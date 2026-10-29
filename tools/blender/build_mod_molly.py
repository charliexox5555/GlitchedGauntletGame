# build_mod_molly.py: the Molly incendiary canister (vault/01 Design/Abilities/Molly.md), held in first person and thrown.
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup \
#       --python tools/blender/build_mod_molly.py -- [--render]
# A military incendiary grenade (AN-M14 style, plain and realistic, not the old glitch look): a matte olive-drab steel
# can with rolled seams top and bottom, a red band, a small pale-yellow stencil marking, and a steel fuse on top with a
# spoon lever running down the +X (forward) side, a split pin and pull ring on the +Y side and a small cap on top
# (Fuse_Energy: the fuse glow, tinted per team in game).
#
# Parts (code animates them): Body, Band, FuseHead, Fuse_Energy, Lever (flies off on the throw), Pin (ring + pin,
# pulled on equip). Locators: Handle (the centre, held in the palm; the builder adds RightGrip = Handle) and Fuse (top
# of the fuse cap). HoldOffset lives in tools/studio/make_ability_build_data.py (EXTRA), like the Packet's.
# Origin at the centre of the 0.55-stud height. Same axes as every Mod: +X forward, +Z up, +Y left, 1 unit = 1 stud.
#
# --render writes vault/02 Art/References/abilities/molly/molly_model.jpg: a close-up from three angles plus a
# true-scale lineup next to the Packet (built from art-source/abilities/Packet/Packet.blend, appended, never saved).

import os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import math
from modkit import *  # noqa: F401,F403

MOD = "Molly"
R = 0.105  # can radius (0.21 studs across)
Z0, Z1 = -0.275, 0.148  # can bottom / lid top
TOP = 0.275  # top of the fuse cap: 0.55 studs overall

# Extra matte materials for the realistic canister (appended after modkit's six, same rbx_* look properties).
OLIVE, RED, STENCIL, STEEL = 6, 7, 8, 9


def extra_materials():
	def mat(name, color, metallic, rough, rbx):
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
		m.diffuse_color = (*lin(color), 1)
		return m

	return [
		mat("Olive", 0x4A5034, 0.0, 0.62, "SmoothPlastic"),  # olive-drab paint on steel
		mat("Red", 0x9C2A1E, 0.0, 0.58, "SmoothPlastic"),  # incendiary band
		mat("Stencil", 0xCDBB72, 0.0, 0.7, "SmoothPlastic"),  # pale yellow stencil paint
		mat("Steel", 0x9A9EA4, 0.85, 0.34, "Metal"),  # bare steel pin and ring
	]


def sweep(stations, mat):
	# A curved strip (the spoon) along a centreline in the XZ plane. stations: [(x, z, width, sag)]; the section is
	# an arc across Y (edges `sag` closer to the can) with a fixed thickness, so it hugs the body like a real lever.
	th = 0.007
	bm = bmesh.new()
	rings = []
	n = len(stations)
	for i, (x, z, w, sag) in enumerate(stations):
		a = stations[max(i - 1, 0)]
		b = stations[min(i + 1, n - 1)]
		tx, tz = b[0] - a[0], b[1] - a[1]
		ln = math.hypot(tx, tz)
		tx, tz = tx / ln, tz / ln
		nx, nz = tz, -tx  # outward normal (the centreline runs top -> bottom down the +X side)
		ring = []
		for side in (1, -1):  # outer then inner surface
			off = th / 2 * side
			for y in (-w / 2, 0.0, w / 2):
				s = sag * (abs(y) / (w / 2)) ** 2
				ring.append(bm.verts.new((x + nx * (off - s), y, z + nz * (off - s))))
		rings.append(ring)
	# ring order: o0 o1 o2 i0 i1 i2 -> loop o0 o1 o2 i2 i1 i0
	loop = [0, 1, 2, 5, 4, 3]
	for ra, rb in zip(rings, rings[1:]):
		for k in range(6):
			p, q = loop[k], loop[(k + 1) % 6]
			bm.faces.new((ra[p], ra[q], rb[q], rb[p]))
	for ring in (rings[0], rings[-1]):
		bm.faces.new([ring[k] for k in loop])
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	for f in bm.faces:
		f.material_index = mat
	return bm


def stencil(text, size, angle0, z, radius, mat=STENCIL):
	# Flat stencil lettering wrapped onto the can (text centred on angle0, baseline at z), as real geometry.
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
	for v in bm.verts:
		tx, ty = v.co.x, v.co.y
		a = angle0 + tx / radius  # reads left to right seen from outside
		v.co = (radius * math.cos(a), radius * math.sin(a), z + ty)
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	bm.normal_update()
	# Face outward.
	for f in bm.faces:
		c = f.calc_center_median()
		if f.normal.dot(Vector((c.x, c.y, 0))) < 0:
			f.normal_flip()
		f.material_index = mat
	return bm


