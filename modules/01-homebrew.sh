#!/usr/bin/env bash
# Module: Homebrew installation for legacy modules

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && source "${BASH_SOURCE[0]%/*}/../lib/standalone.sh"

run() {
  # Install Homebrew if missing (pinned to specific commit with SHA256 verification)
  if ! command -v brew >/dev/null 2>&1; then
    log_info "Installing Homebrew (commit: ${HOMEBREW_INSTALL_COMMIT:0:8})..."
    if ! is_dry_run "install Homebrew"; then
      local install_url="https://raw.githubusercontent.com/Homebrew/install/${HOMEBREW_INSTALL_COMMIT}/install.sh"
      local temp_script="/tmp/homebrew-install-${HOMEBREW_INSTALL_COMMIT:0:8}.sh"
      register_temp_file "$temp_script"

      if ! download_if_missing "$temp_script" "$install_url" "$HOMEBREW_INSTALL_SHA256"; then
        die "Failed to download Homebrew installer"
      fi

      /bin/bash "$temp_script"
      rm -f "$temp_script"
      export PATH="/opt/homebrew/bin:/usr/local/bin${PATH:+:$PATH}"
      log_success "Installed Homebrew"
    fi
  else
    log_skip "Homebrew already installed"
  fi
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && { run; print_summary; }
