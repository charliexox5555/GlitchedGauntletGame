"""Lobby V3 Duels hall (north), second version. Low blast gate -> landing -> arrowed ramp down -> a long dark hall.
Queue stations stand in bays down both walls (the east bays are staggered half a bay against the west ones):
each station has two team pads set into the floor side by side and a hologram board per pad on the wall behind.
The hall ends at a raised stage with the Gauntlet portal. Dark, neutral surfaces: the pads and holograms carry the colour.
World frame: the wing axis is +Y."""
from math import sin, cos, pi, radians, sqrt, atan
from mathutils import Matrix, Vector
import lv3_core as C

D = radians
X0, X1 = -26.0, 26.0  # interior faces of the side walls
Y0, YE = 52.0, 246.0  # hub-side wall, end wall
ZF, ZC = -4.0, 22.0
ZS = ZF + 0.9  # stage
WEST_PIERS = [80, 110, 140, 170, 200, 230]
EAST_PIERS = [80, 95, 125, 155, 185, 215, 230]
MODES = {"1v1": (9.0, 8.0, 1), "2v2": (11.0, 9.5, 2), "3v3": (11.5, 12.0, 3), "4v4": (11.5, 13.5, 4)}  # pad width, depth, players
# side (-1 west, +1 east), bay centre y, mode, station letter, open
STATIONS = [
	(-1, 95, "1v1", "A", True), (-1, 125, "2v2", "A", True), (-1, 155, "1v1", "C", True), (-1, 185, "2v2", "B", True), (-1, 215, "3v3", "B", True),
	(1, 110, "1v1", "B", True), (1, 140, "3v3", "A", True), (1, 170, "1v1", "D", True), (1, 200, "4v4", "A", False),
]
TEAM = ("N_TeamA", "N_TeamB")
PADS = []  # [pad id, mode, world x, world y, top z, width along the wall, depth, side, open] for the queue zones in Studio


def mats():
	S = C.surface
	S("ConcreteDuels", "#3A3D41", 0.8, var=0.05, bump=0.05, ao=0.45)
	S("DuelPier", "#2B2E32", 0.7, var=0.05, bump=0.04, ao=0.45)
	S("DuelUpper", "#25282B", 0.9, var=0.06, bump=0.06, ao=0.4)
	S("DuelFloor", "#26292D", 0.4, var=0.04, bump=0.04, ao=0.4, seams=dict(mode="floor", h=5, v=5, w=0.04, dark=0.3))
	S("DuelStage", "#303439", 0.45, var=0.04, bump=0.04, ao=0.4)
	S("PortalPanel", "#121418", 0.4, var=0.02, bump=0.0, ao=0.2)
	S("PadInk", "#14161A", 0.5, var=0.02, bump=0.0, ao=0.1)
	S("PadOff", "#3A3F45", 0.5, var=0.03, bump=0.0, ao=0.2)
	C.emission("N_TeamA", "#FF6A3D", 3.2)
	C.emission("N_TeamB", "#2E9BFF", 3.2)
	C.emission("HoloLine", "#7FD4FF", 5.0)
	C.emission("HoloPane", "#1F6FA8", 0.5)
	C.emission("E_Spine", "#E6EEFF", 14.0)
	C.emission("E_PierStrip", "#CFE0FF", 5.0)
	C.BEVEL.update({"ConcreteDuels": 0.35, "DuelPier": 0.4, "DuelUpper": 0.35, "DuelFloor": 0.08, "DuelStage": 0.2, "PortalPanel": 0.0,
		"PadInk": 0.0, "PadOff": 0.0, "N_TeamA": 0.0, "N_TeamB": 0.0, "HoloLine": 0.0, "HoloPane": 0.0, "E_Spine": 0.0, "E_PierStrip": 0.0})
	C.NO_COLLIDE.update({"PadInk", "PadOff", "N_TeamA", "N_TeamB", "HoloLine", "HoloPane"})


