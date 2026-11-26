"""Loadout terminal v3 (Range v5 plan §3, 2026-11-25): the owner asked for range loadout terminals that "look better and
more professional" than the v2 box in v5_rangekit.py. A faceted armoury kiosk:

    plinth with a chamfered toe + a recessed shadow-gap band
    body whose front leans back, side cheeks one size up (0.14 proud) with a big cut top-front corner
    a leaning screen head (15 deg) with an even grey margin, a charcoal bezel ring and a flat screen slab
    a lit gun bay lined as one piece, two faceted gun cradles on its back wall, a glow strip in a channel in its ceiling
    edge detail only: steel kick plate, status lamp on the right cheek, back exhaust slots, side vents,
    a conduit from a gland on the back panel through a faceted elbow into a floor flange

Run in a live Blender MCP instance (sys.path must hold this folder):

    build()    rebuilds the V5LoadoutV3 collection (Terminal3_Body/Trim/Steel/Glow/Screen)
    review()   adds the R15 stand-in, lights and cameras in V5LoadoutV3_Review and renders the two views
    export()   writes art-source/lobby/V5_LoadoutTerminal.fbx (same FBX settings as V5_RangeKit.fbx)

Units: 1 Blender unit = 1 stud. X = width, -Y = front, Z = up. Every mesh except the screen has its origin at the
terminal's floor centre (0, 0, 0); Terminal3_Screen's origin is the screen centre and its object rotation is the head
tilt, with the mesh axis-aligned in its own space (front = local -Y), so a SurfaceGui face lines up with the slab.
Each role is unioned per part before a 1-segment angle-limited bevel (gauntlet-model-joins: union before bevel).
"""
import math
import os

import bmesh
import bpy
from mathutils import Matrix, Vector

import v5_props as K

OUT = os.path.join(K.ROOT, "art-source", "lobby", "V5_LoadoutTerminal.fbx")
REF = os.path.join(K.ROOT, "vault", "02 Art", "References", "range-v5")
COLL = "V5LoadoutV3"
RCOLL = "V5LoadoutV3_Review"

# Preview colours only (Studio sets the real ones).
COLOURS = {
	"Body": (0x8E, 0x91, 0x96),
	"Trim": (0x2A, 0x2C, 0x31),
	"Steel": (0x5A, 0x5F, 0x67),
	"Glow": (0x2B, 0xD9, 0xA8),
	"Screen": (0x14, 0x17, 0x1B),
}
BEVEL = {"Body": 0.055, "Trim": 0.035, "Steel": 0.022, "Glow": 0.0, "Screen": 0.008}

# ---------------------------------------------------------------- dimensions
PX, PY0, PY1 = 2.35, -1.6, 1.5  # plinth half width, front, back
P_TOP = 0.48
BASE = 0.62  # body/cheek underside (shadow-gap band 0.46..0.64 between)
CX = 1.8  # core half width
KX = 2.08  # cheek outer half width
CHEEK = 0.14  # cheek offset (one size up)
# core side profile (y, z), front = -y
CORE = [
	(-1.15, BASE),
	(1.15, BASE),
	(1.15, 6.83),
	(0.90, 7.08),
	(-0.38, 7.08),  # big cut top-front corner (the cheeks repeat it 0.14 out)
	(-0.72, 6.88),  # top of the screen face
	(-1.30, 4.72),  # bottom of the screen face (chin)
	(-0.92, 4.52),  # top of the leaning front
]
FACE_A, FACE_B = Vector((0, -1.30, 4.72)), Vector((0, -0.72, 6.88))
TILT = math.atan2(FACE_B.y - FACE_A.y, FACE_B.z - FACE_A.z)  # lean back from vertical (~15 deg)
FACE_MID = (FACE_A + FACE_B) / 2
SCR_W, SCR_H = 3.04, 1.71  # 16:9
BEZ_W, BEZ_H = 3.28, 1.95  # charcoal bezel ring outer
BAY_X, BAY_Z0, BAY_Z1 = 1.35, 1.35, 4.20
BAY_BACK = -0.10
LINER_T = 0.09
HATCH = (1.25, 1.95, 5.2)  # back service hatch half width, bottom, top


