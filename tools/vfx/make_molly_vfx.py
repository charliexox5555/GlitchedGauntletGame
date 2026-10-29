"""Renders the Molly (incendiary) fire textures with Blender, and their preview sheet.

Render (Blender, headless; about 4 minutes on a 12-core CPU, `--fast` for a quick half-size, low-sample check):

    "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup \
        --python tools/vfx/make_molly_vfx.py -- [names...] [--fast]

Preview contact sheet (plain Python + Pillow, run after rendering):

    python tools/vfx/make_molly_vfx.py --preview

Look (vault/01 Design/Abilities/Molly.md): a Valorant-style incendiary patch in a plain, realistic, classic
tactical look: low knee-high flames, a little smoke, floating embers, a scorch mark, a clear burning edge, and
a "whoomp" of flame on the burst. Fire is NOT team-tinted, so the fire textures carry baked fire colours
(straight-alpha RGBA PNG); smoke and the ember are greyscale for tinting in Roblox. Output goes to
art-source/vfx/abilities/molly/.

  molly_flame_4x4     1024x1024  4x4 flipbook (16 frames, left-right, top-bottom), a SEAMLESS LOOP: a low cluster
                                 of flame tongues, base on the bottom edge. Rising noise erodes tongue-shaped
                                 envelopes; the noise is periodic in height and time (height mapped onto a circle
                                 in 4D noise), so frame 16 flows into frame 1.
  molly_smoke_2x2     1024x1024  2x2 flipbook: a soft grey smoke puff (lit Cycles volume) that rises, spreads and
                                 thins over the 4 frames. Greyscale (tint it darker in game).
  molly_ember         128x128    one glowing ember: hot white core, soft halo. Greyscale.
  molly_burst_2x2     1024x1024  2x2 flipbook: the "whoomp" (side view, base on the bottom edge): a hot pop, a
                                 flame dome rolling outward, a wide low sheet of flame, then low tongues dying
                                 down. Baked fire colours.
  molly_scorch        1024x1024  top-down burn decal: mottled char centre, soot falloff, ragged outline, a few
                                 splash spots; alpha falls to 0 well inside the border. Near-black, warm-brown rim.
  molly_edge          1024x256   burning edge band, TILEABLE in u (left/right edges match): a bright burning line
                                 at the bottom (v = 0, the ground) with flame licks rising and fading by the top.
                                 Baked fire colours.

Every frame is a Cycles render. Fire (flame, burst, edge) is pure emission: the flame and burst are 12 stacked
emissive slices through a 3D noise field (a noise-free stand-in for a volume), rendered on black and turned into
colour + alpha by fire_post (alpha = brightness). The smoke is a lit Cycles volume; the ember and scorch are shader
maths on a plane. Seeds are fixed, so re-running gives the same images.
"""

import math
import random
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art-source" / "vfx" / "abilities" / "molly"
PREVIEW = ROOT / "vault" / "02 Art" / "References" / "abilities" / "molly" / "molly_vfx_preview.png"

try:
	import bpy
except ImportError:  # Plain Python: preview mode only.
	bpy = None

FAST = "--fast" in sys.argv


# Node maths (same helpers as make_dash_vfx.py, plus colour ramps and looping noise) ---------------


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


# Fire colour ramp (linear RGB): soot red -> deep orange -> orange -> amber -> pale yellow -> near white.
FIRE_RAMP = [
	(0.0, (0.06, 0.004, 0.0)),
	(0.18, (0.45, 0.045, 0.004)),
	(0.4, (1.0, 0.16, 0.012)),
	(0.62, (1.0, 0.3, 0.03)),
	(0.82, (1.0, 0.52, 0.1)),
	(1.0, (1.0, 0.8, 0.38)),
]


