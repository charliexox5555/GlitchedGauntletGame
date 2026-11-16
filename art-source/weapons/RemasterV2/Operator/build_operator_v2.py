# build_operator_v2.py: RemasterV2 Operator (heavy bolt-action sniper), fresh rebuild from
# vault/02 Art/References/Gun-Image-Concepts/Heavy scoped bolt-action rifle concept-13.png. Blender MCP only.
# Contract measured on the original Operator.blend (REF_Operator_Original): Muzzle 3.521, buttpad -1.3195, bore z
# 0.385, bolt axis z 0.3885, scope axis z 0.602, AimPoint (-0.0875, 0, 0.602), ScopeAxis (1.603, 0, 0.602),
# LeftGrip (1.6625, 0, 0.196); bones Root/Bolt/Mag/Trigger/Flash/Charm (original heads, Charm moved). Bolt: lift =
# rotation about X (handle on the right swings up), then slide back (-0.3). Scoped (game overlay past SCOPE_AT).
# Changes: receiver 0.086 -> 0.09 with bolt ports both sides and an inner channel; lofted scope (eyepiece with
# grip ribs, tube, objective bell) on two rings over a toothed rail with a turret saddle and three turrets, coated
# glass; slotted handguard with a neon pocket and a front stud; octagonal brake; box mag in a lipped well;
# skeleton stock with a riser on posts and a monopod notch; trigger clearance (original 0.01); hanging charm tab.

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
from v2kit import BODY, PANEL, DARK, METAL, GRIP, ACCENT, NEON, BRASS  # noqa: E402

GUN = "Operator"
BORE, BZ, SZ = 0.385, 0.3885, 0.602
MUZZLE_X = 3.521
RW, HW = 0.09, 0.088
AIM_ROT = Matrix(((0, 0, 1), (0, 1, 0), (-1, 0, 0))).to_4x4()
EJECT_RIGHT_UP = Vector((0, -0.8, 0.6)).to_track_quat("Z", "Y").to_matrix().to_4x4()


def ring(x, r, segs=18):
	return (x, K.circle(0.0, SZ, r, segs, rot=0.0))


