# preview_map_oldtown.py: an offline preview of the whole Old Town map, assembled the way Studio will build it.
#
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup \
#       art-source/maps/OldTown/Kit_OldTown.blend --python tools/blender/preview_map_oldtown.py -- [--samples N] [--views a,b]
#       ... -- --check     z-fighting check of the assembled map only (no renders); exits 1 if any visible pair
#
# Reads the same data Art.luau is generated from (tools/maps/oldtown_layout.py + oldtown_art.py): every kit placement
# becomes a collection instance of its Map_<Piece>, plus the greybox parts Art.luau leaves visible (floors, interior
# plaster, slabs) and its plain parts (flat roof tops, linings). Roblox map space (x, y, z) is Blender (x, -z, y); a
# Roblox yaw turns +X toward -Z, i.e. Blender +Y, so it is a plain rotation about Blender +Z. Tints are left out
# (every house shows the cream stucco and the blue accent). Renders to vault/02 Art/References/maps/oldtown/preview-*.jpg.
# The file is not saved.

import math, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "maps"))
import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402
import json  # noqa: E402
import numpy as np  # noqa: E402
import lobbykit as K  # noqa: E402
import zfight_check as Z  # noqa: E402
from gunkit import box  # noqa: E402
import oldtown_layout as L  # noqa: E402
import oldtown_art as A  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
REF = os.path.join(K.ROOT, "vault", "02 Art", "References", "maps", "oldtown")


def mat(name, color, rough=0.85):
	m = bpy.data.materials.get(name)
	if m:
		return m
	m = bpy.data.materials.new(name)
	m.use_nodes = True
	b = m.node_tree.nodes.get("Principled BSDF")
	b.inputs["Base Color"].default_value = (*K.lin(color), 1)
	b.inputs["Roughness"].default_value = rough
	return m


def rbx_box(col, name, x0, x1, y0, y1, z0, z1, m):
	# Roblox map-space box -> Blender object.
	bm = box(x0, x1, -z1, -z0, y0, y1)
	ob = K.add_obj(name, bm, [m], col, smooth_angle=0, uvs=None)
	return ob


def box_tris(x0, x1, y0, y1, z0, z1):
	# Roblox map-space box -> 12 Blender-space triangles.
	bx0, bx1, by0, by1, bz0, bz1 = x0, x1, -z1, -z0, y0, y1
	v = [(bx0, by0, bz0), (bx1, by0, bz0), (bx1, by1, bz0), (bx0, by1, bz0), (bx0, by0, bz1), (bx1, by0, bz1), (bx1, by1, bz1), (bx0, by1, bz1)]
	quads = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
	out = []
	for a, b, c, d in quads:
		out.append([v[a], v[b], v[c]])
		out.append([v[a], v[c], v[d]])
	return out


