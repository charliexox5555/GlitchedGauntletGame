# build_sheriff_v2.py: RemasterV2 Sheriff (six-shot revolver), fresh rebuild from
# vault/02 Art/References/Gun-Image-Concepts/Charcoal Six-Shot Revolver Concept Sheet-7.png. Blender MCP only.
# Contract measured on the original Sheriff.blend (REF_Sheriff_Original): muzzle 1.495, bore z 0.2782, cylinder
# axis z 0.1898 from x 0.3172 (back) to 0.6292 (front), radius 0.143, chambers on r 0.088 (chamber 1 = top = bore),
# crane hinge (0.6292, 0.04, 0.026) swinging out to the left; bones Root/Crane/Cylinder/EjectorRod/Rounds/
# Speedloader/Hammer/Trigger/CylinderRelease/Flash/Charm (original heads, Charm moved), locators incl.
# CylinderAxis, Chamber_01..06, EjectorReference, ReloadInsertPoint. No Eject (cases leave at the reload).
# Changes: thicker frame (0.06 -> 0.064) and grip (0.055 -> 0.066), a frame window around the cylinder, fluted
# cylinder with chamber mouths and rear chambers holding the case heads, stepped underlug, serrated hammer spur,
# rounder guard with trigger clearance (the original tip sat 0.006 above the guard), front blade + rear notch with
# neon, hanging charm tab, and back under the 3K sidearm budget (the original was 3,432).

import bpy, math, sys, importlib
from mathutils import Matrix, Vector

ROOT = r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/art-source/weapons/RemasterV2"
sys.path.insert(0, ROOT + "/_Library")
import v2kit as K  # noqa: E402
import v2build as B  # noqa: E402

importlib.reload(K)
importlib.reload(B)
from v2kit import BODY, PANEL, DARK, METAL, GRIP, ACCENT, NEON, BRASS  # noqa: E402

GUN = "Sheriff"
BORE = 0.2782
MUZZLE_X = 1.495
CYL_Z, CYL_R, CH_R = 0.1898, 0.143, 0.088
CYL_FRONT, CYL_BACK = 0.6292, 0.3172
HINGE = (0.6292, 0.04, 0.026)
FW, GW = 0.064, 0.066


def chamber(i):
	a = math.radians(90 + 60 * (i - 1))
	return CH_R * math.cos(a), CYL_Z + CH_R * math.sin(a)


def around_x(bm, angle, z=CYL_Z):
	m = Matrix.Translation((0, 0, z)) @ Matrix.Rotation(angle, 4, "X") @ Matrix.Translation((0, 0, -z))
	return K.xform(bm, m)


