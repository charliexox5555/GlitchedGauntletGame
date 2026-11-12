# review_generic.py: auto-framed review cameras + original comparison for any RemasterV2 weapon (Blender MCP only).
#   ns = {}; exec(compile(open(p).read(), p, "exec"), ns)
#   ns["setup"](gun, view, extra_cams)   stages lights, cameras, ADS range in <gun>_RemasterV2_Review
#   ns["render"](gun, cams, tag)
# view: {"aim": (x, y, z) or None, "ads_distance": studs, "ads_fov": deg, "vm_offset": (x, y, z), "vm_scale": s,
#        "hip_fov": 80}. ADS eye = AimPoint - ads_distance / vm_scale along X (Viewmodel.SCALE 0.75 for primaries);
#        held view from viewmodelOffset / scale (camera right = -Y, up = +Z, forward = +X; no sway/tilt/arms).

import bpy, os
from mathutils import Vector

ROOT = r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/art-source/weapons/RemasterV2"
ns_stage = {}
_p = ROOT + "/_Library/review_stage.py"
exec(compile(open(_p).read(), _p, "exec"), ns_stage)


def bounds(gun):
	pts = []
	for o in bpy.data.collections[gun].objects:
		if o.type == "MESH":
			pts += [o.matrix_world @ v.co for v in o.data.vertices]
	lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
	hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
	return lo, hi


def setup(gun, view, extra_cams=None):
	sc = bpy.data.scenes[gun + "_RemasterV2_Review"]
	lo, hi = bounds(gun)
	c = (lo + hi) / 2
	L, H, W = hi.x - lo.x, hi.z - lo.z, hi.y - lo.y
	frame = max(L, H * 16 / 9) * 1.2
	d = max(1.5 * L, 2.3 * H)
	cams = {
		"Cam_Hero": {"loc": tuple(c + Vector((0.50, 0.70, 0.33)).normalized() * d), "at": tuple(c), "lens": 42},
		"Cam_HeroR": {"loc": tuple(c + Vector((-0.45, -0.75, 0.30)).normalized() * d), "at": tuple(c), "lens": 42},
		"Cam_Side": {"loc": (c.x, 8.0, c.z), "at": (c.x, 0.0, c.z), "ortho": frame},
		"Cam_SideR": {"loc": (c.x, -8.0, c.z), "at": (c.x, 0.0, c.z), "ortho": frame},
		"Cam_Top": {"loc": (c.x, 0.0, 8.0), "at": (c.x, 0.0001, c.z), "ortho": frame},
		"Cam_Front": {"loc": (hi.x + 6.0, 0.0, c.z), "at": (lo.x, 0.0, c.z), "ortho": max(H, W) * 1.2},
	}
	s = view.get("vm_scale", 0.75)
	o = view.get("vm_offset")
	if o:
		hip = (o[2] / s, o[0] / s, -o[1] / s)  # Roblox camera: forward -Z, right +X (= gun -Y), up +Y
		cams["Cam_Hip"] = {"loc": hip, "at": (hip[0] + 30.0, hip[1], hip[2]), "fov_v": view.get("hip_fov", 80), "clip": 0.1 / s}
	aim = view.get("aim")
	eye = None
	if aim and view.get("ads_distance"):
		eye = (aim[0] - view["ads_distance"] / s, aim[1], aim[2])
		cams["Cam_ADS"] = {"loc": eye, "at": (eye[0] + 30.0, eye[1], eye[2]), "fov_v": view.get("ads_fov", 70), "clip": 0.1 / s}
	for k, v in (extra_cams or {}).items():
		cams[k] = v
	spec = {"prefix": gun, "center": tuple(c), "cams": cams, "ads": {"eye": eye or (lo.x - 1.0, 0.0, hi.z), "target_dist": 30.0}}
	ns_stage["stage"](sc, spec)
	return {"L": round(L, 3), "H": round(H, 3), "W": round(W, 3), "eye": eye}


def render(gun, cams, tag, ads_cams=("Cam_ADS", "Cam_Hip"), hide=(), res=None):
	sc = bpy.data.scenes[gun + "_RemasterV2_Review"]
	out_dir = ROOT + "/" + gun + "/renders"
	os.makedirs(out_dir, exist_ok=True)
	out = []
	for cam in cams:
		path = "%s/%s_%s.png" % (out_dir, tag, cam.replace("Cam_", "").lower())
		r = res or ((1080, 1080) if cam == "Cam_Front" else (1920, 1080))
		ns_stage["shoot"](sc, cam, path, ads=cam in ads_cams, res=r, hide=hide if cam == "Cam_ADS" else (), prefix=gun)
		out.append(path)
	return out


