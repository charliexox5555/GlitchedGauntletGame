# build_shorty_v2.py: RemasterV2 Shorty (break-action double-barrel sidearm). Blender MCP only.
# Finish from vault/02 Art/References/Gun-Image-Concepts/Compact twin-barrel shotgun concept sheet-1.png; layout
# stays SIDE-BY-SIDE (the user's round-2 call, 2026-10-26, and the rig contract: "Upper" = left barrel +Y fires first).
# Contract measured on the original Shorty.blend (REF_Shorty_Original): muzzles x 1.4482 at y +-0.05, bore z 0.26,
# hinge (0.546, 0, 0.1144), breech face x 0.546; bones Root/Barrels/ShellUpper/ShellLower/BreechLatch/Trigger/Flash/
# Charm (original heads, Charm moved); locators Muzzle/MuzzleLower/Eject/EjectLower/ForeGrip/ChamberUpper/
# ChamberLower on Barrels + RightGrip/LeftGrip/CharmPoint.
# Changes: thicker frame (0.085 -> 0.09) and grip (0.05 -> 0.064); a chamfered barrel housing with ringed muzzles
# standing proud of it, a rib with a front post; breech band with chambers; textured fore-end; round hinge caps;
# windowed latch; grip base cap; trigger clearance (the original tip sat 0.008 above the guard).

import bpy, math, sys, importlib
from mathutils import Vector

ROOT = r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/art-source/weapons/RemasterV2"
sys.path.insert(0, ROOT + "/_Library")
import v2kit as K  # noqa: E402
import v2build as B  # noqa: E402
import ammo as AM  # noqa: E402

importlib.reload(K)
importlib.reload(B)
importlib.reload(AM)
from v2kit import BODY, PANEL, DARK, METAL, GRIP, ACCENT, NEON  # noqa: E402

GUN = "Shorty"
BORE = 0.26
BY = 0.05
MUZZLE_X = 1.4482
BREECH_X = 0.546
HINGE = (0.546, 0.0, 0.1144)
FW, GW = 0.09, 0.064


