"""The SURGE power case (vault/01 Design/Loadout and Power Deck.md -> Power cases; owner 2026-11-26: theme
"Surge", a compact chest, the same opening as the skin cases). Electric power: charcoal body, gold accent, a
faceted energy core under a hex bezel on the lid, gold surge lines cut into the lid plate, a lightning-bolt
light in a front bezel, faceted corner guards that wrap the clipped corners.

Same part names, groups and pivots as build_crate.py (Base, Lid hinged at the back, LatchL / LatchR, Handle,
Gem; colour roles Body, Frame, Hardware, Light, Gem, Interior), so tools/studio/BuildCrate.luau rigs it and
Util/CaseOpening plays it unchanged. It reuses build_crate.py's faceted helpers.

Run in a live Blender (its own instance: tools/blender/start_bridge.py, then)
    python tools/blender/lobby_v4/send.py tools/blender/crates/build_power_case.py --port 9877 --pid <pid>
Env (or set the globals below before exec): POWER_PREVIEW=<dir> renders previews; POWER_EXPORT=1 writes the FBX.

Units: 1 unit = 1 stud. X = length, -Y = front, Z = up, origin = floor centre.
Style (gauntlet-build-style): faceted only, flat 1-segment chamfers, 6/8-sided bars, cut ends, no curves.
"""
import json
import math
import os

import bmesh
import bpy
from mathutils import Euler, Vector

ROOT = r"C:\Users\charl\Documents\GauntletGame\GlitchedGauntletGame"
HERE = os.path.join(ROOT, "tools", "blender", "crates")
BLEND = os.path.join(ROOT, "art-source", "lobby", "crates", "PowerCase.blend")
OUT_JSON = os.path.join(ROOT, "art-source", "lobby", "crates", "PowerCase.json")
FBX = os.path.join(ROOT, "art-source", "lobby", "Exports", "PowerCase.fbx")

# the crate's helpers (mat, prism, loft, cham_rect, ngon, add, bar, bolt, boolean_cut, PIECES)
_ns = {"__name__": "crate_helpers"}
_src = open(os.path.join(HERE, "build_crate.py"), encoding="utf-8").read()
exec(_src.split("# ---------------------------------------------------------------- the crate")[0], _ns)
mat, prism, loft, cham_rect, ngon = _ns["mat"], _ns["prism"], _ns["loft"], _ns["cham_rect"], _ns["ngon"]
add, bar, bolt, boolean_cut, PIECES = _ns["add"], _ns["bar"], _ns["bolt"], _ns["boolean_cut"], _ns["PIECES"]
SURGE = {
	"Body": "41444C",  # charcoal (a step lighter than the guards so they read)
	"Frame": "18191D",  # graphite guards and bezels
	"Hardware": "9DA2A9",  # gunmetal steel
	"Light": "FFC83D",  # gold surge
	"Gem": "FFD95A",  # the core
	"Interior": "141518",
}
_ns["ROLES"].update({k: tuple(int(v[i : i + 2], 16) for i in (0, 2, 4)) for k, v in SURGE.items()})

# ---------------------------------------------------------------- dimensions
HX, HY = 1.00, 0.68  # half length / half depth: a compact chest (2.0 x 1.36)
CUT = 0.15  # corner cut of the footprint
BASE_Z0, SEAM = 0.12, 0.70
GAP = 0.02
LID_Z0, LID_Z1 = SEAM + GAP, 1.10
LID_CHAM = 0.16  # the lid's big faceted shoulder
WALL = 0.09
GUARD_T = 0.055  # how far the corner guards stand proud
LATCH_X = 0.64
HINGE_X = 0.58
HANDLE_X = 0.26

HINGE = Vector((0.0, HY + 0.05, SEAM + GAP / 2))
LATCH_PIVOT_YZ = (-(HY + 0.055), SEAM - 0.25)
HANDLE_PIVOT_YZ = (-(HY + 0.065), 0.25)
GEM_C = Vector((0.0, 0.0, LID_Z1 + 0.16))

COLL = "POWERCASE"
FOOT = cham_rect(-HX, HX, -HY, HY, CUT)
INNER = cham_rect(-HX + WALL, HX - WALL, -HY + WALL, HY - WALL, CUT * 0.7)


