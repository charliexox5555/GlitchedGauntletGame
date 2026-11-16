"""Lobby V4, section 2: Duels. A horseshoe hall past the hub's Duels portal: a landing with steps down (-3), 84 wide,
rectangle y 62-158 then a faceted three-face apse to y 180. Eight equal queue bays in mode order round the walls (left
1v1 x3, apse 2v2 x2, right 3v3 x2 + 4v4), a match-board island with a sitting kerb in the middle, the gauntlet trophy
under THE GAUNTLET sign at the end of the spawn sightline. Plan: vault/02 Art/Lobby V4 Plan.md section 3.2.
"""
from math import cos, sin, radians, pi, sqrt

from mathutils import Matrix, Vector

import lv3_core as C
import sw_core as S
import v4_core as V

AREA = "Duels"
Z0 = -3.0  # hall floor
H = 30.0  # wall height above the hall floor
X = 42.0  # half width
Y0, Y1, YE = 62.0, 158.0, 182.0  # front wall face, apse start, end wall
XE = 18.0  # half width of the apse end face
BAYS = (78.0, 106.0, 134.0)  # bay centres along each side wall (respaced for the open stage pads)
PIERS = (92.0, 120.0)
PHW = 11.5  # the hub Duels portal half width (v4_hub.DUELS_HW): the mouth continues its lining
BAY_HW, BAY_H, BAY_D = 11.0, 18.0, 4.0
PLAYERS = {"1v1": 1, "2v2": 2, "3v3": 3, "4v4": 4}


def frame(origin, xdir):
	"""Wall face frame at origin (floor level of the hall), X along xdir, Z = into the hall (left of xdir, seen from above)."""
	x = Vector(xdir).normalized()
	z = Vector((x.y, -x.x, 0))
	return S.face((origin[0], origin[1], Z0), (x.x, x.y, 0), (z.x, z.y, 0))


def corner_frame(p, zin):
	z = Vector(zin).normalized()
	return S.face((p[0], p[1], Z0), (-z.y, z.x, 0), (z.x, z.y, 0))


