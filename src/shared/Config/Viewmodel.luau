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

export type ItemKey = { t: number, pos: Vector3, rot: Vector3 }
export type ItemAction = { length: number, hideAt: number?, keys: { ItemKey } }

-- A hand: position (from its grip) and the direction its arm runs from there.
export type Hand = { offset: Vector3, direction: Vector3 }

-- A free-hand key (camera space around the root): where the fist is and the
-- direction its arm runs from there (toward the shoulder, off-screen).
export type HandKey = { t: number, pos: Vector3, dir: Vector3 }
-- `release` (0..1): a gesture that carries a prop (ViewmodelController.
-- gesture's `prop`) lets go of it then; `propScale` sizes the prop in the
-- fist, `propTilt` tips it forward (degrees) by the release.
export type Gesture = {
	length: number,
	keys: { HandKey },
	release: number?,
	propScale: number?,
	propTilt: number?,
}

-- Bob amplitude: studs (pos) and degrees (rot: pitch, yaw, roll).
export type Bob = { pos: Vector3, rot: Vector3 }

-- Which moving rig joint a hand grabs while one of the gun's own Blender clips
-- plays. "Bottom": the bottom of the parts on that joint (a magazine);
-- "Center": their middle (a bolt handle, a cylinder); "Grip": the hand keeps
-- its normal grip but rides along with the joint (a pump, break-action barrels).
-- `point`: grab this attachment on the gun (riding the joint) when it has
-- one, e.g. a break-action's "ForeGrip".
export type Follow = { joint: string, grab: "Bottom" | "Center" | "Grip", point: string? }

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
	-- Nothing on screen nearer than this to the eye while aiming: the camera's
	-- near plane (~0.1) slices closer meshes open (round 3: the "glitched" ADS
	-- on the Bulldog, Spectre and Odin). Parts reaching back past the eye fade
	-- out while aimed; guns set adsDistance so the receiver ahead clears it.
	ADS_NEAR = 0.16,
	ADS_FADE_PREFIXES = { "Stock" }, -- parts (by name) that may fade when they pass the eye
	-- Scoped guns (config scope): past this much aim the gun and arms hide
	-- and the HUD scope overlay shows.
	SCOPE_AT = 0.85,

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
	-- A reaching arm whose block (ARM_REACH_LENGTH long from the hand) would
	-- pass within ARM_EYE_CLEARANCE of the camera is bent to point at least
	-- ARM_MIN_DROP down the screen and at most ARM_MAX_BACK toward the camera
	-- (unit direction, camera space): one running through the eye isn't drawn
	-- at all, and one just under it walls off the view.
	ARM_REACH_LENGTH = 2.35,
	ARM_EYE_CLEARANCE = 0.5,
	ARM_MIN_DROP = 0.72,
	ARM_MAX_BACK = 0.35,

	-- Hands (gun space, mirrored on an akimbo left gun): where each hand sits
	-- from its grip attachment, and the direction its arm runs from there
	-- (toward the elbow, off-screen). Hand and arm are rigid with the gun, so
	-- they move as one with it; only clips (reload, pump, bolt) move a hand.
	-- Long guns: the right hand low on the grip, its forearm straight down
	-- (it clears the receiver and stock); the support hand under the
	-- handguard just ahead of its grip point, forearm down and back. Checked
	-- by box overlap: neither block enters the receiver (the hand blocks are
	-- wide, so they sit on the grips rather than around them).
	RIFLE_RIGHT_HAND = {
		offset = Vector3.new(0.04, -0.28, 0.02),
		direction = Vector3.new(0.2, -0.95, 0.2),
	} :: Hand,
	RIFLE_LEFT_HAND = {
		offset = Vector3.new(-0.02, -0.22, -0.14),
		direction = Vector3.new(-0.18, -0.95, 0.25), -- steep: the forearm clears the mag
	} :: Hand,
	-- Pistols: two-handed, RIVALS style. The right fist closes on the grip
	-- itself (the grip disappears into the block up to the frame, so a small
	-- gun reads as held, not floating ahead of the hands); the left fist
	-- wraps the right one from the left and below. Round 2 feedback: the old
	-- hold sat both hands half a stud behind the grip.
	PISTOL_RIGHT_HAND = {
		offset = Vector3.new(0, -0.02, 0.06),
		direction = Vector3.new(0.12, -0.75, 0.65),
	} :: Hand,
	PISTOL_LEFT_HAND = {
		offset = Vector3.new(-0.15, -0.1, 0.08),
		direction = Vector3.new(-0.45, -0.7, 0.55),
	} :: Hand,
	-- Melee: the hand closes around the handle (the arm runs back along it);
	-- the free hand rests low on the left as a guard (root space).
	MELEE_HAND = {
		offset = Vector3.new(0, -0.02, 0.14),
		direction = Vector3.new(0.08, -0.4, 0.91),
	} :: Hand,
	-- Pistols: the support hand on a moving part with a held point (a
	-- revolver's crane, break-action barrels), from the left side.
	PISTOL_FOLLOW_HAND = {
		offset = Vector3.new(-0.26, -0.04, 0),
		direction = Vector3.new(-0.9, -0.25, 0.35),
	} :: Hand,
	-- Knife heavy stab: the free hand joins the right one on the handle,
	-- behind it (gun space from the grip, like MELEE_HAND).
	MELEE_TWO_HAND = {
		offset = Vector3.new(-0.02, -0.04, 0.32),
		direction = Vector3.new(-0.3, -0.45, 0.84),
	} :: Hand,
	FREE_HAND = {
		offset = Vector3.new(-0.56, -0.86, -0.95),
		direction = Vector3.new(-0.35, -0.7, 0.6),
	} :: Hand,

	-- Dropped mags (Util/MagDrop): a reload clip's mag (or belt box) joint
	-- counts as out of the gun `away` studs (model units) from rest; a copy
	-- falls (studs/s, gravity studs/s²), bounces once, lies there for `life`
	-- seconds and fades over the last `fade`.
	MAG_DROP = {
		bones = { "Mag", "AmmoBox" },
		away = 0.12,
		gravity = 60,
		kick = 3,
		spin = 6, -- rad/s tumble
		bounce = 0.3,
		restLift = 0.04,
		life = 4,
		fade = 0.6,
		poolPerGun = 4,
	},

	-- Hands follow the gun's moving parts during its Blender clips. In each of
	-- HAND_CLIPS the left hand takes the first joint the clip moves, then any
	-- later one (e.g. mag out/in, then the charging handle). Fire on pump/bolt
	-- guns: the hand works the action.
	HAND_CLIPS = { "Reload", "ReloadEmpty", "ReloadInsert", "Draw", "Inspect" },
	RELOAD_FOLLOW = {
		{ joint = "Mag", grab = "Bottom" },
		{ joint = "AmmoBox", grab = "Bottom" }, -- belt-fed: the box, after the feed cover
		{ joint = "FeedCover", grab = "Center" },
		{ joint = "Cylinder", grab = "Center" },
		{ joint = "Barrels", grab = "Grip", point = "ForeGrip" },
		{ joint = "Pump", grab = "Grip" },
		{ joint = "Bolt", grab = "Center" },
		{ joint = "ChargingHandle", grab = "Center" },
		{ joint = "Slide", grab = "Center" }, -- pistols: racking the slide
		{ joint = "Shell", grab = "Center" }, -- shell-by-shell loading: the hand carries the shell
		-- Revolvers: the hand rides the swung-out cylinder (on its crane) and loads it.
		{ joint = "Crane", grab = "Center", point = "ReloadInsertPoint" },
	} :: { Follow },
	PUMP_FOLLOW = { joint = "Pump", grab = "Grip" } :: Follow,
	BOLT_FOLLOW = { joint = "Bolt", grab = "Center" } :: Follow,
	-- Lever-actions: the trigger hand rides the lever (its fingers are in the
	-- loop), in Fire and in every handling clip; the support hand leaves the
	-- bolt alone (the lever drives it).
	LEVER_FOLLOW = { joint = "Lever", grab = "Bottom" } :: Follow, -- under the loop, riding it
	-- Share of the clip the hand takes to reach a part before it moves / to come back.
	FOLLOW_LEAD = 0.14,
	-- How far outside a followed part the hand stops (studs, viewmodel scale),
	-- so the wide hand block rests on it (checked with
	-- tools/blender/check_hand_clipping.py): below a mag, beside anything
	-- else (from the hand's own side). A part further than FOLLOW_SIDE off
	-- the centre line on the far side is the other hand's.
	FOLLOW_CLEARANCE = 0.26,
	-- Beside a small handle (a charging handle knob, a bolt) the hand closes
	-- on it: only this far out, so the block's end meets the knob.
	FOLLOW_SIDE_CLEARANCE = 0.22,
	FOLLOW_SIDE = 0.02,
	-- On a part below or beside the gun the arm points away from it, tipped
	-- down and back by this (so it still rises into view from below).
	FOLLOW_REACH_BIAS = Vector3.new(0, -0.6, 0.25),
	-- Beside the gun (a handle or bolt) the forearm hangs as steeply as it
	-- can: each of FOLLOW_SIDE_DROPS (down component, steepest first, with
	-- FOLLOW_SIDE_BACK toward the camera) is tried until FOLLOW_ARM_SAMPLES
	-- points FOLLOW_ARM_STEP apart along it clear the gun's other moving parts
	-- (elbow out over a drum); the hand a little below the part's middle.
	FOLLOW_SIDE_DROPS = { -1.0, -0.6, -0.35, -0.12 },
	FOLLOW_SIDE_STEPS = { 0, 0.04, 0.08, 0.12 }, -- studs further out the hand may go first
	FOLLOW_STEP_COST = 0.5,
	FOLLOW_SIDE_BACK = 0.3,
	FOLLOW_ARM_SAMPLES = 6,
	FOLLOW_ARM_STEP = 0.15,
	FOLLOW_ARM_MARGIN = 0.06,
	FOLLOW_SIDE_DROP = 0.06,
	-- A hand beside the gun is lifted (FOLLOW_LIFT_STEP studs at a time, at
	-- most FOLLOW_LIFT_STEPS) until it clears the gun's other moving parts
	-- (tested as a cube FOLLOW_LIFT_PUSH out along the arm, the arm's
	-- half-width less FOLLOW_LIFT_BEVEL, against each part's box); parts on
	-- these joints don't count.
	FOLLOW_LIFT_STEP = 0.04,
	FOLLOW_LIFT_STEPS = 10,
	FOLLOW_LIFT_PUSH = 0.1,
	FOLLOW_LIFT_BEVEL = 0.03,
	FOLLOW_IGNORE_JOINTS = { "Flash", "Charm", "Trigger", "Hammer" },
	-- Studs the hand swings out (along its arm) halfway between its grip and
	-- a part, so it travels around the gun, not through it.
	FOLLOW_ARC = 0.42,
	-- While a hand works a part, its arm turns toward this direction (gun
	-- space): down and back, so it rises from below the gun into view.
	REACH_DIRECTION = Vector3.new(-0.6, -0.74, 0.3),
	-- Foley read off the clips (share of the clip): mag out this long after the
	-- mag starts moving, mag in this long before it stops, the rack this long
	-- before the charging handle (or bolt) comes to rest.
	BEAT_MAG_OUT = 0.03,
	BEAT_MAG_IN = 0.03,
	BEAT_RACK = 0.02,
	-- lockOnEmpty guns: on the last round the Fire clip is cut here (its
	-- slide at the back) and the action holds open until the reload.
	LOCK_AT = 0.25,

	-- Motion of the whole rig (Util/ViewmodelMotion). Every spring is
	-- critically damped and solved exactly, so it looks the same at any frame
	-- rate; `frequency` is its natural frequency (rad/s, higher = snappier).
	-- Rotations turn around MOTION_PIVOT (about where the hands are), so the
	-- gun tilts instead of swinging around the camera.
	MOTION_PIVOT = Vector3.new(0.2, -0.45, -1.1),
	ADS_MOTION_PIVOT = Vector3.new(0, 0, -0.75), -- aimed: around the sight line
	VELOCITY_SMOOTHING = 10, -- low-pass on the predicted velocity (1/s)

	-- Sway: turning the view kicks a spring (pushed by how far the view turned,
	-- not by a per-frame rate, so mouse jitter can't make it shake). The gun
	-- lags behind the turn by rotating and shifting a little.
	SWAY_FREQUENCY = 10,
	SWAY_GAIN = 2.4, -- steady lag = GAIN / FREQUENCY^2 radians per rad/s of turn
	SWAY_MAX = 0.09, -- radians, soft limit
	SWAY_SHIFT = 0.35, -- studs of shift per radian of lag

	-- Strafing drifts the gun against the motion and leans its top back
	-- against it (aimed values: the sights follow the strafe, gently); falling
	-- lifts it, landing dips it.
	STRAFE_ROLL = 0.0035, -- radians per stud/s of sideways speed
	STRAFE_SHIFT = 0.0022, -- studs per stud/s
	ADS_STRAFE_ROLL = 0.0026,
	ADS_STRAFE_SHIFT = 0.0008,
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
	-- Aimed: a small, snappy push back with almost no climb, settling fast
	-- (critically damped), so the sight picture stays on target; the camera
	-- kick carries the recoil feel. The gun's own Fire clip moves its Root
	-- joint (the whole gun) only this much while fully aimed.
	ADS_KICK_BACK = 0.035,
	ADS_KICK_ROTATE = 0.004,
	ADS_RECOIL_STIFFNESS = 700,
	ADS_CLIP_KICK = 0.2,

	-- Held Mods (ModController): the gun drops out of view (camera space,
	-- around the root) while the Mod's item comes up in the right hand.
	LOWER = { pos = Vector3.new(0.3, -1.5, 0.6), rot = Vector3.new(-45, 15, 25) } :: Pose,
	LOWER_FREQUENCY = 14, -- rad/s, critically damped
	ITEM_OFFSET = Vector3.new(0.5, -0.62, -2), -- the item's grip, camera space
	ITEM_ROTATION = Vector3.new(8, -12, 0), -- degrees
	ITEM_FROM = Vector3.new(0.4, -1.3, 0.4), -- it rises from this far below
	ITEM_ARM = Vector3.new(0.22, -0.8, 0.6), -- right arm direction from the grip
	-- The item comes up on an underdamped spring: a little overshoot, then it settles.
	ITEM_RAISE_FREQUENCY = 13, -- rad/s
	ITEM_RAISE_DAMPING = 0.55, -- ratio (1 = no overshoot)
	-- Held idle: a slow breathing drift on top of the hold (position studs,
	-- rotation degrees, cycles per second).
	ITEM_IDLE = { pos = Vector3.new(0.012, 0.018, 0), rot = Vector3.new(1.5, 1.8, 1), rate = 0.55 },
	-- Uses, keyframed on top of the hold (camera space, smoothstep between
	-- keys; `t` 0..1 over `length` seconds). Throw: wind back and up, release
	-- forward (the item leaves the hand at `hideAt`), follow through down.
	-- Place: push down and out. Heal: a thrust toward the target and back.
	ITEM_ACTIONS = {
		Throw = {
			length = 0.34,
			hideAt = 0.58,
			keys = {
				{ t = 0, pos = Vector3.zero, rot = Vector3.zero },
				{ t = 0.38, pos = Vector3.new(0.12, 0.28, 0.45), rot = Vector3.new(-32, 6, 12) },
				{ t = 0.58, pos = Vector3.new(-0.06, 0.38, -0.95), rot = Vector3.new(38, -4, -6) },
				{ t = 1, pos = Vector3.new(0.05, -0.7, -0.25), rot = Vector3.new(24, 0, 0) },
			},
		},
		-- Javelin (Frost LMB): the arm draws back level with the shoulder and
		-- spears it forward, flat.
		Javelin = {
			length = 0.32,
			hideAt = 0.55,
			keys = {
				{ t = 0, pos = Vector3.zero, rot = Vector3.zero },
				{ t = 0.35, pos = Vector3.new(0.22, 0.1, 0.55), rot = Vector3.new(-8, 18, 4) },
				{ t = 0.55, pos = Vector3.new(-0.05, 0.12, -1.05), rot = Vector3.new(6, -6, -4) },
				{ t = 1, pos = Vector3.new(0.05, -0.55, -0.4), rot = Vector3.new(18, 0, 0) },
			},
		},
		-- LauncherFire (Recon): the launcher kicks up and back, then settles.
		LauncherFire = {
			length = 0.3,
			keys = {
				{ t = 0, pos = Vector3.zero, rot = Vector3.zero },
				{ t = 0.15, pos = Vector3.new(0, 0.06, 0.28), rot = Vector3.new(16, 0, 2) },
				{ t = 1, pos = Vector3.zero, rot = Vector3.zero },
			},
		},
		-- Lob: underhand, a swing down and back, then out low and soft.
		Lob = {
			length = 0.4,
			hideAt = 0.62,
			keys = {
				{ t = 0, pos = Vector3.zero, rot = Vector3.zero },
				{ t = 0.35, pos = Vector3.new(0.06, -0.4, 0.3), rot = Vector3.new(32, 4, 4) },
				{ t = 0.62, pos = Vector3.new(0, -0.08, -0.75), rot = Vector3.new(-38, -2, 0) },
				{ t = 1, pos = Vector3.new(0.02, -0.5, -0.35), rot = Vector3.new(-12, 0, 0) },
			},
		},
		Place = {
			length = 0.32,
			keys = {
				{ t = 0, pos = Vector3.zero, rot = Vector3.zero },
				{ t = 0.4, pos = Vector3.new(0, -0.38, -0.55), rot = Vector3.new(28, 0, 0) },
				{ t = 1, pos = Vector3.zero, rot = Vector3.zero },
			},
		},
		-- OrbChest (Heal Orb on yourself): the hand presses the orb into your
		-- chest, low and toward you.
		OrbChest = {
			length = 0.4,
			hideAt = 0.5,
			keys = {
				{ t = 0, pos = Vector3.zero, rot = Vector3.zero },
				{ t = 0.25, pos = Vector3.new(-0.05, 0.08, -0.12), rot = Vector3.new(-6, 0, 0) },
				{ t = 0.5, pos = Vector3.new(-0.35, -0.55, 1.05), rot = Vector3.new(30, 20, 0) },
				{ t = 1, pos = Vector3.new(-0.2, -0.9, 0.6), rot = Vector3.new(20, 10, 0) },
			},
		},
		Heal = {
			length = 0.36,
			hideAt = 0.25, -- the orb leaves the hand at full extension
			keys = {
				{ t = 0, pos = Vector3.zero, rot = Vector3.zero },
				{ t = 0.25, pos = Vector3.new(-0.02, 0.06, -0.42), rot = Vector3.new(-8, 0, 0) },
				{ t = 0.55, pos = Vector3.new(0, 0.02, -0.22), rot = Vector3.new(-3, 0, 0) },
				{ t = 1, pos = Vector3.zero, rot = Vector3.zero },
			},
		},
	} :: { [string]: ItemAction },

	-- Mod gestures (ModController → ViewmodelController.gesture): the gun
	-- moves by one of MOD_DIPS (camera space around the root, smoothstep
	-- between keys) while the free (left) hand plays one of MOD_GESTURES.
	--
	-- Dash: the gun dips out of view and snaps back up with a small
	-- overshoot; it's down by the dash's end and back up as the fire delay
	-- ends (~0.25 s). Keep in step with Config/Mods Dash.
	DASH_DIP = {
		length = 0.34,
		keys = {
			{ t = 0, pos = Vector3.zero, rot = Vector3.zero },
			{ t = 0.17, pos = Vector3.new(0.3, -1.3, 0.5), rot = Vector3.new(-40, 14, 22) },
			{ t = 0.68, pos = Vector3.new(0.3, -1.35, 0.5), rot = Vector3.new(-42, 14, 24) },
			{ t = 0.88, pos = Vector3.new(0, 0.035, -0.03), rot = Vector3.new(3, 0, -1) },
			{ t = 1, pos = Vector3.zero, rot = Vector3.zero },
		},
	} :: ItemAction,
	-- Updraft: the gun drops down and away while you rise (no shots for the
	-- stats' gunDown), then swings back up near the peak.
	UPDRAFT_DIP = {
		length = 0.5,
		keys = {
			{ t = 0, pos = Vector3.zero, rot = Vector3.zero },
			{ t = 0.2, pos = Vector3.new(0.15, -1.15, 0.45), rot = Vector3.new(-38, 8, 14) },
			{ t = 0.62, pos = Vector3.new(0.15, -1.2, 0.45), rot = Vector3.new(-40, 8, 15) },
			{ t = 0.86, pos = Vector3.new(0, 0.04, -0.03), rot = Vector3.new(3, 0, -1) },
			{ t = 1, pos = Vector3.zero, rot = Vector3.zero },
		},
	} :: ItemAction,
	-- Stim: the gun dips down and to the side while the free hand tosses the
	-- beacon, then comes straight back.
	STIM_DIP = {
		length = 0.55,
		keys = {
			{ t = 0, pos = Vector3.zero, rot = Vector3.zero },
			{ t = 0.25, pos = Vector3.new(0.18, -0.65, 0.3), rot = Vector3.new(-24, 8, 12) },
			{ t = 0.65, pos = Vector3.new(0.18, -0.7, 0.3), rot = Vector3.new(-26, 8, 12) },
			{ t = 0.88, pos = Vector3.new(0, 0.03, -0.02), rot = Vector3.new(2, 0, -1) },
			{ t = 1, pos = Vector3.zero, rot = Vector3.zero },
		},
	} :: ItemAction,
	-- Recall: over the wind-up the gun sinks a little and tilts in while the
	-- free hand twists; it's back up just as you arrive.
	RECALL_DIP = {
		length = 0.6,
		keys = {
			{ t = 0, pos = Vector3.zero, rot = Vector3.zero },
			{ t = 0.3, pos = Vector3.new(0.06, -0.22, 0.1), rot = Vector3.new(-8, 6, 10) },
			{ t = 0.8, pos = Vector3.new(0.06, -0.26, 0.12), rot = Vector3.new(-9, 6, 12) },
			{ t = 1, pos = Vector3.zero, rot = Vector3.zero },
		},
	} :: ItemAction,
	-- The free hand, starting and ending below the screen. Dash: the way you
	-- dash (Forward: the palm pushes out; Left / Right: a sweep to that side;
	-- Back: reach out, then pull back). Updraft: a flick down, pushing off.
	MOD_GESTURES = {
		DashForward = {
			length = 0.24,
			keys = {
				{ t = 0, pos = Vector3.new(-0.55, -1.6, -0.7), dir = Vector3.new(-0.3, -0.8, 0.5) },
				{
					t = 0.3,
					pos = Vector3.new(-0.35, -0.72, -1.15),
					dir = Vector3.new(-0.3, -0.55, 0.75),
				},
				{
					t = 0.55,
					pos = Vector3.new(-0.12, -0.42, -1.75),
					dir = Vector3.new(-0.25, -0.4, 0.88),
				},
				{
					t = 0.78,
					pos = Vector3.new(-0.2, -0.55, -1.6),
					dir = Vector3.new(-0.25, -0.45, 0.85),
				},
				{ t = 1, pos = Vector3.new(-0.55, -1.6, -0.7), dir = Vector3.new(-0.3, -0.8, 0.5) },
			},
		},
		DashBack = {
			length = 0.24,
			keys = {
				{ t = 0, pos = Vector3.new(-0.55, -1.6, -0.7), dir = Vector3.new(-0.3, -0.8, 0.5) },
				{
					t = 0.3,
					pos = Vector3.new(-0.25, -0.45, -1.55),
					dir = Vector3.new(-0.3, -0.5, 0.8),
				},
				{
					t = 0.65,
					pos = Vector3.new(-0.6, -0.85, -0.75),
					dir = Vector3.new(-0.4, -0.75, 0.5),
				},
				{ t = 1, pos = Vector3.new(-0.6, -1.6, -0.6), dir = Vector3.new(-0.3, -0.8, 0.5) },
			},
		},
		DashLeft = {
			length = 0.24,
			keys = {
				{ t = 0, pos = Vector3.new(-0.4, -1.6, -0.8), dir = Vector3.new(-0.3, -0.8, 0.5) },
				{
					t = 0.3,
					pos = Vector3.new(-0.1, -0.55, -1.3),
					dir = Vector3.new(-0.15, -0.6, 0.8),
				},
				{
					t = 0.62,
					pos = Vector3.new(-1.15, -0.5, -1.05),
					dir = Vector3.new(-0.5, -0.55, 0.65),
				},
				{
					t = 1,
					pos = Vector3.new(-0.95, -1.6, -0.7),
					dir = Vector3.new(-0.4, -0.8, 0.45),
				},
			},
		},
		DashRight = {
			length = 0.24,
			keys = {
				{ t = 0, pos = Vector3.new(-0.6, -1.6, -0.8), dir = Vector3.new(-0.3, -0.8, 0.5) },
				{
					t = 0.3,
					pos = Vector3.new(-0.55, -0.55, -1.25),
					dir = Vector3.new(-0.3, -0.55, 0.75),
				},
				{
					t = 0.62,
					pos = Vector3.new(0.45, -0.5, -1.2),
					dir = Vector3.new(-0.65, -0.45, 0.6),
				},
				{
					t = 1,
					pos = Vector3.new(0.15, -1.6, -0.75),
					dir = Vector3.new(-0.5, -0.75, 0.45),
				},
			},
		},
		-- Molly: the free hand comes up to the canister's top (the held item
		-- sits at ITEM_OFFSET), pulls the pin and drops away.
		MollyPinPull = {
			length = 0.45,
			keys = {
				{ t = 0, pos = Vector3.new(-0.55, -1.6, -0.8), dir = Vector3.new(-0.3, -0.8, 0.5) },
				{
					t = 0.38,
					pos = Vector3.new(0.3, -0.36, -1.85),
					dir = Vector3.new(-0.65, -0.35, 0.68),
				},
				{
					t = 0.5,
					pos = Vector3.new(0.28, -0.34, -1.8),
					dir = Vector3.new(-0.65, -0.35, 0.68),
				},
				{
					t = 0.72,
					pos = Vector3.new(-0.15, -0.3, -1.5),
					dir = Vector3.new(-0.5, -0.5, 0.7),
				},
				{ t = 1, pos = Vector3.new(-0.55, -1.6, -0.8), dir = Vector3.new(-0.3, -0.8, 0.5) },
			},
		},
		-- Stim (Brimstone-style): the hand comes up from the belt with the
		-- beacon, dips back and tosses it underhand a few steps ahead
		-- (it leaves the hand at `release`, the stats' tossRelease), then
		-- follows through and drops away.
		StimToss = {
			length = 0.55,
			release = 0.55, -- the beacon (ModProps' hand-sized one) leaves the fist
			propTilt = -35,
			keys = {
				{
					t = 0,
					pos = Vector3.new(-0.55, -1.6, -0.75),
					dir = Vector3.new(-0.3, -0.8, 0.5),
				},
				{
					t = 0.24,
					pos = Vector3.new(-0.42, -0.92, -1.2),
					dir = Vector3.new(-0.35, -0.5, 0.8),
				},
				{
					t = 0.4,
					pos = Vector3.new(-0.4, -1.12, -1.0),
					dir = Vector3.new(-0.3, -0.25, 0.92),
				},
				{
					t = 0.55,
					pos = Vector3.new(-0.22, -0.62, -1.65),
					dir = Vector3.new(-0.15, -0.45, 0.88),
				},
				{
					t = 0.72,
					pos = Vector3.new(-0.16, -0.48, -1.72),
					dir = Vector3.new(-0.1, -0.6, 0.8),
				},
				{ t = 1, pos = Vector3.new(-0.55, -1.7, -0.8), dir = Vector3.new(-0.3, -0.8, 0.5) },
			},
		},
		-- Recall: the hand comes up in front, twists (a snap of the wrist)
		-- and holds while the teleport charges, then drops away.
		RecallTwist = {
			length = 0.6,
			keys = {
				{
					t = 0,
					pos = Vector3.new(-0.55, -1.6, -0.75),
					dir = Vector3.new(-0.3, -0.8, 0.5),
				},
				{
					t = 0.25,
					pos = Vector3.new(-0.32, -0.55, -1.3),
					dir = Vector3.new(-0.45, -0.6, 0.65),
				},
				{
					t = 0.45,
					pos = Vector3.new(-0.22, -0.5, -1.35),
					dir = Vector3.new(0.1, -0.7, 0.7),
				},
				{
					t = 0.85,
					pos = Vector3.new(-0.22, -0.52, -1.35),
					dir = Vector3.new(0.12, -0.7, 0.7),
				},
				{ t = 1, pos = Vector3.new(-0.55, -1.7, -0.8), dir = Vector3.new(-0.3, -0.8, 0.5) },
			},
		},
		UpdraftDown = {
			length = 0.26,
			keys = {
				{
					t = 0,
					pos = Vector3.new(-0.55, -1.6, -0.75),
					dir = Vector3.new(-0.3, -0.8, 0.5),
				},
				{
					t = 0.3,
					pos = Vector3.new(-0.42, -0.5, -1.2),
					dir = Vector3.new(-0.3, -0.6, 0.7),
				},
				{
					t = 0.7,
					pos = Vector3.new(-0.5, -1.25, -1.05),
					dir = Vector3.new(-0.25, 0.2, 0.95),
				},
				{ t = 1, pos = Vector3.new(-0.55, -1.7, -0.8), dir = Vector3.new(-0.3, -0.8, 0.5) },
			},
		},
	} :: { [string]: Gesture },

	-- Held free-hand poses (ViewmodelController.setFreeHand): root space, the
	-- fist and its arm direction, eased toward at FREE_POSE_RATE. Firewall:
	-- the hand held up with a flame in it, then pushed out to guide the wall.
	FREE_POSES = {
		FirewallReady = {
			offset = Vector3.new(-0.42, -0.5, -1.35),
			direction = Vector3.new(-0.35, -0.75, 0.55),
		},
		FirewallGuide = {
			offset = Vector3.new(-0.2, -0.42, -1.85),
			direction = Vector3.new(-0.25, -0.45, 0.86),
		},
	} :: { [string]: Hand },
	FREE_POSE_RATE = 16, -- 1/s
	FREE_POSE_FROM = Vector3.new(-0.55, -1.6, -0.8), -- where the hand comes up from
	-- The flame in the hand (a small fire on the fist; Util/... MOLLY flipbook).
	HAND_FLAME_SIZE = 0.55,

	-- Pose blends (critically damped, rad/s).
	POSE_FREQUENCY = 13,
	CANCEL_TIME = 0.14, -- seconds to fade out a cancelled track

	-- Poses of the gun around its grip, mirrored for the left gun. Sprint is a
	-- lowered carry: muzzle in toward the centre, rolled onto its side.
	POSES = {
		Sprint = { pos = Vector3.new(-0.05, -0.07, 0.04), rot = Vector3.new(-6, 20, 30) },
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
		-- Every draw (stretched to drawTime), under the gun's Draw
		-- clip (Valorant style): swing up from low right, roll the left side to
		-- the camera while the support hand racks the charging handle all the
		-- way back and holds it (clip 28-53%), slam it home (56%), settle.
		Draw = {
			length = 0.9,
			pivot = "Grip",
			keys = {
				key(0, Vector3.new(0.12, -0.75, 0.25), Vector3.new(-50, 30, 35)),
				-- Pushed out, lifted and turned muzzle-in (positive yaw) with a
				-- little roll, so the left side and the hand on the charging
				-- handle face the camera, on screen, and the arm isn't in its face.
				key(
					0.26,
					Vector3.new(-0.05, 0.06, -0.3),
					Vector3.new(8, 16, -8),
					Enum.EasingStyle.Quad,
					OUT
				),
				key(0.42, Vector3.new(-0.06, 0.07, -0.33), Vector3.new(7, 19, -10)), -- handle back
				key(0.53, Vector3.new(-0.06, 0.065, -0.33), Vector3.new(6.5, 19.5, -10.5)), -- held
				key(
					0.6,
					Vector3.new(-0.03, 0.04, -0.15),
					Vector3.new(7, 10, -5),
					Enum.EasingStyle.Back,
					OUT
				), -- slammed home
				key(0.8, Vector3.new(0, 0.008, 0), Vector3.new(1.5, -0.5, 1)),
				key(1, ZERO, ZERO, Enum.EasingStyle.Sine, INOUT),
			},
		},
		-- Turn to show the right side, tilt, flip to the left side, return.
		-- (The gun's own clip runs alongside: a mag tap, then a press check on
		-- the charging handle, which the support hand works from the far side.)
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
		-- Knife inspect, plain (round 2: no whole-hand spin): turn the blade to
		-- look along one face, then the other, and back.
		InspectMelee = {
			length = 2.4,
			pivot = "Grip",
			keys = {
				key(0, ZERO, ZERO),
				key(
					0.18,
					Vector3.new(-0.2, 0.14, 0.05),
					Vector3.new(5, 40, -20),
					Enum.EasingStyle.Quad,
					OUT
				),
				key(0.42, Vector3.new(-0.21, 0.15, 0.05), Vector3.new(7, 44, -22)),
				key(
					0.62,
					Vector3.new(-0.18, 0.15, 0.05),
					Vector3.new(5, -35, 28),
					Enum.EasingStyle.Quad,
					INOUT
				),
				key(0.84, Vector3.new(-0.17, 0.14, 0.05), Vector3.new(4, -38, 30)),
				key(1, ZERO, ZERO, Enum.EasingStyle.Quad, INOUT),
			},
		},
		-- Knife attacks (placeholders until the Blender Slash/HeavyStab clips
		-- land; the gun clip of the same name plays on the knife when it has
		-- one). Light slashes chain 1 -> 2 -> 3: a forehand cut right to left,
		-- a backhand cut back across, a downward chop. The heavy stab draws back
		-- to the centre with both hands, thrusts, holds, recovers.
		Slash1 = {
			length = 0.42,
			pivot = "Grip",
			keys = {
				key(0, ZERO, ZERO),
				key(
					0.18,
					Vector3.new(0.1, 0.08, 0.04),
					Vector3.new(-12, -25, 20),
					Enum.EasingStyle.Quad,
					OUT
				),
				key(
					0.45,
					Vector3.new(-0.38, -0.14, -0.22),
					Vector3.new(18, 55, -40),
					Enum.EasingStyle.Quad,
					OUT
				),
				key(1, ZERO, ZERO, Enum.EasingStyle.Sine, INOUT),
			},
		},
		Slash2 = {
			length = 0.42,
			pivot = "Grip",
			keys = {
				key(0, ZERO, ZERO),
				key(
					0.18,
					Vector3.new(-0.22, 0.1, 0.02),
					Vector3.new(-10, 35, -30),
					Enum.EasingStyle.Quad,
					OUT
				),
				key(
					0.45,
					Vector3.new(0.22, -0.12, -0.22),
					Vector3.new(15, -45, 35),
					Enum.EasingStyle.Quad,
					OUT
				),
				key(1, ZERO, ZERO, Enum.EasingStyle.Sine, INOUT),
			},
		},
		Slash3 = {
			length = 0.5,
			pivot = "Grip",
			keys = {
				key(0, ZERO, ZERO),
				key(
					0.22,
					Vector3.new(-0.05, 0.22, 0.08),
					Vector3.new(-45, 5, 0),
					Enum.EasingStyle.Quad,
					OUT
				),
				key(
					0.48,
					Vector3.new(-0.1, -0.24, -0.3),
					Vector3.new(50, 10, 0),
					Enum.EasingStyle.Quad,
					OUT
				),
				key(1, ZERO, ZERO, Enum.EasingStyle.Sine, INOUT),
			},
		},
		HeavyStab = {
			length = 0.9,
			pivot = "Grip",
			keys = {
				key(0, ZERO, ZERO),
				key(
					0.28,
					Vector3.new(-0.2, -0.02, 0.2),
					Vector3.new(-22, 18, 12),
					Enum.EasingStyle.Quad,
					OUT
				),
				key(
					0.46,
					Vector3.new(-0.2, 0.05, -0.5),
					Vector3.new(-30, 12, 6),
					Enum.EasingStyle.Quad,
					OUT
				),
				-- Pitched down from the blade-up hold so the point leads the thrust.
				key(0.62, Vector3.new(-0.2, 0.05, -0.47), Vector3.new(-30, 12, 6)),
				key(1, ZERO, ZERO, Enum.EasingStyle.Sine, INOUT),
			},
		},
		-- Body motion layered on the gun's own Reload clip (stretched to the reload
		-- time): tip the mag side toward you, a shove as it seats, then pushed
		-- out, lifted and turned muzzle-in while the support hand tugs the
		-- charging handle (clip 80-90%), so the hand reaches up beside the gun.
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
					0.7,
					Vector3.new(-0.03, -0.01, 0.01),
					Vector3.new(-4, 5, -8),
					Enum.EasingStyle.Quad,
					OUT
				),
				key(0.8, Vector3.new(-0.05, 0.05, -0.26), Vector3.new(7, 15, -8)), -- out, handle side up
				key(0.88, Vector3.new(-0.05, 0.05, -0.27), Vector3.new(6.5, 16, -9)), -- tugged
				key(1, ZERO, ZERO, Enum.EasingStyle.Quad, INOUT),
			},
		},
		-- Empty reload: the same mag swap (seated by 52%), then the full rack of
		-- the charging handle (clip 80-90%).
		ReloadEmpty = {
			length = 1,
			pivot = "Center",
			keys = {
				key(0, ZERO, ZERO),
				key(
					0.12,
					Vector3.new(-0.05, -0.05, 0.03),
					Vector3.new(7, 8, -16),
					Enum.EasingStyle.Sine,
					OUT
				),
				key(0.4, Vector3.new(-0.06, -0.07, 0.04), Vector3.new(4, 10, -20)),
				key(0.5, Vector3.new(-0.05, -0.04, 0.05), Vector3.new(6, 9, -17)), -- seated
				key(
					0.62,
					Vector3.new(-0.03, -0.03, 0.03),
					Vector3.new(2, 6, -6),
					Enum.EasingStyle.Sine,
					INOUT
				),
				-- Pushed out, lifted and turned muzzle-in (like the first draw), so
				-- the hand on the charging handle reaches up beside the gun.
				key(0.76, Vector3.new(-0.05, 0.06, -0.3), Vector3.new(8, 16, -8)), -- handle side up
				key(0.86, Vector3.new(-0.06, 0.065, -0.33), Vector3.new(7, 19, -10)), -- handle back
				key(
					0.91,
					Vector3.new(-0.03, 0.04, -0.15),
					Vector3.new(7, 10, -5),
					Enum.EasingStyle.Back,
					OUT
				), -- released
				key(1, ZERO, ZERO, Enum.EasingStyle.Quad, INOUT),
			},
		},
	} :: { [string]: Track },
})
