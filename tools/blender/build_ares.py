# build_ares.py: builds the Ares (14, drum-fed light machine gun) in the open Blender scene.
#
#   g = {"__name__": "build", "__file__": path}; exec(compile(open(path).read(), path, "exec"), g); g["build"]()
#
# Family conventions in tools/blender/gunkit.py. Traced from the side view of
# vault/02 Art/References/Gun-Image-Concepts/ARES-inspired light machine gun concept sheet-14.png (P converts pixels).
# The drum's axis runs along the barrel (a round face forward, ribbed body behind it) and it hangs under the
# magwell ahead of the trigger; it is the Mag bone. Charging handle: a knob in a slot on the left (FP) side of the
# receiver front. Bolt: visible in the right-side ejection port. Iron sights: AimPoint at the rear aperture.

import bmesh, bpy, importlib, math, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gunkit

importlib.reload(gunkit)
from gunkit import DARK, METAL, NEON, PANEL, Part, box, charm_loop, cut, cyl_x, cyl_y, drop, group, mirror_y, prism, ring_pts, stadium

GUN = "Ares"

# Side view -> studs: muzzle (px 51) to buttpad (1397) = 4.31 studs. Grip at (1012, 880).
S = 0.0032
OX, OY = 1012, 880


def X(px):
	return (OX - px) * S


def Z(py):
	return (OY - py) * S


def P(pts):
	return [(X(a), Z(b)) for a, b in pts]


BORE_Z = Z(764)
DRUM_Z = Z(905)
RW = 0.068  # receiver half width
HW = 0.066  # handguard half width
SIGHT_Z = gunkit.sight_line(Z(703))  # round 2: open irons, rear ring centre = front post tip


