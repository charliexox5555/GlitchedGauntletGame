"""Ghost (Hush) stations for Frostbite 20_review.py."""

from pathlib import Path

CENTER = (0.90, 0, 0.0)
WIDTH = 2.65
AT = (1.042, 0, 0.424)
ADS_DISTANCE = 1.2
HIP = ((-1.097, 0.580, 0.818), 80)
STATIONS = {
    "core_left": ((0.10, 0.9, 0.15), (0.09, 0, 0.178), 0.42),
    "grip_right": ((0.10, -0.9, 0.10), (-0.01, 0, -0.115), 0.36),
    "slide_art": ((0.10, 0.9, 0.15), (0.45, 0, 0.30), 0.70),
    "can": ((0.30, 0.9, 0.35), (1.60, 0, 0.30), 1.00),
    "charm_zone": ((0.20, 0.8, -0.25), (0.86, 0, 0.18), 0.40),
    "mag": ((0.20, 0.9, -0.15), (-0.07, 0, -0.43), 0.45),
    "can_join": ((0.25, 0.6, 0.15), (1.13, 0, 0.30), 0.35),
    "guard_front_left": ((0.5, 0.7, -0.3), (0.68, 0, 0.10), 0.30),
}
FINISH_EXTRA = ["core_left", "slide_art", "can", "charm_zone", "mag"]
source = (Path(bpy.data.filepath).parents[6] / "tools/blender/frostbite/20_review.py").read_text(encoding="utf-8")
line = 'AT = bpy.data.objects[f"{GUN}_AimPoint"].matrix_world.translation.copy()'
assert line in source
exec(source.replace(line, f"AT = Vector({AT})"))
