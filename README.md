# dotfiles

[![ci](https://github.com/joaosa/dotfiles/actions/workflows/ci.yml/badge.svg)](https://github.com/joaosa/dotfiles/actions/workflows/ci.yml)

Declarative macOS development environment using Nix, nix-darwin, Home Manager,
and nix-homebrew. Nix owns the primary package inventory, selected Homebrew
formulae/casks, Home Manager files, fonts, services, and fixed-output assets.

## Security Considerations

This repo installs software and modifies your system. Before running:

1. **Review the code** - Read [`flake.nix`](./flake.nix) and [`nix/`](./nix/) to understand what will be installed
2. **Verify integrity** - Nix uses fixed-output hashes for fetched files, including model data
3. **Preview changes** - Use `make build` before activation

## Installation

### Recommended: Nix

```bash
# Clone and review
git clone https://github.com/joaosa/dotfiles ~/ghq/github.com/joaosa/dotfiles
cd ~/ghq/github.com/joaosa/dotfiles

# Install Nix or Lix first, then review the config and build
$EDITOR nix/packages.nix
make build

# First activation (before darwin-rebuild exists on the system)
nix flake lock
sudo -H nix --extra-experimental-features "nix-command flakes" \
  run .#darwin-rebuild -- switch --flake .#Mac

# Later changes use the pinned darwin-rebuild from this flake
make switch
```

This flake is currently configured for:

- host: `Mac`
- user: `joao-sousa-andrade`
- platform: `aarch64-darwin`

The Nix setup manages CLI/dev tools through nixpkgs, user files through Home
Manager, and GUI apps plus macOS-specific formulae through nix-darwin's
Homebrew module.

### Configuration

Add or remove a package by editing the list in
[`nix/packages.nix`](./nix/packages.nix), then `make build` and
`make switch`. Packages are direct references (`pkgs.ripgrep`), so one
dropped or renamed in nixpkgs is a `nix flake check` error rather than a tool
that silently disappears.

Each machine is one `hosts` entry in [`flake.nix`](./flake.nix); host-specific
overrides go in `nix/hosts/<name>.nix`. User files, services, fonts, and
Homebrew casks are configured in [`nix/home`](./nix/home) and
[`nix/darwin`](./nix/darwin).

## Usage

```bash
make switch         # Apply the nix-darwin + Home Manager flake
make build          # Build the system without activating
make check          # nix flake check + formatting check
make hooks          # install the prek git hooks (run once per clone)
make                # list recipes
```

Recipes target the `Mac` host entry by default; pass `HOST=<name>` to build
another `hosts` entry.

For development, `nix develop` drops you into a shell with `nixfmt`, `statix`,
`deadnix`, and `prek`. `make hooks` wires the hooks in
[`.pre-commit-config.yaml`](./.pre-commit-config.yaml). CI
([`.github/workflows/ci.yml`](./.github/workflows/ci.yml)) runs the formatting
check and `nix flake check` — which builds every host system and runs the
`statix`/`deadnix` lint checks — on every push and PR. A scheduled workflow
([`.github/workflows/update-flake-lock.yml`](./.github/workflows/update-flake-lock.yml))
opens a weekly PR bumping `flake.lock`.

Run the underlying `nix` commands directly for the rarer operations:
`nix flake check` (validate outputs) and `nix flake update` (update inputs).

### Tool Ownership Exceptions

`node` and `npm` are Nix-managed, while global npm packages install into
`~/.local` through the Home Manager-managed `.npmrc`. `claude` and `codex` are
intentionally installed with npm for now because their upstream CLIs move faster
than nixpkgs; add `pkgs.claude-code` / `pkgs.codex` to `nix/packages.nix` to
install them via Nix instead.

Project-local Rust CLIs are intentionally managed by their own dev symlink flow
rather than Cargo's install registry or this flake. Those symlinks live in
`~/.cargo/bin` and point at the relevant workspace `target` directory.

### Claude Code sandbox

Trail of Bits'
[claude-code-devcontainer](https://github.com/trailofbits/claude-code-devcontainer)
runs Claude Code in a Docker container so `bypassPermissions` can't touch the
host. The `devc` CLI is pinned and repackaged in
[`nix/packages/devc.nix`](./nix/packages/devc.nix) (bump `rev`/`hash` there and
`make switch` to update — no `devc self-install`/`update`). Two zsh wrappers
drive it:

```bash
claude-fleet <org>                 # shared container over ~/ghq/github.com/<org>;
                                   # all repos at /workspace/<repo>, one Claude/gh login
claude-audit <repo-path-or-url>    # isolated container + volumes for untrusted code
```

`claude-fleet` stamps the org dir with
[`config/claude-devcontainer/fleet.devcontainer.json`](./config/claude-devcontainer/fleet.devcontainer.json)
(the base template minus its per-repo `.git` mounts, which don't exist at the
org root; the read-only `.devcontainer` overlay is kept). Signing material is
mounted from resolved paths, not `~` symlinks — colima only shares `$HOME`, so
a mount whose source resolves into `/nix/store` would dangle in the VM. Colima
itself is configured by the repo-managed
[`config/colima/colima.yaml`](./config/colima/colima.yaml) — agent forwarding
on for in-container commit signing, with `COLIMA_SAVE_CONFIG=false` (exported
from `.zshenv`) keeping colima from rewriting the linked file.

First run needs a Claude token. It lives in the login keychain (encrypted at
rest, never in a dotfile or the ambient environment); the `devc` wrapper reads
it from the keychain on every invocation and forwards it into the container via
`localEnv`, so login works from `claude-fleet`, `devc up`, or `devc shell`
alike:

```bash
claude setup-token   # once — interactive; copy the sk-ant-oat01-… token it shows
security add-generic-password -a "$USER" -s claude-code-oauth -w
                     # paste the copied token at the (hidden) password prompt
```

Re-store a rotated/mispasted token by deleting first
(`security delete-generic-password -a "$USER" -s claude-code-oauth`) then adding
again; `claude-fleet` warns if the stored value is missing or too short.

## Structure

```
.
├── flake.nix              # Nix flake entry point (hosts attrset + mkHost)
├── nix/
│   ├── packages.nix       # nixpkgs package inventory (the installed list)
│   ├── packages/          # Local package definitions missing from nixpkgs
│   ├── hosts/
│   │   └── Mac.nix        # Per-host overrides (one file per machine)
│   ├── darwin/
│   │   ├── default.nix    # nix-darwin system configuration
│   │   ├── homebrew.nix   # nix-homebrew with pinned taps + declarative casks
│   │   └── tailscale.nix  # Tailscale launchd daemon
│   └── home/
│       ├── default.nix    # Home Manager composer (platform-aware homeDir)
│       ├── common.nix     # Cross-platform files, shell, packages, services
│       ├── darwin.nix     # macOS-only files and packages (guarded)
│       ├── linux.nix      # Linux-only home config (stub)
│       └── qwen3-asr.nix  # Fixed-output ASR model fetches
├── Makefile               # Task runner
└── config/                # Dotfile source tree linked by Home Manager
    ├── alacritty/alacritty.toml
    ├── git/                  # gitconfig, gitignore_global
    ├── hammerspoon/          # init.lua, config/, lib/, modules/
    ├── karabiner/karabiner.json
    ├── nvim/                 # init.lua, lua/
    ├── ruff/ruff.toml
    ├── starship/starship.toml
    ├── stylua/stylua.toml
    ├── tmux/                 # tmux.conf, lightline.conf
    └── yamllint/yamllint
```

(zsh runcoms are generated by `programs.zsh`, not linked from here.)

## Features

### Security

- Fixed-output hashes for downloaded assets and model data
- Flake-pinned Nix inputs via `flake.lock`
- Homebrew taps pinned as flake inputs (`brew tap` and API installs disabled)
- Homebrew auto-update and activation upgrades disabled under nix-darwin

### Idempotency

- Nix activations are declarative and safe to re-run
- Home Manager owns user-level symlinks and backs up replaced files with `.hm-backup`

### Modularity

- Per-host (`mkHost` + `nix/hosts/`) and per-platform (`home/{common,darwin,linux}`) splits keep a second host cheap to add
- Local package derivations live under `nix/packages/` when nixpkgs does not provide the exact tool/version needed

## Version Management

- [`flake.nix`](./flake.nix) and [`nix/`](./nix/) - primary Nix, nix-darwin, Home Manager, and Homebrew configuration
- `flake.lock` - generated by `nix flake lock`; update inputs with `nix flake update`

## Prerequisites

### SSH Key Setup

Git operations require SSH authentication:

```bash
ssh-keygen -t ed25519 -C "your_email@example.com"
# Add ~/.ssh/id_ed25519.pub to https://github.com/settings/keys
ssh -T git@github.com
```
