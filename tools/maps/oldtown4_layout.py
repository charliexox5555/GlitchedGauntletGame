#!/usr/bin/env python3
"""Old Town remade (OldTown4, large 2v2-3v3), concept round (2026-11-21): two layout directions for the owner.

Run: python tools/maps/oldtown4_layout.py [canal|hill]
Writes vault/02 Art/References/maps/oldtown4/oldtown4-<option>-layout.png/svg.

Kept from OldTown2: the warm Italian old town (cream / ochre / rose stucco, terracotta roofs, stone arcades, a fountain,
a clock tower, a cafe terrace, a market). Fixed: the closed box of tall flat perimeter walls (the town now continues
past the bounds), the crowd of small rooms (RIVALS-clean lanes instead), the repeated window grid, primitive props.

  canal  "Canale": a canal crosses the middle (walkable, 3 down) like Metro's track bed; a covered stone bridge
         (+6 deck, arches you walk under) is the centre landmark, two flat side bridges at the flanks. Each half: a
         piazza with a fountain, an arcade house with a +12 roof terrace, a cafe, market stalls, a gatehouse at the
         spawn.
  hill   "Collina": a hill town. The middle is a raised piazza (+6) round the clock tower, climbed by stepped streets
         and ramps from both halves; each half is a lower street with houses, a +12 loggia terrace, alleys on the
         flanks that run under arches.
X across, Z along, +Z = team A, 180-degree rotational symmetry.
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import arena_layout as L  # noqa: E402
from arena_layout import Box, Plan  # noqa: E402

CANAL = Plan(
	name="oldtown4_canal",
	title="Old Town: Canale",
	room=[(-100, 110), (100, 110), (100, -110), (-100, -110)],
	center=[
		Box("Canal", 0, 0, 200, 14, 0, 0, "decor"),  # walkable, 3 below the quays
		Box("Ponte (covered bridge)", 0, 0, 14, 24, 7, 0, "deck", 5),  # walk on it at +6, under it in the canal
		Box("Ponte pier", -5.5, 0, 3, 6, 7, 0, "pillar"),
		Box("Ponte pier", 5.5, 0, 3, 6, 7, 0, "pillar"),
	],
	half=[
		Box("Ponte stair", 0, 20, 10, 16, 7, 0, "ramp"),
		Box("Side bridge parapet", 59, 0, 2, 14, 3, 0, "low"),
		Box("Side bridge parapet", 71, 0, 2, 14, 3, 0, "low"),
		Box("Quay crates", -30, 14, 10, 5, 3.5, 0, "low"),
		# the piazza: fountain, stalls, a column
		Box("Fountain", 0, 48, 14, 14, 3, 0, "low"),
		Box("Fountain column", 0, 48, 4, 4, 10, 0, "pillar"),
		Box("Stall", -22, 36, 8, 4, 3.5, 0, "low"),
		Box("Stall", 22, 60, 8, 4, 3.5, 0, "low"),
		# arcade house west with a +12 roof terrace (outside stair), cafe east (full)
		Box("Arcade house", -62, 50, 26, 36, 12, 0, "deck"),
		Box("Arcade stair", -46.5, 46, 5, 20, 12, 0, "ramp"),
		Box("Cafe", 62, 44, 26, 30, 16),
		Box("Cafe tables", 36, 30, 6, 10, 3, 0, "low"),
		# flank houses on the quay, a boathouse
		Box("Quay house", -90, 14, 20, 14, 14),
		Box("Boathouse", 90, 14.5, 20, 15, 10),
		Box("Well", 30, 80, 6, 6, 3.5, 0, "low"),
		Box("Gatehouse", 0, 88, 34, 8, 12, 0, "baffle"),
		Box("Corner house", -75, 99, 50, 22, 16),
		Box("Corner house", 75, 99, 50, 22, 16),
		Box("Loggia kiosk", -22, 42, 10, 8, 10),  # breaks the straight line from the spawn exit
		Box("Planter", -30, 86, 8, 8, 3.5, 0, "low"),
	],
	spawns_a=[(-12, 101), (0, 103), (12, 101), (-6, 97), (6, 97)],
	duel=False,
	notes=["canal 3 down, walkable; Ponte +6 with arches under it; side bridges at x +-65"],
)

HILL = Plan(
	name="oldtown4_hill",
	title="Old Town: Collina",
	room=[(-100, 110), (100, 110), (100, -110), (-100, -110)],
	center=[
		Box("Hill piazza", 0, 0, 60, 44, 7, 0, "deck"),  # the raised middle
		Box("Clock tower", 0, 0, 10, 10, 40, 0, "pillar"),
	],
	half=[
		# two climbs per side up to the piazza: a broad stepped street (centre-left) and a ramp (right)
		Box("Stepped street", -18, 30, 14, 16, 7, 0, "ramp"),
		Box("Ramp", 24, 30, 10, 16, 7, 0, "ramp"),
		Box("Piazza wall", 3, 23, 18, 2, 7),  # retaining wall faces between the climbs
		Box("Fountain", 22, 52, 12, 12, 3, 0, "low"),
		Box("Fountain column", 22, 52, 4, 4, 10, 0, "pillar"),
		# houses: a loggia with a +12 terrace (west), a long house (east), alley arches on the flanks
		Box("Loggia house", -60, 46, 30, 28, 12, 0, "deck"),
		Box("Loggia stair", -42.5, 44, 5, 20, 12, 0, "ramp"),
		Box("Long house", 64, 52, 24, 34, 16),
		Box("Alley arch", -88, 22, 24, 10, 14, 0, "full", 8),
		Box("Alley arch", 88, 14, 24, 10, 14, 0, "full", 8),
		Box("Stall", -22, 52, 8, 4, 3.5, 0, "low"),
		Box("Cart", 40, 80, 8, 4, 3.5, 0, "low"),
		Box("Gatehouse", 0, 88, 34, 8, 12, 0, "baffle"),
		Box("Corner house", -75, 99, 50, 22, 16),
		Box("Corner house", 75, 99, 50, 22, 16),
	],
	spawns_a=[(-12, 101), (0, 103), (12, 101), (-6, 97), (6, 97)],
	duel=False,
	notes=["middle piazza +6 round the clock tower; two climbs a side; loggia terrace +12"],
)

PLANS = {"canal": CANAL, "hill": HILL}

if __name__ == "__main__":
	which = sys.argv[1:] or ["canal", "hill"]
	out_dir = Path(__file__).resolve().parents[2] / "vault/02 Art/References/maps/oldtown4"
	out_dir.mkdir(parents=True, exist_ok=True)
	for w in which:
		plan = PLANS[w]
		longest = L.report(plan)
		(out_dir / f"oldtown4-{w}-layout.svg").write_text(L.svg(plan, longest), encoding="utf-8")
		L.png(plan, longest, out_dir / f"oldtown4-{w}-layout.png")
