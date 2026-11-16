"""Lobby V4, sections 3-5: the Locker (west), the Shop with the Season Pass (east) and the Range yard (south, seen
through the hub window). Each wing is its own area (Studio folder). Plan: vault/02 Art/Lobby V4 Plan.md 3.3-3.5.
"""
from math import cos, sin, radians, pi

from mathutils import Matrix, Vector

import lv3_core as C
import sw_core as S
import v4_core as V

I4 = Matrix.Identity(4)


def stage(K, KD, cx, cy, r1, r2, ring, area_light=True):
	"""A two-step octagonal stage with light nosings and an accent ring on top."""
	M = Matrix.Translation((cx, cy, 0))
	F, G = S.FK(K, M), S.FK(KD, M)
	F["V_Floor2"].prism(V.ccw(V.oct_pts(r1)), 0.0, 0.9)
	F["V_Lane"].prism(V.ccw(V.oct_pts(r2)), 0.9, 1.8)
	for r, z in ((r1, 0.9), (r2, 1.8)):
		o, i = V.oct_pts(r + 0.05), V.oct_pts(r - 0.55)
		for k in range(8):
			j = (k + 1) % 8
			G["V_Trim"].prism(V.ccw([i[k], i[j], o[j], o[k]]), z - 0.12, z + 0.06)
	o, i = V.oct_pts(r2 - 1.1), V.oct_pts(r2 - 1.45)
	for k in range(8):
		j = (k + 1) % 8
		G[ring].prism(V.ccw([i[k], i[j], o[j], o[k]]), 1.8, 1.86)


def console(K, KD, cx, cy, yaw, accent, area, tag, name):
	"""A terminal on a faceted pedestal, its angled screen facing yaw; the gameplay hook sits on it."""
	M = Matrix.Translation((cx, cy, 0)) @ Matrix.Rotation(radians(yaw), 4, "Z")
	with C.grp(name, M):
		F, G = S.FK(K, M), S.FK(KD, M)
		F["V_Base"].prism(V.ccw(V.oct_pts(1.9)), 0, 0.6)
		F["V_Wall"].solid([(x, y, 0.6) for x, y in V.ccw(V.oct_pts(1.5))], [(x, y, 3.2) for x, y in V.ccw(V.oct_pts(1.7))])
		Ms = M @ Matrix.Translation((0, -0.4, 3.2)) @ Matrix.Rotation(radians(-35), 4, "X")
		P = S.FK(KD, Ms)
		P["V_Dark"].prism(V.ccw(S.cut_rect(-2.0, 2.0, -1.3, 1.3, 0.45, 0.12)), 0, 0.35)
		S.ring_prism(P["V_Trim"], V.ccw(S.cut_rect(-2.0, 2.0, -1.3, 1.3, 0.45, 0.12)), V.ccw(S.cut_rect(-1.7, 1.7, -1.0, 1.0, 0.3, 0.08)), 0.35, 0.5)
		P[accent].box(-1.5, 1.5, -0.85, 0.85, 0.3, 0.42)
		G[accent].box(-1.0, 1.0, -1.72, -1.6, 0.8, 1.2)
		c = M @ Vector((0, -1.5, 3.0))
		S.ANCHORS.append([name, tag, round(c.x, 3), round(c.y, 3), round(c.z, 3), 4.0, 6.0, 4.0, {}])


