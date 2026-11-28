"""Stinger (Hornet) stations for Frostbite 20_review.py."""

from pathlib import Path

CENTER = (-0.185, 0, -0.05)
WIDTH = 3.0
ADS_DISTANCE = 0.30
STATIONS = {
    "core_left": ((0.15, 0.9, 0.25), (0.53, 0, 0.32), 0.55),
    "core_right": ((0.10, -0.9, 0.20), (-0.36, 0, 0.29), 0.45),
    "foreend": ((0.35, 0.8, -0.2), (0.65, 0, 0.19), 0.55),
    "stock_block": ((0.20, 0.9, 0.30), (-0.62, 0, 0.25), 0.45),
    "butt": ((-0.60, 0.9, 0.30), (-1.44, 0, 0.12), 0.60),
    "brake": ((0.35, 0.7, 0.35), (1.00, 0, 0.294), 0.45),
    "mag": ((0.20, 0.9, -0.10), (0.01, 0, -0.38), 0.55),
    "grip_join": ((0.3, 0.8, -0.2), (0.0, 0, 0.14), 0.30),
    "foreend_join": ((-0.3, 0.8, -0.3), (0.47, 0, 0.20), 0.25),
    "front_sight_join": ((0.30, 0.6, 0.30), (0.835, 0, 0.43), 0.25),
}
FINISH_EXTRA = ["core_left", "foreend", "stock_block", "butt", "brake"]
exec((Path(bpy.data.filepath).parents[6] / "tools/blender/frostbite/20_review.py").read_text(encoding="utf-8"))
