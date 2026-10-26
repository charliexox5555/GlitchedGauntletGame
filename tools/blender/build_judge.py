# build_judge.py: builds the Judge (03, compact automatic drum-fed shotgun) in the open Blender scene.
#
#   g = {"__name__": "build", "__file__": path}; exec(compile(open(path).read(), path, "exec"), g); g["build"]()
#
# Family conventions in tools/blender/gunkit.py. Traced from the side view of
# vault/02 Art/References/Gun-Image-Concepts/Compact Drum-Fed Shotgun Concept Sheet-3.png (P converts pixels).
# No ADS (shotgun): no AimPoint. The drum is the "Mag" bone (one detachable assembly; its axis runs along the
# barrel and it never spins). Side charging handle on the left, bolt seen through a right-side port.

import bmesh, bpy, importlib, math, os, sys
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gunkit

importlib.reload(gunkit)
from gunkit import DARK, METAL, NEON, PANEL, Part, box, charm_loop, cut, cyl_x, cyl_y, drop, group, mirror_y, prism, stadium

GUN = "Judge"

# Side view -> studs: muzzle (px 230) to buttpad (1242) = 3.14 studs; grip (144 px) close to the family grip.
# Grip centre at (913, 940).
S = 0.0031
OX, OY = 913, 940


def X(px):
	return (OX - px) * S


def Z(py):
	return (OY - py) * S


def P(pts):
	return [(X(a), Z(b)) for a, b in pts]


BORE_Z = Z(778)
DRUM_Z = Z(937)
DRUM_R = 0.335


