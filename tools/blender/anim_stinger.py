# anim_stinger.py: the Stinger's clips as NLA tracks (Fire, Reload, ReloadEmpty, Draw, Inspect), built from the
# shared blocks in tools/blender/gunkit.py. Run after build_stinger.py (tools/blender/finish_gun.py does it headless).
#
# Uzi-type SMG: the bolt cycles, the side cocking knob stays put while firing. The long magazine drops straight out
# of the grip (no rock). The left hand follows the magazine, then the cocking knob.
#
# Round 3 of the 2026-11-20 animation pass: the new magazine comes in from the front, tilted bottom-forward, and only
# its last ~0.2 stud slides straight up the grip (mag_swap_front). The Uzi's mag goes through the pistol grip, and the
# block forearm hangs straight down that grip's line, so a mag rising straight up the line went through the forearm
# (measured 0.15 deep for ~0.3 s with tools/studio/ArmClipCheck.luau).

import bpy, importlib, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gunkit

importlib.reload(gunkit)
from gunkit import Clip, cycle, draw_rack, inspect_tap_check, kick, rack, reload_root, trigger_pull

GUN = "Stinger"
FPS = 24


def mag_swap_front(c, f0, drop=0.7, tilt=-6):
	# mag_swap's timing (MagIn f0 + 18, slap f0 + 37, done f0 + 40; MagOut a frame sooner, f0 + 2); the old mag
	# leaves straight down as before. The new one (Mag bone: X gun-forward, Y gun-left, Z up; a negative Y turn swings the
	# mag's bottom forward) shows low and in front of the trigger hand's forearm, rocks back as it rises and is
	# straight only for the last 0.2 stud, where the mag's bottom is still inside the fist.
	bone = "Mag"
	c.key(bone, f0)
	c.key(bone, f0 + 2, (0.004, 0, -0.03), (0, tilt * 0.2, 0))
	c.key(bone, f0 + 5, (0.01, 0, -drop * 1.15), (0, tilt, 0))  # hidden from MagOut until MagIn
	c.key(bone, f0 + 18, (0.45, 0.15, -0.95), (0, -30, 0))  # the new mag, low and forward
	c.key(bone, f0 + 27, (0.3, 0.08, -0.42), (0, -24, 0))
	c.key(bone, f0 + 31, (0.12, 0.02, -0.2), (0, -12, 0))
	c.key(bone, f0 + 34, (0.01, 0, -0.05), (0, -2, 0))  # in the well, straight
	c.key(bone, f0 + 37, (0, 0, 0.007), (0, 0.6, 0))  # slapped home
	c.key(bone, f0 + 40)
	c.mark("MagOut", f0 + 2)  # a frame before mag_swap's: at f0 + 3 it was already in the forearm's line
	c.mark("MagIn", f0 + 18)
	return f0 + 40


def fire():
	c = Clip(GUN, "Fire", 10)
	kick(c, back=0.035, climb=2.2, roll=0.5, last=10)
	cycle(c, ("Bolt", "ChargingHandle"), 0.11)  # round 2: the knob rides every shot
	trigger_pull(c, 14)
	return c


def reload_tactical():
	c = Clip(GUN, "Reload", 66)
	mag_swap_front(c, 10)
	reload_root(c, 10, roll=12, pitch=-4, yaw=3, lift=0.016)
	c.key("Root", 58, (0, 0, 0.003), (2, -0.5, 0.5))
	c.key("Root", 64)
	return c


def reload_empty():
	c = Clip(GUN, "ReloadEmpty", 97)
	mag_swap_front(c, 11)  # done by f51 = 52%
	reload_root(c, 11, roll=12, pitch=-4, yaw=3, lift=0.016)
	rack(c, 80, travel=0.15, jolt=0.8)  # cocking knob from 82%
	return c


def draw():
	c = Clip(GUN, "Draw", 31)
	draw_rack(c, travel=0.15, jolt=0.8)
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
