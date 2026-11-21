"""Close-up renders of assembled Foundry4 pieces for review (live Blender MCP, port 9897), after run_foundry4.py.

python tools/blender/lobby_v4/send.py tools/blender/maps_foundry4/render_closeups.py --port 9897 --pid <pid>
Writes vault/02 Art/References/maps/foundry4/close-*.png (the ladle on its car, the loco front and back).
"""
import bpy
from mathutils import Vector

REPO = r"C:\Users\charl\Documents\GauntletGame\GlitchedGauntletGame"
OUT = REPO + "/vault/02 Art/References/maps/foundry4"
scene = bpy.context.scene
root = bpy.data.collections["Foundry4Kit"]
tmp = bpy.data.collections.get("_Closeup") or bpy.data.collections.new("_Closeup")
if tmp.name not in scene.collection.children:
	scene.collection.children.link(tmp)
for o in list(tmp.objects):
	bpy.data.objects.remove(o, do_unlink=True)


def place(piece, loc):
	for o in bpy.data.collections["Map_" + piece].objects:
		d = bpy.data.objects.new(o.name + "_c", o.data)
		d.location = Vector(loc)
		tmp.objects.link(d)


place("F4LadleCar", (0, 0, 0))
place("F4Ladle", (0, 0, 2.95))
place("F4Loco", (30, 0, 0))
root.hide_render = True
cam = bpy.data.objects["KitCam"]
scene.camera = cam
cam.data.lens = 40


def shot(name, eye, at):
	cam.location = Vector(eye)
	cam.rotation_euler = (Vector(at) - cam.location).to_track_quat("-Z", "Y").to_euler()
	scene.render.filepath = OUT + "/close-" + name + ".png"
	bpy.ops.render.render(write_still=True)


shot("ladlecar", (13, -14, 7), (0, 0, 5))
shot("ladlecar-side", (16, 2, 4), (0, 0, 4.5))
shot("loco-front", (39, -17, 6), (30, -2, 4))
shot("loco-back", (21, 15, 7), (30, 2, 5))
root.hide_render = False
for o in list(tmp.objects):
	bpy.data.objects.remove(o, do_unlink=True)
bpy.data.collections.remove(tmp)
result = {"ok": True}
