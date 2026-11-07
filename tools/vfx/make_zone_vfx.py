"""Renders the sudden-death zone wall textures with Blender, and their preview sheet.

Render (Blender, headless; well under a minute):

    "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup \
        --python tools/vfx/make_zone_vfx.py

Preview contact sheet (plain Python + Pillow + numpy, after rendering):

    python tools/vfx/make_zone_vfx.py --preview

Look (vault/05 Production/Match Structure Revamp.md, decision 8): a storm wall like Valorant's, with a glitched vibe.
A churning curtain of storm cloud, brightest and densest at the ground, thinning upward, broken by glitch artefacts:
horizontal bands of the cloud slipped sideways (datamosh), hard 8-px pixel blocks and faint scanlines. Everything is
WHITE with straight alpha (RGBA PNG) so the game tints it (Controllers/ZoneController). Output: art-source/vfx/zone/.

  zone_wall    1024x512   the main curtain. Tiles left-right seamlessly (the cloud is sampled on a cylinder, every
                          glitch operation wraps), so a ring of Beams can run it round the circle. Top rows fade to
                          alpha 0; the bottom rows are a bright ground line.
  zone_glitch  512x256    a sparse overlay scrolled faster than the wall: pixel blocks and short slipped streaks only,
                          mostly transparent. Tiles left-right.

How: Cycles renders two greyscale emission fields on a plane, each a 3D noise sampled on a cylinder (x = cos(2πu),
y = sin(2πu), z = v) so the left and right edges meet. post() (numpy) shapes them into the curtain and adds the glitch
artefacts from a fixed seed, so re-running gives the same images.
"""

import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art-source" / "vfx" / "zone"
PREVIEW = ROOT / "vault" / "02 Art" / "References" / "zone" / "zone_vfx_preview.png"

try:
	import bpy
except ImportError:  # Plain Python: post-processing and preview only.
	bpy = None

TAU = math.tau

# name: (width, height, noise scale, vertical stretch)
FIELDS = {
	"cloud": (1024, 512, 2.2, 0.55),
	"detail": (1024, 512, 6.0, 0.35),
}


def render_fields():
	scene = bpy.context.scene
	scene.render.engine = "CYCLES"
	scene.cycles.samples = 16
	scene.cycles.device = "CPU"
	scene.view_settings.view_transform = "Standard"
	scene.render.image_settings.file_format = "PNG"
	scene.render.image_settings.color_mode = "BW"
	scene.render.image_settings.color_depth = "16"
	for obj in list(bpy.data.objects):
		bpy.data.objects.remove(obj)

	bpy.ops.mesh.primitive_plane_add(size=1)
	plane = bpy.context.active_object
	plane.scale = (2.0, 1.0, 1.0)

	cam_data = bpy.data.cameras.new("Cam")
	cam_data.type = "ORTHO"
	cam_data.ortho_scale = 2.0
	cam = bpy.data.objects.new("Cam", cam_data)
	cam.location = (0, 0, 5)
	bpy.context.collection.objects.link(cam)
	scene.camera = cam

	world = bpy.data.worlds.new("Black")
	world.color = (0, 0, 0)
	scene.world = world

	OUT.mkdir(parents=True, exist_ok=True)
	for name, (w, h, scale, stretch) in FIELDS.items():
		mat = bpy.data.materials.new(name)
		if mat.node_tree is None:
			mat.use_nodes = True
		nt = mat.node_tree
		nt.nodes.clear()
		n = nt.nodes.new
		link = nt.links.new
		tc = n("ShaderNodeTexCoord")
		sep = n("ShaderNodeSeparateXYZ")
		link(tc.outputs["UV"], sep.inputs[0])
		ang = n("ShaderNodeMath")
		ang.operation = "MULTIPLY"
		ang.inputs[1].default_value = TAU
		link(sep.outputs[0], ang.inputs[0])
		cos = n("ShaderNodeMath")
		cos.operation = "COSINE"
		link(ang.outputs[0], cos.inputs[0])
		sin = n("ShaderNodeMath")
		sin.operation = "SINE"
		link(ang.outputs[0], sin.inputs[0])
		vz = n("ShaderNodeMath")
		vz.operation = "MULTIPLY"
		vz.inputs[1].default_value = TAU * stretch  # taller wisps than wide
		link(sep.outputs[1], vz.inputs[0])
		comb = n("ShaderNodeCombineXYZ")
		link(cos.outputs[0], comb.inputs[0])
		link(sin.outputs[0], comb.inputs[1])
		link(vz.outputs[0], comb.inputs[2])
		noise = n("ShaderNodeTexNoise")
		noise.noise_dimensions = "3D"
		noise.inputs["Scale"].default_value = scale
		noise.inputs["Detail"].default_value = 8.0
		noise.inputs["Roughness"].default_value = 0.58
		noise.inputs["Distortion"].default_value = 0.6
		link(comb.outputs[0], noise.inputs["Vector"])
		emit = n("ShaderNodeEmission")
		link(noise.outputs["Fac"], emit.inputs["Strength"])
		emit.inputs["Color"].default_value = (1, 1, 1, 1)
		out = n("ShaderNodeOutputMaterial")
		link(emit.outputs[0], out.inputs["Surface"])
		plane.data.materials.clear()
		plane.data.materials.append(mat)
		scene.render.resolution_x = w
		scene.render.resolution_y = h
		scene.render.filepath = str(OUT / f"_field_{name}.png")
		bpy.ops.render.render(write_still=True)


