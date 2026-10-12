# shellcheck shell=bash disable=SC2016 # stub bodies expand when the stub runs
# Exercises `agent` against stub host tools in a throwaway $HOME.
# Usage: agent-test.sh <path-to-agent>
set -euo pipefail

agent="$1"
work="$(mktemp -d)"
export HOME="$work/home" USER=tester
log="$work/calls.log"
stubs="$work/bin"
mkdir -p "$HOME/ghq/github.com/acme/repo" "$HOME/plain" "$stubs"
git -C "$HOME/ghq/github.com/acme/repo" init -q
git -C "$HOME/ghq/github.com/acme/repo" config user.email t@t
git init -q "$HOME/audited"

stub() {
  printf '#!%s\n%s\n' "$(command -v bash)" "$2" >"$stubs/$1"
  chmod +x "$stubs/$1"
}
# colima ssh -- <cmd> runs <cmd> locally, so the VM mount probe sees this tree.
stub colima 'echo "colima $*" >>"$LOG"; if [[ "$1" == ssh ]]; then shift 2; [[ "$1" == test && "$3" == /run/* ]] && exit 0; exec "$@"; fi'
stub ssh-add 'echo "ssh-add $*" >>"$LOG"'
stub security 'echo "security $*" >>"$LOG"; echo "token-for-${*: -2:1}-padded-to-twenty-chars"'
stub devcontainer 'echo "devcontainer $* | token=${CLAUDE_CODE_OAUTH_TOKEN:-none} dotfiles=${DOTFILES_PATH:-}" >>"$LOG"; [[ "$1" == exec ]] && exit "${EXEC_RC:-0}"; exit 0'
export PATH="$stubs:$PATH" LOG="$log"

fails=0
# expect <want-rc> <stderr-substring> -- <agent args...>
expect() {
  local want="$1" needle="$2" rc=0 err
  shift 3
  : >"$log"
  err="$("$agent" "$@" 2>&1 >/dev/null)" || rc=$?
  if [[ "$rc" != "$want" || "$err" != *"$needle"* ]]; then
    echo "FAIL: agent $* -> rc=$rc (want $want), stderr: $err (want: $needle)" >&2
    fails=$((fails + 1))
  fi
}
# called <substring>: the last agent run logged a matching tool call.
called() {
  if ! grep -qF -- "$1" "$log"; then
    echo "FAIL: no call matching: $1" >&2
    sed 's/^/  /' "$log" >&2
    fails=$((fails + 1))
  fi
}
not_called() {
  if grep -qF -- "$1" "$log"; then
    echo "FAIL: unexpected call matching: $1" >&2
    fails=$((fails + 1))
  fi
}

expect 1 "usage: agent fleet" --
expect 1 "agent audit <repo-path-or-url>" -- bogus
expect 1 "usage: agent fleet" -- fleet
expect 1 "unknown agent fleet option: --bogus" -- fleet --bogus acme
expect 1 "unknown Claude profile 'nope' (use alt|main)" -- fleet -p nope acme
expect 1 "invalid Claude profile" -- fleet -p 'a b' acme
expect 1 "org must be one safe path component: ../x" -- fleet ../x
expect 1 "no safe org directory" -- fleet missing
expect 1 "usage: agent trust <org>" -- trust
expect 1 "usage: agent audit" -- audit
expect 1 "usage: agent audit" -- audit a b
expect 1 "no safe directory" -- audit "$HOME/nope"
expect 1 "not a git checkout" -- audit "$HOME/plain"

expect 0 "" -- fleet acme
called "devcontainer up --workspace-folder $HOME/ghq/github.com/acme"
called "--id-label agent.devcontainer.profile=fleet | token=token-for-svc-main"
called "dotfiles=/dotfiles"
called "devcontainer exec"
not_called "--remove-existing-container"
not_called "claude-profile="
[[ -f "$HOME/.cache/agent-devcontainer/fleet/devcontainer.json" ]] \
  || { echo "FAIL: fleet config not staged" >&2; fails=$((fails + 1)); }

expect 0 "" -- fleet --alt --rebuild acme
called "--id-label agent.devcontainer.profile=fleet-alt --id-label agent.devcontainer.claude-profile=alt --remove-existing-container"
called "token=token-for-svc-alt"

EXEC_RC=7 expect 7 "" -- fleet acme

expect 0 "" -- audit "$HOME/audited"
called "--id-label agent.devcontainer.profile=audit"
called "token=none"
not_called "security"
not_called "ssh-add"

if ((fails)); then
  echo "$fails agent test(s) failed" >&2
  exit 1
fi
echo "agent tests passed"
