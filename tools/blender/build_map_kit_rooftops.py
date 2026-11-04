# build_map_kit_rooftops.py: the Rooftops map kit (vault/01 Design/Maps/Rooftops.md), one kit group "Kit".
#
# Every piece is a collection Map_<Piece> built at the world origin, authored in ROBLOX map-local coordinates
# (studs, +Y up) through RB()/rb() and converted to Blender (x, -z, y), so a vertex at Roblox (x, y, z) lands back
# at (x, y, z) after export (kit_bundle.py maps Blender (x, y, z) -> Roblox (x, z, -y)). Objects are <Piece>_<Part>;
# *_Wall parts take the building's brick tone in Studio, *_Glow parts are Neon (RoofSign / SignTower glow is tinted
# per side). Origins (Roblox local):
#   Facade8A/B/C, Facade4   top centre of the wall's front face (y 0 = the roof level), facing +X, 8 / 4 wide along
#                           Z, 72 tall (6 storeys of 12, a window on each). No top, bottom or end caps: columns butt.
#   Plinth8 / Plinth4       street storey of the taller towers: front slab 0.35 proud, origin at the street.
#   Quoin                   building corner (outward faces +X and +Z) at the roof level; runs 80 down; carries the
#                           cornice's corner block.
#   Flue                    top centre of an 8 x 6 brick shaft (depth along X, its back -X against a building), 82 tall.
#   Stair16, Gangway16, PlankRamp16   floor centre of an 8 x 16 footprint at the low end, rising 8 toward +Z
#                           (like the WedgePart). Catwalk8: deck top centre of an 8 x 8 flat footbridge (along Z).
#   ACUnit 8x4x7.5 (long along X), Condenser 4x4x3, Skylight 8x4x3, Penthouse 40x8x11 (door +Z), StairHut 6x6x9,
#   LiftHouse 8x8x10, LiftTower 10x8x16, TankHouse 10x10x8, CoolingTower 10x10x8 (doors +X): floor centre.
#   WaterTank               base centre of the 4 legs (4 tall), drum 4.4-14, cap to 16.
#   Billboard               floor centre between its legs (legs at x +-5), panel 18 x 10 at 9-19, advert on +Z.
#   RoofSign                hut roof centre; legs at z +-2.2, panel 14 (Z) x 10 at 4-14, DINER in neon both sides.
#   LetterA / LetterB       painted letter, its back on the plane z = 0, standing out toward -Z (0.08 proud).
#   StreetLamp              base on the sidewalk, arm and head toward +X. SignTower, RadioMast, CityA/B/C: base centre.
#
# Run (headless):
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup \
#       --python tools/blender/build_map_kit_rooftops.py -- [--no-render] [--samples N] [--shots a,b]
# Writes art-source/maps/Rooftops/Kit_Rooftops.blend, vault/02 Art/References/maps/rooftops/kit-contact.jpg and the
# assembled previews rooftops-preview-*.jpg (placements from tools/maps/rooftops_art.py, exactly what Art.luau
# places), and runs the mesh-level z-fighting check on every piece and on the assembled map with the visible
# greybox Parts (prints ROOFTOPS_ZFIGHT; must be 0).
# Export: blender --background --factory-startup art-source/maps/Rooftops/Kit_Rooftops.blend
#         --python tools/blender/export_lobby_kit.py -- --maps Rooftops Kit

import json, math, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "maps"))
import bpy, bmesh  # noqa: E402
import numpy as np  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402
import lobbykit as K  # noqa: E402
from gunkit import prism, box, merge, group, ring_pts, bevel  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
K.ART_DIR = os.path.join(K.ROOT, "art-source", "maps", "Rooftops")
K.RENDER_DIR = os.path.join(K.ROOT, "vault", "02 Art", "References", "maps", "rooftops")


# ---------------------------------------------------------------- Roblox-space geometry

def rb(p):
	return Vector((p[0], -p[2], p[1]))


FACE_N = {"+x": (0, 1), "-x": (0, -1), "+y": (2, 1), "-y": (2, -1), "+z": (1, -1), "-z": (1, 1)}  # -> blender axis, sign


def RB(x0, x1, y0, y1, z0, z1, drop="", ch=0.0):
	"""Roblox box; `drop` lists faces to leave out ("+y -x" ...): faces that always butt or are buried."""
	bm = box(min(x0, x1), max(x0, x1), -max(z0, z1), -min(z0, z1), min(y0, y1), max(y0, y1))
	if ch > 0:
		bevel(bm, ch, segs=1, angle=30)
	if drop:
		bm.normal_update()
		kill = []
		for key in drop.split():
			ax, sg = FACE_N[key]
			for f in bm.faces:
				if f.normal[ax] * sg > 0.99:
					kill.append(f)
		bmesh.ops.delete(bm, geom=list(set(kill)), context="FACES")
	return bm


def frame_to(a, b, up=(0, 1, 0)):
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
	m, L_ = frame_to(a, b, up)
	return K.place(box(0, L_, -w / 2, w / 2, -h / 2, h / 2), m)


def rod(a, b, r, segs=6):
	m, L_ = frame_to(a, b)
	return K.place(prism(ring_pts(0, 0, r, segs, math.pi / segs), "X", 0, L_), m)


def vcyl(x, z, r, y0, y1, segs=12, caps=True):
	bm = K.cyl(x, -z, r, y0, y1, segs=segs)
	if not caps:
		bm.normal_update()
		bmesh.ops.delete(bm, geom=[f for f in bm.faces if abs(f.normal.z) > 0.99], context="FACES")
	return bm


def cone(x, z, r, y0, y1, segs=16):
	bm = bmesh.new()
	ring = [bm.verts.new((x + r * math.cos(2 * math.pi * i / segs), -z + r * math.sin(2 * math.pi * i / segs), y0)) for i in range(segs)]
	tip = bm.verts.new((x, -z, y1))
	for i in range(segs):
		bm.faces.new((ring[i], ring[(i + 1) % segs], tip))
	bm.faces.new(ring[::-1])
	bm.normal_update()
	return bm


class Acc:
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
	ngons = [f for f in bm.faces if len(f.verts) > 4]
	if ngons:
		bmesh.ops.triangulate(bm, faces=ngons, quad_method="BEAUTY", ngon_method="EAR_CLIP")
	return bm


PIECES = {}


def piece(name, acc, mats, kit):
	col = K.collection("Map_" + name, kit)
	parts = acc.parts()
	for _, (bm, _) in parts.items():
		tidy(bm)
	K.build(name, parts, mats, col)
	PIECES[name] = col
	return col


def text_bm(body, size, origin, right, up, depth, font=K.FONT_HEAVY, align="CENTER"):
	"""Extruded text as a bmesh: origin/right/up are Roblox vectors; the text's front faces right x up."""
	cu = bpy.data.curves.new("_txt", "FONT")
	cu.body = body
	cu.size = size
	cu.align_x = align
	cu.align_y = "CENTER"
	cu.extrude = depth / 2
	cu.resolution_u = 2
	if os.path.exists(font):
		cu.font = bpy.data.fonts.load(font, check_existing=True)
	ob = bpy.data.objects.new("_txt", cu)
	bpy.context.scene.collection.objects.link(ob)
	dg = bpy.context.evaluated_depsgraph_get()
	me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
	bpy.data.objects.remove(ob)
	bpy.data.curves.remove(cu)
	bm = bmesh.new()
	bm.from_mesh(me)
	bpy.data.meshes.remove(me)
	# text local: x right, y up, z out of the face (z in -depth/2..depth/2): shift so its back is at z = 0
	R, U = Vector(right).normalized(), Vector(up).normalized()
	N = R.cross(U)  # Roblox: right x up = toward the viewer
	O = Vector(origin)
	for v in bm.verts:
		lx, ly, lz = v.co
		p = O + R * lx + U * ly + N * (lz + depth / 2)
		v.co = rb(p)
	bm.normal_update()
	return bm


# ---------------------------------------------------------------- materials

