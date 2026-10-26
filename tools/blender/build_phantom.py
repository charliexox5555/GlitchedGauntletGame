# build_phantom.py: builds the Phantom rifle (gun 2, the Vandal's suppressed companion) in the open Blender scene.
# Re-running it replaces the gun, so tweak numbers here rather than by hand.
#
#   Run inside Blender (Text Editor, or the Blender MCP):
#     g = {"__name__": "build", "__file__": path}; exec(compile(open(path).read(), path, "exec"), g); g["build"]()
#
# Same conventions as the Vandal (see tools/blender/gunkit.py): +X muzzle, +Z up, +Y gun-left, 1 unit = 1 stud,
# origin at the pistol grip, same bones and locators. Shapes come from the approved concept's side view
# (vault/02 Art/References/phantom-concept.webp, 1448x1086 sheet, side view in the bottom panel), in image
# pixels: P(px, py) converts. The positions were read by eye (the file was added after the user approved the model).

import bmesh, bpy, importlib, math, os, sys
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gunkit

importlib.reload(gunkit)
from gunkit import DARK, METAL, NEON, PANEL, Part, box, charm_loop, cut, cyl_x, cyl_y, drop, group, merge, mirror_y, prism, stadium

GUN = "Phantom"

# Concept side view -> studs. Suppressor front (px 160) to buttpad (px 1285) = 3.6 studs (the Vandal is 3.9);
# grip centre at (942, 900), where the Vandal's grip sits too.
S = 0.0032
OX, OY = 942, 900


def X(px):
	return (OX - px) * S


def Z(py):
	return (OY - py) * S


def P(pts):
	return [(X(a), Z(b)) for a, b in pts]


BORE_Z = Z(790)
SIGHT_Z = Z(729)  # rear aperture centre = front post tip


