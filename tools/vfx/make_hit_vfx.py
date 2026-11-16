"""Hit feedback textures (vault/05 Production/Playtests/2026-11-13 Hit Feedback Pass.md §11).

    python -I tools/vfx/make_hit_vfx.py

Writes to art-source/vfx/hit/:
  marker_kite.png   64x160  the hit marker blade since 2026-11-15: a slim
                    white rhombus, tip at the bottom, soft dark halo baked in
                    (RIVALS-style blades; our own drawing).
  marker_wedge.png  128x256  a white wedge, tip at the bottom, with a dark
                    outline baked in; tinted per hit (white body, red head)
                    by ImageColor3 (the outline stays dark). The crosshair hit
                    marker: four of them point in at the centre (RIVALS-style
                    indents).
  head_crown_4x4.png 1024x1024  the headshot burst since 2026-11-15: a
                    16-frame one-shot flipbook of faceted blades (centre,
                    +-38, +-64 degrees) that shoot out, split and break up
                    (RIVALS-style crown burst, drawn from scratch).
  head_flare_2x2.png 1024x1024  the owner's ChatGPT headshot flare
                    (HeadshotFlare_chatgpt.png, 2x2 on black) keyed to alpha,
                    four frames (burst, flame, wisp, embers), each frame's base
                    lined up on one anchor (256, 440) in its 512 cell.
  head_flash.png    512x512  a radial burst of tapered streaks, white core,
                    warm yellow to orange edges, on transparency. The headshot
                    flash behind the head (best effort until the owner's
                    ChatGPT render; prompt in the note).
Supersampled 4x for clean edges. Pillow only.
"""

import math
import os
import random

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art-source", "vfx", "hit")
SS = 4  # supersampling


