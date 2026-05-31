#
# Defines environment variables.
#
# Authors:
#   Sorin Ionescu <sorin.ionescu@gmail.com>
#

typeset -gU path

_remove_legacy_runtime_paths() {
  local -a cleaned_path
  local path_entry

  for path_entry in "${path[@]}"; do
    case "$path_entry" in
      "$HOME/.asdf/bin"|"$HOME/.asdf/shims"|"$HOME/.asdf/plugins/"*/shims)
        ;;
      *)
        cleaned_path+=("$path_entry")
        ;;
    esac
  done

  path=("${cleaned_path[@]}")
}

_prefer_nix_profile_paths() {
  path=(
    "/etc/profiles/per-user/$USER/bin"
    "$HOME/.nix-profile/bin"
    /nix/var/nix/profiles/default/bin
    $path
  )
}

_remove_legacy_runtime_paths
_prefer_nix_profile_paths

# Ensure that a non-login, non-interactive shell has a defined environment.
if [[ ( "$SHLVL" -eq 1 && ! -o LOGIN ) && -s "${ZDOTDIR:-$HOME}/.zprofile" ]]; then
  source "${ZDOTDIR:-$HOME}/.zprofile"
fi
. "$HOME/.cargo/env"

_remove_legacy_runtime_paths
_prefer_nix_profile_paths
unset -f _remove_legacy_runtime_paths _prefer_nix_profile_paths
