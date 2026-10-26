# build_mod_packet.py: the Packet grenade (Mod 3, Damage), held in first person and thrown.
#   blender --background --factory-startup --python tools/blender/build_mod_packet.py -- [--render]
# A chunky rounded "data packet" cube: charcoal shell, a dark belt with four energy windows, a fuse dome on top
# (Fuse_Energy, blinks before the blast), a spoon lever and a pin ring that come off on the throw.
# Origin at the centre (Handle locator, held in the palm). See tools/blender/modkit.py for conventions.

import os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import math
from modkit import *  # noqa: F401,F403

MOD = "Packet"
H = 0.2  # half the cube's side: the body is 0.4 studs (0.56 with fuse and lever)


def build():
	mats = begin(MOD)

	body = Part("Body")
	body.add(box(-H, H, -H, H, -H, H, SHELL), 0.075, 4)
	# Raised corner plates on the left/right faces give the cube a front/back read.
	for s in (1, -1):
		body.add(box(-0.13, 0.13, s * H - 0.012, s * H + 0.014, 0.07, 0.165, TRIM), 0.01, 2)
	# Bottom foot.
	body.add(lathe([(0, -H - 0.02), (0.1, -H - 0.02), (0.12, -H + 0.01), (0, -H + 0.01)], 8, DARK, rot=math.pi / 8), 0.01, 1)

	belt = Part("Belt")
	belt.add(box(-H - 0.018, H + 0.018, -H - 0.018, H + 0.018, -0.055, 0.035, DARK), 0.025, 3)

	windows = Part("Windows_Energy")
	# Two "bit" windows per side; the lever runs down between the pair on the front.
	for a in range(4):
		for y0, y1 in ((-0.165, -0.06), (0.06, 0.165)):
			w = box(H + 0.012, H + 0.026, y0, y1, -0.038, 0.018, ENERGY)
			windows.add(place(w, rot_z(a * math.pi / 2)), 0.01, 2)

	cap = Part("Cap")
	cap.add(lathe([(0, H - 0.01), (0.12, H - 0.01), (0.125, H + 0.03), (0.105, H + 0.055), (0, H + 0.055)], 16, DARK), 0.008, 1)
	cap.add(lathe([(0.075, H + 0.05), (0.095, H + 0.05), (0.095, H + 0.075), (0.075, H + 0.075)], 16, TRIM), 0.004, 1)

	fuse = Part("Fuse_Energy")
	fuse.add(lathe([(0, H + 0.05)] + [(0.072 * math.cos(a), H + 0.06 + 0.06 * math.sin(a)) for a in (0, 0.4, 0.8, 1.2)] + [(0, H + 0.12)], 16, ENERGY))

	lever = Part("Lever")
	lever.add(prism([(0.06, H + 0.07), (0.12, H + 0.07), (H + 0.055, H - 0.02), (H + 0.055, -0.07), (H + 0.03, -0.09), (H + 0.03, H - 0.035), (0.11, H + 0.04), (0.06, H + 0.04)], "Y", -0.038, 0.038, TRIM), 0.012, 2)

	pin = Part("Pin")
	pin.add(torus(0.045, 0.011, 14, 6, TRIM, "X", (0.1, 0.12, H + 0.06)))
	pin.add(box(0.07, 0.13, 0.0, 0.085, H + 0.045, H + 0.07, TRIM), 0.006, 1)

	parts = [body, belt, windows, cap, fuse, lever, pin]
	locators = [
		("Handle", (0, 0, 0), None),
		("Fuse", (0, 0, H + 0.12), None),
	]
	return assemble(MOD, parts, mats, locators, {"kind": "thrown", "size_studs": 0.56})


if __name__ == "__main__":
	cli(MOD, build, "packet", look_dir=(0.9, 1.0, 0.6), hover=0.25)
