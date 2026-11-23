"""Apply an approved Slipframe master to a separate export copy and check its flat FBX."""

import json
from pathlib import Path

import bpy


master = Path(bpy.data.filepath)
gun = master.stem.split("_")[0]
assert "_Slipframe_r" in master.name and not master.stem.endswith("x"), master
root = master.parents[6]
version = master.stem.split("_")[-1]
export_version = version + ("fx" if gun == "Guardian" else "x")
directory = master.parent.with_name(export_version)
copy = directory / f"{gun}_Slipframe_{export_version}.blend"
assert not copy.exists(), copy

directory.mkdir(parents=True, exist_ok=True)
bpy.data.objects[f"{gun}_Rig"].data.pose_position = "REST"
bpy.context.view_layer.update()
for group in (gun, "COL_Slipframe"):
    for obj in bpy.data.collections[group].objects:
        if obj.type != "MESH" or obj.hide_render:
            continue
        if "Sight" in obj.name and "flat_group" in obj:
            del obj["flat_group"]
        if not obj.modifiers:
            continue
        depsgraph = bpy.context.evaluated_depsgraph_get()
        mesh = bpy.data.meshes.new_from_object(obj.evaluated_get(depsgraph), depsgraph=depsgraph)
        obj.modifiers.clear()
        obj.data = mesh
if gun == "Guardian":
    bpy.data.objects["SF_InspectSlidingPanel_Left"]["flat_group"] = "SFInspectPanel"
    bpy.data.objects["SF_SeamInlay_Left"]["flat_group"] = "SFSeam"
bpy.ops.wm.save_as_mainfile(filepath=str(copy))

tools = root / "tools/blender"
exporter = {"ITEMS": [("Slipframe", gun, export_version)]}
exec((tools / "export_skin_items_flat.py").read_text(encoding="utf-8"), exporter)
manifest = directory / "manifest_flat.json"
model = directory / f"{gun}_Slipframe_RobloxFlat.fbx"
assert manifest.is_file() and model.is_file(), exporter.get("result")

evidence = root / f"vault/02 Art/Skins/Slipframe/out/{gun}_{export_version}_flat_check"
check = {"FBXS": [(f"{gun}_{export_version}", str(model), str(manifest))], "OUT": str(evidence)}
exec((tools / "check_flat_export.py").read_text(encoding="utf-8"), check)
(evidence / "reimport.json").write_text(json.dumps(check["result"], indent=2), encoding="utf-8")
bpy.ops.wm.open_mainfile(filepath=str(master))
result = {"master": str(master), "copy": str(copy), "export": str(model),
          "check": check["result"], "evidence": str(evidence)}
