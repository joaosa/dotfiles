#!/usr/bin/env bash
# Module: Install dotfiles via GNU Stow (auto-discovers packages)

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && { set -euo pipefail; source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/helpers.sh"; init_standalone; }

run() {
  local stow_dir="$SCRIPT_DIR/stow"

  if [ ! -d "$stow_dir" ]; then
    log_error "Stow directory not found: $stow_dir"
    return 1
  fi

  local -a stow_dirs=()
  while IFS= read -r pkg; do
    stow_dirs+=("$pkg")
  done < <(discover_stow_packages)

  if [ ${#stow_dirs[@]} -eq 0 ]; then
    log_warn "No stow packages found in $stow_dir"
    return 0
  fi

  log_info "Discovered stow packages: ${stow_dirs[*]}"
  if is_dry_run "stow: ${stow_dirs[*]}"; then return 0; fi

  # Stow each package individually for granular error reporting
  for pkg in "${stow_dirs[@]}"; do
    if stow -d "$stow_dir" -t "$HOME" --restow "$pkg"; then
      log_success "Stowed $pkg"
    else
      log_error "Failed to stow $pkg"
    fi
  done
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && { run; print_summary; }
