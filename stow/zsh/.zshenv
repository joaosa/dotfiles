#
# Defines environment variables.
#
# Authors:
#   Sorin Ionescu <sorin.ionescu@gmail.com>
#

typeset -gU path
path=(
  "/etc/profiles/per-user/$USER/bin"
  "$HOME/.nix-profile/bin"
  /nix/var/nix/profiles/default/bin
  $path
)

# Ensure that a non-login, non-interactive shell has a defined environment.
if [[ ( "$SHLVL" -eq 1 && ! -o LOGIN ) && -s "${ZDOTDIR:-$HOME}/.zprofile" ]]; then
  source "${ZDOTDIR:-$HOME}/.zprofile"
fi
. "$HOME/.cargo/env"

path=(
  "/etc/profiles/per-user/$USER/bin"
  "$HOME/.nix-profile/bin"
  /nix/var/nix/profiles/default/bin
  $path
)
