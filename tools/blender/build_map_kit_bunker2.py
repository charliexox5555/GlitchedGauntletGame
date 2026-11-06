# build_map_kit_bunker2.py: the Bunker2 map kit, group "Kit" (vault/01 Design/Maps/Bunker2.md; the Map Quality Standard,
# vault/01 Design/Maps/Map Quality Standard.md). The concepts (art-source/maps/Bunker2/concepts/02-hero, 03-kit-sheet)
# are the quality reference: board-formed concrete over olive bunker paint with an end-colour band, dark steel headers
# with warm coves, concrete piers with cage lamps, brass rails and trims, a gold-capped sun plinth on a star compass,
# a trussed skylight, a jammed cross-braced blast door, and machines that tell the rooms' stories.
#
# Every visible thing is a bevelled mesh (rounded edges: concrete 0.3-0.45, steel 0.12-0.25, small parts 0.05-0.1),
# nothing thinner than 0.2, rail posts 0.4. Board joints, tie holes, plate seams and chips are in the MaterialVariant
# textures (tools/textures/make_bunker2_textures.py); the meshes carry the big forms. No text in meshes: sign text is
# a rendered-font decal applied in Studio. Materials are roles B2_<Role> from tools/maps/bunker2_style.py, so a palette
# change never needs this script.
#
# Pieces keep the old Bunker kit's names and origins (tools/blender/build_map_kit_bunker.py header), so
# tools/maps/bunker2_art.py places them with the proven rules; new: Pier12 (a wall pier with a cage lamp), Rail4
# (railing module, replaces the stretched Rail8), Wall pieces are authored 8 long and placed in modules of 6-10 so
# textures never stretch more than about 25%.
# Coordinates: ROBLOX piece-local (x, y up, z); Blender = (x, -z, y), the importer's mapping.
#
# Run (headless, no lock needed):
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup \
#       --python tools/blender/build_map_kit_bunker2.py -- [--no-render] [--samples N]
# Writes art-source/maps/Bunker2/Kit_Bunker2.blend, the face export (Exports/Bunker2_faces.json, checked on the dressed
# map by tools/maps/bunker2_art.py), art-source/maps/Bunker2/coplanar.json (in-piece check, must be 0) and the contact
# sheet vault/02 Art/References/maps/bunker2/contact-bunker2.jpg (with a 5-stud R15 proxy for scale).
# Export: blender --background --factory-startup art-source/maps/Bunker2/Kit_Bunker2.blend \
#           --python tools/blender/export_lobby_kit.py -- --maps Bunker2 Kit

import json, math, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "maps"))
import bpy, bmesh  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402
import lobbykit as K  # noqa: E402
from build_lobby_kit_stylized import prism, finish, rbox, rcyl, xform, T, merge  # noqa: E402
import bunker2_style as S  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ART_DIR = os.path.join(K.ROOT, "art-source", "maps", "Bunker2")
RENDER_DIR = os.path.join(K.ROOT, "vault", "02 Art", "References", "maps", "bunker2")
FACES_OUT = os.path.join(ART_DIR, "Exports", "Bunker2_faces.json")
COPLANAR_OUT = os.path.join(ART_DIR, "coplanar.json")

M = {}
PIECES = []


def materials():
	for role, (hx, rbx, var) in S.PALETTE.items():
		c = int(hx, 16)
		if rbx == "Neon":
			m = K._emissive("B2_" + role, c, 6.0)
		elif rbx == "Glass":
			m = K._flat("B2_" + role, c, 0.1, rbx="Glass", rbx_transparency=0.55)
		else:
			rough = 0.35 if rbx == "SmoothPlastic" else 0.7
			metal = 0.6 if role in ("Brass", "Gold") else 0.0
			m = K._flat("B2_" + role, c, rough, metallic=metal, rbx=rbx)
		m["rbx_variant"] = var
		M[role] = m
	M["_Floor"] = K._flat("Preview_Floor", 0x6A665F, 0.8, rbx="Concrete")


# ---------------------------------------------------------------- Roblox-space helpers

def RB(x0, x1, y0, y1, z0, z1, r=0.0, segs=2):
	"""Box from Roblox piece-local bounds, edges rounded by r (segs 2: 3 self-overlaps at some sizes)."""
	x0, x1 = sorted((x0, x1))
	y0, y1 = sorted((y0, y1))
	z0, z1 = sorted((z0, z1))
	return rbox(x0, x1, -z1, -z0, y0, y1, r, segs)


def RPZ(pts, z0, z1, r=0.0, segs=2):
	"""Profile in (x, y), extruded along Roblox Z."""
	return finish(prism(list(pts), "Y", -max(z0, z1), -min(z0, z1)), r, segs)


def RPX(pts, x0, x1, r=0.0, segs=2):
	"""Profile in (z, y), extruded along Roblox X."""
	return finish(prism([(-z, y) for z, y in pts], "X", min(x0, x1), max(x0, x1)), r, segs)


def RPY(pts, y0, y1, r=0.0, segs=2):
	"""Footprint in (x, z), extruded up along Roblox Y."""
	return finish(prism([(x, -z) for x, z in pts], "Z", min(y0, y1), max(y0, y1)), r, segs)


def ccw(pts):
	a = sum(pts[i][0] * pts[(i + 1) % len(pts)][1] - pts[(i + 1) % len(pts)][0] * pts[i][1] for i in range(len(pts)))
	return pts if a > 0 else pts[::-1]


def vcyl(x, z, r, y0, y1, n=16, bev=0.06):
	"""Cylinder along Roblox Y."""
	return rcyl(r, y0, y1, n, min(bev, r * 0.4), 2, cx=x, cy=-z)


def xcyl(y, z, r, x0, x1, n=16, bev=0.06):
	"""Cylinder along Roblox X centred on (y, z)."""
	bm = rcyl(r, x0, x1, n, min(bev, r * 0.4), 2)
	return xform(bm, T(0, -z, y) @ Matrix.Rotation(math.radians(90), 4, "Y"))


def zcyl(x, y, r, z0, z1, n=16, bev=0.06):
	"""Cylinder along Roblox Z centred on (x, y)."""
	bm = rcyl(r, z0, z1, n, min(bev, r * 0.4), 2)
	return xform(bm, T(x, 0, y) @ Matrix.Rotation(math.radians(90), 4, "X"))


def bar(p0, p1, w, h=None, up=(0.0, 1.0, 0.0)):
	"""Square-section bar from p0 to p1 (Roblox coords)."""
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


def pyramid(half, y0, y1):
	bm = bmesh.new()
	b = [bm.verts.new((x, y, y0)) for x, y in ((-half, -half), (half, -half), (half, half), (-half, half))]
	apex = bm.verts.new((0.0, 0.0, y1))
	bm.faces.new(b[::-1])
	for i in range(4):
		bm.faces.new((b[i], b[(i + 1) % 4], apex))
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	return bm


def clip(poly, x0, x1, y0, y1):
	"""Sutherland-Hodgman clip of a polygon to a rectangle (for hazard stripes)."""
	def edge(pts, inside, inter):
		out = []
		for i in range(len(pts)):
			a, b = pts[i - 1], pts[i]
			if inside(b):
				if not inside(a):
					out.append(inter(a, b))
				out.append(b)
			elif inside(a):
				out.append(inter(a, b))
		return out

	def ix(c):
		return lambda a, b: (c, a[1] + (b[1] - a[1]) * (c - a[0]) / (b[0] - a[0]))

	def iy(c):
		return lambda a, b: (a[0] + (b[0] - a[0]) * (c - a[1]) / (b[1] - a[1]), c)

	p = poly
	for inside, inter in ((lambda q: q[0] >= x0, ix(x0)), (lambda q: q[0] <= x1, ix(x1)), (lambda q: q[1] >= y0, iy(y0)), (lambda q: q[1] <= y1, iy(y1))):
		if not p:
			break
		p = edge(p, inside, inter)
	return p


