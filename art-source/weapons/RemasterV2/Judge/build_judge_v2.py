# build_judge_v2.py: RemasterV2 Judge (compact automatic drum-fed shotgun, no ADS), fresh rebuild from
# vault/02 Art/References/Gun-Image-Concepts/Compact Drum-Fed Shotgun Concept Sheet-3.png. Blender MCP only.
# Contract measured on the original Judge.blend (REF_Judge_Original): Muzzle 2.1173, buttpad -1.02, bore z 0.5022,
# LeftGrip (1.5903, 0, 0.2418); bones Root/Mag/ChargingHandle/Bolt/Trigger/FireSelector/Flash/Charm (original heads,
# Charm moved). Top cocking slide = ChargingHandle (racks -0.17); the drum is the Mag bone (one detachable assembly).
# Changes: the drum now turns its round face to the side like the concept (the original ran its axis along the
# barrel, which read as a box); thicker receiver (0.1 -> 0.104) with the concept's angled side wing and neon
# trapezoid; lower with a real guard opening and trigger clearance (the original tip went 0.012 below the floor);
# drum with rims, lugs, hub and a feed tower into a lipped well; slotted handguard with a lower rail; heavy muzzle
# collar; tall front post with a neon insert, rear notch with dots; skeleton stock; hanging charm tab.

import bpy, math, sys, importlib
from mathutils import Matrix, Vector

ROOT = r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/art-source/weapons/RemasterV2"
sys.path.insert(0, ROOT + "/_Library")
import v2kit as K  # noqa: E402
import v2build as B  # noqa: E402
import ammo as AM  # noqa: E402

importlib.reload(K)
importlib.reload(B)
importlib.reload(AM)
from v2kit import BODY, PANEL, DARK, METAL, GRIP, ACCENT, NEON  # noqa: E402

GUN = "Judge"
BORE = 0.5022
MUZZLE_X = 2.1173
RW = 0.104
DX, DZ, DR, DW = 0.84, 0.0, 0.30, 0.14  # v03: wider drum (concept)  # drum centre x/z, radius, half width (axis along Y)
EJECT_ROT = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0))).to_4x4()


