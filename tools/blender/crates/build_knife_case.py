"""The Knife case (vault/01 Design/Inventory and Crates.md -> Knife case), from the owner's pick:
concept A "slim tactical blade case", model sheet art-source/ui/shop/crates/knife_case_sheet.png.
The big crate's little sibling: same family (straps, back hinges, front latches, a light strip, a
notched lid plate with a gem) but about half as long and low, the handle on the front between the
latches, a foam tray with a knife cutout inside.

Same part names, groups and pivots as build_crate.py, so tools/studio/BuildCrate.luau rigs it and
Util/CaseOpening plays it unchanged. It reuses build_crate.py's faceted helpers.

Run (background is fine, it only writes its own .blend):
    blender -b --factory-startup --python tools/blender/crates/build_knife_case.py
Env: KNIFE_EXPORT=1 writes art-source/lobby/Exports/KnifeCase.fbx; KNIFE_PREVIEW=<dir> renders
closed / open / front / top / side previews there; KNIFE_ART=1 renders the UI pictures (crop them
with a 10 px border: crate_knife.png -> shop/crates/crate_knife_wide.png, card_raw -> card).

Units: 1 unit = 1 stud. X = length, -Y = front, Z = up, origin = floor centre.
Style (gauntlet-build-style): faceted only, flat 1-segment chamfers, 6/8-sided bars, cut ends.
"""
import json
import math
import os

import bmesh
import bpy
from mathutils import Vector

ROOT = r"C:\Users\charl\Documents\GauntletGame\GlitchedGauntletGame"
HERE = os.path.join(ROOT, "tools", "blender", "crates")
BLEND = os.path.join(ROOT, "art-source", "lobby", "crates", "KnifeCase.blend")
OUT_JSON = os.path.join(ROOT, "art-source", "lobby", "crates", "KnifeCase.json")
FBX = os.path.join(ROOT, "art-source", "lobby", "Exports", "KnifeCase.fbx")

# the crate's helpers (mat, prism, loft, cham_rect, ngon, add, bar, bolt, boolean_cut, PIECES)
_ns = {"__name__": "crate_helpers"}
_src = open(os.path.join(HERE, "build_crate.py"), encoding="utf-8").read()
exec(_src.split("# ---------------------------------------------------------------- the crate")[0], _ns)
mat, prism, loft, cham_rect, ngon = _ns["mat"], _ns["prism"], _ns["loft"], _ns["cham_rect"], _ns["ngon"]
add, bar, bolt, boolean_cut, PIECES = _ns["add"], _ns["bar"], _ns["bolt"], _ns["boolean_cut"], _ns["PIECES"]
# knife-case preview colours (Studio paints the real ones: Config/Crates tier 4)
_ns["ROLES"].update({
	"Body": (0x26, 0x40, 0x2A),
	"Frame": (0x17, 0x2A, 0x1B),
	"Hardware": (0xC5, 0xCA, 0xD0),
	"Light": (0x5B, 0xE3, 0x5A),
	"Gem": (0x4F, 0xD2, 0x4E),
	"Interior": (0x14, 0x16, 0x18),
})

# ---------------------------------------------------------------- dimensions
HX, HY = 0.80, 0.27  # half length / half depth (sheet: about 2.7 : 1)
CUT = 0.07  # corner cut of the footprint
BASE_Z0, SEAM = 0.06, 0.31
GAP = 0.012
LID_Z0, LID_Z1 = SEAM + GAP, 0.47
LID_CHAM = 0.05
WALL = 0.045
STRAP_X, STRAP_W, STRAP_T = 0.60, 0.12, 0.03
LATCH_X = 0.33
PANEL_X = 0.46
HANDLE_X = 0.20
HINGE_X = STRAP_X  # the hinges sit on the straps (sheet back view)
O = HY + STRAP_T  # strap outer face