def build_parts():
	parts = {}

	def part(name, bone="Root"):
		parts[name] = K.Part(name, bone)
		return parts[name]

	both = B.both

	# ================================================================ Frame (action body, standing breech)
	fr = part("Frame")
	body = B.solid(K.chamfer([(-0.10, 0.10), (BREECH_X, 0.052), (BREECH_X, 0.333), (-0.06, 0.333), (-0.10, 0.29)], [0.03, 0, 0, 0.0, 0.0]), K.section(FW, 0.04, 0.333, 0.02, 0.014), BODY, 0.003)
	cuts = [
		both(K.prism(K.chamfer([(0.02, 0.07), (0.44, 0.07), (0.44, 0.215), (0.06, 0.215)], 0.012), "Y", FW - 0.005, 0.2)),  # side panel recess
		both(K.box(0.125, 0.198, FW - 0.005, 0.2, 0.239, 0.253)),  # neon pocket
	]
	body = K.cut(body, K.group(*cuts), DARK)
	for f in body.faces:
		c = f.calc_center_median()
		if abs(abs(c.y) - (FW - 0.005)) < 1e-4 and 0.07 <= c.z <= 0.215:
			f.material_index = PANEL
	fr.add(body)
	fr.add(both(K.drop(K.cyl_y(HINGE[0], HINGE[2], 0.032, FW - 0.003, FW + 0.008, 12, METAL), 1, -1)), 0.003)  # hinge caps
	rear = K.bevel(K.prism([(-0.02, 0.33), (0.085, 0.33), (0.078, 0.365), (-0.012, 0.365)], "Y", -0.034, 0.034, DARK), 0.003, 1, 50)
	fr.add(K.cut(rear, K.box(-0.1, 0.2, -0.011, 0.011, 0.348, 0.5), DARK))
	guard = K.bevel(K.prism([(0.172, 0.06), (0.538, 0.06), (0.538, 0.03), (0.47, -0.135), (0.20, -0.135), (0.172, -0.10)], "Y", -0.03, 0.03, DARK), 0.006, 1, 30)
	fr.add(K.cut(guard, K.prism(K.chamfer([(0.231, 0.08), (0.447, 0.08), (0.447, 0.02), (0.41, -0.105), (0.24, -0.105), (0.231, -0.08)], [0, 0, 0.01, 0.012, 0.012, 0.01]), "Y", -0.1, 0.1), DARK))

	# ================================================================ Grip
	gr = part("Grip")
	gp = [(0.148, 0.135), (-0.06, 0.135), (-0.234, -0.195), (-0.234, -0.273), (-0.218, -0.30), (0.036, -0.30), (0.057, -0.286), (0.062, -0.156), (0.114, 0.0), (0.148, 0.047)]
	grip = K.bevel(K.prism(gp, "Y", -GW, GW, DARK), 0.012, 2)
	gr.add(K.cut(grip, both(K.prism(K.chamfer([(0.07, -0.01), (-0.035, 0.03), (-0.19, -0.25), (0.02, -0.262)], 0.02), "Y", GW - 0.004, 0.2)), GRIP))
	gr.add(B.solid(K.chamfer([(0.045, -0.292), (-0.232, -0.292), (-0.236, -0.335), (0.04, -0.335)], [0, 0, 0.01, 0.01]), K.section(GW + 0.004, -0.34, -0.292, 0.004, 0.012), PANEL, 0.003))  # base cap

	# ================================================================ Neon
	neon = part("Neon")
	neon.add(both(K.box(0.128, 0.195, FW - 0.0045, FW - 0.0015, 0.2415, 0.2505, NEON)))
	neon.add(both(K.prism([(0.13, 0.03), (0.142, 0.03), (0.116, -0.05), (0.104, -0.05)], "Y", GW - 0.001, GW + 0.0015, NEON)))  # grip-front strips
	neon.add(both(K.box(-0.0157, -0.0134, 0.017, 0.026, 0.351, 0.36, NEON)))  # rear notch dots

	# ================================================================ Charm tab (rear-left of the frame, vertical hole)
	ch = part("CharmLoop")
	tab = [(-0.085, 0.0), (-0.04, 0.0)] + [(-0.0625 + 0.0225 * math.cos(a), 0.108 + 0.0225 * math.sin(a)) for a in [i * math.pi / 5 for i in range(6)]]
	tab = [(x, y if y > 0 else FW - 0.002) for x, y in tab]
	tb = K.bevel(K.prism(tab, "Z", 0.196, 0.214, DARK), 0.003, 1, 50)
	ch.add(K.cut(tb, K.prism(K.circle(-0.0625, 0.108, 0.0085, 8), "Z", 0.1, 0.3, METAL), METAL))
	ch.add(K.prism([(FW + 0.002, 0.196), (0.106, 0.196), (FW + 0.002, 0.176)], "X", -0.068, -0.057, DARK))

	# ================================================================ Barrels (break-action group)
	bar = part("Barrels", "Barrels")
	# v03 (concept): the shroud covers only the breech end; two full barrel tubes run out to the muzzle, joined by a
	# web and a sighting rib, with a clamp band near the muzzle.
	housing = B.solid(K.chamfer([(0.64, 0.198), (1.0, 0.198), (1.04, 0.24), (1.04, 0.29), (1.0, 0.322), (0.64, 0.322)], [0, 0.0, 0.01, 0.01, 0.0, 0]), K.section(0.102, 0.198, 0.322, 0.03, 0.022), BODY, 0.003)
	housing = K.cut(housing, K.box(0.66, 1.1, -0.012, 0.012, 0.316, 0.4), DARK)  # rib valley
	bar.add(housing)
	for y in (BY, -BY):
		bar.add(K.drop(K.cyl_x(0.99, 1.36, 0.046, y, BORE, 14, METAL), 0, -1))  # barrel tube
		ring = K.bevel(K.cyl_x(1.355, MUZZLE_X, 0.05, y, BORE, 14, METAL), 0.006, 1, 25)
		bar.add(K.cut(ring, K.cyl_x(MUZZLE_X - 0.1, MUZZLE_X + 0.05, 0.035, y, BORE, 12, DARK), DARK))
	bar.add(K.box(0.99, 1.36, -0.012, 0.012, BORE - 0.03, BORE + 0.03, DARK))  # web between the tubes
	rib = K.box(0.99, 1.36, -0.016, 0.016, BORE + 0.028, 0.312, DARK)
	bar.add(K.cut(rib, K.group(*[K.box(1.05 + 0.06 * i, 1.08 + 0.06 * i, -0.05, 0.05, 0.299, 0.33) for i in range(4)]), DARK), 0.002)  # vented rib (blind slots from the top: through-vents left a 0.002 strip that triangulated into slivers)
	bar.add(B.solid(K.chamfer([(1.27, BORE - 0.06), (1.32, BORE - 0.06), (1.32, BORE + 0.056), (1.27, BORE + 0.056)], 0.008), K.section(0.104, BORE - 0.06, BORE + 0.056, 0.03, 0.03), PANEL, 0.003))  # clamp band
	bar.add(K.prism([(1.30, 0.31), (1.35, 0.31), (1.345, 0.348), (1.30, 0.348)], "Y", -0.009, 0.009, DARK), 0.002)  # front post
	bn = part("BarrelNeon", "Barrels")
	bn.add(K.box(1.2985, 1.3005, -0.0055, 0.0055, 0.332, 0.342, NEON))  # front post dot
	band = B.solid(K.chamfer([(BREECH_X, 0.091), (0.645, 0.091), (0.645, 0.333), (BREECH_X, 0.333)], [0.014, 0.0, 0.0, 0.014]), K.section(0.104, 0.091, 0.333, 0.026, 0.02), BODY, 0.003)
	band = K.cut(band, K.group(*[K.cyl_x(BREECH_X - 0.05, BREECH_X + 0.08, 0.035, y, BORE, 12, DARK) for y in (BY, -BY)]), METAL)
	bar.add(band)
	fore = B.solid([(1.25, 0.222), (0.645, 0.222), (0.645, 0.005), (0.858, 0.005), (0.879, 0.031), (1.21, 0.031), (1.25, 0.093)], K.section(0.088, 0.0, 0.224, 0.0, 0.022), DARK, 0.003)  # v03: up to the barrels
	bar.add(K.cut(fore, both(K.prism(K.chamfer([(0.70, 0.05), (1.20, 0.05), (1.235, 0.17), (0.70, 0.17)], 0.015), "Y", 0.084, 0.2)), GRIP))

	# ================================================================ Moving parts
	lt = part("BreechLatch", "BreechLatch")
	latch = K.prism(K.chamfer([(0.286, 0.117), (0.434, 0.117), (0.434, 0.164), (0.286, 0.164)], 0.006), "Y", FW - 0.004, FW + 0.012, METAL)
	lt.add(K.cut(latch, K.box(0.335, 0.39, FW + 0.006, 0.2, 0.128, 0.153), DARK))
	tg = part("Trigger", "Trigger")
	tp = [(0.286, 0.088), (0.316, 0.088), (0.322, 0.03), (0.317, 0.0), (0.304, -0.028), (0.288, -0.048), (0.28, -0.042), (0.292, -0.02), (0.30, 0.004), (0.298, 0.03), (0.288, 0.04)]
	tg.add(K.prism(tp, "Y", -0.011, 0.011, METAL), 0.002)
	for name, y in (("ShellUpper", BY), ("ShellLower", -BY)):
		sh = part(name, name)
		sh.add(AM.shotgun_shell(BREECH_X - 0.008, y, BORE, scale=0.95))  # v02: blue hull, brass head + rim, rolled crimp
	return parts


