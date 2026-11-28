"""Bucky (Pump) stations for 20_review.py: every new join and detail gets a close-up, and every stock join
(trigger guard, grip, wrist, butt, forend, barrel, tube, band, collar, sights) a culled one from both sides
and below for the gap sweep."""

from pathlib import Path

import bpy
from mathutils import Matrix

CENTER = (0.94, 0, 0.09)
WIDTH = 4.2
# Config/Weapons Bucky: noAds = true, so there is no adsDistance. The stock file has no AimPoint either: an
# unsaved stand-in over the rear notch (floor .462, walls .49; bead top .477) with 0.36 gives the "ads" review
# camera a look down the notch to the bead. The file is reopened from disk afterwards, so it is never saved.
ADS_DISTANCE = 0.36
stand_in = bpy.data.objects.new("Bucky_AimPoint", None)
stand_in.matrix_world = Matrix.Translation((0.25, 0, 0.474))
# No Cam_Hip in the stock file: Bucky_FP_Hip (looks straight down +x, 80 degrees vertical).
HIP = ((-0.85, 0.6, 0.5), 80)
STATIONS = {
    # new parts
    "deck": ((0.15, 0.9, 0.20), (0.56, 0, 0.31), 0.72),
    "joystick": ((-0.30, 0.5, 0.20), (0.40, 0.09, 0.31), 0),
    "deck_top": ((0.10, 0.45, 0.60), (0.58, 0.08, 0.36), 0.45),
    "coin_door": ((0.10, -0.9, 0.15), (0.56, 0, 0.19), 0.66),
    "forend_left": ((0.30, 0.8, 0.25), (1.67, 0, 0.21), 0.95),
    "forend_right": ((0.30, -0.8, 0.25), (1.67, 0, 0.21), 0.95),
    "forend_under": ((0.20, 0.5, -0.70), (1.67, 0, 0.15), 0.95),
    "forend_rear": ((-0.45, 0.6, 0.15), (1.24, 0, 0.22), 0.35),
    "forend_front": ((0.45, 0.6, 0.15), (2.09, 0, 0.24), 0.35),
    "stock_art": ((0.10, 0.9, 0.20), (-0.58, 0, 0.24), 0.40),
    "butt": ((-0.60, 0.9, 0.30), (-0.89, 0, 0.03), 0.75),
    "butt_join_right": ((0.20, -0.8, 0.20), (-0.85, 0, 0.03), 0.70),
    "butt_under": ((0.10, 0.4, -0.80), (-0.86, 0, -0.25), 0.40),
    "collar": ((0.35, 0.7, 0.30), (2.79, 0, 0.37), 0.35),
    "collar_rear": ((-0.30, 0.6, 0.25), (2.75, 0, 0.36), 0.30),
    "muzzle_front": ((0.70, 0.2, 0.10), (2.83, 0, 0.30), 0.40),
    # gap sweep of the stock joins
    "receiver_front": ((0.30, 0.7, 0.20), (0.96, 0, 0.27), 0.40),
    "receiver_front_right": ((0.30, -0.7, 0.20), (0.96, 0, 0.27), 0.40),
    "charm": ((0.10, 0.8, -0.20), (0.915, 0, 0.15), 0.30),
    "trigger_left": ((0.10, 0.8, -0.10), (0.33, 0, 0.10), 0.50),
    "trigger_right": ((0.10, -0.8, -0.10), (0.33, 0, 0.10), 0.50),
    "trigger_under": ((0.10, 0.3, -0.80), (0.30, 0, 0.08), 0.60),
    "receiver_under": ((0.00, 0.3, -0.80), (0.60, 0, 0.13), 0.80),
    "grip_left": ((0.20, 0.8, 0.00), (-0.05, 0, 0.00), 0.55),
    "grip_right": ((0.20, -0.8, 0.00), (-0.05, 0, 0.00), 0.55),
    "wrist_left": ((0.15, 0.8, 0.20), (-0.15, 0, 0.25), 0.35),
    "wrist_right": ((0.15, -0.8, 0.20), (-0.15, 0, 0.25), 0.35),
    "band": ((0.20, 0.7, -0.20), (2.50, 0, 0.29), 0.40),
    "rear_sight": ((-0.35, 0.5, 0.30), (0.33, 0, 0.44), 0.40),
    "front_sight": ((0.30, 0.6, 0.30), (2.67, 0, 0.44), 0.30),
}
FINISH_EXTRA = ["deck", "joystick", "coin_door", "forend_left", "butt", "collar", "stock_art"]
exec((Path(bpy.data.filepath).parents[6] / "tools/blender/arcade/20_review.py").read_text(encoding="utf-8"))
