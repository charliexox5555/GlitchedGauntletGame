# build_phantom_v2.py: RemasterV2 Phantom (suppressed AR-pattern rifle), fresh rebuild from
# vault/02 Art/References/phantom-concept.webp. Blender MCP only.
# Contract measured on the original Phantom.blend (REF_Phantom_Original): suppressor front / Muzzle 2.5024, buttpad
# -1.098, bore z 0.352, AimPoint (0.1536, 0, 0.5784) (rear ring centre = front post tip), LeftGrip (1.2864, 0,
# 0.1984); bones Root/Mag/ChargingHandle/Bolt/Trigger/FireSelector/Flash/Charm (original heads, Charm moved).
# Changes: thicker (upper 0.068 -> 0.084, lower 0.064 -> 0.08, handguard 0.072 -> 0.088, grip 0.05 -> 0.062, mag
# 0.042 -> 0.054, stock 0.055 -> 0.066); flared magwell with cavity and catch; charging channel; port + bolt; side
# recesses; open ring + post-in-hood irons; hanging charm tab; suppressor with stepped sections and a closed cap;
# trigger clearance (the original tip went 0.016 below the guard bar's top).

import bpy, math, sys, importlib
from mathutils import Matrix, Vector

ROOT = r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/art-source/weapons/RemasterV2"
sys.path.insert(0, ROOT + "/_Library")
import v2kit as K  # noqa: E402
import ammo as AM  # noqa: E402
import v2build as B  # noqa: E402
import sights as SI  # noqa: E402

importlib.reload(K)
importlib.reload(AM)
importlib.reload(B)
importlib.reload(SI)
from v2kit import BODY, PANEL, DARK, METAL, GRIP, ACCENT, NEON  # noqa: E402

GUN = "Phantom"
BORE = 0.352
SIGHT_Z = 0.5784
AIM_X = 0.1536
MUZZLE_X = 2.5024
UW, LW = 0.084, 0.08
AIM_ROT = Matrix(((0, 0, 1), (0, 1, 0), (-1, 0, 0))).to_4x4()
EJECT_ROT = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0))).to_4x4()


