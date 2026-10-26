# anim_knife.py: the Knife's clips as NLA tracks (Fire, Draw, Inspect). Run after build_knife.py
# (tools/blender/finish_gun.py does it headless).
#
# The knife is one rigid piece on Root, whose head is at the grip, so these turn it in the hand. The swings
# themselves (directions, thrust, recovery) belong to the viewmodel's arm motion; Fire only adds a small wrist snap
# on top. Draw twirls it once around the blade axis; Inspect turns the edge up, then rolls it to show the far side.

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


def inspect():
	c = Clip(GUN, "Inspect", 67)
	c.key("Root", 8, rot=(0, 0, 0))
	c.key("Root", 16, rot=(-25, -20, 10))  # edge up, toward the eye
	c.key("Root", 26, rot=(-30, -22, 12))
	c.key("Root", 36, rot=(90, -10, 0))
	c.key("Root", 44, rot=(180, -15, -8))  # far face
	c.key("Root", 54, rot=(185, -12, -6))
	c.key("Root", 62, rot=(358, 0, 0))
	c.key("Root", 67, rot=(360, 0, 0))
	return c


def animate():
	bpy.context.scene.render.fps = FPS
	out = {}
	for clip in (fire(), draw(), inspect()):
		clip.bake()
		out[clip.name] = {"frames": clip.last, "bones": sorted(clip.keys)}
	bpy.context.scene.frame_set(1)
	return out


if __name__ == "__main__":
	print(animate())
