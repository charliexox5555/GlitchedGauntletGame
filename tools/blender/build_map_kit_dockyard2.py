# build_map_kit_dockyard2.py: the Dockyard2 map kit (vault/01 Design/Maps/Dockyard2.md), one kit group "Kit".
#
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup \
#       --python tools/blender/build_map_kit_dockyard2.py -- [--render] [--preview] [--samples N]
#
# The Lobby's kit language (vault/02 Art/Lobby Style Guide.md) applied to a sunny container port: designed profiles,
# a bevel hierarchy (tools/maps/dockyard2_style.py BEVEL), layering (ribs, rails, frames and bands always step in or
# out by >= 0.05), clean SmoothPlastic trims and the Lobby's calm painted textures on the big surfaces only.
# Every material is a ROLE (D2_<Role>) from dockyard2_style.PALETTE; Studio re-applies colours by role, so a palette
# change never needs this script (see the style file).
#
# Pieces are authored in ROBLOX piece-local coordinates (studs, +Y up, +Z = the piece's front) through RB / RPX / RPY /
# RPZ, which convert to Blender (x, -z, y); kit_bundle.py maps Blender (x, y, z) back to Roblox (x, z, -y). One
# Map_<Piece> collection per piece, origin as listed (all at floor level unless noted):
#   C40 / C20 / C40Lo / C20Lo  floor centre; long axis along Z (32 / 16), 8 x 8; doors on the +Z end. Inside the
#                 8 x 8 x L envelope by >= 0.03 everywhere, so stacked and neighbouring boxes never share a face.
#                 Lo = the background version (end walls above eye level, ships, far stacks).
#   Stair         floor centre of the 8 x 16 ramp footprint, rising 8 toward +Z (the greybox wedge's own axes).
#   Crane         the gantry crane centred on the map (legs at (+-30, +-16), girders 52-56, spreader over the stack).
#   Shed          floor centre of the 26 x 36 Shed (B half: map (55, 42)); roller door on -Z at x -9..1, two doors on
#                 -X at z -8 / +8, the water side +X. ShedSign1 / ShedSign2: its sign, same origin.
#   Rack, Office, Crate   floor centre.  QuayBarrier8 / QuayBarrierShort: the 3-tall quay wall on x -2..0 (water at +X),
#                 8 / 3.7 long along Z.  QuayFace8: the deck edge, face at x 0 (+X outward), 8 long.  Bollard,
#                 LampMast: floor centre (placed on the barrier top).  StsCrane, Ship: skyline.
# Objects are <Piece>_<Part>; Neon parts end in _Glow. 1 Blender unit = 1 stud.
# Writes art-source/maps/Dockyard2/Kit_Dockyard2.blend, runs the coplanar audit (art-source/maps/Dockyard2/
# coplanar.json, must be 0), and with --render the contact sheets, with --preview the style frames of the assembled
# yard (vault/02 Art/References/maps/dockyard2/). Next: export_lobby_kit.py -- --maps Dockyard2 Kit.

import math, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
for p in (HERE, os.path.join(HERE, "..", "maps")):
	if p not in sys.path:
		sys.path.insert(0, p)
import bpy, bmesh  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402
from lobbykit import collection, add_obj, _flat, _emissive, lathe, ROOT  # noqa: E402
from build_lobby_kit_stylized import prism, finish, rbox, rcyl, u_frame, xform, T, RZ, merge  # noqa: E402
from build_lobby_kit_bunker2 import text_mesh, chamfer_path, ring_prism  # noqa: E402
from build_lobby_kit_stylized import rrect  # noqa: E402
import dockyard2_style as S  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ART = os.path.join(ROOT, "art-source", "maps", "Dockyard2")
BLEND = os.path.join(ART, "Kit_Dockyard2.blend")
RENDER_DIR = os.path.join(ROOT, "vault", "02 Art", "References", "maps", "dockyard2")
BP, BS, BT = S.BEVEL["primary"], S.BEVEL["secondary"], S.BEVEL["tertiary"]
SP, SS, ST = S.SEGMENTS["primary"], S.SEGMENTS["secondary"], S.SEGMENTS["tertiary"]

M = {}
PIECES = {}
KIT = None


def materials():
	for role, (hx, rbx, var) in S.PALETTE.items():
		c = int(hx, 16)
		if rbx == "Neon":
			M[role] = _emissive("D2_" + role, c, 6.0)
			continue
		extra = {}
		if rbx == "Glass":
			extra["rbx_transparency"] = 0.5
		if role == "Water":
			extra["rbx_reflectance"] = 0.15
		rough = 0.35 if rbx in ("SmoothPlastic", "Glass") else 0.7
		metal = 0.3 if rbx == "Metal" else 0.0
		m = _flat("D2_" + role, c, rough, metallic=metal, rbx=rbx, **extra)
		m["rbx_variant"] = var
		M[role] = m


# ---------------------------------------------------------------- Roblox-space helpers

def RB(x0, x1, y0, y1, z0, z1, r=0.0, segs=1):
	# Box from Roblox piece-local bounds (y up), rounded by r.
	return rbox(min(x0, x1), max(x0, x1), -max(z0, z1), -min(z0, z1), min(y0, y1), max(y0, y1), r, segs)


def RPZ(pts, z0, z1, r=0.0, segs=1):
	# Profile in (x, y) extruded along Roblox Z.
	return finish(prism(list(pts), "Y", -max(z0, z1), -min(z0, z1)), r, segs)


def RPX(pts, x0, x1, r=0.0, segs=1):
	# Profile in (z, y) extruded along Roblox X.
	return finish(prism([(-z, y) for z, y in pts], "X", min(x0, x1), max(x0, x1)), r, segs)


def RPY(pts, y0, y1, r=0.0, segs=1):
	# Footprint in (x, z) extruded up along Roblox Y.
	return finish(prism([(x, -z) for x, z in pts], "Z", min(y0, y1), max(y0, y1)), r, segs)


def RY(deg):
	return Matrix.Rotation(math.radians(deg), 4, "Y")


def rcylX(cx, cy, cz, r, x0, x1, n=20, bev=0.08):
	# Cylinder along Roblox X centred on (y, z) = (cy, cz).
	bm = rcyl(r, x0, x1, n, bev, 2)
	return xform(bm, T(0, -cz, cy) @ RY(90))


def rcylZ(cx, cy, r, z0, z1, n=20, bev=0.08):
	bm = rcyl(r, z0, z1, n, bev, 2)
	return xform(bm, T(cx, 0, cy) @ Matrix.Rotation(math.radians(90), 4, "X"))


def octo(cx, cz, half, notch):
	h, n = half, notch
	return [(cx + x, cz + z) for x, z in ((h - n, -h), (h, -h + n), (h, h - n), (h - n, h), (-h + n, h), (-h, h - n), (-h, -h + n), (-h + n, -h))]


def piece(name, **props):
	col = collection("Map_" + name, KIT)
	for k, v in props.items():
		col[k] = v
	PIECES[name] = col
	return col


def obj(col, part, bm, role, smooth=35):
	name = col.name[4:] + "_" + part
	if S.PALETTE[role][1] == "Neon":
		ob = add_obj(name + "_Glow", bm, [M[role]], col, smooth_angle=0)
		ob["glow"] = True
		ob.visible_shadow = False
		return ob
	return add_obj(name, bm, [M[role]], col, smooth_angle=smooth)


def beam(p0, p1, w, h=None, up=(0.0, 1.0, 0.0)):
	"""Square-section bar from p0 to p1 (Roblox coords), w wide, h tall."""
	h = h or w
	a, b = Vector(p0), Vector(p1)
	d = (b - a).normalized()
	u = Vector(up)
	if abs(d.dot(u)) > 0.95:
		u = Vector((1.0, 0.0, 0.0))
	sv = d.cross(u).normalized()
	u2 = sv.cross(d).normalized()
	bm = bmesh.new()
	vs = []
	for p in (a, b):
		for i, j in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
			q = p + sv * (i * w / 2) + u2 * (j * h / 2)
			vs.append(bm.verts.new((q.x, -q.z, q.y)))
	for ids in ((0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)):
		bm.faces.new([vs[i] for i in ids])
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	return bm