def front_y(z):
	"""Core front face y at height z (the leaning part below the chin)."""
	(y0, z0), (y1, z1) = CORE[0], CORE[7]
	return y0 + (y1 - y0) * (z - z0) / (z1 - z0)


LEAN = math.atan2(CORE[7][0] - CORE[0][0], CORE[7][1] - CORE[0][1])


# ---------------------------------------------------------------- helpers
def obj_from(bm, name="_t"):
	me = bpy.data.meshes.new(name)
	bm.to_mesh(me)
	bm.free()
	ob = bpy.data.objects.new(name, me)
	bpy.context.scene.collection.objects.link(ob)
	return ob


def bm_from_eval(ob):
	dg = bpy.context.evaluated_depsgraph_get()
	ev = ob.evaluated_get(dg)
	out = bmesh.new()
	out.from_mesh(ev.to_mesh())
	ev.to_mesh_clear()
	return out


def kill(ob):
	me = ob.data
	bpy.data.objects.remove(ob)
	if me.users == 0:
		bpy.data.meshes.remove(me)


def solid(shells, cutters=(), bevel=0.0, angle=35.0):
	"""Union the shells (exact, self), subtract the cutters, then a 1-segment angle-limited bevel."""
	base = bmesh.new()
	for s in shells:
		me = bpy.data.meshes.new("_s")
		s.to_mesh(me)
		base.from_mesh(me)
		bpy.data.meshes.remove(me)
		s.free()
	a = obj_from(base, "_a")
	tmp = []
	if len(shells) > 1:
		m = a.modifiers.new("u", "BOOLEAN")
		m.operation, m.solver, m.use_self = "UNION", "EXACT", True
		m.operand_type = "COLLECTION"
		empty = bpy.data.collections.get("_empty") or bpy.data.collections.new("_empty")
		m.collection = empty
	for i, c in enumerate(cutters):  # one modifier per cutter: overlapping cutters in one operand break EXACT
		b = obj_from(c, "_b")
		b.hide_render = True
		tmp.append(b)
		m = a.modifiers.new("d%d" % i, "BOOLEAN")
		m.operation, m.solver, m.object = "DIFFERENCE", "EXACT", b
	if bevel > 0:
		m = a.modifiers.new("bev", "BEVEL")
		m.width, m.segments, m.limit_method = bevel, 1, "ANGLE"
		m.angle_limit = math.radians(angle)
		m.use_clamp_overlap = True
	out = bm_from_eval(a)
	kill(a)
	for t in tmp:
		kill(t)
	bmesh.ops.dissolve_degenerate(out, dist=1e-5, edges=out.edges)
	return out


def offset_poly(pts, d):
	"""Miter offset of a simple polygon outward by d."""
	n = len(pts)
	area = sum(pts[i][0] * pts[(i + 1) % n][1] - pts[(i + 1) % n][0] * pts[i][1] for i in range(n))
	sgn = 1 if area > 0 else -1  # CCW: outward normal of edge (dx, dy) is (dy, -dx)
	out = []
	for i in range(n):
		p0, p1, p2 = Vector(pts[i - 1]), Vector(pts[i]), Vector(pts[(i + 1) % n])
		e1, e2 = (p1 - p0).normalized(), (p2 - p1).normalized()
		n1 = Vector((e1.y, -e1.x)) * sgn
		n2 = Vector((e2.y, -e2.x)) * sgn
		m = n1 + n2
		out.append(tuple(p1 + m * (d / (1 + n1.dot(n2)))))
	return out


def yz(pts, x0, x1):
	return K.prism(pts, "YZ", x0, x1)


def xz(pts, y0, y1):
	return K.prism(pts, "XZ", y0, y1)


def rect(x0, x1, y0, y1):
	return [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]


