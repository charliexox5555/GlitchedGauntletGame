# final_geo.py: the final geometry test for RemasterV2 weapons (2026-11-11). Blender MCP only; works on the gun
# loaded in this session (final_pass.load), at rest.
#   G["bind"](F)
#   G["holes"](gun)    open mesh borders the player can see through. Roblox draws faces one-sided, so an open
#                      border that is not sealed against (or buried in) another solid shows the inside of the part
#                      as nothing (the Phantom suppressor's missing back).
#   G["zfight"](gun)   coplanar overlapping faces of two different islands (flicker), split by same / other material.
#   G["floating"](gun) loose islands that touch nothing (parts_check, tol 0.0015).
#   G["report"](gun)   all three + triangle count.

import bpy, bmesh, math
from mathutils import Vector
from mathutils.bvhtree import BVHTree

F = {}
ROOT = r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/art-source/weapons/RemasterV2"
ROLES = ["Body", "Panel", "Dark", "Metal", "Grip", "Accent", "Neon", "Brass", "Glass"]


def bind(ns):
	F.update(ns)


def _islands(gun):
	# [(part, role, verts(world), tris, bm_faces_info, boundary_edges[(a, b)])] per loose island at rest.
	out = []
	for ob in F["meshes"](gun):
		bm = bmesh.new()
		bm.from_mesh(ob.data)
		bm.transform(ob.matrix_world)
		bmesh.ops.triangulate(bm, faces=bm.faces[:])
		bm.faces.ensure_lookup_table()
		seen = set()
		for f in bm.faces:
			if f.index in seen:
				continue
			st, fs = [f], []
			seen.add(f.index)
			while st:
				c = st.pop()
				fs.append(c)
				for e in c.edges:
					for n in e.link_faces:
						if n.index not in seen:
							seen.add(n.index)
							st.append(n)
			vs = list({v for x in fs for v in x.verts})
			vi = {v: i for i, v in enumerate(vs)}
			co = [v.co.copy() for v in vs]
			tris = [[vi[v] for v in x.verts] for x in fs]
			mats = [x.material_index for x in fs]
			fset = set(fs)
			border = []
			for x in fs:
				for e in x.edges:
					if len([lf for lf in e.link_faces if lf in fset]) == 1 and len(e.link_faces) == 1:
						border.append((e.verts[0].co.copy(), e.verts[1].co.copy(), x.normal.copy()))
			out.append({"part": ob.name[len(gun) + 1:], "bone": ob.parent_bone, "co": co, "tris": tris, "mats": mats, "border": border,
				"tree": BVHTree.FromPolygons(co, tris), "lo": Vector([min(c[i] for c in co) for i in range(3)]), "hi": Vector([max(c[i] for c in co) for i in range(3)])})
		bm.free()
	return out


def _inside(p, isl):
	# Ray parity against a (mostly closed) island: inside if two of three rays cross an odd number of faces.
	votes = 0
	for d in (Vector((0.5774, 0.5774, 0.5774)), Vector((-0.7071, 0.1, 0.7)), Vector((0.2, -0.9, 0.38))):
		d = d.normalized()
		o = p.copy()
		n = 0
		for _ in range(64):
			h = isl["tree"].ray_cast(o, d, 20.0)
			if h[0] is None:
				break
			n += 1
			o = h[0] + d * 1e-5
		votes += n % 2
	return votes >= 2


def holes(gun, seal=0.0016, min_len=0.004):
	isl = _islands(gun)
	found = []
	for i, a in enumerate(isl):
		if not a["border"]:
			continue
		exposed = []
		near = [b for j, b in enumerate(isl) if j != i and all(a["lo"][k] <= b["hi"][k] + 0.01 and b["lo"][k] <= a["hi"][k] + 0.01 for k in range(3))]
		for p0, p1, nrm in a["border"]:
			mid = (p0 + p1) / 2
			ok = False
			for b in near:
				h = b["tree"].find_nearest(mid)
				if h[0] is not None and h[3] <= seal:
					ok = True
					break
			if not ok:
				for b in near:
					if _inside(mid, b):
						ok = True
						break
			if not ok:
				exposed.append((p0, p1))
		total = sum((p1 - p0).length for p0, p1 in exposed)
		if exposed and total >= min_len:
			pts = [p for e in exposed for p in e]
			lo = [round(min(p[k] for p in pts), 3) for k in range(3)]
			hi = [round(max(p[k] for p in pts), 3) for k in range(3)]
			found.append({"part": a["part"], "role": ROLES[a["mats"][0]] if a["mats"][0] < len(ROLES) else "?", "edges": len(exposed), "len": round(total, 3), "lo": lo, "hi": hi})
	return found


