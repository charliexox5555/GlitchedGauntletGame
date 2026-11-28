"""Sheriff stations for Frostbite 20_review.py."""

from pathlib import Path

CENTER = (0.62, 0, 0.0)
WIDTH = 2.0
ADS_DISTANCE = 0.42
HIP = ((-0.55, 0.30, 0.50), 70)
STATIONS = {
    "core_left": ((0.15, 0.9, 0.15), (1.04, 0, 0.21), 0.52),
    "frame_right": ((0.10, -0.9, 0.10), (0.22, 0, 0.14), 0.32),
    "barrel_art": ((0.10, -0.9, 0.10), (1.12, 0, 0.27), 0.65),
    "collar": ((0.35, 0.7, 0.30), (1.46, 0, 0.28), 0.30),
    "muzzle_front": ((0.70, 0.2, 0.10), (1.50, 0, 0.28), 0.30),
    "trigger_left": ((0.10, 0.8, -0.10), (0.41, 0, -0.06), 0.45),
    "lug_rear": ((-0.30, 0.6, -0.20), (0.76, 0, 0.11), 0.25),
}
FINISH_EXTRA = ["core_left", "frame_right", "barrel_art", "collar", "muzzle_front"]
exec((Path(bpy.data.filepath).parents[6] / "tools/blender/frostbite/20_review.py").read_text(encoding="utf-8"))
