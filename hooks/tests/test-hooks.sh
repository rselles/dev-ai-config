#!/usr/bin/env bash
# test-hooks.sh - TDD test suite for hooks/pre-run.sh, hooks/pre-commit.sh, hooks/pre-push.sh
# Tests are written before scripts exist (red phase). Run with: bash hooks/tests/test-hooks.sh

set -uo pipefail

HOOKS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PRE_COMMIT="$HOOKS_DIR/pre-commit.sh"
PRE_PUSH="$HOOKS_DIR/pre-push.sh"
PRE_RUN="$HOOKS_DIR/pre-run.sh"

PASS=0
FAIL=0

pass() {
  echo "PASS: $1"
  PASS=$((PASS + 1))
}

fail() {
  echo "FAIL: $1"
  echo "      $2"
  FAIL=$((FAIL + 1))
}

# Run a hook script, capturing stdout and exit code.
# Uses `set -uo pipefail` (no -e) so non-zero exit codes from scripts are captured
# cleanly rather than aborting the test runner.
# Sets globals: OUTPUT, EXIT_CODE
# Optional extra args after input are passed as env vars via `env` (e.g. HOOK_BRANCH_OVERRIDE=main)
run_hook() {
  local script="$1"
  local input="$2"
  shift 2
  EXIT_CODE=0
  OUTPUT=$(echo "$input" | env "$@" bash "$script" 2>/dev/null) || EXIT_CODE=$?
}

# ---------------------------------------------------------------------------
# pre-commit tests
# ---------------------------------------------------------------------------

# Test 1: Commit subject >50 chars -> exit 2
INPUT=$(jq -n --arg cmd "git commit -m 'Add a very long commit message that definitely exceeds the fifty character limit'" \
  '{"tool_input": {"command": $cmd}}')
run_hook "$PRE_COMMIT" "$INPUT" HOOK_BRANCH_OVERRIDE=feature/test
if [ "$EXIT_CODE" -eq 2 ]; then
  pass "pre-commit: subject >50 chars -> exit 2"
else
  fail "pre-commit: subject >50 chars -> exit 2" "got exit $EXIT_CODE"
fi

# Test 2: Past-tense first word ("Added feature") -> exit 2
# "Added" is not in the allowlist; suffix check fires because it ends in -ed.
INPUT=$(jq -n --arg cmd "git commit -m 'Added feature'" \
  '{"tool_input": {"command": $cmd}}')
run_hook "$PRE_COMMIT" "$INPUT" HOOK_BRANCH_OVERRIDE=feature/test
if [ "$EXIT_CODE" -eq 2 ]; then
  pass "pre-commit: past-tense (-ed) first word -> exit 2"
else
  fail "pre-commit: past-tense (-ed) first word -> exit 2" "got exit $EXIT_CODE"
fi

# Test 3: Gerund first word ("Adding feature") -> exit 2
# "Adding" is not in the allowlist; suffix check fires because it ends in -ing.
INPUT=$(jq -n --arg cmd "git commit -m 'Adding feature'" \
  '{"tool_input": {"command": $cmd}}')
run_hook "$PRE_COMMIT" "$INPUT" HOOK_BRANCH_OVERRIDE=feature/test
if [ "$EXIT_CODE" -eq 2 ]; then
  pass "pre-commit: gerund (-ing) first word -> exit 2"
else
  fail "pre-commit: gerund (-ing) first word -> exit 2" "got exit $EXIT_CODE"
fi

# Test 4: Imperative first word ("Add feature") -> exit 0
# "Add" is not in the allowlist but does not end in -ed or -ing.
INPUT=$(jq -n --arg cmd "git commit -m 'Add feature'" \
  '{"tool_input": {"command": $cmd}}')
run_hook "$PRE_COMMIT" "$INPUT" HOOK_BRANCH_OVERRIDE=feature/test
if [ "$EXIT_CODE" -eq 0 ]; then
  pass "pre-commit: imperative first word -> exit 0"
else
  fail "pre-commit: imperative first word -> exit 0" "got exit $EXIT_CODE"
fi

# Test 5: Non-git command -> exit 0 (pass through)
INPUT=$(jq -n --arg cmd "echo hello" \
  '{"tool_input": {"command": $cmd}}')
run_hook "$PRE_COMMIT" "$INPUT"
if [ "$EXIT_CODE" -eq 0 ]; then
  pass "pre-commit: non-git command -> exit 0 (pass through)"
else
  fail "pre-commit: non-git command -> exit 0 (pass through)" "got exit $EXIT_CODE"
fi

# Test 6: Missing -m flag -> exit 0 (conservative)
INPUT=$(jq -n --arg cmd "git commit --allow-empty" \
  '{"tool_input": {"command": $cmd}}')
run_hook "$PRE_COMMIT" "$INPUT" HOOK_BRANCH_OVERRIDE=feature/test
if [ "$EXIT_CODE" -eq 0 ]; then
  pass "pre-commit: missing -m flag -> exit 0 (conservative)"
