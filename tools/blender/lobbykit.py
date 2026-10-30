# lobbykit.py: shared library for the Lobby kit (vault/02 Art/Lobby Kit.md): materials, mesh helpers, trims and the
# preview stage. Build scripts (build_lobby_styleboard.py, build_lobby_preview.py, the step 4 kit builds) import it.
#
# AXES AND UNITS (same family as gunkit / modkit):
#   1 Blender unit = 1 stud, +Z up.
#   KIT PIECES (local space): +X forward (into the room), +Y left, origin on the floor.
#     straight pieces: origin at the centre of the back face, the piece faces +X, its width runs along Y
#     round pieces:    origin at the circle's centre on the floor, the segment starts at bearing 0
#     props:           origin on the floor at the centre
#   PLAN / WORLD SPACE (Lobby Art Plan: Roblox +X east, -Z north, Y up, bearings clockwise from north):
#     Blender X = Roblox X (east), Blender Y = Roblox -Z (north), Blender Z = Roblox Y (up).
#     plan_to_blender(x, y, z) = (x, -z, y); blender_to_plan(x, y, z) = (x, z, -y). This is exactly Roblox's own
#     mesh import mapping (Blender +Y comes in as Roblox -Z), so world-placed previews and exported meshes agree.
#     A bearing b (degrees, 0 = north, clockwise seen from above) points along (sin b, cos b, 0) in Blender.
#     Round kit radii are in plan studs (R44, R68, R42, R16); segments are 11.25 degrees (32 per circle).
#
# MATERIALS: make_materials() builds every material of the Lobby Kit style sheet as a Principled BSDF preview of
#   the final Roblox look. Each carries rbx_material (base material), rbx_variant (MaterialVariant name, "" if none)
#   and rbx_color (hex), plus rbx_transparency where needed. Surface patterns are driven by the "UVMap" layer, which
#   the helpers write in studs (stud_uvs: box projection from world positions, so grids continue across pieces;
#   arc_uvs for curved segments), so the formwork grid, saw cuts and grain tile at real stud scale like a
#   MaterialVariant with StudsPerTile would. Rock uses 3D object-space noise (no seams on faceted chunks).
#   Neon / emissive parts are separate objects named <Part>_Glow (add_glow), so the game can recolour pad rings.
#
# STAGE: begin() opens an empty file; lobby_world(kind) sets the world, sun and the per-zone light preset;
#   camera(), bloom() (modkit's approach) and render() finish a preview. Run build scripts headless only:
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup --python <script> -- [args]

import bpy, bmesh, math, os, random, sys
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
	sys.path.insert(0, HERE)
from gunkit import prism, box, ring_pts, merge, group, bevel  # noqa: E402,F401

ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
ART_DIR = os.path.join(ROOT, "art-source", "lobby")
RENDER_DIR = os.path.join(ROOT, "vault", "02 Art", "References", "lobby", "kit")
FONT_HEAVY = "C:/Windows/Fonts/seguibl.ttf"  # Segoe UI Black: stands in for the signs' GothamBlack
FONT_LABEL = "C:/Windows/Fonts/segoeuib.ttf"

SEG = 11.25  # round kit segment, degrees


# ---------------------------------------------------------------- axes

def plan_to_blender(x, y, z):
	return (x, -z, y)


def blender_to_plan(x, y, z):
	return (x, z, -y)


def bearing_dir(b):
	r = math.radians(b)
	return Vector((math.sin(r), math.cos(r), 0.0))


def polar(r, b, z=0.0):
	# Point at radius r and bearing b (degrees) in Blender space.
	d = bearing_dir(b)
	return Vector((d.x * r, d.y * r, z))


def lin(color):
	c = [((color >> 16) & 255) / 255, ((color >> 8) & 255) / 255, (color & 255) / 255]
	return tuple(v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in c)


# ---------------------------------------------------------------- palette (Lobby Kit style sheet)

C_BOARD = 0x8E8C87
C_BOARD_SHADE = 0x6B6965  # same variant, darker Color (coffer insides)
C_POLISHED = 0xB9B4AA
C_INLAY = 0xF2EADB
C_DARK = 0x3A3B3D
C_TERRAZZO = 0xD6C8B0
C_HONED = 0x7E7C78  # Lobby_ConcreteDark variant with a lighter Color: plinths (a continuous honed band, saw cuts)
C_ROCK = 0x625D57  # lifted from #55524E (art review: the hub rock crushed to black under the planned ambient)
C_ROCK_DUELS = 0x2E2F33
C_STEEL_BLACK = 0x1C1D20
C_STEEL_BRUSHED = 0xA7ABB0
C_OAK = 0x94683F  # was #A0703F (read as orange laminate)
C_BRASS = 0xB08D55  # was #B8873F (read as copper): warm satin brass
C_GLASS = 0xA9C9CF
C_SIGN = 0x2A2C30
C_SCREEN = 0x0B0D10
C_TEXT = 0xF4F4F2

# Neon: name -> (colour, emission strength). Strength previews Roblox Neon under bloom. Neon in Roblox GLOWS but
# LIGHTS NOTHING, so _emissive only emits to camera rays (strips bloom, walls stay unlit); every wash a design needs
# is an explicit rbx_light(). Strengths were cut after the art review: at 5-6 every warm line rendered clinical white,
# red bloomed pink and 2v2 blue clipped to cyan. The cove colour is warmer than the 3000K target because Neon pushes
# toward white.
GLOWS = {
	"Glow_Cove": (0xFFDDB0, 2.2),  # warm cove, ring and rock gaps (reads ~3000K after Neon's push to white)
	"Glow_Cool": (0xDDE8F2, 2.5),  # cool daylight strips, Range (6000K)
	"Glow_Neutral": (0xF2EEE4, 2.5),  # neutral museum light, Weapons coves and turntable under-rings (4500K)
	"Glow_DuelsRed": (0xB3262E, 2.5),  # Duels edge strips and tally lamps (stays deep red, no pink bloom)
	"Glow_1v1": (0x3DDC84, 3.0),
	"Glow_2v2": (0x3B8CFF, 3.0),
	"Glow_3v3": (0x9B5CFF, 3.0),
	"Glow_4v4": (0xFF7A1A, 2.8),
	"Glow_Gauntlet": (0xFFC83D, 2.8),
	"Glow_Dormant": (0x6A6E76, 1.2),  # unpowered pads: a dim grey ring, never off
}

# Light colours per zone (Lobby Art Plan, "Light per zone").
L_SUN = 0xFFE2B8
L_COVE = 0xFFF1DC
L_DUELS = 0xB8D4FF
L_MARKET = 0xFFD9A8
L_WEAPONS = 0xF2F0EA
L_RANGE = 0xDDE8F2
AMBIENT = 0x1E222A
OUTDOOR_AMBIENT = 0x3A3F48


# ---------------------------------------------------------------- node graph helper

