# quick_look.py: fast EEVEE look at a gun before the long bake (current materials, preview cameras).
#
#   blender --background art-source/weapons/<Id>.blend --python tools/blender/quick_look.py -- <Id> <out_dir> [Cam ...]

import bpy, os, sys

args = sys.argv[sys.argv.index("--") + 1:]
gun, out = args[0], args[1]
cams = args[2:] or ["Cam_34", "Cam_FP", "Cam_Side"]
os.makedirs(out, exist_ok=True)
sc = bpy.context.scene
sc.render.engine = "BLENDER_EEVEE"
sc.eevee.taa_render_samples = 8
sc.render.resolution_x, sc.render.resolution_y = 800, 500
for cam in cams:
	if cam == "ADS":  # looking down the sights from 0.3 studs behind AimPoint
		aim = bpy.data.objects[gun + "_AimPoint"].matrix_world.translation
		cd = bpy.data.cameras.new("ADS")
		cd.lens = 35
		ob = bpy.data.objects.new("ADS", cd)
		sc.collection.objects.link(ob)
		ob.location = (aim.x - 0.3, aim.y, aim.z)
		ob.rotation_euler = (1.5708, 0, -1.5708)
		cd.clip_start = 0.01
	sc.camera = bpy.data.objects[cam]
	sc.render.filepath = os.path.join(out, "%s_%s.png" % (gun, cam))
	bpy.ops.render.render(write_still=True)
print("QUICK_LOOK", out)