def corner_guard(sx, sy, z0, z1, g):
	"""A guard that wraps one clipped corner: an angled plate on the cut face plus a short return on each side,
	seated 0.03 into the body and GUARD_T proud of it, its ends cut back."""
	t = GUARD_T
	ret = 0.20  # how far it runs along each side
	# corner in the +x,+y quadrant, then mirrored
	pts = [
		(HX - CUT - ret, HY - 0.03),
		(HX - CUT - ret, HY + t * 0.6),
		(HX - CUT - ret + 0.05, HY + t),
		(HX - CUT + 0.02, HY + t),
		(HX + t, HY - CUT + 0.02),
		(HX + t, HY - CUT - ret + 0.05),
		(HX + t * 0.6, HY - CUT - ret),
		(HX - 0.03, HY - CUT - ret),
		(HX - CUT * 0.5 - 0.03, HY - CUT * 0.5 - 0.03),
	]
	pts = [(x * sx, y * sy) for x, y in pts]
	add(g, "Frame", prism(pts, "XY", z0, z1, cham=0.018))


def bolt_shape(cx, cz, h, w):
	"""A lightning bolt in the XZ plane (u = x, v = z), centred on (cx, cz), h tall."""
	s = h / 1.0
	pts = [(0.10, 0.50), (-0.18, 0.02), (-0.02, 0.02), (-0.12, -0.50), (0.18, -0.04), (0.02, -0.04)]
	return [(cx + x * s * w, cz + z * s) for x, z in pts]


