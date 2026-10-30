# build_lobby_kit_range.py: the Lobby kit group "Range" (vault/02 Art/Lobby Kit.md, step 4): the hub-side Range
# Lobby (descent frames, viewing window, 1:3 scale model, ENTER gate) and the real range 1,000 studs south (lane
# dividers, distance posts, steel silhouettes, berm, trusses, light bars, formwork wall panels, yard and course trims).
#
# Every piece is a collection Lobby_<Piece> built at the world origin with the Lobby Kit origin conventions:
#   straight pieces (RangeWallPanel*, EnterGate, RangePlinth, RangeEdge): origin on the floor at the centre of the back
#     face, front +X, width along Y.
#   props (TargetStand, LaneDivider, Berm, RangeBench, JerseyBarrier, RangeCrate, DistancePost, RangeFrame): origin
#     on the floor at the centre, front +X. RangeFrame's origin is at the foot of the frame (jambs run 26 up so they
#     reach below the 1:4 ramp).
#   ViewingWindow: origin on the floor in the glass plane, the viewer side is +X.
#   ScaleModel: origin on the floor at the centre of the 44 x 66 model, +X = the viewer side (the mini firing line).
#   Hanging pieces (RangeLightBar): origin at the top centre. RangeTruss: origin at the bottom centre, length along Y.
#   Scalable pieces (RangeSignFrame, RangeRod, RangePlinth, RangeEdge): unit size along their stretch axis with no
#     end chamfers, so Studio can set Size along that axis without distorting the profile.
# 1 Blender unit = 1 stud. Objects are <Piece>_<Part>; Neon parts are separate *_Glow objects.
#
# Run (headless):
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup \
#       --python tools/blender/build_lobby_kit_range.py -- [--no-render] [--samples N]
# Writes art-source/lobby/Kit_Range.blend and vault/02 Art/References/lobby/kit/contact-range.jpg and prints
# RANGE_TRIS (per piece).

import json, math, os, random, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy, bmesh  # noqa: E402
from mathutils import Matrix, Vector, noise  # noqa: E402
import lobbykit as K  # noqa: E402
from gunkit import prism, box, merge, group, ring_pts  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
FY = -8.0  # Range Lobby floor (world), used by the ScaleModel's world-to-kit mapping


# ---------------------------------------------------------------- helpers

def B(x0, x1, y0, y1, z0, z1):
	return box(min(x0, x1), max(x0, x1), min(y0, y1), max(y0, y1), min(z0, z1), max(z0, z1))


def CB(x0, x1, y0, y1, z0, z1, ch=0.1):
	return K.cbox(min(x0, x1), max(x0, x1), min(y0, y1), max(y0, y1), min(z0, z1), max(z0, z1), ch=ch)


def G(*bms):
	return group(*bms)


def vcyl(x, y, r, z0, z1, segs=8):
	return K.cyl(x, y, r, z0, z1, segs=segs)


def ycyl(x, z, r, y0, y1, segs=10):
	return prism(ring_pts(x, z, r, segs, math.pi / segs), "Y", y0, y1)


def xprism(pts, x0, x1):
	# Profile in (y, z), extruded along X.
	return prism(pts, "X", x0, x1)


def yprism(pts, y0, y1):
	# Profile in (x, z), extruded along Y.
	return prism(pts, "Y", y0, y1)


def chamfer_rect(w, h, c):
	# Centred rectangle w x h with corner chamfers c, as (a, b) points.
	a, b = w / 2, h / 2
	return [(-a + c, -b), (a - c, -b), (a, -b + c), (a, b - c), (a - c, b), (-a + c, b), (-a, b - c), (-a, -b + c)]


def tf(bm, m):
	return K.place(bm, m)


class Acc:
	# Accumulates bmeshes per material (one object per material for big composite props).
	def __init__(self):
		self.d = {}

	def add(self, mat, *bms):
		for bm in bms:
			if mat in self.d:
				merge(self.d[mat], bm)
			else:
				self.d[mat] = bm

	def parts(self, names=None):
		out = {}
		for mat, bm in self.d.items():
			part = (names or {}).get(mat, mat)
			out[part] = (bm, mat)
		return out


def extra_materials(mats):
	mats["ConcreteBoardB"] = K._concrete_board("ConcreteBoardB", 0x868480)  # same variant, -4% tone (formwork boards)
	mats["TieHole"] = K._flat("TieHole", 0x4A4844, 0.85, rbx="Concrete")
	mats["RangeFloor"] = K._concrete_polished("RangeFloor", 0xA9ACAF)  # cool polished floor
	mats["LaneLight"] = K._concrete_polished("LaneLight", 0xC9CDD1)
	mats["LinePaint"] = K._flat("LinePaint", 0xEDEEEF, 0.55, rbx="Concrete")
	mats["SafetyYellow"] = K._flat("SafetyYellow", 0xE2B93B, 0.5, rbx="SmoothPlastic")
	mats["TargetPaint"] = K._flat("TargetPaint", 0xE4E6E8, 0.45, metallic=0.3, rbx="Metal")
	mats["TargetMark"] = K._flat("TargetMark", 0x3A3D42, 0.6, rbx="Metal")
	mats["Acoustic"] = K._flat("Acoustic", 0x2E3034, 0.95, rbx="Fabric")
	mats["RubberMat"] = K._flat("RubberMat", 0x2B2D30, 0.9, rbx="Rubber")
	mats["Sandbag"] = K._flat("Sandbag", 0x8A7E66, 0.95, rbx="Fabric")
	earth = K._rock("BermEarth", 0x8E7A5A)  # lifted from the greybox #7A6A55: Ground read as asphalt in Studio
	earth["rbx_material"] = "Ground"
	earth["rbx_variant"] = ""
	mats["BermEarth"] = earth
	mats["SteelPlate"] = K._flat("SteelPlate", 0x5A5F66, 0.45, metallic=0.6, rbx="DiamondPlate")
	mats["AbilityFloor"] = K._concrete_dark("AbilityFloor", 0x5E5B56)
	mats["CourseFloor"] = K._concrete_dark("CourseFloor", 0x9E9A92)
	mats["Foliage"] = K._flat("Foliage", 0x4E6B3C, 0.8, rbx="LeafyGrass")
	mats["Soil"] = K._flat("Soil", 0x3A2F25, 0.95, rbx="Ground")


def piece(name, parts, mats, kit, uv_rotate=()):
	col = K.collection("Lobby_" + name, kit)
	K.build(name, parts, mats, col, uv_rotate=uv_rotate)
	return col


# ---------------------------------------------------------------- hub-side pieces

