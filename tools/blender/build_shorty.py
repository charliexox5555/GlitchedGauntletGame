# build_shorty.py: builds the Shorty (01, over-under break-action shotgun sidearm) in the open Blender scene.
# Re-running it replaces the gun.
#
#   g = {"__name__": "build", "__file__": path}; exec(compile(open(path).read(), path, "exec"), g); g["build"]()
#
# Family conventions in tools/blender/gunkit.py (+X muzzle, +Z up, +Y gun-left, studs, origin at the grip).
# Traced from the side view of vault/02 Art/References/Gun-Image-Concepts/Compact twin-barrel shotgun concept
# sheet-1.png in image pixels (P converts). Sidearm: no AimPoint (no ADS); LeftGrip sits on the grip like the
# family's pistols (two-handed pistol hold).
#
# Break action: the Barrels bone (both barrels, breech band and fore-end) hinges on the pin under the band; a
# positive rotation about its Y axis drops the muzzles. ShellUpper / ShellLower are reload props in the chambers
# (children of Barrels); the upper barrel is taken to fire first, so a one-shell reload swaps the upper shell.
# New references beyond the family set: MuzzleLower, EjectLower, ChamberUpper, ChamberLower, ForeGrip (all on
# Barrels).

import bmesh, bpy, importlib, math, os, sys
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gunkit

importlib.reload(gunkit)
from gunkit import DARK, METAL, NEON, PANEL, Part, box, charm_loop, cut, cyl_x, cyl_y, drop, group, mirror_y, prism

GUN = "Shorty"

# Side view -> studs: the grip (174 px tall) matches the family's grip size; muzzle (px 405) to grip back (1052)
# = 1.68 studs. Grip centre at (962, 880).
S = 0.0026
OX, OY = 962, 880


def X(px):
	return (OX - px) * S


def Z(py):
	return (OY - py) * S


def P(pts):
	return [(X(a), Z(b)) for a, b in pts]


UPPER_Z = Z(762)
LOWER_Z = Z(807)
HINGE = (752, 812)
BREECH_X = X(752)  # rear face of the barrel band = chamber mouths


def build_parts(mats):
	parts = {}

	def part(name, bone="Root"):
		parts[name] = Part(name, bone)
		return parts[name]

	fw = 0.055  # frame half width

	# ---- Frame (charcoal receiver/breech body, black grip and guard)
	fr = part("Frame")
	body = prism(P([(752, 735), (985, 735), (1000, 752), (1000, 815), (985, 828), (945, 860), (752, 860)]), "Y", -fw, fw)
	recess = mirror_y(box(X(985), X(940), fw - 0.008, fw + 0.02, Z(826), Z(800)))
	neon_pocket = mirror_y(box(X(916), X(884), fw - 0.005, fw + 0.02, Z(789.5), Z(781.5)))
	fr.add(cut(body, group(recess, neon_pocket), mats), 0)
	fr.add(prism(P([(920, 747), (925, 727), (958, 727), (963, 747)]), "Y", -0.026, 0.026, DARK), 0.004, 1)  # rear sight
	guard = prism(P([(755, 858), (896, 858), (896, 872), (880, 929), (790, 929), (768, 918)]), "Y", -0.022, 0.022, DARK)
	opening = prism(P([(790, 862), (873, 862), (873, 910), (800, 913), (790, 902)]), "Y", -0.05, 0.05)
	fr.add(cut(guard, opening, mats, DARK, bw=0.004, segs=1), 0)
	grip = prism(P([(905, 828), (985, 828), (1052, 955), (1052, 985), (1046, 1000), (948, 1002), (940, 990), (938, 940), (918, 880), (905, 862)]), "Y", -0.046, 0.046, DARK)
	panel = mirror_y(prism(P([(948, 884), (992, 872), (1030, 950), (1030, 974), (962, 978)]), "Y", 0.042, 0.06))
	fr.add(cut(grip, panel, mats, DARK, bw=0.01, segs=1), 0)
	fr.add(mirror_y(drop(cyl_y(X(HINGE[0]), Z(HINGE[1]), 0.022, fw - 0.002, fw + 0.008, 12), 1, -1)), 0.002, 1)  # hinge pin

	# ---- Barrels (break-action group): squared upper barrel, round lower barrel, breech band, muzzles, fore-end
	bar = part("Barrels", "Barrels")
	bw2 = 0.055
	oct_ = [(-bw2 + 0.014, Z(735)), (bw2 - 0.014, Z(735)), (bw2, Z(735) - 0.014), (bw2, Z(789) + 0.01), (bw2 - 0.01, Z(789)), (-bw2 + 0.01, Z(789)), (-bw2, Z(789) + 0.01), (-bw2, Z(735) - 0.014)]
	bar.add(prism(oct_, "X", X(717), X(425)), 0.006, 1)
	bar.add(drop(drop(cyl_x(X(717), X(425), 0.047, LOWER_Z, 16, mat=PANEL), 0, 1), 0, -1), 0)
	band = box(X(752), X(715), -0.058, 0.058, Z(832), Z(734))
	chambers = group(cyl_x(BREECH_X - 0.12, BREECH_X + 0.01, 0.034, UPPER_Z, 16), cyl_x(BREECH_X - 0.12, BREECH_X + 0.01, 0.034, LOWER_Z, 16))
	bar.add(cut(band, chambers, mats, METAL, bw=0.006, segs=1), 0)
	for zc in (UPPER_Z, LOWER_Z):
		ring = cyl_x(X(426), X(405), 0.052, zc, 16)
		bar.add(cut(ring, cyl_x(X(410), X(398), 0.033, zc, 16), mats, DARK, bw=0.006, segs=1), 0)
	bar.add(prism(P([(437, 737), (444, 721), (466, 721), (471, 737)]), "Y", -0.018, 0.018, DARK), 0.003, 1)  # front sight
	fore = prism(P([(470, 812), (480, 806), (722, 806), (722, 876), (640, 876), (632, 866), (495, 866), (470, 846)]), "Y", -0.052, 0.052)
	fpanel = mirror_y(prism(P([(492, 826), (632, 826), (632, 860), (500, 860)]), "Y", 0.047, 0.07))
	bar.add(cut(fore, fpanel, mats, DARK, bw=0.008, segs=1), 0)

	# ---- Neon (restrained: breech dash and grip front strip, both sides)
	neon = part("Neon")
	neon.add(mirror_y(box(X(914), X(886), fw - 0.004, fw - 0.0008, Z(788), Z(783), NEON)), 0)
	strip = prism(P([(920, 858), (928, 856), (934, 881), (926, 883)]), "Y", 0.046 - 0.002, 0.046 + 0.0025, NEON)
	neon.add(mirror_y(strip), 0)

	# ---- Charm (buddy) loop: left side of the rear breech block
	charm = part("CharmLoop")
	lug, tor = charm_loop(X(990), Z(796), fw + 0.002)
	charm.add(lug, 0.004, 1)
	charm.add(tor, 0)

	# ---- Moving parts
	latch = part("BreechLatch", "BreechLatch")
	latch.add(box(X(852), X(795), fw - 0.004, fw + 0.012, Z(835), Z(817), METAL), 0.003, 1)
	latch.add(box(X(830), X(818), fw + 0.01, fw + 0.02, Z(832), Z(820), METAL), 0.002, 1)

	trig = part("Trigger", "Trigger")
	trig.add(prism(P([(838, 864), (852, 864), (858, 878), (858, 894), (852, 908), (845, 910), (848, 894), (847, 880)]), "Y", -0.01, 0.01, METAL), 0.003, 1)

	for name, zc in (("ShellUpper", UPPER_Z), ("ShellLower", LOWER_Z)):
		sh = part(name, name)
		sh.add(cyl_x(BREECH_X - 0.005, BREECH_X + 0.2, 0.031, zc, 10, mat=DARK), 0.003, 1)  # hull
		sh.add(cyl_x(BREECH_X - 0.012, BREECH_X + 0.03, 0.035, zc, 10, mat=METAL), 0.003, 1)  # brass base and rim

	return parts


