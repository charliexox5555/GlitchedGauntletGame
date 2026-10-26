# build_operator.py: builds the Operator (13, heavy bolt-action sniper rifle) in the open Blender scene.
#
#   g = {"__name__": "build", "__file__": path}; exec(compile(open(path).read(), path, "exec"), g); g["build"]()
#
# Family conventions in tools/blender/gunkit.py. Traced from the side view of
# vault/02 Art/References/Gun-Image-Concepts/Heavy scoped bolt-action rifle concept-13.png (P converts pixels).
# The sheet draws the bolt handle on the side it shows (the gun's left); the brief asks for a right-side handle,
# and the trigger hand works it, so it is on the right (-Y). The bolt body shows through a port on both sides.
# Bolt: one bone on the bore line. Lift = negative rotation about X (the handle swings up around the bolt axis),
# then slide back along -X. Scoped: AimPoint at the eyepiece, ScopeAxis at the objective, dark non-emissive glass.
# New reference beyond the family set: ScopeAxis (as on the Marshal/Outlaw).

import bmesh, bpy, importlib, math, os, sys
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gunkit

importlib.reload(gunkit)
from gunkit import DARK, METAL, NEON, PANEL, Part, box, charm_loop, cut, cyl_x, cyl_y, drop, group, mirror_y, prism, ring_pts, stadium

GUN = "Operator"

# Side view -> studs: muzzle (px 29) to buttpad (1412) = 4.84 studs, the longest gun. Grip at (1035, 915).
S = 0.0035
OX, OY = 1035, 915


def X(px):
	return (OX - px) * S


def Z(py):
	return (OY - py) * S


def P(pts):
	return [(X(a), Z(b)) for a, b in pts]


BORE_Z = Z(805)
BOLT_Z = Z(804)
SCOPE_Z = Z(743)
RW = 0.072  # receiver half width
HW = 0.068  # handguard half width


def frustum_x(x0, x1, r0, r1, z, segs=20, mat=METAL):
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


def rod(p0, p1, r, segs=10, mat=METAL):
	v = Vector(p1) - Vector(p0)
	bm = prism(ring_pts(0.0, 0.0, r, segs, math.pi / segs), "Z", 0.0, v.length, mat)
	bmesh.ops.transform(bm, matrix=Matrix.Translation(p0) @ v.to_track_quat("Z", "Y").to_matrix().to_4x4(), verts=bm.verts[:])
	return bm


def ball(c, r, mat=METAL):
	bm = bmesh.new()
	bmesh.ops.create_uvsphere(bm, u_segments=12, v_segments=8, radius=r)
	bmesh.ops.translate(bm, vec=Vector(c), verts=bm.verts[:])
	for f in bm.faces:
		f.material_index = mat
		f.smooth = True
	return bm


