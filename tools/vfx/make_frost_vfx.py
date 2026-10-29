"""Renders the Frost (cryo burst / Hinder) textures with Blender, and their preview sheet.

Render (Blender, headless; a few minutes on a 12-core CPU, `--fast` for a quick half-size, low-sample check):

    "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup \
        --python tools/vfx/make_frost_vfx.py -- [names...] [--fast]

Preview contact sheet (plain Python + Pillow + numpy, run after rendering):

    python tools/vfx/make_frost_vfx.py --preview

Look (vault/01 Design/Abilities/Frost.md, "Look"): Waylay's Saturate as the quality reference, in this game's plain,
realistic tactical style: a cold, crystalline burst (icy flash + needles + a jagged shock ring), cold mist billowing
out, feathery frost spreading on the floor, ice shards and glints, frost crystals and mist on hindered bodies, a
frosted screen edge for the hindered player, and a thin vapour trail. Everything is WHITE / greyscale with straight
alpha (RGBA PNG) so the game tints it (ice blue #BFE8FF is the intended tint); only the mist and the crystals carry
shading in their RGB (lit renders), which tinting keeps. Output goes to art-source/vfx/abilities/frost/.

  frost_mist_2x2     1024x1024  2x2 flipbook: a cold mist puff (lit Cycles volume) billowing out and thinning into
                                wisps over the 4 frames. Light grey-white shading.
  frost_burst_2x2    1024x1024  2x2 flipbook (camera-facing): the icy burst: a white flash with crystal needles, a
                                jagged shock ring with shattered-ice facets inside it, glints; it expands and breaks
                                up over the 4 frames. White, alpha = brightness.
  frost_ground       1024x1024  top-down floor decal: feathery ice crystals (hexagonal 60-degree side branches)
                                radiating from the centre over a mottled frost haze; ragged soft edge, alpha 0 at
                                the border. White.
  frost_shard        256x256    one sharp ice glint: hot core, four long thin rays, four short diagonals, soft halo.
  frost_crystals     512x512    a cluster of small faceted ice crystals (hexagonal prisms with points) radiating from
                                the centre, lit render with bright rim edges and a faint frost haze. Greyscale.
  frost_vignette     1024x576   full-screen 16:9 overlay: frosted haze and frost feathers growing in from the edges,
                                densest in the corners; the centre is exactly transparent. White.
  frost_vapor        512x128    a thin, soft vapour wisp lying along u (streaky, wavy), fading out at both ends and
                                both edges. White. For a Trail (TextureMode Stretch) and held-canister vapour.

How: every texture is a Cycles render. The mist is a lit volume; the burst, ground, vignette and shard are emission
rendered on black and turned into white + alpha afterwards (glow_post: alpha = brightness); the frost feathers are
real curves (a deterministic dendrite growth: main branches with 60-degree side branches, like real hoarfrost); the
crystals are lit meshes on a transparent film. Seeds are fixed, so re-running gives the same images.
"""

import math
import random
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art-source" / "vfx" / "abilities" / "frost"
PREVIEW = ROOT / "vault" / "02 Art" / "References" / "abilities" / "frost" / "frost_vfx_preview.png"

try:
	import bpy
except ImportError:  # Plain Python: preview mode only.
	bpy = None

FAST = "--fast" in sys.argv


# Node maths (same helpers as make_molly_vfx.py, plus Voronoi and the surface normal) ---------------


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


# Frost feathers (dendrites) --------------------------------------------------------------
# Real hoarfrost grows as feathers: a main stem with side branches at about 60 degrees (ice is hexagonal), and
# smaller branches off those. grow() walks a stem with a slight wander and spawns side branches on both sides; the
# polylines become one Blender curve with a diamond bevel (a ridge, brighter along its spine).


def grow(out, rng, p, ang, length, width, depth, step=0.016, wander=0.05, branch=0.8, side_len=(0.1, 0.2)):
	n = max(3, int(length / step))
	st = length / n
	pts = [(p[0], p[1], width)]
	x, y = p
	side = 1 if rng.random() < 0.5 else -1
	for i in range(n):
		ang += rng.gauss(0, wander)
		x += st * math.cos(ang)
		y += st * math.sin(ang)
		f = (i + 1) / n
		w = width * (1.0 - f) ** 0.6 + width * 0.08
		pts.append((x, y, w))
		if depth > 0 and 0 < i < n - 1:
			for s in (side, -side):
				if rng.random() < branch:
					sub = length * rng.uniform(*side_len) * (1.0 - f) ** 0.6 + st
					a = ang + s * math.radians(rng.gauss(60, 7))
					grow(out, rng, (x, y), a, sub, w * 0.62, depth - 1, step * 0.8, wander * 1.2, branch * 0.8, side_len)
			side = -side
	out.append(pts)


