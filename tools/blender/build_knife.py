# build_knife.py: builds the basic tactical Knife (10, melee) in the open Blender scene.
#
#   g = {"__name__": "build", "__file__": path}; exec(compile(open(path).read(), path, "exec"), g); g["build"]()
#
# Family conventions in tools/blender/gunkit.py: blade along +X (tip forward), edge down (-Z), the gun-left side is
# +Y, origin at the grip. Traced from the side view of
# vault/02 Art/References/Gun-Image-Concepts/Charcoal tactical knife concept sheet-10.png (P converts pixels).
# One rigid assembly on the Root bone (its head is at the grip, so draw flips and inspect turns pivot in the hand).
# Melee: no muzzle, ejection, ADS or buddy. BladeBase / BladeTip are the melee trace references (new names).

import bmesh, bpy, importlib, math, os, sys
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gunkit

importlib.reload(gunkit)
from gunkit import DARK, METAL, NEON, PANEL, Part, box, cut, cyl_x, group, mirror_y, prism

GUN = "Knife"

# Side view -> studs: tip (px 62) to pommel (1385) = 1.72 studs (the old Cutter was 1.65). Grip at (1040, 830).
S = 0.0013
OX, OY = 1040, 830


def X(px):
	return (OX - px) * S


def Z(py):
	return (OY - py) * S


def P(pts):
	return [(X(a), Z(b)) for a, b in pts]


# The cutting edge from the tip back to the choil, and the spine (clip point, then flat to the guard).
EDGE = [(62, 818), (110, 845), (170, 866), (250, 881), (350, 890), (480, 895), (620, 896), (722, 895)]
SPINE = [(722, 895), (726, 872), (742, 862), (762, 858), (762, 776), (215, 778), (62, 818)]
BEVEL = 0.022 / S  # edge bevel height in pixels


def edge_wedge(mat):
	# The satin edge bevel: a band from the edge line up to BEVEL px above it, tapering from the blade's full
	# thickness down to a thin edge.
	bm = bmesh.new()
	outer, inner = [], []
	for px, py in EDGE:
		x, z = X(px), Z(py)
		outer.append((bm.verts.new((x, 0.0018, z)), bm.verts.new((x, -0.0018, z))))
		zi = min(Z(py - BEVEL), Z(818) if px < 80 else 1e9)
		inner.append((bm.verts.new((x, 0.012, Z(py - BEVEL))), bm.verts.new((x, -0.012, Z(py - BEVEL)))))
	n = len(EDGE)
	for i in range(n - 1):
		for s in (0, 1):
			a, b, c, d = outer[i][s], outer[i + 1][s], inner[i + 1][s], inner[i][s]
			bm.faces.new((a, b, c, d) if s == 0 else (d, c, b, a))
		bm.faces.new((outer[i][0], outer[i][1], outer[i + 1][1], outer[i + 1][0]))  # the edge itself
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	for f in bm.faces:
		f.material_index = mat
	return bm


def build_parts(mats):
	parts = {}

	def part(name, bone="Root"):
		parts[name] = Part(name, bone)
		return parts[name]

	# ---- Blade: charcoal flats (from the top of the edge bevel up to the spine), satin bevel band
	bl = part("Blade")
	flats = [(px, py - BEVEL) for px, py in EDGE] + SPINE[1:-1]
	flats[0] = (62 + 6, 818 - 4)
	bl.add(prism(P(flats), "Y", -0.012, 0.012, METAL), 0.002, 1)
	bl.add(edge_wedge(PANEL), 0)

	# ---- Guard (metal), handle (black textured polymer with finger grooves), octagonal pommel (metal)
	hd = part("Hilt")
	hd.add(prism(P([(760, 745), (766, 738), (780, 738), (786, 745), (786, 898), (780, 905), (766, 905), (760, 898)]), "Y", -0.036, 0.036, METAL), 0.004, 1)
	handle = prism(P([(784, 770), (800, 762), (1300, 758), (1300, 905), (1270, 905), (1250, 892), (1170, 895), (1120, 905), (1060, 892), (1000, 905), (940, 890), (880, 905), (840, 892), (800, 905), (784, 895)]), "Y", -0.046, 0.046, DARK)
	panel = mirror_y(prism(P([(960, 790), (1240, 785), (1250, 870), (1200, 880), (960, 870), (940, 830)]), "Y", 0.042, 0.07))
	hd.add(cut(handle, panel, mats, DARK, bw=0.008, segs=2), 0)
	hd.add(cyl_x(X(1386), X(1298), 0.098, Z(832), 8, mat=METAL, rot=math.pi / 8), 0.01, 2)

	# ---- Neon: one tiny inset near the pommel (gun-left side)
	neon = part("Neon")
	neon.add(prism(P([(1188, 785), (1226, 785), (1230, 790), (1226, 795), (1188, 795), (1184, 790)]), "Y", 0.044, 0.0485, NEON), 0)

	return parts


BONES = [
	("Root", None, (0.0, 0.0, 0.0)),
]

LOCATORS = [
	("RightGrip", "Root", (0.0, 0.0, 0.0), None),
	("BladeBase", "Root", (X(760), 0.0, Z(835)), None),
	("BladeTip", "Root", (X(62), 0.0, Z(818)), None),
]


def build():
	mats = gunkit.begin(GUN)
	parts = build_parts(mats)
	return gunkit.assemble(GUN, parts, mats, BONES, LOCATORS,
		{"class": "Melee", "tier": "Melee", "template_version": 2, "length_rel": 0.44, "att_positions": "{}", "pbr": True})


if __name__ == "__main__":
	print(build())
