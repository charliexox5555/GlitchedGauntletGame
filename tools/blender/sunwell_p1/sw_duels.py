"""Sunwell Works: Duels (the turbine floor), second version (owner's notes 2026-11-11: too plain, pads out of order and
of mixed sizes, mesh holograms looked poor, pads lay over the floor lines).

The blast frame opens onto a raised arrival deck; a ramp runs down the south side to a lowered floor under a row of
skylights. Nine stations stand in bays between cast piers, in mode order along each wall (1v1, 1v1, 2v2, 3v3, then the
locked 4v4). Every station is the same: a gunmetal portal, a framed display (a SurfaceGui screen in Studio), a console
with team footlights, and two equal team pads (A orange, B blue). The sealed GAUNTLET gate closes the doorway's axis.
"""
from math import radians, pi
from mathutils import Matrix, Vector

import lv3_core as C
import sw_core as S
import sw_doors as DR

AREA = "Duels"
ZL = -4.0  # lowered floor
H = 22.0  # lowered floor to ceiling
XE, XW, Y0, Y1 = -43.4, -203.4, 12.0, 56.0
XD = -57.4  # edge of the arrival deck
PTS = [(XW, Y0), (XE, Y0), (XE, Y1), (XW, Y1)]
PW, PD, GAP, PY0 = 10.0, 9.0, 1.6, 4.4  # every team pad: width, depth, gap between the pair, distance from the wall
BEAMS = (-59.4, -87.4, -115.4, -143.4, -171.4, -199.4)  # bay joints: piers, crossbeams
# wall, station centre x, mode, letter, open. Mode order runs away from the doorway on both walls.
STATIONS = [
	("N", -73.4, "1v1", "A", True), ("N", -101.4, "1v1", "B", True), ("N", -129.4, "2v2", "A", True), ("N", -157.4, "3v3", "A", True),
	("N", -185.4, "4v4", "A", False),
	("S", -101.4, "1v1", "C", True), ("S", -129.4, "1v1", "D", True), ("S", -157.4, "2v2", "B", True), ("S", -185.4, "3v3", "B", True),
]
T = Matrix.Translation


def floor_frame(M):
	"""Frame lying on the floor in front of a wall face: x = the viewer's left, y = out from the wall, z = up."""
	R = M.to_3x3()
	x, y = -(R @ Vector((1, 0, 0))), R @ Vector((0, 0, 1))
	o = M.translation
	return Matrix(((x.x, y.x, 0, o.x), (x.y, y.y, 0, o.y), (0, 0, 1, o.z), (0, 0, 0, 1)))


def cham_rect(x0, x1, y0, y1, c):
	return [(x0 + c, y0), (x1 - c, y0), (x1, y0 + c), (x1, y1 - c), (x1 - c, y1), (x0 + c, y1), (x0, y1 - c), (x0, y0 + c)]


