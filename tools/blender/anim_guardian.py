# anim_guardian.py: the Guardian's clips as NLA tracks (Fire, Reload, ReloadEmpty, Draw, Inspect), built from the
# shared blocks in tools/blender/gunkit.py. Run after build_guardian.py (tools/blender/finish_gun.py does it headless).
#
# Semi-automatic precision rifle: each shot cycles the bolt (no manual cycling); the side charging knob stays put.
# The straight box magazine rocks forward a touch and drops. The left hand follows the magazine, then the knob.

import bpy, importlib, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gunkit

importlib.reload(gunkit)
from gunkit import Clip, cycle, draw_rack, inspect_tap_check, kick, mag_swap, rack, reload_root, trigger_pull

GUN = "Guardian"
FPS = 24


def fire():
	c = Clip(GUN, "Fire", 12)
	kick(c, back=0.06, climb=4.5, roll=0.4, last=12)
	cycle(c, ("Bolt", "ChargingHandle"), 0.13)  # round 2: the handle rides the bolt on every shot
	trigger_pull(c, 15)
	return c


def reload_tactical():
	c = Clip(GUN, "Reload", 66)
	mag_swap(c, 10, drop=0.6, fwd=0.05, tilt=-8, rock=0.3)
	reload_root(c, 10, roll=10, pitch=-5, yaw=2.5, lift=0.018)
	c.key("Root", 58, (0, 0, 0.003), (2, -0.5, 0.5))
	c.key("Root", 64)
	return c


def reload_empty():
	c = Clip(GUN, "ReloadEmpty", 97)
	mag_swap(c, 11, drop=0.6, fwd=0.05, tilt=-8, rock=0.3)  # done by f51 = 52%
	reload_root(c, 11, roll=10, pitch=-5, yaw=2.5, lift=0.018)
	rack(c, 80, travel=0.15, jolt=1.0)  # cocking knob from 82%
	return c


def draw():
	c = Clip(GUN, "Draw", 31)
	draw_rack(c, travel=0.2, jolt=1.2)  # round 2: a full, visible rack
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
