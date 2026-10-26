# build_mod_patchup.py: the Patch Up heal device (Mod 7, Sustain), a first-person viewmodel item (Sage-style).
#   blender --background --factory-startup --python tools/blender/build_mod_patchup.py -- [--render]
# A chunky pistol-grip gadget: charcoal housing, an energy vial on top (charge read-out), a medical cross on each
# side, and three claws holding a glowing core at the front where the heal beam leaves.
# Origin at the grip (Handle locator); the beam leaves the Emitter locator along +X. See tools/blender/modkit.py.

import os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import math
from modkit import *  # noqa: F401,F403

MOD = "PatchUp"
AXIS_Z = 0.23  # height of the emitter axis (claws, core, beam)


def plus(cx, cz, arm, t):
	return [(cx - t, cz + arm), (cx + t, cz + arm), (cx + t, cz + t), (cx + arm, cz + t), (cx + arm, cz - t), (cx + t, cz - t), (cx + t, cz - arm), (cx - t, cz - arm), (cx - t, cz - t), (cx - arm, cz - t), (cx - arm, cz + t), (cx - t, cz + t)]


def build():
	mats = begin(MOD)

	grip = Part("Grip")
	grip.add(prism([(-0.16, -0.38), (0.05, -0.38), (0.11, 0.10), (-0.10, 0.10)], "Y", -0.095, 0.095, DARK), 0.035, 2)
	grip.add(box(-0.19, 0.08, -0.11, 0.11, -0.44, -0.36, DARK), 0.03, 2)  # flared base
	grip.add(prism([(0.05, 0.08), (0.12, 0.08), (0.10, -0.02), (0.06, -0.04)], "Y", -0.022, 0.022, TRIM), 0.01, 1)  # trigger
	# Chunky trigger guard (one closed profile).
	grip.add(prism([(0.03, -0.06), (0.27, -0.06), (0.27, 0.09), (0.21, 0.09), (0.21, 0.0), (0.03, 0.0)], "Y", -0.035, 0.035, DARK), 0.018, 2)

	body = Part("Body")
	body.add(prism([(-0.32, 0.08), (0.48, 0.08), (0.56, 0.16), (0.56, 0.30), (0.44, 0.38), (-0.24, 0.38), (-0.32, 0.30)], "Y", -0.14, 0.14, SHELL), 0.05, 3)
	body.add(box(-0.37, -0.29, -0.12, 0.12, 0.12, 0.34, DARK), 0.03, 2)  # rear cap
	body.add(mirror_y(box(-0.24, 0.42, 0.135, 0.152, 0.105, 0.14, TRIM)), 0.006, 1)  # side trim lines
	body.add(mirror_y(box(0.04, 0.22, 0.13, 0.15, 0.135, 0.315, DARK)), 0.02, 2)  # cross plates
	body.add(box(-0.20, 0.34, -0.085, 0.085, 0.36, 0.42, DARK), 0.025, 2)  # vial cradle
	body.add(lathe([(0, 0), (0.125, 0), (0.125, 0.03), (0, 0.03)], 16, DARK, "X", (0.545, 0, AXIS_Z)), 0.008, 1)  # emitter socket

	clamps = Part("Clamps")
	for x in (-0.06, 0.2):
		clamps.add(torus(0.064, 0.015, 12, 5, TRIM, "X", (x, 0, 0.43)))

	claws = Part("Claws")
	claws.add(torus(0.15, 0.034, 20, 6, TRIM, "X", (0.585, 0, AXIS_Z)))  # collar
	for i in range(3):
		# Side profile (x, distance from the axis) of one claw with an inward lip at the tip.
		claw = bevel(prism([(0.55, 0.12), (0.75, 0.12), (0.75, 0.085), (0.835, 0.085), (0.835, 0.185), (0.55, 0.185)], "Y", -0.042, 0.042, SHELL), 0.02, 2)
		claws.add(place(claw, rot_x(i * 2 * math.pi / 3, (0, 0, AXIS_Z))))  # built around the X axis, then raised

	core = Part("Core_Energy")
	core.add(sphere(0.105, 16, 10, ENERGY, "Z", (0.70, 0, AXIS_Z)))

	vial = Part("Vial_Energy")
	vial.add(capsule(0.055, 0.5, 14, 3, ENERGY, "X", (0.07, 0, 0.43)))

	cross = Part("Cross_Energy")
	cross.add(mirror_y(prism(plus(0.13, 0.225, 0.07, 0.024), "Y", 0.148, 0.166, ENERGY)))

	parts = [grip, body, clamps, claws, core, vial, cross]
	locators = [
		("Handle", (0, 0, 0), None),
		("LeftGrip", (-0.02, 0, -0.15), None),
		("Emitter", (0.82, 0, AXIS_Z), Matrix.Identity(4)),
	]
	return assemble(MOD, parts, mats, locators, {"kind": "handheld", "size_studs": 1.2})


if __name__ == "__main__":
	cli(MOD, build, "patch-up", look_dir=(0.55, 1.0, 0.42), hover=0.3)
