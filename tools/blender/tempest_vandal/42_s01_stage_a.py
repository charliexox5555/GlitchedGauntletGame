# Tempest-Strike Vandal s01, stage A: restyle the STOCK RemasterV2 Vandal (same rig, joints, charm loop,
# barrel, bolt, handle, trigger, selector). Replaced parts are copies of stock meshes edited with Blender's
# mesh tools; stock originals stay in the file, hidden, for the export manifest and comparison.
# Idempotent: deletes TS_* and rebuilds from the stock meshes.
import bpy, bmesh, math
from mathutils import Vector, Matrix

V = bpy.data.collections["Vandal"]
def coll(name, parent=None):
	c = bpy.data.collections.get(name)
	if c is None:
		c = bpy.data.collections.new(name)
		(parent or bpy.context.scene.collection).children.link(c)
	return c
TS = coll("Tempest")
CUT = coll("Tempest_Cutters")
for c in (TS, CUT):
	for o in list(c.all_objects):
		bpy.data.objects.remove(o, do_unlink=True)
for m in list(bpy.data.meshes):
	if m.users == 0:
		bpy.data.meshes.remove(m)
CUT.hide_render = True

def lin(h):
	h = h.lstrip("#")
	f = lambda v: (v / 255) / 12.92 if v / 255 <= 0.04045 else (((v / 255) + 0.055) / 1.055) ** 2.4
	return (f(int(h[0:2], 16)), f(int(h[2:4], 16)), f(int(h[4:6], 16)), 1.0)
# Storm Shadow on the stock role materials (same names the exporter and recolour system use)
PAL = {"Body": ("#1D2433", 0.42, 0.35), "Panel": ("#C6CDD4", 0.30, 0.65), "Dark": ("#0C111C", 0.6, 0.2),
	"Grip": ("#4A3328", 0.72, 0.0), "Metal": ("#5F6976", 0.32, 0.85), "Accent": ("#3E6580", 0.4, 0.3),
	"Neon": ("#5FE6E0", 0.3, 0.0)}
for n, (hx, r, mt) in PAL.items():
	m = bpy.data.materials[n]
	m.diffuse_color = lin(hx)
	if m.use_nodes:
		b = next((x for x in m.node_tree.nodes if x.type == "BSDF_PRINCIPLED"), None)
		if b:
			b.inputs["Base Color"].default_value = lin(hx)
			b.inputs["Roughness"].default_value = r
			b.inputs["Metallic"].default_value = mt
			cr = next((x for x in m.node_tree.nodes if x.type == "VALTORGB"), None)
			if cr:
				base = lin(hx)
				for e, k in zip(cr.color_ramp.elements, (0.96, 1.04)):
					e.color = (base[0] * k, base[1] * k, base[2] * k, 1.0)
			if n == "Neon":
				b.inputs["Emission Color"].default_value = lin(hx)
				b.inputs["Emission Strength"].default_value = 4.0
MAT = {m.name: i for i, m in enumerate(bpy.data.objects["Vandal_Receiver"].data.materials)}

def dup(src, name, hide_src=True):
	o = bpy.data.objects[src]
	n = o.copy(); n.data = o.data.copy(); n.name = name; n.data.name = name
	if "ts_replaced" in n.keys():
		del n["ts_replaced"]
	n.hide_render = False; n.hide_viewport = False
	for c in n.users_collection:
		c.objects.unlink(n)
	TS.objects.link(n); n.hide_set(False)
	if hide_src:
		o.hide_render = True; o.hide_set(True); o["ts_replaced"] = True
	return n

