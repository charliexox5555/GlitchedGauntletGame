"""Block the Slipframe Arc draw and inspect on the export master's grip and plate."""

import json
import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Quaternion, Vector
from mathutils.bvhtree import BVHTree

sys.path.insert(0, str(Path(__file__).resolve().parent))
from arc_plate_joint import PLATE_BONE, fit_plate_joint


source = Path(bpy.data.filepath)
assert source.name == "Knife_Slipframe_Arc_r01.blend", source
output = source.parent.with_name("anim01")
output.mkdir(parents=True, exist_ok=True)
master = output / "Knife_Slipframe_Arc_anim01.blend"
assert not master.exists(), master

FPS = 24
LIFT = .018
GUIDE_INNER_Y = -.0068
POCKET_FLOOR_Y = .015
rig = fit_plate_joint()
rig.data.pose_position = "POSE"
root = rig.pose.bones["Root"]
plate = rig.pose.bones[PLATE_BONE]
root.rotation_mode = "XYZ"
animation = rig.animation_data_create()
for track in animation.nla_tracks:
    track.mute = True
scene = bpy.context.scene
scene.render.fps = FPS
scene.render.fps_base = 1


def block(name, root_keys, plate_keys, markers):
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    animation.action = action
    for frame, degrees, translation in root_keys:
        root.rotation_euler = [math.radians(value) for value in degrees]
        root.location = translation
        root.keyframe_insert(data_path="rotation_euler", frame=frame, group="Root")
        root.keyframe_insert(data_path="location", frame=frame, group="Root")
    for frame, travel in plate_keys:
        plate.location = (0, travel, 0)
        plate.keyframe_insert(data_path="location", frame=frame, group=PLATE_BONE)
    channelbag = action.layers[0].strips[0].channelbag(action.slots[0])
    for curve in channelbag.fcurves:
        for key in curve.keyframe_points:
            key.interpolation = "BEZIER"
            key.handle_left_type = "AUTO_CLAMPED"
            key.handle_right_type = "AUTO_CLAMPED"
        curve.update()
    for label, frame in markers.items():
        marker = action.pose_markers.new(label)
        marker.frame = frame
    return action


zero = (0, 0, 0)
draw = block("Arc_Draw_Block", [
    (1, (-48, 12, -11), (.035, -.04, -.28)),
    (4, (-31, 8, -7), (.024, -.016, -.146)),
    (8, (16, -5, 3), (-.014, .008, .029)),
    (11, (-4, 2, -1), (.005, 0, -.011)),
    (15, zero, zero),
], [(1, 0), (15, 0)], {"SeamWake": 7, "DrawSettle": 15})

inspect = block("Arc_Inspect_Block", [
    (1, zero, zero),
    (8, (-5, 5, -4), (.024, -.018, -.034)),
    (16, (15, -11, 8), (-.050, .017, .035)),
    (24, (25, -14, 8), (-.054, .020, .045)),
    (36, (34, -12, 6), (-.056, .018, .055)),
    (46, (23, -7, 2), (-.032, .012, .033)),
    (54, (7, -2, 1), (-.010, .006, .016)),
    (65, zero, zero),
], [(1, 0), (17, 0), (20, .002), (27, LIFT), (41, LIFT),
    (48, .003), (51, 0), (65, 0)],
    {"SeamWake": 14, "PanelRelease": 18, "RevealHold": 27,
     "PanelSeat": 51, "InspectSettle": 65})


def pick(action, first, last):
    animation.action = action
    animation.action_slot = action.slots[0]
    scene.frame_start = first
    scene.frame_end = last
    scene.frame_set(first)


def tree(obj, depsgraph):
    current = obj.evaluated_get(depsgraph)
    mesh = current.to_mesh()
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bm.transform(current.matrix_world)
    volume = BVHTree.FromBMesh(bm)
    bm.free()
    current.to_mesh_clear()
    return volume


