# build_map_kit_dockyard.py: the Dockyard map kit (vault/01 Design/Maps/Dockyard.md), one kit group "Kit".
#
# Every piece is a collection Map_<Piece> built at the world origin. Pieces are authored in ROBLOX map-local
# coordinates (studs, +Y up) through rb()/RB() and converted to Blender (x, -z, y), so a vertex at Roblox (x, y, z)
# lands back at (x, y, z) after export (kit_bundle.py maps Blender (x, y, z) -> Roblox (x, z, -y)). Origins (Roblox
# local):
#   C40 / C20     floor centre; long axis along Z (32 / 16), 8 wide, 8 tall; the doors are on the +Z end.
#                 Body and Frame take the lane colour per instance in Studio (Art.luau); Hardware stays dark.
#   Stair         floor centre of an 8 x 16 footprint, rising 8 toward +Z (the greybox WedgePart's own axes).
#   Crane         the gantry crane centred on the map: legs at (+-30, +-16), girders at 52-56, spreader over the stack.
#   Shed          floor centre of the 26 x 36 shed (B half: map (55, 42)); roller door on -Z, two doors on -X, the
#                 water side +X. Shed_Stripe takes the lane colour.
#   Office, Rack, Crate   floor centre (Office door on -X, Rack long along Z).
#   QuayBarrier8  the 3-tall quay wall, 8 long along Z; its outer (water) face at x = 0, the wall on x = -2..0.
#   QuayFace8     the deck edge below the wall, 8 long along Z, face at x = 0 down to y = -12, fenders on +X.
#   Bollard, LampMast   floor centre (place them on top of the barrier: y = 3).
#   StsCrane      background ship-to-shore crane, floor centre between its four legs, boom raised toward +X.
# Objects are <Piece>_<Part>; Neon parts end in _Glow. 1 Blender unit = 1 stud.
#
# Run (headless):
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup \
#       --python tools/blender/build_map_kit_dockyard.py -- [--no-render] [--samples N]
# Writes art-source/maps/Dockyard/Kit_Dockyard.blend, the contact sheet
# vault/02 Art/References/maps/dockyard/kit-contact.jpg and a dusk preview of the whole layout
# (dockyard-preview-*.jpg), and prints DOCKYARD_TRIS per piece.
# Export: blender --background --factory-startup art-source/maps/Dockyard/Kit_Dockyard.blend
#         --python tools/blender/export_lobby_kit.py -- --maps Dockyard Kit

import json, math, os, random, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "maps"))
import bpy, bmesh  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402
import lobbykit as K  # noqa: E402
from gunkit import prism, box, merge, group, ring_pts, bevel  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
K.ART_DIR = os.path.join(K.ROOT, "art-source", "maps", "Dockyard")
K.RENDER_DIR = os.path.join(K.ROOT, "vault", "02 Art", "References", "maps", "dockyard")

LANE = {"west": 0x9A3B2E, "mid": 0x2F5E9E, "east": 0x3E7D4F}
WALL_MIX = [0x6E7277, 0xC9C2B0, 0x3B4A63, 0x6B3A33, 0x3C6766, 0x8A8F96, 0x5B6B4F]

# The skyline (also placed by Art.luau; keep the two in step). Map space; the east set, the west set is it rotated.
# Ship on the far side of the channel (hull x 90..126), STS cranes on the far quay (x 132+) reaching back over it.
SKY_CRANES = ((158, 60, 180), (158, -12, 180), (-158, -60, 0), (-158, 12, 0))
SHIP_STACKS = [(x, z, n) for z, ns in ((-50, (2, 3, 3, 2)), (-16, (3, 2, 3, 3)), (18, (2, 3, 2, 1))) for x, n in zip((-12, -4, 4, 12), ns)]
FAR_STACKS = ((190, -120, 2), (190, -86, 3), (222, -120, 1), (222, 100, 2), (190, 120, 3), (254, 40, 2))


# ---------------------------------------------------------------- Roblox-space geometry helpers

def rb(p):
	return Vector((p[0], -p[2], p[1]))


def RB(x0, x1, y0, y1, z0, z1, ch=0.0):
	bm = box(min(x0, x1), max(x0, x1), -max(z0, z1), -min(z0, z1), min(y0, y1), max(y0, y1))
	if ch > 0:
		bevel(bm, ch, segs=1, angle=30)
	return bm


def frame_to(a, b, up=(0, 1, 0)):
	# Matrix that maps Blender +X onto the Roblox segment a -> b (origin at a), side axis = up x dir.
	A, Bv = rb(a), rb(b)
	d = Bv - A
	x = d.normalized()
	u = rb(up)
	if abs(x.dot(u.normalized())) > 0.99:
		u = Vector((1, 0, 0)) if abs(x.x) < 0.9 else Vector((0, 1, 0))
	y = u.cross(x).normalized()
	z = x.cross(y)
	return Matrix(((x.x, y.x, z.x, A.x), (x.y, y.y, z.y, A.y), (x.z, y.z, z.z, A.z), (0, 0, 0, 1))), d.length


def beam(a, b, w, h, up=(0, 1, 0)):
	# Box of cross-section w (side) x h (up) from Roblox point a to b.
	m, L = frame_to(a, b, up)
	bm = box(0, L, -w / 2, w / 2, -h / 2, h / 2)
	return K.place(bm, m)


def rod(a, b, r, segs=6):
	m, L = frame_to(a, b)
	bm = prism(ring_pts(0, 0, r, segs, math.pi / segs), "X", 0, L)
	return K.place(bm, m)


def vcyl(x, z, r, y0, y1, segs=12):
	return K.cyl(x, -z, r, y0, y1, segs=segs)


def corrugated(axis, side, outer, depth, back, a0, a1, y0, y1, pitch, flat=0.3):
	# A corrugated sheet as a closed slab with vertical ribs. axis "x": the sheet faces +-X (side = +1 or -1) with its
	# outer face at x = outer and spans z = a0..a1; axis "z": faces +-Z with its outer face at z = outer, spans x.
	# Ribs: outer flat, slope, inner flat (depth in), slope; the back face is `back` behind the outer face.
	n = max(1, round((a1 - a0) / pitch))
	p = (a1 - a0) / n
	prof = []
	for i in range(n):
		s0 = a0 + i * p
		for t, o in ((0.0, 1), (flat, 1), (0.5, 0), (0.5 + flat, 0)):
			prof.append((s0 + t * p, 0.0 if o else depth))
	prof.append((a1, 0.0))
	pts = []
	for s, d in prof:
		off = outer - side * d
		pts.append((off, -s) if axis == "x" else (s, -off))
	bo = outer - side * back
	if axis == "x":
		pts += [(bo, -a1), (bo, -a0)]
	else:
		pts += [(a1, -bo), (a0, -bo)]
	bm = prism(pts, "Z", y0, y1)
	# The top and bottom caps always sit under a rail or plinth: drop them (they are most of the triangles).
	bm.normal_update()
	bmesh.ops.delete(bm, geom=[f for f in bm.faces if abs(f.normal.z) > 0.9], context="FACES_ONLY")
	return bm


def G(*bms):
	return group(*bms)


