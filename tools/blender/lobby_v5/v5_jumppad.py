"""Range jump pad (owner 2026-11-21: "I want jump pads to be made in blender to look nice"). Our design, not the
RIVALS pad (studied: square plate, corner blocks, neon octagon + inward brackets). Run in a live Blender MCP instance
after v5_props is importable:

    build()   rebuilds the V5JumpPad collection
    export()  writes art-source/lobby/v5/Exports/V5_JumpPad.fbx (JumpPad_<Role> objects)

10 x 10 footprint, about 1 stud tall, origin at the floor centre. Crisp forms, details cut in (props-crisp-connected):
a leaning base with clipped corners, a raised rim with a vent notch on each side, a recessed deck, a stepped centre
(glow ring, dark bezel, glow core), four launch chevrons pointing outward, steel clamps over the corners.
Roles: Trim (base), Body (rim), Rubber (deck), Hardware (bezel, clamps, bolts), Accent (everything that glows).
"""
import math
import os

import bmesh
import bpy

import v5_props as K

ROOT = K.ROOT
OUT = os.path.join(ROOT, "art-source", "lobby", "v5", "Exports", "V5_JumpPad.fbx")
COLL = "V5JumpPad"


def chevron(r, ang):
	"""A launch chevron at radius r on the axis at angle ang, pointing outward, 0.38 thick."""
	pts = [(-0.95, 0.0), (0.0, 0.75), (0.95, 0.0), (0.95, 0.38), (0.0, 1.13), (-0.95, 0.38)]
	bm = K.prism(pts, "XY", 0.55, 0.6)
	from mathutils import Matrix

	m = Matrix.Rotation(ang - math.pi / 2, 4, "Z") @ Matrix.Translation((0, r, 0))
	return K.xform(bm, m)


def pad():
	S, C = 5.0, 0.8
	outer = K.cham_rect(-S, S, -S, S, C)
	K.add("Trim", K.prism(outer, "XY", 0.0, 0.42, cham=0.03, taper=(1.03, 1.0)))
	rim = K.prism(K.cham_rect(-S + 0.15, S - 0.15, -S + 0.15, S - 0.15, C - 0.1), "XY", 0.4, 0.9, cham=0.04)
	cuts = [K.prism(K.cham_rect(-S + 1.05, S - 1.05, -S + 1.05, S - 1.05, C - 0.45), "XY", 0.5, 2.0)]
	for ax in ((1, 0), (-1, 0), (0, 1), (0, -1)):
		x0, x1 = (-0.8, 0.8) if ax[0] == 0 else (ax[0] * (S - 1.3), ax[0] * (S + 0.5))
		y0, y1 = (-0.8, 0.8) if ax[1] == 0 else (ax[1] * (S - 1.3), ax[1] * (S + 0.5))
		cuts.append(K.box(min(x0, x1), max(x0, x1), min(y0, y1), max(y0, y1), 0.62, 2.0))
	for c in cuts:  # one at a time: overlapping cutters in one boolean fail (v5_props weapon crate bands)
		rim = K.cut(rim, [c])
	K.add("Body", rim)
	K.add("Rubber", K.prism(K.cham_rect(-S + 1.0, S - 1.0, -S + 1.0, S - 1.0, C - 0.4), "XY", 0.4, 0.55))
	# centre: glow ring, a raised dark bezel inside it, a glowing core
	K.add("Accent", K.annulus(8, 2.75, 2.15, 0.5, 0.63, rot=math.pi / 8))
	K.add("Trim", K.annulus(8, 2.15, 1.05, 0.5, 0.76, rot=math.pi / 8, cham=0.03))
	K.add("Accent", K.prism(K.ngon(0, 0, 1.05, 8, math.pi / 8), "XY", 0.5, 0.7))
	for i in range(4):
		K.add("Accent", chevron(3.15, i * math.pi / 2))
	# corner clamps over the rim, a bolt on each
	for sx in (-1, 1):
		for sy in (-1, 1):
			cx, cy = sx * (S - 0.95), sy * (S - 0.95)
			K.add("Hardware", K.prism(K.cham_rect(cx - 0.75, cx + 0.75, cy - 0.75, cy + 0.75, 0.25), "XY", 0.5, 1.05, cham=0.03, taper=(1.0, 0.82)))
			K.add("Hardware", K.prism(K.ngon(cx, cy, 0.2, 6), "XY", 1.03, 1.12, taper=(1.0, 0.75)))


def build():
	K.PIECES.clear()
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
	K._prop[0] = "JumpPad"
	pad()
	merged = {}
	for _, role, bm in K.PIECES:
		if role not in merged:
			merged[role] = bmesh.new()
		me = bpy.data.meshes.new("_tmp")
		bm.to_mesh(me)
		merged[role].from_mesh(me)
		bpy.data.meshes.remove(me)
		bm.free()
	out = {}
	for role, bm in merged.items():
		me = bpy.data.meshes.new("JumpPad_" + role)
		bm.to_mesh(me)
		bm.free()
		for p in me.polygons:
			p.use_smooth = False
		me.materials.append(K.mat(role))
		ob = bpy.data.objects.new("JumpPad_" + role, me)
		ob.location = (0, 30, 0)
		coll.objects.link(ob)
		out[role] = len(me.polygons)
	return out


def export():
	bpy.ops.object.select_all(action="DESELECT")
	coll = bpy.data.collections[COLL]
	saved = {}
	for ob in coll.objects:
		saved[ob.name] = ob.location.copy()
		ob.location = (0, 0, 0)
		ob.select_set(True)
	bpy.context.view_layer.objects.active = coll.objects[0]
	bpy.ops.export_scene.fbx(filepath=OUT, use_selection=True, object_types={"MESH"}, apply_scale_options="FBX_SCALE_UNITS", bake_anim=False)
	for ob in coll.objects:
		ob.location = saved[ob.name]
	return {"path": OUT}
