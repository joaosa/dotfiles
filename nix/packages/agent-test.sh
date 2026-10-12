# shellcheck shell=bash disable=SC2016 # stub bodies expand when the stub runs
# Exercises `agent` against stub host tools in a throwaway $HOME.
# Usage: agent-test.sh <path-to-agent>
set -euo pipefail

agent="$1"
work="$(mktemp -d)"
export HOME="$work/home" USER=tester
log="$work/calls.log"
stubs="$work/bin"
org="$HOME/ghq/github.com/acme"
mkdir -p "$org/repo/sub" "$HOME/plain" "$HOME/.colima/default" "$HOME/.ssh" "$stubs"
git -C "$org/repo" init -q
git init -q "$HOME/audited"
touch "$HOME/.ssh/id_ed25519.pub"
cat >"$HOME/.colima/default/colima.yaml" <<'EOF'
cpu: 8
memory: 32
runtime: docker
mounts:
  - location: ~/ghq
    writable: true
  - location: ~/sandbox
    writable: true
EOF

stub() {
  printf '#!%s\n%s\n' "$(command -v bash)" "$2" >"$stubs/$1"
  chmod +x "$stubs/$1"
}
# colima ssh -- <cmd> runs <cmd> locally, so the VM mount probe sees this tree.
stub colima 'echo "colima $*" >>"$LOG"
case "$1" in
  ssh)
    shift 2
    [[ "$1" == test && "$3" == /run/* ]] && exit 0
    [[ "$1" == test && "$3" == */.ssh ]] && exit 1
    [[ "$1" == mount ]] && { echo "x on $HOME/ghq type virtiofs (rw)"; exit 0; }
    exec "$@" ;;
  list) echo "{\"status\":\"Running\",\"cpus\":${VM_CPUS:-8},\"memory\":34359738368}" ;;
esac'
stub ssh-add 'echo "ssh-add $*" >>"$LOG"; [[ "$1" == -l ]] && echo "256 SHA256:fp key (ED25519)"; exit 0'
stub ssh-keygen 'echo "256 SHA256:fp key (ED25519)"'
stub security 'echo "security $*" >>"$LOG"; [[ "$*" == *codex* ]] && exit 44; echo "token-for-${*: -2:1}-padded-to-twenty-chars"'
stub devcontainer 'echo "devcontainer $* | token=${CLAUDE_CODE_OAUTH_TOKEN:-none} dotfiles=${DOTFILES_PATH:-}" >>"$LOG"; [[ "$1" == exec ]] && exit "${EXEC_RC:-0}"; exit 0'
stub docker 'echo "docker $*" >>"$LOG"
case "$1" in
  ps) [[ "$*" == *-aq* ]] && { [[ -n "${DOCKER_PS:-}" ]] && echo "$DOCKER_PS"; exit 0; }; echo "table" ;;
  top) echo "${DOCKER_TOP:-zsh}" ;;
esac'
export PATH="$stubs:$PATH" LOG="$log"

fails=0
fail() {
  echo "FAIL: $*" >&2
  fails=$((fails + 1))
}
# expect <want-rc> <output-substring> -- <agent args...>; runs in $CWD.
expect() {
  local want="$1" needle="$2" rc=0
  shift 3
  : >"$log"
  out="$(cd "${CWD:-$work}" && "$agent" "$@" 2>&1)" || rc=$?
  [[ "$rc" == "$want" && "$out" == *"$needle"* ]] \
    || fail "agent $* -> rc=$rc (want $want), output: $out (want: $needle)"
}
called() { grep -qF -- "$1" "$log" || fail "no call matching: $1 in: $(cat "$log")"; }
not_called() { if grep -qF -- "$1" "$log"; then fail "unexpected call matching: $1"; fi; }

# Argument handling.
expect 1 "usage: agent fleet" --
expect 1 "agent doctor" -- bogus
expect 1 "unknown agent fleet option: --bogus" -- fleet --bogus acme
expect 1 "usage: agent fleet" -- fleet acme other
expect 1 "unknown Claude profile 'nope' (use alt|main)" -- fleet -p nope acme
expect 1 "invalid Claude profile" -- fleet -p 'a b' acme
expect 1 "org must be one safe path component: ../x" -- fleet ../x
expect 1 "no safe org directory" -- fleet missing
expect 1 "no org given" -- fleet
expect 1 "usage: agent trust" -- trust a b
expect 1 "usage: agent audit" -- audit a b
expect 1 "usage: agent audit" -- audit --bogus
expect 1 "no safe directory" -- audit "$HOME/nope"
expect 1 "not a git checkout" -- audit "$HOME/plain"
CWD="$HOME/plain" expect 1 "not a git checkout" -- audit
expect 1 "usage: agent stop" -- stop a b
expect 1 "no org given" -- stop

