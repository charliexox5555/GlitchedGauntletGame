# build_vandal_v2.py: RemasterV2 Vandal (fresh rebuild from vault/02 Art/References/vandal-concept.webp).
#
# Run ONLY through Blender MCP inside the visible interactive Blender session:
#   ns = {"__name__": "__main__"}; exec(compile(open(p).read(), p, "exec"), ns); result = ns["RESULT"]
# Builds into its own scene "Vandal_RemasterV2_Review" (collection "Vandal"); never touches other scenes,
# the original art-source/weapons/Vandal.blend or GunTest.blend.
#
# Contract kept from the original (tools/blender/build_vandal.py, measured on the original rig):
#   +X muzzle, +Z up, +Y gun-left, 1 unit = 1 stud, origin at the pistol grip.
#   Length muzzle 2.647 -> buttpad -1.252 (3.90 studs). Bore z 0.285. Sight line z 0.5598 (AimPoint x 0.0775).
#   Bones Root/Mag/ChargingHandle/Bolt/Trigger/FireSelector/Flash/Charm with the original heads (Charm moved
#   to the new eyelet). Locators Vandal_Muzzle/RightGrip/LeftGrip/AimPoint/Eject/CharmPoint (+ new Sockets).
# Main change: everything is thicker (receiver half width 0.072 -> 0.092, handguard 0.075 -> 0.098, grip
# 0.052 -> 0.064, mag 0.047 -> 0.058, stock 0.058 -> 0.068), designed sections with chamfers, a real magwell
# with mouth lip + catch, a charging channel, an independent trigger with clearance, an integral charm
# eyelet and open ring/post irons.

import bpy, bmesh, math, os, sys, importlib
from mathutils import Matrix, Vector

ROOT = r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/art-source/weapons/RemasterV2"
sys.path.insert(0, ROOT + "/_Library")
import v2kit as K  # noqa: E402
import ammo as AM  # noqa: E402
import v2build as B  # noqa: E402

importlib.reload(K)
importlib.reload(AM)
importlib.reload(B)
from v2kit import BODY, PANEL, DARK, METAL, GRIP, ACCENT, NEON  # noqa: E402

GUN = "Vandal"
PRE = GUN + "_"
SCENE = "Vandal_RemasterV2_Review"

BORE_Z = 0.285
SIGHT_Z = 0.5598
AIM_X = 0.0775
MUZZLE_X = 2.647
HW = 0.092  # receiver half width


def solid(side, sect, mat=BODY, edge=0.0):
	# Side profile (x, z) extruded across Y, intersected with a section (y, z) extruded along X.
	xs = [p[0] for p in side]
	a = K.prism(side, "Y", -0.5, 0.5, mat)
	b = K.prism(sect, "X", min(xs) - 0.05, max(xs) + 0.05, mat)
	out = K.intersect(a, b)
	return K.bevel(out, edge, 1, 50) if edge > 0 else out


def both(bm):
	return K.mirror_y(bm)


def hexhead(x, z, y_surface, r=0.0095, h=0.007, side=1, mat=METAL):
	y0, y1 = (y_surface - 0.003, y_surface + h) if side > 0 else (-y_surface - h, -y_surface + 0.003)
	bm = K.cyl_y(x, z, r, y0, y1, 6, mat, rot=0.0)
	return K.drop(bm, 1, -side)


def roundhead(x, z, y_surface, r=0.0085, h=0.005, side=1, mat=METAL):
	y0, y1 = (y_surface - 0.003, y_surface + h) if side > 0 else (-y_surface - h, -y_surface + 0.003)
	return K.drop(K.cyl_y(x, z, r, y0, y1, 6, mat), 1, -side)


