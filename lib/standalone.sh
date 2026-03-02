#!/usr/bin/env bash
# Standalone module bootstrap — sourced by module header guards.
# Usage (at top of module):
#   [[ "${BASH_SOURCE[0]}" == "${0}" ]] && source "${BASH_SOURCE[0]%/*}/../lib/standalone.sh"

set -euo pipefail
source "${BASH_SOURCE[1]%/*}/../lib/helpers.sh"
init_standalone