def build_base():
	g = "Base"
	body = prism(FOOT, "XY", BASE_Z0, SEAM, cham=0.04)
	body = boolean_cut(body, prism(INNER, "XY", BASE_Z0 + 0.10, SEAM + 0.2))
	add(g, "Body", body)
	add(g, "Interior", prism(cham_rect(-HX + WALL + 0.02, HX - WALL - 0.02, -HY + WALL + 0.02, HY - WALL - 0.02, 0.08), "XY", BASE_Z0 + 0.10, BASE_Z0 + 0.12))
	# inner rim that closes the seam
	rim_o = cham_rect(-HX + WALL * 0.45, HX - WALL * 0.45, -HY + WALL * 0.45, HY - WALL * 0.45, CUT * 0.85)
	rim = prism(rim_o, "XY", SEAM - 0.08, SEAM + 0.05)
	rim = boolean_cut(rim, prism(INNER, "XY", SEAM - 0.2, SEAM + 0.2))
	add(g, "Frame", rim)
	# a skirt band round the foot: the body steps out at the bottom (a plinth, not a box on the floor)
	skirt = prism(cham_rect(-HX - 0.03, HX + 0.03, -HY - 0.03, HY + 0.03, CUT + 0.01), "XY", BASE_Z0, BASE_Z0 + 0.09, cham=0.02, taper=(1.0, 0.985))
	skirt = boolean_cut(skirt, prism(cham_rect(-HX + 0.05, HX - 0.05, -HY + 0.05, HY - 0.05, CUT), "XY", BASE_Z0 - 0.1, BASE_Z0 + 0.2))
	add(g, "Frame", skirt)

	# corner guards on the base, feet under them
	for sx in (-1, 1):
		for sy in (-1, 1):
			corner_guard(sx, sy, BASE_Z0 - 0.005, SEAM - 0.04, g)
			fx, fy = sx * (HX - CUT * 0.5), sy * (HY - CUT * 0.5)
			add(g, "Frame", prism(ngon(fx, fy, 0.17, 8, math.pi / 8), "XY", -0.0, BASE_Z0 + 0.01, cham=0.02, taper=(0.82, 1.0)))

	# front: a hexagon bezel round a lightning-bolt light, the handle mounts below it
	bez_c = (0.0, 0.50)
	hex_o = [(bez_c[0] + x, bez_c[1] + z) for x, z in ngon(0, 0, 0.21, 6, math.pi / 6)]
	hex_i = [(bez_c[0] + x, bez_c[1] + z) for x, z in ngon(0, 0, 0.155, 6, math.pi / 6)]
	bezel = prism(hex_o, "XZ", -HY - 0.05, -HY + 0.02, cham=0.014)
	bezel = boolean_cut(bezel, prism(hex_i, "XZ", -HY - 0.2, -HY - 0.02))  # a recess, floor left at -HY - 0.02
	add(g, "Frame", bezel)
	add(g, "Light", prism(bolt_shape(bez_c[0], bez_c[1], 0.25, 1.5), "XZ", -HY - 0.035, -HY - 0.015))
	# side panels: a raised frame on each end, the fixed end handle in its recess
	for sx in (-1, 1):
		x0 = sx * HX
		a0, a1 = sorted((x0 - sx * 0.01, x0 + sx * 0.035))
		outer = cham_rect(-0.28, 0.28, 0.24, 0.58, 0.06)
		inner = cham_rect(-0.22, 0.22, 0.29, 0.53, 0.04)
		ring = prism(outer, "YZ", a0, a1, cham=0.012)
		ring = boolean_cut(ring, prism(inner, "YZ", a0 - 0.1, a1 + 0.1))
		add(g, "Body", ring)
		# fixed end handle: a faceted bar on two mount blocks
		for sy in (-1, 1):
			y = sy * 0.13
			b0, b1 = sorted((x0 - sx * 0.005, x0 + sx * 0.06))
			add(g, "Hardware", prism(cham_rect(y - 0.06, y + 0.06, 0.38, 0.50, 0.025), "YZ", b0, b1, cham=0.008))
			bar(g, "Hardware", (x0 + sx * 0.05, y, 0.44), (x0 + sx * 0.17, y * 0.9, 0.36), 0.038)
		bar(g, "Hardware", (x0 + sx * 0.17, -0.13, 0.36), (x0 + sx * 0.17, 0.13, 0.36), 0.045, sides=8)

	# latch keepers and knuckles
	for sx in (-1, 1):
		x = sx * LATCH_X
		add(g, "Hardware", prism(cham_rect(x - 0.11, x + 0.11, SEAM - 0.32, SEAM - 0.04, 0.035), "XZ", -HY - 0.043, -HY + 0.005, cham=0.008))
		bar(g, "Hardware", (x - 0.1, LATCH_PIVOT_YZ[0], LATCH_PIVOT_YZ[1]), (x + 0.1, LATCH_PIVOT_YZ[0], LATCH_PIVOT_YZ[1]), 0.03)

	# front handle mounts
	for sx in (-1, 1):
		x = sx * HANDLE_X
		add(g, "Hardware", prism(cham_rect(x - 0.06, x + 0.06, 0.19, 0.31, 0.025), "XZ", -HY - 0.06, -HY + 0.005, cham=0.008))

	# back hinges: base leaf + middle knuckle
	for sx in (-1, 1):
		x = sx * HINGE_X
		add(g, "Hardware", prism(cham_rect(x - 0.13, x + 0.13, SEAM - 0.20, SEAM - 0.005, 0.03), "XZ", HY - 0.005, HY + 0.03, cham=0.008))
		bar(g, "Hardware", (x - 0.045, HINGE.y, HINGE.z), (x + 0.045, HINGE.y, HINGE.z), 0.045)
		for dx in (-0.08, 0.08):
			bolt(g, x + dx, HY + 0.03, SEAM - 0.13, "+Y", r=0.03, h=0.02)


