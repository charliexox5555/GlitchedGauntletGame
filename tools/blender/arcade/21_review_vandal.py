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
}
FINISH_EXTRA = ["deck", "coin_door", "butt", "brake", "joystick"]
exec((Path(bpy.data.filepath).parents[6] / "tools/blender/arcade/20_review.py").read_text(encoding="utf-8"))
