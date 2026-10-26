# build_sheriff.py: builds the Sheriff (07, heavy six-shot revolver) in the open Blender scene.
#
#   g = {"__name__": "build", "__file__": path}; exec(compile(open(path).read(), path, "exec"), g); g["build"]()
#
# Family conventions in tools/blender/gunkit.py. Traced from the side view of
# vault/02 Art/References/Gun-Image-Concepts/Charcoal Six-Shot Revolver Concept Sheet-7.png (P converts pixels).
# Sidearm: no AimPoint; LeftGrip on the grip (two-handed pistol hold). No ejection on firing (cases leave at the
# reload), so no Eject.
#
# Swing-out cylinder: the Crane hinges about X at the window's lower-left (a negative X rotation swings the
# cylinder out to the gun's left and down); the Cylinder (child of Crane) indexes about its own X axis (60 degrees
# a shot); the EjectorRod (child of Cylinder: rod + star) pushes rearward to kick the cases out. "Rounds" are the
# six cartridges (child of Cylinder; ejected by the star, brought back seated in the speedloader); "Speedloader"
# is the loader body (child of Cylinder, rests hidden inside it). New references: Crane, EjectorRod, Hammer,
# CylinderRelease, Rounds, Speedloader (bones); CylinderAxis,
# Chamber_01..Chamber_06, EjectorReference, ReloadInsertPoint (locators).

import bmesh, bpy, importlib, math, os, sys
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gunkit

importlib.reload(gunkit)
from gunkit import DARK, METAL, NEON, PANEL, Part, box, charm_loop, cut, cyl_x, cyl_y, drop, group, merge, mirror_y, prism

GUN = "Sheriff"

# Side view -> studs: muzzle (px 372) to grip back (1035) = 1.72 studs; grip close to the family grip.
# Grip centre at (947, 880).
S = 0.0026
OX, OY = 947, 880


def X(px):
	return (OX - px) * S


def Z(py):
	return (OY - py) * S


def P(pts):
	return [(X(a), Z(b)) for a, b in pts]


BORE_Z = Z(773)
CYL_Z = Z(807)
CYL_R = 0.143
CH_R = 0.088  # chamber circle radius
CYL_FRONT, CYL_BACK = X(705), X(825)
HINGE = (X(705), 0.04, Z(870))


def chamber(i):
	# Chamber i (1 = top, at the bore), counting the way the cylinder turns.
	a = math.radians(90 + 60 * (i - 1))
	return CH_R * math.cos(a), CYL_Z + CH_R * math.sin(a)


def around_x(bm, angle, centre):
	bmesh.ops.rotate(bm, verts=bm.verts[:], cent=centre, matrix=Matrix.Rotation(angle, 3, "X"))
	return bm


