# Dotfiles bootstrap - run `just` to see all recipes
nix := "/nix/var/nix/profiles/default/bin/nix"

# Full bootstrap
default: bootstrap

# First nix-darwin activation after installing Nix/Lix
nix-bootstrap:
    {{nix}} flake lock
    sudo {{nix}} run github:nix-darwin/nix-darwin/master#darwin-rebuild -- switch --flake .#Mac

# Apply the flake after nix-darwin is installed
nix-switch:
    sudo darwin-rebuild switch --flake .#Mac

# Build the nix-darwin system without activating it
nix-build:
    {{nix}} build .#darwinConfigurations.Mac.system --no-link

# Build the standalone Home Manager activation package without activating it
nix-home-build:
    {{nix}} build .#homeConfigurations.joao-sousa-andrade.activationPackage --no-link

# Validate flake outputs
nix-check:
    {{nix}} flake check

# Update flake inputs
nix-update:
    {{nix}} flake update

# Apply only the standalone Home Manager output
nix-home:
    PATH="/nix/var/nix/profiles/default/bin:$PATH" {{nix}} run .#home-manager -- switch --flake .#joao-sousa-andrade

# Run complete bootstrap (or specify modules: just bootstrap stow languages)
bootstrap *MODULES:
    ./bootstrap {{MODULES}}

# Preview changes without executing
dry-run *MODULES:
    DRY_RUN=true ./bootstrap {{MODULES}}

# Install Homebrew packages from Brewfile
homebrew:
    ./bootstrap homebrew

# Install dotfiles via stow
stow:
    ./bootstrap stow

# Configure shell (Prezto, fzf, parallel)
shell:
    ./bootstrap shell

# Install language runtimes and packages
languages:
    ./bootstrap languages

# Configure services (Syncthing)
services:
    ./bootstrap services

# Download config files (kubectl aliases, whisper model)
downloads:
    ./bootstrap downloads

# Verify setup health (check binaries, stow links, versions)
[group('utils')]
doctor:
    ./bootstrap doctor

# Lint all shell scripts with shellcheck
[group('utils')]
lint:
    shellcheck -x lib/*.sh modules/*.sh bootstrap versions.env

# Remove Homebrew packages not in Brewfile (same as the cleanup step in modules/01-homebrew.sh)
[group('utils')]
clean:
    brew bundle cleanup --force --file=Brewfile