def build_lid():
	g = "Lid"
	c = LID_CHAM
	top = cham_rect(-HX + c, HX - c, -HY + c, HY - c, CUT * 0.8)
	lid = loft([(FOOT, LID_Z0), (FOOT, LID_Z1 - c), (top, LID_Z1)], cham=0.02)
	lid = boolean_cut(lid, prism(INNER, "XY", LID_Z0 - 0.2, LID_Z1 - 0.10))
	add(g, "Body", lid)
	add(g, "Interior", prism(cham_rect(-HX + WALL + 0.02, HX - WALL - 0.02, -HY + WALL + 0.02, HY - WALL - 0.02, 0.08), "XY", LID_Z1 - 0.12, LID_Z1 - 0.10))

	# lid corner guards (the vertical band only; the shoulder stays clean)
	for sx in (-1, 1):
		for sy in (-1, 1):
			corner_guard(sx, sy, LID_Z0 + 0.025, LID_Z1 - c - 0.01, g)

	# raised lid plate: a notched octagon, with the surge lines cut into it and filled with gold
	pz0, pz1 = LID_Z1 - 0.01, LID_Z1 + 0.05
	a, b = 0.62, 0.44
	plate_pts = [(-a, -b + 0.10), (-a + 0.10, -b), (a - 0.10, -b), (a, -b + 0.10), (a, b - 0.10), (a - 0.10, b), (-a + 0.10, b), (-a, b - 0.10)]
	plate = prism(plate_pts, "XY", pz0, pz1, cham=0.02)
	lines = []
	for sx in (-1, 1):
		# a zig-zag surge line from the core housing out toward each end
		pts = [(0.30, 0.04), (0.40, -0.06), (0.47, 0.05), (0.56, -0.03)]
		pts = [(x * sx, y) for x, y in pts]
		for p, q in zip(pts, pts[1:]):
			lines.append((p, q))
	for p, q in lines:
		d = Vector((q[0] - p[0], q[1] - p[1], 0))
		n = Vector((-d.y, d.x, 0)).normalized() * 0.022
		quad = [(p[0] - n.x, p[1] - n.y), (q[0] - n.x, q[1] - n.y), (q[0] + n.x, q[1] + n.y), (p[0] + n.x, p[1] + n.y)]
		groove = prism(quad, "XY", pz1 - 0.025, pz1 + 0.1)
		plate = boolean_cut(plate, groove)
		add(g, "Light", prism(quad, "XY", pz1 - 0.03, pz1 - 0.008))
	add(g, "Body", plate)

	# the core housing: a tapered hex block, a steel hex bezel ring on top (the gem sits in it)
	add(g, "Frame", prism(ngon(0, 0, 0.34, 6, 0), "XY", pz1 - 0.01, pz1 + 0.06, cham=0.02, taper=(1.0, 0.92)))
	ring = prism(ngon(0, 0, 0.27, 6, 0), "XY", pz1 + 0.05, pz1 + 0.12, cham=0.015, taper=(1.0, 0.94))
	ring = boolean_cut(ring, prism(ngon(0, 0, 0.19, 6, 0), "XY", pz1 + 0.08, pz1 + 0.3))
	add(g, "Hardware", ring)
	for i in range(6):
		ang = i * math.pi / 3  # on the ring's corners, where it is widest
		bolt(g, 0.222 * math.cos(ang), 0.222 * math.sin(ang), pz1 + 0.12, "+Z", r=0.018, h=0.012)

	# a surge strip on the lid front between the latches: a graphite bezel with a gold bar set in it
	add(g, "Frame", prism(cham_rect(-0.40, 0.40, LID_Z0 + 0.05, LID_Z0 + 0.14, 0.03), "XZ", -HY - 0.03, -HY + 0.01, cham=0.01))
	add(g, "Light", prism(cham_rect(-0.33, 0.33, LID_Z0 + 0.075, LID_Z0 + 0.115, 0.015), "XZ", -HY - 0.038, -HY - 0.02))

	# latch catches on the lid front
	for sx in (-1, 1):
		x = sx * LATCH_X
		add(g, "Hardware", prism(cham_rect(x - 0.08, x + 0.08, LID_Z0 + 0.03, LID_Z0 + 0.10, 0.02), "XZ", -HY - 0.035, -HY + 0.005, cham=0.008))

	# lid hinge leaves and outer knuckles
	for sx in (-1, 1):
		x = sx * HINGE_X
		add(g, "Hardware", prism(cham_rect(x - 0.13, x + 0.13, LID_Z0 + 0.005, LID_Z1 - c - 0.02, 0.03), "XZ", HY - 0.005, HY + 0.03, cham=0.008))
		for dx in (-0.1, 0.1):
			bar(g, "Hardware", (x + dx - 0.045, HINGE.y, HINGE.z), (x + dx + 0.045, HINGE.y, HINGE.z), 0.045)