else
  fail "pre-commit: missing -m flag -> exit 0 (conservative)" "got exit $EXIT_CODE"
fi

# Test 7: "Fix" as first word -> exit 0 (explicit allowlist entry)
# "Fix" is in the allowlist; the -ed/-ing suffix check is skipped entirely.
INPUT=$(jq -n --arg cmd "git commit -m 'Fix login redirect bug'" \
  '{"tool_input": {"command": $cmd}}')
run_hook "$PRE_COMMIT" "$INPUT" HOOK_BRANCH_OVERRIDE=feature/test
if [ "$EXIT_CODE" -eq 0 ]; then
  pass "pre-commit: 'Fix' first word (allowlist) -> exit 0"
else
  fail "pre-commit: 'Fix' first word (allowlist) -> exit 0" "got exit $EXIT_CODE"
fi

# Test 8: "Address" as first word -> exit 0 (explicit allowlist entry)
# "Address" ends in -ess; the allowlist protects it from any overly-broad suffix
# matching. Tests that the allowlist check runs before the suffix check.
INPUT=$(jq -n --arg cmd "git commit -m 'Address review feedback'" \
  '{"tool_input": {"command": $cmd}}')
run_hook "$PRE_COMMIT" "$INPUT" HOOK_BRANCH_OVERRIDE=feature/test
if [ "$EXIT_CODE" -eq 0 ]; then
  pass "pre-commit: 'Address' first word (allowlist) -> exit 0"
else
  fail "pre-commit: 'Address' first word (allowlist) -> exit 0" "got exit $EXIT_CODE"
fi

# Test 9: "Process" as first word -> exit 0 (explicit allowlist entry)
# "Process" ends in -ess; same allowlist-before-suffix-check rationale as "Address".
INPUT=$(jq -n --arg cmd "git commit -m 'Process payment webhook events'" \
  '{"tool_input": {"command": $cmd}}')
run_hook "$PRE_COMMIT" "$INPUT" HOOK_BRANCH_OVERRIDE=feature/test
if [ "$EXIT_CODE" -eq 0 ]; then
  pass "pre-commit: 'Process' first word (allowlist) -> exit 0"
else
  fail "pre-commit: 'Process' first word (allowlist) -> exit 0" "got exit $EXIT_CODE"
fi

# Test 10: Double-quoted -m value is parsed correctly -> exit 0
# Verifies the parser strips both single and double quote styles.
INPUT=$(jq -n --arg cmd 'git commit -m "Add double-quoted subject"' \
  '{"tool_input": {"command": $cmd}}')
run_hook "$PRE_COMMIT" "$INPUT" HOOK_BRANCH_OVERRIDE=feature/test
if [ "$EXIT_CODE" -eq 0 ]; then
  pass "pre-commit: double-quoted -m value parsed correctly -> exit 0"
else
  fail "pre-commit: double-quoted -m value parsed correctly -> exit 0" "got exit $EXIT_CODE"
fi

# Test 11: Double-quoted -m with -ed first word -> exit 2
# Verifies the parser strips double quotes before applying the mood check.
INPUT=$(jq -n --arg cmd 'git commit -m "Added double-quoted subject"' \
  '{"tool_input": {"command": $cmd}}')
run_hook "$PRE_COMMIT" "$INPUT" HOOK_BRANCH_OVERRIDE=feature/test
if [ "$EXIT_CODE" -eq 2 ]; then
  pass "pre-commit: double-quoted -m with -ed first word -> exit 2"
else
  fail "pre-commit: double-quoted -m with -ed first word -> exit 2" "got exit $EXIT_CODE"
fi

# ---------------------------------------------------------------------------
# pre-push tests
# ---------------------------------------------------------------------------

# Test 12: git push -> exit 0 AND stdout contains "additionalContext"
INPUT=$(jq -n --arg cmd "git push origin main" \
  '{"tool_input": {"command": $cmd}}')
run_hook "$PRE_PUSH" "$INPUT"
if [ "$EXIT_CODE" -eq 0 ] && echo "$OUTPUT" | grep -q "additionalContext"; then
  pass "pre-push: git push -> exit 0 and stdout contains 'additionalContext'"
else
  fail "pre-push: git push -> exit 0 and stdout contains 'additionalContext'" \
    "exit=$EXIT_CODE output=$(echo "$OUTPUT" | head -1)"
fi

# Test 13: Non-push command -> exit 0 AND stdout is empty
INPUT=$(jq -n --arg cmd "git status" \
  '{"tool_input": {"command": $cmd}}')
run_hook "$PRE_PUSH" "$INPUT"
if [ "$EXIT_CODE" -eq 0 ] && [ -z "$OUTPUT" ]; then
  pass "pre-push: non-push command -> exit 0 and empty stdout"
else
  fail "pre-push: non-push command -> exit 0 and empty stdout" \
    "exit=$EXIT_CODE output='$OUTPUT'"
