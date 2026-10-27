# build_outlaw.py: builds the Outlaw (12, twin-barrel break-action scoped rifle) in the open Blender scene.
#
#   g = {"__name__": "build", "__file__": path}; exec(compile(open(path).read(), path, "exec"), g); g["build"]()
#
# Family conventions in tools/blender/gunkit.py. Traced from the side view of
# vault/02 Art/References/Gun-Image-Concepts/Stacked-barrel scoped rifle concept sheet-12.png (P converts pixels).
# Round 2 (2026-10-26): widened to the Vandal's chunk (receiver, fore-end, stock, barrels), vent rib.
# Break action like the Shorty: the Barrels bone (both barrels, front clamp, breech block and fore-end) hinges on the
# lower knuckle at the receiver's front; a positive rotation about its Y axis drops the muzzles. The scope stays on
# the stationary receiver. RoundUpper / RoundLower are the chamber props (children of Barrels); the upper barrel is
# taken to fire first. Scoped: AimPoint at the eyepiece, ScopeAxis at the objective, dark non-emissive glass.
# New references beyond the family set: MuzzleLower, EjectLower, ChamberUpper, ChamberLower, ScopeAxis (locators);
# RoundUpper, RoundLower, BreechLatch (bones). LeftGrip is on the fore-end (Barrels).

import bmesh, bpy, importlib, math, os, sys
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gunkit

importlib.reload(gunkit)
from gunkit import DARK, METAL, NEON, PANEL, Part, box, charm_loop, cut, cyl_x, cyl_y, drop, group, mirror_y, prism, ring_pts

GUN = "Outlaw"

# Side view -> studs: muzzle (px 51) to buttpad (1398) = 4.58 studs (the Marshal is 4.43). Grip (wrist) at (1065, 920).
S = 0.0034
OX, OY = 1065, 920


def X(px):
	return (OX - px) * S


def Z(py):
	return (OY - py) * S


def P(pts):
	return [(X(a), Z(b)) for a, b in pts]


UPPER_Z = Z(784)
LOWER_Z = Z(820)
SCOPE_Z = Z(736)
HINGE = (790, 851)
BREECH_X = X(762)


def frustum_x(x0, x1, r0, r1, z, segs=16, mat=DARK):
	bm = bmesh.new()
	a = [bm.verts.new((x0, r0 * math.cos(2 * math.pi * i / segs), z + r0 * math.sin(2 * math.pi * i / segs))) for i in range(segs)]
	b = [bm.verts.new((x1, r1 * math.cos(2 * math.pi * i / segs), z + r1 * math.sin(2 * math.pi * i / segs))) for i in range(segs)]
	bm.faces.new(a[::-1])
	bm.faces.new(b)
	for i in range(segs):
		j = (i + 1) % segs
		bm.faces.new((a[i], a[j], b[j], b[i]))
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	for f in bm.faces:
		f.material_index = mat
	return bm


