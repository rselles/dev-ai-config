#!/usr/bin/env bash

session_store_key() {
  local transcript_path="${1:-}"
  local cwd="${2:-}"
  local scope=""

  if [ -n "$transcript_path" ]; then
    scope="$transcript_path"
  elif [ -n "$cwd" ]; then
    scope="$cwd"
  else
    return 1
  fi

  printf '%s' "$scope" | cksum | awk '{print $1}'
}

signals_file_path() {
  local dir="$1"
  local transcript_path="${2:-}"
  local cwd="${3:-}"
  local key

  key=$(session_store_key "$transcript_path" "$cwd") || return 1
  printf '%s/signals-%s.log\n' "$dir" "$key"
}

pending_file_path() {
  local dir="$1"
  local cwd="${2:-}"
  local key

  key=$(session_store_key "" "$cwd") || return 1
  printf '%s/pending-%s.md\n' "$dir" "$key"
}
