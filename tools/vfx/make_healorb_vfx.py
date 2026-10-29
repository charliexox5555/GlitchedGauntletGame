"""Renders the Heal Orb textures with Blender, and their preview sheet.

Render (Blender, headless; about a minute on a 12-core CPU, `--fast` for a quick half-size, low-sample check):

    "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup \
        --python tools/vfx/make_healorb_vfx.py -- [names...] [--fast]

Preview contact sheet (plain Python + Pillow + numpy, run after rendering):

    python tools/vfx/make_healorb_vfx.py --preview

Look (vault/01 Design/Abilities/Heal Orb.md, "Look"): Sage's healing orb as the quality reference, in this game's clean
tactical style: a soft green-teal orb of swirling light, curling light wisps around the fingers, a ribbon of light to
the teammate, a soft burst when the orb is absorbed, a rising halo and an edge glow on the healed player. Soft and
rounded everywhere (no spikes or shards: that is Frost's language). Everything is WHITE / greyscale with straight
alpha (RGBA PNG) so the game tints it (green-teal #5CFFC8 is the intended tint). Output: art-source/vfx/abilities/healorb/.

  healorb_swirl       512x512    seamless in u AND v: swirling streams of light (warped diagonal filaments over a soft
                                 haze, a few sparkles). RGB carries the pattern too (greyscale, sqrt of alpha), so it
                                 also works on a ForceField-material MeshPart (the Shell), which reads the texture's
                                 brightness and animates it on its own.
  healorb_mote        256x256    a soft glowing mote: small hot core, soft halo, faint wide bloom.
  healorb_wisp_2x2    1024x1024  2x2 flipbook: a curling light wisp (a main strand with two thin strands twisting around
                                 it) drawing itself in, curling up, loosening and breaking into motes.
  healorb_ribbon      1024x256   beam texture, u along the beam (seamless in u), v across: a soft core, three braided
                                 strands, long energetic streaks and sparkles; soft (zero) edges in v.
  healorb_burst_2x2   1024x1024  2x2 flipbook (camera-facing): a soft light burst: a bright core flash with soft petals of
                                 light, an expanding soft ring, then sparkles drifting out as it fades.
  healorb_ring        512x512    top-view soft halo ring (bright inner edge, soft outer falloff, light streaks around it);
                                 a flat rising ring particle (Orientation VelocityPerpendicular) or a side-on band.
  healorb_edge        1024x576   full-screen 16:9 overlay: a soft glow at the screen edges and corners with drifting
                                 wisps and a few motes; the centre is exactly transparent.

How: every texture is a Cycles render of emission on black (shader planes, and real curves for the wisp), turned into
white + alpha afterwards (glow_post: alpha = brightness, plus a numpy gaussian bloom for the soft glow). The tileable
ones use noise on a torus (4D noise of cos/sin of u and v) and integer wave numbers, so the edges meet exactly. Seeds are
fixed, so re-running gives the same images.
"""

import math
import random
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art-source" / "vfx" / "abilities" / "healorb"
PREVIEW = ROOT / "vault" / "02 Art" / "References" / "abilities" / "healorb" / "healorb_vfx_preview.png"

try:
	import bpy
except ImportError:  # Plain Python: preview mode only.
	bpy = None

FAST = "--fast" in sys.argv
TAU = math.tau


# Node maths (same helpers as make_frost_vfx.py, plus 4D Voronoi) ---------------------------------


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
		self.z = S(self, obj.outputs[2])

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
		"""Smoothstep from lo (0) to hi (1); lo > hi inverts it."""
		n = self.node("ShaderNodeMapRange")
		n.interpolation_type = "SMOOTHSTEP"
		n.clamp = True
		self.put(n.inputs["Value"], value)
		flip = lo > hi
		if flip:
			lo, hi = hi, lo
		n.inputs["From Min"].default_value = lo
		n.inputs["From Max"].default_value = hi
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

	def voronoi(self, x, y, z=0.0, w=None, rand=1.0):
		"""F1 Voronoi, 3D (or 4D with w). Returns (distance, cell random 0..1)."""
		c = self.node("ShaderNodeCombineXYZ")
		self.put(c.inputs[0], x)
		self.put(c.inputs[1], y)
		self.put(c.inputs[2], z)
		n = self.node("ShaderNodeTexVoronoi")
		n.voronoi_dimensions = "3D" if w is None else "4D"
		n.feature = "F1"
		self.link(c.outputs[0], n.inputs["Vector"])
		if w is not None:
			self.put(n.inputs["W"], w)
		n.inputs["Scale"].default_value = 1.0
		n.inputs["Randomness"].default_value = rand
		sep = self.node("ShaderNodeSeparateColor")
		self.link(n.outputs["Color"], sep.inputs[0])
		return S(self, n.outputs["Distance"]), S(self, sep.outputs[0])

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


