# review_stage.py: neutral studio lighting, review cameras, ADS range and render helper for RemasterV2.
# Runs through Blender MCP in the interactive session, inside the weapon's own review scene only.
#
#   ns = {}; exec(compile(open(p).read(), p, "exec"), ns)
#   ns["stage"](scene, gun_collection_name, spec)   # spec: cameras + ADS numbers (see Vandal review script)
#   ns["shoot"](scene, "Cam_Side", out_path, ads=False)

import bpy, math
from mathutils import Vector, Matrix

TAG = "rv2"


def _col(sc, name):
	c = bpy.data.collections.get(name)
	if c is None:
		c = bpy.data.collections.new(name)
		c[TAG] = True
		sc.collection.children.link(c)
	elif not c.get(TAG):
		raise RuntimeError("collection clash: " + name)
	for o in list(c.objects):
		data = o.data
		bpy.data.objects.remove(o)
		if data is not None and data.users == 0:
			for coll in (bpy.data.cameras, bpy.data.lights, bpy.data.meshes):
				if data.name in coll and coll[data.name] == data:
					coll.remove(data)
					break
	return c


def _mat(name, rgb, rough=0.6, emit=None):
	m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
	m[TAG] = True
	m.use_nodes = True
	b = m.node_tree.nodes.get("Principled BSDF")
	b.inputs["Base Color"].default_value = (*rgb, 1)
	b.inputs["Roughness"].default_value = rough
	if emit:
		b.inputs["Emission Color"].default_value = (*rgb, 1)
		b.inputs["Emission Strength"].default_value = emit
	m.diffuse_color = (*rgb, 1)
	return m


def look_at(ob, target):
	d = Vector(target) - ob.location
	ob.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()


def _light(col, name, kind, loc, target, energy, size=1.0, color=(1, 1, 1)):
	ld = bpy.data.lights.new(name, kind)
	ld.energy = energy
	ld.color = color
	if kind == "AREA":
		ld.shape = "RECTANGLE"
		ld.size = size
		ld.size_y = size * 0.6
	ob = bpy.data.objects.new(name, ld)
	col.objects.link(ob)
	ob.location = loc
	look_at(ob, target)
	return ob


def _cam(col, name, loc, target, lens=50.0, ortho=None, fov_v=None, clip=0.05):
	cd = bpy.data.cameras.new(name)
	cd.clip_start = clip
	cd.clip_end = 200
	if ortho:
		cd.type = "ORTHO"
		cd.ortho_scale = ortho
	elif fov_v:
		cd.sensor_fit = "VERTICAL"
		cd.lens_unit = "FOV"
		cd.angle_y = math.radians(fov_v)
	else:
		cd.lens = lens
	ob = bpy.data.objects.new(name, cd)
	col.objects.link(ob)
	ob.location = loc
	look_at(ob, target)
	return ob


