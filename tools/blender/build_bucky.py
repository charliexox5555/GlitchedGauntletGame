# build_bucky.py: builds the Bucky (06, long pump-action shotgun) in the open Blender scene.
#
#   g = {"__name__": "build", "__file__": path}; exec(compile(open(path).read(), path, "exec"), g); g["build"]()
#
# Family conventions in tools/blender/gunkit.py. Traced from the side view of
# vault/02 Art/References/Gun-Image-Concepts/Roblox Pump-Action Shotgun Concept Sheet-6.png (P converts pixels).
# No ADS (shotgun): no AimPoint. The Pump (ribbed fore-end plus its action bars) slides back along the fixed
# magazine tube and carries LeftGrip, so the support hand rides it exactly; the Bolt shows through the right-side
# port and moves with the pump. "Shell" is a reusable loading prop (rests hidden inside the receiver at the loading
# port; ShellLoadPoint marks the port). New references beyond the family set: Shell (bone), ShellLoadPoint.

import bmesh, bpy, importlib, math, os, sys
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gunkit

importlib.reload(gunkit)
from gunkit import DARK, METAL, NEON, PANEL, Part, box, charm_loop, cut, cyl_x, cyl_y, drop, group, mirror_y, prism

GUN = "Bucky"

# Side view -> studs: muzzle (px 65) to buttpad (1326) = 3.78 studs. Grip centre at (1009, 888).
S = 0.003
OX, OY = 1009, 888


def X(px):
	return (OX - px) * S


def Z(py):
	return (OY - py) * S


def P(pts):
	return [(X(a), Z(b)) for a, b in pts]


BORE_Z = Z(765)
TUBE_Z = Z(816)
PORT = (760, 850)  # loading port under the receiver


