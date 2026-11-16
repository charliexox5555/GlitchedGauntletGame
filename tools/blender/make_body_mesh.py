# make_body_mesh.py: the third-person block body (vault/01 Design/Third Person
# Overhaul.md §3).
#
#   blender --background --factory-startup --python tools/blender/make_body_mesh.py
#
# Writes art-source/body/BlockBody.fbx (ten meshes) and BlockBody.json (each
# mesh's size and the offset of its centre from the R15 part it is welded to:
# Roblox re-centres an imported mesh on its bounds). shared/MatchBody welds one
# block over each R15 part of the standard match body; the engine's own parts
# stay as the rig and the hitboxes, invisible.
#
# Shapes (same language as the first-person arm, make_arm_mesh.py: a sharp
# block, one 0.035 chamfer, flat faces):
#   UpperArm      flat top; the elbow end is a mitre (two 45-degree plates) on
#                 the elbow's axis, so a bend closes into a chamfered corner
#                 instead of a gap.
#   LowerArm      forearm AND hand as one block to the fingertips; mitre at
#                 the elbow.
#   UpperLeg      mitres at the hip and the knee.
#   LowerLeg      shin AND foot as one block to the sole; mitre at the knee.
#   UpperTorso    the chest block.
#   LowerTorso    the hips, plus an inset band reaching up into the chest so a
#                 lean at the waist shows a band, not a hole.
# Straight, every cap hides inside its neighbour. The lower segment of each
# limb is a hair wider (LOWER_EXTRA) and the torso a hair wider than the limbs
# (TORSO_EXTRA), so faces that would lie in one plane never flicker.
#
# UVs sit on the classic clothing template (585 x 559) by each point's place
# in the straight limb. The game doesn't use them (a mesh texture draws a
# template's clear areas black): shared/MatchBody lays the Shirt and Pants on
# with one Texture per face instead, cropped by the same numbers
# (Config/Avatar BLOCKS t0 / t1, CLOTH_REGIONS). They are kept for tools that
# want the mesh textured.
#
# Numbers: the standard match body's parts and rig attachments (R15 blocky,
# all scales standard; read in Studio 2026-11-12). Roblox part space: +Y up,
# -Z front, +X the character's right. Blender: X = X, Z = Roblox Y, Y = -Roblox Z.

import json
import math
import os

import bmesh
import bpy
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_DIR = os.path.join(ROOT, "art-source", "body")
OUT = os.path.join(OUT_DIR, "BlockBody.fbx")
OUT_JSON = os.path.join(OUT_DIR, "BlockBody.json")

BEVEL = 0.035
LOWER_EXTRA = 0.006  # half-width added to forearms and shins
TORSO_EXTRA = 0.006  # half-width added to the torso blocks
SIZE = (585.0, 559.0)
R = 0.5  # joint cap radius = half a limb's depth

# Rig numbers (part-local Y of each joint, part half-heights).
UA_TOP, UA_ELBOW = 0.5843, -0.3341
LA_ELBOW, LA_TIP = 0.2587, -0.5009 - 0.275
UL_HIP, UL_KNEE = 0.4208, -0.4010
LL_KNEE, LL_SOLE = 0.3790, -0.5472 - 0.1019 - 0.15
ARM_LEN = (UA_TOP - UA_ELBOW) + (LA_ELBOW - LA_TIP)
LEG_LEN = (UL_HIP - UL_KNEE) + (LL_KNEE - LL_SOLE)
TORSO_LEN = 2.0
BAND = 0.35  # how far the hips' inset band reaches up into the chest
BAND_INSET = 0.03

# Template regions (top-left px). Limbs: 64 x 128 sides, 64 x 64 ends.
RIGHT_LIMB = {"F": (217, 355), "R": (151, 355), "B": (85, 355), "L": (19, 355), "U": (217, 289), "D": (217, 485)}
LEFT_LIMB = {"F": (308, 355), "L": (374, 355), "B": (440, 355), "R": (506, 355), "U": (308, 289), "D": (308, 485)}
# Torso: 128 x 128 front and back, 64 x 128 sides, 128 x 64 top and bottom.
TORSO = {"F": (231, 74), "R": (165, 74), "L": (361, 74), "B": (427, 74), "U": (231, 8), "D": (231, 204)}