def bay(K, KD, M, mode, idx):
	"""One queue station at frame M (centre on the wall plane; Z points into the hall). Owner 2026-11-16: the deep
	alcove pads were boring and hidden; RIVALS lays its pads out open beside the walkway. Ours: a shallow lit recess
	with the queue board, and in front of it an open raised stage pad: stepped base, steel rim, two team plates with
	one slot marker per player, a VS pylon between them, two corner light towers, hazard edging on the front step."""
	n = PLAYERS[mode]
	hw, h, d = BAY_HW, BAY_H, BAY_D
	with C.grp("Bay", M, inst=True):
		F = S.FK(K, M)
		FD = S.FK(KD, M)
		# the recess: stepped frame, lined, a lit back panel with the queue board
		S.u_frame(FD["V_Trim"], hw, h, hw - 1.2, h - 1.2, -1.0, 1.6, ci=2.8)
		S.u_frame(FD["V_Wall"], hw - 1.2, h - 1.2, hw - 2.2, h - 2.2, -3.0, 0.9, co=2.8, ci=2.5)
		S.u_frame(FD["V_Panel"], hw - 2.2, h - 2.2, hw - 3.2, h - 3.2, -d, 0.3, co=2.5, ci=2.2)
		F["V_Wall"].box(-hw - 2.5, hw + 2.5, h - 2.2, h + 2.0, -d, -1.0)
		for sx in (-1, 1):
			F["V_Wall"].box(sx * (hw - 2.2), sx * (hw + 2.5), 0, h - 2.2, -d, -1.0)
		F["V_Wall"].box(-hw - 2.5, hw + 2.5, 0, h + 2.0, -d - 3.0, -d)
		F["V_Slab"].box(-hw - 2.5, hw + 2.5, -1.2, -0.02, -d - 3.0, -2.0)
		FD["V_Floor2"].box(-(hw - 3.2), hw - 3.2, 0, 0.12, -d, 0)
		FD["V_Low"].prism(V.ccw(S.cham_rect(-7.5, 7.5, 2.6, 13.2, 1.2)), -d, -d + 0.3)
		FD["V_Dark"].prism(V.ccw(S.cham_rect(-7.35, 7.35, 2.8, 12.9, 1.0)), -d + 0.3, -d + 0.5)  # the big screen's case
		S.screen("lineup", mode.upper(), f"0 / {2 * n} QUEUED", M, 0, 7.8, -d + 0.56, 14.2, 9.6)
		FD["V_Steel"].ext_x(V.ccw([(13.0, -d + 0.3), (13.0, -d + 1.5), (13.4, -d + 1.7), (13.6, -d + 0.3)]), -6.0, 6.0)  # hood over the screen
		S.light(M, 0, h - 3.6, -d * 0.4, V.WHITE, 1.4, 18, 80)
		# the stage pad on the hall floor (floor frame: X right, Y into the wall, so the hall is -Y)
		Mf = M @ V.RX(-90)
		P = S.FK(KD, Mf)
		y0, y1, x1 = -13.0, -0.8, 9.6  # front, back, half width (bigger pads, room for 4 a side)
		P["V_Floor2"].prism(V.ccw(S.cham_rect(-x1 - 0.6, x1 + 0.6, y0 - 1.0, y1, 0.5)), 0.12, 0.55)  # front step
		P["V_Trim"].prism(V.ccw(S.cham_rect(-x1 - 0.66, x1 + 0.66, y0 - 1.06, y0 - 0.55, 0.2)), 0.5, 0.62)  # its nosing, proud of the step
		P["V_Base"].prism(V.ccw(S.cham_rect(-x1, x1, y0, y1, 0.6)), 0.55, 1.05)
		S.ring_prism(P["V_Steel"], V.ccw(S.cham_rect(-x1, x1, y0, y1, 0.6)), V.ccw(S.cham_rect(-x1 + 0.45, x1 - 0.45, y0 + 0.45, y1 - 0.45, 0.4)), 1.05, 1.25)
		P["V_Dark"].prism(V.ccw(S.cham_rect(-x1 + 0.45, x1 - 0.45, y0 + 0.45, y1 - 0.45, 0.4)), 1.05, 1.18)
		S.collider(AREA, Mf, -x1 + 0.3, x1 - 0.3, y0 - 0.7, y1 - 0.3, 0.12, 1.1, "B")
		for sx, glow, paint, letter in ((-1, "E_TeamA", "V_TeamA", "A"), (1, "E_TeamB", "V_TeamB", "B")):
			a0, a1 = (-x1 + 1.0, -1.4) if sx < 0 else (1.4, x1 - 1.0)
			outer = V.ccw(S.cham_rect(a0, a1, y0 + 1.0, y1 - 1.0, 0.5))
			S.ring_prism(P[glow], outer, V.inset(outer, 0.16), 1.18, 1.26)  # one thin lit outline
			S.ring_prism(P[paint], V.inset(outer, 0.16), V.inset(outer, 0.7), 1.18, 1.24)  # painted team band
			P["V_Floor2"].prism(V.inset(outer, 0.7), 1.18, 1.22)
			cx = (a0 + a1) / 2
			S.add_text(P["V_Paint"], letter, 2.2, 0.04, y0=y1 - 4.8, z0=1.22, x0=cx - S.text_width(letter, 2.2) / 2, s=0.22)
			for k in range(n):  # one chevron slot marker per player, pointing at the hall
				px = cx + (k - (n - 1) / 2) * 1.5
				P[paint].prism(V.ccw([(px - 0.55, y0 + 2.6), (px, y0 + 2.1), (px + 0.55, y0 + 2.6), (px + 0.55, y0 + 3.0), (px, y0 + 2.5), (px - 0.55, y0 + 3.0)]), 1.22, 1.27)
			S.light(Mf, cx, (y0 + y1) / 2, 2.4, "#FF7A3D" if sx < 0 else "#3A94FF", 1.0, 8)
			# corner light tower at the front corner: shoe, faceted post, a team stripe, an angled lamp head
			tx, ty = sx * (x1 - 0.2), y0 + 0.3
			P["V_Base"].prism(V.ccw(S.cham_rect(tx - 0.9, tx + 0.9, ty - 0.9, ty + 0.9, 0.3)), 1.18, 1.6)
			P["V_Wall"].prism(V.ccw(S.cham_rect(tx - 0.55, tx + 0.55, ty - 0.55, ty + 0.55, 0.18)), 1.6, 3.9)  # waist-high: never in front of the screen
			P[paint].prism(V.ccw(S.cham_rect(tx - 0.58, tx + 0.58, ty - 0.58, ty + 0.58, 0.18)), 3.0, 3.35)
			P["V_Trim"].prism(V.ccw(S.cham_rect(tx - 0.75, tx + 0.75, ty - 0.75, ty + 0.75, 0.25)), 3.9, 4.2)
			P["V_Dark"].solid([(px_, py_, 4.2) for px_, py_ in V.ccw(S.cham_rect(tx - 0.6, tx + 0.6, ty - 0.4, ty + 0.9, 0.2))],
				[(px_, py_ + 0.4, 5.0) for px_, py_ in V.ccw(S.cham_rect(tx - 0.5, tx + 0.5, ty - 0.2, ty + 0.9, 0.18))])
			P["E_White"].box(tx - 0.32, tx + 0.32, ty + 1.22, ty + 1.32, 4.3, 4.85)
			S.collider(AREA, Mf, tx - 0.5, tx + 0.5, ty - 0.5, ty + 0.5, 1.2, 4.2, "B")
			S.light(Mf, cx, (y0 + y1) / 2 - 1.0, 9.6, V.WHITE, 1.2, 14, 70)
		# VS pylon between the team plates, at the back
		P["V_Base"].prism(V.ccw(S.cham_rect(-1.0, 1.0, y1 - 2.4, y1 - 0.6, 0.3)), 1.18, 1.6)
		P["V_Wall"].solid([(a, b, 1.6) for a, b in V.ccw(S.cham_rect(-0.75, 0.75, y1 - 2.2, y1 - 0.8, 0.2))], [(a, b, 4.4) for a, b in V.ccw(S.cham_rect(-0.6, 0.6, y1 - 2.0, y1 - 0.9, 0.18))])
		P["V_Trim"].prism(V.ccw(S.cham_rect(-0.75, 0.75, y1 - 2.15, y1 - 0.75, 0.2)), 4.4, 4.65)
		P["V_Dark"].box(-0.62, 0.62, y1 - 2.34, y1 - 2.08, 2.15, 3.55)  # VS plate seated into the pylon face
		Mv = Mf @ V.T(0, y1 - 2.34, 2.4) @ V.RX(90)
		S.add_text(S.FK(KD, Mv)["V_GoldPaint"], "VS", 0.85, 0.06, y0=0.0, z0=0.0, s=0.22, c=0.06, ci=0.02)
		S.collider(AREA, Mf, -0.55, 0.55, y1 - 2.0, y1 - 1.0, 1.2, 4.4, "B")
	V.hazard_strip(KD, M @ V.RX(-90), -9.4, 9.4, -14.75, -14.1, 0.12)  # hazard edge in front of the step
	V.sign(KD, M @ V.T(0, h + 1.6, 0), mode.upper(), 11.0, 5.0, accent="E_Gold", tilt=10, standoff=0.8, name="BaySign", light=False, lh=3.1, chevrons=False)
	c = Mf @ Vector((0, -6.9, 3.6))
	if mode in ("1v1", "2v2", "3v3"):
		S.ANCHORS.append([f"Queue_{idx}_{mode}", "LobbyQueue", round(c.x, 3), round(c.y, 3), round(c.z, 3), 15.0, 11.0, 5.0, {"Mode": mode}])


