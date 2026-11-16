# build_odin_v2.py: RemasterV2 Odin (belt-fed heavy machine gun), fresh rebuild from
# vault/02 Art/References/Gun-Image-Concepts/Odin-inspired belt-fed machine gun prop sheet-15.png. Blender MCP only.
# Contract measured on the original Odin.blend (REF_Odin_Original): Muzzle 3.3635, buttpad -1.2425, bore z 0.371,
# AimPoint (0.021, 0, 0.6503), front post x 2.4325, LeftGrip (1.715, 0, 0.154); bones Root/AmmoBox/FeedBelt (child of
# AmmoBox)/FeedCover/ChargingHandle/Bolt/Trigger/Flash/Charm (original heads, Charm moved); BeltFeedPoint on FeedBelt.
# FeedCover hinges at its rear (negative Y rotation lifts the front); ChargingHandle racks -0.2.
# Changes: thicker shroud/feed/rear receiver (0.096 -> 0.1) with armour plates and the concept's neon slashes, a feed
# window holding five linked rounds, ammo box with lid band, raised X, handle and clip (sheet's olive normalised to the
# family palette), hinged cover with ears and latch; charging handle moved forward in its slot so the full rack stays
# inside it (the original's knob ran past the slot end); port + bolt; octagonal hider; open ring + hooded post on the
# front sight block; skeleton stock; hanging charm tab under the shroud.

import bpy, math, sys, importlib
from mathutils import Matrix, Vector

ROOT = r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/art-source/weapons/RemasterV2"
sys.path.insert(0, ROOT + "/_Library")
import v2kit as K  # noqa: E402
import v2build as B  # noqa: E402
import sights as SI  # noqa: E402

importlib.reload(K)
importlib.reload(B)
importlib.reload(SI)
from v2kit import BODY, PANEL, DARK, METAL, GRIP, ACCENT, NEON, BRASS  # noqa: E402

GUN = "Odin"
BORE = 0.371
SIGHT_Z = 0.6503
AIM_X = 0.021
FRONT_X = 2.4325
MUZZLE_X = 3.3635
RW, BW = 0.1, 0.156
BELT_Y = 0.054
ROUNDS = (0.3955, 0.336, 0.275, 0.2135, 0.1523)
AIM_ROT = Matrix(((0, 0, 1), (0, 1, 0), (-1, 0, 0))).to_4x4()
EJECT_ROT = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0))).to_4x4()


def slash(x0, z0, z1, w=0.035, lean=0.049):
	return [(x0, z0), (x0 + w, z0), (x0 + w + lean, z1), (x0 + lean, z1)]


