# build_marshal.py: builds the Marshal (11, light scoped lever-action rifle) in the open Blender scene.
#
#   g = {"__name__": "build", "__file__": path}; exec(compile(open(path).read(), path, "exec"), g); g["build"]()
#
# Family conventions in tools/blender/gunkit.py. Traced from the side view of
# vault/02 Art/References/Gun-Image-Concepts/Scoped lever-action rifle design sheet-11.png (P converts pixels).
# Scoped: the optic is fixed and non-emissive (dark glass, no reticle); AimPoint sits at the eyepiece on the scope
# axis (ScopeAxis marks the objective end); the game owns zoom and the overlay. Lever action: the Lever (loop under
# the receiver, pivot at its front) swings down to cycle; the Bolt slides back and the Hammer cocks with it.
# Tubular magazine under the barrel, loaded through a right-side gate: "Shell" is the reusable round prop
# (hidden in the receiver at the gate at rest); LoadPoint marks the gate. New references: Lever, Hammer, Shell
# (bones); ScopeAxis, LoadPoint (locators).

import bmesh, bpy, importlib, math, os, sys
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gunkit

importlib.reload(gunkit)
from gunkit import DARK, METAL, NEON, PANEL, Part, box, charm_loop, cut, cyl_x, cyl_y, drop, group, merge, mirror_y, prism, ring_pts

GUN = "Marshal"

# Side view -> studs: muzzle (px 51) to buttplate (1392) = 4.43 studs. Grip (the wrist) at (1020, 865).
S = 0.0033
OX, OY = 1020, 865


def X(px):
	return (OX - px) * S


def Z(py):
	return (OY - py) * S


def P(pts):
	return [(X(a), Z(b)) for a, b in pts]


BORE_Z = Z(803)
TUBE_Z = Z(830)
SCOPE_Z = Z(764)
GATE = (900, 852)


def frustum_x(x0, x1, r0, r1, z, segs=16, mat=DARK):
	# A cone section along X from (x0, r0) to (x1, r1).
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


def turret_z(x, y, r, z0, z1, segs=12, mat=DARK):
	return prism(ring_pts(x, y, r, segs, math.pi / segs), "Z", z0, z1, mat)