def build_parts():
	parts = {}

	def part(name, bone="Root"):
		parts[name] = K.Part(name, bone)
		return parts[name]

	both = B.both
	neon = part("Neon")

	# ================================================================ Receiver
	rec = part("Receiver")
	body = B.solid([(0.0525, 0.448), (1.0955, 0.448), (1.0955, 0.157), (1.067, 0.133), (0.0525, 0.133)], K.section(RW, 0.12, 0.448, 0.026, 0.016), BODY, 0.003)
	body = K.cut(body, K.group(
		both(K.prism(K.chamfer([(0.1225, 0.3395), (0.77, 0.3395), (0.77, 0.4375), (0.1225, 0.4375)], 0.012), "Y", 0.03, 0.2)),  # bolt ports
		K.cyl_x(-0.1, 0.80, 0.046, 0.0, BZ, 14, DARK),  # bolt channel
		both(K.prism(K.chamfer([(0.0525 + 0.06, 0.15), (0.70, 0.15), (0.70, 0.215), (0.11, 0.215)], 0.01), "Y", RW - 0.005, 0.2)),  # lower recess
		both(K.prism([(0.164, 0.28), (0.322, 0.28), (0.315, 0.248), (0.171, 0.248)], "Y", RW - 0.005, 0.2)),  # neon pocket
		K.prism([(0.441, 0.2), (0.8225, 0.2), (0.8225, 0.05), (0.441, 0.05)], "Y", -0.064, 0.064),  # magwell cavity
	), DARK)
	rec.add(body)
	neon.add(both(K.prism([(0.167, 0.277), (0.319, 0.277), (0.313, 0.251), (0.173, 0.251)], "Y", RW - 0.0045, RW - 0.0015, NEON)))
	lip = B.solid(K.chamfer([(0.432, 0.14), (0.832, 0.14), (0.836, 0.10), (0.428, 0.10)], [0, 0, 0.008, 0.008]), [(-0.074, 0.145), (-0.074, 0.112), (-0.078, 0.106), (-0.078, 0.10), (0.078, 0.10), (0.078, 0.106), (0.074, 0.112), (0.074, 0.145)], BODY, 0.003)
	rec.add(K.cut(lip, K.prism([(0.437, 0.2), (0.827, 0.2), (0.827, 0.0), (0.437, 0.0)], "Y", -0.064, 0.064), DARK))
	rec.add(K.box(0.2345, 1.0955, -0.034, 0.034, 0.446, 0.47, DARK), 0.003)
	t = K.Part("_t")
	for x in [0.25 + 0.06 * i for i in range(14)]:
		t.add(K.drop(K.box(x, x + 0.03, -0.036, 0.036, 0.469, 0.48, DARK), 2, -1))
	rec.add(t.merged())
	guard = K.bevel(K.prism([(0.112, 0.133), (0.42, 0.133), (0.42, 0.04), (0.38, -0.0175), (0.147, -0.0175), (0.112, 0.02)], "Y", -0.032, 0.032, DARK), 0.006, 1, 30)
	rec.add(K.cut(guard, K.prism(K.chamfer([(0.15, 0.2), (0.385, 0.2), (0.385, 0.05), (0.36, 0.0125), (0.15, 0.0125)], [0, 0, 0.012, 0.0, 0.0]), "Y", -0.1, 0.1), DARK))

	# ================================================================ Handguard
	hg = part("Handguard")
	fore = B.solid([(1.0815, 0.4515), (2.2085, 0.4515), (2.2295, 0.431), (2.2295, 0.2905), (2.1875, 0.2555), (1.13, 0.168), (1.0815, 0.14)], K.section(HW, 0.13, 0.4515, 0.026, 0.03), BODY, 0.003)
	slots = K.group(*[K.prism(K.stadium(x, x + 0.14, 0.37, 0.03, 2), "Y", HW - 0.016, 0.2) for x in (1.80, 1.98)] + [K.prism(K.stadium(1.40, 1.70, 0.37, 0.03, 2), "Y", HW - 0.016, 0.2)])
	fore = K.cut(fore, K.group(both(slots), both(K.prism([(1.20, 0.28), (1.375, 0.28), (1.36, 0.245), (1.215, 0.245)], "Y", HW - 0.005, 0.2))), DARK)
	hg.add(fore)
	neon.add(both(K.prism([(1.203, 0.277), (1.372, 0.277), (1.357, 0.248), (1.218, 0.248)], "Y", HW - 0.0045, HW - 0.0015, NEON)))
	hg.add(K.box(2.2295, 2.27, -0.014, 0.014, 0.28, 0.32, METAL), 0.002)  # front stud

	# ================================================================ Barrel + brake
	br = part("Barrel")
	# v03: heavy fluted barrel (0.052 -> 0.062) and a bigger ported brake (concept).
	barrel = K.drop(K.cyl_x(2.2, 3.12, 0.062, 0.0, BORE, 16, METAL), 0, 1)
	flutes = K.group(*[K.box(2.4, 3.0, s * 0.054, s * 0.1, BORE + dz - 0.009, BORE + dz + 0.009) for s in (1, -1) for dz in (-0.022, 0.022)], K.box(2.4, 3.0, -0.009, 0.009, BORE + 0.054, BORE + 0.1))
	br.add(K.cut(barrel, flutes, DARK))
	br.add(K.cyl_x(3.108, 3.235, 0.078, 0.0, BORE, 14, DARK), 0.006)
	oc = [(-0.053, -0.089), (0.053, -0.089), (0.079, -0.062), (0.079, 0.062), (0.053, 0.089), (-0.053, 0.089), (-0.079, 0.062), (-0.079, -0.062)]
	brake = K.bevel(K.prism([(y, BORE + z) for y, z in oc], "X", 3.2305, MUZZLE_X, DARK), 0.006)
	ports = K.group(*[K.box(x, x + 0.056, -0.12, 0.12, BORE - 0.046, BORE + 0.046) for x in (3.27, 3.35, 3.43)], K.cyl_x(MUZZLE_X - 0.05, MUZZLE_X + 0.03, 0.03, 0.0, BORE, 10))
	br.add(K.cut(brake, ports, DARK))

	# ================================================================ Grip
	gr = part("Grip")
	gp = [(0.1225, 0.1365), (-0.0525, 0.1365), (-0.042, 0.105), (-0.1925, -0.182), (-0.1855, -0.2345), (0.0455, -0.2555), (0.0665, -0.21), (0.1225, 0.087)]
	grip = K.bevel(K.prism(gp, "Y", -0.064, 0.064, DARK), 0.014, 1)
	gr.add(K.cut(grip, both(K.prism(K.chamfer([(0.09, 0.08), (-0.03, 0.08), (-0.14, -0.19), (0.03, -0.215)], 0.02), "Y", 0.06, 0.2)), GRIP))

	# ================================================================ Stock (hinge block, skeleton body, riser on posts, pad)
	st = part("Stock")
	st.add(B.solid(K.chamfer([(-0.3325, 0.1505), (-0.0525, 0.1505), (-0.0525, 0.3115), (-0.3325, 0.3115)], 0.016), K.section(0.07, 0.1505, 0.3115, 0.016, 0.016), PANEL, 0.003))
	sbody = B.solid([(-0.3325, 0.3045), (-1.085, 0.3045), (-1.085, -0.21), (-0.7525, -0.21), (-0.665, -0.1645), (-0.5845, -0.0595), (-0.4025, 0.035), (-0.3325, 0.1505)], K.section(0.072, -0.22, 0.3045, 0.02, 0.02), BODY, 0.004)
	sbody = K.cut(sbody, K.group(K.prism(K.chamfer([(-0.42, 0.24), (-0.95, 0.24), (-0.95, -0.06), (-0.66, -0.06), (-0.50, 0.10)], 0.02), "Y", -0.2, 0.2), K.box(-0.875, -0.7525, -0.2, 0.2, -0.25, -0.16)), DARK)
	st.add(sbody)
	st.add(B.solid(K.chamfer([(-0.497, 0.33), (-1.0045, 0.33), (-1.0045, 0.4235), (-0.54, 0.4235)], [0, 0, 0.016, 0.016]), K.section(0.062, 0.33, 0.4235, 0.016, 0.0), PANEL, 0.003))  # cheek riser
	for x in (-0.6195, -0.6965):
		st.add(K.prism(K.circle(x, 0.0, 0.013, 8), "Z", 0.29, 0.335, METAL))  # riser posts
	pad = B.solid(K.chamfer([(-1.085, 0.38), (-1.3195, 0.38), (-1.3195, -0.217), (-1.085, -0.217)], [0, 0.024, 0.024, 0]), K.section(0.082, -0.217, 0.38, 0.018, 0.018), DARK, 0.004)
	st.add(K.cut(pad, K.group(*[K.box(-1.36, -1.31, -0.07, 0.07, z, z + 0.012) for z in (-0.17, -0.10, -0.03, 0.04, 0.11, 0.18, 0.25, 0.32)]), GRIP))

	# ================================================================ Scope
	sc = part("Scope")
	sc.add(K.loft_x([ring(-0.077, 0.1), ring(0.1015, 0.1), ring(0.11, 0.092), ring(0.2135, 0.092), ring(0.28, 0.061), ring(1.0185, 0.061), ring(1.3615, 0.135), ring(1.484, 0.135), ring(1.49, 0.14), ring(1.5925, 0.14)], DARK))
	for x in (0.125, 0.155, 0.185):
		sc.add(K.annulus_x(x, x + 0.012, 0.0, SZ, 0.098, 0.088, 18, METAL))  # eyepiece grip ribs
	sc.add(K.annulus_x(1.53, 1.545, 0.0, SZ, 0.145, 0.135, 18, METAL))
	for xr in (0.392, 0.8645):
		sc.add(K.annulus_x(xr - 0.026, xr + 0.026, 0.0, SZ, 0.08, 0.058, 18, METAL))
		sc.add(B.solid([(xr - 0.036, 0.478), (xr + 0.036, 0.478), (xr + 0.026, 0.528), (xr - 0.026, 0.528)], K.section(0.036, 0.478, 0.528, 0.0, 0.006), METAL, 0.002))
		sc.add(both(K.drop(K.cyl_y(xr, SZ - 0.08, 0.009, 0.034, 0.043, 6, METAL, rot=0.0), 1, -1)))
	sc.add(B.solid(K.chamfer([(0.5355, SZ - 0.07), (0.6895, SZ - 0.07), (0.6895, SZ + 0.07), (0.5355, SZ + 0.07)], 0.02), K.section(0.078, SZ - 0.07, SZ + 0.07, 0.024, 0.024), DARK, 0.004))  # saddle
	sc.add(K.prism(K.circle(0.6125, 0.0, 0.058, 16), "Z", SZ + 0.06, 0.774, METAL), 0.004)
	sc.add(K.prism(K.circle(0.6125, 0.0, 0.066, 16), "Z", 0.745, 0.7875, DARK), 0.004)
	sc.add(K.cyl_y(0.6125, SZ, 0.062, 0.07, 0.122, 16, DARK, rot=0.0), 0.004)
	sc.add(K.cyl_y(0.6125, SZ, 0.05, -0.12, -0.07, 14, METAL, rot=0.0), 0.004)
	lens = part("ScopeLens")
	lens.add(K.cyl_x(1.588, 1.598, 0.126, 0.0, SZ, 18, ACCENT))
	lens.add(K.cyl_x(-0.084, -0.074, 0.086, 0.0, SZ, 18, ACCENT))

	# ================================================================ Charm tab (under the receiver front, left)
	ch = part("CharmLoop")
	tab = [(0.914, 0.17), (0.976, 0.17)] + [(0.945 + 0.031 * math.cos(-a), 0.10 + 0.031 * math.sin(-a)) for a in [i * math.pi / 6 for i in range(7)]]
	tb = K.bevel(K.prism(tab, "Y", RW - 0.001, RW + 0.013, METAL), 0.003, 1, 50)
	ch.add(K.cut(tb, K.cyl_y(0.945, 0.095, 0.012, 0.0, 0.3, 10, METAL), DARK))
	ch.add(B.head(0.931, 0.152, RW + 0.013, r=0.006, h=0.003))
	ch.add(B.head(0.959, 0.152, RW + 0.013, r=0.006, h=0.003))

	# ================================================================ Moving parts
	bolt = part("Bolt", "Bolt")
	bolt.add(K.cyl_x(0.11, 0.76, 0.04, 0.0, BZ, 12, METAL, rot=0.0))
	bolt.add(K.bevel(K.cyl_x(0.04, 0.125, 0.05, 0.0, BZ, 10, DARK, rot=0.0), 0.006, 1, 25))  # shroud
	L, A = 0.15, 1.2  # handle length and lean (rad from straight down, toward the right / -Y)
	handle = K.prism([(-0.011, BZ + 0.012), (0.011, BZ + 0.012), (0.013, BZ - L), (-0.013, BZ - L)], "X", 0.188, 0.226, METAL)
	K.xform(handle, Matrix.Translation((0, 0, BZ)) @ Matrix.Rotation(-A, 4, "X") @ Matrix.Translation((0, 0, -BZ)))
	bolt.add(handle, 0.003)
	kp = Vector((0.207, -L * math.sin(A), BZ - L * math.cos(A)))
	bolt.add(K.loft_x([(kp.x - 0.036, K.circle(kp.y, kp.z, 0.018, 8)), (kp.x - 0.014, K.circle(kp.y, kp.z, 0.036, 8)), (kp.x + 0.014, K.circle(kp.y, kp.z, 0.036, 8)), (kp.x + 0.036, K.circle(kp.y, kp.z, 0.018, 8))], ACCENT))  # knob

	mg = part("Magazine", "Mag")
	mb = K.bevel(K.prism([(0.4455, 0.18), (0.8185, 0.18), (0.8185, -0.07), (0.4455, -0.07)], "Y", -0.06, 0.06, DARK), 0.01)
	mg.add(K.cut(mb, both(K.box(0.52, 0.75, 0.034, 0.2, -0.05, 0.088)), DARK))  # v02: deeper witness windows
	# v02 ammo: full-size sniper rounds (scaled to the mag), the top round on the feed lips, and the stack showing in
	# both witness windows.
	mg.add(AM.sniper_round(0.452, 0.012, 0.202, scale=0.8))
	for zc in (-0.026, 0.02, 0.064):
		mg.add(both(K.cyl_x(0.515, 0.755, 0.021, 0.034, zc, 8, BRASS, rot=0.0)))
	mg.add(B.solid(K.chamfer([(0.441, -0.068), (0.8225, -0.068), (0.826, -0.09), (0.437, -0.09)], 0.006), K.section(0.066, -0.095, -0.068, 0.004, 0.008), PANEL, 0.002))

	tg = part("Trigger", "Trigger")
	tp = [(0.237, 0.135), (0.27, 0.135), (0.272, 0.11), (0.267, 0.09), (0.256, 0.072), (0.24, 0.058), (0.233, 0.064), (0.245, 0.08), (0.25, 0.095), (0.249, 0.115), (0.238, 0.124)]
	tg.add(K.prism(tp, "Y", -0.011, 0.011, METAL), 0.002)
	return parts


