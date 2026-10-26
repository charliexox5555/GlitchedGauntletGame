# anim_shorty.py: the Shorty's clips as NLA tracks (Fire, Reload = one-shell, ReloadEmpty = two-shell, Draw,
# Inspect). Run after build_shorty.py (tools/blender/finish_gun.py does it headless):
#   g = {"__name__": "anim", "__file__": path}; exec(compile(open(path).read(), path, "exec"), g); g["animate"]()
#
# Break action: Barrels rotates about its Y axis (positive = muzzles drop, the action opens). The shells are
# children of Barrels, so their moves are in the opened barrels' frame (-X = out of the chamber, rearward).
# Gameplay picks the barrel per shot; the upper barrel is taken to fire first, so the one-shell Reload swaps the
# upper shell only. The left hand follows the first part a reload moves: Barrels (RELOAD_FOLLOW, grab "Grip").

import bpy, importlib, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gunkit

importlib.reload(gunkit)

GUN = "Shorty"
FPS = 24
OPEN = 38  # degrees the barrels drop when broken open


def fire():
	c = gunkit.Clip(GUN, "Fire", 12)
	c.key("Root", 2, (-0.06, 0, 0.012), (0, -6.5, 0.6))
	c.key("Root", 3, (-0.075, 0, 0.016), (0, -8, 0.7))
	c.key("Root", 5, (-0.04, 0, 0.008), (0, -4.5, 0.3))
	c.key("Root", 7, (-0.012, 0, 0.002), (0, -1.2, 0))
	c.key("Root", 9, (0.004, 0, 0), (0, 0.4, 0))
	c.key("Root", 11)
	c.key("Trigger", 2, rot=(0, 16, 0))
	c.key("Trigger", 4, rot=(0, 16, 0))
	c.key("Trigger", 6, rot=(0, 4, 0))
	c.key("Trigger", 7)
	for f, a in ((3, 12), (5, -8), (7, 4.5), (9, -2), (11, 0.6)):
		c.key("Charm", f, rot=(a * 0.35, a, 0))
	return c


def open_close(c, f_open, f_close, last):
	# Latch forward, barrels drop open (with a little bounce), later snap shut and the latch returns.
	c.key("BreechLatch", f_open - 4)
	c.key("BreechLatch", f_open - 1, (0.022, 0, 0))
	c.key("BreechLatch", f_close + 3, (0.022, 0, 0))
	c.key("BreechLatch", f_close + 5)
	c.key("Barrels", f_open)
	c.key("Barrels", f_open + 5, rot=(0, OPEN + 3, 0))
	c.key("Barrels", f_open + 7, rot=(0, OPEN, 0))
	c.key("Barrels", f_close - 3, rot=(0, OPEN, 0))
	c.key("Barrels", f_close, rot=(0, -1.5, 0))  # snapped shut
	c.key("Barrels", f_close + 2)
	# Root: tip the muzzle down and roll the breech toward the player while open; a jolt as it snaps shut.
	c.key("Root", f_open - 4, (0, 0, 0.005), (5, 3, -3))
	c.key("Root", f_open + 6, (0, 0, 0.02), (9, 10, -6))
	c.key("Root", f_close - 4, (0, 0, 0.02), (9, 8, -6))
	c.key("Root", f_close, (0.01, 0, 0.012), (6, -3, -4))
	c.key("Root", f_close + 4, (0, 0, 0.004), (2, 0.5, -1.5))
	c.key("Root", last - 4)
	for f, a in ((f_open + 2, 9), (f_open + 6, -7), (f_open + 10, 4), (f_open + 14, -2), (f_close + 1, 10), (f_close + 5, -6), (f_close + 9, 3)):
		c.key("Charm", f, rot=(a * 0.35, a, 0))