def p_range_frame(mats, kit):
	# Steel portal over the 1:4 descent: 24 clear, jambs 2 x 2, head at 24..26 above the foot (world y FY-2 .. 16).
	# Face plates front and back stand 0.3 proud of the inner faces, so each jamb carries a lit channel.
	steel = G(CB(-1, 1, 12, 14, 0, 26), CB(-1, 1, -14, -12, 0, 26), CB(-1, 1, -12.05, 12.05, 24, 26))
	plates = bmesh.new()
	for x0, x1 in ((-1.2, -1.0), (1.0, 1.2)):
		merge(plates, B(x0, x1, 11.7, 14.0, 0, 23.7))
		merge(plates, B(x0, x1, -14.0, -11.7, 0, 23.7))
		merge(plates, B(x0, x1, -14.0, 14.0, 23.7, 26.3))
	glow = G(B(-0.15, 0.15, 11.92, 12.0, 0, 23.92), B(-0.15, 0.15, -12.0, -11.92, 0, 23.92), B(-0.15, 0.15, -11.92, 11.92, 23.92, 24.0))
	return piece("RangeFrame", {"Steel": (steel, "SteelBlack"), "Plates": (plates, "SteelBlack"), "Light_Glow": (glow, "Glow_Cool")}, mats, kit)


def p_viewing_window(mats, kit):
	# 44 x 9 glazing over the 3-high sill (world: glass plane z 131, sill face z 130, rail z 127.6). Viewer side +X.
	frame = G(CB(-0.4, 0.4, -22, 22, 11.5, 12.2), CB(-0.4, 0.4, -22, 22, 3.0, 3.5), CB(-0.4, 0.4, 21.4, 22, 3.0, 12.0), CB(-0.4, 0.4, -22, -21.4, 3.0, 12.0))
	for ym in (-15, -9, -3, 3, 9, 15):
		merge(frame, CB(-0.35, 0.35, ym - 0.25, ym + 0.25, 3.5, 11.5, ch=0.08))
	glass = B(-0.04, 0.04, -21.5, 21.5, 3.5, 11.5)
	cap = G(B(0.4, 1.2, -22, 22, 3.0, 3.06), B(1.08, 1.2, -22, 22, 2.55, 3.06))
	kick = B(1.0, 1.1, -22, 22, 0, 0.5)
	rail = ycyl(3.4, 3.45, 0.2, -22, 22, segs=10)
	for y in (-21.5, -7.5, 7.5, 21.5):
		merge(rail, vcyl(3.4, y, 0.12, 0, 3.3, segs=8))
	channel = B(3.25, 3.55, -21.6, 21.6, 3.05, 3.25)
	glow = G(B(1.0, 1.06, -21.8, 21.8, 0.5, 0.6), B(3.3, 3.5, -21.5, 21.5, 2.99, 3.05))
	parts = {
		"Frame": (frame, "SteelBlack"),
		"Glass": (glass, "Glass"),
		"Cap": (cap, "SteelBrushed"),
		"Kick": (G(kick, channel), "SteelBlack"),
		"Rail": (rail, "SteelBrushed"),
		"Light_Glow": (glow, "Glow_Cool"),
	}
	return piece("ViewingWindow", parts, mats, kit)


def p_enter_gate(mats, kit):
	# 12 x 10 opening in a 16 x 12 steel frame, 2 deep (back x 0, front x 2). Lit reveal on the inner faces and a
	# thin cool line across the head plate. Also used for the RANGE STATUS screen and the far EXIT alcove.
	steel = G(CB(0, 2, 6, 8, 0, 12), CB(0, 2, -8, -6, 0, 12), CB(0, 2, -6.05, 6.05, 10, 12))
	plates = G(B(2.0, 2.2, 5.7, 8.2, 0, 9.7), B(2.0, 2.2, -8.2, -5.7, 0, 9.7), B(2.0, 2.2, -8.2, 8.2, 9.7, 12.2))
	sill = B(0, 2.2, -6, 6, 0, 0.04)
	glow = G(B(1.3, 1.7, 5.92, 6.0, 0.1, 9.92), B(1.3, 1.7, -6.0, -5.92, 0.1, 9.92), B(1.3, 1.7, -5.92, 5.92, 9.92, 10.0), B(2.2, 2.26, -7.6, 7.6, 10.9, 11.05))
	parts = {"Frame": (steel, "SteelBlack"), "Plates": (plates, "SteelBlack"), "Sill": (sill, "SteelBrushed"), "Light_Glow": (glow, "Glow_Cool")}
	return piece("EnterGate", parts, mats, kit)


def p_sign_frame(mats, kit):
	# Scalable sign frame: one bar profile (0.6 deep x 0.4, chamfered long edges only, flat ends) 1 long along Y, the
	# charcoal panel and the edge strip as unit boxes. Studio sizes and places each part (ArtKit sign family).
	bar = yprism(chamfer_rect(0.6, 0.4, 0.08), -0.5, 0.5)
	panel = B(-0.2, 0.2, -0.5, 0.5, -0.5, 0.5)
	strip = B(-0.05, 0.05, -0.5, 0.5, -0.5, 0.5)
	return piece("RangeSignFrame", {"Bar": (bar, "SteelBlack"), "Panel": (panel, "SignPanel"), "Strip_Glow": (strip, "Glow_Cool")}, mats, kit)


def p_rod(mats, kit):
	# Scalable round rod (diameter 1, length 1 along Z): hangers and posts.
	return piece("RangeRod", {"Rod": (vcyl(0, 0, 0.5, -0.5, 0.5, segs=10), "SteelBlack")}, mats, kit)


def p_plinth(mats, kit):
	# Scalable wall plinth (1 long along Y): honed concrete 1.5 tall, 0.28 proud, brushed nosing.
	body = yprism([(0, 0), (0.28, 0), (0.28, 1.38), (0, 1.38)], -0.5, 0.5)
	nose = yprism([(0, 1.38), (0.3, 1.38), (0.3, 1.5), (0, 1.5)], -0.5, 0.5)
	return piece("RangePlinth", {"Body": (body, "ConcreteHoned"), "Nosing": (nose, "SteelBrushed")}, mats, kit)


def p_edge(mats, kit):
	# Scalable edge trim (1 long along Y) for course blocks and cover: a brushed steel angle over the top front edge
	# (origin = the edge, block face at x 0, block top at z 0) with a safety-yellow band painted on the top.
	angle = yprism([(-0.4, 0), (0, 0), (0, -0.4), (0.05, -0.4), (0.05, 0.05), (-0.4, 0.05)], -0.5, 0.5)
	band = B(-0.95, -0.4, -0.5, 0.5, 0.0, 0.02)
	return piece("RangeEdge", {"Angle": (angle, "SteelBrushed"), "Band": (band, "SafetyYellow")}, mats, kit)