def build():
	mats = begin(MOD) + extra_materials()

	# ---- Body: the can, with rolled seams (beads) top and bottom and a slightly domed lid.
	body = Part("Body")
	body.add(lathe([
		(0.0, Z0 + 0.008), (0.07, Z0 + 0.008), (0.086, Z0 + 0.002), (0.097, Z0), (0.104, Z0 + 0.004),
		(0.109, Z0 + 0.012), (0.109, Z0 + 0.026), (R, Z0 + 0.032),
		(R, 0.112), (0.109, 0.118), (0.109, 0.132), (0.104, 0.139), (0.094, Z1 - 0.004), (0.06, Z1), (0.0, Z1),
	], 28, OLIVE))
	# Filler plug on the bottom.
	body.add(lathe([(0.0, Z0 + 0.004), (0.028, Z0 + 0.004), (0.03, Z0 + 0.008), (0.0, Z0 + 0.008)], 12, OLIVE))
	# Stencil marking on the side away from the lever (+Y / -Y); two short lines.
	for a0 in (math.pi / 2, -math.pi / 2):
		body.add(stencil("INCENDIARY", 0.026, a0, -0.075, R + 0.0012))
		body.add(stencil("TH3  M14", 0.022, a0, -0.112, R + 0.0012))

	# ---- Band: the red band below the top seam (a raised painted ring).
	band_p = Part("Band")
	band_p.add(band(28, R - 0.002, R + 0.0022, 0.02, 0.074, RED))

	# ---- FuseHead: threaded collar, fuse body, lever ears and striker head.
	fuse = Part("FuseHead")
	fuse.add(lathe([(0.0, Z1 - 0.004), (0.032, Z1 - 0.004), (0.032, Z1 + 0.012)], 16, DARK))
	collar = lathe([(0.032, Z1 + 0.012), (0.044, Z1 + 0.012), (0.046, Z1 + 0.016), (0.046, Z1 + 0.034), (0.044, Z1 + 0.038), (0.037, Z1 + 0.038)], 6, TRIM, rot=math.pi / 6)
	fuse.add(collar)
	fuse.add(lathe([(0.037, Z1 + 0.038), (0.036, Z1 + 0.04), (0.036, 0.236), (0.041, 0.239), (0.041, 0.252), (0.036, 0.256), (0.0, 0.256)], 16, TRIM))
	# Lever ears (hinge plates either side of the lever, the pin runs through them).
	for s in (1, -1):
		fuse.add(box(0.026, 0.056, s * 0.016, s * 0.023, 0.198, 0.236, DARK), 0.003, 1)

	# ---- Fuse_Energy: the small cap on top of the striker (team-tinted fuse glow).
	glow = Part("Fuse_Energy")
	glow.add(lathe([(0.0, 0.254), (0.021, 0.254), (0.021, 0.262)] + [(0.021 * math.cos(a), 0.262 + 0.013 * math.sin(a)) for a in (0.5, 1.0)] + [(0.0, TOP)], 14, ENERGY))

	# ---- Lever: the spoon, from its hook beside the cap, over the head, down past the ears, over the top seam and
	# down the can's +X side, with a small outward kick at the end.
	lever = Part("Lever")
	lever.add(sweep([
		(0.026, 0.262, 0.026, 0.0),
		(0.044, 0.262, 0.028, 0.0),
		(0.054, 0.256, 0.03, 0.001),
		(0.06, 0.236, 0.032, 0.002),
		(0.064, 0.2, 0.036, 0.003),
		(0.08, 0.17, 0.04, 0.004),
		(0.103, 0.15, 0.042, 0.005),
		(0.1135, 0.132, 0.044, 0.006),
		(0.1135, 0.11, 0.044, 0.006),
		(0.111, 0.0, 0.044, 0.006),
		(0.111, -0.09, 0.042, 0.006),
		(0.114, -0.118, 0.04, 0.005),
		(0.121, -0.135, 0.036, 0.004),
	], TRIM))

	# ---- Pin: split pin through the ears (along Y) and the pull ring hanging off the +Y end.
	pin = Part("Pin")
	px, pz = 0.047, 0.217
	pin.add(lathe([(0.0035, -0.03), (0.0035, 0.032)], 8, STEEL, axis="Y", center=(px, 0, pz)))
	ring_c = Vector((px, 0.032 + 0.024 * math.cos(math.radians(35)), pz - 0.024 * math.sin(math.radians(35))))
	ring = torus(0.024, 0.0038, 20, 6, STEEL)
	pin.add(place(ring, Matrix.Translation(ring_c) @ Matrix.Rotation(math.pi / 2, 4, "Y")))  # ring in the YZ plane
	# Bent legs of the split pin on the -Y side.
	pin.add(lathe([(0.003, 0.0), (0.003, 0.014)], 6, STEEL, axis="X", center=(px, -0.031, pz)))

	parts = [body, band_p, fuse, glow, lever, pin]
	locators = [
		("Handle", (0, 0, 0), None),
		("Fuse", (0, 0, TOP), None),
	]
	return assemble(MOD, parts, mats, locators, {"kind": "thrown", "size_studs": round(TOP - Z0, 3)})


