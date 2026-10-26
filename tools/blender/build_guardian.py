# build_guardian.py: builds the Guardian (09, long semi-automatic precision rifle) in the open Blender scene.
#
#   g = {"__name__": "build", "__file__": path}; exec(compile(open(path).read(), path, "exec"), g); g["build"]()
#
# Family conventions in tools/blender/gunkit.py. Traced from the side view of
# vault/02 Art/References/Gun-Image-Concepts/Guardian precision rifle concept sheet-9.png (P converts pixels).
# Iron-sight ADS, no scope (AimPoint at the rear aperture). Slim long barrel with a restrained brake, long two-row
# M-LOK handguard, straight box magazine ahead of the trigger. The charging handle is a knob at the front of the
# left-side slot (doesn't reciprocate); the bolt shows through a right-side port.

import bmesh, bpy, importlib, math, os, sys
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gunkit

importlib.reload(gunkit)
from gunkit import DARK, METAL, NEON, PANEL, Part, box, charm_loop, cut, cyl_x, cyl_y, drop, group, mirror_y, prism, stadium

GUN = "Guardian"

# Side view -> studs: muzzle (px 62) to buttpad (1388) = 4.24 studs. Grip centre at (999, 900).
S = 0.0032
OX, OY = 999, 900


def X(px):
	return (OX - px) * S


def Z(py):
	return (OY - py) * S


def P(pts):
	return [(X(a), Z(b)) for a, b in pts]


BORE_Z = Z(785)
SIGHT_Z = Z(745)


def build_parts(mats):
	parts = {}

	def part(name, bone="Root"):
		parts[name] = Part(name, bone)
		return parts[name]

	rw = 0.062  # receiver half width

	# ---- Receiver (charcoal): front block, upper with side slot / port / neon pocket, lower with magwell
	rec = part("Receiver")
	rec.add(prism(P([(644, 782), (650, 777), (725, 777), (725, 834), (650, 834), (644, 828)]), "Y", -0.07, 0.07), 0.007, 1)
	upper = prism(P([(721, 770), (727, 767), (1003, 767), (1003, 827), (721, 827)]), "Y", -rw, rw)
	slot = box(X(894), X(760), rw - 0.01, rw + 0.02, Z(795), Z(788))
	port = box(X(900), X(800), -rw - 0.02, -rw + 0.024, Z(815), Z(790))
	pocket = mirror_y(box(X(889), X(825), rw - 0.005, rw + 0.02, Z(812), Z(805)))
	rec.add(cut(upper, group(slot, port, pocket), mats), 0)
	lower = prism(P([(725, 827), (1021, 827), (1021, 856), (952, 862), (952, 890), (858, 890), (852, 870), (845, 862), (753, 862), (725, 845)]), "Y", -0.058, 0.058)
	rec.add(cut(lower, prism(P([(860, 862), (946, 862), (946, 884), (866, 884)]), "Y", -0.1, 0.1), mats, DARK, bw=0.006, segs=1), 0)
	rec.add(box(X(1000), X(263), -0.028, 0.028, Z(767), Z(760), DARK), 0.003, 1)  # top rail

	# ---- Handguard (charcoal, long two-row M-LOK)
	hg = part("Handguard")
	gw, top, bot = 0.068, Z(763), Z(841)
	sect = [(-gw + 0.014, top), (gw - 0.014, top), (gw, top - 0.014), (gw, bot + 0.024), (gw - 0.024, bot), (-gw + 0.024, bot), (-gw, bot + 0.024), (-gw, top - 0.014)]
	body = prism(sect, "X", X(648), X(263))
	slots = mirror_y(group(*[prism(stadium(X(x), X(x + 38), Z(y), 0.026, 3), "Y", gw - 0.02, gw + 0.03) for y in (782, 803) for x in range(292, 620, 50)]))
	hg.add(cut(body, slots, mats, bw=0.008), 0)

	# ---- Barrel and restrained muzzle brake (metal)
	bar = part("Barrel")
	bar.add(drop(cyl_x(X(265), X(128), 0.029, BORE_Z, 12), 0, -1), 0)
	brake = cyl_x(X(130), X(62), 0.042, BORE_Z, 12)
	ports = group(*[prism(stadium(X(x), X(x + 13), BORE_Z, 0.03, 2), "Y", -0.06, 0.06) for x in (72, 92, 110)], cyl_x(X(68), X(55), 0.018, BORE_Z, 12))
	bar.add(cut(brake, ports, mats, DARK, bw=0.005, segs=1), 0)
	bar.add(cyl_x(X(140), X(128), 0.034, BORE_Z, 12), 0.002, 1)  # collar

	# ---- Sights (black): front post, rear aperture
	si = part("Sights")
	ear = [(281, 767), (281, 740), (286, 732), (301, 732), (306, 740), (306, 767)]
	si.add(group(prism(P(ear), "Y", 0.014, 0.028, DARK), prism(P(ear), "Y", -0.028, -0.014, DARK)), 0.003, 1)
	si.add(box(X(296), X(291), -0.005, 0.005, Z(767), SIGHT_Z, METAL), 0.002, 1)
	rear = prism(P([(940, 767), (940, 739), (946, 732), (966, 732), (972, 739), (972, 767)]), "Y", -0.028, 0.028, DARK)
	si.add(cut(rear, cyl_x(X(978), X(934), 0.01, SIGHT_Z, 10), mats, DARK, bw=0.003, segs=1), 0)

	# ---- Grip (black polymer)
	grip = part("Grip")
	g = prism(P([(944, 852), (1030, 850), (1044, 975), (1035, 992), (975, 996), (966, 985), (972, 950), (955, 890)]), "Y", -0.048, 0.048, DARK)
	grip.add(cut(g, mirror_y(prism(P([(962, 875), (1022, 870), (1032, 965), (982, 972)]), "Y", 0.044, 0.07)), mats, DARK, bw=0.01, segs=1), 0)

	# ---- Stock (black polymer, window, ribbed buttpad) on a buffer tube
	st = part("Stock")
	st.add(cyl_x(X(1110), X(1001), 0.056, Z(795), 16, mat=DARK), 0.006, 1)
	stock = prism(P([(1106, 780), (1115, 774), (1338, 774), (1338, 950), (1322, 950), (1180, 868), (1120, 830), (1106, 820)]), "Y", -0.058, 0.058, DARK)
	st.add(cut(stock, prism(P([(1162, 824), (1318, 824), (1318, 926)]), "Y", -0.1, 0.1), mats, DARK, bw=0.01), 0)
	pad = prism(P([(1335, 776), (1380, 778), (1388, 790), (1388, 945), (1380, 952), (1335, 952)]), "Y", -0.066, 0.066, DARK)
	st.add(cut(pad, mirror_y(group(*[box(X(1385), X(1352), 0.06, 0.09, Z(y + 5), Z(y)) for y in range(795, 940, 13)])), mats, DARK, bw=0.006, segs=1), 0)

	# ---- Pins (metal)
	pins = part("Pins")
	for px, py, w in ((664, 790, 0.07), (664, 822, 0.07), (990, 840, 0.058)):
		pins.add(mirror_y(drop(cyl_y(X(px), Z(py), 0.011, w - 0.002, w + 0.006, 8), 1, -1)), 0)

	# ---- Neon: receiver bar (both sides), mag strip (on the Mag)
	neon = part("Neon")
	neon.add(mirror_y(box(X(887), X(827), rw - 0.004, rw - 0.0008, Z(811), Z(806), NEON)), 0)

	# ---- Charm (buddy) loop: left side of the handguard's rear underside
	charm = part("CharmLoop")
	lug, tor = charm_loop(X(630), Z(832), gw + 0.002)
	charm.add(lug, 0.004, 1)
	charm.add(tor, 0)

	# ---- Moving parts
	mag = part("Mag", "Mag")
	m = prism(P([(755, 855), (845, 855), (845, 912), (840, 922), (760, 922), (755, 914)]), "Y", -0.045, 0.045, DARK)
	window = mirror_y(prism(P([(790, 870), (832, 870), (832, 910), (790, 910)]), "Y", 0.041, 0.07))
	mag.add(cut(m, window, mats, DARK, bw=0.006, segs=1), 0)
	mag.add(mirror_y(box(X(778), X(771), 0.045 - 0.002, 0.045 + 0.0025, Z(904), Z(862), NEON)), 0)

	chh = part("ChargingHandle", "ChargingHandle")
	chh.add(box(X(778), X(762), rw - 0.008, rw + 0.022, Z(799), Z(784), METAL), 0.003, 1)

	bolt = part("Bolt", "Bolt")
	bolt.add(box(X(898), X(802), -rw + 0.004, -rw + 0.022, Z(813), Z(792), METAL), 0.002, 1)

	trig = part("Trigger", "Trigger")
	trig.add(prism(P([(912, 862), (924, 862), (930, 872), (930, 880), (924, 886), (917, 886), (920, 878), (918, 870)]), "Y", -0.009, 0.009, METAL), 0.003, 1)

	sel = part("FireSelector", "FireSelector")
	sel.add(prism(P([(944, 830), (972, 827), (972, 837), (944, 837)]), "Y", 0.058, 0.068, METAL), 0.003, 1)

	catch = part("BoltCatch", "Root")
	catch.add(box(X(873), X(852), 0.056, 0.066, Z(852), Z(823), DARK), 0.003, 1)

	return parts


