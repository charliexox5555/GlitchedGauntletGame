# anim_judge.py: the Judge's clips as NLA tracks (Fire, Reload = drum swap, ReloadEmpty = drum swap + rack, Draw,
# Inspect), built from the shared blocks in tools/blender/gunkit.py. Run after build_judge.py
# (tools/blender/finish_gun.py does it headless).
#
# Automatic shotgun: no pump between shots; the bolt cycles, the side charging handle stays put. The drum (Mag)
# never spins; it rocks forward off the catch and drops. The left hand follows the drum, then the charging handle.

import bpy, importlib, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gunkit

importlib.reload(gunkit)
from gunkit import Clip, cycle, draw_rack, inspect_tap_check, kick, mag_swap, rack, reload_root, trigger_pull

GUN = "Judge"
FPS = 24


def fire():
	c = Clip(GUN, "Fire", 12)
	kick(c, back=0.07, climb=5.5, roll=0.6)
	cycle(c, ("Bolt", "ChargingHandle"), 0.12)  # round 2: the top slide cycles every shot
	trigger_pull(c)
	return c


def reload_tactical():
	c = Clip(GUN, "Reload", 76)
	mag_swap(c, 11, drop=0.75, fwd=0.08, tilt=-12, rock=0.6)
	reload_root(c, 11, roll=11, pitch=-6, yaw=2.5, lift=0.02)
	c.key("Root", 64, (0, 0, 0.004), (2, -1, 0.5))
	c.key("Root", 72)
	return c


def reload_empty():
	c = Clip(GUN, "ReloadEmpty", 97)
	mag_swap(c, 11, drop=0.75, fwd=0.08, tilt=-12, rock=0.6)  # drum done by f51 = 52%
	reload_root(c, 11, roll=11, pitch=-6, yaw=2.5, lift=0.02)
	rack(c, 80, travel=0.16, jolt=1.2)  # charging handle from 82%
	return c


def draw():
	c = Clip(GUN, "Draw", 31)
	draw_rack(c, travel=0.17, jolt=1.2)  # round 2: racks the top slide
	return c


def inspect():
	c = Clip(GUN, "Inspect", 67)
	inspect_tap_check(c, check_travel=0.07)
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
