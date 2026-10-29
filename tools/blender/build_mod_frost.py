# build_mod_frost.py: the Frost canister (vault/01 Design/Abilities/Frost.md), held in first person and thrown.
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup \
#       --python tools/blender/build_mod_frost.py -- [--render]
# A tactical cryo grenade, plain and realistic (same family as the Molly, clearly different at a glance): a matte
# cool white-grey can with a gunmetal base cap, a sloped (conical) shoulder instead of a flat lid, a caged window
# section in the middle (six ribs over frost-blue windows), a cold-blue band under the shoulder, a dark stencil
# marking, and the same steel fuse on top: spoon lever down the +X (forward) side, split pin and pull ring on the +Y
# side, a small cap on top (Fuse_Energy: the fuse glow, tinted per team in game).
#
# Parts (code animates them): Body, Band, Vents, FuseHead, Fuse_Energy, Lever (flies off on the throw), Pin (ring +
# pin, pulled on equip). Vents are NOT an energy part on purpose: they stay frost blue for every viewer (Roblox Ice
# material, fixed colour), since ModProps recolours *_Energy / Neon parts to the team colour.
# Locators: Handle (the centre, held in the palm; the builder adds RightGrip = Handle) and Fuse (top of the fuse cap).
# HoldOffset lives in tools/studio/make_ability_build_data.py (EXTRA), like the Molly's.
# Origin at the centre of the 0.55-stud height. Same axes as every Mod: +X forward, +Z up, +Y left, 1 unit = 1 stud.
#
# --render writes vault/02 Art/References/abilities/frost/frost_model.jpg: a close-up from three angles plus a
# true-scale lineup next to the Molly (built from art-source/abilities/Molly/Molly.blend, appended, never saved).

import os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import math
from modkit import *  # noqa: F401,F403

MOD = "Frost"
R = 0.1  # can radius (0.2 studs across, a touch slimmer than the Molly)
Z0 = -0.275  # can bottom
ZS = 0.098  # where the shoulder starts
Z1 = 0.152  # top of the shoulder (fuse seat)
TOP = 0.275  # top of the fuse cap: 0.55 studs overall
SEG = 20  # lathe segments around the can (keeps the whole prop under 2.5K tris)
WIN0, WIN1 = -0.09, 0.034  # caged window section
RIBS = 6  # one rib on +X, under the lever

# Extra matte materials (appended after modkit's six, same rbx_* look properties).
WHITE, BLUE, FROSTGLASS, GUNMETAL, STEEL, STENCIL = 6, 7, 8, 9, 10, 11


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
			# A faint inner glow so the frosted windows read as lit-through ice in the check render.
			b.inputs["Emission Color"].default_value = (*lin(color), 1)
			b.inputs["Emission Strength"].default_value = emit
		m.diffuse_color = (*lin(color), 1)
		return m

	return [
		mat("White", 0xC2C7CC, 0.0, 0.6, "SmoothPlastic"),  # cool white-grey paint
		mat("ColdBlue", 0x2F7DB8, 0.0, 0.55, "SmoothPlastic"),  # cold-blue accent band
		mat("FrostGlass", 0x8CCBEB, 0.0, 0.3, "Ice", emit=0.3),  # frosted windows (Roblox Ice material)
		mat("Gunmetal", 0x50565F, 0.7, 0.4, "Metal"),  # base cap, ribs' fuse collar
		mat("Steel", 0x9A9EA4, 0.85, 0.34, "Metal"),  # bare steel pin and ring
		mat("Stencil", 0x1F2833, 0.0, 0.7, "SmoothPlastic"),  # dark navy stencil paint
	]


def sweep(stations, mat):
	# The spoon: a curved strip along a centreline in the XZ plane (same as the Molly's). stations: [(x, z, width,
	# sag)]; the section is an arc across Y (edges `sag` closer to the can) with a fixed thickness.
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
		nx, nz = tz, -tx
		ring = []
		for side in (1, -1):
			off = th / 2 * side
			for y in (-w / 2, 0.0, w / 2):
				s = sag * (abs(y) / (w / 2)) ** 2
				ring.append(bm.verts.new((x + nx * (off - s), y, z + nz * (off - s))))
		rings.append(ring)
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