def stripes(u0, u1, v0, v1, pitch=0.9, width=0.45, slant=1.0):
	"""Diagonal hazard stripes clipped to the rectangle [u0,u1] x [v0,v1]: list of polygons in (u, v)."""
	out = []
	h = v1 - v0
	u = u0 - h * slant
	while u < u1:
		poly = [(u, v0), (u + width, v0), (u + width + h * slant, v1), (u + h * slant, v1)]
		c = clip(poly, u0, u1, v0, v1)
		if len(c) >= 3:
			area = 0.5 * abs(sum(c[i][0] * c[(i + 1) % len(c)][1] - c[(i + 1) % len(c)][0] * c[i][1] for i in range(len(c))))
			if area > 0.02:
				out.append(ccw(c))
		u += pitch
	return out


def piece(name, parts):
	"""parts: {part: (bmesh or [bmesh], role)}. Neon roles become <Piece>_<Part>_Glow objects."""
	col = K.collection("Map_" + name, KIT)
	for part, (bms, role) in parts.items():
		if isinstance(bms, (list, tuple)):
			bms = [b for b in bms if b is not None]
			if not bms:
				continue
			bm = merge(*bms) if len(bms) > 1 else bms[0]
		else:
			bm = bms
		oname = "%s_%s" % (name, part)
		if S.PALETTE[role][1] == "Neon":
			ob = K.add_glow(oname, bm, M[role], col)
		else:
			ob = K.add_obj(oname, bm, [M[role]], col, smooth_angle=35)
			if role == "Glass":
				ob.visible_shadow = False
	PIECES.append((name, col))
	return col


# ---------------------------------------------------------------- walls

WALL_DEPTH = 0.36  # deepest cladding layer (the header); tools/maps/bunker2_art.py D_CLAD = this + 0.02


def wall_parts(H, L=8.0):
	"""A wall module H tall, L long (z -L/2..L/2), facing +X from the wall face at x 0."""
	h = L / 2
	hdr0 = H - 1.0
	return {
		"Steel": ([
			RB(0, 0.3, 0, 0.8, -h, h, 0.05, 1),  # kick plate
			RB(0, WALL_DEPTH, hdr0, H - 0.02, -h, h, 0.08),  # header channel
		], "SteelDark"),
		"Paint": (RB(0, 0.2, 0.8, 4.0, -h, h, 0.05), "Olive"),
		"Band": (RB(0, 0.24, 4.0, 5.1, -h, h, 0.05), "Band"),
		"Field": (RB(0, 0.12, 5.1, hdr0, -h, h), "Board"),
		"Cove": (RB(0.1, 0.26, hdr0 - 0.1, hdr0, -h + 0.05, h - 0.05), "Cove"),
	}


def p_walls():
	piece("Clad12", wall_parts(12.0))
	piece("Clad10", wall_parts(10.5))
	# Upper band of the tall rooms (placed at y 12, up to the 26 ceiling): a string course at the deck line, the
	# lighter board field, and a cornice with a cove under it.
	piece("Field14", {
		"Course": ([RB(0, 0.3, 0.03, 0.5, -4, 4, 0.1), RB(0, 0.4, 13.0, 13.98, -4, 4, 0.12)], "BoardLight"),
		"Field": (RB(0, 0.14, 0.5, 13.0, -4, 4), "BoardLight"),
		"Cove": (RB(0.12, 0.3, 12.9, 13.0, -3.95, 3.95), "Cove"),
	})
	# Convex corner: a concrete pier filling the quadrant x 0..0.62, z 0..0.62 (the notch the two claddings leave),
	# stacked like the walls (steel foot, olive, band, board, steel cap).
	a = 0.62
	piece("CornerPost12", {
		"Foot": ([RB(0, a + 0.06, 0, 0.85, 0, a + 0.06, 0.05, 1), RB(0, a + 0.08, 11.0, 11.98, 0, a + 0.08, 0.08)], "SteelDark"),
		"Paint": (RB(0, a + 0.04, 0.85, 4.05, 0, a + 0.04, 0.08), "Olive"),
		"Band": (RB(0, a + 0.05, 4.05, 5.15, 0, a + 0.05, 0.06), "Band"),
		"Body": (RB(0, a, 5.15, 11.0, 0, a, 0.15), "Board"),
	})
	piece("CornerPost14", {
		"Body": ([RB(0, a, 0, 13.0, 0, a, 0.15), RB(0, a + 0.1, 13.0, 13.98, 0, a + 0.1, 0.12)], "BoardLight"),
	})


def cage_lamp_x(x0, y, z, scale=1.0):
	"""A bulkhead cage lamp on a surface facing +X at x0: plate, glass (glow), brass cage and cap."""
	s = scale
	plate = RB(x0, x0 + 0.14 * s, y - 0.6 * s, y + 0.6 * s, z - 0.42 * s, z + 0.42 * s, 0.05)
	glow = xcyl(y, z, 0.27 * s, x0 + 0.14 * s, x0 + 0.72 * s, n=14)
	cage = [xcyl(y, z, 0.37 * s, xx - 0.1 * s, xx + 0.1 * s, n=16, bev=0.04) for xx in (x0 + 0.3 * s, x0 + 0.56 * s)]
	cage.append(xcyl(y, z, 0.3 * s, x0 + 0.72 * s, x0 + 0.86 * s, n=14, bev=0.05))
	for dy, dz in ((0.33, 0), (-0.33, 0), (0, 0.33), (0, -0.33)):
		cage.append(RB(x0 + 0.14 * s, x0 + 0.76 * s, y + (dy - 0.1) * s, y + (dy + 0.1) * s, z + (dz - 0.1) * s, z + (dz + 0.1) * s, 0.03, 1))
	return plate, glow, cage


def p_pier():
	# A wall pier (pilaster) every 12-16 studs on long ground-band walls: steel foot, olive and band wrap, a rounded
	# concrete shaft, a steel capital under the header line, and a cage lamp on its face at 7.5.
	plate, glow, cage = cage_lamp_x(0.95, 7.6, 0.0)
	piece("Pier12", {
		"Steel": ([RB(0, 1.05, 0, 0.85, -0.95, 0.95, 0.06, 1), RB(0, 1.15, 10.84, 11.98, -1.0, 1.0, 0.1)], "SteelDark"),
		"Paint": (RB(0, 1.0, 0.85, 4.05, -0.9, 0.9, 0.08), "Olive"),
		"Band": (RB(0, 1.02, 4.05, 5.15, -0.92, 0.92, 0.06), "Band"),
		"Shaft": (RB(0, 0.95, 5.15, 10.84, -0.85, 0.85, 0.3), "Board"),
		"LampPlate": (plate, "Steel"),
		"Lamp": (glow, "Lamp"),
		"Cage": (cage, "Brass"),
	})
	plate, glow, cage = cage_lamp_x(0.12, 8.6, 0.0)
	piece("WallLamp", {"LampPlate": (plate, "Steel"), "Lamp": (glow, "Lamp"), "Cage": (cage, "Brass")})


# ---------------------------------------------------------------- doors