def build_parts(mats):
	parts = {}

	def part(name, bone="Root"):
		parts[name] = Part(name, bone)
		return parts[name]

	ch_slot = box(X(820), X(680), 0.045, RW + 0.04, Z(801), Z(785))
	pocket_pts = [(stadium(X(810), X(857), Z(768.5), 10 * S)), (stadium(X(857), X(901), Z(790), 11 * S))]
	pockets = group(*[mirror_y(prism(p, "Y", RW - 0.005, RW + 0.02)) for p in pocket_pts])

	# ---- Receiver: upper body (charging-handle slot left, ejection port right), front trunnion block, lower
	# receiver / magwell, end plate, trigger guard, rail
	rec = part("Receiver")
	upper = prism(P([(640, 727), (1048, 727), (1048, 817), (640, 817)]), "Y", -RW, RW)
	port = box(X(870), X(800), -RW - 0.04, -RW + 0.035, Z(775), Z(752))
	grooves = mirror_y(group(box(X(1040), X(905), RW - 0.004, RW + 0.02, Z(781), Z(778)), box(X(990), X(760), RW - 0.004, RW + 0.02, Z(748), Z(745))))
	rec.add(cut(upper, group(ch_slot, port, pockets, grooves), mats), 0)
	block = prism(P([(655, 718), (740, 718), (740, 840), (655, 840)]), "Y", -0.074, 0.074)
	rec.add(cut(block, box(X(820), X(680), 0.045, 0.12, Z(801), Z(785)), mats), 0)
	for x, z in ((672, 735), (722, 735), (672, 825)):
		rec.add(mirror_y(drop(cyl_y(X(x), Z(z), 0.011, 0.07, 0.079, 8), 1, -1)), 0)
	rec.add(prism(P([(705, 812), (1000, 812), (1014, 822), (1000, 837), (705, 837)]), "Y", -0.062, 0.062), 0.005, 1)
	rec.add(box(X(1070), X(1045), -0.064, 0.064, Z(817), Z(727), DARK), 0.005, 1)  # end plate
	guard = prism(P([(850, 835), (962, 835), (962, 860), (948, 877), (862, 877), (850, 862)]), "Y", -0.024, 0.024, DARK)
	rec.add(cut(guard, prism(P([(860, 838), (952, 838), (952, 858), (942, 869), (866, 869)]), "Y", -0.06, 0.06), mats, DARK, bw=0.004, segs=1), 0)
	rec.add(box(X(950), X(390), -0.03, 0.03, Z(729), Z(719), DARK), 0.002, 1)  # top rail
	for x in range(398, 945, 16):
		rec.add(drop(box(X(x + 8), X(x), -0.032, 0.032, Z(720), Z(716), DARK), 2, -1), 0)

	# ---- Handguard: vented (three rows of slots), front block, lower rail, gas block
	hg = part("Handguard")
	shell = prism(P([(385, 734), (389, 730), (636, 730), (640, 734), (640, 813), (636, 817), (389, 817), (385, 813)]), "Y", -HW, HW)
	vents = []
	for zc, h in ((747.5, 12), (776, 12), (804, 8)):
		for a, b in ((394, 436), (450, 497), (512, 566)):
			vents.append(mirror_y(prism(stadium(X(a), X(b), Z(zc), h * S), "Y", HW - 0.018, HW + 0.02)))
	hg.add(cut(shell, group(*vents), mats), 0)
	hg.add(mirror_y(drop(cyl_y(X(615), Z(778), 0.016, HW - 0.002, HW + 0.006, 10), 1, -1)), 0)
	hg.add(prism(P([(346, 734), (385, 734), (385, 813), (346, 813)]), "Y", -0.06, 0.06), 0.006, 1)
	hg.add(box(X(565), X(405), -0.03, 0.03, Z(822), Z(812), DARK), 0.002, 1)
	hg.add(box(X(346), X(300), -0.052, 0.052, Z(805), Z(727), DARK), 0.006, 1)  # gas block

	# ---- Barrel and flash hider
	brl = part("Barrel")
	brl.add(drop(cyl_x(X(642), X(166), 0.045, BORE_Z, 16), 0, 1), 0)
	brl.add(cyl_x(X(166), X(140), 0.058, BORE_Z, 16, mat=DARK), 0.004, 1)
	hider = cyl_x(X(140), X(51), 0.064, BORE_Z, 8, mat=DARK)
	brl.add(cut(hider, group(box(X(90), X(62), -0.1, 0.1, BORE_Z - 0.024, BORE_Z + 0.024), cyl_x(X(58), X(40), 0.032, BORE_Z, 12)), mats, DARK, bw=0.006, segs=1), 0)

	# ---- Iron sights: front post with ears, rear aperture tower
	sights = part("Sights")
	sights.add(box(X(370), X(337), -0.03, 0.03, Z(730), Z(712), DARK), 0.004, 1)
	sights.add(box(X(1027), X(955), -0.035, 0.035, Z(719), Z(703), DARK), 0.004, 1)
	rear, front = gunkit.open_irons(X(978), Z(703), X(354), Z(712), SIGHT_Z)  # round 2: open ring + post
	sights.add(rear, 0.002, 1)
	sights.add(front, 0.002, 1)
	sights.add(drop(cyl_y(X(1012), Z(708), 0.017, 0.03, 0.05, 10), 1, -1), 0.002, 1)

	# ---- Grip (textured) and stock
	grip = part("Grip")
	gbody = prism(P([(958, 834), (1012, 822), (1074, 952), (1072, 966), (1000, 982), (992, 972), (985, 940), (968, 900), (960, 870)]), "Y", -0.052, 0.052, DARK)
	grip.add(cut(gbody, mirror_y(prism(P([(972, 850), (1010, 845), (1060, 950), (1004, 962)]), "Y", 0.047, 0.08)), mats, DARK, bw=0.01, segs=2), 0)

	st = part("Stock")
	st.add(box(X(1132), X(1070), -0.05, 0.05, Z(815), Z(742), DARK), 0.006, 1)
	st.add(box(X(1118), X(1105), -0.056, 0.056, Z(812), Z(745), DARK), 0.003, 1)
	sbody = prism(P([(1130, 740), (1345, 733), (1350, 738), (1350, 925), (1322, 925), (1225, 830), (1160, 818), (1130, 818)]), "Y", -0.055, 0.055, DARK)
	sslots = mirror_y(group(prism(stadium(X(1255), X(1325), Z(797.5), 14 * S), "Y", 0.04, 0.08),
		gunkit.rotate_y(prism(stadium(X(1252), X(1330), Z(877), 12 * S), "Y", 0.04, 0.08), math.radians(-32), (X(1291), 0, Z(877)))))
	st.add(cut(sbody, sslots, mats, DARK, bw=0.008), 0)
	st.add(prism(P([(1350, 730), (1392, 733), (1397, 745), (1397, 915), (1390, 927), (1350, 927)]), "Y", -0.062, 0.062, DARK), 0.006, 1)

	# ---- Drum (Mag): ribbed body, front cap with hub, rims, feed neck
	drum = part("Drum", "Mag")
	drum.add(cyl_x(X(822), X(702), 0.278, DRUM_Z, 16, mat=DARK, rot=0), 0.012, 2)
	for x0, x1 in ((702, 712), (812, 822)):
		drum.add(cyl_x(X(x1), X(x0), 0.286, DRUM_Z, 16, mat=DARK, rot=0), 0.006, 1)
	drum.add(cyl_x(X(836), X(822), 0.268, DRUM_Z, 16, mat=DARK, rot=0), 0.008, 1)
	drum.add(cyl_x(X(702), X(687), 0.25, DRUM_Z, 16, mat=DARK, rot=0), 0.01, 2)
	drum.add(cyl_x(X(689), X(680), 0.075, DRUM_Z, 12, mat=METAL), 0.004, 1)
	drum.add(drop(box(X(820), X(720), -0.05, 0.05, Z(840), Z(812), DARK), 2, 1), 0.004, 1)

	# ---- Neon capsules (both sides)
	neon = part("Neon")
	for zc, a, b, h in ((768.5, 812, 855, 7), (790, 859, 899, 8)):
		neon.add(mirror_y(prism(stadium(X(a), X(b), Z(zc), h * S), "Y", RW - 0.004, RW - 0.0008, NEON)), 0)

	# ---- Charm (buddy) loop: left side, under the handguard's rear, ahead of the drum
	charm = part("CharmLoop")
	lug, tor = charm_loop(X(620), Z(817), HW + 0.002)
	charm.add(lug, 0.004, 1)
	charm.add(tor, 0)

	# ---- Moving controls
	chg = part("ChargingHandle", "ChargingHandle")
	chg.add(box(X(764), X(746), RW - 0.02, RW + 0.05, Z(800), Z(787), METAL), 0.003, 1)  # round 2: a bigger, readable knob
	chg.add(box(X(772), X(738), RW + 0.04, RW + 0.066, Z(806), Z(781), METAL), 0.005, 1)

	bolt = part("Bolt", "Bolt")
	bolt.add(box(X(882), X(790), -0.045, -0.01, Z(775), Z(752), METAL), 0.003, 1)

	sel = part("FireSelector", "FireSelector")
	sel.add(drop(cyl_y(X(985), Z(800), 0.013, RW - 0.002, RW + 0.008, 10, METAL), 1, -1), 0.002, 1)
	sel.add(prism(P([(985, 796), (1004, 798), (1004, 803), (985, 805)]), "Y", RW + 0.004, RW + 0.011, METAL), 0.002, 1)

	trig = part("Trigger", "Trigger")
	trig.add(prism(P([(918, 838), (927, 838), (934, 856), (932, 868), (926, 868), (926, 854)]), "Y", -0.009, 0.009, METAL), 0.003, 1)

	return parts


