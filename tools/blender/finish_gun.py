# finish_gun.py: the headless half of a scripted gun build. After tools/blender/build_<id>.py has been run and the
# .blend saved, this bakes the texture set, keys the clips (tools/blender/anim_<id>.py, if present), resets the
# rig to rest, saves, and optionally renders the PBR check views.
#
#   blender --background art-source/weapons/<Id>.blend --python tools/blender/finish_gun.py -- <Id> [render_dir]
#
# Used by tools/ship_gun.py; it can also be run on its own.

import bpy, os, sys
from mathutils import Matrix

HERE = os.path.dirname(os.path.abspath(__file__))


def run(path, name, fn, *args):
	g = {"__name__": name, "__file__": path}
	exec(compile(open(path).read(), path, "exec"), g)
	return g[fn](*args), g


def main(gun, render_dir=None):
	report = {}
	report["bake"], bake = run(os.path.join(HERE, "bake_textures.py"), "bake", "bake", gun)
	anim = os.path.join(HERE, "anim_%s.py" % gun.lower())
	if os.path.exists(anim):
		report["clips"], _ = run(anim, "anim", "animate")
	rig = bpy.data.objects.get(gun + "_Rig")
	if rig:
		for pb in rig.pose.bones:
			pb.matrix_basis = Matrix.Identity(4)
	bpy.ops.wm.save_mainfile()
	if render_dir:
		os.makedirs(render_dir, exist_ok=True)
		bake["preview"](gun, True)
		sc = bpy.context.scene
		sc.render.engine = "BLENDER_EEVEE"
		for cam in ("Cam_34", "Cam_Side", "Cam_Close", "Cam_FP"):
			if bpy.data.objects.get(cam):
				sc.camera = bpy.data.objects[cam]
				sc.render.filepath = os.path.join(render_dir, "%s_%s.png" % (gun, cam))
				bpy.ops.render.render(write_still=True)
		# Not saved: the preview outputs stay off in the file.
	print("FINISH_GUN", report)


if __name__ == "__main__":
	args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
	main(args[0], args[1] if len(args) > 1 else None)
