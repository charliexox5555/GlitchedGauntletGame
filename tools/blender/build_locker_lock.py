"""The Locker's locked-gun overlay: four gold chain strands in an X meeting at a padlock (owner 2026-11-28, after
RIVALS' locked weapon screen; our own faceted build, vault/02 Art/UI Locker.md -> "Locked guns v2").

Run headless (it never touches an open Blender file):
    blender -b --factory-startup --python tools/blender/build_locker_lock.py -- [--render]

Writes art-source/ui/locker-lock/LockerLock.fbx (+ .blend, + review renders with --render). Objects:
ChainTL / ChainTR / ChainBL / ChainBR (each strand its own mesh so the unlock can drop them one by one),
Padlock (body + collars, keyhole cut), Shackle, Keyhole (the dark insert). Units are arbitrary: the Locker scales
the model to the gun (Controllers/LockerV3Controller). Faceted everywhere (gauntlet-build-style s0): 6-sided wire,
link ends in 4 facets, chamfered body, no smooth shading.
"""

import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art-source", "ui", "locker-lock")
os.makedirs(OUT, exist_ok=True)

# --- sizes (Blender units; X right, Z up, -Y toward the camera) ---------------------------------------------------
LINK_L = 0.62  # straight run of a link's long side (centre line)
LINK_R = 0.30  # end radius (centre line)
WIRE = 0.105  # wire radius (hexagon)
END_FACETS = 4  # facets per 180 deg link end
LINKS = 14  # per strand: long enough to run off every screen edge (owner 2026-11-28)
ANGLE = math.radians(32)  # strand angle above / below horizontal
START = 0.9  # first link's centre, out from the padlock centre
PITCH = LINK_L + 2 * LINK_R - 2.2 * WIRE  # consecutive links interlock

BODY_W, BODY_H, BODY_D = 2.5, 2.05, 0.8  # big: it's the first thing a locked gun says
CHAMF = 0.22  # corner chamfer of the outline
EDGE = 0.09  # front/back edge chamfer
SHACKLE_R = 0.72  # arc radius (centre line)
SHACKLE_WIRE = 0.19
SHACKLE_LEG = 0.6  # straight leg above the body
SHACKLE_ARC = 8  # facets on the 180 deg arc


def clear():
	bpy.ops.wm.read_factory_settings(use_empty=True)


def material(name, rgb):
	m = bpy.data.materials.new(name)
	m.diffuse_color = (*rgb, 1)
	return m


def new_obj(name, bm, mat):
	me = bpy.data.meshes.new(name)
	bm.to_mesh(me)
	bm.free()
	for p in me.polygons:
		p.use_smooth = False
	me.materials.append(mat)
	ob = bpy.data.objects.new(name, me)
	bpy.context.scene.collection.objects.link(ob)
	return ob


def sweep(bm, path, radius, sides, closed, rot=0.0, normal=None):
	"""A `sides`-gon tube along `path` (list of Vector); flat facets. A planar path passes its plane `normal`, so
	the section never flips round the bends (it twisted the link ends into stars)."""
	rings = []
	n = len(path)
	for i, p in enumerate(path):
		if closed:
			t = (path[(i + 1) % n] - path[i - 1]).normalized()
		else:
			a = path[min(i + 1, n - 1)] - path[max(i - 1, 0)]
			t = a.normalized()
		if normal is not None:
			u = normal.normalized()
		else:
			up = Vector((0, 1, 0)) if abs(t.dot(Vector((0, 1, 0)))) < 0.9 else Vector((1, 0, 0))
			u = t.cross(up).normalized()
		v = t.cross(u).normalized()
		ring = []
		for k in range(sides):
			a = rot + 2 * math.pi * k / sides
			ring.append(bm.verts.new(p + (u * math.cos(a) + v * math.sin(a)) * radius))
		rings.append(ring)
	count = n if closed else n - 1
	for i in range(count):
		r0, r1 = rings[i], rings[(i + 1) % n]
		for k in range(sides):
			bm.faces.new((r0[k], r0[(k + 1) % sides], r1[(k + 1) % sides], r1[k]))
	if not closed:
		bm.faces.new(list(reversed(rings[0])))
		bm.faces.new(rings[-1])


def link_path(center, axis, side):
	"""Centre line of one link: a stadium of two straight runs and two faceted ends, in the plane (axis, side)."""
	pts = []
	half = LINK_L / 2
	for end, sign in ((1, 1), (-1, -1)):
		c = center + axis * (half * end)
		for k in range(END_FACETS + 1):
			a = -math.pi / 2 + math.pi * k / END_FACETS
			# end = +1 sweeps the far end from -side to +side; end = -1 the near end back
			pts.append(c + axis * (math.cos(a) * LINK_R * sign) + side * (math.sin(a) * LINK_R * sign))
	return pts


