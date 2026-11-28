"""Transparent UI icons for every charm (memory: UI item art = Blender renders, never ViewportFrames).

Exec in the live Blender MCP (optionally with NAMES = ["Joystick", ...]). For each
art-source/charms/<Name>/<Name>.blend it renders the charm's own collection through its ReviewCam (re-placed to frame
the whole charm from the front three-quarter, above) with its RenderRig lights and a soft white world on a transparent film, to art-source/ui/charm-icons/_raw_<Name>.png;
tools/render/fit_charm_icons.py crops and fits them to 512 x 512.
"""
from pathlib import Path

import math

import bpy
from mathutils import Vector

ROOT = Path(r"C:\Users\charl\Documents\GauntletGame\GlitchedGauntletGame")
SRC = ROOT / "art-source/charms"
OUT = ROOT / "art-source/ui/charm-icons"
OUT.mkdir(parents=True, exist_ok=True)
names = globals().get("NAMES") or sorted(p.name for p in SRC.iterdir() if (p / f"{p.name}.blend").exists())
done, missing = [], []
for name in names:
    bpy.ops.wm.open_mainfile(filepath=str(SRC / name / f"{name}.blend"))
    scene = bpy.context.scene
    cam = bpy.data.objects.get("ReviewCam")
    col = bpy.data.collections.get(name)
    if not cam or not col:
        missing.append(name)
        continue
    keep = {o.name for o in col.all_objects}
    for o in scene.objects:
        if o.type == "MESH" and o.name not in keep:
            o.hide_render = True
    # frame the whole charm from the front three-quarter, above (the review front_34 view)
    pts = [o.matrix_world @ Vector(c) for o in col.all_objects if o.type == "MESH" for c in o.bound_box]
    lo = Vector([min(p[i] for p in pts) for i in range(3)])
    hi = Vector([max(p[i] for p in pts) for i in range(3)])
    center, radius = (lo + hi) / 2, (hi - lo).length / 2
    direction = Vector((0.45, 0.85, -0.32)).normalized()  # camera looks along this
    cam.data.type = "PERSP"
    cam.data.lens_unit = "FOV"
    cam.data.angle = math.radians(30)
    cam.data.clip_start = 0.001
    cam.location = center - direction * (radius / math.sin(math.radians(15)) * 1.05)
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    world = bpy.data.worlds.new("IconWorld")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (1, 1, 1, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.8
    scene.world = world
    scene.camera = cam
    scene.render.film_transparent = True
    scene.render.resolution_x = scene.render.resolution_y = 1024
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.render.filepath = str(OUT / f"_raw_{name}.png")
    bpy.ops.render.render(write_still=True)
    done.append(name)
result = {"done": len(done), "missing": missing}
