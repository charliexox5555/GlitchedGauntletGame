"""Bucky (Pump) stations for Frostbite 20_review.py."""

from pathlib import Path

import bpy
from mathutils import Matrix

CENTER = (0.94, 0, 0.09)
WIDTH = 4.2
ADS_DISTANCE = 0.36
stand_in = bpy.data.objects.new("Bucky_AimPoint", None)
stand_in.matrix_world = Matrix.Translation((0.25, 0, 0.474))
HIP = ((-0.85, 0.6, 0.5), 80)
STATIONS = {
    "core_left": ((0.15, 0.9, 0.20), (0.56, 0, 0.31), 0.72),
    "core_right": ((0.10, -0.9, 0.15), (0.56, 0, 0.19), 0.66),
    "forend_left": ((0.30, 0.8, 0.25), (1.67, 0, 0.21), 0.95),
    "forend_rear": ((-0.45, 0.6, 0.15), (1.24, 0, 0.22), 0.35),
    "butt": ((-0.60, 0.9, 0.30), (-0.89, 0, 0.03), 0.75),
    "collar": ((0.35, 0.7, 0.30), (2.79, 0, 0.37), 0.35),
    "trigger_left": ((0.10, 0.8, -0.10), (0.33, 0, 0.10), 0.50),
    "grip_left": ((0.20, 0.8, 0.00), (-0.05, 0, 0.00), 0.55),
}
FINISH_EXTRA = ["core_left", "forend_left", "butt", "collar"]
exec((Path(bpy.data.filepath).parents[6] / "tools/blender/frostbite/20_review.py").read_text(encoding="utf-8"))
