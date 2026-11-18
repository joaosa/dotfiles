# shellcheck shell=bash disable=SC2016 # stub bodies expand when the stub runs
# Exercises `agent` against stub host tools in a throwaway $HOME.
# Usage: agent-test.sh <path-to-agent> <path-to-post-start.sh>
set -euo pipefail

agent="$1"
post_start="$2"
devc="$(sed -n 's/^AGENT_DEVC=//p' "$(realpath "$agent")")"
work="$(mktemp -d)"
export HOME="$work/home" USER=tester
log="$work/calls.log"
exec_log="$work/exec-args"
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
    [[ "${COLIMA_SSH_RC:-0}" == 0 ]] || exit "$COLIMA_SSH_RC"
    shift 2
    [[ "$1" == sh && "$3" == '\''test ! -e "$1"'\'' ]] && exit 0
    [[ "$1" == sh ]] && exec "${@//\/run\/host-services\/ssh-auth.sock/}"
    [[ "$1" == test && "$3" == /run/* ]] && exit 0
    [[ "$1" == test && "$3" == */.ssh ]] && exit 1
    [[ "$1" == mount ]] && { echo "x on $HOME/ghq type virtiofs (rw)"; exit 0; }
    exec "$@" ;;
  list)
    echo "{\"name\":\"default\",\"status\":\"${VM_STATUS:-Running}\",\"cpus\":${VM_CPUS:-8},\"memory\":34359738368}"
    echo "{\"name\":\"another\",\"status\":\"${OTHER_VM_STATUS:-Stopped}\"}" ;;
  start) exit "${COLIMA_START_RC:-0}" ;;
esac'
stub ssh-add 'echo "ssh-add $*" >>"$LOG"; [[ "$1" == -l ]] && echo "256 SHA256:fp key (ED25519)"; exit 0'
stub ssh-keygen 'echo "256 SHA256:fp key (ED25519)"'
stub security 'echo "security $*" >>"$LOG"; [[ "$*" == *codex* ]] && exit 44; echo "token-for-${*: -2:1}-padded-to-twenty-chars"'
stub devcontainer 'echo "devcontainer $* | token=${CLAUDE_CODE_OAUTH_TOKEN:-none} dotfiles=${DOTFILES_PATH:-} org=${AGENT_ORG:-} devc=${AGENT_DEVC:-} skip_update=${AGENT_SKIP_UPDATE:-0}" >>"$LOG"
if [[ "$1" == exec ]]; then
  printf "%s\0" "$@" >"$EXEC_LOG"
  exit "${EXEC_RC:-0}"
fi
exit 0'
stub docker 'echo "docker $*" >>"$LOG"
case "$1" in
  info) exit "${DOCKER_INFO_RC:-0}" ;;
  stop) exit "${DOCKER_STOP_RC:-0}" ;;
  ps)
    [[ "${DOCKER_PS_RC:-0}" == 0 ]] || exit "$DOCKER_PS_RC"
    [[ -z "${DOCKER_PS:-}" ]] && exit 0
    if [[ "$*" == *-aq* ]]; then echo "$DOCKER_PS"
    elif [[ "$*" == *agent.devcontainer.devc* ]]; then echo "$DOCKER_PS ${DOCKER_DEVC:-}"
    else echo table; fi ;;
  top) echo "${DOCKER_TOP:-zsh}" ;;