def p_door_lining():
	# 8 x 10 opening through a 2-thick wall (x -1..1), opening along Z (z -4..4). Steel lining inside, a steel frame on
	# both faces (jambs and a head up to 11.95, proud 0.5 of the wall), warm glow strips on the jambs, a sign plate on
	# each head (Art.luau puts the room name decal on it, or removes it under a deck).
	lining = [
		RB(-1.45, 1.45, 0, 0.05, -4, 4, 0.0),
		RB(-1.45, 1.45, 0.05, 9.6, -4, -3.85, 0.0),
		RB(-1.45, 1.45, 0.05, 9.6, 3.85, 4, 0.0),
		RB(-1.45, 1.45, 9.6, 10.0, -4, 4, 0.0),
	]
	frame, glow, bolts = [], [], []
	for s in (1, -1):
		xa, xb = s * 1.0, s * 1.5
		for zs in (1, -1):
			frame.append(RB(xa, xb, 0, 10.1 if zs > 0 else 10.16, zs * 3.92, zs * 4.45, 0.12))
			glow.append(RB(xb, s * 1.56, 1.0, 9.0, zs * 4.08, zs * 4.3, 0.02, 1))
		frame.append(RB(xa, xb, 10.0, 11.95, -4.45, 4.45, 0.12))
		for zc in (-2.6, 2.6):
			for yc in (10.45, 11.5):
				bolts.append(xcyl(yc, zc, 0.11, s * 1.62, s * 1.7, n=8, bev=0.03))
	piece("DoorLining", {
		"Lining": (lining, "SteelDark"),
		"Frame": (frame, "Steel"),
		"Glow": (glow, "Cove"),
		"SignP": (RB(1.5, 1.62, 10.22, 11.73, -2.9, 2.9, 0.04, 1), "Sign"),
		"SignM": (RB(-1.62, -1.5, 10.22, 11.73, -2.9, 2.9, 0.04, 1), "Sign"),
		"Bolts": (bolts, "Brass"),
	})


def p_blast_door():
	# The gallery's jammed blast door (opening z -7..7 through the 2-thick back wall; the leaf stuck at z 1..6.85). The
	# gallery face (+X) gets concrete piers and a concrete head over a steel frame; the vestibule face only lips.
	lining = [
		RB(-1.45, 1, 0, 0.05, -7, 7, 0.0),
		RB(-1.45, 1, 0.05, 11.85, -7, -6.85, 0.0),
		RB(-1.45, 1, 0.05, 11.85, 6.85, 7, 0.0),
		RB(-1.45, 1, 11.85, 12.0, -7, 7, 0.0),
	]
	frame = [
		RB(1.0, 1.92, 0, 12.3, -8.4, -6.85, 0.15),
		RB(1.0, 1.92, 0, 12.3, 6.85, 8.4, 0.15),
		RB(1.0, 1.92, 12.0, 13.4, -8.4, 8.4, 0.15),
	]
	piers = [
		RB(1.0, 2.5, 0, 14.6, -10.0, -8.4, 0.35),
		RB(1.0, 2.5, 0, 14.6, 8.4, 10.0, 0.35),
		RB(1.0, 2.5, 13.4, 14.6, -8.4, 8.4, 0.3),
	]
	feet = [RB(1.03, 2.6, 0.03, 0.9, zs * 8.3, zs * 10.1, 0.06, 1) for zs in (1, -1)]
	bolts = []
	for zc in (-7.62, 7.62):
		for k in range(7):
			bolts.append(xcyl(1.0 + k * 1.6, zc, 0.16, 1.92, 2.02, n=8, bev=0.04))
	leaf = [RB(-0.5, 0.5, 0.05, 11.85, 1.0, 6.85, 0.1)]
	ribs, braces = [], []
	for s in (1, -1):
		xa, xb = s * 0.5, s * 0.7
		ribs += [RB(xa, xb, 0.3, 11.6, 1.2, 1.7, 0.06), RB(xa, xb, 0.3, 11.6, 6.15, 6.65, 0.06),
				 RB(xa, xb, 11.1, 11.6, 1.7, 6.15, 0.06), RB(xa, xb, 2.4, 2.9, 1.7, 6.15, 0.06),
				 RB(xa, xb, 6.7, 7.2, 1.7, 6.15, 0.06)]
		# X braces in the two panels (one diagonal deeper than the other, so their faces never share a plane)
		for (y0, y1) in ((2.9, 6.7), (7.2, 11.1)):
			for k, (za, zb) in enumerate(((1.7, 6.15), (6.15, 1.7))):
				d = 0.18 if k == 0 else 0.12
				w = 0.32
				pts = [(za, y0), (za + w * (1 if zb > za else -1), y0), (zb, y1 - 0), (zb - w * (1 if zb > za else -1), y1)]
				braces.append(RPX(ccw([(p[0], p[1]) for p in pts]), s * (0.53 if k == 0 else 0.57), s * (0.5 + d + (0 if k == 0 else 0.04)), 0.0))
	hinge = vcyl(0.0, 6.95, 0.42, 0.12, 11.78, n=14, bev=0.08)
	hz_base, hz = [], []
	for s in (1, -1):
		hz_base.append(RB(s * 0.5, s * 0.58, 0.3, 2.3, 1.75, 6.1, 0.0))
		for poly in stripes(1.75, 6.1, 0.3, 2.3, pitch=0.9, width=0.45, slant=0.8):
			hz.append(RPX(poly, s * 0.58, s * 0.63, 0.0))
	piece("BlastDoor", {
		"Lining": (lining, "SteelDark"),
		"Frame": (frame + bolts, "Steel"),
		"Piers": (piers, "Board"),
		"Feet": (feet, "SteelDark"),
		"Sign": (RB(1.92, 2.02, 12.3, 13.1, -3.6, 3.6, 0.04, 1), "Sign"),
		"Leaf": (leaf, "Door"),
		"Ribs": (ribs + braces + [hinge], "Steel"),
		"HazardBase": (hz_base, "Ink"),
		"Hazard": (hz, "Hazard"),
	})


# ---------------------------------------------------------------- structure

def p_structure():
	piece("Pilaster14", {
		"Body": (RB(0, 0.95, 0, 12.0, -0.85, 0.85, 0.3), "BoardLight"),
		"Cap": (RB(0, 1.15, 12.0, 12.5, -1.0, 1.0, 0.1), "SteelDark"),
	})
	piece("Corbel", {
		"Body": ([RB(0, 1.1, -0.9, 0, -0.8, 0.8, 0.12), RB(0, 0.7, -1.6, -0.9, -0.6, 0.6, 0.1)], "BoardLight"),
		"Plate": (RB(1.1, 1.2, -0.85, -0.05, -0.55, 0.55, 0.03, 1), "SteelDark"),
	})
	piece("Beam8", {
		"Body": (RB(-0.7, 0.7, -1.5, 0, -4, 4, 0.2), "BoardLight"),
		"Soffit": (RB(-0.5, 0.5, -1.58, -1.46, -3.9, 3.9, 0.02, 1), "SteelDark"),
	})


