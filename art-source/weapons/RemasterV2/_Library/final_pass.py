# final_pass.py: final polish pass helpers for the RemasterV2 weapons (2026-11-11). Blender MCP only.
#   ns = {}; exec(compile(open(p).read(), p, "exec"), ns)
#   ns["load"](gun)            appends the gun's latest <Gun>_RemasterV2_vNN.blend review scene into this session
#   ns["ads_cam"](gun)         a camera at the GAME's aiming eye (Weapons.luau adsDistance / adsFov, Viewmodel.SCALE)
#   ns["shot"](gun, cam, path) renders one picture
#   ns["sightline"](gun)       what the game's occluder pass would hit between the eye and AimPoint (true geometry
#                              and bounding boxes, since WeaponBuilder gives every part a Box collider)
#   ns["save"](gun, "v05")     writes the scene to <Gun>_RemasterV2_v05.blend
# Axes in these files: muzzle +X, gun-left +Y, up +Z; 1 unit = 1 stud at model scale 1.

import bpy, os, re, glob, math, sys
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

ROOT = r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/art-source/weapons/RemasterV2"
if ROOT + "/_Library" not in sys.path:
	sys.path.insert(0, ROOT + "/_Library")

GUNS = ["Vandal", "Phantom", "Bulldog", "Guardian", "Spectre", "Stinger", "Ares", "Odin", "Sheriff", "Classic", "Ghost",
	"Shorty", "Bucky", "Judge", "Marshal", "Outlaw", "Operator", "Knife"]

# src/shared/Config/Weapons.luau (2026-11-11). scale = viewmodelScale or Viewmodel.SCALE (0.8).
ADS = {
	"Vandal": {"fov": 68, "dist": 0.36, "scale": 0.8},
	"Phantom": {"fov": 68, "dist": 0.42, "scale": 0.8},
	"Bulldog": {"fov": 68, "dist": 0.38, "scale": 0.8},
	"Guardian": {"fov": 58, "dist": 0.33, "scale": 0.8},
	"Spectre": {"fov": 72, "dist": 0.37, "scale": 0.8},
	"Stinger": {"fov": 72, "dist": 0.30, "scale": 0.8},
	"Ares": {"fov": 70, "dist": 0.40, "scale": 0.8},
	"Odin": {"fov": 70, "dist": 0.39, "scale": 0.8},
	"Sheriff": {"fov": 68, "dist": 0.42, "scale": 1.1},
}
HIP = {  # viewmodelOffset (Roblox camera space: right, up, -forward), scale
	"Vandal": ((0.52, -0.266, -0.38), 0.8), "Phantom": ((0.52, -0.277, -0.38), 0.8),
	"Bulldog": ((0.44, -0.246, -0.85), 0.8), "Guardian": ((0.52, -0.3, -0.38), 0.8),
	"Spectre": ((0.46, -0.325, -0.92), 0.8), "Stinger": ((0.46, -0.324, -0.92), 0.8),
	"Ares": ((0.52, -0.291, -0.43), 0.8), "Odin": ((0.52, -0.3, -0.38), 0.8),
	"Marshal": ((0.52, -0.3, -0.47), 0.8), "Outlaw": ((0.52, -0.3, -0.47), 0.8), "Operator": ((0.52, -0.3, -0.47), 0.8),
	"Judge": ((0.36, -0.42, -0.95), 0.8), "Bucky": ((0.48, -0.4, -0.68), 0.8),
	"Sheriff": ((0.52, -0.72, -1.0), 1.1), "Classic": ((0.52, -0.72, -1.0), 1.1), "Ghost": ((0.52, -0.72, -1.0), 1.1),
	"Shorty": ((0.52, -0.72, -1.0), 1.1),
}
NEAR = 0.1  # Roblox camera near plane, studs


def latest(gun):
	best, ver = None, -1
	for p in glob.glob("%s/%s/%s_RemasterV2_v*.blend" % (ROOT, gun, gun)):
		m = re.search(r"_v(\d+)\.blend$", p)
		if m and int(m.group(1)) > ver:
			best, ver = p, int(m.group(1))
	return best, ver


def scene(gun):
	return bpy.data.scenes.get(gun + "_RemasterV2_Review")


