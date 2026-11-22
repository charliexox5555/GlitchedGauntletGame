#!/usr/bin/env python3
"""CanyonOutpost (regular, 1v1-2v2): a sun-baked mining outpost in a red canyon, RIVALS style (2026-11-21, map lineup
round 2, map 4, the last new map for the release).

Run: python tools/maps/canyon_layout.py
Uses the checks in arena_layout.py and writes vault/02 Art/References/maps/canyon/canyon-layout.svg/png.

RIVALS study (read-only, vault/01 Design/Maps/CanyonOutpost.md): Westown's canyon is RIVALS rock + sand-cap mesh
pairs (taken as R_Mesa1-3); its timber is Wood01a / WoodSiding_01a / WoodPlank_01b in a few browns.

Mirror symmetry across the midline (z -> -z), like Foundry4: the mine (west) and the ore tipple (east) sit on the
midline and belong to both teams.

The midline: the ore track runs at ground level from the mine portal in the west cliff (x -68) east to the tipple
(x 52). Three ore carts stand on it (low cover). The water tower (the landmark) straddles the track in the middle:
its four legs stand round the track, the tank is far out of reach. The tipple is a timber tower over the end of the
track with a deck at +10 and an ore bin above it; walkways at +10 join it to each team's loading dock.
Each half (team A at +Z): the trading post (porch facing the middle), the loading dock deck at +10 on the east
(stair up from the middle), a powder shed and a rock shelf (+7, ramp) on the west under the cliff, a pit-prop stack, a
water trough, a freight wagon and a barricade on the east flank, the stores shed (spawn baffle), the spawn yard
against the canyon's end wall.
Heights: ground 0, rock shelves +7, porches +1, dock decks, walkways and the tipple deck +10.
Studs; X across, Z along, +Z = team A.
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import arena_layout as L  # noqa: E402
from arena_layout import Box  # noqa: E402
from foundry4_layout import MirrorPlan  # noqa: E402

CANYON = MirrorPlan(
	name="canyon",
	title="CanyonOutpost",
	room=[(-70, 96), (70, 96), (70, -96), (-70, -96)],
	center=[
		# ---- the midline: mine portal (west) -> ore track -> water tower over the track -> tipple (east)
		Box("Mine portal", -68, 0, 4, 22, 17),
		Box("Ore track", -11, 0, 132, 5, 0, 0, "decor"),
		Box("Ore cart W", -42, 0, 8, 5, 3.5, 0, "low"),
		Box("Ore cart M", -20, 0, 8, 5, 3.5, 0, "low"),
		Box("Ore cart E", 20, 0, 8, 5, 3.5, 0, "low"),
		# the water tower's four legs round the track; the tank (+22..+36) is out of reach
		Box("Tower leg", -7, 7, 1.6, 1.6, 22, 0, "pillar"),
		Box("Tower leg", 7, 7, 1.6, 1.6, 22, 0, "pillar"),
		Box("Tower leg", -7, -7, 1.6, 1.6, 22, 0, "pillar"),
		Box("Tower leg", 7, -7, 1.6, 1.6, 22, 0, "pillar"),
		# the tipple: deck +10 on posts (you walk under it), the ore bin above, the chute over the track's end
		Box("Tipple deck", 54.4, 0, 16, 20.8, 10, 0, "deck", 9.4),
		Box("Tipple bin", 57, 0, 8, 10, 23, 0, "full", 10),
		Box("Tipple post", 47, 9.6, 1.2, 1.2, 9.4, 0, "pillar"),
		Box("Tipple post", 47, -9.6, 1.2, 1.2, 9.4, 0, "pillar"),
		Box("Tipple chute", 55.5, 0, 3, 3, 9.7, 0, "full", 5.6),
		Box("Track bumper", 55, 0, 3, 5, 3, 0, "low"),
	],
	half=[
		# ---- the trading post (porch faces the middle)
		Box("Trading post", -14, 54, 26, 14, 16),
		Box("Porch", -14, 45, 26, 4, 1, 0, "plinth"),
		Box("Water trough", -14, 36, 17, 4, 3.4, 0, "low"),
		# ---- the middle of the half: the pump house that fills the tower, the assayer's hut, the timber stack (pit props)
		Box("Pump house", 4, 18, 10, 6, 9),
		Box("Assay hut", 24, 24, 9, 7, 10),
		Box("Timber stack", -38, 46, 7, 14, 9),
		# ---- the loading dock (east): deck +10, stair up from the middle, walkway to the tipple
		Box("Dock deck", 50, 38, 24, 16, 10, 0, "deck", 9.4),
		Box("Jib crane", 60.5, 44.5, 1.2, 1.2, 18, 0, "pillar", 10),
		Box("Dock stair", 28, 42, 20, 5, 10, 0, "ramp"),
		Box("Walkway", 56, 20.2, 5, 19.6, 10, 0, "deck", 9.4),
		Box("Dock post", 38.6, 30.6, 1.2, 1.2, 9.4, 0, "pillar"),
		Box("Dock post", 50, 30.6, 1.2, 1.2, 9.4, 0, "pillar"),
		Box("Dock post", 61.4, 30.6, 1.2, 1.2, 9.4, 0, "pillar"),
		Box("Dock post", 38.6, 45.4, 1.2, 1.2, 9.4, 0, "pillar"),
		Box("Dock post", 50, 45.4, 1.2, 1.2, 9.4, 0, "pillar"),
		Box("Dock post", 61.4, 45.4, 1.2, 1.2, 9.4, 0, "pillar"),
		Box("Freight wagon", 50, 57, 15, 7.4, 8),
		Box("Timber stack", 28, 66, 14, 5, 9),
		# ---- the west, under the cliff: powder shed, rock shelf +7 (ramp, or climb), pit props
		Box("Powder shed", -48, 28, 10, 8, 10),
		Box("Rock shelf", -60, 56, 20, 22, 7, 0, "deck"),
		Box("Shelf steps", -42, 62, 16, 6, 7, 0, "ramp"),
		Box("Pit props", -28, 20, 10, 4, 3.4, 0, "low"),
		Box("Ore bin", -24, 34, 6, 6, 8),
		Box("Barrels", -38, 74, 5, 5, 3.5, 0, "low"),
		# ---- the spawn end
		Box("Stores shed", 0, 75, 24, 8, 12, 0, "baffle"),
		Box("Crates", 22, 80, 6, 4, 4, 0, "low"),
	],
	spawns_a=[(-12, 88), (0, 90), (12, 88), (-6, 85), (6, 85)],
	duel=False,
	notes=[
		"canyon floor 140 x 192: mine portal (west) -> ore track with 3 carts -> water tower over the track -> tipple (east)",
		"tipple deck +10 joined to each team's dock deck by a walkway; rock shelves +7 under the west cliff; mirror (z -> -z)",
	],
)

if __name__ == "__main__":
	out_dir = Path(__file__).resolve().parents[2] / "vault/02 Art/References/maps/canyon"
	out_dir.mkdir(parents=True, exist_ok=True)
	longest = L.report(CANYON)
	(out_dir / "canyon-layout.svg").write_text(L.svg(CANYON, longest), encoding="utf-8", newline="\n")
	L.png(CANYON, longest, out_dir / "canyon-layout.png")
	print(f"wrote {out_dir / 'canyon-layout.png'}")
