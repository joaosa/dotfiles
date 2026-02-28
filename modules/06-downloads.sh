#!/usr/bin/env bash
# Module: Configuration file downloads with integrity verification

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/standalone.sh"

run() {
  download_if_missing "$KUBECTL_ALIASES_PATH" "$KUBECTL_ALIASES_URL" "$KUBECTL_ALIASES_SHA256"
  download_if_missing "$WHISPER_MODEL_PATH" "$WHISPER_MODEL_URL" "$WHISPER_MODEL_SHA256"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && { run; print_summary; }