class Locker:
	AREA = "Locker"
	X0, X1, Y0, Y1, H = -114.0, -62.0, -24.0, 24.0, 28.0

	@classmethod
	def build(cls):
		K = S.kit(cls.AREA, nocol=False)
		KD = C.Kit(K.col, prefix=cls.AREA + "D")
		KD.nocol = True
		A = cls.AREA
		cases_n = [(12.0, "SIDEARMS", [("Classic", 1.9, 4.4), ("Sheriff", 1.9, 8.6)]), (26.0, "RIFLES", [("Vandal", 1.9, 4.4), ("Phantom", 1.9, 8.6)]),
			(40.0, "SNIPERS", [("Operator", 1.9, 4.4), ("Marshal", 1.9, 8.6)])]
		cases_s = [(12.0, "SMGS", [("Spectre", 1.9, 4.4), ("Stinger", 1.9, 8.6)]), (26.0, "SHOTGUNS", [("Judge", 1.9, 4.4), ("Bucky", 1.9, 8.6)]),
			(40.0, "HEAVY", [("Odin", 1.9, 4.4), ("Ares", 1.9, 8.6)])]
		W = V.wframe
		Mn, Ms = W((cls.X0, cls.Y1), (1, 0)), W((cls.X1, cls.Y0), (-1, 0))
		skips = {"N": [], "S": [], "W": [(8.0, 40.5)], "E": [(24 - 10.0, 24 + 10.0)]}
		for M, side, cases in ((Mn, "N", cases_n), (Ms, "S", cases_s)):
			for u, label, guns in cases:
				skips[side].append(V.niche(K, KD, M, u, 9.0, label, guns, "E_Violet", A))
		walls = V.room(K, KD, A, cls.X0, cls.X1, cls.Y0, cls.Y1, cls.H, ops={"E": [(15.0, 33.0, 0.0, 18.0)]}, skips=skips, beams_x=(-96.0, -80.0))
		for side in "NS":
			Mv, _ = walls[side]
			with C.grp("Vents_" + side, Mv):
				for u in (19.0, 33.0):
					V.vent(KD, Mv, u, 2.6, 2.8, 2.0)
		Mw0, _ = walls["W"]
		with C.grp("Plaques_Loadout", Mw0):
			V.plaque(KD, Mw0, 37.6, 10.6, 3.4, 2.4, "notice", "NOTICE", ["PICK YOUR", "LOADOUT HERE"])
		Me, _ = walls["E"]
		V.mouth(KD, Me @ V.T(24, 0, 0), 9.0, 18.0)
		KD["V_Floor2"].box(cls.X1, cls.X1 + 4.0, -5.0, 5.0, 0.0, 0.12)
		# loadout station on the end wall: stage, board, sign, console
		Mw, _ = walls["W"]
		stage(K, KD, cls.X0 + 8.6, 0.0, 6.6, 4.6, "E_Violet")
		V.floor_text(KD, Matrix.Translation((cls.X0 + 8.6, 0.0, 1.8)) @ Matrix.Rotation(radians(90), 4, "Z"), "STAND HERE", 0.9, mat="V_Paint", z=0.06)
		V.board(KD, Mw @ V.T(24, 6.2, 0), 22.0, 9.4, "locker", "SELECTED", name="Board_Loadout", accent="E_Violet")
		V.sign(KD, Mw @ V.T(24, 18.6, 0), "LOCKER", 22.0, 5.2, accent="E_Violet", name="Sign_Loadout")
		console(K, KD, cls.X0 + 17.5, 0.0, 90, "E_Violet", A, "LobbyLocker", "LockerConsole")
		V.prop_group(K, V.wframe((cls.X1, cls.Y1), (0, -1)) @ V.RX(-90), [("case", 9.0, -2.0, 0.0, 0), ("case", 9.2, -2.0, 0.92, -4), ("crate_s", 9.0, -6.2, 0.0, 8)])
		# centre: the hero gun turning over a lit plinth
		with C.grp("HeroPlinth", Matrix.Translation((-88.0, 0.0, 0.0))):
			F, G = S.FK(K, Matrix.Translation((-88.0, 0.0, 0.0))), S.FK(KD, Matrix.Translation((-88.0, 0.0, 0.0)))
			F["V_Base"].prism(V.ccw(V.oct_pts(3.4)), 0, 0.8)
			F["V_Wall"].prism(V.ccw(V.oct_pts(2.7)), 0.8, 3.2)
			o, i = V.oct_pts(2.85), V.oct_pts(2.55)
			for k in range(8):
				j = (k + 1) % 8
				G["E_Violet"].prism(V.ccw([i[k], i[j], o[j], o[k]]), 2.6, 2.8)
			G["V_Trim"].prism(V.ccw(V.oct_pts(2.9)), 3.2, 3.5)
			G["V_Steel"].prism(V.ccw(V.oct_pts(2.3)), 3.5, 3.7)  # turntable the gun stands on
			S.gun_row(["Vandal", 1.35, -88.0, 0.0, 4.4, 0.0, 1.0, 1, 16])
			S.light(I4, -88.0, 0.0, cls.H - 0.6, V.WHITE, 2.4, 30, 40)
		return K.done() + KD.done()