def trophy(K, KD):
	"""THE GAUNTLET: a faceted gold fist on a stepped plinth at the end of the spawn sightline, turning slowly."""
	cx, cy = 0.0, YE - 9.0
	Mp = Matrix.Translation((cx, cy, Z0))
	with C.grp("TrophyPlinth", Mp):
		F = S.FK(K, Mp)
		F["V_Base"].prism(V.ccw(V.oct_pts(6.6)), 0, 1.4)
		F["V_Wall"].prism(V.ccw(V.oct_pts(5.2)), 1.4, 5.6)
		G = S.FK(KD, Mp)
		for r0, r1, z0, z1, m in ((6.0, 6.7, 1.2, 1.5, "V_Trim"), (5.0, 5.35, 4.6, 4.9, "E_Gold"), (4.6, 5.3, 5.5, 5.9, "V_Trim")):
			o, i = V.oct_pts(r1), V.oct_pts(r0)
			for k in range(8):
				j = (k + 1) % 8
				G[m].prism(V.ccw([i[k], i[j], o[j], o[k]]), z0, z1)
	z = Z0 + 5.9
	Mt = Matrix.Translation((cx, cy, z))
	with C.grp("Trophy", Mt):
		T = S.FK(KD, Mt)
		# cuff: an 8-sided taper with a light band and a gold rim
		lo, hi = V.oct_pts(2.4), V.oct_pts(2.9)
		T["V_Gold"].solid([(x, y, 0.2) for x, y in lo], [(x, y, 3.6) for x, y in hi])
		T["V_Trim"].prism(V.ccw(V.oct_pts(3.05)), 3.4, 3.9)
		T["V_Base"].prism(V.ccw(V.oct_pts(2.2)), 0, 0.3)
		# a closed fist, knuckles to the hall (-Y): back of the hand, a knuckle bar with four faceted caps, four squat
		# finger segments folded under it, the tucked fingertips, the thumb across the front
		T["V_Gold"].solid([(x, y, 3.9) for x, y in V.ccw(S.cham_rect(-2.9, 2.9, -0.6, 1.9, 0.5))],
			[(x, y, 8.1) for x, y in V.ccw(S.cham_rect(-3.2, 3.2, -0.95, 1.6, 0.5))])
		T["V_Gold"].ext_x(V.ccw([(-0.9, 8.0), (-0.9, 9.3), (-1.4, 9.7), (-2.7, 9.7), (-3.4, 9.1), (-3.4, 8.0)]), -3.15, 3.15)
		for k in range(4):
			fx = -2.34 + k * 1.56
			lift = (0.0, 0.2, 0.15, -0.15)[k]
			T["V_Gold"].ext_x(V.ccw([(-0.7, 4.6), (-0.7, 8.1), (-3.5, 8.1), (-3.95, 7.6), (-3.95, 5.4), (-3.4, 4.6)]), fx - 0.71, fx + 0.71)
		T["V_Gold"].ext_x(V.ccw([(-0.7, 4.0), (-0.7, 4.7), (-3.2, 4.7), (-2.6, 4.0)]), -3.0, 2.0)  # tucked tips
		T["V_Gold"].ext_x(V.ccw([(-3.7, 5.0), (-3.7, 6.5), (-4.55, 6.35), (-4.65, 5.2)]), -0.8, 3.3)  # thumb across
		T["V_Gold"].prism(V.ccw(S.cham_rect(2.9, 3.75, -3.9, 0.4, 0.3)), 4.6, 7.0)  # thumb root
		T["V_Trim"].prism(V.ccw(S.cham_rect(-3.1, 3.1, 1.75, 2.0, 0.1)), 4.4, 7.6)  # back plate rib
	S.ANIM["Trophy"] = {"pivot": [cx, cy, z], "spin": 9, "axis": [0, 0, 1]}
	S.light(Matrix.Identity(4), cx, cy, Z0 + H - 1.0, V.WHITE, 3.0, 34, 38)


