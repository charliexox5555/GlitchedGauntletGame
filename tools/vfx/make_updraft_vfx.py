"""Renders the Updraft screen-edge texture with Blender, and its preview.

Render (Blender, headless; well under a minute, `--fast` for a quick half-size check):

    "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup         --python tools/vfx/make_updraft_vfx.py -- [--fast]

Preview (plain Python + Pillow + numpy, run after rendering):

    python tools/vfx/make_updraft_vfx.py --preview

Look (vault/01 Design/Abilities/Updraft.md, "First person"): the rush of air as you shoot up. Thin wind streaks run
straight up the left and right sides of the screen and rise off the bottom edge, densest in the bottom corners and
thinning toward the top; the centre is exactly transparent. WHITE with straight alpha (RGBA PNG) so the game tints it
(a pale cool white). Output goes to art-source/vfx/abilities/updraft/.

  updraft_edge   1024x576   full-screen 16:9 overlay: vertical wind streaks (ridged noise stretched up) along the
                            sides and bottom over a faint soft haze; clear centre.

How: emission maths on a plane, rendered with Cycles on black; bloom_post turns brightness into alpha and adds a soft
glow. Fixed noise, so re-running gives the same image.
"""

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art-source" / "vfx" / "abilities" / "updraft"
PREVIEW = ROOT / "vault" / "02 Art" / "References" / "abilities" / "updraft" / "updraft_vfx_preview.png"

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




EDGE_A = 16 / 9


def edge(g, _i):
	"""Wind streaks rising along the sides and off the bottom edge; a faint haze under them; clear centre."""
	x, y = g.x, g.y
	ax = g.abs(x) / EDGE_A  # 0 centre .. 1 side edge
	wobble = sn(g.noise(x * 1.4, y * 0.9, 0.0, w=3.0, detail=2.0)) * 0.06
	# How close to the sides and the bottom (the top stays clear): smooth ramps, 1 at the edges.
	side = g.smooth(ax + wobble, 0.55, 1.0)
	bottom = g.smooth(y + wobble, -0.25, -1.0)
	mask = g.max(side, bottom) ** 1.6
	# Fade toward the top: the wind comes from below.
	rise = g.smooth(y, 1.0, -0.4) * 0.75 + 0.25
	# Streaks: ridged noise stretched hard along y (thin vertical lines), two scales.
	n1 = g.noise(x * 26.0, y * 1.2, 0.0, w=11.0, detail=2.0, rough=0.5)
	n2 = g.noise(x * 60.0, y * 2.4, 0.0, w=17.0, detail=1.0, rough=0.4)
	s1 = g.smooth(g.abs(n1 - 0.5), 0.05, 0.0)
	s2 = g.smooth(g.abs(n2 - 0.5), 0.035, 0.0) * 0.6
	# Break the streaks into lengths (gusts), not endless lines.
	gust = g.smooth(g.noise(x * 9.0, y * 0.7, 0.0, w=5.0, detail=1.0), 0.42, 0.62)
	streaks = (s1 + s2) * gust * 0.55
	haze = mask * mask * 0.08
	return g.emit((streaks * mask + haze) * rise)


SHEETS = {
	"updraft_edge": (1024, 576, 1, edge, [(2.5, 0.4), (10.0, 0.3)], 0.95),
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
	width, height, grid, shader, blooms, gain = SHEETS[name]
	aspect = width / height
	scene = setup_scene(width, height, 2 * grid * aspect, 48)
	bpy.ops.mesh.primitive_plane_add(size=2)
	plane = bpy.context.active_object
	plane.scale = (aspect, 1, 1)
	bpy.ops.object.transform_apply(scale=True)  # object coordinates in -aspect..aspect, -1..1
	plane.data.materials.append(shader(G(name), 0))
	raw = OUT / f"_{name}.exr"
	path = OUT / f"{name}.png"
	scene.render.filepath = str(raw)
	bpy.ops.render.render(write_still=True)
	bloom_post(raw, path, grid, blooms, gain)
	raw.unlink()
	print(f"[updraft-vfx] {path.relative_to(ROOT)}")
	return path


def render_main():
	OUT.mkdir(parents=True, exist_ok=True)
	for name in SHEETS:
		render_sheet(name)


# Preview (plain Python + Pillow) -----------------------------------------------

BG = (34, 36, 40)
PALE = (0xE6, 0xF4, 0xFF)


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

	def tint(img, color):
		a = np.asarray(img, np.float32)
		a[..., :3] *= np.array(color, np.float32) / 255.0
		return Image.fromarray(a.clip(0, 255).astype("uint8"), "RGBA")

	tex = Image.open(OUT / "updraft_edge.png").convert("RGBA")
	W, pad = 1328, 24
	sheet = Image.new("RGBA", (W, 2 * 720 + 140), (*BG, 255))
	draw = ImageDraw.Draw(sheet)
	draw.text((pad, 16), "updraft_edge.png 1024x576: pale white over a mid-grey screen, then a dark one (normal blend)", fill=(235, 235, 235), font=font(22))
	y = 60
	for top, bottom in ((150, 100), (70, 40)):
		scr = Image.new("RGBA", (1280, 720), (128, 128, 128, 255))
		sd = ImageDraw.Draw(scr)
		for k in range(720):
			c0 = int(top - (top - bottom) * k / 720)
			sd.line((0, k, 1280, k), fill=(c0, c0, c0 + 4, 255))
		sd.line((640 - 12, 360, 640 + 12, 360), fill=(255, 255, 255, 255), width=2)
		sd.line((640, 360 - 12, 640, 360 + 12), fill=(255, 255, 255, 255), width=2)
		scr.alpha_composite(tint(tex.resize((1280, 720), Image.LANCZOS), PALE))
		sheet.alpha_composite(scr, (pad, y))
		y += 720 + 30
	PREVIEW.parent.mkdir(parents=True, exist_ok=True)
	sheet.convert("RGB").save(PREVIEW)
	print(f"[updraft-vfx] preview {PREVIEW.relative_to(ROOT)}")


if bpy is not None:
	render_main()
elif "--preview" in sys.argv:
	preview_main()
else:
	print(__doc__)