def wall_panel(cols, rows=3):
	# Board-formed panel: cols x rows boards of 3.2 x 6.4 with V-grooves (each board is a low frustum), two tones
	# (the Lobby_ConcreteBoard variant carries the tie holes). Back at x 0, width along Y centred, z 0..rows*6.4.
	w = cols * 3.2
	a, b = bmesh.new(), bmesh.new()
	for i in range(cols):
		for j in range(rows):
			y0 = -w / 2 + i * 3.2
			z0 = j * 6.4
			y1, z1 = y0 + 3.2, z0 + 6.4
			bm = bmesh.new()
			v = [bm.verts.new(p) for p in ((0, y0, z0), (0, y1, z0), (0, y1, z1), (0, y0, z1))]
			f = [bm.verts.new(p) for p in ((0.1, y0 + 0.05, z0 + 0.05), (0.1, y1 - 0.05, z0 + 0.05), (0.1, y1 - 0.05, z1 - 0.05), (0.1, y0 + 0.05, z1 - 0.05))]
			bm.faces.new((f[0], f[1], f[2], f[3]))
			for k in range(4):
				n = (k + 1) % 4
				bm.faces.new((v[k], v[n], f[n], f[k]))
			bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
			bm.normal_update()
			if sum(fc.normal.x for fc in bm.faces) < 0:
				bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
			tone = (i + j + (1 if (i * 5 + j * 3) % 7 == 0 else 0)) % 2 == 0
			merge(a if tone else b, bm)
	return {"BoardA": (a, "ConcreteBoard"), "BoardB": (b, "ConcreteBoardB")}


def p_wall_panels(mats, kit):
	return [piece("RangeWallPanel", wall_panel(6), mats, kit), piece("RangeWallPanelHalf", wall_panel(3), mats, kit)]


def p_bench(mats, kit):
	# Oak slat bench on black steel frames: 20 long (Y), 3 deep, seat top 1.5 (the greybox Bench collision).
	seat = bmesh.new()
	for k in range(5):
		x0 = -1.45 + k * 0.6
		merge(seat, CB(x0, x0 + 0.5, -10, 10, 1.3, 1.5, ch=0.04))
	steel = bmesh.new()
	for y in (-8.5, 0.0, 8.5):
		merge(steel, B(-1.3, -1.1, y - 0.1, y + 0.1, 0.12, 1.1))
		merge(steel, B(1.1, 1.3, y - 0.1, y + 0.1, 0.12, 1.1))
		merge(steel, B(-1.4, 1.4, y - 0.1, y + 0.1, 1.1, 1.3))
		merge(steel, B(-1.35, 1.35, y - 0.14, y + 0.14, 0, 0.12))
	merge(steel, B(-0.1, 0.1, -9, 9, 0.95, 1.1))
	return piece("RangeBench", {"Seat": (seat, "Oak"), "Frame": (steel, "SteelBlack")}, mats, kit, uv_rotate=("Seat",))


# ---------------------------------------------------------------- real range pieces

def lane_divider(acc, m=Matrix.Identity(4), lod=False):
	# Stall divider, 6 long (X, +X = downrange end), 0.6 thick, 7 tall: steel posts and cap, acoustic infill, kick
	# plate, a gun shelf on both faces at the shooter end, and a cool line down the back post.
	if lod:
		acc.add("SteelBlack", tf(G(B(-3, 3, -0.3, 0.3, 6.6, 7.0), B(-3.0, -2.6, -0.3, 0.3, 0, 6.6), B(2.6, 3.0, -0.3, 0.3, 0, 6.6)), m))
		acc.add("Acoustic", tf(B(-2.6, 2.6, -0.25, 0.25, 0, 6.6), m))
		acc.add("SteelBrushed", tf(G(B(-2.6, -0.6, 0.25, 1.1, 3.3, 3.5), B(-2.6, -0.6, -1.1, -0.25, 3.3, 3.5)), m))
		return
	acc.add("SteelBlack", tf(G(CB(2.6, 3.0, -0.35, 0.35, 0, 7.0, ch=0.06), CB(-3.0, -2.6, -0.35, 0.35, 0, 7.0, ch=0.06), CB(-2.62, 2.62, -0.33, 0.33, 6.6, 7.0, ch=0.06)), m))
	acc.add("Acoustic", tf(B(-2.6, 2.6, -0.25, 0.25, 0.6, 6.6), m))
	shelf = bmesh.new()
	for s in (1, -1):
		merge(shelf, B(-2.6, -0.5, s * 0.25, s * 1.15, 3.25, 3.4))
		merge(shelf, B(-2.4, -2.2, s * 0.25, s * 0.95, 2.6, 3.25))
		merge(shelf, B(-0.9, -0.7, s * 0.25, s * 0.95, 2.6, 3.25))
	acc.add("SteelBrushed", tf(G(B(-2.6, 2.6, -0.32, 0.32, 0, 0.6), shelf), m))
	acc.add("Oak", tf(G(B(-2.55, -0.55, 0.3, 1.12, 3.4, 3.48), B(-2.55, -0.55, -1.12, -0.3, 3.4, 3.48)), m))
	acc.add("Glow_Cool", tf(B(-3.06, -3.0, -0.08, 0.08, 0.7, 6.4), m))


def p_lane_divider(mats, kit):
	acc = Acc()
	lane_divider(acc)
	return piece("LaneDivider", acc.parts({"SteelBlack": "Frame", "Acoustic": "Infill", "SteelBrushed": "Shelf", "Oak": "ShelfTop", "Glow_Cool": "Light_Glow"}), mats, kit, uv_rotate=("ShelfTop",))


