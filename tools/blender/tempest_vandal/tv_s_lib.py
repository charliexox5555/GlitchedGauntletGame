# Helpers for the stock-based Tempest-Strike build (s01+). Exec'd by the stage scripts.
# World axes: +X muzzle, +Z up, +Y = gun's left (player side). Stock parts hang off the Vandal_Rig bones.
import bpy, bmesh, math
from mathutils import Vector, Matrix

def coll(name, parent=None):
	c = bpy.data.collections.get(name)
	if c is None:
		c = bpy.data.collections.new(name)
		(parent or bpy.context.scene.collection).children.link(c)
	return c
TS = coll("Tempest")
CUT = coll("Tempest_Cutters")
CUT.hide_render = True
M = lambda n: bpy.data.materials[n]

def purge(prefixes):
	for c in (TS, CUT):
		for o in list(c.objects):
			if o.name.startswith(prefixes):
				bpy.data.objects.remove(o, do_unlink=True)
	for m in list(bpy.data.meshes):
		if m.users == 0:
			bpy.data.meshes.remove(m)

def replaced(src):
	o = bpy.data.objects[src]
	o.hide_render = True; o.hide_set(True); o["ts_replaced"] = True
	return o

def dup(src, name, hide_src=True):
	o = bpy.data.objects[src]
	n = o.copy(); n.data = o.data.copy(); n.name = name; n.data.name = name
	if "ts_replaced" in n.keys():
		del n["ts_replaced"]
	n.hide_render = False; n.hide_viewport = False
	for c in list(n.users_collection):
		c.objects.unlink(n)
	TS.objects.link(n); n.hide_set(False)
	if hide_src:
		replaced(src)
	return n

def stock_finish(o, bevel=0.0):
	for p in o.data.polygons:
		p.use_smooth = True
	if bevel:
		b = o.modifiers.new("Bevel", "BEVEL"); b.width = bevel; b.segments = 1; b.limit_method = "ANGLE"
		b.angle_limit = math.radians(30); b.harden_normals = True; b.use_clamp_overlap = True
	if not any(m.type == "WEIGHTED_NORMAL" for m in o.modifiers):
		w = o.modifiers.new("WeightedNormal", "WEIGHTED_NORMAL"); w.keep_sharp = True; w.weight = 50
	return o

def new_obj(name, bm, mat, like="Vandal_Receiver", bevel=0.0012):
	"""World-space bmesh -> object parented like `like` (same bone), smooth + weighted normals like stock."""
	ref = bpy.data.objects[like]
	bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	me = bpy.data.meshes.new(name)
	bm.to_mesh(me); bm.free()
	o = bpy.data.objects.new(name, me); TS.objects.link(o)
	o.parent = ref.parent; o.parent_type = ref.parent_type; o.parent_bone = ref.parent_bone
	o.matrix_world = Matrix.Identity(4)
	me.materials.append(M(mat))
	return stock_finish(o, bevel)

def cutter(name, bm):
	me = bpy.data.meshes.new(name); bmesh.ops.recalc_face_normals(bm, faces=bm.faces); bm.to_mesh(me); bm.free()
	o = bpy.data.objects.new(name, me); CUT.objects.link(o); o.matrix_world = Matrix.Identity(4)
	me.materials.append(M("Dark"))
	return o

def boolean(o, c, op="DIFFERENCE"):
	m = o.modifiers.new("B_" + c.name, "BOOLEAN"); m.object = c; m.operation = op; m.solver = "EXACT"
	m.material_mode = "TRANSFER"; m.use_hole_tolerant = True
	o.modifiers.move(o.modifiers.find(m.name), 0)
	return m

def loft(rings, cap0=True, cap1=True):
	bm = bmesh.new()
	R = [[bm.verts.new(p) for p in r] for r in rings]
	n = len(rings[0])
	for a, b in zip(R[:-1], R[1:]):
		for i in range(n):
			bm.faces.new((a[i], a[(i + 1) % n], b[(i + 1) % n], b[i]))
	if cap0:
		bm.faces.new(R[0][::-1])
	if cap1:
		bm.faces.new(R[-1])
	return bm