class Acc:
	# One bmesh per part name: {part: [bmesh, material]}.
	def __init__(self):
		self.d = {}

	def add(self, part, mat, *bms):
		for bm in bms:
			if part in self.d:
				merge(self.d[part][0], bm)
			else:
				self.d[part] = [bm, mat]

	def parts(self):
		return {k: (v[0], v[1]) for k, v in self.d.items()}


def tidy(bm):
	# Concave n-gon caps (corrugated profiles) must be triangulated here; the FBX importer's fan would fold them.
	ngons = [f for f in bm.faces if len(f.verts) > 4]
	if ngons:
		bmesh.ops.triangulate(bm, faces=ngons, quad_method="BEAUTY", ngon_method="EAR_CLIP")
	return bm


def piece(name, parts, mats, kit):
	col = K.collection("Map_" + name, kit)
	for _, (bm, _) in parts.items():
		tidy(bm)
	K.build(name, parts, mats, col)
	return col


# ---------------------------------------------------------------- materials

def make_mats():
	mats = K.begin()
	f = K._flat
	add = {
		"ContainerPaint": f("ContainerPaint", 0xB4B7BB, 0.5, metallic=0.25, rbx="Metal"),
		"ContainerFrame": f("ContainerFrame", 0x9A9DA2, 0.55, metallic=0.3, rbx="Metal"),
		"SteelDark": f("SteelDark", 0x2A2C30, 0.45, metallic=0.7, rbx="Metal"),
		"CraneYellow": f("CraneYellow", 0xE0AE2E, 0.45, metallic=0.25, rbx="Metal"),
		"HazardBlack": f("HazardBlack", 0x1E1F22, 0.6, rbx="SmoothPlastic"),
		"CabWhite": f("CabWhite", 0xD9DADB, 0.5, rbx="SmoothPlastic"),
		"Glass": K._glass("CabGlass", 0x8FB3C4),
		"QuayConcrete": f("QuayConcrete", 0x9C988F, 0.85, rbx="Concrete"),
		"QuayConcreteDark": f("QuayConcreteDark", 0x6E6A63, 0.9, rbx="Concrete"),
		"Rubber": f("Rubber", 0x222326, 0.9, rbx="Rubber"),
		"SafetyYellow": f("SafetyYellow", 0xE2B93B, 0.5, rbx="SmoothPlastic"),
		"Cladding": f("Cladding", 0x5C6670, 0.5, metallic=0.3, rbx="Metal"),
		"ShedTrim": f("ShedTrim", 0xC9C6BE, 0.5, metallic=0.2, rbx="Metal"),
		"ShedStripe": f("ShedStripe", 0x9A3B2E, 0.5, rbx="SmoothPlastic"),
		"RoofSheet": f("RoofSheet", 0x6F757C, 0.55, metallic=0.3, rbx="Metal"),
		"ShedFloor": f("ShedFloor", 0x7A7873, 0.8, rbx="Concrete"),
		"CrateWood": f("CrateWood", 0xA27B4E, 0.8, rbx="Wood"),
		"PalletWood": f("PalletWood", 0x7E6243, 0.85, rbx="Wood"),
		"Cardboard": f("Cardboard", 0xB58E5E, 0.85, rbx="Cardboard"),
		"ShrinkWrap": f("ShrinkWrap", 0xD3D8DC, 0.35, rbx="Plastic"),
		"RackBlue": f("RackBlue", 0x2F4E86, 0.45, metallic=0.3, rbx="Metal"),
		"OfficeWhite": f("OfficeWhite", 0xD2D4D6, 0.5, rbx="SmoothPlastic"),
		"StsWhite": f("StsWhite", 0xC4C7CB, 0.5, metallic=0.2, rbx="Metal"),
		"StsRed": f("StsRed", 0xA8322B, 0.5, rbx="Metal"),
		"HullDark": f("HullDark", 0x2E3440, 0.55, metallic=0.3, rbx="Metal"),
		"HatchGreen": f("HatchGreen", 0x4C5A50, 0.6, metallic=0.3, rbx="Metal"),
		"Glow_Sodium": K._emissive("Glow_Sodium", 0xFFB45C, 3.0),
		"Glow_Red": K._emissive("Glow_Red", 0xFF4A3D, 3.0),
		"Glow_Window": K._emissive("Glow_Window", 0xFFD9A0, 1.6),
	}
	mats.update(add)
	return mats


# ---------------------------------------------------------------- containers

def p_container(name, L, mats, kit):
	h = L / 2
	acc = Acc()
	# Frame: corner posts, side rails, end rails, corner castings.
	fr = []
	for sx in (-1, 1):
		for sz in (-1, 1):
			fr.append(RB(sx * 3.45, sx * 4.0, 0, 8, sz * (h - 0.55), sz * h, ch=0.05))
			fr.append(RB(sx * 3.35, sx * 4.05, 0, 0.6, sz * (h - 0.65), sz * (h + 0.05)))
			fr.append(RB(sx * 3.35, sx * 4.05, 7.4, 8.0, sz * (h - 0.65), sz * (h + 0.05)))
		fr.append(RB(sx * 3.55, sx * 4.0, 0, 0.5, -h + 0.5, h - 0.5))
		fr.append(RB(sx * 3.55, sx * 4.0, 7.55, 8.0, -h + 0.5, h - 0.5))
	for sz in (-1, 1):
		fr.append(RB(-3.5, 3.5, 0, 0.6, sz * (h - 0.4), sz * h))
		fr.append(RB(-3.5, 3.5, 7.35, 8.0, sz * (h - 0.4), sz * h))
	acc.add("Frame", "ContainerFrame", *fr)
	# Body: corrugated sides, corrugated blind end (-Z), roof, doors (+Z).
	body = []
	for sx in (-1, 1):
		body.append(corrugated("x", sx, sx * 3.92, 0.22, 0.34, -h + 0.5, h - 0.5, 0.5, 7.55, 1.6))
	body.append(corrugated("z", -1, -h + 0.06, 0.18, 0.3, -3.45, 3.45, 0.6, 7.35, 1.4))
	body.append(RB(-3.55, 3.55, 7.3, 7.88, -h + 0.4, h - 0.4))
	for x0, x1 in ((-3.45, -0.03), (0.03, 3.45)):
		body.append(RB(x0, x1, 0.6, 7.35, h - 0.3, h - 0.08))
		for y in (1.6, 3.95, 6.3):  # pressed horizontal ribs on the door leaves
			body.append(RB(x0 + 0.25, x1 - 0.25, y - 0.35, y + 0.35, h - 0.08, h - 0.02))
	acc.add("Body", "ContainerPaint", *body)
	# Hardware: four locking bars with handles and cam keepers, door hinges.
	hw = []
	for x in (-2.6, -0.9, 0.9, 2.6):
		hw.append(vcyl(x, h + 0.12, 0.09, 0.62, 7.33, segs=6))
		hw.append(RB(x - 0.12, x + 0.12, 0.62, 0.95, h - 0.02, h + 0.3))
		hw.append(RB(x - 0.12, x + 0.12, 7.0, 7.33, h - 0.02, h + 0.3))
		hw.append(beam((x, 3.3, h + 0.15), (x + (0.75 if x < 0 else -0.75), 3.3, h + 0.3), 0.12, 0.12))
	for sx in (-1, 1):
		for y in (1.2, 3.0, 4.9, 6.7):
			hw.append(RB(sx * 3.3, sx * 3.62, y - 0.18, y + 0.18, h - 0.02, h + 0.14))
	acc.add("Hardware", "SteelDark", *hw)
	return piece(name, acc.parts(), mats, kit)


