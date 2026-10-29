"""Renders the Recon (sensor dart scan pulse) textures with Blender, and their preview sheet.

Render (Blender, headless; about a minute on a 12-core CPU, `--fast` for a quick half-size, low-sample check):

    "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup \
        --python tools/vfx/make_recon_vfx.py -- [names...] [--fast]

Preview contact sheet (plain Python + Pillow + numpy, run after rendering):

    python tools/vfx/make_recon_vfx.py --preview

Look (vault/01 Design/Abilities/Recon.md, "Look"): Sova's Recon Bolt as the quality reference, in this game's plain,
realistic tactical style: a faint light trail behind the dart in flight, a small blinking light on the stuck dart
that flashes on each pulse, a clean sonar-like scan wavefront expanding from the dart (a flat ring plus a
camera-facing shell), and sparks when the dart is shot. No glitch or digital shapes. Everything is WHITE with
straight alpha (RGBA PNG) so the game tints it (cool cyan #9BE7FF is the intended tint for the scan, team colour for
the dart light). Output goes to art-source/vfx/abilities/recon/.

  recon_scan_ring        1024x1024  flat scan wavefront for an expanding ring (a flat MeshPart / Decal / SurfaceGui
                                    on a part scaled up over the pulse): a thin, crisp, bright leading edge at
                                    r = 0.9 of the half-size with a soft glow trailing inward (towards the centre)
                                    and two faint echo lines behind it; faint fine radial "scan" streaks in the trail.
                                    Transparent centre and outside.
  recon_scan_sphere_2x2  1024x1024  2x2 flipbook (camera-facing, left-right, top-bottom): an expanding scan shell seen
                                    as a sphere (bright limb, see-through middle, the projected thickness of a real
                                    thin shell), with fainter echo shells following inside it; a flash at the start,
                                    the shell grows, thins and fades over the 4 frames.
  recon_glow             256x256    soft point glow with a small hot core (the dart's light: blinks, flashes on a pulse).
  recon_trail            512x128    thin light streak for a Trail (TextureMode Stretch): u along it, the HEAD at the
                                    LEFT (u = 0, brightest), a tapering bright core in a soft glow fading to the right.
  recon_spark            256x256    small spark (dart destroyed): a hot core with a long horizontal streak (for
                                    VelocityParallel particles), short vertical flare and a faint halo.

How: every texture is emission maths on a plane, rendered with Cycles on black and turned into white + alpha
afterwards (glow_post: alpha = brightness). Seeds are fixed, so re-running gives the same images.
"""

import math
import random
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art-source" / "vfx" / "abilities" / "recon"
PREVIEW = ROOT / "vault" / "02 Art" / "References" / "abilities" / "recon" / "recon_vfx_preview.png"

try:
	import bpy
except ImportError:  # Plain Python: preview mode only.
	bpy = None

FAST = "--fast" in sys.argv


# Node maths (same helpers as make_frost_vfx.py) ---------------


class S:
	"""A float socket with operators, so shader maths reads like maths."""

	def __init__(self, g, sock):
		self.g = g
		self.sock = sock

	def _op(self, op, other, swap=False):
		a, b = (other, self) if swap else (self, other)
		return self.g.math(op, a, b)

	def __add__(self, o):
		return self._op("ADD", o)

	def __radd__(self, o):
		return self._op("ADD", o, True)

	def __sub__(self, o):
		return self._op("SUBTRACT", o)

	def __rsub__(self, o):
		return self._op("SUBTRACT", o, True)

	def __mul__(self, o):
		return self._op("MULTIPLY", o)

	def __rmul__(self, o):
		return self._op("MULTIPLY", o, True)

	def __truediv__(self, o):
		return self._op("DIVIDE", o)

	def __rtruediv__(self, o):
		return self._op("DIVIDE", o, True)

	def __pow__(self, o):
		return self._op("POWER", o)

	def __neg__(self):
		return self._op("MULTIPLY", -1.0)


