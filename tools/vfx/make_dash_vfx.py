"""Renders the Dash ability effect textures with Blender, and their preview sheet.

Render (Blender, headless):

    "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup \
        --python tools/vfx/make_dash_vfx.py -- [names...]

Preview contact sheet (plain Python + Pillow, run after rendering):

    python tools/vfx/make_dash_vfx.py --preview

Look (vault/01 Design/Abilities/Dash.md): a Jett-style (Valorant Tailwind) air
dash in a plain, classic-gun-game style: tapered wind wisps, a swirling gust
ring, a soft dust/air puff. No glitch or digital shapes. Everything is WHITE on
a transparent film (straight-alpha RGBA PNG); the game tints it per team
(ally #00E5FF, enemy #FF5A36). Output goes to art-source/vfx/abilities/dash/.

  dash_wind_trail       512x128  Trail texture. u = along the path, LEFT = newest
                                 (head), right = tail; v = across. Wisps run
                                 along u, fade at both v edges and toward the tail.
  dash_air_burst_2x2    1024x1024 2x2 flipbook (left-right, top-bottom): a ring
                                 of crescent wind strokes swirling outward and
                                 thinning over the 4 frames (dash start).
  dash_puff_2x2         1024x1024 2x2 flipbook: a soft air/dust puff, a Cycles
                                 volume (noise-eroded sphere) that billows and
                                 then thins away (dash end).
  dash_screen_streak    512x64   one thin speed streak: bright rounded head at the
                                 LEFT, long soft wavy tail fading right.

Emission textures are shader maths on object/UV coordinates (radial frames use
object x, y in -1..1 per frame; strip textures use UV). The puff is a lit
Principled Volume. Seeds are fixed, so re-running gives the same images.
"""

import math
import random
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art-source" / "vfx" / "abilities" / "dash"
PREVIEW = ROOT / "vault" / "02 Art" / "References" / "abilities" / "dash" / "dash_vfx_preview.png"

try:
	import bpy
except ImportError:  # Plain Python: preview mode only.
	bpy = None


# Node maths (same helpers as make_vfx_textures.py) ---------------------------


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

	# Clamp before POWER: a negative base gives 0 in Blender.
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

	def fmod(self, a, b):
		return self.math("FLOORED_MODULO", a, b)

	def length(self, a, b):
		return self.sqrt(a * a + b * b)

	def falloff(self, d, radius, power=1.0):
		"""1 at d=0, 0 at d>=radius, shaped by power."""
		f = self.clamp01(1.0 - d / radius)
		return f if power == 1.0 else f**power

	def soft(self, d, width):
		"""Gaussian-like bump: 1 at d=0, ~0 by d=2*width (smooth, no kink)."""
		q = d / width
		return self.math("EXPONENT", -(q * q))

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
		"""White (or grey) emission with straight `alpha` on a transparent film."""
		em = self.node("ShaderNodeEmission")
		if isinstance(color, S):
			self.link(color.sock, em.inputs["Color"])
		else:
			em.inputs["Color"].default_value = (color, color, color, 1.0)
		em.inputs["Strength"].default_value = 1.0
		tr = self.node("ShaderNodeBsdfTransparent")
		mix = self.node("ShaderNodeMixShader")
		self.put(mix.inputs[0], self.clamp01(alpha))
		self.link(tr.outputs[0], mix.inputs[1])
		self.link(em.outputs[0], mix.inputs[2])
		out = self.node("ShaderNodeOutputMaterial")
		self.link(mix.outputs[0], out.inputs["Surface"])
		return self.mat

	def volume(self, density):
		"""White scattering volume (the puff); lit by the scene lights."""
		pv = self.node("ShaderNodeVolumePrincipled")
		pv.inputs["Color"].default_value = (1.0, 1.0, 1.0, 1.0)
		pv.inputs["Anisotropy"].default_value = 0.2
		self.put(pv.inputs["Density"], density)
		out = self.node("ShaderNodeOutputMaterial")
		self.link(pv.outputs[0], out.inputs["Volume"])
		return self.mat