HINGE_POS = (X(HINGE[0]), 0.0, Z(HINGE[1]))
CHARM = (X(990), 0.055 + 0.002 + 0.012, Z(796) - 0.049)

BONES = [
	("Root", None, (0.0, 0.0, 0.1)),
	("Barrels", "Root", HINGE_POS),
	("ShellUpper", "Barrels", (BREECH_X, 0.0, UPPER_Z)),
	("ShellLower", "Barrels", (BREECH_X, 0.0, LOWER_Z)),
	("BreechLatch", "Root", (X(823), 0.06, Z(826))),
	("Trigger", "Root", (X(845), 0.0, Z(864))),
	("Flash", "Root", (X(405) + 0.01, 0.0, UPPER_Z)),
	("Charm", "Root", CHARM),
]

# Shells leave the chambers rearward and up when the barrels are open.
EJECT_BACK = Vector((-0.86, 0, 0.51)).to_track_quat("Z", "Y").to_matrix().to_4x4()  # local Z = eject direction

LOCATORS = [
	("Muzzle", "Barrels", (X(405), 0.0, UPPER_Z), None),
	("MuzzleLower", "Barrels", (X(405), 0.0, LOWER_Z), None),
	("RightGrip", "Root", (0.0, 0.0, 0.0), None),
	("LeftGrip", "Root", (0.0, 0.0, -0.08), None),
	("Eject", "Barrels", (BREECH_X, 0.0, UPPER_Z), EJECT_BACK),
	("EjectLower", "Barrels", (BREECH_X, 0.0, LOWER_Z), EJECT_BACK),
	("ForeGrip", "Barrels", (X(600), 0.0, Z(866)), None),  # support-hand spot on the fore-end (reload follow)
	("ChamberUpper", "Barrels", (BREECH_X + 0.1, 0.0, UPPER_Z), None),
	("ChamberLower", "Barrels", (BREECH_X + 0.1, 0.0, LOWER_Z), None),
	("CharmPoint", "Charm", CHARM, None),
]


def build():
	mats = gunkit.begin(GUN)
	parts = build_parts(mats)
	return gunkit.assemble(GUN, parts, mats, BONES, LOCATORS,
		{"class": "Sidearm", "tier": "T1", "template_version": 2, "length_rel": 0.43, "att_positions": "{}", "pbr": True})


if __name__ == "__main__":
	print(build())
