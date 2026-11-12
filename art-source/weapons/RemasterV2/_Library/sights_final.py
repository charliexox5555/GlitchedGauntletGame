# sights_final.py: the final iron-sight family (2026-11-11, owner: "all aim down sights look odd ... hard to see
# through"). One family, one quality bar: a big thin-walled rear window the eye looks THROUGH (about a fifth of the
# screen height at the game's aiming eye, like vault/02 Art/References/ads-refs), a clean front post with a lit dot
# at the exact sight line, and bases that run INTO the gun (nothing can float). Each gun keeps its own window shape.
# Profiles are (y, z); ax / fx = rear / front x; sz = sight line z; zb = the surface the piece stands on.

import math
import bmesh
import v2kit as K

EMBED = 0.006  # every base runs this far into the surface under it


def _clip_z(pts, z, keep_above=True):
	# Sutherland-Hodgman against z >= z (or z <= z).
	out = []
	n = len(pts)
	if keep_above:
		inside = lambda p: p[1] >= z - 1e-9
	else:
		inside = lambda p: p[1] <= z + 1e-9
	for i in range(n):
		a, b = pts[i], pts[(i + 1) % n]
		ia, ib = inside(a), inside(b)
		if ia:
			out.append(a)
		if ia != ib:
			t = (z - a[1]) / (b[1] - a[1])
			out.append((a[0] + (b[0] - a[0]) * t, z))
	return out


def _dedupe(pts, eps=1e-5):
	out = []
	for p in pts:
		if not out or abs(p[0] - out[-1][0]) > eps or abs(p[1] - out[-1][1]) > eps:
			out.append(p)
	if len(out) > 1 and abs(out[0][0] - out[-1][0]) < eps and abs(out[0][1] - out[-1][1]) < eps:
		out.pop()
	return out


def _extend(pts, zc, z_to):
	# Replaces the flat cut at zc (left by _clip_z) with two straight sides running to z_to.
	w = max(abs(p[0]) for p in pts)
	res = []
	for i, p in enumerate(pts):
		res.append(p)
		q = pts[(i + 1) % len(pts)]
		if abs(p[1] - zc) < 1e-6 and abs(q[1] - zc) < 1e-6 and abs(p[0] - q[0]) > w:
			res += [(p[0], z_to), (q[0], z_to)]
	return res


def shape(kind, cz, r, hh=None, ch=None):
	# Convex window outline centred on (0, cz). r = half width; hh = half height (rect kinds).
	if kind == "circle":
		return K.circle(0.0, cz, r, 20)
	if kind == "octagon":
		return K.circle(0.0, cz, r / math.cos(math.pi / 8), 8)
	if kind == "hexagon":  # flat top and bottom, points at the sides
		return K.circle(0.0, cz, r, 6, rot=0.0)
	hh = r if hh is None else hh
	ch = 0.3 * min(r, hh) if ch is None else ch
	return K.chamfer([(-r, cz - hh), (r, cz - hh), (r, cz + hh), (-r, cz + hh)], ch)


def frame(ax, sz, zp, kind, r_in, wall=0.013, t=0.02, hh=None, ch=None, legs=False, sill=0.006, open_top=None, z_foot=None, mat=K.DARK):
	# Rear window plate. zp = top of the pedestal it stands in. The window is clipped at zp + sill (a flat bottom
	# when the gun's top is close under the sight line). legs: the outline drops straight from its widest row into
	# the pedestal (an arch). open_top: everything above sz + open_top is cut away (two horns: a cradle).
	win = shape(kind, sz, r_in, hh, ch)
	hh_o = None if hh is None else hh + wall
	ch_o = None if ch is None else ch + wall * 0.6
	out = shape(kind, sz, r_in + wall, hh_o, ch_o)
	win = _dedupe(_clip_z(win, zp + sill))
	if legs:
		out = _extend(_dedupe(_clip_z(out, sz)), sz, zp - EMBED if z_foot is None else z_foot)
	else:
		out = _dedupe(_clip_z(out, zp - EMBED))
	if open_top is not None:
		out = _dedupe(_clip_z(out, sz + open_top, keep_above=False))
		zc = max(p[1] for p in win)
		wide = max(abs(p[0]) for p in win)
		zrow = min(p[1] for p in win if abs(abs(p[0]) - wide) < 1e-6)  # lowest point of the widest row
		win = _extend(_dedupe(_clip_z(win, zrow, keep_above=False)), zrow, sz + open_top + 0.02)
	plate = K.prism(out, "X", ax - t / 2, ax + t / 2, mat)
	cutter = K.prism(win, "X", ax - 0.1, ax + 0.1, mat)
	return K.bevel(K.cut(plate, cutter, mat), 0.002, 1, 40)


def pedestal(ax, zb, zp, length=0.13, hw=0.045, top_len=None, mat=K.DARK):
	# Low base under a rear sight: side profile (x, z) with sloped ends, running EMBED into the gun.
	tl = length * 0.72 if top_len is None else top_len
	pts = [(ax - length / 2, zb - EMBED), (ax + length / 2, zb - EMBED), (ax + length / 2, zb + 0.004), (ax + tl / 2, zp), (ax - tl / 2, zp), (ax - length / 2, zb + 0.004)]
	return K.bevel(K.prism(pts, "Y", -hw, hw, mat), 0.002, 1, 40)


