--!strict
-- First-person viewmodel feel and animation data (Gunplay.md §6). Positions
-- are in camera space (studs, +X right, +Y up, -Z forward) for the scaled-down
-- gun. Rotations in keyframes and poses are degrees (X pitch, Y yaw, Z roll),
-- applied as CFrame.Angles around the track's pivot.

export type Key = {
	t: number, -- 0..1 through the track
	pos: Vector3,
	rot: Vector3, -- degrees
	-- Easing for the segment that ends at this key (default Sine InOut).
	style: Enum.EasingStyle?,
	dir: Enum.EasingDirection?,
}

-- "Grip": rotate around the gun's grip; "Center": around the gun's middle.
export type Pivot = "Grip" | "Center"

export type Track = {
	length: number, -- seconds at speed 1 (equip/reload are stretched to their duration)
	pivot: Pivot,
	keys: { Key },
}

export type Pose = { pos: Vector3, rot: Vector3 }

-- Which moving rig joint a hand grabs while one of the gun's own Blender clips
-- plays. "Bottom": the bottom of the parts on that joint (a magazine);
-- "Center": their middle (a bolt handle, a cylinder); "Grip": the hand keeps
-- its normal grip but rides along with the joint (a pump, break-action barrels).
export type Follow = { joint: string, grab: "Bottom" | "Center" | "Grip" }

local function key(
	t: number,
	pos: Vector3,
	rot: Vector3,
	style: Enum.EasingStyle?,
	dir: Enum.EasingDirection?
): Key
	return { t = t, pos = pos, rot = rot, style = style, dir = dir }
end

local ZERO = Vector3.zero
local OUT = Enum.EasingDirection.Out
local INOUT = Enum.EasingDirection.InOut

