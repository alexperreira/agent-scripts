#!/usr/bin/env bash

die() {
  echo "error: $*" >&2
  exit 1
}

warn() {
  echo "warning: $*" >&2
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

require_arg_value() {
  local flag="$1"
  local value="${2:-}"

  [[ -n "$value" ]] || die "missing value for ${flag}"
  [[ "$value" != --* ]] || die "missing value for ${flag}"
}

# run CMD... — execute, or print "[dry-run] CMD" when the global DRY_RUN is true.
# Callers set DRY_RUN (default false here so sourcing scripts needn't).
run() {
  if [[ "${DRY_RUN:-false}" == true ]]; then
    echo "[dry-run] $*"
  else
    "$@"
  fi
}
