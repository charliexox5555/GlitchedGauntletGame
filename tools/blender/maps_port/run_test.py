"""Port kit test piece: a red and a grey container (one stacked), crates as plain boxes, an R15 proxy.

python tools/blender/lobby_v4/send.py tools/blender/maps_port/run_test.py --port 9930 --pid <pid>
"""
import importlib
import sys
from math import radians

import bpy
from mathutils import Vector

REPO = r"C:\Users\charl\Documents\GauntletGame\GlitchedGauntletGame"
sys.path[:0] = [REPO + r"\tools\blender\maps_port", REPO + r"\tools\blender\maps_arena"]
import arena_kit as A
import port_kit as P

importlib.reload(A)
importlib.reload(P)

# hide the Arena test so the render shows only the port pieces
arena = bpy.data.collections.get("Arena_Test")
if arena:
	arena.hide_render = True
	arena.hide_viewport = True

A.clear_coll(P.ROOT)
root = A.coll(P.ROOT)
test = A.coll("Port_Test", root)
red = P.container("Map_ContainerRed", collection=test)
grey = P.container("Map_ContainerGrey", body="C_Grey", frame="C_GreyDark", collection=test)
grey.location = (-4.0, 12.0, 0.0)
grey.rotation_euler = (0, 0, radians(4))
top = P.container("Map_ContainerGreyTop", body="C_Grey", frame="C_GreyDark", collection=test)
top.location = (-4.0, 12.0, 10.0)
top.rotation_euler = (0, 0, radians(4))
A.r15_proxy(x=19.0, y=-6.0, collection=test)
fm = A.Mesh("PortFloor", test)
fm.prism(A.cham(-40, 40, -25, 30, 0.5), -0.5, 0.0, A.mat("A_Floor"))
fm.finish()

sc = bpy.context.scene
cam = bpy.data.objects.get("ArenaCam")
cam.location = (36.0, -30.0, 11.0)
d = Vector((4, 2, 5.5)) - cam.location
cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
cam.data.lens = 30
sc.camera = cam
sun = bpy.data.objects.get("ArenaSun")
sun.data.energy = 4.0
sun.rotation_euler = (radians(50), radians(10), radians(30))
out = REPO + r"\vault\02 Art\References\maps\port\kit-test-container.png"
sc.render.filepath = out
bpy.ops.render.render(write_still=True)
tris = sum(len(p.vertices) - 2 for p in red.data.polygons)
result = {"container_tris": tris, "dims": [round(v, 2) for v in red.dimensions], "render": out}
