# build_bulldog.py: builds the Bulldog (08, compact bullpup rifle, magazine behind the grip) in the open Blender
# scene.
#
#   g = {"__name__": "build", "__file__": path}; exec(compile(open(path).read(), path, "exec"), g); g["build"]()
#
# Family conventions in tools/blender/gunkit.py. Traced from the side view of
# vault/02 Art/References/Gun-Image-Concepts/Compact Bullpup Rifle Concept Sheet-8.png (P converts pixels).
# Iron-sight ADS (AimPoint at the rear aperture). Bullpup: the trigger group and grip sit forward, the magazine goes
# into the stock behind the grip, the ejection port is on the right behind the grip, and the charging handle is the
# forward block on the top-left (it doesn't reciprocate when firing).

import bmesh, bpy, importlib, math, os, sys
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gunkit

importlib.reload(gunkit)
from gunkit import DARK, METAL, NEON, PANEL, Part, box, charm_loop, cut, cyl_x, cyl_y, drop, group, mirror_y, prism, stadium

GUN = "Bulldog"

# Side view -> studs: muzzle (px 157) to buttpad (1271) = 2.9 studs. Grip centre at (710, 905).
S = 0.0026
OX, OY = 710, 905


def X(px):
	return (OX - px) * S


def Z(py):
	return (OY - py) * S


def P(pts):
	return [(X(a), Z(b)) for a, b in pts]


BORE_Z = Z(766)
SIGHT_Z = gunkit.sight_line(Z(725), stem=0.065)  # round 3: the ring stands on a taller post so the bullpup top clears it  # round 2: open irons, rear ring centre = front post tip


