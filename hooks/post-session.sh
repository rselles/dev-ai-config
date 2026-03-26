#!/usr/bin/env bash
# Stop hook — generates session-end knowledge capture draft and prompts user.
# Must exit 0 always. Never block session end.
set -uo pipefail

SIGNALS_FILE="${SIGNALS_OVERRIDE:-/tmp/claude-session-signals}"
PENDING_FILE="${PENDING_OVERRIDE:-/home/sirrasel/claude-projects/dev-ai-config/session-review/pending.md}"
SKILLS_DIR="${SKILLS_DIR_OVERRIDE:-$HOME/.claude/skills}"
AGENTS_MD="${AGENTS_MD_OVERRIDE:-/home/sirrasel/claude-projects/dev-ai-config/AGENTS.md}"

if ! command -v jq >/dev/null 2>&1; then exit 0; fi

INPUT=$(cat)

# Loop guard — exit immediately if Stop hook is already running
if [ "$(echo "$INPUT" | jq -r '.stop_hook_active // false')" = "true" ]; then
  exit 0
fi

# No signals → nothing to do
if [ ! -f "$SIGNALS_FILE" ] || [ ! -s "$SIGNALS_FILE" ]; then
  exit 0
fi

SIGNALS=$(sort -u "$SIGNALS_FILE")
rm -f "$SIGNALS_FILE"

# Build transcript excerpt (last 200 JSONL lines, extract content fields)
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty')
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

PROMPT="You are reviewing a just-completed Claude Code session to capture improvements.

Analyze through this lens: what worked, what didn't, where did Claude get stuck?

Signals detected in this session: $SIGNALS

Session transcript (last excerpt):
$TRANSCRIPT_EXCERPT

Opt-in targets:
$TARGET_CONTEXT

For each target, propose a concrete update IF the session revealed something new.
If nothing notable, write exactly: no update needed

Output format (use these exact headers):
## [skill-name or AGENTS.md]
[proposed changes or: no update needed]

## Journal
[proposed entry or: no update needed]"

DRAFT=$(printf '%s' "$PROMPT" | timeout 30s claude -p 2>/dev/null) || { exit 0; }

# If every section says "no update needed", exit silently
# Normalize literal \n sequences to real newlines (handles both mock and real claude output),
# then check if any non-header line has content other than "no update needed".
DRAFT_NORMALIZED=$(printf '%b' "$DRAFT")
if ! printf '%s' "$DRAFT_NORMALIZED" | grep -v "^## " | grep -qv "no update needed"; then
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
    printf '%s\n' "$DRAFT" > "$PENDING_FILE"
    printf 'Draft saved. Will be shown at next session start.\n'
    ;;
esac

exit 0
