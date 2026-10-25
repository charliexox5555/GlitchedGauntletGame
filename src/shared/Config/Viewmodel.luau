--!strict
-- First-person viewmodel feel. Positions are in camera space (studs, +X right,
-- +Y up, -Z forward) for the scaled-down gun.

return table.freeze({
	SCALE = 0.5, -- guns are modelled at world size; first person shows them smaller
	ADS_DISTANCE = 0.95, -- camera to the AimPoint while aiming
	ADS_EASE = 0.5, -- 0 = linear, 1 = very eased

	-- Arms run from these shoulder points to the gun's RightGrip / LeftGrip.
	SHOULDER_RIGHT = Vector3.new(0.62, -0.95, 0.35),
	SHOULDER_LEFT = Vector3.new(-0.5, -1.0, 0.2),
	ARM_THICKNESS = 0.2,
	HAND_SIZE = Vector3.new(0.17, 0.2, 0.22),
	SLEEVE_COLOR = Color3.fromHex("1C2030"),
	CUFF_COLOR = Color3.fromHex("00E5FF"),

	-- Sway follows mouse movement; bob follows walking.
	SWAY_AMOUNT = 0.9,
	SWAY_MAX = 0.12, -- radians
	SWAY_STIFFNESS = 180,
	SWAY_DAMPING = 18,
	BOB_SPEED = 9,
	BOB_AMOUNT = Vector2.new(0.025, 0.018),
	ADS_SWAY_SCALE = 0.2,

	-- Per-shot kick on the viewmodel (scaled by the gun's recoil.up).
	KICK_BACK = 0.05,
	KICK_ROTATE = 0.035,
	RECOIL_STIFFNESS = 260,
	RECOIL_DAMPING = 24,

	SPRINT_OFFSET = CFrame.new(0.12, -0.12, 0.08) * CFrame.Angles(-0.3, 0.75, 0.25),
	EQUIP_DROP = CFrame.new(0, -0.7, 0.1) * CFrame.Angles(-1.0, 0.2, 0),
})