def sweep(path, r, sides=8):
	"""Faceted tube through 3D points (planar path in a constant-x plane), mitred joints, open ends capped."""
	bm = bmesh.new()
	path = [Vector(p) for p in path]
	rings = []
	for i, p in enumerate(path):
		if i == 0:
			t, sc = (path[1] - p).normalized(), 1.0
		elif i == len(path) - 1:
			t, sc = (p - path[i - 1]).normalized(), 1.0
		else:
			ta, tb = (p - path[i - 1]).normalized(), (path[i + 1] - p).normalized()
			t = (ta + tb).normalized()
			sc = 1.0 / max(0.3, math.cos(ta.angle(tb) / 2))
		u = Vector((1, 0, 0))
		v = t.cross(u).normalized()
		ring = []
		for k in range(sides):
			a = math.pi / sides + 2 * math.pi * k / sides
			ring.append(bm.verts.new(p + u * (r * math.cos(a)) + v * (r * math.sin(a) * sc)))
		rings.append(ring)
	for ra, rb in zip(rings, rings[1:]):
		for k in range(sides):
			j = (k + 1) % sides
			bm.faces.new((ra[k], ra[j], rb[j], rb[k]))
	bm.faces.new(rings[0])
	bm.faces.new(list(reversed(rings[-1])))
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	return bm


def hexy(r, y0, y1, sides=6, rot=None, r_in=None):
	"""A faceted prism (or ring when r_in) along Y, centred on the origin's X/Z."""
	if r_in:
		bm = K.annulus(sides, r, r_in, y0, y1, rot=rot)
	else:
		bm = K.prism(K.ngon(0, 0, r, sides, rot), "XY", y0, y1)
	# prism/annulus are built along Z: swap Z -> Y (a mirror, so the winding is fixed after)
	K.xform(bm, Matrix(((1, 0, 0, 0), (0, 0, 1, 0), (0, 1, 0, 0), (0, 0, 0, 1))))
	bmesh.ops.reverse_faces(bm, faces=bm.faces)
	return bm


def at(bm, m):
	return K.xform(bm, m)


def face_frame():
	"""Matrix of the screen face: local x across, local +y into the head, local z up the face, origin on the face."""
	return Matrix.Translation(FACE_MID) @ Matrix.Rotation(-TILT, 4, "X")


# ---------------------------------------------------------------- parts
def body():
	core = yz(CORE, -CX, CX)
	cheek_pts = offset_poly(CORE, CHEEK)
	cheek_pts = [(y, BASE if z < BASE + 0.01 else z) for y, z in cheek_pts]
	cut = []
	shells = [core]
	for s in (-1, 1):
		x0, x1 = sorted((s * (CX - 0.02), s * KX))
		shells.append(yz(cheek_pts, x0, x1))
	# the gun bay (straight back, chamfered corners)
	cut.append(xz(K.cham_rect(-BAY_X, BAY_X, BAY_Z0, BAY_Z1, 0.18), -3.0, BAY_BACK))
	# screen recess for the bezel ring
	F = face_frame()
	cut.append(at(K.box(-BEZ_W / 2 - 0.005, BEZ_W / 2 + 0.005, -0.6, 0.10, -BEZ_H / 2 - 0.005, BEZ_H / 2 + 0.005), F))
	# kick-plate pocket (follows the lean)
	kz = 0.83
	KP = Matrix.Translation((0, front_y(kz), kz)) @ Matrix.Rotation(-LEAN, 4, "X")
	cut.append(at(K.box(-1.46, 1.46, -0.5, 0.04, -0.175, 0.175), KP))
	# status lamp pocket on the right cheek front
	lz = 3.95
	lx = (CX + KX) / 2
	cheek_front = front_y(lz) - CHEEK / math.cos(LEAN)
	LP = Matrix.Translation((lx, cheek_front, lz)) @ Matrix.Rotation(-LEAN, 4, "X")
	cut.append(at(hexy(0.10, -0.5, 0.035, sides=6, rot=0), LP))
	# back exhaust slots
	for i in range(4):
		z = 5.55 + i * 0.24
		cut.append(K.box(-1.1, 1.1, 1.15 - 0.07, 2.0, z - 0.05, z + 0.05))
	# service hatch on the back panel: a cut groove outline (bolted at its corners, see steel())
	ring = solid([K.box(-HATCH[0], HATCH[0], 1.15 - 0.04, 2.0, HATCH[1], HATCH[2])], [K.box(-HATCH[0] + 0.06, HATCH[0] - 0.06, 0.0, 3.0, HATCH[1] + 0.06, HATCH[2] - 0.06)])
	cut.append(ring)
	# side vents low on each cheek, toward the back
	for s in (-1, 1):
		for i in range(3):
			z = 1.05 + i * 0.22
			x0, x1 = sorted((s * (KX - 0.06), s * (KX + 1)))
			cut.append(K.box(x0, x1, 0.15, 0.85, z - 0.05, z + 0.05))
	return solid(shells, cut, BEVEL["Body"], angle=30)


