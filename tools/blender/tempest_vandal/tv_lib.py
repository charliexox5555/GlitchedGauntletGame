# Tempest-Strike Vandal (restart 2026-11-21): modelling helpers.
# Units: Blender units = studs. +X = muzzle, +Z = up, +Y = the gun's left side (the side the player sees).
# Exec'd at the top of each build script: exec(open(LIB).read()).
import bpy, bmesh, math
from mathutils import Vector, Matrix

SCRATCH = r"C:/Users/charl/AppData/Local/Temp/claude/487954cbd365390d/59720a05-5fc4-46fb-9558-104afc4148ec/scratchpad/"

# ---------- collections and materials ----------
def coll(name, parent=None):
	c = bpy.data.collections.get(name)
	if c is None:
		c = bpy.data.collections.new(name)
		(parent or bpy.context.scene.collection).children.link(c)
	return c

def clear_coll(c):
	for o in list(c.all_objects):
		me = o.data if o.type == "MESH" else None
		bpy.data.objects.remove(o, do_unlink=True)
		if me is not None and me.users == 0:
			bpy.data.meshes.remove(me)

def _lin(h):
	h = h.lstrip("#")
	def ch(v):
		v = v / 255.0
		return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4
	return (ch(int(h[0:2], 16)), ch(int(h[2:4], 16)), ch(int(h[4:6], 16)), 1.0)

# Storm Shadow roles (concept.md working values; tune under neutral light).
ROLES = {
	"Body":   ("#30363E", 0.52, 0.20),   # matte black alloy (blue-black enamel)
	"Panel":  ("#D3D8DD", 0.40, 0.35),   # brushed silver plates
	"Dark":   ("#0E1320", 0.60, 0.20),   # dark indigo recesses
	"Grip":   ("#4A3328", 0.70, 0.00),   # dark-brown leather
	"Metal":  ("#6D7682", 0.28, 1.00),   # dark steel joints, controls, muzzle
	"Accent": ("#3E6580", 0.45, 0.30),   # storm blue, sparing
	"Neon":   ("#5FE6E0", 0.30, 0.00),   # hydro cyan (emissive)
	"Glass":  ("#A9E5E9", 0.05, 0.00),
}

def mat(role):
	name = "TS_" + role
	m = bpy.data.materials.get(name)
	if m is None:
		m = bpy.data.materials.new(name)
		m.use_nodes = True
	col, rough, metal = ROLES[role]
	b = m.node_tree.nodes.get("Principled BSDF")
	b.inputs["Base Color"].default_value = _lin(col)
	b.inputs["Roughness"].default_value = rough
	b.inputs["Metallic"].default_value = metal
	if role == "Neon":
		b.inputs["Emission Color"].default_value = _lin(col)
		b.inputs["Emission Strength"].default_value = 4.0
	m.diffuse_color = _lin(col)
	return m

# ---------- object creation ----------
def kill(name):
	o = bpy.data.objects.get(name)
	if o:
		me = o.data if o.type == "MESH" else None
		bpy.data.objects.remove(o, do_unlink=True)
		if me is not None and me.users == 0:
			bpy.data.meshes.remove(me)

def to_obj(name, bm, c, role):
	kill(name)
	bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	me = bpy.data.meshes.new(name)
	bm.to_mesh(me)
	bm.free()
	o = bpy.data.objects.new(name, me)
	c.objects.link(o)
	me.materials.append(mat(role))
	return o

def poly_offset(pts, d):
	"""Offset a closed 2D polygon (CCW) outward by d with mitred corners."""
	n = len(pts)
	out = []
	area = sum(pts[i][0] * pts[(i + 1) % n][1] - pts[(i + 1) % n][0] * pts[i][1] for i in range(n))
	s = 1 if area > 0 else -1
	for i in range(n):
		p0, p1, p2 = Vector(pts[i - 1]), Vector(pts[i]), Vector(pts[(i + 1) % n])
		e0 = (p1 - p0).normalized(); e1 = (p2 - p1).normalized()
		n0 = Vector((e0.y, -e0.x)) * s; n1 = Vector((e1.y, -e1.x)) * s
		bis = (n0 + n1)
		if bis.length < 1e-6:
			bis = n0
		bis.normalize()
		cosv = max(0.35, bis.dot(n0))
		q = p1 + bis * (d / cosv)
		out.append((q.x, q.y))
	return out