def build_parts(mats):
	parts = {}

	def part(name, bone="Root"):
		parts[name] = Part(name, bone)
		return parts[name]

	rw = 0.055  # receiver half width

	# ---- Receiver (steel grey): side plate, neon slot pocket, ejection/loading openings on the right
	rec = part("Receiver")
	body = prism(P([(751, 800), (760, 795), (942, 795), (968, 810), (990, 840), (990, 878), (968, 880), (760, 879), (751, 872)]), "Y", -rw, rw)
	recess = mirror_y(prism(P([(775, 808), (930, 808), (950, 830), (950, 868), (775, 868)]), "Y", rw - 0.004, rw + 0.02))
	slot = mirror_y(box(X(930), X(860), rw - 0.008, rw + 0.02, Z(848), Z(838)))
	gate = box(X(925), X(880), -rw - 0.02, -rw + 0.016, Z(860), Z(845))
	rec.add(cut(body, group(recess, slot, gate), mats), 0)
	rec.add(box(X(940), X(772), -0.022, 0.022, Z(796), Z(788), DARK), 0.002, 1)  # scope rail

	# ---- Barrel, magazine tube, barrel band, front sight
	bar = part("Barrel")
	bar.add(cut(cyl_x(X(752), X(51), 0.042, BORE_Z, 16), cyl_x(X(56), X(44), 0.022, BORE_Z, 12), mats, DARK, bw=0.006, segs=1), 0)
	bar.add(drop(cyl_x(X(752), X(100), 0.046, TUBE_Z, 16), 0, -1), 0.004, 1)
	bar.add(cyl_x(X(100), X(94), 0.049, TUBE_Z, 16, mat=DARK), 0.004, 1)  # tube cap
	bar.add(prism(P([(415, 788), (443, 788), (443, 850), (415, 850)]), "Y", -0.052, 0.052), 0.005, 1)  # barrel band
	bar.add(prism(P([(75, 791), (80, 776), (92, 772), (106, 773), (110, 791)]), "Y", -0.012, 0.012, DARK), 0.002, 1)

	# ---- Fore-end (black polymer) with a blue diamond
	fe = part("ForeEnd")
	fe.add(prism(P([(443, 812), (455, 802), (735, 802), (751, 815), (751, 860), (738, 869), (455, 869), (443, 858)]), "Y", -0.058, 0.058, DARK), 0.008, 2)

	# ---- Scope (fixed): objective bell, tube, rings, turrets, eyepiece, dark lenses
	sc = part("Scope")
	sc.add(cyl_x(X(705), X(670), 0.075, SCOPE_Z, 20), 0.006, 1)
	sc.add(frustum_x(X(758), X(705), 0.046, 0.075, SCOPE_Z, 20), 0)
	sc.add(cyl_x(X(912), X(756), 0.046, SCOPE_Z, 20), 0.003, 1)
	sc.add(frustum_x(X(961), X(912), 0.062, 0.05, SCOPE_Z, 20), 0)
	sc.add(cyl_x(X(963), X(940), 0.062, SCOPE_Z, 20), 0.005, 1)
	sc.add(turret_z(X(832), 0.0, 0.034, SCOPE_Z, Z(732)), 0.004, 1)
	sc.add(prism(ring_pts(X(832), Z(770), 0.03, 12, math.pi / 12), "Y", 0.0, 0.07, DARK), 0.004, 1)  # side turret
	for x in (785, 890):
		sc.add(cyl_x(X(x + 12), X(x - 12), 0.056, SCOPE_Z, 16, mat=METAL), 0.003, 1)
		sc.add(box(X(x + 12), X(x - 12), -0.024, 0.024, Z(796), SCOPE_Z - 0.03, METAL), 0.003, 1)
	lens = part("ScopeLens")
	lens.add(cyl_x(X(668), X(666), 0.068, SCOPE_Z, 20, mat=DARK), 0)  # objective glass
	lens.add(cyl_x(X(965), X(963), 0.055, SCOPE_Z, 20, mat=DARK), 0)  # ocular glass

	# ---- Stock (black polymer) and buttplate
	st = part("Stock")
	st.add(prism(P([(968, 800), (985, 800), (1100, 845), (1380, 845), (1388, 855), (1388, 945), (1380, 955), (1150, 952), (1070, 905), (1040, 890), (968, 880)]), "Y", -0.055, 0.055, DARK), 0.012, 2)
	st.add(prism(P([(1386, 846), (1394, 852), (1396, 862), (1396, 945), (1394, 955), (1386, 957)]), "Y", -0.06, 0.06, DARK), 0.004, 1)

	# ---- Pins (metal)
	pins = part("Pins")
	for px, py in ((849, 873), (430, 830), (770, 860)):
		w = rw if px > 700 else 0.052
		pins.add(mirror_y(drop(cyl_y(X(px), Z(py), 0.011, w - 0.002, w + 0.006, 8), 1, -1)), 0)

	# ---- Neon: fore-end diamond and receiver slot accent (both sides)
	neon = part("Neon")
	neon.add(mirror_y(prism(P([(675, 830), (712, 830), (704, 844), (667, 844)]), "Y", 0.058 - 0.002, 0.058 + 0.0025, NEON)), 0)
	neon.add(mirror_y(box(X(930), X(908), rw - 0.006, rw - 0.002, Z(847), Z(839), NEON)), 0)

	# ---- Charm (buddy) loop: left side of the receiver's front, under the scope
	charm = part("CharmLoop")
	lug, tor = charm_loop(X(772), Z(868), rw + 0.002)
	charm.add(lug, 0.004, 1)
	charm.add(tor, 0)

	# ---- Moving parts
	lever = part("Lever", "Lever")
	front = prism(P([(842, 866), (952, 878), (958, 912), (882, 914), (848, 896)]), "Y", -0.018, 0.018, METAL)
	front_hole = prism(P([(866, 880), (944, 886), (946, 904), (888, 905), (870, 894)]), "Y", -0.05, 0.05)
	lever.add(cut(front, front_hole, mats, METAL, bw=0.004, segs=1), 0)
	loop = prism(P([(950, 878), (1000, 880), (1040, 898), (1060, 942), (1052, 964), (1010, 966), (978, 935), (952, 912)]), "Y", -0.018, 0.018, METAL)
	loop_hole = prism(P([(968, 892), (998, 893), (1030, 908), (1044, 940), (1038, 952), (1014, 952), (990, 926), (968, 904)]), "Y", -0.05, 0.05)
	lever.add(cut(loop, loop_hole, mats, METAL, bw=0.004, segs=1), 0)

	bolt = part("Bolt", "Bolt")
	bolt.add(box(X(968), X(880), -0.036, 0.036, Z(812), Z(796), METAL), 0.003, 1)  # top of the bolt, rides back over the tang

	ham = part("Hammer", "Hammer")
	ham.add(prism(P([(952, 830), (962, 805), (972, 795), (995, 795), (990, 803), (975, 810), (968, 830)]), "Y", -0.013, 0.013, METAL), 0.003, 1)

	trig = part("Trigger", "Trigger")
	trig.add(prism(P([(912, 872), (922, 872), (930, 884), (933, 897), (928, 904), (921, 903), (923, 892), (918, 882)]), "Y", -0.009, 0.009, METAL), 0.003, 1)

	shell = part("Shell", "Shell")
	shell.add(cyl_x(X(GATE[0] + 30), X(GATE[0] - 40), 0.022, Z(GATE[1]), 10, mat=METAL), 0.003, 1)

	return parts