def eject(c, bone, f):
	# Spent shell kicks out of its chamber and away (the game hides it once it's out of view).
	c.key(bone, f)
	c.key(bone, f + 3, (-0.16, 0, 0.1), (0, -20, 0))
	c.key(bone, f + 8, (-0.55, 0, 0.42), (0, -70, 0))


def insert(c, bone, f):
	# A fresh shell comes up from below-behind, lines up with the chamber and is pushed home by f + 12.
	c.key(bone, f, (-0.5, 0, -0.35), (0, 25, 0))
	c.key(bone, f + 7, (-0.16, 0, -0.02), (0, 4, 0))
	c.key(bone, f + 12)


def reload_one():
	L = 72
	c = gunkit.Clip(GUN, "Reload", L)
	open_close(c, 10, 52, L)
	eject(c, "ShellUpper", 17)
	c.key("ShellUpper", 27, (-0.55, 0, 0.42), (0, -70, 0))
	insert(c, "ShellUpper", 30)
	return c


def reload_two():
	L = 86
	c = gunkit.Clip(GUN, "ReloadEmpty", L)
	open_close(c, 10, 66, L)
	eject(c, "ShellUpper", 17)
	eject(c, "ShellLower", 17)
	c.key("ShellUpper", 27, (-0.55, 0, 0.42), (0, -70, 0))
	c.key("ShellLower", 27, (-0.55, 0, 0.42), (0, -70, 0))
	insert(c, "ShellUpper", 30)
	c.key("ShellLower", 40, (-0.55, 0, 0.42), (0, -70, 0))
	insert(c, "ShellLower", 44)
	return c


def draw():
	# Quick snap check on the draw: thumb the latch, let the barrels drop a touch, snap them shut.
	L = 24
	c = gunkit.Clip(GUN, "Draw", L)
	c.key("BreechLatch", 2)
	c.key("BreechLatch", 4, (0.02, 0, 0))
	c.key("BreechLatch", 10, (0.02, 0, 0))
	c.key("BreechLatch", 12)
	c.key("Barrels", 4)
	c.key("Barrels", 7, rot=(0, 11, 0))
	c.key("Barrels", 10, rot=(0, -1.5, 0))
	c.key("Barrels", 12)
	c.key("Root", 4, (0, 0, 0.004), (4, 2, -2))
	c.key("Root", 7, (0, 0, 0.01), (6, 6, -3))
	c.key("Root", 10, (0.012, 0, 0.006), (4, -3, -2))
	c.key("Root", 14, (0, 0, 0.002), (1.5, 0.4, -0.8))
	c.key("Root", 20)
	for f, a in ((5, 7), (9, -6), (12, 9), (16, -5), (20, 2)):
		c.key("Charm", f, rot=(a * 0.35, a, 0))
	return c


def inspect():
	# Alongside the viewmodel's Inspect track (right side 16-42%, left side 60-82%): break it open on the left
	# side to show the two loaded shells, then snap it shut.
	L = 67
	c = gunkit.Clip(GUN, "Inspect", L)
	c.key("BreechLatch", 36)
	c.key("BreechLatch", 38, (0.02, 0, 0))
	c.key("BreechLatch", 56, (0.02, 0, 0))
	c.key("BreechLatch", 58)
	c.key("Barrels", 38)
	c.key("Barrels", 43, rot=(0, 27, 0))
	c.key("Barrels", 45, rot=(0, 25, 0))
	c.key("Barrels", 52, rot=(0, 25, 0))
	c.key("Barrels", 55, rot=(0, -1.2, 0))
	c.key("Barrels", 57)
	c.key("Root", 54, (0, 0, 0))
	c.key("Root", 55, (0.008, 0, 0.004), (0, -1.5, 0))
	c.key("Root", 58)
	for f, a in ((6, 8), (11, -6), (16, 5), (21, -2.5), (30, 2), (40, 9), (44, -7), (48, 4), (55, 9), (59, -5), (63, 2)):
		c.key("Charm", f, rot=(a * 0.35, a, 0))
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
