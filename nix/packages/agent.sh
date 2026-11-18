# shellcheck shell=bash
# Body of `agent`; agent.nix prepends the AGENT_* settings. Host tools come from the caller's PATH.

ORGS_ROOT="$HOME/$AGENT_ORGS_SUBDIR"
SIGNING_KEY="$HOME/.ssh/id_ed25519"
AGENT_SOCK=/run/host-services/ssh-auth.sock
CODEX_SERVICE=codex-api-key
FLEET_USAGE="agent fleet [--rebuild] [--no-update] [--alt | -p <profile>] [<org>] [-- <cmd>...]"
TRUST_USAGE="agent trust [<org>]"
AUDIT_USAGE="agent audit [<repo-path-or-url>] [-- <cmd>...]"
LS_USAGE="agent ls"
STOP_USAGE="agent stop [<org> | --all]"
DOCTOR_USAGE="agent doctor"

die() {
  echo "$*" >&2
  exit 1
}

usage() {
  printf 'usage: %s\n' "$FLEET_USAGE"
  printf '       %s\n' "$TRUST_USAGE" "$AUDIT_USAGE" "$LS_USAGE" "$STOP_USAGE" "$DOCTOR_USAGE"
}

help() {
  case "${1:-}" in
    fleet)
      printf 'usage: %s\n\n' "$FLEET_USAGE"
      cat <<EOF
Open a trusted org's container, keeping your current repository/subdirectory.
The org is inferred from ~/$AGENT_ORGS_SUBDIR/<org> when omitted.
Without a command, open zsh. Pass agent arguments after --.

  --rebuild        Recreate the container; keep logins and history.
  --no-update      Skip agent updates for this launch.
  --alt            Select the alt Claude account.
  -p, --profile    Select a Claude profile (default: $AGENT_DEFAULT_PROFILE).

Examples (run from a repository):
  agent fleet -- claude --resume
  agent fleet --alt -- claude --resume
  agent fleet -- codex resume --last
EOF
      ;;
    audit)
      printf 'usage: %s\n\n' "$AUDIT_USAGE"
      cat <<'EOF'
Open an isolated container for one repository; default to the current directory.
A URL is cloned into ~/sandbox/audit. Local targets must be Git checkouts.
Host AI/API credentials and the SSH agent are not forwarded; log in inside.
Without a command, open zsh. Pass agent arguments after --.

Example:
  agent audit . -- codex
EOF
      ;;
    trust)
      printf 'usage: %s\n\n' "$TRUST_USAGE"
      printf '%s\n' "Accept Git hook/config changes you have reviewed for a trusted org." \
        "The org is inferred from the current directory when omitted."
      ;;
    ls)
      printf 'usage: %s\n\n' "$LS_USAGE"
      printf '%s\n' "List agent containers, including stopped ones."
      ;;
    stop)
      printf 'usage: %s\n\n' "$STOP_USAGE"
      printf '%s\n' "Stop an org's containers, or every agent container with --all." \
        "The org is inferred from the current directory when omitted."
      ;;
    doctor)
      printf 'usage: %s\n\n' "$DOCTOR_USAGE"
      printf '%s\n' "Check host tools, the VM, mounts, signing and optional keychain items." \
        "Reports problems without starting the VM or reading secret values."
      ;;
    "")
      usage
      cat <<'EOF'

fleet   Open a trusted org's container; keep your current directory within it.
audit   Open an isolated repo container; defaults to the current directory.
trust   Accept reviewed Git hook/config changes for an org.
ls      List agent containers, including stopped ones.
stop    Stop an org's containers, or every agent container with --all.
doctor  Check the VM, mounts, signing setup and optional keychain items.

Fleet, trust and stop infer the org from your current directory when omitted.
Fleet defaults to the main Claude account; --alt or -p selects another profile.
Use --rebuild to recreate a fleet container while keeping logins and history.
Use --no-update to skip updates once; AGENT_TIMING=1 prints startup phase times.
Use agent help <command> or agent <command> --help for command-specific help.

