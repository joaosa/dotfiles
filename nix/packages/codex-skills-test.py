"""Exercise config preservation and safe failure when merging skill exclusions."""

import importlib.util
import json
import stat
import sys
import tempfile
import tomllib
from pathlib import Path

spec = importlib.util.spec_from_file_location("merge_skills", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

with tempfile.TemporaryDirectory() as directory:
    root = Path(directory).resolve()
    skills = root / "skills"
    skills.mkdir()
    for name in ("duplicate", "reenabled"):
        (skills / name).write_text("skill")
    policy = root / "policy.json"
    policy.write_text(json.dumps({"shared": ["duplicate", "reenabled", "absent"]}))
    config = root / "config.toml"
    for inline in (False, True):
        entry = f'path = {json.dumps(str(skills / "reenabled"))}, enabled = true'
        original = '# keep this comment\nmodel = "chosen"\n'
        original += (
            '[skills]\nconfig = [{' + entry + '}]\n'
            if inline
            else '[[skills.config]]\n' + entry.replace(", ", "\n") + "\n"
        )
        config.write_text(original)
        config.chmod(0o600)
        assert module.merge(config, skills, policy) == 1
        content = config.read_text()
        parsed = tomllib.loads(content)
        assert parsed["model"] == "chosen" and "# keep this comment" in content
        assert parsed["skills"]["config"] == [
            {"path": str(skills / "reenabled"), "enabled": True},
            {"path": str(skills / "duplicate"), "enabled": False},
        ]
        assert stat.S_IMODE(config.stat().st_mode) == 0o600
        modified = config.stat().st_mtime_ns
        assert module.merge(config, skills, policy) == 0
        assert config.stat().st_mtime_ns == modified

    config.write_text("broken = [")
    try:
        module.merge(config, skills, policy)
    except ValueError:
        pass
    else:
        raise AssertionError("invalid TOML was accepted")
    assert config.read_text() == "broken = ["

    config.unlink()
    assert module.merge(config, skills, policy) == 2
    assert stat.S_IMODE(config.stat().st_mode) == 0o600

    # Discover selected skills across sync bundles and plugin versions without
    # disabling unrelated skills or duplicating entries from overlapping globs.
    shared = skills / "synced" / "bundle" / "pdf" / "SKILL.md"
    plugin_root = root / "plugins" / "cache" / "marketplace"
    selected = plugin_root / "pages" / "1.0" / "skills" / "write-page" / "SKILL.md"
    unrelated = plugin_root / "notion" / "1.0" / "skills" / "research" / "SKILL.md"
    for path in (shared, selected, unrelated):
        path.parent.mkdir(parents=True)
        path.write_text("skill")
    policy.write_text(json.dumps({
        "shared": ["synced/*/pdf/SKILL.md", "synced/bundle/pdf/SKILL.md"],
        "plugins": ["marketplace/pages/*/skills/*/SKILL.md"],
    }))
    config.write_text('[[skills.config]]\nname = "keep-me"\nenabled = true\n')
    assert module.merge(config, skills, policy) == 2
    parsed = tomllib.loads(config.read_text())
    assert parsed["skills"]["config"] == [
        {"name": "keep-me", "enabled": True},
        {"path": str(shared), "enabled": False},
        {"path": str(selected), "enabled": False},
    ]
    upgraded = plugin_root / "pages" / "2.0" / "skills" / "write-page" / "SKILL.md"
    upgraded.parent.mkdir(parents=True)
    upgraded.write_text("skill")
    assert module.merge(config, skills, policy) == 1
    assert module.merge(config, skills, policy) == 0

    for invalid in ("../outside", "/absolute/path"):
        original = config.read_text()
        policy.write_text(json.dumps({"shared": [invalid]}))
        try:
            module.merge(config, skills, policy)
        except ValueError:
            pass
        else:
            raise AssertionError("invalid exclusion path was accepted")
        assert config.read_text() == original

print("Codex skill exclusion tests passed")