def build_parts(mats):
	parts = {}

	def part(name, bone="Root"):
		parts[name] = Part(name, bone)
		return parts[name]

	rw = 0.08  # receiver half width

	# ---- Receiver (charcoal, bulky and angular)
	rec = part("Receiver")
	body = prism(P([(506, 742), (516, 729), (860, 729), (870, 736), (967, 745), (967, 818), (940, 822), (714, 820), (700, 830), (640, 860), (506, 860)]), "Y", -rw, rw)
	port = box(X(800), X(700), -rw - 0.02, -rw + 0.03, Z(800), Z(770))
	track = box(X(722), X(636), rw - 0.012, rw + 0.02, Z(801), Z(789))
	panel = mirror_y(prism(P([(560, 738), (850, 738), (900, 800), (600, 800)]), "Y", rw - 0.004, rw + 0.02))
	pocket = mirror_y(prism(P([(897, 806), (936, 806), (928, 819), (905, 819)]), "Y", rw - 0.005, rw + 0.02))
	rec.add(cut(body, group(port, track, panel, pocket), mats), 0)
	lower = prism(P([(706, 816), (955, 816), (955, 852), (938, 866), (848, 866), (848, 905), (838, 912), (770, 912), (760, 900), (760, 866), (730, 866), (706, 842)]), "Y", -0.07, 0.07)
	opening = prism(P([(776, 862), (838, 862), (838, 899), (782, 899), (776, 893)]), "Y", -0.1, 0.1)
	rec.add(cut(lower, opening, mats, DARK, bw=0.006, segs=1), 0)  # lower receiver with the trigger guard
	rec.add(box(X(972), X(941), -0.07, 0.07, Z(820), Z(742)), 0.006, 1)  # stock adapter
	rec.add(box(X(870), X(300), -0.028, 0.028, Z(749), Z(741), DARK), 0.003, 1)  # top rib

	# ---- Barrel (dark metal) with a heavy muzzle collar
	bar = part("Barrel")
	bar.add(drop(cyl_x(X(510), X(283), 0.077, BORE_Z, 24), 0, -1), 0.004, 1)
	collar = cyl_x(X(284), X(230), 0.084, BORE_Z, 24)
	bar.add(cut(collar, cyl_x(X(238), X(222), 0.05, BORE_Z, 20), mats, DARK, bw=0.008, segs=2), 0)

	# ---- Handguard (charcoal, three slots a side, wraps under the barrel)
	hg = part("Handguard")
	gw, top, bot = 0.085, Z(788), Z(862)
	sect = [(-gw + 0.01, top), (gw - 0.01, top), (gw, top - 0.01), (gw, bot + 0.03), (gw - 0.025, bot), (-gw + 0.025, bot), (-gw, bot + 0.03), (-gw, top - 0.01)]
	body = prism(sect, "X", X(507), X(292))
	slots = mirror_y(group(*[prism(stadium(X(x1), X(x0), Z(810), 0.042, 3), "Y", gw - 0.024, gw + 0.03) for x0, x1 in ((372, 323), (431, 382), (490, 441))]))
	hg.add(cut(body, slots, mats, bw=0.009), 0)

	# ---- Sights (black): tall front post with a blue insert, flip rear
	si = part("Sights")
	si.add(prism(P([(292, 754), (292, 712), (300, 700), (326, 700), (333, 712), (333, 754)]), "Y", -0.03, 0.03, DARK), 0.004, 1)
	si.add(prism(P([(807, 742), (813, 720), (826, 702), (852, 702), (859, 742)]), "Y", -0.026, 0.026, DARK), 0.004, 1)

	# ---- Grip (black polymer)
	grip = part("Grip")
	g = prism(P([(853, 860), (938, 858), (950, 870), (988, 1000), (988, 1030), (898, 1036), (892, 1022), (878, 960), (862, 920)]), "Y", -0.05, 0.05, DARK)
	tex = mirror_y(prism(P([(900, 905), (940, 892), (972, 990), (918, 998)]), "Y", 0.046, 0.07))
	grip.add(cut(g, tex, mats, DARK, bw=0.01, segs=1), 0)

	# ---- Stock (charcoal skeleton with a triangular window, black buttpad)
	st = part("Stock")
	stock = prism(P([(967, 757), (1205, 757), (1205, 965), (1190, 968), (1100, 890), (985, 832), (967, 832)]), "Y", -0.06, 0.06)
	window = prism(P([(1110, 833), (1190, 833), (1190, 916)]), "Y", -0.1, 0.1)
	st.add(cut(stock, window, mats, PANEL, bw=0.01), 0)
	st.add(prism(P([(1200, 762), (1236, 766), (1242, 780), (1242, 960), (1236, 972), (1200, 975)]), "Y", -0.07, 0.07, DARK), 0.009, 1)

	# ---- Pins (metal, both sides)
	pins = part("Pins")
	for px, py, r in ((565, 824, 0.016), (817, 845, 0.016), (1005, 825, 0.014), (1183, 940, 0.014)):
		w = rw if px < 970 else 0.06
		pins.add(mirror_y(drop(cyl_y(X(px), Z(py), r, w - 0.002, w + 0.008, 8), 1, -1)), 0)

	# ---- Neon: receiver trapezoid (both sides), front sight insert (both sides)
	neon = part("Neon")
	neon.add(mirror_y(prism(P([(899, 807), (934, 807), (927, 818), (906, 818)]), "Y", rw - 0.004, rw - 0.0008, NEON)), 0)
	neon.add(mirror_y(box(X(308), X(300), 0.03 - 0.002, 0.03 + 0.002, Z(723), Z(705), NEON)), 0)

	# ---- Charm (buddy) loop: left side of the receiver's front, ahead of the drum
	charm = part("CharmLoop")
	lug, tor = charm_loop(X(520), Z(840), rw + 0.002)
	charm.add(lug, 0.004, 1)
	charm.add(tor, 0)

	# ---- Moving parts
	mag = part("Mag", "Mag")  # the drum: one detachable assembly
	x0, x1 = X(740), X(545)
	mag.add(cyl_x(x0 + 0.03, x1 - 0.03, DRUM_R, DRUM_Z, 32, mat=DARK), 0.012, 2)
	mag.add(cyl_x(x1 - 0.045, x1, DRUM_R + 0.012, DRUM_Z, 32, mat=DARK), 0.006, 1)  # front rim
	mag.add(cyl_x(x0, x0 + 0.045, DRUM_R + 0.012, DRUM_Z, 32, mat=DARK), 0.006, 1)  # rear rim
	mag.add(cyl_x(x1, x1 + 0.012, 0.05, DRUM_Z, 16, mat=METAL), 0.003, 1)  # hub
	lugs = bmesh.new()
	for i in range(8):
		a = math.radians(22.5 + 45 * i)
		y, z = (DRUM_R + 0.008) * math.cos(a), DRUM_Z + (DRUM_R + 0.008) * math.sin(a)
		lug_ = box(-0.03, 0.03, -0.022, 0.022, -0.02, 0.02, DARK)
		bmesh.ops.rotate(lug_, verts=lug_.verts[:], cent=(0, 0, 0), matrix=gunkit.Matrix.Rotation(a, 3, "X"))
		bmesh.ops.translate(lug_, verts=lug_.verts[:], vec=((x0 + x1) / 2, y, z))
		gunkit.merge(lugs, lug_)
	mag.add(lugs, 0.004, 1)
	mag.add(box(X(690), X(590), -0.06, 0.06, Z(865), Z(826), DARK), 0.006, 1)  # feed tower into the receiver

	chh = part("ChargingHandle", "ChargingHandle")
	chh.add(box(X(724), X(706), rw - 0.008, rw + 0.012, Z(803), Z(787), METAL), 0.003, 1)
	chh.add(box(X(724), X(712), rw + 0.01, rw + 0.034, Z(802), Z(788), METAL), 0.003, 1)

	bolt = part("Bolt", "Bolt")
	bolt.add(box(X(798), X(702), -rw + 0.004, -rw + 0.026, Z(798), Z(772), METAL), 0.002, 1)

	trig = part("Trigger", "Trigger")
	trig.add(prism(P([(806, 864), (820, 864), (826, 878), (826, 892), (820, 902), (812, 903), (815, 890), (814, 878)]), "Y", -0.011, 0.011, METAL), 0.003, 1)

	sel = part("FireSelector", "FireSelector")
	sel.add(prism(P([(844, 834), (869, 834), (869, 843), (844, 843)]), "Y", rw + 0.002, rw + 0.012, METAL), 0.003, 1)

	return parts


