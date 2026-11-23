"""Render and export review copies of the Slipframe Arc from the HD master."""

import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Quaternion, Vector


output = Path(sys.argv[sys.argv.index("--") + 1])
draft = "--draft" in sys.argv
stills = "--stills" in sys.argv
output.mkdir(parents=True, exist_ok=True)
scene = bpy.context.scene


def check_stock_actions():
    rig = bpy.data.objects["Knife_Rig"]
    reference = bpy.data.objects["Knife_Blade"]
    driven = [obj for name in ("Arc · Hilt", "Arc · Blade")
              for obj in bpy.data.collections[name].objects]
    bpy.context.view_layer.update()
    rest = [reference.matrix_world.inverted() @ obj.matrix_world for obj in driven]
    animation = rig.animation_data_create()
    active, slot = animation.action, animation.action_slot
    old_frame, old_subframe = scene.frame_current, scene.frame_subframe
    report = {}
    rig.data.pose_position = "POSE"
    for action in sorted(bpy.data.actions, key=lambda item: item.name):
        animation.action = action
        animation.action_slot = action.slots[0]
        start, end = action.frame_range
        frames = [start + (end - start) * i / 4 for i in range(5)]
        worst_error = 0
        for frame in frames:
            scene.frame_set(math.floor(frame), subframe=frame % 1)
            inverse = reference.matrix_world.inverted()
            for obj, original in zip(driven, rest, strict=True):
                relative = inverse @ obj.matrix_world
                error = max(abs(a-b) for line_a, line_b in zip(relative, original)
                            for a, b in zip(line_a, line_b))
                worst_error = max(worst_error, error)
        assert worst_error < 1e-5, (action.name, worst_error)
        report[action.name] = {"sampled_frames": frames, "max_relative_error": worst_error}
    animation.action = active
    if active is not None:
        animation.action_slot = slot
    rig.data.pose_position = "REST"
    scene.frame_set(old_frame, subframe=old_subframe)
    (output / "pose_audit.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")


if not draft and not stills:
    check_stock_actions()

scene.render.engine = "CYCLES"
scene.cycles.samples = 16 if draft else 40
scene.cycles.use_denoising = True
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.render.film_transparent = True
scene.view_settings.view_transform = "AgX"
scene.view_settings.look = "AgX - Medium High Contrast"
scene.view_settings.exposure = -.62

world = bpy.data.worlds.new("Arc review · neutral ambient")
background = world.node_tree.nodes.get("Background")
background.inputs["Color"].default_value = (.22, .26, .33, 1)
background.inputs["Strength"].default_value = .21
scene.world = world

stage = bpy.data.collections.new("Arc review · stage")
scene.collection.children.link(stage)


def aim(obj, point):
    return (Vector(point) - obj.location).to_track_quat("-Z", "Y")


def softbox(name, position, target, power, color, width, height):
    light = bpy.data.lights.new(name, "AREA")
    light.shape = "RECTANGLE"
    light.size = width
    light.size_y = height
    light.energy = power
    light.color = color
    obj = bpy.data.objects.new(name, light)
    stage.objects.link(obj)
    obj.location = position
    obj.rotation_euler = aim(obj, target).to_euler()


softbox("Broad neutral key", (.15, 1.14, .95), (.38, 0, 0), 53, (.94, .97, 1), 2.65, .67)
softbox("Ice rim", (.73, -.87, .56), (.48, 0, .03), 42, (.53, .73, 1), 2.00, .26)
softbox("Neutral edge", (.43, -.21, -.67), (.40, 0, -.06), 26, (.92, .96, 1), 1.83, .28)
softbox("Side fill", (-.48, 1.24, -.29), (.30, 0, 0), 12, (.72, .84, 1), .68, .92)
softbox("Rear face key", (-.12, -1.15, .42), (.35, 0, 0), 36, (.93, .97, 1), 2.17, .59)
softbox("Shoulder kicker", (1.37, .35, .22), (.64, 0, .04), 12, (.80, .88, 1), .50, .72)

camdata = bpy.data.cameras.new("Arc review camera")
camera = bpy.data.objects.new(camdata.name, camdata)
stage.objects.link(camera)
scene.camera = camera
camdata.type = "ORTHO"
camdata.clip_start = .01


def render(name, target, direction, roll, scale, resolution):
    camera.location = Vector(target) + Vector(direction).normalized() * 3.1
    camera.rotation_euler = (aim(camera, target) @
                             Quaternion((0, 0, 1), math.radians(roll))).to_euler()
    camdata.ortho_scale = scale
    scene.render.resolution_x, scene.render.resolution_y = resolution
    scene.render.filepath = str(output / f"{name}.png")
    bpy.ops.render.render(write_still=True)


if draft:
    render("arc_draft", (.410, 0, -.017), (.16, 1, .28), 15, 2.0, (1120, 610))
    render("arc_join_draft", (.392, 0, .007), (-.32, 1, .35), 13, .58, (1050, 660))
elif stills:
    render("Arc_Hero", (.410, 0, -.017), (.16, 1, .28), 15, 2.0, (1730, 920))
    render("Arc_Guard", (.373, 0, .005), (-.32, 1, .35), 13, .64, (1230, 750))
else:
    render("Arc_Hero", (.410, 0, -.017), (.16, 1, .28), 15, 2.0, (1910, 1050))
    render("Arc_Profile", (.405, 0, -.019), (0, 1, 0), 0, 1.95, (1740, 600))
    render("Arc_Guard", (.335, 0, .007), (-.37, 1, .33), 13, .73, (1410, 865))
    render("Arc_Reverse", (.400, 0, -.024), (-.12, -1, .35), -11, 2.0, (1530, 740))
    scene.camera = bpy.data.objects["Knife_FP_Hero"]
    scene.render.resolution_x, scene.render.resolution_y = (1280, 720)
    for stock in (False, True):
        for name in ("Arc · Hilt", "Arc · Blade"):
            bpy.data.collections[name].hide_render = stock
        for name in ("Knife_Blade", "Knife_Hilt", "Knife_Neon"):
            bpy.data.objects[name].hide_render = not stock
        scene.render.filepath = str(output / ("Stock_FP.png" if stock else "Arc_FP.png"))
        bpy.ops.render.render(write_still=True)
    for name in ("Arc · Hilt", "Arc · Blade"):
        bpy.data.collections[name].hide_render = False
    for name in ("Knife_Blade", "Knife_Hilt", "Knife_Neon"):
        bpy.data.objects[name].hide_render = True


if "--glb" in sys.argv:
    for obj in bpy.context.view_layer.objects:
        if obj.select_get():
            obj.select_set(False)
    meshes = [obj for name in ("Arc · Hilt", "Arc · Blade")
              for obj in bpy.data.collections[name].objects if obj.type == "MESH"]
    # Export evaluated world-space copies so the review file needs no rig or cutters.
    review = bpy.data.collections.new("Arc review · export")
    scene.collection.children.link(review)
    depsgraph = bpy.context.evaluated_depsgraph_get()
    for obj in meshes:
        evaluated = obj.evaluated_get(depsgraph)
        mesh = bpy.data.meshes.new_from_object(evaluated, depsgraph=depsgraph)
        copy = bpy.data.objects.new(obj.name, mesh)
        review.objects.link(copy)
        copy.matrix_world = evaluated.matrix_world
        copy.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(output / "Arc_review.glb"), export_format="GLB",
                              use_selection=True, export_animations=False)
