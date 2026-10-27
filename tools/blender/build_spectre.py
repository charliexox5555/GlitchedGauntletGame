# build_spectre.py: builds the Spectre (05, refined suppressed compact SMG) in the open Blender scene.
#
#   g = {"__name__": "build", "__file__": path}; exec(compile(open(path).read(), path, "exec"), g); g["build"]()
#
# Family conventions in tools/blender/gunkit.py. Traced from the side view of
# vault/02 Art/References/Gun-Image-Concepts/Compact suppressed SMG concept sheet-5.png (P converts pixels).
# Iron-sight ADS (AimPoint at the rear aperture). Shorter and lighter than the Phantom; shares its suppressor
# treatment. HK-style charging handle: the oblong loop at the front of the upper slides back along the side slot
# (it doesn't reciprocate when firing); the bolt shows through a right-side port.

import bmesh, bpy, importlib, math, os, sys
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gunkit

importlib.reload(gunkit)
from gunkit import DARK, METAL, NEON, PANEL, Part, box, charm_loop, cut, cyl_x, cyl_y, drop, group, mirror_y, prism, stadium

GUN = "Spectre"

# Side view -> studs: suppressor front (px 190) to buttpad (1250) = 2.97 studs. Grip centre at (869, 893).
S = 0.0028
OX, OY = 869, 893


def X(px):
	return (OX - px) * S


def Z(py):
	return (OY - py) * S


def P(pts):
	return [(X(a), Z(b)) for a, b in pts]


BORE_Z = Z(767)
SIGHT_Z = gunkit.sight_line(Z(732))  # round 2: open irons, rear ring centre = front post tip


def build_parts(mats):
	parts = {}

	def part(name, bone="Root"):
		parts[name] = Part(name, bone)
		return parts[name]

	uw, lw = 0.06, 0.056  # upper / lower half widths

	# ---- Receiver (charcoal): slim upper with side slot, port and neon pocket; lower with magwell and guard
	rec = part("Receiver")
	upper = prism(P([(620, 735), (628, 727), (932, 727), (987, 731), (987, 806), (935, 806), (935, 795), (620, 795)]), "Y", -uw, uw)
	slot = box(X(809), X(646), uw - 0.01, uw + 0.02, Z(758), Z(750))
	port = box(X(780), X(700), -uw - 0.02, -uw + 0.024, Z(765), Z(740))
	pocket = mirror_y(box(X(928), X(902), uw - 0.005, uw + 0.02, Z(783), Z(770)))
	rec.add(cut(upper, group(slot, port, pocket), mats), 0)
	lower = prism(P([(625, 795), (935, 795), (935, 846), (822, 846), (822, 895), (735, 895), (714, 880), (714, 871), (644, 871), (625, 835)]), "Y", -lw, lw)
	opening = prism(P([(735, 848), (814, 848), (814, 884), (742, 884), (735, 877)]), "Y", -0.1, 0.1)
	rec.add(cut(lower, opening, mats, DARK, bw=0.007), 0)
	rec.add(box(X(930), X(600), -0.03, 0.03, Z(735), Z(726), DARK), 0.003, 1)  # top rail
	rec.add(box(X(699), X(678), -0.022, 0.022, Z(742), Z(731), DARK), 0.003, 1)  # top block
	rec.add(box(X(730), X(707), lw - 0.002, lw + 0.008, Z(832), Z(798), DARK), 0.003, 1)  # mag release

	# ---- Handguard (charcoal, octagonal, three slot rows a side)
	hg = part("Handguard")
	gw, top, bot = 0.07, Z(724), Z(811)
	sect = [(-gw + 0.016, top), (gw - 0.016, top), (gw, top - 0.016), (gw, bot + 0.022), (gw - 0.022, bot), (-gw + 0.022, bot), (-gw, bot + 0.022), (-gw, top - 0.016)]
	body = prism(sect, "X", X(620), X(462))
	slots = mirror_y(group(*[prism(stadium(X(505), X(581), Z(y), 0.02, 3), "Y", gw - 0.02, gw + 0.03) for y in (747, 773, 798)]))
	hg.add(cut(body, slots, mats, bw=0.008), 0)

	# ---- Suppressor (near-black, round) on a hex nut
	sup = part("Suppressor")
	can = cyl_x(X(420), X(190), 0.092, BORE_Z, 32, mat=DARK)
	sup.add(cut(can, cyl_x(X(196), X(182), 0.024, BORE_Z, 16), mats, DARK, bw=0.014, segs=2), 0)
	sup.add(drop(drop(cyl_x(X(404), X(398), 0.087, BORE_Z, 32, mat=METAL), 0, 1), 0, -1), 0)  # seam
	sup.add(cyl_x(X(463), X(419), 0.068, BORE_Z, 6, mat=METAL, rot=0), 0.005, 1)  # hex nut

	# ---- Sights (black): front post block, rear flip
	si = part("Sights")
	si.add(prism(P([(489, 732), (489, 726), (494, 722), (518, 722), (523, 726), (523, 732)]), "Y", -0.026, 0.026, DARK), 0.003, 1)
	rear, front = gunkit.open_irons(X(888), Z(732), X(506), Z(722), SIGHT_Z)  # round 2: open ring + post
	si.add(rear, 0.002, 1)
	si.add(front, 0.002, 1)

	# ---- Grip (black polymer)
	grip = part("Grip")
	g = prism(P([(822, 845), (885, 842), (940, 963), (936, 985), (862, 993), (856, 985)]), "Y", -0.048, 0.048, DARK)
	grip.add(cut(g, mirror_y(prism(P([(838, 870), (880, 866), (920, 960), (868, 968)]), "Y", 0.044, 0.07)), mats, DARK, bw=0.01, segs=1), 0)

	# ---- Stock (black polymer, triangular window) on a buffer tube
	st = part("Stock")
	st.add(cyl_x(X(1022), X(984), 0.075, Z(775), 16, mat=DARK), 0.006, 1)
	stock = prism(P([(1019, 752), (1215, 752), (1215, 935), (1200, 935), (1080, 850), (1019, 808)]), "Y", -0.055, 0.055, DARK)
	st.add(cut(stock, prism(P([(1078, 793), (1185, 793), (1185, 898), (1178, 903)]), "Y", -0.1, 0.1), mats, DARK, bw=0.01), 0)
	st.add(prism(P([(1210, 750), (1245, 752), (1250, 765), (1250, 925), (1245, 935), (1210, 935)]), "Y", -0.065, 0.065, DARK), 0.008, 1)

	# ---- Pins (metal)
	pins = part("Pins")
	for px, py in ((635, 804), (838, 831)):
		pins.add(mirror_y(drop(cyl_y(X(px), Z(py), 0.01, lw - 0.002, lw + 0.006, 8), 1, -1)), 0)

	# ---- Neon: receiver square (both sides), front sight square (both sides)
	neon = part("Neon")
	neon.add(mirror_y(box(X(926), X(904), uw - 0.004, uw - 0.0008, Z(782), Z(771), NEON)), 0)
	neon.add(mirror_y(box(X(507), X(497), 0.026 - 0.002, 0.026 + 0.0025, Z(728), Z(719), NEON)), 0)

	# ---- Charm (buddy) loop: left side of the lower receiver's front, ahead of the magwell
	charm = part("CharmLoop")
	lug, tor = charm_loop(X(633), Z(808), lw + 0.002)
	charm.add(lug, 0.004, 1)
	charm.add(tor, 0)

	# ---- Moving parts
	mag = part("Mag", "Mag")
	m = prism(P([(646, 860), (712, 860), (708, 890), (680, 990), (672, 1018), (600, 1030), (592, 1018), (604, 970), (630, 890)]), "Y", -0.036, 0.036, DARK)
	mag.add(cut(m, mirror_y(prism(P([(640, 900), (690, 900), (668, 995), (618, 995)]), "Y", 0.032, 0.06)), mats, DARK, bw=0.006, segs=1), 0)
	mag.add(prism(P([(588, 1005), (672, 1010), (668, 1031), (590, 1037)]), "Y", -0.042, 0.042, DARK), 0.005, 1)  # base plate

	chh = part("ChargingHandle", "ChargingHandle")
	loop = prism(P([(623, 765), (628, 761), (641, 761), (646, 765), (646, 791), (641, 795), (628, 795), (623, 791)]), "Y", uw - 0.004, uw + 0.016, METAL)
	chh.add(cut(loop, prism(P([(629, 768), (640, 768), (640, 788), (629, 788)]), "Y", uw - 0.01, uw + 0.03), mats, METAL, bw=0.003, segs=1), 0)
	chh.add(box(X(660), X(640), uw - 0.008, uw + 0.004, Z(757), Z(751), METAL), 0.002, 1)  # stem in the slot

	bolt = part("Bolt", "Bolt")
	bolt.add(box(X(778), X(702), -uw + 0.004, -uw + 0.022, Z(763), Z(742), METAL), 0.002, 1)

	trig = part("Trigger", "Trigger")
	trig.add(prism(P([(782, 849), (794, 849), (799, 862), (799, 874), (793, 883), (786, 884), (789, 874), (787, 862)]), "Y", -0.009, 0.009, METAL), 0.003, 1)

	sel = part("FireSelector", "FireSelector")
	sel.add(prism(P([(780, 812), (786, 808), (816, 808), (822, 812), (822, 822), (816, 826), (786, 826), (780, 822)]), "Y", lw + 0.002, lw + 0.011, METAL), 0.003, 1)

	return parts


