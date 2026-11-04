# build_map_kit_oldtown.py: the Old Town match map kit (vault/01 Design/Maps/Old Town.md).
#
# Every piece is a collection Map_<Piece> built at the world origin; objects are <Piece>_<Material>, one per material
# (each becomes one MeshPart). 1 Blender unit = 1 stud; Blender +X = Roblox +X, Blender +Y = Roblox -Z, +Z up, so a
# piece placed with yaw 0 in Roblox keeps the axes below (kit_bundle.py turns Blender (x, y, z) into Roblox (x, z, -y)).
#
# Origins (tools/maps/oldtown_art.py places the pieces with the same numbers):
#   Facade modules F_*, Cornice*, Parapet*, Attic*: on the floor of their storey, at the centre of the FRONT face plane
#     (the building's outer wall surface); the piece faces +X, its width runs along Y, the wall body is x -2..0 (the
#     greybox walls are 2 thick) and trims stand proud of x = 0. Storeys are 12 tall.
#   Roof*: at the eave line on the face plane, at eave height; the slope rises toward -X (into the building).
#   Gable*: at the centre of the gable end's face plane at eave height, facing +X.
#   Quoin12: at the building corner on the floor; the corner's two faces look +X and -Y (building in x < 0, y > 0).
#   ArcadeBay, Balustrade8, ArcadeRoof8: at the arcade's front face plane (bay centre), on its floor / at 12 / at 12.
#   Arch8 / Arch8D4: at the centre of the lintel's underside, spanning along Y, 1.9 / 3.9 deep (just inside the 2 / 4
#     thick lintel, so its faces stay off the facades it meets).
#   Props, Fountain, ClockTower, Pavilion, CityGate: on the floor at the centre; fronts face +X unless noted.
#     CityGate: the Blue Gate as placed at Roblox (0, 0, -38): its arch is at x -10..0, the plaza face is -Y.
#     Pavilion: as placed at Roblox (51, 0, 0): the plaza end is at x = -17.
# Materials are Roblox materials only (rbx_material + rbx_color): Plaster walls (one cream; Art.luau tints each house
# to its tone), Limestone trims, ClayRoofTiles, Wood, Metal, Fabric... The side accent (#2F6BB3, shutters, awnings,
# banners) is recoloured to the Green end's #4E8A3E by Art.luau on the B half.
#
# Run (headless):
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup \
#       --python tools/blender/build_map_kit_oldtown.py -- [--no-render] [--samples N]
# Writes art-source/maps/OldTown/Kit_OldTown.blend and contact sheets in vault/02 Art/References/maps/oldtown/,
# prints OLDTOWN_TRIS (per piece). Export: tools/blender/export_lobby_kit.py -- --maps OldTown <Group> <pieces...>
# (STRUCTURE and PROPS below list the two groups).

import json, math, os, random, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy, bmesh  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402
import lobbykit as K  # noqa: E402
import zfight_check as Z  # noqa: E402
from gunkit import prism, box, merge, group, ring_pts  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ROOT = K.ROOT
OUT_DIR = os.path.join(ROOT, "art-source", "maps", "OldTown")
REF_DIR = os.path.join(ROOT, "vault", "02 Art", "References", "maps", "oldtown")

PITCH = math.tan(math.radians(30))
STOREY = 12.0

# ---------------------------------------------------------------- palette (vault/01 Design/Maps/Old Town.md -> Look)
C_STUCCO = 0xE9DCC0
C_STONE = 0xD3C3A0
C_PLINTH = 0xB9A584
C_TILE = 0xAD5230
C_BRICK = 0x9E5A40
C_WOOD = 0x6B4A2E
C_WOODLIGHT = 0x9A7550
C_IRON = 0x2B2A28
C_GLASS = 0x3B4652
C_ACCENT = 0x2F6BB3
C_CLOTH = 0xEFE6D2
C_FOLIAGE = 0x6B8A3F
C_CYPRESS = 0x4E6B35
C_WATER = 0x5FA8B8
C_CLOCK = 0xF2EBDD
C_BRASS = 0xB08D55
C_SOIL = 0x4A3A2A
C_BURLAP = 0xB89F72
C_FRUIT = 0xE08A2E
C_POSTER = 0xE8E0CC


def _mat(name, rbx, color, rough=0.85, var=0.05, scale=0.5, bump=0.12, metallic=0.0, stripes=None, **extra):
	m, g, b = K._base(name, rbx, "", color, **extra)
	p = g.obj()
	n = g.noise(p, scale, 3.0)
	c = g.col(color, g.remap(n, 0.3, 0.7, 1 - var, 1 + var))
	if stripes:
		# Tile courses / boards: darker bands every `stripes` studs along U.
		u, v = g.uv()
		band = g.smooth(0.78, 0.95, g.fract(g.div(u, stripes)))
		c = g.scale(c, g.remap(band, 0.0, 1.0, 1.0, 0.72))
	g.set(b.inputs["Base Color"], c)
	b.inputs["Roughness"].default_value = rough
	b.inputs["Metallic"].default_value = metallic
	if bump:
		g.set(b.inputs["Normal"], g.bump(g.noise(p, scale * 8, 4.0), bump, 0.05))
	return m


def make_materials():
	mats = {}
	for m in [
		_mat("Stucco", "Plaster", C_STUCCO, 0.92, 0.04, 0.35, 0.1),
		_mat("Stone", "Limestone", C_STONE, 0.8, 0.06, 0.8, 0.18),
		_mat("Plinth", "Limestone", C_PLINTH, 0.82, 0.07, 0.8, 0.2),
		_mat("Tile", "ClayRoofTiles", C_TILE, 0.75, 0.08, 0.4, 0.2, stripes=1.0),
		_mat("Brick", "Brick", C_BRICK, 0.85, 0.08, 0.6, 0.2),
		_mat("Wood", "Wood", C_WOOD, 0.7, 0.08, 1.2, 0.1, stripes=0.5),
		_mat("WoodLight", "WoodPlanks", C_WOODLIGHT, 0.75, 0.08, 1.2, 0.1, stripes=1.0),
		_mat("Iron", "Metal", C_IRON, 0.45, 0.04, 1.0, 0.05, metallic=0.7),
		_mat("Glass", "SmoothPlastic", C_GLASS, 0.18, 0.02, 1.0, 0.0),
		_mat("AccentWood", "Wood", C_ACCENT, 0.6, 0.05, 1.2, 0.08, stripes=0.5),
		_mat("AccentCloth", "Fabric", C_ACCENT, 0.9, 0.04, 2.0, 0.05),
		_mat("Cloth", "Fabric", C_CLOTH, 0.9, 0.03, 2.0, 0.05),
		_mat("Foliage", "Grass", C_FOLIAGE, 0.9, 0.12, 0.9, 0.3),
		_mat("Cypress", "LeafyGrass", C_CYPRESS, 0.9, 0.12, 0.9, 0.3),
		_mat("ClockFace", "SmoothPlastic", C_CLOCK, 0.5, 0.02, 1.0, 0.0),
		_mat("Brass", "Metal", C_BRASS, 0.4, 0.04, 1.0, 0.03, metallic=0.8),
		_mat("Soil", "Ground", C_SOIL, 0.95, 0.1, 1.0, 0.2),
		_mat("Burlap", "Fabric", C_BURLAP, 0.95, 0.08, 1.5, 0.15),
		_mat("Fruit", "SmoothPlastic", C_FRUIT, 0.5, 0.15, 3.0, 0.0),
		_mat("Poster", "SmoothPlastic", C_POSTER, 0.7, 0.1, 2.0, 0.0),
	]:
		mats[m.name] = m
	w = K._glass("Water", C_WATER)
	w["rbx_transparency"] = 0.35
	mats["Water"] = w
	mats["Mannequin"] = K._flat("Mannequin", 0xA3A2A5, 0.62, preview_only=True)
	mats["SignText"] = K._emissive("SignText", 0xF4F4F2, 1.6, rbx="SurfaceGui", preview_only=True)
	return mats


# ---------------------------------------------------------------- geometry helpers

def B(x0, x1, y0, y1, z0, z1):
	return box(min(x0, x1), max(x0, x1), min(y0, y1), max(y0, y1), min(z0, z1), max(z0, z1))


def CB(x0, x1, y0, y1, z0, z1, ch=0.08):
	return K.cbox(min(x0, x1), max(x0, x1), min(y0, y1), max(y0, y1), min(z0, z1), max(z0, z1), ch=ch)


def vcyl(x, y, r, z0, z1, segs=8):
	return K.cyl(x, y, r, z0, z1, segs=segs)


def ycyl(x, z, r, y0, y1, segs=8):
	return prism(ring_pts(x, z, r, segs, math.pi / segs), "Y", y0, y1)


def xcyl(y, z, r, x0, x1, segs=8):
	return prism(ring_pts(y, z, r, segs, math.pi / segs), "X", x0, x1)


def xprism(pts, x0, x1):
	return prism(pts, "X", x0, x1)  # profile (y, z), extruded along X


def yprism(pts, y0, y1):
	return prism(pts, "Y", y0, y1)  # profile (x, z), extruded along Y


def arc_pts(cy, cz, r, a0, a1, n):
	return [(cy + r * math.cos(a0 + (a1 - a0) * i / n), cz + r * math.sin(a0 + (a1 - a0) * i / n)) for i in range(n + 1)]


def tf(bm, m):
	return K.place(bm, m)


def mv(bm, x=0.0, y=0.0, z=0.0):
	return K.place(bm, Matrix.Translation((x, y, z)))


def rz(bm, deg, x=0.0, y=0.0, z=0.0):
	return K.place(bm, Matrix.Translation((x, y, z)) @ Matrix.Rotation(math.radians(deg), 4, "Z"))


def shear_z(bm, t, dz=0.0):
	# z' = z - t * x + dz: lays flat geometry onto a roof slope that rises toward -X.
	m = Matrix(((1, 0, 0, 0), (0, 1, 0, 0), (-t, 0, 1, dz), (0, 0, 0, 1)))
	bmesh.ops.transform(bm, matrix=m, verts=bm.verts[:])
	return bm


def frustum(x, y, r0, r1, z0, z1, segs=8):
	# Tapered vertical prism (cypresses, balusters, spires); r1 = 0 makes a cone.
	bm = bmesh.new()
	lo = [bm.verts.new((x + r0 * math.cos(2 * math.pi * i / segs), y + r0 * math.sin(2 * math.pi * i / segs), z0)) for i in range(segs)]
	if r1 <= 1e-6:
		top = bm.verts.new((x, y, z1))
		for i in range(segs):
			bm.faces.new((lo[i], lo[(i + 1) % segs], top))
	else:
		hi = [bm.verts.new((x + r1 * math.cos(2 * math.pi * i / segs), y + r1 * math.sin(2 * math.pi * i / segs), z1)) for i in range(segs)]
		for i in range(segs):
			j = (i + 1) % segs
			bm.faces.new((lo[i], lo[j], hi[j], hi[i]))
		bm.faces.new(hi)
	bm.faces.new(lo[::-1])
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	return bm


def blob(x, y, z, sx, sy, sz, seed, points=14):
	# Low-poly foliage clump (a faceted hull).
	return K.rock_chunk(seed, size=(sx, sy, sz), center=(x, y, z), points=points, jag=0.22)


class Acc:
	# One bmesh per material: each becomes one object (one MeshPart). `opts` steers finish() (see piece()).
	def __init__(self, **opts):
		self.d = {}
		self.opts = opts

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

# No z-fighting (vault/01 Design/Maps/00 Maps.md): a layer on a surface (trim, sill, band, coping, cloth, iron) sits
# ON it (its back face touches the surface: both faces are buried, nothing flickers) and stands proud by >= 0.05; a
# face that must pass into a solid goes SINK deep, never flush with one of its faces. Modules butt edge to edge:
# finish() removes the faces a neighbour or the ground hides and pulls trim ends in by JOINT, so no two surfaces of
# neighbouring pieces share a plane. zfight_check.py proves it per piece before the file is saved.
EMB = 0.0  # trims touch their surface
SINK = 0.05  # how far a part reaches into a solid it must pass into
JOINT = 0.03


