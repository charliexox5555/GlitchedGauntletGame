# Geometry audit for the Tempest-Strike Vandal (visible parts of Vandal + Tempest): contact graph (floating
# parts), same-facing coplanar faces (z-fight), open edges (holes in one-sided Roblox rendering), inverted
# closed meshes, and the receiver's underside profile where the handle meets it.
import bpy, bmesh, math
from mathutils import Vector
from mathutils.bvhtree import BVHTree
dg = bpy.context.evaluated_depsgraph_get()
objs = []
for c in ("Vandal", "Tempest"):
	for o in bpy.data.collections[c].all_objects:
		if o.type == "MESH" and not o.hide_render and not o.get("ts_replaced") and o.visible_get():
			objs.append(o)
D = {}
for o in objs:
	ev = o.evaluated_get(dg); me = ev.to_mesh()
	bm = bmesh.new(); bm.from_mesh(me); bm.transform(o.matrix_world); bm.normal_update()
	D[o.name] = {"bm": bm, "bvh": BVHTree.FromBMesh(bm)}
	ev.to_mesh_clear()
names = list(D)
touch = {n: set() for n in names}
zf = []
for i, a in enumerate(names):
	A = D[a]
	verts = A["bm"].verts[:]
	step = max(1, len(verts) // 400)
	for b in names[i + 1:]:
		B = D[b]
		hit = bool(A["bvh"].overlap(B["bvh"]))
		if not hit:
			for v in verts[::step]:
				loc, n, idx, d = B["bvh"].find_nearest(v.co, 0.0015)
				if loc is not None:
					hit = True; break
		if not hit:
			bv = B["bm"].verts[:]
			for v in bv[::max(1, len(bv) // 400)]:
				loc, n, idx, d = A["bvh"].find_nearest(v.co, 0.0015)
				if loc is not None:
					hit = True; break
		if hit:
			touch[a].add(b); touch[b].add(a)
			# same-facing coplanar faces (both visible -> flicker)
			faces = A["bm"].faces[:]; fs = max(1, len(faces) // 300); cnt = 0
			for f in faces[::fs]:
				c = f.calc_center_median()
				loc, n, idx, d = B["bvh"].find_nearest(c, 0.0006)
				if loc is not None and n.dot(f.normal) > 0.995 and f.calc_area() > 1e-6:
					cnt += 1
			if cnt:
				zf.append((a, b, cnt))
# connected components from the receiver
seen = set(); st = ["Vandal_Receiver"]
while st:
	n = st.pop()
	if n in seen:
		continue
	seen.add(n); st += list(touch[n])
floating = sorted(set(names) - seen)
holes = {}; inverted = []
for n in names:
	bm = D[n]["bm"]
	ob = sum(1 for e in bm.edges if e.is_boundary)
	if ob:
		holes[n] = ob
	if ob == 0 and len(bm.faces):
		vol = bm.calc_volume(signed=True)
		if vol < 0:
			inverted.append(n)
# receiver underside z (min) at x stations around the handle
rec = D["Vandal_Receiver"]["bm"]
under = {}
for x in [-0.18, -0.15, -0.12, -0.09, -0.06, -0.03, 0.0, 0.05, 0.10, 0.15]:
	zs = [v.co.z for v in rec.verts if abs(v.co.x - x) < 0.02 and abs(v.co.y) < 0.03]
	under[x] = round(min(zs), 3) if zs else None
for n in D:
	D[n]["bm"].free()
result = {"parts": len(names), "floating": floating, "zfight": zf, "open_edges": holes, "inverted": inverted,
	"rec_underside": under, "lonely": {n: sorted(touch[n]) for n in names if len(touch[n]) <= 1}}
