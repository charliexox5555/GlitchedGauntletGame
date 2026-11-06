# build_map_kit_greenhouse2.py: the Greenhouse2 match map kit (vault/01 Design/Maps/Greenhouse2.md), forked from
# build_map_kit_greenhouse.py and brought to the Map Quality Standard (no Metal on painted iron, the palette table,
# arched bays with spandrels and finials, a three-tier fountain, a cast-iron sectional boiler with copper pipework,
# slatted crates, banded flower tubs). The layout and every piece origin are Greenhouse's (the contract below).
#
# Every piece is a collection Map_<Piece> built at the world origin; objects are <Piece>_<Material>, one per material
# (each becomes one MeshPart). 1 Blender unit = 1 stud; Blender +X = Roblox +X, Blender +Y = Roblox -Z, +Z up
# (kit_bundle.py turns Blender (x, y, z) into Roblox (x, z, -y)). tools/maps/greenhouse_art.py places the pieces from
# the layout's own numbers, so these origins are the contract:
#   Walls (GlassWall16/8/4/2, GlassDoor8, StuccoWall16/8/4/2, StuccoDoor8): on the floor at the middle of the wall's
#     centreline, running along Y, 2 thick (x -1..1, the greybox wall), 40 tall, the same seen from both sides. Nothing
#     stands proud of x = +-1, so runs meet at corners and T-junctions without overlapping faces. Doors: an 8 x 10
#     opening over the whole piece width (the neighbours' half-ribs or pilasters frame it).
#   RoofSpan48/32: on the floor below the middle of an 8-deep roof bay (the glazing starts at z 40, the roof plane), spanning X.
#   Dome, Fountain, Bridge: at the Dome's centre on the floor. Gallery: at the middle of the east gallery's footprint
#     (x -6..6 here = map x 28..40), front edge at -X. IronStair: at the stair foot's middle, climbing toward +X
#     (18 long, 12 high, 8 wide).
#   Props and beds: on the floor at the middle of the collision block they dress, X = the block's first size.
# Materials are Roblox materials (rbx_material + rbx_color). Parts named *_Accent are tinted per end by Art.luau;
# *_Glass and *_Water cast no shadow.
#
# Run (headless):
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup \
#       --python tools/blender/build_map_kit_greenhouse.py -- [--no-render] [--samples N]
# Writes art-source/maps/Greenhouse/Kit_Greenhouse.blend and the contact sheet
# vault/02 Art/References/maps/greenhouse/greenhouse-kit-sheet.jpg, prints GREENHOUSE_TRIS and the two groups.

import json, math, os, random, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy, bmesh  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402
import lobbykit as K  # noqa: E402
from gunkit import prism, box, merge, ring_pts  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ROOT = K.ROOT
OUT_DIR = os.path.join(ROOT, "art-source", "maps", "Greenhouse2")
REF_DIR = os.path.join(ROOT, "vault", "02 Art", "References", "maps", "greenhouse2")
PLAN = os.path.join(ROOT, "art-source", "maps", "Greenhouse", "plan.json")

HALL = 40.0
DOOR_H = 10.0
GAL = 12.0
TAN = math.tan(math.radians(22.5))
COS = math.cos(math.radians(22.5))

# ---------------------------------------------------------------- palette (Greenhouse.md -> Look)
C_IRON = 0xEDEDE4
C_FROST = 0x9DBDB2  # Greenhouse2 r3: a deeper sea-green, the white iron reads against it (r2: flat pale walls)
C_ROOFGLASS = 0xCFE6EA
C_BRICK = 0x9C5B44
C_STONE = 0xD9D0BE
C_STUCCO = 0xEDE4D0
C_SOIL = 0x4A3A2C
C_PALM = 0x5E8F3A
C_FERN = 0x4C8A3E
C_DEEP = 0x2F6B35
C_LIME = 0x9BC24E
C_TRUNK = 0x7A6450
C_TIMBER = 0x8C6A48
C_POT = 0xC0673F
C_WATER = 0x5FB0B8
C_GILT = 0xC9A24B
C_ROCK = 0xA39A88
C_ACCENT = 0x3A6FC4
C_MARBLE = 0xE9E6DE
C_HEDGE = 0x3F6E35
C_FRUIT = 0xE88A2A
C_BOILER = 0x5A5F64
C_COPPER = 0xB07650
C_BLOOM = 0xEEEDE6
C_SLATE = 0x6F7A86
C_CRATE = 0xA98557
C_SACK = 0xC8B48A
C_POOL = 0x2E5A5C
C_PAD = 0x6E9E3A


def _mat(name, rbx, color, rough=0.85, var=0.05, scale=0.5, bump=0.1, metallic=0.0, **extra):
	m, g, b = K._base(name, rbx, "", color, **extra)
	p = g.obj()
	n = g.noise(p, scale, 3.0)
	g.set(b.inputs["Base Color"], g.col(color, g.remap(n, 0.3, 0.7, 1 - var, 1 + var)))
	b.inputs["Roughness"].default_value = rough
	b.inputs["Metallic"].default_value = metallic
	if bump:
		g.set(b.inputs["Normal"], g.bump(g.noise(p, scale * 8, 4.0), bump, 0.05))
	return m


def _clear(name, color, alpha, transparency):
	m, g, b = K._base(name, "SmoothPlastic", "", color, rbx_transparency=transparency)
	m.surface_render_method = "BLENDED"
	m.use_backface_culling = False
	b.inputs["Base Color"].default_value = (*K.lin(color), 1)
	b.inputs["Roughness"].default_value = 0.05
	b.inputs["Alpha"].default_value = alpha
	return m


def make_materials():
	mats = {}
	for m in [
		_mat("Iron", "SmoothPlastic", C_IRON, 0.45, 0.02, 1.0, 0.02),  # standard: no Metal on paint
		_mat("Frost", "SmoothPlastic", C_FROST, 0.35, 0.03, 0.2, 0.0),
		_mat("Brick", "Brick", C_BRICK, 0.9, 0.08, 1.2, 0.2),
		_mat("Stone", "Limestone", C_STONE, 0.85, 0.05, 0.8, 0.12),
		_mat("Stucco", "Plaster", C_STUCCO, 0.92, 0.03, 0.4, 0.08),
		_mat("Soil", "Ground", C_SOIL, 0.95, 0.1, 1.0, 0.2),
		_mat("Palm", "SmoothPlastic", C_PALM, 0.7, 0.1, 0.8, 0.0),
		_mat("Fern", "SmoothPlastic", C_FERN, 0.7, 0.1, 0.8, 0.0),
		_mat("Deep", "SmoothPlastic", C_DEEP, 0.7, 0.1, 0.8, 0.0),
		_mat("Lime", "SmoothPlastic", C_LIME, 0.7, 0.1, 0.8, 0.0),
		_mat("Trunk", "Wood", C_TRUNK, 0.9, 0.1, 1.5, 0.2),
		_mat("Timber", "Wood", C_TIMBER, 0.8, 0.08, 1.2, 0.1),
		_mat("Pot", "Plastic", C_POT, 0.8, 0.06, 1.0, 0.05),
		_mat("Gilt", "SmoothPlastic", C_GILT, 0.35, 0.03, 1.0, 0.0),
		_mat("Rock", "Slate", C_ROCK, 0.9, 0.12, 0.7, 0.25),
		_mat("Accent", "Wood", C_ACCENT, 0.6, 0.04, 1.0, 0.05),
		_mat("Marble", "Marble", C_MARBLE, 0.4, 0.04, 0.6, 0.05),
		_mat("Hedge", "LeafyGrass", C_HEDGE, 0.9, 0.12, 1.2, 0.3),
		_mat("Fruit", "SmoothPlastic", C_FRUIT, 0.5, 0.08, 2.0, 0.0),
		_mat("Boiler", "SmoothPlastic", C_BOILER, 0.6, 0.05, 1.0, 0.05),
		_mat("Copper", "SmoothPlastic", C_COPPER, 0.5, 0.06, 1.0, 0.0),
		_mat("Bloom", "SmoothPlastic", C_BLOOM, 0.7, 0.06, 2.0, 0.0),
		_mat("Slate", "Slate", C_SLATE, 0.85, 0.06, 1.0, 0.1),
		_mat("Crate", "Wood", C_CRATE, 0.85, 0.08, 1.2, 0.1),
		_mat("Sack", "Fabric", C_SACK, 0.95, 0.08, 1.5, 0.15),
		_mat("Pool", "SmoothPlastic", C_POOL, 0.6, 0.05, 0.6, 0.0),
		_mat("Pad", "SmoothPlastic", C_PAD, 0.7, 0.08, 1.0, 0.0),
	]:
		mats[m.name] = m
	mats["Glass"] = _clear("Glass", C_ROOFGLASS, 0.32, 0.55)
	mats["Water"] = _clear("Water", C_WATER, 0.55, 0.35)
	mats["Mannequin"] = K._flat("Mannequin", 0xA3A2A5, 0.62, preview_only=True)
	mats["SignText"] = K._emissive("SignText", 0xF4F4F2, 1.6, rbx="SurfaceGui", preview_only=True)
	return mats


# ---------------------------------------------------------------- geometry helpers

def B(x0, x1, y0, y1, z0, z1):
	return box(min(x0, x1), max(x0, x1), min(y0, y1), max(y0, y1), min(z0, z1), max(z0, z1))


def tf(bm, m):
	return K.place(bm, m)


def mv(bm, x=0.0, y=0.0, z=0.0):
	return K.place(bm, Matrix.Translation((x, y, z)))


def rz(bm, deg, x=0.0, y=0.0, z=0.0):
	return K.place(bm, Matrix.Translation((x, y, z)) @ Matrix.Rotation(math.radians(deg), 4, "Z"))


def vcyl(x, y, r, z0, z1, segs=10):
	return K.cyl(x, y, r, z0, z1, segs=segs)


def xprism(pts, x0, x1):
	return prism(pts, "X", x0, x1)  # profile (y, z)


def lathe(profile, segs=16, x=0.0, y=0.0):
	bm = K.lathe(profile, steps=segs)
	return mv(bm, x, y)


