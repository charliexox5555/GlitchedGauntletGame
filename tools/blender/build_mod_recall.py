# build_mod_recall.py: the Recall anchor (vault/01 Design/Abilities/Recall.md, "Look"), planted on the ground and
# teleported back to later.
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup \
#       --python tools/blender/build_mod_recall.py -- [--render]
# A compact tactical teleport anchor, plain and realistic (Chamber's Rendezvous anchor as the quality read), in COOL
# VIOLET so it never reads as Heal Orb green-teal, Frost ice blue, Stim yellow or fire orange: a heavy hexagonal
# charcoal body on a black rubber foot, gripped to the floor by three steel-tipped claw legs (on the back and back
# diagonals), a gunmetal shoulder and neck, and on top an open three-fin crown cradling a faceted violet crystal
# (Core_Violet) inside a thin glowing violet ring (Ring_Violet). Violet light strips run up the inner edge of each fin
# and round the top of the foot (Strips_Violet): a soft violet glow at floor level and at the top, so it's findable.
# Front (+X): a dark bezel with a small team-tinted status light (Light_Energy) over a "RECALL" stencil with a
# violet-paint underline. Sides (the two front diagonals): recessed panels with a violet-paint diamond emblem.
#
# Parts: Base, Legs, Crown, Core_Violet, Ring_Violet, Strips_Violet, Light_Energy. The *_Violet parts are NOT energy
# parts on purpose: they stay cool violet (#9B6BFF, Neon) for every viewer; only *_Energy parts are team-tinted.
# Multi-material parts are split on export (Base -> Base_Shell, Base_Dark, Base_Trim, Base_Stencil, Base_Paint ...).
# Locators: Top (just above the crystal tip: the light / beam rises from here) and Floor (the floor centre = pivot).
# Origin on the floor at the centre. Same axes as every Mod: +X forward, +Z up, +Y left, 1 unit = 1 stud.
#
# --render writes vault/02 Art/References/abilities/recall/recall_model.jpg: three angles, a high view as players
# mostly see it, and a true-scale lineup next to the Stim beacon (art-source/abilities/Stim/Stim.blend, appended,
# never saved).

import os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import math
from modkit import *  # noqa: F401,F403

MOD = "Recall"
VIOLET = 0x9B6BFF

HEX = math.pi / 6  # hexagon corners at 30 + 60k degrees: flat faces at 0, 60, 120 ... (front face on +X)
R_BODY = 0.17  # body corner radius
AP_BODY = R_BODY * math.cos(HEX)  # flat face distance
Z_FOOT, Z_BODY, Z_SHOULDER = 0.05, 0.42, 0.47
NECK_Z0, NECK_Z1 = Z_SHOULDER, 0.585  # neck up to the crown cup
LEG_ANGLES = (math.radians(60), math.pi, math.radians(-60))  # claws on the back and the back diagonals
SIDE_ANGLES = (math.radians(120), math.radians(-120))  # panels on the front diagonals
LIGHT_Z = 0.34
CORE_Z0, CORE_Z1, CORE_R = 0.63, 0.97, 0.072  # the crystal
RING_Z, RING_R = 0.79, 0.158
TOP_Z = 1.0

# Extra materials (appended after modkit's six, same rbx_* look properties).
STEEL, STENCIL, VIOLET_NEON, PAINT = 6, 7, 8, 9


def extra_materials():
	def mat(name, color, metallic, rough, rbx, emit=0.0):
		m = bpy.data.materials.new(name)
		m["rbx_material"] = rbx
		m["rbx_color"] = "%06X" % color
		m.use_nodes = True
		nt = m.node_tree
		nt.nodes.clear()
		out = nt.nodes.new("ShaderNodeOutputMaterial")
		b = nt.nodes.new("ShaderNodeBsdfPrincipled")
		nt.links.new(b.outputs["BSDF"], out.inputs["Surface"])
		b.inputs["Base Color"].default_value = (*lin(color), 1)
		b.inputs["Metallic"].default_value = metallic
		b.inputs["Roughness"].default_value = rough
		if emit > 0:
			b.inputs["Emission Color"].default_value = (*lin(color), 1)
			b.inputs["Emission Strength"].default_value = emit
		m.diffuse_color = (*lin(color), 1)
		return m

	return [
		mat("Steel", 0x9A9EA4, 0.85, 0.34, "Metal"),  # bare steel: claw tips, hinge pins
		mat("Stencil", 0xC8CBD0, 0.0, 0.7, "SmoothPlastic"),  # pale grey stencil paint
		mat("Violet", VIOLET, 0.0, 0.2, "Neon", emit=1.5),  # the anchor light: fixed cool violet, Neon
		mat("Paint", 0x6A4FB8, 0.0, 0.6, "SmoothPlastic"),  # matte violet paint (underline, emblems)
	]


