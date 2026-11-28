"""Export all 32 charms from art-source/charms/<Id>/<Id>.blend to FBX + JSON manifests."""

import json
import os
import sys

import bpy, bmesh

if "__file__" in globals():
    ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
else:
    ROOT = r"c:\Users\charl\Documents\GauntletGame\GlitchedGauntletGame"

CHARMS_DIR = os.path.join(ROOT, "art-source", "charms")
OUT_DIR = os.path.join(CHARMS_DIR, "Exports")


def used_material(obj):
    if not obj.material_slots:
        return None
    idx = obj.data.polygons[0].material_index if len(obj.data.polygons) else 0
    return obj.material_slots[min(idx, len(obj.material_slots) - 1)].material


def strip_prefix(obj_name, charm_id):
    pre = charm_id + "_"
    return obj_name[len(pre) :] if obj_name.startswith(pre) else obj_name


def material_suffix(name):
    name = name.split(".")[0]
    return name[len("Body_") :] if name.startswith("Body_") else name


def split_by_material(obj):
    me = obj.data
    n_slots = len(obj.material_slots)
    if n_slots == 0:
        return [obj]
    used = sorted({min(p.material_index, n_slots - 1) for p in me.polygons})
    if len(used) <= 1:
        if len(me.polygons):
            for p in me.polygons:
                p.material_index = used[0]
        return [obj]
    pieces = []
    for idx in used:
        mat = obj.material_slots[idx].material
        new = obj.copy()
        new.data = me.copy()
        for col in obj.users_collection:
            col.objects.link(new)
        bm = bmesh.new()
        bm.from_mesh(new.data)
        bmesh.ops.delete(
            bm,
            geom=[f for f in bm.faces if min(f.material_index, n_slots - 1) != idx],
            context="FACES",
        )
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
        for f in bm.faces:
            f.material_index = 0
        bm.to_mesh(new.data)
        bm.free()
        new.data.materials.clear()
        new.data.materials.append(mat)
        new.name = obj.name + "_" + material_suffix(mat.name)
        pieces.append(new)
    bpy.data.objects.remove(obj)
    return pieces

ALL_CHARMS = [
    # Season 1 Battle Pass (8)
    "ArcadeToken",
    "IceCube",
    "Joystick",
    "PixelHeart",
    "SnowflakeShard",
    "GameCartridge",
    "ThunderOrb",
    "HighScore",
    # Strike Pack (12)
    "DraftTicket",
    "BrassBullet",
    "DogTags",
    "FragPin",
    "MiniHelmet",
    "TargetPlate",
    "FragGrenade",
    "MicroBlade",
    "MoltenCore",
    "GlitchDie",
    "CrownTrophy",
    "AceSkull",
    # Overdrive Pack (12)
    "HazardSign",
    "BatteryCell",
    "CompassRose",
    "Keycard",
    "DashWing",
    "FrostCrystal",
    "ClockworkGear",
    "MiniTsuba",
    "PlasmaPrism",
    "PhantomLantern",
    "ReactorCore",
    "KillRadar",
]


def part_look(obj):
    mat = used_material(obj)
    if mat is None or "rbx_material" not in mat:
        return None
    out = {
        "material": str(mat["rbx_material"]),
        "color": [int(c) for c in mat["rbx_color"]],
    }
    if "rbx_transparency" in mat:
        out["transparency"] = float(mat["rbx_transparency"])
    return out


def part_role(short_name: str) -> str:
    low = short_name.lower()
    if low == "chain" or low.startswith("chain_"):
        return "chain"
    if low == "neon" or low.startswith("neon_"):
        return "neon"
    if low == "screen" or low.startswith("screen_"):
        return "screen"
    if low == "stick" or low.startswith("stick_"):
        return "stick"
    if low == "wheel" or low.startswith("wheel_"):
        return "wheel"
    if low == "ring" or low.startswith("ring_"):
        return "ring"
    if low == "clasp" or low.startswith("clasp_"):
        return "clasp"
    return "body"