def neck(ax, z0, z1, hw=0.026, t=0.03, mat=K.DARK):
	# Short stem joining a raised ring to its pedestal (deeper front-to-back than the plate: no coincident faces).
	return K.bevel(K.prism([(-hw * 1.3, z0), (hw * 1.3, z0), (hw, z1), (-hw, z1)], "X", ax - t / 2, ax + t / 2, mat), 0.002, 1, 40)


def knobs(ax, sz, y, r=0.012, w=0.008, mat=K.METAL):
	# Small adjuster drums on both sides of a frame.
	return K.group(K.cyl_y(ax, sz, r, y - 0.002, y + w, 8, mat, rot=0.0), K.cyl_y(ax, sz, r, -y - w, -y + 0.002, 8, mat, rot=0.0))


def slider(ax, sz, hw, drop=0.026, bar=0.008, notch=0.01, t=0.014, mat=K.METAL):
	# Ladder-sight slider: a thin bar across the lower window with a small square notch under the sight line.
	top = sz - drop
	pts = [(-hw, top - bar), (hw, top - bar), (hw, top), (notch, top), (notch, top - bar * 0.55), (-notch, top - bar * 0.55), (-notch, top), (-hw, top)]
	return K.prism(pts, "X", ax - t / 2 - 0.003, ax + t / 2 + 0.003, mat)


def notch_blade(ax, sz, zb, hw=0.05, t=0.022, nw=0.02, nd=0.022, ch=0.01, mat=K.DARK):
	# Open pistol rear sight: a low wide blade, square notch, shoulders level with the sight line.
	pts = [(-hw, zb - EMBED), (hw, zb - EMBED), (hw, sz - ch), (hw - ch, sz), (nw, sz), (nw, sz - nd), (-nw, sz - nd), (-nw, sz), (-hw + ch, sz), (-hw, sz - ch)]
	return K.bevel(K.prism(pts, "X", ax - t / 2, ax + t / 2, mat), 0.002, 1, 40)


# ---- front sights

def tower(fx, zb, zt, length=0.1, hw=0.03, top_len=0.05, top_hw=None, mat=K.DARK):
	# Front sight block: sloped front and back, narrowing to its top, running EMBED into the gun.
	th = hw * 0.7 if top_hw is None else top_hw
	b = K.prism([(fx - length / 2, zb - EMBED), (fx + length / 2, zb - EMBED), (fx + top_len / 2, zt), (fx - top_len / 2, zt)], "Y", -hw, hw, mat)
	for v in b.verts:
		if v.co.z > zt - 1e-6:
			v.co.y *= th / hw
	return K.bevel(b, 0.002, 1, 40)


def post(fx, sz, z0, w=0.007, t=0.014, tip=0.0035, mat=K.METAL):
	# Front post, its flat tip exactly on the sight line.
	return K.prism([(-w, z0), (w, z0), (w, sz - 0.02), (tip, sz), (-tip, sz), (-w, sz - 0.02)], "X", fx - t / 2, fx + t / 2, mat)


def dot(fx, sz, t=0.014, r=0.0042, mat=K.NEON):
	# Lit dot on the post's rear face, just under its tip: the thing the eye finds first.
	return K.cyl_x(fx - t / 2 - 0.0025, fx - t / 2 + 0.0015, r, 0.0, sz - 0.011, 8, mat)


def ears(fx, sz, zt, gap=0.03, th=0.008, depth=0.036, rise=0.012, lean=0.006, mat=K.DARK):
	# Two protective ears beside the post, standing in the tower top, leaning out a little.
	out = []
	for s in (1, -1):
		pts = [(s * gap, zt - 0.004), (s * (gap + th), zt - 0.004), (s * (gap + th + lean), sz + rise), (s * (gap + lean), sz + rise)]
		if s < 0:
			pts = pts[::-1]
		out.append(K.bevel(K.prism(pts, "X", fx - depth / 2, fx + depth / 2, mat), 0.0015, 1, 40))
	return out


def hood_ring(fx, sz, r_in=0.03, wall=0.007, depth=0.03, segs=14, mat=K.DARK):
	# Thin round hood; the tower top must reach above sz - r_in - wall + 0.004 so the ring's bottom runs into it.
	return K.annulus_x(fx - depth / 2, fx + depth / 2, 0.0, sz, r_in + wall, r_in, segs, mat)


def hood_box(fx, sz, zt, hw=0.034, rise=0.03, wall=0.007, depth=0.04, mat=K.DARK):
	# Square tunnel hood standing in the tower top; open front and back.
	top = sz + rise
	outer = K.prism(K.chamfer([(-hw, zt - 0.004), (hw, zt - 0.004), (hw, top), (-hw, top)], [0, 0, 0.008, 0.008]), "X", fx - depth / 2, fx + depth / 2, mat)
	inner = K.prism([(-hw + wall, zt - 0.02), (hw - wall, zt - 0.02), (hw - wall, top - wall), (-hw + wall, top - wall)], "X", fx - 0.1, fx + 0.1, mat)
	return K.bevel(K.cut(outer, inner, mat), 0.0015, 1, 40)
