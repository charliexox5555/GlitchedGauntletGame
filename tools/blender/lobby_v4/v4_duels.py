"""Lobby V4, section 2: Duels (V5, owner 2026-11-16: "the pads more like RIVALS ... see-through glass, much larger,
highlights when a player walks over ... sections ... big TVs ... more fun, bigger"). A long hall past the hub's Duels
portal: a landing with steps down (-3), 88 wide, straight to y 222 then a faceted three-face apse to y 244. Eight big
queue pads along the side walls, a pier with a bar lamp between each (one section per pad): a raised deck with two
sunken team wells under tinted glass and a lit emblem below, a hazard divider, light posts; two tall TVs on the wall
behind (blank until the pad UI) and the mode sign over them. Near to far: left 1v1, 1v1, 2v2, 2v2; right 3v3, 3v3,
4v4, 5v5. A four-sided screen cube hangs mid hall (the island went, owner), the gauntlet trophy under THE GAUNTLET at the end. The client draws the
ring holograms and the glow when a player stands on a team well (LobbyPadFx). Plan: vault/02 Art/Lobby V4 Build.md.
"""
from math import cos, sin, radians, pi, sqrt

from mathutils import Matrix, Vector

import lv3_core as C
import sw_core as S
import v4_core as V

AREA = "Duels"
Z0 = -3.0  # hall floor
H = 30.0  # wall height above the hall floor
X = 44.0  # half width
Y0, Y1, YE = 62.0, 222.0, 244.0  # front wall face, apse start, end wall
XE = 20.0  # half width of the apse end face
PADS = (86.0, 120.0, 154.0, 188.0)  # pad centres along each side wall (one section each)
PIERS = (103.0, 137.0, 171.0, 205.0)
PHW = 11.5  # the hub Duels portal half width (v4_hub.DUELS_HW): the mouth continues its lining
PAD_HW, PAD_D, SQ = 12.5, 14.5, 11.0  # pad half width along the wall, depth into the hall, team well side
MODES_LEFT = ("1v1", "1v1", "2v2", "2v2")  # near to far
MODES_RIGHT = ("3v3", "3v3", "4v4", "5v5")
LIVE = ("1v1", "2v2", "3v3")  # modes with a queue today (4v4 / 5v5: soon)
PLAYERS = {"1v1": 1, "2v2": 2, "3v3": 3, "4v4": 4, "5v5": 5}


def frame(origin, xdir):
	"""Wall face frame at origin (floor level of the hall), X along xdir, Z = into the hall (left of xdir, seen from above)."""
	x = Vector(xdir).normalized()
	z = Vector((x.y, -x.x, 0))
	return S.face((origin[0], origin[1], Z0), (x.x, x.y, 0), (z.x, z.y, 0))


def corner_frame(p, zin):
	z = Vector(zin).normalized()
	return S.face((p[0], p[1], Z0), (-z.y, z.x, 0), (z.x, z.y, 0))


def _box_size(M, sx, sy, sz):
	"""World (Blender) axis sizes of a box sx x sy x sz in frame M's X / Y / Z."""
	R = M.to_3x3()
	ax, ay, az = R @ Vector((sx, 0, 0)), R @ Vector((0, sy, 0)), R @ Vector((0, 0, sz))
	return [round(abs(ax[i]) + abs(ay[i]) + abs(az[i]), 2) for i in range(3)]