class Graph:
	# Tiny wrapper so material graphs read like formulas. Values are sockets or plain numbers/tuples.
	def __init__(self, mat):
		self.nt = mat.node_tree
		self.L = self.nt.links
		self._uv = None
		self._obj = None

	def node(self, kind, **props):
		n = self.nt.nodes.new(kind)
		for k, v in props.items():
			setattr(n, k, v)
		return n

	def set(self, sock, v):
		if v is None:
			return
		if isinstance(v, bpy.types.NodeSocket):
			self.L.new(v, sock)
		else:
			sock.default_value = v

	def math(self, op, a, b=None, c=None, clamp=False):
		n = self.node("ShaderNodeMath", operation=op, use_clamp=clamp)
		for i, v in enumerate((a, b, c)):
			self.set(n.inputs[i], v)
		return n.outputs[0]

	def add(self, a, b):
		return self.math("ADD", a, b)

	def sub(self, a, b):
		return self.math("SUBTRACT", a, b)

	def mul(self, a, b):
		return self.math("MULTIPLY", a, b)

	def div(self, a, b):
		return self.math("DIVIDE", a, b)

	def mn(self, a, b):
		return self.math("MINIMUM", a, b)

	def mx(self, a, b):
		return self.math("MAXIMUM", a, b)

	def fract(self, a):
		return self.math("FRACT", a)

	def floor(self, a):
		return self.math("FLOOR", a)

	def absv(self, a):
		return self.math("ABSOLUTE", a)

	def remap(self, x, a, b, c=0.0, d=1.0, smooth=False):
		n = self.node("ShaderNodeMapRange", interpolation_type="SMOOTHSTEP" if smooth else "LINEAR", clamp=True)
		for i, v in enumerate((x, a, b, c, d)):
			self.set(n.inputs[i], v)
		return n.outputs[0]

	def smooth(self, e0, e1, x):
		return self.remap(x, e0, e1, 0.0, 1.0, smooth=True)

	def inv(self, a):
		return self.sub(1.0, a)

	def xyz(self, a, b, c=0.0):
		n = self.node("ShaderNodeCombineXYZ")
		for i, v in enumerate((a, b, c)):
			self.set(n.inputs[i], v)
		return n.outputs[0]

	def sep(self, v):
		n = self.node("ShaderNodeSeparateXYZ")
		self.set(n.inputs[0], v)
		return n.outputs[0], n.outputs[1], n.outputs[2]

	def length(self, v):
		n = self.node("ShaderNodeVectorMath", operation="LENGTH")
		self.set(n.inputs[0], v)
		return n.outputs["Value"]

	def uv(self):
		# (u, v) in studs from the UVMap layer.
		if self._uv is None:
			tc = self.node("ShaderNodeTexCoord")
			self._uv = self.sep(tc.outputs["UV"])[:2]
		return self._uv

	def obj(self):
		if self._obj is None:
			tc = self.node("ShaderNodeTexCoord")
			self._obj = tc.outputs["Object"]
		return self._obj

	def noise(self, vec, scale, detail=2.0, rough=0.5, distortion=0.0):
		n = self.node("ShaderNodeTexNoise", noise_dimensions="3D")
		self.set(n.inputs["Vector"], vec)
		n.inputs["Scale"].default_value = scale
		n.inputs["Detail"].default_value = detail
		n.inputs["Roughness"].default_value = rough
		n.inputs["Distortion"].default_value = distortion
		return n.outputs["Fac"]

	def voronoi(self, vec, scale, feature="F1", metric="EUCLIDEAN", randomness=1.0):
		n = self.node("ShaderNodeTexVoronoi", voronoi_dimensions="3D", feature=feature, distance=metric)
		self.set(n.inputs["Vector"], vec)
		n.inputs["Scale"].default_value = scale
		n.inputs["Randomness"].default_value = randomness
		return n

	def white(self, vec):
		n = self.node("ShaderNodeTexWhiteNoise", noise_dimensions="3D")
		self.set(n.inputs["Vector"], vec)
		return n.outputs["Value"]

	def wave(self, vec, scale, distortion=2.0, detail=2.0, direction="Y"):
		n = self.node("ShaderNodeTexWave", wave_type="BANDS", bands_direction=direction)
		self.set(n.inputs["Vector"], vec)
		n.inputs["Scale"].default_value = scale
		n.inputs["Distortion"].default_value = distortion
		n.inputs["Detail"].default_value = detail
		return n.outputs["Fac"]

	def col(self, color, fac=1.0):
		# Linear RGB of a hex colour scaled by fac (a socket or number) as a vector socket.
		n = self.node("ShaderNodeVectorMath", operation="SCALE")
		n.inputs[0].default_value = lin(color) if isinstance(color, int) else color
		self.set(n.inputs[3], fac)
		return n.outputs[0]

	def scale(self, vec, fac):
		n = self.node("ShaderNodeVectorMath", operation="SCALE")
		self.set(n.inputs[0], vec)
		self.set(n.inputs[3], fac)
		return n.outputs[0]

	def mix(self, fac, a, b):
		n = self.node("ShaderNodeMix", data_type="RGBA")
		self.set(n.inputs[0], fac)
		self.set(n.inputs[6], (*lin(a), 1) if isinstance(a, int) else a)
		self.set(n.inputs[7], (*lin(b), 1) if isinstance(b, int) else b)
		return n.outputs[2]

	def bump(self, height, strength, distance):
		n = self.node("ShaderNodeBump")
		n.inputs["Strength"].default_value = strength
		n.inputs["Distance"].default_value = distance
		self.set(n.inputs["Height"], height)
		return n.outputs["Normal"]

	def grid_dist(self, u, v, pu, pv):
		# Distance (studs) to the nearest line of a pu x pv grid, plus the cell index and local position.
		su, sv = self.div(u, pu), self.div(v, pv)
		fu, fv = self.fract(su), self.fract(sv)
		du = self.mul(self.mn(fu, self.inv(fu)), pu)
		dv = self.mul(self.mn(fv, self.inv(fv)), pv)
		return self.mn(du, dv), (self.floor(su), self.floor(sv)), (self.mul(fu, pu), self.mul(fv, pv))


# ---------------------------------------------------------------- materials

def _base(name, rbx_material, rbx_variant, color, **extra):
	m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
	m["rbx_material"] = rbx_material
	m["rbx_variant"] = rbx_variant
	m["rbx_color"] = "%06X" % color
	m.use_fake_user = True  # keep the whole library in every saved .blend, used or not
	for k, v in extra.items():
		m[k] = v
	m.use_nodes = True
	nt = m.node_tree
	nt.nodes.clear()
	out = nt.nodes.new("ShaderNodeOutputMaterial")
	bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
	nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
	m.diffuse_color = (*lin(color), 1)
	return m, Graph(m), bsdf


def _concrete_board(name="ConcreteBoard", color=C_BOARD):
	# Board-formed concrete: 3.2 x 6.4 formwork panels with fine 0.06 V-groove joints, 6 tie holes per panel (2 x 3,
	# inset 0.4: small 0.08 holes with a lighter 0.03 cone-plug ring, a faint stain running ~1.5 down from each),
	# +-3% tone per panel, soft mottling and a faint horizontal formwork grain. (Art review: the old 4 big black
	# corner dots read as rivets on metal tiles and the 0.12 grooves as tile grout.)
	m, g, b = _base(name, "Concrete", "Lobby_ConcreteBoard", color)
	u, v = g.uv()
	d, (cu, cv), (lx, ly) = g.grid_dist(u, v, 3.2, 6.4)
	groove = g.inv(g.smooth(0.0, 0.03, d))
	hx = g.mn(g.absv(g.sub(lx, 0.4)), g.absv(g.sub(lx, 2.8)))
	hy = g.mn(g.mn(g.absv(g.sub(ly, 0.4)), g.absv(g.sub(ly, 3.2))), g.absv(g.sub(ly, 6.0)))
	hr = g.length(g.xyz(hx, hy))
	hole = g.inv(g.smooth(0.065, 0.08, hr))
	plug = g.mul(g.smooth(0.07, 0.085, hr), g.inv(g.smooth(0.1, 0.115, hr)))
	w = g.white(g.xyz(cu, cv, 3.7))
	tone = g.remap(w, 0.0, 1.0, 0.94, 1.06)
	p3 = g.xyz(u, v, g.mul(w, 17.0))
	mottle = g.remap(g.noise(p3, 0.28, 5.0, 0.55), 0.3, 0.7, 0.84, 1.10)
	grain = g.remap(g.noise(g.xyz(g.mul(u, 0.18), g.mul(v, 5.0), w), 1.0, 3.0), 0.3, 0.7, 0.97, 1.03)
	pores = g.smooth(0.70, 0.74, g.noise(p3, 26.0, 0.0))
	# Stains: a soft vertical streak under each hole (V runs up), 1.5 long, width varying with noise.
	sw = g.remap(g.noise(g.xyz(u, g.mul(v, 0.5), 9.0), 2.0, 2.0), 0.3, 0.7, 0.05, 0.13)
	across = g.inv(g.smooth(0.0, 1.0, g.div(hx, sw)))
	streak = 0.0
	for yk in (0.4, 3.2, 6.0):
		dy = g.sub(yk, ly)
		streak = g.add(streak, g.mul(g.smooth(0.05, 0.2, dy), g.inv(g.smooth(0.2, 1.5, dy))))
	streak = g.mul(g.mul(across, g.mn(streak, 1.0)), g.inv(hole))
	f = g.mul(g.mul(tone, mottle), grain)
	f = g.mul(f, g.inv(g.mul(groove, 0.25)))
	f = g.mul(f, g.inv(g.mul(hole, 0.4)))
	f = g.mul(f, g.add(1.0, g.mul(plug, 0.07)))
	f = g.mul(f, g.inv(g.mul(streak, 0.04)))
	f = g.mul(f, g.inv(g.mul(pores, 0.2)))
	g.set(b.inputs["Base Color"], g.col(color, f))
	g.set(b.inputs["Roughness"], g.add(g.remap(mottle, 0.84, 1.10, 0.84, 0.74), g.mul(hole, 0.08)))
	h = g.sub(g.smooth(0.0, 0.03, d), g.mul(hole, 0.6))
	h = g.add(h, g.mul(g.noise(p3, 9.0, 3.0), 0.12))
	h = g.sub(h, g.mul(pores, 0.2))
	g.set(b.inputs["Normal"], g.bump(h, 0.35, 0.03))
	return m


def _concrete_polished(name, color, rough=(0.26, 0.4), variant="Lobby_ConcretePolished"):
	# Polished concrete: cloudy trowel tone, faint aggregate specks, smudgy satin roughness. Kept satin (0.26-0.4,
	# low specular) rather than mirror-like: Roblox has no screen-space reflections, and a glossy EEVEE floor mirrored
	# the dark ring and read as dark slate instead of #B9B4AA (art review).
	m, g, b = _base(name, "Concrete", variant, color)
	b.inputs["Specular IOR Level"].default_value = 0.35
	u, v = g.uv()
	p = g.xyz(u, v, 0.0)
	cloud = g.remap(g.noise(p, 0.09, 4.0, 0.6), 0.3, 0.7, 0.93, 1.06)
	vo = g.voronoi(p, 2.6)
	speck = g.inv(g.smooth(0.12, 0.2, vo.outputs["Distance"]))
	r = g.sep(vo.outputs["Color"])[0]
	keep = g.smooth(0.45, 0.5, r)
	tint = g.remap(g.sep(vo.outputs["Color"])[1], 0.0, 1.0, 0.82, 1.12)
	f = g.mul(cloud, g.add(1.0, g.mul(g.mul(speck, keep), g.sub(tint, 1.0))))
	g.set(b.inputs["Base Color"], g.col(color, f))
	g.set(b.inputs["Roughness"], g.remap(g.noise(p, 0.22, 3.0), 0.3, 0.7, rough[0], rough[1]))
	g.set(b.inputs["Normal"], g.bump(g.noise(p, 3.0, 2.0), 0.04, 0.02))
	return m