# ---------------------------------------------------------------- stair

def p_stair(mats, kit):
	# Steel stair 8 wide (x), 16 long (z), rising 8 toward +Z: 11 treads on two stringers with handrails.
	acc = Acc()
	n = 11
	run = 16.0 / n
	rise = 8.0 / n
	st = []
	for sx in (-1, 1):
		x = sx * 3.75
		st.append(beam((x, -0.45, -8.2), (x, 7.55, 8.0), 0.35, 0.9))
	acc.add("Stringers", "SteelDark", *st)
	treads, nose = [], []
	for i in range(n):
		z0 = -8 + i * run
		y = (i + 1) * rise
		treads.append(RB(-3.55, 3.55, y - 0.18, y, z0, z0 + run + 0.05))
		nose.append(RB(-3.55, 3.55, y - 0.2, y + 0.01, z0, z0 + 0.22))
	acc.add("Treads", "SteelDark", *treads)
	acc.add("Nosing", "SafetyYellow", *nose)
	rail = []
	for sx in (-1, 1):
		x = sx * 3.9
		for t in (0.05, 0.36, 0.68, 0.98):
			z = -8 + 16 * t
			y = 8 * t
			rail.append(rod((x, y, z), (x, y + 3.6, z), 0.1))
		rail.append(rod((x, 3.6, -8), (x, 11.6, 8), 0.1))
		rail.append(rod((x, 1.9, -8), (x, 9.9, 8), 0.07))
	acc.add("Rails", "SafetyYellow", *rail)
	return piece("Stair", acc.parts(), mats, kit)


# ---------------------------------------------------------------- gantry crane (RTG)

def p_crane(mats, kit):
	acc = Acc()
	Y = "CraneYellow"
	legs, dark, stripes = [], [], []
	for sx in (-1, 1):
		for sz in (-1, 1):
			x, z = sx * 30, sz * 16
			# Leg: tapered column from the bogie to the girder, built as a beam from foot to head.
			legs.append(beam((x, 3.0, z), (x, 52.0, z), 2.6, 2.6, up=(0, 0, 1)))
			legs.append(RB(x - 1.7, x + 1.7, 2.2, 3.4, z - 1.7, z + 1.7, ch=0.1))
			# Bogie and wheels (inside the leg's 3 x 3 collision footprint, a little longer along Z).
			legs.append(RB(x - 1.2, x + 1.2, 0.9, 2.3, z - 2.4, z + 2.4, ch=0.1))
			for wz in (-1.5, 1.5):
				dark.append(K.place(prism(ring_pts(0, 0, 0.9, 12, 0), "X", -1.0, 1.0), Matrix.Translation(rb((x, 0.9, z + wz)))))
			for k in range(3):
				y0 = 3.6 + k * 1.6
				stripes.append(RB(x - 1.34, x + 1.34, y0, y0 + 0.8, z - 1.34, z + 1.34))
		# Side frame: portal beam between the two legs of a side and diagonal braces.
		legs.append(beam((sx * 30, 34, -16), (sx * 30, 34, 16), 2.0, 2.4))
		legs.append(beam((sx * 30, 35, -14.8), (sx * 30, 50.5, -1.5), 1.0, 1.0))
		legs.append(beam((sx * 30, 35, 14.8), (sx * 30, 50.5, 1.5), 1.0, 1.0))
		# End beam on top of the side.
		legs.append(RB(sx * 30 - 1.6, sx * 30 + 1.6, 50, 56.4, -17.6, 17.6, ch=0.12))
	# Main girders along X, with a walkway rail on top.
	for sz in (-1, 1):
		legs.append(RB(-33, 33, 52, 56, sz * 16 - 1.5, sz * 16 + 1.5, ch=0.12))
		for x in range(-30, 31, 6):
			dark.append(rod((x, 56, sz * 16 + sz * 1.3), (x, 57.6, sz * 16 + sz * 1.3), 0.06))
		dark.append(rod((-31, 57.6, sz * 16 + sz * 1.3), (31, 57.6, sz * 16 + sz * 1.3), 0.06))
	acc.add("Steel", Y, *legs)
	acc.add("Stripes", "HazardBlack", *stripes)
	# Trolley across the girders with the machinery house; the cab hangs under it.
	tr = [RB(-5, 5, 56, 57.4, -18, 18, ch=0.1), RB(-4, 4, 57.4, 61, -6, 6, ch=0.15)]
	acc.add("Trolley", Y, *tr)
	cab = [RB(1.5, 5.5, 46.2, 50.2, -12.5, -8.5, ch=0.15), RB(2.5, 4.5, 50.2, 56, -11.5, -9.5)]
	acc.add("Cab", "CabWhite", *cab)
	acc.add("CabGlass", "Glass", RB(1.4, 5.6, 47.6, 49.8, -12.6, -12.4), RB(1.4, 1.6, 47.6, 49.8, -12.4, -8.6), RB(1.45, 5.55, 46.15, 46.3, -12.45, -8.55))
	# Spreader over the crane stack (top at 16), high enough (26+) that a player standing on the stack stays clear.
	spr = [RB(-15.5, 15.5, 26.2, 27.4, -1.0, 1.0, ch=0.1), RB(-16.2, -14.2, 25.8, 27.6, -3.8, 3.8, ch=0.1), RB(14.2, 16.2, 25.8, 27.6, -3.8, 3.8, ch=0.1), RB(-3, 3, 27.4, 29, -2.6, 2.6, ch=0.15)]
	acc.add("Spreader", Y, *spr)
	for x in (-2.2, 2.2):
		for z in (-1.8, 1.8):
			dark.append(rod((x, 29, z), (x * 1.5, 56, z * 2), 0.07, segs=4))
	acc.add("Dark", "SteelDark", *dark)
	# Sodium floodlights under the girders (they light the stack in Studio through Lighting.luau's SpotLight).
	glow = []
	for x in (-20, 20):
		for sz in (-1, 1):
			glow.append(RB(x - 1.2, x + 1.2, 51.6, 51.9, sz * 16 - 0.8, sz * 16 + 0.8))
	acc.add("Lamp_Glow", "Glow_Sodium", *glow)
	acc.add("LampHousing", "SteelDark", *[RB(x - 1.4, x + 1.4, 51.9, 52.0, sz * 16 - 1.0, sz * 16 + 1.0) for x in (-20, 20) for sz in (-1, 1)])
	return piece("Crane", acc.parts(), mats, kit)


# ---------------------------------------------------------------- shed

