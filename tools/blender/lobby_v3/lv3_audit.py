"""Geometry checks for Lobby V3 (run through Blender MCP after a build).
A: mesh integrity (open edges, zero-area faces)
B: coplanar faces of different solids that face the same way and overlap (z-fighting)
C: floating solids (nothing within 0.06 studs of them)
D: sealing (rays from inside every room must never reach the bedrock or the sky, except up the light well)
"""
import bpy
import bmesh
import numpy as np
from math import sqrt, pi, cos, sin
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.geometry import intersect_point_tri_2d

SKIP = ("RenderShell", "Cameras", "Scale")


def _objects(root_name="LobbyV3"):
	root = bpy.data.collections[root_name]
	for col in root.children_recursive:
		if col.name in SKIP:
			continue
		for o in col.objects:
			if o.type == "MESH" and not o.name.endswith("_Dummy"):
				yield o


def _islands(bm):
	"""face index -> island id"""
	lab = [-1] * len(bm.faces)
	n = 0
	for f in bm.faces:
		if lab[f.index] != -1:
			continue
		stack = [f]
		lab[f.index] = n
		while stack:
			g = stack.pop()
			for e in g.edges:
				for h in e.link_faces:
					if lab[h.index] == -1:
						lab[h.index] = n
						stack.append(h)
		n += 1
	return lab, n