# ---------------------------------------------------------------- containers

def p_container(name, L, lo=False):
	c = piece(name, length=L)
	h = L / 2
	obj(c, "Body", RB(-3.72, 3.72, 0.32, 7.68, -h + 0.36, h - 0.36, 0.22, 1), "Lane")  # concept pass: 1 segment (budget)
	# Broad proud ribs on both sides (five per 16 studs; three on the Lo version), chamfered trapezoids.
	n = (3 if lo else 5) * int(L / 16)
	pitch = (L - 2.4) / n
	ribs = []
	for k in range(n):
		zc = -h + 1.2 + pitch * (k + 0.5)
		for s in (1, -1):
			pts = [(s * 3.6, zc - 0.8), (s * 3.9, zc - 0.55), (s * 3.9, zc + 0.55), (s * 3.6, zc + 0.8)]
			ribs.append(RPY(pts, 0.9, 7.1))
	# Two ribs across the rear end and the roof's three shallow panels.
	for y in (2.7, 5.3):
		ribs.append(RB(-3.2, 3.2, y - 0.45, y + 0.45, -h + 0.22, -h + 0.42, 0.0 if lo else BT, 1))
	if not lo:
		for k in (-1, 0, 1):
			zc = k * (L - 3) / 3
			ribs.append(RB(-3.2, 3.2, 7.6, 7.78, zc - L / 7.5, zc + L / 7.5, BT, ST))
	obj(c, "Ribs", merge(*ribs), "Lane")
	frame = []
	fr = BS * (0.7 if lo else 1.0)
	for sx in (1, -1):
		for sz in (1, -1):
			frame.append(RB(sx * 3.3, sx * 3.97, 0.03, 7.97, sz * (h - 0.7), sz * (h - 0.03), fr, 1))
		for y0, y1 in ((0.1, 0.75), (7.25, 7.9)):
			if not lo or y0 > 1:
				frame.append(RB(sx * 3.45, sx * 3.9, y0, y1, -h + 0.6, h - 0.6, fr, 1))
	for sz in (1, -1):
		for y0, y1 in ((0.1, 0.75), (7.25, 7.9)):
			frame.append(RB(-3.35, 3.35, y0, y1, sz * (h - 0.6), sz * (h - 0.12), fr, 1))
	obj(c, "Frame", merge(*frame), "LaneFrame")
	# concept pass 2026-11-05: ISO corner castings (charcoal blocks) at all eight corners
	cast = []
	for sx in (1, -1):
		for sz in (1, -1):
			for y0, y1 in ((-0.02, 0.62), (7.38, 8.02)):
				cast.append(RB(sx * 3.32, sx * 4.02, y0, y1, sz * (h - 0.72), sz * (h + 0.02), 0.05, 1))
	obj(c, "Castings", merge(*cast), "Charcoal")
	doors = []
	for s in (1, -1):
		doors.append(RB(s * 0.07, s * 3.25, 0.85, 7.15, h - 0.44, h - 0.22, BS, 1))
		if not lo:
			doors.append(RB(s * 1.4, s * 1.9, 1.3, 6.7, h - 0.26, h - 0.14, BT, ST))
	obj(c, "Doors", merge(*doors), "Lane")
	if not lo:
		rods = []
		for x in (0.75, 2.6, -0.75, -2.6):
			rods.append(RB(x - 0.07, x + 0.07, 0.95, 7.05, h - 0.26, h - 0.07, BT, ST))
			rods.append(RB(x - 0.02, x + 0.5 * (1 if x > 0 else -1) - 0.02, 3.4, 3.8, h - 0.24, h - 0.05, BT, ST))
		obj(c, "Hardware", merge(*rods), "Charcoal")


# ---------------------------------------------------------------- stair

def slope(z):
	return (z + 8.0) / 2.0


def p_stair():
	c = piece("Stair")
	treads, noses = [], []
	for k in range(1, 10):
		z0 = -8 + 1.6 * k
		z1 = min(z0 + 1.6, 7.97)
		top = 0.8 * k - 0.03
		treads.append(RB(-3.3, 3.3, top - 0.28, top, z0, z1, BT, ST))
		noses.append(RB(-3.2, 3.2, top - 0.2, top + 0.02, z0 + 0.04, z0 + 0.3, BT, ST))
	obj(c, "Treads", merge(*treads), "Grate")
	obj(c, "Nosing", merge(*noses), "Hazard")
	cheek = [(-7.98, -0.1), (-5.4, -0.1), (7.97, 7.2), (7.97, 8.45), (-7.98, 0.5)]
	cheeks = [RPX(cheek, s * 3.35, s * 3.85, BS, SS) for s in (1, -1)]
	obj(c, "Stringers", merge(*cheeks), "Charcoal")
	rail = []
	for s in (1, -1):
		x0, x1 = s * 3.5, s * 3.72
		pts = [(-7.4, slope(-7.4) + 3.2), (7.9, slope(7.9) + 3.2), (7.9, slope(7.9) + 3.5), (-7.4, slope(-7.4) + 3.5)]
		rail.append(RPX(pts, x0, x1, BT, ST))
		for zp in (-7.0, -1.0, 5.0):
			rail.append(RB(x0, x1, slope(zp) + 0.4, slope(zp) + 3.25, zp - 0.12, zp + 0.12, BT, ST))
	obj(c, "Rails", merge(*rail), "White")


# ---------------------------------------------------------------- crane (the landmark)