class G:
	"""Builds one material's node tree."""

	def __init__(self, name, frame=None):
		# frame: an empty whose object space the coordinates use (the stacked fire slices share one frame).
		m = bpy.data.materials.new(name)
		if m.node_tree is None:
			m.use_nodes = True
		nt = m.node_tree
		nt.nodes.clear()
		self.mat = m
		self.nt = nt
		tc = self.node("ShaderNodeTexCoord")
		if frame is not None:
			tc.object = frame
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
		elif isinstance(value, tuple):
			sock.default_value = value
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

	def noise(self, x, y, z=0.0, w=0.0, detail=2.0, rough=0.5, lac=2.0, distortion=0.0):
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
		n.inputs["Distortion"].default_value = distortion
		return S(self, n.outputs["Fac"])

	def rising(self, x, y, z, t, sx, sy, period, cycles=1, seed=0.0, detail=3.0, rough=0.55):
		"""Noise that flows up (+y) and loops: periodic in y (period) and in t (0..1 = `cycles` periods).

		Height is mapped onto a circle in the noise's last two dimensions, so the field repeats every `period`
		in y; moving the angle with t scrolls it upward and wraps back exactly at t = 1.
		sx = feature frequency across (x and z), sy = along the rise (smaller sy = taller, streakier features).
		"""
		rho = sy * period / math.tau
		th = (y * (1.0 / period) - t * cycles) * math.tau
		# Depth (z) varies slowly, so stacked slices agree and outlines stay crisp.
		return self.noise(x * sx + seed * 7.31, z * (sx * 0.2) + seed * 3.17, rho * self.cos(th), rho * self.sin(th), detail=detail, rough=rough)

	def tiled(self, u, v, sx, sv, seed=0.0, detail=3.0, rough=0.55, extra=0.0):
		"""Noise periodic in u (0..1 wraps): u on a circle in the first two dimensions."""
		rho = sx / math.tau
		a = u * math.tau
		return self.noise(rho * self.cos(a) + seed * 5.1, rho * self.sin(a) - seed * 2.3, v * sv, extra + seed, detail=detail, rough=rough)

	def ramp(self, value, stops=FIRE_RAMP):
		n = self.node("ShaderNodeValToRGB")
		cr = n.color_ramp
		cr.interpolation = "B_SPLINE"
		while len(cr.elements) < len(stops):
			cr.elements.new(0.5)
		for el, (t, c) in zip(cr.elements, stops):
			el.position = t
			el.color = (*c, 1.0)
		self.put(n.inputs["Fac"], value)
		return n.outputs["Color"]

	def output(self, alpha, color=1.0, strength=1.0):
		"""Emission colour (grey value or ramp colour socket) with straight `alpha` on a transparent film."""
		em = self.node("ShaderNodeEmission")
		if isinstance(color, S):
			self.link(color.sock, em.inputs["Color"])
		elif isinstance(color, (int, float)):
			em.inputs["Color"].default_value = (color, color, color, 1.0)
		elif isinstance(color, tuple):
			em.inputs["Color"].default_value = color
		else:
			self.link(color, em.inputs["Color"])
		self.put(em.inputs["Strength"], strength)
		tr = self.node("ShaderNodeBsdfTransparent")
		mix = self.node("ShaderNodeMixShader")
		self.put(mix.inputs[0], self.clamp01(alpha))
		self.link(tr.outputs[0], mix.inputs[1])
		self.link(em.outputs[0], mix.inputs[2])
		out = self.node("ShaderNodeOutputMaterial")
		self.link(mix.outputs[0], out.inputs["Surface"])
		return self.mat

	def fire(self, density, temp, absorb=5.0, glow=3.0):
		"""Emissive, absorbing (sooty) volume: alpha from the density, colour from the temperature ramp."""
		pv = self.node("ShaderNodeVolumePrincipled")
		pv.inputs["Color"].default_value = (0.0, 0.0, 0.0, 1.0)  # no scattering: soot absorbs
		self.put(pv.inputs["Density"], density * absorb)
		self.link(self.ramp(temp), pv.inputs["Emission Color"])
		self.put(pv.inputs["Emission Strength"], density * (temp**1.4) * glow)
		out = self.node("ShaderNodeOutputMaterial")
		self.link(pv.outputs[0], out.inputs["Volume"])
		return self.mat

	def glow(self, strength, temp):
		"""Pure emission (fire is light) that lets everything behind it through: colour from the temperature
		ramp. Stacked slices of it add up like a volume, without a volume's sampling noise. Rendered on black and
		turned into colour + alpha afterwards (fire_post)."""
		em = self.node("ShaderNodeEmission")
		self.link(self.ramp(temp), em.inputs["Color"])
		self.put(em.inputs["Strength"], strength)
		tr = self.node("ShaderNodeBsdfTransparent")
		add = self.node("ShaderNodeAddShader")
		self.link(em.outputs[0], add.inputs[0])
		self.link(tr.outputs[0], add.inputs[1])
		out = self.node("ShaderNodeOutputMaterial")
		self.link(add.outputs[0], out.inputs["Surface"])
		return self.mat

	def volume(self, density, color=1.0):
		"""Grey scattering volume (smoke); lit by the scene lights."""
		pv = self.node("ShaderNodeVolumePrincipled")
		pv.inputs["Color"].default_value = (color, color, color, 1.0)
		pv.inputs["Anisotropy"].default_value = 0.25
		self.put(pv.inputs["Density"], density)
		out = self.node("ShaderNodeOutputMaterial")
		self.link(pv.outputs[0], out.inputs["Volume"])
		return self.mat


# Textures --------------------------------------------------------------------------
# Volume frames: object coordinates -1..1, +y = up in the image, z = depth toward the camera.

FLAME_FRAMES = 16
BASE = -0.94  # flame base (just above the bottom edge of the frame)

# Envelopes of the flame cluster: (x, height, half width at the base, lean, flicker phase, flicker cycles). The
# individual tongues come from the rising noise, so they change shape every frame instead of being fixed cones.
TONGUES = [
	(0.0, 1.62, 0.78, 0.05, 0.0, 1),
	(-0.3, 1.05, 0.55, -0.1, 0.37, 2),
	(0.34, 1.12, 0.52, 0.12, 0.71, 1),
]


