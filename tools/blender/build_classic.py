# build_classic.py: builds the Classic (00, the sidearm benchmark) in the open Blender scene.
#
#   g = {"__name__": "build", "__file__": path}; exec(compile(open(path).read(), path, "exec"), g); g["build"]()
#
# Family conventions in tools/blender/gunkit.py. Traced from the lower (true side) profile of
# vault/02 Art/References/Gun-Image-Concepts/Classic Pistol Two-View Concept Sheet.png (P converts pixels); the
# three-quarter hero above it gives the depth. Brief: section 00 of vault/01 Design/Gauntlet_Weapon_Modeling_Briefs.md.
# Slide with a chamfered top, rear serrations, the sights and a neon bar; the port is on the right (the sheet shows
# a plain left side). Barrel is its own bone (the Muzzle rides it, so effects don't move with the slide); it tilts a
# touch while the slide is locked back. Magazine hidden in the grip with only the base plate (and its neon) showing.
# No AimPoint (no ADS); LeftGrip sits on the grip like the Ghost's.

import bmesh, bpy, importlib, math, os, sys
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gunkit

importlib.reload(gunkit)
from gunkit import DARK, METAL, NEON, PANEL, Part, box, charm_loop, cut, cyl_x, cyl_y, drop, group, mirror_y, prism

GUN = "Classic"

# Side view -> studs: muzzle (px 505) to slide rear (942) = 1.27 studs (the Ghost is 1.37). Grip at (850, 880).
S = 0.0029
OX, OY = 850, 880


def X(px):
	return (OX - px) * S


def Z(py):
	return (OY - py) * S


def P(pts):
	return [(X(a), Z(b)) for a, b in pts]


BORE_Z = Z(754)
SW = 0.046  # slide half width
FW = 0.044  # frame half width
GW = 0.052  # grip half width
MW = 0.033  # magazine half width
CH = 0.016  # slide top chamfer (inward)


