"""Classic stations for 20_review.py: every new join and detail gets a close-up, plus the gap sweep.

The Classic has no ADS (alt fire) and no AimPoint locator, so this script runs a copy of 20_review.py with
AT set to the front post's top (the physical iron line, as in 49_audit.py). ADS_DISTANCE 1.2 puts the
"ads" camera at the audit's iron eye (-0.565, 0, 0.509). The stock file has no Cam_Hip: HIP is the
Config/Weapons SIDEARM_VM (0.52, -0.72, -1.0) + Viewmodel HIP_SHIFT (-0.01, 0, 0.035) from the RightGrip
(sidearms are placed by the grip), over 0.8 x viewmodelScale 1.1: (-1.097, 0.580, 0.818).
"""

from pathlib import Path

import bpy

CENTER = (0.38, 0, 0.07)
WIDTH = 2.45
AT = (0.935, 0, 0.509)
ADS_DISTANCE = 1.2  # iron-line view only: the Classic has no ADS
HIP = ((-1.097, 0.580, 0.818), 80)
STATIONS = {
    "deck": ((0.10, 0.9, 0.15), (0.05, 0, 0.224), 0.45),
    "joystick": ((-0.25, 0.5, 0.15), (-0.06, 0.09, 0.224), 0),
    "deck_top": ((0.05, 0.45, 0.55), (0.06, 0.08, 0.26), 0.38),
    "coin_door": ((0.10, -0.9, 0.10), (0.0, 0, -0.09), 0.40),
    "slide_art": ((0.10, 0.9, 0.15), (0.49, 0, 0.38), 0.50),
    "muzzle": ((0.60, 0.5, 0.15), (1.0, 0, 0.36), 0),
    "muzzle_front": ((0.90, 0.0, 0.05), (1.0, 0, 0.36), 0.22),
    "trim": ((0.15, -0.8, -0.25), (0.80, 0, 0.21), 0.45),
    "charm_zone": ((0.20, 0.8, -0.25), (0.74, 0, 0.20), 0.45),
    "mag": ((0.20, 0.9, -0.15), (0.0, 0, -0.34), 0.45),
    "rear_loop": ((-0.60, 0.5, 0.25), (-0.20, 0, 0.30), 0.45),
    # Gap sweep: every join from both sides and below (20_review shoots culled_* of every station).
    "guard_grip_left": ((0.3, 0.8, -0.2), (0.24, 0, 0.09), 0.30),
    "guard_grip_right": ((0.3, -0.8, -0.2), (0.24, 0, 0.09), 0.30),
    "guard_below": ((0.05, 0.02, -0.9), (0.30, 0, 0.05), 0.45),
    "grip_frame_left": ((-0.2, 0.8, 0.1), (0.0, 0, 0.18), 0.35),
    "grip_frame_right": ((-0.2, -0.8, 0.1), (0.0, 0, 0.18), 0.35),
    "base_join": ((0.2, 0.8, -0.3), (0.0, 0, -0.30), 0.40),
    "base_below": ((0.3, 0.3, -0.9), (0.0, 0, -0.33), 0.50),
    "slide_frame_left": ((0.1, 0.8, -0.1), (0.6, 0, 0.29), 0.40),
    "slide_frame_right": ((0.1, -0.8, -0.1), (0.6, 0, 0.29), 0.40),
    "nose_below": ((0.4, 0.3, -0.8), (0.93, 0, 0.25), 0.35),
}
FINISH_EXTRA = ["deck", "joystick", "coin_door", "slide_art", "muzzle", "charm_zone"]
source = (Path(bpy.data.filepath).parents[6] / "tools/blender/arcade/20_review.py").read_text(encoding="utf-8")
line = 'AT = bpy.data.objects[f"{GUN}_AimPoint"].matrix_world.translation.copy()'
assert line in source
exec(source.replace(line, 'AT = Vector(globals()["AT"])'))
