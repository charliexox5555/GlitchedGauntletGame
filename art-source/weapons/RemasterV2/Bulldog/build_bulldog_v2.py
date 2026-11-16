# build_bulldog_v2.py: RemasterV2 Bulldog (compact bullpup rifle), fresh rebuild from
# vault/02 Art/References/Gun-Image-Concepts/Compact Bullpup Rifle Concept Sheet-8.png. Blender MCP only.
# Contract measured on the original Bulldog.blend (REF_Bulldog_Original): Muzzle 1.4378, buttpad -1.4586, bore z
# 0.3614, AimPoint (-0.1976, 0, 0.5838) (ring on a tall post so the bullpup top clears it), front post x 0.8736,
# LeftGrip (0.806, 0, 0.156); bones Root/Mag/ChargingHandle/Bolt/Trigger/FireSelector/Flash/Charm (original heads,
# Charm moved). Bullpup: magazine in the stock behind the grip, port on the right behind the grip, forward side
# charging handle on the top-left that racks (-0.2).
# Changes: thicker shell (0.076 -> 0.084), handguard (0.078 -> 0.086), stock (0.078 -> 0.088), grip (0.048 ->
# 0.06), mag (0.045 -> 0.056); faceted shell with slots and a front plate, stock magwell with cavity and flared lip,
# ribbed mag, raised side plate with neon, sling slot, open ring + hooded post, hanging charm tab, trigger clearance.

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

GUN = "Bulldog"
BORE = 0.3614
SIGHT_Z = 0.5838
AIM_X = -0.1976
FRONT_X = 0.8736
MUZZLE_X = 1.4378
RW, SW = 0.084, 0.088
AIM_ROT = Matrix(((0, 0, 1), (0, 1, 0), (-1, 0, 0))).to_4x4()
EJECT_RIGHT_UP = Vector((0, -0.8, 0.6)).to_track_quat("Z", "Y").to_matrix().to_4x4()