def target(acc, m=Matrix.Identity(4), lod=False):
	# Steel silhouette (IPSC-like), painted light grey: 1.9 wide body z 1.3..3.8, head to 5.1, on a post and a sloped
	# deflector base. Front +X. A-zone and head-zone outlines painted dark.
	body = [(-0.8, 1.3), (0.8, 1.3), (0.95, 3.2), (0.55, 3.8), (-0.55, 3.8), (-0.95, 3.2)]
	plate = G(xprism(body, -0.08, 0.08), B(-0.08, 0.08, -0.22, 0.22, 3.75, 4.05), xprism(ring_pts(0, 4.55, 0.55, 8 if not lod else 6, math.pi / 8), -0.08, 0.08))
	acc.add("TargetPaint", tf(plate, m))
	base = G(B(-0.12, 0.12, -0.12, 0.12, 0.5, 1.35), yprism([(-0.9, 0), (0.9, 0), (0.25, 0.55), (-0.25, 0.55)], -0.9, 0.9))
	if not lod:
		merge(base, B(-1.0, 1.0, -1.0, 1.0, 0, 0.05))
	acc.add("SteelBlack", tf(base, m))
	if not lod:
		mk = bmesh.new()
		for y0, y1, z0, z1 in ((-0.45, 0.45, 2.3, 3.25), (-0.25, 0.25, 4.3, 4.8)):
			merge(mk, B(0.08, 0.1, y0, y1, z0, z0 + 0.05))
			merge(mk, B(0.08, 0.1, y0, y1, z1 - 0.05, z1))
			merge(mk, B(0.08, 0.1, y0, y0 + 0.05, z0, z1))
			merge(mk, B(0.08, 0.1, y1 - 0.05, y1, z0, z1))
		acc.add("TargetMark", tf(mk, m))
		acc.add("SafetyYellow", tf(yprism([(0.7375, 0.1375), (0.6075, 0.2475), (0.627, 0.27), (0.757, 0.16)], -0.88, 0.88), m))


def p_target(mats, kit):
	acc = Acc()
	target(acc)
	return piece("TargetStand", acc.parts({"TargetPaint": "Plate", "SteelBlack": "Stand", "TargetMark": "Marks", "SafetyYellow": "Stripe"}), mats, kit)


def berm_surface(width, toe, crest, back, height, nu, nv, amp, seed):
	# Earth berm as one heightfield: slope from the toe (x = toe, z 0) up to the crest (x = crest, z = height), flat top
	# to x = back, a back face and end caps. Offsets push the surface out of the collision by 0..amp along the slope
	# normal; they depend only on (x, z) at the two ends, so neighbouring pieces meet exactly.
	rnd = random.Random(seed)
	off = Vector((rnd.uniform(0, 99), rnd.uniform(0, 99), rnd.uniform(0, 99)))
	hw = width / 2
	sx, sz = crest - toe, height
	n_slope = Vector((sz, 0, -sx)).normalized()
	if n_slope.x * (1 if toe > crest else -1) < 0:
		n_slope = -n_slope
	stations = []
	for i in range(nu + 1):
		t = i / nu
		stations.append((toe + sx * t, height * t, "s"))
	ntop = 3
	for i in range(1, ntop + 1):
		stations.append((crest + (back - crest) * i / ntop, height, "t"))
	bm = bmesh.new()
	grid = []
	for k, (x, z, kind) in enumerate(stations):
		row = []
		for j in range(nv + 1):
			y = -hw + width * j / nv
			edge = j in (0, nv)
			if not edge:
				y += rnd.uniform(-0.3, 0.3) * width / nv
			q = Vector((x * 0.35, (0 if edge else y) * 0.35, z * 0.35)) + off
			h = 0.5 + 0.5 * max(-1.0, min(1.0, noise.noise(q) * 1.4 + 0.4 * noise.noise(q * 2.7)))
			d = amp * h
			if k == 0 or k == len(stations) - 1:
				d = 0.0
			if kind == "s":
				p = Vector((x, y, z)) + n_slope * d
			else:
				p = Vector((x, y, z + d))
			row.append(bm.verts.new(p))
		grid.append(row)
	for k in range(len(stations) - 1):
		for j in range(nv):
			a0, a1, b1, b0 = grid[k][j], grid[k][j + 1], grid[k + 1][j + 1], grid[k + 1][j]
			if rnd.random() < 0.5:
				bm.faces.new((a0, a1, b1))
				bm.faces.new((a0, b1, b0))
			else:
				bm.faces.new((a0, a1, b0))
				bm.faces.new((a1, b1, b0))
	bot = [bm.verts.new((back, -hw + width * j / nv, 0.0)) for j in range(nv + 1)]
	last = grid[-1]
	for j in range(nv):
		bm.faces.new((last[j], last[j + 1], bot[j + 1], bot[j]))
	for j in (0, nv):
		ring = [grid[k][j] for k in range(len(stations))] + [bot[j]]
		bm.faces.new(ring)
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	bm.normal_update()
	# Outward check: the slope should face +X (toward the shooter) when toe > crest.
	sl = [f for f in bm.faces if len(f.verts) == 3]
	if sl and sum(f.normal.x for f in sl) < 0:
		bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
	return bm


def berm(acc, m, width=24.0, toe=7.0, crest=-1.0, back=-7.0, height=14.0, lod=False, seed=11):
	s = height / 14.0
	acc.add("BermEarth", tf(berm_surface(width, toe, crest, back, height, 5 if lod else 6, 6 if lod else 8, 0.25 * s, seed), m))
	rnd = random.Random(seed + 5)
	rocks = bmesh.new()
	for k in range(2 if lod else 3):
		t = rnd.uniform(0.15, 0.7)
		x = toe + (crest - toe) * t
		z = height * t
		y = -width / 2 + width * (k + 0.5) / (2 if lod else 3) + rnd.uniform(-1.5, 1.5) * s
		sz = (rnd.uniform(2.2, 3.2) * s, rnd.uniform(2.4, 3.6) * s, rnd.uniform(1.6, 2.4) * s)
		merge(rocks, K.rock_chunk(seed * 13 + k, size=sz, center=(x + 0.25 * s, y, z - 0.2 * s), points=12 if lod else 16, jag=0.25))
	acc.add("Rock", tf(rocks, m))
	bags = bmesh.new()
	# Sandbag revetment at the toe: two staggered courses lying on the slope, half bedded in the earth (they stand
	# at most 0.25 proud of the collision face), plus a plain course along the crest.
	L = math.hypot(crest - toe, height)
	u = Vector(((crest - toe) / L, 0, height / L))
	nrm = Vector((height / L, 0, -(crest - toe) / L))
	n = 6 if lod else 10
	pitch = width / n
	bw, bt = 1.1 * s, 0.5 * s
	for row in range(2):
		t = (0.55 * s + row * 1.05 * s) / L
		for i in range(n - row):
			yc = -width / 2 + pitch * (i + 0.5 + 0.5 * row)
			bl = pitch * 0.95
			bg = CB(-bt / 2, bt / 2, -bl / 2, bl / 2, -bw / 2, bw / 2, ch=0.12 * s) if not lod else B(-bt / 2, bt / 2, -bl / 2, bl / 2, -bw / 2, bw / 2)
			c = Vector((toe + (crest - toe) * t, yc, height * t)) + nrm * (0.25 * s - bt / 2 + rnd.uniform(-0.04, 0.04) * s)
			mm = Matrix(((nrm.x, 0, u.x, c.x), (0, 1, 0, c.y), (nrm.z, 0, u.z, c.z), (0, 0, 0, 1)))
			tf(bg, mm @ Matrix.Rotation(math.radians(rnd.uniform(-3, 3)), 4, "X"))
			merge(bags, bg)
	for i in range(n):
		yc = -width / 2 + pitch * (i + 0.5)
		bg = B(-0.5 * s, 0.5 * s, -pitch * 0.47, pitch * 0.47, 0, 0.45 * s)
		tf(bg, Matrix.Translation((crest - 0.7 * s, yc, height - 0.05 * s)) @ Matrix.Rotation(math.radians(rnd.uniform(-4, 4)), 4, "Z"))
		merge(bags, bg)
	acc.add("Sandbag", tf(bags, m))


