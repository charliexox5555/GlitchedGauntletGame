# build_marshal_v2.py: RemasterV2 Marshal (light scoped lever-action rifle), fresh rebuild from
# vault/02 Art/References/Gun-Image-Concepts/Scoped lever-action rifle design sheet-11.png. Blender MCP only.
# Contract measured on the original Marshal.blend (REF_Marshal_Original): Muzzle 3.1977, buttplate -1.241, bore z
# 0.2046, tube z 0.1155, scope axis z 0.3333, AimPoint (0.1881, 0, 0.3333) at the eyepiece, ScopeAxis (1.1616, 0,
# 0.3333), LoadPoint gate (0.396, -0.055, 0.0429), LeftGrip (1.386, 0, -0.0132); bones Root/Lever/Bolt/Hammer/
# Trigger/Shell/Flash/Charm (original heads, Charm moved). The game hides the gun past Viewmodel.SCOPE_AT and shows
# the scope overlay, so the optic is a fixed, coherent model (no reticle).
# Changes: thicker satin receiver (0.055 -> 0.066) with a side recess and neon slot, gate on the right; lofted scope
# (objective bell, tube, eyepiece) on two rings with clamp screws and bases on a rail, top + side turrets with
# knurl lines, coated lens part; textured fore-end with the neon diamond; barrel band; tube cap; lever loop with the
# trigger clear of it (original 0.004); stock with a cheek line; hanging charm tab.

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

GUN = "Marshal"
BORE = 0.2046
TUBE = 0.1155
SZ = 0.3333
MUZZLE_X = 3.1977
RW = 0.066
AIM_ROT = Matrix(((0, 0, 1), (0, 1, 0), (-1, 0, 0))).to_4x4()
EJECT_UP = Vector((0, 0, 1)).to_track_quat("Z", "Y").to_matrix().to_4x4()


def ring(x, r, segs=16):
	return (x, K.circle(0.0, SZ, r, segs, rot=0.0))