def p_shed(mats, kit):
	# Local: X -13..13, Z -18..18 (the greybox walls), walls 16, gable ridge 22 along Z. Openings: roller door
	# x -5..5 on -Z (16 clear, the visual head from 13), doors z -12..-4 and 4..12 on -X (9 clear).
	acc = Acc()
	H, R = 16.0, 22.0
	clad, plinth, trim = [], [], []
	# Wall runs: (axis, side, outer, a0, a1, top) with gaps for the doors.
	runs = [
		("z", -1, -18.0, -13, -5), ("z", -1, -18.0, 5, 13),  # south, beside the roller door
		("z", 1, 18.0, -13, 13),  # north
		("x", -1, -13.0, -18, -12), ("x", -1, -13.0, -4, 4), ("x", -1, -13.0, 12, 18),  # west, between the doors
		("x", 1, 13.0, -18, 18),  # east (water side)
	]
	for axis, side, outer, a0, a1 in runs:
		clad.append(corrugated(axis, side, outer, 0.18, 1.0, a0, a1, 2.5, H, 0.9))
		if axis == "x":
			plinth.append(RB(outer - side * 1.05, outer + side * 0.12, 0, 2.5, a0, a1))
		else:
			plinth.append(RB(a0, a1, 0, 2.5, outer - side * 1.05, outer + side * 0.12))
	# Heads over the openings (the greybox lintels: roller door from 13, side doors from 9).
	clad.append(corrugated("z", -1, -18.0, 0.18, 1.0, -5, 5, 13, H, 0.9))
	for z0, z1 in ((-12, -4), (4, 12)):
		clad.append(corrugated("x", -1, -13.0, 0.18, 1.0, z0, z1, 9, H, 0.9))
	# Gables (16 to 22) on both ends: triangles of cladding.
	for zs in (-1, 1):
		zo = zs * 18.0
		pts = [(-13.4, H), (13.4, H), (0, R + 0.2)]
		ya, yb = sorted((-(zo - 0.8 * zs), -(zo + 0.2 * zs)))
		clad.append(prism(pts, "Y", ya, yb))
	acc.add("Cladding", "Cladding", *clad)
	acc.add("Plinth", "QuayConcrete", *plinth)
	# Trims: corner flashings, door frames, eaves gutters, downpipes.
	for sx in (-1, 1):
		for sz in (-1, 1):
			trim.append(RB(sx * 13.25, sx * 12.6, 0, H + 0.2, sz * 18.25, sz * 17.6))
			trim.append(vcyl(sx * 13.4, sz * 17.2, 0.22, 0, H, segs=6))
		trim.append(RB(sx * 13.0, sx * 14.0, H - 0.3, H + 0.3, -18.6, 18.6))
	for x in (-5.4, 5.4):
		trim.append(RB(x - 0.4, x + 0.4, 0, 13.4, -18.5, -17.7))
	trim.append(RB(-5.8, 5.8, 13.0, 13.4, -18.5, -17.7))
	for z0, z1 in ((-12, -4), (4, 12)):
		trim.append(RB(-13.5, -12.7, 0, 9.4, z0 - 0.4, z0))
		trim.append(RB(-13.5, -12.7, 0, 9.4, z1, z1 + 0.4))
		trim.append(RB(-13.5, -12.7, 9.0, 9.4, z0 - 0.4, z1 + 0.4))
	acc.add("Trim", "ShedTrim", *trim)
	# Lane stripe band (tinted per instance) and the sign board over the roller door.
	stripe = []
	for axis, side, outer, a0, a1 in runs:
		if axis == "x":
			stripe.append(RB(outer + side * 0.05, outer + side * 0.22, 10.6, 12.0, a0, a1))
		else:
			stripe.append(RB(a0, a1, 10.6, 12.0, outer + side * 0.05, outer + side * 0.22))
	acc.add("Stripe", "ShedStripe", *stripe)
	# Roller door: the rolled-up drum and guides.
	roller = [K.place(prism(ring_pts(0, 0, 1.0, 10, 0), "X", -5.4, 5.4), Matrix.Translation(rb((0, 14.4, -17.0))))]
	for x in (-5.15, 5.15):
		roller.append(RB(x - 0.25, x + 0.25, 0, 13.2, -17.6, -17.2))
	acc.add("Roller", "SteelDark", *roller)
	# Roof: two slopes (eaves 16 at x = +-13.5, ridge 22 at x = 0), sheets with ribs down the slope, ridge cap.
	roof, ribs = [], []
	for sx in (-1, 1):
		a = (sx * 13.9, H - 0.1, 0)
		b = (0, R + 0.05, 0)
		m, L = frame_to(a, b, up=(0, 1, 0))
		sheet = K.place(box(0, L, -18.7, 18.7, -0.15, 0.15), m)
		roof.append(sheet)
		for k in range(19):
			z = -18 + k * 2.0
			ribs.append(beam((sx * 13.9, H + 0.08, z), (0, R + 0.2, z), 0.25, 0.22))
	roof.append(beam((0, R + 0.1, -18.8), (0, R + 0.1, 18.8), 1.2, 0.5))
	acc.add("Roof", "RoofSheet", *roof)
	acc.add("RoofRibs", "RoofSheet", *ribs)
	# Inside: portal frames (columns and rafters) and the floor slab tone.
	steel = []
	for z in (-13.5, -4.5, 4.5, 13.5):
		for sx in (-1, 1):
			steel.append(RB(sx * 12.0, sx * 11.4, 0, H, z - 0.3, z + 0.3))
			steel.append(beam((sx * 11.7, H - 0.6, z), (0, R - 0.9, z), 0.5, 0.8))
	acc.add("Frames", "RackBlue", *steel)
	acc.add("Floor", "ShedFloor", RB(-12, 12, 0, 0.04, -17, 17))
	# Lights: pendant lamps inside, wall packs over the doors outside.
	lamps, housings = [], []
	for z in (-10, 0, 10):
		for x in (-6, 6):
			lamps.append(RB(x - 0.6, x + 0.6, 13.3, 13.4, z - 0.6, z + 0.6))
			housings.append(RB(x - 0.7, x + 0.7, 13.4, 13.8, z - 0.7, z + 0.7))
			housings.append(rod((x, 13.8, z), (x, R - 1.2, z), 0.05, segs=4))
	for p in ((0, 15.2, -18.6), (-13.6, 10.4, -8), (-13.6, 10.4, 8)):
		x, y, z = p
		if z < -18:
			lamps.append(RB(-0.9, 0.9, y - 0.12, y, z - 0.6, z))
			housings.append(RB(-1.0, 1.0, y, y + 0.5, z - 0.7, z))
		else:
			lamps.append(RB(x - 0.6, x, y - 0.12, y, z - 0.9, z + 0.9))
			housings.append(RB(x - 0.7, x, y, y + 0.5, z - 1.0, z + 1.0))
	acc.add("Lamp_Glow", "Glow_Sodium", *lamps)
	acc.add("LampHousing", "SteelDark", *housings)
	# Sign board over the roller door (Art.luau puts the SurfaceGui name on a Part in front of it).
	acc.add("Sign", "HazardBlack", RB(-6.5, 6.5, 15.6, 18.6, -18.7, -18.4))
	return piece("Shed", acc.parts(), mats, kit)


