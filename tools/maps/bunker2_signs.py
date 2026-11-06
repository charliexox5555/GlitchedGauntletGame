#!/usr/bin/env python3
"""Bunker2 sign art: room names rendered from a real font (no part-built text; Map Quality Standard -> Text and signage).

    python tools/maps/bunker2_signs.py            render the PNGs (art-source/maps/Bunker2/signs/)
    python tools/maps/bunker2_signs.py --upload   ...and upload them as Decals (records the ids in signs.json)

Bahnschrift (Windows' DIN-style face) Bold Condensed, in the palette's sign ink on a transparent ground, so the plate's
own colour (role Sign) shows behind it. Image aspect = the plate face it goes on: door plates 5.8 x 1.51, the blast
door's head plate 7.2 x 0.8, the spawn panels 6.0 x 5.8. Studio resolves each Decal id to its image id (the install
step writes "image" into signs.json; tools/maps/bunker2_art.py then writes the SIGN table into Art.luau).
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

import bunker2_style as S

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art-source/maps/Bunker2/signs"
RECORD = ROOT / "art-source/maps/Bunker2/signs.json"
FONT = "C:/Windows/Fonts/bahnschrift.ttf"

DOORS = ["CONTROL", "CORRIDOR", "GALLERY", "LOCKERS", "OVERLOOK", "RING", "SPAWN", "SUNWELL", "VESTIBULE", "PUMP"]


def font(px: int) -> ImageFont.FreeTypeFont:
	f = ImageFont.truetype(FONT, px)
	try:
		f.set_variation_by_name("Bold Condensed")
	except Exception:
		f.set_variation_by_name("Bold")
	return f


def ink(alpha: int = 255) -> tuple[int, int, int, int]:
	r, g, b = S.hex_rgb(S.SIGN_INK)
	return r, g, b, alpha


def fit(draw: ImageDraw.ImageDraw, text: str, max_w: int, max_h: int, spacing: float = 0.08):
	px = max_h
	while px > 8:
		f = font(px)
		w = sum(draw.textlength(c, font=f) for c in text) + spacing * px * (len(text) - 1)
		bb = f.getbbox("H")
		if w <= max_w and bb[3] - bb[1] <= max_h:
			return f, w, spacing * px
		px -= 2
	return font(8), 0, 0


def spaced(draw, text, cx, cy, f, total_w, gap, fill):
	x = cx - total_w / 2
	bb = f.getbbox("H")
	y = cy - (bb[1] + bb[3]) / 2
	for c in text:
		draw.text((x, y), c, font=f, fill=fill)
		x += draw.textlength(c, font=f) + gap


def door(text: str) -> Image.Image:
	w, h = 1024, 267
	im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
	d = ImageDraw.Draw(im)
	f, tw, gap = fit(d, text, int(w * 0.8), int(h * 0.5))
	spaced(d, text, w / 2, h / 2, f, tw, gap, ink())
	for y in (int(h * 0.12), int(h * 0.88) - 6):  # two thin rules, like stencilled plate borders
		d.rectangle((int(w * 0.06), y, int(w * 0.94), y + 6), fill=ink(170))
	return im


def blast(text: str) -> Image.Image:
	w, h = 1152, 128
	im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
	d = ImageDraw.Draw(im)
	f, tw, gap = fit(d, text, int(w * 0.7), int(h * 0.62), spacing=0.25)
	spaced(d, text, w / 2, h / 2, f, tw, gap, ink())
	return im


def spawn(letter: str) -> Image.Image:
	w, h = 512, 495
	im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
	d = ImageDraw.Draw(im)
	f, tw, gap = fit(d, letter, int(w * 0.6), int(h * 0.55))
	spaced(d, letter, w / 2, h * 0.4, f, tw, gap, ink())
	f2, tw2, gap2 = fit(d, "SPAWN", int(w * 0.62), int(h * 0.12), spacing=0.3)
	spaced(d, "SPAWN", w / 2, h * 0.82, f2, tw2, gap2, ink(220))
	d.rectangle((int(w * 0.2), int(h * 0.69), int(w * 0.8), int(h * 0.69) + 5), fill=ink(170))
	return im


def render() -> dict[str, Path]:
	OUT.mkdir(parents=True, exist_ok=True)
	files = {}
	for t in DOORS:
		files[t] = OUT / f"door_{t}.png"
		door(t).save(files[t])
	for side in ("A", "B"):
		files[f"GALLERY {side}"] = OUT / f"blast_{side}.png"
		blast(f"GALLERY {side}").save(files[f"GALLERY {side}"])
		files[f"SPAWN {side}"] = OUT / f"spawn_{side}.png"
		spawn(side).save(files[f"SPAWN {side}"])
	return files


if __name__ == "__main__":
	files = render()
	rec = json.loads(RECORD.read_text(encoding="utf-8")) if RECORD.exists() else {}
	if "--upload" in sys.argv:
		for name, path in files.items():
			if rec.get(name, {}).get("decal"):
				continue
			out = subprocess.run([sys.executable, str(ROOT / "tools/opencloud/upload_asset.py"), "--group", "11116787", "--type", "Decal",
								  str(path), f"GG Bunk2 Sign {name}"], capture_output=True, text=True)
			ids = [t for t in out.stdout.split() if t.isdigit()]
			rec[name] = {"file": str(path.relative_to(ROOT)).replace("\\", "/"), "decal": ids[-1] if ids else "", "image": ""}
			print(name, rec[name]["decal"], out.stderr[-200:] if not ids else "")
		RECORD.write_text(json.dumps(rec, indent=1), encoding="utf-8")
	print(f"{len(files)} signs in {OUT}")