def pad(P, cx, team, live, pad_id, mode):
	"""A team pad built like a piece of floor equipment: a flange bolted to the floor, a gunmetal tray, a light channel
	round a rubber deck held by four clamps, deck markings in the team colour (our emblem, two chevrons toward the
	display, the team letter, one pip per player), a light lip at the aisle edge and a cable duct back to the console."""
	with S.grp(f"Pad_{team}", P.M @ Matrix.Translation((cx, PY0 + PD / 2, 0)), inst=True):
		n = int(mode[0])
		paint = ("P_TeamA" if team == "A" else "P_TeamB") if live else "PadOff"
		glow = ("E_TeamA" if team == "A" else "E_TeamB") if live else "PadOff"
		y0, y1 = PY0, PY0 + PD
		x0, x1 = cx - PW / 2, cx + PW / 2
		cy = (y0 + y1) / 2
		cr = cham_rect
		P["PetrolDark"].prism(cr(x0 - 0.22, x1 + 0.22, y0 - 0.22, y1 + 0.22, 1.1), 0.0, 0.1)  # floor flange
		P["Petrol"].prism(cr(x0, x1, y0, y1, 1.0), 0.1, 0.32)  # tray
		S.bolts(P["Steel"], [(cx + sx * (PW / 2 - 0.45), cy + sy * (PD / 2 - 1.5)) for sx in (-1, 1) for sy in (-1, 1)], r=0.11, z0=0.32, h=0.06)
		S.ring_prism(P[glow], cr(x0 + 0.5, x1 - 0.5, y0 + 0.5, y1 - 0.5, 0.8), cr(x0 + 0.72, x1 - 0.72, y0 + 0.72, y1 - 0.72, 0.7), 0.32, 0.4)
		P["PadDark"].prism(cr(x0 + 0.72, x1 - 0.72, y0 + 0.72, y1 - 0.72, 0.7), 0.32, 0.38)  # rubber deck
		for mx, my, hx, hy in ((cx, y0 + 0.61, 0.7, 0.24), (cx, y1 - 0.61, 0.7, 0.24), (x0 + 0.61, cy, 0.24, 0.7), (x1 - 0.61, cy, 0.24, 0.7)):
			P["Graphite"].box(mx - hx, mx + hx, my - hy, my + hy, 0.32, 0.47)  # clamps over the light channel
			S.bolts(P["Steel"], [(mx - hx * 0.55, my - hy * 0.55), (mx + hx * 0.55, my + hy * 0.55)], r=0.07, z0=0.47, h=0.04)
		P[paint].ring(1.5, 2.05, 0.38, 0.42, n=8, cx=cx, cy=cy + 0.5)  # emblem: octagon ring and diamond
		P[paint].prism([(cx - 0.8, cy + 0.5), (cx, cy - 0.3), (cx + 0.8, cy + 0.5), (cx, cy + 1.3)], 0.38, 0.42)
		for k in (0, 1):  # chevrons toward the display
			a = y0 + 1.25 + k * 0.7
			P[paint].prism([(cx - 1.3, a + 0.5), (cx, a), (cx + 1.3, a + 0.5), (cx + 1.3, a + 0.8), (cx, a + 0.3), (cx - 1.3, a + 0.8)], 0.38, 0.42)
		LT = P.at(Matrix.Translation((x1 - 1.35, y1 - 1.25, 0.38)) @ Matrix.Rotation(pi, 4, "Z"))  # read from the aisle
		S.add_text(LT[paint], team, 1.35, 0.04, y0=0.0, z0=0.0, x0=0.0, s=0.22, c=0.1)
		for i in range(n):  # one pip per player on the team
			px = x0 + 1.6 + i * 0.72
			P[glow].box(px - 0.24, px + 0.24, y1 - 1.95, y1 - 1.47, 0.38, 0.43)
		P[glow].box(x0 + 1.8, x1 - 1.8, y1 - 0.34, y1 - 0.16, 0.32, 0.42)  # light lip at the aisle edge
		P["Graphite"].box(cx - 0.6, cx + 0.6, 3.1, y0 - 0.22, 0.0, 0.16)  # cable duct to the console
		for k in (0, 1):
			P["PetrolDark"].box(cx - 0.68, cx + 0.68, 3.35 + k * 0.42, 3.5 + k * 0.42, 0.0, 0.2)
		S.collider(AREA, P.M, x0 - 0.2, x1 + 0.2, y0 - 0.2, y1 + 0.2, 0.0, 0.36, kind="Y")
		if live:
			w = P.M @ Vector((cx, cy, 2.8))
			S.anchor("QueueZone", "LobbyQueue", w.x, w.y, w.z, PW - 1.5, PD - 1.0, 5.0, Mode=mode, PadId=pad_id)


