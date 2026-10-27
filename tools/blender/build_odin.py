# build_odin.py: builds the Odin (15, belt-fed heavy machine gun) in the open Blender scene.
#
#   g = {"__name__": "build", "__file__": path}; exec(compile(open(path).read(), path, "exec"), g); g["build"]()
#
# Family conventions in tools/blender/gunkit.py. Traced from the side view of
# vault/02 Art/References/Gun-Image-Concepts/Odin-inspired belt-fed machine gun prop sheet-15.png (P converts pixels).
# The rectangular belt box hangs under the feed section (AmmoBox bone); a short belt of five rounds rises from it into
# a feed window on the left (FP) side (FeedBelt, a child of AmmoBox so it leaves with the box). The top FeedCover
# hinges at its rear: a negative rotation about Y lifts its front. Charging handle on the left side of the rear
# receiver, bolt in the right-side ejection port. Iron sights: AimPoint at the rear aperture.
# The sheet's olive box is normalized to the family palette.

import bmesh, bpy, importlib, math, os, sys
from mathutils import Matrix

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gunkit

importlib.reload(gunkit)
from gunkit import DARK, METAL, NEON, PANEL, Part, box, charm_loop, cut, cyl_x, cyl_y, drop, group, mirror_y, prism, ring_pts

GUN = "Odin"

# Side view -> studs: muzzle (px 69) to buttpad (1385) = 4.61 studs, the heaviest gun. Grip at (1030, 900).
S = 0.0035
OX, OY = 1030, 900


def X(px):
	return (OX - px) * S


def Z(py):
	return (OY - py) * S


def P(pts):
	return [(X(a), Z(b)) for a, b in pts]


BORE_Z = Z(794)
RW = 0.08  # receiver half width
BW = 0.13  # box half width
BELT_Y = 0.045
ROUNDS = (787, 804, 821.5, 839, 856.5)


def frustum_x(x0, x1, r0, r1, z, y=0.0, segs=10, mat=METAL):
	bm = bmesh.new()
	a = [bm.verts.new((x0, y + r0 * math.cos(2 * math.pi * i / segs), z + r0 * math.sin(2 * math.pi * i / segs))) for i in range(segs)]
	b = [bm.verts.new((x1, y + r1 * math.cos(2 * math.pi * i / segs), z + r1 * math.sin(2 * math.pi * i / segs))) for i in range(segs)]
	bm.faces.new(a[::-1])
	bm.faces.new(b)
	for i in range(segs):
		j = (i + 1) % segs
		bm.faces.new((a[i], a[j], b[j], b[i]))
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	for f in bm.faces:
		f.material_index = mat
	return bm
SIGHT_Z = gunkit.sight_line(Z(735))  # round 2: open irons, rear ring centre = front post tip


