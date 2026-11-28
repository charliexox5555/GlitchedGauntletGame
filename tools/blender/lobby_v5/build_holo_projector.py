"""Lobby hologram projector for Draft Duels (vault/02 Art/Lobby Holograms.md).

Run in a live Blender MCP instance: exec this file with {"VERSION": "v01"} in globals.

Units: 1 Blender unit = 1 stud. X = width, -Y = front, Z = up, origin = floor centre.
Style (gauntlet-build-style / gauntlet-model-joins): 8-sided faceted only (no smooth faces, no subdivision),
chamfers from an angle-limited 1-segment bevel applied AFTER an exact union of each part's shells, every detail
seated 0.02+ into what carries it.

Parts (one MeshPart each in Studio; Studio colours them by role):
    Base_Body   the battered 8-sided plinth on its foot flange (dark gunmetal)
    Base_Trim   the lens collar and the four emitter arms (charcoal steel)
    Base_Light  the lens, the arm tips and the four facet light strips (Neon, hologram colour)
    Holo_Cone   the open light cone from the lens up to the item (double-sided, UV v = 0 at the lens, 1 at the top)
    Holo_Ring   the flat 8-sided floor ring round the foot (Neon, sits 0.03 above the floor)
"""

import json
import math
import os

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = r"C:\Users\charl\Documents\GauntletGame\GlitchedGauntletGame"
_g = globals()
VERSION = _g.get("VERSION") or "v01"
OUT_DIR = os.path.join(ROOT, "art-source", "lobby", "HoloProjector")
BLEND = os.path.join(OUT_DIR, f"HoloProjector_{VERSION}.blend")
FBX = os.path.join(OUT_DIR, f"HoloProjector_{VERSION}.fbx")
OUT_JSON = os.path.join(OUT_DIR, f"HoloProjector_{VERSION}.json")
REVIEW_DIR = os.path.join(OUT_DIR, "review", VERSION)
COLL = "HOLOPROJECTOR"

N = 8
A0 = math.radians(22.5)  # vertices at 22.5 + k*45: a flat face is centred on every axis and diagonal

PALETTE = {
	"Body": ("3A3D44", 0.0),
	"Trim": ("23252A", 0.0),
	"Light": ("4FC8FF", 2.0),
	"Cone": ("4FC8FF", 1.0),
	"Ring": ("4FC8FF", 1.5),
}

# (z, circumradius) profiles
FOOT = [(0.0, 2.70), (0.20, 2.70), (0.34, 2.52)]
BODY = [(0.30, 2.34), (0.98, 2.04), (1.08, 1.96)]
COLLAR_OUT = [(1.02, 1.98), (1.22, 1.86), (1.36, 1.66)]
COLLAR_IN = [(1.10, 1.20), (1.36, 1.34)]
LENS = (1.08, 1.16, 1.12)  # z0, z1, r
ARM_ANGLES = [45, 135, 225, 315]
# arm profile in (radial, z): seated in the body top, rising out over the collar and leaning in to the tip
# the arm runs down the battered body face (0.12-0.15 proud) to a clamp plate, so it reads clamped on, not stuck on top
ARM = [
	(1.70, 0.47),
	(2.20, 0.47),
	(2.28, 0.57),
	(2.04, 1.12),
	(2.04, 1.38),
	(1.58, 2.02),
	(1.40, 2.20),
	(1.20, 2.13),
	(1.20, 1.98),
	(1.44, 1.56),
	(1.52, 1.36),
	(1.70, 1.00),
]
ARM_T = 0.32  # tangential thickness
CLAMP = (0.40, 0.74, 0.78)  # z0, z1, width of the clamp plate under each arm
CONE = (1.18, 0.96, 5.4, 3.1)  # z0, r0, z1, r1
RING = (2.95, 3.30, 0.0, 0.035)  # r_in, r_out, z0, z1


def hex_lin(h):
	c = [int(h[i : i + 2], 16) / 255 for i in (0, 2, 4)]
	return tuple(((v + 0.055) / 1.055) ** 2.4 if v > 0.04045 else v / 12.92 for v in c) + (1.0,)


