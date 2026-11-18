# Working in this repository

This repository manages macOS dotfiles through Nix, nix-darwin, and Home Manager.

- `nix/home/`: user settings, shell integration, and shared agent settings.
- `nix/darwin/` and `nix/hosts/`: system and host configuration.
- `nix/packages/`: local packages and the `agent` launcher.
- `config/`: application configuration and agent devcontainer templates.
- `flake.nix`: inputs, packages, development tools, and checks.

Read the relevant configuration and existing changes before editing. Preserve
unrelated user work. Keep changes focused; routine edits do not require a
separate planning approval or a multi-agent workflow.

## Verification

Use checks appropriate to the changed files and report any checks not run.

- Nix: formatting (`nix fmt -- --fail-on-change`), `statix check .`, and
  `deadnix --fail .`; the latter two are available through `nix develop`.
- `make check`: full flake checks and formatting, including system builds and
  the agent launcher tests. Run before proposing a system-wide change is ready
  to activate; it may need uncached dependencies and additional permissions.
- Shell changes: syntax checks and ShellCheck, plus the relevant flake tests.
- Documentation-only changes: inspect links, examples, and `git diff --check`.

`make build` builds without activating. `make switch` changes the running system;
do not run it as a verification command or unless activation is authorized.

## Agent configuration

Claude and Codex share guidance and skills from `~/.claude-shared`; Home Manager
links them into each client and devcontainers mount them read-only. Changes to
that tree affect both clients and require access outside this repository.

Shared Claude settings originate in `nix/home/common.nix` and are merged into
each profile on activation. Keep that source consistent with any authorized
live-settings edit. Synced skill bundles are externally managed; prefer client
skill exclusions to deleting bundle contents that a sync may restore.

Global outbound-data approval rules and the limit of fewer than 700 changed
lines per PR continue to apply. Evaluate commands for network effects before
running them; local verification does not authorize uploading private content.