def build_parts():
	parts = {}

	def part(name, bone="Root"):
		parts[name] = K.Part(name, bone)
		return parts[name]

	both = B.both
	neon = part("Neon")

	# ================================================================ Receiver (bulky, angular) + lower with guard
	rec = part("Receiver")
	body = B.solid([(1.262, 0.574), (1.231, 0.614), (0.164, 0.614), (0.133, 0.592), (-0.167, 0.564), (-0.167, 0.338), (-0.083, 0.326), (0.617, 0.332), (0.66, 0.30), (0.846, 0.248), (1.262, 0.248)], K.section(RW, 0.24, 0.614, 0.03, 0.016), BODY, 0.003)
	body = K.cut(body, K.group(
		K.prism(K.chamfer([(0.35, 0.434), (0.66, 0.434), (0.66, 0.527), (0.35, 0.527)], 0.012), "Y", -0.2, -RW + 0.024),  # port (right)
		both(K.prism([(1.094, 0.586), (0.195, 0.586), (0.04, 0.394), (0.97, 0.394)], "Y", RW - 0.006, 0.2)),  # the concept's angled side wing (recess)
		both(K.prism([(0.0496, 0.415), (-0.0713, 0.415), (-0.0465, 0.375), (0.0248, 0.375)], "Y", RW - 0.005, 0.2)),  # neon trapezoid pocket
	), DARK)
	for f in body.faces:
		c = f.calc_center_median()
		if abs(abs(c.y) - (RW - 0.006)) < 1e-4 and 0.394 <= c.z <= 0.586:
			f.material_index = PANEL
	rec.add(body)
	neon.add(both(K.prism([(0.046, 0.412), (-0.068, 0.412), (-0.045, 0.378), (0.023, 0.378)], "Y", RW - 0.0045, RW - 0.0015, NEON)))
	lower = B.solid([(0.642, 0.384), (-0.13, 0.384), (-0.13, 0.272), (-0.077, 0.229), (0.202, 0.229), (0.202, 0.108), (0.233, 0.087), (0.443, 0.087), (0.474, 0.124), (0.55, 0.229), (0.642, 0.30)], K.section(0.09, 0.08, 0.384, 0.006, 0.016), BODY, 0.003)
	lower = K.cut(lower, K.group(
		K.prism(K.chamfer([(0.233, 0.25), (0.425, 0.25), (0.425, 0.145), (0.40, 0.118), (0.233, 0.118)], [0, 0, 0.01, 0.0, 0.0]), "Y", -0.2, 0.2),
		K.prism([(0.79, 0.40), (0.89, 0.40), (0.89, 0.20), (0.79, 0.20)], "Y", -0.05, 0.05),  # feed opening
	), DARK)
	rec.add(lower)
	well = B.solid(K.chamfer([(0.76, 0.26), (0.92, 0.26), (0.925, 0.225), (0.755, 0.225)], [0, 0, 0.008, 0.008]), K.section(0.07, 0.22, 0.26, 0.0, 0.008), BODY, 0.003)
	rec.add(K.cut(well, K.prism([(0.79, 0.40), (0.89, 0.40), (0.89, 0.10), (0.79, 0.10)], "Y", -0.054, 0.054), DARK))
	rec.add(B.solid(K.chamfer([(-0.183, 0.372), (-0.087, 0.372), (-0.087, 0.614), (-0.183, 0.614)], 0.014), K.section(0.09, 0.372, 0.614, 0.016, 0.016), PANEL, 0.003))  # stock adapter
	rec.add(K.box(0.133, 1.9, -0.034, 0.034, 0.61, 0.632, DARK), 0.003)  # top rib
	rec.add(K.prism(K.chamfer([(0.335, 0.44), (0.365, 0.44), (0.365, 0.52), (0.335, 0.52)], [0.008, 0, 0, 0.008]), "Y", -RW - 0.012, -RW + 0.004, BODY), 0.003)

	# ================================================================ Barrel + collar
	bar = part("Barrel")
	bar.add(K.drop(K.cyl_x(1.24, 1.96, 0.077, 0.0, BORE, 16, METAL), 0, -1))
	collar = K.bevel(K.cyl_x(1.95, MUZZLE_X, 0.086, 0.0, BORE, 16, METAL), 0.01, 1, 25)
	bar.add(K.cut(collar, K.cyl_x(MUZZLE_X - 0.1, MUZZLE_X + 0.05, 0.052, 0.0, BORE, 12, DARK), DARK))
	bar.add(K.annulus_x(1.995, 2.01, 0.0, BORE, 0.09, 0.08, 16, METAL))

	# ================================================================ Handguard (slots, lower rail)
	hg = part("Handguard")
	body = B.solid(K.chamfer([(1.259, 0.242), (1.925, 0.242), (1.925, 0.471), (1.259, 0.471)], [0, 0.02, 0.012, 0]), K.section(0.11, 0.242, 0.471, 0.012, 0.034), BODY, 0.003)
	slots = K.group(*[K.prism(K.stadium(x0, x1, 0.38, 0.044, 2), "Y", 0.088, 0.2) for x0, x1 in ((1.40, 1.55), (1.59, 1.74), (1.78, 1.88))])
	hg.add(K.cut(body, both(slots), DARK))
	hg.add(K.box(1.35, 1.85, -0.034, 0.034, 0.218, 0.244, DARK), 0.003)
	t = K.Part("_t")
	for x in [1.37 + 0.06 * i for i in range(8)]:
		t.add(K.drop(K.box(x, x + 0.028, -0.034, 0.034, 0.205, 0.219, DARK), 2, 1))
	hg.add(t.merged())

	# ================================================================ Sights (no ADS: shooting reference)
	si = part("Sights")
	si.add(K.prism([(1.80, 0.628), (1.925, 0.628), (1.915, 0.67), (1.89, 0.704), (1.83, 0.704), (1.80, 0.67)], "Y", -0.03, 0.03, DARK), 0.004)  # top level with the rear notch floor
	neon.add(K.prism([(1.8052, 0.6744), (1.8262, 0.6982), (1.8244, 0.6999), (1.8034, 0.6761)], "Y", -0.014, 0.014, NEON))  # v03: lies on the post's sloped rear face
	rear = K.bevel(K.prism([(0.167, 0.628), (0.329, 0.628), (0.31, 0.71), (0.19, 0.71)], "Y", -0.04, 0.04, DARK), 0.004, 1, 50)
	si.add(K.cut(rear, K.box(0.1, 0.4, -0.013, 0.013, 0.682, 0.8), DARK))
	neon.add(both(K.box(0.1843, 0.1866, 0.021, 0.031, 0.69, 0.70, NEON)))  # v03: set into the sloped rear face

	# ================================================================ Grip
	gr = part("Grip")
	gp = [(0.186, 0.248), (-0.077, 0.254), (-0.114, 0.217), (-0.226, -0.186), (-0.246, -0.262), (-0.236, -0.30), (0.062, -0.312), (0.074, -0.27), (0.058, -0.235), (0.074, -0.196), (0.058, -0.158), (0.072, -0.118), (0.115, 0.009), (0.165, 0.112)]  # v03: finger grooves, base flare
	grip = K.bevel(K.prism(gp, "Y", -0.064, 0.064, DARK), 0.014, 1)
	gr.add(K.cut(grip, both(K.prism(K.chamfer([(0.11, 0.12), (-0.07, 0.14), (-0.18, -0.20), (0.02, -0.23)], 0.02), "Y", 0.06, 0.2)), GRIP))

	# ================================================================ Stock
	st = part("Stock")
	sbody = B.solid(K.chamfer([(-0.167, 0.567), (-0.905, 0.567), (-0.905, -0.087), (-0.858, -0.096), (-0.579, 0.155), (-0.223, 0.335), (-0.167, 0.335)], [0, 0.014, 0, 0.0, 0, 0, 0]), K.section(0.074, -0.1, 0.567, 0.022, 0.016), BODY, 0.004)
	st.add(K.cut(sbody, K.prism(K.chamfer([(-0.61, 0.33), (-0.858, 0.33), (-0.858, 0.072)], 0.02), "Y", -0.2, 0.2), DARK))
	pad = B.solid(K.chamfer([(-0.89, 0.58), (-1.02, 0.58), (-1.02, -0.108), (-0.89, -0.108)], [0, 0.024, 0.024, 0]), K.section(0.084, -0.108, 0.58, 0.018, 0.018), DARK, 0.004)
	st.add(K.cut(pad, K.group(*[K.box(-1.06, -1.01, -0.075, 0.075, z, z + 0.012) for z in (-0.06, 0.02, 0.10, 0.18, 0.26, 0.34, 0.42, 0.50)]), GRIP))

	# ================================================================ Fasteners
	pins = part("Pins")
	for s in (1, -1):
		for x, z, w in ((1.20, 0.30, RW), (0.36, 0.31, 0.09), (-0.24, 0.47, 0.074), (-0.80, 0.0, 0.074)):
			pins.add(B.head(x, z, w, r=0.013, segs=8, side=s))

	# ================================================================ Charm tab (hangs under the receiver's front, left)
	ch = part("CharmLoop")
	tab = [(1.17, 0.29), (1.234, 0.29)] + [(1.202 + 0.032 * math.cos(-a), 0.215 + 0.032 * math.sin(-a)) for a in [i * math.pi / 6 for i in range(7)]]
	tb = K.bevel(K.prism(tab, "Y", RW - 0.001, RW + 0.013, METAL), 0.003, 1, 50)
	ch.add(K.cut(tb, K.cyl_y(1.202, 0.21, 0.013, 0.0, 0.3, 10, METAL), DARK))
	ch.add(B.head(1.187, 0.273, RW + 0.013, r=0.007, h=0.003))
	ch.add(B.head(1.217, 0.273, RW + 0.013, r=0.007, h=0.003))

	# ================================================================ Moving parts
	mg = part("Mag", "Mag")
	# v03 drum (concept): one dark body; each face a raised outer rim band, a recessed field split by three radial
	# ribs, and a metal hub with a winding knob; six chunky clips bridge the faces round the rim.
	drum = K.cyl_y(DX, DZ, DR, -DW, DW, 24, DARK, rot=0.0)
	drum = K.cut(drum, K.group(K.cyl_y(DX, DZ, DR - 0.04, DW - 0.012, DW + 0.1, 24, DARK, rot=0.0), K.cyl_y(DX, DZ, DR - 0.04, -DW - 0.1, -DW + 0.012, 24, DARK, rot=0.0)), DARK)
	mg.add(drum, 0.008, 1, 30)
	for s in (1, -1):
		yf = s * (DW - 0.012)
		y0, y1 = sorted((yf, yf + s * 0.01))
		for i in range(3):
			a = math.radians(90 + 120 * i)
			bm = K.box(0.06, DR - 0.045, y0, y1, -0.017, 0.017, DARK)  # radial rib on the recessed face
			K.xform(bm, Matrix.Translation((DX, 0.0, DZ)) @ Matrix.Rotation(-a, 4, "Y"))
			mg.add(bm, 0.002)
		mg.add(K.drop(K.cyl_y(DX, DZ, 0.07, min(yf, yf + s * 0.016), max(yf, yf + s * 0.016), 12, METAL), 1, -s), 0.003)  # hub
		mg.add(K.drop(K.cyl_y(DX, DZ, 0.03, min(yf, yf + s * 0.04), max(yf, yf + s * 0.04), 8, DARK), 1, -s), 0.003)  # winding knob
	for i in range(6):  # chunky clips round the rim, bridging both faces
		a = math.radians(30 + 60 * i)
		lug = K.box(-0.048, 0.048, -DW - 0.006, DW + 0.006, -0.006, 0.014, DARK)
		K.xform(lug, Matrix.Translation((DX + DR * math.cos(a), 0.0, DZ + DR * math.sin(a))) @ Matrix.Rotation(-a + math.pi / 2, 4, "Y"))
		mg.add(lug, 0.004)
	mg.add(B.solid([(0.795, 0.27), (0.885, 0.27), (0.885, 0.24), (0.905, 0.22), (0.905, 0.16), (0.775, 0.16), (0.775, 0.22), (0.795, 0.24)], K.section(0.05, 0.15, 0.28, 0.0, 0.0), DARK, 0.003))  # feed tower
	mg.add(AM.shotgun_shell(0.765, 0.0, 0.272, scale=0.88, length=0.19))  # v02: top shell on the feed tower

	chh = part("ChargingHandle", "ChargingHandle")
	slide = K.prism(K.chamfer([(0.642, 0.632), (1.094, 0.632), (1.094, 0.676), (0.656, 0.676)], 0.008), "Y", -0.05, 0.05, METAL)
	chh.add(K.cut(slide, both(K.group(*[K.box(x, x + 0.012, 0.044, 0.07, 0.636, 0.68) for x in (0.68, 0.71, 0.74, 0.77, 0.80)])), DARK))
	chh.add(K.prism(K.chamfer([(0.636, 0.66), (0.70, 0.66), (0.692, 0.70), (0.644, 0.70)], [0, 0, 0.008, 0.008]), "Y", 0.036, 0.074, ACCENT), 0.004)  # knob on the slide's left edge, clear of the sight line

	bolt = part("Bolt", "Bolt")
	bolt.add(K.box(0.357, 0.654, -RW + 0.004, -RW + 0.028, 0.44, 0.52, METAL), 0.003)

	tg = part("Trigger", "Trigger")
	tp = [(0.292, 0.262), (0.324, 0.262), (0.33, 0.21), (0.325, 0.19), (0.312, 0.172), (0.295, 0.158), (0.288, 0.164), (0.3, 0.182), (0.307, 0.2), (0.305, 0.222), (0.292, 0.232)]
	tg.add(K.prism(tp, "Y", -0.012, 0.012, METAL), 0.002)

	sel = part("FireSelector", "FireSelector")
	sel.add(K.drop(K.cyl_y(0.1767, 0.3162, 0.02, 0.088, 0.098, 8, METAL), 1, -1), 0.002)
	sel.add(K.prism(K.chamfer([(0.13, 0.302), (0.214, 0.305), (0.214, 0.327), (0.13, 0.33)], 0.006), "Y", 0.094, 0.104, ACCENT))
	return parts


