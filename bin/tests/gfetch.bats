#!/usr/bin/env bats
# Tests for gfetch
#
# Acceptance criteria:
#   AC1: Given a URL, stdout contains the Gemini response text
#   AC2: Given a URL, stderr shows raw→summary savings with percentage
#   AC3: Given a URL, a CSV row is appended to GEMINI_GAIN_LOG with raw_tokens populated
#   AC4: Given a URL + extraction prompt, the Gemini call includes both
#   AC5: Given jq is missing, it still outputs the response and logs with blank token fields

bats_require_minimum_version 1.5.0

SCRIPT="$BATS_TEST_DIRNAME/../gfetch"
MOCKS="$BATS_TEST_DIRNAME/mocks"

setup() {
  export PATH="$MOCKS:$PATH"
  export GEMINI_GAIN_LOG="$(mktemp)"
}

teardown() {
  rm -f "$GEMINI_GAIN_LOG"
}

# AC1 — stdout contains response text
@test "gfetch writes Gemini response to stdout" {
  export MOCK_GEMINI_RESPONSE="Here are the API endpoints."
  run "$SCRIPT" "https://example.com/api"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Here are the API endpoints."* ]]
}

# AC2 — stderr shows raw→summary savings line
@test "gfetch writes raw→summary savings line to stderr" {
  run --separate-stderr "$SCRIPT" "https://example.com/api"
  [ "$status" -eq 0 ]
  [[ "$stderr" == *"[gfetch]"* ]]
  [[ "$stderr" == *"raw"* ]]
  [[ "$stderr" == *"summary"* ]]
  [[ "$stderr" == *"saved"* ]]
}

@test "gfetch savings line includes the URL" {
  run --separate-stderr "$SCRIPT" "https://example.com/api"
  [[ "$stderr" == *"example.com"* ]]
}

@test "gfetch savings line includes a percentage" {
  run --separate-stderr "$SCRIPT" "https://example.com/api"
  [[ "$stderr" == *"%"* ]]
}

# AC3 — CSV row with raw_tokens populated
@test "gfetch appends a CSV row to the log file" {
  "$SCRIPT" "https://example.com/api" >/dev/null
  [ "$(wc -l < "$GEMINI_GAIN_LOG")" -eq 1 ]
}

@test "gfetch CSV row has correct mode field" {
  "$SCRIPT" "https://example.com/api" >/dev/null
  row=$(cat "$GEMINI_GAIN_LOG")
  [[ "$row" == *",gfetch,"* ]]
}

@test "gfetch CSV row has non-empty raw_tokens field" {
  "$SCRIPT" "https://example.com/api" >/dev/null
  row=$(cat "$GEMINI_GAIN_LOG")
  # raw_tokens is the 4th column — should be a number > 0
  raw_tok=$(echo "$row" | cut -d',' -f4)
  [ -n "$raw_tok" ]
  [ "$raw_tok" -gt 0 ]
}

# AC4 — extraction prompt is forwarded to Gemini
@test "gfetch accepts an optional extraction prompt without error" {
  run "$SCRIPT" "https://example.com/api" "list the auth endpoints"
  [ "$status" -eq 0 ]
}

# AC5 — graceful degradation when jq is missing
@test "gfetch still outputs response when jq is missing" {
  export MOCK_GEMINI_RESPONSE="Fetched content summary."
  local no_jq
  no_jq="$(mktemp -d)"
  printf '#!/usr/bin/env bash\nexit 127\n' > "$no_jq/jq"
  chmod +x "$no_jq/jq"
  PATH="$no_jq:$MOCKS:$(echo "$PATH" | tr ':' '\n' | grep -v "$MOCKS" | tr '\n' ':')"
  run "$SCRIPT" "https://example.com/api"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Fetched content summary."* ]]
  rm -rf "$no_jq"
}

@test "gfetch logs a row even when jq is missing" {
  local no_jq
  no_jq="$(mktemp -d)"
  printf '#!/usr/bin/env bash\nexit 127\n' > "$no_jq/jq"
  chmod +x "$no_jq/jq"
  PATH="$no_jq:$MOCKS:$(echo "$PATH" | tr ':' '\n' | grep -v "$MOCKS" | tr '\n' ':')"
  "$SCRIPT" "https://example.com/api" >/dev/null
  [ "$(wc -l < "$GEMINI_GAIN_LOG")" -eq 1 ]
  rm -rf "$no_jq"
}