def arc_block(rin, rout, a0, a1, z0, z1, segs, mat):
	# A curved block (a slice of a thick ring) from angle a0 to a1: the ribs of the window cage.
	bm = bmesh.new()

	def ring(r, z):
		return [bm.verts.new((r * math.cos(a0 + (a1 - a0) * i / segs), r * math.sin(a0 + (a1 - a0) * i / segs), z)) for i in range(segs + 1)]

	ob, ib, ot, it = ring(rout, z0), ring(rin, z0), ring(rout, z1), ring(rin, z1)
	for i in range(segs):
		j = i + 1
		bm.faces.new((ob[i], ob[j], ot[j], ot[i]))
		bm.faces.new((ib[j], ib[i], it[i], it[j]))
		bm.faces.new((ot[i], ot[j], it[j], it[i]))
		bm.faces.new((ib[i], ib[j], ob[j], ob[i]))
	for e in (0, segs):
		bm.faces.new((ob[e], ot[e], it[e], ib[e]))
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	for f in bm.faces:
		f.material_index = mat
	return bm


def tube(n, r, z0, z1, mat):
	# An open, outward-facing cylinder wall (only its outside is ever seen: the windows behind the ribs).
	bm = bmesh.new()
	lo = [bm.verts.new((r * math.cos(2 * math.pi * i / n), r * math.sin(2 * math.pi * i / n), z0)) for i in range(n)]
	hi = [bm.verts.new((r * math.cos(2 * math.pi * i / n), r * math.sin(2 * math.pi * i / n), z1)) for i in range(n)]
	for i in range(n):
		j = (i + 1) % n
		f = bm.faces.new((lo[i], lo[j], hi[j], hi[i]))
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
		a = angle0 + tx / radius
		v.co = (radius * math.cos(a), radius * math.sin(a), z + ty)
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	bm.normal_update()
	for f in bm.faces:
		c = f.calc_center_median()
		if f.normal.dot(Vector((c.x, c.y, 0))) < 0:
			f.normal_flip()
		f.material_index = mat
	return bm