HINGE = Vector((0.0, O + 0.03, SEAM + GAP / 2))
LATCH_PIVOT_YZ = (-(HY + 0.045), 0.19)
HANDLE_PIVOT_YZ = (-(HY + 0.05), 0.16)
GEM_C = Vector((0.0, 0.0, LID_Z1 + 0.065))

COLL = "KNIFECASE"
FOOT = cham_rect(-HX, HX, -HY, HY, CUT)
INNER = cham_rect(-HX + WALL, HX - WALL, -HY + WALL, HY - WALL, CUT * 0.7)

# the foam cutout: a knife lying along X, handle left, tip right (sheet open view)
KNIFE = [
	(-0.56, -0.045), (-0.20, -0.045), (-0.20, -0.095), (-0.15, -0.095), (-0.15, -0.06), (0.40, -0.06),
	(0.56, 0.0), (0.50, 0.06), (-0.15, 0.06), (-0.15, 0.095), (-0.20, 0.095), (-0.20, 0.045), (-0.56, 0.045),
]


def build_base():
	g = "Base"
	body = prism(FOOT, "XY", BASE_Z0, SEAM, cham=0.02)
	body = boolean_cut(body, prism(INNER, "XY", BASE_Z0 + 0.05, SEAM + 0.2))
	add(g, "Body", body)
	# foam tray filling the base, with a knife-shaped cutout
	foam_o = cham_rect(-HX + WALL + 0.005, HX - WALL - 0.005, -HY + WALL + 0.005, HY - WALL - 0.005, CUT * 0.6)
	foam = prism(foam_o, "XY", BASE_Z0 + 0.05, SEAM - 0.035)
	foam = boolean_cut(foam, prism(KNIFE, "XY", SEAM - 0.11, SEAM))
	add(g, "Interior", foam)
	# inner rim lip
	rim_o = cham_rect(-HX + WALL * 0.45, HX - WALL * 0.45, -HY + WALL * 0.45, HY - WALL * 0.45, CUT * 0.85)
	rim = boolean_cut(prism(rim_o, "XY", SEAM - 0.05, SEAM + 0.03), prism(INNER, "XY", SEAM - 0.2, SEAM + 0.2))
	add(g, "Frame", rim)

	# front and back panels between the straps: raised chamfered rings
	for side in (-1, 1):
		y0 = side * HY
		a0, a1 = sorted((y0, y0 + side * 0.02))
		ring = prism(cham_rect(-PANEL_X, PANEL_X, 0.10, 0.24, 0.035), "XZ", a0, a1, cham=0.008)
		ring = boolean_cut(ring, prism(cham_rect(-PANEL_X + 0.035, PANEL_X - 0.035, 0.13, 0.21, 0.025), "XZ", a0 - 0.1, a1 + 0.1))
		add(g, "Body", ring)
	# end panels (sheet side view): same ring on each end
	for sx in (-1, 1):
		x0 = sx * HX
		a0, a1 = sorted((x0, x0 + sx * 0.02))
		ring = prism(cham_rect(-0.16, 0.16, 0.10, 0.24, 0.03), "YZ", a0, a1, cham=0.008)
		ring = boolean_cut(ring, prism(cham_rect(-0.125, 0.125, 0.13, 0.21, 0.02), "YZ", a0 - 0.1, a1 + 0.1))
		add(g, "Body", ring)

	# glowing slot on the front, under the seam
	add(g, "Frame", prism(cham_rect(-0.11, 0.11, 0.252, 0.296, 0.015), "XZ", -HY - 0.02, -HY + 0.005, cham=0.006))
	add(g, "Light", prism(cham_rect(-0.08, 0.08, 0.265, 0.283, 0.008), "XZ", -HY - 0.026, -HY - 0.012))

	# straps: a U band per side round front, bottom and back, ending at the seam
	for sx in (-1, 1):
		x = sx * STRAP_X
		u = [(-O, 0.05), (O, 0.05), (O, SEAM - 0.012), (O - 0.012, SEAM), (HY, SEAM), (HY, BASE_Z0), (-HY, BASE_Z0), (-HY, SEAM), (-O + 0.012, SEAM), (-O, SEAM - 0.012)]
		add(g, "Frame", prism(u, "YZ", x - STRAP_W / 2, x + STRAP_W / 2, cham=0.008))
		for z in (0.13, 0.25):
			bolt(g, x, -O, z, "-Y", r=0.028, h=0.018)
		bolt(g, x, O, 0.13, "+Y", r=0.028, h=0.018)  # the hinge leaf covers the upper back spot
		# feet: flared wedges under each strap, front and back
		for side in (-1, 1):
			y0, y1 = sorted((side * 0.12, side * (HY + 0.05)))
			add(g, "Frame", prism(cham_rect(x - 0.10, x + 0.10, y0, y1, 0.025), "XY", 0.0, 0.065, cham=0.012, taper=(1.0, 0.86)))

	# latch keepers (the lever pivots on their knuckle)
	for sx in (-1, 1):
		x = sx * LATCH_X
		add(g, "Hardware", prism(cham_rect(x - 0.065, x + 0.065, 0.15, 0.30, 0.02), "XZ", -HY - 0.032, -HY + 0.003, cham=0.006))
		bar(g, "Hardware", (x - 0.06, LATCH_PIVOT_YZ[0], LATCH_PIVOT_YZ[1]), (x + 0.06, LATCH_PIVOT_YZ[0], LATCH_PIVOT_YZ[1]), 0.018)

	# front handle mounts
	for sx in (-1, 1):
		x = sx * HANDLE_X
		add(g, "Hardware", prism(cham_rect(x - 0.035, x + 0.035, 0.12, 0.20, 0.015), "XZ", -HY - 0.045, -HY + 0.003, cham=0.006))

	# back hinges on the straps: base leaf + middle knuckle (the lid carries the outer ones)
	for sx in (-1, 1):
		x = sx * HINGE_X
		add(g, "Hardware", prism(cham_rect(x - 0.07, x + 0.07, 0.20, SEAM - 0.004, 0.02), "XZ", O - 0.003, O + 0.02, cham=0.006))
		bar(g, "Hardware", (x - 0.025, HINGE.y, HINGE.z), (x + 0.025, HINGE.y, HINGE.z), 0.025)
		for dx in (-0.045, 0.045):
			bolt(g, x + dx, O + 0.02, 0.245, "+Y", r=0.018, h=0.012)