def pad(K, KD, M, mode, idx):
	"""One queue pad at wall frame M (centre on the wall plane; Z points into the hall). After RIVALS' pads, ours:
	a raised deck with a steel rim and a front step; two sunken team wells (A orange, B blue) under tinted glass, a
	glowing octagon emblem on each well floor, a hazard divider between them, light posts at the front corners; on
	the wall two tall blank TVs (one per team) with hoods and glow strips, the mode sign over them."""
	hw, d, sq = PAD_HW, PAD_D, SQ
	live = mode in LIVE
	with C.grp("Pad_" + mode, M, inst=True):
		FD = S.FK(KD, M)
		# the wall: two tall TVs (one per team), a hood over each, a team glow strip under each
		for sx, glow in ((-1, "E_TeamA"), (1, "E_TeamB")):
			cx = sx * 6.3
			S.ring_prism(FD["V_Trim"], V.ccw(S.cham_rect(cx - 5.6, cx + 5.6, 3.9, 19.1, 0.6)), V.ccw(S.cham_rect(cx - 5.0, cx + 5.0, 4.5, 18.5, 0.4)), 0.42, 1.2)
			FD["V_Dark"].prism(V.ccw(S.cham_rect(cx - 5.05, cx + 5.05, 4.45, 18.55, 0.4)), 0.5, 0.85)  # seated into the wall trims
			FD["G_Screen"].prism(V.ccw(S.cham_rect(cx - 4.95, cx + 4.95, 4.55, 18.45, 0.35)), 0.85, 0.9)
			FD[glow].box(cx - 4.2, cx + 4.2, 3.6, 3.95, 0.5, 1.12)  # a lit bar under the frame, seated into the wall
			FD["V_Steel"].ext_x(V.ccw([(19.1, 0.55), (19.1, 1.4), (19.4, 1.9), (19.75, 1.9), (19.75, 0.55)]), cx - 5.2, cx + 5.2)
			c = M @ Vector((cx, 11.5, 0.9))
			n = M.to_3x3() @ Vector((0, 0, 1))
			bs = _box_size(M, 10.0, 14.0, 0.2)
			S.ANCHORS.append([f"PadBoard_{idx}_{'A' if sx < 0 else 'B'}", "LobbyPadBoard", round(c.x, 3), round(c.y, 3), round(c.z, 3), bs[0], bs[1], bs[2],
				{"Pad": idx, "Team": 1 if sx < 0 else 2, "Mode": mode, "NX": round(n.x, 4), "NY": round(n.y, 4)}])
		S.light(M, 0, 21.5, 4.0, V.WHITE, 1.3, 22, 80)
		# the deck on the hall floor (floor frame: X along the wall, Y into the wall, so the hall is -Y)
		Mf = M @ V.RX(-90)
		P = S.FK(KD, Mf)
		y1, y0 = -1.0, -1.0 - d  # back edge (by the wall), front edge
		wy0, wy1 = y0 + 1.5, y0 + 1.5 + sq  # the wells, front to back
		ax0, ax1 = -0.8 - sq, -0.8  # well A across; well B is mirrored
		P["V_Floor2"].prism(V.ccw(S.cham_rect(-hw - 0.6, hw + 0.6, y0 - 1.2, y1, 0.5)), 0.12, 0.5)  # front step
		P["V_Trim"].prism(V.ccw(S.cham_rect(-hw - 0.66, hw + 0.66, y0 - 1.26, y0 - 0.75, 0.2)), 0.45, 0.57)  # its nosing
		# the deck around the wells: front, back, ends and the middle strip
		for x0_, x1_, y0_, y1_ in ((-hw, hw, y0, wy0), (-hw, hw, wy1, y1), (-hw, ax0, wy0, wy1), (-ax0, hw, wy0, wy1), (ax1, -ax1, wy0, wy1)):
			P["V_Base"].box(x0_, x1_, y0_, y1_, 0.12, 1.0)
		S.ring_prism(P["V_Steel"], V.ccw(S.cham_rect(-hw, hw, y0, y1, 0.6)), V.ccw(S.cham_rect(-hw + 0.45, hw - 0.45, y0 + 0.45, y1 - 0.45, 0.4)), 1.0, 1.2)
		P["V_Dark"].box(-hw + 0.45, hw - 0.45, y1 - 1.55, y1 - 0.45, 1.0, 1.08)  # back walkway plate
		V.hazard_strip(KD, Mf @ Matrix.Rotation(radians(90), 4, "Z"), wy0 + 0.1, wy1 - 0.1, -0.5, 0.5, 1.0, step=1.0)  # the divider (stripes across it)
		for sx, glow, paint, glass in ((-1, "E_TeamA", "V_TeamA", "G_PadA"), (1, "E_TeamB", "V_TeamB", "G_PadB")):
			a0, a1 = (ax0, ax1) if sx < 0 else (-ax1, -ax0)
			cx, cy = (a0 + a1) / 2, (wy0 + wy1) / 2
			P["V_Dark"].box(a0, a1, wy0, wy1, 0.12, 0.62)  # the well floor
			Me = Mf @ Matrix.Translation((cx, cy, 0.62))
			E = S.FK(KD, Me)
			S.ring_prism(E[glow], V.ccw(V.oct_pts(4.7)), V.ccw(V.oct_pts(4.3)), 0.0, 0.06)  # the emblem, lit under the glass
			S.ring_prism(E[paint], V.ccw(V.oct_pts(3.0)), V.ccw(V.oct_pts(2.4)), 0.0, 0.05)
			E[glow].prism(V.ccw(V.oct_pts(0.6)), 0.0, 0.06)
			for k in range(4):
				Er = S.FK(KD, Me @ Matrix.Rotation(radians(90 * k), 4, "Z"))
				Er[paint].box(3.3, 4.0, -0.2, 0.2, 0.0, 0.05)
			P[glass].box(a0, a1, wy0, wy1, 0.92, 1.0)  # the glass, flush with the deck
			S.ring_prism(P[glow], V.ccw(S.cham_rect(a0 - 0.2, a1 + 0.2, wy0 - 0.2, wy1 + 0.2, 0.15)), V.ccw(S.cham_rect(a0, a1, wy0, wy1, 0.05)), 1.0, 1.07)
			S.light(Me, 0, 0, 0.4, "#FF7A3D" if sx < 0 else "#3A94FF", 0.9, 9)
			S.light(Mf, cx, cy, 10.5, V.WHITE, 1.1, 15, 70)
			c = Mf @ Vector((cx, cy, 1.0))
			S.ANCHORS.append([f"PadSquare_{idx}_{'A' if sx < 0 else 'B'}", "LobbyPadSquare", round(c.x, 3), round(c.y, 3), round(c.z, 3), sq, sq, 1.0,
				{"Pad": idx, "Team": 1 if sx < 0 else 2, "Mode": mode}])
			# a light post at the front corner: shoe, faceted post, team stripe, an angled lamp head
			tx, ty = sx * (hw - 0.2), y0 + 0.3
			P["V_Base"].prism(V.ccw(S.cham_rect(tx - 0.9, tx + 0.9, ty - 0.9, ty + 0.9, 0.3)), 1.2, 1.6)
			P["V_Wall"].prism(V.ccw(S.cham_rect(tx - 0.55, tx + 0.55, ty - 0.55, ty + 0.55, 0.18)), 1.6, 4.6)
			P[paint].prism(V.ccw(S.cham_rect(tx - 0.58, tx + 0.58, ty - 0.58, ty + 0.58, 0.18)), 3.6, 3.95)
			P["V_Trim"].prism(V.ccw(S.cham_rect(tx - 0.75, tx + 0.75, ty - 0.75, ty + 0.75, 0.25)), 4.6, 4.9)
			P["V_Dark"].solid([(px_, py_, 4.9) for px_, py_ in V.ccw(S.cham_rect(tx - 0.6, tx + 0.6, ty - 0.4, ty + 0.9, 0.2))],
				[(px_, py_ + 0.4, 5.7) for px_, py_ in V.ccw(S.cham_rect(tx - 0.5, tx + 0.5, ty - 0.2, ty + 0.9, 0.18))])
			P["E_White"].box(tx - 0.32, tx + 0.32, ty + 1.22, ty + 1.32, 5.0, 5.55)
			S.collider(AREA, Mf, tx - 0.5, tx + 0.5, ty - 0.5, ty + 0.5, 1.2, 4.9, "B")
		S.collider(AREA, Mf, -hw + 0.2, hw - 0.2, y0 + 0.2, y1 - 0.2, 0.12, 1.0, "B")
		S.collider(AREA, Mf, -hw - 0.4, hw + 0.4, y0 - 1.0, y0 + 0.2, 0.12, 0.5, "B")
	V.hazard_strip(KD, M @ V.RX(-90), -hw + 0.4, hw - 0.4, -1.0 - d - 2.0, -1.0 - d - 1.35, 0.12)  # hazard edge in front of the step
	V.sign(KD, M @ V.T(0, 21.6, 0), mode.upper(), 12.0, 5.0, accent="E_Gold", tilt=10, standoff=0.8, name="PadSign", light=False, lh=3.1, chevrons=False)
	Mf = M @ V.RX(-90)
	if live:  # step onto the pad: the Queue menu opens with this mode (WorldPrompts step pads)
		c = Mf @ Vector((0, -1.0 - d / 2, 3.0))
		qs = _box_size(Mf, 2 * hw - 1.0, d - 1.0, 5.0)
		S.ANCHORS.append([f"Queue_{idx}_{mode}", "LobbyQueue", round(c.x, 3), round(c.y, 3), round(c.z, 3), qs[0], qs[1], qs[2], {"Mode": mode, "Trigger": "Step"}])


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


