"""Season 1 Goodie Bag for Draft Duels: a chunky faceted gift sack tied at the neck.

Run in a live Blender MCP instance (exec this file with {"VERSION": "v01"} in globals), or headless:
    blender --background --factory-startup --python tools/blender/crates/build_goodie_bag.py -- v01

Units: 1 Blender unit = 1 stud. X = width, -Y = front, Z = up, origin = base centre.
Style (gauntlet-build-style / gauntlet-model-joins): flat faceted only (10-sided sack, no smooth
faces, no subdivision), chamfers by an angle-limited 1-segment bevel applied AFTER an exact
union of each part's shells, every detail seated 0.02+ into what carries it.

Parts (Group_Role naming, so Shared/CrateLook paints them from a Config/Crates tier):
    Sack_Body      the sack (pleats gather into the neck)
    Sack_Frame     the front patch plate
    Sack_Light     the hem band and the pixel star on the patch
    Sack_Interior  the dark neck cap (hidden until the top pops off)
    Top_Frame      the flared, scalloped ruffle above the tie (hollow)
    Top_Interior   the dark floor inside the ruffle
    Top_Hardware   the tie band, knot, bow loops, tails, tag cord and tag plate
    Top_Gem        the raised star on the tag
Groups: Sack pivots at the base centre; Top pivots at the neck (it can lift off in an opening).
"""

import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

ROOT = r"C:\Users\charl\Documents\GauntletGame\GlitchedGauntletGame"
_g = globals()
VERSION = _g.get("VERSION") or (sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "v01")
OUT_DIR = os.path.join(ROOT, "art-source", "crates", "GoodieBag")
BLEND = os.path.join(OUT_DIR, f"GoodieBag_{VERSION}.blend")
FBX = os.path.join(OUT_DIR, f"GoodieBag_{VERSION}.fbx")
OUT_JSON = os.path.join(OUT_DIR, f"GoodieBag_{VERSION}.json")
REVIEW_DIR = os.path.join(OUT_DIR, "review", VERSION)
CARD_PNG = os.path.join(ROOT, "art-source", "ui", "shop", "bags", "bag_season1.png")
COLL = "GOODIEBAG"

N = 10  # sack facets
A0 = math.radians(-90 + 18)  # vertex 0 angle: a face is centred on the front (-Y)
SCALE = 1.6 / 1.52  # authored ~1.52 tall, delivered 1.6 studs

PALETTE = {
	"Body": ("2C1650", 0.0),
	"Frame": ("47297C", 0.0),
	"Hardware": ("FFC83D", 0.0),
	"Light": ("3FE0F2", 1.3),
	"Gem": ("F03CA8", 1.3),
	"Interior": ("140A24", 0.0),
}

# sack profile: (z, radius, pleat) - pleat pulls the odd vertices in (gathered fabric at the neck)
# (rings sharing a pleat value give planar faces: the patch sits on 3..4, the tag on 5..6)
SACK = [
	(0.00, 0.40, 1.0),
	(0.05, 0.53, 1.0),
	(0.17, 0.635, 0.97),
	(0.38, 0.675, 0.95),
	(0.62, 0.65, 0.95),
	(0.82, 0.56, 0.90),
	(0.98, 0.42, 0.90),
	(1.09, 0.29, 0.78),
	(1.18, 0.20, 0.84),
]
NECK_Z = 1.16
BAND = (1.09, 1.23, 0.315, 0.27)  # z0, z1, r0, r1
# ruffle outer profile (z, r) and the scalloped rim: even verts high/out, odd low/in
# the ruffle has 16 facets with deep pleats, so it reads as gathered fabric, not a pot rim
RN = 16
RA0 = math.radians(-90 + 180 / 16)
RUFFLE = [(1.15, 0.215, 1.0), (1.23, 0.255, 1.0), (1.31, 0.345, 0.9), (1.41, 0.43, 0.82)]
RIM = (1.52, 0.47, 1.46, 0.8)  # even z, even r, odd z, odd/even r
RUFFLE_INNER = [(1.36, 0.27, 1.0), (1.41, 0.385, 0.82)]
RUFFLE_FLOOR = 1.36


def hex_lin(h):
	c = [int(h[i : i + 2], 16) / 255 for i in (0, 2, 4)]
	return tuple(((v + 0.055) / 1.055) ** 2.4 if v > 0.04045 else v / 12.92 for v in c) + (1.0,)


