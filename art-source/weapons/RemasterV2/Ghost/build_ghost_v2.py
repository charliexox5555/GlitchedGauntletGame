# build_ghost_v2.py: RemasterV2 Ghost (suppressed sidearm), fresh rebuild from
# vault/02 Art/References/Gun-Image-Concepts/Ghost pistol concept sheet-2.png. Blender MCP only:
#   ns = {"__name__": "__main__"}; exec(compile(open(p).read(), p, "exec"), ns); result = ns["RESULT"]
# Contract measured on the original Ghost.blend (REF_Ghost_Original): slide -0.213 -> 1.126, bore z 0.2964,
# suppressor to the Muzzle at 2.054 (fixed to the frame, never moves with the slide); bones Root/Slide/Mag/Trigger/
# SlideCatch/MagRelease/Flash/Charm with the original heads (Charm moved to the new tab); slide locks back at -0.13.
# Changes: thicker (slide half width 0.059 -> 0.066, frame 0.052 -> 0.062, grip -> 0.064), 3-dot sights, a real
# port + hood, the slide's double slash in neon, finger grooves on the guard, two side levers, a hollow mag well,
# a trigger that clears the guard (the original's tip passed through the guard bottom), a hanging charm tab,
# a suppressor with a stepped rear, seam grooves and a recessed muzzle face.

import bpy, math, sys, importlib
from mathutils import Vector

ROOT = r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/art-source/weapons/RemasterV2"
sys.path.insert(0, ROOT + "/_Library")
import v2kit as K  # noqa: E402
import ammo as AM  # noqa: E402
import v2build as B  # noqa: E402

importlib.reload(K)
importlib.reload(AM)
importlib.reload(B)
from v2kit import BODY, PANEL, DARK, METAL, GRIP, ACCENT, NEON  # noqa: E402

GUN = "Ghost"
BORE = 0.2964
MUZZLE_X = 2.054
SW, FW, GW = 0.066, 0.062, 0.064
S0, S1 = 0.229, 0.39


def slash(x0, z0, z1):
	# one "/" bar leaning back: the concept's double slash
	return [(x0, z1), (x0 - 0.021, z1), (x0 - 0.055, z0), (x0 - 0.034, z0)]


