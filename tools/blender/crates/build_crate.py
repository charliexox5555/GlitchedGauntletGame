"""The Shop crate (vault/01 Design/Inventory and Crates.md), from the owner's model sheet
art-source/ui/shop/crates/crate_sheet.png. Run in a live Blender MCP instance:

    python tools/blender/lobby_v4/send.py tools/blender/crates/build_crate.py --port <port> --pid <pid>

It rebuilds the CRATE collection from scratch, so it can be re-run after any change.

Units: 1 Blender unit = 1 stud. X = length, -Y = front, Z = up, origin = floor centre.
Style (gauntlet-build-style): faceted only. Every edge is a flat chamfer (1 segment, flat
shading), round things are 6- or 8-sided prisms, ends are cut at an angle.

Built for animation: moving parts are their own objects with the pivot as the object origin
(Lid on the hinge axis, latches on their knuckles, the handle on its mounts, the gem at its
centre). The base and lid are hollow trays with an Interior liner that can glow when it opens.
Static pieces of one moving group are joined per colour role, so a tier is only colour data
in Studio: Body, Frame, Hardware, Light, Gem, Interior.
"""
import json
import math
import os

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = r"C:\Users\charl\Documents\GauntletGame\GlitchedGauntletGame"
OUT_JSON = os.path.join(ROOT, "art-source", "lobby", "crates", "Crate.json")

# Standard-tier preview colours (Studio sets the real tier colours).
ROLES = {
	"Body": (0x5C, 0x61, 0x6A),
	"Frame": (0x33, 0x31, 0x38),
	"Hardware": (0x9A, 0x9E, 0xA4),
	"Light": (0x2F, 0xD3, 0xE6),
	"Gem": (0x3F, 0xD8, 0xF0),
	"Interior": (0x1A, 0x1C, 0x21),
}

# ---------------------------------------------------------------- dimensions
HX, HY = 1.55, 0.52  # body half length / half depth (owner 2026-11-20: compacted from 1.95)
CUT = 0.16  # corner cut of the footprint (the clipped ends in the top view)
BASE_Z0, SEAM = 0.14, 0.62  # base body bottom / top
GAP = 0.02  # shadow gap between base and lid
LID_Z0, LID_Z1 = SEAM + GAP, 0.90
LID_CHAM = 0.09  # the lid's big top chamfer
WALL = 0.09
STRAP_X, STRAP_W, STRAP_T = 1.17, 0.30, 0.055
LATCH_X = 0.66
PANEL_X = 0.92  # front/back panel half length
HINGE_X = 0.86
HANDLE_X = 0.36  # front handle mount spacing

HINGE = Vector((0.0, HY + 0.05, SEAM + GAP / 2))  # lid axis (along X)
LATCH_PIVOT_YZ = (-(HY + 0.055), 0.38)
HANDLE_PIVOT_YZ = (-(HY + 0.065), 0.31)
GEM_C = Vector((0.0, 0.0, 1.02))

COLL = "CRATE"


# ---------------------------------------------------------------- helpers
def mat(role):
	name = "Crate_" + role
	m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
	r, g, b = ROLES[role]
	m.diffuse_color = (r / 255, g / 255, b / 255, 1)
	m.use_nodes = True
	bsdf = m.node_tree.nodes.get("Principled BSDF")
	if bsdf:
		bsdf.inputs["Base Color"].default_value = m.diffuse_color
		bsdf.inputs["Roughness"].default_value = 0.6
		if role in ("Light", "Gem"):
			bsdf.inputs["Emission Color"].default_value = m.diffuse_color
			bsdf.inputs["Emission Strength"].default_value = 2.0
	return m


def to3(plane, u, v, w):
	"""Point in a plane frame: 'XY' extrudes along Z, 'YZ' along X, 'XZ' along Y."""
	if plane == "XY":
		return Vector((u, v, w))
	if plane == "YZ":
		return Vector((w, u, v))
	return Vector((u, w, v))  # XZ: u = x, v = z, w = y