def station(F, u, mode, letter, live):
	B = F.at(T((u, 0, 0)))
	with S.grp(f"Station_{mode}_{letter}", B.M):
		S.u_frame(B["Petrol"], 12.0, 14.2, 10.4, 11.2, 0.0, 1.0, co=2.4, ci=1.6)
		S.u_frame(B["PetrolDark"], 10.4, 11.2, 10.0, 10.8, 0.2, 0.75, co=1.6, ci=1.45)  # inner lip
		B["Charcoal"].prism(S.u_pts(10.4, 11.2, cham=1.6), 0.0, 0.2)
		S.add_text(B["Cream"], mode.upper(), 1.6, 0.32, y0=11.95, z0=0.95, s=0.225, c=0.1, track=0.16)
		B["E_Amber" if live else "PadOff"].box(-3.2, 3.2, 11.45, 11.62, 1.0, 1.06)  # rule under the mode
		S.bolts(B["Steel"], [(s * 11.25, y) for s in (-1, 1) for y in (2.2, 5.2, 8.2)], r=0.24, z0=1.0, h=0.16)
		for s in (-1, 1):  # downlights in the head
			B["Graphite"].box(s * 5.0 - 1.7, s * 5.0 + 1.7, 11.0, 11.2, 0.25, 0.95)
			B["E_Opal" if live else "PadOff"].box(s * 5.0 - 1.4, s * 5.0 + 1.4, 10.93, 11.0, 0.35, 0.85)
		# framed display: the screen itself is a SurfaceGui in Studio
		B["Graphite"].prism(cham_rect(-8.0, 8.0, 3.9, 9.9, 0.5), 0.2, 0.6)
		B["Dark"].box(-7.5, 7.5, 4.4, 9.4, 0.6, 0.63)
		for s in (-1, 1):
			B["Petrol"].box(*sorted((s * 8.0, s * 8.7)), 5.4, 8.4, 0.2, 0.72)  # side clamps
			S.bolts(B["Steel"], [(s * 8.35, 6.0), (s * 8.35, 7.8)], r=0.16, z0=0.72, h=0.1)
		S.screen("queue" if live else "locked", mode.upper(), letter, B.M, 0.0, 6.9, 0.66, 14.8, 4.8)
		# console under the display, with team footlights that match the pads
		B["Graphite"].ext_x([(0.0, 0.2), (0.0, 3.0), (2.3, 2.55), (3.1, 2.0), (3.1, 0.2)], -9.2, 9.2)  # front leans back, top edge cut
		for s in (-1, 1):  # end cheeks a size up, so the console reads as a framed unit
			B["Petrol"].ext_x([(0.0, 0.2), (0.0, 3.14), (2.36, 2.68), (3.3, 2.08), (3.3, 0.2)], *sorted((s * 9.2, s * 9.75)))
		B["Charcoal"].box(-9.2, 9.2, 3.1, 3.26, 0.2, 2.1)  # top plate
		B["PetrolDark"].box(-9.2, 9.2, 0.0, 0.42, 0.2, 3.1)  # kick
		for s, team in ((-1, "A"), (1, "B")):
			gl = ("E_TeamA" if team == "A" else "E_TeamB") if live else "PadOff"
			B[gl].box(*sorted((s * 1.0, s * 8.4)), 1.0, 1.22, 2.7, 2.84)
		B["Steel"].box(-0.5, 0.5, 0.75, 1.5, 2.7, 2.9)
		S.collider(AREA, B.M, -9.6, 9.6, 0.0, 3.2, 0.35, 2.4)
		for sx in (-1, 1):  # the portal legs
			S.collider(AREA, B.M, *sorted((sx * 10.6, sx * 11.8)), 0.0, 11.0, 0.1, 0.85)
		off = PW / 2 + GAP / 2
		P = S.FK(F.K, floor_frame(B.M))
		for s, team in ((-1, "A"), (1, "B")):  # team A on the viewer's left, in front of its half of the display
			pad(P, -s * off, team, live, f"{mode}_{letter}{'W' if team == 'A' else 'E'}", mode)


