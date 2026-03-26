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
# "Add" is in the allowlist; allowlist check fires before suffix check.
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

# Test 20: Imperative word not in allowlist and no -ed/-ing suffix -> exit 0
# "Tweak" is not in the allowlist but is imperative. Should pass.
INPUT=$(jq -n --arg cmd "git commit -m 'Tweak config timeout'" '{"tool_input": {"command": $cmd}}')
run_hook "$PRE_COMMIT" "$INPUT" HOOK_BRANCH_OVERRIDE=feature/test
if [ "$EXIT_CODE" -eq 0 ]; then
  pass "pre-commit: non-allowlist imperative word ('Tweak') -> exit 0"
else
  fail "pre-commit: non-allowlist imperative word ('Tweak') -> exit 0" "got exit $EXIT_CODE"
fi

# ---------------------------------------------------------------------------
# track-session.sh tests
# ---------------------------------------------------------------------------
TRACK="$HOOKS_DIR/track-session.sh"

SIGNALS_OVERRIDE=""
cleanup_signals() { rm -f "$SIGNALS_OVERRIDE"; }

# Test T1: Skill tool with vps-log-review (has Self-Improvement Protocol) → appends skill name
cleanup_signals
SIGNALS_OVERRIDE=$(mktemp)
INPUT=$(jq -n '{"tool_name": "Skill", "tool_input": {"skill": "vps-log-review"}}')
SIGNALS_OVERRIDE="$SIGNALS_OVERRIDE" run_hook "$TRACK" "$INPUT"
if grep -q "vps-log-review" "$SIGNALS_OVERRIDE" 2>/dev/null; then
  pass "track-session: Skill with SIP section → skill name appended"
else
  fail "track-session: Skill with SIP section → skill name appended" \
       "signals file: $(cat "$SIGNALS_OVERRIDE" 2>/dev/null || echo 'missing')"
fi

# Test T2: Skill tool with brainstorming (no Self-Improvement Protocol) → nothing written
SIGNALS_OVERRIDE=$(mktemp)
cleanup_signals
INPUT=$(jq -n '{"tool_name": "Skill", "tool_input": {"skill": "brainstorming"}}')
SIGNALS_OVERRIDE="$SIGNALS_OVERRIDE" run_hook "$TRACK" "$INPUT"
if [ ! -s "$SIGNALS_OVERRIDE" ]; then
  pass "track-session: Skill without SIP → nothing written"
else
  fail "track-session: Skill without SIP → nothing written" \
       "file unexpectedly contains: $(cat "$SIGNALS_OVERRIDE")"
fi
cleanup_signals

# Test T3: Bash tool with ssh rafaelselles → appends vps-debug
cleanup_signals
SIGNALS_OVERRIDE=$(mktemp)
INPUT=$(jq -n '{"tool_name": "Bash", "tool_input": {"command": "ssh rafaelselles ls"}}')
SIGNALS_OVERRIDE="$SIGNALS_OVERRIDE" run_hook "$TRACK" "$INPUT"
if grep -q "vps-debug" "$SIGNALS_OVERRIDE" 2>/dev/null; then
  pass "track-session: Bash ssh rafaelselles → vps-debug appended"
else
  fail "track-session: Bash ssh rafaelselles → vps-debug appended" \
       "signals file: $(cat "$SIGNALS_OVERRIDE" 2>/dev/null || echo 'missing')"
fi
cleanup_signals

# Test T4: Bash tool without SSH → nothing written
SIGNALS_OVERRIDE=$(mktemp)
cleanup_signals
INPUT=$(jq -n '{"tool_name": "Bash", "tool_input": {"command": "ls -la /tmp"}}')
SIGNALS_OVERRIDE="$SIGNALS_OVERRIDE" run_hook "$TRACK" "$INPUT"
if [ ! -s "$SIGNALS_OVERRIDE" ]; then
  pass "track-session: Bash without SSH → nothing written"
else
  fail "track-session: Bash without SSH → nothing written" \
       "file unexpectedly contains: $(cat "$SIGNALS_OVERRIDE")"
fi
cleanup_signals

# ---------------------------------------------------------------------------
# post-session.sh tests
# ---------------------------------------------------------------------------
POST_SESSION="$HOOKS_DIR/post-session.sh"

# Helper: create a mock claude binary that returns known output
MOCK_CLAUDE_DIR=""
setup_mock_claude() {
  local output="$1"
  local exit_code="${2:-0}"
  MOCK_CLAUDE_DIR=$(mktemp -d)
  printf '#!/usr/bin/env bash\necho "%s"\nexit %s\n' "$output" "$exit_code" > "$MOCK_CLAUDE_DIR/claude"
  chmod +x "$MOCK_CLAUDE_DIR/claude"
  export PATH="$MOCK_CLAUDE_DIR:$PATH"
}
cleanup_mock_claude() {
  [ -n "$MOCK_CLAUDE_DIR" ] && rm -rf "$MOCK_CLAUDE_DIR"
  MOCK_CLAUDE_DIR=""
}

