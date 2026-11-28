"""Operator (Deadeye) stations for 20_review.py: every new join and detail gets a close-up, and every join
(new or stock) gets a culled magenta close-up from the left, the right and below (gap sweep)."""

from pathlib import Path

import bpy

CENTER = (1.10, 0, 0.25)
WIDTH = 5.0
ADS_DISTANCE = 0.70  # no Config/Weapons Operator.adsDistance: Viewmodel ADS_DISTANCE (scoped, zoom 2.5)
# The stock Operator file has no Cam_Hip. HIP = the AimPoint minus (viewmodelOffset SCOPED_VM + HIP_SHIFT)
# / SCALE 0.8: (0.51, -0.30, -0.435) studs -> camera at AimPoint + (-0.544, +0.6375, +0.375).
HIP = ((-0.631, 0.6375, 0.977), 80)
STATIONS = {
    # Arcade details
    "deck": ((0.15, 0.9, 0.25), (0.45, 0, 0.245), 0.75),
    "joystick": ((-0.30, 0.5, 0.22), (0.30, 0.10, 0.25), 0),
    "deck_top": ((0.10, 0.45, 0.60), (0.45, 0.08, 0.30), 0.45),
    "coin_door": ((0.10, -0.9, 0.20), (0.40, 0, 0.22), 0.75),
    "handguard_front": ((0.35, 0.8, 0.30), (2.00, 0, 0.33), 0.60),
    "vents": ((0.10, 0.9, 0.20), (1.40, 0, 0.33), 0.60),
    "charm": ((0.10, 0.8, -0.20), (0.95, 0, 0.16), 0.40),
    "butt": ((-0.60, 0.9, 0.30), (-1.19, 0, 0.10), 0.80),
    "butt_right": ((-0.30, -0.9, 0.30), (-1.19, 0, 0.10), 0.80),
    "stock_art": ((0.10, 0.9, 0.30), (-0.56, 0, 0.27), 0.45),
    "brake": ((0.35, 0.7, 0.35), (3.38, 0, 0.385), 0.50),
    "mag": ((0.20, 0.9, -0.10), (0.63, 0, 0.02), 0.50),
    "first_person_close": ((-0.5, 0.45, 0.45), (0.45, 0.09, 0.27), 0),
    # Gap sweep: left / right / below on every join
    "hg_join": ((0.2, 0.8, 0.15), (1.09, 0, 0.30), 0.42),
    "hg_join_right": ((0.2, -0.8, 0.15), (1.09, 0, 0.30), 0.42),
    "hg_join_under": ((0.25, 0.25, -0.8), (1.09, 0, 0.22), 0.45),
    "handguard_under": ((0.20, 0.5, -0.70), (1.70, 0, 0.22), 0.90),
    "nose_barrel": ((0.40, 0.6, -0.15), (2.22, 0, 0.36), 0.35),
    "nose_barrel_right": ((0.40, -0.6, 0.15), (2.22, 0, 0.36), 0.35),
    "trigger_guard": ((0.1, 0.8, -0.1), (0.25, 0, 0.09), 0.45),
    "trigger_guard_right": ((0.1, -0.8, -0.1), (0.25, 0, 0.09), 0.45),
    "trigger_guard_under": ((0.2, 0.2, -0.8), (0.25, 0, 0.09), 0.50),
    "grip_join": ((-0.1, 0.8, 0.0), (-0.02, 0, 0.14), 0.42),
    "grip_join_right": ((-0.1, -0.8, 0.0), (-0.02, 0, 0.14), 0.42),
    "magwell": ((0.1, 0.8, -0.2), (0.63, 0, 0.13), 0.55),
    "magwell_right": ((0.1, -0.8, -0.2), (0.63, 0, 0.13), 0.55),
    "magwell_under": ((0.2, 0.2, -0.8), (0.63, 0, 0.12), 0.60),
    "tube_join": ((0.2, 0.8, 0.2), (0.03, 0, 0.25), 0.40),
    "tube_join_right": ((0.2, -0.8, 0.2), (0.03, 0, 0.25), 0.40),
    "tube_frame_join": ((-0.2, 0.8, 0.1), (-0.36, 0, 0.22), 0.40),
    "tube_frame_join_under": ((0.2, 0.3, -0.8), (-0.30, 0, 0.18), 0.50),
    "riser_posts": ((0.2, 0.8, 0.1), (-0.66, 0, 0.33), 0.30),
    "riser_posts_right": ((0.2, -0.8, 0.1), (-0.66, 0, 0.33), 0.30),
    "butt_join": ((0.30, 0.8, 0.2), (-1.07, 0, 0.10), 0.65),
    "butt_join_right": ((0.30, -0.8, 0.2), (-1.07, 0, 0.10), 0.65),
    "butt_join_under": ((0.3, 0.3, -0.8), (-1.10, 0, -0.10), 0.55),
    "rail_scope": ((0.15, 0.8, 0.15), (0.40, 0, 0.47), 0.25),
    "rail_scope_right": ((0.15, -0.8, 0.15), (0.86, 0, 0.47), 0.25),
    "collar_brake": ((0.25, 0.7, 0.15), (3.20, 0, 0.385), 0.35),
    "collar_brake_right": ((-0.25, -0.7, -0.15), (3.20, 0, 0.385), 0.35),
}
FINISH_EXTRA = ["deck", "joystick", "coin_door", "butt", "brake", "stock_art", "handguard_front"]
exec((Path(bpy.data.filepath).parents[6] / "tools/blender/arcade/20_review.py").read_text(encoding="utf-8"))