def jumbotron(K, KD):
	"""A four-sided screen cube hanging over the middle of the hall (an arena's scoreboard): a faceted dark body, a
	blank screen on each face (LobbyHallBoard anchors for the UI later), trim caps, a violet light ring under it,
	four steel hangers up into the vault."""
	cy, z0, z1 = 154.8, Z0 + 17.0, Z0 + 24.0  # between two vault lamps (147.4, 162.2): the hangers miss them
	hw = 6.4
	M = Matrix.Translation((0.0, cy, 0.0))
	with C.grp("Jumbotron", M):
		G = S.FK(KD, M)
		G["V_Dark"].prism(V.ccw(S.cham_rect(-hw, hw, -hw, hw, 1.2)), z0, z1)
		G["V_Trim"].prism(V.ccw(S.cham_rect(-hw - 0.4, hw + 0.4, -hw - 0.4, hw + 0.4, 1.4)), z1, z1 + 0.8)
		G["V_Trim"].prism(V.ccw(S.cham_rect(-hw - 0.4, hw + 0.4, -hw - 0.4, hw + 0.4, 1.4)), z0 - 0.8, z0)
		G["V_Dark"].prism(V.ccw(S.cham_rect(-hw + 1.0, hw - 1.0, -hw + 1.0, hw - 1.0, 0.8)), z0 - 1.5, z0 - 0.8)
		S.ring_prism(G["E_ThViolet"], V.ccw(S.cham_rect(-hw + 1.05, hw - 1.05, -hw + 1.05, hw - 1.05, 0.8)), V.ccw(S.cham_rect(-hw + 1.5, hw - 1.5, -hw + 1.5, hw - 1.5, 0.6)), z0 - 1.6, z0 - 1.5)
		for k in range(4):
			R = Matrix.Rotation(radians(90 * k), 4, "Z")
			F = S.FK(KD, M @ R)
			F["G_Screen"].box(-hw + 1.1, hw - 1.1, hw, hw + 0.06, z0 + 0.6, z1 - 0.6)
			F["V_Trim"].box(-hw + 0.7, hw - 0.7, hw - 0.02, hw + 0.12, z0 + 0.25, z0 + 0.6)
			c = M @ R @ Vector((0.0, hw + 0.06, (z0 + z1) / 2))
			n = (M @ R).to_3x3() @ Vector((0, 1, 0))
			S.ANCHORS.append([f"HallBoard_{k + 1}", "LobbyHallBoard", round(c.x, 3), round(c.y, 3), round(c.z, 3), 1.0, 1.0, 1.0,
				{"NX": round(n.x, 4), "NY": round(n.y, 4), "W": round(2 * (hw - 1.1), 2), "H": round(z1 - z0 - 1.2, 2)}])
		for hx in (-3.6, 3.6):
			for hy in (-3.6, 3.6):
				G["V_Steel"].box(hx - 0.14, hx + 0.14, hy - 0.14, hy + 0.14, z1 + 0.8, Z0 + H + 10.3)
	S.light(Matrix.Identity(4), 0.0, cy, z0 - 2.0, V.WHITE, 1.6, 30, 80)


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
	for ym in PADS:  # one lamp over every pad section; the nave is lit from the vault top
		for sx in (-1, 1):
			V.ceiling_lamp(KD, sx * 30.0, ym, z, 6.0, 1.3)
			S.light(Matrix.Identity(4), sx * 30.0, ym, z - 0.4, V.WHITE, 1.2, 32, 80)


