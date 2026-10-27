# anim_outlaw.py: the Outlaw's clips as NLA tracks (Fire, Reload = one round, ReloadEmpty = two rounds, Draw,
# Inspect). Run after build_outlaw.py (tools/blender/finish_gun.py does it headless). Built like the Shorty's.
#
# Break action: Barrels rotates about its Y axis (positive = muzzles drop, the action opens); the scope stays on the
# receiver. The rounds are children of Barrels, so their moves are in the opened barrels' frame (-X = out of the
# chamber, rearward). The upper barrel is taken to fire first, so the one-round Reload swaps RoundUpper only.
# The left hand is on the fore-end (LeftGrip is on Barrels), so it rides the barrels open; the right hand thumbs
# the BreechLatch and feeds the rounds.

import bpy, importlib, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gunkit

importlib.reload(gunkit)
from gunkit import Clip, kick, swing, trigger_pull

GUN = "Outlaw"
FPS = 24
OPEN = 46  # degrees the barrels drop when broken open (round 2: fully open, Valorant-style)
OUT = ((-0.5, 0.06, -1.1), (0, 60, 0))  # a spent round's resting place: dropped below the frame


def fire():
	c = Clip(GUN, "Fire", 20)
	kick(c, back=0.1, climb=7.5, roll=0.8, last=20)
	trigger_pull(c, 15)
	swing(c, [(3, 11), (5, -7), (8, 4), (11, -2), (14, 0.8)])
	return c


def open_close(c, f_open, f_close, last):
	# Latch thumbed aside, barrels drop open (small bounce), later swung shut and the latch returns.
	c.key("BreechLatch", f_open - 4)
	c.key("BreechLatch", f_open - 1, (0.02, 0, 0), (12, 0, 0))
	c.key("BreechLatch", f_close + 3, (0.02, 0, 0), (12, 0, 0))
	c.key("BreechLatch", f_close + 5)
	c.key("Barrels", f_open)
	c.key("Barrels", f_open + 6, rot=(0, OPEN + 2.5, 0))
	c.key("Barrels", f_open + 8, rot=(0, OPEN, 0))
	c.key("Barrels", f_close - 4, rot=(0, OPEN, 0))
	c.key("Barrels", f_close, rot=(0, -1.2, 0))  # snapped shut
	c.key("Barrels", f_close + 2)
	# Root: tip the muzzle down and roll the breech toward the player while open; a jolt as it closes.
	c.key("Root", f_open - 4, (0, 0, 0.005), (4, 3, -2))
	c.key("Root", f_open + 7, (0, 0, 0.022), (10, 9, -5))
	c.key("Root", f_close - 5, (0, 0, 0.022), (10, 8, -5))
	c.key("Root", f_close, (0.012, 0, 0.012), (6, -3, -3))
	c.key("Root", f_close + 4, (0, 0, 0.004), (2, 0.5, -1))
	c.key("Root", last - 4)
	swing(c, [(f_open + 2, 8), (f_open + 6, -6), (f_open + 10, 3.5), (f_open + 14, -1.5), (f_close + 1, 9), (f_close + 5, -5), (f_close + 9, 2.5)])


def extract(c, bone, f):
	# The extractor lifts the spent round, then it flicks back and away.
	c.key(bone, f)
	c.key(bone, f + 3, (-0.1, 0, 0.02))
	c.key(bone, f + 6, (-0.32, 0, 0.04), (0, -15, 0))
	c.key(bone, f + 10, *OUT)


def insert(c, bone, f):
	# A fresh round comes up from behind-below, lines up with the chamber and is pushed home by f + 12.
	c.key(bone, f - 1, *OUT)
	c.key(bone, f, (-0.55, 0, -0.3), (0, 20, 0))
	c.key(bone, f + 6, (-0.24, 0, -0.01), (0, 3, 0))
	c.key(bone, f + 9, (-0.2, 0, 0))
	c.key(bone, f + 12)


def reload_one():
	L = 74
	c = Clip(GUN, "Reload", L)
	open_close(c, 10, 54, L)
	extract(c, "RoundUpper", 17)
	insert(c, "RoundUpper", 32)
	return c


def reload_two():
	L = 90
	c = Clip(GUN, "ReloadEmpty", L)
	open_close(c, 10, 70, L)
	extract(c, "RoundUpper", 17)
	extract(c, "RoundLower", 18)
	insert(c, "RoundUpper", 32)
	c.key("RoundLower", 44, *OUT)
	insert(c, "RoundLower", 46)
	return c


def draw():
	# Snap check on the draw: thumb the latch, the barrels drop a touch, swing them shut.
	L = 26
	c = Clip(GUN, "Draw", L)
	c.key("BreechLatch", 3)
	c.key("BreechLatch", 5, (0.02, 0, 0), (12, 0, 0))
	c.key("BreechLatch", 11, (0.02, 0, 0), (12, 0, 0))
	c.key("BreechLatch", 13)
	c.key("Barrels", 5)
	c.key("Barrels", 8, rot=(0, 9, 0))
	c.key("Barrels", 11, rot=(0, -1.2, 0))
	c.key("Barrels", 13)
	c.key("Root", 5, (0, 0, 0.004), (4, 2, -2))
	c.key("Root", 8, (0, 0, 0.01), (6, 5, -3))
	c.key("Root", 11, (0.012, 0, 0.006), (4, -3, -2))
	c.key("Root", 15, (0, 0, 0.002), (1.5, 0.4, -0.8))
	c.key("Root", 22)
	swing(c, [(6, 6), (10, -5), (13, 8), (17, -4), (21, 1.5)])
	return c


def inspect():
	# Alongside the viewmodel's Inspect track: break it part-way open to show both rounds, then close it.
	L = 67
	c = Clip(GUN, "Inspect", L)
	c.key("BreechLatch", 36)
	c.key("BreechLatch", 38, (0.02, 0, 0), (12, 0, 0))
	c.key("BreechLatch", 56, (0.02, 0, 0), (12, 0, 0))
	c.key("BreechLatch", 58)
	c.key("Barrels", 38)
	c.key("Barrels", 43, rot=(0, 21, 0))
	c.key("Barrels", 45, rot=(0, 19, 0))
	c.key("Barrels", 52, rot=(0, 19, 0))
	c.key("Barrels", 55, rot=(0, -1, 0))
	c.key("Barrels", 57)
	c.key("Root", 54, (0, 0, 0))
	c.key("Root", 55, (0.008, 0, 0.004), (0, -1.5, 0))
	c.key("Root", 58)
	swing(c, [(6, 7), (11, -5), (16, 4), (21, -2), (40, 8), (44, -6), (48, 3.5), (55, 8), (59, -4.5), (63, 2)])
	return c


def animate():
	bpy.context.scene.render.fps = FPS
	out = {}
	for clip in (fire(), reload_one(), reload_two(), draw(), inspect()):
		clip.bake()
		out[clip.name] = {"frames": clip.last, "bones": sorted(clip.keys)}
	bpy.context.scene.frame_set(1)
	return out


if __name__ == "__main__":
	print(animate())