# Test P1: stop_hook_active=true → exits 0, produces no output
PENDING_P=$(mktemp)
SIGNALS_P=$(mktemp)
echo "vps-log-review" > "$SIGNALS_P"
INPUT=$(jq -n '{"stop_hook_active": true, "transcript_path": "/dev/null"}')
OUTPUT=$(echo "$INPUT" | SIGNALS_OVERRIDE="$SIGNALS_P" PENDING_OVERRIDE="$PENDING_P" bash "$POST_SESSION" 2>/dev/null)
EXIT_CODE=$?
if [ "$EXIT_CODE" -eq 0 ] && [ -z "$OUTPUT" ]; then
  pass "post-session: stop_hook_active=true → exits 0 silently"
else
  fail "post-session: stop_hook_active=true → exits 0 silently" \
       "exit=$EXIT_CODE output='$OUTPUT'"
fi
rm -f "$PENDING_P" "$SIGNALS_P"

# Test P2: non-empty draft → "Review now?" prompt shown
PENDING_P=$(mktemp)
SIGNALS_P=$(mktemp)
echo "vps-log-review" > "$SIGNALS_P"
setup_mock_claude "## vps-log-review\nAdd new pattern\n## AGENTS.md\nno update needed\n## Journal\nno update needed"
INPUT=$(jq -n '{"stop_hook_active": false, "transcript_path": "/dev/null"}')
OUTPUT=$(printf "N\n" | echo "$INPUT" | SIGNALS_OVERRIDE="$SIGNALS_P" PENDING_OVERRIDE="$PENDING_P" bash "$POST_SESSION" 2>/dev/null)
cleanup_mock_claude
if echo "$OUTPUT" | grep -qi "Review now"; then
  pass "post-session: non-empty draft → Review now? prompt shown"
else
  fail "post-session: non-empty draft → Review now? prompt shown" \
       "output='$OUTPUT'"
fi
rm -f "$PENDING_P" "$SIGNALS_P"

# Test P3: all sections "no update needed" → exits silently, no prompt
PENDING_P=$(mktemp)
SIGNALS_P=$(mktemp)
echo "vps-log-review" > "$SIGNALS_P"
setup_mock_claude "## vps-log-review\nno update needed\n## AGENTS.md\nno update needed\n## Journal\nno update needed"
INPUT=$(jq -n '{"stop_hook_active": false, "transcript_path": "/dev/null"}')
OUTPUT=$(echo "$INPUT" | SIGNALS_OVERRIDE="$SIGNALS_P" PENDING_OVERRIDE="$PENDING_P" bash "$POST_SESSION" 2>/dev/null)
cleanup_mock_claude
if [ -z "$OUTPUT" ]; then
  pass "post-session: all no update needed → exits silently"
else
  fail "post-session: all no update needed → exits silently" \
       "output='$OUTPUT'"
fi
rm -f "$PENDING_P" "$SIGNALS_P"

# Test P4: answer N → pending.md overwritten (not appended)
PENDING_P=$(mktemp)
echo "old content" > "$PENDING_P"
SIGNALS_P=$(mktemp)
echo "vps-log-review" > "$SIGNALS_P"
setup_mock_claude "## vps-log-review\nAdd new pattern"
INPUT=$(jq -n '{"stop_hook_active": false, "transcript_path": "/dev/null"}')
printf "N\n" | echo "$INPUT" | SIGNALS_OVERRIDE="$SIGNALS_P" PENDING_OVERRIDE="$PENDING_P" bash "$POST_SESSION" 2>/dev/null
cleanup_mock_claude
if grep -q "Add new pattern" "$PENDING_P" 2>/dev/null && ! grep -q "old content" "$PENDING_P" 2>/dev/null; then
  pass "post-session: answer N → pending.md overwritten not appended"
else
  fail "post-session: answer N → pending.md overwritten not appended" \
       "pending.md: $(cat "$PENDING_P" 2>/dev/null || echo 'missing')"
fi
rm -f "$PENDING_P" "$SIGNALS_P"

# Test P5: claude -p exits 1 → script exits 0 silently
PENDING_P=$(mktemp)
SIGNALS_P=$(mktemp)
echo "vps-log-review" > "$SIGNALS_P"
setup_mock_claude "" 1
INPUT=$(jq -n '{"stop_hook_active": false, "transcript_path": "/dev/null"}')
OUTPUT=$(echo "$INPUT" | SIGNALS_OVERRIDE="$SIGNALS_P" PENDING_OVERRIDE="$PENDING_P" bash "$POST_SESSION" 2>/dev/null)
EXIT_CODE=$?
cleanup_mock_claude
if [ "$EXIT_CODE" -eq 0 ] && [ -z "$OUTPUT" ]; then
  pass "post-session: claude failure → exits 0 silently"
else
  fail "post-session: claude failure → exits 0 silently" \
       "exit=$EXIT_CODE output='$OUTPUT'"
fi
rm -f "$PENDING_P" "$SIGNALS_P"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

echo ""
echo "Results: $PASS passed, $FAIL failed (expected: 20 original pass, T1+T3 fail (script missing), T2+T4 pass vacuously)"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
