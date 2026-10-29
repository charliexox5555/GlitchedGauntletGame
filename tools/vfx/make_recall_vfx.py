"""Renders the Recall (teleport anchor) textures with Blender, and their preview sheet.

Render (Blender, headless; about a minute on a 12-core CPU, `--fast` for a quick half-size, low-sample check):

    "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup \
        --python tools/vfx/make_recall_vfx.py -- [names...] [--fast]

Preview contact sheet (plain Python + Pillow + numpy, run after rendering):

    python tools/vfx/make_recall_vfx.py --preview

Look (vault/01 Design/Abilities/Recall.md, "Look"): Chamber's Rendezvous as the quality reference, in this game's clean
tactical style: COOL VIOLET (#9B6BFF is the intended tint), kept apart from Heal Orb green-teal, Frost ice blue, Stim
yellow and fire orange. During the 0.6 s wind-up a violet shimmer of glints and small diamond fragments plays over the
player's body and the screen warps inward; they vanish, and pop out at the anchor with a violet flash and a ring
shockwave. The anchor itself sits in a soft violet ground ring. Crisp, precise light (glints, diamond flecks, thin
lines), not soft healing wisps (Heal Orb) or jagged arcs (Stim). Everything is WHITE with straight alpha (RGBA PNG)
so the game tints it. Output: art-source/vfx/abilities/recall/.

  recall_shimmer_2x2  1024x1024  2x2 flipbook of shimmer clusters for the wind-up (four variants, NOT a growth
                                 sequence: flick through them fast or pick a random frame per particle): four-point
                                 star glints, small diamond-shaped light fragments (a few hollow), tiny specks, and
                                 thin wavy heat-shimmer lines behind them. Each stays inside its cell.
  recall_flash        512x512    the arrival / departure pop: a hot core, a soft round glow and a few sharp streaks of
                                 different lengths (one long horizontal pair, the rest at odd angles).
  recall_ring         1024x1024  top view: a thin crisp ring (r = 0.86 of the half-size) with a soft glow trailing
                                 inward, a faint dashed inner ring and a short glow outside; the centre is clear
                                 (alpha 0 inside r ~ 0.45). Ground glow under the anchor and the arrival shockwave.
  recall_mote         256x256    a small soft glowing mote: hot core, soft halo.
  recall_warp         1024x576   full-screen 16:9 overlay for the wind-up: thin streaks pulling INWARD from the screen
                                 edges toward the centre (speed lines of varying length, tapering as they reach in)
                                 over a faint edge glow; the centre is exactly transparent.

Every texture's outermost pixel rows and columns are alpha 0 (per flipbook cell too), so nothing smears at the edges.

How: everything is a Cycles render of white emission on black. The shimmer is real geometry: small planes (glint,
fragment and speck shaders, placed by a seeded RNG) over a per-cell shimmer-line plane, all additive (Transparent +
Emission) so overlaps add up. The flash, ring, mote and warp are emission maths on one plane. post() then turns
brightness into alpha, adds a gaussian bloom per flipbook cell, and fades the outer pixels of every cell to 0. Seeds
are fixed, so re-running gives the same images.
"""

import math
import random
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art-source" / "vfx" / "abilities" / "recall"
PREVIEW = ROOT / "vault" / "02 Art" / "References" / "abilities" / "recall" / "recall_vfx_preview.png"

try:
	import bpy
except ImportError:  # Plain Python: preview mode only.
	bpy = None

FAST = "--fast" in sys.argv
TAU = math.tau


