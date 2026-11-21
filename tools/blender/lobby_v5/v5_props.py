"""Lobby V5 decor props (owner 2026-11-21: "cases, boxes, barrels and other things that match our vibe",
built in Blender, not assembled from Parts). Run in a live Blender MCP instance:

    build()   rebuilds the V5Props collection from scratch
    export()  writes art-source/lobby/v5/Exports/V5_Props.fbx (one MeshPart per <Prop>_<Role> object)

Units: 1 Blender unit = 1 stud. X = length, -Y = front, Z = up, every prop's origin = its floor centre.
Style (gauntlet-build-style): faceted only, flat shading, 1-segment chamfers, round things are 10- or
12-sided prisms, nothing ends square. Each prop is joined per colour role so a variant is only colour
data in Studio: Body, Trim, Hardware, Accent, Rubber.
Props are laid out along X (SPACING apart) so they don't overlap in the file; Studio re-pivots each one.
"""
import math
import os

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = r"C:\Users\charl\Documents\GauntletGame\GlitchedGauntletGame"
OUT = os.path.join(ROOT, "art-source", "lobby", "v5", "Exports", "V5_Props.fbx")
COLL = "V5Props"
SPACING = 8.0

# Preview colours only (Studio sets the real variant colours).
ROLES = {
	"Body": (0x4A, 0x4E, 0x55),
	"Trim": (0x2C, 0x2E, 0x33),
	"Hardware": (0x9A, 0x9E, 0xA4),
	"Accent": (0xE8, 0xB8, 0x2A),
	"Rubber": (0x1D, 0x1E, 0x21),
}


# ---------------------------------------------------------------- helpers
def mat(role):
	name = "Prop_" + role
	m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
	r, g, b = ROLES[role]
	m.diffuse_color = (r / 255, g / 255, b / 255, 1)
	return m


def to3(plane, u, v, w):
	"""'XY' extrudes along Z, 'YZ' along X (u=y, v=z), 'XZ' along Y (u=x, v=z)."""
	if plane == "XY":
		return Vector((u, v, w))
	if plane == "YZ":
		return Vector((w, u, v))
	return Vector((u, w, v))


def _bevel(bm, cham):
	if cham > 0:
		bmesh.ops.bevel(bm, geom=list(bm.edges), offset=cham, segments=1, profile=0.5, affect="EDGES", clamp_overlap=True)
	return bm


def prism(pts, plane, a0, a1, cham=0.0, taper=None):
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
	return _bevel(bm, cham)


def loft(rings, cham=0.0):
	"""Solid through horizontal outlines [(pts, z), ...] with equal point counts."""
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
	return _bevel(bm, cham)


def annulus(n, r_out, r_in, z0, z1, cx=0.0, cy=0.0, rot=None, cham=0.0):
	"""A faceted ring (n sides) between z0 and z1."""
	rot = math.pi / n if rot is None else rot
	bm = bmesh.new()
	o0 = [bm.verts.new((cx + r_out * math.cos(rot + 2 * math.pi * i / n), cy + r_out * math.sin(rot + 2 * math.pi * i / n), z0)) for i in range(n)]
	o1 = [bm.verts.new((v.co.x, v.co.y, z1)) for v in o0]
	i0 = [bm.verts.new((cx + r_in * math.cos(rot + 2 * math.pi * i / n), cy + r_in * math.sin(rot + 2 * math.pi * i / n), z0)) for i in range(n)]
	i1 = [bm.verts.new((v.co.x, v.co.y, z1)) for v in i0]
	for i in range(n):
		j = (i + 1) % n
		bm.faces.new((o0[i], o0[j], o1[j], o1[i]))
		bm.faces.new((i1[i], i1[j], i0[j], i0[i]))
		bm.faces.new((o1[i], o1[j], i1[j], i1[i]))
		bm.faces.new((i0[i], i0[j], o0[j], o0[i]))
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	return _bevel(bm, cham)


