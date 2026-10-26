# build_mod_launchpad.py: the Launch Pad (Mod 2, Mobility), a placed jump pad.
#   blender --background --factory-startup --python tools/blender/build_mod_launchpad.py -- [--render]
# A low hexagonal pad, 4.7 studs corner to corner (4.1 flat to flat): charcoal base with dark corner bumpers, an
# energy channel around a dark launch plate (Plate pops up on a launch), three chevrons pointing the launch
# direction (Arrow1..3_Energy, so code can chase them) and a light on each sloped side.
# Origin on the floor at the centre, launch direction +X. See tools/blender/modkit.py.

import os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import math
from modkit import *  # noqa: F401,F403

MOD = "LaunchPad"
ROT = math.pi / 6  # hex corners at 30 + 60k degrees: flat faces front and back
R0, R1, TOP = 2.35, 2.12, 0.32  # base: bottom / top corner radius, height
PLATE_TOP = 0.40


def chevron(tip):
	return [(tip, 0), (tip - 0.6, 0.75), (tip - 0.94, 0.75), (tip - 0.34, 0), (tip - 0.94, -0.75), (tip - 0.6, -0.75)]


def build():
	mats = begin(MOD)

	base = Part("Base")
	base.add(frustum(6, R0, R1, 0, TOP, SHELL, ROT), 0.06, 2)
	for k in range(6):
		a = ROT + k * math.pi / 3
		base.add(place(box(2.04, 2.46, -0.24, 0.24, 0, 0.40, DARK), rot_z(a)), 0.05, 2)  # corner bumpers

	plate = Part("Plate")
	plate.add(frustum(6, 1.80, 1.72, 0.24, PLATE_TOP, DARK, ROT), 0.04, 2)

	rim = Part("Rim_Energy")
	rim.add(band(6, 1.86, 1.98, 0.28, TOP + 0.025, ENERGY, ROT))

	parts = [base, plate, rim]
	for i, tip in enumerate((-0.45, 0.35, 1.15)):
		arrow = Part("Arrow%d_Energy" % (i + 1))
		arrow.add(prism(chevron(tip), "Z", PLATE_TOP - 0.01, PLATE_TOP + 0.03, ENERGY), 0.012, 1)
		parts.append(arrow)

	# One pill light on each sloped side, laid flat on the face.
	side = Part("Side_Energy")
	ap0, ap1 = R0 * math.cos(math.pi / 6), R1 * math.cos(math.pi / 6)  # apothems at the bottom and top
	for k in range(6):
		a = k * math.pi / 3
		out = Vector((math.cos(a), math.sin(a), 0))
		slope = (Vector((0, 0, TOP)) - out * (ap0 - ap1)).normalized()
		tangent = Vector((-math.sin(a), math.cos(a), 0))
		normal = tangent.cross(slope)
		origin = out * (ap0 + ap1) / 2 + Vector((0, 0, TOP / 2)) - normal * 0.004
		m = Matrix((tangent, normal, slope)).transposed().to_4x4()
		m.translation = origin
		side.add(place(prism(stadium(-0.55, 0.55, 0, 0.08), "Y", 0, 0.022, ENERGY), m))
	parts.append(side)

	locators = [
		("Top", (0, 0, PLATE_TOP + 0.03), None),  # launch burst / stand point
	]
	return assemble(MOD, parts, mats, locators, {"kind": "placed", "size_studs": 4.7})


if __name__ == "__main__":
	cli(MOD, build, "launch-pad", look_dir=(1.0, 0.8, 0.85), hover=0.0, zoom=0.78)
