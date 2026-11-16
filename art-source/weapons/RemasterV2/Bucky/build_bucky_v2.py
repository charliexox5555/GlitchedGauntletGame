# build_bucky_v2.py: RemasterV2 Bucky (long pump-action shotgun, no ADS), fresh rebuild from
# vault/02 Art/References/Gun-Image-Concepts/Roblox Pump-Action Shotgun Concept Sheet-6.png. Blender MCP only.
# Contract measured on the original Bucky.blend (REF_Bucky_Original): Muzzle 2.832, buttpad -0.951, bore z 0.369,
# magazine tube z 0.216; bones Root/Pump/Bolt/Trigger/Shell/Flash/Charm (original heads, Charm moved); LeftGrip rides
# the Pump (1.668, 0, 0.096), ShellLoadPoint (0.747, 0, 0.114); clips incl. ReloadStart/Insert/End (ShellIn markers).
# Changes: thicker receiver (0.066 -> 0.078) with the concept's angled side panel, octagonal ribbed pump (0.072 ->
# 0.084) on action bars, heavier barrel/tube, barrel clamp, knurled tube cap, loading port with a lip, port + bolt,
# front post insert level with the rear notch, skeleton stock with slotted pad, hanging charm tab, trigger clearance
# (the original tip sat 0.003 above the guard floor).

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

GUN = "Bucky"
BORE = 0.369
TUBE = 0.216
MUZZLE_X = 2.832
RW = 0.078
EJECT_RIGHT_UP = Vector((0, -0.8, 0.6)).to_track_quat("Z", "Y").to_matrix().to_4x4()


