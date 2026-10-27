# anim_vandal.py: keyframes the Vandal's clips on its rig and stores them as NLA tracks (what
# tools/blender/export_weapons.py samples):
#   Fire         kick, bolt + charging handle cycle, trigger, buddy sway
#   Reload       tactical: AK rock-out / rock-in, then a short tug on the charging handle
#   ReloadEmpty  the same mag swap, then a full charging-handle rack with the gun turned to show it
#   Draw         first draw of a life (Valorant style): safety off, the support hand racks the
#                charging handle all the way back, holds it, lets it slam home
#   Inspect      mag tap, then a press check (charging handle half back), buddy swinging
#
#   Run inside Blender after build_vandal.py:
#     g = {"__name__": "anim"}; exec(compile(open(path).read(), path, "exec"), g); g["animate"]()
#
# Bone space: every bone points along world +Y with no roll, so a bone's local X/Y/Z are the gun's
# +X (muzzle) / +Y (left) / +Z (up). Rotation about Y with a negative angle lifts the muzzle (and
# swings a mag's bottom forward); a positive angle pulls the trigger back.
#
# Timing rules from the game (Config/Viewmodel + ViewmodelController):
#   - Every clip but Fire is stretched to its time in the game (reload, empty reload, first draw, the
#     inspect track's length), so only proportions matter.
#   - In Reload, ReloadEmpty, Draw and Inspect the left hand follows the first part the clip moves (Mag,
#     grabbed at its bottom), then a later one (ChargingHandle) only if their windows, each widened by
#     FOLLOW_LEAD = 0.14 of the clip, don't overlap. So in both reloads (97 frames) the mag is done by
#     53% and the charging handle moves from 80%. The Bolt is NOT moved in these clips (it sits on the
#     far side; the right hand would take it).
#   - Foley is read off the clips (ViewmodelController.clipBeats): mag out when the Mag starts moving,
#     mag in when it stops, the rack when the ChargingHandle stops.
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
		self.markers = {}  # name -> frame (exported as clip fractions, see gunkit.Clip)

	def key(self, bone, frame, loc=(0, 0, 0), rot=(0, 0, 0)):
		self.keys.setdefault(bone, {})[frame] = (loc, rot)

	def rest(self, bone, *frames):
		for f in frames:
			self.key(bone, f)

	def bake(self, r):
		act = new_action(self.name)
		if self.markers:
			act["gg_markers"] = dict(self.markers)
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


def mag_swap(c):
	"""The AK rock-out / rock-in shared by both reloads (mag seated by f51)."""
	# Root: roll the mag side toward the player and lift the muzzle a little; jolts on the mag seat and
	# the charging-handle release. (The viewmodel adds its own reload body motion on top.)
	c.key("Root", 10, (0, 0, 0.01), (9, -4, 2))
	c.key("Root", 22, (0, 0, 0.02), (11, -5, 3))
	c.key("Root", 44, (0, 0, 0.015), (10, -5, 2))
	c.key("Root", 48, (0.0, 0, 0.03), (12.5, -7.5, 2.5))  # mag slammed home
	c.key("Root", 51, (0, 0, 0.012), (9.5, -4.5, 2))
	# Mag (round 2, mag drop): rock forward off the catch and fall out of view fast (MagOut: the game spawns the
	# falling copy and hides the Mag), a fresh one comes up from below (MagIn), rocks in and locks (done by f51).
	c.key("Mag", 11)
	c.key("Mag", 14, (0.012, 0, -0.02), (0, -9, 0))
	c.key("Mag", 17, (0.06, 0, -0.78), (0, -22, 0))
	c.key("Mag", 30, (0.1, 0, -0.75), (0, -24, 0))
	c.key("Mag", 40, (0.05, 0, -0.2), (0, -14, 0))
	c.markers["MagOut"] = 15
	c.markers["MagIn"] = 30
	c.key("Mag", 44, (0.018, 0, -0.03), (0, -10, 0))
	c.key("Mag", 47, (0.004, 0, 0), (0, -6, 0))  # front lug caught
	c.key("Mag", 49, (0, 0, 0), (0, 1.2, 0))  # rocked back, click
	c.key("Mag", 51)


def reload():
	# Tactical: the mag swap (seated at 53%), then the gun turns a little and the support hand gives the
	# charging handle a short tug (80-88%) to be sure: the action moves, it doesn't need a full rack.
	L = 97
	c = Clip("Reload", L)
	mag_swap(c)
	c.key("Root", 58, (0, 0, 0.006), (4, -2, 0))
	c.key("Root", 70, (0, 0, 0.008), (5, -2.5, -2.5))  # turn to show the charging handle
	c.key("Root", 78, (0, 0, 0.008), (5.5, -3, -3))
	c.key("Root", 82, (-0.012, 0, 0.009), (6, -3.4, -3.4))  # tugged
	c.key("Root", 86, (0.01, 0, 0.004), (3, -1, -2))  # let go
	c.key("Root", 92, (0, 0, 0), (0.4, 0, -0.3))
	c.key("ChargingHandle", 78)
	c.key("ChargingHandle", 82, (-0.12, 0, 0))
	c.key("ChargingHandle", 84, (-0.12, 0, 0))
	c.key("ChargingHandle", 86)
	c.key("ChargingHandle", 87, (-0.005, 0, 0))
	c.key("ChargingHandle", 88)
	for f, a in ((14, 6), (18, -5), (23, 3), (28, -1.5), (48, 9), (52, -6), (56, 3), (60, -1), (83, -4),
			(87, 6), (90, -3), (94, 1)):
		c.key("Charm", f, rot=(a * 0.4, a, 0))
	return c


