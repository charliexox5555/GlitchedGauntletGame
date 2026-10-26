# anim_phantom.py: keyframes the Phantom's Fire, Reload (tactical) and ReloadEmpty clips as NLA tracks
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
	# Straight box mag: release, drop out of view, come back up, seat with a slap. Done 40 frames after f0.
	c.key("Mag", f0)
	c.key("Mag", f0 + 3, (0.004, 0, -0.025), (0, -2, 0))
	c.key("Mag", f0 + 9, (0.03, 0, -0.3), (0, -8, 0))
	c.key("Mag", f0 + 14, (0.05, 0, -0.64), (0, -12, 0))
	c.key("Mag", f0 + 22, (0.04, 0, -0.7), (0, -10, 0))
	c.key("Mag", f0 + 29, (0.02, 0, -0.24), (0, -5, 0))
	c.key("Mag", f0 + 34, (0.006, 0, -0.035), (0, -1.5, 0))
	c.key("Mag", f0 + 37, (0, 0, 0.007), (0, 0.6, 0))  # slapped home
	c.key("Mag", f0 + 40)
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


def animate():
	bpy.context.scene.render.fps = FPS
	out = {}
	for clip in (fire(), reload_tactical(), reload_empty()):
		clip.bake()
		out[clip.name] = {"frames": clip.last, "bones": sorted(clip.keys)}
	bpy.context.scene.frame_set(1)
	return out


if __name__ == "__main__":
	print(animate())