def pier(F, u):
	"""Cast pier at a bay joint: plinth, shaft, a bracket for the crossbeam, a wall lamp, pipe clamps."""
	P = F.at(T((u, 0, 0)))
	with S.grp("Pier", P.M, inst=True):
		S.taper_y(P["WallBase"], (-2.2, 2.2, 0.0, 2.1), 0.0, (-1.9, 1.9, 0.0, 1.8), 1.6)  # flared foot
		S.taper_y(P["CastTrim"], (-1.85, 1.85, 0.0, 1.75), 1.6, (-1.5, 1.5, 0.0, 1.4), 4.8)
		P["CastTrim"].box(-1.5, 1.5, 4.8, 18.2, 0.0, 1.4)
		P["CastTrim"].ext_x([(18.2, 0.0), (20.3, 0.0), (20.3, 2.6), (19.4, 2.6), (18.2, 1.4)], -1.5, 1.5)  # corbel
		S.collider(AREA, P.M, -1.3, 1.3, 0.0, 18.0, 0.05, 1.2)
		DR.sconce(P.at(T((0, 0, 1.4))), 0.0, 9.6)


def pipes(F, u0, u1, clamps):
	"""Two service pipes high on the wall, held by clamps at the piers."""
	with S.grp("WallPipes", F.M):
		F["Steel"].pipe((u0, 16.6, 0.75), (u1, 16.6, 0.75), 0.34, 12)
		F["SteelDark"].pipe((u0, 17.5, 0.6), (u1, 17.5, 0.6), 0.22, 10)
		for u in clamps:
			F["PetrolDark"].box(u - 0.28, u + 0.28, 16.1, 17.85, 0.0, 1.2)
			F["Steel"].box(u - 0.4, u + 0.4, 16.2, 17.0, 0.35, 1.18)