Examples (run from a repository):
  agent fleet -- claude
  agent fleet --alt -- claude --resume
  agent fleet -- codex
  agent fleet -- codex resume
  agent fleet -- codex resume --last
  agent audit . -- codex
EOF
      ;;
    *) die "unknown help command: $1"$'\n'"usage: agent help [fleet|audit|trust|ls|stop|doctor]" ;;
  esac
}

require_commands() {
  local tool
  for tool in "$@"; do
    command -v "$tool" &>/dev/null \
      || die "required command not found on PATH: $tool (install it or add it to PATH)"
  done
}

# Bash's clock avoids extra subprocesses. Only fixed labels and elapsed times
# are logged; never command arguments, directories, or credentials.
phase_started="${EPOCHREALTIME//[!0-9]/}"
timing() {
  local now="${EPOCHREALTIME//[!0-9]/}" elapsed
  elapsed=$((now - phase_started))
  if [[ "${AGENT_TIMING:-0}" == 1 ]]; then
    printf '[agent timing] %s: %d.%03ds\n' "$1" "$((elapsed / 1000000))" "$((elapsed / 1000 % 1000))" >&2
  fi
  phase_started="$now"
}

# list avoids status's extra VM probes; select the same default profile used
# by colima start/ssh. Other profiles must not change its running state.
colima_vm() {
  colima list --json 2>/dev/null | jq -sce '[.[] | select(.name == "default")] | if length == 1 then .[0] else empty end'
}

preflight() {
  require_commands devcontainer colima docker "$@"
  local vm
  if ! vm="$(colima_vm)" || [[ "$(jq -r .status <<<"$vm")" != Running ]]; then
    colima start --ssh-agent || die "could not start Colima; run agent doctor"
  fi
  docker info &>/dev/null || die "Docker daemon unreachable; check the Docker context and run agent doctor"
  timing "VM readiness"
}

# put <src> <dst>: install a staged file, never through a symlink.
put() {
  [[ ! -L "$2" ]] || { echo "refusing symlinked staged file: $2" >&2; return 1; }
  install -m0644 "$1" "$2"
}

# Stage the trusted templates outside the checkout; prints the config path.
stage() {
  local profile="$1" cache="$HOME/.cache" p file
  local dir="$cache/agent-devcontainer/$profile"
  for p in "$cache" "${dir%/*}" "$dir"; do
    [[ ! -L "$p" ]] || { echo "refusing symlinked agent cache path: $p" >&2; return 1; }
    if [[ -e "$p" ]]; then
      [[ -d "$p" && -O "$p" ]] || { echo "agent cache path is not an owned directory: $p" >&2; return 1; }
    else
      mkdir "$p" || return 1
    fi
  done
  for file in "${AGENT_TEMPLATE_FILES[@]}"; do
    put "$AGENT_DEVC/share/agent-devcontainer/$file" "$dir/$file" || return 1
  done
  put "$AGENT_DEVC/share/agent-devcontainer/$profile.devcontainer.json" "$dir/devcontainer.json" || return 1
  printf '%s\n' "$dir/devcontainer.json"
}

# Export one keychain-held credential into the fleet container, or unset it and say so.
export_secret() {
  local var="$1" service="$2" agent="$3" secret
  secret=$(security find-generic-password -a "$USER" -s "$service" -w 2>/dev/null) || secret=""
  if [[ "${#secret}" -ge 20 ]]; then
    export "$var=$secret"
  else
    unset "$var"
    echo "$agent keychain secret missing or malformed ($service); use interactive login in the fleet container" >&2
  fi
}

# containers <label=value>...: ids of agent containers carrying every label.
containers() {
  local -a filters=(--filter label=agent.devcontainer.profile)
  local label
  for label in "$@"; do filters+=(--filter "label=$label"); done
  docker ps -aq "${filters[@]}"
}

# The default profile keeps the pre-multi-account label so its volumes survive.
identity_profile() {
  if [[ -n "${2:-}" && "$2" != "$AGENT_DEFAULT_PROFILE" ]]; then
    printf '%s\n' "$1-$2"
  else
    printf '%s\n' "$1"
  fi
}