def polar(g):
	return g.length(g.x, g.y), g.atan2(g.y, g.x)


# Textures ---------------------------------------------------------------------


def wind_trail(g, _i):
	"""Trail strip: thin tapered wisps along u (left = head) over a faint wind sheet."""
	rng = random.Random(5101)
	u = g.u
	y = (g.v - 0.5) * 2.0  # -1..1 across the trail
	total = 0.0
	wisps = 7
	for k in range(wisps):
		lane = -0.5 + 1.0 * (k + rng.uniform(-0.35, 0.35)) / (wisps - 1)
		amp = rng.uniform(0.06, 0.15)
		freq = rng.uniform(0.8, 1.7) * math.tau
		phase = rng.uniform(0, math.tau)
		start = rng.uniform(0.0, 0.16)
		length = rng.uniform(0.6, 0.98)
		width = rng.uniform(0.03, 0.085)
		gain = rng.uniform(0.55, 1.0)
		t = (u - start) / length  # 0 at the wisp's head, 1 at its tail
		tc = g.clamp01(t)
		# The wisp drifts away from its lane toward the tail (air spreading out).
		drift = -lane * rng.uniform(0.1, 0.5) + rng.uniform(-0.12, 0.12)
		wob = (g.noise(u * 2.5, 0.0, 0.0, w=k * 3.3 + 1.0, detail=2) - 0.5) * 0.18
		yc = lane + g.sin(u * freq + phase) * amp * tc + tc * drift + wob * tc
		w = width * (0.45 + 0.55 * g.smooth(t, 0.0, 0.18)) * (1.0 - 0.6 * tc)
		env = g.smooth(t, -0.02, 0.1) * (g.clamp01(1.0 - t) ** 1.1)
		# Breaks along the wisp so it reads as moving air, not a solid line.
		breakup = g.smooth(g.noise(u * 4.0, 0.0, 0.0, w=k * 5.1 + 7.0, detail=3), 0.3, 0.62)
		d = g.abs(y - yc)
		core = g.soft(d, w)
		halo = g.soft(d, w * 3.2) * 0.22
		total = total + (core + halo) * env * gain * (0.35 + 0.65 * breakup)
	# Faint striated wind sheet behind the wisps (streaky: slow along u, fast across).
	sheet = g.noise(u * 1.6, y * 9.0, 0.0, w=21.0, detail=3, rough=0.55)
	sheet = g.smooth(sheet, 0.35, 0.75) * 0.22 * g.smooth(g.abs(y), 0.85, 0.1)
	sheet = sheet * (g.clamp01(1.0 - u) ** 1.6)
	total = total + sheet
	# A soft body of displaced air right behind the head.
	total = total + g.soft(y, 0.32) * (g.clamp01(1.0 - u * 1.6) ** 2) * 0.28
	edge = g.smooth(g.abs(y), 1.0, 0.72)
	tail = g.clamp01(1.0 - u) ** 0.6 * g.smooth(u, 1.0, 0.82)
	head = g.smooth(u, 0.0, 0.035)
	return g.output(total * edge * tail * head)


BURST_RADIUS = (0.34, 0.54, 0.7, 0.82)
BURST_FADE = (1.0, 0.85, 0.6, 0.34)
BURST_WIDTH = (0.06, 0.052, 0.042, 0.032)