def build_lid():
	g = "Lid"
	top = cham_rect(-HX + LID_CHAM, HX - LID_CHAM, -HY + LID_CHAM, HY - LID_CHAM, CUT)
	lid = loft([(FOOT, LID_Z0), (FOOT, LID_Z1 - LID_CHAM), (top, LID_Z1)], cham=0.012)
	lid = boolean_cut(lid, prism(INNER, "XY", LID_Z0 - 0.2, LID_Z1 - 0.05))
	add(g, "Body", lid)
	add(g, "Interior", prism(cham_rect(-HX + WALL + 0.01, HX - WALL - 0.01, -HY + WALL + 0.01, HY - WALL - 0.01, 0.05), "XY", LID_Z1 - 0.062, LID_Z1 - 0.05))

	# raised lid plate: a long notched octagon between the straps
	a, b, c, d = 0.30, 0.34, 0.40, 0.44
	plate = [(-a, -0.14), (a, -0.14), (b, -0.10), (c, -0.10), (d, -0.05), (d, 0.05), (c, 0.10), (b, 0.10), (a, 0.14), (-a, 0.14), (-b, 0.10), (-c, 0.10), (-d, 0.05), (-d, -0.05), (-c, -0.10), (-b, -0.10)]
	add(g, "Body", prism(plate, "XY", LID_Z1 - 0.005, LID_Z1 + 0.03, cham=0.01))
	# gem mount: a diamond plate
	add(g, "Hardware", prism(ngon(0, 0, 0.115, 4), "XY", LID_Z1 + 0.025, LID_Z1 + 0.05, cham=0.01, taper=(1.0, 0.88)))

	# lid straps follow the chamfered top
	for sx in (-1, 1):
		x = sx * STRAP_X
		cc = LID_CHAM
		t = LID_Z1 + STRAP_T
		u = [(-O, LID_Z0), (-HY, LID_Z0), (-HY, LID_Z1 - cc), (-HY + cc, LID_Z1), (HY - cc, LID_Z1), (HY, LID_Z1 - cc), (HY, LID_Z0), (O, LID_Z0), (O, LID_Z1 - cc + 0.012), (HY - cc + 0.018, t), (-HY + cc - 0.018, t), (-O, LID_Z1 - cc + 0.012)]
		add(g, "Frame", prism(u, "YZ", x - STRAP_W / 2, x + STRAP_W / 2, cham=0.008))
		bolt(g, x, -O, 0.37, "-Y", r=0.028, h=0.018)
		for dy in (-0.12, 0.12):
			bolt(g, x, dy, t, "+Z", r=0.028, h=0.012)

	# latch catches on the lid front
	for sx in (-1, 1):
		x = sx * LATCH_X
		add(g, "Hardware", prism(cham_rect(x - 0.05, x + 0.05, LID_Z0 + 0.015, LID_Z0 + 0.06, 0.012), "XZ", -HY - 0.02, -HY + 0.003, cham=0.005))

	# lid hinge leaves and outer knuckles
	for sx in (-1, 1):
		x = sx * HINGE_X
		add(g, "Hardware", prism(cham_rect(x - 0.07, x + 0.07, LID_Z0 + 0.004, 0.41, 0.02), "XZ", O - 0.003, O + 0.02, cham=0.006))
		for dx in (-0.05, 0.05):
			bar(g, "Hardware", (x + dx - 0.025, HINGE.y, HINGE.z), (x + dx + 0.025, HINGE.y, HINGE.z), 0.025)