def p_berm(mats, kit):
	acc = Acc()
	berm(acc, Matrix.Identity(4))
	return piece("Berm", acc.parts({"BermEarth": "Earth", "Rock": "Rocks", "Sandbag": "Bags"}), mats, kit)


def truss(acc, m, length=24.0, h=3.0, chord=0.5, depth=0.8, web=0.3, bays=4, lod=False):
	hl = length / 2
	st = G(B(-depth / 2, depth / 2, -hl, hl, h - chord, h), B(-depth / 2, depth / 2, -hl, hl, 0, chord))
	for k in range(bays):
		ya = -hl + length * k / bays
		yb = ya + length / bays
		merge(st, B(-web / 2, web / 2, ya, ya + web, chord, h - chord))
		if k % 2 == 0:
			pts = [(ya + web, chord), (ya + web + web * 1.4, chord), (yb, h - chord), (yb - web * 1.4, h - chord)]
		else:
			pts = [(yb - web * 1.4, chord), (yb, chord), (ya + web + web * 1.4, h - chord), (ya + web, h - chord)]
		merge(st, xprism(pts, -web / 2, web / 2))
	acc.add("SteelBlack", tf(st, m))


def p_truss(mats, kit):
	acc = Acc()
	truss(acc, Matrix.Identity(4))
	return piece("RangeTruss", acc.parts({"SteelBlack": "Steel"}), mats, kit)


def p_light_bar(mats, kit):
	# Linear luminaire, 12 long (Y), hung on two rods from its top (origin at the top of the rods, z 0 = 1 above it).
	housing = G(CB(-0.35, 0.35, -6, 6, -1.45, -1.0, ch=0.05), vcyl(0, 4.5, 0.06, -1.0, 0, 6), vcyl(0, -4.5, 0.06, -1.0, 0, 6))
	glow = B(-0.2, 0.2, -5.9, 5.9, -1.5, -1.45)
	return piece("RangeLightBar", {"Housing": (housing, "SteelBlack"), "Diffuser_Glow": (glow, "Glow_Cool")}, mats, kit)


def p_distance_post(mats, kit):
	# Lane-edge distance marker: a 0.4 steel post to 5 and a 3.4 x 1.9 sign frame centred at z 6 (front +X); the
	# number is a SurfaceGui in Studio.
	steel = G(B(-0.2, 0.2, -0.2, 0.2, 0, 5.05), B(-0.5, 0.5, -0.5, 0.5, 0, 0.08))
	e = 0.2
	w, h, zc = 3.4, 1.9, 6.0
	frame = bmesh.new()
	for zz in (zc - h / 2 + e / 2, zc + h / 2 - e / 2):
		bar = yprism(chamfer_rect(0.3, e, 0.04), -w / 2, w / 2)
		tf(bar, Matrix.Translation((0, 0, zz)))
		merge(frame, bar)
	for yy in (-w / 2 + e / 2, w / 2 - e / 2):
		bar = xprism([(yy - e / 2, zc - h / 2 + e), (yy + e / 2, zc - h / 2 + e), (yy + e / 2, zc + h / 2 - e), (yy - e / 2, zc + h / 2 - e)], -0.15, 0.15)
		merge(frame, bar)
	merge(steel, frame)
	panel = B(-0.1, 0.1, -w / 2 + e, w / 2 - e, zc - h / 2 + e + 0.15, zc + h / 2 - e)
	strip = B(0.0, 0.1, -w / 2 + e, w / 2 - e, zc - h / 2 + e, zc - h / 2 + e + 0.15)
	return piece("DistancePost", {"Steel": (steel, "SteelBlack"), "Panel": (panel, "SignPanel"), "Strip_Glow": (strip, "Glow_Cool")}, mats, kit)


def p_jersey(mats, kit):
	# Precast jersey barrier for the cover yard: 8 long (Y), 3.6 tall, base 2.0, top 1.0 (the greybox LowCover is
	# 8 x 3.6 x 1.5), with reflector tabs and two lifting slots.
	prof = [(-1.0, 0), (1.0, 0), (1.0, 0.25), (0.78, 0.95), (0.5, 3.48), (0.38, 3.6), (-0.38, 3.6), (-0.5, 3.48), (-0.78, 0.95), (-1.0, 0.25)]
	body = yprism(prof, -3.98, 3.98)
	tabs = bmesh.new()
	for y in (-2.5, 2.5):
		for s in (1, -1):
			tb = B(-0.06, 0.06, y - 0.35, y + 0.35, 2.7, 2.95)
			tf(tb, Matrix.Translation((s * 0.585, 0, 0)) @ Matrix.Rotation(math.radians(-6.3 * s), 4, "Y"))
			merge(tabs, tb)
	slots = G(B(-1.01, 1.01, -2.8, -2.0, 0.0, 0.35), B(-1.01, 1.01, 2.0, 2.8, 0.0, 0.35))
	return piece("JerseyBarrier", {"Body": (body, "ConcreteHoned"), "Tabs": (tabs, "SafetyYellow"), "Slots": (slots, "SteelBlack")}, mats, kit)


def p_crate(mats, kit):
	# Ammo crate, 4 long x 2.4 deep x 2.2 tall: oak body, darker battens, black steel corner caps and a stencil plate.
	body = CB(-1.2, 1.2, -2.0, 2.0, 0.1, 2.1, ch=0.04)
	battens = bmesh.new()
	for y in (-1.6, 1.6):
		merge(battens, CB(-1.28, 1.28, y - 0.18, y + 0.18, 0.05, 2.18, ch=0.03))
	merge(battens, CB(-1.26, 1.26, -2.06, 2.06, 1.6, 1.82, ch=0.03))
	caps = bmesh.new()
	for x in (-1.2, 1.2):
		for y in (-2.0, 2.0):
			for z0, z1 in ((0.0, 0.45), (1.75, 2.2)):
				merge(caps, B(x - 0.12, x + 0.12, y - 0.12, y + 0.12, z0, z1))
	plate = B(1.28, 1.31, -0.9, 0.9, 0.55, 1.35)
	return piece("RangeCrate", {"Body": (body, "Oak"), "Battens": (battens, "Oak"), "Caps": (caps, "SteelBlack"), "Plate": (plate, "SafetyYellow")}, mats, kit, uv_rotate=("Body", "Battens"))


