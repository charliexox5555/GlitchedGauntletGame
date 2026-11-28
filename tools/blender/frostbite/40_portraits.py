"""Locker portraits and side icons for the Frostbite line, rendered in Blender."""
import math
from pathlib import Path

import bpy
from mathutils import Euler, Matrix, Vector

ROOT = Path(r"C:\Users\charl\Documents\GauntletGame\GlitchedGauntletGame")
FINAL = {
    "Vandal": "v10", "Phantom": "v04", "Spectre": "v02", "Guardian": "v02", "Bulldog": "v03",
    "Odin": "v02", "Operator": "v02", "Marshal": "v02", "Bucky": "v02", "Stinger": "v02",
    "Classic": "v02", "Sheriff": "v02", "Shorty": "v02", "Ghost": "v02", "Knife": "v02",
}
GUNS = globals().get("GUNS", FINAL)
OUT = ROOT / "art-source/ui/item-portraits"
SIDE = globals().get("SIDE", False)
TILT, YAW, PITCH = (0.0, math.radians(-12), math.radians(6)) if SIDE else (math.radians(35), math.radians(14), math.radians(10))


def visible_meshes():
    keep = []
    for o in bpy.context.scene.objects:
        if o.type != "MESH" or o.hide_render:
            continue
        cols = [c.name for c in o.users_collection]
        if any(("ADSRange" in c) or ("Cutters" in c) or ("RV2_" in c) or ("FP_" in c) for c in cols):
            continue
        keep.append(o)
    return keep


def render(gun, ver):
    path = ROOT / f"art-source/weapons/Skins/Frostbite/{gun}/{ver}/{gun}_Frostbite_{ver}.blend"
    bpy.ops.wm.open_mainfile(filepath=str(path))
    scene = bpy.context.scene
    rig = bpy.data.objects.get(f"{gun}_Rig")
    if rig:
        rig.data.pose_position = "REST"
    for c in bpy.data.collections:
        if "ADSRange" in c.name:
            c.hide_render = True
    for o in scene.objects:
        if o.type == "LIGHT":
            o.hide_render = True
    bpy.context.view_layer.update()
    meshes = visible_meshes()
    pts = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
    lo = Vector([min(p[i] for p in pts) for i in range(3)])
    hi = Vector([max(p[i] for p in pts) for i in range(3)])
    center = (lo + hi) / 2
    size = (hi - lo).length
    direction = Vector((0, 1, 0)) if SIDE else Vector((0, -1, 0))
    direction.rotate(Euler((0, 0, -YAW)))
    direction = (direction + Vector((0, 0, -math.tan(PITCH)))).normalized()
    cam_data = bpy.data.cameras.new("Portrait")
    cam_data.lens_unit = "FOV"
    cam_data.angle = math.radians(26)
    cam = bpy.data.objects.new("Portrait", cam_data)
    scene.collection.objects.link(cam)
    distance = size * 0.5 / math.tan(math.radians(13)) * (1.0 if SIDE else 1.05)
    cam.location = center - direction * distance
    rot = direction.to_track_quat("-Z", "Y").to_matrix().to_4x4()
    roll = Matrix.Rotation(TILT, 4, "Z")
    cam.matrix_world = Matrix.Translation(cam.location) @ rot @ roll
    scene.camera = cam
    world = bpy.data.worlds.new("PortraitWorld")
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs[0].default_value = (1, 1, 1, 1)
    bg.inputs[1].default_value = 0.9
    scene.world = world
    sun = bpy.data.objects.new("PortraitSun", bpy.data.lights.new("PortraitSun", "SUN"))
    sun.data.energy = 2.2
    sun.data.angle = math.radians(30)
    scene.collection.objects.link(sun)
    sun.rotation_euler = (-direction + Vector((0.2, 0, 0.6))).normalized().to_track_quat("Z", "Y").to_euler()
    scene.render.engine = "BLENDER_EEVEE"
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.view_settings.exposure = -0.15
    scene.render.film_transparent = True
    scene.render.resolution_x, scene.render.resolution_y = (2048, 900) if SIDE else (2048, 2048)
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    raw = OUT / (f"_side_{gun}.png" if SIDE else f"_raw_{gun}.png")
    scene.render.filepath = str(raw)
    bpy.ops.render.render(write_still=True)
    return str(raw)


done = {gun: render(gun, ver) for gun, ver in GUNS.items()}
result = {"raw": done}
