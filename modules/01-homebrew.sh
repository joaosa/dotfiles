#!/usr/bin/env bash
# Module: Homebrew installation, package management, and cleanup

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && { set -euo pipefail; source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/helpers.sh"; init_standalone; }

run() {
  # Install Homebrew if missing (pinned to specific commit with SHA256 verification)
  if ! command -v brew >/dev/null 2>&1; then
    log_info "Installing Homebrew (commit: ${HOMEBREW_INSTALL_COMMIT:0:8})..."
    if ! is_dry_run "install Homebrew"; then
      local install_url="https://raw.githubusercontent.com/Homebrew/install/${HOMEBREW_INSTALL_COMMIT}/install.sh"
      local temp_script
      temp_script=$(mktemp)
      register_temp_file "$temp_script"

      if ! curl -fsSL -m 120 -o "$temp_script" "$install_url"; then
        die "Failed to download Homebrew installer"
      fi

      local actual_sha256
      actual_sha256=$(sha256sum_portable "$temp_script" | awk '{print $1}')
      if [ "$actual_sha256" != "$HOMEBREW_INSTALL_SHA256" ]; then
        log_error "Homebrew installer checksum mismatch!"
        log_detail "Expected: $HOMEBREW_INSTALL_SHA256"
        log_detail "Got:      $actual_sha256"
        die "Refusing to run unverified installer"
      fi

      /bin/bash "$temp_script"
      rm -f "$temp_script"
      export PATH="/opt/homebrew/bin:/usr/local/bin${PATH:+:$PATH}"
      log_success "Installed Homebrew"
    fi
  else
    log_skip "Homebrew already installed"
  fi

  # Install from Brewfile
  if brew bundle check --file="$SCRIPT_DIR/Brewfile" >/dev/null 2>&1; then
    log_skip "All Brewfile packages already installed"
  elif ! is_dry_run "install Brewfile packages"; then
    log_info "Installing packages from Brewfile..."
    if ! bundle_output=$(brew bundle --file="$SCRIPT_DIR/Brewfile" 2>&1); then
      echo "$bundle_output"
      if echo "$bundle_output" | grep -q "must.*brew unpin"; then
        echo ""
        log_warn "Installation blocked by pinned dependencies."
        echo "$bundle_output" | grep "must.*brew unpin" | sed -E 's/.*`(brew unpin [^`]+)`.*/  \1/' | sort -u
      fi
      log_error "Brewfile installation failed"
      return 1
    fi
    log_success "Brewfile packages installed"
  fi

  # Pin packages
  if ! is_dry_run "pin all Homebrew packages"; then
    log_info "Pinning Homebrew packages..."
    pin_brew_packages
  fi

  # Clean up packages not in Brewfile
  if ! is_dry_run "clean up packages not in Brewfile"; then
    log_info "Checking for packages to clean up..."
    cleanup_output=$(brew bundle cleanup --force --file="$SCRIPT_DIR/Brewfile" 2>&1)
    if echo "$cleanup_output" | grep -qE "(Uninstall|Untap)"; then
      echo "$cleanup_output"
      log_success "Cleanup complete"
    else
      log_skip "No packages to clean up"
    fi
  fi
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && { run; print_summary; }
