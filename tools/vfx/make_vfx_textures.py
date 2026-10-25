"""Renders the weapon VFX texture set (Style B "Stylized Neon") with Blender.

    "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup \
        --python tools/vfx/make_vfx_textures.py -- [names...] [--preview <png>]

Every texture is an emission shader (or flat emission geometry) on a transparent
film, rendered with Cycles and saved as a straight-alpha PNG in art-source/vfx/.
Most are white so the game tints them (ParticleEmitter.Color, Beam.Color,
ImageColor3); the bullet hole is baked dark. Sheets marked grid=2 are 2x2
flipbooks (frames left-to-right, top-to-bottom) for FlipbookLayout.Grid2x2.

Shapes are built from shader math on object/UV coordinates (radial textures use
object space x, y in -1..1 per frame; beam textures use UV, u along the beam).
"""

import math
import random
import sys
from pathlib import Path

import bpy

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art-source" / "vfx"


# Node maths -------------------------------------------------------------------


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

	# Helpers. Clamp before POWER: a negative base gives 0 in Blender.
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

	def falloff(self, d, radius, power=1.0):
		"""1 at d=0, 0 at d>=radius, shaped by power."""
		f = self.clamp01(1.0 - d / radius)
		return f if power == 1.0 else f**power

	def smooth(self, value, lo, hi):
		"""Smoothstep from lo (0) to hi (1); lo > hi inverts it."""
		n = self.node("ShaderNodeMapRange")
		n.interpolation_type = "SMOOTHSTEP"
		n.clamp = True
		self.put(n.inputs["Value"], value)
		flip = lo > hi
		n.inputs["From Min"].default_value = min(lo, hi)
		n.inputs["From Max"].default_value = max(lo, hi)
		n.inputs["To Min"].default_value = 1.0 if flip else 0.0
		n.inputs["To Max"].default_value = 0.0 if flip else 1.0
		return S(self, n.outputs[0])

	def noise(self, x, y, z=0.0, w=0.0, scale=1.0, detail=2.0, rough=0.5):
		"""4D Perlin noise, about 0..1 around 0.5."""
		c = self.node("ShaderNodeCombineXYZ")
		self.put(c.inputs[0], x)
		self.put(c.inputs[1], y)
		self.put(c.inputs[2], z)
		n = self.node("ShaderNodeTexNoise")
		n.noise_dimensions = "4D"
		self.link(c.outputs[0], n.inputs["Vector"])
		self.put(n.inputs["W"], w)
		n.inputs["Scale"].default_value = scale
		n.inputs["Detail"].default_value = detail
		n.inputs["Roughness"].default_value = rough
		return S(self, n.outputs["Fac"])

	def output(self, alpha, color=1.0):
		"""Emission `color` (grey value, socket or RGB tuple) with straight `alpha`."""
		em = self.node("ShaderNodeEmission")
		if isinstance(color, S):
			self.link(color.sock, em.inputs["Color"])
		else:
			rgb = color if isinstance(color, tuple) else (color, color, color)
			em.inputs["Color"].default_value = (*rgb, 1.0)
		em.inputs["Strength"].default_value = 1.0
		tr = self.node("ShaderNodeBsdfTransparent")
		mix = self.node("ShaderNodeMixShader")
		self.put(mix.inputs[0], self.clamp01(alpha))
		self.link(tr.outputs[0], mix.inputs[1])
		self.link(em.outputs[0], mix.inputs[2])
		out = self.node("ShaderNodeOutputMaterial")
		self.link(mix.outputs[0], out.inputs["Surface"])
		return self.mat


def polar(g):
	r = g.length(g.x, g.y)
	a = g.atan2(g.y, g.x)
	return r, a


# Texture shaders (one frame each) --------------------------------------------


