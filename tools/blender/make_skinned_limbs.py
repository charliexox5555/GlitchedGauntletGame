# make_skinned_limbs.py: the third-person block body's arms and legs as ONE
# skinned mesh each (vault/01 Design/Third Person Overhaul.md §8).
#
#   blender --background --factory-startup --python tools/blender/make_skinned_limbs.py
#
# Writes art-source/body/SkinnedLimbs.fbx (four meshes, each with its own
# armature) and SkinnedLimbs.json (each mesh's size, its centre in the upper
# R15 part's frame, and each bone's bind position in that frame).
#
# Why skinned (owner 2026-11-12: "the joins and bends just don't look
# correct... different sizes and bent weirdly. It's not smooth"): two rigid
# boxes can't close a bend cleanly at every angle (v1 half-octagon caps read
# as lumps, v2 mitres as stacked blocks). One mesh per limb is one
# cross-section from shoulder to fist, and the bend is made by the skin
# (LihFolk "Weight Painting and Skinning for Roblox": three edge loops at a
# joint, falloff about the joint's thickness, a helper bone):
#   - an edge loop at the hinge rides a helper bone that turns HALF the bend
#     ("Mid1" at the elbow / knee, "Mid2" at the wrist / ankle);
#   - one loop JOINT_HALF above and one below are fully on the segments.
# So the outside of any bend is two flat plates (no curves: gauntlet-build-
# style), the inside folds into the neighbour, and straight it is a plain
# box. The fist end follows the hand and the sole follows the foot ("End"),
# so a turned wrist turns the fist with the gun.
#
# Bones (all children of "Upper", which sits on the upper part):
#   Upper  upper arm / thigh (rigid on the MeshPart's weld)
#   Mid1   elbow / knee helper, half of the bend
#   Lower  forearm / shin
#   Mid2   wrist / ankle helper
#   End    hand / foot
# shared/MatchBody makes the MeshPart and its Bones; Controllers/
# BodySkinController turns the bones each frame from the R15 parts.
#
# Roblox part space: +Y up, -Z front, +X the character's right. Blender:
# X = X, Z = Roblox Y, Y = -Roblox Z. One Blender unit = one stud.

import json
import os

import bmesh
import bpy
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_DIR = os.path.join(ROOT, "art-source", "body")
OUT = os.path.join(OUT_DIR, "SkinnedLimbs.fbx")
OUT_JSON = os.path.join(OUT_DIR, "SkinnedLimbs.json")

BEVEL = 0.035
R = 0.5  # half a limb's width and depth
JOINT_HALF = 0.25  # elbow / knee: loops this far either side of the hinge
# (0.35 read as a rubbery slab, owner 2026-11-12)
END_HALF = 0.1  # wrist / ankle
SIZE = (585.0, 559.0)

# Rig numbers in the UPPER part's frame (standard match body, read in Studio
# 2026-11-12; same as make_body_mesh.py).
UA_TOP, ELBOW = 0.5843, -0.3341
LA_ELBOW, LA_WRIST, HAND_LEN = 0.2587, -0.5009, 0.275
WRIST = ELBOW - (LA_ELBOW - LA_WRIST)
ARM_TIP = WRIST - HAND_LEN
UL_HIP, KNEE = 0.4208, -0.4010
LL_KNEE, LL_ANKLE, FOOT_DROP = 0.3790, -0.5472, 0.1019 + 0.15
ANKLE = KNEE - (LL_KNEE - LL_ANKLE)
SOLE = ANKLE - FOOT_DROP
UL_TOP = 0.6083  # the thigh's flat top, inside the hips (R15's own top)
HIP_HALF = 0.15  # the hip bend: from the pivot down this far (0.25 bulged at the hips)
# The torso (LowerTorso frame): hips 0.4 tall under the waist pivot, chest
# 1.6 above it. One mesh, so a turned chest twists the belly instead of a
# chest block hanging out over a hips block (owner 2026-11-12: "the torso
# looking a bit weird and overlapping").
WAIST, CHEST_TOP, HIPS_BOTTOM = 0.2, 1.8, -0.2
# The R15 layout exactly (checked side by side with the owner's R6 / R15
# presets, 2026-11-12): a plain 2 x 2 x 1 torso box (chest + hips), legs 2.0
# below it with their tops tucked into the hips. Every bone name is unique
# per mesh (BONE_PREFIX): with shared names ("Upper", "Lower" in all five)
# Roblox's importer bound each mesh to another armature's bones, which drew
# the torso 2.5 tall, up past the chin, and stretched the legs (v3a-v3g).
WAIST_UP = 0.7  # the twist spreads from this far above the waist to the hips bottom (0.3 creased)
TORSO_EXTRA = 0.006  # the torso a hair wider than the limbs (no flicker)
TORSO = {"F": (231, 74), "R": (165, 74), "L": (361, 74), "B": (427, 74), "U": (231, 8), "D": (231, 204)}

