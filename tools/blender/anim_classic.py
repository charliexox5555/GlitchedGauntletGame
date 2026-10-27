# anim_classic.py: the Classic's clips as NLA tracks (Fire, Reload, ReloadEmpty, Draw, Inspect, DryFire). Run after
# build_classic.py (tools/blender/finish_gun.py does it headless). Patterned on the Ghost's clips.
#
# Held-open empty state: ReloadEmpty's first frame (slide locked back, barrel breech dipped). With lockOnEmpty the
# game cuts the last shot's Fire at 25% and holds that frame until the reload.
# ReloadEmpty: mag swap, then the slide catch is thumbed and the slide slams home (f49-54).
# DryFire: the trigger only (pressed on an empty gun, if the game uses it).
# Barrel: a small negative rotation about Y dips its breech (pivot near the muzzle) whenever the slide is back.

import bpy, importlib, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gunkit

importlib.reload(gunkit)
from gunkit import Clip, swing

GUN = "Classic"
FPS = 24
LOCK = -0.12  # slide travel / locked-back position
TILT = (0, -2.5, 0)  # barrel with the slide back


def fire():
	c = Clip(GUN, "Fire", 9)
	c.key("Slide", 2, (LOCK, 0, 0))
	c.key("Slide", 3, (-0.08, 0, 0))
	c.key("Slide", 4)
	c.key("Barrel", 1)
	c.key("Barrel", 2, rot=TILT)
	c.key("Barrel", 4)
	c.key("Root", 2, (-0.026, 0, 0.007), (0, -5, 0.4))
	c.key("Root", 4, (-0.016, 0, 0.004), (0, -3, 0.2))
	c.key("Root", 6, (-0.003, 0, 0.001), (0, -0.6, 0))
	c.key("Root", 8, (0.002, 0, 0), (0, 0.3, 0))
	c.key("Root", 9)
	c.key("Trigger", 2, rot=(0, 14, 0))
	c.key("Trigger", 3, rot=(0, 14, 0))
	c.key("Trigger", 5)
	swing(c, [(3, 8), (5, -5), (7, 2.5), (9, -1)])
	return c


def dry_fire():
	c = Clip(GUN, "DryFire", 8)
	c.key("Trigger", 1)
	c.key("Trigger", 3, rot=(0, 14, 0))
	c.key("Trigger", 4, rot=(0, 14, 0))
	c.key("Trigger", 7)
	return c


def mag_swap(c, f0):
	# Thumb the release, the mag drops out of the grip, a fresh one goes in and is slapped home (f0 .. f0 + 34).
	c.key("MagRelease", f0 - 2)
	c.key("MagRelease", f0, (0, -0.005, 0))
	c.key("MagRelease", f0 + 3)
	gunkit.pistol_mag_drop(c, f0, back=-0.07, drop=0.58)  # round 2: mag drop (MagOut / MagIn markers)
	c.key("Root", f0 - 3, (0, 0, 0.004), (7, -2, 2))
	c.key("Root", f0 + 8, (0, 0, 0.012), (11, -4, 3))
	c.key("Root", f0 + 29, (0, 0, 0.01), (10, -4, 3))
	c.key("Root", f0 + 32, (0, 0, 0.022), (12, -6, 3.5))
	c.key("Root", f0 + 35, (0, 0, 0.008), (8, -3, 2))
	swing(c, [(f0 + 2, 6), (f0 + 6, -4), (f0 + 11, 2), (f0 + 32, 8), (f0 + 36, -5), (f0 + 40, 2)])


def reload_tactical():
	c = Clip(GUN, "Reload", 60)
	mag_swap(c, 10)
	c.key("Root", 52, (0, 0, 0.002), (1.5, -0.5, 0.4))
	c.key("Root", 58)
	return c


def reload_empty():
	c = Clip(GUN, "ReloadEmpty", 70)
	c.key("Slide", 1, (LOCK, 0, 0))  # starts locked back after the last shot (the held-open state)
	c.key("Barrel", 1, rot=TILT)
	mag_swap(c, 10)
	c.key("Slide", 52, (LOCK, 0, 0))
	c.key("Slide", 54)  # slide catch thumbed: slams home
	c.key("Barrel", 52, rot=TILT)
	c.key("Barrel", 54)
	c.key("SlideCatch", 49)
	c.key("SlideCatch", 51, rot=(0, -9, 0))
	c.key("SlideCatch", 54)
	c.key("Root", 50, (0, 0, 0.006), (6, -2, 1.5))
	c.key("Root", 54, (0.012, 0, 0.004), (2, 1.5, 0.5))
	c.key("Root", 58, (0, 0, 0.001), (1, -0.3, 0.2))
	c.key("Root", 66)
	swing(c, [(54, 9), (58, -6), (62, 3)])
	return c


def draw():
	# Raised with a quick press check: the slide eases back a touch, then home.
	c = Clip(GUN, "Draw", 20)
	c.key("Slide", 6)
	c.key("Slide", 9, (-0.04, 0, 0))
	c.key("Slide", 11, (-0.04, 0, 0))
	c.key("Slide", 13)
	c.key("Root", 4, (0, 0, 0.004), (6, 0, -4))
	c.key("Root", 9, (0, 0, 0.006), (9, -1, -6))
	c.key("Root", 13, (0.006, 0, 0.003), (4, 0.6, -3))
	c.key("Root", 17)
	swing(c, [(5, 6), (9, -4), (13, 7), (17, -3)])
	return c


def inspect():
	# Alongside the viewmodel's turn (slide side, grip, far side, mag base): the mag drops a little and is pushed
	# home, then a press check.
	c = Clip(GUN, "Inspect", 67)
	c.key("MagRelease", 12)
	c.key("MagRelease", 13, (0, -0.005, 0))
	c.key("MagRelease", 15)
	c.key("Mag", 13)
	c.key("Mag", 17, (-0.01, 0, -0.06), (0, -1, 0))
	c.key("Mag", 22, (-0.01, 0, -0.06), (0, -1, 0))
	c.key("Mag", 25, (0, 0, 0.004), (0, 0.3, 0))
	c.key("Mag", 27)
	c.key("Slide", 42)
	c.key("Slide", 46, (-0.045, 0, 0))
	c.key("Slide", 51, (-0.045, 0, 0))
	c.key("Slide", 53)
	c.key("Root", 25, (0, 0, 0.004), (0.6, 0, 0))
	c.key("Root", 27)
	c.key("Root", 53, (0.005, 0, 0), (0, 0.4, 0))
	c.key("Root", 55)
	swing(c, [(6, 8), (11, -6), (16, 5), (21, -3), (26, 4), (31, -2), (40, 9), (45, -7), (50, 4), (54, 6), (58, -3), (62, 1.5)])
	return c


def animate():
	bpy.context.scene.render.fps = FPS
	out = {}
	for clip in (fire(), reload_tactical(), reload_empty(), draw(), inspect(), dry_fire()):
		clip.bake()
		out[clip.name] = {"frames": clip.last, "bones": sorted(clip.keys)}
	bpy.context.scene.frame_set(1)
	return out


if __name__ == "__main__":
	print(animate())