def build_parts():
	parts = {}

	def part(name, bone="Root"):
		parts[name] = K.Part(name, bone)
		return parts[name]

	both = B.both
	neon = part("Neon")

	# ================================================================ Receiver
	rec = part("Receiver")
	body = B.solid([(0.969, 0.42), (0.132, 0.42), (-0.003, 0.384), (-0.099, 0.36), (-0.099, 0.132), (-0.063, 0.132), (0.057, 0.141), (0.969, 0.141)], K.section(RW, 0.13, 0.42, 0.026, 0.016), BODY, 0.003)
	body = K.cut(body, K.group(
		both(K.prism([(0.951, 0.408), (0.312, 0.408), (0.171, 0.234), (0.951, 0.234)], "Y", RW - 0.005, 0.2)),  # angled side panel
		both(K.box(0.129, 0.285, RW - 0.005, 0.2, 0.204, 0.228)),  # neon pocket
		K.prism(K.chamfer([(0.441, 0.25), (0.747, 0.25), (0.747, 0.354), (0.441, 0.354)], 0.012), "Y", -0.2, -RW + 0.022),  # port (right)
		K.prism(K.chamfer([(0.627, 0.05), (0.867, 0.05), (0.867, 0.20), (0.627, 0.20)], 0.01), "Y", -0.031, 0.031),  # loading port (bottom); v03: shell-wide, the rim rests on its walls
	), DARK)
	for f in body.faces:
		c = f.calc_center_median()
		if abs(abs(c.y) - (RW - 0.005)) < 1e-4 and 0.234 <= c.z <= 0.408 and c.x > 0.17:
			f.material_index = PANEL
	rec.add(body)
	neon.add(both(K.box(0.132, 0.282, RW - 0.0045, RW - 0.0015, 0.207, 0.225, NEON)))
	rec.add(K.prism(K.chamfer([(0.425, 0.256), (0.455, 0.256), (0.455, 0.35), (0.425, 0.35)], [0.008, 0, 0, 0.008]), "Y", -RW - 0.012, -RW + 0.004, BODY), 0.003)
	guard = K.bevel(K.prism([(0.18, 0.144), (0.531, 0.144), (0.531, 0.08), (0.462, 0.0), (0.205, 0.0), (0.18, 0.04)], "Y", -0.03, 0.03, DARK), 0.006, 1, 30)
	rec.add(K.cut(guard, K.prism(K.chamfer([(0.225, 0.2), (0.43, 0.2), (0.43, 0.06), (0.41, 0.028), (0.225, 0.028)], [0, 0, 0.012, 0.0, 0.0]), "Y", -0.1, 0.1), DARK))

	# ================================================================ Barrel, tube, clamp
	bar = part("Barrel")
	barrel = K.cyl_x(0.95, MUZZLE_X, 0.055, 0.0, BORE, 16, METAL)
	bar.add(K.cut(barrel, K.cyl_x(MUZZLE_X - 0.08, MUZZLE_X + 0.05, 0.036, 0.0, BORE, 12, DARK), DARK))
	bar.add(K.annulus_x(MUZZLE_X - 0.05, MUZZLE_X - 0.035, 0.0, BORE, 0.059, 0.05, 16, METAL))
	bar.add(K.drop(K.cyl_x(0.95, 2.73, 0.058, 0.0, TUBE, 14, METAL), 0, -1))
	cap = K.bevel(K.cyl_x(2.72, 2.79, 0.063, 0.0, TUBE, 14, DARK), 0.008, 1, 25)
	bar.add(cap)  # tube cap
	clamp = B.solid(K.chamfer([(2.448, 0.15), (2.541, 0.15), (2.541, 0.43), (2.448, 0.43)], 0.016), K.section(0.07, 0.15, 0.43, 0.03, 0.03), DARK, 0.003)
	bar.add(clamp)

	# ================================================================ Sights (no ADS): front post insert level with the rear notch
	si = part("Sights")
	si.add(K.prism([(2.60, 0.418), (2.735, 0.418), (2.725, 0.45), (2.70, 0.477), (2.64, 0.477), (2.60, 0.45)], "Y", -0.024, 0.024, DARK), 0.003)  # insert shows inside the rear notch
	neon.add(K.prism([(2.6106, 0.4559), (2.6326, 0.4708), (2.6312, 0.4728), (2.6092, 0.4580)], "Y", -0.013, 0.013, NEON))  # v03: lies on the post's sloped rear face
	rear = K.bevel(K.prism([(0.237, 0.418), (0.417, 0.418), (0.40, 0.49), (0.255, 0.49)], "Y", -0.036, 0.036, DARK), 0.003, 1, 50)
	si.add(K.cut(rear, K.box(0.1, 0.5, -0.012, 0.012, 0.462, 0.6), DARK))
	neon.add(both(K.box(0.2491, 0.2514, 0.02, 0.029, 0.468, 0.477, NEON)))  # v03: set into the sloped rear face

	# ================================================================ Grip
	gr = part("Grip")
	gp = [(0.162, 0.138), (-0.078, 0.144), (-0.213, -0.201), (-0.207, -0.261), (0.003, -0.297), (0.042, -0.27), (0.072, -0.156), (0.132, 0.0)]
	grip = K.bevel(K.prism(gp, "Y", -0.062, 0.062, DARK), 0.013, 1)
	gr.add(K.cut(grip, both(K.prism(K.chamfer([(0.087, 0.054), (-0.057, 0.066), (-0.15, -0.20), (0.0, -0.23)], 0.02), "Y", 0.058, 0.2)), GRIP))

	# ================================================================ Stock
	st = part("Stock")
	st.add(K.drop(K.cyl_x(-0.25, -0.093, 0.075, 0.0, 0.255, 12, DARK), 0, 1), 0.005)
	sbody = B.solid(K.chamfer([(-0.231, 0.33), (-0.873, 0.33), (-0.873, -0.282), (-0.828, -0.282), (-0.423, 0.024), (-0.273, 0.144), (-0.231, 0.159)], [0, 0.014, 0, 0.0, 0, 0, 0]), K.section(0.07, -0.29, 0.33, 0.02, 0.016), BODY, 0.004)
	st.add(K.cut(sbody, K.prism(K.chamfer([(-0.483, 0.162), (-0.79, 0.162), (-0.79, -0.102)], 0.02), "Y", -0.2, 0.2), DARK))
	pad = B.solid(K.chamfer([(-0.86, 0.345), (-0.951, 0.345), (-0.951, -0.288), (-0.86, -0.288)], [0, 0.02, 0.02, 0]), K.section(0.078, -0.288, 0.345, 0.016, 0.016), DARK, 0.004)
	st.add(K.cut(pad, both(K.group(*[K.box(-0.93, -0.89, 0.07, 0.2, z, z + 0.036) for z in (-0.22, -0.15, -0.08, -0.01, 0.06, 0.13, 0.20)])), DARK))

	# ================================================================ Fasteners
	pins = part("Pins")
	for s in (1, -1):
		for x, z in ((0.094, 0.30), (0.935, 0.30)):
			pins.add(B.head(x, z, RW, r=0.012, segs=8, side=s))

	# ================================================================ Charm tab (under the receiver's front, left, ahead of the loading port)
	ch = part("CharmLoop")
	tab = [(0.885, 0.18), (0.945, 0.18)] + [(0.915 + 0.03 * math.cos(-a), 0.12 + 0.03 * math.sin(-a)) for a in [i * math.pi / 6 for i in range(7)]]
	tb = K.bevel(K.prism(tab, "Y", RW - 0.001, RW + 0.013, METAL), 0.003, 1, 50)
	ch.add(K.cut(tb, K.cyl_y(0.915, 0.115, 0.012, 0.0, 0.2, 10, METAL), DARK))
	ch.add(B.head(0.901, 0.164, RW + 0.013, r=0.006, h=0.003))
	ch.add(B.head(0.929, 0.164, RW + 0.013, r=0.006, h=0.003))

	# ================================================================ Moving parts
	pump = part("Pump", "Pump")
	fore = B.solid(K.chamfer([(1.239, 0.096), (2.094, 0.096), (2.094, 0.315), (1.239, 0.315)], 0.03), K.section(0.084, 0.096, 0.315, 0.03, 0.03), DARK, 0.003)
	ribs = both(K.group(*[K.box(x, x + 0.022, 0.072, 0.2, 0.12, 0.29) for x in [1.33 + 0.058 * i for i in range(12)]]))
	pump.add(K.cut(fore, ribs, GRIP))
	pump.add(both(K.box(0.951, 1.245, 0.04, 0.054, 0.246, 0.276, METAL)), 0.002)  # action bars

	bolt = part("Bolt", "Bolt")
	bolt.add(K.box(0.447, 0.741, -RW + 0.004, -RW + 0.026, 0.262, 0.348, METAL), 0.003)

	tg = part("Trigger", "Trigger")
	tp = [(0.235, 0.15), (0.27, 0.15), (0.273, 0.12), (0.268, 0.1), (0.256, 0.083), (0.24, 0.07), (0.233, 0.076), (0.245, 0.094), (0.251, 0.11), (0.249, 0.13), (0.236, 0.138)]
	tg.add(K.prism(tp, "Y", -0.011, 0.011, METAL), 0.002)

	sh = part("Shell", "Shell")
	sh.add(AM.shotgun_shell(0.657, 0.0, 0.154, scale=0.92, length=0.21))  # v02: brass head to the rear (crimp goes in first)
	return parts


