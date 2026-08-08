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

# Firewall first: everything below does network fetches, and the fleet profile
# enables both flags — updating agent binaries during the one unfiltered-egress
# window would undercut the allowlist exactly where it matters most. The
# applier runs as root and reads the allowlist from a root-owned file baked
# into the image, so the untrusted user never supplies the domain payload.
if [ "${AGENT_ENABLE_FIREWALL:-0}" = "1" ]; then
  echo "[devcontainer] Outbound firewall: strict"
  sudo /usr/local/bin/apply-firewall.sh
else
  echo "[devcontainer] Outbound firewall: permissive"
fi

# Both agents live in the image, so a self-update dies with the container and
# layer caching keeps serving old builds. Refresh here instead, throttled by a
# container-local stamp — the binaries are container-local too, so a stamp on
# a persistent volume would let a recreated container skip the refresh. Fleet
# opts in; audit and sandbox stay pinned. The hosts it needs are allowlisted;
# a blocked fetch keeps the image-pinned build.
stamp=/home/vscode/.agent-update-stamp
if [ "${AGENT_UPDATE_AGENTS:-0}" = "1" ] \
  && [ -z "$(find "$stamp" -mtime -1 2>/dev/null)" ]; then
  echo "[devcontainer] Checking for Claude Code and Codex updates"
  update_ok=1
  # The two checks are independent; overlap them so the slower download never
  # serializes behind the other.
  (
    timeout 120 claude update \
      || { echo "[devcontainer] Claude update skipped; keeping installed build" >&2; exit 1; }
  ) &
  claude_update=$!
  # npm re-downloads the ~130MB platform binary even when current, so compare
  # versions first. Exact @x.y.z installs are exempt from
  # NPM_CONFIG_MINIMUM_RELEASE_AGE, so pick the newest version older than the
  # window ourselves; the sort -V guard refuses in-window downgrades.
  codex_have=$(codex --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || true)
  age_cutoff=$(date -u -d "${NPM_CONFIG_MINIMUM_RELEASE_AGE:-0} minutes ago" '+%Y-%m-%dT%H:%M:%S.000Z')
  codex_want=$(timeout 30 npm view @openai/codex time --json 2>/dev/null \
    | jq -r --arg cutoff "$age_cutoff" \
      'to_entries
       | map(select(.key | test("^[0-9]+\\.[0-9]+\\.[0-9]+$")) | select(.value <= $cutoff))
       | (max_by(.key | split(".") | map(tonumber)) // {}).key // empty' \
    || true)
  if [ -z "$codex_want" ]; then
    update_ok=0
  elif [ "$codex_have" != "$codex_want" ] \
    && [ "$(printf '%s\n' "$codex_have" "$codex_want" | sort -V | tail -n1)" = "$codex_want" ]; then
    timeout 600 npm install --global "@openai/codex@$codex_want" \
      || { echo "[devcontainer] Codex update skipped; keeping installed build" >&2; update_ok=0; }
  fi
  wait "$claude_update" || update_ok=0
  # Stamp only a fully successful refresh so transient failures retry.
  if [ "$update_ok" = 1 ]; then
    touch "$stamp"
  fi
fi

# Codex's TUI ignores CODEX_API_KEY, so exchange it for persistent ~/.codex
# credentials. Unconditional: that is what lets a rotated key beat a stale login.
if [ -n "${CODEX_API_KEY:-}" ]; then
  printf '%s' "$CODEX_API_KEY" | codex login --with-api-key \
    || echo "[devcontainer] Codex: API key login failed; run codex login manually" >&2
fi
