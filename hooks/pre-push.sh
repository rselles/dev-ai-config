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

CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
[ -z "$CWD" ] && CWD="$PWD"

# Only Python/pytest projects are recognized so far (recetario, arguiano).
# No recognized test runner -> nothing to enforce, let the push through.
HAS_PY_TESTS=0
if [ -f "$CWD/pyproject.toml" ] && [ -d "$CWD/tests" ] \
   && find "$CWD/tests" -maxdepth 3 -name "*.py" -print -quit 2>/dev/null | grep -q .; then
  HAS_PY_TESTS=1
fi

if [ "$HAS_PY_TESTS" -ne 1 ]; then
  exit 0
fi

PYTHON_BIN=$(command -v python || command -v python3 || true)
if [ -z "$PYTHON_BIN" ]; then
  exit 0
fi

TEST_OUTPUT=$(cd "$CWD" && timeout 120 "$PYTHON_BIN" -m pytest 2>&1)
TEST_EXIT=$?

if [ "$TEST_EXIT" -ne 0 ]; then
  printf 'Push blocked: test suite failed (exit %s).\n\n%s\n' "$TEST_EXIT" "$(echo "$TEST_OUTPUT" | tail -30)"
  exit 2
fi

exit 0
