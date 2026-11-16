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
		G[V.PAINT.get(ring, ring)].prism(V.ccw([i[k], i[j], o[j], o[k]]), 1.8, 1.86)


def console(K, KD, cx, cy, yaw, accent, area, tag, name, title="TERMINAL"):
	"""A terminal kiosk (owner 2026-11-16: the slanted neon slab read like a tablet and overlapped): a faceted column
	with a kick, a vertical SurfaceGui screen in a bezel, a visor over it, a dark key shelf below, one painted accent
	band. Faces -Y of its frame (yaw turns it). The gameplay hook sits in front of the screen."""
	M = Matrix.Translation((cx, cy, 0)) @ Matrix.Rotation(radians(yaw), 4, "Z")
	with C.grp(name, M):
		F, G = S.FK(K, M), S.FK(KD, M)
		F["V_Base"].prism(V.ccw(S.cham_rect(-1.9, 1.9, -1.3, 1.3, 0.4)), 0, 0.5)
		F["V_Wall"].prism(V.ccw(S.cham_rect(-1.6, 1.6, -1.0, 1.0, 0.3)), 0.5, 6.0)
		G["V_Trim"].prism(V.ccw(S.cham_rect(-1.75, 1.75, -1.15, 1.15, 0.32)), 6.0, 6.3)
		G[V.PAINT.get(accent, accent)].prism(V.ccw(S.cham_rect(-1.63, 1.63, -1.03, 1.03, 0.3)), 1.1, 1.4)  # accent band
		G["V_Dark"].box(-1.35, 1.35, -1.12, -1.0, 2.9, 5.5)  # screen bezel
		Ms = S.face((0, -1.14, 0), (1, 0, 0), (0, -1, 0))
		S.screen("notice", title, "PRESS E", M @ Ms, 0, 4.2, 0.0, 2.4, 2.4)
		G["V_Steel"].ext_x(V.ccw([(5.5, -1.0), (5.5, -1.7), (5.75, -1.85), (6.0, -1.0)]), -1.45, 1.45)  # visor
		G["V_Dark"].ext_x(V.ccw([(2.3, -1.0), (2.6, -1.9), (2.85, -1.9), (2.75, -1.0)]), -1.3, 1.3)  # key shelf
		c = M @ Vector((0, -2.6, 3.0))
		S.ANCHORS.append([name, tag, round(c.x, 3), round(c.y, 3), round(c.z, 3), 4.0, 4.0, 5.0, {}])


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
			V.plaque(KD, Mw0, 37.6, 10.6, 3.4, 2.4, "notice", "NOTICE", ["PICK YOUR LOADOUT"])
		Me, _ = walls["E"]
		V.mouth(KD, Me @ V.T(24, 0, 0), 9.0, 18.0)
		KD["V_Floor2"].box(cls.X1, cls.X1 + 4.0, -5.0, 5.0, 0.0, 0.12)
		# loadout station on the end wall: stage, board, sign, console
		Mw, _ = walls["W"]
		V.step_pad(K, KD, A, cls.X0 + 10.0, 0.0, 5.0, "E_Violet", "LobbyLocker", "LockerPad")  # step on it: the Locker opens
		V.board(KD, Mw @ V.T(24, 6.2, 0), 22.0, 9.4, "featured", "SELECTED", name="Board_Loadout", accent="E_Violet")
		V.sign(KD, Mw @ V.T(24, 18.6, 0), "LOCKER", 22.0, 5.2, accent="E_Violet", name="Sign_Loadout", icon="reticle")
		# the armorer: an NPC behind a gun bench in the south-west corner, facing the room
		V.gun_table(K, KD, A, Matrix.Translation((cls.X0 + 7.6, -13.0, 0.0)) @ Matrix.Rotation(radians(90), 4, "Z"), [("Knife", 1.6), ("Sheriff", 1.6)], w=7.0, d=3.2, name="ArmorerBench")
		V.npc("Armorer", cls.X0 + 12.5, -8.0, 0.0, -60, "armorer", "ARMORER")  # in the open beside the pad, facing the door
		V.prop_group(K, V.wframe((cls.X1, cls.Y1), (0, -1)) @ V.RX(-90), [("case", 9.0, -2.0, 0.0, 0), ("case", 9.2, -2.0, 1.62, -4), ("crate_s", 9.0, -6.2, 0.0, 8)])
		for ty, guns in ((-12.0, [("Sheriff", 1.6), ("Bulldog", 1.6), ("Ghost", 1.6)]), (12.0, [("Judge", 1.6), ("Spectre", 1.6), ("Classic", 1.6)])):
			V.gun_table(K, KD, A, Matrix.Translation((-75.0, ty, 0.0)), guns, name="GunTable")
		Me1, _ = walls["E"]
		V.poster(KD, Me1, 7.5, 6.0, 6.0, 8.0, "KNOW YOUR LOADOUT", "PICK|SKIN|WIN", name="Poster_Loadout")
		V.poster(KD, Me1, 40.5, 6.0, 6.0, 8.0, "EVERY GUN", "HAS A STORY", name="Poster_Story")
		# centre: the hero gun turning over a lit plinth
		with C.grp("HeroPlinth", Matrix.Translation((-88.0, 0.0, 0.0))):
			F, G = S.FK(K, Matrix.Translation((-88.0, 0.0, 0.0))), S.FK(KD, Matrix.Translation((-88.0, 0.0, 0.0)))
			F["V_Base"].prism(V.ccw(V.oct_pts(3.4)), 0, 0.8)
			F["V_Wall"].prism(V.ccw(V.oct_pts(2.7)), 0.8, 3.2)
			o, i = V.oct_pts(2.85), V.oct_pts(2.55)
			for k in range(8):
				j = (k + 1) % 8
				G["V_Violet"].prism(V.ccw([i[k], i[j], o[j], o[k]]), 2.6, 2.8)
			G["V_Trim"].prism(V.ccw(V.oct_pts(2.9)), 3.2, 3.5)
			G["V_Steel"].prism(V.ccw(V.oct_pts(2.3)), 3.5, 3.7)  # turntable the gun stands on
			S.gun_row(["Vandal", 1.35, -88.0, 0.0, 4.4, 0.0, 1.0, 1, 16])
			S.light(I4, -88.0, 0.0, cls.H - 0.6, V.WHITE, 2.4, 30, 40)
		V.fx("sparkle", -88.0, 0.0, 5.0, "#8E6CFF", name="HeroFX", Rate=5, Spread=2.0)
		V.fx("cone", -88.0, 0.0, cls.H - 1.5, "#FFF4E0", to=(-88.0, 0.0, 3.6), name="HeroCone", W0=1.0, W1=6.5)
		return K.done() + KD.done()