def make_mat(role):
	name = f"HoloProjector_{role}"
	m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
	hexv, emit = PALETTE[role]
	lin = hex_lin(hexv)
	m.diffuse_color = lin
	m.use_nodes = True
	b = m.node_tree.nodes.get("Principled BSDF")
	b.inputs["Base Color"].default_value = lin
	b.inputs["Roughness"].default_value = 0.55
	b.inputs["Metallic"].default_value = 0.3 if role in ("Body", "Trim") else 0.0
	b.inputs["Emission Color"].default_value = lin
	b.inputs["Emission Strength"].default_value = emit
	if role == "Cone":
		b.inputs["Alpha"].default_value = 0.25
		if hasattr(m, "blend_method"):
			m.blend_method = "BLEND"
	return m


def ring(r, z, n=N, a0=A0):
	return [(r * math.cos(a0 + k * 2 * math.pi / n), r * math.sin(a0 + k * 2 * math.pi / n), z) for k in range(n)]


def loft(rings, cap0=True, cap1=True):
	bm = bmesh.new()
	vs = [[bm.verts.new(p) for p in r] for r in rings]
	n = len(vs[0])
	if cap0:
		bm.faces.new(list(reversed(vs[0])))
	if cap1:
		bm.faces.new(vs[-1])
	for a, b in zip(vs, vs[1:]):
		for i in range(n):
			j = (i + 1) % n
			bm.faces.new((a[i], a[j], b[j], b[i]))
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	return bm


def shell(outer, inner):
	"""Hollow open-top shell: outer rings bottom->top, inner rings bottom->top (inner[0] is the floor)."""
	bm = bmesh.new()
	o = [[bm.verts.new(p) for p in r] for r in outer]
	i_ = [[bm.verts.new(p) for p in r] for r in inner]
	n = len(o[0])
	bm.faces.new(list(reversed(o[0])))
	bm.faces.new(i_[0])
	for rs in (o, i_):
		for a, b in zip(rs, rs[1:]):
			for k in range(n):
				j = (k + 1) % n
				bm.faces.new((a[k], a[j], b[j], b[k]))
	top_o, top_i = o[-1], i_[-1]
	for k in range(n):
		j = (k + 1) % n
		bm.faces.new((top_o[k], top_o[j], top_i[j], top_i[k]))
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	return bm


def plate(pts2, t0, t1, frame):
	bm = bmesh.new()
	a = [bm.verts.new(frame @ Vector((u, v, t0))) for u, v in pts2]
	b = [bm.verts.new(frame @ Vector((u, v, t1))) for u, v in pts2]
	bm.faces.new(a)
	bm.faces.new(list(reversed(b)))
	n = len(pts2)
	for i in range(n):
		j = (i + 1) % n
		bm.faces.new((a[i], a[j], b[j], b[i]))
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	return bm


def cham_poly(w, h, c):
	x0, x1, y0, y1 = -w / 2, w / 2, -h / 2, h / 2
	return [(x0 + c, y0), (x1 - c, y0), (x1, y0 + c), (x1, y1 - c), (x1 - c, y1), (x0 + c, y1), (x0, y1 - c), (x0, y0 + c)]


def frame_from(origin, normal, up_hint=Vector((0, 0, 1))):
	z = Vector(normal).normalized()
	x = up_hint.cross(z)
	if x.length < 1e-4:
		x = Vector((1, 0, 0))
	x.normalize()
	y = z.cross(x)
	m = Matrix((x, y, z)).transposed().to_4x4()
	m.translation = Vector(origin)
	return m


def radial_frame(deg):
	"""Frame whose X = radial out, Y = up (world Z), Z = tangential, at angle deg."""
	a = math.radians(deg)
	x = Vector((math.cos(a), math.sin(a), 0))
	y = Vector((0, 0, 1))
	z = x.cross(y)
	return Matrix((x, y, z)).transposed().to_4x4()


def apothem(r):
	return r * math.cos(math.pi / N)


# --- parts ------------------------------------------------------------------------------------


def base_body():
	return [loft([ring(r, z) for z, r in FOOT]), loft([ring(r, z) for z, r in BODY])]


