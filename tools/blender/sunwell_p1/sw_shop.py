"""Sunwell Works: the Shop (station supply desk). A wide opening shows an inset counter and a featured hard case;
SKINS, CASES and SIDEARMS in lit wall bays on the far wall; Battle Pass and Event boards on the quieter return wall.
Entered from the hall's east wall at y = 72 under the ribbed valance."""
from math import radians, pi, cos, sin
from mathutils import Matrix, Vector

import sw_core as S
import sw_doors as DR
import sw_locker as LK

AREA = "Shop"
H = 14.0
X0, X1, Y0, Y1 = 43.4, 83.4, 60.0, 104.0
PTS = [(X0, Y0), (X1, Y0), (X1, Y1), (X0, Y1)]
TOP = 12.0  # top of the bay openings
AMBER = "#FFECD6"  # neutral warm white: the room read yellow-orange; amber stays in the sign, sill and strips


def hard_case(F, L=3.0, D=1.9, h=1.5, band="P_Orange", handle=True):
	"""Chunky hard case: shell with a lid seam, two straps, a handle, a seated latch and an inlaid rarity strip."""
	with S.grp("Case", F.M, inst=True):
		c = min(0.28, D * 0.16)
		foot = [(-L / 2 + c, -D / 2), (L / 2 - c, -D / 2), (L / 2, -D / 2 + c), (L / 2, D / 2 - c), (L / 2 - c, D / 2), (-L / 2 + c, D / 2),
			(-L / 2, D / 2 - c), (-L / 2, -D / 2 + c)]
		zs = h * 0.6
		F["CaseShell"].prism(foot, 0.0, zs)
		F["Dark"].box(-L / 2 + 0.06, L / 2 - 0.06, -D / 2 + 0.06, D / 2 - 0.06, zs, zs + 0.06)  # lid seam
		F["CaseShell"].prism(foot, zs + 0.06, h)
		for s in (-1, 1):
			x = s * L * 0.27
			F["Graphite"].box(x - 0.2, x + 0.2, -D / 2 - 0.05, D / 2 + 0.05, 0.02, h + 0.05)
		hw = L * 0.16
		if handle:  # left off a case that has another stacked on it
			for s in (-1, 1):
				F["Graphite"].box(s * hw - 0.13, s * hw + 0.13, -0.13, 0.13, h, h + 0.38)
			F["Graphite"].box(-hw - 0.13, hw + 0.13, -0.16, 0.16, h + 0.3, h + 0.52)
		F["Steel"].box(-0.26, 0.26, -D / 2 - 0.1, -D / 2, zs - 0.3, zs + 0.34)
		F[band].box(L * 0.3 + 0.28, L / 2 - 0.2, -D / 2 - 0.03, -D / 2 + 0.02, zs * 0.3, zs * 0.3 + 0.3)


def shop_bay(F, u, w, label, tick):
	"""Open display niche. Base cabinet and casing share one front plane, split by a shadow gap; the casing (sill,
	cheeks, header) is one continuous piece round a pale back, with a timber shelf liner and the category on the header."""
	B = F.at(Matrix.Translation((u, 0, 0)))
	hw = w / 2
	B["Charcoal"].box(-hw, hw, -1.5, TOP, -4.0, -2.4)
	B["Graphite"].box(-hw, hw, -1.5, 2.76, -2.4, 0.5)  # base cabinet
	for s in (-1, 1):
		B["Charcoal"].box(*sorted((s * 0.12, s * (hw - 0.4))), 0.55, 2.4, 0.5, 0.54)
		B["Steel"].box(s * 0.5 - 0.06, s * 0.5 + 0.06, 1.15, 1.85, 0.54, 0.64)
	B["PetrolDark"].box(-hw, hw, 0.0, 0.32, 0.5, 0.56)
	B["Dark"].box(-hw + 0.05, hw - 0.05, 2.76, 2.9, -2.4, 0.4)  # shadow gap
	S.ring_prism(B["Charcoal"], S.rect_loop(-hw, hw, 2.9, TOP), S.rect_loop(-hw + 0.6, hw - 0.6, 3.5, 9.9), -2.4, 0.5)
	B["BayBack"].box(-hw + 0.6, hw - 0.6, 3.5, 9.9, -2.4, -2.3)
	B["Timber"].box(-hw + 0.6, hw - 0.6, 3.5, 3.62, -2.3, 0.3)  # shelf liner
	B["E_Opal"].box(-hw + 1.2, hw - 1.2, 9.78, 9.9, -1.6, -0.9)
	B[tick].box(-hw + 0.8, -hw + 1.06, 10.35, 11.55, 0.5, 0.56)
	S.add_text(B["Cream"], label, 0.95, 0.2, y0=10.48, z0=0.45, x0=-hw + 1.5, s=0.2, c=0.07, track=0.16)
	S.collider(AREA, B.M, -hw + 0.1, hw - 0.1, -1.5, 2.66, -2.3, 0.38)
	S.collider(AREA, B.M, -hw + 0.1, hw - 0.1, 10.05, TOP, -2.3, 0.38)
	S.collider(AREA, B.M, -hw, hw, -1.5, TOP, -3.85, -2.55)
	S.light(B.M, 0, 8.6, -0.6, AMBER, 0.9, 9)
	return B


