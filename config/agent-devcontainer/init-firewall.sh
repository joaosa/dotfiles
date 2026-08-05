#!/usr/bin/env bash
# Adapted from OpenAI Codex's secure devcontainer firewall. This is a
# Defense-in-depth IP allowlist for the audit container boundary.
set -euo pipefail
IFS=$'\n\t'

allowed_domains_file=/etc/agent-devcontainer/allowed-domains
# Baked into the image and validated as 0/1 by apply-firewall.sh, this script's
# only entry point (the sudoers rule exposes nothing else), so no fallback
# default here — the Dockerfile ARG is the single owner of the default.
include_github_meta_ranges="$(tr -d '[:space:]' < /etc/agent-devcontainer/include-github-meta)"
ipv4_re='^[0-9]{1,3}(\.[0-9]{1,3}){3}$'
# The same dotted quad plus a /prefix, for GitHub's published CIDR ranges.
ipv4_cidr_re='^[0-9]{1,3}(\.[0-9]{1,3}){3}/[0-9]{1,2}$'
firewall_ready=0

fail_closed() {
  if [ "$firewall_ready" != 1 ]; then
    # Flush before dropping: a partial run may have appended broad ACCEPT rules
    # (e.g. DNS) that would otherwise survive alongside the DROP policy and keep
    # egress open in the supposedly closed state. Rules beat policy.
    iptables -F 2>/dev/null || true
    iptables -t nat -F 2>/dev/null || true
    ip6tables -F 2>/dev/null || true
    iptables -P INPUT DROP 2>/dev/null || true
    iptables -P FORWARD DROP 2>/dev/null || true
    iptables -P OUTPUT DROP 2>/dev/null || true
    ip6tables -P INPUT DROP 2>/dev/null || true
    ip6tables -P FORWARD DROP 2>/dev/null || true
    ip6tables -P OUTPUT DROP 2>/dev/null || true
  fi
}
trap fail_closed EXIT

# Non-emptiness is apply-firewall.sh's check: it validates and writes this file
# immediately before invoking us, with the actionable "rebuild the image" error.
mapfile -t allowed_domains < <(sed '/^\s*#/d;/^\s*$/d' "$allowed_domains_file")

add_ipv4_cidr() {
  local cidr="$1"
  if [[ ! "$cidr" =~ $ipv4_cidr_re ]]; then
    echo "ERROR: invalid IPv4 CIDR: $cidr" >&2
    exit 1
  fi
  printf 'add allowed-domains %s\n' "$cidr" >> "$ipset_batch"
}

configure_ipv6_default_deny() {
  # A host with IPv6 disabled has no v6 egress to secure, so skip rather than
  # bricking the container. If ip6tables IS present we must reach default-deny;
  # the flushes are best-effort but the DROP policies below are mandatory.
  if ! command -v ip6tables >/dev/null 2>&1 \
    || ! ip6tables -L >/dev/null 2>&1; then
    echo "[devcontainer] IPv6 stack unavailable; skipping IPv6 deny" >&2
    return 0
  fi
  ip6tables -F 2>/dev/null || true
  ip6tables -X 2>/dev/null || true
  ip6tables -t mangle -F 2>/dev/null || true
  ip6tables -t mangle -X 2>/dev/null || true
  ip6tables -t nat -F 2>/dev/null || true
  ip6tables -t nat -X 2>/dev/null || true
  ip6tables -A INPUT -i lo -j ACCEPT
  ip6tables -A OUTPUT -o lo -j ACCEPT
  ip6tables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
  ip6tables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
  ip6tables -P INPUT DROP
  ip6tables -P FORWARD DROP
  ip6tables -P OUTPUT DROP
}

# Preserve Docker's embedded-DNS NAT rules while replacing the filter policy.
docker_dns_rules="$(iptables-save -t nat | grep '127\.0\.0\.11' || true)"
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X
ip6tables -F 2>/dev/null || true
ip6tables -X 2>/dev/null || true
ip6tables -t nat -F 2>/dev/null || true
ip6tables -t nat -X 2>/dev/null || true
ip6tables -t mangle -F 2>/dev/null || true
ip6tables -t mangle -X 2>/dev/null || true
ipset destroy allowed-domains 2>/dev/null || true

# A prior run leaves the default policies at DROP. Temporarily open them while
# rebuilding the complete ruleset; the EXIT trap fails closed on any error.
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
ip6tables -P INPUT ACCEPT 2>/dev/null || true
ip6tables -P FORWARD ACCEPT 2>/dev/null || true
ip6tables -P OUTPUT ACCEPT 2>/dev/null || true

if [ -n "$docker_dns_rules" ]; then
  iptables -t nat -N DOCKER_OUTPUT 2>/dev/null || true
  iptables -t nat -N DOCKER_POSTROUTING 2>/dev/null || true
  while IFS= read -r rule; do
    [ -z "$rule" ] && continue
    IFS=' ' read -r -a rule_parts <<< "$rule"
    iptables -t nat "${rule_parts[@]}"
  done <<< "$docker_dns_rules"
fi

