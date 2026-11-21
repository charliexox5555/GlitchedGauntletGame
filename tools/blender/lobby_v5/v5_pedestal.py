"""Locker gun pedestal (owner 2026-11-21: the gun circle's stands "need to look better"). Run in a live Blender MCP
instance with v5_props importable: build() then export() -> art-source/lobby/v5/Exports/V5_Pedestal.fbx
(Pedestal_<Role>). Octagonal, 3.5 wide, 3.15 tall, origin at the floor centre. Crisp (props-crisp-connected): every
piece sits on the one below or in a groove cut for it; glow rings are set 0.02 under the faces they sit in.
Roles: Trim (base), Body (step, column, top), Hardware (collar), Accent (glow).
"""
import math
import os

import bmesh
import bpy

import v5_props as K

OUT = os.path.join(K.ROOT, "art-source", "lobby", "v5", "Exports", "V5_Pedestal.fbx")
COLL = "V5Pedestal"
R8 = math.pi / 8


def oct(r):
	return K.ngon(0, 0, r, 8, R8)


def pedestal():
	K._prop[0] = "Pedestal"
	K.add("Trim", K.prism(oct(1.8), "XY", 0.0, 0.35, cham=0.04, taper=(1.04, 1.0)))
	K.add("Body", K.prism(oct(1.5), "XY", 0.35, 0.62, cham=0.04))
	col = K.loft([(oct(1.0), 0.62), (oct(0.86), 2.7)], cham=0.03)
	col = K.cut(col, [K.annulus(8, 1.3, 0.84, 1.52, 1.66, rot=R8)])  # a glow band cut round the column
	K.add("Body", col)
	K.add("Accent", K.annulus(8, 0.93, 0.85, 1.535, 1.645, rot=R8))
	K.add("Hardware", K.prism(oct(1.22), "XY", 2.7, 2.9, cham=0.04))
	top = K.loft([(oct(1.3), 2.9), (oct(1.48), 3.05), (oct(1.48), 3.12), (oct(1.38), 3.18)], cham=0.02)
	top = K.cut(top, [K.annulus(8, 1.24, 1.1, 3.08, 4.0, rot=R8)])  # ring groove in the top
	top = K.cut(top, [K.prism(oct(0.95), "XY", 3.12, 4.0)])  # a shallow dish the gun turns over
	K.add("Body", top)
	K.add("Accent", K.annulus(8, 1.22, 1.12, 3.08, 3.16, rot=R8))


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
	pedestal()
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
		name = "Pedestal_" + role
		old = bpy.data.objects.get(name)
		if old:
			bpy.data.objects.remove(old)
		me = bpy.data.meshes.new(name)
		bm.to_mesh(me)
		bm.free()
		for p in me.polygons:
			p.use_smooth = False
		me.materials.append(K.mat(role))
		ob = bpy.data.objects.new(name, me)
		ob.location = (0, 70, 0)
		coll.objects.link(ob)
		out[role] = len(me.polygons)
	return out


def export():
	bpy.ops.object.select_all(action="DESELECT")
	coll = bpy.data.collections[COLL]
	for ob in coll.objects:
		ob.location = (0, 0, 0)
		ob.select_set(True)
	bpy.context.view_layer.objects.active = coll.objects[0]
	bpy.ops.export_scene.fbx(filepath=OUT, use_selection=True, object_types={"MESH"}, apply_scale_options="FBX_SCALE_UNITS", bake_anim=False)
	for ob in coll.objects:
		ob.location = (0, 70, 0)
	return {"path": OUT}