def build_parts(mats):
	parts = {}

	def part(name, bone="Root"):
		parts[name] = Part(name, bone)
		return parts[name]

	# ---- Receiver (charcoal): bolt port on both sides, bolt channel, recessed lower panel, neon pocket, rail
	rec = part("Receiver")
	body = prism(P([(722, 787), (1020, 787), (1020, 824), (1050, 826), (1050, 877), (730, 877), (722, 870)]), "Y", -RW, RW)
	port = mirror_y(box(X(1000), X(815), 0.03, RW + 0.03, Z(818), Z(790)))
	channel = cyl_x(X(1040), X(812), 0.043, BOLT_Z, 16)
	panel = mirror_y(prism(P([(850, 849), (1040, 849), (1040, 870), (860, 870)]), "Y", RW - 0.005, RW + 0.02))
	pocket = mirror_y(prism(P([(943, 835), (988, 835), (986, 844), (941, 844)]), "Y", RW - 0.005, RW + 0.02))
	rec.add(cut(body, group(port, channel, panel, pocket), mats), 0)
	rec.add(box(X(968), X(722), -0.032, 0.032, Z(787), Z(775), DARK), 0.003, 1)  # rail
	for x in range(735, 965, 18):
		rec.add(drop(box(X(x + 9), X(x), -0.034, 0.034, Z(776), Z(773), DARK), 2, -1), 0)  # rail teeth
	guard = prism(P([(915, 877), (1003, 877), (1003, 903), (990, 920), (925, 920), (915, 905)]), "Y", -0.026, 0.026, DARK)
	rec.add(cut(guard, prism(P([(925, 879), (992, 879), (992, 900), (983, 912), (930, 912)]), "Y", -0.06, 0.06), mats, DARK, bw=0.004, segs=1), 0)

	# ---- Handguard: three slots per side, neon pocket, front stud
	hg = part("Handguard")
	fore = prism(P([(398, 792), (404, 786), (726, 786), (726, 875), (712, 872), (410, 847), (398, 836)]), "Y", -HW, HW)
	slots = group(*[mirror_y(prism(stadium(X(a), X(a + 41), Z(820), 8 * S), "Y", HW - 0.012, HW + 0.02)) for a in (427, 480, 532)])
	hpocket = mirror_y(prism(P([(648, 838), (698, 838), (694, 848), (652, 848)]), "Y", HW - 0.005, HW + 0.02))
	hg.add(cut(fore, group(slots, hpocket), mats), 0)
	hg.add(box(X(398), X(386), -0.014, 0.014, Z(834), Z(822), METAL), 0.002, 1)

	# ---- Barrel and muzzle brake
	brl = part("Barrel")
	brl.add(drop(cyl_x(X(404), X(145), 0.05, BORE_Z, 16), 0, 1), 0)
	brl.add(cyl_x(X(147), X(112), 0.064, BORE_Z, 16, mat=DARK), 0.004, 1)
	oc = [(-0.04, -0.07), (0.04, -0.07), (0.06, -0.05), (0.06, 0.05), (0.04, 0.07), (-0.04, 0.07), (-0.06, 0.05), (-0.06, -0.05)]
	brake = prism([(y, BORE_Z + z) for y, z in oc], "X", X(112), X(29), DARK)
	ports = group(*[box(X(a + 16), X(a), -0.1, 0.1, BORE_Z - 0.037, BORE_Z + 0.037) for a in (40, 62, 84)], cyl_x(X(36), X(20), 0.03, BORE_Z, 12))
	brl.add(cut(brake, ports, mats, DARK, bw=0.006, segs=1), 0)

	# ---- Magazine (detachable box)
	mag = part("Magazine", "Mag")
	mbody = prism(P([(800, 874), (905, 874), (905, 928), (909, 932), (909, 939), (796, 939), (796, 932), (800, 928)]), "Y", -0.05, 0.05, DARK)
	mag.add(cut(mbody, mirror_y(box(X(829), X(825), 0.045, 0.07, Z(926), Z(886))), mats, DARK, bw=0.005, segs=1), 0)

	# ---- Pistol grip (textured) and stock (skeletal, adjustable cheek riser)
	grip = part("Grip")
	gbody = prism(P([(1000, 876), (1050, 876), (1047, 885), (1090, 967), (1088, 982), (1022, 988), (1016, 975), (1000, 890)]), "Y", -0.055, 0.055, DARK)
	grip.add(cut(gbody, mirror_y(prism(P([(1012, 900), (1043, 900), (1075, 962), (1030, 970)]), "Y", 0.05, 0.08)), mats, DARK, bw=0.01, segs=2), 0)

	st = part("Stock")
	st.add(box(X(1130), X(1050), -0.058, 0.058, Z(872), Z(826)), 0.006, 1)  # hinge block
	for x in (1095, 1115):
		st.add(mirror_y(drop(cyl_y(X(x), Z(850), 0.012, 0.055, 0.064, 8), 1, -1)), 0)
	sbody = prism(P([(1130, 828), (1200, 828), (1200, 880), (1245, 880), (1245, 828), (1345, 828), (1345, 975), (1250, 975), (1225, 962), (1202, 932), (1150, 905), (1130, 872)]), "Y", -0.058, 0.058)
	st.add(cut(sbody, mirror_y(box(X(1285), X(1247), 0.052, 0.08, Z(915), Z(882))), mats, DARK, bw=0.008), 0)
	st.add(prism(P([(1177, 817), (1182, 794), (1320, 794), (1322, 800), (1322, 827), (1190, 827)]), "Y", -0.05, 0.05), 0.006, 1)  # cheek riser
	for x in (1212, 1234):
		st.add(prism(ring_pts(X(x), 0.0, 0.012, 10, math.pi / 10), "Z", Z(882), Z(826), METAL), 0.002, 1)  # riser posts
	st.add(box(X(1362), X(1345), -0.062, 0.062, Z(975), Z(805), DARK), 0.004, 1)
	st.add(prism(P([(1360, 808), (1405, 805), (1412, 815), (1412, 968), (1405, 977), (1360, 975)]), "Y", -0.068, 0.068, DARK), 0.006, 1)

	# ---- Scope (fixed): big objective, rings, turret saddle, ribbed eyepiece
	sc = part("Scope")
	sc.add(cyl_x(X(613), X(580), 0.14, SCOPE_Z, 24), 0.008, 1)
	sc.add(cyl_x(X(646), X(611), 0.135, SCOPE_Z, 24), 0.004, 1)
	sc.add(frustum_x(X(748), X(644), 0.061, 0.135, SCOPE_Z, 24), 0)
	sc.add(cyl_x(X(955), X(744), 0.061, SCOPE_Z, 20), 0)
	for x in (788, 923):
		sc.add(cyl_x(X(x + 13), X(x - 13), 0.078, SCOPE_Z, 20, mat=DARK), 0.004, 1)
		sc.add(box(X(x + 13), X(x - 13), -0.034, 0.034, Z(787), SCOPE_Z - 0.06, DARK), 0.004, 1)
	sc.add(box(X(882), X(838), -0.075, 0.075, SCOPE_Z - 0.065, SCOPE_Z + 0.065), 0.01, 2)  # saddle
	sc.add(prism(ring_pts(X(860), 0.0, 0.058, 16, math.pi / 16), "Z", SCOPE_Z + 0.06, Z(704)), 0.003, 1)
	sc.add(prism(ring_pts(X(860), 0.0, 0.07, 20, math.pi / 20), "Z", Z(708), Z(690)), 0.005, 1)  # elevation cap
	sc.add(prism(ring_pts(X(860), SCOPE_Z, 0.068, 20, math.pi / 20), "Y", 0.07, 0.118), 0.005, 1)  # side knob
	sc.add(frustum_x(X(976), X(952), 0.061, 0.09, SCOPE_Z), 0)
	sc.add(cyl_x(X(1007), X(974), 0.092, SCOPE_Z, 20), 0.003, 1)
	for x in (981, 991, 1001):
		sc.add(cyl_x(X(x + 3), X(x - 3), 0.098, SCOPE_Z, 20), 0.002, 1)
	sc.add(cyl_x(X(1057), X(1006), 0.1, SCOPE_Z, 20), 0.007, 1)
	lens = part("ScopeLens")
	lens.add(cyl_x(X(580), X(577), 0.124, SCOPE_Z, 24, mat=DARK), 0)
	lens.add(cyl_x(X(1060), X(1057), 0.084, SCOPE_Z, 20, mat=DARK), 0)

	# ---- Neon: handguard bar and the strip under the bolt port (both sides)
	neon = part("Neon")
	neon.add(mirror_y(prism(P([(650, 840), (696, 840), (692, 846.5), (654, 846.5)]), "Y", HW - 0.004, HW - 0.0008, NEON)), 0)
	neon.add(mirror_y(prism(P([(945, 837), (986, 837), (984, 842), (943, 842)]), "Y", RW - 0.004, RW - 0.0008, NEON)), 0)

	# ---- Charm (buddy) loop: left side of the receiver's underside, ahead of the magazine
	charm = part("CharmLoop")
	lug, tor = charm_loop(X(765), Z(877), RW + 0.002)
	charm.add(lug, 0.004, 1)
	charm.add(tor, 0)

	# ---- Bolt (body, rear cap, right-side handle and knob) and trigger
	bolt = part("Bolt", "Bolt")
	bolt.add(cyl_x(X(1012), X(820), 0.04, BOLT_Z, 16), 0.003, 1)
	bolt.add(cyl_x(X(1020), X(975), 0.046, BOLT_Z, 16, mat=DARK), 0.005, 1)
	bolt.add(rod((X(956), -0.03, Z(810)), (X(970), -0.112, Z(852)), 0.013), 0)
	bolt.add(ball((X(972), -0.118, Z(857)), 0.045, DARK), 0)

	trig = part("Trigger", "Trigger")
	trig.add(prism(P([(958, 879), (966, 879), (972, 894), (970, 909), (964, 909), (964, 896)]), "Y", -0.009, 0.009, METAL), 0.003, 1)

	return parts