# DNS only to the resolvers this container actually uses, not to any host: a
# wide-open port 53 is a data-exfiltration tunnel that bypasses the domain
# allowlist entirely. Derive them from resolv.conf rather than hardcoding
# Docker's embedded resolver, which only exists on user-defined networks:
# colima's default bridge points resolv.conf at the VM resolver instead, and
# hardcoding 127.0.0.11 there kills DNS the moment the DROP policy lands. Each
# of these forwards to upstream either way, so the exfil surface is unchanged.
# Inbound replies ride the ESTABLISHED,RELATED rule below, so no --sport 53
# INPUT rule (which any peer could match by choosing source port 53) is needed.
dns_endpoints=0
while IFS= read -r nameserver; do
  # IPv6 resolvers are unusable here: IPv6 egress is default-deny below.
  if [[ ! "$nameserver" =~ $ipv4_re ]]; then
    echo "[devcontainer] Ignoring non-IPv4 nameserver: $nameserver" >&2
    continue
  fi
  iptables -A OUTPUT -p udp -d "$nameserver" --dport 53 -j ACCEPT
  iptables -A OUTPUT -p tcp -d "$nameserver" --dport 53 -j ACCEPT
  dns_endpoints=$((dns_endpoints + 1))
  echo "[devcontainer] DNS allowed to $nameserver"
done < <(awk '$1 == "nameserver" { print $2 }' /etc/resolv.conf | sort -u)
if [ "$dns_endpoints" -eq 0 ]; then
  echo "ERROR: no IPv4 nameserver in /etc/resolv.conf; DNS would be dead" >&2
  exit 1
fi
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

ipset create allowed-domains hash:net
# Entries accumulate here and load in one `ipset restore` at the end: a fork
# per entry adds seconds once GitHub's meta ranges (hundreds of CIDRs) join.
ipset_batch="$(mktemp)"

# Resolve concurrently: serial digs cost seconds on every start, and a single
# slow resolver retry would stall the whole list. Domains are safe as file
# names: apply-firewall.sh validated them against [a-zA-Z0-9.-].
echo "[devcontainer] Resolving ${#allowed_domains[@]} allowlisted domains"
resolve_dir="$(mktemp -d)"
for domain in "${allowed_domains[@]}"; do
  dig +short A "$domain" > "$resolve_dir/$domain" &
done
wait
for domain in "${allowed_domains[@]}"; do
  # `dig +short A` may print the CNAME chain before the final addresses.
  ips="$(grep -E "$ipv4_re" "$resolve_dir/$domain" || true)"
  if [ -z "$ips" ]; then
    echo "ERROR: failed to resolve $domain" >&2
    exit 1
  fi
  while IFS= read -r ip; do
    printf 'add allowed-domains %s\n' "$ip" >> "$ipset_batch"
  done <<< "$ips"
done

if [ "$include_github_meta_ranges" = 1 ]; then
  github_meta="$(curl -fsSL --connect-timeout 10 https://api.github.com/meta)"
  echo "$github_meta" | jq -e '.web and .api and .git' >/dev/null
  while IFS= read -r cidr; do
    [ -z "$cidr" ] && continue
    [[ "$cidr" == *:* ]] || add_ipv4_cidr "$cidr"
  done < <(echo "$github_meta" | jq -r '((.web // []) + (.api // []) + (.git // []))[]' | sort -u)
fi

ipset -exist restore < "$ipset_batch"
rm -rf "$resolve_dir" "$ipset_batch"

iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m set --match-set allowed-domains dst -j ACCEPT
iptables -A INPUT -j REJECT --reject-with icmp-admin-prohibited
iptables -A OUTPUT -j REJECT --reject-with icmp-admin-prohibited
iptables -A FORWARD -j REJECT --reject-with icmp-admin-prohibited
configure_ipv6_default_deny

# Assert DNS survived the DROP policy before trusting the negative checks: with
# resolution dead, every curl below fails for the wrong reason and a firewall
# that blocks everything would look like one that blocks exactly the right hosts.
if ! dig +short A example.com | grep -qE "$ipv4_re"; then
  echo "ERROR: DNS resolution is broken under the firewall policy" >&2
  exit 1
fi

# Negative checks are the security-critical assertions: a non-allowlisted host
# and any IPv6 egress must be blocked. These fail the firewall hard.
if curl --connect-timeout 5 https://example.com >/dev/null 2>&1; then
  echo "ERROR: firewall allowed a non-allowlisted domain" >&2
  exit 1
fi
if curl --connect-timeout 5 -6 https://example.com >/dev/null 2>&1; then
  echo "ERROR: firewall allowed IPv6 egress" >&2
  exit 1
fi

# Positive check: confirm at least one configured domain is reachable, drawn
# from the allowlist rather than hardcoded endpoints. A single domain whose CDN
# rotated its IP away from the snapshot must not brick startup, so only a total
# failure (every probed domain unreachable) is fatal; partial misses warn.
reachable=0
probed=0
for domain in "${allowed_domains[@]}"; do
  [ "$probed" -ge 5 ] && break
  probed=$((probed + 1))
  if curl --connect-timeout 5 "https://$domain" >/dev/null 2>&1; then
    reachable=1
    break
  fi
done
if [ "$probed" -gt 0 ] && [ "$reachable" -ne 1 ]; then
  echo "ERROR: firewall blocked every probed allowlisted domain" >&2
  exit 1
fi

firewall_ready=1
echo "[devcontainer] Firewall verification passed"