def trim():
	parts = []
	# plinth: straight base, chamfered toe all round, and the inset shadow-gap band the body sits on
	plinth = K.loft(
		[
			(K.cham_rect(-PX, PX, PY0, PY1, 0.22), 0.0),
			(K.cham_rect(-PX, PX, PY0, PY1, 0.22), 0.28),
			(K.cham_rect(-PX + 0.16, PX - 0.16, PY0 + 0.2, PY1 - 0.1, 0.12), P_TOP),
		]
	)
	band = K.box(-KX + 0.1, KX - 0.1, -1.15 - CHEEK + 0.1, 1.15 + CHEEK - 0.1, P_TOP - 0.02, BASE + 0.02)
	parts.append(solid([plinth, band], (), BEVEL["Trim"]))
	# bay liner: one piece, front edge 0.05 behind the leaning body face
	outer = xz(K.cham_rect(-BAY_X + 0.005, BAY_X - 0.005, BAY_Z0 + 0.005, BAY_Z1 - 0.005, 0.175), -2.0, BAY_BACK - 0.005)
	inner = xz(K.cham_rect(-BAY_X + LINER_T, BAY_X - LINER_T, BAY_Z0 + LINER_T, BAY_Z1 - LINER_T, 0.12), -3.0, BAY_BACK - LINER_T)
	zlo, zhi = -1.0, 6.0
	face_cut = yz([(-3.0, zlo), (front_y(zlo) + 0.05, zlo), (front_y(zhi) + 0.05, zhi), (-3.0, zhi)], -3, 3)
	gy0, gy1 = -0.80, -0.44  # glow channel in the bay ceiling
	ch = K.box(-1.1, 1.1, gy0, gy1, BAY_Z1 - LINER_T - 0.05, BAY_Z1 - 0.03)
	parts.append(solid([outer], [inner, face_cut, ch], BEVEL["Trim"]))
	# bezel ring in the screen recess, its face 0.03 behind the grey face
	F = face_frame()
	ring_o = K.box(-BEZ_W / 2, BEZ_W / 2, 0.03, 0.10, -BEZ_H / 2, BEZ_H / 2)
	ring_i = K.box(-SCR_W / 2 - 0.01, SCR_W / 2 + 0.01, -1.0, 1.0, -SCR_H / 2 - 0.01, SCR_H / 2 + 0.01)
	parts.append(at(solid([ring_o], [ring_i], 0.025), F))
	return parts


