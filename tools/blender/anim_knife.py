# anim_knife.py: the Knife's clips as NLA tracks (Fire, Draw, Inspect, Slash1-3, HeavyStab). Run after build_knife.py
# (tools/blender/finish_gun.py does it headless).
#
# The knife is one rigid piece on Root, whose head is at the grip, so these turn it in the hand. The swings
# themselves (directions, thrust, recovery) belong to the viewmodel's arm motion; Fire only adds a small wrist snap
# on top. Draw twirls it once around the blade axis.
# Round 2: the Valorant-style combo Slash1 (forehand, right to left) -> Slash2 (backhand, edge flipped) -> Slash3
# (overhead chop), HeavyStab (wind back, thrust; the second hand is the viewmodel's), each with a "Hit" marker at
# the moment of contact (fraction of the clip) so the game can time the hit, wall mark and sound. Inspect is plain:
# edge up toward the eye, a half turn of the wrist to show the other face, back (no whole-hand spin).

import bpy, importlib, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gunkit

importlib.reload(gunkit)
from gunkit import Clip

GUN = "Knife"
FPS = 24


def fire():
	c = Clip(GUN, "Fire", 12)
	c.key("Root", 3, rot=(-14, 4, -6))
	c.key("Root", 5, rot=(10, -3, 4))
	c.key("Root", 8, rot=(-3, 1, -1))
	c.key("Root", 11)
	return c


def draw():
	c = Clip(GUN, "Draw", 20)
	c.key("Root", 3, rot=(0, -10, 0))
	c.key("Root", 8, rot=(180, -6, 0))
	c.key("Root", 13, rot=(345, -2, 0))
	c.key("Root", 16, rot=(362, 0, 0))
	c.key("Root", 20, rot=(360, 0, 0))  # one full turn: ends looking like rest
	return c


def wrist(c, keys, hit=None):
	for f, rot, *loc in keys:
		c.key("Root", f, loc[0] if loc else (0, 0, 0), rot)
	if hit:
		c.mark("Hit", hit)
	return c


def slash1():
	# Forehand: cocked to the right, sweeps right to left, follow-through.
	return wrist(Clip(GUN, "Slash1", 14), [(3, (20, 10, 25)), (5, (-25, -8, -30)), (8, (-30, -6, -36)), (11, (-8, -2, -9))], hit=5)


def slash2():
	# Backhand: edge rolled over, sweeps back left to right.
	return wrist(Clip(GUN, "Slash2", 14), [(3, (-30, 8, -30)), (6, (32, -10, 36)), (9, (35, -8, 39)), (12, (8, -2, 9))], hit=6)


def slash3():
	# Finisher: tip raised high, chops down hard.
	return wrist(Clip(GUN, "Slash3", 18), [(4, (0, -42, 6)), (6, (2, -45, 6)), (9, (6, 36, -5)), (12, (4, 40, -4)), (15, (0, 8, 0))], hit=9)


def heavy_stab():
	# Wind back with the tip lifted, then a straight thrust (tip level, a small push along the blade), slow recovery.
	return wrist(Clip(GUN, "HeavyStab", 24), [
		(6, (0, -16, 0), (-0.04, 0, 0)),
		(8, (0, -18, 0), (-0.05, 0, 0)),
		(11, (0, 4, 0), (0.06, 0, 0)),
		(14, (0, 3, 0), (0.06, 0, 0)),
		(19, (0, 0, 0), (0.01, 0, 0)),
	], hit=11)


def inspect():
	c = Clip(GUN, "Inspect", 67)
	c.key("Root", 8, rot=(0, 0, 0))
	c.key("Root", 16, rot=(-22, -16, 10))  # edge up, toward the eye
	c.key("Root", 28, rot=(-26, -18, 12))
	c.key("Root", 38, rot=(58, -10, 0))  # wrist turned: the other face
	c.key("Root", 50, rot=(62, -8, -4))
	c.key("Root", 60, rot=(2, 0, 0))
	return c


def animate():
	bpy.context.scene.render.fps = FPS
	out = {}
	for clip in (fire(), draw(), inspect(), slash1(), slash2(), slash3(), heavy_stab()):
		clip.bake()
		out[clip.name] = {"frames": clip.last, "bones": sorted(clip.keys)}
	bpy.context.scene.frame_set(1)
	return out


if __name__ == "__main__":
	print(animate())