def finish_like_stock(o, w=0.0015):
	"""Stock finish: smooth shading + weighted normals (keep sharp), plus a tight single bevel on new edges."""
	for p in o.data.polygons:
		p.use_smooth = True
	if w:
		b = o.modifiers.new("Bevel", "BEVEL"); b.width = w; b.segments = 2; b.limit_method = "ANGLE"
		b.angle_limit = math.radians(30); b.harden_normals = True; b.use_clamp_overlap = True
	if not any(m.type == "WEIGHTED_NORMAL" for m in o.modifiers):
		wn = o.modifiers.new("WeightedNormal", "WEIGHTED_NORMAL"); wn.keep_sharp = True; wn.weight = 50
	else:
		o.modifiers.move(o.modifiers.find(next(m.name for m in o.modifiers if m.type == "WEIGHTED_NORMAL")), len(o.modifiers) - 1)
	return o

# ---------------- 1. top cover: stock rail without its 20 cross-teeth ----------------
tc = dup("Vandal_Rail", "TS_TopCover")
bm = bmesh.new(); bm.from_mesh(tc.data)
seen = set(); kill = []
for v in bm.verts:
	if v in seen:
		continue
	isl = []; st = [v]
	while st:
		a = st.pop()
		if a in seen:
			continue
		seen.add(a); isl.append(a)
		st += [e.other_vert(a) for e in a.link_edges]
	if min(x.co.z for x in isl) > 0.446:
		kill += isl
bmesh.ops.delete(bm, geom=kill, context="VERTS")
for f in bm.faces:
	if f.calc_center_median().z > 0.446 and f.normal.z > 0.9:
		f.material_index = MAT["Panel"]          # brushed-silver top strip on the cover
bm.to_mesh(tc.data); bm.free()

# ---------------- 2. rear sight: stock ring opened into a crescent ----------------
rs = dup("Vandal_RearSight", "TS_Sight_Crescent")
AX, AZ = 0.078, 0.56
bm = bmesh.new(); bm.from_mesh(rs.data)
dead = []
for f in bm.faces:
	c = f.calc_center_median()
	dy, dz = c.y, c.z - AZ
	r = math.hypot(dy, dz)
	ang = math.degrees(math.atan2(dy, dz))         # 0 = straight up
	if r > 0.04 and abs(ang) < 34 and c.z > AZ:
		dead.append(f)
bmesh.ops.delete(bm, geom=dead, context="FACES")
# cap the two open horn ends
bnd = [e for e in bm.edges if e.is_boundary]
if bnd:
	bmesh.ops.holes_fill(bm, edges=bnd, sides=0)
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
bm.to_mesh(rs.data); bm.free()
# two cyan pips just outside the horns
for s in (1, -1):
	a = math.radians(s * 44)
	py, pz = 0.088 * math.sin(a), AZ + 0.088 * math.cos(a)
	bm = bmesh.new()
	pts = [(py, pz + 0.011), (py + 0.007, pz), (py, pz - 0.011), (py - 0.007, pz)]
	f0 = bm.faces.new([bm.verts.new((AX - 0.006, y, z)) for y, z in pts])
	r_ = bmesh.ops.extrude_face_region(bm, geom=[f0])
	for v in [g for g in r_["geom"] if isinstance(g, bmesh.types.BMVert)]:
		v.co.x += 0.012
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	me = bpy.data.meshes.new("TS_Sight_Pip%+d" % s); bm.to_mesh(me); bm.free()
	o = bpy.data.objects.new(me.name, me); TS.objects.link(o)
	o.parent = rs.parent; o.parent_type = rs.parent_type; o.parent_bone = rs.parent_bone
	o.matrix_world = Matrix.Identity(4)
	me.materials.append(bpy.data.materials["Neon"])

# ---------------- 3. stock: skeleton window through the upper box ----------------
st_ = dup("Vandal_Stock", "TS_Stock")
bm = bmesh.new()
win = [(-0.300, 0.338), (-1.040, 0.338), (-1.060, 0.320), (-1.060, 0.262), (-1.035, 0.248), (-0.420, 0.262)]
vs = [bm.verts.new((x, -0.2, z)) for x, z in win]
f0 = bm.faces.new(vs)
r_ = bmesh.ops.extrude_face_region(bm, geom=[f0])
for v in [g for g in r_["geom"] if isinstance(g, bmesh.types.BMVert)]:
	v.co.y += 0.4
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
me = bpy.data.meshes.new("TS_CUT_StockWindow"); bm.to_mesh(me); bm.free()
cw = bpy.data.objects.new(me.name, me); CUT.objects.link(cw)
cw.matrix_world = Matrix.Identity(4)
cw.data.materials.append(bpy.data.materials["Dark"])
bo = st_.modifiers.new("Window", "BOOLEAN"); bo.object = cw; bo.solver = "EXACT"; bo.material_mode = "TRANSFER"
bo.use_hole_tolerant = True; bo.use_self = True
# boolean must come before the weighted normal
st_.modifiers.move(st_.modifiers.find("Window"), 0)

