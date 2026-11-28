"""Shorty stations for Frostbite 20_review.py."""

from pathlib import Path

import bpy
from mathutils import Matrix

CENTER = (0.60, 0, 0.0)
WIDTH = 2.1
ADS_DISTANCE = 0.36
stand_in = bpy.data.objects.new("Shorty_AimPoint", None)
stand_in.matrix_world = Matrix.Translation((0.03, 0, 0.356))
STATIONS = {
    "core_left": ((0.10, 0.9, 0.15), (0.26, 0, 0.265), 0.62),
    "frame_right": ((0.10, -0.9, 0.10), (0.20, 0, 0.15), 0.42),
    "forend_left": ((0.20, 0.8, 0.10), (1.00, 0, 0.11), 0.60),
    "muzzle": ((0.35, 0.6, 0.25), (1.40, 0, 0.26), 0.35),
    "muzzle_front": ((0.80, 0.15, 0.05), (1.45, 0, 0.26), 0.32),
    "charm": ((0.05, 0.8, -0.05), (0.74, 0.10, 0.20), 0.40),
    "trigger_left": ((0.10, 0.8, -0.10), (0.36, 0, -0.03), 0.45),
    "muzzle_rear": ((-0.30, 0.5, 0.25), (1.34, 0, 0.28), 0.30),
}
FINISH_EXTRA = ["core_left", "forend_left", "muzzle", "muzzle_front", "charm"]
exec((Path(bpy.data.filepath).parents[6] / "tools/blender/frostbite/20_review.py").read_text(encoding="utf-8"))
