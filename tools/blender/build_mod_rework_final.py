"""Build the final prop and effects pass into its own review and export folder."""

import sys
from pathlib import Path

import bpy

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from build_mod_rework import MODULES, PREVIEWS, ROOT
from mod_rework_final_props import build_props
from mod_rework_review import (
    camera, floor, frame_viewport, label, lighting, molly_review,
    position, prop, prop_review, render_scene,
)
from mod_rework_kit import material

OUT = ROOT / "art-source/abilities/Rework/v02"
PACK = OUT / "Gauntlet_Mod_Rework_v02.blend"


def joints_review():
    scene = render_scene("Beacon and Anchor Details", (1730, 1050),
                         PREVIEWS / "Stim and Recall Details v02.png")
    cam = camera(scene, (1.14, -4.6, 2.45), (0, 0, .285), 2.37)
    lighting(scene)
    floor(scene, "A7AFB6", -.002)
    ink = material("Detail board ink", "283343")
    for name, x in [("Stim", -.52), ("Recall", .55)]:
        prop(scene, name, position((x, 0, 0), -12))
        label(scene, name.upper(), (x, -.62, .027), .058, ink, cam.rotation_euler)


def build(prop_check):
    startup = bpy.context.scene
    hero = build_props()
    molly_review(PREVIEWS / "Molly Moving Parts v02.png")
    prop_review(PREVIEWS / "Ability Props v02.png")
    joints_review()
    if not prop_check:
        from mod_rework_final_fx import build_fx
        build_fx(OUT, PREVIEWS)
    bpy.context.window.scene = bpy.data.scenes[hero.name]
    bpy.data.scenes.remove(startup)
    frame_viewport()
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "Textures").mkdir(exist_ok=True)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(PACK), compress=True, relative_remap=False)


def export():
    from export_mods import export_collection
    bpy.ops.wm.open_mainfile(filepath=str(PACK))
    directory = OUT / "Exports"
    directory.mkdir(exist_ok=True)
    for name in MODULES:
        bpy.context.window.scene = bpy.data.scenes[name]
        print(export_collection(name, str(directory)), flush=True)


def render(scenes):
    bpy.ops.wm.open_mainfile(filepath=str(PACK))
    for name in scenes:
        scene = bpy.data.scenes[name]
        scene.render.threads_mode = "FIXED"
        scene.render.threads = 10
        bpy.ops.render.render(scene=name, write_still=True)


if __name__ == "__main__":
    if not bpy.app.background:
        raise RuntimeError("Run the art pack builder with Blender --background.")
    args = sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else []
    if "--export" in args:
        export()
    elif "--render" in args:
        render(args[args.index("--render")+1:])
    else:
        build("--prop-check" in args)
