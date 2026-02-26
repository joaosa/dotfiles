#!/usr/bin/env bash
# Module: Service configuration (Syncthing)

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && { set -euo pipefail; source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/helpers.sh"; init_standalone; }

run() {
  # Syncthing config path varies by OS
  local syncthing_config
  if is_macos; then
    syncthing_config="$HOME/Library/Application Support/Syncthing/config.xml"
  else
    syncthing_config="${XDG_CONFIG_HOME:-$HOME/.config}/syncthing/config.xml"
  fi

  # Syncthing - enable built-in HTTPS
  if [ -f "$syncthing_config" ]; then
    if grep -q '<gui enabled="true" tls="false"' "$syncthing_config"; then
      if ! is_dry_run "enable Syncthing HTTPS"; then
        sed_inplace 's/<gui enabled="true" tls="false"/<gui enabled="true" tls="true"/' "$syncthing_config"
        log_success "Enabled Syncthing HTTPS"
      fi
    else
      log_skip "Syncthing HTTPS already enabled"
    fi
  fi

  # Syncthing - start as background service
  if is_macos; then
    if ! brew services info syncthing --json 2>/dev/null | grep -q '"running":true'; then
      if ! is_dry_run "start syncthing service"; then
        brew services start syncthing
        log_success "Started syncthing service"
      fi
    else
      log_skip "syncthing service already running"
    fi
  elif is_linux; then
    if ! systemctl --user is-active syncthing >/dev/null 2>&1; then
      if ! is_dry_run "start syncthing service"; then
        systemctl --user enable --now syncthing
        log_success "Started syncthing service"
      fi
    else
      log_skip "syncthing service already running"
    fi
  fi
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && { run; print_summary; }