def build_parts(mats):
	parts = {}

	def part(name, bone="Root"):
		parts[name] = Part(name, bone)
		return parts[name]

	fw = 0.06  # frame half width

	# ---- Frame (charcoal): front block, top strap, bottom strap, rear frame; trigger guard
	fr = part("Frame")
	fr.add(prism(P([(654, 742), (660, 737), (702, 737), (702, 887), (672, 887), (654, 862)]), "Y", -fw, fw), 0.008, 1)
	fr.add(box(X(862), X(700), -fw, fw, Z(752), Z(737)), 0.006, 1)
	fr.add(prism(P([(700, 860), (845, 860), (852, 884), (700, 888)]), "Y", -fw, fw), 0.006, 1)
	fr.add(prism(P([(848, 740), (866, 740), (884, 758), (940, 800), (978, 810), (958, 836), (905, 852), (885, 884), (848, 884)]), "Y", -fw, fw), 0.008, 1)
	guard = prism(P([(722, 884), (855, 884), (855, 940), (840, 965), (750, 965), (722, 935)]), "Y", -0.026, 0.026)
	fr.add(cut(guard, prism(P([(732, 886), (850, 886), (850, 935), (836, 950), (752, 950), (732, 930)]), "Y", -0.06, 0.06), mats, PANEL, bw=0.004, segs=1), 0)

	# ---- Barrel (charcoal octagon with a flat top rib) and its underlug
	bw2 = 0.068
	top, bot = Z(735), Z(812)
	sect = [(-bw2 + 0.022, top), (bw2 - 0.022, top), (bw2, top - 0.022), (bw2, bot + 0.022), (bw2 - 0.022, bot), (-bw2 + 0.022, bot), (-bw2, bot + 0.022), (-bw2, top - 0.022)]
	bar = part("Barrel")
	bar.add(cut(prism(sect, "X", X(656), X(372)), cyl_x(X(380), X(364), 0.034, BORE_Z, 16), mats, DARK, bw=0.008, segs=1), 0)
	bar.add(prism(P([(440, 812), (560, 812), (656, 814), (656, 845), (560, 845), (560, 837), (452, 837), (440, 828)]), "Y", -0.042, 0.042), 0.006, 1)

	# ---- Sights: front blade with a blue top insert, rear notch with two blue dots
	si = part("Sights")
	si.add(prism(P([(395, 737), (399, 724), (408, 720), (440, 720), (445, 728), (445, 737)]), "Y", -0.02, 0.02, DARK), 0.003, 1)
	si.add(prism(P([(822, 740), (826, 722), (834, 717), (848, 717), (852, 724), (852, 740)]), "Y", -0.03, 0.03, DARK), 0.003, 1)

	# ---- Grip (black polymer, texture panel)
	grip = part("Grip")
	g = prism(P([(930, 830), (975, 808), (1000, 830), (1035, 960), (1035, 985), (1015, 1003), (905, 1003), (895, 985), (905, 940), (898, 905), (880, 890)]), "Y", -0.055, 0.055, DARK)
	grip.add(cut(g, mirror_y(prism(P([(940, 865), (990, 850), (1015, 970), (950, 985)]), "Y", 0.05, 0.08)), mats, DARK, bw=0.012, segs=1), 0)

	# ---- Neon: front sight top insert, rear sight dots
	neon = part("Neon")
	neon.add(box(X(436), X(407), -0.012, 0.012, Z(721.5), Z(719), NEON), 0)
	neon.add(group(cyl_y(X(833), Z(724), 0.006, 0.029, 0.031, 6, NEON), cyl_y(X(843), Z(724), 0.006, 0.029, 0.031, 6, NEON)), 0)
	n2 = group(cyl_y(X(833), Z(724), 0.006, 0.029, 0.031, 6, NEON), cyl_y(X(843), Z(724), 0.006, 0.029, 0.031, 6, NEON))
	neon.add(mirror_y(n2), 0)

	# ---- Charm (buddy) loop: left side of the frame's front, ahead of the trigger guard
	charm = part("CharmLoop")
	lug, tor = charm_loop(X(686), Z(872), fw + 0.002)
	charm.add(lug, 0.004, 1)
	charm.add(tor, 0)

	# ---- Moving parts
	crane = part("Crane", "Crane")
	crane.add(prism([(-0.03, CYL_Z - 0.02), (0.03, CYL_Z - 0.02), (0.05, HINGE[2]), (0.03, HINGE[2] - 0.016), (-0.01, HINGE[2] - 0.016)], "X", CYL_FRONT + 0.03, CYL_FRONT, METAL), 0.004, 1)
	crane.add(cyl_x(CYL_FRONT + 0.05, CYL_BACK - 0.01, 0.012, HINGE[2], 8, y=HINGE[1]), 0.002, 1)  # hinge pin

	cyl = part("Cylinder", "Cylinder")
	body = cyl_x(CYL_BACK, CYL_FRONT, CYL_R, CYL_Z, 24, mat=METAL)
	cutters = bmesh.new()
	for i in range(1, 7):
		y, z = chamber(i)
		merge(cutters, cyl_x(CYL_FRONT + 0.01, CYL_FRONT - 0.06, 0.03, z, 12, y=y))  # chamber mouths (front)
		merge(cutters, cyl_x(CYL_BACK + 0.06, CYL_BACK - 0.01, 0.031, z, 12, y=y))  # chamber ends (rear)
		flute = box(CYL_BACK + 0.03, CYL_FRONT - 0.03, -0.017, 0.017, CYL_Z + CYL_R - 0.016, CYL_Z + CYL_R + 0.05)
		merge(cutters, around_x(flute, math.radians(30 + 60 * (i - 1)), (0, 0, CYL_Z)))
	cyl.add(cut(body, cutters, mats, DARK, bw=0.008, segs=2), 0)
	rounds = part("Rounds", "Rounds")  # the six cartridges, seated in the chambers (case heads show at the rear)
	for i in range(1, 7):
		y, z = chamber(i)
		rounds.add(cyl_x(CYL_BACK - 0.004, CYL_BACK + 0.16, 0.027, z, 8, y=y, mat=METAL), 0.002, 1)

	rod = part("EjectorRod", "EjectorRod")
	rod.add(cyl_x(CYL_FRONT - 0.002, X(656) - 0.004, 0.016, CYL_Z, 10), 0.003, 1)
	star = cyl_x(CYL_BACK + 0.012, CYL_BACK - 0.002, 0.05, CYL_Z, 6, rot=math.radians(30))
	rod.add(star, 0.003, 1)

	ham = part("Hammer", "Hammer")
	ham.add(prism(P([(880, 795), (893, 772), (905, 750), (918, 741), (942, 742), (938, 750), (918, 758), (908, 795)]), "Y", -0.016, 0.016, METAL), 0.004, 1)

	trig = part("Trigger", "Trigger")
	trig.add(prism(P([(790, 884), (805, 884), (818, 900), (826, 925), (822, 946), (812, 948), (812, 925), (804, 902)]), "Y", -0.011, 0.011, METAL), 0.003, 1)

	rel = part("CylinderRelease", "CylinderRelease")
	rel.add(cyl_y(X(863), Z(858), 0.016, fw - 0.002, fw + 0.009, 12), 0.003, 1)

	sl = part("Speedloader", "Speedloader")
	# The loader body only (the cartridges are "Rounds"). At rest it sits inside the closed cylinder, hidden; in the
	# reload it brings the Rounds in from below and pulls away empty.
	sl.add(cyl_x(CYL_BACK + 0.012, CYL_BACK + 0.032, 0.04, CYL_Z, 10, mat=DARK), 0.006, 1)  # knob
	sl.add(cyl_x(CYL_BACK + 0.032, CYL_BACK + 0.06, 0.12, CYL_Z, 16, mat=DARK), 0.006, 1)  # body

	return parts


