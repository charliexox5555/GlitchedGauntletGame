# build_akimbo.py: builds the Akimbo pistol (16, dual automatic pistols) in the open Blender scene.
#
#   g = {"__name__": "build", "__file__": path}; exec(compile(open(path).read(), path, "exec"), g); g["build"]()
#
# Family conventions in tools/blender/gunkit.py. Traced from the left hero pistol of
# vault/02 Art/References/Gun-Image-Concepts/Akimbo Tactical Pistols With Extended Magazines-16.png (P converts
# pixels; the hero is a slight three-quarter view, so its front faces are dropped and only the side is traced).
# ONE pistol: the game shows it in both hands (the weapon config's models = {left, right}), no mirroring.
# The ejection port is on the right like the Ghost's (the sheet's port side is a mirrored render); the left side
# carries the front vents, rear serrations and neon. No AimPoint (dual hip fire); LeftGrip sits on the grip.

import bmesh, bpy, importlib, math, os, sys
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gunkit

importlib.reload(gunkit)
from gunkit import DARK, METAL, NEON, PANEL, Part, box, charm_loop, cut, cyl_x, cyl_y, drop, group, mirror_y, prism

GUN = "Akimbo"

# Side view -> studs: muzzle (px 145) to beavertail (660) = 1.44 studs (the Ghost is 1.37). Grip at (565, 310).
S = 0.0028
OX, OY = 565, 310


def X(px):
	return (OX - px) * S


def Z(py):
	return (OY - py) * S


def P(pts):
	return [(X(a), Z(b)) for a, b in pts]


BORE_Z = Z(105)
SW = 0.06  # slide half width
FW = 0.056  # frame half width
GW = 0.062  # grip half width
MW = 0.044  # magazine half width


