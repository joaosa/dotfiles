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
# Real octets only: a garbage A record like 999.1.1.1 must be dropped here,
# not abort the whole batched `ipset restore` and brick the start fail-closed.
ipv4_octet='(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])'
ipv4_re="^${ipv4_octet}(\.${ipv4_octet}){3}\$"
# The same dotted quad plus a /prefix, for GitHub's published CIDR ranges.
ipv4_cidr_re="^${ipv4_octet}(\.${ipv4_octet}){3}/([0-9]|[12][0-9]|3[0-2])\$"
firewall_ready=0

# Local resolver for everything but its own uid; see "DNS filter" below.
dns_user=agent-dns
dns_conf=/etc/agent-devcontainer/dnsmasq.conf

# shellcheck source=firewall-lockdown.sh
. /usr/local/lib/firewall-lockdown.sh
fail_closed() {
  if [ "$firewall_ready" != 1 ]; then
    rm -rf "${resolve_dir:-}" "${ipset_batch:-}" "${probe_dir:-}" 2>/dev/null || true
    lockdown_egress
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

# Upstream DNS (from resolv.conf) only for the filter uid: any other uid
# reaching a resolver, on any port, could tunnel data out as lookups.
nameservers=()
while IFS= read -r nameserver; do
  # IPv6 resolvers are unusable here: IPv6 egress is default-deny below.
  if [[ ! "$nameserver" =~ $ipv4_re ]]; then
    echo "[devcontainer] Ignoring non-IPv4 nameserver: $nameserver" >&2
    continue
  fi
  for proto in udp tcp; do
    iptables -A OUTPUT -p "$proto" -d "$nameserver" --dport 53 -m owner --uid-owner "$dns_user" -j ACCEPT
  done
  iptables -A OUTPUT -d "$nameserver" -m owner ! --uid-owner "$dns_user" -j REJECT
  nameservers+=("$nameserver")
  echo "[devcontainer] DNS upstream $nameserver"
done < <(awk '$1 == "nameserver" { print $2 }' /etc/resolv.conf | sort -u)
if [ "${#nameservers[@]}" -eq 0 ]; then
  echo "ERROR: no IPv4 nameserver in /etc/resolv.conf; DNS would be dead" >&2
  exit 1
fi

# DNS filter: dnsmasq forwards only allowlisted names (and subdomains) and adds
# each answer to the ipset; every other uid's port-53 traffic is sent to it.
ipset create allowed-domains hash:net
domains="$(IFS=/; echo "${allowed_domains[*]}")"
{
  printf '%s\n' no-resolv no-poll bind-interfaces listen-address=127.0.0.1 \
    "user=$dns_user" "group=$dns_user" "ipset=/$domains/allowed-domains"
  for nameserver in "${nameservers[@]}"; do
    printf 'server=/%s/%s\n' "$domains" "$nameserver"
  done
} > "$dns_conf"
chmod 0444 "$dns_conf"
dnsmasq --conf-file="$dns_conf"
# Matched by address: after the DNAT reroute the filter does not see -o lo.
for proto in udp tcp; do
  iptables -t nat -I OUTPUT 1 -p "$proto" --dport 53 -m owner ! --uid-owner "$dns_user" \
    -j DNAT --to-destination 127.0.0.1:53
  iptables -A OUTPUT -p "$proto" -d 127.0.0.1 --dport 53 -j ACCEPT
done
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Resolve concurrently through the filter, which fills the ipset; this only
# asserts each name resolves. Domains are validated, so safe as file names.
echo "[devcontainer] Resolving ${#allowed_domains[@]} allowlisted domains"
resolve_dir="$(mktemp -d)"
for domain in "${allowed_domains[@]}"; do
  dig +short A "$domain" > "$resolve_dir/$domain" &
done
wait
for domain in "${allowed_domains[@]}"; do
  grep -qE "$ipv4_re" "$resolve_dir/$domain" && continue
  # One serial retry: a dropped reply in the burst must not brick the start.
  if ! dig +short A "$domain" | grep -qE "$ipv4_re"; then
    echo "ERROR: failed to resolve $domain" >&2
    exit 1
  fi
done
rm -rf "$resolve_dir"

if [ "$include_github_meta_ranges" = 1 ]; then
  # One `ipset restore`: a fork per CIDR adds seconds for hundreds of ranges.
  ipset_batch="$(mktemp)"
  github_meta="$(curl -fsSL --connect-timeout 10 https://api.github.com/meta)"
  echo "$github_meta" | jq -e '.web and .api and .git' >/dev/null
  while IFS= read -r cidr; do
    [ -z "$cidr" ] && continue
    [[ "$cidr" == *:* ]] || add_ipv4_cidr "$cidr"
  done < <(echo "$github_meta" | jq -r '((.web // []) + (.api // []) + (.git // []))[]' | sort -u)
  ipset -exist restore < "$ipset_batch"
  rm -f "$ipset_batch"
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

# Allowlisted DNS must survive the DROP policy, or the checks below mislead.
if ! dig +short A "${allowed_domains[0]}" | grep -qE "$ipv4_re"; then
  echo "ERROR: DNS resolution is broken under the firewall policy" >&2
  exit 1
fi
# Unlisted names must not resolve, even when a query names the upstream itself.
if dig +short +time=3 +tries=1 A example.com | grep -qE "$ipv4_re" \
  || setpriv --reuid=nobody --regid=nogroup --clear-groups \
    dig +short +time=3 +tries=1 A example.com "@${nameservers[0]}" | grep -qE "$ipv4_re"; then
  echo "ERROR: DNS filter resolved a non-allowlisted name" >&2
  exit 1
fi

# All verification probes run concurrently: each is an independent 5s-timeout
# connect, and they sit on the blocking container-start path. Serially this is
# 10s of negative checks (which always burn their full timeout, since a working
# firewall means the connect is *expected* to fail) plus up to 5x5s of positive
# probes. Overlapped, the whole verification costs one timeout.
probe_dir="$(mktemp -d)"
# A probe records "reachable" only on a successful connect; the file is absent
# for a blocked host, so a probe crashing reads as blocked, never as reachable.
probe() { curl --connect-timeout 5 "$@" >/dev/null 2>&1 && echo reachable; }

# Negative checks are the security-critical assertions: a non-allowlisted host
# and any IPv6 egress must be blocked. Literal IPs: DNS would fail them anyway.
probe https://1.1.1.1 > "$probe_dir/neg-v4" &
probe -6 'https://[2606:4700:4700::1111]' > "$probe_dir/neg-v6" &

# Positive check: confirm at least one configured domain is reachable, drawn
# from the allowlist rather than hardcoded endpoints. A single domain whose CDN
# rotated its IP away from the snapshot must not brick startup, so only a total
# failure (every probed domain unreachable) is fatal; partial misses warn.
probed=0
for domain in "${allowed_domains[@]}"; do
  [ "$probed" -ge 5 ] && break
  probe "https://$domain" > "$probe_dir/pos-$probed" &
  probed=$((probed + 1))
done
wait

if [ -s "$probe_dir/neg-v4" ]; then
  echo "ERROR: firewall allowed a non-allowlisted domain" >&2
  exit 1
fi
if [ -s "$probe_dir/neg-v6" ]; then
  echo "ERROR: firewall allowed IPv6 egress" >&2
  exit 1
fi
if [ "$probed" -gt 0 ] && ! grep -rqx reachable "$probe_dir"/pos-* 2>/dev/null; then
  echo "ERROR: firewall blocked every probed allowlisted domain" >&2
  exit 1
fi
rm -rf "$probe_dir"

firewall_ready=1
echo "[devcontainer] Firewall verification passed"