# ---------------------------------------------------------------- the scale model (hero)

def W(xw, zw, hy=0.0):
	# Mini-range world (x, z) and height above the Range Lobby floor -> ScaleModel kit space (origin (0, FY, 165),
	# kit +X = north = the viewer side, kit +Y = west).
	return (165.0 - zw, -xw, hy)


def wbox(x0, x1, z0, z1, h0, h1):
	a, b = W(x0, z0), W(x1, z1)
	return B(a[0], b[0], a[1], b[1], h0, h1)


def wmat(xw, zw, hy=0.0, scale=1.0, face_north=True):
	p = W(xw, zw, hy)
	return Matrix.Translation(p) @ Matrix.Scale(scale, 4)


# The model is a diorama of the whole practice floor: depths and heights at 1:3 (the hub's distance boards hang at
# FZ + d / 3), lane widths at 1:4 (lanes 3 wide, so the yards fit beside them) and the yards' layout squeezed into
# the strips between the lane walls and the room walls (their blocks keep 1:4 x 1:3 x 1:3 sizes).
FZ = 135.0  # mini firing line (real FL 1214)
XL = 21.95  # room half width (core walls)


def mz(rz):
	return FZ + (1214.0 - rz) / 3


def mxl(rx):
	# Lanes: real x / 4, mirrored (the viewer looks south, so real west = mini east = the viewer's left).
	return -rx / 4.0


def mxy(rx):
	# Yards: real |x| 47 (lane wall) .. 120 (hall wall) squeezed into mini 11.75 .. 21.35.
	s = 1.0 if rx < 0 else -1.0
	return s * (11.75 + (abs(rx) - 47.0) * (9.6 / 73.0))


def ybox(rx, rz, sx, sz, h0, h1, lanes=False):
	# A real block (centre rx, rz; footprint sx x sz; heights h0..h1) in the mini.
	cx = mxl(rx) if lanes else mxy(rx)
	cz = mz(rz)
	return wbox(cx - sx / 8, cx + sx / 8, cz - sz / 6, cz + sz / 6, h0 / 3, h1 / 3)


def p_scale_model(mats, kit):
	acc = Acc()
	END = mz(1044)  # berm toe
	LW = 10.5  # lanes half width (7 x 3)
	acc.add("RangeFloor", wbox(-XL, XL, 132, 197.95, 0, 0.04))
	acc.add("RubberMat", wbox(-LW, LW, 132.1, FZ - 0.15, 0.04, 0.06))
	for i in (1, 3, 5, 7):
		cx = mxl(-48 + 12 * i)
		acc.add("LaneLight", wbox(cx - 1.5, cx + 1.5, FZ, END, 0.04, 0.06))
	for k in range(8):
		x = -LW + 3 * k
		w = 0.2 if k in (0, 7) else 0.12
		acc.add("LinePaint", wbox(x - w / 2, x + w / 2, FZ, END, 0.06, 0.075))
	for d in (10, 25, 50, 100, 150):
		z = FZ + d / 3
		acc.add("LinePaint", wbox(-LW, LW, z - 0.07, z + 0.07, 0.06, 0.075))
	acc.add("SafetyYellow", wbox(-LW, LW, FZ - 0.15, FZ + 0.15, 0.04, 0.085))
	# Shooter stalls: the real LaneDivider at 1/3 and the lane header beam with its light line (the lane numbers are
	# painted on the floor in Studio, so nothing tall stands between the window and the lanes).
	for k in range(8):
		x = -LW + 3 * k
		lane_divider(acc, Matrix.Translation(W(x, FZ - 1.17)) @ Matrix.Rotation(math.pi, 4, "Z") @ Matrix.Diagonal((1 / 3, 1 / 3, 1 / 3, 1)), lod=True)
	acc.add("SteelBlack", wbox(-LW - 0.2, LW + 0.2, FZ - 1.3, FZ - 0.95, 2.33, 2.53))
	acc.add("Glow_Cool", wbox(-LW, LW, FZ - 1.2, FZ - 1.05, 2.3, 2.33))
	# Steel silhouettes at the real distances, 1/3 scale, facing the viewer; lane 1 on the viewer's left as it is for a
	# shooter in the real range.
	for i, d in enumerate((10, 25, 50, 150, 100, 50, 25), start=1):
		target(acc, Matrix.Translation(W(mxl(-48 + 12 * i), FZ + d / 3)) @ Matrix.Scale(1 / 3, 4), lod=True)
	# Long platform on lane 7 (real x 32..40, z 1110..1118, 6 tall) with its yellow nosing.
	acc.add("ConcreteBoard", ybox(36, 1114, 8, 8, 0, 6, lanes=True))
	acc.add("SafetyYellow", wbox(mxl(36) - 1, mxl(36) + 1, mz(1118) - 0.06, mz(1118) + 0.06, 1.9, 2.03))
	# Lane walls (real x +-47, 4 tall, z 1044..1206) between the lanes and the yards, with brushed steel caps.
	for rx in (-47, 47):
		cx = mxl(rx)
		acc.add("ConcreteBoard", wbox(cx - 0.25, cx + 0.25, mz(1206), END, 0, 4 / 3))
		acc.add("SteelBrushed", wbox(cx - 0.3, cx + 0.3, mz(1206), END, 4 / 3, 4 / 3 + 0.06))
	# Berm at 1/3 between the lane walls (real toe 1044, crest 1036, back 1030; height 14).
	toe, crest, back = W(0, END)[0], W(0, mz(1036))[0], W(0, mz(1030))[0]
	berm(acc, Matrix.Identity(4), width=2 * 12.0, toe=toe, crest=crest, back=back, height=14 / 3, lod=True, seed=29)
	# Board-formed side walls: pilasters at the real pilaster stations (z 1040..1200 every 40 -> 1/3).
	for zr in (1040, 1080, 1120, 1160, 1200):
		zc = mz(zr)
		for s in (-1, 1):
			acc.add("ConcreteBoard", wbox(s * XL, s * (XL - 0.6), zc - 0.35, zc + 0.35, 0, 12.0))
	# Back wall title plate (PRACTICE RANGE, a SurfaceGui in Studio) and the trusses with their light lines.
	acc.add("SteelBlack", wbox(-14.3, 14.3, 197.75, 197.95, 7.85, 11.75))
	acc.add("SignPanel", wbox(-14.0, 14.0, 197.6, 197.75, 8.1, 11.5))
	for zr in (1060, 1096, 1132, 1168, 1204):
		zc = mz(zr)
		tm = Matrix.Translation(W(0, zc, 11.0)) @ Matrix.Diagonal((0.6, 1.0, 1 / 3, 1))
		truss(acc, tm, length=2 * XL, h=3.0, chord=0.5, depth=0.8, web=0.4, bays=6, lod=True)
		acc.add("Glow_Cool", wbox(-20, 20, zc - 0.12, zc + 0.12, 10.9, 10.98))
	names = {"Glow_Cool": "Lights_Glow"}
	return piece("ScaleModel", acc.parts(names), mats, kit, uv_rotate=())