def zfight(gun, plane=0.0004, min_area=2e-5):
	isl = _islands(gun)
	out = {}
	for i, a in enumerate(isl):
		for j in range(i + 1, len(isl)):
			b = isl[j]
			if a["bone"] != b["bone"]:
				continue  # moving against static: judged in the clips, not at rest
			if not all(a["lo"][k] <= b["hi"][k] and b["lo"][k] <= a["hi"][k] for k in range(3)):
				continue
			area = {"same": 0.0, "diff": 0.0}
			lo = [9, 9, 9]
			hi = [-9, -9, -9]
			for ta, tb in a["tree"].overlap(b["tree"]):
				A = [a["co"][k] for k in a["tris"][ta]]
				B = [b["co"][k] for k in b["tris"][tb]]
				na = (A[1] - A[0]).cross(A[2] - A[0])
				nb = (B[1] - B[0]).cross(B[2] - B[0])
				if na.length < 1e-12 or nb.length < 1e-12:
					continue
				aa, ab = na.length / 2, nb.length / 2
				na.normalize()
				nb.normalize()
				if na.dot(nb) < 0.9995:
					continue
				if max(abs((p - A[0]).dot(na)) for p in B) > plane:
					continue
				# overlapping area estimate: the smaller triangle's area when its centroid lies in the other
				ca, cb = (A[0] + A[1] + A[2]) / 3, (B[0] + B[1] + B[2]) / 3
				def _in(p, T, n):
					for k in range(3):
						if (T[(k + 1) % 3] - T[k]).cross(p - T[k]).dot(n) < -1e-9:
							return False
					return True
				if not (_in(cb, A, na) or _in(ca, B, nb)):
					continue
				key = "same" if a["mats"][ta] == b["mats"][tb] else "diff"
				area[key] += min(aa, ab)
				for p in A:
					for k in range(3):
						lo[k] = min(lo[k], p[k])
						hi[k] = max(hi[k], p[k])
			for key in ("same", "diff"):
				if area[key] >= min_area:
					name = "%s|%s" % (a["part"], b["part"])
					d = out.setdefault(name, {"same": 0.0, "diff": 0.0, "lo": lo, "hi": hi})
					d[key] = round(d[key] + area[key], 5)
	return [{"pair": k, "same": v["same"], "diff": v["diff"], "lo": [round(x, 3) for x in v["lo"]], "hi": [round(x, 3) for x in v["hi"]]} for k, v in out.items()]


def floating(gun, tol=0.0016):
	ns = {}
	p = ROOT + "/_Library/parts_check.py"
	exec(compile(open(p).read(), p, "exec"), ns)
	return ns["check"](gun, tol)["floating"]


def report(gun):
	F["rest"](gun)
	return {"tris": F["tris"](gun), "floating": floating(gun), "holes": holes(gun), "zfight": [z for z in zfight(gun) if z["diff"] > 0]}


# ---------------------------------------------------------------- see-through test (what Roblox would show)

def _bf_material():
	m = bpy.data.materials.get("FP_BackfaceTest")
	if m is None:
		m = bpy.data.materials.new("FP_BackfaceTest")
		m.use_nodes = True
		nt = m.node_tree
		nt.nodes.clear()
		out = nt.nodes.new("ShaderNodeOutputMaterial")
		em = nt.nodes.new("ShaderNodeEmission")
		geo = nt.nodes.new("ShaderNodeNewGeometry")
		mix = nt.nodes.new("ShaderNodeMix")
		mix.data_type = "RGBA"
		mix.inputs["A"].default_value = (0, 1, 0, 1)  # front faces: green
		mix.inputs["B"].default_value = (1, 0, 0, 1)  # back faces: red (Roblox draws nothing there)
		nt.links.new(geo.outputs["Backfacing"], mix.inputs["Factor"])
		nt.links.new(mix.outputs["Result"], em.inputs["Color"])
		nt.links.new(em.outputs["Emission"], out.inputs["Surface"])
		m.use_backface_culling = False
	return m