def sn(n, gain=4.0):
	"""Perlin fac (about 0.5 +- 0.15) -> signed, roughly -0.8..0.8."""
	return (n - 0.5) * gain


def tongue_shape(g, x, y, z, xc, height, half, lean, t_flick):
	"""Signed field of one flame envelope: 1 on its axis, 0 on its outline, negative outside (down to -1)."""
	hgt = height * (1.0 + 0.12 * math.sin(t_flick) + 0.05 * math.sin(2 * t_flick + 1.3))
	h = (y - BASE) * (1.0 / hgt)
	hc = g.clamp01(h)
	prof = g.max(g.clamp01(1.0 - h) ** 0.5, 0.004)
	wdt = prof * half
	dx = (x - xc - (hc * hc) * lean) / wdt
	dz = z / (wdt * 1.1)  # slices nearly agree on the outline: crisp edges, a little depth
	rr = g.sqrt(dx * dx + dz * dz)
	inside = g.max(1.0 - rr, -1.0)
	return inside


def flame(g, i):
	t = i / FLAME_FRAMES
	x0, y0, z = g.x, g.y, g.z
	hg = g.clamp01((y0 - BASE) * (1.0 / 1.85))  # 0 at the base, 1 at the top of the frame
	# Rising, looping warp: the flame sways and licks, more toward the top.
	wx = sn(g.rising(x0, y0, z, t, 1.5, 0.9, 2.6, 1, seed=1.0, detail=2.0))
	x = x0 + wx * (0.02 + 0.32 * hg**1.5)
	shape = 0.0
	for k, (xc, height, half, lean, ph, cyc) in enumerate(TONGUES):
		s = tongue_shape(g, x, y0, z, xc, height, half, lean, (t * cyc + ph) * math.tau)
		shape = s if k == 0 else g.max(shape, s)
	# Erosion: rising fBm, streaky (tall features), with a fine layer rising faster; stronger with height.
	big = sn(g.rising(x, y0, z, t, 2.6, 1.6, 2.6, 2, seed=3.0, detail=3.0, rough=0.55))
	fine = sn(g.rising(x, y0, z, t, 6.0, 3.2, 1.3, 3, seed=4.0, detail=3.0, rough=0.55))
	# Tall vertical streaks split the top into separate licking tongues.
	lick = sn(g.rising(x, y0, z, t, 3.6, 0.7, 2.6, 1, seed=5.0, detail=1.0, rough=0.5))
	n = big * (0.14 + 0.6 * hg) + lick * (0.04 + 0.6 * hg) + fine * (0.05 + 0.2 * hg)
	field = shape + n - 0.12 * hg
	body = g.smooth(field, 0.0, 0.06 + 0.1 * hg)
	# Soft, uneven base: the flame rises out of a glowing bed instead of sitting on a ruled line.
	bed = BASE + 0.05 * sn(g.noise(x0 * 3.0, z * 0.6, 0.0, w=float(i) * 0.0 + 30.0, detail=2.0))
	body = body * g.smooth(y0, bed - 0.03, bed + 0.2)
	# Hot in the core low down, cooling up the tongues to deep orange-red tips.
	temp = g.clamp01(field * 1.35) * (1.0 - 0.7 * hg) + g.soft(y0 - BASE, 0.1) * 0.1 * g.clamp01(shape * 3.0)
	temp = g.clamp01(temp)
	keep = g.smooth(g.abs(x0), 0.99, 0.9) * g.smooth(y0, 0.99, 0.9)
	# Brighter and darker rising sheets inside the body, so it reads as layered flame, not one flat glow.
	sheets = g.clamp01(1.0 - g.abs(sn(g.rising(x, y0, z, t, 9.0, 2.2, 1.3, 3, seed=6.0, detail=2.0), 2.5)))
	return g.glow(body * keep * (0.3 + temp) * (0.6 + 0.55 * sheets), temp)


BURST = [
	# (spread half-width, height, heat, hollow centre, erosion, squareness of the spread)
	(0.52, 0.95, 1.0, 0.0, 0.0, 2.0),
	(0.8, 1.15, 0.95, 0.0, 0.05, 3.0),
	(0.97, 0.95, 0.85, 0.2, 0.12, 5.0),
	(0.99, 0.72, 0.7, 0.3, 0.3, 6.0),
]