def steel():
	parts = []
	# gun cradles on the bay's back wall: mount plate seated into the liner + a hook with a gusset heel and a lip
	wall = BAY_BACK - LINER_T  # liner inner back face
	# side profile of a cradle arm: gusset heel, a faceted V saddle for the gun, a raised front lip
	hook = [
		(wall + 0.02, 2.30),
		(wall + 0.02, 2.86),
		(-0.34, 2.86),
		(-0.40, 2.76),  # saddle
		(-0.50, 2.76),
		(-0.56, 2.86),
		(-0.56, 3.00),
		(-0.60, 3.05),  # lip top, chamfered
		(-0.66, 3.05),
		(-0.70, 3.00),
		(-0.70, 2.70),
		(-0.62, 2.60),
		(-0.42, 2.60),
	]
	for cx in (-0.8, 0.8):
		plate = K.box(cx - 0.22, cx + 0.22, wall - 0.07, wall + 0.02, 2.16, 3.16)
		arm = yz(hook, cx - 0.13, cx + 0.13)
		parts.append(solid([plate, arm], (), BEVEL["Steel"]))
	# kick plate in its pocket, 0.03 proud
	kz = 0.83
	KP = Matrix.Translation((0, front_y(kz), kz)) @ Matrix.Rotation(-LEAN, 4, "X")
	parts.append(at(solid([K.box(-1.44, 1.44, -0.03, 0.04, -0.16, 0.16)], (), BEVEL["Steel"]), KP))
	# status lamp bezel ring, seated in its pocket
	lz = 3.95
	lx = (CX + KX) / 2
	cheek_front = front_y(lz) - CHEEK / math.cos(LEAN)
	LP = Matrix.Translation((lx, cheek_front, lz)) @ Matrix.Rotation(-LEAN, 4, "X")
	parts.append(at(solid([hexy(0.095, -0.05, 0.035, sides=6, rot=0, r_in=0.06)], (), 0.012), LP))
	# hatch bolts, inside the groove outline's corners
	for bx in (-HATCH[0] + 0.17, HATCH[0] - 0.17):
		for bz in (HATCH[1] + 0.17, HATCH[2] - 0.17):
			bolt = K.prism(K.ngon(0, 0, 0.055, 6), "XY", 0.0, 0.05, taper=(1.0, 0.72))  # tapered head, no blunt top
			parts.append(at(bolt, Matrix.Translation((bx, 1.13, bz)) @ Matrix.Rotation(-math.pi / 2, 4, "X")))
	# conduit: gland on the back panel -> faceted elbow -> floor flange behind the plinth
	gx, gz, gy = 0.95, 1.45, 1.15
	gland = [
		at(hexy(0.2, gy - 0.03, gy + 0.07, sides=6), Matrix.Translation((gx, 0, gz))),
		at(hexy(0.145, gy + 0.07, gy + 0.2, sides=8), Matrix.Translation((gx, 0, gz))),
	]
	ey = 1.84
	tube = sweep([(gx, gy + 0.12, gz), (gx, ey - 0.12, gz), (gx, ey, gz - 0.12), (gx, ey, 0.12)], 0.095, 8)
	floor = [
		K.prism(K.ngon(gx, ey, 0.21, 8), "XY", 0.0, 0.06),
		K.prism(K.ngon(gx, ey, 0.145, 8), "XY", 0.06, 0.2),
	]
	parts.append(solid(gland + [tube] + floor, (), BEVEL["Steel"]))
	return parts


def glow():
	parts = []
	gy0, gy1 = -0.80, -0.44
	parts.append(K.box(-1.08, 1.08, gy0 + 0.02, gy1 - 0.02, BAY_Z1 - LINER_T + 0.02, BAY_Z1 - 0.04))
	lz = 3.95
	lx = (CX + KX) / 2
	cheek_front = front_y(lz) - CHEEK / math.cos(LEAN)
	LP = Matrix.Translation((lx, cheek_front, lz)) @ Matrix.Rotation(-LEAN, 4, "X")
	parts.append(at(hexy(0.058, -0.02, 0.03, sides=6, rot=0), LP))
	return parts


def screen():
	"""Axis-aligned slab in its own space (front = local -Y); the object carries the tilt."""
	return solid([K.box(-SCR_W / 2, SCR_W / 2, 0.0, 0.035, -SCR_H / 2, SCR_H / 2)], (), BEVEL["Screen"])


