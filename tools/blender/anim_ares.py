# anim_ares.py: the Ares's clips as NLA tracks (Fire, Reload, ReloadEmpty, Draw, Inspect). Run after build_ares.py
# (tools/blender/finish_gun.py does it headless). Built from the shared blocks in gunkit.py, like the Guardian.
#
# Fire is one automatic shot (the game loops it): kick and a bolt cycle; the drum does not spin. Reload swaps the
# drum (Mag); ReloadEmpty adds a charging-handle rack (the knob on the left side of the receiver front).

import bpy, importlib, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gunkit

importlib.reload(gunkit)
from gunkit import Clip, cycle, draw_rack, inspect_tap_check, kick, mag_swap, rack, reload_root, trigger_pull

GUN = "Ares"
FPS = 24


def fire():
	c = Clip(GUN, "Fire", 12)
	kick(c, back=0.05, climb=3, roll=0.5, last=12)
	cycle(c, ("Bolt", "ChargingHandle"), 0.12)  # round 2: the left-side handle rides the carrier, like the Vandal
	trigger_pull(c, 15)
	return c


def reload_tactical():
	c = Clip(GUN, "Reload", 66)
	mag_swap(c, 10, drop=0.75, fwd=0.03, tilt=-6, rock=0.15)  # heavy drum: a longer drop
	reload_root(c, 10, roll=12, pitch=-4, yaw=2.5, lift=0.02)
	c.key("Root", 58, (0, 0, 0.003), (2, -0.5, 0.5))
	c.key("Root", 64)
	return c


def reload_empty():
	c = Clip(GUN, "ReloadEmpty", 97)
	mag_swap(c, 11, drop=0.75, fwd=0.03, tilt=-6, rock=0.15)  # done by f51 = 52%
	reload_root(c, 11, roll=12, pitch=-4, yaw=2.5, lift=0.02)
	rack(c, 80, travel=0.18, jolt=1.2)  # charging handle from 82%
	return c


def draw():
	c = Clip(GUN, "Draw", 31)
	draw_rack(c, travel=0.18, jolt=1.2)
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
