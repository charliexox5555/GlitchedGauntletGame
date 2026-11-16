"""Lobby V4, section 1: the Concourse (main area). A faceted octagon, 92 across (inradius 46), walls 34 high, a coffered
ceiling on 8 radial beams, a lantern drum over the spawn dais. Doors on the axes (Duels +Y, Shop +X, Locker -X,
Range -Y); boards, crates and the social niche on the diagonals. Plan: vault/02 Art/Lobby V4 Plan.md section 3.1.
"""
from math import cos, sin, radians, pi

from mathutils import Matrix, Vector

import lv3_core as C
import sw_core as S
import v4_core as V

AREA = "Concourse"
R = 46.0  # inradius of the octagon
RC = R / cos(pi / 8)  # vertex radius
HW = 34.0  # wall height (ceiling underside)
WT = 4.0  # wall thickness
A = RC * sin(pi / 8) - 1.6  # half span of a wall bay between the piers
RL = 16.0  # lantern ring inradius
DUELS_HW = 11.5  # Duels portal half width: clears the corner piers, which reach 13.65 along a wall
OPEN = set()  # wings already built: their doorway closure is left out


spans = V.spans


def wall(K, KD, M, ops=(), panel_skip=None, panels=True):
	V.wall_run(K, KD, M, -A, A, HW, ops, panel_skip=[panel_skip] if panel_skip else [], panels=panels, t=WT)


def pier(K, KD, k):
	phi = radians(22.5 + 45 * k)
	c, s = cos(phi), sin(phi)
	M = S.face((RC * c, RC * s, 0), (s, -c, 0), (-c, -s, 0))
	with C.grp("Pier", M, inst=True):
		F = S.FK(KD, M)
		S.collider(AREA, M, -3.0, 3.0, 0.0, HW, -4.4, 2.6, "B")
		F["V_Base"].ext_y(V.ccw(S.cham_rect(-4.3, 4.3, -4.6, 3.8, 0.45)), 0, 1.8)
		F["V_Wall"].ext_y(V.ccw(S.cham_rect(-3.6, 3.6, -4.6, 3.1, 0.6)), 1.8, 28.6)
		S.taper_y(F["V_Trim"], (-3.6, 3.6, -4.6, 3.1), 28.6, (-4.3, 4.3, -4.6, 3.9), 29.8)
		F["V_Wall"].ext_y(V.ccw(S.cham_rect(-4.3, 4.3, -4.6, 3.9, 0.5)), 29.8, HW)
		# a shallow channel up the shaft front that holds the lamp
		F["V_Low"].ext_y(V.ccw(S.cham_rect(-1.5, 1.5, 2.9, 3.35, 0.08)), 10.6, 22.4)
	V.bar_lamp(KD, M @ V.T(0, 11.2, 3.35), length=10.6, feed=5.2)
	with C.grp("PierCollar", M, inst=True):
		S.FK(KD, M)["V_Trim"].ext_y(V.ccw(S.cham_rect(-3.9, 3.9, -4.6, 3.4, 0.2)), 8.9, 9.9)
		for sx in (-1.4, 1.4):
			V.gusset(KD, M, sx, 31.6, 3.0)
	S.light(M, 0, 29.4, 5.2, V.WHITE, 1.3, 30, 75)
	return M


def ring_sectors(b, r0, r1, z0, z1, rot=radians(22.5)):
	o, i = V.oct_pts(r1, rot), V.oct_pts(r0, rot)
	for k in range(8):
		j = (k + 1) % 8
		b.prism(V.ccw([i[k], i[j], o[j], o[k]]), z0, z1)


def ceiling(KC, KCD, KD):
	ring_sectors(KC["V_Ceil"], RL, R + 4.6, HW, HW + 1.5)
	ring_sectors(KCD["V_Beam"], 30.0, 32.4, 32.6, HW + 0.3)  # coffer ring (tops sunk into the slab)
	ring_sectors(KCD["V_Beam"], RL - 0.3, RL + 2.4, 31.2, HW + 0.3)  # lantern ring
	ring_sectors(KD["E_White"], RL + 0.5, RL + 1.6, 31.08, 31.22)  # cove strip under the lantern ring
	# a housed lamp in every outer coffer, between the radial beams
	for k in range(8):
		th = radians(45 * k)
		V.ceiling_lamp(KD, 39.0 * cos(th), 39.0 * sin(th), HW, 1.6, 1.6)
	for k in range(8):
		phi = radians(22.5 + 45 * k)
		c, s = cos(phi), sin(phi)
		M = S.face((RC * c, RC * s, 0), (s, -c, 0), (-c, -s, 0))
		with C.grp("Beam", M, inst=True):
			S.FK(KCD, M)["V_Beam"].prism(V.ccw([(-1.6, HW + 0.25), (-1.6, 32.3), (-0.9, 31.6), (0.9, 31.6), (1.6, 32.3), (1.6, HW + 0.25)]), 3.0, RC - RL / cos(pi / 8))


