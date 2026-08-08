# shellcheck shell=bash
# Sourced by apply-firewall.sh and init-firewall.sh: the one definition of
# fail-closed. Flush before dropping — rules beat policy, so a partial run's
# broad ACCEPTs would otherwise survive alongside the DROP.
lockdown_egress() {
  iptables -F 2>/dev/null || true
  iptables -t nat -F 2>/dev/null || true
  ip6tables -F 2>/dev/null || true
  iptables -P INPUT DROP 2>/dev/null || true
  iptables -P FORWARD DROP 2>/dev/null || true
  iptables -P OUTPUT DROP 2>/dev/null || true
  ip6tables -P INPUT DROP 2>/dev/null || true
  ip6tables -P FORWARD DROP 2>/dev/null || true
  ip6tables -P OUTPUT DROP 2>/dev/null || true
}