def gun_on(B, gid, du, rest, cw, chh):
	ln, ht = LK.gun_box(gid)
	sc = round(min(cw * 0.86 / ln, chh * 0.6 / ht, 3.0), 2)
	B["Steel"].box(du - ln * sc * 0.36, du + ln * sc * 0.36, rest - 0.14, rest, -2.4, -1.0)
	p = B.M @ Vector((du, rest, -1.55))
	t = B.M.to_3x3() @ Vector((1, 0, 0))
	S.gun_row([gid, sc, round(p.x, 3), round(p.y, 3), round(p.z, 3), round(t.x, 4), round(t.y, 4), 0, 0])


def chips(B, y, mats, w=1.5):
	n = len(mats)
	for i, m in enumerate(mats):
		x = (i - (n - 1) / 2) * (w + 0.5)
		B["Graphite"].box(x - w / 2 - 0.1, x + w / 2 + 0.1, y - 0.1, y + 0.7, -2.3, -2.16)
		B[m].box(x - w / 2, x + w / 2, y, y + 0.6, -2.16, -2.08)


def board(F, u, w, y0, y1, title, bar):
	"""Wall board: a framed dark panel with a title and one progress bar (the live version will be a SurfaceGui)."""
	B = F.at(Matrix.Translation((u, 0, 0)))
	hw = w / 2
	B["Charcoal"].box(-hw, hw, y0, y1, 0.0, 0.4)
	B["Dark"].box(-hw + 0.4, hw - 0.4, y0 + 0.4, y1 - 0.4, 0.4, 0.46)
	B["Timber"].box(-hw - 0.2, hw + 0.2, y0 - 0.3, y0, 0.0, 0.6)
	S.add_text(B["Cream"], title, 0.9, 0.16, y0=y1 - 1.75, z0=0.42, x0=-hw + 1.0, s=0.2, c=0.07, track=0.15)
	B["Graphite"].box(-hw + 1.0, hw - 1.0, y0 + 0.95, y0 + 1.35, 0.46, 0.5)
	B[bar].box(-hw + 1.0, -hw + 1.0 + (w - 2.0) * 0.62, y0 + 0.95, y0 + 1.35, 0.5, 0.55)
	S.light(B.M, 0, (y0 + y1) / 2, 2.2, AMBER, 0.6, 9)


