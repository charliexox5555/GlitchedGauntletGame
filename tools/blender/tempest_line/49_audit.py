# Geometry audit (adapted from tempest_vandal/49_audit.py) for the visible parts of <GUN> + Tempest, evaluated
# meshes in world space: contact graph from the receiver (floating parts), same-facing coplanar faces between
# touching parts (z-fight), open edges, inverted closed meshes. Bone-riding parts are tested at the rest pose.
exec(open(r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/tools/blender/tempest_line/ts_lib.py").read())
from mathutils.bvhtree import BVHTree
ROOTPART = globals().get("ROOTPART", "TS_Receiver")
for a in bpy.data.objects:
	if a.type == "ARMATURE":
		a.data.pose_position = "REST"
bpy.context.view_layer.update()
dg = bpy.context.evaluated_depsgraph_get()
objs = [o for o in visible_model()]
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
	A = D[a]; verts = A["bm"].verts[:]; step = max(1, len(verts) // 400)
	for b in names[i + 1:]:
		B = D[b]
		hit = bool(A["bvh"].overlap(B["bvh"]))
		if not hit:
			for v in verts[::step]:
				if B["bvh"].find_nearest(v.co, 0.0015)[0] is not None:
					hit = True; break
		if not hit:
			bv = B["bm"].verts[:]
			for v in bv[::max(1, len(bv) // 400)]:
				if A["bvh"].find_nearest(v.co, 0.0015)[0] is not None:
					hit = True; break
		if hit:
			touch[a].add(b); touch[b].add(a)
			for X, Y, xn, yn in ((A, B, a, b), (B, A, b, a)):
				faces = X["bm"].faces[:]; fs = max(1, len(faces) // 300); cnt = 0
				for f in faces[::fs]:
					loc, n, idx, d = Y["bvh"].find_nearest(f.calc_center_median(), 0.0006)
					if loc is not None and n.dot(f.normal) > 0.995 and f.calc_area() > 1e-6:
						cnt += 1
				if cnt:
					zf.append((xn, yn, cnt)); break
seen = set(); st = [ROOTPART]
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
	if ob == 0 and len(bm.faces) and bm.calc_volume(signed=True) < 0:
		inverted.append(n)
for n in D:
	D[n]["bm"].free()
for a in bpy.data.objects:
	if a.type == "ARMATURE":
		a.data.pose_position = "POSE"
result = {"parts": len(names), "floating": floating, "zfight": zf, "open_edges": holes, "inverted": inverted,
	"lonely": {n: sorted(touch[n]) for n in names if len(touch[n]) <= 1}}