def build_parts(mats):
	parts = {}

	def part(name, bone="Root"):
		parts[name] = Part(name, bone)
		return parts[name]

	hw = 0.068  # upper receiver half width
	lw = 0.064  # lower receiver half width

	# ---- Receiver (charcoal): AR-style upper and lower, magwell, end plate
	rec = part("Receiver")
	upper = prism(P([(650, 772), (659, 762), (990, 762), (990, 800), (650, 800)]), "Y", -hw, hw)
	port = box(X(850), X(765), -hw - 0.02, -hw + 0.025, Z(795), Z(772))  # ejection port (right side)
	track = box(X(762), X(650), hw - 0.01, hw + 0.02, Z(787), Z(769))  # charging handle track (left side)
	neon_pocket = mirror_y(box(X(857), X(811), hw - 0.006, hw + 0.02, Z(800.5), Z(793.5)))
	rec.add(cut(upper, group(port, track, neon_pocket), mats), 0)
	rec.add(prism(P([(656, 800), (990, 800), (990, 850), (676, 850), (656, 836)]), "Y", -lw, lw), 0.008)
	rec.add(prism(P([(674, 846), (797, 846), (797, 890), (684, 890), (678, 880)]), "Y", -0.058, 0.058), 0.007, 1)  # magwell
	rec.add(box(X(997), X(984), -0.07, 0.07, Z(850), Z(768)), 0.005, 1)  # end plate
	rec.add(box(X(798), X(772), lw - 0.002, lw + 0.009, Z(836), Z(818), DARK), 0.003, 1)  # bolt catch (left side)

	# ---- Handguard (charcoal, M-LOK slots, chamfered underside)
	hg = part("Handguard")
	gw, top, bot = 0.072, Z(766), Z(838)
	sect = [(-gw + 0.012, top), (gw - 0.012, top), (gw, top - 0.012), (gw, bot + 0.04), (gw - 0.03, bot), (-gw + 0.03, bot), (-gw, bot + 0.04), (-gw, top - 0.012)]
	body = prism(sect, "X", X(652), X(442))
	slots = group(*[prism(stadium(X(x1), X(x0), zc, 0.026, 3), "Y", gw - 0.02, gw + 0.03) for x0, x1 in ((505, 455), (585, 530)) for zc in (Z(786), Z(818))])
	mirror_y(slots)
	hg.add(cut(body, slots, mats, bw=0.009), 0)
	cap = [(y * 0.9, min(max(z, bot + 0.008), top - 0.006)) for y, z in sect]
	hg.add(prism(cap, "X", X(442), X(428)), 0.007, 1)

	# ---- Suppressor (near-black, round): two sections with a seam, rounded front, bore at the muzzle
	sup = part("Suppressor")
	r = 0.08
	front = cyl_x(X(331), X(160), r, BORE_Z, 32, mat=DARK)
	bore = cyl_x(X(166), X(150), 0.026, BORE_Z, 16)
	sup.add(cut(front, bore, mats, DARK, bw=0.014, segs=2), 0)
	sup.add(cyl_x(X(398), X(333), r - 0.002, BORE_Z, 32, mat=DARK), 0.01, 1)
	sup.add(drop(drop(cyl_x(X(335), X(329), r - 0.007, BORE_Z, 32, mat=METAL), 0, 1), 0, -1), 0)  # seam
	sup.add(cyl_x(X(430), X(397), 0.058, BORE_Z, 16, mat=METAL), 0.006, 1)  # mount collar

	# ---- Rail (black): base, foot, teeth
	rail = part("Rail")
	rail.add(box(X(930), X(436), -0.04, 0.04, Z(760), Z(752), DARK), 0.003, 1)
	rail.add(drop(box(X(930), X(436), -0.033, 0.033, Z(767), Z(760) + 0.001, DARK), 2, 1), 0)
	teeth = bmesh.new()
	x = X(930) + 0.012
	while x + 0.024 < X(438):
		merge(teeth, drop(box(x, x + 0.024, -0.04, 0.04, Z(752) - 0.001, Z(748), DARK), 2, -1))
		x += 0.05
	rail.add(teeth, 0)

	# ---- Flip-up sights (black): front tower with post, rear aperture
	sights = part("Sights")
	sights.add(box(X(478), X(445), -0.036, 0.036, Z(752), Z(742), DARK), 0.004, 1)
	ear = [(448, 742), (474, 742), (471, 724), (464, 718), (456, 718), (451, 724)]
	sights.add(group(prism(P(ear), "Y", 0.02, 0.034, DARK), prism(P(ear), "Y", -0.034, -0.02, DARK)), 0.003, 1)
	sights.add(box(X(463), X(459), -0.006, 0.006, Z(742), SIGHT_Z, METAL), 0.002, 1)  # front post
	sights.add(box(X(908), X(876), -0.036, 0.036, Z(752), Z(742), DARK), 0.004, 1)
	tower = prism(P([(884, 742), (904, 742), (904, 726), (899, 720), (889, 720), (884, 726)]), "Y", -0.028, 0.028, DARK)
	sights.add(cut(tower, cyl_x(X(910), X(878), 0.014, SIGHT_Z, 10), mats, bw=0.003, segs=1), 0)

	# ---- Grip and trigger guard (black polymer), same footprint as the Vandal's
	grip = part("Grip")
	grip.add(prism(P([(882, 850), (968, 850), (980, 862), (976, 874), (1002, 984), (1003, 996), (934, 998), (930, 989), (938, 981), (912, 906), (904, 893), (898, 881), (887, 872)]), "Y", -0.05, 0.05, DARK), 0.012, 1)
	guard = group(
		prism(P([(796, 872), (884, 872), (884, 882), (800, 882), (796, 878)]), "Y", -0.026, 0.026, DARK),
		prism(P([(790, 848), (802, 848), (802, 880), (796, 882), (790, 876)]), "Y", -0.026, 0.026, DARK),
	)
	grip.add(guard, 0.004)

	# ---- Stock (round dark tube, charcoal body with an inset panel, black buttpad)
	st = part("Stock")
	st.add(cyl_x(X(1064), X(994), 0.064, Z(795), 16, mat=DARK), 0.006, 1)
	st.add(cyl_x(X(1000), X(990), 0.074, Z(795), 12, mat=METAL), 0.004, 1)  # castle nut
	stock = prism(P([(1052, 782), (1064, 772), (1246, 772), (1252, 778), (1252, 915), (1238, 918), (1100, 858), (1086, 846), (1056, 806)]), "Y", -0.055, 0.055)
	inset = mirror_y(prism(P([(1112, 787), (1236, 787), (1236, 882), (1204, 882), (1112, 840)]), "Y", 0.049, 0.07))
	st.add(cut(stock, inset, mats, PANEL, bw=0.01, segs=1), 0)
	st.add(prism(P([(1248, 778), (1256, 770), (1278, 772), (1285, 782), (1285, 910), (1278, 920), (1256, 920), (1248, 912)]), "Y", -0.065, 0.065, DARK), 0.009, 1)
	st.add(mirror_y(box(X(1197), X(1183), 0.05, 0.057, Z(847), Z(833), METAL)), 0.002, 1)  # QD socket
	st.add(mirror_y(drop(cyl_y(X(1219), Z(907), 0.017, 0.05, 0.06, 8), 1, -1)), 0.002, 1)  # sling knob

	# ---- Pins (metal, both sides)
	pins = part("Pins")
	for px, py, rr in ((700, 812, 0.011), (962, 814, 0.011), (868, 826, 0.009), (886, 834, 0.009)):
		pins.add(mirror_y(drop(cyl_y(X(px), Z(py), rr, lw - 0.002, lw + 0.006, 6), 1, -1)), 0)

	# ---- Neon (restrained: upper receiver bars both sides, one square by the trigger on the left)
	neon = part("Neon")
	neon.add(mirror_y(box(X(855), X(813), hw - 0.006, hw - 0.0015, Z(799.5), Z(794.5), NEON)), 0)
	neon.add(box(X(782), X(773), 0.058 - 0.002, 0.058 + 0.0025, Z(889), Z(880), NEON), 0)

	# ---- Charm (buddy) mount: same QD loop as the Vandal, left side of the lower receiver's front
	charm = part("CharmLoop")
	lug, tor = charm_loop(X(664), Z(822), lw + 0.002)
	charm.add(lug, 0.004, 1)
	charm.add(tor, 0)

	# ---- Moving parts
	mag = part("Mag", "Mag")
	mbody = prism(P([(688, 886), (766, 886), (760, 972), (678, 972)]), "Y", -0.042, 0.042, DARK)
	ribs = mirror_y(group(box(X(763), X(679), 0.042 - 0.004, 0.06, Z(934), Z(930)), box(X(760), X(744), 0.042 - 0.003, 0.06, Z(962), Z(900))))
	mag.add(cut(mbody, ribs, mats, DARK, bw=0.007), 0)
	mag.add(prism(P([(674, 970), (764, 970), (762, 994), (672, 994)]), "Y", -0.048, 0.048, DARK), 0.007)  # base plate

	chh = part("ChargingHandle", "ChargingHandle")
	chh.add(box(X(700), X(652), hw - 0.008, hw + 0.02, Z(790), Z(766), DARK), 0.004, 1)
	chh.add(cyl_y(X(656), Z(772), 0.011, hw + 0.016, hw + 0.026, 8), 0.002, 1)  # knob

	bolt = part("Bolt", "Bolt")
	bolt.add(box(X(848), X(767), -hw + 0.004, -hw + 0.022, Z(793), Z(774), METAL), 0.002, 1)

	trig = part("Trigger", "Trigger")
	trig.add(prism(P([(836, 849), (848, 849), (849, 858), (846, 868), (840, 876), (834, 877), (837, 867), (839, 858)]), "Y", -0.01, 0.01, METAL), 0.003, 1)

	sel = part("FireSelector", "FireSelector")
	pv = Vector((X(905), Z(812)))
	tip = Vector((X(913), Z(833)))
	d = (tip - pv).normalized()
	nrm = Vector((-d.y, d.x))
	pts = []
	for i in range(5):
		a = math.atan2(nrm.y, nrm.x) + math.pi * i / 4
		pts.append(tuple(pv + Vector((math.cos(a), math.sin(a))) * 0.016))
	pts += [tuple(tip - nrm * 0.009), tuple(tip + d * 0.004), tuple(tip + nrm * 0.009)]
	sel.add(prism(pts, "Y", lw + 0.002, lw + 0.011, METAL), 0.003, 1)
	sel.add(drop(cyl_y(pv.x, pv.y, 0.01, lw + 0.009, lw + 0.015, 6, METAL), 1, -1), 0)

	return parts