def beam(p0, p1, w, h, up=(0, 0, 1)):
	# A w x h box from p0 to p1 (its h side along `up`, made orthogonal).
	p0, p1 = Vector(p0), Vector(p1)
	d = p1 - p0
	L = d.length
	X = d / L
	U = Vector(up)
	Z = (U - X * U.dot(X))
	if Z.length < 1e-6:
		Z = Vector((0, 0, 1)) if abs(X.z) < 0.9 else Vector((1, 0, 0))
		Z = Z - X * Z.dot(X)
	Z.normalize()
	Y = Z.cross(X)
	bm = box(0, L, -w / 2, w / 2, -h / 2, h / 2)
	m = Matrix(((X.x, Y.x, Z.x, p0.x), (X.y, Y.y, Z.y, p0.y), (X.z, Y.z, Z.z, p0.z), (0, 0, 0, 1)))
	return tf(bm, m)


def quad_slab(a, b, c, d, t):
	# A thin slab on the quad a-b-c-d (counter-clockwise seen from its outside), t thick toward the outside normal.
	a, b, c, d = (Vector(v) for v in (a, b, c, d))
	n = (b - a).cross(d - a).normalized()
	bm = bmesh.new()
	lo = [bm.verts.new(v) for v in (a, b, c, d)]
	hi = [bm.verts.new(v + n * t) for v in (a, b, c, d)]
	bm.faces.new(lo[::-1])
	bm.faces.new(hi)
	for i in range(4):
		j = (i + 1) % 4
		bm.faces.new((lo[i], lo[j], hi[j], hi[i]))
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	return bm


def rock_block(x0, x1, y0, y1, z0, z1, seed, cell=1.5, inset=0.45):
	# Faceted rockwork that fills a collision block from inside: a subdivided box whose vertices are pushed inward
	# (never out), flat-shaded so every triangle reads as a facet.
	rnd = random.Random(seed)
	bm = box(x0, x1, y0, y1, z0, z1)
	cuts = max(1, int(max(x1 - x0, y1 - y0, z1 - z0) / cell) - 1)
	bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=cuts, use_grid_fill=True)
	e = 1e-4
	for v in bm.verts:
		c = v.co
		on = [abs(c.x - x0) < e, abs(c.x - x1) < e, abs(c.y - y0) < e, abs(c.y - y1) < e, abs(c.z - z1) < e]
		k = rnd.uniform(0.15, 1.0) * inset
		if on[0]:
			c.x += k
		if on[1]:
			c.x -= k
		if on[2]:
			c.y += k
		if on[3]:
			c.y -= k
		if on[4]:
			c.z -= rnd.uniform(0.0, 0.6)
		if c.z > z0 + e and not on[4]:
			c.z += rnd.uniform(-0.2, 0.2) * (1 if c.z < z1 - 0.3 else 0)
	bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method="BEAUTY")
	return bm


def ribbon(spine, sides, widths, lifts, t=0.05):
	# A double-sided leaf/frond: per station a centre point, a side vector, a half width and a centre lift (V fold).
	bm = bmesh.new()
	top, bot = [], []
	for p, s, w, lf in zip(spine, sides, widths, lifts):
		p, s = Vector(p), Vector(s)
		row = [p - s * w, p + Vector((0, 0, lf)), p + s * w]
		top.append([bm.verts.new(v) for v in row])
		bot.append([bm.verts.new(v - Vector((0, 0, t))) for v in row])
	for i in range(len(spine) - 1):
		for j in range(2):
			a, b, c, d = top[i][j], top[i][j + 1], top[i + 1][j + 1], top[i + 1][j]
			if len({a, b, c, d}) == 4:
				bm.faces.new((a, b, c, d))
			a, b, c, d = bot[i][j], bot[i + 1][j], bot[i + 1][j + 1], bot[i][j + 1]
			if len({a, b, c, d}) == 4:
				bm.faces.new((a, b, c, d))
	bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-5)
	return bm


def frond(base, heading_deg, length, width, elev=35.0, droop=0.5, serrate=True, stations=9):
	# An arching blade from `base`: rises at `elev`, falls under `droop`; serrated edges suggest leaflets.
	h = math.radians(heading_deg)
	d = Vector((math.cos(h), math.sin(h), 0))
	s = Vector((-math.sin(h), math.cos(h), 0))
	spine, sides, widths, lifts = [], [], [], []
	for i in range(stations + 1):
		u = i / stations
		x = length * u
		z = math.tan(math.radians(elev)) * x * (1 - u) - droop * length * u * u
		spine.append(Vector(base) + d * x + Vector((0, 0, z)))
		sides.append(s)
		w = width * math.sin(math.pi * min(u * 1.15, 1.0)) ** 0.7
		if serrate and 0 < i < stations and i % 2:
			w *= 0.55
		widths.append(max(w, 0.02))
		lifts.append(w * 0.25)
	return ribbon(spine, sides, widths, lifts)


def fern_clump(x, y, z, n, length, width, seed, elev=40.0, droop=0.6):
	rnd = random.Random(seed)
	bm = bmesh.new()
	for i in range(n):
		hd = 360.0 * i / n + rnd.uniform(-15, 15)
		merge(bm, frond((x, y, z), hd, length * rnd.uniform(0.8, 1.1), width, elev + rnd.uniform(-8, 8), droop, stations=5 if length < 2.5 else 9))
	return bm


def canopy(x, y, z, sx, sy, sz, seed, points=24):
	return K.rock_chunk(seed, size=(sx, sy, sz), center=(x, y, z), points=points, jag=0.18)


class Acc:
	def __init__(self):
		self.d = {}

	def add(self, mat, *bms):
		for bm in bms:
			if mat in self.d:
				merge(self.d[mat], bm)
			else:
				self.d[mat] = bm
		return self


KIT = None
MATS = None
BUILT = []
FLAT = {"Rock", "Palm", "Fern", "Deep", "Lime", "Hedge", "Pad"}


def piece(name, acc):
	col = K.collection("Map_" + name, KIT)
	for mat, bm in acc.d.items():
		big = [f for f in bm.faces if len(f.verts) > 4]
		if big:
			bmesh.ops.triangulate(bm, faces=big, quad_method="BEAUTY", ngon_method="EAR_CLIP")
		ob = K.add_obj("%s_%s" % (name, mat), bm, [MATS[mat]], col, smooth_angle=0 if mat in FLAT else 30)
		ob.visible_shadow = mat not in ("Glass", "Water", "Frost")
	BUILT.append((name, col))
	return col


# ---------------------------------------------------------------- glass walls

