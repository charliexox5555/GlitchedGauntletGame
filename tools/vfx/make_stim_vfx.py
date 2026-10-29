"""Renders the Stim (electric beacon / Stimmed) textures with Blender, and their preview sheet.

Render (Blender, headless; a minute or two on a 12-core CPU, `--fast` for a quick half-size, low-sample check):

    "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup \
        --python tools/vfx/make_stim_vfx.py -- [names...] [--fast]

Preview contact sheet (plain Python + Pillow + numpy, run after rendering):

    python tools/vfx/make_stim_vfx.py --preview

Look (vault/01 Design/Abilities/Stim.md, "Look"): Brimstone's stim beacon as the quality reference, in this game's
plain, realistic tactical style: crackling ELECTRIC YELLOW. Small jagged arcs crackle over stimmed bodies and along the
zone edge, bolts jump from the beacon's mast, the 10-stud zone is a bright electric ring on the floor, hot sparks fly,
and the stimmed player's screen edges pulse with a faint electric glow. No glitch or digital shapes. Everything is
WHITE with straight alpha (RGBA PNG) so the game tints it (electric yellow #FFD23F is the intended tint). Output goes
to art-source/vfx/abilities/stim/.

  stim_arc_2x2   1024x1024  2x2 flipbook of small electric crackles (one frame each, NOT a growth sequence: flick
                            through them fast, or pick a random frame per particle): jagged, forked arcs with a thin
                            hot core and a soft glow. Arcs stay inside each cell (a margin all round).
  stim_bolt      1024x256   one lightning bolt for a Beam (u along it): a jagged main channel from the left edge to
                            the right edge, entering and leaving at v = 0.5 (so it joins its attachments and tiles in
                            u), a thinner second strand and short forks; hot core, soft glow.
  stim_ring      1024x1024  top-down zone ring: a bright, slightly wavering electric edge at r = 0.92 of the half-size
                            with small arcs crackling along it, a soft glow trailing inward with faint branching
                            veins, and a transparent centre (alpha 0 inside r ~ 0.5) and outside.
  stim_spark     256x256    a hot spark: white-hot core, a long horizontal streak (for VelocityParallel particles),
                            a short cross flare and a faint halo.
  stim_edge      1024x576   full-screen 16:9 overlay for the stimmed player: a soft electric glow from the screen
                            edges (strongest in the corners) with faint thin filaments running along the border and a
                            few tiny arcs reaching in; the centre is exactly transparent.

How: the arcs, bolts and filaments are real geometry: deterministic jagged polylines (recursive midpoint
displacement with forks, like real discharge paths) turned into thin round curves with an emission material; the ring
and edge glows are emission maths on a plane. Everything renders with Cycles on black; bloom_post then turns
brightness into alpha and adds a two-radius soft glow (blurred copies of the render, per flipbook cell) so the thin
cores read as electricity. Seeds are fixed, so re-running gives the same images.
"""

import math
import random
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art-source" / "vfx" / "abilities" / "stim"
PREVIEW = ROOT / "vault" / "02 Art" / "References" / "abilities" / "stim" / "stim_vfx_preview.png"

try:
	import bpy
except ImportError:  # Plain Python: preview mode only.
	bpy = None

FAST = "--fast" in sys.argv


# Node maths (same helpers as make_frost_vfx.py) --------------------------------------------

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


# Electric paths -------------------------------------------------------------------------
# A discharge path is a polyline of (x, y, width). jag() displaces midpoints recursively (each level halves the
# segment and the displacement), which gives the fractal, kinked look of real sparks; fork() adds side branches that
# leave the main channel at a shallow angle and taper to nothing.


def jag(rng, a, b, depth, rough, clamp=None):
	pts = [a, b]
	for _ in range(depth):
		nxt = [pts[0]]
		for p, q in zip(pts, pts[1:]):
			dx, dy = q[0] - p[0], q[1] - p[1]
			ln = math.hypot(dx, dy)
			off = rng.gauss(0, 1) * ln * rough
			mx, my = (p[0] + q[0]) / 2 - dy / ln * off, (p[1] + q[1]) / 2 + dx / ln * off
			if clamp:
				mx, my = clamp(mx, my)
			nxt += [(mx, my), q]
		pts = nxt
	return pts