def make_mat(role):
	name = f"GoodieBag_{role}"
	m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
	hexv, emit = PALETTE[role]
	lin = hex_lin(hexv)
	m.diffuse_color = lin
	m.use_nodes = True
	b = m.node_tree.nodes.get("Principled BSDF")
	b.inputs["Base Color"].default_value = lin
	b.inputs["Roughness"].default_value = 0.4 if role == "Hardware" else 0.62
	b.inputs["Metallic"].default_value = 0.0
	b.inputs["Emission Color"].default_value = lin
	b.inputs["Emission Strength"].default_value = emit
	return m


# --- shape helpers ----------------------------------------------------------------------------


def ang(k):
	return A0 + k * 2 * math.pi / N


def ring(r, z, pleat=1.0, zodd=None, n=N, a0=None):
	out = []
	for k in range(n):
		a = (a0 if a0 is not None else A0) + k * 2 * math.pi / n
		rr = r * (pleat if k % 2 else 1.0)
		zz = zodd if (zodd is not None and k % 2) else z
		out.append((rr * math.cos(a), rr * math.sin(a), zz))
	return out


def loft(rings, cap0=True, cap1=True):
	bm = bmesh.new()
	vs = [[bm.verts.new(p) for p in r] for r in rings]
	n = len(vs[0])
	if cap0:
		bm.faces.new(list(reversed(vs[0])))
	if cap1:
		bm.faces.new(vs[-1])
	for a, b in zip(vs, vs[1:]):
		for i in range(n):
			j = (i + 1) % n
			bm.faces.new((a[i], a[j], b[j], b[i]))
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	return bm


def shell(outer, inner):
	"""Hollow open-top shell: outer rings bottom->top, inner rings bottom->top (same count)."""
	bm = bmesh.new()
	o = [[bm.verts.new(p) for p in r] for r in outer]
	i_ = [[bm.verts.new(p) for p in r] for r in inner]
	n = len(o[0])
	bm.faces.new(list(reversed(o[0])))
	bm.faces.new(i_[0])  # inner floor
	for rs in (o, i_):
		for a, b in zip(rs, rs[1:]):
			for k in range(n):
				j = (k + 1) % n
				bm.faces.new((a[k], a[j], b[j], b[k]))
	top_o, top_i = o[-1], i_[-1]
	for k in range(n):
		j = (k + 1) % n
		bm.faces.new((top_o[k], top_o[j], top_i[j], top_i[k]))
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	return bm


def cham_poly(w, h, c, cut=0.0):
	"""Rectangle centred at 0 with chamfer c on 3 corners and a bigger 45deg cut on the top-right."""
	x0, x1, y0, y1 = -w / 2, w / 2, -h / 2, h / 2
	k = max(cut, c)
	return [(x0 + c, y0), (x1 - c, y0), (x1, y0 + c), (x1, y1 - k), (x1 - k, y1), (x0 + c, y1), (x0, y1 - c), (x0, y0 + c)]


def plate(pts2, t0, t1, frame):
	"""Extrude a 2D outline (u, v) between depths t0..t1 along the frame's local Z."""
	bm = bmesh.new()
	a = [bm.verts.new(frame @ Vector((u, v, t0))) for u, v in pts2]
	b = [bm.verts.new(frame @ Vector((u, v, t1))) for u, v in pts2]
	bm.faces.new(a)
	bm.faces.new(list(reversed(b)))
	n = len(pts2)
	for i in range(n):
		j = (i + 1) % n
		bm.faces.new((a[i], a[j], b[j], b[i]))
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	return bm


def box(c, size, frame=None, cham=0.0):
	sx, sy, sz = size
	pts = cham_poly(sx, sy, cham) if cham else [(-sx / 2, -sy / 2), (sx / 2, -sy / 2), (sx / 2, sy / 2), (-sx / 2, sy / 2)]
	f = (frame or Matrix.Identity(4)).copy()
	f.translation = Vector(c)
	return plate(pts, -sz / 2, sz / 2, f)


