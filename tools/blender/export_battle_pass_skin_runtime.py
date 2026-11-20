"""Export Poolside and Rootglass for the existing Studio skin installer."""

from collections import defaultdict
import json
from pathlib import Path
import sys

import bpy

sys.path.insert(0, str(Path(__file__).resolve().parent))
from export_moderate_runtime import classify, fix_outward, part, save_fbx

ROOT = Path.cwd()
OUT = ROOT / "art-source/weapons/Skins/Review/Battle Pass"
INDEX = OUT / "manifest.json"


def export(line, item, asset, out):
    gun = "Knife" if item == "Leafblade" else item
    manifest = json.loads((ROOT / asset["manifest"]).read_text(encoding="utf-8"))
    bpy.ops.wm.open_mainfile(filepath=str(ROOT / asset["blend"]), load_ui=False)
    bpy.context.scene.frame_set(1)
    bpy.context.view_layer.update()
    stock = bpy.data.collections[gun]
    additions = bpy.data.collections.get("Rootglass Cosmetic")
    stock_meshes = [ob for ob in stock.all_objects if ob.type == "MESH"]
    meshes = stock_meshes + list(additions.objects if additions else ())
    keep, replaced, specs, made = set(), set(), {}, []
    for ob in meshes:
        role = ob.name.removeprefix(gun + "_")
        if ob in stock_meshes and role.startswith("Scope"):
            keep.add(role)
            continue
        if ob in stock_meshes:
            replaced.add(role)
        if ob.hide_render:
            continue
        fix_outward(ob)
        mesh = ob.data
        mesh.calc_loop_triangles()
        active = next((layer for layer in mesh.uv_layers if layer.active_render), mesh.uv_layers.active)
        uv = active.uv if active else None
        surfaces = defaultdict(list)
        for tri in mesh.loop_triangles:
            if tri.area > 1e-10:
                mat = mesh.materials[mesh.polygons[tri.polygon_index].material_index]
                surfaces[classify(ob, mat)].append(tri)
        for index, ((kind, color, material, opacity), triangles) in enumerate(surfaces.items(), start=1):
            name = f"{role}_{index:02}"
            assert name not in specs, name
            vertices, faces, uvs, vertex_indices = [], [], [], {}
            for tri in triangles:
                indices = []
                for i in tri.vertices:
                    if i not in vertex_indices:
                        vertex_indices[i] = len(vertices)
                        vertices.append(ob.matrix_world @ mesh.vertices[i].co)
                    indices.append(vertex_indices[i])
                faces.append(tuple(indices))
                if kind == "pbr":
                    assert uv, (ob.name, name)
                    uvs.append([tuple(uv[i].vector) for i in tri.loops])
            extra = {"color": color, "material": material, "opacity": round(opacity, 5)}
            made.append(part(name, vertices, faces, uvs, specs, ob.parent_bone or "Root", kind, extra))

    assert len(made) and any(spec["kind"] == "pbr" for spec in specs.values())
    stem = f"{gun}_{line}_Runtime_{asset['version']}"
    file = out / (stem + ".fbx")
    save_fbx(made, file)
    job = {"line": line, "gun": gun, "item": item, "version": asset["version"],
           "parts": specs, "replaced": sorted(replaced), "kept": sorted(keep),
           "maps": {key: value["file"] for key, value in manifest["maps"].items()},
           "source": asset["blend"], "file": file.relative_to(ROOT).as_posix()}
    (out / (stem + ".json")).write_text(json.dumps(job, indent=2) + "\n", encoding="utf-8")
    print("READY", line, item, len(made), flush=True)


if __name__ == "__main__":
    output = OUT / "Studio"
    output.mkdir(exist_ok=True)
    assets = json.loads(INDEX.read_text(encoding="utf-8"))["cosmetics"]
    choices = sys.argv[sys.argv.index("--") + 1:]
    for skin in choices or [f"{line}/{item}" for line, items in assets.items() for item in items]:
        line, item = skin.split("/")
        export(line, item, assets[line][item], output)
