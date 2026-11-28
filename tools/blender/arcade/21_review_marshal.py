"""Marshal (Scout) stations for 20_review.py: every new join and detail gets a close-up, plus the stock joins
for the gap sweep (20_review shoots culled_* magenta close-ups of every station)."""

from pathlib import Path

import bpy

CENTER = (0.97, 0, -0.02)
WIDTH = 4.8
ADS_DISTANCE = 0.70  # no Config/Weapons Marshal.adsDistance (scoped): Viewmodel ADS_DISTANCE
# The stock Marshal file has its own Cam_Hip, so no HIP override is needed.
STATIONS = {
    # Arcade parts
    "deck": ((0.15, 0.9, 0.2), (0.49, 0, 0.10), 0.85),
    "joystick": ((-0.30, 0.5, 0.2), (0.33, 0.08, 0.09), 0),
    "deck_top": ((0.10, 0.45, 0.6), (0.49, 0.07, 0.18), 0.5),
    "coin_door": ((0.10, -0.9, 0.15), (0.36, 0, 0.12), 0.6),
    "forend": ((0.20, 0.9, 0.2), (1.40, 0, 0.09), 1.2),
    "forend_right": ((0.20, -0.9, 0.2), (1.40, 0, 0.09), 1.2),
    "forend_front": ((0.35, 0.7, -0.2), (1.86, 0, 0.10), 0.45),
    "forend_under": ((0.20, 0.5, -0.7), (1.40, 0, 0.0), 1.1),
    "charm": ((0.10, 0.8, -0.2), (0.82, 0, -0.03), 0.35),
    "butt": ((-0.60, 0.9, 0.3), (-1.22, 0, -0.10), 0.75),
    "butt_join": ((0.30, -0.8, 0.3), (-1.19, 0, -0.10), 0.55),
    "butt_under": ((0.20, 0.5, -0.8), (-1.20, 0, -0.20), 0.5),
    "stock_art": ((0.10, 0.9, 0.2), (-0.75, 0, -0.03), 0.45),
    "muzzle": ((0.35, 0.7, 0.35), (3.16, 0, 0.205), 0.35),
    "muzzle_front": ((0.80, 0.3, 0.15), (3.20, 0, 0.205), 0.25),
    # Gap sweep: joins, each from the side and from below (culled_* on magenta)
    "forend_receiver": ((-0.30, 0.8, -0.2), (0.88, 0, 0.08), 0.40),
    "forend_receiver_right": ((-0.30, -0.8, -0.2), (0.88, 0, 0.08), 0.40),
    "forend_band": ((0.20, 0.8, -0.1), (1.92, 0, 0.12), 0.40),
    "muzzle_sight_join": ((-0.20, 0.6, 0.3), (3.10, 0, 0.24), 0.22),
    "trigger_guard": ((0.10, 0.8, -0.2), (0.30, 0, -0.10), 0.60),
    "trigger_guard_right": ((0.10, -0.8, -0.2), (0.30, 0, -0.10), 0.60),
    "lever_under": ((0.10, 0.3, -0.8), (0.30, 0, -0.10), 0.70),
    "wrist": ((-0.20, 0.8, 0.2), (0.12, 0, 0.12), 0.40),
    "wrist_right": ((-0.20, -0.8, 0.2), (0.12, 0, 0.12), 0.40),
    "loading_gate": ((0.15, -0.7, -0.35), (0.40, 0, 0.04), 0.45),
    "scope_mounts": ((0.10, 0.8, 0.3), (0.60, 0, 0.27), 0.60),
    "front_band": ((0.20, 0.8, -0.1), (3.00, 0, 0.15), 0.35),
}
FINISH_EXTRA = ["deck", "joystick", "coin_door", "forend", "butt", "muzzle", "forend_front"]
exec((Path(bpy.data.filepath).parents[6] / "tools/blender/arcade/20_review.py").read_text(encoding="utf-8"))