def p_shaft():
	# Shaft lining (y 0 = the sunwell ceiling at 26, up to the skylight at 64): a steel rim with a cove, the light
	# board field, and two steel ring beams that give the 38-tall shaft scale.
	piece("ShaftPanel8", {
		"Rim": ([RB(0.06, 0.35, 0, 0.7, -3.97, 3.97, 0.06), RB(0.06, 0.4, 12.7, 13.3, -3.97, 3.97, 0.08), RB(0.06, 0.4, 25.4, 26.0, -3.97, 3.97, 0.08)], "SteelDark"),
		"Cove": (RB(0.14, 0.3, 0.7, 0.78, -3.95, 3.95), "Cove"),
		"Field": (RB(0, 0.15, 0.7, 38.0, -4, 4), "BoardLight"),
	})
	# Skylight (y 0 = 64): the old steel curb, glazing bars at two depths and the glass, under a trussed frame: corner and
	# mid posts, a top chord ring at 2.2, zig-zag diagonals in each side and a cross on top (the concept's truss).
	curb = [RB(-14, 12, 0, 0.8, 12, 14, 0.06), RB(12, 14, 0, 0.8, -12, 14, 0.06),
			RB(-12, 14, 0, 0.8, -14, -12, 0.06), RB(-14, -12, 0, 0.8, -14, 12, 0.06)]
	gbars = []
	for c in (-6.0, 0.0, 6.0):
		gbars.append(RB(-12, 12, 0.1, 0.7, c - 0.12, c + 0.12, 0.0))
		gbars.append(RB(c - 0.12, c + 0.12, 0.2, 0.6, -12, 12, 0.0))
	tr = []
	top = 2.6
	e = 12.6
	for sx in (-1, 1):
		for sz in (-1, 1):
			tr.append(bar((sx * e, 0.8, sz * e), (sx * e, top + 0.25, sz * e), 0.5))
	for k in range(4):
		ang = k * math.pi / 2
		ux, uz = round(math.cos(ang)), round(math.sin(ang))
		vx, vz = -uz, ux
		a = (ux * e + vx * e, ux * e + vx * e)
		# top chord along this side
		p0 = (ux * e - vx * e, top, uz * e - vz * e)
		p1 = (ux * e + vx * e, top, uz * e + vz * e)
		tr.append(bar(p0, p1, 0.46 if k % 2 == 0 else 0.36, 0.4 if k % 2 == 0 else 0.33, up=(ux, 0, uz)))
		tr.append(bar((ux * e, 0.8, uz * e), (ux * e, top - 0.05, uz * e), 0.26))
		for t0, t1 in ((-1.0, 0.0), (0.0, 1.0)):
			ei = e - (0.1 if k % 2 else 0.16)
			q0 = (ux * ei + vx * e * t0 * 0.97, 0.8 if t0 == -1.0 else top, uz * ei + vz * e * t0 * 0.97)
			q1 = (ux * ei + vx * e * t1 * 0.97, top if t0 == -1.0 else 0.8, uz * ei + vz * e * t1 * 0.97)
			tr.append(bar(q0, q1, 0.21, up=(ux, 0, uz)))
		# roof cross: from the side's midpoint to the centre (a hip)
		tr.append(bar((ux * e, top, uz * e), (0.0, top + 1.6, 0.0), 0.36))
		tr.append(bar((ux * e - vx * e, top, uz * e - vz * e), (0.0, top + 1.6, 0.0), 0.3))
	piece("ShaftTop", {
		"Curb": (curb + gbars, "SteelDark"),
		"Truss": (tr, "Steel"),
		"Hub": (vcyl(0, 0, 0.6, top + 1.2, top + 2.0, n=12, bev=0.1), "Brass"),
		"Glass": (RB(-11.95, 11.95, 0.35, 0.45, -11.95, 11.95, 0.0), "Glass"),
	})


def p_sun():
	# The sun dais: a two-step honed slab (16 x 16 collision footprint kept), an inlaid brass compass: an outer ring, an
	# inner ring and a 16-point star whose long points run on the axes (the plinth sits on the star's centre).
	slab = [RB(-8, 8, 0, 0.3, -8, 8, 0.1, 1), RB(-7.4, 7.4, 0.3, 0.5, -7.4, 7.4, 0.08, 1)]
	ring = [K.mat_all(K.arc(r0, r1, a0, a0 + 179.5, 0.5, 0.55, steps=36), 0) for r0, r1 in ((6.3, 6.7), (5.85, 6.0)) for a0 in (0.25, 180.25)]
	pts = []
	for k in range(16):
		a = math.radians(22.5 * k)
		ux, uz = math.cos(a), math.sin(a)
		vx, vz = -uz, ux
		long_ = k % 4 == 0
		mid_ = k % 2 == 0
		r0 = 4.15 if long_ else (5.8 if mid_ else 5.9)
		r1 = 7.3 if long_ else (6.95 if mid_ else 6.45)
		w = 0.55 if long_ else (0.42 if mid_ else 0.3)
		if not long_ and mid_:
			r0 = 5.75  # diagonals start outside the plinth's corners (5.66)
		tri = [(ux * r0 + vx * w, uz * r0 + vz * w), (ux * r1, uz * r1), (ux * r0 - vx * w, uz * r0 - vz * w)]
		pts.append(RPY(ccw(tri), 0.525, 0.58))
	# corner diamonds on the outer step
	dia = []
	for sx in (-1, 1):
		for sz in (-1, 1):
			c = (sx * 7.7, sz * 7.7)
			dia.append(RPY(ccw([(c[0], c[1] - 0.25), (c[0] + 0.25, c[1]), (c[0], c[1] + 0.25), (c[0] - 0.25, c[1])]), 0.3, 0.35))
	piece("SunDais", {"Slab": (slab, "Dais"), "Compass": (ring + pts, "Brass"), "Diamonds": (dia, "Brass")})
	# The plinth: three rounded board-formed courses over a darker core (the seams read), a brass collar and a gold
	# pyramid cap (the brightest thing on the map, in the sun).
	courses = [RB(-4, 4, a, b, -4, 4, 0.25) for a, b in ((0.5, 3.1), (3.18, 5.78), (5.86, 8.5))]
	piece("SunPlinth", {
		"Core": (RB(-3.85, 3.85, 0.55, 8.4, -3.85, 3.85, 0.0), "Ceiling"),
		"Courses": (courses, "BoardLight"),
		"Collar": (RB(-4.15, 4.15, 8.5, 8.78, -4.15, 4.15, 0.08), "Brass"),
		"Cap": (pyramid(3.9, 8.78, 10.9), "Gold"),
	})


def p_ring():
	# The ring and overlook deck edge: a rounded concrete fascia and a cove strip tucked under the slab.
	piece("RingEdge8", {
		"Fascia": (RB(0, 0.32, 10.2, 12.3, -4, 4, 0.1), "BoardLight"),
		"Cove": (RB(-0.45, -0.15, 10.42, 10.5, -3.95, 3.95), "Cove"),
	})
	# Railing module on a parapet top (y 0 = 15), 4 long: a concrete coping, two 0.4 brass posts (pitch 2 across modules)
	# and a brass top rail.
	piece("Rail4", {
		"Coping": (RB(-0.62, 0.62, 0, 0.25, -2, 2, 0.08), "BoardLight"),
		"Rail": ([RB(-0.13, 0.13, 0.25, 1.15, zc - 0.13, zc + 0.13, 0.05) for zc in (-1.0, 1.0)] + [zcyl(0.0, 1.27, 0.16, -2, 2, n=10, bev=0.0)], "Brass"),
	})


def p_stair():
	# 16 concrete steps with steel nosings, rising toward -Z from z 0 (y 0) to z -18 (y 12); each tread top sits on the
	# collision ramp at its centre. The open side (-X) has a steel stringer and a brass handrail on 0.4 posts.
	n, run, rise = 16, 18.0, 12.0
	go, up = run / n, rise / n
	x0, x1 = -3.0, 2.65
	treads, nos = [], []
	for i in range(n):
		za, zb = -i * go, -(i + 1) * go
		top = (i + 0.5) * up
		treads.append(RB(x0, x1, 0, top - 0.1, zb, za, 0.0))
		nos.append(RB(x0 + 0.05, x1 - 0.05, top - 0.1, top, za - 0.3, za, 0.03, 1))
	slope = rise / run
	stringer = RPX([(0.0, 0.0), (0.0, 0.9), (-run, rise + 0.45), (-run, rise - 0.55)], -3.25, -3.0, 0.05)
	posts = []
	for k in range(5):
		zc = -1.0 - k * 4.0
		ytop = (-zc) * slope + 0.4
		posts.append(RB(-3.33, -2.93, ytop - 0.5, ytop + 2.6, zc - 0.2, zc + 0.2, 0.06))
	rail = RPX([(-0.6, 0.6 * slope + 2.6), (-0.6, 0.6 * slope + 2.9), (-17.4, 17.4 * slope + 2.9), (-17.4, 17.4 * slope + 2.6)], -3.3, -2.96, 0.06)
	piece("GalleryStair", {
		"Treads": (treads, "Board"),
		"Nosings": (nos, "SteelDark"),
		"Stringer": (stringer, "Steel"),
		"Rail": (posts + [rail], "Brass"),
	})


# ---------------------------------------------------------------- props

