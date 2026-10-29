"""Turn art-source/abilities/Exports/<Mod>.json into the compact build data the
Studio AbilityBuilder reads (tools/studio/abilities/BuildData/<Mod>.json). Copy
tools/studio/abilities/ to src/server/AbilityBuild/ (temporary, gitignored) so
Rojo syncs both into Studio while the props are built.

Usage: python tools/studio/make_ability_build_data.py [Mod ...]   (no names = every export)
"""

import json
import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
EXPORTS = os.path.join(ROOT, "art-source", "abilities", "Exports")
OUT = os.path.join(ROOT, "tools", "studio", "abilities", "BuildData")

# Roblox-space extras per Mod. HoldOffset matches the code's placeholders (src/client/Util/ModProps.luau): a thrown
# prop held in the hand sits this far from the grip so the hand doesn't cover it.
EXTRA = {
	"Packet": {"holdOffset": [0, 0.32, -0.12]},
	"LagField": {"holdOffset": [0, 0.34, -0.12]},
	"Molly": {"holdOffset": [0, 0.32, -0.12]},
	"Frost": {"holdOffset": [0, 0.32, -0.12]},
	# Recon: a handheld launcher held by its grip like the Patch Up (no HoldOffset). ReconDart: the fired sensor dart,
	# never held; "thrown" for the builder (no shadows, RightGrip = Handle = the tip, which is also the pivot).
	"Recon": {"kind": "handheld"},
	"ReconDart": {"kind": "thrown"},
	# HealOrb: pivot at the orb centre; it hovers above and a little in front of the open palm (no contact with the hand,
	# clear of the fingers even with the rings, ~0.23 studs out). Tune with the open-palm hold pose.
	"HealOrb": {"kind": "handheld", "holdOffset": [0, 0.4, -0.15]},
	# Stim: the beacon dropped at your feet (pivot = floor centre, like the Launch Pad). Coil_Yellow is Neon in a fixed
	# electric yellow (#FFD23F), NOT team-tinted: code that recolours Neon parts must skip it.
	"Stim": {"kind": "placed"},
	# Recall: the teleport anchor planted on the ground (pivot = floor centre, like the Stim). Core_Violet, Ring_Violet and
	# Strips_Violet are Neon in a fixed cool violet (#9B6BFF), NOT team-tinted: code that recolours Neon parts must skip
	# them (only Light_Energy, the small status light, takes the team colour).
	"Recall": {"kind": "placed"},
}
# Parts that are seen from both sides.
DOUBLE_SIDED = {"Panel_Energy", "Shockwave_Energy", "Dome_Energy", "Sphere_Energy", "ScanRing_Energy"}


def main(only=None):
	os.makedirs(OUT, exist_ok=True)
	assets = json.load(open(os.path.join(EXPORTS, "assets.json")))
	textures = json.load(open(os.path.join(EXPORTS, "textures.json")))
	decals = {t["part"]: t["decalId"] for t in textures.values()}
	for name in sorted(os.listdir(EXPORTS)):
		if not name.endswith(".json") or name in ("assets.json", "textures.json"):
			continue
		mod = name[:-5]
		if only and mod not in only:
			continue
		data = json.load(open(os.path.join(EXPORTS, name)))
		parts = []
		for p in data["parts"]:
			q = {k: p[k] for k in ("name", "look", "energy", "tris", "center", "size")}
			if p["name"] in DOUBLE_SIDED:
				q["doubleSided"] = True
			key = mod + "/" + p["name"]
			if key in decals:
				q["decal"] = decals[key]
			parts.append(q)
		out = {
			"mod": mod,
			"kind": data["props"].get("kind", "thrown"),
			"assetId": assets.get(mod, {}).get("assetId", 0),
			"tris": data["tris"],
			"parts": parts,
			"locators": data["locators"],
		}
		out.update(EXTRA.get(mod, {}))
		with open(os.path.join(OUT, name), "w") as f:
			json.dump(out, f, separators=(",", ":"))
	print("ok")


if __name__ == "__main__":
	main(set(sys.argv[1:]) or None)