def lantern(K, KC, KD):
	"""The sunroof (owner 2026-11-16: needs work). A clerestory drum of frosted panels, a faceted stepped roof of eight
	sloped plates with ribs, an upper drum, and a frosted oculus; a light ring hung inside on rods; a soft light shaft."""
	z0 = HW + 1.5
	zr = z0 + 10.0  # drum top
	with C.grp("Lantern", Matrix.Identity(4)):
		half = RL * sin(pi / 8) / cos(pi / 8)
		for k in range(8):
			M = V.face_at(45 * k, RL, z0)
			F = S.FK(KC, M)
			F["V_Wall"].box(-half, half, 0.05, 2.0, -1.6, 0)
			F["V_Wall"].box(-half, half, 8.4, 10.0, -1.6, 0)
			S.FK(KD, M)["E_Panel"].box(-half + 0.9, half - 0.9, 2.0, 8.4, -1.1, -0.9)
			S.FK(KD, M)["V_Steel"].box(-0.25, 0.25, 2.0, 8.4, -0.9, -0.5)  # mullion
			S.FK(KD, M)["V_Trim"].box(-half + 0.4, half - 0.4, 1.7, 2.12, -0.05, 0.35)  # sill
		for k in range(8):  # corner posts, set on the drum (clear of the ceiling ring)
			phi = radians(22.5 + 45 * k)
			rc = RL / cos(pi / 8)
			c, s = cos(phi), sin(phi)
			M = S.face((rc * c, rc * s, z0), (s, -c, 0), (-c, -s, 0))
			S.FK(KC, M)["V_Trim"].ext_y(V.ccw(S.cham_rect(-0.9, 0.9, -1.7, 0.3, 0.2)), 0.1, 9.9)
		# sloped roof: eight plates from the drum top up to the upper drum
		ro, ri, zt = RL + 1.2, 8.6, zr + 5.0
		o, i_ = V.oct_pts(ro), V.oct_pts(ri)
		for k in range(8):
			j = (k + 1) % 8
			KC["V_Ceil"].solid([(o[k][0], o[k][1], zr), (o[j][0], o[j][1], zr), (i_[j][0], i_[j][1], zt), (i_[k][0], i_[k][1], zt)],
				[(o[k][0], o[k][1], zr + 1.2), (o[j][0], o[j][1], zr + 1.2), (i_[j][0], i_[j][1], zt + 1.2), (i_[k][0], i_[k][1], zt + 1.2)])
		for k in range(8):  # ribs along the plate seams
			a = V.oct_pts(ro + 0.3)[k]
			b = V.oct_pts(ri + 0.3)[k]
			S.FK(KD, Matrix.Identity(4))["V_Beam"].pipe((a[0], a[1], zr - 0.3), (b[0], b[1], zt - 0.3), 0.45, n=6)
		# upper drum with a frosted band, flat cap with the oculus
		for k in range(8):
			M = V.face_at(45 * k, ri, zt)
			hh = ri * sin(pi / 8) / cos(pi / 8)
			S.FK(KC, M)["V_Wall"].box(-hh, hh, 0.0, 0.8, -1.0, 0)
			S.FK(KD, M)["E_Panel"].box(-hh + 0.6, hh - 0.6, 0.8, 2.8, -0.7, -0.5)
			S.FK(KC, M)["V_Wall"].box(-hh, hh, 2.8, 3.6, -1.0, 0)
		ring_sectors(KC["V_Ceil"], 4.2, ri + 0.4, zt + 3.6, zt + 4.6)
		S.FK(KD, Matrix.Identity(4))["E_Panel"].prism(V.ccw(V.oct_pts(4.3)), zt + 3.9, zt + 4.1)  # frosted oculus
	# the light ring hung inside the drum
	zh = z0 + 3.4
	with C.grp("LightRing", Matrix.Translation((0, 0, zh))):
		G = S.FK(KD, Matrix.Translation((0, 0, zh)))
		o, i_ = V.oct_pts(10.4), V.oct_pts(9.0)
		for k in range(8):
			j = (k + 1) % 8
			G["V_Dark"].prism(V.ccw([i_[k], i_[j], o[j], o[k]]), 0.0, 0.8)
			G["E_ThViolet"].prism(V.ccw([V.oct_pts(9.9)[k], V.oct_pts(9.9)[j], V.oct_pts(10.5)[j], V.oct_pts(10.5)[k]]), 0.25, 0.55)
			G["E_White"].prism(V.ccw([V.oct_pts(9.2)[k], V.oct_pts(9.2)[j], V.oct_pts(10.2)[j], V.oct_pts(10.2)[k]]), -0.08, 0.0)
		for k in range(8):  # hanger rods up to the drum top
			p = V.oct_pts(9.7, rot=radians(0))[k]
			G["V_Steel"].pipe((p[0], p[1], 0.8), (p[0], p[1], zr + 4.5 - zh), 0.09, n=6)  # up into the sloped roof
	S.light(Matrix.Identity(4), 0, 0, zh - 0.5, V.WHITE, 2.4, 50, 80)
	S.light(Matrix.Identity(4), 0, 0, zt + 2.0, V.WHITE, 1.4, 40, 70)
	V.fx("cone", 0.0, 0.0, zt + 3.4, "#F4F1EA", to=(0.0, 0.0, 2.2), name="Sunshaft", W0=7.0, W1=16.0)


