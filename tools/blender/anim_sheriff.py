# anim_sheriff.py: the Sheriff's clips as NLA tracks (Fire, Reload, ReloadEmpty, Draw, Inspect). Run after
# build_sheriff.py (tools/blender/finish_gun.py does it headless).
#
# Double-action revolver: the trigger pull rocks the hammer back and drops it, then the cylinder indexes one
# chamber (60 degrees about X; it's six-fold symmetric, so a clip may end on a multiple of 60 and look like rest).
# Reload: thumb the release, the crane swings the cylinder out to the left (Crane X rotation negative), muzzle up,
# the ejector rod's star kicks the six cases out (Rounds leave and fall away), the speedloader brings fresh Rounds
# in from below, twists, pulls away empty, the cylinder is flicked shut. The left hand follows the Cylinder
# (RELOAD_FOLLOW). Partial reloads use the same clip (all six chambers are refilled).

import bpy, importlib, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gunkit

importlib.reload(gunkit)
from gunkit import Clip, swing

GUN = "Sheriff"
FPS = 24
OPEN = -82  # crane swing (degrees about X)


def fire():
	c = Clip(GUN, "Fire", 14)
	c.key("Trigger", 1)
	c.key("Trigger", 2, rot=(0, 18, 0))
	c.key("Trigger", 4, rot=(0, 18, 0))
	c.key("Trigger", 7)
	c.key("Hammer", 1)
	c.key("Hammer", 2, rot=(0, -28, 0))  # rocked back by the pull...
	c.key("Hammer", 3)  # ...and dropped
	c.key("Cylinder", 3)
	c.key("Cylinder", 7, rot=(60, 0, 0))
	c.key("Cylinder", 14, rot=(60, 0, 0))  # one chamber on: looks the same as rest
	c.key("Root", 3, (-0.05, 0, 0.02), (0, -11, 1))
	c.key("Root", 4, (-0.06, 0, 0.025), (0, -13, 1.2))
	c.key("Root", 6, (-0.03, 0, 0.012), (0, -6, 0.5))
	c.key("Root", 9, (-0.006, 0, 0.002), (0, -1, 0))
	c.key("Root", 11, (0.003, 0, 0), (0, 0.5, 0))
	c.key("Root", 13)
	swing(c, [(4, 14), (6, -9), (8, 5), (10, -2.5), (13, 0.8)])
	return c


def reload_clip(name):
	L = 110
	c = Clip(GUN, name, L)
	c.key("CylinderRelease", 3)
	c.key("CylinderRelease", 5, (0.012, 0, 0))
	c.key("CylinderRelease", 9)
	c.key("Crane", 5)
	c.key("Crane", 10, rot=(OPEN - 6, 0, 0))
	c.key("Crane", 12, rot=(OPEN, 0, 0))
	c.key("Crane", 66, rot=(OPEN, 0, 0))
	c.key("Crane", 70, rot=(3, 0, 0))  # flicked shut
	c.key("Crane", 72)
	# Muzzle up to dump the cases, back down to load, level to close.
	c.key("Root", 4, (0, 0, 0.01), (8, -2, 3))
	c.key("Root", 12, (0, 0, 0.04), (14, -35, 6))
	c.key("Root", 24, (0, 0, 0.05), (16, -48, 6))
	c.key("Root", 34, (0, 0, 0.03), (18, 14, 4))
	c.key("Root", 50, (0, 0, 0.035), (20, 18, 4))
	c.key("Root", 62, (0, 0, 0.02), (12, 6, 3))
	c.key("Root", 70, (0.012, 0, 0.012), (6, -3, 2))
	c.key("Root", 76, (0, 0, 0.002), (1.5, 0.5, 0.4))
	c.key("Root", 90)
	# Ejector rod pushed rearward: the star kicks the cases out; the rod springs back.
	c.key("EjectorRod", 17)
	c.key("EjectorRod", 21, (-0.09, 0, 0))
	c.key("EjectorRod", 23, (-0.09, 0, 0))
	c.key("EjectorRod", 26)
	c.key("Rounds", 17)
	c.key("Rounds", 21, (-0.09, 0, 0))
	c.key("Rounds", 25, (-0.3, 0, -0.12), (0, 0, 20))
	c.key("Rounds", 31, (-0.6, 0, -0.7), (0, 0, 60))  # gone (out of view)
	# Speedloader brings the fresh rounds up from below, pushes them in, twists, pulls away empty.
	for b in ("Rounds", "Speedloader"):
		c.key(b, 36, (-0.55, 0, -0.55), (0, 20, 0))
		c.key(b, 45, (-0.16, 0, -0.01), (0, 2, 0))
		c.key(b, 49)
	c.key("Speedloader", 51, rot=(25, 0, 0))  # twist to release
	c.key("Speedloader", 53, (-0.12, 0, 0), (25, 0, 0))
	c.key("Speedloader", 58, (-0.5, 0, -0.5), (25, 0, 0))
	c.key("Speedloader", 66, (-0.5, 0, -0.5), (25, 0, 0))
	c.key("Speedloader", 67)  # back inside the closed cylinder, hidden
	c.key("Rounds", 50)
	swing(c, [(10, -8), (14, 6), (22, 9), (27, -6), (34, 5), (48, -4), (70, 10), (74, -6), (78, 3)])
	return c


def draw():
	# Snapped up with a quick spin of the cylinder (two chambers) against the palm.
	c = Clip(GUN, "Draw", 24)
	c.key("Cylinder", 6)
	c.key("Cylinder", 14, rot=(120, 0, 0))
	c.key("Cylinder", 24, rot=(120, 0, 0))
	c.key("Root", 4, (0, 0, 0.004), (7, 0, -5))
	c.key("Root", 10, (0, 0, 0.008), (10, -1, -7))
	c.key("Root", 16, (0, 0, 0.003), (4, 0.5, -3))
	c.key("Root", 21)
	swing(c, [(5, 6), (9, -4), (14, 7), (18, -4), (22, 1.5)])
	return c


def inspect():
	# Left side (60-82%): swing the cylinder out, spin it, flick it shut.
	c = Clip(GUN, "Inspect", 67)
	c.key("CylinderRelease", 36)
	c.key("CylinderRelease", 38, (0.012, 0, 0))
	c.key("CylinderRelease", 41)
	c.key("Crane", 38)
	c.key("Crane", 43, rot=(OPEN * 0.8 - 5, 0, 0))
	c.key("Crane", 45, rot=(OPEN * 0.8, 0, 0))
	c.key("Crane", 55, rot=(OPEN * 0.8, 0, 0))
	c.key("Crane", 58, rot=(3, 0, 0))
	c.key("Crane", 60)
	c.key("Cylinder", 45)
	c.key("Cylinder", 53, rot=(300, 0, 0))
	c.key("Cylinder", 67, rot=(300, 0, 0))
	c.key("Root", 57, (0, 0, 0))
	c.key("Root", 58, (0.008, 0, 0.004), (0, -2, 0))
	c.key("Root", 61)
	swing(c, [(6, 8), (11, -6), (16, 5), (21, -3), (30, 2), (42, -8), (46, 7), (52, -4), (58, 9), (62, -5), (66, 2)])
	return c


def animate():
	bpy.context.scene.render.fps = FPS
	out = {}
	for clip in (fire(), reload_clip("Reload"), reload_clip("ReloadEmpty"), draw(), inspect()):
		clip.bake()
		out[clip.name] = {"frames": clip.last, "bones": sorted(clip.keys)}
	bpy.context.scene.frame_set(1)
	return out


if __name__ == "__main__":
	print(animate())
