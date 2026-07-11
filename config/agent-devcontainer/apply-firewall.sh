#!/usr/bin/env bash
# Root-invoked firewall applier. Runs via a no-argument sudo rule so the
# untrusted vscode user cannot supply the allowlist payload: the domain list is
# read from PID 1's environment (set by the container runtime from containerEnv,
# not writable by the agent), validated here, then written to a root-only path.
set -euo pipefail

# Read a variable from PID 1's environment (NUL-delimited), ignoring whatever
# the calling shell exported. This is the runtime-provided, tamper-proof value.
init_env() {
  local name="$1" kv
  while IFS= read -r -d '' kv; do
    if [ "${kv%%=*}" = "$name" ]; then
      printf '%s' "${kv#*=}"
      return 0
    fi
  done < /proc/1/environ
  return 1
}

domains_raw="$(init_env AGENT_ALLOWED_DOMAINS || true)"
domains_raw="${domains_raw:-api.openai.com api.anthropic.com}"
include_meta="$(init_env AGENT_INCLUDE_GITHUB_META_RANGES || true)"
export AGENT_INCLUDE_GITHUB_META_RANGES="${include_meta:-1}"

mapfile -t domains < <(printf '%s\n' "$domains_raw" | tr ', ' '\n' | sed '/^$/d' | sort -u)
if [ "${#domains[@]}" -eq 0 ]; then
  echo "[devcontainer] No allowed domains configured" >&2
  exit 1
fi

tmp_file="$(mktemp)"
trap 'rm -f "$tmp_file"' EXIT
for domain in "${domains[@]}"; do
  if [[ ! "$domain" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*\.[a-zA-Z]{2,}$ ]]; then
    echo "[devcontainer] Invalid domain: $domain" >&2
    exit 1
  fi
  printf '%s\n' "$domain" >> "$tmp_file"
done

install -d -m 0755 /etc/agent-devcontainer
install -o root -g root -m 0444 "$tmp_file" /etc/agent-devcontainer/allowed-domains
/usr/local/bin/init-firewall.sh