def build_parts(mats):
	parts = {}

	def part(name, bone="Root"):
		parts[name] = Part(name, bone)
		return parts[name]

	# ---- Shroud (front receiver), armour plates with neon chevrons, sling loop
	rec = part("Receiver")
	shroud = prism(P([(381, 757), (615, 757), (615, 850), (395, 850), (381, 836)]), "Y", -RW, RW)
	recess = mirror_y(group(box(X(500), X(400), RW - 0.012, RW + 0.02, Z(821), Z(802)), box(X(610), X(390), RW - 0.004, RW + 0.02, Z(779), Z(776))))
	rec.add(cut(shroud, recess, mats), 0)
	plate = mirror_y(prism(P([(500, 800), (700, 800), (715, 812), (715, 846), (705, 855), (510, 855), (500, 845)]), "Y", RW - 0.004, RW + 0.012))
	chev = mirror_y(group(*[prism(P([(a, 809), (a + 10, 809), (a + 24, 826), (a + 14, 826)]), "Y", RW + 0.006, RW + 0.03) for a in (512, 528)]))
	rec.add(cut(plate, chev, mats), 0)
	loop = prism(P([(445, 850), (495, 850), (495, 874), (445, 874)]), "Y", -0.012, 0.012, DARK)
	rec.add(cut(loop, box(X(489), X(451), -0.05, 0.05, Z(869), Z(856)), mats, DARK, bw=0.003, segs=1), 0)

	# ---- Feed section (feed window on the left for the belt), rear receiver (charging slot left, ejection port
	# right), end block, trigger guard
	feed = prism(P([(615, 760), (805, 760), (805, 862), (615, 862)]), "Y", -RW, RW)
	window = box(X(805), X(728), 0.02, RW + 0.03, Z(866), Z(774))
	rec.add(cut(feed, window, mats), 0)
	for x, z in ((630, 778), (630, 800)):
		rec.add(mirror_y(drop(cyl_y(X(x), Z(z), 0.013, RW - 0.002, RW + 0.008, 6), 1, -1)), 0)
	rear = prism(P([(805, 737), (1078, 737), (1078, 812), (1065, 855), (815, 855), (805, 845)]), "Y", -RW, RW)
	rslot = box(X(1062), X(930), RW - 0.015, RW + 0.03, Z(813), Z(797))
	port = box(X(930), X(860), -RW - 0.03, -RW + 0.03, Z(812), Z(790))
	rline = mirror_y(group(box(X(1070), X(830), RW - 0.004, RW + 0.02, Z(785), Z(782)), box(X(990), X(880), RW - 0.006, RW + 0.02, Z(760), Z(752))))
	rec.add(cut(rear, group(rslot, port, rline), mats), 0)
	for x, z in ((875, 830), (1050, 830)):
		rec.add(mirror_y(drop(cyl_y(X(x), Z(z), 0.015, RW - 0.002, RW + 0.008, 6), 1, -1)), 0)
	endb = box(X(1110), X(1075), -0.078, 0.078, Z(845), Z(730), DARK)
	rec.add(cut(endb, mirror_y(box(X(1103), X(1084), 0.074, 0.1, Z(763), Z(748))), mats, DARK, bw=0.006), 0)
	guard = prism(P([(900, 853), (980, 853), (980, 880), (968, 900), (912, 900), (900, 884)]), "Y", -0.026, 0.026, DARK)
	rec.add(cut(guard, prism(P([(910, 856), (970, 856), (970, 878), (962, 892), (916, 892)]), "Y", -0.06, 0.06), mats, DARK, bw=0.004, segs=1), 0)

	# ---- Barrel, collars, flash hider
	brl = part("Barrel")
	brl.add(drop(cyl_x(X(383), X(165), 0.068, BORE_Z, 16), 0, 1), 0)
	brl.add(cyl_x(X(317), X(286), 0.092, BORE_Z, 16, mat=DARK), 0.006, 1)
	brl.add(cyl_x(X(165), X(137), 0.09, BORE_Z, 8, mat=DARK, rot=0), 0.006, 1)
	hider = cyl_x(X(135), X(69), 0.091, BORE_Z, 8, mat=DARK, rot=0)
	brl.add(cut(hider, group(box(X(117), X(80), -0.12, 0.12, BORE_Z - 0.035, BORE_Z + 0.035), cyl_x(X(76), X(60), 0.045, BORE_Z, 12)), mats, DARK, bw=0.007, segs=1), 0)

	# ---- Iron sights
	sights = part("Sights")
	sights.add(box(X(359), X(317), -0.062, 0.062, Z(840), Z(755), DARK), 0.008, 1)
	sights.add(box(X(1065), X(1005), -0.04, 0.04, Z(745), Z(735), DARK), 0.003, 1)
	rear, front = gunkit.open_irons(X(1024), Z(735), X(335), Z(755), SIGHT_Z)  # round 2: open ring + post
	sights.add(rear, 0.002, 1)
	sights.add(front, 0.002, 1)

	# ---- Grip and stock (window cut through)
	grip = part("Grip")
	grip.add(prism(P([(962, 853), (1045, 853), (1090, 955), (1095, 972), (1012, 990), (1005, 975), (975, 900)]), "Y", -0.055, 0.055, DARK), 0.008, 2)
	st = part("Stock")
	st.add(box(X(1140), X(1108), -0.062, 0.062, Z(852), Z(765), DARK), 0.006, 1)
	sbody = prism(P([(1138, 770), (1285, 786), (1305, 760), (1312, 760), (1312, 962), (1290, 965), (1138, 852)]), "Y", -0.058, 0.058, DARK)
	st.add(cut(sbody, prism(P([(1195, 822), (1297, 822), (1297, 898), (1285, 900)]), "Y", -0.1, 0.1), mats, DARK, bw=0.01), 0)
	st.add(prism(P([(1305, 757), (1375, 757), (1385, 767), (1385, 955), (1375, 967), (1305, 967)]), "Y", -0.066, 0.066, DARK), 0.008, 1)

	# ---- Ammo box (removable): lid band, recessed side panels with a raised X, handle, front clip
	ab = part("AmmoBox", "AmmoBox")
	body = box(X(865), X(655), -BW, BW, Z(1005), Z(866))
	ab.add(cut(body, mirror_y(box(X(845), X(675), BW - 0.008, BW + 0.02, Z(995), Z(882))), mats, PANEL, bw=0.01), 0)
	ab.add(box(X(868), X(652), -BW - 0.005, BW + 0.005, Z(877), Z(862)), 0.006, 1)
	for a, b in (((680, 885), (840, 992)), ((680, 992), (840, 885))):
		dx, dz = X(a[0]) - X(b[0]), Z(a[1]) - Z(b[1])  # raised X: a bar from b to a in studs
		bar = box(0, math.hypot(dx, dz), BW - 0.009, BW - 0.002, -0.008, 0.008)
		bmesh.ops.rotate(bar, verts=bar.verts[:], cent=(0, 0, 0), matrix=Matrix.Rotation(-math.atan2(dz, dx), 3, "Y"))
		bmesh.ops.translate(bar, vec=(X(b[0]), 0, Z(b[1])), verts=bar.verts[:])
		ab.add(mirror_y(bar), 0)
	handle = prism(P([(760, 897), (828, 897), (828, 922), (760, 922)]), "Y", BW, BW + 0.016, DARK)
	ab.add(cut(handle, box(X(822), X(766), BW - 0.01, BW + 0.05, Z(916), Z(903)), mats, DARK, bw=0.003, segs=1), 0)
	ab.add(box(X(655), X(630), -0.03, 0.03, Z(910), Z(877), DARK), 0.004, 1)

	# ---- Feed belt: five rounds with links, rising from the box into the feed window
	belt = part("FeedBelt", "FeedBelt")
	for zc in ROUNDS:
		z = Z(zc)
		belt.add(cyl_x(X(800), X(752), 0.021, z, 10, y=BELT_Y), 0.002, 1)
		belt.add(frustum_x(X(752), X(735), 0.021, 0.007, z, BELT_Y), 0)
		belt.add(box(X(790), X(762), BELT_Y - 0.03, BELT_Y - 0.012, z - 0.026, z + 0.026, DARK), 0.002, 1)

	# ---- Feed cover (hinged at its rear)
	cover = part("FeedCover", "FeedCover")
	cover.add(prism(P([(635, 740), (641, 734), (800, 734), (805, 740), (805, 761), (635, 761)]), "Y", -0.076, 0.076), 0.008, 2)
	cover.add(mirror_y(box(X(800), X(785), 0.07, 0.084, Z(760), Z(738), DARK)), 0.003, 1)  # hinge ears
	cover.add(box(X(650), X(640), -0.03, 0.03, Z(735), Z(727), METAL), 0.002, 1)  # latch tab

	# ---- Neon: chevrons (both sides) and the end-block squares
	neon = part("Neon")
	for a in (512, 528):
		neon.add(mirror_y(prism(P([(a, 809), (a + 10, 809), (a + 24, 826), (a + 14, 826)]), "Y", RW + 0.002, RW + 0.0058, NEON)), 0)
	neon.add(mirror_y(box(X(1102), X(1085), 0.074, 0.0775, Z(762), Z(749), NEON)), 0)

	# ---- Charm (buddy) loop: left side of the shroud's underside
	charm = part("CharmLoop")
	lug, tor = charm_loop(X(420), Z(850), RW + 0.002)
	charm.add(lug, 0.004, 1)
	charm.add(tor, 0)

	# ---- Moving controls
	chg = part("ChargingHandle", "ChargingHandle")
	chg.add(box(X(1057), X(997), RW - 0.012, RW + 0.008, Z(812), Z(798), METAL), 0.003, 1)
	chg.add(prism(P([(1036, 792), (1060, 792), (1060, 818), (1036, 818)]), "Y", RW + 0.008, RW + 0.058, METAL), 0.005, 1)  # round 2: bigger

	bolt = part("Bolt", "Bolt")
	bolt.add(box(X(940), X(850), -RW + 0.025, -RW + 0.045, Z(810), Z(792), METAL), 0.003, 1)

	trig = part("Trigger", "Trigger")
	trig.add(prism(P([(938, 856), (947, 856), (955, 872), (953, 888), (947, 888), (947, 872)]), "Y", -0.01, 0.01, METAL), 0.003, 1)

	return parts