DIRS = {
	"left": (0, 1, 0), "right": (0, -1, 0), "top": (0, 0.001, 1), "bottom": (0, 0.001, -1), "front": (1, 0, 0), "back": (-1, 0, 0),
	"fp_hip": (-0.75, 0.42, 0.36), "fp_low": (-0.8, 0.5, 0.05), "back_r": (-0.75, -0.42, 0.36), "front_l": (0.6, 0.6, 0.3),
	"front_r": (0.6, -0.6, 0.3), "under_l": (-0.4, 0.5, -0.6), "under_r": (0.4, -0.5, -0.6), "top_fl": (0.5, 0.3, 0.8), "top_bl": (-0.5, 0.3, 0.8),
	"back_l_flat": (-0.9, 0.3, 0.1), "back_r_flat": (-0.9, -0.3, 0.1), "front_low": (0.9, 0.2, -0.2),
}


def backfaces(gun, out_dir, res=(1280, 720), keep_over=0):
	# Renders the gun from 18 directions with back faces painted red. Returns red pixel counts per view and writes
	# the pictures of the views that show any.
	import os, numpy as np
	sc = F["scene"](gun)
	bpy.context.window.scene = sc
	F["rest"](gun)
	vl = sc.view_layers[0]
	lo, hi = F["bounds"](gun)
	c = (lo + hi) / 2
	size = (hi - lo).length
	old = (vl.material_override, sc.view_settings.view_transform, sc.view_settings.look, sc.eevee.taa_render_samples)
	vl.material_override = _bf_material()
	sc.view_settings.view_transform = "Standard"
	sc.view_settings.look = "None"
	os.makedirs(out_dir, exist_ok=True)
	counts = {}
	try:
		for name, d in DIRS.items():
			v = Vector(d).normalized()
			cam = F["camera"](gun, "BF", tuple(c + v * (size * 2 + 1)), tuple(c), ortho=size * 1.08)
			path = "%s/%s_%s.png" % (out_dir, gun, name)
			F["shot"](gun, cam, path, res=res, rng=False, samples=1)
			img = bpy.data.images.load(path)
			px = np.empty(res[0] * res[1] * 4, dtype=np.float32)
			img.pixels.foreach_get(px)
			bpy.data.images.remove(img)
			px = px.reshape(res[1], res[0], 4)
			r = (px[:, :, 0] > 0.6) & (px[:, :, 1] < 0.3)
			# Only patches at least 2 px thick count: a 1 px line is two touching or edge-on surfaces, which Roblox
			# (back faces culled) never shows.
			thick = r[:-1, :-1] & r[1:, :-1] & r[:-1, 1:] & r[1:, 1:]
			red = int(thick.sum())
			counts[name] = red
			if red <= keep_over:
				os.remove(path)
	finally:
		vl.material_override = old[0]
		sc.view_settings.view_transform = old[1]
		try:
			sc.view_settings.look = old[2]
		except Exception:
			pass
		sc.eevee.taa_render_samples = old[3]
	return {k: v for k, v in counts.items() if v > 0}


# ---------------------------------------------------------------- sealing open borders