def p_office(mats, kit):
	# Site cabin 7 (x) x 8 (z), 9 tall: door and windows on -X (facing the shed floor).
	acc = Acc()
	acc.add("Shell", "OfficeWhite", RB(-3.5, 3.5, 0.4, 8.4, -4, 4, ch=0.12))
	acc.add("Base", "SteelDark", RB(-3.4, 3.4, 0, 0.4, -3.9, 3.9), RB(-3.6, 3.6, 8.4, 8.7, -4.1, 4.1))
	acc.add("Window_Glow", "Glow_Window", RB(-3.56, -3.5, 4.0, 6.6, 0.4, 3.4), RB(-3.56, -3.5, 4.0, 6.6, -3.4, -2.2))
	acc.add("Door", "SteelDark", RB(-3.58, -3.5, 0.5, 6.8, -1.8, 0.0))
	acc.add("Unit", "ContainerFrame", RB(-1.5, 1.5, 8.7, 9.0, -1.5, 1.5, ch=0.08))
	acc.add("Stair", "SafetyYellow", RB(-4.6, -3.5, 0, 0.45, -2.2, 0.4))
	return piece("Office", acc.parts(), mats, kit)


def p_rack(mats, kit):
	# Pallet rack 2.5 (x) x 14 (z) x 8, packed full so it reads as the full cover it is.
	acc = Acc()
	up, beams, loads, pal = [], [], [], []
	for z in (-7, -2.33, 2.33, 7):
		for x in (-1.15, 1.15):
			up.append(RB(x - 0.12, x + 0.12, 0, 8, z - 0.12, z + 0.12))
	for y in (0.25, 2.85, 5.45):
		for x in (-1.2, 1.2):
			beams.append(RB(x - 0.08, x + 0.08, y, y + 0.3, -7, 7))
	rnd = random.Random(3)
	for k, z0 in enumerate((-6.9, -2.2, 2.45)):
		for lvl, y in enumerate((0.55, 3.15, 5.75)):
			pal.append(RB(-1.1, 1.1, y, y + 0.3, z0 + 0.1, z0 + 4.35))
			hgt = 2.1 if lvl < 2 else rnd.uniform(1.6, 2.1)
			if rnd.random() < 0.5:
				loads.append(("ShrinkWrap", RB(-1.05, 1.05, y + 0.3, y + 0.3 + hgt, z0 + 0.15, z0 + 4.3, ch=0.1)))
			else:
				for i in range(2):
					for j in range(2):
						loads.append(("Cardboard", RB(-1.0 + i * 1.02, -0.02 + i * 1.02, y + 0.3, y + 0.3 + hgt * rnd.uniform(0.85, 1.0), z0 + 0.2 + j * 2.07, z0 + 2.2 + j * 2.07, ch=0.04)))
	acc.add("Uprights", "RackBlue", *up)
	acc.add("Beams", "SafetyYellow", *beams)
	acc.add("Pallets", "PalletWood", *pal)
	for mat, bm in loads:
		acc.add("Load" + mat, mat, bm)
	return piece("Rack", acc.parts(), mats, kit)


def p_crate(mats, kit):
	# Pallet + wooden crate, 4 x 4 x 3.5 (the greybox low cover).
	acc = Acc()
	pal = []
	for x in (-1.8, 0, 1.8):
		pal.append(RB(x - 0.25, x + 0.25, 0, 0.35, -2, 2))
	for z in (-1.75, -0.6, 0.6, 1.75):
		pal.append(RB(-2, 2, 0.35, 0.5, z - 0.22, z + 0.22))
	acc.add("Pallet", "PalletWood", *pal)
	crate = [RB(-1.85, 1.85, 0.5, 3.4, -1.85, 1.85, ch=0.06)]
	bat = []
	for sx in (-1, 1):
		for y0 in (0.5, 3.05):
			bat.append(RB(sx * 1.85, sx * 1.98, y0, y0 + 0.35, -1.9, 1.9))
			bat.append(RB(-1.9, 1.9, y0, y0 + 0.35, sx * 1.85, sx * 1.98))
		bat.append(beam((sx * 1.92, 0.7, -1.6), (sx * 1.92, 3.2, 1.6), 0.15, 0.3, up=(1, 0, 0)))
		bat.append(beam((-1.6, 0.7, sx * 1.92), (1.6, 3.2, sx * 1.92), 0.3, 0.15, up=(0, 0, 1)))
	acc.add("Crate", "CrateWood", *crate)
	acc.add("Battens", "PalletWood", *bat)
	return piece("Crate", acc.parts(), mats, kit)


# ---------------------------------------------------------------- quay

def p_quay_barrier(mats, kit):
	# 3-tall quay wall, wall on x = -2..0 (water at +X), 8 long, with a yellow/black hazard top edge.
	acc = Acc()
	prof = [(-2.0, 0), (0.0, 0), (0.0, 2.6), (-0.25, 3.0), (-1.75, 3.0), (-2.0, 2.6)]
	bm = prism([(x, y) for x, y in prof], "Y", -4.0, 4.0)
	acc.add("Wall", "QuayConcrete", bm)
	paint, black = [], []
	for k in range(4):
		z0 = -4 + k * 2
		(paint if k % 2 == 0 else black).append(RB(-1.78, -0.22, 3.0, 3.04, z0, z0 + 2))
	acc.add("Paint", "SafetyYellow", *paint)
	acc.add("PaintBlack", "HazardBlack", *black)
	acc.add("Base", "QuayConcreteDark", RB(-2.08, 0.08, 0, 0.35, -4.0, 4.0))
	return piece("QuayBarrier8", acc.parts(), mats, kit)


def p_quay_face(mats, kit):
	# Deck edge: a concrete face at x = 0 down to y = -12, coping on top, tyre fender on +X.
	acc = Acc()
	acc.add("Face", "QuayConcreteDark", RB(-1.0, 0.0, -12, -0.4, -4, 4))
	acc.add("Coping", "QuayConcrete", RB(-1.0, 0.35, -0.6, 0.05, -4, 4, ch=0.06))
	fend = K.place(prism(ring_pts(0, 0, 1.1, 10, 0), "X", -0.6, 0.6), Matrix.Translation(rb((0.85, -4.5, 0))) @ Matrix.Rotation(math.radians(90), 4, "Z"))
	acc.add("Fender", "Rubber", fend, RB(0.0, 0.5, -9.5, -1.0, -0.5, 0.5))
	return piece("QuayFace8", acc.parts(), mats, kit)


def p_bollard(mats, kit):
	acc = Acc()
	acc.add("Body", "SteelDark", vcyl(0, 0, 0.55, 0.3, 1.5, segs=10), vcyl(0, 0, 0.8, 1.5, 1.8, segs=10), RB(-0.9, 0.9, 0, 0.3, -0.9, 0.9, ch=0.05))
	return piece("Bollard", acc.parts(), mats, kit)


def p_lamp_mast(mats, kit):
	# High mast: pole to 34, a crown ring of four sodium floodlights angled down.
	acc = Acc()
	acc.add("Pole", "ContainerFrame", vcyl(0, 0, 0.5, 0, 34, segs=8), vcyl(0, 0, 0.75, 0, 1.6, segs=8), RB(-1.1, 1.1, 0, 0.3, -1.1, 1.1, ch=0.05))
	crown, glow = [], []
	crown.append(RB(-2.4, 2.4, 33.8, 34.3, -0.25, 0.25))
	crown.append(RB(-0.25, 0.25, 33.8, 34.3, -2.4, 2.4))
	for ang in (0, 90, 180, 270):
		r = math.radians(ang)
		cx, cz = 2.6 * math.cos(r), 2.6 * math.sin(r)
		m = Matrix.Translation(rb((cx, 33.6, cz))) @ Matrix.Rotation(-r, 4, "Z") @ Matrix.Rotation(math.radians(-30), 4, "Y")
		crown.append(K.place(box(-0.9, 0.9, -0.7, 0.7, 0.0, 0.6), m.copy()))
		glow.append(K.place(box(-0.75, 0.75, -0.55, 0.55, -0.06, 0.0), m.copy()))
	acc.add("Crown", "SteelDark", *crown)
	acc.add("Lamp_Glow", "Glow_Sodium", *glow)
	return piece("LampMast", acc.parts(), mats, kit)


