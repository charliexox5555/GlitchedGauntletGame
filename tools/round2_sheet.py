"""Round 2 before/after check sheet: vault/02 Art/References/round2/<id>.jpg.

    python tools/round2_sheet.py <Id> <render_dir> [notes]

Before = the gun's old check sheet (vault/02 Art/References/<id>-blender-check.jpg, written by ship_gun.py sheet);
after = the fresh PBR renders from tools/ship_gun.py <Id> ship <render_dir>.
"""

import os
import sys

from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
REFS = os.path.join(ROOT, "vault", "02 Art", "References")


def main(gun, render_dir, notes=""):
	W = 1500
	old = Image.open(os.path.join(REFS, "%s-blender-check.jpg" % gun.lower())).convert("RGB")
	r = lambda cam: Image.open(os.path.join(render_dir, "%s_%s.png" % (gun, cam))).convert("RGB")
	fit = lambda im, w: im.resize((w, int(im.height * w / im.width)))
	# Old sheet layout (ship_gun.sheet): label 40 + 3/4 pair 267, label 40 + Vandal side 385, label 40 + gun side 385.
	off = max(0, old.height - 2134)  # a notes line on the old sheet shifts every row down 40
	before34 = old.crop((750, 40 + off, 1500, 307 + off))
	before_side = old.crop((0, 772 + off, 1500, 1157 + off))
	after34 = fit(r("Cam_34").crop((0, 230, 1600, 800)), 750)
	after_side = fit(r("Cam_Side").crop((40, 330, 1560, 720)), W)
	fp = fit(r("Cam_FP"), 750)
	close = fit(r("Cam_Close"), 750)
	pair = Image.new("RGB", (W, 267), (14, 16, 20))
	pair.paste(before34, (0, 0))
	pair.paste(after34, (750, 0))
	views = Image.new("RGB", (W, fp.height), (14, 16, 20))
	views.paste(fp, (0, 0))
	views.paste(close, (750, 0))
	rows = [("%s round 2: before (left) / after (right), same camera" % gun, pair),
		("Side before", before_side), ("Side after", after_side), ("After: first-person camera (left), close-up (right)", views)]
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
	os.makedirs(os.path.join(REFS, "round2"), exist_ok=True)
	path = os.path.join(REFS, "round2", "%s.jpg" % gun.lower())
	out.save(path, quality=86)
	print("sheet", path, out.size)


if __name__ == "__main__":
	main(*sys.argv[1:])
