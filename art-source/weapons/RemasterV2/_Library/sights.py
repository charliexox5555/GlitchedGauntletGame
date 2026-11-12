# sights.py: RemasterV2 iron-sight kit (v02). Every gun gets its own sight picture (the user's call, 2026-11-08: "their
# sights will just be different varying on the gun"), and nothing floats: each piece stands on, or is fused to, its
# base. Profiles are (y, z) prisms along X, so they read as clean silhouettes from the ADS eye.
# Conventions: ax / fx = rear / front sight x; sz = sight line z (the front post's tip); zb = top of the base the
# piece stands on. Open notches: the post tip sits level with the blade's shoulders (blade top = sz).

import math
import v2kit as K


def _blade_outline(hw, zb, top, c):
	return [(-hw, zb), (hw, zb), (hw, top - c), (hw - c, top), (-hw + c, top), (-hw, top - c)]


def notch_blade(ax, sz, zb, hw=0.05, t=0.02, notch="square", nw=0.016, nd=0.03, c=0.008, mat=K.DARK):
	# A rear blade across the gun with an open notch at the sight line. notch: "square", "v" or "u".
	pts = [(-hw, zb), (hw, zb), (hw, sz - c), (hw - c, sz), (nw, sz)]
	if notch == "square":
		pts += [(nw, sz - nd), (-nw, sz - nd)]
	elif notch == "v":
		pts += [(0.0, sz - nd)]
	else:  # round-bottom U
		pts += [(nw, sz - nd + nw)] + [(nw * math.cos(a), sz - nd + nw - nw * math.sin(a)) for a in [math.pi * i / 6 for i in range(1, 6)]] + [(-nw, sz - nd + nw)]
	pts += [(-nw, sz), (-hw + c, sz), (-hw, sz - c)]
	return K.bevel(K.prism(pts, "X", ax - t / 2, ax + t / 2, mat), 0.002, 1, 40)


def aperture_plate(ax, sz, zb, hw=0.06, top=None, hole=0.045, shape="round", t=0.02, c=0.012, mat=K.DARK):
	# A solid plate with a window centred on the sight line: "round" (peep) or "diamond".
	top = sz + hole + 0.026 if top is None else top
	plate = K.prism(_blade_outline(hw, zb, top, c), "X", ax - t / 2, ax + t / 2, mat)
	if shape == "diamond":
		win = K.prism([(0.0, sz - hole), (hole, sz), (0.0, sz + hole), (-hole, sz)], "X", ax - 0.1, ax + 0.1, mat)
	else:
		win = K.cyl_x(ax - 0.1, ax + 0.1, hole, 0.0, sz, 12, mat, rot=0.0)
	return K.bevel(K.cut(plate, win, mat), 0.002, 1, 40)


def drum(ax, sz, zb, r=0.04, hw=0.04, hole=0.017, mat=K.DARK, metal=K.METAL):
	# HK-style rotary diopter: a drum (axis across the gun) on a pedestal, the sight hole through it along X.
	ped = K.prism([(-0.032, zb), (0.032, zb), (0.026, sz), (-0.026, sz)], "X", ax - 0.03, ax + 0.03, mat)
	d = K.cyl_y(ax, sz, r, -hw, hw, 12, mat, rot=0.0)
	d = K.cut(d, K.cyl_x(ax - 0.1, ax + 0.1, hole, 0.0, sz, 10, mat, rot=0.0), mat)
	caps = K.group(K.cyl_y(ax, sz, r * 0.55, hw - 0.001, hw + 0.006, 8, metal, rot=0.0), K.cyl_y(ax, sz, r * 0.55, -hw - 0.006, -hw + 0.001, 8, metal, rot=0.0))
	return [K.bevel(ped, 0.002, 1, 40), K.bevel(d, 0.003, 1, 40), caps]