# ---------------------------------------------------------------- check render

OUT_DIR = os.path.join(ROOT, "vault", "02 Art", "References", "abilities", "molly")


def instance(col, pos, rz=0.0, rx=0.0):
	e = bpy.data.objects.new("Inst_" + col.name, None)
	e.instance_type = "COLLECTION"
	e.instance_collection = col
	bpy.context.scene.collection.objects.link(e)
	e.matrix_world = Matrix.Translation(pos) @ Matrix.Rotation(math.radians(rz), 4, "Z") @ Matrix.Rotation(math.radians(rx), 4, "X")
	return e


def render_sheet():
	# Close-up row (three angles of the Molly) and a true-scale row with the Packet, rendered as two images and
	# stacked into one JPEG with numpy (bundled with Blender).
	import numpy as np

	sc = bpy.context.scene
	molly = bpy.data.collections[MOD]
	# Hide the real collection from the view layer; show it through instances instead.
	sc.view_layers[0].layer_collection.children[MOD].exclude = True
	tmp = os.path.join(OUT_DIR, "_tmp")
	os.makedirs(tmp, exist_ok=True)

	# Row 1: three angles. The camera looks from +X (front, the lever side) slightly to the left.
	insts = [instance(molly, (0, -0.32, 0.0), 0), instance(molly, (0, 0.0, 0.0), 90), instance(molly, (0, 0.32, 0.0), 200)]
	# A real floor under them; stage() frames every mesh, so give it a stand-in mesh at the right bounds.
	proxy_me = bpy.data.meshes.new("_proxy")
	bm = box(-0.13, 0.13, -0.47, 0.47, Z0, TOP, SHELL)
	bm.to_mesh(proxy_me)
	bm.free()
	proxy = bpy.data.objects.new("_proxy", proxy_me)
	sc.collection.objects.link(proxy)
	proxy.hide_render = False
	stage(look_dir=(1.0, 0.08, 0.32), hover=0.0, lens=60, zoom=0.62)
	proxy.hide_render = True
	sc.view_settings.view_transform = "AgX"  # no energy-colour clipping to worry about; AgX gives nicer paint
	sc.view_settings.look = "AgX - Medium High Contrast"
	a = render(os.path.join(tmp, "angles.jpg"), (1800, 900))
	for o in insts + [proxy]:
		bpy.data.objects.remove(o)

	# Row 2: true scale next to the Packet (both 0.55 studs tall; the Packet is the chunky 0.4 cube).
	path = blend_path("Packet")
	with bpy.data.libraries.load(path, link=False) as (src, dst):
		dst.collections = ["Packet"]
	packet = dst.collections[0]
	sc.collection.children.link(packet)
	sc.view_layers[0].layer_collection.children["Packet"].exclude = True
	insts = [instance(molly, (0, -0.22, 0.0), -20), instance(packet, (0, 0.22, Z0 + 0.22), 25)]  # the Packet foot is 0.22 below its centre
	proxy_me = bpy.data.meshes.new("_proxy2")
	bm = box(-0.15, 0.25, -0.45, 0.45, Z0, TOP, SHELL)
	bm.to_mesh(proxy_me)
	bm.free()
	proxy = bpy.data.objects.new("_proxy2", proxy_me)
	sc.collection.objects.link(proxy)
	stage(look_dir=(1.0, 0.0, 0.3), hover=0.0, lens=120, zoom=0.62)
	proxy.hide_render = True
	sc.view_settings.view_transform = "AgX"
	sc.view_settings.look = "AgX - Medium High Contrast"
	b = render(os.path.join(tmp, "scale.jpg"), (1800, 700))

	imgs = []
	for p in (a, b):
		im = bpy.data.images.load(p)
		px = np.array(im.pixels[:], dtype=np.float32).reshape(im.size[1], im.size[0], 4)
		imgs.append(px)
	# Blender pixel rows run bottom to top: the first image goes on top -> last in the array.
	stacked = np.concatenate([imgs[1], imgs[0]], axis=0)
	out = bpy.data.images.new("molly_model", stacked.shape[1], stacked.shape[0], alpha=False)
	out.pixels.foreach_set(stacked.ravel())
	out.filepath_raw = os.path.join(OUT_DIR, "molly_model.jpg")
	out.file_format = "JPEG"
	sc.render.image_settings.quality = 92
	out.save()
	for p in (a, b):
		os.remove(p)
	os.rmdir(tmp)
	print("MOLLY_RENDER", out.filepath_raw)


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
