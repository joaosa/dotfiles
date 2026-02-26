#!/usr/bin/env bash
# Module: Language runtimes and packages (Rust, Node, Go, npm, cargo)

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && { set -euo pipefail; source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/helpers.sh"; init_standalone; }

run() {
  # Rust
  if ! command -v rustc >/dev/null 2>&1; then
    if ! is_dry_run "install Rust"; then
      rustup-init -y --default-toolchain stable
      log_success "Installed Rust"
    fi
  else
    if ! is_dry_run; then
      rustup toolchain list | grep -q stable || rustup install stable
      rustup default stable >/dev/null 2>&1 || true
    fi
    log_skip "Rust already installed"
  fi

  # Node.js via asdf
  install_asdf_language "nodejs" "https://github.com/asdf-vm/asdf-nodejs.git"

  # npm packages
  log_info "Installing npm packages..."
  install_asdf_packages "nodejs" "${NPM_PACKAGES[@]}"

  # Go via asdf
  install_asdf_language "golang" "https://github.com/asdf-community/asdf-golang.git"

  # Go packages
  log_info "Installing Go packages..."
  install_asdf_packages "golang" "${GO_PACKAGES[@]}"

  # Cargo packages
  log_info "Installing Cargo packages..."
  install_cargo_packages "${CARGO_PACKAGES[@]}"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && { run; print_summary; }
