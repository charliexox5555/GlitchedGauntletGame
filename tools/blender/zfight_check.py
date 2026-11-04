# zfight_check.py: finds coplanar overlapping surfaces (z-fighting) in triangle soup.
#
# Used by build_map_kit_oldtown.py (inside every kit piece, before saving/exporting) and preview_map_oldtown.py
# --check (the assembled map: every kit placement plus the greybox parts Art.luau leaves visible). Mirrors
# tools/studio/maps/Audit.luau's rule (parallel faces closer than PLANE_TOL whose rectangles overlap), but on the
# real triangles, so faces inside a bounding box are checked too.
#
# A conflict is two triangles from different surfaces (different parts, or different faces of one part) that lie
# in the same plane (normals parallel, plane distance < PLANE_TOL) and overlap by more than MIN_AREA:
#   "same"     both face the same way: both can be seen at once, so the renderer flickers. Always a bug.
#   "opposite" they face each other (two solids touching): each is buried in the other, so nothing flickers; the
#              Studio audit skips buried faces too. Reported for information only.
#   "buried"   same-facing, but where they overlap a third, opposite-facing surface lies on them (two trims sitting
#              on one wall: their back faces press against the wall's face). Invisible; information only.
# Plain Python + numpy (both ship with Blender), no bpy, so it can be unit-tested anywhere.

import math

import numpy as np

PLANE_TOL = 0.02
MIN_AREA = 0.01
NORMAL_TOL = 0.999


def _clip(poly, a, b):
	# Keep the part of `poly` left of the directed edge a->b.
	out = []
	n = len(poly)
	if n == 0:
		return out
	ax, ay = a
	bx, by = b

	def side(p):
		return (bx - ax) * (p[1] - ay) - (by - ay) * (p[0] - ax)

	for i in range(n):
		p, q = poly[i], poly[(i + 1) % n]
		sp, sq = side(p), side(q)
		if sp >= 0:
			out.append(p)
		if (sp >= 0) != (sq >= 0):
			t = sp / (sp - sq)
			out.append((p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t))
	return out


def _area(poly):
	s = 0.0
	for i in range(len(poly)):
		x0, y0 = poly[i]
		x1, y1 = poly[(i + 1) % len(poly)]
		s += x0 * y1 - x1 * y0
	return s / 2


def overlap(t1, t2):
	# Intersection polygon of two 2D triangles.
	if _area(t2) < 0:
		t2 = t2[::-1]
	poly = list(t1)
	for i in range(3):
		poly = _clip(poly, t2[i], t2[(i + 1) % 3])
		if not poly:
			return []
	return poly


def overlap_area(t1, t2):
	return abs(_area(overlap(t1, t2)))


def _inside(p, t):
	(ax, ay), (bx, by), (cx, cy) = t
	d1 = (bx - ax) * (p[1] - ay) - (by - ay) * (p[0] - ax)
	d2 = (cx - bx) * (p[1] - by) - (cy - by) * (p[0] - bx)
	d3 = (ax - cx) * (p[1] - cy) - (ay - cy) * (p[0] - cx)
	neg = d1 < 0 or d2 < 0 or d3 < 0
	pos = d1 > 0 or d2 > 0 or d3 > 0
	return not (neg and pos)


