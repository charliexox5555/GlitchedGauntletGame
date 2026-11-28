"""Odin (Mauler) stations for 20_review.py: every new join and detail gets a close-up, plus the gap sweep."""

from pathlib import Path

import bpy

CENTER = (1.08, 0, 0.17)
WIDTH = 4.75
ADS_DISTANCE = 0.39  # Config/Weapons Odin.adsDistance (adsFov 70; 20_review renders ADS at 68)
# The stock Odin file has no Cam_Hip: the Vandal's Cam_Hip placed at the same offset from the AimPoint
# (-0.5842, +0.6933, -0.1598), raised 0.034 / 0.8 for the Odin's lower viewmodelOffset (RIFLE_VM -0.3
# against the Vandal's -0.266).
HIP = ((-0.5632, 0.6933, 0.5330), 80)
STATIONS = {
    "deck": ((0.10, 0.9, 0.20), (0.31, 0, 0.34), 0.95),
    "joystick": ((-0.30, 0.5, 0.20), (0.02, 0.10, 0.43), 0),
    "screen": ((0.05, 0.6, 0.10), (0.60, 0.10, 0.345), 0.36),
    "deck_top": ((0.10, 0.45, 0.60), (0.30, 0.08, 0.46), 0.80),
    "coin_door": ((0.10, -0.9, 0.10), (1.13, 0, 0.32), 0.55),
    "handguard_left": ((0.10, 0.9, 0.10), (1.79, 0, 0.30), 0.80),
    "handguard_right": ((0.10, -0.9, 0.10), (1.79, 0, 0.30), 0.80),
    "handguard_front": ((0.35, 0.8, 0.30), (2.10, 0, 0.30), 0.55),
    "handguard_rear": ((-0.30, 0.8, 0.30), (1.45, 0, 0.33), 0.50),
    "handguard_under": ((0.20, 0.6, -0.60), (1.90, 0, 0.17), 0.70),
    "charm_zone": ((0.10, 0.9, 0.05), (1.18, 0, 0.36), 0.60),
    "box_left": ((0.15, 0.9, -0.05), (0.95, 0, -0.12), 0.90),
    "box_right": ((0.15, -0.9, -0.05), (0.95, 0, -0.12), 0.90),
    "box_flange": ((0.30, 0.8, -0.25), (0.95, 0, 0.13), 0.60),
    "butt": ((0.45, 0.8, 0.28), (-1.04, 0, 0.15), 0.85),
    "butt_join": ((0.20, -0.8, 0.30), (-0.96, 0, 0.15), 0.70),
    "marquee": ((-0.30, 0.6, 0.50), (-1.07, 0.09, 0.50), 0.35),
    "stock_art": ((0.10, 0.9, 0.20), (-0.70, 0, 0.30), 0.60),
    "brake": ((0.35, 0.7, 0.35), (3.18, 0, 0.371), 0.55),
    "brake_mount": ((-0.30, 0.6, 0.30), (3.02, 0, 0.371), 0.35),
    "rear_sight": ((-0.35, 0.5, 0.30), (0.02, 0, 0.62), 0.35),
    "front_sight": ((0.30, 0.6, 0.30), (2.43, 0, 0.55), 0.40),
    # Gap sweep (2026-11-27): 20_review shoots culled magenta close-ups of every station; these cover the
    # stock joins from both sides and below.
    "trigger_join": ((0.5, 0.6, -0.35), (0.31, 0, 0.12), 0.42),
    "trigger_join_right": ((0.5, -0.6, -0.35), (0.31, 0, 0.12), 0.42),
    "trigger_join_below": ((0.05, 0.02, -0.9), (0.25, 0, 0.12), 0.60),
    "grip_join": ((-0.6, 0.6, -0.2), (-0.12, 0, 0.12), 0.45),
    "rear_cap_join": ((-0.3, 0.8, 0.3), (-0.25, 0, 0.33), 0.50),
    "rear_cap_join_right": ((-0.3, -0.8, 0.3), (-0.25, 0, 0.33), 0.50),
    "feed_join_below": ((0.05, 0.05, -0.9), (0.95, 0, 0.13), 0.90),
    "handguard_join_right": ((-0.3, -0.8, 0.3), (1.45, 0, 0.33), 0.45),
    "barrel_join": ((-0.3, -0.8, -0.2), (2.35, 0, 0.37), 0.60),
    "rail_join": ((0.3, 0.8, 0.4), (0.35, 0, 0.57), 0.60),
    "box_join_front": ((0.9, 0.4, -0.2), (1.30, 0, 0.12), 0.50),
    "box_join_rear": ((-0.9, 0.4, -0.3), (0.60, 0, 0.12), 0.50),
    "eject_join": ((0.2, -0.8, 0.2), (0.40, 0, 0.35), 0.40),
}
FINISH_EXTRA = ["deck", "joystick", "screen", "coin_door", "handguard_left", "box_left", "butt", "brake",
                "stock_art"]
exec((Path(bpy.data.filepath).parents[6] / "tools/blender/arcade/20_review.py").read_text(encoding="utf-8"))