def seal(gun, seal_tol=0.0016, min_len=0.003, parts=None, force=False):
	# Closes every open border that is NOT sealed against or buried in another solid (the builders' hidden-face
	# cull left some borders a hair outside their occluder; a few caps were dropped on purpose and are in view).
	# Each such border loop gets its face(s) back, with the neighbouring material. Returns {part: faces added}.
	all_isl = _islands(gun)
	done = {}
	for ob in F["meshes"](gun):
		part = ob.name[len(gun) + 1:]
		if parts is not None and part not in parts:
			continue
		me = ob.data
		bm = bmesh.new()
		bm.from_mesh(me)
		bm.edges.ensure_lookup_table()
		border = [e for e in bm.edges if len(e.link_faces) == 1]
		if not border:
			bm.free()
			continue
		mw = ob.matrix_world
		# face islands (to know which island a border edge belongs to)
		isl_of = {}
		seen = set()
		bm.faces.ensure_lookup_table()
		boxes = []
		for f in bm.faces:
			if f.index in seen:
				continue
			st, fs = [f], []
			seen.add(f.index)
			while st:
				c = st.pop()
				fs.append(c)
				for e in c.edges:
					for n in e.link_faces:
						if n.index not in seen:
							seen.add(n.index)
							st.append(n)
			vs = {v for x in fs for v in x.verts}
			lo = Vector([min((mw @ v.co)[i] for v in vs) for i in range(3)])
			hi = Vector([max((mw @ v.co)[i] for v in vs) for i in range(3)])
			k = len(boxes)
			boxes.append((lo, hi))
			for x in fs:
				isl_of[x.index] = k
		# border loops: connected components over shared verts
		comp = {}
		adj = {}
		for e in border:
			for v in e.verts:
				adj.setdefault(v.index, []).append(e)
		loops = []
		for e in border:
			if e.index in comp:
				continue
			st, grp = [e], []
			comp[e.index] = len(loops)
			while st:
				c = st.pop()
				grp.append(c)
				for v in c.verts:
					for n in adj[v.index]:
						if n.index not in comp:
							comp[n.index] = len(loops)
							st.append(n)
			loops.append(grp)
		fill = []
		for grp in loops:
			k = isl_of[grp[0].link_faces[0].index]
			lo, hi = boxes[k]
			others = [b for b in all_isl if not (b["part"] == part and (b["lo"] - lo).length < 1e-4 and (b["hi"] - hi).length < 1e-4)
				and all(lo[i] <= b["hi"][i] + 0.01 and b["lo"][i] <= hi[i] + 0.01 for i in range(3))]
			exposed = 0.0
			for e in grp:
				mid = mw @ ((e.verts[0].co + e.verts[1].co) / 2)
				ok = False
				for b in others:
					h = b["tree"].find_nearest(mid)
					if h[0] is not None and h[3] <= seal_tol:
						ok = True
						break
				if not ok:
					for b in others:
						if _inside(mid, b):
							ok = True
							break
				if not ok:
					exposed += e.calc_length()
			if exposed >= min_len or force:
				fill += grp
		if fill:
			n0 = len(bm.faces)
			mats = {e.index: e.link_faces[0].material_index for e in fill}
			res = bmesh.ops.holes_fill(bm, edges=fill, sides=0)
			for f in res["faces"]:
				mi = None
				for e in f.edges:
					for lf in e.link_faces:
						if lf is not f and lf not in res["faces"]:
							mi = lf.material_index
							break
					if mi is not None:
						break
				f.material_index = mi if mi is not None else 0
				f.smooth = True
			bmesh.ops.triangulate(bm, faces=res["faces"], quad_method="BEAUTY", ngon_method="BEAUTY")
			done[part] = len(bm.faces) - n0
			bm.to_mesh(me)
			me.shade_smooth()
			me.set_sharp_from_angle(angle=math.radians(34))
			me.update()
		bm.free()
	return done


def fix_normals(gun):
	# Closed islands only: make every face point outward (a flipped face is invisible in Roblox). Returns flips.
	out = {}
	for ob in F["meshes"](gun):
		me = ob.data
		bm = bmesh.new()
		bm.from_mesh(me)
		bm.faces.ensure_lookup_table()
		seen = set()
		flips = 0
		for f in bm.faces:
			if f.index in seen:
				continue
			st, fs = [f], []
			seen.add(f.index)
			while st:
				c = st.pop()
				fs.append(c)
				for e in c.edges:
					for n in e.link_faces:
						if n.index not in seen:
							seen.add(n.index)
							st.append(n)
			if any(len(e.link_faces) != 2 for x in fs for e in x.edges):
				continue
			before = [x.normal.copy() for x in fs]
			bmesh.ops.recalc_face_normals(bm, faces=fs)
			bm.normal_update()
			flips += sum(1 for x, n in zip(fs, before) if x.normal.dot(n) < 0)
		if flips:
			out[ob.name[len(gun) + 1:]] = flips
			bm.to_mesh(me)
			me.update()
		bm.free()
	return out


