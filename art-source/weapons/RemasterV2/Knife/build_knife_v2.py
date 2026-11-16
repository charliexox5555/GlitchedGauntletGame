# build_knife_v2.py: RemasterV2 Knife (fixed-blade tactical knife, melee). Blender MCP only.
# Finish from vault/02 Art/References/Gun-Image-Concepts/Charcoal tactical knife concept sheet-10.png: clip-point blade
# with a satin cutting bevel, a sabre grind line and a plunge at the ricasso; choil; chamfered metal guard plate;
# black polymer handle with finger swells and recessed textured panels; faceted octagonal pommel with a lanyard hole;
# one small blue inset near the pommel (gun-left side).
# Contract measured on the original Knife.blend (REF_Knife_Original): blade along +X (tip forward), edge down (-Z),
# gun-left +Y, origin at the grip; one rigid assembly on the Root bone (0,0,0); locators RightGrip (0,0,0),
# BladeBase (0.364,0,-0.0065), BladeTip (1.2714,0,0.0156). Melee: no muzzle, eject, ADS or charm.
# The concept's pixel frame is the original builder's (S 0.0013, origin px 1040/830, tip px 62 -> pommel px 1386).
# Changes: blade 0.024 -> 0.032 thick at the spine with a real cross-section (spine flat, sabre grind, satin edge
# bevel to a 0.003 edge), a proper clip point that thins to the tip, a cut choil, a plunge step at the ricasso; guard
# with chamfered faces; handle 0.092 -> 0.1 wide, octagon-section, finger swells, two recessed grip panels; pommel
# lofted (front lip, flats, back chamfer) with a through lanyard hole.

import bpy, math, sys, importlib
import bmesh

ROOT = r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/art-source/weapons/RemasterV2"
sys.path.insert(0, ROOT + "/_Library")
import v2kit as K  # noqa: E402
import v2build as B  # noqa: E402

importlib.reload(K)
importlib.reload(B)
from v2kit import BODY, PANEL, DARK, METAL, GRIP, ACCENT, NEON  # noqa: E402

GUN = "Knife"
S, OX, OY = 0.0013, 1040, 830
T = 0.016  # blade half-thickness at the spine


def X(px):
	return (OX - px) * S


def Z(py):
	return (OY - py) * S


def P(pts):
	return [(X(a), Z(b)) for a, b in pts]


# Blade stations (px x) from the tip back to the plunge, with each row's height (py) and half-thickness.
# Rows: E edge, B top of the satin edge bevel, G sabre grind line, S spine. Rows that coincide share a vertex.
STATIONS = [
	# px,  E py, E t,    B py, B t,    G py, G t,   S py,  S t
	(62, 818, 0.0, 818, 0.0, 818, 0.0, 818, 0.0),
	(110, 845, 0.0015, 832, 0.004, 806, 0.007, 806, 0.007),
	(170, 866, 0.0015, 850, 0.0065, 790, 0.011, 790, 0.011),
	(215, 874, 0.0015, 857, 0.0065, 792, 0.0145, 778, 0.0145),
	(250, 881, 0.0015, 864, 0.0065, 798, T, 777, T),
	(350, 890, 0.0015, 873, 0.0065, 806, T, 776, T),
	(480, 895, 0.0015, 878, 0.0065, 808, T, 776, T),
	(620, 896, 0.0015, 879, 0.0065, 808, T, 776, T),
	(722, 895, 0.0015, 878, 0.0065, 808, T, 776, T),
]
ROW_MATS = (METAL, BODY, PANEL)  # v03: E-B bright satin edge (palette v03), B-G charcoal grind, G-S steel-grey flat


