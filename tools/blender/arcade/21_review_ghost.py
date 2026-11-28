"""Ghost (Hush) stations for 20_review.py: every new join and detail gets a close-up, plus the gap sweep.

The Ghost has no ADS (noAds) and no AimPoint locator, so this script runs a copy of 20_review.py with
AT set to the front post's top (the physical iron line). ADS_DISTANCE 1.2 puts the "ads" camera on the
iron line at (-0.458, 0, 0.424), behind the rear sight. The stock file has no Cam_Hip: the Ghost uses the
same SIDEARM_VM and viewmodelScale as the Classic and its RightGrip is also at the origin, so HIP is the
Classic's derived camera (-1.097, 0.580, 0.818), 80 degrees.
"""

from pathlib import Path

import bpy

CENTER = (0.90, 0, 0.0)
WIDTH = 2.65
AT = (1.042, 0, 0.424)
ADS_DISTANCE = 1.2  # iron-line view only: the Ghost has no ADS
HIP = ((-1.097, 0.580, 0.818), 80)
STATIONS = {
    "deck": ((0.10, 0.9, 0.15), (0.09, 0, 0.178), 0.42),
    "joystick": ((-0.25, 0.5, 0.15), (-0.03, 0.08, 0.178), 0),
    "deck_top": ((0.05, 0.45, 0.55), (0.10, 0.07, 0.215), 0.36),
    "coin_door": ((0.10, -0.9, 0.10), (-0.01, 0, -0.115), 0.36),
    "slide_art": ((0.10, 0.9, 0.15), (0.45, 0, 0.30), 0.80),
    "can": ((0.30, 0.9, 0.35), (1.60, 0, 0.30), 1.10),
    "can_right": ((0.20, -0.8, 0.20), (1.60, 0, 0.30), 1.10),
    "can_front": ((0.90, 0.0, 0.05), (2.05, 0, 0.30), 0.30),
    "ring": ((0.30, 0.6, 0.25), (1.405, 0, 0.30), 0),
    "neon_teeth": ((0.30, 0.6, 0.10), (0.95, 0, 0.30), 0.25),
    "trim": ((0.15, -0.8, -0.25), (0.92, 0, 0.19), 0.45),
    "charm_zone": ((0.20, 0.8, -0.25), (0.86, 0, 0.18), 0.40),
    "mag": ((0.20, 0.9, -0.15), (-0.07, 0, -0.43), 0.45),
    "rear_end": ((-0.60, 0.5, 0.25), (-0.20, 0, 0.25), 0.45),
    # Gap sweep: every join from both sides and below (20_review shoots culled_* of every station).
    "can_join": ((0.25, 0.6, 0.15), (1.13, 0, 0.30), 0.35),
    "can_join_below": ((0.10, 0.2, -0.8), (1.13, 0, 0.30), 0.35),
    "guard_grip_left": ((0.3, 0.8, -0.2), (0.30, 0, 0.06), 0.35),
    "guard_grip_right": ((0.3, -0.8, -0.2), (0.30, 0, 0.06), 0.35),
    "guard_front_left": ((0.5, 0.7, -0.3), (0.68, 0, 0.10), 0.30),
    "guard_front_right": ((0.5, -0.7, -0.3), (0.68, 0, 0.10), 0.30),
    "guard_below": ((0.05, 0.02, -0.9), (0.45, 0, 0.03), 0.55),
    "grip_frame_left": ((-0.2, 0.8, 0.1), (0.0, 0, 0.13), 0.40),
    "grip_frame_right": ((-0.2, -0.8, 0.1), (0.0, 0, 0.13), 0.40),
    "base_join": ((0.2, 0.8, -0.3), (-0.07, 0, -0.40), 0.45),
    "base_join_right": ((0.2, -0.8, -0.3), (-0.07, 0, -0.40), 0.45),
    "base_below": ((0.3, 0.3, -0.9), (-0.07, 0, -0.43), 0.50),
    "slide_frame_left": ((0.1, 0.8, -0.1), (0.6, 0, 0.23), 0.45),
    "slide_frame_right": ((0.1, -0.8, -0.1), (0.6, 0, 0.23), 0.45),
    "dust_below": ((0.3, 0.3, -0.8), (0.95, 0, 0.17), 0.40),
}
FINISH_EXTRA = ["deck", "joystick", "coin_door", "slide_art", "can", "ring", "charm_zone", "mag"]
source = (Path(bpy.data.filepath).parents[6] / "tools/blender/arcade/20_review.py").read_text(encoding="utf-8")
line = 'AT = bpy.data.objects[f"{GUN}_AimPoint"].matrix_world.translation.copy()'
assert line in source
exec(source.replace(line, 'AT = Vector(globals()["AT"])'))