def build_parts():
	parts = {}

	def part(name, bone="Root"):
		parts[name] = K.Part(name, bone)
		return parts[name]

	both = B.both

	# ================================================================ Frame with the cylinder window
	fr = part("Frame")
	outline = [(0.746, 0.372), (0.25, 0.372), (0.211, 0.364), (0.164, 0.317), (0.018, 0.208), (-0.081, 0.182), (-0.029, 0.114), (0.109, 0.073), (0.161, -0.018), (0.715, -0.018), (0.762, 0.047), (0.762, 0.359)]
	frame = B.solid(outline, K.section(FW, -0.03, 0.372, 0.014, 0.012), BODY, 0.003)
	window = K.prism(K.chamfer([(0.312, 0.052), (0.637, 0.052), (0.637, 0.333), (0.312, 0.333)], 0.01), "Y", -0.2, 0.2)
	ham_slot = K.box(0.0, 0.2, -0.022, 0.022, 0.2, 0.42)  # hammer slot in the rear of the top strap
	frame = K.cut(frame, K.group(window, ham_slot), DARK)
	fr.add(frame)
	# Stepped shoulder where the barrel enters the front block (the concept's two-level joint).
	fr.add(B.solid(K.chamfer([(0.75, 0.15), (0.80, 0.15), (0.80, 0.385), (0.75, 0.385)], [0, 0.01, 0.01, 0]), K.section(0.074, 0.15, 0.385, 0.018, 0.012), BODY, 0.003))
	# Rounded trigger guard (narrow), inner bottom lowered for trigger clearance.
	guard = K.bevel(K.prism(K.chamfer([(0.239, -0.01), (0.585, -0.01), (0.585, -0.15), (0.52, -0.232), (0.27, -0.232), (0.239, -0.17)], [0, 0, 0.06, 0.05, 0.045, 0.03]), "Y", -0.03, 0.03, BODY), 0.006, 1, 30)
	fr.add(K.cut(guard, K.prism(K.chamfer([(0.258, 0.0), (0.56, 0.0), (0.56, -0.13), (0.505, -0.202), (0.29, -0.202), (0.258, -0.15)], [0, 0, 0.05, 0.04, 0.035, 0.02]), "Y", -0.1, 0.1), BODY))

	# ================================================================ Barrel: octagon, crowned bore, stepped underlug
	br = part("Barrel")
	# v03: a slimmer octagonal barrel round the bore (concept), not v02's tall block.
	bar = B.solid(K.chamfer([(0.756, BORE - 0.072), (MUZZLE_X, BORE - 0.072), (MUZZLE_X, BORE + 0.07), (0.756, BORE + 0.07)], [0, 0.012, 0.012, 0]), K.section(0.068, BORE - 0.072, BORE + 0.07, 0.03, 0.03), BODY, 0.003)
	bar = K.cut(bar, K.group(K.cyl_x(MUZZLE_X - 0.08, MUZZLE_X + 0.05, 0.03, 0.0, BORE, 12, DARK), K.cyl_x(MUZZLE_X - 0.008, MUZZLE_X + 0.05, 0.044, 0.0, BORE, 12, DARK)), DARK)
	br.add(bar)
	# v03: one narrow underlug with an angled front (concept), joined to the barrel's underside.
	lug = [(0.756, BORE - 0.06), (1.30, BORE - 0.06), (1.30, 0.172), (1.215, 0.112), (0.756, 0.104)]
	br.add(B.solid(lug, K.section(0.046, 0.095, BORE - 0.05, 0.0, 0.016), BODY, 0.003))

	# ================================================================ Sights (+ neon)
	si = part("Sights")
	neon = part("Neon")
	si.add(K.prism([(1.29, BORE + 0.064), (1.436, BORE + 0.064), (1.43, 0.424), (1.40, 0.428), (1.31, 0.40), (1.29, 0.37)], "Y", -0.018, 0.018, DARK), 0.002)  # v03: ramp down to the lower barrel top
	neon.add(K.box(1.40, 1.428, -0.0125, 0.0125, 0.4235, 0.4275, NEON))  # insert on the blade top, seen from behind
	neon.add(K.prism([(1.3676, 0.4208), (1.3996, 0.4308), (1.4003, 0.4286), (1.3683, 0.4186)][::-1], "Y", -0.0125, 0.0125, NEON))  # strip on the sloped rear face (eye line)
	rear = K.bevel(K.prism([(0.247, 0.368), (0.325, 0.368), (0.318, 0.424), (0.254, 0.424)], "Y", -0.034, 0.034, DARK), 0.003, 1, 50)
	si.add(K.cut(rear, K.box(0.2, 0.4, -0.011, 0.011, 0.403, 0.5), DARK))
	neon.add(both(K.box(0.2508, 0.2531, 0.017, 0.026, 0.406, 0.415, NEON)))  # v03: set into the sloped rear face

	# ================================================================ Grip (wraps the frame; checkered panels)
	gr = part("Grip")
	gp = [(0.044, 0.13), (-0.073, 0.187), (-0.138, 0.13), (-0.212, -0.12), (-0.262, -0.30), (-0.262, -0.37), (-0.228, -0.414), (0.03, -0.42), (0.074, -0.39), (0.084, -0.33), (0.068, -0.28), (0.09, -0.225), (0.074, -0.17), (0.104, -0.11), (0.127, -0.065), (0.174, -0.026)]  # v03: long raked revolver grip with finger grooves (concept)
	grip = K.bevel(K.prism(gp, "Y", -GW, GW, DARK), 0.014, 2)
	grip = K.cut(grip, both(K.prism(K.chamfer([(0.02, 0.035), (-0.112, 0.072), (-0.218, -0.33), (-0.03, -0.372)], 0.024), "Y", GW - 0.004, 0.2)), GRIP)
	gr.add(grip)

	# ================================================================ Fasteners + release ring
	pins = part("Pins")
	for s in (1, -1):
		pins.add(B.head(0.20, 0.27, FW, r=0.008, segs=8, side=s))
		pins.add(B.head(0.12, 0.12, FW, r=0.007, side=s))
	pins.add(K.drop(K.cyl_y(0.2184, 0.0572, 0.024, FW - 0.003, FW + 0.003, 12, BODY), 1, -1))  # release surround (left)

	# ================================================================ Charm tab (hangs under the front block, left)
	ch = part("CharmLoop")
	tab = [(0.65, 0.03), (0.71, 0.03)] + [(0.68 + 0.03 * math.cos(-a), -0.035 + 0.03 * math.sin(-a)) for a in [i * math.pi / 5 for i in range(6)]]
	tabbm = K.bevel(K.prism(tab, "Y", FW - 0.002, FW + 0.012, METAL), 0.003, 1, 50)
	ch.add(K.cut(tabbm, K.cyl_y(0.68, -0.04, 0.011, 0.0, 0.2, 10, METAL), DARK))
	ch.add(B.head(0.68, 0.012, FW + 0.012, r=0.006, h=0.003))

	# ================================================================ Moving parts
	crane = part("Crane", "Crane")
	crane.add(K.prism([(-0.03, CYL_Z - 0.02), (0.03, CYL_Z - 0.02), (0.05, HINGE[2]), (0.03, HINGE[2] - 0.016), (-0.01, HINGE[2] - 0.016)], "X", CYL_FRONT + 0.03, CYL_FRONT, METAL), 0.003)
	crane.add(K.cyl_x(CYL_FRONT + 0.05, CYL_BACK + 0.02, 0.012, HINGE[1], HINGE[2], 8, METAL))

	cy = part("Cylinder", "Cylinder")
	body = K.bevel(K.cyl_x(CYL_BACK, CYL_FRONT, CYL_R, 0.0, CYL_Z, 18, METAL, rot=0.0), 0.012, 1, 25)
	cutters = []
	for i in range(1, 7):
		y, z = chamber(i)
		cutters.append(K.cyl_x(CYL_FRONT - 0.05, CYL_FRONT + 0.02, 0.031, y, z, 8, DARK))  # chamber mouth
		cutters.append(K.cyl_x(CYL_BACK - 0.02, CYL_BACK + 0.03, 0.031, y, z, 8, DARK))  # chamber at the rear
		fl = K.prism(K.stadium(CYL_BACK + 0.05, CYL_FRONT - 0.045, 0.0, 0.036, 2), "Z", CYL_Z + CYL_R - 0.018, CYL_Z + CYL_R + 0.05)
		cutters.append(around_x(fl, math.radians(30 + 60 * (i - 1))))
	cy.add(K.cut(body, K.group(*cutters), DARK))

	rounds = part("Rounds", "Rounds")
	for i in range(1, 7):
		y, z = chamber(i)
		rounds.add(K.cyl_x(CYL_BACK - 0.006, CYL_BACK + 0.15, 0.026, y, z, 6, BRASS, rot=0.0))  # v02: brass cases
		rounds.add(K.drop(K.cyl_x(CYL_BACK - 0.008, CYL_BACK - 0.002, 0.03, y, z, 6, BRASS, rot=0.0), 0, 1))  # case rim

	rod = part("EjectorRod", "EjectorRod")
	rod.add(K.cyl_x(CYL_FRONT - 0.002, 0.7526, 0.016, 0.0, CYL_Z, 8, METAL))
	rod.add(K.cyl_x(CYL_BACK - 0.012, CYL_BACK + 0.002, 0.05, 0.0, CYL_Z, 6, METAL, rot=math.radians(30)), 0.003)

	ham = part("Hammer", "Hammer")
	hp = [(0.174, 0.197), (0.140, 0.281), (0.109, 0.338), (0.075, 0.361), (0.013, 0.359), (0.023, 0.338), (0.075, 0.317), (0.101, 0.197)]  # v03: seated on the slot floor (v02 floated in the slot)
	hm = K.bevel(K.prism(hp, "Y", -0.019, 0.019, METAL), 0.003, 1, 40)
	hm = K.cut(hm, K.group(*[K.rot_y(K.box(x, x + 0.007, -0.05, 0.05, 0.35, 0.40), 0.12, (x, 0, 0.36)) for x in (0.025, 0.042, 0.059)]), METAL)
	ham.add(hm)

	tg = part("Trigger", "Trigger")
	tp = [(0.408, -0.0104), (0.369, -0.0104), (0.335, -0.052), (0.318, -0.112), (0.328, -0.162), (0.348, -0.168), (0.347, -0.117), (0.372, -0.057)]
	tg.add(K.prism(tp, "Y", -0.012, 0.012, METAL), 0.002)

	rl = part("CylinderRelease", "CylinderRelease")
	rl.add(K.drop(K.cyl_y(0.2184, 0.0572, 0.016, FW - 0.002, FW + 0.011, 12, ACCENT), 1, -1), 0.003)

	sp = part("Speedloader", "Speedloader")
	sp.add(K.cyl_x(CYL_BACK + 0.012, CYL_BACK + 0.032, 0.04, 0.0, CYL_Z, 8, DARK), 0.004)
	sp.add(K.cyl_x(CYL_BACK + 0.032, CYL_BACK + 0.06, 0.12, 0.0, CYL_Z, 12, DARK), 0.004)
	return parts