# ---------------------------------------------------------------- skyline

def p_sts_crane(mats, kit):
	# Ship-to-shore crane for the skyline (1.3x real-ish proportions at our scale): portal legs 30 (x) x 22 (z),
	# girder at 50 from the backreach (x -34) out over the water to the boom tip (x +62), A-frame apex at 100 over
	# the landside legs, forestays to the boom. Floor centre between the legs; the boom reaches toward +X.
	acc = Acc()
	w, red, dark, glow = [], [], [], []
	for sx in (-1, 1):
		for sz in (-1, 1):
			w.append(beam((sx * 15, 0, sz * 11), (sx * 15, 50, sz * 11), 2.6, 2.6, up=(0, 0, 1)))
		w.append(beam((sx * 15, 26, -11), (sx * 15, 26, 11), 1.8, 1.8))
		w.append(beam((sx * 15, 7, -11), (sx * 15, 7, 11), 2.0, 2.0))
		w.append(beam((sx * 15, 9, -11), (sx * 15, 47, 11), 1.0, 1.0))
	for sz in (-1, 1):
		w.append(beam((-34, 50, sz * 10), (62, 50, sz * 7), 2.4, 3.8))
		w.append(beam((-15, 52, sz * 10), (-8, 100, sz * 5), 1.8, 1.8))
		w.append(beam((15, 52, sz * 10), (-8, 100, sz * 5), 1.8, 1.8))
		for x in (30, 46, 62):
			dark.append(rod((-8, 100, sz * 5), (x, 52, sz * 7), 0.18, segs=4))
		dark.append(rod((-8, 100, sz * 5), (-34, 52, sz * 10), 0.18, segs=4))
	w.append(beam((-8, 100, -5.6), (-8, 100, 5.6), 2.2, 2.2))
	w.append(beam((-34, 50, -10), (-34, 50, 10), 2.4, 2.4))
	red.append(RB(-34, -18, 51.9, 60, -9, 9, ch=0.2))  # machinery house
	red.append(RB(-10, -6, 96, 101, -5.5, 5.5))
	w.append(RB(20, 30, 43, 48.2, -4, 4, ch=0.2))  # trolley and cab
	dark.append(RB(-12, 12, 0, 1.5, -13, 13))  # rail beam / sill
	glow.append(RB(-8.5, -7.5, 101.2, 102.0, -0.5, 0.5))
	glow.append(RB(61.5, 62.5, 52.2, 53.0, -0.5, 0.5))
	acc.add("Steel", "StsWhite", *w)
	acc.add("Band", "StsRed", *red)
	acc.add("Stays", "SteelDark", *dark)
	acc.add("Warn_Glow", "Glow_Red", *glow)
	return piece("StsCrane", acc.parts(), mats, kit)


def p_container_lo(mats, kit):
	# Far-away 40 ft box for the ships and the far quays: no corrugation, ~60 triangles, tinted per instance.
	acc = Acc()
	acc.add("Body", "ContainerPaint", RB(-3.95, 3.95, 0.05, 7.95, -15.95, 15.95))
	fr = []
	for sz in (-1, 1):
		for sx in (-1, 1):
			fr.append(RB(sx * 3.5, sx * 4.0, 0, 8, sz * 15.5, sz * 16))
		fr.append(RB(-4, 4, 0, 0.5, sz * 15.5, sz * 16))
		fr.append(RB(-4, 4, 7.5, 8, sz * 15.5, sz * 16))
	acc.add("Frame", "ContainerFrame", *fr)
	return piece("C40Lo", acc.parts(), mats, kit)


def p_ship(mats, kit):
	# Container ship for the harbour: origin on the waterline at the hull centre, 36 wide (x), 184 long (z, bow +Z),
	# deck at 17, bridge at the stern. Deck boxes are C40Lo placed by the art script (bays at z -50 / -16 / 18,
	# rows at x -12 / -4 / 4 / 12).
	acc = Acc()
	plan = [(-18, -92), (18, -92), (18, 56), (12, 80), (0, 92), (-12, 80), (-18, 56)]
	top = prism([(x, -z) for x, z in plan], "Z", 2.0, 17.0)
	bot = prism([(x * 0.94, -z * 0.98) for x, z in plan], "Z", -6.0, 2.0)
	acc.add("Hull", "HullDark", top)
	acc.add("Bottom", "StsRed", bot)
	acc.add("Boot", "CabWhite", prism([(x * 1.003, -z * 1.003) for x, z in plan], "Z", 1.6, 2.4))
	deck = [RB(-17.5, 17.5, 17, 17.6, -88, 54)]
	for z0 in (-66, -32, 2, 36):
		deck.append(RB(-16, 16, 17.6, 18.4, z0 + 0.6, z0 + 33.4, ch=0.1))  # hatch covers
	acc.add("Deck", "HatchGreen", *deck)
	bridge = [RB(-15, 15, 17, 41, -90, -76, ch=0.2), RB(-18, 18, 41, 43, -88, -78, ch=0.15), RB(-5, 5, 43, 52, -90, -84, ch=0.3)]
	acc.add("Bridge", "CabWhite", *bridge)
	acc.add("Funnel", "SteelDark", RB(-4.5, 4.5, 52, 58, -90, -85, ch=0.3))
	glow = [RB(-15.05, 15.05, 37.5, 39.0, -76.05, -75.9), RB(-15.05, 15.05, 30, 30.8, -76.05, -75.9), RB(-15.05, 15.05, 25, 25.8, -76.05, -75.9)]
	acc.add("Window_Glow", "Glow_Window", *glow)
	acc.add("Mast_Glow", "Glow_Red", RB(-0.4, 0.4, 58.2, 59.0, -87.9, -87.1), RB(-0.4, 0.4, 24.0, 24.8, 88.0, 88.8))
	acc.add("Mast", "SteelDark", vcyl(0, 88.4, 0.3, 17, 24, segs=6))
	return piece("Ship", acc.parts(), mats, kit)


# ---------------------------------------------------------------- previews

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
	ncol = 5
	nrow = (len(pieces) + ncol - 1) // ncol
	floor = K.add_obj("SheetFloor", box(-cell * (nrow - 0.4), cell * 0.6, -cell * 0.6, cell * (ncol - 0.4), -0.2, 0), [mats["QuayConcreteDark"]], stage)
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
		s = min(2.0, 24.0 / max(size.x, size.y, size.z, 0.01))
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
	cx, cy = -(nrow - 1) * cell / 2, (ncol - 1) * cell / 2
	cam = K.camera((cx + 260, cy + 60, 250), (cx, cy, 4), lens=50, name="SheetCam", col=stage)
	cam.data.type = "ORTHO"
	cam.data.ortho_scale = cell * ncol * 1.08
	K.render_settings(samples=int(ARGS[ARGS.index("--samples") + 1]) if "--samples" in ARGS else 24)
	try:
		sc.eevee.use_raytracing = False
	except AttributeError:
		pass
	K.bloom(strength=0.4)
	return stage