def path_run(name, x, y, dx, dy, length, width, spacing, speed, tone):
	"""A spot where the client lays a run of chevrons that light up in a wave along it (LobbyPathFx): start (x, y) on
	the hall floor, direction (dx, dy), length, chevron width and spacing (studs), wave speed (studs a second)."""
	S.ANCHORS.append([name, "LobbyPathRun", round(x, 3), round(y, 3), round(Z0 + 0.17, 3), 1.0, 1.0, 1.0,
		{"DX": dx, "DY": dy, "Length": round(length, 2), "Width": width, "Spacing": spacing, "Speed": speed, "Tone": tone}])


def line_run(name, x, y, dx, dy, length, width, tone):
	"""A spot where the client runs a light pulse along a lit floor line (LobbyPathFx)."""
	S.ANCHORS.append([name, "LobbyLineRun", round(x, 3), round(y, 3), round(Z0 + 0.2, 3), 1.0, 1.0, 1.0,
		{"DX": dx, "DY": dy, "Length": round(length, 2), "Width": width, "Tone": tone}])


def floor(K, KD):
	# plates over the hall (8 x 11), the aisle straight down the middle to the trophy
	ys = [72.8 + k * (Y1 - 72.8) / 11 for k in range(12)]
	xs = [-X + k * 11.0 for k in range(9)]
	for a in range(11):
		for b in range(8):
			mat = "V_Floor" if (a + b) % 2 == 0 else "V_Floor2"
			KD[mat].box(xs[b] + 0.125, xs[b + 1] - 0.125, ys[a] + 0.125, ys[a + 1] - 0.125, Z0, Z0 + 0.12)
	apse = [(-X, Y1), (-XE, YE), (XE, YE), (X, Y1)]
	KD["V_Floor2"].prism(V.inset(V.ccw(apse), 0.125), Z0, Z0 + 0.12)
	ya, yb = 72.8, YE - 17.0  # the aisle, to the trophy plinth
	KD["V_Lane"].box(-6, 6, ya, yb, Z0 + 0.12, Z0 + 0.17)
	KD["E_ThViolet"].box(-6.5, -6.1, ya, yb, Z0 + 0.12, Z0 + 0.19)  # RIVALS runs two lit lines down its aisle; ours: violet and lilac
	KD["E_ThLilac"].box(6.1, 6.5, ya, yb, Z0 + 0.12, Z0 + 0.19)
	for sx in (-1, 1):
		V.grate(KD, Matrix.Identity(4), sx * 8.0 - 1.0, sx * 8.0 + 1.0, ya + 0.8, yb - 0.8, Z0 + 0.12)
		KD["V_GoldPaint"].box(sx * 6.1, sx * 6.5, 46.0, Y0 - 4.0, 0.12, 0.19)  # through the hub tunnel
		KD["V_GoldPaint"].box(sx * 6.1, sx * 6.5, Y0, 70.0, 0.12, 0.19)  # across the landing
	V.floor_text(KD, Matrix.Translation((0, 92.6, Z0)), "PLAY", 2.2, z=0.17)
	# animated (LobbyPathFx): chevrons up the aisle, a light running along each edge line, a short run to every pad
	path_run("PathAisle", 0.0, 99.0, 0.0, 1.0, yb - 2.0 - 99.0, 7.0, 4.0, 42.0, "lilac")
	line_run("LineAisleL", -6.3, ya, 0.0, 1.0, yb - ya, 0.5, "violet")
	line_run("LineAisleR", 6.3, ya, 0.0, 1.0, yb - ya, 0.5, "lilac")
	front = X - 1.0 - PAD_D - 2.3  # the hazard edge in front of each pad's step
	for side, sx in (("L", -1), ("R", 1)):
		for k, y in enumerate(PADS):
			path_run(f"PathPad{side}{k + 1}", sx * 10.0, y, float(sx), 0.0, front - 10.6, 6.0, 3.0, 26.0, "violet")


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
	idx = 0
	skips = [(y - PAD_HW - 0.5, y + PAD_HW + 0.5) for y in PADS]
	# west (left) wall: local x = world y
	Mw = frame((-X, 0), (0, 1))
	V.wall_run(K, KD, Mw, Y0 - 4.0, Y1 - 1.6, H, panel_skip=skips, dx0=Y0 + 2.0)
	for y, m in zip(PADS, MODES_LEFT):
		idx += 1
		pad(K, KD, frame((-X, y), (0, 1)), m, idx)
	# east (right) wall: local x = -world y
	Me = frame((X, 0), (0, -1))
	V.wall_run(K, KD, Me, -(Y1 - 1.6), -(Y0 - 4.0), H, panel_skip=[(-b_, -a_) for a_, b_ in skips], dx1=-(Y0 + 2.0))
	for y, m in zip(PADS, MODES_RIGHT):
		idx += 1
		pad(K, KD, frame((X, y), (0, -1)), m, idx)
	# apse: the end face carries THE GAUNTLET; the angled faces carry crates and vents
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
			V.wall_run(K, KD, Ma, 1.6, L - 1.6, H)
			with C.grp("ApseVents", Ma):
				for u in (L / 2 - 4.0, L / 2 + 4.0):
					V.vent(KD, Ma, u, 2.6, 3.0, 2.2)
			with C.grp("ApseProps", Ma):
				V.prop_group(K, Ma @ V.RX(-90), [("crate", L / 2 - 6.5, -3.4, 0.0, 3), ("crate_s", L / 2 + 6.0, -3.0, 0.0, -6)] if k == 0 else
					[("case", L / 2 - 6.0, -2.0, 0.0, -2), ("case", L / 2 - 5.8, -2.0, 1.62, 4), ("crate", L / 2 + 6.5, -3.4, 0.0, -3)])
	# front wall (the hub side), seen from the hall: local x = -world x
	Mf = frame((0, Y0), (-1, 0))
	Mfloor = Mf @ V.RX(-90)
	with C.grp("Props_Front", Mf):  # one odd group on the side without vents, clear of the corner pier
		V.prop_group(K, Mfloor, [("crate", 34.8, -3.4, 0.0, 3), ("case", 30.0, -2.0, 0.0, -2), ("case", 30.2, -2.0, 1.62, 4)])
	with C.grp("FrontDetails", Mf):
		for sx in (-1, 1):
			if sx < 0:
				V.plaque(KD, Mf, sx * 18.4, 10.6, 3.6, 2.6, "warning", "WARNING", ["MATCH STARTS ON", "LAMP FLASH"])
			V.beacon(KD, Mf, sx * 18.4, 14.2)
			for x in ((29.6, 33.2) if sx < 0 else ()):
				V.vent(KD, Mf, sx * x, 2.6, 3.0, 2.2)
	V.wall_run(K, KD, Mf, -X, X, H, [(-PHW, PHW, 3.0, 23.0)], panel_skip=[(-PHW - 1.0, PHW + 1.0), (15.6, 25.2), (-25.2, -15.6)], dx0=-X + 2.0, dx1=X - 2.0)
	# piers between the pad sections, each with its bar lamp; one at every apse corner
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
	jumbotron(K, KD)
	trophy(K, KD)
	ceiling(K, KD)
	return K.done() + KD.done()


floor = V.grouped(floor, "DuelsFloor")
ceiling = V.grouped(ceiling, "DuelsCeiling")
landing = V.grouped(landing, "Landing")
