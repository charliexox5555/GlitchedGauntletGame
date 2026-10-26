# anim_marshal.py: the Marshal's clips as NLA tracks. Run after build_marshal.py (tools/blender/finish_gun.py does
# it headless). Built from the shared blocks in tools/blender/gunkit.py.
#
#   Fire          kick, then the lever cycle: lever down (bolt back, hammer cocked, case out), lever up
#   ReloadStart   roll the right-side loading gate up toward the player (ends in the loading pose)
#   ReloadInsert  one round pushed into the gate and forward into the tube (loading pose at both ends; looped)
#   ReloadEnd     back to the hold, no cycle
#   Reload        one complete round (start, insert, end)    ReloadEmpty   one round, then a lever cycle
#   Draw          a lever cycle    Inspect   half-open press check
#
# Lever: negative rotation about Y swings the loop down. The trigger hand works the lever, so Fire needs a right-hand
# follow on "Lever" (like BOLT_FOLLOW on bolt-action guns); inserts want a left-hand follow on "Shell".

import bpy, importlib, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gunkit

importlib.reload(gunkit)
from gunkit import Clip, kick, swing, trigger_pull

GUN = "Marshal"
FPS = 24
OPEN = -48  # lever swing
BOLT = 0.16  # bolt travel
LOAD_POSE = ((0, 0, 0.03), (-26, -8, 8))  # Root: right side (the gate) up toward the player


def lever_cycle(c, f0, hold=1):
	# Lever down (f0 .. f0 + 3), hold, back up (.. f0 + 6 + hold); bolt and hammer follow.
	c.key("Lever", f0)
	c.key("Lever", f0 + 3, rot=(0, OPEN, 0))
	c.key("Lever", f0 + 3 + hold, rot=(0, OPEN, 0))
	c.key("Lever", f0 + 6 + hold, rot=(0, 2, 0))
	c.key("Lever", f0 + 7 + hold)
	c.key("Bolt", f0)
	c.key("Bolt", f0 + 3, (-BOLT, 0, 0))
	c.key("Bolt", f0 + 3 + hold, (-BOLT, 0, 0))
	c.key("Bolt", f0 + 6 + hold)
	c.key("Hammer", f0)
	c.key("Hammer", f0 + 2, rot=(0, -32, 0))  # cocked by the bolt and stays back
	c.key("Hammer", f0 + 7 + hold, rot=(0, -32, 0))


def fire():
	c = Clip(GUN, "Fire", 22)
	kick(c, back=0.08, climb=6, roll=0.5, last=22)
	trigger_pull(c, 15)
	c.key("Hammer", 1, rot=(0, -32, 0))  # starts cocked...
	c.key("Hammer", 2)  # ...falls on the shot
	lever_cycle(c, 9, hold=2)
	c.key("Hammer", 22, rot=(0, -32, 0))
	c.key("Root", 12, (-0.012, 0, -0.004), (0, 1, 0))  # the lever throw dips the gun
	return c


def insert(c, f0):
	c.key("Shell", f0, (0.02, -0.42, -0.25), (0, 0, 15))
	c.key("Shell", f0 + 6, (0, -0.08, -0.01))
	c.key("Shell", f0 + 9)
	c.key("Shell", f0 + 12, (0.15, 0, 0))
	c.key("Shell", f0 + 13)
	swing(c, [(f0 + 10, 4), (f0 + 13, -3), (f0 + 16, 1.5)])


def hold_pose(c, *frames):
	for f in frames:
		c.key("Root", f, *LOAD_POSE)


def reload_start():
	c = Clip(GUN, "ReloadStart", 12)
	c.key("Root", 5, (0, 0, 0.015), (-14, -4, 4))
	hold_pose(c, 10, 12)
	return c


def reload_insert():
	c = Clip(GUN, "ReloadInsert", 16)
	hold_pose(c, 1, 8, 16)
	c.key("Root", 10, (0.004, 0, 0.034), (-27, -9, 8))
	insert(c, 1)
	return c


def reload_end():
	c = Clip(GUN, "ReloadEnd", 14)
	hold_pose(c, 1)
	c.key("Root", 6, (0, 0, 0.012), (-9, -3, 3))
	c.key("Root", 11, (0, 0, 0.002), (-1, 0.3, 0.3))
	return c


def reload_single():
	c = Clip(GUN, "Reload", 60)
	c.key("Root", 5, (0, 0, 0.015), (-14, -4, 4))
	hold_pose(c, 10, 26)
	insert(c, 12)
	c.key("Root", 22, (0.004, 0, 0.034), (-27, -9, 8))
	c.key("Root", 40, (0, 0, 0.012), (-9, -3, 3))
	c.key("Root", 50, (0, 0, 0.002), (-1, 0.3, 0.3))
	return c


def reload_empty():
	c = Clip(GUN, "ReloadEmpty", 86)
	c.key("Root", 5, (0, 0, 0.015), (-14, -4, 4))
	hold_pose(c, 10, 26)
	insert(c, 12)
	c.key("Root", 22, (0.004, 0, 0.034), (-27, -9, 8))
	c.key("Root", 40, (0, 0, 0.01), (-4, -2, 1))
	lever_cycle(c, 52, hold=2)
	c.key("Hammer", 86, rot=(0, -32, 0))
	c.key("Root", 55, (-0.016, 0, -0.004), (-2, 1, 0.5))
	c.key("Root", 61, (0.01, 0, 0.002), (-1, -0.5, 0.2))
	c.key("Root", 72, (0, 0, 0), (-0.3, 0, 0))
	return c


def draw():
	c = Clip(GUN, "Draw", 31)
	c.key("Root", 8, (0, 0, 0), (6, 0, -5))
	c.key("Root", 15, (0, 0, 0.006), (8, 1, -6))
	c.key("Root", 20, (0.012, 0, 0.003), (4, -1, -3))
	c.key("Root", 25, (0, 0, 0), (0.8, 0, -0.6))
	lever_cycle(c, 11, hold=1)
	c.key("Hammer", 31, rot=(0, -32, 0))
	return c


def inspect():
	c = Clip(GUN, "Inspect", 67)
	c.key("Lever", 42)
	c.key("Lever", 46, rot=(0, OPEN * 0.45, 0))
	c.key("Lever", 51, rot=(0, OPEN * 0.45, 0))
	c.key("Lever", 54)
	c.key("Bolt", 42)
	c.key("Bolt", 46, (-BOLT * 0.4, 0, 0))
	c.key("Bolt", 51, (-BOLT * 0.4, 0, 0))
	c.key("Bolt", 54)
	c.key("Root", 54, (0, 0, 0))
	c.key("Root", 55, (0.006, 0, 0), (0, 0.4, 0))
	c.key("Root", 57)
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
