#!/usr/bin/env bash
# Module: Language runtimes and packages (Rust, Node, Go, npm, cargo)

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && source "${BASH_SOURCE[0]%/*}/../lib/standalone.sh"

run() {
  # Rust
  ensure_installed "Rust" \
    'command -v rustc >/dev/null 2>&1' \
    'rustup-init -y --default-toolchain stable'

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
