"""Operator (Deadeye) stations for Frostbite 20_review.py."""

from pathlib import Path

CENTER = (1.10, 0, 0.25)
WIDTH = 5.0
ADS_DISTANCE = 0.70
HIP = ((-0.631, 0.6375, 0.977), 80)
STATIONS = {
    "core_left": ((0.15, 0.9, 0.25), (0.55, 0, 0.23), 0.70),
    "core_right": ((0.10, -0.9, 0.20), (0.55, 0, 0.23), 0.70),
    "handguard_front": ((0.35, 0.8, 0.30), (1.75, 0, 0.34), 0.80),
    "charm": ((0.10, 0.8, -0.20), (0.95, 0, 0.16), 0.40),
    "butt": ((-0.60, 0.9, 0.30), (-1.19, 0, 0.10), 0.80),
    "brake": ((0.35, 0.7, 0.35), (3.38, 0, 0.385), 0.50),
    "mag": ((0.20, 0.9, -0.10), (0.63, 0, 0.02), 0.50),
    "grip_join": ((-0.1, 0.8, 0.0), (-0.02, 0, 0.14), 0.42),
    "hg_join": ((0.2, 0.8, 0.15), (1.09, 0, 0.30), 0.42),
    "rail_scope": ((0.2, 0.8, 0.1), (0.60, 0, 0.46), 0.55),
}
FINISH_EXTRA = ["core_left", "handguard_front", "butt", "brake", "mag"]
exec((Path(bpy.data.filepath).parents[6] / "tools/blender/frostbite/20_review.py").read_text(encoding="utf-8"))
