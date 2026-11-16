# build_classic_v2.py: RemasterV2 Classic (default sidearm), fresh rebuild from
# vault/02 Art/References/Gun-Image-Concepts/Classic Pistol Two-View Concept Sheet.png.
#
# Run ONLY through Blender MCP inside the visible interactive Blender session:
#   ns = {"__name__": "__main__"}; exec(compile(open(p).read(), p, "exec"), ns); result = ns["RESULT"]
# Builds into its own scene "Classic_RemasterV2_Review" (collection "Classic"); never touches other scenes,
# the original art-source/weapons/Classic.blend or GunTest.blend.
#
# Contract measured on the original Classic.blend (appended read-only into REF_Classic_Original):
#   +X muzzle, +Z up, +Y gun-left, 1 unit = 1 stud, origin at the grip. Slide rear -0.267 -> muzzle 1.0005
#   (1.27 studs). Bore z 0.3654. Bones Root/Slide/Barrel/Mag/Trigger/SlideCatch/MagRelease/Flash/Charm with the
#   original heads (Charm moved to the new eyelet). Locators Classic_Muzzle (Barrel), RightGrip, LeftGrip (0,0,-0.08),
#   Eject (Slide), CharmPoint (Charm); no AimPoint (Classic has no ADS: right mouse is a 3-pellet burst).
# Main change: thicker (slide half width 0.062 -> 0.07, frame 0.065 -> 0.072, grip 0.057 -> 0.066), a slide with
# designed chamfers, deep rear serrations, an open-top port showing the barrel hood, 3-dot sights (neon dots),
# a narrow trigger guard with a free trigger + safety tab, a ribbed mag release, an integral charm lug with a
# through hole, a two-tier base plate.

import bpy, bmesh, math, os, sys, importlib
from mathutils import Matrix, Vector

ROOT = r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/art-source/weapons/RemasterV2"
sys.path.insert(0, ROOT + "/_Library")
import v2kit as K  # noqa: E402
import ammo as AM  # noqa: E402

importlib.reload(K)
importlib.reload(AM)
from v2kit import BODY, PANEL, DARK, METAL, GRIP, ACCENT, NEON  # noqa: E402

GUN = "Classic"
PRE = GUN + "_"
SCENE = "Classic_RemasterV2_Review"

BORE = 0.3654
MUZZLE_X = 1.0005
SW = 0.070  # slide half width
FW = 0.072  # frame half width
GW = 0.066  # grip half width
S0, S1 = 0.284, 0.481  # slide bottom / top


def solid(side, sect, mat=BODY, edge=0.0):
	xs = [p[0] for p in side]
	a = K.prism(side, "Y", -0.5, 0.5, mat)
	b = K.prism(sect, "X", min(xs) - 0.05, max(xs) + 0.05, mat)
	out = K.intersect(a, b)
	return K.bevel(out, edge, 1, 50) if edge > 0 else out


def both(bm):
	return K.mirror_y(bm)


def head(x, z, y_surface, r=0.008, h=0.004, segs=6, side=1, mat=METAL):
	y0, y1 = (y_surface - 0.003, y_surface + h) if side > 0 else (-y_surface - h, -y_surface + 0.003)
	return K.drop(K.cyl_y(x, z, r, y0, y1, segs, mat, rot=0.0), 1, -side)


