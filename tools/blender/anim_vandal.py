# anim_vandal.py: keyframes the Vandal's Fire and Reload clips on its rig and
# stores them as NLA tracks named "Fire" / "Reload" (what tools/blender/export_weapons.py samples).
#
#   Run inside Blender after build_vandal.py:
#     g = {"__name__": "anim"}; exec(compile(open(path).read(), path, "exec"), g); g["animate"]()
#
# Bone space: every bone points along world +Y with no roll, so a bone's local X/Y/Z are the gun's
# +X (muzzle) / +Y (left) / +Z (up). Rotation about Y with a negative angle lifts the muzzle (and
# swings a mag's bottom forward); a positive angle pulls the trigger back.
#
# Timing rules from the game (Config/Viewmodel + ViewmodelController):
#   - Reload is stretched to the gun's reloadTime, so only proportions matter.
#   - The left hand follows the first part the Reload clip moves (Mag, grabbed at its bottom), then a later
#     one (ChargingHandle) only if their windows, each widened by FOLLOW_LEAD = 0.14 of the clip, don't
#     overlap. So the mag is done by 52% and the charging handle moves from 82%. The Bolt is NOT moved in
#     Reload (it comes before ChargingHandle in RELOAD_FOLLOW and sits on the far side).
#   - Fire restarts on every shot; it is short and settles fast.

import bpy, math

GUN = "Vandal"
FPS = 24


def rig():
	return bpy.data.objects[GUN + "_Rig"]


def new_action(name):
	old = bpy.data.actions.get(GUN + "_" + name)
	if old:
		bpy.data.actions.remove(old)
	return bpy.data.actions.new(GUN + "_" + name)


class Clip:
	def __init__(self, name, last):
		self.name = name
		self.last = last
		self.keys = {}  # bone -> {frame: (loc, rot_deg)}

	def key(self, bone, frame, loc=(0, 0, 0), rot=(0, 0, 0)):
		self.keys.setdefault(bone, {})[frame] = (loc, rot)

	def rest(self, bone, *frames):
		for f in frames:
			self.key(bone, f)

	def bake(self, r):
		act = new_action(self.name)
		ad = r.animation_data or r.animation_data_create()
		ad.action = act
		bones = r.pose.bones
		for b in bones:
			b.rotation_mode = "XYZ"
		for bone, frames in self.keys.items():
			pb = bones[bone]
			# Rest at both ends so the clip starts and ends on the rest pose.
			frames.setdefault(1, ((0, 0, 0), (0, 0, 0)))
			frames.setdefault(self.last, ((0, 0, 0), (0, 0, 0)))
			for f, (loc, rot) in sorted(frames.items()):
				pb.location = loc
				pb.rotation_euler = tuple(math.radians(a) for a in rot)
				pb.keyframe_insert("location", frame=f, group=bone)
				pb.keyframe_insert("rotation_euler", frame=f, group=bone)
		for b in bones:
			b.location = (0, 0, 0)
			b.rotation_euler = (0, 0, 0)
		ad.action = None
		track = next((t for t in ad.nla_tracks if t.name == self.name), None)
		if track:
			ad.nla_tracks.remove(track)
		track = ad.nla_tracks.new()
		track.name = self.name
		track.strips.new(self.name, 1, act)
		track.mute = True  # strips are only for the exporter; keep the rig at rest in the viewport
		return act


