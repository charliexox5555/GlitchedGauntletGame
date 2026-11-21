# Report mesh islands (bounds, face count, main material) of chosen stock parts and sections at x stations.
exec(open(r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/tools/blender/tempest_line/ts_lib.py").read())
PARTS = globals().get("PARTS", [])
SECT = globals().get("SECT", {})
out = {}
for n in PARTS:
	o = bpy.data.objects[n]
	bm = bmesh.new(); bm.from_mesh(o.data); bm.transform(o.matrix_world)
	seen = set(); isl = []
	for f in bm.faces:
		if f.index in seen:
			continue
		st = [f]; grp = []
		while st:
			a = st.pop()
			if a.index in seen:
				continue
			seen.add(a.index); grp.append(a)
			for e in a.edges:
				for g in e.link_faces:
					if g.index not in seen:
						st.append(g)
		vs = {v for g in grp for v in g.verts}
		lo = [round(min(v.co[i] for v in vs), 3) for i in range(3)]; hi = [round(max(v.co[i] for v in vs), 3) for i in range(3)]
		from collections import Counter
		mc = Counter(o.data.materials[g.material_index].name for g in grp).most_common(2)
		isl.append({"lo": lo, "hi": hi, "f": len(grp), "mat": mc})
	out[n] = sorted(isl, key=lambda d: d["lo"][0])
	bm.free()
sec = {}
for n, xs in SECT.items():
	sec[n] = {x: section_at(n, x) for x in xs}
result = {"islands": out, "sections": sec}