def gauntlet_gate(F):
	"""The sealed GAUNTLET gate on the doorway's axis: staging art for the future event."""
	with S.grp("GauntletGate", F.M):
		S.u_frame(F["Petrol"], 14.5, 16.8, 12.0, 13.0, 0.0, 1.4, co=3.2, ci=2.4)
		S.u_frame(F["PetrolDark"], 12.0, 13.0, 11.5, 12.5, 0.35, 1.0, co=2.4, ci=2.2)
		F["BlastDoor"].prism(S.u_pts(12.0, 13.0, cham=2.4), 0.0, 0.35)
		F["Dark"].box(-0.09, 0.09, 0.0, 12.4, 0.35, 0.38)  # centre seam
		for s in (-1, 1):
			F["Graphite"].prism([(s * 3.0, 1.6), (s * 10.4, 1.6), (s * 10.4, 9.4), (s * 8.6, 11.2), (s * 3.0, 11.2)], 0.35, 0.52)
			S.bolts(F["Steel"], [(s * 13.25, y) for y in (2.0, 5.5, 9.0, 12.5)], r=0.26, z0=1.4, h=0.18)
			F["PetrolDark"].box(*sorted((s * 3.0, s * 4.2)), 5.6, 7.2, 0.52, 0.72)  # hinge blocks
		F["Graphite"].prism(cham_rect(-2.8, 2.8, 4.2, 10.2, 0.8), 0.35, 0.6)  # crest plate across the seam
		c = lambda x0, x1, y0, y1, z1=1.0: F["Steel"].box(x0 * 2.0, x1 * 2.0, 7.3 + y0 * 2.0, 7.3 + y1 * 2.0, 0.6, z1)
		c(-0.95, 0.95, -0.7, 0.3)
		for i, top in enumerate((1.12, 1.25, 1.2, 1.05)):
			c(-0.95 + i * 0.49, -0.95 + i * 0.49 + 0.43, 0.34, top)
		c(-0.45, 0.72, -0.4, 0.06, 1.2)
		c(-0.72, 0.72, -1.25, -0.74)
		c(-0.98, 0.98, -1.62, -1.29)
		F["Graphite"].box(-3.0, 3.0, 1.6, 3.5, 0.35, 0.52)  # plate under the crest, level with the leaf panels
		S.add_text(F["Cream"], "COMING SOON", 0.75, 0.14, y0=2.2, z0=0.5, s=0.2, c=0.06, track=0.22, space=0.6)
		wd = S.text_width("GAUNTLET", 1.9, s=0.225, track=0.14)
		S.add_text(F["Cream"], "GAUNTLET", 1.9, 0.36, y0=13.9, z0=1.34, x0=-wd / 2 + 1.6, s=0.225, c=0.12, track=0.14)
		for k in range(3):
			S.slash(F["P_Orange"], -wd / 2 - 2.2 + k * 0.85, 14.0, 1.7, 0.4, 0.4, 1.34, 1.6)
		Pf = S.FK(F.K, floor_frame(F.M))
		# two-step stage with cut front corners; it ends 0.8 before the nearest pads (it ran under them before)
		Pf["WallBase"].prism([(-16.5, 0.0), (16.5, 0.0), (16.5, 5.0), (15.1, 6.4), (-15.1, 6.4), (-16.5, 5.0)], 0.0, 0.5)
		Pf["Graphite"].prism([(-15.0, 0.0), (15.0, 0.0), (15.0, 3.4), (14.0, 4.4), (-14.0, 4.4), (-15.0, 3.4)], 0.5, 1.0)
		for k in range(-5, 6):  # hazard dashes along the stage edge
			Pf["P_Orange"].prism([(k * 2.4 - 0.8, 3.0), (k * 2.4 + 0.3, 3.0), (k * 2.4 + 0.8, 3.7), (k * 2.4 - 0.3, 3.7)], 1.0, 1.06)
		S.collider(AREA, Pf.M, -16.3, 16.3, 0.0, 6.2, 0.0, 0.45)
		S.collider(AREA, Pf.M, -14.8, 14.8, 0.0, 4.2, 0.4, 0.95)
		S.collider(AREA, F.M, -11.8, 11.8, 1.0, 12.8, 0.06, 0.28)
		for s in (-1, 1):  # light pylons on the stage
			Py = S.FK(F.K, floor_frame(F.M) @ T((s * 13.0, 1.6, 1.0)))
			Py["PetrolDark"].prism(cham_rect(-0.9, 0.9, -0.9, 0.9, 0.3), 0.0, 0.5)
			Py["Petrol"].prism(cham_rect(-0.6, 0.6, -0.6, 0.6, 0.2), 0.5, 6.4)
			Py["E_Orange"].box(-0.3, 0.3, 0.6, 0.66, 1.3, 5.6)
			Py["PetrolDark"].prism(cham_rect(-0.75, 0.75, -0.75, 0.75, 0.25), 6.4, 6.8)
			S.collider(AREA, Py.M, -0.45, 0.45, -0.45, 0.45, 0.0, 6.6)
		S.light(F.M, 0, 15.0, 7.0, "#FFE9CC", 1.8, 26, angle=110)
		S.light(F.M, 0, 5.0, 6.0, "#FF8A4A", 0.7, 14)


