# anim_phantom.py: keyframes the Phantom's Fire, Reload (tactical), ReloadEmpty, Draw (first draw: selector off
# safe, rack) and Inspect (mag tap, press check) clips as NLA tracks
# (what tools/blender/export_weapons.py samples; tools/make_weapon_anims.py writes them to
# src/shared/WeaponAnimations/Phantom.luau).
#
#   Run inside Blender after build_phantom.py:
#     g = {"__name__": "anim", "__file__": path}; exec(compile(open(path).read(), path, "exec"), g); g["animate"]()
#
# Same timing rules as tools/blender/anim_vandal.py: clips are stretched to reloadTime / emptyReloadTime, so
# only proportions matter; the left hand follows the first part a reload moves (Mag, grabbed at its bottom),
# then a later one (ChargingHandle) only if their windows, each widened by FOLLOW_LEAD = 0.14, don't overlap:
# in ReloadEmpty the mag is done by 52% and the charging handle moves from 82%. The Bolt never moves in a
# reload (it comes before ChargingHandle in RELOAD_FOLLOW and sits on the far side).
#
# Phantom specifics: an AR-style action, so the side charging handle does NOT reciprocate when firing (only
# the bolt cycles); the straight box mag drops straight down instead of rocking out like the Vandal's; the kick
# is lighter (it's the steadier rifle).

import bpy, importlib, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gunkit

importlib.reload(gunkit)

GUN = "Phantom"
FPS = 24


def fire():
	c = gunkit.Clip(GUN, "Fire", 12)
	c.key("Root", 2, (-0.04, 0, 0.006), (0, -2.6, 0.3))
	c.key("Root", 3, (-0.052, 0, 0.008), (0, -3.3, 0.35))
	c.key("Root", 5, (-0.026, 0, 0.004), (0, -1.8, 0.15))
	c.key("Root", 7, (-0.007, 0, 0.001), (0, -0.4, 0))
	c.key("Root", 9, (0.003, 0, 0), (0, 0.2, 0))
	c.key("Root", 11)
	# Only the bolt carrier cycles (seen through the ejection port).
	c.key("Bolt", 2, (-0.12, 0, 0))
	c.key("Bolt", 3, (-0.14, 0, 0))
	c.key("Bolt", 4, (-0.09, 0, 0))
	c.key("Bolt", 5, (-0.025, 0, 0))
	c.key("Bolt", 6)
	c.key("Trigger", 2, rot=(0, 15, 0))
	c.key("Trigger", 4, rot=(0, 15, 0))
	c.key("Trigger", 6, rot=(0, 4, 0))
	c.key("Trigger", 7)
	c.key("Charm", 3, rot=(3.5, 9, 0))
	c.key("Charm", 5, rot=(-1.8, -6, 0))
	c.key("Charm", 7, rot=(1.2, 3.4, 0))
	c.key("Charm", 9, rot=(-0.4, -1.5, 0))
	c.key("Charm", 11, rot=(0, 0.4, 0))
	return c


def mag_swap(c, f0):
	# Straight box mag: released, falls away fast, a fresh one comes up and seats with a slap. Done 40 frames after f0.
	gunkit.mag_swap(c, f0, drop=0.62, fwd=0.05, tilt=-12)  # round 2: mag-drop timing + MagOut/MagIn markers
	for f, a in ((f0 + 3, 5), (f0 + 7, -4), (f0 + 12, 2.5), (f0 + 17, -1), (f0 + 37, 8), (f0 + 41, -5), (f0 + 45, 2.5), (f0 + 49, -1)):
		c.key("Charm", f, rot=(a * 0.4, a, 0))


def mag_root(c, f0):
	# Roll the mag side toward the player and lift the muzzle; a jolt when the mag is slapped home.
	c.key("Root", f0 - 1, (0, 0, 0.01), (8, -4, 2))
	c.key("Root", f0 + 11, (0, 0, 0.018), (10, -5, 2.5))
	c.key("Root", f0 + 33, (0, 0, 0.014), (9.5, -5, 2))
	c.key("Root", f0 + 37, (0, 0, 0.028), (12, -7, 2.5))
	c.key("Root", f0 + 40, (0, 0, 0.012), (9, -4.5, 2))


def reload_tactical():
	c = gunkit.Clip(GUN, "Reload", 72)
	mag_swap(c, 11)
	mag_root(c, 11)
	c.key("Root", 62, (0, 0, 0.004), (2, -1, 0.5))
	c.key("Root", 69, (0, 0, 0), (0.3, 0, 0))
	return c


