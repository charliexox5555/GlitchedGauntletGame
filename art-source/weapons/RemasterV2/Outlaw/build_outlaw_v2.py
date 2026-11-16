# build_outlaw_v2.py: RemasterV2 Outlaw (twin-barrel over-under break-action scoped rifle), fresh rebuild from
# vault/02 Art/References/Gun-Image-Concepts/Stacked-barrel scoped rifle concept sheet-12.png. Blender MCP only.
# Contract measured on the original Outlaw.blend (REF_Outlaw_Original): Muzzle 3.4476 (upper, z 0.4624) and
# MuzzleLower (z 0.34) on Barrels, hinge (0.935, 0, 0.2346), breech x 1.0302, scope axis z 0.6256, AimPoint
# (-0.0646, 0, 0.6256), ScopeAxis (1.1934, 0, 0.6256), LeftGrip (1.819, 0, 0.1156) on Barrels, buttpad -1.132; bones
# Root/Barrels/RoundUpper/RoundLower/BreechLatch/Trigger/Flash/Charm (original heads, Charm moved). The scope stays on
# the receiver; the game shows its overlay past SCOPE_AT.
# Changes: sectioned receiver (already 0.106 wide) with the concept's knuckle caps, side panel and neon parallelogram;
# breech block with two chambers; barrels in an octagonal front clamp with a vent rib and web; textured fore-end;
# lofted scope on rings/bases over a rail with three turrets and coated glass; stock with a textured wrist and
# cheek line; trigger clearance (the original tip went below the guard opening); hanging charm tab.

import bpy, math, sys, importlib
from mathutils import Matrix, Vector

ROOT = r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/art-source/weapons/RemasterV2"
sys.path.insert(0, ROOT + "/_Library")
import v2kit as K  # noqa: E402
import v2build as B  # noqa: E402
import ammo as AM  # noqa: E402

importlib.reload(K)
importlib.reload(B)
importlib.reload(AM)
from v2kit import BODY, PANEL, DARK, METAL, GRIP, ACCENT, NEON  # noqa: E402

GUN = "Outlaw"
UZ, LZ, SZ = 0.4624, 0.34, 0.6256
HINGE = (1.045, 0.0, 0.152)
LUG_R, LUG_W = 0.036, 0.07  # v02 barrel hinge lug (disc around the pin) and its half width
BX = 1.0302
MUZZLE_X = 3.4476
RW = 0.106
# v02 hinge: the original pivot (0.935, 0.2346) sat inside the receiver, so the barrels could not open past ~45 deg
# without sweeping through it. A break action pivots at the bottom-front corner of the action: every barrel part is
# then ahead of and above the pin and swings forward-down, clear of the receiver at any angle. The decorative knuckle
# caps stay where the concept has them (OLD_KNUCKLE).
OLD_KNUCKLE = (0.935, 0.0, 0.2346)
AIM_ROT = Matrix(((0, 0, 1), (0, 1, 0), (-1, 0, 0))).to_4x4()
EJECT_BACK = Vector((-0.86, 0, 0.51)).to_track_quat("Z", "Y").to_matrix().to_4x4()


def ring(x, r, segs=14):
	return (x, K.circle(0.0, SZ, r, segs, rot=0.0))