CHARM = (X(633), 0.056 + 0.002 + 0.012, Z(808) - 0.049)

BONES = [
	("Root", None, (0.0, 0.0, 0.15)),
	("Mag", "Root", (X(679), 0.0, Z(862))),
	("ChargingHandle", "Root", (X(634), 0.07, Z(778))),
	("Bolt", "Root", (X(740), -0.05, Z(752))),
	("Trigger", "Root", (X(788), 0.0, Z(849))),
	("FireSelector", "Root", (X(790), 0.065, Z(817))),
	("Flash", "Root", (X(190) + 0.01, 0.0, BORE_Z)),
	("Charm", "Root", CHARM),
]

EJECT_RIGHT_UP = Vector((0, -0.8, 0.6)).to_track_quat("Z", "Y").to_matrix().to_4x4()

LOCATORS = [
	("Muzzle", "Root", (X(190), 0.0, BORE_Z), None),  # suppressor tip
	("RightGrip", "Root", (0.0, 0.0, 0.0), None),
	("LeftGrip", "Root", (X(540), 0.0, Z(811)), None),
	("AimPoint", "Root", (X(888), 0.0, SIGHT_Z), gunkit.AIM_ROT),
	("Eject", "Root", (X(740), -0.06, Z(752)), EJECT_RIGHT_UP),
	("CharmPoint", "Charm", CHARM, None),
]


def build():
	mats = gunkit.begin(GUN)
	parts = build_parts(mats)
	return gunkit.assemble(GUN, parts, mats, BONES, LOCATORS,
		{"class": "SMG", "tier": "T2", "template_version": 2, "length_rel": 0.76, "att_positions": "{}", "pbr": True}, widen={"*": 1.2, "Suppressor": 1.0, "Sights": 1.0, "Grip": 1.05, "Trigger": 1.0})


if __name__ == "__main__":
	print(build())