def p_crane():
	c = piece("Crane", span=60)
	legs, bands, bogies, tyres = [], [], [], []
	for sx in (1, -1):
		for sz in (1, -1):
			cx, cz = 30 * sx, 16 * sz
			# concept pass: a solid box-section leg (the collision is solid) with proud corner chords and X bracing
			legs.append(RB(cx - 1.55, cx + 1.55, 3.0, 51.8, cz - 1.55, cz + 1.55, BT, ST))
			for ax in (1, -1):
				for az in (1, -1):
					legs.append(RB(cx + ax * 1.35 - 0.38, cx + ax * 1.35 + 0.38, 2.98, 51.84, cz + az * 1.35 - 0.38, cz + az * 1.35 + 0.38, BT, ST))
			for k in range(8):
				y0 = 3.4 + 6.0 * k
				y1 = y0 + 6.0
				for f in (1, -1):
					fx = cx + f * 1.62
					bands.append(beam((fx, y0 + 0.3, cz - 1.05), (fx, y1 - 0.3, cz + 1.05), 0.3, 0.3))
					bands.append(beam((fx, y0 + 0.3, cz + 1.05), (fx, y1 - 0.3, cz - 1.05), 0.26, 0.3))
					fz = cz + f * 1.62
					bands.append(beam((cx - 1.05, y0 + 0.3, fz), (cx + 1.05, y1 - 0.3, fz), 0.3, 0.3))
					bands.append(beam((cx + 1.05, y0 + 0.3, fz), (cx - 1.05, y1 - 0.3, fz), 0.26, 0.3))
				if k < 7:
					bands.append(RB(cx - 1.75, cx + 1.75, y1 - 0.25, y1 + 0.25, cz - 1.75, cz + 1.75, BT, ST))
			bogies.append(RB(cx - 1.95, cx + 1.95, 0.45, 2.6, cz - 2.5, cz + 2.5, 0.12, 1))
			bogies.append(RB(cx - 1.7, cx + 1.7, 2.6, 3.25, cz - 2.05, cz + 2.05, BS, SS))
			for dz in (-1.4, 1.4):
				for side in (1, -1):
					x0 = cx + side * 1.55
					x1 = cx + side * 2.08
					tyres.append(rcylX(0, 0.92, cz + dz, 0.9, min(x0, x1), max(x0, x1), 14, 0.0))
	obj(c, "Legs", merge(*legs), "Crane")
	obj(c, "Bands", merge(*bands), "Crane")
	# A-frame knee braces under the girders (high, out of the stacks' play space)
	knees = []
	for sx in (1, -1):
		for sz in (1, -1):
			knees.append(beam((30 * sx, 38.0, 16 * sz - sz * 1.6), (30 * sx, 48.6, 5.0 * sz), 0.9, 0.9))
	obj(c, "Knees", merge(*knees), "Crane")
	# black-and-white striped footings round each bogie (the concept's hazard bands; no second yellow)
	stripes = []
	for sx in (1, -1):
		for sz in (1, -1):
			cx, cz = 30 * sx, 16 * sz
			for k in range(-3, 4):
				zc = cz + k * 1.4
				pts = [(zc - 0.35, 0.5), (zc + 0.35, 0.5), (zc + 1.05, 2.55), (zc + 0.35, 2.55)]
				pts = [(max(cz - 2.45, min(cz + 2.45, z)), y) for z, y in pts]
				if pts[1][0] - pts[0][0] > 0.1 and pts[2][0] - pts[3][0] > 0.1:
					for side in (1, -1):
						x0 = cx + side * 1.95
						stripes.append(RPX(pts, *sorted((x0, x0 + side * 0.06))))
	obj(c, "Stripes", merge(*stripes), "Charcoal")
	obj(c, "Bogies", merge(*bogies), "White")
	obj(c, "Tyres", merge(*tyres), "Rubber")
	girders = []
	for sz in (1, -1):
		zc = 16 * sz
		g = [(zc - 1.5, 52.65), (zc - 0.85, 52.0), (zc + 0.85, 52.0), (zc + 1.5, 52.65), (zc + 1.5, 56.0), (zc - 1.5, 56.0)]
		girders.append(RPX(g, -34.0, 34.0, BS, SS))
	for sx in (1, -1):
		p = [(-17.6, 48.6), (17.6, 48.6), (17.6, 52.4), (-17.6, 52.4)]
		girders.append(RPX(p, 30 * sx - 1.35, 30 * sx + 1.35, BS, SS))
	obj(c, "Girders", merge(*girders), "Crane")
	obj(c, "Trolley", RB(-5.0, 5.0, 56.05, 58.6, -17.6, 17.6, BS, SS), "Crane")
	obj(c, "House", RB(-3.6, 3.6, 58.55, 61.4, -6.0, 6.0, BS, SS), "White")
	obj(c, "Cab", RB(6.0, 10.4, 46.2, 50.4, 12.2, 17.0, 0.3, SS), "White")
	obj(c, "CabGlass", RB(10.3, 10.5, 47.3, 49.6, 12.9, 16.3, BT, ST), "Glass")
	hw = [RB(10.0, 11.0, 49.75, 50.05, 12.6, 16.6, BT, ST), RB(7.6, 8.8, 50.35, 52.3, 14.0, 15.4, BT, ST),
		RB(-2.5, 2.5, 27.55, 29.2, -2.0, 2.0, BS, SS)]
	for x in (-1.6, 1.6):
		for z in (-1.2, 1.2):
			hw.append(RB(x - 0.09, x + 0.09, 29.1, 56.1, z - 0.09, z + 0.09, 0.0, 1))
	obj(c, "Rigging", merge(*hw), "Charcoal")
	sp = [RB(-16.0, 16.0, 26.2, 27.6, -1.0, 1.0, BS, SS)]
	for s in (1, -1):
		sp.append(RB(s * 14.8, s * 16.2, 25.8, 27.85, -4.1, 4.1, BS, SS))
	obj(c, "Spreader", merge(*sp), "Crane")
	beacons = [RB(sx * 33.0 - 0.3, sx * 33.0 + 0.3, 55.95, 56.55, sz * 16 - 0.3, sz * 16 + 0.3, BT, ST) for sx in (1, -1) for sz in (1, -1)]
	obj(c, "Beacon", merge(*beacons), "GlowSignal")


# ---------------------------------------------------------------- shed

SH_X, SH_Z = 13.0, 18.0  # half footprint
WALL_T = 0.6
OPEN_S = [(-9.0, 1.0, 13.0)]  # roller door on the -Z wall: x range, top
OPEN_W = [(-12.0, -4.0, 9.0), (4.0, 12.0, 9.0)]  # doors on the -X wall: z range, top


def cut(a, b, holes):
	out = [(a, b)]
	for h0, h1 in holes:
		nxt = []
		for s0, s1 in out:
			if h1 <= s0 or h0 >= s1:
				nxt.append((s0, s1))
				continue
			if h0 > s0:
				nxt.append((s0, h0))
			if h1 < s1:
				nxt.append((h1, s1))
		out = nxt
	return [s for s in out if s[1] - s[0] > 0.05]


def wall(face, a0, a1, openings, parts):
	# One straight wall. face: "S" (z = -18, outward -Z), "N" (+Z), "W" (x = -13, outward -X), "E" (+X).
	# u runs along the wall (x for S/N, z for W/E); d is the outward offset from the outer face (+ = outside).
	out = {"S": -1, "N": 1, "W": -1, "E": 1}[face]
	along_x = face in ("S", "N")
	edge = SH_Z if along_x else SH_X

	def box(u0, u1, y0, y1, d0, d1, r=0.0, segs=1):
		w0, w1 = out * (edge + d0), out * (edge + d1)
		if along_x:
			return RB(u0, u1, y0, y1, w0, w1, r, segs)
		return RB(w0, w1, y0, y1, u0, u1, r, segs)

	holes = [(o[0], o[1]) for o in openings]
	for u0, u1 in cut(a0, a1, holes):
		parts["Cladding"].append(box(u0, u1, 1.45, 15.3, -WALL_T, 0.0))
		# Plinths and cornices of the long walls overrun the corners; the short ones stop at them (no overlap).
		e0 = 0.25 if along_x and u0 <= a0 + 1e-6 else (0.0 if along_x else (-0.15 if u0 <= a0 + 1e-6 else 0.0))
		e1 = 0.25 if along_x and u1 >= a1 - 1e-6 else (0.0 if along_x else (-0.15 if u1 >= a1 - 1e-6 else 0.0))
		parts["Plinth"].append(box(u0 - e0, u1 + e1, -0.1, 1.5, -WALL_T - 0.15, 0.25, BS, SS))
	for o in openings:
		parts["Cladding"].append(box(o[0], o[1], o[2], 15.3, -WALL_T, 0.0))
	# Lane band and cornice; the band stops at openings that rise through it.
	tall = [(o[0] - 0.7, o[1] + 0.7) for o in openings if o[2] > 11.0]
	for u0, u1 in cut(a0 + 0.3, a1 - 0.3, tall):
		parts["Band"].append(box(u0, u1, 11.2, 12.2, -0.12, 0.08, BT, ST))
	ce = 0.35 if along_x else 0.4
	parts["Cornice"].append(box(a0 - ce, a1 + ce, 15.25, 16.1, -0.2, 0.35, BS, SS))
	# Pilasters every ~6.5 studs, clear of the openings and their frames.
	n = max(1, int(round((a1 - a0) / 6.5)))
	for k in range(1, n):
		u = a0 + (a1 - a0) * k / n
		if any(o[0] - 1.2 < u < o[1] + 1.2 for o in openings):
			continue
		parts["Trim"].append(box(u - 0.25, u + 0.25, 1.5, 15.25, -0.08, 0.12, BT, ST))
	# Picture-frame surrounds with rounded inner corners for every opening.
	for o in openings:
		w = o[1] - o[0]
		# 0.1 inside the opening on every side, so its faces never meet the wall's cut faces.
		pts = u_frame(w - 0.2, o[2] - 0.1, 0.65, 0.45, 0.8)
		uc = (o[0] + o[1]) / 2
		if along_x:
			pts2 = [(uc + p[0], p[1]) for p in pts]
			parts["Trim"].append(RPZ(pts2, out * (edge - 0.15), out * (edge + 0.15), BT, ST))
		else:
			pts2 = [(uc + p[0], p[1]) for p in pts]
			parts["Trim"].append(RPX(pts2, out * (edge - 0.15), out * (edge + 0.15), BT, ST))