def p_scale_yards(mats, kit):
	# The yards beside the mini lanes (same origin as ScaleModel): cover + ability yard on the viewer's left (real
	# west), the movement course on the right (real east). Real positions from the RangeFar greybox.
	acc = Acc()
	X0, X1 = 12.05, XL - 0.6
	zc0, zc1 = 132.1, 197.9
	# Floors (paint-thin, over the model floor).
	acc.add("ConcreteDark", wbox(X0, X1, zc0, mz(1154), 0.04, 0.06))
	acc.add("AbilityFloor", wbox(X0, X1, mz(1148), mz(1064), 0.04, 0.06))
	paint = bmesh.new()
	merge(paint, wbox(X0, X1, mz(1214) - 0.12, mz(1214) + 0.12, 0.06, 0.08))
	for rz in (1148, 1064):
		merge(paint, wbox(X0, X1, mz(rz) - 0.06, mz(rz) + 0.06, 0.06, 0.08))
	grid = bmesh.new()
	for k in range(1, 4):
		x = X0 + (X1 - X0) * k / 4
		merge(grid, wbox(x - 0.05, x + 0.05, mz(1148) + 0.3, mz(1064) - 0.3, 0.06, 0.07))
	for rz in (1127, 1106, 1085):
		merge(grid, wbox(X0 + 0.3, X1 - 0.3, mz(rz) - 0.05, mz(rz) + 0.05, 0.06, 0.07))
	acc.add("LinePaint", grid)
	acc.add("CourseFloor", wbox(-X1, -X0, zc0, zc1, 0.04, 0.06))
	acc.add("LaneLight", wbox(mxy(67), mxy(57), mz(1252), mz(1094), 0.06, 0.075))
	for rz in range(1100, 1251, 25):
		merge(paint, wbox(mxy(67), mxy(57), mz(rz) - 0.05, mz(rz) + 0.05, 0.075, 0.085))
	# Cover yard: three pillars, the jersey barrier, the solid wall and the steel plate wall.
	blocks = bmesh.new()
	for rx in (-100, -80, -60):
		merge(blocks, ybox(rx, 1204, 3, 3, 0, 10))
	merge(blocks, ybox(-94, 1190.8, 10, 1.5, 0, 9))
	# Course: jump boxes (2 .. 6.5 tall), gap platforms, crouch walls.
	for rz, h in ((1201, 2), (1192, 3.5), (1183, 5), (1174, 6.5)):
		merge(blocks, ybox(80, rz, 6, 6, 0, h))
	for rz, d in ((1135, 8), (1156, 8), (1174, 8), (1189, 10)):
		merge(blocks, ybox(98, rz, 8, d, 0, 3))
	acc.add("ConcreteBoard", blocks)
	honed = G(ybox(-62, 1188.8, 8, 2, 0, 3.6), ybox(-116.6, 1176, 2, 8, 0, 3.6), ybox(-116.6, 1186, 2, 8, 0, 3.6))
	acc.add("ConcreteHoned", honed)
	acc.add("SteelPlate", ybox(-76, 1194, 10, 0.6, 0, 9))
	steel = bmesh.new()
	for rz in (1066, 1080, 1094):
		cx, cz = mxy(80), mz(rz)
		merge(steel, wbox(cx - 1.25, cx + 1.25, cz - 0.2, cz + 0.2, 0.75, 1.07))
		for s in (-1, 1):
			merge(steel, wbox(cx + s * 1.25 - 0.1, cx + s * 1.25 + 0.1, cz - 0.2, cz + 0.2, 0, 0.75))
	acc.add("SteelBlack", steel)
	# Yellow nosings on the course tops and pillar caps (the real course's RangeEdge trims).
	for rz, h in ((1201, 2), (1192, 3.5), (1183, 5), (1174, 6.5)):
		merge(paint, wbox(mxy(80) - 0.75, mxy(80) + 0.75, mz(rz) - 1.0, mz(rz) - 0.88, h / 3, h / 3 + 0.03))
	for rz, d in ((1135, 8), (1156, 8), (1174, 8), (1189, 10)):
		for s in (-1, 1):
			z = mz(rz) + s * (d / 6 - 0.06)
			merge(paint, wbox(mxy(98) - 1.0, mxy(98) + 1.0, z - 0.06, z + 0.06, 1.0, 1.03))
	for rx in (-100, -80, -60):
		merge(paint, wbox(mxy(rx) - 0.375, mxy(rx) + 0.375, mz(1204) - 0.5, mz(1204) + 0.5, 10 / 3, 10 / 3 + 0.03))
	acc.add("SafetyYellow", paint)
	# Crates against the walls (the real dressing).
	# (The crate stack at real z 1252..1257 would fall outside the model, in front of the window.)
	oak = bmesh.new()
	for rz in (1150, 1154.5):
		merge(oak, ybox(116.4, rz, 2.4, 4, 0, 2.2))
	acc.add("Oak", oak)
	return piece("ScaleModelYards", acc.parts({"SteelPlate": "Plate", "SteelBlack": "Steel"}), mats, kit, uv_rotate=())