def reload_empty():
	L = 97
	c = gunkit.Clip(GUN, "ReloadEmpty", L)
	mag_swap(c, 11)  # mag f11..f51 = 52% of the clip
	mag_root(c, 11)
	# Turn to show the left side, pull the side charging handle (from f80 = 82%), release it.
	c.key("Root", 70, (0, 0, 0.01), (4, -3, -2))
	c.key("Root", 80, (0, 0, 0.008), (3, -3, -3))
	c.key("Root", 84, (-0.018, 0, 0.01), (4.5, -4, -3.5))
	c.key("Root", 88, (0.014, 0, 0.004), (2, -1, -2))
	c.key("Root", 93, (0, 0, 0), (0.4, 0, -0.3))
	c.key("ChargingHandle", 80)
	c.key("ChargingHandle", 84, (-0.17, 0, 0))
	c.key("ChargingHandle", 86, (-0.17, 0, 0))
	c.key("ChargingHandle", 88)
	c.key("ChargingHandle", 89, (-0.005, 0, 0))
	c.key("ChargingHandle", 90)
	for f, a in ((85, -6), (89, 9), (92, -4.5), (95, 2)):
		c.key("Charm", f, rot=(a * 0.4, a, 0))
	return c


def draw():
	# First draw of a life (stretched to firstEquipTime 0.8 s): thumb the selector off safe, then the support
	# hand racks the side charging handle (pulled 36-48%, released 52%) and the gun jolts as the bolt runs home.
	# Same timing as the Vandal's Draw so the viewmodel's draw track lines up.
	L = 31
	c = gunkit.Clip(GUN, "Draw", L)
	c.key("FireSelector", 3)
	c.key("FireSelector", 6, rot=(0, 14, 0))
	c.key("FireSelector", 7, rot=(0, 12, 0))
	c.key("FireSelector", 9)
	# Roll (+X) lifts the left side into view; yaw (-Z) swings the muzzle right so it faces the camera.
	c.key("Root", 8, (0, 0, 0), (6, 0, -5))
	c.key("Root", 12, (0, 0, 0.005), (8.5, -1, -6.5))
	c.key("Root", 15, (-0.025, 0, 0.007), (9.5, -2, -7.5))  # handle pulled: the gun gives a little
	c.key("Root", 17, (0.016, 0, 0.003), (5.5, 1.2, -4.5))  # bolt home (lighter jolt than the Vandal)
	c.key("Root", 19, (0, 0, 0.002), (3.8, -0.4, -3.2))
	c.key("Root", 25, (0, 0, 0), (0.7, 0, -0.5))
	c.key("ChargingHandle", 12)
	c.key("ChargingHandle", 15, (-0.17, 0, 0))
	c.key("ChargingHandle", 16, (-0.17, 0, 0))
	c.key("ChargingHandle", 17)
	c.key("ChargingHandle", 18, (-0.006, 0, 0))
	c.key("ChargingHandle", 19)
	for f, a in ((5, -4.5), (9, 3.5), (13, -2.5), (16, 7), (19, -5), (22, 3), (26, -1)):
		c.key("Charm", f, rot=(a * 0.4, a, 0))
	return c


def inspect():
	# Runs alongside the viewmodel's Inspect track (2.8 s: right side shown 16-42%, left side 60-82%):
	# a tap on the mag while the right side shows, then a press check on the left side.
	L = 67
	c = gunkit.Clip(GUN, "Inspect", L)
	c.key("Mag", 13)
	c.key("Mag", 15, (0, 0, -0.022), (0, -1.2, 0))
	c.key("Mag", 16, (0, 0, 0.004), (0, 0.3, 0))  # tapped home
	c.key("Mag", 18)
	c.key("ChargingHandle", 42)
	c.key("ChargingHandle", 45, (-0.07, 0, 0))  # half back: brass in the chamber
	c.key("ChargingHandle", 50, (-0.07, 0, 0))
	c.key("ChargingHandle", 52)
	c.key("ChargingHandle", 53, (-0.004, 0, 0))
	c.key("ChargingHandle", 54)
	c.key("Root", 15, (0, 0, 0.004), (0.5, 0, 0))
	c.key("Root", 17)
	c.key("Root", 52, (0.005, 0, 0), (0, 0.35, 0))
	c.key("Root", 54)
	for f, a in ((6, 8), (11, -6), (16, 5), (21, -2.5), (28, 1.8), (36, -8), (41, 10), (46, -5.5), (52, 4.5),
			(57, -2.5), (62, 1.2)):
		c.key("Charm", f, rot=(a * 0.4, a, 0))
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