def prism_between(p0, p1, r, sides=6):
	p0, p1 = Vector(p0), Vector(p1)
	axis = (p1 - p0).normalized()
	q = axis.to_track_quat("Z", "Y")
	f = q.to_matrix().to_4x4()
	f.translation = p0
	pts = [(r * math.cos(2 * math.pi * k / sides + math.pi / sides), r * math.sin(2 * math.pi * k / sides + math.pi / sides)) for k in range(sides)]
	return plate(pts, 0.0, (p1 - p0).length, f)


def frame_from(origin, normal, up_hint=Vector((0, 0, 1))):
	"""Local frame: Z = normal (out of the surface), Y = up along the surface."""
	z = Vector(normal).normalized()
	x = up_hint.cross(z)
	if x.length < 1e-4:
		x = Vector((1, 0, 0))
	x.normalize()
	y = z.cross(x)
	m = Matrix((x, y, z)).transposed().to_4x4()
	m.translation = Vector(origin)
	return m


def star(r_out, r_in, pts=5, rot=math.pi / 2):
	out = []
	for k in range(pts * 2):
		r = r_out if k % 2 == 0 else r_in
		a = rot + k * math.pi / pts
		out.append((r * math.cos(a), r * math.sin(a)))
	return out


# --- parts ------------------------------------------------------------------------------------


def sack_body():
	rings = [ring(r, z, p) for z, r, p in SACK]
	return [loft(rings)]


def sack_bvh():
	bm = loft([ring(r, z, p) for z, r, p in SACK])
	bmesh.ops.triangulate(bm, faces=list(bm.faces))
	t = BVHTree.FromBMesh(bm)
	bm.free()
	return t


def surface(bvh, x, z, from_front=True):
	"""Front surface point of the sack at (x, z) seen from -Y."""
	hit = bvh.ray_cast(Vector((x, -3.0, z)), Vector((0, 1, 0)))
	return hit[0], hit[1]


def face_plane(lo, hi, k, t=0.5):
	"""A planar sack facet between rings lo..hi, face k (between vertices k and k+1):
	returns (point at height fraction t, outward normal, up-along-the-face unit vector)."""
	rl = ring(SACK[lo][1], SACK[lo][0], SACK[lo][2])
	rh = ring(SACK[hi][1], SACK[hi][0], SACK[hi][2])
	j = (k + 1) % N
	a, b, c, d = Vector(rl[k]), Vector(rl[j]), Vector(rh[j]), Vector(rh[k])
	bot, top = (a + b) / 2, (c + d) / 2
	up = (top - bot).normalized()
	nrm = (b - a).cross(d - a).normalized()
	if nrm.dot(Vector((bot.x, bot.y, 0))) < 0:
		nrm = -nrm
	return bot.lerp(top, t), nrm, up


def front_frame():
	pt, nrm, up = face_plane(3, 4, N - 1, 0.5)
	return frame_from(pt, nrm, up)


def sack_frame():
	return [plate(cham_poly(0.30, 0.30, 0.03, cut=0.075), -0.025, 0.016, front_frame())]


PIXEL_STAR = [
	"...X...",
	"...X...",
	"..XXX..",
	"XXXXXXX",
	"..XXX..",
	"...X...",
	"...X...",
]


def sack_light():
	# a four-point sparkle (with a small one beside it) on the patch, buried 0.006 into its face
	f = front_frame()
	big = Matrix.Translation(f @ Vector((-0.02, -0.02, 0.0)) - f.translation) @ f
	small = Matrix.Translation(f @ Vector((0.085, 0.085, 0.0)) - f.translation) @ f
	return [plate(star(0.105, 0.03, pts=4), 0.010, 0.03, big), plate(star(0.042, 0.013, pts=4), 0.010, 0.026, small)]


def sack_interior():
	# a dark cap seated on the neck top, inside the band and ruffle until the top lifts off
	return [loft([ring(0.185, 1.17), ring(0.175, 1.20)])]


def ruffle_rings():
	outer = [ring(r, z, pl, n=RN, a0=RA0) for z, r, pl in RUFFLE]
	ez, er, oz, ratio = RIM
	outer.append(ring(er, ez, ratio, zodd=oz, n=RN, a0=RA0))
	inner = [ring(r, z, pl, n=RN, a0=RA0) for z, r, pl in RUFFLE_INNER]
	inner.append(ring(er - 0.04, ez - 0.004, (er * ratio - 0.03) / (er - 0.04), zodd=oz - 0.004, n=RN, a0=RA0))
	return outer, inner