def p_lockers():
	def bank(z0, z1, x_back, x_front, both=False):
		parts = {"body": [], "kick": [], "doors": [], "vents": [], "handles": [], "crown": []}
		n = int(round(z1 - z0))
		faces = [(x_front, 1)] + ([(-x_front, -1)] if both else [])
		xb = -x_front + 0.05 if both else x_back
		parts["body"].append(RB(xb, x_front - 0.05, 0.35, 7.6, z0, z1, 0.06))
		parts["kick"].append(RB(xb + 0.1 if both else x_back + 0.05, x_front - 0.15, 0, 0.35, z0 + 0.05, z1 - 0.05, 0.03, 1))
		parts["crown"].append(RB(xb - (0.05 if both else 0), x_front + 0.02, 7.6, 7.95, z0 - (0.04 if both else 0.0), z1 + (0.04 if both else 0.0), 0.06))
		for xf, s in faces:
			face = xf - 0.05 * s
			for i in range(n):
				a, b = z0 + i, z0 + i + 1
				parts["doors"].append(RB(face, face + 0.08 * s, 0.55, 7.4, a + 0.05, b - 0.05, 0.04, 1))
				for y in (6.3, 6.6, 6.9, 1.0, 1.3):
					parts["vents"].append(RB(face + 0.08 * s, face + 0.13 * s, y, y + 0.14, a + 0.25, b - 0.25, 0.02, 1))
				parts["handles"].append(RB(face + 0.08 * s, face + 0.2 * s, 3.5, 4.5, b - 0.3, b - 0.1, 0.04, 1))
		return parts

	for name, args in (("Lockers4", (-2.0, 2.0, 0.35, 2.0, False)), ("LockerIsland", (-4.0, 4.0, 0.0, 2.0, True))):
		b = bank(*args)
		parts = {
			"Body": (b["body"], "Locker"),
			"Kick": (b["kick"] + b["crown"], "SteelDark"),
			"Doors": (b["doors"], "LockerDoor"),
			"Vents": (b["vents"], "SteelDark"),
			"Handles": (b["handles"], "Brass"),
		}
		if name == "LockerIsland":
			# a bench along each face (feet to the floor), the island's story
			bench = []
			for s in (1, -1):
				bench.append(RB(s * 2.6, s * 3.6, 1.35, 1.65, -3.4, 3.4, 0.08))
				for zc in (-3.0, 3.0):
					bench.append(RB(s * 2.9, s * 3.3, 0, 1.35, zc - 0.2, zc + 0.2, 0.05, 1))
			parts["Bench"] = (bench, "Steel")
		piece(name, parts)


def p_rack():
	# Two server racks (2 wide each) against a wall: dark frames, mesh doors (Steel texture), amber LED rows, a top vent.
	body, doors, leds, vents = [], [], [], []
	body.append(RB(0.35, 1.9, 0, 8.0, -2, 2, 0.08))
	for a, b in ((-2.0, 0.0), (0.0, 2.0)):
		doors.append(RB(1.9, 1.98, 0.4, 7.6, a + 0.1, b - 0.1, 0.04, 1))
		for k in range(8):
			y = 1.2 + k * 0.75
			leds.append(RB(1.98, 2.04, y, y + 0.12, a + 0.3, a + 0.3 + (0.9 if k % 2 else 0.5), 0.0))
		vents.append(RB(1.98, 2.06, 6.8, 7.3, a + 0.25, b - 0.25, 0.03, 1))
	piece("Rack4", {
		"Frame": (body, "Rack"),
		"Doors": (doors, "SteelDark"),
		"Vents": (vents, "Steel"),
		"Led": (leds, "Status"),
	})


def p_console():
	# A control desk, 8 long, 2 deep, 3 tall (half cover): a rounded olive body with a sloped top, three screens with
	# dark bezels, button rows, a kick and an upright monitor hood at the back.
	body = RPZ([(-1.0, 0.0), (1.0, 0.0), (1.0, 2.3), (-0.2, 3.0), (-1.0, 3.0)], -4, 4, 0.08)
	dx, dy = -1.2, 0.7
	ln = math.hypot(dx, dy)
	nx, ny = -dy / ln, dx / ln
	if ny < 0:
		nx, ny = -nx, -ny

	def on_slope(t0, t1, o0, o1, a, b):
		p0 = (1.0 + dx * t0, 2.3 + dy * t0)
		p1 = (1.0 + dx * t1, 2.3 + dy * t1)
		pts = [(p0[0] + nx * o0, p0[1] + ny * o0), (p1[0] + nx * o0, p1[1] + ny * o0), (p1[0] + nx * o1, p1[1] + ny * o1), (p0[0] + nx * o1, p0[1] + ny * o1)]
		return RPZ(ccw(pts), a, b, 0.0)

	bezels, screens, buttons = [], [], []
	for a, b in ((-3.6, -1.4), (-1.1, 1.1), (1.4, 3.6)):
		bezels.append(on_slope(0.38, 0.95, 0.0, 0.06, a, b))
		screens.append(on_slope(0.45, 0.88, 0.06, 0.09, a + 0.15, b - 0.15))
		for k in range(3):
			c = a + 0.35 + k * 0.6
			buttons.append(on_slope(0.1, 0.26, 0.0, 0.07, c, c + 0.35))
	hood = [RB(-1.0, -0.6, 3.0, 5.6, -3.0, 3.0, 0.1)]
	mon = RB(-0.6, -0.54, 3.4, 5.2, -2.7, 2.7, 0.0)
	kick = RB(-0.9, 0.95, 0.03, 0.3, -3.9, 3.9, 0.03, 1)
	piece("Console8", {
		"Body": (body, "Console"),
		"Kick": ([kick] + hood + bezels, "SteelDark"),
		"Screen": (screens + [mon], "ScreenGlow"),
		"Buttons": (buttons, "Status"),
	})


def p_generators():
	# Generators on the cover blocks (4 x 6 or 6 x 6, 7 tall): a skid, a rounded brushed housing, a radiator fin pack on
	# the front end, a control box with status lights, an exhaust stack, and a brass guard rail on the skid.
	for name, w, d in (("Gen46", 4.0, 6.0), ("Gen66", 6.0, 6.0)):
		hw, hd = w / 2, d / 2
		fins = []
		nf = int((w - 0.8) / 0.45)
		for k in range(nf):
			x = -hw + 0.6 + k * 0.45
			fins.append(RB(x - 0.1, x + 0.1, 1.0, 5.6, hd - 1.2, hd - 0.15, 0.04, 1))
		rail = []
		for sx in (-1, 1):
			for sz in (-1, 1):
				rail.append(RB(sx * hw - 0.2 * sx - 0.2, sx * hw - 0.2 * sx + 0.2, 0.5, 1.9, sz * hd - 0.2 * sz - 0.2, sz * hd - 0.2 * sz + 0.2, 0.06))
		for sz in (-1, 1):
			rail.append(RB(-hw + 0.1, hw - 0.1, 1.9, 2.2, sz * (hd - 0.2) - 0.15, sz * (hd - 0.2) + 0.15, 0.06))
		for sx in (-1, 1):
			rail.append(RB(sx * (hw - 0.2) - 0.15, sx * (hw - 0.2) + 0.15, 1.87, 2.17, -hd + 0.1, hd - 0.1, 0.06))
		piece(name, {
			"Skid": (RB(-hw, hw, 0, 0.5, -hd, hd, 0.08, 1), "SteelDark"),
			"Housing": ([RB(-hw + 0.5, hw - 0.5, 0.5, 6.0, -hd + 0.5, hd - 1.2, 0.3)], "Machine"),
			"Fins": (fins + [RB(-hw + 0.45, hw - 0.45, 0.5, 1.0, hd - 1.25, hd - 0.1, 0.05, 1), RB(-hw + 0.45, hw - 0.45, 5.6, 6.0, hd - 1.25, hd - 0.1, 0.05, 1)], "Fins"),
			"Box": ([RB(hw - 0.5, hw - 0.2, 2.4, 4.8, -hd + 1.2, -hd + 3.2, 0.06)], "SteelDark"),
			"Status": ([RB(hw - 0.2, hw - 0.14, 4.1, 4.4, -hd + 1.5, -hd + 2.9, 0.0)], "Status"),
			"Exhaust": ([vcyl(-hw * 0.3, -hd * 0.35, 0.35, 6.0, 7.0, n=12), vcyl(-hw * 0.3, -hd * 0.35, 0.45, 6.75, 6.95, n=12)], "Pipe"),
			"Rail": (rail, "Brass"),
		})