def build_gem():
	"""The energy core: a cut crystal in the bezel. A hex pavilion, a girdle band, then a crown whose ring is
	turned 30 degrees (so its faces are triangles that catch the light) rising to a sharp tip."""
	bm = bmesh.new()
	c = GEM_C
	rings = [(0.06, -0.10, 0.0), (0.15, -0.03, 0.0), (0.15, 0.01, 0.0), (0.075, 0.12, math.pi / 6)]
	vs = []
	for r, dz, rot in rings:
		vs.append([bm.verts.new((c.x + x, c.y + y, c.z + dz)) for x, y in ngon(0, 0, r, 6, rot)])
	tip = bm.verts.new((c.x, c.y, c.z + 0.21))
	bm.faces.new(list(reversed(vs[0])))
	for a, b in zip(vs[:2], vs[1:3]):
		for i in range(6):
			j = (i + 1) % 6
			bm.faces.new((a[i], a[j], b[j], b[i]))
	# girdle -> turned crown ring: alternating triangles
	g, k = vs[2], vs[3]
	for i in range(6):
		j = (i + 1) % 6
		bm.faces.new((g[i], g[j], k[i]))
		bm.faces.new((g[j], k[j], k[i]))
	for i in range(6):
		bm.faces.new((k[i], k[(i + 1) % 6], tip))
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	add("Gem", "Gem", bm)


def build_latch(sx):
	g = "LatchL" if sx < 0 else "LatchR"
	x = sx * LATCH_X
	py, pz = LATCH_PIVOT_YZ
	bar(g, "Hardware", (x - 0.075, py, pz), (x + 0.075, py, pz), 0.04)
	lever = [(x - 0.10, pz), (x + 0.10, pz), (x + 0.115, pz + 0.06), (x + 0.115, pz + 0.17), (x + 0.085, LID_Z0 + 0.12), (x - 0.085, LID_Z0 + 0.12), (x - 0.115, pz + 0.17), (x - 0.115, pz + 0.06)]
	add(g, "Hardware", prism(lever, "XZ", -HY - 0.085, -HY - 0.04, cham=0.012))
	add(g, "Hardware", prism(cham_rect(x - 0.07, x + 0.07, LID_Z0 + 0.10, LID_Z0 + 0.14, 0.012), "XZ", -HY - 0.075, -HY - 0.035, cham=0.006))
	# a gold stripe down the lever: the case's accent on the moving parts
	add(g, "Light", prism(cham_rect(x - 0.025, x + 0.025, pz + 0.05, LID_Z0 + 0.06, 0.012), "XZ", -HY - 0.092, -HY - 0.08))
	add(g, "Hardware", prism(cham_rect(x - 0.06, x + 0.06, pz - 0.07, pz - 0.02, 0.015), "XZ", -HY - 0.085, -HY - 0.055, cham=0.006))


def build_handle():
	g = "Handle"
	py, pz = HANDLE_PIVOT_YZ
	gy, gz = py - 0.09, pz - 0.10  # hangs low and close, clear of the bolt bezel
	gx = HANDLE_X - 0.10
	bar(g, "Hardware", (-gx, gy, gz), (gx, gy, gz), 0.05, sides=8)
	for sx in (-1, 1):
		bar(g, "Hardware", (sx * HANDLE_X, py, pz), (sx * (gx + 0.01), gy, gz), 0.042)
		bar(g, "Hardware", (sx * (HANDLE_X - 0.05), py, pz), (sx * (HANDLE_X + 0.05), py, pz), 0.055)


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
	for o in list(bpy.data.objects):  # the startup scene's cube, light and camera
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
	os.makedirs(os.path.dirname(OUT_JSON), exist_ok=True)
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
			rel.rotate(Euler((math.radians(-105 * open_t), 0, 0)))
			ob.location = lid_pivot + rel
			ob.rotation_euler = (math.radians(-105 * open_t), 0, 0)


def srgb(h):
	c = [int(h[i : i + 2], 16) / 255 for i in (0, 2, 4)]
	return tuple(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c) + (1.0,)


