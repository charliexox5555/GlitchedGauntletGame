"""Bulldog (Lancer) stations for 20_review.py: every new join and detail gets a close-up."""

from pathlib import Path

import bpy

CENTER = (0.0, 0, 0.17)
WIDTH = 3.35
ADS_DISTANCE = 0.38  # Config/Weapons Bulldog.adsDistance (adsFov 68)
# The stock Bulldog file has its own Cam_Hip, so no HIP override is needed.
STATIONS = {
    "deck": ((0.15, 0.9, 0.25), (-0.79, 0, 0.345), 0.62),
    "joystick": ((-0.30, 0.5, 0.22), (-0.93, 0.10, 0.34), 0),
    "deck_top": ((0.10, 0.45, 0.60), (-0.78, 0.08, 0.40), 0.45),
    "screen": ((0.05, 0.6, 0.10), (-0.68, 0.10, 0.342), 0.30),
    "stock_field_left": ((0.10, 0.9, 0.10), (-0.99, 0, 0.08), 0.55),
    "stock_field_right": ((0.10, -0.9, 0.20), (-0.79, 0, 0.345), 0.62),
    "coin_door": ((0.10, -0.9, 0.10), (-0.99, 0, 0.065), 0.50),
    "handguard_front": ((0.35, 0.8, 0.30), (0.95, 0, 0.25), 0.45),
    "handguard_receiver": ((-0.30, 0.8, 0.30), (0.62, 0, 0.27), 0.40),
    "handguard_under": ((0.20, 0.6, -0.60), (0.82, 0, 0.18), 0.60),
    "butt": ((-0.60, 0.9, 0.30), (-1.31, 0, 0.18), 0.75),
    "butt_join": ((0.20, -0.8, 0.30), (-1.20, 0, 0.18), 0.60),
    "marquee": ((-0.30, 0.6, 0.50), (-1.32, 0.09, 0.45), 0.35),
    "brake": ((0.35, 0.7, 0.35), (1.34, 0, 0.3614), 0.40),
    "brake_mount": ((-0.30, 0.6, 0.30), (1.24, 0, 0.3614), 0.25),
    "mag": ((0.20, 0.9, -0.10), (-0.62, 0, -0.08), 0.55),
    "rear_sight": ((-0.35, 0.5, 0.30), (-0.20, 0, 0.56), 0.45),
    "front_sight": ((0.30, 0.6, 0.30), (0.87, 0, 0.56), 0.45),
    # Stock joins fixed in v03 (the trigger guard's front post, the front sight base): 20_review shoots
    # their culled magenta close-ups with the rest. v03's culled_* of these four came from the same
    # stations in a culled-only pass.
    "trigger_join": ((0.5, 0.6, -0.35), (0.47, 0, 0.16), 0.30),
    "trigger_join_right": ((0.5, -0.6, -0.35), (0.47, 0, 0.16), 0.30),
    "trigger_join_below": ((0.05, 0.02, -0.9), (0.42, 0, 0.14), 0.36),
    "front_sight_join": ((0.4, 0.5, 0.25), (0.87, 0, 0.5), 0.30),
}
FINISH_EXTRA = ["deck", "joystick", "coin_door", "butt", "brake", "stock_field_left", "stock_field_right",
                "handguard_front", "screen"]
exec((Path(bpy.data.filepath).parents[6] / "tools/blender/arcade/20_review.py").read_text(encoding="utf-8"))
