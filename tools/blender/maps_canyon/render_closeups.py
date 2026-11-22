"""Close-up renders of the CanyonOutpost kit joins (live Blender MCP, port 9897), after run_canyon.py.

python tools/blender/lobby_v4/send.py tools/blender/maps_canyon/render_closeups.py --port 9897 --pid <pid>
Writes vault/02 Art/References/maps/canyon/close-*.png: every place two parts meet must read as one connected piece.
"""
import bpy
from mathutils import Vector

REPO = r"C:\Users\charl\Documents\GauntletGame\GlitchedGauntletGame"
OUT = REPO + "/vault/02 Art/References/maps/canyon"
scene = bpy.context.scene
cam = bpy.data.objects["KitCam"]
root = bpy.data.collections["CanyonKit"]
# (piece, camera position, look-at) in Blender studs (+Y = Roblox -Z)
SHOTS = [
	("CNOreCart", (4.6, -5.2, 3.6), (0.0, 0.0, 1.8), "close-cart"),
	("CNWagon", (8.5, -9.0, 4.5), (2.6, -2.5, 3.6), "close-wagon-side"),
	("CNWagon", (6.5, 2.0, 2.6), (3.45, 3.6, 1.9), "close-wagon-wheel"),
	("CNWaterTower", (12.0, -14.0, 14.0), (6.0, -6.0, 12.0), "close-tower-braces"),
	("CNWaterTower", (11.0, -11.0, 25.0), (4.0, -3.0, 23.5), "close-tower-deck"),
	("CNMinePortal", (6.0, 9.0, 9.0), (3.0, 1.0, 11.0), "close-portal-header"),
]
for piece, pos, at, name in SHOTS:
	for c in root.children:
		c.hide_render = c.name[4:] != piece
	cam.location = Vector(pos)
	cam.rotation_euler = (Vector(at) - cam.location).to_track_quat("-Z", "Y").to_euler()
	cam.data.lens = 35
	scene.render.filepath = OUT + "/" + name + ".png"
	bpy.ops.render.render(write_still=True)
for c in root.children:
	c.hide_render = False
result = {"shots": [s[3] for s in SHOTS]}