def make_mats():
	mats = K.begin()
	f = K._flat
	add = {
		"Brick": f("Brick", 0x8E4E3C, 0.9, rbx="Brick"),
		"Stone": f("Stone", 0xC9C1B0, 0.85, rbx="Limestone"),
		"WindowGlass": f("WindowGlass", 0x1D2633, 0.12, metallic=0.4, rbx="Glass"),
		"Concrete": f("Concrete", 0xA49F95, 0.9, rbx="Concrete"),
		"ConcreteDark": f("ConcreteDark", 0x5E5B57, 0.9, rbx="Concrete"),
		"SteelDark": f("SteelDark", 0x2A2D33, 0.5, metallic=0.6, rbx="Metal"),
		"SteelGalv": f("SteelGalv", 0x8E949B, 0.45, metallic=0.6, rbx="Metal"),
		"Grating": f("Grating", 0x6E737A, 0.5, metallic=0.5, rbx="DiamondPlate"),
		"SafetyYellow": f("SafetyYellow", 0xE2B93B, 0.5, rbx="SmoothPlastic"),
		"Planks": f("Planks", 0x8A6A4C, 0.85, rbx="WoodPlanks"),
		"TankWood": f("TankWood", 0x7A6450, 0.9, rbx="WoodPlanks"),
		"Casing": f("Casing", 0xB9BEC4, 0.5, metallic=0.3, rbx="Metal"),
		"Door": f("Door", 0x3C4650, 0.55, metallic=0.3, rbx="Metal"),
		"Interior": f("Interior", 0x23262C, 0.9, rbx="SmoothPlastic"),
		"SkyGlass": K._glass("SkyGlass", 0x8FB3C4),
		"Paint": f("Paint", 0xE8E4DA, 0.8, rbx="SmoothPlastic"),
		"AdvertBlue": f("AdvertBlue", 0x2E5FA8, 0.6, rbx="SmoothPlastic"),
		"AdvertCream": f("AdvertCream", 0xF1E6C8, 0.6, rbx="SmoothPlastic"),
		"AdvertMagenta": f("AdvertMagenta", 0xB8336F, 0.6, rbx="SmoothPlastic"),
		"CityConcrete": f("CityConcrete", 0x5A6170, 0.85, rbx="Concrete"),
		"CityStone": f("CityStone", 0x8A7E70, 0.85, rbx="Concrete"),
		"CityGlass": f("CityGlass", 0x243041, 0.15, metallic=0.4, rbx="Glass"),
		"Glow_Window": K._emissive("Glow_Window", 0xE8B072, 2.0),
		"Glow_Lamp": K._emissive("Glow_Lamp", 0xFFE2A8, 3.0),
		"Glow_Sign": K._emissive("Glow_Sign", 0xFF4FA3, 3.0),
		"Glow_Red": K._emissive("Glow_Red", 0xFF3B30, 3.0),
		"Glow_Flood": K._emissive("Glow_Flood", 0xFFF1D6, 3.0),
	}
	mats.update(add)
	return mats


# ---------------------------------------------------------------- facades

STOREY = 12.0
STOREYS = 6
LIT = {"Facade8A": (2, 5), "Facade8B": (1, 3, 6), "Facade8C": (4,), "Facade4": (3,)}


def p_facade(name, w, mats, kit):
	acc = Acc()
	hw = w / 2
	ww = 1.8 if w == 8 else 0.8  # window half width
	bottom = -STOREY * STOREYS
	top = -2.0  # wall and pilasters stop under the frieze band
	wall, trim, glass, lit = [], [], [], []
	# piers (full height) and spandrels between the windows; no caps at the module ends, top or bottom
	wall.append(RB(-1, 0, bottom, top, -hw, -ww, drop="-z +y -y"))
	wall.append(RB(-1, 0, bottom, top, ww, hw, drop="+z +y -y"))
	spans = [(bottom, bottom + 3)]
	for k in range(1, STOREYS):
		fl = -STOREY * k
		spans.append((fl - 3, fl + 3))
	spans.append((-3, top))
	for y0, y1 in spans:
		d = ("-y " if y0 == bottom else "") + ("+y" if y1 == top else "")
		wall.append(RB(-1, 0, y0, y1, -ww, ww, drop=d.strip()))
	# pilaster halves at the module edges (0.2 proud), frieze band and cornice (the corner block is the Quoin's)
	wall.append(RB(0, 0.2, bottom, top, -hw, -hw + 0.6, drop="-z -y -x"))
	wall.append(RB(0, 0.2, bottom, top, hw - 0.6, hw, drop="+z -y -x"))
	trim.append(RB(0, 0.3, top, -1.2, -hw, hw, drop="-x"))
	trim.append(RB(0, 0.4, -1.2, -0.05, -hw, hw, drop="-x"))
	for k in range(1, STOREYS + 1):
		fl = -STOREY * k
		s, hd = fl + 3, fl + 9
		trim.append(RB(-0.5, 0.25, s - 0.3, s + 0.1, -ww - 0.3, ww + 0.3))  # sill, 0.1 above the opening
		trim.append(RB(-0.3, 0.15, hd - 0.15, hd + 0.6, -ww - 0.3, ww + 0.3))  # lintel, 0.15 into the opening
		pane = RB(-0.6, -0.5, s, hd, -ww, ww)
		(lit if k in LIT[name] else glass).append(pane)
		if w == 8:
			trim.append(RB(-0.45, -0.32, s, hd, -0.075, 0.075))  # mullion (clear of the sill and lintel faces)
	acc.add("Wall", "Brick", *wall)
	acc.add("Trim", "Stone", *trim)
	if glass:
		acc.add("Glass", "WindowGlass", *glass)
	if lit:
		acc.add("Lit_Glow", "Glow_Window", *lit)
	return piece(name, acc, mats, kit)


def p_plinth(name, w, mats, kit):
	acc = Acc()
	hw = w / 2
	acc.add("Trim", "Stone", RB(0, 0.35, 0, 7.4, -hw, hw, drop="-x -y +y"), RB(0, 0.5, 7.4, 8, -hw, hw, drop="-x"))
	return piece(name, acc, mats, kit)


def p_quoin(mats, kit):
	acc = Acc()
	q = [RB(-0.75, 0.25, -80, -1.25, -0.75, 0.25, drop="-y")]
	# stone blocks alternating long and short along the corner, 0.1 prouder than the column
	for i in range(18):
		y = -78 + i * 4.3
		if y + 1.9 > -2.2:
			break
		lx = 1.6 if i % 2 == 0 else 1.0
		q.append(RB(0.25, 0.32, y, y + 1.9, -lx, 0.25))
		q.append(RB(-lx, 0.25, y, y + 1.9, 0.25, 0.32))
	acc.add("Trim", "Stone", *q, RB(0, 0.4, -2.0, -0.05, 0, 0.4))
	return piece("Quoin", acc, mats, kit)


def p_flue(mats, kit):
	acc = Acc()
	# depth along X (-3 back against the building .. +3), width along Z (+-4), top at 0, street at -82
	acc.add("Wall", "Brick", RB(-3, 3, -82, -0.6, -4, 4, drop="-x -y +y"))
	tr = [RB(-3, 3.25, -0.6, 0, -4.25, 4.25, drop="-x")]  # cap (flush at the back)
	for y in (-30, -54):
		tr.append(RB(-3, 3.12, y, y + 0.8, -4.12, 4.12, drop="-x"))  # string courses
	acc.add("Trim", "Stone", *tr)
	lv = [RB(3, 3.15, -5.2, -1.2, -2.6, 2.6)]  # louvre frame
	for i in range(6):
		y = -4.9 + i * 0.6
		lv.append(RB(3.15, 3.3, y, y + 0.3, -2.4, 2.4))
	acc.add("Vent", "SteelDark", *lv)
	return piece("Flue", acc, mats, kit)


# ---------------------------------------------------------------- bridges and stairs