def finish(bm, W=None, roof=False, ground=True, ridge=None, joint=JOINT):
	# ground: drop downward faces lying on z = 0 (floor, ground or the storey below hides them).
	# W: a strip piece W wide along Y. Its wall body's end faces (x within -2..0) are dropped (the neighbour's body
	#    continues the surface; at a corner the other face's module covers the plane); other end faces (trims) are
	#    pulled in by JOINT, so neighbouring trims meet at a hairline joint instead of a shared plane. roof: drop
	#    every end face (slabs, rolls, fascia: the next slope continues them, the gable's coping hides the last end).
	# ridge: x of a roof ridge; faces looking -X on it are dropped (the other slope and the ridge cap meet there).
	bm.normal_update()
	kill = []
	shrink = {}
	for f in bm.faces:
		vs = [v.co for v in f.verts]
		n = f.normal
		if ground and n.z < -0.99 and all(abs(c.z) < 1e-4 for c in vs):
			kill.append(f)
			continue
		if ridge is not None and n.x < -0.99 and all(abs(c.x - ridge) < 1e-4 for c in vs):
			kill.append(f)
			continue
		if W is None:
			continue
		for s in (-1, 1):
			if n.y * s > 0.99 and all(abs(c.y - s * W / 2) < 1e-4 for c in vs):
				body = all(-2.0 - 1e-4 <= c.x <= 1e-4 for c in vs)
				if roof or body:
					kill.append(f)
				else:
					for v in f.verts:
						shrink[v] = s
	if kill:
		bmesh.ops.delete(bm, geom=kill, context="FACES_ONLY")
	for v, s in shrink.items():
		v.co.y -= s * joint
	return bm


def piece(name, acc):
	col = K.collection("Map_" + name, KIT)
	o = acc.opts
	for mat, bm in acc.d.items():
		finish(bm, W=o.get("W"), roof=o.get("roof", False), ground=o.get("ground", True), ridge=o.get("ridge"), joint=o.get("joint", JOINT))
		big = [f for f in bm.faces if len(f.verts) > 4]
		if big:
			bmesh.ops.triangulate(bm, faces=big, quad_method="BEAUTY", ngon_method="EAR_CLIP")
		ob = K.add_obj("%s_%s" % (name, mat), bm, [MATS[mat]], col, smooth_angle=30)
		if mat in ("AccentCloth", "Cloth", "Foliage", "Cypress", "Water", "Iron", "Fruit"):
			ob.visible_shadow = mat not in ("Water",)
	BUILT.append((name, col))
	return col


# ---------------------------------------------------------------- walls with openings

def opening_top(o):
	return o["z1"] + ((o["y1"] - o["y0"]) / 2 if o.get("arch") else 0.0)


def _layer(W, z0, H, x0, x1, ops):
	# One wall layer x0..x1 with the given openings cut through it (rows of merged boxes + arch spandrels).
	ys = sorted({-W / 2, W / 2} | {o["y0"] for o in ops} | {o["y1"] for o in ops})
	zs = sorted({z0, z0 + H} | {o["z0"] for o in ops} | {opening_top(o) for o in ops})

	def empty(y, z):
		return any(o["y0"] < y < o["y1"] and o["z0"] < z < opening_top(o) for o in ops)

	bm = bmesh.new()
	for k in range(len(zs) - 1):
		za, zb = zs[k], zs[k + 1]
		run = None
		for i in range(len(ys) - 1):
			ya, yb = ys[i], ys[i + 1]
			solid = not empty((ya + yb) / 2, (za + zb) / 2)
			if solid and run is None:
				run = ya
			if not solid and run is not None:
				merge(bm, B(x0, x1, run, ya, za, zb))
				run = None
		if run is not None:
			merge(bm, B(x0, x1, run, ys[-1], za, zb))
	for o in ops:
		if o.get("arch"):
			yc, r, s = (o["y0"] + o["y1"]) / 2, (o["y1"] - o["y0"]) / 2, o["z1"]
			n = 6
			left = [(o["y0"], s), (o["y0"], s + r), (yc, s + r)] + arc_pts(yc, s, r, math.pi / 2, math.pi, n)[1:-1]
			right = [(o["y1"], s)] + arc_pts(yc, s, r, 0, math.pi / 2, n)[1:-1] + [(yc, s + r), (o["y1"], s + r)]
			merge(bm, xprism(left, x0, x1))
			merge(bm, xprism(right, x0, x1))
	return bm


def wall(acc, W, H, ops=(), depth=2.0, mat="Stucco", back_mat="Glass", z0=0.0):
	# A wall x -depth..0, y -W/2..W/2, z z0..z0+H. Openings: y0, y1, z0, z1 (a rectangle; an arched one has a
	# semicircular head springing at z1), through (a real hole) or a recess `recess` deep with a back panel.
	# Two layers: the front layer (x -rec..0) has every opening, the back layer only the through ones, so from behind
	# a recessed window is plain wall. The back panel (glass, a door leaf) stands EMB proud of the back layer and
	# reaches EMB into the reveals, so no face of it lies in a wall plane.
	shallow = [o for o in ops if not o.get("through")]
	rec = shallow[0].get("recess", 0.6) if shallow else depth
	through = [o for o in ops if o.get("through")]
	if shallow:
		acc.add(mat, _layer(W, z0, H, -rec, 0, ops), _layer(W, z0, H, -depth, -rec, through))
	else:
		acc.add(mat, _layer(W, z0, H, -depth, 0, ops))
	for o in shallow:
		acc.add(o.get("back", back_mat), B(-rec - SINK, -rec + SINK, o["y0"] - SINK, o["y1"] + SINK, o["z0"] - SINK, opening_top(o) + SINK))
	return rec


def archivolt(acc, yc, spring, r_in, r_out, prot=0.2, mat="Stone", n=10):
	pts = arc_pts(yc, spring, r_out, 0, math.pi, n) + arc_pts(yc, spring, r_in, math.pi, 0, n)
	acc.add(mat, xprism(pts, -EMB, prot))


def keystone(acc, yc, z, w=0.9, h=1.3, prot=0.35, mat="Stone"):
	acc.add(mat, xprism([(yc - w / 2, z), (yc + w / 2, z), (yc + w * 0.65, z + h), (yc - w * 0.65, z + h)], -EMB, prot))


def surround(acc, y0, y1, z0, z1, band=0.35, prot=0.15, mat="Stone", sill=True, head=True):
	# Stiles stop under the head and above the sill (they butt, never share a face).
	acc.add(mat, B(-EMB, prot, y0 - band, y0, z0, z1), B(-EMB, prot, y1, y1 + band, z0, z1))
	if head:
		acc.add(mat, B(-EMB, prot + 0.15, y0 - band - 0.2, y1 + band + 0.2, z1, z1 + 0.5))
		acc.add(mat, B(-EMB, prot + 0.3, y0 - band - 0.3, y1 + band + 0.3, z1 + 0.5, z1 + 0.75))
	if sill:
		acc.add(mat, B(-EMB, 0.4, y0 - band - 0.1, y1 + band + 0.1, z0 - 0.35, z0))


def shutters(acc, y0, y1, z0, z1):
	# Open shutters flat against the wall either side of the window frame (y0..y1 is the outer edge of the frame).
	w = (y1 - y0) / 2 - 0.35
	for a, b in ((y0 - 0.06 - w, y0 - 0.06), (y1 + 0.06, y1 + 0.06 + w)):
		acc.add("AccentWood", B(-EMB, 0.16, a, b, z0 + 0.06, z1 - 0.06))
		for z in (z0 + 0.35, (z0 + z1) / 2, z1 - 0.35):  # rails (louvres read from the material)
			acc.add("AccentWood", B(0.11, 0.23, a + 0.1, b - 0.1, z - 0.09, z + 0.09))


def window_frame(acc, y0, y1, z0, z1, rec, cross=True):
	# Wood frame and glazing bars on the glass (glass front at -rec + EMB), inside the reveal.
	x0, x1 = -rec, -rec + SINK + 0.12
	t = 0.14
	acc.add("Wood", B(x0, x1, y0, y0 + t, z0, z1), B(x0, x1, y1 - t, y1, z0, z1))
	acc.add("Wood", B(x0, x1, y0 + t, y1 - t, z0, z0 + t), B(x0, x1, y0 + t, y1 - t, z1 - t, z1))
	if cross:
		yc = (y0 + y1) / 2
		zc = z0 + (z1 - z0) * 0.62
		acc.add("Wood", B(x0, x1 - 0.03, yc - t / 2, yc + t / 2, z0 + t, z1 - t))
		acc.add("Wood", B(x0, x1 - 0.06, y0 + t, y1 - t, zc - t / 2, zc + t / 2))


def plinth(acc, W, gaps=(), h=1.2, prot=0.2):
	edges = sorted([-W / 2, W / 2] + [g for gp in gaps for g in gp])
	for k in range(0, len(edges), 2):
		if edges[k + 1] - edges[k] > 1e-3:
			acc.add("Plinth", B(-EMB, prot, edges[k], edges[k + 1], 0, h), B(-EMB, prot + 0.1, edges[k], edges[k + 1], h, h + 0.15))


def string_course(acc, W, z=11.2, h=0.75, prot=0.25):
	acc.add("Stone", B(-EMB, prot, -W / 2, W / 2, z, z + h))


# ---------------------------------------------------------------- facade modules (8 / 4 / 2 wide, 12 tall)
# Openings line up across storeys: every 8-wide module centres its opening, so windows stack over doors and shops.

