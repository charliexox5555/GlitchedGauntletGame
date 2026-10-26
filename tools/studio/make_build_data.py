"""Turn art-source/weapons/Exports/<Id>.json into the compact build data the
Studio WeaponBuilder reads (tools/studio/rojo/BuildData/<Id>.json; Rojo syncs
it into ServerStorage.WeaponBuild while guns are being built).

Usage: python tools/studio/make_build_data.py [Id ...]   (no ids = every export in Exports/)
"""

import json
import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
EXPORTS = os.path.join(ROOT, "art-source", "weapons", "Exports")
OUT = os.path.join(ROOT, "tools", "studio", "rojo", "BuildData")
KEEP = ("id", "gun", "bones", "parts", "locators", "options_visible")


def main(only=None):
	os.makedirs(OUT, exist_ok=True)
	assets = json.load(open(os.path.join(EXPORTS, "assets.json")))
	# Baked SurfaceAppearance maps per gun (image ids), see tools/blender/bake_textures.py.
	tex_path = os.path.join(EXPORTS, "textures.json")
	textures = json.load(open(tex_path)) if os.path.exists(tex_path) else {}
	for name in sorted(os.listdir(EXPORTS)):
		if not name.endswith(".json") or name in ("assets.json", "textures.json"):
			continue
		if only and name[:-5] not in only:
			continue
		data = json.load(open(os.path.join(EXPORTS, name)))
		out = {k: data[k] for k in KEEP}
		out["assetId"] = assets.get(data["id"], {}).get("assetId", 0)
		if data["id"] in textures:
			out["surface"] = textures[data["id"]]
		if "att_positions" in data["props"]:
			out["att_positions"] = data["props"]["att_positions"]
		with open(os.path.join(OUT, name), "w") as f:
			json.dump(out, f, separators=(",", ":"))
	print("ok")


if __name__ == "__main__":
	main(set(sys.argv[1:]) or None)
