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
-- Decided 2026-11-21 (round 2): stays OFF; the clips are the default. With
-- the gun swung about the real shoulder, IK tied or slightly beat the clips
-- from the owner's angle (level, sights, 35 up, 30 down, sidearm), but the
-- owner saw no difference, bots and a weapon swap in IK mode are not
-- verified in the engine, and its one clear win (the head looking down at
-- the target) is now in the clips' down holds. Overnight plan note, TP.
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
	-- Seconds after a gun appears before the IK may move it (GripController
	-- reads the gun's resting grip first; the draw clip plays meanwhile).
	NEW_GUN_WAIT = 0.25,

	-- The gun's handle from the right shoulder joint (UpperTorso's
	-- RightShoulderRigAttachment), in the body's yaw frame (x right, y up,
	-- -z ahead), level aim; measured on tools/anim/tp_rig from the hold
	-- clips' solved poses (LONG_HIP = tp_rig HOLD_OFFSET), so IK mode starts
	-- where the clips are. The gun swings about that joint as you look up
	-- and down, like the clips (round 2; it hung off the head before).
	LONG_HIP = Vector3.new(-0.454, 0.086, -1.105),
	LONG_ADS = Vector3.new(-0.512, 0.236, -1.269),
	PISTOL_HIP = Vector3.new(-0.284, 0.245, -1.831),
	PISTOL_ADS = Vector3.new(-0.333, 0.401, -1.847),
	-- Fallback when a rig has no shoulder attachment: from the head's centre.
	LONG_HIP_HEAD = Vector3.new(0.445, -0.706, -0.652),
	PISTOL_HIP_HEAD = Vector3.new(0.655, -0.553, -1.474),
	-- At sights the head rolls onto the stock, as the clips do (degrees).
	NECK_ADS_ROLL = -9,
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