def check(art):
	# Every visible surface of the assembled map: kit placements (per MeshPart), the greybox parts Art.luau leaves
	# visible, and Art's plain parts. Same rule as tools/studio/maps/Audit.luau: same plane, overlapping, both visible.
	local = {}
	for c in bpy.data.collections:
		if not c.name.startswith("Map_"):
			continue
		objs = []
		for ob in c.all_objects:
			if ob.type != "MESH":
				continue
			me = ob.data
			me.calc_loop_triangles()
			co = np.array([tuple(ob.matrix_world @ v.co) for v in me.vertices])
			idx = np.array([tuple(t.vertices) for t in me.loop_triangles], dtype=int)
			if len(idx):
				objs.append((ob.name, co[idx]))
		local[c.name[4:]] = objs
	tris, owners, labels = [], [], []

	def add(label, arr):
		owners.extend([len(labels)] * len(arr))
		labels.append(label)
		tris.append(np.asarray(arr, dtype=float))

	for sec, piece, x, y, z, yaw, side, tone in art.place:
		r = math.radians(yaw)
		R = np.array([[math.cos(r), -math.sin(r), 0], [math.sin(r), math.cos(r), 0], [0, 0, 1]])
		T = np.array([x, -z, y])
		for name, t in local.get(piece, []):
			add("%s@(%.0f,%.0f,%.0f)" % (name, x, y, z), t @ R.T + T)
	add("Greybox.Ground", box_tris(-L.OUT_X - 4, L.OUT_X + 4, -2, 0, -L.OUT_Z - 4, L.OUT_Z + 4))
	for name, a, b, c, d in L.FLOORS_A:
		for s in (1, -1):
			xa, xb = sorted((a * s, b * s))
			za, zb = sorted((c * s, d * s))
			add("Greybox.%s%s" % (name, "_A" if s > 0 else "_B"), box_tris(xa, xb, -0.16, 0.04, za, zb))
	for s in L.all_solids():
		if s.shape != "box" or s.kind == "ground":
			continue
		if (s.kind in ("bldg", "perim") and not s.shell) or s.kind == "floor":
			add("Greybox." + s.name, box_tris(s.cx - s.sx / 2, s.cx + s.sx / 2, s.y0, s.y1, s.cz - s.sz / 2, s.cz + s.sz / 2))
	for sec, name, x0, x1, y0, y1, z0, z1, color, material in art.parts:
		add("Art.%s.%s" % (sec, name), box_tris(x0, x1, y0, y1, z0, z1))
	allt = np.concatenate(tris)
	print("MAPZ triangles", len(allt), "surfaces", len(labels))
	found = Z.find(allt, owners, labels, same_owner=False)
	same = [c for c in found if c[0] == "same"]
	print("MAPZ visible pairs (same plane, overlapping, both seen): %d; buried %d; touching %d" % (len(same), sum(1 for c in found if c[0] == "buried"), sum(1 for c in found if c[0] == "opposite")))
	for k, v in Z.summary(found, "same", 40):
		print("MAPZ  %4d  %s + %s" % (v, k[0], k[1]))
	out = [{"a": c[1], "b": c[2], "at": [round(float(c[3][0]), 2), round(float(c[3][2]), 2), round(float(-c[3][1]), 2)], "normal": [float(c[4][0]), float(c[4][2]), float(-c[4][1])], "area": float(c[5])} for c in same]
	path = os.path.join(K.ROOT, "art-source", "maps", "OldTown", "zfight-offline.json")
	with open(path, "w") as f:
		json.dump(out, f, indent=1)
	print("MAPZ wrote", path)
	return len(same)