def prism(pts, plane, a0, a1, cham=0.0, taper=None):
	"""A solid from a 2D outline extruded a0..a1 along the plane's normal. taper = (s0, s1)
	scales the outline at each end about its centre (for wedges and flared feet)."""
	bm = bmesh.new()
	cu = sum(p[0] for p in pts) / len(pts)
	cv = sum(p[1] for p in pts) / len(pts)
	rings = []
	for a, s in ((a0, taper[0] if taper else 1.0), (a1, taper[1] if taper else 1.0)):
		rings.append([bm.verts.new(to3(plane, cu + (u - cu) * s, cv + (v - cv) * s, a)) for u, v in pts])
	n = len(pts)
	bm.faces.new(rings[0])
	bm.faces.new(list(reversed(rings[1])))
	for i in range(n):
		j = (i + 1) % n
		bm.faces.new((rings[0][i], rings[0][j], rings[1][j], rings[1][i]))
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	if cham > 0:
		bmesh.ops.bevel(bm, geom=list(bm.edges), offset=cham, segments=1, profile=0.5, affect="EDGES", clamp_overlap=True)
	return bm


def loft(rings, cham=0.0):
	"""A solid through horizontal outlines [(pts, z), ...] with the same point count."""
	bm = bmesh.new()
	vs = [[bm.verts.new((u, v, z)) for u, v in pts] for pts, z in rings]
	bm.faces.new(vs[0])
	bm.faces.new(list(reversed(vs[-1])))
	n = len(vs[0])
	for a, b in zip(vs, vs[1:]):
		for i in range(n):
			j = (i + 1) % n
			bm.faces.new((a[i], a[j], b[j], b[i]))
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	if cham > 0:
		bmesh.ops.bevel(bm, geom=list(bm.edges), offset=cham, segments=1, profile=0.5, affect="EDGES", clamp_overlap=True)
	return bm


def cham_rect(x0, x1, y0, y1, c):
	return [(x0 + c, y0), (x1 - c, y0), (x1, y0 + c), (x1, y1 - c), (x1 - c, y1), (x0 + c, y1), (x0, y1 - c), (x0, y0 + c)]


def ngon(cx, cy, r, n, rot=0.0):
	return [(cx + r * math.cos(rot + 2 * math.pi * i / n), cy + r * math.sin(rot + 2 * math.pi * i / n)) for i in range(n)]


PIECES = []  # (group, role, bmesh)


def add(group, role, bm):
	PIECES.append((group, role, bm))


def bar(group, role, p, q, r, sides=6):
	"""A faceted round bar from p to q (6 or 8 sides) with chamfered ends."""
	p, q = Vector(p), Vector(q)
	d = q - p
	L = d.length
	bm = prism(ngon(0, 0, r, sides, math.pi / sides), "XY", 0, L, cham=r * 0.25)
	rot = d.normalized().to_track_quat("Z", "Y").to_matrix().to_4x4()
	bmesh.ops.transform(bm, matrix=Matrix.Translation(p) @ rot, verts=bm.verts)
	add(group, role, bm)


def bolt(group, x, y, z, normal, r=0.045, h=0.03):
	"""Hex bolt head on a face; normal is the face's outward axis ('-Y', '+Y', '+Z', '-X', '+X')."""
	bm = prism(ngon(0, 0, r, 6, math.pi / 6), "XY", 0, h, taper=(1.0, 0.78))
	axis = {"-Y": (math.pi / 2, "X"), "+Y": (-math.pi / 2, "X"), "+Z": (0, "X"), "-X": (-math.pi / 2, "Y"), "+X": (math.pi / 2, "Y")}[normal]
	m = Matrix.Translation((x, y, z)) @ Matrix.Rotation(axis[0], 4, axis[1])
	bmesh.ops.transform(bm, matrix=m, verts=bm.verts)
	add(group, "Hardware", bm)