def check_actions():
    blade = bpy.data.objects["Arc_Blade_SweptTitanium"]
    right_panel = bpy.data.objects["Arc_CobaltInlay_R"]
    guides = [bpy.data.objects[f"Arc_PlateGuide_{i}"] for i in (1, 2)]
    clips = [(draw, 15), (inspect, 65)]
    report = {}
    for action, last in clips:
        pick(action, 1, last)
        travel_peak = 0
        for sample in range(2, 2*last+1):
            scene.frame_set(sample//2, subframe=(sample % 2)*.5)
            travel = plate.location.y
            travel_peak = max(travel_peak, travel)
            assert -.000001 <= travel <= LIFT+.000001, (action.name, sample/2, travel)
            if action == inspect:
                depsgraph = bpy.context.evaluated_depsgraph_get()
                chassis = tree(blade, depsgraph)
                for driven in (right_panel, *guides):
                    assert not chassis.overlap(tree(driven, depsgraph)), (driven.name, sample/2)
        assert max(abs(value) for value in (*root.location, *root.rotation_euler, *plate.location)) < 1e-6
        report[action.name] = {
            "frames": [1, last],
            "samples": 2*last-1,
            "duration_s": round((last-1)/FPS, 3),
            "max_plate_travel": round(travel_peak, 6),
            "minimum_guide_engagement": round(POCKET_FLOOR_Y-(GUIDE_INNER_Y+travel_peak), 6),
            "markers": {marker.name: marker.frame for marker in action.pose_markers},
        }
    assert abs(report[inspect.name]["max_plate_travel"] - LIFT) < 1e-6
    assert report[inspect.name]["minimum_guide_engagement"] > .003
    return report


report = check_actions()
scene.name = "Slipframe Arc · Draw and inspect blocks"
scene["Arc motion stage"] = "Cosmetic draw and inspect blocking on the stock grip. Rigged plate reveal."
pick(inspect, 1, 65)
for marker in inspect.pose_markers:
    scene.timeline_markers.new(marker.name, frame=marker.frame)

stage = bpy.data.collections.new("Arc motion · review cameras")
scene.collection.children.link(stage)


def camera(name, target, direction, roll, scale):
    data = bpy.data.cameras.new(name)
    view = bpy.data.objects.new(name, data)
    stage.objects.link(view)
    view.location = Vector(target) + Vector(direction).normalized()*3
    forward = (Vector(target)-view.location).to_track_quat("-Z", "Y")
    view.rotation_euler = (forward @ Quaternion((0, 0, 1), math.radians(roll))).to_euler()
    data.type = "ORTHO"
    data.ortho_scale = scale
    return view


overview = camera("Arc motion overview", (.40, 0, -.057), (.15, 1, .29), 11, 2.05)
detail = camera("Arc guided reveal detail", (.695, .006, .18), (-.36, 1, -.20), -10, 1.08)
scene.camera = overview
(output / "motion_audit.json").write_text(json.dumps(report, indent=2)+"\n", encoding="utf-8")
bpy.ops.wm.save_as_mainfile(filepath=str(master))

if "--preview" in sys.argv:
    preview = Path(sys.argv[sys.argv.index("--preview")+1])
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.render.resolution_x, scene.render.resolution_y = 960, 540
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGB"
    scene.render.film_transparent = False
    scene.display.render_aa = "8"
    shading = scene.display.shading
    shading.light = "STUDIO"
    shading.color_type = "MATERIAL"
    shading.show_shadows = True
    shading.show_cavity = True
    shading.cavity_type = "WORLD"
    shading.background_type = "VIEWPORT"
    shading.background_color = (.025, .039, .062)
    scene.world.color = (.025, .039, .062)
    scene.view_settings.view_transform = "Standard"
    for label, action, first, last, view in (
        ("draw", draw, 1, 15, overview),
        ("inspect", inspect, 1, 65, overview),
        ("guide_detail", inspect, 16, 53, detail),
    ):
        pick(action, first, last)
        scene.camera = view
        directory = preview / label
        directory.mkdir(parents=True, exist_ok=True)
        scene.render.filepath = str(directory / "frame_")
        bpy.ops.render.render(animation=True)
print(json.dumps(report))
