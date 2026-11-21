# Tempest-Strike line (Stinger, Marshal, Bucky, Sheriff, Kunai-Katana): shared helpers, exec'd by every stage.
# Copied and adapted from tools/blender/tempest_vandal/tv_s_lib.py + tv_lib.py (the Vandal's stay untouched).
# Set GUN before exec. World axes: +X muzzle, +Z up, +Y = gun's left (player side). Units = studs.
# Stock parts hang off <GUN>_Rig bones; new parts copy the parenting of a stock part (`like`).
import bpy, bmesh, math, os
from mathutils import Vector, Matrix

ROOT = r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/"
SCRATCH = r"C:/Users/charl/AppData/Local/Temp/claude/6f8bed3fe7c45255/6fc92333-7f52-4d25-b886-dff8b47c2843/scratchpad/"
GUN = globals().get("GUN", "Stinger")
G = lambda n: "%s_%s" % (GUN, n)

def coll(name, parent=None):
	c = bpy.data.collections.get(name)
	if c is None:
		c = bpy.data.collections.new(name)
		(parent or bpy.context.scene.collection).children.link(c)
	return c
TS = coll("Tempest")
CUT = coll("Tempest_Cutters")
CUT.hide_render = True

def lin(h):
	h = h.lstrip("#")
	f = lambda v: (v / 255) / 12.92 if v / 255 <= 0.04045 else (((v / 255) + 0.055) / 1.055) ** 2.4
	return (f(int(h[0:2], 16)), f(int(h[2:4], 16)), f(int(h[4:6], 16)), 1.0)

# Final Vandal Storm Shadow values (s05 finish): (hex, roughness, metallic)
PAL = {"Body": ("#1D2433", 0.30, 0.45), "Panel": ("#DCE1E6", 0.26, 0.72), "Dark": ("#0C111C", 0.6, 0.2),
	"Grip": ("#4A3328", 0.72, 0.0), "Metal": ("#7A8491", 0.26, 0.95), "Accent": ("#3E6580", 0.32, 0.5),
	"Neon": ("#5FE6E0", 0.3, 0.0), "Brass": ("#A8844E", 0.35, 0.9)}

def palette():
	"""Storm Shadow on the stock role materials (same names the flat exporter reads)."""
	for n, (hx, r, mt) in PAL.items():
		m = bpy.data.materials.get(n)
		if m is None:
			continue
		base = lin(hx); m.diffuse_color = base
		if not m.use_nodes:
			continue
		b = next((x for x in m.node_tree.nodes if x.type == "BSDF_PRINCIPLED"), None)
		if not b:
			continue
		cr = next((x for x in m.node_tree.nodes if x.type == "VALTORGB"), None)
		if cr:
			for e, k in zip(cr.color_ramp.elements, (0.97, 1.03)):
				e.color = (base[0] * k, base[1] * k, base[2] * k, 1.0)
		if not b.inputs["Base Color"].is_linked:
			b.inputs["Base Color"].default_value = base
		if not b.inputs["Roughness"].is_linked:
			b.inputs["Roughness"].default_value = r
		else:
			mr = next((x for x in m.node_tree.nodes if x.type == "MAP_RANGE"), None)
			if mr:
				mr.inputs["To Min"].default_value = r - 0.04; mr.inputs["To Max"].default_value = r + 0.04
		b.inputs["Metallic"].default_value = mt
		if n == "Neon":
			b.inputs["Emission Color"].default_value = base
			b.inputs["Emission Strength"].default_value = 4.0
		if n == "Grip":
			# leather: no rubber pattern bump
			for x in m.node_tree.nodes:
				if x.type == "BUMP":
					x.inputs["Strength"].default_value = 0.0

def M(n):
	m = bpy.data.materials.get(n)
	if m is None:
		m = bpy.data.materials.new(n); m.use_nodes = True
		hx, r, mt = PAL.get(n, ("#FF00FF", 0.5, 0.0))
		b = m.node_tree.nodes.get("Principled BSDF")
		b.inputs["Base Color"].default_value = lin(hx); b.inputs["Roughness"].default_value = r
		b.inputs["Metallic"].default_value = mt; m.diffuse_color = lin(hx)
	return m

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

def unreplace(src):
	o = bpy.data.objects.get(src)
	if o:
		o.hide_render = False; o.hide_set(False)
		if "ts_replaced" in o.keys():
			del o["ts_replaced"]

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

def finish(o, bevel=0.0, smooth=False):
	"""Crisp finish (Vandal r02+ rule): flat shading, at most one hairline flat chamfer (<= 0.0012)."""
	for p in o.data.polygons:
		p.use_smooth = smooth
	if bevel:
		b = o.modifiers.new("Bevel", "BEVEL"); b.width = bevel; b.segments = 1; b.limit_method = "ANGLE"
		b.angle_limit = math.radians(30); b.harden_normals = False; b.use_clamp_overlap = True
	return o

def bake_bm(bm):
	bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	return bm

