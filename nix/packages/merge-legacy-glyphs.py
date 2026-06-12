"""Graft the Symbols for Legacy Computing block from a donor font into every
TTF under a source tree, preserving names and metrics of the originals.

Usage: merge-legacy-glyphs.py <src-fonts-dir> <donor.ttf> <out-dir>
"""

import os
import sys
import tempfile
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path

from fontTools.merge import Merger
from fontTools.subset import Subsetter
from fontTools.ttLib import TTFont
from fontTools.ttLib.scaleUpem import scale_upem

LEGACY_COMPUTING = range(0x1FB00, 0x1FC00)


def donor_subset(donor_path, upem, tmpdir):
    """Subset the donor to the legacy block at the given upem."""
    donor = TTFont(donor_path)
    subsetter = Subsetter()
    subsetter.populate(unicodes=LEGACY_COMPUTING)
    subsetter.subset(donor)
    if donor["head"].unitsPerEm != upem:
        scale_upem(donor, upem)
    path = tmpdir / f"legacy-subset-{upem}.ttf"
    donor.save(path)
    return path


def merge_one(ttf, subset, dest):
    # Merger keeps the first font's name table, so family/style stay intact.
    merged = Merger().merge([ttf, subset])
    dest.parent.mkdir(parents=True, exist_ok=True)
    merged.save(dest)
    print(f"patched {ttf.name}")


def main():
    src, donor_path, out = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3])
    tmpdir = Path(tempfile.mkdtemp())

    fonts = sorted(src.rglob("*.ttf"))
    upems = {ttf: TTFont(ttf, lazy=True)["head"].unitsPerEm for ttf in fonts}
    subsets = {upem: donor_subset(donor_path, upem, tmpdir) for upem in set(upems.values())}

    # The per-font merges are independent and CPU-bound; iterating the map
    # result surfaces any worker exception as a build failure.
    workers = int(os.environ.get("NIX_BUILD_CORES", "0")) or os.cpu_count()
    with ProcessPoolExecutor(max_workers=workers) as pool:
        list(
            pool.map(
                merge_one,
                fonts,
                (subsets[upems[ttf]] for ttf in fonts),
                (out / ttf.relative_to(src) for ttf in fonts),
            )
        )


if __name__ == "__main__":
    main()
