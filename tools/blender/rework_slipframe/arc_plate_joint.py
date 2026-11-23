"""Prepare the cosmetic Slipframe Arc plate joint in a working scene."""

import bpy
from mathutils import Vector


PLATE_BONE = "ArcPlate"
PLATE_BASE = (.555, .0154, .046)


def fit_plate_joint():
    rig = bpy.data.objects["Knife_Rig"]
    rig.data.pose_position = "REST"
    if PLATE_BONE not in rig.data.bones:
        rig.hide_set(False)
        bpy.context.view_layer.objects.active = rig
        rig.select_set(True)
        bpy.ops.object.mode_set(mode="EDIT")
        joint = rig.data.edit_bones.new(PLATE_BONE)
        joint.parent = rig.data.edit_bones["Root"]
        joint.head = Vector(PLATE_BASE)
        joint.tail = joint.head + Vector((0, .055, 0))
        bpy.ops.object.mode_set(mode="OBJECT")
        rig.select_set(False)
    driven = [obj for obj in bpy.context.scene.objects if obj.get("Arc plate driven")]
    assert len(driven) == 5, [obj.name for obj in driven]
    for obj in driven:
        world = obj.matrix_world.copy()
        obj.parent_bone = PLATE_BONE
        bpy.context.view_layer.update()
        obj.matrix_world = world
    bpy.context.view_layer.update()
    return rig


def plate_manifest_joint(rig):
    root = rig.data.bones["Root"].matrix_local
    local = root.inverted() @ rig.data.bones[PLATE_BONE].matrix_local
    position = list(local.translation)
    rotation = [local[row][col] for row in range(3) for col in range(3)]
    return {"name": PLATE_BONE, "parent": "Root",
            "c0": [round(value, 6) for value in position + rotation]}
