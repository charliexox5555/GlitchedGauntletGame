"""Clash audit: triangles of one piece that cut through another piece (owner 2026-11-16: bar lamp into gallery,
vent into bench). Different pieces = different top-level group paths (custom property "g"). Run after build_all().

    import v4_clash; v4_clash.run(area="Concourse")
"""
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

import sw_core as S


def _top(g):
	return (g or "").split("/")[0]


def run(area=None, limit=60, ignore=("V_Slab", "V_Floor", "V_Floor2", "V_Ceil", "V_Wall")):
	"""Pairs of objects in different pieces whose triangles intersect. Objects whose material is in `ignore` on BOTH
	sides are skipped (shell against shell is the room itself)."""
	dg = bpy.context.evaluated_depsgraph_get()
	obs = []
	for col in bpy.data.collections[S.ROOT].children:
		if area and not col.name.startswith(area):
			continue
		for o in col.objects:
			if o.type != "MESH":
				continue
			e = o.evaluated_get(dg)
			me = e.to_mesh()
			vs = [o.matrix_world @ v.co for v in me.vertices]
			polys = [tuple(p.vertices) for p in me.polygons]
			e.to_mesh_clear()
			if not polys:
				continue
			lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
			hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
			mat = o.data.materials[0].name if o.data.materials else ""
			obs.append((o.name, o.get("g") or "", mat, lo, hi, BVHTree.FromPolygons(vs, polys)))
	found = {}
	for i in range(len(obs)):
		a = obs[i]
		for j in range(i + 1, len(obs)):
			b = obs[j]
			if _top(a[1]) == _top(b[1]):
				continue
			if a[2] in ignore and b[2] in ignore:
				continue
			if any(a[4][k] < b[3][k] - 0.01 or b[4][k] < a[3][k] - 0.01 for k in range(3)):
				continue
			hits = a[5].overlap(b[5])
			if hits:
				key = tuple(sorted((a[1] or a[0], b[1] or b[0])))
				c = (a[3] + a[4] + b[3] + b[4]) / 4
				d = found.setdefault(key, [0, (round(c.x, 1), round(c.y, 1), round(c.z, 1)), a[2], b[2]])
				d[0] += len(hits)
	rows = sorted(([k[0], k[1], v[2], v[3], v[0], v[1]] for k, v in found.items()), key=lambda r: -r[4])
	return {"pairs": len(rows), "rows": rows[:limit]}