def make_curves(name, polylines, mat, z=0.0, base=0.004):
	cu = bpy.data.curves.new(name, "CURVE")
	cu.dimensions = "3D"
	cu.bevel_depth = base
	cu.bevel_resolution = 0  # diamond section: a ridge seen from above
	cu.use_fill_caps = True
	for pl in polylines:
		sp = cu.splines.new("POLY")
		sp.points.add(len(pl) - 1)
		for pt, (x, y, w) in zip(sp.points, pl):
			pt.co = (x, y, z, 1.0)
			pt.radius = w / base
		sp.use_smooth = True
	cu.materials.append(mat)
	ob = bpy.data.objects.new(name, cu)
	bpy.context.scene.collection.objects.link(ob)
	return ob


def feather_mat(name, mask=None, gain=1.0):
	"""Ice ridges: bright along the spine (normal facing the camera), dimmer on the flanks."""
	g = G(name)
	ridge = 0.45 + 0.55 * g.clamp01(g.normal_z()) ** 2.0
	strength = ridge * gain
	if mask is not None:
		strength = strength * mask(g)
	return g.emit(strength)


# Textures --------------------------------------------------------------------------
# Plane coordinates: -1..1 (times the aspect in x), +y = up in the image.

MIST = [
	# (radius, density, holes threshold, warp, rise)
	(0.36, 6.0, 0.0, 0.35, -0.04),
	(0.47, 3.6, 0.3, 0.45, -0.01),
	(0.55, 2.1, 0.4, 0.5, 0.02),
	(0.61, 1.15, 0.46, 0.55, 0.04),
]


def mist(g, i):
	"""Cold mist: soft rounded billows on a warped ball, rolling outward and tearing into wisps."""
	size, dens, holes_at, warp_k, rise = MIST[i]
	seed = 71.0 + i * 0.22  # neighbouring frames share structure
	x0, y0, z0 = g.x, g.y - rise, g.z * 1.25
	warp = size * warp_k
	# Two-level domain warp: big rolling lobes, then curling wisps.
	wx = sn(g.noise(x0 * 1.6, y0 * 1.6, z0 * 1.6, w=seed + 50.0, detail=2.0))
	wy = sn(g.noise(x0 * 1.6, y0 * 1.6, z0 * 1.6, w=seed + 60.0, detail=2.0))
	wz = sn(g.noise(x0 * 1.6, y0 * 1.6, z0 * 1.6, w=seed + 70.0, detail=2.0))
	x1, y1, z1 = x0 + wx * warp * 0.5, y0 + wy * warp * 0.5, z0 + wz * warp * 0.5
	cx = sn(g.noise(x1 * 4.0, y1 * 4.0, z1 * 4.0, w=seed + 80.0, detail=2.0))
	cy = sn(g.noise(x1 * 4.0, y1 * 4.0, z1 * 4.0, w=seed + 90.0, detail=2.0))
	x, y, z = x1 + cx * warp * 0.14 * (1 + i * 0.4), y1 + cy * warp * 0.14 * (1 + i * 0.4), z1
	d = g.sqrt(x * x + (y * 1.12) * (y * 1.12) + z * z) - size
	# Softer billows than smoke (mist is finer): low-weight lobes plus a wispy fBm.
	b1 = g.abs(sn(g.noise(x * 2.2, y * 2.2, z * 2.2, w=seed + 7.0, detail=1.0)))
	b2 = g.abs(sn(g.noise(x * 5.0, y * 5.0, z * 5.0, w=seed + 8.0, detail=1.0)))
	fb = sn(g.noise(x * 7.0, y * 7.0, z * 7.0, w=seed + 9.0, detail=4.0, rough=0.6))
	d = d - size * (b1 * 0.42 + b2 * 0.15 + fb * 0.1) + size * 0.24
	soft = size * (0.16 + 0.08 * i)
	density = g.smooth(d, soft, -soft)
	# Fine streaky texture inside so it reads as vapour, not cotton.
	streak = g.noise(x * 9.0, y * 3.0, z * 9.0, w=seed + 11.0, detail=3.0, rough=0.6)
	density = density * (0.55 + 0.9 * g.smooth(streak, 0.3, 0.7))
	if holes_at > 0:
		hole = g.noise(x * 2.4, y * 2.4, z * 2.4, w=seed + 13.0, detail=3.0, rough=0.55)
		density = density * g.smooth(hole, holes_at, holes_at + 0.22)
	keep = g.smooth(g.length(g.x, g.y), 0.97, 0.72)
	return g.volume(density * keep * dens, 0.97)


BURST = [
	# (front radius, spike reach, core flash, hollow centre, overall, break-up)
	(0.2, 0.26, 1.0, 0.0, 1.0, 0.0),
	(0.4, 0.4, 0.5, 0.4, 0.95, 0.0),
	(0.55, 0.38, 0.14, 0.62, 0.78, 0.3),
	(0.66, 0.3, 0.0, 0.76, 0.55, 0.55),
]