def _concrete_dark(name="ConcreteDark", color=C_DARK):
	# Honed dark concrete: matte, fine light aggregate, saw-cut joints every 5 studs (both ways).
	m, g, b = _base(name, "Concrete", "Lobby_ConcreteDark", color)
	u, v = g.uv()
	p = g.xyz(u, v, 0.0)
	d, _, _ = g.grid_dist(u, v, 5.0, 5.0)
	cut = g.inv(g.smooth(0.02, 0.05, d))
	cloud = g.remap(g.noise(p, 0.12, 4.0, 0.6), 0.3, 0.7, 0.9, 1.08)
	vo = g.voronoi(p, 3.5)
	speck = g.mul(g.inv(g.smooth(0.1, 0.17, vo.outputs["Distance"])), g.smooth(0.55, 0.6, g.sep(vo.outputs["Color"])[0]))
	f = g.mul(g.mul(cloud, g.add(1.0, g.mul(speck, 0.55))), g.inv(g.mul(cut, 0.6)))
	g.set(b.inputs["Base Color"], g.col(color, f))
	g.set(b.inputs["Roughness"], g.add(g.remap(g.noise(p, 0.3, 3.0), 0.3, 0.7, 0.5, 0.64), g.mul(cut, 0.2)))
	g.set(b.inputs["Normal"], g.bump(g.add(g.smooth(0.02, 0.05, d), g.mul(g.noise(p, 6.0, 2.0), 0.05)), 0.4, 0.03))
	return m


def _terrazzo(name="Terrazzo", color=C_TERRAZZO):
	# Terrazzo: warm light matrix with fine light chips (two sizes) and a few grey ones.
	m, g, b = _base(name, "Concrete", "Lobby_Terrazzo", color)
	u, v = g.uv()
	p = g.xyz(u, v, 0.0)
	cloud = g.remap(g.noise(p, 0.15, 3.0), 0.3, 0.7, 0.96, 1.04)
	base = g.col(color, cloud)
	for scale, size, seed in ((3.2, 0.22, 0.0), (7.0, 0.26, 5.3)):
		vo = g.voronoi(g.xyz(u, v, seed), scale, metric="MANHATTAN")
		chip = g.inv(g.smooth(size - 0.03, size, vo.outputs["Distance"]))
		rr, rg, _ = g.sep(vo.outputs["Color"])
		chip = g.mul(chip, g.smooth(0.25, 0.3, rr))
		chip_col = g.mix(g.smooth(0.3, 0.32, rg), 0x8F887F, 0xF5F2EC)
		base = g.mix(chip, base, chip_col)
	g.set(b.inputs["Base Color"], base)
	g.set(b.inputs["Roughness"], g.remap(g.noise(p, 0.3, 2.0), 0.3, 0.7, 0.24, 0.36))
	return m


def _rock(name, color):
	# Granite: the facets come from the mesh; the material adds grain, large tone drift, hairline cracks and a
	# noise-driven normal (the step 5 Lobby_Rock normal map).
	# The strong large-scale tone drift (0.75-1.18) is the fake occlusion the step 5 Lobby_Rock texture carries.
	m, g, b = _base(name, "Slate", "Lobby_Rock", color)
	p = g.obj()
	tone = g.remap(g.noise(p, 0.07, 4.0, 0.6), 0.3, 0.7, 0.75, 1.18)
	grain = g.remap(g.noise(p, 7.0, 2.0, 0.5), 0.3, 0.7, 0.88, 1.12)
	vo = g.voronoi(p, 11.0)
	fleck = g.mul(g.inv(g.smooth(0.08, 0.16, vo.outputs["Distance"])), g.smooth(0.55, 0.6, g.sep(vo.outputs["Color"])[0]))
	grain = g.mul(grain, g.inv(g.mul(fleck, 0.35)))
	fine = g.remap(g.noise(p, 2.2, 6.0, 0.6), 0.3, 0.7, 0.92, 1.08)
	px, py, pz = g.sep(p)
	strata = g.remap(g.noise(g.xyz(g.mul(px, 0.15), g.mul(py, 0.15), g.mul(pz, 1.6)), 1.0, 3.0), 0.3, 0.7, 0.9, 1.08)
	crack = g.smooth(0.74, 0.78, g.noise(p, 0.9, 2.0, 0.5, distortion=1.5))
	f = g.mul(g.mul(g.mul(g.mul(tone, grain), fine), strata), g.inv(g.mul(crack, 0.3)))
	g.set(b.inputs["Base Color"], g.col(color, f))
	g.set(b.inputs["Roughness"], g.remap(grain, 0.8, 1.15, 0.82, 0.68))
	h = g.add(g.noise(p, 0.55, 8.0, 0.62), g.mul(g.noise(p, 3.0, 4.0), 0.35))
	h = g.sub(h, g.mul(crack, 0.2))
	g.set(b.inputs["Normal"], g.bump(h, 0.55, 0.18))
	return m


def _metal(name, color, rough, var=0.04, variant="", brushed=False, metallic=1.0, rbx="Metal"):
	m, g, b = _base(name, rbx, variant, color)
	b.inputs["Metallic"].default_value = metallic
	u, v = g.uv()
	p = g.obj()
	if brushed:
		# Fine directional brushing along U: streaks in roughness and tone (EEVEE has no anisotropy).
		s = g.noise(g.xyz(g.mul(u, 0.4), g.mul(v, 70.0), 0.0), 1.0, 3.0, 0.6)
		s2 = g.noise(g.xyz(g.mul(u, 0.1), g.mul(v, 300.0), 2.0), 1.0, 1.0)
		st = g.add(g.mul(s, 0.7), g.mul(s2, 0.3))
		g.set(b.inputs["Base Color"], g.col(color, g.remap(st, 0.3, 0.7, 0.92, 1.05)))
		g.set(b.inputs["Roughness"], g.remap(st, 0.3, 0.7, rough - var, rough + var))
		b.inputs["Anisotropic"].default_value = 0.6  # Cycles only; harmless in EEVEE
		g.set(b.inputs["Normal"], g.bump(st, 0.05, 0.01))
	else:
		n = g.noise(p, 0.6, 4.0)
		g.set(b.inputs["Base Color"], g.col(color, g.remap(n, 0.3, 0.7, 0.94, 1.05)))
		g.set(b.inputs["Roughness"], g.remap(g.noise(p, 1.4, 3.0), 0.3, 0.7, rough - var, rough + var))
	return m


def _oak(name="Oak", color=C_OAK):
	# Warm oak, straight grain along U (the helpers lay U along a slat's length): long irregular streaks of darker
	# late wood, a finer streak layer and a per-board tone shift (boards/slats are 1 stud wide in V).
	m, g, b = _base(name, "Wood", "Lobby_Oak", color)
	u, v = g.uv()
	plank = g.white(g.xyz(g.floor(v), 0.0, 7.0))
	seed = g.mul(plank, 40.0)
	streak = g.noise(g.xyz(g.mul(u, 0.12), g.mul(v, 6.0), seed), 1.0, 8.0, 0.68, distortion=0.25)
	fine = g.noise(g.xyz(g.mul(u, 0.25), g.mul(v, 28.0), seed), 1.0, 4.0, 0.6)
	# Half the old grain contrast around #94683F (art review: the old oak read as stripy orange laminate), satin
	# oiled finish (roughness 0.45-0.55, a faint coat).
	t = g.add(g.mul(streak, 0.75), g.mul(fine, 0.25))
	c = g.mix(g.smooth(0.3, 0.7, t), 0x86603C, 0x9E7246)
	c = g.scale(c, g.remap(plank, 0.0, 1.0, 0.94, 1.05))
	g.set(b.inputs["Base Color"], c)
	g.set(b.inputs["Roughness"], g.remap(t, 0.3, 0.7, 0.55, 0.45))
	b.inputs["Coat Weight"].default_value = 0.06
	b.inputs["Coat Roughness"].default_value = 0.4
	g.set(b.inputs["Normal"], g.bump(fine, 0.05, 0.01))
	return m


def _glass(name="Glass", color=C_GLASS):
	# One layer, Transparency 0.7: a thin tinted sheet with clean reflections.
	m, g, b = _base(name, "Glass", "", color, rbx_transparency=0.7)
	m.surface_render_method = "BLENDED"
	m.use_backface_culling = False
	b.inputs["Base Color"].default_value = (*lin(color), 1)
	b.inputs["Roughness"].default_value = 0.03
	b.inputs["Alpha"].default_value = 0.3
	b.inputs["Specular IOR Level"].default_value = 0.8
	return m


def _flat(name, color, rough, metallic=0.0, rbx="SmoothPlastic", **extra):
	m, g, b = _base(name, rbx, "", color, **extra)
	b.inputs["Base Color"].default_value = (*lin(color), 1)
	b.inputs["Roughness"].default_value = rough
	b.inputs["Metallic"].default_value = metallic
	return m


def _emissive(name, color, strength, rbx="Neon", **extra):
	# Roblox Neon (and SurfaceGui text): it glows where it is SEEN and lights nothing. So the emission only reaches
	# camera rays (Light Path "Is Camera Ray"): the strip renders and blooms, but no wall, floor or reflection is lit
	# by it. A wash must be a real light (rbx_light), counted against the light budget.
	m, g, b = _base(name, rbx, "", color, **extra)
	m["glow"] = True
	b.inputs["Base Color"].default_value = (*lin(color), 1)
	b.inputs["Emission Color"].default_value = (*lin(color), 1)
	lp = g.node("ShaderNodeLightPath")
	g.set(b.inputs["Emission Strength"], g.mul(lp.outputs["Is Camera Ray"], strength))
	b.inputs["Roughness"].default_value = 0.3
	return m