def top_frame():
	outer, inner = ruffle_rings()
	bm = bmesh.new()
	o = [[bm.verts.new(p) for p in r] for r in outer]
	i_ = [[bm.verts.new(p) for p in r] for r in inner]
	bm.faces.new(list(reversed(o[0])))
	bm.faces.new(i_[0])
	for rs in (o, i_):
		for a, b in zip(rs, rs[1:]):
			for k in range(RN):
				j = (k + 1) % RN
				bm.faces.new((a[k], a[j], b[j], b[k]))
	for k in range(RN):
		j = (k + 1) % RN
		bm.faces.new((o[-1][k], o[-1][j], i_[-1][j], i_[-1][k]))
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	return [bm]


def top_interior():
	# the dark floor inside the ruffle: its rim buried between the inner and outer walls
	return [loft([ring(0.32, 1.345, 0.92, n=RN, a0=RA0), ring(0.33, 1.38, 0.92, n=RN, a0=RA0)])]


def top_hardware(bvh):
	parts = []
	z0, z1, r0, r1 = BAND
	# tie band: a solid 10-sided collar wrapping the neck
	parts.append(loft([ring(r0 - 0.01, z0), ring(r0, z0 + 0.02), ring(r1, z1 - 0.02), ring(r1 - 0.012, z1)]))
	apo = (r0 + r1) / 2 * math.cos(math.pi / N)
	kz = (z0 + z1) / 2
	# knot: seated 0.035 into the band's front facet
	parts.append(box((0, -apo - 0.035, kz), (0.15, 0.17, 0.11), Matrix(((1, 0, 0, 0), (0, 0, 1, 0), (0, -1, 0, 0), (0, 0, 0, 1))), cham=0.03))
	# bow loops: flat octagon rings, their inner end buried in the knot, angled back along the band
	for s in (-1, 1):
		ow, oh, iw, ih = 0.25, 0.155, 0.12, 0.055
		outer = cham_poly(ow, oh, 0.04)
		inner = cham_poly(iw, ih, 0.015)
		# the band's next facet runs back at 36deg: the loop lies along it, its back buried 0.02
		bx = 0.15
		face_y = -0.276 + (bx - 0.09) * math.tan(math.radians(36))
		f = Matrix.Translation((s * bx, face_y - 0.01, kz + 0.035)) @ Matrix.Rotation(s * math.radians(36), 4, "Z") @ Matrix.Rotation(-s * math.radians(22), 4, "Y")
		f = f @ Matrix(((1, 0, 0, 0), (0, 0, 1, 0), (0, -1, 0, 0), (0, 0, 0, 1)))
		bm = bmesh.new()
		t0, t1 = -0.03, 0.03
		of = [bm.verts.new(f @ Vector((u, v, t0))) for u, v in outer]
		ob = [bm.verts.new(f @ Vector((u, v, t1))) for u, v in outer]
		if_ = [bm.verts.new(f @ Vector((u, v, t0))) for u, v in inner]
		ib = [bm.verts.new(f @ Vector((u, v, t1))) for u, v in inner]
		n = len(outer)
		for i in range(n):
			j = (i + 1) % n
			bm.faces.new((of[i], of[j], if_[j], if_[i]))
			bm.faces.new((ib[i], ib[j], ob[j], ob[i]))
			bm.faces.new((of[i], ob[i], ob[j], of[j]))
			bm.faces.new((if_[j], ib[j], ib[i], if_[i]))
		bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
		parts.append(bm)
	# tails: V-notched ribbons from the knot down onto the shoulder (end resting on the sack)
	for s in (-1, 1):
		top = Vector((s * 0.035, -apo - 0.05, kz - 0.04))
		ex, ez = s * 0.11, 0.99
		hit, nrm = surface(bvh, ex, ez)
		end = hit + nrm * 0.012
		d = end - top
		length = d.length
		ydir = -d.normalized()  # local +Y points up the tail
		zdir = (nrm + Vector((0, -1, 0))).normalized()
		xdir = ydir.cross(zdir).normalized()
		zdir = xdir.cross(ydir).normalized()
		f = Matrix((xdir, ydir, zdir)).transposed().to_4x4()
		f.translation = end
		w = 0.075
		pts = [(-w / 2, 0.0), (0.0, 0.035), (w / 2, 0.0), (w / 2, length + 0.02), (-w / 2, length + 0.02)]
		parts.append(plate(pts, -0.018, 0.018, f))
	# tag: a cut-corner plate resting on the planar front-right shoulder facet, on a cord from the band
	mid, nrm, slope = face_plane(5, 6, 0, 0.55)
	ta = math.atan2(mid.y, mid.x)
	f = frame_from(mid, nrm, slope)
	tag_w, tag_h = 0.19, 0.2
	parts.append(plate(cham_poly(tag_w, tag_h, 0.025, cut=0.06), -0.018, 0.02, f))
	# cord: band -> tag top edge, buried at both ends
	tag_top = f @ Vector((-0.03, tag_h / 2 - 0.02, 0.0))
	cord_top = Vector((r0 * 0.88 * math.cos(ta), r0 * 0.88 * math.sin(ta), z0 + 0.04))
	parts.append(prism_between(cord_top, tag_top, 0.018, sides=6))
	return parts, f


