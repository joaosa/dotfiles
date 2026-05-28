# dotfiles

Declarative macOS development environment using Nix, nix-darwin, Home Manager,
and nix-homebrew. The previous shell bootstrap remains available as a fallback
while the migration settles.

## Security Considerations

This repo installs software and modifies your system. Before running:

1. **Review the code** - Read [`flake.nix`](./flake.nix), [`nix/`](./nix/), and [`modules/`](./modules/) to understand what will be installed
2. **Verify integrity** - Nix uses fixed-output hashes for fetched files, and the legacy scripts include SHA256 checksums in [`versions.env`](./versions.env)
3. **Preview changes** - Use `just nix-build` for Nix or `just dry-run` for the legacy bootstrap

## Installation

### Recommended: Nix

```bash
# Clone and review
git clone https://github.com/joaosa/dotfiles ~/ghq/github.com/joaosa/dotfiles
cd ~/ghq/github.com/joaosa/dotfiles

# Install Nix or Lix first, then review the phase gates and build
$EDITOR nix/phase.nix
just nix-build
just nix-home-build

# Activate only after the current phase is understood
just nix-bootstrap

# Later changes use the pinned darwin-rebuild from this flake
just nix-switch
```

This flake is currently configured for:

- host: `Mac`
- user: `joao-sousa-andrade`
- platform: `aarch64-darwin`

The Nix setup manages CLI/dev tools through nixpkgs, user files through Home
Manager, and GUI apps plus macOS-specific formulae through nix-darwin's
Homebrew module.

### Phased Rollout

[`nix/phase.nix`](./nix/phase.nix) is the rollout switchboard for remaining
migration work. Keep enabling one owner at a time, build, then activate.

Enable one small thing at a time, build, then activate:

```nix
{
  homePackageKeys = [ "ripgrep" ];
  homeFileTargets = [ ];
  systemPackageKeys = [ ];
  homeShell = false;
  syncthingGuiTls = false;
  systemShell = false;
  fonts = false;
  homebrewBrews = [ ];
  homebrewCasks = [ ];
}
```

Suggested order:

1. `homePackageKeys` for low-risk CLI tools, one or a few at a time
2. `homeFileTargets` for individual dotfiles once you are ready for Home Manager to own them
3. `homebrewBrews` and `homebrewCasks` once you want nix-darwin to manage selected Homebrew entries
4. `homeShell`, `systemShell`, `fonts`, and `syncthingGuiTls` after the smaller pieces are stable

### Legacy Bootstrap

The old bootstrap flow is still present for fallback and for pieces that have
not been fully converted yet:

```bash
# Preview legacy shell changes
just dry-run

# Or run specific modules
just stow
just languages
```

### Legacy Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/joaosa/dotfiles/master/bootstrap | bash
```

## Usage

```bash
just nix-bootstrap      # First nix-darwin activation after Nix/Lix install
just nix-switch         # Apply the nix-darwin + Home Manager flake
just nix-build          # Build the flake without activating
just nix-home-build     # Build the standalone Home Manager output
just nix-check          # Validate flake outputs
just nix-update         # Update flake inputs
just nix-home           # Apply Home Manager using the pinned Nix CLI package

just                    # Legacy full bootstrap (all modules in order)
just dry-run            # Preview legacy changes without executing
just stow               # Legacy dotfiles via GNU Stow
just shell              # Legacy shell setup
just languages          # Legacy language runtimes and global packages
just downloads          # Legacy ASR model download
```

Modules can also be combined: `./bootstrap stow languages`

Each module can run standalone: `bash modules/04-languages.sh`

## Structure

```
.
├── flake.nix              # Nix flake entry point
├── nix/
│   ├── phase.nix          # Rollout gates for incremental Nix adoption
│   ├── packages.nix       # nixpkgs package inventory
│   ├── darwin/
│   │   ├── default.nix    # nix-darwin system configuration
│   │   └── homebrew.nix   # nix-homebrew + declarative casks/formulae
│   └── home/
│       └── default.nix    # Home Manager user configuration
├── bootstrap              # Entry point (curl-friendly)
├── Justfile               # Task runner
├── .tool-versions         # asdf language versions
├── versions.env           # All other version pins
├── lib/
│   ├── logging.sh         # Color-coded logging with counters
│   ├── helpers.sh         # Shared functions (download, asdf, packages)
│   └── module.sh          # Module runner framework
├── modules/
│   ├── 02-stow.sh         # Auto-discover & stow dotfiles
│   ├── 03-shell.sh        # Prezto and fzf
│   ├── 04-languages.sh    # Rust, Node, Go, npm/go/cargo packages
│   └── 06-downloads.sh    # Legacy ASR model download
└── stow/                  # GNU Stow packages (symlinked to ~)
    ├── alacritty/
    ├── git/
    ├── hammerspoon/
    ├── karabiner/
    ├── nvim/
    ├── opencode/
    ├── ruff/
    ├── starship/
    ├── stylua/
    ├── tmux/
    └── zsh/
```

## Features

### Security

- SHA256 checksum verification for downloaded assets
- Flake-pinned Nix inputs once `flake.lock` is generated
- Legacy version pins for Go, npm, Cargo, asdf, Prezto, and ASR model download
- Homebrew auto-update and activation upgrades disabled under nix-darwin
- Legacy DRY_RUN mode to preview shell bootstrap changes

### Idempotency

- Nix activations are declarative and safe to re-run
- Home Manager owns user-level symlinks and backs up replaced files with `.hm-backup`
- Legacy modules keep their check-before-install pattern

### Modularity

- Nix configuration is split into package, system, Homebrew, and home modules
- Legacy shell modules still run independently or as part of the old bootstrap

## Version Management

- [`flake.nix`](./flake.nix) and [`nix/`](./nix/) — primary Nix, nix-darwin, Home Manager, and Homebrew configuration
- `flake.lock` — generated by `nix flake lock` or `just nix-update`
- [`.tool-versions`](./.tool-versions) — legacy asdf language versions
- [`versions.env`](./versions.env) — legacy npm, Go, Cargo, Prezto, and ASR model pin

## Prerequisites

### SSH Key Setup

Git operations require SSH authentication:

```bash
ssh-keygen -t ed25519 -C "your_email@example.com"
# Add ~/.ssh/id_ed25519.pub to https://github.com/settings/keys
ssh -T git@github.com
```