def cham_rect(x0, x1, y0, y1, c):
	return [(x0 + c, y0), (x1 - c, y0), (x1, y0 + c), (x1, y1 - c), (x1 - c, y1), (x0 + c, y1), (x0, y1 - c), (x0, y0 + c)]


def ngon(cx, cy, r, n, rot=None):
	rot = math.pi / n if rot is None else rot
	return [(cx + r * math.cos(rot + 2 * math.pi * i / n), cy + r * math.sin(rot + 2 * math.pi * i / n)) for i in range(n)]


def xform(bm, m):
	bmesh.ops.transform(bm, matrix=m, verts=bm.verts)
	return bm


PIECES = []  # (prop, role, bmesh)
_prop = [""]


def add(role, bm):
	PIECES.append((_prop[0], role, bm))


def bar(role, p, q, r, sides=6, rot=None):
	"""A faceted bar from p to q with chamfered ends (sides=4 → square bar)."""
	p, q = Vector(p), Vector(q)
	d = q - p
	bm = prism(ngon(0, 0, r, sides, rot), "XY", 0, d.length, cham=r * 0.3)
	m = Matrix.Translation(p) @ d.normalized().to_track_quat("Z", "Y").to_matrix().to_4x4()
	add(role, xform(bm, m))


def bolt(x, y, z, normal, r=0.05, h=0.035):
	bm = prism(ngon(0, 0, r, 6), "XY", 0, h, taper=(1.0, 0.75))
	ax = {"-Y": (math.pi / 2, "X"), "+Y": (-math.pi / 2, "X"), "+Z": (0, "X"), "-X": (-math.pi / 2, "Y"), "+X": (math.pi / 2, "Y")}[normal]
	add("Hardware", xform(bm, Matrix.Translation((x, y, z)) @ Matrix.Rotation(ax[0], 4, ax[1])))


# ---------------------------------------------------------------- props (v2, 2026-11-21)
# Owner rejected v1 (field case, supply crates, pallet, ammo box, tool chest) as "rounded low poly shapes
# that do not connect well". v2 rules (memory props-crisp-connected): crisp main forms with small even
# bevels, details cut in with booleans or bands that wrap the whole body, attachments seated in pockets.
def box(x0, x1, y0, y1, z0, z1, bev=0.0):
	bm = prism([(x0, y0), (x1, y0), (x1, y1), (x0, y1)], "XY", z0, z1)
	return _bevel(bm, bev)


def cut(bm, cutters):
	"""bm minus the union of cutter bmeshes (exact boolean through temporary objects)."""
	if not cutters:
		return bm
	cb = bmesh.new()
	for c in cutters:
		me = bpy.data.meshes.new("_c")
		c.to_mesh(me)
		cb.from_mesh(me)
		bpy.data.meshes.remove(me)
		c.free()
	me_a, me_b = bpy.data.meshes.new("_a"), bpy.data.meshes.new("_b")
	bm.to_mesh(me_a)
	cb.to_mesh(me_b)
	coll = bpy.context.scene.collection
	a, b = bpy.data.objects.new("_a", me_a), bpy.data.objects.new("_b", me_b)
	coll.objects.link(a)
	coll.objects.link(b)
	mod = a.modifiers.new("cut", "BOOLEAN")
	mod.operation, mod.solver, mod.object = "DIFFERENCE", "EXACT", b
	dg = bpy.context.evaluated_depsgraph_get()
	out = bmesh.new()
	ev = a.evaluated_get(dg)
	out.from_mesh(ev.to_mesh())
	ev.to_mesh_clear()
	for o in (a, b):
		bpy.data.objects.remove(o)
	bpy.data.meshes.remove(me_a)
	bpy.data.meshes.remove(me_b)
	bm.free()
	cb.free()
	return out


