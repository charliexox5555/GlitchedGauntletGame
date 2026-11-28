"""Classic stations for Frostbite 20_review.py."""

from pathlib import Path

import bpy

CENTER = (0.38, 0, 0.07)
WIDTH = 2.45
AT = (0.935, 0, 0.509)
ADS_DISTANCE = 1.2
HIP = ((-1.097, 0.580, 0.818), 80)
STATIONS = {
    "core_left": ((0.10, 0.9, 0.15), (0.05, 0, 0.224), 0.45),
    "grip_right": ((0.10, -0.9, 0.10), (0.0, 0, -0.09), 0.40),
    "slide_art": ((0.10, 0.9, 0.15), (0.49, 0, 0.38), 0.60),
    "muzzle": ((0.60, 0.5, 0.15), (1.0, 0, 0.36), 0.30),
    "charm_zone": ((0.20, 0.8, -0.25), (0.74, 0, 0.20), 0.45),
    "mag": ((0.20, 0.9, -0.15), (0.0, 0, -0.34), 0.45),
    "guard_grip_left": ((0.3, 0.8, -0.2), (0.24, 0, 0.09), 0.30),
    "base_join": ((0.2, 0.8, -0.3), (0.0, 0, -0.30), 0.40),
}
FINISH_EXTRA = ["core_left", "grip_right", "slide_art", "muzzle", "charm_zone"]
source = (Path(bpy.data.filepath).parents[6] / "tools/blender/frostbite/20_review.py").read_text(encoding="utf-8")
line = 'AT = bpy.data.objects[f"{GUN}_AimPoint"].matrix_world.translation.copy()'
assert line in source
exec(source.replace(line, f"AT = Vector({AT})"))
