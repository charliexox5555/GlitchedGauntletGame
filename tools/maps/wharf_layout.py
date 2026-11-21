#!/usr/bin/env python3
"""Wharf (regular, 1v1-2v2): the layout, learned from RIVALS Docks' flow (2026-11-20).

Run: python tools/maps/wharf_layout.py
Uses the checks in arena_layout.py (spawn gap, sightlines, lanes, cover, pinches, jumps, slide runs, first sight)
and writes vault/02 Art/References/maps/wharf/wharf-layout.svg/png.

Docks' flow at duel size (measurements: vault/01 Design/Maps/Wharf.md): a concrete pier with water on three
sides and the container yard on the fourth; two long sheds, staggered, split it into three lanes (yard /
mid / quay) that only meet around the shed ends; containers and crates break every lane; each team has a
harbour office in its corner with a +12 roof deck (outside stair + crate-container steps); a sunken landing
in each outer lane is the low ground. The quay crane (the landmark) stands off the pier to the east.
Studs; X across (east +), Z along, +Z = team A. 180-degree rotational symmetry. 5-stud module.
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import arena_layout as L  # noqa: E402
from arena_layout import Box, Plan  # noqa: E402

C = 10.0  # container width and height (port kit)


def container(name, x, z, along_z=True, length=30.0, h=C, base=0.0, kind="full"):
	return Box(name, x, z, C if along_z else length, length if along_z else C, h, 0, kind, base)


WHARF = Plan(
	name="wharf",
	title="Wharf",
	room=[(-65, 92.5), (65, 92.5), (65, -92.5), (-65, -92.5)],
	center=[
		container("Mid container", 0, 0, along_z=True, length=20),
	],
	half=[
		# the sheds (one a side, staggered like Docks' warehouses): walls 14, gable roof to 21
		Box("Shed", 27.5, 20, 20, 60, 14),
		# loading dock along the shed's quay side: +3.5, shoot-over, walkable
		Box("Shed dock", 40, 22.5, 5, 35, 3.5, 0, "plinth"),
		Box("Dock crate stack", 40, 12.5, 5, 5, 12),
		# harbour office in the yard corner, flat roof deck +12 with a parapet
		Box("Office", -52.5, 82.5, 25, 20, 12, 0, "deck"),
		Box("Office stair", -37.5, 80, 5, 25, 12, 0, "ramp"),
		container("Office container", -55, 67.5, along_z=False, length=20, kind="deck"),
		Box("Office step high", -42.5, 62.5, 5, 5, 7, 0, "deck"),
		Box("Office step low", -42.5, 57.5, 5, 5, 3.5, 0, "plinth"),
		# spawn baffle: a crosswise container in front of the markers
		container("Spawn container", 5, 62.5, along_z=False, length=20),
		# mid lane: a container with a second one stacked on its yard end; low crates
		container("Mid cross", -5, 37.5, along_z=False, length=20),
		container("Mid stack", -7.5, 37.5, along_z=False, length=15, h=20, base=10),
		Box("Mid crates", 0, 20, 10, 5, 3.5, 0, "low"),
		Box("Mid crate stack", -15, 27.5, 5, 10, 10),
		# yard lane: a long container along the lane, a crate pair, the yard edge stacks (bounds)
		container("Yard container", -40, 37.5, along_z=True, length=30),
		Box("Yard crates", -22.5, 57.5, 10, 5, 3.5, 0, "low"),
		container("Yard reefer", -57.5, 12.5, along_z=False, length=15),
		# quay lane (beside the shed dock): bollard line, a reefer container, the sunken landing
		container("Quay container", 50, 62.5, along_z=True, length=20),
		container("Quay box", 52.5, 27.5, along_z=True, length=15),
		Box("Landing", 60, 0, 10, 15, -3.0, 0, "plinth"),
	],
	spawns_a=[(-2.5, 80), (7.5, 80), (-2.5, 75), (7.5, 75)],
	duel=True,
	notes=[
		"water east and at both ends (bounds at the edge rail), the container yard stacks on the west edge",
		"landing: a 3-deep step-down in each outer lane (steps at both ends)",
		"office deck +12: outside stair, or crate 3.5 -> 7 -> container 10 -> deck 12",
	],
)

if __name__ == "__main__":
	out_dir = Path(__file__).resolve().parents[2] / "vault/02 Art/References/maps/wharf"
	out_dir.mkdir(parents=True, exist_ok=True)
	longest = L.report(WHARF)
	(out_dir / "wharf-layout.svg").write_text(L.svg(WHARF, longest), encoding="utf-8")
	L.png(WHARF, longest, out_dir / "wharf-layout.png")
	print(f"wrote {out_dir / 'wharf-layout.png'}")
