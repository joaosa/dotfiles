#!/usr/bin/env bash
# Module: Service configuration (Syncthing)

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && source "${BASH_SOURCE[0]%/*}/../lib/standalone.sh"

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
    ensure_service_running "syncthing" \
      'brew services info syncthing --json 2>/dev/null | grep -q "\"running\":true"' \
      'brew services start syncthing'
  elif is_linux; then
    ensure_service_running "syncthing" \
      'systemctl --user is-active syncthing >/dev/null 2>&1' \
      'systemctl --user enable --now syncthing'
  fi
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && { run; print_summary; }
