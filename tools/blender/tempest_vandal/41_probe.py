import bpy, bmesh
from collections import Counter
out = {}
def zhist(name, axis=2, nd=3):
	o = bpy.data.objects[name]
	c = Counter(round(v.co[axis], nd) for v in o.data.vertices)
	return sorted(c.items())
out["rail_z"] = zhist("Vandal_Rail")
o = bpy.data.objects["Vandal_Rail"]; bm = bmesh.new(); bm.from_mesh(o.data)
isl = 0; seen = set()
for v in bm.verts:
	if v.index in seen: continue
	isl += 1; st = [v]
	while st:
		a = st.pop()
		if a.index in seen: continue
		seen.add(a.index)
		for e in a.link_edges: st.append(e.other_vert(a))
out["rail_islands"] = isl
# stock silhouette: +Y side outline points (x,z) of verts with y > max-0.002
s = bpy.data.objects["Vandal_Stock"]
ymax = max(v.co.y for v in s.data.vertices)
pts = sorted({(round(v.co.x, 3), round(v.co.z, 3)) for v in s.data.vertices if v.co.y > ymax - 0.003})
out["stock_ymax"] = ymax; out["stock_side_pts"] = pts
r = bpy.data.objects["Vandal_RearSight"]
out["rs_x"] = sorted(Counter(round(v.co.x, 3) for v in r.data.vertices).items())
out["mw"] = [m.name for m in o.matrix_world.row] if False else None
result = out