def find(tris, owners, labels, same_owner=True, max_report=None):
	"""tris: (N, 3, 3) float array of world-space triangles. owners: (N,) int surface ids (a part, a face group);
	labels: list of names per owner id (dict or list). Returns a list of (kind, label_a, label_b, point, normal, area)."""
	tris = np.asarray(tris, dtype=float)
	if len(tris) == 0:
		return []
	e1 = tris[:, 1] - tris[:, 0]
	e2 = tris[:, 2] - tris[:, 0]
	n = np.cross(e1, e2)
	ln = np.linalg.norm(n, axis=1)
	keep = ln > 1e-6  # degenerate triangles have no plane
	idx = np.nonzero(keep)[0]
	n = n[idx] / ln[idx, None]
	# Canonical plane key: flip so the largest component is positive; remember the facing.
	ax = np.argmax(np.abs(n), axis=1)
	sgn = np.sign(n[np.arange(len(n)), ax])
	cn = n * sgn[:, None]
	d = np.einsum("ij,ij->i", cn, tris[idx, 0])
	qn = np.round(cn * 500).astype(np.int64)  # ~0.1 degree buckets
	qd = np.floor(d / PLANE_TOL).astype(np.int64)
	buckets = {}
	for k in range(len(idx)):
		key = (qn[k, 0], qn[k, 1], qn[k, 2], qd[k])
		buckets.setdefault(key, []).append(k)
	out = []
	seen = set()
	for key, members in buckets.items():
		# Same plane bucket plus the next one up (plane distance < PLANE_TOL can straddle a bucket edge).
		other = buckets.get((key[0], key[1], key[2], key[3] + 1), [])
		cand = members + other
		if len(cand) < 2:
			continue
		a_axis = int(np.argmax(np.abs(cn[members[0]])))
		u, v = [i for i in range(3) if i != a_axis]
		P = tris[idx[cand]][:, :, [u, v]]
		lo = P.min(axis=1) + 0.005
		hi = P.max(axis=1) - 0.005
		# Grid hash in 2D for candidate pairs.
		cell = 4.0
		grid = {}
		for m in range(len(cand)):
			for gx in range(int(math.floor(lo[m, 0] / cell)), int(math.floor(hi[m, 0] / cell)) + 1):
				for gy in range(int(math.floor(lo[m, 1] / cell)), int(math.floor(hi[m, 1] / cell)) + 1):
					grid.setdefault((gx, gy), []).append(m)
		nm = len(members)
		for cellm in grid.values():
			if len(cellm) < 2:
				continue
			for i in range(len(cellm)):
				a = cellm[i]
				for j in range(i + 1, len(cellm)):
					b = cellm[j]
					if a >= nm and b >= nm:
						continue  # both in the neighbour bucket: that bucket checks itself
					ka, kb = cand[a], cand[b]
					pair = (min(ka, kb), max(ka, kb))
					if pair in seen:
						continue
					oa, ob = owners[idx[ka]], owners[idx[kb]]
					if oa == ob and not same_owner:
						continue
					if abs(d[ka] - d[kb]) >= PLANE_TOL:
						continue
					if np.dot(cn[ka], cn[kb]) < NORMAL_TOL:
						continue
					if hi[a, 0] < lo[b, 0] or hi[b, 0] < lo[a, 0] or hi[a, 1] < lo[b, 1] or hi[b, 1] < lo[a, 1]:
						continue
					seen.add(pair)
					poly = overlap([tuple(p) for p in P[a]], [tuple(p) for p in P[b]])
					area = abs(_area(poly)) if poly else 0.0
					if area <= MIN_AREA:
						continue
					kind = "same" if sgn[ka] == sgn[kb] else "opposite"
					if oa == ob and kind == "opposite":
						continue  # two touching solids inside one mesh: buried
					if kind == "same":
						cx = sum(q[0] for q in poly) / len(poly)
						cy = sum(q[1] for q in poly) / len(poly)
						for m in set(cellm) | set(grid.get((int(math.floor(cx / cell)), int(math.floor(cy / cell))), [])):
							km = cand[m]
							if sgn[km] != sgn[ka] and abs(d[km] - d[ka]) < PLANE_TOL and _inside((cx, cy), [tuple(q) for q in P[m]]):
								kind = "buried"
								break
					pt = tris[idx[ka]].mean(axis=0)
					out.append((kind, labels[oa], labels[ob], tuple(np.round(pt, 2)), tuple(np.round(n[ka], 3)), round(area, 3)))
					if max_report and len(out) >= max_report:
						return out
	return out


def summary(conflicts, kind="same", top=30):
	import re
	groups = {}
	for c in conflicts:
		if c[0] != kind:
			continue
		a = re.sub(r"\d+", "#", c[1])
		b = re.sub(r"\d+", "#", c[2])
		k = tuple(sorted((a, b)))
		groups[k] = groups.get(k, 0) + 1
	return sorted(groups.items(), key=lambda kv: -kv[1])[:top]