CHARM = (X(772), 0.055 + 0.002 + 0.012, Z(868) - 0.049)

BONES = [
	("Root", None, (0.0, 0.0, 0.1)),
	("Lever", "Root", (X(849), 0.0, Z(873))),
	("Bolt", "Root", (X(925), 0.0, Z(804))),
	("Hammer", "Root", (X(962), 0.0, Z(828))),
	("Trigger", "Root", (X(918), 0.0, Z(872))),
	("Shell", "Root", (X(GATE[0]), 0.0, Z(GATE[1]))),
	("Flash", "Root", (X(51) + 0.01, 0.0, BORE_Z)),
	("Charm", "Root", CHARM),
]

EJECT_UP_RIGHT = Vector((0, -0.4, 0.9)).to_track_quat("Z", "Y").to_matrix().to_4x4()

LOCATORS = [
	("Muzzle", "Root", (X(51), 0.0, BORE_Z), None),
	("RightGrip", "Root", (0.0, 0.0, 0.0), None),
	("LeftGrip", "Root", (X(600), 0.0, Z(869)), None),
	("AimPoint", "Root", (X(963), 0.0, SCOPE_Z), gunkit.AIM_ROT),  # eyepiece
	("ScopeAxis", "Root", (X(668), 0.0, SCOPE_Z), None),  # objective end; with AimPoint it gives the scope axis
	("Eject", "Root", (X(925), 0.0, Z(800)), EJECT_UP_RIGHT),
	("LoadPoint", "Root", (X(GATE[0]), -0.055, Z(GATE[1])), None),
	("CharmPoint", "Charm", CHARM, None),
]


def build():
	mats = gunkit.begin(GUN)
	parts = build_parts(mats)
	return gunkit.assemble(GUN, parts, mats, BONES, LOCATORS,
		{"class": "Sniper", "tier": "T2", "template_version": 2, "length_rel": 1.14, "att_positions": "{}", "pbr": True})


if __name__ == "__main__":
	print(build())