class G:
	"""Builds one material's node tree."""

	def __init__(self, name):
		m = bpy.data.materials.new(name)
		if m.node_tree is None:
			m.use_nodes = True
		nt = m.node_tree
		nt.nodes.clear()
		self.mat = m
		self.nt = nt
		tc = self.node("ShaderNodeTexCoord")
		obj = self.node("ShaderNodeSeparateXYZ")
		self.link(tc.outputs["Object"], obj.inputs[0])
		uv = self.node("ShaderNodeSeparateXYZ")
		self.link(tc.outputs["UV"], uv.inputs[0])
		self.x = S(self, obj.outputs[0])
		self.y = S(self, obj.outputs[1])
		self.z = S(self, obj.outputs[2])
		self.u = S(self, uv.outputs[0])
		self.v = S(self, uv.outputs[1])

	def node(self, kind):
		return self.nt.nodes.new(kind)

	def link(self, a, b):
		self.nt.links.new(a, b)

	def put(self, sock, value):
		if isinstance(value, S):
			self.link(value.sock, sock)
		else:
			sock.default_value = value

	def math(self, op, a, b=0.0, clamp=False):
		n = self.node("ShaderNodeMath")
		n.operation = op
		n.use_clamp = clamp
		self.put(n.inputs[0], a)
		self.put(n.inputs[1], b)
		return S(self, n.outputs[0])

	def clamp01(self, a):
		return self.math("ADD", a, 0.0, clamp=True)

	def abs(self, a):
		return self.math("ABSOLUTE", a)

	def max(self, a, b):
		return self.math("MAXIMUM", a, b)

	def min(self, a, b):
		return self.math("MINIMUM", a, b)

	def cos(self, a):
		return self.math("COSINE", a)

	def sin(self, a):
		return self.math("SINE", a)

	def sqrt(self, a):
		return self.math("SQRT", a)

	def atan2(self, y, x):
		return self.math("ARCTAN2", y, x)

	def length(self, a, b):
		return self.sqrt(a * a + b * b)

	def soft(self, d, width):
		"""Gaussian bump: 1 at d=0, ~0 by d=2*width."""
		q = d / width
		return self.math("EXPONENT", -(q * q))

	def smooth(self, value, lo, hi):
		"""Smoothstep from lo (0) to hi (1); lo > hi inverts it. lo/hi may be sockets."""
		n = self.node("ShaderNodeMapRange")
		n.interpolation_type = "SMOOTHSTEP"
		n.clamp = True
		self.put(n.inputs["Value"], value)
		const = not isinstance(lo, S) and not isinstance(hi, S)
		flip = const and lo > hi
		if flip:
			lo, hi = hi, lo
		self.put(n.inputs["From Min"], lo)
		self.put(n.inputs["From Max"], hi)
		n.inputs["To Min"].default_value = 1.0 if flip else 0.0
		n.inputs["To Max"].default_value = 0.0 if flip else 1.0
		return S(self, n.outputs[0])

	def noise(self, x, y, z=0.0, w=0.0, detail=2.0, rough=0.5, lac=2.0):
		"""4D Perlin fBm, about 0..1 around 0.5 (Scale 1: pre-scale the inputs)."""
		c = self.node("ShaderNodeCombineXYZ")
		self.put(c.inputs[0], x)
		self.put(c.inputs[1], y)
		self.put(c.inputs[2], z)
		n = self.node("ShaderNodeTexNoise")
		n.noise_dimensions = "4D"
		self.link(c.outputs[0], n.inputs["Vector"])
		self.put(n.inputs["W"], w)
		n.inputs["Scale"].default_value = 1.0
		n.inputs["Detail"].default_value = detail
		n.inputs["Roughness"].default_value = rough
		n.inputs["Lacunarity"].default_value = lac
		return S(self, n.outputs["Fac"])

	def voronoi(self, x, y, z=0.0, feature="F1", rand=1.0):
		"""3D Voronoi (Scale 1: pre-scale the inputs). Returns (distance, cell random 0..1)."""
		c = self.node("ShaderNodeCombineXYZ")
		self.put(c.inputs[0], x)
		self.put(c.inputs[1], y)
		self.put(c.inputs[2], z)
		n = self.node("ShaderNodeTexVoronoi")
		n.voronoi_dimensions = "3D"
		n.feature = feature
		self.link(c.outputs[0], n.inputs["Vector"])
		n.inputs["Scale"].default_value = 1.0
		n.inputs["Randomness"].default_value = rand
		dist = S(self, n.outputs["Distance"])
		if feature == "DISTANCE_TO_EDGE":
			return dist, None
		sep = self.node("ShaderNodeSeparateColor")
		self.link(n.outputs["Color"], sep.inputs[0])
		return dist, S(self, sep.outputs[0])

	def normal_z(self):
		geo = self.node("ShaderNodeNewGeometry")
		sep = self.node("ShaderNodeSeparateXYZ")
		self.link(geo.outputs["Normal"], sep.inputs[0])
		return S(self, sep.outputs[2])

	def emit(self, strength):
		"""White emission (rendered on black; glow_post turns brightness into alpha)."""
		em = self.node("ShaderNodeEmission")
		em.inputs["Color"].default_value = (1.0, 1.0, 1.0, 1.0)
		self.put(em.inputs["Strength"], strength)
		out = self.node("ShaderNodeOutputMaterial")
		self.link(em.outputs[0], out.inputs["Surface"])
		return self.mat

	def output(self, alpha, color=1.0, strength=1.0):
		"""Grey emission with straight `alpha` on a transparent film."""
		em = self.node("ShaderNodeEmission")
		if isinstance(color, S):
			cc = self.node("ShaderNodeCombineColor")
			for k in range(3):
				self.put(cc.inputs[k], color)
			self.link(cc.outputs[0], em.inputs["Color"])
		else:
			em.inputs["Color"].default_value = (color, color, color, 1.0)
		self.put(em.inputs["Strength"], strength)
		tr = self.node("ShaderNodeBsdfTransparent")
		mix = self.node("ShaderNodeMixShader")
		self.put(mix.inputs[0], self.clamp01(alpha))
		self.link(tr.outputs[0], mix.inputs[1])
		self.link(em.outputs[0], mix.inputs[2])
		out = self.node("ShaderNodeOutputMaterial")
		self.link(mix.outputs[0], out.inputs["Surface"])
		return self.mat

	def volume(self, density, color=1.0):
		"""White scattering volume (mist), lit by the scene lights."""
		pv = self.node("ShaderNodeVolumePrincipled")
		pv.inputs["Color"].default_value = (color, color, color, 1.0)
		pv.inputs["Anisotropy"].default_value = 0.3
		self.put(pv.inputs["Density"], density)
		out = self.node("ShaderNodeOutputMaterial")
		self.link(pv.outputs[0], out.inputs["Volume"])
		return self.mat