CHARM = (X(520), 0.08 + 0.002 + 0.012, Z(840) - 0.049)

BONES = [
	("Root", None, (0.0, 0.0, 0.15)),
	("Mag", "Root", (X(642), 0.0, Z(850))),
	("ChargingHandle", "Root", (X(715), 0.09, Z(795))),
	("Bolt", "Root", (X(750), -0.065, Z(785))),
	("Trigger", "Root", (X(812), 0.0, Z(864))),
	("FireSelector", "Root", (X(856), 0.09, Z(838))),
	("Flash", "Root", (X(230) + 0.01, 0.0, BORE_Z)),
	("Charm", "Root", CHARM),
]

EJECT_RIGHT_UP = Vector((0, -0.8, 0.6)).to_track_quat("Z", "Y").to_matrix().to_4x4()

LOCATORS = [
	("Muzzle", "Root", (X(230), 0.0, BORE_Z), None),
	("RightGrip", "Root", (0.0, 0.0, 0.0), None),
	("LeftGrip", "Root", (X(400), 0.0, Z(862)), None),
	("Eject", "Root", (X(750), -0.08, Z(785)), EJECT_RIGHT_UP),
	("CharmPoint", "Charm", CHARM, None),
]


def build():
	mats = gunkit.begin(GUN)
	parts = build_parts(mats)
	return gunkit.assemble(GUN, parts, mats, BONES, LOCATORS,
		{"class": "Shotgun", "tier": "T2", "template_version": 2, "length_rel": 0.8, "att_positions": "{}", "pbr": True})


if __name__ == "__main__":
	print(build())