def widths(pts, w0, w1, bulge=0.0):
	"""Width from w0 at the start to w1 at the end, optionally thicker in the middle; a little random flicker."""
	n = len(pts) - 1
	out = []
	for i, (x, y) in enumerate(pts):
		t = i / n
		w = w0 + (w1 - w0) * t + bulge * math.sin(math.pi * t)
		out.append((x, y, max(w, 0.0)))
	return out


def fork(rng, lines, pts, count, length, width, depth, rough, spread=(0.35, 0.8), clamp=None, sub=0):
	"""Side branches off a path (pts as (x, y)): `count` forks at random points, each tapering to zero."""
	n = len(pts)
	for _ in range(count):
		i = rng.randint(int(n * 0.12), int(n * 0.85))
		p, q = pts[i], pts[min(i + 2, n - 1)]
		ang = math.atan2(q[1] - p[1], q[0] - p[0]) + rng.choice((-1, 1)) * rng.uniform(*spread)
		ln = length * rng.uniform(0.5, 1.0)
		end = (p[0] + ln * math.cos(ang), p[1] + ln * math.sin(ang))
		if clamp:
			end = clamp(*end)
		bp = jag(rng, p, end, depth, rough, clamp)
		lines.append(widths(bp, width, 0.0))
		if sub:
			fork(rng, lines, bp, sub, ln * 0.45, width * 0.6, max(depth - 1, 2), rough, spread, clamp, 0)


def make_curves(name, polylines, strength, z=0.05, base=0.004):
	cu = bpy.data.curves.new(name, "CURVE")
	cu.dimensions = "3D"
	cu.bevel_depth = base
	cu.bevel_resolution = 2
	cu.use_fill_caps = True
	for pl in polylines:
		sp = cu.splines.new("POLY")
		sp.points.add(len(pl) - 1)
		for pt, (x, y, w) in zip(sp.points, pl):
			pt.co = (x, y, z, 1.0)
			pt.radius = w / base
	m = bpy.data.materials.new(name + "_mat")
	m.use_nodes = True
	nt = m.node_tree
	nt.nodes.clear()
	em = nt.nodes.new("ShaderNodeEmission")
	em.inputs["Color"].default_value = (1, 1, 1, 1)
	em.inputs["Strength"].default_value = strength
	out = nt.nodes.new("ShaderNodeOutputMaterial")
	nt.links.new(em.outputs[0], out.inputs["Surface"])
	cu.materials.append(m)
	ob = bpy.data.objects.new(name, cu)
	bpy.context.scene.collection.objects.link(ob)
	return ob


def box_clamp(lim):
	return lambda x, y: (max(-lim, min(lim, x)), max(-lim, min(lim, y)))


# Textures -------------------------------------------------------------------------------
# Plane coordinates: -1..1 (times the aspect in x), +y = up in the image. Flipbook cells are 2 units wide.


ARC_CELLS = [
	# (seed, main arcs, forks per arc, roughness, core width)
	(11, 1, 4, 0.2, 0.011),
	(23, 2, 2, 0.22, 0.009),
	(37, 1, 3, 0.26, 0.010),
	(41, 3, 1, 0.24, 0.008),
]


def arc_cell(ox, oy, i):
	"""One crackle: 1-3 jagged arcs across the cell (through the middle area), forked, kept inside the cell."""
	seed, mains, forks, rough, w = ARC_CELLS[i]
	rng = random.Random(seed)
	cl = box_clamp(0.86)
	lines = []
	for k in range(mains):
		a0 = rng.uniform(0, math.tau)
		r0, r1 = rng.uniform(0.55, 0.8), rng.uniform(0.5, 0.8)
		a1 = a0 + math.pi + rng.uniform(-0.9, 0.9)
		p = (r0 * math.cos(a0), r0 * math.sin(a0))
		q = (r1 * math.cos(a1), r1 * math.sin(a1))
		pts = jag(rng, p, q, 7, rough, cl)
		lines.append(widths(pts, w * 0.35, w * 0.35, bulge=w * 0.9))
		fork(rng, lines, pts, forks, 0.55, w * 0.7, 5, rough * 1.1, clamp=cl, sub=1)
	# A few tiny loose sparks of discharge near the arcs.
	for _ in range(3):
		c = (rng.uniform(-0.5, 0.5), rng.uniform(-0.5, 0.5))
		ang = rng.uniform(0, math.tau)
		e = (c[0] + 0.16 * math.cos(ang), c[1] + 0.16 * math.sin(ang))
		lines.append(widths(jag(rng, c, e, 4, 0.3, cl), w * 0.5, 0.0))
	return [[(x + ox, y + oy, ww) for x, y, ww in pl] for pl in lines]


