"""Phantom (Spirit) stations for Frostbite 20_review.py."""

from pathlib import Path

CENTER = (0.70, 0, 0.18)
WIDTH = 4.05
ADS_DISTANCE = 0.42
HIP = ((-0.5067, 0.6933, 0.4138), 80)
STATIONS = {
    "core_left": ((0.15, 0.9, 0.25), (0.45, 0, 0.24), 0.65),
    "core_right": ((0.10, -0.9, 0.20), (0.45, 0, 0.24), 0.65),
    "fore_left": ((0.35, 0.8, 0.30), (1.30, 0, 0.30), 0.65),
    "fore_receiver": ((-0.30, 0.8, 0.30), (0.96, 0, 0.32), 0.50),
    "fore_under": ((0.20, 0.6, -0.60), (1.27, 0, 0.20), 0.70),
    "butt": ((-0.60, 0.9, 0.30), (-1.04, 0, 0.18), 0.70),
    "butt_join": ((0.20, -0.8, 0.30), (-0.97, 0, 0.18), 0.55),
    "can": ((0.35, 0.7, 0.35), (2.10, 0, 0.352), 0.90),
    "can_mount": ((-0.30, 0.6, 0.30), (1.70, 0, 0.352), 0.40),
    "mag": ((0.20, 0.9, -0.10), (0.70, 0, -0.06), 0.60),
    "trigger_join": ((0.5, 0.6, -0.35), (0.40, 0, 0.12), 0.34),
    "trigger_join_below": ((0.05, 0.02, -0.9), (0.32, 0, 0.08), 0.40),
    "rail_tip_join": ((0.3, 0.8, 0.2), (1.60, 0, 0.42), 0.24),
    "front_sight_join": ((0.4, 0.5, 0.25), (1.54, 0, 0.48), 0.24),
}
FINISH_EXTRA = ["core_left", "fore_left", "butt", "can", "mag"]
exec((Path(bpy.data.filepath).parents[6] / "tools/blender/frostbite/20_review.py").read_text(encoding="utf-8"))