def build_parts():
	parts = {}

	def part(name, bone="Root"):
		parts[name] = K.Part(name, bone)
		return parts[name]

	# ================================================================ Slide (graphite coated steel)
	sl = part("Slide", "Slide")
	sn = part("SlideNeon", "Slide")
	slide = solid(K.chamfer([(-0.267, S0), (1.0, S0), (1.0, S1), (-0.267, S1)], [0, 0.012, 0.03, 0.018]),
		K.section(SW, S0, S1, 0.034, 0.006), BODY, 0.003)
	cut = []
	# Rear serrations: six deep slots, leaning forward a touch, both sides.
	for i in range(6):
		x = -0.215 + i * 0.026
		cut.append(both(K.prism([(x, 0.300), (x + 0.012, 0.300), (x + 0.018, 0.446), (x + 0.006, 0.446)], "Y", SW - 0.007, 0.2)))
	# Seam groove where the front section starts (sides).
	cut.append(both(K.box(0.705, 0.711, SW - 0.003, 0.2, 0.296, 0.446)))
	# Open-top ejection port (right side + top) showing the barrel hood.
	cut.append(K.prism(K.chamfer([(0.375, 0.352), (0.600, 0.352), (0.600, 0.60), (0.375, 0.60)], [0.01, 0.01, 0, 0]), "Y", -0.2, 0.028))
	# Muzzle bore and guide-rod hole in the front face.
	cut.append(K.cyl_x(0.96, 1.06, 0.031, 0.0, BORE, 12, DARK))
	cut.append(K.cyl_x(0.975, 1.06, 0.015, 0.0, 0.306, 8, DARK))
	# Sight groove along the top flat (from rear to front sight) and a recessed rear cover plate.
	cut.append(K.box(-0.14, 0.90, -0.006, 0.006, S1 - 0.003, 0.6))
	cut.append(K.prism(K.chamfer([(-0.042, 0.300), (0.042, 0.300), (0.042, 0.452), (-0.042, 0.452)], 0.01), "X", -0.4, -0.264))
	# Neon pocket (left, ahead of the serrations).
	cut.append(K.box(0.0, 0.095, SW - 0.005, 0.2, 0.296, 0.31))
	slide = K.cut(slide, K.group(*cut), DARK)
	sl.add(slide)
	sn.add(K.box(0.003, 0.092, SW - 0.0045, SW - 0.0015, 0.298, 0.308, NEON))
	# Front sight: post with a vertical rear face and a neon dot facing the shooter.
	sl.add(K.prism([(0.912, 0.474), (0.957, 0.474), (0.951, 0.516), (0.912, 0.516)], "Y", -0.011, 0.011, DARK), 0.002)
	sn.add(K.box(0.9102, 0.9125, -0.0055, 0.0055, 0.497, 0.508, NEON))
	# Rear sight: sloped-front block with a square notch and two dots.
	rear = K.prism([(-0.232, 0.474), (-0.148, 0.474), (-0.16, 0.522), (-0.224, 0.522)], "Y", -0.042, 0.042, DARK)
	rear = K.bevel(rear, 0.003, 1, 50)
	rear = K.cut(rear, K.box(-0.3, -0.1, -0.0125, 0.0125, 0.501, 0.6), DARK)
	sl.add(rear)
	sn.add(both(K.box(-0.2278, -0.2255, 0.0225, 0.0315, 0.504, 0.513, NEON)))  # v03: set into the sloped rear face (v02 stood 0.004 off it)

	# ================================================================ Barrel (own bone; Muzzle rides it)
	br = part("Barrel", "Barrel")
	barrel = K.cyl_x(0.62, 0.997, 0.027, 0.0, BORE, 12, METAL)
	barrel = K.cut(barrel, K.cyl_x(0.98, 1.02, 0.014, 0.0, BORE, 8, DARK), DARK)
	br.add(K.drop(barrel, 0, -1))
	hood = K.prism(K.chamfer([(0.37, 0.333), (0.625, 0.333), (0.625, 0.44), (0.37, 0.44)], [0, 0, 0.008, 0.008]), "Y", -0.031, 0.031, METAL)
	br.add(hood, 0.003)

	# ================================================================ Frame (dark polymer)
	fr = part("Frame")
	frame = solid(K.chamfer([(0.971, 0.287), (-0.285, 0.287), (-0.285, 0.242), (-0.262, 0.212), (-0.215, 0.185), (-0.16, 0.165), (0.58, 0.165), (0.60, 0.185), (0.94, 0.185), (0.971, 0.215)],
		[0, 0.008, 0, 0, 0, 0, 0, 0, 0, 0]), K.section(FW, 0.165, 0.287, 0.004, 0.012), DARK, 0.003)
	fcut = [
		both(K.box(0.64, 0.935, FW - 0.008, 0.2, 0.198, 0.214)),  # accessory rail grooves
		K.box(0.80, 0.826, -0.05, 0.05, 0.15, 0.193),  # rail cross slot (underside)
		both(K.box(0.236, 0.268, FW - 0.004, 0.2, 0.21, 0.242)),  # small control pocket
	]
	frame = K.cut(frame, K.group(*fcut), DARK)
	fr.add(frame)
	fr.add(K.box(0.24, 0.264, FW - 0.0045, FW - 0.0005, 0.214, 0.238, METAL))  # control button in its pocket (left)
	guard = K.prism([(0.248, 0.175), (0.248, 0.02), (0.27, 0.0), (0.53, 0.0), (0.562, 0.03), (0.582, 0.175)], "Y", -0.034, 0.034, DARK)
	guard = K.bevel(guard, 0.006, 1, 30)
	guard = K.cut(guard, K.prism(K.chamfer([(0.29, 0.2), (0.546, 0.2), (0.53, 0.032), (0.29, 0.032)], [0, 0, 0.012, 0.01]), "Y", -0.1, 0.1), DARK)
	fr.add(guard)

	# ================================================================ Grip (polymer with stippled panels)
	gr = part("Grip")
	gp = [(0.248, 0.175), (0.235, 0.09), (0.215, -0.02), (0.19, -0.13), (0.165, -0.24), (0.152, -0.296), (-0.255, -0.296), (-0.235, -0.15), (-0.20, 0.0), (-0.178, 0.085), (-0.206, 0.122), (-0.262, 0.146), (-0.284, 0.164), (-0.278, 0.176), (-0.158, 0.176)]  # v03: beavertail (concept)
	grip = K.bevel(K.prism(gp, "Y", -GW, GW, DARK), 0.012, 2)
	panel = K.prism(K.chamfer([(0.193, 0.075), (-0.143, 0.075), (-0.208, -0.245), (0.125, -0.245)], 0.02), "Y", GW - 0.004, 0.2)
	grip = K.cut(grip, both(panel), GRIP)
	# Magazine well: the grip is hollow from the bottom (seen when the magazine drops), with a chamfered mouth.
	well = K.prism([(0.166, 0.12), (-0.128, 0.12), (-0.232, -0.32), (0.136, -0.32)], "Y", -0.054, 0.054)
	mouth = K.intersect(K.prism([(0.176, -0.27), (-0.236, -0.27), (-0.25, -0.31), (0.152, -0.31)], "Y", -0.06, 0.06), K.prism(K.chamfer([(-0.06, -0.31), (0.06, -0.31), (0.06, -0.27), (-0.06, -0.27)], [0.0, 0.0, 0.0, 0.0]), "X", -0.4, 0.4))
	grip = K.cut(grip, K.group(well, mouth), DARK)
	gr.add(grip)

	# ================================================================ Fasteners
	pins = part("Pins")
	for s in (1, -1):
		pins.add(head(0.47, 0.25, FW, r=0.009, segs=8, side=s))  # takedown pin
		pins.add(head(0.40, 0.205, FW, r=0.007, segs=6, side=s))  # trigger pin

	# ================================================================ Charm lug (left, under the slide's rear; hole runs front-to-back)
	ch = part("CharmLoop")
	# A sideways tab with a vertical through-hole (the hook drops through it; the charm hangs clear of the frame),
	# carried by a base plate on the frame and a gusset underneath.
	tab = [(-0.236, 0.0), (-0.189, 0.0)] + [(-0.2125 + 0.0235 * math.cos(a), 0.094 + 0.0235 * math.sin(a)) for a in [i * math.pi / 5 for i in range(6)]]
	tab = [(x, y if y > 0 else FW - 0.002) for x, y in tab]
	tabbm = K.prism(tab, "Z", 0.214, 0.232, DARK)
	tabbm = K.bevel(tabbm, 0.003, 1, 50)
	tabbm = K.cut(tabbm, K.prism(K.circle(-0.2125, 0.094, 0.0085, 8), "Z", 0.1, 0.3, METAL), METAL)
	ch.add(tabbm)
	ch.add(K.prism(K.chamfer([(-0.25, 0.198), (-0.175, 0.198), (-0.175, 0.25), (-0.25, 0.25)], 0.008), "Y", FW - 0.002, FW + 0.004, DARK), 0.002)
	ch.add(K.prism([(FW + 0.002, 0.214), (0.092, 0.214), (FW + 0.002, 0.196)], "X", -0.218, -0.207, DARK))

	# ================================================================ Moving parts
	mg = part("Magazine", "Mag")
	body = K.prism([(0.16, 0.155), (-0.122, 0.155), (-0.222, -0.296), (0.13, -0.296)], "Y", -0.05, 0.05, METAL)
	mg.add(K.drop(body, 2, -1), 0.004)
	# Top round (seen with the magazine out).
	mg.add(AM.pistol_round(-0.075, 0.0, 0.172, scale=1.4))  # v02: brass-cased pistol round
	plate = solid(K.chamfer([(0.162, -0.298), (-0.26, -0.298), (-0.27, -0.33), (-0.256, -0.376), (0.152, -0.384), (0.178, -0.345)], [0.0, 0.0, 0.006, 0.01, 0.01, 0.006]),
		K.section(0.07, -0.39, -0.298, 0.006, 0.016), DARK, 0.003)
	plate = K.cut(plate, K.group(both(K.box(-0.3, 0.3, 0.066, 0.2, -0.318, -0.312)), both(K.box(-0.238, -0.176, 0.066, 0.2, -0.356, -0.343))), DARK)
	mg.add(plate)
	mn = part("MagNeon", "Mag")
	mn.add(both(K.box(-0.235, -0.179, 0.0655, 0.068, -0.354, -0.345, NEON)))

	tg = part("Trigger", "Trigger")
	tp = [(0.355, 0.17), (0.39, 0.17), (0.392, 0.135), (0.386, 0.10), (0.372, 0.072), (0.355, 0.06), (0.348, 0.066), (0.36, 0.09), (0.368, 0.115), (0.366, 0.14), (0.356, 0.152)]
	tg.add(K.prism(tp, "Y", -0.011, 0.011, METAL), 0.002)
	tg.add(K.prism([(0.386, 0.128), (0.395, 0.126), (0.384, 0.088), (0.375, 0.091)], "Y", -0.0035, 0.0035, ACCENT))  # safety tab

	sc = part("SlideCatch", "SlideCatch")
	sc.add(K.prism(K.chamfer([(0.285, 0.236), (0.432, 0.236), (0.432, 0.262), (0.298, 0.262)], 0.004), "Y", FW - 0.002, FW + 0.009, METAL), 0.002)
	sc.add(K.box(0.30, 0.31, FW + 0.008, FW + 0.0115, 0.24, 0.258, METAL))  # thumb ridge

	mr = part("MagRelease", "MagRelease")
	btn = K.prism(K.chamfer([(0.168, 0.04), (0.218, 0.04), (0.224, 0.098), (0.176, 0.098)], 0.006), "Y", GW - 0.006, GW + 0.011, ACCENT)
	btn = K.cut(btn, K.group(*[K.box(0.17, 0.25, GW + 0.008, 0.2, z, z + 0.006) for z in (0.054, 0.066, 0.078)]), ACCENT)
	mr.add(btn, 0.0)

	return parts


