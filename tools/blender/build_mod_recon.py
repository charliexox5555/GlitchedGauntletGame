# build_mod_recon.py: the Recon dart launcher (vault/01 Design/Abilities/Recon.md, "Look"), a first-person viewmodel
# item like the Patch Up: the gun lowers, this comes up with a sensor dart loaded, hold to charge, release to fire.
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup \
#       --python tools/blender/build_mod_recon.py -- [--render]
# Build tools/blender/build_mod_recondart.py first: this script imports its dart (dart_parts) and its --render draws
# the stuck dart too.
#
# A compact, chunky flare-gun-style launcher, plain and realistic (Sova's recon bolt as the read, no bow): a matte
# dark-polymer frame with a raked pistol grip and a big trigger guard, a short large-bore gunmetal barrel that breaks
# open on a steel hinge pin under the breech, an octagonal polymer shroud with side vents and a short top rail, a
# muzzle collar with a front sight, and the dart's head and point sticking out of the muzzle. Two read-outs for the
# shooter: a charge light bar in a channel on top (Charge_Energy: code fills / brightens it while charging) and two
# round bounce lights on the sloped back plate (Bounce1_Energy left, Bounce2_Energy right as the shooter sees them:
# code lights 0 / 1 / 2). Small grey "RECON" stencil on the left side.
#
# Parts: Grip, Body (frame, side plates, charge channel, back plate, latch, hinge pin, screws), Barrel (tube, collar,
# shroud, vents, rail, sight, hinge lug), Dart (the loaded dart; code hides it when fired), Charge_Energy,
# Bounce1_Energy, Bounce2_Energy. Multi-material parts are split on export (Body -> Body_Polymer, Body_Dark ...;
# Dart -> Dart_Steel, Dart_Gunmetal, Dart_Dark, Dart_Polymer, Dart_Lens), so code finds the dart as every part named
# "Dart" or starting with "Dart_".
# Locators: Handle (the grip; the builder adds RightGrip = Handle), LeftGrip (pistol support hand, like the Patch Up)
# and Muzzle (barrel tip on the bore axis; its LookVector is forward: the dart leaves here).
# Origin at the grip. Same axes as every Mod: +X forward, +Z up, +Y left, 1 unit = 1 stud. No HoldOffset (held by
# the grip like the Patch Up).
#
# --render writes vault/02 Art/References/abilities/recon/recon_model.jpg: the launcher from two angles, the dart from
# two angles, and a true-scale lineup with the Patch Up (art-source/abilities/PatchUp/PatchUp.blend, appended, never
# saved).

import os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import math
from modkit import *  # noqa: F401,F403
from build_mod_recondart import POLY, GUNMETAL, STEEL, LENS, STENCIL, dart_parts, extra_materials  # noqa: E402

MOD = "Recon"
AXIS_Z = 0.2  # height of the bore axis
MUZZLE_X = 0.765  # front face of the muzzle collar
PROTRUDE = 0.19  # how far the loaded dart's point sticks out of the muzzle
BACK = (-0.28, 0.235, -0.15, 0.335)  # back plate slope: (x, z) bottom to (x, z) top


def text_side(text, size, x0, z0, y, mat=STENCIL):
	# Flat stencil lettering on the +Y (left) side, reading left to right when seen from +Y (so along -X).
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
		v.co = (x0 - v.co.x, y, z0 + v.co.y)
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	bm.normal_update()
	for f in bm.faces:
		if f.normal.y < 0:
			f.normal_flip()
		f.material_index = mat
	return bm


def back_frame(along=0.0, across=0.0, out=0.0):
	# Matrix on the sloped back plate: local X up the slope, local Y = +Y (left), local Z = out of the plate.
	x0, z0, x1, z1 = BACK
	u = Vector((x1 - x0, 0, z1 - z0)).normalized()
	n = Vector((-u.z, 0, u.x))
	mid = Vector(((x0 + x1) / 2, 0, (z0 + z1) / 2))
	return frame(mid + u * along + Vector((0, across, 0)) + n * out, u, (0, 1, 0))