# Node maths (same helpers as make_stim_vfx.py) --------------------------------------------


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
		self.x = S(self, obj.outputs[0])
		self.y = S(self, obj.outputs[1])
		info = self.node("ShaderNodeObjectInfo")
		self.rand = S(self, info.outputs["Random"])

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

	def exp(self, a):
		return self.math("EXPONENT", a)

	def length(self, a, b):
		return self.sqrt(a * a + b * b)

	def soft(self, d, width):
		"""Gaussian bump: 1 at d=0, ~0 by d=2*width."""
		q = d / width
		return self.exp(-(q * q))

	def smooth(self, value, lo, hi):
		"""Smoothstep from lo (0) to hi (1); lo > hi inverts it. lo/hi may be sockets (then lo < hi)."""
		n = self.node("ShaderNodeMapRange")
		n.interpolation_type = "SMOOTHSTEP"
		n.clamp = True
		self.put(n.inputs["Value"], value)
		flip = not isinstance(lo, S) and not isinstance(hi, S) and lo > hi
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

	def emit(self, strength):
		"""Additive white emission (Transparent + Emission): overlapping planes add up, black stays see-through."""
		em = self.node("ShaderNodeEmission")
		em.inputs["Color"].default_value = (1.0, 1.0, 1.0, 1.0)
		self.put(em.inputs["Strength"], strength)
		tr = self.node("ShaderNodeBsdfTransparent")
		add = self.node("ShaderNodeAddShader")
		self.link(tr.outputs[0], add.inputs[0])
		self.link(em.outputs[0], add.inputs[1])
		out = self.node("ShaderNodeOutputMaterial")
		self.link(add.outputs[0], out.inputs["Surface"])
		return self.mat


def sn(n, gain=4.0):
	"""Perlin fac (about 0.5 +- 0.15) -> signed, roughly -0.8..0.8."""
	return (n - 0.5) * gain


# Shimmer: small planes ------------------------------------------------------------------
# Plane object coordinates run -1..1; the plane's scale sets the size in the cell (cells are 2 units wide).


def glint_mat():
	"""Four-point star glint: a hot core, thin arms tapering to the plane edge (long horizontal, shorter vertical)."""
	g = G("glint")
	x, y = g.x, g.y
	r = g.length(x, y)
	ax, ay = g.abs(x), g.abs(y)

	def arm(along, across, reach, width):
		f = g.clamp01(1.0 - along / reach)
		return g.soft(across, width * (0.25 + 0.75 * f)) * f**2.2

	core = g.soft(r, 0.07) * 1.6 + g.soft(r, 0.2) * 0.35
	arms = arm(ax, ay, 0.98, 0.045) + arm(ay, ax, 0.78, 0.04) * 0.85
	k = 0.70710678
	diag = arm(g.abs((x + y) * k), g.abs((x - y) * k), 0.32, 0.02) + arm(g.abs((x - y) * k), g.abs((x + y) * k), 0.32, 0.02)
	gain = 0.65 + 0.35 * g.rand
	return g.emit((core + arms + diag * 0.4) * gain * g.smooth(r, 1.0, 0.9))


def shard_mat(hollow):
	"""A diamond fragment of light (the plane is stretched tall): solid with a hot centre, or a hollow outline."""
	g = G("shard_hollow" if hollow else "shard")
	q = g.abs(g.x) + g.abs(g.y)  # diamond distance: 1 on the plane's diamond edge
	if hollow:
		body = g.soft(q - 0.78, 0.07) * 0.9 + g.soft(q, 0.25) * 0.15
	else:
		body = g.smooth(q, 0.82, 0.62) * 0.7 + g.soft(q, 0.3) * 0.9
	gain = 0.55 + 0.45 * g.rand
	return g.emit(body * gain)


def speck_mat():
	g = G("speck")
	r = g.length(g.x, g.y)
	return g.emit((g.soft(r, 0.22) * 1.2 + g.soft(r, 0.5) * 0.2) * (0.5 + 0.5 * g.rand) * g.smooth(r, 1.0, 0.85))


def shimmer_lines(i):
	"""Per-cell backdrop: thin wavy heat-shimmer lines rising through the cluster, broken into segments."""
	g = G(f"lines{i}")
	x, y = g.x, g.y
	r = g.length(x, y * 0.85)
	w0 = 11.0 + i * 3.7
	xw = x + sn(g.noise(x * 1.4, y * 2.2, 0.0, w=w0, detail=2.0)) * 0.14
	ln = g.noise(xw * 9.0, y * 0.9, 0.0, w=w0 + 1.0, detail=1.0)
	lines = g.smooth(g.abs(ln - 0.5), 0.022, 0.0)
	seg = g.smooth(g.noise(x * 2.5, y * 3.0, 0.0, w=w0 + 2.0, detail=2.0), 0.48, 0.66)
	haze = g.soft(r, 0.3) * 0.03
	env = g.smooth(r, 0.9, 0.45)
	return g.emit((lines * seg * 0.42 + haze) * env)