def burst(g, i):
	"""The whoomp, side view: a hot pop that rolls out into a wide low sheet of flame and breaks up."""
	rad, hgt, heat, hollow, erode, square = BURST[i]
	t = i * 0.11  # the same rising noise field, moved up a little each frame (frames share structure)
	x0, y0, z = g.x, g.y, g.z
	hg = g.clamp01((y0 - BASE) * (1.0 / 1.85))
	wx = sn(g.rising(x0, y0, z, t, 1.5, 1.0, 2.6, 1, seed=11.0, detail=2.0))
	x = x0 + wx * (0.03 + 0.3 * hg)
	# Ragged dome: the top height varies across (rising tongues), the outline is a flattened half-ellipse.
	tongues = g.noise(x * 4.0, z * 0.8, 0.0, w=40.0 + i * 0.15, detail=2.0)
	top = hgt * (0.6 + 0.8 * g.smooth(tongues, 0.3, 0.72))
	ex = g.abs(x / rad) ** square  # higher = flatter, wider sheet of fire
	ey = (y0 - BASE) / top
	ez = z / (rad * 0.9)
	env = 1.0 - g.sqrt(ex + ey * ey + ez * ez)
	if hollow > 0:  # the fire has rolled outward: thinner in the middle
		env = env - hollow * g.soft(x, rad * 0.45) * g.smooth(y0 - BASE, 0.05, 0.3)
	big = sn(g.rising(x, y0, z, t, 2.8, 1.8, 2.6, 2, seed=13.0, detail=3.0, rough=0.55))
	lick = sn(g.rising(x, y0, z, t, 4.0, 0.8, 2.6, 1, seed=15.0, detail=1.0))
	fine = sn(g.rising(x, y0, z, t, 7.0, 3.6, 1.3, 3, seed=14.0, detail=3.0, rough=0.55))
	n = big * (0.14 + 0.5 * hg + 0.25 * erode) + lick * (0.04 + 0.45 * hg) + fine * (0.05 + 0.18 * hg + 0.15 * erode)
	field = env + n - 0.08 * hg - 0.15 * erode
	body = g.smooth(field, 0.0, 0.06 + 0.1 * hg)
	body = body * g.smooth(y0, BASE - 0.03, BASE + 0.16)
	# Hot white-yellow pop in the first frames, cooling to orange.
	core = g.soft(g.length(x0 / (rad * 0.8), (y0 - BASE) / (hgt * 0.75)), 0.75) * (0.55, 0.3, 0.08, 0.0)[i]
	temp = g.clamp01((g.clamp01(field * 1.35) * (1.0 - 0.6 * hg) + core) * heat)
	sheets = g.clamp01(1.0 - g.abs(sn(g.rising(x, y0, z, t, 9.0, 2.2, 1.3, 3, seed=16.0, detail=2.0), 2.5)))
	keep = g.smooth(g.abs(x0), 0.99, 0.9) * g.smooth(y0, 0.99, 0.9)
	gain = (1.0, 1.0, 0.9, 0.72)[i]  # the flash is brightest at the pop
	return g.glow(body * keep * (0.3 + temp) * (0.6 + 0.55 * sheets) * gain, temp)


SMOKE = [
	# (radius, rise, density, holes)
	(0.4, -0.05, 9.0, 0.0),
	(0.52, 0.02, 6.5, 0.0),
	(0.62, 0.08, 4.0, 0.25),
	(0.7, 0.12, 2.2, 0.38),
]


def smoke(g, i):
	"""A soft rising smoke puff: billowy (cauliflower) noise on a warped ball, wispier and thinner each frame."""
	size, rise, dens, holes_at = SMOKE[i]
	seed = 41.0 + i * 0.2  # neighbouring frames share structure
	x0, y0, z0 = g.x, g.y - rise, g.z * 1.2
	warp = size * (0.35 + 0.1 * i)
	wx = sn(g.noise(x0 * 1.8, y0 * 1.8, z0 * 1.8, w=seed + 50.0, detail=2.0))
	wy = sn(g.noise(x0 * 1.8, y0 * 1.8, z0 * 1.8, w=seed + 60.0, detail=2.0))
	wz = sn(g.noise(x0 * 1.8, y0 * 1.8, z0 * 1.8, w=seed + 70.0, detail=2.0))
	x, y, z = x0 + wx * warp * 0.5, y0 + wy * warp * 0.5, z0 + wz * warp * 0.5
	d = g.sqrt(x * x + (y * 1.1) * (y * 1.1) + z * z) - size
	# Billows: |signed noise| at three scales gives rounded lobes with creases between them.
	b1 = g.abs(sn(g.noise(x * 2.4, y * 2.4, z * 2.4, w=seed + 7.0, detail=1.0)))
	b2 = g.abs(sn(g.noise(x * 5.5, y * 5.5, z * 5.5, w=seed + 8.0, detail=1.0)))
	b3 = g.abs(sn(g.noise(x * 12.0, y * 12.0, z * 12.0, w=seed + 9.0, detail=2.0)))
	d = d - size * (b1 * 0.5 + b2 * 0.22 + b3 * 0.08) + size * 0.3
	soft = size * (0.06 + 0.08 * i)
	density = g.smooth(d, soft, -soft)
	if holes_at > 0:
		hole = g.noise(x * 2.6, y * 2.6, z * 2.6, w=seed + 13.0, detail=3.0, rough=0.5)
		density = density * g.smooth(hole, holes_at, holes_at + 0.25)
	keep = g.smooth(g.length(g.x, g.y), 0.98, 0.85)
	return g.volume(density * keep * dens, 0.8)


