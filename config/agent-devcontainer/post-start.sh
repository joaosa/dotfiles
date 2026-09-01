#!/usr/bin/env bash
set -euo pipefail

# Runs as the unprivileged remote user (vscode), which is NOT in sudoers.
# Every privileged action — arming the firewall, chowning the named volumes,
# scoping the forwarded SSH agent socket — now happens in the root entrypoint
# (entrypoint.sh) before this script runs, so nothing here needs sudo. The
# firewall is therefore already armed by the time the network fetches below
# run: agent-binary updates never ride an unfiltered-egress window.
#
# The SSH socket forwarded by the fleet profile is a real trust hand-off: the
# agent can sign auth challenges with the host's keys against any host it can
# reach. The domain allowlist is what bounds "any host" down to GitHub and the
# pinned list; the entrypoint scopes the socket 0600 to vscode alone.

# Both agents live in the image, so a self-update dies with the container and
# layer caching keeps serving old builds. Refresh here instead, throttled by a
# container-local stamp — the binaries are container-local too, so a stamp on
# a persistent volume would let a recreated container skip the refresh. Fleet
# opts in; audit stays pinned. The hosts it needs are allowlisted;
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
    # npm does not support auditing global installs, so override the profile's
    # audit=true for this command instead of emitting its global/audit warning.
    timeout 600 npm install --global --no-audit "@openai/codex@$codex_want" \
      || { echo "[devcontainer] Codex update skipped; keeping installed build" >&2; update_ok=0; }
  fi
  wait "$claude_update" || update_ok=0
  # Stamp only a fully successful refresh so transient failures retry.
  if [ "$update_ok" = 1 ]; then
    touch "$stamp"
  fi
fi

# Codex's TUI ignores CODEX_API_KEY, so exchange it for persistent ~/.codex
# credentials. The hash gate skips the round trip when the key is unchanged;
# a failed exchange is fatal, or a rotated-but-rejected key would silently
# keep using the previous login.
if [ -n "${CODEX_API_KEY:-}" ]; then
  key_hash=$(printf '%s' "$CODEX_API_KEY" | sha256sum | cut -d' ' -f1)
  hash_file=/home/vscode/.codex/.api-key-hash
  if [ ! -f "$hash_file" ] || [ "$(cat "$hash_file")" != "$key_hash" ]; then
    if printf '%s' "$CODEX_API_KEY" | codex login --with-api-key; then
      printf '%s\n' "$key_hash" > "$hash_file"
    else
      echo "[devcontainer] Codex API key login failed; previous credentials may be stale" >&2
      exit 1
    fi
  fi
fi
