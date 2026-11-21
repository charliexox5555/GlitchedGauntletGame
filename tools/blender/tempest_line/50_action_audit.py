# Sweep every stock action of <GUN> and test the moving parts (children of animated bones) against the static parts:
# interpenetration (BVH overlap of evaluated meshes) and same-facing coplanar faces (flicker) at sampled frames.
exec(open(r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/tools/blender/tempest_line/ts_lib.py").read())
from mathutils.bvhtree import BVHTree
SRC = globals().get("SRC")
if SRC:
	bpy.ops.wm.open_mainfile(filepath=ROOT + SRC)
	exec(open(ROOT + "tools/blender/tempest_line/ts_lib.py").read())
rig = bpy.data.objects[G("Rig")]
sc = bpy.context.scene
objs = visible_model()
out = {"actions": {}}
for act in bpy.data.actions:
	if not act.name.startswith(GUN):
		continue
	bones = {}
	fcs = []
	if hasattr(act, "fcurves"):
		fcs = list(act.fcurves)
	else:
		for L in act.layers:
			for stp in L.strips:
				for cb in stp.channelbags:
					fcs += list(cb.fcurves)
	for fc in fcs:
		if fc.data_path.startswith('pose.bones["'):
			b = fc.data_path.split('"')[1]
			ks = [k.co[1] for k in fc.keyframe_points]
			if ks and max(ks) - min(ks) > 1e-5:
				bones.setdefault(b, set()).add(fc.data_path.split(".")[-1])
	out["actions"][act.name] = {"bones": {b: sorted(v) for b, v in bones.items()}, "range": list(act.frame_range)}
rig.animation_data_create()
report = {}
for an, info in out["actions"].items():
	moving_bones = set(info["bones"]) - {"Root", "Charm"}
	movers = [o for o in objs if o.parent == rig and o.parent_bone in moving_bones]
	statics = [o for o in objs if o not in movers and not (o.parent == rig and o.parent_bone == "Charm")]
	# baseline contacts at rest (the designed, buried joins)
	rig.animation_data.action = None; sc.frame_set(0)
	dg0 = bpy.context.evaluated_depsgraph_get()
	def bvh0(o):
		ev = o.evaluated_get(dg0); me = ev.to_mesh(); bm = bmesh.new(); bm.from_mesh(me); bm.transform(o.matrix_world); ev.to_mesh_clear()
		t = BVHTree.FromBMesh(bm); bm.free(); return t
	B0 = {o.name: bvh0(o) for o in movers + statics}
	base = {(m.name, s_.name) for m in movers for s_ in statics if B0[m.name].overlap(B0[s_.name])}
	rig.animation_data.action = bpy.data.actions[an]
	try:
		if bpy.data.actions[an].slots:
			rig.animation_data.action_slot = bpy.data.actions[an].slots[0]
	except AttributeError:
		pass
	f0, f1 = int(info["range"][0]), int(info["range"][1])
	hits = {}
	for fr in range(f0, f1 + 1, max(1, (f1 - f0) // 24)):
		sc.frame_set(fr)
		dg = bpy.context.evaluated_depsgraph_get()
		def bvh(o):
			ev = o.evaluated_get(dg); me = ev.to_mesh(); bm = bmesh.new(); bm.from_mesh(me); bm.transform(o.matrix_world); bm.normal_update(); ev.to_mesh_clear()
			return bm, BVHTree.FromBMesh(bm)
		S = {o.name: bvh(o) for o in statics}
		for mo in movers:
			bm, tr = bvh(mo)
			for sn, (sbm, st) in S.items():
				ov = tr.overlap(st)
				cop = 0
				if ov:
					for f in bm.faces[:][::max(1, len(bm.faces) // 200)]:
						loc, n, idx, d = st.find_nearest(f.calc_center_median(), 0.0006)
						if loc is not None and n.dot(f.normal) > 0.995:
							cop += 1
				if ov and ((mo.name, sn) not in base or cop):
					k = (mo.name, sn); h = hits.setdefault("|".join(k), {"frames": [], "pairs": 0, "coplanar": 0})
					h["frames"].append(fr); h["pairs"] = max(h["pairs"], len(ov))
					h["coplanar"] = max(h["coplanar"], cop); h["new"] = (mo.name, sn) not in base
			bm.free()
		for sbm, st in S.values():
			sbm.free()
	report[an] = {"movers": [o.name for o in movers], "hits": {k: {"frames": [v["frames"][0], v["frames"][-1], len(v["frames"])], "pairs": v["pairs"], "coplanar": v["coplanar"], "new": v["new"]} for k, v in hits.items()}}
rig.animation_data.action = None
sc.frame_set(0)
thin = {}
for o in objs:
	dims = sorted(o.dimensions)
	if dims[0] < 0.0025:
		thin[o.name] = [round(d, 4) for d in dims]
result = {"actions": out["actions"], "contacts": report, "thin": thin}
