# check_map_zfight.py: offline z-fighting check of an assembled match map (vault/01 Design/Maps/00 Maps.md,
# "No z-fighting"). Run it on the map's kit .blend with a dump of the built map:
#
#   lune run tools/studio/maps/mock_place.luau <bundle.luau> <Map> <Group...> -o dump.json
#   blender --background --factory-startup art-source/maps/<Map>/Kit_<Map>.blend \
#       --python tools/blender/check_map_zfight.py -- dump.json [--report out.json]
#
# Every placed kit piece contributes its real mesh polygons (Map_<Piece> collections, transformed the way
# kit_bundle.py + put() place them: Blender (x, y, z) -> Roblox (x, z, -y), then the piece's CFrame), and
# every visible non-kit part (greybox, barriers) its six box faces. Two polygons z-fight when they face the
# same way, lie in the same plane (within PLANE_TOL) and overlap by more than MIN_AREA; pairs inside one
# mesh object count too (two boxes merged into one part). Like tools/studio/maps/Audit.luau, a face pair
# buried in a visible solid block (the point just outside it is inside a greybox box) is skipped.
# --bounds checks each kit part's bounding box instead of its mesh (stricter: what a raycast against a part with
# Box collision fidelity sees), to look for pairs Studio's ray audit may still report.
# Prints the pairs grouped by part names and exits with code 1 when any are found (so it can gate an export).

import bpy, json, math, os, sys
from collections import defaultdict
from mathutils import Matrix, Vector

PLANE_TOL = 0.02
MIN_AREA = 0.01
NORMAL_DOT = 0.9995

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def cf_matrix(c):
	x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = c
	return Matrix(((r00, r01, r02, x), (r10, r11, r12, y), (r20, r21, r22, z), (0, 0, 0, 1)))


def piece_polys():
	# {piece: [(part name, [ [Vector...] per polygon ])]} in Roblox piece space.
	out = {}
	for col in bpy.data.collections:
		if not col.name.startswith("Map_"):
			continue
		parts = []
		for ob in col.all_objects:
			if ob.type != "MESH" or ob.get("preview_only") or ob.get("kit_skip") or len(ob.data.polygons) == 0:
				continue
			mw = ob.matrix_world
			verts = [mw @ v.co for v in ob.data.vertices]
			verts = [Vector((v.x, v.z, -v.y)) for v in verts]
			if "--bounds" in ARGS:
				# Whole-part bounds instead of the mesh: what a Box-fidelity raycast (Studio's audit) can hit.
				lo = Vector([min(v[i] for v in verts) for i in range(3)])
				hi = Vector([max(v[i] for v in verts) for i in range(3)])
				polys = box_polys(Matrix.Translation((lo + hi) / 2), list(hi - lo))
			else:
				polys = [[verts[i] for i in p.vertices] for p in ob.data.polygons]
			parts.append((ob.name, polys))
		out[col.name[4:]] = parts
	return out


def box_polys(m, size):
	hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
	c = [m @ Vector((sx * hx, sy * hy, sz * hz)) for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)]
	idx = lambda sx, sy, sz: ((sx + 1) // 2) * 4 + ((sy + 1) // 2) * 2 + (sz + 1) // 2  # noqa: E731
	faces = []
	for axis in range(3):
		for s in (-1, 1):
			quad = []
			for a, b in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
				k = [0, 0, 0]
				k[axis] = s
				o = [i for i in range(3) if i != axis]
				k[o[0]], k[o[1]] = a, b
				quad.append(c[idx(*k)])
			# wind it so its normal points out of the box
			centre = m @ Vector((0, 0, 0))
			mid = sum(quad, Vector((0, 0, 0))) / 4
			if newell(quad).dot(mid - centre) < 0:
				quad.reverse()
			faces.append(quad)
	return faces


def newell(poly):
	n = Vector((0, 0, 0))
	for i in range(len(poly)):
		a, b = poly[i], poly[(i + 1) % len(poly)]
		n.x += (a.y - b.y) * (a.z + b.z)
		n.y += (a.z - b.z) * (a.x + b.x)
		n.z += (a.x - b.x) * (a.y + b.y)
	return n


def basis(n):
	t = Vector((1, 0, 0)) if abs(n.x) < 0.9 else Vector((0, 1, 0))
	u = n.cross(t).normalized()
	return u, n.cross(u).normalized()


def clip(subject, clipper):
	# Sutherland-Hodgman, both convex, CCW 2D lists of (x, y).
	def inside(p, a, b):
		return (b[0] - a[0]) * (p[1] - a[1]) - (b[1] - a[1]) * (p[0] - a[0]) >= -1e-9

	def inter(p, q, a, b):
		x1, y1, x2, y2 = p[0], p[1], q[0], q[1]
		x3, y3, x4, y4 = a[0], a[1], b[0], b[1]
		den = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4)
		if abs(den) < 1e-12:
			return q
		t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / den
		return (x1 + t * (x2 - x1), y1 + t * (y2 - y1))

	out = subject
	for i in range(len(clipper)):
		a, b = clipper[i], clipper[(i + 1) % len(clipper)]
		inp, out = out, []
		if not inp:
			break
		s = inp[-1]
		for e in inp:
			if inside(e, a, b):
				if not inside(s, a, b):
					out.append(inter(s, e, a, b))
				out.append(e)
			elif inside(s, a, b):
				out.append(inter(s, e, a, b))
			s = e
	return out


