# Dotfiles bootstrap - run `just` to see all recipes

# Full bootstrap
default: bootstrap

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

# Configure shell (Prezto, fzf, git, parallel)
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

# Generate OPNsense secrets (requires YubiKey)
[group('infra')]
secrets:
    bash infra/secrets/generate-secrets.sh

# Install Claude Code desktop notifications
[group('extras')]
ccnotify:
    bash extras/setup-ccnotify.sh

# Verify setup health (check binaries, stow links, versions)
[group('utils')]
doctor:
    bash modules/doctor.sh

# Lint all shell scripts with shellcheck
[group('utils')]
lint:
    shellcheck -x lib/*.sh modules/*.sh bootstrap versions.env

# Remove Homebrew packages not in Brewfile
[group('utils')]
clean:
    brew bundle cleanup --force --file=Brewfile