def build_gem():
	bm = bmesh.new()
	vs = []
	for r, dz in ((0.075, -0.015), (0.075, 0.0), (0.04, 0.035)):
		vs.append([bm.verts.new((GEM_C.x + x, GEM_C.y + y, GEM_C.z + dz)) for x, y in ngon(0, 0, r, 4)])
	bm.faces.new(vs[0])
	bm.faces.new(list(reversed(vs[-1])))
	for a, b in zip(vs, vs[1:]):
		for i in range(4):
			j = (i + 1) % 4
			bm.faces.new((a[i], a[j], b[j], b[i]))
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	bmesh.ops.bevel(bm, geom=list(bm.edges), offset=0.005, segments=1, affect="EDGES", clamp_overlap=True)
	add("Gem", "Gem", bm)


def build_latch(sx):
	g = "LatchL" if sx < 0 else "LatchR"
	x = sx * LATCH_X
	py, pz = LATCH_PIVOT_YZ
	bar(g, "Hardware", (x - 0.045, py, pz), (x + 0.045, py, pz), 0.022)
	top = LID_Z0 + 0.07
	lever = [(x - 0.06, pz), (x + 0.06, pz), (x + 0.07, pz + 0.035), (x + 0.07, pz + 0.10), (x + 0.05, top), (x - 0.05, top), (x - 0.07, pz + 0.10), (x - 0.07, pz + 0.035)]
	add(g, "Hardware", prism(lever, "XZ", -HY - 0.07, -HY - 0.04, cham=0.008))
	add(g, "Hardware", prism(cham_rect(x - 0.045, x + 0.045, LID_Z0 + 0.055, LID_Z0 + 0.08, 0.008), "XZ", -HY - 0.062, -HY - 0.02, cham=0.004))
	add(g, "Hardware", prism(cham_rect(x - 0.04, x + 0.04, pz - 0.045, pz - 0.012, 0.01), "XZ", -HY - 0.07, -HY - 0.05, cham=0.004))