def f_ground(kind, W=8.0):
	a = Acc(W=W)
	if kind == "Door":
		# The greybox doorway is 6 x 9: the arch springs at 6 and crowns at 9, jambs at +-3.
		wall(a, W, STOREY, [dict(y0=-3, y1=3, z0=0, z1=6, arch=True, through=True)])
		archivolt(a, 0, 6, 3.0, 3.6)
		keystone(a, 0, 8.6)
		a.add("Stone", B(-EMB, 0.2, -3.6, -3.0, 0, 5.7), B(-EMB, 0.2, 3.0, 3.6, 0, 5.7))
		a.add("Stone", B(-EMB, 0.3, -3.8, -2.9, 5.7, 6.1), B(-EMB, 0.3, 2.9, 3.8, 5.7, 6.1))
		a.add("Plinth", B(-2.0 + EMB, 0.05, -3.0 + EMB, 3.0 - EMB, 0, 0.12))  # worn threshold
		plinth(a, W, gaps=[(-3.6, 3.6)])
	elif kind == "Closed":
		rec = wall(a, W, STOREY, [dict(y0=-2.5, y1=2.5, z0=0, z1=6, arch=True, through=False, recess=0.5, back="Wood")])
		archivolt(a, 0, 6, 2.5, 3.1)
		keystone(a, 0, 7.9)
		a.add("Stone", B(-EMB, 0.2, -3.1, -2.5, 0, 6), B(-EMB, 0.2, 2.5, 3.1, 0, 6))
		front = -rec + SINK
		a.add("Wood", B(front - SINK, front + 0.12, -0.08, 0.08, 0.06, 7.6))  # meeting stiles
		for z in (2.2, 5.0):
			a.add("Wood", B(front - SINK, front + 0.1, -2.3, -0.08, z - 0.1, z + 0.1), B(front - SINK, front + 0.1, 0.08, 2.3, z - 0.1, z + 0.1))
		a.add("Iron", B(front, front + 0.3, -0.7, -0.4, 3.6, 3.9), B(front, front + 0.3, 0.4, 0.7, 3.6, 3.9))
		plinth(a, W, gaps=[(-3.1, 3.1)])
	elif kind == "Shop":
		y0, y1, z0, z1 = -2.6, 2.6, 1.4, 8.0
		rec = wall(a, W, STOREY, [dict(y0=y0, y1=y1, z0=z0, z1=z1, through=False, recess=0.6)])
		window_frame(a, y0, y1, z0, z1, rec, cross=False)
		for yv in (-0.9, 0.9):
			a.add("Wood", B(-rec, -rec + 0.18, yv - 0.08, yv + 0.08, z0 + 0.14, z1 - 0.14))
		a.add("Wood", B(-rec, -rec + 0.15, y0 + 0.14, -0.98, 6.4, 6.55), B(-rec, -rec + 0.15, -0.82, 0.82, 6.4, 6.55), B(-rec, -rec + 0.15, 0.98, y1 - 0.14, 6.4, 6.55))
		surround(a, y0, y1, z0, z1, band=0.3, sill=False)
		# Striped awning (the side accent and cream), 3 deep, 8.6..10, on two iron brackets tucked under it.
		n = 6
		for k in range(n):
			ya = -3.2 + 6.4 * k / n
			yb = -3.2 + 6.4 * (k + 1) / n
			m = "AccentCloth" if k % 2 == 0 else "Cloth"
			a.add(m, yprism([(-EMB, 10.0 + 0.021), (-EMB, 10.12 + 0.021), (3.0, 8.72), (3.0, 8.6)], ya, yb))
			a.add(m, B(2.9, 3.06, ya, yb, 8.0, 8.6))  # valance, proud of the sloping cloth's edge
		for yv in (-2.9, 2.9):
			a.add("Iron", yprism([(-EMB, 9.0), (-EMB, 9.12), (2.6, 8.65), (2.6, 8.53)], yv - 0.05, yv + 0.05))
		plinth(a, W, gaps=[(y0 - 0.4, y1 + 0.4)], h=1.05)
		a.add("Stone", B(-EMB, 0.35, y0 - 0.4, y1 + 0.4, 0, 1.4))  # stall-riser sill under the shop window
	elif kind == "Window":
		y0, y1, z0, z1 = -1.2, 1.2, 4.0, 7.6
		rec = wall(a, W, STOREY, [dict(y0=y0, y1=y1, z0=z0, z1=z1, through=False, recess=0.6)])
		bars = bmesh.new()
		for yv in (-0.6, 0.0, 0.6):
			merge(bars, B(-0.4, -0.25, yv - 0.06, yv + 0.06, z0 - EMB, z1 + EMB))
		merge(bars, B(-0.42, -0.23, y0 - EMB, -0.66, 5.8, 5.9))
		merge(bars, B(-0.42, -0.23, -0.54, -0.06, 5.8, 5.9))
		merge(bars, B(-0.42, -0.23, 0.06, 0.54, 5.8, 5.9))
		merge(bars, B(-0.42, -0.23, 0.66, y1 + EMB, 5.8, 5.9))
		a.add("Iron", bars)
		surround(a, y0, y1, z0, z1, band=0.3)
		plinth(a, W)
	else:  # plain
		wall(a, W, STOREY)
		plinth(a, W)
	string_course(a, W)
	return a


def f_upper(kind, W=8.0):
	a = Acc(W=W)
	if kind == "Window":
		y0, y1, z0, z1 = -1.5, 1.5, 3.0, 8.5
		rec = wall(a, W, STOREY, [dict(y0=y0, y1=y1, z0=z0, z1=z1, through=False)])
		window_frame(a, y0, y1, z0, z1, rec)
		surround(a, y0, y1, z0, z1)
		shutters(a, y0 - 0.35, y1 + 0.35, z0, z1)
	elif kind == "Balcony":
		y0, y1, z0, z1 = -1.6, 1.6, 0.4, 8.0
		rec = wall(a, W, STOREY, [dict(y0=y0, y1=y1, z0=z0, z1=z1, through=False)])
		window_frame(a, y0, y1, z0, z1, rec)
		surround(a, y0, y1, z0, z1, sill=False)
		shutters(a, y0 - 0.35, y1 + 0.35, z0, z1)
		# Stone slab on two consoles, iron railing.
		a.add("Stone", B(-SINK, 1.4, -2.6, 2.6, -0.15, 0.34))
		for yv in (-2.0, 2.0):
			a.add("Stone", yprism([(-SINK, -1.1), (-SINK, -0.15), (1.0, -0.15)], yv - 0.25, yv + 0.25))  # into the wall: off the string course's plane
		rail = bmesh.new()
		merge(rail, B(-EMB, 1.32, -2.5, -2.38, 3.0, 3.14))
		merge(rail, B(-EMB, 1.32, 2.38, 2.5, 3.0, 3.14))
		merge(rail, B(1.2, 1.32, -2.38, 2.38, 3.0, 3.14))
		merge(rail, B(1.2, 1.32, -2.38, 2.38, 0.34, 0.5))
		for k in range(1, 6):
			yv = -2.4 + 4.8 * k / 6
			merge(rail, B(1.22, 1.3, yv - 0.04, yv + 0.04, 0.5, 3.0))
		merge(rail, B(1.2, 1.32, -2.5, -2.38, 0.34, 3.0))
		merge(rail, B(1.2, 1.32, 2.38, 2.5, 0.34, 3.0))
		for k in range(1, 3):
			xv = 1.2 * k / 3
			merge(rail, B(xv - 0.04, xv + 0.04, -2.48, -2.4, 0.34, 3.0))
			merge(rail, B(xv - 0.04, xv + 0.04, 2.4, 2.48, 0.34, 3.0))
		a.add("Iron", rail)
	elif kind == "Door":
		# The terrace door: the greybox opening is 6 x 9 from the upper floor.
		wall(a, W, STOREY, [dict(y0=-3, y1=3, z0=0, z1=6, arch=True, through=True)])
		archivolt(a, 0, 6, 3.0, 3.5)
		keystone(a, 0, 8.5)
		a.add("Stone", B(-EMB, 0.2, -3.5, -3.0, 0.05, 6), B(-EMB, 0.2, 3.0, 3.5, 0.05, 6))
		a.add("Stone", B(-1.95, 0.3, -3.6, 3.6, -0.15, 0.14))  # threshold step over the terrace floor
	else:
		wall(a, W, STOREY)
	return a


def cornice(W):
	a = Acc(W=W, joint=2.4 * JOINT)
	prof = [(-SINK, -1.4), (0.2, -1.4), (0.2, -1.0), (0.45, -0.9), (0.75, -0.55), (1.0, -0.2), (1.05, 0.25), (-SINK, 0.25)]  # back sunk into the wall
	a.add("Stone", yprism(prof, -W / 2, W / 2))
	n = int(W / 1.0)
	for k in range(n):  # dentils, hung under the profile
		yv = -W / 2 + 0.5 + k
		a.add("Stone", B(0.12, 0.45, yv - 0.22, yv + 0.22, -1.9, -1.4 + EMB))
	return a


def parapet(W):
	a = Acc(W=W, joint=2.4 * JOINT)
	a.add("Stucco", B(-1.5, 0, -W / 2, W / 2, 0, 2.65))  # its top is buried in the coping
	a.add("Stone", B(-1.7, 0.2, -W / 2, W / 2, 2.6, 3.0))
	a.add("Stone", yprism([(-SINK, -0.75), (0.15, -0.75), (0.45, -0.3), (0.5, 0.1), (-SINK, 0.1)], -W / 2, W / 2))  # clear of a string course
	return a


def attic(W):
	a = Acc(W=W, joint=2.4 * JOINT)
	ops = []
	if W >= 8:
		ops = [dict(y0=-2.6, y1=-1.4, z0=1.6, z1=2.8, through=False, recess=0.4), dict(y0=1.4, y1=2.6, z0=1.6, z1=2.8, through=False, recess=0.4)]
	wall(a, W, 3.65, ops)  # its top is buried in the coping
	a.add("Stone", yprism([(-EMB, 0), (0.3, 0), (0.6, 0.4), (0.8, 0.9), (-EMB, 0.9)], -W / 2, W / 2))
	a.add("Stone", B(-2.2, 0.3, -W / 2, W / 2, 3.6, 4.0))
	return a


def outer_band(W, h):
	# Plain band of wall (the perimeter's outer side above its eave, under a shed roof's high edge).
	a = Acc(W=W, joint=2.4 * JOINT)
	wall(a, W, h - 0.35)  # its top is buried in the coping
	a.add("Stone", B(-2.2, 0.3, -W / 2, W / 2, h - 0.4, h))
	return a


def quoin():
	# Corner stones for a corner whose faces look +X and -Y (building at x < 0, y > 0), one storey: six blocks between
	# the plinth and the string course (1.5..10.5), short along each face (0.55 / 0.35) so shutters, sills and arches
	# beside the corner stay clear of them. The +X blocks start where the -Y blocks' proud edge ends.
	a = Acc(ground=False)
	for k in range(6):
		z = 1.5 + 1.5 * k
		L = 0.55 if k % 2 == 0 else 0.35
		M = 0.35 if k % 2 == 0 else 0.55
		a.add("Stone", B(0.0, 0.14, 0.0, M, z + 0.06, z + 1.44), B(-L, 0.14, -0.14, 0.0, z + 0.06, z + 1.44))
	return a


def roof(run, W):
	# One slope: eave at x = 0 (1 of overhang to x = +1), ridge at x = -run, 30 degrees, tiles as raised rolls. The
	# ridge is capped by a separate RidgeCap piece (one per ridge), so the two slopes never overlap.
	a = Acc(W=W, roof=True, ground=False, ridge=-run)
	t = PITCH
	th = 0.45
	top = run * t
	a.add("Tile", yprism([(1.0, -t), (1.0, -t + th), (-run, top + th), (-run, top)], -W / 2, W / 2))
	rolls = bmesh.new()
	n = int(W / 1.0)
	for k in range(n):
		yv = -W / 2 + 0.5 + k
		r = xprism([(yv - 0.32, -EMB), (yv + 0.32, -EMB), (yv + 0.16, 0.18), (yv - 0.16, 0.18)], -run, 1.0)
		shear_z(r, t, th)
		merge(rolls, r)
	merge(rolls, ycyl(0.95, -t + th + 0.05, 0.28, -W / 2, W / 2, segs=6))  # eave course
	a.add("Tile", rolls)
	a.add("Wood", B(0.6, 1.0 + EMB, -W / 2, W / 2, -t - 0.45, -t + EMB))  # fascia board
	return a


def ridge_cap(W):
	# Half-round ridge tiles along Y, axis at the origin (placed on the ridge line at the slabs' top).
	a = Acc(W=W)
	a.add("Tile", prism(arc_pts(0, 0, 0.5, -0.35, math.pi + 0.35, 8), "Y", -W / 2, W / 2))
	return a


def gable(width):
	a = Acc()
	rise = width / 2 * PITCH
	a.add("Stucco", xprism([(-width / 2, 0), (width / 2, 0), (0, rise)], -2, 0))
	for s in (-1, 1):
		band = [(s * (width / 2 - 0.05), -0.1), (s * (width / 2 - 0.05), 0.55), (0, rise + 0.8), (0, rise + 0.15)]
		# The two rake bands meet at the apex: different depths keep their faces out of each other's planes.
		x0, x1 = (-EMB, 0.3) if s < 0 else (-EMB - 0.03, 0.36)
		a.add("Stone", xprism(band if s < 0 else band[::-1], x0, x1))
	r = 1.0 if width <= 24 else 1.3
	zc = rise * 0.42
	a.add("Stone", xprism(arc_pts(0, zc, r + 0.35, 0, 2 * math.pi, 12)[:-1], -EMB, 0.18))
	a.add("Glass", xprism(arc_pts(0, zc, r, 0, 2 * math.pi, 12)[:-1], 0.13, 0.23))
	return a


# ---------------------------------------------------------------- arcade

