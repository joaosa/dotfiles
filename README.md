# dotfiles

Declarative macOS development environment using Nix, nix-darwin, Home Manager,
and nix-homebrew. Nix owns the primary package inventory, selected Homebrew
formulae/casks, Home Manager files, fonts, services, and fixed-output assets.

## Security Considerations

This repo installs software and modifies your system. Before running:

1. **Review the code** - Read [`flake.nix`](./flake.nix), [`nix/`](./nix/), and [`modules/`](./modules/) to understand what will be installed
2. **Verify integrity** - Nix uses fixed-output hashes for fetched files, including model data
3. **Preview changes** - Use `just nix-build`, `just nix-home-build`, or `just nix-check` before activation

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
  qwen3AsrModel = false;
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
4. `qwen3AsrModel` once you want Home Manager to own the local ASR model path
5. `homeShell`, `systemShell`, `fonts`, and `syncthingGuiTls` after the smaller pieces are stable

## Usage

```bash
just nix-bootstrap      # First nix-darwin activation after Nix/Lix install
just nix-switch         # Apply the nix-darwin + Home Manager flake
just nix-build          # Build the nix-darwin system without activating
just nix-home-build     # Build the standalone Home Manager output
just nix-check          # Validate flake outputs
just nix-update         # Update flake inputs
just nix-home           # Apply Home Manager using the pinned Nix CLI package
just doctor             # Verify expected tools and local assets
just lint               # Run shellcheck over bootstrap helper scripts
```

The bootstrap script remains curl-friendly and module-aware, but there are no
numbered install modules left at the moment. Operational checks live in
`modules/doctor.sh`.

### Tool Ownership Exceptions

`node` and `npm` are Nix-managed, while global npm packages install into
`~/.local` through the Home Manager-managed `.npmrc`. `claude` and `codex` are
intentionally installed with npm for now because their upstream CLIs move faster
than nixpkgs; keep them out of `homePackageKeys` until Nix catches up.

Project-local Rust CLIs are intentionally managed by their own dev symlink flow
rather than Cargo's install registry or this flake. Those symlinks live in
`~/.cargo/bin` and point at the relevant workspace `target` directory.

## Structure

```
.
├── flake.nix              # Nix flake entry point
├── nix/
│   ├── phase.nix          # Rollout gates for incremental Nix adoption
│   ├── packages.nix       # nixpkgs package inventory
│   ├── packages/          # Local package definitions missing from nixpkgs
│   ├── darwin/
│   │   ├── default.nix    # nix-darwin system configuration
│   │   └── homebrew.nix   # nix-homebrew + declarative casks/formulae
│   └── home/
│       ├── default.nix    # Home Manager user configuration
│       └── qwen3-asr.nix  # Fixed-output ASR model fetches
├── bootstrap              # Entry point and module runner
├── Justfile               # Task runner
├── .tool-versions         # asdf language versions still used by local projects
├── lib/
│   ├── logging.sh         # Color-coded logging with counters
│   ├── helpers.sh         # Shared bootstrap helpers
│   └── module.sh          # Module runner framework
├── modules/
│   └── doctor.sh          # Local setup health checks
└── stow/                  # Dotfile source tree linked by Home Manager
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

- Fixed-output hashes for downloaded assets and model data
- Flake-pinned Nix inputs once `flake.lock` is generated
- Homebrew auto-update and activation upgrades disabled under nix-darwin
- `nix/phase.nix` gates for incremental activation

### Idempotency

- Nix activations are declarative and safe to re-run
- Home Manager owns user-level symlinks and backs up replaced files with `.hm-backup`
- Doctor checks can be re-run without changing the system

### Modularity

- Nix configuration is split into package, system, Homebrew, and home modules
- Local package derivations live under `nix/packages/` when nixpkgs does not provide the exact tool/version needed
- Bootstrap libraries remain available for read-only checks and future small modules

## Version Management

- [`flake.nix`](./flake.nix) and [`nix/`](./nix/) - primary Nix, nix-darwin, Home Manager, and Homebrew configuration
- `flake.lock` - generated by `nix flake lock` or `just nix-update`
- [`.tool-versions`](./.tool-versions) - asdf language versions used by local projects

## Prerequisites

### SSH Key Setup

Git operations require SSH authentication:

```bash
ssh-keygen -t ed25519 -C "your_email@example.com"
# Add ~/.ssh/id_ed25519.pub to https://github.com/settings/keys
ssh -T git@github.com
```
