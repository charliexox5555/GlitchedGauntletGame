# build_spectre_v2.py: RemasterV2 Spectre (refined suppressed compact SMG), fresh rebuild from
# vault/02 Art/References/Gun-Image-Concepts/Compact suppressed SMG concept sheet-5.png. Blender MCP only.
# Contract measured on the original Spectre.blend (REF_Spectre_Original): Muzzle 1.9012, buttpad -1.0668, bore z
# 0.3528, AimPoint (-0.0532, 0, 0.5236), front post x 1.0164, LeftGrip (0.9212, 0, 0.2296); bones Root/Mag/
# ChargingHandle/Bolt/Trigger/FireSelector/Flash/Charm (original heads, Charm moved). HK-style loop handle at the
# front of the left slot, racks -0.16.
# Changes: thicker upper (0.072 -> 0.082), lower (0.067 -> 0.078), handguard (0.084 -> 0.09), grip, curved mag
# (0.05 -> 0.056); octagonal handguard with long slots; magwell with cavity and flared mouth; loop handle in its
# slot; port + bolt; skeleton stock with ribbed pad; suppressor with hex nut, seam band and closed cap; open ring
# + hooded post with the concept's neon square; hanging charm tab; trigger clearance (original tip sat on the guard).

import bpy, math, sys, importlib
from mathutils import Matrix, Vector

ROOT = r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/art-source/weapons/RemasterV2"
sys.path.insert(0, ROOT + "/_Library")
import v2kit as K  # noqa: E402
import ammo as AM  # noqa: E402
import v2build as B  # noqa: E402
import sights as SI  # noqa: E402

importlib.reload(K)
importlib.reload(AM)
importlib.reload(B)
importlib.reload(SI)
from v2kit import BODY, PANEL, DARK, METAL, GRIP, ACCENT, NEON  # noqa: E402

GUN = "Spectre"
BORE = 0.3528
SIGHT_Z = 0.5236
AIM_X = -0.0532
FRONT_X = 1.0164
MUZZLE_X = 1.9012
UW, LW = 0.082, 0.078
AIM_ROT = Matrix(((0, 0, 1), (0, 1, 0), (-1, 0, 0))).to_4x4()
EJECT_ROT = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0))).to_4x4()
MAG = [(0.624, 0.10), (0.44, 0.10), (0.454, 0.0084), (0.535, -0.25), (0.60, -0.45), (0.628, -0.515), (0.828, -0.545), (0.848, -0.505), (0.80, -0.32), (0.742, -0.15), (0.669, 0.0084)]  # v03: long curved SMG mag (concept)