def build_parts():
	parts = {}

	def part(name, bone="Root"):
		parts[name] = K.Part(name, bone)
		return parts[name]

	both = B.both

	# ================================================================ Slide
	sl = part("Slide", "Slide")
	sn = part("SlideNeon", "Slide")
	slide = B.solid(K.chamfer([(-0.213, S0), (1.126, S0), (1.126, S1), (-0.213, S1)], [0, 0.01, 0.02, 0.014]), K.section(SW, S0, S1, 0.026, 0.005), BODY, 0.003)
	cuts = []
	for i in range(7):
		x = -0.165 + i * 0.033
		cuts.append(both(K.prism([(x, 0.24), (x + 0.014, 0.24), (x + 0.02, 0.356), (x + 0.006, 0.356)], "Y", SW - 0.006, 0.2)))
	cuts.append(K.prism(K.chamfer([(0.333, 0.31), (0.50, 0.31), (0.50, 0.5), (0.333, 0.5)], [0.008, 0.008, 0, 0]), "Y", -0.2, 0.02))  # port (top + right)
	cuts.append(K.box(-0.06, 1.0, -0.005, 0.005, S1 - 0.0025, 0.5))  # sight groove
	cuts.append(K.prism(K.chamfer([(-0.036, 0.245), (0.036, 0.245), (0.036, 0.35), (-0.036, 0.35)], 0.008), "X", -0.4, -0.21))  # rear plate
	for x0 in (1.008, 0.962):
		cuts.append(both(K.prism(slash(x0, 0.27, 0.338), "Y", SW - 0.005, 0.2)))
	sl.add(K.cut(slide, K.group(*cuts), DARK))
	for x0 in (1.008, 0.962):
		sn.add(both(K.prism([(a - 0.002 if i in (0, 3) else a + 0.002, b) for i, (a, b) in enumerate(slash(x0, 0.272, 0.336))], "Y", SW - 0.0045, SW - 0.0015, NEON)))
	sl.add(K.prism([(1.012, 0.384), (1.072, 0.384), (1.066, 0.424), (1.012, 0.424)], "Y", -0.011, 0.011, DARK), 0.002)
	sn.add(K.box(1.0102, 1.0125, -0.0055, 0.0055, 0.405, 0.416, NEON))
	rear = K.bevel(K.prism([(-0.142, 0.384), (-0.058, 0.384), (-0.07, 0.43), (-0.134, 0.43)], "Y", -0.04, 0.04, DARK), 0.003, 1, 50)
	sl.add(K.cut(rear, K.box(-0.2, 0.0, -0.012, 0.012, 0.41, 0.5), DARK))
	sn.add(both(K.box(-0.1377, -0.1354, 0.0215, 0.0305, 0.413, 0.422, NEON)))  # v03: set into the sloped rear face

	# ================================================================ Suppressor + barrel (fixed to the frame)
	sp = part("Suppressor")
	can = K.cyl_x(1.205, MUZZLE_X, 0.1, 0.0, BORE, 24, DARK)
	can = K.bevel(can, 0.016, 1, 30)
	sp.add(K.cut(can, K.cyl_x(MUZZLE_X - 0.08, MUZZLE_X + 0.05, 0.024, 0.0, BORE, 12, DARK), DARK))  # bore in a closed end cap
	for x in (1.40,):  # a satin seam band (raised 0.003) instead of boolean grooves: same read, fewer tris
		sp.add(K.annulus_x(x, x + 0.012, 0.0, BORE, 0.103, 0.095, 24, METAL))
	sp.add(K.drop(K.annulus_x(MUZZLE_X - 0.002, MUZZLE_X + 0.003, 0.0, BORE, 0.062, 0.03, 16, PANEL), 0, -1))  # face ring
	sp.add(K.drop(K.cyl_x(1.165, 1.215, 0.088, 0.0, BORE, 16, PANEL), 0, 1), 0.004)  # stepped rear neck
	sp.add(K.cyl_x(1.118, 1.17, 0.07, 0.0, BORE, 16, METAL), 0.003)  # thread collar
	sp.add(K.drop(K.cyl_x(0.54, 1.13, 0.03, 0.0, BORE, 12, METAL), 0, 1))  # barrel (seen with the slide back)
	sp.add(K.prism(K.chamfer([(0.333, 0.262), (0.505, 0.262), (0.505, 0.352), (0.333, 0.352)], [0, 0, 0.008, 0.008]), "Y", -0.027, 0.027, METAL), 0.002)  # hood

	# ================================================================ Frame
	fr = part("Frame")
	frame = B.solid(K.chamfer([(1.118, 0.231), (-0.25, 0.231), (-0.25, 0.195), (-0.215, 0.14), (0.28, 0.105), (0.70, 0.105), (0.728, 0.169), (1.10, 0.169), (1.118, 0.19)],
		[0, 0.008, 0, 0, 0, 0, 0, 0, 0]), K.section(FW, 0.10, 0.231, 0.004, 0.01), DARK, 0.003)
	frame = K.cut(frame, K.group(both(K.box(0.76, 1.08, FW - 0.008, 0.2, 0.18, 0.196)), K.box(0.93, 0.955, -0.04, 0.04, 0.15, 0.178)), DARK)
	fr.add(frame)
	guard = K.bevel(K.prism([(0.28, 0.11), (0.28, -0.02), (0.30, -0.039), (0.65, -0.039), (0.676, -0.015), (0.70, 0.11)], "Y", -0.034, 0.034, DARK), 0.006, 1, 30)
	gcut = [K.prism(K.chamfer([(0.31, 0.16), (0.605, 0.16), (0.605, 0.03), (0.32, 0.008), (0.31, 0.02)], [0, 0, 0.012, 0.01, 0]), "Y", -0.1, 0.1)]
	gcut += [K.box(0.678, 0.75, -0.05, 0.05, z, z + 0.01) for z in (0.02, 0.045, 0.07)]  # finger grooves on the guard front
	fr.add(K.cut(guard, K.group(*gcut), DARK))
	fr.add(K.prism(K.chamfer([(0.52, 0.186), (0.60, 0.186), (0.60, 0.222), (0.52, 0.222)], 0.005), "Y", FW - 0.002, FW + 0.008, METAL), 0.002)  # takedown lever

	# ================================================================ Grip
	gr = part("Grip")
	gp = [(0.273, 0.105), (0.247, 0.047), (0.195, -0.065), (0.13, -0.273), (0.09, -0.40), (-0.236, -0.40), (-0.254, -0.36), (-0.249, -0.273), (-0.229, 0.052), (-0.213, 0.13), (-0.205, 0.14)]  # v03: longer grip (concept)
	grip = K.bevel(K.prism(gp, "Y", -GW, GW, DARK), 0.012, 2)
	grip = K.cut(grip, both(K.prism(K.chamfer([(0.18, 0.07), (-0.11, 0.085), (-0.19, -0.345), (0.05, -0.35)], 0.02), "Y", GW - 0.004, 0.2)), GRIP)
	well = K.prism([(0.104, 0.03), (-0.14, 0.03), (-0.225, -0.43), (0.066, -0.43)], "Y", -0.049, 0.049)
	grip = K.cut(grip, well, DARK)
	gr.add(grip)

	# ================================================================ Fasteners
	pins = part("Pins")
	for s in (1, -1):
		pins.add(B.head(0.45, 0.135, FW, r=0.007, side=s))
		pins.add(B.head(0.64, 0.15, FW, r=0.008, segs=8, side=s))

	# ================================================================ Charm tab (hangs under the dust cover, left; hole across Y)
	ch = part("CharmLoop")
	tab = [(0.828, 0.205), (0.892, 0.205)] + [(0.86 + 0.032 * math.cos(-a), 0.14 + 0.032 * math.sin(-a)) for a in [i * math.pi / 5 for i in range(6)]]
	tabbm = K.bevel(K.prism(tab, "Y", FW - 0.002, FW + 0.012, METAL), 0.003, 1, 50)
	ch.add(K.cut(tabbm, K.cyl_y(0.86, 0.14, 0.012, 0.0, 0.2, 10, METAL), DARK))
	ch.add(B.head(0.843, 0.188, FW + 0.012, r=0.006, h=0.003))
	ch.add(B.head(0.877, 0.188, FW + 0.012, r=0.006, h=0.003))

	# ================================================================ Moving parts
	mg = part("Mag", "Mag")
	mg.add(K.drop(K.prism([(0.099, 0.047), (-0.135, 0.073), (-0.216, -0.40), (0.07, -0.40)], "Y", -0.045, 0.045, METAL), 2, -1), 0.004)
	mg.add(AM.pistol_round(-0.095, 0.0, 0.085, scale=1.4))  # v02: brass-cased pistol round
	plate = B.solid(K.chamfer([(0.092, -0.394), (-0.252, -0.394), (-0.262, -0.423), (-0.25, -0.46), (0.088, -0.462), (0.11, -0.433)], [0, 0, 0.004, 0.01, 0.01, 0.004]), K.section(0.067, -0.468, -0.394, 0.004, 0.012), DARK, 0.003)
	plate = K.cut(plate, B.both(K.box(-0.3, 0.3, 0.063, 0.2, -0.422, -0.417)), DARK)  # two-tier line
	mg.add(plate)

	tg = part("Trigger", "Trigger")
	tp = [(0.415, 0.15), (0.447, 0.15), (0.45, 0.115), (0.444, 0.085), (0.432, 0.058), (0.416, 0.038), (0.408, 0.044), (0.42, 0.066), (0.428, 0.092), (0.427, 0.118), (0.418, 0.128)]
	tg.add(K.prism(tp, "Y", -0.011, 0.011, METAL), 0.002)
	tg.add(K.prism([(0.444, 0.108), (0.453, 0.106), (0.44, 0.068), (0.431, 0.071)], "Y", -0.0035, 0.0035, ACCENT))

	sc = part("SlideCatch", "SlideCatch")
	sc.add(K.prism(K.chamfer([(0.335, 0.186), (0.47, 0.186), (0.47, 0.222), (0.345, 0.222)], 0.004), "Y", FW - 0.002, FW + 0.009, METAL), 0.002)
	sc.add(K.box(0.35, 0.36, FW + 0.008, FW + 0.0115, 0.19, 0.218, METAL))

	mr = part("MagRelease", "MagRelease")
	btn = K.prism(K.chamfer([(0.19, 0.0), (0.238, 0.0), (0.252, 0.058), (0.204, 0.058)], 0.006), "Y", GW - 0.006, GW + 0.01, ACCENT)
	mr.add(K.cut(btn, K.group(*[K.box(0.17, 0.27, GW + 0.007, 0.2, z, z + 0.006) for z in (0.012, 0.025, 0.038)]), ACCENT))
	return parts


