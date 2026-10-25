--!strict
-- First-person viewmodel feel and animation data (Gunplay.md §6). Positions
-- are in camera space (studs, +X right, +Y up, -Z forward) for the scaled-down
-- gun unless a comment says "gun space" (the gun's Handle: grip at the origin,
-- barrel along -Z). Rotations in keyframes and poses are degrees (X pitch,
-- Y yaw, Z roll), applied as CFrame.Angles around the track's pivot.
--
-- The viewmodel is one rigid rig: root (camera + MOTION) -> gun (hold pose:
-- hip/ADS, POSES, TRACKS, recoil) -> hands and arms (on the gun's grips, in
-- gun space).

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

-- A hand: position (from its grip) and the direction its arm runs from there.
export type Hand = { offset: Vector3, direction: Vector3 }

-- Bob amplitude: studs (pos) and degrees (rot: pitch, yaw, roll).
export type Bob = { pos: Vector3, rot: Vector3 }

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
	-- Guns are modelled at world size; first person shows them at this scale.
	SCALE = 0.75,
	ADS_DISTANCE = 0.7, -- camera to the AimPoint while aiming (per gun: adsDistance)

	-- Arms (Util/ViewmodelArms): one bevelled block per arm, RIVALS style.
	-- Mesh from tools/blender/make_arm_mesh.py (art-source/viewmodel/Arms.fbx,
	-- Model asset 112778616991962), native size ARM_MESH_SIZE, drawn
	-- ARM_WIDTH wide.
	ARM_MESH = {
		Right = "rbxassetid://78886981056288",
		Left = "rbxassetid://98808533168115",
	},
	ARM_MESH_SIZE = Vector3.new(1, 5, 1),
	ARM_WIDTH = 0.5,
	SLEEVE_INFLATE = 1.015, -- shirt layer sits just outside the skin block
	HAND_OVERSHOOT = 0.3, -- in arm widths: how far the block ends past the grip

	-- Hands (gun space, mirrored on Dual Boot's left gun): where each hand sits
	-- from its grip attachment, and the direction its arm runs from there
	-- (toward the elbow, off-screen). Hand and arm are rigid with the gun, so
	-- they move as one with it; only clips (reload, pump, bolt) move a hand.
	-- Long guns: right hand along the grip, support hand under the handguard.
	RIFLE_RIGHT_HAND = {
		offset = Vector3.new(0, -0.06, 0.05),
		direction = Vector3.new(0.2, -0.68, 0.7),
	} :: Hand,
	RIFLE_LEFT_HAND = {
		offset = Vector3.new(0, -0.13, 0),
		direction = Vector3.new(-0.4, -0.5, 0.77),
	} :: Hand,
	-- Pistols: two-handed, high grip. The right hand wraps the grip, its top
	-- just under the back of the slide; the left hand cups it from below and
	-- to the left.
	PISTOL_RIGHT_HAND = {
		offset = Vector3.new(0.01, 0.23, 0.52),
		direction = Vector3.new(0.1, -0.6, 0.8),
	} :: Hand,
	PISTOL_LEFT_HAND = {
		offset = Vector3.new(-0.22, 0.1, 0.56),
		direction = Vector3.new(-0.45, -0.55, 0.7),
	} :: Hand,
	-- Melee: the free hand rests here as a guard (root space).
	FREE_HAND = {
		offset = Vector3.new(-0.5, -0.75, -0.95),
		direction = Vector3.new(-0.35, -0.7, 0.6),
	} :: Hand,

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

	-- Motion of the whole rig (Util/ViewmodelMotion). Every spring is
	-- critically damped and solved exactly, so it looks the same at any frame
	-- rate; `frequency` is its natural frequency (rad/s, higher = snappier).
	-- Rotations turn around MOTION_PIVOT (about where the hands are), so the
	-- gun tilts instead of swinging around the camera.
	MOTION_PIVOT = Vector3.new(0.2, -0.45, -1.1),
	VELOCITY_SMOOTHING = 10, -- low-pass on the predicted velocity (1/s)

	-- Sway: turning the view kicks a spring (pushed by how far the view turned,
	-- not by a per-frame rate, so mouse jitter can't make it shake). The gun
	-- lags behind the turn by rotating and shifting a little.
	SWAY_FREQUENCY = 10,
	SWAY_GAIN = 2.4, -- steady lag = GAIN / FREQUENCY^2 radians per rad/s of turn
	SWAY_MAX = 0.09, -- radians, soft limit
	SWAY_SHIFT = 0.35, -- studs of shift per radian of lag

	-- Strafing rolls the gun and drifts it against the motion; falling lifts
	-- it, landing dips it.
	STRAFE_ROLL = 0.0035, -- radians per stud/s of sideways speed
	STRAFE_SHIFT = 0.0022, -- studs per stud/s
	TILT_FREQUENCY = 8,
	FALL_LAG = 0.0035, -- studs per stud/s of vertical speed (clamped to FALL_LAG_MAX)
	FALL_LAG_MAX = 0.07,
	LAND_KICK = 0.9, -- studs/s of downward kick on a hard landing
	LIFT_FREQUENCY = 11,

	-- Walk bob: a figure-8 (sideways once per loop, a dip on each step, so
	-- twice per loop), sized by ground speed and eased in and out. Sprinting
	-- swaps to a slower, wider loop.
	BOB_REFERENCE_SPEED = 16, -- studs/s that give the walk amount
	BOB_WALK_FREQUENCY = 1.0, -- loops per second
	BOB_SPRINT_FREQUENCY = 0.85,
	BOB_WALK = { pos = Vector3.new(0.016, 0.009, 0), rot = Vector3.new(0.5, 0.6, 1.1) } :: Bob,
	BOB_SPRINT = { pos = Vector3.new(0.034, 0.02, 0), rot = Vector3.new(1.2, 1.8, 2.6) } :: Bob,
	BOB_EASE = 6, -- how fast the bob amount and speed ease (rad/s)

	-- Breathing: slow idle drift, faded out while moving.
	BREATH_RATE = 0.25, -- cycles per second
	BREATH_AMOUNT = Vector2.new(0.003, 0.0045), -- studs
	BREATH_ROTATION = 0.3, -- degrees of pitch

	-- How much of each motion stays while fully aimed (1 = all of it). Kept
	-- non-zero so the sights drift as you move, like RIVALS.
	ADS_SWAY_SCALE = 0.35,
	ADS_MOVE_SCALE = 0.4,
	ADS_BOB_SCALE = 0.25,
	ADS_BREATH_SCALE = 0.5,

	-- Per-shot kick on the gun (scaled by the gun's recoil.up).
	KICK_BACK = 0.05,
	KICK_ROTATE = 0.035,
	RECOIL_STIFFNESS = 260,
	RECOIL_DAMPING = 24,

	-- Pose blends (critically damped, rad/s).
	POSE_FREQUENCY = 13,
	CANCEL_TIME = 0.14, -- seconds to fade out a cancelled track

	-- Poses of the gun around its grip, mirrored for the left gun. Sprint is a
	-- lowered carry, muzzle down and in, rolled toward the centre.
	POSES = {
		Sprint = { pos = Vector3.new(-0.04, -0.16, 0.08), rot = Vector3.new(-14, 26, 18) },
		Slide = { pos = Vector3.new(-0.05, -0.1, 0.08), rot = Vector3.new(4, 10, -24) },
		Crouch = { pos = Vector3.new(-0.01, -0.02, 0.02), rot = Vector3.new(0, 2, -4) },
		Air = { pos = Vector3.new(0, 0.03, 0.02), rot = Vector3.new(4, 0, 2) },
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