CHARM = (-0.2125, 0.094, 0.2235)
EJECT_RIGHT_UP = Vector((0.0, -0.8, 0.6)).to_track_quat("Z", "Y").to_matrix().to_4x4()

BONES = [
	("Root", None, (0.0, 0.0, 0.1)),
	("Slide", "Root", (0.377, 0.0, BORE)),
	("Barrel", "Root", (0.957, 0.0, BORE)),
	("Mag", "Root", (0.0145, 0.0, 0.145)),
	("Trigger", "Root", (0.3712, 0.0, 0.1595)),
	("SlideCatch", "Root", (0.3567, FW, 0.2494)),
	("MagRelease", "Root", (0.232, GW, 0.0696)),
	("Flash", "Root", (MUZZLE_X + 0.01, 0.0, BORE)),
	("Charm", "Root", CHARM),
]

LOCATORS = [
	("Muzzle", "Barrel", (MUZZLE_X, 0.0, BORE), None),
	("RightGrip", "Root", (0.0, 0.0, 0.0), None),
	("LeftGrip", "Root", (0.0, 0.0, -0.08), None),
	("Eject", "Slide", (0.493, -0.027, 0.4205), EJECT_RIGHT_UP),
	("CharmPoint", "Charm", CHARM, None),
	("Socket_Muzzle", "Barrel", (MUZZLE_X, 0.0, BORE), None),
	("Socket_Optic", "Slide", (0.25, 0.0, S1), None),
	("Socket_Under", "Root", (0.80, 0.0, 0.185), None),
]