def valve_wheel(x0, y, z, r):
	"""A hand wheel facing +X at x0: a rim ring, four spokes and a hub on a stem."""
	w = 0.16
	rim = K.mat_all(K.arc(r - 0.12, r, 0.0, 359.0, 0.0, w, steps=20), 0)
	rim = xform(rim, T(x0, -z, y) @ Matrix.Rotation(math.radians(90), 4, "Y") @ Matrix.Rotation(math.radians(90), 4, "Z"))
	out = [rim]
	for k in range(2):
		a = math.radians(45 + 90 * k)
		dy, dz = math.cos(a) * (r - 0.08), math.sin(a) * (r - 0.08)
		out.append(bar((x0 + w / 2, y - dy, z - dz), (x0 + w / 2, y + dy, z + dz), 0.05 if k == 0 else 0.11, 0.1))
	out.append(xcyl(y, z, 0.16, x0 - 0.12, x0 + w + 0.04, n=10, bev=0.03))
	return out


def p_pump():
	# The pump room's skid (10 x 12 x 8 cover block against the outer wall, 0.35 off it): a concrete plinth, two pumps
	# (motor + volute) on a steel base, pipes with elbows and flanges rising into the ceiling, valve wheels, a control
	# cabinet against the wall with a status panel.
	pipes, flanges, wheels, motors, vol = [], [], [], [], []
	for zc in (-3.0, 3.0):
		motors.append(xcyl(2.4, zc, 1.1, 4.5, 8.4, n=18, bev=0.15))  # motor along X
		motors.append(RB(4.3, 8.6, 0.8, 1.3, zc - 1.0, zc + 1.0, 0.06))
		vol.append(xcyl(2.6, zc, 1.6, 3.2, 4.5, n=20, bev=0.2))  # volute
		pipes.append(vcyl(3.85, zc, 0.6, 4.1, 12.0, n=14))  # riser to the ceiling
		flanges.append(vcyl(3.85, zc, 0.85, 4.0, 4.35, n=14, bev=0.05))
		flanges.append(vcyl(3.85, zc, 0.85, 8.6, 8.95, n=14, bev=0.05))
		flanges.append(vcyl(3.85, zc, 0.85, 11.4, 11.75, n=14, bev=0.05))
		wheels += valve_wheel(4.55, 6.3, zc, 0.75)
	cab = RB(0.35, 2.6, 0.8, 8.0, -5.9, 5.9, 0.12)
	piece("PumpUnit", {
		"Plinth": (RB(0.35, 10.0, 0, 0.8, -6, 6, 0.2), "Board"),
		"Cabinet": (cab, "Machine"),
		"Motor": (motors, "Machine"),
		"Volute": (vol, "Olive"),
		"Pipes": (pipes, "Pipe"),
		"Flanges": (flanges, "SteelDark"),
		"Wheels": (wheels, "Valve"),
		"Panel": (RB(2.6, 2.7, 4.8, 6.8, -1.0, 1.0, 0.03, 1), "SteelDark"),
		"Status": (RB(2.7, 2.76, 5.3, 6.4, -0.7, 0.7, 0.0), "Status"),
		"Plate": (RB(2.6, 2.68, 2.6, 3.8, -0.8, 0.8, 0.0), "Hazard"),
	})
	risers = [vcyl(1.0, zc, 0.3, 2.9, 12.0, n=12) for zc in (-1.2, 0.0, 1.2)]
	wheels = [w for zc in (-1.2, 0.0, 1.2) for w in valve_wheel(1.55, 2.4, zc, 0.45)]
	piece("Manifold", {
		"Header": (zcyl(1.0, 2.4, 0.55, -1.95, 1.95, n=16), "Pipe"),
		"Risers": (risers, "Pipe"),
		"Brackets": ([RB(0.35, 1.5, 0, 1.9, -1.75, -1.35, 0.05), RB(0.35, 1.5, 0, 1.9, 1.35, 1.75, 0.05)], "SteelDark"),
		"Wheels": (wheels, "Valve"),
	})


def case(x0, x1, y0, y1, z0, z1):
	"""A rugged hard case: a rounded olive body, a lid line, brass corner guards, two latches and a handle."""
	body = RB(x0, x1, y0, y1, z0, z1, 0.14)
	lid = RB(x0 - 0.04, x1 + 0.04, y1 - 0.75, y1 - 0.6, z0 - 0.04, z1 + 0.04, 0.03, 1)
	corners = []
	for xs in (x0, x1):
		for zs in (z0, z1):
			cx = xs - 0.02 if xs == x0 else xs + 0.02
			cz = zs - 0.02 if zs == z0 else zs + 0.02
			corners.append(RB(min(xs, cx) - 0.05 if xs == x0 else xs - 0.35, max(xs, cx) + 0.35 if xs == x0 else cx + 0.05, y0 + 0.05, y1 - 0.05,
							   min(zs, cz) - 0.05 if zs == z0 else zs - 0.35, max(zs, cz) + 0.35 if zs == z0 else cz + 0.05, 0.05, 1))
	latch = [RB(x1, x1 + 0.1, y1 - 1.0, y1 - 0.45, zc - 0.22, zc + 0.22, 0.03, 1) for zc in (z0 + 0.25 * (z1 - z0), z0 + 0.75 * (z1 - z0))]
	handle = RB(x1 + 0.02, x1 + 0.22, (y0 + y1) / 2 - 0.15, (y0 + y1) / 2 + 0.15, (z0 + z1) / 2 - 0.6, (z0 + z1) / 2 + 0.6, 0.05, 1)
	return body, lid, corners, latch + [handle]


def p_cases():
	def stack(boxes, pallet=None):
		parts = {"Body": [], "Lid": [], "Corners": [], "Hardware": []}
		for bx in boxes:
			b, l, c, h = case(*bx)
			parts["Body"].append(b)
			parts["Lid"].append(l)
			parts["Corners"] += c
			parts["Hardware"] += h
		out = {"Body": (parts["Body"], "Case"), "Lid": (parts["Lid"], "SteelDark"), "Corners": (parts["Corners"], "Brass"),
			   "Hardware": (parts["Hardware"], "SteelDark")}
		if pallet:
			out["Pallet"] = (pallet, "Steel")
		return out

	boxes = []
	for y0, y1 in ((0.5, 3.7), (3.75, 6.95)):
		for z0, z1 in ((-2.9, -0.08), (0.08, 2.9)):
			boxes.append((0.45, 3.75, y0, y1, z0, z1))
	pallet = [RB(0.35, 4.0, 0.3, 0.5, -3.0, 3.0, 0.04, 1)] + [RB(0.35, 4.0, 0, 0.3, zc - 0.4, zc + 0.4, 0.04, 1) for zc in (-2.4, 0.0, 2.4)]
	piece("CrateStack", stack(boxes, pallet))
	boxes = [(0.45, 2.8, 0, 2.6, -2.9, -0.08), (0.45, 2.8, 0, 2.6, 0.08, 2.9), (0.6, 2.5, 2.64, 3.9, -1.6, 0.9)]
	piece("CrateRow", stack(boxes))


