#!/usr/bin/env bash
# Module: Legacy ASR model download

# shellcheck disable=SC1091
[[ "${BASH_SOURCE[0]}" == "${0}" ]] && source "${BASH_SOURCE[0]%/*}/../lib/standalone.sh"

run() {
  download_asr_model "$ASR_MODEL_DIR" "$ASR_MODEL_REPO" "$ASR_MODEL_COMMIT"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && { run; print_summary; }
