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
	-- The track is the whole move (position and rotation): the gun's Blender
	-- clip of the same name doesn't play (the knife's attacks and inspect).
	own: boolean?,
	-- Keyed on screen: offsets and turns in camera axes about the grip (x
	-- right, y up, z back), turns interpolated as rotations (slerp), not as
	-- angles. tools/studio/knife_fp_keys.py solves the knife's from where the
	-- blade should be seen.
	screen: boolean?,
	-- A spline through the keys with the velocity carried through each one
	-- (Util/ViewmodelTracks sampleSmooth); per-key easing is ignored.
	smooth: boolean?,
	-- The knife thrown out of the fist and caught: keys in the knife's own
	-- handle space (turns in degrees about `tossPivot`), on top of the track;
	-- the arm stays on the fist meanwhile (Util/ViewmodelTracks toss).
	toss: { Key }?,
	tossPivot: Vector3?,
	hit: number?, -- 0..1: the contact frame (knife attacks)
	-- Where the track's handling beats sit (0..1), by beat name ("MagOut",
	-- "MagIn", "Rack"). When the gun's own clip has the same beats
	-- (ViewmodelController clipBeats), the keys are time-warped so each beat
	-- of the track lands on the clip's: the mag slap on the mag going in, the
	-- muzzle kick on the rack. Revolvers and break-actions stand in "Open"
	-- for MagOut and "Close" for MagIn.
	marks: { [string]: number }?,
}

export type Pose = { pos: Vector3, rot: Vector3 }

-- `arm`: added to the hold's arm direction at this key (the forearm swings
-- with the move instead of sliding along at one angle).
export type ItemKey = { t: number, pos: Vector3, rot: Vector3, arm: Vector3? }
-- `smooth`: a spline through the keys with the speed carried through each
-- one (the monotone cubic of Util/ViewmodelTracks; nothing drifts past a
-- key, overshoot is keyed). Without it every key is a full stop.
export type ItemAction = { length: number, hideAt: number?, smooth: boolean?, keys: { ItemKey } }

-- How one Mod's item sits in the right hand, where it differs from
-- ITEM_OFFSET / ITEM_ROTATION / ITEM_ARM (ITEM_HOLDS, by the model's name).
-- `lift` moves the item from the grip (on top of the model's HoldOffset
-- attribute), so the fist doesn't cover it.
-- `side`: the hand that holds it (default Right; the bow is Left, drawn with
-- the Right); `from`: where it rises from (default ITEM_FROM); `scale`: the
-- viewmodel copy's size (pushing a held item back keeps the block arms from
-- filling the screen; the scale keeps it big).
export type ItemHold = {
	offset: Vector3?,
	rotation: Vector3?,
	arm: Vector3?,
	lift: Vector3?,
	side: ("Left" | "Right")?,
	from: Vector3?,
	scale: number?,
	seat: number?, -- studs the fist sits back along the forearm from the grip (ITEM_SEAT)
}

-- One moving part of the held item (ITEM_PART_MOVES; Util/ViewmodelHeldMods
-- moveItemPart). The part named `part` (or its `part`_<Material> pieces)
-- either turns by `angle` (degrees, in the axes of the attachment `pivot`,
-- about its position) or slides so that its centre lands on the attachment
-- `to`. `anchor` picks another point of the part's box to land there, in
-- half-sizes from the centre ((0, 1, 0): the middle of its top face; a
-- MeshPart's CFrame is its box centre, not the modeller's origin), and the
-- attachment `from`, when the model has it, is used instead. It starts
-- `at` seconds after the call and takes `time` seconds on `style` / `dir`
-- (Quad Out when left out; Back Out overshoots and settles). `back`: it
-- returns to rest over this many seconds once it has arrived (a pressed
-- pad springing up), after staying there `hold` seconds. A part or
-- attachment the model doesn't have: nothing happens. The item is whole
-- again the next time it's held.
export type PartMove = {
	part: string,
	pivot: string?,
	angle: Vector3?,
	to: string?,
	from: string?,
	anchor: Vector3?,
	at: number,
	time: number,
	style: Enum.EasingStyle?,
	dir: Enum.EasingDirection?,
	back: number?,
	hold: number?,
}

-- A free-hand pose reached by a keyed move instead of the plain ease
-- (FREE_POSE_MOVES): the keys start at the pose the hand leaves and end on
-- the pose it's named for.
export type HandMove = { length: number, smooth: boolean?, keys: { HandKey } }
-- A held free-hand pose that follows the view's turn (FREE_POSE_STEER): the
-- fist trails `lag` studs per rad/s of yaw (at most `max`), its arm swings
-- `swing` per stud trailed, eased at `rate` (1/s).
export type HandSteer = { lag: number, max: number, swing: number, rate: number }

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
	smooth: boolean?, -- a spline through the keys (see ItemAction)
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
local inspectLock = require(script.Parent.SkinPreview).SHADOW_MIST.INSPECT_LOCK

local function ruinInspect(
	length: number,
	show: Vector3,
	turn: Vector3,
	detail: Vector3,
	tilt: Vector3
): Track
	return {
		length = length,
		pivot = "Center",
		own = true,
		smooth = true,
		keys = {
			key(0, ZERO, ZERO),
			key(0.09, Vector3.new(0.02, -0.04, -0.06), Vector3.new(-4, -6, 4)),
			key(0.23, show, turn),
			key(0.43, show + detail, turn + tilt),
			key(0.60, show + detail * 0.62, turn + tilt * 0.32),
			key(0.76, show + detail * 0.48, turn + tilt * 0.64),
			key(inspectLock - 0.02, show * 0.48, turn * 0.39),
			key(inspectLock, show * 0.40 + Vector3.new(0, -0.026, -0.026), turn * 0.31),
			key(0.97, show * -0.035, turn * -0.042),
			key(1, ZERO, ZERO),
		},
	}
end

local function ruinDraw(start: Vector3, turn: Vector3, lift: Vector3): Track
	return {
		length = 1,
		pivot = "Grip",
		smooth = true,
		keys = {
			key(0, start, turn),
			key(0.19, start:Lerp(lift, 0.28), turn * 0.89),
			key(0.40, lift, turn * 0.53),
			key(0.58, lift * 0.62, turn * 0.19),
			key(0.66, Vector3.new(0.015, -0.023, 0.036), Vector3.new(-3.5, 0, 1.8)),
			key(0.82, Vector3.new(0.004, 0.016, -0.018), Vector3.new(1.4, 0, -0.6)),
			key(1, ZERO, ZERO),
		},
	}
end

local function ruinReload(show: Vector3, turn: Vector3): Track
	return {
		length = 2.5,
		pivot = "Center",
		smooth = true,
		marks = { MagOut = 0.17, MagIn = 0.61 },
		keys = {
			key(0, ZERO, ZERO),
			key(0.08, show * 0.28, turn * 0.47),
			key(0.17, show * 0.81, turn * 0.87),
			key(0.32, show, turn),
			key(0.50, show + Vector3.new(-0.025, 0.019, 0.026), turn * 0.92),
			key(0.58, show * 0.76, turn * 0.68),
			key(0.61, show * 0.64 + Vector3.new(0, -0.027, -0.035), turn * 0.50),
			key(0.76, show * 0.42, turn * 0.31),
			key(0.95, show * -0.04, turn * -0.05),
			key(1, ZERO, ZERO),
		},
	}
end
local OUT = Enum.EasingDirection.Out
local INOUT = Enum.EasingDirection.InOut

