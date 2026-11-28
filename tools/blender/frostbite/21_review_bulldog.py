"""Bulldog (Lancer) stations for Frostbite 20_review.py."""

from pathlib import Path

CENTER = (0.0, 0, 0.17)
WIDTH = 3.35
ADS_DISTANCE = 0.38
STATIONS = {
    "core_left": ((0.15, 0.9, 0.25), (-0.79, 0, 0.345), 0.62),
    "core_right": ((0.10, -0.9, 0.20), (-0.79, 0, 0.345), 0.62),
    "stock_field_left": ((0.10, 0.9, 0.10), (-0.99, 0, 0.08), 0.55),
    "handguard_front": ((0.35, 0.8, 0.30), (0.85, 0, 0.25), 0.50),
    "handguard_under": ((0.20, 0.6, -0.60), (0.82, 0, 0.18), 0.60),
    "butt": ((-0.60, 0.9, 0.30), (-1.31, 0, 0.18), 0.75),
    "butt_join": ((0.20, -0.8, 0.30), (-1.20, 0, 0.18), 0.60),
    "brake": ((0.35, 0.7, 0.35), (1.34, 0, 0.3614), 0.40),
    "mag": ((0.20, 0.9, -0.10), (-0.62, 0, -0.08), 0.55),
    "trigger_join": ((0.5, 0.6, -0.35), (0.47, 0, 0.16), 0.30),
    "front_sight_join": ((0.4, 0.5, 0.25), (0.87, 0, 0.5), 0.30),
}
FINISH_EXTRA = ["core_left", "handguard_front", "butt", "brake", "mag"]
exec((Path(bpy.data.filepath).parents[6] / "tools/blender/frostbite/20_review.py").read_text(encoding="utf-8"))