def band(path, th, cap_a=None, cap_b=None):
	"""Polygon (x,z) for a bar of thickness th along a polyline path. Mitred joints."""
	left, right = [], []
	n = len(path)
	for i in range(n):
		p = Vector(path[i])
		if i == 0:
			t = (Vector(path[1]) - p).normalized()
		elif i == n - 1:
			t = (p - Vector(path[i - 1])).normalized()
		else:
			t = ((p - Vector(path[i - 1])).normalized() + (Vector(path[i + 1]) - p).normalized()).normalized()
		nrm = Vector((-t.y, t.x))
		k = 1.0
		if 0 < i < n - 1:
			t0 = (p - Vector(path[i - 1])).normalized()
			k = 1.0 / max(0.4, Vector((-t0.y, t0.x)).dot(nrm))
		left.append(tuple(p + nrm * th * 0.5 * k)); right.append(tuple(p - nrm * th * 0.5 * k))
	return left + right[::-1]

def profile(name, pts, hw, c, role, yc=0.0):
	"""Side profile (x,z) extruded across Y from yc-hw to yc+hw."""
	bm = bmesh.new()
	vs = [bm.verts.new((x, yc - hw, z)) for x, z in pts]
	f = bm.faces.new(vs)
	r = bmesh.ops.extrude_face_region(bm, geom=[f])
	for v in [g for g in r["geom"] if isinstance(g, bmesh.types.BMVert)]:
		v.co.y += 2 * hw
	return bm

def plate_yz(name, pts, x0, x1):
	"""Front profile (y,z) extruded along X from x0 to x1."""
	bm = bmesh.new()
	vs = [bm.verts.new((x0, y, z)) for y, z in pts]
	f = bm.faces.new(vs)
	r = bmesh.ops.extrude_face_region(bm, geom=[f])
	for v in [g for g in r["geom"] if isinstance(g, bmesh.types.BMVert)]:
		v.co.x += (x1 - x0)
	return bm

def loft(rings, cap0=True, cap1=True):
	"""rings: list of lists of 3D points (same count, same winding). Returns bmesh."""
	bm = bmesh.new()
	R = [[bm.verts.new(p) for p in ring] for ring in rings]
	n = len(rings[0])
	for a, b in zip(R[:-1], R[1:]):
		for i in range(n):
			bm.faces.new((a[i], a[(i + 1) % n], b[(i + 1) % n], b[i]))
	if cap0:
		bm.faces.new(R[0][::-1])
	if cap1:
		bm.faces.new(R[-1])
	return bm

def octo(hw, hh, c=0.38, cy=0.0, cz=0.0, ctop=None, cbot=None):
	"""Elongated octagon in (y,z): flat sides, flat top/bottom, 45-ish diagonals.
	c = diagonal size as a fraction of the smaller half-extent. Optional separate top/bottom chamfer."""
	m = min(hw, hh)
	ct = (ctop if ctop is not None else c) * m
	cb = (cbot if cbot is not None else c) * m
	return [(cy + hw, cz - hh + cb), (cy + hw, cz + hh - ct), (cy + hw - ct, cz + hh), (cy - hw + ct, cz + hh),
		(cy - hw, cz + hh - ct), (cy - hw, cz - hh + cb), (cy - hw + cb, cz - hh), (cy + hw - cb, cz - hh)]

def ring_x(x, sec):
	return [(x, y, z) for y, z in sec]

def ngon_yz(r, n, cy=0.0, cz=0.0, rot=0.0, sy=1.0):
	return [(cy + sy * r * math.cos(rot + 2 * math.pi * i / n), cz + r * math.sin(rot + 2 * math.pi * i / n)) for i in range(n)]

# ---------- edge treatment ----------
def chamfer_edges(bm, pred, offset, segs=1, profile=0.5):
	bm.edges.ensure_lookup_table()
	es = [e for e in bm.edges if len(e.link_faces) == 2 and pred(e)]
	if es:
		bmesh.ops.bevel(bm, geom=es, offset=offset, offset_type="OFFSET", profile_type="SUPERELLIPSE",
			segments=segs, profile=profile, affect="EDGES", clamp_overlap=True)
	return len(es)

def side_edges(zmin=-9, zmax=9, up=None, ymin=0.9):
	"""Predicate: edges between a +/-Y side face and another face (optionally only upward/downward faces)."""
	def p(e):
		f0, f1 = e.link_faces
		a, b = f0.normal, f1.normal
		for s, o in ((a, b), (b, a)):
			if abs(s.y) > ymin and abs(o.y) < 0.6:
				if up is True and o.z < 0.3:
					continue
				if up is False and o.z > -0.3:
					continue
				z = (e.verts[0].co.z + e.verts[1].co.z) / 2
				if zmin <= z <= zmax:
					return True
		return False
	return p