def top_gem(tag_frame):
	return [plate(star(0.062, 0.027), 0.012, 0.034, tag_frame)]


# --- build ------------------------------------------------------------------------------------


def bm_to_obj(name, bms, coll):
	me = bpy.data.meshes.new(name + "_shell0")
	ob = None
	objs = []
	for i, bm in enumerate(bms):
		m = bpy.data.meshes.new(f"{name}_s{i}")
		bm.to_mesh(m)
		bm.free()
		o = bpy.data.objects.new(f"{name}_s{i}", m)
		coll.objects.link(o)
		objs.append(o)
	bpy.data.meshes.remove(me)
	return objs


def union_bevel(name, bms, coll, scratch, bevel=0.014):
	shells = bm_to_obj(name, bms, scratch)
	base = shells[0]
	if len(shells) > 1:
		ops = bpy.data.collections.new(name + "_ops")
		scratch.children.link(ops)
		for o in shells[1:]:
			scratch.objects.unlink(o)
			ops.objects.link(o)
		mod = base.modifiers.new("Union", "BOOLEAN")
		mod.operation = "UNION"
		mod.solver = "EXACT"
		mod.use_self = True
		mod.operand_type = "COLLECTION"
		mod.collection = ops
	if bevel > 0:
		bv = base.modifiers.new("Bevel", "BEVEL")
		bv.width = bevel
		bv.segments = 1
		bv.limit_method = "ANGLE"
		bv.angle_limit = math.radians(40)
		bv.harden_normals = False
	dg = bpy.context.evaluated_depsgraph_get()
	ev = base.evaluated_get(dg)
	me = bpy.data.meshes.new_from_object(ev)
	bm = bmesh.new()
	bm.from_mesh(me)
	bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
	bmesh.ops.triangulate(bm, faces=list(bm.faces))
	bm.to_mesh(me)
	bm.free()
	me.name = name
	for o in shells:
		bpy.data.objects.remove(o)
	if len(shells) > 1:
		bpy.data.collections.remove(ops)
	return me


def check(me):
	bm = bmesh.new()
	bm.from_mesh(me)
	nm = sum(1 for e in bm.edges if not e.is_manifold)
	islands = 0
	seen = set()
	for v in bm.verts:
		if v.index in seen:
			continue
		islands += 1
		stack = [v]
		while stack:
			x = stack.pop()
			if x.index in seen:
				continue
			seen.add(x.index)
			stack.extend(e.other_vert(x) for e in x.link_edges)
	bm.free()
	return {"tris": len(me.polygons), "non_manifold": nm, "islands": islands, "smooth": sum(1 for p in me.polygons if p.use_smooth)}


