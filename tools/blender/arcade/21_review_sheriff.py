"""Sheriff (revolver) stations for 20_review.py: every new join and detail gets a close-up, and every stock join
(trigger guard, grip, hammer, sights, front ring, underlug, cylinder window, release, charm loop) a culled one
from both sides and below for the gap sweep."""

from pathlib import Path

import bpy

CENTER = (0.62, 0, 0.0)
WIDTH = 2.0
ADS_DISTANCE = 0.42  # Config/Weapons Sheriff adsDistance
# No Cam_Hip in the stock file: a held-pistol stand-in (looks straight down +x from the left, 70 degrees).
HIP = ((-0.55, 0.30, 0.50), 70)
STATIONS = {
    # new parts
    "deck": ((0.15, 0.9, 0.15), (1.04, 0, 0.21), 0.52),
    "deck_controls": ((-0.25, 0.45, 0.05), (0.98, 0.09, 0.17), 0),
    "deck_top": ((0.05, 0.35, 0.55), (1.05, 0.07, 0.30), 0.42),
    "deck_under": ((0.05, 0.35, -0.60), (1.04, 0.06, 0.13), 0.45),
    "deck_rear": ((-0.50, 0.50, 0.10), (0.84, 0.06, 0.21), 0.30),
    "deck_front": ((0.50, 0.50, 0.10), (1.24, 0.06, 0.21), 0.30),
    "coin_door": ((0.10, -0.9, 0.10), (0.22, 0, 0.14), 0.32),
    "coin_door_angle": ((-0.30, -0.50, 0.20), (0.22, -0.07, 0.14), 0),
    "barrel_art": ((0.10, -0.9, 0.10), (1.12, 0, 0.27), 0.65),
    "trim": ((0.10, -0.50, -0.40), (1.10, -0.06, 0.22), 0.70),
    "collar": ((0.35, 0.7, 0.30), (1.46, 0, 0.28), 0.30),
    "collar_rear": ((-0.40, 0.6, 0.25), (1.43, 0, 0.30), 0.25),
    "collar_right": ((0.20, -0.7, -0.20), (1.46, 0, 0.27), 0.30),
    "muzzle_front": ((0.70, 0.2, 0.10), (1.50, 0, 0.28), 0.30),
    # gap sweep of the stock joins
    "trigger_left": ((0.10, 0.8, -0.10), (0.41, 0, -0.06), 0.45),
    "trigger_right": ((0.10, -0.8, -0.10), (0.41, 0, -0.06), 0.45),
    "trigger_under": ((0.10, 0.3, -0.80), (0.41, 0, -0.06), 0.50),
    "grip_left": ((0.20, 0.8, 0.00), (0.00, 0, 0.02), 0.45),
    "grip_right": ((0.20, -0.8, 0.00), (0.00, 0, 0.02), 0.45),
    "grip_under": ((0.10, 0.3, -0.80), (-0.05, 0, -0.20), 0.55),
    "hammer": ((-0.40, 0.5, 0.30), (0.12, 0, 0.30), 0.35),
    "rear_sight": ((-0.35, 0.5, 0.30), (0.29, 0, 0.38), 0.25),
    "front_sight": ((0.30, 0.6, 0.30), (1.37, 0, 0.37), 0.25),
    "ring_left": ((0.20, 0.7, 0.20), (0.78, 0, 0.24), 0.35),
    "ring_right": ((0.20, -0.7, 0.20), (0.78, 0, 0.24), 0.35),
    "lug_under": ((0.10, 0.4, -0.80), (0.95, 0, 0.12), 0.50),
    "lug_rear": ((-0.30, 0.6, -0.20), (0.76, 0, 0.11), 0.25),
    "cylinder_left": ((0.10, 0.8, 0.10), (0.47, 0, 0.19), 0.55),
    "cylinder_right": ((0.10, -0.8, 0.10), (0.47, 0, 0.19), 0.55),
    "release": ((0.10, 0.6, 0.00), (0.22, 0.06, 0.06), 0.20),
    "charm": ((0.10, 0.7, -0.20), (0.68, 0, -0.01), 0.25),
}
FINISH_EXTRA = ["deck", "deck_controls", "coin_door", "barrel_art", "collar", "trim"]
exec((Path(bpy.data.filepath).parents[6] / "tools/blender/arcade/20_review.py").read_text(encoding="utf-8"))
