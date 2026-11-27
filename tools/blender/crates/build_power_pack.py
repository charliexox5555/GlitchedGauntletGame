"""The SURGE power pack (vault/01 Design/Loadout and Power Deck.md -> Power cases; owner 2026-11-26: "instead of a
case we will do like a card pack, and it rips open"). A faceted foil pouch: a pillow body stepped down in flat
facets from a front and back label plateau to a thin edge, gold crimped seals top and bottom (saw-tooth ends,
crimp ribs), a tear notch, and a front label plate that carries the art (a SurfaceGui in Studio).

Parts (one mesh each, named group_role like the crates):
    Body_Foil   the pouch (charcoal foil)          Body_Seal  the bottom crimp (gold)
    Body_Label  the front label plate (art)        Top_Seal   the top crimp: the strip that tears off
Code animates them (Util/PackOpening); the Top pivot is its right end, where the tear finishes.

Run in a live Blender (its own instance: tools/blender/start_bridge.py, then)
    python tools/blender/lobby_v4/send.py tools/blender/crates/build_power_pack.py --port 9877 --pid <pid>
Set PACK_PREVIEW = r"<dir>" / PACK_EXPORT = True / PACK_ART = True before the code for previews, the FBX, UI art.

Units: 1 unit = 1 stud. X = width, -Y = front, Z = up, origin = the pack's centre.
Style (gauntlet-build-style): faceted only, flat facets, no curves, no smoothing, cut and toothed ends.
"""
import json
import math
import os

import bmesh
import bpy
from mathutils import Quaternion, Vector

ROOT = r"C:\Users\charl\Documents\GauntletGame\GlitchedGauntletGame"
HERE = os.path.join(ROOT, "tools", "blender", "crates")
BLEND = os.path.join(ROOT, "art-source", "lobby", "crates", "PowerPack.blend")
OUT_JSON = os.path.join(ROOT, "art-source", "lobby", "crates", "PowerPack.json")
FBX = os.path.join(ROOT, "art-source", "lobby", "Exports", "PowerPack.fbx")

_ns = {"__name__": "crate_helpers"}
_src = open(os.path.join(HERE, "build_crate.py"), encoding="utf-8").read()
exec(_src.split("# ---------------------------------------------------------------- the crate")[0], _ns)
prism, cham_rect = _ns["prism"], _ns["cham_rect"]

COLL = "POWERPACK"
COLORS = {"Foil": "2B2D33", "Seal": "C9961F", "Label": "141518"}

HW = 0.85  # half width
BODY_Z = 0.95  # the foil runs between the seals (+-)
SEAL_Z = 1.20  # the crimp ends (+-)
EDGE_T = 0.012  # half thickness at the pouch's edge
TEETH = 17
TEETH_D = 0.035
TOP_PIVOT = Vector((HW + 0.01, 0.0, BODY_Z - 0.02))


def mat(role):
	name = "Pack_" + role
	m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
	h = COLORS[role]
	c = [int(h[i : i + 2], 16) / 255 for i in (0, 2, 4)]
	lin = tuple(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c) + (1.0,)
	m.diffuse_color = lin
	m.use_nodes = True
	bsdf = m.node_tree.nodes.get("Principled BSDF")
	bsdf.inputs["Base Color"].default_value = lin
	bsdf.inputs["Metallic"].default_value = 0.55 if role != "Label" else 0.0
	bsdf.inputs["Roughness"].default_value = 0.35 if role == "Seal" else 0.5
	return m


def loft_y(rings):
	"""A solid through outlines in the XZ plane [(pts (x, z), y), ...], same point count, back to front."""
	bm = bmesh.new()
	vs = [[bm.verts.new((x, y, z)) for x, z in pts] for pts, y in rings]
	bm.faces.new(vs[0])
	bm.faces.new(list(reversed(vs[-1])))
	n = len(vs[0])
	for a, b in zip(vs, vs[1:]):
		for i in range(n):
			j = (i + 1) % n
			bm.faces.new((a[i], a[j], b[j], b[i]))
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	return bm


def foil():
	"""The pillow: a thin edge, two flat facet steps, a flat label plateau front and back."""
	outer = cham_rect(-HW, HW, -BODY_Z, BODY_Z, 0.04)
	mid = cham_rect(-HW + 0.07, HW - 0.07, -BODY_Z + 0.06, BODY_Z - 0.06, 0.07)
	top = cham_rect(-HW + 0.17, HW - 0.17, -BODY_Z + 0.15, BODY_Z - 0.15, 0.10)
	bm = loft_y([(top, 0.105), (mid, 0.07), (outer, EDGE_T), (outer, -EDGE_T), (mid, -0.07), (top, -0.105)])
	# the back fin seal: a raised crimped strip down the middle of the back, seated into the plateau
	extra = [prism(cham_rect(-0.055, 0.055, -BODY_Z + 0.16, BODY_Z - 0.16, 0.025), "XZ", 0.098, 0.124, cham=0.006)]
	for i in range(12):
		z = -BODY_Z + 0.24 + i * (2 * BODY_Z - 0.48) / 11
		extra.append(prism(cham_rect(-0.05, 0.05, z - 0.008, z + 0.008, 0.004), "XZ", 0.12, 0.13))
	for e in extra:
		me = bpy.data.meshes.new("_e")
		e.to_mesh(me)
		bm.from_mesh(me)
		bpy.data.meshes.remove(me)
		e.free()
	return bm