def main():
	if "--check" in ARGS:
		n = check(A.Art().build())
		if n:
			raise SystemExit(1)
		return
	for lc in bpy.context.view_layer.layer_collection.children:
		lc.exclude = True  # the kit masters, the kit's own preview sets and its sun
	col = K.collection("Preview")
	art = A.Art().build()
	pieces = {c.name[4:]: c for c in bpy.data.collections if c.name.startswith("Map_")}
	missing = set()
	for sec, piece, x, y, z, yaw, side, tone in art.place:
		c = pieces.get(piece)
		if c is None:
			missing.add(piece)
			continue
		m = Matrix.Translation((x, -z, y)) @ Matrix.Rotation(math.radians(yaw), 4, "Z")
		K.place_instance(c, m, "P_" + piece, col)
	print("PREVIEW placements", len(art.place), "missing", sorted(missing))
	# Ground and paving.
	rbx_box(col, "Ground", -L.OUT_X - 4, L.OUT_X + 4, -2, 0, -L.OUT_Z - 4, L.OUT_Z + 4, mat("Cobble", 0x9C8D7A, 0.95))
	for name, a, b, c, d in L.FLOORS_A:
		for s in (1, -1):
			xa, xb = sorted((a * s, b * s))
			za, zb = sorted((c * s, d * s))
			rbx_box(col, name, xa, xb, -0.06, 0.04, za, zb, mat("Paving", 0xD8C9AA, 0.9))
	# Greybox parts Art.luau keeps visible.
	interior = mat("InteriorPlaster", 0xEFE4CC, 0.95)
	slab = mat("Slab", 0xD9CBAE, 0.85)
	for s in L.all_solids():
		if s.shape != "box" or s.kind == "ground":
			continue
		if s.kind in ("bldg", "perim") and not s.shell:
			m = interior
		elif s.kind == "floor":
			m = slab
		else:
			continue
		rbx_box(col, "G_" + s.name, s.cx - s.sx / 2, s.cx + s.sx / 2, s.y0, s.y1, s.cz - s.sz / 2, s.cz + s.sz / 2, m)
	# Art's plain parts.
	for sec, name, x0, x1, y0, y1, z0, z1, color, material in art.parts:
		rbx_box(col, "A_" + name, x0, x1, y0, y1, z0, z1, mat("Part_" + color, int(color[1:], 16), 0.9))

	# World + sun as Lighting.luau sets them: ~41 degrees up, 11 degrees north of west (Roblox north = -Z = Blender +Y).
	sc = bpy.context.scene
	w = sc.world or bpy.data.worlds.new("World")
	sc.world = w
	w.use_nodes = True
	nt = w.node_tree
	nt.nodes.clear()
	out = nt.nodes.new("ShaderNodeOutputWorld")
	bg = nt.nodes.new("ShaderNodeBackground")
	tc = nt.nodes.new("ShaderNodeTexCoord")
	sep = nt.nodes.new("ShaderNodeSeparateXYZ")
	ramp = nt.nodes.new("ShaderNodeValToRGB")
	nt.links.new(tc.outputs["Generated"], sep.inputs[0])
	nt.links.new(sep.outputs[2], ramp.inputs[0])
	ramp.color_ramp.elements[0].position = 0.0
	ramp.color_ramp.elements[0].color = (*K.lin(0xE2CDAE), 1)
	ramp.color_ramp.elements[1].position = 0.4
	ramp.color_ramp.elements[1].color = (*K.lin(0x5E95CC), 1)
	nt.links.new(ramp.outputs[0], bg.inputs[0])
	bg.inputs[1].default_value = 1.0
	nt.links.new(bg.outputs[0], out.inputs[0])
	ld = bpy.data.lights.new("Sun", "SUN")
	ld.energy = 4.0
	ld.color = K.lin(0xFFE0B8)
	ld.angle = math.radians(1.0)
	so = bpy.data.objects.new("Sun", ld)
	col.objects.link(so)
	el, az = math.radians(41), math.radians(11)
	to_sun = Vector((-math.cos(el) * math.cos(az), math.cos(el) * math.sin(az), math.sin(el)))
	so.rotation_euler = (-to_sun).to_track_quat("-Z", "Y").to_euler()
	samples = int(ARGS[ARGS.index("--samples") + 1]) if "--samples" in ARGS else 32
	K.render_settings(samples=samples)
	K.bloom(strength=0.25, threshold=1.5)
	# Views: Roblox map space (x, eye y, z) -> Blender (x, -z, y).
	def V(x, y, z):
		return (x, -z, y)

	views = {
		"overview": (V(-150, 190, -210), V(0, 0, -10), 30),
		"spawn": (V(10, 5.4, -126), V(16, 5, -100), 26),
		"forecourt": (V(-4, 5.4, -88), V(-5, 6, -36), 26),
		"gate": (V(-16, 5.4, -31), V(12, 8, 24), 24),
		"terrace": (V(40, 17.4, -30), V(-20, 6, 10), 24),
		"alley": (V(72, 5.4, -100), V(74, 9, -50), 24),
		"court": (V(-34, 5.4, -60), V(-46, 6, -76), 24),
		"plaza": (V(-22, 5.4, -33), V(14, 10, 12), 24),
	}
	want = ARGS[ARGS.index("--views") + 1].split(",") if "--views" in ARGS else list(views)
	for name in want:
		loc, tgt, lens = views[name]
		cam = K.camera(loc, tgt, lens=lens, name="Cam_" + name, col=col)
		sc.camera = cam
		K.render(os.path.join(REF, "preview-%s.jpg" % name), res=(1600, 900))


main()
