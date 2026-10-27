# build_shorty.py: builds the Shorty (01, sawed-off side-by-side double-barrel sidearm) in the open Blender scene.
# Re-running it replaces the gun.
#
#   g = {"__name__": "build", "__file__": path}; exec(compile(open(path).read(), path, "exec"), g); g["build"]()
#
# Family conventions in tools/blender/gunkit.py (+X muzzle, +Z up, +Y gun-left, studs, origin at the grip).
# Traced from the side view of vault/02 Art/References/Gun-Image-Concepts/Compact twin-barrel shotgun concept
# sheet-1.png in image pixels (P converts). Sidearm: no AimPoint (no ADS); LeftGrip sits on the grip like the
# family's pistols (two-handed pistol hold).
#
# Round 2 redesign (2026-10-26): a regular sawed-off side-by-side double-barrel (the user's note), wider and chunkier.
# The old over-under names are kept so the game needs no new rules: "Upper" = the LEFT barrel (+Y, fires first),
# "Lower" = the RIGHT barrel (-Y).
# Break action: the Barrels bone (both barrels, breech band and fore-end) hinges on the pin under the band; a
# positive rotation about its Y axis drops the muzzles. ShellUpper / ShellLower are reload props in the chambers
# (children of Barrels); the left barrel is taken to fire first, so a one-shell reload swaps ShellUpper.
# New references beyond the family set: MuzzleLower, EjectLower, ChamberUpper, ChamberLower, ForeGrip (all on
# Barrels).

import bmesh, bpy, importlib, math, os, sys
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gunkit

importlib.reload(gunkit)
from gunkit import DARK, METAL, NEON, PANEL, Part, box, charm_loop, cut, cyl_x, cyl_y, drop, group, mirror_y, prism  # noqa: F401

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


BORE_Z = Z(780)
BY = 0.05  # barrel centres at Y = +-BY (left = "Upper", right = "Lower")
BR = 0.045  # barrel radius
UPPER_Y, LOWER_Y = BY, -BY
UPPER_Z = LOWER_Z = BORE_Z
HINGE = (752, 836)
BREECH_X = X(752)  # rear face of the barrel band = chamber mouths
FW = 0.085  # frame half width


def build_parts(mats):
	parts = {}

	def part(name, bone="Root"):
		parts[name] = Part(name, bone)
		return parts[name]

	fw = FW

	# ---- Frame (charcoal action body with a standing breech, black grip and guard)
	fr = part("Frame")
	body = prism(P([(752, 752), (985, 752), (1000, 768), (1000, 815), (985, 828), (945, 860), (752, 860)]), "Y", -fw, fw)
	recess = mirror_y(box(X(985), X(940), fw - 0.008, fw + 0.02, Z(826), Z(800)))
	neon_pocket = mirror_y(box(X(916), X(884), fw - 0.005, fw + 0.02, Z(789.5), Z(781.5)))
	plate = mirror_y(prism(P([(770, 768), (900, 768), (930, 800), (930, 845), (770, 845)]), "Y", fw - 0.004, fw + 0.02))
	fr.add(cut(body, group(recess, neon_pocket, plate), mats), 0)
	fr.add(prism(P([(930, 755), (935, 742), (962, 742), (967, 755)]), "Y", -0.03, 0.03, DARK), 0.004, 1)  # rear notch block
	guard = prism(P([(755, 858), (896, 858), (896, 872), (880, 929), (790, 929), (768, 918)]), "Y", -0.026, 0.026, DARK)
	opening = prism(P([(790, 862), (873, 862), (873, 910), (800, 913), (790, 902)]), "Y", -0.06, 0.06)
	fr.add(cut(guard, opening, mats, DARK, bw=0.004, segs=1), 0)
	grip = prism(P([(905, 828), (985, 828), (1052, 955), (1052, 985), (1046, 1000), (948, 1002), (940, 990), (938, 940), (918, 880), (905, 862)]), "Y", -0.05, 0.05, DARK)
	panel = mirror_y(prism(P([(948, 884), (992, 872), (1030, 950), (1030, 974), (962, 978)]), "Y", 0.046, 0.065))
	fr.add(cut(grip, panel, mats, DARK, bw=0.01, segs=1), 0)
	fr.add(mirror_y(drop(cyl_y(X(HINGE[0]), Z(HINGE[1]), 0.024, fw - 0.002, fw + 0.008, 12), 1, -1)), 0.002, 1)  # hinge pin

	# ---- Barrels (break-action group): two short barrels side by side, top rib, breech band, muzzles, fore-end
	bar = part("Barrels", "Barrels")
	for y in (UPPER_Y, LOWER_Y):
		bar.add(drop(drop(cyl_x(X(717), X(426), BR, BORE_Z, 16, y=y, mat=METAL), 0, 1), 0, -1), 0)
		ring = cyl_x(X(428), X(405), BR + 0.006, BORE_Z, 16, y=y, mat=DARK)
		bar.add(cut(ring, cyl_x(X(410), X(398), BR * 0.7, BORE_Z, 16, y=y), mats, DARK, bw=0.005, segs=1), 0)
	rib = box(X(717), X(428), -0.022, 0.022, BORE_Z + 0.02, BORE_Z + 0.052, DARK)  # flat top rib in the valley
	bar.add(rib, 0.004, 1)
	bar.add(box(X(717), X(428), -0.03, 0.03, BORE_Z - 0.04, BORE_Z, DARK), 0.003, 1)  # bottom web
	bar.add(cyl_y(X(440), BORE_Z + 0.062, 0.011, -0.011, 0.011, 8, METAL), 0.002, 1)  # front bead
	band = box(X(752), X(715), -0.1, 0.1, Z(845), Z(752))
	chambers = group(*[cyl_x(BREECH_X - 0.12, BREECH_X + 0.01, 0.034, BORE_Z, 16, y=y) for y in (UPPER_Y, LOWER_Y)])
	bar.add(cut(band, chambers, mats, METAL, bw=0.008, segs=1), 0)
	fore = prism(P([(470, 812), (480, 804), (722, 804), (722, 878), (640, 878), (632, 868), (495, 868), (470, 848)]), "Y", -0.082, 0.082)
	fpanel = mirror_y(prism(P([(492, 826), (632, 826), (632, 860), (500, 860)]), "Y", 0.077, 0.1))
	bar.add(cut(fore, fpanel, mats, DARK, bw=0.01, segs=1), 0)

	# ---- Neon (restrained: breech dash and grip front strip, both sides)
	neon = part("Neon")
	neon.add(mirror_y(box(X(914), X(886), fw - 0.004, fw - 0.0008, Z(788), Z(783), NEON)), 0)
	strip = prism(P([(920, 858), (928, 856), (934, 881), (926, 883)]), "Y", 0.05 - 0.002, 0.05 + 0.0025, NEON)
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

	for name, y in (("ShellUpper", UPPER_Y), ("ShellLower", LOWER_Y)):
		sh = part(name, name)
		sh.add(cyl_x(BREECH_X - 0.005, BREECH_X + 0.2, 0.031, BORE_Z, 10, y=y, mat=DARK), 0.003, 1)  # hull
		sh.add(cyl_x(BREECH_X - 0.012, BREECH_X + 0.03, 0.035, BORE_Z, 10, y=y, mat=METAL), 0.003, 1)  # brass base and rim

	return parts


