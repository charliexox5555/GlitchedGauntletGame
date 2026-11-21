"""s08x: the Tempest-Strike Vandal's moving parts (2026-11-22, owner: "moving
parts"). Opens the s07x export copy, adds a TS_Rig armature whose bones sit at
the pivots with the stock Root bone's orientation (so each Studio joint's C0 is a
pure offset), re-parents the pieces, saves s08x. The flat exporter turns the
extra bones into Studio joints (InstallFlatSkin addJoints); Util/TempestIdle
drives their Motor6D.Transform.

  TS_VentL / TS_VentR: the silver handguard blade + the two top fins on each
      side, hinged at their rear end; they flare open like vents.
  TS_Crescent: the crescent rear sight (ring, face, tip pips), turning about
      the bore through the sight's centre.
"""
import bpy, os
from mathutils import Matrix, Vector

ROOT = r"C:\Users\charl\Documents\GauntletGame\GlitchedGauntletGame"
D = os.path.join(ROOT, "art-source", "weapons", "Skins", "TempestStrike", "Vandal")
bpy.ops.wm.open_mainfile(filepath=os.path.join(D, "s07x", "Vandal_TempestStrike_s07x.blend"))

stock = bpy.data.objects["Vandal_Rig"]
root_local = stock.data.bones["Root"].matrix_local.copy()
GROUPS = {
    "TS_VentL": (Vector((1.075, 0.085, 0.29)), ["TSE_GuardBlade+1", "TSE_Fin1+1", "TSE_Fin2+1"]),
    "TS_VentR": (Vector((1.075, -0.085, 0.29)), ["TSE_GuardBlade-1", "TSE_Fin1-1", "TSE_Fin2-1"]),
    "TS_Crescent": (Vector((0.078, 0.0, 0.555)), ["TSC_Sight_Crescent", "TSC_Sight_CrescentFace", "TSC_Sight_Pip+1", "TSC_Sight_Pip-1"]),
}

arm = bpy.data.armatures.new("TS_Rig")
rig = bpy.data.objects.new("TS_Rig", arm)
bpy.data.objects["TSE_Handguard"].users_collection[0].objects.link(rig)
rig.matrix_world = stock.matrix_world.copy()
bpy.context.view_layer.objects.active = rig
for o in bpy.context.view_layer.objects:
    o.select_set(False)
rig.select_set(True)
win = bpy.context.window_manager.windows[0]
area = next(a for a in win.screen.areas if a.type == "VIEW_3D")
ctx = {"window": win, "area": area, "region": next(r for r in area.regions if r.type == "WINDOW"), "active_object": rig, "object": rig}
with bpy.context.temp_override(**ctx):
    bpy.ops.object.mode_set(mode="EDIT")
inv = stock.matrix_world.inverted()
for name, (pivot, _) in GROUPS.items():
    eb = arm.edit_bones.new(name)
    eb.head = (0, 0, 0)
    eb.tail = (0, 0.05, 0)
    eb.matrix = Matrix.Translation(inv @ pivot) @ root_local.to_3x3().to_4x4()
with bpy.context.temp_override(**ctx):
    bpy.ops.object.mode_set(mode="OBJECT")
bpy.context.view_layer.update()

moved = {}
for name, (_, objs) in GROUPS.items():
    for on in objs:
        o = bpy.data.objects[on]
        mw = o.matrix_world.copy()
        o.parent = rig
        o.parent_type = "BONE"
        o.parent_bone = name
        o.matrix_world = mw
        moved[on] = name
bpy.context.view_layer.update()
os.makedirs(os.path.join(D, "s08x"), exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(D, "s08x", "Vandal_TempestStrike_s08x.blend"), copy=False)
b = arm.bones["TS_Crescent"]
result = {"moved": moved, "crescent_local": [round(x, 4) for x in (root_local.inverted() @ b.matrix_local).translation], "root_axes": [[round(v, 3) for v in r] for r in root_local.to_3x3()]}
