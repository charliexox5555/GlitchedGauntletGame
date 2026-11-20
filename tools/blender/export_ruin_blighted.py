"""Export the Shadow Mist variant for InstallFlatSkin.

    blender -b <versioned blend> --python tools/blender/export_ruin_blighted.py
"""

import json
from pathlib import Path
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from export_roblox_flat import CROSSED_LEFT, export_flat


LINE = "RuinBlighted"
FLOATING_PLATES = (
    "RB_Handguard_Forehead_", "RB_Handguard_BarrelCheek_", "RB_Handguard_DorsalKeel",
    "RB_Stock_MainCleavedPlate_", "RB_Stock_HeelPlate_",
)
GLOW = {
    "Wrap crest": "77D9C8",
    "Wrap jade": "398E7E",
    "Teal inlay": "5BC4B2",
}
PHASE = {"Fore": 0.0, "Receiver": 0.85, "Mag": 1.65, "Stock": 2.35, "Sight": 3.15}
SIGHT_FRAGMENT = "RB_RearSight_Fragment_"


def region(obj):
    if obj.name.startswith(SIGHT_FRAGMENT):
        return "Sight"
    if "Magazine" in obj.name or obj.parent_bone == "Mag":
        return "Mag"
    if "Handguard" in obj.name:
        return "Fore"
    if "Stock" in obj.name:
        return "Stock"
    return "Receiver"


def shard_motion(shard, position, root_from_world):
    area = region(shard)
    if area == "Sight":
        radial = Vector((0, position.y, position.z - .5598)).normalized()
        serial = int(shard.name.rsplit("_", 1)[1])
        return {
            "axis": list(root_from_world.to_3x3() @ radial),
            "phase": round(serial * .7854, 4),
            "travel": .010,
            "tilt": .023,
            "tether": False,
            "region": area,
        }
    chip = shard.name.startswith("RB_Shard_")
    side = 0 if abs(position.y) < .025 else (1 if position.y >= 0 else -1)
    vertical = max(-1, min(1, (position.z - .31) / .15))
    if not chip and side:
        vertical *= .45
    direction = Vector((.075 if area == "Fore" else -.075, side * .80, vertical))
    low_fore = area == "Fore" and position.z < .20
    if low_fore:
        # These splinters sit ahead of the supporting hand. Drift along the
        # gun and outboard so the loop stays above and ahead of the fingers.
        direction = Vector((.90, side * .45, .14))
    axis = root_from_world.to_3x3() @ direction
    span = (position.x - 1.2 if area == "Fore" else -.7 - position.x)
    travel = .126 if chip else .049
    if chip and (position.z < .21 or position.x < 0):
        travel = .092
    return {
        "axis": list(axis.normalized()),
        "phase": round(PHASE[area] + span * 1.8 + min(vertical, 0) * .60 + side * .17, 4),
        "travel": travel,
        "tilt": .08 if low_fore else (.13 if chip else .047),
        "tether": not chip and shard.name.startswith((
            "RB_Handguard_Forehead_", "RB_Stock_MainCleavedPlate_",
        )),
        "region": area,
    }


