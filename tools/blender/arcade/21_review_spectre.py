"""Spectre (Prowler) stations for 20_review.py: every new join and detail gets a close-up."""

from pathlib import Path

import bpy

CENTER = (0.415, 0, 0.02)
WIDTH = 3.3
ADS_DISTANCE = 0.37  # Config/Weapons Spectre.adsDistance
# The stock Spectre file has its own Cam_Hip, so no HIP override is needed.
STATIONS = {
    "deck": ((0.15, 0.9, 0.25), (-0.09, 0, 0.337), 0.62),
    "joystick": ((-0.30, 0.5, 0.22), (-0.20, 0.10, 0.335), 0),
    "deck_top": ((0.10, 0.45, 0.60), (0.05, 0.08, 0.39), 0.42),
    "coin_door": ((0.10, -0.9, 0.20), (0.10, 0, 0.20), 0.62),
    "handguard_front": ((0.35, 0.8, 0.30), (1.10, 0, 0.35), 0.45),
    "handguard_receiver": ((-0.30, 0.8, 0.30), (0.72, 0, 0.36), 0.40),
    "handguard_under": ((0.20, 0.6, -0.60), (0.92, 0, 0.25), 0.55),
    "butt": ((-0.60, 0.9, 0.30), (-0.99, 0, 0.15), 0.70),
    "butt_join": ((0.20, -0.8, 0.30), (-0.92, 0, 0.15), 0.55),
    "stock_art": ((0.10, 0.9, 0.30), (-0.58, 0, 0.30), 0.45),
    "can": ((0.35, 0.7, 0.35), (1.57, 0, 0.353), 0.85),
    "can_mount": ((-0.30, 0.6, 0.30), (1.20, 0, 0.353), 0.40),
    "mag": ((0.20, 0.9, -0.10), (0.65, 0, -0.20), 0.70),
    "rear_sight": ((-0.35, 0.5, 0.30), (-0.05, 0, 0.53), 0.45),
    "front_sight": ((0.30, 0.6, 0.30), (1.02, 0, 0.50), 0.45),
}
FINISH_EXTRA = ["deck", "coin_door", "butt", "can", "joystick", "stock_art"]
exec((Path(bpy.data.filepath).parents[6] / "tools/blender/arcade/20_review.py").read_text(encoding="utf-8"))