# ---------------------------------------------------------------- helpers


def face_frame(phi, z, along=0.0, out=0.0, ap=AP_BODY):
	# Matrix on the flat body face at angle phi: local X = along the face (reading direction seen from outside),
	# local Y = up, local Z = out of the face.
	n = Vector((math.cos(phi), math.sin(phi), 0))
	u = Vector((-math.sin(phi), math.cos(phi), 0))
	return frame(n * (ap + out) + u * along + Vector((0, 0, z)), u, (0, 0, 1))


def radial(phi):
	# Local radial frame at angle phi: local X = outward, Y = across (tangent), Z = up. Profiles drawn in (r, z) with
	# prism(..., "Y", -w, w) land in the radial plane through phi.
	return rot_z(phi)


def text_flat(text, size, mat=STENCIL):
	# Flat lettering in the local XY plane (centred on x = 0, baseline at y = 0), as real geometry.
	cu = bpy.data.curves.new("_txt", "FONT")
	cu.body = text
	cu.size = size
	cu.align_x = "CENTER"
	cu.resolution_u = 2
	cu.fill_mode = "BOTH"
	ob = bpy.data.objects.new("_txt", cu)
	bpy.context.scene.collection.objects.link(ob)
	dg = bpy.context.evaluated_depsgraph_get()
	me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
	bm = bmesh.new()
	bm.from_mesh(me)
	bpy.data.objects.remove(ob)
	bpy.data.curves.remove(cu)
	bpy.data.meshes.remove(me)
	bpy.context.view_layer.update()
	bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-5)
	bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(4), verts=bm.verts[:], edges=bm.edges[:])
	bm.normal_update()
	for f in bm.faces:
		if f.normal.z < 0:
			f.normal_flip()
		f.material_index = mat
	return bm


def offset_curve(pts, d):
	# Offsets an open polyline [(r, z)] sideways by d (positive = to the left of the walking direction).
	out = []
	n = len(pts)
	for i in range(n):
		a = pts[max(i - 1, 0)]
		b = pts[min(i + 1, n - 1)]
		tx, tz = b[0] - a[0], b[1] - a[1]
		ln = math.hypot(tx, tz)
		out.append((pts[i][0] - tz / ln * d, pts[i][1] + tx / ln * d))
	return out


# Fin inner edge (r, z), bottom to top: hugs the crystal, leaving a small gap.
FIN_INNER = [(0.085, 0.585), (0.112, 0.64), (0.135, 0.71), (0.142, 0.79), (0.132, 0.87), (0.108, 0.94), (0.088, 0.985)]
# Fin outer edge (r, z), top to bottom: a swept blade that flares out past the ring.
FIN_OUTER = [(0.102, 1.0), (0.15, 0.94), (0.192, 0.86), (0.206, 0.79), (0.196, 0.71), (0.158, 0.63), (0.118, 0.585)]
FIN_W = 0.022  # half thickness
STRIP_W = 0.0105  # half width of the violet strip on the fin's inner edge


# ---------------------------------------------------------------- build


