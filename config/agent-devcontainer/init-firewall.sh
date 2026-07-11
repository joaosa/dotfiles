#!/usr/bin/env bash
# Adapted from OpenAI Codex's secure devcontainer firewall. This is a
# Defense-in-depth IP allowlist for the audit container boundary.
set -euo pipefail
IFS=$'\n\t'

allowed_domains_file=/etc/agent-devcontainer/allowed-domains
include_github_meta_ranges="${AGENT_INCLUDE_GITHUB_META_RANGES:-1}"
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

mapfile -t allowed_domains < <(sed '/^\s*#/d;/^\s*$/d' "$allowed_domains_file")
if [ "${#allowed_domains[@]}" -eq 0 ]; then
  echo "ERROR: no allowed domains configured" >&2
  exit 1
fi

add_ipv4_cidr() {
  local cidr="$1"
  if [[ ! "$cidr" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}/[0-9]{1,2}$ ]]; then
    echo "ERROR: invalid IPv4 CIDR: $cidr" >&2
    exit 1
  fi
  ipset add allowed-domains "$cidr" -exist
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

# DNS only to Docker's embedded resolver, not to any host: a wide-open port 53
# is a data-exfiltration tunnel that bypasses the domain allowlist entirely.
# Inbound replies ride the ESTABLISHED,RELATED rule below, so no --sport 53
# INPUT rule (which any peer could match by choosing source port 53) is needed.
iptables -A OUTPUT -p udp -d 127.0.0.11 --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp -d 127.0.0.11 --dport 53 -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

ipset create allowed-domains hash:net
for domain in "${allowed_domains[@]}"; do
  echo "[devcontainer] Resolving $domain"
  # `dig +short A` may print the CNAME chain before the final addresses.
  ips="$(dig +short A "$domain" | grep -E '^[0-9]{1,3}(\.[0-9]{1,3}){3}$' || true)"
  if [ -z "$ips" ]; then
    echo "ERROR: failed to resolve $domain" >&2
    exit 1
  fi
  while IFS= read -r ip; do
    ipset add allowed-domains "$ip" -exist
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