def build_parts(mats):
	parts = {}

	def part(name, bone="Root"):
		parts[name] = Part(name, bone)
		return parts[name]

	# ---- Slide: front vents, rear serrations, right-side port, bore, neon pockets, sights
	sl = part("Slide", "Slide")
	body = prism(P([(145, 70), (153, 62), (645, 64), (655, 74), (655, 147), (145, 147)]), "Y", -SW, SW)
	vents = mirror_y(group(*[prism(P([(a, 70), (a + 11, 70), (a + 20, 110), (a + 9, 110)]), "Y", SW - 0.02, SW + 0.02) for a in (215, 238, 261)]))
	serr = mirror_y(group(*[prism(P([(a, 92), (a + 9, 92), (a + 13, 145), (a + 4, 145)]), "Y", SW - 0.006, SW + 0.02) for a in (545, 563, 581, 599)]))
	port = box(X(425), X(345), -SW - 0.03, SW - 0.016, Z(110), Z(55))
	bore = cyl_x(X(158), X(135), 0.03, BORE_Z, 12)
	pockets = mirror_y(prism(P([(588, 85), (636, 85), (636, 94), (588, 94)]), "Y", SW - 0.005, SW + 0.02))
	sl.add(cut(body, group(vents, serr, port, bore, pockets), mats, DARK, bw=0.006), 0)
	sl.add(box(X(182), X(152), -0.018, 0.018, Z(64), Z(52), DARK), 0.003, 1)  # front sight
	sl.add(box(X(176), X(160), -0.008, 0.008, Z(52), Z(38), DARK), 0.002, 1)
	rear = box(X(615), X(552), -0.042, 0.042, Z(66), Z(50), DARK)
	sl.add(cut(rear, box(X(625), X(545), -0.009, 0.009, Z(57), Z(44)), mats, DARK, bw=0.003, segs=1), 0)
	sn = part("SlideNeon", "Slide")
	sn.add(mirror_y(prism(P([(590, 86), (634, 86), (634, 93), (590, 93)]), "Y", SW - 0.004, SW - 0.0008, NEON)), 0)

	# ---- Barrel (fixed) and its hood seen through the port
	bs = part("Barrel")
	bs.add(drop(cyl_x(X(430), X(146), 0.034, BORE_Z, 12), 0, -1), 0)  # keeps its muzzle face (seen with the slide back)
	bs.add(box(X(428), X(345), -0.034, 0.034, Z(112), Z(70), METAL), 0.003, 1)

	# ---- Frame (polymer): dust cover with rail notches and a side groove, trigger guard, takedown lever, pin
	fr = part("Frame")
	frame = prism(P([(182, 150), (655, 150), (655, 205), (470, 205), (320, 224), (192, 224), (182, 212)]), "Y", -FW, FW, DARK)
	notches = group(*[box(X(a + 16), X(a), -0.1, 0.1, Z(226), Z(212)) for a in (205, 232, 259, 286)])
	groove = mirror_y(box(X(295), X(200), FW - 0.006, FW + 0.02, Z(166), Z(159)))
	fr.add(cut(frame, group(notches, groove), mats, DARK, bw=0.006), 0)
	guard = prism(P([(305, 205), (470, 205), (470, 300), (455, 316), (330, 318), (310, 306), (305, 282)]), "Y", -0.03, 0.03, DARK)
	fr.add(cut(guard, prism(P([(345, 222), (460, 222), (460, 292), (447, 304), (345, 304)]), "Y", -0.08, 0.08), mats, DARK, bw=0.005, segs=1), 0)
	fr.add(box(X(445), X(402), FW - 0.004, FW + 0.008, Z(182), Z(156), METAL), 0.003, 1)
	fr.add(mirror_y(drop(cyl_y(X(480), Z(195), 0.011, FW - 0.002, FW + 0.005, 8), 1, -1)), 0)

	# ---- Grip (textured panels both sides)
	gr = part("Grip")
	grip = prism(P([(465, 200), (640, 200), (655, 205), (612, 235), (608, 255), (635, 315), (660, 425), (660, 440), (495, 446), (480, 355), (465, 305)]), "Y", -GW, GW, DARK)
	tex = mirror_y(prism(P([(548, 265), (605, 262), (640, 420), (560, 430)]), "Y", GW - 0.005, GW + 0.02))
	fgroove = mirror_y(prism(P([(470, 330), (486, 330), (495, 430), (482, 430)]), "Y", GW - 0.004, GW + 0.02))
	gr.add(cut(grip, group(tex, fgroove), mats, DARK, bw=0.008), 0)

	# ---- Extended magazine (angled with the grip), base plate, neon on the base
	mg = part("Magazine", "Mag")
	mbody = prism(P([(512, 440), (645, 440), (683, 622), (552, 640)]), "Y", -MW, MW, DARK)
	mg.add(cut(mbody, mirror_y(prism(P([(600, 470), (608, 470), (640, 610), (632, 611)]), "Y", MW - 0.004, MW + 0.02)), mats, DARK, bw=0.005, segs=1), 0)
	plate = prism(P([(545, 628), (688, 616), (693, 650), (685, 670), (560, 672), (548, 658)]), "Y", -MW - 0.008, MW + 0.008, DARK)
	mg.add(cut(plate, mirror_y(box(X(638), X(619), MW + 0.004, MW + 0.03, Z(651), Z(640))), mats, DARK, bw=0.005), 0)
	mn = part("MagNeon", "Mag")
	mn.add(mirror_y(box(X(637), X(620), MW + 0.005, MW + 0.0075, Z(650), Z(641), NEON)), 0)

	# ---- Charm (buddy) loop: left side of the frame, under the slide's rear
	charm = part("CharmLoop")
	lug, tor = charm_loop(X(630), Z(190), FW + 0.002)
	charm.add(lug, 0.004, 1)
	charm.add(tor, 0)

	# ---- Controls
	tg = part("Trigger", "Trigger")
	tg.add(prism(P([(420, 222), (440, 222), (452, 245), (442, 270), (420, 292), (407, 290), (426, 262), (430, 240)]), "Y", -0.01, 0.01, METAL), 0.003, 1)
	sc = part("SlideCatch", "SlideCatch")
	sc.add(box(X(547), X(505), FW - 0.004, FW + 0.01, Z(186), Z(160), METAL), 0.003, 1)
	mr = part("MagRelease", "MagRelease")
	mr.add(box(X(530), X(497), GW - 0.006, GW + 0.008, Z(305), Z(268), DARK), 0.004, 1)

	return parts


CHARM = (X(630), FW + 0.002 + 0.012, Z(190) - 0.049)

BONES = [
	("Root", None, (0.0, 0.0, 0.1)),
	("Slide", "Root", (X(400), 0.0, Z(105))),
	("Mag", "Root", (X(578), 0.0, Z(440))),
	("Trigger", "Root", (X(425), 0.0, Z(222))),
	("SlideCatch", "Root", (X(526), FW, Z(173))),
	("MagRelease", "Root", (X(513), GW, Z(286))),
	("Flash", "Root", (X(145) + 0.01, 0.0, BORE_Z)),
	("Charm", "Root", CHARM),
]


EJECT_RIGHT_UP = Vector((0.0, -0.8, 0.6)).to_track_quat("Z", "Y").to_matrix().to_4x4()

LOCATORS = [
	("Muzzle", "Root", (X(145), 0.0, BORE_Z), None),
	("RightGrip", "Root", (0.0, 0.0, 0.0), None),
	("LeftGrip", "Root", (0.0, 0.0, -0.08), None),  # on the grip, like the Ghost
	("Eject", "Slide", (X(385), -0.03, Z(70)), EJECT_RIGHT_UP),  # right-side port, up and right
	("CharmPoint", "Charm", CHARM, None),
]


def build():
	mats = gunkit.begin(GUN)
	parts = build_parts(mats)
	return gunkit.assemble(GUN, parts, mats, BONES, LOCATORS,
		{"class": "Dual", "tier": "T2", "template_version": 2, "length_rel": 0.34, "att_positions": "{}", "pbr": True})


if __name__ == "__main__":
	print(build())
