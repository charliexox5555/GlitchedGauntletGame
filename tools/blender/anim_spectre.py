# anim_spectre.py: the Spectre's clips as NLA tracks (Fire, Reload, ReloadEmpty, Draw, Inspect), built from the
# shared blocks in tools/blender/gunkit.py. Run after build_spectre.py (tools/blender/finish_gun.py does it headless).
#
# Suppressed SMG: the bolt cycles, the HK-style charging handle stays put while firing. The curved magazine drops
# out forward of the trigger guard. The left hand follows the magazine, then the charging handle.

import bpy, importlib, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gunkit

importlib.reload(gunkit)
from gunkit import Clip, cycle, draw_rack, inspect_tap_check, kick, mag_swap, rack, reload_root, trigger_pull

GUN = "Spectre"
FPS = 24


def fire():
	c = Clip(GUN, "Fire", 10)
	kick(c, back=0.03, climb=1.8, roll=0.4, last=10)
	cycle(c, ("Bolt", "ChargingHandle"), 0.11)  # round 2: the handle rides every shot
	trigger_pull(c, 14)
	return c


def reload_tactical():
	c = Clip(GUN, "Reload", 66)
	mag_swap(c, 10, drop=0.65, fwd=0.06, tilt=-10, rock=0.3)
	reload_root(c, 10, roll=12, pitch=-4, yaw=3, lift=0.016)
	c.key("Root", 58, (0, 0, 0.003), (2, -0.5, 0.5))
	c.key("Root", 64)
	return c


def reload_empty():
	c = Clip(GUN, "ReloadEmpty", 97)
	mag_swap(c, 11, drop=0.65, fwd=0.06, tilt=-10, rock=0.3)  # done by f51 = 52%
	reload_root(c, 11, roll=12, pitch=-4, yaw=3, lift=0.016)
	rack(c, 80, travel=0.16, jolt=0.8)  # cocking knob from 82%
	return c


def draw():
	c = Clip(GUN, "Draw", 31)
	draw_rack(c, travel=0.16, jolt=0.8)
	return c


def inspect():
	c = Clip(GUN, "Inspect", 67)
	inspect_tap_check(c, check_travel=0.06)
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