# ---------------------------------------------------------------- build / review / export
def _lin(c):
	c = c / 255
	return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def _mat(role):
	name = "Term3_" + role
	m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
	r, g, b = (_lin(c) for c in COLOURS[role])
	m.diffuse_color = (r, g, b, 1)
	m.use_nodes = True
	p = m.node_tree.nodes.get("Principled BSDF")
	if p:
		p.inputs["Base Color"].default_value = (r, g, b, 1)
		p.inputs["Roughness"].default_value = 0.7 if role != "Steel" else 0.5
		p.inputs["Metallic"].default_value = 0.35 if role == "Steel" else 0.0
		if role == "Glow":
			p.inputs["Emission Color"].default_value = (r, g, b, 1)
			p.inputs["Emission Strength"].default_value = 4.0
		if role == "Screen":
			p.inputs["Roughness"].default_value = 0.3
	return m


def _join(bms):
	out = bmesh.new()
	for b in bms:
		me = bpy.data.meshes.new("_j")
		b.to_mesh(me)
		out.from_mesh(me)
		bpy.data.meshes.remove(me)
		b.free()
	return out


def build():
	coll = bpy.data.collections.get(COLL)
	if coll:
		for o in list(coll.objects):
			kill(o)
	else:
		coll = bpy.data.collections.new(COLL)
		bpy.context.scene.collection.children.link(coll)
	roles = {
		"Body": body(),
		"Trim": _join(trim()),
		"Steel": _join(steel()),
		"Glow": _join(glow()),
		"Screen": screen(),
	}
	stats = {}
	for role, bm in roles.items():
		name = "Terminal3_" + role
		me = bpy.data.meshes.new(name)
		bm.to_mesh(me)
		bm.free()
		for p in me.polygons:
			p.use_smooth = False
		me.materials.append(_mat(role))
		ob = bpy.data.objects.new(name, me)
		if role == "Screen":
			ob.matrix_world = face_frame() @ Matrix.Translation((0, 0.065, 0))
		coll.objects.link(ob)
	bpy.context.view_layer.update()
	for ob in coll.objects:
		tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
		ws = [ob.matrix_world @ v.co for v in ob.data.vertices]
		lo = Vector((min(w.x for w in ws), min(w.y for w in ws), min(w.z for w in ws)))
		hi = Vector((max(w.x for w in ws), max(w.y for w in ws), max(w.z for w in ws)))
		stats[ob.name] = {
			"tris": tris,
			"size": [round(v, 3) for v in (hi - lo)],
			"centre": [round(v, 3) for v in ((hi + lo) / 2)],
			"origin": [round(v, 3) for v in ob.matrix_world.translation],
		}
	stats["total_tris"] = sum(v["tris"] for v in stats.values())
	stats["tilt_deg"] = round(math.degrees(TILT), 2)
	return stats


def _box_figure(coll):
	"""R15-proportioned block stand-in, 5.5 studs tall, standing 2.6 studs in front of the terminal."""
	bm = bmesh.new()
	for x0, x1, y0, y1, z0, z1 in [
		(-0.45, -0.05, -0.2, 0.2, 0.0, 2.1),  # legs
		(0.05, 0.45, -0.2, 0.2, 0.0, 2.1),
		(-0.5, 0.5, -0.25, 0.25, 2.1, 4.1),  # torso
		(-0.85, -0.52, -0.18, 0.18, 2.2, 4.05),  # arms
		(0.52, 0.85, -0.18, 0.18, 2.2, 4.05),
		(-0.33, 0.33, -0.3, 0.3, 4.15, 5.5),  # head
	]:
		tmp = K.box(x0, x1, y0, y1, z0, z1, 0.03)
		me = bpy.data.meshes.new("_f")
		tmp.to_mesh(me)
		bm.from_mesh(me)
		bpy.data.meshes.remove(me)
		tmp.free()
	me = bpy.data.meshes.new("R15_StandIn")
	bm.to_mesh(me)
	bm.free()
	m = bpy.data.materials.get("Term3_Figure") or bpy.data.materials.new("Term3_Figure")
	m.use_nodes = True
	m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.75, 0.45, 0.2, 1)
	me.materials.append(m)
	ob = bpy.data.objects.new("R15_StandIn", me)
	ob.location = (-3.1, -2.6, 0)
	ob.rotation_euler = (0, 0, math.radians(25))
	coll.objects.link(ob)