def p_shed():
	c = piece("Shed", width=26, depth=36)
	parts = {k: [] for k in ("Cladding", "Plinth", "Band", "Cornice", "Trim")}
	wall("S", -SH_X, SH_X, OPEN_S, parts)
	wall("N", -SH_X, SH_X, [], parts)
	wall("W", -SH_Z + WALL_T, SH_Z - WALL_T, OPEN_W, parts)
	wall("E", -SH_Z + WALL_T, SH_Z - WALL_T, [], parts)
	# Gable ends under the roof.
	for s in (1, -1):
		r13 = 16.0 + 6.0 * (1 - SH_X / 13.5) - 0.35
		tri = [(-SH_X, 15.3), (SH_X, 15.3), (SH_X, r13), (0.0, 21.65), (-SH_X, r13)]
		parts["Cladding"].append(RPZ(tri, s * SH_Z, s * (SH_Z - WALL_T)))
	obj(c, "Cladding", merge(*parts["Cladding"]), "Cladding")
	obj(c, "Plinth", merge(*parts["Plinth"]), "Concrete")
	obj(c, "Band", merge(*parts["Band"]), "Lane")
	obj(c, "Cornice", merge(*parts["Cornice"]), "Charcoal")
	obj(c, "Trim", merge(*parts["Trim"]), "Charcoal")
	# Roof: two slabs whose top follows the greybox roof (16 at x +-13.5 up to 22 on the ridge), 1.1 eave overhang.
	ry = lambda x: 16.0 + 6.0 * (1 - abs(x) / 13.5)
	roof = []
	for s in (1, -1):
		xe = s * 14.6
		pts = [(xe, ry(xe) - 0.45), (0.0, ry(0) - 0.45), (0.0, ry(0)), (xe, ry(xe))]
		roof.append(RPZ(pts, -SH_Z - 1.4, SH_Z + 1.4))
	obj(c, "Roof", merge(*roof), "Roof")
	cap = [(-0.9, ry(0.9) + 0.02), (0.0, ry(0) + 0.32), (0.9, ry(0.9) + 0.02), (0.9, ry(0.9) - 0.2), (-0.9, ry(0.9) - 0.2)]
	fascia = [RPZ(cap, -SH_Z - 1.5, SH_Z + 1.5, BT, ST)]
	for s in (1, -1):
		xe = s * 14.6
		fascia.append(RB(xe - 0.18, xe + 0.18, ry(xe) - 0.65, ry(xe) + 0.08, -SH_Z - 1.5, SH_Z + 1.5, BT, ST))
	# Barge boards along the gable edges (one piece over the ridge, a little past the eaves).
	xb = 14.8
	pts = [(-xb, ry(xb) + 0.06), (0.0, ry(0) + 0.06), (xb, ry(xb) + 0.06), (xb, ry(xb) - 0.6), (0.0, ry(0) - 0.6), (-xb, ry(xb) - 0.6)]
	for z in (SH_Z + 1.4, -SH_Z - 1.4):
		fascia.append(RPZ(pts, z - 0.12, z + 0.12))
	obj(c, "Fascia", merge(*fascia), "White")
	# Inside: portal frames clear of the doors, the roller drum, pendant lamps, the floor slab.
	inner = []
	# Maps v4: I-section portal frames (flanges and a web), not smooth boxes
	for z in (-15.0, 0.0, 15.0):
		for s in (1, -1):
			for fz in (z - 0.35, z + 0.25):
				inner.append(RB(s * 11.75, s * 12.35, -0.05, 14.9, fz, fz + 0.1, BT, ST))
			inner.append(RB(s * 11.99, s * 12.11, -0.05, 14.9, z - 0.26, z + 0.26))
		for fy in (14.5, 15.1):
			inner.append(RB(-12.25, 12.25, fy, fy + 0.1, z - 0.3, z + 0.3, BT, ST))
		inner.append(RB(-12.25, 12.25, 14.59, 15.11, z - 0.06, z + 0.06))
	inner.append(rcylX(0, 14.4, -SH_Z + WALL_T + 0.9, 0.7, -9.3, 1.3, 20, 0.08))
	obj(c, "Frames", merge(*inner), "Charcoal")
	lamps, lens = [], []
	for z in (-7.5, 7.5):
		for x in (-5.0, 5.0):
			lamps.append(RB(x - 0.07, x + 0.07, 13.0, 14.5, z - 0.07, z + 0.07))
			lamps.append(lathe_at(x, z, [(0.0, 13.25), (0.9, 12.75), (0.9, 12.55)]))
			lens.append(RB(x - 0.6, x + 0.6, 12.42, 12.56, z - 0.6, z + 0.6, BT, ST))
	# maps v5 float audit: the pendants hung 4 below the roof from nothing; a purlin over each lamp line now
	# runs between the portal tie beams and carries them
	for x in (-5.0, 5.0):
		lamps.append(RB(x - 0.12, x + 0.12, 14.48, 14.7, -15.3, 15.3, BT, ST))
	obj(c, "Lamps", merge(*lamps), "Charcoal")
	# Round 3: warm strips under the three tie beams, so the Shed reads lit even where PointLights don't render.
	strips = [RB(-11.0, 11.0, 14.38, 14.5, z - 0.12, z + 0.12, BT, ST) for z in (-15.0, 0.0, 15.0)]
	obj(c, "BeamGlow", merge(*strips), "GlowWarm")
	obj(c, "LampGlow", merge(*lens), "GlowWarm")
	obj(c, "Floor", RB(-SH_X + WALL_T, SH_X - WALL_T, -0.08, 0.06, -SH_Z + WALL_T, SH_Z - WALL_T), "Concrete")
	# Maps v4 shed interior kit (above head height or flat, so nothing reads as cover that isn't)
	pipes, boxes, paint, dark = [], [], [], []
	for y, r in ((11.2, 0.2), (11.8, 0.13)):
		pipes.append(RB(12.0, 12.3, y - r, y + r, -SH_Z + WALL_T + 0.05, SH_Z - WALL_T - 0.05, 0.08, 1))
	for z in (-15.0, 0.0, 15.0):
		for s in (1, -1):
			if not (s > 0 and z < 0):  # the site office stands against that column
				boxes.append(RB(s * 11.1, s * 11.8, 4.23, 5.31, z - 0.37, z + 0.37, BT, ST))
	obj(c, "Pipes", merge(*pipes), "Charcoal")
	obj(c, "JunctionBoxes", merge(*boxes), "White")
	# loading zone inside the roller door: a white field with charcoal stripes; walkway lines down the Shed
	paint.append(drop_down(RB(-9.0, 1.0, 0.06, 0.075, -SH_Z + WALL_T + 0.05, -14.2)))
	for k in range(12):
		x = -8.6 + k * 0.82
		dark.append(drop_down(RB(x, x + 0.4, 0.075, 0.085, -SH_Z + WALL_T + 0.2, -14.35)))
	for x in (-4.6, 2.4):
		paint.append(drop_down(RB(x - 0.12, x + 0.12, 0.06, 0.075, -13.6, SH_Z - WALL_T - 0.6)))
	obj(c, "FloorPaint", merge(*paint), "Hazard")
	obj(c, "FloorStripes", merge(*dark), "Charcoal")


def lathe_at(x, z, prof):
	bm = lathe(chamfer_path(prof, 0.05), steps=16)
	return xform(bm, T(x, -z, 0))


def p_shed_sign(n):
	# Maps v4 (the user's review: "SHED 02" blocky and too simple; no part-built text): a framed plate above the
	# roller door in the Shed's lane colour (1 = B half, east, green; 2 = A half, west, red) with a white band and
	# two lamp hoods: the Shed is called by its colour, and the plate is built into the facade.
	c = piece("ShedSign%d" % n)
	cx, z = -4.0, -SH_Z
	ring = ring_prism(rrect(8.9, 2.15, 0.5, 4, cx, 14.3), rrect(8.1, 1.55, 0.25, 4, cx, 14.3), -z - 0.05, -z + 0.32, "Y")
	obj(c, "Frame", finish(ring, BT, ST), "Charcoal")
	obj(c, "Plate", RB(cx - 4.1, cx + 4.1, 13.5, 15.1, z - 0.2, z + 0.1, BT, ST), "SignEast" if n == 1 else "SignWest")
	obj(c, "Band", RB(cx - 4.1, cx + 4.1, 14.05, 14.55, z - 0.26, z - 0.18), "White")
	hoods, lens = [], []
	for x in (cx - 2.8, cx + 2.8):
		hoods.append(RB(x - 0.08, x + 0.08, 15.35, 15.5, z - 1.2, z - 0.25))
		hoods.append(RB(x - 0.45, x + 0.45, 15.25, 15.6, z - 1.5, z - 0.9, BT, ST))
		lens.append(RB(x - 0.35, x + 0.35, 15.17, 15.26, z - 1.42, z - 0.98))
	obj(c, "Hoods", merge(*hoods), "Charcoal")
	obj(c, "HoodGlow", merge(*lens), "GlowWarm")