def weapon_crate():
	"""Military crate: body and lid split by a dark seam groove, four wide bands wrapping front, top and back,
	a recessed label with an inset plate, hand-hold slots cut into both ends, latches spanning the seam."""
	HX, HY, H, SEAM = 2.6, 1.7, 2.9, 1.9
	bands = (-1.95, -0.65, 0.65, 1.95)
	ends = [box(sx * HX - 0.4, sx * HX + 0.4, -0.55, 0.55, 1.15, 1.5) for sx in (-1, 1)]
	add("Body", cut(box(-HX, HX, -HY, HY, 0.12, SEAM - 0.04, 0.06), ends + [box(1.03, 1.57, -HY - 0.1, -HY + 0.05, 0.55, 1.35)]))
	add("Body", box(-HX, HX, -HY, HY, SEAM + 0.04, H, 0.06))
	add("Trim", box(-HX + 0.07, HX - 0.07, -HY + 0.07, HY - 0.07, SEAM - 0.1, SEAM + 0.1))
	for x in bands:
		b = box(x - 0.3, x + 0.3, -HY - 0.08, HY + 0.08, 0.12, H + 0.08, 0.04)
		b = cut(b, [box(x - 0.5, x + 0.5, -HY + 0.02, HY - 0.02, -1, H - 0.02)])
		add("Body", cut(b, [box(x - 0.5, x + 0.5, -HY - 0.3, HY + 0.3, SEAM - 0.04, SEAM + 0.04)]))
	add("Accent", box(1.07, 1.53, -HY + 0.035, -HY + 0.06, 0.6, 1.3))
	for x in (-1.3, 1.3):
		add("Hardware", box(x - 0.18, x + 0.18, -HY - 0.06, -HY + 0.01, SEAM - 0.32, SEAM + 0.3, 0.02))
	for y in (-1.15, 1.15):
		add("Trim", box(-HX + 0.15, HX - 0.15, y - 0.3, y + 0.3, 0.0, 0.14, 0.03))


def flat_case():
	"""Low hard case: base and lid split by a seam groove, four grooves cut across the lid, latches seated in
	pockets on the front, a carry handle in its own pocket, a stencil plate set into the lid."""
	HX, HY, H, SEAM = 2.7, 1.6, 1.3, 0.64

	def pockets():
		p = [box(x - 0.3, x + 0.3, -HY - 0.1, -HY + 0.16, SEAM - 0.3, SEAM + 0.3) for x in (-1.6, 1.6)]
		p.append(box(-0.6, 0.6, -HY - 0.1, -HY + 0.22, 0.14, 0.44))
		return p

	add("Body", cut(box(-HX, HX, -HY, HY, 0.0, SEAM - 0.04, 0.07), pockets()))
	grooves = [box(x - 0.07, x + 0.07, -HY + 0.25, HY - 0.25, H - 0.07, H + 0.2) for x in (-2.0, -1.2, 1.2, 2.0)]
	grooves.append(box(-0.8, 0.8, -0.5, 0.5, H - 0.04, H + 0.2))
	add("Body", cut(box(-HX, HX, -HY, HY, SEAM + 0.04, H, 0.07), grooves + pockets()))
	add("Trim", box(-HX + 0.07, HX - 0.07, -HY + 0.07, HY - 0.07, SEAM - 0.08, SEAM + 0.08))
	add("Accent", box(-0.76, 0.76, -0.46, 0.46, H - 0.06, H - 0.03))
	for x in (-1.6, 1.6):
		add("Hardware", box(x - 0.2, x + 0.2, -HY + 0.03, -HY + 0.17, SEAM - 0.24, SEAM + 0.24, 0.02))
	add("Hardware", box(-0.6, 0.6, -HY + 0.03, -HY + 0.12, 0.24, 0.34, 0.015))