def build():
	sc = K.new_scene(SCENE)
	win = bpy.context.window
	win.scene = sc
	if bpy.context.object and bpy.context.object.mode != "OBJECT":
		bpy.ops.object.mode_set(mode="OBJECT")
	col = bpy.data.collections.get(GUN)
	if col is not None:
		if not col.get(K.TAG):
			raise RuntimeError("collection Classic exists and is not ours")
		K.clear_collection(col)
	else:
		col = bpy.data.collections.new(GUN)
		col[K.TAG] = True
		sc.collection.children.link(col)
	col["weapon_name"] = GUN
	col["class"] = "Sidearm"
	col["tier"] = "T1"
	col["remaster"] = "RemasterV2 2026-11-07"

	scratch = bpy.data.collections.new("_rv2_scratch")
	sc.collection.children.link(scratch)
	mats = K.materials()
	K._SCRATCH["col"] = scratch
	K._SCRATCH["mats"] = mats
	try:
		parts = build_parts()
	finally:
		for o in list(scratch.objects):
			me = o.data
			bpy.data.objects.remove(o)
			if me and me.users == 0:
				bpy.data.meshes.remove(me)
		bpy.data.collections.remove(scratch)

	rig = K.build_rig(col, PRE, BONES)
	report = {}
	static = [pc for p in parts.values() if p.bone == "Root" for pc in p.pieces]
	report["_hidden_faces_removed"] = K.remove_hidden(static, static)
	for p in parts.values():
		me = K.finish_mesh(p.merged(), PRE + p.name, mats)
		ob = bpy.data.objects.new(PRE + p.name, me)
		col.objects.link(ob)
		wn = ob.modifiers.new("WeightedNormal", "WEIGHTED_NORMAL")
		wn.keep_sharp = True
		wn.weight = 60
		K.parent_to_bone(ob, rig, p.bone, Matrix.Identity(4))
		report[p.name] = K.tri_count(me)
	for name, bone, pos, rot in LOCATORS:
		e = bpy.data.objects.new(PRE + name, None)
		e.empty_display_type = "ARROWS" if rot is not None else "PLAIN_AXES"
		e.empty_display_size = 0.04
		col.objects.link(e)
		K.parent_to_bone(e, rig, bone, Matrix.Translation(pos) @ (rot if rot is not None else Matrix.Identity(4)))
	report["_total_tris"] = sum(v for k, v in report.items() if not k.startswith("_"))
	return report


RESULT = build()