def strand(name, direction, depth, mat):
	bm = bmesh.new()
	axis = direction.normalized()
	face = Vector((0, -1, 0))  # toward the camera
	in_plane = axis.cross(face).normalized()
	for i in range(LINKS):
		c = axis * (START + i * PITCH) + Vector((0, depth, 0))
		side = in_plane if i % 2 == 0 else face  # every other link turned 90 deg
		sweep(bm, link_path(c, axis, side), WIRE, 6, True, rot=math.pi / 6, normal=axis.cross(side))
	return new_obj(name, bm, mat)


def outline(w, h, c, bottom_c):
	"""Padlock body outline (X, Z), clockwise: chamfered corners, a bigger cut at the foot."""
	x, z = w / 2, h / 2
	return [
		(-x + c, z), (x - c, z), (x, z - c), (x, -z + bottom_c), (x - bottom_c, -z),
		(-x + bottom_c, -z), (-x, -z + bottom_c), (-x, z - c),
	]


def prism_chamfered(bm, pts, depth, edge, y0=0.0):
	"""Extrude an outline along Y with chamfered front and back edges (inset rings)."""
	cx = sum(p[0] for p in pts) / len(pts)
	cz = sum(p[1] for p in pts) / len(pts)

	def ring(y, inset):
		out = []
		for px, pz in pts:
			dx, dz = px - cx, pz - cz
			ln = math.hypot(dx, dz) or 1
			out.append(bm.verts.new((px - dx / ln * inset, y, pz - dz / ln * inset)))
		return out

	d = depth / 2
	rings = [ring(y0 - d, edge), ring(y0 - d + edge, 0), ring(y0 + d - edge, 0), ring(y0 + d, edge)]
	n = len(pts)
	for a, b in zip(rings, rings[1:]):
		for k in range(n):
			bm.faces.new((a[k], a[(k + 1) % n], b[(k + 1) % n], b[k]))
	front = bm.faces.new(list(reversed(rings[0])))
	bm.faces.new(rings[-1])
	return front


def boolean(target, cutter, op):
	mod = target.modifiers.new("b", "BOOLEAN")
	mod.operation = op
	mod.solver = "EXACT"
	mod.object = cutter
	bpy.context.view_layer.objects.active = target
	bpy.ops.object.modifier_apply(modifier=mod.name)
	bpy.data.objects.remove(cutter)


def keyhole_shape(bm, depth, y0, scale=1.0):
	"""A keyhole: an octagon over a tapered slot, as one closed prism along Y."""
	r = 0.17 * scale
	pts = []
	for k in range(8):
		a = math.pi / 2 + 2 * math.pi * k / 8 + math.pi / 8
		pts.append((math.cos(a) * r, 0.12 * scale + math.sin(a) * r))
	# replace the lowest two octagon points with the slot
	pts.sort(key=lambda p: math.atan2(p[1] - 0.12 * scale, p[0]))
	top = [p for p in pts if p[1] > 0.12 * scale - r * 0.6]
	top.sort(key=lambda p: -math.atan2(p[1] - 0.12 * scale, p[0]))
	slot = [(0.09 * scale, -0.05 * scale), (0.13 * scale, -0.36 * scale), (-0.13 * scale, -0.36 * scale), (-0.09 * scale, -0.05 * scale)]
	outline_pts = top[: len(top)] + slot
	# order clockwise around the centre
	cx = sum(p[0] for p in outline_pts) / len(outline_pts)
	cz = sum(p[1] for p in outline_pts) / len(outline_pts)
	outline_pts.sort(key=lambda p: -math.atan2(p[1] - cz, p[0] - cx))
	front = [bm.verts.new((px, y0 - depth / 2, pz)) for px, pz in outline_pts]
	back = [bm.verts.new((px, y0 + depth / 2, pz)) for px, pz in outline_pts]
	n = len(outline_pts)
	for k in range(n):
		bm.faces.new((front[k], front[(k + 1) % n], back[(k + 1) % n], back[k]))
	bm.faces.new(list(reversed(front)))
	bm.faces.new(back)


