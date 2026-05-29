#!/usr/bin/env bash
# Verification helpers used by doctor.sh

check_binary() {
  local name="$1" description="${2:-$1}"
  if command -v "$name" >/dev/null 2>&1; then
    log_success "$description"
  else
    log_error "$description: not found"
  fi
}

check_file() {
  local path="$1" description="${2:-$1}"
  if [ -f "$path" ]; then
    log_success "$description"
  else
    log_error "$description: missing"
  fi
}

check_dir() {
  local path="$1" description="${2:-$1}"
  if [ -d "$path" ]; then
    log_success "$description"
  else
    log_error "$description: missing"
  fi
}
