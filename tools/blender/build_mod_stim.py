# build_mod_stim.py: the Stim beacon (vault/01 Design/Abilities/Stim.md, "Look"), dropped at your feet and left there.
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup \
#       --python tools/blender/build_mod_stim.py -- [--render]
# A rugged tactical field beacon, plain and realistic (Brimstone's stim beacon as the quality read), shown deployed:
# a heavy octagonal charcoal body on a black rubber skirt, a gunmetal deck and a sloped shoulder, four side panels
# (on the diagonal faces) that have popped open and now lie as feet on the floor, their inner faces painted with
# yellow/black warning stripes, a short two-stage telescoping light mast with a caged emitter on top: an ELECTRIC
# YELLOW coil round a glowing core (Coil_Yellow) under a steel cap and a short spike (where the arcs come from).
# Front (+X): a bezel with a small team-tinted status light (Light_Energy) over a "STIM" stencil. Sides (+-Y):
# warning-stripe patches. Back: vent slots. Open pockets on the diagonal faces where the panels sat.
#
# Parts: Base, Panels, Mast, Coil_Yellow, Light_Energy. Coil_Yellow is NOT an energy part on purpose: it stays
# electric yellow (#FFD23F, Neon) for every viewer; only *_Energy parts are team-tinted. Multi-material parts are
# split on export (Base -> Base_Shell, Base_Dark, Base_Trim, Base_Hazard, Base_Stencil ...).
# Locators: Top (the spike tip: arcs / beams start here) and Floor (the floor centre = the pivot).
# Origin on the floor at the centre. Same axes as every Mod: +X forward, +Z up, +Y left, 1 unit = 1 stud.
#
# --render writes vault/02 Art/References/abilities/stim/stim_model.jpg: three angles, plus a true-scale lineup next
# to the Frost canister (art-source/abilities/Frost/Frost.blend, appended, never saved).

import os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import math
from modkit import *  # noqa: F401,F403

MOD = "Stim"
ELECTRIC_YELLOW = 0xFFD23F

OCT = math.pi / 8  # octagon corners at 22.5 + 45k degrees: flat faces at 0, 45, 90 ... (front face on +X)
R_BODY = 0.25  # body corner radius
AP_BODY = R_BODY * math.cos(OCT)  # body apothem (flat face distance)
Z_SKIRT, Z_BODY, Z_DECK, Z_SHOULDER = 0.06, 0.36, 0.385, 0.445
FACE_W = 2 * R_BODY * math.sin(OCT)  # width of one flat face

PANEL_L, PANEL_TH, PANEL_W0, PANEL_W1 = 0.18, 0.024, 0.17, 0.13  # length, thickness, width at hinge / tip
PAD_TH = 0.014
OPEN = math.radians(14)  # how far past horizontal the opened panels tip down (their tips rest on the floor)
HINGE_R = AP_BODY + 0.018
HINGE_Z = PANEL_L * math.sin(OPEN) + (PANEL_TH + PAD_TH) * math.cos(OPEN)  # pad corner exactly on the floor

CAGE_Z0, CAGE_Z1 = 0.83, 0.968  # emitter cage: ring top to cap underside
TOP_Z = 1.1
LIGHT_Z = 0.225  # status light height on the front face

# Extra matte materials (appended after modkit's six, same rbx_* look properties).
HAZARD, ELECTRIC, STEEL, STENCIL = 6, 7, 8, 9


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
		mat("Hazard", 0xE3AE1E, 0.0, 0.55, "SmoothPlastic"),  # worn safety-yellow paint (warning stripes)
		mat("Electric", ELECTRIC_YELLOW, 0.0, 0.2, "Neon", emit=2.2),  # the emitter: fixed electric yellow, Neon
		mat("Steel", 0x9A9EA4, 0.85, 0.34, "Metal"),  # bare steel: cage, spike, hinge pins
		mat("Stencil", 0xC8CBD0, 0.0, 0.7, "SmoothPlastic"),  # pale grey stencil paint
	]


# ---------------------------------------------------------------- helpers


def face_frame(phi, z, along=0.0, out=0.0, ap=AP_BODY):
	# Matrix on the flat body face at angle phi: local X = along the face (reading direction seen from outside),
	# local Y = up, local Z = out of the face.
	n = Vector((math.cos(phi), math.sin(phi), 0))
	u = Vector((-math.sin(phi), math.cos(phi), 0))
	return frame(n * (ap + out) + u * along + Vector((0, 0, z)), u, (0, 0, 1))


def clip(poly, a, b, c):
	# Sutherland-Hodgman: keep the part of a convex polygon where a*x + b*y + c >= 0.
	out = []
	n = len(poly)
	for i in range(n):
		p, q = poly[i], poly[(i + 1) % n]
		fp, fq = a * p[0] + b * p[1] + c, a * q[0] + b * q[1] + c
		if fp >= 0:
			out.append(p)
		if (fp >= 0) != (fq >= 0):
			t = fp / (fp - fq)
			out.append((p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t))
	return out