def review(shots=("front34", "joins", "back34", "bay")):
	rc = bpy.data.collections.get(RCOLL)
	if rc:
		for o in list(rc.objects):
			if o.type == "MESH":
				kill(o)
			else:
				bpy.data.objects.remove(o)
	else:
		rc = bpy.data.collections.new(RCOLL)
		bpy.context.scene.collection.children.link(rc)
	_box_figure(rc)
	# floor
	fbm = K.box(-14, 14, -14, 14, -0.05, 0.0)
	fme = bpy.data.meshes.new("Floor")
	fbm.to_mesh(fme)
	fbm.free()
	fm = bpy.data.materials.get("Term3_Floor") or bpy.data.materials.new("Term3_Floor")
	fm.use_nodes = True
	fm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.11, 0.115, 0.12, 1)
	fme.materials.append(fm)
	fo = bpy.data.objects.new("Floor", fme)
	rc.objects.link(fo)
	# lights
	def light(name, kind, loc, rot, energy, size=4.0, col=(1, 1, 1)):
		ld = bpy.data.lights.new(name, kind)
		ld.energy = energy
		ld.color = col
		if kind == "AREA":
			ld.size = size
		o = bpy.data.objects.new(name, ld)
		o.location = loc
		o.rotation_euler = [math.radians(a) for a in rot]
		rc.objects.link(o)

	light("Key", "SUN", (0, 0, 10), (50, 0, -35), 2.2)
	light("Fill", "AREA", (6, -8, 6), (65, 0, 40), 250, 8, (0.85, 0.9, 1.0))
	light("Rim", "AREA", (-5, 7, 8), (-50, 0, 210), 900, 6)
	light("BayLight", "POINT", (0, -0.6, 3.9), (0, 0, 0), 25, 0.2, (0.17, 0.85, 0.66))
	sc = bpy.context.scene
	w = sc.world or bpy.data.worlds.new("World")
	sc.world = w
	w.use_nodes = True
	w.node_tree.nodes["Background"].inputs["Color"].default_value = (0.36, 0.38, 0.41, 1)
	w.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.35
	sc.render.engine = "BLENDER_EEVEE"
	sc.render.resolution_x, sc.render.resolution_y = 1400, 1400
	sc.view_settings.view_transform = "AgX"
	cams = {
		"front34": ((5.6, -10.5, 5.4), (0.0, 0.0, 3.6), 40),
		"joins": ((3.2, -3.4, 6.2), (0.9, -0.9, 5.0), 35),
		"back34": ((-6.5, 9.5, 6.8), (0.2, 0.5, 3.4), 40),
		"bay": ((-1.6, -4.6, 3.3), (0.0, -0.6, 2.9), 35),
	}
	os.makedirs(REF, exist_ok=True)
	out = []
	for name in shots:
		loc, tgt, lens = cams[name]
		cd = bpy.data.cameras.new("Cam_" + name)
		cd.lens = lens
		co = bpy.data.objects.new("Cam_" + name, cd)
		co.location = loc
		d = Vector(tgt) - Vector(loc)
		co.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
		rc.objects.link(co)
		sc.camera = co
		fig = bpy.data.objects["R15_StandIn"]
		fig.hide_render = name in ("joins", "bay")
		path = os.path.join(REF, "terminal3_" + name + ".png")
		sc.render.filepath = path
		bpy.ops.render.render(write_still=True)
		out.append(path)
	return {"renders": out}


def export():
	bpy.ops.object.select_all(action="DESELECT")
	coll = bpy.data.collections[COLL]
	for ob in coll.objects:
		ob.select_set(True)
	bpy.context.view_layer.objects.active = coll.objects[0]
	os.makedirs(os.path.dirname(OUT), exist_ok=True)
	bpy.ops.export_scene.fbx(filepath=OUT, use_selection=True, object_types={"MESH"}, apply_scale_options="FBX_SCALE_UNITS", bake_anim=False)
	return {"path": OUT}