def ember(g, _i):
	r = g.length(g.x, g.y)
	core = g.soft(r, 0.09)
	glow = g.soft(r, 0.3) * 0.38 + g.soft(r, 0.62) * 0.1
	alpha = core + glow
	return g.output(alpha, g.clamp01(0.55 + core * 0.6))


def scorch(g, _i):
	"""Top-down burn mark: mottled char in the middle, a soot falloff with a warm-brown scorched band, a ragged
	outline and a few burnt splash spots outside it."""
	x0, y0 = g.x, g.y
	# Domain warp so no circle survives.
	wx = sn(g.noise(x0 * 1.6, y0 * 1.6, 0.0, w=1.0, detail=3.0))
	wy = sn(g.noise(x0 * 1.6, y0 * 1.6, 0.0, w=2.0, detail=3.0))
	x, y = x0 + wx * 0.12, y0 + wy * 0.12
	r = g.length(x, y)
	a = g.atan2(y, x)
	ca, sa = g.cos(a), g.sin(a)
	lobes = sn(g.noise(ca * 1.1, sa * 1.1, 0.0, w=3.0, detail=2.0))
	mid = sn(g.noise(ca * 3.5, sa * 3.5, 0.0, w=4.0, detail=3.0, rough=0.6))
	edge = 0.62 + lobes * 0.13 + mid * 0.05
	rr = r / edge
	mottle = g.noise(x * 5.0, y * 5.0, 0.0, w=13.0, detail=5.0, rough=0.62)
	grain = g.noise(x * 40.0, y * 40.0, 0.0, w=17.0, detail=2.0, rough=0.5)
	core = g.smooth(rr, 0.92, 0.5) * (0.88 + 0.12 * g.smooth(mottle, 0.35, 0.6))
	halo = g.smooth(rr, 1.45, 0.75) * 0.55 * (0.7 + 0.3 * g.smooth(mottle, 0.3, 0.7))
	# Splash spots: burnt fuel droplets thrown out past the edge.
	spots = g.noise(x * 10.0, y * 10.0, 0.0, w=21.0, detail=2.0, rough=0.5)
	splash = g.smooth(spots, 0.66, 0.72) * g.smooth(rr, 1.7, 1.05) * g.smooth(rr, 0.8, 1.05) * 0.75
	alpha = g.max(g.max(core, halo), splash) * (0.9 + 0.1 * grain) * g.smooth(g.length(x0, y0), 0.99, 0.88)
	# Colour: near-black char, grey ash patches inside, warm brown where the soot thins out.
	ash = g.smooth(mottle, 0.62, 0.74) * g.smooth(rr, 0.8, 0.35) * 0.07
	brown = g.smooth(rr, 0.6, 1.0)
	base = 0.012 + 0.014 * grain + ash
	cr = g.node("ShaderNodeCombineColor")
	g.put(cr.inputs[0], base + brown * 0.055)
	g.put(cr.inputs[1], base + brown * 0.032)
	g.put(cr.inputs[2], base + brown * 0.016)
	return g.output(alpha, cr.outputs[0])


def edge(g, _i):
	"""Tileable burning band: hot line on the ground (v = 0), flame licks rising and fading by v = 1."""
	u, v = g.u, g.v
	# Lick heights vary along u (periodic noise); the licks streak upward.
	tall = g.tiled(u, 0.0, 10.0, 0.0, seed=1.0, detail=2.0)
	height = 0.32 + 0.6 * g.smooth(tall, 0.32, 0.7)
	warp = sn(g.tiled(u, v, 12.0, 2.0, seed=2.0, detail=2.0))
	uu = u + warp * 0.012 * v
	big = sn(g.tiled(uu, v, 26.0, 3.0, seed=3.0, detail=3.0, rough=0.55))
	lick = sn(g.tiled(uu, v, 30.0, 1.4, seed=4.0, detail=1.0))
	fine = sn(g.tiled(uu, v, 70.0, 7.0, seed=5.0, detail=3.0, rough=0.55))
	h = v / height
	env = 1.0 - h
	field = env + big * (0.1 + 0.4 * v) + lick * (0.05 + 0.45 * v) + fine * (0.04 + 0.15 * v) - 0.1 * v
	body = g.smooth(field, 0.0, 0.08 + 0.1 * v)
	temp = g.clamp01(field * 1.1) * (0.95 - 0.6 * v)
	sheets = g.clamp01(1.0 - g.abs(sn(g.tiled(uu, v, 60.0, 2.5, seed=6.0, detail=2.0), 2.5)))
	strength = body * (0.3 + temp) * (0.6 + 0.55 * sheets)
	# The burning line on the ground: a bright, slightly broken band right at the bottom, plus a low glow.
	line = g.soft(v - 0.05, 0.035) * (0.75 + 0.25 * sn(g.tiled(u, 0.0, 50.0, 0.0, seed=7.0, detail=2.0)))
	glow = g.soft(v, 0.22) * 0.25
	strength = strength + line * 1.0 + glow * 0.5
	temp = g.clamp01(g.max(temp, line * 0.9))
	return g.output(g.clamp01(strength) * g.smooth(v, 0.0, 0.012), g.ramp(temp), 1.0)


