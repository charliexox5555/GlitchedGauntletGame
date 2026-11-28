"""Review captures for a Frostbite master in the live session (adapted from arcade/20_review.py).

Run with the master open: exec(open(".../tools/blender/frostbite/20_review.py").read(), {"STATIONS": {...}})
Writes vault/02 Art/Skins/Frostbite/out/<Gun>_<ver>_views/:
  wb_*      Workbench material views and join close-ups (two-sided)
  culled_*  the same on magenta with backface culling (holes and flipped faces show)
  finish_*  EEVEE look renders for the owner (hero, sides, top, first person, ADS)
  pose_*    stock clips at their key frames
  stock_*   the stock gun from the same cameras
"""

import math
from pathlib import Path

import bpy
from mathutils import Vector


MASTER = Path(bpy.data.filepath)
GUN = MASTER.stem.split("_")[0]
assert "_Frostbite_v" in MASTER.name, MASTER
VERSION = MASTER.stem.split("_")[-1]
ROOT = MASTER.parents[6]
STOCK = ROOT / f"art-source/weapons/RemasterV2/{GUN}/{GUN}_RemasterV2_v05.blend"
OUT = ROOT / f"vault/02 Art/Skins/Frostbite/out/{GUN}_{VERSION}_views"
OUT.mkdir(parents=True, exist_ok=True)
STATIONS = globals()["STATIONS"]
CENTER = Vector(globals()["CENTER"])
WIDTH = globals()["WIDTH"]
ADS_DISTANCE = globals()["ADS_DISTANCE"]

AT = bpy.data.objects[f"{GUN}_AimPoint"].matrix_world.translation.copy()
EYE = AT - Vector((ADS_DISTANCE / 0.8, 0, 0)) if ADS_DISTANCE is not None else AT - Vector((0.5, 0, 0))

VIEWS = {
    "hero": (CENTER + Vector((2.2, 5, 1.62)), CENTER, WIDTH, (1100, 470)),
    "rear": (CENTER + Vector((-2.1, -5, 1.65)), CENTER, WIDTH, (1100, 470)),
    "left": (CENTER + Vector((0, 5, 0)), CENTER, WIDTH, (1100, 420)),
    "right": (CENTER + Vector((0, -5, 0)), CENTER, WIDTH, (1100, 420)),
    "top": (CENTER + Vector((0, 0, 5)), CENTER, WIDTH, (1100, 240)),
    "underside": (CENTER + Vector((0, 0, -5)), CENTER, WIDTH, (1100, 260)),
}
for name, (offset, target, width) in STATIONS.items():
    VIEWS[name] = (Vector(target) + Vector(offset), Vector(target), width, (760, 460))

scene = bpy.context.scene
rig = bpy.data.objects[f"{GUN}_Rig"]


def camera_object():
    camera = bpy.data.objects.get("Frostbite review")
    if camera is None:
        data = bpy.data.cameras.new("Frostbite review")
        data.clip_start = 0.005
        camera = bpy.data.objects.new("Frostbite review", data)
        scene.collection.objects.link(camera)
    return camera


def aim(camera, name):
    if name == "first_person" and bpy.data.objects.get(f"{GUN}_Cam_Hip") is None:
        location, angle = globals()["HIP"]
        camera.location = location
        camera.rotation_euler = Vector((1, 0, 0)).to_track_quat("-Z", "Y").to_euler()
        camera.data.type = "PERSP"
        camera.data.sensor_fit = "VERTICAL"
        camera.data.angle_y = math.radians(angle)
        camera.data.shift_x = camera.data.shift_y = 0
        return (1280, 720)
    if name == "first_person":
        hip = bpy.data.objects[f"{GUN}_Cam_Hip"]
        camera.matrix_world = hip.matrix_world.copy()
        camera.data.type = "PERSP"
        camera.data.sensor_fit = hip.data.sensor_fit
        camera.data.angle = hip.data.angle
        camera.data.shift_x, camera.data.shift_y = hip.data.shift_x, hip.data.shift_y
        return (1280, 720)
    camera.data.shift_x = camera.data.shift_y = 0
    if name == "ads":
        camera.location = EYE
        camera.rotation_euler = (AT - EYE).to_track_quat("-Z", "Y").to_euler()
        camera.data.type = "PERSP"
        camera.data.sensor_fit = "VERTICAL"
        camera.data.angle_y = math.radians(68)
        return (1280, 720)
    location, target, width, resolution = VIEWS[name]
    camera.location = location
    camera.rotation_euler = (Vector(target) - Vector(location)).to_track_quat("-Z", "Y").to_euler()
    if name == "top":
        camera.rotation_euler = (0, 0, 0)
    elif name == "underside":
        camera.rotation_euler = (math.pi, 0, 0)
    if width:
        camera.data.type = "ORTHO"
        camera.data.sensor_fit = "HORIZONTAL"
        camera.data.ortho_scale = width
    else:
        camera.data.type = "PERSP"
        camera.data.sensor_fit = "HORIZONTAL"
        camera.data.angle = math.radians(32)
    return resolution