def build_parts(mats):
	parts = {}

	def part(name, bone="Root"):
		parts[name] = Part(name, bone)
		return parts[name]

	rw = 0.068  # receiver half width

	# ---- Receiver (charcoal): long upper shell, centre body with the side plate, port behind the grip
	rec = part("Receiver")
	upper = prism(P([(308, 722), (318, 713), (892, 713), (892, 793), (308, 793)]), "Y", -rw, rw)
	slots = mirror_y(group(prism(stadium(X(348), X(403), Z(772), 0.035, 3), "Y", rw - 0.02, rw + 0.03), prism(stadium(X(414), X(469), Z(772), 0.035, 3), "Y", rw - 0.02, rw + 0.03)))
	port = box(X(892), X(838), -rw - 0.02, -rw + 0.024, Z(810), Z(780))
	rec.add(cut(upper, group(slots, port), mats), 0)
	centre = prism(P([(575, 765), (892, 765), (892, 862), (870, 870), (790, 862), (650, 858), (575, 840)]), "Y", -rw + 0.004, rw - 0.004)
	rec.add(centre, 0.008, 1)
	plate = prism(P([(693, 808), (700, 802), (771, 802), (771, 851), (700, 851), (693, 845)]), "Y", rw - 0.01, rw + 0.006)
	pockets = mirror_y(group(box(X(760), X(722), rw - 0.004, rw + 0.02, Z(812), Z(805)), box(X(760), X(722), rw - 0.004, rw + 0.02, Z(841), Z(833))))
	rec.add(cut(mirror_y(plate), pockets, mats, PANEL, bw=0.004, segs=1), 0)
	rec.add(prism(P([(475, 768), (488, 759), (565, 759), (578, 772), (578, 830), (565, 837), (488, 837), (475, 828)]), "Y", -rw - 0.006, rw + 0.006), 0.007, 1)  # front plate
	rec.add(box(X(667), X(391), -0.032, 0.032, Z(716), Z(707), DARK), 0.003, 1)  # top rail
	rec.add(box(X(857), X(665), -0.04, 0.04, Z(725), Z(707)), 0.005, 1)  # raised rear rail block

	# ---- Lower handguard (black polymer, grip-texture panel)
	hg = part("Handguard")
	lower = prism(P([(297, 800), (308, 790), (489, 790), (489, 845), (308, 845), (297, 835)]), "Y", -0.07, 0.07, DARK)
	hg.add(cut(lower, mirror_y(box(X(463), X(351), 0.066, 0.09, Z(842), Z(802))), mats, DARK, bw=0.008), 0)

	# ---- Barrel and flash hider (metal)
	bar = part("Barrel")
	bar.add(drop(cyl_x(X(310), X(232), 0.02, BORE_Z, 12), 0, -1), 0)
	hider = cyl_x(X(233), X(157), 0.03, BORE_Z, 16)
	vents = group(prism(stadium(X(170), X(205), BORE_Z + 0.014, 0.008, 2), "Y", -0.05, 0.05), prism(stadium(X(170), X(205), BORE_Z - 0.014, 0.008, 2), "Y", -0.05, 0.05), cyl_x(X(162), X(150), 0.017, BORE_Z, 12))
	bar.add(cut(hider, vents, mats, DARK, bw=0.004, segs=1), 0)
	bar.add(cyl_x(X(222), X(212), 0.034, BORE_Z, 16), 0.002, 1)  # collar ring

	# ---- Sights (black): front flip post, rear aperture
	si = part("Sights")
	rear, front = gunkit.open_irons(X(786), Z(725), X(374), Z(725), SIGHT_Z)  # round 2: open ring + post
	si.add(rear, 0.002, 1)
	si.add(front, 0.002, 1)

	# ---- Grip and trigger guard (black polymer)
	grip = part("Grip")
	g = prism(P([(648, 858), (735, 858), (790, 985), (788, 1005), (775, 1020), (700, 1022), (686, 1012), (690, 990), (672, 920), (655, 880)]), "Y", -0.048, 0.048, DARK)
	grip.add(cut(g, mirror_y(prism(P([(668, 880), (728, 878), (768, 985), (706, 995)]), "Y", 0.044, 0.07)), mats, DARK, bw=0.01, segs=1), 0)
	guard = prism(P([(512, 842), (650, 842), (650, 911), (535, 911), (512, 880)]), "Y", -0.028, 0.028, DARK)
	grip.add(cut(guard, prism(P([(541, 847), (645, 847), (645, 897), (548, 897), (541, 880)]), "Y", -0.06, 0.06), mats, DARK, bw=0.004, segs=1), 0)

	# ---- Stock (black polymer): butt body with a raised side plate, magwell lip, buttpad with a slot
	st = part("Stock")
	body = prism(P([(892, 722), (900, 716), (1182, 716), (1182, 957), (1012, 951), (1012, 870), (892, 862)]), "Y", -0.07, 0.07, DARK)
	st.add(body, 0.01, 2)
	st.add(mirror_y(prism(P([(892, 782), (900, 776), (1116, 776), (1116, 834), (892, 834)]), "Y", 0.064, 0.076, DARK)), 0.004, 1)  # side plate
	st.add(prism(P([(905, 851), (1007, 851), (1012, 880), (900, 880)]), "Y", -0.06, 0.06, DARK), 0.005, 1)  # magwell lip
	pad = prism(P([(1179, 716), (1190, 710), (1262, 712), (1271, 725), (1271, 950), (1262, 957), (1190, 957), (1179, 950)]), "Y", -0.075, 0.075, DARK)
	st.add(cut(pad, mirror_y(box(X(1202), X(1186), 0.07, 0.09, Z(914), Z(868))), mats, DARK, bw=0.008, segs=1), 0)  # sling slot

	# ---- Pins (metal)
	pins = part("Pins")
	for px, py, w in ((332, 819, 0.07), (495, 779, rw + 0.006), (1093, 810, 0.076)):
		pins.add(mirror_y(drop(cyl_y(X(px), Z(py), 0.011, w - 0.002, w + 0.006, 8), 1, -1)), 0)

	# ---- Neon: two bars on the side plate (both sides)
	neon = part("Neon")
	neon.add(mirror_y(group(box(X(758), X(724), rw + 0.002, rw + 0.0055, Z(811), Z(806), NEON), box(X(758), X(724), rw + 0.002, rw + 0.0055, Z(840), Z(834), NEON))), 0)

	# ---- Charm (buddy) loop: left side, under the front plate, ahead of the trigger guard
	charm = part("CharmLoop")
	lug, tor = charm_loop(X(498), Z(832), rw + 0.006 + 0.002)
	charm.add(lug, 0.004, 1)
	charm.add(tor, 0)

	# ---- Moving parts
	mag = part("Mag", "Mag")
	m = prism(P([(882, 874), (1008, 874), (1010, 900), (996, 1000), (985, 1008), (862, 1008), (860, 995), (872, 900)]), "Y", -0.04, 0.04, DARK)
	ribs = mirror_y(group(*[box(X(x + 6), X(x), 0.036, 0.06, Z(990), Z(890)) for x in range(895, 985, 22)]))
	mag.add(cut(m, ribs, mats, DARK, bw=0.006, segs=1), 0)
	mag.add(prism(P([(855, 990), (990, 990), (992, 1010), (853, 1010)]), "Y", -0.046, 0.046, DARK), 0.005, 1)  # base

	chh = part("ChargingHandle", "ChargingHandle")
	# Round 2: a Vandal-style side handle (stem in the slot, a big knob) that racks on draw/reloads and rides each shot.
	chh.add(prism(P([(512, 762), (518, 745), (566, 743), (573, 760)]), "Y", rw - 0.002, rw + 0.03, METAL), 0.004, 1)
	chh.add(prism(P([(520, 768), (526, 738), (560, 736), (566, 766)]), "Y", rw + 0.026, rw + 0.06, METAL), 0.006, 1)

	bolt = part("Bolt", "Bolt")
	bolt.add(box(X(890), X(840), -rw + 0.004, -rw + 0.022, Z(808), Z(782), METAL), 0.002, 1)

	trig = part("Trigger", "Trigger")
	trig.add(prism(P([(618, 852), (630, 852), (638, 866), (640, 880), (634, 892), (626, 893), (629, 880), (626, 866)]), "Y", -0.009, 0.009, METAL), 0.003, 1)

	sel = part("FireSelector", "FireSelector")
	sel.add(prism(P([(652, 848), (676, 848), (676, 856), (652, 856)]), "Y", rw - 0.002, rw + 0.008, METAL), 0.003, 1)

	return parts