def stage(sc, spec):
	# World: flat neutral grey (backdrop + soft ambient). No HDRI, no coloured cast.
	w = bpy.data.worlds.get("RV2_Studio") or bpy.data.worlds.new("RV2_Studio")
	w[TAG] = True
	w.use_nodes = True
	bg = w.node_tree.nodes.get("Background")
	bg.inputs["Color"].default_value = (0.105, 0.11, 0.12, 1)
	bg.inputs["Strength"].default_value = 0.55
	sc.world = w

	r = sc.render
	r.engine = "BLENDER_EEVEE"
	r.resolution_x, r.resolution_y = 1920, 1080
	r.resolution_percentage = 100
	r.film_transparent = False
	r.image_settings.file_format = "PNG"
	try:
		sc.eevee.taa_render_samples = 48
		sc.eevee.use_shadows = True
	except Exception:
		pass
	sc.view_settings.view_transform = "AgX"
	try:
		sc.view_settings.look = "AgX - Medium High Contrast"
	except Exception:
		pass

	c = Vector(spec["center"])
	pre = spec.get("prefix", "")
	cname = lambda n: (pre + "_" + n) if pre else n
	k = spec.get("light_scale", 1.0)
	lights = _col(sc, cname("RV2_Lights"))
	_light(lights, "Key", "AREA", c + Vector((0.8, 3.0, 2.4)), c, 120 * k, 3.0)
	_light(lights, "Fill", "AREA", c + Vector((1.5, -2.6, 0.6)), c, 40 * k, 3.0)
	_light(lights, "Rim", "AREA", c + Vector((-2.8, 0.6, 2.0)), c, 110 * k, 2.0)
	_light(lights, "Top", "AREA", c + Vector((0.0, 0.0, 3.0)), c, 60 * k, 4.0)
	_light(lights, "Under", "AREA", c + Vector((0.6, 1.6, -2.0)), c, 22 * k, 3.0)

	cams = _col(sc, cname("RV2_Cameras"))
	for name, d in spec["cams"].items():
		_cam(cams, cname(name), d["loc"], d["at"], d.get("lens", 50), d.get("ortho"), d.get("fov_v"), d.get("clip", 0.05))

	# ADS range: floor, back wall, side walls and a target at the sight line far ahead.
	rng = _col(sc, cname("RV2_ADSRange"))
	floor_m = _mat("RV2_RangeFloor", (0.32, 0.33, 0.35), 0.8)
	wall_m = _mat("RV2_RangeWall", (0.55, 0.56, 0.6), 0.8)
	red = _mat("RV2_TargetRed", (0.55, 0.03, 0.03), 0.5)
	white = _mat("RV2_TargetWhite", (0.85, 0.85, 0.85), 0.5)
	ads = spec["ads"]
	far = ads["target_dist"]
	z_eye = ads["eye"][2]
	def plane(name, loc, size, rot, m):
		me = bpy.data.meshes.new(name)
		s = size / 2
		me.from_pydata([(-s, -s, 0), (s, -s, 0), (s, s, 0), (-s, s, 0)], [], [(0, 1, 2, 3)])
		me.materials.append(m)
		ob = bpy.data.objects.new(name, me)
		rng.objects.link(ob)
		ob.location = loc
		ob.rotation_euler = rot
		return ob
	plane("RangeFloor", (far / 2, 0, z_eye - 1.6), far * 1.6, (0, 0, 0), floor_m)
	plane("RangeBack", (far + 2, 0, z_eye), 30, (0, math.radians(90), 0), wall_m)
	plane("RangeLeft", (far / 2, 6, z_eye), far * 1.6, (math.radians(90), 0, 0), wall_m)
	plane("RangeRight", (far / 2, -6, z_eye), far * 1.6, (math.radians(90), 0, 0), wall_m)
	for i, (rad, m) in enumerate(((1.0, red), (0.8, white), (0.6, red), (0.4, white), (0.2, red))):
		me = bpy.data.meshes.new("Target%d" % i)
		n = 32
		verts = [(0, rad * math.cos(2 * math.pi * k / n), rad * math.sin(2 * math.pi * k / n)) for k in range(n)]
		me.from_pydata(verts, [], [list(range(n))[::-1]])
		me.materials.append(m)
		ob = bpy.data.objects.new("Target%d" % i, me)
		rng.objects.link(ob)
		ob.location = (far - 0.002 * i, 0, z_eye)
	for k, (dy, dz) in enumerate(((3.5, 0.6), (-3.0, -0.4))):
		for i, (rad, m) in enumerate(((0.5, red), (0.33, white), (0.16, red))):
			me = bpy.data.meshes.new("TargetB%d_%d" % (k, i))
			n = 24
			verts = [(0, rad * math.cos(2 * math.pi * j / n), rad * math.sin(2 * math.pi * j / n)) for j in range(n)]
			me.from_pydata(verts, [], [list(range(n))[::-1]])
			me.materials.append(m)
			ob = bpy.data.objects.new("TargetB%d_%d" % (k, i), me)
			rng.objects.link(ob)
			ob.location = (far * 0.7 - 0.002 * i, dy, z_eye + dz)
	_light(rng, "RangeSun", "SUN", (-6, 4, 12), (far, -2, 0), 2.2)
	rng.hide_render = True
	rng.hide_viewport = True
	return sc


def shoot(sc, cam, path, ads=False, res=(1920, 1080), hide=(), prefix=""):
	# hide: objects the GAME itself hides in this view (e.g. ADS stock fade), never presentation cheats.
	cname = lambda n: (prefix + "_" + n) if prefix else n
	sc.camera = bpy.data.objects[cname(cam)]
	for n in hide:
		bpy.data.objects[n].hide_render = True
	sc.render.resolution_x, sc.render.resolution_y = res
	rng = bpy.data.collections[cname("RV2_ADSRange")]
	rng.hide_render = not ads
	sc.render.filepath = path
	with bpy.context.temp_override(window=bpy.context.window, scene=sc):
		bpy.ops.render.render(write_still=True, scene=sc.name)
	rng.hide_render = True
	for n in hide:
		bpy.data.objects[n].hide_render = False
	return path
