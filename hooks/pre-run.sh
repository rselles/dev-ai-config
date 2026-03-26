#!/usr/bin/env bash
set -uo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo "pre-run.sh: jq is required but not installed" >&2
  exit 1
fi

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

if [ -z "$CWD" ]; then exit 0; fi

CONTENT=""

LESSONS="$CWD/tasks/lessons.md"
if [ -f "$LESSONS" ]; then
  CONTENT=$(cat "$LESSONS")
fi

# Inject pending session review draft if present
PENDING_FILE="${PENDING_FILE_OVERRIDE:-/home/sirrasel/claude-projects/dev-ai-config/session-review/pending.md}"
if [ -f "$PENDING_FILE" ]; then
  PENDING_CONTENT=$(cat "$PENDING_FILE")
  # Calculate age in days
  FILE_EPOCH=$(date -r "$PENDING_FILE" +%s 2>/dev/null || stat -c %Y "$PENDING_FILE" 2>/dev/null || echo 0)
  NOW_EPOCH=$(date +%s)
  FILE_AGE=$(( (NOW_EPOCH - FILE_EPOCH) / 86400 ))
  AGE_WARN=""
  if [ "$FILE_AGE" -gt 7 ]; then
    AGE_WARN=" (${FILE_AGE} days old — consider discarding)"
  fi
  PENDING_SECTION="---
There is a pending session review draft${AGE_WARN}. Present it to the user and ask: apply, skip, or edit each item. Clear $PENDING_FILE once the user has decided.

PENDING DRAFT:
$PENDING_CONTENT"
  if [ -n "${CONTENT:-}" ]; then
    CONTENT="$CONTENT

$PENDING_SECTION"
  else
    CONTENT="$PENDING_SECTION"
  fi
fi

if [ -n "${CONTENT:-}" ]; then
  jq -n --arg content "$CONTENT" '{"hookSpecificOutput":{"additionalContext":$content}}'
fi

exit 0
