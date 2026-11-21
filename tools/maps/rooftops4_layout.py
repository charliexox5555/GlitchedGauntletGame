#!/usr/bin/env python3
"""Rooftops4 (regular, 1v1-2v2): Rooftops rebuilt as a city block at blue hour (2026-11-21, map lineup round 2).

Run: python tools/maps/rooftops4_layout.py
Uses the checks in arena_layout.py and writes vault/02 Art/References/maps/rooftops4/rooftops4-layout.svg/png.

Owner verdicts on the old Rooftops maps: Rooftops2 was "the weakest map, with no levels and no character" (big flat
roof floors, a dark pit, AC stacks blocking routes, blocky signs, props off scale); the old Rooftops met at 1.7 s.
RIVALS Construction (read-only, measured: ~125 x 150 core, spawns 125 apart, 2-4 lanes, longest sight 75, a +22
deck) gives the flow: a few strong lanes and one real high deck per side.

Three buildings in a row, split by two alleys (the fall, `void`), crossed by bridges (`bridge`):
  team roofs (0) with a spawn penthouse baffle, a fire-escape deck (+8) and AC / skylight cover;
  the middle building: a sunken roof court (-6, drop in anywhere, climb out at 6 < 7.5 or by the steps) round the
  water-tank tower (the landmark, its pump house is the middle line breaker); its west and east wings are higher
  roofs: a billboard deck (+8, stair + step) at one end and a skylight roof (+3.5) at the other, staggered by the
  180-degree turn.
Heights: court -6, roofs 0, skylight roofs +3.5, cabinet steps +3.5, fire-escape and billboard decks +8; the tank,
huts and penthouses are out of reach. In this 2-D check the court counts as floor (its 6-stud drop only blocks
more), so the numbers are on the safe side.
Studs; X across, Z along, +Z = team A. 180-degree rotational symmetry.
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import arena_layout as L  # noqa: E402
from arena_layout import Box, Plan  # noqa: E402

ROOFTOPS4 = Plan(
	name="rooftops4",
	title="Rooftops4",
	room=[(-70, 96), (70, 96), (70, -96), (-70, -96)],
	center=[
		# the middle building (z -38..38): sunken court -6 round the tank tower
		Box("Pump house (tank tower)", 0, 0, 20, 20, 11),  # the tank stands on it at +22
	],
	half=[
		# ---- the alley between the team roof and the middle building (z 38..48): the fall, three crossings
		Box("Alley", 0, 43, 140, 10, 0, 0, "void"),
		Box("Plank bridge", -46, 43, 6, 12, 0, 0, "bridge"),
		Box("Steel catwalk", 14, 43, 8, 12, 0, 0, "bridge"),
		Box("Fire-escape bridge", 58, 43, 6, 12, 0, 0, "bridge"),
		# ---- the team roof (z 48..96, level 0). A front row of roof structures along the alley edge (1 in from it),
		# open only at the crossings, cuts the long roof-to-roof lines.
		Box("Lift machine room", -61, 53, 18, 8, 12),
		Box("Stair hut", -26, 53, 28, 8, 10),
		Box("Tar-paper shed", -3, 52.5, 18, 7, 10),
		Box("Condenser stack", 28, 53, 12, 8, 10),
		Box("Chimney stack", 41, 52.5, 14, 5, 12),
		Box("Vent stack", 66, 53, 8, 8, 10),
		# behind it: the fire-escape deck (+8), the spawn penthouse baffle, low cover
		Box("Fire-escape deck", -60, 71, 20, 14, 8, 0, "deck"),
		Box("Fire-escape stair", -60, 87, 6, 18, 8, 0, "ramp"),
		Box("Deck step", -47.5, 67, 5, 5, 3.5, 0, "plinth"),
		Box("Tank house", -38, 72, 8, 8, 11),
		Box("Spawn penthouse", 0, 74, 30, 9, 12, 0, "baffle"),
		Box("Skylight", -28, 86, 12, 7, 2.5, 0, "low"),
		Box("AC unit", 28, 68, 10, 5, 3.5, 0, "low"),
		Box("Roof vents", 36, 87, 8, 4, 3, 0, "low"),
		Box("Water heater", 56, 74, 6, 6, 10),
		# ---- the middle building, this half's side (z 0..38)
		# billboard deck (+8) on the west wing: a stair up from the wing ledge (+ landing), a cabinet step on its north side
		Box("Billboard deck", -53, 14, 34, 22, 8, 0, "deck"),
		Box("Billboard deck stair", -33, 22, 6, 16, 8, 0, "ramp"),
		Box("Billboard step", -53, 27.5, 5, 5, 3.5, 0, "plinth"),
		Box("Roof access hut", -28, 34.5, 8, 6, 10),
		Box("Billboard frame", -68, 14, 2, 20, 18, 0, "full", 8),  # on the deck's outer edge, faces the court
		Box("Billboard leg", -68, 6, 2, 2, 18, 0, "pillar", 8),
		Box("Billboard leg", -68, 22, 2, 2, 18, 0, "pillar", 8),
		# skylight roof (+3.5) on the east wing: a glass roof lantern, AC units
		Box("Skylight roof", 53, 18, 34, 28, 3.5, 0, "plinth"),
		Box("Roof lantern", 52, 18, 12, 10, 9),
		Box("Wing AC", 41, 29, 10, 5, 11, 0, "full", 3.5),
		# the court (-6): cover round the tank tower
		Box("Stair bulkhead", -17, 21, 11, 8, 10),
		Box("Fan housing", 24, 7, 6, 22, 9),
		Box("Pipe chase", 22, 31, 6, 6, 10),
		Box("Court steps", 3, 23, 10, 10, 0, 0, "ramp"),  # 0 down to -6
	],
	spawns_a=[(-12, 89), (0, 91), (12, 89), (-6, 85), (6, 85)],
	duel=False,
	notes=[
		"three buildings: team roofs 0, middle court -6 round the tank tower, wings +8 billboard deck / +3.5 skylight",
		"two alleys (void, 10 wide) crossed by a plank bridge, a steel catwalk and a fire-escape bridge a side",
	],
)

if __name__ == "__main__":
	out_dir = Path(__file__).resolve().parents[2] / "vault/02 Art/References/maps/rooftops4"
	out_dir.mkdir(parents=True, exist_ok=True)
	longest = L.report(ROOFTOPS4)
	(out_dir / "rooftops4-layout.svg").write_text(L.svg(ROOFTOPS4, longest), encoding="utf-8")
	L.png(ROOFTOPS4, longest, out_dir / "rooftops4-layout.png")
	print(f"wrote {out_dir / 'rooftops4-layout.png'}")