def deck(K, KR):
	"""Arrival deck at hall level, the ramp down the south side, and the guard rail along the overlook."""
	with S.grp("Deck", reuse=True):
		K["Walk"].box(XD, XE, Y0, Y1, ZL, 0.0)
		S.collider(AREA, S.I4, XD + 0.1, XE, Y0, Y1, ZL, -0.045)
		K["Graphite"].box(XD - 0.25, XD + 0.6, 25.2, Y1, -0.45, 0.06)  # nosing along the overlook edge
		K["WallBase"].box(XD - 0.35, XD, 25.2, Y1, ZL, ZL + 1.6)
	with S.grp("DuelsRamp"):
		KR["Rubber"].ext_y([(XD, ZL), (XD, 0.0), (XD - 22.0, ZL)], Y0, 24.0)
		KR["CastTrim"].ext_y([(XD, ZL), (XD, 1.3), (XD - 22.0, ZL + 1.3), (XD - 22.0, ZL)], 24.0, 25.2)
		slope = Matrix.Translation((XD, 18.0, 0.0)) @ Matrix.Rotation(radians(90), 4, "Z") @ Matrix.Rotation(-0.1799, 4, "X")
		R = S.FK(K, slope)  # local y runs down the ramp
		y = 0.4
		while y < 22.0:
			if 8.0 < y < 14.4:
				R["Graphite"].box(-5.6, -3.4, y, y + 0.16, 0, 0.05)
				R["Graphite"].box(3.4, 5.6, y, y + 0.16, 0, 0.05)
			else:
				R["Graphite"].box(-5.6, 5.6, y, y + 0.16, 0, 0.05)
			y += 0.62
		for a in (8.7, 11.0):
			R["P_Cream"].prism([(-2.4, a), (0, a + 1.3), (2.4, a), (2.4, a + 0.75), (0, a + 2.05), (-2.4, a + 0.75)], 0, 0.05)
	with S.grp("OverlookRail"):
		xr = XD + 0.25
		for yy in (26.0, 32.0, 38.0, 44.0, 50.0, 55.4):
			K["Petrol"].box(xr - 0.25, xr + 0.25, yy - 0.25, yy + 0.25, 0.06, 3.0)
		for z in (1.55, 2.8):
			K["Petrol"].box(xr - 0.2, xr + 0.2, 26.0, 55.4, z, z + 0.42)
		S.collider(AREA, S.I4, xr - 0.3, xr + 0.3, 25.2, Y1, 0.0, 3.3, kind="Y")
		S.collider(AREA, S.I4, XD - 22.0, XD, 24.0, 25.2, ZL, 4.6, kind="Y")
	with S.grp("Deck", reuse=True):
		K["WallBase"].box(XD, XE, Y0, Y0 + 0.35, 0.0, 1.5)  # skirting on the deck
		K["WallBase"].box(XD, XE, Y1 - 0.35, Y1, 0.0, 1.5)
		for ya, yb in ((Y0 + 0.35, 24.0), (44.0, Y1 - 0.35)):
			K["WallBase"].box(XE - 0.35, XE, ya, yb, 0.0, 1.5)


def roof(KC):
	"""Ceiling with a skylight in every bay on the centre line, and a crossbeam on corbels at every bay joint."""
	zc = ZL + H
	with S.grp("DuelsRoof"):
		KC["Ceil"].box(XW - 4, XE + 4, Y0 - 4, 26.0, zc, zc + 2)
		KC["Ceil"].box(XW - 4, XE + 4, 42.0, Y1 + 4, zc, zc + 2)
		S.collider(AREA, S.I4, XW - 4, XE + 4, Y0 - 4, 25.8, zc + 0.2, zc + 1.8)
		S.collider(AREA, S.I4, XW - 4, XE + 4, 42.2, Y1 + 4, zc + 0.2, zc + 1.8)
		cuts = [XE + 4] + [x for xb in BEAMS[:-1] for x in (xb - 2.0, xb - 26.0)] + [XW - 4]
		for i in range(0, len(cuts), 2):  # solid strips between the skylights
			KC["Ceil"].box(cuts[i + 1], cuts[i], 26.0, 42.0, zc, zc + 2)
			S.collider(AREA, S.I4, cuts[i + 1], cuts[i], 25.8, 42.2, zc + 0.2, zc + 1.8)
	for xb in BEAMS[:-1]:
		xa, xc = xb - 26.0, xb - 2.0
		with S.grp("Skylight", Matrix.Translation(((xa + xc) / 2, 34, zc))):
			S.ring_prism(KC["Petrol"], S.rect_loop(xa, xc, 26.0, 42.0), S.rect_loop(xa + 0.55, xc - 0.55, 26.55, 41.45), zc + 0.25, zc + 1.0)
			for yy in (31.33, 36.67):
				KC["Petrol"].box(xa + 0.55, xc - 0.55, yy - 0.22, yy + 0.22, zc + 0.5, zc + 1.0)
			for k in (1, 2, 3):
				xx = xa + (xc - xa) * k / 4
				KC["PetrolDark"].box(xx - 0.18, xx + 0.18, 26.55, 41.45, zc + 0.56, zc + 0.94)
			KC["Glass"].box(xa + 0.1, xc - 0.1, 26.1, 41.9, zc + 1.0, zc + 1.15)
			S.collider(AREA, S.I4, xa, xc, 26.0, 42.0, zc + 1.0, zc + 1.2, kind="Y")
	for xb in BEAMS[1:]:
		with S.grp("DuelsBeam", Matrix.Translation((xb, 34, zc)), inst=True):
			KC["Petrol"].box(xb - 0.9, xb + 0.9, Y0 + 2.6, Y1 - 2.6, zc - 1.7, zc - 1.3)
			KC["Petrol"].box(xb - 0.28, xb + 0.28, Y0 + 2.6, Y1 - 2.6, zc - 1.3, zc - 0.4)
			KC["Petrol"].box(xb - 0.9, xb + 0.9, Y0 + 2.6, Y1 - 2.6, zc - 0.4, zc)
			for yy in (26.0, 34.0, 42.0):
				KC["PetrolDark"].box(xb - 0.75, xb + 0.75, yy - 0.13, yy + 0.13, zc - 1.3, zc - 0.4)