# The org a path sits in under ORGS_ROOT, or nothing.
org_of() {
  local root rel
  root="$(realpath -m -- "$ORGS_ROOT")"
  rel="${1#"$root"/}"
  [[ "$rel" == "$1" ]] || printf '%s\n' "${rel%%/*}"
}

infer_org() {
  local org
  org="$(org_of "$(pwd -P)")"
  [[ -n "$org" ]] || die "no org given, and $PWD is not under ~/$AGENT_ORGS_SUBDIR/<org>"
  printf '%s\n' "$org"
}

fleet_dir() {
  local org="$1"
  [[ -n "$org" && "$org" != *[^A-Za-z0-9._-]* && "$org" != . && "$org" != .. ]] \
    || { echo "org must be one safe path component: $org" >&2; return 1; }
  [[ -d "$ORGS_ROOT/$org" && ! -L "$ORGS_ROOT/$org" ]] \
    || { echo "no safe org directory: $ORGS_ROOT/$org" >&2; return 1; }
  printf '%s\n' "$ORGS_ROOT/$org"
}

# launch <dir> <profile> <claude-profile> [<cmd>...]; REBUILD=1 recreates the container.
launch() {
  local dir="$1" profile="$2" claude_profile="$3"
  shift 3
  local -a cmd=("$@")
  ((${#cmd[@]})) || cmd=(zsh)
  # Fleet mounts the org at /workspace, but the caller may be in a repo or
  # subdirectory. Pass paths and command arguments separately, never as code.
  if [[ "$profile" == fleet ]]; then
    local cwd root
    cwd="$(pwd -P)"
    root="$(realpath -- "$dir")"
    if [[ "$cwd" == "$root/"* ]]; then
      # shellcheck disable=SC2016 # expanded inside the container, not on the host
      cmd=(sh -c 'cd -- "$1" && shift && exec "$@"' agent-shell "/workspace/${cwd#"$root/"}" "${cmd[@]}")
    fi
  fi
  local config identity listing id="" built="" rc=0
  local -a identity_args up_args=()

  # One VM round-trip: Docker binds an unmounted source as an empty dir.
  # shellcheck disable=SC2016
  colima ssh -- sh -c 'test -d "$1" || exit 3; [ -z "$2" ] || test -S "$2" || exit 4' _ \
    "$dir" "$([[ "$profile" == fleet ]] && echo "$AGENT_SOCK")" &>/dev/null || rc=$?
  case "$rc" in
    0) ;;
    4) { echo "colima has no SSH agent socket; run: colima stop && colima start --ssh-agent" >&2; return 1; } ;;
    *) { echo "workspace not mounted in the Colima VM (see colima.yaml mounts): $dir" >&2; return 1; } ;;
  esac
  config="$(stage "$profile")" || return 1

  # devcontainerId hashes the id-labels, so the account label isolates the volumes too.
  identity="$(identity_profile "$profile" "$claude_profile")"
  identity_args=(
    --id-label "devcontainer.local_folder=$dir"
    --id-label "agent.devcontainer.profile=$identity"
  )
  [[ "$identity" == "$profile" ]] \
    || identity_args+=(--id-label "agent.devcontainer.claude-profile=$claude_profile")

  listing=$(docker ps -a --filter "label=devcontainer.local_folder=$dir" \
    --filter "label=agent.devcontainer.profile=$identity" \
    --format '{{.ID}} {{.Label "agent.devcontainer.devc"}}') \
    || { echo "could not list containers; run agent doctor" >&2; return 1; }
  read -r id built <<<"$listing" || true
  if [[ "${REBUILD:-0}" != 1 && -n "$id" && "$built" != "$AGENT_DEVC" ]]; then
    echo "Container templates changed since it was built; rebuilding (logins and history are kept, other container changes are not)." >&2
    REBUILD=1
  fi
  [[ "${REBUILD:-0}" != 1 ]] || up_args+=(--remove-existing-container)
  timing "workspace setup"

  (
    export DOTFILES_PATH="$AGENT_DOTFILES" AGENT_DEVC
    AGENT_ORG="$(org_of "$dir")"
    export AGENT_ORG
    if [[ "$profile" == audit ]]; then
      unset CLAUDE_CODE_OAUTH_TOKEN ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN
      unset OPENAI_API_KEY CODEX_API_KEY AGENT_CLAUDE_PROFILE
    else
      export AGENT_CLAUDE_PROFILE="$claude_profile"
      # Anthropic API credentials outrank the OAuth token; keep the explicit account.
      unset ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN
      export_secret CLAUDE_CODE_OAUTH_TOKEN "${AGENT_PROFILES[$claude_profile]}" "Claude ($claude_profile)"
      export_secret CODEX_API_KEY "$CODEX_SERVICE" Codex
    fi
    timing "credentials"

    cd "$dir" || exit 1
    devcontainer up --workspace-folder "$dir" --config "$config" \
      "${identity_args[@]}" "${up_args[@]}" || exit 1
    timing "container startup"
    devcontainer exec --workspace-folder "$dir" --config "$config" \
      "${identity_args[@]}" "${cmd[@]}"
  )
}