return table.freeze({
	SCALE = 0.5, -- guns are modelled at world size; first person shows them smaller
	ADS_DISTANCE = 1.15, -- camera to the AimPoint while aiming (per gun: adsDistance)
	ADS_EASE = 0.5, -- 0 = linear, 1 = very eased
	-- While aiming, parts that start this far (scaled studs) behind the AimPoint
	-- fade out (stocks); a gun's adsHide names more (Ray Trace's battery cells).
	ADS_HIDE_BEHIND = 0.05,
	ADS_NEON_DIM = 0.8, -- neon strips running back past the sight dim this much

	-- Hip pose rotation on top of the gun's viewmodelOffset (slight inward cant).
	HIP_ROTATION = Vector3.new(1.5, 3, -2),

	-- Arms: blocky, Roblox-proportioned segments dressed in the player's shirt
	-- (classic Shirt template) over their skin colour. Two-bone IK from these
	-- shoulder points to the gun's grips; elbows bend toward the hint.
	SHOULDER_RIGHT = Vector3.new(0.85, -1.35, 0.15),
	SHOULDER_LEFT = Vector3.new(-0.7, -1.4, -0.15),
	-- While aiming the shoulders spread and drop and the elbows hang lower, so
	-- the forearms rise from the bottom corners instead of crossing the sight.
	ADS_SHOULDER_SPREAD = Vector3.new(0.2, -0.35, 0),
	ADS_ELBOW_HINT_RIGHT = Vector3.new(0.5, -1, 0.1),
	ADS_ELBOW_HINT_LEFT = Vector3.new(-0.5, -1, 0.1),
	ELBOW_HINT_RIGHT = Vector3.new(1, -0.65, 0.1),
	ELBOW_HINT_LEFT = Vector3.new(-1, -0.6, 0.1),
	UPPER_LENGTH = 1.2,
	LOWER_LENGTH = 1.15,
	HAND_LENGTH = 0.24,
	ARM_WIDTH = 0.22,
	-- How far the upper arm block runs past the elbow so the joint has no gap.
	ELBOW_OVERLAP = 0.12,
	-- Pistols put both grips in one spot; the support hand cups under and to the left.
	SUPPORT_HAND_OFFSET = Vector3.new(-0.13, -0.05, 0.03),
	-- Melee: the free hand rests here (camera space) as a guard.
	FREE_HAND = Vector3.new(-0.62, -0.78, -1.05),
	-- Shirt template (585 x 559 px): where each arm face sits, and how the arm's
	-- 128 px height splits into upper arm / forearm / hand (like R15 blocky arms).
	SHIRT_SIZE = Vector2.new(585, 559),
	SHIRT_FACES = {
		Right = {
			F = Vector2.new(217, 355),
			R = Vector2.new(151, 355),
			B = Vector2.new(85, 355),
			L = Vector2.new(19, 355),
			U = Vector2.new(217, 289),
			D = Vector2.new(217, 485),
		},
		Left = {
			F = Vector2.new(308, 355),
			L = Vector2.new(374, 355),
			B = Vector2.new(440, 355),
			R = Vector2.new(506, 355),
			U = Vector2.new(308, 289),
			D = Vector2.new(308, 485),
		},
	},
	ARM_SPLIT = { 0.45, 0.82 }, -- upper | forearm | hand

	-- Hands follow the gun's moving parts during its Blender clips. Reload: the
	-- left hand takes the first joint the clip moves, then any later one (e.g.
	-- mag out/in, then the bolt). Fire on pump/bolt guns: the hand works the action.
	RELOAD_FOLLOW = {
		{ joint = "Mag", grab = "Bottom" },
		{ joint = "Cylinder", grab = "Center" },
		{ joint = "Barrels", grab = "Grip" },
		{ joint = "Pump", grab = "Grip" },
		{ joint = "Bolt", grab = "Center" },
		{ joint = "ChargingHandle", grab = "Center" },
	} :: { Follow },
	PUMP_FOLLOW = { joint = "Pump", grab = "Grip" } :: Follow,
	BOLT_FOLLOW = { joint = "Bolt", grab = "Center" } :: Follow,
	-- Share of the clip the hand takes to reach a part before it moves / to come back.
	FOLLOW_LEAD = 0.14,

	-- Sway follows how fast the view turns; strafing rolls the gun.
	SWAY_AMOUNT = 0.016, -- radians of sway per rad/s of turn
	SWAY_MAX = 0.1, -- radians
	SWAY_STIFFNESS = 140,
	SWAY_DAMPING = 17,
	STRAFE_ROLL = 0.0045, -- radians per stud/s of sideways speed
	FALL_LAG = 0.004, -- studs per stud/s of vertical speed
	ADS_SWAY_SCALE = 0.2,

	-- Walk bob follows real ground speed so it fades in and out smoothly.
	BOB_FREQUENCY = 0.55, -- cycles per stud travelled
	BOB_AMOUNT = Vector3.new(0.022, 0.016, 0), -- studs at walk speed
	BOB_ROTATION = Vector3.new(0.8, 0.6, 1.2), -- degrees at walk speed
	BOB_WALK_SPEED = 16,
	SPRINT_BOB_SCALE = 1.8,
	ADS_BOB_SCALE = 0.15,

	-- Per-shot kick on the viewmodel (scaled by the gun's recoil.up).
	KICK_BACK = 0.05,
	KICK_ROTATE = 0.035,
	RECOIL_STIFFNESS = 260,
	RECOIL_DAMPING = 24,
	LAND_KICK = 0.9, -- landing dip impulse

	-- Pose blends (critically damped; higher = faster).
	POSE_STIFFNESS = 120,
	CANCEL_TIME = 0.14, -- seconds to fade out a cancelled track

	-- Poses around the grip, mirrored for the left gun.
	POSES = {
		Sprint = { pos = Vector3.new(0.02, -0.2, 0.1), rot = Vector3.new(-16, 38, 20) },
		Slide = { pos = Vector3.new(-0.06, -0.14, 0.12), rot = Vector3.new(6, 14, -30) },
		Crouch = { pos = Vector3.new(-0.01, -0.03, 0.02), rot = Vector3.new(0, 2, -5) },
		Air = { pos = Vector3.new(0, 0.04, 0.03), rot = Vector3.new(5, 0, 2) },
	} :: { [string]: Pose },

	-- Keyframed tracks.
	TRACKS = {
		-- Raise in from below the screen (stretched to the gun's equip time).
		Equip = {
			length = 0.35,
			pivot = "Grip",
			keys = {
				key(0, Vector3.new(0.05, -0.8, 0.2), Vector3.new(-60, 25, 20)),
				key(
					0.7,
					Vector3.new(0, 0.015, 0),
					Vector3.new(3, -2, -2),
					Enum.EasingStyle.Quad,
					OUT
				),
				key(1, ZERO, ZERO, Enum.EasingStyle.Sine, INOUT),
			},
		},
		-- Turn to show the right side, tilt, flip to the left side, return.
		Inspect = {
			length = 2.8,
			pivot = "Center",
			keys = {
				key(0, ZERO, ZERO),
				key(
					0.16,
					Vector3.new(-0.24, 0.1, 0.12),
					Vector3.new(6, 64, -20),
					Enum.EasingStyle.Back,
					OUT
				),
				key(0.42, Vector3.new(-0.22, 0.13, 0.1), Vector3.new(2, 56, -12)),
				key(
					0.6,
					Vector3.new(-0.42, 0.1, -0.22),
					Vector3.new(-6, -58, 22),
					Enum.EasingStyle.Back,
					OUT
				),
				key(0.82, Vector3.new(-0.42, 0.08, -0.2), Vector3.new(-2, -52, 16)),
				key(1, ZERO, ZERO, Enum.EasingStyle.Quad, INOUT),
			},
		},
		-- Melee: bring the blade up, flip it over the knuckles, show both sides.
		InspectMelee = {
			length = 2.4,
			pivot = "Grip",
			keys = {
				key(0, ZERO, ZERO),
				key(
					0.14,
					Vector3.new(-0.2, 0.14, 0.05),
					Vector3.new(10, 30, -35),
					Enum.EasingStyle.Quad,
					OUT
				),
				key(0.24, Vector3.new(-0.2, 0.16, 0.05), Vector3.new(10, 30, -35)),
				key(
					0.46,
					Vector3.new(-0.2, 0.2, 0.05),
					Vector3.new(370, 30, -35),
					Enum.EasingStyle.Quad,
					INOUT
				),
				key(
					0.62,
					Vector3.new(-0.16, 0.16, 0.05),
					Vector3.new(360, -45, 25),
					Enum.EasingStyle.Back,
					OUT
				),
				key(0.8, Vector3.new(-0.15, 0.15, 0.05), Vector3.new(356, -50, 30)),
				key(1, ZERO, Vector3.new(360, 0, 0), Enum.EasingStyle.Quad, INOUT),
			},
		},
		-- Body motion layered on the gun's own Reload clip (stretched to the reload time).
		Reload = {
			length = 1,
			pivot = "Center",
			keys = {
				key(0, ZERO, ZERO),
				key(
					0.16,
					Vector3.new(-0.05, -0.05, 0.03),
					Vector3.new(7, 8, -16),
					Enum.EasingStyle.Sine,
					OUT
				),
				key(0.55, Vector3.new(-0.06, -0.07, 0.04), Vector3.new(4, 10, -20)),
				key(
					0.74,
					Vector3.new(-0.03, -0.01, 0.01),
					Vector3.new(-4, 5, -8),
					Enum.EasingStyle.Quad,
					OUT
				),
				key(1, ZERO, ZERO, Enum.EasingStyle.Quad, INOUT),
			},
		},
	} :: { [string]: Track },
})
