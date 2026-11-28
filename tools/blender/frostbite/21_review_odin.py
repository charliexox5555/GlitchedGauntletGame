"""Odin (Mauler) stations for Frostbite 20_review.py."""

from pathlib import Path

CENTER = (1.08, 0, 0.17)
WIDTH = 4.75
ADS_DISTANCE = 0.39
HIP = ((-0.5632, 0.6933, 0.5330), 80)
STATIONS = {
    "core_left": ((0.10, 0.9, 0.20), (0.58, 0, 0.33), 0.75),
    "core_right": ((0.10, -0.9, 0.15), (0.55, 0, 0.24), 0.70),
    "handguard_left": ((0.10, 0.9, 0.10), (1.84, 0, 0.30), 0.85),
    "handguard_front": ((0.35, 0.8, 0.30), (2.10, 0, 0.30), 0.55),
    "charm_zone": ((0.10, 0.9, 0.05), (1.18, 0, 0.36), 0.60),
    "box_left": ((0.15, 0.9, -0.05), (0.95, 0, -0.15), 0.90),
    "box_flange": ((0.30, 0.8, -0.25), (0.95, 0, 0.13), 0.60),
    "butt": ((0.45, 0.8, 0.28), (-1.06, 0, 0.15), 0.85),
    "brake": ((0.35, 0.7, 0.35), (3.18, 0, 0.371), 0.55),
    "trigger_join": ((0.5, 0.6, -0.35), (0.31, 0, 0.12), 0.42),
    "rear_cap_join": ((-0.3, 0.8, 0.3), (-0.25, 0, 0.33), 0.50),
    "front_sight_join": ((0.30, 0.6, 0.30), (2.43, 0, 0.55), 0.40),
}
FINISH_EXTRA = ["core_left", "handguard_left", "box_left", "butt", "brake"]
exec((Path(bpy.data.filepath).parents[6] / "tools/blender/frostbite/20_review.py").read_text(encoding="utf-8"))