SHIMMER = [
	# (seed, glints, solid shards, hollow shards, specks, spread)
	(101, 6, 13, 2, 22, 0.36),
	(202, 5, 15, 1, 26, 0.4),
	(303, 7, 11, 2, 18, 0.34),
	(404, 5, 14, 3, 24, 0.38),
]


def build_shimmer(grid):
	mats = {"glint": glint_mat(), "shard": shard_mat(False), "hollow": shard_mat(True), "speck": speck_mat()}

	def quad(mat, origin, sx, sy, rot, z):
		bpy.ops.mesh.primitive_plane_add(size=2, location=(origin[0], origin[1], z))
		o = bpy.context.active_object
		o.scale = (sx, sy, 1)
		o.rotation_euler = (0, 0, rot)
		o.data.materials.append(mat)
		return o

	def spot(rng, ox, oy, spread, lim):
		while True:
			px, py = rng.gauss(0, spread), rng.gauss(0, spread * 1.15)
			if math.hypot(px, py / 1.1) < lim:
				return ox + px, oy + py

	for i in range(grid * grid):
		col, row = i % grid, i // grid
		ox, oy = (col - (grid - 1) / 2) * 2, ((grid - 1) / 2 - row) * 2
		seed, n_glint, n_shard, n_hollow, n_speck, spread = SHIMMER[i]
		rng = random.Random(seed)
		bpy.ops.mesh.primitive_plane_add(size=2, location=(ox, oy, 0.0))
		bpy.context.active_object.data.materials.append(shimmer_lines(i))
		z = 0.01
		for _ in range(n_glint):
			s = rng.uniform(0.11, 0.26)
			p = spot(rng, ox, oy, spread, 0.95 - s)
			quad(mats["glint"], p, s, s, rng.uniform(-0.12, 0.12), z)
			z += 0.001
		for _ in range(n_shard):
			h = rng.uniform(0.035, 0.085)
			p = spot(rng, ox, oy, spread * 1.1, 0.95 - h)
			quad(mats["shard"], p, h * rng.uniform(0.32, 0.45), h, rng.uniform(-0.35, 0.35), z)
			z += 0.001
		for _ in range(n_hollow):
			h = rng.uniform(0.06, 0.1)
			p = spot(rng, ox, oy, spread, 0.95 - h)
			quad(mats["hollow"], p, h * 0.6, h, rng.uniform(-0.2, 0.2), z)
			z += 0.001
		for _ in range(n_speck):
			s = rng.uniform(0.014, 0.03)
			p = spot(rng, ox, oy, spread * 1.25, 0.95 - s)
			quad(mats["speck"], p, s, s, 0.0, z)
			z += 0.001


# Plane shaders ----------------------------------------------------------------------------

FLASH_RAYS = [
	# (angle deg, reach, width, gain): a long horizontal pair, then shorter streaks at odd angles
	(0, 0.97, 0.022, 1.0),
	(180, 0.93, 0.022, 1.0),
	(90, 0.58, 0.018, 0.75),
	(270, 0.5, 0.018, 0.7),
	(28, 0.46, 0.012, 0.55),
	(152, 0.4, 0.012, 0.5),
	(214, 0.52, 0.012, 0.55),
	(327, 0.42, 0.012, 0.5),
]


def flash(g, _i):
	"""Arrival / departure pop: hot core, soft round glow, a few sharp streaks."""
	x, y = g.x, g.y
	r = g.length(x, y)
	core = g.soft(r, 0.06) * 2.0 + g.soft(r, 0.16) * 0.7
	glow = g.soft(r, 0.36) * 0.32 + g.soft(r, 0.62) * 0.08
	rays = 0.0
	for ang, reach, width, gain in FLASH_RAYS:
		a = math.radians(ang)
		along = x * math.cos(a) + y * math.sin(a)
		across = g.abs(y * math.cos(a) - x * math.sin(a))
		f = g.clamp01(1.0 - along / reach) * g.smooth(along, -0.02, 0.04)
		rays = rays + g.soft(across, width * (0.2 + 0.8 * f)) * f**1.6 * gain
	return g.emit((core + glow + rays) * g.smooth(r, 1.0, 0.9))


RING_R = 0.86