def muzzle_front(g, i):
	"""Star burst seen down the barrel: broad petals, thin spikes, hot core."""
	rng = random.Random(100 + i)
	petals = [5, 6, 4, 5][i]
	rot = rng.uniform(0, math.tau)
	rot2 = rng.uniform(0, math.tau)
	r, a = polar(g)
	ca, sa = g.cos(a), g.sin(a)
	vary = g.noise(ca * 1.4, sa * 1.4, 0.0, w=i * 3.7)
	broad = g.abs(g.cos((a - rot) * (petals / 2))) ** 2.6
	spikes = g.abs(g.cos((a - rot2) * (petals + 2) / 2)) ** 30
	length = g.max(0.24 + broad * (0.34 + vary * 0.4), 0.3 + spikes * (0.4 + vary * 0.3))
	length = g.min(length, 0.96)
	body = g.falloff(r / length, 1.0, 0.85)
	grain = g.noise(g.x * 5, g.y * 5, 0.0, w=i * 1.9 + 10, detail=4, rough=0.6)
	streaks = g.noise(ca * 7, sa * 7, r * 2.5, w=i * 2.3, detail=3)
	texture = g.clamp01(0.78 + (grain - 0.5) * 0.6 + (streaks - 0.5) * 0.5)
	core = g.falloff(r, 0.4, 1.3)
	return g.output(body * texture + core)


def muzzle_side(g, i):
	"""Flame from the side: base at the bottom edge, tip at the top, two side jets."""
	rng = random.Random(200 + i)
	t = g.clamp01((g.y + 0.92) / 1.86)
	wide = rng.uniform(0.9, 1.1)
	width = (t**0.4) * (g.clamp01(1.0 - t) ** 1.2) * (1.25 * wide)
	jag = g.noise(g.x * 2.5, g.y * 4.5, 0.0, w=i * 4.1, detail=3)
	width = g.max(width * (0.8 + jag * 0.4), 0.001)
	edge = g.abs(g.x) / width
	body = g.falloff(edge, 1.0, 0.9) * (1.0 - t * t * 0.35)
	grain = g.noise(g.x * 7, g.y * 3, 0.0, w=i * 2.7 + 5, detail=4, rough=0.6)
	body = body * g.clamp01(0.8 + (grain - 0.5) * 0.6)
	inner = g.falloff(edge, 0.4, 1.2) * g.clamp01(1.0 - t * 1.3)
	jets = 0.0
	for side in (-1, 1):
		ang = math.radians(rng.uniform(42, 58)) * side
		jl = rng.uniform(0.38, 0.55)
		px, py = g.x, g.y + 0.62
		ux = px * math.cos(ang) - py * math.sin(ang)
		uy = px * math.sin(ang) + py * math.cos(ang)
		along = uy / jl
		inside = g.clamp01(along * 25) * g.clamp01((1.0 - along) * 25)
		jw = g.max((g.clamp01(along) ** 0.35) * g.clamp01(1.0 - along) * 0.2, 0.001)
		jets = jets + g.falloff(g.abs(ux) / jw, 1.0, 1.1) * inside * 0.9
	core = g.falloff(g.length(g.x, g.y + 0.62), 0.42, 1.4)
	return g.output(body + inner + jets + core)


def smoke(g, i):
	"""Soft puff, wispy edges. Light grey; the game tints and fades it."""
	n = g.noise(g.x * 1.5, g.y * 1.5, 0.0, w=i * 5.3, detail=4, rough=0.55)
	r = g.length(g.x, g.y) + (n - 0.5) * 0.75
	density = g.smooth(r, 0.95, 0.1)
	wisp = g.noise(g.x * 3.5, g.y * 3.5, 0.0, w=i * 3.1 + 20, detail=6, rough=0.6)
	density = density * g.clamp01(0.5 + (wisp - 0.4) * 1.6)
	shade = 0.62 + wisp * 0.4
	return g.output(density * 0.85, shade)