def _beam(name="Beam_Sun", color=L_SUN, strength=0.12, top=1.0, bottom=0.33, edge=0.35):
	# Fake sunbeam (Roblox Beam, additive, LightEmission 1): transparent + emission, faded by UV.
	# U across the ribbon, V from the top (0, at the skylight rim) to the floor (1). The beam is brightest where it
	# leaves the rim (`top`) and thins toward the floor (`bottom`), like Roblox Beam Transparency 0.85 -> 0.95, so it
	# visibly comes OUT of the oculus. `edge` is the soft fraction of each side (wider, fainter outer ribbons give the
	# shaft its soft edge).
	m, g, b = _base(name, "Beam", "", color, preview_only=True)
	nt = m.node_tree
	nt.nodes.remove(b)
	out = [n for n in nt.nodes if n.type == "OUTPUT_MATERIAL"][0]
	m.surface_render_method = "BLENDED"
	m.use_backface_culling = False
	u, v = g.uv()
	across = g.smooth(0.0, edge, g.inv(g.absv(g.sub(g.mul(u, 2.0), 1.0))))
	along = g.mul(g.mul(g.remap(v, 0.0, 1.0, top, bottom), g.smooth(0.0, 0.03, v)), g.inv(g.smooth(0.94, 1.0, v)))
	k = g.mul(g.mul(across, along), strength)
	em = g.node("ShaderNodeEmission")
	em.inputs["Color"].default_value = (*lin(color), 1)
	g.set(em.inputs["Strength"], k)
	tr = g.node("ShaderNodeBsdfTransparent")
	add = g.node("ShaderNodeAddShader")
	g.L.new(tr.outputs[0], add.inputs[0])
	g.L.new(em.outputs[0], add.inputs[1])
	g.L.new(add.outputs[0], out.inputs["Surface"])
	return m


def make_materials():
	# Every material of the Lobby Kit style sheet (plus sign, screen and preview-only helpers). Returns {name: mat}.
	mats = [
		_concrete_board(),
		# Same MaterialVariant, darker Color: coffer insides and recess backs ("darker inner faces").
		_concrete_board("ConcreteBoardShade", C_BOARD_SHADE),
		_concrete_polished("ConcretePolished", C_POLISHED),
		_concrete_polished("ConcretePolishedInlay", C_INLAY, rough=(0.2, 0.34)),
		_concrete_dark(),
		# Same honed variant, mid Color: plinths as one continuous band (saw cuts, no tie holes).
		_concrete_dark("ConcreteHoned", C_HONED),
		_terrazzo(),
		_rock("Rock", C_ROCK),
		_rock("RockDuels", C_ROCK_DUELS),
		_metal("SteelBlack", C_STEEL_BLACK, 0.36, 0.05, metallic=0.85),
		_metal("SteelBrushed", C_STEEL_BRUSHED, 0.32, 0.08, brushed=True, metallic=0.75),
		_oak(),
		_metal("Brass", C_BRASS, 0.375, 0.025, metallic=0.8),  # warm satin, roughness 0.35-0.4
		_glass(),
		_metal("SignPanel", C_SIGN, 0.5, 0.04, metallic=0.4),  # charcoal steel behind sign text
		_flat("Screen", C_SCREEN, 0.18),  # SurfaceGui screens (leaderboards, terminals)
		_emissive("SignText", C_TEXT, 1.6, rbx="SurfaceGui", preview_only=True),  # SurfaceGui text, LightInfluence 0
		_emissive("SignTextDim", 0x9A9EA6, 1.2, rbx="SurfaceGui", preview_only=True),
		_beam(),
		_beam("Beam_SunSoft", strength=0.06, edge=0.5),  # the wider, fainter outer ribbons (soft shaft edge)
		# Scale mannequin (preview only): a 5-stud R15 block avatar in Roblox's neutral grey.
		_flat("Mannequin", 0xA3A2A5, 0.62, preview_only=True),
	]
	for name, (c, s) in GLOWS.items():
		mats.append(_emissive(name, c, s))
	return {m.name: m for m in mats}


# ---------------------------------------------------------------- mesh helpers (bmesh, studs)

def mat_all(bm, idx):
	for f in bm.faces:
		f.material_index = idx
	return bm


def place(bm, matrix):
	bmesh.ops.transform(bm, matrix=matrix, verts=bm.verts[:])
	if matrix.determinant() < 0:
		bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
	return bm


def rot_z(deg, offset=(0, 0, 0)):
	return Matrix.Translation(offset) @ Matrix.Rotation(math.radians(deg), 4, "Z")


def facing(direction_deg, offset=(0, 0, 0)):
	# Matrix that turns a kit piece (faces +X) to face the Blender-space heading `direction_deg` (0 = +X,
	# 90 = +Y, -90 = -Y) and moves its origin to `offset`.
	return rot_z(direction_deg, offset)


def copy(bm):
	tmp = bpy.data.meshes.new("_c")
	bm.to_mesh(tmp)
	out = bmesh.new()
	out.from_mesh(tmp)
	bpy.data.meshes.remove(tmp)
	return out


def cbox(x0, x1, y0, y1, z0, z1, ch=0.25, mat=0):
	# Box with chamfered edges (concrete 0.25, steel 0.1 per the style sheet).
	bm = mat_all(box(x0, x1, y0, y1, z0, z1), mat)
	if ch > 0:
		bevel(bm, ch, segs=1, angle=30)
	return bm


def cyl(cx, cy, r, z0, z1, segs=32, mat=0, ch=0.0):
	bm = mat_all(prism(ring_pts(cx, cy, r, segs, math.pi / segs), "Z", z0, z1), mat)
	if ch > 0:
		bevel(bm, ch, segs=1, angle=30)
	return bm


def arc(r_in, r_out, b0, b1, z0, z1, steps=None, mat=0, center=(0.0, 0.0)):
	# Radial wedge between radii r_in..r_out and bearings b0..b1 (degrees, clockwise from north = Blender +Y),
	# heights z0..z1, in studs. r_in = 0 gives a pie slice. steps: facets along the arc (default one per 5.625 deg,
	# i.e. two per 11.25 deg kit segment). A full circle (b1 - b0 = 360) gives a closed ring.
	span = b1 - b0
	steps = steps or max(1, int(math.ceil(abs(span) / 5.625 - 1e-6)))
	full = abs(abs(span) - 360) < 1e-6
	cx, cy = center
	bm = bmesh.new()

	def ring(r, z):
		if r < 1e-6:
			return [bm.verts.new((cx, cy, z))] * (steps + 1)
		pts = []
		for i in range(steps + 1):
			if full and i == steps:
				pts.append(pts[0])
				break
			p = polar(r, b0 + span * i / steps, z)
			pts.append(bm.verts.new((p.x + cx, p.y + cy, p.z)))
		return pts

	ib, ob, ot, it = ring(r_in, z0), ring(r_out, z0), ring(r_out, z1), ring(r_in, z1)
	for i in range(steps):
		j = i + 1
		bm.faces.new((ob[i], ob[j], ot[j], ot[i]))  # outer wall
		if r_in > 1e-6:
			bm.faces.new((ib[j], ib[i], it[i], it[j]))  # inner wall
			bm.faces.new((ot[i], ot[j], it[j], it[i]))  # top
			bm.faces.new((ib[i], ib[j], ob[j], ob[i]))  # bottom
		else:
			bm.faces.new((ot[i], ot[j], it[0]))
			bm.faces.new((ib[0], ob[j], ob[i]))
	if not full:
		for k in (0, steps):
			quad = (ib[k], ob[k], ot[k], it[k]) if r_in > 1e-6 else (ib[0], ob[k], ot[k], it[0])
			bm.faces.new(quad)
	bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-6)
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	return mat_all(bm, mat)


def lathe(profile, b0=0.0, b1=360.0, steps=None, mat=0, center=(0.0, 0.0)):
	# Revolves an open (r, z) polyline between bearings b0..b1 (degrees, clockwise from north), in studs. Round kit
	# trims (rims, lips, coves, ledges) without the hidden faces a closed arc() would add. A point with r = 0 collapses
	# to the axis (fans). steps: facets along the arc (default one per 5.625 deg). Face orientation: the visible side
	# is to the LEFT of the profile direction, drawn with r to the right and z up (so a profile running outward along
	# r faces up, one running up a wall faces the axis, one running down faces away from it).
	span = b1 - b0
	steps = steps or max(1, int(math.ceil(abs(span) / 5.625 - 1e-6)))
	full = abs(abs(span) - 360) < 1e-6
	cx, cy = center
	bm = bmesh.new()
	rings = []
	for r, z in profile:
		if r < 1e-6:
			v = bm.verts.new((cx, cy, z))
			rings.append([v] * (steps + 1))
			continue
		pts = []
		for i in range(steps + 1):
			if full and i == steps:
				pts.append(pts[0])
				break
			p = polar(r, b0 + span * i / steps, z)
			pts.append(bm.verts.new((p.x + cx, p.y + cy, z)))
		rings.append(pts)
	for k in range(len(profile) - 1):
		(ra, za), (rb, zb) = profile[k], profile[k + 1]
		dr, dz = rb - ra, zb - za
		A, B = rings[k], rings[k + 1]
		for i in range(steps):
			quad = []
			for v in (A[i], A[i + 1], B[i + 1], B[i]):
				if v not in quad:
					quad.append(v)
			if len(quad) < 3:
				continue
			f = bm.faces.new(quad)
			f.normal_update()
			c = f.calc_center_median()
			rad = Vector((c.x - cx, c.y - cy, 0.0))
			rad = rad.normalized() if rad.length > 1e-6 else Vector((0, 0, 0))
			want = rad * (-dz) + Vector((0, 0, dr))
			if f.normal.dot(want) < 0:
				f.normal_flip()
	return mat_all(bm, mat)


