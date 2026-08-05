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

# Both agents live in the image, so a self-update dies with the container and
# layer caching keeps serving old builds. Refresh here instead, throttled by a
# marker in the ~/.codex volume. Fleet opts in; audit and sandbox stay pinned.
# Runs before the firewall, so enabling both flags fetches outside the allowlist.
if [ "${AGENT_UPDATE_AGENTS:-0}" = "1" ] \
  && [ -z "$(find /home/vscode/.codex/.agent-update-stamp -mtime -1 2>/dev/null)" ]; then
  echo "[devcontainer] Checking for Claude Code and Codex updates"
  # The two checks are independent; overlap them so the slower download never
  # serializes behind the other.
  (
    timeout 120 claude update \
      || echo "[devcontainer] Claude update skipped; keeping installed build" >&2
  ) &
  claude_update=$!
  # npm re-downloads the ~130MB platform binary even when current, so compare
  # versions first. NPM_CONFIG_MINIMUM_RELEASE_AGE keeps @latest off fresh publishes.
  codex_have=$(codex --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || true)
  codex_want=$(timeout 30 npm view @openai/codex version 2>/dev/null || true)
  if [ -n "$codex_want" ] && [ "$codex_have" != "$codex_want" ]; then
    timeout 600 npm install --global "@openai/codex@$codex_want" \
      || echo "[devcontainer] Codex update skipped; keeping installed build" >&2
  fi
  wait "$claude_update"
  touch /home/vscode/.codex/.agent-update-stamp || true
fi

# Codex's TUI ignores CODEX_API_KEY, so exchange it for persistent ~/.codex
# credentials. Unconditional: that is what lets a rotated key beat a stale login.
if [ -n "${CODEX_API_KEY:-}" ]; then
  printf '%s' "$CODEX_API_KEY" | codex login --with-api-key \
    || echo "[devcontainer] Codex: API key login failed; run codex login manually" >&2
fi

if [ "${AGENT_ENABLE_FIREWALL:-0}" != "1" ]; then
  echo "[devcontainer] Outbound firewall: permissive"
  exit 0
fi

echo "[devcontainer] Outbound firewall: strict"
# The applier runs as root and reads the allowlist from a root-owned file baked
# into the image, so the untrusted user never supplies the domain payload or any
# firewall arguments.
sudo /usr/local/bin/apply-firewall.sh
