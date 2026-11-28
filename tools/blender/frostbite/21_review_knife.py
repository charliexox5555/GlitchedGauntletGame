"""Knife (Tier 30 chase melee) stations for Frostbite 20_review.py."""

from pathlib import Path

CENTER = (0.40, 0, 0.0)
WIDTH = 1.95
AT = (1.267, 0, 0.0)
ADS_DISTANCE = 1.2
HIP = ((-0.65, 0.48, 0.45), 70)
STATIONS = {
    "blade_left": ((0.15, 0.9, 0.15), (0.78, 0, 0.0), 0.95),
    "blade_right": ((0.15, -0.9, 0.15), (0.78, 0, 0.0), 0.95),
    "guard": ((0.30, 0.7, 0.25), (0.33, 0, 0.0), 0.42),
    "pommel": ((-0.55, 0.6, 0.20), (-0.40, 0, 0.0), 0.35),
    "tip": ((0.45, 0.7, 0.15), (1.12, 0, 0.0), 0.45),
    "edge_under": ((0.10, 0.2, -0.9), (0.65, 0, -0.04), 0.85),
    "grip_join": ((0.15, 0.8, 0.15), (-0.05, 0, 0.0), 0.55),
}
FINISH_EXTRA = ["blade_left", "blade_right", "guard", "pommel", "tip"]
source = (Path(bpy.data.filepath).parents[6] / "tools/blender/frostbite/20_review.py").read_text(encoding="utf-8")
line = 'AT = bpy.data.objects[f"{GUN}_AimPoint"].matrix_world.translation.copy()'
assert line in source
exec(source.replace(line, f"AT = Vector({AT})"))