def build():
	K, KC, edges = S.poly_room(AREA, PTS, 0.0, H, floor_mat="ShopFloor", t=3.9)  # 3.9: no outer face shares a plane with the Locker's walls
	bays = [(-14.0, "SKINS", "Stripe"), (0.0, "CASES", "Stripe"), (14.0, "SIDEARMS", "Stripe")]
	for i, (F, L, ext) in enumerate(edges):
		ops = []
		if i == 1:
			ops = [(u - 5.5, u + 5.5, TOP) for u, _l, _t in bays]
		if i == 3:
			ops = [(-20.0, 0.0, 13.0)]  # the doorway (door axis y = 72)
		S.wall_seg(F, AREA, L, H, ops, ext=ext, courses=[1.5, 6.75, TOP], t=3.9, top_trim=0.03 * (i % 2), name=f"ShopWall{i + 1}")
	FE = edges[1][0]
	# the three category bays on the far wall
	with S.grp("Bay_Skins", FE.at(Matrix.Translation((-14.0, 0, 0))).M):
		B = shop_bay(FE, -14.0, 11.0, "SKINS", "Stripe")
		gun_on(B, "Vandal", 0.0, 7.0, 9.4, 3.0)
		gun_on(B, "Phantom", 0.0, 4.2, 9.4, 3.0)
	with S.grp("Bay_Cases", FE.M):
		B = shop_bay(FE, 0.0, 11.0, "CASES", "Stripe")
		for row, y in enumerate((3.62, 6.5)):
			if row:
				B["Timber"].box(-5.0, 5.0, y - 0.25, y, -2.4, -0.7)
			for k in (-1, 0, 1):
				hard_case(B.at(Matrix.Translation((k * 3.1, y, -1.5)) @ Matrix.Rotation(-pi / 2, 4, "X")), 2.5, 1.4, 1.15,
					"Stripe")
	with S.grp("Bay_Sidearms", FE.at(Matrix.Translation((14.0, 0, 0))).M):
		B = shop_bay(FE, 14.0, 11.0, "SIDEARMS", "Stripe")
		gun_on(B, "Classic", -2.5, 7.0, 4.6, 3.0)
		gun_on(B, "Ghost", 2.5, 7.0, 4.6, 3.0)
		gun_on(B, "Sheriff", -2.5, 4.2, 4.6, 3.0)
		gun_on(B, "Shorty", 2.5, 4.2, 4.6, 3.0)
	for u in (-21.3, -7.0, 7.0, 21.3):  # cast piers between the bays
		with S.grp("Pier", FE.at(Matrix.Translation((u, 0, 0))).M, inst=True):
			P = FE.at(Matrix.Translation((u, 0, 0)))
			hw = 1.3 if abs(u) < 20 else 0.7
			P["CastTrim"].box(-hw, hw, 1.5, H, 0.0, 0.9)
			P["WallBase"].box(-hw - 0.3, hw + 0.3, 0.0, 1.5, 0.0, 1.2)
			S.collider(AREA, P.M, -hw + 0.2, hw - 0.2, 0.0, H, 0.05, 0.7)
	# counter with a timber top, two terminals, and the featured hard case on its dock
	with S.grp("Counter", reuse=True):
		cx0, cx1, cy0, cy1 = 69.0, 72.4, 63.0, 87.0
		K["Petrol"].ext_y([(cx0 - 0.55, 0.0), (cx1, 0.0), (cx1, 3.1), (cx0 + 0.1, 3.1)], cy0, cy1)  # the front leans back toward the top
		K["PetrolDark"].box(cx0 - 0.75, cx1 + 0.18, cy0 - 0.18, cy1 + 0.18, 0.0, 0.45)
		K["Timber"].prism(S.cham_rect(cx0 - 0.45, cx1 + 0.3, cy0 - 0.35, cy1 + 0.35, 0.5), 3.1, 3.42)
		for ye in (cy0, cy1):  # end cheeks
			K["Graphite"].ext_y([(cx0 - 0.68, 0.45), (cx1 + 0.1, 0.45), (cx1 + 0.1, 3.1), (cx0, 3.1)], ye - 0.15, ye + 0.15)
		K["E_Amber"].box(cx0 - 0.02, cx0 + 0.08, cy0 + 1.0, cy1 - 1.0, 2.6, 2.78)  # warm line under the counter lip
		S.collider(AREA, S.I4, cx0 + 0.15, cx1 - 0.15, cy0 + 0.15, cy1 - 0.15, 0.0, 3.3)
		S.collider(AREA, S.I4, cx0 - 0.75, cx0 - 0.5, cy0, cy1, 0.0, 3.4, kind="Y")  # the leaning front
		for y in (69.0, 81.0):  # terminals face the customer side (-x)
			with S.grp("Terminal", Matrix.Translation((70.9, y, 3.42)), inst=True):
				T = S.FK(K, Matrix.Translation((70.9, y, 3.42)))
				T["Graphite"].box(-0.5, 0.5, -0.7, 0.7, 0.0, 0.14)
				T["Graphite"].box(-0.12, 0.12, -0.2, 0.2, 0.14, 0.75)
				T["Charcoal"].box(-0.3, -0.1, -1.25, 1.25, 0.6, 2.2)
				T["E_Holo"].box(-0.34, -0.3, -1.1, 1.1, 0.75, 2.05)
	with S.grp("CaseDock", Matrix.Translation((70.0, 93.0, 0))):
		dx0, dx1, dy0, dy1 = 66.4, 73.6, 89.0, 97.0
		K["PetrolDark"].box(dx0, dx1, dy0, dy1, 0.0, 0.6)
		K["Cast"].box(dx0 + 0.5, dx1 - 0.5, dy0 + 0.5, dy1 - 0.5, 0.6, 1.2)
		S.ring_prism(K["E_Amber"], S.rect_loop(dx0 + 0.9, dx1 - 0.9, dy0 + 0.9, dy1 - 0.9), S.rect_loop(dx0 + 1.1, dx1 - 1.1, dy0 + 1.1, dy1 - 1.1), 1.14, 1.24)
		hard_case(S.FK(K, Matrix.Translation((70.0, 93.0, 1.2)) @ Matrix.Rotation(radians(-78), 4, "Z")), 4.4, 2.7, 2.1, "E_Amber")
		S.collider(AREA, S.I4, dx0 + 0.15, dx1 - 0.15, dy0 + 0.15, dy1 - 0.15, 0.0, 0.5)
		S.collider(AREA, S.I4, dx0 + 0.7, dx1 - 0.7, dy0 + 0.7, dy1 - 0.7, 0.4, 1.1)
		S.collider(AREA, S.I4, 68.2, 71.8, 90.8, 95.2, 1.2, 3.4, kind="Y")
		S.light(S.I4, 70.0, 93.0, 6.0, AMBER, 1.6, 12, angle=80)
	with S.grp("Counter", reuse=True):
		K["Stripe"].box(cx0 - 6.9, cx0 - 6.5, cy0, dy1, -0.2, 0.05)  # ochre line in front of the counter mat
	# Battle Pass and Event boards on the return wall
	FN = edges[2][0]
	DR.display(FN, -8.6, 7.4, 14.0, 6.2, "battlepass", "BATTLE PASS", "SEASON 1")
	DR.display(FN, 9.2, 7.4, 9.5, 6.2, "event", "EVENT", "GAUNTLET")
	# a story group by the near wall: supply cases waiting to be shelved, and a bench
	FS = edges[0][0]
	with S.grp("SupplyCases", Matrix.Translation((52.0, 62.4, 0.0))):
		G1 = S.FK(K, Matrix.Translation((50.0, 62.4, 0.0)) @ Matrix.Rotation(radians(4), 4, "Z"))
		hard_case(G1, 3.6, 2.2, 1.7, "Stripe", handle=False)
		hard_case(G1.at(Matrix.Translation((0.2, 0.05, 1.7)) @ Matrix.Rotation(radians(-9), 4, "Z")), 2.9, 1.8, 1.4, "Stripe")
		hard_case(S.FK(K, Matrix.Translation((54.4, 62.6, 0.0)) @ Matrix.Rotation(radians(-7), 4, "Z")), 2.6, 1.7, 1.3, "Stripe")
		S.collider(AREA, S.I4, 48.2, 55.8, 61.2, 63.6, 0.0, 1.7, kind="Y")
	# supply cabinets along the near wall: tall gunmetal lockers with seamed doors, pulls, vents and stock tags
	for k in range(3):
		Cb = FS.at(Matrix.Translation((4.9 - k * 4.4, 0, 0)))
		with S.grp("Cabinet", Cb.M, inst=True):
			Cb["Petrol"].box(-2.05, 2.05, 0.0, 9.6, 0.0, 2.0)
			Cb["PetrolDark"].box(-2.15, 2.15, 0.0, 0.5, 0.0, 2.1)
			Cb["PetrolDark"].box(-2.15, 2.15, 9.6, 9.95, 0.0, 2.15)
			for sx in (-1, 1):
				Cb["Graphite"].box(*sorted((sx * 0.06, sx * 1.9)), 0.7, 9.3, 2.0, 2.12)  # door leaf
				Cb["Steel"].box(sx * 0.42 - 0.08, sx * 0.42 + 0.08, 4.2, 5.6, 2.12, 2.3)  # pull
				for j in range(3):
					Cb["Dark"].box(*sorted((sx * 0.5, sx * 1.5)), 8.3 + j * 0.28, 8.42 + j * 0.28, 2.12, 2.15)  # vent slots
			Cb["Stripe"].box(-1.5, -0.5, 6.6, 7.1, 2.12, 2.17)  # stock tag
			S.collider(AREA, Cb.M, -1.9, 1.9, 0.0, 9.5, 0.1, 1.85)
	# hanging SUPPLY sign over the counter: the room's one headline
	Hs = S.FK(K, S.face((69.0, 75.0, 0.0), (0, -1, 0), (-1, 0, 0)))
	# hung high (11 to 13.6) so it never crosses the bay headers behind it, seen from the doorway
	with S.grp("SupplySign", Hs.M):
		Hs["Charcoal"].prism(S.cham_rect(-6.4, 6.4, 11.0, 13.6, 0.5), -0.3, 0.3)
		Hs["Graphite"].prism(S.cham_rect(-6.0, 6.0, 11.3, 13.3, 0.35), 0.3, 0.38)
		S.add_text(Hs["Cream"], "SHOP", 1.45, 0.3, y0=11.58, z0=0.33, s=0.225, c=0.1, track=0.3)  # matches the doorway
		for sx in (-1, 1):
			Hs["PetrolDark"].box(sx * 4.6 - 0.45, sx * 4.6 + 0.45, 13.6, H, -0.35, 0.35)
			Hs["E_Amber"].box(sx * 5.75 - 0.12, sx * 5.75 + 0.12, 11.5, 13.1, 0.38, 0.44)
	# rubber mat where customers stand, and ribs on the counter front
	with S.grp("Counter", reuse=True):
		K["Graphite"].box(cx0 - 6.2, cx0 - 1.0, cy0 + 1.0, cy1 - 1.0, -0.2, 0.07)  # mat (charcoal-brown, not black)
		K["E_Sun"].box(cx0 - 0.83, cx0 - 0.74, cy0 + 0.6, cy1 - 0.6, 0.06, 0.14)  # warm toe light along the counter foot
		for y in (68.0, 75.0, 82.0):
			S.light(S.I4, cx0 - 3.0, y, 9.5, "#FFECD6", 1.2, 13, angle=70)  # pools on the customer side
		for k in range(11):
			yy = cy0 + 1.6 + k * 2.08
			a0, a1 = cx0 - 0.424, cx0 - 0.047  # fins follow the leaning front
			K["PetrolDark"].ext_y([(a0 - 0.12, 0.6), (a0, 0.6), (a1, 2.4), (a1 - 0.12, 2.4)], yy - 0.5, yy + 0.5)
	# gallery-side casing of the doorway, and wall lights
	FW = edges[3][0]
	with S.grp("ShopDoorCasing", FW.M):
		S.u_frame(FW.at(Matrix.Translation((-10.0, 0, 0)))["Petrol"], 10.4, 12.6, 8.0, 11.0, 0.0, 0.5, co=2.0, ci=1.5)
	DR.sconce(FW, 4.0, 9.6)
	DR.sconce(FW, 14.0, 9.6)
	for x in (53.0, 64.0, 77.0):
		for y in (71.0, 93.0):
			S.opal_panel(KC, x, y, H, 4.6, 4.6, color="#F4EEE6", brightness=0.32, rng=20)  # lighting pass: the bays and lamps carry the light
	S.soffit(KC, AREA, PTS, H, depth=0.6, width=3.0, lights=6, name="ShopSoffit")
	S.ceiling_beam(KC, X0 + 3.0, 82.0, X1 - 3.0, 82.0, H, name="ShopBeam")
	with S.grp("FeaturedPlinth", Matrix.Translation((56.0, 82.0, 0))):  # the room's hero: a featured item turning over a lit plinth
		import sw_hub as _H2
		PM = Matrix.Translation((56.0, 82.0, 0))
		Pf = S.FK(K, PM)
		o = _H2.oct_pts
		Pf["WallBase"].solid([(x, y, 0.0) for x, y in o(2.05)], [(x, y, 0.4) for x, y in o(1.9)])  # battered foot
		Pf["Petrol"].solid([(x, y, 0.4) for x, y in o(1.3)], [(x, y, 2.9) for x, y in o(1.0)])  # tapered column
		Pf["PetrolDark"].prism(o(1.55), 2.9, 3.15)  # top plate
		S.ring_prism(Pf["E_Amber"], o(1.5), o(1.28), 3.15, 3.2)  # light ring
		Pf["Charcoal"].prism(o(1.28), 3.15, 3.22)
		for rot in (0.0, pi / 4):
			S.collider(AREA, PM @ Matrix.Rotation(rot, 4, "Z"), -1.95, 1.95, -1.95, 1.95, 0.0, 3.2, kind="Y")
		C2 = __import__("lv3_core")
		C2.collider_cyl(AREA, 56.0, 82.0, 1.8, 3.2, 7.6, kind="X")  # keeps players off the turning item
		S.gun_row(["Vandal", 1.25, 56.0, 82.0, 4.0, 0.0, 1.0, 1, 18])  # about 4.9 long over a 3-stud plinth
		S.light(PM, 0, 0, 11.5, "#FFE6C4", 1.6, 16, angle=50)  # a tight spot on the item
		S.light(PM, 0, 0, 3.6, "#FFB866", 0.6, 7)  # warm uplight from the ring
	with S.grp("Stanchions", Matrix.Translation((56.0, 82.0, 0))):  # a low barrier round the featured plinth, open toward the door
		import sw_hub as _H3
		PM = Matrix.Translation((56.0, 82.0, 0))
		posts = [(3.9 * cos(a), 3.9 * sin(a)) for a in [radians(292.5 + 45 * k) for k in range(6)]]  # six posts; the gap faces the doorway
		for x, y in posts:
			P = S.FK(K, PM @ Matrix.Translation((x, y, 0)))
			P["PetrolDark"].prism(_H3.oct_pts(0.42), 0.0, 0.12)  # base
			P["Petrol"].solid([(px, py, 0.12) for px, py in _H3.oct_pts(0.14)], [(px, py, 2.6) for px, py in _H3.oct_pts(0.12)])
			P["Stripe"].prism(_H3.oct_pts(0.2), 2.6, 2.78)  # cap
		for (x0, y0), (x1, y1) in zip(posts, posts[1:]):
			import math as _m
			a = _m.atan2(y1 - y0, x1 - x0)
			L = _m.hypot(x1 - x0, y1 - y0)
			B = S.FK(K, PM @ Matrix.Translation(((x0 + x1) / 2, (y0 + y1) / 2, 0)) @ Matrix.Rotation(a, 4, "Z"))
			B["Charcoal"].box(-L / 2 + 0.15, L / 2 - 0.15, -0.05, 0.05, 2.22, 2.42)  # belt between posts
		for x, y in posts:
			S.collider(AREA, PM @ Matrix.Translation((x, y, 0)), -0.2, 0.2, -0.2, 0.2, 0.0, 2.8, kind="Y")
	with S.grp("ShopFloorGrid"):  # laid floor plates: joints every 6 studs inside the border (clear of the emblem and counter mat)
		for x in (49.0, 55.0, 61.0):
			for ya, yb in ((62.9, 76.6), (87.4, 101.1)):
				K["Graphite"].box(x - 0.05, x + 0.05, ya, yb, 0.0, 0.025)
		for y in (68.0, 74.0, 90.0, 96.0):
			K["Graphite"].box(45.9, 62.0, y - 0.05, y + 0.05, 0.0, 0.025)
	with S.grp("ShopFloorEmblem", Matrix.Translation((56.0, 82.0, 0))):
		E = S.FK(K, Matrix.Translation((56.0, 82.0, 0)))
		import sw_hub as _H
		S.ring_prism(E["Graphite"], _H.oct_pts(4.2), _H.oct_pts(3.8), 0.0, 0.03)
		E["Stripe"].prism(_H.star_pts(2.2, 1.0, 8, 3.14159 / 8), 0.0, 0.03)
		E["Graphite"].prism(_H.oct_pts(0.6), 0.0, 0.035)
	S.pilaster(FN, 0.4, H - 0.6, name="ShopPilaster")  # between the Battle Pass and Event boards
	S.pilaster(FN, -18.2, H - 0.6, name="ShopPilaster")
	S.pilaster(FN, 16.8, H - 0.6, name="ShopPilaster")
	S.pilaster(FS, 9.2, H - 0.6, name="ShopPilaster")  # either side of the supply cabinets
	S.pilaster(FS, -9.4, H - 0.6, name="ShopPilaster")
	with S.grp("ShopFloorMarks"):
		from mathutils import Vector as _V
		import lv3_core as _C
		outer = _C._inset_poly([_V(p) for p in PTS], 2.4)
		inner = _C._inset_poly([_V(p) for p in PTS], 2.8)
		S.ring_prism(K["Graphite"], [(p.x, p.y) for p in outer], [(p.x, p.y) for p in inner], 0.0, 0.03)
	S.anchor("ShopZone", "LobbyShop", 65.5, 75.0, 3.5, 6.0, 16.0, 6.0)
	S.anchor("BattlePassZone", "LobbyBattlePass", 55.0, 100.5, 3.5, 14.0, 6.0, 6.0)
	K.done()
	KC.done()
