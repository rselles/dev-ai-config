#!/usr/bin/env bash
set -uo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo "pre-push.sh: jq is required but not installed" >&2
  exit 1
fi

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [ -z "$COMMAND" ] || ! echo "$COMMAND" | grep -qE '^git push'; then
  exit 0
fi

printf '{"hookSpecificOutput":{"additionalContext":"REMINDER: Confirm test suite passed before pushing. If unsure, run tests first."}}\n'
exit 0