def burst(g, i):
	"""The icy burst, camera-facing: a flash, then a spiky crystalline front (ice shards radiating out of a jagged
	shock ring) that expands, hollows out and shatters; faint facet lines and glints."""
	ring_r, reach, core_k, hollow, gain, breakup = BURST[i]
	x, y = g.x, g.y
	r = g.length(x, y)
	a = g.atan2(y, x)
	ca, sa = g.cos(a), g.sin(a)
	w0 = 3.0  # shared seed: every frame has the same shards, they grow outward

	def peaks(freq, w, lo, sharp):
		n = g.noise(ca * freq, sa * freq, 0.0, w=w, detail=1.0)
		return g.clamp01((n - lo) * 3.4) ** sharp

	# Outline of the shard star: big shards, smaller ones between, a little ragged noise.
	L = ring_r * 0.82 + reach * (peaks(6.0, w0 + 1.0, 0.43, 2.2) + 0.5 * peaks(13.0, w0 + 2.0, 0.46, 2.0))
	L = L + sn(g.noise(ca * 25.0, sa * 25.0, 0.0, w=w0 + 3.0, detail=2.0)) * 0.012
	q = r / L
	inside = g.smooth(L - r, 0.0, 0.02)
	# Brighter toward the front (a shock front), hollowing out in the middle on later frames.
	body = inside * (0.18 + 0.82 * g.clamp01(q) ** 2.2)
	if hollow > 0:
		body = body * g.smooth(q, hollow - 0.25, hollow + 0.1)
	# Ridges along each shard (thin radial lines) and a crisp bright rim.
	ridge_n = g.noise(ca * 18.0, sa * 18.0, r * 0.6, w=w0 + 4.0, detail=1.0)
	ridges = g.smooth(g.abs(ridge_n - 0.5), 0.025, 0.0) * inside * g.smooth(q, 0.3, 0.8) * 0.5
	rim = g.soft(L - r, 0.012) * 0.9 * g.smooth(r, 0.02, 0.1)
	# Faint facet lines (fractured ice) in the outer band.
	fac, _ = g.voronoi(x * 7.0, y * 7.0, 0.0, "DISTANCE_TO_EDGE")
	facets = g.smooth(fac, 0.03, 0.0) * inside * g.smooth(q, 0.45, 0.85) * 0.35
	shards = body + ridges + rim + facets
	if breakup > 0:
		bn = g.noise(x * 5.0, y * 5.0, 0.0, w=w0 + 5.0, detail=3.0, rough=0.55)
		shards = shards * g.smooth(bn, 0.3 + 0.25 * breakup, 0.42 + 0.25 * breakup)
	core = g.soft(r, 0.085 + 0.03 * i) * core_k * 1.7 + g.soft(r, 0.26) * core_k * 0.4
	# Frosty haze behind the front.
	mott = g.noise(x * 4.0, y * 4.0, 0.0, w=w0 + 6.0, detail=4.0, rough=0.6)
	haze = g.smooth(r, ring_r * 1.1, ring_r * 0.3) * (0.06 + 0.12 * g.smooth(mott, 0.35, 0.7)) * (1.0 - 0.6 * i / 3)
	# Glints: small sparks scattered around the front and just beyond it.
	gd, gr = g.voronoi(x * 24.0, y * 24.0, 7.0 + i * 0.37, "F1")
	glint = g.smooth(gd, 0.1, 0.0) * g.smooth(gr, 0.87, 0.9) * g.soft(r - ring_r - reach * 0.4, 0.2) * 1.5
	keep = g.smooth(r, 0.99, 0.9)
	return g.emit((core + shards + haze + glint) * gain * keep)


def ground_haze(g, _i):
	"""Under the feathers: a mottled frost coat, denser in the middle, faint radial streaks, fine frost grain."""
	x0, y0 = g.x, g.y
	wx = sn(g.noise(x0 * 1.5, y0 * 1.5, 0.0, w=1.0, detail=3.0))
	wy = sn(g.noise(x0 * 1.5, y0 * 1.5, 0.0, w=2.0, detail=3.0))
	x, y = x0 + wx * 0.1, y0 + wy * 0.1
	r = g.length(x, y)
	a = g.atan2(y, x)
	ca, sa = g.cos(a), g.sin(a)
	lobes = sn(g.noise(ca * 1.2, sa * 1.2, 0.0, w=3.0, detail=2.0))
	mid = sn(g.noise(ca * 4.0, sa * 4.0, 0.0, w=4.0, detail=3.0))
	edge = 0.66 + lobes * 0.12 + mid * 0.05
	rr = r / edge
	mottle = g.noise(x * 4.5, y * 4.5, 0.0, w=13.0, detail=5.0, rough=0.62)
	coat = g.smooth(rr, 1.05, 0.05) * (0.2 + 0.36 * g.smooth(mottle, 0.33, 0.68)) + g.soft(r, 0.2) * 0.25
	# Faint ice plates (fractured frost) in the coat.
	pl, _ = g.voronoi(x * 9.0, y * 9.0, 0.0, "DISTANCE_TO_EDGE")
	coat = coat + g.smooth(pl, 0.025, 0.0) * g.smooth(rr, 0.95, 0.3) * 0.14
	streak_n = g.noise(ca * 40.0, sa * 40.0, r * 2.5, w=5.0, detail=2.0)
	streaks = g.smooth(streak_n, 0.58, 0.68) * g.smooth(rr, 1.1, 0.25) * 0.22
	gd, gr = g.voronoi(x * 70.0, y * 70.0, 0.0, "F1")
	grain = g.smooth(gd, 0.22, 0.0) * g.smooth(gr, 0.55, 0.75) * g.smooth(rr, 1.25, 0.5) * 0.35
	keep = g.smooth(g.length(x0, y0), 0.99, 0.86)
	return g.emit((coat + streaks + grain) * keep)