def base_trim():
	out = [shell([ring(r, z) for z, r in COLLAR_OUT], [ring(r, z) for z, r in COLLAR_IN])]
	for deg in ARM_ANGLES:
		# the arm sits on a face centre (faces are centred on 0/45/90...), radial profile, chamfered outline
		out.append(plate(ARM, -ARM_T / 2, ARM_T / 2, radial_frame(deg)))
		# clamp plate seated on the battered face under the arm foot
		z0, z1, w = CLAMP
		(za, ra), (zb, rb) = BODY[0], BODY[1]
		zm = (z0 + z1) / 2
		t = (zm - za) / (zb - za)
		ap = apothem(ra + (rb - ra) * t)
		a = math.radians(deg)
		radial = Vector((math.cos(a), math.sin(a), 0))
		n = (radial * (zb - za) + Vector((0, 0, apothem(ra) - apothem(rb)))).normalized()
		f = frame_from(radial * ap + Vector((0, 0, zm)), n)
		out.append(plate(cham_poly(w, z1 - z0, 0.07), -0.04, 0.07, f))
	return out


def base_light():
	z0, z1, r = LENS
	out = [loft([ring(r, z0), ring(r, z1)])]
	for deg in ARM_ANGLES:
		# tip emitter: a small block let into the arm's inner face, just under the tip
		f = radial_frame(deg)
		pts = [(1.15, 1.95), (1.24, 1.95), (1.24, 2.09), (1.15, 2.09)]
		out.append(plate(pts, -ARM_T / 2 + 0.07, ARM_T / 2 - 0.07, f))
	# facet strips on the battered body faces between the arms (0/90/180/270)
	(za, ra), (zb, rb) = BODY[0], BODY[1]
	zm = 0.64
	t = (zm - za) / (zb - za)
	ap = apothem(ra + (rb - ra) * t)
	slope = Vector((apothem(rb) - apothem(ra), zb - za))
	for deg in (0, 90, 180, 270):
		a = math.radians(deg)
		radial = Vector((math.cos(a), math.sin(a), 0))
		# face normal: radial tilted up by the batter
		n = (radial * (zb - za) + Vector((0, 0, -(slope.x)))).normalized()
		origin = radial * ap + Vector((0, 0, zm))
		f = frame_from(origin, n)
		out.append(plate(cham_poly(1.05, 0.13, 0.05), -0.03, 0.035, f))
	return out


def holo_cone():
	z0, r0, z1, r1 = CONE
	bm = bmesh.new()
	uv = bm.loops.layers.uv.new("UVMap")
	for side in (1, -1):  # outward faces, then inward copies on their own verts (double-sided)
		lo = [bm.verts.new(p) for p in ring(r0, z0)]
		hi = [bm.verts.new(p) for p in ring(r1, z1)]
		for i in range(N):
			j = (i + 1) % N
			quad = (lo[i], lo[j], hi[j], hi[i]) if side == 1 else (hi[i], hi[j], lo[j], lo[i])
			f = bm.faces.new(quad)
			u0, u1 = i / N, (i + 1) / N
			uvs = [(u0, 0), (u1, 0), (u1, 1), (u0, 1)] if side == 1 else [(u0, 1), (u1, 1), (u1, 0), (u0, 0)]
			for loop, c in zip(f.loops, uvs):
				loop[uv].uv = c
	bm.normal_update()
	return bm


def holo_ring():
	r_in, r_out, z0, z1 = RING
	bm = bmesh.new()
	ob = [bm.verts.new(p) for p in ring(r_out, z0)]
	ot = [bm.verts.new(p) for p in ring(r_out, z1)]
	ib = [bm.verts.new(p) for p in ring(r_in, z0)]
	it = [bm.verts.new(p) for p in ring(r_in, z1)]
	for i in range(N):
		j = (i + 1) % N
		bm.faces.new((ot[i], ot[j], it[j], it[i]))  # top
		bm.faces.new((ib[i], ib[j], ob[j], ob[i]))  # bottom
		bm.faces.new((ob[i], ob[j], ot[j], ot[i]))  # outer
		bm.faces.new((it[i], it[j], ib[j], ib[i]))  # inner
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	return bm


def bm_objs(name, bms, coll):
	objs = []
	for i, bm in enumerate(bms):
		m = bpy.data.meshes.new(f"{name}_s{i}")
		bm.to_mesh(m)
		bm.free()
		o = bpy.data.objects.new(f"{name}_s{i}", m)
		coll.objects.link(o)
		objs.append(o)
	return objs


