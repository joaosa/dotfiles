#!/usr/bin/env bash
# Module: Configuration file downloads with integrity verification

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && source "${BASH_SOURCE[0]%/*}/../lib/standalone.sh"

run() {
  download_if_missing "$KUBECTL_ALIASES_PATH" "$KUBECTL_ALIASES_URL" "$KUBECTL_ALIASES_SHA256"
  download_asr_model "$ASR_MODEL_DIR" "$ASR_MODEL_REPO" "$ASR_MODEL_COMMIT"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && { run; print_summary; }