def seal(sz):
	"""A gold crimp: a flat band with a saw-tooth outer end and crimp ribs, seated over the foil's edge.
	sz = +1 top, -1 bottom."""
	z_in, z_out = sz * (BODY_Z - 0.03), sz * SEAL_Z
	pts = [(-HW - 0.01, z_in), (HW + 0.01, z_in)]
	step = (2 * HW + 0.02) / TEETH
	for i in range(TEETH, -1, -1):
		x = -HW - 0.01 + i * step
		# the band's outer corners are cut, not square (no blunt ends)
		if i == TEETH:
			pts.append((x, z_out - sz * 0.035))
			pts.append((x - 0.03, z_out))
		elif i == 0:
			pts.append((x + 0.03, z_out))
			pts.append((x, z_out - sz * 0.035))
		else:
			pts.append((x, z_out))
		if i > 0:
			pts.append((x - step / 2, z_out - sz * TEETH_D))
	if sz > 0:
		# the tear notch: a V cut into the left end, where the rip starts
		pts.append((-HW - 0.01, z_out - 0.06))
		pts.append((-HW + 0.06, z_in + 0.09))
		pts.append((-HW - 0.01, z_in + 0.05))
	if sz < 0:
		pts = [(x, z) for x, z in pts]
	bm = prism(pts, "XZ", -0.022, 0.022)
	# crimp ribs: thin raised lines across the band, front and back
	ribs = []
	n = 14
	for i in range(n):
		x = -HW + 0.06 + i * (2 * HW - 0.12) / (n - 1)
		for y0, y1 in ((-0.03, -0.02), (0.02, 0.03)):
			ribs.append(prism(cham_rect(x - 0.008, x + 0.008, min(z_in, z_out) + 0.03, max(z_in, z_out) - 0.05, 0.004), "XZ", y0, y1))
	for r in ribs:
		me = bpy.data.meshes.new("_r")
		r.to_mesh(me)
		bm.from_mesh(me)
		bpy.data.meshes.remove(me)
		r.free()
	return bm


def label():
	"""The front label plate on the plateau (the art is a SurfaceGui on it in Studio)."""
	return prism(cham_rect(-HW + 0.21, HW - 0.21, -BODY_Z + 0.19, BODY_Z - 0.19, 0.08), "XZ", -0.111, -0.104, cham=0.003)


PIVOTS = {"Body": (0.0, 0.0, 0.0), "Top": tuple(TOP_PIVOT)}


def build():
	coll = bpy.data.collections.get(COLL)
	if coll:
		for o in list(coll.objects):
			bpy.data.objects.remove(o)
	else:
		coll = bpy.data.collections.new(COLL)
		bpy.context.scene.collection.children.link(coll)
	parts = {
		("Body", "Foil"): foil(),
		("Body", "Seal"): seal(-1),
		("Top", "Seal"): seal(1),
		("Body", "Label"): label(),
	}
	info = {"parts": {}, "pivots": PIVOTS, "units": "studs", "axes": "blender X=width, -Y=front, Z=up, origin=centre"}
	tris = 0
	for (g, role), bm in parts.items():
		name = f"{g}_{role}"
		bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
		bmesh.ops.triangulate(bm, faces=list(bm.faces))
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
		t = len(me.polygons)
		tris += t
		info["parts"][name] = {"group": g, "role": role, "tris": t}
	info["tris"] = tris
	with open(OUT_JSON, "w") as f:
		json.dump(info, f, indent=1)
	return info


def lights_and_cam(sc, k=1.0, tgt=(0, 0, 0)):
	tgt = Vector(tgt)
	for name, loc, energy, size in (("Key", (-3, -4, 3), 260, 3), ("Fill", (3.5, -2.5, 1.0), 90, 3.5), ("Rim", (1.5, 3.5, 3), 220, 2.4)):
		lt = bpy.data.objects.get("Pack" + name) or bpy.data.objects.new("Pack" + name, bpy.data.lights.new("Pack" + name, "AREA"))
		if lt.name not in sc.collection.objects:
			sc.collection.objects.link(lt)
		lt.location = Vector(loc) * k
		lt.data.energy, lt.data.size = energy * k * k, size * k
		lt.rotation_euler = (tgt - lt.location).to_track_quat("-Z", "Y").to_euler()
	cam = bpy.data.objects.get("PackCam") or bpy.data.objects.new("PackCam", bpy.data.cameras.new("PackCam"))
	if cam.name not in sc.collection.objects:
		sc.collection.objects.link(cam)
	sc.camera = cam
	return cam