def build_arc(scene):
	polys = []
	for i in range(4):
		col, row = i % 2, i // 2
		polys += arc_cell((col - 0.5) * 2, (0.5 - row) * 2, i)
	make_curves("arcs", polys, 1.0)


def build_bolt(scene):
	"""The beam bolt: x from -4 to 4 (u), y -1..1 (v), enters and leaves at y = 0."""
	rng = random.Random(77)
	cl = lambda x, y: (x, max(-0.62, min(0.62, y)))  # noqa: E731
	lines = []
	main = jag(rng, (-4.06, 0.0), (4.06, 0.0), 8, 0.055, cl)
	main = [(x, y * (min(1.0, (4.06 - abs(x)) / 0.35))) for x, y in main]  # pinned to v = 0.5 at both ends
	lines.append(widths(main, 0.013, 0.013, bulge=0.008))
	# A thinner second strand that wanders off the main channel and rejoins it.
	for a, b in ((-3.2, -0.6), (0.4, 2.9)):
		ia = min(range(len(main)), key=lambda k: abs(main[k][0] - a))
		ib = min(range(len(main)), key=lambda k: abs(main[k][0] - b))
		s = jag(rng, main[ia], main[ib], 6, 0.09, cl)
		lines.append(widths(s, 0.003, 0.003, bulge=0.006))
	fork(rng, lines, main, 7, 0.75, 0.01, 5, 0.12, spread=(0.3, 0.7), clamp=cl, sub=1)
	make_curves("bolt", lines, 1.0, base=0.01)


RING_R = 0.92


def ring_glow(g, _i):
	"""Electric zone edge: a thin bright wavering edge line, a soft glow trailing inward with faint veins."""
	x, y = g.x, g.y
	r = g.length(x, y)
	a = g.atan2(y, x)
	ca, sa = g.cos(a), g.sin(a)
	wob = sn(g.noise(ca * 6.0, sa * 6.0, 0.0, w=3.0, detail=2.0)) * 0.006
	R = r - RING_R - wob
	edge = g.soft(R, 0.004) * 0.95 + g.soft(R, 0.014) * 0.3
	inside = g.smooth(R, 0.004, -0.004)
	behind = g.clamp01(-R)
	trail = (g.math("EXPONENT", behind * -16.0) * 0.16 + g.math("EXPONENT", behind * -4.5) * 0.045) * inside
	# Faint branching veins in the glow band (ridged noise: thin bright lines where the noise crosses 0.5).
	vn = g.noise(x * 7.0, y * 7.0, 0.0, w=5.0, detail=3.0, rough=0.55)
	veins = g.smooth(g.abs(vn - 0.5), 0.016, 0.0) * g.smooth(behind, 0.16, 0.02) * inside * 0.2
	vary = 0.82 + 0.36 * g.smooth(g.noise(ca * 2.0, sa * 2.0, 0.0, w=6.0, detail=2.0), 0.3, 0.7)
	keep = g.smooth(r, 0.995, 0.975) * g.smooth(r, 0.5, 0.7)
	return g.emit((edge + trail + veins) * vary * keep)


def ring_arcs():
	"""Small arcs crackling along the edge: hops along the circle, some leaping a little in or out."""
	rng = random.Random(505)
	lines = []
	a = 0.0
	while a < math.tau - 0.05:
		span = rng.uniform(0.12, 0.34)
		dr0, dr1 = rng.uniform(-0.02, 0.012), rng.uniform(-0.02, 0.012)
		p = ((RING_R + dr0) * math.cos(a), (RING_R + dr0) * math.sin(a))
		q = ((RING_R + dr1) * math.cos(a + span), (RING_R + dr1) * math.sin(a + span))
		clamp = lambda x, y: (x * min(1.0, 0.975 / max(math.hypot(x, y), 1e-6)), y * min(1.0, 0.975 / max(math.hypot(x, y), 1e-6)))  # noqa: E731
		pts = jag(rng, p, q, 5, 0.2, clamp)
		w = rng.uniform(0.0035, 0.006)
		lines.append(widths(pts, w * 0.4, w * 0.4, bulge=w))
		if rng.random() < 0.45:
			fork(rng, lines, pts, 1, 0.07, w * 0.7, 3, 0.25, clamp=clamp)
		a += span + rng.uniform(0.04, 0.3)
	return lines


