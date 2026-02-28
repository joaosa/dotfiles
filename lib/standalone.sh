#!/usr/bin/env bash
# Standalone module bootstrap — sourced by module header guards.
# Usage (at top of module):
#   [[ "${BASH_SOURCE[0]}" == "${0}" ]] && source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/standalone.sh"

set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[1]}")/.." && pwd)/lib/helpers.sh"
init_standalone