CHARM = (0.86, FW + 0.005, 0.14)
EJECT_RIGHT_UP = Vector((0.0, -0.8, 0.6)).to_track_quat("Z", "Y").to_matrix().to_4x4()
BONES = [
	("Root", None, (0.0, 0.0, 0.1)),
	("Slide", "Root", (0.468, 0.0, 0.312)),
	("Mag", "Root", (-0.026, 0.0, 0.0572)),
	("Trigger", "Root", (0.4316, 0.0, 0.1404)),
	("SlideCatch", "Root", (0.3432, FW, 0.2288)),
	("MagRelease", "Root", (0.221, GW, 0.0338)),
	("Flash", "Root", (MUZZLE_X + 0.01, 0.0, BORE)),
	("Charm", "Root", CHARM),
]
LOCATORS = [
	("Muzzle", "Root", (MUZZLE_X, 0.0, BORE), None),
	("RightGrip", "Root", (0.0, 0.0, 0.0), None),
	("LeftGrip", "Root", (0.0, 0.0, -0.08), None),
	("Eject", "Slide", (0.416, -0.042, 0.377), EJECT_RIGHT_UP),
	("CharmPoint", "Charm", CHARM, None),
	("Socket_Muzzle", "Root", (MUZZLE_X, 0.0, BORE), None),
	("Socket_Optic", "Slide", (0.30, 0.0, S1), None),
	("Socket_Under", "Root", (0.92, 0.0, 0.169), None),
]

RESULT = B.assemble(GUN, build_parts, BONES, LOCATORS, {"class": "Sidearm", "tier": "T1"})