def load(gun, ver=None):
	if scene(gun) is not None:
		return "loaded"
	path, v = latest(gun)
	if ver is not None:
		path = "%s/%s/%s_RemasterV2_v%02d.blend" % (ROOT, gun, gun, ver)
	before = set(bpy.data.scenes)
	with bpy.data.libraries.load(path, link=False) as (src, dst):
		dst.scenes = [s for s in src.scenes if s.startswith(gun + "_RemasterV2_")][:1]
		dst.actions = [a for a in src.actions if a.startswith(gun + "_")]
	sc = [s for s in bpy.data.scenes if s not in before][0]
	sc.name = gun + "_RemasterV2_Review"  # v04 files named the scene after the version
	sc["rv2"] = True
	sc["fp_source"] = os.path.basename(path)
	ensure_stage(gun)
	return os.path.basename(path)


def bounds(gun):
	pts = [o.matrix_world @ v.co for o in meshes(gun) for v in o.data.vertices]
	lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
	hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
	return lo, hi


def ensure_stage(gun):
	# Lights, world and the ADS range (review_stage.py); v04 files were saved without them.
	sc = scene(gun)
	if bpy.data.collections.get(gun + "_RV2_Lights") is not None and gun + "_RV2_Lights" in [c.name for c in sc.collection.children]:
		return False
	ns = {}
	p = ROOT + "/_Library/review_stage.py"
	exec(compile(open(p).read(), p, "exec"), ns)
	sc.view_layers[0].update()
	lo, hi = bounds(gun)
	c = (lo + hi) / 2
	e = tuple(eye(gun)) if gun in ADS and locator(gun, "AimPoint") is not None else (lo.x - 1.0, 0.0, hi.z)
	ns["stage"](sc, {"prefix": gun, "center": tuple(c), "cams": {}, "ads": {"eye": e, "target_dist": 30.0}})
	return True


def col(gun):
	return bpy.data.collections[gun]


def meshes(gun):
	return [o for o in col(gun).objects if o.type == "MESH"]


def obj(gun, part):
	return bpy.data.objects[gun + "_" + part]


def rest(gun):
	rig = bpy.data.objects.get(gun + "_Rig")
	if rig is None:
		return
	if rig.animation_data:
		rig.animation_data.action = None
	for pb in rig.pose.bones:
		pb.location = (0, 0, 0)
		pb.rotation_euler = (0, 0, 0)
		pb.rotation_quaternion = (1, 0, 0, 0)
	sc = scene(gun)
	sc.frame_set(1)
	sc.view_layers[0].update()


def locator(gun, name):
	o = bpy.data.objects.get(gun + "_" + name)
	return None if o is None else o.matrix_world.translation.copy()


def eye(gun):
	a = ADS[gun]
	aim = locator(gun, "AimPoint")
	return Vector((aim.x - a["dist"] / a["scale"], aim.y, aim.z))


def camera(gun, name, loc, at, fov_v=None, lens=50.0, ortho=None, clip=0.01, aspect=16 / 9):
	sc = scene(gun)
	cname = gun + "_FP_" + name
	cam = bpy.data.objects.get(cname)
	if cam is None:
		cam = bpy.data.objects.new(cname, bpy.data.cameras.new(cname))
		cc = bpy.data.collections.get(gun + "_FP_Cams")
		if cc is None:
			cc = bpy.data.collections.new(gun + "_FP_Cams")
			sc.collection.children.link(cc)
		cc.objects.link(cam)
	d = cam.data
	cam.location = loc
	fwd = (Vector(at) - Vector(loc)).normalized()
	cam.rotation_euler = fwd.to_track_quat("-Z", "Y").to_euler()
	d.clip_start, d.clip_end = clip, 500
	if ortho:
		d.type = "ORTHO"
		d.ortho_scale = ortho
	else:
		d.type = "PERSP"
		if fov_v:
			d.sensor_fit = "VERTICAL"
			d.sensor_height = 24
			d.lens = 12 / math.tan(math.radians(fov_v) / 2)
		else:
			d.sensor_fit = "AUTO"
			d.lens = lens
	return cam


def ads_cam(gun):
	e = eye(gun)
	a = ADS[gun]
	return camera(gun, "ADS", e, (e.x + 30, e.y, e.z), fov_v=a["fov"], clip=NEAR / a["scale"])


def hip_cam(gun, fov=80):
	o, s = HIP[gun]
	# Game places the gun's AimPoint/grip by viewmodelOffset; the old review used the handle origin: keep that.
	loc = (o[2] / s, o[0] / s, -o[1] / s)
	return camera(gun, "Hip", loc, (loc[0] + 30, loc[1], loc[2]), fov_v=fov, clip=NEAR / s)