def look():
	"""Preview materials: the Surge colours, emissive gold, a little metal on the steel."""
	for role, hexv in SURGE.items():
		m = mat(role)
		col = srgb(hexv)
		m.diffuse_color = col
		bsdf = m.node_tree.nodes.get("Principled BSDF")
		bsdf.inputs["Base Color"].default_value = col
		bsdf.inputs["Roughness"].default_value = 0.55
		if role in ("Light", "Gem"):
			bsdf.inputs["Emission Color"].default_value = col
			bsdf.inputs["Emission Strength"].default_value = 0.9 if role == "Gem" else 2.2  # the core keeps its facets readable
		elif role == "Hardware":
			bsdf.inputs["Metallic"].default_value = 0.35
			bsdf.inputs["Roughness"].default_value = 0.45


def previews(out):
	os.makedirs(out, exist_ok=True)
	sc = bpy.context.scene
	sc.render.engine = "BLENDER_EEVEE"
	sc.render.resolution_x, sc.render.resolution_y = 1400, 900
	sc.view_settings.view_transform = "Standard"
	sc.render.film_transparent = False
	w = bpy.data.worlds.get("PowerWorld") or bpy.data.worlds.new("PowerWorld")
	w.use_nodes = True
	w.node_tree.nodes["Background"].inputs[0].default_value = (0.05, 0.05, 0.055, 1)
	sc.world = w
	look()
	for name, loc, energy, size in (("Key", (-3, -3.6, 4.2), 260, 3), ("Fill", (3.6, -2.2, 2.2), 80, 3.5), ("Rim", (1.4, 4, 3.4), 200, 2.4)):
		lt = bpy.data.objects.get("Power" + name) or bpy.data.objects.new("Power" + name, bpy.data.lights.new("Power" + name, "AREA"))
		if lt.name not in sc.collection.objects:
			sc.collection.objects.link(lt)
		lt.location = loc
		lt.data.energy, lt.data.size = energy, size
		lt.rotation_euler = (Vector((0, 0, 0.5)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
	cam = bpy.data.objects.get("PowerCam") or bpy.data.objects.new("PowerCam", bpy.data.cameras.new("PowerCam"))
	if cam.name not in sc.collection.objects:
		sc.collection.objects.link(cam)
	sc.camera = cam
	shots = {
		"three_quarter": ((-2.6, -3.6, 2.5), (0, 0, 0.55), 38, 0),
		"open": ((-2.4, -3.4, 3.0), (0, 0.2, 0.7), 34, 1),
		"front": ((0, -6.5, 0.7), (0, 0, 0.62), 50, 0),
		"top": ((0, -0.01, 6.5), (0, 0, 0.6), 50, 0),
		"side": ((6.5, 0, 0.7), (0, 0, 0.62), 50, 0),
		"back": ((2.6, 3.6, 2.3), (0, 0, 0.55), 38, 0),
		"close_lid": ((-0.9, -1.5, 2.3), (0, 0, 1.2), 50, 0),
		"close_front": ((-0.6, -2.2, 0.75), (0.1, -0.68, 0.5), 50, 0),
	}
	paths = []
	for name, (loc, tgt, lens, op) in shots.items():
		pose(op)
		cam.location = loc
		cam.rotation_euler = (Vector(tgt) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
		cam.data.lens = lens
		sc.render.filepath = os.path.join(out, f"power_{name}.png")
		bpy.ops.render.render(write_still=True)
		paths.append(sc.render.filepath)
	pose(0)
	return paths


info = build()
result = {"parts": len(info["parts"]), "tris": info["tris"]}
_preview = globals().get("POWER_PREVIEW") or os.environ.get("POWER_PREVIEW")
if _preview:
	result["previews"] = previews(_preview)
if globals().get("POWER_EXPORT") or os.environ.get("POWER_EXPORT"):
	pose(0)
	bpy.ops.object.select_all(action="DESELECT")
	for ob in bpy.data.collections[COLL].objects:
		ob.select_set(True)
	bpy.ops.export_scene.fbx(filepath=FBX, use_selection=True, object_types={"MESH"}, apply_scale_options="FBX_SCALE_UNITS", use_mesh_modifiers=True, bake_anim=False)
	result["fbx"] = FBX
bpy.ops.wm.save_as_mainfile(filepath=BLEND)
