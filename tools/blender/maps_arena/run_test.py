"""Kit test piece for the Arena: one full-cover panel slab beside an R15 proxy, rendered for review.

python tools/blender/lobby_v4/send.py tools/blender/maps_arena/run_test.py --port 9930 --pid <pid>
"""
import importlib
import sys
from math import radians

import bpy

REPO = r"C:\Users\charl\Documents\GauntletGame\GlitchedGauntletGame"
sys.path[:0] = [REPO + r"\tools\blender\maps_arena"]
import arena_kit as K

importlib.reload(K)

cube = bpy.data.objects.get("Cube")
if cube and cube.data and cube.data.name.startswith("Cube") and len(cube.data.vertices) == 8:
	bpy.data.objects.remove(cube, do_unlink=True)

K.clear_coll(K.ROOT)
col = K.coll(K.ROOT)
test = K.coll("Arena_Test", col)
slab = K.panel_slab("Map_PanelSlab", collection=test)
proxy = K.r15_proxy(x=10.5, y=-4.0, collection=test)

# floor plate for the render
fm = K.Mesh("TestFloor", test)
fm.prism(K.cham(-30, 30, -20, 20, 0.5), -0.5, 0.0, K.mat("A_Floor"))
fm.finish()

sc = bpy.context.scene
sc.render.engine = "BLENDER_EEVEE" if "BLENDER_EEVEE" in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items] else "BLENDER_EEVEE_NEXT"
sc.render.resolution_x, sc.render.resolution_y = 1400, 860
sc.view_settings.view_transform = "Standard"
w = sc.world or bpy.data.worlds.new("World")
sc.world = w
w.use_nodes = True
bg = w.node_tree.nodes.get("Background")
bg.inputs["Color"].default_value = (0.55, 0.62, 0.75, 1)
bg.inputs["Strength"].default_value = 0.9

sun = bpy.data.objects.get("ArenaSun")
if sun is None:
	sd = bpy.data.lights.new("ArenaSun", "SUN")
	sun = bpy.data.objects.new("ArenaSun", sd)
	col.objects.link(sun)
sun.data.energy = 3.2
sun.data.angle = radians(4)
sun.rotation_euler = (radians(52), radians(8), radians(38))

cam = bpy.data.objects.get("ArenaCam")
if cam is None:
	cam = bpy.data.objects.new("ArenaCam", bpy.data.cameras.new("ArenaCam"))
	col.objects.link(cam)
cam.data.lens = 32
cam.location = (17.0, -21.0, 7.5)
from mathutils import Vector

d = Vector((0, 0, 4.2)) - cam.location
cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
sc.camera = cam

out = REPO + r"\vault\02 Art\References\maps\arena\kit-test-panel-slab.png"
sc.render.filepath = out
bpy.ops.render.render(write_still=True)

me = slab.data
result = {"slab_tris": sum(len(p.vertices) - 2 for p in me.polygons), "dims": [round(v, 2) for v in slab.dimensions], "render": out}