def build():
	mats = begin(MOD) + extra_materials()

	# ---- Body: white-grey can with a recessed window groove, a sloped shoulder up to the fuse seat, a gunmetal base
	# cap with two grip grooves, and six gunmetal-edged ribs caging the windows.
	body = Part("Body")
	body.add(lathe([
		(0.096, -0.214), (R, -0.209),
		(R, WIN0 - 0.006), (0.096, WIN0 - 0.001), (0.087, WIN0 + 0.001),  # lip into the window groove
		(0.087, WIN1 - 0.001), (0.096, WIN1 + 0.001), (R, WIN1 + 0.006),
		(R, ZS), (0.097, ZS + 0.007),  # rounded edge onto the shoulder
		(0.06, Z1 - 0.008), (0.053, Z1 - 0.002), (0.05, Z1), (0.0, Z1),
	], SEG, WHITE))
	body.add(lathe([
		(0.0, Z0 + 0.005), (0.074, Z0 + 0.005), (0.09, Z0), (0.1, Z0 + 0.003), (0.1045, Z0 + 0.011),
		(0.1045, -0.245), (0.1, -0.242), (0.1, -0.235), (0.1045, -0.232),  # grip groove
		(0.1045, -0.211), (0.099, -0.206), (0.0, -0.206),
	], SEG, GUNMETAL))
	# Ribs over the windows: flush with the can, one on +X under the lever.
	half = math.radians(7.5)
	for k in range(RIBS):
		a = 2 * math.pi * k / RIBS
		body.add(arc_block(0.08, R + 0.0015, a - half, a + half, WIN0 - 0.004, WIN1 + 0.004, 2, WHITE))
	# Stencil marking on the lower can, both sides away from the lever (+Y / -Y).
	for a0 in (math.pi / 2, -math.pi / 2):
		body.add(stencil("FROST", 0.032, a0, -0.148, R + 0.0012))
		body.add(stencil("CRYO  M7", 0.019, a0, -0.18, R + 0.0012))

	# ---- Vents: the frosted windows behind the cage (a ring in the groove). Fixed frost blue, not team-tinted.
	vents = Part("Vents")
	vents.add(tube(SEG, 0.0895, WIN0, WIN1, FROSTGLASS))

	# ---- Band: the cold-blue band under the shoulder (a raised painted ring).
	band_p = Part("Band")
	band_p.add(band(SEG, R - 0.002, R + 0.0022, 0.052, 0.084, BLUE))

	# ---- FuseHead: threaded gunmetal collar on the shoulder, fuse body, lever ears and striker head.
	fuse = Part("FuseHead")
	fuse.add(lathe([(0.0, Z1 - 0.004), (0.034, Z1 - 0.004), (0.034, Z1 + 0.01)], 16, GUNMETAL))
	fuse.add(lathe([(0.034, Z1 + 0.01), (0.044, Z1 + 0.01), (0.046, Z1 + 0.014), (0.046, Z1 + 0.032), (0.044, Z1 + 0.036), (0.037, Z1 + 0.036)], 6, GUNMETAL, rot=math.pi / 6))
	fuse.add(lathe([(0.037, Z1 + 0.036), (0.036, Z1 + 0.038), (0.036, 0.236), (0.041, 0.239), (0.041, 0.252), (0.036, 0.256), (0.0, 0.256)], 16, TRIM))
	for s in (1, -1):
		fuse.add(box(0.026, 0.056, s * 0.016, s * 0.023, 0.198, 0.236, DARK), 0.003, 1)

	# ---- Fuse_Energy: the small cap on top of the striker (team-tinted fuse glow).
	glow = Part("Fuse_Energy")
	glow.add(lathe([(0.0, 0.254), (0.021, 0.254), (0.021, 0.262)] + [(0.021 * math.cos(a), 0.262 + 0.013 * math.sin(a)) for a in (0.5, 1.0)] + [(0.0, TOP)], 14, ENERGY))

	# ---- Lever: the spoon, from its hook beside the cap, down past the ears, along the sloped shoulder and down the
	# +X rib, with a small outward kick at the end.
	lever = Part("Lever")
	lever.add(sweep([
		(0.026, 0.262, 0.026, 0.0),
		(0.044, 0.262, 0.028, 0.0),
		(0.054, 0.256, 0.03, 0.001),
		(0.06, 0.236, 0.032, 0.002),
		(0.063, 0.2, 0.034, 0.003),
		(0.066, 0.172, 0.036, 0.003),
		(0.071, 0.152, 0.038, 0.004),
		(0.09, 0.128, 0.04, 0.005),
		(0.1065, 0.108, 0.042, 0.006),
		(0.1095, 0.092, 0.042, 0.006),
		(0.1095, -0.07, 0.042, 0.006),
		(0.1115, -0.098, 0.04, 0.005),
		(0.118, -0.116, 0.036, 0.004),
	], TRIM))

	# ---- Pin: split pin through the ears (along Y) and the pull ring hanging off the +Y end.
	pin = Part("Pin")
	px, pz = 0.047, 0.217
	pin.add(lathe([(0.0035, -0.03), (0.0035, 0.032)], 8, STEEL, axis="Y", center=(px, 0, pz)))
	ring_c = Vector((px, 0.032 + 0.024 * math.cos(math.radians(35)), pz - 0.024 * math.sin(math.radians(35))))
	ring = torus(0.024, 0.0038, 16, 6, STEEL)
	pin.add(place(ring, Matrix.Translation(ring_c) @ Matrix.Rotation(math.pi / 2, 4, "Y")))
	pin.add(lathe([(0.003, 0.0), (0.003, 0.014)], 6, STEEL, axis="X", center=(px, -0.031, pz)))

	parts = [body, vents, band_p, fuse, glow, lever, pin]
	locators = [
		("Handle", (0, 0, 0), None),
		("Fuse", (0, 0, TOP), None),
	]
	return assemble(MOD, parts, mats, locators, {"kind": "thrown", "size_studs": round(TOP - Z0, 3)})