def cargo_box():
	"""Tall cargo box: body with vertical grooves cut into every face, a steel tray rim at the foot and a
	steel lid rim on top with a shallow recessed lid."""
	S, H = 1.7, 3.8
	gr = []
	for u in (-0.75, 0.75):
		for s in (-1, 1):
			gr.append(box(u - 0.06, u + 0.06, s * S - 0.06, s * S + 0.06, 0.7, H - 0.7))
			gr.append(box(s * S - 0.06, s * S + 0.06, u - 0.06, u + 0.06, 0.7, H - 0.7))
	add("Body", cut(box(-S, S, -S, S, 0.4, H - 0.4, 0.05), gr))
	add("Hardware", box(-S - 0.12, S + 0.12, -S - 0.12, S + 0.12, 0.0, 0.55, 0.06))
	add("Hardware", cut(box(-S - 0.12, S + 0.12, -S - 0.12, S + 0.12, H - 0.5, H, 0.06), [box(-S + 0.2, S - 0.2, -S + 0.2, S - 0.2, H - 0.12, H + 1)]))
	add("Trim", box(-0.3, 0.3, -0.12, 0.12, H - 0.13, H - 0.04, 0.02))


def ammo_can():
	"""Ammo can: body with two grooves cut along the back, an overlapping lid, the handle folded into a slot
	in the lid, an end latch spanning lid and body, a stencil plate in a recess on the front."""
	HX, HY = 0.85, 0.4
	cuts = [box(-0.62, 0.62, HY - 0.04, HY + 0.1, z - 0.03, z + 0.03) for z in (0.3, 0.6)]
	cuts.append(box(-0.6, 0.1, -HY - 0.1, -HY + 0.03, 0.3, 0.58))
	add("Body", cut(box(-HX, HX, -HY, HY, 0.0, 0.9, 0.04), cuts))
	add("Accent", box(-0.58, 0.08, -HY + 0.025, -HY + 0.04, 0.32, 0.56))
	add("Trim", cut(box(-HX - 0.04, HX + 0.04, -HY - 0.04, HY + 0.04, 0.84, 1.08, 0.04), [box(-0.45, 0.45, -0.09, 0.09, 1.0, 1.2)]))
	add("Hardware", box(-0.43, 0.43, -0.05, 0.05, 1.0, 1.07, 0.012))
	add("Hardware", box(HX + 0.02, HX + 0.08, -0.18, 0.18, 0.55, 1.0, 0.015))


def power_box():
	"""Electrical cabinet: body on a plinth, the door set into a recess with a shadow gap, slot vents cut into
	the door, a hazard plate in a recess, a lever handle in a pocket, a drip cap on top."""
	HX, HY, H = 1.2, 0.55, 3.4
	add("Body", cut(box(-HX, HX, -HY, HY, 0.3, H, 0.05), [box(-HX + 0.15, HX - 0.15, -HY - 0.1, -HY + 0.1, 0.5, H - 0.25)]))
	vents = [box(-0.55, 0.55, -HY - 0.2, -HY + 0.13, z - 0.04, z + 0.04) for z in (0.8, 1.0, 1.2, 1.4)]
	vents.append(box(-0.4, 0.4, -HY - 0.2, -HY + 0.105, 2.2, 2.85))
	vents.append(box(0.65, 0.9, -HY - 0.2, -HY + 0.12, 1.55, 2.25))
	add("Body", cut(box(-HX + 0.19, HX - 0.19, -HY + 0.06, -HY + 0.16, 0.54, H - 0.29, 0.01), vents))
	add("Trim", box(-HX + 0.16, HX - 0.16, -HY + 0.1, -HY + 0.3, 0.51, H - 0.26))
	add("Accent", box(-0.38, 0.38, -HY + 0.095, -HY + 0.12, 2.22, 2.83))
	add("Hardware", box(0.71, 0.84, -HY + 0.02, -HY + 0.13, 1.6, 2.2, 0.02))
	add("Trim", box(-HX + 0.05, HX - 0.05, -HY + 0.05, HY - 0.05, 0.0, 0.34, 0.03))
	add("Trim", box(-HX - 0.06, HX + 0.06, -HY - 0.08, HY + 0.02, H - 0.05, H + 0.16, 0.04))