def stripes(poly, period, width, slant, z0, z1, mat=DARK, phase=0.0):
	# Diagonal warning stripes clipped to a convex polygon (in local x, y), as thin prisms from z0 to z1.
	xs = [p[0] + slant * p[1] for p in poly]
	bm = bmesh.new()
	k = math.floor((min(xs) - phase) / period) - 1
	while phase + k * period < max(xs) + period:
		s0 = phase + k * period
		# band s0 <= x + slant*y <= s0 + width
		pc = clip(poly, 1.0, slant, -s0)
		pc = clip(pc, -1.0, -slant, s0 + width) if len(pc) >= 3 else []
		if len(pc) >= 3:
			area = 0.5 * sum(pc[i][0] * pc[(i + 1) % len(pc)][1] - pc[(i + 1) % len(pc)][0] * pc[i][1] for i in range(len(pc)))
			if abs(area) > 2e-5:
				merge(bm, drop(prism(pc, "Z", z0, z1, mat), 2, -1))
		k += 1
	return bm


def hazard_patch(poly, period=0.05, width=0.022, slant=0.9, th=0.004, phase=0.0):
	# A yellow painted plate (a thin raised panel) with black diagonal stripes on it, built flat (local z = out).
	bm = drop(prism(poly, "Z", 0.0, th, HAZARD), 2, -1)
	merge(bm, stripes(poly, period, width, slant, th - 0.0005, th + 0.0015, DARK, phase))
	return bm


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


def helix(R, r, z0, z1, turns, per_turn, sides, mat):
	# A coil spring: a tube of radius r wound round Z at radius R from z0 to z1, closed at both ends.
	bm = bmesh.new()
	n = int(turns * per_turn)
	rings = []
	for i in range(n + 1):
		t = i / n
		th = 2 * math.pi * turns * t
		p = Vector((R * math.cos(th), R * math.sin(th), z0 + (z1 - z0) * t))
		tang = Vector((-R * math.sin(th) * 2 * math.pi * turns, R * math.cos(th) * 2 * math.pi * turns, z1 - z0)).normalized()
		nrm = Vector((math.cos(th), math.sin(th), 0))
		bi = tang.cross(nrm)
		rings.append([bm.verts.new(p + r * (math.cos(2 * math.pi * k / sides) * nrm + math.sin(2 * math.pi * k / sides) * bi)) for k in range(sides)])
	for a, b in zip(rings, rings[1:]):
		for k in range(sides):
			j = (k + 1) % sides
			bm.faces.new((a[k], a[j], b[j], b[k]))
	bm.faces.new(rings[0])
	bm.faces.new(rings[-1])
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	for f in bm.faces:
		f.material_index = mat
	return bm


def panel_matrix(phi):
	# Local panel frame -> world: local X along the panel from the hinge to the tip, Y across, Z up (the inner,
	# striped face); tipped down by OPEN, hinge at radius HINGE_R and height HINGE_Z on the face at angle phi.
	return rot_z(phi) @ Matrix.Translation((HINGE_R, 0, HINGE_Z)) @ Matrix.Rotation(OPEN, 4, "Y")


# ---------------------------------------------------------------- build


