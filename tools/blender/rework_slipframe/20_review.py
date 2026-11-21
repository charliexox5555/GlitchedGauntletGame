"""Capture matched stock and Slipframe Guardian views in the live session."""

import math
from pathlib import Path

import bpy
from mathutils import Vector


MASTER = Path(bpy.data.filepath)
assert "Guardian_Slipframe_r" in MASTER.name, MASTER
VERSION = MASTER.stem.split("_")[-1]
ROOT = MASTER.parents[6]
STOCK = ROOT / "art-source/weapons/RemasterV2/Guardian/Guardian_RemasterV2_v05.blend"
OUT = ROOT / f"vault/02 Art/Skins/Slipframe/out/Guardian_{VERSION}_views"
OUT.mkdir(parents=True, exist_ok=True)

CENTER = Vector((0.875, 0, 0.139))
AT = Vector((0.1376, 0, 0.4984))
EYE = AT - Vector((0.33 / 0.8, 0, 0))

VIEWS = {
    "hero": ((3.02, 4.85, 2.01), CENTER, 4.59, (1100, 475)),
    "rear": ((-1.53, -4.85, 1.83), CENTER, 4.59, (1100, 475)),
    "left": ((CENTER.x, 5, CENTER.z), CENTER, 4.59, (1100, 400)),
    "right": ((CENTER.x, -5, CENTER.z), CENTER, 4.59, (1100, 400)),
    "top": ((CENTER.x, 0, 5), CENTER, 4.59, (1100, 230)),
    "underside": ((CENTER.x, 0, -5), CENTER, 4.59, (1100, 260)),
    "stock_join": ((-0.91, 1.45, 0.81), (-0.52, 0, 0.20), 1.44, (770, 490)),
    "action_join": ((1.31, 1.13, 0.77), (0.81, 0, 0.292), 1.25, (770, 490)),
    "inspect_detail": ((0.11, 1.08, 0.70), (0.52, 0, 0.405), 0.86, (770, 490)),
    "ejection_join": ((0.61, -1.1, 0.57), (0.46, 0, 0.28), 1.08, (770, 490)),
    "grip_mag_join": ((0.70, -1.12, -0.19), (0.29, 0, 0.055), 1.10, (770, 490)),
    "fore_end_join": ((1.94, 1.03, 0.72), (1.68, 0, 0.312), 1.27, (770, 490)),
    "brake_join": ((3.45, 0.74, 0.77), (2.69, 0, 0.366), 0.79, (770, 490)),
    "front_sight_join": ((2.65, 0.63, 0.73), (2.25, 0, 0.443), 0.44, (850, 490)),
    "rear_sight_join": ((-0.19, 0.51, 0.68), (0.138, 0, 0.469), 0.43, (850, 490)),
    "ads": (EYE, AT, None, (900, 506)),
}


