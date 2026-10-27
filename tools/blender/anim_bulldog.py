# anim_bulldog.py: the Bulldog's clips as NLA tracks (Fire, Reload, ReloadEmpty, Draw, Inspect), built from the
# shared blocks in tools/blender/gunkit.py. Run after build_bulldog.py (tools/blender/finish_gun.py does it headless).
#
# Bullpup: the bolt cycles, the forward charging handle stays put while firing. The magazine sits behind the grip
# and drops straight down out of the stock; the gun rolls further to bring it into view. The left hand follows the
# magazine, then the charging handle (forward on the top-left).

import bpy, importlib, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gunkit

importlib.reload(gunkit)
from gunkit import Clip, cycle, draw_rack, inspect_tap_check, kick, mag_swap, rack, reload_root, trigger_pull

GUN = "Bulldog"
FPS = 24


def fire():
	c = Clip(GUN, "Fire", 10)
	kick(c, back=0.045, climb=3.0, roll=0.5, last=10)
	cycle(c, ("Bolt", "ChargingHandle"), 0.1)  # round 2: the side handle rides every shot, like the Vandal
	trigger_pull(c, 14)
	return c


def reload_tactical():
	c = Clip(GUN, "Reload", 66)
	mag_swap(c, 10, drop=0.65, fwd=-0.04, tilt=6)
	reload_root(c, 10, roll=16, pitch=-2, yaw=-8, lift=0.02)
	c.key("Root", 58, (0, 0, 0.003), (2, -0.5, 0.5))
	c.key("Root", 64)
	return c


def reload_empty():
	c = Clip(GUN, "ReloadEmpty", 97)
	mag_swap(c, 11, drop=0.65, fwd=-0.04, tilt=6)  # done by f51 = 52%
	reload_root(c, 11, roll=16, pitch=-2, yaw=-8, lift=0.02)
	rack(c, 80, travel=0.2, jolt=1.1)  # cocking knob from 82%
	return c


def draw():
	c = Clip(GUN, "Draw", 31)
	draw_rack(c, travel=0.2, jolt=1.1)
	return c


def inspect():
	c = Clip(GUN, "Inspect", 67)
	inspect_tap_check(c, check_travel=0.055)
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
