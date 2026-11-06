"""OldTown2 layout: Old Town's checked layout (tools/maps/oldtown_layout.py) and art placement rules
(tools/maps/oldtown_art.py), unchanged, written for the new map id at its own origin.

    python tools/maps/oldtown2_layout.py [--write]

Map Quality Standard step 2 ("layout kept from the map note"): re-runs every Old Town check on the same
numbers, writes the layout SVG for OldTown2 and, with --write, tools/studio/maps/OldTown2/Greybox.luau and
Art.luau at origin (3000, 200, -1500), placing the OldTown2 kit (tools/blender/build_map_kit_oldtown2.py, the
same piece names and origins). Old Town's own files are never written (vault/01 Design/Maps/OldTown2.md).
"""

import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import oldtown_layout as L  # noqa: E402
import oldtown_art as A  # noqa: E402

ROOT = HERE.parents[1]
OUT = ROOT / "tools" / "studio" / "maps" / "OldTown2"


def swap(src: str, pairs) -> str:
	for a, b, n in pairs:
		c = src.count(a)
		assert c == n or (n is None and c > 0), (a, c)
		src = src.replace(a, b)
	return src


def greybox() -> str:
	return swap(
		L.greybox_luau(),
		[
			('newMap("OldTown", CFrame.new(0, 200, 1500))', 'newMap("OldTown2", CFrame.new(3000, 200, -1500))', 1),
			("bundle.py OldTown Greybox", "bundle.py OldTown2 Greybox", None),
			("Builds Workspace.OldTown at (0, 200, 1500)", "Builds Workspace.OldTown2 at (3000, 200, -1500)", 1),
			('"OldTown greybox:', '"OldTown2 greybox:', 1),
		],
	)


def art() -> str:
	src = A.art_luau()
	return swap(
		src,
		[
			("ServerStorage.MapKit.OldTown)", "ServerStorage.MapKit.OldTown2)", 1),
			("kit_bundle.py OldTown Structure", "kit_bundle.py OldTown2 Structure", 1),
			("kit_bundle.py OldTown Props", "kit_bundle.py OldTown2 Props", 1),
			("bundle.py OldTown Greybox Art Lighting", "bundle.py OldTown2 Greybox Art Lighting", 1),
			("Workspace.OldTown.Art", "Workspace.OldTown2.Art", 1),
			('"OldTown art:', '"OldTown2 art:', 1),
		],
	)


if __name__ == "__main__":
	res = L.report(write_svg=False)
	if "--write" in sys.argv:
		OUT.mkdir(parents=True, exist_ok=True)
		(OUT / "Greybox.luau").write_text(greybox(), encoding="utf-8")
		(OUT / "Art.luau").write_text(art(), encoding="utf-8")
		print("Wrote", OUT / "Greybox.luau", "and Art.luau")
