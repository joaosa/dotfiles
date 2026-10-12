# shellcheck shell=bash
# Body of `agent`; agent.nix prepends AGENT_DEVC, AGENT_DOTFILES,
# AGENT_DEFAULT_PROFILE, AGENT_TEMPLATE_FILES and AGENT_PROFILES.
# Host tools (colima, docker, devcontainer, security, ssh-add) come from the
# caller's PATH: Apple's ssh-add is the one that knows --apple-load-keychain.
#
# Agent devcontainers use trusted configs staged outside each checkout.
# Repository-owned .devcontainer files are never read, overwritten, or
# followed as symlinks.

FLEET_USAGE="usage: agent fleet [--rebuild] [--alt | -p <profile>] <org>"

die() {
  echo "$*" >&2
  exit 1
}

usage() {
  echo "$FLEET_USAGE" >&2
  echo "       agent trust <org>" >&2
  echo "       agent audit <repo-path-or-url>" >&2
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

launch() {
  local dir="$1" profile="$2" rebuild="${3:-0}"
  local claude_profile="${4:-}" claude_service="${5:-}" config
  local identity_profile="$profile"
  local -a account_identity_args=() identity_args=() up_args=()
  # Docker binds an unmounted source as an empty VM dir; fail instead.
  colima ssh -- test -d "$dir" &>/dev/null \
    || { echo "workspace not mounted in the Colima VM (see colima.yaml mounts): $dir" >&2; return 1; }
  config="$(stage "$profile")" || return 1

  # Preserve the pre-multi-account identity for the default profile. Every
  # other profile gets a distinct profile value as well as an account label,
  # so a lookup for the legacy labels cannot also match it. devcontainerId is
  # a hash of the full label set, so all named volumes are isolated too.
  if [[ -n "$claude_profile" && "$claude_profile" != "$AGENT_DEFAULT_PROFILE" ]]; then
    identity_profile="$profile-$claude_profile"
    account_identity_args=(--id-label "agent.devcontainer.claude-profile=$claude_profile")
  fi
  identity_args=(
    --id-label "devcontainer.local_folder=$dir"
    --id-label "agent.devcontainer.profile=$identity_profile"
    "${account_identity_args[@]}"
  )
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
    devcontainer exec \
      --workspace-folder "$dir" \
      --config "$config" \
      "${identity_args[@]}" \
      zsh
  )
}

# Fleet .git changes run under host Git; detect them before launch and on exit.
fleet_dir() {
  local org="$1"
  [[ -n "$org" && "$org" != *[^A-Za-z0-9._-]* && "$org" != . && "$org" != .. ]] \
    || { echo "org must be one safe path component: $org" >&2; return 1; }
  local dir="$HOME/ghq/github.com/$org"
  [[ -d "$dir" && ! -L "$dir" ]] || { echo "no safe org directory: $dir" >&2; return 1; }
  printf '%s\n' "$dir"
}

git_guard() {
  local action="$1" org="$2" dir rc=0
  dir="$(fleet_dir "$org")" || return 1
  "$AGENT_DEVC/libexec/devc-git-guard" "$action" "$dir" \
    "$HOME/.local/state/agent-devcontainer/git-guard/$org.json" || rc=$?
  ((rc != 1)) || echo "If you made these changes yourself, accept them with: agent trust $org" >&2
  return "$rc"
}

cmd_trust() {
  (($# == 1)) || die "usage: agent trust <org>"
  git_guard accept "$1"
}

# One trusted container over every repository in an organization. It carries
# both Claude and Codex, profile-specific login volumes, gh auth, and the
# forwarded signing agent. Only use this over organizations you trust.
cmd_fleet() {
  local rebuild=0 claude_profile="$AGENT_DEFAULT_PROFILE"
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
        break
        ;;
      -*)
        echo "unknown agent fleet option: $1" >&2
        die "$FLEET_USAGE"
        ;;
      *)
        break
        ;;
    esac
  done

  (($# == 1)) || die "$FLEET_USAGE"
  [[ -n "$claude_profile" && "$claude_profile" != *[^A-Za-z0-9_-]* ]] \
    || die "invalid Claude profile: $claude_profile"
  local claude_service="${AGENT_PROFILES[$claude_profile]:-}"
  [[ -n "$claude_service" ]] \
    || die "unknown Claude profile '$claude_profile' (use $(printf '%s\n' "${!AGENT_PROFILES[@]}" | sort | paste -sd'|'))"

  local org="$1" dir rc=0
  dir="$(fleet_dir "$org")" || exit 1

  preflight
  local signing_key="$HOME/.ssh/id_ed25519"
  ssh-add --apple-load-keychain &>/dev/null || true
  ssh-add "$signing_key" &>/dev/null || die "could not load signing key: $signing_key"
  colima ssh -- test -S /run/host-services/ssh-auth.sock &>/dev/null \
    || die "colima has no SSH agent socket; run: colima stop && agent fleet $org"
  git_guard check "$org" || true
  launch "$dir" fleet "$rebuild" "$claude_profile" "$claude_service" || rc=$?
  git_guard check "$org" || true
  exit "$rc"
}

# Per-repository audit containers receive no host AI/API credentials or SSH
# agent. URL destinations are validated and created by the pinned helper, and
# the trusted config lives outside the checkout.
cmd_audit() {
  (($# == 1)) || die "usage: agent audit <repo-path-or-url>"
  local target="$1" dir rc=0
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
  launch "$dir" audit || rc=$?
  exit "$rc"
}

cmd="${1:-}"
shift $(($# > 0))
case "$cmd" in
  fleet) cmd_fleet "$@" ;;
  trust) cmd_trust "$@" ;;
  audit) cmd_audit "$@" ;;
  *) usage ;;
esac
