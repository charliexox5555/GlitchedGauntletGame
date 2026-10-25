# make_arm_mesh.py: the first-person arm blocks (RIVALS style, Gunplay.md §6).
#
#   blender --background --factory-startup --python tools/blender/make_arm_mesh.py
#
# Writes art-source/viewmodel/Arms.fbx with two meshes, ArmRight and ArmLeft:
# one long block per arm (1 x LENGTH x 1 studs, R6 cross-section) with softly
# bevelled edges and smooth shading. UVs map each side onto that arm's region
# of the classic Roblox shirt template (585 x 559), so the game can lay the
# player's Shirt over the skin-coloured block. The template's 128 px arm
# height covers the TEMPLATE_SPAN studs nearest the hand (R6: 2 studs); the
# rest of the block, toward the shoulder, repeats the template's top row.
#
# Axes (Roblox space after import): +Y toward the shoulder, the hand end at
# -Y, front -Z, character right +X. Blender: X = X, Z = Roblox Y, Y = -Roblox Z.

import os

import bmesh
import bpy

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art-source", "viewmodel", "Arms.fbx")

LENGTH = 5.0
TEMPLATE_SPAN = 2.0
BEVEL = 0.16
BEVEL_SEGMENTS = 5
SIZE = (585.0, 559.0)

# Template regions (top-left px) of each arm face on the classic shirt template
# (checked against Roblox's own R6 clothing in Studio).
FACES = {
	"ArmRight": {"F": (217, 355), "R": (151, 355), "B": (85, 355), "L": (19, 355), "U": (217, 289), "D": (217, 485)},
	"ArmLeft": {"F": (308, 355), "L": (374, 355), "B": (440, 355), "R": (506, 355), "U": (308, 289), "D": (308, 485)},
}


def to_roblox(v):
	return (v.x, v.z, -v.y)


def face_key(n):
	x, y, z = to_roblox(n)
	ax = max((abs(x), "x"), (abs(y), "y"), (abs(z), "z"))[1]
	if ax == "x":
		return "R" if x > 0 else "L"
	if ax == "y":
		return "U" if y > 0 else "D"
	return "B" if z > 0 else "F"


def uv_for(key, p, regions):
	x, y, z = p
	x0, y0 = regions[key]
	half = LENGTH / 2
	# Side faces: u across the face as seen from outside, v down the arm.
	if key in ("F", "B", "R", "L"):
		u = {"F": 0.5 - x, "B": x + 0.5, "R": 0.5 - z, "L": z + 0.5}[key]
		t = (y + half) / TEMPLATE_SPAN  # 0 at the hand end, 1 at the span's top
		v = 1 - min(max(t, 0), 1)
		px, py = x0 + u * 64, y0 + v * 128
	elif key == "U":
		px, py = x0 + (0.5 - x) * 64, y0 + (0.5 - z) * 64
	else:
		# D, the hand-end cap: the sleeve's bottom row (front face), so the
		# cap and its bevels match the end of the sleeve (the template's own
		# D square is often unpainted and shows as dark specks on the bevels).
		fx, fy = regions["F"]
		px, py = fx + (0.5 - x) * 64, fy + 126
	return (px / SIZE[0], 1 - py / SIZE[1])


def make(name):
	bm = bmesh.new()
	bmesh.ops.create_cube(bm, size=1.0)
	for v in bm.verts:
		v.co.z *= LENGTH  # Blender Z = Roblox Y (arm length)
	# A loop where the template span ends, so the mapping bends there.
	cut_z = -LENGTH / 2 + TEMPLATE_SPAN
	geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
	bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(0, 0, cut_z), plane_no=(0, 0, 1))
	corner_edges = [e for e in bm.edges if e.calc_face_angle(0) > 0.5]
	bmesh.ops.bevel(
		bm,
		geom=corner_edges,
		offset=BEVEL,
		offset_type="OFFSET",
		segments=BEVEL_SEGMENTS,
		profile=0.5,
		affect="EDGES",
		clamp_overlap=True,
	)
	bmesh.ops.triangulate(bm, faces=bm.faces[:])
	uv = bm.loops.layers.uv.new("UVMap")
	regions = FACES[name]
	for f in bm.faces:
		key = face_key(f.normal)
		for loop in f.loops:
			loop[uv].uv = uv_for(key, to_roblox(loop.vert.co), regions)
	mesh = bpy.data.meshes.new(name)
	bm.to_mesh(mesh)
	bm.free()
	for p in mesh.polygons:
		p.use_smooth = True
	obj = bpy.data.objects.new(name, mesh)
	bpy.context.scene.collection.objects.link(obj)
	# Smooth shading across the bevels, crisp nowhere.
	mod = obj.modifiers.new("WeightedNormal", "WEIGHTED_NORMAL")
	mod.keep_sharp = False
	return obj


def main():
	bpy.ops.wm.read_factory_settings(use_empty=True)
	objs = [make(n) for n in FACES]
	bpy.ops.object.select_all(action="DESELECT")
	for o in objs:
		o.select_set(True)
	bpy.context.view_layer.objects.active = objs[0]
	os.makedirs(os.path.dirname(OUT), exist_ok=True)
	bpy.ops.export_scene.fbx(
		filepath=OUT,
		use_selection=True,
		object_types={"MESH"},
		apply_scale_options="FBX_SCALE_UNITS",
		use_mesh_modifiers=True,
		mesh_smooth_type="FACE",
	)
	print("wrote", OUT)


main()