def build():
	mats = begin(MOD) + extra_materials()

	# ---- Base: rubber foot, hex body with a rubber bumper band, gunmetal shoulder, neck and the crown cup.
	base = Part("Base")
	base.add(drop(frustum(6, 0.24, 0.222, 0.0, Z_FOOT, DARK, HEX), 2, -1), 0.012, 1)
	base.add(drop(frustum(6, R_BODY, R_BODY, Z_FOOT - 0.01, Z_BODY, SHELL, HEX), 2, -1), 0.012, 1)
	base.add(band(6, R_BODY - 0.01, R_BODY + 0.014, 0.085, 0.125, DARK, HEX), 0.005, 1)
	base.add(drop(frustum(6, 0.178, 0.17, Z_BODY, Z_BODY + 0.018, TRIM, HEX), 2, -1), 0.005, 1)
	base.add(drop(frustum(6, 0.158, 0.1, Z_BODY + 0.018, Z_SHOULDER, SHELL, HEX), 2, -1), 0.008, 1)
	base.add(lathe([
		(0.0, Z_SHOULDER - 0.004), (0.072, Z_SHOULDER - 0.004), (0.072, 0.51), (0.056, 0.518), (0.056, 0.548),
		(0.084, 0.552), (0.106, 0.566), (0.106, NECK_Z1), (0.092, NECK_Z1), (0.092, NECK_Z1 - 0.008),
		(0.0, NECK_Z1 - 0.008),
	], 12, TRIM, rot=math.pi / 12))
	# The cup's dark emitter plate under the floating crystal.
	base.add(lathe([(0.0, NECK_Z1 - 0.009), (0.093, NECK_Z1 - 0.009), (0.093, NECK_Z1 - 0.005), (0.0, NECK_Z1 - 0.005)], 12, DARK, rot=math.pi / 12))

	# Front (+X): a dark bezel for the status light, the "RECALL" stencil and a violet-paint underline.
	bz = [(-0.052, -0.04), (0.052, -0.04), (0.052, 0.04), (-0.052, 0.04)]
	base.add(place(drop(prism(bz, "Z", 0.0, 0.012, DARK), 2, -1), face_frame(0.0, LIGHT_Z)), 0.004, 1)
	base.add(place(text_flat("RECALL", 0.03), face_frame(0.0, 0.215, out=0.0012)))
	base.add(place(drop(prism([(-0.062, 0.0), (0.062, 0.0), (0.062, 0.006), (-0.062, 0.006)], "Z", 0.0, 0.002, PAINT), 2, -1), face_frame(0.0, 0.2, out=0.0004)))
	# Small hazard-free detail: two screws under the stencil row.
	for s in (-1, 1):
		screw = lathe([(0.0, 0.0), (0.008, 0.0), (0.008, 0.003), (0.0, 0.004)], 6, TRIM)
		base.add(place(screw, face_frame(0.0, 0.165, along=s * 0.05)))

	# Front diagonals: recessed dark panels with a violet-paint diamond emblem and three small stencil ticks.
	panel = [(-0.06, -0.1), (0.06, -0.1), (0.06, 0.1), (-0.06, 0.1)]
	diamond = [(0.0, -0.042), (0.03, 0.0), (0.0, 0.042), (-0.03, 0.0)]
	inner = [(0.0, -0.026), (0.0165, 0.0), (0.0, 0.026), (-0.0165, 0.0)]
	for phi in SIDE_ANGLES:
		base.add(place(drop(prism(panel, "Z", 0.0, 0.004, DARK), 2, -1), face_frame(phi, 0.27)), 0.002, 1)
		base.add(place(drop(prism(diamond, "Z", 0.0, 0.0065, PAINT), 2, -1), face_frame(phi, 0.3)))
		base.add(place(drop(prism(inner, "Z", 0.0, 0.0075, DARK), 2, -1), face_frame(phi, 0.3)))
		for k in range(3):
			tick = [(-0.022, 0.0), (0.022, 0.0), (0.022, 0.006), (-0.022, 0.006)]
			base.add(place(drop(prism(tick, "Z", 0.0, 0.0055, STENCIL), 2, -1), face_frame(phi, 0.215 - k * 0.018)))

	# Leg hinge blocks on the back faces.
	for phi in LEG_ANGLES:
		blk = box(AP_BODY - 0.006, AP_BODY + 0.03, -0.058, 0.058, 0.205, 0.305, DARK)
		base.add(place(blk, radial(phi)), 0.006, 1)

	# ---- Legs: three claws from the hinge blocks down to steel tips planted on the floor.
	legs = Part("Legs")
	claw = [(0.15, 0.2), (0.15, 0.31), (0.205, 0.312), (0.255, 0.272), (0.355, 0.122), (0.312, 0.08), (0.232, 0.158)]
	tip = [(0.296, 0.096), (0.358, 0.138), (0.405, 0.0), (0.378, 0.0)]
	rib = [(0.205, 0.292), (0.236, 0.265), (0.33, 0.125), (0.322, 0.118), (0.228, 0.256), (0.2, 0.28)]
	for phi in LEG_ANGLES:
		m = radial(phi)
		legs.add(place(prism(claw, "Y", -0.044, 0.044, SHELL), m), 0.009, 1)
		legs.add(place(prism(tip, "Y", -0.026, 0.026, STEEL), m), 0.004, 1)
		legs.add(place(prism(rib, "Y", -0.012, 0.012, TRIM), m @ Matrix.Translation((0, 0, 0.004))), 0.002, 1)
		pin = lathe([(0.0, -0.066), (0.019, -0.066), (0.019, 0.066), (0.0, 0.066)], 8, STEEL, "Y", (0.0, 0, 0.0))
		legs.add(place(pin, m @ Matrix.Translation((0.178, 0, 0.268))))

	# ---- Crown: three swept fins on the cup, cradling the crystal; a small gunmetal clamp where the ring passes.
	crown = Part("Crown")
	fin = FIN_INNER + FIN_OUTER
	for phi in LEG_ANGLES:
		m = radial(phi)
		crown.add(place(prism(fin, "Y", -FIN_W, FIN_W, SHELL), m), 0.006, 1)
		clamp = box(RING_R - 0.03, RING_R + 0.06, -FIN_W - 0.007, FIN_W + 0.007, RING_Z - 0.026, RING_Z + 0.026, TRIM)
		crown.add(place(clamp, m), 0.005, 1)

	# ---- Core_Violet: a faceted crystal (hex bipyramid with a short waist), fixed violet.
	core = Part("Core_Violet")
	cz = (CORE_Z0 + CORE_Z1) / 2
	core.add(lathe([(0.0, CORE_Z0), (CORE_R, cz - 0.03), (CORE_R, cz + 0.03), (0.0, CORE_Z1)], 6, VIOLET_NEON, rot=HEX))

	# ---- Ring_Violet: a thin glowing ring round the crystal, through the fin clamps.
	ring = Part("Ring_Violet")
	ring.add(torus(RING_R, 0.0105, 30, 6, VIOLET_NEON, "Z", (0, 0, RING_Z)))

	# ---- Strips_Violet: light strips on each fin's inner edge, and a thin glowing band round the top of the foot.
	strips = Part("Strips_Violet")
	inner_edge = FIN_INNER[1:-1]
	# (offset_curve: + is toward the crystal, - is into the fin; the strip stands 6 mm proud of the edge.)
	strip = offset_curve(inner_edge, -0.006) + offset_curve(inner_edge, 0.006)[::-1]
	for phi in LEG_ANGLES:
		strips.add(place(prism(strip, "Y", -STRIP_W, STRIP_W, VIOLET_NEON), radial(phi)))
	strips.add(band(12, 0.046, 0.06, NECK_Z1 - 0.006, NECK_Z1 - 0.002, VIOLET_NEON, math.pi / 12))  # emitter ring
	strips.add(band(6, R_BODY + 0.004, R_BODY + 0.03, Z_FOOT - 0.004, Z_FOOT + 0.007, VIOLET_NEON, HEX))

	# ---- Light_Energy: the small team-tinted status light in the front bezel.
	light = Part("Light_Energy")
	dome = lathe([(0.0, 0.0), (0.02, 0.0), (0.02, 0.006), (0.015, 0.012), (0.008, 0.0155), (0.0, 0.0165)], 10, ENERGY)
	light.add(place(dome, face_frame(0.0, LIGHT_Z, out=0.011)))

	parts = [base, legs, crown, core, ring, strips, light]
	locators = [
		("Top", (0, 0, TOP_Z), None),
		("Floor", (0, 0, 0), None),
	]
	return assemble(MOD, parts, mats, locators, {"kind": "placed", "size_studs": round(TOP_Z, 3)})