def ads_faded(gun, eye, near=0.16 / 0.75, prefixes=("Stock",)):
	# Mirrors ViewmodelController.findNearPlaneParts (the game fades these while aiming).
	out = []
	for o in bpy.data.collections[gun].objects:
		if o.type != "MESH" or not any(o.name.startswith(gun + "_" + p) for p in prefixes):
			continue
		xs = [(o.matrix_world @ v.co).x - eye[0] for v in o.data.vertices]
		if min(xs) < 0 and max(xs) > near:
			out.append(o.name)
	return out


def append_original(gun):
	# Appends the original <gun> collection + actions read-only into scene REF_<gun>_Original, names prefixed REF_.
	if ("REF_%s_Original" % gun) in bpy.data.scenes:
		return "exists"
	p = r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/art-source/weapons/%s.blend" % gun
	kinds = ("objects", "materials", "actions", "images", "collections", "armatures", "meshes")
	before = {k: set(getattr(bpy.data, k)) for k in kinds}
	with bpy.data.libraries.load(p, link=False) as (src, dst):
		dst.collections = [gun]
		dst.actions = list(src.actions)
	ref = bpy.data.scenes.new("REF_%s_Original" % gun)
	col = [c for c in bpy.data.collections if c not in before["collections"]][0]
	ref.collection.children.link(col)
	for k in kinds:
		for x in [x for x in getattr(bpy.data, k) if x not in before[k]]:
			x.name = "REF_" + x.name
	return "appended"


def original_report(gun):
	ref = bpy.data.scenes["REF_%s_Original" % gun]
	win = bpy.context.window
	prev = win.scene
	win.scene = ref
	ref.view_layers[0].update()
	out = {"bones": {}, "loc": {}, "parts": {}, "tris": 0, "acts": {}}
	col = bpy.data.collections["REF_" + gun]
	rig = [o for o in col.objects if o.type == "ARMATURE"][0]
	for b in rig.data.bones:
		out["bones"][b.name] = [round(v, 4) for v in b.head_local] + [b.parent.name if b.parent else "-"]
	for o in col.objects:
		if o.type == "EMPTY":
			out["loc"][o.name.replace("REF_", "")] = [round(v, 4) for v in o.matrix_world.translation] + [o.parent_bone]
		elif o.type == "MESH":
			t = sum(len(p.vertices) - 2 for p in o.data.polygons)
			out["tris"] += t
			ws = [o.matrix_world @ v.co for v in o.data.vertices]
			out["parts"][o.name.replace("REF_" + gun + "_", "")] = [t, o.parent_bone] + [[round(min(getattr(v, a) for v in ws), 3), round(max(getattr(v, a) for v in ws), 3)] for a in "xyz"]
	for a in bpy.data.actions:
		if a.name.startswith("REF_%s_" % gun):
			d = {"range": list(a.frame_range), "mk": dict(a["gg_markers"]) if "gg_markers" in a.keys() else {}}
			for l in a.layers:
				for s in l.strips:
					for cb in s.channelbags:
						for fc in cb.fcurves:
							vals = [k.co[1] for k in fc.keyframe_points]
							if max(vals) - min(vals) > 1e-5:
								d[fc.data_path.split('"')[1] + "." + fc.data_path.split(".")[-1][:3] + str(fc.array_index)] = [round(min(vals), 3), round(max(vals), 3)]
			out["acts"][a.name.replace("REF_%s_" % gun, "")] = d
	win.scene = prev
	return out


def compare(gun, cams, ads_cams=("Cam_ADS", "Cam_Hip")):
	# Renders the untouched original with this weapon's stage (same lights, cameras, world).
	sc = bpy.data.scenes[gun + "_RemasterV2_Review"]
	ref = bpy.data.scenes["REF_%s_Original" % gun]
	links = [bpy.data.collections[gun + n] for n in ("_RV2_Lights", "_RV2_Cameras", "_RV2_ADSRange")]
	for c in links:
		if c.name not in ref.collection.children:
			ref.collection.children.link(c)
	old_world = ref.world
	ref.world = sc.world
	ref.render.engine = sc.render.engine
	ref.view_settings.view_transform = sc.view_settings.view_transform
	ref.view_settings.look = sc.view_settings.look
	ref.render.resolution_x, ref.render.resolution_y = 1920, 1080
	ref.render.image_settings.file_format = "PNG"
	out = []
	for cam in cams:
		ref.camera = bpy.data.objects[gun + "_" + cam]
		links[2].hide_render = cam not in ads_cams
		p = ROOT + "/%s/renders/compare_original_%s.png" % (gun, cam.replace("Cam_", "").lower())
		ref.render.filepath = p
		with bpy.context.temp_override(window=bpy.context.window, scene=ref):
			bpy.ops.render.render(write_still=True, scene=ref.name)
		out.append(p)
	links[2].hide_render = True
	for c in links:
		ref.collection.children.unlink(c)
	ref.world = old_world
	return out