def dust(g, i):
	"""Grainy dust burst (tinted by the surface colour in game)."""
	n = g.noise(g.x * 2.2, g.y * 2.2, 0.0, w=i * 4.7 + 40, detail=6, rough=0.7)
	r = g.length(g.x, g.y) + (n - 0.5) * 0.9
	density = g.smooth(r, 0.92, 0.05)
	grain = g.noise(g.x * 22, g.y * 22, 0.0, w=i * 1.3, detail=1)
	density = density * g.smooth(grain, 0.38, 0.62)
	clump = g.noise(g.x * 4, g.y * 4, 0.0, w=i * 2.2 + 70, detail=3)
	return g.output(density * g.clamp01(0.4 + clump * 0.9), 0.8 + clump * 0.2)


def spark(g, _i):
	"""Bright streak pointing up (VelocityParallel: up = direction of travel)."""
	t = g.clamp01((g.y + 1.0) / 2.0)
	along = (t**1.6) * g.clamp01((1.0 - t) / 0.07)
	core = g.falloff(g.abs(g.x), 0.04, 1.5) * along
	halo = g.falloff(g.abs(g.x), 0.2, 3.0) * along * 0.55
	head = g.falloff(g.length(g.x, g.y - 0.86), 0.12, 2.0) * 0.6
	return g.output(core + halo + head)


def impact_flash(g, _i):
	"""Hit flare: hot core, four long rays, four short ones."""
	r, a = polar(g)
	core = g.falloff(r, 0.42, 2.0)
	long_rays = (g.abs(g.cos(a * 2)) ** 70) * g.falloff(r, 0.97, 1.3)
	short_rays = (g.abs(g.sin(a * 2)) ** 90) * g.falloff(r, 0.55, 1.5) * 0.7
	glow = g.falloff(r, 1.0, 3.0) * 0.5
	return g.output(core + long_rays + short_rays + glow)


def glow(g, _i):
	r, _a = polar(g)
	return g.output(g.falloff(r, 1.0, 2.6) + g.falloff(r, 0.22, 2.0) * 0.3)


def ring(g, _i):
	r, _a = polar(g)
	d = g.abs(r - 0.78)
	return g.output(g.falloff(d, 0.06, 1.6) + g.falloff(d, 0.24, 3.0) * 0.35)


def _hole_shape(g):
	r, a = polar(g)
	ca, sa = g.cos(a), g.sin(a)
	jag = g.noise(ca * 2.2, sa * 2.2, 0.0, w=7.7, detail=3)
	radius = 0.19 + (jag - 0.5) * 0.12
	cracks = g.abs(g.cos((a - 0.4) * 2.5)) ** 240 + g.abs(g.cos((a + 0.9) * 1.5)) ** 300
	return r, a, radius, cracks


def hole(g, _i):
	"""Bullet hole: dark centre, soot, a few cracks (baked dark, not tinted)."""
	r, _a, radius, cracks = _hole_shape(g)
	core = g.clamp01((radius - r) / 0.025)
	n = g.noise(g.x * 3, g.y * 3, 0.0, w=3.3, detail=5, rough=0.6)
	soot = g.falloff(r + (n - 0.5) * 0.35, 0.85, 1.7) * 0.82
	crack = cracks * g.falloff(r, 0.62, 1.0) * 0.8
	alpha = g.max(g.max(core, soot), crack)
	shade = 0.012 + g.clamp01(1.0 - core) * 0.03
	return g.output(alpha, shade)


def hole_rim(g, _i):
	"""Glowing rim + cracks matching `hole` (white; tinted to the gun's colour)."""
	r, _a, radius, cracks = _hole_shape(g)
	d = g.abs(r - (radius + 0.025))
	rim = g.falloff(d, 0.045, 1.4)
	halo = g.falloff(d, 0.22, 3.0) * 0.4
	crack = cracks * g.clamp01((r - radius) / 0.04) * g.falloff(r - radius, 0.36, 1.2) * 0.9
	return g.output(rim + halo + crack)


def tracer(g, _i):
	"""Beam streak: u = tail (0) -> head (1), v across. Rounded bright head."""
	y = (g.v - 0.5) * 2.0
	along = (g.u**2.4) * g.smooth(g.u, 1.0, 0.95)
	core = g.falloff(g.abs(y), 0.22, 1.5)
	halo = g.falloff(g.abs(y), 1.0, 2.5) * 0.45
	return g.output((core + halo) * along)