# ---------------------------------------------------------------- check render

OUT_DIR = os.path.join(ROOT, "vault", "02 Art", "References", "abilities", "recall")


def instance(col, pos, rz=0.0):
	e = bpy.data.objects.new("Inst_" + col.name, None)
	e.instance_type = "COLLECTION"
	e.instance_collection = col
	bpy.context.scene.collection.objects.link(e)
	e.matrix_world = Matrix.Translation(pos) @ Matrix.Rotation(math.radians(rz), 4, "Z")
	return e


def proxy(name, x0, x1, y0, y1, z0, z1):
	me = bpy.data.meshes.new(name)
	bm = box(x0, x1, y0, y1, z0, z1, SHELL)
	bm.to_mesh(me)
	bm.free()
	ob = bpy.data.objects.new(name, me)
	bpy.context.scene.collection.objects.link(ob)
	return ob


def shot(name, insts, box_, look_dir, lens, zoom, res):
	sc = bpy.context.scene
	pr = proxy("_proxy_" + name, *box_)
	stage(look_dir=look_dir, hover=0.0, lens=lens, zoom=zoom)
	pr.hide_render = True
	sc.view_settings.view_transform = "AgX"
	sc.view_settings.look = "AgX - Medium High Contrast"
	path = render(os.path.join(OUT_DIR, "_tmp", name + ".jpg"), res)
	for o in insts + [pr]:
		bpy.data.objects.remove(o)
	return path


