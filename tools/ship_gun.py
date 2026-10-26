"""Ship a scripted gun after its model is built: bake, animate, export, upload, record, check sheet.

    python tools/ship_gun.py <Id> ship [render_dir]
        bake + clips + PBR check renders (tools/blender/finish_gun.py, headless), export (export_weapons.py),
        upload the model and its 4 texture maps (Open Cloud, key in ROBLOX_ASSETS_KEY) and record the decal ids
        in art-source/weapons/Exports/textures.json. Prints the decal ids.
    python tools/ship_gun.py <Id> images <color> <normal> <roughness> <metalness>
        records the image ids behind those decals (resolve them in Studio: InsertService:LoadAsset(decal) ->
        Decal.Texture), then writes the build data and the animation module for this gun only.
    python tools/ship_gun.py <Id> sheet <render_dir> <vandal_34.png> <vandal_side.png> [notes]
        writes vault/02 Art/References/<id>-blender-check.jpg (this gun beside the Vandal).

Steps the model build itself (tools/blender/build_<id>.py in the Blender UI) and the Studio install are not here.
"""

import json
import os
import subprocess
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
BLENDER = os.environ.get("BLENDER_EXE", r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe")
GROUP = "11116787"
EXPORTS = os.path.join(ROOT, "art-source", "weapons", "Exports")
TEXTURES = os.path.join(EXPORTS, "textures.json")
MAPS = ("Color", "Normal", "Roughness", "Metalness")


def sh(args, **kw):
	print(">", " ".join(str(a) for a in args), flush=True)
	return subprocess.run(args, cwd=ROOT, check=True, text=True, capture_output=True, **kw).stdout


def textures():
	return json.load(open(TEXTURES)) if os.path.exists(TEXTURES) else {}


def ship(gun, render_dir=None):
	blend = os.path.join("art-source", "weapons", gun + ".blend")
	out = sh([BLENDER, "--background", blend, "--python", "tools/blender/finish_gun.py", "--", gun] + ([render_dir] if render_dir else []))
	print([l for l in out.splitlines() if l.startswith("FINISH_GUN")])
	out = sh([BLENDER, "--background", blend, "--python", "tools/blender/export_weapons.py", "--", gun])
	data = json.load(open(os.path.join(EXPORTS, gun + ".json")))
	print("export:", len(data["parts"]), "parts,", sum(p["tris"] for p in data["parts"]), "tris; clips",
		{k: sorted(a["bones"]) for k, a in data["animations"].items()})
	print(sh([sys.executable, "-I", "tools/opencloud/upload_models.py", "--group", GROUP, gun]).strip())
	decals = {}
	for m in MAPS:
		png = os.path.join("art-source", "weapons", "Textures", "%s_%s.png" % (gun, m))
		decals[m] = int(sh([sys.executable, "-I", "tools/opencloud/upload_asset.py", "--group", GROUP, "--type", "Decal", png, "GG %s %s" % (gun, m)]).strip().splitlines()[-1])
	t = textures()
	t[gun] = {"decals": decals}
	json.dump(t, open(TEXTURES, "w"), indent=1)
	print("DECALS", json.dumps(decals))


def images(gun, color, normal, rough, metal):
	t = textures()
	entry = t.get(gun, {})
	entry.update({"ColorMap": int(color), "NormalMap": int(normal), "RoughnessMap": int(rough), "MetalnessMap": int(metal)})
	# Keep the image ids first, like the earlier entries.
	t[gun] = {k: entry[k] for k in ("ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap", "decals") if k in entry}
	json.dump(t, open(TEXTURES, "w"), indent=1)
	print(sh([sys.executable, "tools/studio/make_build_data.py", gun]).strip())
	print(sh([sys.executable, "tools/make_weapon_anims.py", gun]).strip())


def sheet(gun, render_dir, vandal_34, vandal_side, notes=""):
	from PIL import Image, ImageDraw

	W = 1500

	def load(path, box):
		return Image.open(path).convert("RGB").crop(box)

	def fit(im, w=W):
		return im.resize((w, int(im.height * w / im.width)))

	r = lambda cam: os.path.join(render_dir, "%s_%s.png" % (gun, cam))
	v34 = fit(load(vandal_34, (0, 230, 1600, 800)), 750)
	g34 = fit(load(r("Cam_34"), (0, 230, 1600, 800)), 750)
	pair = Image.new("RGB", (W, v34.height), (14, 16, 20))
	pair.paste(v34, (0, 0))
	pair.paste(g34, (750, 0))
	rows = [("Vandal (left) and %s (right), same camera" % gun, pair),
		("Side: Vandal (orthographic, 4.3-stud frame)", fit(load(vandal_side, (40, 330, 1560, 720)))),
		("Side: %s (same frame unless the gun is longer than 4 studs, then widened to fit)" % gun, fit(load(r("Cam_Side"), (40, 330, 1560, 720))))]
	for cam, label in (("Cam_Close", "close-up, left side (first-person side), baked PBR textures"),):
		if os.path.exists(r(cam)):
			rows.append(("%s %s" % (gun, label), fit(load(r(cam), (0, 0, 1600, 1000)))))
	H = sum(im.height + 40 for _, im in rows) + (40 if notes else 0)
	out = Image.new("RGB", (W, H), (14, 16, 20))
	d = ImageDraw.Draw(out)
	y = 0
	if notes:
		d.text((12, 12), notes, fill=(220, 225, 235))
		y = 40
	for label, im in rows:
		d.text((12, y + 12), label, fill=(220, 225, 235))
		y += 40
		out.paste(im, (0, y))
		y += im.height
	path = os.path.join(ROOT, "vault", "02 Art", "References", "%s-blender-check.jpg" % gun.lower())
	out.save(path, quality=88)
	print("sheet", path, out.size)


if __name__ == "__main__":
	gun, cmd, *rest = sys.argv[1:]
	{"ship": ship, "images": images, "sheet": sheet}[cmd](gun, *rest)