def build_parts():
	parts = {}

	def part(name, bone="Root"):
		parts[name] = K.Part(name, bone)
		return parts[name]

	both = B.both
	neon = part("Neon")

	# ================================================================ Receiver + guard + rail
	rec = part("Receiver")
	body = B.solid([(1.037, 0.1156), (1.037, 0.469), (1.003, 0.4964), (0.255, 0.4964), (0.187, 0.4624), (0.139, 0.408), (0.139, 0.1156)], K.section(RW, 0.1, 0.4964, 0.026, 0.02), BODY, 0.003)
	body = K.cut(body, K.group(
		both(K.prism(K.chamfer([(0.80, 0.442), (0.357, 0.442), (0.255, 0.367), (0.255, 0.204), (0.629, 0.17), (0.80, 0.204)], 0.014), "Y", RW - 0.005, 0.2)),
		both(K.prism([(0.609, 0.255), (0.541, 0.255), (0.561, 0.201), (0.629, 0.201)], "Y", RW - 0.005, 0.2)),
	), DARK)
	for f in body.faces:
		c = f.calc_center_median()
		if abs(abs(c.y) - (RW - 0.005)) < 1e-4 and 0.17 <= c.z <= 0.442 and not (0.54 < c.x < 0.63 and c.z < 0.26):
			f.material_index = PANEL
	# Hinge: a pocket in the receiver's bottom-front corner for the barrels' lug (cheeks either side).
	body = K.cut(body, K.cyl_y(HINGE[0], HINGE[2], LUG_R + 0.01, -LUG_W - 0.004, LUG_W + 0.004, 12, DARK, rot=0.0), DARK)
	rec.add(body)
	neon.add(both(K.prism([(0.606, 0.252), (0.544, 0.252), (0.563, 0.204), (0.626, 0.204)], "Y", RW - 0.0045, RW - 0.0015, NEON)))
	rec.add(both(K.drop(K.cyl_y(HINGE[0], HINGE[2], 0.02, RW - 0.004, RW + 0.006, 8, METAL), 1, -1)), 0.002)
	for cx, cz in ((0.955, 0.3876), (OLD_KNUCKLE[0], OLD_KNUCKLE[2])):
		rec.add(both(K.drop(K.cyl_y(cx, cz, 0.078, RW - 0.002, RW + 0.01, 18, PANEL), 1, -1)), 0.004)  # knuckle caps
		rec.add(both(K.drop(K.cyl_y(cx, cz, 0.016, RW + 0.008, RW + 0.016, 8, METAL), 1, -1)))
	guard = K.bevel(K.prism([(0.258, 0.122), (0.568, 0.122), (0.568, 0.048), (0.52, -0.003), (0.29, -0.003), (0.258, 0.03)], "Y", -0.034, 0.034, DARK), 0.006, 1, 30)
	rec.add(K.cut(guard, K.prism(K.chamfer([(0.282, 0.2), (0.52, 0.2), (0.52, 0.06), (0.49, 0.03), (0.282, 0.03)], [0, 0, 0.01, 0.0, 0.0]), "Y", -0.1, 0.1), DARK))
	rec.add(K.box(0.30, 1.02, -0.032, 0.032, 0.492, 0.516, DARK), 0.003)
	t = K.Part("_t")
	for x in [0.33 + 0.055 * i for i in range(12)]:
		t.add(K.drop(K.box(x, x + 0.024, -0.032, 0.032, 0.515, 0.525, DARK), 2, -1))
	rec.add(t.merged())

	# ================================================================ Scope
	sc = part("Scope")
	sc.add(K.loft_x([ring(-0.058, 0.09), ring(0.034, 0.092), ring(0.06, 0.07), ring(0.187, 0.052), ring(0.901, 0.052), ring(1.044, 0.102), ring(1.187, 0.104)], DARK))
	sc.add(K.annulus_x(0.0, 0.016, 0.0, SZ, 0.096, 0.086, 14, METAL))
	sc.add(K.annulus_x(1.15, 1.165, 0.0, SZ, 0.106, 0.098, 14, METAL))
	for xr in (0.323, 0.687):
		sc.add(K.annulus_x(xr - 0.024, xr + 0.024, 0.0, SZ, 0.066, 0.05, 12, METAL))
		sc.add(B.solid([(xr - 0.032, 0.52), (xr + 0.032, 0.52), (xr + 0.024, 0.566), (xr - 0.024, 0.566)], K.section(0.034, 0.52, 0.566, 0.0, 0.006), METAL, 0.002))
		sc.add(both(K.drop(K.cyl_y(xr, SZ - 0.066, 0.009, 0.032, 0.04, 6, METAL, rot=0.0), 1, -1)))
	sc.add(K.prism(K.circle(0.507, 0.0, 0.044, 12), "Z", SZ + 0.045, 0.762, METAL), 0.004)
	sc.add(K.prism(K.circle(0.507, 0.0, 0.05, 12), "Z", 0.735, 0.745, DARK))
	sc.add(K.prism(K.circle(0.507, 0.0, 0.058, 12), "Z", SZ + 0.025, SZ + 0.055, DARK))
	sc.add(K.cyl_y(0.507, SZ, 0.04, -0.13, -0.05, 12, METAL, rot=0.0), 0.004)
	sc.add(K.cyl_y(0.507, SZ, 0.034, 0.05, 0.11, 10, DARK, rot=0.0), 0.003)
	lens = part("ScopeLens")
	lens.add(K.cyl_x(1.182, 1.192, 0.094, 0.0, SZ, 14, ACCENT))
	lens.add(K.cyl_x(-0.064, -0.056, 0.08, 0.0, SZ, 14, ACCENT))

	# ================================================================ Stock
	st = part("Stock")
	sbody = B.solid(K.chamfer([(0.139, 0.442), (0.085, 0.425), (-0.187, 0.272), (-0.238, 0.357), (-0.323, 0.381), (-0.98, 0.381), (-0.98, -0.272), (-0.119, -0.272), (-0.051, -0.221), (0.017, -0.136), (0.085, -0.017), (0.221, 0.051), (0.248, 0.1156), (0.139, 0.1156)], [0, 0, 0.02, 0.02, 0, 0, 0, 0.02, 0.02, 0, 0, 0, 0, 0]), K.section(0.084, -0.28, 0.442, 0.024, 0.02), DARK, 0.004)
	sbody = K.cut(sbody, both(K.group(K.prism(K.chamfer([(0.085, 0.204), (-0.119, 0.163), (-0.194, -0.068), (-0.017, -0.085)], 0.02), "Y", 0.08, 0.2), K.prism(K.chamfer([(-0.40, 0.17), (-0.92, 0.17), (-0.92, -0.18), (-0.70, -0.18)], 0.02), "Y", 0.08, 0.2))), GRIP)
	st.add(sbody)
	pad = B.solid(K.chamfer([(-0.975, 0.388), (-1.132, 0.388), (-1.132, -0.275), (-0.975, -0.275)], [0, 0.02, 0.02, 0]), K.section(0.09, -0.275, 0.388, 0.018, 0.018), PANEL, 0.004)
	st.add(K.cut(pad, K.group(*[K.box(-1.17, -1.12, -0.08, 0.08, z, z + 0.012) for z in (-0.22, -0.15, -0.08, -0.01, 0.06, 0.13, 0.20, 0.27, 0.34)]), GRIP))

	# ================================================================ Charm tab (under the receiver behind the hinge, left)
	ch = part("CharmLoop")
	tab = [(0.70, 0.16), (0.762, 0.16)] + [(0.731 + 0.031 * math.cos(-a), 0.09 + 0.031 * math.sin(-a)) for a in [i * math.pi / 6 for i in range(7)]]
	tb = K.bevel(K.prism(tab, "Y", RW - 0.001, RW + 0.013, METAL), 0.003, 1, 50)
	ch.add(K.cut(tb, K.cyl_y(0.731, 0.085, 0.012, 0.0, 0.3, 10, METAL), DARK))
	ch.add(B.head(0.717, 0.14, RW + 0.013, r=0.006, h=0.003))
	ch.add(B.head(0.745, 0.14, RW + 0.013, r=0.006, h=0.003))

	# ================================================================ Barrels (break-action group)
	bar = part("Barrels", "Barrels")
	for zc, r in ((UZ, 0.056), (LZ, 0.06)):
		bar.add(K.drop(K.cyl_x(1.10, 3.38, r, 0.0, zc, 14, METAL), 0, 1))
		mz = K.bevel(K.cyl_x(3.37, MUZZLE_X, r + 0.008, 0.0, zc, 14, METAL), 0.006, 1, 25)
		bar.add(K.cut(mz, K.cyl_x(MUZZLE_X - 0.06, MUZZLE_X + 0.04, r * 0.62, 0.0, zc, 10, DARK), DARK))
	rib = K.box(1.22, 3.36, -0.024, 0.024, UZ + 0.048, UZ + 0.072, DARK)  # v02: starts past the scope bell
	bar.add(K.cut(rib, K.group(*[K.box(1.3 + 0.22 * i, 1.36 + 0.22 * i, -0.06, 0.06, UZ + 0.045, UZ + 0.064) for i in range(9)]), METAL), 0.002)
	bar.add(K.drop(K.drop(K.box(1.14, 3.17, -0.046, 0.046, LZ + 0.025, UZ - 0.025, DARK), 1, 1), 1, -1))
	bar.add(K.prism([(-0.08, 0.278), (0.08, 0.278), (0.104, 0.30), (0.104, 0.51), (0.08, 0.535), (-0.08, 0.535), (-0.104, 0.51), (-0.104, 0.30)], "X", 3.17, 3.30, DARK), 0.006)  # front clamp
	block = B.solid(K.chamfer([(1.039, 0.156), (1.139, 0.156), (1.139, 0.512), (1.039, 0.512)], 0.016), K.section(0.098, 0.156, 0.512, 0.024, 0.02), BODY, 0.003)
	# Hinge lug: a disc around the pin joined to the block and fore-end; it turns inside the receiver's pocket.
	lug = [(HINGE[0] + LUG_R * math.cos(a), HINGE[2] + LUG_R * math.sin(a)) for a in [math.pi / 2 + i * math.pi / 8 for i in range(9)]]
	lug += [(1.125, HINGE[2] - LUG_R), (1.125, 0.19), (HINGE[0], 0.19)]
	bar.add(K.prism(lug, "Y", -LUG_W, LUG_W, BODY), 0.003, 1, 40)
	bar.add(K.cyl_y(HINGE[0], HINGE[2], 0.013, -LUG_W - 0.003, LUG_W + 0.003, 8, METAL))  # pin (ends shown by the receiver caps)
	bar.add(K.cut(block, K.group(K.cyl_x(BX - 0.05, BX + 0.12, 0.04, 0.0, UZ, 12, DARK), K.cyl_x(BX - 0.05, BX + 0.12, 0.043, 0.0, LZ, 12, DARK)), METAL))
	fore = B.solid(K.chamfer([(1.115, 0.1156), (2.496, 0.1156), (2.496, 0.333), (1.115, 0.333)], [0, 0.04, 0.04, 0]), K.section(0.098, 0.11, 0.333, 0.02, 0.03), BODY, 0.003)
	bar.add(K.cut(fore, both(K.prism(K.chamfer([(1.30, 0.15), (2.10, 0.15), (2.10, 0.30), (1.36, 0.30)], 0.02), "Y", 0.093, 0.2)), GRIP))

	# ================================================================ Other moving parts
	lt = part("BreechLatch", "BreechLatch")
	lt.add(K.prism(K.chamfer([(0.194, 0.469), (0.126, 0.496), (0.105, 0.475), (0.16, 0.42), (0.187, 0.42)], 0.006), "Y", -0.02, 0.02, ACCENT), 0.003)
	tg = part("Trigger", "Trigger")
	tp = [(0.315, 0.13), (0.35, 0.13), (0.353, 0.105), (0.348, 0.088), (0.336, 0.073), (0.32, 0.063), (0.313, 0.069), (0.325, 0.083), (0.331, 0.097), (0.329, 0.113), (0.317, 0.12)]
	tg.add(K.prism(tp, "Y", -0.011, 0.011, METAL), 0.002)
	for name, zc in (("RoundUpper", UZ), ("RoundLower", LZ)):
		rd = part(name, name)
		rd.add(AM.sniper_round(BX + 0.009, 0.0, zc))  # v02: full-size bottleneck sniper round (brass case, steel ogive)
	return parts