def area2(p):
	return sum(p[i][0] * p[(i + 1) % len(p)][1] - p[(i + 1) % len(p)][0] * p[i][1] for i in range(len(p))) / 2


def ccw(p):
	return p if area2(p) >= 0 else list(reversed(p))


def main():
	dump = json.load(open(ARGS[0]))
	report_path = ARGS[ARGS.index("--report") + 1] if "--report" in ARGS else None
	kit = piece_polys()
	polys = []  # (owner, part name, normal, d, verts)
	missing = set()
	for i, pl in enumerate(dump["pieces"]):
		parts = kit.get(pl["piece"])
		if parts is None:
			missing.add(pl["piece"])
			continue
		m = cf_matrix(pl["cf"])
		for name, plist in parts:
			owner = "%s#%d/%s" % (pl["piece"], i, name)
			for poly in plist:
				polys.append((owner, name, [m @ v for v in poly]))
	solids = []
	for j, p in enumerate(dump["parts"]):
		m = cf_matrix(p["cf"])
		owner = "%s#g%d" % (p["name"], j)
		if p["class"] in ("Part", "SpawnLocation"):
			solids.append((m.inverted(), [s / 2 for s in p["size"]]))
		if p["class"] == "WedgePart":
			continue  # ramps are hidden under the kit's stairs
		for q in box_polys(m, p["size"]):
			polys.append((owner, p["name"], q))

	def buried(pt):
		for inv, h in solids:
			lp = inv @ pt
			if abs(lp.x) < h[0] - 1e-4 and abs(lp.y) < h[1] - 1e-4 and abs(lp.z) < h[2] - 1e-4:
				return True
		return False

	# Plane buckets: quantised normal + plane distance.
	buckets = defaultdict(list)
	for k, (owner, name, vs) in enumerate(polys):
		n = newell(vs)
		if n.length < 1e-9:
			continue
		n.normalize()
		d = n.dot(vs[0])
		key = (round(n.x, 3), round(n.y, 3), round(n.z, 3))
		buckets[key].append((d, k, n))
	found = {}
	for key, items in buckets.items():
		items.sort()
		for a_i in range(len(items)):
			da, ka, na = items[a_i]
			oa, nma, va = polys[ka]
			u, v = basis(na)
			pa = None
			for b_i in range(a_i + 1, len(items)):
				db, kb, nb = items[b_i]
				if db - da > PLANE_TOL:
					break
				if na.dot(nb) < NORMAL_DOT:
					continue
				ob, nmb, vb = polys[kb]
				if oa == ob:
					# same mesh object: only polygons that don't share a corner (two merged boxes)
					if any((x - y).length < 1e-5 for x in va for y in vb):
						continue
				pair = tuple(sorted((oa, ob)))
				if pair in found:
					continue
				if pa is None:
					pa = ccw([(p.dot(u), p.dot(v)) for p in va])
					ax0, ax1 = min(p[0] for p in pa), max(p[0] for p in pa)
					ay0, ay1 = min(p[1] for p in pa), max(p[1] for p in pa)
				pb = ccw([(p.dot(u), p.dot(v)) for p in vb])
				if max(p[0] for p in pb) <= ax0 or min(p[0] for p in pb) >= ax1 or max(p[1] for p in pb) <= ay0 or min(p[1] for p in pb) >= ay1:
					continue
				inter = clip(pa, pb)
				if len(inter) < 3:
					continue
				ar = abs(area2(inter))
				if ar < MIN_AREA:
					continue
				cx = sum(p[0] for p in inter) / len(inter)
				cy = sum(p[1] for p in inter) / len(inter)
				pt = u * cx + v * cy + na * (da + 0.03)
				if buried(pt):
					continue
				found[pair] = (round(ar, 3), [round(c, 2) for c in pt], [round(c) for c in na])
	groups = defaultdict(list)
	for (a, b), info in found.items():
		ga = a.split("/")[-1] if "/" in a else a.split("#")[0]
		gb = b.split("/")[-1] if "/" in b else b.split("#")[0]
		groups[" + ".join(sorted((ga, gb)))].append(((a, b), info))
	print("ZFIGHT %s: %d polygons, %d z-fighting pairs" % (dump["map"], len(polys), len(found)))
	for g, lst in sorted(groups.items(), key=lambda kv: -len(kv[1])):
		(a, b), (ar, pt, n) = lst[0]
		print("ZFIGHT  %3d  %-60s e.g. at %s normal %s area %.2f" % (len(lst), g, pt, n, ar))
	if missing:
		print("ZFIGHT missing kit pieces:", sorted(missing))
	if report_path:
		with open(report_path, "w") as f:
			json.dump([{"a": a, "b": b, "area": i[0], "at": i[1], "normal": i[2]} for (a, b), i in found.items()], f, indent=1)
	sys.stdout.flush()
	os._exit(1 if found else 0)


main()
