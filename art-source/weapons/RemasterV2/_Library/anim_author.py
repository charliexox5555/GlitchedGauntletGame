# anim_author.py: authors new RemasterV2 weapon clips (Blender MCP only). Keys pose-bone location / rotation_euler
# (Euler XYZ, bone-local axes: x along the gun, z up, y gun-left) into a new action, then files it as a muted NLA
# track named after the clip, the same way anim_copy.py files the copied originals (the exporter bakes NLA strips).
#   author(gun, "Reload", 60, {"Barrels": {"rot": [(1, (0, 0, 0)), (13, (0, 1.06, 0))]}, ...}, markers={"Open": 13})

import bpy


def author(gun, clip, end, tracks, markers=None, fps=24):
	rig = bpy.data.objects[gun + "_Rig"]
	ad = rig.animation_data or rig.animation_data_create()
	name = "%s_%s" % (gun, clip)
	old = bpy.data.actions.get(name)
	if old is not None:
		bpy.data.actions.remove(old)
	for t in list(ad.nla_tracks):
		if t.name == clip:
			ad.nla_tracks.remove(t)
	act = bpy.data.actions.new(name)
	act.use_fake_user = True
	act["rv2"] = True
	act["rv2_authored"] = "2026-11-08"
	ad.action = act
	for pb in rig.pose.bones:
		pb.rotation_mode = "XYZ"
		pb.location = (0, 0, 0)
		pb.rotation_euler = (0, 0, 0)
	for bone, ch in tracks.items():
		pb = rig.pose.bones[bone]
		for f, v in ch.get("loc", []):
			pb.location = v
			pb.keyframe_insert("location", frame=f, group=bone)
		for f, v in ch.get("rot", []):
			pb.rotation_euler = v
			pb.keyframe_insert("rotation_euler", frame=f, group=bone)
	act.use_frame_range = True
	act.frame_start = 1
	act.frame_end = end
	if markers:
		act["gg_markers"] = dict(markers)
	ad.action = None
	for pb in rig.pose.bones:
		pb.location = (0, 0, 0)
		pb.rotation_euler = (0, 0, 0)
	tr = ad.nla_tracks.new()
	tr.name = clip
	st = tr.strips.new(name, 1, act)
	try:
		if act.slots:
			st.action_slot = act.slots[0]
	except Exception:
		pass
	tr.mute = True
	return {"clip": clip, "end": end, "bones": sorted(tracks), "seconds_at_24": round(end / fps, 2)}


def sway(keys, amp=0.12, axis=1):
	# A damped charm swing after each jolt frame: [(frame, strength)] -> rot keys around one axis.
	out = [(1, (0, 0, 0))]
	for f, s in keys:
		for i, k in enumerate((1.0, -0.7, 0.4, -0.15)):
			v = [0.0, 0.0, 0.0]
			v[axis] = amp * s * k
			out.append((f + 3 * i, tuple(v)))
	last = max(f for f, _ in out)
	out.append((last + 4, (0, 0, 0)))
	return sorted(out)
