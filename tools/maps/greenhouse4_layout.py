#!/usr/bin/env python3
"""Greenhouse4 (regular, 1v1-2v2): a Victorian iron-and-glass conservatory (2026-11-21, map lineup round 2, map 2).

Run: python tools/maps/greenhouse4_layout.py
Uses the checks in arena_layout.py and writes vault/02 Art/References/maps/greenhouse4/greenhouse4-layout.svg/png.

Old Greenhouse 1-3 are theme references only: Greenhouse3 was pulled 2026-11-20 for curved shapes, plain ground and no
world round it. RIVALS Museum / Studio (read-only) give the flow: one big readable hall in the middle with a raised
gallery, a few doors in, outdoor lanes on the flanks.

The middle: the Palm House (88 x 72), glass on a stone dwarf wall, a faceted clerestory roof and an octagonal lantern
over the lily pond. On the pond's island stands a tall palm (the landmark). Inside: planting beds as cover, a rockery
just inside each grand door (it breaks the door-to-door line), an iron gallery at +10 along both side walls on
cast-iron columns, reached by four iron stairs (each team has one to each gallery, at its own end).
Doors: three in each end wall (a grand door and two side doors), two in each side wall.
Each half (team A at +Z): a terrace walk, a box-hedge parterre with topiary, the potting house (the spawn baffle), the
spawn court with palms in tubs. One flank holds the team's Fern House (a smaller glass hall, an indoor lane); the other
an open garden walk with a yew hedge, a cold frame and a raised rock-garden terrace (+4, ramp + climb).
Heights: pond -1.5 (wade, step out), ground 0, rock-garden terraces +4, galleries +10. Roofs out of play.
Glass walls block shots and bodies; they count as full walls here.
Studs; X across, Z along, +Z = team A. 180-degree rotational symmetry.
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import arena_layout as L  # noqa: E402
from arena_layout import Box, Plan  # noqa: E402

GREENHOUSE4 = Plan(
	name="greenhouse4",
	title="Greenhouse4",
	room=[(-70, 98), (70, 98), (70, -98), (-70, -98)],
	center=[
		# the lily pond's island with the palm and ferns (the line breaker in the middle of the hall)
		Box("Palm island", 0, 0, 7, 7, 8),
		Box("Lily pond", 0, 0, 26, 26, 0, 0, "decor"),
	],
	half=[
		# ---- the Palm House, this half (z 0..36). Glass on a stone dwarf wall, eaves at 20.
		Box("End wall W", -30, 36, 28, 1.2, 20),
		Box("End wall pier W", -7.5, 36, 3, 1.2, 20),
		Box("End wall pier E", 7.5, 36, 3, 1.2, 20),
		Box("End wall E", 30, 36, 28, 1.2, 20),
		Box("Side wall E", 44, 7, 1.2, 14, 20),
		Box("Side wall E2", 44, 29, 1.2, 14, 20),
		Box("Side wall W", -44, 7, 1.2, 14, 20),
		Box("Side wall W2", -44, 29, 1.2, 14, 20),
		# the iron gallery (+10) on both side walls, on columns; a stair up to each at this team's end
		Box("Gallery E", 40, 17.75, 8, 35.5, 10, 0, "deck", 9.4),
		Box("Gallery W", -40, 17.75, 8, 35.5, 10, 0, "deck", 9.4),
		Box("Gallery stair E", 27, 32, 18, 5, 10, 0, "ramp"),
		Box("Gallery stair W", -27, 32, 18, 5, 10, 0, "ramp"),
		Box("Column", 36, 6, 1, 1, 10, 0, "pillar"),
		Box("Column", 36, 18, 1, 1, 10, 0, "pillar"),
		Box("Column", -36, 6, 1, 1, 10, 0, "pillar"),
		Box("Column", -36, 18, 1, 1, 10, 0, "pillar"),
		# planting beds (stone kerb 2.8, plants to ~7, nobody stands on them) and the rockery inside the grand door
		Box("Bed E", 16, 16, 12, 8, 9),
		Box("Bed W", -16, 16, 12, 8, 9),
		Box("Rockery", 0, 26, 9, 5, 9),
		# ---- outside, this half (z 36..98)
		# the box-hedge parterre: low hedges (shoot over), two clipped topiary, a sundial bed
		Box("Box hedge", -27, 50, 12, 3, 3, 0, "low"),
		Box("Box hedge", 27, 50, 12, 3, 3, 0, "low"),
		Box("Box hedge", -27, 62, 12, 3, 3, 0, "low"),
		Box("Box hedge", 27, 62, 12, 3, 3, 0, "low"),
		Box("Topiary", -12, 56, 3, 3, 9, 0, "pillar"),
		Box("Topiary", 12, 56, 3, 3, 9, 0, "pillar"),
		Box("Sundial bed", 0, 56, 7, 7, 2.5, 0, "low"),
		Box("Potting house", 0, 74, 22, 8, 12, 0, "baffle"),
		Box("Palm tub", -40, 87, 8, 8, 9),
		Box("Palm tub", 40, 87, 8, 8, 9),
		# the team's Fern House on the west flank (x -70..-52, z 10..58): glass, eaves 11; doors at both ends and one
		# facing the Palm House's side door
		Box("Fern house inner wall", -52, 12, 1.2, 4, 14),
		Box("Fern house inner wall", -52, 40, 1.2, 36, 14),
		Box("Fern house end", -67.25, 10, 5.5, 1.2, 14),
		Box("Fern house end", -54.75, 10, 5.5, 1.2, 14),
		Box("Fern house end", -64.75, 58, 10.5, 1.2, 14),  # the north door sits by the inner wall (off the south door's line)
		Box("Fern bench", -67.5, 26, 5, 14, 3, 0, "low"),
		Box("Tree fern bed", -67.5, 45, 5, 10, 9),
		Box("Fern bed", -55.5, 34, 6, 8, 9),
		# the open garden walk on the east flank: a yew hedge, a cold frame, the rock-garden terrace (+4)
		Box("Boiler house", 49.25, 31, 10.5, 11, 12),  # against the Palm House wall, its chimney a landmark per side
		Box("Yew alcove", 66, 30, 8, 10, 8.5),
		Box("Garden shed", 66, 10, 8, 12, 10),
		Box("Rock garden", 62, 62, 16, 22, 4, 0, "deck"),
		Box("Rock garden ramp", 62, 45, 8, 12, 4, 0, "ramp"),
	],
	spawns_a=[(-12, 90), (0, 92), (12, 90), (-6, 86), (6, 86)],
	duel=False,
	notes=[
		"Palm House 88 x 72 in the middle: pond + palm island, beds, rockeries, +10 galleries on both sides (4 stairs)",
		"each half: parterre, potting house baffle, spawn court; Fern House on one flank, rock garden (+4) on the other",
	],
)

if __name__ == "__main__":
	out_dir = Path(__file__).resolve().parents[2] / "vault/02 Art/References/maps/greenhouse4"
	out_dir.mkdir(parents=True, exist_ok=True)
	longest = L.report(GREENHOUSE4)
	(out_dir / "greenhouse4-layout.svg").write_text(L.svg(GREENHOUSE4, longest), encoding="utf-8")
	L.png(GREENHOUSE4, longest, out_dir / "greenhouse4-layout.png")
	print(f"wrote {out_dir / 'greenhouse4-layout.png'}")