class Shop:
	AREA = "Shop"
	X0, X1, Y0, Y1, H = 62.0, 116.0, -26.0, 26.0, 28.0

	@classmethod
	def build(cls):
		K = S.kit(cls.AREA, nocol=False)
		KD = C.Kit(K.col, prefix=cls.AREA + "D")
		KD.nocol = True
		A = cls.AREA
		W = V.wframe
		Ms = W((cls.X1, cls.Y0), (-1, 0))
		skips = {"S": [], "N": [(27 - 15.0, 27 + 15.0)], "E": [(6.0, 46.0)], "W": [(26 - 13.0, 26 + 13.0)]}
		for u, label, guns in ((13.0, "SKINS", [("Vandal", 1.9, 4.4), ("Phantom", 1.9, 8.6)]), (27.0, "BUNDLES", [("Spectre", 1.9, 4.4), ("Sheriff", 1.9, 8.6)]),
				(41.0, "NEW", [("Guardian", 1.9, 4.4), ("Ghost", 1.9, 8.6)])):
			skips["S"].append(V.niche(K, KD, Ms, u, 9.0, label, guns, "E_Coral", A))
		walls = V.room(K, KD, A, cls.X0, cls.X1, cls.Y0, cls.Y1, cls.H, ops={"W": [(14.0, 38.0, 0.0, 18.0)]}, skips=skips, beams_x=(80.0, 98.0))
		Mv, _ = walls["S"]
		with C.grp("Vents_S", Mv):
			for u in (20.0, 34.0):
				V.vent(KD, Mv, u, 2.6, 2.8, 2.0)
		Me0, _ = walls["E"]
		with C.grp("Plaques_Counter", Me0):
			V.plaque(KD, Me0, 9.0, 10.6, 3.4, 2.4, "notice", "NOTICE", ["NEW SKINS", "EVERY WEEK"])
		Mw, _ = walls["W"]
		V.mouth(KD, Mw @ V.T(26, 0, 0), 12.0, 18.0)
		KD["V_Floor2"].box(cls.X0 - 4.0, cls.X0, -8.0, 8.0, 0.0, 0.12)
		# the counter on the end wall, the featured board and the SUPPLY sign
		Me, _ = walls["E"]
		with C.grp("Counter", Matrix.Translation((cls.X1 - 9.0, 0.0, 0.0))):
			M = Matrix.Translation((cls.X1 - 9.0, 0.0, 0.0))
			F, G = S.FK(K, M), S.FK(KD, M)
			G["V_Base"].box(-1.4, 1.6, -10.0, 10.0, 0.0, 0.6)
			F["V_Wall"].ext_y(V.ccw([(-1.8, 0.6), (-2.1, 3.4), (1.9, 3.4), (1.9, 0.6)]), -10.4, 10.4)
			G["V_Trim"].ext_y(V.ccw([(-2.5, 3.4), (-2.5, 3.75), (2.1, 3.75), (2.1, 3.4)]), -10.8, 10.8)
			G["E_Coral"].ext_y(V.ccw([(-2.3, 3.0), (-2.3, 3.25), (-2.06, 3.25), (-2.03, 3.0)]), -9.6, 9.6)
			for y in (-6.6, 0.0, 6.6):
				G["V_Dark"].ext_y(V.ccw([(-2.0, 1.2), (-2.2, 2.8), (-2.08, 2.8), (-1.88, 1.2)]), y - 2.6, y + 2.6)
			S.ANCHORS.append(["ShopCounter", "LobbyShop", round(cls.X1 - 12.0, 3), 0.0, 3.0, 4.0, 18.0, 6.0, {}])
		V.board(KD, Me @ V.T(26, 6.0, 0), 24.0, 9.4, "shop", "FEATURED", name="Board_Featured", accent="E_Coral")
		V.sign(KD, Me @ V.T(26, 18.4, 0), "SHOP", 18.0, 5.4, accent="E_Coral", name="Sign_ShopCounter")
		# the Season Pass wall on the north side, with its podium and terminal
		Mn, _ = walls["N"]
		V.board(KD, Mn @ V.T(27, 4.6, 0), 26.0, 10.8, "battlepass", "SEASON PASS", name="Board_SeasonPass", accent="E_Coral")
		V.sign(KD, Mn @ V.T(27, 18.5, 0), "SEASON PASS", 20.0, 4.6, accent="E_Coral", name="Sign_SeasonPass", chevrons=False, lh=2.4)
		stage(K, KD, 89.0, cls.Y1 - 9.6, 5.2, 3.6, "E_Coral")
		V.floor_text(KD, Matrix.Translation((89.0, cls.Y1 - 9.6, 1.8)) @ Matrix.Rotation(radians(0), 4, "Z"), "STAND HERE", 0.8, mat="V_Paint", z=0.06)
		console(K, KD, 89.0, cls.Y1 - 17.5, 0, "E_Coral", A, "LobbyBattlePass", "PassConsole")
		with C.grp("FeaturePlinth", Matrix.Translation((84.0, -5.0, 0.0))):
			Mp = Matrix.Translation((84.0, -5.0, 0.0))
			F, G = S.FK(K, Mp), S.FK(KD, Mp)
			F["V_Base"].prism(V.ccw(V.oct_pts(3.6)), 0, 0.8)
			F["V_Wall"].prism(V.ccw(V.oct_pts(2.9)), 0.8, 3.0)
			o, i = V.oct_pts(3.05), V.oct_pts(2.75)
			for k in range(8):
				j = (k + 1) % 8
				G["E_Coral"].prism(V.ccw([i[k], i[j], o[j], o[k]]), 2.4, 2.6)
			G["V_Trim"].prism(V.ccw(V.oct_pts(3.1)), 3.0, 3.3)
			G["V_Steel"].prism(V.ccw(V.oct_pts(2.3)), 3.3, 3.5)  # turntable the gun stands on
			S.gun_row(["Phantom", 2.0, 84.0, -5.0, 4.5, 1.0, 0.0, 1, 14])
			S.light(I4, 84.0, -5.0, cls.H - 0.6, V.WHITE, 2.2, 30, 40)
		# hard cases stacked by the Season Pass wall
		V.prop_group(K, V.wframe((cls.X0, cls.Y1), (1, 0)) @ V.RX(-90), [("case", 44.0, -2.2, 0.0, 2), ("case", 44.2, -2.2, 0.92, -3), ("case", 44.0, -2.2, 1.84, 5)])
		# a crate group beside the door
		Mf = Matrix.Translation((cls.X0 + 3.6, cls.Y0 + 6.0, 0.0))
		V.crate(K, Mf @ Matrix.Rotation(radians(90), 4, "Z"))
		V.crate(K, Mf @ Matrix.Translation((0, 5.4, 0)) @ Matrix.Rotation(radians(86), 4, "Z"))
		V.crate(K, Mf @ Matrix.Translation((0.2, 2.7, 3.32)) @ Matrix.Rotation(radians(97), 4, "Z"))
		return K.done() + KD.done()