def ring(g, _i):
	"""Top-view ring: thin crisp edge, soft glow trailing inward, a faint dashed inner ring, clear centre."""
	x, y = g.x, g.y
	r = g.length(x, y)
	a = g.atan2(y, x)
	ca, sa = g.cos(a), g.sin(a)
	d = r - RING_R
	edge = g.soft(d, 0.0045) * 1.1 + g.soft(d, 0.013) * 0.32
	behind = g.clamp01(-d)
	inside = g.smooth(d, 0.004, -0.004)
	trail = (g.exp(behind * -14.0) * 0.2 + g.exp(behind * -4.0) * 0.06) * inside
	outside = g.exp(g.clamp01(d) * -60.0) * 0.12 * g.smooth(d, -0.004, 0.004)
	# Faint dashed inner ring: 36 dashes (integer, so it closes), with soft ends.
	dash = g.smooth(g.sin(a * 36.0), 0.15, 0.6)
	inner = g.soft(r - RING_R * 0.9, 0.004) * dash * 0.4
	var = 0.82 + 0.3 * g.smooth(g.noise(ca * 1.8, sa * 1.8, 0.0, w=21.0, detail=2.0), 0.3, 0.7)
	keep = g.smooth(r, 0.99, 0.95) * g.smooth(r, 0.45, 0.62)
	return g.emit((edge + trail + outside + inner) * var * keep)


def mote(g, _i):
	r = g.length(g.x, g.y)
	core = g.soft(r, 0.07) * 1.5 + g.soft(r, 0.16) * 0.5
	halo = g.soft(r, 0.36) * 0.2 + g.soft(r, 0.6) * 0.05
	return g.emit((core + halo) * g.smooth(r, 0.99, 0.85))


WARP_A = 16 / 9


def edge_d(g):
	"""0 in the middle, ~1 at the edge middles, more in the corners (superellipse p = 2.6)."""
	ex, ey = g.abs(g.x) / WARP_A, g.abs(g.y)
	return (ex**2.6 + ey**2.6) ** (1 / 2.6)


def warp(g, _i):
	"""Streaks pulling inward from the screen edges: radial speed lines of varying length over a faint edge glow."""
	x, y = g.x, g.y
	d = edge_d(g)
	a = g.atan2(y, x)
	ca, sa = g.cos(a), g.sin(a)
	clear = g.smooth(d, 0.36, 0.56)  # exactly zero in the middle

	def streaks(freq, w, thresh, gain, reach):
		# Thin lines along the radius: high frequency around the angle, almost none along the radius.
		n = g.noise(ca * freq, sa * freq, d * 0.35, w=w, detail=1.0)
		line = g.smooth(n, thresh, thresh + 0.045)
		# Each streak reaches in a different distance (another angular noise), tapering at its inner end.
		start = reach + sn(g.noise(ca * freq * 0.5, sa * freq * 0.5, 0.0, w=w + 0.5, detail=1.0), 2.4) * 0.22
		taper = g.smooth(d, start, start + 0.3)
		return line * taper * gain

	lines = streaks(70.0, 31.0, 0.6, 0.55, 0.6) + streaks(130.0, 37.0, 0.61, 0.4, 0.72) + streaks(40.0, 43.0, 0.64, 0.4, 0.5)
	glow = g.smooth(d, 0.72, 1.3) ** 2.0 * 0.24
	return g.emit((lines + glow) * clear)


# Sheets -------------------------------------------------------------------------------
# name: (width, height, grid, plane shader or "shimmer", bloom [(sigma px at full size, weight)], alpha gain)

SHEETS = {
	"recall_shimmer_2x2": (1024, 1024, 2, "shimmer", [(2.5, 0.55), (10.0, 0.5)], 1.0),
	"recall_flash": (512, 512, 1, flash, [(4.0, 0.3), (16.0, 0.25)], 1.0),
	"recall_ring": (1024, 1024, 1, ring, [(3.0, 0.35), (12.0, 0.3)], 1.0),
	"recall_mote": (256, 256, 1, mote, [], 1.0),
	"recall_warp": (1024, 576, 1, warp, [(2.0, 0.3), (8.0, 0.25)], 0.85),
}