def build_parts(mats):
	parts = {}

	def part(name, bone="Root"):
		parts[name] = Part(name, bone)
		return parts[name]

	rw = 0.092  # receiver half width (round 2: chunkier, near the Vandal's)

	# ---- Receiver (charcoal): hinge knuckles, side panel, neon pocket, rail, trigger guard
	rec = part("Receiver")
	body = prism(P([(760, 782), (770, 774), (990, 774), (1010, 784), (1024, 800), (1024, 886), (760, 886)]), "Y", -rw, rw)
	panel = mirror_y(prism(P([(830, 790), (960, 790), (990, 812), (990, 860), (880, 870), (830, 860)]), "Y", rw - 0.004, rw + 0.02))
	pocket = mirror_y(prism(P([(886, 844), (908, 844), (902, 862), (880, 862)]), "Y", rw - 0.005, rw + 0.02))
	rec.add(cut(body, group(panel, pocket), mats), 0)
	for cx, cy in ((784, 806), HINGE):
		rec.add(mirror_y(drop(cyl_y(X(cx), Z(cy), 0.078, rw - 0.002, rw + 0.01, 20, PANEL), 1, -1)), 0.005, 1)  # knuckles
		rec.add(mirror_y(drop(cyl_y(X(cx), Z(cy), 0.016, rw + 0.006, rw + 0.014, 8), 1, -1)), 0)  # pin heads
	rec.add(box(X(975), X(765), -0.032, 0.032, Z(778), Z(770), DARK), 0.002, 1)  # rail
	guard = prism(P([(898, 884), (989, 884), (989, 912), (980, 921), (912, 921), (898, 905)]), "Y", -0.034, 0.034, DARK)
	rec.add(cut(guard, prism(P([(912, 886), (982, 886), (982, 908), (918, 910)]), "Y", -0.06, 0.06), mats, DARK, bw=0.004, segs=1), 0)

	# ---- Scope (fixed on the receiver)
	sc = part("Scope")
	sc.add(cyl_x(X(758), X(716), 0.11, SCOPE_Z, 20), 0.006, 1)
	sc.add(frustum_x(X(800), X(758), 0.05, 0.11, SCOPE_Z, 20), 0)
	sc.add(cyl_x(X(1012), X(798), 0.05, SCOPE_Z, 20), 0.003, 1)
	sc.add(frustum_x(X(1080), X(1010), 0.09, 0.06, SCOPE_Z, 20), 0)
	sc.add(cyl_x(X(1082), X(1055), 0.09, SCOPE_Z, 20), 0.005, 1)
	sc.add(prism(ring_pts(X(916), 0.0, 0.042, 12, math.pi / 12), "Z", SCOPE_Z, Z(696), METAL), 0.004, 1)
	sc.add(prism(ring_pts(X(916), 0.0, 0.048, 16, math.pi / 16), "Z", Z(702), Z(690), METAL), 0.004, 1)
	sc.add(prism(ring_pts(X(916), SCOPE_Z, 0.05, 16, math.pi / 16), "Y", 0.0, 0.085, METAL), 0.004, 1)
	for x in (863, 970):
		sc.add(cyl_x(X(x + 13), X(x - 13), 0.06, SCOPE_Z, 16, mat=METAL), 0.003, 1)
		sc.add(box(X(x + 13), X(x - 13), -0.026, 0.026, Z(778), SCOPE_Z - 0.03, METAL), 0.003, 1)
	lens = part("ScopeLens")
	lens.add(cyl_x(X(714), X(712), 0.1, SCOPE_Z, 20, mat=DARK), 0)
	lens.add(cyl_x(X(1084), X(1082), 0.08, SCOPE_Z, 20, mat=DARK), 0)

	# ---- Stock (black polymer, textured wrist) and buttpad
	st = part("Stock")
	stock = prism(P([(1024, 790), (1040, 795), (1120, 840), (1135, 815), (1160, 808), (1360, 808), (1360, 1000), (1100, 1000), (1080, 985), (1060, 960), (1040, 925), (1000, 905), (992, 886), (1024, 886)]), "Y", -0.08, 0.08, DARK)
	st.add(cut(stock, mirror_y(prism(P([(1040, 850), (1100, 862), (1122, 930), (1070, 935)]), "Y", 0.076, 0.1)), mats, DARK, bw=0.012, segs=2), 0)
	st.add(prism(P([(1353, 806), (1390, 808), (1398, 820), (1398, 990), (1390, 1001), (1353, 1001)]), "Y", -0.086, 0.086, DARK), 0.006, 1)

	# ---- Neon: receiver parallelogram (both sides)
	neon = part("Neon")
	neon.add(mirror_y(prism(P([(887, 845), (907, 845), (901, 861), (881, 861)]), "Y", rw - 0.004, rw - 0.0008, NEON)), 0)

	# ---- Charm (buddy) loop: left side of the receiver's underside, behind the hinge
	charm = part("CharmLoop")
	lug, tor = charm_loop(X(850), Z(878), rw + 0.002)
	charm.add(lug, 0.004, 1)
	charm.add(tor, 0)

	# ---- Barrels (break-action group): two barrels, front clamp, breech block with chambers, fore-end
	bar = part("Barrels", "Barrels")
	for zc, x_end, r in ((UPPER_Z, 51, 0.056), (LOWER_Z, 51, 0.06)):
		bar.add(drop(cyl_x(X(740), X(70), r, zc, 16), 0, 1), 0)
		ring = cyl_x(X(72), X(x_end), r + 0.006, zc, 16)
		bar.add(cut(ring, cyl_x(X(56), X(44), r * 0.65, zc, 16), mats, DARK, bw=0.005, segs=1), 0)
	rib = box(X(735), X(80), -0.022, 0.022, UPPER_Z + 0.05, UPPER_Z + 0.072, DARK)  # vent rib on top
	slots = group(*[box(X(700) + i * 0.16, X(700) + i * 0.16 + 0.05, -0.05, 0.05, UPPER_Z + 0.04, UPPER_Z + 0.063) for i in range(13)])
	rib = cut(rib, slots, mats, METAL, bw=0.002, segs=1)
	bar.add(rib, 0)
	bar.add(box(X(735), X(140), -0.046, 0.046, LOWER_Z + 0.025, UPPER_Z - 0.025, DARK), 0.003, 1)  # web filling the valley between the barrels
	clamp = [(-0.08, Z(758)), (0.08, Z(758)), (0.098, Z(774)), (0.098, Z(834)), (0.08, Z(848)), (-0.08, Z(848)), (-0.098, Z(834)), (-0.098, Z(774))]
	bar.add(prism(clamp, "X", X(132), X(96), DARK), 0.006, 1)
	block = box(X(764), X(730), -0.09, 0.09, Z(874), Z(764))
	chambers = group(cyl_x(BREECH_X - 0.12, BREECH_X + 0.01, 0.04, UPPER_Z, 16), cyl_x(BREECH_X - 0.12, BREECH_X + 0.01, 0.043, LOWER_Z, 16))
	bar.add(cut(block, chambers, mats, METAL, bw=0.006, segs=1), 0)
	fore = prism(P([(331, 822), (345, 807), (725, 807), (737, 822), (737, 872), (725, 886), (345, 886), (331, 872)]), "Y", -0.092, 0.092)
	bar.add(cut(fore, mirror_y(box(X(625), X(387), 0.086, 0.12, Z(876), Z(828))), mats, DARK, bw=0.008), 0)

	# ---- Other moving parts
	latch = part("BreechLatch", "BreechLatch")
	latch.add(prism(P([(1008, 790), (1028, 782), (1034, 788), (1018, 806), (1010, 806)]), "Y", -0.018, 0.018, METAL), 0.003, 1)

	trig = part("Trigger", "Trigger")
	trig.add(prism(P([(961, 886), (972, 886), (978, 896), (978, 905), (972, 911), (966, 911), (968, 902), (965, 894)]), "Y", -0.009, 0.009, METAL), 0.003, 1)

	for name, zc in (("RoundUpper", UPPER_Z), ("RoundLower", LOWER_Z)):
		rd = part(name, name)
		rd.add(cyl_x(BREECH_X - 0.005, BREECH_X + 0.24, 0.034, zc, 10, mat=METAL), 0.003, 1)
		rd.add(cyl_x(BREECH_X - 0.012, BREECH_X + 0.02, 0.04, zc, 10, mat=METAL), 0.003, 1)  # rim

	return parts