def probe(gun, view, image_path, res=(1280, 720), max_spots=4):
	# What is behind the red pixels of a backfaces() picture: casts a ray through each red cluster and reports the
	# part, material, hit point and face normal.
	import numpy as np
	sc = F["scene"](gun)
	bpy.context.window.scene = sc
	F["rest"](gun)
	lo, hi = F["bounds"](gun)
	c = (lo + hi) / 2
	size = (hi - lo).length
	v = Vector(DIRS[view]).normalized()
	cam = F["camera"](gun, "BF", tuple(c + v * (size * 2 + 1)), tuple(c), ortho=size * 1.08)
	sc.view_layers[0].update()
	img = bpy.data.images.load(image_path)
	px = np.empty(res[0] * res[1] * 4, dtype=np.float32)
	img.pixels.foreach_get(px)
	bpy.data.images.remove(img)
	px = px.reshape(res[1], res[0], 4)
	red = (px[:, :, 0] > 0.6) & (px[:, :, 1] < 0.3)
	thick = np.zeros_like(red)
	thick[:-1, :-1] = red[:-1, :-1] & red[1:, :-1] & red[:-1, 1:] & red[1:, 1:]
	ys, xs = np.where(thick)
	if len(xs) == 0:
		return []
	# a few spread sample pixels
	order = np.argsort(xs + ys * 0.37)
	picks = [order[int(i * (len(order) - 1) / max(1, max_spots - 1))] for i in range(max_spots)]
	mw = cam.matrix_world
	right, up, fwd = mw.to_3x3() @ Vector((1, 0, 0)), mw.to_3x3() @ Vector((0, 1, 0)), mw.to_3x3() @ Vector((0, 0, -1))
	scale = cam.data.ortho_scale
	dg = bpy.context.evaluated_depsgraph_get()
	out = []
	for i in picks:
		x, y = int(xs[i]), int(ys[i])  # image rows start at the bottom in Blender's pixel buffer
		u = ((x + 0.5) / res[0] - 0.5) * scale
		w = ((y + 0.5) / res[1] - 0.5) * scale * res[1] / res[0]
		o = mw.translation + right * u + up * w
		hit, loc, nrm, idx, ob, _ = sc.ray_cast(dg, o, fwd)
		if not hit:
			out.append({"px": [x, y], "hit": None})
			continue
		role = "?"
		try:
			role = ob.material_slots[ob.data.polygons[idx].material_index].material.name
		except Exception:
			pass
		out.append({"px": [x, y], "part": ob.name[len(gun) + 1:], "role": role, "at": [round(t, 4) for t in loc], "n": [round(t, 2) for t in nrm], "facing_cam": round(nrm.dot(-fwd), 2)})
	return out


def snap_floating(gun, max_gap=0.006, tol=0.0016):
	# Loose islands that stand a hair off their seat (decals, pin heads, neon strips kept 0.002 proud): move each
	# onto the nearest surface so it runs 0.0006 into it. Returns what moved; bigger gaps are left for a real fix.
	moved, left = [], []
	for f in floating(gun, tol):
		if f["gap"] > max_gap:
			left.append(f)
			continue
		ob = F["obj"](gun, f["part"])
		isl = [i for i in _islands(gun) if i["part"] != f["part"] or (((i["lo"] + i["hi"]) / 2) - Vector(f["center"])).length > 0.002]
		bm = bmesh.new()
		bm.from_mesh(ob.data)
		bm.faces.ensure_lookup_table()
		seen = set()
		for face in bm.faces:
			if face.index in seen:
				continue
			st, fs = [face], []
			seen.add(face.index)
			while st:
				c = st.pop()
				fs.append(c)
				for e in c.edges:
					for n in e.link_faces:
						if n.index not in seen:
							seen.add(n.index)
							st.append(n)
			vs = list({v for x in fs for v in x.verts})
			lo = Vector([min(v.co[i] for v in vs) for i in range(3)])
			hi = Vector([max(v.co[i] for v in vs) for i in range(3)])
			if ((lo + hi) / 2 - Vector(f["center"])).length > 0.002:
				continue
			best = None
			for v in vs:
				for b in isl:
					h = b["tree"].find_nearest(v.co)
					if h[0] is not None and (best is None or h[3] < best[0]):
						best = (h[3], h[0] - v.co)
			if best is not None and best[0] > 1e-6:
				d = best[1].normalized() * (best[0] + 0.0006)
				for v in vs:
					v.co += d
				moved.append({"part": f["part"], "gap": f["gap"], "by": [round(t, 4) for t in d]})
			break
		bm.to_mesh(ob.data)
		bm.free()
		ob.data.update()
	return {"moved": moved, "left": left}