def p_planter(mats, kit):
	# Board-formed trough 8 long (Y) x 2.4 deep x 1.8 tall with an oak cap, soil and a few low faceted shrubs (a
	# bunker keeps its plants few and low). Origin on the floor at the centre, front +X.
	body = G(CB(-1.2, 1.2, -4, 4, 0, 1.6, ch=0.08), B(-1.2, -1.0, -4, 4, 1.6, 1.8), B(1.0, 1.2, -4, 4, 1.6, 1.8), B(-1.0, 1.0, -4, -3.8, 1.6, 1.8), B(-1.0, 1.0, 3.8, 4, 1.6, 1.8))
	cap = G(CB(-1.3, 1.3, -4.1, -3.78, 1.8, 1.95, ch=0.03), CB(-1.3, 1.3, 3.78, 4.1, 1.8, 1.95, ch=0.03), CB(-1.3, -0.98, -3.78, 3.78, 1.8, 1.95, ch=0.03), CB(0.98, 1.3, -3.78, 3.78, 1.8, 1.95, ch=0.03))
	soil = B(-1.0, 1.0, -3.8, 3.8, 1.6, 1.74)
	kick = B(-1.22, 1.22, -4.02, 4.02, 0, 0.18)
	leaves = bmesh.new()
	rnd = random.Random(7)
	spots = ((-2.9, 1.1, 1.3), (-1.6, 1.5, 1.6), (-0.2, 1.2, 1.1), (1.1, 1.7, 1.8), (2.5, 1.2, 1.3), (3.2, 0.9, 1.0))
	for k, (y, sz, h) in enumerate(spots):
		x = rnd.uniform(-0.25, 0.25)
		merge(leaves, K.rock_chunk(40 + k, size=(sz, sz * 1.1, h), center=(x, y, 1.72), points=14, jag=0.32, flat_base=True))
	parts = {"Body": (body, "ConcreteBoard"), "Kick": (kick, "ConcreteHoned"), "Cap": (cap, "Oak"), "Soil": (soil, "Soil"), "Leaves": (leaves, "Foliage")}
	return piece("RangePlanter", parts, mats, kit, uv_rotate=("Cap",))


# ---------------------------------------------------------------- contact sheet

def sheet(pieces, mats, tris):
	sc = bpy.context.scene
	stage = K.collection("Sheet")
	w = sc.world or bpy.data.worlds.new("World")
	sc.world = w
	w.use_nodes = True
	bg = w.node_tree.nodes.get("Background")
	if bg:
		bg.inputs[0].default_value = (*K.lin(0x4A5260), 1)
		bg.inputs[1].default_value = 1.2
	cell = 34.0
	ncol = 6
	nrow = (len(pieces) + ncol - 1) // ncol
	floor = K.add_obj("SheetFloor", B(-cell * (nrow - 0.4), cell * 0.6, -cell * 0.6, cell * (ncol - 0.4), -0.2, 0), [mats["ConcreteHoned"]], stage)
	floor["preview_only"] = True
	for idx, (name, col) in enumerate(pieces):
		r, c = divmod(idx, ncol)
		lo = Vector((1e9, 1e9, 1e9))
		hi = -lo
		for ob in col.all_objects:
			if ob.type != "MESH":
				continue
			for v in ob.data.vertices:
				for i in range(3):
					lo[i] = min(lo[i], v.co[i])
					hi[i] = max(hi[i], v.co[i])
		size = hi - lo
		s = min(4.0, 24.0 / max(size.x, size.y, size.z, 0.01))
		ctr = (lo + hi) / 2
		px, py = -r * cell, c * cell
		m = Matrix.Translation((px, py, 0)) @ Matrix.Scale(s, 4) @ Matrix.Translation((-ctr.x, -ctr.y, -lo.z))
		e = bpy.data.objects.new("Sheet_" + name, None)
		e.instance_type = "COLLECTION"
		e.instance_collection = col
		e.matrix_world = m
		stage.objects.link(e)
		label = "%s  %d tris  %.0fx%.0fx%.0f%s" % (name, tris[name], size.x, size.y, size.z, "" if s == 1 else "  (x%.2f)" % s)
		K.text(label, 1.3, (px + 14.5, py, 0.05), stage, mats["SignText"], rot=(0, 0, 90), font=K.FONT_LABEL)
	sun = bpy.data.lights.new("SheetSun", "SUN")
	sun.energy = 3.5
	sun.angle = math.radians(2)
	so = bpy.data.objects.new("SheetSun", sun)
	stage.objects.link(so)
	so.rotation_euler = (math.radians(40), math.radians(-25), math.radians(200))
	rows = (len(pieces) + ncol - 1) // ncol
	cx, cy = -(rows - 1) * cell / 2, (ncol - 1) * cell / 2
	cam = K.camera((cx + 260, cy + 60, 250), (cx, cy, 4), lens=50, name="SheetCam", col=stage)
	cam.data.type = "ORTHO"
	cam.data.ortho_scale = cell * ncol * 1.05
	K.render_settings(samples=int(ARGS[ARGS.index("--samples") + 1]) if "--samples" in ARGS else 24)
	try:
		sc.eevee.use_raytracing = False
	except AttributeError:
		pass
	K.bloom(strength=0.4)


def main():
	mats = K.begin()
	extra_materials(mats)
	kit = K.collection("Kit")
	built = [
		("RangeFrame", p_range_frame(mats, kit)),
		("ViewingWindow", p_viewing_window(mats, kit)),
		("ScaleModel", p_scale_model(mats, kit)),
		("ScaleModelYards", p_scale_yards(mats, kit)),
		("RangePlanter", p_planter(mats, kit)),
		("EnterGate", p_enter_gate(mats, kit)),
		("LaneDivider", p_lane_divider(mats, kit)),
		("TargetStand", p_target(mats, kit)),
		("Berm", p_berm(mats, kit)),
		("RangeTruss", p_truss(mats, kit)),
		("RangeLightBar", p_light_bar(mats, kit)),
		("DistancePost", p_distance_post(mats, kit)),
		("JerseyBarrier", p_jersey(mats, kit)),
		("RangeCrate", p_crate(mats, kit)),
		("RangeBench", p_bench(mats, kit)),
	]
	wp, wph = p_wall_panels(mats, kit)
	built += [("RangeWallPanel", wp), ("RangeWallPanelHalf", wph)]
	built += [("RangeSignFrame", p_sign_frame(mats, kit)), ("RangeRod", p_rod(mats, kit)), ("RangePlinth", p_plinth(mats, kit)), ("RangeEdge", p_edge(mats, kit))]
	tris = {}
	worst = {}
	for name, col in built:
		tris[name] = K.tri_count(col)
		for ob in col.all_objects:
			if ob.type == "MESH":
				ob.data.calc_loop_triangles()
				worst[ob.name] = len(ob.data.loop_triangles)
	print("RANGE_TRIS " + json.dumps(tris))
	print("RANGE_MAX_OBJECT " + json.dumps(max(worst.items(), key=lambda kv: kv[1])))
	sheet(built, mats, tris)
	bpy.context.view_layer.layer_collection.children["Kit"].exclude = True
	path = K.save("Kit_Range")
	print("RANGE saved", path)
	if "--no-render" not in ARGS:
		K.render(os.path.join(K.RENDER_DIR, "contact-range.jpg"), res=(2200, 1500))


main()