def rock_chunk(seed, size=(4, 4, 4), center=(0, 0, 0), points=22, jag=0.28, flat_base=False, mat=0):
	# Faceted low-poly rock: convex hull of jittered points on an ellipsoid (seeded, so the same seed always gives
	# the same chunk). size = full extents. flat_base clips the bottom to center.z so it sits on the floor.
	rnd = random.Random(seed)
	sx, sy, sz = size
	cx, cy, cz = center
	bm = bmesh.new()
	vs = []
	golden = math.pi * (3 - math.sqrt(5))
	for i in range(points):
		y = 1 - 2 * (i + 0.5) / points
		r = math.sqrt(max(0.0, 1 - y * y))
		a = golden * i + rnd.uniform(-0.5, 0.5)
		d = Vector((math.cos(a) * r, math.sin(a) * r, y))
		d += Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-1, 1))) * 0.18
		d.normalize()
		k = 1 - jag * rnd.random()
		p = Vector((d.x * sx / 2 * k, d.y * sy / 2 * k, d.z * sz / 2 * k))
		if flat_base:
			p.z = max(p.z + sz * 0.3, 0.0)  # sits on z = center.z, about 0.8 of sz tall
		vs.append(bm.verts.new((p.x + cx, p.y + cy, p.z + cz)))
	res = bmesh.ops.convex_hull(bm, input=vs)
	junk = list({v for v in res["geom_interior"] + res["geom_unused"] if isinstance(v, bmesh.types.BMVert) and v.is_valid})
	if junk:
		bmesh.ops.delete(bm, geom=junk, context="VERTS")
	bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(4), verts=bm.verts[:], edges=bm.edges[:])
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	return mat_all(bm, mat)


def rock_face(width, height, seed, cell=2.2, depth=2.4, relief=1.4, mat=0, ledges=3, chips=0.3, row=None):
	# A blasted rock face as ONE faceted surface (cheap, no holes), at two facet scales:
	#   primary: a jittered grid (about `cell` across, `row` up; row defaults to 1.2 x cell) split into strata BANDS
	#     by `ledges` near-level breaks. Each band is its own slab leaning slightly out toward its top, plus layered
	#     noise. At every break a pair of close rows makes a crisp BENCH: the band above starts set back, so the step
	#     is an up-facing facet that catches a downlight (sawtooth strata, like drilled and blasted benches).
	#   secondary: `chips` of the faces (more near the breaks) are poked into 3 small chip facets (about cell / 2).
	# Triangulated with random diagonals and flat shaded, so every triangle is a facet. Kit space: the face looks
	# along +X, its back plane is x = 0 and the surface sits between x = depth - relief and x = depth, spanning y
	# -width/2..width/2, z 0..height. The two side edges and the bottom are held at x = depth - relief / 2 so any two
	# variants tile side by side. Triangles: about 2 * (width / cell) * (height / row + 2 * ledges) * (1 + chips).
	from mathutils import noise
	rnd = random.Random(seed)
	off = Vector((rnd.uniform(0, 500), rnd.uniform(0, 500), rnd.uniform(0, 500)))
	row = row or cell * 1.2
	ny = max(2, int(round(width / cell)))
	mid = depth - relief / 2
	# Breaks: spread over the height with jitter, each slightly tilted (slope along y).
	breaks = []
	if ledges > 0:
		for k in range(ledges):
			zc = height * (k + 0.5 + rnd.uniform(-0.28, 0.28)) / ledges
			breaks.append((min(max(zc, 1.2), height - 1.2), rnd.uniform(-0.05, 0.05)))
		breaks.sort()
	bands = len(breaks) + 1
	# Sawtooth strata: each band leans slightly OUT toward its top, then the next band starts set back, so every
	# break is a bench (an up-facing facet that catches a downlight) and none is a dark overhang slash.
	sets = [rnd.uniform(-0.12, 0.12) for _ in range(bands)]
	leans = [rnd.uniform(0.3, 0.55) for _ in range(bands)]
	step = 0.32  # height of the step between the two rows at a break
	# Row stations: regular rows (skipping any near a break) plus a close pair at every break.
	zs = []
	nz = max(2, int(round(height / row)))
	for i in range(nz + 1):
		z = height * i / nz
		if all(abs(z - zc) > 0.9 for zc, _ in breaks) or i in (0, nz):
			zs.append((z, None))
	for k, (zc, sl) in enumerate(breaks):
		zs.append((zc - step / 2, (k, sl, -1)))
		zs.append((zc + step / 2, (k, sl, 1)))
	zs.sort(key=lambda q: q[0])

	def band_of(z, y):
		for k, (zc, sl) in enumerate(breaks):
			if z < zc + sl * y:
				return k
		return len(breaks)

	def band_t(z, y, k):
		lo = 0.0 if k == 0 else breaks[k - 1][0] + breaks[k - 1][1] * y
		hi = height if k == len(breaks) else breaks[k][0] + breaks[k][1] * y
		return (z - lo) / max(hi - lo, 1e-3)

	bm = bmesh.new()
	grid = []
	near = []
	for iz, (zb, tag) in enumerate(zs):
		r = []
		for iy in range(ny + 1):
			y = -width / 2 + width * iy / ny
			ey, ez = iy in (0, ny), iz in (0, len(zs) - 1)
			if not ey:
				y += rnd.uniform(-0.36, 0.36) * width / ny
			if tag is None:
				z = zb
				if not ez:
					gap = min(abs(zb - zs[iz - 1][0]), abs(zs[iz + 1][0] - zb))
					z += rnd.uniform(-0.3, 0.3) * gap
				k = band_of(z, y)
			else:
				k_br, sl, side = tag
				z = zb + sl * y + rnd.uniform(-0.05, 0.05)
				k = k_br if side < 0 else k_br + 1
			q = Vector((0.0, y, z)) * 0.11 + off
			h = noise.noise(q) + 0.5 * noise.noise(q * 2.3) + 0.25 * noise.noise(q * 5.1)
			h = max(-1.0, min(1.0, h * 0.9))
			t = band_t(z, y, k)
			x = mid + (sets[k] + leans[k] * (t - 0.5)) * relief + h * relief * 0.22 + rnd.uniform(-0.17, 0.17) * relief
			x = min(max(x, depth - relief), depth)
			if ey or iz == 0:
				x = mid
				z = zb if tag is None else z
			r.append(bm.verts.new((x, y, z)))
		grid.append(r)
		near.append(tag is not None)
	faces = []
	for iz in range(len(zs) - 1):
		hot = near[iz] or near[iz + 1]
		for iy in range(ny):
			a0, a1, b1, b0 = grid[iz][iy], grid[iz][iy + 1], grid[iz + 1][iy + 1], grid[iz + 1][iy]
			if rnd.random() < 0.5:
				tris = [bm.faces.new((a0, a1, b1)), bm.faces.new((a0, b1, b0))]
			else:
				tris = [bm.faces.new((a0, a1, b0)), bm.faces.new((a1, b1, b0))]
			faces += [(f, hot) for f in tris]
	bm.normal_update()
	if sum(f.normal.x for f in bm.faces) < 0:
		bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
		bm.normal_update()
	# Secondary chips: poke chosen faces and push the new centre in or out along the face normal.
	if chips > 0:
		pick = [f for f, hot in faces if f.calc_area() > cell * cell * 0.12 and rnd.random() < chips * (1.6 if hot else 0.8)]
		if pick:
			res = bmesh.ops.poke(bm, faces=pick)
			bm.normal_update()
			for v in res["verts"]:
				n = v.link_faces[0].normal if v.link_faces else Vector((1, 0, 0))
				v.co += n * rnd.uniform(-0.18, 0.3) * cell * 0.35
				v.co.x = min(max(v.co.x, depth - relief), depth)
	bm.normal_update()
	return mat_all(bm, mat)


def slat_panel(width, height, slat=1.0, pitch=1.5, depth=0.35, backing=0.2, z0=0.0, slat_mat=0, back_mat=1):
	# Oak slat wall (style sheet: 1 wide on a 1.5 pitch) on a dark backing, kit space (back at x = 0, faces +X,
	# width along Y centred). Returns (slats, backing) so each can take its own material.
	back = mat_all(box(0, backing, -width / 2, width / 2, z0, z0 + height), back_mat)
	sl = bmesh.new()
	n = int((width - slat) // pitch) + 1
	y0 = -((n - 1) * pitch) / 2
	for i in range(n):
		y = y0 + i * pitch
		merge(sl, cbox(backing, backing + depth, y - slat / 2, y + slat / 2, z0, z0 + height, ch=0.06, mat=slat_mat))
	return sl, back


def glow_strip(x0, x1, y0, y1, z0, z1):
	# Thin Neon strip (keep the smallest side <= 0.3 per the style sheet). Make it an object with add_glow().
	return box(x0, x1, y0, y1, z0, z1)


# ---------------------------------------------------------------- UVs (studs)

def stud_uvs(bm, uv_rotate=False):
	# Box projection in studs from the bmesh's current coordinates (world coords if built in place): faces mostly
	# facing X use (y, z), facing Y use (x, z), facing Z use (x, y). V runs up on walls. uv_rotate swaps U/V (to turn
	# oak grain or brushing 90 degrees).
	layer = bm.loops.layers.uv.verify()
	bm.normal_update()
	for f in bm.faces:
		n = f.normal
		ax, ay, az = abs(n.x), abs(n.y), abs(n.z)
		for lp in f.loops:
			c = lp.vert.co
			if az >= ax and az >= ay:
				uv = (c.x, c.y)
			elif ax >= ay:
				uv = (c.y if n.x < 0 else -c.y, c.z)
			else:
				uv = (-c.x if n.y < 0 else c.x, c.z)
			lp[layer].uv = (uv[1], uv[0]) if uv_rotate else uv
	return bm


def arc_uvs(bm, r_ref, b_ref=0.0, center=(0.0, 0.0)):
	# Curved segments: U = arc length at r_ref from bearing b_ref, V = height on walls; floors/tops use plan (x, y).
	layer = bm.loops.layers.uv.verify()
	bm.normal_update()
	cx, cy = center
	for f in bm.faces:
		n = f.normal
		for lp in f.loops:
			c = lp.vert.co
			if abs(n.z) > 0.7:
				lp[layer].uv = (c.x, c.y)
				continue
			b = math.atan2(c.x - cx, c.y - cy) - math.radians(b_ref)
			b = (b + math.pi) % (2 * math.pi) - math.pi
			fc = f.calc_center_median()
			radial = Vector((fc.x - cx, fc.y - cy, 0))
			if radial.length > 1e-6 and abs(Vector((n.x, n.y, 0)).normalized().dot(radial.normalized())) > 0.7:
				lp[layer].uv = (b * r_ref, c.z)
			else:
				lp[layer].uv = (math.hypot(c.x - cx, c.y - cy), c.z)
	return bm


# ---------------------------------------------------------------- objects

def collection(name, parent=None):
	col = bpy.data.collections.get(name) or bpy.data.collections.new(name)
	par = parent or bpy.context.scene.collection
	if col.name not in [c.name for c in par.children]:
		par.children.link(col)
	return col


def add_obj(name, bm, mats, col, smooth_angle=35, uvs="box", uv_rotate=False):
	# bm faces index into `mats` (a list of materials). uvs: "box" (stud_uvs), "keep" (already set) or a callable.
	if uvs == "box":
		stud_uvs(bm, uv_rotate)
	elif callable(uvs):
		uvs(bm)
	bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-5)
	me = bpy.data.meshes.new(name)
	bm.to_mesh(me)
	bm.free()
	for m in mats:
		me.materials.append(m)
	if smooth_angle:
		me.shade_smooth()
		me.set_sharp_from_angle(angle=math.radians(smooth_angle))
	else:
		me.shade_flat()
	ob = bpy.data.objects.new(name, me)
	col.objects.link(ob)
	return ob


