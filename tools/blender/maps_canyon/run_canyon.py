"""Build the CanyonOutpost kit and render close-ups (live Blender MCP, port 9897).

python tools/blender/lobby_v4/send.py tools/blender/maps_canyon/run_canyon.py --port 9897 --pid <pid>
Works in its own file art-source/maps/CanyonOutpost/Kit_CanyonOutpost.blend (opened or created here).
Writes vault/02 Art/References/maps/canyon/kit-*.png. Export: run_canyon_export.py.
"""
import importlib
import os
import sys

import bpy
from mathutils import Vector

REPO = r"C:\Users\charl\Documents\GauntletGame\GlitchedGauntletGame"
BLEND = REPO + r"\art-source\maps\CanyonOutpost\Kit_CanyonOutpost.blend"
if os.path.normcase(bpy.data.filepath) != os.path.normcase(BLEND):
	assert not bpy.data.is_dirty, "the open file has unsaved changes"
	os.makedirs(os.path.dirname(BLEND), exist_ok=True)
	if os.path.exists(BLEND):
		bpy.ops.wm.open_mainfile(filepath=BLEND)
	else:
		bpy.ops.wm.read_homefile(use_empty=True)
		bpy.ops.wm.save_as_mainfile(filepath=BLEND)
sys.path[:0] = [
	REPO + r"\tools\blender\maps_canyon",
	REPO + r"\tools\blender\maps_foundry4",
	REPO + r"\tools\blender\maps_greenhouse4",
	REPO + r"\tools\blender\maps_snowpeak4",
	REPO + r"\tools\blender\maps_arena",
]
import arena_kit as A
import snowcat_model as SC
import greenhouse4_pieces as G
import foundry4_pieces as F
import canyon_pieces as K

for m in (A, SC, G, F, K):
	importlib.reload(m)

tris = K.build_all()
root = bpy.data.collections[K.ROOT]
root.hide_render = False
root.hide_viewport = False

scene = bpy.context.scene
scene.render.engine = "BLENDER_WORKBENCH"
scene.display.shading.light = "STUDIO"
scene.display.shading.color_type = "MATERIAL"
scene.display.shading.show_cavity = True
scene.render.resolution_x, scene.render.resolution_y = 1000, 700
cam = bpy.data.objects.get("KitCam")
if cam is None:
	cam = bpy.data.objects.new("KitCam", bpy.data.cameras.new("KitCam"))
	scene.collection.objects.link(cam)
scene.camera = cam
OUT = REPO + "/vault/02 Art/References/maps/canyon"


def frame(name, path, d=(0.75, -1.0, 0.55), k=2.6):
	for c in root.children:
		c.hide_render = c.name[4:] != name
	objs = list(bpy.data.collections["Map_" + name].objects)
	pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
	lo = Vector([min(p[i] for p in pts) for i in range(3)])
	hi = Vector([max(p[i] for p in pts) for i in range(3)])
	c = (lo + hi) / 2
	r = (hi - lo).length / 2
	cam.location = c + Vector(d).normalized() * r * k
	cam.rotation_euler = (c - cam.location).to_track_quat("-Z", "Y").to_euler()
	cam.data.lens = 50
	cam.data.clip_end = 5000
	scene.render.filepath = path
	bpy.ops.render.render(write_still=True)


SHOTS = [a for a in sys.argv[1:]] if len(sys.argv) > 1 else None
for n in (SHOTS or K.PIECES):
	frame(n, OUT + "/kit-" + n.lower() + ".png", d=(0.6, 1.0, 0.35) if n == "CNMinePortal" else (0.75, -1.0, 0.55), k=2.0 if n == "CNMinePortal" else 2.6)
for c in root.children:
	c.hide_render = False
bpy.ops.wm.save_mainfile()
result = {"tris": tris}