def air_burst(g, i):
	"""Gust ring: crescent wind strokes swirling around an expanding circle."""
	rng = random.Random(5200)  # same strokes every frame, so the sheet animates
	radius, fade, width = BURST_RADIUS[i], BURST_FADE[i], BURST_WIDTH[i]
	swirl = i * 0.32  # strokes rotate as the ring grows
	r, a = polar(g)
	ca, sa = g.cos(a), g.sin(a)
	jitter = (g.noise(ca * 1.8, sa * 1.8, 0.0, w=i * 0.4 + 3.0, detail=2) - 0.5) * 0.06
	rr = r + jitter
	total = 0.0
	strokes = 7
	for k in range(strokes):
		a0 = k / strokes * math.tau + rng.uniform(-0.25, 0.25) + swirl
		span = rng.uniform(1.1, 1.8) * (1.0 - 0.15 * i / 3)
		spiral = rng.uniform(0.08, 0.16)
		off = rng.uniform(-0.05, 0.05)
		gain = rng.uniform(0.7, 1.0)
		wk = width * rng.uniform(0.75, 1.25)
		d = g.fmod(a - a0 + math.pi, math.tau) - math.pi
		p = (d + span / 2) / span  # 0 = tail, 1 = head of the crescent
		pc = g.clamp01(p)
		rc = radius + off + spiral * (pc - 0.5) * (1.0 + i * 0.4)
		# Thick rounded head, long thin tail.
		# Wind-slash profile: hair-thin tail, fullest near the front, pointed head.
		w = wk * (0.08 + (pc**1.2) * (g.clamp01(1.0 - pc) ** 0.35) / 0.437)
		w = g.max(w, 0.002)
		mask = g.smooth(p, -0.02, 0.18) * g.smooth(p, 1.02, 0.94)
		dist = g.abs(rr - rc)
		core = g.soft(dist, w)
		halo = g.soft(dist, w * 3.0) * 0.18
		total = total + (core + halo) * mask * gain
	# Soft air haze filling the ring, with radial streaks (gust shock).
	streaks = g.noise(ca * 9.0, sa * 9.0, r * 1.2, w=i * 0.3 + 11.0, detail=3)
	inside = g.smooth(rr, radius * 1.08, radius * 0.8) * g.smooth(rr, radius * 0.15, radius * 0.7)
	haze = inside * (0.45 + 0.55 * g.smooth(streaks, 0.3, 0.8)) * 0.22
	# Soft pressure flash in the first frames (the "pop" of the gust).
	flash = g.soft(r, radius * 0.8) * (0.35, 0.15, 0.0, 0.0)[i]
	edge = g.smooth(r, 0.99, 0.9)
	return g.output((total + haze + flash) * fade * edge)


def screen_streak(g, _i):
	"""One speed streak: rounded bright head at the left, soft wavy tail to the right."""
	u = g.u
	y = (g.v - 0.5) * 2.0
	wave = g.sin(u * (math.tau * 1.1) + 0.6) * 0.16 * u
	wob = (g.noise(u * 3.0, 0.0, 0.0, w=4.0, detail=2) - 0.5) * 0.18 * u
	yc = wave + wob
	width = 0.2 * (g.clamp01(1.0 - u) ** 0.8) + 0.035
	cap = g.smooth(u, 0.0, 0.045)  # rounded head
	along = cap * (g.clamp01(1.0 - u) ** 1.7)
	breakup = 0.65 + 0.35 * g.smooth(g.noise(u * 9.0, 0.0, 0.0, w=9.0, detail=2), 0.3, 0.7)
	d = g.abs(y - yc)
	core = g.soft(d, width * 0.55)
	halo = g.soft(d, width * 2.0) * 0.3
	tip = g.soft(g.length((u - 0.05) * 7.0, y), 0.22) * 0.6
	edge = g.smooth(g.abs(y), 1.0, 0.8) * g.smooth(u, 1.0, 0.9)
	return g.output((core * breakup + halo + tip) * along * edge)


PUFF_RADIUS = (0.47, 0.6, 0.7, 0.78)  # overall size per frame (frame half-width = 1)
PUFF_DENSITY = (7.0, 4.5, 2.6, 1.4)
PUFF_HOLES = (0.0, 0.0, 0.3, 0.42)  # wispy holes opening as it dissipates