def arcade_bay():
	a = Acc(W=8)
	wall(a, 8, STOREY, [dict(y0=-3, y1=3, z0=0, z1=7, arch=True, through=True)], mat="Stone")
	archivolt(a, 0, 7, 3.0, 3.55, prot=0.18, mat="Stone")
	keystone(a, 0, 9.55, w=0.8, h=1.2, prot=0.3)
	for yv in (-3.5, 3.5):
		y0, y1 = max(yv - 0.75, -4), min(yv + 0.75, 4)
		a.add("Plinth", B(-2.2, 0.25, y0, y1, 0, 1.0))  # pier bases (half piers at the bay ends)
		y0, y1 = max(yv - 0.8, -4), min(yv + 0.8, 4)
		a.add("Plinth", B(-2.25, 0.3, y0, y1, 6.55, 7.0))  # impost
	a.add("Stone", B(-EMB, 0.35, -4, 4, 11.25, 11.9))  # entablature band at the terrace edge
	return a


def balustrade():
	a = Acc(W=8)
	a.add("Stone", B(-1.0, 0, -3.4, 3.4, 0, 0.45), B(-1.15, 0.12, -4, 4, 2.55, 3.0))
	for yv in (-3.7, 3.7):
		a.add("Plinth", B(-1.05, 0.05, max(yv - 0.3, -4), min(yv + 0.3, 4), 0, 2.55))
	bal = bmesh.new()
	for k in range(5):
		yv = -2.8 + 1.4 * k
		merge(bal, frustum(-0.5, yv, 0.24, 0.24, 0.4, 0.75, 6))
		merge(bal, frustum(-0.5, yv, 0.24, 0.36, 0.75, 1.35, 6))
		merge(bal, frustum(-0.5, yv, 0.36, 0.17, 1.35, 2.25, 6))
		merge(bal, frustum(-0.5, yv, 0.24, 0.24, 2.25, 2.6, 6))
	a.add("Stone", bal)
	return a


def arcade_roof():
	# Lean-to tiles over the west arcade: 12 at the front face, 15 at the back wall (10 in), plus a front cornice.
	a = Acc(W=8, roof=True, ground=False)
	t = 0.3
	a.add("Tile", yprism([(1.0, -t), (1.0, -t + 0.4), (-10.05, 3.015 + 0.4), (-10.05, 3.015)], -4, 4))  # into the back wall
	rolls = bmesh.new()
	for k in range(8):
		yv = -3.5 + k
		r = xprism([(yv - 0.32, -EMB), (yv + 0.32, -EMB), (yv + 0.16, 0.16), (yv - 0.16, 0.16)], -10.05, 1.0)
		shear_z(r, t, 0.4)
		merge(rolls, r)
	a.add("Tile", rolls)
	a.add("Plinth", B(-SINK, 0.45, -4, 4, -0.35, 0.05))  # eave band, proud of the arcade's entablature
	return a


def arch8(depth=2.0):
	# Passage / gate arch spanning 8 along Y (its ends reach SINK into the walls), `depth` deep: underside crown at 0,
	# haunches springing at -1.2 (y +-4), masonry up to 3.65 under a coping, a stone ring on both faces, a keystone.
	a = Acc(ground=False)
	n = 8
	r = (16 + 1.44) / (2 * 1.2)  # segmental arch through (+-4, -1.2) and (0, 0)
	cz = -r
	pts = []
	for i in range(n + 1):
		yv = -4 + 8 * i / n
		pts.append((yv, cz + math.sqrt(max(r * r - yv * yv, 0))))
	span = 4 + SINK
	poly = [(span, -1.2), (span, 3.65), (-span, 3.65), (-span, -1.2)] + pts[1:-1]
	h = depth / 2
	a.add("Stucco", xprism(poly, -h, h))
	for x0, x1 in ((h, h + 0.15), (-h - 0.15, -h)):
		ring = [(p[0], p[1]) for p in pts] + [(p[0], p[1] + 0.9) for p in pts[::-1]]
		a.add("Stone", xprism(ring, x0, x1))
	a.add("Stone", B(-h - 0.2, h + 0.2, -0.45, 0.45, -0.1, 1.3))
	a.add("Stone", B(-h - 0.25, h + 0.25, -4.0, 4.0, 3.6, 4.0))
	return a


def stair12():
	# 6 wide, 16 run, 12 rise; rises toward +X from x = 0; one solid stepped mass with stone nosings proud of it.
	a = Acc()
	n = 16
	prof = [(0.0, 0.0), (16.0, 0.0)]
	for i in range(n - 1, -1, -1):
		prof += [((i + 1.0), (i + 1) * 0.75), (float(i), (i + 1) * 0.75)]
	a.add("Stone", yprism(prof, -3, 3))
	nos = bmesh.new()
	for i in range(n):
		merge(nos, B(i - 0.08, i + 0.12, -3.06, 3.06, (i + 1) * 0.75 - 0.12, (i + 1) * 0.75 + SINK))
	a.add("Plinth", nos)
	rail = bmesh.new()
	merge(rail, B(0, 0.1, 3.03, 3.19, 0.75, 3.7))
	merge(rail, B(15.9, 16.0, 3.03, 3.19, 12, 15))
	r = xprism([(3.06, 3.5), (3.16, 3.5), (3.16, 3.62), (3.06, 3.62)], 0, 16.0)
	shear_z(r, -0.75, 0.0)
	merge(rail, r)
	a.add("Iron", rail)
	return a


# ---------------------------------------------------------------- heroes

def city_gate():
	a = Acc()
	# Body 24 x 4 x 24, the arch 10 wide at x -10..0 (spring 7, crown 12), plaza face -Y.
	ring_r = 5.0
	body = bmesh.new()
	merge(body, B(-12, -10, -2, 2, 0, 24))
	merge(body, B(0, 12, -2, 2, 0, 24))
	merge(body, B(-10, 0, -2, 2, 12, 24))
	yc = -5.0
	left = [(-10, 7), (-10, 12), (yc, 12)] + [(yc + ring_r * math.cos(t), 7 + ring_r * math.sin(t)) for t in [math.pi / 2 + (math.pi / 2) * i / 6 for i in range(1, 6)]]
	right = [(0, 7)] + [(yc + ring_r * math.cos(t), 7 + ring_r * math.sin(t)) for t in [(math.pi / 2) * i / 6 for i in range(1, 6)]] + [(yc, 12), (0, 12)]
	merge(body, yprism(left, -2, 2))
	merge(body, yprism(right, -2, 2))
	a.add("Stone", body)
	for s in (-1, 1):
		y_face = 2.0 * s
		ys0, ys1 = (y_face, y_face + 0.18 * s)
		# Rusticated base: raised courses up to 10.
		for k in range(7):
			z = 0.25 + k * 1.4
			for x0, x1 in ((-11.95, -10.6), (0.6, 11.95)):
				a.add("Plinth", B(x0, x1, *sorted((y_face - 0.05 * s, ys1)), z, z + 1.15))
		# Arch ring and keystone with a shield (the side accent).
		ring = [(yc + 5.0 * math.cos(t), 7 + 5.0 * math.sin(t)) for t in [math.pi * i / 12 for i in range(13)]]
		ring += [(yc + 6.2 * math.cos(t), 7 + 6.2 * math.sin(t)) for t in [math.pi * (12 - i) / 12 for i in range(13)]]
		a.add("Stone", yprism(ring, min(ys0, y_face + 0.3 * s), max(ys0, y_face + 0.3 * s)))
		a.add("Stone", yprism([(yc - 0.8, 11.6), (yc + 0.8, 11.6), (yc + 1.1, 13.6), (yc - 1.1, 13.6)], min(ys0, y_face + 0.5 * s), max(ys0, y_face + 0.5 * s)))
		sh = [(yc - 1.6, 14.2), (yc + 1.6, 14.2), (yc + 1.6, 16.6), (yc, 17.9), (yc - 1.6, 16.6)]
		a.add("AccentWood", yprism(sh, min(y_face + 0.1 * s, y_face + 0.3 * s), max(y_face + 0.1 * s, y_face + 0.3 * s)))
		a.add("Stone", B(-11.95, 11.95, min(y_face, y_face + 0.4 * s), max(y_face, y_face + 0.4 * s), 12.0, 12.8))  # string course
		# Upper storey: pilasters and two windows east of the arch.
		for xv in (-11.35, 0.5, 11.35):
			a.add("Stone", B(xv - 0.6, xv + 0.6, min(y_face, y_face + 0.25 * s), max(y_face, y_face + 0.25 * s), 12.8, 21.6))
		for xc in (4.0, 8.4):
			g0, g1 = sorted((y_face, y_face + 0.06 * s))
			f0, f1 = sorted((y_face, y_face + 0.22 * s))
			a.add("Glass", B(xc - 1.2, xc + 1.2, *sorted((y_face - 0.05 * s, y_face + 0.06 * s)), 15.0, 19.6))
			a.add("Wood", B(xc - 0.08, xc + 0.08, *sorted((y_face, y_face + 0.1 * s)), 15.0, 19.6))
			a.add("Stone", B(xc - 1.55, xc - 1.2, f0, f1, 15.0, 19.6), B(xc + 1.2, xc + 1.55, f0, f1, 15.0, 19.6))
			a.add("Stone", B(xc - 1.7, xc + 1.7, *sorted((y_face, y_face + 0.35 * s)), 19.6, 20.2))
			a.add("Stone", B(xc - 1.7, xc + 1.7, *sorted((y_face, y_face + 0.4 * s)), 14.6, 15.0))
		# Banners either side of the arch, hanging from the cornice.
		for xc in (-11.0, 1.4):
			yb = y_face + 0.45 * s
			a.add("AccentCloth", B(xc - 0.8, xc + 0.8, min(yb, yb + 0.08 * s), max(yb, yb + 0.08 * s), 13.4, 20.8))
			a.add("AccentCloth", xprism([(min(yb, yb + 0.08 * s), 13.4), (max(yb, yb + 0.08 * s), 13.4), (max(yb, yb + 0.08 * s), 12.6), (min(yb, yb + 0.08 * s), 12.6)], xc - 0.8, xc + 0.8))
			a.add("Iron", B(xc - 1.0, xc + 1.0, min(yb - 0.1 * s, yb + 0.3 * s), max(yb - 0.1 * s, yb + 0.3 * s), 20.8, 21.0))
	# Cornice and crenellated parapet; a bell gable over the arch.
	a.add("Stone", B(-11.95, 11.95, -2.6, 2.6, 21.6, 22.4), B(-11.9, 11.9, -2.3, 2.3, 22.4, 23.0))
	mer = bmesh.new()
	for k in range(9):
		xv = -11.15 + 2.7875 * k
		if -9 < xv < -1:
			continue
		merge(mer, B(xv - 0.8, xv + 0.8, -2.3, 2.3, 23.0, 25.4))
	a.add("Stone", mer)
	bell = bmesh.new()
	merge(bell, B(-9, -1, -1.6, 1.6, 23.0, 24.0))
	merge(bell, yprism([(-8.6, 24), (-1.4, 24), (-1.4, 28.5), (-5, 31), (-8.6, 28.5)], -1.4, 1.4))
	a.add("Stone", bell)
	a.add("Glass", yprism([(-6.2, 25), (-3.8, 25), (-3.8, 27.4), (-5, 28.4), (-6.2, 27.4)], -1.5, 1.5))
	a.add("Brass", vcyl(-5, 0, 0.8, 25.4, 27.0, 8))
	a.add("Stone", yprism([(-8.9, 28.4), (-5, 31.1), (-1.1, 28.4), (-1.1, 28.9), (-5, 31.6), (-8.9, 28.9)], -1.6, 1.6))
	return a