def tinted(name, color, rough=0.5):
	m = bpy.data.materials.get(name) or K._flat(name, color, rough, metallic=0.25, rbx="Metal")
	m["preview_only"] = True
	return m


def instance(col_name, cf, parent, tint=None, tint_parts=("Body", "Frame", "Stripe")):
	# Places linked copies of a kit piece's meshes (shared data, per-object material when tinted).
	# cf: (x, y, z, yaw_deg) in Roblox map space; yaw like CFrame.Angles(0, yaw, 0).
	x, y, z, yaw = cf
	m = Matrix.Translation(rb((x, y, z))) @ Matrix.Rotation(math.radians(yaw), 4, "Z")
	src = bpy.data.collections["Map_" + col_name]
	for ob in src.objects:
		if ob.type != "MESH":
			continue
		o = bpy.data.objects.new(ob.name + "_p", ob.data)
		o.matrix_world = m
		if tint is not None and any(ob.name.endswith("_" + p) for p in tint_parts):
			o.material_slots[0].link = "OBJECT"
			o.material_slots[0].material = tint
		if ob.get("glow"):
			o.visible_shadow = False
		parent.objects.link(o)


def shade(c, k):
	r, g, b = (c >> 16) & 255, (c >> 8) & 255, c & 255
	return (min(255, int(r * k)) << 16) | (min(255, int(g * k)) << 8) | min(255, int(b * k))


def yard_preview(mats):
	# The whole layout (tools/maps/dockyard_layout.py) dressed with the kit, at dusk: the art pass as Art.luau will
	# place it, so the renders show the real composition.
	import dockyard_layout as L

	col = K.collection("Preview")
	rnd = random.Random(11)
	tints = {}

	def lane_tint(lane, k):
		key = (lane, k)
		if key not in tints:
			tints[key] = tinted("Tint_%s_%d" % (lane, k), shade(LANE[lane], (0.9, 1.0, 1.08)[k]))
		return tints[key]

	def wall_tint(i):
		key = ("wall", i)
		if key not in tints:
			tints[key] = tinted("Tint_wall_%d" % i, WALL_MIX[i])
		return tints[key]

	def stack(piece, x, z, along_x, n, tint_fn):
		for k in range(n):
			yaw = (90 if along_x else 0) + (180 if rnd.random() < 0.5 else 0)
			instance(piece, (x, 8 * k, z, yaw), col, tint_fn(k))

	sheds = set()
	for b in L.BOXES:
		if b.kind == "box":
			n = int(round(b.h / 8))
			stack(b.piece, b.x, b.z, b.sx > b.sz, n, lambda k, b=b: lane_tint(b.lane() if b.lane() in LANE else "mid", rnd.randrange(3)))
		elif b.kind == "low":
			instance("Crate", (b.x, 0, b.z, rnd.choice((0, 90))), col)
		elif b.kind == "ramp":
			yaw = math.degrees(math.atan2(b.up[0], b.up[1]))
			instance("Stair", (b.x, 0, b.z, yaw), col)
		elif b.kind == "rack":
			instance("Rack", (b.x, 0, b.z, 0), col)
		elif b.kind == "office":
			instance("Office", (b.x, 0, b.z, 0 if b.x > 0 else 180), col)
		elif b.kind == "wall":
			sheds.add(1 if b.z > 0 else -1)
		elif b.kind == "edge":
			n = int(round(b.sz / 8))
			for i in range(n):
				z = b.z0 + 4 + i * 8
				instance("QuayBarrier8", (b.x + (1 if b.x > 0 else -1), 0, z, 0 if b.x > 0 else 180), col)
				if i % 2 == 0:
					instance("Bollard", (b.x, 3, z, 0), col)
		elif b.kind == "backdrop":
			pass
	for s in sheds:
		instance("Shed", (55 * s, 0, 42 * s, 0 if s > 0 else 180), col, tinted("Tint_shed_%d" % s, LANE["east" if s > 0 else "west"]))
	instance("Crane", (0, 0, 0, 0), col)
	# End walls: 7-high faces toward the yard and the alcoves.
	for s in (1, -1):
		for k in range(7):
			y = 8 * k
			for x, z, piece, yaw in ((-52, 96, "C40", 90), (-31, 100, "C20", 0), (-22, 102, "C20", 0), (52, 96, "C40", 90), (31, 100, "C20", 0), (22, 102, "C20", 0), (0, 114, "C40", 90)):
				instance(piece, (x * s, y, z * s, yaw + (180 if s < 0 else 0) + (180 if rnd.random() < 0.3 else 0)), col, wall_tint(rnd.randrange(len(WALL_MIX))))
	# Quay faces all round, lamp masts, skyline cranes.
	for s in (1, -1):
		for i in range(30):
			instance("QuayFace8", (68 * s, 0, -116 + i * 8, 0 if s > 0 else 180), col)
		for i in range(17):
			instance("QuayFace8", (-64 + i * 8, 0, 118 * s, -90 if s > 0 else 90), col)
	for x, z in ((-67, 40), (67, 84), (67, -40), (-67, -84)):
		instance("LampMast", (x, 3, z, 0), col)
	for x, z, yaw in SKY_CRANES:
		instance("StsCrane", (x, -8, z, yaw), col)
	for s_ in (1, -1):
		instance("Ship", (108 * s_, -9, 20 * s_, 0 if s_ > 0 else 180), col)
		for bx, bz, n in SHIP_STACKS:
			for k in range(n):
				instance("C40Lo", ((108 + bx) * s_, 9.4 + 8 * k, (20 + bz) * s_, 0), col, wall_tint(rnd.randrange(len(WALL_MIX))))
		for fx, fz, n in FAR_STACKS:
			for k in range(n):
				instance("C40Lo", (fx * s_, -8 + 8 * k, fz * s_, 90), col, wall_tint(rnd.randrange(len(WALL_MIX))))
	# Deck, water and far quays (Parts in Studio; preview-only here).
	deck_m = K._flat("PrevAsphalt", 0x4A4A4C, 0.85)
	line_m = K._flat("PrevLine", 0xD9B23A, 0.6)
	water_m = K._flat("PrevWater", 0x1E2A44, 0.08, metallic=0.0)
	far_m = K._flat("PrevFarQuay", 0x77736C, 0.9)
	for m in (deck_m, line_m, water_m, far_m):
		m["preview_only"] = True
	K.add_obj("PrevDeck", RB(-68, 68, -12, 0, -118, 118), [deck_m], col)
	lines = bmesh.new()
	for x in range(-64, 65, 16):
		merge(lines, RB(x - 0.25, x + 0.25, 0, 0.03, -92, 92))
	for z in range(-80, 81, 16):
		merge(lines, RB(-66, 66, 0, 0.03, z - 0.25, z + 0.25))
	K.add_obj("PrevLines", lines, [line_m], col)
	K.add_obj("PrevWater", RB(-900, 900, -10, -9, -900, 900), [water_m], col)
	for s in (1, -1):
		K.add_obj("PrevFarQuay%d" % s, RB(s * 132, s * 400, -12, -8, -500, 500), [far_m], col)
	return col