def sn(n, gain=4.0):
	"""Perlin fac (about 0.5 +- 0.15) -> signed, roughly -0.8..0.8."""
	return (n - 0.5) * gain


def torus_uv(g, u, v, r):
	"""(x, y, z, w) on a torus: noise sampled here is periodic in u and v (period 1)."""
	return g.cos(u * TAU) * r, g.sin(u * TAU) * r, g.cos(v * TAU) * r, g.sin(v * TAU) * r


# Textures --------------------------------------------------------------------------
# Plane object coordinates: -1..1 (times the aspect in x), +y = up in the image.


def swirl(g, _i):
	"""Seamless swirl: thin curling filaments of light (isolines of warped, diagonally stretched noise) over a soft
	haze, with a few sparkles. Shearing u by v (an integer shear) keeps it periodic while stretching the streams
	along the diagonal, so on the orb they read as light flowing around it."""
	u = (g.x + 1.0) * 0.5
	v = (g.y + 1.0) * 0.5
	a = u + v  # integer shear: still period 1 in u and v

	def tn(p, q, rp, rq, w0, detail=2.0, rough=0.5):
		# Noise on a torus with separate radii: rp sets the frequency across the streams, rq along them.
		return g.noise(g.cos(p * TAU) * rp, g.sin(p * TAU) * rp, g.cos(q * TAU) * rq, w=g.sin(q * TAU) * rq + w0, detail=detail, rough=rough)

	# A gentle periodic warp so the streams curl.
	wu = sn(tn(u, v, 0.8, 0.8, 3.0)) * 0.06
	wv = sn(tn(u, v, 0.8, 0.8, 5.0)) * 0.06
	au, vv = a + wu, v + wv

	def iso(n, width):
		# Thin bright line where the noise crosses 0.5, with a soft shoulder.
		d = g.abs(n - 0.5)
		return g.smooth(d, width, 0.0) ** 2.0 + g.smooth(d, width * 4.0, 0.0) * 0.18

	n1 = tn(au, vv, 2.2, 0.55, 11.0, 2.0)
	n2 = tn(au + 0.37, vv, 3.0, 0.7, 13.0, 2.0)
	n3 = tn(u - v + wu, v + wv, 2.8, 0.6, 17.0, 2.0)  # a fainter family flowing the other way
	pulse = 0.35 + 0.65 * g.smooth(tn(u, v, 1.4, 1.4, 19.0), 0.35, 0.68)
	streams = iso(n1, 0.022) * 0.95 * pulse + iso(n2, 0.016) * 0.5 * (1.2 - pulse * 0.6) + iso(n3, 0.013) * 0.18
	haze = 0.04 + 0.12 * g.smooth(tn(u, v, 1.3, 1.3, 23.0, 4.0, 0.6), 0.3, 0.72)
	sd, sr = g.voronoi(g.cos(u * TAU) * 5.0, g.sin(u * TAU) * 5.0, g.cos(v * TAU) * 5.0, w=g.sin(v * TAU) * 5.0 + 31.0)
	spark = g.smooth(sd, 0.14, 0.0) * g.smooth(sr, 0.82, 0.88) * 0.8
	return g.emit(haze + streams + spark)


def mote(g, _i):
	r = g.length(g.x, g.y)
	core = g.soft(r, 0.07) * 1.4 + g.soft(r, 0.16) * 0.55
	halo = g.soft(r, 0.36) * 0.22 + g.soft(r, 0.62) * 0.06
	return g.emit((core + halo) * g.smooth(r, 0.99, 0.85))


def ribbon(g, _i):
	"""Beam texture: u along (seamless), v across; soft core, braided strands, long streaks, sparkles."""
	A = 4.0
	u = (g.x + A) / (2 * A)
	y = g.y
	cu, su = g.cos(u * TAU), g.sin(u * TAU)
	ay = g.abs(y)
	edge = g.smooth(ay, 0.98, 0.72)  # exactly zero at both edges of the beam
	core = g.soft(y, 0.05) * 0.42 + g.soft(y, 0.18) * 0.2 + g.soft(y, 0.5) * 0.07
	# Three braided strands (integer cycles along u so they tile), each with a little noise wobble.
	strands = 0.0
	for k, (n, ph, amp, wd, gain) in enumerate([(2, 0.0, 0.46, 0.035, 0.75), (3, 2.1, 0.38, 0.03, 0.6), (5, 4.0, 0.28, 0.022, 0.45)]):
		wob = sn(g.noise(cu * 1.0, su * 1.0, 0.0, w=41.0 + k, detail=1.0)) * 0.04
		yk = g.sin(u * (TAU * n) + ph) * amp + wob
		# Strands dim where they pass "behind" the core (cosine of the same phase), so they read as a twist.
		depth = 0.7 + 0.3 * g.cos(u * (TAU * n) + ph)
		strands = strands + g.soft(y - yk, wd) * gain * depth
	# Long streaks along u: low frequency along the beam, high across it.
	st1 = g.noise(cu * 2.0, su * 2.0, y * 14.0, w=51.0, detail=3.0, rough=0.55)
	st2 = g.noise(cu * 4.0, su * 4.0, y * 26.0, w=52.0, detail=2.0, rough=0.5)
	streaks = (g.smooth(st1, 0.55, 0.75) * 0.5 + g.smooth(st2, 0.58, 0.74) * 0.3) * g.smooth(ay, 0.85, 0.15)
	sd, sr = g.voronoi(cu * 9.0, su * 9.0, y * 3.0)
	spark = g.smooth(sd, 0.18, 0.0) * g.smooth(sr, 0.72, 0.8) * g.smooth(ay, 0.8, 0.3) * 0.9
	return g.emit((core + strands + streaks + spark) * edge)