def shoot_set(label, names, culling=False):
    scene = bpy.context.scene
    bpy.data.objects["Guardian_Rig"].data.pose_position = "REST"
    for collection in bpy.data.collections:
        if "ADSRange" in collection.name:
            collection.hide_render = True
            collection.hide_viewport = True
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.render.film_transparent = False
    scene.render.image_settings.file_format = "PNG"
    scene.render.resolution_percentage = 100
    scene.display.render_aa = "16"
    shading = scene.display.shading
    shading.light = "STUDIO"
    shading.studiolight_rotate_z = math.radians(18)
    shading.color_type = "MATERIAL"
    shading.show_shadows = True
    shading.show_cavity = True
    shading.cavity_type = "BOTH"
    shading.curvature_ridge_factor = 0.77
    shading.curvature_valley_factor = 1.02
    shading.show_backface_culling = culling
    shading.background_type = "WORLD"
    scene.world.color = (0.80, 0.008, 0.35) if culling else (0.028, 0.037, 0.052)
    data = bpy.data.cameras.new("Slipframe review")
    data.clip_start = 0.01
    camera = bpy.data.objects.new("Slipframe review", data)
    scene.collection.objects.link(camera)
    scene.camera = camera
    for name in names:
        if name == "first_person":
            scene.camera = bpy.data.objects["Guardian_Cam_Hip"]
            scene.camera.data.clip_start = 0.01
            resolution = (900, 506)
        else:
            location, target, width, resolution = VIEWS[name]
            camera.location = location
            direction = Vector(target) - Vector(location)
            camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
            if name == "top":
                camera.rotation_euler = (0, 0, 0)
            elif name == "underside":
                camera.rotation_euler = (math.pi, 0, 0)
            data.type = "ORTHO" if width else "PERSP"
            if width:
                data.sensor_fit = "HORIZONTAL"
                data.ortho_scale = width
            else:
                data.sensor_fit = "VERTICAL"
                data.angle_y = math.radians(58)
            scene.camera = camera
        scene.render.resolution_x, scene.render.resolution_y = resolution
        scene.render.filepath = str(OUT / f"{label}_{name}.png")
        bpy.ops.render.render(write_still=True)

    if culling or not globals().get("POSES", True):
        return
    rig = bpy.data.objects["Guardian_Rig"]
    rig.data.pose_position = "POSE"
    rig.animation_data_create()
    camera.location, target, data.ortho_scale, _ = VIEWS["left"]
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    data.type = "ORTHO"
    data.sensor_fit = "HORIZONTAL"
    scene.camera = camera
    scene.render.resolution_x, scene.render.resolution_y = (1100, 480)
    for clip, fraction in (("Draw", 0.45), ("Fire", 0.30), ("Inspect", 0.52), ("Reload", 0.47), ("ReloadEmpty", 0.50)):
        action = bpy.data.actions[f"Guardian_{clip}"]
        rig.animation_data.action = action
        if action.slots:
            rig.animation_data.action_slot = action.slots[0]
        start, end = action.frame_range
        scene.frame_set(round(start + (end - start) * fraction))
        scene.render.filepath = str(OUT / f"{label}_pose_{clip}.png")
        bpy.ops.render.render(write_still=True)


def finish_hero():
    scene = bpy.context.scene
    rig = bpy.data.objects["Guardian_Rig"]
    rig.data.pose_position = "REST"
    for light in [o for o in scene.objects if o.type == "LIGHT"]:
        light.hide_render = True
    scene.render.engine = "BLENDER_EEVEE"
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Medium High Contrast"
    scene.view_settings.exposure = -0.5
    world = bpy.data.worlds.new("Slipframe finish review")
    world.use_nodes = True
    world.node_tree.nodes.get("Background").inputs[0].default_value = (0.067, 0.089, 0.13, 1)
    scene.world = world

    def softbox(label, position, target, power, size, tint):
        lamp = bpy.data.lights.new(label, "AREA")
        lamp.energy = power
        lamp.shape = "DISK"
        lamp.size = size
        lamp.color = tint
        obj = bpy.data.objects.new(label, lamp)
        scene.collection.objects.link(obj)
        obj.location = position
        obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()

    softbox("SF Review Key", (0.2, 3.6, 4.6), CENTER, 730, 4.0, (0.90, 0.95, 1.0))
    softbox("SF Review Fill", (0.75, 3.1, -1.25), CENTER, 190, 4.0, (1.0, 0.962, 0.885))
    softbox("SF Review Rim", (1.70, -2.40, 2.7), CENTER, 620, 3.0, (0.79, 0.87, 1.0))
    camera = bpy.data.objects.get("Slipframe review")
    camera.location = (2.59, 5.9, 1.51)
    camera.rotation_euler = (CENTER - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.sensor_fit = "HORIZONTAL"
    camera.data.ortho_scale = 4.78
    scene.camera = camera
    scene.render.resolution_x, scene.render.resolution_y = (1700, 620)
    scene.render.filepath = str(OUT / "slipframe_finish.png")
    bpy.ops.render.render(write_still=True)


names = globals().get("VIEWS_TO_RENDER", [*VIEWS, "first_person"])
shoot_set("slipframe", names)
if globals().get("WITH_CULL", True):
    shoot_set("culled", [name for name in names if name not in {"ads", "first_person"}], True)
if globals().get("FINISH", True):
    finish_hero()
bpy.ops.wm.open_mainfile(filepath=str(STOCK))
shoot_set("stock", names)
bpy.ops.wm.open_mainfile(filepath=str(MASTER))
result = {"directory": str(OUT), "views": names}
