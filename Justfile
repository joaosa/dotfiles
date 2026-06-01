# Dotfiles tasks - run `just` to see all recipes
nix := "/nix/var/nix/profiles/default/bin/nix"

# List available recipes
default:
    @just --list

# Apply the nix-darwin + Home Manager flake
nix-switch:
    sudo -H {{nix}} --extra-experimental-features "nix-command flakes" run .#darwin-rebuild -- switch --flake .#Mac

# Build the system without activating it
nix-build:
    {{nix}} build .#darwinConfigurations.Mac.system --no-link
