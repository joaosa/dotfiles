#!/usr/bin/env bash
set -euo pipefail

if [ -n "${SSH_AUTH_SOCK:-}" ]; then
  if [ ! -S "$SSH_AUTH_SOCK" ]; then
    echo "[devcontainer] SSH agent socket is unavailable: $SSH_AUTH_SOCK" >&2
    exit 1
  fi
  sudo chown vscode:vscode "$SSH_AUTH_SOCK"
  sudo chmod 0600 "$SSH_AUTH_SOCK"
  echo "[devcontainer] SSH agent socket permissions refreshed"
fi

if [ "${AGENT_ENABLE_FIREWALL:-0}" != "1" ]; then
  echo "[devcontainer] Outbound firewall: permissive"
  exit 0
fi

echo "[devcontainer] Outbound firewall: strict"
# The applier runs as root and reads the allowlist from PID 1's environment, so
# the untrusted user never supplies the domain payload or firewall arguments.
sudo /usr/local/bin/apply-firewall.sh