def export():
    source = Path(bpy.data.filepath)
    assert source.is_file() and source.name.startswith("Vandal_RuinBlighted_")
    version = source.parent.name
    bpy.context.scene.frame_set(1)
    rig = bpy.data.objects["Vandal_Rig"]
    rig.data.pose_position = "REST"
    bpy.context.view_layer.update()

    stock = [o for o in bpy.data.collections["Vandal"].objects if o.type == "MESH"]
    skin = bpy.data.collections["Ruin-Blighted | Shadow Mist"]
    fractured_spine = any(o.name == "RB_Receiver_SpineBed" for o in skin.all_objects)
    meshes = [o for o in [*stock, *skin.all_objects] if o.type == "MESH" and not o.hide_render]
    root_matrix = rig.data.bones["Root"].matrix_local.copy()
    root_from_world = (rig.matrix_world @ root_matrix).inverted()
    movers = sorted(
        (o for o in meshes if o.name.startswith(("RB_Shard_", *FLOATING_PLATES))
         or (o.name.startswith(SIGHT_FRAGMENT) and fractured_spine)),
        key=lambda o: (region(o), o.name),
    )
    shard_poses = [o.matrix_world.copy() for o in movers]
    # The export groups by bone. Give the rigid shards real temporary bones so
    # they export as independent assemblies, with the same axes as Root.
    rig.hide_set(False)
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    edit = rig.data.edit_bones
    joint_names = [
        f"{'RuinSight' if region(obj) == 'Sight' else 'RuinShard'}_{index:02}"
        for index, obj in enumerate(movers, 1)
    ]
    for joint, pose in zip(joint_names, shard_poses):
        bone = edit.new(joint)
        bone.parent = edit["Root"]
        matrix = root_matrix.copy()
        matrix.translation = rig.matrix_world.inverted() @ pose.translation
        bone.matrix = matrix
        bone.length = 0.08
    bpy.ops.object.mode_set(mode="OBJECT")

    joints = []
    for joint, shard, pose in zip(joint_names, movers, shard_poses):
        shard.parent_bone = joint
        bpy.context.view_layer.update()
        shard.matrix_world = pose
        pivot = root_from_world @ pose.translation
        joints.append({
            "name": joint,
            "parent": "Root",
            "c0": [*pivot, 1, 0, 0, 0, 1, 0, 0, 0, 1],
            "source": shard.name,
            **shard_motion(shard, pose.translation, root_from_world),
        })

    # the source stores the skin recolors as per-object material overrides
    shade = bpy.data.materials["Shadow Mist - Obsidian"]
    edge = bpy.data.materials["Shadow Mist - Slate"]
    glowing_materials = {}
    movers_set = set(movers)
    for ob in meshes:
        materials = [slot.material for slot in ob.material_slots]
        for i, material in enumerate(materials):
            if not material:
                continue
            role = material.name.removeprefix("Shadow Mist - ")
            if ob in movers_set and region(ob) != "Sight":
                # Two finishes per rigid slab preserve the facets and limit
                # MeshPart count when every loose fragment has a motor.
                material = edge if role in {"Slate", "Broken edge"} else shade
            elif role in GLOW and ("Sight" not in ob.name or region(ob) == "Sight"):
                key = (region(ob), role)
                if key not in glowing_materials:
                    clone = material.copy()
                    clone.name = f"Ruin glow {key[0]} {key[1]}"
                    glowing_materials[key] = clone
                material = glowing_materials[key]
            elif ob in movers_set and region(ob) == "Sight":
                material = shade
            ob.data.materials[i] = material

    bpy.context.view_layer.update()
    fbx, parts = export_flat(meshes, str(source.parent), "Vandal", LINE)
    assert not CROSSED_LEFT, CROSSED_LEFT
    assert set(j["name"] for j in joints) <= {p["bone"] for p in parts.values()}
    installed = {}
    for name, p in parts.items():
        material = p["blender_material"].removeprefix("Shadow Mist - ")
        glow = material.startswith("Ruin glow ")
        finish = p["material"]
        color = p["color"]
        phase = None
        glow_mix = None
        if glow:
            _, _, area, role = material.split(" ", 3)
            finish, color = "Neon", GLOW[role]
            phase = PHASE[area] + (0.32 if role == "Wrap jade" else 0)
            glow_mix = {"Wrap jade": .43, "Teal inlay": .82, "Wrap crest": 1.0}[role]
        elif material.startswith(("Grip fabric", "Grip folded", "Grip seam")):
            finish = "Fabric"
        elif material.startswith("Magazine "):
            finish = "Slate"
        installed[name] = {
            "b": p["bone"], "c": p["center"], "s": p["size"], "col": color,
            "mat": finish, "refl": p["reflectance"], "glow": phase, "glowMix": glow_mix, "tris": p["triangles"],
        }

    energy = [
        {"name": "RuinMistFore", "bone": "Root", "point": [1.49, .139, .385], "region": "Fore", "mist": True},
        {"name": "RuinReceiverGlow", "bone": "Root", "point": [.67, .114, .413],
         "region": "Receiver", "mist": fractured_spine},
        {"name": "RuinMagGlow", "bone": "Mag", "point": [.718, .067, -.177] if fractured_spine else [.718, .065, -.154],
         "region": "Mag", "mist": fractured_spine},
        {"name": "RuinMistHeel", "bone": "Root", "point": [-1.03, .112, .307], "region": "Stock", "mist": True},
    ]
    if fractured_spine:
        for side, suffix in ((1, "L"), (-1, "R")):
            for name, point, area in (
                ("Cowl", (.235, .084, .432), "Receiver"),
                ("Collar", (-.365, .074, .343), "Stock"),
                ("Heel", (-1.07, .106, .132), "Stock"),
                ("LowerFore", (1.743, .077, .204), "Fore"),
            ):
                x, y, z = point
                energy.append({"name": "Ruin" + name + suffix, "bone": "Root",
                               "point": [x, y*side, z], "region": area, "mist": True})
        energy.append({"name": "RuinApertureGlow", "bone": "Root", "point": [.074, 0, .471],
                       "region": "Sight", "mist": False})
    manifest = {
        "line": LINE, "gun": "Vandal", "version": version, "file": Path(fbx).name,
        "parts": installed, "replaced": {o.name.removeprefix("Vandal_"): True for o in stock},
        "joints": joints,
        "energy": energy,
    }
    for anchor in manifest["energy"]:
        anchor["phase"] = PHASE[anchor["region"]]
    (source.parent / "manifest_flat.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8",
    )
    print(f"Exported {len(parts)} parts in {fbx}")


if __name__ == "__main__":
    export()