class Shop:
	"""The Shop as a Market hallway (owner 2026-11-16, after RIVALS' Market: a hall, not a room). From the hub door a
	long hall runs east; two big show stages face each other across it (FEATURED south, SEASON PASS north), each with a
	walk-in floor mark that opens its menu; a big NPC, the BROKER, stands at the far end on a stepped plinth under the
	SHOP sign and a TV. Piers with bar lamps, TVs and posters by the entrance, a lit path down the middle."""
	AREA = "Shop"
	X0, X1, Y0, Y1, H = 62.0, 150.0, -20.0, 20.0, 30.0  # owner 2026-11-16: wider (was 26)
	BX, BHW, BH, BD = 104.0, 15.0, 20.0, 18.0  # stage centre x, half width, height, depth

	@classmethod
	def build(cls):
		K = S.kit(cls.AREA, nocol=False)
		KD = C.Kit(K.col, prefix=cls.AREA + "D")
		KD.nocol = True
		A = cls.AREA
		X0, X1, Y0, Y1, H = cls.X0, cls.X1, cls.Y0, cls.Y1, cls.H
		BX, BHW, BH, BD = cls.BX, cls.BHW, cls.BH, cls.BD
		nb = (BX - X0 - BHW, BX - X0 + BHW, 0.0, BH)  # north wall: local x = world x - X0
		sb = (X1 - BX - BHW, X1 - BX + BHW, 0.0, BH)  # south wall: local x = X1 - world x
		gap = 2.4
		ops = {"W": [(Y1 - 12.0, Y1 + 12.0, 0.0, 18.0)], "N": [nb], "S": [sb]}
		skips = {"N": [(nb[0] - gap, nb[1] + gap), (3.0, 20.0)], "S": [(sb[0] - gap, sb[1] + gap), (X1 - X0 - 20.0, X1 - X0 - 3.0)],
			"E": [(Y1 - 11.0, Y1 + 11.0)], "W": []}
		walls = V.room(K, KD, A, X0, X1, Y0, Y1, H, ops=ops, skips=skips, beams_x=(84.0, 124.0))
		Mw, _ = walls["W"]
		V.mouth(KD, Mw @ V.T(Y1, 0, 0), 12.0, 18.0)
		with C.grp("Threshold"):
			KD["V_Floor2"].box(X0 - 4.0, X0, -8.0, 8.0, 0.0, 0.12)
		Mn, _ = walls["N"]
		Ms, _ = walls["S"]
		# a painted violet band down both long walls (RIVALS' Market runs one colour band the length of the hall)
		for Mw_, segs in ((Mn, ((2.5, 20.0), (64.0, 85.5))), (Ms, ((2.5, 24.0), (68.0, 85.5)))):
			with C.grp("WallBand", Mw_):
				G = S.FK(KD, Mw_)
				for a_, b_ in segs:
					G["V_ThViolet"].box(a_, b_, 5.9, 7.9, 0.5, 0.6)
		# piers between the entrance section, the stages and the end
		for x in (84.0, 124.0):
			V.pier_at(K, KD, V.wframe((x, Y1), (1, 0)), H, A, w=3.0)
			V.pier_at(K, KD, V.wframe((x, Y0), (-1, 0)), H, A, w=3.0)
		# entrance section: pop-out TVs either side, a vent below each
		V.tv(K, KD, Mn @ V.T(11.5, 9.0, 0), 13.0, 7.5, "featured", "NEW THIS WEEK", "SKINS · BUNDLES", out=2.6, name="TV_ShopN")
		V.tv(K, KD, Ms @ V.T(X1 - X0 - 11.5, 9.0, 0), 13.0, 7.5, "news", "SEASON 1", "PASS OUT NOW", out=2.6, name="TV_ShopS")
		with C.grp("Vents", Mn):
			V.vent(KD, Mn, 11.5, 2.6, 3.2, 2.2)
		with C.grp("Vents", Ms):
			V.vent(KD, Ms, X1 - X0 - 11.5, 2.6, 3.2, 2.2)
		# FEATURED stage (south)
		heroF = V.holobay(K, KD, A, Ms @ V.T(X1 - BX, 0, 0), BHW, BH, BD, "FEATURED", "E_Coral", "sparkle", name="Bay_Featured",
			curtains="V_Pink", figures=((-5.2, 0.76, 1.15), (5.2, 0.76, 1.15)))
		Mh = Matrix.Translation(tuple(heroF))
		with C.grp("FeaturedPedestal", Mh):
			G = S.FK(KD, Mh)
			G["V_Base"].prism(V.ccw(V.oct_pts(3.0)), 0.0, 0.8)
			G["V_Wall"].prism(V.ccw(V.oct_pts(2.5)), 0.8, 3.0)
			G["V_Pink"].prism(V.ccw(V.oct_pts(2.65)), 2.4, 2.6)
			G["V_Trim"].prism(V.ccw(V.oct_pts(2.7)), 3.0, 3.25)
			G["V_Steel"].prism(V.ccw(V.oct_pts(2.2)), 3.25, 3.4)
			S.gun_row(["Phantom", 2.2, round(heroF.x, 3), round(heroF.y, 3), round(heroF.z + 3.4, 3), 1.0, 0.0, 0, 16])
		for k, dx in enumerate((-7.5, 7.5)):
			V.hard_case(KD, Matrix.Translation((heroF.x + dx, heroF.y + (0.6 if k else -0.4), heroF.z)) @ Matrix.Rotation(radians(8 - 16 * k), 4, "Z"), name="StageCase")
		V.fx("sparkle", heroF.x, heroF.y, heroF.z + 5.5, "#FF5C8A", name="FeaturedFX", Rate=8, Spread=3.4)
		V.step_mark(KD, A, BX, Y0 + 5.4, 24.0, 8.0, "E_Coral", "LobbyShop", "Mark_Featured", facing=-1.0)
		# SEASON PASS stage (north)
		heroS = V.holobay(K, KD, A, Mn @ V.T(BX - X0, 0, 0), BHW, BH, BD, "SEASON PASS", "E_ThViolet", "star", name="Bay_Season",
			backdrop="V_ThLilac", figures=((-7.0, 0.74, 1.15), (7.0, 0.74, 1.15)))
		Mh = Matrix.Translation(tuple(heroS))
		with C.grp("SeasonCrest", Mh):
			G = S.FK(KD, Mh)
			G["V_Base"].prism(V.ccw(V.oct_pts(3.4)), 0.0, 0.8)
			G["V_Trim"].prism(V.ccw(V.oct_pts(2.8)), 0.8, 1.6)
			P = S.FK(KD, Mh @ Matrix.Translation((0, 0, 1.6)) @ V.RX(90))
			crest = V.ccw([(-2.8, 7.8), (2.8, 7.8), (3.2, 6.7), (3.2, 2.8), (0.0, 0.0), (-3.2, 2.8), (-3.2, 6.7)])
			P["V_Gold"].prism(crest, -0.35, 0.35)
			S.ring_prism(P["V_Trim"], V.inset(crest, -0.08), V.inset(crest, 0.45), 0.3, 0.55)
			S.add_text(P["E_White"], "1", 3.6, 0.25, y0=2.6, z0=0.3, s=0.26)
			for poly in V._icon_shapes("star", 1.6):
				P["E_ThViolet"].prism([(a, b + 7.7) for a, b in poly], -0.2, 0.2)  # set into the crest top
		V.fx("sparkle", heroS.x, heroS.y, heroS.z + 5.5, "#C5B7D9", name="SeasonFX", Rate=8, Spread=3.4)
		V.step_mark(KD, A, BX, Y1 - 5.4, 24.0, 8.0, "E_ThViolet", "LobbyBattlePass", "Mark_Season", facing=1.0)
		# the far end: the BROKER on a stepped plinth, the SHOP sign and a TV behind him
		Me, _ = walls["E"]
		V.tv(K, KD, Me @ V.T(Y1, 12.4, 0), 18.0, 8.8, "shop", "FEATURED", out=2.6, name="TV_ShopEnd")
		V.sign(KD, Me @ V.T(Y1, 22.2, 0), "SHOP", 18.0, 4.0, accent="E_Coral", name="Sign_ShopEnd", shape="tag", icon="sparkle", icon_at="right", icon_size=4.0)
		px = X1 - 9.0
		with C.grp("BrokerPlinth", Matrix.Translation((px, 0.0, 0.0))):
			F, G = S.FK(K, Matrix.Translation((px, 0.0, 0.0))), S.FK(KD, Matrix.Translation((px, 0.0, 0.0)))
			F["V_Floor2"].prism(V.ccw(V.oct_pts(5.4)), 0.12, 1.0)
			F["V_Lane"].prism(V.ccw(V.oct_pts(3.8)), 1.0, 1.9)
			for r_, zz in ((5.4, 1.0), (3.8, 1.9)):
				o, i_ = V.oct_pts(r_ + 0.05), V.oct_pts(r_ - 0.5)
				for k in range(8):
					j = (k + 1) % 8
					G["V_Trim"].prism(V.ccw([i_[k], i_[j], o[j], o[k]]), zz - 0.12, zz + 0.06)
			o, i_ = V.oct_pts(3.2), V.oct_pts(2.9)
			for k in range(8):
				j = (k + 1) % 8
				G["E_ThViolet"].prism(V.ccw([i_[k], i_[j], o[j], o[k]]), 1.9, 1.95)
		V.npc("Broker", px, 0.0, 1.9, 90, "broker", "BROKER", scale=1.8)
		S.light(I4, px, 0.0, H - 1.0, V.WHITE, 2.2, 30, 45)
		# hologram stands by the entrance, props in the corners
		V.holo_stand(K, KD, A, 73.0, Y1 - 7.0, "gift", name="Holo_ShopGift", size=2.6)
		V.holo_stand(K, KD, A, 73.0, Y0 + 7.0, "badge", name="Holo_ShopBadge", size=2.6)
		for (x, y, yaw, kind) in ((139.0, Y1 - 3.9, -6.0, "crate"), (133.5, Y1 - 3.6, 10.0, "barrel"), (139.0, Y0 + 3.9, 6.0, "container"), (133.5, Y0 + 3.6, -8.0, "crate_s")):
			V.prop_m(kind, Matrix.Translation((x, y, 0.0)) @ Matrix.Rotation(radians(yaw), 4, "Z"), name="Prop")
		# a lit path from the door to the plinth
		V.path_lane(KD, Matrix.Rotation(radians(-90), 4, "Z"), 3.0, X0 + 3.0, px - 6.0, arrows=(px - 11.0, px - 8.6))
		return K.done() + KD.done()
