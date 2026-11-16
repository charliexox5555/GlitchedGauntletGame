"""Build one theme kit in the live maps Blender (port 9930), render its contact sheet and export it.

    python tools/blender/maps_kit/run.py <theme> [--no-export]     (wraps this file with THEME / KIT / EXPORT)

THEME: module suffix (kit_<theme>.py); KIT: the MapKit folder / art-source/maps/<KIT>/Exports name.
Sheet: vault/02 Art/References/maps/kits/<theme>-kit.png (pieces in a row beside an R15 proxy).
"""
import importlib
import sys

import bpy
from mathutils import Vector

REPO = r"C:\Users\charl\Documents\GauntletGame\GlitchedGauntletGame"
for p in (r"\tools\blender", r"\tools\blender\maps_kit", r"\tools\blender\maps_arena"):
    if REPO + p not in sys.path:
        sys.path.insert(0, REPO + p)
import arena_kit as A
import export_lobby_kit as E
import kitlib as KL

theme = importlib.import_module("kit_" + THEME)  # noqa: F821 (set by the wrapper)
for m in (A, KL, theme, E):
    importlib.reload(m)

for c in bpy.data.collections:
    if c.name in ("Arena_Test", "Port_Test", "Port_Sheet", "ArenaKit", "PortKit") or c.name.endswith("_Sheet"):
        c.hide_render = True
        c.hide_viewport = True

tris = theme.build_all()

# contact sheet: linked duplicates in a row (masters stay at the origin for export)
sheet_name = THEME + "_Sheet"  # noqa: F821
sheet = bpy.data.collections.get(sheet_name)
if sheet:
    for o in list(sheet.objects):
        bpy.data.objects.remove(o, do_unlink=True)
else:
    sheet = bpy.data.collections.new(sheet_name)
    bpy.context.scene.collection.children.link(sheet)
sheet.hide_render = False
sheet.hide_viewport = False
x = 0.0
masters = [bpy.data.objects[n] for n in tris]
skip = getattr(theme, "SHEET_SKIP", ())
for o in masters:
    if o.name in skip:
        continue
    w = o.dimensions.x
    d = bpy.data.objects.new(o.name + "_Sheet", o.data)
    d.location = (x + w / 2 - (o.bound_box[0][0] + o.bound_box[6][0]) / 2, 0, 0)
    sheet.objects.link(d)
    x += w + 4
for c in [c for c in bpy.data.collections if c.name.startswith("Map_")]:
    c.hide_render = True
A.r15_proxy(THEME + "_R15", x=x + 2, y=-4, collection=sheet)  # noqa: F821
fm = A.Mesh(THEME + "_Floor", sheet)  # noqa: F821
fm.prism(A.cham(-8, x + 10, -20, 20, 0.5), -0.5, 0.0, A.mat("A_Floor"))
fm.finish()

sc = bpy.context.scene
cam = bpy.data.objects.get("ArenaCam")
mid = Vector((x / 2, 0, 6))
span = max(x, 40)
cam.location = mid + Vector((span * 0.25, -span * 0.75, span * 0.42))
cam.rotation_euler = (mid - cam.location).to_track_quat("-Z", "Y").to_euler()
cam.data.lens = 30
sc.camera = cam
sc.render.resolution_x, sc.render.resolution_y = 1800, 900
out = REPO + r"\vault\02 Art\References\maps\kits\%s-kit.png" % THEME  # noqa: F821
import os

os.makedirs(os.path.dirname(out), exist_ok=True)
sc.render.filepath = out
bpy.ops.render.render(write_still=True)

res = {"tris": tris, "total": sum(tris.values()), "sheet": out}
if EXPORT:  # noqa: F821
    for c in [c for c in bpy.data.collections if c.name.startswith("Map_")]:
        c.hide_render = False
    res["export"] = E.main(["--maps", KIT, "Kit"])  # noqa: F821
    tmp = bpy.data.collections.get("_Export")
    if tmp:
        for o in list(tmp.objects):
            bpy.data.objects.remove(o, do_unlink=True)
        bpy.data.collections.remove(tmp)
    theme.build_all()
result = res