CHARM = (X(686), 0.06 + 0.002 + 0.012, Z(872) - 0.049)

BONES = [
	("Root", None, (0.0, 0.0, 0.1)),
	("Crane", "Root", HINGE),
	("Cylinder", "Crane", (CYL_FRONT, 0.0, CYL_Z)),
	("EjectorRod", "Cylinder", (CYL_FRONT, 0.0, CYL_Z)),
	("Hammer", "Root", (X(895), 0.0, Z(790))),
	("Trigger", "Root", (X(798), 0.0, Z(886))),
	("CylinderRelease", "Root", (X(863), 0.066, Z(858))),
	("Rounds", "Cylinder", (CYL_BACK, 0.0, CYL_Z)),
	("Speedloader", "Cylinder", (CYL_BACK, 0.0, CYL_Z)),
	("Flash", "Root", (X(372) + 0.01, 0.0, BORE_Z)),
	("Charm", "Root", CHARM),
]

LOCATORS = [
	("Muzzle", "Root", (X(372), 0.0, BORE_Z), None),
	("RightGrip", "Root", (0.0, 0.0, 0.0), None),
	("LeftGrip", "Root", (0.0, 0.0, -0.08), None),
	("CylinderAxis", "Cylinder", (CYL_FRONT, 0.0, CYL_Z), None),
	*[("Chamber_%02d" % i, "Cylinder", (CYL_BACK, chamber(i)[0], chamber(i)[1]), None) for i in range(1, 7)],
	("EjectorReference", "EjectorRod", (X(656), 0.0, CYL_Z), None),
	("ReloadInsertPoint", "Cylinder", (CYL_BACK, 0.0, CYL_Z), None),
	("CharmPoint", "Charm", CHARM, None),
]


def build():
	mats = gunkit.begin(GUN)
	parts = build_parts(mats)
	return gunkit.assemble(GUN, parts, mats, BONES, LOCATORS,
		{"class": "Sidearm", "tier": "T1", "template_version": 2, "length_rel": 0.44, "att_positions": "{}", "pbr": True})


if __name__ == "__main__":
	print(build())