def union_bevel(name, bms, scratch, bevel):
	shells = bm_objs(name, bms, scratch)
	base = shells[0]
	ops = None
	if len(shells) > 1:
		ops = bpy.data.collections.new(name + "_ops")
		scratch.children.link(ops)
		for o in shells[1:]:
			scratch.objects.unlink(o)
			ops.objects.link(o)
		mod = base.modifiers.new("Union", "BOOLEAN")
		mod.operation = "UNION"
		mod.solver = "EXACT"
		mod.use_self = True
		mod.operand_type = "COLLECTION"
		mod.collection = ops
	if bevel > 0:
		bv = base.modifiers.new("Bevel", "BEVEL")
		bv.width = bevel
		bv.segments = 1
		bv.limit_method = "ANGLE"
		bv.angle_limit = math.radians(40)
	dg = bpy.context.evaluated_depsgraph_get()
	me = bpy.data.meshes.new_from_object(base.evaluated_get(dg))
	bm = bmesh.new()
	bm.from_mesh(me)
	bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
	bmesh.ops.triangulate(bm, faces=list(bm.faces))
	bm.to_mesh(me)
	bm.free()
	me.name = name
	for o in shells:
		bpy.data.objects.remove(o)
	if ops:
		bpy.data.collections.remove(ops)
	return me


def plain(name, bm):
	bmesh.ops.triangulate(bm, faces=list(bm.faces))
	me = bpy.data.meshes.new(name)
	bm.to_mesh(me)
	bm.free()
	return me


def check(me):
	bm = bmesh.new()
	bm.from_mesh(me)
	nm = sum(1 for e in bm.edges if not e.is_manifold)
	seen, islands = set(), 0
	for v in bm.verts:
		if v.index in seen:
			continue
		islands += 1
		stack = [v]
		while stack:
			x = stack.pop()
			if x.index in seen:
				continue
			seen.add(x.index)
			stack.extend(e.other_vert(x) for e in x.link_edges)
	bm.free()
	return {"tris": len(me.polygons), "non_manifold": nm, "islands": islands, "smooth": sum(1 for p in me.polygons if p.use_smooth)}


def build():
	bpy.ops.wm.read_homefile(use_empty=True, use_factory_startup=True)
	sc = bpy.context.scene
	coll = bpy.data.collections.new(COLL)
	sc.collection.children.link(coll)
	scratch = bpy.data.collections.new("_scratch")
	sc.collection.children.link(scratch)
	spec = [
		("Base_Body", "Body", union_bevel("Base_Body", base_body(), scratch, 0.06)),
		("Base_Trim", "Trim", union_bevel("Base_Trim", base_trim(), scratch, 0.035)),
		("Base_Light", "Light", union_bevel("Base_Light", base_light(), scratch, 0.0)),
		("Holo_Cone", "Cone", plain("Holo_Cone", holo_cone())),
		("Holo_Ring", "Ring", plain("Holo_Ring", holo_ring())),
	]
	info = {"version": VERSION, "parts": {}, "tris": 0}
	objs = {}
	for name, role, me in spec:
		for p in me.polygons:
			p.use_smooth = False
		me.materials.clear()
		me.materials.append(make_mat(role))
		ob = bpy.data.objects.new(name, me)
		coll.objects.link(ob)
		st = check(me)
		info["parts"][name] = st
		info["tris"] += st["tris"]
		objs[name] = ob
	bpy.data.collections.remove(scratch)
	return coll, objs, info


def coplanar_pairs(objs, tol=0.0015):
	data = []
	for name, ob in objs.items():
		if name.startswith("Holo_"):
			continue
		for p in ob.data.polygons:
			data.append((name, p.center.copy(), p.normal.copy(), p.area))
	hits, sample = 0, []
	for i in range(len(data)):
		ni, ci, nn, ai = data[i]
		for j in range(i + 1, len(data)):
			nj, cj, nm, aj = data[j]
			if ni == nj or nn.dot(nm) < 0.999 or abs((cj - ci).dot(nn)) > tol:
				continue
			if (cj - ci).length > (math.sqrt(ai) + math.sqrt(aj)):
				continue
			hits += 1
			if len(sample) < 6:
				sample.append([ni, nj, [round(x, 3) for x in ci]])
	return hits, sample