RIGHT_LIMB = {"F": (217, 355), "R": (151, 355), "B": (85, 355), "L": (19, 355), "U": (217, 289), "D": (217, 485)}
LEFT_LIMB = {"F": (308, 355), "L": (374, 355), "B": (440, 355), "R": (506, 355), "U": (308, 289), "D": (308, 485)}


def limb_spec(kind):
	if kind == "Torso":
		return {
			"top": CHEST_TOP,
			"tip": HIPS_BOTTOM,
			"hx": 1.0 + TORSO_EXTRA,
			"hz": R + TORSO_EXTRA,
			"loops": [CHEST_TOP, WAIST + WAIST_UP, WAIST, HIPS_BOTTOM],
			# The mesh is welded to the hips (LowerTorso = "Upper"); the
			# chest ("Lower") follows UpperTorso, the waist loop half way.
			"weights": [
				(CHEST_TOP, "Lower"),
				(WAIST + WAIST_UP, "Lower"),
				(WAIST, "Mid1"),
				(HIPS_BOTTOM, "Upper"),
			],
			"bones": {b: (WAIST, WAIST - 0.2) for b in ("Upper", "Mid1", "Lower", "Mid2", "End")},
			"pivot": WAIST,
		}
	if kind == "Arm":
		top, j, w, tip = UA_TOP, ELBOW, WRIST, ARM_TIP
		head = [(top, "Upper")]
		bones = {}
	else:
		# The thigh's top rides the pelvis ("Hip"), the loop at the hip pivot
		# turns half ("HipMid"), so a raised leg bends out from under the hips
		# with one chamfer and nothing pokes up into the waist.
		top, j, w, tip = UL_TOP, KNEE, ANKLE, SOLE
		head = [(top, "Hip"), (UL_HIP, "HipMid"), (UL_HIP - HIP_HALF, "Upper")]
		bones = {"Hip": (UL_HIP, UL_HIP - 0.2), "HipMid": (UL_HIP, UL_HIP - 0.2)}
	weights = head + [
		(j + JOINT_HALF, "Upper"),
		(j, "Mid1"),
		(j - JOINT_HALF, "Lower"),
		(w + END_HALF, "Lower"),
		(w, "Mid2"),
		(w - END_HALF, "End"),
		(tip, "End"),
	]
	pivot = UA_TOP if kind == "Arm" else UL_HIP
	bones.update({"Upper": (pivot, j), "Mid1": (j, j - 0.2), "Lower": (j, w), "Mid2": (w, w - 0.1), "End": (w, tip)})
	return {
		"top": top,
		"tip": tip,
		"hx": R,
		"hz": R,
		"loops": [y for (y, _) in weights],
		"weights": weights,
		"bones": bones,
		"pivot": pivot,
	}


def build_bm(spec):
	"""A 1 x 1 box from top to tip, cut by every loop, with an optional hip
	ridge on top. Built as a stack of rings so every loop is a real edge loop."""
	bm = bmesh.new()
	hz = spec["hz"]
	widths = spec.get("widths") or [None] * len(spec["loops"])
	rings = []
	for y, w in zip(spec["loops"], widths):
		hx = w if w is not None else spec["hx"]
		corners = [(-hx, -hz), (hx, -hz), (hx, hz), (-hx, hz)]  # (x, z) Roblox, z +back
		ring = [bm.verts.new((x, -z, y)) for (x, z) in corners]  # Blender (x, -Rz, Ry)
		rings.append(ring)
	for a, b in zip(rings, rings[1:]):
		for i in range(4):
			j = (i + 1) % 4
			bm.faces.new((a[i], a[j], b[j], b[i]))
	bottom = rings[-1]
	bm.faces.new(list(reversed(bottom)))
	bm.faces.new(rings[0])
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	# The sharp chamfer of the first-person arm on the outline edges only
	# (never on the loop cuts, which are flat).
	sharp = [e for e in bm.edges if len(e.link_faces) == 2 and e.calc_face_angle(0) > 0.3]
	bmesh.ops.bevel(
		bm, geom=sharp, offset=BEVEL, offset_type="OFFSET", segments=1, profile=0.5, affect="EDGES", clamp_overlap=True
	)
	bmesh.ops.triangulate(bm, faces=bm.faces[:])
	return bm


def to_roblox(v):
	return (v.x, v.z, -v.y)


def limb_uv(regions, top, length):
	def uv(n, p):
		x, y, z = p
		nx, ny, nz = n
		t = min(max((top - y) / length, 0.0), 1.0)
		u_x = min(max(0.5 - x / (2 * R), 0.0), 1.0)
		if abs(nx) > 0.7:
			key = "R" if nx > 0 else "L"
			u = (0.5 - z) if nx > 0 else (z + 0.5)
			return regions[key][0] + min(max(u, 0), 1) * 64, regions[key][1] + t * 128
		if abs(ny) > 0.95:
			if ny > 0:
				return regions["U"][0] + u_x * 64, regions["U"][1] + min(max(0.5 - z, 0), 1) * 64
			return regions["F"][0] + u_x * 64, regions["F"][1] + 126
		if nz <= 0:
			return regions["F"][0] + u_x * 64, regions["F"][1] + t * 128
		return regions["B"][0] + (1 - u_x) * 64, regions["B"][1] + t * 128

	return uv


