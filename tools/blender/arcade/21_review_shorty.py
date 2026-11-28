"""Shorty stations for 20_review.py: every new join and detail gets a close-up, and every stock join
(trigger guard, grip, breech, latch, forend, band, muzzle, sights, CharmLoop) a culled one from both sides
and below for the gap sweep."""

from pathlib import Path

import bpy
from mathutils import Matrix

CENTER = (0.60, 0, 0.0)
WIDTH = 2.1
# Config/Weapons Shorty: noAds = true, so there is no adsDistance, and the stock file has no AimPoint. An
# unsaved stand-in over the rear notch (dots z .351-.36, bead top .348) with 0.36 gives the "ads" review
# camera a look down the rib to the bead. The file is reopened from disk afterwards, so it is never saved.
ADS_DISTANCE = 0.36
stand_in = bpy.data.objects.new("Shorty_AimPoint", None)
stand_in.matrix_world = Matrix.Translation((0.03, 0, 0.356))
STATIONS = {
    # new parts
    "deck": ((0.10, 0.9, 0.15), (0.26, 0, 0.265), 0.62),
    "joystick": ((-0.25, 0.45, 0.15), (0.12, 0.10, 0.26), 0),
    "screen": ((0.05, 0.6, 0.05), (0.37, 0.10, 0.263), 0.32),
    "deck_top": ((0.05, 0.40, 0.55), (0.26, 0.09, 0.30), 0.42),
    "deck_rear": ((-0.45, 0.5, 0.10), (0.02, 0.09, 0.26), 0.30),
    "coin_door": ((0.10, -0.9, 0.10), (0.20, 0, 0.15), 0.42),
    "coin_close": ((0.15, -0.5, 0.15), (0.18, -0.09, 0.15), 0),
    "forend_left": ((0.20, 0.8, 0.10), (1.00, 0, 0.11), 0.60),
    "forend_right": ((0.20, -0.8, 0.10), (1.00, 0, 0.11), 0.60),
    "forend_under": ((0.10, 0.4, -0.8), (1.00, 0, 0.04), 0.60),
    "trim": ((0.10, 0.6, -0.30), (1.05, 0.08, 0.035), 0.35),
    "muzzle": ((0.35, 0.6, 0.25), (1.40, 0, 0.26), 0.35),
    "muzzle_front": ((0.80, 0.15, 0.05), (1.45, 0, 0.26), 0.32),
    "muzzle_rear": ((-0.30, 0.5, 0.25), (1.34, 0, 0.28), 0.30),
    "muzzle_under": ((0.10, -0.3, -0.70), (1.39, 0, 0.21), 0.32),
    "charm": ((0.05, 0.8, -0.05), (0.74, 0.10, 0.20), 0.40),
    # gap sweep of the stock joins
    "trigger_left": ((0.10, 0.8, -0.10), (0.36, 0, -0.03), 0.45),
    "trigger_right": ((0.10, -0.8, -0.10), (0.36, 0, -0.03), 0.45),
    "trigger_under": ((0.10, 0.3, -0.80), (0.36, 0, -0.05), 0.50),
    "grip_left": ((0.20, 0.8, 0.00), (-0.05, 0, -0.10), 0.60),
    "grip_right": ((0.20, -0.8, 0.00), (-0.05, 0, -0.10), 0.60),
    "grip_under": ((0.10, 0.3, -0.80), (-0.10, 0, -0.30), 0.40),
    "breech_left": ((0.25, 0.7, 0.15), (0.55, 0, 0.20), 0.40),
    "breech_right": ((0.25, -0.7, 0.15), (0.55, 0, 0.20), 0.40),
    "breech_top": ((0.10, 0.3, 0.80), (0.55, 0, 0.33), 0.40),
    "latch": ((0.10, 0.8, -0.10), (0.36, 0.09, 0.14), 0.30),
    "forend_rear_under": ((0.00, 0.5, -0.70), (0.70, 0, 0.05), 0.40),
    "band": ((0.20, 0.7, 0.20), (1.29, 0, 0.26), 0.30),
    "rear_sight": ((-0.35, 0.5, 0.30), (0.03, 0, 0.35), 0.30),
    "front_sight": ((0.30, 0.6, 0.30), (1.33, 0, 0.33), 0.25),
    "charmloop": ((0.10, 0.7, 0.10), (-0.06, 0.10, 0.20), 0.25),
}
FINISH_EXTRA = ["deck", "joystick", "screen", "coin_door", "forend_left", "muzzle", "muzzle_front"]
exec((Path(bpy.data.filepath).parents[6] / "tools/blender/arcade/20_review.py").read_text(encoding="utf-8"))
