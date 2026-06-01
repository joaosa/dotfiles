# Dotfiles tasks - run `just` to see all recipes
nix := "/nix/var/nix/profiles/default/bin/nix"

# Default health check
default: doctor

# Apply the nix-darwin + Home Manager flake
nix-switch:
    sudo -H {{nix}} --extra-experimental-features "nix-command flakes" run .#darwin-rebuild -- switch --flake .#Mac

# Build the system without activating it
nix-build:
    {{nix}} build .#darwinConfigurations.Mac.system --no-link

# Verify setup health
[group('utils')]
doctor:
    ./bootstrap doctor

# Lint all shell scripts with shellcheck
[group('utils')]
lint:
    shellcheck -x lib/*.sh modules/*.sh bootstrap