def cap(y0, sign):
	"""The joint end of a limb block, round the joint at height y0, pointing up
	(sign +1) or down (-1): a mitre, two 45-degree plates meeting in a ridge
	along the joint's axis, half a limb's depth past the pivot. Both segments
	of a joint share the pivot, so at a right-angle bend the two mitres make
	one clean chamfered corner, and straight they hide inside each other.
	(v1 was a half-octagon, four plates an end: bent arms read as a lump of
	facets, "crumpled boulders", owner 2026-11-12.) Returns the ridge point
	(z, y)."""
	return [(0.0, y0 + sign * R)]


def limb_profile(top, bottom, top_cap, bottom_cap):
	"""(z, y) outline of a limb block, counter-clockwise seen from +X."""
	out = []
	# Up the back face (z = +R), over the top, down the front (z = -R), under.
	out.append((R, bottom))
	out.append((R, top))
	if top_cap:
		out += cap(top, 1)
	out.append((-R, top))
	out.append((-R, bottom))
	if bottom_cap:
		out += [(-z, y) for (z, y) in cap(bottom, -1)]
	return out


def prism(profile, half_x):
	bm = bmesh.new()
	left = [bm.verts.new((-half_x, -z, y)) for (z, y) in profile]  # Blender (x, -Rz, Ry)
	right = [bm.verts.new((half_x, -z, y)) for (z, y) in profile]
	n = len(profile)
	bm.faces.new(left)
	bm.faces.new(list(reversed(right)))
	for i in range(n):
		j = (i + 1) % n
		bm.faces.new((left[j], left[i], right[i], right[j]))
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	return bm


def box(bm, x, y0, y1, z):
	"""Adds a box (Roblox half-width x, y0..y1, half-depth z) to bm."""
	made = bmesh.ops.create_cube(bm, size=1.0)
	for v in made["verts"]:
		v.co.x *= 2 * x
		v.co.y *= 2 * z
		v.co.z = (y0 + y1) / 2 + v.co.z * (y1 - y0)


def to_roblox(v):
	return (v.x, v.z, -v.y)


def finish(bm, name, uv_of):
	sharp = [e for e in bm.edges if len(e.link_faces) == 2 and e.calc_face_angle(0) > 0.3]
	bmesh.ops.bevel(
		bm, geom=sharp, offset=BEVEL, offset_type="OFFSET", segments=1, profile=0.5, affect="EDGES", clamp_overlap=True
	)
	bmesh.ops.triangulate(bm, faces=bm.faces[:])
	uv = bm.loops.layers.uv.new("UVMap")
	for f in bm.faces:
		n = to_roblox(f.normal)
		for loop in f.loops:
			px, py = uv_of(n, to_roblox(loop.vert.co))
			loop[uv].uv = (px / SIZE[0], 1 - py / SIZE[1])
	lo = Vector((min(v.co.x for v in bm.verts), min(v.co.y for v in bm.verts), min(v.co.z for v in bm.verts)))
	hi = Vector((max(v.co.x for v in bm.verts), max(v.co.y for v in bm.verts), max(v.co.z for v in bm.verts)))
	mesh = bpy.data.meshes.new(name)
	bm.to_mesh(mesh)
	bm.free()
	# Flat faces, hard edges: sharp blocks (smooth normals across the mitres
	# and chamfers shaded the joints like pebbles).
	for p in mesh.polygons:
		p.use_smooth = False
	obj = bpy.data.objects.new(name, mesh)
	bpy.context.scene.collection.objects.link(obj)
	centre = (lo + hi) / 2
	size = hi - lo
	info = {
		# Roblox space: the mesh centre in the part's frame, and its size.
		"offset": [round(centre.x, 5), round(centre.z, 5), round(-centre.y, 5)],
		"size": [round(size.x, 5), round(size.z, 5), round(size.y, 5)],
	}
	return obj, info


def clamp01(t):
	return min(max(t, 0.0), 1.0)


def limb_uv(regions, dist_of, length, half_x):
	"""UVs for a limb block: `dist_of(y)` = how far down the straight limb the
	point sits (0 at its top, `length` at its end)."""

	def uv(n, p):
		x, y, z = p
		nx, ny, nz = n
		t = clamp01(dist_of(y) / length)
		u_x = clamp01(0.5 - x / (2 * half_x))  # across, seen from the front
		if abs(nx) > 0.7:
			key = "R" if nx > 0 else "L"
			u = clamp01(0.5 - z) if nx > 0 else clamp01(z + 0.5)
			return regions[key][0] + u * 64, regions[key][1] + t * 128
		if abs(ny) > 0.95:
			if ny > 0:
				return regions["U"][0] + u_x * 64, regions["U"][1] + clamp01(0.5 - z) * 64
			# The free end: the front face's last row, so the cap matches the
			# cuff (the template's own end square is often unpainted).
			return regions["F"][0] + u_x * 64, regions["F"][1] + 126
		if nz <= 0:
			return regions["F"][0] + u_x * 64, regions["F"][1] + t * 128
		return regions["B"][0] + (1 - u_x) * 64, regions["B"][1] + t * 128

	return uv