def build_parts():
	parts = {}

	def part(name, bone="Root"):
		parts[name] = K.Part(name, bone)
		return parts[name]

	both = B.both
	neon = part("Neon")

	# ================================================================ Receiver shell + centre body
	rec = part("Receiver")
	shell = B.solid(K.chamfer([(-0.473, 0.291), (1.045, 0.291), (1.045, 0.45), (1.02, 0.476), (-0.473, 0.476)], [0, 0.02, 0, 0, 0]), K.section(RW, 0.291, 0.476, 0.026, 0.0), BODY, 0.003)
	shell = K.cut(shell, K.group(
		both(K.group(K.prism(K.stadium(0.80, 0.94, 0.355, 0.034, 2), "Y", RW - 0.02, 0.2), K.prism(K.stadium(0.625, 0.77, 0.355, 0.034, 2), "Y", RW - 0.02, 0.2))),
		K.prism(K.chamfer([(0.30, 0.38), (0.53, 0.38), (0.53, 0.425), (0.30, 0.425)], 0.006), "Y", RW - 0.016, 0.2),  # charging channel (left)
		K.prism(K.chamfer([(-0.473 - 0.01, 0.30), (-0.333, 0.30), (-0.333, 0.36), (-0.473 - 0.01, 0.36)], [0, 0.01, 0.01, 0]), "Y", -0.2, -RW + 0.02),  # port (right)
	), DARK)
	rec.add(shell)
	centre = B.solid([(0.351, 0.364), (-0.473, 0.364), (-0.473, 0.112), (-0.416, 0.091), (-0.208, 0.112), (0.156, 0.122), (0.351, 0.177)], K.section(RW - 0.004, 0.08, 0.364, 0.0, 0.016), BODY, 0.003)
	rec.add(centre)
	plate = K.prism(K.chamfer([(-0.159, 0.14), (0.044, 0.14), (0.044, 0.252), (-0.159, 0.252)], 0.012), "Y", RW - 0.006, RW + 0.008, PANEL)
	plate = K.cut(K.bevel(plate, 0.003, 1, 50), K.group(K.box(-0.13, -0.04, RW + 0.004, 0.2, 0.226, 0.238), K.box(-0.13, -0.04, RW + 0.004, 0.2, 0.156, 0.168)), DARK)
	rec.add(both(plate))
	neon.add(both(K.group(K.box(-0.127, -0.043, RW + 0.0045, RW + 0.0065, 0.228, 0.236, NEON), K.box(-0.127, -0.043, RW + 0.0045, RW + 0.0065, 0.158, 0.166, NEON))))
	rec.add(B.solid(K.chamfer([(0.343, 0.177), (0.611, 0.177), (0.611, 0.38), (0.343, 0.38)], 0.02), K.section(RW + 0.008, 0.177, 0.38, 0.02, 0.02), BODY, 0.003))  # front plate
	rec.add(K.box(0.112, 0.86, -0.034, 0.034, 0.474, 0.492, DARK), 0.003)  # rail base
	t = K.Part("_t")
	x = 0.13
	while x + 0.026 < 0.82:
		t.add(K.drop(K.box(x, x + 0.026, -0.034, 0.034, 0.491, 0.505, DARK), 2, -1))
		x += 0.06
	rec.add(t.merged())
	rec.add(B.solid(K.chamfer([(-0.40, 0.474), (0.117, 0.474), (0.117, 0.515), (-0.40, 0.515)], [0, 0, 0.012, 0.02]), K.section(0.046, 0.474, 0.515, 0.012, 0.0), BODY, 0.003))  # raised rear rail block
	rec.add(K.prism(K.chamfer([(-0.36, 0.298), (-0.325, 0.298), (-0.325, 0.362), (-0.36, 0.362)], [0.008, 0, 0, 0.008]), "Y", -RW - 0.012, -RW + 0.004, BODY), 0.003)  # deflector

	# ================================================================ Lower handguard (textured panel)
	hg = part("Handguard")
	lower = B.solid(K.chamfer([(0.575, 0.156), (1.074, 0.156), (1.074, 0.291), (0.575, 0.291)], [0, 0.03, 0.0, 0]), K.section(0.086, 0.156, 0.296, 0.0, 0.03), DARK, 0.003)
	hg.add(K.cut(lower, both(K.prism(K.chamfer([(0.64, 0.18), (1.02, 0.18), (1.02, 0.27), (0.64, 0.27)], 0.014), "Y", 0.082, 0.2)), GRIP))

	# ================================================================ Barrel + flash hider
	bar = part("Barrel")
	# v03: a real barrel (0.022 -> 0.034) and an octagonal brake with side ports, as on the concept.
	bar.add(K.drop(K.cyl_x(1.03, 1.255, 0.034, 0.0, BORE, 12, METAL), 0, -1))
	hider = K.bevel(K.cyl_x(1.25, MUZZLE_X, 0.05, 0.0, BORE, 8, METAL, rot=math.pi / 8), 0.006, 1, 25)
	vents = K.group(K.prism(K.stadium(1.285, 1.335, BORE, 0.026, 2), "Y", -0.2, 0.2), K.prism(K.stadium(1.355, 1.405, BORE, 0.026, 2), "Y", -0.2, 0.2), K.cyl_x(MUZZLE_X - 0.05, MUZZLE_X + 0.02, 0.022, 0.0, BORE, 8))
	bar.add(K.cut(hider, vents, DARK))
	bar.add(K.annulus_x(1.268, 1.282, 0.0, BORE, 0.036, 0.03, 12, METAL))

	# ================================================================ Sights
	si = part("Sights")
	si.add(B.solid(K.chamfer([(-0.27, 0.512), (-0.125, 0.512), (-0.125, 0.53), (-0.27, 0.53)], [0, 0, 0.008, 0.008]), K.section(0.044, 0.512, 0.53, 0.008, 0.0), DARK, 0.002))
	# v03 sight picture (Bulldog's own): protected ghost ring (thin wide ring between two tall pillars); round hood
	# over the front post. (v02's diamond plate blocked most of the view.)
	for pc in SI.ghost_ring(AIM_X, SIGHT_Z, 0.528):
		si.add(pc)
	si.add(B.solid([(FRONT_X - 0.05, 0.503), (FRONT_X + 0.05, 0.503), (FRONT_X + 0.026, 0.535), (FRONT_X - 0.026, 0.535)], [(-0.034, 0.503), (0.034, 0.503), (0.022, 0.535), (-0.022, 0.535)], DARK, 0.002))
	si.add(K.annulus_x(FRONT_X - 0.016, FRONT_X + 0.016, 0.0, SIGHT_Z, 0.052, 0.04, 12, DARK))
	si.add(K.prism([(-0.006, 0.532), (0.006, 0.532), (0.006, 0.562), (0.0016, SIGHT_Z), (-0.0016, SIGHT_Z), (-0.006, 0.562)], "X", FRONT_X - 0.006, FRONT_X + 0.006, METAL))

	# ================================================================ Grip + guard
	gr = part("Grip")
	gp = [(0.161, 0.122), (-0.065, 0.122), (-0.208, -0.208), (-0.203, -0.26), (-0.169, -0.299), (0.026, -0.304), (0.062, -0.278), (0.052, -0.221), (0.099, -0.039), (0.143, 0.065)]
	grip = K.bevel(K.prism(gp, "Y", -0.06, 0.06, DARK), 0.013, 1)
	gr.add(K.cut(grip, both(K.prism(K.chamfer([(0.10, 0.06), (-0.04, 0.07), (-0.16, -0.21), (0.02, -0.235)], 0.02), "Y", 0.056, 0.2)), GRIP))
	guard = K.bevel(K.prism([(0.156, 0.164), (0.515, 0.164), (0.515, 0.10), (0.455, -0.016), (0.156, -0.016)], "Y", -0.03, 0.03, DARK), 0.006, 1, 30)
	gr.add(K.cut(guard, K.prism(K.chamfer([(0.169, 0.20), (0.48, 0.20), (0.48, 0.10), (0.43, 0.012), (0.169, 0.012)], [0, 0, 0.012, 0.012, 0.0]), "Y", -0.1, 0.1), DARK))

	# ================================================================ Stock with magwell
	st = part("Stock")
	sbody = B.solid(K.chamfer([(-0.473, 0.476), (-0.98, 0.476), (-1.06, 0.43), (-1.227, 0.43), (-1.227, -0.07), (-1.12, -0.135), (-0.785, -0.12), (-0.785, 0.091), (-0.473, 0.112)], [0, 0.02, 0.02, 0.02, 0.02, 0.02, 0.0, 0.0, 0]), K.section(SW, -0.14, 0.476, 0.028, 0.018), BODY, 0.004)  # v03: comb steps down to the pad, heel angles up (concept)
	sbody = K.cut(sbody, K.group(
		both(K.prism(K.chamfer([(-0.52, 0.28), (-1.05, 0.28), (-1.05, 0.41), (-0.56, 0.41)], 0.014), "Y", SW - 0.005, 0.2)),  # side recess
		both(K.prism(K.stadium(-1.205, -1.185, 0.04, 0.0, 2), "Y", -0.2, 0.2)) if False else K.box(-1.21, -1.185, -0.2, 0.2, -0.03, 0.10),  # sling slot (through)
	), DARK)
	for f in sbody.faces:
		c = f.calc_center_median()
		if abs(abs(c.y) - (SW - 0.005)) < 1e-4 and 0.28 <= c.z <= 0.41:
			f.material_index = DARK  # v03: quiet recess (v01's light slab read as a sticker)
	st.add(sbody)
	lip = B.solid(K.chamfer([(-0.44, 0.115), (-0.795, 0.115), (-0.80, 0.06), (-0.436, 0.06)], [0, 0, 0.008, 0.008]), [(-0.074, 0.12), (-0.074, 0.076), (-0.078, 0.07), (-0.078, 0.06), (0.078, 0.06), (0.078, 0.07), (0.074, 0.076), (0.074, 0.12)], BODY, 0.003)
	st.add(K.cut(lip, K.prism([(-0.443, 0.2), (-0.784, 0.2), (-0.786, 0.0), (-0.441, 0.0)], "Y", -0.06, 0.06), DARK))
	pad = B.solid(K.chamfer([(-1.219, 0.445), (-1.459, 0.445), (-1.459, -0.078), (-1.219, -0.078)], [0, 0.03, 0.03, 0]), K.section(0.092, -0.078, 0.445, 0.022, 0.022), DARK, 0.004)
	st.add(K.cut(pad, K.group(*[K.box(-1.50, -1.45, -0.08, 0.08, z, z + 0.014) for z in (-0.08, 0.0, 0.08, 0.16, 0.24, 0.32, 0.40)]), GRIP))

	# ================================================================ Fasteners
	pins = part("Pins")
	for s in (1, -1):
		for x, z, w in ((0.70, 0.22, 0.086), (0.40, 0.33, RW + 0.008), (-0.92, 0.18, SW), (-0.60, 0.43, SW)):
			pins.add(B.head(x, z, w, r=0.011, segs=8, side=s))

	# ================================================================ Charm tab (hangs under the front plate, left)
	ch = part("CharmLoop")
	tab = [(0.52, 0.215), (0.584, 0.215)] + [(0.552 + 0.032 * math.cos(-a), 0.15 + 0.032 * math.sin(-a)) for a in [i * math.pi / 6 for i in range(7)]]
	tb = K.bevel(K.prism(tab, "Y", RW + 0.007, RW + 0.021, METAL), 0.003, 1, 50)
	ch.add(K.cut(tb, K.cyl_y(0.552, 0.145, 0.013, 0.0, 0.2, 10, METAL), DARK))
	ch.add(B.head(0.537, 0.198, RW + 0.021, r=0.007, h=0.004))
	ch.add(B.head(0.567, 0.198, RW + 0.021, r=0.007, h=0.004))

	# ================================================================ Moving parts
	mg = part("Mag", "Mag")
	mb = K.bevel(K.prism([(-0.447, 0.16), (-0.78, 0.16), (-0.785, 0.015), (-0.765, -0.22), (-0.455, -0.22), (-0.44, 0.015)], "Y", -0.056, 0.056, DARK), 0.01)
	mb = K.cut(mb, both(K.group(*[K.box(x, x + 0.016, 0.052, 0.2, -0.20, 0.0) for x in (-0.73, -0.67, -0.61, -0.55, -0.49)])), DARK)
	mg.add(mb)
	mg.add(AM.rifle_round(-0.765, 0.008, 0.174, scale=0.85))  # v02: top round (seen with the mag out)
	mg.add(B.solid(K.chamfer([(-0.448, -0.218), (-0.772, -0.218), (-0.78, -0.27), (-0.44, -0.27)], [0, 0, 0.01, 0.01]), K.section(0.062, -0.28, -0.218, 0.006, 0.012), PANEL, 0.003))
	mg.add(K.loft_x([(-0.70, K.circle(0, 0.172, 0.014, 8)), (-0.555, K.circle(0, 0.172, 0.014, 8)), (-0.543, K.circle(0, 0.172, 0.012, 8)), (-0.505, K.circle(0, 0.172, 0.004, 8))], METAL))

	chh = part("ChargingHandle", "ChargingHandle")
	chh.add(K.box(0.40, 0.515, RW - 0.016, RW - 0.001, 0.385, 0.42, METAL))
	chh.add(K.box(0.43, 0.48, RW - 0.002, RW + 0.03, 0.388, 0.417, METAL), 0.003)
	chh.add(K.prism(K.chamfer([(0.415, 0.372), (0.495, 0.372), (0.502, 0.40), (0.495, 0.435), (0.425, 0.435), (0.415, 0.42)], 0.006), "Y", RW + 0.026, RW + 0.05, ACCENT), 0.003)

	bolt = part("Bolt", "Bolt")
	bolt.add(K.box(-0.468, -0.338, -RW + 0.004, -RW + 0.024, 0.302, 0.358, METAL), 0.003)

	tg = part("Trigger", "Trigger")
	tp = [(0.205, 0.148), (0.238, 0.148), (0.241, 0.118), (0.236, 0.092), (0.224, 0.068), (0.208, 0.052), (0.2, 0.058), (0.214, 0.078), (0.221, 0.1), (0.219, 0.124), (0.206, 0.134)]
	tg.add(K.prism(tp, "Y", -0.011, 0.011, METAL), 0.002)

	sel = part("FireSelector", "FireSelector")
	sel.add(K.drop(K.cyl_y(0.1196, 0.1378, 0.017, RW - 0.006, RW + 0.006, 8, METAL), 1, -1), 0.002)
	sel.add(K.prism(K.chamfer([(0.10, 0.128), (0.16, 0.13), (0.165, 0.145), (0.10, 0.147)], 0.004), "Y", RW + 0.004, RW + 0.012, ACCENT))
	return parts