def pavilion():
	a = Acc()
	# 34 x 8 x 24 block (x -17..17); the plaza end (x = -17) is a stone frontispiece: a dark arched niche with the
	# side shield, a loggia balcony and a pediment. The rest is stucco under a hipped roof.
	a.add("Stucco", B(-15, 17, -4, 4, 0, 23.9))
	a.add("Stone", B(-17, -15, -4, 4, 0, 23.9))
	front = Acc()
	archivolt(front, 0, 7.5, 2.0, 2.6, prot=0.2)
	keystone(front, 0, 10.0)
	front.add("Stone", B(0, 0.2, -2.6, -2.0, 1.0, 7.5), B(0, 0.2, 2.0, 2.6, 1.0, 7.5), B(0, 0.35, -2.8, 2.8, 0.6, 1.0))
	front.add("Glass", B(-SINK, 0.05, -2.0, 2.0, 1.0, 7.5), xprism(arc_pts(0, 7.5, 2.0, 0, math.pi, 8), -SINK, 0.05))
	front.add("AccentWood", xprism([(-1.0, 4.0), (1.0, 4.0), (1.0, 5.6), (0, 6.6), (-1.0, 5.6)], 0.05, 0.15))
	for mat, bm in front.d.items():
		tf(bm, Matrix.Translation((-17.0, 0, 0)) @ Matrix.Rotation(math.radians(180), 4, "Z"))
		a.add(mat, bm)
	# Upper loggia: a balcony on two consoles with balusters (above head height, 1.4 proud).
	a.add("Glass", B(-17.05, -16.95, -2.4, 2.4, 13.0, 20.5))
	a.add("Stone", B(-18.4, -17.0, -3.0, 3.0, 12.4, 13.0), B(-18.3, -17.0, -2.9, 2.9, 15.4, 15.8))
	for yv in (-2.4, 2.4):
		a.add("Stone", yprism([(-17.0, 11.4), (-17.0, 12.4), (-18.0, 12.4)], yv - 0.25, yv + 0.25))
	for k in range(7):
		yv = -2.55 + 0.85 * k
		a.add("Stone", frustum(-17.7, yv, 0.2, 0.28, 13.0, 15.4, 6))
	a.add("Stone", B(-17.4, -17.0, -3.0, -2.4, 13.0, 21.0), B(-17.4, -17.0, 2.4, 3.0, 13.0, 21.0), B(-17.5, -17.0, -3.05, 3.05, 20.5, 21.3))
	for yv in (-3.6, 3.6):
		a.add("Stone", B(-17.38, -16.9, yv - 0.5, yv + 0.5, 0, 22.5))  # backs sunk into the stone end
	a.add("Stone", B(-17.4, 17.3, -4.3, 4.3, 11.6, 12.4))
	a.add("Stone", B(-17.8, 16.95, -4.6, 4.6, 22.5, 23.4), B(-17.6, 16.9, -4.4, 4.4, 23.4, 24.0))
	# Pediment over the plaza end with the side roundel.
	a.add("Stone", xprism([(-4.4, 23.95), (4.4, 23.95), (0, 27.6)], -17.66, -15.2))
	a.add("AccentWood", xprism(arc_pts(0, 25.4, 0.9, 0, 2 * math.pi, 10)[:-1], -17.7, -17.55))
	# Windows on the two long faces over the arcade / terrace (x -15..-7) and on the alley end.
	for s_ in (-1, 1):
		yf = 4.0 * s_
		lo, hi = sorted((yf, yf + 0.3 * s_))
		a.add("Glass", B(-12.4, -9.6, min(yf, yf + 0.05 * s_), max(yf, yf + 0.05 * s_), 14.0, 20.0))
		a.add("Stone", B(-12.8, -9.2, lo, hi, 13.6, 14.0), B(-12.8, -9.2, lo, hi, 20.0, 20.6))
		lo2, hi2 = sorted((yf, yf + 0.15 * s_))
		a.add("AccentWood", B(-14.2, -12.8, lo2, hi2, 14.0, 20.0), B(-9.2, -7.8, lo2, hi2, 14.0, 20.0))
	a.add("Glass", B(17.0, 17.05, -1.4, 1.4, 14.0, 20.0))
	a.add("Stone", B(17.0, 17.4, -1.8, 1.8, 13.6, 14.0), B(17.0, 17.4, -1.8, 1.8, 20.0, 20.6))
	# Hipped roof (ridge along x).
	h = 4.6 * PITCH
	rf = bmesh.new()
	v = [rf.verts.new(q) for q in [(-17.6, -4.6, 24), (17.6, -4.6, 24), (17.6, 4.6, 24), (-17.6, 4.6, 24), (-13.0, 0, 24 + h), (13.0, 0, 24 + h)]]
	for f in ((v[0], v[1], v[5], v[4]), (v[2], v[3], v[4], v[5]), (v[1], v[2], v[5]), (v[3], v[0], v[4]), (v[3], v[2], v[1], v[0])):
		rf.faces.new(f)
	bmesh.ops.recalc_face_normals(rf, faces=rf.faces[:])
	a.add("Tile", rf)
	a.add("Tile", tf(ycyl(0, 24 + h, 0.35, -13, 13, 6), Matrix.Rotation(math.radians(90), 4, "Z")))
	return a


def fountain():
	a = Acc()
	# Basin: low wall ring R 10.4..11, coping, a step; water at 2.3.
	a.add("Stone", K.arc(10.3, 11.0, 0, 360, 0.4, 2.6, steps=32))
	a.add("Plinth", K.arc(11.0, 11.7, 0, 360, 0.0, 0.4, steps=32))
	a.add("Stone", K.arc(10.1, 11.35, 0, 360, 2.6, 3.05, steps=32))
	a.add("Water", K.arc(0.0, 10.35, 0, 360, 2.0, 2.3, steps=32))
	# Octagonal pedestal R 6 to 9 with base and top mouldings.
	a.add("Plinth", vcyl(0, 0, 6.6, 2.2, 3.2, 8))
	a.add("Stone", vcyl(0, 0, 6.05, 3.2, 8.6, 8))
	a.add("Stone", vcyl(0, 0, 6.5, 8.6, 9.2, 8))
	# Four lion-mask spouts and their jets.
	jets = bmesh.new()
	for k in range(4):
		ang = math.radians(22.5 + 90 * k)
		cx, cy = math.cos(ang), math.sin(ang)
		m = Matrix.Translation((cx * 6.2, cy * 6.2, 6.4)) @ Matrix.Rotation(ang, 4, "Z")
		a.add("Plinth", tf(B(-0.4, 0.4, -0.6, 0.6, -0.7, 0.7), m))
		prev = None
		for i in range(6):
			t0 = i / 6
			p = (6.6 + 2.6 * t0, 6.2 - 3.9 * t0 * t0)
			if prev:
				seg = xcyl(0, 0, 0.16, 0, math.dist(prev, p), 5)
				dz = p[1] - prev[1]
				dx = p[0] - prev[0]
				tilt = math.atan2(dz, dx)
				tf(seg, Matrix.Rotation(ang, 4, "Z") @ Matrix.Translation((prev[0], 0, prev[1])) @ Matrix.Rotation(-tilt, 4, "Y"))
				merge(jets, seg)
			prev = p
	a.add("Water", jets)
	# Upper bowl, column, capital, globe and spire.
	a.add("Stone", K.lathe([(0.0, 10.4), (2.0, 10.4), (4.4, 11.05), (4.9, 11.0), (4.6, 10.6), (2.2, 9.4), (0.0, 9.2)], steps=12))
	a.add("Water", K.arc(0.0, 4.4, 0, 360, 10.7, 10.85, steps=12))
	a.add("Stone", vcyl(0, 0, 1.8, 10.4, 19.0, 8))
	a.add("Stone", vcyl(0, 0, 2.3, 19.0, 19.8, 8))
	a.add("Plinth", vcyl(0, 0, 2.05, 9.6, 10.35, 8))
	globe = bmesh.new()
	bmesh.ops.create_uvsphere(globe, u_segments=10, v_segments=6, radius=1.3)
	mv(globe, 0, 0, 21.1)
	a.add("Brass", globe)
	a.add("Brass", frustum(0, 0, 0.35, 0.0, 22.2, 24.6, 6))
	return a


def clock_tower():
	a = Acc()
	# 14 x 14 brick shaft on a stone base, a stone clock stage, an open belfry, a lantern and a tiled spire to 104.
	a.add("Plinth", B(-7.3, 7.3, -7.3, 7.3, 0, 4))
	a.add("Brick", B(-7, 7, -7, 7, 4.4, 58))
	for z in (4.0, 22.0, 40.0):
		a.add("Stone", B(-7.3, 7.3, -7.3, 7.3, z, z + 0.8))
	q = bmesh.new()
	for sx in (-1, 1):
		for sy in (-1, 1):
			z = 4.8
			k = 0
			while z < 57.5:
				lx, ly = (1.6, 1.0) if k % 2 == 0 else (1.0, 1.6)
				x0, x1 = sorted((sx * (7 - lx), sx * 7.15))
				y0, y1 = sorted((sy * (7 - ly), sy * 7.15))
				clear = all(z + 1.2 < c - 0.05 or z > c + 0.85 for c in (22.0, 40.0)) and z + 1.2 < 57.95
				if clear:
					merge(q, B(x0, x1, y0, y1, z, z + 1.2))
				z += 1.4
				k += 1
	a.add("Stone", q)
	# Slit windows up the shaft (front +X and the sides).
	for z in (14.0, 30.0, 46.0):
		for ang in (0, 90, 180, 270):
			m = Matrix.Rotation(math.radians(ang), 4, "Z")
			a.add("Glass", tf(B(6.9, 7.08, -0.5, 0.5, z, z + 3.5), m))
			a.add("Stone", tf(B(6.9, 7.25, -0.8, 0.8, z - 0.3, z), m))
	# Clock stage 58-70.
	a.add("Stone", B(-7.6, 7.6, -7.6, 7.6, 58, 59.2))
	a.add("Stone", B(-7.2, 7.2, -7.2, 7.2, 59.2, 69))
	a.add("Stone", B(-7.8, 7.8, -7.8, 7.8, 69, 70.2))
	for ang in (0, 90, 180, 270):
		m = Matrix.Rotation(math.radians(ang), 4, "Z")
		a.add("Stone", tf(xprism(arc_pts(0, 64, 3.6, 0, 2 * math.pi, 16)[:-1], 7.2, 7.45), m))
		a.add("ClockFace", tf(xprism(arc_pts(0, 64, 3.1, 0, 2 * math.pi, 16)[:-1], 7.45, 7.55), m))
		ticks = bmesh.new()
		for h in range(12):
			t = math.radians(30 * h)
			yv, zv = 2.6 * math.sin(t), 64 + 2.6 * math.cos(t)
			merge(ticks, B(7.55, 7.62, yv - 0.12, yv + 0.12, zv - 0.12, zv + 0.12))
		# Hands at ten to four (afternoon).
		hh = math.radians(30 * 3.83)
		mm = math.radians(6 * 50)
		for ang_h, L, w, x0, x1 in ((hh, 1.6, 0.22, 7.6, 7.68), (mm, 2.5, 0.14, 7.66, 7.76)):
			hand = B(x0, x1, -w / 2, w / 2, 0, L)
			tf(hand, Matrix.Translation((0, 0, 64)) @ Matrix.Rotation(-ang_h, 4, "X"))
			merge(ticks, hand)
		a.add("Iron", tf(ticks, m))
	# Belfry 70.2-82: on each side a brick wall with a round arch (crown 81.2, under the cornice), a stone ring and a
	# low stone sill; brick corner piers; a brick ceiling. The bell hangs from a timber yoke on two iron straps.
	for sx in (-1, 1):
		for sy in (-1, 1):
			x0, x1 = sorted((sx * 5.0, sx * 7.0))
			y0, y1 = sorted((sy * 5.0, sy * 7.0))
			a.add("Brick", B(x0, x1, y0, y1, 70.2, 82))
	for ang in (0, 90, 180, 270):
		m = Matrix.Rotation(math.radians(ang), 4, "Z")
		a.add("Brick", tf(_layer(10.0, 70.2, 11.8, 5.0, 7.0, [dict(y0=-4.2, y1=4.2, z0=70.2, z1=77.0, arch=True, through=True)]), m))
		a.add("Stone", tf(xprism(arc_pts(0, 77.0, 4.8, 0, math.pi, 12) + arc_pts(0, 77.0, 4.2, math.pi, 0, 12), 7.0 - EMB, 7.2), m))
		a.add("Plinth", tf(B(5.0 + SINK, 7.15, -4.2 - SINK, 4.2 + SINK, 70.2 - SINK, 71.4), m))
	a.add("Brick", B(-5.0, 5.0, -5.0, 5.0, 81.6, 82.05))
	a.add("Wood", B(-0.25, 0.25, -1.7, 1.7, 79.9, 80.45))
	a.add("Iron", B(-0.08, 0.08, -1.48, -1.32, 80.45 - SINK, 81.6 + SINK), B(-0.08, 0.08, 1.32, 1.48, 80.45 - SINK, 81.6 + SINK))
	bell = [(0.0, 79.95), (0.9, 79.92), (1.3, 79.4), (1.5, 78.4), (1.75, 77.4), (2.2, 76.7), (2.35, 76.5), (2.0, 76.45), (1.5, 77.2), (1.15, 78.3), (0.9, 79.2), (0.0, 79.4)]
	a.add("Brass", K.lathe(bell, steps=12))
	a.add("Iron", vcyl(0, 0, 0.08, 77.0, 79.4 + SINK, 6))
	clap = bmesh.new()
	bmesh.ops.create_uvsphere(clap, u_segments=8, v_segments=5, radius=0.34)
	mv(clap, 0, 0, 76.85)
	a.add("Iron", clap)
	a.add("Stone", B(-7.9, 7.9, -7.9, 7.9, 82, 83.4))
	# Lantern stage 83-91 with a crenellated parapet, then the spire.
	a.add("Brick", B(-5, 5, -5, 5, 83.4, 90.4))
	mer = bmesh.new()
	for ang in (0, 90, 180, 270):
		m = Matrix.Rotation(math.radians(ang), 4, "Z")
		for k in range(1, 5):
			v = -6.6 + 2.64 * k
			merge(mer, tf(B(6.6, 7.6, v - 0.6, v + 0.6, 83.4, 85.6), m))
		merge(mer, tf(B(6.4, 7.6, 6.4, 7.6, 83.4, 85.6), m))  # corner merlon, once per corner
	a.add("Stone", mer)
	for ang in (0, 90, 180, 270):
		m = Matrix.Rotation(math.radians(ang), 4, "Z")
		a.add("Glass", tf(xprism([(-1.2, 85.0), (1.2, 85.0), (1.2, 88.0), (0, 89.2), (-1.2, 88.0)], 4.9, 5.05), m))
	a.add("Stone", B(-5.6, 5.6, -5.6, 5.6, 90.4, 91.2))
	sp = bmesh.new()
	v = [sp.verts.new(p) for p in [(-5.8, -5.8, 91.2), (5.8, -5.8, 91.2), (5.8, 5.8, 91.2), (-5.8, 5.8, 91.2), (0, 0, 104.0)]]
	for f in ((v[0], v[1], v[4]), (v[1], v[2], v[4]), (v[2], v[3], v[4]), (v[3], v[0], v[4]), (v[3], v[2], v[1], v[0])):
		sp.faces.new(f)
	bmesh.ops.recalc_face_normals(sp, faces=sp.faces[:])
	a.add("Tile", sp)
	a.add("Brass", frustum(0, 0, 0.3, 0.08, 103.0, 108.0, 6))
	globe = bmesh.new()
	bmesh.ops.create_uvsphere(globe, u_segments=8, v_segments=5, radius=0.6)
	mv(globe, 0, 0, 105.2)
	a.add("Brass", globe)
	return a


