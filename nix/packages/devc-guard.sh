#!/usr/bin/env bash
# Guard shim installed as `devc`. The agent-fleet/agent-audit shell wrappers are
# the only supported entry points; upstream devc's up/./template/self-install/
# update subcommands are unsafe (they read a repo's own .devcontainer and can
# escape the Nix pin), so this refuses to run any of them.
set -euo pipefail

cat >&2 <<'EOF'
devc is managed by this dotfiles flake and has no runnable subcommands.

  Trusted org (shared login + signing):  agent-fleet <org>
  Untrusted repo (isolated, strict egress): agent-audit <repo-path-or-url>

Install or update the tooling with `make switch`. Do not use
`devc self-install`, `devc update`, `devc up`, or `devc template`: they bypass
the audited wrappers and this pin.
EOF
exit 64
