#!/usr/bin/env bash
# Root PID-1 init for the agent devcontainer. Runs as root at container start
# (the profiles set containerUser=root + overrideCommand=false so this image
# ENTRYPOINT is honoured as PID 1), does every privileged action the container
# needs, then execs a keep-alive. The agent and terminals attach later as
# remoteUser=vscode, which is NOT in sudoers. Moving these actions here is what
# lets us remove vscode's sudo grant entirely: an untrusted agent can no longer
# reach the firewall applier, the volume chowns, or the ssh-socket perms.
#
# Fail-closed on the firewall: apply-firewall.sh arms its own EXIT trap that
# locks egress down if anything fails, so a broken init denies network rather
# than leaving the allowlist un-applied (fail-open). We deliberately do NOT
# `set -e` around the whole script: a chown that races a not-yet-mounted volume
# must not abort before the firewall arms. Each privileged step guards itself.
set -uo pipefail

log() { echo "[entrypoint] $*" >&2; }

# 1. Volume ownership. The named volumes (.claude, .codex, .config/gh,
#    /commandhistory) mount root-owned on first create; make them writable by
#    the remote user. Read-only binds nested inside (e.g. ~/.claude/skills)
#    make chown -R exit nonzero even when the writable contents were chowned,
#    so judge success by ownership, not exit code -- same rationale as the old
#    post_install.py path this replaces.
remote_uid="$(id -u vscode)"
remote_gid="$(id -g vscode)"
for dir in \
  /home/vscode/.claude \
  /home/vscode/.codex \
  /home/vscode/.config/gh \
  /commandhistory; do
  [ -e "$dir" ] || continue
  cur_uid="$(stat -c '%u' "$dir" 2>/dev/null || echo -1)"
  if [ "$cur_uid" != "$remote_uid" ]; then
    chown -R "$remote_uid:$remote_gid" "$dir" 2>/dev/null || true
    if [ "$(stat -c '%u' "$dir" 2>/dev/null || echo -1)" = "$remote_uid" ]; then
      log "fixed ownership: $dir"
    else
      log "warning: could not fix ownership of $dir"
    fi
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
if [ "${AGENT_ENABLE_FIREWALL:-0}" = "1" ]; then
  log "outbound firewall: strict"
  if ! /usr/local/bin/apply-firewall.sh; then
    log "FATAL: firewall failed to apply; egress is locked down fail-closed"
  fi
else
  log "outbound firewall: permissive"
fi

# Hand off to a keep-alive PID 1. init=true gives us tini as the real PID 1
# reaping zombies; this exec keeps the container running the way the default
# overrideCommand sleep loop would have.
log "init complete; container ready"
exec sleep infinity
