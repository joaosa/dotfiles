# dotfiles

Automated development environment bootstrap with security best practices.

## Security Considerations

This script installs software and modifies your system. Before running:

1. **Review the code** - Read the [`modules/`](./modules/) and [`Brewfile`](./Brewfile) to understand what will be installed
2. **Verify integrity** - The script includes SHA256 checksums for downloaded files (see [`versions.env`](./versions.env))
3. **Preview changes** - Use dry-run mode to see what would be installed

## Installation

### Recommended: Review First

```bash
# Clone and review
git clone https://github.com/joaosa/dotfiles ~/ghq/github.com/joaosa/dotfiles
cd ~/ghq/github.com/joaosa/dotfiles

# Preview changes
just dry-run

# Run everything
just

# Or run specific modules
just homebrew
just stow
just languages
```

### Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/joaosa/dotfiles/master/bootstrap | bash
```

## Usage

```bash
just                    # Full bootstrap (all modules in order)
just dry-run            # Preview all changes without executing
just homebrew           # Install Homebrew packages from Brewfile
just stow              # Install dotfiles via GNU Stow
just shell             # Configure shell (Prezto, fzf, git, parallel)
just languages         # Install language runtimes and packages
just services          # Configure services (Syncthing)
just downloads         # Download config files (kubectl aliases, whisper model)
just clean             # Remove Homebrew packages not in Brewfile
```

Modules can also be combined: `./bootstrap homebrew languages`

Each module can run standalone: `bash modules/04-languages.sh`

## Structure

```
.
├── bootstrap              # Entry point (curl-friendly)
├── Justfile               # Task runner
├── Brewfile               # Homebrew packages & casks
├── .tool-versions         # asdf language versions
├── versions.env           # All other version pins
├── lib/
│   ├── logging.sh         # Color-coded logging with counters
│   ├── helpers.sh         # Shared functions (download, asdf, brew pin)
│   └── module.sh          # Module runner framework
├── modules/
│   ├── 01-homebrew.sh     # Homebrew install + bundle + pin + cleanup
│   ├── 02-stow.sh         # Auto-discover & stow dotfiles
│   ├── 03-shell.sh        # Prezto, fzf, git config, parallel
│   ├── 04-languages.sh    # Rust, Node, Go, npm/go/cargo packages
│   ├── 05-services.sh     # Syncthing
│   └── 06-downloads.sh    # Verified file downloads
├── stow/                  # GNU Stow packages (symlinked to ~)
│   ├── alacritty/
│   ├── git/
│   ├── hammerspoon/
│   ├── karabiner/
│   ├── nvim/
│   ├── opencode/
│   ├── tmux/
│   └── zsh/
├── infra/                 # Infrastructure (separate from bootstrap)
│   ├── secrets/           # OPNsense encrypted secrets
│   └── network-audit.md
└── extras/
    └── setup-ccnotify.sh  # Claude Code notifications
```

## Features

### Security

- SHA256 checksum verification for all downloads (including Homebrew installer)
- Version pinning for all packages (Go, npm, Cargo, asdf, Prezto)
- Homebrew packages pinned to prevent auto-updates
- DRY_RUN mode to preview changes

### Idempotency

- Safe to re-run at any time — only installs what's missing
- Stow `--restow` handles re-runs cleanly
- Check-before-install pattern throughout

### Modularity

- Each module runs independently or as part of the full bootstrap
- Stow packages auto-discovered — add a directory, run `just stow`
- Version pins consolidated in `versions.env`

## Version Management

- [`Brewfile`](./Brewfile) — Homebrew packages and casks
- [`.tool-versions`](./.tool-versions) — asdf-managed languages (Node.js, Go)
- [`versions.env`](./versions.env) — Everything else (npm, Go, Cargo packages, Prezto commit, download URLs)

## Optional

### OPNsense Secrets

```bash
just secrets                                      # Generate (requires YubiKey)
DRY_RUN=true bash infra/secrets/generate-secrets.sh  # Preview
```

### Claude Code Notifications

```bash
just ccnotify
```

See [CLAUDE.md](./CLAUDE.md) for details.

## Prerequisites

### SSH Key Setup

Git operations require SSH authentication:

```bash
ssh-keygen -t ed25519 -C "your_email@example.com"
# Add ~/.ssh/id_ed25519.pub to https://github.com/settings/keys
ssh -T git@github.com
```
