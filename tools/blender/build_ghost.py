# build_ghost.py: builds the Ghost (02, slim suppressed semi-automatic pistol) in the open Blender scene.
#
#   g = {"__name__": "build", "__file__": path}; exec(compile(open(path).read(), path, "exec"), g); g["build"]()
#
# Family conventions in tools/blender/gunkit.py. Traced from the side view of
# vault/02 Art/References/Gun-Image-Concepts/Ghost pistol concept sheet-2.png (P converts image pixels).
# Sidearm: no AimPoint; LeftGrip on the grip (two-handed pistol hold).
#
# The Slide (with its blue slashes and sights) moves back on its own; the barrel and suppressor are fixed to the
# frame so the suppressor never travels with the slide. New bones beyond the family set: SlideCatch, MagRelease.
# Last-shot hold-open: the slide's locked-back pose is Slide at -0.13 on X (ReloadEmpty starts there).

import bmesh, bpy, importlib, math, os, sys
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gunkit

importlib.reload(gunkit)
from gunkit import DARK, METAL, NEON, PANEL, Part, box, charm_loop, cut, cyl_x, cyl_y, drop, group, mirror_y, prism

GUN = "Ghost"

# Side view -> studs: grip height (162 px) close to the family grip; slide front (547) to frame rear (1072)
# = 1.37 studs, suppressor front at px 190. Grip centre at (980, 880).
S = 0.0026
OX, OY = 980, 880


def X(px):
	return (OX - px) * S


def Z(py):
	return (OY - py) * S


def P(pts):
	return [(X(a), Z(b)) for a, b in pts]


BORE_Z = Z(766)


def slash(x0):
	# One slanted blue bar of the slide's double slash.
	return [(x0, 750), (x0 + 8, 750), (x0 + 21, 777), (x0 + 13, 777)]