def blade_bm():
	bm = bmesh.new()
	cache = {}

	def v(x, y, z):
		k = (round(x, 5), round(y, 5), round(z, 5))
		if k not in cache:
			cache[k] = bm.verts.new(k)
		return cache[k]

	def face(vs, mat):
		out = []
		for a in vs:
			if a not in out:
				out.append(a)
		if len(out) >= 3 and bm.faces.get(out) is None:
			f = bm.faces.new(out)
			f.material_index = mat

	grid = []  # grid[i][row][side] side 0 = +Y, 1 = -Y
	for px, ez, et, bz, bt, gz, gt, sz, st in STATIONS:
		x = X(px)
		rows = []
		for z, t in ((ez, et), (bz, bt), (gz, gt), (sz, st)):
			rows.append((v(x, t, Z(z)), v(x, -t, Z(z))))
		grid.append(rows)
	n = len(grid)
	for i in range(n - 1):
		a, b = grid[i], grid[i + 1]
		for r in range(3):
			face((a[r][0], b[r][0], b[r + 1][0], a[r + 1][0]), ROW_MATS[r])  # +Y
			face((a[r + 1][1], b[r + 1][1], b[r][1], a[r][1]), ROW_MATS[r])  # -Y
		face((a[0][1], b[0][1], b[0][0], a[0][0]), METAL)  # edge flat
		face((a[3][0], b[3][0], b[3][1], a[3][1]), PANEL)  # spine
	end = grid[-1]  # back cap (hidden inside the ricasso)
	face([end[r][0] for r in range(4)] + [end[r][1] for r in range(3, -1, -1)], METAL)
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	return bm


def build_parts():
	parts = {}

	def part(name, bone="Root"):
		parts[name] = K.Part(name, bone)
		return parts[name]

	# ---------------------------------------------------------------- Blade (+ ricasso and choil)
	bl = part("Blade")
	bl.add(blade_bm(), 0.0015, 1, 40)
	ric = P([(716, 776), (772, 776), (772, 858), (750, 860), (738, 864), (729, 872), (724, 884), (716, 889)])
	bl.add(K.prism(ric, "Y", -T, T, METAL), 0.002, 1)

	# ---------------------------------------------------------------- Hilt: guard, handle, pommel
	hd = part("Hilt")
	gside = K.rect(X(790), X(756), Z(914), Z(732), 0.006)
	gsect = K.chamfer([(-0.064, Z(914)), (0.064, Z(914)), (0.064, Z(732)), (-0.064, Z(732))], 0.026)
	hd.add(B.solid(gside, gsect, METAL), 0.004, 1, 40)

	hside = P([(780, 772), (830, 764), (950, 766), (1100, 762), (1230, 754), (1304, 756),
		(1304, 902), (1266, 910), (1232, 898), (1185, 887), (1135, 906), (1075, 909), (1030, 893),
		(985, 884), (940, 904), (885, 908), (842, 888), (810, 886), (780, 894)])
	hsect = K.section(0.05, Z(914), Z(750), 0.02, 0.022)
	handle = B.solid(hside, hsect, DARK)
	rear = B.both(K.prism(P([(958, 790), (1222, 784), (1248, 812), (1250, 862), (1214, 878), (962, 874), (942, 832)]), "Y", 0.046, 0.2))
	front = B.both(K.prism(P([(808, 794), (920, 790), (930, 830), (916, 868), (816, 874), (800, 832)]), "Y", 0.046, 0.2))
	handle = K.cut(handle, rear, GRIP)
	handle = K.cut(handle, front, GRIP)
	npts = P([(1176, 772), (1226, 770), (1232, 775), (1226, 780), (1176, 782), (1170, 777)])
	handle = K.cut(handle, K.prism(npts, "Y", 0.0455, 0.2), DARK)
	hd.add(handle, 0.0025, 1, 40)

	zc = 0.0
	secs = []
	for x, r in ((X(1296), 0.07), (X(1306), 0.086), (X(1318), 0.098), (X(1368), 0.098), (X(1388), 0.074)):
		secs.append((x, K.circle(0.0, zc, r, 8, math.pi / 8)))
	pommel = K.loft_x(secs, METAL)
	pommel = K.cut(pommel, K.cyl_y(X(1346), zc, 0.019, -0.2, 0.2, 10, DARK, rot=0.0), DARK)
	hd.add(pommel, 0.003, 1, 30)

	# ---------------------------------------------------------------- Neon: one inset near the pommel, gun-left
	ne = part("Neon")
	inner = P([(1180, 773.5), (1222, 772), (1227, 776), (1222, 779), (1180, 780.5), (1175, 777)])
	ne.add(K.prism(inner, "Y", 0.044, 0.0478, NEON), 0)
	return parts


BONES = [("Root", None, (0.0, 0.0, 0.0))]
LOCATORS = [
	("RightGrip", "Root", (0.0, 0.0, 0.0), None),
	("BladeBase", "Root", (0.364, 0.0, -0.0065), None),
	("BladeTip", "Root", (1.2714, 0.0, 0.0156), None),
]

RESULT = B.assemble(GUN, build_parts, BONES, LOCATORS, {"class": "Melee", "tier": "Melee"})