CHARM = (X(420), RW + 0.002 + 0.012, Z(850) - 0.049)

BONES = [
	("Root", None, (0.0, 0.0, 0.1)),
	("AmmoBox", "Root", (X(760), 0.0, Z(866))),
	("FeedBelt", "AmmoBox", (X(768), BELT_Y, Z(787))),
	("FeedCover", "Root", (X(800), 0.0, Z(740))),
	("ChargingHandle", "Root", (X(1027), 0.0, Z(805))),
	("Bolt", "Root", (X(895), 0.0, Z(801))),
	("Trigger", "Root", (X(942), 0.0, Z(856))),
	("Flash", "Root", (X(69) + 0.01, 0.0, BORE_Z)),
	("Charm", "Root", CHARM),
]

LOCATORS = [
	("Muzzle", "Root", (X(69), 0.0, BORE_Z), None),
	("RightGrip", "Root", (0.0, 0.0, 0.0), None),
	("LeftGrip", "Root", (X(540), 0.0, Z(856)), None),  # under the shroud's armour plate
	("AimPoint", "Root", (X(1024), 0.0, SIGHT_Z), gunkit.AIM_ROT),  # rear ring centre
	("Eject", "Root", (X(895), -RW, Z(801)), gunkit.EJECT_ROT),
	("BeltFeedPoint", "FeedBelt", (X(768), BELT_Y, Z(780)), None),
	("CharmPoint", "Charm", CHARM, None),
]


def build():
	mats = gunkit.begin(GUN)
	parts = build_parts(mats)
	return gunkit.assemble(GUN, parts, mats, BONES, LOCATORS,
		{"class": "Heavy", "tier": "T4", "template_version": 2, "length_rel": 1.07, "att_positions": "{}", "pbr": True}, widen={"*": 1.2, "Barrel": 1.0, "Sights": 1.0, "Grip": 1.05, "Trigger": 1.0})


if __name__ == "__main__":
	print(build())