CHARM = (0.945, RW + 0.006, 0.095)
BONES = [
	("Root", None, (0.0, 0.0, 0.1)),
	("Bolt", "Root", (0.4095, 0.0, BZ)),
	("Mag", "Root", (0.6405, 0.0, 0.1365)),
	("Trigger", "Root", (0.2555, 0.0, 0.126)),
	("Flash", "Root", (MUZZLE_X + 0.01, 0.0, BORE)),
	("Charm", "Root", CHARM),
]
LOCATORS = [
	("Muzzle", "Root", (MUZZLE_X, 0.0, BORE), None),
	("RightGrip", "Root", (0.0, 0.0, 0.0), None),
	("LeftGrip", "Root", (1.6625, 0.0, 0.196), None),
	("AimPoint", "Root", (-0.0875, 0.0, SZ), AIM_ROT),
	("ScopeAxis", "Root", (1.603, 0.0, SZ), None),
	("Eject", "Root", (0.455, -0.048, BZ), EJECT_RIGHT_UP),
	("CharmPoint", "Charm", CHARM, None),
	("Socket_Muzzle", "Root", (MUZZLE_X, 0.0, BORE), None),
	("Socket_Optic", "Root", (0.66, 0.0, 0.48), None),
	("Socket_Under", "Root", (1.66, 0.0, 0.19), None),
]

RESULT = B.assemble(GUN, build_parts, BONES, LOCATORS, {"class": "Sniper", "tier": "T4"})
