"""Prepare ChatGPT-made UI art for the game (vault/02 Art/UI Art Brief (ChatGPT).md).

    python tools/ui_chatgpt.py

Reads art-source/ui/chatgpt/icons/<Id>.png and cards/<Id>.png and writes game-ready
copies to art-source/ui/chatgpt/out/:
- icons: a pure white glyph on transparency (alpha from the image's alpha, or from
  its brightness when it has none), trimmed and fitted into 256 px with padding;
- cards: cropped to the draft card's art area (380 x 300 design px, saved 2x at
  760 x 600) with the card's cut top-left corner masked off and the bottom half
  fading out, so it sits on the card without hard edges.
Then upload the out/ files with tools/opencloud/upload_asset.py.
"""

import os

from PIL import Image, ImageChops, ImageDraw, ImageOps

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SRC = os.path.join(ROOT, "art-source", "ui", "chatgpt")
OUT = os.path.join(SRC, "out")
IDS = ["Dash", "Updraft", "Molly", "Firewall", "Frost", "Recon", "HealOrb", "Stim", "Recall"]
ICON = 256
ICON_PAD = 20
CARD = (760, 600)
CUT = 40  # the card's 20 px corner at 2x


def icon(path, dest):
	im = Image.open(path).convert("RGBA")
	alpha = im.getchannel("A")
	if alpha.getextrema()[0] == 255:
		# No transparency: the glyph is whatever differs from the corner colour.
		grey = im.convert("L")
		corner = grey.getpixel((0, 0))
		alpha = ImageChops.difference(grey, Image.new("L", grey.size, corner))
		alpha = alpha.point(lambda v: min(255, v * 2))
	box = alpha.getbbox()
	if not box:
		print("empty icon", path)
		return
	alpha = alpha.crop(box)
	side = ICON - ICON_PAD * 2
	alpha = ImageOps.contain(alpha, (side, side), Image.LANCZOS)
	out = Image.new("RGBA", (ICON, ICON), (255, 255, 255, 0))
	glyph = Image.new("RGBA", alpha.size, (255, 255, 255, 255))
	glyph.putalpha(alpha)
	out.alpha_composite(glyph, ((ICON - alpha.width) // 2, (ICON - alpha.height) // 2))
	out.save(dest)


def card(path, dest):
	im = Image.open(path).convert("RGBA")
	im = ImageOps.fit(im, CARD, Image.LANCZOS, centering=(0.5, 0.4))
	mask = Image.new("L", CARD, 255)
	d = ImageDraw.Draw(mask)
	d.polygon([(0, 0), (CUT, 0), (0, CUT)], fill=0)
	w, h = CARD
	start = int(h * 0.5)
	for y in range(start, h):
		k = 1 - (y - start) / (h - start)
		d.line([(0, y), (w, y)], fill=int(255 * k * k))
	d.polygon([(0, 0), (CUT, 0), (0, CUT)], fill=0)
	im.putalpha(ImageChops.multiply(im.getchannel("A"), mask))
	im.save(dest)


def main():
	for kind, fn in (("icons", icon), ("cards", card)):
		os.makedirs(os.path.join(OUT, kind), exist_ok=True)
		done = []
		for name in IDS:
			src = os.path.join(SRC, kind, name + ".png")
			if os.path.exists(src):
				fn(src, os.path.join(OUT, kind, name + ".png"))
				done.append(name)
		print(kind, len(done), done)


if __name__ == "__main__":
	main()
