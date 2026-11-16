# build_guardian_v2.py: RemasterV2 Guardian (long semi-auto precision rifle, iron-sight ADS), fresh rebuild from
# vault/02 Art/References/Gun-Image-Concepts/Guardian precision rifle concept sheet-9.png. Blender MCP only.
# Contract measured on the original Guardian.blend (REF_Guardian_Original): Muzzle 2.9984, buttpad -1.245, bore z
# 0.368, AimPoint (0.1376, 0, 0.4984), front post x 2.2576, LeftGrip (1.6608, 0, 0.1888); bones Root/Mag/
# ChargingHandle/Bolt/Trigger/FireSelector/Flash/Charm (original heads, Charm moved); BoltCatch part on Root.
# Changes: receiver/handguard/mag/grip/stock thickened and sectioned; a real magwell with lip for the short box
# mag; charging channel; port + bolt; long two-row slotted handguard with front block; skeleton stock with a
# triangular window and cheek; open ring + hooded post; hanging charm tab; trigger clearance (the original tip went
# 0.006 below the guard opening).

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

GUN = "Guardian"
BORE = 0.368
SIGHT_Z = 0.4984
AIM_X = 0.1376
FRONT_X = 2.2576
MUZZLE_X = 2.9984
UW, LW = 0.086, 0.08
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
	upper = B.solid(K.chamfer([(-0.013, 0.2336), (0.89, 0.2336), (0.89, 0.40), (0.874, 0.416), (-0.013, 0.416)], 0.0), K.section(UW, 0.2336, 0.416, 0.022, 0.0), BODY, 0.003)
	upper = K.cut(upper, K.group(
		# v03 panel lines: front and rear vertical seams and a low horizontal seam, both sides.
		both(K.box(0.096, 0.104, UW - 0.004, 0.2, 0.25, 0.385)),  # stop below the top chamfer
		both(K.box(0.826, 0.834, UW - 0.004, 0.2, 0.25, 0.385)),
		both(K.box(0.099, 0.831, UW - 0.004, 0.2, 0.25, 0.258)),  # overlaps the verticals (touching ends made non-manifold edges)
		K.prism(K.chamfer([(0.30, 0.326), (0.79, 0.326), (0.79, 0.366), (0.30, 0.366)], 0.006), "Y", UW - 0.016, 0.2),  # charging channel
		K.prism(K.chamfer([(0.317, 0.268), (0.637, 0.268), (0.637, 0.352), (0.317, 0.352)], 0.012), "Y", -0.2, -UW + 0.02),  # port
		K.box(0.35, 0.56, UW - 0.006, 0.2, 0.281, 0.297),  # neon pocket, left only (the port is on the right)
	), DARK)
	rec.add(upper)
	neon.add(K.box(0.353, 0.557, UW - 0.0055, UW - 0.0025, 0.2825, 0.2955, NEON))
	lower = B.solid([(0.877, 0.2336), (-0.07, 0.2336), (-0.07, 0.143), (-0.05, 0.13), (0.15, 0.12), (0.15, 0.032), (0.451, 0.032), (0.47, 0.1216), (0.877, 0.1216)], K.section(LW, 0.02, 0.2336, 0.006, 0.014), BODY, 0.003)
	lower = K.cut(lower, K.group(
		K.prism(K.chamfer([(0.17, 0.13), (0.445, 0.13), (0.445, 0.062), (0.41, 0.051), (0.17, 0.051)], [0, 0, 0.012, 0.0, 0.01]), "Y", -0.2, 0.2),  # guard opening
		K.prism([(0.493, 0.25), (0.781, 0.25), (0.781, 0.05), (0.493, 0.05)], "Y", -0.064, 0.064),  # magwell cavity
		both(K.prism(K.chamfer([(-0.05, 0.15), (0.14, 0.15), (0.14, 0.215), (-0.05, 0.215)], 0.01), "Y", LW - 0.005, 0.2)),
	), DARK)
	rec.add(lower)
	# Magwell lip below the lower (the mag shows ~0.2 below it).
	lip = B.solid(K.chamfer([(0.485, 0.125), (0.79, 0.125), (0.795, 0.09), (0.48, 0.09)], [0, 0, 0.008, 0.008]), [(-0.074, 0.13), (-0.074, 0.104), (-0.078, 0.098), (-0.078, 0.09), (0.078, 0.09), (0.078, 0.098), (0.074, 0.104), (0.074, 0.13)], BODY, 0.003)
	rec.add(K.cut(lip, K.prism([(0.489, 0.2), (0.785, 0.2), (0.785, 0.0), (0.489, 0.0)], "Y", -0.064, 0.064), DARK))
	rec.add(B.solid(K.chamfer([(0.877, 0.211), (1.136, 0.211), (1.136, 0.394), (0.877, 0.394)], [0, 0.02, 0.02, 0]), K.section(0.092, 0.211, 0.394, 0.022, 0.02), BODY, 0.003))  # front block
	rec.add(K.prism(K.chamfer([(0.296, 0.27), (0.325, 0.27), (0.325, 0.35), (0.296, 0.35)], [0.008, 0, 0, 0.008]), "Y", -UW - 0.012, -UW + 0.004, BODY), 0.003)  # deflector
	rec.add(K.box(-0.003, 2.355, -0.03, 0.03, 0.414, 0.436, DARK), 0.003)  # rail base
	t = K.Part("_t")
	x = 0.03
	while x + 0.024 < 2.2:
		if not (0.06 < x < 0.22):
			t.add(K.drop(K.box(x, x + 0.024, -0.03, 0.03, 0.435, 0.448, DARK), 2, -1))
		x += 0.075
	rec.add(t.merged())

	# ================================================================ Handguard
	hg = part("Handguard")
	body = B.solid(K.chamfer([(1.123, 0.189), (2.355, 0.189), (2.355, 0.432), (1.123, 0.432)], [0, 0.02, 0.012, 0]), K.section(0.088, 0.189, 0.432, 0.022, 0.034), BODY, 0.003)
	slots = K.group(*[K.prism(K.stadium(x, x + 0.13, zc, 0.028, 2), "Y", 0.066, 0.2) for x in (1.22, 1.39, 1.56, 1.73, 1.90, 2.07) for zc in (0.37, 0.30)])
	hg.add(K.cut(body, both(slots), DARK))

	# ================================================================ Barrel + brake
	bar = part("Barrel")
	bar.add(K.drop(K.cyl_x(2.34, 2.79, 0.04, 0.0, BORE, 12, METAL), 0, -1))  # v03: heavier barrel (0.03 -> 0.04)
	brake = K.bevel(K.cyl_x(2.78, MUZZLE_X, 0.058, 0.0, BORE, 8, METAL, rot=math.pi / 8), 0.006)  # v03: bigger brake
	ports = K.group(*[K.prism(K.stadium(x, x + 0.04, BORE, 0.03, 2), "Y", -0.08, 0.08) for x in (2.81, 2.87, 2.93)], K.cyl_x(MUZZLE_X - 0.05, MUZZLE_X + 0.02, 0.018, 0.0, BORE, 8, DARK))
	bar.add(K.cut(brake, ports, DARK))
	bar.add(K.cyl_x(2.755, 2.785, 0.036, 0.0, BORE, 10, METAL), 0.003)

	# ================================================================ Sights
	si = part("Sights")
	si.add(B.solid(K.chamfer([(0.07, 0.436), (0.205, 0.436), (0.205, 0.452), (0.07, 0.452)], [0, 0, 0.008, 0.008]), K.section(0.04, 0.436, 0.452, 0.008, 0.0), DARK, 0.002))
	# v02 sight picture (Guardian's own): a carry handle whose rear end holds the peep, with a sighting channel along
	# its top; front post between two winged guards.
	hx0, hx1 = AIM_X - 0.03, AIM_X + 0.33
	handle = K.prism([(hx0, 0.436), (hx1, 0.436), (hx1, SIGHT_Z + 0.012), (hx1 - 0.03, SIGHT_Z + 0.02), (hx0 + 0.07, SIGHT_Z + 0.02), (hx0 + 0.05, SIGHT_Z + 0.046), (hx0 + 0.008, SIGHT_Z + 0.046), (hx0, SIGHT_Z + 0.036)], "Y", -0.034, 0.034, DARK)  # raised rear housing closes the peep
	handle = K.cut(handle, K.group(
		K.box(hx0 + 0.05, hx1 + 0.1, -0.017, 0.017, SIGHT_Z - 0.018, 0.7),  # sighting channel (open to the front)
		K.prism(K.chamfer([(hx0 + 0.07, 0.43), (hx1 - 0.06, 0.43), (hx1 - 0.06, 0.468), (hx0 + 0.07, 0.468)], 0.012), "Y", -0.2, 0.2),  # hand window
		K.cyl_x(hx0 - 0.1, hx0 + 0.06, 0.024, 0.0, SIGHT_Z, 12, DARK, rot=0.0),  # peep
	), DARK)
	si.add(handle, 0.003, 1, 40)
	for s in (1, -1):
		si.add(K.prism([(s * 0.011, 0.458), (s * 0.034, 0.458), (s * 0.026, SIGHT_Z + 0.024), (s * 0.015, SIGHT_Z + 0.024)], "X", FRONT_X - 0.014, FRONT_X + 0.014, DARK), 0.002, 1, 40)  # wings
	si.add(B.solid([(FRONT_X - 0.045, 0.434), (FRONT_X + 0.045, 0.434), (FRONT_X + 0.022, 0.462), (FRONT_X - 0.022, 0.462)], [(-0.03, 0.434), (0.03, 0.434), (0.02, 0.462), (-0.02, 0.462)], DARK, 0.002))
	si.add(K.prism([(-0.005, 0.458), (0.005, 0.458), (0.005, 0.482), (0.0014, SIGHT_Z), (-0.0014, SIGHT_Z), (-0.005, 0.482)], "X", FRONT_X - 0.005, FRONT_X + 0.005, METAL))

	# ================================================================ Grip
	gr = part("Grip")
	gp = [(0.176, 0.154), (-0.10, 0.16), (-0.144, -0.24), (-0.115, -0.294), (-0.074, -0.307), (0.106, -0.307), (0.115, -0.272), (0.096, -0.16), (0.12, -0.12), (0.10, -0.06), (0.15, 0.06)]
	grip = K.bevel(K.prism(gp, "Y", -0.06, 0.06, DARK), 0.013, 1)
	gr.add(K.cut(grip, both(K.prism(K.chamfer([(0.10, 0.07), (-0.07, 0.085), (-0.105, -0.24), (0.07, -0.25)], 0.02), "Y", 0.056, 0.2)), GRIP))

	# ================================================================ Stock (tube, skeleton body with window, cheek, pad)
	st = part("Stock")
	st.add(K.drop(K.cyl_x(-0.36, -0.006, 0.058, 0.0, 0.336, 12, DARK), 0, 1), 0.004)
	st.add(K.cyl_x(-0.03, 0.0, 0.068, 0.0, 0.336, 8, METAL, rot=math.pi / 8), 0.003)
	sbody = B.solid(K.chamfer([(-0.342, 0.37), (-0.37, 0.403), (-1.085, 0.403), (-1.085, -0.16), (-1.034, -0.16), (-0.58, 0.102), (-0.38, 0.224), (-0.342, 0.256)], [0, 0.01, 0.01, 0, 0.0, 0, 0, 0]), K.section(0.07, -0.17, 0.403, 0.02, 0.016), BODY, 0.004)
	sbody = K.cut(sbody, K.prism(K.chamfer([(-0.52, 0.243), (-1.02, 0.243), (-1.02, -0.083)], 0.02), "Y", -0.2, 0.2), DARK)
	st.add(sbody)
	st.add(B.solid(K.chamfer([(-0.55, 0.4), (-0.98, 0.4), (-0.98, 0.43), (-0.6, 0.43)], [0, 0, 0.012, 0.012]), K.section(0.062, 0.39, 0.43, 0.012, 0.0), PANEL, 0.003))  # cheek riser
	pad = B.solid(K.chamfer([(-1.08, 0.41), (-1.245, 0.41), (-1.245, -0.166), (-1.08, -0.166)], [0, 0.024, 0.024, 0]), K.section(0.078, -0.166, 0.41, 0.018, 0.018), DARK, 0.004)
	st.add(K.cut(pad, K.group(*[K.box(-1.29, -1.236, -0.07, 0.07, z, z + 0.012) for z in (-0.12, -0.05, 0.02, 0.09, 0.16, 0.23, 0.30, 0.37)]), GRIP))

	# ================================================================ Fasteners, bolt catch
	pins = part("Pins")
	for s in (1, -1):
		for x, z, w in ((0.94, 0.36, 0.092), (0.94, 0.24, 0.092), (0.21, 0.19, LW), (0.37, 0.19, LW), (-0.48, 0.32, 0.07)):
			pins.add(B.head(x, z, w, r=0.01, segs=8, side=s))
	bc = part("BoltCatch")
	bc.add(K.prism(K.chamfer([(0.403, 0.16), (0.47, 0.16), (0.47, 0.235), (0.41, 0.235)], 0.006), "Y", LW - 0.002, LW + 0.01, METAL), 0.002)

	# ================================================================ Charm tab (hangs under the front block, left)
	ch = part("CharmLoop")
	tab = [(1.15, 0.23), (1.212, 0.23)] + [(1.181 + 0.031 * math.cos(-a), 0.17 + 0.031 * math.sin(-a)) for a in [i * math.pi / 6 for i in range(7)]]
	tb = K.bevel(K.prism(tab, "Y", 0.087, 0.1, METAL), 0.003, 1, 50)
	ch.add(K.cut(tb, K.cyl_y(1.181, 0.165, 0.012, 0.0, 0.2, 10, METAL), DARK))
	ch.add(B.head(1.166, 0.215, 0.1, r=0.006, h=0.003))
	ch.add(B.head(1.196, 0.215, 0.1, r=0.006, h=0.003))

	# ================================================================ Moving parts
	mg = part("Mag", "Mag")
	mb = K.bevel(K.prism([(0.495, 0.22), (0.78, 0.22), (0.79, -0.05), (0.805, -0.175), (0.515, -0.175), (0.50, -0.05)], "Y", -0.06, 0.06, DARK), 0.01)  # v03: full-length DMR mag
	mb = K.cut(mb, both(K.group(K.prism(K.chamfer([(0.60, -0.03), (0.74, -0.03), (0.74, 0.07), (0.60, 0.07)], 0.008), "Y", 0.056, 0.2), K.box(0.53, 0.56, 0.056, 0.2, -0.03, 0.07))), DARK)
	mg.add(mb)
	mg.add(B.solid(K.chamfer([(0.505, -0.17), (0.815, -0.17), (0.82, -0.205), (0.50, -0.205)], 0.008), K.section(0.066, -0.21, -0.165, 0.004, 0.01), PANEL, 0.002))  # v03: base plate
	mg.add(AM.rifle_round(0.505, 0.008, 0.236, scale=1.05))  # v02: full-power top round (seen with the mag out)
	mg.add(both(K.box(0.536, 0.554, 0.0565, 0.0585, -0.025, 0.065, NEON)))
	mg.add(B.solid(K.chamfer([(0.488, -0.045), (0.787, -0.045), (0.792, -0.07), (0.483, -0.07)], 0.006), K.section(0.065, -0.075, -0.045, 0.004, 0.008), PANEL, 0.002))
	mg.add(K.loft_x([(0.53, K.circle(0, 0.232, 0.015, 8)), (0.68, K.circle(0, 0.232, 0.015, 8)), (0.692, K.circle(0, 0.232, 0.013, 8)), (0.735, K.circle(0, 0.232, 0.005, 8))], METAL))

	chh = part("ChargingHandle", "ChargingHandle")
	chh.add(K.box(0.68, 0.79, UW - 0.016, UW - 0.001, 0.33, 0.362, METAL))
	chh.add(K.box(0.70, 0.75, UW - 0.002, UW + 0.03, 0.334, 0.358, METAL), 0.003)
	chh.add(K.prism(K.chamfer([(0.688, 0.318), (0.762, 0.318), (0.768, 0.346), (0.762, 0.375), (0.698, 0.375), (0.688, 0.36)], 0.006), "Y", UW + 0.026, UW + 0.05, ACCENT), 0.003)

	bolt = part("Bolt", "Bolt")
	bolt.add(K.box(0.323, 0.63, -UW + 0.004, -UW + 0.024, 0.278, 0.346, METAL), 0.003)

	tg = part("Trigger", "Trigger")
	tp = [(0.243, 0.13), (0.276, 0.13), (0.279, 0.105), (0.274, 0.088), (0.262, 0.074), (0.246, 0.068), (0.24, 0.074), (0.252, 0.086), (0.258, 0.1), (0.256, 0.114), (0.244, 0.12)]
	tg.add(K.prism(tp, "Y", -0.011, 0.011, METAL), 0.002)

	sel = part("FireSelector", "FireSelector")
	sel.add(K.drop(K.cyl_y(0.1568, 0.2176, 0.017, LW - 0.002, LW + 0.008, 8, METAL), 1, -1), 0.002)
	sel.add(K.prism(K.chamfer([(0.09, 0.205), (0.16, 0.208), (0.165, 0.226), (0.09, 0.228)], 0.004), "Y", LW + 0.006, LW + 0.014, ACCENT))
	return parts


