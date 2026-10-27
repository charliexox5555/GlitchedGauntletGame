"""Exact hand-vs-gun clipping check for the first-person viewmodel.

    blender --background --factory-startup --python tools/blender/check_hand_clipping.py -- art-source/viewmodel/checks/Vandal_hold.json [...]

Input: samples from tools/studio/SampleHands.luau (each arm block, per gun
joint, in that joint's rest frame, Roblox gun space at model scale).
The gun is the exported FBX (art-source/weapons/Exports/<Id>.fbx), at rest.
Each mesh part is tested against the arm block on its own joint (from
Exports/<Id>.json): triangle-triangle overlap (BVH) plus gun vertices inside
the block. Depth = how far the deepest gun vertex sits inside the block
(studs at model scale). Prints a summary per arm; writes <input>.result.json.

Roblox gun space -> Blender: G^-1(X, Y, Z) = (-Z, -X, Y) (see WeaponBuilder).
"""

import json
import os
import sys

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
EXPORTS = os.path.join(ROOT, "art-source", "weapons", "Exports")


def to_blender(v):
	return Vector((-v[2], -v[0], v[1]))


def load_gun(gid):
	bpy.ops.wm.read_factory_settings(use_empty=True)
	bpy.ops.import_scene.fbx(filepath=os.path.join(EXPORTS, gid + ".fbx"))
	for o in bpy.data.objects:
		if o.type == "ARMATURE":
			o.data.pose_position = "REST"
	bpy.context.view_layer.update()
	info = json.load(open(os.path.join(EXPORTS, gid + ".json")))
	bones = {p["name"]: p["bone"] or "Root" for p in info["parts"]}
	centers = {p["name"]: p["center"] for p in info["parts"]}
	deps = bpy.context.evaluated_depsgraph_get()
	meshes = {}
	worst_center = 0.0
	for o in bpy.data.objects:
		if o.type != "MESH" or o.name not in bones:
			continue
		ev = o.evaluated_get(deps)
		me = ev.to_mesh()
		verts = [ev.matrix_world @ v.co for v in me.vertices]
		tris = []
		me.calc_loop_triangles()
		for t in me.loop_triangles:
			tris.append(tuple(t.vertices))
		ev.to_mesh_clear()
		if not verts:
			continue
		lo = Vector((min(v[i] for v in verts) for i in range(3)))
		hi = Vector((max(v[i] for v in verts) for i in range(3)))
		worst_center = max(worst_center, ((lo + hi) / 2 - Vector(centers[o.name])).length)
		meshes[o.name] = {
			"bone": bones[o.name],
			"verts": verts,
			"bvh": BVHTree.FromPolygons(verts, tris),
		}
	return meshes, worst_center


def box_from(rows, half):
	x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = rows
	center = to_blender((x, y, z))
	axes = [to_blender((r00, r10, r20)), to_blender((r01, r11, r21)), to_blender((r02, r12, r22))]
	corners = []
	for sx in (-1, 1):
		for sy in (-1, 1):
			for sz in (-1, 1):
				corners.append(center + axes[0] * (sx * half[0]) + axes[1] * (sy * half[1]) + axes[2] * (sz * half[2]))
	# 12 triangles of the box (corner index = sx*4 + sy*2 + sz with 0/1 bits)
	quads = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
	tris = []
	for a, b, c, d in quads:
		tris += [(a, b, c), (a, c, d)]
	return center, axes, corners, BVHTree.FromPolygons(corners, tris)


def depth_inside(p, center, axes, half):
	d = p - center
	best = None
	for i in range(3):
		u = d.dot(axes[i])
		gap = half[i] - abs(u)
		if gap <= 0:
			return 0.0
		best = gap if best is None else min(best, gap)
	return best


def check(path):
	data = json.load(open(path))
	gid, half = data["id"], data["half"]
	meshes, center_err = load_gun(gid)
	summary = {"Right": {}, "Left": {}}
	per_frame = []
	for frame in data["frames"]:
		row = {"label": frame["label"]}
		for side, joints in frame["arms"].items():
			hits = {}
			for name, m in meshes.items():
				rows = joints.get(m["bone"]) or joints.get("Root")
				if not rows:
					continue
				center, axes, _, box = box_from(rows, half)
				pairs = box.overlap(m["bvh"])
				deep = 0.0
				for v in m["verts"]:
					deep = max(deep, depth_inside(v, center, axes, half))
				if pairs or deep > 0:
					hits[name] = round(deep, 3) if deep > 0 else 0.001
			row[side] = hits
			for name, d in hits.items():
				s = summary[side].setdefault(name, {"frames": 0, "max": 0.0})
				s["frames"] += 1
				s["max"] = max(s["max"], d)
		per_frame.append(row)
	out = {"id": gid, "mode": data["mode"], "frames": len(data["frames"]), "import_center_error": round(center_err, 4), "summary": summary, "per_frame": per_frame}
	with open(path.replace(".json", ".result.json"), "w") as f:
		json.dump(out, f, indent=1)
	lines = [f"{gid} {data['mode']} ({len(data['frames'])} frames, import err {center_err:.4f})"]
	for side in ("Right", "Left"):
		items = sorted(summary[side].items(), key=lambda kv: -kv[1]["max"])
		text = ", ".join(f"{n} {s['max']:.3f}x{s['frames']}" for n, s in items) or "clear"
		lines.append(f"  {side}: {text}")
	print("\n".join(lines), flush=True)


if __name__ == "__main__":
	args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
	for p in args:
		check(os.path.abspath(p))
