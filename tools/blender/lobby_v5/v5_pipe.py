"""Lobby V5 pipe kit (live Blender MCP, port 9897). 8-sided prisms, flat shading, no round shapes.

V5_Pipe8: 1 x 1 cross-section (across flats), length 1 along X, centred; scaled with MeshPart.Size in Studio.
V5_Flange8: 1 x 1 x 1 octagonal collar with chamfered rims (two 45-degree facets each side).
Box-projected UVs at 4 studs per tile.
"""
import math
import os

import bmesh
import bpy

REPO = r"C:\Users\charl\Documents\GauntletGame\GlitchedGauntletGame"
OUT = os.path.join(REPO, "art-source", "lobby", "v5", "Exports")


def _ring(bm, x, r):
	# octagon across flats = 2r: vertex radius r / cos(22.5)
	rv = r / math.cos(math.pi / 8)
	return [bm.verts.new((x, rv * math.cos(math.pi / 8 + k * math.pi / 4), rv * math.sin(math.pi / 8 + k * math.pi / 4))) for k in range(8)]


def _loft(bm, rings):
	for a, b in zip(rings, rings[1:]):
		for k in range(8):
			bm.faces.new((a[k], a[(k + 1) % 8], b[(k + 1) % 8], b[k]))
	bm.faces.new(list(reversed(rings[0])))
	bm.faces.new(rings[-1])


def _obj(name, bm):
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	uv = bm.loops.layers.uv.new("UVMap")
	for f in bm.faces:
		ax = max(range(3), key=lambda k: abs(f.normal[k]))
		for lp in f.loops:
			c = lp.vert.co
			lp[uv].uv = ((c.y, c.z) if ax == 0 else (c.x, c.z) if ax == 1 else (c.x, c.y))
	me = bpy.data.meshes.new(name)
	bm.to_mesh(me)
	bm.free()
	for p in me.polygons:
		p.use_smooth = False
	o = bpy.data.objects.get(name)
	if o:
		bpy.data.objects.remove(o, do_unlink=True)
	o = bpy.data.objects.new(name, me)
	col = bpy.data.collections.get("COL_V5_Props") or bpy.data.collections.new("COL_V5_Props")
	if col.name not in bpy.context.scene.collection.children:
		bpy.context.scene.collection.children.link(col)
	col.objects.link(o)
	return o


def build():
	bm = bmesh.new()
	_loft(bm, [_ring(bm, -0.5, 0.5), _ring(bm, 0.5, 0.5)])
	p = _obj("V5_Pipe8", bm)
	bm = bmesh.new()
	_loft(bm, [_ring(bm, -0.5, 0.36), _ring(bm, -0.3, 0.5), _ring(bm, 0.3, 0.5), _ring(bm, 0.5, 0.36)])
	f = _obj("V5_Flange8", bm)
	f.location.y = 3
	return {"pipe": len(p.data.polygons), "flange": len(f.data.polygons)}


def export():
	res = {}
	for n in ("V5_Pipe8", "V5_Flange8"):
		o = bpy.data.objects[n]
		loc = o.location.copy()
		o.location = (0, 0, 0)
		bpy.ops.object.select_all(action="DESELECT")
		o.select_set(True)
		bpy.context.view_layer.objects.active = o
		bpy.ops.export_scene.fbx(filepath=os.path.join(OUT, n + ".fbx"), use_selection=True, object_types={"MESH"},
			apply_scale_options="FBX_SCALE_UNITS", bake_anim=False)
		o.location = loc
		res[n] = [round(v, 3) for v in o.dimensions]
	return res
