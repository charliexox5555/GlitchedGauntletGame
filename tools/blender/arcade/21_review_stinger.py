"""Stinger (Hornet) stations for 20_review.py: every new join and detail gets a close-up, and every
join (new or stock) gets culled magenta views from the left, the right and below (20_review shoots
culled_* of every station) for the no-gaps sweep."""

from pathlib import Path

import bpy

CENTER = (-0.185, 0, -0.05)
WIDTH = 3.0
ADS_DISTANCE = 0.30  # Config/Weapons Stinger.adsDistance (OPEN_IRONS_ADS)
# The stock Stinger file has its own Cam_Hip, so no HIP override is needed.
STATIONS = {
    "deck": ((0.15, 0.9, 0.25), (0.53, 0, 0.32), 0.62),
    "joystick": ((-0.30, 0.5, 0.22), (0.42, 0.10, 0.31), 0),
    "deck_top": ((0.10, 0.45, 0.60), (0.55, 0.08, 0.36), 0.42),
    "coin_door": ((0.10, -0.9, 0.20), (-0.36, 0, 0.29), 0.45),
    "foreend": ((0.35, 0.8, -0.2), (0.65, 0, 0.19), 0.55),
    "foreend_right": ((0.35, -0.8, -0.2), (0.65, 0, 0.19), 0.55),
    "stock_block": ((0.20, 0.9, 0.30), (-0.62, 0, 0.25), 0.45),
    "butt": ((-0.60, 0.9, 0.30), (-1.44, 0, 0.12), 0.60),
    "butt_join": ((0.20, -0.8, 0.30), (-1.38, 0, 0.12), 0.45),
    "brake": ((0.35, 0.7, 0.35), (1.00, 0, 0.294), 0.45),
    "brake_mount": ((-0.30, 0.6, 0.30), (0.90, 0, 0.294), 0.30),
    "mag": ((0.20, 0.9, -0.10), (-0.07, 0, -0.38), 0.60),
    "rear_sight": ((-0.35, 0.5, 0.30), (-0.41, 0, 0.43), 0.30),
    "front_sight": ((0.30, 0.6, 0.30), (0.835, 0, 0.43), 0.25),
    # Gap sweep: every join from the left, the right and below.
    "grip_join": ((0.3, 0.8, -0.2), (0.0, 0, 0.14), 0.30),
    "grip_join_right": ((0.3, -0.8, -0.2), (0.0, 0, 0.14), 0.30),
    "guard_join": ((0.4, 0.6, -0.3), (0.24, 0, 0.12), 0.30),
    "guard_join_right": ((0.4, -0.6, -0.3), (0.24, 0, 0.12), 0.30),
    "lower_below": ((0.05, 0.02, -0.9), (0.20, 0, 0.10), 0.70),
    "foreend_join": ((-0.3, 0.8, -0.3), (0.47, 0, 0.20), 0.25),
    "foreend_join_right": ((-0.3, -0.8, -0.3), (0.47, 0, 0.20), 0.25),
    "foreend_front": ((0.6, 0.6, 0.1), (0.82, 0, 0.25), 0.30),
    "foreend_below": ((0.05, 0.02, -0.9), (0.65, 0, 0.12), 0.50),
    "receiver_rear": ((-0.4, 0.7, 0.3), (-0.52, 0, 0.30), 0.30),
    "receiver_rear_right": ((-0.4, -0.7, 0.3), (-0.52, 0, 0.30), 0.30),
    "receiver_rear_below": ((-0.05, 0.02, -0.9), (-0.55, 0, 0.20), 0.40),
    "bars_block": ((0.2, 0.8, -0.2), (-0.72, 0, 0.20), 0.30),
    "bars_butt_below": ((0.05, 0.02, -0.9), (-1.38, 0, 0.10), 0.40),
    "mag_grip": ((0.3, 0.8, -0.2), (-0.05, 0, -0.22), 0.30),
    "mag_floor": ((0.3, 0.8, -0.4), (-0.07, 0, -0.55), 0.30),
    "rail_join": ((0.3, 0.8, 0.3), (0.0, 0, 0.39), 0.30),
    "cap_join": ((0.3, 0.8, 0.3), (0.78, 0, 0.38), 0.25),
}
FINISH_EXTRA = ["deck", "joystick", "coin_door", "butt", "brake", "stock_block", "foreend"]
exec((Path(bpy.data.filepath).parents[6] / "tools/blender/arcade/20_review.py").read_text(encoding="utf-8"))