BURST = [
	# (core flash, petal reach, petals, ring radius, ring width, ring gain, sparkles, fade)
	(1.05, 0.42, 0.8, 0.2, 0.06, 0.4, 0.0, 1.0),
	(0.6, 0.6, 0.6, 0.4, 0.06, 0.75, 0.5, 0.95),
	(0.24, 0.72, 0.32, 0.58, 0.07, 0.6, 0.9, 0.8),
	(0.06, 0.82, 0.1, 0.74, 0.09, 0.32, 0.8, 0.6),
]


def burst(g, i):
	"""A soft light burst, camera-facing: core flash with soft petals of light, an expanding soft ring, sparkles."""
	flash, reach, petals_k, ring_r, ring_w, ring_k, spark_k, fade = BURST[i]
	x, y = g.x, g.y
	r = g.length(x, y)
	a = g.atan2(y, x)
	ca, sa = g.cos(a), g.sin(a)
	core = g.soft(r, 0.07 + 0.035 * i) * flash + g.soft(r, 0.24 + 0.06 * i) * flash * 0.32
	# Soft petals: broad angular lobes (low angular frequency, smooth), with finer rays inside them.
	lobes = g.smooth(g.noise(ca * 2.2, sa * 2.2, 0.0, w=5.0, detail=1.0), 0.38, 0.68)
	rays = g.smooth(g.noise(ca * 9.0, sa * 9.0, r * 0.4, w=6.0, detail=2.0), 0.45, 0.78)
	radial = g.math("EXPONENT", -(r / reach) * 2.2) * g.smooth(r, 0.0, 0.08 + 0.04 * i)
	petals = radial * (0.45 * lobes + 0.55 * rays * (0.4 + 0.6 * lobes)) * petals_k
	# Expanding soft ring, brighter on one side so it isn't a perfect circle.
	var = 0.55 + 0.45 * g.smooth(g.noise(ca * 1.6, sa * 1.6, 0.0, w=7.0 + i * 0.15, detail=2.0), 0.3, 0.7)
	ring = (g.soft(r - ring_r, ring_w) * 0.8 + g.soft(r - ring_r * 0.92, ring_w * 2.4) * 0.25) * ring_k * var
	glowfill = g.smooth(r, ring_r * 1.05, 0.0) * (0.02 + 0.03 * (3 - i))
	body = core + petals + ring + glowfill
	if i >= 2:
		bn = g.noise(x * 3.5, y * 3.5, 0.0, w=9.0, detail=3.0, rough=0.55)
		body = body * g.smooth(bn, 0.24 + 0.08 * (i - 2), 0.52 + 0.08 * (i - 2))
	# Sparkles: small soft dots around the ring, drifting outward (the same cells each frame, scaled with the ring).
	if spark_k > 0:
		s = 1.0 / (0.6 + 0.35 * i)
		sd, sr = g.voronoi(x * 13.0 * s, y * 13.0 * s, 4.0)
		spark = g.smooth(sd, 0.2, 0.0) * g.smooth(sr, 0.8, 0.84) * g.soft(r - ring_r * 1.05, 0.18 + 0.03 * i) * spark_k
		body = body + spark
	return g.emit(body * fade * g.smooth(r, 0.98, 0.86))


