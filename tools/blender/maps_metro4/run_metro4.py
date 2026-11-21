"""Build the Metro4 + Props kit and render close-up review shots (live Blender MCP, port 9897).

python tools/blender/lobby_v4/send.py tools/blender/maps_metro4/run_metro4.py --port 9897 --pid <pid>
Writes vault/02 Art/References/maps/metro4/kit-*.png. Export: run_metro4_export.py.
"""
import importlib
import sys

import bpy
from mathutils import Vector

REPO = r"C:\Users\charl\Documents\GauntletGame\GlitchedGauntletGame"
sys.path[:0] = [REPO + r"\tools\blender\maps_metro4", REPO + r"\tools\blender\maps_arena"]
import arena_kit as A
import metro4_pieces as K

for m in (A, K):
	importlib.reload(m)

for c in bpy.data.collections:
	if c.name in ("PortKit", "WharfKit", "Port_Sheet", "Arena_Test", "Port_Test"):
		c.hide_render = True
		c.hide_viewport = True
tris = K.build_all()
root = bpy.data.collections[K.ROOT]
root.hide_render = False
root.hide_viewport = False

scene = bpy.context.scene
scene.render.engine = "BLENDER_WORKBENCH"
scene.display.shading.light = "STUDIO"
scene.display.shading.color_type = "MATERIAL"
scene.display.shading.show_cavity = True
scene.display.shading.show_object_outline = False
scene.render.resolution_x, scene.render.resolution_y = 1200, 800
cam = bpy.data.objects.get("KitCam")
if cam is None:
	cam = bpy.data.objects.new("KitCam", bpy.data.cameras.new("KitCam"))
	scene.collection.objects.link(cam)
scene.camera = cam

# lay the pieces out in a row for the shots (object offsets only; the export bakes from the masters at 0)
layout = {}


def place(names, spacing, y=0.0):
	x = -spacing * (len(names) - 1) / 2
	for n in names:
		for o in bpy.data.collections["Map_" + n].objects:
			o.location = (x, y, 0)
		layout[n] = (x, y)
		x += spacing


def shoot(only, pos, target, path, lens=50):
	for c in root.children:
		c.hide_render = c.name[4:] not in only
	cam.location = Vector(pos)
	d = Vector(target) - cam.location
	cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
	cam.data.lens = lens
	cam.data.clip_end = 2000
	scene.render.filepath = path
	bpy.ops.render.render(write_still=True)


OUT = REPO + "\\vault\\02 Art\\References\\maps\\metro4"


def frame(name, path, d=(0.75, 1.0, 0.5), back=False):
	objs = list(bpy.data.collections["Map_" + name].objects)
	pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
	lo = Vector([min(p[i] for p in pts) for i in range(3)])
	hi = Vector([max(p[i] for p in pts) for i in range(3)])
	c = (lo + hi) / 2
	r = (hi - lo).length / 2
	dv = Vector(d)
	if back:
		dv = Vector((-dv.x, -dv.y, dv.z))
	shoot({name}, tuple(c + dv.normalized() * r * 3.2), tuple(c), path, lens=50)


for n in ("CrateA_5", "CrateB_35", "Vending", "TicketGate", "GatePaddles", "LuggageCart", "Pallet", "Barrier", "Bogie"):
	frame(n, OUT + r"\kit-" + n.lower() + ".png")
frame("Vending", OUT + r"\kit-vending-back.png", back=True)
frame("CabFront", OUT + r"\kit-cabfront.png", d=(1.0, 0.8, 0.35))
frame("CabFront", OUT + r"\kit-cabfront-side.png", d=(0.35, 1.0, 0.2))
# back to the origin for the export
for c in root.children:
	c.hide_render = False
	for o in c.objects:
		o.location = (0, 0, 0)
result = {"tris": tris}