def puff(g, i):
	"""Volume density for one puff frame: billows push out, then thin and break up.

	Signed distance to a union of balls (the same balls every frame, so the
	frames animate), scaled with the puff, then broken up by a large domain
	warp and soft billow noise so no ball outline survives.
	"""
	rng = random.Random(5300)
	size, dens, holes_at = PUFF_RADIUS[i], PUFF_DENSITY[i], PUFF_HOLES[i]
	seed = 31.0 + i * 0.25  # neighbouring frames share structure
	x0, y0, z0 = g.x, g.y, g.z * 1.3  # a little flatter toward the camera
	# Domain warp: swirl the space so the balls melt into one billowing cloud.
	warp = size * (0.32 + 0.08 * i)
	wx = g.noise(x0 * 2.6, y0 * 2.6, z0 * 2.6, w=seed + 50.0, detail=2) - 0.5
	wy = g.noise(x0 * 2.6, y0 * 2.6, z0 * 2.6, w=seed + 60.0, detail=2) - 0.5
	wz = g.noise(x0 * 2.6, y0 * 2.6, z0 * 2.6, w=seed + 70.0, detail=2) - 0.5
	x, y, z = x0 + wx * warp, y0 + wy * warp, z0 + wz * warp
	balls = [(0.0, 0.0, 0.0, 0.5)]
	for k in range(12):
		ang = k / 12 * math.tau + rng.uniform(-0.4, 0.4)
		dist = rng.uniform(0.25, 0.68)
		balls.append((math.cos(ang) * dist, math.sin(ang) * dist, rng.uniform(-0.3, 0.3), rng.uniform(0.2, 0.4)))
	sdf = 10.0
	for bx, by, bz, br in balls:
		d = g.sqrt((x - bx * size) * (x - bx * size) + (y - by * size) * (y - by * size) + (z - bz * size) * (z - bz * size))
		sdf = g.min(sdf, d - br * size)
	big = g.noise(x * 1.7, y * 1.7, z * 1.7, w=seed, detail=2, rough=0.5) - 0.5
	billow = g.noise(x * 4.0, y * 4.0, z * 4.0, w=seed + 7.0, detail=2, rough=0.5) - 0.5
	sdf = sdf + big * size * 0.45 + billow * size * (0.22 + 0.06 * i)
	soft = size * (0.18 + 0.06 * i)  # edges get softer as it dissipates
	density = g.smooth(sdf, soft * 0.4, -soft)
	if holes_at > 0:
		holes = g.noise(x * 2.4, y * 2.4, z * 2.4, w=seed + 13.0, detail=2, rough=0.5)
		density = density * g.smooth(holes, holes_at, holes_at + 0.22)
	keep = g.smooth(g.length(g.x, g.y), 0.98, 0.86)  # stays inside its frame
	return g.volume(density * keep * dens)


# Sheets -----------------------------------------------------------------------
# name: (width, height, grid, kind, builder)

SHEETS = {
	"dash_wind_trail": (512, 128, 1, "strip", wind_trail),
	"dash_air_burst_2x2": (1024, 1024, 2, "radial", air_burst),
	"dash_puff_2x2": (1024, 1024, 2, "volume", puff),
	"dash_screen_streak": (512, 64, 1, "strip", screen_streak),
}


def setup_scene(width, height, ortho, samples=48):
	bpy.ops.wm.read_factory_settings(use_empty=True)
	scene = bpy.context.scene
	scene.render.engine = "CYCLES"
	scene.cycles.device = "CPU"
	scene.cycles.samples = samples
	scene.cycles.seed = 7
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


