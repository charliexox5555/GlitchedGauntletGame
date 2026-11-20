--!strict
-- Third-person IK hands, the RIVALS way (prototype, overnight 2026-11-20;
-- vault/03 Research/Rivals Reference/Body, Viewmodel, Guns and VFX.md and
-- vault/05 Production/Overnight 2026-11-20 Animation Pass.md, lane TP).
--
-- OFF by default: the keyed hold clips (Simulation/Poses) stay live.
-- ON: Controllers/TpIkController places each watched character's gun from
-- its aim (the head's position, the body's yaw, the replicated aim pitch,
-- swung about the right shoulder), puts the right hand on the gun by an
-- IKControl (GripController keeps the left hand on it), and pitches the
-- waist and neck 0.25 / 0.75 of the aim through the joints' attachments.
-- Poses then holds the level clip only (the pitch comes from the joints).
--
-- How to flip it:
--   * for good: ENABLED = true below.
--   * in a Studio playtest, live: set the Workspace attribute `TpIk`
--     (true / false) on the Server; it wins over ENABLED in Studio only.

return table.freeze({
	ENABLED = false,
	DEV_ATTRIBUTE = "TpIk", -- Workspace attribute, Studio only

	-- The IK weight blends; it never switches (switching an IKControl pops,
	-- Third Person Overhaul §7 / §22). Seconds for a full fade.
	FADE_IN = 0.2,
	FADE_OUT = 0.12,

	-- The gun's handle from the head's centre, in the body's yaw frame
	-- (x right, y up, -z ahead), level aim; measured on tools/anim/tp_rig
	-- from the hold clips' solved poses, so IK mode starts where the clips are.
	LONG_HIP = Vector3.new(0.445, -0.706, -0.652),
	LONG_ADS = Vector3.new(0.263, -0.518, -0.743),
	PISTOL_HIP = Vector3.new(0.655, -0.553, -1.474),
	PISTOL_ADS = Vector3.new(0.546, -0.382, -1.482),
	-- Where the gun swings up and down (the right shoulder, from the head;
	-- tp_clips AIM_PIVOT), so looking down the gun goes out, not into the chest.
	PIVOT = Vector3.new(0.6, -0.88, 0.51),
	-- Aim pitch limits for the gun (radians) and the body split (RIVALS).
	PITCH_MAX = math.rad(70),
	WAIST_SHARE = 0.25,
	NECK_SHARE = 0.75,
	PITCH_SMOOTHING = 14, -- 1/s, like Config/Animations AIM_SMOOTHING
	ADS_SMOOTHING = 12, -- 1/s, like Config/Animations ADS_SMOOTHING
	-- The right elbow's pole, in UpperTorso space (down, out and back).
	RIGHT_POLE = Vector3.new(1.6, -1.6, 0.9),
	-- Further than this from its root, a gun target is ignored (RIVALS: 16).
	MAX_GUN_DISTANCE = 6,
})
