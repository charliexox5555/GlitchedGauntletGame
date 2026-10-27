# rebuild_gun.py: runs tools/blender/build_<id>.py headless on the gun's .blend and saves it.
#
#   blender --background art-source/weapons/<Id>.blend --python tools/blender/rebuild_gun.py -- <Id>
#
# Then tools/ship_gun.py <Id> ship bakes, keys the clips, exports and uploads.

import bpy, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
gun = sys.argv[sys.argv.index("--") + 1]
path = os.path.join(HERE, "build_%s.py" % gun.lower())
g = {"__name__": "build", "__file__": path}
exec(compile(open(path).read(), path, "exec"), g)
print("REBUILD", gun, g["build"]())
bpy.ops.wm.save_mainfile()