def glass_bays(acc, W, door=False):
	# Bays of 8 (or one bay of W). Half-ribs at the piece edges, full ribs inside; frosted glass between.
	n = max(1, int(W // 8))
	bw = W / n
	y0 = -W / 2
	g0 = DOOR_H + 0.6 if door else 3.35
	for i in range(n):
		a, b = y0 + i * bw, y0 + (i + 1) * bw
		ga, gb = (a + 0.3 if not door else a), (b - 0.3 if not door else b)
		if not door:
			acc.add("Brick", B(-0.92, 0.92, a, b, 0, 3.0))
			acc.add("Stone", B(-0.98, 0.98, a, b, 3.0, 3.35))
		acc.add("Frost", B(-0.86, 0.86, ga, gb, g0, 39.6))
		# Glazing bars: mullions every 2 (both faces), transoms at 10 / 20 / 30 (both faces, a little prouder).
		k = 1
		while a + 2 * k < b - 0.5:
			yy = a + 2 * k
			if ga + 0.1 < yy < gb - 0.1:
				for sx in (1, -1):
					acc.add("Iron", B(sx * 0.86, sx * 0.94, yy - 0.1, yy + 0.1, g0, 39.6))
			k += 1
		for zt in (10.0, 20.0, 30.0):
			if zt > g0 + 0.5:
				for sx in (1, -1):
					acc.add("Iron", B(sx * 0.86, sx * 0.97, ga, gb, zt - 0.17, zt + 0.17))
	# Ribs: half at the edges (unless a door), full inside.
	for i in range(n + 1):
		yy = y0 + i * bw
		lo, hi = yy - 0.3, yy + 0.3
		if i == 0:
			if door:
				continue
			lo = yy
		if i == n:
			if door:
				continue
			hi = yy
		acc.add("Iron", B(-1.0, 1.0, lo, hi, 3.35 if not door else g0, 39.6))
	if not door:
		for i in range(n):
			a, b = y0 + i * bw + 0.3, y0 + (i + 1) * bw - 0.3
			yc, r = (a + b) / 2, (b - a) / 2
			if r < 1.2:
				continue
			outer = [(yc + r * math.cos(math.pi * t / 12), 10.17 + r * 0.7 * math.sin(math.pi * t / 12)) for t in range(13)]
			inner = [(yc + (r - 0.3) * math.cos(math.pi * t / 12), 10.17 + (r - 0.3) * 0.7 * math.sin(math.pi * t / 12)) for t in range(12, -1, -1)]
			for sx in (1, -1):
				x0, x1 = sorted((sx * 0.87, sx * 0.985))
				acc.add("Iron", xprism(outer + inner, x0, x1))
	# Greenhouse2: an arched head in the top panel of every bay (springing at the 30 transom), roundel bosses in its
	# spandrels, on both faces, all inside x +-1 (the wall contract).
	if not door:
		for i in range(n):
			a, b = y0 + i * bw + 0.3, y0 + (i + 1) * bw - 0.3
			yc, r = (a + b) / 2, (b - a) / 2
			if r < 1.2:
				continue
			outer = [(yc + r * math.cos(math.pi * t / 12), 30.12 + r * math.sin(math.pi * t / 12)) for t in range(13)]
			inner = [(yc + (r - 0.24) * math.cos(math.pi * t / 12), 30.12 + (r - 0.24) * math.sin(math.pi * t / 12)) for t in range(12, -1, -1)]
			for sx in (1, -1):
				x0, x1 = sorted((sx * 0.87, sx * 0.985))
				acc.add("Iron", xprism(outer + inner, x0, x1))
				for yb in (a + 0.75, b - 0.75):
					zb = 30.12 + r * 0.82
					if zb + 0.5 < 39.4:
						acc.add("Iron", prism(ring_pts(yb, zb, 0.42, 10), "X", *sorted((sx * 0.9, sx * 0.995))))  # inside x +-1 (walls meet without overlap)
	# Wall plate and cresting along the top.
	acc.add("Iron", B(-1.0, 1.0, -W / 2, W / 2, 39.6, 40.4))
	# Greenhouse2: a turned finial on every rib (each piece owns its start edge, so joints get exactly one)
	for i in range(n):
		yy = y0 + i * bw
		if door and i == 0:
			continue
		acc.add("Iron", lathe([(0.0, 40.4), (0.32, 40.42), (0.22, 40.9), (0.3, 41.3), (0.12, 41.55), (0.2, 41.8), (0.0, 42.2)], segs=10, y=yy))
	m = 0
	while -W / 2 + 0.5 + m <= W / 2 - 0.5 + 1e-6:
		yy = -W / 2 + 0.5 + m
		acc.add("Iron", xprism([(yy - 0.28, 40.4), (yy + 0.28, 40.4), (yy, 41.15)], -0.05, 0.05))
		m += 1.0
	acc.add("Iron", B(-0.1, 0.1, -W / 2, W / 2, 40.62, 40.72))
	if door:
		acc.add("Iron", B(-1.0, 1.0, -W / 2, W / 2, DOOR_H, DOOR_H + 0.6))
		acc.add("Stone", B(-1.0, 1.0, -W / 2, W / 2, 0, 0.1))
	return acc


def glass_wall(W):
	return glass_bays(Acc(), W)


def glass_door():
	return glass_bays(Acc(), 8.0, door=True)


# ---------------------------------------------------------------- stucco walls (the Orangery)

def arch_head(yc, r, zs, x0, x1, n=8):
	# The stucco spandrels over a round-headed opening (two prisms between the arch and its square).
	left = [(yc - r, zs + r), (yc, zs + r)] + [(yc + r * math.cos(a), zs + r * math.sin(a)) for a in [math.pi / 2 + (math.pi / 2) * k / n for k in range(1, n + 1)]]
	right = [(yc + r * math.cos(a), zs + r * math.sin(a)) for a in [(math.pi / 2) * k / n for k in range(0, n)]] + [(yc, zs + r), (yc + r, zs + r)]
	right = [(yc + r, zs)] + right[1:]
	bm = xprism(left, x0, x1)
	merge(bm, xprism([(yc + r, zs + r), (yc, zs + r)] + [(yc + r * math.cos(a), zs + r * math.sin(a)) for a in [math.pi / 2 - (math.pi / 2) * k / n for k in range(1, n + 1)]], x0, x1))
	return bm


def arch_glass(yc, r, zs, z0, x0, x1, n=8):
	pts = [(yc - r, z0), (yc + r, z0)] + [(yc + r * math.cos(a), zs + r * math.sin(a)) for a in [math.pi * k / n for k in range(0, n + 1)]]
	pts = pts[:2] + pts[2:]
	return xprism(pts, x0, x1)


def stucco_bay(acc, a, b, door=False, windows=True):
	# One bay from y=a to y=b: stone plinth, stucco, round-headed windows (lower 3.5..15, upper 24..34), stone string
	# course at 20, cornice and parapet with a cap. Everything flush within x +-1 (windows recessed).
	yc = (a + b) / 2
	w = b - a
	acc.add("Stone", B(-1.0, 1.0, a, b, 0, 1.2) if not door else bmesh.new())
	acc.add("Stone", B(-1.0, 1.0, a, b, 20.0, 20.6))
	acc.add("Stone", B(-1.0, 1.0, a, b, 37.4, 38.4))
	acc.add("Stone", B(-1.0, 1.0, a, b, 40.6, 41.0))
	# Parapet: stone with recessed panels between dies.
	acc.add("Stone", B(-0.7, 0.7, a + 0.5, b - 0.5, 38.4, 40.6))
	acc.add("Stone", B(-1.0, 1.0, a, a + 0.5, 38.4, 40.6), B(-1.0, 1.0, b - 0.5, b, 38.4, 40.6))
	wins = []
	if windows and w >= 8:
		wins = [(2.0, 3.5, 13.0), (2.0, 24.0, 32.0)] if not door else [(2.0, 24.0, 32.0)]
	# Stucco: the wall between plinth/string course/cornice, minus window openings.
	zs = [1.2 if not door else DOOR_H + 1.2, 20.0, 20.6, 37.4]
	if door:
		acc.add("Stone", B(-1.0, 1.0, a, b, DOOR_H, DOOR_H + 1.2))  # lintel over the opening
	for z0, z1 in ((zs[0], zs[1]), (zs[2], zs[3])):
		holes = [h for h in wins if z0 < h[1] < z1]
		if not holes:
			acc.add("Stucco", B(-1.0, 1.0, a, b, z0, z1))
			continue
		r, h0, h1 = holes[0]
		acc.add("Stucco", B(-1.0, 1.0, a, yc - r, z0, z1))
		acc.add("Stucco", B(-1.0, 1.0, yc + r, b, z0, z1))
		acc.add("Stucco", B(-1.0, 1.0, yc - r, yc + r, z0, h0))
		acc.add("Stucco", B(-1.0, 1.0, yc - r, yc + r, h1 + r, z1))
		acc.add("Stucco", arch_head(yc, r, h1, -1.0, 1.0))
		acc.add("Frost", arch_glass(yc, r, h1, h0, -0.45, 0.45))
		# Glazing bars on both faces and a stone sill.
		for sx in (1, -1):
			acc.add("Iron", B(sx * 0.45, sx * 0.53, yc - 0.06, yc + 0.06, h0, h1 + r))
			for zz in (h0 + (h1 - h0) / 3, h0 + 2 * (h1 - h0) / 3, h1):
				acc.add("Iron", B(sx * 0.45, sx * 0.56, yc - r, yc + r, zz - 0.06, zz + 0.06))
	return acc


def stucco_wall(W):
	acc = Acc()
	n = max(1, int(W // 8))
	bw = W / n
	for i in range(n):
		stucco_bay(acc, -W / 2 + i * bw, -W / 2 + (i + 1) * bw, windows=W >= 8)
	return acc


def stucco_door():
	return stucco_bay(Acc(), -4.0, 4.0, door=True)


# ---------------------------------------------------------------- roofs

def roof_span(S):
	# One 8-deep ridge-and-furrow bay: gutters at y -4 / 0 / 4 (halves at the edges), ridges at +-2 rising to 41.4,
	# lattice girders below every 8 along X, gable ends against the walls.
	acc = Acc()
	h = S / 2
	for yy, lo, hi in ((-4.0, -4.0, -3.85), (0.0, -0.15, 0.15), (4.0, 3.85, 4.0)):
		acc.add("Iron", B(-h, h, lo, hi, 39.7, 40.0))
	for yr in (-2.0, 2.0):
		acc.add("Iron", B(-h, h, yr - 0.08, yr + 0.08, 41.32, 41.5))
		for ya in (yr - 2.0, yr + 2.0):
			# Glass slope from the gutter's edge (40) to the ridge (41.32).
			yg = ya + 0.15 if ya < yr else ya - 0.15
			ge = h - 0.08  # the glass stops at the gable ends' inner faces
			pa, pb = Vector((-ge, yg, 40.0)), Vector((ge, yg, 40.0))
			pc, pd = Vector((ge, yr, 41.32)), Vector((-ge, yr, 41.32))
			acc.add("Glass", quad_slab(pa, pb, pc, pd, 0.05) if ya < yr else quad_slab(pb, pa, pd, pc, 0.05))
			# Glazing bars down the slope every 2 along X.
			x = -h + 2
			while x < h - 0.5:
				acc.add("Iron", beam((x, yg, 40.14), (x, yr, 41.46), 0.1, 0.1))
				x += 2
		# Gable ends (iron) at both walls.
		for sx in (1, -1):
			acc.add("Iron", prism([(yr - 2.0, 40.0), (yr + 2.0, 40.0), (yr, 41.4)], "X", min(sx * h, sx * (h - 0.08)), max(sx * h, sx * (h - 0.08))))
	# Lattice girders along Y every 8 along X: two chords and a zigzag web.
	x = -h + 4
	while x < h:
		acc.add("Iron", B(x - 0.25, x + 0.25, -4, 4, 39.4, 39.7))
		acc.add("Iron", B(x - 0.25, x + 0.25, -4, 4, 37.8, 38.1))
		for k in range(4):
			y0, y1 = -4 + 2 * k, -4 + 2 * (k + 1)
			za, zb = (38.1, 39.4) if k % 2 == 0 else (39.4, 38.1)
			acc.add("Iron", beam((x, y0 + 0.1, za), (x, y1 - 0.1, zb), 0.16, 0.16, up=(1, 0, 0)))
		x += 8
	return acc


# ---------------------------------------------------------------- the Dome

def octo(r, k):
	# Corner k of the octagon with inradius r (corners at 22.5 + 45 k degrees, Blender XY).
	a = math.radians(22.5 + 45 * k)
	R = r / COS
	return Vector((R * math.cos(a), R * math.sin(a), 0))


def dome():
	acc = Acc()
	prof = [(40.0, 40.0), (40.0, 46.0), (35.0, 56.0), (26.0, 64.0), (14.0, 70.0), (7.0, 70.0), (7.0, 76.0), (0.6, 80.0)]
	# Corner flat roofs (glass) at 40 between the square walls and the octagon, with iron frames.
	for k in range(4):
		a = math.radians(45 + 90 * k)
		sx, sy = (1 if math.cos(a) > 0 else -1), (1 if math.sin(a) > 0 else -1)
		p1 = Vector((sx * 40 * TAN, sy * 40.0, 40.0))
		p2 = Vector((sx * 40.0, sy * 40 * TAN, 40.0))
		p3 = Vector((sx * 40.0, sy * 40.0, 40.0))
		bm = bmesh.new()
		lo = [bm.verts.new(v) for v in (p1, p2, p3)]
		hi = [bm.verts.new(v + Vector((0, 0, 0.08))) for v in (p1, p2, p3)]
		bm.faces.new(lo)
		bm.faces.new(hi)
		for i in range(3):
			j = (i + 1) % 3
			bm.faces.new((lo[i], lo[j], hi[j], hi[i]))
		bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
		acc.add("Glass", bm)
		for q, dz in ((p1, 0.12), (p2, 0.16)):
			acc.add("Iron", beam(q + Vector((0, 0, dz)), p3 + Vector((0, 0, dz)), 0.3, 0.2))
	rings = []
	for i, ((ra, za), (rb, zb)) in enumerate(zip(prof, prof[1:])):
		for k in range(8):
			a0, a1 = octo(ra, k - 1), octo(ra, k)
			b0, b1 = octo(rb, k - 1), octo(rb, k)
			A0 = a0 + Vector((0, 0, za))
			A1 = a1 + Vector((0, 0, za))
			B0 = b0 + Vector((0, 0, zb))
			B1 = b1 + Vector((0, 0, zb))
			# Outward normal of this facet and a 0.02 lift off the collision plane.
			n = (A1 - A0).cross(B0 - A0).normalized()
			if n.dot(Vector((A0.x + A1.x, A0.y + A1.y, 0))) < 0 and n.z < 0.99:
				n = -n
			if n.z < -0.1:
				n = -n
			lift = n * 0.1
			mat = "Glass" if i not in (4, 6) else "Iron"
			acc.add(mat, quad_slab(A0 + lift, A1 + lift, B1 + lift, B0 + lift, 0.06))
			# Hip rib along the corner line and a glazing bar down the middle of the facet.
			acc.add("Iron", beam(A1 + n * 0.08, B1 + n * 0.08, 0.35, 0.3, up=n))
			if mat == "Glass":
				m0, m1 = (A0 + A1) / 2, (B0 + B1) / 2
				acc.add("Iron", beam(m0 + n * 0.1, m1 + n * 0.1, 0.14, 0.14, up=n))
		# Ring girder at the bottom of each ring (an octagon of beams).
		for k in range(8):
			p0 = octo(ra, k - 1) + Vector((0, 0, za))
			p1 = octo(ra, k) + Vector((0, 0, za))
			out = Vector((p0.x + p1.x, p0.y + p1.y, 0)).normalized()
			acc.add("Iron", beam(p0 + out * 0.25 + Vector((0, 0, 0.65)), p1 + out * 0.25 + Vector((0, 0, 0.65)), 0.5, 0.4))
	# Drum rail on the walls / corner roofs, and the finial.
	acc.add("Gilt", lathe([(0.0, 80.0), (0.9, 80.4), (1.0, 81.2), (0.6, 82.0), (0.9, 82.6), (0.5, 83.4), (0.12, 86.0)], segs=12))
	return acc


# ---------------------------------------------------------------- fountain, gallery, bridge, stair

def fountain():
	acc = Acc()
	# Octagonal basin: body inradius 11..11.9, coping 10.9..12 (2.6..3).
	def ring(r0, r1, z0, z1):
		return K.arc(r0 / COS, r1 / COS, 22.5, 382.5, z0, z1, steps=8)
	acc.add("Stone", ring(11.0, 11.9, 0.0, 2.6), ring(10.9, 12.0, 2.6, 3.0))
	water = mv(K.cyl(0, 0, 11.0 / COS, 1.1, 1.16, segs=8), 0, 0, 0)
	bmesh.ops.rotate(water, verts=water.verts[:], cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(22.5 - 22.5), 3, "Z"))
	acc.add("Water", water)
	acc.add("Pool", K.arc(0.0, 10.9 / COS, 22.5, 382.5, 0.06, 0.12, steps=8))
	# Tiers matching the collision cylinders (base 8, shaft 6, bowl 14, upper 3, top basin 5).
	acc.add("Stone", vcyl(0, 0, 4.0, 0.0, 1.2, 16), vcyl(0, 0, 3.0, 1.2, 5.0, 16))
	acc.add("Stone", lathe([(3.0, 5.0), (5.5, 5.2), (7.0, 5.7), (7.0, 6.0), (6.6, 6.0), (6.4, 5.75), (3.0, 5.75)], segs=20))
	acc.add("Stone", vcyl(0, 0, 2.5, 6.0, 9.6, 16), lathe([(2.5, 9.6), (3.2, 9.7), (3.2, 10.2), (2.9, 10.2), (2.7, 10.0), (0.0, 10.0)], segs=16))
	for k in range(4):  # carved lion-mask panels on the upper column
		a = math.radians(90 * k + 45)
		acc.add("Stone", tf(B(-0.04, 0.06, -0.7, 0.7, 7.0, 8.6), Matrix.Translation((math.cos(a) * 2.47, math.sin(a) * 2.47, 0)) @ Matrix.Rotation(a, 4, "Z")))
	acc.add("Water", vcyl(0, 0, 6.45, 5.8, 5.86, 20), vcyl(0, 0, 2.85, 10.02, 10.08, 16))
	# Water falling from the bowl lip: a thin ring of sheet (transparent).
	acc.add("Water", K.arc(6.95, 7.02, 0, 360, 1.16, 5.6, steps=40))
	# Greenhouse2: the concept's third tier (above the collision; decor) with its bowl, water and the gilt finial
	acc.add("Stone", vcyl(0, 0, 0.55, 10.0, 11.3, 12))
	acc.add("Stone", lathe([(0.55, 11.3), (1.5, 11.45), (1.7, 11.85), (1.55, 11.9), (1.45, 11.7), (0.0, 11.7)], segs=16))
	acc.add("Water", vcyl(0, 0, 1.42, 11.74, 11.8, 16))
	acc.add("Gilt", lathe([(0.0, 11.8), (0.4, 11.9), (0.28, 12.2), (0.36, 12.4), (0.05, 12.7)], segs=10))
	# Carved panels on the basin (proud 0.06 off the body face, below the coping).
	for k in range(8):
		a = math.radians(45 * k)
		d = Vector((math.cos(a), math.sin(a), 0))
		t = Vector((-math.sin(a), math.cos(a), 0))
		c = d * 11.96
		acc.add("Stone", tf(B(-0.06, 0.03, -2.6, 2.6, 0.7, 2.0), Matrix.Translation(c) @ Matrix.Rotation(a, 4, "Z")))
	return acc


def column(acc, x, y, h, r=0.6, base=0.75, cap=0.75):
	acc.add("Iron", vcyl(x, y, base, 0.0, 0.6, 12), vcyl(x, y, r, 0.6, h - 1.2, 12))
	acc.add("Iron", lathe([(r, h - 1.2), (0.85, h - 0.8), (cap, h - 0.4), (0.0, h - 0.4)], segs=12, x=x, y=y))
	acc.add("Iron", B(x - cap, x + cap, y - cap, y + cap, h - 0.4, h))
	# Leafy capital: small iron leaves around the top.
	for k in range(6):
		a = math.radians(60 * k)
		acc.add("Iron", frond((x + math.cos(a) * r, y + math.sin(a) * r, h - 1.4), 60 * k, 0.7, 0.25, elev=60, droop=0.3, serrate=False, stations=3))


def balustrade(acc, x0, x1, y0, y1, z):
	# Cast-iron balustrade along Y (x0..x1 thick) from y0 to y1, 3 tall: rails, solid panels with raised roundels.
	acc.add("Iron", B(x0 - 0.05, x1 + 0.05, y0, y1, z + 2.7, z + 3.0))
	acc.add("Iron", B(x0, x1, y0, y1, z, z + 0.3))
	acc.add("Iron", B(x0 + 0.1, x1 - 0.1, y0, y1, z + 0.3, z + 2.7))
	n = max(1, int((y1 - y0) / 1.5))
	for i in range(n):
		yc = y0 + (i + 0.5) * (y1 - y0) / n
		for xs, sgn in ((x0 + 0.1, -1), (x1 - 0.1, 1)):
			ring_bm = prism(ring_pts(yc, z + 1.5, 0.5, 10), "X", min(xs, xs + sgn * 0.06), max(xs, xs + sgn * 0.06))
			acc.add("Iron", ring_bm)
	acc.add("Iron", B(x0 - 0.12, x1 + 0.12, y0 - 0.06, y0 + 0.25, z + 0.3, z + 2.7), B(x0 - 0.12, x1 + 0.12, y1 - 0.25, y1 + 0.06, z + 0.3, z + 2.7))


def gallery():
	# The east gallery: map x 28..40, z -40..40 -> here x -6..6, y 40..-40 (Blender y = -map z).
	acc = Acc()
	acc.add("Timber", B(-5.6, 5.97, -39.97, 39.97, GAL - 0.3, GAL))
	acc.add("Iron", B(-6.0, -5.6, -40.0, 40.0, GAL - 1.0, GAL))  # front fascia girder
	y = -36.0
	while y <= 36.0:
		acc.add("Iron", B(-5.6, 5.97, y - 0.2, y + 0.2, GAL - 1.0, GAL - 0.3))
		y += 4.0
	# Balustrade on the front edge (map z -32..-4 and 4..40 -> y 4..32 and -40..-4).
	for y0, y1 in ((4.0, 32.0), (-40.0, -4.0)):
		balustrade(acc, -6.0, -5.5, y0, y1, GAL)
	for mz in (-24, -12, 12, 24):
		column(acc, -5.0, -mz, GAL - 1.0)
		# Curved bracket from column to fascia.
		acc.add("Iron", beam((-5.0, -mz, GAL - 3.0), (-5.0, -mz + 2.5, GAL - 1.05), 0.2, 0.2, up=(1, 0, 0)))
		acc.add("Iron", beam((-5.0, -mz, GAL - 3.0), (-5.0, -mz - 2.5, GAL - 1.05), 0.2, 0.2, up=(1, 0, 0)))
	return acc


def bridge():
	acc = Acc()
	acc.add("Timber", B(-27.97, 27.97, -3.6, 3.6, GAL - 0.3, GAL))
	for sy in (1, -1):
		y0, y1 = sorted((sy * 3.6, sy * 4.0))
		acc.add("Iron", B(-28.0, 28.0, y0, y1, GAL - 1.0, GAL))
		# Railing: posts every 2, bottom / mid / top rails (the top rail is the collision rail).
		acc.add("Iron", B(-28.0, 28.0, y0 + 0.1, y1, GAL + 3.2, GAL + 3.5))
		acc.add("Iron", B(-28.0, 28.0, y0 + 0.15, y1 - 0.05, GAL + 1.6, GAL + 1.75))
		acc.add("Iron", B(-28.0, 28.0, y0 + 0.15, y1 - 0.05, GAL, GAL + 0.15))
		x = -27.0
		while x <= 27.01:
			acc.add("Iron", B(x - 0.08, x + 0.08, y0 + 0.2, y1 - 0.1, GAL + 0.15, GAL + 3.2))
			x += 2.0
		# A shallow arched truss under each edge.
		pts = []
		for i in range(15):
			u = i / 14
			xx = -28 + 56 * u
			zz = GAL - 1.0 - 1.4 * math.sin(math.pi * u)
			pts.append(Vector((xx, (y0 + y1) / 2, zz)))
		for p0, p1 in zip(pts, pts[1:]):
			acc.add("Iron", beam(p0, p1, 0.3, 0.3, up=(0, 1, 0)))
	for x in (-20.0, 20.0):
		column(acc, x, 0.0, GAL - 1.0, r=0.55, base=0.7, cap=0.7)
	return acc


def iron_stair():
	# Climbs toward +X: x 0..18, z 0..12, 8 wide, 16 risers; solid iron stringer panels, timber treads, handrails.
	acc = Acc()
	n = 16
	g, r = 18.0 / n, GAL / n
	for i in range(n):
		x0, x1 = i * g, (i + 1) * g
		acc.add("Iron", B(x0, x1, -3.8, 3.8, 0, (i + 1) * r - 0.12))
		acc.add("Timber", B(x0 + 0.04, x1, -3.8, 3.8, (i + 1) * r - 0.12, (i + 1) * r))
	for sy in (1, -1):
		y0, y1 = sorted((sy * 3.8, sy * 4.0))
		pts = [(0.0, 0.0), (18.0, 0.0), (18.0, GAL + 0.25), (0.0, 0.5)]
		acc.add("Iron", prism([(p[0], p[1]) for p in pts], "Y", y0, y1))
		# Handrail and balusters.
		acc.add("Iron", beam((0.0, (y0 + y1) / 2, 3.6), (18.0, (y0 + y1) / 2, GAL + 3.5), 0.22, 0.22, up=(0, 0, 1)))
		for i in range(0, n, 2):
			xx = (i + 0.5) * g
			zb = (i + 1) * r
			acc.add("Iron", B(xx - 0.07, xx + 0.07, (y0 + y1) / 2 - 0.07, (y0 + y1) / 2 + 0.07, zb, zb + 3.3))
	return acc


# ---------------------------------------------------------------- plants

def palm(acc, x, y, z0, z1, seed, fronds=18, length=9.5):
	# Greenhouse2 (concept 02-hero): a thick, knobbly trunk (10 sides, a flared leaf-base ring on every 1.1 segment,
	# each ring turned half a side so the scars stagger), a full crown of 18 serrated fronds in two tiers, young
	# upright fronds and a date cluster.
	rnd = random.Random(seed)
	r0, r1 = 0.95, 0.68
	z = z0
	k = 0
	while z < z1 - 1e-6:
		za = min(z + 1.1, z1)
		t0, t1 = (z - z0) / (z1 - z0), (za - z0) / (z1 - z0)
		ra, rb = r0 + (r1 - r0) * t0, r0 + (r1 - r0) * t1
		rot = (math.pi / 10) * (k % 2)
		bm = bmesh.new()
		lo = [bm.verts.new((x + ra * 0.86 * math.cos(2 * math.pi * q / 10 + rot), y + ra * 0.86 * math.sin(2 * math.pi * q / 10 + rot), z)) for q in range(10)]
		mid = [bm.verts.new((x + rb * 1.06 * math.cos(2 * math.pi * q / 10 + rot), y + rb * 1.06 * math.sin(2 * math.pi * q / 10 + rot), za - 0.22)) for q in range(10)]
		hi = [bm.verts.new((x + rb * 0.86 * math.cos(2 * math.pi * q / 10 + rot), y + rb * 0.86 * math.sin(2 * math.pi * q / 10 + rot), za)) for q in range(10)]
		for q in range(10):
			bm.faces.new((lo[q], lo[(q + 1) % 10], mid[(q + 1) % 10], mid[q]))
			bm.faces.new((mid[q], mid[(q + 1) % 10], hi[(q + 1) % 10], hi[q]))
		acc.add("Trunk", bm)
		z = za
		k += 1
	acc.add("Trunk", vcyl(x, y, r1 * 0.86, z1 - 0.01, z1 + 0.7, 10))
	for i in range(fronds):
		tier = i % 2
		hd = 360.0 * i / fronds + rnd.uniform(-8, 8)
		mat = ("Palm", "Palm", "Deep")[i % 3]
		acc.add(mat, frond((x, y, z1 + 0.55 + 0.15 * tier), hd, length * rnd.uniform(0.85, 1.1) * (0.9 if tier else 1.0), 1.6, elev=rnd.uniform(18, 34) + 14 * tier, droop=0.6 - 0.1 * tier))
	for i in range(4):
		acc.add("Lime", frond((x, y, z1 + 0.7), 90 * i + 30, 4.2, 0.8, elev=72, droop=0.2))
	acc.add("Fruit", canopy(x + 0.7, y, z1 - 0.3, 1.0, 1.0, 1.2, seed + 3, points=12))


def tree_fern(acc, x, y, z0, z1, seed):
	rnd = random.Random(seed)
	acc.add("Trunk", vcyl(x, y, 0.55, z0, z1, 8), vcyl(x, y, 0.75, z1 - 0.8, z1 + 0.08, 8))
	for i in range(10):
		hd = 36 * i + rnd.uniform(-8, 8)
		acc.add("Fern" if i % 2 else "Deep", frond((x, y, z1), hd, 4.8 * rnd.uniform(0.9, 1.1), 0.9, elev=30, droop=0.55))


def banana(acc, x, y, z0, seed, h=6.0):
	rnd = random.Random(seed)
	acc.add("Trunk", vcyl(x, y, 0.3, z0, z0 + h, 6))
	for i in range(5):
		hd = 72 * i + rnd.uniform(-15, 15)
		acc.add("Lime" if i % 2 else "Palm", frond((x, y, z0 + h), hd, 4.2, 1.1, elev=45, droop=0.5, serrate=False, stations=6))


def border(acc, x0, x1, y0, y1, z, seed, density=0.5):
	# Low border plants on a bed: fern clumps <= 1.2 tall, spaced along the bed.
	rnd = random.Random(seed)
	nx = max(1, int((x1 - x0) / 2.2))
	ny = max(1, int((y1 - y0) / 2.2))
	for i in range(nx):
		for j in range(ny):
			if rnd.random() > density:
				continue
			cx = x0 + (i + 0.5) * (x1 - x0) / nx + rnd.uniform(-0.3, 0.3)
			cy = y0 + (j + 0.5) * (y1 - y0) / ny + rnd.uniform(-0.3, 0.3)
			mat = rnd.choice(("Fern", "Lime", "Deep"))
			acc.add(mat, fern_clump(cx, cy, z, 6, 1.3, 0.35, rnd.randrange(10**6), elev=55, droop=0.45))


# ---------------------------------------------------------------- props

def bed(W, L):
	# A raised bed W (x) by L (y), 3 tall: brick kerb with a stone coping, soil, a low border; bananas in long beds.
	acc = Acc()
	hw, hl = W / 2, L / 2
	t = 0.6
	for x0, x1, y0, y1 in ((-hw + 0.05, hw - 0.05, -hl + 0.05, -hl + t), (-hw + 0.05, hw - 0.05, hl - t, hl - 0.05), (-hw + 0.05, -hw + t, -hl + t, hl - t), (hw - t, hw - 0.05, -hl + t, hl - t)):
		acc.add("Brick", B(x0, x1, y0, y1, 0, 2.7))
	acc.add("Stone", B(-hw, hw, -hl, -hl + t + 0.05, 2.7, 3.0), B(-hw, hw, hl - t - 0.05, hl, 2.7, 3.0))
	acc.add("Stone", B(-hw, -hw + t + 0.05, -hl + t + 0.05, hl - t - 0.05, 2.7, 3.0), B(hw - t - 0.05, hw, -hl + t + 0.05, hl - t - 0.05, 2.7, 3.0))
	acc.add("Soil", B(-hw + t, hw - t, -hl + t, hl - t, 2.0, 2.55))
	border(acc, -hw + t, hw - t, -hl + t, hl - t, 2.55, W * 100 + L)
	if L >= 12:
		for k, yy in enumerate((-hl + 3.5, hl - 3.5) if L >= 18 else (0.0,)):
			banana(acc, 0.3 * (1 if k % 2 else -1), yy, 2.55, int(L * 7 + k), h=6.5)
	return acc


def palm_planter():
	acc = Acc()
	acc.add("Rock", rock_block(-3, 3, -4.5, 4.5, 0, 9, 11))
	acc.add("Soil", B(-2.0, 2.0, -3.4, 3.4, 8.2, 8.45))
	border(acc, -2.2, 2.2, -3.6, 3.6, 8.45, 5, density=0.8)
	palm(acc, 0.0, -0.5, 8.4, 30.0, 21)  # map z 20 -> Blender y = -(20 - 19.5) = -0.5 (planter centre 19.5)
	return acc


def fernery():
	acc = Acc()
	acc.add("Brick", B(-3.98, 3.98, -7.98, 7.98, 0, 2.7))
	acc.add("Stone", B(-4, 4, -8, 8, 2.7, 3.05))
	acc.add("Rock", rock_block(-3.4, 3.4, -7.4, 7.4, 3.05, 9, 31, cell=1.6, inset=0.5))
	acc.add("Soil", B(-3.0, 3.0, -7.0, 7.0, 8.1, 8.4))
	border(acc, -3.2, 3.2, -7.2, 7.2, 8.4, 7, density=0.7)
	# Ferns tumbling down the rock faces.
	rnd = random.Random(9)
	for i in range(14):
		side = rnd.choice((-1, 1))
		yy = rnd.uniform(-7, 7)
		zz = rnd.uniform(3.0, 7.5)
		acc.add(rnd.choice(("Fern", "Deep")), fern_clump(side * 3.2, yy, max(zz, 3.6), 5, 1.4, 0.35, rnd.randrange(10**6), elev=10, droop=0.7))
	for yy in (4.0, -4.0):  # map z 58 / 66 around the centre 62
		tree_fern(acc, 0.0, yy, 8.3, 16.0, int(yy * 10 + 50))
	return acc


def rockery(W, L, H, seed):
	acc = Acc()
	# Greenhouse2 r3: a brick plinth to 3 with a stone coping (the concept's brick planters), the rock above it
	acc.add("Brick", B(-W / 2 + 0.02, W / 2 - 0.02, -L / 2 + 0.02, L / 2 - 0.02, 0, 2.7))
	acc.add("Stone", B(-W / 2, W / 2, -L / 2, L / 2, 2.7, 3.05))
	acc.add("Rock", rock_block(-W / 2 + 0.6, W / 2 - 0.6, -L / 2 + 0.6, L / 2 - 0.6, 3.05, H, seed, cell=1.6, inset=0.5))
	acc.add("Soil", B(-W / 2 + 1.0, W / 2 - 1.0, -L / 2 + 1.0, L / 2 - 1.0, H - 0.9, H - 0.6))
	border(acc, -W / 2 + 1.2, W / 2 - 1.2, -L / 2 + 1.2, L / 2 - 1.2, H - 0.6, seed, density=0.8)
	rnd = random.Random(seed)
	for i in range(14):
		xx = rnd.uniform(-W / 2 + 0.8, W / 2 - 0.8)
		side = rnd.choice((-1, 1))
		acc.add(rnd.choice(("Fern", "Deep", "Lime")), fern_clump(xx, side * (L / 2 - 0.75), rnd.uniform(3.4, H - 1.5), 6, 1.5, 0.4, rnd.randrange(10**6), elev=10, droop=0.7))
	return acc


def pedestal():
	acc = Acc()
	acc.add("Stone", B(-2, 2, -2, 2, 0, 1.0), B(-1.8, 1.8, -1.8, 1.8, 1.0, 7.4), B(-2, 2, -2, 2, 7.4, 8.2))
	for k in range(4):
		a = 90 * k
		acc.add("Stone", rz(B(1.8, 1.86, -1.2, 1.2, 2.0, 6.4), a))
	acc.add("Stone", lathe([(0.0, 8.2), (1.4, 8.2), (1.9, 8.6), (1.9, 9.0), (1.6, 9.0), (1.5, 8.8), (0.0, 8.8)], segs=16))
	acc.add("Fern", fern_clump(0, 0, 8.8, 9, 2.0, 0.4, 77, elev=25, droop=0.8))
	return acc


def hedge_box():
	acc = Acc()
	# Versailles box 8 x 4 x 3: white posts with ball finials, panels in the end colour, then a clipped hedge to 9.
	for x in (-3.8, 3.8):
		for y in (-1.8, 1.8):
			acc.add("Iron", B(x - 0.2, x + 0.2, y - 0.2, y + 0.2, 0, 3.0))
			acc.add("Iron", K.rock_chunk(int(x * 10 + y), size=(0.4, 0.4, 0.4), center=(x, y, 3.2), points=10, jag=0.0))
	acc.add("Accent", B(-3.6, 3.6, -1.9, -1.75, 0.2, 2.8), B(-3.6, 3.6, 1.75, 1.9, 0.2, 2.8))
	acc.add("Accent", B(-3.9, -3.75, -1.6, 1.6, 0.2, 2.8), B(3.75, 3.9, -1.6, 1.6, 0.2, 2.8))
	acc.add("Timber", B(-3.75, 3.75, -1.75, 1.75, 0.2, 2.9))
	acc.add("Hedge", K.cbox(-3.85, 3.85, -1.85, 1.85, 2.9, 9.0, ch=0.45))
	return acc


def wardian_case():
	acc = Acc()
	acc.add("Accent", B(-4, 4, -2, 2, 2.4, 3.0))
	for x in (-3.7, 3.7):
		for y in (-1.7, 1.7):
			acc.add("Accent", B(x - 0.3, x + 0.3, y - 0.3, y + 0.3, 0, 2.4))
	acc.add("Timber", B(-3.4, 3.4, -1.4, 1.4, 0.6, 0.9))
	acc.add("Frost", B(-3.9, 3.9, -1.9, 1.9, 3.0, 7.4))
	acc.add("Frost", prism([(-1.9, 7.4), (1.9, 7.4), (0.0, 9.0)], "X", -3.9, 3.9))
	for x in (-3.95, -1.3, 1.3, 3.95):
		for y in (-1.95, 1.95):
			acc.add("Iron", B(x - 0.08, x + 0.08, y - 0.06, y + 0.06, 3.0, 7.45))
	acc.add("Iron", B(-4.0, 4.0, -0.08, 0.08, 8.92, 9.05))
	acc.add("Iron", B(-4.0, 4.0, -2.04, -1.86, 7.35, 7.5), B(-4.0, 4.0, 1.86, 2.04, 7.35, 7.5))
	acc.add("Gilt", K.rock_chunk(5, size=(0.5, 0.5, 0.6), center=(-3.8, 0, 9.3), points=10, jag=0.0), K.rock_chunk(6, size=(0.5, 0.5, 0.6), center=(3.8, 0, 9.3), points=10, jag=0.0))
	return acc


def citrus_tub():
	acc = Acc()
	for x in (-1.8, 1.8):
		for y in (-1.8, 1.8):
			acc.add("Iron", B(x - 0.2, x + 0.2, y - 0.2, y + 0.2, 0, 3.0))
			acc.add("Iron", K.rock_chunk(int(x * 7 + y * 3), size=(0.4, 0.4, 0.4), center=(x, y, 3.2), points=10, jag=0.0))
	acc.add("Accent", B(-1.6, 1.6, -1.9, -1.75, 0.2, 2.8), B(-1.6, 1.6, 1.75, 1.9, 0.2, 2.8), B(-1.9, -1.75, -1.6, 1.6, 0.2, 2.8), B(1.75, 1.9, -1.6, 1.6, 0.2, 2.8))
	acc.add("Timber", B(-1.75, 1.75, -1.75, 1.75, 0.2, 2.7))
	acc.add("Soil", B(-1.6, 1.6, -1.6, 1.6, 2.7, 2.85))
	acc.add("Trunk", vcyl(0, 0, 0.2, 2.85, 7.6, 6))
	acc.add("Deep", canopy(0, 0, 9.1, 3.8, 3.8, 3.4, 41, points=26))
	rnd = random.Random(4)
	for i in range(11):
		a = rnd.uniform(0, 2 * math.pi)
		e = rnd.uniform(-0.6, 0.9)
		p = Vector((math.cos(a) * math.cos(e) * 1.95, math.sin(a) * math.cos(e) * 1.95, 9.1 + math.sin(e) * 1.75))
		acc.add("Fruit", K.rock_chunk(100 + i, size=(0.42, 0.42, 0.42), center=tuple(p), points=10, jag=0.0))
	return acc


def flower_tub():
	# Greenhouse2 (concept 02-hero): a staved tub, 2.6 across, two bands in the end colour, a white hydrangea
	acc = Acc()
	acc.add("Timber", lathe([(0.0, -0.06), (1.1, -0.06), (1.3, 1.2), (1.38, 2.3), (1.2, 2.3), (0.0, 2.3)], segs=16))  # sunk 0.06: no face on the floor plane
	for z in (0.4, 1.7):
		acc.add("Accent", K.arc(1.16 + z * 0.09, 1.3 + z * 0.09, 0, 360, z, z + 0.2, steps=16))
	acc.add("Soil", vcyl(0, 0, 1.22, 2.18, 2.26, 14))
	acc.add("Deep", canopy(0, 0, 2.9, 1.9, 1.9, 1.4, 71, points=18))  # sits into the soil (float audit)
	rnd = random.Random(31)
	for i in range(9):
		a = rnd.uniform(0, 2 * math.pi)
		rr = rnd.uniform(0.3, 1.0)
		acc.add("Bloom", K.rock_chunk(200 + i, size=(0.62, 0.62, 0.5), center=(math.cos(a) * rr, math.sin(a) * rr, 3.25 + rnd.uniform(0, 0.45)), points=12, jag=0.08))
	return acc


def hip_roof(W, L, H, chimney=False, skylights=0):
	# Greenhouse2 r2 (concept 01-overview: the brick potting sheds and the Lodge under slate): a hipped slate roof
	# over a flat ceiling block W (x) by L (y), its eaves 0.8 out, rising H; stone ridge, fascia, a brick chimney
	# and glass skylights on the long faces. Origin: the middle of the ceiling's top. Decor (the ceiling collides).
	acc = Acc()
	hw, hl, o = W / 2 + 0.8, L / 2 + 0.8, 0.0
	ins = min(hw, hl) * 0.92
	pts_lo = [(-hw, -hl), (hw, -hl), (hw, hl), (-hw, hl)]
	bm = bmesh.new()
	lo = [bm.verts.new((x, y, o)) for x, y in pts_lo]
	tx, ty = max(hw - ins, 0.3), max(hl - ins, 0.3)
	hi = [bm.verts.new((sx * tx, sy * ty, H)) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
	bm.faces.new(lo[::-1])
	bm.faces.new(hi)
	for i in range(4):
		j = (i + 1) % 4
		bm.faces.new((lo[i], lo[j], hi[j], hi[i]))
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	acc.add("Slate", bm)
	acc.add("Stone", B(-tx - 0.2, tx + 0.2, -ty - 0.2, ty + 0.2, H - 0.05, H + 0.35))
	acc.add("Timber", B(-hw - 0.05, hw + 0.05, -hl - 0.05, hl + 0.05, -0.45, 0.02))
	if chimney:
		cx, cy = hw * 0.45, hl * 0.3
		acc.add("Brick", B(cx - 1.0, cx + 1.0, cy - 1.0, cy + 1.0, 0.3, H + 3.0))  # starts above the slab's base plane (z-fight)
		acc.add("Stone", B(cx - 1.2, cx + 1.2, cy - 1.2, cy + 1.2, H + 3.0, H + 3.4))
		for dx in (-0.45, 0.45):
			acc.add("Pot", vcyl(cx + dx, cy, 0.3, H + 3.4, H + 4.2, 8))
	for k in range(skylights):
		xc = -hw * 0.55 + k * (hw * 1.1 / max(skylights - 1, 1))
		for sy in (1, -1):
			# a raised glazed light on the slope, framed in iron (on the slope between eave and ridge)
			y0, y1 = sorted((sy * hl * 0.35, sy * hl * 0.7))
			z0 = H * (1 - abs(y1 if sy > 0 else y0) / hl) if hl > 0 else 0
			za = H * (1 - abs(y0 if sy > 0 else y1) / hl)
			zb = H * (1 - abs(y1 if sy > 0 else y0) / hl)
			a = Vector((xc - 1.6, y0, (za if sy > 0 else zb) + 0.12))
			b2 = Vector((xc + 1.6, y0, (za if sy > 0 else zb) + 0.12))
			c = Vector((xc + 1.6, y1, (zb if sy > 0 else za) + 0.12))
			d = Vector((xc - 1.6, y1, (zb if sy > 0 else za) + 0.12))
			acc.add("Iron", quad_slab(a, b2, c, d, 0.14) if sy < 0 else quad_slab(b2, a, d, c, 0.14))
			lift = Vector((0, 0, 0.16))
			acc.add("Glass", quad_slab(a + lift + Vector((0.2, 0.2 * sy * 0, 0)), b2 + lift - Vector((0.2, 0, 0)), c + lift - Vector((0.2, 0, 0)), d + lift + Vector((0.2, 0, 0)), 0.04) if sy < 0 else quad_slab(b2 + lift - Vector((0.2, 0, 0)), a + lift + Vector((0.2, 0, 0)), d + lift + Vector((0.2, 0, 0)), c + lift - Vector((0.2, 0, 0)), 0.04))
	return acc


def garden_tree(seed):
	# Greenhouse2 r2: the parkland round the glasshouse (concept 01-overview): a broadleaf tree, trunk and three
	# lumpy crown masses in two greens. Decor outside the walls; ~1.2k tris.
	acc = Acc()
	rnd = random.Random(seed)
	h = rnd.uniform(16.0, 22.0)
	acc.add("Trunk", lathe([(1.1, 0.0), (0.85, 1.2), (0.7, h * 0.55), (0.0, h * 0.62)], segs=10))
	for k in range(3):
		a = 2 * math.pi * k / 3 + rnd.uniform(-0.4, 0.4)
		r = rnd.uniform(1.6, 3.0)
		acc.add("Trunk", beam((0, 0, h * 0.45), (math.cos(a) * r, math.sin(a) * r, h * 0.7), 0.6, 0.6))
		acc.add("Deep" if k == 0 else "Palm", canopy(math.cos(a) * r, math.sin(a) * r, h * 0.78, rnd.uniform(5.5, 7.5), rnd.uniform(5.5, 7.5), rnd.uniform(4.5, 6.0), seed * 10 + k, points=30))
	acc.add("Palm", canopy(0, 0, h * 0.92, 6.5, 6.5, 5.0, seed * 10 + 7, points=30))
	return acc


def cold_frame():
	acc = Acc()
	acc.add("Brick", B(-4, 4, -1.5, 1.5, 0, 1.6))
	acc.add("Timber", B(-4, 4, -1.5, 1.5, 1.6, 1.9))
	lid = [Vector((-3.9, -1.45, 1.9)), Vector((3.9, -1.45, 1.9)), Vector((3.9, 1.45, 2.94)), Vector((-3.9, 1.45, 2.94))]
	acc.add("Frost", quad_slab(lid[0], lid[1], lid[2], lid[3], 0.04))
	for x in (-3.95, -1.3, 1.3, 3.95):
		acc.add("Iron", beam((x, -1.5, 1.98), (x, 1.5, 3.0), 0.1, 0.08, up=(0, -0.35, 1)))
	acc.add("Iron", B(-4, 4, 1.4, 1.5, 1.9, 3.0))
	return acc


def urn_shape(acc, r=2.0):
	acc.add("Stone", vcyl(0, 0, r, 0, 0.6, 16), vcyl(0, 0, r - 0.25, 0.6, 4.6, 16), vcyl(0, 0, r, 4.6, 5.0, 16))
	acc.add("Stone", lathe([(0.0, 5.0), (1.0, 5.0), (1.2, 5.4), (1.9, 7.2), (2.0, 8.4), (1.85, 8.6), (2.0, 9.0), (1.7, 9.0), (1.6, 8.7), (0.0, 8.7)], segs=16))
	acc.add("Fern", fern_clump(0, 0, 8.7, 8, 2.2, 0.4, 13, elev=20, droop=0.9))


def urn():
	acc = Acc()
	urn_shape(acc)
	return acc


def potting_bench():
	acc = Acc()
	acc.add("Timber", B(-3, 3, -1.5, 1.5, 2.6, 3.0))
	acc.add("Timber", B(-2.9, 2.9, -1.4, 1.4, 0, 2.6))
	rnd = random.Random(2)
	for i in range(5):
		x = -2.2 + i * 1.1
		y = rnd.uniform(-0.6, 0.6)
		acc.add("Pot", lathe([(0.35, 3.0), (0.5, 3.7), (0.55, 3.75), (0.47, 3.75)], segs=8, x=x, y=y))
		acc.add("Soil", vcyl(x, y, 0.46, 3.55, 3.68, 8))
		acc.add(rnd.choice(("Fern", "Lime")), fern_clump(x, y, 3.68, 4, 0.7, 0.2, i + 7, elev=60, droop=0.4))
	return acc


def shelf_rack():
	acc = Acc()
	acc.add("Timber", B(-2.9, 2.9, -0.06, 0.06, 0, 9))  # central back board
	for x in (-2.95, 2.95):
		acc.add("Timber", B(x - 0.05, x + 0.05, -1.0, 1.0, 0, 9.0))
	for z in (0.2, 2.4, 4.6, 6.8, 8.7):
		acc.add("Timber", B(-2.9, 2.9, -0.95, -0.06, z, z + 0.25), B(-2.9, 2.9, 0.06, 0.95, z, z + 0.25))
	rnd = random.Random(8)
	for z in (0.45, 2.65, 4.85, 7.05):
		for side in (-1, 1):
			for i in range(4):
				x = -2.2 + i * 1.45 + rnd.uniform(-0.2, 0.2)
				y = side * 0.5
				acc.add("Pot", lathe([(0.3, z), (0.4, z + 0.6), (0.34, z + 0.6)], segs=8, x=x, y=y))
				acc.add("Soil", vcyl(x, y, 0.35, z + 0.42, z + 0.52, 8))
				if rnd.random() < 0.6:
					acc.add("Fern", fern_clump(x, y, z + 0.52, 4, 0.6, 0.18, rnd.randrange(10**6), elev=55, droop=0.4))
	return acc


def boiler():
	acc = Acc()
	acc.add("Brick", B(-4, 4, -4, 4, 0, 0.6))
	acc.add("Boiler", K.cbox(-3.9, 3.9, -3.9, 3.9, 0.6, 8.2, ch=0.5))
	for k in range(6):
		y = -3.25 + k * 1.3
		acc.add("Boiler", B(-3.97, 3.97, y - 0.12, y + 0.12, 0.9, 7.9))
	acc.add("Boiler", lathe([(0.0, 8.2), (3.3, 8.2), (3.0, 9.4), (1.6, 10.0), (0.0, 10.0)], segs=12))
	acc.add("Copper", B(-1.0, 1.0, -4.05, -3.95, 2.0, 3.6))  # fire door
	acc.add("Boiler", vcyl(0, 0, 0.55, 10.0, 14.0, 10))  # flue up to the ceiling
	# Greenhouse2: copper flow and return pipes off the top, down the side and away along the floor, with flanges,
	# a pressure gauge and a valve wheel
	for yy in (-2.2, 2.2):
		acc.add("Copper", vcyl(2.4, yy, 0.32, 8.6, 11.0, 10))
		acc.add("Copper", beam((2.4, yy, 10.7), (4.6, yy, 10.7), 0.62, 0.62))
		acc.add("Copper", vcyl(4.6, yy, 0.32, 0.6, 11.0, 10))
		for zf in (2.0, 6.0, 9.6):
			acc.add("Copper", vcyl(4.6, yy, 0.42, zf, zf + 0.2, 10))
		acc.add("Boiler", B(4.0, 4.32, yy - 0.18, yy + 0.18, 4.5, 4.8))  # wall-side bracket back to the casing
	acc.add("Copper", vcyl(-2.0, -3.2, 0.5, 8.2, 8.5, 12))
	acc.add("Bloom", vcyl(-2.0, -3.2, 0.42, 8.5, 8.56, 12))  # gauge face
	acc.add("Copper", vcyl(2.6, -3.2, 0.25, 8.2, 8.9, 8))
	acc.add("Iron", vcyl(2.6, -3.2, 0.6, 8.88, 9.0, 12))  # valve wheel on its stub (float audit: a ring touched nothing)
	return acc


def crate_stack():
	acc = Acc()
	rnd = random.Random(12)
	for k in range(3):
		a = rnd.uniform(-4, 4)
		z0 = 3 * k
		core = K.cbox(-1.7, 1.7, -1.7, 1.7, z0 + 0.06, z0 + 2.92, ch=0.04)
		rz(core, a)
		acc.add("Timber", core)
		# Greenhouse2: four planks a side with 0.12 gaps (the dark core shows between), corner battens, a lid
		for side in range(4):
			for j in range(4):
				zz = z0 + 0.12 + j * 0.7
				pl = B(1.7, 1.82, -1.62, 1.62, zz, zz + 0.58)
				rz(pl, a + 90 * side)
				acc.add("Crate", pl)
			for sy in (1, -1):
				bt = B(1.82, 1.9, sy * 1.62 - (0.24 if sy > 0 else 0), sy * 1.62 + (0.0 if sy > 0 else 0.24), z0, z0 + 3.0)
				rz(bt, a + 90 * side)
				acc.add("Crate", bt)
		lid = B(-1.86, 1.86, -1.86, 1.86, z0 + 2.92, z0 + 3.0 - 0.005)
		rz(lid, a)
		acc.add("Crate", lid)
	acc.add("Sack", K.rock_chunk(3, size=(2.6, 1.8, 1.0), center=(0.3, 0.2, 9.4), points=18, jag=0.05))
	return acc


def pool(W, L, seed, urn_in=False, reeds=False):
	acc = Acc()
	hw, hl = W / 2, L / 2
	for x0, x1, y0, y1 in ((-hw, hw, -hl, -hl + 1), (-hw, hw, hl - 1, hl), (-hw, -hw + 1, -hl + 1, hl - 1), (hw - 1, hw, -hl + 1, hl - 1)):
		acc.add("Stone", B(x0, x1, y0, y1, 0, 1.2))
	acc.add("Pool", B(-hw + 1, hw - 1, -hl + 1, hl - 1, 0.0, 0.06))
	acc.add("Water", B(-hw + 1, hw - 1, -hl + 1, hl - 1, 0.74, 0.8))
	rnd = random.Random(seed)
	pads = []
	for i in range(9 if not urn_in else 7):
		for _ in range(60):
			x, y = rnd.uniform(-hw + 2.2, hw - 2.2), rnd.uniform(-hl + 2.2, hl - 2.2)
			r = rnd.uniform(0.9, 1.5)
			if (not urn_in or math.hypot(x, y) > 3.4 + r) and all(math.hypot(x - a, y - b) > r + c + 0.3 for a, b, c in pads):
				break
		else:
			continue
		pads.append((x, y, r))
		zp = 0.85
		acc.add("Pad", K.cyl(x, y, r, zp, zp + 0.1, segs=12), K.arc(r, r + 0.12, 0, 330, zp, zp + 0.2, steps=11, center=(x, y)))
	if urn_in:
		urn_shape(acc)
	if reeds:
		for cx, cy in ((-hw + 1.8, -hl + 1.8), (hw - 1.8, hl - 1.8), (-hw + 1.8, hl - 1.8)):
			for k in range(7):
				a = rnd.uniform(0, 360)
				acc.add("Lime", frond((cx + rnd.uniform(-0.5, 0.5), cy + rnd.uniform(-0.5, 0.5), 0.8), a, 1.5, 0.28, elev=62, droop=0.25, serrate=False, stations=4))
	return acc


def shed_door():
	# Timber architrave round an 8 x 10 opening in a 2-thick wall, on both faces (back against the wall faces).
	acc = Acc()
	for sx in (1, -1):
		x0, x1 = sorted((sx * 1.0, sx * 1.12))
		acc.add("Accent", B(x0, x1, -4.6, -4.0, 0, 10.6), B(x0, x1, 4.0, 4.6, 0, 10.6), B(x0, x1, -4.0, 4.0, 10.0, 10.6))
	acc.add("Stone", B(-1.0, 1.0, -4.0, 4.0, 0, 0.1))
	return acc


# ---------------------------------------------------------------- the kit

STRUCTURE, GARDEN = [], []


def build_all():
	global STRUCTURE, GARDEN
	s = []
	for w in (16, 8, 4, 2):
		s.append(("GlassWall%d" % w, glass_wall(w)))
	s.append(("GlassDoor8", glass_door()))
	for w in (16, 8, 4, 2):
		s.append(("StuccoWall%d" % w, stucco_wall(w)))
	s.append(("StuccoDoor8", stucco_door()))
	s.append(("RoofSpan48", roof_span(48)))
	s.append(("RoofSpan32", roof_span(32)))
	s += [("Dome", dome()), ("Fountain", fountain()), ("Gallery", gallery()), ("Bridge", bridge()), ("IronStair", iron_stair()), ("ShedDoor8", shed_door())]
	g = [
		("Bed6x6", bed(6, 6)),
		("Bed6x12", bed(6, 12)),
		("Bed6x14", bed(6, 14)),
		("Bed6x18", bed(6, 18)),
		("Bed6x20", bed(6, 20)),
		("PalmPlanter", palm_planter()),
		("Fernery", fernery()),
		("Rockery12x6", rockery(12, 6, 10, 51)),
		("Pedestal4", pedestal()),
		("HedgeBox8x4", hedge_box()),
		("WardianCase", wardian_case()),
		("CitrusTub", citrus_tub()),
		("ColdFrame", cold_frame()),
		("Urn", urn()),
		("PottingBench", potting_bench()),
		("ShelfRack", shelf_rack()),
		("Boiler", boiler()),
		("CrateStack", crate_stack()),
		("LilyPool", pool(14, 14, 61, urn_in=True)),
		("Pond", pool(14, 12, 62, reeds=True)),
		("FlowerTub", flower_tub()),
		("RoofShed48x40", hip_roof(48, 40, 7.0, chimney=True, skylights=3)),
		("RoofShed32x18", hip_roof(32, 18, 5.0, chimney=True)),
		("RoofLodge52x16", hip_roof(52, 16, 5.0)),
		("RoofOrangery80x16", hip_roof(80, 16, 5.0, skylights=4)),
		("GardenTreeA", garden_tree(3)),
		("GardenTreeB", garden_tree(8)),
	]
	for name, acc in s + g:
		acc.d = {k: v for k, v in acc.d.items() if len(v.faces)}
		piece(name, acc)
	STRUCTURE = [n for n, _ in s]
	GARDEN = [n for n, _ in g]


# ---------------------------------------------------------------- contact sheet

def stage_world(strength=1.0):
	sc = bpy.context.scene
	w = sc.world or bpy.data.worlds.new("World")
	sc.world = w
	w.use_nodes = True
	nt = w.node_tree
	nt.nodes.clear()
	out = nt.nodes.new("ShaderNodeOutputWorld")
	bg = nt.nodes.new("ShaderNodeBackground")
	tc = nt.nodes.new("ShaderNodeTexCoord")
	sep = nt.nodes.new("ShaderNodeSeparateXYZ")
	ramp = nt.nodes.new("ShaderNodeValToRGB")
	nt.links.new(tc.outputs["Generated"], sep.inputs[0])
	nt.links.new(sep.outputs[2], ramp.inputs[0])
	ramp.color_ramp.elements[0].color = (*K.lin(0xDDE6DA), 1)
	ramp.color_ramp.elements[1].position = 0.45
	ramp.color_ramp.elements[1].color = (*K.lin(0x6FA6D6), 1)
	nt.links.new(ramp.outputs[0], bg.inputs[0])
	bg.inputs[1].default_value = strength
	nt.links.new(bg.outputs[0], out.inputs[0])


def sun(elev=62.0, azim=-60.0, energy=4.0):
	ld = bpy.data.lights.new("Sun", "SUN")
	ld.energy = energy
	ld.color = K.lin(0xFFF2DC)
	ld.angle = math.radians(1.0)
	ob = bpy.data.objects.new("Sun", ld)
	K.collection("Stage").objects.link(ob)
	d = Vector((math.cos(math.radians(elev)) * math.cos(math.radians(azim)), math.cos(math.radians(elev)) * math.sin(math.radians(azim)), math.sin(math.radians(elev))))
	ob.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
	return ob


TRIS = {}


def sheet(col, names):
	cell, row = 20.0, 26.0
	ncol = 8
	nrow = (len(names) + ncol - 1) // ncol
	floor = _mat("Prev_Shelf", "Limestone", 0xC9C1AF, 0.9, 0.05, 0.9, 0.1)
	for r in range(nrow):
		ob = K.add_obj("Shelf%d" % r, B(-cell / 2, cell * ncol - cell / 2, -9, 9, -r * row - 0.6, -r * row), [floor], col)
		ob["preview_only"] = True
	for idx, name in enumerate(names):
		r, c = divmod(idx, ncol)
		pc = bpy.data.collections["Map_" + name]
		lo = Vector((1e9, 1e9, 1e9))
		hi = -lo
		for ob in pc.all_objects:
			if ob.type != "MESH":
				continue
			for v in ob.data.vertices:
				for i in range(3):
					lo[i] = min(lo[i], v.co[i])
					hi[i] = max(hi[i], v.co[i])
		size = hi - lo
		s = min(1.0, 16.0 / max(size.x, size.y, size.z, 0.01))
		ctr = (lo + hi) / 2
		px, pz = c * cell, -r * row
		m = Matrix.Translation((px, 0, pz)) @ Matrix.Scale(s, 4) @ Matrix.Translation((-ctr.x, -ctr.y, -lo.z))
		K.place_instance(pc, m, "Sheet_" + name, col)
		label = "%s  %d" % (name, TRIS[name]) + ("" if s == 1 else "  x%.2f" % s)
		K.text(label, 1.1, (px, -9.1, pz - 1.6), col, MATS["SignText"], rot=(90, 0, 0), font=K.FONT_LABEL)
	return cell, ncol, nrow, row


def main():
	global KIT, MATS
	bpy.ops.wm.read_homefile(use_empty=True)
	MATS = make_materials()
	KIT = K.collection("Kit")
	build_all()
	worst = {}
	for name, col in BUILT:
		TRIS[name] = K.tri_count(col)
		for ob in col.all_objects:
			if ob.type == "MESH":
				ob.data.calc_loop_triangles()
				worst[ob.name] = len(ob.data.loop_triangles)
	print("GREENHOUSE2_TRIS " + json.dumps(TRIS))
	print("GREENHOUSE2_MAX_OBJECT " + json.dumps(max(worst.items(), key=lambda kv: kv[1])))
	print("GREENHOUSE2_GROUPS " + json.dumps({"Structure": STRUCTURE, "Garden": GARDEN}))
	os.makedirs(OUT_DIR, exist_ok=True)
	os.makedirs(REF_DIR, exist_ok=True)
	bpy.context.view_layer.layer_collection.children["Kit"].exclude = True
	if "--no-render" not in ARGS:
		samples = int(ARGS[ARGS.index("--samples") + 1]) if "--samples" in ARGS else 32
		stage_world(1.1)
		sun()
		K.render_settings(samples=samples)
		K.bloom(strength=0.25, threshold=1.5)
		col = K.collection("Set_Sheet")
		cell, ncol, nrow, row = sheet(col, STRUCTURE + GARDEN)
		cx, cz = cell * ncol / 2 - cell / 2, -row * (nrow - 1) / 2 + 8
		cam = K.camera((cx, -300, cz + 70), (cx, 0, cz), lens=50, name="CamSheet", col=col)
		cam.data.type = "ORTHO"
		cam.data.ortho_scale = max(cell * ncol, row * nrow * 2000 / 1500) * 1.04
		bpy.context.scene.camera = cam
		K.render(os.path.join(REF_DIR, "greenhouse2-kit-sheet.jpg"), res=(2000, 1500))
		bpy.context.view_layer.layer_collection.children["Set_Sheet"].exclude = True
	path = os.path.join(OUT_DIR, "Kit_Greenhouse2.blend")
	bpy.ops.wm.save_as_mainfile(filepath=path)
	print("GREENHOUSE2 saved", path)


main()