# ---------------------------------------------------------------- props

def market_stall():
	# 8 wide (Y) x 4 deep (X), counter front +X; the back boards and the canopy make it full cover (8).
	a = Acc()
	a.add("WoodLight", B(-0.2, 2.0, -4, 4, 0, 3.4), B(-0.3, 2.3, -4.1, 4.1, 3.4, 3.6))
	a.add("WoodLight", B(-2.0, -1.6, -4, 4, 0, 6.8))
	for yv in (-3.75, 3.75):
		a.add("Wood", B(-2.1, -1.5, yv - 0.22, yv + 0.22, 0, 8.3), B(1.8, 2.2, yv - 0.2, yv + 0.2, 3.6, 7.2))
	for k in range(8):
		ya, yb = -4.3 + 8.6 * k / 8, -4.3 + 8.6 * (k + 1) / 8
		a.add("AccentCloth" if k % 2 == 0 else "Cloth", yprism([(-2.2, 8.3), (-2.2, 8.42), (2.9, 7.0), (2.9, 6.88)], ya, yb))
		a.add("AccentCloth" if k % 2 == 0 else "Cloth", B(2.84, 2.96, ya, yb, 6.4, 7.0))
	crates = bmesh.new()
	fruit = bmesh.new()
	for k, yv in enumerate((-2.8, -0.9, 1.0, 2.9)):
		merge(crates, B(0.2, 1.9, yv - 0.85, yv + 0.85, 3.6, 4.4))
		for i in range(3):
			for j in range(2):
				merge(fruit, vcyl(0.55 + i * 0.5, yv - 0.4 + j * 0.8, 0.24, 4.4, 4.75, 6))
	a.add("Wood", crates)
	a.add("Fruit", fruit)
	sacks = bmesh.new()
	for i, (yv, z) in enumerate(((-2.5, 3.6), (0, 3.6), (2.5, 3.6))):
		merge(sacks, blob(-1.0, yv, z + 0.8, 1.2, 1.6, 1.6, 30 + i, points=10))
	a.add("Burlap", sacks)
	return a


def kiosk():
	# 12 wide (Y) x 4 deep (X), full height to 8: a closed flower-and-paper kiosk with a tiled hip roof.
	a = Acc()
	a.add("AccentWood", B(-1.8, 1.8, -5.8, 5.8, 0.4, 6.2))
	a.add("Wood", B(-2.0, 2.0, -6.0, 6.0, 0, 0.5), B(-2.1, 2.1, -6.1, 6.1, 6.2, 6.6))
	for yv in (-5.8, -2.0, 2.0, 5.8):
		a.add("Wood", B(1.8, 2.0, yv - 0.2, yv + 0.2, 0.5, 6.2), B(-2.0, -1.8, yv - 0.2, yv + 0.2, 0.5, 6.2))
	for yv in (-3.9, 0, 3.9):
		a.add("Poster", B(1.8, 1.86, yv - 1.4, yv + 1.4, 2.4, 5.6))
		a.add("Poster", B(-1.86, -1.8, yv - 1.4, yv + 1.4, 2.4, 5.6))
	# Flower buckets along the front.
	pots = bmesh.new()
	fl = bmesh.new()
	for k in range(5):
		yv = -4.4 + 2.2 * k
		merge(pots, frustum(2.6, yv, 0.45, 0.6, 0, 1.0, 6))
		merge(fl, blob(2.6, yv, 1.35, 1.1, 1.1, 0.9, 50 + k, points=9))
	a.add("Iron", pots)
	a.add("Foliage", fl)
	t = 0.5
	rf = bmesh.new()
	v = [rf.verts.new(p) for p in [(-2.6, -6.6, 6.6), (2.6, -6.6, 6.6), (2.6, 6.6, 6.6), (-2.6, 6.6, 6.6), (0, -4.0, 8.2), (0, 4.0, 8.2)]]
	for f in ((v[1], v[2], v[5], v[4]), (v[3], v[0], v[4], v[5]), (v[0], v[1], v[4]), (v[2], v[3], v[5]), (v[3], v[2], v[1], v[0])):
		rf.faces.new(f)
	bmesh.ops.recalc_face_normals(rf, faces=rf.faces[:])
	a.add("Tile", rf)
	a.add("Iron", vcyl(0, 0, 0.2, 8.2, 9.0, 6), vcyl(0, 0, 0.35, 9.0, 9.5, 6))
	return a


def cart():
	# 7 long (X) x 3.5 wide (Y): a hand cart with two big wheels, loaded with stacked crates to ~7.5 (full cover).
	a = Acc()
	a.add("WoodLight", B(-3.5, 3.5, -1.75, 1.75, 1.6, 2.1))
	for sy in (-1, 1):
		a.add("WoodLight", B(-3.5, 3.5, *sorted((sy * 1.63, sy * 1.75)), 2.1, 3.3))
	for sx in (-1, 1):
		a.add("WoodLight", B(*sorted((sx * 3.38, sx * 3.5)), -1.63, 1.63, 2.1, 3.0))
	a.add("Wood", B(3.45, 6.0, -1.3, -1.1, 1.7, 1.9), B(3.45, 6.0, 1.1, 1.3, 1.7, 1.9))
	a.add("Wood", B(-3.2, -2.9, -0.15, 0.15, 0.0, 1.6 + SINK))  # prop leg
	wheels = bmesh.new()
	for sy in (-1, 1):
		merge(wheels, prism(ring_pts(0.6, 1.5, 1.5, 12, 0), "Y", *sorted((sy * 1.78, sy * 2.08))))
	a.add("Wood", wheels)
	a.add("Iron", ycyl(0.6, 1.5, 0.15, -2.14, 2.14, 6))
	crates = bmesh.new()
	straps = bmesh.new()
	for (x, w, d, z0, h) in ((-2.2, 2.0, 3.0, 2.1, 1.9), (0.0, 2.0, 3.0, 2.1, 1.9), (2.2, 2.0, 3.0, 2.1, 1.9), (-1.1, 2.0, 2.8, 4.0, 1.8), (1.15, 1.9, 2.6, 4.0, 1.8), (-0.2, 1.8, 2.4, 5.8, 1.7)):
		merge(crates, K.cbox(x - w / 2, x + w / 2, -d / 2, d / 2, z0, z0 + h, ch=0.08))
		merge(straps, B(x - w / 2 - 0.04, x + w / 2 + 0.04, -0.12, 0.12, z0 + 0.15, z0 + h - 0.15))
	a.add("WoodLight", crates)
	a.add("Wood", straps)
	return a


def planter_low():
	# 8 long (Y) x 3 (X) x 3 tall stone trough with low shrubs.
	a = Acc()
	a.add("Stone", B(-1.5, 1.5, -4, 4, 0, 2.4), B(-1.7, 1.7, -4.2, 4.2, 2.4, 2.8))
	a.add("Soil", B(-1.2, 1.2, -3.7, 3.7, 2.8, 2.86))
	sh = bmesh.new()
	for k in range(4):
		merge(sh, blob(0, -3.0 + 2.0 * k, 3.3, 2.3, 2.3, 1.4, 200 + k, points=12))
	a.add("Foliage", sh)
	return a


def cypress_planter():
	# 8 long (Y) x 3 (X): a stone trough with three cypresses (full cover to 8, trees to 13).
	a = Acc()
	a.add("Stone", B(-1.5, 1.5, -4, 4, 0, 2.4), B(-1.7, 1.7, -4.2, 4.2, 2.4, 2.8))
	a.add("Soil", B(-1.2, 1.2, -3.7, 3.7, 2.8, 2.86))
	tr = bmesh.new()
	for k, (yv, h) in enumerate(((-2.7, 12.5), (0.0, 13.5), (2.7, 12.0))):
		merge(tr, frustum(0, yv, 1.25, 1.45, 2.75, 3.8, 7))
		merge(tr, frustum(0, yv, 1.45, 1.15, 3.8, 8.5, 7))
		merge(tr, frustum(0, yv, 1.15, 0.0, 8.5, h, 7))
	a.add("Cypress", tr)
	return a


def cafe_set():
	# Round table, two chairs and a parasol (the side accent); 3 x 3 footprint.
	a = Acc()
	a.add("Iron", vcyl(0, 0, 0.12, 0, 2.5, 6), vcyl(0, 0, 0.7, 0, 0.1, 6))
	a.add("Stone", vcyl(0, 0, 1.25, 2.5, 2.65, 10))
	for s in (-1, 1):
		ch = bmesh.new()
		merge(ch, B(-0.55, 0.55, s * 1.9 - 0.55, s * 1.9 + 0.55, 1.5, 1.65))
		for dx in (-0.45, 0.45):
			for dy in (-0.45, 0.45):
				merge(ch, B(dx - 0.06, dx + 0.06, s * 1.9 + dy - 0.06, s * 1.9 + dy + 0.06, 0, 1.5))
		merge(ch, B(-0.55, 0.55, s * 2.4 - 0.06, s * 2.4 + 0.06, 1.65, 3.2))
		a.add("Iron", ch)
	a.add("Iron", vcyl(0, 0, 0.07, 2.65, 7.2, 6))
	n = 8
	can = bmesh.new()
	v0 = can.verts.new((0, 0, 7.3))
	ring = [can.verts.new((2.6 * math.cos(2 * math.pi * i / n), 2.6 * math.sin(2 * math.pi * i / n), 6.4)) for i in range(n)]
	for i in range(n):
		can.faces.new((v0, ring[i], ring[(i + 1) % n]))
	can.faces.new(ring[::-1])
	a.add("AccentCloth", can)
	return a


