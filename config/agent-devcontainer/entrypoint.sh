#!/usr/bin/env bash
# Root PID-1 init: does every privileged action the container needs (the profiles
# set containerUser=root + overrideCommand=false so this ENTRYPOINT runs as PID
# 1), then execs CMD. The agent attaches later as remoteUser=vscode, which is
# NOT in sudoers -- moving this work here is what lets us drop vscode's sudo
# grant entirely.
#
# We deliberately do NOT `set -e`: a chown that races a not-yet-mounted volume
# must not abort before the firewall arms. Each step guards itself, and the
# firewall fails closed via apply-firewall.sh's own trap.
set -uo pipefail

log() { echo "[entrypoint] $*" >&2; }

# 1. Volume ownership. The named volumes mount root-owned on first create; make
#    them writable by the remote user. The top-dir uid guard keeps the recursive
#    walk off the restart hot path. chown -R exits nonzero on the read-only binds
#    nested inside (e.g. ~/.claude/skills) even when the writable contents were
#    chowned, so judge success by the resulting ownership, not the exit code.
remote_uid="$(id -u vscode)"
remote_gid="$(id -g vscode)"
for dir in /home/vscode/.claude /home/vscode/.codex /home/vscode/.config/gh /commandhistory; do
  [ -e "$dir" ] && [ "$(stat -c '%u' "$dir")" != "$remote_uid" ] || continue
  chown -R "$remote_uid:$remote_gid" "$dir" 2>/dev/null || true
  if [ "$(stat -c '%u' "$dir")" = "$remote_uid" ]; then
    log "fixed ownership: $dir"
  else
    log "warning: could not fix ownership of $dir"
  fi
done

# 2. Forwarded SSH agent socket. Arrives root-owned from the host-services
#    bind; scope it to vscode alone so no other in-container uid can borrow it.
#    Only the fleet profile forwards it; a missing socket is not an error here.
if [ -n "${SSH_AUTH_SOCK:-}" ] && [ -S "${SSH_AUTH_SOCK:-}" ]; then
  chown vscode:vscode "$SSH_AUTH_SOCK" 2>/dev/null || log "warning: ssh socket chown failed"
  chmod 0600 "$SSH_AUTH_SOCK" 2>/dev/null || log "warning: ssh socket chmod failed"
  log "ssh agent socket scoped to vscode"
fi

# 3. Firewall. Root already, so no sudo: call the applier directly. It reads
#    the allowlist from the root-owned baked-in file and fails closed on any
#    error via its own trap. Kept last among the privileged steps so egress is
#    locked before the container becomes reachable for work.
#    The enable flag is read from containerEnv, which is safe where the payload
#    is not: PID 1 captures it at container start, before the agent exists, so
#    the agent cannot flip it. The allowlist stays a baked 0444 file because it
#    is the attacker-chosen *content*, not a fixed on/off switch, that must be
#    immutable. Both profiles set it to 1.
if [ "${AGENT_ENABLE_FIREWALL:-0}" = "1" ]; then
  log "outbound firewall: strict"
  if ! /usr/local/bin/apply-firewall.sh; then
    log "FATAL: firewall failed to apply; egress is locked down fail-closed"
  fi
else
  log "outbound firewall: permissive"
fi

# Drop into whatever the container was asked to run; the image's CMD defaults
# this to `sleep infinity`, the keep-alive that overrideCommand=false suppressed.
log "init complete; container ready"
exec "$@"
