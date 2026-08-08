#!/usr/bin/env bash
# Root-invoked firewall applier. Runs via a no-argument sudo rule so the
# untrusted vscode user cannot supply the allowlist payload: the domain list is
# baked into the image at build time as a root-owned, world-unwritable file,
# validated here, then written to a root-only path the firewall reads.
set -euo pipefail

config_dir=/etc/agent-devcontainer
domains_in="$config_dir/allowed-domains.in"
meta_in="$config_dir/include-github-meta"

# Validation failure must fail closed, not permissive: exiting before
# init-firewall.sh arms its own trap would leave egress wide open under
# AGENT_ENABLE_FIREWALL=1. Flush first — rules beat policy.
firewall_applied=0
fail_closed() {
  if [ -n "${tmp_file:-}" ]; then
    rm -f "$tmp_file"
  fi
  if [ "$firewall_applied" != 1 ]; then
    iptables -F 2>/dev/null || true
    iptables -t nat -F 2>/dev/null || true
    ip6tables -F 2>/dev/null || true
    iptables -P INPUT DROP 2>/dev/null || true
    iptables -P FORWARD DROP 2>/dev/null || true
    iptables -P OUTPUT DROP 2>/dev/null || true
    ip6tables -P INPUT DROP 2>/dev/null || true
    ip6tables -P FORWARD DROP 2>/dev/null || true
    ip6tables -P OUTPUT DROP 2>/dev/null || true
    echo "[devcontainer] Firewall inputs invalid; egress locked down fail-closed" >&2
  fi
}
trap fail_closed EXIT

# A baked input is only trustworthy if the agent could not have rewritten it
# between build and apply: reject symlinks (which could redirect the read into
# agent-writable storage) and anything not owned by root or writable by others.
require_trusted_file() {
  local file="$1" owner mode
  if [ -L "$file" ] || [ ! -f "$file" ]; then
    echo "[devcontainer] Missing or non-regular allowlist input: $file" >&2
    exit 1
  fi
  read -r owner mode <<< "$(stat -c '%u:%g %a' "$file")"
  if [ "$owner" != "0:0" ] || [ $((8#$mode & 8#022)) -ne 0 ]; then
    echo "[devcontainer] Untrusted allowlist input $file (owner $owner, mode $mode)" >&2
    exit 1
  fi
}

require_trusted_file "$domains_in"
require_trusted_file "$meta_in"

# An empty allowlist means the image was built without AGENT_ALLOWED_DOMAINS.
# Fail loudly instead of silently applying a narrower default: a firewall that
# quietly permits two domains looks identical to one applying the real policy.
mapfile -t domains < <(tr ', ' '\n' < "$domains_in" | sed '/^$/d' | sort -u)
if [ "${#domains[@]}" -eq 0 ]; then
  echo "[devcontainer] No allowed domains baked into this image; rebuild with" \
    "AGENT_ALLOWED_DOMAINS set, or disable AGENT_ENABLE_FIREWALL" >&2
  exit 1
fi

# Validate only: init-firewall.sh reads the trusted file itself, like the
# allowlist, so the flag has one channel and the Dockerfile ARG one default.
include_meta="$(tr -d '[:space:]' < "$meta_in")"
case "$include_meta" in
  0 | 1) ;;
  *)
    echo "[devcontainer] Invalid include-github-meta: $include_meta" >&2
    exit 1
    ;;
esac

tmp_file="$(mktemp)"
for domain in "${domains[@]}"; do
  if [[ ! "$domain" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*\.[a-zA-Z]{2,}$ ]]; then
    echo "[devcontainer] Invalid domain: $domain" >&2
    exit 1
  fi
  printf '%s\n' "$domain" >> "$tmp_file"
done

install -o root -g root -m 0444 "$tmp_file" "$config_dir/allowed-domains"
/usr/local/bin/init-firewall.sh
firewall_applied=1