def build():
	mats = begin(MOD) + extra_materials()

	# ---- Grip: raked polymer grip with stippled dark side panels, a flared base, the trigger and a chunky guard.
	grip = Part("Grip")
	grip.add(prism([(-0.165, -0.40), (0.035, -0.40), (0.095, 0.07), (-0.115, 0.07)], "Y", -0.08, 0.08, POLY), 0.03, 2)
	grip.add(mirror_y(prism([(-0.135, -0.33), (0.008, -0.33), (0.055, 0.0), (-0.092, 0.0)], "Y", 0.076, 0.087, DARK)), 0.007, 1)
	for z in (-0.27, -0.19, -0.11):  # finger ridges down the front strap
		x = 0.035 + (z + 0.40) / 0.47 * 0.06
		grip.add(prism([(x - 0.01, z - 0.012), (x + 0.012, z - 0.006), (x + 0.012, z + 0.006), (x - 0.01, z + 0.012)], "Y", -0.06, 0.06, POLY))
	grip.add(box(-0.19, 0.06, -0.092, 0.092, -0.445, -0.385, DARK), 0.022, 1)  # flared base
	grip.add(prism([(0.1, 0.06), (0.14, 0.06), (0.132, -0.02), (0.112, -0.052), (0.1, -0.056), (0.106, -0.02)], "Y", -0.02, 0.02, TRIM), 0.006, 1)  # trigger
	grip.add(prism([(0.04, -0.09), (0.255, -0.09), (0.255, 0.07), (0.2, 0.07), (0.2, -0.04), (0.04, -0.04)], "Y", -0.032, 0.032, DARK), 0.016, 2)

	# ---- Body: the frame (sloped back plate), side plates, the charge channel on top, latch, hinge pin, screws.
	x0, z0, x1, z1 = BACK
	body = Part("Body")
	body.add(prism([(x0, 0.05), (0.155, 0.05), (0.155, z1), (x1, z1), (x0, z0)], "Y", -0.105, 0.105, POLY), 0.03, 2)
	body.add(mirror_y(prism([(-0.21, 0.09), (0.11, 0.09), (0.11, 0.285), (-0.12, 0.285), (-0.21, 0.215)], "Y", 0.1, 0.112, DARK)), 0.008, 1)
	# Charge channel: two rails and two end blocks around the light bar; the rear block carries a sight notch.
	body.add(mirror_y(box(-0.115, 0.095, 0.026, 0.05, 0.32, 0.383, DARK)), 0.008, 1)
	body.add(box(0.095, 0.13, -0.05, 0.05, 0.32, 0.392, DARK), 0.01, 1)
	notch = [(-0.05, 0.32), (0.05, 0.32), (0.05, 0.4), (0.012, 0.4), (0.012, 0.372), (-0.012, 0.372), (-0.012, 0.4), (-0.05, 0.4)]
	body.add(prism(notch, "X", -0.15, -0.115, DARK), 0.006, 1)  # rear block with the sight notch
	# Back plate bezel around the two bounce lights, with a gunmetal ring round each light.
	bez = box(-0.055, 0.055, -0.075, 0.075, -0.012, 0.007, DARK)
	body.add(place(bez, back_frame()), 0.006, 1)
	for s in (1, -1):
		ring = band(10, 0.0165, 0.022, 0.0, 0.007, GUNMETAL)
		body.add(place(ring, back_frame(0.0, s * 0.036, 0.007)))
	# Break-open latch on the left side, just behind the breech.
	body.add(prism([(0.035, 0.245), (0.145, 0.262), (0.15, 0.292), (0.045, 0.288)], "Y", 0.104, 0.122, GUNMETAL), 0.006, 1)
	# Hinge pin under the breech (through the frame, heads proud on both sides).
	body.add(lathe([(0.0, -0.118), (0.026, -0.118), (0.026, 0.118), (0.0, 0.118)], 12, STEEL, "Y", (0.135, 0, 0.088)))
	for x, z in ((-0.17, 0.12), (0.07, 0.12), (0.07, 0.255)):  # side plate screws
		s = lathe([(0.0, 0.0), (0.011, 0.0), (0.011, 0.005), (0.0, 0.005)], 6, STEEL, "Y", (x, 0.112, z))
		body.add(mirror_y(s))
	body.add(text_side("RECON", 0.04, -0.045, 0.165, 0.1125))

	# ---- Barrel: large-bore gunmetal tube (bore stops halfway: the dart sits in it), muzzle collar with a front
	# sight, an octagonal polymer shroud with vents and a short top rail, and the hinge lug under the breech.
	barrel = Part("Barrel")
	barrel.add(lathe([
		(0.0, 0.13), (0.088, 0.13), (0.088, 0.688), (0.104, 0.696), (0.104, MUZZLE_X - 0.008), (0.094, MUZZLE_X),
		(0.062, MUZZLE_X), (0.052, MUZZLE_X - 0.01), (0.052, 0.45), (0.0, 0.45),
	], 16, GUNMETAL, "X", (0, 0, AXIS_Z)))
	shroud = band(8, 0.086, 0.114, 0.0, 0.36, POLY, rot=math.pi / 8)
	barrel.add(place(shroud, axis_matrix("X", (0.17, 0, AXIS_Z))), 0.01, 1)
	ap = 0.114 * math.cos(math.pi / 8)  # shroud flat (apothem)
	for xa, xb in ((0.2, 0.27), (0.3, 0.37), (0.4, 0.47)):  # vent slots on both side flats
		barrel.add(mirror_y(prism(stadium(xa, xb, AXIS_Z, 0.034, 2), "Y", ap - 0.002, ap + 0.004, DARK)))
	barrel.add(box(0.22, 0.5, -0.026, 0.026, AXIS_Z + ap - 0.004, AXIS_Z + ap + 0.012, GUNMETAL), 0.004, 1)  # rail base
	for k in range(6):  # rail teeth
		xa = 0.235 + k * 0.045
		barrel.add(drop(box(xa, xa + 0.025, -0.026, 0.026, AXIS_Z + ap + 0.012, AXIS_Z + ap + 0.024, GUNMETAL), 2, -1))
	barrel.add(prism([(0.705, AXIS_Z + 0.1), (0.755, AXIS_Z + 0.1), (0.748, AXIS_Z + 0.138), (0.722, AXIS_Z + 0.138)], "Y", -0.009, 0.009, GUNMETAL), 0.003, 1)  # front sight
	barrel.add(box(0.1, 0.235, -0.05, 0.05, 0.055, AXIS_Z - 0.06, GUNMETAL), 0.014, 1)  # hinge lug

	# ---- Dart: the loaded sensor dart (same geometry as ReconDart), point out of the muzzle; its light is unlit glass.
	dart = Part("Dart")
	at = Matrix.Translation((MUZZLE_X + PROTRUDE, 0, AXIS_Z))
	for bm in dart_parts(LENS, loaded=True).values():
		dart.add(place(bm, at))

	# ---- Energy read-outs.
	charge = Part("Charge_Energy")
	charge.add(capsule(0.019, 0.205, 14, 3, ENERGY, "X", (-0.01, 0, 0.362)))
	bounces = []
	for name, s in (("Bounce1_Energy", 1), ("Bounce2_Energy", -1)):
		p = Part(name)
		dome = lathe([(0.0, 0.0), (0.0168, 0.0), (0.0168, 0.004), (0.014, 0.009), (0.008, 0.0118), (0.0, 0.0125)], 10, ENERGY)
		p.add(place(dome, back_frame(0.0, s * 0.036, 0.003)))
		bounces.append(p)

	parts = [grip, body, barrel, dart, charge] + bounces
	locators = [
		("Handle", (0, 0, 0), None),
		("LeftGrip", (-0.02, 0, -0.15), None),
		("Muzzle", (MUZZLE_X, 0, AXIS_Z), Matrix.Identity(4)),
	]
	return assemble(MOD, parts, mats, locators, {"kind": "handheld", "size_studs": round(MUZZLE_X - BACK[0], 3)})