def build_parts():
	parts = {}

	def part(name, bone="Root"):
		parts[name] = K.Part(name, bone)
		return parts[name]

	both = B.both
	neon = part("Neon")

	# ================================================================ Receiver
	rec = part("Receiver")
	upper = B.solid(K.chamfer([(-0.154, 0.318), (0.934, 0.318), (0.934, 0.40), (0.905, 0.43), (-0.154, 0.43)], [0, 0, 0, 0, 0.0]), K.section(UW, 0.318, 0.43, 0.022, 0.0), BODY, 0.003)
	upper = K.cut(upper, K.group(
		K.prism(K.chamfer([(0.52, 0.355), (0.945, 0.355), (0.945, 0.402), (0.52, 0.402)], 0.006), "Y", 0.066, 0.2),  # charging channel (left)
		K.prism(K.chamfer([(0.29, 0.335), (0.575, 0.335), (0.575, 0.41), (0.29, 0.41)], 0.012), "Y", -0.2, -0.062),  # ejection port (right)
		both(K.box(0.276, 0.415, UW - 0.006, 0.2, 0.322, 0.338)),  # neon pocket
	), DARK)
	rec.add(upper)
	neon.add(both(K.box(0.279, 0.412, UW - 0.0055, UW - 0.0025, 0.3235, 0.3365, NEON)))
	lower = B.solid(K.chamfer([(-0.154, 0.16), (0.89, 0.16), (0.915, 0.20), (0.915, 0.32), (-0.154, 0.32)], [0, 0, 0.0, 0, 0]), K.section(LW, 0.16, 0.32, 0.006, 0.016), BODY, 0.003)
	lower = K.cut(lower, K.group(both(K.prism(K.chamfer([(0.02, 0.19), (0.43, 0.19), (0.43, 0.29), (0.06, 0.29)], 0.012), "Y", LW - 0.005, 0.2))), DARK)
	for f in lower.faces:
		c = f.calc_center_median()
		if abs(abs(c.y) - (LW - 0.005)) < 1e-4 and 0.19 <= c.z <= 0.29:
			f.material_index = PANEL
	rec.add(lower)
	# Flared magwell with the cavity sized to the magazine (0.004 gap), front grip ridges.
	well_sect = [(-0.068, 0.17), (-0.068, 0.052), (-0.073, 0.046), (-0.073, 0.036), (-0.068, 0.03), (0.068, 0.03), (0.073, 0.036), (0.073, 0.046), (0.068, 0.052), (0.068, 0.17)]
	well = B.solid(K.chamfer([(0.464, 0.165), (0.858, 0.165), (0.866, 0.03), (0.47, 0.03)], [0, 0, 0.008, 0.008]), well_sect, BODY, 0.003)
	well = K.cut(well, K.group(K.prism([(0.552, 0.2), (0.82, 0.2), (0.825, 0.0), (0.548, 0.0)], "Y", -0.058, 0.058), *[K.box(0.855, 0.9, -0.08, 0.08, z, z + 0.008) for z in (0.06, 0.08, 0.10, 0.12)]), DARK)
	rec.add(well)
	neon.add(K.box(0.512, 0.541, 0.0725, 0.075, 0.042, 0.064, NEON))
	rec.add(K.prism(K.chamfer([(0.47, 0.105), (0.51, 0.105), (0.51, 0.14), (0.47, 0.14)], 0.004), "Y", -0.08, -0.068, ACCENT), 0.002)  # mag release (right)
	rec.add(K.prism(K.chamfer([(0.43, 0.20), (0.52, 0.20), (0.52, 0.235), (0.44, 0.235)], 0.005), "Y", LW - 0.002, LW + 0.009, METAL), 0.002)  # bolt catch (left)
	rec.add(B.solid(K.chamfer([(-0.178, 0.16), (-0.134, 0.16), (-0.134, 0.4224), (-0.178, 0.4224)], 0.012), K.section(0.086, 0.16, 0.4224, 0.014, 0.014), PANEL, 0.003))  # end plate
	rec.add(K.prism(K.chamfer([(0.295, 0.338), (0.335, 0.338), (0.335, 0.408), (0.295, 0.408)], [0.008, 0, 0, 0.008]), "Y", -UW - 0.012, -UW + 0.004, BODY), 0.003)  # deflector

	# ================================================================ Handguard
	hg = part("Handguard")
	body = B.solid(K.chamfer([(0.928, 0.198), (1.60, 0.198), (1.60, 0.429), (0.928, 0.429)], [0, 0.03, 0.012, 0]), K.section(0.088, 0.198, 0.429, 0.024, 0.04), BODY, 0.003)
	slots = K.group(*[K.prism(K.stadium(x0, x1, zc, 0.03, 2), "Y", 0.066, 0.2) for x0, x1 in ((1.02, 1.18), (1.24, 1.42)) for zc in (0.37, 0.27)])
	hg.add(K.cut(body, both(slots), DARK))
	hg.add(B.solid([(1.598, 0.215), (1.645, 0.215), (1.645, 0.415), (1.598, 0.415)], K.section(0.08, 0.215, 0.415, 0.022, 0.03), PANEL, 0.003))

	# ================================================================ Rail
	rail = part("Rail")
	rail.add(K.box(0.038, 1.619, -0.046, 0.046, 0.428, 0.474, DARK), 0.004)
	t = K.Part("_t")
	x = 0.06
	while x + 0.03 < 1.46:
		t.add(K.drop(K.box(x, x + 0.03, -0.046, 0.046, 0.473, 0.488, DARK), 2, -1))
		x += 0.07
	rail.add(t.merged())

	# ================================================================ Sights: rear ring, front post in a hood (both on the rail)
	si = part("Sights")
	si.add(B.solid(K.chamfer([(0.095, 0.486), (0.225, 0.486), (0.225, 0.515), (0.095, 0.515)], [0, 0, 0.012, 0.012]), K.section(0.044, 0.486, 0.515, 0.01, 0.0), DARK, 0.003))
	# v02 sight picture (Phantom's own): square-notch rear blade; front post with a neon dot in a square box hood.
	si.add(SI.notch_blade(AIM_X, SIGHT_Z, 0.513, hw=0.05, notch="square", nw=0.016, nd=0.028))
	si.add(SI.box_hood(1.539, SIGHT_Z, 0.528, hw=0.036, depth=0.05))
	si.add(SI.post(1.539, SIGHT_Z, 0.525))
	neon.add(SI.post_dot(1.539, SIGHT_Z))
	si.add(B.solid(K.chamfer([(1.49, 0.486), (1.59, 0.486), (1.565, 0.53), (1.515, 0.53)], 0.0), [(-0.038, 0.486), (0.038, 0.486), (0.034, 0.53), (-0.034, 0.53)], DARK, 0.003))  # v03: top wide enough for the box hood walls

	# ================================================================ Suppressor
	sp = part("Suppressor")
	can = K.bevel(K.cyl_x(1.955, MUZZLE_X, 0.082, 0.0, BORE, 20, DARK), 0.014, 1, 25)
	sp.add(K.cut(can, K.cyl_x(MUZZLE_X - 0.08, MUZZLE_X + 0.05, 0.026, 0.0, BORE, 10, DARK), DARK))
	sp.add(K.drop(K.annulus_x(MUZZLE_X - 0.002, MUZZLE_X + 0.003, 0.0, BORE, 0.05, 0.026, 14, PANEL), 0, -1))
	sp.add(K.drop(K.drop(K.cyl_x(1.741, 1.96, 0.078, 0.0, BORE, 20, DARK), 0, 1), 0, -1), 0.0)
	sp.add(K.annulus_x(1.945, 1.962, 0.0, BORE, 0.085, 0.074, 20, METAL))  # seam band
	sp.add(K.cyl_x(1.638, 1.745, 0.058, 0.0, BORE, 14, METAL), 0.005)  # mount collar
	sp.add(K.drop(K.cyl_x(1.60, 1.645, 0.03, 0.0, BORE, 10, METAL), 0, 1))

	# ================================================================ Grip + guard
	gr = part("Grip")
	gp = [(0.192, 0.16), (-0.083, 0.16), (-0.122, 0.122), (-0.109, 0.083), (-0.192, -0.269), (-0.195, -0.307), (0.026, -0.314), (0.038, -0.285), (0.013, -0.259), (0.096, -0.019), (0.122, 0.022), (0.141, 0.061), (0.176, 0.090)]
	grip = K.bevel(K.prism(gp, "Y", -0.062, 0.062, DARK), 0.014, 1)
	gr.add(K.cut(grip, both(K.prism(K.chamfer([(0.07, 0.02), (-0.08, 0.06), (-0.16, -0.24), (0.0, -0.25)], 0.02), "Y", 0.058, 0.2)), GRIP))
	guard = [(0.448, 0.162), (0.486, 0.162), (0.486, 0.075), (0.468, 0.05), (0.18, 0.05), (0.18, 0.082), (0.448, 0.082)]
	gr.add(K.prism(guard, "Y", -0.03, 0.03, DARK), 0.006)

	# ================================================================ Stock
	st = part("Stock")
	st.add(K.drop(K.cyl_x(-0.39, -0.17, 0.064, 0.0, 0.336, 12, DARK), 0, 1), 0.004)
	st.add(K.cyl_x(-0.19, -0.16, 0.074, 0.0, 0.336, 8, METAL, rot=math.pi / 8), 0.004)  # castle nut
	sbody = B.solid(K.chamfer([(-0.352, 0.378), (-0.39, 0.4096), (-0.972, 0.4096), (-0.99, 0.39), (-0.99, -0.048), (-0.946, -0.058), (-0.506, 0.134), (-0.461, 0.173), (-0.365, 0.301)], [0, 0.012, 0.012, 0, 0.01, 0, 0, 0, 0]), K.section(0.066, -0.07, 0.4096, 0.02, 0.016), BODY)  # bevelled after the window cut (the cut failed on the bevelled body)
	# v03: open skeleton stock (concept): a through window leaves a top bar, a rear upright and the lower brace.
	sbody = K.cut(sbody, K.prism(K.chamfer([(-0.565, 0.34), (-0.915, 0.34), (-0.915, 0.085), (-0.85, 0.085), (-0.565, 0.215)], 0.022), "Y", -0.2, 0.2), DARK)
	st.add(K.bevel(sbody, 0.004, 1, 50))
	pad = B.solid(K.chamfer([(-0.98, 0.41), (-1.098, 0.41), (-1.098, -0.064), (-0.98, -0.064)], [0, 0.024, 0.024, 0]), K.section(0.076, -0.064, 0.41, 0.018, 0.018), DARK, 0.004)
	st.add(K.cut(pad, K.group(*[K.box(-1.14, -1.09, -0.06, 0.06, z, z + 0.012) for z in (-0.02, 0.05, 0.12, 0.19, 0.26, 0.33)]), GRIP))
	st.add(both(K.box(-0.80, -0.756, 0.061, 0.07, 0.352, 0.392, METAL)), 0.002)  # QD sockets (v03: on the top bar, clear of the window)
	st.add(both(K.drop(K.cyl_y(-0.886, -0.022, 0.018, 0.064, 0.074, 8, METAL), 1, -1)), 0.002)  # sling knobs

	# ================================================================ Fasteners
	pins = part("Pins")
	for s in (1, -1):
		for x, z in ((0.77, 0.282), (-0.064, 0.278), (0.236, 0.245), (0.30, 0.245)):
			pins.add(B.head(x, z, LW - (0.005 if 0.02 < x < 0.43 else 0.0), r=0.009, side=s))

	# ================================================================ Charm tab (hangs under the lower's front, left)
	ch = part("CharmLoop")
	tab = [(0.876, 0.205), (0.944, 0.205)] + [(0.91 + 0.034 * math.cos(-a), 0.14 + 0.034 * math.sin(-a)) for a in [i * math.pi / 6 for i in range(7)]]
	tb = K.bevel(K.prism(tab, "Y", LW - 0.001, LW + 0.013, METAL), 0.003, 1, 50)
	ch.add(K.cut(tb, K.cyl_y(0.91, 0.135, 0.0135, 0.0, 0.2, 10, METAL), DARK))
	ch.add(B.head(0.893, 0.188, LW + 0.013, r=0.007, h=0.004))
	ch.add(B.head(0.927, 0.188, LW + 0.013, r=0.007, h=0.004))

	# ================================================================ Moving parts
	mg = part("Mag", "Mag")
	mb = K.bevel(K.prism([(0.5632, 0.20), (0.8128, 0.20), (0.807, -0.23), (0.555, -0.23)], "Y", -0.054, 0.054, DARK), 0.01)
	mb = K.cut(mb, both(K.group(K.box(0.53, 0.84, 0.05, 0.2, -0.105, -0.095), K.box(0.765, 0.79, 0.05, 0.2, -0.22, 0.02))), DARK)
	mg.add(mb)
	mg.add(AM.rifle_round(0.575, 0.008, 0.214, scale=0.85))  # v02: top round (seen with the mag out)
	mg.add(B.solid(K.chamfer([(0.548, -0.228), (0.818, -0.228), (0.826, -0.268), (0.81, -0.30), (0.548, -0.30)], [0, 0, 0.006, 0.01, 0.01]), K.section(0.06, -0.31, -0.228, 0.006, 0.012), PANEL, 0.003))
	mg.add(K.loft_x([(0.59, K.circle(0, 0.212, 0.013, 8)), (0.73, K.circle(0, 0.212, 0.013, 8)), (0.742, K.circle(0, 0.212, 0.011, 8)), (0.78, K.circle(0, 0.212, 0.004, 8))], METAL))

	chh = part("ChargingHandle", "ChargingHandle")
	chh.add(K.box(0.77, 0.935, 0.068, 0.083, 0.36, 0.397, METAL))
	chh.add(K.box(0.79, 0.83, 0.082, 0.104, 0.365, 0.392, METAL), 0.003)
	chh.add(K.prism(K.chamfer([(0.775, 0.352), (0.84, 0.352), (0.845, 0.375), (0.84, 0.405), (0.785, 0.405), (0.775, 0.39)], 0.006), "Y", 0.10, 0.122, ACCENT), 0.003)

	bolt = part("Bolt", "Bolt")
	bolt.add(K.box(0.301, 0.56, -0.066, -0.046, 0.342, 0.403, METAL), 0.003)
	bolt.add(K.box(0.53, 0.556, -0.0685, -0.064, 0.36, 0.385, DARK))

	tg = part("Trigger", "Trigger")
	tp = [(0.305, 0.17), (0.338, 0.17), (0.342, 0.142), (0.338, 0.122), (0.326, 0.106), (0.31, 0.098), (0.304, 0.104), (0.316, 0.118), (0.322, 0.135), (0.32, 0.15), (0.306, 0.158)]
	tg.add(K.prism(tp, "Y", -0.011, 0.011, METAL), 0.002)

	sel = part("FireSelector", "FireSelector")
	pv, tip = Vector((0.1184, 0.2816)), Vector((0.0928, 0.2144))
	d = (tip - pv).normalized()
	n = Vector((-d.y, d.x))
	arm = [tuple(pv + n * 0.015), tuple(tip + n * 0.01 - d * 0.01), tuple(tip + d * 0.004), tuple(tip - n * 0.01 - d * 0.01), tuple(pv - n * 0.015)]
	sel.add(K.prism(arm, "Y", LW + 0.003, LW + 0.012, METAL))
	sel.add(K.drop(K.cyl_y(pv.x, pv.y, 0.019, LW - 0.002, LW + 0.007, 8, METAL), 1, -1), 0.002)
	sel.add(K.prism([tuple(tip + n * 0.011 - d * 0.024), tuple(tip + d * 0.005 + n * 0.003), tuple(tip + d * 0.005 - n * 0.003), tuple(tip - n * 0.011 - d * 0.024)], "Y", LW + 0.005, LW + 0.015, ACCENT))
	return parts