def ladder_frame(ax, sz, zb, hw=0.05, top=None, bar=0.012, t=0.016, mat=K.DARK, slider_mat=K.METAL):
	# Machine-gun ladder sight: an open rectangular frame with a slider bar carrying a V notch at the sight line.
	top = sz + 0.045 if top is None else top
	frame = K.prism(_blade_outline(hw, zb, top, 0.006), "X", ax - t / 2, ax + t / 2, mat)
	frame = K.cut(frame, K.prism([(-hw + bar, zb + bar), (hw - bar, zb + bar), (hw - bar, top - bar), (-hw + bar, top - bar)], "X", ax - 0.1, ax + 0.1, mat), mat)
	sl = [(-hw + bar - 0.001, sz - 0.022), (hw - bar + 0.001, sz - 0.022), (hw - bar + 0.001, sz), (0.012, sz), (0.0, sz - 0.014), (-0.012, sz), (-hw + bar - 0.001, sz)]
	slider = K.prism(sl, "X", ax - t / 2 - 0.004, ax + t / 2 + 0.004, slider_mat)
	return [K.bevel(frame, 0.002, 1, 40), K.bevel(slider, 0.0015, 1, 40)]


def ring_hood(fx, sz, r_out=0.05, r_in=0.04, depth=0.03, mat=K.DARK):
	# Round hood around the front post; the caller's tower top must reach above sz - r_out (it then sits on it).
	return K.annulus_x(fx - depth / 2, fx + depth / 2, 0.0, sz, r_out, r_in, 12, mat)


def box_hood(fx, sz, zt, hw=0.04, top=None, wall=0.009, depth=0.05, mat=K.DARK):
	# Square tunnel hood standing on the tower (top at zt); open front and back.
	top = sz + 0.03 if top is None else top
	outer = K.prism(_blade_outline(hw, zt, top, 0.006), "X", fx - depth / 2, fx + depth / 2, mat)
	inner = K.prism([(-hw + wall, zt - 0.01), (hw - wall, zt - 0.01), (hw - wall, top - wall), (-hw + wall, top - wall)], "X", fx - 0.1, fx + 0.1, mat)
	return K.bevel(K.cut(outer, inner, mat), 0.002, 1, 40)


def post(fx, sz, z0, w=0.006, t=0.012, tip=0.0016, mat=K.METAL):
	# Front blade post, tapering to its tip at the sight line.
	return K.prism([(-w, z0), (w, z0), (w, sz - 0.03), (tip, sz), (-tip, sz), (-w, sz - 0.03)], "X", fx - t / 2, fx + t / 2, mat)


def post_dot(fx, sz, t=0.012, neon=K.NEON):
	# Neon dot set into the post's rear face just under the tip (faces the shooter).
	return K.box(fx - t / 2 - 0.0015, fx - t / 2 + 0.001, -0.0035, 0.0035, sz - 0.014, sz - 0.006, neon)


def bead(fx, sz, r=0.008, mat=K.NEON):
	# Round bead topping a post (axis toward the eye, so it reads as a dot); its top is the sight line.
	return K.cyl_x(fx - 0.006, fx + 0.006, r, 0.0, sz - r, 8, mat)


def ghost_ring(ax, sz, zb, r_out=0.056, r_in=0.045, pw=0.018, top=None, t=0.024, mat=K.DARK):
	# Protected ghost ring: a thin, wide ring held between two tall side pillars that reach above it (the ring's
	# sides are buried in the pillars, the pillars stand on the base). Wide window, clean picture.
	top = sz + r_out + 0.012 if top is None else top
	ring = K.annulus_x(ax - t * 0.3, ax + t * 0.3, 0.0, sz, r_out, r_in, 16, mat)
	out = [ring]
	for s in (1, -1):
		y0, y1 = sorted((s * (r_out - 0.006), s * (r_out - 0.006 + pw)))
		pil = K.prism(K.chamfer([(ax - t / 2 - 0.012, zb), (ax + t / 2 + 0.012, zb), (ax + t / 2, top), (ax - t / 2, top)], [0, 0, 0.006, 0.006]), "Y", y0, y1, mat)
		out.append(K.bevel(pil, 0.002, 1, 40))
	# Arms tie the ring's sides into both pillars (so it reads as held, not hanging), and a web joins it to the base.
	for s in (1, -1):
		y0, y1 = sorted((s * (r_in + 0.004), s * (r_out + 0.004)))
		out.append(K.box(ax - t * 0.3, ax + t * 0.3, y0, y1, sz - 0.009, sz + 0.009, mat))
	out.append(K.prism([(-0.014, zb), (0.014, zb), (0.01, sz - r_in + 0.004), (-0.01, sz - r_in + 0.004)], "X", ax - t * 0.3, ax + t * 0.3, mat))
	return out