def build():
	bpy.ops.wm.read_homefile(use_empty=True, use_factory_startup=True)
	sc = bpy.context.scene
	coll = bpy.data.collections.new(COLL)
	sc.collection.children.link(coll)
	scratch = bpy.data.collections.new("_scratch")
	sc.collection.children.link(scratch)
	bvh = sack_bvh()
	hw, tag_frame = top_hardware(bvh)
	spec = [
		("Sack", "Body", sack_body(), 0.016),
		("Sack", "Frame", sack_frame(), 0.008),
		("Sack", "Light", sack_light(), 0.004),
		("Sack", "Interior", sack_interior(), 0.0),
		("Top", "Frame", top_frame(), 0.01),
		("Top", "Interior", top_interior(), 0.0),
		("Top", "Hardware", hw, 0.012),
		("Top", "Gem", top_gem(tag_frame), 0.004),
	]
	pivots = {"Sack": Vector((0, 0, 0)), "Top": Vector((0, 0, NECK_Z * SCALE))}
	info = {"version": VERSION, "parts": {}, "tris": 0, "scale": SCALE, "pivots_blender": {k: list(v) for k, v in pivots.items()}}
	objs = {}
	for group, role, bms, bev in spec:
		name = f"{group}_{role}"
		me = union_bevel(name, bms, scratch, scratch, bev)
		piv = pivots[group]
		me.transform(Matrix.Scale(SCALE, 4))
		me.transform(Matrix.Translation(-piv))
		for p in me.polygons:
			p.use_smooth = False
		me.materials.clear()
		me.materials.append(make_mat(role))
		ob = bpy.data.objects.new(name, me)
		ob.location = piv
		ob["group"], ob["role"] = group, role
		coll.objects.link(ob)
		st = check(me)
		info["parts"][name] = st
		info["tris"] += st["tris"]
		objs[name] = ob
	bpy.data.collections.remove(scratch)
	return coll, objs, info


def coplanar_pairs(objs, tol=0.0015):
	"""Faces of different parts that lie in the same plane and overlap (z-fight risk)."""
	data = []
	for name, ob in objs.items():
		mw = ob.matrix_world
		for p in ob.data.polygons:
			c = mw @ p.center
			n = (mw.to_3x3() @ p.normal).normalized()
			data.append((name, c, n, p.area))
	hits = 0
	sample = []
	for i in range(len(data)):
		ni, ci, nn, ai = data[i]
		for j in range(i + 1, len(data)):
			nj, cj, nm, aj = data[j]
			if ni == nj or nn.dot(nm) < 0.999:
				continue
			if abs((cj - ci).dot(nn)) > tol:
				continue
			if (cj - ci).length > (math.sqrt(ai) + math.sqrt(aj)):
				continue
			hits += 1
			if len(sample) < 6:
				sample.append([ni, nj, [round(x, 3) for x in ci]])
	return hits, sample


def lights_and_cam(sc, target):
	tgt = Vector(target)
	for name, loc, energy, size in (("Key", (-3.2, -4.2, 3.6), 320, 3.0), ("Fill", (3.8, -2.6, 1.4), 120, 3.8), ("Rim", (1.6, 3.8, 3.2), 260, 2.6)):
		lt = bpy.data.objects.new("BagLight_" + name, bpy.data.lights.new("BagLight_" + name, "AREA"))
		sc.collection.objects.link(lt)
		lt.location = Vector(loc)
		lt.data.energy, lt.data.size = energy, size
		lt.rotation_euler = (tgt - lt.location).to_track_quat("-Z", "Y").to_euler()
	cam = bpy.data.objects.new("BagCam", bpy.data.cameras.new("BagCam"))
	sc.collection.objects.link(cam)
	sc.camera = cam
	return cam


def shoot(sc, cam, loc, target, path, lens=50, transparent=False, res=720):
	cam.location = Vector(loc)
	cam.rotation_euler = (Vector(target) - cam.location).to_track_quat("-Z", "Y").to_euler()
	cam.data.lens = lens
	sc.render.film_transparent = transparent
	sc.render.resolution_x = sc.render.resolution_y = res
	sc.render.filepath = path
	bpy.ops.render.render(write_still=True)


