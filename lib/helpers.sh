#!/usr/bin/env bash
# Shared helper functions for bootstrap modules
# Sources focused libraries and provides module-init and utility functions.

_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/platform.sh
source "$_LIB_DIR/platform.sh"
# shellcheck source=lib/downloads.sh
source "$_LIB_DIR/downloads.sh"
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

# Encapsulates the common check/dry-run/start/log pattern for services.
# Usage: ensure_service_running "name" "check_cmd" "start_cmd"
#   $1 — service name (used in log messages)
#   $2 — shell command that succeeds (exit 0) when service is already running
#   $3 — shell command(s) to start the service
ensure_service_running() {
  local name="$1" check_cmd="$2" start_cmd="$3"
  if eval "$check_cmd"; then
    log_skip "$name service already running"
  elif ! is_dry_run "start $name service"; then
    eval "$start_cmd"
    log_success "Started $name service"
  fi
}

# ============================================================================
# MODULE INIT
# ============================================================================

# Call from standalone module execution to set up the environment.
# Usage (at top of module): init_standalone
init_standalone() {
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[1]}")/.." && pwd)"
  STOW_DIR="$SCRIPT_DIR/stow"
  DRY_RUN="${DRY_RUN:-false}"
  source "$SCRIPT_DIR/lib/logging.sh"
  # helpers.sh is already sourced (we're in it)
  source "$SCRIPT_DIR/versions.env"
  reset_counters
}

# ============================================================================
# VERSION MANAGEMENT
# ============================================================================

get_tool_version() {
  local tool="$1"
  local tool_versions_file="$SCRIPT_DIR/.tool-versions"
  if [ -f "$tool_versions_file" ]; then
    grep "^${tool} " "$tool_versions_file" | awk '{print $2}'
  else
    echo ""
  fi
}

# ============================================================================
# STOW PACKAGE DISCOVERY
# ============================================================================

# Print one stow package name per line, skipping hidden directories.
discover_stow_packages() {
  local name
  for d in "$STOW_DIR"/*/; do
    [ -d "$d" ] || continue
    name=$(basename "$d")
    [[ "$name" == .* ]] && continue
    echo "$name"
  done
}