HINGE_POS = (X(HINGE[0]), 0.0, Z(HINGE[1]))
CHARM = (X(850), 0.092 + 0.002 + 0.012, Z(878) - 0.049)

BONES = [
	("Root", None, (0.0, 0.0, 0.1)),
	("Barrels", "Root", HINGE_POS),
	("RoundUpper", "Barrels", (BREECH_X, 0.0, UPPER_Z)),
	("RoundLower", "Barrels", (BREECH_X, 0.0, LOWER_Z)),
	("BreechLatch", "Root", (X(1018), 0.0, Z(800))),
	("Trigger", "Root", (X(966), 0.0, Z(886))),
	("Flash", "Root", (X(51) + 0.01, 0.0, UPPER_Z)),
	("Charm", "Root", CHARM),
]

EJECT_BACK = Vector((-0.86, 0, 0.51)).to_track_quat("Z", "Y").to_matrix().to_4x4()

LOCATORS = [
	("Muzzle", "Barrels", (X(51), 0.0, UPPER_Z), None),
	("MuzzleLower", "Barrels", (X(51), 0.0, LOWER_Z), None),
	("RightGrip", "Root", (0.0, 0.0, 0.0), None),
	("LeftGrip", "Barrels", (X(530), 0.0, Z(886)), None),  # on the fore-end
	("AimPoint", "Root", (X(1084), 0.0, SCOPE_Z), gunkit.AIM_ROT),  # eyepiece
	("ScopeAxis", "Root", (X(714), 0.0, SCOPE_Z), None),
	("Eject", "Barrels", (BREECH_X, 0.0, UPPER_Z), EJECT_BACK),
	("EjectLower", "Barrels", (BREECH_X, 0.0, LOWER_Z), EJECT_BACK),
	("ChamberUpper", "Barrels", (BREECH_X + 0.1, 0.0, UPPER_Z), None),
	("ChamberLower", "Barrels", (BREECH_X + 0.1, 0.0, LOWER_Z), None),
	("CharmPoint", "Charm", CHARM, None),
]


def build():
	mats = gunkit.begin(GUN)
	parts = build_parts(mats)
	return gunkit.assemble(GUN, parts, mats, BONES, LOCATORS,
		{"class": "Sniper", "tier": "T3", "template_version": 2, "length_rel": 1.17, "att_positions": "{}", "pbr": True})


if __name__ == "__main__":
	print(build())