# Fleet launch, explicit and inferred org, custom command.
expect 0 "" -- fleet acme
called "devcontainer up --workspace-folder $org"
called "--id-label agent.devcontainer.profile=fleet | token=token-for-svc-main"
called "dotfiles=/dotfiles"
called "agent.devcontainer.profile=fleet zsh |"
not_called "--remove-existing-container"
not_called "claude-profile="
[[ -f "$HOME/.cache/agent-devcontainer/fleet/devcontainer.json" ]] || fail "fleet config not staged"

CWD="$org/repo/sub" expect 0 "" -- fleet --alt -- claude --resume
called "devcontainer up --workspace-folder $org"
called "--id-label agent.devcontainer.profile=fleet-alt --id-label agent.devcontainer.claude-profile=alt"
called "claude --resume | token=token-for-svc-alt"

expect 0 "" -- fleet acme --rebuild
called "--remove-existing-container"

EXEC_RC=7 expect 7 "" -- fleet acme

# Stale detection: rebuild once when the stamp is missing or differs.
DOCKER_PS=c1 CWD="$org" expect 0 "" -- fleet -p alt
not_called "--remove-existing-container"
rm -rf "$HOME/.local/state/agent-devcontainer/templates"
DOCKER_PS=c1 expect 0 "templates changed" -- fleet acme
called "--remove-existing-container"
DOCKER_PS=c1 expect 0 "" -- fleet acme
not_called "--remove-existing-container"

# Agents left running after the shell exits.
DOCKER_PS=c1 DOCKER_TOP="node /usr/local/bin/claude" expect 0 "agent stop acme" -- fleet acme
DOCKER_PS=c1 DOCKER_TOP="zsh" expect 0 "" -- fleet acme
[[ "$out" != *"agent stop"* ]] || fail "warned about agents with none running"

# Audit: no credentials or agent forwarding; defaults to the current directory.
CWD="$HOME/audited" expect 0 "" -- audit
called "devcontainer up --workspace-folder $HOME/audited"
called "--id-label agent.devcontainer.profile=audit zsh | token=none"
not_called "security"
not_called "ssh-add"
expect 0 "" -- audit "$HOME/audited" -- codex
called "audit codex | token=none"

# Trust, ls and stop.
CWD="$org/repo" expect 0 "" -- trust
[[ -f "$HOME/.local/state/agent-devcontainer/git-guard/acme.json" ]] || fail "trust wrote no baseline"
expect 0 "" -- ls
called "docker ps -a --filter label=agent.devcontainer.profile --format"
DOCKER_PS=c1 CWD="$org/repo" expect 0 "stopped 1" -- stop
called "--filter label=devcontainer.local_folder=$org"
called "docker stop c1"
DOCKER_PS=$'c1\nc2' expect 0 "stopped 2" -- stop --all
called "docker stop c1 c2"
expect 0 "no agent containers" -- stop acme

# Doctor: optional secrets warn, mismatches fail.
expect 1 "FAIL  VM mounts $HOME/sandbox" -- doctor
[[ "$out" == *"ok    colima.yaml sets runtime"* ]] || fail "doctor: runtime not ok: $out"
[[ "$out" == *"ok    VM mounts $HOME/ghq"* ]] || fail "doctor: ghq mount not ok"
[[ "$out" == *"ok    host ~/.ssh hidden from the VM"* ]] || fail "doctor: ssh visibility"
[[ "$out" == *"ok    signing key loaded"* ]] || fail "doctor: signing key"
[[ "$out" == *"warn  keychain item codex-api-key missing"* ]] || fail "doctor: codex warn"
VM_CPUS=2 expect 1 "FAIL  VM resources match colima.yaml" -- doctor
sed -i.bak '/^runtime:/d' "$HOME/.colima/default/colima.yaml"
expect 1 "FAIL  colima.yaml sets runtime" -- doctor

if ((fails)); then
  echo "$fails agent test(s) failed" >&2
  exit 1
fi
echo "agent tests passed"