def dusk_world(sun_az=90.0, sun_el=4.0):
	# Dusk sky: orange at the horizon toward the sun, violet overhead, a low warm sun down the X axis.
	sc = bpy.context.scene
	w = bpy.data.worlds.new("Dusk")
	sc.world = w
	w.use_nodes = True
	nt = w.node_tree
	nt.nodes.clear()
	out = nt.nodes.new("ShaderNodeOutputWorld")
	bg = nt.nodes.new("ShaderNodeBackground")
	tc = nt.nodes.new("ShaderNodeTexCoord")
	sep = nt.nodes.new("ShaderNodeSeparateXYZ")
	nt.links.new(tc.outputs["Generated"], sep.inputs[0])
	ramp = nt.nodes.new("ShaderNodeValToRGB")
	cr = ramp.color_ramp
	cr.elements[0].position = 0.0
	cr.elements[0].color = (*K.lin(0x2A2238), 1)
	cr.elements[1].position = 1.0
	cr.elements[1].color = (*K.lin(0x1B1E3A), 1)
	for pos, col in ((0.47, 0x40304A), (0.5, 0xE08A55), (0.53, 0xB0627A), (0.62, 0x5A4A86), (0.8, 0x2C2F5E)):
		e = cr.elements.new(pos)
		e.color = (*K.lin(col), 1)
	# Generated Z on the world sphere runs 0 (down) .. 1 (up); warm side toward +X (Blender) by mixing with X.
	mr = nt.nodes.new("ShaderNodeMath")
	mr.operation = "MULTIPLY_ADD"
	nt.links.new(sep.outputs["Z"], mr.inputs[0])
	mr.inputs[1].default_value = 0.5
	mr.inputs[2].default_value = 0.5
	nt.links.new(mr.outputs[0], ramp.inputs[0])
	nt.links.new(ramp.outputs[0], bg.inputs[0])
	bg.inputs[1].default_value = 0.9
	nt.links.new(bg.outputs[0], out.inputs[0])
	ld = bpy.data.lights.new("DuskSun", "SUN")
	ld.energy = 2.6
	ld.color = K.lin(0xFFB27A)
	ld.angle = math.radians(1.5)
	ob = bpy.data.objects.new("DuskSun", ld)
	K.collection("Stage").objects.link(ob)
	# Light travels from +X (Blender) toward -X, slightly down.
	d = Vector((-math.cos(math.radians(sun_el)), 0.15, -math.sin(math.radians(sun_el)) - 0.12)).normalized()
	ob.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
	fill = bpy.data.lights.new("SkyFill", "SUN")
	fill.energy = 0.55
	fill.color = K.lin(0x8C86C8)
	fill.use_shadow = False
	fo = bpy.data.objects.new("SkyFill", fill)
	K.collection("Stage").objects.link(fo)
	fo.rotation_euler = (math.radians(20), math.radians(10), 0)


def sodium(name, p, energy=9000, radius=1.0):
	ld = bpy.data.lights.new(name, "POINT")
	ld.energy = energy
	ld.color = K.lin(0xFFB45C)
	ld.shadow_soft_size = radius
	ob = bpy.data.objects.new(name, ld)
	K.collection("Stage").objects.link(ob)
	ob.location = rb(p)
	return ob


def yard_renders(mats):
	sc = bpy.context.scene
	for c in list(bpy.context.view_layer.layer_collection.children):
		if c.name in ("Sheet", "Kit"):
			c.exclude = True
	dusk_world()
	for x, z in ((-67, 40), (67, 84), (67, -40), (-67, -84)):
		sodium("Mast", (x + (-6 if x > 0 else 6), 30, z), energy=60000, radius=2)
	sodium("CraneLamp", (0, 44, 0), energy=30000, radius=2)
	for s in (1, -1):
		sodium("ShedLamp", (55 * s, 12, 42 * s), energy=6000)
		sodium("StairLamp", (30 * s, 14, 56 * s), energy=4000)
	K.render_settings(samples=int(ARGS[ARGS.index("--samples") + 1]) if "--samples" in ARGS else 32)
	K.bloom(strength=0.35, threshold=1.0)
	shots = [
		("overview", (-150, 120, -200), (0, 0, 10), 32),
		("from-b-spawn", (0, 24, 72), (0, 8, 0), 26),
		("middle", (-22, 5.5, 20), (16, 12, -18), 24),
		("high-lane", (30, 14, 50), (20, 8, -30), 24),
		("apron", (-60, 7, 80), (-40, 6, 0), 24),
	]
	only = None
	if "--shots" in ARGS:
		only = set(ARGS[ARGS.index("--shots") + 1].split(","))
	for name, eye, tgt, lens in shots:
		if only and name not in only:
			continue
		K.camera(tuple(rb(eye)), tuple(rb(tgt)), lens=lens, name="Cam_" + name)
		K.render(os.path.join(K.RENDER_DIR, "dockyard-preview-%s.jpg" % name), res=(1600, 900))


def main():
	mats = make_mats()
	kit = K.collection("Kit")
	built = [
		("C40", p_container("C40", 32.0, mats, kit)),
		("C20", p_container("C20", 16.0, mats, kit)),
		("Stair", p_stair(mats, kit)),
		("Crane", p_crane(mats, kit)),
		("Shed", p_shed(mats, kit)),
		("Office", p_office(mats, kit)),
		("Rack", p_rack(mats, kit)),
		("Crate", p_crate(mats, kit)),
		("QuayBarrier8", p_quay_barrier(mats, kit)),
		("QuayFace8", p_quay_face(mats, kit)),
		("Bollard", p_bollard(mats, kit)),
		("LampMast", p_lamp_mast(mats, kit)),
		("StsCrane", p_sts_crane(mats, kit)),
		("C40Lo", p_container_lo(mats, kit)),
		("Ship", p_ship(mats, kit)),
	]
	tris, worst = {}, {}
	for name, col in built:
		tris[name] = K.tri_count(col)
		for ob in col.all_objects:
			if ob.type == "MESH":
				ob.data.calc_loop_triangles()
				worst[ob.name] = len(ob.data.loop_triangles)
	print("DOCKYARD_TRIS " + json.dumps(tris))
	print("DOCKYARD_MAX_OBJECT " + json.dumps(max(worst.items(), key=lambda kv: kv[1])))
	sheet(built, mats, tris)
	bpy.context.view_layer.layer_collection.children["Kit"].exclude = True
	if "--no-preview" not in ARGS:
		yard_preview(mats)
		bpy.context.view_layer.layer_collection.children["Preview"].exclude = True
	path = K.save("Kit_Dockyard")
	print("DOCKYARD saved", path)
	if "--no-render" in ARGS:
		return
	if "--no-sheet" not in ARGS:
		K.render(os.path.join(K.RENDER_DIR, "kit-contact.jpg"), res=(2200, 1500))
	if "--no-preview" not in ARGS:
		bpy.context.view_layer.layer_collection.children["Preview"].exclude = False
		yard_renders(mats)


main()