CHARM = (-0.0625, 0.108, 0.205)
EJECT_BACK = Vector((-0.86, 0, 0.51)).to_track_quat("Z", "Y").to_matrix().to_4x4()
BONES = [
	("Root", None, (0.0, 0.0, 0.1)),
	("Barrels", "Root", HINGE),
	("ShellUpper", "Barrels", (BREECH_X, BY, BORE)),
	("ShellLower", "Barrels", (BREECH_X, -BY, BORE)),
	("BreechLatch", "Root", (0.3614, FW, 0.1404)),
	("Trigger", "Root", (0.3042, 0.0, 0.0416)),
	("Flash", "Root", (MUZZLE_X + 0.01, 0.0, BORE)),
	("Charm", "Root", CHARM),
]
LOCATORS = [
	("Muzzle", "Barrels", (MUZZLE_X, BY, BORE), None),
	("MuzzleLower", "Barrels", (MUZZLE_X, -BY, BORE), None),
	("RightGrip", "Root", (0.0, 0.0, 0.0), None),
	("LeftGrip", "Root", (0.0, 0.0, -0.08), None),
	("Eject", "Barrels", (BREECH_X, BY, BORE), EJECT_BACK),
	("EjectLower", "Barrels", (BREECH_X, -BY, BORE), EJECT_BACK),
	("ForeGrip", "Barrels", (0.9412, 0.0, 0.0312), None),
	("ChamberUpper", "Barrels", (BREECH_X + 0.1, BY, BORE), None),
	("ChamberLower", "Barrels", (BREECH_X + 0.1, -BY, BORE), None),
	("CharmPoint", "Charm", CHARM, None),
	("Socket_Muzzle", "Barrels", (MUZZLE_X, 0.0, BORE), None),
	("Socket_Optic", "Root", (0.25, 0.0, 0.333), None),
	("Socket_Under", "Barrels", (1.05, 0.0, 0.005), None),
]

RESULT = B.assemble(GUN, build_parts, BONES, LOCATORS, {"class": "Sidearm", "tier": "T1"})