def build_parts():
	parts = {}

	def part(name, bone="Root"):
		parts[name] = K.Part(name, bone)
		return parts[name]

	neon = part("Neon")

	# ================================================================ Receiver (graphite)
	rec = part("Receiver")
	# Lower receiver: deep body, bottom edges chamfered harder than the top shoulder.
	lower = solid(K.chamfer([(-0.09, 0.164), (0.806, 0.164), (0.806, 0.347), (-0.09, 0.347)], [0.0, 0.012, 0.0, 0.0]),
		K.section(HW, 0.164, 0.347, 0.006, 0.018), BODY, 0.004)
	cutters = K.group(
		# Side recess panels (both sides), angled front like the concept's lower seam.
		both(K.prism(K.chamfer([(0.17, 0.19), (0.66, 0.19), (0.735, 0.262), (0.17, 0.262)], 0.012), "Y", HW - 0.005, HW + 0.05)),
		# Charging channel, left side: room for the carrier at rest and fully back (-0.25).
		K.prism(K.chamfer([(0.288, 0.287), (0.802, 0.287), (0.802, 0.327), (0.288, 0.327)], 0.006), "Y", 0.072, HW + 0.05),
		# Ejection port, right side, with a slight chamfered opening.
		K.prism(K.chamfer([(0.34, 0.272), (0.632, 0.272), (0.632, 0.342), (0.34, 0.342)], 0.012), "Y", -HW - 0.05, -0.068),
		# Neon dash pocket by the selector (left).
		K.box(0.098, 0.152, HW - 0.004, HW + 0.05, 0.193, 0.205),
	)
	pocket_floor = PANEL
	lower = K.cut(lower, cutters, DARK)
	# Recess floors read as a lighter inset panel: recolour faces lying on the pocket planes.
	for f in lower.faces:
		c = f.calc_center_median()
		if abs(abs(c.y) - (HW - 0.005)) < 1e-4 and 0.19 <= c.z <= 0.262 and 0.17 <= c.x <= 0.735:
			f.material_index = pocket_floor
	rec.add(lower)
	neon.add(K.box(0.1, 0.15, HW - 0.0045, HW - 0.002, 0.1945, 0.2035, NEON))

	# Upper / dust cover: narrower than the lower so the shoulder reads, big top chamfers (concept facets).
	upper = solid([(0.211, 0.345), (0.806, 0.345), (0.806, 0.402), (0.782, 0.428), (0.211, 0.428)],
		K.section(0.084, 0.345, 0.428, 0.026, 0.0), BODY, 0.004)
	upper = K.cut(upper, both(K.prism(K.chamfer([(0.598, 0.369), (0.748, 0.369), (0.748, 0.388), (0.598, 0.388)], 0.004), "Y", 0.084 - 0.006, 0.2)), DARK)
	rec.add(upper)
	neon.add(both(K.box(0.601, 0.745, 0.0785, 0.0805, 0.3715, 0.3855, NEON)))

	# Rear block under the rear sight, stepping down to the stock adapter.
	rec.add(solid(K.chamfer([(-0.09, 0.345), (0.215, 0.345), (0.215, 0.412), (-0.09, 0.412)], [0, 0, 0, 0.03]),
		K.section(0.088, 0.345, 0.412, 0.02, 0.0), BODY, 0.004))

	# Front trunnion block (handguard clamp) with chamfered nose.
	rec.add(solid(K.chamfer([(0.804, 0.164), (1.062, 0.164), (1.062, 0.40), (0.804, 0.40)], [0, 0.03, 0.02, 0]),
		K.section(0.094, 0.164, 0.40, 0.022, 0.02), BODY, 0.004))

	# Stock adapter / hinge plate.
	rec.add(solid(K.chamfer([(-0.178, 0.178), (-0.088, 0.178), (-0.088, 0.405), (-0.178, 0.405)], [0.02, 0, 0, 0.02]),
		K.section(0.09, 0.178, 0.405, 0.016, 0.016), PANEL, 0.004))

	# Magwell: flared mouth lip, rear step for the catch, cavity sized to the magazine (0.004 gap).
	well_side = K.chamfer([(0.446, 0.166), (0.728, 0.166), (0.749, 0.084), (0.546, 0.084), (0.524, 0.112), (0.452, 0.112)],
		[0, 0, 0.008, 0.008, 0.008, 0.006])
	well_sect = [(-0.074, 0.17), (-0.074, 0.104), (-0.078, 0.098), (-0.078, 0.089), (-0.073, 0.084), (0.073, 0.084), (0.078, 0.089), (0.078, 0.098), (0.074, 0.104), (0.074, 0.17)]
	well_sect = [(y, z) for y, z in reversed(well_sect)]
	well = solid(well_side, well_sect, BODY, 0.003)
	well = K.cut(well, K.prism([(0.462, 0.20), (0.709, 0.20), (0.738, 0.05), (0.462, 0.05)], "Y", -0.0625, 0.0625), DARK)
	rec.add(well)

	# Mag catch paddle behind the well; its hook rests on the magazine's rear lug.
	rec.add(K.prism(K.chamfer([(0.424, 0.166), (0.447, 0.166), (0.447, 0.113), (0.469, 0.105), (0.469, 0.099), (0.436, 0.076), (0.421, 0.084)], [0, 0, 0, 0.003, 0.003, 0.006, 0.006]),
		"Y", -0.024, 0.024, DARK), 0.003)

	# Trigger housing plate under the receiver, slotted for the trigger.
	plate = K.bevel(K.box(0.118, 0.382, -0.068, 0.068, 0.150, 0.166, PANEL), 0.004)
	plate = K.cut(plate, K.box(0.182, 0.252, -0.017, 0.017, 0.12, 0.2), DARK)
	rec.add(plate)

	# Ejection deflector bump behind the port (right side).
	rec.add(K.prism(K.chamfer([(0.30, 0.268), (0.338, 0.268), (0.338, 0.346), (0.30, 0.346)], [0.01, 0, 0, 0.01]), "Y", -HW - 0.012, -HW + 0.004, BODY), 0.003)

	# ================================================================ Handguard
	hg = part("Handguard")
	body = solid(K.chamfer([(1.046, 0.1705), (1.553, 0.1705), (1.553, 0.412), (1.046, 0.412)], [0, 0.02, 0.016, 0]),
		K.section(0.098, 0.1705, 0.412, 0.032, 0.04), BODY, 0.005)
	slots = K.group(*[K.prism(K.stadium(x0, x1, zc, 0.032, 3), "Y", 0.098 - 0.024, 0.2) for x0, x1 in ((1.10, 1.255), (1.292, 1.452)) for zc in (0.256, 0.336)])
	slots = both(slots)
	hg.add(K.cut(body, slots, DARK))
	# Hand stop under the front of the handguard (ahead of LeftGrip at x 1.32).
	hg.add(K.prism(K.chamfer([(1.455, 0.175), (1.545, 0.175), (1.53, 0.128), (1.488, 0.128)], [0, 0, 0.008, 0.008]), "Y", -0.05, 0.05, DARK), 0.004)
	# Front cap ring (slightly inset section) and barrel nut.
	hg.add(solid([(1.551, 0.18), (1.632, 0.18), (1.632, 0.40), (1.551, 0.40)], K.section(0.088, 0.18, 0.40, 0.03, 0.034), PANEL, 0.005))
	hg.add(K.drop(K.cyl_x(1.630, 1.685, 0.06, 0.0, BORE_Z, 10, METAL), 0, -1), 0.005)

	# ================================================================ Rail (dark)
	rail = part("Rail")
	rail.add(K.box(0.211, 1.60, -0.05, 0.05, 0.4255, 0.452, DARK), 0.005)
	rail.add(K.drop(K.box(0.80, 1.60, -0.036, 0.036, 0.398, 0.4265, DARK), 2, 1))
	teeth = K.Part("_t")
	x = 0.232
	while x + 0.032 < 1.44:
		teeth.add(K.drop(K.box(x, x + 0.032, -0.05, 0.05, 0.451, 0.476, DARK), 2, -1))
		x += 0.068
	rail.add(teeth.merged())
	rail.add(K.prism(K.chamfer([(1.452, 0.40), (1.535, 0.40), (1.535, 0.462), (1.452, 0.462)], [0, 0, 0.018, 0.018]), "Y", -0.056, 0.056, DARK), 0.004)

	# ================================================================ Rear sight (v02: one solid aperture block)
	# MBUS-style, as on the concept: a base on the rail, an aperture leaf with a round window, and guard wings that
	# are part of the same block. Nothing stands on its own in the ADS view (v01's ring-on-a-stem + loose ears did).
	rs = part("RearSight")
	rs.add(solid(K.chamfer([(-0.02, 0.41), (0.19, 0.41), (0.19, 0.468), (-0.02, 0.468)], [0, 0, 0.016, 0.045]),
		K.section(0.06, 0.41, 0.468, 0.012, 0.0), DARK, 0.003))
	leaf_yz = K.chamfer([(-0.072, 0.462), (0.072, 0.462), (0.072, SIGHT_Z + 0.046), (0.046, SIGHT_Z + 0.072), (-0.046, SIGHT_Z + 0.072), (-0.072, SIGHT_Z + 0.046)], [0, 0, 0.006, 0.006, 0.006, 0.006])
	leaf = K.prism(leaf_yz, "X", AIM_X - 0.011, AIM_X + 0.011, DARK)
	leaf = K.cut(leaf, K.cyl_x(AIM_X - 0.05, AIM_X + 0.05, 0.05, 0.0, SIGHT_Z, 12, DARK, rot=0.0), DARK)
	rs.add(leaf, 0.003, 1, 40)
	# Guard wings: thick side plates fused to the leaf and the base, sloping back and down.
	wing = K.prism(K.chamfer([(AIM_X - 0.07, 0.462), (AIM_X + 0.09, 0.462), (AIM_X + 0.016, SIGHT_Z + 0.03), (AIM_X - 0.016, SIGHT_Z + 0.03)], [0.0, 0.0, 0.008, 0.008]), "Y", 0.058, 0.08, DARK)
	rs.add(both(wing), 0.003, 1, 40)

	# ================================================================ Front sight (v02: post between two ears)
	# AK-style block as on the concept: the block clamps barrel + gas tube, a tower rises into two protective ears,
	# the post stands between them with its tip on the sight line. A cross hole lightens the tower (side read).
	fs = part("FrontSight")
	fs.add(solid(K.chamfer([(1.95, 0.20), (2.096, 0.20), (2.096, 0.39), (1.95, 0.39)], [0.012, 0.012, 0.02, 0.012]), K.section(0.058, 0.20, 0.39, 0.016, 0.016), BODY, 0.004))
	tower_side = K.chamfer([(1.968, 0.386), (2.078, 0.386), (2.058, SIGHT_Z + 0.034), (1.988, SIGHT_Z + 0.034)], [0, 0, 0.01, 0.01])
	tower_sect = [(-0.05, 0.386), (0.05, 0.386), (0.044, SIGHT_Z + 0.034), (-0.044, SIGHT_Z + 0.034)]
	tower = solid(tower_side, tower_sect, BODY, 0.004)
	tower = K.cut(tower, K.prism(K.chamfer([(1.95, 0.484), (2.10, 0.484), (2.10, 0.70), (1.95, 0.70)], 0.0), "Y", -0.027, 0.027), DARK)  # gap between the ears
	tower = K.cut(tower, K.cyl_y(2.023, 0.43, 0.017, -0.2, 0.2, 8, DARK, rot=0.0), DARK)  # cross hole
	fs.add(tower)
	post = [(-0.0075, 0.48), (0.0075, 0.48), (0.0075, 0.528), (0.0022, SIGHT_Z), (-0.0022, SIGHT_Z), (-0.0075, 0.528)]
	fs.add(K.prism(post, "X", 2.015, 2.031, METAL))

	# ================================================================ Barrel group (satin steel)
	bar = part("Barrel")
	bar.add(K.drop(K.drop(K.cyl_x(1.04, 2.39, 0.042, 0.0, BORE_Z, 16), 0, 1), 0, -1))
	bar.add(K.drop(K.drop(K.cyl_x(1.60, 1.96, 0.028, 0.0, 0.347, 10), 0, 1), 0, -1))
	bar.add(K.cyl_x(2.384, 2.468, 0.06, 0.0, BORE_Z, 8, METAL, rot=math.pi / 8), 0.008)
	brake = K.bevel(K.cyl_x(2.465, MUZZLE_X, 0.062, 0.0, BORE_Z, 8, METAL, rot=math.pi / 8), 0.008)
	ports = K.group(
		K.prism(K.stadium(2.488, 2.548, BORE_Z, 0.03, 2), "Y", -0.2, 0.2),
		K.prism(K.stadium(2.568, 2.622, BORE_Z, 0.03, 2), "Y", -0.2, 0.2),
		K.cyl_x(2.60, 2.70, 0.026, 0.0, BORE_Z, 8, METAL, rot=0.0),
	)
	bar.add(K.cut(brake, ports, DARK))

	# ================================================================ Grip + trigger guard (polymer)
	grip = part("Grip")
	gp = [(0.1395, 0.166), (-0.09, 0.166), (-0.0837, 0.0868), (-0.130, 0.0372), (-0.186, -0.279), (-0.164, -0.3007), (0.0062, -0.3069),
		(0.0248, -0.2697), (0.062, -0.2232), (0.0496, -0.1829), (0.0806, -0.1426), (0.062, -0.0992), (0.099, -0.0558)]
	gbody = K.bevel(K.prism(gp, "Y", -0.064, 0.064, DARK), 0.016, 1)
	panel = K.prism(K.chamfer([(0.055, -0.02), (-0.095, 0.0), (-0.150, -0.255), (-0.005, -0.262)], 0.02), "Y", 0.064 - 0.004, 0.2)
	gbody = K.cut(gbody, both(panel), GRIP)
	grip.add(gbody)
	guard = [(0.375, 0.152), (0.412, 0.152), (0.412, 0.042), (0.392, 0.012), (0.12, 0.012), (0.12, 0.044), (0.375, 0.044)]
	grip.add(K.prism(guard, "Y", -0.034, 0.034, DARK), 0.008)

	# ================================================================ Stock
	st = part("Stock")
	st.add(solid([(-0.425, 0.215), (-0.17, 0.215), (-0.17, 0.375), (-0.425, 0.375)], K.section(0.05, 0.215, 0.375, 0.016, 0.016), BODY, 0.004))
	sb = solid(K.chamfer([(-0.341, 0.397), (-0.372, 0.4185), (-1.06, 0.4185), (-1.10, 0.397), (-1.10, 0.198), (-0.465, 0.192)], [0.01, 0.01, 0.01, 0.0, 0.0, 0.012]),
		K.section(0.068, 0.19, 0.4185, 0.022, 0.016), BODY, 0.005)
	sb = K.cut(sb, both(K.prism(K.chamfer([(-0.52, 0.236), (-1.045, 0.236), (-1.045, 0.378), (-0.435, 0.378)], 0.014), "Y", 0.068 - 0.005, 0.2)), PANEL)
	st.add(sb)
	st.add(K.prism(K.chamfer([(-0.738, 0.205), (-0.868, 0.205), (-1.073, -0.05), (-1.073, -0.149), (-1.017, -0.149)], [0, 0.01, 0, 0, 0.01]), "Y", -0.056, 0.056, BODY), 0.009)
	st.add(K.box(-1.107, -1.017, -0.06, 0.06, -0.16, 0.205, BODY), 0.008)
	pad = solid(K.chamfer([(-1.10, 0.415), (-1.252, 0.415), (-1.252, -0.177), (-1.10, -0.177)], [0, 0.03, 0.03, 0]), K.section(0.078, -0.177, 0.415, 0.02, 0.02), DARK, 0.005)
	grooves = K.group(*[K.box(-1.30, -1.244, -0.06, 0.06, z, z + 0.014) for z in (-0.10, -0.04, 0.02, 0.08, 0.14, 0.20, 0.26, 0.32)])
	st.add(K.cut(pad, grooves, GRIP))

	# ================================================================ Fasteners
	pins = part("Pins")
	for s in (1, -1):
		for x, z in ((0.85, 0.36), (1.012, 0.36)):
			pins.add(hexhead(x, z, 0.094, side=s))
		for x, z in ((-0.133, 0.372), (-0.133, 0.212)):
			pins.add(hexhead(x, z, 0.09, side=s))
		for x, z in ((0.245, 0.214), (0.318, 0.214)):
			pins.add(roundhead(x, z, HW - 0.005, side=s))
		for x, z in ((0.02, 0.44), (0.17, 0.44)) if s > 0 else ((0.02, 0.44),):
			pins.add(roundhead(x, z, 0.052, r=0.0075, side=s))
		pins.add(roundhead(2.05, 0.30, 0.058, r=0.011, side=s))
		pins.add(hexhead(-1.062, 0.30, 0.06, side=s))

	# ================================================================ Charm eyelet (integral tab on the trunnion, left side)
	charm = part("CharmLoop")
	tab = [(0.892, 0.215), (0.968, 0.215)] + [(0.93 + 0.038 * math.cos(-a), 0.15 + 0.038 * math.sin(-a)) for a in [i * math.pi / 6 for i in range(7)]]
	tabbm = K.bevel(K.prism(tab, "Y", 0.093, 0.108, METAL), 0.004)
	tabbm = K.cut(tabbm, K.cyl_y(0.93, 0.148, 0.0155, 0.0, 0.2, 10, METAL), DARK)
	charm.add(tabbm)
	charm.add(hexhead(0.91, 0.195, 0.108, r=0.008, h=0.005))
	charm.add(hexhead(0.95, 0.195, 0.108, r=0.008, h=0.005))

	# ================================================================ Moving parts
	mag = part("Mag", "Mag")
	back = [(0.468, 0.20), (0.4681, 0.1302), (0.4867, 0.0403), (0.527, -0.062), (0.5828, -0.1705), (0.6479, -0.279), (0.713, -0.378)]
	front = [(0.70, 0.20), (0.7068, 0.1457), (0.7285, 0.0744), (0.7688, -0.0248), (0.8277, -0.1364), (0.9021, -0.248), (0.9858, -0.3472)]
	mprof = back + front[::-1]
	mb = K.bevel(K.prism(mprof, "Y", -0.058, 0.058, DARK), 0.012)
	# Witness windows along the rear half, following the curve.
	win = bmesh.new()
	pts = []
	for t in [i / 6 for i in range(1, 6)]:
		# point along the back curve, then 0.05 forward-ish (perpendicular)
		seg = t * (len(back) - 2) + 1
		i = min(int(seg), len(back) - 2)
		f = seg - i
		a, b = Vector(back[i]), Vector(back[i + 1])
		p = a.lerp(b, f)
		d = (b - a).normalized()
		n = Vector((d.y, -d.x)) * -1
		if n.x < 0:
			n = -n
		pts.append((p + n * 0.05, d))
	for p, d in pts:
		w = K.box(p.x - 0.014, p.x + 0.014, 0.058 - 0.006, 0.2, p.y - 0.016, p.y + 0.016)
		K.rot_y(w, -math.atan2(d.y, d.x) + math.pi / 2, (p.x, 0, p.y))
		K.merge(win, w)
	mb = K.cut(mb, both(win), DARK)
	# Neon pocket along the front edge just under the well.
	nfront = [(0.7215, 0.075), (0.734, 0.075), (0.755, 0.0), (0.742, 0.0)]
	mb = K.cut(mb, both(K.prism(nfront, "Y", 0.058 - 0.004, 0.2)), DARK)
	mag.add(mb)
	mag.add(both(K.prism([(0.7235, 0.072), (0.732, 0.072), (0.752, 0.003), (0.7435, 0.003)], "Y", 0.0545, 0.0562, NEON)))
	# Rear lug under the catch hook.
	mag.add(K.box(0.461, 0.48, -0.02, 0.02, 0.087, 0.0995, DARK), 0.003)
	# Baseplate.
	mag.add(K.prism(K.chamfer([(0.998, -0.330), (0.700, -0.357), (0.708, -0.405), (1.006, -0.377)], [0.01, 0.006, 0.006, 0.012]), "Y", -0.064, 0.064, PANEL), 0.006)
	# Top round (hidden while seated, visible when the mag is out).
	rnd = AM.rifle_round(0.488, 0.0, 0.214, scale=0.85)  # v02: brass-cased rifle round
	mag.add(rnd)

	chh = part("ChargingHandle", "ChargingHandle")
	chh.add(K.box(0.56, 0.792, 0.074, 0.0905, 0.291, 0.323, METAL))
	chh.add(K.box(0.556, 0.598, 0.089, 0.11, 0.296, 0.318, METAL), 0.003)
	chh.add(K.prism(K.chamfer([(0.538, 0.282), (0.612, 0.282), (0.618, 0.302), (0.612, 0.336), (0.55, 0.336), (0.538, 0.322)], [0.006, 0.006, 0, 0.006, 0.006, 0]), "Y", 0.106, 0.128, ACCENT), 0.004)

	bolt = part("Bolt", "Bolt")
	bolt.add(K.box(0.353, 0.617, -0.072, -0.046, 0.278, 0.336, METAL), 0.004)
	bolt.add(K.box(0.585, 0.612, -0.0745, -0.07, 0.296, 0.318, DARK), 0.002)  # extractor face detail

	trig = part("Trigger", "Trigger")
	tp = [(0.196, 0.175), (0.228, 0.175), (0.232, 0.14), (0.229, 0.112), (0.22, 0.088), (0.206, 0.068), (0.196, 0.072), (0.204, 0.092), (0.21, 0.116), (0.208, 0.14), (0.198, 0.152)]
	trig.add(K.prism(tp, "Y", -0.013, 0.013, METAL), 0.003)

	sel = part("FireSelector", "FireSelector")
	pv = Vector((0.0806, 0.2852))
	tip = Vector((0.022, 0.19))
	d = (tip - pv).normalized()
	nrm = Vector((-d.y, d.x))
	arm = [tuple(pv + nrm * 0.016), tuple(tip + nrm * 0.011 - d * 0.012), tuple(tip + d * 0.004), tuple(tip - nrm * 0.011 - d * 0.012), tuple(pv - nrm * 0.016)]
	sel.add(K.prism(arm, "Y", HW + 0.004, HW + 0.013, METAL))
	sel.add(K.drop(K.cyl_y(pv.x, pv.y, 0.022, HW - 0.002, HW + 0.008, 8, METAL), 1, -1), 0.003)
	sel.add(K.prism(K.chamfer([tuple(tip + nrm * 0.013 - d * 0.03), tuple(tip + d * 0.006 + nrm * 0.004), tuple(tip + d * 0.006 - nrm * 0.004), tuple(tip - nrm * 0.013 - d * 0.03)], 0.003), "Y", HW + 0.006, HW + 0.017, ACCENT), 0.002)

	return parts


