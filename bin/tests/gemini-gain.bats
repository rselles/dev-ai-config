#!/usr/bin/env bats
# Tests for gemini-gain
#
# Acceptance criteria:
#   AC1: Given a log with rows, prints cumulative totals per mode
#   AC2: Given an empty log file, exits cleanly with a "no data" message
#   AC3: Given no log file, exits cleanly with a "no data" message

SCRIPT="$BATS_TEST_DIRNAME/../gemini-gain"

setup() {
  export GEMINI_GAIN_LOG="$(mktemp)"
}

teardown() {
  rm -f "$GEMINI_GAIN_LOG"
}

_write_gsearch_row() {
  # tab-separated: timestamp  mode  target  raw_tokens  summary_tokens  gemini_input_tokens  gemini_output_tokens
  printf '2026-04-12T10:00:00Z\tgsearch\twhat is Rust\t\t150\t7224\t24\n' >> "$GEMINI_GAIN_LOG"
}

_write_gfetch_row() {
  printf '2026-04-12T10:01:00Z\tgfetch\thttps://example.com/api\t24200\t612\t7224\t24\n' >> "$GEMINI_GAIN_LOG"
}

# AC1 — cumulative totals
@test "gemini-gain prints output for a log with rows" {
  _write_gsearch_row
  _write_gfetch_row
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}

@test "gemini-gain output includes gsearch section" {
  _write_gsearch_row
  run "$SCRIPT"
  [[ "$output" == *"gsearch"* ]]
}

@test "gemini-gain output includes gfetch section" {
  _write_gfetch_row
  run "$SCRIPT"
  [[ "$output" == *"gfetch"* ]]
}

@test "gemini-gain output includes total calls count" {
  _write_gsearch_row
  _write_gsearch_row
  run "$SCRIPT"
  # Two gsearch calls — output should reflect that
  [[ "$output" == *"2"* ]]
}

@test "gemini-gain output includes gemini input token total" {
  _write_gfetch_row
  run "$SCRIPT"
  # gemini_input_tokens = 7224
  [[ "$output" == *"7224"* ]] || [[ "$output" == *"7,224"* ]]
}

# AC2 — empty log
@test "gemini-gain handles empty log file cleanly" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"no data"* ]] || [[ "$output" == *"No data"* ]]
}

# AC3 — missing log file
@test "gemini-gain handles missing log file cleanly" {
  rm -f "$GEMINI_GAIN_LOG"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"no data"* ]] || [[ "$output" == *"No data"* ]]
}
