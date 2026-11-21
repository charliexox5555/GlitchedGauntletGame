#!/usr/bin/env python3
"""Snowpeak4 (regular, 1v1-2v2): Snowpeak rebuilt from Snowpeak2's vibe with an open middle (2026-11-20).

Run: python tools/maps/snowpeak4_layout.py
Uses the checks in arena_layout.py and writes vault/02 Art/References/maps/snowpeak4/snowpeak4-layout.svg/png.

Owner (2026-11-20): keep Snowpeak2's whole vibe (a timber ski lodge, the gondola station with its red cabins, a
frozen pond, the snowcat, pines and big mountains) but the middle was "too congested", the snowcats weren't good,
no spawn nooks (the ghost hold keeps you at the spawn) and clean mountains. RIVALS Village (read-only, measured
2026-11-20: 300 x 300, 2 spawns 185 apart, an open middle round a raised feature, two buildings per half pushed out
to the sides) gives the flow: the buildings leave the middle. Each half has a Lodge (west, deck +10) staggered
against the other half's gondola Station (west, deck +10); the middle is the open saddle round the frozen pond with
one rock island, a snowcat flanking it on each side. Studs; X across, Z along, +Z = team A. 180-degree symmetry.
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import arena_layout as L  # noqa: E402
from arena_layout import Box, Plan  # noqa: E402

SNOWPEAK4 = Plan(
	name="snowpeak4",
	title="Snowpeak4",
	room=[(-75, 95), (75, 95), (75, -95), (-75, -95)],
	center=[
		# the frozen pond (ice, walkable) and its rock island: the one feature in the open middle
		Box("Pond", 0, 0, 36, 26, 0, 0, "decor"),
		Box("Pond rock", 0, 0, 12, 9, 12),  # a snowy outcrop, too tall to climb (12)
	],
	half=[
		# A's Lodge on the west (+Z half), its deck +10 on the side toward the middle, outside stair from the spawn side
		Box("Lodge", -52, 50, 26, 24, 20),
		Box("Lodge deck", -34, 50, 10, 24, 10, 0, "deck", 9),
		Box("Lodge stair", -34, 70, 5, 16, 10, 0, "ramp"),  # 32 degrees
		# A's gondola Station on the east: concrete base, deck +10 (the parked cabin), stair from the spawn side
		Box("Station", 50, 36, 22, 18, 10, 0, "deck"),
		Box("Station stair", 36.5, 51, 5, 16, 10, 0, "ramp"),
		Box("Station step high", 36.5, 30, 5, 5, 7, 0, "deck"),
		Box("Station step low", 31.5, 30, 5, 5, 3.5, 0, "plinth"),
		# the snowcat flanking the pond on the east side (B's is on the west)
		Box("Snowcat", 30, 12, 8, 15, 9),
		# the warming hut off the middle on the west (B's on the east): breaks the diagonals past the pond
		Box("Warming hut", -21, 18, 12, 9, 10),
		# mid cover between the buildings and the pond
		Box("Log pile", -38, 28, 9, 3.5, 3.5, 0, "low"),
		Box("Snowbank", 14, 34, 10, 4, 3, 0, "low"),
		Box("Supply crates", 22, 56, 10, 5, 3.5, 0, "low"),
		Box("Crate stack", 60, 60, 5, 5, 12),
		Box("Ticket booth", -11, 54, 6, 5, 9),  # the lift ticket booth on the west lane
		Box("Ski rack", -1, 44, 9, 2, 3.5, 0, "low"),
		# the ski-patrol hut screening the spawn, a woodshed at the west corner
		Box("Patrol hut", 0, 70, 30, 7, 10, 0, "baffle"),
		# pine clumps flanking the spawn (trunk collision, foliage above): the spawn is screened, not walled in
		Box("Pines", -50, 84, 12, 8, 25),  # west of the lodge stair's foot
		Box("Pines 2", 31, 80, 12, 10, 25),
		Box("Woodshed", -71.5, 74, 7, 12, 9),  # against the west fence, beside the lodge
		Box("Sled stack", 47, 84, 6, 3, 3.5, 0, "low"),
		# character pass (owner playtest 2026-11-21): lantern posts on the routes, the trail sign by the spawn, the fire
		# pit west of the lodge porch
		Box("Lamp", 8, 58, 1, 1, 9.6, 0, "pillar"),
		Box("Lamp", -21, 60, 1, 1, 9.6, 0, "pillar"),
		Box("Lamp", 44, 64, 1, 1, 9.6, 0, "pillar"),
		Box("Trail sign", -36, 86, 1, 1, 7.5, 0, "pillar"),
		Box("Fire pit", -50, 71, 5, 5, 1.0, 0, "low"),
	],
	spawns_a=[(-12, 89), (0, 91), (12, 89), (-6, 85), (6, 85)],
	duel=False,
	notes=[
		"open middle: pond + one rock island; snowcats flank it; lodge / station decks +10",
		"long sides: fence on a drop-off; ends: snow banks and pines, the world beyond (no spawn nooks)",
	],
)

if __name__ == "__main__":
	out_dir = Path(__file__).resolve().parents[2] / "vault/02 Art/References/maps/snowpeak4"
	out_dir.mkdir(parents=True, exist_ok=True)
	longest = L.report(SNOWPEAK4)
	(out_dir / "snowpeak4-layout.svg").write_text(L.svg(SNOWPEAK4, longest), encoding="utf-8")
	L.png(SNOWPEAK4, longest, out_dir / "snowpeak4-layout.png")
	print(f"wrote {out_dir / 'snowpeak4-layout.png'}")