def beam_energy(g, _i):
	"""Electric filaments around a core; tiles along u (for TextureSpeed)."""
	y = (g.v - 0.5) * 2.0
	theta = g.u * math.tau
	ct, st = g.cos(theta), g.sin(theta)
	total = g.falloff(g.abs(y), 0.2, 1.6) * 0.95 + g.falloff(g.abs(y), 1.0, 1.6) * 0.45
	for k, (freq, thick, gain) in enumerate(((3.0, 0.13, 1.0), (5.0, 0.1, 0.85), (2.0, 0.15, 0.7))):
		offset = (g.noise(ct * freq, st * freq, 0.0, w=k * 9.1 + 1, detail=3, rough=0.55) - 0.5) * 2.0
		bright = g.noise(ct * 4, st * 4, 1.0, w=k * 4.4 + 3)
		total = total + g.falloff(g.abs(y - offset), thick, 1.5) * gain * g.clamp01(0.3 + bright)
	return g.output(total)


def beam_helix(g, _i):
	"""Two strands twisting round a core (Ray Trace rail); tiles along u."""
	y = (g.v - 0.5) * 2.0
	phase = g.u * (math.tau * 2)
	s = g.sin(phase) * 0.58
	c = g.cos(phase)
	front = g.falloff(g.abs(y - s), 0.16, 1.2) * (0.6 + c * 0.4)
	back = g.falloff(g.abs(y + s), 0.16, 1.2) * (0.6 - c * 0.4)
	core = g.falloff(g.abs(y), 0.2, 1.6)
	halo = g.falloff(g.abs(y), 1.0, 1.6) * 0.42
	return g.output(front + back + core + halo)


def vignette(g, _i):
	"""Screen-edge glow (rounded square), for the kill flash."""
	e = (g.x**4 + g.y**4) ** 0.25
	return g.output(g.smooth(e, 0.5, 1.0) ** 1.4)


def disc(g, _i):
	"""Loopback disc face: outer and inner rings, six segments, hot hub."""
	r, a = polar(g)
	outer = g.falloff(g.abs(r - 0.83), 0.06, 1.3)
	inner = g.falloff(g.abs(r - 0.42), 0.035, 1.3) * 0.9
	band = g.clamp01((0.085 - g.abs(r - 0.62)) / 0.015)
	segs = band * g.clamp01((g.abs(g.cos(a * 3)) - 0.42) / 0.05) * 0.8
	hub = g.falloff(r, 0.2, 1.2)
	halo = g.falloff(r, 1.0, 1.5) * 0.22
	return g.output(outer + inner + segs + hub + halo)


# Geometry textures ------------------------------------------------------------


def flat_material(name, grey):
	g = G(name)
	return g.output(1.0, grey)


def add_poly(points, z, material, origin):
	ox, oy = origin
	mesh = bpy.data.meshes.new("poly")
	verts = [(ox + x, oy + y, z) for x, y in points]
	mesh.from_pydata(verts, [], [list(range(len(verts)))])
	obj = bpy.data.objects.new("poly", mesh)
	obj.data.materials.append(material)
	bpy.context.scene.collection.objects.link(obj)
	return obj


def debris_frame(i, origin):
	"""One angular chip per frame: a lit face and a darker side."""
	rng = random.Random(300 + i)
	count = rng.randint(5, 7)
	pts = []
	for k in range(count):
		ang = k / count * math.tau + rng.uniform(-0.3, 0.3)
		rad = rng.uniform(0.45, 0.85)
		pts.append((math.cos(ang) * rad, math.sin(ang) * rad * rng.uniform(0.6, 1.0)))
	dark = flat_material("chip_dark", 0.42)
	light = flat_material("chip_light", 0.95)
	add_poly(pts, 0.0, dark, origin)
	# Lit face: the same outline shrunk toward a corner.
	cx, cy = rng.uniform(-0.12, 0.12), rng.uniform(0.0, 0.15)
	face = [(cx + (x - cx) * 0.72, cy + (y - cy) * 0.72) for x, y in pts]
	add_poly(face, 0.01, light, origin)