CHARM = (0.731, RW + 0.006, 0.085)
BONES = [
	("Root", None, (0.0, 0.0, 0.1)),
	("Barrels", "Root", HINGE),
	("RoundUpper", "Barrels", (BX, 0.0, UZ)),
	("RoundLower", "Barrels", (BX, 0.0, LZ)),
	("BreechLatch", "Root", (0.1598, 0.0, 0.408)),
	("Trigger", "Root", (0.3366, 0.0, 0.1156)),
	("Flash", "Root", (MUZZLE_X + 0.01, 0.0, UZ)),
	("Charm", "Root", CHARM),
]
LOCATORS = [
	("Muzzle", "Barrels", (MUZZLE_X, 0.0, UZ), None),
	("MuzzleLower", "Barrels", (MUZZLE_X, 0.0, LZ), None),
	("RightGrip", "Root", (0.0, 0.0, 0.0), None),
	("LeftGrip", "Barrels", (1.819, 0.0, 0.1156), None),
	("AimPoint", "Root", (-0.0646, 0.0, SZ), AIM_ROT),
	("ScopeAxis", "Root", (1.1934, 0.0, SZ), None),
	("Eject", "Barrels", (BX, 0.0, UZ), EJECT_BACK),
	("EjectLower", "Barrels", (BX, 0.0, LZ), EJECT_BACK),
	("ChamberUpper", "Barrels", (BX + 0.1, 0.0, UZ), None),
	("ChamberLower", "Barrels", (BX + 0.1, 0.0, LZ), None),
	("CharmPoint", "Charm", CHARM, None),
	("Socket_Muzzle", "Barrels", (MUZZLE_X, 0.0, UZ), None),
	("Socket_Optic", "Root", (0.66, 0.0, 0.525), None),
	("Socket_Under", "Barrels", (1.82, 0.0, 0.1156), None),
]

RESULT = B.assemble(GUN, build_parts, BONES, LOCATORS, {"class": "Sniper", "tier": "T3"})
