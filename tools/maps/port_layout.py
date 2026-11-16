#!/usr/bin/env python3
"""Pier (duel) + Dockyard (3v3) layouts, map redesign batch 2 (2026-11-16). One port kit.

Run: python tools/maps/port_layout.py [pier|dockyard]   (default: both)
Uses the checks in arena_layout.py (spawn gap, sightlines, lanes, cover, pinches, jumps, slide runs,
first sight) and writes vault/02 Art/References/maps/port/<map>-layout.svg/png.

Kit module (learned from RIVALS Docks: 9.4 x 10.2 x 27.5 / 34 containers, stacks of two, crates, one crane):
  container 10 x 10 x 30 (short one 10 x 10 x 20), 10 high = full cover nobody jumps onto (ledge limit 7.5);
  crate 5 x 5, 3.5 high (low cover) or 7 high (a step: floor -> 7 -> container top 10, every rise <= 4);
  the gantry crane is the landmark: two leg frames, a beam overhead (not walkable).
Studs; X across, Z along, +Z = team A. 180-degree rotational symmetry.
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import arena_layout as L  # noqa: E402
from arena_layout import Box, Plan  # noqa: E402

C = 10.0  # container width and height


def container(name, x, z, along_z=True, length=30.0, h=C, base=0.0):
    return Box(name, x, z, C if along_z else length, length if along_z else C, h, 0, "full", base)


# PIER: the duel slice. A 90 x 150 pier deck, water both sides (bounds at the deck edge, a low rail).
# Spawns at the two ends behind a crosswise container; three lanes split by container rows; the gantry
# straddles the middle; each team has a container-top perch at +10 reached by crate steps.
PIER = Plan(
    name="pier",
    title="Pier",
    room=[(-45, 75), (45, 75), (45, -75), (-45, -75)],
    center=[
        container("Mid container", 0, 0, along_z=True, length=20),
        Box("Gantry leg", -42.5, 0, 5, 10, 30, 0, "pillar"),
        Box("Gantry leg", 42.5, 0, 5, 10, 30, 0, "pillar"),
        Box("Gantry beam", 0, 0, 90, 5, 30, 0, "full", 25.0),
    ],
    half=[
        container("Spawn container", 0, 55, along_z=False, length=30),
        container("Flank container", -37.5, 55, along_z=False, length=15),
        # left lane row (x < 0 on the A half)
        container("Row container", -25, 25, along_z=True, length=30),
        Box("Crate stack", -17.5, 17.5, 5, 5, 10),
        # the perch: a container top at +10 on the right; crates step up from its inner side
        Box("Perch deck", 30, 32.5, 10, 25, 10, 0, "deck"),
        Box("Step crate high", 22.5, 22.5, 5, 5, 7, 0, "deck"),
        Box("Step crate low", 17.5, 22.5, 5, 5, 3.5, 0, "plinth"),
        Box("Back step high", 30, 47.5, 5, 5, 7, 0, "deck"),
        Box("Back step low", 30, 52.5, 5, 5, 3.5, 0, "plinth"),
        # mid lane
        container("Cross container", 0, 35, along_z=False, length=20),
        Box("Edge crates", -42.5, 20, 5, 10, 3.5, 0, "low"),
    ],
    spawns_a=[(-5, 70), (5, 70), (-5, 65), (5, 65)],
    duel=True,
    notes=["water both sides; bounds at the deck edge up to +60"],
)

# DOCKYARD: the full port, 3v3. A 220 x 250 quay; a warehouse on each team's left flank (an interior
# route), container stacks in three lanes, the gantry over the middle lane, a +10 container perch and a
# +14 warehouse roof deck a side.
DOCKYARD = Plan(
    name="dockyard",
    title="Dockyard",
    room=[(-100, 115), (100, 115), (100, -115), (-100, -115)],
    center=[
        container("Mid container", 0, 0, along_z=True, length=30),
        Box("Gantry leg", -60, 0, 5, 10, 34, 0, "pillar"),
        Box("Gantry leg", 60, 0, 5, 10, 34, 0, "pillar"),
        Box("Gantry beam", 0, 0, 125, 5, 34, 0, "full", 29.0),
    ],
    half=[
        container("Spawn container", 0, 85, along_z=False, length=30),
        container("Spawn flank", -40, 92.5, along_z=False, length=20),
        # warehouse on the left flank (x -100..-60, z 40..80): doors east and north, roof deck +14
        Box("Warehouse wall N1", -92.5, 77.5, 15, 5, 12),
        Box("Warehouse wall N2", -67.5, 77.5, 15, 5, 12),
        Box("Warehouse wall S", -80, 42.5, 40, 5, 12),
        Box("Warehouse wall E1", -62.5, 50, 5, 10, 12),
        Box("Warehouse wall E2", -62.5, 70, 5, 10, 12),
        Box("Warehouse roof", -80, 60, 40, 40, 14, 0, "deck", 12.0),
        Box("Roof stair", -55, 52.5, 10, 25, 14, 0, "ramp"),
        Box("Roof landing", -55, 72.5, 10, 15, 14, 0, "deck"),
        container("Roof container", -80, 35, along_z=False, length=20),
        Box("Roof container top", -80, 35, 20, 10, 10, 0, "deck"),
        Box("Roof step high", -77.5, 27.5, 5, 5, 7, 0, "deck"),
        Box("Roof step low", -77.5, 22.5, 5, 5, 3.5, 0, "plinth"),
        # container yard
        container("Lane stack L", -30, 40, along_z=True, length=30),
        container("Lane stack R", 30, 25, along_z=True, length=30),
        container("Cross container", 5, 55, along_z=False, length=30),
        Box("Mid crates", 15, 15, 5, 10, 3.5, 0, "low"),
        Box("Lane crate stack", -20, 10, 10, 10, 10),
        container("Yard container", 40, 75, along_z=False, length=20),
        # right flank perch: a container top at +10, crate steps at both ends
        Box("Perch deck", 70, 50, 10, 30, 10, 0, "deck"),
        Box("Step crate high", 62.5, 40, 5, 5, 7, 0, "deck"),
        Box("Step crate low", 57.5, 40, 5, 5, 3.5, 0, "plinth"),
        Box("Back step high", 70, 67.5, 5, 5, 7, 0, "deck"),
        Box("Back step low", 70, 72.5, 5, 5, 3.5, 0, "plinth"),
        container("Right short", 85, 10, along_z=True, length=20),
        Box("Gantry crate stack", 45, 0, 10, 10, 10),
    ],
    spawns_a=[(-12, 103), (0, 106), (12, 103), (-6, 98), (6, 98)],
    duel=False,
    notes=["quay edge: bounds at the edge; the warehouse is a covered route (walls 12, roof deck at +12..14)"],
)

PLANS = {"pier": PIER, "dockyard": DOCKYARD}

if __name__ == "__main__":
    out_dir = Path(__file__).resolve().parents[2] / "vault/02 Art/References/maps/port"
    out_dir.mkdir(parents=True, exist_ok=True)
    for nm in sys.argv[1:] or ["pier", "dockyard"]:
        p = PLANS[nm]
        longest = L.report(p)
        (out_dir / f"{nm}-layout.svg").write_text(L.svg(p, longest), encoding="utf-8")
        L.png(p, longest, out_dir / f"{nm}-layout.png")
        print(f"wrote {out_dir / (nm + '-layout.png')}")