def build():
	mats = begin(MOD) + extra_materials()

	# ---- Base: rubber skirt, octagonal body with a raised rubber bumper band, gunmetal deck lip, sloped shoulder up
	# to the mast collar, and a steel carry bar on the back.
	base = Part("Base")
	base.add(drop(frustum(8, 0.278, 0.262, 0.0, Z_SKIRT, DARK, OCT), 2, -1), 0.012, 1)
	base.add(drop(frustum(8, R_BODY, R_BODY, Z_SKIRT - 0.01, Z_BODY, SHELL, OCT), 2, -1), 0.012, 1)
	base.add(band(8, R_BODY - 0.01, R_BODY + 0.014, 0.282, 0.318, DARK, OCT), 0.005, 1)
	base.add(drop(frustum(8, 0.258, 0.246, Z_BODY, Z_DECK, TRIM, OCT), 2, -1), 0.006, 1)
	base.add(drop(frustum(8, 0.232, 0.15, Z_DECK, Z_SHOULDER, SHELL, OCT), 2, -1), 0.01, 1)

	# Front (+X): a dark bezel for the status light, and the "STIM" stencil under it with a yellow underline.
	bz = [(-0.06, -0.045), (0.06, -0.045), (0.06, 0.045), (-0.06, 0.045)]
	base.add(place(drop(prism(bz, "Z", 0.0, 0.012, DARK), 2, -1), face_frame(0.0, LIGHT_Z)), 0.004, 1)
	base.add(place(text_flat("STIM", 0.05), face_frame(0.0, 0.135, out=0.0012)))
	base.add(place(drop(prism([(-0.07, 0.0), (0.07, 0.0), (0.07, 0.007), (-0.07, 0.007)], "Z", 0.0, 0.002, HAZARD), 2, -1), face_frame(0.0, 0.115, out=0.0004)))

	# Sides (+-Y): warning-stripe patches.
	hw = FACE_W / 2 - 0.018
	patch = [(-hw, -0.085), (hw, -0.085), (hw, 0.085), (-hw, 0.085)]
	for phi in (math.pi / 2, -math.pi / 2):
		base.add(place(hazard_patch(patch, phase=0.01), face_frame(phi, 0.17)))

	# Back (-X): three vent slots under a steel carry bar (two standoffs and the bar).
	for z in (0.12, 0.165, 0.21):
		base.add(place(drop(prism([(p[0], p[1] - z) for p in stadium(-0.06, 0.06, z, 0.02, 2)], "Z", 0.0, 0.006, DARK), 2, -1), face_frame(math.pi, z)))
	for s in (-1, 1):
		base.add(place(drop(box(-0.012, 0.012, -0.012, 0.012, 0.0, 0.045, TRIM), 2, -1), face_frame(math.pi, 0.25, along=s * 0.055) @ rot_x(0.0)))
	bar = lathe([(0.0, -0.075), (0.011, -0.075), (0.011, 0.075), (0.0, 0.075)], 8, STEEL, "X", (0, 0, 0))
	base.add(place(bar, face_frame(math.pi, 0.25, out=0.045)))

	# Diagonal faces: the open pockets the panels popped out of (dark recess plates) and the hinge leaves.
	pocket = [(-0.07, -0.1), (0.07, -0.1), (0.07, 0.1), (-0.07, 0.1)]
	for k in range(4):
		phi = math.pi / 4 + k * math.pi / 2
		base.add(place(drop(prism(pocket, "Z", 0.0, 0.004, DARK), 2, -1), face_frame(phi, 0.17)))
		base.add(place(box(AP_BODY - 0.004, HINGE_R, -0.07, 0.07, HINGE_Z - 0.012, HINGE_Z + 0.012, DARK), rot_z(phi)))

	# ---- Panels: four feet on the diagonals, tips on the floor, striped inner faces up, rubber pads, hinge pins.
	panels = Part("Panels")
	outline = [(0.0, -PANEL_W0 / 2), (PANEL_L, -PANEL_W1 / 2), (PANEL_L, PANEL_W1 / 2), (0.0, PANEL_W0 / 2)]
	inset = [(0.02, -PANEL_W0 / 2 + 0.018), (PANEL_L - 0.016, -PANEL_W1 / 2 + 0.014), (PANEL_L - 0.016, PANEL_W1 / 2 - 0.014), (0.02, PANEL_W0 / 2 - 0.018)]
	for k in range(4):
		phi = math.pi / 4 + k * math.pi / 2
		m = panel_matrix(phi)
		plate = bevel(prism(outline, "Z", -PANEL_TH, 0.0, SHELL), 0.006, 1)
		panels.add(place(plate, m))
		stripe = hazard_patch(inset, period=0.046, width=0.021, slant=1.0, th=0.003, phase=0.0)
		panels.add(place(stripe, m))
		pad = drop(box(PANEL_L - 0.05, PANEL_L - 0.004, -0.058, 0.058, -PANEL_TH - PAD_TH, -PANEL_TH, DARK), 2, 1)
		panels.add(place(pad, m))
		pin = lathe([(0.0, -0.078), (0.014, -0.078), (0.014, 0.078), (0.0, 0.078)], 8, STEEL, "Y", (0.0, 0, -PANEL_TH / 2))
		panels.add(place(pin, m))

	# ---- Mast: collar on the shoulder, two stout telescoping stages, the emitter ring, a 4-bar cage, the cap and spike.
	mast = Part("Mast")
	mast.add(lathe([
		(0.0, Z_SHOULDER - 0.005), (0.1, Z_SHOULDER - 0.005), (0.1, Z_SHOULDER + 0.03), (0.086, Z_SHOULDER + 0.042),
		(0.06, Z_SHOULDER + 0.042), (0.06, 0.64), (0.074, 0.645), (0.074, 0.675), (0.048, 0.68),
		(0.048, 0.79), (0.094, 0.794), (0.1, 0.806), (0.1, CAGE_Z0), (0.0, CAGE_Z0),
	], 12, TRIM, rot=math.pi / 12))
	for k in range(4):
		a = math.pi / 4 + k * math.pi / 2
		bar = drop(drop(box(-0.008, 0.008, -0.008, 0.008, CAGE_Z0 - 0.002, CAGE_Z1 + 0.002, STEEL), 2, 1), 2, -1)
		mast.add(place(bar, rot_z(a) @ Matrix.Translation((0.089, 0, 0))))
	mast.add(lathe([
		(0.0, CAGE_Z1), (0.104, CAGE_Z1), (0.104, CAGE_Z1 + 0.02), (0.082, CAGE_Z1 + 0.036),
		(0.014, CAGE_Z1 + 0.044), (0.011, TOP_Z - 0.02), (0.0, TOP_Z),
	], 12, DARK, rot=math.pi / 12))

	# ---- Coil_Yellow: the electric-yellow emitter, a coil round a glowing core inside the cage (fixed colour).
	coil = Part("Coil_Yellow")
	coil.add(helix(0.06, 0.0085, CAGE_Z0 + 0.014, CAGE_Z1 - 0.014, 3.5, 10, 5, ELECTRIC))
	coil.add(capsule(0.028, CAGE_Z1 - CAGE_Z0 - 0.004, 10, 2, ELECTRIC, "Z", (0, 0, (CAGE_Z0 + CAGE_Z1) / 2)))

	# ---- Light_Energy: the small team-tinted status light in the front bezel.
	light = Part("Light_Energy")
	dome = lathe([(0.0, 0.0), (0.022, 0.0), (0.022, 0.006), (0.017, 0.013), (0.009, 0.0165), (0.0, 0.0175)], 10, ENERGY)
	light.add(place(dome, face_frame(0.0, LIGHT_Z, out=0.011) @ Matrix.Identity(4)))

	parts = [base, panels, mast, coil, light]
	locators = [
		("Top", (0, 0, TOP_Z), None),
		("Floor", (0, 0, 0), None),
	]
	return assemble(MOD, parts, mats, locators, {"kind": "placed", "size_studs": round(TOP_Z, 3)})