CHARM = (0.552, RW + 0.014, 0.145)
BONES = [
	("Root", None, (0.0, 0.0, 0.15)),
	("Mag", "Root", (-0.598, 0.0, 0.0754)),
	("ChargingHandle", "Root", (0.4368, 0.0896, 0.3978)),
	("Bolt", "Root", (-0.403, -0.0672, 0.286)),
	("Trigger", "Root", (0.2236, 0.0, 0.1378)),
	("FireSelector", "Root", (0.1196, 0.0784, 0.1378)),
	("Flash", "Root", (MUZZLE_X + 0.01, 0.0, BORE)),
	("Charm", "Root", CHARM),
]
LOCATORS = [
	("Muzzle", "Root", (MUZZLE_X, 0.0, BORE), None),
	("RightGrip", "Root", (0.0, 0.0, 0.0), None),
	("LeftGrip", "Root", (0.806, 0.0, 0.156), None),
	("AimPoint", "Root", (AIM_X, 0.0, SIGHT_Z), AIM_ROT),
	("Eject", "Root", (-0.403, -0.0762, 0.30), EJECT_RIGHT_UP),
	("CharmPoint", "Charm", CHARM, None),
	("Socket_Muzzle", "Root", (MUZZLE_X, 0.0, BORE), None),
	("Socket_Optic", "Root", (0.45, 0.0, 0.505), None),
	("Socket_Under", "Root", (0.82, 0.0, 0.156), None),
]

RESULT = B.assemble(GUN, build_parts, BONES, LOCATORS, {"class": "Rifle", "tier": "T2"})
