"""Add known duplicate skill exclusions without replacing user Codex settings."""

import json
import os
import stat
import sys
import tempfile
from pathlib import Path

import tomlkit


def merge(config_file: Path, skills_root: Path, policy: Path) -> int:
    config_file = config_file.resolve()
    original = config_file.read_text() if config_file.exists() else ""
    config = tomlkit.parse(original)
    entries = config.get("skills", {}).get("config", [])
    configured = {Path(entry["path"]).resolve() for entry in entries}
    missing = []
    for relative in json.loads(policy.read_text()):
        path = Path(relative)
        if path.is_absolute() or ".." in path.parts:
            raise ValueError("skill exclusion paths must be relative to the skills root")
        path = skills_root / path
        if path.is_file() and path.resolve() not in configured:
            missing.append({"path": str(path), "enabled": False})
            configured.add(path.resolve())
    if not missing:
        return 0

    skills = config.setdefault("skills", tomlkit.table())
    entries = skills.setdefault("config", tomlkit.aot())
    entries.extend(missing)
    updated = tomlkit.dumps(config)
    # Validate before touching the original, including inline-array configs.
    tomlkit.parse(updated)
    config_file.parent.mkdir(parents=True, exist_ok=True)
    mode = stat.S_IMODE(config_file.stat().st_mode) if config_file.exists() else 0o600
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w", dir=config_file.parent, delete=False
        ) as out:
            temporary = Path(out.name)
            os.chmod(temporary, mode)
            out.write(updated)
        temporary.replace(config_file)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)
    return len(missing)


if __name__ == "__main__":
    try:
        count = merge(*(Path(arg) for arg in sys.argv[1:]))
        print(f"Codex skill exclusions: added {count}; existing choices preserved")
    except (ValueError, KeyError, TypeError, OSError) as error:
        sys.exit(f"Could not merge Codex skill exclusions; original config preserved: {error}")