def finish(o, w=0.006, segs=1, angle=30, wn=True):
	"""Crisp machined finish (owner 2026-11-21: 'sharper corners, cleaner sides, nothing curved').
	Flat shading on every face, one tiny flat chamfer per hard edge (a thin edge highlight, never a radius),
	no weighted/hardened normals (they smear light across faces and read as rounded)."""
	me = o.data
	for p in me.polygons:
		p.use_smooth = False
	w = min(w, 0.0012)
	if w > 0:
		b = o.modifiers.new("Chamfer", "BEVEL")
		b.width = w
		b.segments = 1
		b.limit_method = "ANGLE"
		b.angle_limit = math.radians(angle)
		b.harden_normals = False
		b.miter_outer = "MITER_SHARP"
		b.use_clamp_overlap = True
	if False:
		n = o.modifiers.new("WNormal", "WEIGHTED_NORMAL")
		n.keep_sharp = True
		n.weight = 100
		n.mode = "FACE_AREA"
	# sharp edges by angle so faces stay planar
	bm = bmesh.new(); bm.from_mesh(me)
	for e in bm.edges:
		if len(e.link_faces) == 2 and e.calc_face_angle(0) > math.radians(angle):
			e.smooth = False
	bm.to_mesh(me); bm.free()
	return o

def cut(o, cutter, op="DIFFERENCE", name=None):
	m = o.modifiers.new(name or ("Cut_" + cutter.name), "BOOLEAN")
	m.operation = op
	m.solver = "EXACT"
	m.material_mode = "TRANSFER"
	m.object = cutter
	cutter.display_type = "WIRE"
	cutter.hide_render = True
	# keep booleans before the chamfer
	while o.modifiers.find(m.name) > 0 and o.modifiers[o.modifiers.find(m.name) - 1].type in ("BEVEL", "WEIGHTED_NORMAL"):
		bpy.context.view_layer.objects.active = o
		with bpy.context.temp_override(object=o):
			bpy.ops.object.modifier_move_up(modifier=m.name)
	return m

def cut_coll(o, cutters_coll, name):
	m = o.modifiers.new(name, "BOOLEAN")
	m.operation = "DIFFERENCE"
	m.solver = "EXACT"
	m.operand_type = "COLLECTION"
	m.material_mode = "TRANSFER"
	m.collection = cutters_coll
	for c in cutters_coll.objects:
		c.display_type = "WIRE"; c.hide_render = True
	while o.modifiers.find(m.name) > 0 and o.modifiers[o.modifiers.find(m.name) - 1].type in ("BEVEL", "WEIGHTED_NORMAL"):
		with bpy.context.temp_override(object=o):
			bpy.ops.object.modifier_move_up(modifier=m.name)
	return m

def box(x0, x1, y0, y1, z0, z1):
	bm = bmesh.new()
	bmesh.ops.create_cube(bm, size=1.0)
	for v in bm.verts:
		v.co.x = x0 if v.co.x < 0 else x1
		v.co.y = y0 if v.co.y < 0 else y1
		v.co.z = z0 if v.co.z < 0 else z1
	return bm

def tris(objs):
	dg = bpy.context.evaluated_depsgraph_get()
	t = 0
	for o in objs:
		if o.type != "MESH" or o.hide_render:
			continue
		me = o.evaluated_get(dg).to_mesh()
		t += sum(len(p.vertices) - 2 for p in me.polygons)
		o.evaluated_get(dg).to_mesh_clear()
	return t

def fluted(sec, spec):
	"""Insert grooves into a closed (y,z) section. spec: {edge_index: [(t, width, depth), ...]}
	t = position along the edge 0..1, depth inward (0 = flush, keeps the point count for lofting)."""
	out = []
	n = len(sec)
	for i in range(n):
		a, b = Vector(sec[i]), Vector(sec[(i + 1) % n])
		out.append(tuple(a))
		if i in spec:
			e = b - a; L = e.length; t_ = e / L
			nrm = Vector((t_.y, -t_.x))
			# inward normal: towards the section centre
			cen = sum((Vector(p) for p in sec), Vector((0, 0))) / n
			if nrm.dot(cen - (a + b) / 2) < 0:
				nrm = -nrm
			for t, w, d in sorted(spec[i]):
				p0 = a + t_ * (t * L - w / 2); p1 = a + t_ * (t * L + w / 2)
				out += [tuple(p0), tuple(p0 + t_ * (w * 0.2) + nrm * d), tuple(p1 - t_ * (w * 0.2) + nrm * d), tuple(p1)]
	return out
