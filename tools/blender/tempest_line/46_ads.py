# ADS check at the game's aim camera: eye = AimPoint - (ADS_DIST, 0, 0), looking +X, vertical FOV = ADS_FOV
# (src/shared/Config/Weapons.luau). Renders the view and casts the five findOccluders rays (centre +-0.012)
# along the aim line: every visible part they hit must have "Sight" in its name.
exec(open(r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/tools/blender/tempest_line/ts_lib.py").read())
TAG = globals().get("TAG", "s01")
ADS_DIST = globals().get("ADS_DIST", 0.30); ADS_FOV = globals().get("ADS_FOV", 72)
sc = bpy.context.scene
cam_d = bpy.data.cameras.get("CAM_ADS") or bpy.data.cameras.new("CAM_ADS")
cam = bpy.data.objects.get("CAM_ADS") or bpy.data.objects.new("CAM_ADS", cam_d)
if cam.name not in sc.collection.all_objects:
	sc.collection.objects.link(cam)
cam_d.type = "PERSP"; cam_d.sensor_fit = "VERTICAL"; cam_d.angle_y = math.radians(ADS_FOV); cam_d.clip_start = 0.01
aimp = bpy.data.objects[G("AimPoint")].matrix_world.translation.copy()
eye = aimp - Vector((ADS_DIST, 0, 0))
cam.location = eye
cam.rotation_euler = Vector((1, 0, 0)).to_track_quat("-Z", "Y").to_euler()
prev = sc.camera; sc.camera = cam
sc.render.resolution_x, sc.render.resolution_y = 1600, 900
sc.render.filepath = SCRATCH + "%s_%s_ads.png" % (GUN, TAG)
if not globals().get("NORENDER"):
	bpy.ops.render.render(write_still=True)
sc.camera = prev
dg = bpy.context.evaluated_depsgraph_get()
hits = {}
for off in ((0, 0, 0), (0, 0.012, 0), (0, -0.012, 0), (0, 0, 0.012), (0, 0, -0.012)):
	o_ = eye + Vector(off)
	for _ in range(16):
		ok, loc, nrm, idx, obj, mtx = sc.ray_cast(dg, o_, Vector((1, 0, 0)), distance=6.0)
		if not ok:
			break
		if not obj.hide_render and obj.type == "MESH" and not obj.get("ts_replaced"):
			hits.setdefault(obj.name, round(loc.x - aimp.x, 3))
		o_ = loc + Vector((0.0005, 0, 0))
bad = sorted(n for n in hits if "Sight" not in n)
result = {"ads": SCRATCH + "%s_%s_ads.png" % (GUN, TAG), "aim": [round(v, 4) for v in aimp], "hits": hits, "non_sight": bad}