HINGE_POS = (X(HINGE[0]), 0.0, Z(HINGE[1]))
CHARM = (X(990), FW + 0.002 + 0.012, Z(796) - 0.049)

BONES = [
	("Root", None, (0.0, 0.0, 0.1)),
	("Barrels", "Root", HINGE_POS),
	("ShellUpper", "Barrels", (BREECH_X, UPPER_Y, BORE_Z)),
	("ShellLower", "Barrels", (BREECH_X, LOWER_Y, BORE_Z)),
	("BreechLatch", "Root", (X(823), FW + 0.005, Z(826))),
	("Trigger", "Root", (X(845), 0.0, Z(864))),
	("Flash", "Root", (X(405) + 0.01, 0.0, BORE_Z)),
	("Charm", "Root", CHARM),
]

# Shells leave the chambers rearward and up when the barrels are open.
EJECT_BACK = Vector((-0.86, 0, 0.51)).to_track_quat("Z", "Y").to_matrix().to_4x4()  # local Z = eject direction

LOCATORS = [
	("Muzzle", "Barrels", (X(405), UPPER_Y, BORE_Z), None),  # left barrel
	("MuzzleLower", "Barrels", (X(405), LOWER_Y, BORE_Z), None),  # right barrel
	("RightGrip", "Root", (0.0, 0.0, 0.0), None),
	("LeftGrip", "Root", (0.0, 0.0, -0.08), None),
	("Eject", "Barrels", (BREECH_X, UPPER_Y, BORE_Z), EJECT_BACK),
	("EjectLower", "Barrels", (BREECH_X, LOWER_Y, BORE_Z), EJECT_BACK),
	("ForeGrip", "Barrels", (X(600), 0.0, Z(868)), None),  # support-hand spot on the fore-end (reload follow)
	("ChamberUpper", "Barrels", (BREECH_X + 0.1, UPPER_Y, BORE_Z), None),
	("ChamberLower", "Barrels", (BREECH_X + 0.1, LOWER_Y, BORE_Z), None),
	("CharmPoint", "Charm", CHARM, None),
]


def build():
	mats = gunkit.begin(GUN)
	parts = build_parts(mats)
	return gunkit.assemble(GUN, parts, mats, BONES, LOCATORS,
		{"class": "Sidearm", "tier": "T1", "template_version": 2, "length_rel": 0.43, "att_positions": "{}", "pbr": True})


if __name__ == "__main__":
	print(build())