def light_puff(scene):
	"""Soft key from the upper left plus a bright grey sky: light, mostly-white smoke."""
	scene.cycles.volume_bounces = 3
	scene.cycles.volume_step_rate = 0.5
	world = bpy.data.worlds.new("world")
	world.use_nodes = True
	bg = world.node_tree.nodes.get("Background") or world.node_tree.nodes.new("ShaderNodeBackground")
	bg.inputs["Color"].default_value = (1.0, 1.0, 1.0, 1.0)
	bg.inputs["Strength"].default_value = 0.6
	out = world.node_tree.nodes.get("World Output") or world.node_tree.nodes.new("ShaderNodeOutputWorld")
	world.node_tree.links.new(bg.outputs[0], out.inputs["Surface"])
	scene.world = world
	sun_data = bpy.data.lights.new("sun", "SUN")
	sun_data.energy = 3.2
	sun_data.angle = math.radians(25)
	sun = bpy.data.objects.new("sun", sun_data)
	sun.rotation_euler = (math.radians(40), math.radians(-35), math.radians(10))
	scene.collection.objects.link(sun)


def render_sheet(name):
	width, height, grid, kind, build = SHEETS[name]
	if kind == "strip":
		aspect = width / height
		scene = setup_scene(width, height, 2 * aspect)
		bpy.ops.mesh.primitive_plane_add(size=2)
		plane = bpy.context.active_object
		plane.scale = (aspect, 1, 1)
		plane.data.materials.append(build(G(name), 0))
	else:
		volume = kind == "volume"
		scene = setup_scene(width, height, 2 * grid, samples=96 if volume else 48)
		if volume:
			light_puff(scene)
		for i in range(grid * grid):
			col, row = i % grid, i // grid
			origin = ((col - (grid - 1) / 2) * 2, ((grid - 1) / 2 - row) * 2)
			if volume:
				bpy.ops.mesh.primitive_cube_add(size=2, location=(*origin, 0))
			else:
				bpy.ops.mesh.primitive_plane_add(size=2, location=(*origin, 0))
			obj = bpy.context.active_object
			obj.data.materials.append(build(G(f"{name}{i}"), i))
	path = OUT / f"{name}.png"
	scene.render.filepath = str(path)
	bpy.ops.render.render(write_still=True)
	print(f"[dash-vfx] {path.relative_to(ROOT)}")
	return path


def render_main():
	argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
	OUT.mkdir(parents=True, exist_ok=True)
	for name in argv or list(SHEETS):
		render_sheet(name)


# Preview (plain Python + Pillow) -----------------------------------------------