CHARM = (1.181, 0.094, 0.165)
BONES = [
	("Root", None, (0.0, 0.0, 0.15)),
	("Mag", "Root", (0.6368, 0.0, 0.1376)),
	("ChargingHandle", "Root", (0.7328, 0.0864, 0.3456)),
	("Bolt", "Root", (0.4768, -0.06, 0.3136)),
	("Trigger", "Root", (0.2592, 0.0, 0.1216)),
	("FireSelector", "Root", (0.1568, 0.0756, 0.2176)),
	("Flash", "Root", (MUZZLE_X + 0.01, 0.0, BORE)),
	("Charm", "Root", CHARM),
]
LOCATORS = [
	("Muzzle", "Root", (MUZZLE_X, 0.0, BORE), None),
	("RightGrip", "Root", (0.0, 0.0, 0.0), None),
	("LeftGrip", "Root", (1.6608, 0.0, 0.1888), None),
	("AimPoint", "Root", (AIM_X, 0.0, SIGHT_Z), AIM_ROT),
	("Eject", "Root", (0.4768, -0.0744, 0.3136), EJECT_ROT),
	("CharmPoint", "Charm", CHARM, None),
	("Socket_Muzzle", "Root", (MUZZLE_X, 0.0, BORE), None),
	("Socket_Optic", "Root", (0.55, 0.0, 0.448), None),
	("Socket_Under", "Root", (1.66, 0.0, 0.189), None),
]

RESULT = B.assemble(GUN, build_parts, BONES, LOCATORS, {"class": "Marksman rifle", "tier": "T3"})
