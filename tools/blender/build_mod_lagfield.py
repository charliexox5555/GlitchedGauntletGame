# build_mod_lagfield.py: the Lag Field orb (Mod 5, Control), thrown; it opens the slowing zone where it lands.
#   blender --background --factory-startup --python tools/blender/build_mod_lagfield.py -- [--render]
# A 0.6-stud orb: two charcoal caps with glowing lens domes (Core_Energy, top and bottom so it reads however it
# lands), trim bezels, and a dark belt carrying a ring of eight shrinking dots, a "buffering" spinner
# (Spinner_Energy; code spins it). Origin at the centre (Handle locator). See tools/blender/modkit.py.

import os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import math
from modkit import *  # noqa: F401,F403

MOD = "LagField"
FLIP = Matrix.Diagonal((1, 1, -1, 1))  # mirror top -> bottom (place() fixes the normals)


def both(bm):
	return group(bm, place(copy(bm), FLIP))


def build():
	mats = begin(MOD)

	shell = Part("Caps")
	cap = lathe([(0, 0.24), (0.13, 0.24), (0.13, 0.285), (0.2, 0.262), (0.255, 0.215), (0.29, 0.15), (0.302, 0.09), (0.296, 0.058), (0.0, 0.058)], 24, SHELL)
	shell.add(both(cap))
	shell.add(band(24, 0.235, 0.288, -0.062, 0.062, DARK), 0.012, 2)  # belt

	bezel = Part("Bezels")
	bezel.add(both(torus(0.136, 0.02, 20, 6, TRIM, "Z", (0, 0, 0.283))))

	core = Part("Core_Energy")
	core.add(both(lathe([(0, 0.24), (0.124, 0.24), (0.124, 0.27), (0.1, 0.298), (0.055, 0.316), (0, 0.321)], 20, ENERGY)))

	spinner = Part("Spinner_Energy")
	for i in range(8):
		h = 0.034 * (1 - i * 0.075)
		dot = box(0.282, 0.302, -h, h, -h, h, ENERGY)
		spinner.add(place(dot, rot_z(-i * math.pi / 4)), 0.012, 2)

	locators = [("Handle", (0, 0, 0), None)]
	return assemble(MOD, [shell, bezel, core, spinner], mats, locators, {"kind": "thrown", "size_studs": 0.64})


if __name__ == "__main__":
	cli(MOD, build, "lag-field", look_dir=(0.9, 1.0, 0.7), hover=0.25)