def spark(g, _i):
	"""Hot core, long horizontal streak, short cross flare, faint halo."""
	x, y = g.x, g.y
	r = g.length(x, y)
	ax, ay = g.abs(x), g.abs(y)

	def ray(along, across, reach, width):
		f = g.clamp01(1.0 - along / reach)
		return g.soft(across, width * (0.2 + 0.8 * f)) * f**1.8

	core = g.soft(r, 0.08) * 1.6 + g.soft(r, 0.2) * 0.45
	streak = ray(ax, ay, 0.96, 0.06)
	flare = ray(ay, ax, 0.42, 0.03) * 0.6
	k = 0.70710678
	diag = (ray(g.abs((x + y) * k), g.abs((x - y) * k), 0.2, 0.014) + ray(g.abs((x - y) * k), g.abs((x + y) * k), 0.2, 0.014)) * 0.35
	halo = g.soft(r, 0.42) * 0.16
	return g.emit((core + streak + flare + diag + halo) * g.smooth(r, 1.0, 0.92))


EDGE_A = 16 / 9


def edge_d(g):
	"""0 in the middle, ~1 at the edge middles, more in the corners (superellipse p = 3)."""
	ex, ey = g.abs(g.x) / EDGE_A, g.abs(g.y)
	return (ex**3.0 + ey**3.0) ** (1 / 3.0)


def edge_glow(g, _i):
	"""Soft electric glow from the screen edges with a faint flowing texture; clear centre."""
	x, y = g.x, g.y
	d = edge_d(g) + sn(g.noise(x * 1.1, y * 1.1, 0.0, w=7.0, detail=2.0)) * 0.05
	glow = g.smooth(d, 0.84, 1.15) ** 1.8 * 0.3
	# Faint ridged streaks (static-like), strongest close to the border.
	sn1 = g.noise(x * 5.0, y * 5.0, 0.0, w=9.0, detail=3.0, rough=0.55)
	streaks = g.smooth(g.abs(sn1 - 0.5), 0.025, 0.0) * g.smooth(d, 0.9, 1.08) * 0.16
	mott = 0.7 + 0.6 * g.smooth(g.noise(x * 2.2, y * 2.2, 0.0, w=8.0, detail=3.0), 0.3, 0.7)
	return g.emit((glow * mott + streaks) * g.smooth(edge_d(g), 0.66, 0.8))


def edge_filaments():
	"""Thin jagged filaments running along the border, more toward the corners, and tiny arcs reaching inward."""
	A = EDGE_A
	rng = random.Random(901)
	lines = []
	clamp = lambda x, y: (max(-A + 0.005, min(A - 0.005, x)), max(-0.995, min(0.995, y)))  # noqa: E731
	for side in range(4):
		horiz = side < 2
		sgn = 1 if side % 2 == 0 else -1
		L = 2 * A if horiz else 2.0
		t = -L / 2 + rng.uniform(0.0, 0.2)
		while t < L / 2 - 0.15:
			ln = rng.uniform(0.25, 0.7)
			inset0, inset1 = rng.uniform(0.012, 0.07), rng.uniform(0.012, 0.07)
			if horiz:
				p, q = (t, sgn * (1 - inset0)), (min(t + ln, A), sgn * (1 - inset1))
			else:
				p, q = (sgn * (A - inset0), t), (sgn * (A - inset1), min(t + ln, 1.0))
			pts = jag(rng, p, q, 6, 0.06, clamp)
			w = rng.uniform(0.0025, 0.0045)
			lines.append(widths(pts, w * 0.3, w * 0.3, bulge=w))
			if rng.random() < 0.5:
				fork(rng, lines, pts, 1, 0.12, w * 0.7, 4, 0.2, spread=(0.6, 1.2), clamp=clamp)
			t += ln + rng.uniform(0.1, 0.45)
	# Tiny arcs in the corners reaching inward.
	for sx in (1, -1):
		for sy in (1, -1):
			for _ in range(2):
				p = (sx * (A - rng.uniform(0.02, 0.2)), sy * (1 - rng.uniform(0.02, 0.15)))
				ang = math.atan2(-sy, -sx * A) + rng.uniform(-0.5, 0.5)
				ln = rng.uniform(0.14, 0.28)
				q = (p[0] + ln * math.cos(ang), p[1] + ln * math.sin(ang))
				pts = jag(rng, p, q, 5, 0.2, clamp)
				lines.append(widths(pts, 0.004, 0.0))
	return lines