def reload_empty():
	L = 97
	c = Clip("ReloadEmpty", L)
	mag_swap(c)
	c.key("Root", 66, (0, 0, 0.01), (6, -3, -3))  # turn well round to show the charging handle
	c.key("Root", 77, (0, 0, 0.01), (8, -4, -5))
	c.key("Root", 82, (-0.03, 0, 0.012), (9, -5, -6))  # pulled all the way: the gun gives
	c.key("Root", 86, (-0.03, 0, 0.012), (9, -5.2, -6))
	c.key("Root", 88, (0.022, 0, 0.004), (4, -0.5, -3))  # released: slams home
	c.key("Root", 91, (0, 0, 0.003), (2, -1.2, -1.5))
	c.key("Root", 95, (0, 0, 0), (0.4, 0, -0.3))
	# Charging handle: a full rack from 80%: all the way back, held, released and slams forward.
	c.key("ChargingHandle", 78)
	c.key("ChargingHandle", 82, (-0.25, 0, 0))
	c.key("ChargingHandle", 86, (-0.25, 0, 0))
	c.key("ChargingHandle", 88)
	c.key("ChargingHandle", 89, (-0.012, 0, 0))
	c.key("ChargingHandle", 90)
	# Selector untouched; the buddy swings with each jolt.
	for f, a in ((14, 6), (18, -5), (23, 3), (28, -1.5), (48, 9), (52, -6), (56, 3), (60, -1), (85, -7), (89, 10), (92, -5), (95, 2)):
		c.key("Charm", f, rot=(a * 0.4, a, 0))
	return c


def draw():
	# First draw (stretched to firstEquipTime, ~0.9 s), Valorant style: the gun comes up with the
	# selector thumbed off safe, the support hand takes the charging handle and racks it all the way
	# back (28-42%), holds it a beat (42-53%), lets it slam home (56%) with a jolt through the gun, and
	# goes back to the handguard. The viewmodel's Draw track rolls the gun to show this side.
	L = 36
	c = Clip("Draw", L)
	c.key("FireSelector", 3)
	c.key("FireSelector", 6, rot=(0, 14, 0))
	c.key("FireSelector", 7, rot=(0, 12, 0))
	c.key("FireSelector", 9)
	# Roll (+X) lifts the left side into view; yaw (-Z) swings the muzzle right so it faces the camera.
	c.key("Root", 6, (0, 0, 0), (6, 0, -5))
	c.key("Root", 10, (0, 0, 0.005), (10, -1, -8))
	c.key("Root", 15, (-0.035, 0, 0.009), (12, -2.5, -9))  # handle pulled: the gun gives
	c.key("Root", 19, (-0.035, 0, 0.009), (12, -2.6, -9))
	c.key("Root", 21, (0.028, 0, 0.004), (6, 2, -5))  # slammed home
	c.key("Root", 23, (0, 0, 0.002), (4.5, -0.8, -4))
	c.key("Root", 29, (0, 0, 0), (1, 0, -0.8))
	c.key("ChargingHandle", 10)
	c.key("ChargingHandle", 15, (-0.25, 0, 0))
	c.key("ChargingHandle", 19, (-0.25, 0, 0))
	c.key("ChargingHandle", 20)
	c.key("ChargingHandle", 21, (-0.012, 0, 0))
	c.key("ChargingHandle", 22)
	for f, a in ((5, -5), (9, 4), (14, -3), (20, 9), (23, -7), (26, 4), (30, -1.5)):
		c.key("Charm", f, rot=(a * 0.4, a, 0))
	return c


def inspect():
	# Runs alongside the viewmodel's Inspect track (2.8 s: right side shown 16-42%, left side 60-82%).
	# A tap on the mag while the right side shows, then a press check on the left side.
	L = 67
	c = Clip("Inspect", L)
	c.key("Mag", 13)
	c.key("Mag", 15, (0, 0, -0.025), (0, -2, 0))
	c.key("Mag", 16, (0, 0, 0.004), (0, 0.4, 0))  # tapped home
	c.key("Mag", 18)
	c.key("ChargingHandle", 42)
	c.key("ChargingHandle", 45, (-0.085, 0, 0))  # half back: brass in the chamber
	c.key("ChargingHandle", 50, (-0.085, 0, 0))
	c.key("ChargingHandle", 52)
	c.key("ChargingHandle", 53, (-0.005, 0, 0))
	c.key("ChargingHandle", 54)
	c.key("Root", 15, (0, 0, 0.004), (0.6, 0, 0))
	c.key("Root", 17)
	c.key("Root", 52, (0.006, 0, 0), (0, 0.4, 0))
	c.key("Root", 54)
	for f, a in ((6, 9), (11, -7), (16, 6), (21, -3), (28, 2), (36, -9), (41, 11), (46, -6), (52, 5),
			(57, -3), (62, 1.5)):
		c.key("Charm", f, rot=(a * 0.4, a, 0))
	return c


def animate():
	r = rig()
	if r.mode != "POSE":
		bpy.context.view_layer.objects.active = r
	scene = bpy.context.scene
	scene.render.fps = FPS
	out = {}
	for clip in (fire(), reload(), reload_empty(), draw(), inspect()):
		act = clip.bake(r)
		out[clip.name] = {"frames": clip.last, "bones": sorted(clip.keys)}
	scene.frame_set(1)
	return out


if __name__ == "__main__":
	print(animate())