def build_parts(mats):
	parts = {}

	def part(name, bone="Root"):
		parts[name] = Part(name, bone)
		return parts[name]

	sw = 0.042  # slide half width
	fw = 0.04  # frame half width

	# ---- Slide (charcoal metal): port step on top, rear serrations, neon pockets, sights
	sl = part("Slide", "Slide")
	body = prism(P([(547, 738), (555, 730), (1050, 730), (1062, 742), (1062, 792), (552, 792), (547, 786)]), "Y", -sw, sw)
	port = box(X(852), X(787), -sw - 0.02, sw - 0.012, Z(739), Z(724))
	serr = group(*[prism(P([(x, 744), (x + 6, 744), (x + 11, 788), (x + 5, 788)]), "Y", sw - 0.005, sw + 0.02) for x in range(950, 1030, 13)])
	mirror_y(serr)
	pockets = mirror_y(group(prism(P(slash(592)), "Y", sw - 0.005, sw + 0.02), prism(P(slash(610)), "Y", sw - 0.005, sw + 0.02)))
	sl.add(cut(body, group(port, serr, pockets), mats, DARK, bw=0.006), 0)
	sl.add(prism(P([(560, 731), (563, 718), (590, 718), (593, 731)]), "Y", -0.012, 0.012, DARK), 0.002, 1)  # front sight
	sl.add(prism(P([(990, 731), (995, 713), (1026, 713), (1030, 731)]), "Y", -0.03, 0.03, DARK), 0.003, 1)  # rear sight
	sn = part("SlideNeon", "Slide")
	sn.add(mirror_y(group(prism(P(slash(592)), "Y", sw - 0.004, sw - 0.0008, NEON), prism(P(slash(610)), "Y", sw - 0.004, sw - 0.0008, NEON))), 0)

	# ---- Barrel and suppressor (fixed to the frame)
	bs = part("Suppressor")
	can = cyl_x(X(530), X(190), 0.1, BORE_Z, 32, mat=DARK)
	bs.add(cut(can, cyl_x(X(196), X(182), 0.024, BORE_Z, 16), mats, DARK, bw=0.016, segs=2), 0)
	bs.add(drop(drop(cyl_x(X(498), X(492), 0.095, BORE_Z, 32, mat=METAL), 0, 1), 0, -1), 0)  # seam
	bs.add(cyl_x(X(549), X(528), 0.075, BORE_Z, 16, mat=METAL), 0.005, 1)  # thread collar
	bs.add(drop(cyl_x(X(760), X(540), 0.03, BORE_Z, 12), 0, 1), 0)  # barrel, seen when the slide runs back
	bs.add(box(X(852), X(787), -0.02, 0.02, Z(745), Z(733), METAL), 0.002, 1)  # barrel hood seen through the port

	# ---- Frame (black polymer): dust cover, body, trigger guard, grip with texture panel
	fr = part("Frame")
	cover = prism(P([(550, 790), (700, 790), (700, 815), (560, 815), (550, 808)]), "Y", -fw, fw, DARK)
	body = prism(P([(697, 790), (1066, 790), (1072, 806), (1062, 830), (1068, 860), (1075, 985), (1068, 1000), (940, 1000), (930, 985), (905, 905), (885, 862), (875, 842), (697, 842)]), "Y", -fw, fw, DARK)
	guard = prism(P([(720, 838), (880, 838), (888, 862), (882, 895), (748, 895), (722, 882)]), "Y", -0.026, 0.026, DARK)
	opening = prism(P([(746, 822), (867, 822), (867, 877), (754, 877), (746, 868)]), "Y", -0.06, 0.06)
	panel = mirror_y(prism(P([(912, 852), (1022, 846), (1042, 975), (952, 980)]), "Y", fw - 0.004, fw + 0.02))
	rail = mirror_y(box(X(690), X(565), fw - 0.004, fw + 0.02, Z(808), Z(800)))
	fr.add(cut(group(cover, body, guard), group(opening, panel, rail), mats, DARK, bw=0.008), 0)

	# ---- Neon: none on the frame (the concept keeps the blue on the slide)

	# ---- Charm (buddy) loop: left side of the frame's dust cover, ahead of the trigger guard
	charm = part("CharmLoop")
	lug, tor = charm_loop(X(650), Z(806), fw + 0.002)
	charm.add(lug, 0.004, 1)
	charm.add(tor, 0)

	# ---- Moving parts
	mag = part("Mag", "Mag")
	mag.add(prism(P([(942, 862), (1032, 852), (1060, 1000), (945, 1000)]), "Y", -0.03, 0.03, DARK), 0.006, 1)  # body (inside the grip when seated)
	mag.add(prism(P([(930, 999), (1052, 999), (1055, 1012), (927, 1012)]), "Y", -0.044, 0.044, DARK), 0.005, 1)  # baseplate

	trig = part("Trigger", "Trigger")
	trig.add(prism(P([(808, 826), (820, 826), (828, 842), (830, 860), (824, 878), (816, 880), (820, 862), (816, 842)]), "Y", -0.009, 0.009, METAL), 0.003, 1)

	catch = part("SlideCatch", "SlideCatch")
	catch.add(box(X(852), X(797), fw - 0.002, fw + 0.01, Z(801), Z(784), DARK), 0.003, 1)

	rel = part("MagRelease", "MagRelease")
	rel.add(box(X(910), X(880), fw - 0.004, fw + 0.008, Z(880), Z(855), DARK), 0.003, 1)

	return parts


CHARM = (X(650), 0.04 + 0.002 + 0.012, Z(806) - 0.049)

BONES = [
	("Root", None, (0.0, 0.0, 0.1)),
	("Slide", "Root", (X(800), 0.0, Z(760))),
	("Mag", "Root", (X(990), 0.0, Z(858))),
	("Trigger", "Root", (X(814), 0.0, Z(826))),
	("SlideCatch", "Root", (X(848), 0.046, Z(792))),
	("MagRelease", "Root", (X(895), 0.044, Z(867))),
	("Flash", "Root", (X(190) + 0.01, 0.0, BORE_Z)),
	("Charm", "Root", CHARM),
]

EJECT_RIGHT_UP = Vector((0, -0.8, 0.6)).to_track_quat("Z", "Y").to_matrix().to_4x4()  # local Z = eject direction

LOCATORS = [
	("Muzzle", "Root", (X(190), 0.0, BORE_Z), None),  # suppressor exit
	("RightGrip", "Root", (0.0, 0.0, 0.0), None),
	("LeftGrip", "Root", (0.0, 0.0, -0.08), None),
	("Eject", "Slide", (X(820), -0.03, Z(735)), EJECT_RIGHT_UP),
	("CharmPoint", "Charm", CHARM, None),
]


def build():
	mats = gunkit.begin(GUN)
	parts = build_parts(mats)
	return gunkit.assemble(GUN, parts, mats, BONES, LOCATORS,
		{"class": "Sidearm", "tier": "T1", "template_version": 2, "length_rel": 0.64, "att_positions": "{}", "pbr": True}, widen={"*": 1.4, "Suppressor": 1.0, "Frame": 1.3, "Mag": 1.25, "Trigger": 1.0})


if __name__ == "__main__":
	print(build())