class Range:
	"""The yard behind the hub's Range window: lanes, a shooting line, octagon targets, the yard walls, a faceted mesa
	with a mast as the landmark. Seen through glass; players go in through the gate (the existing teleport)."""
	AREA = "Range"
	Z = -2.0
	X, Y0, Y1 = 60.0, -50.0, -172.0

	@classmethod
	def build(cls):
		K = S.kit(cls.AREA, nocol=False)
		KD = C.Kit(K.col, prefix=cls.AREA + "D")
		KD.nocol = True
		Z, X, Y0, Y1 = cls.Z, cls.X, cls.Y0, cls.Y1
		KD["V_Slab"].box(-X - 4, X + 4, Y1 - 4, Y0, Z - 1.2, Z - 0.02)
		for i in range(6):
			for j in range(6):
				ax, bx = -X + 20 * i, -X + 20 * (i + 1)
				ay, by = Y1 + (Y0 - Y1) * j / 6, Y1 + (Y0 - Y1) * (j + 1) / 6
				KD["V_Floor" if (i + j) % 2 == 0 else "V_Floor2"].box(ax + 0.15, bx - 0.15, ay + 0.15, by - 0.15, Z, Z + 0.12)
		# yard walls: graphite with a light cap and lime lamp posts
		for M, L in ((V.wframe((-X, Y1), (0, 1), Z), Y0 - Y1), (V.wframe((X, Y0), (0, -1), Z), Y0 - Y1), (V.wframe((X, Y1), (-1, 0), Z), 2 * X)):
			F, G = S.FK(KD, M), S.FK(KD, M)
			F["V_Wall"].box(-4.0, L + 4.0, 0, 16.0, -3.0, 0)
			G["V_Low"].ext_x(V.ccw([(0, 0), (0, 0.6), (6.0, 0.3), (6.0, 0)]), 0, L)
			G["V_Trim"].ext_x(V.ccw([(15.4, -3.2), (15.4, 0.6), (16.4, 0.6), (16.4, -3.2)]), -4.0, L + 4.0)
			for u in [k * 20.0 + 10.0 for k in range(int(L // 20))]:
				G["V_Steel"].box(u - 0.5, u + 0.5, 6.0, 14.0, 0.0, 0.7)
				G["E_Lime"].box(u - 0.3, u + 0.3, 12.2, 13.6, 0.7, 0.85)
		# shooting line and lane dividers
		yl = -64.0
		KD["V_Wall"].box(-36.0, 36.0, yl - 1.2, yl + 1.2, Z, Z + 3.2)
		KD["V_Trim"].box(-36.4, 36.4, yl - 1.5, yl + 1.5, Z + 3.2, Z + 3.5)
		KD["E_Lime"].box(-35.0, 35.0, yl - 1.32, yl - 1.18, Z + 2.6, Z + 2.9)
		for x in (-36.0, -21.6, -7.2, 7.2, 21.6, 36.0):
			KD["V_Low"].box(x - 0.6, x + 0.6, -150.0, yl - 1.5, Z, Z + 1.8)
			KD["V_Trim"].box(x - 0.75, x + 0.75, -150.0, yl - 1.5, Z + 1.8, Z + 2.05)
		for y in (-90.0, -115.0, -140.0):  # distance bars
			KD["E_Lime"].box(-35.0, 35.0, y - 0.25, y + 0.25, Z + 0.12, Z + 0.16)
		# octagon targets on steel stands, three distances per lane
		for k, x in enumerate((-28.8, -14.4, 0.0, 14.4, 28.8)):
			for y in ((-96.0, -121.0, -146.0)[k % 3], (-121.0, -146.0, -96.0)[k % 3]):
				M = Matrix.Translation((x, y, Z))
				with C.grp("Target", M, inst=True):
					G = S.FK(KD, M)
					for sx in (-1, 1):
						G["V_Steel"].box(sx * 1.6 - 0.2, sx * 1.6 + 0.2, -0.28, 0.28, 0, 5.2)
						G["V_Base"].box(sx * 1.6 - 0.6, sx * 1.6 + 0.6, -0.8, 0.8, 0, 0.3)
					Mt = M @ Matrix.Translation((0, 0, 7.2)) @ Matrix.Rotation(radians(90), 4, "X")
					P = S.FK(KD, Mt)
					P["V_Paint"].prism(V.ccw(V.oct_pts(2.4)), -0.15, 0.15)
					for r0, r1, m in ((1.7, 2.0, "V_Dark"), (0.9, 1.2, "V_Dark"), (0.0, 0.45, "E_Lime")):
						if r0 == 0.0:
							P[m].prism(V.ccw(V.oct_pts(r1)), -0.2, 0.2)
							continue
						o, i = V.oct_pts(r1), V.oct_pts(r0)
						for q in range(8):
							j = (q + 1) % 8
							P[m].prism(V.ccw([i[q], i[j], o[j], o[q]]), -0.2, 0.2)
					G["V_Steel"].box(-1.9, 1.9, -0.24, 0.24, 4.8, 5.3)
		# the mesa: stepped faceted tiers beyond the end wall, a lattice mast with a lime beacon on top
		tiers = [(70.0, 34.0, Z - 1.0, 18.0), (54.0, 26.0, 18.0, 32.0), (34.0, 18.0, 32.0, 42.0)]
		cy = Y1 - 48.0
		for k, (rx, ry, z0, z1) in enumerate(tiers):
			pts = [(rx * cos(radians(a)) * (1.0 + 0.06 * ((q * 7) % 3)), cy + ry * sin(radians(a)) * (1.0 + 0.05 * ((q * 5) % 3))) for q, a in enumerate(range(5, 365, 36))]
			top = [((x - 0.0) * 0.9, cy + (y - cy) * 0.88) for x, y in pts]
			KD["V_Rock" if k % 2 == 0 else "V_Rock2"].solid([(x, y, z0) for x, y in V.ccw(pts)], [(x, y, z1) for x, y in V.ccw(top)])
		mx, my, mz = 6.0, cy + 2.0, 42.0
		for sx in (-1, 1):
			for sy in (-1, 1):
				KD["V_Steel"].pipe((mx + sx * 3.0, my + sy * 3.0, mz), (mx + sx * 0.8, my + sy * 0.8, mz + 26.0), 0.35, n=8)
		for h in (6.0, 13.0, 20.0):
			s = 3.0 - 2.2 * h / 26.0
			for (a, b) in (((-s, -s), (s, -s)), ((s, -s), (s, s)), ((s, s), (-s, s)), ((-s, s), (-s, -s))):
				KD["V_Steel"].pipe((mx + a[0], my + a[1], mz + h), (mx + b[0], my + b[1], mz + h), 0.22, n=6)
		KD["V_Dark"].prism(V.ccw(V.oct_pts(1.3)), mz + 25.6, mz + 27.0)
		KD["E_Lime"].prism(V.ccw(V.oct_pts(0.9)), mz + 27.0, mz + 28.4)
		return K.done() + KD.done()