CHARM = (0.915, RW + 0.006, 0.115)
BONES = [
	("Root", None, (0.0, 0.0, 0.15)),
	("Pump", "Root", (1.668, 0.0, TUBE)),
	("Bolt", "Root", (0.597, -0.05, 0.3)),
	("Trigger", "Root", (0.255, 0.0, 0.126)),
	("Shell", "Root", (0.747, 0.0, 0.154)),
	("Flash", "Root", (MUZZLE_X + 0.01, 0.0, BORE)),
	("Charm", "Root", CHARM),
]
LOCATORS = [
	("Muzzle", "Root", (MUZZLE_X, 0.0, BORE), None),
	("RightGrip", "Root", (0.0, 0.0, 0.0), None),
	("LeftGrip", "Pump", (1.668, 0.0, 0.096), None),
	("Eject", "Root", (0.597, -0.066, 0.3), EJECT_RIGHT_UP),
	("ShellLoadPoint", "Root", (0.747, 0.0, 0.114), None),
	("CharmPoint", "Charm", CHARM, None),
	("Socket_Muzzle", "Root", (MUZZLE_X, 0.0, BORE), None),
	("Socket_Optic", "Root", (0.6, 0.0, 0.42), None),
	("Socket_Under", "Root", (2.49, 0.0, 0.15), None),
]

RESULT = B.assemble(GUN, build_parts, BONES, LOCATORS, {"class": "Shotgun", "tier": "T2"})
