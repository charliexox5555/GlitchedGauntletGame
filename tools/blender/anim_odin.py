# anim_odin.py: the Odin's clips as NLA tracks (Fire, Reload, ReloadEmpty, Draw, Inspect). Run after build_odin.py
# (tools/blender/finish_gun.py does it headless). Built from the shared blocks in gunkit.py.
#
#   Fire          one automatic shot (the game loops it): kick, bolt cycle, the belt twitches as it feeds
#   Reload        feed cover up (f6-11), box swap (f12-52; the belt rides the box), belt seated in the tray
#                 (f52-57), cover slammed shut (f58-60)
#   ReloadEmpty   the same, then a charging-handle rack (from 84%)
#   Draw          rack     Inspect   tap on the box, press check
#
# FeedCover hinges at its rear: negative rotation about Y lifts the front. FeedBelt is a child of AmmoBox, so its keys
# are offsets from the box. The left hand works the cover, the box and the belt: Studio needs follow rules for
# "FeedCover", "AmmoBox" and "FeedBelt" (or one on AmmoBox for the whole window).

import bpy, importlib, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gunkit

importlib.reload(gunkit)
from gunkit import Clip, cycle, draw_rack, inspect_tap_check, kick, mag_swap, rack, reload_root, swing, trigger_pull

GUN = "Odin"
FPS = 24
COVER = -75  # feed cover open, degrees about Y
SAG = (0, 0, -0.06)  # the loose belt hanging lower before it is laid in the tray


def fire():
	c = Clip(GUN, "Fire", 12)
	kick(c, back=0.045, climb=2.2, roll=0.6, last=12)
	cycle(c, ("Bolt", "ChargingHandle"), 0.1)  # round 2: the handle rides the bolt on every shot
	trigger_pull(c, 14)
	c.key("FeedBelt", 1)
	c.key("FeedBelt", 2, (0, 0, 0.012))
	c.key("FeedBelt", 4, (0, 0, -0.004))
	c.key("FeedBelt", 6)
	return c


def belt_change(c):
	# Cover up, box out and back, belt laid in, cover slammed (f4 .. f64).
	c.key("FeedCover", 6)
	c.key("FeedCover", 10, rot=(0, COVER - 4, 0))
	c.key("FeedCover", 12, rot=(0, COVER, 0))
	c.key("FeedCover", 55, rot=(0, COVER, 0))
	c.key("FeedCover", 59, rot=(0, 2, 0))  # slammed shut
	c.key("FeedCover", 61)
	mag_swap(c, 12, drop=0.8, fwd=0.02, tilt=-4, bone="AmmoBox")
	reload_root(c, 12, roll=11, pitch=-4, yaw=2, lift=0.02)
	c.key("FeedBelt", 12)
	c.key("FeedBelt", 20, SAG, (6, 0, 0))
	c.key("FeedBelt", 51, SAG, (6, 0, 0))
	c.key("FeedBelt", 55, (0, 0, 0.012))
	c.key("FeedBelt", 57)
	c.key("Root", 56, (0, 0, 0.016), (9, -4, 2))
	c.key("Root", 59, (0, 0, 0.004), (7, -1.5, 1.5))  # cover slam jolts it down
	c.key("Root", 62, (0, 0, 0.012), (8, -3, 2))
	swing(c, [(59, 9), (62, -5), (65, 2.5)])


def reload_tactical():
	c = Clip(GUN, "Reload", 80)
	belt_change(c)
	c.key("Root", 72, (0, 0, 0.002), (1, -0.4, 0.3))
	c.key("Root", 78)
	return c


def reload_empty():
	c = Clip(GUN, "ReloadEmpty", 110)
	belt_change(c)
	rack(c, 92, travel=0.15, jolt=1.3)  # charging handle from 84%
	return c


def draw():
	c = Clip(GUN, "Draw", 31)
	draw_rack(c, travel=0.2, selector=None, jolt=1.3)
	return c


def inspect():
	c = Clip(GUN, "Inspect", 67)
	inspect_tap_check(c, mag="AmmoBox", check_travel=0.07)
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