def floor(K, KD):
	K["V_Slab"].prism(V.ccw(V.oct_pts(R + 4.6)), -1.2, 0)
	K["V_Floor2"].prism(V.ccw(V.oct_pts(15.4)), 0, 0.12)
	ring_sectors(KD["E_ThLilac"], 15.7, 16.1, 0.12, 0.17)  # a lit ring round the dais (lanes start from it)
	# plates: 16 per ring, two rings, split by 0.25 shadow gaps
	for ring, (r0, r1) in enumerate(((16.45, 31.0), (31.25, R + 0.6))):
		o = V.oct_pts(r1)
		i = V.oct_pts(r0)
		for k in range(8):
			j = (k + 1) % 8
			om = ((o[k][0] + o[j][0]) / 2, (o[k][1] + o[j][1]) / 2)
			im = ((i[k][0] + i[j][0]) / 2, (i[k][1] + i[j][1]) / 2)
			for h, quad in enumerate(([i[k], im, om, o[k]], [im, i[j], o[j], om])):
				mat = "V_Floor" if (ring + h) % 2 == 0 else "V_Floor2"
				KD[mat].prism(V.inset(V.ccw(quad), 0.125), 0, 0.12)
	for k in range(2):  # grates at the foot of the two board walls (the other diagonals carry props)
		Mz = Matrix.Rotation(radians(45 + 90 * k) - pi / 2, 4, "Z")
		V.grate(KD, Mz, -13.0, 13.0, R - 4.2, R - 2.4, 0.12)
	# the dais: two octagonal steps with light nosings, a gold ring and a dark centre plate with a gold arrow to Duels
	K["V_Floor2"].prism(V.ccw(V.oct_pts(12.5)), 0.12, 1.0)
	ring_sectors(K["V_Trim"], 11.9, 12.55, 0.86, 1.05)
	K["V_Lane"].prism(V.ccw(V.oct_pts(8.5)), 1.0, 2.0)
	ring_sectors(K["V_Trim"], 7.9, 8.55, 1.86, 2.05)
	ring_sectors(KD["V_ThLilac"], 5.6, 6.0, 2.0, 2.06)  # studio lilac
	KD["V_Dark"].prism(V.ccw(V.oct_pts(4.6)), 2.0, 2.05)
	S.add_text(KD["E_Gold"], "GG", 3.2, 0.06, y0=-1.6, z0=2.05, s=0.24)
	# paths to the doors: inlaid lanes with lit rails, chevrons near each door (RIVALS' floor paths, our build)
	for th, name in ((90, "DUELS"), (0, "SHOP"), (180, "LOCKER")):
		Ml = Matrix.Rotation(radians(th - 90), 4, "Z")
		V.path_lane(KD, Ml, 5.0, 16.6, R - 4.2, arrows=(33.0, 36.4), word=name)