esac'
export PATH="$stubs:$PATH" LOG="$log" EXEC_LOG="$exec_log"

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
  : >"$exec_log"
  out="$(cd "${CWD:-$work}" && "$agent" "$@" 2>&1)" || rc=$?
  [[ "$rc" == "$want" && "$out" == *"$needle"* ]] \
    || fail "agent $* -> rc=$rc (want $want), output: $out (want: $needle)"
}
called() { grep -qF -- "$1" "$log" || fail "no call matching: $1 in: $(cat "$log")"; }
not_called() { if grep -qF -- "$1" "$log"; then fail "unexpected call matching: $1"; fi; }
has() { [[ "$out" == *"$1"* ]] || fail "output lacks: $1 in: $out"; }
# Compare argument boundaries too: whitespace and shell syntax must survive.
exec_ends_with() {
  local -a args
  local offset arg
  mapfile -d '' -t args < "$exec_log"
  offset=$((${#args[@]} - $#))
  ((offset >= 0)) || { fail "too few exec arguments"; return; }
  for arg in "$@"; do
    [[ "${args[$offset]}" == "$arg" ]] || fail "exec argument $offset differs: ${args[$offset]} (want: $arg)"
    offset=$((offset + 1))
  done
}

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

# Help does not start the VM, read credentials or invoke host tools.
for option in --help -h help; do
  expect 0 "Examples (run from a repository):" -- "$option"
  has "agent fleet -- codex"
  [[ ! -s "$log" ]] || fail "help invoked host tools"
done
for subcommand in fleet audit trust ls stop doctor; do
  for option in --help -h; do
    expect 0 "usage: agent $subcommand" -- "$subcommand" "$option"
    [[ ! -s "$log" ]] || fail "$subcommand help invoked host tools"
  done
  expect 0 "usage: agent $subcommand" -- help "$subcommand"
  [[ ! -s "$log" ]] || fail "help $subcommand invoked host tools"
done
expect 1 "unknown help command: extra" -- help extra
expect 1 "usage: agent help [command]" -- help fleet extra
expect 1 "usage: agent --help" -- --help extra

# All required host tools are checked before starting the VM or loading keys.
# A restricted PATH prevents an installed host tool from masking a missing stub.
for tool in devcontainer colima docker ssh-add; do
  mv "$stubs/$tool" "$stubs/$tool.disabled"
  PATH="$stubs" expect 1 "required command not found on PATH: $tool" -- fleet acme
  [[ ! -s "$log" ]] || fail "missing $tool allowed fleet side effects"
  PATH="$stubs" expect 0 "usage: agent fleet" -- fleet --help
  [[ ! -s "$log" ]] || fail "help with missing $tool invoked host tools"
  if [[ "$tool" != ssh-add ]]; then
    PATH="$stubs" expect 1 "required command not found on PATH: $tool" -- audit "$HOME/audited"
    [[ ! -s "$log" ]] || fail "missing $tool allowed audit side effects"
  fi
  if [[ "$tool" == docker ]]; then
    PATH="$stubs" expect 1 "required command not found on PATH: docker" -- ls
    PATH="$stubs" expect 1 "required command not found on PATH: docker" -- stop --all
  fi
  mv "$stubs/$tool.disabled" "$stubs/$tool"
done

# Help belonging to the launched command passes through the -- separator.
expect 0 "" -- fleet acme -- codex --help
exec_ends_with agent.devcontainer.profile=fleet codex --help
expect 0 "" -- audit "$HOME/audited" -- claude --help
exec_ends_with agent.devcontainer.profile=audit claude --help

# Fleet launch, explicit and inferred org, custom command.
expect 0 "" -- fleet acme
called "devcontainer up --workspace-folder $org"
called "--id-label agent.devcontainer.profile=fleet | token=token-for-svc-main"
called "dotfiles=/dotfiles org=acme devc=$devc"
called "agent.devcontainer.profile=fleet zsh |"
not_called "colima start"
not_called "colima status"
not_called "--remove-existing-container"
not_called "claude-profile="
[[ -f "$HOME/.cache/agent-devcontainer/fleet/devcontainer.json" ]] || fail "fleet config not staged"

CWD="$org/repo/sub" expect 0 "" -- fleet --alt -- claude --resume
called "devcontainer up --workspace-folder $org"
called "--id-label agent.devcontainer.profile=fleet-alt --id-label agent.devcontainer.claude-profile=alt"
called "claude --resume | token=token-for-svc-alt"
exec_ends_with sh -c 'cd -- "$1" && shift && exec "$@"' agent-shell /workspace/repo/sub claude --resume

# Default shells preserve the directory too; the org root needs no wrapper.
CWD="$org/repo" expect 0 "" -- fleet
exec_ends_with sh -c 'cd -- "$1" && shift && exec "$@"' agent-shell /workspace/repo zsh
CWD="$org" expect 0 "" -- fleet
exec_ends_with agent.devcontainer.profile=fleet zsh

# Explicitly selecting an org preserves context only when inside that org.
mkdir -p "$HOME/ghq/github.com/acme-other/repo"
CWD="$HOME/ghq/github.com/acme-other/repo" expect 0 "" -- fleet acme -- codex
exec_ends_with agent.devcontainer.profile=fleet codex

# Quoted paths, prompts and empty arguments are passed literally.
special='repo with spaces; $HOME'
mkdir -p "$org/$special"
prompt='keep $(touch unwanted) and "quotes" literal'
CWD="$org/$special" expect 0 "" -- fleet acme -- codex "$prompt" ''
exec_ends_with sh -c 'cd -- "$1" && shift && exec "$@"' agent-shell "/workspace/$special" codex "$prompt" ''

# Execute the emitted wrapper locally with a mapped directory: it changes cwd,
# preserves argument boundaries and propagates the command's exit status.
mapfile -d '' -t exec_args < "$exec_log"
wrapper="${exec_args[${#exec_args[@]} - 6]}"
rc=0
result=$(sh -c "$wrapper" agent-shell "$org/$special" bash -c 'pwd -P; printf "<%s>\n" "$@"; exit 7' _ "$prompt" '') || rc=$?
[[ "$rc" == 7 && "$result" == "$(cd "$org/$special" && pwd -P)"$'\n'"<$prompt>"$'\n<>' ]] \
  || fail "directory wrapper changed arguments or exit status"

expect 0 "" -- fleet acme --rebuild
called "--remove-existing-container"
LC_NUMERIC=de_DE.UTF-8 AGENT_TIMING=1 expect 0 "[agent timing] VM readiness:" -- fleet acme --no-update
called "skip_update=1"
has "[agent timing] workspace setup:"
has "[agent timing] container startup:"
[[ "$out" != *"token-for-"* ]] || fail "timing output exposed a credential"
AGENT_SKIP_UPDATE=1 expect 0 "" -- fleet acme
called "skip_update=0"

EXEC_RC=7 expect 7 "" -- fleet acme

# Stale detection: rebuild when the container's template label differs.
DOCKER_PS=c1 DOCKER_DEVC="$devc" CWD="$org" expect 0 "" -- fleet -p alt
not_called "--remove-existing-container"
DOCKER_PS=c1 DOCKER_DEVC=/nix/store/old-devc expect 0 "templates changed" -- fleet acme
called "--remove-existing-container"
DOCKER_PS=c1 expect 0 "templates changed" -- fleet acme

# Agents left running after the shell exits.
DOCKER_PS=c1 DOCKER_DEVC="$devc" DOCKER_TOP="node /usr/local/bin/claude" expect 0 "agent stop acme" -- fleet acme
DOCKER_PS=c1 DOCKER_DEVC="$devc" DOCKER_TOP="zsh" expect 0 "" -- fleet acme
[[ "$out" != *"agent stop"* ]] || fail "warned about agents with none running"

# Audit: no credentials or agent forwarding; defaults to the current directory.
CWD="$HOME/audited" expect 0 "" -- audit
called "devcontainer up --workspace-folder $HOME/audited"
called "--id-label agent.devcontainer.profile=audit zsh | token=none dotfiles=/dotfiles org= "
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
called "--filter label=agent.devcontainer.org=acme"
called "docker stop c1"
DOCKER_PS=$'c1\nc2' expect 0 "stopped 2" -- stop --all
called "docker stop c1 c2"
expect 0 "no agent containers" -- stop acme

# Transport failures must not look like empty container lists or start a session.
DOCKER_PS_RC=1 expect 1 "could not list containers" -- stop --all
not_called "docker stop"
[[ "$out" != *"no agent containers"* ]] || fail "Docker failure reported as empty list"
DOCKER_PS_RC=1 expect 1 "could not list containers" -- ls
DOCKER_PS_RC=1 expect 1 "could not list containers" -- fleet acme
not_called "devcontainer up"
DOCKER_PS=c1 DOCKER_STOP_RC=1 expect 1 "could not stop containers" -- stop acme
DOCKER_INFO_RC=1 expect 1 "Docker daemon unreachable" -- fleet acme
not_called "ssh-add"
not_called "security"
not_called "devcontainer up"
VM_STATUS=Stopped OTHER_VM_STATUS=Running COLIMA_START_RC=1 expect 1 "could not start Colima" -- fleet acme
not_called "docker info"

# Doctor: optional secrets warn, mismatches fail.
expect 1 "FAIL  VM mounts $HOME/sandbox (restart colima after changing mounts)" -- doctor
has "ok    colima VM running"$'\n'
has "ok    VM resources match colima.yaml"
has "ok    VM mounts $HOME/ghq"
has "ok    host ~/.ssh hidden from the VM"
has "ok    SSH agent socket forwarded"
has "ok    signing key loaded"
has "ok    keychain item svc-alt"
has "warn  keychain item codex-api-key missing"
has "1 check(s) failed"
mv "$HOME/.colima/default/colima.yaml" "$work/colima.yaml"
expect 1 "FAIL  colima config readable: $HOME/.colima/default/colima.yaml"$'\n' -- doctor
mv "$work/colima.yaml" "$HOME/.colima/default/colima.yaml"
VM_CPUS=2 expect 1 "FAIL  VM resources match colima.yaml (restart colima after changing them)" -- doctor
DOCKER_INFO_RC=1 expect 1 "FAIL  Docker daemon reachable" -- doctor
VM_STATUS=Stopped OTHER_VM_STATUS=Running expect 1 "FAIL  colima VM running" -- doctor
COLIMA_SSH_RC=255 expect 1 "FAIL  VM mount list readable" -- doctor
has "FAIL  host ~/.ssh hidden from the VM"
has "ok    keychain item svc-alt"

# Startup refresh: stub all updater commands; never contact a registry or log in.
stub claude 'echo "claude $*" >>"$LOG"; exit "${UPDATE_RC:-0}"'
stub codex 'echo "codex $*" >>"$LOG"; echo "codex-cli 1.0.0"'
stub npm 'echo "npm $*" >>"$LOG"; echo '\''{"1.0.0":"2020-01-01T00:00:00.000Z"}'\'''
stub date 'echo "2021-01-01T00:00:00.000Z"'
export AGENT_UPDATE_AGENTS=1
unset CODEX_API_KEY
stamp="$HOME/.agent-update-stamp"
attempt_stamp="$HOME/.agent-update-attempt"
startup() {
  : >"$log"
  startup_out=$(bash "$post_start" 2>&1) || fail "post-start failed: $startup_out"
}
UPDATE_RC=1 startup
called "claude update"
called "npm view"
[[ -f "$attempt_stamp" && ! -e "$stamp" ]] || fail "failed refresh recorded as success"
startup
[[ ! -s "$log" ]] || fail "refresh retried during cooldown"

# Once the cooldown expires, retry; success then suppresses checks for a day.
touch -t 202001010000 "$attempt_stamp"
startup
called "claude update"
[[ -f "$stamp" ]] || fail "successful refresh not recorded"
touch -t 202001010000 "$attempt_stamp"
startup
[[ ! -s "$log" ]] || fail "successful refresh retried within a day"
touch -t 202001010000 "$stamp"
startup
called "claude update"

# Audit stays pinned even when both stamps are old.
touch -t 202001010000 "$stamp" "$attempt_stamp"
AGENT_UPDATE_AGENTS=0 startup
[[ ! -s "$log" ]] || fail "audit attempted an update"

# Skip only updates: authentication still runs, timing omits credentials, and
# neither cooldown stamp is changed by a skipped refresh.
mkdir -p "$HOME/.codex"
before=$(stat -c '%Y' "$stamp" "$attempt_stamp")
AGENT_SKIP_UPDATE=1 AGENT_TIMING=1 CODEX_API_KEY=test-only-key startup
called "codex login --with-api-key"
not_called "npm"
not_called "claude update"
[[ "$before" == "$(stat -c '%Y' "$stamp" "$attempt_stamp")" ]] || fail "skip updated cooldown stamps"
[[ "$startup_out" == *"[devcontainer timing] agent updates:"* \
  && "$startup_out" == *"[devcontainer timing] Codex authentication:"* \
  && "$startup_out" != *"test-only-key"* ]] || fail "startup timing missing or exposed a key"
[[ -s "$HOME/.codex/.api-key-hash" ]] || fail "skip disabled authentication"

if ((fails)); then
  echo "$fails agent test(s) failed" >&2
  exit 1
fi
echo "agent tests passed"