CHARM = (0.68, FW + 0.005, -0.04)
BONES = [
	("Root", None, (0.0, 0.0, 0.1)),
	("Crane", "Root", HINGE),
	("Cylinder", "Crane", (CYL_FRONT, 0.0, CYL_Z)),
	("EjectorRod", "Cylinder", (CYL_FRONT, 0.0, CYL_Z)),
	("Hammer", "Root", (0.1352, 0.0, 0.234)),
	("Trigger", "Root", (0.3874, 0.0, -0.0156)),
	("CylinderRelease", "Root", (0.2184, 0.066, 0.0572)),
	("Rounds", "Cylinder", (CYL_BACK, 0.0, CYL_Z)),
	("Speedloader", "Cylinder", (CYL_BACK, 0.0, CYL_Z)),
	("Flash", "Root", (MUZZLE_X + 0.01, 0.0, BORE)),
	("Charm", "Root", CHARM),
]
LOCATORS = [
	("Muzzle", "Root", (MUZZLE_X, 0.0, BORE), None),
	("RightGrip", "Root", (0.0, 0.0, 0.0), None),
	("LeftGrip", "Root", (0.0, 0.0, -0.08), None),
	("CylinderAxis", "Cylinder", (CYL_FRONT, 0.0, CYL_Z), None),
	*[("Chamber_%02d" % i, "Cylinder", (CYL_BACK, chamber(i)[0], chamber(i)[1]), None) for i in range(1, 7)],
	("EjectorReference", "EjectorRod", (0.7566, 0.0, CYL_Z), None),
	("ReloadInsertPoint", "Cylinder", (CYL_BACK, 0.0, CYL_Z), None),
	("CharmPoint", "Charm", CHARM, None),
	("Socket_Muzzle", "Root", (MUZZLE_X, 0.0, BORE), None),
	("Socket_Optic", "Root", (0.47, 0.0, 0.372), None),
	("Socket_Under", "Root", (1.10, 0.0, 0.091), None),
]

RESULT = B.assemble(GUN, build_parts, BONES, LOCATORS, {"class": "Sidearm", "tier": "T1"})