# ---------------------------------------------------------------- spawn wayfinding (fix round 1)

def arrow(cx, cy, z0, z1, point, w=1.1, h=1.0):
	# A flat triangle in the sign plane pointing along local +X (point 1) or -X (point -1).
	pts = [(cx - point * w / 2, cy - h / 2), (cx + point * w / 2, cy), (cx - point * w / 2, cy + h / 2)]
	return RPZ(pts, z0, z1, BT, ST)


def p_spawn_sign(team):
	# On the spawn baffle's face toward the alcove (origin: floor centre of that face, +Z toward the spawn). Names the
	# dock and the lane each way round the baffle, seen from the spawn: the viewer's right is local +X, which is east
	# (green) for B and west (red) for A (the A piece is placed turned 180).
	c = piece("SpawnSign" + team)
	left, right = ("RED", "GREEN") if team == "B" else ("GREEN", "RED")
	lrole, rrole = ("SignWest", "SignEast") if team == "B" else ("SignEast", "SignWest")
	# Round 2: sized for the 20-footer on top of the stepped baffle (origin = that box's face centre).
	ring = ring_prism(rrect(15.0, 6.2, 0.8, 4, 0.0, 12.0), rrect(13.9, 5.1, 0.5, 4, 0.0, 12.0), -0.42, -0.06, "Y")
	obj(c, "Frame", finish(ring, BT, ST), "Charcoal")
	obj(c, "Plate", RB(-7.05, 7.05, 9.4, 14.6, 0.08, 0.3, BT, ST), "White")
	brackets = [RB(x - 0.3, x + 0.3, y - 0.3, y + 0.3, -0.25, 0.12, BT, ST) for x in (-5.0, 5.0) for y in (9.7, 14.3)]
	obj(c, "Brackets", merge(*brackets), "Charcoal")
	bm, w = text_mesh("DOCK " + team, 1.9, depth=0.14)
	xform(bm, T(0.0, -0.3, 12.2))
	obj(c, "Title", bm, "Charcoal", smooth=0)
	bm, w = text_mesh(left, 0.85, depth=0.12)
	xform(bm, T(-6.2 + 1.4 + w / 2, -0.3, 10.0))
	bm2 = arrow(-6.3, 10.43, 0.3, 0.42, -1, 0.95, 0.9)
	obj(c, "Left", merge(bm, bm2), lrole, smooth=0)
	bm, w = text_mesh(right, 0.85, depth=0.12)
	xform(bm, T(6.2 - 1.4 - w / 2, -0.3, 10.0))
	bm2 = arrow(6.3, 10.43, 0.3, 0.42, 1, 0.95, 0.9)
	obj(c, "Right", merge(bm, bm2), rrole, smooth=0)


def p_crane_sign():
	# Round 3: a framed charcoal plate with white "CRANE" letters on the long side of the reefer stack (origin: the
	# stack's face at 4.0 from its centre, +Z outward; the ribs stand to 3.9, so brackets carry it 0.1 off them).
	c = piece("CraneSign")
	ring = ring_prism(rrect(9.6, 2.9, 0.6, 4, 0.0, 5.3), rrect(8.9, 2.2, 0.35, 4, 0.0, 5.3), -0.36, -0.04, "Y")
	obj(c, "Frame", finish(ring, BT, ST), "White")
	obj(c, "Plate", RB(-4.5, 4.5, 4.15, 6.45, 0.06, 0.24, BT, ST), "Charcoal")
	obj(c, "Brackets", merge(*[RB(x - 0.25, x + 0.25, 4.6, 6.0, -0.12, 0.08, BT, ST) for x in (-3.0, 3.0)]), "Charcoal")
	bm, w = text_mesh("CRANE", 1.25, depth=0.12)
	xform(bm, T(0.0, -0.24, 4.68))
	obj(c, "Letters", bm, "White", smooth=0)


def p_deck_word(word, role):
	# Round 2: a lane name painted on the deck (top 0.07; bay lines are 0.05), letters' tops toward local -Z, so it
	# reads for someone walking out of the spawn (-Z for B; the A copies are turned 180).
	c = piece("DeckWord" + word)
	bm, w = text_mesh(word, 3.4, depth=0.12)
	# text_mesh: upright, facing -Y (Roblox +Z), baseline at z 0. Lay it flat: letters' up -> Roblox -Z (Blender +Y).
	xform(bm, T(0.0, -1.7, 0.01) @ Matrix.Rotation(math.radians(-90), 4, "X") @ T(0.0, 0.06, 0.0))
	obj(c, "Paint", bm, role, smooth=0)


def p_chevron():
	# Deck paint: a white chevron pointing local -Z (out of the spawn), top 0.07 over the deck (bay lines are 0.05).
	c = piece("Chevron")
	pts = [(-1.6, 0.8), (0.0, -0.8), (1.6, 0.8), (0.75, 0.8), (0.0, 0.05), (-0.75, 0.8)]
	obj(c, "Paint", RPY(pts, -0.05, 0.07), "White")


# ---------------------------------------------------------------- yard props

def drop_down(bm):
	# Flat art on a floor: no bottom faces (nothing shares the floor's top plane).
	bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.normal.z < -0.99], context="FACES")
	return bm


def p_deck_drain():
	c = piece("DeckDrain")
	obj(c, "Frame", drop_down(RB(-0.9, 0.9, 0.0, 0.04, -0.6, 0.6)), "ConcreteDark")
	obj(c, "Grate", drop_down(merge(*[RB(x - 0.06, x + 0.06, 0.04, 0.06, -0.45, 0.45) for x in (-0.6, -0.36, -0.12, 0.12, 0.36, 0.6)])), "Charcoal")


def p_manhole():
	c = piece("Manhole")
	obj(c, "Cover", drop_down(lathe([(0.0, 0.045), (1.05, 0.045), (1.05, 0.0)], steps=20)), "Charcoal")
	obj(c, "Rim", drop_down(lathe([(1.05, 0.0), (1.05, 0.03), (1.2, 0.03), (1.2, 0.0)], steps=20)), "ConcreteDark")
	obj(c, "Ribs", drop_down(merge(*[RB(-0.85, 0.85, 0.045, 0.06, z - 0.05, z + 0.05) for z in (-0.5, -0.17, 0.17, 0.5)])), "Rubber")


def p_oil_stain(name, seed):
	c = piece(name)
	pts = []
	for i in range(10):
		a = 2 * math.pi * i / 10
		r = 1.0 + 0.4 * math.sin(2.7 * i + seed) + 0.2 * math.cos(4.9 * i + 2 * seed)
		pts.append((2.4 * r * math.cos(a), 1.5 * r * math.sin(a)))
	obj(c, "Stain", drop_down(RPY(pts, 0.0, 0.02)), "Stain")



