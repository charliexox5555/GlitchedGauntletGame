"""Stage the Slipframe Arc's local Roblox flat FBX and verify its reimport."""

import json
import sys
from pathlib import Path

import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from arc_plate_joint import PLATE_BONE, fit_plate_joint, plate_manifest_joint


source = Path(bpy.data.filepath)
assert source.name == "Knife_Slipframe_Arc_r01.blend", source
output = source.parents[2] / "r01x"
output.mkdir(parents=True, exist_ok=True)
assert not (output / "Knife_Slipframe_RobloxFlat.fbx").exists(), output
tools = Path(__file__).resolve().parents[1]
rig = fit_plate_joint()
authored = [obj for name in ("Arc · Hilt", "Arc · Blade")
            for obj in bpy.data.collections[name].objects if obj.type == "MESH"]
depsgraph = bpy.context.evaluated_depsgraph_get()
staged = []
for obj in authored:
    evaluated = obj.evaluated_get(depsgraph)
    world = evaluated.matrix_world.copy()
    data = bpy.data.meshes.new_from_object(evaluated, depsgraph=depsgraph)
    temporary = bpy.data.objects.new(f"Flat_{obj.name}", data)
    bpy.context.scene.collection.objects.link(temporary)
    temporary.parent = rig
    temporary.parent_type = "BONE"
    temporary.parent_bone = obj.parent_bone
    bpy.context.view_layer.update()
    temporary.matrix_world = world
    if obj.name == "Arc_IceLane_R":
        temporary["flat_group"] = "ArcInlay"
    if obj.name.startswith("Arc_RevealContact_"):
        temporary["flat_group"] = "ArcContacts"
    staged.append(temporary)
bpy.context.view_layer.update()

exporter = {}
exec(compile((tools / "export_roblox_flat.py").read_text(encoding="utf-8"),
             str(tools / "export_roblox_flat.py"), "exec"), exporter)
# The pocket floors and their inlays have real, audited sub-millistud offsets.
# Treat only numerically coincident faces as a correction candidate on this asset.
exporter["COPLANAR_TOL_D"] = .000065
fbx, parts = exporter["export_flat"](staged, str(output), "Knife", "Slipframe")
triangle_count = sum(part["triangles"] for part in parts.values())
assert 0 < triangle_count < 10_000, triangle_count
assert not exporter["CROSSED_LEFT"], exporter["CROSSED_LEFT"]
assert not exporter["COPLANAR_LIFTED"], exporter["COPLANAR_LIFTED"]
assert {"SK_Root_ArcContacts", "SK_ArcPlate_ArcInlay"} <= parts.keys()
assert {part["bone"] for part in parts.values()} == {"Root", PLATE_BONE}
manifest = {
    "variant": "Slipframe Arc r01x",
    "gun": "Knife",
    "source_blend": source.name,
    "fbx": Path(fbx).name,
    "replaced_stock_prefixes": ["Blade", "Hilt", "Neon"],
    "untouched_stock": [],
    "joints": [plate_manifest_joint(rig)],
    "visual_tip": [round(v, 6) for v in bpy.data.objects["Arc_FX_VisualTip"].matrix_world.translation],
    "flipped_islands": exporter["FLIPPED"],
    "coplanar_lifted": exporter["COPLANAR_LIFTED"],
    "crossed_faces_fixed": exporter["CROSSED_FIXED"],
    "crossed_faces_left": exporter["CROSSED_LEFT"],
    "parts": parts,
}
manifest_path = output / "manifest_flat.json"
manifest_path.write_text(json.dumps(manifest, indent=2)+"\n", encoding="utf-8")

scratch = str(Path(sys.argv[sys.argv.index("--")+1]))
check = {"FBXS": [("Slipframe_Arc_r01x", fbx, str(manifest_path))],
         "OUT": scratch, "VIEWS": ("Left", "Right", "Rear")}
checker_path = tools / "check_flat_export.py"
exec(compile(checker_path.read_text(encoding="utf-8"), str(checker_path), "exec"), check)
imported = {obj.name: obj for obj in bpy.context.scene.objects if obj.type == "MESH"}
assert imported.keys() == parts.keys(), (imported.keys(), parts.keys())
delta = 0
for name, obj in imported.items():
    obj.data.calc_loop_triangles()
    assert len(obj.data.loop_triangles) == parts[name]["triangles"], name
    positions = [obj.matrix_world @ vertex.co for vertex in obj.data.vertices]
    low = Vector([min(p[axis] for p in positions) for axis in range(3)])
    high = Vector([max(p[axis] for p in positions) for axis in range(3)])
    for actual, target in ((high-low, parts[name]["size"]), ((high+low)/2, parts[name]["center"])):
        delta = max(delta, *(abs(a-b) for a, b in zip(actual, target, strict=True)))
assert delta < .00011, delta
report = check["result"]["Slipframe_Arc_r01x"]
assert not report["inside_out"], report
report.update(triangles=triangle_count, max_manifest_bounds_error=delta, bones=["Root", PLATE_BONE])
(output / "reimport_audit.json").write_text(json.dumps(report, indent=2)+"\n", encoding="utf-8")
print(json.dumps(report))
