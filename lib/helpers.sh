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
  local stow_dir="$SCRIPT_DIR/stow"
  local name
  for d in "$stow_dir"/*/; do
    [ -d "$d" ] || continue
    name=$(basename "$d")
    [[ "$name" == .* ]] && continue
    echo "$name"
  done
}
