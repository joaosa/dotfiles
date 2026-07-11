#!/usr/bin/env python3
"""Configure shared tooling for the Claude Code and Codex devcontainer."""

import contextlib
import json
import os
import subprocess
import sys
import tomllib
from pathlib import Path


def fix_directory_ownership() -> None:
    """Make newly created named volumes writable by the remote user."""
    uid = os.getuid()
    gid = os.getgid()
    directories = [
        Path.home() / ".claude",
        Path.home() / ".codex",
        Path.home() / ".config" / "gh",
        Path("/commandhistory"),
    ]

    for directory in directories:
        if not directory.exists():
            continue
        try:
            if directory.stat().st_uid != uid:
                subprocess.run(
                    ["sudo", "chown", "-R", f"{uid}:{gid}", str(directory)],
                    check=True,
                    capture_output=True,
                )
                print(f"[post_install] Fixed ownership: {directory}", file=sys.stderr)
        except (PermissionError, subprocess.CalledProcessError) as error:
            print(
                f"[post_install] Warning: could not fix ownership of {directory}: "
                f"{error}",
                file=sys.stderr,
            )


def setup_onboarding_bypass() -> None:
    """Seed Claude onboarding only for the trusted profile's forwarded token."""
    token = os.environ.get("CLAUDE_CODE_OAUTH_TOKEN", "").strip()
    if not token:
        print(
            "[post_install] No forwarded Claude token; use interactive login",
            file=sys.stderr,
        )
        return

    claude_json_dir = Path(os.environ.get("CLAUDE_CONFIG_DIR", Path.home()))
    claude_json = claude_json_dir / ".claude.json"

    print("[post_install] Seeding Claude authentication state...", file=sys.stderr)
    try:
        result = subprocess.run(
            ["claude", "-p", "ok"],
            capture_output=True,
            text=True,
            timeout=30,
        )
        if result.returncode != 0:
            print(
                f"[post_install] claude -p exited {result.returncode}: "
                f"{result.stderr.strip()}",
                file=sys.stderr,
            )
    except subprocess.TimeoutExpired:
        print("[post_install] claude -p timed out on cold start", file=sys.stderr)
    except (FileNotFoundError, OSError) as error:
        print(f"[post_install] Could not run claude: {error}", file=sys.stderr)
        return

    if not claude_json.exists():
        print(f"[post_install] {claude_json} was not created", file=sys.stderr)
        return

    try:
        config = json.loads(claude_json.read_text())
    except json.JSONDecodeError as error:
        print(
            f"[post_install] Warning: {claude_json} has invalid JSON ({error}); "
            "not overwriting recoverable state",
            file=sys.stderr,
        )
        return

    if not isinstance(config, dict):
        print(
            f"[post_install] Warning: {claude_json} is not a JSON object; "
            "leaving it unchanged",
            file=sys.stderr,
        )
        return

    config["hasCompletedOnboarding"] = True
    claude_json.write_text(json.dumps(config, indent=2) + "\n", encoding="utf-8")


def setup_claude_settings() -> None:
    """Enable bypass mode only for the explicitly trusted fleet profile."""
    claude_dir = Path(os.environ.get("CLAUDE_CONFIG_DIR", Path.home() / ".claude"))
    claude_dir.mkdir(parents=True, exist_ok=True)
    settings_file = claude_dir / "settings.json"
    settings: dict = {}

    if settings_file.exists():
        with contextlib.suppress(json.JSONDecodeError):
            loaded = json.loads(settings_file.read_text())
            if isinstance(loaded, dict):
                settings = loaded

    permissions = settings.setdefault("permissions", {})
    if os.environ.get("CLAUDE_BYPASS_PERMISSIONS") == "1":
        permissions["defaultMode"] = "bypassPermissions"
        mode = "bypassPermissions"
    else:
        if permissions.get("defaultMode") == "bypassPermissions":
            permissions.pop("defaultMode")
        if not permissions:
            settings.pop("permissions", None)
        mode = "interactive permissions"

    settings_file.write_text(json.dumps(settings, indent=2) + "\n", encoding="utf-8")
    print(f"[post_install] Claude mode: {mode}", file=sys.stderr)