# ---------------------------------------------------------------- check render

OUT_DIR = os.path.join(ROOT, "vault", "02 Art", "References", "abilities", "frost")


def instance(col, pos, rz=0.0, rx=0.0):
	e = bpy.data.objects.new("Inst_" + col.name, None)
	e.instance_type = "COLLECTION"
	e.instance_collection = col
	bpy.context.scene.collection.objects.link(e)
	e.matrix_world = Matrix.Translation(pos) @ Matrix.Rotation(math.radians(rz), 4, "Z") @ Matrix.Rotation(math.radians(rx), 4, "X")
	return e


def render_sheet():
	# Close-up row (three angles of the Frost) and a true-scale row with the Molly, rendered as two images and
	# stacked into one JPEG with numpy (bundled with Blender).
	import numpy as np

	sc = bpy.context.scene
	frost = bpy.data.collections[MOD]
	sc.view_layers[0].layer_collection.children[MOD].exclude = True
	tmp = os.path.join(OUT_DIR, "_tmp")
	os.makedirs(tmp, exist_ok=True)

	# Row 1: three angles. The camera looks from +X (front, the lever side) slightly to the left.
	insts = [instance(frost, (0, -0.32, 0.0), 0), instance(frost, (0, 0.0, 0.0), 90), instance(frost, (0, 0.32, 0.0), 200)]
	proxy_me = bpy.data.meshes.new("_proxy")
	bm = box(-0.13, 0.13, -0.47, 0.47, Z0, TOP, SHELL)
	bm.to_mesh(proxy_me)
	bm.free()
	proxy = bpy.data.objects.new("_proxy", proxy_me)
	sc.collection.objects.link(proxy)
	stage(look_dir=(1.0, 0.08, 0.32), hover=0.0, lens=60, zoom=0.62)
	proxy.hide_render = True
	sc.view_settings.view_transform = "AgX"
	sc.view_settings.look = "AgX - Medium High Contrast"
	a = render(os.path.join(tmp, "angles.jpg"), (1800, 900))
	for o in insts + [proxy]:
		bpy.data.objects.remove(o)

	# Row 2: true scale next to the Molly (both 0.55 studs tall, pivot at the centre).
	path = blend_path("Molly")
	with bpy.data.libraries.load(path, link=False) as (src, dst):
		dst.collections = ["Molly"]
	molly = dst.collections[0]
	sc.collection.children.link(molly)
	sc.view_layers[0].layer_collection.children["Molly"].exclude = True
	insts = [instance(frost, (0, -0.17, 0.0), -20), instance(molly, (0, 0.17, 0.0), 20)]
	proxy_me = bpy.data.meshes.new("_proxy2")
	bm = box(-0.15, 0.15, -0.4, 0.4, Z0, TOP, SHELL)
	bm.to_mesh(proxy_me)
	bm.free()
	proxy = bpy.data.objects.new("_proxy2", proxy_me)
	sc.collection.objects.link(proxy)
	stage(look_dir=(1.0, 0.0, 0.3), hover=0.0, lens=120, zoom=0.82)
	proxy.hide_render = True
	sc.view_settings.view_transform = "AgX"
	sc.view_settings.look = "AgX - Medium High Contrast"
	b = render(os.path.join(tmp, "scale.jpg"), (1800, 700))

	imgs = []
	for p in (a, b):
		im = bpy.data.images.load(p)
		px = np.array(im.pixels[:], dtype=np.float32).reshape(im.size[1], im.size[0], 4)
		imgs.append(px)
	stacked = np.concatenate([imgs[1], imgs[0]], axis=0)
	out = bpy.data.images.new("frost_model", stacked.shape[1], stacked.shape[0], alpha=False)
	out.pixels.foreach_set(stacked.ravel())
	out.filepath_raw = os.path.join(OUT_DIR, "frost_model.jpg")
	out.file_format = "JPEG"
	sc.render.image_settings.quality = 92
	out.save()
	for p in (a, b):
		os.remove(p)
	os.rmdir(tmp)
	print("FROST_RENDER", out.filepath_raw)


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