def build_parts():
	parts = {}

	def part(name, bone="Root"):
		parts[name] = K.Part(name, bone)
		return parts[name]

	both = B.both
	neon = part("Neon")

	# ================================================================ Receiver
	rec = part("Receiver")
	upper = B.solid([(0.697, 0.274), (0.697, 0.42), (0.675, 0.442), (-0.33, 0.442), (-0.33, 0.244), (-0.185, 0.244), (-0.185, 0.274)], K.section(UW, 0.244, 0.442, 0.024, 0.0), BODY, 0.003)
	upper = K.cut(upper, K.group(
		# v03 panel lines: two vertical seams on both sides of the upper.
		both(K.box(0.556, 0.564, UW - 0.004, 0.2, 0.26, 0.35)),
		both(K.box(-0.254, -0.246, UW - 0.004, 0.2, 0.26, 0.42)),
		K.prism(K.chamfer([(0.16, 0.374), (0.70, 0.374), (0.70, 0.404), (0.16, 0.404)], 0.006), "Y", UW - 0.014, 0.2),  # handle slot (left)
		K.prism(K.chamfer([(0.249, 0.358), (0.473, 0.358), (0.473, 0.428), (0.249, 0.428)], 0.012), "Y", -0.2, -UW + 0.02),  # port
		K.box(-0.165, -0.092, UW - 0.005, 0.2, 0.288, 0.325),  # neon pocket (left)
	), DARK)
	rec.add(upper)
	neon.add(K.box(-0.162, -0.095, UW - 0.0045, UW - 0.0015, 0.291, 0.322, NEON))
	lower = B.solid([(0.683, 0.274), (-0.185, 0.274), (-0.185, 0.131), (0.132, 0.131), (0.132, -0.0056), (0.375, -0.0056), (0.434, 0.037), (0.434, 0.0616), (0.63, 0.0616), (0.683, 0.162)], K.section(LW, -0.02, 0.274, 0.006, 0.014), BODY, 0.003)
	lower = K.cut(lower, K.group(
		K.prism(K.chamfer([(0.154, 0.15), (0.375, 0.15), (0.375, 0.05), (0.35, 0.025), (0.154, 0.025)], [0, 0, 0.01, 0.0, 0.006]), "Y", -0.2, 0.2),  # guard opening
		K.prism([(0.635, 0.2), (0.43, 0.2), (0.443, -0.05), (0.672, -0.05)], "Y", -0.06, 0.06),  # magwell cavity
	), DARK)
	rec.add(lower)
	lip = B.solid(K.chamfer([(0.428, 0.074), (0.684, 0.074), (0.69, 0.045), (0.432, 0.045)], [0, 0, 0.008, 0.008]), [(-0.072, 0.08), (-0.072, 0.058), (-0.076, 0.052), (-0.076, 0.045), (0.076, 0.045), (0.076, 0.052), (0.072, 0.058), (0.072, 0.08)], BODY, 0.003)
	rec.add(K.cut(lip, K.prism([(0.635, 0.2), (0.43, 0.2), (0.447, -0.05), (0.676, -0.05)], "Y", -0.06, 0.06), DARK))
	rec.add(K.box(-0.171, 0.753, -0.032, 0.032, 0.44, 0.458, DARK), 0.003)  # rail base
	t = K.Part("_t")
	x = -0.15
	while x + 0.024 < 0.74:
		if not (-0.12 < x < 0.03):
			t.add(K.drop(K.box(x, x + 0.024, -0.032, 0.032, 0.457, 0.468, DARK), 2, -1))
		x += 0.065
	rec.add(t.merged())
	rec.add(K.prism(K.chamfer([(0.39, 0.17), (0.43, 0.17), (0.43, 0.262), (0.39, 0.262)], 0.006), "Y", -LW - 0.01, -LW + 0.002, ACCENT), 0.002)  # mag release (right)
	rec.add(K.prism(K.chamfer([(0.232, 0.36), (0.256, 0.36), (0.256, 0.43), (0.232, 0.43)], [0.006, 0, 0, 0.006]), "Y", -UW - 0.012, -UW + 0.004, BODY), 0.003)  # deflector

	# ================================================================ Handguard (octagonal, long slots)
	hg = part("Handguard")
	body = B.solid(K.chamfer([(0.697, 0.23), (1.14, 0.23), (1.14, 0.473), (0.697, 0.473)], [0, 0.016, 0.016, 0]), K.section(0.09, 0.23, 0.473, 0.03, 0.03), BODY, 0.003)
	slots = K.group(*[K.prism(K.stadium(0.76, 1.06, z, 0.026, 2), "Y", 0.07, 0.2) for z in (0.40, 0.30)])
	hg.add(K.cut(body, both(slots), DARK))

	# ================================================================ Suppressor on a hex nut
	sp = part("Suppressor")
	can = K.bevel(K.cyl_x(1.257, MUZZLE_X, 0.092, 0.0, BORE, 20, DARK), 0.014, 1, 25)
	sp.add(K.cut(can, K.cyl_x(MUZZLE_X - 0.08, MUZZLE_X + 0.05, 0.024, 0.0, BORE, 10, DARK), DARK))
	sp.add(K.drop(K.annulus_x(MUZZLE_X - 0.002, MUZZLE_X + 0.003, 0.0, BORE, 0.056, 0.024, 14, PANEL), 0, -1))
	sp.add(K.annulus_x(1.35, 1.362, 0.0, BORE, 0.095, 0.085, 20, METAL))  # seam band
	sp.add(K.cyl_x(1.137, 1.262, 0.068, 0.0, BORE, 6, METAL, rot=0.0), 0.006)  # hex nut

	# ================================================================ Sights
	si = part("Sights")
	si.add(B.solid(K.chamfer([(-0.12, 0.456), (0.02, 0.456), (0.02, 0.476), (-0.12, 0.476)], [0, 0, 0.008, 0.008]), K.section(0.044, 0.456, 0.476, 0.008, 0.0), DARK, 0.002))
	# v02 sight picture (Spectre's own): HK-style rotary drum diopter; round hood over the front post.
	for pc in SI.drum(AIM_X, SIGHT_Z, 0.474, r=0.04, hw=0.04, hole=0.018):
		si.add(pc)
	neon.add(both(K.box(1.0, 1.033, 0.0395, 0.0415, 0.472, 0.484, NEON)))  # the concept's neon squares, on the front base
	si.add(B.solid(K.chamfer([(0.969, 0.468), (1.064, 0.468), (1.064, 0.49), (0.969, 0.49)], 0.0), K.section(0.04, 0.468, 0.49, 0.006, 0.0), DARK, 0.002))
	si.add(K.annulus_x(FRONT_X - 0.014, FRONT_X + 0.014, 0.0, SIGHT_Z, 0.046, 0.035, 12, DARK))
	si.add(K.prism([(-0.005, 0.486), (0.005, 0.486), (0.005, 0.506), (0.0014, SIGHT_Z), (-0.0014, SIGHT_Z), (-0.005, 0.506)], "X", FRONT_X - 0.005, FRONT_X + 0.005, METAL))

	# ================================================================ Grip
	gr = part("Grip")
	gp = [(0.132, 0.134), (-0.044, 0.142), (-0.199, -0.246), (-0.188, -0.268), (-0.017, -0.28), (0.0, -0.258)]
	grip = K.bevel(K.prism(gp, "Y", -0.06, 0.06, DARK), 0.013, 1)
	gr.add(K.cut(grip, both(K.prism(K.chamfer([(0.088, 0.08), (-0.04, 0.09), (-0.15, -0.22), (-0.03, -0.235)], 0.02), "Y", 0.056, 0.2)), GRIP))

	# ================================================================ Stock
	st = part("Stock")
	st.add(K.drop(K.cyl_x(-0.43, -0.322, 0.075, 0.0, 0.33, 12, DARK), 0, 1), 0.005)
	sbody = B.solid(K.chamfer([(-0.42, 0.395), (-0.969, 0.395), (-0.969, -0.118), (-0.927, -0.118), (-0.591, 0.12), (-0.42, 0.238)], [0.012, 0.012, 0, 0.0, 0, 0]), K.section(0.066, -0.13, 0.395, 0.02, 0.016), BODY, 0.004)
	st.add(K.cut(sbody, K.prism(K.chamfer([(-0.585, 0.28), (-0.885, 0.28), (-0.885, -0.016), (-0.865, -0.03)], 0.016), "Y", -0.2, 0.2), DARK))
	pad = B.solid(K.chamfer([(-0.955, 0.40), (-1.067, 0.40), (-1.067, -0.118), (-0.955, -0.118)], [0, 0.02, 0.02, 0]), K.section(0.074, -0.118, 0.40, 0.016, 0.016), DARK, 0.004)
	st.add(K.cut(pad, K.group(*[K.box(-1.11, -1.058, -0.07, 0.07, z, z + 0.01) for z in (-0.08, -0.02, 0.04, 0.10, 0.16, 0.22, 0.28, 0.34)]), GRIP))

	# ================================================================ Fasteners
	pins = part("Pins")
	for s in (1, -1):
		for x, z in ((0.645, 0.25), (0.10, 0.175), (-0.05, 0.22)):
			pins.add(B.head(x, z, LW, r=0.009, segs=8, side=s))

	# ================================================================ Charm tab (under the lower's front, left)
	ch = part("CharmLoop")
	tab = [(0.63, 0.19), (0.692, 0.19)] + [(0.661 + 0.031 * math.cos(-a), 0.13 + 0.031 * math.sin(-a)) for a in [i * math.pi / 6 for i in range(7)]]
	tb = K.bevel(K.prism(tab, "Y", LW - 0.001, LW + 0.013, METAL), 0.003, 1, 50)
	ch.add(K.cut(tb, K.cyl_y(0.661, 0.125, 0.012, 0.0, 0.2, 10, METAL), DARK))
	ch.add(B.head(0.647, 0.174, LW + 0.013, r=0.006, h=0.003))
	ch.add(B.head(0.675, 0.174, LW + 0.013, r=0.006, h=0.003))

	# ================================================================ Moving parts
	mg = part("Mag", "Mag")
	mb = K.bevel(K.prism(MAG, "Y", -0.056, 0.056, DARK), 0.01)
	mg.add(AM.pistol_round(0.47, 0.006, 0.114, scale=1.3))  # v02: top round (seen with the mag out)
	mg.add(K.cut(mb, both(K.prism(K.chamfer([(0.49, -0.02), (0.64, -0.02), (0.755, -0.42), (0.625, -0.42)], 0.012), "Y", 0.052, 0.2)), DARK))
	mg.add(B.solid(K.chamfer([(0.622, -0.505), (0.842, -0.536), (0.838, -0.568), (0.618, -0.537)], 0.006), K.section(0.062, -0.58, -0.495, 0.006, 0.01), PANEL, 0.002))  # v03: base plate at the new length

	chh = part("ChargingHandle", "ChargingHandle")
	chh.add(K.box(0.60, 0.70, UW - 0.012, UW + 0.002, 0.377, 0.401, METAL))
	loop = K.prism(K.chamfer([(0.624, 0.32), (0.689, 0.32), (0.689, 0.398), (0.624, 0.398)], 0.012), "Y", UW + 0.0, UW + 0.02, ACCENT)
	chh.add(K.cut(loop, K.prism(K.chamfer([(0.638, 0.334), (0.675, 0.334), (0.675, 0.384), (0.638, 0.384)], 0.008), "Y", 0.0, 0.2), ACCENT))

	bolt = part("Bolt", "Bolt")
	bolt.add(K.box(0.255, 0.468, -UW + 0.004, -UW + 0.024, 0.364, 0.423, METAL), 0.002)

	tg = part("Trigger", "Trigger")
	tp = [(0.207, 0.162), (0.238, 0.162), (0.244, 0.108), (0.24, 0.088), (0.229, 0.07), (0.212, 0.058), (0.205, 0.064), (0.218, 0.08), (0.224, 0.096), (0.222, 0.114), (0.208, 0.122)]
	tg.add(K.prism(tp, "Y", -0.011, 0.011, METAL), 0.002)

	sel = part("FireSelector", "FireSelector")
	sel.add(K.drop(K.cyl_y(0.2212, 0.2128, 0.018, LW - 0.002, LW + 0.008, 8, METAL), 1, -1), 0.002)
	sel.add(K.prism(K.chamfer([(0.14, 0.198), (0.232, 0.202), (0.232, 0.224), (0.14, 0.228)], 0.008), "Y", LW + 0.004, LW + 0.012, ACCENT))
	return parts