def ground_feathers():
	rng = random.Random(1907)
	lines = []
	n_main = 26
	for k in range(n_main):
		ang = (k + rng.uniform(-0.4, 0.4)) / n_main * math.tau
		length = rng.uniform(0.38, 0.8)
		start = rng.uniform(0.03, 0.16)
		grow(lines, rng, (start * math.cos(ang), start * math.sin(ang)), ang, length, rng.uniform(0.006, 0.008), 2, step=0.012, wander=0.07, branch=0.85, side_len=(0.12, 0.22))
	# Secondary feathers starting further out, at odd angles (frost doesn't grow in a perfect star).
	for k in range(40):
		ang = rng.uniform(0, math.tau)
		r0 = rng.uniform(0.15, 0.55)
		grow(lines, rng, (r0 * math.cos(ang), r0 * math.sin(ang)), ang + rng.gauss(0, 0.6), rng.uniform(0.1, 0.28), rng.uniform(0.004, 0.006), 2, step=0.01, wander=0.08, branch=0.85, side_len=(0.14, 0.26))
	# Loose fragments around the rim (the ragged edge): short feathers, random directions.
	for k in range(28):
		ang = rng.uniform(0, math.tau)
		r0 = rng.uniform(0.55, 0.78)
		grow(lines, rng, (r0 * math.cos(ang), r0 * math.sin(ang)), ang + rng.gauss(0, 0.9), rng.uniform(0.04, 0.11), 0.0035, 1, step=0.008, wander=0.1, branch=0.8, side_len=(0.15, 0.3))
	return lines


def ground_mask(g):
	return g.smooth(g.length(g.x, g.y), 0.99, 0.9)


def shard(g, _i):
	"""A sharp ice glint: core, four long rays (vertical a touch longer), four short diagonals, soft halo."""
	x, y = g.x, g.y
	r = g.length(x, y)
	ax, ay = g.abs(x), g.abs(y)

	def ray(along, across, reach, width):
		f = g.clamp01(1.0 - along / reach)
		return g.soft(across, width * (0.15 + 0.85 * f)) * f**2.2

	h = ray(ax, ay, 0.9, 0.022)
	v = ray(ay, ax, 0.98, 0.022)
	k = 0.70710678
	d1 = g.abs((x + y) * k)
	d2 = g.abs((x - y) * k)
	diag = ray(d2, d1, 0.42, 0.016) + ray(d1, d2, 0.42, 0.016)
	core = g.soft(r, 0.05) * 1.4 + g.soft(r, 0.14) * 0.45
	halo = g.soft(r, 0.38) * 0.14
	alpha = core + h + v + diag * 0.55 + halo
	return g.output(alpha * g.smooth(r, 0.99, 0.9), 1.0)


def vignette_d(g):
	"""0 in the middle, ~1 at the edge middles, more in the corners (a superellipse, p = 2.6, so the corners
	frost over first), with an irregular wobble so the clear area isn't a rounded rectangle."""
	A = 16 / 9
	ex, ey = g.abs(g.x) / A, g.abs(g.y)
	return (ex**2.6 + ey**2.6) ** (1 / 2.6) + vignette_wobble(g)


def vignette_haze(g, _i):
	"""Frosted glass at the screen edges: patchy haze that thickens toward the border and corners."""
	x, y = g.x, g.y
	dd = vignette_d(g)
	mottle = g.noise(x * 3.0, y * 3.0, 0.0, w=22.0, detail=5.0, rough=0.62)
	patches = g.noise(x * 1.2, y * 1.2, 0.0, w=24.0, detail=2.0)
	crys, _ = g.voronoi(x * 9.0, y * 9.0, 0.0, "DISTANCE_TO_EDGE")
	facets = g.smooth(crys, 0.035, 0.0) * g.smooth(dd, 0.9, 1.15) * 0.18
	haze = g.smooth(dd, 0.78, 1.25) * (0.1 + 0.4 * g.smooth(mottle, 0.3, 0.72)) * (0.55 + 0.7 * g.smooth(patches, 0.35, 0.65))
	gd, gr = g.voronoi(x * 60.0, y * 60.0, 1.0, "F1")
	grain = g.smooth(gd, 0.2, 0.0) * g.smooth(gr, 0.5, 0.75) * g.smooth(dd, 0.8, 1.05) * 0.3
	return g.emit((haze + facets + grain) * vignette_clear(g))


def vignette_wobble(g):
	# Irregular inner boundary, so the clear centre isn't a rounded rectangle.
	return sn(g.noise(g.x * 0.9, g.y * 0.9, 0.0, w=21.0, detail=3.0)) * 0.13 + sn(g.noise(g.x * 3.5, g.y * 3.5, 0.0, w=23.0, detail=2.0)) * 0.04