# Fleet .git changes run under host Git; detect them before launch and on exit.
git_guard() {
  local action="$1" org="$2" dir="$3" rc=0
  "$AGENT_DEVC/libexec/devc-git-guard" "$action" "$dir" "$HOME/.local/state/agent-devcontainer/git-guard/$org.json" || rc=$?
  ((rc != 1)) || echo "If you made these changes yourself, accept them with: agent trust $org" >&2
  return "$rc"
}

# The exit check cannot see writes from agents that outlive the shell.
warn_running_agents() {
  local org="$1" dir="$2" identity="$3" id listing
  listing=$(containers "devcontainer.local_folder=$dir" "agent.devcontainer.profile=$identity") \
    || { echo "could not check for running agents; run agent doctor" >&2; return 0; }
  for id in $listing; do
    if docker top "$id" -eo args 2>/dev/null | grep -qE '(^|[ /])(claude|codex)( |$)'; then
      echo "Agents are still running in the fleet container; .git changes they make after this check go unseen." >&2
      echo "Stop it with: agent stop $org" >&2
    fi
  done
}

cmd_trust() {
  (($# <= 1)) || die "usage: $TRUST_USAGE"
  local org="${1:-}" dir
  [[ -n "$org" ]] || org="$(infer_org)"
  dir="$(fleet_dir "$org")"
  git_guard accept "$org" "$dir"
}

# One trusted container per org: both agents, per-profile logins, gh auth and the signing agent.
cmd_fleet() {
  export AGENT_SKIP_UPDATE=0
  local claude_profile="$AGENT_DEFAULT_PROFILE" org="" dir rc=0
  local -a cmd=()
  while (($#)); do
    case "$1" in
      --rebuild) REBUILD=1 ;;
      --no-update) AGENT_SKIP_UPDATE=1 ;;
      --alt) claude_profile=alt ;;
      -p | --profile)
        (($# >= 2)) || die "usage: $FLEET_USAGE"
        claude_profile="$2"
        shift
        ;;
      --)
        shift
        cmd=("$@")
        break
        ;;
      -*) die "unknown agent fleet option: $1"$'\n'"usage: $FLEET_USAGE" ;;
      *)
        [[ -z "$org" ]] || die "usage: $FLEET_USAGE"
        org="$1"
        ;;
    esac
    shift
  done

  [[ -n "$claude_profile" && "$claude_profile" != *[^A-Za-z0-9_-]* ]] \
    || die "invalid Claude profile: $claude_profile"
  [[ -n "${AGENT_PROFILES[$claude_profile]:-}" ]] \
    || die "unknown Claude profile '$claude_profile' (use $(
      IFS='|'
      echo "${AGENT_PROFILE_NAMES[*]}"
    ))"
  [[ -n "$org" ]] || org="$(infer_org)"
  dir="$(fleet_dir "$org")"

  timing "arguments"
  preflight ssh-add
  ssh-add --apple-load-keychain &>/dev/null || true
  ssh-add "$SIGNING_KEY" &>/dev/null || die "could not load signing key: $SIGNING_KEY"
  git_guard check "$org" "$dir" || true
  timing "signing and Git guard"
  launch "$dir" fleet "$claude_profile" "${cmd[@]}" || rc=$?
  git_guard check "$org" "$dir" || true
  warn_running_agents "$org" "$dir" "$(identity_profile fleet "$claude_profile")"
  exit "$rc"
}