def build():
	K, KC, edges = S.poly_room(AREA, PTS, ZL, H, floor_mat="DuelFloor", ceiling=False)
	KR = C.Kit(K.col, prefix="DuelsWalk")
	fs, fe, fn, fw = (e[0] for e in edges)
	for i, F in enumerate((fs, fe, fn, fw)):
		ops = [(-10.0, 10.0, 17.0)] if i == 1 else []  # the doorway: 13 above the deck, which fills the opening below it
		S.wall_seg(F, AREA, edges[i][1], H, ops, ext=edges[i][2], joint=14.0, courses=[1.5, 5.5, 11.25, 17.0], belt=False, batter=0.0, top_trim=0.03 * (i % 2), name=f"DuelsWall{i + 1}")
	deck(K, KR)
	roof(KC)
	mid = (XE + XW) / 2
	loc = lambda wall, x: (x - mid) if wall == "N" else -(x - mid)
	for wall, x, mode, letter, live in STATIONS:
		station(fn if wall == "N" else fs, loc(wall, x), mode, letter, live)
		S.opal_panel(KC, x, 49.0 if wall == "N" else 19.0, ZL + H, 6.0, 2.2, color="#F1F4FF", brightness=0.95, rng=32)
	for x in BEAMS:
		pier(fn, loc("N", x))
		if x < -60:
			pier(fs, loc("S", x))
	pipes(fn, loc("N", -60.9), loc("N", -201.0), [loc("N", x + d) for _w, x, *_r in STATIONS if _w == "N" for d in (-7.0, 7.0)])
	pipes(fs, loc("S", -85.9), loc("S", -201.0), [loc("S", x + d) for _w, x, *_r in STATIONS if _w == "S" for d in (-7.0, 7.0)])
	gauntlet_gate(fw)
	with S.grp("DuelsDoorCasing", fe.M):
		S.u_frame(fe.at(T((0, 4.0, 0)))["Petrol"], 10.7, 13.7, 8.0, 11.0, 0.0, 0.5, co=3.2, ci=2.4)  # deck-side casing of the doorway
	for s in (-1, 1):
		DR.sconce(fe.at(T((0, 4.0, 0))), s * 13.0, 7.6)
	# win-streak board over the ramp (a SurfaceGui screen in Studio)
	W = fs.at(T((loc("S", -69.4), 0, 0)))
	DR.display(W, 0.0, 12.0, 16.0, 6.4, "streak", "WIN STREAKS", "")
	# floor: a clear centre walk between two ochre lines that run to the gate
	for sy in (-1, 1):
		with S.grp("DuelsFloorLines", reuse=True):
			K["Stripe"].box(XW + 10.0, XD - 24.0, 34 + sy * 6.0 - 0.3, 34 + sy * 6.0 + 0.3, ZL - 0.2, ZL + 0.05)
	S.opal_panel(KC, -50.4, 20.0, ZL + H, 4.0, 4.0, brightness=0.7, rng=28)
	S.opal_panel(KC, -50.4, 48.0, ZL + H, 4.0, 4.0, brightness=0.7, rng=28)
	K.done()
	KC.done()
	KR.done()