def previews(out):
	os.makedirs(out, exist_ok=True)
	sc = bpy.context.scene
	sc.render.engine = "BLENDER_EEVEE"
	sc.render.resolution_x, sc.render.resolution_y = 1200, 1200
	sc.view_settings.view_transform = "Standard"
	sc.render.film_transparent = False
	w = bpy.data.worlds.get("PackWorld") or bpy.data.worlds.new("PackWorld")
	w.use_nodes = True
	w.node_tree.nodes["Background"].inputs[0].default_value = (0.05, 0.05, 0.055, 1)
	sc.world = w
	cam = lights_and_cam(sc)
	shots = {
		"front": ((0.0, -7.0, 0.0), (0, 0, 0), 50),
		"three_quarter": ((-3.2, -5.4, 1.6), (0, 0, 0), 50),
		"side": ((7.0, 0.0, 0.0), (0, 0, 0), 50),
		"close_top": ((-1.2, -2.2, 1.6), (-0.2, 0, 1.05), 50),
		"back": ((2.6, 5.6, 0.8), (0, 0, 0), 50),
	}
	paths = []
	for name, (loc, tgt, lens) in shots.items():
		cam.location = loc
		cam.rotation_euler = (Vector(tgt) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
		cam.data.lens = lens
		sc.render.filepath = os.path.join(out, f"pack_{name}.png")
		bpy.ops.render.render(write_still=True)
		paths.append(sc.render.filepath)
	return paths


LABEL_PNG = os.path.join(ROOT, "art-source", "ui", "pack", "pack_label.png")


def art():
	"""The UI pictures (Backpack icon, Shop card), transparent; raw renders, cropped afterwards with a 10 px border.
	The label art lives in Studio as a SurfaceGui (tools/studio/BuildPack.luau); for these renders a straight-on
	Studio capture of it (art-source/ui/pack/pack_label.png) goes on a render-only plane over the plate."""
	sc = bpy.context.scene
	sc.render.engine = "BLENDER_EEVEE"
	sc.render.film_transparent = True
	sc.render.image_settings.file_format = "PNG"
	sc.render.image_settings.color_mode = "RGBA"
	sc.view_settings.view_transform = "Standard"
	me = bpy.data.meshes.new("PackLabelArt")
	x, z, y = HW - 0.21, BODY_Z - 0.19, -0.1113
	me.from_pydata([(-x, y, -z), (x, y, -z), (x, y, z), (-x, y, z)], [], [(0, 1, 2, 3)])
	uv = me.uv_layers.new()
	for i, c in enumerate(((0, 0), (1, 0), (1, 1), (0, 1))):
		uv.data[i].uv = c
	m = bpy.data.materials.get("Pack_LabelArt") or bpy.data.materials.new("Pack_LabelArt")
	m.use_nodes = True
	nt = m.node_tree
	bsdf = nt.nodes.get("Principled BSDF")
	tex = nt.nodes.get("LabelTex") or nt.nodes.new("ShaderNodeTexImage")
	tex.name = "LabelTex"
	tex.image = bpy.data.images.load(LABEL_PNG, check_existing=True)
	nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
	nt.links.new(tex.outputs["Color"], bsdf.inputs["Emission Color"])
	bsdf.inputs["Emission Strength"].default_value = 0.35
	bsdf.inputs["Roughness"].default_value = 0.5
	me.materials.append(m)
	plane = bpy.data.objects.new("PackLabelArt", me)
	bpy.data.collections[COLL].objects.link(plane)
	cam = lights_and_cam(sc, 1.0, (0, 0, 0))
	cam.data.type = "PERSP"
	out = []
	for path, d, lens, res in (
		(os.path.join(ROOT, "art-source", "ui", "pack", "pack_power_raw.png"), (-0.42, -1.0, 0.22), 50, 512),
		(os.path.join(ROOT, "art-source", "ui", "pack", "pack_power_card_raw.png"), (-0.55, -1.0, 0.3), 50, 640),
	):
		cam.location = Vector(d).normalized() * 4.4
		q = (-cam.location).to_track_quat("-Z", "Y")
		cam.rotation_euler = (q @ Quaternion((0, 0, 1), math.radians(-7))).to_euler()
		cam.data.lens = lens
		sc.render.resolution_x = sc.render.resolution_y = res
		sc.render.filepath = path
		bpy.ops.render.render(write_still=True)
		out.append(path)
	bpy.data.objects.remove(plane)
	sc.render.film_transparent = False
	return out


info = build()
for _c in bpy.data.collections:  # only the pack in renders (this Blender may also hold the Surge case)
	_c.hide_render = _c.name != COLL
	_c.hide_viewport = _c.name != COLL
result = {"parts": len(info["parts"]), "tris": info["tris"]}
if globals().get("PACK_PREVIEW"):
	result["previews"] = previews(globals()["PACK_PREVIEW"])
if globals().get("PACK_ART"):
	result["art"] = art()
if globals().get("PACK_EXPORT"):
	bpy.ops.object.select_all(action="DESELECT")
	for ob in bpy.data.collections[COLL].objects:
		ob.select_set(True)
	bpy.ops.export_scene.fbx(filepath=FBX, use_selection=True, object_types={"MESH"}, apply_scale_options="FBX_SCALE_UNITS", use_mesh_modifiers=True, bake_anim=False)
	result["fbx"] = FBX
bpy.ops.wm.save_as_mainfile(filepath=BLEND)
