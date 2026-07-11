#!/usr/bin/env python3
"""Turn a supported Git URL into a traversal-safe host/path slug."""

from __future__ import annotations

import re
import stat
import subprocess
import sys
from pathlib import Path
from urllib.parse import unquote, urlsplit


COMPONENT = re.compile(r"^[A-Za-z0-9._-]+$")
SCHEMES = {"git", "http", "https", "ssh"}


def fail(message: str) -> "NoReturn":
    raise ValueError(message)


def split_url(value: str) -> tuple[str, str]:
    if "://" in value:
        parsed = urlsplit(value)
        if parsed.scheme not in SCHEMES:
            fail(f"unsupported URL scheme: {parsed.scheme or '<missing>'}")
        if not parsed.hostname:
            fail("URL has no host")
        if parsed.query or parsed.fragment:
            fail("URL queries and fragments are not supported")
        try:
            if parsed.port is not None:
                fail("URLs with explicit ports are not supported")
        except ValueError as error:
            fail(f"invalid URL port: {error}")
        return parsed.hostname, unquote(parsed.path).lstrip("/")

    match = re.fullmatch(r"[^@/:]+@([^/:]+):(.+)", value)
    if not match:
        fail("expected an http(s), git, ssh, or user@host:path Git URL")
    return match.group(1), unquote(match.group(2))


def audit_slug(value: str) -> str:
    host, path = split_url(value.strip())
    # Strip the trailing slash first: a URL like `.../repo.git/` would otherwise
    # keep its `.git` suffix and slug to a different directory than `.../repo`.
    path = path.rstrip("/").removesuffix(".git")
    components = [host, *path.split("/")]

    if len(components) < 3:
        fail("expected at least host/owner/repository")

    for component in components:
        if component in {"", ".", ".."}:
            fail("empty, '.' and '..' path components are forbidden")
        if not COMPONENT.fullmatch(component):
            fail(f"unsupported character in URL component: {component!r}")

    return "/".join(components)


def ensure_owned_directory(path: Path) -> None:
    """Create one directory without accepting symlinks or foreign owners."""
    try:
        metadata = path.lstat()
    except FileNotFoundError:
        path.mkdir()
        metadata = path.lstat()

    if not stat.S_ISDIR(metadata.st_mode) or path.is_symlink():
        fail(f"refusing non-directory or symlink path: {path}")
    if metadata.st_uid != Path.home().stat().st_uid:
        fail(f"refusing directory owned by another user: {path}")


def prepare_target(root: Path, value: str) -> Path:
    """Create safe parents, clone when absent, and return the checkout path."""
    slug = audit_slug(value)
    root = root.expanduser()

    # The configured audit root is below HOME. Build each component separately
    # so mkdir never follows a pre-created symlink.
    home = Path.home().resolve()
    try:
        relative_root = root.relative_to(home)
    except ValueError:
        fail(f"audit root must be below HOME: {root}")

    current = home
    for component in relative_root.parts:
        if component in {"", ".", ".."}:
            fail("unsafe audit-root component")
        current /= component
        ensure_owned_directory(current)

    slug_parts = slug.split("/")
    for component in slug_parts[:-1]:
        current /= component
        ensure_owned_directory(current)

    destination = current / slug_parts[-1]
    if destination.exists() or destination.is_symlink():
        ensure_owned_directory(destination)
        git_dir = destination / ".git"
        if not git_dir.is_dir() or git_dir.is_symlink():
            fail(f"existing audit destination is not a safe Git checkout: {destination}")
        return destination

    subprocess.run(["git", "clone", "--", value, str(destination)], check=True)
    ensure_owned_directory(destination)
    return destination


def main() -> int:
    try:
        if len(sys.argv) == 2:
            print(audit_slug(sys.argv[1]))
        elif len(sys.argv) == 4 and sys.argv[1] == "--prepare":
            print(prepare_target(Path(sys.argv[2]), sys.argv[3]))
        else:
            print(
                "usage: devc-audit-slug [--prepare ROOT] <git-url>",
                file=sys.stderr,
            )
            return 2
    except (ValueError, subprocess.CalledProcessError) as error:
        print(f"invalid audit URL: {error}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
