# shellcheck shell=bash
# Body of `agent`; agent.nix prepends AGENT_DEVC, AGENT_DOTFILES,
# AGENT_DEFAULT_PROFILE, AGENT_TEMPLATE_FILES and AGENT_PROFILES.
# Host tools (colima, docker, devcontainer, security, ssh-add) come from the
# caller's PATH: Apple's ssh-add is the one that knows --apple-load-keychain.
#
# Agent devcontainers use trusted configs staged outside each checkout.
# Repository-owned .devcontainer files are never read, overwritten, or
# followed as symlinks.

ORGS_ROOT="$HOME/ghq/github.com"
STATE_DIR="$HOME/.local/state/agent-devcontainer"
FLEET_USAGE="usage: agent fleet [--rebuild] [--alt | -p <profile>] [<org>] [-- <cmd>...]"
AUDIT_USAGE="usage: agent audit [<repo-path-or-url>] [-- <cmd>...]"
STOP_USAGE="usage: agent stop [<org> | --all]"

die() {
  echo "$*" >&2
  exit 1
}

usage() {
  echo "$FLEET_USAGE" >&2
  echo "       agent trust [<org>]" >&2
  echo "       ${AUDIT_USAGE#usage: }" >&2
  echo "       agent ls" >&2
  echo "       ${STOP_USAGE#usage: }" >&2
  echo "       agent doctor" >&2
  exit 1
}

preflight() {
  command -v devcontainer &>/dev/null || die "devcontainer CLI not installed (run make switch)"
  colima status &>/dev/null || colima start --ssh-agent
}