def torso_uv(dist_of, half_x):
	def uv(n, p):
		x, y, z = p
		nx, ny, nz = n
		t = clamp01(dist_of(y) / TORSO_LEN)
		u_x = clamp01(0.5 - x / (2 * half_x))
		if abs(nx) > 0.7:
			key = "R" if nx > 0 else "L"
			u = clamp01(0.5 - z) if nx > 0 else clamp01(z + 0.5)
			return TORSO[key][0] + u * 64, TORSO[key][1] + t * 128
		if abs(ny) > 0.95:
			key = "U" if ny > 0 else "D"
			return TORSO[key][0] + u_x * 128, TORSO[key][1] + clamp01(0.5 - z) * 64
		if nz <= 0:
			return TORSO["F"][0] + u_x * 128, TORSO["F"][1] + t * 128
		return TORSO["B"][0] + (1 - u_x) * 128, TORSO["B"][1] + t * 128

	return uv


def main():
	bpy.ops.wm.read_factory_settings(use_empty=True)
	objs, infos = [], {}

	def add(name, bm, uv_of):
		obj, info = finish(bm, name, uv_of)
		objs.append(obj)
		infos[name] = info

	for side, regions in (("Right", RIGHT_LIMB), ("Left", LEFT_LIMB)):
		hx = 0.5
		add(
			side + "UpperArm",
			prism(limb_profile(UA_TOP, UA_ELBOW, False, True), hx),
			limb_uv(regions, lambda y: UA_TOP - y, ARM_LEN, hx),
		)
		hx = 0.5 + LOWER_EXTRA
		add(
			side + "LowerArm",
			prism(limb_profile(LA_ELBOW, LA_TIP, True, False), hx),
			limb_uv(regions, lambda y: (UA_TOP - UA_ELBOW) + (LA_ELBOW - y), ARM_LEN, hx),
		)
		hx = 0.5
		add(
			side + "UpperLeg",
			prism(limb_profile(UL_HIP, UL_KNEE, True, True), hx),
			limb_uv(regions, lambda y: UL_HIP - y, LEG_LEN, hx),
		)
		hx = 0.5 + LOWER_EXTRA
		add(
			side + "LowerLeg",
			prism(limb_profile(LL_KNEE, LL_SOLE, True, False), hx),
			limb_uv(regions, lambda y: (UL_HIP - UL_KNEE) + (LL_KNEE - y), LEG_LEN, hx),
		)

	hx = 1.0 + TORSO_EXTRA
	bm = bmesh.new()
	box(bm, hx, -0.8, 0.8, 0.5 + TORSO_EXTRA)
	add("UpperTorso", bm, torso_uv(lambda y: 0.8 - y, hx))
	bm = bmesh.new()
	box(bm, hx, -0.2, 0.2, 0.5 + TORSO_EXTRA)
	box(bm, hx - BAND_INSET, 0.2 - 0.01, 0.2 + BAND, 0.5 + TORSO_EXTRA - BAND_INSET)
	add("LowerTorso", bm, torso_uv(lambda y: 1.6 + (0.2 - y), hx))

	bpy.ops.object.select_all(action="DESELECT")
	for o in objs:
		o.select_set(True)
	bpy.context.view_layer.objects.active = objs[0]
	os.makedirs(OUT_DIR, exist_ok=True)
	bpy.ops.export_scene.fbx(
		filepath=OUT,
		use_selection=True,
		object_types={"MESH"},
		apply_scale_options="FBX_SCALE_UNITS",
		use_mesh_modifiers=True,
		mesh_smooth_type="FACE",
	)
	with open(OUT_JSON, "w", encoding="utf-8") as f:
		json.dump(infos, f, indent=1)
	# A look at the result (workbench, three-quarter), for review.
	print("wrote", OUT)
	print(json.dumps(infos))


main()
