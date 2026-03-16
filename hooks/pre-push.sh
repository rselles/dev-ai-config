#!/usr/bin/env bash
set -uo pipefail

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [ -z "$COMMAND" ] || ! echo "$COMMAND" | grep -qE '^git push'; then
  exit 0
fi

printf '{"hookSpecificOutput":{"additionalContext":"REMINDER: Confirm test suite passed before pushing. If unsure, run tests first."}}\n'
exit 0
