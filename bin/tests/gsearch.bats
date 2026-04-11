#!/usr/bin/env bats
# Tests for gsearch
#
# Acceptance criteria:
#   AC1: Given a query, stdout contains the Gemini response text
#   AC2: Given a query, stderr contains a savings line with token counts
#   AC3: Given a query, a CSV row is appended to GEMINI_GAIN_LOG with correct fields
#   AC4: Given jq is missing, stdout still contains the response and log row has blank token fields
#   AC5: Given multiple calls, rows accumulate in the log (not overwritten)

bats_require_minimum_version 1.5.0

SCRIPT="$BATS_TEST_DIRNAME/../gsearch"
MOCKS="$BATS_TEST_DIRNAME/mocks"

setup() {
  export PATH="$MOCKS:$PATH"
  export GEMINI_GAIN_LOG="$(mktemp)"
}

teardown() {
  rm -f "$GEMINI_GAIN_LOG"
}

# AC1 — stdout contains response text
@test "gsearch writes Gemini response to stdout" {
  export MOCK_GEMINI_RESPONSE="This is the search result summary."
  run "$SCRIPT" "what is Rust"
  [ "$status" -eq 0 ]
  [[ "$output" == *"This is the search result summary."* ]]
}

# AC2 — stderr contains savings line
@test "gsearch writes token savings line to stderr" {
  run --separate-stderr "$SCRIPT" "what is Rust"
  [ "$status" -eq 0 ]
  [[ "$stderr" == *"[gsearch]"* ]]
  [[ "$stderr" == *"gemini input"* ]]
  [[ "$stderr" == *"tok"* ]]
}

# AC2 — stderr contains the query in the savings line
@test "gsearch savings line includes the query" {
  run --separate-stderr "$SCRIPT" "vulkan sparse binding"
  [[ "$stderr" == *"vulkan sparse binding"* ]]
}

# AC3 — CSV row appended to log
@test "gsearch appends a CSV row to the log file" {
  "$SCRIPT" "what is Rust" >/dev/null
  [ "$(wc -l < "$GEMINI_GAIN_LOG")" -eq 1 ]
}

@test "gsearch CSV row has correct mode field" {
  "$SCRIPT" "what is Rust" >/dev/null
  row=$(cat "$GEMINI_GAIN_LOG")
  [[ "$row" == *",gsearch,"* ]]
}

@test "gsearch CSV row contains gemini input token count" {
  "$SCRIPT" "what is Rust" >/dev/null
  row=$(cat "$GEMINI_GAIN_LOG")
  # mock returns input=7224, output=24 — both should appear in the row
  [[ "$row" == *"7224"* ]]
}

# AC4 — graceful degradation when jq is missing
@test "gsearch still outputs response when jq is missing" {
  export MOCK_GEMINI_RESPONSE="Fallback response."
  # Shadow jq with a no-op that exits non-zero
  local no_jq
  no_jq="$(mktemp -d)"
  printf '#!/usr/bin/env bash\nexit 127\n' > "$no_jq/jq"
  chmod +x "$no_jq/jq"
  PATH="$no_jq:$MOCKS:$(echo "$PATH" | tr ':' '\n' | grep -v "$MOCKS" | tr '\n' ':')"
  run "$SCRIPT" "what is Rust"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Fallback response."* ]]
  rm -rf "$no_jq"
}

@test "gsearch logs a row even when jq is missing" {
  local no_jq
  no_jq="$(mktemp -d)"
  printf '#!/usr/bin/env bash\nexit 127\n' > "$no_jq/jq"
  chmod +x "$no_jq/jq"
  PATH="$no_jq:$MOCKS:$(echo "$PATH" | tr ':' '\n' | grep -v "$MOCKS" | tr '\n' ':')"
  "$SCRIPT" "what is Rust" >/dev/null
  [ "$(wc -l < "$GEMINI_GAIN_LOG")" -eq 1 ]
  rm -rf "$no_jq"
}

# AC5 — multiple calls accumulate rows
@test "gsearch accumulates multiple rows in the log" {
  "$SCRIPT" "first query" >/dev/null
  "$SCRIPT" "second query" >/dev/null
  [ "$(wc -l < "$GEMINI_GAIN_LOG")" -eq 2 ]
}