def island(K, KD):
	cx, cy = 0.0, 112.0
	M = Matrix.Translation((cx, cy, Z0))
	with C.grp("Island", M):
		F = S.FK(K, M)
		G = S.FK(KD, M)
		F["V_Base"].prism(V.ccw(V.oct_pts(5.4)), 0, 1.0)
		F["V_Wall"].prism(V.ccw(V.oct_pts(4.6)), 1.0, 7.0)
		G["V_Trim"].prism(V.ccw(V.oct_pts(5.0)), 6.6, 7.4)
		G["E_Gold"].prism(V.ccw(V.oct_pts(4.2)), 7.4, 7.55)
		G["V_Dark"].prism(V.ccw(V.oct_pts(3.4)), 7.55, 8.1)
		# the sitting kerb: eight faceted blocks round the kiosk, with a light seat top and a gap at the lane
		o, i = V.oct_pts(11.6), V.oct_pts(9.2)
		for k in range(8):
			j = (k + 1) % 8
			quad = V.ccw([i[k], i[j], o[j], o[k]])
			F["V_Low"].prism(V.inset(quad, 0.12), 0, 1.5)
			G["V_Seat"].prism(V.inset(quad, 0.0), 1.5, 1.85)
	for th, title in ((270, "QUEUES"), (90, "LAST MATCHES"), (0, "QUEUES"), (180, "LAST MATCHES")):
		c, s = cos(radians(th)), sin(radians(th))
		Mk = S.face((cx + 4.6 * c, cy + 4.6 * s, Z0), (-s, c, 0), (c, s, 0))  # on the kiosk face, Z out
		S.screen("queue_summary", title, "", Mk, 0, 4.2, 0.16, 3.4, 3.8)
		S.FK(KD, Mk)["V_Trim"].prism(V.ccw(S.cham_rect(-1.95, 1.95, 2.0, 6.4, 0.25)), -0.05, 0.12)
	S.light(Matrix.Identity(4), cx, cy, Z0 + H - 1.0, V.WHITE, 1.4, 32, 70)