def sn(n, gain=4.0):
	"""Perlin fac (about 0.5 +- 0.15) -> signed, roughly -0.8..0.8."""
	return (n - 0.5) * gain



# Textures --------------------------------------------------------------------------
# Plane coordinates: -1..1 (times the aspect in x), +y = up in the image. Strip textures use the plane's UVs.


def scan_ring(g, _i):
	"""Flat scan wavefront: crisp bright leading edge, soft glow trailing inward, two faint echo lines, fine streaks."""
	x, y = g.x, g.y
	r = g.length(x, y)
	a = g.atan2(y, x)
	ca, sa = g.cos(a), g.sin(a)
	R = 0.9
	behind = g.clamp01((R - r) * 1.0)  # 0 at the edge, grows inward
	inside = g.smooth(r, R + 0.004, R - 0.004)
	edge = g.soft(r - R, 0.0055) * 1.0 + g.soft(r - R, 0.018) * 0.32
	trail = g.math("EXPONENT", behind * -13.0) * inside * 0.42 + g.math("EXPONENT", behind * -4.0) * inside * 0.08
	echo = g.soft(r - (R - 0.13), 0.0045) * 0.2 + g.soft(r - (R - 0.27), 0.004) * 0.09
	# Fine radial streaks in the trailing glow (the scan "reading" the space), very subtle.
	streak = g.noise(ca * 34.0, sa * 34.0, r * 3.0, w=4.0, detail=1.0)
	streaks = 0.9 + 0.2 * g.smooth(streak, 0.32, 0.68)
	# A slow brightness variation round the ring so it doesn't look stamped.
	vary = 0.88 + 0.24 * g.smooth(g.noise(ca * 1.8, sa * 1.8, 0.0, w=6.0, detail=2.0), 0.3, 0.7)
	keep = g.smooth(r, 0.99, 0.95) * g.smooth(r, 0.3, 0.5)
	return g.emit((edge + trail * streaks + echo) * vary * keep)