def build_parts():
	parts = {}

	def part(name, bone="Root"):
		parts[name] = K.Part(name, bone)
		return parts[name]

	both = B.both
	neon = part("Neon")

	# ================================================================ Receiver: shroud, armour plates, feed section, rear receiver, end block
	rec = part("Receiver")
	shroud = B.solid(K.chamfer([(1.44, 0.175), (2.2715, 0.175), (2.2715, 0.5005), (1.44, 0.5005)], [0, 0.03, 0.02, 0]), K.section(RW, 0.175, 0.5005, 0.03, 0.02), BODY, 0.003)
	shroud = K.cut(shroud, both(K.group(K.box(1.75, 2.10, RW - 0.012, 0.2, 0.276, 0.343), K.box(1.465, 2.25, RW - 0.004, 0.2, 0.418, 0.428))), DARK)
	rec.add(shroud)
	plate = K.prism(K.chamfer([(1.1025, 0.1575), (1.855, 0.1575), (1.855, 0.35), (1.155, 0.35), (1.1025, 0.30)], [0, 0.016, 0.016, 0, 0.0]), "Y", RW - 0.004, RW + 0.014, PANEL)
	plate = K.cut(K.bevel(plate, 0.003, 1, 50), K.group(*[K.prism(slash(x, 0.24, 0.30), "Y", RW + 0.008, 0.2) for x in (1.73, 1.79)]), DARK)
	rec.add(both(plate))
	neon.add(both(K.group(*[K.prism(slash(x + 0.002, 0.242, 0.298, 0.031), "Y", RW + 0.0085, RW + 0.0105, NEON) for x in (1.73, 1.79)])))
	loop = K.prism(K.chamfer([(1.855, 0.18), (2.03, 0.18), (2.03, 0.09), (1.855, 0.09)], 0.012), "Y", -0.014, 0.014, DARK)
	rec.add(K.cut(loop, K.box(1.876, 2.009, -0.05, 0.05, 0.108, 0.155), DARK), 0.002)  # sling loop
	feed = B.solid(K.chamfer([(0.7875, 0.133), (1.4525, 0.133), (1.4525, 0.49), (0.7875, 0.49)], 0.0), K.section(RW, 0.133, 0.49, 0.0, 0.02), BODY, 0.003)
	feed = K.cut(feed, K.prism(K.chamfer([(0.79, 0.12), (1.057, 0.12), (1.057, 0.441), (0.79, 0.441)], [0, 0, 0.012, 0]), "Y", 0.02, 0.2), DARK)  # feed window (left)
	rec.add(feed)
	rear = B.solid([(0.7875, 0.5705), (-0.168, 0.5705), (-0.168, 0.3075), (-0.1225, 0.1575), (0.7525, 0.1575), (0.7875, 0.1925)], K.section(RW, 0.15, 0.5705, 0.026, 0.016), BODY, 0.003)
	rear = K.cut(rear, K.group(
		K.prism(K.chamfer([(-0.112, 0.3045), (0.35, 0.3045), (0.35, 0.3605), (-0.112, 0.3605)], 0.008), "Y", RW - 0.016, 0.2),  # charging slot (left)
		K.prism(K.chamfer([(0.35, 0.308), (0.595, 0.308), (0.595, 0.385), (0.35, 0.385)], 0.012), "Y", -0.2, -RW + 0.026),  # port (right)
		both(K.group(K.box(-0.14, 0.70, RW - 0.004, 0.2, 0.4125, 0.4235), K.box(0.14, 0.525, RW - 0.004, 0.2, 0.49, 0.518))),
	), DARK)
	rec.add(rear)
	endb = B.solid(K.chamfer([(-0.28, 0.1925), (-0.1575, 0.1925), (-0.1575, 0.565), (-0.28, 0.565)], [0, 0, 0.016, 0.03]), K.section(0.094, 0.1925, 0.565, 0.018, 0.018), PANEL, 0.003)  # top kept at the receiver line (ADS view)
	rec.add(K.cut(endb, both(K.box(-0.255, -0.19, 0.088, 0.2, 0.46, 0.51)), DARK))
	neon.add(both(K.box(-0.252, -0.193, 0.0885, 0.0905, 0.463, 0.507, NEON)))
	guard = K.bevel(K.prism([(0.175, 0.16), (0.455, 0.16), (0.455, 0.06), (0.41, 0.0), (0.21, 0.0), (0.175, 0.04)], "Y", -0.032, 0.032, DARK), 0.006, 1, 30)
	rec.add(K.cut(guard, K.prism(K.chamfer([(0.21, 0.2), (0.42, 0.2), (0.42, 0.06), (0.39, 0.028), (0.21, 0.028)], [0, 0, 0.012, 0.0, 0.0]), "Y", -0.1, 0.1), DARK))
	rec.add(K.prism(K.chamfer([(0.33, 0.31), (0.352, 0.31), (0.352, 0.383), (0.33, 0.383)], [0.006, 0, 0, 0.006]), "Y", -RW - 0.012, -RW + 0.004, BODY), 0.003)
	rec.add(K.box(-0.1, 0.78, -0.036, 0.036, 0.567, 0.59, DARK), 0.003)  # rear rail
	t = K.Part("_t")
	for x in [0.13 + 0.06 * i for i in range(11)]:
		t.add(K.drop(K.box(x, x + 0.028, -0.038, 0.038, 0.589, 0.6, DARK), 2, -1))
	rec.add(t.merged())

	# ================================================================ Barrel + collar + hider
	br = part("Barrel")
	# v03: heavy MG barrel (0.068 -> 0.08) with a bigger collar, muzzle ring and hider (concept).
	br.add(K.drop(K.cyl_x(2.26, 3.03, 0.08, 0.0, BORE, 14, METAL), 0, 1))
	br.add(K.cyl_x(2.4955, 2.604, 0.1, 0.0, BORE, 14, DARK), 0.006)
	br.add(K.cyl_x(3.0275, 3.13, 0.104, 0.0, BORE, 8, DARK, rot=0.0), 0.006)
	hider = K.bevel(K.cyl_x(3.122, MUZZLE_X, 0.108, 0.0, BORE, 8, DARK, rot=0.0), 0.007)  # seated against the ring
	br.add(K.cut(hider, K.group(K.box(3.18, 3.31, -0.14, 0.14, BORE - 0.035, BORE + 0.035), K.cyl_x(MUZZLE_X - 0.06, MUZZLE_X + 0.03, 0.045, 0.0, BORE, 10)), DARK))

	# ================================================================ Sights
	si = part("Sights")
	si.add(B.solid(K.chamfer([(2.3485, 0.21), (2.4955, 0.21), (2.4955, 0.5075), (2.3485, 0.5075)], 0.02), K.section(0.09, 0.21, 0.5075, 0.026, 0.026), DARK, 0.003))  # front sight block (v03: wider round the heavier barrel)
	si.add(B.solid([(FRONT_X - 0.05, 0.505), (FRONT_X + 0.05, 0.505), (FRONT_X + 0.026, 0.60), (FRONT_X - 0.026, 0.60)], [(-0.04, 0.505), (0.04, 0.505), (0.036, 0.60), (-0.036, 0.60)], DARK, 0.003))  # v03: top carries the box hood walls
	# v02 sight picture (Odin's own, HMG): a ladder frame with a V-notch slider at the rear; the front post in a
	# square box hood.
	si.add(SI.box_hood(FRONT_X, SIGHT_Z, 0.598, hw=0.038, depth=0.05))
	si.add(SI.post(FRONT_X, SIGHT_Z, 0.597))
	for pc in SI.ladder_frame(AIM_X, SIGHT_Z, 0.598, hw=0.05):
		si.add(pc)
	si.add(B.solid(K.chamfer([(-0.1225, 0.588), (0.0875, 0.588), (0.0875, 0.6), (-0.1225, 0.6)], 0.0), K.section(0.044, 0.585, 0.6, 0.006, 0.0), DARK, 0.002))

	# ================================================================ Grip
	gr = part("Grip")
	gp = [(0.238, 0.1645), (-0.052, 0.1645), (-0.21, -0.192), (-0.2275, -0.2515), (-0.0595, -0.315), (-0.035, -0.2625), (0.07, 0.0)]
	grip = K.bevel(K.prism(gp, "Y", -0.066, 0.066, DARK), 0.014, 1)
	gr.add(K.cut(grip, both(K.prism(K.chamfer([(0.15, 0.10), (-0.04, 0.11), (-0.16, -0.20), (-0.03, -0.24)], 0.02), "Y", 0.062, 0.2)), GRIP))

	# ================================================================ Stock
	st = part("Stock")
	st.add(B.solid(K.chamfer([(-0.385, 0.168), (-0.273, 0.168), (-0.273, 0.4725), (-0.385, 0.4725)], 0.014), K.section(0.074, 0.168, 0.4725, 0.016, 0.016), DARK, 0.003))
	sbody = B.solid([(-0.378, 0.455), (-0.892, 0.399), (-0.962, 0.49), (-0.987, 0.49), (-0.987, -0.2275), (-0.91, -0.238), (-0.378, 0.168)], K.section(0.072, -0.24, 0.49, 0.022, 0.016), BODY, 0.004)
	st.add(K.cut(sbody, K.prism(K.chamfer([(-0.578, 0.27), (-0.935, 0.27), (-0.935, 0.004), (-0.893, -0.003)], 0.02), "Y", -0.2, 0.2), DARK))
	pad = B.solid(K.chamfer([(-0.9625, 0.5005), (-1.2425, 0.5005), (-1.2425, -0.2345), (-0.9625, -0.2345)], [0, 0.03, 0.03, 0]), K.section(0.082, -0.2345, 0.5005, 0.02, 0.02), DARK, 0.004)
	st.add(K.cut(pad, K.group(*[K.box(-1.29, -1.233, -0.072, 0.072, z, z + 0.014) for z in (-0.18, -0.10, -0.02, 0.06, 0.14, 0.22, 0.30, 0.38)]), GRIP))

	# ================================================================ Fasteners
	pins = part("Pins")
	for s in (1, -1):
		for x, z, w in ((1.40, 0.4, RW), (1.40, 0.2, RW), (0.65, 0.24, RW), (0.0, 0.24, RW), (2.42, 0.29, 0.074)):
			pins.add(B.head(x, z, w, r=0.015, segs=6, side=s))

	# ================================================================ Charm tab (under the shroud, left)
	ch = part("CharmLoop")
	tab = [(2.104, 0.225), (2.166, 0.225)] + [(2.135 + 0.031 * math.cos(-a), 0.13 + 0.031 * math.sin(-a)) for a in [i * math.pi / 6 for i in range(7)]]
	tb = K.bevel(K.prism(tab, "Y", RW - 0.001, RW + 0.013, METAL), 0.003, 1, 50)
	ch.add(K.cut(tb, K.cyl_y(2.135, 0.125, 0.012, 0.0, 0.3, 10, METAL), DARK))
	ch.add(B.head(2.12, 0.205, RW + 0.013, r=0.006, h=0.003))
	ch.add(B.head(2.15, 0.205, RW + 0.013, r=0.006, h=0.003))

	# ================================================================ Ammo box (AmmoBox bone) + feed belt (FeedBelt bone)
	ab = part("AmmoBox", "AmmoBox")
	box_b = B.solid(K.chamfer([(0.5775, -0.3675), (1.3125, -0.3675), (1.3125, 0.119), (0.5775, 0.119)], 0.03), K.section(BW, -0.3675, 0.119, 0.02, 0.02), PANEL, 0.004)
	box_b = K.cut(box_b, both(K.prism(K.chamfer([(0.65, -0.33), (1.24, -0.33), (1.24, 0.03), (0.65, 0.03)], 0.02), "Y", BW - 0.008, 0.3)), PANEL)
	ab.add(box_b)
	for (x0, z0), (x1, z1) in (((0.69, -0.30), (1.20, 0.0)), ((0.69, 0.0), (1.20, -0.30))):
		L = math.hypot(x1 - x0, z1 - z0)
		bar = K.box(0.0, L, BW - 0.009, BW - 0.002, -0.009, 0.009, PANEL)
		K.xform(bar, Matrix.Translation((x0, 0, z0)) @ Matrix.Rotation(-math.atan2(z1 - z0, x1 - x0), 4, "Y"))
		ab.add(both(bar))  # raised X
	ab.add(B.solid([(0.57, 0.065), (1.32, 0.065), (1.32, 0.122), (0.57, 0.122)], K.section(BW + 0.006, 0.06, 0.125, 0.008, 0.008), DARK, 0.003))  # lid band
	handle = K.prism(K.chamfer([(0.735, -0.06), (0.98, -0.06), (0.98, 0.02), (0.735, 0.02)], 0.012), "Y", BW, BW + 0.02, DARK)
	ab.add(K.cut(handle, K.box(0.76, 0.955, BW - 0.01, BW + 0.05, -0.04, 0.0), DARK), 0.002)
	ab.add(K.box(1.3125, 1.40, -0.035, 0.035, -0.05, 0.065, DARK), 0.004)  # front clip
	fb = part("FeedBelt", "FeedBelt")
	for z in ROUNDS:
		fb.add(K.loft_x([(0.84, K.circle(BELT_Y, z, 0.026, 8)), (1.0, K.circle(BELT_Y, z, 0.026, 8))], BRASS))  # v02: brass case
		fb.add(K.loft_x([(1.0, K.circle(BELT_Y, z, 0.021, 8)), (1.012, K.circle(BELT_Y, z, 0.021, 8)), (1.05, K.circle(BELT_Y, z, 0.007, 8))], METAL))  # bullet
		fb.add(K.cyl_x(1.0, 1.016, 0.022, BELT_Y, z, 8, ACCENT))  # bullet band
		fb.add(K.box(0.87, 0.94, BELT_Y - 0.03, BELT_Y - 0.022, z - 0.03, z + 0.03, DARK))  # link

	# ================================================================ Feed cover (hinged at its rear)
	cv = part("FeedCover", "FeedCover")
	cv.add(B.solid(K.chamfer([(0.7875, 0.486), (1.3825, 0.486), (1.3825, 0.56), (1.36, 0.581), (0.81, 0.581), (0.7875, 0.56)], 0.0), K.section(0.092, 0.486, 0.581, 0.022, 0.0), BODY, 0.003))
	cv.add(both(K.box(0.7875, 0.84, 0.084, 0.1, 0.49, 0.565, DARK)), 0.003)  # hinge ears
	cv.add(K.box(1.35, 1.385, -0.03, 0.03, 0.578, 0.592, ACCENT), 0.002)  # latch tab

	# ================================================================ Moving controls
	chg = part("ChargingHandle", "ChargingHandle")
	chg.add(K.box(0.13, 0.30, RW - 0.016, RW - 0.001, 0.31, 0.355, METAL))
	chg.add(K.box(0.16, 0.22, RW - 0.003, RW + 0.03, 0.315, 0.35, METAL), 0.003)
	chg.add(K.prism(K.chamfer([(0.145, 0.298), (0.235, 0.298), (0.24, 0.333), (0.235, 0.368), (0.155, 0.368), (0.145, 0.355)], 0.006), "Y", RW + 0.026, RW + 0.058, ACCENT), 0.003)
	bolt = part("Bolt", "Bolt")
	bolt.add(K.box(0.315, 0.63, -RW + 0.006, -RW + 0.03, 0.315, 0.378, METAL), 0.003)
	tg = part("Trigger", "Trigger")
	tp = [(0.29, 0.17), (0.322, 0.17), (0.325, 0.14), (0.32, 0.12), (0.308, 0.102), (0.292, 0.088), (0.285, 0.094), (0.297, 0.112), (0.303, 0.128), (0.301, 0.148), (0.29, 0.156)]
	tg.add(K.prism(tp, "Y", -0.011, 0.011, METAL), 0.002)
	return parts