def post():
	import numpy as np
	from PIL import Image

	rng = np.random.default_rng(20261107)

	def load(name):
		a = np.asarray(Image.open(OUT / f"_field_{name}.png")).astype(np.float64)
		# Noise sits in a narrow band around grey: spread it to 0..1.
		lo, hi = np.percentile(a, 1), np.percentile(a, 99)
		return np.clip((a - lo) / max(hi - lo, 1e-6), 0, 1)

	cloud = load("cloud")
	detail = load("detail")
	h, w = cloud.shape

	def stretch(a, lo, hi):
		return np.clip((a - lo) / (hi - lo), 0, 1)

	# Churning storm: big billows with finer streaks on top.
	c = stretch(cloud, 0.32, 0.72) ** 1.4
	d = stretch(detail, 0.35, 0.75)
	storm = np.clip(c * 0.75 + d * 0.35, 0, 1)

	# Vertical profile: row 0 is the TOP of the wall.
	y = np.linspace(0, 1, h)[:, None]  # 0 top .. 1 bottom
	profile = 0.18 + 0.82 * y**1.6
	alpha = storm * profile + 0.22 * y**3  # denser near the ground
	ground = np.exp(-((1 - y) * h / 5.0) ** 2)  # bright ground line, ~5 px
	alpha = np.maximum(alpha, ground * 0.95)
	lum = np.clip(0.55 + 0.45 * storm + ground * 0.5, 0, 1)

	# Glitch 1: horizontal bands slipped sideways (wraps, so it still tiles).
	for _ in range(16):
		band_h = int(rng.integers(3, 18))
		top = int(rng.integers(0, h - band_h))
		shift = int(rng.integers(-w // 6, w // 6))
		alpha[top : top + band_h] = np.roll(alpha[top : top + band_h], shift, axis=1)
		lum[top : top + band_h] = np.clip(np.roll(lum[top : top + band_h], shift, axis=1) + 0.15, 0, 1)

	# Glitch 2: hard pixel blocks on an 8-px grid, more of them low on the wall.
	cell = 8
	for _ in range(220):
		bw = cell * int(rng.integers(1, 4))
		bh = cell * int(rng.integers(1, 3))
		gy = int(rng.beta(2.2, 1.2) * (h - bh) // cell * cell)
		gx = int(rng.integers(0, w // cell)) * cell
		xs = np.arange(gx, gx + bw) % w
		value = float(rng.uniform(0.35, 0.9))
		alpha[gy : gy + bh][:, xs] = np.maximum(alpha[gy : gy + bh][:, xs], value)
		lum[gy : gy + bh][:, xs] = 1.0

	# Faint scanlines.
	alpha[::4] *= 0.82

	# Top rows fade to nothing.
	fade = np.clip(np.arange(h) / 10.0, 0, 1)[:, None]
	alpha *= fade
	write("zone_wall", lum, alpha)

	# The sparse overlay: blocks and slipped streaks on transparent.
	gh, gw = 256, 512
	ga = np.zeros((gh, gw))
	for _ in range(70):
		bw = 4 * int(rng.integers(1, 6))
		bh = 4 * int(rng.integers(1, 3))
		gy = int(rng.integers(0, (gh - bh) // 4)) * 4
		gx = int(rng.integers(0, gw // 4)) * 4
		xs = np.arange(gx, gx + bw) % gw
		ga[gy : gy + bh][:, xs] = rng.uniform(0.5, 1.0)
	for _ in range(18):
		length = int(rng.integers(40, 160))
		gy = int(rng.integers(0, gh - 2))
		gx = int(rng.integers(0, gw))
		xs = np.arange(gx, gx + length) % gw
		ga[gy : gy + 2][:, xs] = np.maximum(ga[gy : gy + 2][:, xs], np.linspace(0.9, 0.0, length))
	ga *= np.clip(np.arange(gh) / 6.0, 0, 1)[:, None]
	write("zone_glitch", np.ones_like(ga), ga)


def write(name, lum, alpha):
	import numpy as np
	from PIL import Image

	rgba = np.zeros(lum.shape + (4,), dtype=np.uint8)
	v = (np.clip(lum, 0, 1) * 255).astype(np.uint8)
	rgba[..., 0] = v
	rgba[..., 1] = v
	rgba[..., 2] = v
	rgba[..., 3] = (np.clip(alpha, 0, 1) * 255).astype(np.uint8)
	Image.fromarray(rgba, "RGBA").save(OUT / f"{name}.png")
	print("wrote", OUT / f"{name}.png")


def preview():
	from PIL import Image

	tint = (205, 60, 255)
	tiles = []
	for name in ("zone_wall", "zone_glitch"):
		img = Image.open(OUT / f"{name}.png").convert("RGBA")
		img = img.resize((1024, 512 if name == "zone_wall" else 512))
		bg = Image.new("RGBA", img.size, (28, 30, 36, 255))
		colored = Image.new("RGBA", img.size, tint + (255,))
		colored.putalpha(img.getchannel("A"))
		bg.alpha_composite(colored)
		tiles.append(bg)
	# Two copies side by side show the seam.
	sheet = Image.new("RGBA", (2048, 1024), (0, 0, 0, 255))
	sheet.paste(tiles[0], (0, 0))
	sheet.paste(tiles[0], (1024, 0))
	sheet.paste(tiles[1], (0, 512))
	sheet.paste(tiles[1], (1024, 512))
	PREVIEW.parent.mkdir(parents=True, exist_ok=True)
	sheet.convert("RGB").save(PREVIEW)
	print("preview", PREVIEW)


if __name__ == "__main__":
	if bpy is not None:
		render_fields()
	elif "--preview" in sys.argv:
		post()
		preview()
	else:
		post()
