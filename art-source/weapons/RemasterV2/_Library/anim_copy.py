# anim_copy.py: gives a RemasterV2 rig the ORIGINAL weapon's actions. The rebuilds keep the original bone names,
# axes, roll and rest orientation, so the keyed motion carries over unchanged (frame ranges, gg_markers, NLA track
# names). Source actions are appended read-only from art-source/weapons/<Id>.blend as REF_<Id>_<Clip>.
# Run through Blender MCP after the weapon's builder.

import bpy


def apply(gun, names):
	rig = bpy.data.objects[gun + "_Rig"]
	ad = rig.animation_data or rig.animation_data_create()
	for t in list(ad.nla_tracks):
		ad.nla_tracks.remove(t)
	ad.action = None
	out = {}
	for n in names:
		src = bpy.data.actions["REF_%s_%s" % (gun, n)]
		name = "%s_%s" % (gun, n)
		old = bpy.data.actions.get(name)
		if old is not None:
			bpy.data.actions.remove(old)
		act = src.copy()
		act.name = name
		act.use_fake_user = True
		act["rv2"] = True
		tr = ad.nla_tracks.new()
		tr.name = n
		st = tr.strips.new(name, int(act.frame_range[0]), act)
		try:
			if act.slots:
				st.action_slot = act.slots[0]
		except Exception:
			pass
		tr.mute = True
		out[n] = [act.frame_range[0], act.frame_range[1], dict(act["gg_markers"]) if "gg_markers" in act.keys() else {}]
	return out


def pose(gun, action, frame):
	# Clears the pose first: channels an action doesn't key would otherwise keep the last clip's values.
	rig = bpy.data.objects[gun + "_Rig"]
	for pb in rig.pose.bones:
		pb.location = (0, 0, 0)
		pb.rotation_euler = (0, 0, 0)
		pb.rotation_quaternion = (1, 0, 0, 0)
	ad = rig.animation_data
	act = bpy.data.actions[action] if action else None
	ad.action = act
	if act is not None:
		try:
			ad.action_slot = act.slots[0]
		except Exception:
			pass
	bpy.context.window.scene.frame_set(frame)
	return frame


def rest(gun):
	rig = bpy.data.objects[gun + "_Rig"]
	if rig.animation_data:
		rig.animation_data.action = None
	for pb in rig.pose.bones:
		pb.location = (0, 0, 0)
		pb.rotation_euler = (0, 0, 0)
		pb.rotation_quaternion = (1, 0, 0, 0)
	bpy.context.window.scene.frame_set(1)