CHARM = (X(765), RW + 0.002 + 0.012, Z(877) - 0.049)

BONES = [
	("Root", None, (0.0, 0.0, 0.1)),
	("Bolt", "Root", (X(918), 0.0, BOLT_Z)),
	("Mag", "Root", (X(852), 0.0, Z(876))),
	("Trigger", "Root", (X(962), 0.0, Z(879))),
	("Flash", "Root", (X(29) + 0.01, 0.0, BORE_Z)),
	("Charm", "Root", CHARM),
]

EJECT = Vector((-0.15, -0.8, 0.55)).to_track_quat("Z", "Y").to_matrix().to_4x4()

LOCATORS = [
	("Muzzle", "Root", (X(29), 0.0, BORE_Z), None),
	("RightGrip", "Root", (0.0, 0.0, 0.0), None),
	("LeftGrip", "Root", (X(560), 0.0, Z(859)), None),  # handguard underside
	("AimPoint", "Root", (X(1060), 0.0, SCOPE_Z), gunkit.AIM_ROT),  # eyepiece
	("ScopeAxis", "Root", (X(577), 0.0, SCOPE_Z), None),
	("Eject", "Root", (X(905), -0.04, BOLT_Z), EJECT),  # right-side port
	("CharmPoint", "Charm", CHARM, None),
]


def build():
	mats = gunkit.begin(GUN)
	parts = build_parts(mats)
	return gunkit.assemble(GUN, parts, mats, BONES, LOCATORS,
		{"class": "Sniper", "tier": "T4", "template_version": 2, "length_rel": 1.24, "att_positions": "{}", "pbr": True})


if __name__ == "__main__":
	print(build())