CHARM = (X(498), 0.068 + 0.006 + 0.002 + 0.012, Z(832) - 0.049)

BONES = [
	("Root", None, (0.0, 0.0, 0.15)),
	("Mag", "Root", (X(940), 0.0, Z(876))),
	("ChargingHandle", "Root", (X(542), 0.08, Z(752))),
	("Bolt", "Root", (X(865), -0.06, Z(795))),
	("Trigger", "Root", (X(624), 0.0, Z(852))),
	("FireSelector", "Root", (X(664), 0.07, Z(852))),
	("Flash", "Root", (X(157) + 0.01, 0.0, BORE_Z)),
	("Charm", "Root", CHARM),
]

EJECT_RIGHT_UP = Vector((0, -0.8, 0.6)).to_track_quat("Z", "Y").to_matrix().to_4x4()

LOCATORS = [
	("Muzzle", "Root", (X(157), 0.0, BORE_Z), None),
	("RightGrip", "Root", (0.0, 0.0, 0.0), None),
	("LeftGrip", "Root", (X(400), 0.0, Z(845)), None),
	("AimPoint", "Root", (X(786), 0.0, SIGHT_Z), gunkit.AIM_ROT),
	("Eject", "Root", (X(865), -0.068, Z(795)), EJECT_RIGHT_UP),
	("CharmPoint", "Charm", CHARM, None),
]


def build():
	mats = gunkit.begin(GUN)
	parts = build_parts(mats)
	return gunkit.assemble(GUN, parts, mats, BONES, LOCATORS,
		{"class": "Rifle", "tier": "T2", "template_version": 2, "length_rel": 0.74, "att_positions": "{}", "pbr": True}, widen={"*": 1.12, "Barrel": 1.0, "Sights": 1.0, "Grip": 1.0, "Trigger": 1.0})


if __name__ == "__main__":
	print(build())
