"""Distinguish inverted closed shells from open FBX material partitions."""

import json
from pathlib import Path

import bmesh
import bpy


master = Path(bpy.data.filepath)
version = master.stem.split("_")[-1]
directory = master.parent.with_name(version + "x")
root = master.parents[6]
fbx = directory / "Guardian_Slipframe_RobloxFlat.fbx"
target = root / f"vault/02 Art/Skins/Slipframe/out/Guardian_{version}_flat_check/reimport_topology.json"
bpy.ops.wm.read_homefile(use_empty=True, use_factory_startup=True)
window = bpy.context.window_manager.windows[0]
with bpy.context.temp_override(window=window):
    bpy.ops.import_scene.fbx(filepath=str(fbx), axis_forward="-Z", axis_up="Y")

report = {}
for obj in bpy.context.scene.objects:
    if obj.type != "MESH":
        continue
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.transform(obj.matrix_world)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=0.000001)
    unseen = set(bm.faces)
    shapes = {"open": 0, "closed": 0, "inverted_closed": 0}
    while unseen:
        faces = [unseen.pop()]
        for face in faces:
            for edge in face.edges:
                for adjacent in edge.link_faces:
                    if adjacent in unseen:
                        unseen.remove(adjacent)
                        faces.append(adjacent)
        if any(not edge.is_manifold for face in faces for edge in face.edges):
            shapes["open"] += 1
            continue
        volume = 0.0
        for face in faces:
            a, b, c = [v.co for v in face.verts]
            volume += a.dot(b.cross(c)) / 6
        shapes["closed"] += 1
        shapes["inverted_closed"] += int(volume < -1e-9)
    shapes["inconsistent_edges"] = sum(edge.is_manifold and not edge.is_contiguous for edge in bm.edges)
    report[obj.name] = shapes
    bm.free()

target.write_text(json.dumps(report, indent=2), encoding="utf-8")
bpy.ops.wm.open_mainfile(filepath=str(master))
result = {"evidence": str(target), "objects": len(report),
          "inverted_closed": [n for n, values in report.items() if values["inverted_closed"]],
          "inconsistent_edges": [n for n, values in report.items() if values["inconsistent_edges"]],
          "sight_partition": report["SK_Root_Sight_04"]}