CHARM = (X(620), HW + 0.002 + 0.012, Z(817) - 0.049)

BONES = [
	("Root", None, (0.0, 0.0, 0.1)),
	("Mag", "Root", (X(770), 0.0, Z(820))),
	("ChargingHandle", "Root", (X(755), 0.0, Z(795))),
	("Bolt", "Root", (X(835), 0.0, Z(763))),
	("FireSelector", "Root", (X(985), 0.0, Z(800))),
	("Trigger", "Root", (X(922), 0.0, Z(838))),
	("Flash", "Root", (X(51) + 0.01, 0.0, BORE_Z)),
	("Charm", "Root", CHARM),
]

LOCATORS = [
	("Muzzle", "Root", (X(51), 0.0, BORE_Z), None),
	("RightGrip", "Root", (0.0, 0.0, 0.0), None),
	("LeftGrip", "Root", (X(500), 0.0, Z(822)), None),  # handguard underside
	("AimPoint", "Root", (X(978), 0.0, SIGHT_Z), gunkit.AIM_ROT),  # rear ring centre
	("Eject", "Root", (X(835), -RW, Z(763)), gunkit.EJECT_ROT),
	("CharmPoint", "Charm", CHARM, None),
]


def build():
	mats = gunkit.begin(GUN)
	parts = build_parts(mats)
	return gunkit.assemble(GUN, parts, mats, BONES, LOCATORS,
		{"class": "Heavy", "tier": "T3", "template_version": 2, "length_rel": 1.0, "att_positions": "{}", "pbr": True}, widen={"*": 1.15, "Barrel": 1.0, "Sights": 1.0, "Drum": 1.0, "Grip": 1.05, "Trigger": 1.0})


if __name__ == "__main__":
	print(build())
