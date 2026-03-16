#!/usr/bin/env bash
set -uo pipefail

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

if [ -z "$CWD" ]; then exit 0; fi

LESSONS="$CWD/tasks/lessons.md"
if [ -f "$LESSONS" ]; then
  CONTENT=$(cat "$LESSONS")
  printf '{"hookSpecificOutput":{"additionalContext":"%s"}}\n' \
    "$(echo "$CONTENT" | sed 's/\\/\\\\/g; s/"/\\"/g; s/$/\\n/' | tr -d '\n')"
fi

exit 0
