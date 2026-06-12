"""Graft the Symbols for Legacy Computing block from a donor font into every
TTF under a source tree, preserving names and metrics of the originals.

Usage: merge-legacy-glyphs.py <src-fonts-dir> <donor.ttf> <out-dir>
"""

import sys
import tempfile
from pathlib import Path

from fontTools.merge import Merger
from fontTools.subset import Subsetter
from fontTools.ttLib import TTFont
from fontTools.ttLib.scaleUpem import scale_upem

LEGACY_COMPUTING = range(0x1FB00, 0x1FC00)

src, donor_path, out = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3])
tmpdir = Path(tempfile.mkdtemp())
donor_subsets = {}


def donor_subset(upem):
    """Subset the donor to the legacy block at the given upem, once per upem."""
    if upem not in donor_subsets:
        donor = TTFont(donor_path)
        subsetter = Subsetter()
        subsetter.populate(unicodes=LEGACY_COMPUTING)
        subsetter.subset(donor)
        if donor["head"].unitsPerEm != upem:
            scale_upem(donor, upem)
        donor_subsets[upem] = tmpdir / f"legacy-subset-{upem}.ttf"
        donor.save(donor_subsets[upem])
    return donor_subsets[upem]


for ttf in sorted(src.rglob("*.ttf")):
    target_upem = TTFont(ttf, lazy=True)["head"].unitsPerEm

    # Merger keeps the first font's name table, so family/style stay intact.
    merged = Merger().merge([ttf, donor_subset(target_upem)])
    dest = out / ttf.relative_to(src)
    dest.parent.mkdir(parents=True, exist_ok=True)
    merged.save(dest)
    print(f"patched {ttf.name}")