SHELL = [
	# (radius, shell thickness, gain, core flash, [(echo radius, echo gain)])
	(0.3, 0.05, 1.0, 1.0, []),
	(0.54, 0.042, 0.92, 0.22, [(0.38, 0.32)]),
	(0.74, 0.034, 0.72, 0.0, [(0.58, 0.3), (0.42, 0.14)]),
	(0.9, 0.026, 0.45, 0.0, [(0.76, 0.2), (0.6, 0.09)]),
]


def shell(g, r, R, t):
	"""Projected thickness of a thin sphere shell (radius R, thickness t) at screen distance r, normalised to 1 at
	the limb: bright rim, see-through middle, like a real shockwave bubble."""
	outer = g.sqrt(g.max(R * R - r * r, 0.0))
	inner = g.sqrt(g.max((R - t) * (R - t) - r * r, 0.0))
	return (outer - inner) / math.sqrt(R * R - (R - t) * (R - t))


def scan_sphere(g, i):
	"""Expanding scan shell (camera-facing): a sphere shell with a crisp limb, faint echo shells inside, a flash."""
	R, t, gain, core_k, echoes = SHELL[i]
	x, y = g.x, g.y
	r = g.length(x, y)
	a = g.atan2(y, x)
	body = shell(g, r, R, t)
	# Soft glow just outside the limb and a faint fill inside (the scanned volume).
	halo = g.soft(r - R, 0.03 + 0.01 * i) * 0.35
	fill = g.smooth(r, R, R * 0.2) * 0.04
	total = body + halo + fill
	for er, eg in echoes:
		total = total + shell(g, r, er, t * 0.8) * eg
	# A gentle, smooth brightness variation round the shell (no hard wedges), stronger as it fades out.
	if i >= 1:
		bn = g.noise(x * 2.2, y * 2.2, 0.0, w=11.0, detail=2.0)
		k = 0.18 + 0.1 * i
		total = total * ((1.0 - k) + 2.0 * k * g.smooth(bn, 0.3, 0.7))
	core = g.soft(r, 0.07) * core_k * 1.4 + g.soft(r, 0.2) * core_k * 0.45
	keep = g.smooth(r, 0.995, 0.95)
	return g.emit((total * gain + core) * keep)


def glow(g, _i):
	"""Soft point glow with a small hot core."""
	r = g.length(g.x, g.y)
	alpha = g.soft(r, 0.055) * 1.3 + g.soft(r, 0.17) * 0.5 + g.soft(r, 0.42) * 0.18
	return g.emit(alpha * g.smooth(r, 1.0, 0.9))


def trail(g, _i):
	"""Thin light streak along u, head at the left: a tapering hot core in a soft glow, fading to the right."""
	u, v = g.u, g.v
	dv = g.abs(v - 0.5)
	fade = g.clamp01(1.0 - u) ** 1.7
	head = g.smooth(u, 0.0, 0.025)
	core = g.soft(dv, 0.035 * (1.0 - 0.55 * u)) * fade * 1.15
	glow_ = g.soft(dv, 0.16 * (1.0 - 0.35 * u)) * g.clamp01(1.0 - u) ** 2.4 * 0.35
	# A slight shimmer along the length so it isn't a perfect gradient.
	shim = 0.88 + 0.24 * g.smooth(g.noise(u * 9.0, 0.0, 0.0, w=21.0, detail=2.0), 0.3, 0.7)
	edges = g.smooth(v, 0.0, 0.06) * g.smooth(v, 1.0, 0.94)
	return g.emit((core + glow_) * shim * head * edges)


def spark(g, _i):
	"""Hot core, long horizontal streak, short vertical flare, faint halo."""
	x, y = g.x, g.y
	r = g.length(x, y)
	ax, ay = g.abs(x), g.abs(y)

	def ray(along, across, reach, width):
		f = g.clamp01(1.0 - along / reach)
		return g.soft(across, width * (0.2 + 0.8 * f)) * f**1.8

	core = g.soft(r, 0.06) * 1.5 + g.soft(r, 0.16) * 0.4
	streak = ray(ax, ay, 0.95, 0.045)
	flare = ray(ay, ax, 0.3, 0.025) * 0.55
	halo = g.soft(r, 0.4) * 0.12
	return g.emit((core + streak + flare + halo) * g.smooth(r, 1.0, 0.92))