def padlock(gold, dark):
	front_y = -BODY_D / 2
	# body
	bm = bmesh.new()
	f = prism_chamfered(bm, outline(BODY_W, BODY_H, CHAMF, CHAMF * 1.8), BODY_D, EDGE)
	# a framed front panel: inset the front face, sink it a little
	res = bmesh.ops.inset_region(bm, faces=[f], thickness=0.18, depth=0)
	bmesh.ops.translate(bm, verts=list({v for face in [f] for v in face.verts}), vec=(0, 0.045, 0))
	body = new_obj("Padlock", bm, gold)
	# collars where the shackle legs enter the body (seated 0.12 into it)
	for sx in (-1, 1):
		bm = bmesh.new()
		top = BODY_H / 2
		base = Vector((sx * SHACKLE_R, 0, top - 0.12))
		path = [base, base + Vector((0, 0, 0.26))]
		sweep(bm, path, SHACKLE_WIRE * 1.55, 6, False, rot=0)
		collar = new_obj("Collar", bm, gold)
		boolean(body, collar, "UNION")
	# keyhole cut into the panel
	bm = bmesh.new()
	keyhole_shape(bm, 0.5, front_y + 0.045, 1.3)
	cutter = new_obj("Cut", bm, dark)
	boolean(body, cutter, "DIFFERENCE")
	# the dark insert at the keyhole's floor (set back 0.16 from the panel)
	bm = bmesh.new()
	keyhole_shape(bm, 0.08, front_y + 0.045 + 0.2, 1.32)
	new_obj("Keyhole", bm, dark)
	# shackle: legs seated 0.3 into the body, a faceted half ring on top
	bm = bmesh.new()
	top = BODY_H / 2
	pts = [Vector((-SHACKLE_R, 0, top - 0.3)), Vector((-SHACKLE_R, 0, top + SHACKLE_LEG))]
	for k in range(1, SHACKLE_ARC):
		a = math.pi - math.pi * k / SHACKLE_ARC
		pts.append(Vector((math.cos(a) * SHACKLE_R, 0, top + SHACKLE_LEG + math.sin(a) * SHACKLE_R)))
	pts += [Vector((SHACKLE_R, 0, top + SHACKLE_LEG)), Vector((SHACKLE_R, 0, top - 0.3))]
	sweep(bm, pts, SHACKLE_WIRE, 6, False, rot=math.pi / 6, normal=Vector((0, 1, 0)))
	new_obj("Shackle", bm, gold)
	return body


def build():
	clear()
	gold = material("LockGold", (0.98, 0.72, 0.16))
	dark = material("LockDark", (0.12, 0.08, 0.03))
	ca, sa = math.cos(ANGLE), math.sin(ANGLE)
	# the two diagonals sit at different depths so nothing meets at the crossing (behind the padlock)
	strand("ChainTR", Vector((ca, 0, sa)), 0.10, gold)
	strand("ChainBL", Vector((-ca, 0, -sa)), 0.10, gold)
	strand("ChainTL", Vector((-ca, 0, sa)), 0.28, gold)
	strand("ChainBR", Vector((ca, 0, -sa)), 0.28, gold)
	padlock(gold, dark)


def report():
	tris = 0
	rows = []
	for ob in bpy.data.objects:
		if ob.type != "MESH":
			continue
		ob.data.calc_loop_triangles()
		n = len(ob.data.loop_triangles)
		tris += n
		bm = bmesh.new()
		bm.from_mesh(ob.data)
		nm = sum(1 for e in bm.edges if not e.is_manifold)
		bm.free()
		smooth = sum(1 for p in ob.data.polygons if p.use_smooth)
		rows.append(f"{ob.name}: {n} tris, non-manifold edges {nm}, smooth faces {smooth}, dims {tuple(round(d, 2) for d in ob.dimensions)}")
	print("\n".join(rows))
	print(f"TOTAL {tris} tris")


def export():
	bpy.ops.object.select_all(action="DESELECT")
	for ob in bpy.data.objects:
		if ob.type == "MESH":
			ob.select_set(True)
	bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "LockerLock.blend"))
	bpy.ops.export_scene.fbx(
		filepath=os.path.join(OUT, "LockerLock.fbx"),
		use_selection=True,
		object_types={"MESH"},
		apply_scale_options="FBX_SCALE_UNITS",
		mesh_smooth_type="FACE",
		bake_anim=False,
	)


def render():
	scene = bpy.context.scene
	scene.render.engine = "BLENDER_WORKBENCH"
	scene.display.shading.light = "STUDIO"
	scene.display.shading.color_type = "MATERIAL"
	scene.display.shading.show_cavity = True
	scene.render.resolution_x, scene.render.resolution_y = 1200, 800
	world = bpy.data.worlds.new("W")
	scene.world = world
	cam_data = bpy.data.cameras.new("Cam")
	cam = bpy.data.objects.new("Cam", cam_data)
	scene.collection.objects.link(cam)
	scene.camera = cam
	shots = {
		"front": ((0, -14, 0.4), 50),
		"three_quarter": ((-7, -10, 3), 50),
		"padlock_close": ((1.2, -4.2, 0.9), 50),
		"links_close": ((3.4, -3.6, 2.4), 50),
	}
	targets = {"padlock_close": Vector((0, 0, 0.3)), "links_close": Vector((2.4, 0, 1.4))}
	for name, (pos, lens) in shots.items():
		cam.location = pos
		cam_data.lens = lens
		target = targets.get(name, Vector((0, 0, 0.2)))
		d = target - Vector(pos)
		cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
		scene.render.filepath = os.path.join(OUT, "review", f"{name}.png")
		bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
	args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
	build()
	report()
	export()
	if "--render" in args:
		render()
