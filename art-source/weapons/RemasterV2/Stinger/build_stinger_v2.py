# build_stinger_v2.py: RemasterV2 Stinger (compact SMG, magazine through the grip), fresh rebuild from
# vault/02 Art/References/Gun-Image-Concepts/Charcoal compact SMG concept sheet-4.png. Blender MCP only.
# Contract measured on the original Stinger.blend (REF_Stinger_Original): Muzzle 1.14, buttplate -1.53, bore z 0.294,
# AimPoint (-0.408, 0, 0.4778), front post x 0.8355, LeftGrip (0.636, 0, 0.105); bones Root/Mag/ChargingHandle/Bolt/
# Trigger/FireSelector/Flash/Charm (original heads, Charm moved). Cocking knob rides the left groove (-0.15).
# Changes: thicker box receiver (0.072 -> 0.08) with chamfered top, long side groove, top cover, front block with
# ears, ridged handguard, folding skeleton stock with a hinge block, grip hollow for the long magazine (lip at the
# grip base), open ring + hooded post, hanging charm tab, trigger clearance (original tip went below the guard).

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

GUN = "Stinger"
BORE = 0.294
SIGHT_Z = 0.4778
AIM_X = -0.408
FRONT_X = 0.8355
MUZZLE_X = 1.14
RW = 0.08
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
	box_r = B.solid(K.chamfer([(-0.51, 0.144), (0.786, 0.144), (0.786, 0.39), (-0.51, 0.39)], [0.0, 0.0, 0.0, 0.0]), K.section(RW, 0.144, 0.39, 0.03, 0.014), BODY, 0.003)
	box_r = K.cut(box_r, K.group(
		# v03 panel lines (break the flat receiver sides): the upper/lower seam and two vertical seams, both sides.
		both(K.box(-0.45, 0.74, RW - 0.004, 0.2, 0.196, 0.204)),
		both(K.box(0.396, 0.404, RW - 0.004, 0.2, 0.204, 0.30)),
		both(K.box(-0.364, -0.356, RW - 0.004, 0.2, 0.204, 0.30)),
		K.prism(K.stadium(-0.20, 0.27, 0.334, 0.026, 3), "Y", RW - 0.012, 0.2),  # cocking groove (left)
		K.prism(K.stadium(-0.20, 0.27, 0.334, 0.02, 3), "Y", -0.2, -RW + 0.006),  # matching groove line (right, shallow)
		K.prism(K.chamfer([(-0.09, 0.27), (0.156, 0.27), (0.156, 0.31), (-0.09, 0.31)], 0.01), "Y", -0.2, -RW + 0.02),  # port (right)
		both(K.group(K.box(0.285, 0.345, RW - 0.005, 0.2, 0.19, 0.224), K.box(-0.465, -0.414, RW - 0.005, 0.2, 0.19, 0.224))),
	), DARK)
	rec.add(box_r)
	neon.add(both(K.group(K.box(0.288, 0.342, RW - 0.0045, RW - 0.0015, 0.193, 0.221, NEON), K.box(-0.462, -0.417, RW - 0.0045, RW - 0.0015, 0.193, 0.221, NEON))))
	rec.add(B.solid(K.chamfer([(-0.489, 0.386), (0.546, 0.386), (0.546, 0.429), (-0.489, 0.429)], [0, 0, 0.014, 0.014]), K.section(0.052, 0.386, 0.429, 0.012, 0.0), DARK, 0.003))  # top cover
	rec.add(B.solid(K.chamfer([(0.78, 0.189), (0.906, 0.189), (0.906, 0.405), (0.78, 0.405)], [0, 0.012, 0.016, 0]), K.section(0.07, 0.189, 0.405, 0.018, 0.012), BODY, 0.003))  # front block
	rec.add(K.prism(K.chamfer([(-0.105, 0.272), (-0.085, 0.272), (-0.085, 0.31), (-0.105, 0.31)], [0.006, 0, 0, 0.006]), "Y", -RW - 0.012, -RW + 0.004, BODY), 0.003)

	# ================================================================ Handguard (ridged)
	hg = part("Handguard")
	body = B.solid(K.chamfer([(0.465, 0.105), (0.825, 0.105), (0.825, 0.264), (0.465, 0.264)], [0, 0.02, 0.012, 0]), K.section(0.084, 0.10, 0.264, 0.012, 0.03), DARK, 0.003)
	ridges = both(K.group(*[K.prism(K.stadium(0.55, 0.78, z, 0.014, 2), "Y", 0.08, 0.2) for z in (0.225, 0.19, 0.155)]))
	hg.add(K.cut(body, ridges, GRIP))

	# ================================================================ Barrel nut + hider
	bar = part("Barrel")
	bar.add(K.cyl_x(0.906, 0.984, 0.052, 0.0, BORE, 12, METAL), 0.005)
	hider = K.bevel(K.cyl_x(0.98, MUZZLE_X, 0.044, 0.0, BORE, 12, METAL), 0.005, 1, 25)
	slots = K.group(*[K.prism(K.stadium(1.01, 1.11, BORE + dz, 0.012, 2), "Y", -0.06, 0.06) for dz in (0.02, -0.02)], K.cyl_x(MUZZLE_X - 0.05, MUZZLE_X + 0.02, 0.024, 0.0, BORE, 10))
	bar.add(K.cut(hider, slots, DARK))

	# ================================================================ Sights
	si = part("Sights")
	si.add(B.solid(K.chamfer([(-0.48, 0.427), (-0.335, 0.427), (-0.335, 0.43), (-0.48, 0.43)], 0.0), K.section(0.046, 0.425, 0.43, 0.004, 0.0), DARK, 0.0))
	# v02 sight picture (Stinger's own, fast SMG): low V-notch rear; a neon bead on a short post up front.
	si.add(SI.notch_blade(AIM_X, SIGHT_Z, 0.428, hw=0.044, notch="v", nw=0.026, nd=0.026))
	si.add(SI.post(FRONT_X, SIGHT_Z - 0.012, 0.428, w=0.005, t=0.01))
	neon.add(SI.bead(FRONT_X, SIGHT_Z, r=0.008))
	si.add(B.solid([(FRONT_X - 0.045, 0.403), (FRONT_X + 0.045, 0.403), (FRONT_X + 0.024, 0.432), (FRONT_X - 0.024, 0.432)], [(-0.032, 0.403), (0.032, 0.403), (0.022, 0.432), (-0.022, 0.432)], DARK, 0.002))

	# ================================================================ Grip (hollow for the magazine) + guard
	gr = part("Grip")
	gp = [(0.132, 0.156), (-0.072, 0.156), (-0.108, 0.06), (-0.162, -0.186), (-0.15, -0.204), (0.054, -0.204), (0.066, -0.18), (0.12, 0.06)]
	grip = K.bevel(K.prism(gp, "Y", -0.062, 0.062, DARK), 0.013, 1)
	grip = K.cut(grip, both(K.prism(K.chamfer([(0.10, 0.12), (-0.06, 0.12), (-0.125, -0.17), (0.04, -0.17)], 0.018), "Y", 0.058, 0.2)), GRIP)
	grip = K.cut(grip, K.prism([(0.062, 0.0), (-0.12, 0.0), (-0.182, -0.30), (0.035, -0.30)], "Y", -0.054, 0.054), DARK)  # magazine channel
	gr.add(grip)
	guard = K.bevel(K.prism([(0.126, 0.162), (0.36, 0.162), (0.36, 0.03), (0.33, 0.009), (0.126, 0.009)], "Y", -0.03, 0.03, DARK), 0.005, 1, 30)
	gr.add(K.cut(guard, K.prism(K.chamfer([(0.138, 0.2), (0.336, 0.2), (0.336, 0.05), (0.32, 0.036), (0.138, 0.036)], [0, 0, 0.01, 0.0, 0.0]), "Y", -0.1, 0.1), DARK))

	# ================================================================ Folding stock (extended)
	st = part("Stock")
	st.add(B.solid(K.chamfer([(-0.714, 0.12), (-0.51, 0.12), (-0.51, 0.384), (-0.714, 0.384)], [0.02, 0, 0, 0.02]), K.section(0.074, 0.12, 0.384, 0.016, 0.016), BODY, 0.003))  # hinge block
	st.add(both(K.drop(K.cyl_y(-0.61, 0.25, 0.026, 0.072, 0.082, 10, METAL), 1, -1)), 0.002)  # hinge pin caps
	st.add(K.prism([(-0.708, 0.372), (-1.41, 0.31), (-1.41, 0.232), (-0.708, 0.29)], "Y", -0.042, 0.042, BODY), 0.008)  # top beam
	st.add(K.prism([(-0.70, 0.20), (-0.76, 0.205), (-1.40, 0.075), (-1.40, -0.01), (-1.33, -0.01)], "Y", -0.042, 0.042, BODY), 0.008)  # strut
	plate = B.solid(K.chamfer([(-1.398, 0.30), (-1.53, 0.30), (-1.53, -0.096), (-1.398, -0.096)], [0, 0.02, 0.02, 0]), K.section(0.06, -0.096, 0.30, 0.014, 0.014), DARK, 0.003)
	st.add(K.cut(plate, K.prism(K.chamfer([(-1.43, 0.24), (-1.50, 0.24), (-1.50, -0.04), (-1.43, -0.04)], 0.012), "Y", -0.2, 0.2), DARK))  # open buttplate frame

	# ================================================================ Fasteners
	pins = part("Pins")
	for s in (1, -1):
		for x, z, w in ((0.82, 0.32, 0.07), (0.50, 0.19, 0.084), (0.20, 0.215, RW)):
			pins.add(B.head(x, z, w, r=0.01, segs=8, side=s))

	# ================================================================ Charm tab (hangs under the receiver, ahead of the guard, left)
	ch = part("CharmLoop")
	tab = [(0.378, 0.19), (0.44, 0.19)] + [(0.409 + 0.031 * math.cos(-a), 0.13 + 0.031 * math.sin(-a)) for a in [i * math.pi / 6 for i in range(7)]]
	tb = K.bevel(K.prism(tab, "Y", RW - 0.001, RW + 0.013, METAL), 0.003, 1, 50)
	ch.add(K.cut(tb, K.cyl_y(0.409, 0.125, 0.012, 0.0, 0.2, 10, METAL), DARK))
	ch.add(B.head(0.395, 0.174, RW + 0.013, r=0.006, h=0.003))
	ch.add(B.head(0.423, 0.174, RW + 0.013, r=0.006, h=0.003))

	# ================================================================ Moving parts
	mg = part("Mag", "Mag")
	mb = K.bevel(K.prism([(0.054, -0.01), (-0.12, -0.01), (-0.178, -0.534), (0.03, -0.534)], "Y", -0.05, 0.05, DARK), 0.008)
	mg.add(AM.pistol_round(-0.105, 0.006, 0.003, scale=1.3))  # v02: top round (seen with the mag out)
	mg.add(K.cut(mb, both(K.prism(K.chamfer([(-0.03, -0.24), (-0.012, -0.24), (-0.045, -0.51), (-0.063, -0.51)], 0.004), "Y", 0.046, 0.2)), DARK))
	mg.add(B.solid(K.chamfer([(0.04, -0.532), (-0.186, -0.532), (-0.19, -0.585), (0.046, -0.585)], 0.008), K.section(0.056, -0.59, -0.532, 0.006, 0.01), PANEL, 0.002))
	mg.add(K.loft_x([(-0.10, K.circle(0, 0.0, 0.016, 8)), (0.0, K.circle(0, 0.0, 0.016, 8)), (0.012, K.circle(0, 0.0, 0.013, 8)), (0.045, K.circle(0, 0.0, 0.005, 8))], METAL))

	chh = part("ChargingHandle", "ChargingHandle")
	chh.add(K.box(0.15, 0.255, RW - 0.012, RW + 0.004, 0.32, 0.348, METAL))
	knob = K.prism(K.chamfer([(0.155, 0.31), (0.25, 0.31), (0.256, 0.335), (0.25, 0.362), (0.16, 0.362), (0.155, 0.35)], 0.006), "Y", RW, RW + 0.03, ACCENT)
	chh.add(K.cut(knob, K.group(*[K.box(x, x + 0.008, RW + 0.024, 0.2, 0.30, 0.37) for x in (0.17, 0.19, 0.21, 0.23)]), ACCENT))

	bolt = part("Bolt", "Bolt")
	bolt.add(K.box(-0.084, 0.15, -RW + 0.004, -RW + 0.024, 0.274, 0.306, METAL), 0.002)

	tg = part("Trigger", "Trigger")
	tp = [(0.182, 0.17), (0.216, 0.17), (0.22, 0.14), (0.215, 0.115), (0.203, 0.093), (0.188, 0.08), (0.181, 0.086), (0.193, 0.104), (0.199, 0.122), (0.197, 0.142), (0.184, 0.152)]
	tg.add(K.prism(tp, "Y", -0.011, 0.011, METAL), 0.002)

	sel = part("FireSelector", "FireSelector")
	sel.add(K.prism(K.chamfer([(-0.06, 0.18), (0.066, 0.18), (0.066, 0.212), (-0.05, 0.218)], 0.006), "Y", RW - 0.002, RW + 0.009, METAL), 0.002)
	sel.add(K.box(0.04, 0.06, RW + 0.007, RW + 0.012, 0.184, 0.21, ACCENT))
	return parts