def well():
	a = Acc()
	a.add("Stone", K.arc(2.2, 3.0, 0, 360, 0, 2.6, steps=16))
	a.add("Stone", K.arc(2.1, 3.15, 0, 360, 2.6, 3.0, steps=16))
	a.add("Water", K.arc(0, 2.2, 0, 360, 1.2, 1.3, steps=16))
	it = bmesh.new()
	for s in (-1, 1):
		merge(it, B(-0.12, 0.12, s * 2.6 - 0.12, s * 2.6 + 0.12, 3.0, 7.2))
	merge(it, yprism([(-0.12, 7.2), (0.12, 7.2), (0.12, 7.35), (-0.12, 7.35)], -2.7, 2.7))
	merge(it, ycyl(0, 6.5, 0.2, -1.0, 1.0, 6))
	a.add("Iron", it)
	a.add("Wood", vcyl(0, 0, 0.5, 4.2, 5.2, 8))
	return a


def shrine():
	# Wall fountain block 7 deep (X) x 6 wide (Y), 8 tall: basin on the +X face, a tiled niche (the side accent).
	a = Acc()
	a.add("Stone", B(-3.5, 2.3, -3, 3, 0, 7.4), B(-3.7, 2.5, -3.2, 3.2, 7.4, 8.0))
	a.add("Plinth", B(-3.6, 2.4, -3.1, 3.1, 0, 0.8))
	a.add("Stone", B(2.3, 3.5, -2.6, 2.6, 0, 2.6))
	a.add("Water", B(2.4, 3.3, -2.4, 2.4, 2.2, 2.3))
	a.add("AccentWood", B(2.3, 2.36, -1.6, 1.6, 2.8, 6.0))
	for z in (3.6, 4.4, 5.2):
		a.add("Cloth", B(2.36, 2.4, -1.6, 1.6, z - 0.05, z + 0.05))
	a.add("Cloth", B(2.36, 2.4, -0.05, 0.05, 2.8, 6.0))
	a.add("Stone", xprism(arc_pts(0, 6.0, 1.6, 0, math.pi, 8), 2.3, 2.6))
	a.add("Brass", tf(xcyl(0, 0, 0.12, -0.05, 0.9, 6), Matrix.Translation((2.3, 0, 3.4))))
	a.add("Stone", xprism([(-3.2, 8.0), (3.2, 8.0), (0, 9.4)], -3.7, 2.5))
	return a


def crates():
	# A 4 x 4 stack to ~6.4: crates in a layer stand apart (or just touch), each layer rests on the one below.
	a = Acc()
	for (x, y, z, sz, h) in ((-0.98, -0.98, 0.0, 1.9, 1.9), (0.98, -0.98, 0.0, 1.9, 1.9), (-0.98, 0.98, 0.0, 1.9, 1.9), (0.98, 0.98, 0.0, 1.9, 1.9), (-0.5, 0.0, 1.9, 1.8, 1.8), (1.05, 0.3, 1.9, 1.3, 1.3), (-0.3, 0.1, 3.7, 1.6, 1.6), (-0.2, 0.0, 5.3, 1.1, 1.05)):
		a.add("WoodLight", K.cbox(x - sz / 2, x + sz / 2, y - sz / 2, y + sz / 2, z, z + h, ch=0.08))
		a.add("Wood", B(x - sz / 2 - 0.03, x + sz / 2 + 0.03, y - 0.12, y + 0.12, z + 0.15, z + h - 0.15))
	return a


def barrels():
	a = Acc()
	for k, (x, y) in enumerate(((-0.6, -1.3), (0.5, 0.0), (-0.5, 1.3))):
		a.add("Wood", K.lathe([(0.0, 2.6), (0.62, 2.6), (0.75, 1.9), (0.78, 1.25), (0.75, 0.6), (0.62, 0), (0.0, 0)], steps=10, center=(x, y)))
		for z in (0.35, 2.25):
			a.add("Iron", K.arc(0.66, 0.8, 0, 360, z, z + 0.15, steps=10, center=(x, y)))
	return a


def stair_porch():
	# 8 wide (Y) x 6 deep (X) x 7 tall masonry porch against a house (back at x = -3): steps rise along +Y up to a
	# landing with an iron rail.
	a = Acc()
	a.add("Stucco", B(-3.05, 1.2, -4, 4, 0, 6.25))
	a.add("Stone", B(-3.1, 1.5, -4.2, 4.2, 6.2, 6.6), B(-3.1, 1.6, -4.3, 4.3, 0, 0.6))  # backs into the house wall
	st = bmesh.new()
	for i in range(8):
		merge(st, B(1.2, 3.0, -4 + i, -3 + i, 0, 0.78 * (i + 1)))
	a.add("Stone", st)
	rail = bmesh.new()
	for i in range(0, 9, 2):
		merge(rail, B(2.85, 3.05, -4 + i - 0.06, -4 + i + 0.06, 0.78 * i, 0.78 * i + 3.0))
	merge(rail, xprism([(-4, 3.0), (4, 9.24), (4, 9.38), (-4, 3.14)], 2.85, 3.05))
	a.add("Iron", rail)
	pots = bmesh.new()
	fl = bmesh.new()
	for yv in (-2.6, 2.6):
		merge(pots, frustum(-1.4, yv, 0.5, 0.65, 6.6, 7.6, 6))
		merge(fl, blob(-1.4, yv, 8.0, 1.3, 1.3, 1.0, 300 + int(yv), points=9))
	a.add("Plinth", pots)
	a.add("Foliage", fl)
	return a


def wall_lantern():
	a = Acc(ground=False)
	a.add("Iron", B(0.1, 1.1, -0.06, 0.06, 0.95, 1.07), B(0.0, 0.1, -0.2, 0.2, 0.5, 1.3))
	a.add("Iron", frustum(1.0, 0, 0.3, 0.42, 0.0, 0.15, 6), frustum(1.0, 0, 0.42, 0.0, 0.9, 1.25, 6))
	a.add("Glass", frustum(1.0, 0, 0.3, 0.38, 0.15, 0.9, 6))
	return a


def banner():
	# Hangs from its top (origin) down 7: a pole bracket and a swallow-tailed cloth (the side accent), 1.2 wide so it
	# fits on a pier or between two windows' shutters.
	a = Acc(ground=False)
	a.add("Iron", B(0.1, 0.9, -0.7, 0.7, -0.1, 0.05), B(0.0, 0.1, -0.15, 0.15, -0.5, 0.2))
	a.add("AccentCloth", xprism([(-0.6, -0.05), (0.6, -0.05), (0.6, -7.0), (0, -6.2), (-0.6, -7.0)], 0.7, 0.78))
	a.add("Cloth", xprism([(-0.6, -0.9), (0.6, -0.9), (0.6, -1.2), (-0.6, -1.2)], 0.75, 0.83))
	return a


def laundry_line():
	# Spans 12 along Y at its origin height, sagging 0.8, with cloth hung on it.
	a = Acc(ground=False)
	line = bmesh.new()
	pts = [(-6 + 12 * i / 8, -0.8 * (1 - ((i - 4) / 4) ** 2)) for i in range(9)]
	for i in range(8):
		(y0, z0), (y1, z1) = pts[i], pts[i + 1]
		seg = xprism([(y0, z0), (y1, z1), (y1, z1 + 0.06), (y0, z0 + 0.06)], -0.03, 0.03)
		merge(line, seg)
	merge(line, B(-0.15, 0.15, -6.05, -5.7, -0.2, 0.2))  # hooks reach into the walls
	merge(line, B(-0.15, 0.15, 5.7, 6.05, -0.2, 0.2))
	a.add("Iron", line)
	for k, (yc, w, h, m) in enumerate(((-3.6, 1.4, 2.2, "Cloth"), (-1.6, 1.8, 1.4, "AccentCloth"), (0.6, 1.2, 2.6, "Cloth"), (2.8, 1.6, 1.8, "Cloth"))):
		zt = -0.8 * (1 - ((yc / 6 * 4) / 4) ** 2) - 0.05
		a.add(m, xprism([(yc - w / 2, zt), (yc + w / 2, zt), (yc + w / 2, zt - h), (yc - w / 2, zt - h)], -0.04, 0.04))
	return a


def plaza_ring():
	# Paving inlay round the fountain: two stone rings (R 15, R 23) and 8 spokes to R 33; 0.06 thick.
	a = Acc()
	a.add("Plinth", K.arc(14.4, 15.6, 0, 360, 0, 0.11, steps=48), K.arc(22.4, 23.6, 0, 360, 0, 0.11, steps=48))
	sp = bmesh.new()
	for k in range(8):
		merge(sp, rz(B(11.8, 14.4, -0.6, 0.6, 0, 0.06), 22.5 + 45 * k))
		merge(sp, rz(B(15.6, 22.4, -0.6, 0.6, 0, 0.06), 22.5 + 45 * k))
		merge(sp, rz(B(23.6, 32.0, -0.6, 0.6, 0, 0.06), 22.5 + 45 * k))
	a.add("Plinth", sp)
	return a


def paving_band():
	a = Acc()
	a.add("Plinth", B(-0.6, 0.6, -8, 8, 0, 0.06))
	return a


def bench():
	a = Acc()
	a.add("Stone", B(-0.8, 0.8, -3, 3, 1.2, 1.6), B(-0.6, 0.6, -2.6, -1.8, 0, 1.2), B(-0.6, 0.6, 1.8, 2.6, 0, 1.2))
	return a


def ceiling_beam():
	# A 20-long timber beam (along Y) hung under a ceiling: origin at its top centre.
	a = Acc()
	a.add("Wood", B(-0.45, 0.45, -9.85, 9.85, -0.9, 0))
	return a


# ---------------------------------------------------------------- the kit

STRUCTURE = []
PROPS = []


def build_all():
	global STRUCTURE, PROPS
	s = []
	for kind in ("Door", "Shop", "Window", "Closed"):
		s.append(("F_Ground" + kind, f_ground(kind)))
	for w in (8, 4, 2):
		s.append(("F_Ground%d" % w, f_ground("Plain", w)))
	for kind in ("Window", "Balcony", "Door"):
		s.append(("F_Upper" + kind, f_upper(kind)))
	for w in (8, 4, 2):
		s.append(("F_Upper%d" % w, f_upper("Plain", w)))
	for w in (8, 4, 2):
		s.append(("Cornice%d" % w, cornice(w)))
		s.append(("Parapet%d" % w, parapet(w)))
		s.append(("Attic%d" % w, attic(w)))
	s.append(("Quoin12", quoin()))
	for run in (12, 16):
		for w in (8, 4):
			s.append(("Roof%d_%d" % (run, w), roof(run, w)))
	for w in (8, 4):
		s.append(("RidgeCap%d" % w, ridge_cap(w)))
		s.append(("OuterBand%d" % w, outer_band(w, 7.4)))
	s.append(("Gable24", gable(24)))
	s.append(("Gable32", gable(32)))
	s += [("ArcadeBay", arcade_bay()), ("Balustrade8", balustrade()), ("ArcadeRoof8", arcade_roof()), ("Arch8", arch8(1.85)), ("Arch8D4", arch8(3.85)), ("Stair12", stair12())]
	s += [("CityGate", city_gate()), ("Pavilion", pavilion()), ("Fountain", fountain()), ("ClockTower", clock_tower())]
	p = [
		("MarketStall", market_stall()),
		("Kiosk", kiosk()),
		("Cart", cart()),
		("PlanterLow", planter_low()),
		("CypressPlanter", cypress_planter()),
		("CafeSet", cafe_set()),
		("Well", well()),
		("Shrine", shrine()),
		("Crates", crates()),
		("Barrels", barrels()),
		("StairPorch", stair_porch()),
		("WallLantern", wall_lantern()),
		("Banner", banner()),
		("LaundryLine", laundry_line()),
		("PlazaRing", plaza_ring()),
		("PavingBand16", paving_band()),
		("Bench", bench()),
		("CeilingBeam", ceiling_beam()),
	]
	for name, acc in s:
		piece(name, acc)
	for name, acc in p:
		piece(name, acc)
	STRUCTURE = [n for n, _ in s]
	PROPS = [n for n, _ in p]


