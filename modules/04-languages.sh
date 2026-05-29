#!/usr/bin/env bash
# Module: Legacy language tools not yet managed by Nix

# shellcheck disable=SC1091
[[ "${BASH_SOURCE[0]}" == "${0}" ]] && source "${BASH_SOURCE[0]%/*}/../lib/standalone.sh"

run() {
  log_info "Installing legacy Cargo packages..."
  install_cargo_packages "${CARGO_PACKAGES[@]}"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && { run; print_summary; }