def add_glow(name, bm, glow, col):
	# Neon parts are separate objects named <Part>_Glow with one emissive material (recoloured per mode in game).
	name = name if name.endswith("_Glow") else name + "_Glow"
	ob = add_obj(name, bm, [glow], col, smooth_angle=0)
	ob["glow"] = True
	ob.visible_shadow = False
	return ob


def place_instance(kit_col, matrix, name, col):
	# Places a kit piece the way the game will: a collection-instance empty of its Lobby_<Piece> collection (the
	# meshes stay shared, like MeshParts sharing a MeshId). matrix: the piece's world transform (rot_z / facing).
	ob = bpy.data.objects.new(name, None)
	ob.instance_type = "COLLECTION"
	ob.instance_collection = kit_col
	ob.empty_display_size = 1.0
	ob.matrix_world = matrix
	col.objects.link(ob)
	return ob


def seg_matrix(b):
	# World transform of a round kit segment that starts at bearing b (masters are built at bearing 0..11.25).
	return Matrix.Rotation(-math.radians(b), 4, "Z")


def tri_count(col):
	# Triangles of every mesh object in a collection and its children (text stand-ins are curves and not counted).
	n = 0
	for ob in col.all_objects:
		if ob.type == "MESH":
			ob.data.calc_loop_triangles()
			n += len(ob.data.loop_triangles)
	return n


def text(body, size, loc, col, mat, rot=(0, 0, 0), align="CENTER", font=FONT_HEAVY, extrude=0.0, spacing=1.0, name=None):
	# SurfaceGui text stand-in (preview only). rot in degrees; the text lies in its local XY plane facing +Z.
	cu = bpy.data.curves.new(name or ("Text_" + body[:12]), "FONT")
	cu.body = body
	cu.size = size
	cu.align_x = align
	cu.align_y = "CENTER"
	cu.extrude = extrude
	cu.space_character = spacing
	if os.path.exists(font):
		cu.font = bpy.data.fonts.load(font, check_existing=True)
	cu.materials.append(mat)
	ob = bpy.data.objects.new(cu.name, cu)
	ob.location = loc
	ob.rotation_euler = tuple(math.radians(a) for a in rot)
	ob["preview_only"] = True
	ob.visible_shadow = False
	col.objects.link(ob)
	return ob


# ---------------------------------------------------------------- trims (kit space: back at x = 0, facing +X)
# Each returns {part: (bmesh, material name)}; build() turns that into objects. Glow parts end in "_Glow".

def trim_plinth_gap(length, wall_t=1.0, plinth_h=1.5, gap_h=0.6, gap_d=0.5, glow="Glow_Cove"):
	# Plinth 1.5 tall set 0.25 in from the wall face, then the 0.6 x 0.5 glowing shadow gap where the finished
	# work meets the rock above (the rock's foot sits on z = plinth_h + gap_h). Brushed-steel nosing on the plinth.
	f = wall_t
	h0, h1 = plinth_h, plinth_h + gap_h
	return {
		"Plinth": (cbox(0, f - 0.25, -length / 2, length / 2, 0, h0, ch=0.12), "ConcreteBoard"),
		"PlinthNosing": (box(f - 0.27, f - 0.2, -length / 2, length / 2, h0 - 0.12, h0), "SteelBrushed"),
		"GapLiner": (box(0, f - gap_d, -length / 2, length / 2, h0, h1), "SteelBlack"),
		# Neon tucked into the top back corner of the slot, so from standing height it reads as a lit slot.
		"Gap_Glow": (glow_strip(f - gap_d, f - gap_d + 0.08, -length / 2, length / 2, h1 - 0.16, h1 - 0.04), glow),
	}


def trim_portal_corner(height=16.0, span=10.0, thick=3.0, deep=6.0, ch=0.25, band_h=4.0, edge_glow="Glow_DuelsRed"):
	# Corner of a deep board-formed portal frame (3 thick x 6 deep, 0.25 chamfers): the left jamb (seen from the
	# room) and `span` of the lintel above an opening `height` tall, with a charcoal title band on the lintel face
	# and an optional red edge strip down the inside of the jamb (Duels). Kit space: frame front face at x = deep.
	jamb = cbox(0, deep, -thick / 2, thick / 2, 0, height + thick, ch=ch)
	lintel = cbox(0, deep, -thick / 2 + 0.01, span, height, height + thick, ch=ch)
	band = cbox(deep - 0.1, deep + 0.15, thick / 2 + 0.5, span - 0.5, height + 0.3, height + thick - 0.3, ch=0.05)
	parts = {
		"Frame": (group(jamb, lintel), "ConcreteBoard"),
		"TitleBand": (band, "SignPanel"),
	}
	if edge_glow:
		parts["Edge_Glow"] = (glow_strip(deep - 0.55, deep - 0.3, thick / 2, thick / 2 + 0.08, 0.3, height - 0.3), edge_glow)
	return parts


def trim_sign_frame(w=14.0, h=7.0, edge=0.4, strip=0.3, mode_glow="Glow_1v1"):
	# Sign frame: 0.4 black-steel edge around a charcoal panel, with a 0.3 mode-colour strip along the bottom
	# inside the frame. Kit space, centred on y, bottom at z = 0, back at x = 0. Text goes on x = 0.5.
	frame = bmesh.new()
	merge(frame, cbox(0, 0.6, -w / 2, w / 2, h - edge, h, ch=0.1))
	merge(frame, cbox(0, 0.6, -w / 2, w / 2, 0, edge, ch=0.1))
	merge(frame, cbox(0, 0.6, -w / 2, -w / 2 + edge, edge - 0.05, h - edge + 0.05, ch=0.1))
	merge(frame, cbox(0, 0.6, w / 2 - edge, w / 2, edge - 0.05, h - edge + 0.05, ch=0.1))
	panel = box(0, 0.45, -w / 2 + edge, w / 2 - edge, edge + strip, h - edge)
	return {
		"Frame": (frame, "SteelBlack"),
		"Panel": (panel, "SignPanel"),
		"Strip_Glow": (glow_strip(0.2, 0.42, -w / 2 + edge, w / 2 - edge, edge, edge + strip), mode_glow),
	}


def trim_pad(w=13.0, d=13.0, deck_h=0.5, ring=1.0, mode_glow="Glow_1v1"):
	# Queue pad (prop space: centred, on the floor): a light deck at +0.5 inside a 1-wide ring channel. The channel
	# is brushed steel; its Neon sits 0.1 below the deck between 0.2 steel lips.
	hw, hd = w / 2, d / 2
	base = cbox(-hw, hw, -hd, hd, 0, deck_h - 0.25, ch=0.1)
	deck = cbox(-hw + ring, hw - ring, -hd + ring, hd - ring, 0, deck_h, ch=0.08)
	lips = bmesh.new()
	for o in (0.0, ring - 0.2):  # outer and inner lip, each 0.2 wide, flush with the deck
		a, b2 = hw - o, hd - o
		merge(lips, box(-a, a, b2 - 0.2, b2, 0, deck_h))
		merge(lips, box(-a, a, -b2, -b2 + 0.2, 0, deck_h))
		merge(lips, box(a - 0.2, a, -b2 + 0.2, b2 - 0.2, 0, deck_h))
		merge(lips, box(-a, -a + 0.2, -b2 + 0.2, b2 - 0.2, 0, deck_h))
	ring_bm = bmesh.new()
	a, b2, t = hw - 0.2, hd - 0.2, ring - 0.4
	ztop = deck_h - 0.1
	merge(ring_bm, box(-a, a, b2 - t, b2, 0, ztop))
	merge(ring_bm, box(-a, a, -b2, -b2 + t, 0, ztop))
	merge(ring_bm, box(a - t, a, -b2 + t, b2 - t, 0, ztop))
	merge(ring_bm, box(-a, -a + t, -b2 + t, b2 - t, 0, ztop))
	return {
		"Base": (base, "SteelBrushed"),
		"Deck": (deck, "ConcretePolished"),
		"Channel": (lips, "SteelBrushed"),
		"Ring_Glow": (ring_bm, mode_glow),
	}