def build_parts(mats):
	parts = {}

	def part(name, bone="Root"):
		parts[name] = Part(name, bone)
		return parts[name]

	# ---- Slide: chamfered top, front/rear corner chamfers, panel grooves, rear serrations, right-side port, bore,
	# neon pocket, sights
	sl = part("Slide", "Slide")
	prof = [(-SW, Z(782)), (SW, Z(782)), (SW, Z(748)), (SW - CH, Z(729)), (-SW + CH, Z(729)), (-SW, Z(748))]
	body = prism(prof, "X", X(942), X(505), DARK)  # matte black slide
	corners = group(prism(P([(498, 722), (519, 722), (498, 741)]), "Y", -0.1, 0.1), prism(P([(928, 722), (950, 722), (950, 746)]), "Y", -0.1, 0.1))
	grooves = mirror_y(group(box(X(570), X(567), SW - 0.004, SW + 0.02, Z(782), Z(749)), box(X(754), X(751), SW - 0.004, SW + 0.02, Z(782), Z(749))))
	serr = mirror_y(group(*[prism(P([(a, 742), (a + 4, 742), (a + 6, 781), (a + 2, 781)]), "Y", SW - 0.006, SW + 0.02) for a in (843, 855, 867, 878, 890, 901)]))
	port = box(X(722), X(640), -SW - 0.03, SW - 0.014, Z(760), Z(722))
	bore = cyl_x(X(512), X(495), 0.022, BORE_Z, 12)
	pocket = mirror_y(box(X(843), X(814), SW - 0.005, SW + 0.02, Z(780), Z(773)))
	sl.add(cut(body, group(corners, grooves, serr, port, bore, pocket), mats, DARK, bw=0.005), 0)
	sl.add(prism(P([(522, 731), (528, 714), (546, 714), (550, 731)]), "Y", -0.012, 0.012, DARK), 0.002, 1)  # front sight
	rear = prism(P([(880, 731), (886, 714), (914, 714), (920, 731)]), "Y", -0.03, 0.03, DARK)
	sl.add(cut(rear, box(X(925), X(875), -0.008, 0.008, Z(724), Z(710)), mats, DARK, bw=0.003, segs=1), 0)
	sn = part("SlideNeon", "Slide")
	sn.add(mirror_y(box(X(842), X(815), SW - 0.004, SW - 0.0008, Z(779), Z(774), NEON)), 0)

	# ---- Barrel (own bone): tube to the muzzle face and the hood seen through the port
	br = part("Barrel", "Barrel")
	br.add(drop(cyl_x(X(730), X(507), 0.026, BORE_Z, 12), 0, -1), 0)
	br.add(cut(box(X(720), X(642), -0.027, 0.027, Z(764), Z(733), METAL), cyl_x(X(650), X(630), 0.02, BORE_Z, 10), mats, METAL, bw=0.003, segs=1), 0)

	# ---- Frame (polymer): dust cover with a rail groove, trigger guard, pin, detail buttons
	fr = part("Frame")
	frame = prism(P([(515, 779), (942, 779), (942, 805), (898, 817), (522, 817), (515, 810)]), "Y", -FW, FW)
	fr.add(cut(frame, mirror_y(box(X(598), X(525), FW - 0.007, FW + 0.02, Z(807), Z(798))), mats, DARK, bw=0.005), 0)
	guard = prism(P([(630, 815), (765, 815), (765, 870), (748, 885), (645, 887), (636, 878)]), "Y", -0.026, 0.026)
	fr.add(cut(guard, prism(P([(656, 823), (748, 823), (752, 862), (742, 876), (663, 876), (656, 866)]), "Y", -0.06, 0.06), mats, DARK, bw=0.004, segs=1), 0)
	fr.add(mirror_y(drop(cyl_y(X(688), Z(803), 0.009, FW - 0.002, FW + 0.004, 8, METAL), 1, -1)), 0)
	fr.add(box(X(797), X(780), FW - 0.004, FW + 0.007, Z(828), Z(805), DARK), 0.002, 1)
	fr.add(box(X(802), X(798), FW - 0.002, FW + 0.003, Z(804), Z(789), METAL), 0.001, 1)

	# ---- Grip (darker, two textured panels a side)
	gr = part("Grip")
	grip = prism(P([(765, 815), (895, 815), (940, 960), (938, 970), (905, 978), (800, 982), (795, 975), (772, 880), (765, 860)]), "Y", -GW, GW, DARK)
	panels = mirror_y(group(prism(P([(815, 819), (880, 819), (893, 852), (812, 852)]), "Y", GW - 0.004, GW + 0.02),
		prism(P([(812, 858), (873, 857), (910, 950), (837, 968)]), "Y", GW - 0.004, GW + 0.02)))
	gr.add(cut(grip, panels, mats, DARK, bw=0.007), 0)

	# ---- Magazine: body inside the grip, visible base plate, neon on the base
	mg = part("Magazine", "Mag")
	mg.add(drop(prism(P([(805, 830), (885, 830), (925, 975), (810, 979)]), "Y", -MW, MW, DARK), 2, 1), 0.003, 1)
	plate = prism(P([(795, 978), (915, 976), (922, 985), (918, 1010), (800, 1012), (793, 1003)]), "Y", -GW + 0.004, GW - 0.004, DARK)
	mg.add(cut(plate, mirror_y(box(X(908), X(886), GW - 0.008, GW + 0.02, Z(996), Z(988))), mats, DARK, bw=0.005), 0)
	mn = part("MagNeon", "Mag")
	mn.add(mirror_y(box(X(907), X(887), GW - 0.0075, GW - 0.0045, Z(995), Z(989), NEON)), 0)

	# ---- Charm (buddy) loop: left side of the frame, under the slide's rear
	charm = part("CharmLoop")
	lug, tor = charm_loop(X(918), Z(800), FW + 0.002)
	charm.add(lug, 0.004, 1)
	charm.add(tor, 0)

	# ---- Controls
	tg = part("Trigger", "Trigger")
	tg.add(prism(P([(718, 825), (728, 825), (730, 840), (722, 860), (710, 875), (705, 872), (716, 855), (720, 838)]), "Y", -0.009, 0.009, METAL), 0.003, 1)
	sc = part("SlideCatch", "SlideCatch")
	sc.add(box(X(752), X(702), FW - 0.004, FW + 0.009, Z(801), Z(787), DARK), 0.003, 1)
	mr = part("MagRelease", "MagRelease")
	mr.add(box(X(782), X(758), FW - 0.004, FW + 0.01, Z(870), Z(843), DARK), 0.003, 1)

	return parts


CHARM = (X(918), FW + 0.002 + 0.012, Z(800) - 0.049)
EJECT_RIGHT_UP = Vector((0.0, -0.8, 0.6)).to_track_quat("Z", "Y").to_matrix().to_4x4()

BONES = [
	("Root", None, (0.0, 0.0, 0.1)),
	("Slide", "Root", (X(720), 0.0, BORE_Z)),
	("Barrel", "Root", (X(520), 0.0, BORE_Z)),  # pivot near the muzzle: the breech dips when the slide is locked back
	("Mag", "Root", (X(845), 0.0, Z(830))),
	("Trigger", "Root", (X(722), 0.0, Z(825))),
	("SlideCatch", "Root", (X(727), FW, Z(794))),
	("MagRelease", "Root", (X(770), FW, Z(856))),
	("Flash", "Root", (X(505) + 0.01, 0.0, BORE_Z)),
	("Charm", "Root", CHARM),
]

LOCATORS = [
	("Muzzle", "Barrel", (X(505), 0.0, BORE_Z), None),
	("RightGrip", "Root", (0.0, 0.0, 0.0), None),
	("LeftGrip", "Root", (0.0, 0.0, -0.08), None),  # on the grip, like the Ghost
	("Eject", "Slide", (X(680), -0.02, Z(735)), EJECT_RIGHT_UP),  # right-side port, up and right
	("CharmPoint", "Charm", CHARM, None),
]


def build():
	mats = gunkit.begin(GUN)
	parts = build_parts(mats)
	return gunkit.assemble(GUN, parts, mats, BONES, LOCATORS,
		{"class": "Sidearm", "tier": "T1", "template_version": 2, "length_rel": 0.3, "att_positions": "{}", "pbr": True})


if __name__ == "__main__":
	print(build())
