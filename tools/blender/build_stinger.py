# build_stinger.py: builds the Stinger replacement (04, Uzi-inspired compact SMG, magazine through the grip) in
# the open Blender scene.
#
#   g = {"__name__": "build", "__file__": path}; exec(compile(open(path).read(), path, "exec"), g); g["build"]()
#
# Family conventions in tools/blender/gunkit.py. Traced from the side view of
# vault/02 Art/References/Gun-Image-Concepts/Charcoal compact SMG concept sheet-4.png (P converts pixels).
# Iron-sight ADS: AimPoint at the rear aperture, on the line through the front post's tip. The cocking knob sits
# on the left side under the top cover and rides the side groove (ChargingHandle; it doesn't reciprocate when firing), the bolt shows through a right-side port, the long
# magazine drops straight out of the grip. The folding stock is modelled extended and fixed.

import bmesh, bpy, importlib, math, os, sys
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gunkit

importlib.reload(gunkit)
from gunkit import DARK, METAL, NEON, PANEL, Part, box, charm_loop, cut, cyl_x, cyl_y, drop, group, mirror_y, prism, stadium

GUN = "Stinger"

# Side view -> studs: muzzle (px 312) to buttplate (1202) = 2.67 studs. Grip centre at (692, 850).
S = 0.003
OX, OY = 692, 850


def X(px):
	return (OX - px) * S


def Z(py):
	return (OY - py) * S


def P(pts):
	return [(X(a), Z(b)) for a, b in pts]


BORE_Z = Z(752)
SIGHT_Z = gunkit.sight_line(Z(715))  # round 2: open irons, rear ring centre = front post tip


def build_parts(mats):
	parts = {}

	def part(name, bone="Root"):
		parts[name] = Part(name, bone)
		return parts[name]

	rw = 0.06  # receiver half width

	# ---- Receiver (charcoal box): side groove, neon pockets, ejection port; top cover; front block
	rec = part("Receiver")
	upper = prism(P([(430, 720), (437, 715), (862, 715), (862, 802), (570, 802), (560, 796), (430, 796)]), "Y", -rw, rw)
	groove = mirror_y(prism(stadium(X(605), X(757), Z(738.5), 0.022, 3), "Y", rw - 0.006, rw + 0.02))
	port = box(X(722), X(640), -rw - 0.02, -rw + 0.025, Z(752), Z(726))
	pockets = mirror_y(group(box(X(597), X(577), rw - 0.005, rw + 0.02, Z(787), Z(775)), box(X(847), X(830), rw - 0.005, rw + 0.02, Z(788), Z(776))))
	rec.add(cut(upper, group(groove, port, pockets), mats), 0)
	rec.add(box(X(855), X(510), -0.045, 0.045, Z(717), Z(707), DARK), 0.004, 1)  # top cover
	rec.add(box(X(432), X(390), -0.058, 0.058, Z(787), Z(715)), 0.008, 1)  # front block

	# ---- Handguard (black polymer with three ridges)
	hg = part("Handguard")
	body = prism(P([(417, 762), (530, 757), (537, 765), (537, 812), (527, 815), (422, 815), (417, 808)]), "Y", -0.064, 0.064, DARK)
	ridges = mirror_y(group(*[prism(stadium(X(448), X(528), Z(y), 0.008, 2), "Y", 0.064 - 0.006, 0.09) for y in (772, 784, 796)]))
	hg.add(cut(body, ridges, mats, DARK, bw=0.008), 0)

	# ---- Barrel nut and slotted flash hider (metal)
	bar = part("Barrel")
	bar.add(cyl_x(X(390), X(364), 0.052, BORE_Z, 16), 0.005, 1)
	hider = cyl_x(X(365), X(312), 0.045, BORE_Z, 16)
	slots = group(*[prism(stadium(X(355), X(325), BORE_Z + dz, 0.012, 2), "Y", -0.06, 0.06) for dz in (0.02, -0.02)], cyl_x(X(318), X(305), 0.024, BORE_Z, 12))
	bar.add(cut(hider, slots, mats, DARK, bw=0.005, segs=1), 0)

	# ---- Sights (black): front ears + post, rear block with aperture
	si = part("Sights")
	rear, front = gunkit.open_irons(X(828), Z(715), X(413.5), Z(717), SIGHT_Z)  # round 2: open ring + post
	si.add(rear, 0.002, 1)
	si.add(front, 0.002, 1)

	# ---- Grip and trigger guard (black polymer)
	grip = part("Grip")
	g = prism(P([(648, 798), (716, 798), (728, 830), (746, 912), (742, 918), (670, 918), (666, 910), (652, 830)]), "Y", -0.048, 0.048, DARK)
	tex = mirror_y(prism(P([(662, 812), (712, 812), (730, 900), (676, 902)]), "Y", 0.044, 0.07))
	grip.add(cut(g, tex, mats, DARK, bw=0.01, segs=1), 0)
	guard = prism(P([(572, 796), (650, 796), (650, 847), (580, 847), (572, 839)]), "Y", -0.026, 0.026, DARK)
	grip.add(cut(guard, prism(P([(580, 802), (646, 802), (646, 837), (586, 837), (580, 831)]), "Y", -0.06, 0.06), mats, DARK, bw=0.004, segs=1), 0)

	# ---- Stock (charcoal, extended): hinge block, top beam, diagonal strut, buttplate
	st = part("Stock")
	st.add(box(X(930), X(862), -0.06, 0.06, Z(810), Z(722)), 0.008, 1)
	st.add(prism(P([(928, 733), (1162, 751), (1162, 768), (928, 752)]), "Y", -0.03, 0.03), 0.006, 1)
	st.add(prism(P([(924, 788), (940, 786), (1152, 830), (1152, 848), (1140, 848), (924, 806)]), "Y", -0.03, 0.03), 0.006, 1)
	st.add(prism(P([(1158, 752), (1195, 756), (1202, 770), (1202, 872), (1195, 882), (1158, 880)]), "Y", -0.05, 0.05, DARK), 0.008, 1)
	st.add(mirror_y(drop(cyl_y(X(895), Z(766), 0.018, 0.06, 0.07, 10), 1, -1)), 0.002, 1)

	# ---- Pins (metal)
	pins = part("Pins")
	for px, py in ((435, 780), (550, 769), (877, 742), (877, 790)):
		w = 0.064 if px < 560 else 0.06
		pins.add(mirror_y(drop(cyl_y(X(px), Z(py), 0.011, w - 0.002, w + 0.006, 8), 1, -1)), 0)

	# ---- Neon: two small squares a side
	neon = part("Neon")
	neon.add(mirror_y(group(box(X(595), X(579), rw - 0.004, rw - 0.0008, Z(785), Z(777), NEON), box(X(845), X(832), rw - 0.004, rw - 0.0008, Z(786), Z(778), NEON))), 0)

	# ---- Charm (buddy) loop: left side, receiver bottom ahead of the trigger guard
	charm = part("CharmLoop")
	lug, tor = charm_loop(X(556), Z(790), rw + 0.002)
	charm.add(lug, 0.004, 1)
	charm.add(tor, 0)

	# ---- Moving parts
	mag = part("Mag", "Mag")
	m = prism(P([(674, 880), (742, 880), (750, 1028), (684, 1028)]), "Y", -0.032, 0.032, DARK)
	mag.add(cut(m, mirror_y(box(X(700), X(691), 0.028, 0.05, Z(1020), Z(922))), mats, DARK, bw=0.005, segs=1), 0)  # side window groove
	mag.add(prism(P([(680, 1026), (753, 1026), (755, 1045), (680, 1045)]), "Y", -0.038, 0.038, DARK), 0.005, 1)

	chh = part("ChargingHandle", "ChargingHandle")
	knob = box(X(642), X(607), rw - 0.004, rw + 0.024, Z(737), Z(716), METAL)  # left-side knob, rides the side groove
	serr = group(*[box(X(x + 3), X(x), rw + 0.018, rw + 0.04, Z(740), Z(713)) for x in range(611, 640, 7)])
	chh.add(cut(knob, serr, mats, METAL, bw=0.004, segs=1), 0)

	bolt = part("Bolt", "Bolt")
	bolt.add(box(X(720), X(642), -rw + 0.004, -rw + 0.022, Z(750), Z(728), METAL), 0.002, 1)

	trig = part("Trigger", "Trigger")
	trig.add(prism(P([(618, 806), (630, 806), (637, 818), (638, 830), (632, 840), (625, 841), (628, 830), (626, 818)]), "Y", -0.009, 0.009, METAL), 0.003, 1)

	sel = part("FireSelector", "FireSelector")
	sel.add(box(X(712), X(670), rw - 0.002, rw + 0.01, Z(790), Z(775), METAL), 0.003, 1)

	return parts