def drum():
	"""Steel drum: 12-sided shell, two rolled hoops, rim and chime rings, lid with two bungs, a band.
	The owner liked this one (2026-11-21): keep it as is."""
	n, R = 12, 1.1
	add("Body", loft([(ngon(0, 0, R * 0.95, n), 0.06), (ngon(0, 0, R, n), 0.16), (ngon(0, 0, R, n), 2.84), (ngon(0, 0, R * 0.96, n), 2.9)]))
	add("Trim", annulus(n, R + 0.05, R - 0.12, 2.8, 3.02, cham=0.02))
	add("Trim", annulus(n, R + 0.03, R - 0.12, 0.0, 0.14, cham=0.02))
	for z in (0.98, 1.92):
		add("Trim", annulus(n, R + 0.06, R - 0.05, z, z + 0.12, cham=0.03))
	add("Accent", annulus(n, R + 0.025, R - 0.05, 1.3, 1.6))
	add("Hardware", prism(ngon(0.52, 0.18, 0.15, 6), "XY", 2.85, 2.97, cham=0.02))
	add("Hardware", prism(ngon(-0.55, -0.12, 0.1, 6), "XY", 2.85, 2.95, cham=0.015))


def pallet():
	"""Composite pallet with crisp square-ended slats, stringers, blocks and runners."""
	for y in (-1.66, -0.83, 0.0, 0.83, 1.66):
		add("Body", box(-2.0, 2.0, y - 0.34, y + 0.34, 0.38, 0.52, 0.025))
	for x in (-1.72, 0.0, 1.72):
		add("Trim", box(x - 0.26, x + 0.26, -1.96, 1.96, 0.26, 0.39, 0.02))
		for y in (-1.72, 0.0, 1.72):
			add("Trim", box(x - 0.28, x + 0.28, y - 0.28, y + 0.28, 0.11, 0.27, 0.025))
	for y in (-1.72, 0.0, 1.72):
		add("Body", box(-2.0, 2.0, y - 0.28, y + 0.28, 0.0, 0.12, 0.02))


def _axis_x(bm, mirror=False):
	"""Turn a build along Z so its axis runs along X (mirrored to -X when asked), then lift it."""
	m = Matrix.Rotation(math.pi / 2, 4, "Y")
	if mirror:
		m = Matrix.Scale(-1, 4, Vector((1, 0, 0))) @ m
	xform(bm, m)
	if mirror:
		bmesh.ops.reverse_faces(bm, faces=bm.faces)
	return bm


def cable_spool():
	"""Cable spool on its side, built like the drum: two 12-sided flanges with a rim ring, cable wound on the
	core in three bands, a hex hub boss. Axis along X, a flat facet on the floor."""
	n, R = 12, 1.6
	cz = R * math.cos(math.pi / n)
	lift = Matrix.Translation((0, 0, cz))
	for mir in (False, True):
		add("Body", xform(_axis_x(prism(ngon(0, 0, R, n), "XY", 1.04, 1.26, cham=0.03), mir), lift))
		add("Trim", xform(_axis_x(annulus(n, R + 0.04, R - 0.18, 1.24, 1.32, cham=0.015), mir), lift))
		add("Hardware", xform(_axis_x(prism(ngon(0, 0, 0.5, 6), "XY", 1.24, 1.38, cham=0.03), mir), lift))
	add("Rubber", xform(_axis_x(prism(ngon(0, 0, 1.22, n), "XY", -1.05, 1.05)), lift))
	for x in (-0.68, 0.0, 0.68):
		add("Rubber", xform(_axis_x(prism(ngon(0, 0, 1.3, n), "XY", x - 0.3, x + 0.3, cham=0.04)), lift))
	add("Accent", xform(_axis_x(annulus(n, 1.315, 1.2, 0.34, 0.46)), lift))


