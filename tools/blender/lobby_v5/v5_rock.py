"""Lobby V5 rock kit, built in the live Blender MCP instance (send with tools/blender/lobby_v4/send.py --port 9897).

Faceted cavern rock: flat triangle facets, no smoothing, no round shapes (gauntlet-build-style).
1 Blender unit = 1 stud. Width = X, height = Z, depth = Y; the rock face points to -Y, flat back at y = 0.
Pivot = bottom centre of the back face. Box-projected UVs, 1 UV unit = UV_STUDS studs, so a MaterialVariant
(Slate02c) tiles at a steady size on every piece.

    exec(open(path).read()); build_all(); export_all()
"""
import math
import os
import random

import bmesh
import bpy

REPO = r"C:\Users\charl\Documents\GauntletGame\GlitchedGauntletGame"
OUT = os.path.join(REPO, "art-source", "lobby", "v5", "Exports")
UV_STUDS = 12.0

# name: (width, height, max depth, cols, rows, seed)
WALLS = {
	"V5_RockWall_A": (24, 48, 12, 3, 6, 11),
	"V5_RockWall_B": (24, 48, 13, 3, 5, 23),
	"V5_RockWall_C": (24, 48, 11, 4, 6, 37),
	"V5_RockLow_A": (24, 16, 8, 3, 2, 51),  # low piece for over doorways and under ledges
}
CEIL = {"V5_RockCeil_A": (48, 48, 14, 5, 5, 71)}
# chimney pieces: the top edge is jagged (JAG studs) so the sky opening has a rock silhouette, not a straight line
CHIMNEY = {"V5_RockChimney_A": (32, 40, 11, 4, 5, 91), "V5_RockChimney_B": (32, 40, 12, 3, 5, 113)}
JAG = 16.0


def _col(name):
	c = bpy.data.collections.get(name)
	if not c:
		c = bpy.data.collections.new(name)
		bpy.context.scene.collection.children.link(c)
	return c


def _mat():
	m = bpy.data.materials.get("MAT_Rock")
	if not m:
		m = bpy.data.materials.new("MAT_Rock")
		m.diffuse_color = (0.42, 0.36, 0.31, 1)
	return m


def _relief(w, h, depth, cols, rows, seed, jag=0.0):
	"""Grid of vertices with big-mass bulges plus per-vertex jitter. Border columns stay shallow so neighbours meet."""
	rnd = random.Random(seed)
	ph = [rnd.uniform(0, math.tau) for _ in range(4)]
	grid = []
	for j in range(rows + 1):
		row = []
		for i in range(cols + 1):
			u, v = i / cols, j / rows
			x = (u - 0.5) * w
			z = v * h
			edge_x = i in (0, cols)
			edge_z = j in (0, rows)
			if not edge_x:
				x += rnd.uniform(-0.28, 0.28) * w / cols
			if not edge_z:
				z += rnd.uniform(-0.28, 0.28) * h / rows
			mass = 0.55 + 0.25 * math.sin(u * 3.1 + ph[0]) * math.sin(v * 2.3 + ph[1]) + 0.2 * math.sin(v * 5.0 + ph[2])
			d = depth * max(0.1, min(1.0, mass + rnd.uniform(-0.45, 0.45)))
			if edge_x:
				d = depth * 0.35 + rnd.uniform(-0.4, 0.4)
			if edge_z:
				d *= 0.6
			if jag and j == rows:
				z = h - (rnd.uniform(0, 0.25) if edge_x else rnd.uniform(0.25, 1.0)) * jag
				d = depth * rnd.uniform(0.3, 0.9)
			row.append((x, -d, z))
		grid.append(row)
	return grid


