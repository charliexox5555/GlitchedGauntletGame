"""Export the PopCircuit Bat using the same axes and part names as stock weapons."""
import json
from pathlib import Path
import sys

import bpy

sys.path.insert(0,str(Path(__file__).resolve().parent))
import export_weapons as exporter

dest = Path(bpy.data.filepath).resolve().parent / "studio-export"
dest.mkdir(exist_ok=True)
exporter.OUT_DIR = str(dest)
collection = bpy.data.collections["Bat"]
collection["weapon_name"] = "Bat"
rig = bpy.data.objects["Bat_Rig"]
animation = rig.animation_data
animation.action = None
scene = bpy.context.scene
for action in [bpy.data.actions[name] for name in ("Bat_Idle","Bat_SlashLeft","Bat_SlashRight","Bat_Smash","Bat_Inspect")]:
    track = animation.nla_tracks.new()
    name = action.name.removeprefix("Bat_")
    track.name = name
    track.strips.new(name,1,action)
    track.mute = True
for bone in rig.pose.bones:
    bone.matrix_basis.identity()
    bone.location = (0,0,0)
    bone.rotation_euler = (0,0,0)
# World-space pose constraints belong to the Blender camera review.
for constraint in list(rig.pose.bones["LeftHand"].constraints):
    rig.pose.bones["LeftHand"].constraints.remove(constraint)
scene.frame_set(1)
bpy.context.view_layer.update()
print("BAT_EXPORT "+json.dumps(exporter.export_gun(collection)))