def build_parts():
	parts = {}

	def part(name, bone="Root"):
		parts[name] = K.Part(name, bone)
		return parts[name]

	both = B.both
	neon = part("Neon")

	# ================================================================ Receiver (satin) + rail
	rec = part("Receiver")
	body = B.solid([(0.888, 0.2145), (0.858, 0.228), (0.264, 0.228), (0.172, 0.2145), (0.099, 0.165), (0.099, -0.039), (0.172, -0.049), (0.858, -0.049), (0.888, -0.026)], K.section(RW, -0.06, 0.228, 0.016, 0.012), PANEL, 0.003)
	body = K.cut(body, K.group(
		both(K.prism(K.chamfer([(0.25, 0.188), (0.81, 0.188), (0.81, 0.0), (0.21, 0.0), (0.155, 0.08)], 0.012), "Y", RW - 0.005, 0.2)),
		both(K.box(0.297, 0.528, RW - 0.007, 0.2, 0.056, 0.089)),  # slot (neon at its rear)
		K.prism(K.chamfer([(0.31, 0.02), (0.46, 0.02), (0.46, 0.068), (0.31, 0.068)], 0.008), "Y", -0.2, -RW + 0.016),  # loading gate (right)
	), DARK)
	for f in body.faces:
		c = f.calc_center_median()
		if abs(abs(c.y) - (RW - 0.005)) < 1e-4 and -0.001 <= c.z <= 0.189:
			f.material_index = BODY
	rec.add(body)
	neon.add(both(K.box(0.30, 0.37, RW - 0.0065, RW - 0.0035, 0.059, 0.086, NEON)))
	rec.add(K.box(0.24, 0.84, -0.026, 0.026, 0.226, 0.25, DARK), 0.003)  # scope rail
	t = K.Part("_t")
	for x in [0.27 + 0.05 * i for i in range(12)]:
		t.add(K.drop(K.box(x, x + 0.022, -0.026, 0.026, 0.249, 0.258, DARK), 2, -1))
	rec.add(t.merged())

	# ================================================================ Barrel, tube, band, front sight
	bar = part("Barrel")
	barrel = K.cyl_x(0.88, MUZZLE_X, 0.044, 0.0, BORE, 14, METAL)
	bar.add(K.cut(barrel, K.cyl_x(MUZZLE_X - 0.06, MUZZLE_X + 0.04, 0.024, 0.0, BORE, 10, DARK), DARK))
	bar.add(K.annulus_x(MUZZLE_X - 0.04, MUZZLE_X - 0.028, 0.0, BORE, 0.048, 0.04, 14, METAL))
	bar.add(K.drop(K.cyl_x(0.88, 3.03, 0.047, 0.0, TUBE, 14, METAL), 0, -1))
	bar.add(K.bevel(K.cyl_x(3.02, 3.06, 0.05, 0.0, TUBE, 14, DARK), 0.006, 1, 25))
	bar.add(B.solid(K.chamfer([(1.904, 0.05), (1.997, 0.05), (1.997, 0.258), (1.904, 0.258)], 0.016), K.section(0.06, 0.05, 0.258, 0.03, 0.03), PANEL, 0.003))  # barrel band
	bar.add(K.prism([(3.003, 0.244), (3.12, 0.244), (3.11, 0.275), (3.08, 0.30), (3.035, 0.30), (3.003, 0.275)], "Y", -0.012, 0.012, DARK), 0.002)
	bar.add(B.solid(K.chamfer([(2.965, 0.062), (3.025, 0.062), (3.025, 0.252), (2.965, 0.252)], 0.012), K.section(0.054, 0.062, 0.252, 0.03, 0.03), PANEL, 0.003))  # v03: front band (barrel + tube)

	# ================================================================ Fore-end
	fe = part("ForeEnd")
	fore = B.solid(K.chamfer([(0.888, -0.013), (1.904, -0.013), (1.904, 0.208), (0.888, 0.208)], [0, 0.03, 0.03, 0]), K.section(0.068, -0.013, 0.208, 0.024, 0.03), DARK, 0.003)
	fore = K.cut(fore, both(K.group(K.prism(K.chamfer([(1.0, 0.02), (1.66, 0.02), (1.66, 0.175), (1.0, 0.175)], 0.016), "Y", 0.064, 0.2), K.prism([(1.70, 0.063), (1.82, 0.063), (1.795, 0.11), (1.675, 0.11)], "Y", 0.064, 0.2))), GRIP)
	fe.add(fore)
	neon.add(both(K.prism([(1.703, 0.066), (1.815, 0.066), (1.792, 0.107), (1.68, 0.107)], "Y", 0.0645, 0.0665, NEON)))

	# ================================================================ Scope (fixed): lofted bell, tube, eyepiece; rings on the rail; turrets
	sc = part("Scope")
	tube = K.loft_x([ring(0.188, 0.06), ring(0.27, 0.062), ring(0.30, 0.05), ring(0.36, 0.046), ring(0.865, 0.046), ring(1.04, 0.075), ring(1.155, 0.077)], DARK)
	sc.add(tube)
	sc.add(K.annulus_x(0.256, 0.266, 0.0, SZ, 0.066, 0.058, 16, METAL))  # eyepiece focus ring
	sc.add(K.annulus_x(1.12, 1.135, 0.0, SZ, 0.081, 0.072, 16, METAL))  # objective ring
	for xr in (0.429, 0.7755):
		sc.add(K.annulus_x(xr - 0.022, xr + 0.022, 0.0, SZ, 0.058, 0.044, 16, METAL))
		sc.add(B.solid(K.chamfer([(xr - 0.03, 0.25), (xr + 0.03, 0.25), (xr + 0.022, 0.29), (xr - 0.022, 0.29)], 0.0), K.section(0.03, 0.25, 0.29, 0.0, 0.006), METAL, 0.002))
		sc.add(both(K.drop(K.cyl_y(xr, SZ - 0.06, 0.008, 0.028, 0.036, 6, METAL, rot=0.0), 1, -1)))  # clamp screws
	sc.add(K.prism(K.circle(0.62, 0.0, 0.034, 12), "Z", SZ + 0.04, 0.44, METAL), 0.004)  # elevation turret
	sc.add(K.prism(K.circle(0.62, 0.0, 0.03, 12), "Z", SZ + 0.03, SZ + 0.045, DARK))
	sc.add(K.cyl_y(0.62, SZ, 0.03, -0.1, -0.04, 12, METAL, rot=0.0), 0.004)  # windage (right)
	sc.add(K.cyl_y(0.62, SZ, 0.024, 0.04, 0.085, 10, DARK, rot=0.0), 0.003)  # parallax (left)
	sc.add(K.prism(K.circle(0.62, 0.0, 0.048, 12), "Z", SZ + 0.02, SZ + 0.05, DARK))  # turret saddle
	lens = part("ScopeLens")
	lens.add(K.cyl_x(1.15, 1.16, 0.068, 0.0, SZ, 16, ACCENT))  # coated objective glass
	lens.add(K.cyl_x(0.184, 0.19, 0.052, 0.0, SZ, 16, ACCENT))  # ocular glass

	# ================================================================ Stock
	st = part("Stock")
	sbody = B.solid(K.chamfer([(0.172, 0.2145), (0.116, 0.2145), (-0.264, 0.066), (-1.188, 0.07), (-1.214, 0.04), (-1.214, -0.27), (-1.188, -0.30), (-0.44, -0.287), (-0.165, -0.132), (-0.066, -0.083), (0.172, -0.049)], [0, 0, 0.03, 0, 0, 0, 0, 0.03, 0.03, 0, 0]), K.section(0.066, -0.31, 0.2145, 0.024, 0.026), DARK)  # bevelled after the cuts below
	# v03: the wrist is slimmer than the butt (concept): taper the width from 0.78 at the wrist to full at the butt.
	for v in sbody.verts:
		t = min(1.0, max(0.0, (-v.co.x - 0.18) / 0.36))
		v.co.y *= 0.78 + 0.22 * (t * t * (3 - 2 * t))
	# Textured wrist panels and a shallow facet along the butt (replaces v01's big light panel).
	sbody = K.cut(sbody, both(K.prism(K.chamfer([(0.06, 0.12), (-0.07, 0.08), (-0.19, -0.02), (-0.09, -0.09), (0.05, -0.02)], 0.012), "Y", 0.046, 0.2)), GRIP)
	sbody = K.cut(sbody, both(K.prism(K.chamfer([(-0.40, 0.035), (-1.12, 0.035), (-1.12, -0.10), (-0.52, -0.10)], [0.02, 0.012, 0.012, 0.02]), "Y", 0.0615, 0.2)), DARK)
	st.add(K.bevel(sbody, 0.004, 1, 50))
	pad = B.solid(K.chamfer([(-1.21, 0.07), (-1.246, 0.07), (-1.246, -0.30), (-1.21, -0.30)], [0, 0.012, 0.012, 0]), K.section(0.07, -0.31, 0.08, 0.016, 0.016), DARK, 0.003)
	st.add(K.cut(pad, K.group(*[K.box(-1.3, -1.24, -0.08, 0.08, z, z + 0.012) for z in (-0.24, -0.18, -0.12, -0.06, 0.0)]), GRIP))  # recoil pad grooves
	st.add(B.solid([(-1.204, 0.07), (-1.214, 0.07), (-1.214, -0.30), (-1.204, -0.30)], K.section(0.068, -0.31, 0.08, 0.016, 0.016), PANEL, 0.0))  # spacer line

	# ================================================================ Fasteners
	pins = part("Pins")
	for s in (1, -1):
		for x, z, w in ((0.495, -0.026, RW), (0.825, 0.165, RW), (1.95, 0.115, 0.06)):
			pins.add(B.head(x, z, w, r=0.011, segs=8, side=s))

	# ================================================================ Charm tab (under the receiver's front, left)
	ch = part("CharmLoop")
	tab = [(0.79, 0.0), (0.85, 0.0)] + [(0.82 + 0.03 * math.cos(-a), -0.06 + 0.03 * math.sin(-a)) for a in [i * math.pi / 6 for i in range(7)]]
	tb = K.bevel(K.prism(tab, "Y", RW - 0.001, RW + 0.012, METAL), 0.003, 1, 50)
	ch.add(K.cut(tb, K.cyl_y(0.82, -0.065, 0.012, 0.0, 0.2, 10, METAL), DARK))
	ch.add(B.head(0.82, -0.018, RW + 0.012, r=0.006, h=0.003))

	# ================================================================ Moving parts
	lv = part("Lever", "Lever")
	front = K.prism(K.chamfer([(0.587, -0.003), (0.204, -0.043), (0.184, -0.155), (0.43, -0.163), (0.565, -0.10)], 0.012), "Y", -0.02, 0.02, METAL)
	lv.add(K.cut(front, K.prism(K.chamfer([(0.51, -0.05), (0.244, -0.07), (0.232, -0.14), (0.44, -0.145), (0.53, -0.105)], 0.012), "Y", -0.06, 0.06), METAL), 0.003)
	loop = K.prism(K.chamfer([(0.231, -0.043), (0.066, -0.05), (-0.066, -0.109), (-0.132, -0.254), (-0.106, -0.327), (0.033, -0.333), (0.139, -0.231), (0.224, -0.155)], [0.012, 0.03, 0.04, 0.05, 0.05, 0.04, 0.03, 0.012]), "Y", -0.02, 0.02, METAL)
	lv.add(K.cut(loop, K.prism(K.chamfer([(0.20, -0.09), (0.07, -0.093), (-0.03, -0.142), (-0.08, -0.248), (-0.06, -0.29), (0.02, -0.29), (0.12, -0.21), (0.19, -0.16)], [0.012, 0.025, 0.035, 0.03, 0.03, 0.035, 0.025, 0.012]), "Y", -0.06, 0.06), METAL), 0.003)

	bolt = part("Bolt", "Bolt")
	bolt.add(K.box(0.172, 0.462, -0.04, 0.04, 0.2, 0.236, METAL), 0.003)
	ham = part("Hammer", "Hammer")
	hm = K.prism([(0.174, 0.125), (0.149, 0.188), (0.116, 0.228), (0.04, 0.228), (0.056, 0.201), (0.106, 0.178), (0.13, 0.125)], "Y", -0.014, 0.014, METAL)
	ham.add(K.cut(hm, K.group(*[K.box(x, x + 0.007, -0.05, 0.05, 0.22, 0.24) for x in (0.05, 0.066, 0.082)]), METAL), 0.002)
	tg = part("Trigger", "Trigger")
	tp = [(0.318, -0.02), (0.352, -0.02), (0.355, -0.045), (0.35, -0.065), (0.338, -0.083), (0.322, -0.096), (0.315, -0.09), (0.327, -0.074), (0.333, -0.058), (0.331, -0.038), (0.32, -0.03)]
	tg.add(K.prism(tp, "Y", -0.011, 0.011, METAL), 0.002)
	sh = part("Shell", "Shell")
	sh.add(AM.sniper_round(0.29, 0.0, 0.0429, scale=0.56))  # v02: rifle-calibre sniper round (brass case, steel ogive)
	return parts