def render(objs, info):
	sc = bpy.context.scene
	sc.render.engine = "BLENDER_EEVEE"
	sc.view_settings.view_transform = "Standard"
	sc.render.image_settings.file_format = "PNG"
	sc.render.image_settings.color_mode = "RGBA"
	w = bpy.data.worlds.new("BagWorld")
	w.use_nodes = True
	w.node_tree.nodes["Background"].inputs[0].default_value = (0.05, 0.052, 0.065, 1.0)
	sc.world = w
	h = 1.6
	cam = lights_and_cam(sc, (0, 0, h * 0.5))
	os.makedirs(REVIEW_DIR, exist_ok=True)
	os.makedirs(os.path.dirname(CARD_PNG), exist_ok=True)
	mid = (0, 0, h * 0.48)
	shoot(sc, cam, (-2.6, -4.6, 2.2), mid, CARD_PNG, lens=90, transparent=True, res=900)
	shots = {
		"hero": ((-2.6, -4.6, 2.2), mid, 50),
		"front": ((0, -5.0, 0.9), (0, 0, 0.8), 50),
		"right": ((5.0, -0.6, 1.0), (0, 0, 0.8), 50),
		"back": ((1.8, 4.8, 1.6), (0, 0, 0.8), 50),
		"tie_front": ((-0.35, -1.9, 1.55), (0, -0.3, 1.22), 50),
		"tie_left": ((-1.9, -0.9, 1.4), (0, -0.1, 1.22), 50),
		"tie_right": ((1.7, -1.4, 1.35), (0.15, -0.2, 1.15), 50),
		"tag": ((1.25, -1.35, 1.05), (0.28, -0.38, 0.98), 50),
		"patch": ((-0.5, -1.6, 0.6), (0, -0.62, 0.52), 50),
		"base": ((1.4, -2.0, -0.35), (0, 0, 0.12), 45),
		"base_back": ((-1.6, 1.8, -0.3), (0, 0, 0.12), 45),
		"top_down": ((0.3, -0.6, 3.2), (0, 0, 1.4), 45),
	}
	for k, (loc, tgt, lens) in shots.items():
		shoot(sc, cam, loc, tgt, os.path.join(REVIEW_DIR, f"{k}.png"), lens=lens)
	# culled magenta: back faces magenta to show holes / flipped faces
	mag = bpy.data.materials.new("_Magenta")
	mag.use_nodes = True
	nt = mag.node_tree
	b = nt.nodes["Principled BSDF"]
	geo = nt.nodes.new("ShaderNodeNewGeometry")
	mix = nt.nodes.new("ShaderNodeMixRGB")
	mix.inputs[1].default_value = (0.6, 0.6, 0.62, 1)
	mix.inputs[2].default_value = (1, 0, 1, 1)
	nt.links.new(geo.outputs["Backfacing"], mix.inputs[0])
	nt.links.new(mix.outputs[0], b.inputs["Base Color"])
	saved = {n: list(o.data.materials) for n, o in objs.items()}
	for o in objs.values():
		o.data.materials.clear()
		o.data.materials.append(mag)
	for k in ("tie_front", "tie_right", "tag", "base"):
		loc, tgt, lens = shots[k]
		shoot(sc, cam, loc, tgt, os.path.join(REVIEW_DIR, f"mag_{k}.png"), lens=lens)
	for n, o in objs.items():
		o.data.materials.clear()
		for m in saved[n]:
			o.data.materials.append(m)
	bpy.data.materials.remove(mag)


def export_fbx(coll):
	objs = list(coll.objects)
	win = bpy.context.window_manager.windows[0]
	with bpy.context.temp_override(window=win, selected_objects=objs, active_object=objs[0]):
		bpy.ops.export_scene.fbx(filepath=FBX, use_selection=True, object_types={"MESH"}, apply_scale_options="FBX_SCALE_UNITS", use_mesh_modifiers=True, bake_anim=False)


def main():
	assert not os.path.exists(BLEND), f"{BLEND} exists: one .blend per version"
	os.makedirs(OUT_DIR, exist_ok=True)
	coll, objs, info = build()
	hits, sample = coplanar_pairs(objs)
	info["coplanar_pairs"] = hits
	info["coplanar_sample"] = sample
	info["subdiv_modifiers"] = sum(1 for o in objs.values() for m in o.modifiers if m.type == "SUBSURF")
	bpy.context.view_layer.update()
	z = [(o.matrix_world @ v.co).z for o in objs.values() for v in o.data.vertices]
	info["height"] = round(max(z) - min(z), 4)
	info["min_z"] = round(min(z), 4)
	export_fbx(coll)
	with bpy.context.temp_override(window=bpy.context.window_manager.windows[0]):
		render(objs, info)
		bpy.ops.wm.save_as_mainfile(filepath=BLEND)
	with open(OUT_JSON, "w", encoding="utf-8") as f:
		json.dump(info, f, indent=2)
	return info


result = main()
print(json.dumps(result, indent=2))