CHARM = (1.202, RW + 0.006, 0.21)
BONES = [
	("Root", None, (0.0, 0.0, 0.15)),
	("Mag", "Root", (0.8401, 0.0, 0.279)),
	("ChargingHandle", "Root", (0.6603, 0.0, 0.682)),
	("Bolt", "Root", (0.5053, -0.0812, 0.4805)),
	("Trigger", "Root", (0.3131, 0.0, 0.2356)),
	("FireSelector", "Root", (0.1767, 0.1125, 0.3162)),
	("Flash", "Root", (MUZZLE_X + 0.01, 0.0, BORE)),
	("Charm", "Root", CHARM),
]
LOCATORS = [
	("Muzzle", "Root", (MUZZLE_X, 0.0, BORE), None),
	("RightGrip", "Root", (0.0, 0.0, 0.0), None),
	("LeftGrip", "Root", (1.5903, 0.0, 0.2418), None),
	("Eject", "Root", (0.5053, -0.1, 0.4805), EJECT_ROT),
	("CharmPoint", "Charm", CHARM, None),
	("Socket_Muzzle", "Root", (MUZZLE_X, 0.0, BORE), None),
	("Socket_Optic", "Root", (1.3, 0.0, 0.632), None),
	("Socket_Under", "Root", (1.6, 0.0, 0.205), None),
]

RESULT = B.assemble(GUN, build_parts, BONES, LOCATORS, {"class": "Shotgun", "tier": "T2"})
