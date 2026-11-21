# Tempest-Strike Vandal s01, stage B: leather wraps and hydro conduits cut from the stock grip and magazine
# surfaces (they follow the real shape and ride the right bone: grip = Root, magazine = Mag).
import bpy, bmesh, math
from mathutils import Vector
TS = bpy.data.collections["Tempest"]
for o in list(TS.objects):
	if o.name.startswith(("TS_Wrap", "TS_Conduit")):
		bpy.data.objects.remove(o, do_unlink=True)

def surface_band(src, name, axis, lo, hi, mat, lift=0.0012, thick=0.006, side_only=0.75):
	"""Faces of src between two planes (normal `axis`, offsets lo..hi), cut exactly at the planes, pushed out
	along the vertex normals and thickened: a sleeve that follows the part."""
	o = bpy.data.objects[src]
	mw = o.matrix_world; mi = mw.inverted()
	ax = Vector(axis).normalized()
	bm = bmesh.new(); bm.from_mesh(o.data); bm.transform(mw)
	for d in (lo, hi):
		bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=ax * d, plane_no=ax)
	keep = [f for f in bm.faces if lo < f.calc_center_median().dot(ax) < hi and abs(f.normal.dot(ax)) < side_only
		and not (src == "Vandal_Grip" and (f.calc_center_median().x > 0.16 or f.calc_center_median().z > 0.03))]
	bmesh.ops.delete(bm, geom=[f for f in bm.faces if f not in set(keep)], context="FACES")
	bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(1.0), verts=bm.verts[:], edges=bm.edges[:])
	bm.normal_update()
	bm.transform(mi)
	me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
	p = bpy.data.objects.new(name, me); TS.objects.link(p)
	p.parent = o.parent; p.parent_type = o.parent_type; p.parent_bone = o.parent_bone
	p.matrix_parent_inverse = o.matrix_parent_inverse.copy(); p.matrix_basis = o.matrix_basis.copy()
	me.materials.append(bpy.data.materials[mat])
	so = p.modifiers.new("Thick", "SOLIDIFY"); so.thickness = thick; so.offset = 1.0; so.use_even_offset = False; so.use_quality_normals = True; so.thickness = thick + lift
	so.use_rim = True
	for f in me.polygons:
		f.use_smooth = True
	wn = p.modifiers.new("WeightedNormal", "WEIGHTED_NORMAL"); wn.keep_sharp = True; wn.weight = 50
	return p

# magazine: three leather bands with two cyan conduits between them; axis follows the mag's rake
mag = bpy.data.objects["Vandal_Mag"]
MAX = (0.30, 0, -0.954)                       # roughly along the magazine body (down and forward)
for i, (lo, hi) in enumerate(((0.170, 0.280), (0.310, 0.420), (0.450, 0.560))):
	surface_band("Vandal_Mag", "TS_WrapMag%d" % i, MAX, lo, hi, "Grip", thick=0.0065)
for i, (lo, hi) in enumerate(((0.289, 0.301), (0.429, 0.441))):
	surface_band("Vandal_Mag", "TS_ConduitMag%d" % i, MAX, lo, hi, "Neon", lift=0.0006, thick=0.0025)
# grip: four slanted bands, alternating tilt (tsuka-maki rhythm), below the trigger guard
for i, (lo, hi, tilt) in enumerate(((0.035, 0.085, 12), (0.101, 0.151, 12), (0.167, 0.217, 12))):
	a = math.radians(tilt)
	surface_band("Vandal_Grip", "TS_WrapGrip%d" % i, (math.sin(a), 0, -math.cos(a)), lo, hi, "Grip", thick=0.0055)
# leather reads smooth: flatten the stock rubber pattern on the Grip role
for n in bpy.data.materials['Grip'].node_tree.nodes:
	if n.type == 'BUMP':
		n.inputs['Strength'].default_value = 0.0
cr = next((n for n in bpy.data.materials['Grip'].node_tree.nodes if n.type == 'VALTORGB'), None)
if cr:
	c0 = cr.color_ramp.elements[0].color[:]
	cr.color_ramp.elements[1].color = c0
bpy.ops.wm.save_mainfile()
result = {"made": sorted(o.name for o in TS.objects if o.name.startswith(("TS_Wrap", "TS_Conduit"))),
	"faces": {o.name: len(o.data.polygons) for o in TS.objects if o.name.startswith(("TS_Wrap", "TS_Conduit"))}}