def portal(K, KD, M, hw, h, depth, close=True, cut=2.4, lining="V_Low", name="Portal", rings=(1.5, 1.3, 1.2)):
	"""A stepped door surround: light trim ring, graphite ring, lining that runs back into the tunnel; tunnel shell,
	floor and (until the wing is built) a closure. The wall opening is (-hw, hw) x (0, h)."""
	with C.grp(name, M):
		F = S.FK(K, M)
		FD = S.FK(KD, M)
		a, b, c = rings
		h1, h2, h3 = hw - a, hw - a - b, hw - a - b - c
		v1, v2, v3 = h - a + 0.1, h - a - b + 0.1, h - a - b - c + 0.1
		S.u_frame(FD["V_Trim"], hw, h, h1, v1, -1.0, 1.6, ci=cut + 0.4)
		S.u_frame(FD["V_Wall"], h1, v1, h2, v2, -3.0, 0.9, co=cut + 0.4, ci=cut + 0.2)
		S.u_frame(FD[lining], h2, v2, h3, v3, -depth, 0.3, co=cut + 0.2, ci=cut)
		F["V_Wall"].box(-hw - 1, hw + 1, v2, h + 1, -depth, -1.0)  # tunnel shell
		for sx in (-1, 1):
			F["V_Wall"].box(sx * h2, sx * (hw + 1), 0, v2, -depth, -1.0)
		F["V_Slab"].box(-hw - 1, hw + 1, -1.2, -0.02, -depth, -WT)
		FD["V_Floor2"].box(-h3, h3, 0, 0.12, -depth, -0.65)  # starts past the hall plates (they reach 0.6 into the doorway)
		for sx in (-1, 1):  # the lining is visual: players stop at boxes hidden inside its legs and head
			S.collider(AREA, M, sx * (h3 + 0.15), sx * (h2 - 0.1), 0.0, v3 - 0.1, -depth, 0.2, "B")
		S.collider(AREA, M, -(h2 - 0.2), h2 - 0.2, v3 + 0.15, v2 - 0.1, -depth, 0.2, "B")
		for rz in ([-depth * 0.35, -depth * 0.7] if depth > 6 else []):
			S.u_frame(FD["V_Trim"], h3 + 0.05, v3 + 0.05, h3 - 0.45, v3 - 0.45, rz - 0.3, rz + 0.3, co=cut, ci=cut - 0.2)
			FD["E_White"].box(-h3 * 0.5, h3 * 0.5, v3 - 0.5, v3 - 0.42, rz - 0.15, rz + 0.15)
		if close:
			F["V_Base"].box(-hw - 1, hw + 1, 0, h + 1, -depth - 1.0, -depth)
		S.light(M, 0, v3 - 0.6, -depth * 0.45, V.WHITE, 1.6, 22, 80)
		S.light(M, 0, v3 * 0.5, -depth * 0.6, V.WHITE, 0.8, 16)


def doors(K, KD):
	"""Each door in a gatehouse (owner 2026-11-16: grand entrances), its sign standing on the gatehouse head."""
	M = V.face_at(90, R)
	portal(K, KD, M, DUELS_HW, 20.0, 12.0, close="Duels" not in OPEN, name="Portal_Duels")
	V.gatehouse(K, KD, M, DUELS_HW, 20.0, name="Gate_Duels")
	V.sign(KD, M @ V.T(0, 23.9, 0), "DUELS", 25.0, 6.4, accent="E_Gold", name="Sign_Duels", shape="badge", icon="blades", standoff=4.2)
	M = V.face_at(0, R)
	portal(K, KD, M, 12.0, 18.0, 12.0, close="Shop" not in OPEN, name="Portal_Shop")
	V.gatehouse(K, KD, M, 12.0, 18.0, name="Gate_Shop")
	V.sign(KD, M @ V.T(0, 21.6, 0), "SHOP", 21.0, 6.2, accent="E_Coral", name="Sign_Shop", shape="tag", icon="sparkle", icon_at="right", icon_size=5.0, standoff=4.2)
	M = V.face_at(180, R)
	portal(K, KD, M, 9.0, 18.0, 12.0, close="Locker" not in OPEN, cut=2.6, name="Portal_Locker")
	V.gatehouse(K, KD, M, 9.0, 18.0, name="Gate_Locker", plain=(-1,))
	V.sign(KD, M @ V.T(0, 22.4, 0), "LOCKER", 25.0, 6.2, accent="E_Violet", name="Sign_Locker", icon="reticle", standoff=4.2)
	# Range (-Y): not built yet (owner 2026-11-16). A sealed door in its gatehouse, the RANGE sign kept for later.
	M = V.face_at(270, R)
	portal(K, KD, M, 10.0, 18.0, 4.6, close=True, cut=2.6, name="Portal_Range")
	V.gatehouse(K, KD, M, 10.0, 18.0, name="Gate_Range", plain=(-1,))
	with C.grp("RangeDoor", M):
		G = S.FK(KD, M)
		h3, v3 = 10.0 - 4.0, 18.0 - 3.9
		for sx in (-1, 1):  # two closed leaves with a seam, ribs and a lime status strip
			G["V_Steel"].box(sx * 0.06, sx * (h3 - 0.05), 0.12, v3 - 0.05, -2.3, -1.9)
			for y in (3.0, 7.0, 11.0):
				G["V_Dark"].box(sx * 0.6, sx * (h3 - 0.6), y, y + 0.5, -1.9, -1.75)
		G["E_Lime"].box(-2.0, 2.0, v3 - 1.2, v3 - 0.9, -1.9, -1.75)
	V.sign(KD, M @ V.T(0, 21.7, 0), "RANGE", 25.0, 6.2, accent="E_Lime", name="Sign_Range", shape="arrow", icon="target", standoff=4.2)