# ---------------------------------------------------------------- check render

OUT_DIR = os.path.join(ROOT, "vault", "02 Art", "References", "abilities", "recon")


def instance(col, pos, rz=0.0, rx=0.0, ry=0.0):
	e = bpy.data.objects.new("Inst_" + col.name, None)
	e.instance_type = "COLLECTION"
	e.instance_collection = col
	bpy.context.scene.collection.objects.link(e)
	e.matrix_world = Matrix.Translation(pos) @ Matrix.Rotation(math.radians(rz), 4, "Z") @ Matrix.Rotation(math.radians(ry), 4, "Y") @ Matrix.Rotation(math.radians(rx), 4, "X")
	return e


def proxy(name, x0, x1, y0, y1, z0, z1):
	me = bpy.data.meshes.new(name)
	bm = box(x0, x1, y0, y1, z0, z1, SHELL)
	bm.to_mesh(me)
	bm.free()
	ob = bpy.data.objects.new(name, me)
	bpy.context.scene.collection.objects.link(ob)
	return ob


def append(mod):
	with bpy.data.libraries.load(blend_path(mod), link=False) as (src, dst):
		dst.collections = [mod]
	return dst.collections[0]  # not linked to the scene: only drawn through collection instances


def shot(name, insts, box_, look_dir, lens, zoom, res, hover=0.0):
	sc = bpy.context.scene
	pr = proxy("_proxy_" + name, *box_)
	stage(look_dir=look_dir, hover=hover, lens=lens, zoom=zoom)
	pr.hide_render = True
	sc.view_settings.view_transform = "AgX"
	sc.view_settings.look = "AgX - Medium High Contrast"
	path = render(os.path.join(OUT_DIR, "_tmp", name + ".jpg"), res)
	for o in insts + [pr]:
		bpy.data.objects.remove(o)
	return path