def shell(K):
	K["DuelFloor"].box(X0, X1, Y0, YE, -6, ZF)
	K["FloorDark"].box(-7, 7, 48, 52, -6, 0)
	K["ConcreteDuels"].ext_y(
		[(-30, -6), (-7, -6), (-7, 9), (-4, 12), (4, 12), (7, 9), (7, -6), (30, -6), (30, ZC), (-30, ZC)], 48, 52)
	for sx, xw in ((1, X1), (-1, X0)):
		xo = xw + sx * 4
		K["ConcreteDuels"].box(min(xw, xo), max(xw, xo), Y0, YE, -6, 12.6)
		K["Steel"].box(min(xw - sx * 0.4, xo), max(xw - sx * 0.4, xo), Y0, YE, 12.6, 13.2)  # ledge
		K["DuelUpper"].box(min(xw + sx * 0.5, xo), max(xw + sx * 0.5, xo), Y0, YE, 13.2, ZC)
		K["DuelPier"].ext_y([(xw, ZF), (xw - sx * 0.6, ZF), (xw - sx * 0.3, ZF + 1.4), (xw, ZF + 1.4)], Y0, YE)  # skirt


def entry(K):
	"""Landing and the arrowed ramp."""
	K["FloorDark"].box(-7, 7, 52, 60, ZF, 0)
	K["FloorDark"].ext_x([(60, ZF), (60, 0), (76, ZF)], -7, 7)
	for sx in (-1, 1):
		K["ConcreteDuels"].ext_x([(52, ZF), (52, 1.9), (60, 1.9), (76, -2.1), (77.5, -2.6), (77.5, ZF)], sx * 7, sx * 9)
		K["Steel"].ext_x([(52, 1.9), (52, 2.25), (60, 2.25), (76, -1.75), (77.7, -2.3), (77.5, -2.6), (76, -2.1), (60, 1.9)], sx * 6.8, sx * 9.2)
	th = atan(4.0 / 16.0)
	M = Matrix.Translation((0, 60, 0)) @ Matrix.Rotation(-th, 4, "X")
	b = K["P_White"].framem(M)
	for c in (1.4, 5.3, 9.2, 13.1):
		b.prism([(-3.2, c), (0, c + 1.7), (3.2, c), (3.2, c + 1.0), (0, c + 2.7), (-3.2, c + 1.0)], 0.0, 0.035)
	b.reset()


def piers(K):
	"""Rounded dark piers with a slim recessed light strip between two steel fins."""
	for sx, xw, ys in ((-1, X0, WEST_PIERS), (1, X1, EAST_PIERS)):
		for y in ys:
			xa, xb = sorted((xw, xw - sx * 3.0))
			K["DuelPier"].box(xa, xb, y - 2.0, y + 2.0, ZF, ZC)
			xa, xb = sorted((xw, xw - sx * 3.5))
			K["DuelPier"].box(xa, xb, y - 2.5, y + 2.5, ZF, ZF + 1.55)
			xf = xw - sx * 3.0
			xa, xb = sorted((xf, xf - sx * 0.22))
			for dy in (-0.55, 0.4):
				K["Steel"].box(xa, xb, y + dy, y + dy + 0.15, ZF + 1.6, ZF + 11.4)
			xa, xb = sorted((xf, xf - sx * 0.08))
			K["E_PierStrip"].box(xa, xb, y - 0.4, y + 0.4, ZF + 1.8, ZF + 11.2)


def local(side, yc):
	"""Station frame: origin on the wall at the bay centre, +Y into the room, Z up from the hall floor."""
	xw = X0 if side < 0 else X1
	return Matrix.Translation((xw, yc, ZF)) @ Matrix.Rotation(D(-90) if side < 0 else D(90), 4, "Z")