def rails_sloped(z0, z1, y0, y1, x, post_every=4.0, first_post=True):
	"""Handrail + mid rail + posts on one side, from (z0, y0) to (z1, y1) along Z at x."""
	out = []
	for h in (1.65, 3.35):
		out.append(rod((x, y0 + h, z0), (x, y1 + h, z1), 0.12))
	n = max(1, int(round(abs(z1 - z0) / post_every)))
	for i in range(0 if first_post else 1, n + 1):
		t = i / n
		z = z0 + (z1 - z0) * t
		y = y0 + (y1 - y0) * t
		out.append(rod((x, y, z), (x, y + 3.5, z), 0.09))
	return out


def p_stair(mats, kit):
	acc = Acc()
	n = 16
	run, rise = 16.0 / n, 8.0 / n
	st, tr, no = [], [], []
	for sx in (-1, 1):
		st.append(beam((sx * 3.75, -0.5, -8.3), (sx * 3.75, 7.5, 7.9), 0.3, 0.9))
	for i in range(n):
		z0 = -8 + i * run
		y = (i + 1) * rise
		tr.append(RB(-3.55, 3.55, y - 0.16, y, z0, z0 + run))
		no.append(RB(-3.45, 3.45, y - 0.2, y + 0.03, z0 + run - 0.22, z0 + run + (0.06 if i < n - 1 else -0.08)))
	acc.add("Stringers", "SteelDark", *st)
	acc.add("Treads", "Grating", *tr)
	acc.add("Nosing", "SafetyYellow", *no)
	acc.add("Rails", "SafetyYellow", *rails_sloped(-8, 8, 0, 8, -3.85), *rails_sloped(-8, 8, 0, 8, 3.85))
	return piece("Stair16", acc, mats, kit)


def p_gangway(mats, kit):
	acc = Acc()
	# a sloped steel gangway: grating deck on two channels, cleats, handrails
	dk, ch, cl = [], [], []
	m, L_ = frame_to((0, 0, -8), (0, 8, 8))
	dk.append(K.place(box(0, L_, -3.7, 3.7, -0.2, 0), m))
	for sx in (-1, 1):
		ch.append(beam((sx * 3.7, -0.45, -7.8), (sx * 3.7, 7.45, 7.8), 0.3, 0.9))
	for i in range(1, 12):
		t = i / 12
		z, y = -8 + 16 * t, 8 * t
		cl.append(beam((-3.6, y + 0.03, z), (3.6, y + 0.03, z), 0.15, 0.1))
	acc.add("Deck", "Grating", *dk)
	acc.add("Frame", "SteelDark", *ch, *cl)
	acc.add("Rails", "SafetyYellow", *rails_sloped(-8, 8, 0, 8, -3.85), *rails_sloped(-8, 8, 0, 8, 3.85))
	return piece("Gangway16", acc, mats, kit)


def p_plank_ramp(mats, kit):
	acc = Acc()
	pl, bm_, cl = [], [], []
	m, L_ = frame_to((0, 0, -8), (0, 8, 8))
	# boards across the ramp, small gaps between them (never touching faces)
	nb = 30
	step = L_ / nb
	for i in range(nb):
		pl.append(K.place(box(i * step + 0.03, (i + 1) * step - 0.03, -3.9, 3.9, -0.25, 0), m))
	for sx in (-1, 1):
		bm_.append(beam((sx * 2.6, -0.95, -8), (sx * 2.6, 7.05, 8), 0.5, 0.7))
	for i in range(1, 9):
		t = i / 9
		cl.append(beam((-3.4, 8 * t + 0.06, -8 + 16 * t), (3.4, 8 * t + 0.06, -8 + 16 * t), 0.2, 0.12))
	acc.add("Planks", "Planks", *pl, *cl)
	acc.add("Beams", "SteelDark", *bm_)
	return piece("PlankRamp16", acc, mats, kit)


def p_catwalk8(mats, kit):
	acc = Acc()
	acc.add("Deck", "Grating", RB(-3.7, 3.7, -0.2, 0, -4, 4))
	acc.add("Frame", "SteelDark", RB(-4, -3.7, -0.9, 0, -4, 4), RB(3.7, 4, -0.9, 0, -4, 4), RB(-3.7, 3.7, -0.9, -0.2, -0.15, 0.15))
	acc.add("Rails", "SafetyYellow", *rails_sloped(-4, 4, 0, 0, -3.85, first_post=False), *rails_sloped(-4, 4, 0, 0, 3.85, first_post=False))
	return piece("Catwalk8", acc, mats, kit)


# ---------------------------------------------------------------- roof furniture

def louvre(face, a0, a1, y0, y1, plane, n=6, out=1):
	"""A louvre panel on an X face (face="x", varies Z a0..a1) or a Z face (face="z", varies X); plane = the face
	coordinate, out = +1/-1 the outward direction. Frame 0.12 proud, slats 0.24 proud, gaps between slats."""
	o = []
	fr0, fr1 = sorted((plane, plane + out * 0.12))
	sl0, sl1 = sorted((plane + out * 0.12, plane + out * 0.24))
	h = (y1 - y0) / n
	if face == "x":
		o.append(RB(fr0, fr1, y0, y1, a0, a1))
		for i in range(n):
			o.append(RB(sl0, sl1, y0 + i * h + 0.08, y0 + (i + 1) * h - 0.08, a0 + 0.15, a1 - 0.15))
	else:
		o.append(RB(a0, a1, y0, y1, fr0, fr1))
		for i in range(n):
			o.append(RB(a0 + 0.15, a1 - 0.15, y0 + i * h + 0.08, y0 + (i + 1) * h - 0.08, sl0, sl1))
	return o


def door_x(acc, plane, z, w=3.2, h=7.0, out=1, lamp=True):
	"""Steel door on an X face: leaf 0.12 proud, frame 0.2 proud, a canopy and a lamp over it."""
	a0, a1 = sorted((plane, plane + out * 0.12))
	f0, f1 = sorted((plane, plane + out * 0.2))
	acc.add("Door", "Door", RB(a0, a1, 0.2, h, z - w / 2, z + w / 2))
	acc.add("Frame", "SteelDark", RB(f0, f1, 0, h + 0.4, z - w / 2 - 0.35, z - w / 2), RB(f0, f1, 0, h + 0.4, z + w / 2, z + w / 2 + 0.35), RB(f0, f1, h, h + 0.4, z - w / 2, z + w / 2))
	c0, c1 = sorted((plane, plane + out * 1.2))
	acc.add("Frame", "SteelDark", RB(c0, c1, h + 0.9, h + 1.1, z - w / 2 - 0.6, z + w / 2 + 0.6))
	if lamp:
		l0, l1 = sorted((plane + out * 0.25, plane + out * 0.6))
		acc.add("Lamp_Glow", "Glow_Lamp", RB(l0, l1, h + 0.5, h + 0.8, z - 0.25, z + 0.25))


def door_z(acc, plane, x, w=3.2, h=7.0, out=1, lamp=True):
	a0, a1 = sorted((plane, plane + out * 0.12))
	f0, f1 = sorted((plane, plane + out * 0.2))
	acc.add("Door", "Door", RB(x - w / 2, x + w / 2, 0.2, h, a0, a1))
	acc.add("Frame", "SteelDark", RB(x - w / 2 - 0.35, x - w / 2, 0, h + 0.4, f0, f1), RB(x + w / 2, x + w / 2 + 0.35, 0, h + 0.4, f0, f1), RB(x - w / 2, x + w / 2, h, h + 0.4, f0, f1))
	c0, c1 = sorted((plane, plane + out * 1.2))
	acc.add("Frame", "SteelDark", RB(x - w / 2 - 0.6, x + w / 2 + 0.6, h + 0.9, h + 1.1, c0, c1))
	if lamp:
		l0, l1 = sorted((plane + out * 0.25, plane + out * 0.6))
		acc.add("Lamp_Glow", "Glow_Lamp", RB(x - 0.25, x + 0.25, h + 0.5, h + 0.8, l0, l1))


