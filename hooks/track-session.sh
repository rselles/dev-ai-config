#!/usr/bin/env bash
# PostToolUse hook — detects skill invocations and VPS SSH, writes to signals file.
# Exit 0 always — never block tool execution.
set -uo pipefail

SIGNALS_FILE="${SIGNALS_OVERRIDE:-/tmp/claude-session-signals}"
SKILLS_DIR="${SKILLS_DIR_OVERRIDE:-$HOME/.claude/skills}"

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
TOOL_INPUT=$(echo "$INPUT" | jq -r '.tool_input // {}')

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
