# Append the stock RemasterV2 Vandal as a hidden-render reference collection REF_Stock.
import bpy, os
src = r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/art-source/weapons/RemasterV2/Vandal/Vandal_RemasterV2_v05.blend"
for o in list(bpy.data.objects):
    if o.name in ("Cube",):
        bpy.data.objects.remove(o, do_unlink=True)
if "REF_Stock" not in bpy.data.collections:
    with bpy.data.libraries.load(src, link=False) as (df, dt):
        dt.collections = [c for c in df.collections if c == "Vandal"]
    ref = bpy.data.collections.new("REF_Stock")
    bpy.context.scene.collection.children.link(ref)
    for c in dt.collections:
        ref.children.link(c)
ref = bpy.data.collections["REF_Stock"]
info = []
from mathutils import Vector
for o in ref.all_objects:
    if o.type == "MESH":
        ws = [o.matrix_world @ Vector(c) for c in o.bound_box]
        mn = [round(min(v[i] for v in ws), 3) for i in range(3)]
        mx = [round(max(v[i] for v in ws), 3) for i in range(3)]
        info.append((o.name, mn, mx, len(o.data.polygons)))
    else:
        info.append((o.name, o.type, [round(x, 3) for x in o.matrix_world.translation]))
result = {"info": info}