stage() {
  local profile="$1"
  local cache="$HOME/.cache"
  local root="$cache/agent-devcontainer"
  local dir="$root/$profile"
  local p file

  for p in "$cache" "$root" "$dir"; do
    [[ ! -L "$p" ]] || { echo "refusing symlinked agent cache path: $p" >&2; return 1; }
    if [[ -e "$p" ]]; then
      [[ -d "$p" && -O "$p" ]] || { echo "agent cache path is not an owned directory: $p" >&2; return 1; }
    else
      mkdir "$p" || return 1
    fi
  done

  for file in "${AGENT_TEMPLATE_FILES[@]}"; do
    [[ ! -L "$dir/$file" ]] || { echo "refusing symlinked staged file: $dir/$file" >&2; return 1; }
    install -m0644 "$AGENT_DEVC/share/agent-devcontainer/$file" "$dir/$file" || return 1
  done
  [[ ! -L "$dir/devcontainer.json" ]] \
    || { echo "refusing symlinked staged config: $dir/devcontainer.json" >&2; return 1; }
  install -m0644 "$AGENT_DEVC/share/agent-devcontainer/$profile.devcontainer.json" \
    "$dir/devcontainer.json" || return 1
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

# Container ids carrying the given identity labels (label=value ...).
containers() {
  local -a filters=(--filter label=agent.devcontainer.profile)
  local label
  for label in "$@"; do filters+=(--filter "label=$label"); done
  docker ps -aq "${filters[@]}"
}

# The identity profile label: the default profile keeps the pre-multi-account
# value, so its container and named volumes survive.
identity_profile() {
  local profile="$1" claude_profile="${2:-}"
  if [[ -n "$claude_profile" && "$claude_profile" != "$AGENT_DEFAULT_PROFILE" ]]; then
    printf '%s\n' "$profile-$claude_profile"
  else
    printf '%s\n' "$profile"
  fi
}

# launch <dir> <profile> <rebuild> <claude-profile> <claude-service> <cmd>...
launch() {
  local dir="$1" profile="$2" rebuild="$3" claude_profile="$4" claude_service="$5"
  shift 5
  local -a cmd=("$@")
  ((${#cmd[@]})) || cmd=(zsh)
  local config identity stamp
  local -a identity_args=() up_args=()
  # Docker binds an unmounted source as an empty VM dir; fail instead.
  colima ssh -- test -d "$dir" &>/dev/null \
    || { echo "workspace not mounted in the Colima VM (see colima.yaml mounts): $dir" >&2; return 1; }
  config="$(stage "$profile")" || return 1

  # devcontainerId hashes the full id-label set, so the extra account label
  # also isolates every named volume between Claude profiles.
  identity="$(identity_profile "$profile" "$claude_profile")"
  identity_args=(
    --id-label "devcontainer.local_folder=$dir"
    --id-label "agent.devcontainer.profile=$identity"
  )
  if [[ "$identity" != "$profile" ]]; then
    identity_args+=(--id-label "agent.devcontainer.claude-profile=$claude_profile")
  fi

  # The devc store path changes with any template or allowlist change. It is
  # kept outside the id-labels so a rebuild keeps the login volumes.
  stamp="$STATE_DIR/templates/$(printf '%s' "$identity:$dir" | sha256sum | cut -c1-16)"
  if [[ "$rebuild" != 1 && -n "$(containers "devcontainer.local_folder=$dir" "agent.devcontainer.profile=$identity")" \
    && "$(cat "$stamp" 2>/dev/null)" != "$AGENT_DEVC" ]]; then
    echo "Container templates changed since it was built; rebuilding (logins and history are kept, other container changes are not)." >&2
    rebuild=1
  fi
  if [[ "$rebuild" == 1 ]]; then
    up_args+=(--remove-existing-container)
  fi

  (
    export DOTFILES_PATH="$AGENT_DOTFILES"
    if [[ "$profile" == audit ]]; then
      unset CLAUDE_CODE_OAUTH_TOKEN ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN
      unset OPENAI_API_KEY CODEX_API_KEY AGENT_CLAUDE_PROFILE
    else
      export AGENT_CLAUDE_PROFILE="$claude_profile"
      # Anthropic API credentials outrank CLAUDE_CODE_OAUTH_TOKEN;
      # do not let ambient host state defeat the explicit account.
      unset ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN
      export_secret CLAUDE_CODE_OAUTH_TOKEN "$claude_service" "Claude ($claude_profile)"
      export_secret CODEX_API_KEY codex-api-key Codex
    fi

    cd "$dir" || exit 1
    devcontainer up \
      --workspace-folder "$dir" \
      --config "$config" \
      "${identity_args[@]}" \
      "${up_args[@]}" \
      || exit 1
    mkdir -p "${stamp%/*}" && printf '%s\n' "$AGENT_DEVC" >"$stamp"
    devcontainer exec \
      --workspace-folder "$dir" \
      --config "$config" \
      "${identity_args[@]}" \
      "${cmd[@]}"
  )
}

# The org owning the current directory, for commands run inside a checkout.
infer_org() {
  local here root rel
  here="$(pwd -P)"
  root="$(realpath -m -- "$ORGS_ROOT")"
  rel="${here#"$root"/}"
  [[ "$rel" != "$here" && -n "$rel" ]] \
    || die "no org given, and $PWD is not under ${ORGS_ROOT/#"$HOME"/\~}/<org>"
  printf '%s\n' "${rel%%/*}"
}

fleet_dir() {
  local org="$1"
  [[ -n "$org" && "$org" != *[^A-Za-z0-9._-]* && "$org" != . && "$org" != .. ]] \
    || { echo "org must be one safe path component: $org" >&2; return 1; }
  local dir="$ORGS_ROOT/$org"
  [[ -d "$dir" && ! -L "$dir" ]] || { echo "no safe org directory: $dir" >&2; return 1; }
  printf '%s\n' "$dir"
}

# Fleet .git changes run under host Git; detect them before launch and on exit.
git_guard() {
  local action="$1" org="$2" dir rc=0
  dir="$(fleet_dir "$org")" || return 1
  "$AGENT_DEVC/libexec/devc-git-guard" "$action" "$dir" "$STATE_DIR/git-guard/$org.json" || rc=$?
  ((rc != 1)) || echo "If you made these changes yourself, accept them with: agent trust $org" >&2
  return "$rc"
}

# The exit check cannot see writes from agents that outlive the shell.
warn_running_agents() {
  local org="$1" dir="$2" identity="$3" id
  for id in $(containers "devcontainer.local_folder=$dir" "agent.devcontainer.profile=$identity"); do
    if docker top "$id" -eo args 2>/dev/null | grep -qE '(^|[ /])(claude|codex)( |$)'; then
      echo "Agents are still running in the fleet container; .git changes they make after this check go unseen." >&2
      echo "Stop it with: agent stop $org" >&2
    fi
  done
}

cmd_trust() {
  (($# <= 1)) || die "usage: agent trust [<org>]"
  local org="${1:-}"
  [[ -n "$org" ]] || org="$(infer_org)"
  git_guard accept "$org"
}

# One trusted container over every repository in an organization. It carries
# both Claude and Codex, profile-specific login volumes, gh auth, and the
# forwarded signing agent. Only use this over organizations you trust.
cmd_fleet() {
  local rebuild=0 claude_profile="$AGENT_DEFAULT_PROFILE" org=""
  local -a cmd=()
  while (($#)); do
    case "$1" in
      --rebuild)
        rebuild=1
        shift
        ;;
      --alt)
        claude_profile=alt
        shift
        ;;
      -p | --profile)
        (($# >= 2)) || die "$FLEET_USAGE"
        claude_profile="$2"
        shift 2
        ;;
      --)
        shift
        cmd=("$@")
        break
        ;;
      -*)
        echo "unknown agent fleet option: $1" >&2
        die "$FLEET_USAGE"
        ;;
      *)
        [[ -z "$org" ]] || die "$FLEET_USAGE"
        org="$1"
        shift
        ;;
    esac
  done

  [[ -n "$claude_profile" && "$claude_profile" != *[^A-Za-z0-9_-]* ]] \
    || die "invalid Claude profile: $claude_profile"
  local claude_service="${AGENT_PROFILES[$claude_profile]:-}"
  [[ -n "$claude_service" ]] \
    || die "unknown Claude profile '$claude_profile' (use $(printf '%s\n' "${!AGENT_PROFILES[@]}" | sort | paste -sd'|'))"
  [[ -n "$org" ]] || org="$(infer_org)"

  local dir rc=0
  dir="$(fleet_dir "$org")" || exit 1

  preflight
  local signing_key="$HOME/.ssh/id_ed25519"
  ssh-add --apple-load-keychain &>/dev/null || true
  ssh-add "$signing_key" &>/dev/null || die "could not load signing key: $signing_key"
  colima ssh -- test -S /run/host-services/ssh-auth.sock &>/dev/null \
    || die "colima has no SSH agent socket; run: colima stop && agent fleet $org"
  git_guard check "$org" || true
  launch "$dir" fleet "$rebuild" "$claude_profile" "$claude_service" "${cmd[@]}" || rc=$?
  git_guard check "$org" || true
  warn_running_agents "$org" "$dir" "$(identity_profile fleet "$claude_profile")"
  exit "$rc"
}

# Per-repository audit containers receive no host AI/API credentials or SSH
# agent. URL destinations are validated and created by the pinned helper, and
# the trusted config lives outside the checkout.
cmd_audit() {
  local target="" dir rc=0
  local -a cmd=()
  while (($#)); do
    case "$1" in
      --)
        shift
        cmd=("$@")
        break
        ;;
      -*) die "$AUDIT_USAGE" ;;
      *)
        [[ -z "$target" ]] || die "$AUDIT_USAGE"
        target="$1"
        shift
        ;;
    esac
  done
  [[ -n "$target" ]] || target=.

  if [[ "$target" == *://* || "$target" == *@*:* ]]; then
    dir="$("$AGENT_DEVC/libexec/devc-audit-slug" --prepare "$HOME/sandbox/audit" "$target")" || exit 1
  else
    # Reject a symlinked target on the raw path: realpath resolves symlinks,
    # so testing -L after it would always pass.
    [[ ! -L "$target" ]] || die "refusing symlinked target: $target"
    dir="$(realpath -m -- "$target")"
    [[ -d "$dir" && ! -L "$dir" ]] || die "no safe directory: $dir"
    [[ -d "$dir/.git" ]] || die "not a git checkout (audit mounts .git read-only): $dir"
  fi

  preflight
  echo "Audit profile: no host AI/API credentials or SSH agent are forwarded." >&2
  echo "Use 'codex login --device-auth' or interactive Claude login inside this isolated container." >&2
  launch "$dir" audit 0 "" "" "${cmd[@]}" || rc=$?
  exit "$rc"
}

cmd_ls() {
  (($# == 0)) || die "usage: agent ls"
  docker ps -a --filter label=agent.devcontainer.profile \
    --format 'table {{.ID}}\t{{.Label "agent.devcontainer.profile"}}\t{{.Status}}\t{{.Label "devcontainer.local_folder"}}'
}

cmd_stop() {
  local -a ids=()
  if [[ "${1:-}" == --all ]]; then
    (($# == 1)) || die "$STOP_USAGE"
    mapfile -t ids < <(containers)
  else
    (($# <= 1)) || die "$STOP_USAGE"
    local org="${1:-}" dir
    [[ -n "$org" ]] || org="$(infer_org)"
    dir="$(fleet_dir "$org")" || exit 1
    mapfile -t ids < <(containers "devcontainer.local_folder=$dir")
  fi
  ((${#ids[@]})) || { echo "no agent containers to stop" >&2; return 0; }
  docker stop "${ids[@]}" >/dev/null
  echo "stopped ${#ids[@]} container(s)" >&2
}

# Value of a top-level `key: value` line in colima.yaml.
yaml_value() {
  sed -n "s/^$1:[[:space:]]*\([^#[:space:]]*\).*/\1/p" "$2" | head -n1
}

cmd_doctor() {
  (($# == 0)) || die "usage: agent doctor"
  local failures=0 config="$HOME/.colima/default/colima.yaml"
  ok() { echo "ok    $*"; }
  bad() {
    echo "FAIL  $*"
    failures=$((failures + 1))
  }
  warn() { echo "warn  $*"; }
  check() {
    local label="$1"
    shift
    if "$@" &>/dev/null; then ok "$label"; else bad "$label"; fi
  }

  check "devcontainer CLI installed" command -v devcontainer
  if [[ -e /run/current-system && -e /nix/var/nix/profiles/system ]]; then
    if [[ "$(readlink -f /run/current-system)" == "$(readlink -f /nix/var/nix/profiles/system)" ]]; then
      ok "latest system generation is active"
    else
      bad "latest system generation is not active (activation failed? rerun make switch)"
    fi
  fi

  if [[ ! -r "$config" ]]; then
    bad "colima config readable: $config"
  elif [[ -z "$(yaml_value runtime "$config")" ]]; then
    bad "colima.yaml sets runtime (without it colima ignores the whole file)"
  else
    ok "colima.yaml sets runtime"
  fi

  local vm
  if ! vm="$(colima list --json 2>/dev/null)" || [[ "$(jq -r .status <<<"$vm")" != Running ]]; then
    bad "colima VM running (start it with: colima start --ssh-agent)"
  else
    ok "colima VM running"
    local want_cpu want_mem
    want_cpu="$(yaml_value cpu "$config" 2>/dev/null)"
    want_mem="$(yaml_value memory "$config" 2>/dev/null)"
    if [[ -n "$want_cpu" && "$(jq -r .cpus <<<"$vm")" != "$want_cpu" ]] \
      || [[ -n "$want_mem" && "$(jq -r '.memory / 1073741824' <<<"$vm")" != "$want_mem" ]]; then
      bad "VM resources match colima.yaml (want ${want_cpu:-?} CPUs, ${want_mem:-?} GiB; restart colima)"
    else
      ok "VM resources match colima.yaml"
    fi

    local mounts location
    mounts="$(colima ssh -- mount 2>/dev/null | awk '$5 == "virtiofs" { print $3 }')"
    while read -r location; do
      location="${location/#\~/$HOME}"
      if grep -qxF -- "$location" <<<"$mounts"; then
        ok "VM mounts $location"
      else
        bad "VM mounts $location (restart colima after changing mounts)"
      fi
    done < <(sed -n 's/^[[:space:]]*-[[:space:]]*location:[[:space:]]*//p' "$config" 2>/dev/null)
    if colima ssh -- test -e "$HOME/.ssh" &>/dev/null; then
      bad "host ~/.ssh hidden from the VM"
    else
      ok "host ~/.ssh hidden from the VM"
    fi
    check "SSH agent socket forwarded into the VM" colima ssh -- test -S /run/host-services/ssh-auth.sock
  fi

  local signing_key="$HOME/.ssh/id_ed25519" fingerprint
  if fingerprint="$(ssh-keygen -lf "$signing_key.pub" 2>/dev/null | cut -d' ' -f2)" && [[ -n "$fingerprint" ]] \
    && ssh-add -l 2>/dev/null | grep -qF -- "$fingerprint"; then
    ok "signing key loaded in ssh-agent"
  else
    bad "signing key loaded in ssh-agent (agent fleet loads it on launch)"
  fi

  # Optional secrets, so only warn. Presence only: without -w they are never read.
  local name service
  for name in $(printf '%s\n' "${!AGENT_PROFILES[@]}" | sort) codex; do
    service="${AGENT_PROFILES[$name]:-codex-api-key}"
    if security find-generic-password -a "$USER" -s "$service" &>/dev/null; then
      ok "keychain item $service"
    else
      warn "keychain item $service missing; that agent falls back to interactive login"
    fi
  done

  ((failures == 0)) || { echo "$failures check(s) failed" >&2; exit 1; }
}

subcommand="${1:-}"
shift $(($# > 0))
case "$subcommand" in
  fleet) cmd_fleet "$@" ;;
  trust) cmd_trust "$@" ;;
  audit) cmd_audit "$@" ;;
  ls) cmd_ls "$@" ;;
  stop) cmd_stop "$@" ;;
  doctor) cmd_doctor "$@" ;;
  *) usage ;;
esac