def halo_ring(g, _i):
	"""Top-view soft halo: bright inner edge, soft outer falloff, light streaks running around it."""
	x, y = g.x, g.y
	r = g.length(x, y)
	a = g.atan2(y, x)
	ca, sa = g.cos(a), g.sin(a)
	R = 0.66
	d = r - R
	# Asymmetric profile: sharper inside, longer soft tail outside.
	inner = g.soft(g.min(d, 0.0), 0.035)
	outer = g.math("EXPONENT", -(g.max(d, 0.0) / 0.1))
	band = inner * outer
	wide = g.soft(d, 0.16) * 0.16
	# Streaks around the circumference (high angular frequency, low radial) and a slow brightness variation.
	st = g.noise(ca * 7.0, sa * 7.0, r * 12.0, w=61.0, detail=3.0, rough=0.55)
	streaks = g.smooth(st, 0.5, 0.75) * g.soft(d, 0.06) * 0.4
	var = 0.6 + 0.4 * g.smooth(g.noise(ca * 1.4, sa * 1.4, 0.0, w=62.0, detail=2.0), 0.3, 0.7)
	sd, sr = g.voronoi(x * 16.0, y * 16.0, 3.0)
	spark = g.smooth(sd, 0.18, 0.0) * g.smooth(sr, 0.82, 0.86) * g.soft(d, 0.1) * 0.8
	fill = g.smooth(r, R, 0.0) * 0.05
	return g.emit(((band * 0.95 + wide + streaks) * var + spark + fill) * g.smooth(r, 0.99, 0.9))


def edge_d(g):
	"""0 in the middle, ~1 at the edge middles, more in the corners (superellipse p = 2.4), slightly wobbly."""
	A = 16 / 9
	ex, ey = g.abs(g.x) / A, g.abs(g.y)
	wob = sn(g.noise(g.x * 0.9, g.y * 0.9, 0.0, w=71.0, detail=2.0)) * 0.08
	return (ex**2.4 + ey**2.4) ** (1 / 2.4) + wob


def edge(g, _i):
	"""Soft green glow at the screen edges with drifting wisps and a few motes; the centre is exactly clear."""
	x, y = g.x, g.y
	d = edge_d(g)
	clear = g.smooth(d, 0.7, 0.9)
	glow = g.smooth(d, 0.74, 1.32) ** 1.8 * 0.45
	mott = g.noise(x * 1.4, y * 1.4, 0.0, w=72.0, detail=1.0)
	glow = glow * (0.7 + 0.45 * g.smooth(mott, 0.3, 0.7))
	# Wisps: warped streams flowing along the border (stretched along the edge by sampling the angle).
	a = g.atan2(y, x / (16 / 9))
	ca, sa = g.cos(a), g.sin(a)
	warp = sn(g.noise(ca * 2.0, sa * 2.0, d * 2.0, w=73.0, detail=2.0)) * 0.08
	ws = g.noise(ca * 2.5, sa * 2.5, (d + warp) * 14.0, w=74.0, detail=1.0)
	wisps = g.soft(ws - 0.5, 0.03) * g.smooth(d, 0.84, 1.08) * 0.22
	sd, sr = g.voronoi(x * 14.0, y * 14.0, 2.0)
	motes = g.smooth(sd, 0.16, 0.0) * g.smooth(sr, 0.86, 0.9) * g.smooth(d, 0.82, 1.0) * 0.7
	return g.emit((glow + wisps + motes) * clear)


# The wisp: real curves -----------------------------------------------------------------------
# A clothoid-like stroke (curvature grows along it) that rises and curls into a spiral hook, as a bevelled curve
# lit only by emission (brighter along the spine: the camera looks down -z at the round section), with two thin
# strands winding around it. Frames trim the stroke (draw-in, full, retracting) and break it into dashes at the end.

WISP = [
	# (t0, t1, curl, width, strand gain, dashes, strength)
	(0.0, 0.62, 1.0, 0.85, 0.8, 0, 1.0),
	(0.0, 1.0, 1.0, 1.0, 1.0, 0, 1.0),
	(0.32, 1.0, 0.85, 0.9, 0.85, 0, 0.82),
	(0.58, 1.0, 0.7, 0.75, 0.6, 8, 0.62),
]


def wisp_path(curl, n=260):
	"""Points (x, y) of the full stroke, starting low, swaying once and curling up into a tightening spiral."""
	pts = []
	x, y = 0.0, 0.0
	head = math.radians(72)
	L = 3.4
	ds = L / n
	for k in range(n + 1):
		t = k / n
		pts.append((x, y))
		# A gentle S sway first, then the curvature grows fast (a spiral, about 1.3 turns).
		kappa = -1.1 * math.sin(t * math.pi * 1.6) * (1 - t) ** 2 + curl * (0.15 + 11.0 * t**2.8)
		head += kappa * ds
		x += ds * math.cos(head)
		y += ds * math.sin(head)
	return pts


def wisp_fit():
	# One transform for every frame (fitted to all of them), so the frames line up and none leaves its cell.
	pts = [p for f in WISP for p in wisp_path(f[2])]
	xs, ys = [p[0] for p in pts], [p[1] for p in pts]
	cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
	s = 1.58 / max(max(xs) - min(xs), max(ys) - min(ys))
	return lambda p: ((p[0] - cx) * s, (p[1] - cy) * s)