def brick_box(acc, hx, hz, H, roof_extra=True):
	"""Brick walls to H-0.4, a stone coping slab on top (0.15 overhang), a stone plinth band."""
	acc.add("Wall", "Brick", RB(-hx, hx, 0, H - 0.4, -hz, hz, drop="-y +y"))
	acc.add("Trim", "Stone", RB(-hx - 0.15, hx + 0.15, H - 0.4, H, -hz - 0.15, hz + 0.15), RB(-hx - 0.08, hx + 0.08, 0, 0.6, -hz - 0.08, hz + 0.08, drop="-y"))


def roof_vents(acc, pts, y):
	v = []
	for x, z in pts:
		v.append(vcyl(x, z, 0.35, y, y + 1.6, segs=8))
		v.append(vcyl(x, z, 0.55, y + 1.6, y + 1.85, segs=8))
	acc.add("Vents", "SteelGalv", *v)


def p_ac(mats, kit):
	acc = Acc()
	acc.add("Base", "SteelDark", RB(-4, 4, 0, 0.6, -2, 2, drop="-y"))
	acc.add("Casing", "Casing", RB(-3.9, 3.9, 0.6, 6.6, -1.9, 1.9, ch=0.06))
	lv = []
	for sz in (-1, 1):
		for x0 in (-3.5, 0.2):
			lv += louvre("z", x0, x0 + 3.3, 1.2, 5.8, sz * 1.9, n=7, out=sz)
	acc.add("Louvres", "SteelGalv", *lv)
	fans, gr = [], []
	for x in (-2, 2):
		fans.append(vcyl(x, 0, 1.15, 6.6, 7.4, segs=16))
		gr.append(vcyl(x, 0, 1.0, 7.4, 7.5, segs=16))
	acc.add("Casing", "Casing", *fans)
	acc.add("Grille", "SteelDark", *gr)
	return piece("ACUnit", acc, mats, kit)


def p_condenser(mats, kit):
	acc = Acc()
	acc.add("Base", "SteelDark", RB(-2, 2, 0, 0.3, -2, 2, drop="-y"))
	acc.add("Casing", "Casing", RB(-1.9, 1.9, 0.3, 2.7, -1.9, 1.9, ch=0.05))
	lv = louvre("x", -1.6, 1.6, 0.6, 2.4, 1.9, n=5, out=1) + louvre("x", -1.6, 1.6, 0.6, 2.4, -1.9, n=5, out=-1)
	acc.add("Louvres", "SteelGalv", *lv)
	acc.add("Grille", "SteelDark", vcyl(0, 0, 1.5, 2.7, 3.0, segs=16))
	return piece("Condenser", acc, mats, kit)


def p_skylight(mats, kit):
	acc = Acc()
	acc.add("Curb", "SteelGalv", RB(-4, 4, 0, 1, -2, 2, drop="-y"))
	# glass ridge along X: a triangular prism on the curb (1 .. 3), bars over it
	pts = [(-1.9, 1.0), (1.9, 1.0), (0.0, 2.95)]  # (z, y) Roblox
	bm = prism([(z_, y_) for z_, y_ in pts], "X", -3.9, 3.9)
	for v in bm.verts:
		x_, z_, y_ = v.co.x, v.co.y, v.co.z
		v.co = Vector((x_, -z_, y_))
	bm.normal_update()
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	acc.add("Glass", "SkyGlass", bm)
	bars = [rod((-4, 3.0, 0), (4, 3.0, 0), 0.12)]
	for x in (-3.8, -1.3, 1.3, 3.8):
		for sz in (-1, 1):
			bars.append(rod((x, 1.05, sz * 1.95), (x, 3.0, 0), 0.07, segs=4))
	acc.add("Bars", "SteelDark", *bars)
	return piece("Skylight", acc, mats, kit)


def p_penthouse(mats, kit):
	acc = Acc()
	hx, hz, H = 20.0, 4.0, 11.0
	brick_box(acc, hx, hz, H)
	door_z(acc, hz, -6, out=1)
	door_z(acc, hz, 6, out=1)
	lv = louvre("x", -2.5, 2.5, 3, 8, hx, n=8, out=1) + louvre("x", -2.5, 2.5, 3, 8, -hx, n=8, out=-1)
	lv += louvre("z", -14, -10, 6, 9, hz, n=5, out=1) + louvre("z", 10, 14, 6, 9, hz, n=5, out=1)
	acc.add("Louvres", "SteelGalv", *lv)
	roof_vents(acc, [(-12, 1), (-9, -1.5), (13, 0.5)], H)
	ant = [rod((16, H, 0), (16, H + 9, 0), 0.12), rod((14.5, H + 6, 0), (17.5, H + 6, 0), 0.06), rod((15, H + 8, 0), (17, H + 8, 0), 0.06)]
	acc.add("Antenna", "SteelDark", *ant)
	acc.add("Light_Glow", "Glow_Red", RB(15.85, 16.15, H + 9, H + 9.3, -0.15, 0.15))
	return piece("Penthouse", acc, mats, kit)


def p_letter(name, ch, mats, kit):
	acc = Acc()
	acc.add("Paint", "Paint", text_bm(ch, 8.0, (0, 5.6, -0.0), (-1, 0, 0), (0, 1, 0), 0.08))
	# a painted band under it (two stripes), 0.06 proud
	acc.add("Paint", "Paint", RB(-8, -2.5, 1.2, 1.6, -0.06, 0), RB(2.5, 8, 1.2, 1.6, -0.06, 0))
	return piece(name, acc, mats, kit)


def p_stairhut(mats, kit):
	acc = Acc()
	brick_box(acc, 3, 3, 9)
	door_x(acc, 3, 0, out=1)
	acc.add("Louvres", "SteelGalv", *louvre("x", -1.6, 1.6, 4, 7, -3, n=5, out=-1))
	roof_vents(acc, [(-1.2, 1.2)], 9)
	return piece("StairHut", acc, mats, kit)


def p_lifthouse(mats, kit):
	acc = Acc()
	brick_box(acc, 4, 4, 10)
	door_x(acc, 4, 0, out=1)
	lv = louvre("z", -2.5, 2.5, 5, 8.5, 4, n=6, out=1) + louvre("z", -2.5, 2.5, 5, 8.5, -4, n=6, out=-1)
	acc.add("Louvres", "SteelGalv", *lv)
	roof_vents(acc, [(-2, -2), (2, 2)], 10)
	return piece("LiftHouse", acc, mats, kit)


def p_lifttower(mats, kit):
	acc = Acc()
	brick_box(acc, 5, 4, 16)
	door_x(acc, 5, 0, out=1)
	door_x(acc, -5, 0, out=-1)
	lv = louvre("z", -3, 3, 10, 14, 4, n=6, out=1) + louvre("z", -3, 3, 10, 14, -4, n=6, out=-1)
	acc.add("Louvres", "SteelGalv", *lv)
	return piece("LiftTower", acc, mats, kit)


def p_tankhouse(mats, kit):
	acc = Acc()
	brick_box(acc, 5, 5, 8)
	door_x(acc, 5, 0, out=1)
	acc.add("Louvres", "SteelGalv", *louvre("z", -3, 3, 3, 6.5, 5, n=6, out=1))
	return piece("TankHouse", acc, mats, kit)


def p_coolingtower(mats, kit):
	acc = Acc()
	acc.add("Base", "SteelDark", RB(-5, 5, 0, 0.8, -5, 5, drop="-y"))
	acc.add("Casing", "Casing", RB(-4.8, 4.8, 0.8, 6.8, -4.8, 4.8, ch=0.08))
	lv = []
	for s in (-1, 1):
		lv += louvre("x", -4.2, 4.2, 1.4, 6.2, s * 4.8, n=9, out=s)
		lv += louvre("z", -4.2, 4.2, 1.4, 6.2, s * 4.8, n=9, out=s)
	acc.add("Louvres", "SteelGalv", *lv)
	fans, gr = [], []
	for x in (-2.3, 2.3):
		fans.append(vcyl(x, 0, 2.1, 6.8, 7.8, segs=20))
		gr.append(vcyl(x, 0, 1.9, 7.8, 8.0, segs=20))
	acc.add("Casing", "Casing", *fans)
	acc.add("Grille", "SteelDark", *gr)
	return piece("CoolingTower", acc, mats, kit)