def run(max_report=25, root="LobbyV3", probes=None):
	rep = {"A_open_edges": [], "A_zero_faces": [], "B_coplanar": [], "C_floating": [], "D_leaks": []}
	faces = []  # (obj, island gid, normal, [verts])
	isl_pts = {}  # gid -> sample points
	isl_name = {}
	isl_tris = {}
	tris, tri_owner = [], []
	verts_all = []
	gid0 = 0
	for o in _objects(root):
		bm = bmesh.new()
		bm.from_mesh(o.data)
		bm.faces.ensure_lookup_table()
		bm.verts.ensure_lookup_table()
		open_e = sum(1 for e in bm.edges if len(e.link_faces) != 2)
		if open_e:
			rep["A_open_edges"].append((o.name, open_e))
		zero = sum(1 for f in bm.faces if f.calc_area() < 1e-7)
		if zero:
			rep["A_zero_faces"].append((o.name, zero))
		lab, n = _islands(bm)
		for f in bm.faces:
			g = gid0 + lab[f.index]
			vs = [v.co.copy() for v in f.verts]
			faces.append((o.name, g, f.normal.copy(), vs))
			isl_name[g] = o.name
			pts = isl_pts.setdefault(g, [])
			ctr = f.calc_center_median()
			pts.append(ctr)
			for v in f.verts:
				pts.append(v.co.lerp(ctr, 0.5))
			for e in f.edges:
				a, b = e.verts[0].co, e.verts[1].co
				k = max(1, int((b - a).length / 0.3))
				for i in range(k + 1):
					pts.append(a.lerp(b, i / k))
		# triangles for the BVH
		base = len(verts_all)
		verts_all.extend(v.co.copy() for v in bm.verts)
		for lt in bm.calc_loop_triangles():
			tri = [base + l.vert.index for l in lt]
			tris.append(tri)
			tri_owner.append(gid0 + lab[lt[0].face.index])
			isl_tris.setdefault(gid0 + lab[lt[0].face.index], []).append(tri)
		gid0 += n
		bm.free()

	dg = bpy.context.evaluated_depsgraph_get()
	sc = bpy.context.scene
	shell_names = {o.name for o in bpy.data.collections["RenderShell"].objects} if "RenderShell" in bpy.data.collections else set()
	hidden = 0
	bvh0 = BVHTree.FromPolygons(verts_all, tris, all_triangles=True)
	skew = Vector((0.371, 0.557, 0.743)).normalized()

	def inside_solid(pt):
		# parity per solid along one skew ray: inside any closed solid means the spot cannot be seen
		counts = {}
		o = pt.copy()
		for _ in range(400):
			loc, _n, idx, _d = bvh0.ray_cast(o, skew)
			if loc is None:
				break
			g = tri_owner[idx]
			counts[g] = counts.get(g, 0) + 1
			o = loc + skew * 2e-4
		return any(c % 2 == 1 for c in counts.values())

	# ---- B: coplanar, same facing, overlapping (only where a camera could see it)
	groups = {}
	for i, (name, g, nrm, vs) in enumerate(faces):
		for ax in range(3):
			if abs(nrm[ax]) > 0.9995:
				key = (ax, 1 if nrm[ax] > 0 else -1, round(vs[0][ax] / 0.004))
				groups.setdefault(key, []).append(i)
	found = {}
	for (ax, sg, _c), idx in groups.items():
		if len(idx) < 2:
			continue
		u, v = [a for a in range(3) if a != ax]
		bb = np.array([[min(p[u] for p in faces[i][3]), max(p[u] for p in faces[i][3]),
			min(p[v] for p in faces[i][3]), max(p[v] for p in faces[i][3])] for i in idx])
		gid = np.array([faces[i][1] for i in idx])
		m = 0.03
		ov = ((bb[:, None, 0] < bb[None, :, 1] - m) & (bb[None, :, 0] < bb[:, None, 1] - m)
			& (bb[:, None, 2] < bb[None, :, 3] - m) & (bb[None, :, 2] < bb[:, None, 3] - m)
			& (gid[:, None] != gid[None, :]))
		for a, b in zip(*np.nonzero(np.triu(ov, 1))):
			fa, fb = faces[idx[a]], faces[idx[b]]
			pa = [Vector((p[u], p[v])) for p in fa[3]]
			pb = [Vector((p[u], p[v])) for p in fb[3]]

			def inside(pt, poly):
				c = False
				j = len(poly) - 1
				for i2 in range(len(poly)):
					if ((poly[i2].y > pt.y) != (poly[j].y > pt.y)) and (
						pt.x < (poly[j].x - poly[i2].x) * (pt.y - poly[i2].y) / (poly[j].y - poly[i2].y) + poly[i2].x):
						c = not c
					j = i2
				return c

			def samples(poly):
				ctr = sum(poly, Vector((0, 0))) / len(poly)
				out = [ctr]
				for p in poly:
					out.append(p.lerp(ctr, 0.15))
				for i2 in range(len(poly)):
					out.append(((poly[i2] + poly[(i2 + 1) % len(poly)]) / 2).lerp(ctr, 0.15))
				return [s for s in out if inside(s, poly)]

			hit = any(inside(s, pb) for s in samples(pa)) or any(inside(s, pa) for s in samples(pb))
			if hit:
				both = [q for q in samples(pa) if inside(q, pb)] or [q for q in samples(pb) if inside(q, pa)]
				p3 = [0.0, 0.0, 0.0]
				p3[ax] = fa[3][0][ax] + sg * 0.03
				p3[u], p3[v] = both[0].x, both[0].y
				dirv = Vector([sg if a2 == ax else 0 for a2 in range(3)])
				if inside_solid(Vector(p3)):
					hidden += 1
					continue
				key2 = tuple(sorted((fa[0], fb[0]))) + (ax, sg)
				c = Vector(p3)
				d = found.setdefault(key2, [0, None])
				d[0] += 1
				d[1] = tuple(round(x, 1) for x in c)
	rep["B_coplanar"] = sorted(([k[0], k[1], "xyz"[k[2]], k[3], v[0], v[1]] for k, v in found.items()), key=lambda r: -r[4])[:max_report]
	rep["B_visible_pairs"] = sum(v[0] for v in found.values())
	rep["B_hidden_pairs"] = hidden

	# ---- C: floating solids
	bvh = BVHTree.FromPolygons(verts_all, tris, all_triangles=True)
	owner = np.array(tri_owner)
	floating = []
	for g, pts in isl_pts.items():
		attached = False
		step = max(1, len(pts) // 400)
		for p in pts[::step]:
			for _loc, _n, ti, _d in bvh.find_nearest_range(p, 0.06):
				if owner[ti] != g:
					attached = True
					break
			if attached:
				break
		if not attached:  # touching nothing: does it at least pass through another solid?
			used = sorted({i for t in isl_tris[g] for i in t})
			remap = {i: k for k, i in enumerate(used)}
			own = BVHTree.FromPolygons([verts_all[i] for i in used], [[remap[i] for i in t] for t in isl_tris[g]], all_triangles=True)
			attached = any(owner[b] != g for _a, b in own.overlap(bvh))
		if not attached:
			c = sum(pts, Vector()) / len(pts)
			floating.append((isl_name[g], tuple(round(x, 1) for x in c)))
	rep["C_floating"] = floating[:max_report]
	rep["C_total"] = len(floating)

	# ---- D: sealing
	probes = probes or {
		"hub": (0, 0, 5), "hub_ring": (30, 12, 4), "gate_N": (0, 41, 5), "gate_W": (-41, 0, 5), "gate_E": (41, 0, 5), "gate_S": (0, -41, 5),
		"duels_landing": (0, 56, 5), "duels_mid": (0, 110, 3), "duels_gate": (0, 158, 3), "market": (-80, 0, 4), "market_alcove": (-82, 33, 3),
		"market_apse": (-122, 0, 4), "vault": (70, 6, 6), "range": (0, -75, 3), "range_hall": (0, -130, 3),
	}
	n = 2500
	for name, p in probes.items():
		leaks = 0
		ex = None
		for i in range(n):
			z = 1 - 2 * (i + 0.5) / n
			r = sqrt(1 - z * z)
			a = i * pi * (3 - sqrt(5))
			d = Vector((r * cos(a), r * sin(a), z))
			hit, loc, _nrm, _idx, ob, _m = sc.ray_cast(dg, Vector(p), d)
			if hit and ob.name not in shell_names:
				continue
			if name.startswith("hub") and d.z > 0:  # allowed: out through the light well
				t = (62 - p[2]) / d.z
				x, y = p[0] + d.x * t, p[1] + d.y * t
				if x * x + y * y < 25.0 ** 2:
					continue
			leaks += 1
			ex = tuple(round(c, 2) for c in d)
		if leaks:
			rep["D_leaks"].append((name, leaks, ex))
	rep["solids"] = gid0
	rep["faces"] = len(faces)
	return rep