# Per-repository containers with no host credentials or SSH agent.
cmd_audit() {
  local target="." dir
  if [[ $# -gt 0 && "$1" != -- ]]; then
    [[ "$1" != -* ]] || die "usage: $AUDIT_USAGE"
    target="$1"
    shift
  fi
  if (($#)); then
    [[ "$1" == -- ]] || die "usage: $AUDIT_USAGE"
    shift
  fi

  if [[ "$target" == *://* || "$target" == *@*:* ]]; then
    dir="$("$AGENT_DEVC/libexec/devc-audit-slug" --prepare "$HOME/sandbox/audit" "$target")"
  else
    # Check -L before realpath, which resolves symlinks.
    [[ ! -L "$target" ]] || die "refusing symlinked target: $target"
    dir="$(realpath -m -- "$target")"
    [[ -d "$dir" && ! -L "$dir" ]] || die "no safe directory: $dir"
    [[ -d "$dir/.git" ]] || die "not a git checkout (audit mounts .git read-only): $dir"
  fi

  preflight
  echo "Audit profile: no host AI/API credentials or SSH agent are forwarded." >&2
  echo "Use 'codex login --device-auth' or interactive Claude login inside this isolated container." >&2
  launch "$dir" audit "" "$@"
}

cmd_ls() {
  (($# == 0)) || die "usage: $LS_USAGE"
  require_commands docker
  docker ps -a --filter label=agent.devcontainer.profile \
    --format 'table {{.ID}}\t{{.Label "agent.devcontainer.profile"}}\t{{.Label "agent.devcontainer.org"}}\t{{.Status}}\t{{.Label "devcontainer.local_folder"}}' \
    || die "could not list containers; run agent doctor"
}

cmd_stop() {
  (($# <= 1)) || die "usage: $STOP_USAGE"
  require_commands docker
  local listing
  local -a ids=() filters=()
  if [[ "${1:-}" != --all ]]; then
    local org="${1:-}"
    [[ -n "$org" ]] || org="$(infer_org)"
    fleet_dir "$org" >/dev/null
    filters+=("agent.devcontainer.org=$org")
  fi
  listing=$(containers "${filters[@]}") || die "could not list containers; run agent doctor"
  [[ -n "$listing" ]] || { echo "no agent containers to stop" >&2; return 0; }
  mapfile -t ids <<<"$listing"
  docker stop "${ids[@]}" >/dev/null || die "could not stop containers; run agent doctor"
  echo "stopped ${#ids[@]} container(s)" >&2
}

# Value of a top-level `key: value` line in colima.yaml.
yaml_value() {
  sed -n "s/^$1:[[:space:]]*\([^#[:space:]]*\).*/\1/p" "$2" | head -n1
}

cmd_doctor() {
  (($# == 0)) || die "usage: $DOCTOR_USAGE"
  local failures=0 config="$HOME/.colima/default/colima.yaml"
  # report <status> <text>[|<fix>]: the fix is shown only on failure.
  report() {
    if (($1 == 0)); then
      echo "ok    ${2%%|*}"
    else
      if [[ "$2" == *"|"* ]]; then echo "FAIL  ${2%%|*} (${2#*|})"; else echo "FAIL  $2"; fi
      failures=$((failures + 1))
    fi
  }
  check() {
    local label="$1"
    shift
    if "$@" &>/dev/null; then report 0 "$label"; else report 1 "$label"; fi
  }
  same_generation() { [[ "$(readlink -f /run/current-system)" == "$(readlink -f /nix/var/nix/profiles/system)" ]]; }
  signing_key_loaded() {
    local fingerprint
    fingerprint="$(ssh-keygen -lf "$SIGNING_KEY.pub" | cut -d' ' -f2)"
    [[ -n "$fingerprint" ]] && ssh-add -l | grep -qF -- "$fingerprint"
  }
  vm_resources_match() {
    local cpus mem
    read -r cpus mem < <(jq -r '"\(.cpus) \(.memory / 1073741824)"' <<<"$1")
    [[ "$cpus" == "$(yaml_value cpu "$config")" && "$mem" == "$(yaml_value memory "$config")" ]]
  }
  # Negate the file test inside the VM, so a failed SSH connection is a failure.
  # shellcheck disable=SC2016
  ssh_hidden() { colima ssh -- sh -c 'test ! -e "$1"' _ "$HOME/.ssh"; }

  check "devcontainer CLI installed" command -v devcontainer
  check "colima installed" command -v colima
  check "docker installed" command -v docker
  check "ssh-add installed" command -v ssh-add
  check "Docker daemon reachable|check the Docker context and colima status" docker info
  [[ ! -e /run/current-system ]] \
    || check "latest system generation is active|rerun make switch" same_generation
  [[ -r "$config" ]] || report 1 "colima config readable: $config"

  local vm location mounts
  if ! vm="$(colima_vm)" || [[ "$(jq -r .status <<<"$vm")" != Running ]]; then
    report 1 "colima VM running|colima start --ssh-agent"
  else
    report 0 "colima VM running"
    check "VM resources match colima.yaml|restart colima after changing them" vm_resources_match "$vm"
    if mounts="$(colima ssh -- mount 2>/dev/null | awk '$5 == "virtiofs" { print $3 }')"; then
      while read -r location; do
        location="${location/#\~/$HOME}"
        check "VM mounts $location|restart colima after changing mounts" grep -qxF -- "$location" <<<"$mounts"
      done < <(sed -n 's/^[[:space:]]*-[[:space:]]*location:[[:space:]]*//p' "$config" 2>/dev/null)
    else
      report 1 "VM mount list readable|check colima ssh connectivity"
    fi
    check "host ~/.ssh hidden from the VM|drop it from the colima.yaml mounts" ssh_hidden
    check "SSH agent socket forwarded into the VM|colima stop && colima start --ssh-agent" colima ssh -- test -S "$AGENT_SOCK"
  fi
  check "signing key loaded in ssh-agent|agent fleet loads it on launch" signing_key_loaded

  # Optional secrets, so only warn; without -w they are never read.
  local service
  for service in "${AGENT_PROFILES[@]}" "$CODEX_SERVICE"; do
    if security find-generic-password -a "$USER" -s "$service" &>/dev/null; then
      echo "ok    keychain item $service"
    else
      echo "warn  keychain item $service missing; that agent falls back to interactive login"
    fi
  done

  ((failures == 0)) || die "$failures check(s) failed"
}

subcommand="${1:-}"
shift $(($# > 0))
# Only a standalone help flag belongs to the launcher. Arguments after --
# (including --help for Claude or Codex) must reach the container unchanged.
case "$subcommand" in
  fleet | trust | audit | ls | stop | doctor)
    if (($# == 1)) && [[ "$1" == --help || "$1" == -h ]]; then
      help "$subcommand"
      exit 0
    fi
    ;;
esac
case "$subcommand" in
  help)
    (($# <= 1)) || die "usage: agent help [command]"
    help "${1:-}"
    ;;
  --help | -h)
    (($# == 0)) || die "usage: agent --help"
    help
    ;;
  fleet) cmd_fleet "$@" ;;
  trust) cmd_trust "$@" ;;
  audit) cmd_audit "$@" ;;
  ls) cmd_ls "$@" ;;
  stop) cmd_stop "$@" ;;
  doctor) cmd_doctor "$@" ;;
  *) usage >&2; exit 1 ;;
esac
