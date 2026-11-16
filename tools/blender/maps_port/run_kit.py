"""Build the port kit and render a contact sheet (live maps Blender, port 9930).

python tools/blender/lobby_v4/send.py tools/blender/maps_port/run_kit.py --port 9930 --pid <pid>
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
import port_pieces as K

for m in (A, P, K):
	importlib.reload(m)

for name in ("Arena_Test", "Port_Test"):
	c = bpy.data.collections.get(name)
	if c:
		c.hide_render = True
		c.hide_viewport = True

tris = K.build_all()

# contact sheet: lay the pieces out in a row on a floor (the masters stay at the origin for export, so
# render through linked duplicates in a sheet collection)
sheet = bpy.data.collections.get("Port_Sheet")
if sheet:
	for o in list(sheet.objects):
		bpy.data.objects.remove(o, do_unlink=True)
else:
	sheet = bpy.data.collections.new("Port_Sheet")
	bpy.context.scene.collection.children.link(sheet)
spots = {
	"ContainerGrey30": (0, 0, 0, 0), "ContainerRed30": (0, 12, 0, 0), "ContainerGrey25": (35, 0, 0, 0),
	"ContainerGrey20": (35, 12, 0, 0), "ContainerRed20": (35, 12, 10, 0), "ContainerGrey15": (62, 0, 0, 0),
	"Bollard": (62, 14, 0, 0), "RoofStair": (-40, -25, 0, 0), "WarehouseRoof": (-40, 20, -12, 0),
	"GantryPier": (0, -30, 0, 0),
}
for name, (x, y, z, rot) in spots.items():
	src = bpy.data.objects[name]
	d = bpy.data.objects.new(name + "_Sheet", src.data)
	d.location = (x, y, z)
	d.rotation_euler = (0, 0, radians(rot))
	sheet.objects.link(d)
for src_coll in [c for c in bpy.data.collections if c.name.startswith("Map_")]:
	src_coll.hide_render = True
A.r15_proxy("R15_Sheet", x=50, y=-8, collection=sheet)
fm = A.Mesh("SheetFloor", sheet)
fm.prism(A.cham(-70, 80, -45, 45, 0.5), -0.5, 0.0, A.mat("A_Floor"))
fm.finish()

sc = bpy.context.scene
cam = bpy.data.objects.get("ArenaCam")
cam.location = (95.0, -95.0, 70.0)
d = Vector((5, -5, 6)) - cam.location
cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
cam.data.lens = 28
sc.camera = cam
sc.render.resolution_x, sc.render.resolution_y = 1600, 950
out = REPO + r"\vault\02 Art\References\maps\port\kit-sheet-v1.png"
sc.render.filepath = out
bpy.ops.render.render(write_still=True)
result = {"tris": tris, "total": sum(tris.values()), "render": out}
