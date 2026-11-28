"""Spectre (Prowler) stations for Frostbite 20_review.py."""

from pathlib import Path

CENTER = (0.415, 0, 0.02)
WIDTH = 3.3
ADS_DISTANCE = 0.37
STATIONS = {
    "core_left": ((0.15, 0.9, 0.25), (0.46, 0, 0.20), 0.55),
    "core_right": ((0.10, -0.9, 0.20), (0.46, 0, 0.20), 0.55),
    "handguard_front": ((0.35, 0.8, 0.30), (1.00, 0, 0.34), 0.55),
    "handguard_receiver": ((-0.30, 0.8, 0.30), (0.70, 0, 0.35), 0.45),
    "handguard_under": ((0.20, 0.6, -0.60), (0.92, 0, 0.25), 0.55),
    "butt": ((-0.60, 0.9, 0.30), (-0.99, 0, 0.15), 0.70),
    "butt_join": ((0.20, -0.8, 0.30), (-0.92, 0, 0.15), 0.55),
    "stock_art": ((0.10, 0.9, 0.30), (-0.54, 0, 0.32), 0.45),
    "can": ((0.35, 0.7, 0.35), (1.57, 0, 0.353), 0.85),
    "can_mount": ((-0.30, 0.6, 0.30), (1.20, 0, 0.353), 0.40),
    "mag": ((0.20, 0.9, -0.10), (0.72, 0, -0.22), 0.60),
    "lower_hg_join": ((0.2, 0.8, -0.3), (0.67, 0, 0.26), 0.24),
    "grip_guard_join": ((0.4, 0.6, -0.2), (0.13, 0, 0.08), 0.22),
    "front_sight_join": ((0.4, 0.5, 0.25), (1.015, 0, 0.48), 0.20),
}
FINISH_EXTRA = ["core_left", "handguard_front", "butt", "can", "mag"]
exec((Path(bpy.data.filepath).parents[6] / "tools/blender/frostbite/20_review.py").read_text(encoding="utf-8"))
