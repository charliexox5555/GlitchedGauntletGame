"""Guardian (Marksman) stations for 20_review.py: every new join and detail gets a close-up."""

from pathlib import Path

import bpy

CENTER = (0.88, 0, 0.12)
WIDTH = 4.6
ADS_DISTANCE = 0.33  # Config/Weapons Guardian.adsDistance (adsFov 58)
# The stock Guardian file has its own Cam_Hip, so no HIP override is needed.
STATIONS = {
    "deck": ((0.15, 0.9, 0.25), (0.45, 0, 0.28), 0.62),
    "joystick": ((-0.30, 0.5, 0.22), (0.33, 0.10, 0.28), 0),
    "deck_top": ((0.10, 0.45, 0.60), (0.45, 0.08, 0.32), 0.42),
    "coin_door": ((0.10, -0.9, 0.20), (0.20, 0, 0.18), 0.62),
    "handguard_front": ((0.35, 0.8, 0.30), (2.22, 0, 0.33), 0.50),
    "handguard_receiver": ((-0.30, 0.8, 0.30), (1.13, 0, 0.30), 0.40),
    "handguard_under": ((0.20, 0.6, -0.60), (1.90, 0, 0.22), 0.75),
    "vents": ((0.10, 0.9, 0.20), (1.45, 0, 0.32), 0.55),
    "charm": ((0.10, 0.8, -0.20), (1.18, 0, 0.22), 0.35),
    "butt": ((-0.60, 0.9, 0.30), (-1.15, 0, 0.13), 0.75),
    "butt_join": ((0.20, -0.8, 0.30), (-1.06, 0, 0.15), 0.60),
    "stock_art": ((0.10, 0.9, 0.30), (-0.58, 0, 0.30), 0.45),
    "brake": ((0.35, 0.7, 0.35), (2.89, 0, 0.368), 0.45),
    "brake_mount": ((-0.30, 0.6, 0.30), (2.78, 0, 0.368), 0.30),
    "mag": ((0.20, 0.9, -0.10), (0.65, 0, -0.08), 0.55),
    "rear_sight": ((-0.35, 0.5, 0.30), (0.14, 0, 0.48), 0.45),
    "front_sight": ((0.30, 0.6, 0.30), (2.26, 0, 0.47), 0.45),
    # Gap sweep (v03): culled magenta close-ups of the stock joins it closed (20_review shoots culled_* of
    # every station). The full three-way sweep is in out/Guardian_v03_gapsweep/.
    "rail_riser_join": ((0.2, 0.8, 0.15), (1.00, 0, 0.41), 0.34),
    "rail_riser_join_right": ((0.2, -0.8, 0.15), (1.00, 0, 0.41), 0.34),
    "front_sight_join": ((0.4, 0.5, 0.25), (2.257, 0, 0.45), 0.20),
    "tube_ring_join": ((0.3, 0.7, 0.2), (-0.02, 0, 0.33), 0.24),
}
FINISH_EXTRA = ["deck", "coin_door", "butt", "brake", "joystick", "stock_art", "handguard_front"]
exec((Path(bpy.data.filepath).parents[6] / "tools/blender/arcade/20_review.py").read_text(encoding="utf-8"))