# ---------------- 4. silver armour cut from the stock surfaces ----------------
def surface_plate(src, name, outline, side, lift=0.0008, thick=0.0055, mat="Panel"):
	"""Copy src's faces that face `side` (+1 = +Y left, -1 = right), cut them exactly along the outline
	(x,z polygon, world space) with bisect planes, keep the inside, then thicken outward."""
	o = bpy.data.objects[src]
	mw = o.matrix_world; mi = mw.inverted()
	bm = bmesh.new(); bm.from_mesh(o.data)
	bm.transform(mw)
	n = len(outline)
	for i in range(n):
		a = Vector((outline[i][0], 0, outline[i][1])); b = Vector((outline[(i + 1) % n][0], 0, outline[(i + 1) % n][1]))
		nrm = (b - a).cross(Vector((0, 1, 0))).normalized()
		bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=a, plane_no=nrm)
	def inside(x, z):
		c = False
		for i in range(n):
			x1, z1 = outline[i]; x2, z2 = outline[(i + 1) % n]
			if (z1 > z) != (z2 > z) and x < (x2 - x1) * (z - z1) / (z2 - z1) + x1:
				c = not c
		return c
	keep = set()
	for f in bm.faces:
		cc = f.calc_center_median()
		if f.normal.y * side > 0.55 and inside(cc.x, cc.z):
			keep.add(f)
	bmesh.ops.delete(bm, geom=[f for f in bm.faces if f not in keep], context="FACES")
	bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(1.0), verts=bm.verts[:], edges=bm.edges[:])
	for v in bm.verts:
		v.co.y += side * lift
	bm.transform(mi)
	me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
	p = bpy.data.objects.new(name, me); TS.objects.link(p)
	p.parent = o.parent; p.parent_type = o.parent_type; p.parent_bone = o.parent_bone
	p.matrix_parent_inverse = o.matrix_parent_inverse.copy(); p.matrix_basis = o.matrix_basis.copy()
	me.materials.append(bpy.data.materials[mat])
	so = p.modifiers.new("Thick", "SOLIDIFY"); so.thickness = thick; so.offset = 1.0 if side > 0 else -1.0
	so.use_even_offset = True; so.use_rim = True
	finish_like_stock(p, w=0)
	return p

# receiver: one long blade over the upper side band (pointed nose, raked tail)
REC_PLATE = [(0.000, 0.372), (0.040, 0.404), (1.020, 0.404), (1.058, 0.372), (1.020, 0.352), (0.120, 0.352)]
# handguard: long silver blade low on the side, sharp point forward, carrying the receiver's line
HG_PLATE = [(1.060, 0.300), (1.060, 0.170), (1.120, 0.150), (1.640, 0.150), (1.680, 0.170), (1.550, 0.232), (1.110, 0.300)]
for s in (1, -1):
	surface_plate("Vandal_Receiver", "TS_RecPlate%+d" % s, REC_PLATE, s)
	surface_plate("Vandal_Handguard", "TS_GuardPlate%+d" % s, HG_PLATE, s)

bpy.data.objects["Vandal_Neon"].hide_render = True
bpy.data.objects["Vandal_Neon"]["ts_replaced"] = True
bpy.data.objects["Vandal_Neon"].hide_set(True)
bpy.ops.wm.save_mainfile()
result = {"ts": sorted(o.name for o in TS.objects)}