# ---------------------------------------------------------------- check render

OUT_DIR = os.path.join(ROOT, "vault", "02 Art", "References", "abilities", "stim")


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
	# Rows stacked into one JPEG with numpy (bundled with Blender): three angles (front three-quarter, the side, high
	# from behind), a top-down-ish view as players mostly see it, and a true-scale lineup with the Frost canister.
	# The camera looks from +Y (the left side) slightly forward, so +X is screen left.
	import numpy as np

	stim = bpy.data.collections[MOD]
	bpy.context.scene.collection.children.unlink(stim)
	with bpy.data.libraries.load(blend_path("Frost"), link=False) as (src, dst):
		dst.collections = ["Frost"]
	frost = dst.collections[0]
	os.makedirs(os.path.join(OUT_DIR, "_tmp"), exist_ok=True)
	paths = []

	# Front three-quarter (status light), the right side, the back (vents, carry bar).
	insts = [instance(stim, (1.0, 0.0, 0.0), 60), instance(stim, (0.0, 0.0, 0.0), 0), instance(stim, (-1.0, 0.0, 0.0), -120)]
	paths.append(shot("angles", insts, (-1.45, 1.45, -0.45, 0.45, 0.0, 1.12), (0.0, 1.0, 0.32), 60, 0.62, (1800, 760)))

	# From high up (how players mostly see it on the floor).
	insts = [instance(stim, (0.55, 0.0, 0.0), 75), instance(stim, (-0.55, 0.0, 0.0), 10)]
	paths.append(shot("above", insts, (-1.0, 1.0, -0.45, 0.45, 0.0, 1.12), (0.0, 1.0, 1.4), 60, 0.62, (1800, 760)))

	# True scale: both on the floor (the Frost by its bottom: pivot at its centre, 0.55 tall).
	insts = [instance(stim, (0.3, 0.0, 0.0), 70), instance(frost, (-0.42, 0.0, 0.275), 70)]
	paths.append(shot("scale", insts, (-0.75, 0.75, -0.45, 0.45, 0.0, 1.12), (0.0, 1.0, 0.22), 85, 0.82, (1800, 700)))

	imgs = []
	for p in paths:
		im = bpy.data.images.load(p)
		imgs.append(np.array(im.pixels[:], dtype=np.float32).reshape(im.size[1], im.size[0], 4))
	stacked = np.concatenate(imgs[::-1], axis=0)  # Blender pixel rows run bottom-up
	out = bpy.data.images.new("stim_model", stacked.shape[1], stacked.shape[0], alpha=False)
	out.pixels.foreach_set(stacked.ravel())
	out.filepath_raw = os.path.join(OUT_DIR, "stim_model.jpg")
	out.file_format = "JPEG"
	bpy.context.scene.render.image_settings.quality = 92
	out.save()
	for p in paths:
		os.remove(p)
	os.rmdir(os.path.join(OUT_DIR, "_tmp"))
	print("STIM_RENDER", out.filepath_raw)


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