def render_sheet():
	# Rows stacked into one JPEG with numpy (bundled with Blender): three angles (front three-quarter, the side, the
	# back), a high view as players mostly see it, and a true-scale lineup with the Stim beacon.
	# The camera looks from +Y (the left side) slightly forward, so +X is screen left.
	import numpy as np

	recall = bpy.data.collections[MOD]
	bpy.context.scene.collection.children.unlink(recall)
	with bpy.data.libraries.load(blend_path("Stim"), link=False) as (src, dst):
		dst.collections = ["Stim"]
	stim = dst.collections[0]
	os.makedirs(os.path.join(OUT_DIR, "_tmp"), exist_ok=True)
	paths = []

	# Front three-quarter (status light, stencil), the side, the back (claws).
	insts = [instance(recall, (1.0, 0.0, 0.0), 55), instance(recall, (0.0, 0.0, 0.0), 0), instance(recall, (-1.0, 0.0, 0.0), -150)]
	paths.append(shot("angles", insts, (-1.45, 1.45, -0.45, 0.45, 0.0, 1.0), (0.0, 1.0, 0.32), 60, 0.62, (1800, 760)))

	# From high up (how players mostly see it on the floor).
	insts = [instance(recall, (0.55, 0.0, 0.0), 75), instance(recall, (-0.55, 0.0, 0.0), 10)]
	paths.append(shot("above", insts, (-1.0, 1.0, -0.45, 0.45, 0.0, 1.0), (0.0, 1.0, 1.4), 60, 0.62, (1800, 760)))

	# True scale: both on the floor (both pivots at the floor centre).
	insts = [instance(recall, (0.38, 0.0, 0.0), 70), instance(stim, (-0.42, 0.0, 0.0), 70)]
	paths.append(shot("scale", insts, (-0.8, 0.8, -0.45, 0.45, 0.0, 1.12), (0.0, 1.0, 0.22), 85, 0.82, (1800, 700)))

	imgs = []
	for p in paths:
		im = bpy.data.images.load(p)
		imgs.append(np.array(im.pixels[:], dtype=np.float32).reshape(im.size[1], im.size[0], 4))
	stacked = np.concatenate(imgs[::-1], axis=0)  # Blender pixel rows run bottom-up
	out = bpy.data.images.new("recall_model", stacked.shape[1], stacked.shape[0], alpha=False)
	out.pixels.foreach_set(stacked.ravel())
	out.filepath_raw = os.path.join(OUT_DIR, "recall_model.jpg")
	out.file_format = "JPEG"
	bpy.context.scene.render.image_settings.quality = 92
	out.save()
	for p in paths:
		os.remove(p)
	os.rmdir(os.path.join(OUT_DIR, "_tmp"))
	print("RECALL_RENDER", out.filepath_raw)


if __name__ == "__main__":
	args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
	report = build()
	bpy.context.view_layer.update()
	objs = [o for o in bpy.data.collections[MOD].objects if o.type == "MESH"]
	lo, hi = bounds(objs)
	path = blend_path(MOD)
	os.makedirs(os.path.dirname(path), exist_ok=True)
	bpy.ops.wm.save_as_mainfile(filepath=path)
	print("BUILD_MOD " + json.dumps({"mod": MOD, "blend": path, "tris": report, "bounds": [list(lo), list(hi)]}))
	if "--render" in args:
		render_sheet()