def _panel(name, w, h, depth, cols, rows, seed, horizontal=False, jag=0.0):
	bm = bmesh.new()
	g = _relief(w, h, depth, cols, rows, seed, jag)
	vf = [[bm.verts.new(p) for p in row] for row in g]
	rnd = random.Random(seed * 7)
	for j in range(rows):
		for i in range(cols):
			a, b, c, d = vf[j][i], vf[j][i + 1], vf[j + 1][i + 1], vf[j + 1][i]
			# split each quad on a random diagonal: big triangle facets
			if rnd.random() < 0.5:
				bm.faces.new((a, b, c)); bm.faces.new((a, c, d))
			else:
				bm.faces.new((a, b, d)); bm.faces.new((b, c, d))
	# flat back and closing sides so the piece is solid from every angle
	back = [[bm.verts.new((p[0], 0.0, p[2])) for p in row] for row in g]
	for j in range(rows):  # left and right
		for i in (0, cols):
			f, bk = (vf[j][i], vf[j + 1][i]), (back[j][i], back[j + 1][i])
			bm.faces.new((f[0], bk[0], bk[1], f[1]) if i == 0 else (f[0], f[1], bk[1], bk[0]))
	for i in range(cols):  # bottom and top
		for j in (0, rows):
			f, bk = (vf[j][i], vf[j][i + 1]), (back[j][i], back[j][i + 1])
			bm.faces.new((f[0], f[1], bk[1], bk[0]) if j == 0 else (f[0], bk[0], bk[1], f[1]))
	bm.faces.new([back[0][0], back[rows][0], back[rows][cols], back[0][cols]])
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	# box-projected UVs
	uv = bm.loops.layers.uv.new("UVMap")
	for f in bm.faces:
		n = f.normal
		ax = max(range(3), key=lambda k: abs(n[k]))
		for lp in f.loops:
			co = lp.vert.co
			if ax == 0:
				lp[uv].uv = (co.y / UV_STUDS, co.z / UV_STUDS)
			elif ax == 1:
				lp[uv].uv = (co.x / UV_STUDS, co.z / UV_STUDS)
			else:
				lp[uv].uv = (co.x / UV_STUDS, co.y / UV_STUDS)
	me = bpy.data.meshes.new(name)
	bm.to_mesh(me)
	bm.free()
	for p in me.polygons:
		p.use_smooth = False
	me.materials.append(_mat())
	o = bpy.data.objects.get(name)
	if o:
		bpy.data.objects.remove(o, do_unlink=True)
	o = bpy.data.objects.new(name, me)
	_col("COL_V5_Rock").objects.link(o)
	if horizontal:
		# ceiling: lay the panel down so the rock face points down; pivot at the top-centre
		o.rotation_euler = (math.radians(-90), 0, 0)
		o.location = (0, -h / 2, 0)
	return o


def build_all():
	out = {}
	x = 0
	for name, (w, h, dep, c, r, s) in WALLS.items():
		o = _panel(name, w, h, dep, c, r, s)
		o.location.x = x
		x += w + 8
		out[name] = len(o.data.polygons)
	for name, (w, h, dep, c, r, s) in CEIL.items():
		o = _panel(name, w, h, dep, c, r, s)
		o.location = (x + w / 2, 0, 0)
		out[name] = len(o.data.polygons)
		x += w + 8
	for name, (w, h, dep, c, r, s) in CHIMNEY.items():
		o = _panel(name, w, h, dep, c, r, s, jag=JAG)
		o.location = (x + w / 2, 0, 0)
		x += w + 8
		out[name] = len(o.data.polygons)
	return out


def export_all(only=None):
	os.makedirs(OUT, exist_ok=True)
	res = {}
	for o in bpy.data.collections["COL_V5_Rock"].objects:
		if only and o.name not in only:
			continue
		loc = o.location.copy()
		o.location = (0, 0, 0)
		bpy.ops.object.select_all(action="DESELECT")
		o.select_set(True)
		bpy.context.view_layer.objects.active = o
		path = os.path.join(OUT, o.name + ".fbx")
		bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={"MESH"},
			apply_scale_options="FBX_SCALE_UNITS", use_mesh_modifiers=True, bake_anim=False)
		o.location = loc
		res[o.name] = {"tris": sum(len(p.vertices) - 2 for p in o.data.polygons), "dims": [round(v, 2) for v in o.dimensions]}
	return res