# ---------------------------------------------------------------- previews

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
	ramp.color_ramp.elements[0].position = 0.0
	ramp.color_ramp.elements[0].color = (*K.lin(0xE6D3B3), 1)
	ramp.color_ramp.elements[1].position = 0.45
	ramp.color_ramp.elements[1].color = (*K.lin(0x5E95CC), 1)
	nt.links.new(ramp.outputs[0], bg.inputs[0])
	bg.inputs[1].default_value = strength
	nt.links.new(bg.outputs[0], out.inputs[0])


def sun(elev=40.0, azim=-60.0, energy=4.2):
	ld = bpy.data.lights.new("Sun", "SUN")
	ld.energy = energy
	ld.color = K.lin(0xFFE2B8)
	ld.angle = math.radians(1.5)
	ob = bpy.data.objects.new("Sun", ld)
	K.collection("Stage").objects.link(ob)
	d = Vector((math.cos(math.radians(elev)) * math.cos(math.radians(azim)), math.cos(math.radians(elev)) * math.sin(math.radians(azim)), math.sin(math.radians(elev))))
	ob.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
	return ob


def inst(name, x=0.0, y=0.0, z=0.0, deg=0.0, col=None):
	c = bpy.data.collections["Map_" + name]
	return K.place_instance(c, Matrix.Translation((x, y, z)) @ Matrix.Rotation(math.radians(deg), 4, "Z"), "I_" + name, col)


def ground(col, x0, x1, y0, y1, color=0x9C8D7A, rbx="Cobblestone", name="Ground"):
	m = bpy.data.materials.get("Prev_" + name) or _mat("Prev_" + name, rbx, color, 0.9, 0.1, 0.9, 0.35)
	ob = K.add_obj(name + "_" + col.name, B(x0, x1, y0, y1, -0.5, 0), [m], col)
	ob["preview_only"] = True
	return ob


def vignette(col):
	# A plaza corner assembled from the kit the way Art.luau places it (Blender coordinates; Roblox +Z = -Y): the
	# Cafe (24 deep) behind the arcade and its terrace, the Pavilion at the arcade's end, the fountain, props and the
	# clock tower over the roofs. Plaza at x < 0; the arcade face is x = 0, the house face x = 10.
	ground(col, -90, 70, -80, 50)
	ground(col, -90, 0, -80, 50, 0xD8C9AA, "Limestone", "Plaza")
	ys = (-28, -20, -12, -4)
	for i, yc in enumerate(ys):
		inst(("F_GroundShop", "F_GroundDoor", "F_GroundShop", "F_GroundWindow")[i], 10, yc, 0, 180, col)
		inst(("F_UpperDoor", "F_UpperWindow", "F_UpperBalcony", "F_UpperWindow")[i], 10, yc, 12, 180, col)
		inst("Cornice8", 10, yc, 24, 180, col)
		inst("Roof12_8", 10, yc, 24, 180, col)
		inst("Roof12_8", 34, yc, 24, 0, col)
		inst("ArcadeBay", 0, yc, 0, 180, col)
		inst("Balustrade8", 0, yc, 12, 180, col)
	for yc in (-24, -16, -8):
		inst("Banner", -0.35, yc, 11.4, 180, col)
	# South end of the house: facade facing -Y, quoins at the corner, the gable.
	for xc, g, u in ((14, "F_GroundWindow", "F_UpperWindow"), (22, "F_GroundClosed", "F_UpperBalcony"), (30, "F_Ground8", "F_UpperWindow")):
		inst(g, xc, -32, 0, -90, col)
		inst(u, xc, -32, 12, -90, col)
		inst("Cornice8", xc, -32, 24, -90, col)
	inst("Gable24", 22, -32, 24, -90, col)
	inst("Quoin12", 10, -32, 0, -90, col)
	inst("Quoin12", 10, -32, 12, -90, col)
	inst("WallLantern", 10, -16, 9.0, 180, col)
	sl = K.add_obj("TerraceSlab", B(0, 10, -32, 0, 11, 12), [MATS["Stone"]], col)
	sl["preview_only"] = True
	inst("Pavilion", 17, 4, 0, 0, col)
	inst("Fountain", -34, -6, 0, 0, col)
	inst("PlazaRing", -34, -6, 0.02, 0, col)
	inst("CafeSet", -7, -29, 0, 15, col)
	inst("CafeSet", -7, -17, 0, -20, col)
	inst("CafeSet", -7, -6, 0, 40, col)
	inst("MarketStall", -18, 14, 0, 0, col)
	inst("Kiosk", -30, -40, 0, 90, col)
	inst("CypressPlanter", -6, 22, 0, 0, col)
	inst("PlanterLow", -22, -26, 0, 90, col)
	inst("ClockTower", 92, -10, 0, 0, col)
	K.avatar((-3, -12, 0), facing=-90, col=col)
	K.avatar((-22, -14, 0), facing=30, col=col)
	K.avatar((2, -20, 12), facing=180, col=col)


def heroes(col):
	ground(col, -90, 90, -70, 60, 0xD8C9AA, "Limestone", "Plaza")
	inst("CityGate", -55, 0, 0, 0, col)
	inst("Fountain", -12, 0, 0, 0, col)
	inst("Pavilion", 30, 26, 0, 90, col)
	inst("ClockTower", 62, -12, 0, 0, col)
	inst("Shrine", -24, -34, 0, 0, col)
	inst("Well", -8, -34, 0, 0, col)
	inst("StairPorch", 10, -34, 0, 0, col)
	inst("Cart", 26, -34, 0, 20, col)
	inst("Crates", 38, -34, 0, 0, col)
	inst("Barrels", 46, -34, 0, 0, col)
	K.avatar((-34, -10, 0), facing=0, col=col)


def sheet(col, names):
	# A front elevation: shelves of pieces, each turned to face the camera (-Y), labelled with its triangles.
	cell, row = 18.0, 20.0
	ncol = 8
	nrow = (len(names) + ncol - 1) // ncol
	floor = bpy.data.materials.get("Prev_Shelf") or _mat("Prev_Shelf", "Limestone", 0xBFB29C, 0.9, 0.05, 0.9, 0.1)
	for r in range(nrow):
		ob = K.add_obj("Shelf%d" % r, B(-cell / 2, cell * ncol - cell / 2, -8, 8, -r * row - 0.6, -r * row), [floor], col)
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
		s = min(1.0, 14.0 / max(size.x, size.y, size.z, 0.01))
		ctr = (lo + hi) / 2
		px, pz = c * cell, -r * row
		m = Matrix.Translation((px, 0, pz)) @ Matrix.Rotation(math.radians(-90), 4, "Z") @ Matrix.Scale(s, 4) @ Matrix.Translation((-ctr.x, -ctr.y, -lo.z))
		K.place_instance(pc, m, "Sheet_" + name, col)
		label = "%s  %d" % (name, TRIS[name]) + ("" if s == 1 else "  x%.2f" % s)
		K.text(label, 1.1, (px, -8.1, pz - 1.6), col, MATS["SignText"], rot=(90, 0, 0), font=K.FONT_LABEL)
	return cell, ncol, nrow, row


TRIS = {}


def piece_triangles(col):
	# World-space triangles of a kit piece, one owner per object (= one MeshPart in Studio).
	tris, owners, labels = [], [], []
	for ob in col.all_objects:
		if ob.type != "MESH":
			continue
		me = ob.data
		me.calc_loop_triangles()
		mw = ob.matrix_world
		oid = len(labels)
		labels.append(ob.name)
		for t in me.loop_triangles:
			tris.append([tuple(mw @ me.vertices[i].co) for i in t.vertices])
			owners.append(oid)
	return tris, owners, labels


def zfight_kit():
	# Every piece on its own: no two of its surfaces may share a plane and overlap (zfight_check.py).
	bad = {}
	info = 0
	for name, col in BUILT:
		tris, owners, labels = piece_triangles(col)
		found = Z.find(tris, owners, labels)
		same = [c for c in found if c[0] == "same"]
		info += len(found) - len(same)
		if same:
			bad[name] = same
	for name, same in bad.items():
		print("ZFIGHT %s: %d" % (name, len(same)))
		for c in same[:6]:
			print("   ", c)
	print("OLDTOWN_ZFIGHT pieces with z-fighting: %d (touching, buried pairs: %d)" % (len(bad), info))
	return bad


def show_only(name):
	for lc in bpy.context.view_layer.layer_collection.children:
		if lc.name.startswith("Set_"):
			lc.exclude = lc.name != name


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
	print("OLDTOWN_TRIS " + json.dumps(TRIS))
	print("OLDTOWN_MAX_OBJECT " + json.dumps(max(worst.items(), key=lambda kv: kv[1])))
	print("OLDTOWN_GROUPS " + json.dumps({"Structure": STRUCTURE, "Props": PROPS}))
	bad = zfight_kit()
	if bad and "--allow-zfight" not in ARGS:
		raise SystemExit("z-fighting in kit pieces: %s (fix them, or pass --allow-zfight to look at renders)" % ", ".join(bad))
	os.makedirs(OUT_DIR, exist_ok=True)
	os.makedirs(REF_DIR, exist_ok=True)
	bpy.context.view_layer.layer_collection.children["Kit"].exclude = True
	samples = int(ARGS[ARGS.index("--samples") + 1]) if "--samples" in ARGS else 48
	only = ARGS[ARGS.index("--only") + 1].split(",") if "--only" in ARGS else ["vignette", "heroes", "sheet"]
	stage_world(1.1)
	sun()
	K.render_settings(samples=samples)
	K.bloom(strength=0.3, threshold=1.4)
	sets = {}
	if "vignette" in only:
		col = K.collection("Set_Vignette")
		vignette(col)
		sets["Set_Vignette"] = (K.camera((-66, -70, 10), (2, -12, 12), lens=28, name="CamVignette", col=col), "oldtown-kit-vignette.jpg", (1800, 1000))
	if "heroes" in only:
		col = K.collection("Set_Heroes")
		heroes(col)
		sets["Set_Heroes"] = (K.camera((-20, -200, 70), (8, 0, 42), lens=30, name="CamHeroes", col=col), "oldtown-kit-heroes.jpg", (1800, 1000))
	if "sheet" in only:
		col = K.collection("Set_Sheet")
		cell, ncol, nrow, row = sheet(col, STRUCTURE + PROPS)
		cx, cz = cell * ncol / 2 - cell / 2, -row * (nrow - 1) / 2 + 6
		cam = K.camera((cx, -300, cz + 60), (cx, 0, cz), lens=50, name="CamSheet", col=col)
		cam.data.type = "ORTHO"
		cam.data.ortho_scale = max(cell * ncol, row * nrow * 2000 / 1500) * 1.04
		sets["Set_Sheet"] = (cam, "oldtown-kit-sheet.jpg", (2000, 1500))
	if "--no-render" not in ARGS:
		for name, (cam, fname, res) in sets.items():
			show_only(name)
			bpy.context.scene.camera = cam
			K.render(os.path.join(REF_DIR, fname), res=res)
	show_only("")
	path = os.path.join(OUT_DIR, "Kit_OldTown.blend")
	bpy.ops.wm.save_as_mainfile(filepath=path)
	print("OLDTOWN saved", path)


main()