def ceiling(K, KD):
	z = Z0 + H
	apse = [(-X, Y1), (-XE, YE), (XE, YE), (X, Y1)]
	V.slab_with_hole(K, -X - 4, X + 4, Y0 - 4, Y1 - 4.0, -16.0, 16.0, 66.0, Y1 - 8.0, z)  # the nave opening
	V.nave_vault(K, KD, Matrix.Identity(4), 16.0, 66.0, Y1 - 8.0, z, rise=10.0, top=10.0, lamp=(7.0, 2.2), name="NaveVault")
	K["V_Ceil"].prism(V.inset(V.ccw(apse), -4.0), z, z + 1.5)
	K["V_Slab"].box(-X - 4, X + 4, Y0 - 4, Y1 - 4.0, Z0 - 1.2, Z0)
	K["V_Slab"].prism(V.inset(V.ccw(apse), -4.0), Z0 - 1.2, Z0)
	for y in (66.0,) + PIERS:
		KD["V_Beam"].ext_x(V.ccw([(y - 1.6, z + 0.3), (y - 1.6, z - 2.0), (y - 0.9, z - 2.8), (y + 0.9, z - 2.8), (y + 1.6, z - 2.0), (y + 1.6, z + 0.3)]), -X, X)
	for x in (-16.0, 16.0):
		KD["V_Beam"].ext_y(V.ccw([(x - 1.3, z + 0.25), (x - 1.3, z - 1.4), (x - 0.7, z - 2.0), (x + 0.7, z - 2.0), (x + 1.3, z - 1.4), (x + 1.3, z + 0.25)]), Y0, Y1 + 6.0)
	for y0, y1 in ((66.0, PIERS[0]), (PIERS[0], PIERS[1]), (PIERS[1], Y1)):
		ym = (y0 + y1) / 2
		for sx in (-1, 1):  # side aisles; the nave is lit from the vault top
			V.ceiling_lamp(KD, sx * 29.0, ym, z, 5.0, 1.2)
			S.light(Matrix.Identity(4), sx * 29.0, ym, z - 0.4, V.WHITE, 1.2, 32, 80)


def floor(K, KD):
	# plates over the hall: 7 x 7, with the lane down the middle to the island
	ys = [72.8 + k * (Y1 - 72.8) / 7 for k in range(8)]
	xs = [-X + k * 12.0 for k in range(8)]
	for a in range(7):
		for b in range(7):
			mat = "V_Floor" if (a + b) % 2 == 0 else "V_Floor2"
			KD[mat].box(xs[b] + 0.125, xs[b + 1] - 0.125, ys[a] + 0.125, ys[a + 1] - 0.125, Z0, Z0 + 0.12)
	apse = [(-X, Y1), (-XE, YE), (XE, YE), (X, Y1)]
	KD["V_Floor2"].prism(V.inset(V.ccw(apse), 0.125), Z0, Z0 + 0.12)
	KD["V_Lane"].box(-6, 6, 72.8, 100.2, Z0 + 0.12, Z0 + 0.17)
	for sx in (-1, 1):
		KD["V_GoldPaint"].box(sx * 6.1, sx * 6.5, 72.8, 100.2, Z0 + 0.12, Z0 + 0.19)
		KD["V_GoldPaint"].box(sx * 6.1, sx * 6.5, 46.0, Y0 - 4.0, 0.12, 0.19)  # through the hub tunnel
		KD["V_GoldPaint"].box(sx * 6.1, sx * 6.5, Y0, 70.0, 0.12, 0.19)  # across the landing
	for y in (76.0, 82.0, 88.0):
		V.chevron(KD, Matrix.Identity(4), 0, y, 4.0, z=Z0 + 0.17)
	for sx in (-1, 1):
		V.grate(KD, Matrix.Identity(4), sx * 7.8 - 1.0, sx * 7.8 + 1.0, 73.6, 99.6, Z0 + 0.12)  # clear of the pads (they stop at |x| 28)
	V.floor_text(KD, Matrix.Translation((0, 92.6, Z0)), "PLAY", 2.2, z=0.17)