def render_sheet():
	# Three rows stacked into one JPEG with numpy (bundled with Blender): the launcher from two angles (left side as
	# the shooter sees it, and from behind and above, where the read-outs face), the dart from two angles, and a
	# true-scale lineup Patch Up | Recon | ReconDart. The camera looks from +Y (the left side), so +X is screen left.
	import numpy as np

	# The sources leave the scene (the .blend is already saved) so only the instances are drawn and framed.
	recon = bpy.data.collections[MOD]
	bpy.context.scene.collection.children.unlink(recon)
	dart = append("ReconDart")
	patch = append("PatchUp")
	os.makedirs(os.path.join(OUT_DIR, "_tmp"), exist_ok=True)
	paths = []

	insts = [instance(recon, (0.78, 0.0, 0.0), 8), instance(recon, (-0.8, 0.0, 0.0), -128)]
	paths.append(shot("launcher", insts, (-1.55, 1.55, -0.5, 0.5, -0.46, 0.42), (0.18, 1.0, 0.5), 60, 0.62, (1800, 820), hover=0.12))

	insts = [instance(dart, (0.98, 0.0, 0.0), 0), instance(dart, (-0.1, 0.0, 0.0), -28, rx=25, ry=-10)]
	paths.append(shot("dart", insts, (-1.05, 1.05, -0.3, 0.3, -0.1, 0.1), (0.1, 1.0, 0.35), 60, 0.6, (1800, 560), hover=0.08))

	# True scale: everything rests on the floor (z = 0), Patch Up and Recon by their grip base, the dart lying flat.
	insts = [instance(patch, (1.45, 0.0, 0.445), 0), instance(recon, (0.0, 0.0, 0.445), 0), instance(dart, (-0.62, 0.0, 0.0495), 0, rx=90)]
	paths.append(shot("scale", insts, (-1.6, 2.35, -0.3, 0.3, 0.0, 0.85), (0.0, 1.0, 0.22), 85, 0.66, (1800, 700)))

	imgs = []
	for p in paths:
		im = bpy.data.images.load(p)
		imgs.append(np.array(im.pixels[:], dtype=np.float32).reshape(im.size[1], im.size[0], 4))
	stacked = np.concatenate(imgs[::-1], axis=0)  # Blender pixel rows run bottom-up
	out = bpy.data.images.new("recon_model", stacked.shape[1], stacked.shape[0], alpha=False)
	out.pixels.foreach_set(stacked.ravel())
	out.filepath_raw = os.path.join(OUT_DIR, "recon_model.jpg")
	out.file_format = "JPEG"
	bpy.context.scene.render.image_settings.quality = 92
	out.save()
	for p in paths:
		os.remove(p)
	os.rmdir(os.path.join(OUT_DIR, "_tmp"))
	print("RECON_RENDER", out.filepath_raw)


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
