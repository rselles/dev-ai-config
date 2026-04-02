#!/usr/bin/env bash
# Stop hook — generates session-end knowledge capture draft and prompts user.
# Must exit 0 always. Never block session end.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/session-store.sh"

DEFAULT_SIGNALS_DIR="${SCRIPT_DIR}/../session-review/signals"
DEFAULT_PENDING_DIR="${SCRIPT_DIR}/../session-review/pending"
SIGNALS_DIR="${SIGNALS_DIR_OVERRIDE:-$DEFAULT_SIGNALS_DIR}"
PENDING_DIR="${SESSION_REVIEW_DIR_OVERRIDE:-$DEFAULT_PENDING_DIR}"
SIGNALS_FILE="${SIGNALS_OVERRIDE:-}"
PENDING_FILE="${PENDING_OVERRIDE:-}"
SKILLS_DIR="${SKILLS_DIR_OVERRIDE:-$HOME/.claude/skills}"
AGENTS_MD="${AGENTS_MD_OVERRIDE:-/home/sirrasel/claude-projects/dev-ai-config/AGENTS.md}"
CWD_OVERRIDE="${CWD_OVERRIDE:-}"

if ! command -v jq >/dev/null 2>&1; then exit 0; fi

INPUT=$(cat)

# Loop guard — exit immediately if Stop hook is already running
if [ "$(echo "$INPUT" | jq -r '.stop_hook_active // false')" = "true" ]; then
  exit 0
fi

# No signals → nothing to do
# Extract CWD for project-specific target
SESSION_CWD="${CWD_OVERRIDE:-$(echo "$INPUT" | jq -r '.cwd // empty')}"
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty')

if [ -z "$SIGNALS_FILE" ]; then
  SIGNALS_FILE=$(signals_file_path "$SIGNALS_DIR" "$TRANSCRIPT_PATH" "$SESSION_CWD") || exit 0
fi

# No signals → nothing to do
if [ ! -f "$SIGNALS_FILE" ] || [ ! -s "$SIGNALS_FILE" ]; then
  exit 0
fi

SIGNALS=$(sort -u "$SIGNALS_FILE")

# Build transcript excerpt (last 200 JSONL lines, extract content fields)
TRANSCRIPT_EXCERPT=""
if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
  TRANSCRIPT_EXCERPT=$(tail -n 200 "$TRANSCRIPT_PATH" | jq -r '.content // empty' 2>/dev/null | tail -c 8000 || true)
fi

# Build target context from detected signals
TARGET_CONTEXT=""
while IFS= read -r signal; do
  if [ "$signal" = "vps-debug" ]; then
    continue
  fi
  SKILL_MD="$SKILLS_DIR/$signal/SKILL.md"
  if [ -f "$SKILL_MD" ]; then
    TARGET_CONTEXT+="### Skill: $signal"$'\n'"$(cat "$SKILL_MD")"$'\n\n'
  fi
done <<< "$SIGNALS"

# Always include AGENTS.md if it has Self-Improvement Protocol
if [ -f "$AGENTS_MD" ] && grep -q "## Self-Improvement Protocol" "$AGENTS_MD"; then
  TARGET_CONTEXT+="### AGENTS.md"$'\n'"$(cat "$AGENTS_MD")"$'\n\n'
fi

# Include project CLAUDE.md if present and has Self-Improvement Protocol
PROJECT_CLAUDE_MD=""
if [ -n "$SESSION_CWD" ]; then
  for candidate in "$SESSION_CWD/CLAUDE.md" "$SESSION_CWD/AGENTS.md"; do
    if [ -f "$candidate" ] && grep -q "## Self-Improvement Protocol" "$candidate"; then
      PROJECT_CLAUDE_MD="$candidate"
      TARGET_CONTEXT+="### Project CLAUDE.md"$'\n'"$(cat "$candidate")"$'\n\n'
      break
    fi
  done
fi

PROMPT="You are reviewing a just-completed Claude Code session to capture improvements.

Analyze through this lens: what worked, what didn't, where did Claude get stuck?

Signals detected in this session: $SIGNALS

Session transcript (last excerpt):
$TRANSCRIPT_EXCERPT

Opt-in targets:
$TARGET_CONTEXT

For each target, propose a concrete update IF the session revealed something new.
If nothing notable, write exactly: no update needed

Rule for AGENTS.md vs Project CLAUDE.md: broadly-applicable rules (any project) go in AGENTS.md; project-specific rules (this codebase only) go in Project CLAUDE.md.

Output format (use these exact headers):
## [skill-name or AGENTS.md]
[proposed changes or: no update needed]

## Project CLAUDE.md
[proposed changes or: no update needed]

## Journal
[proposed entry or: no update needed]"

DRAFT=$(printf '%s' "$PROMPT" | timeout 30s claude -p 2>/dev/null) || { echo "post-session: claude -p failed or timed out" >&2; exit 0; }
rm -f "$SIGNALS_FILE"

# If every section says "no update needed", exit silently
if ! printf '%s' "$DRAFT" | grep -v "^## " | grep -qv "no update needed"; then
  exit 0
fi

# Show draft and prompt user
printf '\n=== Session Knowledge Capture ===\n'
printf '%s\n' "$DRAFT"
printf '=================================\n\n'
printf 'Review now? [y/N] '
read -r ANSWER </dev/tty 2>/dev/null || ANSWER="N"

case "$ANSWER" in
  y|Y)
    TMPFILE=$(mktemp /tmp/session-draft-XXXXX.md)
    printf '%s\n' "$DRAFT" > "$TMPFILE"
    claude "Review and apply these proposed session updates. The draft is at $TMPFILE. For each section, ask me: apply, skip, or edit."
    rm -f "$TMPFILE"
    ;;
  *)
    if [ -z "$PENDING_FILE" ]; then
      mkdir -p "$PENDING_DIR"
      PENDING_FILE=$(pending_file_path "$PENDING_DIR" "$SESSION_CWD") || exit 0
    fi
    printf '%s\n' "$DRAFT" > "$PENDING_FILE"
    printf 'Draft saved. Will be shown at next session start.\n'
    ;;
esac

exit 0