# Sheets -------------------------------------------------------------------------------
# name: (width, height, grid, kind, builder)

SHEETS = {
	"molly_flame_4x4": (1024, 1024, 4, "fire", flame),
	"molly_smoke_2x2": (1024, 1024, 2, "smoke", smoke),
	"molly_ember": (128, 128, 1, "plane", ember),
	"molly_burst_2x2": (1024, 1024, 2, "fire", burst),
	"molly_scorch": (1024, 1024, 1, "plane", scorch),
	"molly_edge": (1024, 256, 1, "fireplane", edge),
}


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


def light_smoke(scene):
	"""Soft key from the upper left plus a grey sky: light grey smoke with gentle shading."""
	scene.cycles.volume_bounces = 2
	world = bpy.data.worlds.new("world")
	world.use_nodes = True
	bg = world.node_tree.nodes.get("Background") or world.node_tree.nodes.new("ShaderNodeBackground")
	bg.inputs["Color"].default_value = (1.0, 1.0, 1.0, 1.0)
	bg.inputs["Strength"].default_value = 0.22
	out = world.node_tree.nodes.get("World Output") or world.node_tree.nodes.new("ShaderNodeOutputWorld")
	world.node_tree.links.new(bg.outputs[0], out.inputs["Surface"])
	scene.world = world
	sun_data = bpy.data.lights.new("sun", "SUN")
	sun_data.energy = 4.5
	sun_data.angle = math.radians(12)
	sun = bpy.data.objects.new("sun", sun_data)
	sun.rotation_euler = (math.radians(35), math.radians(-30), math.radians(10))
	scene.collection.objects.link(sun)


def fire_post(src, dst, exposure, gamma=1.15):
	"""Emission render on black (linear EXR) -> straight-alpha RGBA PNG.

	Fire is light, so alpha comes from brightness: the image is scaled so its brightest flame core (99.7th
	percentile of the lit pixels) is `exposure`, alpha = brightest channel (softened by gamma) and colour = emission /
	alpha, clipped. Composited with normal alpha blending on black it reproduces the render; with Roblox
	LightEmission it adds up like real flame light.
	"""
	import numpy as np

	img = bpy.data.images.load(str(src))
	w, h = img.size
	px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
	bpy.data.images.remove(img)
	e = px[..., :3]
	lum = e.max(axis=-1)  # brightest channel: saturated orange counts as fully bright
	lit = lum[lum > 1e-4]
	k = exposure / max(float(np.percentile(lit, 99.7)) if lit.size else 1.0, 1e-6)
	e = e * k
	lum = lum * k
	alpha = np.clip(lum, 0.0, 1.0) ** gamma
	col = np.clip(e / np.maximum(alpha, 1e-4)[..., None], 0.0, 1.0)
	col = np.where(col <= 0.0031308, col * 12.92, 1.055 * np.power(col, 1 / 2.4) - 0.055)
	out = np.concatenate([col, alpha[..., None]], axis=-1).astype(np.float32)
	im = bpy.data.images.new("post", w, h, alpha=True)
	im.alpha_mode = "STRAIGHT"
	im.pixels.foreach_set(out.ravel())
	im.filepath_raw = str(dst)
	im.file_format = "PNG"
	im.save()
	bpy.data.images.remove(im)


# Brightness of each emissive sheet's hottest pixels after fire_post (1 = the core just reaches white-yellow).
EXPOSURE = {"molly_flame_4x4": 1.7, "molly_burst_2x2": 1.6, "molly_edge": 1.6}


SLICES = 12