# Sheets -------------------------------------------------------------------------------
# name: (width, height, grid, plane shader or None, curve builder or None, bloom (sigma px, gain) pairs, alpha gain)

SHEETS = {
	"stim_arc_2x2": (1024, 1024, 2, None, build_arc, [(2.5, 0.7), (10.0, 0.75)], 1.0),
	"stim_bolt": (1024, 256, 1, None, build_bolt, [(2.5, 0.6), (9.0, 0.55)], 1.0),
	"stim_ring": (1024, 1024, 1, ring_glow, "ring", [(3.0, 0.4), (12.0, 0.3)], 1.0),
	"stim_spark": (256, 256, 1, spark, None, [], 1.0),
	"stim_edge": (1024, 576, 1, edge_glow, "edge", [(3.0, 0.45), (12.0, 0.3)], 0.9),
}


def setup_scene(width, height, ortho, samples):
	bpy.ops.wm.read_factory_settings(use_empty=True)
	scene = bpy.context.scene
	scene.render.engine = "CYCLES"
	scene.cycles.device = "CPU"
	scene.cycles.samples = max(8, samples // 6) if FAST else samples
	scene.cycles.seed = 7
	scene.cycles.use_denoising = False
	scene.render.resolution_x = width
	scene.render.resolution_y = height
	scene.render.resolution_percentage = 50 if FAST else 100
	scene.view_settings.view_transform = "Standard"
	scene.view_settings.look = "None"
	scene.render.film_transparent = False
	world = bpy.data.worlds.new("black")
	world.use_nodes = True
	world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.0
	scene.world = world
	scene.render.image_settings.file_format = "OPEN_EXR"
	scene.render.image_settings.color_depth = "32"
	scene.render.image_settings.color_mode = "RGB"
	cam_data = bpy.data.cameras.new("cam")
	cam_data.type = "ORTHO"
	cam_data.ortho_scale = ortho
	cam_data.clip_end = 100
	cam = bpy.data.objects.new("cam", cam_data)
	cam.location = (0, 0, 10)
	scene.collection.objects.link(cam)
	scene.camera = cam
	return scene


def blur(a, sigma):
	"""Gaussian-ish blur (three box passes each way), edges clamped. a: 2D float array."""
	import numpy as np

	r = max(1, int(round(sigma * 0.9)))
	for axis in (0, 1):
		for _ in range(3):
			pad = [(0, 0), (0, 0)]
			pad[axis] = (r + 1, r)
			p = np.pad(a, pad, mode="edge")
			c = np.cumsum(p, axis=axis)
			if axis == 0:
				a = (c[2 * r + 1 :, :] - c[: -2 * r - 1, :]) / (2 * r + 1)
			else:
				a = (c[:, 2 * r + 1 :] - c[:, : -2 * r - 1]) / (2 * r + 1)
	return a


def bloom_post(src, dst, grid, blooms, gain, open_u=False):
	"""Emission render on black (linear EXR) -> white straight-alpha RGBA PNG: alpha = (core + soft glow) * gain.
	The glow is blurred per flipbook cell, so nothing bleeds into the neighbouring frame."""
	import numpy as np

	img = bpy.data.images.load(str(src))
	w, h = img.size
	px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
	bpy.data.images.remove(img)
	lum = np.clip(px[..., :3].max(axis=-1), 0.0, 4.0)
	scale = 0.5 if FAST else 1.0
	out_a = np.zeros_like(lum)
	ch, cw = h // grid, w // grid
	for row in range(grid):
		for col in range(grid):
			cell = lum[row * ch : (row + 1) * ch, col * cw : (col + 1) * cw]
			total = np.minimum(cell, 1.0).copy()
			for sigma, k in blooms:
				total += blur(cell, sigma * scale) * k
			out_a[row * ch : (row + 1) * ch, col * cw : (col + 1) * cw] = total
	alpha = np.clip(out_a * gain, 0.0, 1.0)
	# Fade the outermost pixels of every cell to 0 (clean flipbook borders, no wrap seams), except the left/right
	# edges of an open-ended strip (the bolt must reach them: it joins its attachments).
	m = np.ones((h // grid, w // grid), np.float32)
	e = max(2, int(4 * scale))
	ramp = np.linspace(0.0, 1.0, e)
	m[:e, :] *= ramp[:, None]
	m[-e:, :] *= ramp[::-1, None]
	if not open_u:
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
	width, height, grid, shader, curves, blooms, gain = SHEETS[name]
	aspect = width / height
	scene = setup_scene(width, height, 2 * grid * aspect, 48)
	if shader is not None:
		bpy.ops.mesh.primitive_plane_add(size=2)
		plane = bpy.context.active_object
		if aspect != 1:
			plane.scale = (aspect, 1, 1)
			bpy.ops.object.transform_apply(scale=True)  # object coordinates in -aspect..aspect, -1..1
		plane.data.materials.append(shader(G(name), 0))
	if curves == "ring":
		make_curves("ring_arcs", ring_arcs(), 1.0)
	elif curves == "edge":
		make_curves("filaments", edge_filaments(), 0.9)
	elif curves is not None:
		curves(scene)
	raw = OUT / f"_{name}.exr"
	path = OUT / f"{name}.png"
	scene.render.filepath = str(raw)
	bpy.ops.render.render(write_still=True)
	bloom_post(raw, path, grid, blooms, gain, open_u=name == "stim_bolt")
	raw.unlink()
	print(f"[stim-vfx] {path.relative_to(ROOT)}")
	return path


def render_main():
	argv = [a for a in (sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []) if not a.startswith("--")]
	OUT.mkdir(parents=True, exist_ok=True)
	for name in argv or list(SHEETS):
		render_sheet(name)


# Preview (plain Python + Pillow) -----------------------------------------------

BG = (34, 36, 40)
YELLOW = (0xFF, 0xD2, 0x3F)
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
	W, pad, H = 1500, 24, 7000
	sheet = Image.new("RGBA", (W, H), (*BG, 255))
	draw = ImageDraw.Draw(sheet)
	draw.text((pad, 16), "Stim VFX textures on dark grey: electric yellow #FFD23F and white (normal alpha blend unless noted)", fill=(235, 235, 235), font=f_title)
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

	label("stim_arc_2x2.png  1024x1024", "frames 1-4: yellow (normal blend), white, yellow additive (LightEmission 1)")
	row(frames(tex["stim_arc_2x2"], 2), 345, YELLOW)
	row(frames(tex["stim_arc_2x2"], 2), 345, WHITE)
	row(frames(tex["stim_arc_2x2"], 2), 345, YELLOW, add=True)
	y += 10

	label("stim_bolt.png  1024x256", "yellow, white, yellow additive (u along the bolt, enters/leaves at v = 0.5)")
	b = tex["stim_bolt"].resize((1452, 363), Image.LANCZOS)
	for color, add in ((YELLOW, False), (WHITE, False), (YELLOW, True)):
		if add:
			additive(sheet, tint(b, color), (pad, y))
		else:
			sheet.alpha_composite(tint(b, color), (pad, y))
		y += 363 + 8
	y += 18

	label("stim_ring.png  1024x1024", "yellow and white on dark grey, then yellow additive on a concrete-grey floor")
	g = tex["stim_ring"].resize((460, 460), Image.LANCZOS)
	sheet.alpha_composite(tint(g, YELLOW), (pad, y))
	sheet.alpha_composite(tint(g, WHITE), (pad + 480, y))
	floor = Image.new("RGBA", (460, 460), (110, 108, 104, 255))
	sheet.alpha_composite(floor, (pad + 960, y))
	additive(sheet, tint(g, YELLOW), (pad + 960, y))
	y += 460 + 26

	label("stim_spark.png  256x256", "yellow, white, yellow additive; then half size")
	s = tex["stim_spark"]
	sheet.alpha_composite(tint(s, YELLOW), (pad, y))
	sheet.alpha_composite(tint(s, WHITE), (pad + 270, y))
	additive(sheet, tint(s, YELLOW), (pad + 540, y))
	sheet.alpha_composite(tint(s.resize((128, 128), Image.LANCZOS), YELLOW), (pad + 810, y + 64))
	y += 256 + 26

	label("stim_edge.png  1024x576", "yellow over a mid-grey 'screen' (1280x720 here) with a crosshair, normal blend")
	scr = Image.new("RGBA", (1280, 720), (128, 128, 128, 255))
	sd = ImageDraw.Draw(scr)
	for k in range(720):
		c0 = int(140 - 50 * k / 720)
		sd.line((0, k, 1280, k), fill=(c0, c0, c0 + 4, 255))
	sd.line((640 - 12, 360, 640 + 12, 360), fill=(255, 255, 255, 255), width=2)
	sd.line((640, 360 - 12, 640, 360 + 12), fill=(255, 255, 255, 255), width=2)
	scr.alpha_composite(tint(tex["stim_edge"].resize((1280, 720), Image.LANCZOS), YELLOW))
	sheet.alpha_composite(scr, (pad, y))
	y += 720 + 20

	# Mock zone: the ring squashed in perspective on a floor, bolts up to a mast tip, crackle arcs, sparks.
	label("Mock zone (Pillow composite, not a render)", "ring (squashed) + bolts from the mast tip + arc frames + sparks, all additive")
	mw, mh = W - 2 * pad, 600
	mock = Image.new("RGBA", (mw, mh), (60, 62, 64, 255))
	md = ImageDraw.Draw(mock)
	for k in range(mh):
		cc = int(36 + 40 * k / mh)
		md.line((0, k, mw, k), fill=(cc, cc, cc + 2, 255))
	cx, cy = mw // 2, int(mh * 0.68)
	additive(mock, tint(tex["stim_ring"].resize((1300, 360), Image.LANCZOS), YELLOW), (cx - 650, cy - 180))
	md.rectangle((cx - 22, cy - 40, cx + 22, cy), fill=(40, 41, 46, 255))
	md.rectangle((cx - 5, cy - 150, cx + 5, cy - 40), fill=(90, 94, 100, 255))
	tip = (cx, cy - 152)
	bolt = tint(tex["stim_bolt"], YELLOW)
	rng = random.Random(3)
	for ang, ln in ((-160, 360), (-25, 420), (200, 300), (-60, 260)):
		bb = bolt.resize((ln, 70), Image.LANCZOS).rotate(-ang, expand=True, resample=Image.BICUBIC)
		rad = math.radians(ang)
		ex, ey = tip[0] + ln / 2 * math.cos(rad), tip[1] + ln / 2 * math.sin(rad)
		px_, py_ = int(ex - bb.width / 2), int(ey - bb.height / 2)
		if 0 <= px_ and 0 <= py_ and px_ + bb.width <= mw and py_ + bb.height <= mh:
			additive(mock, bb, (px_, py_), 0.9)
	arcs = frames(tex["stim_arc_2x2"], 2)
	for k in range(8):
		a = rng.uniform(0, math.tau)
		ax_, ay_ = cx + int(600 * math.cos(a)), cy + int(165 * math.sin(a))
		sz = rng.randint(70, 120)
		px_, py_ = ax_ - sz // 2, ay_ - sz // 2
		if 0 <= px_ and 0 <= py_ and px_ + sz <= mw and py_ + sz <= mh:
			additive(mock, tint(arcs[k % 4].resize((sz, sz), Image.LANCZOS), YELLOW), (px_, py_))
	sp = tint(tex["stim_spark"], YELLOW)
	for k in range(10):
		sz = rng.randint(24, 60)
		additive(mock, sp.resize((sz, sz), Image.LANCZOS), (tip[0] + rng.randint(-120, 100), tip[1] + rng.randint(-60, 80)))
	sheet.alpha_composite(mock, (pad, y))
	y += mh + 20

	sheet = sheet.crop((0, 0, W, y + 6))
	PREVIEW.parent.mkdir(parents=True, exist_ok=True)
	sheet.convert("RGB").save(PREVIEW)
	print(f"[stim-vfx] preview {PREVIEW.relative_to(ROOT)}")


if bpy is not None:
	render_main()
elif "--preview" in sys.argv:
	preview_main()
else:
	print(__doc__)
