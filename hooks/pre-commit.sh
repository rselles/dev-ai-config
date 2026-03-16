#!/usr/bin/env bash
set -uo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo "pre-commit.sh: jq is required but not installed" >&2
  exit 1
fi

# Read stdin JSON
INPUT=$(cat)

# Extract command
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
if [ -z "$COMMAND" ]; then exit 0; fi

# Only handle git commit
if ! echo "$COMMAND" | grep -qE '^git commit'; then exit 0; fi

# Branch check — use override for testing, otherwise detect
if [ -n "${HOOK_BRANCH_OVERRIDE:-}" ]; then
  BRANCH="$HOOK_BRANCH_OVERRIDE"
else
  BRANCH=$(git branch --show-current 2>/dev/null || echo "")
fi

if [ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ]; then
  echo "Commits to '$BRANCH' are blocked. Create a feature branch first." >&2
  exit 2
fi

# Extract -m value — handle both -m 'msg' and -m "msg" and multiple -m flags
# Conservative: if no -m flag present, pass through
if ! echo "$COMMAND" | grep -qE "\-m[[:space:]]"; then exit 0; fi

# Extract all -m values (concatenate with newline, as git does)
MSG=""
while IFS= read -r part; do
  [ -n "$part" ] && MSG="${MSG}${MSG:+
}${part}"
done < <(
  echo "$COMMAND" | grep -oE "\-m[[:space:]]+'[^']*'" | sed "s/^-m[[:space:]]*//" | tr -d "'"
  echo "$COMMAND" | grep -oE '\-m[[:space:]]+"[^"]*"' | sed 's/^-m[[:space:]]*//' | tr -d '"'
)

if [ -z "$MSG" ]; then exit 0; fi  # couldn't parse -> conservative

# Subject = first line only
SUBJECT="${MSG%%$'\n'*}"

# Length check
if [ "${#SUBJECT}" -gt 50 ]; then
  echo "Commit subject too long (${#SUBJECT} chars, max 50): '$SUBJECT'" >&2
  exit 2
fi

# Mood check
FIRST_WORD="${SUBJECT%% *}"
ALLOWLIST="Add Fix Update Remove Refactor Move Rename Set Use Make Create Delete Merge Revert Release Bump Upgrade Drop Seed Wire Address Process Implement Configure Enable Disable Replace Extract Introduce Simplify Improve Optimize Prevent Enforce Validate Normalize Initialize Override Integrate Deprecate Inline"

ALLOWED=0
for WORD in $ALLOWLIST; do
  if [ "$FIRST_WORD" = "$WORD" ]; then ALLOWED=1; break; fi
done

if [ "$ALLOWED" -eq 0 ]; then
  if echo "$FIRST_WORD" | grep -qiE 'ed$'; then
    echo "Commit subject appears to use past tense ('$FIRST_WORD'). Use imperative mood (e.g., 'Add' not 'Added')." >&2
    exit 2
  fi
  if echo "$FIRST_WORD" | grep -qiE 'ing$'; then
    echo "Commit subject appears to use gerund ('$FIRST_WORD'). Use imperative mood (e.g., 'Add' not 'Adding')." >&2
    exit 2
  fi
fi

# Co-Authored-By advisory (non-blocking)
if ! echo "$COMMAND" | grep -q "Co-Authored-By"; then
  printf '{"hookSpecificOutput":{"additionalContext":"Advisory: commit message is missing a Co-Authored-By line. Consider adding one (e.g., Co-Authored-By: claude-sonnet-4-6 <noreply@anthropic.com>)."}}\n'
fi

exit 0