def boolean_cut(bm, cutter_bm):
	"""bm minus cutter, through a temporary object pair (exact solver)."""
	me_a, me_b = bpy.data.meshes.new("_a"), bpy.data.meshes.new("_b")
	bm.to_mesh(me_a)
	cutter_bm.to_mesh(me_b)
	coll = bpy.context.scene.collection
	a, b = bpy.data.objects.new("_a", me_a), bpy.data.objects.new("_b", me_b)
	coll.objects.link(a)
	coll.objects.link(b)
	mod = a.modifiers.new("cut", "BOOLEAN")
	mod.operation, mod.solver, mod.object = "DIFFERENCE", "EXACT", b
	dg = bpy.context.evaluated_depsgraph_get()
	out = bmesh.new()
	out.from_mesh(a.evaluated_get(dg).to_mesh())
	a.evaluated_get(dg).to_mesh_clear()
	for o in (a, b):
		bpy.data.objects.remove(o)
	bpy.data.meshes.remove(me_a)
	bpy.data.meshes.remove(me_b)
	return out


# ---------------------------------------------------------------- the crate
FOOT = cham_rect(-HX, HX, -HY, HY, CUT)
INNER = cham_rect(-HX + WALL, HX - WALL, -HY + WALL, HY - WALL, CUT * 0.7)


def build_base():
	g = "Base"
	# hollow tray: chamfered outer block minus the cavity
	body = prism(FOOT, "XY", BASE_Z0, SEAM, cham=0.04)
	body = boolean_cut(body, prism(INNER, "XY", BASE_Z0 + 0.10, SEAM + 0.2))
	add(g, "Body", body)
	add(g, "Interior", prism(cham_rect(-HX + WALL + 0.02, HX - WALL - 0.02, -HY + WALL + 0.02, HY - WALL - 0.02, 0.08), "XY", BASE_Z0 + 0.10, BASE_Z0 + 0.12))
	# inner rim lip that fills the seam gap when closed and reads as a rim when open
	rim_o = cham_rect(-HX + WALL * 0.45, HX - WALL * 0.45, -HY + WALL * 0.45, HY - WALL * 0.45, CUT * 0.85)
	rim = prism(rim_o, "XY", SEAM - 0.08, SEAM + 0.05)
	rim = boolean_cut(rim, prism(INNER, "XY", SEAM - 0.2, SEAM + 0.2))
	add(g, "Frame", rim)

	# front and back panels: a raised chamfered frame ring, the body shows through as the recess
	for side in (-1, 1):
		y0 = side * HY
		outer = cham_rect(-PANEL_X, PANEL_X, 0.21, 0.49, 0.07)
		inner = cham_rect(-PANEL_X + 0.06, PANEL_X - 0.06, 0.25, 0.45, 0.05)
		a0, a1 = (y0, y0 + side * 0.035)
		ring = prism(outer, "XZ", min(a0, a1), max(a0, a1), cham=0.012)
		ring = boolean_cut(ring, prism(inner, "XZ", min(a0, a1) - 0.1, max(a0, a1) + 0.1))
		add(g, "Body", ring)

	# glowing slot on the front: dark bezel, light bar set into it
	add(g, "Frame", prism(cham_rect(-0.22, 0.22, 0.505, 0.575, 0.025), "XZ", -HY - 0.03, -HY + 0.005, cham=0.008))
	add(g, "Light", prism(cham_rect(-0.16, 0.16, 0.525, 0.555, 0.012), "XZ", -HY - 0.038, -HY - 0.02))

	# straps: one U band per side round front, bottom and back, ending at the seam
	for sx in (-1, 1):
		x = sx * STRAP_X
		o = HY + STRAP_T
		u = [(-o, 0.10), (o, 0.10), (o, SEAM - 0.02), (o - 0.02, SEAM), (HY, SEAM), (HY, BASE_Z0), (-HY, BASE_Z0), (-HY, SEAM), (-o + 0.02, SEAM), (-o, SEAM - 0.02)]
		add(g, "Frame", prism(u, "YZ", x - STRAP_W / 2, x + STRAP_W / 2, cham=0.015))
		for side in (-1, 1):
			for z in (0.24, 0.50):
				bolt(g, x, side * o, z, "-Y" if side < 0 else "+Y")
		# feet: flared wedges under each strap, front and back
		for side in (-1, 1):
			y0, y1 = (side * 0.28, side * (HY + 0.09))
			add(g, "Frame", prism(cham_rect(x - 0.21, x + 0.21, min(y0, y1), max(y0, y1), 0.04), "XY", -0.03, 0.10, cham=0.02, taper=(1.0, 0.84)))

	# latch keeper plates (the latch lever pivots on their knuckle)
	for sx in (-1, 1):
		x = sx * LATCH_X
		add(g, "Hardware", prism(cham_rect(x - 0.11, x + 0.11, 0.33, 0.58, 0.035), "XZ", -HY - 0.043, -HY + 0.005, cham=0.008))
		bar(g, "Hardware", (x - 0.1, LATCH_PIVOT_YZ[0], LATCH_PIVOT_YZ[1]), (x + 0.1, LATCH_PIVOT_YZ[0], LATCH_PIVOT_YZ[1]), 0.03)

	# front handle mounts
	for sx in (-1, 1):
		x = sx * HANDLE_X
		add(g, "Hardware", prism(cham_rect(x - 0.06, x + 0.06, 0.25, 0.37, 0.025), "XZ", -HY - 0.06, -HY + 0.005, cham=0.008))

	# end handles (fixed): faceted U bars on the ends with mount blocks
	for sx in (-1, 1):
		xe = sx * HX
		for sy in (-1, 1):
			add(g, "Hardware", _end_mount(xe, sx, sy))
		bar(g, "Hardware", (xe + sx * 0.17, -0.20, 0.28), (xe + sx * 0.17, 0.20, 0.28), 0.045, sides=8)
		for sy in (-1, 1):
			bar(g, "Hardware", (xe + sx * 0.045, sy * 0.21, 0.37), (xe + sx * 0.17, sy * 0.20, 0.28), 0.04)

	# back hinges: base leaf + middle knuckle (the lid carries the outer knuckles)
	for sx in (-1, 1):
		x = sx * HINGE_X
		add(g, "Hardware", prism(cham_rect(x - 0.13, x + 0.13, 0.44, SEAM - 0.005, 0.03), "XZ", HY - 0.005, HY + 0.03, cham=0.008))
		bar(g, "Hardware", (x - 0.045, HINGE.y, HINGE.z), (x + 0.045, HINGE.y, HINGE.z), 0.045)
		for dx in (-0.08, 0.08):
			bolt(g, x + dx, HY + 0.03, 0.50, "+Y", r=0.03, h=0.02)