def wisp_curves(i, origin):
	t0, t1, curl, width, sgain, dashes, strength = WISP[i]
	fit = wisp_fit()
	full = [fit(p) for p in wisp_path(curl)]
	n = len(full) - 1
	k0, k1 = int(t0 * n), int(t1 * n)
	seg = full[k0 : k1 + 1]
	m = len(seg)

	def taper(j):
		f = j / max(m - 1, 1)
		# Hair-thin tail, a fuller body, a rounded tip (the brightest, freshest part of the light).
		return min(1.0, f / 0.45) ** 1.2 * min(1.0, (1 - f) / 0.1) ** 0.5

	lines = []
	main = [(x, y, 0.016 * width * (0.06 + 0.94 * taper(j))) for j, (x, y) in enumerate(seg)]
	if dashes:
		step = max(4, m // dashes)
		for d0 in range(0, m - 3, step):
			piece = main[d0 : d0 + max(3, int(step * 0.5))]
			lines.append([(x, y, w * (0.4 + 0.6 * math.sin(math.pi * q / max(len(piece) - 1, 1)))) for q, (x, y, w) in enumerate(piece)])
	else:
		lines.append(main)
	# Two thin strands winding around the main one (offset along the normal by a sine of the arc length).
	strands = []
	for freq, ph, amp in [(4.0, 0.0, 0.034), (6.0, 2.4, 0.026)]:
		pts = []
		for j in range(m):
			a = seg[max(j - 1, 0)]
			b = seg[min(j + 1, m - 1)]
			tx, ty = b[0] - a[0], b[1] - a[1]
			ln = math.hypot(tx, ty) or 1.0
			nx, ny = -ty / ln, tx / ln
			f = (k0 + j) / n
			off = math.sin(f * freq * TAU + ph) * amp * width * (0.3 + 0.7 * taper(j))
			pts.append((seg[j][0] + nx * off, seg[j][1] + ny * off, 0.0045 * width * taper(j) + 0.0006))
		strands.append(pts)
	if dashes:
		strands = [s[k : k + 6] for s in strands for k in range(0, len(s) - 6, 14)]
	make_curves(f"wisp{i}", lines, wisp_mat(f"wm{i}", strength), origin)
	make_curves(f"wisp{i}s", strands, wisp_mat(f"ws{i}", strength * sgain), origin, z=0.02)


def wisp_mat(name, gain):
	g = G(name)
	ridge = 0.35 + 0.65 * g.clamp01(g.normal_z()) ** 1.5
	return g.emit(ridge * gain)


def make_curves(name, polylines, mat, origin, z=0.0, base=0.004):
	cu = bpy.data.curves.new(name, "CURVE")
	cu.dimensions = "3D"
	cu.bevel_depth = base
	cu.bevel_resolution = 3
	cu.use_fill_caps = True
	for pl in polylines:
		if len(pl) < 2:
			continue
		sp = cu.splines.new("POLY")
		sp.points.add(len(pl) - 1)
		for pt, (x, y, w) in zip(sp.points, pl):
			pt.co = (x, y, z, 1.0)
			pt.radius = max(w, 1e-4) / base
		sp.use_smooth = True
	cu.materials.append(mat)
	ob = bpy.data.objects.new(name, cu)
	ob.location = (*origin, 0.0)
	bpy.context.scene.collection.objects.link(ob)
	return ob


# Sheets -------------------------------------------------------------------------------
# name: (width, height, grid, kind, builder)

SHEETS = {
	"healorb_swirl": (512, 512, 1, "plane", swirl),
	"healorb_mote": (256, 256, 1, "plane", mote),
	"healorb_wisp_2x2": (1024, 1024, 2, "curves", None),
	"healorb_ribbon": (1024, 256, 1, "plane", ribbon),
	"healorb_burst_2x2": (1024, 1024, 2, "cells", burst),
	"healorb_ring": (512, 512, 1, "plane", halo_ring),
	"healorb_edge": (1024, 576, 1, "plane", edge),
}
# Post: alpha gain, and a gaussian bloom [(sigma in px at full size, weight)] added to the brightness. Tileable sheets
# blur with wrap-around (FFT), the others with zero padding (per flipbook cell).
POST = {
	"healorb_swirl": (1.0, [(3.0, 0.25)], "wrap"),
	"healorb_mote": (1.0, [], "pad"),
	"healorb_wisp_2x2": (1.0, [(4.0, 0.9), (14.0, 0.7), (40.0, 0.35)], "pad"),
	"healorb_ribbon": (1.0, [(3.0, 0.3), (10.0, 0.25)], "wrap_u"),
	"healorb_burst_2x2": (1.0, [(6.0, 0.35), (24.0, 0.3)], "pad"),
	"healorb_ring": (1.0, [(4.0, 0.3), (14.0, 0.25)], "pad"),
	"healorb_edge": (0.75, [(8.0, 0.2)], "pad"),
}
# Sheets whose RGB also carries the pattern (greyscale = sqrt(alpha)) instead of plain white.
GREY_RGB = {"healorb_swirl"}


def setup_scene(width, height, ortho, samples):
	bpy.ops.wm.read_factory_settings(use_empty=True)
	scene = bpy.context.scene
	scene.render.engine = "CYCLES"
	scene.cycles.device = "CPU"
	scene.cycles.samples = max(8, samples // 4) if FAST else samples
	scene.cycles.seed = 7
	scene.cycles.use_denoising = False
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


def gauss_blur(a, sigma, mode):
	"""Gaussian blur by FFT. mode: 'wrap' (both axes periodic), 'wrap_u' (periodic in x only), 'pad' (zero padding)."""
	import numpy as np

	h, w = a.shape
	py = 0 if mode == "wrap" else int(3 * sigma) + 1
	px = 0 if mode in ("wrap", "wrap_u") else int(3 * sigma) + 1
	b = np.pad(a, ((py, py), (px, px)))
	H, W = b.shape
	fy = np.fft.fftfreq(H)[:, None]
	fx = np.fft.rfftfreq(W)[None, :]
	k = np.exp(-2 * (math.pi**2) * sigma * sigma * (fx * fx + fy * fy))
	out = np.fft.irfft2(np.fft.rfft2(b) * k, s=(H, W))
	return out[py : py + h, px : px + w]


def glow_post(src, dst, name, grid):
	"""Emission render on black (linear EXR) -> straight-alpha RGBA PNG: alpha = (brightness + bloom) * gain."""
	import numpy as np

	gain, blooms, mode = POST[name]
	img = bpy.data.images.load(str(src))
	w, h = img.size
	px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
	bpy.data.images.remove(img)
	lum = px[..., :3].max(axis=-1)
	scale = 0.5 if FAST else 1.0
	total = lum.copy()
	cw, ch = w // grid, h // grid
	for sigma, weight in blooms:
		for r in range(grid):
			for c in range(grid):
				cell = lum[r * ch : (r + 1) * ch, c * cw : (c + 1) * cw]
				total[r * ch : (r + 1) * ch, c * cw : (c + 1) * cw] += gauss_blur(cell, sigma * scale, mode) * weight
	alpha = np.clip(total * gain, 0.0, 1.0)
	alpha[alpha < 1.5 / 255] = 0.0
	out = np.ones((h, w, 4), np.float32)
	if name in GREY_RGB:
		out[..., :3] = np.sqrt(alpha)[..., None]
	out[..., 3] = alpha
	im = bpy.data.images.new("post", w, h, alpha=True)
	im.alpha_mode = "STRAIGHT"
	im.pixels.foreach_set(out.ravel())
	im.filepath_raw = str(dst)
	im.file_format = "PNG"
	im.save()
	bpy.data.images.remove(im)


def render_sheet(name):
	width, height, grid, kind, build = SHEETS[name]
	aspect = width / height
	if kind == "plane":
		scene = setup_scene(width, height, 2 * aspect, 48)
		bpy.ops.mesh.primitive_plane_add(size=2)
		plane = bpy.context.active_object
		plane.scale = (aspect, 1, 1)
		bpy.ops.object.transform_apply(scale=True)  # object coordinates in -aspect..aspect, -1..1
		plane.data.materials.append(build(G(name), 0))
	else:
		scene = setup_scene(width, height, 2 * grid, 64)
		for i in range(grid * grid):
			col, row = i % grid, i // grid
			origin = ((col - (grid - 1) / 2) * 2, ((grid - 1) / 2 - row) * 2)
			if kind == "cells":
				bpy.ops.mesh.primitive_plane_add(size=2, location=(*origin, 0))
				bpy.context.active_object.data.materials.append(build(G(f"{name}{i}"), i))
			else:
				wisp_curves(i, origin)
	path = OUT / f"{name}.png"
	raw = OUT / f"_{name}.exr"
	scene.render.filepath = str(raw)
	bpy.ops.render.render(write_still=True)
	glow_post(raw, path, name, grid)
	raw.unlink()
	print(f"[healorb-vfx] {path.relative_to(ROOT)}")
	return path


def render_main():
	argv = [a for a in (sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []) if not a.startswith("--")]
	OUT.mkdir(parents=True, exist_ok=True)
	for name in argv or list(SHEETS):
		render_sheet(name)


# Preview (plain Python + Pillow) -----------------------------------------------

BG = (34, 36, 40)
TEAL = (0x5C, 0xFF, 0xC8)
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
		region = dst.crop((x, y, x + img.width, y + img.height)).convert("RGB")
		a = np.asarray(img, dtype=np.float32) / 255.0
		b = np.asarray(region, dtype=np.float32) / 255.0
		out = np.clip(b + a[..., :3] * a[..., 3:4] * gain, 0, 1)
		dst.paste(Image.fromarray((out * 255).astype("uint8"), "RGB"), (x, y))

	tex = {n: Image.open(OUT / f"{n}.png").convert("RGBA") for n in SHEETS}
	W, pad, H = 1500, 24, 7000
	sheet = Image.new("RGBA", (W, H), (*BG, 255))
	draw = ImageDraw.Draw(sheet)
	draw.text((pad, 16), "Heal Orb VFX textures on dark grey: green-teal #5CFFC8 tint and white (normal alpha blend unless noted)", fill=(235, 235, 235), font=f_title)
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
			im = tint(img.resize((cell, cell), Image.LANCZOS), color)
			if add:
				additive(sheet, im, (cx, y))
			else:
				sheet.alpha_composite(im, (cx, y))
			draw.text((cx + 6, y + 4), f"{k + 1}", fill=(160, 160, 165), font=f_small)
		if tag:
			draw.text((pad + len(imgs) * (cell + 10), y + 4), tag, fill=(150, 150, 155), font=f_small)
		y += cell + 14

	# Swirl: single tile teal / white, then 2x2 tiled (seams would show as lines), then additive.
	label("healorb_swirl.png  512x512", "teal, white, 2x2 tiled (seamless check, teal additive), RGB channel alone")
	s = tex["healorb_swirl"]
	t = s.resize((330, 330), Image.LANCZOS)
	sheet.alpha_composite(tint(t, TEAL), (pad, y))
	sheet.alpha_composite(tint(t, WHITE), (pad + 340, y))
	tiled = Image.new("RGBA", (660, 660))
	for k in range(4):
		tiled.paste(t, ((k % 2) * 330, (k // 2) * 330))
	tiled = tint(tiled.resize((330, 330), Image.LANCZOS), TEAL)
	additive(sheet, tiled, (pad + 680, y))
	rgb = Image.merge("RGBA", (*s.convert("RGB").split(), Image.new("L", s.size, 255))).resize((330, 330), Image.LANCZOS)
	sheet.alpha_composite(rgb, (pad + 1020, y))
	y += 330 + 26

	label("healorb_mote.png  256x256", "teal and white at actual size, teal additive at half and quarter size")
	m = tex["healorb_mote"]
	sheet.alpha_composite(tint(m, TEAL), (pad, y))
	sheet.alpha_composite(tint(m, WHITE), (pad + 270, y))
	additive(sheet, tint(m.resize((128, 128), Image.LANCZOS), TEAL), (pad + 560, y + 64))
	additive(sheet, tint(m.resize((64, 64), Image.LANCZOS), TEAL), (pad + 720, y + 96))
	y += 256 + 26

	label("healorb_wisp_2x2.png  1024x1024", "frames 1-4: teal (normal blend), white, teal additive (LightEmission 1)")
	row(frames(tex["healorb_wisp_2x2"], 2), 330, TEAL)
	row(frames(tex["healorb_wisp_2x2"], 2), 330, WHITE)
	row(frames(tex["healorb_wisp_2x2"], 2), 330, TEAL, add=True)
	y += 12

	label("healorb_burst_2x2.png  1024x1024", "frames 1-4: teal (normal blend), white, teal additive (LightEmission 1)")
	row(frames(tex["healorb_burst_2x2"], 2), 330, TEAL)
	row(frames(tex["healorb_burst_2x2"], 2), 330, WHITE)
	row(frames(tex["healorb_burst_2x2"], 2), 330, TEAL, add=True)
	y += 12

	label("healorb_ribbon.png  1024x256", "teal, white, then two tiles end to end (teal additive, seam check)")
	rb = tex["healorb_ribbon"]
	sheet.alpha_composite(tint(rb.resize((700, 175), Image.LANCZOS), TEAL), (pad, y))
	sheet.alpha_composite(tint(rb.resize((700, 175), Image.LANCZOS), WHITE), (pad + 740, y))
	y += 175 + 10
	two = Image.new("RGBA", (1400, 175))
	two.paste(rb.resize((700, 175), Image.LANCZOS), (0, 0))
	two.paste(rb.resize((700, 175), Image.LANCZOS), (700, 0))
	additive(sheet, tint(two, TEAL), (pad, y))
	y += 175 + 26

	label("healorb_ring.png  512x512", "teal, white, teal additive, then squashed like a rising ring seen at an angle")
	rg = tex["healorb_ring"].resize((330, 330), Image.LANCZOS)
	sheet.alpha_composite(tint(rg, TEAL), (pad, y))
	sheet.alpha_composite(tint(rg, WHITE), (pad + 340, y))
	additive(sheet, tint(rg, TEAL), (pad + 680, y))
	additive(sheet, tint(tex["healorb_ring"].resize((420, 120), Image.LANCZOS), TEAL), (pad + 1030, y + 100))
	y += 330 + 26

	label("healorb_edge.png  1024x576", "teal over a mid-grey 'screen' (1280x720 here) with a crosshair")
	scr = Image.new("RGBA", (1280, 720), (128, 128, 128, 255))
	sd = ImageDraw.Draw(scr)
	for k in range(720):
		c0 = int(150 - 40 * k / 720)
		sd.line((0, k, 1280, k), fill=(c0, c0, c0 + 4, 255))
	sd.line((640 - 12, 360, 640 + 12, 360), fill=(255, 255, 255, 255), width=2)
	sd.line((640, 360 - 12, 640, 360 + 12), fill=(255, 255, 255, 255), width=2)
	scr.alpha_composite(tint(tex["healorb_edge"].resize((1280, 720), Image.LANCZOS), TEAL))
	sheet.alpha_composite(scr, (pad, y))
	y += 720 + 20

	# Mock: the held orb (swirl disc + mote core + wisp) and a ribbon to the right (Pillow composite, not a render).
	label("Mock (Pillow composite, not a render)", "orb = swirl disc + motes + wisp frame 2, ribbon out to the right, burst frame 2, rising ring")
	mw, mh = W - 2 * pad, 520
	mock = Image.new("RGBA", (mw, mh), (40, 42, 46, 255))
	md = ImageDraw.Draw(mock)
	for k in range(mh):
		cc = int(36 + 30 * k / mh)
		md.line((0, k, mw, k), fill=(cc, cc, cc + 3, 255))
	ox, oy = 260, 260
	disc = tex["healorb_swirl"].resize((200, 200), Image.LANCZOS)
	mask = Image.new("L", (200, 200), 0)
	ImageDraw.Draw(mask).ellipse((0, 0, 199, 199), fill=255)
	da = np.asarray(disc, np.float32).copy()
	yy, xx = np.mgrid[0:200, 0:200]
	rr = np.sqrt((xx - 99.5) ** 2 + (yy - 99.5) ** 2) / 100.0
	da[..., 3] *= np.clip(1.0 - rr, 0, 1) ** 0.35 * (np.asarray(mask) / 255.0) * (0.55 + 0.45 * rr**2)
	disc = Image.fromarray(da.clip(0, 255).astype("uint8"), "RGBA")
	additive(mock, tint(tex["healorb_mote"].resize((420, 420), Image.LANCZOS), TEAL), (ox - 210, oy - 210), 0.7)
	additive(mock, tint(disc, TEAL), (ox - 100, oy - 100), 1.0)
	additive(mock, tint(tex["healorb_mote"].resize((110, 110), Image.LANCZOS), (210, 255, 240)), (ox - 55, oy - 55), 1.0)
	wf = frames(tex["healorb_wisp_2x2"], 2)[1].resize((230, 230), Image.LANCZOS)
	additive(mock, tint(wf, TEAL), (ox - 150, oy - 30), 0.9)
	rng = random.Random(4)
	for _ in range(12):
		sz = rng.randint(14, 36)
		additive(mock, tint(tex["healorb_mote"].resize((sz, sz), Image.LANCZOS), TEAL), (ox + rng.randint(-150, 130), oy + rng.randint(-160, 130)), 1.0)
	beam = tex["healorb_ribbon"].resize((800, 90), Image.LANCZOS)
	additive(mock, tint(beam, TEAL), (ox + 90, oy - 45), 1.0)
	bx = ox + 980
	additive(mock, tint(frames(tex["healorb_burst_2x2"], 2)[1].resize((300, 300), Image.LANCZOS), TEAL), (bx - 150, oy - 150), 0.9)
	additive(mock, tint(tex["healorb_ring"].resize((260, 70), Image.LANCZOS), TEAL), (bx - 130, oy + 120), 1.0)
	additive(mock, tint(tex["healorb_ring"].resize((200, 54), Image.LANCZOS), TEAL), (bx - 100, oy + 30), 0.7)
	sheet.alpha_composite(mock, (pad, y))
	y += mh + 20

	sheet = sheet.crop((0, 0, W, y + 6))
	PREVIEW.parent.mkdir(parents=True, exist_ok=True)
	sheet.convert("RGB").save(PREVIEW)
	print(f"[healorb-vfx] preview {PREVIEW.relative_to(ROOT)}")


if bpy is not None:
	render_main()
elif "--preview" in sys.argv:
	preview_main()
else:
	print(__doc__)
