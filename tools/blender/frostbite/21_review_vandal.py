"""Vandal stations for 20_review.py: every new join, crystal cluster and detail gets a close-up."""

from pathlib import Path

import bpy

CENTER = (0.70, 0, 0.12)
WIDTH = 4.35
ADS_DISTANCE = 0.36
STATIONS = {
    "core_left": ((0.18, 0.85, 0.22), (0.48, 0.05, 0.28), 0.65),
    "core_right": ((0.18, -0.85, 0.22), (0.48, -0.05, 0.28), 0.65),
    "fore_left": ((0.22, 0.90, 0.25), (1.38, 0.05, 0.30), 0.72),
    "fore_right": ((0.22, -0.90, 0.25), (1.38, -0.05, 0.30), 0.72),
    "fore_front": ((0.35, 0.80, 0.30), (1.72, 0, 0.31), 0.65),
    "fore_receiver": ((-0.25, 0.80, 0.25), (1.02, 0, 0.28), 0.60),
    "fore_under": ((0.20, 0.55, -0.65), (1.36, 0, 0.18), 0.65),
    "stock": ((-0.50, 0.95, 0.28), (-0.78, 0, 0.16), 1.15),
    "stock_join": ((0.20, 0.80, 0.25), (-0.18, 0, 0.30), 0.55),
    "stock_join_right": ((0.20, -0.80, 0.25), (-0.18, 0, 0.30), 0.55),
    "butt_join": ((-0.25, 0.80, 0.25), (-1.12, 0, 0.12), 0.85),
    "muzzle": ((0.35, 0.70, 0.32), (2.52, 0, 0.285), 0.52),
    "mag": ((0.22, 0.90, -0.10), (0.72, 0, -0.08), 0.68),
    "charm": ((-0.15, 0.55, 0.12), (0.93, 0.095, 0.18), 0.32),
    "rear_sight": ((-0.35, 0.50, 0.30), (0.08, 0, 0.50), 0.45),
    "front_sight": ((0.30, 0.60, 0.30), (2.02, 0, 0.42), 0.50),
    "trigger_join_left": ((0.45, 0.60, -0.35), (0.42, 0, 0.13), 0.34),
    "trigger_join_right": ((0.45, -0.60, -0.35), (0.42, 0, 0.13), 0.34),
    "trigger_join_below": ((0.05, 0.02, -0.90), (0.30, 0, 0.08), 0.42),
    "guard_grip_join": ((-0.40, 0.60, -0.20), (0.11, 0, 0.05), 0.24),
    "rail_join": ((0.30, 0.80, 0.10), (0.80, 0, 0.41), 0.22),
}
FINISH_EXTRA = ["core_left", "fore_left", "stock", "muzzle", "mag"]
exec((Path(bpy.data.filepath).parents[6] / "tools/blender/frostbite/20_review.py").read_text(encoding="utf-8"))