# Sheets -------------------------------------------------------------------------------
# name: (width, height, grid, builder)

SHEETS = {
	"recon_scan_ring": (1024, 1024, 1, scan_ring),
	"recon_scan_sphere_2x2": (1024, 1024, 2, scan_sphere),
	"recon_glow": (256, 256, 1, glow),
	"recon_trail": (512, 128, 1, trail),
	"recon_spark": (256, 256, 1, spark),
}
# alpha = brightness * GAIN (1 = fully opaque white).
GAIN = {}


def setup_scene(width, height, ortho, samples):
	bpy.ops.wm.read_factory_settings(use_empty=True)
	scene = bpy.context.scene
	scene.render.engine = "CYCLES"
	scene.cycles.device = "CPU"
	scene.cycles.samples = max(8, samples // 6) if FAST else samples
	scene.cycles.seed = 7
	scene.cycles.use_denoising = False
	scene.cycles.transparent_max_bounces = 32
	scene.render.film_transparent = True
	scene.render.resolution_x = width
	scene.render.resolution_y = height
	scene.render.resolution_percentage = 50 if FAST else 100
	scene.view_settings.view_transform = "Standard"
	scene.view_settings.look = "None"
	scene.render.image_settings.file_format = "PNG"
	scene.render.image_settings.color_mode = "RGBA"
	scene.render.image_settings.color_depth = "8"
	scene.render.image_settings.compression = 100
	cam_data = bpy.data.cameras.new("cam")
	cam_data.type = "ORTHO"
	cam_data.ortho_scale = ortho
	cam_data.clip_end = 100
	cam = bpy.data.objects.new("cam", cam_data)
	cam.location = (0, 0, 10)
	scene.collection.objects.link(cam)
	scene.camera = cam
	return scene



def glow_post(src, dst, gain, gamma=1.0):
	"""Emission render on black (linear EXR) -> white straight-alpha RGBA PNG, alpha = brightness * gain."""
	import numpy as np

	img = bpy.data.images.load(str(src))
	w, h = img.size
	px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
	bpy.data.images.remove(img)
	lum = px[..., :3].max(axis=-1)
	alpha = np.clip(lum * gain, 0.0, 1.0) ** gamma
	alpha[alpha < 1.5 / 255] = 0.0
	out = np.ones((h, w, 4), np.float32)
	out[..., 3] = alpha
	im = bpy.data.images.new("post", w, h, alpha=True)
	im.alpha_mode = "STRAIGHT"
	im.pixels.foreach_set(out.ravel())
	im.filepath_raw = str(dst)
	im.file_format = "PNG"
	im.save()
	bpy.data.images.remove(im)


def black_world(scene):
	scene.render.film_transparent = False
	world = bpy.data.worlds.new("black")
	world.use_nodes = True
	world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.0
	scene.world = world
	scene.render.image_settings.file_format = "OPEN_EXR"
	scene.render.image_settings.color_depth = "32"
	scene.render.image_settings.color_mode = "RGB"



def render_sheet(name):
	width, height, grid, build = SHEETS[name]
	aspect = width / height
	scene = setup_scene(width, height, 2 * grid * aspect, 48)
	for i in range(grid * grid):
		col, row = i % grid, i // grid
		origin = ((col - (grid - 1) / 2) * 2, ((grid - 1) / 2 - row) * 2)
		bpy.ops.mesh.primitive_plane_add(size=2, location=(*origin, 0))
		plane = bpy.context.active_object
		if aspect != 1:
			plane.scale = (aspect, 1, 1)
			bpy.ops.object.transform_apply(scale=True)  # object coordinates in -aspect..aspect, -1..1
		plane.data.materials.append(build(G(f"{name}{i}"), i))
	black_world(scene)
	raw = OUT / f"_{name}.exr"
	path = OUT / f"{name}.png"
	scene.render.filepath = str(raw)
	bpy.ops.render.render(write_still=True)
	glow_post(raw, path, GAIN.get(name, 1.0))
	raw.unlink()
	print(f"[recon-vfx] {path.relative_to(ROOT)}")
	return path


def render_main():
	argv = [a for a in (sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []) if not a.startswith("--")]
	OUT.mkdir(parents=True, exist_ok=True)
	for name in argv or list(SHEETS):
		render_sheet(name)


# Preview (plain Python + Pillow) -----------------------------------------------

BG = (34, 36, 40)
CYAN = (0x9B, 0xE7, 0xFF)
WHITE = (255, 255, 255)


def preview_main():
	import numpy as np
	from PIL import Image, ImageDraw, ImageFont

	def font(size):
		for name in ("segoeui.ttf", "arial.ttf", "DejaVuSans.ttf"):
			try:
				return ImageFont.truetype(name, size)
			except OSError:
				continue
		return ImageFont.load_default()

	f_title, f_head, f_small = font(26), font(19), font(14)

	def frames(img, n):
		w, h = img.size
		return [img.crop(((k % n) * w // n, (k // n) * h // n, (k % n + 1) * w // n, (k // n + 1) * h // n)) for k in range(n * n)]

	def tint(img, color):
		a = np.asarray(img, np.float32)
		a[..., :3] *= np.array(color, np.float32) / 255.0
		return Image.fromarray(a.clip(0, 255).astype("uint8"), "RGBA")

	def additive(dst, img, pos, gain=1.0):
		"""Composite like Roblox LightEmission = 1 (colour * alpha added)."""
		x, y = pos
		region = dst.crop((x, y, x + img.width, y + img.height)).convert("RGB")
		a = np.asarray(img, dtype=np.float32) / 255.0
		b = np.asarray(region, dtype=np.float32) / 255.0
		out = np.clip(b + a[..., :3] * a[..., 3:4] * gain, 0, 1)
		dst.paste(Image.fromarray((out * 255).astype("uint8"), "RGB"), (x, y))

	tex = {n: Image.open(OUT / f"{n}.png").convert("RGBA") for n in SHEETS}
	W, pad, H = 1500, 24, 5000
	sheet = Image.new("RGBA", (W, H), (*BG, 255))
	draw = ImageDraw.Draw(sheet)
	draw.text((pad, 16), "Recon VFX textures on dark grey: cool cyan #9BE7FF tint and white (normal alpha blend unless noted)", fill=(235, 235, 235), font=f_title)
	y = 64

	def label(text, sub=None):
		nonlocal y
		draw.text((pad, y), text, fill=(230, 230, 230), font=f_head)
		if sub:
			draw.text((pad + draw.textlength(text, font=f_head) + 14, y + 4), sub, fill=(150, 150, 155), font=f_small)
		y += 30

	def row(imgs, cell, color, add=False):
		nonlocal y
		for k, img in enumerate(imgs):
			cx = pad + k * (cell + 10)
			draw.rectangle((cx, y, cx + cell - 1, y + cell - 1), outline=(48, 50, 56))
			im = tint(img.resize((cell, cell), Image.LANCZOS), color)
			if add:
				additive(sheet, im, (cx, y))
			else:
				sheet.alpha_composite(im, (cx, y))
			draw.text((cx + 6, y + 4), f"{k + 1}", fill=(160, 160, 165), font=f_small)
		y += cell + 14

	label("recon_scan_ring.png  1024x1024", "cyan (normal blend), white, cyan additive (LightEmission 1)")
	ring = tex["recon_scan_ring"]
	row([ring, ring, ring], 470, CYAN)
	y -= 470 + 14
	cx = pad + 480
	sheet.alpha_composite(tint(ring.resize((470, 470), Image.LANCZOS), WHITE), (cx, y))
	additive(sheet, tint(ring.resize((470, 470), Image.LANCZOS), CYAN), (pad + 960, y))
	y += 470 + 26

	label("recon_scan_sphere_2x2.png  1024x1024", "frames 1-4: cyan (normal blend), white, cyan additive")
	fr = frames(tex["recon_scan_sphere_2x2"], 2)
	row(fr, 350, CYAN)
	row(fr, 350, WHITE)
	row(fr, 350, CYAN, add=True)
	y += 12

	label("recon_glow.png 256x256  |  recon_spark.png 256x256", "cyan, white, cyan additive (actual size)")
	for k, (n, col, add) in enumerate([("recon_glow", CYAN, False), ("recon_glow", WHITE, False), ("recon_glow", CYAN, True), ("recon_spark", CYAN, False), ("recon_spark", WHITE, False), ("recon_spark", CYAN, True)]):
		cx = pad + k * 240
		im = tint(tex[n].resize((230, 230), Image.LANCZOS), col)
		draw.rectangle((cx, y, cx + 229, y + 229), outline=(48, 50, 56))
		if add:
			additive(sheet, im, (cx, y))
		else:
			sheet.alpha_composite(im, (cx, y))
	y += 230 + 26

	label("recon_trail.png  512x128", "head at the LEFT; cyan, white (actual size), then cyan at 2x additive")
	tr = tex["recon_trail"]
	sheet.alpha_composite(tint(tr, CYAN), (pad, y))
	sheet.alpha_composite(tint(tr, WHITE), (pad + 530, y))
	y += 128 + 8
	additive(sheet, tint(tr.resize((1024, 256), Image.LANCZOS), CYAN), (pad, y))
	y += 256 + 26

	# Mock pulse: a dart on a wall, the flat ring on the floor in perspective, the shell sprite, the dart's glow and
	# the flight trail coming in (Pillow composite, not a render).
	label("Mock pulse (Pillow composite, not a render)", "floor ring (squashed) + shell frame 3 + echo frame 2 + dart glow, additive; trail and sparks to the right")
	mw, mh = W - 2 * pad, 600
	mock = Image.new("RGBA", (mw, mh), (40, 42, 46, 255))
	md = ImageDraw.Draw(mock)
	horizon = int(mh * 0.55)
	for k in range(mh):
		c0 = int(46 + 16 * k / mh) if k < horizon else int(58 + 30 * (k - horizon) / (mh - horizon))
		md.line((0, k, mw, k), fill=(c0, c0, c0 + 3, 255))
	cx, cy = int(mw * 0.4), int(mh * 0.5)
	md.line((cx - 30, cy + 3, cx + 2, cy), fill=(20, 21, 24, 255), width=5)  # the dart, stuck in the wall
	additive(mock, tint(ring.resize((900, 230), Image.LANCZOS), CYAN), (cx - 450, horizon + 20), 0.9)
	additive(mock, tint(fr[2].resize((520, 520), Image.LANCZOS), CYAN), (cx - 260, cy - 260), 0.9)
	additive(mock, tint(fr[1].resize((300, 300), Image.LANCZOS), CYAN), (cx - 150, cy - 150), 0.5)
	additive(mock, tint(tex["recon_glow"].resize((130, 130), Image.LANCZOS), CYAN), (cx - 65, cy - 65), 1.0)
	additive(mock, tint(tex["recon_glow"].resize((40, 40), Image.LANCZOS), WHITE), (cx - 20, cy - 20), 1.0)
	tx, ty = int(mw * 0.78), int(mh * 0.3)
	additive(mock, tint(tr.resize((300, 40), Image.LANCZOS), CYAN), (tx, ty), 1.0)
	additive(mock, tint(tex["recon_glow"].resize((50, 50), Image.LANCZOS), CYAN), (tx - 25, ty - 5), 1.0)
	rng = random.Random(3)
	sp = tint(tex["recon_spark"], (255, 230, 190))
	for k in range(9):
		n = rng.randint(50, 100)
		s = sp.resize((n, n), Image.LANCZOS).rotate(rng.uniform(0, 360), expand=True, resample=Image.BICUBIC)
		additive(mock, s, (int(mw * 0.82) + rng.randint(-60, 60), int(mh * 0.62) + rng.randint(-50, 50)), 1.0)
	sheet.alpha_composite(mock, (pad, y))
	y += mh + 20

	sheet = sheet.crop((0, 0, W, y + 6))
	PREVIEW.parent.mkdir(parents=True, exist_ok=True)
	sheet.convert("RGB").save(PREVIEW)
	print(f"[recon-vfx] preview {PREVIEW.relative_to(ROOT)}")


if bpy is not None:
	render_main()
elif "--preview" in sys.argv:
	preview_main()
else:
	print(__doc__)