def hide_range():
    for collection in bpy.data.collections:
        if "ADSRange" in collection.name:
            collection.hide_render = True
            collection.hide_viewport = True


def workbench(culling):
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.view_settings.exposure = 0
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
    if scene.world is None:
        scene.world = bpy.data.worlds.new("Frostbite review world")
    scene.world.color = (0.80, 0.008, 0.35) if culling else (0.055, 0.065, 0.085)


def shoot(label, names, culling=False):
    rig.data.pose_position = "REST"
    hide_range()
    workbench(culling)
    camera = camera_object()
    scene.camera = camera
    for name in names:
        scene.render.resolution_x, scene.render.resolution_y = aim(camera, name)
        scene.render.filepath = str(OUT / f"{label}_{name}.png")
        bpy.ops.render.render(write_still=True)


def poses():
    rig.data.pose_position = "POSE"
    rig.animation_data_create()
    workbench(False)
    camera = camera_object()
    scene.camera = camera
    scene.render.resolution_x, scene.render.resolution_y = aim(camera, "left")
    for clip, fraction in (("Draw", 0.45), ("Fire", 0.30), ("Inspect", 0.52),
                           ("Reload", 0.47), ("ReloadEmpty", 0.50)):
        action = bpy.data.actions.get(f"{GUN}_{clip}")
        if action is None:
            continue
        rig.animation_data.action = action
        if action.slots:
            rig.animation_data.action_slot = action.slots[0]
        start, end = action.frame_range
        scene.frame_set(round(start + (end - start) * fraction))
        scene.render.filepath = str(OUT / f"pose_{clip}.png")
        bpy.ops.render.render(write_still=True)
    rig.data.pose_position = "REST"


def finish(label, names):
    rig.data.pose_position = "REST"
    hide_range()
    for light in [o for o in scene.objects if o.type == "LIGHT"]:
        light.hide_render = True
    scene.render.engine = "BLENDER_EEVEE"
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Punchy"
    scene.view_settings.exposure = -0.25
    world = bpy.data.worlds.get("Frostbite finish") or bpy.data.worlds.new("Frostbite finish")
    world.use_nodes = True
    world.node_tree.nodes.get("Background").inputs[0].default_value = (0.045, 0.055, 0.075, 1)
    world.node_tree.nodes.get("Background").inputs[1].default_value = 1.0
    scene.world = world

    def softbox(name, position, power, size, tint):
        obj = bpy.data.objects.get(name)
        if obj is None:
            lamp = bpy.data.lights.new(name, "AREA")
            obj = bpy.data.objects.new(name, lamp)
            scene.collection.objects.link(obj)
        obj.hide_render = False
        obj.data.energy, obj.data.shape, obj.data.size, obj.data.color = power, "DISK", size, tint
        obj.location = position
        obj.rotation_euler = (CENTER - obj.location).to_track_quat("-Z", "Y").to_euler()

    softbox("FB Review Key", CENTER + Vector((-0.6, 3.6, 4.4)), 820, 4.0, (0.90, 0.96, 1.0))
    softbox("FB Review Fill", CENTER + Vector((0.4, 3.1, -1.3)), 230, 4.0, (0.85, 0.92, 1.0))
    softbox("FB Review Rim", CENTER + Vector((1.2, -2.6, 2.6)), 680, 3.0, (0.76, 0.90, 1.0))
    softbox("FB Review RimL", CENTER + Vector((-2.4, 2.0, 1.2)), 300, 3.0, (0.88, 0.96, 1.0))
    camera = camera_object()
    scene.camera = camera
    for name in names:
        resolution = aim(camera, name)
        if name in ("hero", "rear", "left", "right", "top"):
            resolution = (resolution[0] * 3 // 2, resolution[1] * 3 // 2)
        scene.render.resolution_x, scene.render.resolution_y = resolution
        scene.render.filepath = str(OUT / f"{label}_{name}.png")
        bpy.ops.render.render(write_still=True)
    for light in [o for o in scene.objects if o.type == "LIGHT" and o.name.startswith("FB Review")]:
        light.hide_render = True


names = [*VIEWS, "first_person", "ads"]
shoot("wb", names)
shoot("culled", [n for n in names if n not in ("ads", "first_person")], True)
poses()
looks = ["hero", "rear", "left", "right", "top", "first_person", "ads", *globals().get("FINISH_EXTRA", [])]
finish("finish", looks)
bpy.ops.wm.open_mainfile(filepath=str(STOCK))
rig = bpy.data.objects[f"{GUN}_Rig"]
scene = bpy.context.scene
finish("stock", ["hero", "left", "first_person", "ads"])
bpy.ops.wm.open_mainfile(filepath=str(MASTER))
result = {"directory": str(OUT), "views": names}
