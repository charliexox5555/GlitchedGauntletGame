"""Phantom (Spirit) stations for 20_review.py: every new join and detail gets a close-up."""

from pathlib import Path

import bpy

CENTER = (0.70, 0, 0.18)
WIDTH = 4.05
ADS_DISTANCE = 0.42  # Config/Weapons Phantom.adsDistance
# The stock Phantom file has no Cam_Hip: the Vandal's Cam_Hip (-0.507, 0.693, 0.400, 80 deg) raised
# 0.011 / 0.8 for the Phantom's lower viewmodelOffset (-0.277 against -0.266).
HIP = ((-0.5067, 0.6933, 0.4138), 80)
STATIONS = {
    "deck": ((0.15, 0.9, 0.25), (0.45, 0, 0.24), 0.62),
    "joystick": ((-0.28, 0.5, 0.22), (0.30, 0.10, 0.24), 0),
    "coin_door": ((0.10, -0.9, 0.20), (0.45, 0, 0.24), 0.62),
    "handguard_front": ((0.35, 0.8, 0.30), (1.56, 0, 0.30), 0.55),
    "handguard_receiver": ((-0.30, 0.8, 0.30), (0.96, 0, 0.32), 0.50),
    "handguard_under": ((0.20, 0.6, -0.60), (1.27, 0, 0.20), 0.70),
    "butt": ((-0.60, 0.9, 0.30), (-1.04, 0, 0.18), 0.70),
    "butt_join": ((0.20, -0.8, 0.30), (-0.97, 0, 0.18), 0.55),
    "stock_art": ((0.10, 0.9, 0.30), (-0.55, 0, 0.30), 0.50),
    "can": ((0.35, 0.7, 0.35), (2.10, 0, 0.352), 0.90),
    "can_mount": ((-0.30, 0.6, 0.30), (1.70, 0, 0.352), 0.40),
    "mag": ((0.20, 0.9, -0.10), (0.70, 0, -0.06), 0.60),
    "rear_sight": ((-0.35, 0.5, 0.30), (0.15, 0, 0.53), 0.45),
    "front_sight": ((0.30, 0.6, 0.30), (1.55, 0, 0.50), 0.45),
}
FINISH_EXTRA = ["deck", "coin_door", "butt", "can", "joystick"]
exec((Path(bpy.data.filepath).parents[6] / "tools/blender/arcade/20_review.py").read_text(encoding="utf-8"))