def build_handle():
	g = "Handle"
	py, pz = HANDLE_PIVOT_YZ
	gy, gz = py - 0.07, pz - 0.08
	gx = HANDLE_X - 0.06
	bar(g, "Hardware", (-gx, gy, gz), (gx, gy, gz), 0.028, sides=8)
	for sx in (-1, 1):
		bar(g, "Hardware", (sx * HANDLE_X, py, pz), (sx * (gx + 0.005), gy, gz), 0.022)
		bar(g, "Hardware", (sx * (HANDLE_X - 0.03), py, pz), (sx * (HANDLE_X + 0.03), py, pz), 0.03)


PIVOTS = {
	"Lid": (HINGE.x, HINGE.y, HINGE.z),
	"LatchL": (-LATCH_X, LATCH_PIVOT_YZ[0], LATCH_PIVOT_YZ[1]),
	"LatchR": (LATCH_X, LATCH_PIVOT_YZ[0], LATCH_PIVOT_YZ[1]),
	"Handle": (0.0, HANDLE_PIVOT_YZ[0], HANDLE_PIVOT_YZ[1]),
	"Gem": (GEM_C.x, GEM_C.y, GEM_C.z),
	"Base": (0.0, 0.0, 0.0),
}


def build():
	PIECES.clear()
	for o in list(bpy.data.objects):  # factory scene: cube, light, camera
		if o.name in ("Cube", "Light", "Camera"):
			bpy.data.objects.remove(o)
	coll = bpy.data.collections.get(COLL)
	if coll:
		for o in list(coll.objects):
			bpy.data.objects.remove(o)
	else:
		coll = bpy.data.collections.new(COLL)
		bpy.context.scene.collection.children.link(coll)

	build_base()
	build_lid()
	build_gem()
	build_latch(-1)
	build_latch(1)
	build_handle()

	merged = {}
	for g, role, bm in PIECES:
		key = (g, role)
		if key not in merged:
			merged[key] = bmesh.new()
		me = bpy.data.meshes.new("_tmp")
		bm.to_mesh(me)
		merged[key].from_mesh(me)
		bpy.data.meshes.remove(me)
		bm.free()

	info = {"parts": {}, "pivots": PIVOTS, "units": "studs", "axes": "blender X=length, -Y=front, Z=up"}
	tris = 0
	for (g, role), bm in merged.items():
		name = f"{g}_{role}"
		bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
		bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4])
		px, py, pz = PIVOTS[g]
		bmesh.ops.translate(bm, vec=(-px, -py, -pz), verts=bm.verts)
		me = bpy.data.meshes.new(name)
		bm.to_mesh(me)
		bm.free()
		for p in me.polygons:
			p.use_smooth = False
		me.materials.append(mat(role))
		ob = bpy.data.objects.new(name, me)
		ob.location = (px, py, pz)
		ob["group"], ob["role"] = g, role
		coll.objects.link(ob)
		bb = [ob.matrix_world @ Vector(c) for c in ob.bound_box]
		lo = Vector((min(v.x for v in bb), min(v.y for v in bb), min(v.z for v in bb)))
		hi = Vector((max(v.x for v in bb), max(v.y for v in bb), max(v.z for v in bb)))
		t = sum(len(p.vertices) - 2 for p in me.polygons)
		tris += t
		info["parts"][name] = {"group": g, "role": role, "min": list(lo), "max": list(hi), "tris": t}
	info["tris"] = tris
	with open(OUT_JSON, "w") as f:
		json.dump(info, f, indent=1)
	return info


