"""Marshal (Scout) stations for Frostbite 20_review.py."""

from pathlib import Path

CENTER = (0.97, 0, -0.02)
WIDTH = 4.8
ADS_DISTANCE = 0.70
STATIONS = {
    "core_left": ((0.15, 0.9, 0.2), (0.56, 0, 0.10), 0.70),
    "core_right": ((0.10, -0.9, 0.15), (0.56, 0, 0.12), 0.70),
    "forend": ((0.20, 0.9, 0.2), (1.40, 0, 0.09), 1.05),
    "forend_front": ((0.35, 0.7, -0.2), (1.82, 0, 0.10), 0.50),
    "charm": ((0.10, 0.8, -0.2), (0.82, 0, -0.03), 0.35),
    "butt": ((-0.60, 0.9, 0.3), (-1.22, 0, -0.10), 0.75),
    "muzzle": ((0.35, 0.7, 0.35), (3.16, 0, 0.205), 0.35),
    "forend_receiver": ((-0.30, 0.8, -0.2), (0.88, 0, 0.08), 0.40),
    "trigger_guard": ((0.10, 0.8, -0.2), (0.30, 0, -0.10), 0.55),
    "muzzle_sight_join": ((-0.20, 0.6, 0.3), (3.10, 0, 0.24), 0.22),
}
FINISH_EXTRA = ["core_left", "forend", "forend_front", "butt", "muzzle"]
exec((Path(bpy.data.filepath).parents[6] / "tools/blender/frostbite/20_review.py").read_text(encoding="utf-8"))