def p_fixtures():
	piece("LinearLight", {
		"Housing": ([RB(-0.45, 0.45, -0.35, 0, -2.1, 2.1, 0.08)] + [RB(-0.1, 0.1, -0.02, 0.0, zc - 0.1, zc + 0.1, 0.0) for zc in ()], "SteelDark"),
		"Tube": (RB(-0.3, 0.3, -0.45, -0.35, -1.95, 1.95, 0.03, 1), "Lamp"),
	})
	# Ceiling cage lamp: a canopy, a stem, a brass cage around a glowing bulb.
	cage = [RB(bx - 0.1, bx + 0.1, -1.15, -0.45, bz - 0.1, bz + 0.1, 0.03, 1) for bx, bz in ((0.36, 0), (-0.36, 0), (0, 0.36), (0, -0.36))]
	cage += [vcyl(0, 0, 0.46, -0.55, -0.4, n=16, bev=0.04), vcyl(0, 0, 0.46, -1.2, -1.05, n=16, bev=0.04)]
	piece("CageLamp", {
		"Canopy": ([vcyl(0, 0, 0.45, -0.18, 0.0, n=14), vcyl(0, 0, 0.12, -0.45, -0.18, n=8)], "SteelDark"),
		"Cage": (cage, "Brass"),
		"Bulb": (vcyl(0, 0, 0.3, -1.05, -0.5, n=14, bev=0.1), "Lamp"),
	})
	# A pipe run on brackets (8 long module, stretched little): water and a darker conduit.
	piece("PipeRun8", {
		"Brackets": ([RB(0.14, 1.25, 9.2, 11.75, zc - 0.15, zc + 0.15, 0.05) for zc in (-2.5, 2.5)], "SteelDark"),
		"Water": (zcyl(0.75, 10.1, 0.45, -4, 4, n=14), "Pipe"),
		"Conduit": (zcyl(0.6, 11.2, 0.3, -4, 4, n=12), "Steel"),
	})
	piece("SpawnPanel", {
		"Plate": (RB(0.4, 0.52, 5.6, 11.4, -3.0, 3.0, 0.06), "Sign"),
		"Frame": ([RB(0.36, 0.6, 5.4, 5.6, -3.2, 3.2, 0.05), RB(0.36, 0.6, 11.4, 11.6, -3.2, 3.2, 0.05),
				   RB(0.36, 0.6, 5.6, 11.4, -3.2, -3.0, 0.03, 1), RB(0.36, 0.6, 5.6, 11.4, 3.0, 3.2, 0.03, 1),
				   RB(0.24, 0.4, 5.6, 6.0, -2.4, 2.4, 0.03, 1)], "Brass"),
		"Bolts": ([xcyl(y, z, 0.12, 0.52, 0.62, n=8, bev=0.03) for y in (5.95, 11.05) for z in (-2.7, 2.7)], "SteelDark"),
	})
	# stripes() works in (u = z, v = x)
	hz = []
	for poly in stripes(-3.85, 3.85, -0.62, 0.62, pitch=0.9, width=0.45, slant=0.9):
		hz.append(RPY(ccw([(v, u) for u, v in poly]), 0.05, 0.1, 0.0))
	piece("FloorLine16", {"Line": (RB(1.0, 1.3, 0.0, 0.04, -8, 8, 0.0), "Line")})
	piece("HazardSill", {"Base": (RB(-0.75, 0.75, 0, 0.05, -4, 4, 0.0), "Ink"), "Stripes": (hz, "Hazard")})


# ---------------------------------------------------------------- face export + the in-piece coplanar check

def b2r(v):
	return (v[0], v[2], -v[1])


def face_rects(ob):
	me = ob.data
	bm = bmesh.new()
	bm.from_mesh(me)
	bm.faces.ensure_lookup_table()
	island = {}
	idx = 0
	for f in bm.faces:
		if f.index in island:
			continue
		stack = [f]
		while stack:
			g = stack.pop()
			if g.index in island:
				continue
			island[g.index] = idx
			for e in g.edges:
				for h in e.link_faces:
					if h.index not in island:
						stack.append(h)
		idx += 1
	fkey = {}
	for f in bm.faces:
		n = f.normal
		rn = (n.x, n.z, -n.y)
		ax = max(range(3), key=lambda k: abs(rn[k]))
		if abs(rn[ax]) < 0.9995:
			continue
		pts = [b2r(v.co) for v in f.verts]
		fkey[f.index] = (ax, 1 if rn[ax] > 0 else -1, round(sum(p[ax] for p in pts) / len(pts), 4))
	patch = {}
	pid = 0
	for f in bm.faces:
		if f.index not in fkey or f.index in patch:
			continue
		stack = [f]
		while stack:
			g = stack.pop()
			if g.index in patch:
				continue
			patch[g.index] = pid
			for e in g.edges:
				for h in e.link_faces:
					if h.index not in patch and fkey.get(h.index) == fkey[f.index]:
						stack.append(h)
		pid += 1
	area, box2 = {}, {}
	for f in bm.faces:
		if f.index in fkey:
			ax = fkey[f.index][0]
			o = [k for k in range(3) if k != ax]
			pts = [b2r(v.co) for v in f.verts]
			area[patch[f.index]] = area.get(patch[f.index], 0.0) + f.calc_area()
			b = box2.setdefault(patch[f.index], [math.inf, -math.inf, math.inf, -math.inf])
			for p in pts:
				b[0], b[1] = min(b[0], p[o[0]]), max(b[1], p[o[0]])
				b[2], b[3] = min(b[2], p[o[1]]), max(b[3], p[o[1]])
	rect = {k: area[k] >= 0.98 * (b[1] - b[0]) * (b[3] - b[2]) for k, b in box2.items()}
	groups = {}
	POLY.clear()
	for f in bm.faces:
		if f.index not in fkey:
			continue
		ax, sign, plane = fkey[f.index]
		if not rect[patch[f.index]]:
			o2 = [k for k in range(3) if k != ax]
			POLY[f.index] = [(round(b2r(v.co)[o2[0]], 4), round(b2r(v.co)[o2[1]], 4)) for v in f.verts]
		pts = [b2r(v.co) for v in f.verts]
		key = (patch[f.index], -1 if rect[patch[f.index]] else f.index, ax, sign, plane)
		o = [k for k in range(3) if k != ax]
		g = groups.setdefault(key, [math.inf, -math.inf, math.inf, -math.inf])
		for p in pts:
			g[0] = min(g[0], p[o[0]])
			g[1] = max(g[1], p[o[0]])
			g[2] = min(g[2], p[o[1]])
			g[3] = max(g[3], p[o[1]])
	bm.free()
	out = []
	for (isl, _sub, ax, sign, plane), g in groups.items():
		poly = None
		if _sub != -1:
			poly = POLY[_sub]
		out.append((isl, ax, sign, plane, (round(g[0], 4), round(g[1], 4)), (round(g[2], 4), round(g[3], 4)), poly))
	return out


POLY = {}


def poly_area(p):
	return 0.5 * abs(sum(p[i][0] * p[(i + 1) % len(p)][1] - p[(i + 1) % len(p)][0] * p[i][1] for i in range(len(p))))


def convex_overlap(a, b):
	"""Area of the intersection of two convex polygons (Sutherland-Hodgman, b as the clipper)."""
	a = ccw(list(a))
	b = ccw(list(b))
	out = a
	for i in range(len(b)):
		c0, c1 = b[i - 1], b[i]
		inp, out = out, []
		if not inp:
			break

		def inside(p):
			return (c1[0] - c0[0]) * (p[1] - c0[1]) - (c1[1] - c0[1]) * (p[0] - c0[0]) >= -1e-9

		def inter(p, q):
			x1, y1, x2, y2 = p[0], p[1], q[0], q[1]
			x3, y3, x4, y4 = c0[0], c0[1], c1[0], c1[1]
			den = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4)
			if abs(den) < 1e-12:
				return q
			t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / den
			return (x1 + t * (x2 - x1), y1 + t * (y2 - y1))

		for j in range(len(inp)):
			p, q = inp[j - 1], inp[j]
			if inside(q):
				if not inside(p):
					out.append(inter(p, q))
				out.append(q)
			elif inside(p):
				out.append(inter(p, q))
	return poly_area(out) if len(out) >= 3 else 0.0


