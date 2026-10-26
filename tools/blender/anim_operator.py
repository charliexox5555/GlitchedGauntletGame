# anim_operator.py: the Operator's clips as NLA tracks (Fire, Reload, ReloadEmpty, Draw, Inspect). Run after
# build_operator.py (tools/blender/finish_gun.py does it headless). Built from the shared blocks in gunkit.py.
#
#   Fire          heavy kick, then the bolt cycle: lift, pull, push, lock (f13-29); no auto-cycling
#   Reload        magazine swap, no bolt work      ReloadEmpty   magazine swap, then a bolt cycle (from 72%)
#   Draw          deliberate raise, the hand checks the bolt handle is down
#   Inspect       tap on the magazine, then a press check (bolt lifted and drawn part-way back)
#
# Bolt: lift = negative rotation about X (the right-side handle swings up around the bolt axis), then -X slides it
# back. The trigger hand works the handle, so Fire, ReloadEmpty and Inspect need a right-hand follow on "Bolt".
# The Root rolls the right side up toward the player while the bolt is worked.

import bpy, importlib, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gunkit

importlib.reload(gunkit)
from gunkit import Clip, kick, mag_swap, reload_root, swing, trigger_pull

GUN = "Operator"
FPS = 24
LIFT = -62  # handle lift, degrees about X
TRAVEL = 0.3  # bolt pull


def bolt_cycle(c, f0):
	# Lift (f0 .. f0 + 3), pull (.. + 7), push (.. + 12), lock down (.. + 15). Occupies f0 .. f0 + 16.
	c.key("Bolt", f0)
	c.key("Bolt", f0 + 3, rot=(LIFT, 0, 0))
	c.key("Bolt", f0 + 7, (-TRAVEL, 0, 0), (LIFT, 0, 0))
	c.key("Bolt", f0 + 8, (-TRAVEL, 0, 0), (LIFT, 0, 0))
	c.key("Bolt", f0 + 12, (0, 0, 0), (LIFT, 0, 0))
	c.key("Bolt", f0 + 15, rot=(2, 0, 0))
	c.key("Bolt", f0 + 16)
	c.key("Root", f0 - 1, (0, 0, 0), (0, 0, 0))
	c.key("Root", f0 + 3, (0, 0, 0.006), (-9, -2, 3))
	c.key("Root", f0 + 7, (-0.014, 0, 0.008), (-11, -3, 3.5))
	c.key("Root", f0 + 12, (0.01, 0, 0.006), (-9, -1.5, 3))
	c.key("Root", f0 + 15, (0, 0, 0.004), (-5, -1, 1.5))
	c.key("Root", f0 + 22)
	swing(c, [(f0 + 4, 5), (f0 + 8, -8), (f0 + 12, 9), (f0 + 16, -5), (f0 + 20, 2.5)])


def fire():
	c = Clip(GUN, "Fire", 34)
	kick(c, back=0.12, climb=9, roll=0.9, last=12)
	trigger_pull(c, 15)
	swing(c, [(3, 12), (5, -8), (8, 4.5), (11, -2)])
	bolt_cycle(c, 13)
	return c


def reload_tactical():
	c = Clip(GUN, "Reload", 66)
	mag_swap(c, 10, drop=0.6, fwd=0.04, tilt=-6, rock=0.2)
	reload_root(c, 10, roll=9, pitch=-4, yaw=2, lift=0.018)
	c.key("Root", 58, (0, 0, 0.003), (2, -0.5, 0.5))
	c.key("Root", 64)
	return c


def reload_empty():
	c = Clip(GUN, "ReloadEmpty", 97)
	mag_swap(c, 11, drop=0.6, fwd=0.04, tilt=-6, rock=0.2)  # done by f51 = 52%
	reload_root(c, 11, roll=9, pitch=-4, yaw=2, lift=0.018)
	c.key("Root", 60, (0, 0, 0.004), (2, -0.5, 0.5))
	bolt_cycle(c, 70)  # bolt from 72%
	return c


def draw():
	c = Clip(GUN, "Draw", 31)
	c.key("Root", 8, (0, 0, 0), (6, 0, -5))
	c.key("Root", 14, (0, 0, 0.006), (-6, -1, -4))
	c.key("Root", 19, (0.01, 0, 0.004), (-4, 0.5, -2))
	c.key("Root", 25, (0, 0, 0), (0.6, 0, -0.4))
	c.key("Bolt", 12)
	c.key("Bolt", 14, rot=(LIFT * 0.18, 0, 0))
	c.key("Bolt", 16, rot=(1.5, 0, 0))
	c.key("Bolt", 17)
	swing(c, [(5, -5), (9, 4), (13, -3), (16, 6), (19, -4), (22, 2), (26, -1)])
	return c


def inspect():
	c = Clip(GUN, "Inspect", 67)
	c.key("Mag", 13)
	c.key("Mag", 15, (0, 0, -0.025), (0, -2, 0))
	c.key("Mag", 16, (0, 0, 0.004), (0, 0.4, 0))
	c.key("Mag", 18)
	c.key("Root", 15, (0, 0, 0.004), (0.6, 0, 0))
	c.key("Root", 17)
	c.key("Root", 38)
	c.key("Root", 42, (0, 0, 0.004), (-7, -1, 2))
	c.key("Root", 52, (0, 0, 0.004), (-7, -1, 2))
	c.key("Root", 56, (0.006, 0, 0), (-2, 0.4, 0.5))
	c.key("Root", 60)
	c.key("Bolt", 42)
	c.key("Bolt", 45, rot=(LIFT, 0, 0))
	c.key("Bolt", 47, (-TRAVEL * 0.35, 0, 0), (LIFT, 0, 0))
	c.key("Bolt", 51, (-TRAVEL * 0.35, 0, 0), (LIFT, 0, 0))
	c.key("Bolt", 53, (0, 0, 0), (LIFT, 0, 0))
	c.key("Bolt", 55, rot=(1.5, 0, 0))
	c.key("Bolt", 56)
	swing(c, [(6, 9), (11, -7), (16, 6), (21, -3), (28, 2), (40, -6), (45, 7), (50, -4), (55, 6), (59, -3), (63, 1.5)])
	return c


def animate():
	bpy.context.scene.render.fps = FPS
	out = {}
	for clip in (fire(), reload_tactical(), reload_empty(), draw(), inspect()):
		clip.bake()
		out[clip.name] = {"frames": clip.last, "bones": sorted(clip.keys)}
	bpy.context.scene.frame_set(1)
	return out


if __name__ == "__main__":
	print(animate())