CHARM = (0.91, LW + 0.006, 0.135)
BONES = [
	("Root", None, (0.0, 0.0, 0.15)),
	("Mag", "Root", (0.688, 0.0, 0.0384)),
	("ChargingHandle", "Root", (0.8512, 0.0874, 0.3904)),
	("Bolt", "Root", (0.4288, -0.0616, 0.3712)),
	("Trigger", "Root", (0.32, 0.0, 0.16)),
	("FireSelector", "Root", (0.1184, 0.0784, 0.2816)),
	("Flash", "Root", (MUZZLE_X + 0.01, 0.0, BORE)),
	("Charm", "Root", CHARM),
]
LOCATORS = [
	("Muzzle", "Root", (MUZZLE_X, 0.0, BORE), None),
	("RightGrip", "Root", (0.0, 0.0, 0.0), None),
	("LeftGrip", "Root", (1.2864, 0.0, 0.1984), None),
	("AimPoint", "Root", (AIM_X, 0.0, SIGHT_Z), AIM_ROT),
	("Eject", "Root", (0.4288, -0.0762, 0.3712), EJECT_ROT),
	("CharmPoint", "Charm", CHARM, None),
	("Socket_Muzzle", "Root", (MUZZLE_X, 0.0, BORE), None),
	("Socket_Optic", "Root", (0.62, 0.0, 0.488), None),
	("Socket_Under", "Root", (1.29, 0.0, 0.198), None),
]

RESULT = B.assemble(GUN, build_parts, BONES, LOCATORS, {"class": "Assault rifle", "tier": "T3"})
