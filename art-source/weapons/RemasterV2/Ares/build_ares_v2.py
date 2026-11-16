# build_ares_v2.py: RemasterV2 Ares (drum-fed light machine gun), fresh rebuild from
# vault/02 Art/References/Gun-Image-Concepts/ARES-inspired light machine gun concept sheet-14.png. Blender MCP only.
# Contract measured on the original Ares.blend (REF_Ares_Original): Muzzle 3.0752, buttpad -1.232, bore z 0.3712,
# AimPoint (0.1088, 0, 0.6392), front post x 2.1056, LeftGrip (1.6384, 0, 0.1856), drum axis along the barrel at z
# -0.08 (the Mag bone); bones Root/Mag/ChargingHandle/Bolt/FireSelector/Trigger/Flash/Charm (original heads, Charm
# moved). Left-side charging knob racks -0.18.
# Changes: thicker upper (0.091 -> 0.096), trunnion block, vented handguard (0.083 -> 0.092) with lower rail, drum with
# ribbed bands, rims, front face with hub and spokes, feed neck into a lipped well; port + bolt; neon capsules; flash
# hider; open ring on a tower + hooded post; skeleton stock; hanging charm tab; trigger clearance (original 0.003).

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
from v2kit import BODY, PANEL, DARK, METAL, GRIP, ACCENT, NEON  # noqa: E402

GUN = "Ares"
BORE = 0.3712
SIGHT_Z = 0.6392
AIM_X = 0.1088
FRONT_X = 2.1056
MUZZLE_X = 3.0752
RW, HW = 0.096, 0.092
DZ, DR = -0.08, 0.278
AIM_ROT = Matrix(((0, 0, 1), (0, 1, 0), (-1, 0, 0))).to_4x4()
EJECT_ROT = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0))).to_4x4()