def render_sheet(name):
	width, height, grid, kind, build = SHEETS[name]
	if kind in ("strip", "plane", "fireplane"):
		aspect = width / height
		scene = setup_scene(width, height, 2 * aspect, 64)
		bpy.ops.mesh.primitive_plane_add(size=2)
		plane = bpy.context.active_object
		plane.scale = (aspect, 1, 1)
		plane.data.materials.append(build(G(name), 0))
	else:
		scene = setup_scene(width, height, 2 * grid, 24 if kind == "fire" else 96)
		if kind == "smoke":
			light_smoke(scene)
		else:
			scene.cycles.volume_bounces = 0
		for i in range(grid * grid):
			col, row = i % grid, i // grid
			origin = ((col - (grid - 1) / 2) * 2, ((grid - 1) / 2 - row) * 2)
			if kind == "fire":
				# SLICES emissive planes through the frame's depth (z -0.5..0.5), all in one frame's space.
				frame = bpy.data.objects.new(f"{name}{i}_frame", None)
				scene.collection.objects.link(frame)
				frame.location = (*origin, 0)
				mat = build(G(f"{name}{i}", frame), i)
				for k in range(SLICES):
					zk = -0.5 + (k + 0.5) / SLICES
					bpy.ops.mesh.primitive_plane_add(size=2, location=(origin[0], origin[1], zk))
					bpy.context.active_object.data.materials.append(mat)
			else:
				bpy.ops.mesh.primitive_cube_add(size=2, location=(*origin, 0))
				obj = bpy.context.active_object
				obj.data.materials.append(build(G(f"{name}{i}"), i))
	path = OUT / f"{name}.png"
	if kind in ("fire", "fireplane"):
		# Emission on black, linear float; fire_post makes the alpha.
		scene.render.film_transparent = False
		world = bpy.data.worlds.new("black")
		world.use_nodes = True
		world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.0
		scene.world = world
		scene.render.image_settings.file_format = "OPEN_EXR"
		scene.render.image_settings.color_depth = "32"
		scene.render.image_settings.color_mode = "RGB"
		raw = OUT / f"_{name}.exr"
		scene.render.filepath = str(raw)
		bpy.ops.render.render(write_still=True)
		fire_post(raw, path, EXPOSURE.get(name, 1.0))
		raw.unlink()
	else:
		scene.render.filepath = str(path)
		bpy.ops.render.render(write_still=True)
	print(f"[molly-vfx] {path.relative_to(ROOT)}")
	return path


def render_main():
	argv = [a for a in (sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []) if not a.startswith("--")]
	OUT.mkdir(parents=True, exist_ok=True)
	for name in argv or list(SHEETS):
		render_sheet(name)


# Preview (plain Python + Pillow) -----------------------------------------------

BG = (34, 36, 40)