CHARM = (0.409, RW + 0.006, 0.125)
BONES = [
	("Root", None, (0.0, 0.0, 0.15)),
	("Mag", "Root", (-0.048, 0.0, -0.09)),
	("ChargingHandle", "Root", (0.201, 0.0864, 0.372)),
	("Bolt", "Root", (0.036, -0.06, 0.33)),
	("Trigger", "Root", (0.198, 0.0, 0.132)),
	("FireSelector", "Root", (-0.042, 0.078, 0.204)),
	("Flash", "Root", (MUZZLE_X + 0.01, 0.0, BORE)),
	("Charm", "Root", CHARM),
]
LOCATORS = [
	("Muzzle", "Root", (MUZZLE_X, 0.0, BORE), None),
	("RightGrip", "Root", (0.0, 0.0, 0.0), None),
	("LeftGrip", "Root", (0.636, 0.0, 0.105), None),
	("AimPoint", "Root", (AIM_X, 0.0, SIGHT_Z), AIM_ROT),
	("Eject", "Root", (0.036, -0.072, 0.29), EJECT_ROT),
	("CharmPoint", "Charm", CHARM, None),
	("Socket_Muzzle", "Root", (MUZZLE_X, 0.0, BORE), None),
	("Socket_Optic", "Root", (0.05, 0.0, 0.429), None),
	("Socket_Under", "Root", (0.64, 0.0, 0.105), None),
]

RESULT = B.assemble(GUN, build_parts, BONES, LOCATORS, {"class": "SMG", "tier": "T2"})