def tool_chest():
	"""Rolling tool chest: each drawer set into its own recess in the body, finger-pull slots cut into the
	drawer fronts, an overhanging lid, a side grip bar in a pocket, casters."""
	HX, HY = 1.1, 0.65
	z, rec, fronts = 0.55, [], []
	for h in (0.6, 0.52, 0.44, 0.4, 0.36):
		rec.append(box(-HX + 0.1, HX - 0.1, -HY - 0.1, -HY + 0.08, z, z + h))
		fronts.append((z, z + h))
		z += h + 0.06
	rec.append(box(HX - 0.12, HX + 0.1, -0.45, 0.45, 2.42, 2.68))
	add("Body", cut(box(-HX, HX, -HY, HY, 0.4, 3.0, 0.04), rec))
	for z0, z1 in fronts:
		f = box(-HX + 0.13, HX - 0.13, -HY - 0.02, -HY + 0.08, z0 + 0.03, z1 - 0.03, 0.015)
		add("Trim", cut(f, [box(-0.55, 0.55, -HY - 0.2, -HY + 0.0, z1 - 0.14, z1 - 0.07)]))
	add("Trim", box(-HX - 0.04, HX + 0.04, -HY - 0.04, HY + 0.04, 2.97, 3.2, 0.04))
	add("Trim", box(-HX + 0.03, HX - 0.03, -HY + 0.03, HY - 0.03, 0.26, 0.42, 0.02))
	add("Hardware", box(HX - 0.07, HX - 0.01, -0.45, 0.45, 2.52, 2.58, 0.01))
	add("Accent", box(-HX - 0.015, -HX + 0.01, -0.4, 0.4, 2.2, 2.65))
	for sx in (-1, 1):
		for sy in (-1, 1):
			cx, cy = sx * (HX - 0.22), sy * (HY - 0.2)
			add("Hardware", box(cx - 0.1, cx + 0.1, cy - 0.12, cy + 0.12, 0.12, 0.27, 0.02))
			add("Rubber", prism(ngon(cy, 0.12, 0.12, 8), "YZ", cx - 0.06, cx + 0.06))


PROPS = [
	("WeaponCrate", weapon_crate),
	("FlatCase", flat_case),
	("CargoBox", cargo_box),
	("Drum", drum),
	("Pallet", pallet),
	("AmmoCan", ammo_can),
	("CableSpool", cable_spool),
	("ToolChest", tool_chest),
	("PowerBox", power_box),
]



# ---------------------------------------------------------------- assemble
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
	for i, (name, fn) in enumerate(PROPS):
		_prop[0] = name
		fn()
	merged = {}
	for prop, role, bm in PIECES:
		key = (prop, role)
		if key not in merged:
			merged[key] = bmesh.new()
		me = bpy.data.meshes.new("_tmp")
		bm.to_mesh(me)
		merged[key].from_mesh(me)
		bpy.data.meshes.remove(me)
		bm.free()
	stats = {}
	order = [p[0] for p in PROPS]
	for (prop, role), bm in merged.items():
		me = bpy.data.meshes.new(prop + "_" + role)
		bm.to_mesh(me)
		bm.free()
		for p in me.polygons:
			p.use_smooth = False
		me.materials.append(mat(role))
		ob = bpy.data.objects.new(prop + "_" + role, me)
		ob.location.x = order.index(prop) * SPACING
		coll.objects.link(ob)
		stats[prop] = stats.get(prop, 0) + len(me.polygons)
	return stats


def export():
	bpy.ops.object.select_all(action="DESELECT")
	coll = bpy.data.collections[COLL]
	saved = {}
	for ob in coll.objects:
		saved[ob.name] = ob.location.copy()
		ob.select_set(True)
	bpy.context.view_layer.objects.active = coll.objects[0]
	os.makedirs(os.path.dirname(OUT), exist_ok=True)
	bpy.ops.export_scene.fbx(filepath=OUT, use_selection=True, object_types={"MESH"}, apply_scale_options="FBX_SCALE_UNITS", bake_anim=False)
	return {"path": OUT, "objects": len(saved)}