CHARM = (2.135, RW + 0.006, 0.125)
BONES = [
	("Root", None, (0.0, 0.0, 0.1)),
	("AmmoBox", "Root", (0.945, 0.0, 0.119)),
	("FeedBelt", "AmmoBox", (0.917, BELT_Y, 0.3955)),
	("FeedCover", "Root", (0.805, 0.0, 0.56)),
	("ChargingHandle", "Root", (0.0105, 0.0, 0.3325)),
	("Bolt", "Root", (0.4725, 0.0, 0.3465)),
	("Trigger", "Root", (0.308, 0.0, 0.154)),
	("Flash", "Root", (MUZZLE_X + 0.01, 0.0, BORE)),
	("Charm", "Root", CHARM),
]
LOCATORS = [
	("Muzzle", "Root", (MUZZLE_X, 0.0, BORE), None),
	("RightGrip", "Root", (0.0, 0.0, 0.0), None),
	("LeftGrip", "Root", (1.715, 0.0, 0.154), None),
	("AimPoint", "Root", (AIM_X, 0.0, SIGHT_Z), AIM_ROT),
	("Eject", "Root", (0.4725, -0.096, 0.3465), EJECT_ROT),
	("BeltFeedPoint", "FeedBelt", (0.917, BELT_Y, 0.42), None),
	("CharmPoint", "Charm", CHARM, None),
	("Socket_Muzzle", "Root", (MUZZLE_X, 0.0, BORE), None),
	("Socket_Optic", "Root", (0.35, 0.0, 0.6), None),
	("Socket_Under", "Root", (1.72, 0.0, 0.1575), None),
]

RESULT = B.assemble(GUN, build_parts, BONES, LOCATORS, {"class": "Heavy", "tier": "T4"})