TINTS = (("Ally #00E5FF", (0x00, 0xE5, 0xFF)), ("Enemy #FF5A36", (0xFF, 0x5A, 0x36)))
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

	def tinted(img, rgb, gain=1.0):
		"""White texture -> team colour; alpha kept (like Color tint in Roblox)."""
		from PIL import ImageChops

		a = img.getchannel("A").point(lambda v: min(255, int(v * gain)))
		out = ImageChops.multiply(img.convert("RGB"), Image.new("RGB", img.size, rgb)).convert("RGBA")
		out.putalpha(a)
		return out

	def frames(img):
		w, h = img.size
		return [img.crop(((k % 2) * w // 2, (k // 2) * h // 2, (k % 2 + 1) * w // 2, (k // 2 + 1) * h // 2)) for k in range(4)]

	tex = {n: Image.open(OUT / f"{n}.png").convert("RGBA") for n in SHEETS}
	W = 1460
	pad = 24
	H = 2600
	sheet = Image.new("RGBA", (W, H), (*BG, 255))
	draw = ImageDraw.Draw(sheet)
	draw.text((pad, 16), "Dash VFX textures: ally / enemy tint on dark grey", fill=(235, 235, 235), font=f_title)
	y = 64

	def label(text, sub=None):
		nonlocal y
		draw.text((pad, y), text, fill=(230, 230, 230), font=f_head)
		if sub:
			draw.text((pad + draw.textlength(text, font=f_head) + 14, y + 4), sub, fill=(150, 150, 155), font=f_small)
		y += 30

	# 1. Trail + 2. streak side by side per tint.
	label("dash_wind_trail.png  512x128", "Trail, Stretch; left = head (newest), right = tail")
	for tname, rgb in TINTS:
		draw.text((pad, y + 54), tname, fill=rgb, font=f_small)
		sheet.alpha_composite(tinted(tex["dash_wind_trail"], rgb), (pad + 120, y))
		# Same texture stretched like a real 12-stud dash trail (long and thin).
		long = tex["dash_wind_trail"].resize((760, 70), Image.BICUBIC)
		sheet.alpha_composite(tinted(long, rgb), (pad + 120 + 512 + 30, y + 29))
		y += 140
	draw.text((pad + 120 + 512 + 30, y - 8), "stretched 760x70 (as a long trail)", fill=(150, 150, 155), font=f_small)
	y += 18

	label("dash_screen_streak.png  512x64", "one streak; right: mock screen-edge use below")
	for tname, rgb in TINTS:
		draw.text((pad, y + 22), tname, fill=rgb, font=f_small)
		sheet.alpha_composite(tinted(tex["dash_screen_streak"], rgb), (pad + 120, y))
		y += 76
	# Mock: streaks round the edges of a 16:9 screen, heads out, tails toward the centre.
	draw.text((pad, y), "mock screen-edge use: 14 copies, random scale/alpha, heads toward the edge", fill=(150, 150, 155), font=f_small)
	y += 22
	mw, mh = 560, 315
	streak = tex["dash_screen_streak"]
	for col, (_tname, rgb) in enumerate(TINTS):
		rngp = random.Random(9)
		mock = Image.new("RGBA", (mw, mh), (20, 22, 26, 255))
		for k in range(14):
			ang = k / 14 * math.tau + rngp.uniform(-0.18, 0.18)
			s = rngp.uniform(0.3, 0.5)
			img = streak.resize((int(512 * s), max(8, int(64 * s * 0.7))), Image.BICUBIC)
			img = tinted(img, rgb, rngp.uniform(0.55, 1.0))
			img = img.rotate(-math.degrees(ang + math.pi), expand=True, resample=Image.BICUBIC)
			reach = rngp.uniform(0.3, 0.38)
			cx = mw / 2 + math.cos(ang) * mw * reach
			cy = mh / 2 + math.sin(ang) * mh * reach * 1.2
			mock.alpha_composite(img, (int(cx - img.width / 2), int(cy - img.height / 2)))
		sheet.alpha_composite(mock, (pad + 120 + col * (mw + 20), y))
	y += mh + 30

	# 3. Flipbooks: four frames per tint.
	cell = 300
	for name, title, sub in (
		("dash_air_burst_2x2", "dash_air_burst_2x2.png  1024x1024", "frames 1-4 (dash start)"),
		("dash_puff_2x2", "dash_puff_2x2.png  1024x1024", "frames 1-4 (dash end)"),
	):
		label(title, sub)
		fr = frames(tex[name])
		for tname, rgb in TINTS:
			draw.text((pad, y + cell // 2 - 10), tname, fill=rgb, font=f_small)
			for k, img in enumerate(fr):
				x0 = pad + 120 + k * (cell + 14)
				draw.rectangle((x0, y, x0 + cell - 1, y + cell - 1), outline=(48, 50, 56))
				sheet.alpha_composite(tinted(img.resize((cell, cell), Image.LANCZOS), rgb), (x0, y))
				draw.text((x0 + 6, y + 4), f"{k + 1}", fill=(160, 160, 165), font=f_small)
			y += cell + 10
		y += 14
	sheet = sheet.crop((0, 0, W, y + 6))
	PREVIEW.parent.mkdir(parents=True, exist_ok=True)
	sheet.convert("RGB").save(PREVIEW)
	print(f"[dash-vfx] preview {PREVIEW.relative_to(ROOT)}")


if bpy is not None:
	render_main()
elif "--preview" in sys.argv:
	preview_main()
else:
	print(__doc__)