def vignette_clear(g):
	return g.smooth(vignette_d(g), 0.66, 0.88)


def vignette_feathers():
	A = 16 / 9
	rng = random.Random(311)
	lines = []

	def feather(px, py, ang, length, width):
		grow(lines, rng, (px, py), ang, length, width, 2, step=0.012, wander=0.07, branch=0.85, side_len=(0.12, 0.24))

	# Seeds on the screen border, more of them (and longer) toward the corners; each grows inward at an angle.
	perim = 4 * A + 4
	k = 0
	while k < 120:
		t = rng.uniform(0, perim)
		if t < 2 * A:
			px, py, inward = -A + t, 1.02, -math.pi / 2
		elif t < 4 * A:
			px, py, inward = -A + (t - 2 * A), -1.02, math.pi / 2
		elif t < 4 * A + 2:
			px, py, inward = A + 0.02, -1 + (t - 4 * A), math.pi
		else:
			px, py, inward = -A - 0.02, -1 + (t - 4 * A - 2), 0.0
		corner = min(1.0, (abs(px) / A) * abs(py))  # 1 in the corners, 0 at the edge middles
		if rng.random() > 0.25 + 0.75 * corner ** 1.5:
			continue
		length = 0.08 + rng.random() ** 2 * 0.25 + corner * rng.uniform(0.1, 0.4)
		feather(px, py, inward + rng.gauss(0, 0.45), length, 0.004 + 0.003 * corner)
		k += 1
	# A few big feathers out of each corner.
	for sx in (1, -1):
		for sy in (1, -1):
			base = math.atan2(-sy, -sx * A * 0.75)
			for _ in range(4):
				feather(sx * (A + 0.02), sy * 1.02, base + rng.uniform(-0.55, 0.55), rng.uniform(0.4, 0.7), 0.008)
	return lines


CRYSTALS = 20