def shoot(sc, cam, loc, target, path, lens=50, res=720):
	cam.location = Vector(loc)
	cam.rotation_euler = (Vector(target) - cam.location).to_track_quat("-Z", "Y").to_euler()
	cam.data.lens = lens
	sc.render.resolution_x = sc.render.resolution_y = res
	sc.render.filepath = path
	bpy.ops.render.render(write_still=True)


def render(objs):
	sc = bpy.context.scene
	sc.render.engine = "BLENDER_EEVEE"
	sc.view_settings.view_transform = "Standard"
	sc.render.image_settings.file_format = "PNG"
	w = bpy.data.worlds.new("HoloWorld")
	w.use_nodes = True
	w.node_tree.nodes["Background"].inputs[0].default_value = (0.05, 0.052, 0.065, 1.0)
	sc.world = w
	floor = bpy.data.objects.new("_Floor", bpy.data.meshes.new("_Floor"))
	fb = bmesh.new()
	bmesh.ops.create_grid(fb, x_segments=1, y_segments=1, size=12)
	fb.to_mesh(floor.data)
	fb.free()
	fm = bpy.data.materials.new("_FloorMat")
	fm.diffuse_color = hex_lin("6E6A64")
	floor.data.materials.append(fm)
	floor.location.z = -0.001
	sc.collection.objects.link(floor)
	for name, loc, energy, size in (("Key", (-5, -6, 6), 900, 4.0), ("Fill", (6, -3, 2.5), 300, 4.0), ("Rim", (2, 6, 5), 600, 3.0)):
		lt = bpy.data.objects.new("L_" + name, bpy.data.lights.new("L_" + name, "AREA"))
		sc.collection.objects.link(lt)
		lt.location = Vector(loc)
		lt.data.energy, lt.data.size = energy, size
		lt.rotation_euler = (Vector((0, 0, 1)) - lt.location).to_track_quat("-Z", "Y").to_euler()
	cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
	sc.collection.objects.link(cam)
	sc.camera = cam
	os.makedirs(REVIEW_DIR, exist_ok=True)
	cone = objs["Holo_Cone"]
	cone.hide_render = True
	shots = {
		"hero": ((-5.5, -8.0, 4.2), (0, 0, 1.0), 45),
		"front": ((0, -8.5, 1.4), (0, 0, 1.0), 45),
		"top": ((1.5, -3.5, 5.5), (0, 0, 1.2), 40),
		"arm_close": ((2.6, -3.2, 2.4), (1.1, -1.1, 1.6), 50),
		"collar_close": ((0.4, -2.6, 2.9), (0, -0.4, 1.2), 50),
		"foot_close": ((-1.2, -4.2, 0.6), (0, -2.2, 0.4), 50),
	}
	for k, (loc, tgt, lens) in shots.items():
		shoot(sc, cam, loc, tgt, os.path.join(REVIEW_DIR, f"{k}.png"), lens=lens)
	cone.hide_render = False
	shoot(sc, cam, (-7, -10, 5), (0, 0, 2.6), os.path.join(REVIEW_DIR, "with_cone.png"), lens=40)
	bpy.data.objects.remove(floor)


def export_fbx(coll):
	objs = list(coll.objects)
	win = bpy.context.window_manager.windows[0]
	with bpy.context.temp_override(window=win, selected_objects=objs, active_object=objs[0]):
		bpy.ops.export_scene.fbx(filepath=FBX, use_selection=True, object_types={"MESH"}, apply_scale_options="FBX_SCALE_UNITS", use_mesh_modifiers=True, bake_anim=False)


def main():
	os.makedirs(OUT_DIR, exist_ok=True)
	coll, objs, info = build()
	hits, sample = coplanar_pairs(objs)
	info["coplanar_pairs"], info["coplanar_sample"] = hits, sample
	info["subdiv_modifiers"] = sum(1 for o in objs.values() for m in o.modifiers if m.type == "SUBSURF")
	export_fbx(coll)
	with bpy.context.temp_override(window=bpy.context.window_manager.windows[0]):
		render(objs)
		bpy.ops.wm.save_as_mainfile(filepath=BLEND)
	with open(OUT_JSON, "w", encoding="utf-8") as f:
		json.dump(info, f, indent=2)
	return info


result = main()