def new_obj(name, bm, mat, like=None, bevel=0.0010):
	"""World-space bmesh -> object parented like stock part `like` (same bone), flat-shaded."""
	ref = bpy.data.objects[like or G("Receiver")]
	bake_bm(bm)
	me = bpy.data.meshes.new(name)
	bm.to_mesh(me); bm.free()
	o = bpy.data.objects.new(name, me); TS.objects.link(o)
	o.parent = ref.parent; o.parent_type = ref.parent_type; o.parent_bone = ref.parent_bone
	o.matrix_world = Matrix.Identity(4)
	me.materials.append(M(mat))
	return finish(o, bevel)

def add_mat(o, mat):
	"""Append a material slot (for boolean TRANSFER of cutter faces) and return its index."""
	m = M(mat)
	for i, x in enumerate(o.data.materials):
		if x == m:
			return i
	o.data.materials.append(m)
	return len(o.data.materials) - 1

def cutter(name, bm, mat="Dark"):
	me = bpy.data.meshes.new(name); bmesh.ops.recalc_face_normals(bm, faces=bm.faces); bm.to_mesh(me); bm.free()
	o = bpy.data.objects.new(name, me); CUT.objects.link(o); o.matrix_world = Matrix.Identity(4)
	me.materials.append(M(mat)); o.hide_render = True; o.display_type = "WIRE"
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
	"""Near-square 8-gon section (diagonals = c * small half-size; keep c <= 0.16 for crisp reads)."""
	k = c * min(hw, hh)
	return [(cy + hw, cz - hh + k), (cy + hw, cz + hh - k), (cy + hw - k, cz + hh), (cy - hw + k, cz + hh),
		(cy - hw, cz + hh - k), (cy - hw, cz - hh + k), (cy - hw + k, cz - hh), (cy + hw - k, cz - hh)]

def ngon(r, n, cy=0.0, cz=0.0, rot=0.0):
	return [(cy + r * math.cos(rot + 2 * math.pi * i / n), cz + r * math.sin(rot + 2 * math.pi * i / n)) for i in range(n)]

def ring_x(x, sec):
	return [(x, y, z) for y, z in sec]

def fluted(sec, spec):
	"""Insert flute notches into a section's edges: spec {edge_index: [(t, width, depth), ...]}."""
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

def prism_xy(pts, z0, z1):
	bm = bmesh.new()
	f = bm.faces.new([bm.verts.new((x, y, z0)) for x, y in pts])
	r = bmesh.ops.extrude_face_region(bm, geom=[f])
	for v in [g for g in r["geom"] if isinstance(g, bmesh.types.BMVert)]:
		v.co.z += (z1 - z0)
	return bm

def chamfer_prism_xz(pts, y0, y1, ch):
	"""Side-profile plate with flat chamfered long edges: the outline shrinks by `ch` on both Y faces."""
	cx = sum(p[0] for p in pts) / len(pts); cz = sum(p[1] for p in pts) / len(pts)
	inner = poly_offset(pts, -ch)
	bm = bmesh.new()
	ym = (y0 + y1) / 2
	A = [bm.verts.new((x, y0, z)) for x, z in inner]
	B = [bm.verts.new((x, y0 + ch, z)) for x, z in pts]
	C = [bm.verts.new((x, y1 - ch, z)) for x, z in pts]
	D = [bm.verts.new((x, y1, z)) for x, z in inner]
	n = len(pts)
	bm.faces.new(A[::-1])
	for P, Q in ((A, B), (B, C), (C, D)):
		for i in range(n):
			bm.faces.new((P[i], P[(i + 1) % n], Q[(i + 1) % n], Q[i]))
	bm.faces.new(D)
	return bm

def poly_offset(pts, d):
	"""Offset a closed 2D polygon by d (positive = outward for CCW)."""
	n = len(pts); out = []
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
		k = d / max(0.2, bis.dot(n0))
		q = p1 + bis * k
		out.append((q.x, q.y))
	return out

def bar(p0, p1, hw, hh, k=0.55, y=0.0):
	"""Faceted bar (8-pt section: flat sides, lean-in top/bottom planes) between two XZ points."""
	a, b = Vector((p0[0], y, p0[1])), Vector((p1[0], y, p1[1]))
	t = (b - a).normalized(); n = Vector((-t.z, 0, t.x))
	sec = [(hw, -hh * 0.45), (hw, hh * 0.45), (hw * k, hh), (-hw * k, hh), (-hw, hh * 0.45), (-hw, -hh * 0.45),
		(-hw * k, -hh), (hw * k, -hh)]
	ring = lambda c: [tuple(c + Vector((0, yy, 0)) + n * z) for yy, z in sec]
	return loft([ring(a), ring(b)])