-- The gun Inspect track (TRACKS.Inspect and its per-gun copies, INSPECT_TRACK):
-- the same turns; a copy may add a `toss` (the gun leaves the fist, spins and
-- lands back; keys in the gun's own handle space, turns about `tossPivot`).
local function inspectTrack(toss: { Key }?, tossPivot: Vector3?): Track
	return {
		length = 2.8,
		pivot = "Center",
		keys = {
			key(0, ZERO, ZERO),
			key(
				0.035,
				Vector3.new(0.03, -0.035, 0.02),
				Vector3.new(-4, -8, 4),
				Enum.EasingStyle.Sine,
				OUT
			), -- wind-up
			key(
				0.14,
				Vector3.new(-0.27, 0.185, -0.13),
				Vector3.new(9, 70, -21),
				Enum.EasingStyle.Quad,
				OUT
			), -- snap past the right side
			key(
				0.2,
				Vector3.new(-0.255, 0.17, -0.125),
				Vector3.new(5, 60, -15),
				Enum.EasingStyle.Sine,
				INOUT
			),
			key(
				0.31,
				Vector3.new(-0.24, 0.2, -0.14),
				Vector3.new(15, 55, -26),
				Enum.EasingStyle.Sine,
				INOUT
			), -- tip it to show the top
			key(
				0.42,
				Vector3.new(-0.245, 0.185, -0.145),
				Vector3.new(4, 58, -12),
				Enum.EasingStyle.Sine,
				INOUT
			),
			key(
				0.47,
				Vector3.new(-0.22, 0.18, -0.13),
				Vector3.new(3, 66, -8),
				Enum.EasingStyle.Sine,
				OUT
			), -- wind-up for the flip
			key(
				0.575,
				Vector3.new(-0.43, 0.175, -0.39),
				Vector3.new(-8, -62, 23),
				Enum.EasingStyle.Quad,
				OUT
			), -- whip past the left side
			key(
				0.64,
				Vector3.new(-0.42, 0.16, -0.37),
				Vector3.new(-4, -53, 18),
				Enum.EasingStyle.Sine,
				INOUT
			),
			key(
				0.75,
				Vector3.new(-0.4, 0.2, -0.36),
				Vector3.new(10, -50, 13),
				Enum.EasingStyle.Sine,
				INOUT
			), -- muzzle up, a look down the side
			key(
				0.85,
				Vector3.new(-0.42, 0.15, -0.36),
				Vector3.new(-1, -52, 17),
				Enum.EasingStyle.Sine,
				INOUT
			),
			key(
				0.885,
				Vector3.new(-0.44, 0.17, -0.37),
				Vector3.new(2, -57, 20),
				Enum.EasingStyle.Sine,
				OUT
			), -- wind-up
			key(
				0.95,
				Vector3.new(0.02, -0.03, 0.02),
				Vector3.new(-3.5, 4, -3),
				Enum.EasingStyle.Quad,
				OUT
			), -- home, past the hold
			key(1, ZERO, ZERO, Enum.EasingStyle.Sine, INOUT),
		},
		toss = toss,
		tossPivot = tossPivot,
	}
end

-- Tempest-Strike shell reload, Start part: a smooth tilt toward the port (the
-- right side for the Marshal's side gate) on top of the clip's own turn into
-- the loading pose, settling to nothing as the clip holds it. 2026-11-22 v2
-- (owner: the Bucky and Marshal reloads were "very glitchy and choppy"): no
-- barrel roll any more (it fought the clip's turn), and no per-shell push.
local function shellStart(rightSide: boolean): Track
	local side = if rightSide then -1 else 1
	return {
		length = 1,
		pivot = "Center",
		smooth = true,
		keys = {
			key(0, ZERO, ZERO),
			key(0.35, Vector3.new(-0.015, 0.025, -0.015), Vector3.new(3, 2 * side, -5 * side)),
			key(0.75, Vector3.new(-0.006, 0.01, -0.006), Vector3.new(1.2, 0.8 * side, -2 * side)),
			key(1, ZERO, ZERO),
		},
	}
end

-- The Tempest-Strike inspect (2026-11-22, our own design; Util/TempestIdle draws
-- the water on the same beats), rolling about `tossPivot`: each gun's own
-- middle (TempestProfiles roll), so it turns inside its water ring.
local function tempestInspect(tossPivot: Vector3): Track
	return {
		length = 5.0,
		pivot = "Center",
		own = true,
		smooth = true,
		keys = {
			key(0, ZERO, ZERO),
			key(0.05, Vector3.new(0.02, -0.04, -0.04), Vector3.new(-4, -6, 4)),
			-- 2026-11-22 (owner: "a little clunky"): no stop in the middle any
			-- more. The roll happens while the gun swings from the right side
			-- to the left, so it reads as one flowing move; each pose drifts.
			key(0.15, Vector3.new(-0.47, 0.31, -0.94), Vector3.new(17, 70, -23)),
			key(0.2, Vector3.new(-0.44, 0.28, -0.9), Vector3.new(12, 62, -17)),
			key(0.3, Vector3.new(-0.45, 0.31, -0.93), Vector3.new(22, 59, -26)),
			key(0.4, Vector3.new(-0.43, 0.29, -0.91), Vector3.new(14, 65, -18)),
			-- passes muzzle-up (the stock drops out of the face) for the roll
			key(0.52, Vector3.new(-0.36, 0.4, -0.9), Vector3.new(50, 6, -4)),
			key(0.63, Vector3.new(-0.44, 0.22, -0.73), Vector3.new(-10, -62, 24)),
			key(0.69, Vector3.new(-0.41, 0.2, -0.69), Vector3.new(-4, -52, 18)),
			key(0.8, Vector3.new(-0.4, 0.24, -0.68), Vector3.new(10, -48, 12)),
			key(0.87, Vector3.new(-0.42, 0.21, -0.69), Vector3.new(2, -55, 19)),
			key(0.945, Vector3.new(0.02, -0.03, 0.02), Vector3.new(-3.5, 4, -3)),
			key(1, ZERO, ZERO),
		},
		-- the barrel roll: lifts off the fists, one turn about the bore, caught
		toss = {
			key(0, ZERO, ZERO),
			key(0.44, ZERO, ZERO),
			key(0.475, Vector3.new(0, 0.05, 0), Vector3.new(0, 0, -80)),
			key(0.52, Vector3.new(0, 0.08, 0), Vector3.new(0, 0, -215)),
			key(0.565, Vector3.new(0, 0.05, 0), Vector3.new(0, 0, -335)),
			key(0.59, Vector3.new(0, -0.005, 0), Vector3.new(0, 0, -362)),
			key(0.62, ZERO, Vector3.new(0, 0, -360)),
			key(1, ZERO, Vector3.new(0, 0, -360)),
		},
		tossPivot = tossPivot,
	}
end

-- The gun Draw track (TRACKS.Draw and its per-class copies, DRAW_TRACK): every
-- copy is the same raise, rack and settle; only where the gun comes in from
-- (`from`, `fromRot`: the first key) differs.
local function drawTrack(from: Vector3, fromRot: Vector3): Track
	return {
		length = 0.9,
		pivot = "Grip",
		-- 2026-11-14 (owner: "smoother, not a complete linear animation"):
		-- through a spline, the velocity carried through each key, so the
		-- swing flows into the rack and the drop instead of easing to a stop
		-- at every key (Util/ViewmodelTracks).
		smooth = true,
		marks = { Rack = 0.58 },
		keys = {
			key(0, from, fromRot),
			key(
				0.2,
				Vector3.new(-0.06, 0.105, -0.33),
				Vector3.new(12, 15, -13),
				Enum.EasingStyle.Quad,
				OUT
			), -- lands past the rack pose
			key(
				0.3,
				Vector3.new(-0.05, 0.065, -0.3),
				Vector3.new(7, 17, -9),
				Enum.EasingStyle.Sine,
				INOUT
			), -- settled
			key(
				0.42,
				Vector3.new(-0.075, 0.055, -0.31),
				Vector3.new(4.5, 22, -12.5),
				Enum.EasingStyle.Quad,
				OUT
			), -- yanked: pulled toward the hand
			key(
				0.54,
				Vector3.new(-0.068, 0.062, -0.32),
				Vector3.new(5.5, 20.5, -11.5),
				Enum.EasingStyle.Sine,
				INOUT
			), -- held
			key(
				0.58,
				Vector3.new(-0.03, 0.095, -0.21),
				Vector3.new(17, 9, -5),
				Enum.EasingStyle.Quad,
				OUT
			), -- let go: the muzzle snaps up
			key(
				0.74,
				Vector3.new(0.012, -0.035, 0.025),
				Vector3.new(-4.5, -1.5, 3.5),
				Enum.EasingStyle.Quad,
				INOUT
			), -- drops past the hold
			key(
				0.87,
				Vector3.new(-0.002, 0.01, -0.006),
				Vector3.new(1.4, 0.4, -0.9),
				Enum.EasingStyle.Sine,
				INOUT
			), -- bounce
			key(1, ZERO, ZERO, Enum.EasingStyle.Sine, INOUT),
		},
	}
end

return table.freeze({
	-- Guns are modelled at world size; first person shows them at this scale.
	SCALE = 0.8, -- 0.75 until 2026-11-08 (owner: guns bigger, more personal)
	-- Added to every gun's hip viewmodelOffset (per gun: hipShift): right, up,
	-- toward the camera. Owner 2026-11-08: more right, up close, a bit higher.
	-- 2026-11-11 (owner, looking at RIVALS: "hold it down a little more, a
	-- little more to the left, it's too much to the right"): was (0.05, 0.05,
	-- 0.035); now 0.06 left and 0.05 lower than that, same depth.
	HIP_SHIFT = Vector3.new(-0.01, 0, 0.035),
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
	-- The scope's glass (parts by name) fades out between aim `from` and `to`:
	-- its eyepiece reaches the middle of the view (within 0.1 stud of the sight
	-- line, 0.65 stud from the eye) at aim ~0.5, well before SCOPE_AT, and the
	-- Glass caught the light there (owner 2026-11-20: "a reflective part shows
	-- in the middle"; measured on the Marshal, every skin uses ScopeLens).
	SCOPE_LENS = { names = { "ScopeLens" }, from = 0.12, to = 0.4 },
	-- How the gun travels into and out of the sights (2026-11-15, owner: "make
	-- all ADS feel better"). It was a smootherstep along a straight line, the
	-- zoom locked to it. The owner's clips (60 fps): the gun is on the sights
	-- in 100-170 ms on a straight diagonal, and the zoom starts with it but
	-- lands later (90% at 130-235 ms, done at 230-330 ms, an ease-out).
	-- The aim alpha itself stays a straight ramp over the gun's adsTime (the
	-- server runs the same one); the gun is drawn at that ramp's goal (hip or
	-- sights) through a spring, so it leaves at once, is on the sight line at
	-- ~0.85 x adsTime, lands a hair past it and settles, and a half-finished
	-- aim turns round carrying its speed. The cant and the dip are ours (the
	-- clips have none; the owner wants no move to be a straight slide), kept
	-- small; both are zero at rest, so the sight picture is unchanged.
	ADS_FEEL = table.freeze({
		-- Spring speed: omega = reach / adsTime.
		reach = 4.3,
		damping = 0.82, -- about 1% past the pose, once
		cant = 1.6, -- degrees of roll at the fastest point of the move (top leans into it)
		dip = 0.01, -- studs under the straight line at the halfway point
		pull = 0.008, -- studs toward the eye at the halfway point
		-- The zoom: a critically damped spring, omega = zoomReach / adsTime
		-- (3.2 = 90% at ~1.2 x adsTime). Out of the sights it lets go faster
		-- (the clips: the zoom is gone ~180-280 ms after the gun drops).
		zoomReach = 3.2,
		zoomOutReach = 5.5,
	}),

	-- Arms (Util/ViewmodelArms): one bevelled block per arm, RIVALS style.
	-- Mesh from tools/blender/make_arm_mesh.py (art-source/viewmodel/Arms.fbx,
	-- Model asset 112778616991962), native size ARM_MESH_SIZE, drawn
	-- ARM_WIDTH wide.
	ARM_MESH = {
		-- 2026-11-12: a sharp block with one small chamfer (0.035), flat faces,
		-- from the owner's RIVALS screenshots (Model asset 115198041447582).
		-- The soft one was Right 78886981056288, Left 98808533168115
		-- (art-source/viewmodel/Arms_soft_2026-10.fbx).
		Right = "rbxassetid://78825608252004",
		Left = "rbxassetid://83057920713890",
	},
	ARM_MESH_SIZE = Vector3.new(1, 5, 1),
	-- The shirt layer (only when the avatar wears a classic Shirt; without one
	-- the arm is plain skin, the owner's call 2026-11-12): `inflate` times
	-- fatter than the arm, starting `bare` studs up from the hand end, so you
	-- see "their shirt a little bit and then the skin colour" at the hand.
	ARM_SLEEVE = {
		inflate = 1.035,
		bare = 0.62,
	},
	-- A very slight dark outline round the hands (owner 2026-11-12: "barely
	-- noticeable"): the block inside out, `rim` studs larger all round, so a
	-- dark edge that wide shows behind it. It sits inside the shirt layer, so
	-- only the bare hand and wrist get it. rim 0 = no outline.
	ARM_OUTLINE = {
		mesh = {
			Right = "rbxassetid://122296327703241",
			Left = "rbxassetid://118374129783625",
		},
		rim = 0.0028, -- 0.006 read as a cartoon line; 0.004 "slightly too thick" (owner)
		color = Color3.fromHex("0C0C0E"),
		transparency = 0.35,
	},
	-- A very slight dark outline round the gun too (owner 2026-11-12: "super
	-- slight. Rivals has it as well"; to become a player setting later, so it
	-- is one switch here). A Roblox Highlight on the gun: outline only, no
	-- fill, hidden behind walls like the gun itself. A Highlight's line has a
	-- fixed width on screen, so `transparency` is the only strength control
	-- (1 = invisible). It fades out as you aim, so the sight picture is clean.
	GUN_OUTLINE = {
		enabled = true,
		color = Color3.fromHex("0C0C0E"),
		transparency = 0.62,
	},
	ARM_WIDTH = 0.5,
	-- Arms drawn this much longer than the mesh (2026-11-08: the cut end
	-- showed in knife slashes and the Shorty inspect).
	ARM_LENGTH_SCALE = 1.45,
	-- `screen` tracks (the knife's attacks): the blade's turn trails the
	-- hand's travel by this many seconds, so the wrist follows through.
	SCREEN_LAG = 0.035,
	-- ...and the knife FOLLOWS its keyed pose through a spring (2026-11-15,
	-- owner: the motion is "a little blocky"). The keys are poses and the
	-- spline between them is monotone, so the knife stopped dead on every one
	-- (stop, go, stop). Through an underdamped spring a stop has a little
	-- give, a turn carries through, and a move that cuts into another starts
	-- with the speed the last one had. Position and turn have their own
	-- (Hz, damping ratio: lower = more overshoot). An attack is drawn exactly
	-- on its keys up to `hit` (the strike lands where and when it is keyed)
	-- and the spring comes in over `after` seconds from there; every track
	-- lets go of it over its last `out` share, so it ends on the hold.
	SCREEN_FOLLOW = table.freeze({
		frequency = 8.5,
		damping = 0.62,
		turnFrequency = 7.5,
		turnDamping = 0.58,
		after = 0.08,
		out = 0.08,
	}),
	-- A melee hit drags the swing instead of stopping it (owner, 2026-11-15:
	-- the hit "kind of just stops... it seems choppy"; the old hit-stop held
	-- one frame for 66-100 ms, then carried on at full speed). The swing's
	-- speed dips to `floor` of normal over the first `into` share of the drag
	-- and eases back to full over the rest; the drag lasts the attack's `stop`
	-- (Config/Animations KNIFE_FEEL) times `stretch`. It eats about
	-- (1 - floor) / 2 of that time. floor = 0 with stretch = 1 is close to the
	-- old dead stop.
	HIT_DRAG = table.freeze({ floor = 0.35, stretch = 2, into = 0.22, max = 0.3 }),
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

	-- Arm follow-through (2026-11-10, owner: "hands smoother, nicer"). The hand
	-- stays exactly on its grip; the arm's direction trails where the gun asks
	-- it to point on a critically damped spring (rad/s, camera space), so a
	-- kick, a sway or a pose change bends at the wrist instead of turning gun
	-- and arms as one stiff piece. 34 settles in about 0.17 s: a shot's punch
	-- (peak ~25 ms) reaches the forearm at roughly half size, a beat late.
	-- Aimed it stiffens to ARM_FOLLOW_ADS. 0 = rigid, as before.
	ARM_FOLLOW = 34,
	ARM_FOLLOW_ADS = 80,

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
		-- 2026-11-12 (owner's RIVALS references: the support arm is a long
		-- diagonal in from the lower left): was (-0.18, -0.95, 0.25), nearly
		-- straight down. Leaning left also takes it further from the mag.
		direction = Vector3.new(-0.5, -0.8, 0.3),
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
		-- 2026-11-08 (owner: the hold looked off): the fist on the handle with
		-- the forearm running down and back to the right, not along the blade line.
		-- 2026-11-12 (owner: "it's held in the middle of the hand... on the side
		-- of the hand, on the inside"): the fist sits beside the handle, so the
		-- knife lies along its inner edge (was offset (0.01, -0.04, 0.1), the
		-- handle through the middle of the block). Tuned live with VmRightHand.
		-- 2026-11-12, later (owner: "too much of the knife is out of the hand...
		-- tilted weirdly in the hand"): the fist moved up the handle toward the
		-- guard and a little further round it, so only the guard and blade
		-- show above it (was (0.143, 0.029, 0.241)).
		-- 2026-11-14 (owner: "keep it on the edge of the hand", "seeing the
		-- bottom through the hand"): the knife is rigid in the block fist. The
		-- hilt is 0.8 studs guard to pommel and the block 0.5 wide, so the handle
		-- runs 15 degrees off the forearm, inside the block on its inner edge,
		-- the guard just past the block's end (it crossed the block at 61 degrees
		-- and the pommel poked out). Knife handle space; `offset` is the fist's
		-- end point, `direction` the forearm. tools/studio/knife_fp_keys.py
		-- solves every knife key for this hold (was (0.115, 0.02, 0.07)).
		-- (Same day, after the RIVALS frame study: the fist's end at the handle's
		-- middle, the handle on the block's front-inner edge, so the guard and
		-- the top half of the handle show and the pommel half is inside; solved
		-- in play against the clip's hold.)
		-- (Pass 2, 2026-11-14, owner: "my hand is facing upwards to the sky...
		-- the arm should look normal and the knife being held as if there was a
		-- hand but there is not"): the RIVALS look. The forearm block ends at the
		-- wrist and reaches forward at the clip's screen angle (-57 deg); the
		-- whole knife sits just past its end, the pommel at the end face's
		-- centre, where an unseen hand holds it, 60 degrees off the forearm (a
		-- hammer grip). Nothing of the knife is inside the block.
		-- Then the owner's overlay ("lower the guard and shorten the visible
		-- grip... keep the grip over the arm's inner edge... angle the right
		-- forearm outward"): the knife comes up out of the TOP of the forearm's
		-- end, at its inner edge, like a fist gripping it: the pommel half is
		-- inside the block (measured: nothing outside), the guard and ~40% of
		-- the handle show; the forearm reaches forward from the lower right.
		offset = Vector3.new(0.0199, -0.0167, 0.285),
		direction = Vector3.new(-0.6634, 0.5567, 0.5),
	} :: Hand,
	-- Melee (2026-11-12, owner: on the heavy stab "the hand goes across the
	-- whole body, it looks really wrong"). The knife arm always runs from the
	-- hand to the right shoulder (root space, off-screen low right) instead of
	-- a direction fixed to the knife: however the blade turns in a swing, the
	-- forearm comes from the same place. MELEE_HAND.direction is unused now.
	-- (Later the same day, from the owner's RIVALS screenshots: both knife
	-- arms come in as long diagonals from the bottom corners, so the shoulder
	-- sits wide and less far down; it was (0.9, -3.6, 0.4), nearly straight up.)
	-- (And less wide again, (2.5, -2.7, 0.7) → this: the forearm runs closer to
	-- the handle's own line, so the knife doesn't stick out of the fist at an
	-- angle. Still tilted in, as in the reference.)
	-- 2026-11-14: on the RIVALS-matched hold's own forearm line (was
	-- (1.95, -3.0, 0.55)); tools/studio/knife_fp_keys.py SHOULDER matches.
	MELEE_SHOULDER = Vector3.new(0.08, -1.95, 1.60),
	-- The knife's forearm stays at least this many degrees from the blade's
	-- line, so the handle sits across the fist (2026-11-12).
	-- How far the knife forearm may bend from rigid toward MELEE_SHOULDER
	-- (degrees): a block fist has no visible wrist, so only a little give.
	-- (Replaces MELEE_ARM_ANGLE, the 62 degree clamp of 2026-11-12.)
	-- Pass 2 (owner: "the slashes... stay upright"; the clip bends the wrist
	-- hard mid-swing so the blade lies over and trails): up to this many
	-- degrees, pivoting about MELEE_WRIST_PIVOT (knife handle space, inside
	-- the fist by the pommel) so the handle stays seated in the block.
	MELEE_WRIST_BEND = 20, -- 45 let the handle slide out onto the forearm mid-slash
	MELEE_WRIST_PIVOT = Vector3.new(0, 0, 0.3), -- where the handle crosses the forearm, inside it
	-- The off hand isn't a statue (owner 2026-11-12: "it's not moving with the
	-- slashes"). As the knife travels from its hold the off hand goes with the
	-- body: `travel` of the knife's sideways move, and it pulls `back` toward
	-- you and `drop` down (studs) once the knife is `reach` studs from rest.
	-- 2026-11-14 (owner's knife clip: the free arm drops right out of view for
	-- every slash and rises back with the knife): drop 0.13 -> 0.8, back 0.26
	-- -> 0.3, reach 0.8 -> 0.6.
	FREE_HAND_FOLLOW = { travel = 0.3, back = 0.3, drop = 0.8, reach = 0.6 },
	-- The heavy stab is one-handed from the chest; true puts the free hand on
	-- the handle for it again (MELEE_TWO_HAND).
	-- 2026-11-14 (owner's knife clip: both arms come in for the heavy's
	-- thrust): true again, but only for the thrust, from `from` to `to` of
	-- the HeavyStab track (the hand blends on and off over FREE_HAND_BLEND).
	MELEE_HEAVY_TWO_HAND = true,
	-- Where the free fist goes for it: beside the knife fist, a little left,
	-- lower and nearer (root space from the knife's grip), its arm running in
	-- from the lower left (the clip; on the handle it hid behind the knife arm).
	MELEE_HEAVY_HAND = {
		from = 0.4,
		to = 0.68,
		offset = Vector3.new(-0.34, -0.14, 0.18),
		direction = Vector3.new(-0.55, -0.65, 0.5),
	},
	-- The knife's pull-out track (Config TRACKS): "DrawMelee" (the clip's quick
	-- twirl, 2026-11-14) or "DrawMeleeSwipe" (the 2026-11-08 swipe-out). The
	-- free arm stays out of view until this far through it.
	MELEE_DRAW_TRACK = "DrawMelee",
	FREE_HAND_DRAW_AT = 0.68,
	-- The knife is never quite still in the hand: a slow roll and turn while
	-- you hold it (degrees, cycles per second).
	-- (`fade`: 1/s it eases out for a swing and back in after; it stays on
	-- through the inspect and the pull-out, so their holds keep moving.)
	MELEE_IDLE = { roll = 2.6, yaw = 1.6, lean = 2, lift = 0.012, rate = 0.33, fade = 10 },

	-- Running with a pistol (owner 2026-11-11: "your left hand will swing and
	-- your right hand swings independently and holds the gun"): the support
	-- hand lets go and pumps like a runner's arm, forward and up then back out
	-- of view, half a stride out of step with the gun. Root space, blended in
	-- by the Sprint pose's weight. Swing = studs sideways, up, forward at the
	-- front of the swing.
	PISTOL_RUN_HAND = {
		offset = Vector3.new(-0.66, -0.95, -0.95), -- lower and wider 2026-11-12 ("looks a little bit off")
		direction = Vector3.new(-0.1, -0.85, 0.5),
	} :: Hand,
	PISTOL_RUN_SWING = Vector3.new(0.02, 0.085, 0.21), -- about two thirds of the first try

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
	-- The knife's free hand: low and out of frame like Valorant / RIVALS (it
	-- read as a stray fist in the corner at -0.56, -0.86, -0.95); it comes up
	-- onto the handle for the heavy stab (MELEE_TWO_HAND).
	-- 2026-11-08 (owner): both hands out with the knife, held in one: the free
	-- hand is a raised guard low on the left of the screen again (root space).
	-- FREE_HAND_HIDDEN: where it drops to during the inspect (one hand only).
	-- 2026-11-12 (RIVALS screenshots): a diagonal in from the bottom left
	-- corner, mirroring the knife arm; direction was (-0.22, -0.78, 0.58).
	FREE_HAND = {
		-- 2026-11-14 (owner's overlay: "move the empty forearm left and down,
		-- farther from the crosshair"): was (-0.55, -0.68, -1.1).
		offset = Vector3.new(-0.68, -0.8, -1.1),
		direction = Vector3.new(-0.6, -0.55, 0.58),
	} :: Hand,
	FREE_HAND_HIDDEN = {
		offset = Vector3.new(-0.7, -1.6, -0.75),
		direction = Vector3.new(-0.2, -0.8, 0.55),
	} :: Hand,
	-- Seconds the free hand takes to move onto the handle for the heavy stab and back.
	FREE_HAND_BLEND = 0.14,

	-- Dropped mags (Util/MagDrop): a reload clip's mag (or belt box) joint
	-- counts as out of the gun `away` studs (model units) from rest; a copy
	-- falls (studs/s, gravity studs/s²), bounces once, lies there for `life`
	-- seconds and fades over the last `fade`.
	MAG_DROP = {
		bones = { "Mag", "AmmoBox" },
		away = 0.12,
		gravity = 60,
		kick = 3,
		-- Thrown off the gun (camera space: right, up, forward), studs/s.
		-- Owner 2026-11-08: "kicked off and thrown forward", Valorant-like.
		throw = Vector3.new(1.6, 2.2, -6.5),
		spin = 11, -- rad/s tumble
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
	-- Shell loops: the loading hand sets off for the gate this far into
	-- ReloadStart (and is back on its grip this far before ReloadEnd's end).
	SHELL_GATE_REACH = 0.3,
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
	-- 2026-11-11 (owner: "more aggressive, more fun"): gain 2.4 → 3.4, limit
	-- 0.09 → 0.13, a touch slower (10 → 9), so the gun swings behind a flick.
	SWAY_FREQUENCY = 9,
	SWAY_GAIN = 3.4, -- steady lag = GAIN / FREQUENCY^2 radians per rad/s of turn
	SWAY_MAX = 0.13, -- radians, soft limit
	SWAY_SHIFT = 0.35, -- studs of shift per radian of lag

	-- Strafing drifts the gun against the motion and leans its top back
	-- against it (aimed values: the sights follow the strafe, gently); falling
	-- lifts it, landing dips it.
	STRAFE_ROLL = 0.0035, -- radians per stud/s of sideways speed
	STRAFE_SHIFT = 0.0022, -- studs per stud/s
	-- Aimed (owner 2026-11-10: "A tilts the gun a little left, D a little
	-- right"): the gun leans INTO the strafe, around the sight line, so the
	-- sight picture stays on the crosshair. Negative = into the motion; soft
	-- limited at ADS_STRAFE_ROLL_MAX. Was +0.0026 (about 1.5° against it).
	-- 2026-11-12, later (owner: "more drastic... like Rainbow Six Siege and
	-- Rivals: when you go right the gun rotates a bit to the left"): the
	-- direction is back to AGAINST the strafe (positive), and bigger: about
	-- 6 degrees at full aimed strafe speed, capped at ADS_STRAFE_ROLL_MAX. The
	-- same-day earlier value was -0.0075 (into the strafe, capped at 4.5).
	ADS_STRAFE_ROLL = 0.012,
	ADS_STRAFE_ROLL_MAX = 7.5, -- degrees
	ADS_STRAFE_SHIFT = 0.00015, -- 0.0008 until 2026-11-12: at full strafe the sight sat 34 px off the crosshair
	TILT_FREQUENCY = 8,
	-- Fore-aft weight (2026-11-10): moving forward the gun settles back toward
	-- you and its muzzle dips a touch; backpedalling pushes it out. Studs and
	-- radians per stud/s of forward speed, on its own spring.
	SURGE_SHIFT = 0.0012,
	SURGE_PITCH = 0.0009,
	SURGE_FREQUENCY = 7,
	FALL_LAG = 0.005, -- studs per stud/s of vertical speed (clamped to FALL_LAG_MAX); 0.0035 until 2026-11-12
	FALL_LAG_MAX = 0.11, -- 0.07 until 2026-11-12
	-- In the air (2026-11-12, owner: "an animation with the hands when you
	-- jump and when you're falling"). Going up the muzzle tips up; coming
	-- down it tips down, the gun rolls out a little and both elbows flare
	-- away from the body, more the faster you fall. Eased on a spring.
	AIR_FREQUENCY = 7,
	AIR_PITCH = 0.13, -- degrees of muzzle tip per stud/s of vertical speed...
	AIR_PITCH_MAX = 5.5, -- ...up to this
	AIR_ROLL = 6, -- degrees the gun rolls outward at AIR_FALL_SPEED
	AIR_FALL_SPEED = 50, -- studs/s of fall that give the full roll and flare
	AIR_ELBOW = 0.32, -- how far the elbows swing out at full flare (share of the arm's length)
	-- Crouching and standing up: a dip as you drop, a lift as you rise (studs,
	-- on the bounce spring below, so each one settles with a wobble).
	CROUCH_BOUNCE = 0.045,
	LAND_KICK = 0.9, -- studs/s of downward kick on a hard landing
	-- Bounce (2026-11-11, owner: "bouncing and everything like that"): one
	-- springy up-down channel on the whole rig, underdamped so it overshoots
	-- and settles in a couple of wobbles. Landing drops the gun and it bounces
	-- back; a jump dips it as you push off. Peaks in studs (down); the muzzle
	-- tips with it (BOUNCE_PITCH radians per stud).
	BOUNCE_FREQUENCY = 3.1, -- Hz
	BOUNCE_DAMPING = 0.36, -- ratio (1 = no overshoot)
	BOUNCE_LAND = 0.12, -- peak at a full-speed fall (50 studs/s), scaled by fall speed
	BOUNCE_LAND_MIN = 0.03, -- every landing gets at least this
	BOUNCE_JUMP = 0.065,
	BOUNCE_PITCH = 0.45,
	BOUNCE_ADS = 0.35, -- share kept while aimed
	LIFT_FREQUENCY = 11,

	-- Walk bob: a figure-8 (sideways once per loop, a dip on each step, so
	-- twice per loop), sized by ground speed and eased in and out.
	-- 2026-11-10: the loop runs at the footsteps' cadence (one loop = two
	-- steps = 2 x the stride in Config/Audio STEPS), so the dips land with the
	-- footstep sounds; it was 1.0 / 0.85 loops/s against 3.2 / 3.5 steps/s.
	-- Sprinting (owner: "more move to it, a sway to the side") swings the gun
	-- side to side with the stride: `pos` = sideways, dip per step, fore-aft
	-- (a quarter loop behind the swing, so the gun travels a flat oval);
	-- `rot` = pitch, yaw, roll in degrees.
	BOB_REFERENCE_SPEED = 16, -- studs/s that give the walk amount
	BOB_WALK_STRIDE = 5, -- studs per step (Config/Audio STEPS.stride)
	BOB_SPRINT_STRIDE = 6.2,
	BOB_MIN_FREQUENCY = 0.6, -- loops per second, while easing to a stop
	BOB_WALK = { pos = Vector3.new(0.014, 0.008, 0), rot = Vector3.new(0.45, 0.5, 0.9) } :: Bob,
	-- (2026-11-11, second ask for "a left to right sway": wider sideways, less dip.)
	-- (2026-11-12, later: the owner's friends said running "feels a bit off":
	-- pulled back by about a quarter, from pos (0.125, 0.026, 0.035), rot
	-- (1.4, 4.6, 6), and the hang softened below.)
	-- (2026-11-13, lane B: the dip 0.024 -> 0.03. With the bob turning
	-- around BOB_PIVOT the roll no longer adds a lift, so each step's dip
	-- measured half as tall as before; this gives a little of it back.)
	BOB_SPRINT = { pos = Vector3.new(0.095, 0.03, 0.03), rot = Vector3.new(1.2, 3.4, 4.4) } :: Bob,
	BOB_EASE = 6, -- how fast the bob amount and speed ease (rad/s)
	-- The loop's shape (2026-11-12, owner: "the run animation seems a bit
	-- off"; LihFolk "Locomotion Readability": an even sine reads wrong). The
	-- swing hangs at each side and crosses the middle quickly (BOB_HANG: 0 = a
	-- plain sine). Each step rises slowly and drops quickly onto the footfall,
	-- the way a body does (BOB_STEP: 1 = even; 1.7 puts the top of the step
	-- two thirds of the way through it).
	BOB_HANG = 1.0,
	BOB_STEP = 1.7,
	-- 2026-11-13 (lane B, measured): sprinting, the step dips sat where the
	-- sideways swing crosses the middle (a walk's shape), so the roll's lift
	-- at each side pulled one dip early and the next late: dips 0.20 s then
	-- 0.36 s apart, a limp. A run is lowest at mid-stance, which is also
	-- where the body is furthest over the foot: the dip belongs at the ends
	-- of the swing (a U, not a frown). The vertical loop is shifted by this
	-- share of a quarter loop as the sprint blend comes in (0 = walk shape).
	BOB_RUN_SHIFT = 1,
	-- The bob's pitch, yaw and roll turn around this point (camera space,
	-- on the line of the gun by the right hand), not MOTION_PIVOT: turned around a
	-- point left of the hands, the roll lifted the hands on one step and
	-- dropped them on the next. Aimed, it moves to ADS_MOTION_PIVOT.
	BOB_PIVOT = Vector3.new(0.51, -0.66, -0.8), -- measured: rifle and pistol grips both sit at x 0.51

	-- Slide (2026-11-10): the gun drops in with a kick as the slide starts, the
	-- scrape chatters through it (faster and bigger the faster you slide), and
	-- it settles up with a small bounce as you come out.
	SLIDE_ENTER_KICK = Vector3.new(0.55, 1.5, 0.9), -- roll rad/s, drift studs/s, dip studs/s
	SLIDE_EXIT_KICK = 0.45, -- studs/s upward as the slide ends
	-- 2026-11-20 (owner: "the viewmodel must follow that roll so it looks
	-- seamless"; ADS "should tilt with the crosshair too"): degrees the whole
	-- viewmodel leans on screen, clockwise about the line of sight, on the
	-- crosshair's and camera's curve (Util/SlideTilt). Aimed it matches the
	-- crosshair's 20 (Config/Crosshair slideTilt), so the sights and the scope
	-- reticle lean as one; at the hip less, so the gun doesn't swing off
	-- screen. Provisional: the owner tunes it in play.
	SLIDE_CANT = { hip = 9, ads = 20 },
	SLIDE_CHATTER = { pos = 0.0045, roll = 0.5, rate = 11 }, -- studs, degrees, Hz at full slide speed
	SLIDE_REFERENCE_SPEED = 30, -- studs/s that give the full chatter

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
	KICK_BACK = 0.085, -- 0.05 until 2026-11-08, 0.065 until 2026-11-11 (owner: more recoil movement)
	KICK_ROTATE = 0.06, -- 0.035 until 2026-11-08, 0.045 until 2026-11-11
	RECOIL_STIFFNESS = 260,
	RECOIL_DAMPING = 24,
	-- Aimed: a snappy push back toward the eye with a small rise, settling
	-- fast (critically damped), so the sight picture stays on target. The
	-- gun's own Fire clip moves its Root joint (the whole gun) only
	-- ADS_CLIP_KICK of its hip amount while fully aimed.
	-- 2026-11-13 (lane B, measured): it was ADS_KICK_BACK 0.05 / ROTATE 0.006
	-- times the camera recoil.up and halved again while aimed, so an aimed
	-- Vandal shot moved the gun 0.014 studs and 0.8 degrees (hip: 0.16 and
	-- 8): aimed fire felt flat. Valorant's aimed shots visibly push the gun
	-- at you. Now sized per class (back: studs at the peak; rise: degrees).
	ADS_PUNCH = table.freeze({
		Sidearm = { back = 0.06, rise = 1 },
		SMG = { back = 0.035, rise = 0.5 },
		Rifle = { back = 0.05, rise = 0.7 },
		MachineGun = { back = 0.055, rise = 0.8 },
		Shotgun = { back = 0.11, rise = 2.5 },
		Sniper = { back = 0.12, rise = 2.5 }, -- scoped guns hide the gun in the scope; this is the way in and out
	} :: { [string]: { back: number, rise: number } }),
	ADS_PUNCH_GUN = table.freeze({
		Sheriff = { back = 0.09, rise = 1.2 }, -- 2.2 moved the sight 50 px off the crosshair (measured)
		Guardian = { back = 0.07, rise = 1.2 },
		Ghost = { back = 0.045, rise = 1 },
		Spectre = { back = 0.03, rise = 0.4 },
	} :: { [string]: { back: number, rise: number } }),
	ADS_PUNCH_TWIST = 0.3, -- random twist, as a share of the rise
	ADS_RECOIL_STIFFNESS = 700,
	ADS_CLIP_KICK = 0.2,

	-- Shot punch (2026-11-09, owner: "Valorant / RIVALS, recoil of the gun",
	-- shooting felt too smooth). The kick above scales with the gun's camera
	-- recoil.up, so the automatics (up 0.22-0.42) barely moved. This one is
	-- sized per class instead, hip fire only (aimed shots keep ADS_KICK_*):
	--   back  studs the gun slams back      rise  degrees the muzzle jumps
	--   yaw   degrees random side           roll  degrees random twist
	--   climb degrees the muzzle creeps up per shot in a spray, up to
	--         climbMax, settling after you let go (a slow spring)
	-- Peaks land on the shot within ~25 ms and settle in ~0.15 s (`punch`
	-- spring), the climb in ~0.35 s. Times the gun's viewmodelKick.
	SHOT_PUNCH = table.freeze({
		-- 2026-11-14 (owner's clips, vault Playtests/2026-11-14 Gun and Knife
		-- Feel from Videos): the pistol swings its back toward you, the gun ~25%
		-- bigger (was back 0.07, rise 5); the small SMG a small tight kick (was
		-- 0.045 / 1.8); rifles snap back more, muzzle less (was 0.06 / 2.4).
		Sidearm = { back = 0.12, rise = 9, yaw = 1.2, roll = 2.5, climb = 0, climbMax = 0 },
		SMG = { back = 0.04, rise = 1.5, yaw = 0.9, roll = 1.4, climb = 0.3, climbMax = 2.5 },
		Rifle = { back = 0.075, rise = 2.2, yaw = 0.9, roll = 1.8, climb = 0.35, climbMax = 3 },
		MachineGun = {
			back = 0.07,
			rise = 2.6,
			yaw = 1.3,
			roll = 2.2,
			climb = 0.3,
			climbMax = 3.5,
		},
		Shotgun = { back = 0.14, rise = 9, yaw = 1.5, roll = 3.5, climb = 0, climbMax = 0 },
		Sniper = { back = 0.2, rise = 12, yaw = 1, roll = 3.5, climb = 0, climbMax = 0 }, -- rocks back ~30% bigger, 20-25 deg (was 0.16 / 9)
	} :: { [string]: { [string]: number } }),
	-- Guns that differ from their class.
	SHOT_PUNCH_GUN = table.freeze({
		Ghost = { back = 0.05, rise = 3.5, yaw = 0.9, roll = 1.8, climb = 0, climbMax = 0 }, -- suppressed, the steady one
		Shorty = { back = 0.12, rise = 11, yaw = 2, roll = 4, climb = 0, climbMax = 0 }, -- pocket shotgun, wrist snap
		Judge = { back = 0.08, rise = 4.5, yaw = 1.5, roll = 2.5, climb = 0.8, climbMax = 5 }, -- auto shotgun
		Spectre = { back = 0.06, rise = 2.2, yaw = 0.8, roll = 1.8, climb = 0.35, climbMax = 3 }, -- the bigger SMG: the clip's hardest snap (was 0.035 / 1.4)
		Sheriff = { back = 0.14, rise = 13, yaw = 1.5, roll = 4, climb = 0, climbMax = 0 }, -- revolver: ~2.5x the pistol's flip, held at the peak (SHOT_SNAP)
		Phantom = { back = 0.05, rise = 2, yaw = 0.8, roll = 1.5, climb = 0.4, climbMax = 3.5 }, -- suppressed rifle
		Guardian = { back = 0.1, rise = 5, yaw = 1, roll = 2.5, climb = 0, climbMax = 0 }, -- DMR, one big shot
		Marshal = { back = 0.12, rise = 7, yaw = 1, roll = 2.5, climb = 0, climbMax = 0 }, -- lever
		Odin = { back = 0.08, rise = 2.2, yaw = 1.6, roll = 2.6, climb = 0.3, climbMax = 5 }, -- belt-fed, shudders
	} :: { [string]: { [string]: number } }),
	-- The shot's timing (2026-11-14; replaces the punch spring, stiffness 900 /
	-- damping 25, which peaked ~42 ms after the shot and wobbled). Every gun in
	-- the owner's clips snaps to its peak within one frame and eases home with
	-- no overshoot: nearly home by 100 ms, settled by 170 ms (pistol), the
	-- revolver holding its peak ~50 ms, the sniper ~200 ms. LihFolk Hit-Stop and
	-- Screen Shake Tuning by Numbers agrees: a 1-frame rise, 0.10-0.18 s home.
	-- `attack` / `decay`: seconds of the two exponentials (peak at ~13 ms with
	-- the defaults). SHOT_PUNCH sizes stay the peaks.
	SHOT_SNAP = table.freeze({
		attack = 0.006,
		decay = table.freeze({
			Sidearm = 0.05,
			SMG = 0.032,
			Rifle = 0.042,
			MachineGun = 0.048,
			Shotgun = 0.07,
			Sniper = 0.075,
		} :: { [string]: number }),
		gun = table.freeze({
			-- The revolver stays at its peak ~50 ms before it comes down (the
			-- owner's clip; 2026-11-15: two exponentials can't hold, so `hold`
			-- keeps the kick at full for this long after the shot).
			Sheriff = { attack = 0.006, decay = 0.035, hold = 0.06 },
			Guardian = { decay = 0.06 },
			Marshal = { decay = 0.07 },
			Shorty = { decay = 0.06 },
		} :: { [string]: { attack: number?, decay: number?, hold: number? } }),
	}),
	-- 2026-11-13 (lane B, measured): the climb was critically damped at 70
	-- and eased off at 7/s, so after a burst the gun took 0.43 s (Vandal),
	-- 0.67 s (Odin) and 1.0 s (Spectre) to come home: a soft, sticky finish.
	-- Now stiffer and a little underdamped, and it lets go at once when the
	-- shooting stops (ViewmodelController holdPose): home in ~0.35 s with a
	-- small dip past rest, like a gun the hands bring back down.
	CLIMB_STIFFNESS = 400,
	CLIMB_DAMPING_RATIO = 0.6, -- 1 = no overshoot
	-- 2026-11-11 (owner: "more recoil movement, more aggressive"): every
	-- SHOT_PUNCH back / rise / yaw / roll and climb step above is multiplied
	-- by this, and the climb's limit by PUNCH_CLIMB_SCALE. One knob for how
	-- hard the guns kick.
	PUNCH_SCALE = 1.5,
	PUNCH_CLIMB_SCALE = 1.3,
	-- 2026-11-12 (owner: "when you spray the gun looks like it's moving in a
	-- random direction"). The sideways part of the kick used to pick a random
	-- side, and a random twist, on every shot. It now follows the spray: the
	-- gun turns and rolls toward the side the camera recoil is pulling
	-- (PUNCH_LEAN of the gun's yaw / roll), with only PUNCH_JITTER of
	-- randomness on top. Taps and the first shots, where the camera recoil is
	-- straight up, kick straight up and back.
	PUNCH_LEAN = 0.85,
	PUNCH_ROLL_LEAN = 0.6,
	PUNCH_JITTER = 0.15,
	-- 2026-11-13 (lane B, measured): in a long spray every shot kicked the
	-- same 0.07 studs and 2.4 degrees, a steady buzz with no first shot and
	-- no texture. Now the first shot of a burst slams harder (SPRAY_FIRST,
	-- easing to 1 over SPRAY_FIRST_SHOTS shots), each shot's back and rise
	-- vary by up to SHOT_VARY either way, and a pause longer than
	-- SPRAY_GAP seconds starts a new burst.
	SPRAY_FIRST = 1.4,
	SPRAY_FIRST_SHOTS = 3,
	SHOT_VARY = 0.18,
	SPRAY_GAP = 0.3,

	-- Handling bounce (2026-11-11, owner: "reload and all those animations are
	-- not aggressive enough and fun enough... bouncing"). Each gun has one
	-- underdamped spring (about 3 Hz, overshoots and wobbles once or twice)
	-- that the handling beats kick: the mag ripped out, the new one slapped
	-- in, the rack, each shell, the action opening and closing, and the draw.
	-- The clips still place the gun; this is the snap and the bounce on top.
	-- Peaks: drop = studs the gun jumps DOWN (negative = up), pitch = degrees
	-- muzzle up, roll = degrees (positive = top toward the centre).
	HANDLE_STIFFNESS = 380,
	HANDLE_DAMPING = 13,
	HANDLE_ADS = 0.3, -- share kept while aimed
	HANDLE_BUMPS = table.freeze({
		MagOut = { drop = 0.03, pitch = 3, roll = -4.5 },
		MagIn = { drop = -0.055, pitch = -4, roll = 3.5 },
		Rack = { drop = 0.025, pitch = 3.5, roll = 6 },
		Open = { drop = 0.03, pitch = -3.5, roll = -4 },
		Eject = { drop = -0.01, pitch = 2.5, roll = 2.5 },
		-- 2026-11-13 (lane B, measured): the shell-by-shell loops (Bucky,
		-- Marshal) held one pose ~0.9 s with only this to show each shell;
		-- each push now jolts the gun (was drop -0.02, pitch -2, roll 1.5).
		ShellIn = { drop = -0.04, pitch = -4.5, roll = 3 },
		Close = { drop = -0.03, pitch = 4, roll = 3.5 },
		-- 2026-11-13: fires as the gun arrives (DRAW_BUMP_AT), not at the
		-- start where it was still off screen; the track overshoots too.
		Draw = { drop = 0.05, pitch = -4, roll = 4 },
		Inspect = { drop = 0.02, pitch = 2, roll = -3 },
		-- The end of a shell-by-shell reload: the gun lands back in the hold
		-- with a bounce (SHELL_END_SETTLE_AT through ReloadEnd).
		Settle = { drop = 0.04, pitch = -4, roll = 3 },
	} :: { [string]: { drop: number, pitch: number, roll: number } }),
	-- How much of the Reload / ReloadEmpty track's turn a gun takes (1 when
	-- not listed). 2026-11-13 (lane B, measured): the Sheriff's own clip
	-- already flips the revolver ~50 degrees and snaps it back, so with the
	-- whole track on top it turned ~100 degrees in 0.3 s (19.7 per frame).
	RELOAD_TRACK_TURN = table.freeze({
		Sheriff = 0.3,
	} :: { [string]: number }),
	-- Carried rounds (config `carry`): the fresh round shows, and the hand
	-- takes it, this share of the way into its trip back from the
	-- turnaround (0 = at the turnaround). 2026-11-13: the Outlaw's round turns
	-- around ~1.3 studs up and back from the breech, toward the face, so the
	-- hand that met it there came into the screen; it now picks the round up
	-- three quarters of the way in, by the breech (0.55 still drew the arm
	-- across to the crosshair for the second round).
	CARRY_JOIN = table.freeze({
		Outlaw = 0.75,
	} :: { [string]: number }),
	-- A part rolled the moment the inspect starts (GunAnimator.spin), on top of
	-- the gun's own Inspect clip. 2026-11-14 (owner: "the inspect sound starts
	-- with a roll of the [cylinder]... right away"): the Sheriff's inspect
	-- plays its cylinder_spin recording (1.3-1.4 s) at once, but its clip only
	-- turned the cylinder ~70% of the way through. Two whole turns (lands on a
	-- chamber), slowing to a stop like a palm roll. `axis` is the bone's own.
	INSPECT_SPIN = table.freeze({
		Sheriff = { bone = "Cylinder", degrees = 720, seconds = 1.15, axis = Vector3.xAxis },
	} :: {
		[string]: { bone: string, degrees: number, seconds: number, axis: Vector3 },
	}),
	-- Seconds a screen track (the knife's moves) takes to blend in from where
	-- the last move in its slot was, when it cuts in (Util/ViewmodelTracks).
	TRACK_BLEND = 0.09,
	-- A gun with its own Inspect track (TRACKS; others use "Inspect").
	INSPECT_TRACK = table.freeze({ Sheriff = "InspectSheriff" } :: { [string]: string }),
	-- Which Draw track a gun's class uses (TRACKS; others use "Draw").
	DRAW_TRACK = table.freeze({
		Sidearm = "DrawSidearm",
		SMG = "DrawSMG",
		Rifle = "DrawLong",
		MachineGun = "DrawLong",
		Shotgun = "DrawLong",
		Sniper = "DrawLong",
	} :: { [string]: string }),
	DRAW_BUMP_AT = 0.2,
	SHELL_END_SETTLE_AT = 0.75, -- 0..1 through ReloadEnd: the gun is back in the hold -- 0..1 through the draw: the gun lands in the hands (the Draw track's arrival)

	-- Held Mods (ModController): the gun drops out of view (camera space,
	-- around the root) while the Mod's item comes up in the right hand.
	LOWER = { pos = Vector3.new(0.3, -1.5, 0.6), rot = Vector3.new(-45, 15, 25) } :: Pose,
	LOWER_FREQUENCY = 14, -- rad/s, critically damped
	ITEM_OFFSET = Vector3.new(0.5, -0.62, -2), -- the item's grip, camera space
	ITEM_ROTATION = Vector3.new(8, -12, 0), -- degrees
	ITEM_FROM = Vector3.new(0.4, -1.3, 0.4), -- it rises from this far below
	ITEM_ARM = Vector3.new(0.22, -0.8, 0.6), -- right arm direction from the grip
	-- The fist sits this far back along the forearm from the grip, so a held
	-- item rests on the block's end (RIVALS seats its utilities on the end
	-- face; ours sat ~45% sunk into it: measured in play 2026-11-21).
	ITEM_SEAT = 0, -- per hold (`seat`), measured with rays from the end face
	-- The item comes up on an underdamped spring: a little overshoot, then it settles.
	ITEM_RAISE_FREQUENCY = 13, -- rad/s
	ITEM_RAISE_DAMPING = 0.55, -- ratio (1 = no overshoot)
	-- Share of the gun's lowering (0..1) over which the item's hand moves from
	-- the gun onto the item (and back): it switched in one frame (2026-11-21).
	ITEM_HAND_BLEND = 0.35,
	-- A throw called off in its wind-up (a cancel before the release): the
	-- hand eases from where it was back to the hold over this many seconds.
	ITEM_ACTION_CANCEL = 0.18,
	-- The free (left) hand up and empty beside a held item, mirroring the item
	-- hand (RIVALS frames a held utility between both arms: 2026-11-21, owner:
	-- match RIVALS' numbers). Root space: the fist, the arm's direction from it,
	-- a small breathing sway (studs), and the seconds to come up / drop away (it
	-- drops for a use, a gesture or a held pose).
	ITEM_READY_HAND = {
		offset = Vector3.new(-0.38, -0.78, -2),
		direction = Vector3.new(-0.68, -0.75, 0.4),
		sway = Vector3.new(0.012, 0.018, 0),
		rise = 0.25,
		drop = 0.14,
		-- Through a throw's coil it sinks low left (RIVALS keeps it in frame
		-- until the release), then drops at the release.
		actionShift = Vector3.new(-0.12, -0.32, 0.18),
		actionIn = 0.12,
	},
	-- Held idle: a slow breathing drift on top of the hold (position studs,
	-- rotation degrees, cycles per second).
	-- 2026-11-21: rot (1.5, 1.8, 1) -> (2, 3, 2.6): it turned as slowly as 2.5 deg/s
	-- and sat under 4 deg/s for up to 0.375 s (a frozen hold by the feel
	-- checklist); now 4.9-7 deg/s (the yaw and roll run in quadrature).
	ITEM_IDLE = { pos = Vector3.new(0.012, 0.018, 0), rot = Vector3.new(2, 3, 2.6), rate = 0.55 },
	-- Per-Mod holds (by the item model's name). Molly and Frost: lifted out of
	-- the fist (about two thirds of the canister shows) and turned so the pin
	-- side faces the free hand, right of the aim area. HealOrb: palm up, the
	-- forearm running in under it.
	ITEM_HOLDS = table.freeze({
		-- 2026-11-21 (round 2, blind review of hold frames): `lift` lowered ~0.08 on
		-- the thrown items, the orb and the Roller, so each sits just down in the fist
		-- end instead of perched on top of it (0.16 hid half the canister
		-- behind the forearm).
		-- 2026-11-21 (round 3, owner: match RIVALS' numbers): RIVALS stands a held
		-- utility ON the block's end, the forearm leaning in from the bottom right
		-- (Rivals Reference → Abilities and utilities). Canisters: the forearm
		-- leans in (`arm`), the canister turned to within 16° of the forearm's
		-- axis (it was 30° off, its underside to the camera) and seated on the end
		-- face (`seat`; rays from the end face: touching, median gap 0.03).
		Molly = {
			scale = 1.3, -- at 1 the canister read small, perched on the forearm's end (2026-11-16)
			offset = Vector3.new(0.56, -0.72, -2),
			rotation = Vector3.new(-6, -22, 16),
			arm = Vector3.new(0.5, -0.85, 0.25),
			lift = Vector3.new(0, 0.05, 0),
			seat = 0.09,
		},
		Frost = {
			scale = 1.5, -- round 3 (weight): overhangs the block's end like RIVALS' 1.5x grenade (1.3 was no wider than it)
			offset = Vector3.new(0.56, -0.82, -2.05),
			rotation = Vector3.new(-8, -20, 16),
			arm = Vector3.new(0.5, -0.85, 0.25),
			lift = Vector3.new(0, 0.09, 0),
			seat = 0.22, -- at scale 1.5 (rays: median gap ~0.02)
		},
		-- The anchor read tiny on the fist (2026-11-16): scale 1.3, default offset.
		-- Round 3: stood on the fist end like the canisters (it was 40° off the
		-- forearm and half behind its end).
		Recall = {
			scale = 1.3,
			rotation = Vector3.new(-8, -12, 16),
			arm = Vector3.new(0.5, -0.85, 0.25),
			seat = 0.07,
		},
		HealOrb = {
			offset = Vector3.new(0.48, -0.72, -1.85),
			rotation = Vector3.new(0, -10, 0),
			-- Round 3: the forearm upright like the canisters, the orb standing on
			-- its end (palm-up, it sat half behind the block's top edge).
			arm = Vector3.new(0.5, -0.85, 0.25),
			-- The orb sits down in the fist (it floated above it). Round 3: -0.08 -> -0.16,
			-- its glowing core onto the block's end (blind reviews: it hovered).
			lift = Vector3.new(0, -0.16, 0),
		},
		-- Recon bow (rebuilt 2026-11-16, owner: "should look like a good two
		-- hand first person draw back"): a right-handed archer. The bow in the
		-- LEFT hand left of centre, upright with the top canted 12° right, the
		-- bolt running straight down the view at the crosshair; the right hand
		-- on the string from the raise and drawing it straight back toward the
		-- cheek (BOW.hand*). Was: right hand, turned 58° across the view, so
		-- the bolt pointed sideways and the draw read as a short side tug.
		Recon = {
			-- Rebuilt 2026-11-17 to the owner's Valorant reference (Sova's
			-- bow): big and canted, on the RIGHT of the screen. The bow fist
			-- low in the middle (its forearm out of the bottom), the top limb
			-- reaching for the top-right corner, the bolt running in from the
			-- lower right with its head just below the crosshair. Drawn, the
			-- string pulls down-right toward the bottom-right corner. The
			-- owner's first note that day ("the bow's at an angle and it's not
			-- actually being drawn back") was about the old small hold up the
			-- middle; their reference is canted. Tuned live with the Studio
			-- TuneHold* attributes (Util/ViewmodelHeldMods).
			scale = 2.9,
			offset = Vector3.new(0.45, -1.15, -2.75),
			rotation = Vector3.new(6, 22, -40),
			arm = Vector3.new(-0.15, -0.9, 0.4), -- the bow forearm straight down out of frame
			lift = Vector3.zero,
			side = "Left",
			seat = 0, -- the bow fist grips the riser
			from = Vector3.new(0.2, -1.4, 0.3),
		},
		-- Shock Dart (free pack): Recon's bow with its own bolt head, held
		-- and drawn the same way (BOW drives any held bow rig).
		ShockDart = {
			scale = 2.9,
			offset = Vector3.new(0.45, -1.15, -2.75),
			rotation = Vector3.new(6, 22, -40),
			arm = Vector3.new(-0.15, -0.9, 0.4),
			lift = Vector3.zero,
			side = "Left",
			seat = 0, -- the bow fist grips the riser
			from = Vector3.new(0.2, -1.4, 0.3),
		},
		-- Flash: a canister like Frost's, pin side to the free hand.
		Flash = {
			scale = 1.5, -- round 3 (weight): overhangs the block end (1.3 read as a light can on a post)
			offset = Vector3.new(0.56, -0.78, -2.02),
			rotation = Vector3.new(-8, -20, 16),
			arm = Vector3.new(0.5, -0.85, 0.25),
			lift = Vector3.new(0, 0.07, 0),
			seat = 0.23, -- at scale 1.5 (rays: median gap ~0.02)
		},
		-- Roller: the bot on the palm, nose forward (its placed model held small).
		Roller = {
			-- 1.4 until 2026-11-21 (it filled the centre-right of the view), then 1.2;
			-- round 3: 0.95, toward RIVALS' "item about 1.5x the block" (at 1.2 it was
			-- ~3x the block, read weightless on one fist and crowded the crosshair).
			scale = 0.95,
			-- 2026-11-21 (frame in play): at (0.5, -0.7, -2) the car's top-left
			-- wheel sat on the crosshair; lower and further right, clear of it.
			offset = Vector3.new(0.62, -0.9, -2.05),
			rotation = Vector3.new(6, -14, 0),
			arm = Vector3.new(0.3, -0.42, 0.85),
			lift = Vector3.new(0, 0.05, 0),
		},
	} :: { [string]: ItemHold }),
	-- A drawn bow (Util/ViewmodelHeldMods bow rig: any held item with the
	-- attachments LimbTopPivot, LimbBottomPivot, TipTop, TipBottom, Nock and
	-- NockDrawn and the parts StringTop / StringBottom; Recon). Driven by the
	-- charge (ModController.stepCharge → setItemCharge) and released by
	-- releaseItem. Seconds, studs (camera space unless said), degrees.
	BOW = table.freeze({
		limbs = { Top = { "LimbTop", "TipCapTop" }, Bottom = { "LimbBottom", "TipCapBottom" } },
		bolt = "Dart", -- the nocked bolt: parts Dart / Dart_*, slide with the nock
		chargePart = "Charge_Energy",
		flex = 16, -- each limb at full draw, toward the string (26 opened gaps at the pockets)
		-- Draw from the charge: 1 - (1 - charge)^drawEase (fast, easing into full).
		drawEase = 2.6,
		-- The nock's travel at full draw, as a share of the model's Nock →
		-- NockDrawn (more than 1 pulls the string further than modelled).
		stringThick = 0.55, -- the strings' thickness, as a share of the model's
		drawStretch = 0.72, -- at 2.9 scale: the bolt head stays in front of the riser at full draw
		nockTime = 0.14, -- the drawing hand coming up to the string (the string waits for it)
		-- The bow pushes out a little as it's drawn (the bow arm extends).
		drawPush = { pos = Vector3.new(-0.02, 0.015, -0.06), rot = Vector3.new(-2, 2, 1) },
		-- Held at full draw: a small tremble (from `from` charge up).
		tremble = { from = 0.9, nock = 0.006, rot = 0.35, rate = 11 },
		-- Release: the string snaps to rest (an accelerating `snap`), rings past
		-- it (`overshoot` of the draw, `ring` Hz, dying over `decay` s), the
		-- limbs with it. A tap is the same, scaled by its draw.
		-- 2026-11-21: overshoot 0.2 -> 0.36 and ring 15 -> 16 Hz, so the ring
		-- starts at the snap's speed (overshoot * 2 pi * ring = 2 / snap, 36
		-- draws a second): the string's speed halved in one frame at rest.
		release = { snap = 0.055, overshoot = 0.36, ring = 16, decay = 0.05 },
		-- The bow hand's kick at release (scaled by the draw, at least `tap`):
		-- out in `out` s, then a damped settle (one small overshoot).
		kick = {
			pos = Vector3.new(0.01, 0.04, 0.1),
			rot = Vector3.new(6, -1, -2),
			out = 0.045,
			ring = 7,
			decay = 0.09,
			tap = 0.3,
		},
		-- The drawing hand: the fist from the nock (bow space), the arm's
		-- direction from the fist, and where it comes up from.
		hand = Vector3.new(0.06, -0.07, 0.07),
		handDir = Vector3.new(0.45, -0.75, 0.5), -- the drawing forearm down and out of the bottom-right corner
		handFrom = Vector3.new(0.75, -1.5, -0.5), -- where the drawing hand comes up from / drops to (lower right)
		-- After the release it follows through (back and out, root space), holds,
		-- then drops away.
		-- (`creep`: the hand keeps drifting this share further through the hold;
		-- 2026-11-21, it froze for the 80 ms hold.)
		follow = {
			offset = Vector3.new(0.14, 0.05, 0.3),
			out = 0.07,
			hold = 0.08,
			back = 0.24,
			creep = 0.15,
		},
		letDown = 0.16, -- a cancelled draw easing back to rest
		-- Charge_Energy: transparency from `dim` to 0 with the charge, its
		-- colour from `dimColour` toward its own; a flash at full.
		charge = { dim = 0.85, dimColour = 0.55, flash = 0.18 },
		-- The bolt head's charge glow (light brightness and spark rate at
		-- full draw, both rising with the charge; the colour is the bolt
		-- light's: team colour).
		glow = {
			part = "Dart_Head",
			colourFrom = "Dart_Light_Energy",
			brightness = 2.5,
			range = 5,
			rate = 40,
			spark = 0.12,
		},
	}),
	-- Moving parts on equip (ModController.startHold → itemParts(def.id)),
	-- seconds from the equip, in step with MOLLY_PIN_AT / MOLLY_PIN_GONE
	-- (Config/Mods) and the PinPull gestures: the thumb presses the pad
	-- (0.04), the free hand hooks the ring (0.30) and yanks the pin (0.33),
	-- the latch springs open (0.37, Back Out) and the pad springs up.
	ITEM_PART_MOVES = table.freeze({
		Molly = {
			{
				part = "ArmPad",
				to = "ArmPadDown",
				anchor = Vector3.new(0, 1, 0),
				at = 0.04,
				time = 0.06,
				hold = 0.27,
				back = 0.08,
			},
			{
				part = "Pin",
				to = "PinOut",
				anchor = Vector3.new(0, 0, 0.35),
				at = 0.33,
				time = 0.06,
				style = Enum.EasingStyle.Quint,
			},
			{
				part = "Latch",
				pivot = "LatchPivot",
				angle = Vector3.new(45, 0, 0),
				at = 0.37,
				time = 0.16,
				style = Enum.EasingStyle.Back,
			},
		},
		Frost = {
			{
				part = "Pin",
				to = "PinOut",
				anchor = Vector3.new(0, 0, 0.35),
				at = 0.33,
				time = 0.06,
				style = Enum.EasingStyle.Quint,
			},
			{
				part = "Latch",
				pivot = "LatchPivot",
				angle = Vector3.new(45, 0, 0),
				at = 0.37,
				time = 0.16,
				style = Enum.EasingStyle.Back,
			},
		},
	} :: { [string]: { PartMove } }),
	-- Uses, keyframed on top of the hold (camera space, smoothstep between
	-- keys; `t` 0..1 over `length` seconds). Throw: wind back and up, release
	-- forward (the item leaves the hand at `hideAt`), follow through down.
	-- Place: push down and out. Heal: a thrust toward the target and back.
	ITEM_ACTIONS = {
		-- 2026-11-16 re-key (spline): a small dip (coil), the wind back by the
		-- ear braking into a held peak, a ~60 ms snap to the release (0.21 s,
		-- where the old key let go), an overshoot past it, then down.
		-- 2026-11-21 (round 3, to RIVALS' throw, studied from play footage: Rivals
		-- Reference → Abilities and utilities): a far bigger coil, the canister
		-- swung up and back beside the head in ~0.13 s (it was a 0.3-stud lift
		-- that read as part of the hold), braking there; a ~80 ms snap to the
		-- release at 0.25 s (hideAt; ModController sends the throw then); the
		-- arm thrown out at the crosshair (0.33-0.42 s), then out of view.
		Throw = {
			length = 0.6,
			hideAt = 0.42,
			smooth = true,
			keys = {
				{ t = 0, pos = Vector3.zero, rot = Vector3.zero },
				-- Fix round 1 (3 blind reviews, 8.0): the dip deeper (it read as nothing),
				-- the canister upright on the forearm's end at the coil (tipped back 55°
				-- it hung off the side of a forearm that filled the screen's edge), a
				-- little further out; through the snap it trails the arm, then whips
				-- ~65° forward into the release (overlap).
				{ t = 0.07, pos = Vector3.new(0.03, -0.1, 0.06), rot = Vector3.new(8, 0, 3) },
				{
					t = 0.22,
					pos = Vector3.new(0.36, 0.95, 0.95),
					rot = Vector3.new(-22, 18, 22),
					arm = Vector3.new(0.05, -0.15, 0.25),
				},
				-- Fix round 2 (weight): at the brake the canister sags and tips back a
				-- little under its own mass before the snap.
				{
					t = 0.28,
					pos = Vector3.new(0.39, 0.96, 1.02),
					rot = Vector3.new(-30, 19, 24),
					arm = Vector3.new(0.05, -0.15, 0.25),
				},
				{
					t = 0.36,
					pos = Vector3.new(0.15, 0.74, 0),
					rot = Vector3.new(-28, 12, 18),
					arm = Vector3.new(0, 0.1, 0.3),
				},
				-- Fix round 3: at the release the canister rides the end of the thrusting
				-- forearm (14° off it; at +35° it tipped back off the end's edge).
				{
					t = 0.42,
					pos = Vector3.new(-0.08, 0.42, -0.9),
					rot = Vector3.new(-14, -6, 12),
					arm = Vector3.new(-0.1, 0.3, 0.3),
				},
				{
					t = 0.55,
					pos = Vector3.new(-0.45, 0.7, -1.05),
					rot = Vector3.new(55, -8, -10),
					arm = Vector3.new(-0.2, 0.4, 0.3),
				},
				{
					t = 0.7,
					pos = Vector3.new(-0.47, 0.66, -1.1),
					rot = Vector3.new(58, -8, -10),
					arm = Vector3.new(-0.2, 0.4, 0.3),
				},
				{ t = 0.85, pos = Vector3.new(-0.2, -0.35, -0.6), rot = Vector3.new(38, 0, -4) },
				{ t = 1, pos = Vector3.new(0, -1, -0.2), rot = Vector3.new(28, 0, 0) },
			},
		},
		-- Javelin (Frost LMB): the arm draws back level with the shoulder,
		-- brakes, and spears it forward flat (a ~55 ms snap), overshooting.
		Javelin = {
			length = 0.4,
			hideAt = 0.5,
			smooth = true,
			keys = {
				{ t = 0, pos = Vector3.zero, rot = Vector3.zero },
				{ t = 0.08, pos = Vector3.new(0.02, -0.04, 0.05), rot = Vector3.new(4, 0, 0) },
				{
					t = 0.3,
					pos = Vector3.new(0.24, 0.12, 0.6),
					rot = Vector3.new(-10, 20, 6),
					arm = Vector3.new(0.05, 0, -0.2),
				},
				{
					t = 0.36,
					pos = Vector3.new(0.25, 0.13, 0.63),
					rot = Vector3.new(-11, 21, 6),
					arm = Vector3.new(0.05, 0, -0.2),
				},
				{
					t = 0.5,
					pos = Vector3.new(-0.06, 0.14, -1.15),
					rot = Vector3.new(8, -8, -4),
					arm = Vector3.new(0, 0.2, 0.35),
				},
				{
					t = 0.6,
					pos = Vector3.new(-0.09, 0.1, -1.25),
					rot = Vector3.new(12, -10, -6),
					arm = Vector3.new(0, 0.25, 0.4),
				},
				{ t = 0.82, pos = Vector3.new(0.03, -0.4, -0.5), rot = Vector3.new(16, 0, 0) },
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
		-- 2026-11-16 re-key: a small lift, the swing down and back braking
		-- low, a ~55 ms scoop to the release (0.25 s, as before), the hand
		-- rising past it, then down.
		Lob = {
			length = 0.46,
			hideAt = 0.54,
			smooth = true,
			keys = {
				{ t = 0, pos = Vector3.zero, rot = Vector3.zero },
				{ t = 0.1, pos = Vector3.new(0, 0.05, 0.04), rot = Vector3.new(-6, 0, 0) },
				{
					t = 0.36,
					pos = Vector3.new(0.08, -0.45, 0.35),
					rot = Vector3.new(36, 4, 6),
					arm = Vector3.new(0, 0.1, -0.15),
				},
				{
					t = 0.42,
					pos = Vector3.new(0.08, -0.47, 0.37),
					rot = Vector3.new(38, 4, 6),
					arm = Vector3.new(0, 0.1, -0.15),
				},
				{
					t = 0.54,
					pos = Vector3.new(0, -0.02, -0.8),
					rot = Vector3.new(-40, -2, 0),
					arm = Vector3.new(0, 0.15, 0.3),
				},
				{
					t = 0.66,
					pos = Vector3.new(-0.02, 0.12, -0.9),
					rot = Vector3.new(-52, -3, -2),
					arm = Vector3.new(0, 0.2, 0.35),
				},
				{ t = 0.85, pos = Vector3.new(0.02, -0.35, -0.5), rot = Vector3.new(-20, 0, 0) },
				{ t = 1, pos = Vector3.new(0.02, -0.5, -0.35), rot = Vector3.new(-12, 0, 0) },
			},
		},
		Place = {
			length = 0.32,
			-- The item leaves the hand at the bottom of the set-down (2026-11-21,
			-- frame in play: the placed Roller was already out in the world while
			-- the held one was still in the hand, so there were two).
			hideAt = 0.42,
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
	-- 2026-11-16: down early with the hand (0.11 s), back up crisply on the
	-- arrival with a small overshoot (keyed at 0.94).
	RECALL_DIP = {
		length = 0.6,
		smooth = true,
		keys = {
			{ t = 0, pos = Vector3.zero, rot = Vector3.zero },
			{ t = 0.18, pos = Vector3.new(0.06, -0.22, 0.1), rot = Vector3.new(-8, 6, 10) },
			{ t = 0.84, pos = Vector3.new(0.06, -0.26, 0.12), rot = Vector3.new(-9, 6, 12) },
			{ t = 0.94, pos = Vector3.new(0, 0.025, -0.02), rot = Vector3.new(2, 0, -1) },
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
		-- 2026-11-16 re-key, in step with ITEM_PART_MOVES (it starts at
		-- MOLLY_PIN_AT 0.12 s): up to the ring (0.26 s), hooked and braced
		-- (0.30-0.33 s), a ~60 ms yank as the pin slides out, an overshoot
		-- away, then down. The pin hides at MOLLY_PIN_GONE.
		MollyPinPull = {
			length = 0.45,
			smooth = true,
			keys = {
				{ t = 0, pos = Vector3.new(-0.55, -1.6, -0.8), dir = Vector3.new(-0.3, -0.8, 0.5) },
				{
					t = 0.3,
					pos = Vector3.new(0.3, -0.36, -1.82),
					dir = Vector3.new(-0.65, -0.35, 0.68),
				},
				{
					t = 0.4,
					pos = Vector3.new(0.36, -0.31, -1.86),
					dir = Vector3.new(-0.65, -0.35, 0.68),
				},
				{
					t = 0.47,
					pos = Vector3.new(0.37, -0.3, -1.86),
					dir = Vector3.new(-0.62, -0.38, 0.68),
				},
				{
					t = 0.6,
					pos = Vector3.new(0.18, -0.27, -1.82),
					dir = Vector3.new(-0.55, -0.45, 0.7),
				},
				{
					t = 0.68,
					pos = Vector3.new(0.1, -0.23, -1.76),
					dir = Vector3.new(-0.5, -0.5, 0.7),
				},
				{ t = 1, pos = Vector3.new(-0.55, -1.6, -0.8), dir = Vector3.new(-0.3, -0.8, 0.5) },
			},
		},
		-- Frost: the same pull on its taller canister (the ring sits higher).
		FrostPinPull = {
			length = 0.45,
			smooth = true,
			keys = {
				{ t = 0, pos = Vector3.new(-0.55, -1.6, -0.8), dir = Vector3.new(-0.3, -0.8, 0.5) },
				{
					t = 0.3,
					pos = Vector3.new(0.3, -0.33, -1.86),
					dir = Vector3.new(-0.65, -0.35, 0.68),
				},
				{
					t = 0.4,
					pos = Vector3.new(0.37, -0.28, -1.9),
					dir = Vector3.new(-0.65, -0.35, 0.68),
				},
				{
					t = 0.47,
					pos = Vector3.new(0.38, -0.27, -1.9),
					dir = Vector3.new(-0.62, -0.38, 0.68),
				},
				{
					t = 0.6,
					pos = Vector3.new(0.16, -0.24, -1.86),
					dir = Vector3.new(-0.55, -0.45, 0.7),
				},
				{
					t = 0.68,
					pos = Vector3.new(0.08, -0.2, -1.8),
					dir = Vector3.new(-0.5, -0.5, 0.7),
				},
				{ t = 1, pos = Vector3.new(-0.55, -1.6, -0.8), dir = Vector3.new(-0.3, -0.8, 0.5) },
			},
		},
		-- Stim (Brimstone-style): the hand comes up from the belt with the
		-- beacon, dips back and tosses it underhand a few steps ahead
		-- (it leaves the hand at `release`, the stats' tossRelease), then
		-- follows through and drops away.
		-- 2026-11-16 re-key: up with the beacon (0.12 s), a brake, the coil low
		-- and back (0.24 s), a ~60 ms forward-up scoop to the release (0.30 s,
		-- high and out front so the world beacon's arc reads from it), the
		-- hand rising past it, a settle, then down.
		StimToss = {
			length = 0.55,
			release = 0.55, -- the beacon (ModProps' hand-sized one) leaves the fist
			propTilt = -35,
			smooth = true,
			keys = {
				{
					t = 0,
					pos = Vector3.new(-0.55, -1.6, -0.75),
					dir = Vector3.new(-0.3, -0.8, 0.5),
				},
				{
					t = 0.22,
					pos = Vector3.new(-0.4, -0.85, -1.25),
					dir = Vector3.new(-0.35, -0.5, 0.8),
				},
				{
					t = 0.3,
					pos = Vector3.new(-0.4, -0.9, -1.2),
					dir = Vector3.new(-0.35, -0.45, 0.82),
				},
				{
					t = 0.44,
					pos = Vector3.new(-0.42, -1.15, -0.95),
					dir = Vector3.new(-0.3, -0.2, 0.93),
				},
				{
					t = 0.55,
					pos = Vector3.new(-0.2, -0.5, -1.75),
					dir = Vector3.new(-0.15, -0.5, 0.85),
				},
				{
					t = 0.66,
					pos = Vector3.new(-0.15, -0.32, -1.85),
					dir = Vector3.new(-0.1, -0.65, 0.75),
				},
				{
					t = 0.8,
					pos = Vector3.new(-0.18, -0.42, -1.75),
					dir = Vector3.new(-0.12, -0.62, 0.77),
				},
				{ t = 1, pos = Vector3.new(-0.55, -1.7, -0.8), dir = Vector3.new(-0.3, -0.8, 0.5) },
			},
		},
		-- Recall: the hand comes up in front, twists (a snap of the wrist)
		-- and holds while the teleport charges, then drops away.
		-- 2026-11-16 re-key (over the 0.6 s wind-up): the hand is up fast
		-- (0.11 s), counter-turns to coil (0.17 s), snaps the twist in ~60 ms
		-- with a small overshoot (0.25 s), holds with a slight tension creep,
		-- then a crisp ~80 ms drop as you arrive: the gun is back at 1.
		RecallTwist = {
			length = 0.6,
			smooth = true,
			keys = {
				{
					t = 0,
					pos = Vector3.new(-0.55, -1.6, -0.75),
					dir = Vector3.new(-0.3, -0.8, 0.5),
				},
				{
					t = 0.18,
					pos = Vector3.new(-0.3, -0.52, -1.32),
					dir = Vector3.new(-0.45, -0.6, 0.65),
				},
				{
					t = 0.28,
					pos = Vector3.new(-0.31, -0.54, -1.3),
					dir = Vector3.new(-0.58, -0.55, 0.6),
				},
				{
					t = 0.38,
					pos = Vector3.new(-0.2, -0.48, -1.38),
					dir = Vector3.new(0.18, -0.7, 0.7),
				},
				{
					t = 0.44,
					pos = Vector3.new(-0.22, -0.5, -1.36),
					dir = Vector3.new(0.1, -0.7, 0.7),
				},
				{
					t = 0.86,
					pos = Vector3.new(-0.22, -0.53, -1.33),
					dir = Vector3.new(0.13, -0.72, 0.68),
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
	-- 2026-11-16: Ready a touch higher and tighter to the body (the flame
	-- held up), Guide further out with the palm pushed square at the wall.
	FREE_POSES = {
		FirewallReady = {
			offset = Vector3.new(-0.4, -0.47, -1.32),
			direction = Vector3.new(-0.35, -0.78, 0.52),
		},
		FirewallGuide = {
			offset = Vector3.new(-0.18, -0.4, -1.9),
			direction = Vector3.new(-0.2, -0.4, 0.9),
		},
	} :: { [string]: Hand },
	FREE_POSE_RATE = 16, -- 1/s
	FREE_POSE_FROM = Vector3.new(-0.55, -1.6, -0.8), -- where the hand comes up from
	-- Keyed moves into a pose (HandMove). Ready: up past the pose and
	-- settling onto it. Guide: a short coil back, a ~65 ms push out past the
	-- pose, a brake back onto it.
	FREE_POSE_MOVES = table.freeze({
		FirewallReady = {
			length = 0.3,
			smooth = true,
			keys = {
				{ t = 0, pos = Vector3.new(-0.55, -1.6, -0.8), dir = Vector3.new(-0.3, -0.8, 0.5) },
				{
					t = 0.45,
					pos = Vector3.new(-0.42, -0.42, -1.3),
					dir = Vector3.new(-0.35, -0.8, 0.5),
				},
				{
					t = 0.7,
					pos = Vector3.new(-0.4, -0.49, -1.33),
					dir = Vector3.new(-0.35, -0.77, 0.52),
				},
				{
					t = 1,
					pos = Vector3.new(-0.4, -0.47, -1.32),
					dir = Vector3.new(-0.35, -0.78, 0.52),
				},
			},
		},
		FirewallGuide = {
			length = 0.32,
			smooth = true,
			keys = {
				{
					t = 0,
					pos = Vector3.new(-0.4, -0.47, -1.32),
					dir = Vector3.new(-0.35, -0.78, 0.52),
				},
				{
					t = 0.25,
					pos = Vector3.new(-0.46, -0.52, -1.2),
					dir = Vector3.new(-0.4, -0.75, 0.5),
				},
				{
					t = 0.45,
					pos = Vector3.new(-0.15, -0.38, -2),
					dir = Vector3.new(-0.18, -0.36, 0.92),
				},
				{
					t = 0.7,
					pos = Vector3.new(-0.19, -0.41, -1.87),
					dir = Vector3.new(-0.2, -0.41, 0.89),
				},
				{ t = 1, pos = Vector3.new(-0.18, -0.4, -1.9), dir = Vector3.new(-0.2, -0.4, 0.9) },
			},
		},
	} :: { [string]: HandMove }),
	-- Share of a keyed move over which the start bends from where the hand
	-- really was onto the move's first key.
	FREE_POSE_MOVE_BLEND = 0.35,
	-- Seconds a Mod gesture takes to blend out of where the free hand was
	-- (on the gun) into its keys; it jumped there in one frame (2026-11-21).
	GESTURE_FROM_BLEND = 0.07,
	-- A held free-hand pose's idle (studs, degrees of aim, cycles a second;
	-- `fadeIn`: share of the move's length past its end to fade in): an
	-- ellipse, so the hand never stops (2026-11-21; it sat still).
	FREE_POSE_IDLE = {
		pos = Vector3.new(0.03, 0.024, 0.012),
		turn = 3.6,
		rate = 0.45,
		fadeIn = 0.6,
	},
	-- Guiding the wall: the fist trails the view's turn and catches up.
	FREE_POSE_STEER = table.freeze({
		FirewallGuide = { lag = 0.05, max = 0.18, swing = 0.6, rate = 10 },
	} :: { [string]: HandSteer }),
	-- The gesture prop (the Stim beacon) sits this far above the fist (studs).
	GESTURE_PROP_LIFT = 0.08,
	-- The flame in the hand (a small fire on the fist; Util/... MOLLY flipbook).
	HAND_FLAME_SIZE = 0.55,

	-- Pose blends (critically damped, rad/s).
	POSE_FREQUENCY = 13,
	CANCEL_TIME = 0.14, -- seconds to fade out a cancelled track

	-- Poses of the gun around its grip, mirrored for the left gun. Sprint is a
	-- lowered carry: muzzle in toward the centre, rolled onto its side.
	POSES = {
		-- 2026-11-11: running is automatic now (no sprint key), so the carry is
		-- a lighter cant that keeps the gun readable; it was rot (-6, 20, 30).
		Sprint = { pos = Vector3.new(-0.04, -0.06, 0.03), rot = Vector3.new(-4, 13, 17) },
		-- 2026-11-10: canted inward (top toward the centre) and tucked low, the
		-- way shooters carry a gun through a slide; it leaned outward (roll -24).
		Slide = { pos = Vector3.new(-0.1, -0.12, 0.06), rot = Vector3.new(2, 8, 18) },
		-- 2026-11-12: tucked in a little more (was pos (-0.01, -0.02, 0.02), rot (0, 2, -4)).
		Crouch = { pos = Vector3.new(-0.03, -0.035, 0.035), rot = Vector3.new(1.5, 4, -7) },
		Air = { pos = Vector3.new(0, 0.05, 0.03), rot = Vector3.new(7, -2, 5) }, -- 2026-11-11: floatier (was pos (0, 0.03, 0.02), rot (4, 0, 2))
	} :: { [string]: Pose },

	-- Keyframed tracks.
	TRACKS = {
		-- Raise in from below the screen (stretched to the gun's equip time).
		-- 2026-11-13 (lane B): it now arrives past the hold and bounces back
		-- (it eased straight in, then stopped dead).
		Equip = {
			length = 0.35,
			pivot = "Grip",
			keys = {
				key(0, Vector3.new(0.05, -0.8, 0.2), Vector3.new(-60, 25, 20)),
				key(
					0.5,
					Vector3.new(-0.01, 0.03, -0.01),
					Vector3.new(5, -3, -3),
					Enum.EasingStyle.Quad,
					OUT
				),
				key(
					0.78,
					Vector3.new(0.004, -0.012, 0.004),
					Vector3.new(-1.5, 0.8, 1),
					Enum.EasingStyle.Sine,
					INOUT
				),
				key(1, ZERO, ZERO, Enum.EasingStyle.Sine, INOUT),
			},
		},
		-- Every draw (stretched to drawTime), under the gun's Draw clip
		-- (Valorant style): swing up from low right, roll the left side to the
		-- camera while the support hand racks the charging handle all the way
		-- back and holds it, slam it home, settle.
		-- 2026-11-13 (lane B, owner: draws not "aggressive, bouncy or fun
		-- enough"; measured: a 0.3 s dead hold mid-draw and a slow ease into
		-- the hold with no overshoot). Now: a fast swing up that overshoots
		-- the rack pose and settles (the gun lands in the hands, DRAW_BUMP_AT);
		-- the yank on the handle pulls the gun toward the hand; letting go
		-- (marks.Rack, on the clip's rack) snaps the muzzle up; the gun drops
		-- into the hold PAST it, bounces once and settles. RIVALS and
		-- Valorant land their draws the same way (video study in the lane B
		-- note).
		Draw = drawTrack(Vector3.new(0.12, -0.75, 0.25), Vector3.new(-50, 30, 35)),
		-- The same draw, coming in the way each class does in the owner's clips
		-- (2026-11-15; DRAW_TRACK picks one by class):
		--   pistols   up from the bottom right, the muzzle tipped up and to the
		--             left ~45 degrees, turning down into the hold;
		--   SMGs      straight up from under the hold;
		--   long guns swept in from the bottom left, rolled ~60 degrees onto
		--             their side, squaring up as they arrive.
		DrawSidearm = drawTrack(Vector3.new(0.2, -0.62, 0.12), Vector3.new(38, 30, 14)),
		DrawSMG = drawTrack(Vector3.new(0.02, -0.72, 0.1), Vector3.new(-10, 2, 4)),
		DrawLong = drawTrack(Vector3.new(-0.85, -0.7, 0.18), Vector3.new(16, -24, 58)),
		DrawRuinVandal = ruinDraw(
			Vector3.new(0.11, -0.69, 0.23),
			Vector3.new(-20, -8, 16),
			Vector3.new(0.03, -0.15, -0.085)
		),
		DrawRuinGuardian = ruinDraw(
			Vector3.new(-0.25, -0.67, 0.17),
			Vector3.new(-16, 13, -19),
			Vector3.new(-0.09, -0.14, -0.075)
		),
		DrawRuinSpectre = ruinDraw(
			Vector3.new(0.13, -0.57, 0.18),
			Vector3.new(-24, 2, 14),
			Vector3.new(0.03, -0.10, -0.11)
		),
		DrawRuinOperator = ruinDraw(
			Vector3.new(-0.19, -0.74, 0.30),
			Vector3.new(-12, 10, -15),
			Vector3.new(-0.06, -0.19, 0.02)
		),
		DrawRuinGhost = ruinDraw(
			Vector3.new(0.24, -0.53, 0.18),
			Vector3.new(17, -15, 19),
			Vector3.new(0.07, -0.13, -0.09)
		),
		ReloadShadowMist = {
			length = 2.5,
			pivot = "Center",
			smooth = true,
			keys = {
				key(0, ZERO, ZERO),
				key(0.11, Vector3.new(-0.17, 0.19, -0.42), Vector3.new(20, 42, -37)),
				key(0.17, Vector3.new(-0.32, 0.27, -0.58), Vector3.new(28, 54, -47)),
				key(0.34, Vector3.new(-0.42, 0.22, -0.67), Vector3.new(21, 58, -43)),
				key(0.51, Vector3.new(-0.41, 0.24, -0.68), Vector3.new(22, 56, -45)),
				key(0.595, Vector3.new(-0.31, 0.25, -0.51), Vector3.new(19, 42, -37)),
				key(0.63, Vector3.new(-0.25, 0.29, -0.44), Vector3.new(24, 35, -24)),
				key(0.72, Vector3.new(-0.19, 0.15, -0.31), Vector3.new(13, 22, -12)),
				key(0.92, Vector3.new(0.014, -0.015, 0.014), Vector3.new(-2, -3, 3)),
				key(1, ZERO, ZERO),
			},
		},
		ReloadRuinGuardian = ruinReload(Vector3.new(-0.37, 0.22, -0.67), Vector3.new(17, 49, -36)),
		ReloadRuinSpectre = ruinReload(Vector3.new(-0.29, 0.27, -0.54), Vector3.new(24, 35, -31)),
		ReloadRuinOperator = ruinReload(Vector3.new(-0.41, 0.19, -0.74), Vector3.new(12, 43, -26)),
		ReloadRuinGhost = ruinReload(Vector3.new(-0.30, 0.18, -0.47), Vector3.new(31, 44, -38)),
		-- Turn to show the right side, tilt, flip to the left side, return.
		-- (The gun's own clip runs alongside: a mag tap, then a press check on
		-- the charging handle, which the support hand works from the far side.)
		-- 2026-11-13 (lane B; measured: two ~0.9 s holds that only drifted,
		-- and a return that eased in without a settle). Now every move has a
		-- small wind-up the other way, arrives past its pose and settles; each
		-- hold has a look in it (a tilt up to show the top, then back); the
		-- gun comes home past the hold and bounces.
		Inspect = inspectTrack(),
		-- The stock rifle clip reaches across the fore-end. This presentation
		-- keeps both hands on their grips while the receiver cycles.
		InspectSlipframe = {
			length = 2.4,
			pivot = "Center",
			own = true,
			keys = {
				key(0, ZERO, ZERO),
				key(
					0.185,
					Vector3.new(-0.35, 0.15, -0.28),
					Vector3.new(5, 58, -10),
					Enum.EasingStyle.Quad,
					OUT
				),
				key(0.32, Vector3.new(-0.33, 0.14, -0.28), Vector3.new(4, 54, -8)),
				key(0.65, Vector3.new(-0.34, 0.16, -0.27), Vector3.new(7, 56, -10)),
				key(0.84, Vector3.new(-0.29, 0.14, -0.23), Vector3.new(4, 49, -8)),
				key(1, ZERO, ZERO),
			},
		},
		InspectSlipframeCompact = {
			length = 2.2,
			pivot = "Center",
			own = true,
			keys = {
				key(0, ZERO, ZERO),
				key(
					0.19,
					Vector3.new(-0.28, 0.24, -0.34),
					Vector3.new(8, 53, -9),
					Enum.EasingStyle.Quad,
					OUT
				),
				key(0.33, Vector3.new(-0.29, 0.23, -0.34), Vector3.new(6, 51, -8)),
				key(0.66, Vector3.new(-0.29, 0.25, -0.33), Vector3.new(8, 54, -9)),
				key(0.84, Vector3.new(-0.24, 0.20, -0.28), Vector3.new(5, 46, -8)),
				key(1, ZERO, ZERO),
			},
		},
		InspectSlipframeOperator = {
			length = 2.65,
			pivot = "Center",
			own = true,
			keys = {
				key(0, ZERO, ZERO),
				key(
					0.19,
					Vector3.new(-0.42, 0.19, -0.56),
					Vector3.new(3, 50, -10),
					Enum.EasingStyle.Quad,
					OUT
				),
				key(0.34, Vector3.new(-0.41, 0.19, -0.56), Vector3.new(3, 48, -8)),
				key(0.66, Vector3.new(-0.42, 0.21, -0.54), Vector3.new(5, 51, -10)),
				key(0.84, Vector3.new(-0.34, 0.17, -0.45), Vector3.new(4, 44, -8)),
				key(1, ZERO, ZERO),
			},
		},
		InspectRuinGuardian = ruinInspect(
			4.4,
			Vector3.new(-0.42, 0.24, -0.98),
			Vector3.new(12, 59, -17),
			Vector3.new(-0.035, 0.036, -0.11),
			Vector3.new(9, 10, -5)
		),
		InspectRuinSpectre = ruinInspect(
			3.65,
			Vector3.new(-0.31, 0.22, -0.74),
			Vector3.new(13, 57, -23),
			Vector3.new(-0.038, 0.035, -0.065),
			Vector3.new(7, 8, -5)
		),
		InspectRuinOperator = ruinInspect(
			4.85,
			Vector3.new(-0.48, 0.18, -0.89),
			Vector3.new(5, 55, -13),
			Vector3.new(-0.09, 0.09, -0.11),
			Vector3.new(12, 7, -4)
		),
		InspectRuinGhost = ruinInspect(
			3.3,
			Vector3.new(-0.31, 0.29, -0.49),
			Vector3.new(28, 48, -25),
			Vector3.new(0.01, -0.03, -0.06),
			Vector3.new(-10, 22, 14)
		),
		-- Riftforge Legendary line (Prelude-to-Chaos industrial magnetic reactor choreography;
		-- Util/RiftforgeEffects drives the armor cowls, suppressor vents, levitating core
		-- crystal, dual gimbal rings, plasma beams and barrel shockwave on the same beats).
		DrawRiftforge = {
			length = 1.0,
			pivot = "Grip",
			smooth = true,
			keys = {
				key(0, Vector3.new(0.14, -0.68, 0.24), Vector3.new(-30, 14, 58)),
				key(0.16, Vector3.new(0.02, -0.18, -0.06), Vector3.new(-8, 6, 22)),
				-- brief left cant flashing the open reactor bay as the cowls snap shut
				key(0.32, Vector3.new(-0.07, 0.085, -0.11), Vector3.new(10, 8, -18)),
				key(0.45, Vector3.new(-0.03, 0.04, -0.05), Vector3.new(7, 3, -6)), -- cowl SLAM jolt
				key(0.58, Vector3.new(0.012, -0.018, 0.012), Vector3.new(-2.8, -1, 3.5)),
				key(0.76, Vector3.new(0, 0.009, -0.006), Vector3.new(1.1, 0, -0.8)),
				key(1, ZERO, ZERO),
			},
		},
		-- Tactical reload: no charging handle or bolt rack — tilt to vent the spent
		-- energy cell, draw plasma into the magwell, slam the fresh cell home, and
		-- snap the reactor armor cowls shut with an axial plasma surge kick.
		ReloadRiftforge = {
			length = 1.0,
			pivot = "Center",
			smooth = true,
			marks = { MagOut = 0.16, MagIn = 0.48, Rack = 0.78 },
			keys = {
				key(0, ZERO, ZERO),
				key(0.04, Vector3.new(0.012, -0.02, 0.01), Vector3.new(-2.5, -1.5, 3)),
				key(0.12, Vector3.new(-0.10, 0.17, -0.14), Vector3.new(16, 10, -28)),
				key(0.16, Vector3.new(-0.095, 0.16, -0.14), Vector3.new(14, 9, -26)),
				key(0.19, Vector3.new(-0.085, 0.20, -0.15), Vector3.new(20, 10, -22)), -- MagOut plasma burst
				key(0.28, Vector3.new(-0.10, 0.155, -0.14), Vector3.new(13, 10, -29)),
				key(0.40, Vector3.new(-0.105, 0.145, -0.14), Vector3.new(11, 11, -31)), -- plasma cell forming
				key(0.46, Vector3.new(-0.108, 0.132, -0.135), Vector3.new(9, 11, -32)), -- brace
				key(0.50, Vector3.new(-0.08, 0.225, -0.16), Vector3.new(23, 8, -19)), -- MagIn heavy SLAM!
				key(0.58, Vector3.new(-0.09, 0.17, -0.14), Vector3.new(14, 8, -22)),
				key(0.72, Vector3.new(-0.045, 0.09, -0.08), Vector3.new(8, 4, -10)), -- cowls closing
				key(0.78, Vector3.new(-0.015, 0.12, -0.04), Vector3.new(13, 2, -4)), -- cowl SLAM + barrel surge!
				key(0.86, Vector3.new(0.012, -0.015, 0.014), Vector3.new(-3, -1, 3)),
				key(0.94, Vector3.new(0, 0.008, -0.005), Vector3.new(1, 0, -1)),
				key(1, ZERO, ZERO),
			},
		},
		-- Empty reload: heavier reactor reboot! After MagIn slams home, the rifle
		-- kicks sharply up-back as both armor cowls + suppressor vents slam shut
		-- in a two-stage overdrive surge (no stock bolt rack!).
		ReloadEmptyRiftforge = {
			length = 1.0,
			pivot = "Center",
			smooth = true,
			marks = { MagOut = 0.15, MagIn = 0.45, Rack = 0.76 },
			keys = {
				key(0, ZERO, ZERO),
				key(0.04, Vector3.new(0.014, -0.025, 0.012), Vector3.new(-3, -2, 4)),
				key(0.11, Vector3.new(-0.11, 0.18, -0.15), Vector3.new(18, 11, -30)),
				key(0.15, Vector3.new(-0.105, 0.17, -0.15), Vector3.new(15, 10, -28)),
				key(0.18, Vector3.new(-0.09, 0.215, -0.16), Vector3.new(22, 11, -24)), -- MagOut discharge
				key(0.28, Vector3.new(-0.11, 0.16, -0.15), Vector3.new(13, 11, -31)),
				key(0.41, Vector3.new(-0.115, 0.14, -0.145), Vector3.new(10, 12, -33)), -- brace
				key(0.46, Vector3.new(-0.08, 0.245, -0.17), Vector3.new(25, 8, -18)), -- MagIn heavy SLAM!
				key(0.56, Vector3.new(-0.095, 0.18, -0.15), Vector3.new(16, 9, -24)),
				-- Reactor Overdrive Lock (replaces bolt rack): crisp pullback + snap level
				key(0.68, Vector3.new(-0.055, 0.11, -0.10), Vector3.new(6, 5, -14)),
				key(0.76, Vector3.new(-0.02, 0.155, -0.03), Vector3.new(17, 2, -3)), -- violent cowl SLAM kick!
				key(0.84, Vector3.new(0.018, -0.028, 0.02), Vector3.new(-4.5, -1.5, 4.5)),
				key(0.93, Vector3.new(-0.004, 0.012, -0.008), Vector3.new(1.5, 0, -1.2)),
				key(1, ZERO, ZERO),
			},
		},
		-- Inspect: showcase left Reactor Core Bay (cowls split wide, CoreCrystal
		-- levitates UP spinning inside dual gimbal rings with crackling arcs),
		-- whip muzzle-up into a 360-deg magnetic barrel roll across center, then
		-- display right flank suppressor rails as crystal descends and cowls SLAM shut!
		InspectRiftforge = {
			length = 5.2,
			pivot = "Center",
			own = true,
			smooth = true,
			keys = {
				key(0, ZERO, ZERO),
				key(0.045, Vector3.new(0.02, -0.04, -0.03), Vector3.new(-4, -5, 4)),
				-- Left flank Reactor Core Bay showcase (0.14..0.44)
				key(0.14, Vector3.new(-0.42, 0.26, -0.84), Vector3.new(14, 64, -20)),
				key(0.22, Vector3.new(-0.39, 0.24, -0.82), Vector3.new(10, 58, -15)), -- cowls unlock!
				key(0.32, Vector3.new(-0.41, 0.29, -0.86), Vector3.new(19, 55, -23)), -- crystal levitates!
				key(0.42, Vector3.new(-0.39, 0.27, -0.84), Vector3.new(13, 60, -17)),
				-- Sweeps muzzle-up for the magnetic 360 barrel roll
				key(0.53, Vector3.new(-0.33, 0.38, -0.86), Vector3.new(46, 5, -4)),
				-- Catch cleanly on right flank (0.63..0.87)
				key(0.64, Vector3.new(-0.42, 0.21, -0.72), Vector3.new(-8, -58, 22)),
				key(0.72, Vector3.new(-0.39, 0.19, -0.68), Vector3.new(-3, -50, 16)),
				key(0.81, Vector3.new(-0.38, 0.23, -0.68), Vector3.new(9, -46, 11)), -- crystal seats + cowl SLAM!
				key(0.88, Vector3.new(-0.40, 0.20, -0.69), Vector3.new(2, -52, 17)),
				key(0.95, Vector3.new(0.02, -0.03, 0.02), Vector3.new(-3.5, 4, -3)),
				key(1, ZERO, ZERO),
			},
			toss = {
				key(0, ZERO, ZERO),
				key(0.45, ZERO, ZERO),
				key(0.485, Vector3.new(0, 0.055, 0), Vector3.new(0, 0, -85)),
				key(0.53, Vector3.new(0, 0.09, 0), Vector3.new(0, 0, -220)),
				key(0.575, Vector3.new(0, 0.05, 0), Vector3.new(0, 0, -338)),
				key(0.60, Vector3.new(0, -0.006, 0), Vector3.new(0, 0, -364)),
				key(0.63, ZERO, Vector3.new(0, 0, -360)),
				key(1, ZERO, Vector3.new(0, 0, -360)),
			},
			tossPivot = Vector3.new(0, 0.22, -0.78),
		},
		-- Tempest-Strike Vandal (2026-11-22, our own design; Util/TempestIdle draws
		-- the water on the same beats). Inspect: snap to the right side, tip the
		-- top up, bring it to the middle where it lifts out of the hands and rolls
		-- once inside a water ring (the toss), whip to the left side, home past
		-- the hold. Every move winds up, overshoots and settles.
		InspectTempest = tempestInspect(Vector3.new(0, 0.24, -0.96)),
		-- the same roll about each gun's own middle (TempestProfiles roll x, z)
		InspectTempestStinger = tempestInspect(Vector3.new(0, 0.28, -0.3)),
		InspectTempestMarshal = tempestInspect(Vector3.new(0, 0.15, -1.0)),
		InspectTempestBucky = tempestInspect(Vector3.new(0, 0.25, -1.0)),
		-- Draw: rolls in from below on its side and snaps level past the hold
		-- (the water ring runs down the barrel meanwhile).
		DrawTempest = {
			length = 1,
			pivot = "Grip",
			smooth = true,
			keys = {
				key(0, Vector3.new(0.1, -0.72, 0.22), Vector3.new(-34, 12, 74)),
				key(0.18, Vector3.new(0.03, -0.22, -0.08), Vector3.new(-11, 5, 30)),
				key(0.34, Vector3.new(-0.02, 0.045, -0.045), Vector3.new(6, 0, -9)),
				key(0.46, Vector3.new(0.008, -0.012, 0.004), Vector3.new(-2.2, 0, 3)),
				key(0.6, Vector3.new(0, 0.014, -0.01), Vector3.new(1.6, 0, -1.1)),
				key(0.78, Vector3.new(0, -0.004, 0.003), Vector3.new(-0.5, 0, 0.4)),
				key(1, ZERO, ZERO),
			},
		},
		-- Reload: tilt up and roll the magwell toward you (the mag bursts into
		-- water), a slow drift while the water gathers, a hard slap up on the
		-- seat, the rack kick, home past the hold.
		ReloadTempest = {
			length = 1,
			pivot = "Center",
			smooth = true,
			marks = { MagOut = 0.17, MagIn = 0.42, Rack = 0.86 },
			keys = {
				key(0, ZERO, ZERO),
				key(0.04, Vector3.new(0.012, -0.022, 0.01), Vector3.new(-3, -2, 4)),
				key(0.12, Vector3.new(-0.15, 0.26, -0.2), Vector3.new(22, 18, -42)),
				key(0.165, Vector3.new(-0.14, 0.245, -0.2), Vector3.new(18, 16, -38)),
				key(0.19, Vector3.new(-0.13, 0.285, -0.21), Vector3.new(26, 17, -35)),
				key(0.26, Vector3.new(-0.14, 0.235, -0.2), Vector3.new(17, 16, -41)),
				key(0.36, Vector3.new(-0.145, 0.225, -0.2), Vector3.new(15, 19, -44)),
				key(0.4, Vector3.new(-0.15, 0.212, -0.2), Vector3.new(13, 19, -46)),
				key(0.44, Vector3.new(-0.12, 0.3, -0.21), Vector3.new(27, 15, -30)),
				key(0.52, Vector3.new(-0.125, 0.25, -0.2), Vector3.new(18, 14, -34)),
				key(0.66, Vector3.new(-0.09, 0.18, -0.16), Vector3.new(12, 10, -24)),
				key(0.86, Vector3.new(-0.03, 0.08, -0.06), Vector3.new(9, 4, -8)),
				key(0.94, Vector3.new(0.015, -0.02, 0.015), Vector3.new(-3, -2, 3)),
				key(1, ZERO, ZERO),
			},
			-- the spin: once the water magazine seats (Vandal clip ~0.454) the gun
			-- rolls once about the bore and drops back into the hands. Toss keys run on
			-- the clip's own time (alignTrack warps only `keys`).
			toss = {
				key(0, ZERO, ZERO),
				key(0.5, ZERO, ZERO),
				key(0.53, Vector3.new(0, 0.05, 0), Vector3.new(0, 0, -70)),
				key(0.58, Vector3.new(0, 0.085, 0), Vector3.new(0, 0, -205)),
				key(0.63, Vector3.new(0, 0.05, 0), Vector3.new(0, 0, -335)),
				key(0.655, Vector3.new(0, -0.005, 0), Vector3.new(0, 0, -363)),
				key(0.68, ZERO, Vector3.new(0, 0, -360)),
				key(1, ZERO, Vector3.new(0, 0, -360)),
			},
			tossPivot = Vector3.new(0, 0.24, -0.96),
		},
		-- The same reload without the spin (Stinger: its clip seats at another time).
		ReloadTempestLite = {
			length = 1,
			pivot = "Center",
			smooth = true,
			marks = { MagOut = 0.17, MagIn = 0.42, Rack = 0.86 },
			keys = {
				key(0, ZERO, ZERO),
				key(0.04, Vector3.new(0.012, -0.022, 0.01), Vector3.new(-3, -2, 4)),
				key(0.12, Vector3.new(-0.15, 0.26, -0.2), Vector3.new(22, 18, -42)),
				key(0.165, Vector3.new(-0.14, 0.245, -0.2), Vector3.new(18, 16, -38)),
				key(0.19, Vector3.new(-0.13, 0.285, -0.21), Vector3.new(26, 17, -35)),
				key(0.26, Vector3.new(-0.14, 0.235, -0.2), Vector3.new(17, 16, -41)),
				key(0.36, Vector3.new(-0.145, 0.225, -0.2), Vector3.new(15, 19, -44)),
				key(0.4, Vector3.new(-0.15, 0.212, -0.2), Vector3.new(13, 19, -46)),
				key(0.44, Vector3.new(-0.12, 0.3, -0.21), Vector3.new(27, 15, -30)),
				key(0.52, Vector3.new(-0.125, 0.25, -0.2), Vector3.new(18, 14, -34)),
				key(0.66, Vector3.new(-0.09, 0.18, -0.16), Vector3.new(12, 10, -24)),
				key(0.86, Vector3.new(-0.03, 0.08, -0.06), Vector3.new(9, 4, -8)),
				key(0.94, Vector3.new(0.015, -0.02, 0.015), Vector3.new(-3, -2, 3)),
				key(1, ZERO, ZERO),
			},
		},
		-- Tempest-Strike line, 2026-11-22 (owner playtest notes; our own moves, every
		-- one winds up, overshoots and settles; Util/TempestIdle draws the water on
		-- the same beats).
		--
		-- Stinger reload (owner: "makes the hand do like some unnatural movements"):
		-- the Vandal's reload rolled it 46 degrees with the off hand on the mag.
		-- Half the tilt and roll, no yaw swing, so the wrist stays in range.
		ReloadTempestStinger = {
			length = 1,
			pivot = "Center",
			smooth = true,
			marks = { MagOut = 0.17, MagIn = 0.42, Rack = 0.86 },
			keys = {
				key(0, ZERO, ZERO),
				key(0.04, Vector3.new(0.01, -0.018, 0.008), Vector3.new(-2.5, -1.5, 3)),
				key(0.12, Vector3.new(-0.07, 0.13, -0.1), Vector3.new(12, 6, -20)),
				key(0.165, Vector3.new(-0.065, 0.122, -0.1), Vector3.new(10, 5, -18)),
				key(0.19, Vector3.new(-0.06, 0.145, -0.105), Vector3.new(14, 5, -16)), -- mag out: a jolt
				key(0.26, Vector3.new(-0.066, 0.12, -0.1), Vector3.new(9, 5, -19)),
				key(0.36, Vector3.new(-0.068, 0.112, -0.1), Vector3.new(8, 6, -21)),
				key(0.405, Vector3.new(-0.068, 0.1, -0.098), Vector3.new(6.5, 6, -22)), -- brace
				key(0.435, Vector3.new(-0.06, 0.15, -0.105), Vector3.new(14, 4, -15)), -- slapped home
				key(0.52, Vector3.new(-0.06, 0.12, -0.1), Vector3.new(9, 4, -17)),
				key(0.66, Vector3.new(-0.045, 0.09, -0.08), Vector3.new(6, 3, -12)),
				key(0.86, Vector3.new(-0.015, 0.04, -0.03), Vector3.new(4, 1, -4)),
				key(0.94, Vector3.new(0.01, -0.012, 0.01), Vector3.new(-2, -1, 2)),
				key(1, ZERO, ZERO),
			},
		},
		-- Sheriff reload (on top of its own clip, which already flips the revolver
		-- about 50 degrees): lift as the cylinder swings out, a jolt up as the
		-- ejector throws the cases, turn the cylinder to the loader, a small push
		-- as the rounds seat, then the wrist flick that snaps the cylinder shut.
		ReloadTempestSheriff = {
			length = 1,
			pivot = "Center",
			smooth = true,
			marks = { Open = 0.08, Eject = 0.2, ShellIn = 0.45, Close = 0.66 },
			keys = {
				key(0, ZERO, ZERO),
				key(0.04, Vector3.new(0.01, -0.02, 0.01), Vector3.new(-3, -2, 3)),
				key(0.08, Vector3.new(-0.06, 0.08, -0.05), Vector3.new(10, 8, -14)), -- cylinder out
				key(0.12, Vector3.new(-0.055, 0.07, -0.05), Vector3.new(8, 7, -12)),
				key(0.2, Vector3.new(-0.05, 0.11, -0.04), Vector3.new(16, 6, -10)), -- cases thrown
				key(0.26, Vector3.new(-0.06, 0.08, -0.05), Vector3.new(9, 7, -13)),
				key(0.36, Vector3.new(-0.07, 0.05, -0.06), Vector3.new(4, 10, -18)), -- to the loader
				key(0.45, Vector3.new(-0.07, 0.035, -0.06), Vector3.new(1, 10, -19)), -- rounds seat
				key(0.5, Vector3.new(-0.068, 0.05, -0.06), Vector3.new(5, 9, -17)),
				key(0.62, Vector3.new(-0.06, 0.06, -0.05), Vector3.new(6, 12, -24)), -- wind-up
				key(0.66, Vector3.new(-0.02, 0.07, -0.03), Vector3.new(10, -4, 14)), -- flicked shut
				key(0.72, Vector3.new(-0.015, 0.03, -0.02), Vector3.new(3, -2, 6)),
				key(0.84, Vector3.new(0.01, -0.012, 0.008), Vector3.new(-2, 1, -2)),
				key(0.94, Vector3.new(0, 0.004, 0), Vector3.new(0.6, 0, 0.4)),
				key(1, ZERO, ZERO),
			},
		},
		-- Sheriff inspect (owner: the stock twirl looked "unnatural/impossible"):
		-- no toss. Turn it to show the right side, tip the top up, bring it to the
		-- middle rolled toward you as its own clip swings the cylinder out (0.57)
		-- and spins it (a water ring round the open cylinder, TempestProfiles
		-- roll 0.56-0.86), then the wrist flick that shuts it and home past the
		-- hold. Every turn stays in a wrist's range.
		InspectTempestSheriff = {
			length = 2.8,
			pivot = "Center",
			smooth = true,
			keys = {
				key(0, ZERO, ZERO),
				key(0.05, Vector3.new(0.02, -0.03, 0.02), Vector3.new(-4, -6, 4)),
				key(0.16, Vector3.new(-0.21, 0.15, -0.13), Vector3.new(10, 60, -20)), -- past the right side
				key(0.22, Vector3.new(-0.2, 0.14, -0.125), Vector3.new(7, 52, -16)),
				key(0.31, Vector3.new(-0.205, 0.16, -0.13), Vector3.new(18, 50, -24)), -- the top up
				key(0.42, Vector3.new(-0.21, 0.15, -0.13), Vector3.new(8, 54, -16)),
				key(0.5, Vector3.new(-0.12, 0.12, -0.1), Vector3.new(4, 20, -8)),
				key(0.58, Vector3.new(-0.14, 0.13, -0.16), Vector3.new(10, -8, 38)), -- rolled to you, cylinder out
				key(0.66, Vector3.new(-0.135, 0.12, -0.155), Vector3.new(8, -6, 34)),
				key(0.78, Vector3.new(-0.14, 0.125, -0.16), Vector3.new(11, -9, 37)),
				key(0.83, Vector3.new(-0.13, 0.12, -0.15), Vector3.new(9, -10, 42)), -- wind-up
				key(0.87, Vector3.new(-0.05, 0.06, -0.06), Vector3.new(6, 4, -14)), -- flicked shut
				key(0.91, Vector3.new(-0.02, 0.02, -0.02), Vector3.new(1, 2, -4)),
				key(0.955, Vector3.new(0.015, -0.02, 0.012), Vector3.new(-2.5, -1, 2.5)),
				key(1, ZERO, ZERO),
			},
		},
		-- Marshal lever cycle (owner: "a custom cock back"), over its Fire clip (lever
		-- 0.41-0.68): the gun rolls out and dips as the lever swings down, then
		-- snaps back past the hold as it slams up.
		CycleTempestMarshal = {
			length = 0.92,
			pivot = "Center",
			smooth = true,
			keys = {
				key(0, ZERO, ZERO),
				key(0.38, ZERO, ZERO),
				key(0.45, Vector3.new(0.01, -0.025, 0.01), Vector3.new(-5, 3, -14)),
				key(0.55, Vector3.new(0.015, -0.035, 0.012), Vector3.new(-7, 4, -18)),
				key(0.66, Vector3.new(-0.005, 0.012, -0.006), Vector3.new(3, -1, 5)), -- lever home
				key(0.76, Vector3.new(0.002, -0.004, 0.002), Vector3.new(-1, 0, -1.5)),
				key(1, ZERO, ZERO),
			},
		},
		-- Shell guns (Bucky, Marshal), over their own clips: a smooth tilt toward
		-- the port on Start, a wrist flick on End (water bursts at the port per
		-- round come from Util/TempestIdle; no track per shell).
		ReloadStartTempestBucky = shellStart(false),
		ReloadStartTempestMarshal = shellStart(true),
		ReloadEndTempest = {
			length = 1,
			pivot = "Center",
			smooth = true,
			keys = {
				key(0, ZERO, ZERO),
				key(0.2, Vector3.new(0.006, -0.012, 0.006), Vector3.new(-1.5, -1, 2.5)),
				key(0.42, Vector3.new(-0.012, 0.03, -0.016), Vector3.new(5, -1.5, -6)), -- flick
				key(0.66, Vector3.new(0.003, -0.006, 0.002), Vector3.new(-1, 0.2, 0.8)),
				key(0.85, ZERO, Vector3.new(0.2, 0, -0.15)),
				key(1, ZERO, ZERO),
			},
		},
		InspectShadowMist = {
			length = 5.4,
			pivot = "Center",
			own = true,
			smooth = true,
			keys = {
				key(0, ZERO, ZERO),
				key(0.08, Vector3.new(0.02, -0.04, -0.06), Vector3.new(-4, -6, 4)),
				key(0.23, Vector3.new(-0.51, 0.30, -1.05), Vector3.new(15, 67, -20)),
				key(0.43, Vector3.new(-0.57, 0.34, -1.13), Vector3.new(24, 77, -27)),
				key(0.60, Vector3.new(-0.52, 0.32, -1.10), Vector3.new(16, 64, -11)),
				key(0.76, Vector3.new(-0.49, 0.34, -1.06), Vector3.new(25, 59, -19)),
				key(0.86, Vector3.new(-0.33, 0.20, -0.58), Vector3.new(12, 32, -10)),
				key(inspectLock - 0.018, Vector3.new(-0.24, 0.14, -0.43), Vector3.new(8, 28, -8)),
				key(inspectLock, Vector3.new(-0.22, 0.11, -0.45), Vector3.new(5, 25, -5)),
				key(0.967, Vector3.new(0.02, -0.021, 0.02), Vector3.new(-3, -3, 3)),
				key(1, ZERO, ZERO),
			},
		},
		-- The Sheriff's (2026-11-15, the owner's revolver clip: between showing
		-- one side and the other the gun TWIRLS, about two turns in ~0.6 s).
		-- Block fists have no finger to spin it on, so it is a low toss: the
		-- gun hops out of the fist, turns twice end over end about its trigger
		-- guard (muzzle dipping forward first) and lands back as the hand
		-- turns it over to show the other side.
		InspectSheriff = inspectTrack({
			key(0, ZERO, ZERO),
			key(0.44, ZERO, ZERO),
			key(0.49, Vector3.new(0, 0.1, 0), Vector3.new(-180, 0, 0)),
			key(0.54, Vector3.new(0, 0.14, 0), Vector3.new(-360, 0, 0)),
			key(0.59, Vector3.new(0, 0.1, 0), Vector3.new(-540, 0, 0)),
			key(0.64, ZERO, Vector3.new(-720, 0, 0)),
			key(1, ZERO, Vector3.new(-720, 0, 0)),
		}, Vector3.new(0, 0.15, -0.22)),
		-- Knife, 2026-11-14 (owner's knife clip, art-source/reference/feel-videos;
		-- numbers and frames in vault Playtests/2026-11-14 Gun and Knife Feel from
		-- Videos). Every knife track is now keyed on screen: the fist's and the
		-- tip's place on screen per key, solved by tools/studio/knife_fp_keys.py
		-- (don't hand-edit the keys, change the tool and paste its output).
		--
		-- Inspect: a lean left, the knife brought to the middle with its flat
		-- face to you (held), turned edge-on, laid over pointing left with the
		-- edge down (held), tipped point-down, dropped out low right and back up.
		-- No spins (owner 2026-11-12: "a simple look at it"). The free hand
		-- drops out of view meanwhile (FREE_HAND_HIDDEN).
		-- Tempest-Strike Katana (2026-11-22): its own draw, combo, Tempest Cleave and
		-- ring-spin inspect, solved by tools/studio/knife_fp_keys.py (KATANA_*; the
		-- notes are there). Same lengths and hit times as the knife's.
		KatanaSlash1 = {
			length = 0.6,
			pivot = "Grip",
			own = true,
			screen = true,
			smooth = true,
			hit = 0.28,
			keys = {
				key(0, ZERO, ZERO),
				key(0.03, Vector3.new(0.092, 0.039, 0), Vector3.new(0, 0, -8)),
				key(0.12, Vector3.new(0.99, -0.4, 0.339), Vector3.new(-2.954, -9.214, -59.53)),
				key(0.19, Vector3.new(1.047, 0.787, 0.439), Vector3.new(12.443, 5.163, -69.314)),
				key(0.22, Vector3.new(0.304, 0.724, 0.539), Vector3.new(22.013, 15.517, -69.615)),
				key(0.245, Vector3.new(-0.173, 0.623, 0.539), Vector3.new(26.166, 16.221, -76.735)),
				key(0.265, Vector3.new(-0.651, 0.489, 0.539), Vector3.new(27.123, 18.34, -79.688)),
				key(0.28, Vector3.new(-1.217, 0.346, 0.539), Vector3.new(29.615, 36.681, -90.703)),
				key(0.305, Vector3.new(-1.784, 0.053, 0.539), Vector3.new(33.42, 48.961, -106.765)),
				key(
					0.33,
					Vector3.new(-2.306, -0.266, 0.539),
					Vector3.new(29.644, 53.057, -116.768)
				),
				key(0.42, Vector3.new(-2.799, -0.635, 0.539), Vector3.new(80.471, 38.391, 148.227)),
				key(0.5, Vector3.new(-2.888, -0.719, 0.539), Vector3.new(78.294, 30.711, 136.583)),
				key(0.64, Vector3.new(-1.247, -1.206, 0.339), Vector3.new(56.944, -8.061, 84.495)),
				key(0.74, Vector3.new(-0.211, -0.916, 0.239), Vector3.new(25.05, -14.824, 38.593)),
				key(0.83, Vector3.new(0, -0.258, 0), Vector3.new(0, 0, 0)),
				key(0.9, Vector3.new(0, 0.058, 0), Vector3.new(0, 0, -3)),
				key(0.96, Vector3.new(0, -0.013, 0), Vector3.new(0, 0, 1)),
				key(1, ZERO, ZERO),
			},
		},
		KatanaSlash2 = {
			length = 0.6,
			pivot = "Grip",
			own = true,
			screen = true,
			smooth = true,
			hit = 0.385,
			keys = {
				key(0, ZERO, ZERO),
				key(0.03, Vector3.new(-0.069, 0, 0), Vector3.new(0, 0, 12)),
				key(0.08, Vector3.new(-1.359, -0.325, 0.489), Vector3.new(-3.147, 4.692, 96.92)),
				key(0.14, Vector3.new(-1.859, -0.325, 0.539), Vector3.new(9.083, 9.857, 102.706)),
				key(0.3, Vector3.new(-1.934, -0.367, 0.539), Vector3.new(9.024, 9.982, 102.787)),
				key(0.34, Vector3.new(-1.561, -0.073, 0.539), Vector3.new(13.111, 5.111, 96.603)),
				key(0.36, Vector3.new(-1.113, 0.179, 0.539), Vector3.new(18.162, -4.244, 88.667)),
				key(0.385, Vector3.new(-0.591, 0.388, 0.539), Vector3.new(23.785, -31.779, 69.048)),
				key(
					0.41,
					Vector3.new(-0.069, 0.598, 0.539),
					Vector3.new(-18.866, -28.986, -10.728)
				),
				key(0.45, Vector3.new(0.442, 0.75, 0.489), Vector3.new(2.414, 7.573, -53.742)),
				key(0.55, Vector3.new(0.588, 0.602, 0.439), Vector3.new(1.022, 5.823, -38.31)),
				key(0.7, Vector3.new(0.185, 0.103, 0.339), Vector3.new(-0.072, 2.673, -15.322)),
				key(0.82, Vector3.new(0, 0.039, 0), Vector3.new(0, 0, 3)),
				key(0.92, Vector3.new(0, -0.013, 0), Vector3.new(0, 0, -1)),
				key(1, ZERO, ZERO),
			},
		},
		KatanaSlash3 = {
			length = 0.6,
			pivot = "Grip",
			own = true,
			screen = true,
			smooth = true,
			hit = 0.29,
			keys = {
				key(0, ZERO, ZERO),
				key(0.03, Vector3.new(0.092, 0.039, 0), Vector3.new(0, 0, -8)),
				key(0.1, Vector3.new(0.177, -0.316, 0.239), Vector3.new(-0.347, 0.506, -13.137)),
				key(0.2, Vector3.new(0.221, -0.4, 0.339), Vector3.new(0.026, 0.524, -17.407)),
				key(0.26, Vector3.new(-0.725, 0.002, 0.439), Vector3.new(73.271, 67.97, -164.035)),
				key(
					0.29,
					Vector3.new(-0.842, -0.048, -0.061),
					Vector3.new(90.233, 68.723, -174.202)
				),
				key(
					0.36,
					Vector3.new(-0.889, -0.079, -0.181),
					Vector3.new(90.977, 68.127, -174.579)
				),
				key(
					0.44,
					Vector3.new(-0.817, -0.069, -0.081),
					Vector3.new(94.322, 67.712, -178.593)
				),
				key(0.52, Vector3.new(-0.565, -0.113, 0.089), Vector3.new(-26.61, 52.485, -22.696)),
				key(0.62, Vector3.new(-0.158, -0.149, 0.139), Vector3.new(-5.076, -8.972, 22.418)),
				key(0.75, Vector3.new(0, 0.058, 0), Vector3.new(0, 0, -5)),
				key(0.88, Vector3.new(0, -0.015, 0), Vector3.new(0, 0, 2)),
				key(1, ZERO, ZERO),
			},
		},
		KatanaHeavyStab = {
			length = 0.9,
			pivot = "Grip",
			own = true,
			screen = true,
			smooth = true,
			hit = 0.42,
			keys = {
				key(0, ZERO, ZERO),
				key(0.05, Vector3.new(0.155, -0.266, 0.139), Vector3.new(-1.771, -0.714, -7.395)),
				key(0.14, Vector3.new(-1.247, -0.501, 0.339), Vector3.new(-4.405, 4.016, 90.45)),
				key(0.24, Vector3.new(-1.417, -0.533, 0.359), Vector3.new(-4.401, 3.817, 90.918)),
				key(0.34, Vector3.new(-1.495, -0.534, 0.379), Vector3.new(-4.365, 3.526, 91.276)),
				key(0.38, Vector3.new(-1.382, 0.002, 0.439), Vector3.new(-1.641, 1.296, 83.747)),
				key(0.4, Vector3.new(-0.971, 0.169, 0.439), Vector3.new(-0.01, -13.089, 85.036)),
				key(
					0.42,
					Vector3.new(-0.397, 0.205, 0.439),
					Vector3.new(75.905, -21.469, -158.376)
				),
				key(
					0.445,
					Vector3.new(0.177, 0.205, 0.439),
					Vector3.new(72.576, -13.065, -114.511)
				),
				key(0.5, Vector3.new(0.74, 0.151, 0.389), Vector3.new(73.871, -13.452, -108.228)),
				key(0.6, Vector3.new(0.901, -0.048, 0.339), Vector3.new(39.995, 10.12, -57.582)),
				key(0.72, Vector3.new(0.346, -0.196, 0.159), Vector3.new(-4.392, -9.943, 5.738)),
				key(0.84, Vector3.new(0, 0.058, 0), Vector3.new(0, 0, -5)),
				key(0.93, Vector3.new(0, -0.015, 0), Vector3.new(0, 0, 2)),
				key(1, ZERO, ZERO),
			},
		},
		KatanaDraw = {
			length = 0.75,
			pivot = "Grip",
			own = true,
			screen = true,
			smooth = true,
			keys = {
				key(0, Vector3.new(0.882, -1.437, 0.289), Vector3.new(-45.142, -30.41, 122.601)),
				key(
					0.14,
					Vector3.new(0.565, -0.702, 0.289),
					Vector3.new(-38.308, -18.359, 108.903)
				),
				key(0.26, Vector3.new(0.341, -0.262, 0.289), Vector3.new(-19.931, 1.753, 88.781)),
				key(0.36, Vector3.new(0.155, 0.011, 0.289), Vector3.new(1.786, 4.872, 63.499)),
				key(0.44, Vector3.new(0.027, 0.127, 0.259), Vector3.new(8.513, -1.822, 23.994)),
				key(0.52, Vector3.new(-0.075, 0.164, 0.239), Vector3.new(3.201, -7.478, -26.424)),
				key(0.62, Vector3.new(0, -0.065, 0), Vector3.new(0, 0, 4)),
				key(0.74, Vector3.new(0, 0.026, 0), Vector3.new(0, 0, -1.5)),
				key(0.86, Vector3.new(0, -0.008, 0), Vector3.new(0, 0, 0.5)),
				key(1, ZERO, ZERO),
			},
		},
		KatanaInspect = {
			length = 3.4,
			pivot = "Grip",
			own = true,
			screen = true,
			smooth = true,
			keys = {
				key(0, ZERO, ZERO),
				key(0.06, Vector3.new(-0.115, 0.052, 0), Vector3.new(0, 0, 8)),
				key(0.13, Vector3.new(-0.512, -0.042, 0.389), Vector3.new(-14.46, 7.499, 67.587)),
				key(0.19, Vector3.new(-0.46, -0.023, 0.389), Vector3.new(-15.268, 6.771, 70.496)),
				key(0.3, Vector3.new(-0.46, -0.013, 0.389), Vector3.new(-15.045, 6.998, 69.661)),
				key(0.38, Vector3.new(-0.443, -0.023, 0.389), Vector3.new(-15.557, 6.533, 71.703)),
				key(0.45, Vector3.new(-0.46, -0.003, 0.389), Vector3.new(-14.485, 7.515, 67.703)),
				key(0.53, Vector3.new(-0.46, -0.023, 0.389), Vector3.new(-15.168, 6.874, 70.117)),
				key(0.64, Vector3.new(-0.443, -0.032, 0.389), Vector3.new(-14.888, 7.231, 69.155)),
				key(0.68, Vector3.new(-0.409, -0.081, 0.389), Vector3.new(-15.499, 6.946, 71.727)),
				key(0.73, Vector3.new(-0.531, 0.073, 0.339), Vector3.new(-1.764, 0.907, 11.213)),
				key(0.77, Vector3.new(-0.531, 0.093, 0.339), Vector3.new(-1.882, -2.666, -1.812)),
				key(0.81, Vector3.new(-0.531, 0.073, 0.339), Vector3.new(-2.101, -1.026, 4.756)),
				key(0.9, Vector3.new(-0.513, 0.063, 0.339), Vector3.new(-1.93, -0.915, 3.11)),
				key(0.95, Vector3.new(-0.249, 0.065, 0.239), Vector3.new(-0.726, -0.339, 2.42)),
				key(0.98, Vector3.new(0, 0.019, 0), Vector3.new(0, 0, 2)),
				key(1, ZERO, ZERO),
			},
		},
		ArcInspect = {
			length = 64 / 24,
			pivot = "Grip",
			own = true,
			screen = true,
			smooth = true,
			keys = {
				key(0, ZERO, ZERO),
				key(0.11, Vector3.new(-0.112, 0.02, 0.075), Vector3.new(-5, 3, 7)),
				key(0.24, Vector3.new(-0.627, 0.161, 0.374), Vector3.new(-45, 45, 35)),
				key(0.39, Vector3.new(-0.684, 0.179, 0.391), Vector3.new(-47, 53, 34)),
				key(0.58, Vector3.new(-0.695, 0.201, 0.376), Vector3.new(-37, 56, 39)),
				key(0.76, Vector3.new(-0.638, 0.128, 0.352), Vector3.new(-49, 50, 31)),
				key(0.86, Vector3.new(-0.355, 0.052, 0.205), Vector3.new(-22, 26, 16)),
				key(1, ZERO, ZERO),
			},
		},
		InspectMelee = {
			length = 3.4,
			pivot = "Grip",
			own = true,
			screen = true,
			smooth = true,
			keys = {
				key(0, ZERO, ZERO),
				key(0.08, Vector3.new(-0.138, 0.052, 0), Vector3.new(0, 0, 10)),
				key(0.15, Vector3.new(-0.683, 0.151, 0.389), Vector3.new(-48.801, 51.07, 39.631)),
				key(0.2, Vector3.new(-0.683, 0.151, 0.389), Vector3.new(-43.45, 54.6, 32.277)),
				key(0.32, Vector3.new(-0.702, 0.164, 0.399), Vector3.new(-48.885, 55.941, 36.277)),
				key(0.36, Vector3.new(-0.702, 0.097, 0.399), Vector3.new(-50.012, 55.481, 37.241)),
				key(0.39, Vector3.new(-0.702, 0.231, 0.399), Vector3.new(-48.739, 56, 36.152)),
				key(0.45, Vector3.new(-0.701, 0.103, 0.389), Vector3.new(-49.517, 55.594, 37.303)),
				key(0.52, Vector3.new(-0.701, 0.17, 0.389), Vector3.new(-48.908, 55.846, 36.777)),
				key(0.55, Vector3.new(-0.701, 0.074, 0.389), Vector3.new(-49.779, 55.484, 37.529)),
				key(0.572, Vector3.new(-0.701, 0.122, 0.389), Vector3.new(-16.5, 26.725, 24.747)),
				key(0.59, Vector3.new(-0.708, 0.139, 0.384), Vector3.new(3.037, 1.037, 33.288)),
				key(0.603, Vector3.new(-0.716, 0.147, 0.379), Vector3.new(1.314, 1.432, 57.889)),
				key(0.616, Vector3.new(-0.731, 0.16, 0.359), Vector3.new(-5.839, 2.724, 86.272)),
				key(0.63, Vector3.new(-0.746, 0.174, 0.339), Vector3.new(-8.596, 2.27, 97.093)),
				key(0.7, Vector3.new(-0.737, 0.164, 0.339), Vector3.new(-6.621, 1.623, 101.73)),
				key(0.85, Vector3.new(-0.71, 0.133, 0.339), Vector3.new(-4.35, 0.422, 110.389)),
				key(0.92, Vector3.new(-0.308, -0.076, 0.239), Vector3.new(-1.651, 1.238, 47.737)),
				key(0.97, Vector3.new(0, 0.026, 0), Vector3.new(0, 0, 3)),
				key(1, ZERO, ZERO),
			},
			toss = {
				key(0, Vector3.new(0, 0, 0), Vector3.new(0, 0, 0)),
				key(0.39, Vector3.new(0, 0, 0), Vector3.new(0, 0, 0)),
				key(0.43, Vector3.new(0, 0, -0.3), Vector3.new(120, 0, 0)),
				key(0.47, Vector3.new(0, 0, -0.42), Vector3.new(240, 0, 0)),
				key(0.505, Vector3.new(0, 0, -0.22), Vector3.new(330, 0, 0)),
				key(0.53, Vector3.new(0, 0, 0), Vector3.new(360, 0, 0)),
				key(1, Vector3.new(0, 0, 0), Vector3.new(360, 0, 0)),
			},
			tossPivot = Vector3.new(0, 0, -0.4),
		},
		-- The Giltfold Fan's inspect (2026-11-21, owner: "like you're fanning
		-- yourself for a little bit", then "too high up in the air... a little
		-- bit chunky... should last for longer... mainly like a thing of the
		-- wrist"): a small coil, the open fan up a little beside the face (a
		-- touch past, settle), then seven relaxed waves that build and fade,
		-- low on the screen. The block arm has no wrist, so the turn is the
		-- fist and fan together about the grip (this track's pivot): the
		-- forearm stays put but for a small sway a quarter wave behind. Keys
		-- every quarter wave on a sine, so the cubic has no steps. The leaf
		-- flexes behind each wave (Config/MeleeSkins FAN.INSPECT). Chosen when
		-- the knife slot holds the Fan (ViewmodelController). Made by a script
		-- (wave count, sizes and envelope in the 2026-11-21 FP lane note).
		InspectFan = {
			length = 4.6,
			pivot = "Grip",
			own = true,
			screen = true,
			smooth = true,
			keys = {
				key(0, Vector3.new(0, 0, 0), Vector3.new(0, 0, 0)),
				key(0.05, Vector3.new(0.02, -0.03, 0.015), Vector3.new(-3, -5, -4)),
				key(0.12, Vector3.new(-0.11, 0.085, 0.105), Vector3.new(5, 25, 9)),
				key(0.15, Vector3.new(-0.1, 0.07, 0.1), Vector3.new(5.65, 31.35, 11.3)),
				key(0.175, Vector3.new(-0.111, 0.076, 0.105), Vector3.new(4.0, 22.0, 8.0)),
				key(0.2, Vector3.new(-0.1, 0.07, 0.1), Vector3.new(1.9, 10.1, 3.8)),
				key(0.225, Vector3.new(-0.086, 0.062, 0.094), Vector3.new(4.0, 22.0, 8.0)),
				key(0.25, Vector3.new(-0.1, 0.07, 0.1), Vector3.new(6.55, 36.45, 13.1)),
				key(0.275, Vector3.new(-0.116, 0.079, 0.107), Vector3.new(4.0, 22.0, 8.0)),
				key(0.3, Vector3.new(-0.1, 0.07, 0.1), Vector3.new(1.225, 6.275, 2.45)),
				key(0.325, Vector3.new(-0.082, 0.06, 0.092), Vector3.new(4.0, 22.0, 8.0)),
				key(0.35, Vector3.new(-0.1, 0.07, 0.1), Vector3.new(7.0, 39.0, 14.0)),
				key(0.375, Vector3.new(-0.118, 0.08, 0.108), Vector3.new(4.0, 22.0, 8.0)),
				key(0.4, Vector3.new(-0.1, 0.07, 0.1), Vector3.new(1.0, 5.0, 2.0)),
				key(0.425, Vector3.new(-0.082, 0.06, 0.092), Vector3.new(4.0, 22.0, 8.0)),
				key(0.45, Vector3.new(-0.1, 0.07, 0.1), Vector3.new(7.0, 39.0, 14.0)),
				key(0.475, Vector3.new(-0.118, 0.08, 0.108), Vector3.new(4.0, 22.0, 8.0)),
				key(0.5, Vector3.new(-0.1, 0.07, 0.1), Vector3.new(1.075, 5.425, 2.15)),
				key(0.525, Vector3.new(-0.083, 0.06, 0.092), Vector3.new(4.0, 22.0, 8.0)),
				key(0.55, Vector3.new(-0.1, 0.07, 0.1), Vector3.new(6.85, 38.15, 13.7)),
				key(0.575, Vector3.new(-0.117, 0.079, 0.107), Vector3.new(4.0, 22.0, 8.0)),
				key(0.6, Vector3.new(-0.1, 0.07, 0.1), Vector3.new(1.375, 7.125, 2.75)),
				key(0.625, Vector3.new(-0.085, 0.062, 0.093), Vector3.new(4.0, 22.0, 8.0)),
				key(0.65, Vector3.new(-0.1, 0.07, 0.1), Vector3.new(6.4, 35.6, 12.8)),
				key(0.675, Vector3.new(-0.114, 0.078, 0.106), Vector3.new(4.0, 22.0, 8.0)),
				key(0.7, Vector3.new(-0.1, 0.07, 0.1), Vector3.new(1.9, 10.1, 3.8)),
				key(0.725, Vector3.new(-0.089, 0.064, 0.095), Vector3.new(4.0, 22.0, 8.0)),
				key(0.75, Vector3.new(-0.1, 0.07, 0.1), Vector3.new(5.8, 32.2, 11.6)),
				key(0.775, Vector3.new(-0.11, 0.076, 0.104), Vector3.new(4.0, 22.0, 8.0)),
				key(0.8, Vector3.new(-0.1, 0.07, 0.1), Vector3.new(2.65, 14.35, 5.3)),
				key(0.825, Vector3.new(-0.094, 0.067, 0.097), Vector3.new(4.0, 22.0, 8.0)),
				key(0.85, Vector3.new(-0.1, 0.07, 0.1), Vector3.new(4.9, 27.1, 9.8)),
				key(0.885, Vector3.new(-0.09, 0.06, 0.09), Vector3.new(3, 20, 7)),
				key(0.95, Vector3.new(0.02, -0.04, 0.01), Vector3.new(-2.5, -3, -2.5)), -- lowered over ~0.3 s, past the hold
				key(0.98, Vector3.new(-0.004, 0.008, 0), Vector3.new(0.6, 0.6, 0.6)),
				key(1, Vector3.new(0, 0, 0), Vector3.new(0, 0, 0)),
			},
		},
		-- Pull-out: up from below with the blade hanging, about three quarters
		-- of a turn anticlockwise in the fist in ~0.2 s while the arm swings in
		-- from the right, landing pointing left low on the left, back up to the
		-- hold. The clip's twirl (the owner turned down a slow 360 on 2026-11-08;
		-- this one is quick and in the screen's plane). MELEE_DRAW_TRACK =
		-- "DrawMeleeSwipe" puts back the old swipe-out.
		ArcDraw = {
			length = 14 / 24,
			pivot = "Grip",
			own = true,
			screen = true,
			smooth = true,
			keys = {
				key(0, Vector3.new(0.227, -0.82, 0.21), Vector3.new(-42, -19, -23)),
				key(0.21, Vector3.new(0.158, -0.47, 0.15), Vector3.new(-26, -11, -11)),
				key(0.5, Vector3.new(-0.065, 0.064, 0.016), Vector3.new(11, 8, 11)),
				key(0.72, Vector3.new(0.018, -0.036, 0.007), Vector3.new(-4, -2, -3)),
				key(1, ZERO, ZERO),
			},
		},
		DrawMelee = {
			length = 0.75,
			pivot = "Grip",
			own = true,
			screen = true,
			smooth = true,
			keys = {
				key(0, Vector3.new(0.662, -1.298, 0.239), Vector3.new(-27.615, -21.677, 12.711)),
				key(0.2, Vector3.new(0.095, -0.385, 0.219), Vector3.new(-7.051, -6.519, 6.305)),
				key(0.28, Vector3.new(-0.012, 0.133, 0.139), Vector3.new(3.815, 1.166, -2.913)),
				key(0.36, Vector3.new(0.022, -0.159, 0.119), Vector3.new(-2.386, -2.05, 1.848)),
				key(0.52, Vector3.new(0, -0.063, 0.119), Vector3.new(-0.455, -0.929, 0.632)),
				key(0.6, Vector3.new(-0.021, 0.008, 0.119), Vector3.new(0.867, -0.203, 0.173)),
				key(0.68, Vector3.new(0, -0.183, 0.119), Vector3.new(-1.103, 1.024, -4.359)),
				key(0.8, Vector3.new(0, 0.039, 0), Vector3.new(0, 0, 2.5)),
				key(0.9, Vector3.new(0, -0.01, 0), Vector3.new(0, 0, -1)),
				key(1, ZERO, ZERO),
			},
			toss = {
				key(0, Vector3.new(0, 0, 0), Vector3.new(0, 0, 0)),
				key(0.28, Vector3.new(0, 0, 0), Vector3.new(0, 0, 0)),
				key(0.36, Vector3.new(0, 0, -0.28), Vector3.new(0, 100, 0)),
				key(0.44, Vector3.new(0, 0, -0.4), Vector3.new(0, 200, 0)),
				key(0.52, Vector3.new(0, 0, -0.25), Vector3.new(0, 300, 0)),
				key(0.6, Vector3.new(0, 0, 0), Vector3.new(0, 360, 0)),
				key(1, Vector3.new(0, 0, 0), Vector3.new(0, 360, 0)),
			},
			tossPivot = Vector3.new(0, 0, -0.4),
		},
		-- The pull-out before 2026-11-14 (owner 2026-11-08: a swipe out, not a twirl).
		-- Knife draw, 2026-11-08 (owner: a swipe out, not a twirl): up from low
		-- right, swept out across to the left past the hold, settle back.
		DrawMeleeSwipe = {
			length = 0.56,
			pivot = "Grip",
			keys = {
				key(0, Vector3.new(0.25, -0.85, 0.2), Vector3.new(-70, -20, -40)),
				key(
					0.48,
					Vector3.new(-0.1, 0.05, -0.06),
					Vector3.new(6, 14, 20),
					Enum.EasingStyle.Sine,
					OUT
				),
				key(
					0.74,
					Vector3.new(0.02, -0.01, 0),
					Vector3.new(-3, -4, -5),
					Enum.EasingStyle.Sine,
					INOUT
				),
				key(1, ZERO, ZERO, Enum.EasingStyle.Sine, INOUT),
			},
		},
		-- Knife attacks. Light slashes alternate forehand / backhand (Slash3 is a
		-- second forehand, wound up high): a lean, the fist leaving the screen to
		-- wind up, one fast sweep with the blade pointing forward over the
		-- crosshair (on screen ~60 ms, contact at `hit`), the fist leaving the
		-- screen on the far side, back up from below. The free arm drops out for
		-- it (FREE_HAND_FOLLOW). HeavyStab: dropped down-right, cocked low in the
		-- middle with the point forward, held, a thrust with the point dipping and
		-- the free hand coming in (MELEE_HEAVY_HAND), held, the blade rolled back
		-- up through the right. Hit-stop and the camera punch are runtime only
		-- (WeaponController), so a whiff never freezes.
		Slash1 = {
			length = 0.6,
			pivot = "Grip",
			own = true,
			screen = true,
			smooth = true,
			hit = 0.28,
			keys = {
				key(0, ZERO, ZERO),
				key(0.03, Vector3.new(0.092, 0.026, 0), Vector3.new(0, 0, -8)),
				key(0.12, Vector3.new(0.901, -0.803, 0.339), Vector3.new(1.226, -4.336, -79.832)),
				key(0.18, Vector3.new(0.998, 0.418, 0.439), Vector3.new(22.063, 7.038, -80.072)),
				key(0.21, Vector3.new(0.229, 0.682, 0.539), Vector3.new(27.04, 18.722, -72.525)),
				key(0.235, Vector3.new(-0.218, 0.64, 0.539), Vector3.new(28.026, 16.943, -78.508)),
				key(0.258, Vector3.new(-0.666, 0.531, 0.539), Vector3.new(26.914, 18.667, -79.616)),
				key(0.28, Vector3.new(-1.247, 0.388, 0.539), Vector3.new(30.707, 36.073, -93.267)),
				key(0.305, Vector3.new(-1.784, 0.086, 0.539), Vector3.new(31.661, 46.076, -105.32)),
				key(0.33, Vector3.new(-2.262, -0.216, 0.539), Vector3.new(31.387, 50.692, -117.69)),
				key(0.42, Vector3.new(-2.754, -0.619, 0.539), Vector3.new(80.499, 36.755, 148.455)),
				key(0.5, Vector3.new(-2.858, -0.702, 0.539), Vector3.new(78.103, 30.066, 137.795)),
				key(0.64, Vector3.new(-1.247, -1.206, 0.339), Vector3.new(56.826, -8.683, 85.184)),
				key(0.74, Vector3.new(-0.211, -0.916, 0.239), Vector3.new(24.832, -15.176, 38.806)),
				key(0.83, Vector3.new(0, -0.258, 0), Vector3.new(0, 0, 0)),
				key(0.9, Vector3.new(0, 0.058, 0), Vector3.new(0, 0, -3)),
				key(0.96, Vector3.new(0, -0.013, 0), Vector3.new(0, 0, 1)),
				key(1, ZERO, ZERO),
			},
		},
		Slash2 = {
			length = 0.6,
			pivot = "Grip",
			own = true,
			screen = true,
			smooth = true,
			hit = 0.385,
			keys = {
				key(0, ZERO, ZERO),
				key(0.03, Vector3.new(-0.069, 0, 0), Vector3.new(0, 0, 12)),
				key(0.07, Vector3.new(-1.203, -0.193, 0.489), Vector3.new(-5.462, 5.323, 78.586)),
				key(0.12, Vector3.new(-1.71, 0.204, 0.539), Vector3.new(3.025, 4.957, 71.951)),
				key(0.27, Vector3.new(-1.814, 0.179, 0.539), Vector3.new(2.942, 5.149, 73.073)),
				key(0.33, Vector3.new(-1.516, 0.388, 0.539), Vector3.new(7.827, -2.309, 63.706)),
				key(0.36, Vector3.new(-1.307, 0.456, 0.539), Vector3.new(6.706, -10.376, 60.261)),
				key(0.385, Vector3.new(-0.979, 0.456, 0.539), Vector3.new(5.764, -12.467, 59.839)),
				key(0.415, Vector3.new(-0.561, 0.221, 0.539), Vector3.new(-0.018, -28.75, 47.85)),
				key(0.445, Vector3.new(-0.069, -0.157, 0.539), Vector3.new(-0.986, -26.61, 43.751)),
				key(0.53, Vector3.new(0.677, -0.633, 0.489), Vector3.new(-2.738, -20.287, 32.704)),
				key(0.58, Vector3.new(0.802, -0.721, 0.489), Vector3.new(-3.136, -16.465, 26.496)),
				key(0.7, Vector3.new(0.543, -1.156, 0.339), Vector3.new(-2.367, -7.299, 12.029)),
				key(0.8, Vector3.new(0, -0.258, 0), Vector3.new(0, 0, 0)),
				key(0.9, Vector3.new(0, 0.058, 0), Vector3.new(0, 0, 3)),
				key(0.96, Vector3.new(0, -0.013, 0), Vector3.new(0, 0, -1)),
				key(1, ZERO, ZERO),
			},
		},
		Slash3 = {
			length = 0.6,
			pivot = "Grip",
			own = true,
			screen = true,
			smooth = true,
			hit = 0.29,
			keys = {
				key(0, ZERO, ZERO),
				key(0.03, Vector3.new(0.092, 0.039, 0), Vector3.new(0, 0, -8)),
				key(0.12, Vector3.new(0.99, -0.35, 0.339), Vector3.new(6.866, -1.446, -74.322)),
				key(0.19, Vector3.new(1.08, 0.833, 0.439), Vector3.new(19.763, 7.681, -76.063)),
				key(0.22, Vector3.new(0.274, 0.556, 0.539), Vector3.new(25.676, 13.138, -78.256)),
				key(0.245, Vector3.new(-0.218, 0.456, 0.539), Vector3.new(27.692, 13.24, -83.397)),
				key(0.268, Vector3.new(-0.71, 0.372, 0.539), Vector3.new(27.692, 17.567, -84.94)),
				key(0.29, Vector3.new(-1.262, 0.263, 0.539), Vector3.new(28.5, 30.199, -93.964)),
				key(
					0.315,
					Vector3.new(-1.814, 0.036, 0.539),
					Vector3.new(31.162, 43.556, -107.695)
				),
				key(
					0.34,
					Vector3.new(-2.306, -0.241, 0.539),
					Vector3.new(31.588, 52.472, -119.445)
				),
				key(0.43, Vector3.new(-2.799, -0.602, 0.539), Vector3.new(78.658, 35.941, 148.302)),
				key(0.51, Vector3.new(-2.888, -0.686, 0.539), Vector3.new(75.847, 28.22, 136.791)),
				key(0.65, Vector3.new(-1.247, -1.206, 0.339), Vector3.new(54.763, -8.777, 84.172)),
				key(0.75, Vector3.new(-0.211, -0.916, 0.239), Vector3.new(23.883, -14.669, 38.378)),
				key(0.84, Vector3.new(0, -0.258, 0), Vector3.new(0, 0, 0)),
				key(0.91, Vector3.new(0, 0.058, 0), Vector3.new(0, 0, -3)),
				key(0.96, Vector3.new(0, -0.013, 0), Vector3.new(0, 0, 1)),
				key(1, ZERO, ZERO),
			},
		},
		HeavyStab = {
			length = 0.9,
			pivot = "Grip",
			own = true,
			screen = true,
			smooth = true,
			hit = 0.42,
			keys = {
				key(0, ZERO, ZERO),
				key(0.05, Vector3.new(0.085, -0.159, 0.119), Vector3.new(-0.722, -0.284, -4.716)),
				key(0.15, Vector3.new(0.274, -0.447, 0.239), Vector3.new(-3.1, -1.706, -12.589)),
				key(0.21, Vector3.new(-0.289, -0.216, 0.389), Vector3.new(-8.916, 45.227, -51.269)),
				key(0.27, Vector3.new(-0.798, 0.026, 0.519), Vector3.new(75.114, 66.235, -166.567)),
				key(0.36, Vector3.new(-0.777, 0.02, 0.599), Vector3.new(75.929, 60.594, -171.27)),
				key(
					0.42,
					Vector3.new(-0.842, -0.048, -0.061),
					Vector3.new(97.829, 61.722, 176.147)
				),
				key(0.5, Vector3.new(-0.889, -0.086, -0.201), Vector3.new(99.298, 60.801, 175.54)),
				key(
					0.58,
					Vector3.new(-0.817, -0.069, -0.081),
					Vector3.new(97.398, 60.088, 176.616)
				),
				key(
					0.63,
					Vector3.new(-0.621, -0.098, 0.039),
					Vector3.new(-29.339, 48.846, -11.778)
				),
				key(0.68, Vector3.new(-0.395, -0.115, 0.159), Vector3.new(-4.281, -9.998, 33.164)),
				key(0.78, Vector3.new(-0.012, -0.031, 0.139), Vector3.new(-2.715, -8.055, 15.809)),
				key(0.87, Vector3.new(0, 0.058, 0), Vector3.new(0, 0, -5)),
				key(0.94, Vector3.new(0, -0.015, 0), Vector3.new(0, 0, 2)),
				key(1, ZERO, ZERO),
			},
		},
		-- Body motion layered on the gun's own Reload clip (stretched to the
		-- reload time). 2026-11-13 (lane B; owner: reloads not "aggressive,
		-- bouncy or fun enough"). Measured before: the gun dipped DOWN and
		-- held still for ~1.2 s, and its "slap" landed at 1.4 s while the
		-- Vandal's mag went in at 0.75 s. RIVALS and Valorant (video study)
		-- lift the gun UP and in, muzzle up 15-50 degrees, rolled 25-40, snap
		-- into that pose in ~0.13 s with a small overshoot, keep it moving
		-- through every beat, and drop back into the hold past it. So: a
		-- small dip and counter-roll first (anticipation), a fast tilt up and
		-- in that overshoots, a jolt up as the old mag is ripped out, a brace
		-- and a hard slap up as the new one goes in, out to the charging
		-- handle, a muzzle kick on the rack, and home past the hold with a
		-- bounce. `marks` pin the beats onto each gun's own clip beats.
		Reload = {
			length = 1,
			pivot = "Center",
			marks = { MagOut = 0.17, MagIn = 0.42, Rack = 0.86 },
			keys = {
				key(0, ZERO, ZERO),
				key(
					0.04,
					Vector3.new(0.012, -0.022, 0.01),
					Vector3.new(-3, -2, 4),
					Enum.EasingStyle.Sine,
					OUT
				), -- anticipation
				key(
					0.12,
					Vector3.new(-0.135, 0.245, -0.19),
					Vector3.new(19, 14, -35),
					Enum.EasingStyle.Quad,
					OUT
				), -- tilt up and in, past the pose
				key(
					0.165,
					Vector3.new(-0.125, 0.23, -0.19),
					Vector3.new(15, 12, -31),
					Enum.EasingStyle.Sine,
					INOUT
				),
				key(
					0.19,
					Vector3.new(-0.12, 0.27, -0.2),
					Vector3.new(22, 13, -29),
					Enum.EasingStyle.Quad,
					OUT
				), -- mag ripped out: a jolt
				key(
					0.26,
					Vector3.new(-0.128, 0.22, -0.19),
					Vector3.new(14, 12, -34),
					Enum.EasingStyle.Sine,
					INOUT
				),
				key(
					0.36,
					Vector3.new(-0.132, 0.212, -0.19),
					Vector3.new(13, 15, -37),
					Enum.EasingStyle.Sine,
					INOUT
				), -- turns the magwell to the new mag
				key(
					0.405,
					Vector3.new(-0.13, 0.192, -0.185),
					Vector3.new(10.5, 15, -38),
					Enum.EasingStyle.Sine,
					INOUT
				), -- brace
				key(
					0.435,
					Vector3.new(-0.122, 0.26, -0.2),
					Vector3.new(21, 12, -29),
					Enum.EasingStyle.Quad,
					OUT
				), -- slapped home
				key(
					0.52,
					Vector3.new(-0.12, 0.212, -0.19),
					Vector3.new(11, 11, -32),
					Enum.EasingStyle.Sine,
					INOUT
				), -- settles
				key(
					0.62,
					Vector3.new(-0.075, 0.13, -0.18),
					Vector3.new(8, 11, -19),
					Enum.EasingStyle.Sine,
					Enum.EasingDirection.In
				), -- on its way out to the handle: arrives moving (2026-11-20: it stopped dead here, then jerked on)
				key(
					0.74,
					Vector3.new(-0.05, 0.065, -0.27),
					Vector3.new(9, 16, -10),
					Enum.EasingStyle.Quad,
					OUT
				), -- out, handle side up
				key(
					0.835,
					Vector3.new(-0.06, 0.058, -0.285),
					Vector3.new(7, 18, -12),
					Enum.EasingStyle.Sine,
					INOUT
				), -- tugged
				key(
					0.875,
					Vector3.new(-0.035, 0.09, -0.21),
					Vector3.new(15, 12, -6),
					Enum.EasingStyle.Quad,
					OUT
				), -- rack: the muzzle kicks
				key(
					0.95,
					Vector3.new(0.008, -0.025, 0.018),
					Vector3.new(-3.5, -1.5, 3),
					Enum.EasingStyle.Quad,
					INOUT
				), -- home, past the hold
				key(1, ZERO, ZERO, Enum.EasingStyle.Sine, INOUT),
			},
		},
		-- The Outlaw's own reload (break-action: both barrels drop, two rounds
		-- go into the breech, it snaps shut). 2026-11-13 (owner: "the Outlaw
		-- reload animation looks really weird. Like the left hand goes into
		-- the screen"). Measured on the shared track: the breech sat 0.49
		-- studs in front of the eye while the rounds went in, so the loading
		-- hand's arm walled off half the screen and the eye was inside it at
		-- 1.07-1.17 s. Here the gun is pushed out and down while it is open, so
		-- the hand works at arm's length below the sights; it flicks up as the
		-- action closes (marks.MagIn = the clip's Close) and lands past the
		-- hold. Used for ReloadEmpty too (ViewmodelController.reload).
		-- 2026-11-21 (round 3, owner's pick): the open-barrel keys rolled 24 deg
		-- back toward level (Z -22 -> +2) and 0.06 lower, so the dropped barrels
		-- hang at 63-70 deg on screen, steeper than the loading forearm (pinned
		-- at <= 50 deg by ARM_MIN_DROP): it ran down beside them and into them
		-- (0.10-0.20 deep). Measured clear on both reloads in every skin line;
		-- the loading fist stays >= 0.14 of the screen from the centre (was
		-- 0.03). Smooth (PCHIP) instead of an ease in and out at every key.
		ReloadOutlaw = {
			length = 1,
			smooth = true,
			pivot = "Center",
			marks = { MagOut = 0.22, MagIn = 0.83 },
			keys = {
				key(0, ZERO, ZERO),
				key(
					0.05,
					Vector3.new(0.01, -0.02, 0.01),
					Vector3.new(-2, -2, 3),
					Enum.EasingStyle.Sine,
					OUT
				), -- anticipation
				key(
					0.16,
					Vector3.new(-0.06, -0.23, -0.48),
					Vector3.new(-10, 12, 2),
					Enum.EasingStyle.Quad,
					OUT
				), -- out and down, past the pose
				key(
					0.22,
					Vector3.new(-0.055, -0.21, -0.46),
					Vector3.new(-6, 11, 5),
					Enum.EasingStyle.Sine,
					INOUT
				), -- barrels drop
				key(
					0.4,
					Vector3.new(-0.06, -0.22, -0.47),
					Vector3.new(-8, 13, 3),
					Enum.EasingStyle.Sine,
					INOUT
				),
				key(
					0.55,
					Vector3.new(-0.065, -0.225, -0.48),
					Vector3.new(-7, 14, 1),
					Enum.EasingStyle.Sine,
					INOUT
				), -- rounds in
				key(
					0.7,
					Vector3.new(-0.06, -0.22, -0.47),
					Vector3.new(-8, 12, 3),
					Enum.EasingStyle.Sine,
					INOUT
				),
				key(
					0.79,
					Vector3.new(-0.06, -0.24, -0.47),
					Vector3.new(-10, 12, 2),
					Enum.EasingStyle.Sine,
					INOUT
				), -- brace
				key(
					0.84,
					Vector3.new(-0.04, -0.09, -0.38),
					Vector3.new(8, 8, 2),
					Enum.EasingStyle.Quad,
					OUT
				), -- snapped shut: the muzzle flicks up
				key(
					0.93,
					Vector3.new(0.008, -0.02, 0.015),
					Vector3.new(-3, -1, 2.5),
					Enum.EasingStyle.Quad,
					INOUT
				), -- home, past the hold
				key(1, ZERO, ZERO, Enum.EasingStyle.Sine, INOUT),
			},
		},
		-- Empty reload: the same mag swap, then the full rack of the charging
		-- handle (pulled back and held, then let go on marks.Rack).
		ReloadEmpty = {
			length = 1,
			pivot = "Center",
			marks = { MagOut = 0.14, MagIn = 0.4, Rack = 0.9 },
			keys = {
				key(0, ZERO, ZERO),
				key(
					0.035,
					Vector3.new(0.012, -0.022, 0.01),
					Vector3.new(-3, -2, 4),
					Enum.EasingStyle.Sine,
					OUT
				), -- anticipation
				key(
					0.1,
					Vector3.new(-0.135, 0.245, -0.19),
					Vector3.new(19, 14, -35),
					Enum.EasingStyle.Quad,
					OUT
				), -- tilt up and in, past the pose
				key(
					0.135,
					Vector3.new(-0.125, 0.23, -0.19),
					Vector3.new(15, 12, -31),
					Enum.EasingStyle.Sine,
					INOUT
				),
				key(
					0.16,
					Vector3.new(-0.12, 0.27, -0.2),
					Vector3.new(22, 13, -29),
					Enum.EasingStyle.Quad,
					OUT
				), -- mag ripped out
				key(
					0.23,
					Vector3.new(-0.128, 0.22, -0.19),
					Vector3.new(14, 12, -34),
					Enum.EasingStyle.Sine,
					INOUT
				),
				key(
					0.34,
					Vector3.new(-0.132, 0.212, -0.19),
					Vector3.new(13, 15, -37),
					Enum.EasingStyle.Sine,
					INOUT
				),
				key(
					0.385,
					Vector3.new(-0.13, 0.192, -0.185),
					Vector3.new(10.5, 15, -38),
					Enum.EasingStyle.Sine,
					INOUT
				), -- brace
				key(
					0.415,
					Vector3.new(-0.122, 0.26, -0.2),
					Vector3.new(21, 12, -29),
					Enum.EasingStyle.Quad,
					OUT
				), -- slapped home
				key(
					0.5,
					Vector3.new(-0.12, 0.212, -0.19),
					Vector3.new(11, 11, -32),
					Enum.EasingStyle.Sine,
					INOUT
				),
				key(
					0.6,
					Vector3.new(-0.07, 0.125, -0.16),
					Vector3.new(6, 10, -16),
					Enum.EasingStyle.Sine,
					INOUT
				),
				-- Pushed out, lifted and turned muzzle-in (like the draw), so the
				-- hand on the charging handle reaches up beside the gun.
				key(
					0.74,
					Vector3.new(-0.05, 0.068, -0.3),
					Vector3.new(9, 16, -9),
					Enum.EasingStyle.Quad,
					OUT
				), -- handle side up
				key(
					0.8,
					Vector3.new(-0.075, 0.058, -0.31),
					Vector3.new(5, 21, -12.5),
					Enum.EasingStyle.Quad,
					OUT
				), -- yanked back
				key(
					0.885,
					Vector3.new(-0.068, 0.062, -0.32),
					Vector3.new(5.5, 20, -11.5),
					Enum.EasingStyle.Sine,
					INOUT
				), -- held
				key(
					0.915,
					Vector3.new(-0.03, 0.095, -0.18),
					Vector3.new(17, 10, -5),
					Enum.EasingStyle.Quad,
					OUT
				), -- let go: the muzzle snaps up
				key(
					0.965,
					Vector3.new(0.008, -0.025, 0.018),
					Vector3.new(-3.5, -1.5, 3),
					Enum.EasingStyle.Quad,
					INOUT
				), -- home, past the hold
				key(1, ZERO, ZERO, Enum.EasingStyle.Sine, INOUT),
			},
		},
	} :: { [string]: Track },
})
