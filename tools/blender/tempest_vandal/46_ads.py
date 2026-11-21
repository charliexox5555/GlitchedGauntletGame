# ADS check at the stock aim camera: eye adsDistance (0.36) behind AimPoint (0.078, 0, 0.56), looking +X,
# vertical FOV = adsFov (68, Config/Weapons.luau). Also reports what the eye-to-target line hits.
exec(open(r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/tools/blender/tempest_vandal/tv_lib.py").read())
TAG = globals().get("TAG", "s03")
sc = bpy.context.scene
cam_d = bpy.data.cameras.get("CAM_ADS") or bpy.data.cameras.new("CAM_ADS")
cam = bpy.data.objects.get("CAM_ADS") or bpy.data.objects.new("CAM_ADS", cam_d)
if cam.name not in sc.collection.all_objects:
	sc.collection.objects.link(cam)
cam_d.type = "PERSP"; cam_d.sensor_fit = "VERTICAL"; cam_d.angle_y = math.radians(68); cam_d.clip_start = 0.01
eye = Vector((0.078 - 0.36, 0.0, 0.56))
cam.location = eye
cam.rotation_euler = Vector((1, 0, 0)).to_track_quat("-Z", "Y").to_euler()
prev = sc.camera; sc.camera = cam
sc.render.resolution_x, sc.render.resolution_y = 1600, 900
sc.render.filepath = SCRATCH + "tv_%s_ads.png" % TAG
bpy.ops.render.render(write_still=True)
sc.camera = prev
# ray along the aim line: everything it hits must be a *Sight* part
dg = bpy.context.evaluated_depsgraph_get()
hits = []
o_ = eye.copy()
for _ in range(12):
	ok, loc, nrm, idx, obj, mtx = sc.ray_cast(dg, o_, Vector((1, 0, 0)), distance=4.0)
	if not ok:
		break
	if not obj.hide_render:
		hits.append(obj.name)
	o_ = loc + Vector((0.0005, 0, 0))
result = {"ads": SCRATCH + "tv_%s_ads.png" % TAG, "aimline_hits": hits}