def octo(hw, hh, c=0.14, cy=0.0, cz=0.0):
	k = c * min(hw, hh)
	return [(cy + hw, cz - hh + k), (cy + hw, cz + hh - k), (cy + hw - k, cz + hh), (cy - hw + k, cz + hh),
		(cy - hw, cz + hh - k), (cy - hw, cz - hh + k), (cy - hw + k, cz - hh), (cy + hw - k, cz - hh)]

def ring_x(x, sec):
	return [(x, y, z) for y, z in sec]

def fluted(sec, spec):
	out = []; n = len(sec)
	cen = sum((Vector(p) for p in sec), Vector((0, 0))) / n
	for i in range(n):
		a, b = Vector(sec[i]), Vector(sec[(i + 1) % n])
		out.append(tuple(a))
		if i in spec:
			e = b - a; L = e.length; t = e / L
			nr = Vector((t.y, -t.x))
			if nr.dot(cen - (a + b) / 2) < 0:
				nr = -nr
			for tt, w, d in sorted(spec[i]):
				p0 = a + t * (tt * L - w / 2); p1 = a + t * (tt * L + w / 2)
				out += [tuple(p0), tuple(p0 + t * (w * 0.2) + nr * d), tuple(p1 - t * (w * 0.2) + nr * d), tuple(p1)]
	return out

def prism_xz(pts, y0, y1):
	"""Side profile (x,z) extruded across Y."""
	bm = bmesh.new()
	f = bm.faces.new([bm.verts.new((x, y0, z)) for x, z in pts])
	r = bmesh.ops.extrude_face_region(bm, geom=[f])
	for v in [g for g in r["geom"] if isinstance(g, bmesh.types.BMVert)]:
		v.co.y += (y1 - y0)
	return bm

def prism_yz(pts, x0, x1):
	bm = bmesh.new()
	f = bm.faces.new([bm.verts.new((x0, y, z)) for y, z in pts])
	r = bmesh.ops.extrude_face_region(bm, geom=[f])
	for v in [g for g in r["geom"] if isinstance(g, bmesh.types.BMVert)]:
		v.co.x += (x1 - x0)
	return bm

def surface_plate(src, name, outline, side, lift=0.0008, thick=0.0055, mat="Panel", min_dot=0.55):
	"""Faces of `src` facing `side` (+1 left / -1 right), cut exactly along `outline` (x,z, world) and thickened
	outward: armour that sits on the stock surface."""
	o = bpy.data.objects[src]
	mw = o.matrix_world; mi = mw.inverted()
	bm = bmesh.new(); bm.from_mesh(o.data); bm.transform(mw)
	n = len(outline)
	for i in range(n):
		a = Vector((outline[i][0], 0, outline[i][1])); b = Vector((outline[(i + 1) % n][0], 0, outline[(i + 1) % n][1]))
		bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=a,
			plane_no=(b - a).cross(Vector((0, 1, 0))).normalized())
	def inside(x, z):
		c = False
		for i in range(n):
			x1, z1 = outline[i]; x2, z2 = outline[(i + 1) % n]
			if (z1 > z) != (z2 > z) and x < (x2 - x1) * (z - z1) / (z2 - z1) + x1:
				c = not c
		return c
	keep = {f for f in bm.faces if f.normal.y * side > min_dot and f.calc_center_median().y * side > 0.02 and inside(*(lambda c: (c.x, c.z))(f.calc_center_median()))}
	bmesh.ops.delete(bm, geom=[f for f in bm.faces if f not in keep], context="FACES")
	bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(1.0), verts=bm.verts[:], edges=bm.edges[:])
	for v in bm.verts:
		v.co.y += side * lift
	bm.transform(mi)
	me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
	p = bpy.data.objects.new(name, me); TS.objects.link(p)
	p.parent = o.parent; p.parent_type = o.parent_type; p.parent_bone = o.parent_bone
	p.matrix_parent_inverse = o.matrix_parent_inverse.copy(); p.matrix_basis = o.matrix_basis.copy()
	me.materials.append(M(mat))
	so = p.modifiers.new("Thick", "SOLIDIFY"); so.thickness = thick; so.offset = 1.0
	so.use_even_offset = True; so.use_rim = True
	return stock_finish(p)
