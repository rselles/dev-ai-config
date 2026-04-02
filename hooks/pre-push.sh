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

printf 'Tests must pass before pushing. Run the project test suite and confirm it passes, then retry the push.\n'
exit 2