def pose(open_t):
	"""0 = closed, 1 = open (Blender: the lid opens with a negative X angle)."""
	for ob in bpy.data.collections[COLL].objects:
		g = ob["group"]
		a = {"Lid": -105, "LatchL": -130, "LatchR": -130, "Handle": -45}.get(g, 0) * open_t
		ob.rotation_euler = (math.radians(a), 0, 0)
		if g == "Gem":  # rides on the lid
			lid_pivot = Vector(PIVOTS["Lid"])
			rel = Vector(PIVOTS["Gem"]) - lid_pivot
			rel.rotate(__import__("mathutils").Euler((math.radians(-105 * open_t), 0, 0)))
			ob.location = lid_pivot + rel
			ob.rotation_euler = (math.radians(-105 * open_t), 0, 0)


def previews(out):
	os.makedirs(out, exist_ok=True)
	sc = bpy.context.scene
	sc.render.engine = "BLENDER_EEVEE"
	sc.render.resolution_x, sc.render.resolution_y = 1400, 800
	sc.view_settings.view_transform = "Standard"
	w = bpy.data.worlds.get("KnifeWorld") or bpy.data.worlds.new("KnifeWorld")
	w.use_nodes = True
	w.node_tree.nodes["Background"].inputs[0].default_value = (0.045, 0.045, 0.05, 1)
	sc.world = w
	for name, loc, energy, size in (("Key", (-2, -2.6, 3), 110, 2), ("Fill", (2.6, -1.6, 1.6), 35, 2.5), ("Rim", (1, 3, 2.6), 80, 1.6)):
		lt = bpy.data.objects.get("Knife" + name) or bpy.data.objects.new("Knife" + name, bpy.data.lights.new("Knife" + name, "AREA"))
		if lt.name not in sc.collection.objects:
			sc.collection.objects.link(lt)
		lt.location = loc
		lt.data.energy, lt.data.size = energy, size
		lt.rotation_euler = (Vector((0, 0, 0.25)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
	cam = bpy.data.objects.get("KnifeCam") or bpy.data.objects.new("KnifeCam", bpy.data.cameras.new("KnifeCam"))
	if cam.name not in sc.collection.objects:
		sc.collection.objects.link(cam)
	sc.camera = cam
	shots = {
		"three_quarter": ((-1.65, -2.4, 1.5), (0, 0, 0.26), 32, 0),
		"open": ((-1.65, -2.4, 1.9), (0, 0.15, 0.35), 30, 1),
		"front": ((0, -5, 0.3), (0, 0, 0.3), 50, 0),
		"top": ((0, 0, 5), (0, 0, 0.3), 50, 0),
		"side": ((5, 0, 0.3), (0, 0, 0.3), 50, 0),
		"back": ((1.65, 2.4, 1.4), (0, 0, 0.26), 32, 0),
	}
	paths = []
	for name, (loc, tgt, lens, op) in shots.items():
		pose(op)
		cam.location = loc
		cam.rotation_euler = (Vector(tgt) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
		cam.data.lens = lens
		sc.render.filepath = os.path.join(out, f"knife_{name}.png")
		bpy.ops.render.render(write_still=True)
		paths.append(sc.render.filepath)
	pose(0)
	return paths


def srgb(h):
	c = [int(h[i : i + 2], 16) / 255 for i in (0, 2, 4)]
	return tuple(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c) + (1.0,)


def art():
	"""The UI pictures, like render_icons.py / render_cards.py do for the big crate (same views,
	the same lights scaled to this size, Config/Crates tier 4 colours). Raw renders: the caller
	crops them (art-source/ui/backpack/crate_knife.png -> crate_knife_wide.png, card)."""
	sc = bpy.context.scene
	sc.render.engine = "BLENDER_EEVEE"
	sc.render.film_transparent = True
	sc.render.image_settings.file_format = "PNG"
	sc.render.image_settings.color_mode = "RGBA"
	sc.view_settings.view_transform = "Standard"
	w = bpy.data.worlds.get("KnifeWorld") or bpy.data.worlds.new("KnifeWorld")
	w.use_nodes = True
	w.node_tree.nodes["Background"].inputs[0].default_value = (0.045, 0.045, 0.05, 1)
	w.node_tree.nodes["Background"].inputs[1].default_value = 1.0
	sc.world = w
	k = 0.53  # this case is 1.64 long, the crate 3.1
	tgt = Vector((0, 0, 0.5 * k))
	for name, loc, energy, size in (("Key", (-4, -5, 6), 420, 4), ("Fill", (5, -3, 3), 120, 5), ("Rim", (2, 6, 5), 300, 3)):
		lt = bpy.data.objects.get("Knife" + name) or bpy.data.objects.new("Knife" + name, bpy.data.lights.new("Knife" + name, "AREA"))
		if lt.name not in sc.collection.objects:
			sc.collection.objects.link(lt)
		lt.location = Vector(loc) * k
		lt.data.energy, lt.data.size = energy * k * k, size * k
		lt.rotation_euler = (tgt - lt.location).to_track_quat("-Z", "Y").to_euler()
	roles = {"Body": "26402A", "Frame": "172A1B", "Hardware": "C5CAD0", "Light": "5BE35A", "Gem": "4FD24E", "Interior": "0F1A11"}
	for role, hexv in roles.items():
		m = bpy.data.materials.get("Crate_" + role)
		col = srgb(hexv)
		m.diffuse_color = col
		bsdf = m.node_tree.nodes.get("Principled BSDF")
		bsdf.inputs["Base Color"].default_value = col
		if role in ("Light", "Gem"):
			bsdf.inputs["Emission Color"].default_value = col
			bsdf.inputs["Emission Strength"].default_value = 3.0
		elif role == "Hardware":
			bsdf.inputs["Metallic"].default_value = 0.35
			bsdf.inputs["Roughness"].default_value = 0.45
	cam = bpy.data.objects.get("KnifeCam") or bpy.data.objects.new("KnifeCam", bpy.data.cameras.new("KnifeCam"))
	if cam.name not in sc.collection.objects:
		sc.collection.objects.link(cam)
	sc.camera = cam
	cam.data.type = "PERSP"
	pose(0)
	out = []
	# (file, camera from, target, lens, resolution): render_icons.py's 3/4 view, render_cards.py's end-on view
	for path, loc, t, lens, res in (
		(os.path.join(ROOT, "art-source", "ui", "backpack", "crate_knife.png"), (-2.9, -4.4, 2.9), (-0.12, 0, 0.42), 50, 512),
		(os.path.join(ROOT, "art-source", "ui", "shop", "crates", "crate_knife_card_raw.png"), (-5.0, -3.3, 3.9), (-0.05, 0, 0.45), 55, 640),
	):
		t = Vector(t) * k
		cam.location = Vector(loc) * k
		cam.rotation_euler = (t - cam.location).to_track_quat("-Z", "Y").to_euler()
		cam.data.lens = lens
		sc.render.resolution_x = sc.render.resolution_y = res
		sc.render.filepath = path
		bpy.ops.render.render(write_still=True)
		out.append(path)
	return out


info = build()
result = {"parts": len(info["parts"]), "tris": info["tris"]}
if os.environ.get("KNIFE_PREVIEW"):
	result["previews"] = previews(os.environ["KNIFE_PREVIEW"])
if os.environ.get("KNIFE_EXPORT"):
	pose(0)
	bpy.ops.object.select_all(action="DESELECT")
	for ob in bpy.data.collections[COLL].objects:
		ob.select_set(True)
	bpy.ops.export_scene.fbx(filepath=FBX, use_selection=True, object_types={"MESH"}, apply_scale_options="FBX_SCALE_UNITS", use_mesh_modifiers=True, bake_anim=False)
	result["fbx"] = FBX
if os.environ.get("KNIFE_ART"):
	result["art"] = art()
bpy.ops.wm.save_as_mainfile(filepath=BLEND)
print("KNIFE_RESULT", json.dumps(result))