def build_crystals(scene):
	"""A cluster of faceted ice crystals radiating from the centre, lit for bright edges."""
	import bmesh

	rng = random.Random(2024)
	mat = bpy.data.materials.new("ice")
	mat.use_nodes = True
	b = mat.node_tree.nodes.get("Principled BSDF")
	b.inputs["Base Color"].default_value = (0.5, 0.52, 0.55, 1)
	b.inputs["Roughness"].default_value = 0.16
	b.inputs["IOR"].default_value = 1.31
	b.inputs["Coat Weight"].default_value = 0.6
	b.inputs["Coat Roughness"].default_value = 0.05
	b.inputs["Emission Color"].default_value = (1, 1, 1, 1)
	b.inputs["Emission Strength"].default_value = 0.06
	bm = bmesh.new()
	from mathutils import Vector

	for k in range(CRYSTALS):
		# Directions spread around the circle, tipped toward the camera (+z) so they read as a 3D clump.
		phi = (k + rng.uniform(-0.3, 0.3)) / CRYSTALS * math.tau
		tilt = rng.uniform(0.15, 1.05)
		d = Vector((math.cos(phi) * math.cos(tilt), math.sin(phi) * math.cos(tilt), math.sin(tilt)))
		big = k % 4 == 0
		length = rng.uniform(0.55, 0.8) if big else rng.uniform(0.22, 0.48)
		rad = rng.uniform(0.065, 0.09) if big else rng.uniform(0.035, 0.06)
		shoulder = length * rng.uniform(0.62, 0.78)
		q = Vector((0, 0, 1)).rotation_difference(d)
		rot = q.to_matrix()
		spin = rng.uniform(0, math.tau)
		base = [rot @ Vector((rad * 0.75 * math.cos(spin + j * math.pi / 3), rad * 0.75 * math.sin(spin + j * math.pi / 3), -0.05)) for j in range(6)]
		mid = [rot @ Vector((rad * math.cos(spin + j * math.pi / 3), rad * math.sin(spin + j * math.pi / 3), shoulder)) for j in range(6)]
		tip = rot @ Vector((rng.gauss(0, rad * 0.15), rng.gauss(0, rad * 0.15), length))
		vb = [bm.verts.new(p) for p in base]
		vm = [bm.verts.new(p) for p in mid]
		vt = bm.verts.new(tip)
		for j in range(6):
			jj = (j + 1) % 6
			bm.faces.new((vb[j], vb[jj], vm[jj], vm[j]))
			bm.faces.new((vm[j], vm[jj], vt))
		bm.faces.new(vb[::-1])
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	me = bpy.data.meshes.new("crystals")
	bm.to_mesh(me)
	bm.free()
	me.materials.append(mat)
	ob = bpy.data.objects.new("crystals", me)
	ob.scale = (1.15, 1.15, 1.15)
	scene.collection.objects.link(ob)
	# Faint frost haze behind the clump.
	bpy.ops.mesh.primitive_plane_add(size=2, location=(0, 0, -1.2))
	g = G("haze")
	r = g.length(g.x, g.y)
	mott = g.noise(g.x * 4.0, g.y * 4.0, 0.0, w=3.0, detail=4.0)
	bpy.context.active_object.data.materials.append(g.output((g.soft(r, 0.32) * 0.4 + g.soft(r, 0.12) * 0.25) * (0.6 + 0.6 * g.smooth(mott, 0.3, 0.7)), 1.0))
	# Lights: soft key from the upper left, two strong rims from behind for bright crystal edges, grey sky.
	world = bpy.data.worlds.new("world")
	world.use_nodes = True
	world.node_tree.nodes["Background"].inputs["Color"].default_value = (1, 1, 1, 1)
	world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.12
	scene.world = world

	def area(name, loc, energy, size):
		ld = bpy.data.lights.new(name, "AREA")
		ld.energy = energy
		ld.size = size
		lo = bpy.data.objects.new(name, ld)
		lo.location = loc
		lo.rotation_euler = (Vector((0, 0, 0)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
		scene.collection.objects.link(lo)

	area("key", (-2.5, 3.0, 4.0), 220, 2.5)
	area("fill", (3.0, -1.0, 3.0), 35, 3.0)
	area("rim1", (2.5, 2.5, -1.0), 160, 1.5)
	area("rim2", (-2.5, -2.5, -0.5), 110, 1.5)
	# The camera looks down -z; hide the lights' own glow from the film.
	scene.cycles.max_bounces = 8
	scene.cycles.transmission_bounces = 8


def vapor(g, _i):
	"""A thin vapour wisp along u: streaky, wavy centre line, fading out at both ends and both edges."""
	u, v = g.u, g.v
	wave = sn(g.noise(u * 3.0, 0.0, 0.0, w=31.0, detail=2.0)) * 0.12
	thick = 0.13 + 0.08 * g.smooth(g.noise(u * 2.5, 0.0, 0.0, w=32.0, detail=2.0), 0.3, 0.7)
	dv = v - 0.5 - wave
	body = g.soft(dv, thick)
	# Streaks: noise stretched along u (low frequency along, high across), curling slightly.
	curl = sn(g.noise(u * 4.0, v * 4.0, 0.0, w=33.0, detail=2.0)) * 0.05
	s1 = g.noise(u * 5.0, (v + curl) * 26.0, 0.0, w=34.0, detail=3.0, rough=0.55)
	s2 = g.noise(u * 12.0, (v + curl) * 60.0, 0.0, w=35.0, detail=2.0, rough=0.5)
	streaks = g.smooth(s1, 0.32, 0.72) * 0.75 + g.smooth(s2, 0.4, 0.7) * 0.35
	gaps = g.smooth(g.noise(u * 6.0, v * 3.0, 0.0, w=36.0, detail=3.0), 0.3, 0.6)
	ends = g.smooth(u, 0.0, 0.2) * g.smooth(u, 1.0, 0.7)
	alpha = body * (0.25 + streaks) * (0.45 + 0.55 * gaps) * ends * 0.85
	return g.output(alpha * g.smooth(v, 0.0, 0.08) * g.smooth(v, 1.0, 0.92), 1.0)


# Sheets -------------------------------------------------------------------------------
# name: (width, height, grid, kind, builder)

SHEETS = {
	"frost_mist_2x2": (1024, 1024, 2, "volume", mist),
	"frost_burst_2x2": (1024, 1024, 2, "glow", burst),
	"frost_ground": (1024, 1024, 1, "glowplane", ground_haze),
	"frost_shard": (256, 256, 1, "plane", shard),
	"frost_crystals": (512, 512, 1, "crystals", None),
	"frost_vignette": (1024, 576, 1, "glowplane", vignette_haze),
	"frost_vapor": (512, 128, 1, "plane", vapor),
}
# Glow sheets: alpha = brightness * GAIN (the feathers are emission 1, so 1 = fully opaque white).
GAIN = {"frost_burst_2x2": 1.0, "frost_ground": 1.0, "frost_vignette": 0.92}


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


def light_mist(scene):
	"""Bright soft sky plus a gentle key from the upper left: white mist with soft, cool-neutral shading."""
	scene.cycles.volume_bounces = 2
	world = bpy.data.worlds.new("world")
	world.use_nodes = True
	bg = world.node_tree.nodes.get("Background") or world.node_tree.nodes.new("ShaderNodeBackground")
	bg.inputs["Color"].default_value = (1.0, 1.0, 1.0, 1.0)
	bg.inputs["Strength"].default_value = 0.95
	out = world.node_tree.nodes.get("World Output") or world.node_tree.nodes.new("ShaderNodeOutputWorld")
	world.node_tree.links.new(bg.outputs[0], out.inputs["Surface"])
	scene.world = world
	sun_data = bpy.data.lights.new("sun", "SUN")
	sun_data.energy = 3.6
	sun_data.angle = math.radians(20)
	sun = bpy.data.objects.new("sun", sun_data)
	sun.rotation_euler = (math.radians(35), math.radians(-30), math.radians(10))
	scene.collection.objects.link(sun)


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
	width, height, grid, kind, build = SHEETS[name]
	aspect = width / height
	if kind in ("plane", "glowplane"):
		scene = setup_scene(width, height, 2 * aspect, 64)
		bpy.ops.mesh.primitive_plane_add(size=2)
		plane = bpy.context.active_object
		plane.scale = (aspect, 1, 1)
		bpy.ops.object.transform_apply(scale=True)  # object coordinates in -aspect..aspect, -1..1
		plane.data.materials.append(build(G(name), 0))
		if name == "frost_ground":
			make_curves("feathers", ground_feathers(), feather_mat("feather", ground_mask, 0.7), z=0.05)
		elif name == "frost_vignette":
			make_curves("feathers", vignette_feathers(), feather_mat("feather", vignette_clear, 0.8), z=0.05)
	elif kind == "crystals":
		scene = setup_scene(width, height, 2, 160)
		build_crystals(scene)
	else:
		scene = setup_scene(width, height, 2 * grid, 32 if kind == "glow" else 224)
		if kind == "volume":
			light_mist(scene)
		for i in range(grid * grid):
			col, row = i % grid, i // grid
			origin = ((col - (grid - 1) / 2) * 2, ((grid - 1) / 2 - row) * 2)
			if kind == "glow":
				bpy.ops.mesh.primitive_plane_add(size=2, location=(*origin, 0))
			else:
				bpy.ops.mesh.primitive_cube_add(size=2, location=(*origin, 0))
			bpy.context.active_object.data.materials.append(build(G(f"{name}{i}"), i))
	path = OUT / f"{name}.png"
	if kind in ("glow", "glowplane"):
		black_world(scene)
		raw = OUT / f"_{name}.exr"
		scene.render.filepath = str(raw)
		bpy.ops.render.render(write_still=True)
		glow_post(raw, path, GAIN.get(name, 1.0))
		raw.unlink()
	else:
		scene.render.filepath = str(path)
		bpy.ops.render.render(write_still=True)
	print(f"[frost-vfx] {path.relative_to(ROOT)}")
	return path


def render_main():
	argv = [a for a in (sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []) if not a.startswith("--")]
	OUT.mkdir(parents=True, exist_ok=True)
	for name in argv or list(SHEETS):
		render_sheet(name)


# Preview (plain Python + Pillow) -----------------------------------------------

BG = (34, 36, 40)
ICE = (0xBF, 0xE8, 0xFF)
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
	W, pad, H = 1500, 24, 6000
	sheet = Image.new("RGBA", (W, H), (*BG, 255))
	draw = ImageDraw.Draw(sheet)
	draw.text((pad, 16), "Frost VFX textures on dark grey: ice-blue #BFE8FF tint and white (normal alpha blend unless noted)", fill=(235, 235, 235), font=f_title)
	y = 64

	def label(text, sub=None):
		nonlocal y
		draw.text((pad, y), text, fill=(230, 230, 230), font=f_head)
		if sub:
			draw.text((pad + draw.textlength(text, font=f_head) + 14, y + 4), sub, fill=(150, 150, 155), font=f_small)
		y += 30

	def row(imgs, cell, color, add=False, tag=None):
		nonlocal y
		for k, img in enumerate(imgs):
			cx = pad + k * (cell + 10)
			draw.rectangle((cx, y, cx + cell - 1, y + cell - 1), outline=(48, 50, 56))
			im = tint(img.resize((cell, cell) if img.width == img.height else (cell, int(cell * img.height / img.width)), Image.LANCZOS), color)
			if add:
				additive(sheet, im, (cx, y))
			else:
				sheet.alpha_composite(im, (cx, y))
			draw.text((cx + 6, y + 4), f"{k + 1}", fill=(160, 160, 165), font=f_small)
		if tag:
			draw.text((pad + len(imgs) * (cell + 10), y + 4), tag, fill=(150, 150, 155), font=f_small)
		y += cell + 14

	label("frost_mist_2x2.png  1024x1024", "frames 1-4: ice-blue tint, then white")
	row(frames(tex["frost_mist_2x2"], 2), 330, ICE)
	row(frames(tex["frost_mist_2x2"], 2), 330, WHITE)
	y += 12
	label("frost_burst_2x2.png  1024x1024", "frames 1-4: ice-blue (normal blend), white (normal blend), ice-blue additive (LightEmission 1)")
	row(frames(tex["frost_burst_2x2"], 2), 330, ICE)
	row(frames(tex["frost_burst_2x2"], 2), 330, WHITE)
	row(frames(tex["frost_burst_2x2"], 2), 330, ICE, add=True)
	y += 12

	label("frost_ground.png  1024x1024", "decal: ice-blue and white on dark grey, then ice-blue on a concrete-grey floor")
	g = tex["frost_ground"].resize((460, 460), Image.LANCZOS)
	sheet.alpha_composite(tint(g, ICE), (pad, y))
	sheet.alpha_composite(tint(g, WHITE), (pad + 480, y))
	floor = Image.new("RGBA", (460, 460), (120, 118, 112, 255))
	floor.alpha_composite(tint(g, ICE))
	sheet.alpha_composite(floor, (pad + 960, y))
	y += 460 + 26

	label("frost_crystals.png  512x512", "ice-blue / white, then ice-blue on a mid grey")
	c = tex["frost_crystals"].resize((300, 300), Image.LANCZOS)
	sheet.alpha_composite(tint(c, ICE), (pad, y))
	sheet.alpha_composite(tint(c, WHITE), (pad + 320, y))
	mg = Image.new("RGBA", (300, 300), (110, 112, 116, 255))
	mg.alpha_composite(tint(c, ICE))
	sheet.alpha_composite(mg, (pad + 640, y))
	draw.text((pad + 980, y), "frost_shard.png  256x256", fill=(230, 230, 230), font=f_head)
	s = tex["frost_shard"]
	sheet.alpha_composite(tint(s, ICE), (pad + 980, y + 34))
	sheet.alpha_composite(tint(s.resize((128, 128), Image.LANCZOS), WHITE), (pad + 1250, y + 34))
	draw.text((pad + 980, y + 300), "actual size (ice) / half size (white)", fill=(150, 150, 155), font=f_small)
	y += 300 + 30

	label("frost_vapor.png  512x128", "ice-blue and white, actual size and 2x")
	v = tex["frost_vapor"]
	sheet.alpha_composite(tint(v, ICE), (pad, y))
	sheet.alpha_composite(tint(v, WHITE), (pad + 530, y))
	y += 128 + 8
	sheet.alpha_composite(tint(v.resize((1024, 256), Image.LANCZOS), ICE), (pad, y))
	y += 256 + 26

	label("frost_vignette.png  1024x576", "ice-blue over a mid-grey 'screen' (1280x720 here) with a crosshair")
	scr = Image.new("RGBA", (1280, 720), (128, 128, 128, 255))
	sd = ImageDraw.Draw(scr)
	for k in range(720):  # a faint gradient so the overlay reads against something
		c0 = int(150 - 40 * k / 720)
		sd.line((0, k, 1280, k), fill=(c0, c0, c0 + 4, 255))
	sd.line((640 - 12, 360, 640 + 12, 360), fill=(255, 255, 255, 255), width=2)
	sd.line((640, 360 - 12, 640, 360 + 12), fill=(255, 255, 255, 255), width=2)
	scr.alpha_composite(tint(tex["frost_vignette"].resize((1280, 720), Image.LANCZOS), ICE))
	sheet.alpha_composite(scr, (pad, y))
	y += 720 + 20

	# Mock burst: floor decal in perspective + burst flash + mist + shards (Pillow composite, not a render).
	label("Mock burst (Pillow composite, not a render)", "ground decal (squashed) + mist frame 2 + burst frame 2 additive + shards + crystals")
	mw, mh = W - 2 * pad, 560
	mock = Image.new("RGBA", (mw, mh), (60, 62, 64, 255))
	md = ImageDraw.Draw(mock)
	for k in range(mh):
		cc = int(48 + 34 * k / mh)
		md.line((0, k, mw, k), fill=(cc, cc, cc + 2, 255))
	cx, cy = mw // 2, int(mh * 0.7)
	gd = tint(tex["frost_ground"].resize((1000, 300), Image.LANCZOS), ICE)
	mock.alpha_composite(gd, (cx - 500, cy - 150))
	ms = frames(tex["frost_mist_2x2"], 2)
	rng = random.Random(5)
	for k in range(7):
		im = tint(ms[1 + k % 2].resize((300, 300), Image.LANCZOS), (220, 238, 250))
		a = im.getchannel("A").point(lambda val: int(val * 0.7))
		im.putalpha(a)
		mock.alpha_composite(im, (cx - 150 + rng.randint(-330, 330), cy - 260 + rng.randint(-40, 60)))
	bf = tint(frames(tex["frost_burst_2x2"], 2)[1].resize((480, 480), Image.LANCZOS), ICE)
	additive(mock, bf, (cx - 240, cy - 330), 0.9)
	sh = tint(tex["frost_shard"], ICE)
	for k in range(14):
		sz = rng.randint(30, 70)
		additive(mock, sh.resize((sz, sz), Image.LANCZOS), (cx + rng.randint(-420, 380), cy - rng.randint(60, 330)), 1.0)
	cr = tint(tex["frost_crystals"].resize((90, 90), Image.LANCZOS), ICE)
	for k in range(5):
		mock.alpha_composite(cr, (cx - 300 + k * 130, cy - 20 + (k % 2) * 30))
	sheet.alpha_composite(mock, (pad, y))
	y += mh + 20

	sheet = sheet.crop((0, 0, W, y + 6))
	PREVIEW.parent.mkdir(parents=True, exist_ok=True)
	sheet.convert("RGB").save(PREVIEW)
	print(f"[frost-vfx] preview {PREVIEW.relative_to(ROOT)}")


if bpy is not None:
	render_main()
elif "--preview" in sys.argv:
	preview_main()
else:
	print(__doc__)