def wedge():
	w, h = 128, 256
	W, H = w * SS, h * SS
	img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
	d = ImageDraw.Draw(img)
	pad = 6 * SS
	# Outline: the full wedge in near-black, then the white fill inset.
	pts = [(pad, pad), (W - pad, pad), (W // 2, H - pad)]
	# An even outline all round (Pillow strokes inside the polygon edge).
	d.polygon(pts, fill=(255, 255, 255, 255), outline=(6, 8, 12, 240), width=15 * SS)  # ~0.6 px at 4 px wide: a dark edge on a white-flashed body
	return img.resize((w, h), Image.LANCZOS)


def kite():
	"""The hit marker blade (2026-11-15, RIVALS pass): a slim white rhombus,
	tip at the bottom (it points at the screen centre), widest 42 % down from
	the outer end, 1:2.5. A faint soft dark halo is baked into the alpha so a
	white blade still reads on a white-flashed body. Tinted by ImageColor3
	(the halo stays dark because it is drawn black)."""
	w, h = 64, 160
	W, H = w * SS, h * SS
	pad = 8 * SS
	cx = W // 2
	widest = pad + int((H - 2 * pad) * 0.42)
	half = (W - 2 * pad) // 2
	pts = [(cx, pad), (cx + half, widest), (cx, H - pad), (cx - half, widest)]
	shadow = Image.new("L", (W, H), 0)
	ImageDraw.Draw(shadow).polygon(pts, fill=255)
	shadow = shadow.filter(ImageFilter.GaussianBlur(3.5 * SS))
	img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
	dark = Image.new("RGBA", (W, H), (6, 8, 12, 0))
	dark.putalpha(shadow.point(lambda a: int(a * 0.42)))
	img.alpha_composite(dark)
	fill = Image.new("RGBA", (W, H), (0, 0, 0, 0))
	ImageDraw.Draw(fill).polygon(pts, fill=(255, 255, 255, 255))
	img.alpha_composite(fill)
	return img.resize((w, h), Image.LANCZOS)


def _blade(d, base, ang, start, length, width, skew):
	"""A faceted blade from `start` to `start + length` along `ang` (radians
	from straight up, screen y down): pointed tip, an off-centre kink on each
	side (angled plates, never a curve), a narrow butt."""
	dx, dy = math.sin(ang), -math.cos(ang)
	nx, ny = -dy, dx

	def at(t, side):
		return (base[0] + dx * t + nx * side, base[1] + dy * t + ny * side)

	pts = [
		at(start, width * 0.18),
		at(start + length * (0.5 + skew), width * 0.5),
		at(start + length, 0),
		at(start + length * (0.38 - skew), -width * 0.5),
		at(start, -width * 0.18),
	]
	d.polygon(pts, fill=255)


def crown_flipbook(seed=11):
	"""The headshot burst (2026-11-15, RIVALS pass): a 4x4 one-shot flipbook,
	1024x1024, frames left to right, top row first. Studied from RIVALS'
	HeadshotParticles "big-middle" layer and drawn from scratch in our
	faceted style: a tall centre blade, two side blades at +-38 degrees and
	small chips at +-64, from one base 62 % down each cell. Over the frames
	the blades shoot out a little, thin, split into a tip and a chip, and
	break into flecks. White on transparency (tinted white -> orange -> red
	by the emitter), with a soft halo baked in so it blooms like a flash."""
	rng = random.Random(seed)
	cell = 256
	S = cell * SS
	sheet = Image.new("RGBA", (cell * 4, cell * 4), (0, 0, 0, 0))
	blades = [  # angle (deg), length, width (share of the cell)
		(0, 0.47, 0.062),
		(-38, 0.37, 0.058),
		(38, 0.37, 0.058),
		(-66, 0.17, 0.045),
		(66, 0.17, 0.045),
	]
	jitter = [(rng.uniform(-4, 4), rng.uniform(0.9, 1.08), rng.uniform(-0.06, 0.06)) for _ in blades]
	for f in range(16):
		p = f / 15
		mask = Image.new("L", (S, S), 0)
		d = ImageDraw.Draw(mask)
		base = (S / 2, S * 0.62)
		for (deg, length, width), (dj, lj, skew) in zip(blades, jitter):
			ang = math.radians(deg + dj + deg * 0.12 * p)  # they splay a touch
			L0 = length * lj * S
			w0 = width * S
			start = S * 0.07 + L0 * 0.32 * p ** 1.1  # a gap at the base; they fly out
			L = L0 * (1 - 0.78 * p ** 0.9)
			w = w0 * (1 - 0.6 * p)
			if p < 0.38:
				_blade(d, base, ang, start, L, w, skew)
			else:
				# Split: the tip flies on, a chip stays nearer the base.
				_blade(d, base, ang, start + L * 0.42, L * 0.58, w * 0.85, skew)
				if p < 0.85:
					_blade(d, base, ang, start, L * 0.24, w * 0.6, -skew)
		if f < 3:  # the hot point at the base on the first frames
			r = S * (0.05 - 0.012 * f)
			d.polygon([(base[0], base[1] - r), (base[0] + r * 0.8, base[1]), (base[0], base[1] + r * 0.6), (base[0] - r * 0.8, base[1])], fill=255)
		fade = 1 if p < 0.6 else max(0.0, 1 - (p - 0.6) / 0.4)
		halo = mask.filter(ImageFilter.GaussianBlur(5 * SS)).point(lambda a: int(a * 0.55))
		alpha = ImageChops.lighter(halo, mask)
		alpha = alpha.point(lambda a, k=fade: int(a * k))
		frame = Image.new("RGBA", (S, S), (255, 255, 255, 0))
		frame.putalpha(alpha)
		frame = frame.resize((cell, cell), Image.LANCZOS)
		sheet.paste(frame, ((f % 4) * cell, (f // 4) * cell))
	return sheet


def head_flash(seed=7):
	rnd = random.Random(seed)
	S = 512
	B = S * SS
	img = Image.new("RGBA", (B, B), (0, 0, 0, 0))
	c = B / 2
	layers = [
		# (colour, width scale, length scale)
		((255, 138, 46, 235), 1.0, 1.0),  # orange rim
		((255, 214, 110, 255), 0.62, 0.86),  # warm yellow
		((255, 252, 236, 255), 0.3, 0.64),  # white-hot core
	]
	n = 12
	spikes = []
	for i in range(n):
		a = (i / n) * math.tau + rnd.uniform(-0.12, 0.12)
		length = rnd.uniform(0.62, 1.0) if i % 2 == 0 else rnd.uniform(0.36, 0.6)
		width = rnd.uniform(0.07, 0.1) if i % 2 == 0 else rnd.uniform(0.05, 0.075)
		spikes.append((a, length, width))
	for colour, ws, ls in layers:
		layer = Image.new("RGBA", (B, B), (0, 0, 0, 0))
		d = ImageDraw.Draw(layer)
		for a, length, width in spikes:
			L = length * ls * (B * 0.48)
			hw = width * ws * (B * 0.48)
			tip = (c + math.cos(a) * L, c + math.sin(a) * L)
			# A tapered streak: wide near the centre, a sharp point outside.
			perp = (-math.sin(a), math.cos(a))
			base = (c + math.cos(a) * L * 0.12, c + math.sin(a) * L * 0.12)
			p1 = (base[0] + perp[0] * hw, base[1] + perp[1] * hw)
			p2 = (base[0] - perp[0] * hw, base[1] - perp[1] * hw)
			back = (c - math.cos(a) * hw * 0.6, c - math.sin(a) * hw * 0.6)
			d.polygon([back, p1, tip, p2], fill=colour)
		r = B * 0.11 * ls
		d.ellipse([c - r, c - r, c + r, c + r], fill=colour)
		img = Image.alpha_composite(img, layer)
	# A faint warm halo so it sits on bright skies (kept small: shapes over glow).
	halo = Image.new("RGBA", (B, B), (0, 0, 0, 0))
	hd = ImageDraw.Draw(halo)
	r = B * 0.2
	hd.ellipse([c - r, c - r, c + r, c + r], fill=(255, 170, 70, 90))
	halo = halo.filter(ImageFilter.GaussianBlur(B * 0.05))
	img = Image.alpha_composite(halo, img)
	return img.resize((S, S), Image.LANCZOS)


def _key(cell):
	"""Black to alpha by un-premultiplying: alpha = brightest channel above a
	noise floor (x a little gain so thin sparks hold), colour = rgb / alpha."""
	floor, gain = 10, 1.15
	w, h = cell.size
	out = Image.new("RGBA", (w, h))
	px, po = cell.load(), out.load()
	for y in range(h):
		for x in range(w):
			r, g, b = px[x, y]
			m = max(r, g, b)
			if m <= floor:
				po[x, y] = (0, 0, 0, 0)
				continue
			a = min(1.0, (m - floor) / (255 - floor) * gain)
			k = 255 / m
			po[x, y] = (min(255, round(r * k)), min(255, round(g * k)), min(255, round(b * k)), round(a * 255))
	return out


def flare_flipbook(src_name="HeadshotFlare_chatgpt.png", anchor=(256, 440)):
	"""The owner's ChatGPT headshot flare (2x2 on black, no alpha): four frames,
	left to right, top row first ("the impact flashes, the flame shoots upward,
	then breaks apart and fades into embers"). Each frame is keyed to alpha and
	moved so its base point (the bottom-centre of what it draws) lands on one
	`anchor` in its 512 cell, at one shared scale, so the sequence doesn't
	jump. Returns the 1024 sheet and each frame's base in the source cell."""
	src = Image.open(os.path.join(OUT, src_name)).convert("RGB")
	w, h = src.size
	cw, ch = w // 2, h // 2
	scale = 512 / max(cw, ch)
	sheet = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
	bases = []
	for i in range(4):
		cx, cy = i % 2, i // 2
		keyed = _key(src.crop((cx * cw, cy * ch, cx * cw + cw, cy * ch + ch)))
		# The drawn part: pixels clearly above the noise.
		mask = keyed.getchannel("A").point(lambda v: 255 if v > 24 else 0)
		box = mask.getbbox() or (0, 0, cw, ch)
		base = ((box[0] + box[2]) / 2, box[3])
		bases.append(base)
		scaled = keyed.resize((round(cw * scale), round(ch * scale)), Image.LANCZOS)
		dx = round(anchor[0] - base[0] * scale)
		dy = round(anchor[1] - base[1] * scale)
		cell = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
		cell.alpha_composite(scaled, (max(0, dx), max(0, dy)), (max(0, -dx), max(0, -dy)))
		sheet.paste(cell, (cx * 512, cy * 512))
	return sheet, bases


def main():
	os.makedirs(OUT, exist_ok=True)
	wedge().save(os.path.join(OUT, "marker_wedge.png"))
	kite().save(os.path.join(OUT, "marker_kite.png"))
	crown_flipbook().save(os.path.join(OUT, "head_crown_4x4.png"))
	head_flash().save(os.path.join(OUT, "head_flash.png"))
	if os.path.exists(os.path.join(OUT, "HeadshotFlare_chatgpt.png")):
		sheet, bases = flare_flipbook()
		sheet.save(os.path.join(OUT, "head_flare_2x2.png"))
		print("frame bases (source px):", [(round(x), round(y)) for x, y in bases])
	print("wrote", OUT)


if __name__ == "__main__":
	main()