def pixel_frame(i, origin):
	"""Glitch pixels: solid square, hollow square, plus, checker."""
	white = flat_material("px", 1.0)
	ox, oy = origin

	def square(cx, cy, h, z=0.02):
		add_poly([(cx - h, cy - h), (cx + h, cy - h), (cx + h, cy + h), (cx - h, cy + h)], z, white, origin)

	if i == 0:
		square(0, 0, 0.62)
	elif i == 1:
		for cx, cy, w, h in ((0, 0.52, 0.64, 0.12), (0, -0.52, 0.64, 0.12), (0.52, 0, 0.12, 0.4), (-0.52, 0, 0.12, 0.4)):
			add_poly([(cx - w, cy - h), (cx + w, cy - h), (cx + w, cy + h), (cx - w, cy + h)], 0.02, white, origin)
	elif i == 2:
		for cx, cy in ((0, 0), (0.42, 0), (-0.42, 0), (0, 0.42), (0, -0.42)):
			square(cx, cy, 0.2)
	else:
		for cx, cy in ((-0.31, 0.31), (0.31, -0.31)):
			square(cx, cy, 0.3)
		square(0.31, 0.31, 0.12)
	# Faint glow behind the pixel.
	g = G("px_glow")
	r = g.length(g.x, g.y)
	halo = g.output(g.falloff(r, 1.0, 2.5) * 0.35)
	bpy.ops.mesh.primitive_plane_add(size=2, location=(ox, oy, -0.01))
	bpy.context.active_object.data.materials.append(halo)


# Sheet list -------------------------------------------------------------------
# name: (width, height, grid, kind, builder). kind "radial" frames are 2x2-unit
# planes in object space; "beam" is one UV plane at the image's aspect.

SHEETS = {
	"muzzle_front": (512, 512, 2, "radial", muzzle_front),
	"muzzle_side": (512, 512, 2, "radial", muzzle_side),
	"smoke": (512, 512, 2, "radial", smoke),
	"dust": (512, 512, 2, "radial", dust),
	"debris": (256, 256, 2, "geometry", debris_frame),
	"pixel": (256, 256, 2, "geometry", pixel_frame),
	"spark": (128, 256, 1, "radial", spark),
	"impact_flash": (256, 256, 1, "radial", impact_flash),
	"glow": (256, 256, 1, "radial", glow),
	"ring": (256, 256, 1, "radial", ring),
	"hole": (256, 256, 1, "radial", hole),
	"hole_rim": (256, 256, 1, "radial", hole_rim),
	"tracer": (512, 64, 1, "beam", tracer),
	"beam_energy": (512, 128, 1, "beam", beam_energy),
	"beam_helix": (512, 128, 1, "beam", beam_helix),
	"vignette": (256, 256, 1, "radial", vignette),
	"disc": (256, 256, 1, "radial", disc),
}


def setup_scene(width, height, ortho):
	bpy.ops.wm.read_factory_settings(use_empty=True)
	scene = bpy.context.scene
	scene.render.engine = "CYCLES"
	scene.cycles.device = "CPU"
	scene.cycles.samples = 48
	scene.cycles.use_denoising = False
	scene.cycles.transparent_max_bounces = 16
	scene.render.film_transparent = True
	scene.render.resolution_x = width
	scene.render.resolution_y = height
	scene.render.resolution_percentage = 100
	scene.view_settings.view_transform = "Standard"
	scene.view_settings.look = "None"
	scene.render.image_settings.file_format = "PNG"
	scene.render.image_settings.color_mode = "RGBA"
	scene.render.image_settings.color_depth = "8"
	cam_data = bpy.data.cameras.new("cam")
	cam_data.type = "ORTHO"
	cam_data.ortho_scale = ortho
	cam = bpy.data.objects.new("cam", cam_data)
	cam.location = (0, 0, 10)
	scene.collection.objects.link(cam)
	scene.camera = cam
	return scene