def _end_mount(xe, sx, sy):
	y = sy * 0.21
	a0, a1 = sorted((xe - sx * 0.005, xe + sx * 0.05))
	return prism(cham_rect(y - 0.06, y + 0.06, 0.31, 0.43, 0.025), "YZ", a0, a1, cham=0.008)


def build_lid():
	g = "Lid"
	# straight sides, then the big top chamfer as its own ring of facets
	top = cham_rect(-HX + LID_CHAM, HX - LID_CHAM, -HY + LID_CHAM, HY - LID_CHAM, CUT)
	lid = loft([(FOOT, LID_Z0), (FOOT, LID_Z1 - LID_CHAM), (top, LID_Z1)], cham=0.02)
	lid = boolean_cut(lid, prism(INNER, "XY", LID_Z0 - 0.2, LID_Z1 - 0.10))
	add(g, "Body", lid)
	add(g, "Interior", prism(cham_rect(-HX + WALL + 0.02, HX - WALL - 0.02, -HY + WALL + 0.02, HY - WALL - 0.02, 0.08), "XY", LID_Z1 - 0.12, LID_Z1 - 0.10))

	# raised lid plate: a long notched octagon
	a, b, c, d = 0.74, 0.81, 0.92, 0.98  # notch stations along X, inside the straps
	plate = [(-a, -0.30), (a, -0.30), (b, -0.21), (c, -0.21), (d, -0.10), (d, 0.10), (c, 0.21), (b, 0.21), (a, 0.30), (-a, 0.30), (-b, 0.21), (-c, 0.21), (-d, 0.10), (-d, -0.10), (-c, -0.21), (-b, -0.21)]
	add(g, "Body", prism(plate, "XY", LID_Z1 - 0.01, LID_Z1 + 0.05, cham=0.02))

	# gem mount: a diamond plate
	add(g, "Hardware", prism(ngon(0, 0, 0.23, 4), "XY", LID_Z1 + 0.04, LID_Z1 + 0.09, cham=0.018, taper=(1.0, 0.9)))

	# lid straps follow the chamfered top
	for sx in (-1, 1):
		x = sx * STRAP_X
		o = HY + STRAP_T
		c = LID_CHAM
		t = LID_Z1 + STRAP_T
		u = [(-o, LID_Z0), (-HY, LID_Z0), (-HY, LID_Z1 - c), (-HY + c, LID_Z1), (HY - c, LID_Z1), (HY, LID_Z1 - c), (HY, LID_Z0), (o, LID_Z0), (o, LID_Z1 - c + 0.02), (HY - c + 0.03, t), (-HY + c - 0.03, t), (-o, LID_Z1 - c + 0.02)]
		add(g, "Frame", prism(u, "YZ", x - STRAP_W / 2, x + STRAP_W / 2, cham=0.015))
		for side in (-1, 1):
			bolt(g, x, side * o, 0.74, "-Y" if side < 0 else "+Y")
		for dy in (-0.2, 0.2):
			bolt(g, x, dy, t, "+Z", h=0.02)

	# latch catches on the lid front
	for sx in (-1, 1):
		x = sx * LATCH_X
		add(g, "Hardware", prism(cham_rect(x - 0.08, x + 0.08, LID_Z0 + 0.03, LID_Z0 + 0.10, 0.02), "XZ", -HY - 0.035, -HY + 0.005, cham=0.008))

	# lid hinge leaves and outer knuckles
	for sx in (-1, 1):
		x = sx * HINGE_X
		add(g, "Hardware", prism(cham_rect(x - 0.13, x + 0.13, LID_Z0 + 0.005, 0.80, 0.03), "XZ", HY - 0.005, HY + 0.03, cham=0.008))
		for dx in (-0.1, 0.1):
			bar(g, "Hardware", (x + dx - 0.045, HINGE.y, HINGE.z), (x + dx + 0.045, HINGE.y, HINGE.z), 0.045)