def shot(gun, cam, path, res=(1280, 720), rng=False, hide=(), samples=32):
	sc = scene(gun)
	sc.camera = cam if not isinstance(cam, str) else bpy.data.objects[cam]
	r = sc.render
	r.resolution_x, r.resolution_y = res
	r.resolution_percentage = 100
	r.image_settings.file_format = "PNG"
	r.filepath = path
	try:
		sc.eevee.taa_render_samples = samples
	except Exception:
		pass
	rc = bpy.data.collections.get(gun + "_RV2_ADSRange")
	if rc is not None:
		rc.hide_render = not rng
	hid = []
	for n in hide:
		o = bpy.data.objects.get(n)
		if o is not None and not o.hide_render:
			o.hide_render = True
			hid.append(o)
	os.makedirs(os.path.dirname(path), exist_ok=True)
	with bpy.context.temp_override(window=bpy.context.window, scene=sc):
		bpy.ops.render.render(write_still=True, scene=sc.name)
	for o in hid:
		o.hide_render = False
	if rc is not None:
		rc.hide_render = True
	return path


def _world_tris(ob, dg):
	ev = ob.evaluated_get(dg)
	me = ev.to_mesh()
	mw = ob.matrix_world
	co = [mw @ v.co for v in me.vertices]
	polys = [list(p.vertices) for p in me.polygons]
	mats = [ob.material_slots[p.material_index].material.name if ob.material_slots else "?" for p in me.polygons]
	ev.to_mesh_clear()
	return co, polys, mats


def sightline(gun, spread=0.012):
	# Mirrors ViewmodelController.findOccluders in model units: 5 rays from the eye toward AimPoint, length
	# distance - 0.02 studs. Reports true-geometry hits, and the Roblox parts (<Part>_<Material>, Box colliders)
	# whose bounding boxes the rays cross. Names containing "Sight" are exempt in the game.
	a = ADS[gun]
	s = a["scale"]
	e = eye(gun)
	length = (a["dist"] - 0.02) / s
	dg = bpy.context.evaluated_depsgraph_get()
	hits, boxes = {}, {}
	offs = [(0, 0), (spread / s, 0), (-spread / s, 0), (0, spread / s), (0, -spread / s)]
	for ob in meshes(gun):
		part = ob.name[len(gun) + 1:]
		co, polys, mats = _world_tris(ob, dg)
		if not polys:
			continue
		tree = BVHTree.FromPolygons(co, polys)
		for dy, dz in offs:
			o = Vector((e.x, e.y + dy, e.z + dz))
			h = tree.ray_cast(o, Vector((1, 0, 0)), length)
			if h[0] is not None:
				hits.setdefault(part + "_" + mats[h[2]], round(h[3], 4))
		by = {}
		for p, m in zip(polys, mats):
			by.setdefault(m, []).extend(p)
		for m, idx in by.items():
			xs = [co[i].x for i in idx]; ys = [co[i].y for i in idx]; zs = [co[i].z for i in idx]
			for dy, dz in offs:
				y, z = e.y + dy, e.z + dz
				if min(ys) <= y <= max(ys) and min(zs) <= z <= max(zs) and max(xs) > e.x and min(xs) < e.x + length:
					boxes[part + "_" + m] = [round(min(xs) - e.x, 3), round(max(xs) - e.x, 3)]
	return {"eye": [round(v, 4) for v in e], "len": round(length, 4), "geo_hits": hits, "box_hits": boxes}


def tris(gun):
	return sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in meshes(gun))


def save(gun, version):
	import v2kit as K
	sc = scene(gun)
	path = "%s/%s/%s_RemasterV2_%s.blend" % (ROOT, gun, gun, version)
	if os.path.exists(path):
		os.remove(path)  # only ever this pass's own output
	for a in bpy.data.actions:
		if a.name.startswith(gun + "_"):
			a["rv2"] = True
	return K.write_blend(path, sc, gun)


def unload(gun):
	# Drops the gun's scene and data from this session (its .blend on disk is untouched).
	keep = bpy.data.scenes.get("Scene")
	if keep is not None:
		bpy.context.window.scene = keep
	sc = scene(gun)
	if sc is not None:
		for c in list(sc.collection.children_recursive):
			for ob in list(c.objects):
				bpy.data.objects.remove(ob)
			bpy.data.collections.remove(c)
		for ob in list(sc.collection.objects):
			bpy.data.objects.remove(ob)
		bpy.data.scenes.remove(sc)
	for a in [a for a in bpy.data.actions if a.name.startswith(gun + "_")]:
		bpy.data.actions.remove(a)
	bpy.data.orphans_purge(do_local_ids=True, do_linked_ids=False, do_recursive=True)
	return len(bpy.data.scenes)