def p_watertank(mats, kit):
	acc = Acc()
	st = []
	for sx in (-1, 1):
		for sz in (-1, 1):
			st.append(RB(sx * 3.5 - 0.4, sx * 3.5 + 0.4, 0, 4, sz * 3.5 - 0.4, sz * 3.5 + 0.4))
	for s in (-1, 1):
		st.append(rod((-3.1, 0.6, s * 3.5), (3.1, 3.4, s * 3.5), 0.1, segs=4))
		st.append(rod((s * 3.5, 0.6, -3.1), (s * 3.5, 3.4, 3.1), 0.1, segs=4))
	for x in (-3.5, 0, 3.5):
		st.append(RB(x - 0.3, x + 0.3, 4, 4.4, -4.3, 4.3))  # dunnage beams across the legs' tops
	acc.add("Stand", "SteelDark", *st)
	acc.add("Drum", "TankWood", vcyl(0, 0, 4.4, 4.4, 14, segs=20))
	hoops = [vcyl(0, 0, 4.52, y, y + 0.22, segs=20, caps=False) for y in (5.2, 7.0, 8.8, 10.6, 12.4, 13.5)]
	acc.add("Hoops", "SteelDark", *hoops)
	acc.add("Cap", "TankWood", cone(0, 0, 4.7, 14, 16.3, segs=20))
	acc.add("Hoops", "SteelDark", vcyl(0, 0, 0.2, 16.1, 16.9, segs=6))
	lad = [rod((4.75, 0, -0.45), (4.75, 15, -0.45), 0.1, segs=4), rod((4.75, 0, 0.45), (4.75, 15, 0.45), 0.1, segs=4)]
	for i in range(1, 15):
		lad.append(rod((4.75, i, -0.45), (4.75, i, 0.45), 0.05, segs=4))
	acc.add("Ladder", "SteelGalv", *lad)
	return piece("WaterTank", acc, mats, kit)


def p_billboard(mats, kit):
	acc = Acc()
	fr = []
	for x in (-5, 5):
		fr.append(RB(x - 0.4, x + 0.4, 0, 9.5, -0.4, 0.4))
	fr.append(RB(-9, 9, 9, 19, -0.5, 0.45))  # panel body
	for i in range(4):  # back bracing (diagonals on the -Z face)
		x0 = -9 + i * 4.5
		fr.append(rod((x0 + 0.2, 9.4, -0.6), (x0 + 4.3, 18.6, -0.6), 0.1, segs=4))
	acc.add("Frame", "SteelDark", *fr)
	# advert on +Z: a cream field, a blue band, a magenta disc and the word NOODLES (each layer 0.06 prouder)
	acc.add("Advert", "AdvertCream", RB(-8.7, 8.7, 9.3, 18.7, 0.45, 0.53, drop="-z"))
	acc.add("AdvertBlue", "AdvertBlue", RB(-8.7, 8.7, 9.3, 12.2, 0.53, 0.6, drop="-z"))
	disc = bmesh.new()
	ring = [disc.verts.new(rb((5.3 + 2.4 * math.cos(2 * math.pi * i / 24), 15.6 + 2.4 * math.sin(2 * math.pi * i / 24), 0.6))) for i in range(24)]
	ring2 = [disc.verts.new(rb((5.3 + 2.4 * math.cos(2 * math.pi * i / 24), 15.6 + 2.4 * math.sin(2 * math.pi * i / 24), 0.53))) for i in range(24)]
	disc.faces.new(ring[::-1])
	for i in range(24):
		j = (i + 1) % 24
		disc.faces.new((ring[i], ring[j], ring2[j], ring2[i]))
	bmesh.ops.recalc_face_normals(disc, faces=disc.faces[:])
	acc.add("AdvertMagenta", "AdvertMagenta", disc)
	acc.add("AdvertText", "AdvertBlue", text_bm("NOODLES", 2.1, (-3.0, 15.4, 0.53), (1, 0, 0), (0, 1, 0), 0.08))
	acc.add("AdvertText2", "Paint", text_bm("OPEN LATE", 1.4, (0, 10.75, 0.6), (1, 0, 0), (0, 1, 0), 0.06))
	# floodlights on arms over the face
	arms, heads = [], []
	for x in (-6, 0, 6):
		arms.append(rod((x, 19, 0.3), (x, 20.2, 2.4), 0.09, segs=4))
		heads.append(RB(x - 0.45, x + 0.45, 19.9, 20.4, 2.3, 2.9))
	acc.add("Frame", "SteelDark", *arms)
	acc.add("Flood_Glow", "Glow_Flood", *heads)
	return piece("Billboard", acc, mats, kit)


def p_roofsign(mats, kit):
	acc = Acc()
	fr = []
	for z in (-2.2, 2.2):
		fr.append(RB(-0.4, 0.4, 0, 4.2, z - 0.4, z + 0.4))
	fr.append(RB(-0.6, 0.6, 4, 14, -7, 7))
	acc.add("Frame", "SteelDark", *fr)
	gl = []
	for sx in (-1, 1):
		x = sx * 0.6
		# reading right on each face: on +X the text runs toward -Z, on -X toward +Z
		gl.append(text_bm("DINER", 3.6, (x, 9.4, 0), (0, 0, -sx), (0, 1, 0), 0.1))
		# a neon outline tube 0.4 in from the panel edge
		for a, b in (((x, 4.5, -6.5), (x, 4.5, 6.5)), ((x, 13.5, -6.5), (x, 13.5, 6.5)), ((x, 4.5, -6.5), (x, 13.5, -6.5)), ((x, 4.5, 6.5), (x, 13.5, 6.5))):
			a2 = (a[0] + sx * 0.12, a[1], a[2])
			b2 = (b[0] + sx * 0.12, b[1], b[2])
			gl.append(rod(a2, b2, 0.1, segs=6))
	acc.add("Neon_Glow", "Glow_Sign", *gl)
	return piece("RoofSign", acc, mats, kit)


# ---------------------------------------------------------------- street and skyline

def p_streetlamp(mats, kit):
	acc = Acc()
	acc.add("Pole", "SteelDark", vcyl(0, 0, 0.22, 1.2, 10, segs=8), vcyl(0, 0, 0.4, 0, 1.2, segs=8), beam((0, 9.7, 0), (3.2, 10.1, 0), 0.2, 0.2))
	acc.add("Head", "SteelDark", RB(2.6, 4.2, 9.85, 10.35, -0.45, 0.45))
	acc.add("Head_Glow", "Glow_Lamp", RB(2.75, 4.05, 9.75, 9.85, -0.32, 0.32))
	return piece("StreetLamp", acc, mats, kit)