def build_parts(mats):
	parts = {}

	def part(name, bone="Root"):
		parts[name] = Part(name, bone)
		return parts[name]

	rw = 0.066  # receiver half width

	# ---- Receiver (charcoal): angled side panel, neon pocket, ejection port (right), loading port (bottom)
	rec = part("Receiver")
	body = prism(P([(686, 751), (694, 748), (968, 748), (1012, 760), (1042, 768), (1042, 844), (1030, 844), (990, 841), (686, 841)]), "Y", -rw, rw)
	panel = mirror_y(prism(P([(692, 754), (905, 754), (952, 812), (692, 812)]), "Y", rw - 0.004, rw + 0.02))
	pocket = mirror_y(box(X(966), X(914), rw - 0.005, rw + 0.02, Z(821), Z(811)))
	port = box(X(862), X(760), -rw - 0.02, -rw + 0.024, Z(806), Z(770))
	loading = box(X(800), X(720), -0.035, 0.035, Z(850), Z(830))
	rec.add(cut(body, group(panel, pocket, port, loading), mats), 0)
	guard = prism(P([(832, 840), (949, 840), (949, 880), (938, 884), (855, 884), (832, 860)]), "Y", -0.026, 0.026, DARK)
	rec.add(cut(guard, prism(P([(866, 845), (934, 845), (934, 876), (872, 878), (866, 870)]), "Y", -0.06, 0.06), mats, DARK, bw=0.004, segs=1), 0)

	# ---- Barrel, magazine tube with its cap, barrel clamp
	bar = part("Barrel")
	barrel = cyl_x(X(690), X(65), 0.051, BORE_Z, 16)
	bar.add(cut(barrel, cyl_x(X(72), X(58), 0.034, BORE_Z, 16), mats, DARK, bw=0.006, segs=1), 0)
	bar.add(drop(cyl_x(X(690), X(100), 0.056, TUBE_Z, 16), 0, -1), 0.004, 1)
	bar.add(cyl_x(X(101), X(80), 0.06, TUBE_Z, 16, mat=DARK), 0.008, 2)  # tube cap (knurl comes from the bake's grain)
	clamp = prism(P([(162, 785), (193, 785), (193, 836), (162, 836)]), "Y", -0.064, 0.064, DARK)
	bar.add(clamp, 0.006, 1)

	# ---- Sights (black, tiny): front post with a blue insert, rear notch block
	si = part("Sights")
	si.add(prism(P([(98, 750), (100, 732), (108, 728), (138, 728), (145, 735), (145, 750)]), "Y", -0.024, 0.024, DARK), 0.003, 1)
	si.add(prism(P([(870, 750), (874, 734), (884, 728), (918, 728), (930, 736), (930, 750)]), "Y", -0.028, 0.028, DARK), 0.003, 1)

	# ---- Grip (black polymer)
	grip = part("Grip")
	g = prism(P([(955, 842), (1035, 840), (1080, 955), (1078, 975), (1010, 987), (995, 978), (985, 940), (965, 890)]), "Y", -0.05, 0.05, DARK)
	grip.add(cut(g, mirror_y(prism(P([(980, 870), (1028, 866), (1060, 955), (1012, 965)]), "Y", 0.046, 0.07)), mats, DARK, bw=0.01, segs=1), 0)

	# ---- Stock (black polymer, triangular window, slotted buttpad) on a buffer tube
	st = part("Stock")
	st.add(cyl_x(X(1092), X(1040), 0.075, Z(803), 16, mat=DARK), 0.006, 1)
	stock = prism(P([(1086, 778), (1095, 773), (1300, 773), (1300, 982), (1285, 982), (1150, 880), (1100, 840), (1086, 835)]), "Y", -0.058, 0.058, DARK)
	st.add(cut(stock, prism(P([(1170, 834), (1272, 834), (1272, 922)]), "Y", -0.1, 0.1), mats, DARK, bw=0.01), 0)
	pad = prism(P([(1296, 776), (1320, 780), (1326, 792), (1326, 972), (1320, 982), (1296, 984)]), "Y", -0.068, 0.068, DARK)
	slots = mirror_y(group(*[box(X(1318), X(1305), 0.06, 0.09, Z(y + 12), Z(y)) for y in range(820, 950, 22)]))
	st.add(cut(pad, slots, mats, DARK, bw=0.006, segs=1), 0)

	# ---- Pins (metal)
	pins = part("Pins")
	for px, py in ((701, 804), (974, 813)):
		pins.add(mirror_y(drop(cyl_y(X(px), Z(py), 0.012, rw - 0.002, rw + 0.006, 8), 1, -1)), 0)

	# ---- Neon: receiver bar (both sides), front sight insert (both sides)
	neon = part("Neon")
	neon.add(mirror_y(box(X(964), X(916), rw - 0.004, rw - 0.0008, Z(820), Z(812), NEON)), 0)
	neon.add(mirror_y(box(X(124), X(116), 0.024 - 0.002, 0.024 + 0.002, Z(746), Z(732), NEON)), 0)

	# ---- Charm (buddy) loop: left side of the receiver's front, above the tube
	charm = part("CharmLoop")
	lug, tor = charm_loop(X(712), Z(828), rw + 0.002)
	charm.add(lug, 0.004, 1)
	charm.add(tor, 0)

	# ---- Moving parts
	pump = part("Pump", "Pump")
	fore = prism(P([(311, 800), (325, 783), (582, 783), (596, 796), (596, 846), (582, 856), (325, 856), (311, 840)]), "Y", -0.072, 0.072, DARK)
	ribs = mirror_y(group(*[box(X(x + 7), X(x), 0.066, 0.1, Z(853), Z(786)) for x in range(350, 548, 18)]))
	pump.add(cut(fore, ribs, mats, DARK, bw=0.008, segs=1), 0)
	pump.add(mirror_y(box(X(692), X(594), 0.04, 0.052, Z(806), Z(796), METAL)), 0.002, 1)  # action bars

	bolt = part("Bolt", "Bolt")
	bolt.add(box(X(860), X(762), -rw + 0.004, -rw + 0.024, Z(804), Z(772), METAL), 0.002, 1)

	trig = part("Trigger", "Trigger")
	trig.add(prism(P([(918, 846), (931, 846), (937, 858), (937, 868), (931, 876), (924, 877), (927, 868), (925, 858)]), "Y", -0.01, 0.01, METAL), 0.003, 1)

	shell = part("Shell", "Shell")
	shell.add(cyl_x(X(PORT[0] + 30), X(PORT[0] - 40), 0.03, Z(PORT[1]) + 0.04, 10, mat=DARK), 0.003, 1)  # hull
	shell.add(cyl_x(X(PORT[0] + 36), X(PORT[0] + 28), 0.034, Z(PORT[1]) + 0.04, 10, mat=METAL), 0.002, 1)  # brass base

	return parts


CHARM = (X(712), 0.066 + 0.002 + 0.012, Z(828) - 0.049)

BONES = [
	("Root", None, (0.0, 0.0, 0.15)),
	("Pump", "Root", (X(453), 0.0, TUBE_Z)),
	("Bolt", "Root", (X(810), -0.05, Z(788))),
	("Trigger", "Root", (X(924), 0.0, Z(846))),
	("Shell", "Root", (X(PORT[0]), 0.0, Z(PORT[1]) + 0.04)),
	("Flash", "Root", (X(65) + 0.01, 0.0, BORE_Z)),
	("Charm", "Root", CHARM),
]

EJECT_RIGHT_UP = Vector((0, -0.8, 0.6)).to_track_quat("Z", "Y").to_matrix().to_4x4()

LOCATORS = [
	("Muzzle", "Root", (X(65), 0.0, BORE_Z), None),
	("RightGrip", "Root", (0.0, 0.0, 0.0), None),
	("LeftGrip", "Pump", (X(453), 0.0, Z(856)), None),  # on the pump: the support hand rides it
	("Eject", "Root", (X(810), -0.066, Z(788)), EJECT_RIGHT_UP),
	("ShellLoadPoint", "Root", (X(PORT[0]), 0.0, Z(PORT[1])), None),
	("CharmPoint", "Charm", CHARM, None),
]


def build():
	mats = gunkit.begin(GUN)
	parts = build_parts(mats)
	return gunkit.assemble(GUN, parts, mats, BONES, LOCATORS,
		{"class": "Shotgun", "tier": "T2", "template_version": 2, "length_rel": 0.97, "att_positions": "{}", "pbr": True})


if __name__ == "__main__":
	print(build())