CHARM = (0.82, RW + 0.005, -0.065)
BONES = [
	("Root", None, (0.0, 0.0, 0.1)),
	("Lever", "Root", (0.5643, 0.0, -0.0264)),
	("Bolt", "Root", (0.3135, 0.0, 0.2013)),
	("Hammer", "Root", (0.1914, 0.0, 0.1221)),
	("Trigger", "Root", (0.3366, 0.0, -0.0231)),
	("Shell", "Root", (0.396, 0.0, 0.0429)),
	("Flash", "Root", (MUZZLE_X + 0.01, 0.0, BORE)),
	("Charm", "Root", CHARM),
]
LOCATORS = [
	("Muzzle", "Root", (MUZZLE_X, 0.0, BORE), None),
	("RightGrip", "Root", (0.0, 0.0, 0.0), None),
	("LeftGrip", "Root", (1.386, 0.0, -0.0132), None),
	("AimPoint", "Root", (0.1881, 0.0, SZ), AIM_ROT),
	("ScopeAxis", "Root", (1.1616, 0.0, SZ), None),
	("Eject", "Root", (0.3135, 0.0, 0.2145), EJECT_UP),
	("LoadPoint", "Root", (0.396, -0.055, 0.0429), None),
	("CharmPoint", "Charm", CHARM, None),
	("Socket_Muzzle", "Root", (MUZZLE_X, 0.0, BORE), None),
	("Socket_Optic", "Root", (0.55, 0.0, 0.258), None),
	("Socket_Under", "Root", (1.39, 0.0, -0.013), None),
]

RESULT = B.assemble(GUN, build_parts, BONES, LOCATORS, {"class": "Sniper", "tier": "T3"})