def build_parts():
	parts = {}

	def part(name, bone="Root"):
		parts[name] = K.Part(name, bone)
		return parts[name]

	both = B.both
	neon = part("Neon")

	# ================================================================ Receiver
	rec = part("Receiver")
	upper = B.solid(K.chamfer([(-0.115, 0.2016), (1.19, 0.2016), (1.19, 0.4896), (-0.115, 0.4896)], [0, 0, 0.0, 0.0]), K.section(RW, 0.2016, 0.4896, 0.028, 0.0), BODY, 0.003)
	upper = K.cut(upper, K.group(
		K.prism(K.chamfer([(0.55, 0.252), (1.08, 0.252), (1.08, 0.306), (0.55, 0.306)], 0.008), "Y", RW - 0.018, 0.2),  # charging slot (left)
		K.prism(K.chamfer([(0.454, 0.336), (0.678, 0.336), (0.678, 0.41), (0.454, 0.41)], 0.012), "Y", -0.2, -RW + 0.024),  # port (right)
		K.group(K.prism(K.stadium(0.496, 0.646, 0.357, 0.03, 2), "Y", RW - 0.005, 0.2), K.prism(K.stadium(0.355, 0.496, 0.288, 0.034, 2), "Y", RW - 0.005, 0.2)),  # neon pockets, left only (port on the right)
		both(K.group(K.box(-0.09, 0.34, RW - 0.003, 0.2, 0.317, 0.325), K.box(0.07, 0.80, RW - 0.003, 0.2, 0.42, 0.428))),  # panel lines
	), DARK)
	rec.add(upper)
	neon.add(K.group(K.prism(K.stadium(0.499, 0.643, 0.357, 0.024, 2), "Y", RW - 0.0045, RW - 0.0015, NEON), K.prism(K.stadium(0.358, 0.493, 0.288, 0.028, 2), "Y", RW - 0.0045, RW - 0.0015, NEON)))
	rec.add(B.solid(K.chamfer([(0.87, 0.128), (1.142, 0.128), (1.142, 0.518), (0.87, 0.518)], 0.02), K.section(0.1, 0.128, 0.518, 0.026, 0.02), BODY, 0.003))  # trunnion block
	lower = B.solid([(0.982, 0.2176), (0.038, 0.2176), (0.038, 0.1376), (0.982, 0.1376)], K.section(0.08, 0.13, 0.22, 0.0, 0.014), BODY, 0.003)
	rec.add(K.cut(lower, K.prism([(0.62, 0.3), (0.93, 0.3), (0.93, 0.05), (0.62, 0.05)], "Y", -0.056, 0.056), DARK))
	rec.add(B.solid(K.chamfer([(-0.186, 0.2), (-0.106, 0.2), (-0.106, 0.49), (-0.186, 0.49)], 0.016), K.section(0.085, 0.2, 0.49, 0.016, 0.016), PANEL, 0.003))  # end plate
	guard = K.bevel(K.prism([(0.16, 0.144), (0.518, 0.144), (0.518, 0.06), (0.47, 0.0096), (0.19, 0.0096), (0.16, 0.04)], "Y", -0.03, 0.03, DARK), 0.006, 1, 30)
	rec.add(K.cut(guard, K.prism(K.chamfer([(0.192, 0.2), (0.486, 0.2), (0.486, 0.06), (0.46, 0.035), (0.192, 0.035)], [0, 0, 0.012, 0.0, 0.0]), "Y", -0.1, 0.1), DARK))
	rec.add(K.box(0.198, 1.99, -0.034, 0.034, 0.486, 0.51, DARK), 0.003)
	t = K.Part("_t")
	for x in [0.24 + 0.065 * i for i in range(27)]:
		if not (0.14 < x < 0.25):
			t.add(K.drop(K.box(x, x + 0.03, -0.036, 0.036, 0.509, 0.52, DARK), 2, -1))
	rec.add(t.merged())
	rec.add(K.prism(K.chamfer([(0.43, 0.338), (0.455, 0.338), (0.455, 0.408), (0.43, 0.408)], [0.006, 0, 0, 0.006]), "Y", -RW - 0.012, -RW + 0.004, BODY), 0.003)

	# ================================================================ Handguard (vented, lower rail, gas block)
	hg = part("Handguard")
	shell = B.solid(K.chamfer([(1.19, 0.2016), (2.006, 0.2016), (2.006, 0.48), (1.19, 0.48)], [0, 0.012, 0.012, 0]), K.section(HW, 0.2016, 0.48, 0.03, 0.03), BODY, 0.003)
	vents = K.group(*[K.prism(K.stadium(a, b, zc, h, 2), "Y", HW - 0.018, 0.2) for zc, h in ((0.42, 0.036), (0.33, 0.036), (0.245, 0.024)) for a, b in ((1.42, 1.56), (1.60, 1.75), (1.79, 1.94))])
	hg.add(K.cut(shell, both(vents), DARK))
	hg.add(B.solid(K.chamfer([(2.006, 0.21), (2.131, 0.21), (2.131, 0.48), (2.006, 0.48)], 0.016), K.section(0.07, 0.21, 0.48, 0.022, 0.022), PANEL, 0.003))  # front block
	hg.add(K.box(1.29, 1.81, -0.032, 0.032, 0.17, 0.203, DARK), 0.003)
	t2 = K.Part("_t2")
	for x in [1.31 + 0.06 * i for i in range(8)]:
		t2.add(K.drop(K.box(x, x + 0.028, -0.034, 0.034, 0.158, 0.171, DARK), 2, 1))
	hg.add(t2.merged())
	hg.add(B.solid(K.chamfer([(2.131, 0.31), (2.278, 0.31), (2.278, 0.48), (2.131, 0.48)], 0.014), K.section(0.054, 0.31, 0.48, 0.016, 0.016), DARK, 0.003))  # gas block

	# ================================================================ Barrel + hider
	br = part("Barrel")
	# v03: heavier LMG barrel (0.046 -> 0.056), bigger collar and brake (concept).
	br.add(K.drop(K.cyl_x(1.18, 2.72, 0.056, 0.0, BORE, 14, METAL), 0, 1))
	br.add(K.cyl_x(2.707, 2.79, 0.07, 0.0, BORE, 14, DARK), 0.005)
	hider = K.bevel(K.cyl_x(2.79, MUZZLE_X, 0.074, 0.0, BORE, 8, DARK, rot=math.pi / 8), 0.006)
	br.add(K.cut(hider, K.group(K.box(2.88, 2.98, -0.1, 0.1, BORE - 0.024, BORE + 0.024), K.box(2.88, 2.98, -0.024, 0.024, BORE - 0.1, BORE + 0.1), K.cyl_x(MUZZLE_X - 0.05, MUZZLE_X + 0.03, 0.032, 0.0, BORE, 10)), DARK))

	# ================================================================ Sights
	si = part("Sights")
	si.add(B.solid(K.chamfer([(-0.048, 0.508), (0.182, 0.508), (0.182, 0.566), (-0.048, 0.566)], [0, 0, 0.014, 0.014]), K.section(0.044, 0.508, 0.566, 0.012, 0.0), DARK, 0.003))
	# v02 sight picture (Ares's own, LMG): a U-notch leaf on the rear ramp; a wide open blade on the front tower.
	si.add(SI.notch_blade(AIM_X, SIGHT_Z, 0.564, hw=0.052, t=0.024, notch="u", nw=0.026, nd=0.036))
	si.add(SI.post(FRONT_X, SIGHT_Z, 0.588, w=0.009, t=0.016, tip=0.004))
	si.add(both(K.drop(K.cyl_y(0.16, 0.537, 0.017, 0.044, 0.058, 10, METAL), 1, -1)))
	si.add(B.solid([(FRONT_X - 0.05, 0.476), (FRONT_X + 0.05, 0.476), (FRONT_X + 0.026, 0.592), (FRONT_X - 0.026, 0.592)], [(-0.034, 0.476), (0.034, 0.476), (0.022, 0.592), (-0.022, 0.592)], DARK, 0.003))

	# ================================================================ Grip
	gr = part("Grip")
	gp = [(0.173, 0.147), (0.0, 0.186), (-0.198, -0.23), (-0.192, -0.275), (-0.023, -0.326), (0.003, -0.294), (0.026, -0.192), (0.08, -0.064), (0.141, 0.032)]
	grip = K.bevel(K.prism(gp, "Y", -0.064, 0.064, DARK), 0.014, 1)
	gr.add(K.cut(grip, both(K.prism(K.chamfer([(0.12, 0.09), (-0.01, 0.12), (-0.15, -0.20), (0.0, -0.25)], 0.02), "Y", 0.06, 0.2)), GRIP))

	# ================================================================ Stock
	st = part("Stock")
	st.add(B.solid(K.chamfer([(-0.384, 0.208), (-0.186, 0.208), (-0.186, 0.442), (-0.384, 0.442)], 0.014), K.section(0.058, 0.208, 0.442, 0.016, 0.016), DARK, 0.003))
	sbody = B.solid([(-0.378, 0.448), (-1.066, 0.47), (-1.082, 0.454), (-1.082, -0.144), (-0.992, -0.144), (-0.682, 0.16), (-0.474, 0.198), (-0.378, 0.198)], K.section(0.07, -0.15, 0.47, 0.022, 0.016), BODY, 0.004)
	sbody = K.cut(sbody, both(K.group(K.prism(K.stadium(-1.0, -0.78, 0.264, 0.045, 2), "Y", 0.064, 0.2), K.rot_y(K.prism(K.stadium(-1.04, -0.79, 0.01, 0.038, 2), "Y", 0.064, 0.2), math.radians(-32), (-0.915, 0, 0.01)))), DARK)
	st.add(sbody)
	pad = B.solid(K.chamfer([(-1.08, 0.48), (-1.232, 0.48), (-1.232, -0.151), (-1.08, -0.151)], [0, 0.024, 0.024, 0]), K.section(0.078, -0.151, 0.48, 0.018, 0.018), DARK, 0.004)
	st.add(K.cut(pad, K.group(*[K.box(-1.27, -1.222, -0.068, 0.068, z, z + 0.012) for z in (-0.10, -0.03, 0.04, 0.11, 0.18, 0.25, 0.32, 0.39)]), GRIP))

	# ================================================================ Fasteners
	pins = part("Pins")
	for s in (1, -1):
		for x, z in ((0.92, 0.47), (1.08, 0.47), (0.92, 0.17)):
			pins.add(B.head(x, z, 0.1, r=0.012, segs=8, side=s))
		pins.add(B.head(1.98, 0.38, HW, r=0.016, segs=10, side=s))

	# ================================================================ Charm tab (under the handguard's rear, left)
	ch = part("CharmLoop")
	tab = [(1.223, 0.23), (1.285, 0.23)] + [(1.254 + 0.031 * math.cos(-a), 0.16 + 0.031 * math.sin(-a)) for a in [i * math.pi / 6 for i in range(7)]]
	tb = K.bevel(K.prism(tab, "Y", HW - 0.001, HW + 0.013, METAL), 0.003, 1, 50)
	ch.add(K.cut(tb, K.cyl_y(1.254, 0.155, 0.012, 0.0, 0.3, 10, METAL), DARK))
	ch.add(B.head(1.24, 0.213, HW + 0.013, r=0.006, h=0.003))
	ch.add(B.head(1.268, 0.213, HW + 0.013, r=0.006, h=0.003))

	# ================================================================ Drum (Mag): axis along the barrel
	dm = part("Drum", "Mag")
	dm.add(K.bevel(K.cyl_x(0.563, 1.04, DR, 0.0, DZ, 16, DARK, rot=0.0), 0.012, 1, 25))
	for x0, x1 in ((0.60, 0.625), (0.72, 0.735), (0.845, 0.86), (0.965, 0.99)):
		dm.add(K.annulus_x(x0, x1, 0.0, DZ, DR + 0.01, DR - 0.01, 16, PANEL, rot=0.0))  # ribbed bands
	face = K.cyl_x(1.038, 1.05, 0.22, 0.0, DZ, 16, PANEL, rot=0.0)
	dm.add(K.cut(face, K.group(*[K.xform(K.box(1.0, 1.1, -0.012, 0.012, DZ + 0.09, DZ + 0.2), Matrix.Translation((0, 0, DZ)) @ Matrix.Rotation(math.radians(120 * i), 4, "X") @ Matrix.Translation((0, 0, -DZ))) for i in range(3)]), DARK))  # face plate with spoke grooves
	dm.add(K.cyl_x(1.045, 1.07, 0.07, 0.0, DZ, 12, METAL), 0.004)  # hub
	dm.add(B.solid([(0.62, 0.22), (0.928, 0.22), (0.928, 0.17), (0.94, 0.15), (0.94, 0.12), (0.608, 0.12), (0.608, 0.15), (0.62, 0.17)], K.section(0.052, 0.1, 0.23, 0.0, 0.0), DARK, 0.003))  # feed neck

	# ================================================================ Moving controls
	chh = part("ChargingHandle", "ChargingHandle")
	chh.add(K.box(0.76, 0.88, RW - 0.018, RW - 0.002, 0.258, 0.30, METAL))
	chh.add(K.box(0.79, 0.85, RW - 0.004, RW + 0.03, 0.262, 0.296, METAL), 0.003)
	chh.add(K.prism(K.chamfer([(0.77, 0.245), (0.87, 0.245), (0.876, 0.28), (0.87, 0.315), (0.78, 0.315), (0.77, 0.30)], 0.006), "Y", RW + 0.026, RW + 0.054, ACCENT), 0.003)
	bolt = part("Bolt", "Bolt")
	bolt.add(K.box(0.416, 0.71, -RW + 0.006, -RW + 0.028, 0.34, 0.405, METAL), 0.003)
	sel = part("FireSelector", "FireSelector")
	sel.add(K.drop(K.cyl_y(0.0864, 0.256, 0.018, RW - 0.003, RW + 0.007, 8, METAL), 1, -1), 0.002)
	sel.add(K.prism(K.chamfer([(0.026, 0.243), (0.099, 0.246), (0.099, 0.266), (0.026, 0.269)], 0.006), "Y", RW + 0.003, RW + 0.011, ACCENT))
	tg = part("Trigger", "Trigger")
	tp = [(0.27, 0.145), (0.304, 0.145), (0.307, 0.118), (0.302, 0.1), (0.29, 0.084), (0.274, 0.072), (0.267, 0.078), (0.279, 0.094), (0.285, 0.108), (0.283, 0.126), (0.271, 0.134)]
	tg.add(K.prism(tp, "Y", -0.011, 0.011, METAL), 0.002)
	return parts