BONES = [
	("Root", None, (0.0, 0.0, 0.15)),
	("Mag", "Root", (0.5828, 0.0, 0.155)),
	("ChargingHandle", "Root", (0.6572, 0.08, 0.3069)),
	("Bolt", "Root", (0.4898, -0.06, 0.3162)),
	("Trigger", "Root", (0.2108, 0.0, 0.1612)),
	("FireSelector", "Root", (0.0806, 0.08, 0.2852)),
	("Flash", "Root", (MUZZLE_X + 0.01, 0.0, BORE_Z)),
	("Charm", "Root", (0.93, 0.1005, 0.148)),
]

AIM_ROT = Matrix(((0, 0, 1), (0, 1, 0), (-1, 0, 0))).to_4x4()
EJECT_ROT = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0))).to_4x4()
LOCATORS = [
	("Muzzle", "Root", (MUZZLE_X, 0.0, BORE_Z), None),
	("RightGrip", "Root", (0.0, 0.0, 0.0), None),
	("LeftGrip", "Root", (1.32, 0.0, 0.1705), None),
	("AimPoint", "Root", (AIM_X, 0.0, SIGHT_Z), AIM_ROT),
	("Eject", "Root", (0.4836, -0.072, 0.316), EJECT_ROT),
	("CharmPoint", "Charm", (0.93, 0.1005, 0.148), None),
	("Socket_Muzzle", "Root", (MUZZLE_X, 0.0, BORE_Z), None),
	("Socket_Optic", "Root", (0.62, 0.0, 0.476), None),
	("Socket_Under", "Root", (1.32, 0.0, 0.1705), None),
]


RESULT = B.assemble(GUN, build_parts, BONES, LOCATORS, {"class": "Assault rifle", "tier": "T3"})