def cove_hide_distance(lip, strip_h, setback, rise):
	# "Never show the source": for a strip `strip_h` tall sitting `setback` behind a lip that stands `lip` beyond the
	# strip's mounting face, seen by an eye `rise` studs short of the lip's edge (eye 5 below a pelmet's bottom edge,
	# or 5 above an uplight lip's top edge), returns the nearest horizontal distance from which the strip is hidden.
	# An uplight cove seen from below (rise < 0) is hidden from everywhere when strip_h < lip.
	if strip_h >= lip:
		return float("inf")
	if rise <= 0:
		return 0.0
	return setback * rise / (lip - strip_h)


def trim_cove(length, lip=0.6, shelf=1.0, up=True, strip_h=0.15, glow="Glow_Cove", lip_t=0.15):
	# CoveLight housing (the "never show the source" trim): Neon behind a black-steel lip (pelmet). Kit space: the
	# mounting wall at x = 0 facing +X, width along Y centred, the mounting line at z = 0.
	#   up=True  uplight cove on a shelf: the shelf (0.3 thick, top at z = 0) projects `shelf`, the lip stands `lip`
	#            on its front edge, the strip lies on the shelf tight behind the lip (strip_h < lip, so no eye below the
	#            shelf ever sees it). Wash: rbx_light("SurfaceLight", Face Top) on the strip.
	#   up=False downlight pelmet under a soffit at z = 0: the lip hangs `lip` below the soffit at x = shelf and the
	#            strip sits on the soffit 0.1 behind it; cove_hide_distance(lip, strip_h, 0.1, rise) gives the nearest
	#            distance it stays hidden from. Wash: rbx_light("SurfaceLight", Face Bottom) on the strip.
	# Returns {part: (bmesh, material name)} for build(); the glow part is "Cove_Glow".
	hw = length / 2
	if up:
		return {
			"Shelf": (cbox(0.0, shelf, -hw, hw, -0.3, 0.0, ch=0.04), "SteelBlack"),
			"Lip": (cbox(shelf - lip_t, shelf, -hw, hw, 0.0, lip, ch=0.03), "SteelBlack"),
			"Cove_Glow": (glow_strip(shelf - lip_t - 0.35, shelf - lip_t - 0.05, -hw + 0.1, hw - 0.1, 0.0, strip_h), glow),
		}
	return {
		"Lip": (cbox(shelf - lip_t, shelf, -hw, hw, -lip, 0.0, ch=0.03), "SteelBlack"),
		"Cove_Glow": (glow_strip(shelf - lip_t - 0.4, shelf - lip_t - 0.1, -hw + 0.1, hw - 0.1, -strip_h, 0.0), glow),
	}


def avatar(loc, facing=0.0, col=None, name="Avatar"):
	# Scale mannequin (preview only): a 5.2-stud R15 block avatar (2-wide torso, 2-tall legs, 1.2 head) in Roblox's
	# neutral #A3A2A5. loc = the point between its feet on the floor; facing = Blender heading in degrees (0 = +X, the
	# kit convention), the way it looks. Put one in every preview so trims and props carry their scale.
	mat = bpy.data.materials.get("Mannequin")
	parts = [
		cbox(-0.5, 0.5, -0.98, -0.02, 0.0, 2.0, ch=0.05),  # legs
		cbox(-0.5, 0.5, 0.02, 0.98, 0.0, 2.0, ch=0.05),
		cbox(-0.5, 0.5, -1.0, 1.0, 2.0, 2.4, ch=0.05),  # lower torso
		cbox(-0.5, 0.5, -1.0, 1.0, 2.42, 4.0, ch=0.08),  # upper torso
		cbox(-0.45, 0.45, -2.0, -1.04, 2.05, 4.0, ch=0.06),  # arms
		cbox(-0.45, 0.45, 1.04, 2.0, 2.05, 4.0, ch=0.06),
		cbox(-0.6, 0.6, -0.6, 0.6, 4.05, 5.2, ch=0.18),  # head
	]
	bm = group(*parts)
	place(bm, Matrix.Translation(Vector(loc)) @ Matrix.Rotation(math.radians(facing), 4, "Z"))
	ob = add_obj(name, bm, [mat] if mat else [], col or collection("Stage"), smooth_angle=0, uvs=None)
	ob["preview_only"] = True
	return ob


def build(prefix, parts, mats, col, matrix=None, uv_rotate=()):
	# Turns {part: (bmesh, material name)} into objects <prefix>_<part>, optionally placed by `matrix` first (so
	# box UVs follow world positions and grids continue across pieces). Returns {part: object}.
	out = {}
	for part, (bm, mname) in parts.items():
		if matrix is not None:
			place(bm, matrix)
		name = "%s_%s" % (prefix, part)
		if part.endswith("_Glow"):
			out[part] = add_glow(name, bm, mats[mname], col)
		else:
			out[part] = add_obj(name, bm, [mats[mname]], col, uv_rotate=part in uv_rotate)
	return out


# ---------------------------------------------------------------- stage

def begin():
	# Fresh empty file: the build script is the source of truth for the .blend.
	bpy.ops.wm.read_homefile(use_empty=True)
	return make_materials()


ZONES = {
	# kind: world ambient colour/strength, sun strength (0 = no sun), key light colour, key/fill energy per 100 studs^2
	"rotunda": dict(ambient=AMBIENT, ambient_strength=1.6, sun=7.0, key=L_COVE, key_energy=3.5, fill=OUTDOOR_AMBIENT, fill_energy=1.8),
	"duels": dict(ambient=0x0B0D12, ambient_strength=0.5, sun=0.0, key=L_DUELS, key_energy=2.5, fill=0x1A2230, fill_energy=0.6),
	"market": dict(ambient=0x241E18, ambient_strength=1.0, sun=0.0, key=L_MARKET, key_energy=4.0, fill=0x3A3028, fill_energy=1.5),
	"weapons": dict(ambient=AMBIENT, ambient_strength=0.9, sun=0.0, key=L_WEAPONS, key_energy=4.0, fill=OUTDOOR_AMBIENT, fill_energy=1.4),
	"range": dict(ambient=0x2A3038, ambient_strength=1.4, sun=0.0, key=L_RANGE, key_energy=6.0, fill=0x4A5260, fill_energy=2.4),
}


def _look(o, target):
	o.rotation_euler = (Vector(target) - o.location).to_track_quat("-Z", "Y").to_euler()


def light(kind, name, loc, energy, color, target=None, size=1.0, size_y=None, spot=None, blend=0.4, shadow=True, col=None):
	# kind: AREA / SPOT / POINT / SUN. colour as hex. target: point the light at it.
	ld = bpy.data.lights.new(name, kind)
	ld.energy = energy
	ld.color = lin(color)
	try:
		ld.use_shadow = shadow
	except AttributeError:
		pass
	if kind == "AREA":
		ld.shape = "RECTANGLE"
		ld.size = size
		ld.size_y = size_y if size_y is not None else size
	elif kind == "SPOT":
		ld.spot_size = math.radians(spot or 45)
		ld.spot_blend = blend
		ld.shadow_soft_size = size
	elif kind == "POINT":
		ld.shadow_soft_size = size
	ob = bpy.data.objects.new(name, ld)
	(col or collection("Stage")).objects.link(ob)
	ob.location = loc
	if target is not None:
		_look(ob, target)
	return ob


LIGHTS = []  # every rbx_light() made in this file: the per-render dynamic light budget


def rbx_light(rbx_class, name, loc, energy, color, zone="hub", face=None, rbx_range=None, angle=None, **kw):
	# A light that WILL exist in Roblox (shadowless), so every wash a preview relies on is named and counted.
	# rbx_class: "SurfaceLight" | "SpotLight" | "PointLight". face / rbx_range / angle: the Roblox settings to use.
	# kw goes to light() (kind is AREA for SurfaceLight, SPOT for SpotLight, POINT for PointLight unless given).
	kind = kw.pop("kind", {"SurfaceLight": "AREA", "SpotLight": "SPOT", "PointLight": "POINT"}[rbx_class])
	ob = light(kind, name, loc, energy, color, shadow=False, **kw)
	ob["rbx_light"] = rbx_class
	ob["rbx_zone"] = zone
	ob["rbx_shadows"] = False
	if face:
		ob["rbx_face"] = face
	if rbx_range:
		ob["rbx_range"] = rbx_range
	if angle:
		ob["rbx_angle"] = angle
	LIGHTS.append(ob)
	return ob


def light_budget(prefix="LIGHTS"):
	# Prints and returns {(zone, class): count} for every rbx_light() made in this file (the Art Plan budget check).
	out = {}
	for ob in LIGHTS:
		k = (ob["rbx_zone"], ob["rbx_light"])
		out[k] = out.get(k, 0) + 1
	for (zone, cls), n in sorted(out.items()):
		print("%s %-10s %-13s %3d" % (prefix, zone, cls, n))
	print("%s total %d dynamic lights (all shadowless)" % (prefix, len(LIGHTS)))
	return out


def sun_direction():
	# Plan: sun due south at about 80 degrees up; Roblox sun vector (0, 0.985, 0.174) -> Blender (0, -0.174, 0.985)
	# (towards the sun). Light travels the other way: down and 10 degrees north, toward Duels.
	return Vector((0.0, 0.174, -0.985)).normalized()