def p_rack():
	# Maps v4: a pallet-rack run: uprights with horizontal and diagonal bracing between each pair, beams, and on
	# every level a slatted pallet with a carton stack (two sizes, taped), not one smooth box.
	c = piece("Rack")
	up, brace, beams, pal, cart, tape = [], [], [], [], [], []
	for z in (-6.85, -2.3, 2.3, 6.85):
		for x in (-1.0, 1.0):
			up.append(RB(x - 0.15, x + 0.15, 0.0, 7.95, z - 0.15, z + 0.15, BT, ST))
		for k in range(4):
			y0, y1 = 0.6 + k * 1.8, 0.6 + (k + 1) * 1.8
			brace.append(beam((-0.85, y0, z + 0.02 * (k % 2)), (0.85, y1, z + 0.02 * (k % 2)), 0.08, 0.08))
			brace.append(RB(-0.85, 0.85, y0 - 0.05, y0 + 0.05, z - 0.05, z + 0.05))
	for y in (0.35, 2.95, 5.55):
		for x in (-1.1, 1.1):
			beams.append(RB(x - 0.1, x + 0.1, y, y + 0.35, -6.95, 6.95, BT, ST))
	for li, y in enumerate((0.7, 3.3, 5.9)):
		for bi, zc in enumerate((-4.575, 0.0, 4.575)):
			# maps v5 float audit: the pallet spans the two beams (x +-1.1), resting on them
			pal.append(RB(-1.16, 1.16, y + 0.16, y + 0.25, zc - 1.95, zc + 1.95))
			for zz in (zc - 1.6, zc, zc + 1.6):
				pal.append(RB(-1.14, 1.14, y - 0.0, y + 0.17, zz - 0.18, zz + 0.18))
			top = y + 0.24
			seed = li * 3 + bi
			for ci, (z0, z1, h) in enumerate(((zc - 1.85, zc - 0.05, 0.9 + 0.2 * (seed % 2)), (zc + 0.05, zc + 1.85, 1.1), (zc - 1.6, zc - 0.1, 0.7))):
				yb = top if ci < 2 else top + 0.9 + 0.2 * (seed % 2) + 0.02
				if ci == 2 and seed % 3 == 0:
					continue
				cart.append(RB(-0.82, 0.82, yb, yb + h, z0, z1, BT, ST))
				tape.append(RB(-0.86, 0.86, yb + h - 0.02, yb + h + 0.01, (z0 + z1) / 2 - 0.15, (z0 + z1) / 2 + 0.15))
	obj(c, "Uprights", merge(*up), "SignMid")
	obj(c, "Bracing", merge(*brace), "Charcoal")
	obj(c, "Beams", merge(*beams), "Charcoal")
	obj(c, "Pallets", merge(*pal), "Wood")
	obj(c, "Cartons", merge(*cart), "Carton")
	obj(c, "Tape", merge(*tape), "White")


def p_office():
	c = piece("Office")
	obj(c, "Body", RB(-3.3, 3.3, 0.55, 8.45, -3.8, 3.8, 0.3, SS), "White")
	obj(c, "Base", RB(-3.5, 3.5, -0.1, 0.6, -4.0, 4.0, BS, SS), "Charcoal")
	obj(c, "Cap", RB(-3.5, 3.5, 8.4, 9.0, -4.0, 4.0, BS, SS), "Charcoal")
	obj(c, "Door", RB(-3.42, -3.22, 0.7, 6.6, -1.05, 1.05, BT, ST), "Hazard")
	glass, frames = [], []
	for s in (1, -1):
		glass.append(RB(-2.1, 2.1, 4.3, 6.9, s * 3.75, s * 3.88, BT, ST))
		ring = ring_prism(rrect(4.8, 3.2, 0.4, 4, 0.0, 5.6), rrect(4.1, 2.5, 0.2, 4, 0.0, 5.6), min(-s * 3.75, -s * 3.95), max(-s * 3.75, -s * 3.95), "Y")
		frames.append(finish(ring, BT, ST))
	obj(c, "Glass", merge(*glass), "Glass")
	obj(c, "Frames", merge(*frames), "Charcoal")


def p_crate():
	# Maps v4: the concept's crate (02-hero-middle): honey timber boards in a darker frame with an X brace, on a
	# slatted pallet, corner irons on top. Boards are geometry (gaps, depth), so the plank texture only adds grain.
	c = piece("Crate")
	pal = [RB(-1.95, 1.95, 0.02, 0.3, z - 0.24, z + 0.24, BT, ST) for z in (-1.62, 0.0, 1.62)]
	pal += [RB(x - 0.25, x + 0.25, 0.28, 0.46, -1.95, 1.95) for x in (-1.65, -1.1, -0.55, 0.0, 0.55, 1.1, 1.65)]
	obj(c, "Pallet", merge(*pal), "Wood")
	obj(c, "Core", RB(-1.62, 1.62, 0.5, 3.3, -1.62, 1.62), "CrateFrame")
	posts, rails, boards, braces, lid, irons = [], [], [], [], [], []
	for sx in (1, -1):
		for sz in (1, -1):
			x0, x1 = sorted((sx * 1.36, sx * 1.78))
			z0, z1 = sorted((sz * 1.36, sz * 1.78))
			posts.append(RB(x0, x1, 0.47, 3.42, z0, z1, BT, ST))
			irons.append(RB(min(sx * 1.2, sx * 1.81), max(sx * 1.2, sx * 1.81), 3.0, 3.46, min(sz * 1.2, sz * 1.81), max(sz * 1.2, sz * 1.81)))
	for k in range(4):  # the +X face built once, turned for the other three
		face_r, face_b, face_x = [], [], []
		face_r.append(RB(1.58, 1.74, 0.47, 0.68, -1.4, 1.4))
		face_r.append(RB(1.58, 1.74, 3.18, 3.42, -1.4, 1.4))
		for b in range(4):
			y0 = 0.7 + b * 0.62
			face_b.append(RB(1.6, 1.69, y0, y0 + 0.56, -1.4, 1.4))
		face_x.append(beam((1.71, 0.78, -1.22), (1.71, 3.08, 1.22), 0.1, 0.32))
		face_x.append(beam((1.735, 0.78, 1.22), (1.735, 3.08, -1.22), 0.1, 0.32))
		for bm in face_r + face_b + face_x:
			xform(bm, RZ(90 * k))
		rails += face_r
		boards += face_b
		braces += face_x
	for b in range(5):
		x0 = -1.36 + b * 0.55
		lid.append(RB(x0 + 0.02, x0 + 0.5, 3.26, 3.36, -1.36, 1.36))
	obj(c, "Posts", merge(*posts, *rails, *braces), "CrateFrame")
	obj(c, "Boards", merge(*boards, *lid), "CrateWood")
	obj(c, "Irons", merge(*irons), "Charcoal")


def p_quay_barrier(L, name):
	c = piece(name, length=L)
	h = L / 2
	obj(c, "Core", RB(-1.92, -0.08, -0.1, 2.6, -h + 0.02, h - 0.02), "Concrete")
	cap = [(-2.0, 2.55), (0.0, 2.55), (0.0, 2.78), (-0.22, 3.0), (-1.78, 3.0), (-2.0, 2.78)]
	obj(c, "Cap", RPZ(cap, -h, h), "Concrete")
	obj(c, "Band", RB(-1.99, -1.87, 1.55, 2.1, -h + 0.06, h - 0.06, BT, ST), "Hazard")
	# maps v5 r2: the concept's black-and-white hazard stripes on the outer band, slanted, 0.5 pitch 1.0
	st = []
	z = -h + 0.3
	while z + 0.9 < h - 0.1:
		st.append(RPX([(z, 1.58), (z + 0.5, 1.58), (z + 0.85, 2.07), (z + 0.35, 2.07)], -2.03, -1.97))
		z += 1.0
	obj(c, "Stripes", merge(*st), "Charcoal")
	obj(c, "Kick", RB(-2.0, -1.85, -0.08, 0.45, -h, h), "ConcreteDark")


def p_quay_face():
	c = piece("QuayFace8", length=8)
	obj(c, "Face", RB(-0.4, 0.12, -12.0, -0.05, -3.98, 3.98), "ConcreteDark")
	cop = [(-0.5, -0.6), (0.35, -0.6), (0.35, -0.12), (0.18, 0.06), (-0.5, 0.06)]
	obj(c, "Coping", RPZ(cop, -4.0, 4.0), "Concrete")
	# maps v5: Codex's D1 tyre fender, turned to hang flat against the face, on its chain from an eye bracket
	# under the coping (was a rubber box)
	fp = codex_import("QuaySet.glb", "TyreFender")
	for role, bms in fp.items():
		for bm in bms:
			bmesh.ops.rotate(bm, verts=bm.verts, cent=(0.0, 0.0, 0.0), matrix=Matrix.Rotation(math.radians(90.0), 3, "Z"))
			bmesh.ops.translate(bm, verts=bm.verts, vec=(0.55, 0.0, -3.62))
		obj(c, "Tyre" + role, merge(*bms), role)
	obj(c, "FenderEye", RB(0.08, 0.66, -0.66, -0.5, -0.14, 0.14, 0.03, 1), "Charcoal")