CHARM = (0.661, LW + 0.006, 0.125)
BONES = [
	("Root", None, (0.0, 0.0, 0.15)),
	("Mag", "Root", (0.532, 0.0, 0.0868)),
	("ChargingHandle", "Root", (0.658, 0.084, 0.322)),
	("Bolt", "Root", (0.3612, -0.06, 0.3948)),
	("Trigger", "Root", (0.2268, 0.0, 0.1232)),
	("FireSelector", "Root", (0.2212, 0.078, 0.2128)),
	("Flash", "Root", (MUZZLE_X + 0.01, 0.0, BORE)),
	("Charm", "Root", CHARM),
]
LOCATORS = [
	("Muzzle", "Root", (MUZZLE_X, 0.0, BORE), None),
	("RightGrip", "Root", (0.0, 0.0, 0.0), None),
	("LeftGrip", "Root", (0.9212, 0.0, 0.2296), None),
	("AimPoint", "Root", (AIM_X, 0.0, SIGHT_Z), AIM_ROT),
	("Eject", "Root", (0.3612, -0.072, 0.3948), EJECT_ROT),
	("CharmPoint", "Charm", CHARM, None),
	("Socket_Muzzle", "Root", (MUZZLE_X, 0.0, BORE), None),
	("Socket_Optic", "Root", (0.35, 0.0, 0.468), None),
	("Socket_Under", "Root", (0.92, 0.0, 0.23), None),
]

RESULT = B.assemble(GUN, build_parts, BONES, LOCATORS, {"class": "SMG", "tier": "T2"})