fi

# ---------------------------------------------------------------------------
# pre-run tests
# ---------------------------------------------------------------------------

TMPDIR_BASE=$(mktemp -d)
trap 'rm -rf "$TMPDIR_BASE"' EXIT

# Test 14: cwd contains tasks/lessons.md -> stdout contains "additionalContext"
# Only the immediate $cwd is checked; no parent-directory walk.
LESSONS_DIR="$TMPDIR_BASE/with-lessons"
mkdir -p "$LESSONS_DIR/tasks"
printf '## Lesson 1\n**Rule:** Always write tests first.\n' > "$LESSONS_DIR/tasks/lessons.md"

INPUT=$(jq -n --arg cwd "$LESSONS_DIR" '{"cwd": $cwd}')
run_hook "$PRE_RUN" "$INPUT"
if echo "$OUTPUT" | grep -q "additionalContext"; then
  pass "pre-run: cwd with tasks/lessons.md -> stdout contains 'additionalContext'"
else
  fail "pre-run: cwd with tasks/lessons.md -> stdout contains 'additionalContext'" \
    "exit=$EXIT_CODE output='$OUTPUT'"
fi

# Test 15: cwd has no tasks/lessons.md -> stdout is empty AND exit 0
NO_LESSONS_DIR="$TMPDIR_BASE/no-lessons"
mkdir -p "$NO_LESSONS_DIR"

INPUT=$(jq -n --arg cwd "$NO_LESSONS_DIR" '{"cwd": $cwd}')
run_hook "$PRE_RUN" "$INPUT"
if [ "$EXIT_CODE" -eq 0 ] && [ -z "$OUTPUT" ]; then
  pass "pre-run: cwd without tasks/lessons.md -> empty stdout and exit 0"
else
  fail "pre-run: cwd without tasks/lessons.md -> empty stdout and exit 0" \
    "exit=$EXIT_CODE output='$OUTPUT'"
fi

# ---------------------------------------------------------------------------
# pre-commit branch guard + Co-Authored-By advisory tests
# ---------------------------------------------------------------------------

# Test 16: Commit on branch 'main' -> exit 2 (blocked)
INPUT=$(jq -n --arg cmd "git commit -m 'Add feature'" '{"tool_input": {"command": $cmd}}')
run_hook "$PRE_COMMIT" "$INPUT" HOOK_BRANCH_OVERRIDE=main
if [ "$EXIT_CODE" -eq 2 ]; then
  pass "pre-commit: commit on branch 'main' -> exit 2 (blocked)"
else
  fail "pre-commit: commit on branch 'main' -> exit 2 (blocked)" "got exit $EXIT_CODE"
fi

# Test 17: Commit on branch 'feature/my-feature' -> exit 0 (valid message passes)
INPUT=$(jq -n --arg cmd "git commit -m 'Add feature'" '{"tool_input": {"command": $cmd}}')
run_hook "$PRE_COMMIT" "$INPUT" HOOK_BRANCH_OVERRIDE=feature/my-feature
if [ "$EXIT_CODE" -eq 0 ]; then
  pass "pre-commit: commit on branch 'feature/my-feature' -> exit 0"
else
  fail "pre-commit: commit on branch 'feature/my-feature' -> exit 0" "got exit $EXIT_CODE"
fi

# Test 18: Valid commit with no Co-Authored-By -> exit 0 AND stdout contains advisory
INPUT=$(jq -n --arg cmd "git commit -m 'Add feature'" '{"tool_input": {"command": $cmd}}')
run_hook "$PRE_COMMIT" "$INPUT" HOOK_BRANCH_OVERRIDE=feature/test
if [ "$EXIT_CODE" -eq 0 ] && echo "$OUTPUT" | grep -q "Co-Authored-By"; then
  pass "pre-commit: no Co-Authored-By -> exit 0 and advisory in stdout"
else
  fail "pre-commit: no Co-Authored-By -> exit 0 and advisory in stdout" \
    "exit=$EXIT_CODE output='$OUTPUT'"
fi

# Test 19: Valid commit WITH Co-Authored-By -> exit 0 AND stdout does NOT contain advisory
CMD="git commit -m 'Add feature' -m 'Co-Authored-By: claude-sonnet-4-6 <noreply@anthropic.com>'"
INPUT=$(jq -n --arg cmd "$CMD" '{"tool_input": {"command": $cmd}}')
run_hook "$PRE_COMMIT" "$INPUT" HOOK_BRANCH_OVERRIDE=feature/test
if [ "$EXIT_CODE" -eq 0 ] && ! echo "$OUTPUT" | grep -q "additionalContext"; then
  pass "pre-commit: Co-Authored-By present -> exit 0 and no advisory in stdout"
else
  fail "pre-commit: Co-Authored-By present -> exit 0 and no advisory in stdout" \
    "exit=$EXIT_CODE output='$OUTPUT'"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

echo ""
echo "Results: $PASS passed, $FAIL failed"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