def diagonals(K, KD):
	# NE / NW: leaderboards in the first frame from the spawn
	for th, title in ((45, "TOP WINS"), (135, "WIN STREAKS")):
		M = V.face_at(th, R)
		wall(K, KD, M, panel_skip=(-11.6, 11.6))
		V.conduit(KD, M, -14.7, 14.7, HW - 4.4)
		V.gallery(K, KD, M, -A + 3.4, A - 3.4, 27.6, name="Gallery")
		V.tv(K, KD, M @ V.T(0, 10.0, 0), 21.0, 12.0, "leader", title, name="TV_" + title.replace(" ", ""))
	# SW: news board and a crate stack
	M = V.face_at(225, R)
	wall(K, KD, M, panel_skip=(-10.6, 10.6))
	V.conduit(KD, M, -14.7, 14.7, HW - 4.4)
	V.gallery(K, KD, M, -A + 3.4, A - 3.4, 27.6, name="Gallery")
	V.tv(K, KD, M @ V.T(0, 11.0, 0), 19.0, 11.0, "news", "SEASON 1", "NEW MAPS · NEW MODS", name="TV_News")
	Mf = M @ V.RX(-90)
	for x, z, yaw, kind in ((-11.0, 0.0, 0.0, "crate"), (-4.2, 0.0, 4.0, "crate"), (-7.6, 3.8, -7.0, "crate_s"), (8.6, 0.0, 12.0, "barrel"), (12.2, 0.0, -20.0, "barrel_x")):
		V.prop_m(kind, Mf @ V.T(x, -3.4, z) @ Matrix.Rotation(radians(yaw), 4, "Z"), name="Prop")
	# SE: the social niche: two benches, a show stage, the featured board
	M = V.face_at(315, R)
	wall(K, KD, M, panel_skip=(-9.0, 9.0))
	V.conduit(KD, M, -14.7, 14.7, HW - 4.4)
	V.gallery(K, KD, M, -A + 3.4, A - 3.4, 27.6, name="Gallery")
	V.tv(K, KD, M @ V.T(0, 12.4, 0), 16.0, 9.5, "featured", "FEATURED", "THIS WEEK", name="TV_Featured")
	for sx in (-1, 1):
		with C.grp("Bench", M @ V.T(sx * 10.0, 0, 0), inst=True):
			F = S.FK(K, M @ V.T(sx * 10.0, 0, 0))
			F["V_Base"].ext_x(V.ccw([(0, 1.2), (0, 3.2), (1.5, 3.0), (1.5, 1.4)]), -2.8, 2.8)
			F["V_Panel"].ext_x(V.ccw([(1.5, 0.45), (1.5, 3.8), (2.2, 3.9), (2.45, 3.6), (2.45, 0.45)]), -3.0, 3.0)
			F["V_Seat"].ext_x(V.ccw([(2.45, 0.4), (2.45, 1.7), (4.8, 1.45), (5.0, 1.0), (5.0, 0.35)]), -3.0, 3.0)
			F["V_Trim"].ext_x(V.ccw([(2.2, 3.7), (2.45, 3.95), (2.6, 3.95), (2.6, 3.6)]), -3.1, 3.1)
	S.light(M, 0, 30.0, 6.0, V.WHITE, 1.4, 26, 60)


def rig(KD):
	with C.grp("LightingRig", Matrix.Identity(4)):
		V.truss_ring(KD, (0.0, 0.0), 21.0, 30.0, 31.0, HW)  # outside the lantern ring: hangers up to the coffer ceiling
		for k in range(8):
			V.stage_spot(KD, (0.0, 0.0), radians(22.5 + 45 * k), 21.0, 30.0, (0.0, 0.0, 1.0))


