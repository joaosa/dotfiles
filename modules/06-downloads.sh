#!/usr/bin/env bash
# Module: Configuration file downloads with integrity verification

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && { set -euo pipefail; source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/helpers.sh"; init_standalone; }

run() {
  download_if_missing "$HOME/.kubectl_aliases" "$KUBECTL_ALIASES_URL" "$KUBECTL_ALIASES_SHA256"
  download_if_missing "$HOME/.local/share/whisper/ggml-base.en.bin" "$WHISPER_MODEL_URL" "$WHISPER_MODEL_SHA256"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && { run; print_summary; }
