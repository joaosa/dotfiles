#!/usr/bin/env bash
# Shared helper functions for bootstrap modules
# Sources focused libraries and provides module-init and utility functions.

_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/platform.sh
source "$_LIB_DIR/platform.sh"
# shellcheck source=lib/packages.sh
source "$_LIB_DIR/packages.sh"

# ============================================================================
# DRY RUN
# ============================================================================

# Check if dry run mode is active. If so, log and return 0 (true).
# Usage: if is_dry_run "install Prezto"; then return; fi
is_dry_run() {
  if [ "$DRY_RUN" = "true" ]; then
    [ $# -gt 0 ] && log_info "[DRY RUN] Would $1"
    return 0
  fi
  return 1
}

# ============================================================================
# IDEMPOTENT INSTALL
# ============================================================================

# Encapsulates the common check/dry-run/install/log pattern.
# Usage: ensure_installed "description" "check_command" "install_commands"
#   $1 — human-readable description (used in log messages)
#   $2 — shell command that succeeds (exit 0) when already installed
#   $3 — shell command(s) to run for installation
ensure_installed() {
  local description="$1" check_cmd="$2" install_cmd="$3"
  if eval "$check_cmd"; then
    log_skip "$description already installed"
  elif ! is_dry_run "install $description"; then
    eval "$install_cmd"
    log_success "Installed $description"
  fi
}

# ============================================================================
# MODULE INIT
# ============================================================================

# Call from standalone module execution to set up the environment.
# Usage (at top of module): init_standalone
init_standalone() {
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[1]}")/.." && pwd)"
  DRY_RUN="${DRY_RUN:-false}"
  source "$SCRIPT_DIR/lib/logging.sh"
  # helpers.sh is already sourced (we're in it)
  source "$SCRIPT_DIR/versions.env"
  reset_counters
}