def details(K, KD):
	"""Vents low on the board walls, safety plaques and beacons beside the doors."""
	for th in (45, 135, 225, 315):
		M = V.face_at(th, R)
		with C.grp("Vents", M):
			vents = {225: ((4.6, 2.0, 3.0),), 315: ((0.0, 3.2, 2.2),)}.get(th, ((-5.2, 4.2, 1.8), (4.6, 2.2, 3.0)))  # none behind crates or benches
			for x, w_, h_ in vents:
				V.vent(KD, M, x, 2.4, w_, h_, slats=4 if h_ < 2.5 else 6)
	M = V.face_at(180, R)  # Locker door: plaques on the left strip, a beacon over them
	with C.grp("Plaques_Locker", M):
		V.plaque(KD, M @ V.T(0, 0, 3.6), -11.8, 9.0, 3.0, 2.2, "notice", "NOTICE", ["SKINS SAVE PER GUN"])
	M = V.face_at(270, R)  # Range door: sealed, says so
	with C.grp("Plaques_Range", M):
		V.plaque(KD, M @ V.T(0, 0, 3.6), -12.3, 8.6, 3.0, 2.4, "warning", "WARNING", ["RANGE CLOSED"])
		V.beacon(KD, M @ V.T(0, 0, 3.6), -12.3, 12.6)


def life(K, KD):
	# hologram stands on the diagonals (owner 2026-11-16: like RIVALS' holograms, fun; items are placeholders)
	for th, item in ((45, "gift"), (135, "badge"), (225, "rifle"), (315, "crate")):
		a = radians(th)
		V.holo_stand(K, KD, AREA, 27.0 * cos(a), 27.0 * sin(a), item, name="Holo_" + item.title())
	V.fx("dust", 0.0, 0.0, 14.0, "#FFF4E0", name="LanternDust", Spread=10.0)
	# the dais collar: four faceted segments on the diagonals (open on the lanes), gold uplights on top
	for k in range(4):
		th = radians(45 + 90 * k)
		Mz = Matrix.Rotation(th - pi / 2, 4, "Z")
		with C.grp("DaisCollar", Mz, inst=True):
			F, G = S.FK(K, Mz), S.FK(KD, Mz)
			F["V_Wall"].prism(V.ccw([(-4.6, 13.3), (4.6, 13.3), (5.6, 14.6), (-5.6, 14.6)]), 0.12, 1.6)
			G["V_Trim"].prism(V.ccw([(-5.0, 13.2), (5.0, 13.2), (6.0, 14.7), (-6.0, 14.7)]), 1.6, 1.8)
			for u in (-3.6, 0.0, 3.6):
				G["E_Gold"].prism(V.ccw(S.cham_rect(u - 0.35, u + 0.35, 13.75, 14.15, 0.1)), 1.8, 1.86)


def build():
	K = S.kit(AREA, nocol=False)
	KD = C.Kit(K.col, prefix=AREA + "D")
	KD.nocol = True
	KC = S.kit(AREA + "_Ceil", nocol=False)
	floor(K, KD)
	for k in range(8):
		pier(K, KD, k)
	KCD = C.Kit(KC.col, prefix=AREA + "CD")
	KCD.nocol = True
	ceiling(KC, KCD, KD)
	lantern(K, KC, KD)
	wall(K, KD, V.face_at(90, R), ops=[(-DUELS_HW, DUELS_HW, 0.0, 20.0)], panels=False)
	wall(K, KD, V.face_at(0, R), ops=[(-12.0, 12.0, 0.0, 18.0)], panels=False)
	wall(K, KD, V.face_at(180, R), ops=[(-9.0, 9.0, 0.0, 18.0)], panels=False)
	wall(K, KD, V.face_at(270, R), ops=[(-10.0, 10.0, 0.0, 18.0)], panels=False)
	doors(K, KD)
	diagonals(K, KD)
	rig(KD)
	details(K, KD)
	life(K, KD)
	S.light(Matrix.Identity(4), 0, 0, 30.5, V.WHITE, 1.2, 34, 70)  # a soft pool on the dais under the lantern ring
	return K.done() + KD.done() + KC.done() + KCD.done()


def bpy_col(name):
	import bpy
	return bpy.data.collections[name]


floor = V.grouped(floor, "HubFloor")
ceiling = V.grouped(ceiling, "HubCeiling")
