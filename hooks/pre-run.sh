#!/usr/bin/env bash
set -uo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo "pre-run.sh: jq is required but not installed" >&2
  exit 1
fi

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

if [ -z "$CWD" ]; then exit 0; fi

LESSONS="$CWD/tasks/lessons.md"
if [ -f "$LESSONS" ]; then
  CONTENT=$(cat "$LESSONS")
  jq -n --arg content "$CONTENT" '{"hookSpecificOutput":{"additionalContext":$content}}'
fi

exit 0
