#!/usr/bin/env python3
"""Flag Git state in fleet checkouts that host Git would execute."""

from __future__ import annotations

import hashlib
import json
import os
import re
import stat
import subprocess
import sys
from pathlib import Path

# Local config keys that cannot run code; anything else new is flagged, so
# unknown or future exec-capable keys fail closed.
BENIGN_KEY = re.compile(
    r"^(?:core\.(?:repositoryformatversion|filemode|bare|logallrefupdates"
    r"|ignorecase|precomposeunicode|symlinks)"
    r"|branch\..+|remote\..+\.(?:url|pushurl|fetch|tagopt|prune)"
    r"|submodule\..+\.(?:url|active)|user\..+|gc\..+"
    r"|extensions\.objectformat|lfs\.repositoryformatversion)$"
)
# Git reads only these scopes from the checkout; global/system are the host's.
LOCAL_SCOPES = {"local", "worktree"}
SKIP_DIRS = {"objects", "refs", "logs", "lfs"}
EMPTY = {"gitdir": "dir", "config": [], "hooks": {}}
GIT_ENV = {**os.environ, "GIT_CONFIG_NOSYSTEM": "1", "GIT_CONFIG_GLOBAL": os.devnull}


def kind(path: Path) -> str:
    try:
        mode = path.lstat().st_mode
    except FileNotFoundError:
        return "missing"
    if stat.S_ISLNK(mode):
        return "symlink"
    if stat.S_ISDIR(mode):
        return "dir"
    # FIFOs and devices would block a read; report them by type only.
    return "file" if stat.S_ISREG(mode) else "special"


def git(gitdir: Path, cwd: Path, *args: str) -> str:
    # Config reads and path lookups only: no hooks, index refresh, or fsmonitor.
    result = subprocess.run(
        ["git", f"--git-dir={gitdir}", *args],
        capture_output=True,
        cwd=cwd,
        env=GIT_ENV,
        check=False,
        timeout=10,
    )
    if result.returncode != 0:
        raise OSError(result.stderr.decode(errors="replace").strip() or "git failed")
    return result.stdout.decode(errors="replace")


def hook_files(directory: Path) -> dict[str, str]:
    directory_kind = kind(directory)
    if directory_kind != "dir":
        return {} if directory_kind == "missing" else {".": directory_kind}
    hooks = {}
    for entry in sorted(directory.iterdir()):
        if entry.name.endswith(".sample"):
            continue
        entry_kind = kind(entry)
        if entry_kind == "symlink":
            hooks[entry.name] = f"symlink:{entry.readlink()}"
        elif entry_kind == "file":
            with entry.open("rb") as handle:
                hooks[entry.name] = hashlib.file_digest(handle, "sha256").hexdigest()
        else:
            hooks[entry.name] = entry_kind
    return hooks


def snapshot_gitdir(gitdir: Path, worktree: Path) -> dict:
    """What host Git would load: effective config (commondir and includes
    resolved) and the effective hooks directory."""
    try:
        fields = git(
            gitdir, worktree, "config", "--list", "-z", "--show-scope", "--includes"
        )
        fields = fields.split("\0")
        config = sorted(
            f"{scope}: {entry.replace(chr(10), '=', 1)}"
            for scope, entry in zip(fields[::2], fields[1::2], strict=False)
            if scope in LOCAL_SCOPES and not BENIGN_KEY.match(entry.partition("\n")[0])
        )
        hooks_dir = (
            worktree / git(gitdir, worktree, "rev-parse", "--git-path", "hooks").strip()
        )
        hooks = hook_files(hooks_dir)
    except (OSError, subprocess.TimeoutExpired) as error:
        config, hooks = [f"unreadable: {error}"], {}
    return {"gitdir": kind(gitdir), "config": config, "hooks": hooks}


def snapshot(org: Path) -> dict[str, dict]:
    repos: dict[str, dict] = {}
    for repo in sorted(org.iterdir()):
        dot_git = repo / ".git"
        if kind(repo) != "dir" or kind(dot_git) == "missing":
            continue
        repos[repo.name] = snapshot_gitdir(dot_git, repo)
        if kind(dot_git) != "dir":
            continue
        # Submodule and linked-worktree gitdirs carry their own config and hooks.
        for top in ("modules", "worktrees"):
            for root, dirs, files in os.walk(dot_git / top):
                dirs[:] = sorted(d for d in dirs if d not in SKIP_DIRS)
                if "HEAD" in files:
                    gitdir = Path(root)
                    repos[f"{repo.name}/{gitdir.relative_to(repo)}"] = snapshot_gitdir(
                        gitdir, repo
                    )
    return repos


def findings(before: dict[str, dict], after: dict[str, dict]) -> list[str]:
    found = []
    for name, now in after.items():
        was = before.get(name, EMPTY)
        if now["gitdir"] != was["gitdir"]:
            found.append(
                f"{name}: .git is now a {now['gitdir']}, not a {was['gitdir']}"
            )
        found.extend(
            f"{name}: {entry}"
            for entry in sorted(set(now["config"]) - set(was["config"]))
        )
        for hook, digest in sorted(now["hooks"].items()):
            if was["hooks"].get(hook) != digest:
                change = "changed" if hook in was["hooks"] else "added"
                found.append(f"{name}: hook {hook} {change}")
    return found


def main() -> int:
    if len(sys.argv) != 4 or sys.argv[1] not in {"check", "accept"}:
        print(
            "usage: devc-git-guard check|accept <org-dir> <state-file>", file=sys.stderr
        )
        return 2
    action, org, state = sys.argv[1], Path(sys.argv[2]), Path(sys.argv[3])
    try:
        if kind(org) != "dir":
            raise ValueError(f"not a directory: {org}")
        if kind(state) not in {"missing", "file"}:
            raise ValueError(f"refusing non-regular state file: {state}")
        current = snapshot(org)
        if action == "accept" or kind(state) == "missing":
            state.parent.mkdir(parents=True, exist_ok=True)
            tmp = state.with_suffix(".tmp")
            tmp.write_text(
                json.dumps(current, indent=1, sort_keys=True) + "\n", encoding="utf-8"
            )
            tmp.replace(state)
            print(f"devc-git-guard: baseline recorded for {org}", file=sys.stderr)
            return 0
        found = findings(json.loads(state.read_text(encoding="utf-8")), current)
    except (ValueError, OSError) as error:
        print(f"devc-git-guard: {error}", file=sys.stderr)
        return 2
    if not found:
        return 0
    print(
        "\n!!! devc-git-guard: executable Git state changed in shared checkouts !!!\n"
        "Host Git runs these as you. Do not run git (or git-aware tools) in the\n"
        "affected repositories until you have inspected them:",
        file=sys.stderr,
    )
    for line in found:
        print(f"  - {line}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