def build_gem():
	# a faceted square gem: diamond base, cut crown, flat table
	bm = bmesh.new()
	rings = [(0.15, -0.03), (0.15, 0.0), (0.08, 0.06)]
	vs = []
	for r, dz in rings:
		vs.append([bm.verts.new((GEM_C.x + x, GEM_C.y + y, GEM_C.z + dz)) for x, y in ngon(0, 0, r, 4)])
	bm.faces.new(vs[0])
	bm.faces.new(list(reversed(vs[-1])))
	for a, b in zip(vs, vs[1:]):
		for i in range(4):
			j = (i + 1) % 4
			bm.faces.new((a[i], a[j], b[j], b[i]))
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	bmesh.ops.bevel(bm, geom=list(bm.edges), offset=0.008, segments=1, affect="EDGES", clamp_overlap=True)
	add("Gem", "Gem", bm)


def build_latch(sx):
	g = "LatchL" if sx < 0 else "LatchR"
	x = sx * LATCH_X
	py, pz = LATCH_PIVOT_YZ
	# lever: knuckle at the bottom, a tapered plate up over the seam, a hook lip onto the lid catch
	bar(g, "Hardware", (x - 0.075, py, pz), (x + 0.075, py, pz), 0.04)
	lever = [(x - 0.10, pz), (x + 0.10, pz), (x + 0.115, pz + 0.06), (x + 0.115, pz + 0.17), (x + 0.085, LID_Z0 + 0.12), (x - 0.085, LID_Z0 + 0.12), (x - 0.115, pz + 0.17), (x - 0.115, pz + 0.06)]
	add(g, "Hardware", prism(lever, "XZ", -HY - 0.085, -HY - 0.04, cham=0.012))
	add(g, "Hardware", prism(cham_rect(x - 0.07, x + 0.07, LID_Z0 + 0.10, LID_Z0 + 0.14, 0.012), "XZ", -HY - 0.075, -HY - 0.035, cham=0.006))
	# pull tab at the bottom
	add(g, "Hardware", prism(cham_rect(x - 0.06, x + 0.06, pz - 0.07, pz - 0.02, 0.015), "XZ", -HY - 0.085, -HY - 0.055, cham=0.006))