def station(K, side, yc, mode, letter, live):
	W, Dp, n = MODES[mode]
	M = local(side, yc)
	gap = 0.9
	y0, y1 = 2.9, 2.9 + Dp
	K["Steel"].framem(M).box(-13.0, 13.0, 0.0, 1.3, 14.4, 16.6)  # header beam between the piers
	K["DuelPier"].framem(M).ext_x([(0, 0), (1.5, 0), (1.5, 0.7), (1.0, 1.25), (0, 1.25)], -W - gap - 0.3, W + gap + 0.3)  # projector cabinet
	K["Steel"].framem(M).box(-0.3, 0.3, 2.5, y1 + 0.4, 0.0, 0.35)  # kerb between the two pads
	for i, s in enumerate((1, -1)):  # team A is on the viewer's left
		cx = s * (W / 2 + gap)
		glow = TEAM[i] if live else "PadOff"
		K["Steel"].framem(M).box(cx - W / 2 - 0.4, cx + W / 2 + 0.4, y0 - 0.4, y1 + 0.4, 0.0, 0.16)
		K[glow].framem(M).box(cx - W / 2, cx + W / 2, y0, y1, 0.16, 0.22)
		C.collider_box("Duels", M, cx - W / 2 - 0.4, cx + W / 2 + 0.4, y0 - 0.4, y1 + 0.4, -0.3, 0.22)  # so feet stand on the pad, not in it
		# emblem: an octagon ring round a diamond, with two side bars (ours, not a target)
		m = min(W, Dp)
		cy = (y0 + y1) / 2
		K["PadInk"].framem(M @ Matrix.Translation((cx, cy, 0)) @ Matrix.Rotation(D(22.5), 4, "Z")).ring(0.27 * m, 0.36 * m, 0.22, 0.25, n=8)
		Md = M @ Matrix.Translation((cx, cy, 0))
		K["PadInk"].framem(Md).prism([(0.15 * m, 0), (0, 0.15 * m), (-0.15 * m, 0), (0, -0.15 * m)], 0.22, 0.25)
		for sg in (-1, 1):
			xa, xb = sorted((sg * 0.42 * m, sg * 0.47 * m))
			K["PadInk"].framem(Md).box(xa, xb, -0.2 * m, 0.2 * m, 0.22, 0.25)
		# hologram board: a pane, a frame, a header rule and a portrait box per player
		Wb = W - 1.0
		K["HoloPane"].framem(M).box(cx - Wb / 2 + 0.03, cx + Wb / 2 - 0.03, 0.92, 0.98, 2.63, 9.57)
		for z0, z1 in ((2.6, 2.72), (9.48, 9.6), (7.9, 7.98)):
			K["HoloLine"].framem(M).box(cx - Wb / 2, cx + Wb / 2, 0.9, 1.0, z0, z1)
		for sg in (-1, 1):
			K["HoloLine"].framem(M).box(cx + sg * Wb / 2 - 0.06, cx + sg * Wb / 2 + 0.06, 0.9, 1.0, 2.72, 9.48)
		pw = min(3.2, (Wb - 0.8 - (n - 1) * 0.5) / n)
		for k in range(n):
			px = cx + (k - (n - 1) / 2) * (pw + 0.5)
			for z0, z1 in ((3.5, 3.6), (7.0, 7.1)):
				K["HoloLine"].framem(M).box(px - pw / 2, px + pw / 2, 0.9, 1.0, z0, z1)
			for sg in (-1, 1):
				K["HoloLine"].framem(M).box(px + sg * pw / 2 - 0.05, px + sg * pw / 2 + 0.05, 0.9, 1.0, 3.6, 7.0)
		K["HoloLine"].framem(M).box(cx - Wb / 2 + 0.5, cx + Wb / 2 - 0.5, 0.55, 0.95, 1.25, 1.3)  # projector lens on the cabinet
		wp = M @ Vector((cx, cy, 0.22))
		PADS.append([f"{mode}_{letter}{'W' if i == 0 else 'E'}", mode, round(wp.x, 3), round(wp.y, 3), round(wp.z, 3), W, Dp, side, 1 if live else 0])