def weight_of(spec, y):
	"""[(bone, w)] for a vertex at height y: linear between the two loops
	around it."""
	ws = spec["weights"]
	if y >= ws[0][0]:
		return [(ws[0][1], 1.0)]
	for (y0, b0), (y1, b1) in zip(ws, ws[1:]):
		if y0 >= y >= y1:
			if b0 == b1 or abs(y0 - y1) < 1e-6:
				return [(b0, 1.0)]
			t = (y0 - y) / (y0 - y1)
			# Bevel verts sit 0.035 off a loop: snap them to the nearer loop
			# so a loop stays one rigid ring.
			if t < 0.15:
				return [(b0, 1.0)]
			if t > 0.85:
				return [(b1, 1.0)]
			return [(b0, 1 - t), (b1, t)]
	return [(ws[-1][1], 1.0)]


def make_limb(name, kind, regions):
	spec = limb_spec(kind)
	bm = build_bm(spec)
	uvl = bm.loops.layers.uv.new("UVMap")
	length = spec["top"] - spec["tip"]
	uv_of = limb_uv(regions, spec["top"], length)
	for f in bm.faces:
		n = to_roblox(f.normal)
		for loop in f.loops:
			px, py = uv_of(n, to_roblox(loop.vert.co))
			loop[uvl].uv = (px / SIZE[0], 1 - py / SIZE[1])
	lo = Vector((min(v.co.x for v in bm.verts), min(v.co.y for v in bm.verts), min(v.co.z for v in bm.verts)))
	hi = Vector((max(v.co.x for v in bm.verts), max(v.co.y for v in bm.verts), max(v.co.z for v in bm.verts)))
	mesh = bpy.data.meshes.new(name)
	bm.to_mesh(mesh)
	bm.free()
	for p in mesh.polygons:
		p.use_smooth = False
	obj = bpy.data.objects.new(name, mesh)
	bpy.context.scene.collection.objects.link(obj)

	arm_data = bpy.data.armatures.new(name + "Rig")
	rig = bpy.data.objects.new(name + "Rig", arm_data)
	bpy.context.scene.collection.objects.link(rig)
	bpy.context.view_layer.objects.active = rig
	bpy.ops.object.mode_set(mode="EDIT")
	made = {}
	for bone, (y0, y1) in spec["bones"].items():
		eb = arm_data.edit_bones.new(name + bone)
		eb.head = (0.0, 0.0, y0)
		eb.tail = (0.0, 0.0, y1)
		eb.roll = 0.0
		made[bone] = eb
	for bone in made:
		if bone == "Upper":
			continue
		made[bone].parent = made["Upper"]
		made[bone].use_connect = False
	bpy.ops.object.mode_set(mode="OBJECT")

	for bone in spec["bones"]:
		obj.vertex_groups.new(name=name + bone)
	for v in mesh.vertices:
		for bone, w in weight_of(spec, v.co.z):
			obj.vertex_groups[name + bone].add([v.index], w, "REPLACE")
	obj.parent = rig
	mod = obj.modifiers.new("Armature", "ARMATURE")
	mod.object = rig

	centre = (lo + hi) / 2
	size = hi - lo
	info = {
		"offset": [round(centre.x, 5), round(centre.z, 5), round(-centre.y, 5)],
		"size": [round(size.x, 5), round(size.z, 5), round(size.y, 5)],
		"bones": {b: round(y0, 5) for b, (y0, _) in spec["bones"].items()},
		"top": spec["top"],
		"tip": spec["tip"],
	}
	return obj, rig, info


def main():
	bpy.ops.wm.read_factory_settings(use_empty=True)
	infos = {}
	objs = []
	for side, regions in (("Right", RIGHT_LIMB), ("Left", LEFT_LIMB)):
		for kind in ("Arm", "Leg"):
			name = side + kind
			obj, rig, info = make_limb(name, kind, regions)
			objs += [obj, rig]
			infos[name] = info
	obj, rig, info = make_limb("Torso", "Torso", TORSO)
	objs += [obj, rig]
	infos["Torso"] = info
	bpy.ops.object.select_all(action="DESELECT")
	for o in objs:
		o.select_set(True)
	os.makedirs(OUT_DIR, exist_ok=True)
	bpy.ops.export_scene.fbx(
		filepath=OUT,
		use_selection=True,
		object_types={"MESH", "ARMATURE"},
		apply_scale_options="FBX_SCALE_UNITS",
		mesh_smooth_type="FACE",
		add_leaf_bones=False,
		use_armature_deform_only=True,
		bake_anim=False,
	)
	with open(OUT_JSON, "w", encoding="utf-8") as f:
		json.dump(infos, f, indent=1)
	print("wrote", OUT)
	print(json.dumps(infos))


main()