def landing(K, KD):
	"""The arrival landing (hub floor level) with three steps down the middle and parapets either side: the overlook."""
	F, G = K, KD
	F["V_Floor2"].box(-20.0, 20.0, Y0 - 4.0, 70.0, Z0, 0.0)
	G["V_Floor2"].box(-(PHW - 4.0), PHW - 4.0, Y0 - 4.0, 70.0, 0.0, 0.12)
	for k, (y0, y1) in enumerate(((70.0, 71.4), (71.4, 72.8))):
		F["V_Floor2"].box(-10.0, 10.0, y0, y1, Z0, -1.0 - k)
		G["V_Trim"].box(-10.0, 10.0, y1 - 0.35, y1, -1.0 - k - 0.02, -1.0 - k + 0.06)
	G["V_Trim"].box(-10.0, 10.0, 69.65, 70.05, -0.02, 0.15)
	for sx in (-1, 1):
		F["V_Low"].box(sx * 10.0, sx * 20.0, 68.8, 70.0, 0.0, 3.2)
		F["V_Low"].box(sx * 18.8, sx * 20.0, Y0 + 0.3, 68.8, 0.0, 3.2)
		G["V_Trim"].box(sx * 9.8, sx * 20.2, 68.6, 70.2, 3.2, 3.6)
		G["V_Trim"].box(sx * 18.6, sx * 20.2, Y0 + 0.3, 68.6, 3.2, 3.6)
		G["V_Wall"].box(sx * 10.0, sx * 20.0, 70.0, 70.6, Z0, 0.0)  # landing face (one step proud of the parapet base)
		G["E_Gold"].box(sx * 10.6, sx * 19.4, 70.6, 70.75, -1.6, -1.3)  # a gold line under the lip
	# the mouth: the hub tunnel's lining continues through the 4-stud front wall
	M = frame((0, Y0), (-1, 0))
	FD = S.FK(KD, M)
	S.u_frame(FD["V_Trim"], PHW, 23.0, PHW - 1.5, 21.6, -1.0, 1.6, ci=2.8, y0=3.0)
	S.u_frame(FD["V_Wall"], PHW - 1.5, 21.6, PHW - 2.8, 20.3, -3.0, 0.9, co=2.8, ci=2.6, y0=3.0)
	S.u_frame(FD["V_Low"], PHW - 2.8, 20.3, PHW - 4.0, 19.1, -4.2, 0.3, co=2.6, ci=2.4, y0=3.0)
	S.light(M, 0, 21.0, 5.0, V.WHITE, 1.6, 22, 80)