def p_bollard():
	c = piece("Bollard")
	prof = [(0.0, 1.25), (0.55, 1.25), (0.62, 1.12), (0.62, 0.95), (0.38, 0.85), (0.38, 0.22), (0.5, 0.12), (0.5, -0.1)]
	obj(c, "Body", lathe(chamfer_path(prof, BT), steps=20), "Charcoal")


def p_lamp_mast():
	c = piece("LampMast", height=27.6)
	base = merge(RB(-0.9, 0.9, -0.1, 0.8, -0.9, 0.9, BS, SS), RB(-0.65, 0.65, 0.8, 1.45, -0.65, 0.65, BS, SS))
	obj(c, "Base", base, "Concrete")
	obj(c, "Pole", lathe([(0.24, 27.1), (0.4, 1.3)], steps=8), "White")
	head = [RB(-2.7, 2.7, 27.0, 27.6, -0.35, 0.35, BT, ST)]
	lens = []
	for s in (1, -1):
		head.append(RB(s * 1.4, s * 2.7, 26.35, 27.05, -0.7, 0.7, BS, SS))
		lens.append(RB(s * 1.5, s * 2.6, 26.22, 26.38, -0.58, 0.58, BT, ST))
	obj(c, "Head", merge(*head), "Charcoal")
	obj(c, "Lens", merge(*lens), "GlowWarm")


def codex_import(glb, group):
	"""A Codex GLB group in Blender coords, kept at its local origin (the group's bottom centre). Roles from the
	material names (mapped to this map's roles)."""
	before = set(bpy.data.objects)
	bpy.ops.import_scene.gltf(filepath=os.path.join(ART, "props", glb))
	new = [o for o in bpy.data.objects if o not in before]
	bpy.context.view_layer.update()
	meshes = [o for o in new if o.type == "MESH" and (group is None or (o.parent is not None and o.parent.name == group))]
	par = None if group is None else next(o for o in new if o.name == group)
	inv = par.matrix_world.inverted() if par is not None else Matrix()
	ROLE = {"Metal": "Metal", "Accent": "SockOrange", "White": "White", "Charcoal": "Charcoal", "Rubber": "Rubber", "Wood": "Rope"}
	out = {}
	for o in meshes:
		bm = bmesh.new()
		bm.from_mesh(o.data)
		bm.transform(inv @ o.matrix_world)
		role = ROLE[o.data.materials[0].name.split(".")[0]]
		out.setdefault(role, []).append(bm)
	for o in new:
		bpy.data.objects.remove(o)
	return out


def p_windsock():
	# Maps v5: Codex's windsock on a mast (base plate, bracket), on the crane girder (the old one was Parts in the
	# air). Origin: the mast's base centre. The sock meshes keep their names for the Life sway rule.
	c = piece("Windsock")
	ws = codex_import("Windsock.glb", None)
	for role, bms in ws.items():
		for bm in bms:
			bmesh.ops.translate(bm, verts=bm.verts, vec=(2.275, 0.0, 0.0))  # mast axis (Blender x -2.275) to 0
		obj(c, ("Mast" if role == "Metal" else "Sock") + role, merge(*bms), role)


def p_rope_coil():
	c = piece("RopeCoil")
	for role, bms in codex_import("QuaySet.glb", "RopeCoil").items():
		for bm in bms:  # maps v5 r2: 0.75 (read oversized on the barrier top)
			bmesh.ops.scale(bm, verts=bm.verts, vec=(0.75, 0.75, 0.75))
		obj(c, "Coil" + role, merge(*bms), role)


def p_sts_crane():
	c = piece("StsCrane")
	legs = [RB(x - 0.9, x + 0.9, 0.0, 30.0, z - 0.9, z + 0.9, 0.3, 1) for x in (-6.0, 6.0) for z in (-10.0, 10.0)]
	legs.append(RB(-7.0, 7.0, 28.0, 31.0, -11.0, 11.0, 0.3, 1))
	legs.append(RB(-1.0, 1.0, 31.0, 47.0, -9.0, 9.0, 0.3, 1))
	obj(c, "Frame", merge(*legs), "Backfill")
	obj(c, "Boom", RB(-24.0, 46.0, 34.0, 37.0, -2.5, 2.5, 0.3, 1), "Charcoal")
	obj(c, "House", RB(-16.0, -6.0, 37.0, 41.0, -3.5, 3.5, 0.3, 1), "Roof")


def p_ship():
	c = piece("Ship")
	hull = [(-16.0, -62.0), (16.0, -62.0), (16.0, 30.0), (9.0, 44.0), (0.0, 50.0), (-9.0, 44.0), (-16.0, 30.0)]
	obj(c, "Hull", RPY(hull, 0.0, 18.4, 0.4, 1), "Hull")
	sheer = [(x * 1.004, z * 1.004) for x, z in hull]
	obj(c, "Stripe", RPY(sheer, 15.6, 16.6, 0.0, 1), "White")
	obj(c, "Bridge", RB(-14.0, 14.0, 18.3, 34.0, -61.0, -52.0, 0.4, 1), "White")
	obj(c, "Windows", RB(-12.5, 12.5, 30.0, 31.6, -52.1, -51.9), "Charcoal")


# ---------------------------------------------------------------- build

def build():
	global KIT
	for o in list(bpy.data.objects):
		bpy.data.objects.remove(o)
	for col in list(bpy.data.collections):
		bpy.data.collections.remove(col)
	materials()
	KIT = collection("Kit_Dockyard2")
	p_container("C40", 32)
	p_container("C20", 16)
	p_container("C40Lo", 32, lo=True)
	p_container("C20Lo", 16, lo=True)
	p_stair()
	p_crane()
	p_shed()
	p_shed_sign(1)
	p_shed_sign(2)
	p_rack()
	p_office()
	p_crate()
	p_quay_barrier(8.0, "QuayBarrier8")
	p_quay_barrier(3.7, "QuayBarrierShort")
	p_quay_face()
	p_bollard()
	p_lamp_mast()
	p_sts_crane()
	p_ship()
	p_windsock()  # maps v5: Codex D-job windsock, Codex D1 rope coil
	p_rope_coil()
	# maps v4: the spawn signs, chevrons, CRANE plate and deck words are cut (no part-built text)
	p_deck_drain()
	p_manhole()
	p_oil_stain("OilStainA", 1.0)
	p_oil_stain("OilStainB", 2.7)
	tris = {}
	for n, col in PIECES.items():
		t = 0
		for o in col.all_objects:
			o.data.calc_loop_triangles()
			t += len(o.data.loop_triangles)
		tris[n] = t
	os.makedirs(ART, exist_ok=True)
	bpy.ops.wm.save_as_mainfile(filepath=BLEND)
	return tris


def coplanar_audit():
	# tools/blender/audit_lobby_coplanar.py, run on this kit's Map_ collections (its logic, unchanged).
	src = open(os.path.join(HERE, "audit_lobby_coplanar.py"), encoding="utf-8").read().replace("'Lobby_'", "'Map_'")
	out = os.path.join(ART, "coplanar.json")
	argv = sys.argv
	sys.argv = ["x", "--", out]
	try:
		exec(compile(src, "audit_lobby_coplanar.py", "exec"), {"__name__": "audit"})
	finally:
		sys.argv = argv
	import json
	return json.load(open(out))


# ---------------------------------------------------------------- renders

