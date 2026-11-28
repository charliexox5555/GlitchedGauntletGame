"""Guardian (Marksman) stations for Frostbite 20_review.py."""

from pathlib import Path

CENTER = (0.88, 0, 0.12)
WIDTH = 4.6
ADS_DISTANCE = 0.33
STATIONS = {
    "core_left": ((0.15, 0.9, 0.25), (0.45, 0, 0.28), 0.62),
    "core_right": ((0.10, -0.9, 0.20), (0.45, 0, 0.25), 0.62),
    "fore_left": ((0.35, 0.8, 0.30), (1.75, 0, 0.32), 0.85),
    "fore_receiver": ((-0.30, 0.8, 0.30), (1.13, 0, 0.30), 0.45),
    "fore_under": ((0.20, 0.6, -0.60), (1.70, 0, 0.22), 0.75),
    "charm": ((0.10, 0.8, -0.20), (1.18, 0, 0.22), 0.35),
    "butt": ((-0.60, 0.9, 0.30), (-1.15, 0, 0.13), 0.75),
    "butt_join": ((0.20, -0.8, 0.30), (-1.06, 0, 0.15), 0.60),
    "brake": ((0.35, 0.7, 0.35), (2.89, 0, 0.368), 0.45),
    "brake_mount": ((-0.30, 0.6, 0.30), (2.78, 0, 0.368), 0.30),
    "mag": ((0.20, 0.9, -0.10), (0.65, 0, -0.08), 0.55),
    "rail_riser_join": ((0.2, 0.8, 0.15), (1.00, 0, 0.41), 0.34),
    "front_sight_join": ((0.4, 0.5, 0.25), (2.257, 0, 0.45), 0.22),
    "tube_ring_join": ((0.3, 0.7, 0.2), (-0.02, 0, 0.33), 0.24),
}
FINISH_EXTRA = ["core_left", "fore_left", "butt", "brake", "mag"]
exec((Path(bpy.data.filepath).parents[6] / "tools/blender/frostbite/20_review.py").read_text(encoding="utf-8"))