def walls(K, KD):
	b_left = list(BAYS)
	modes_left = ["1v1", "1v1", "1v1"]
	modes_right = ["4v4", "3v3", "3v3"]  # near to far on the right: read clockwise it is 3v3, 3v3, 4v4 from the apse
	idx = 0
	# west (left) wall: local x = world y
	Mw = frame((-X, 0), (0, 1))
	ops = [(y - BAY_HW, y + BAY_HW, 0, BAY_H) for y in b_left]
	V.wall_run(K, KD, Mw, Y0 - 4.0, Y1 - 1.6, H, ops, dx0=Y0 + 2.0)
	for y, m in zip(b_left, modes_left):
		idx += 1
		bay(K, KD, frame((-X, y), (0, 1)), m, idx)
	# apse: west face, end face, east face
	ang = [((-X, Y1), (-XE, YE)), ((-XE, YE), (XE, YE)), ((XE, YE), (X, Y1))]
	for k, (p, q) in enumerate(ang):
		p, q = Vector(p), Vector(q)
		L = (q - p).length
		Ma = frame(p, q - p)
		if k == 1:
			V.wall_run(K, KD, Ma, 1.6, L - 1.6, H, panel_skip=[(L / 2 - 14, L / 2 + 14)])
			V.sign(KD, Ma @ V.T(L / 2, 19.0, 0), "THE GAUNTLET", 26.0, 5.2, accent="E_Gold", tilt=8, name="Sign_Gauntlet", shape="ribbon", icon="crown", icon_at="top", icon_size=4.0)
			S.FK(KD, Ma)["E_Gold"].prism(V.ccw(S.cham_rect(L / 2 - 9, L / 2 + 9, 1.6, 2.0, 0.15)), 0.3, 0.7)
		else:
			V.wall_run(K, KD, Ma, 1.6, L - 1.6, H, [(L / 2 - BAY_HW, L / 2 + BAY_HW, 0, BAY_H)])
			idx += 1
			bay(K, KD, frame(p + (q - p).normalized() * (L / 2), q - p), "2v2", idx)
	# east (right) wall: local x = -world y
	Me = frame((X, 0), (0, -1))
	ops = [(-y - BAY_HW, -y + BAY_HW, 0, BAY_H) for y in b_left]
	V.wall_run(K, KD, Me, -(Y1 - 1.6), -(Y0 - 4.0), H, ops, dx1=-(Y0 + 2.0))
	for y, m in zip(reversed(b_left), list(reversed(modes_right))):
		idx += 1
		bay(K, KD, frame((X, y), (0, -1)), m, idx)
	# front wall (the hub side), seen from the hall: local x = -world x
	Mf = frame((0, Y0), (-1, 0))
	Mfloor = Mf @ V.RX(-90)
	with C.grp("Props_Front", Mf):  # one odd group on the side without vents, clear of the corner pier
		V.prop_group(K, Mfloor, [("crate", 32.8, -3.4, 0.0, 3), ("case", 28.0, -2.0, 0.0, -2), ("case", 28.2, -2.0, 1.62, 4)])
	with C.grp("FrontDetails", Mf):
		for sx in (-1, 1):
			if sx < 0:
				V.plaque(KD, Mf, sx * 18.4, 10.6, 3.6, 2.6, "warning", "WARNING", ["MATCH STARTS ON", "LAMP FLASH"])
			V.beacon(KD, Mf, sx * 18.4, 14.2)
			for x in ((27.6, 31.2) if sx < 0 else ()):
				V.vent(KD, Mf, sx * x, 2.6, 3.0, 2.2)
	V.wall_run(K, KD, Mf, -X, X, H, [(-PHW, PHW, 3.0, 23.0)], panel_skip=[(-PHW - 1.0, PHW + 1.0), (15.6, 25.2), (-25.2, -15.6)], dx0=-X + 2.0, dx1=X - 2.0)
	# piers: three between bays on each side, one at every apse corner
	for y in PIERS:
		V.pier_at(K, KD, frame((-X, y), (0, 1)), H, AREA, w=3.0)
		V.pier_at(K, KD, frame((X, y), (0, -1)), H, AREA, w=3.0)
	for p, zin in (((-X, Y1), (0.924, -0.383)), ((X, Y1), (-0.924, -0.383)), ((-XE, YE), (0.383, -0.924)), ((XE, YE), (-0.383, -0.924))):
		M = corner_frame(p, zin)
		V.pier_at(K, KD, M, H, AREA, w=2.8, d=3.0, name="CornerPier")
		S.FK(K, M)["V_Wall"].box(-3.0, 3.0, 0, H, -4.6, -0.9)  # fills the slab corner behind
	for sx in (-1, 1):  # front corners: a pier on the bisector covers where the side and front walls meet
		V.pier_at(K, KD, corner_frame((sx * X, Y0), (-sx * 0.7071, 0.7071)), H, AREA, w=2.8, d=3.0, name="CornerPier")


def build():
	K = S.kit(AREA, nocol=False)
	KD = C.Kit(K.col, prefix=AREA + "D")
	KD.nocol = True
	landing(K, KD)
	floor(K, KD)
	walls(K, KD)
	island(K, KD)
	trophy(K, KD)
	ceiling(K, KD)
	return K.done() + KD.done()


floor = V.grouped(floor, "DuelsFloor")
ceiling = V.grouped(ceiling, "DuelsCeiling")
landing = V.grouped(landing, "Landing")
