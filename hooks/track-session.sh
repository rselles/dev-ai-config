#!/usr/bin/env bash
# PostToolUse hook — detects skill invocations and VPS SSH, writes to signals file.
# Exit 0 always — never block tool execution.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/session-store.sh"

DEFAULT_SIGNALS_DIR="${SCRIPT_DIR}/../session-review/signals"
SIGNALS_DIR="${SIGNALS_DIR_OVERRIDE:-$DEFAULT_SIGNALS_DIR}"
SIGNALS_FILE="${SIGNALS_OVERRIDE:-}"
SKILLS_DIR="${SKILLS_DIR_OVERRIDE:-$HOME/.claude/skills}"

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
TOOL_INPUT=$(echo "$INPUT" | jq -r '.tool_input // {}')
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

if [ -z "$SIGNALS_FILE" ]; then
  mkdir -p "$SIGNALS_DIR"
  SIGNALS_FILE=$(signals_file_path "$SIGNALS_DIR" "$TRANSCRIPT_PATH" "$CWD") || exit 0
fi

case "$TOOL_NAME" in
  Skill)
    SKILL_NAME=$(echo "$TOOL_INPUT" | jq -r '.skill // empty')
    if [ -z "$SKILL_NAME" ]; then exit 0; fi
    SKILL_MD="$SKILLS_DIR/$SKILL_NAME/SKILL.md"
    if [ -f "$SKILL_MD" ] && grep -q "## Self-Improvement Protocol" "$SKILL_MD"; then
      echo "$SKILL_NAME" >> "$SIGNALS_FILE"
    fi
    ;;
  Bash)
    CMD=$(echo "$TOOL_INPUT" | jq -r '.command // empty')
    if echo "$CMD" | grep -qE "ssh (rafaelselles|opc@)"; then
      echo "vps-debug" >> "$SIGNALS_FILE"
    fi
    ;;
esac

exit 0
