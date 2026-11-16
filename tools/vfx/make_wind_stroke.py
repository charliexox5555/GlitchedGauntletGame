"""The wind stroke: the one shape behind the Dash and Updraft screen effects (numpy + Pillow, no Blender).

    python tools/vfx/make_wind_stroke.py [--preview out.png]

Writes art-source/abilities/Rework/v03/Textures/Wind_Stroke.png (vault/02 Art/Ability VFX Direction.md, "Wind"):
a long thin wedge pointed at both ends, flat white on transparent with hard edges. The head is on the LEFT and
short; the tail runs to the right and is about four times longer. The game stretches it onto an ImageLabel (any
length and thickness), turns it along the move and tints it (Config/Mods WIND_FEEL), so one image is every stroke.
Upload: python tools/opencloud/upload_asset.py --group 11116787 --type Decal <png> "GG VFX Wind_Stroke"
(a Decal id; the Image id behind it goes in Config/VfxTextures WIND_STROKE).
"""

import os
import sys

from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art-source", "abilities", "Rework", "v03", "Textures")
W, H = 1024, 128
SS = 4  # supersampling: the edges stay hard, only the last pixel is smoothed
PAD = 3  # transparent pixels round the shape, so a stretched edge never smears
SHOULDER = 0.2  # where the wedge is widest, from the head (0) to the tail tip (1)


def stroke():
	w, h = W * SS, H * SS
	pad = PAD * SS
	mid = h / 2
	shoulder = pad + (w - 2 * pad) * SHOULDER
	mask = Image.new("L", (w, h), 0)
	ImageDraw.Draw(mask).polygon(
		[(pad, mid), (shoulder, pad), (w - pad, mid), (shoulder, h - pad)],
		fill=255,
	)
	alpha = mask.resize((W, H), Image.BOX)
	img = Image.new("RGBA", (W, H), (255, 255, 255, 0))
	img.putalpha(alpha)
	return img


def main():
	os.makedirs(OUT, exist_ok=True)
	img = stroke()
	path = os.path.join(OUT, "Wind_Stroke.png")
	img.save(path)
	if "--preview" in sys.argv:
		# Three sizes as the game draws them, on a dark and a pale band.
		sheet = Image.new("RGBA", (900, 300), (24, 28, 36, 255))
		ImageDraw.Draw(sheet).rectangle([0, 150, 900, 300], fill=(150, 160, 170, 255))
		tint = Image.new("RGBA", img.size, (230, 244, 255, 255))
		tint.putalpha(img.getchannel("A"))
		for band in (0, 150):
			for i, (length, thick) in enumerate(((560, 26), (400, 18), (250, 12))):
				s = tint.resize((length, thick), Image.LANCZOS)
				sheet.alpha_composite(s, (30 + i * 40, band + 22 + i * 42))
		sheet.convert("RGB").save(sys.argv[sys.argv.index("--preview") + 1])
	print(path)


if __name__ == "__main__":
	main()
