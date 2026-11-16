# anim_vandal_v2.py: gives the RemasterV2 Vandal rig the original Vandal actions (same bone names, axes and
# rest orientation, so the keyed motion carries over unchanged): Vandal_Fire / Reload / ReloadEmpty / Draw /
# Inspect at 24 fps, end frames 12 / 97 / 97 / 36 / 67, gg_markers MagOut 15 / MagIn 30, semantic NLA tracks.
# Source: the original art-source/weapons/Vandal.blend, appended (read only) into the REF_Vandal_Original
# scene as REF_* actions. Run through Blender MCP after build_vandal_v2.py.

import bpy

NAMES = ["Fire", "Reload", "ReloadEmpty", "Draw", "Inspect"]


def apply(rig_name="Vandal_Rig"):
	rig = bpy.data.objects[rig_name]
	ad = rig.animation_data or rig.animation_data_create()
	for t in list(ad.nla_tracks):
		ad.nla_tracks.remove(t)
	ad.action = None
	out = {}
	for n in NAMES:
		src = bpy.data.actions["REF_Vandal_" + n]
		name = "Vandal_" + n
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


def pose(rig_name, action, frame):
	# Shows one action at one frame for review renders (no NLA mixing).
	rig = bpy.data.objects[rig_name]
	ad = rig.animation_data
	act = bpy.data.actions[action] if action else None
	ad.action = act
	if act is not None:
		try:
			ad.action_slot = act.slots[0]
		except Exception:
			pass
	sc = bpy.context.window.scene
	sc.frame_set(frame)
	return frame
