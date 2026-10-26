# build_mod_firewall.py: the Firewall (Mod 4, Defense), a placed 8 x 6 stud bullet-blocking wall.
#   blender --background --factory-startup --python tools/blender/build_mod_firewall.py -- [--render]
# Two chunky emitter pylons on wide feet with a low sill between them (Frame), energy strips on the pylons and the
# sill (Frame_Energy), and one flat translucent panel (Panel_Energy) with 0-1 UVs on both faces for a scrolling
# texture. The panel is a separate part so code can build it up, flicker it on hits and shatter it.
# Origin on the floor at the centre; the wall spans Y (-4..4) and faces +X. See tools/blender/modkit.py.

import os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from modkit import *  # noqa: F401,F403

MOD = "Firewall"
YC = 3.58  # pylon centre
W = 0.4  # pylon half-width
PY, PZ0, PZ1 = 3.12, 0.26, 5.55  # panel half-width and height range


def panel_uv(bm, layer):
	# Front (+X) and back faces: u across, v up, each read the right way round from its own side.
	for f in bm.faces:
		back = f.normal.x < -0.5
		for loop in f.loops:
			co = loop.vert.co
			u = (co.y + PY) / (2 * PY)
			v = (co.z - PZ0) / (PZ1 - PZ0)
			loop[layer].uv = (1 - u if not back else u, v)


def build():
	mats = begin(MOD)

	frame = Part("Frame")
	glow = Part("Frame_Energy")
	for s in (1, -1):
		yc = s * YC
		yi = yc - s * W  # inner face of the pylon
		frame.add(box(-0.75, 0.75, yc - 0.55, yc + 0.55, 0, 0.38, DARK), 0.1, 2)  # foot
		frame.add(prism([(-0.48, 0.25), (0.48, 0.25), (0.36, 1.3), (0.36, 5.62), (-0.36, 5.62), (-0.36, 1.3)], "Y", yc - W, yc + W, SHELL), 0.09, 2)  # pylon
		frame.add(box(-0.24, 0.24, min(yc + s * (W - 0.02), yc + s * (W + 0.07)), max(yc + s * (W - 0.02), yc + s * (W + 0.07)), 1.0, 4.9, DARK), 0.035, 2)  # outer armour
		frame.add(box(-0.5, 0.5, yc - 0.5, yc + 0.5, 5.55, 6.0, DARK), 0.12, 2)  # cap
		frame.add(box(-0.15, 0.15, min(yi, yi - s * 0.07), max(yi, yi - s * 0.07), 0.3, 5.58, DARK), 0.025, 1)  # emitter rail
		glow.add(box(-0.065, 0.065, min(yi - s * 0.07, yi - s * 0.1), max(yi - s * 0.07, yi - s * 0.1), 0.4, 5.48, ENERGY))
		for x in (0.36, -0.36):  # front and back strips
			glow.add(box(min(x, x * 1.08), max(x, x * 1.08), yc - 0.09, yc + 0.09, 1.5, 4.9, ENERGY), 0.008, 1)
		glow.add(mirror_x_box(0.5, 0.52, yc - 0.24, yc + 0.24, 5.72, 5.84))
	frame.add(box(-0.24, 0.24, -YC + 0.3, YC - 0.3, 0, 0.24, DARK), 0.05, 2)  # sill
	glow.add(box(-0.05, 0.05, -YC + 0.3, YC - 0.3, 0.23, 0.27, ENERGY))

	panel = Part("Panel_Energy", uv=panel_uv)
	panel.add(box(-0.035, 0.035, -PY, PY, PZ0, PZ1, GLASS))

	locators = [
		("Center", (0, 0, (PZ0 + PZ1) / 2), None),  # middle of the panel (hit / shatter FX)
	]
	return assemble(MOD, [frame, glow, panel], mats, locators, {"kind": "placed", "size_studs": "8x6"})


def mirror_x_box(x0, x1, y0, y1, z0, z1):
	# A small energy pill on both the front and back face of a cap.
	return group(box(x0, x1, y0, y1, z0, z1, ENERGY), box(-x1, -x0, y0, y1, z0, z1, ENERGY))


if __name__ == "__main__":
	cli(MOD, build, "firewall", look_dir=(1.0, 0.62, 0.32), hover=0.0, lens=42)