CHARM = (X(556), 0.06 + 0.002 + 0.012, Z(790) - 0.049)

BONES = [
	("Root", None, (0.0, 0.0, 0.15)),
	("Mag", "Root", (X(708), 0.0, Z(880))),
	("ChargingHandle", "Root", (X(625), 0.072, Z(726))),
	("Bolt", "Root", (X(680), -0.05, Z(740))),
	("Trigger", "Root", (X(626), 0.0, Z(806))),
	("FireSelector", "Root", (X(706), 0.065, Z(782))),
	("Flash", "Root", (X(312) + 0.01, 0.0, BORE_Z)),
	("Charm", "Root", CHARM),
]

EJECT_RIGHT_UP = Vector((0, -0.8, 0.6)).to_track_quat("Z", "Y").to_matrix().to_4x4()

LOCATORS = [
	("Muzzle", "Root", (X(312), 0.0, BORE_Z), None),
	("RightGrip", "Root", (0.0, 0.0, 0.0), None),
	("LeftGrip", "Root", (X(480), 0.0, Z(815)), None),
	("AimPoint", "Root", (X(828), 0.0, SIGHT_Z), gunkit.AIM_ROT),
	("Eject", "Root", (X(680), -0.06, Z(740)), EJECT_RIGHT_UP),
	("CharmPoint", "Charm", CHARM, None),
]


def build():
	mats = gunkit.begin(GUN)
	parts = build_parts(mats)
	return gunkit.assemble(GUN, parts, mats, BONES, LOCATORS,
		{"class": "SMG", "tier": "T2", "template_version": 2, "length_rel": 0.68, "att_positions": "{}", "pbr": True}, widen={"*": 1.2, "Barrel": 1.0, "Sights": 1.0, "Grip": 1.05, "Trigger": 1.0})


if __name__ == "__main__":
	print(build())