def render_sheet(name):
	width, height, grid, kind, build = SHEETS[name]
	if kind == "beam":
		aspect = width / height
		scene = setup_scene(width, height, 2 * aspect)
		bpy.ops.mesh.primitive_plane_add(size=2)
		plane = bpy.context.active_object
		plane.scale = (aspect, 1, 1)
		plane.data.materials.append(build(G(name), 0))
	else:
		# Frames are 2x2 units; a non-square single frame is scaled to the image.
		sx = width / max(width, height)
		sy = height / max(width, height)
		scene = setup_scene(width, height, 2 * grid)
		for i in range(grid * grid):
			col, row = i % grid, i // grid
			origin = ((col - (grid - 1) / 2) * 2, ((grid - 1) / 2 - row) * 2)
			if kind == "geometry":
				build(i, origin)
			else:
				bpy.ops.mesh.primitive_plane_add(size=2, location=(*origin, 0))
				plane = bpy.context.active_object
				plane.data.materials.append(build(G(f"{name}{i}"), i))
		if sx != 1 or sy != 1:
			# Squeeze the 2x2 frame into a tall/wide image: keep object space
			# -1..1 on both axes by scaling the plane, and the camera covers it.
			for obj in scene.objects:
				if obj.type == "MESH":
					obj.scale = (sx, sy, 1)
			scene.camera.data.ortho_scale = 2 * grid * max(sx, sy)
	path = OUT / f"{name}.png"
	scene.render.filepath = str(path)
	bpy.ops.render.render(write_still=True)
	print(f"[vfx] {path.relative_to(ROOT)}")
	return path


def preview(paths, out):
	"""Contact sheet: each texture tinted cyan over the slate background."""
	import numpy as np

	cell = 256
	cols = 6
	rows = math.ceil(len(paths) / cols)
	canvas = np.zeros((rows * cell, cols * cell, 4), dtype=np.float32)
	canvas[..., 0:3] = (0.07, 0.08, 0.12)
	canvas[..., 3] = 1
	tint = np.array([0.55, 1.0, 1.0])
	for k, p in enumerate(paths):
		img = bpy.data.images.load(str(p))
		w, h = img.size
		px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
		# Nearest-neighbour fit into the cell.
		scale = cell / max(w, h)
		nw, nh = max(1, int(w * scale)), max(1, int(h * scale))
		ys = (np.arange(nh) / scale).astype(int).clip(0, h - 1)
		xs = (np.arange(nw) / scale).astype(int).clip(0, w - 1)
		px = px[ys][:, xs]
		row, col = rows - 1 - k // cols, k % cols
		y0 = row * cell + (cell - nh) // 2
		x0 = col * cell + (cell - nw) // 2
		region = canvas[y0 : y0 + nh, x0 : x0 + nw]
		alpha = px[..., 3:4]
		color = px[..., 0:3] if p.stem == "hole" else px[..., 0:3] * tint
		region[..., 0:3] = color * alpha + region[..., 0:3] * (1 - alpha)
	img = bpy.data.images.new("preview", cols * cell, rows * cell, alpha=True)
	img.pixels = canvas.ravel()
	img.filepath_raw = str(out)
	img.file_format = "PNG"
	img.save()
	print(f"[vfx] preview {out}")


def main():
	argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
	preview_out = None
	if "--preview" in argv:
		k = argv.index("--preview")
		preview_out = argv[k + 1]
		argv = argv[:k] + argv[k + 2 :]
	names = argv or list(SHEETS)
	OUT.mkdir(parents=True, exist_ok=True)
	for name in names:
		render_sheet(name)
	if preview_out:
		preview([OUT / f"{n}.png" for n in SHEETS if (OUT / f"{n}.png").exists()], preview_out)


main()