CHARM = (X(664), 0.064 + 0.002 + 0.012, Z(822) - 0.049)

BONES = [
	# name, parent, head
	("Root", None, (0.0, 0.0, 0.15)),
	("Mag", "Root", (X(727), 0.0, Z(888))),
	("ChargingHandle", "Root", (X(676), 0.078, Z(778))),
	("Bolt", "Root", (X(808), -0.055, Z(784))),
	("Trigger", "Root", (X(842), 0.0, Z(850))),
	("FireSelector", "Root", (X(905), 0.07, Z(812))),
	("Flash", "Root", (X(160) + 0.01, 0.0, BORE_Z)),
	("Charm", "Root", CHARM),
]

LOCATORS = [
	# name, bone, position, rotation
	("Muzzle", "Root", (X(160), 0.0, BORE_Z), None),  # front of the suppressor
	("RightGrip", "Root", (0.0, 0.0, 0.0), None),
	("LeftGrip", "Root", (X(540), 0.0, Z(838)), None),
	("AimPoint", "Root", (X(894), 0.0, SIGHT_Z), gunkit.AIM_ROT),
	("Eject", "Root", (X(808), -0.068, Z(784)), gunkit.EJECT_ROT),
	("CharmPoint", "Charm", CHARM, None),
]


def build():
	mats = gunkit.begin(GUN)
	parts = build_parts(mats)
	return gunkit.assemble(
		GUN,
		parts,
		mats,
		BONES,
		LOCATORS,
		{"class": "Assault rifle", "tier": "T3", "template_version": 2, "length_rel": 0.92, "att_positions": "{}", "pbr": True},
	)


if __name__ == "__main__":
	print(build())