def stage(K):
	"""Raised stage and the Gauntlet portal: a framed, sealed recess (the hologram and sign come with the props)."""
	K["DuelStage"].box(-20, 20, 229.0, YE, ZF, ZF + 0.45)
	K["DuelStage"].box(-20, 20, 230.2, YE, ZF + 0.45, ZS)
	K["P_Duels"].box(-20, 20, 230.2, 230.6, ZS, ZS + 0.03)
	op = [(-10, -6), (-10, ZS + 11.0), (-7, ZS + 14.0), (7, ZS + 14.0), (10, ZS + 11.0), (10, -6)]
	K["ConcreteDuels"].ext_y([(-30, -6)] + op + [(30, -6), (30, ZC), (-30, ZC)], YE, YE + 2.0)
	K["ConcreteDuels"].box(-30, 30, YE + 2.0, YE + 4.0, -6, ZC)
	K["DuelStage"].box(-10, 10, YE, YE + 2.0, -6, ZS)  # floor of the recess
	K["PortalPanel"].box(-10, 10, YE + 1.7, YE + 2.0, ZS, ZS + 14.0)  # the sealed panel
	outer = [(-12.2, ZS), (-12.2, ZS + 11.9), (-7.9, ZS + 16.2), (7.9, ZS + 16.2), (12.2, ZS + 11.9), (12.2, ZS)]
	inner = [(10, ZS), (10, ZS + 11.0), (7, ZS + 14.0), (-7, ZS + 14.0), (-10, ZS + 11.0), (-10, ZS)]
	K["Steel"].ext_y(outer + inner, YE - 0.9, YE)
	for sx in (-1, 1):  # light pylons at the stage corners, light strips beside the frame
		K["DuelPier"].frame(0, sx * 16.5, 233.0, ZS).taper((-1.1, 1.1, -1.1, 1.1), 0, (-0.8, 0.8, -0.8, 0.8), 5.2)
		K["E_Warm"].frame(0, sx * 16.5, 233.0, ZS).box(-0.55, 0.55, -0.55, 0.55, 5.2, 6.0)
		K["Steel"].frame(0, sx * 16.5, 233.0, ZS).box(-0.85, 0.85, -0.85, 0.85, 6.0, 6.3)
		xa, xb = sorted((sx * 12.6, sx * 12.9))
		K["E_PierStrip"].box(xa, xb, YE - 0.1, YE, ZS + 1.0, ZS + 10.5)


def roof(KC):
	KC["ConcreteCeil"].box(-30, 30, 48, YE + 4, ZC, 30)
	y = 66
	while y < YE - 6:  # light spine down the middle
		KC["Steel"].box(-1.0, 1.0, y - 5, y + 5, 16.0, 16.7)
		KC["E_Spine"].box(-0.7, 0.7, y - 4.7, y + 4.7, 15.92, 16.0)
		for dy in (-4, 4):
			KC["Steel"].pipe((0, y + dy, 16.7), (0, y + dy, ZC), 0.12, 8)
		y += 20
	KC["Brushed"].pipe((17.5, 53, 19.6), (17.5, YE - 1, 19.6), 1.0, 20)  # air duct, east side only
	KC["Steel"].box(-18.6, -16.6, 53, YE - 1, 20.2, 20.45)  # cable tray, west side only
	KC["Steel"].box(-18.6, -18.4, 53, YE - 1, 20.45, 20.9)
	KC["Steel"].box(-16.8, -16.6, 53, YE - 1, 20.45, 20.9)
	for y in range(70, int(YE), 30):
		KC["Steel"].box(16.2, 18.8, y - 0.2, y + 0.2, 18.6, ZC)
		KC["Steel"].box(-18.8, -16.4, y - 0.2, y + 0.2, 20.0, ZC)


def build():
	mats()
	PADS.clear()
	C.clear("Duels")
	C.clear("Duels_Ceil")
	col, cc = C.coll("Duels", C.root()), C.coll("Duels_Ceil", C.root())
	K, KC = C.Kit(col), C.Kit(cc)
	shell(K)
	entry(K)
	piers(K)
	for st in STATIONS:
		station(K, *st)
	stage(K)
	roof(KC)
	C.dummy(K, 2.5, 57, 0.0, 0.2)
	C.dummy(K, -17.0, 99.0, ZF + 0.22, 0.0)
	C.dummy(K, -17.0, 91.0, ZF + 0.22, 3.14)
	K.done()
	KC.done()
