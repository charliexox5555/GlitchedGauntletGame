"""Vandal stations for 20_review.py: every new join and detail gets a close-up."""

from pathlib import Path

import bpy

CENTER = (0.70, 0, 0.10)
WIDTH = 4.29
ADS_DISTANCE = 0.36
STATIONS = {
    "deck": ((0.15, 0.9, 0.25), (0.45, 0, 0.23), 0.55),
    "joystick": ((-0.28, 0.5, 0.22), (0.27, 0.10, 0.23), 0),
    "coin_door": ((0.10, -0.9, 0.20), (0.42, 0, 0.23), 0.50),
    "handguard_front": ((0.35, 0.8, 0.30), (1.62, 0, 0.30), 0.60),
    "handguard_receiver": ((-0.30, 0.8, 0.30), (1.06, 0, 0.30), 0.55),
    "handguard_under": ((0.20, 0.6, -0.60), (1.35, 0, 0.17), 0.60),
    "butt": ((-0.60, 0.9, 0.30), (-1.17, 0, 0.12), 0.80),
    "butt_join": ((0.20, -0.8, 0.30), (-1.10, 0, 0.30), 0.50),
    "brake": ((0.35, 0.7, 0.35), (2.51, 0, 0.285), 0.45),
    "mag": ((0.20, 0.9, -0.10), (0.70, 0, -0.05), 0.60),
    "stock_art": ((0.10, 0.9, 0.30), (-0.80, 0, 0.30), 0.60),
    "rear_sight": ((-0.35, 0.5, 0.30), (0.08, 0, 0.50), 0.45),
    "front_sight": ((0.30, 0.6, 0.30), (2.02, 0, 0.42), 0.50),
    # Gap sweep (v08): culled magenta close-ups of the stock joins it closed (20_review shoots culled_* of
    # every station). The full three-way sweep is in out/Vandal_v08_gapsweep/.
    "trigger_join": ((0.5, 0.6, -0.35), (0.42, 0, 0.13), 0.30),
    "trigger_join_right": ((0.5, -0.6, -0.35), (0.42, 0, 0.13), 0.30),
    "trigger_join_below": ((0.05, 0.02, -0.9), (0.30, 0, 0.08), 0.40),
    "guard_grip_join": ((-0.4, 0.6, -0.2), (0.11, 0, 0.05), 0.22),
    "rail_join": ((0.3, 0.8, 0.1), (0.80, 0, 0.41), 0.20),
    "coin_box_join": ((0.2, -0.8, 0.2), (0.32, 0, 0.27), 0.18),
}
FINISH_EXTRA = ["deck", "coin_door", "butt", "brake", "joystick"]
exec((Path(bpy.data.filepath).parents[6] / "tools/blender/arcade/20_review.py").read_text(encoding="utf-8"))