def setup_codex_settings() -> None:
    """Use the container boundary instead of Codex's nested Linux sandbox."""
    if os.environ.get("AGENT_CODEX_EXTERNAL_SANDBOX") != "1":
        return

    config_file = Path.home() / ".codex" / "config.toml"
    config_file.parent.mkdir(parents=True, exist_ok=True)
    config = config_file.read_text(encoding="utf-8") if config_file.exists() else ""
    setting = 'sandbox_mode = "danger-full-access"\n'

    # Parse with tomllib to locate an existing top-level sandbox_mode reliably;
    # a hand-rolled line scan mistakes a multi-line array's `[` continuation for
    # a table header and inserts a duplicate key, which is invalid TOML.
    try:
        parsed = tomllib.loads(config)
    except tomllib.TOMLDecodeError as error:
        print(
            f"[post_install] Warning: {config_file} is invalid TOML ({error}); "
            "leaving Codex sandbox unchanged",
            file=sys.stderr,
        )
        return

    if "sandbox_mode" in parsed:
        # tomllib confirms a top-level sandbox_mode, so its assignment is the one
        # line whose key parses to "sandbox_mode" (a key inside a table would
        # parse under that table, not at top level). Rewrite that exact line;
        # scanning by parsed key avoids mistaking an array's `[` continuation
        # for a table header.
        lines = config.splitlines(keepends=True)
        for index, line in enumerate(lines):
            key = line.split("#", 1)[0].partition("=")[0].strip()
            if key == "sandbox_mode":
                lines[index] = setting
                break
        config_file.write_text("".join(lines), encoding="utf-8")
    else:
        config_file.write_text(setting + config, encoding="utf-8")

    print("[post_install] Codex sandbox: external container", file=sys.stderr)


def setup_tmux_config() -> None:
    tmux_conf = Path.home() / ".tmux.conf"
    if tmux_conf.exists():
        return

    tmux_conf.write_text(
        """\
set-option -g history-limit 200000
set -g mouse on
setw -g mode-keys vi
set -g base-index 1
setw -g pane-base-index 1
set -g renumber-windows on
set -sg escape-time 10
set -g default-terminal "tmux-256color"
set -ag terminal-overrides ",xterm-256color:RGB"
set -as terminal-features ",xterm-ghostty:RGB"
set -as terminal-features ",xterm*:RGB"
set -ga terminal-overrides ",xterm*:colors=256"
set -ga terminal-overrides '*:Ss=\\E[%p1%d q:Se=\\E[ q'
set -g status-style 'bg=#333333 fg=#ffffff'
set -g status-left '[#S] '
set -g status-right '%Y-%m-%d %H:%M'
""",
        encoding="utf-8",
    )


def setup_git_config() -> None:
    home = Path.home()
    gitignore = home / ".gitignore_global"
    local_gitconfig = home / ".gitconfig.local"
    host_gitconfig = home / ".gitconfig"

    if not host_gitconfig.exists():
        host_gitconfig.touch()
    gitignore.write_text(
        """\
# Agent state
.claude/
.codex/

# macOS
.DS_Store
.AppleDouble
.LSOverride
._*

# Python
*.pyc
*.pyo
__pycache__/
*.egg-info/
.eggs/
*.egg
.venv/
venv/
.mypy_cache/
.ruff_cache/

# Node
node_modules/
.npm/

# Editors
*.swp
*.swo
*~
.idea/
.vscode/
*.sublime-*

# Misc
*.log
.env.local
.env.*.local
""",
        encoding="utf-8",
    )

    local_config = f"""\
[include]
    path = {host_gitconfig}

[core]
    excludesfile = {gitignore}
    pager = delta

[interactive]
    diffFilter = delta --color-only

[delta]
    navigate = true
    light = false
    line-numbers = true
    side-by-side = false

[merge]
    conflictstyle = diff3

[diff]
    colorMoved = default

[gpg "ssh"]
    program = /usr/bin/ssh-keygen
"""

    if os.environ.get("AGENT_DISABLE_GIT_SIGNING") == "1":
        # The mounted host gitconfig enables commit AND tag signing and points
        # user.signingkey at a key absent from this container; disable both so
        # git operations don't fail, and drop the host identity so untrusted
        # code cannot author commits as the real user.
        local_config += """\

[commit]
    gpgsign = false

[tag]
    gpgsign = false

[user]
    name = agent-audit
    email = agent-audit@localhost
    signingkey =
"""

    local_gitconfig.write_text(local_config, encoding="utf-8")


def main() -> None:
    print("[post_install] Starting agent container setup...", file=sys.stderr)
    fix_directory_ownership()
    setup_onboarding_bypass()
    setup_claude_settings()
    setup_codex_settings()
    setup_tmux_config()
    setup_git_config()
    print("[post_install] Configuration complete", file=sys.stderr)


if __name__ == "__main__":
    main()