def preview_main():
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

	def additive(dst, img, pos, gain=1.0):
		"""Composite like Roblox LightEmission = 1 (colour * alpha added)."""
		import numpy as np

		x, y = pos
		region = dst.crop((x, y, x + img.width, y + img.height)).convert("RGB")
		a = np.asarray(img, dtype=np.float32) / 255.0
		b = np.asarray(region, dtype=np.float32) / 255.0
		out = np.clip(b + a[..., :3] * a[..., 3:4] * gain, 0, 1)
		dst.paste(Image.fromarray((out * 255).astype("uint8"), "RGB"), (x, y))

	tex = {n: Image.open(OUT / f"{n}.png").convert("RGBA") for n in SHEETS}
	W, pad, H = 1500, 24, 4200
	sheet = Image.new("RGBA", (W, H), (*BG, 255))
	draw = ImageDraw.Draw(sheet)
	draw.text((pad, 16), "Molly VFX textures on dark grey (normal alpha blend unless noted)", fill=(235, 235, 235), font=f_title)
	y = 64

	def label(text, sub=None):
		nonlocal y
		draw.text((pad, y), text, fill=(230, 230, 230), font=f_head)
		if sub:
			draw.text((pad + draw.textlength(text, font=f_head) + 14, y + 4), sub, fill=(150, 150, 155), font=f_small)
		y += 30

	def cells(imgs, cell, per_row, add=False):
		nonlocal y
		for k, img in enumerate(imgs):
			cx = pad + (k % per_row) * (cell + 10)
			if k and k % per_row == 0:
				y += cell + 10
			draw.rectangle((cx, y, cx + cell - 1, y + cell - 1), outline=(48, 50, 56))
			im = img.resize((cell, cell), Image.LANCZOS)
			if add:
				additive(sheet, im, (cx, y))
			else:
				sheet.alpha_composite(im, (cx, y))
			draw.text((cx + 6, y + 4), f"{k + 1}", fill=(160, 160, 165), font=f_small)
		y += cell + 26

	label("molly_flame_4x4.png  1024x1024", "16-frame seamless loop, base at the bottom (frames 1-16)")
	cells(frames(tex["molly_flame_4x4"], 4), 170, 8)
	label("molly_burst_2x2.png  1024x1024", "the whoomp, frames 1-4, base at the bottom")
	cells(frames(tex["molly_burst_2x2"], 2), 330, 4)
	label("molly_smoke_2x2.png  1024x1024", "greyscale puff, frames 1-4 (shown untinted)")
	cells(frames(tex["molly_smoke_2x2"], 2), 330, 4)

	label("molly_edge.png  1024x256", "tileable in u: shown twice side by side (the seam is in the middle)")
	e = tex["molly_edge"]
	sheet.alpha_composite(e.resize((700, 175), Image.LANCZOS), (pad, y))
	sheet.alpha_composite(e.resize((700, 175), Image.LANCZOS), (pad + 700, y))
	y += 175 + 26

	label("molly_scorch.png  1024x1024", "decal: on dark grey (left) and on a light concrete-grey floor (right)")
	sc = tex["molly_scorch"].resize((380, 380), Image.LANCZOS)
	sheet.alpha_composite(sc, (pad, y))
	floor = Image.new("RGBA", (380, 380), (150, 148, 142, 255))
	floor.alpha_composite(sc)
	sheet.alpha_composite(floor, (pad + 400, y))
	draw.text((pad + 800, y), "molly_ember.png  128x128", fill=(230, 230, 230), font=f_head)
	em = tex["molly_ember"]
	sheet.alpha_composite(em, (pad + 800, y + 34))
	sheet.alpha_composite(em.resize((256, 256), Image.LANCZOS), (pad + 950, y + 34))
	draw.text((pad + 800, y + 300), "actual size / 2x (greyscale; tint orange)", fill=(150, 150, 155), font=f_small)
	y += 380 + 30

	# Mock fire patch: a perspective-squashed scorch, the edge band around an ellipse, flame sprites scattered.
	label("Mock patch (Pillow composite, not a render)", "scorch decal + edge band + ~40 flame sprites (LightEmission ~0.6) + smoke")
	mw, mh = W - 2 * pad, 560
	mock = Image.new("RGBA", (mw, mh), (58, 60, 62, 255))
	md = ImageDraw.Draw(mock)
	for k in range(0, mh, 2):  # simple floor gradient
		c = int(52 + 30 * k / mh)
		md.line((0, k, mw, k), fill=(c, c - 1, c - 3, 255))
	cx, cy, rx, ry = mw // 2, int(mh * 0.62), 520, 150
	scm = tex["molly_scorch"].resize((int(rx * 2.25), int(ry * 2.25)), Image.LANCZOS)
	mock.alpha_composite(scm, (cx - scm.width // 2, cy - scm.height // 2))
	rng = random.Random(4)
	fl = frames(tex["molly_flame_4x4"], 4)
	sprites = []
	for k in range(46):
		ang = rng.uniform(0, math.tau)
		rad = math.sqrt(rng.random()) * 0.92
		px, py = cx + math.cos(ang) * rx * rad, cy + math.sin(ang) * ry * rad
		size = int(rng.uniform(70, 120) * (0.8 + 0.4 * (py - (cy - ry)) / (2 * ry)))
		sprites.append((py, px, size, rng.randrange(16)))
	# The edge band: the strip wrapped round the ellipse (3 tiles) as thin upright slices, max-blended into
	# two layers (back half behind the flames, front half in front) so overlapping slices don't double up.
	import numpy as np

	strip = tex["molly_edge"]
	segs, tiles = 240, 3
	seg_w = max(2, int(2 * math.pi * math.sqrt((rx * rx + ry * ry) / 2) / segs) + 8)
	layers = {True: np.zeros((mh, mw, 3), np.float32), False: np.zeros((mh, mw, 3), np.float32)}
	for k in range(segs):
		ang = (k + 0.5) / segs * math.tau
		px, py = cx + math.cos(ang) * rx, cy + math.sin(ang) * ry
		u0 = (k * tiles * strip.width // segs) % strip.width
		u1 = min(strip.width, u0 + max(1, tiles * strip.width // segs))
		seg = np.asarray(strip.crop((u0, 0, u1, strip.height)).resize((seg_w, 52), Image.LANCZOS), np.float32) / 255
		pre = seg[..., :3] * seg[..., 3:4]
		x0, y0 = int(px - seg_w / 2), int(py - 50)
		lay = layers[math.sin(ang) < 0]  # True = back half
		h, w = pre.shape[:2]
		lay[y0 : y0 + h, x0 : x0 + w] = np.maximum(lay[y0 : y0 + h, x0 : x0 + w], pre)

	def add_layer(lay, gain):
		base = np.asarray(mock.convert("RGB"), np.float32) / 255
		out = np.clip(base + lay * gain, 0, 1)
		mock.paste(Image.fromarray((out * 255).astype("uint8"), "RGB"), (0, 0))

	add_layer(layers[True], 0.8)
	smk = frames(tex["molly_smoke_2x2"], 2)
	for py, px, size, f in sorted(sprites):
		im = fl[f].resize((size, size), Image.LANCZOS)
		additive(mock, im, (int(px - size / 2), int(py - size * 0.95)), 0.6)
	add_layer(layers[False], 0.8)
	for k in range(5):
		im = smk[2].resize((260, 260), Image.LANCZOS)
		a = im.getchannel("A").point(lambda v: int(v * 0.35))
		g = Image.new("RGBA", im.size, (70, 70, 72, 255))
		g.putalpha(a)
		mock.alpha_composite(g, (cx - 520 + k * 220, cy - ry - 300 + (k % 2) * 30))
	sheet.alpha_composite(mock, (pad, y))
	y += mh + 20

	sheet = sheet.crop((0, 0, W, y + 6))
	PREVIEW.parent.mkdir(parents=True, exist_ok=True)
	sheet.convert("RGB").save(PREVIEW)
	print(f"[molly-vfx] preview {PREVIEW.relative_to(ROOT)}")


if bpy is not None:
	render_main()
elif "--preview" in sys.argv:
	preview_main()
else:
	print(__doc__)