def _world_nodes(w, z):
	# The camera sees a near-black background; lighting and reflections see a soft gradient (dark floor bounce,
	# the zone's ambient at the horizon, its brighter fill colour on top), standing in for Roblox's Ambient /
	# OutdoorAmbient and environment specular. Light Path "Is Camera Ray" splits the two.
	w.use_nodes = True
	nt = w.node_tree
	nt.nodes.clear()
	out = nt.nodes.new("ShaderNodeOutputWorld")
	g = Graph.__new__(Graph)
	g.nt, g.L, g._uv, g._obj = nt, nt.links, None, None
	tc = g.node("ShaderNodeTexCoord")
	dz = g.sep(tc.outputs["Generated"])[2]
	amb = lin(z["ambient"])
	top = lin(z["fill"])
	low = tuple(c * 0.35 for c in amb)
	env = g.mix(g.smooth(-0.2, 0.15, dz), (*low, 1), (*amb, 1))
	env = g.mix(g.smooth(0.15, 0.9, dz), env, (*top, 1))
	bg_light = g.node("ShaderNodeBackground")
	g.set(bg_light.inputs[0], env)
	bg_light.inputs[1].default_value = z["ambient_strength"]
	bg_cam = g.node("ShaderNodeBackground")
	bg_cam.inputs[0].default_value = (*tuple(c * 0.5 for c in amb), 1)
	bg_cam.inputs[1].default_value = 1.0
	lp = g.node("ShaderNodeLightPath")
	mixs = g.node("ShaderNodeMixShader")
	g.L.new(lp.outputs["Is Camera Ray"], mixs.inputs[0])
	g.L.new(bg_light.outputs[0], mixs.inputs[1])
	g.L.new(bg_cam.outputs[0], mixs.inputs[2])
	g.L.new(mixs.outputs[0], out.inputs["Surface"])


def lobby_world(kind="rotunda", center=(0, 0, 0), radius=30.0, sun=None):
	# World ambient + sun + the zone's key/fill preset, all in a "Stage" collection. center/radius size the key and
	# fill (the key hangs over the centre like the zone's one dynamic light; the fill is a big soft panel behind the
	# camera side standing in for Roblox ambient/environment light). Returns {"sun", "key", "fill"}.
	z = ZONES[kind]
	sc = bpy.context.scene
	stage = collection("Stage")
	w = sc.world or bpy.data.worlds.new("World")
	sc.world = w
	_world_nodes(w, z)
	c = Vector(center)
	out = {}
	s = z["sun"] if sun is None else sun
	if s > 0:
		ld = bpy.data.lights.new("Sun", "SUN")
		ld.energy = s
		ld.color = lin(L_SUN)
		ld.angle = math.radians(0.6)  # crisp disc edge, like the knife-edge skylight rim
		ob = bpy.data.objects.new("Sun", ld)
		stage.objects.link(ob)
		ob.rotation_euler = (math.radians(10), 0, 0)  # local -Z = sun_direction()
		out["sun"] = ob
	area = radius * radius / 100.0
	out["key"] = light("AREA", "Key", c + Vector((0, -radius * 0.2, radius * 1.1)), z["key_energy"] * area * 100, z["key"], c, size=radius * 0.8, shadow=False, col=stage)
	out["fill"] = light("AREA", "Fill", c + Vector((0, -radius * 1.6, radius * 0.7)), z["fill_energy"] * area * 100, z["fill"], c, size=radius * 1.5, shadow=False, col=stage)
	render_settings()
	return out


def sun_occluder(hole_center, hole_r, z=60.0, outer=400.0, col=None, spokes=0, spoke_w=0.3):
	# Invisible-to-camera roof with a round skylight hole (and optional spokes) so the sun only lands as one patch,
	# like the oculus does. hole_center: (x, y) of the hole in plan. It still casts shadows.
	bm = arc(hole_r, outer, 0, 360, z, z + 0.5, steps=96)
	for i in range(spokes):
		b = 22.5 + 45.0 * i
		bm2 = box(-spoke_w / 2, spoke_w / 2, 0, hole_r + 0.5, z, z + 0.5)
		place(bm2, Matrix.Rotation(-math.radians(b), 4, "Z"))
		merge(bm, bm2)
	place(bm, Matrix.Translation((hole_center[0], hole_center[1], 0)))
	ob = add_obj("SunOccluder", bm, [], col or collection("Stage"), uvs=None)
	ob.visible_camera = False
	ob.visible_glossy = False
	ob["preview_only"] = True
	return ob


def hole_for_patch(patch, z=60.0):
	# Where the skylight hole must sit (x, y at height z) for the sun patch to land at `patch` (x, y, z).
	d = sun_direction()
	t = (z - patch[2]) / -d.z
	return (patch[0] - d.x * t, patch[1] - d.y * t)


def sun_beam(top, bottom, r_top, r_bottom, mat, col, planes=4, name="SunBeam", phase=0.0):
	# Fake god rays the Roblox way: a few crossed transparent ribbons (Beams) from the rim to the floor patch.
	# UV: U across a ribbon, V from the top (0) to the floor (1); the Beam_Sun material fades both ends and edges.
	# phase (degrees) turns the set about the beam axis (so a second, wider set can sit between the first).
	top, bottom = Vector(top), Vector(bottom)
	axis = (bottom - top).normalized()
	ref = Vector((1, 0, 0)) if abs(axis.x) < 0.9 else Vector((0, 1, 0))
	bm = bmesh.new()
	layer = bm.loops.layers.uv.verify()
	for i in range(planes):
		a = math.pi * i / planes + math.radians(phase)
		side = (ref.cross(axis)).normalized()
		side = (Matrix.Rotation(a, 3, axis) @ side).normalized()
		vs = [bm.verts.new(top - side * r_top), bm.verts.new(top + side * r_top), bm.verts.new(bottom + side * r_bottom), bm.verts.new(bottom - side * r_bottom)]
		f = bm.faces.new(vs)
		for lp, uv in zip(f.loops, ((0, 0), (1, 0), (1, 1), (0, 1))):
			lp[layer].uv = uv
	ob = add_obj(name, bm, [mat], col, smooth_angle=0, uvs="keep")
	ob.visible_shadow = False
	ob["preview_only"] = True
	return ob


def camera(loc, target, lens=35.0, name="Cam", col=None, shift=(0.0, 0.0)):
	cd = bpy.data.cameras.new(name)
	cd.lens = lens
	cd.shift_x, cd.shift_y = shift
	cd.clip_end = 2000
	ob = bpy.data.objects.new(name, cd)
	(col or collection("Stage")).objects.link(ob)
	ob.location = loc
	_look(ob, target)
	bpy.context.scene.camera = ob
	return ob


def bloom(strength=0.5, size=0.6, threshold=1.2):
	# modkit's compositor bloom (Glare node, Bloom type) on the render layer.
	# RENDER POLICY for every kit render (so the board reads as one family): render_settings() defaults (AgX Medium
	# High Contrast), bloom threshold 1.2 (about Roblox Bloom), exposure 0. Close-up sheets light the subject with a
	# preview fill key instead of raising exposure.
	sc = bpy.context.scene
	ng = bpy.data.node_groups.get("Bloom") or bpy.data.node_groups.new("Bloom", "CompositorNodeTree")
	ng.nodes.clear()
	if not ng.interface.items_tree:
		ng.interface.new_socket("Image", in_out="OUTPUT", socket_type="NodeSocketColor")
	rl = ng.nodes.new("CompositorNodeRLayers")
	gl = ng.nodes.new("CompositorNodeGlare")
	for v in ("Bloom", "BLOOM"):
		try:
			gl.inputs["Type"].default_value = v
			break
		except Exception:
			pass
	try:
		gl.inputs["Quality"].default_value = "High"
	except Exception:
		pass
	gl.inputs["Threshold"].default_value = threshold
	gl.inputs["Strength"].default_value = strength
	gl.inputs["Size"].default_value = size
	go = ng.nodes.new("NodeGroupOutput")
	ng.links.new(rl.outputs["Image"], gl.inputs["Image"])
	ng.links.new(gl.outputs[0], go.inputs[0])
	sc.compositing_node_group = ng
	sc.render.use_compositing = True


def render_settings(samples=96, view="AgX", look="AgX - Medium High Contrast", exposure=0.0):
	sc = bpy.context.scene
	sc.render.engine = "BLENDER_EEVEE"
	sc.eevee.taa_render_samples = samples
	sc.eevee.use_raytracing = True
	for k, v in (("ray_tracing_method", "SCREEN"), ("use_fast_gi", True), ("fast_gi_method", "GLOBAL_ILLUMINATION"), ("use_shadows", True), ("shadow_ray_count", 2), ("shadow_step_count", 8)):
		try:
			setattr(sc.eevee, k, v)
		except (AttributeError, TypeError):
			pass
	try:
		sc.eevee.ray_tracing_options.resolution_scale = "1"
	except (AttributeError, TypeError):
		pass
	sc.view_settings.view_transform = view
	try:
		sc.view_settings.look = look
	except TypeError:
		sc.view_settings.look = "None"
	sc.view_settings.exposure = exposure


def render(path, res=(1600, 1000)):
	sc = bpy.context.scene
	sc.render.resolution_x, sc.render.resolution_y = res
	sc.render.resolution_percentage = 100
	sc.render.image_settings.file_format = "JPEG"
	sc.render.image_settings.quality = 92
	sc.render.filepath = path
	os.makedirs(os.path.dirname(path), exist_ok=True)
	bpy.ops.render.render(write_still=True)
	return path


def save(name):
	path = os.path.join(ART_DIR, name + ".blend")
	os.makedirs(ART_DIR, exist_ok=True)
	bpy.ops.wm.save_as_mainfile(filepath=path)
	return path