CHARM = (X(630), 0.068 + 0.002 + 0.012, Z(832) - 0.049)

BONES = [
	("Root", None, (0.0, 0.0, 0.15)),
	("Mag", "Root", (X(800), 0.0, Z(857))),
	("ChargingHandle", "Root", (X(770), 0.072, Z(792))),
	("Bolt", "Root", (X(850), -0.05, Z(802))),
	("Trigger", "Root", (X(918), 0.0, Z(862))),
	("FireSelector", "Root", (X(950), 0.063, Z(832))),
	("Flash", "Root", (X(62) + 0.01, 0.0, BORE_Z)),
	("Charm", "Root", CHARM),
]

EJECT_RIGHT_UP = Vector((0, -0.8, 0.6)).to_track_quat("Z", "Y").to_matrix().to_4x4()

LOCATORS = [
	("Muzzle", "Root", (X(62), 0.0, BORE_Z), None),
	("RightGrip", "Root", (0.0, 0.0, 0.0), None),
	("LeftGrip", "Root", (X(480), 0.0, Z(841)), None),
	("AimPoint", "Root", (X(956), 0.0, SIGHT_Z), gunkit.AIM_ROT),
	("Eject", "Root", (X(850), -0.062, Z(802)), EJECT_RIGHT_UP),
	("CharmPoint", "Charm", CHARM, None),
]


def build():
	mats = gunkit.begin(GUN)
	parts = build_parts(mats)
	return gunkit.assemble(GUN, parts, mats, BONES, LOCATORS,
		{"class": "Rifle", "tier": "T2", "template_version": 2, "length_rel": 1.09, "att_positions": "{}", "pbr": True})


if __name__ == "__main__":
	print(build())