def export_one(charm_id: str, out_dir: str):
    blend_path = os.path.join(CHARMS_DIR, charm_id, f"{charm_id}.blend")
    if not os.path.exists(blend_path):
        raise FileNotFoundError(f"Missing {blend_path}")

    bpy.ops.wm.open_mainfile(filepath=blend_path)
    col = bpy.data.collections.get(charm_id)
    if col is None:
        raise RuntimeError(f"Collection {charm_id} missing in {blend_path}")

    # Strip prefix first so split_by_material produces Body_<Mat> rather than <Id>_Body_<Mat>
    for obj in list(col.objects):
        if obj.type == "MESH":
            obj.name = strip_prefix(obj.name, charm_id)
            split_by_material(obj)

    objs = [o for o in col.objects if o.type == "MESH"]
    bpy.context.view_layer.update()

    parts = []
    min_pt = [1e9, 1e9, 1e9]
    max_pt = [-1e9, -1e9, -1e9]
    body_min = [1e9, 1e9, 1e9]
    body_max = [-1e9, -1e9, -1e9]

    for obj in objs:
        obj.data.calc_loop_triangles()
        pts = [obj.matrix_world @ v.co for v in obj.data.vertices]
        if not pts:
            continue
        lo = [min(p[i] for p in pts) for i in range(3)]
        hi = [max(p[i] for p in pts) for i in range(3)]
        for i in range(3):
            min_pt[i] = min(min_pt[i], lo[i])
            max_pt[i] = max(max_pt[i], hi[i])
        role = part_role(obj.name)
        if role != "chain":
            for i in range(3):
                body_min[i] = min(body_min[i], lo[i])
                body_max[i] = max(body_max[i], hi[i])

        mat = used_material(obj)
        parts.append(
            {
                "name": obj.name,
                "role": role,
                "material": mat.name.split(".")[0] if mat else None,
                "look": part_look(obj),
                "origin": [round(float(obj.location[i]), 5) for i in range(3)],
                "center": [round((lo[i] + hi[i]) / 2, 5) for i in range(3)],
                "size": [round(hi[i] - lo[i], 5) for i in range(3)],
                "tris": len(obj.data.loop_triangles),
            }
        )

    if body_min[0] > 1e8:
        body_min, body_max = min_pt, max_pt

    manifest = {
        "id": charm_id,
        "axes": "Blender (+X right, +Y back, +Z up); Roblox (x,y,z) = (-bx, bz, by)",
        "bounds": {
            "min": [round(x, 5) for x in min_pt],
            "max": [round(x, 5) for x in max_pt],
            "bodyCenter": [round((body_min[i] + body_max[i]) / 2, 5) for i in range(3)],
        },
        "tris": sum(p["tris"] for p in parts),
        "parts": parts,
    }

    bpy.ops.object.select_all(action="DESELECT")
    for obj in objs:
        obj.hide_set(False)
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]

    fbx_path = os.path.join(out_dir, f"{charm_id}.fbx")
    bpy.ops.export_scene.fbx(
        filepath=fbx_path,
        use_selection=True,
        object_types={"MESH"},
        apply_scale_options="FBX_SCALE_UNITS",
        use_mesh_modifiers=True,
        bake_anim=False,
    )
    with open(os.path.join(out_dir, f"{charm_id}.json"), "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=1)

    return {"id": charm_id, "parts": len(parts), "tris": manifest["tris"], "fbx": fbx_path}


def main():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    targets = argv or ALL_CHARMS
    os.makedirs(OUT_DIR, exist_ok=True)
    summary = [export_one(cid, OUT_DIR) for cid in targets]
    print(json.dumps({"ok": True, "count": len(summary), "charms": summary}, indent=1))


if __name__ == "__main__" or "__file__" not in globals():
    main()