def piece_check(rects_by_obj):
	items = []
	for oname, rects in rects_by_obj.items():
		for isl, ax, sign, plane, ur, vr, poly in rects:
			items.append((oname, isl, ax, sign, plane, ur, vr, poly))
	bad = []
	for i in range(len(items)):
		a = items[i]
		for j in range(i + 1, len(items)):
			b = items[j]
			if a[0] == b[0] and a[1] == b[1]:
				continue
			if a[2] != b[2] or a[3] != b[3] or abs(a[4] - b[4]) >= 0.02:
				continue
			u0, u1 = max(a[5][0], b[5][0]), min(a[5][1], b[5][1])
			v0, v1 = max(a[6][0], b[6][0]), min(a[6][1], b[6][1])
			if u1 - u0 >= 0.05 and v1 - v0 >= 0.05:
				if a[7] or b[7]:
					pa = a[7] or [(a[5][0], a[6][0]), (a[5][1], a[6][0]), (a[5][1], a[6][1]), (a[5][0], a[6][1])]
					pb = b[7] or [(b[5][0], b[6][0]), (b[5][1], b[6][0]), (b[5][1], b[6][1]), (b[5][0], b[6][1])]
					ov = convex_overlap(pa, pb)
					if ov < 0.0025:
						continue
					bad.append((a[0], b[0], "xyz"[a[2]], a[3], round(a[4], 3), round(ov, 3)))
					continue
				bad.append((a[0], b[0], "xyz"[a[2]], a[3], round(a[4], 3), round((u1 - u0) * (v1 - v0), 3)))
	return bad


def export_faces():
	data = {"note": "axis-aligned face rectangles per kit part, Roblox piece-local (x, y up, z); per entry: "
					"[axis 0/1/2, sign, plane, [u0, u1], [v0, v1]] on the two other axes in order", "pieces": {}}
	problems = {}
	for name, col in PIECES:
		by_obj = {}
		for ob in col.all_objects:
			if ob.type != "MESH" or ob.get("preview_only"):
				continue
			by_obj[ob.name] = face_rects(ob)
		bad = piece_check(by_obj)
		if bad:
			problems[name] = bad
		data["pieces"][name] = {o: [[ax, s, p, list(u), list(v)] + ([poly] if poly else []) for _, ax, s, p, u, v, poly in r] for o, r in by_obj.items()}
	os.makedirs(os.path.dirname(FACES_OUT), exist_ok=True)
	with open(FACES_OUT, "w") as f:
		json.dump(data, f)
	with open(COPLANAR_OUT, "w") as f:
		json.dump({k: v for k, v in problems.items()}, f, indent=1)
	n = sum(len(v) for v in problems.values())
	print("BUNKER2_PIECE_COPLANAR %d" % n)
	for name, bad in problems.items():
		for b in bad[:6]:
			print("  ", name, b)
	return n


# ---------------------------------------------------------------- contact sheet (with a 5-stud R15 proxy)

def samples(default):
	return int(ARGS[ARGS.index("--samples") + 1]) if "--samples" in ARGS else default


def sheet(tris):
	sc = bpy.context.scene
	stage = K.collection("Sheet")
	cell = 30.0
	ncol = 7
	order = sorted(PIECES, key=lambda t: t[0])
	nrow = (len(order) + ncol - 1) // ncol
	fl = K.add_obj("SheetFloor", K.cbox(-cell * (nrow - 0.4), cell * 0.6, -cell * 0.6, cell * (ncol - 0.4), -0.2, 0, ch=0), [M["_Floor"]], stage)
	fl["preview_only"] = True
	for idx, (name, col) in enumerate(order):
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
		s = min(1.0, 22.0 / max(size.x, size.y, size.z, 0.01))
		ctr = (lo + hi) / 2
		px, py = -r * cell, c * cell
		m = Matrix.Translation((px, py, 0)) @ Matrix.Scale(s, 4) @ Matrix.Translation((-ctr.x, -ctr.y, -lo.z))
		e = bpy.data.objects.new("Sheet_" + name, None)
		e.instance_type = "COLLECTION"
		e.instance_collection = col
		e.matrix_world = m
		stage.objects.link(e)
		if abs(s - 1) < 1e-3:
			K.avatar((px + 6.0, py + 9.0, 0), facing=0, col=stage, name="Proxy_" + name)  # 5-stud R15 proxy for scale
		label = "%s  %d tris  %.1fx%.1fx%.1f%s" % (name, tris[name], size.x, size.z, size.y, "" if abs(s - 1) < 1e-3 else "  (x%.2f)" % s)
		K.text(label, 1.2, (px + 12.5, py, 0.05), stage, M["Cove"], rot=(0, 0, 90), font=K.FONT_LABEL)
	sun = bpy.data.lights.new("SheetSun", "SUN")
	sun.energy = 3.2
	sun.angle = math.radians(3)
	so = bpy.data.objects.new("SheetSun", sun)
	stage.objects.link(so)
	so.rotation_euler = (math.radians(42), math.radians(-25), math.radians(200))
	w = sc.world or bpy.data.worlds.new("World")
	sc.world = w
	w.use_nodes = True
	bg = w.node_tree.nodes.get("Background")
	if bg:
		bg.inputs[0].default_value = (*K.lin(0x5A6272), 1)
		bg.inputs[1].default_value = 1.3
	cx, cy = -(nrow - 1) * cell / 2, (ncol - 1) * cell / 2
	cam = K.camera((cx + 260, cy + 60, 250), (cx, cy, 4), lens=50, name="SheetCam", col=stage)
	cam.data.type = "ORTHO"
	cam.data.ortho_scale = cell * ncol * 1.05
	K.render_settings(samples=samples(24))
	try:
		sc.eevee.use_raytracing = False
	except AttributeError:
		pass
	K.bloom(strength=0.35)
	return stage


# ---------------------------------------------------------------- main

def main():
	global KIT
	K.begin()
	materials()
	KIT = K.collection("Kit")
	p_walls()
	p_pier()
	p_door_lining()
	p_blast_door()
	p_structure()
	p_shaft()
	p_sun()
	p_ring()
	p_stair()
	p_lockers()
	p_rack()
	p_console()
	p_generators()
	p_pump()
	p_cases()
	p_fixtures()
	tris, worst = {}, {}
	for name, col in PIECES:
		tris[name] = K.tri_count(col)
		for ob in col.all_objects:
			if ob.type == "MESH":
				ob.data.calc_loop_triangles()
				worst[ob.name] = len(ob.data.loop_triangles)
	print("BUNKER2_TRIS " + json.dumps(tris))
	print("BUNKER2_TOTAL %d" % sum(tris.values()))
	print("BUNKER2_MAX_OBJECT " + json.dumps(max(worst.items(), key=lambda kv: kv[1])))
	export_faces()
	os.makedirs(ART_DIR, exist_ok=True)
	bpy.context.view_layer.layer_collection.children["Kit"].exclude = True
	path = os.path.join(ART_DIR, "Kit_Bunker2.blend")
	bpy.ops.wm.save_as_mainfile(filepath=path)
	print("BUNKER2 saved", path)
	if "--no-render" in ARGS:
		return
	os.makedirs(RENDER_DIR, exist_ok=True)
	st = sheet(tris)
	K.render(os.path.join(RENDER_DIR, "contact-bunker2.jpg"), res=(2400, 1700))
	bpy.context.view_layer.layer_collection.children[st.name].exclude = True


KIT = None
main()