def setup_scene(width, height, ortho, samples):
	bpy.ops.wm.read_factory_settings(use_empty=True)
	scene = bpy.context.scene
	scene.render.engine = "CYCLES"
	scene.cycles.device = "CPU"
	scene.cycles.samples = max(8, samples // 4) if FAST else samples
	scene.cycles.seed = 7
	scene.cycles.use_denoising = False
	scene.cycles.transparent_max_bounces = 64
	scene.render.film_transparent = False
	scene.render.resolution_x = width
	scene.render.resolution_y = height
	scene.render.resolution_percentage = 50 if FAST else 100
	scene.view_settings.view_transform = "Standard"
	scene.view_settings.look = "None"
	scene.render.image_settings.file_format = "OPEN_EXR"
	scene.render.image_settings.color_depth = "32"
	scene.render.image_settings.color_mode = "RGB"
	world = bpy.data.worlds.new("black")
	world.use_nodes = True
	world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.0
	scene.world = world
	cam_data = bpy.data.cameras.new("cam")
	cam_data.type = "ORTHO"
	cam_data.ortho_scale = ortho
	cam_data.clip_end = 100
	cam = bpy.data.objects.new("cam", cam_data)
	cam.location = (0, 0, 10)
	scene.collection.objects.link(cam)
	scene.camera = cam
	return scene


def gauss_blur(a, sigma):
	"""Gaussian blur by FFT with zero padding."""
	import numpy as np

	h, w = a.shape
	p = int(3 * sigma) + 1
	b = np.pad(a, ((p, p), (p, p)))
	H, W = b.shape
	fy = np.fft.fftfreq(H)[:, None]
	fx = np.fft.rfftfreq(W)[None, :]
	k = np.exp(-2 * (math.pi**2) * sigma * sigma * (fx * fx + fy * fy))
	out = np.fft.irfft2(np.fft.rfft2(b) * k, s=(H, W))
	return out[p : p + h, p : p + w]


def post(src, dst, grid, blooms, gain):
	"""Emission render on black (linear EXR) -> white straight-alpha RGBA PNG: alpha = (brightness + bloom) * gain,
	blurred per flipbook cell (nothing bleeds into the next frame), outer pixels of every cell faded to exactly 0."""
	import numpy as np

	img = bpy.data.images.load(str(src))
	w, h = img.size
	px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
	bpy.data.images.remove(img)
	lum = np.clip(px[..., :3].max(axis=-1), 0.0, 4.0)
	scale = 0.5 if FAST else 1.0
	total = np.minimum(lum, 1.0)
	ch, cw = h // grid, w // grid
	for sigma, k in blooms:
		for row in range(grid):
			for col in range(grid):
				cell = lum[row * ch : (row + 1) * ch, col * cw : (col + 1) * cw]
				total[row * ch : (row + 1) * ch, col * cw : (col + 1) * cw] += gauss_blur(cell, sigma * scale) * k
	alpha = np.clip(total * gain, 0.0, 1.0)
	m = np.ones((ch, cw), np.float32)
	e = max(3, int(6 * scale))
	ramp = np.linspace(0.0, 1.0, e)
	m[:e, :] *= ramp[:, None]
	m[-e:, :] *= ramp[::-1, None]
	m[:, :e] *= ramp[None, :]
	m[:, -e:] *= ramp[None, ::-1]
	alpha *= np.tile(m, (grid, grid))
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


def render_sheet(name):
	width, height, grid, shader, blooms, gain = SHEETS[name]
	aspect = width / height
	scene = setup_scene(width, height, 2 * grid * aspect, 64)
	if shader == "shimmer":
		build_shimmer(grid)
	else:
		bpy.ops.mesh.primitive_plane_add(size=2)
		plane = bpy.context.active_object
		if aspect != 1:
			plane.scale = (aspect, 1, 1)
			bpy.ops.object.transform_apply(scale=True)  # object coordinates in -aspect..aspect, -1..1
		plane.data.materials.append(shader(G(name), 0))
	raw = OUT / f"_{name}.exr"
	path = OUT / f"{name}.png"
	scene.render.filepath = str(raw)
	bpy.ops.render.render(write_still=True)
	post(raw, path, grid, blooms, gain)
	raw.unlink()
	print(f"[recall-vfx] {path.relative_to(ROOT)}")
	return path


def render_main():
	argv = [a for a in (sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []) if not a.startswith("--")]
	OUT.mkdir(parents=True, exist_ok=True)
	for name in argv or list(SHEETS):
		render_sheet(name)


# Preview (plain Python + Pillow) -----------------------------------------------

BG = (34, 36, 40)
VIOLET = (0x9B, 0x6B, 0xFF)
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
		a = np.asarray(img, np.float32).copy()
		a[..., :3] *= np.array(color, np.float32) / 255.0
		return Image.fromarray(a.clip(0, 255).astype("uint8"), "RGBA")

	def additive(dst, img, pos, gain=1.0):
		"""Composite like Roblox LightEmission = 1 (colour * alpha added)."""
		x, y = pos
		x0, y0 = max(x, 0), max(y, 0)
		x1, y1 = min(x + img.width, dst.width), min(y + img.height, dst.height)
		if x1 <= x0 or y1 <= y0:
			return
		img = img.crop((x0 - x, y0 - y, x1 - x, y1 - y))
		region = dst.crop((x0, y0, x1, y1)).convert("RGB")
		a = np.asarray(img, dtype=np.float32) / 255.0
		b = np.asarray(region, dtype=np.float32) / 255.0
		out = np.clip(b + a[..., :3] * a[..., 3:4] * gain, 0, 1)
		dst.paste(Image.fromarray((out * 255).astype("uint8"), "RGB"), (x0, y0))

	tex = {n: Image.open(OUT / f"{n}.png").convert("RGBA") for n in SHEETS}
	W, pad, H = 1500, 24, 8000
	sheet = Image.new("RGBA", (W, H), (*BG, 255))
	draw = ImageDraw.Draw(sheet)
	draw.text((pad, 16), "Recall VFX textures on dark grey: cool violet #9B6BFF and white (normal alpha blend unless noted)", fill=(235, 235, 235), font=f_title)
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

	label("recall_shimmer_2x2.png  1024x1024", "frames 1-4: violet (normal blend), white, violet additive (LightEmission 1)")
	row(frames(tex["recall_shimmer_2x2"], 2), 345, VIOLET)
	row(frames(tex["recall_shimmer_2x2"], 2), 345, WHITE)
	row(frames(tex["recall_shimmer_2x2"], 2), 345, VIOLET, add=True)
	y += 10

	label("recall_flash.png  512x512", "violet, white, violet additive")
	fl = tex["recall_flash"].resize((440, 440), Image.LANCZOS)
	sheet.alpha_composite(tint(fl, VIOLET), (pad, y))
	sheet.alpha_composite(tint(fl, WHITE), (pad + 470, y))
	additive(sheet, tint(fl, VIOLET), (pad + 940, y))
	y += 440 + 26

	label("recall_ring.png  1024x1024", "violet and white on dark grey, then violet additive on a concrete-grey floor")
	g = tex["recall_ring"].resize((460, 460), Image.LANCZOS)
	sheet.alpha_composite(tint(g, VIOLET), (pad, y))
	sheet.alpha_composite(tint(g, WHITE), (pad + 480, y))
	floor = Image.new("RGBA", (460, 460), (110, 108, 104, 255))
	sheet.alpha_composite(floor, (pad + 960, y))
	additive(sheet, tint(g, VIOLET), (pad + 960, y))
	y += 460 + 26

	label("recall_mote.png  256x256", "violet, white, violet additive; then half size")
	s = tex["recall_mote"]
	sheet.alpha_composite(tint(s, VIOLET), (pad, y))
	sheet.alpha_composite(tint(s, WHITE), (pad + 270, y))
	additive(sheet, tint(s, VIOLET), (pad + 540, y))
	sheet.alpha_composite(tint(s.resize((128, 128), Image.LANCZOS), VIOLET), (pad + 810, y + 64))
	y += 256 + 26

	label("recall_warp.png  1024x576", "violet over a mid-grey 'screen' (1280x720 here) with a crosshair, normal blend")
	scr = Image.new("RGBA", (1280, 720), (128, 128, 128, 255))
	sd = ImageDraw.Draw(scr)
	for k in range(720):
		c0 = int(140 - 50 * k / 720)
		sd.line((0, k, 1280, k), fill=(c0, c0, c0 + 4, 255))
	sd.line((640 - 12, 360, 640 + 12, 360), fill=(255, 255, 255, 255), width=2)
	sd.line((640, 360 - 12, 640, 360 + 12), fill=(255, 255, 255, 255), width=2)
	scr.alpha_composite(tint(tex["recall_warp"].resize((1280, 720), Image.LANCZOS), VIOLET))
	sheet.alpha_composite(scr, (pad, y))
	y += 720 + 20

	# Mock: wind-up (a player silhouette with shimmer frames over it) | arrival (flash + ring shockwave at the anchor).
	label("Mock composite (Pillow, not a render)", "left: wind-up shimmer on a player; right: arrival flash + ring at the anchor (ground ring under it); all additive")
	mw, mh = W - 2 * pad, 640
	mock = Image.new("RGBA", (mw, mh), (60, 62, 64, 255))
	md = ImageDraw.Draw(mock)
	for k in range(mh):
		cc = int(30 + 44 * k / mh)
		md.line((0, k, mw, k), fill=(cc, cc, cc + 3, 255))
	floor_y = int(mh * 0.82)
	ring_img = tint(tex["recall_ring"], VIOLET)
	# Left: the player.
	px_ = mw // 4
	md.rounded_rectangle((px_ - 45, floor_y - 300, px_ + 45, floor_y - 120), 24, fill=(52, 54, 60, 255))
	md.ellipse((px_ - 34, floor_y - 370, px_ + 34, floor_y - 302), fill=(56, 58, 64, 255))
	md.rounded_rectangle((px_ - 40, floor_y - 125, px_ - 6, floor_y), 10, fill=(46, 48, 54, 255))
	md.rounded_rectangle((px_ + 6, floor_y - 125, px_ + 40, floor_y), 10, fill=(46, 48, 54, 255))
	sh = frames(tex["recall_shimmer_2x2"], 2)
	rng = random.Random(5)
	for k in range(9):
		sz = rng.randint(110, 170)
		cx_, cy_ = px_ + rng.randint(-40, 40), floor_y - rng.randint(40, 340)
		additive(mock, tint(sh[k % 4].resize((sz, sz), Image.LANCZOS), VIOLET), (cx_ - sz // 2, cy_ - sz // 2), 0.9)
	mt = tint(tex["recall_mote"], VIOLET)
	for k in range(14):
		sz = rng.randint(14, 34)
		additive(mock, mt.resize((sz, sz), Image.LANCZOS), (px_ + rng.randint(-90, 80), floor_y - rng.randint(0, 420)))
	additive(mock, ring_img.resize((300, 80), Image.LANCZOS), (px_ - 150, floor_y - 40), 0.5)
	# Right: the anchor with its ground ring, the arrival flash and shockwave.
	ax_ = mw * 3 // 4 - 60
	additive(mock, ring_img.resize((260, 70), Image.LANCZOS), (ax_ - 130, floor_y - 35), 0.9)
	md.polygon([(ax_ - 30, floor_y), (ax_ + 30, floor_y), (ax_ + 22, floor_y - 70), (ax_ - 22, floor_y - 70)], fill=(40, 41, 46, 255))
	md.polygon([(ax_, floor_y - 120), (ax_ + 12, floor_y - 98), (ax_, floor_y - 76), (ax_ - 12, floor_y - 98)], fill=(190, 160, 255, 255))
	additive(mock, ring_img.resize((620, 170), Image.LANCZOS), (ax_ - 310, floor_y - 85), 0.8)
	fl = tint(tex["recall_flash"], VIOLET).resize((460, 460), Image.LANCZOS)
	additive(mock, fl, (ax_ - 230, floor_y - 200 - 230), 1.0)
	for k in range(10):
		sz = rng.randint(14, 30)
		additive(mock, mt.resize((sz, sz), Image.LANCZOS), (ax_ + rng.randint(-200, 200), floor_y - rng.randint(60, 360)))
	sheet.alpha_composite(mock, (pad, y))
	y += mh + 20

	sheet = sheet.crop((0, 0, W, y + 6))
	PREVIEW.parent.mkdir(parents=True, exist_ok=True)
	sheet.convert("RGB").save(PREVIEW)
	print(f"[recall-vfx] preview {PREVIEW.relative_to(ROOT)}")


if bpy is not None:
	render_main()
elif "--preview" in sys.argv:
	preview_main()
else:
	print(__doc__)
