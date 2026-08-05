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

### Claude Code and Codex devcontainers

The pinned Trail of Bits `devc` CLI is paired with repo-owned templates under
[`config/agent-devcontainer`](./config/agent-devcontainer). The image contains
both Claude Code and Codex; `agent-*` is the canonical wrapper and the
`claude-*` / `codex-*` names are compatibility aliases:

```bash
agent-fleet <org>                  # trusted org: shared AI/gh login + signing agent, allowlisted egress
agent-audit <repo-path-or-url>     # untrusted repo: isolated logins, strict egress

claude-fleet <org>                 # aliases of agent-fleet
codex-fleet <org>
claude-audit <repo-path-or-url>    # aliases of agent-audit
codex-audit <repo-path-or-url>
```

Wrappers stage the trusted Dockerfile and profile in
`~/.cache/agent-devcontainer`, outside the checkout, then pass the config path
explicitly to the Dev Container CLI. They never create or overwrite a
repository's `.devcontainer`, and URL audit destinations are parsed into safe
`host/group/repo` components under `~/sandbox/audit` with symlinks rejected.

The fleet profile is only for trusted organizations. It shares Claude, Codex,
and GitHub login volumes across that organization and forwards the host SSH
agent for commit signing. The Claude OAuth token and the Codex API key are read
from the login keychain only by this trusted wrapper:

```bash
# Claude: the CLI mints a subscription OAuth token
claude setup-token
security add-generic-password -a "$USER" -s claude-code-oauth -w

# Codex: mint an API key at platform.openai.com (no CLI equivalent exists)
security add-generic-password -a "$USER" -s codex-api-key -w
```

The wrapper exports these as `CLAUDE_CODE_OAUTH_TOKEN` and `CODEX_API_KEY`.
Claude reads its variable directly; Codex's interactive TUI does not, so the
post-start hook exchanges a forwarded `CODEX_API_KEY` for persistent
credentials via `codex login --with-api-key`. In both cases the keychain secret
takes precedence over an earlier interactive login inside the container.

Both secrets are optional; without one, the wrapper unsets its variable and
warns, and that agent falls back to interactive login backed by its persistent
volume.

Fleet also refreshes both agents on start, at most once a day, because the image
pins them at build time and a self-update cannot outlive the container. The
audit and sandbox profiles keep the pinned build.

Fleet applies an outbound domain allowlist, and additionally admits GitHub's
published web/api/git IP ranges so SSH pushes through the forwarded agent do
not depend on a DNS snapshot of `github.com`. Both profiles' lists are defined
once in [`nix/packages/devc.nix`](./nix/packages/devc.nix) — audit extends
fleet's base with the ecosystems fleet has no use for — and are substituted
into the staged configs by `make switch`. The agent refresh runs before the
firewall lands, so it can still fetch outside the allowlist; everything after
container start is confined. The trade-off is that in-fleet web browsing
(Claude's WebFetch/WebSearch) only reaches allowlisted hosts — extend the
allowlist when a task legitimately needs more. The firewall limits credential
exfiltration to attacker infrastructure; it cannot stop misuse of a forwarded
token against an allowlisted service such as `api.github.com`.

The audit profile does not forward `CLAUDE_CODE_OAUTH_TOKEN`,
`ANTHROPIC_API_KEY`, `CODEX_API_KEY`, `OPENAI_API_KEY`, or the SSH agent. It
uses distinct per-repository Claude, Codex, and `gh` volumes, leaves Claude
permission prompts enabled, mounts Git config/hooks read-only, disables
inherited commit signing,
and applies an outbound domain allowlist. Authenticate inside it as
needed; for Codex on a headless container, use:

```bash
codex login --device-auth
```

No profile grants capabilities beyond `NET_ADMIN`/`NET_RAW` for the firewall,
and none relaxes Docker's default seccomp or AppArmor confinement: the
container boundary is the sandbox. Codex therefore uses the devcontainer as its
external sandbox in every profile — its nested Bubblewrap sandbox, which would
need `SYS_ADMIN`, `SYS_PTRACE`, and an unconfined seccomp profile, stays
disabled — and audit retains its approval prompts.

The firewall is defense in depth, not a substitute for the container boundary
or reviewing requested approvals. Extend the domain lists in
[`nix/packages/devc.nix`](./nix/packages/devc.nix) when a project legitimately
needs another package registry; `make switch` restages the configs and the
next launch rebuilds one trailing image layer. The list reaches the image as a
build arg rather than an environment variable so the root applier reads it
from a root-owned file the agent cannot rewrite.

The package that stages these templates lives in
[`nix/packages/devc.nix`](./nix/packages/devc.nix). Update the pinned
`CODEX_VERSION` in the three devcontainer JSON profiles and Dockerfile together.
Use `make switch` to install updates. The `agent-fleet` and `agent-audit`
wrappers are the only entry points; a bare `devc` is a guard that refuses to run
so upstream's unsafe `up` / `template` / `self-install` / `update` subcommands
cannot be invoked.

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
    ├── agent-devcontainer/  # Claude/Codex image, profiles, firewall
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
