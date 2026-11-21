#!/usr/bin/env python3
"""Foundry4 (regular, 1v1-2v2): a steel works at night, in the RIVALS style (2026-11-21, map lineup round 2, map 3).

Run: python tools/maps/foundry4_layout.py
Uses the checks in arena_layout.py and writes vault/02 Art/References/maps/foundry4/foundry4-layout.svg/png.

The old Foundry (pulled 2026-11-20 with the overnight maps) is a theme reference only. RIVALS Museum (read-only study,
vault/01 Design/Maps/Foundry4.md) gives the build language: one big readable hall with a raised gallery, chunky
mesh trims over plain Part masses, one colour family per material.

Mirror symmetry across the midline (z -> -z), not the usual 180-degree turn: the furnace (west) and the ladle (east)
sit on the midline and belong to both teams, so each team's half is the mirror image of the other.

The middle: the melt shop (x -48..46, z -32..32), a steel portal-frame hall open to the yards through big doors.
  - the blast furnace (the landmark) closes the west end of the midline, its cast house behind it;
  - the molten runner (8 wide, glowing) runs from the furnace's tap hole east along z = 0 to the ladle on its car
    (x 52). The runner is a kill zone: its glowing surface doesn't collide and the map's KillDepth (6) downs anyone
    who falls in. Its edges are walkable (a low kerb), two steel plate bridges cross it;
  - a catwalk at +12 along each long wall (stairs at both ends), joined across the runner by the overhead crane's
    bridge walkway (the gantry crane, +12, x -4): the high crossing;
  - cover on the cast floor: slab stacks, an ingot cart, coil pairs, the furnace's mudgun stand.
Each half (team A at +Z): the yard: the hot blast stove (west flank), a scrap bay, coil stacks, the ladle bay with
a spare ladle on a stand (east flank), the shunting loco, the pump house (spawn baffle), the spawn yard.
Heights: runner (kill), ground 0, catwalks / crane walkway +12. Roofs, stove and furnace out of reach.
Studs; X across, Z along, +Z = team A.
"""

from __future__ import annotations

import sys
from dataclasses import dataclass
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import arena_layout as L  # noqa: E402
from arena_layout import Box, Plan  # noqa: E402


def mirrored(b: Box) -> Box:
	return Box(b.name + "'", b.x, -b.z, b.sx, b.sz, b.h, -b.yaw, b.kind, b.base)


@dataclass
class MirrorPlan(Plan):
	@property
	def boxes(self):
		return self.center + self.half + [mirrored(b) for b in self.half]

	@property
	def spawns_b(self):
		return [(x, -z) for x, z in self.spawns_a]


FOUNDRY4 = MirrorPlan(
	name="foundry4",
	title="Foundry4",
	room=[(-75, 96), (75, 96), (75, -96), (-75, -96)],
	center=[
		# ---- the midline: the furnace (west), the runner, the ladle on its car (east)
		Box("Blast furnace", -58, 0, 24, 24, 60),
		Box("Cast house", -69, 0, 12, 34, 16),
		Box("Molten runner", -1, 0, 90, 8, 0, 0, "void"),
		Box("Plate bridge W", -24, 0, 8, 10, 0, 0, "bridge"),
		Box("Plate bridge E", 18, 0, 8, 10, 0, 0, "bridge"),
		Box("Ladle on its car", 52, 0, 12, 12, 13),
		Box("Ladle track", 52, 0, 6, 80, 0, 0, "decor"),
		# the slag skimmer gate straddling the runner: breaks the lines along the runner and the door-to-door diagonal
		Box("Skimmer gate", 5, 0, 3, 12, 9),
		# the gantry crane's bridge walkway: the high crossing between the two catwalks
		Box("Crane walkway", -4, 0, 4, 47, 12, 0, "deck", 11.4),
	],
	half=[
		# ---- the melt shop, this half (z 0..32). Long wall at z 32 with three doors; portal columns every 12.
		Box("Hall wall W", -39, 32, 18, 1.5, 30),
		Box("Hall wall M", -11, 32, 18, 1.5, 30),
		Box("Hall wall E", 20, 32, 20, 1.5, 30),
		Box("Hall wall end", 43, 32, 6, 1.5, 30),
		# catwalk +12 along the wall (z 23.5..28.5), stairs at both ends
		Box("Catwalk", -8, 26, 66, 5, 12, 0, "deck", 11.4),
		Box("Catwalk stair W", -51, 26, 20, 4, 12, 0, "ramp"),
		Box("Catwalk stair E", 35, 26, 20, 4, 12, 0, "ramp"),
		Box("Catwalk post", -28, 24, 1, 1, 11.4, 0, "pillar"),
		Box("Catwalk post", -12, 24, 1, 1, 11.4, 0, "pillar"),
		Box("Catwalk post", 16, 24, 1, 1, 11.4, 0, "pillar"),
		# cover on the cast floor
		Box("Mudgun stand", -36, 10, 6, 5, 8),
		Box("Slab stack", -20, 15, 8, 5, 3.2, 0, "low"),
		Box("Ingot cart", 2, 16, 11, 5, 8),
		Box("Coil pair", 30, 15, 6, 9, 8),
		# ---- the yard, this half (z 32..96)
		Box("Hot blast stove", -60, 48, 12, 12, 40),
		Box("Stove valve house", -62, 57.5, 9, 7, 9),
		Box("Scrap bin", -36, 46, 10, 5, 3.4, 0, "low"),
		Box("Scrap heap", -26, 60, 5, 9, 9),
		Box("Coil stack", -6, 48, 10, 6, 8),
		Box("Coil stack", 20, 54, 6, 10, 8),
		Box("Ladle stand", 63, 44, 11, 11, 13),
		Box("Cooling pallets", 50, 60, 8, 5, 3.2, 0, "low"),
		Box("Shunting loco", 36, 74, 7, 16, 11),
		Box("Pump house", 0, 72, 22, 8, 12, 0, "baffle"),
		Box("Oxygen tanks", -40, 76, 6, 6, 9, 0, "pillar"),
		Box("Barrel pile", -24, 78, 5, 4, 3.4, 0, "low"),
		Box("Barrier", 58, 84, 9, 2, 3.2, 0, "low"),
	],
	spawns_a=[(-12, 88), (0, 90), (12, 88), (-6, 84), (6, 84)],
	duel=False,
	notes=[
		"melt shop 94 x 64 in the middle: furnace (west) -> molten runner (kill) -> ladle (east); 2 plate bridges",
		"catwalks +12 on both long walls joined by the crane walkway over the runner; mirror symmetry (z -> -z)",
	],
)

if __name__ == "__main__":
	out_dir = Path(__file__).resolve().parents[2] / "vault/02 Art/References/maps/foundry4"
	out_dir.mkdir(parents=True, exist_ok=True)
	longest = L.report(FOUNDRY4)
	(out_dir / "foundry4-layout.svg").write_text(L.svg(FOUNDRY4, longest), encoding="utf-8", newline="\n")
	L.png(FOUNDRY4, longest, out_dir / "foundry4-layout.png")
	print(f"wrote {out_dir / 'foundry4-layout.png'}")