def build_handle():
	g = "Handle"
	py, pz = HANDLE_PIVOT_YZ
	# hangs down from its mounts: arms out and down, a faceted grip
	gy, gz = py - 0.12, pz - 0.15
	gx = HANDLE_X - 0.10
	bar(g, "Hardware", (-gx, gy, gz), (gx, gy, gz), 0.05, sides=8)
	for sx in (-1, 1):
		bar(g, "Hardware", (sx * HANDLE_X, py, pz), (sx * (gx + 0.01), gy, gz), 0.042)
		bar(g, "Hardware", (sx * (HANDLE_X - 0.05), py, pz), (sx * (HANDLE_X + 0.05), py, pz), 0.055)


# ---------------------------------------------------------------- export
def export(path):
	"""Every CRATE part into one FBX (one MeshPart each in Studio), same settings as the lobby kit."""
	bpy.ops.object.select_all(action="DESELECT")
	for ob in bpy.data.collections[COLL].objects:
		ob.select_set(True)
	bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={"MESH"}, apply_scale_options="FBX_SCALE_UNITS", use_mesh_modifiers=True, bake_anim=False)
	return path


# ---------------------------------------------------------------- assemble
PIVOTS = {
	"Lid": (HINGE.x, HINGE.y, HINGE.z),
	"LatchL": (-LATCH_X, LATCH_PIVOT_YZ[0], LATCH_PIVOT_YZ[1]),
	"LatchR": (LATCH_X, LATCH_PIVOT_YZ[0], LATCH_PIVOT_YZ[1]),
	"Handle": (0.0, HANDLE_PIVOT_YZ[0], HANDLE_PIVOT_YZ[1]),
	"Gem": (GEM_C.x, GEM_C.y, GEM_C.z),
	"Base": (0.0, 0.0, 0.0),
}


def build():
	PIECES.clear()
	coll = bpy.data.collections.get(COLL)
	if coll:
		for o in list(coll.objects):
			me = o.data
			bpy.data.objects.remove(o)
			if me and me.users == 0:
				bpy.data.meshes.remove(me)
	else:
		coll = bpy.data.collections.new(COLL)
		bpy.context.scene.collection.children.link(coll)

	build_base()
	build_lid()
	build_gem()
	build_latch(-1)
	build_latch(1)
	build_handle()

	# join pieces per (group, role) into one mesh each
	merged = {}
	for g, role, bm in PIECES:
		key = (g, role)
		if key not in merged:
			merged[key] = bmesh.new()
		me = bpy.data.meshes.new("_tmp")
		bm.to_mesh(me)
		merged[key].from_mesh(me)
		bpy.data.meshes.remove(me)
		bm.free()

	info = {"parts": {}, "pivots": PIVOTS, "units": "studs", "axes": "blender X=length, -Y=front, Z=up"}
	tris = 0
	for (g, role), bm in merged.items():
		name = f"{g}_{role}"
		bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
		bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4])
		px, py, pz = PIVOTS[g]
		bmesh.ops.translate(bm, vec=(-px, -py, -pz), verts=bm.verts)  # pivot = object origin
		me = bpy.data.meshes.new(name)
		bm.to_mesh(me)
		bm.free()
		for p in me.polygons:
			p.use_smooth = False
		me.materials.append(mat(role))
		ob = bpy.data.objects.new(name, me)
		ob.location = (px, py, pz)
		ob["group"], ob["role"] = g, role
		coll.objects.link(ob)
		bb = [ob.matrix_world @ Vector(c) for c in ob.bound_box]
		lo = Vector((min(v.x for v in bb), min(v.y for v in bb), min(v.z for v in bb)))
		hi = Vector((max(v.x for v in bb), max(v.y for v in bb), max(v.z for v in bb)))
		t = sum(len(p.vertices) - 2 for p in me.polygons)
		tris += t
		info["parts"][name] = {"group": g, "role": role, "min": list(lo), "max": list(hi), "tris": t}
	info["tris"] = tris
	os.makedirs(os.path.dirname(OUT_JSON), exist_ok=True)
	with open(OUT_JSON, "w") as f:
		json.dump(info, f, indent=1)
	return {"parts": len(info["parts"]), "tris": tris}


result = build()