CHARM = (1.254, HW + 0.006, 0.155)
BONES = [
	("Root", None, (0.0, 0.0, 0.1)),
	("Mag", "Root", (0.7744, 0.0, 0.192)),
	("ChargingHandle", "Root", (0.8224, 0.0, 0.272)),
	("Bolt", "Root", (0.5664, 0.0, 0.3744)),
	("FireSelector", "Root", (0.0864, 0.0, 0.256)),
	("Trigger", "Root", (0.288, 0.0, 0.1344)),
	("Flash", "Root", (MUZZLE_X + 0.01, 0.0, BORE)),
	("Charm", "Root", CHARM),
]
LOCATORS = [
	("Muzzle", "Root", (MUZZLE_X, 0.0, BORE), None),
	("RightGrip", "Root", (0.0, 0.0, 0.0), None),
	("LeftGrip", "Root", (1.6384, 0.0, 0.1856), None),
	("AimPoint", "Root", (AIM_X, 0.0, SIGHT_Z), AIM_ROT),
	("Eject", "Root", (0.5664, -0.0782, 0.3744), EJECT_ROT),
	("CharmPoint", "Charm", CHARM, None),
	("Socket_Muzzle", "Root", (MUZZLE_X, 0.0, BORE), None),
	("Socket_Optic", "Root", (0.7, 0.0, 0.52), None),
	("Socket_Under", "Root", (1.55, 0.0, 0.158), None),
]

RESULT = B.assemble(GUN, build_parts, BONES, LOCATORS, {"class": "Machine gun", "tier": "T4"})