def fire():
	c = Clip("Fire", 12)
	# Recoil: the gun kicks back and the muzzle climbs, then settles with a tiny overshoot.
	c.key("Root", 2, (-0.05, 0, 0.008), (0, -3.2, 0.4))
	c.key("Root", 3, (-0.065, 0, 0.01), (0, -4.2, 0.5))
	c.key("Root", 5, (-0.035, 0, 0.006), (0, -2.4, 0.2))
	c.key("Root", 7, (-0.01, 0, 0.001), (0, -0.6, 0))
	c.key("Root", 9, (0.004, 0, 0), (0, 0.25, 0))
	c.key("Root", 11)
	# The bolt carrier cycles and the left-side charging handle rides on it (AK-style).
	for bone in ("Bolt", "ChargingHandle"):
		c.key(bone, 2, (-0.13, 0, 0))
		c.key(bone, 3, (-0.15, 0, 0))
		c.key(bone, 4, (-0.1, 0, 0))
		c.key(bone, 5, (-0.03, 0, 0))
		c.key(bone, 6)
	c.key("Trigger", 2, rot=(0, 16, 0))
	c.key("Trigger", 4, rot=(0, 16, 0))
	c.key("Trigger", 6, rot=(0, 4, 0))
	c.key("Trigger", 7)
	# The buddy lags the kick and swings out a little, then settles.
	c.key("Charm", 3, rot=(4, 11, 0))
	c.key("Charm", 5, rot=(-2, -7, 0))
	c.key("Charm", 7, rot=(1.5, 4, 0))
	c.key("Charm", 9, rot=(-0.5, -1.8, 0))
	c.key("Charm", 11, rot=(0, 0.5, 0))
	return c


def reload():
	L = 97
	c = Clip("Reload", L)
	# Root: roll the mag side toward the player and lift the muzzle a little; jolts on the mag seat and
	# the charging-handle release. (The viewmodel adds its own reload body motion on top.)
	c.key("Root", 10, (0, 0, 0.01), (9, -4, 2))
	c.key("Root", 22, (0, 0, 0.02), (11, -5, 3))
	c.key("Root", 44, (0, 0, 0.015), (10, -5, 2))
	c.key("Root", 48, (0.0, 0, 0.03), (12.5, -7.5, 2.5))  # mag slammed home
	c.key("Root", 51, (0, 0, 0.012), (9.5, -4.5, 2))
	c.key("Root", 70, (0, 0, 0.01), (4, -3, -2))  # turn to show the charging handle
	c.key("Root", 80, (0, 0, 0.008), (3, -3, -3))
	c.key("Root", 84, (-0.02, 0, 0.01), (4.5, -4, -3.5))  # pulled
	c.key("Root", 88, (0.015, 0, 0.004), (2, -1, -2))  # released: snaps forward
	c.key("Root", 93, (0, 0, 0), (0.4, 0, -0.3))
	# Mag: rock forward off the catch, drop out of view, come back up, rock in and lock (done by f51 = 52%).
	c.key("Mag", 11)
	c.key("Mag", 15, (0.012, 0, -0.012), (0, -9, 0))
	c.key("Mag", 19, (0.05, 0, -0.16), (0, -16, 0))
	c.key("Mag", 25, (0.12, 0, -0.62), (0, -28, 0))
	c.key("Mag", 33, (0.1, 0, -0.7), (0, -24, 0))
	c.key("Mag", 40, (0.05, 0, -0.2), (0, -14, 0))
	c.key("Mag", 44, (0.018, 0, -0.03), (0, -10, 0))
	c.key("Mag", 47, (0.004, 0, 0), (0, -6, 0))  # front lug caught
	c.key("Mag", 49, (0, 0, 0), (0, 1.2, 0))  # rocked back, click
	c.key("Mag", 51)
	# Charging handle: pulled back from 82%, released and slams forward.
	c.key("ChargingHandle", 80)
	c.key("ChargingHandle", 84, (-0.2, 0, 0))
	c.key("ChargingHandle", 86, (-0.2, 0, 0))
	c.key("ChargingHandle", 88)
	c.key("ChargingHandle", 89, (-0.006, 0, 0))
	c.key("ChargingHandle", 90)
	# Selector untouched; the buddy swings with each jolt.
	for f, a in ((14, 6), (18, -5), (23, 3), (28, -1.5), (48, 9), (52, -6), (56, 3), (60, -1), (85, -7), (89, 10), (92, -5), (95, 2)):
		c.key("Charm", f, rot=(a * 0.4, a, 0))
	return c


def animate():
	r = rig()
	if r.mode != "POSE":
		bpy.context.view_layer.objects.active = r
	scene = bpy.context.scene
	scene.render.fps = FPS
	out = {}
	for clip in (fire(), reload()):
		act = clip.bake(r)
		out[clip.name] = {"frames": clip.last, "bones": sorted(clip.keys)}
	scene.frame_set(1)
	return out


if __name__ == "__main__":
	print(animate())
