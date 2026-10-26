# anim_bucky.py: the Bucky's clips as NLA tracks. Run after build_bucky.py (tools/blender/finish_gun.py does it
# headless). Built from the shared blocks in tools/blender/gunkit.py.
#
#   Fire          kick, then pump back (ejects) and forward; the Bolt rides the pump
#   ReloadStart   roll the loading port toward the player (ends in the loading pose)
#   ReloadInsert  one shell from below, up into the port and forward into the tube (loading pose at both ends);
#                 the game loops it once per shell and can stop between inserts (interrupted reload)
#   ReloadEnd     back to the hold from the loading pose, no pump (the chamber is already loaded)
#   Reload        a complete one-shell reload (start, insert, end) for code without the loop
#   ReloadEmpty   start, one shell, pump to chamber it, end
#   Draw          rack the pump    Inspect   half-pump press check
#
# The support hand (LeftGrip) is on the Pump, so it rides it exactly. During inserts the hand should follow the
# "Shell" prop (needs a RELOAD_FOLLOW rule { joint = "Shell", grab = "Center" }).

import bpy, importlib, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gunkit

importlib.reload(gunkit)
from gunkit import Clip, kick, swing, trigger_pull

GUN = "Bucky"
FPS = 24
TRAVEL = 0.26  # pump / bolt travel
LOAD_POSE = ((0, 0, 0.03), (-22, -10, 6))  # Root: roll the bottom toward the player, muzzle up a little


def pump(c, f0, travel=TRAVEL, hold=1):
	# Pump back (f0 .. f0 + 3), forward (.. f0 + 6 + hold), with the bolt.
	for b in ("Pump", "Bolt"):
		c.key(b, f0)
		c.key(b, f0 + 3, (-travel, 0, 0))
		c.key(b, f0 + 3 + hold, (-travel, 0, 0))
		c.key(b, f0 + 6 + hold, (0.004, 0, 0))
		c.key(b, f0 + 7 + hold)


def fire():
	c = Clip(GUN, "Fire", 20)
	kick(c, back=0.08, climb=6.5, roll=0.7, last=20)
	trigger_pull(c, 16)
	pump(c, 7)
	c.key("Root", 10, (-0.012, 0, 0.004), (0, -0.8, 0))  # the pump jerks the gun back a little
	return c


def insert(c, f0):
	# One shell: from below (out of view), under the port, pushed up and forward into the tube (f0 .. f0 + 12).
	c.key("Shell", f0, (0.05, 0, -0.42), (0, 25, 0))
	c.key("Shell", f0 + 6, (0, 0, -0.07), (0, 4, 0))
	c.key("Shell", f0 + 9)
	c.key("Shell", f0 + 12, (0.16, 0, 0.004))
	c.key("Shell", f0 + 13)
	swing(c, [(f0 + 10, 4), (f0 + 13, -3), (f0 + 16, 1.5)])


def hold_pose(c, *frames):
	for f in frames:
		c.key("Root", f, *LOAD_POSE)


def reload_start():
	c = Clip(GUN, "ReloadStart", 12)
	c.key("Root", 5, (0, 0, 0.015), (-12, -6, 3))
	hold_pose(c, 10, 12)
	swing(c, [(5, 6), (9, -4), (12, 2)])
	return c


def reload_insert():
	c = Clip(GUN, "ReloadInsert", 16)
	hold_pose(c, 1, 8, 16)
	c.key("Root", 10, (0.004, 0, 0.034), (-23, -11, 6))  # thumb pushes the shell home
	insert(c, 1)
	return c


def reload_end():
	c = Clip(GUN, "ReloadEnd", 14)
	hold_pose(c, 1)
	c.key("Root", 6, (0, 0, 0.012), (-8, -3, 2))
	c.key("Root", 11, (0, 0, 0.002), (-1, 0.3, 0.2))
	swing(c, [(5, -6), (9, 4), (13, -1.5)])
	return c


def reload_single():
	c = Clip(GUN, "Reload", 60)
	c.key("Root", 5, (0, 0, 0.015), (-12, -6, 3))
	hold_pose(c, 10, 26)
	insert(c, 12)
	c.key("Root", 22, (0.004, 0, 0.034), (-23, -11, 6))
	c.key("Root", 40, (0, 0, 0.012), (-8, -3, 2))
	c.key("Root", 50, (0, 0, 0.002), (-1, 0.3, 0.2))
	return c


def reload_empty():
	c = Clip(GUN, "ReloadEmpty", 86)
	c.key("Root", 5, (0, 0, 0.015), (-12, -6, 3))
	hold_pose(c, 10, 26)
	insert(c, 12)
	c.key("Root", 22, (0.004, 0, 0.034), (-23, -11, 6))
	c.key("Root", 40, (0, 0, 0.01), (-4, -2, 1))  # back to the hold to rack
	pump(c, 52, hold=2)
	c.key("Root", 55, (-0.02, 0, 0.008), (-2, -2.5, 0.5))
	c.key("Root", 60, (0.012, 0, 0.003), (-1, 0.5, 0.2))
	c.key("Root", 72, (0, 0, 0.001), (-0.3, 0, 0))
	swing(c, [(55, -6), (60, 9), (64, -4.5), (68, 2)])
	return c


def draw():
	c = Clip(GUN, "Draw", 31)
	c.key("Root", 8, (0, 0, 0), (6, 0, -5))
	c.key("Root", 12, (0, 0, 0.005), (8, -1, -6))
	c.key("Root", 15, (-0.03, 0, 0.008), (9, -2, -7))
	c.key("Root", 18, (0.02, 0, 0.004), (5, 1.5, -4.5))
	c.key("Root", 25, (0, 0, 0), (0.8, 0, -0.6))
	pump(c, 11, hold=1)
	swing(c, [(5, -5), (9, 4), (14, -6), (18, 8), (21, -5), (25, 2)])
	return c


def inspect():
	c = Clip(GUN, "Inspect", 67)
	for b in ("Pump", "Bolt"):
		c.key(b, 42)
		c.key(b, 46, (-TRAVEL * 0.4, 0, 0))
		c.key(b, 51, (-TRAVEL * 0.4, 0, 0))
		c.key(b, 54)
	c.key("Root", 54, (0, 0, 0))
	c.key("Root", 55, (0.006, 0, 0), (0, 0.4, 0))
	c.key("Root", 57)
	swing(c, [(6, 9), (11, -7), (16, 6), (21, -3), (28, 2), (36, -9), (41, 11), (46, -6), (52, 5), (57, -3), (62, 1.5)])
	return c


def animate():
	bpy.context.scene.render.fps = FPS
	out = {}
	for clip in (fire(), reload_single(), reload_empty(), reload_start(), reload_insert(), reload_end(), draw(), inspect()):
		clip.bake()
		out[clip.name] = {"frames": clip.last, "bones": sorted(clip.keys)}
	bpy.context.scene.frame_set(1)
	return out


if __name__ == "__main__":
	print(animate())