def surface_plate(src, name, outline, side, lift=0.0008, thick=0.0055, mat="Panel", min_dot=0.55, ymin=0.02):
	"""Faces of `src` facing `side` (+1 left / -1 right), cut exactly along `outline` (x,z, world) and thickened
	OUTWARD: armour that sits on the stock surface (Vandal s06 fix: never thicken into the body)."""
	o = bpy.data.objects[src]
	dg = bpy.context.evaluated_depsgraph_get()
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
	keep = {f for f in bm.faces if f.normal.y * side > min_dot and f.calc_center_median().y * side > ymin and inside(*(lambda c: (c.x, c.z))(f.calc_center_median()))}
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
	# outward = the side the faces point to; solidify offset +1 thickens along normals
	so = p.modifiers.new("Thick", "SOLIDIFY"); so.thickness = thick; so.offset = 1.0
	so.use_even_offset = True; so.use_rim = True
	return finish(p)

def crescent(ro, ri, off, gap, cz, n=22):
	"""Open crescent outline (y,z) around (0, cz): thick foot, thin horns, open top of +-gap degrees."""
	a0, a1 = math.radians(90 + gap), math.radians(90 - gap + 360)
	outer = [(ro * math.cos(a0 + (a1 - a0) * i / n), cz + ro * math.sin(a0 + (a1 - a0) * i / n)) for i in range(n + 1)]
	inner = []
	for i in range(1, n):
		a = a1 - (a1 - a0) * i / n
		inner.append((ri * math.cos(a), cz + off + ri * math.sin(a)))
	return outer + inner

def crescent_sight(prefix, ax, az, ro, ri, off, gap, depth, like=None, face=True, pips=True, n=22):
	"""Crescent rear sight centred on the aim axis (ax = x of the sight plane, az = aim height)."""
	made = []
	made.append(new_obj(prefix + "_Sight_Crescent", prism_yz(crescent(ro, ri, off, gap, az, n), ax - depth / 2, ax + depth / 2), "Body", like=like))
	if face:
		made.append(new_obj(prefix + "_Sight_CrescentFace", prism_yz(crescent(ro - 0.0015, ri + 0.002, off * 0.64, gap + 2, az, n),
			ax - depth / 2 - 0.0022, ax - depth / 2 - 0.0002), "Panel", like=like, bevel=0))
	if pips:
		rm = (ro + ri) / 2 + off * 0.3
		for s in (1, -1):
			a = math.radians(90 + s * gap)
			ty, tz = rm * math.cos(a), az + rm * math.sin(a) + 0.001
			k = (ro - ri) * 0.55
			pip = [(ty, tz + k * 1.4), (ty + k, tz), (ty, tz - k), (ty - k, tz)]
			made.append(new_obj(prefix + "_Sight_Pip%+d" % s, prism_yz(pip, ax - depth / 2 - 0.0015, ax + depth / 2 + 0.0015), "Neon", like=like, bevel=0))
	return made

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

def visible_model():
	out = []
	for c in (GUN, "Tempest"):
		cc = bpy.data.collections.get(c)
		if not cc:
			continue
		for o in cc.all_objects:
			if o.type == "MESH" and not o.hide_render and not o.get("ts_replaced"):
				out.append(o)
	return out

def kill(name):
	o = bpy.data.objects.get(name)
	if o:
		me = o.data if o.type == "MESH" else None
		bpy.data.objects.remove(o, do_unlink=True)
		if me is not None and me.users == 0:
			bpy.data.meshes.remove(me)

def stock_bm(name, world=True):
	o = bpy.data.objects[name]
	bm = bmesh.new(); bm.from_mesh(o.data)
	if world:
		bm.transform(o.matrix_world)
	return bm, o

def write_bm(o, bm, world=True):
	if world:
		bm.transform(o.matrix_world.inverted())
	bm.to_mesh(o.data); bm.free(); o.data.update()

def clip(o, plane_co, plane_no, fill=True):
	"""Cut a (dup'd) mesh with a plane, removing the +normal side, filling the hole."""
	bm, _ = stock_bm(o.name)
	r = bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=plane_co, plane_no=plane_no, clear_outer=True)
	if fill:
		bnd = [e for e in bm.edges if e.is_boundary]
		if bnd:
			bmesh.ops.holes_fill(bm, edges=bnd, sides=0)
	write_bm(o, bm)
	return o

def section_at(name, x, tol=0.004):
	"""Measured (y,z) points of a stock mesh near plane x (for mating new parts to stock sections)."""
	o = bpy.data.objects[name]
	bm = bmesh.new(); bm.from_mesh(o.data); bm.transform(o.matrix_world)
	r = bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(x, 0, 0), plane_no=(1, 0, 0))
	pts = sorted({(round(v.co.y, 4), round(v.co.z, 4)) for v in r["geom_cut"] if isinstance(v, bmesh.types.BMVert)})
	bm.free()
	return pts

def profile_side(name, y_min=None):
	"""Silhouette extents per x station: (x, zmin, zmax, |y|max) from a stock mesh's verts."""
	o = bpy.data.objects[name]
	ws = [o.matrix_world @ v.co for v in o.data.vertices]
	xs = sorted({round(w.x, 3) for w in ws})
	return ws
