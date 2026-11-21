#!/usr/bin/env python3
"""Metro4 (large, 2v2-3v3): Metro rebuilt from RIVALS Big Station's flow (2026-11-20).

Run: python tools/maps/metro4_layout.py
Uses the checks in arena_layout.py and writes vault/02 Art/References/maps/metro4/metro4-layout.svg/png.

Big Station's flow at our size (vault/01 Design/Maps/Metro4.md): the tracks run across the middle (along X) in a
sunken bed (-2.5) with parked trains as the divider; the two trains are staggered, so the ground crossings form
an S (the open track beside each train, a gap between cars, the bed under the footbridge); a footbridge at +14
crosses over the tracks; each team's concourse has a staggered ticket hall (+10 roof deck: stair + crate steps)
and a shop block; a planter and a kiosk near each spawn. A glass hall roof over everything, open at both track
ends (the city outside). Studs; X along the tracks, Z across, +Z = team A. 180-degree rotational symmetry.
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import arena_layout as L  # noqa: E402
from arena_layout import Box, Plan  # noqa: E402

BED = -2.5  # track bed

METRO4 = Plan(
	name="metro4",
	title="Metro4",
	room=[(-115, 105), (115, 105), (115, -105), (-115, -105)],
	center=[
		Box("Track bed", 0, 0, 230, 32, BED, 0, "decor"),  # low ground, walkable (2.5 down)
		Box("Footbridge", 0, 0, 6, 64, 14, 0, "deck", 13),
	],
	half=[
		# the A-side train on the north track (z +8): two cars with a 7-stud gap; tops +10 (12.5 over the bed)
		Box("Car A1", -83, 11, 48, 10, 10, 0, "full", BED),
		Box("Car A2", -28, 11, 48, 10, 10, 0, "full", BED),
		# a short work wagon parked on the open part of A's track (breaks the long run along it)
		Box("Work wagon", 75, 11, 15, 10, 10, 0, "full", BED),
		# footbridge landing and stair down into A's concourse; its columns on the platform edge
		Box("Bridge landing", 0, 35, 6, 6, 14, 0, "deck", 13),
		Box("Bridge stair", 17, 35, 28, 6, 14, 0, "ramp"),
		Box("Bridge column", 0, 25, 2, 2, 13, 0, "pillar"),
		# platform: hall columns every 30 (the roof's), benches, a vending pair
		Box("Column", -90, 25, 2, 2, 30, 0, "pillar"),
		Box("Column", -60, 25, 2, 2, 30, 0, "pillar"),
		Box("Column", -30, 25, 2, 2, 30, 0, "pillar"),
		Box("Column", 30, 25, 2, 2, 30, 0, "pillar"),
		Box("Column", 60, 25, 2, 2, 30, 0, "pillar"),
		Box("Column", 90, 25, 2, 2, 30, 0, "pillar"),
		Box("Bench", -45, 30, 10, 2.5, 3, 0, "low"),
		Box("Bench", 45, 30, 10, 2.5, 3, 0, "low"),
		Box("Vending", -15, 30, 6, 3, 9),
		# ticket hall (west half): roof deck +10 with a parapet; outside stair on its east side, crate steps west
		Box("Ticket hall", -70, 62.5, 40, 35, 10, 0, "deck"),
		Box("Hall stair", -47.5, 70, 5, 20, 10, 0, "ramp"),
		Box("Hall step high", -92.5, 52.5, 5, 5, 7, 0, "deck"),
		Box("Hall step low", -97.5, 52.5, 5, 5, 3.5, 0, "plinth"),
		# shop block (east half), full cover
		Box("Shops", 72.5, 45, 30, 25, 10),
		Box("Shop crates", 45, 65, 5, 10, 3.5, 0, "low"),
		Box("Crate stack 2", 35, 45, 5, 10, 12),
		# near the spawn: kiosk baffle, planter, crates
		Box("Kiosk", 0, 77.5, 20, 6, 10, 0, "baffle"),
		Box("Planter", 30, 75, 10, 10, 3.5, 0, "low"),
		Box("Ticket gates", -35, 45, 15, 3, 3.5, 0, "low"),
		Box("Vending 2", 75, 31, 6, 3, 9),  # against the shop front
		Box("Back crates", -65, 92.5, 10, 5, 3.5, 0, "low"),
		Box("Crate stack", -25, 50, 5, 10, 12),
		Box("Crates", 15, 52.5, 10, 5, 3.5, 0, "low"),
		Box("Luggage cart", -40, 90, 10, 5, 3.5, 0, "low"),
	],
	spawns_a=[(-12, 98), (0, 100), (12, 98), (-6, 93), (6, 93)],
	duel=False,
	notes=[
		"track bed -2.5 (low ground); trains staggered; footbridge +14; ticket hall deck +10",
		"open track ends at x +-115: bounds there, the city beyond",
	],
)

if __name__ == "__main__":
	out_dir = Path(__file__).resolve().parents[2] / "vault/02 Art/References/maps/metro4"
	out_dir.mkdir(parents=True, exist_ok=True)
	longest = L.report(METRO4)
	(out_dir / "metro4-layout.svg").write_text(L.svg(METRO4, longest), encoding="utf-8")
	L.png(METRO4, longest, out_dir / "metro4-layout.png")
	print(f"wrote {out_dir / 'metro4-layout.png'}")