def world(sun_el=45.0, sun_az=90.0):
	sc = bpy.context.scene
	sc.world = sc.world or bpy.data.worlds.new("W")
	sc.world.use_nodes = True
	bg = sc.world.node_tree.nodes["Background"]
	bg.inputs[0].default_value = (0.30, 0.55, 1.0, 1)
	bg.inputs[1].default_value = 1.15
	sun = bpy.data.lights.new("Sun", "SUN")
	sun.energy = 4.2
	sun.color = (1.0, 0.93, 0.82)
	sun.angle = math.radians(2.0)
	so = bpy.data.objects.new("Sun", sun)
	# Roblox ClockTime 15 at latitude 0: the sun stands over +X (map), 45 deg up.
	so.rotation_euler = (0.0, math.radians(90 - sun_el), math.radians(sun_az - 90))
	return so


def render_settings(res=(1600, 900), samples=32):
	sc = bpy.context.scene
	sc.render.engine = "BLENDER_EEVEE"
	try:
		sc.eevee.taa_render_samples = samples
	except Exception:
		pass
	sc.render.resolution_x, sc.render.resolution_y = res
	sc.view_settings.view_transform = "AgX"
	try:
		sc.view_settings.look = "AgX - Medium High Contrast"
	except Exception:
		pass
	sc.render.image_settings.file_format = "JPEG"
	sc.render.image_settings.quality = 88


def camera(loc_rb, target_rb, lens=24.0):
	cam = bpy.data.cameras.new("Cam")
	cam.lens = lens
	cam.clip_end = 4000
	co = bpy.data.objects.new("Cam", cam)
	bpy.context.scene.collection.objects.link(co)
	loc = Vector((loc_rb[0], -loc_rb[2], loc_rb[1]))
	tgt = Vector((target_rb[0], -target_rb[2], target_rb[1]))
	co.location = loc
	co.rotation_euler = (tgt - loc).to_track_quat("-Z", "Y").to_euler()
	bpy.context.scene.camera = co
	return co


def shot(path):
	bpy.context.scene.render.filepath = path
	bpy.ops.render.render(write_still=True)
	print("RENDERED", path)


def contact_sheet(names, out, cam_h=None):
	stage = collection("_Sheet")
	x = 0.0
	for n in names:
		col = PIECES[n]
		pts = [Vector(b) for o in col.all_objects for b in o.bound_box]
		mnx, mxx = min(p.x for p in pts), max(p.x for p in pts)
		mny = min(p.y for p in pts)
		e = bpy.data.objects.new("I_" + n, None)
		e.instance_type = "COLLECTION"
		e.instance_collection = col
		e.location = (x - mnx, 0, 0)
		stage.objects.link(e)
		x += (mxx - mnx) + 4
	gm = bpy.data.meshes.new("G")
	bmg = bmesh.new()
	bmesh.ops.create_grid(bmg, x_segments=1, y_segments=1, size=600)
	bmg.to_mesh(gm)
	g = bpy.data.objects.new("G", gm)
	g.data.materials.append(M["Deck"])
	stage.objects.link(g)
	return stage, x


def tinted_copy(name, hexcol):
	# A copy of a kit piece with its Lane / LaneFrame materials tinted (previews only, never exported).
	key = "_T_%s_%s" % (name, hexcol)
	if key in bpy.data.collections:
		return bpy.data.collections[key]
	src = PIECES[name]
	col = bpy.data.collections.new(key)
	for o in src.all_objects:
		cp = o.copy()
		mat = o.material_slots[0].material if o.material_slots else None
		if mat and mat.name in ("D2_Lane", "D2_LaneFrame"):
			k = 1.0 if mat.name == "D2_Lane" else S.FRAME_SHADE
			mk = "D2T_%s_%s" % (mat.name, hexcol)
			if mk not in bpy.data.materials:
				m2 = _flat(mk, int(S.shade(hexcol, k), 16), 0.6, metallic=0.25)
				m2.use_fake_user = False
			cp.data = o.data.copy()
			cp.data.materials[0] = bpy.data.materials[mk]
		col.objects.link(cp)
	return col


def yard_preview():
	import dockyard2_art as A
	puts, parts = A.build()
	stage = collection("_Yard")
	for p in puts:
		if p.piece not in PIECES:
			continue
		col = PIECES[p.piece]
		if p.lane:
			hexcol = S.LANE.get(p.lane) or S.BACKDROP[int(p.lane[2:])]
			col = tinted_copy(p.piece, hexcol)
		e = bpy.data.objects.new("P_" + p.piece, None)
		e.instance_type = "COLLECTION"
		e.instance_collection = col
		e.location = (p.x, -p.z, p.y)
		e.rotation_euler = (0, 0, math.radians(p.yaw))
		stage.objects.link(e)
	for q in parts:
		sx, sy, sz = q.size
		px, py, pz = q.pos
		bm = RB(px - sx / 2, px + sx / 2, py - sy / 2, py + sy / 2, pz - sz / 2, pz + sz / 2)
		ob = add_obj("Q_" + q.name, bm, [M[q.role]], stage, smooth_angle=0)
	import dockyard2_layout as L
	deck = RB(-L.PIER_X, L.PIER_X, -4.0, 0.0, -L.DECK_END, L.DECK_END)
	add_obj("Q_Deck", deck, [M["Deck"]], stage, smooth_angle=0)
	return stage


if __name__ == "__main__":
	tris = build()
	print("DOCKYARD2_TRIS", sum(tris.values()), tris)
	found = coplanar_audit()
	print("COPLANAR", len(found))
	for f in found[:25]:
		print("  ", f["piece"], f["a"], f["b"], f["area"])
	if "--render" in ARGS or "--preview" in ARGS:
		render_settings()
		world()
		# The masters sit at the origin; only their instances may render.
		for lc in bpy.context.view_layer.layer_collection.children:
			if lc.name == "Kit_Dockyard2":
				lc.exclude = True
	if "--render" in ARGS:
		os.makedirs(RENDER_DIR, exist_ok=True)
		stage, w = contact_sheet(["C20", "C40", "C20Lo", "Stair", "Crate", "Rack", "Office", "QuayBarrier8", "QuayFace8", "Bollard", "LampMast"], "a")
		camera((w / 2, 26, 62), (w / 2, 2, -4), 22)
		shot(os.path.join(RENDER_DIR, "kit-contact-a.jpg"))
		bpy.data.collections.remove(stage)
		stage, w = contact_sheet(["Shed", "ShedSign1", "Crane"], "b")
		camera((w / 2, 52, 120), (w / 2, 14, 0), 22)
		shot(os.path.join(RENDER_DIR, "kit-contact-b.jpg"))
		bpy.data.collections.remove(stage)
	if "--closeups" in ARGS:  # maps v4: close 3/4 renders of the rebuilt pieces (scratch)
		if "--render" not in ARGS and "--preview" not in ARGS:
			render_settings()
			world()
			for lc in bpy.context.view_layer.layer_collection.children:
				if lc.name == "Kit_Dockyard2":
					lc.exclude = True
		out = os.environ.get("CLOSEUP_DIR", RENDER_DIR)
		stage, w = contact_sheet(["Crate", "Rack", "DeckDrain", "Manhole", "OilStainA"], "v4a")
		camera((w * 0.5 + 3, 9, 20), (w * 0.5, 2.5, 0), 30)
		shot(os.path.join(out, "closeup-d2-v4a.jpg"))
		camera((-2, 9.0, -14), (-3, 4, 8), 30)
		shot(os.path.join(out, "closeup-d2-v4b.jpg"))
		bpy.data.collections.remove(stage)
		stage, w = contact_sheet(["Shed", "ShedSign1"], "v4c")
		camera((-4, 6, -40), (-4, 9, 0), 30)
		shot(os.path.join(out, "closeup-d2-v4c.jpg"))
		bpy.data.collections.remove(stage)
	if "--preview" in ARGS:
		yard_preview()
		camera((22, 20, 88), (0, 10, 0), 24)
		shot(os.path.join(RENDER_DIR, "style-frame-from-b-spawn.jpg"))
		camera((-4, 5.5, 22), (4, 5, -8), 24)
		shot(os.path.join(RENDER_DIR, "style-frame-middle.jpg"))
		camera((-118, 92, -150), (0, 0, 0), 30)
		shot(os.path.join(RENDER_DIR, "style-frame-overview.jpg"))
		camera((-58, 6, 60), (-40, 7, 0), 26)
		shot(os.path.join(RENDER_DIR, "style-frame-apron.jpg"))