def city_block(name, w, d, H, mats, kit, body="CityConcrete", seed=1):
	acc = Acc()
	import random

	r = random.Random(seed)
	hw, hd = w / 2, d / 2
	acc.add("Body", body, RB(-hw, hw, 0, H, -hd, hd, drop="-y"))
	bands, lit = [], []
	floors = int((H - 6) // 4)
	for k in range(1, floors):
		y = 2 + k * 4
		# dark window bands on all four faces, 0.06 proud
		bands.append(RB(hw, hw + 0.06, y, y + 2, -hd + 0.8, hd - 0.8))
		bands.append(RB(-hw - 0.06, -hw, y, y + 2, -hd + 0.8, hd - 0.8))
		bands.append(RB(-hw + 0.8, hw - 0.8, y, y + 2, hd, hd + 0.06))
		bands.append(RB(-hw + 0.8, hw - 0.8, y, y + 2, -hd - 0.06, -hd))
		# lit windows on about one bay in four, 0.12 proud (in front of the band)
		for face in range(4):
			span = (w if face >= 2 else d) - 1.6
			nwin = int(span // 3)
			for i in range(nwin):
				if r.random() > 0.24:
					continue
				a = -span / 2 + i * 3 + 0.4
				if face == 0:
					lit.append(RB(hw + 0.06, hw + 0.12, y + 0.2, y + 1.8, a, a + 2.2))
				elif face == 1:
					lit.append(RB(-hw - 0.12, -hw - 0.06, y + 0.2, y + 1.8, a, a + 2.2))
				elif face == 2:
					lit.append(RB(a, a + 2.2, y + 0.2, y + 1.8, hd + 0.06, hd + 0.12))
				else:
					lit.append(RB(a, a + 2.2, y + 0.2, y + 1.8, -hd - 0.12, -hd - 0.06))
	acc.add("Windows", "CityGlass", *bands)
	acc.add("Lit_Glow", "Glow_Window", *lit)
	acc.add("Roof", "ConcreteDark", RB(-hw + 2, hw - 2, H, H + 3, -hd + 2, hd - 2))
	return piece(name, acc, mats, kit)


def p_signtower(mats, kit):
	acc = Acc()
	H = 240.0
	acc.add("Body", "CityGlass", RB(-20, 20, 0, H - 8, -20, 20, drop="-y +y"))
	# vertical stone fins every 5 on all faces (0.5 proud) give the curtain wall its rhythm
	fins, lit = [], []
	import random

	r = random.Random(7)
	for i in range(1, 8):
		a = -20 + i * 5
		fins.append(RB(20, 20.5, 6, H - 8, a - 0.35, a + 0.35))
		fins.append(RB(-20.5, -20, 6, H - 8, a - 0.35, a + 0.35))
		fins.append(RB(a - 0.35, a + 0.35, 6, H - 8, 20, 20.5))
		fins.append(RB(a - 0.35, a + 0.35, 6, H - 8, -20.5, -20))
	for k in range(2, int(H // 4) - 2):
		y = k * 4
		for face in range(4):
			for i in range(8):
				if r.random() > 0.18:
					continue
				a0, a1 = -20 + i * 5 + 0.5, -20 + (i + 1) * 5 - 0.5
				if face == 0:
					lit.append(RB(20, 20.1, y + 0.4, y + 3.2, a0, a1))
				elif face == 1:
					lit.append(RB(-20.1, -20, y + 0.4, y + 3.2, a0, a1))
				elif face == 2:
					lit.append(RB(a0, a1, y + 0.4, y + 3.2, 20, 20.1))
				else:
					lit.append(RB(a0, a1, y + 0.4, y + 3.2, -20.1, -20))
	acc.add("Fins", "CityStone", *fins, RB(-21, 21, 0, 6, -21, 21, drop="-y"), RB(-21, 21, H - 8, H, -21, 21))
	acc.add("Lit_Glow", "Glow_Window", *lit)
	# crown and mast
	acc.add("Crown", "ConcreteDark", RB(-14, 14, H, H + 10, -14, 14), RB(-6, 6, H + 10, H + 16, -6, 6))
	acc.add("Mast", "SteelGalv", vcyl(0, 0, 0.6, H + 16, H + 48, segs=8))
	acc.add("Beacon_Glow", "Glow_Red", RB(-0.8, 0.8, H + 48, H + 49.6, -0.8, 0.8), RB(-0.6, 0.6, H + 30, H + 31, -0.6, 0.6))
	# the vertical HOTEL sign on the +X face: a dark frame, neon letters stacked top to bottom, a neon border
	acc.add("SignFrame", "SteelDark", RB(20.5, 22.5, 120, 210, -6, 6))
	gl = []
	for i, ch in enumerate("HOTEL"):
		gl.append(text_bm(ch, 13.0, (22.5, 201 - i * 17, 0), (0, 0, -1), (0, 1, 0), 0.4))
	for a, b in (((22.7, 121, -5.5), (22.7, 209, -5.5)), ((22.7, 121, 5.5), (22.7, 209, 5.5)), ((22.7, 121, -5.5), (22.7, 121, 5.5)), ((22.7, 209, -5.5), (22.7, 209, 5.5))):
		gl.append(rod(a, b, 0.25, segs=6))
	acc.add("Sign_Glow", "Glow_Sign", *gl)
	return piece("SignTower", acc, mats, kit)


def p_radiomast(mats, kit):
	acc = Acc()
	H = 300.0
	legs, br = [], []
	base = [(14 * math.cos(a), 14 * math.sin(a)) for a in (0, 2.094, 4.189)]

	def at(i, y):
		t = y / H
		r = 1 - 0.85 * t
		return (base[i][0] * r, y, base[i][1] * r)

	for i in range(3):
		legs.append(rod(at(i, 0), at(i, H), 0.6, segs=6))
	for k in range(1, 12):
		y = k * 25
		for i in range(3):
			br.append(rod(at(i, y), at((i + 1) % 3, y), 0.25, segs=6))
	acc.add("Lattice", "SafetyYellow", *legs)
	acc.add("Braces", "SteelGalv", *br)
	acc.add("Light_Glow", "Glow_Red", *[RB(-1, 1, y, y + 1.5, -1, 1) for y in (75, 150, 225)], RB(-1.2, 1.2, H, H + 2, -1.2, 1.2))
	return piece("RadioMast", acc, mats, kit)


# ---------------------------------------------------------------- z-fighting check (meshes + greybox Parts)

def piece_tris(col):
	"""{object name: (n, 3, 3) triangles in Roblox piece-local coordinates}."""
	out = {}
	for ob in col.objects:
		if ob.type != "MESH":
			continue
		me = ob.data
		me.calc_loop_triangles()
		co = np.array([v.co for v in me.vertices], float)
		idx = np.array([t.vertices[:] for t in me.loop_triangles], int)
		if len(idx) == 0:
			continue
		tri = co[idx]  # blender (x, y, z) -> roblox (x, z, -y)
		out[ob.name] = np.stack([tri[..., 0], tri[..., 2], -tri[..., 1]], axis=-1)
	return out


def box_tris(x0, x1, y0, y1, z0, z1):
	c = np.array([[x0, y0, z0], [x1, y0, z0], [x1, y1, z0], [x0, y1, z0], [x0, y0, z1], [x1, y0, z1], [x1, y1, z1], [x0, y1, z1]])
	quads = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (3, 7, 6, 2), (0, 4, 7, 3), (1, 2, 6, 5)]
	t = []
	for a, b, c_, d in quads:
		t += [(a, b, c_), (a, c_, d)]
	return c[np.array(t)]


def place_tris(tri, x, y, z, yaw, scale=1.0):
	c, s = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
	X, Y, Z = tri[..., 0] * scale, tri[..., 1] * scale, tri[..., 2] * scale
	return np.stack([X * c + Z * s + x, Y + y, -X * s + Z * c + z], axis=-1)


def clip_area(P, Q):
	"""Area of the intersection of two 2D triangles (Sutherland-Hodgman)."""
	def area(p):
		return 0.5 * abs(sum(p[i][0] * p[(i + 1) % len(p)][1] - p[(i + 1) % len(p)][0] * p[i][1] for i in range(len(p))))

	def ccw(p):
		s = sum(p[i][0] * p[(i + 1) % 3][1] - p[(i + 1) % 3][0] * p[i][1] for i in range(3))
		return p if s > 0 else p[::-1]

	out = list(ccw(list(P)))
	Q = ccw(list(Q))
	for i in range(3):
		a, b = Q[i], Q[(i + 1) % 3]
		inp, out = out, []
		if not inp:
			return 0.0

		def inside(p):
			return (b[0] - a[0]) * (p[1] - a[1]) - (b[1] - a[1]) * (p[0] - a[0]) >= -1e-9

		for j in range(len(inp)):
			cur, prv = inp[j], inp[j - 1]
			ci, pi = inside(cur), inside(prv)
			if ci:
				if not pi:
					out.append(isect(prv, cur, a, b))
				out.append(cur)
			elif pi:
				out.append(isect(prv, cur, a, b))
	return area(out) if len(out) >= 3 else 0.0


def isect(p, q, a, b):
	x1, y1, x2, y2 = p[0], p[1], q[0], q[1]
	x3, y3, x4, y4 = a[0], a[1], b[0], b[1]
	den = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4)
	if abs(den) < 1e-12:
		return q
	t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / den
	return (x1 + t * (x2 - x1), y1 + t * (y2 - y1))


def zfight(items, tol=0.02, min_area=0.0025):
	"""items: [(owner, (n,3,3) roblox triangles)]. Pairs of triangles facing the same way in the same plane
	(normals within 0.9995, planes < tol apart) whose overlap is over min_area: z-fighting. Mirrors Audit.luau."""
	T = np.concatenate([t for _, t in items])
	own = np.concatenate([np.full(len(t), i) for i, (_, t) in enumerate(items)])
	n = np.cross(T[:, 1] - T[:, 0], T[:, 2] - T[:, 0])
	ln = np.linalg.norm(n, axis=1)
	ok = ln > 1e-6
	T, own, n, ln = T[ok], own[ok], n[ok], ln[ok]
	n = n / ln[:, None]
	d = np.einsum("ij,ij->i", n, T[:, 0])
	key = np.round(n * 200).astype(int)
	groups = {}
	for i, k in enumerate(map(tuple, key)):
		groups.setdefault(k, []).append(i)
	bad = []
	for k, idx in groups.items():
		if len(idx) < 2:
			continue
		idx = np.array(idx)
		nn = n[idx[0]]
		# plane basis
		u = np.cross(nn, [0, 1, 0] if abs(nn[1]) < 0.9 else [1, 0, 0])
		u /= np.linalg.norm(u)
		v = np.cross(nn, u)
		order = idx[np.argsort(d[idx])]
		dd = d[order]
		for a_i in range(len(order)):
			j = a_i + 1
			while j < len(order) and dd[j] - dd[a_i] < tol:
				ia, ib = order[a_i], order[j]
				j += 1
				if n[ia] @ n[ib] < 0.9995:
					continue
				A2 = [(p @ u, p @ v) for p in T[ia]]
				B2 = [(p @ u, p @ v) for p in T[ib]]
				if min(p[0] for p in A2) >= max(p[0] for p in B2) or min(p[0] for p in B2) >= max(p[0] for p in A2):
					continue
				if min(p[1] for p in A2) >= max(p[1] for p in B2) or min(p[1] for p in B2) >= max(p[1] for p in A2):
					continue
				ar = clip_area(A2, B2)
				if ar > min_area:
					bad.append((items[own[ia]][0], items[own[ib]][0], tuple(np.round(T[ia].mean(0), 2)), round(ar, 3)))
	return bad


def zfight_report(label, bad):
	pairs = {}
	for a, b, at, ar in bad:
		pairs.setdefault((a, b), []).append((at, ar))
	print("ROOFTOPS_ZFIGHT %s: %d triangle pairs, %d part pairs" % (label, len(bad), len(pairs)))
	for (a, b), v in list(pairs.items())[:25]:
		print("   %s / %s  x%d  e.g. at %s area %.3f" % (a, b, len(v), v[0][0], v[0][1]))
	return len(pairs)


def check_pieces():
	total = 0
	for name, col in PIECES.items():
		tris = piece_tris(col)
		items = list(tris.items())
		bad = zfight(items)
		if bad:
			total += zfight_report("piece " + name, bad)
	print("ROOFTOPS_ZFIGHT pieces total part pairs:", total)
	return total


def assembled_items():
	import rooftops_art as A
	import rooftops_layout as L

	art = A.Art().build()
	items = []
	cache = {name: piece_tris(col) for name, col in PIECES.items()}
	for i, (sec, pc, x, y, z, yaw, tint, glow, scale) in enumerate(art.place):
		if pc not in cache:
			continue
		for oname, tri in cache[pc].items():
			items.append(("%s#%d.%s" % (pc, i, oname.split("_", 1)[1]), place_tris(tri, x, y, z, yaw, scale)))
	vis = [s for s in L.SOLIDS if s.kind not in L.HIDDEN_BY_ART] + A.plain_parts()
	for s in vis:
		items.append(("Part:" + s.name, box_tris(s.x0, s.x1, s.y0, s.y1, s.z0, s.z1)))
	return items, art


# ---------------------------------------------------------------- previews

def sheet(pieces, mats, tris):
	sc = bpy.context.scene
	stage = K.collection("Sheet")
	w = sc.world or bpy.data.worlds.new("World")
	sc.world = w
	w.use_nodes = True
	bg = w.node_tree.nodes.get("Background")
	if bg:
		bg.inputs[0].default_value = (*K.lin(0x3A4256), 1)
		bg.inputs[1].default_value = 1.0
	cell = 30.0
	ncol = 6
	small = [(n, c) for n, c in pieces if n not in ("SignTower", "RadioMast", "CityA", "CityB", "CityC", "Flue", "Quoin", "Plinth8", "Plinth4")]
	nrow = (len(small) + ncol - 1) // ncol
	K.add_obj("SheetFloor", box(-cell * (nrow - 0.4), cell * 0.6, -cell * 0.6, cell * (ncol - 0.4), -0.2, 0), [mats["ConcreteDark"]], stage)["preview_only"] = True
	for idx, (name, col) in enumerate(small):
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
		label = "%s %d tris%s" % (name, tris[name], "" if s == 1 else " (x%.2f)" % s)
		K.text(label, 1.2, (px + 13.5, py, 0.05), stage, mats["SignText"], rot=(0, 0, 90), font=K.FONT_LABEL)
	sun = bpy.data.lights.new("SheetSun", "SUN")
	sun.energy = 3.0
	so = bpy.data.objects.new("SheetSun", sun)
	stage.objects.link(so)
	so.rotation_euler = (math.radians(45), math.radians(-25), math.radians(200))
	cx, cy = -(nrow - 1) * cell / 2, (ncol - 1) * cell / 2
	cam = K.camera((cx + 240, cy + 60, 230), (cx, cy, 4), lens=50, name="SheetCam", col=stage)
	cam.data.type = "ORTHO"
	cam.data.ortho_scale = cell * ncol * 1.05
	K.render_settings(samples=SAMPLES)
	K.bloom(strength=0.3, threshold=1.2)
	return stage


SAMPLES = int(ARGS[ARGS.index("--samples") + 1]) if "--samples" in ARGS else 24


def hexcol(h):
	return int(h[1:], 16)


def assemble(mats, art):
	import rooftops_art as A
	import rooftops_layout as L

	col = K.collection("Preview")
	tint_cache = {}

	def tinted(base, hexs):
		key = (base.name, hexs)
		if key not in tint_cache:
			m = base.copy()
			m.name = "%s_%s" % (base.name, hexs[1:])
			m["preview_only"] = True
			c = K.lin(hexcol(hexs))
			for nd in m.node_tree.nodes:
				if nd.type == "BSDF_PRINCIPLED":
					nd.inputs["Base Color"].default_value = (*c, 1)
					if "Emission Color" in nd.inputs and base.get("glow"):
						nd.inputs["Emission Color"].default_value = (*c, 1)
			tint_cache[key] = m
		return tint_cache[key]

	for sec, pc, x, y, z, yaw, tint, glow, scale in art.place:
		src = PIECES.get(pc)
		if src is None:
			continue
		m = Matrix.Translation(rb((x, y, z))) @ Matrix.Rotation(math.radians(yaw), 4, "Z") @ Matrix.Scale(scale, 4)
		for ob in src.objects:
			if ob.type != "MESH":
				continue
			o = bpy.data.objects.new(ob.name + "_p", ob.data)
			o.matrix_world = m
			mat = ob.material_slots[0].material if ob.material_slots else None
			if tint and ob.name.endswith("_Wall") and mat:
				o.material_slots[0].link = "OBJECT"
				o.material_slots[0].material = tinted(mat, tint)
			if glow and (ob.name.endswith("Sign_Glow") or ob.name.endswith("Neon_Glow")) and mat:
				o.material_slots[0].link = "OBJECT"
				o.material_slots[0].material = tinted(mat, glow)
			if ob.get("glow"):
				o.visible_shadow = False
			col.objects.link(o)
	looks = {
		"Roof": (0x4B4E56, 0.9), "RoofPit": (0x6E6A63, 0.95), "Coping": (0xC9C1B0, 0.85), "Ledge": (0xA49F95, 0.9),
		"Asphalt": (0x2C2E33, 0.9), "Sidewalk": (0x8C8A86, 0.9), "RoadLine": (0xD9D2B8, 0.6),
	}
	lm = {}
	for s in [s for s in L.SOLIDS if s.kind not in L.HIDDEN_BY_ART] + A.plain_parts():
		if s.look == "Brick":
			hexs = A.TONES.get(A.tone_of(s) or "pit")
			key = "Brick" + hexs
			if key not in lm:
				lm[key] = tinted(mats["Brick"], hexs)
		else:
			key = s.look
			if key not in lm:
				c, rgh = looks[key]
				m = K._flat("Look_" + key, c, rgh)
				m["preview_only"] = True
				lm[key] = m
		ob = K.add_obj("G_" + s.name, RB(s.x0, s.x1, s.y0, s.y1, s.z0, s.z1), [lm[key]], col, smooth_angle=0)
		ob["preview_only"] = True
	return col


def blue_hour_world():
	sc = bpy.context.scene
	w = bpy.data.worlds.new("BlueHour")
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
	cr.elements[0].color = (*K.lin(0x1A2238), 1)
	cr.elements[1].position = 1.0
	cr.elements[1].color = (*K.lin(0x0E1A3E), 1)
	for pos, c in ((0.49, 0x2A3550), (0.5, 0x9AA6C8), (0.52, 0x6F86C2), (0.6, 0x34509A), (0.8, 0x1B2C66)):
		e = cr.elements.new(pos)
		e.color = (*K.lin(c), 1)
	mr = nt.nodes.new("ShaderNodeMath")
	mr.operation = "MULTIPLY_ADD"
	nt.links.new(sep.outputs["Z"], mr.inputs[0])
	mr.inputs[1].default_value = 0.5
	mr.inputs[2].default_value = 0.5
	nt.links.new(mr.outputs[0], ramp.inputs[0])
	nt.links.new(ramp.outputs[0], bg.inputs[0])
	bg.inputs[1].default_value = 2.4
	nt.links.new(bg.outputs[0], out.inputs[0])
	# a soft, cool key from the west horizon (the sky after sunset) and a cool fill from above
	for name, energy, color, rot in (("SkyKey", 1.2, 0xB8C6F0, (math.radians(70), 0, math.radians(-90))), ("SkyFill", 0.6, 0x8FA0D8, (math.radians(10), math.radians(10), 0))):
		ld = bpy.data.lights.new(name, "SUN")
		ld.energy = energy
		ld.color = K.lin(color)
		ld.angle = math.radians(8)
		ob = bpy.data.objects.new(name, ld)
		K.collection("Stage").objects.link(ob)
		ob.rotation_euler = rot


def renders():
	for c in list(bpy.context.view_layer.layer_collection.children):
		if c.name in ("Sheet", "Kit"):
			c.exclude = True
	blue_hour_world()
	for x, y, z in ((0, 20, 0), (-30, 24, -12), (30, 24, 12)):
		ld = bpy.data.lights.new("SignLight", "POINT")
		ld.energy = 15000
		ld.color = K.lin(0xFFD9B0)
		ld.shadow_soft_size = 2
		ob = bpy.data.objects.new("SignLight", ld)
		K.collection("Stage").objects.link(ob)
		ob.location = rb((x, y, z))
	K.render_settings(samples=SAMPLES)
	K.bloom(strength=0.35, threshold=1.0)
	shots = {
		"overview": ((150, 120, -150), (0, -6, 0), 30),
		"from-b-spawn": ((-27, 5.4, 55), (2, 2, -20), 24),
		"pit": ((-12, -2.6, -2), (16, 0, 26), 22),
	}
	only = set(ARGS[ARGS.index("--shots") + 1].split(",")) if "--shots" in ARGS else None
	for name, (eye, tgt, lens) in shots.items():
		if only and name not in only:
			continue
		K.camera(tuple(rb(eye)), tuple(rb(tgt)), lens=lens, name="Cam_" + name)
		K.render(os.path.join(K.RENDER_DIR, "rooftops-preview-%s.jpg" % name), res=(1600, 900))


def main():
	mats = make_mats()
	kit = K.collection("Kit")
	built = []
	for nm in ("Facade8A", "Facade8B", "Facade8C"):
		built.append((nm, p_facade(nm, 8, mats, kit)))
	built += [
		("Facade4", p_facade("Facade4", 4, mats, kit)),
		("Plinth8", p_plinth("Plinth8", 8, mats, kit)),
		("Plinth4", p_plinth("Plinth4", 4, mats, kit)),
		("Quoin", p_quoin(mats, kit)),
		("Flue", p_flue(mats, kit)),
		("Stair16", p_stair(mats, kit)),
		("Gangway16", p_gangway(mats, kit)),
		("PlankRamp16", p_plank_ramp(mats, kit)),
		("Catwalk8", p_catwalk8(mats, kit)),
		("ACUnit", p_ac(mats, kit)),
		("Condenser", p_condenser(mats, kit)),
		("Skylight", p_skylight(mats, kit)),
		("Penthouse", p_penthouse(mats, kit)),
		("LetterA", p_letter("LetterA", "A", mats, kit)),
		("LetterB", p_letter("LetterB", "B", mats, kit)),
		("StairHut", p_stairhut(mats, kit)),
		("LiftHouse", p_lifthouse(mats, kit)),
		("LiftTower", p_lifttower(mats, kit)),
		("TankHouse", p_tankhouse(mats, kit)),
		("CoolingTower", p_coolingtower(mats, kit)),
		("WaterTank", p_watertank(mats, kit)),
		("Billboard", p_billboard(mats, kit)),
		("RoofSign", p_roofsign(mats, kit)),
		("StreetLamp", p_streetlamp(mats, kit)),
		("CityA", city_block("CityA", 24, 24, 60, mats, kit, body="CityStone", seed=3)),
		("CityB", city_block("CityB", 30, 30, 110, mats, kit, seed=5)),
		("CityC", city_block("CityC", 26, 26, 160, mats, kit, seed=9)),
		("SignTower", p_signtower(mats, kit)),
		("RadioMast", p_radiomast(mats, kit)),
	]
	tris, worst = {}, {}
	for name, col in built:
		tris[name] = K.tri_count(col)
		for ob in col.all_objects:
			if ob.type == "MESH":
				ob.data.calc_loop_triangles()
				worst[ob.name] = len(ob.data.loop_triangles)
	print("ROOFTOPS_TRIS " + json.dumps(tris))
	print("ROOFTOPS_MAX_OBJECT " + json.dumps(max(worst.items(), key=lambda kv: kv[1])))
	n_piece = check_pieces()
	items, art = assembled_items()
	n_map = zfight_report("assembled map (kit meshes + visible greybox and art Parts)", zfight(items))
	total = 0
	for sec, pc, x, y, z, yaw, tint, glow, scale in art.place:
		total += tris.get(pc, 0)
	parts = sum(sum(1 for o in PIECES[p[1]].objects if o.type == "MESH") for p in art.place if p[1] in PIECES)
	print("ROOFTOPS_BUDGET placements %d, MeshParts %d, triangles %d" % (len(art.place), parts, total))
	print("ROOFTOPS_ZFIGHT_TOTAL", n_piece + n_map)
	sheet(built, mats, tris)
	bpy.context.view_layer.layer_collection.children["Kit"].exclude = True
	path = K.save("Kit_Rooftops")
	print("ROOFTOPS saved", path)
	if "--no-render" in ARGS:
		return
	if "--no-sheet" not in ARGS:
		K.render(os.path.join(K.RENDER_DIR, "kit-contact.jpg"), res=(2200, 1400))
	assemble(mats, art)
	renders()


main()
