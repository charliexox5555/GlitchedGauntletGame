--!strict
-- The PopCircuit Bat in first person (vault/02 Art/Skins/First-Person Melee
-- Animation.md, rewritten 2026-11-12 after the owner rejected the baked
-- 48 fps version: "the way the arms move looks really off, and the way it
-- spins looks off... it should just be very simple").
--
-- Rules, from the owner and LihFolk (Weapon Swing Design, Timing Spacing and
-- Frame Charts, Procedural Weapon Motion):
--   - The fist is a block: the bat sits RIGID in it at one grip point. It
--     never slides, rolls or turns in the hand (no fingers to do that).
--   - The arm always runs from the fist straight to its shoulder.
--   - A few hand-placed keys per move with spline interpolation (speed
--     carries through each key; how fast comes from the key spacing), plus
--     follow-through springs on the fist and the barrel (no baked samples):
--     windup into the coil, a fast strike, follow-through and a slower settle.
--   - Swings travel on arcs (a middle key), the head of the bat leads.
--   - The toss spins the bat once end over end about its centre of mass on
--     a parabola, the hand waits under it and absorbs the catch.
--
-- Space: the viewmodel frame (camera, bob and sway: root * lowered), studs,
-- +X right, +Y up, -Z forward. The bat model's pivot is its Handle; its axis
-- runs along -Z from the knob (+0.24) to the cap (-2.53).
--
-- `step` returns: the bat's pivot CFrame, the right fist point, the left fist
-- point, whether the right hand holds the bat, whether the left hand holds
-- it, whether the swing trail is on, and whether the move has finished.

local StateValues = require(game:GetService("ReplicatedStorage").Shared.StateValues)

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Bat = {}

Bat.RIGHT_SHOULDER = Vector3.new(1.95, -3.0, 0.55)
Bat.LEFT_SHOULDER = Vector3.new(-1.95, -3.0, 0.55)

local GRIP = 0.27 -- the right fist's centre, this far up the handle from the pivot
local SUPPORT = -0.25 -- the left fist below it, toward the knob (two-handed)
local COM = 1.35 -- the bat's centre of mass, this far up from the pivot
local LEFT_REST = Vector3.new(-1.35, -2.6, -1.0) -- the free fist, low and out of view
-- Follow-through springs (Hz, and the damping ratio: under 1 overshoots).
local FOLLOW = { fist = 11, dir = 8, damping = 0.62, maxLag = math.rad(40) }
-- The bat is never quite still in the hand (2026-11-15: measured 0-1 degrees a
-- second at rest, a frozen hold): a slow roll and lean (degrees) and a lift
-- (studs), `rate` cycles a second, off-ratio so it doesn't repeat. It eases
-- out for a swing (`fade`, 1/s), which has to land where it is keyed.
-- 2026-11-21: the roll and lean now trace an ellipse (sine and cosine of one
-- phase), so the bat never stops turning, plus a small off-ratio turn so it
-- doesn't read as a loop. Off-ratio roll and lean turned round together and
-- the idle sat under 1 degree a second for 0.66 s twice a loop (measured).
local DRIFT = { roll = 3.2, lean = 2.8, turn = 1.2, lift = 0.02, rate = 0.4, fade = 10 }
local drift = 1
-- A hit drags the bat (it slows and eases back, never holding a frame: the
-- dead stop read as choppy, owner 2026-11-15). The drag lasts STOP_SCALE
-- times the knife's stop (the bat is heavier) times STOP_STRETCH, up to
-- STOP_MAX seconds; its speed dips to STOP_FLOOR of normal over the first
-- STOP_INTO share and eases back (as Config/Viewmodel HIT_DRAG).
local STOP_SCALE = 1.4
local STOP_STRETCH = 1.6
local STOP_MAX = 0.3
local STOP_FLOOR = 0.4
local STOP_INTO = 0.22
local springs: {
	ready: boolean?,
	fist: Vector3,
	fistV: Vector3,
	dir: Vector3,
	dirV: Vector3,
} =
	{ fist = Vector3.zero, fistV = Vector3.zero, dir = -Vector3.zAxis, dirV = Vector3.zero }

type Key = {
	t: number, -- 0..1 of the move
	fist: Vector3, -- the right fist
	dir: Vector3, -- where the bat points (knob to cap)
	face: Vector3, -- a hint for which way the bat's face (+Y) turns
	left: Vector3?, -- the left fist, nil = at rest
	support: boolean?, -- the left fist holds the handle
	tension: number?, -- under 1 the move slows through this key (a coil), over 1 carries speed (a strike)
	-- Degrees the bat must stay off the forearm's line at this key (default
	-- BAT_MIN_ANGLE), eased between keys. The two-handed smash lets the bat
	-- run on from the arms at contact, as a two-handed overhead swing does.
	minAngle: number?,
}
type Clip = {
	length: number, -- seconds at speed 1
	loop: boolean?,
	hit: number?, -- contact, 0..1
	trail: { number }?, -- trail on between these, 0..1
	keys: { Key },
	toss: Toss?,
}
-- A toss: the bat leaves the hand at `from`, flies on a parabola to `to`
-- (both 0..1 of the move), spinning `turns` times about its centre of mass.
type Toss = { from: number, to: number, peak: number, turns: number }

local function v(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end

-- The idle: fist low right, the bat standing up and leaning in over the
-- crosshair's right, its face toward you.
local IDLE_FIST = v(1.0, -1.2, -2.05)
local IDLE_DIR = v(0.42, 0.9, -0.3)
local FACE = v(0, 0, 1)

local clips: { [string]: Clip } = {
	Idle = {
		length = 3.2,
		loop = true,
		keys = {
			{ t = 0, fist = IDLE_FIST, dir = IDLE_DIR, face = FACE },
			{
				t = 0.5,
				fist = IDLE_FIST + v(-0.015, 0.03, 0),
				dir = IDLE_DIR + v(-0.02, 0, 0),
				face = FACE,
			},
			{ t = 1, fist = IDLE_FIST, dir = IDLE_DIR, face = FACE },
		},
	},
	-- Forehand (reference: Valorant melee light attack, 2026-11-12 video
	-- study): cocked high on the right, then a diagonal cut down across the
	-- crosshair to low left with the barrel leading flat, wrapping round,
	-- and back. The bat stays across the fist the whole way (BAT_MIN_ANGLE).
	SlashLeft = {
		length = 0.5,
		hit = 0.3,
		trail = { 0.22, 0.44 },
		keys = {
			{ t = 0, fist = IDLE_FIST, dir = IDLE_DIR, face = FACE },
			{
				t = 0.17,
				fist = v(1.3, -0.52, -1.62),
				dir = v(0.416, 0.87, 0.265),
				face = v(-0.87, 0.296, 0.394),
				tension = 0.4,
			},
			{
				t = 0.25,
				fist = v(1, -0.48, -1.9),
				dir = v(0.778, 0.53, -0.337),
				face = v(-0.615, 0.754, -0.233),
			},
			{
				t = 0.3,
				fist = v(0.42, -0.52, -2.05),
				dir = v(-0.251, -0.442, -0.861),
				face = v(-0.438, 0.845, -0.307),
				tension = 1.3,
			},
			{
				t = 0.35,
				fist = v(0.05, -0.8, -2),
				dir = v(-0.687, -0.508, -0.519),
				face = v(-0.372, 0.86, -0.349),
			},
			{
				t = 0.47,
				fist = v(-0.45, -1.15, -1.78),
				dir = v(-0.599, -0.799, -0.05),
				face = v(0.226, -0.229, 0.947),
				tension = 0.45,
			},
			{
				t = 0.66,
				fist = v(0.55, -1.4, -1.9),
				dir = v(0.606, 0.673, -0.424),
				face = v(0.284, 0.315, 0.906),
			},
			{
				t = 0.86,
				fist = IDLE_FIST + v(0.06, 0.03, 0),
				dir = IDLE_DIR + v(0.07, 0, 0),
				face = FACE,
				tension = 0.6,
			},
			{ t = 1, fist = IDLE_FIST, dir = IDLE_DIR, face = FACE },
		},
	},
	-- Backhand: wound low across the body on the left, then a rising cut
	-- back through the crosshair to high right.
	SlashRight = {
		length = 0.5,
		hit = 0.3,
		trail = { 0.22, 0.44 },
		keys = {
			{ t = 0, fist = IDLE_FIST, dir = IDLE_DIR, face = FACE },
			{
				t = 0.21,
				fist = v(-0.12, -1.12, -1.74),
				dir = v(-0.954, -0.179, 0.239),
				face = v(-0.099, 0.944, 0.314),
				tension = 0.4,
			},
			{
				t = 0.262,
				fist = v(0.02, -0.92, -1.98),
				dir = v(-0.53, -0.556, -0.64),
				face = v(-0.48, 0.819, -0.314),
			},
			{
				t = 0.3,
				fist = v(0.3, -0.66, -2.08),
				dir = v(0.544, 0.096, -0.833),
				face = v(-0.007, 0.994, 0.11),
				tension = 1.3,
			},
			{
				t = 0.338,
				fist = v(0.72, -0.55, -1.98),
				dir = v(0.739, 0.502, -0.449),
				face = v(-0.402, 0.864, 0.304),
			},
			{
				t = 0.47,
				fist = v(1.22, -0.55, -1.68),
				dir = v(0.571, 0.809, 0.143),
				face = v(-0.809, 0.525, 0.263),
				tension = 0.45,
			},
			{
				t = 0.66,
				fist = v(1.12, -0.95, -1.9),
				dir = v(0.583, 0.811, -0.046),
				face = v(-0.168, 0.175, 0.97),
			},
			{
				t = 0.86,
				fist = IDLE_FIST + v(-0.04, -0.06, 0),
				dir = IDLE_DIR + v(-0.06, 0, 0),
				face = FACE,
				tension = 0.6,
			},
			{ t = 1, fist = IDLE_FIST, dir = IDLE_DIR, face = FACE },
		},
	},
	-- Heavy: both hands on the handle, the bat raised high behind the head,
	-- a held beat, then straight down the centre line and through.
	-- 2026-11-21 (owner: the heavy "looks like the bat's sideways"): on
	-- contact the bat pointed straight into the screen (0.04 of the screen
	-- long, measured) with its art edge-on (its face on the swing's axis).
	-- Now it comes over the top in the swing's plane with its art toward you,
	-- and on contact runs up the middle of the screen (~0.8 of it) with the
	-- sweet spot on the crosshair; keys ~28 degrees apart through the strike
	-- so the speed peaks on contact, then it brakes past the hold. Both hands
	-- are on it, so it may run on from the arms (minAngle).
	Smash = {
		length = 0.9,
		hit = 0.44,
		trail = { 0.37, 0.54 },
		keys = {
			{ t = 0, fist = IDLE_FIST, dir = IDLE_DIR, face = FACE },
			{
				t = 0.14,
				fist = v(0.42, -0.45, -1.55),
				dir = v(-0.026, 0.927, 0.374),
				face = v(-0.026, -0.374, 0.927),
				left = v(0.3, -0.7, -1.5),
				support = true,
			},
			{
				t = 0.3,
				fist = v(0.38, -0.32, -1.48),
				dir = v(-0.027, 0.857, 0.514),
				face = v(-0.027, -0.514, 0.857),
				left = v(0.25, -0.57, -1.43),
				support = true,
				tension = 0.35,
				minAngle = 45,
			},
			{
				t = 0.37,
				fist = v(0.3, -0.5, -1.72),
				dir = v(-0.006, 0.985, 0.174),
				face = v(-0.006, -0.174, 0.985),
				left = v(0.2, -0.72, -1.65),
				support = true,
				minAngle = 20,
			},
			{
				t = 0.405,
				fist = v(0.2, -0.74, -1.9),
				dir = v(0, 0.961, -0.276),
				face = v(0, 0.276, 0.961),
				left = v(0.12, -0.92, -1.8),
				support = true,
				minAngle = 20,
			},
			{
				t = 0.44,
				fist = v(0.1, -1, -2),
				dir = v(-0.036, 0.719, -0.694),
				face = v(-0.036, 0.694, 0.719),
				left = v(0.05, -1.15, -1.92),
				support = true,
				tension = 1.3,
				minAngle = 20,
			},
			{
				t = 0.475,
				fist = v(0.08, -1.18, -1.98),
				dir = v(-0.083, 0.309, -0.947),
				face = v(-0.083, 0.947, 0.309),
				left = v(0.05, -1.35, -1.9),
				support = true,
				minAngle = 20,
			},
			{
				t = 0.515,
				fist = v(0.1, -1.32, -1.93),
				dir = v(-0.103, -0.174, -0.979),
				face = v(-0.103, 0.979, -0.174),
				left = v(0.08, -1.48, -1.85),
				support = true,
				minAngle = 30,
			},
			{
				t = 0.58,
				fist = v(0.18, -1.45, -1.86),
				dir = v(-0.065, -0.669, -0.74),
				face = v(-0.065, 0.74, -0.669),
				left = v(0.15, -1.62, -1.75),
				support = true,
				tension = 0.45,
				minAngle = 45,
			},
			{
				t = 0.64,
				fist = v(0.24, -1.42, -1.86),
				dir = v(-0.043, -0.788, -0.614),
				face = v(-0.043, 0.614, -0.788),
				left = v(0.2, -1.6, -1.76),
				support = true,
				minAngle = 55,
			},
			{
				t = 0.84,
				fist = IDLE_FIST + v(0.03, 0.07, 0),
				dir = IDLE_DIR + v(0.03, 0, -0.04),
				face = FACE,
				tension = 0.6,
			},
			{ t = 1, fist = IDLE_FIST, dir = IDLE_DIR, face = FACE },
		},
	},
	-- Inspect: turn the bat to show its art, dip, flip it up end over end,
	-- catch it, absorb the weight and settle back to the idle.
	-- Draw (pull-out, owner 2026-11-12): the bat comes up from low right
	-- hanging by the hand, sweeps up and out with the barrel leading, rises a
	-- touch past the idle and settles into it. No 360 twirl (the owner found
	-- the knife's unnatural).
	Draw = {
		length = 0.55,
		keys = {
			{ t = 0, fist = v(1.7, -2.7, -1.3), dir = v(0.25, -0.55, 0.8), face = v(0, 0, 1) },
			{
				t = 0.32,
				fist = v(1.45, -1.55, -1.75),
				dir = v(0.95, 0.35, -0.25),
				face = v(0, 1, 0.3),
			},
			{ t = 0.6, fist = v(1.02, -1.08, -2.05), dir = v(0.32, 1, -0.42), face = FACE },
			{ t = 1, fist = IDLE_FIST, dir = IDLE_DIR, face = FACE },
		},
	},
	Inspect = {
		length = 2.8,
		toss = { from = 0.42, to = 0.68, peak = 1.15, turns = 1 },
		keys = {
			{ t = 0, fist = IDLE_FIST, dir = IDLE_DIR, face = FACE },
			-- Present: bat laid across the view, face to the camera.
			{
				t = 0.14,
				fist = v(0.55, -0.85, -1.75),
				dir = v(-1, 0.35, -0.2),
				face = v(0, 0.2, 1),
			},
			{
				t = 0.3,
				fist = v(0.5, -0.8, -1.75),
				dir = v(-1, 0.2, -0.5),
				face = v(0.3, 0.4, 1),
			},
			-- Dip (anticipation), knob down, bat upright, ready to throw.
			{
				t = 0.38,
				fist = v(0.75, -1.25, -1.75),
				dir = v(0.3, 1, -0.2),
				face = FACE,
			},
			-- Release: the hand flicks up.
			{
				t = 0.42,
				fist = v(0.75, -0.95, -1.8),
				dir = v(0.3, 1, -0.2),
				face = FACE,
			},
			-- The open hand waits under it...
			{
				t = 0.55,
				fist = v(0.78, -1.1, -1.8),
				dir = v(0.3, 1, -0.2),
				face = FACE,
			},
			-- ...and catches it (the toss lands the bat here).
			{
				t = 0.68,
				fist = v(0.78, -0.95, -1.8),
				dir = v(0.3, 1, -0.2),
				face = FACE,
			},
			-- Absorb: the weight pulls the fist down.
			{
				t = 0.76,
				fist = v(0.85, -1.28, -1.8),
				dir = v(0.35, 1, -0.22),
				face = FACE,
			},
			-- ...and it comes back up past the idle (a rebound), then settles.
			{
				t = 0.87,
				fist = IDLE_FIST + v(-0.02, 0.08, 0),
				dir = IDLE_DIR + v(-0.04, 0, 0.02),
				face = FACE,
			},
			{ t = 1, fist = IDLE_FIST, dir = IDLE_DIR, face = FACE },
		},
	},
}

export type Motion = {
	name: string,
	clip: Clip,
	time: number,
	speed: number,
	freeze: number, -- seconds left of a hit's drag: the move plays slower
	freezeFor: number, -- how long that drag is in all
}

function Bat.play(name: string, duration: number?): Motion
	local clip = clips[name] or clips.Idle
	if name == "Draw" then
		springs.ready = false -- a fresh pull-out starts where its first key is
	end
	return {
		name = if clips[name] then name else "Idle",
		clip = clip,
		time = 0,
		speed = if duration and duration > 0 then clip.length / duration else 1,
		freeze = 0,
		freezeFor = 0,
	}
end

-- A hit: the bat is dragged for a moment (the time it eats is not caught up).
function Bat.hitStop(motion: Motion, seconds: number)
	if motion.clip.hit then
		motion.freezeFor = math.clamp(seconds * STOP_SCALE * STOP_STRETCH, 0, STOP_MAX)
		motion.freeze = motion.freezeFor
	end
end

-- Seconds from the start of the move to contact.
function Bat.hitDelay(motion: Motion): number
	return (motion.clip.hit or 1) * motion.clip.length / motion.speed
end

-- The bat's pivot for a fist point and a pointing direction.
local function batAt(fist: Vector3, dir: Vector3, face: Vector3): CFrame
	-- (Guards: a zero or undefined vector into .Unit would give NaN, and a
	-- NaN bat stays NaN in the springs.)
	local look = if dir.Magnitude > 1e-3 then dir.Unit else -Vector3.zAxis
	local up = face - look * face:Dot(look)
	if up.Magnitude < 1e-3 then
		up = Vector3.yAxis - look * look.Y
	end
	if up.Magnitude < 1e-3 then
		up = Vector3.xAxis - look * look.X
	end
	-- lookAt: -Z (the bat's axis) toward `look`, +Y toward `face`.
	local cf = CFrame.lookAt(fist, fist + look, up.Unit)
	return cf * CFrame.new(0, 0, GRIP) -- from the grip point back to the pivot
end

-- `dir` kept at least about BAT_MIN_ANGLE from the forearm's line (fist to
-- shoulder, either way). 2026-11-21: the part along the forearm past the limit
-- is taken off and the rest kept, which is continuous everywhere. The old
-- clamp pushed the bat out along its sideways part, which has no direction
-- on the forearm's line: a swing passing it flipped the bat 113 degrees in
-- one frame (measured). Keys keep clear of the line, so this rarely acts.
local BAT_MIN_ANGLE = math.rad(65)
local function acrossArm(dir: Vector3, fist: Vector3, minAngle: number): Vector3
	local arm = Bat.RIGHT_SHOULDER - fist
	if arm.Magnitude < 1e-3 or dir.Magnitude < 1e-3 then
		return dir
	end
	local a, d = arm.Unit, dir.Unit
	local along = d:Dot(a)
	local limit = math.cos(minAngle)
	if math.abs(along) <= limit then
		return d
	end
	local kept = d - a * (along - math.sign(along) * limit)
	return if kept.Magnitude > 1e-3 then kept.Unit else d
end

-- A key's value for one channel (the free left fist rests when unset).
local function channel(key: Key, name: string): Vector3
	if name == "fist" then
		return key.fist
	elseif name == "dir" then
		return key.dir.Unit
	elseif name == "face" then
		return key.face.Unit
	end
	return key.left or LEFT_REST
end

-- A key's Catmull-Rom tangent (in time), scaled by its tension; zero at the
-- ends of the clip.
local function tangent(keys: { Key }, n: number, name: string, k: number): Vector3
	if k <= 1 or k >= n then
		return Vector3.zero
	end
	local dt = keys[k + 1].t - keys[k - 1].t
	return if dt > 0
		then (channel(keys[k + 1], name) - channel(keys[k - 1], name)) * ((keys[k].tension or 1) / dt)
		else Vector3.zero
end

-- The bat's turn is splined as a rotation, not as two loose vectors
-- (2026-11-21, measured): a pointing vector splined between keys ~160 degrees
-- apart passed near zero length and the bat whipped round in one frame (the
-- backhand's tip jumped at 459 studs/s), and a face vector crossing the bat's
-- axis rolled it 180 degrees in one frame (the forehand). Each key's (dir,
-- face) becomes one orientation; the curve between keys is a Bezier on
-- rotations with Catmull-Rom angular tangents (Util/RuinedReaver's scheme).
local function orientation(key: Key): CFrame
	local look = channel(key, "dir")
	local face = channel(key, "face")
	local up = face - look * face:Dot(look)
	if up.Magnitude < 1e-3 then
		up = Vector3.yAxis - look * look.Y
	end
	return CFrame.lookAt(Vector3.zero, look, up.Unit)
end

local function rotationVector(relative: CFrame): Vector3
	local axis, angle = relative:ToAxisAngle()
	return axis * angle
end

local function turned(base: CFrame, spin: Vector3, time: number): CFrame
	return if spin.Magnitude > 1e-5
		then base * CFrame.fromAxisAngle(spin.Unit, spin.Magnitude * time)
		else base
end

type Turn = { from: CFrame, exit: CFrame, entry: CFrame, to: CFrame }
local turns: { [Clip]: { Turn } } = {}

local function turnsOf(clip: Clip): { Turn }
	local cached = turns[clip]
	if cached then
		return cached
	end
	local keys = clip.keys
	local n = #keys
	local poses: { CFrame } = {}
	for k, key in keys do
		poses[k] = orientation(key)
	end
	local function spin(k: number): Vector3
		if k <= 1 or k >= n then
			return Vector3.zero
		end
		local dt = keys[k + 1].t - keys[k - 1].t
		if dt <= 0 then
			return Vector3.zero
		end
		local ahead = rotationVector(poses[k]:ToObjectSpace(poses[k + 1]))
		local behind = rotationVector(poses[k]:ToObjectSpace(poses[k - 1]))
		return (ahead - behind) * ((keys[k].tension or 1) / dt)
	end
	local list: { Turn } = {}
	for k = 1, n - 1 do
		local third = (keys[k + 1].t - keys[k].t) / 3
		list[k] = {
			from = poses[k],
			exit = turned(poses[k], spin(k), third),
			entry = turned(poses[k + 1], spin(k + 1), -third),
			to = poses[k + 1],
		}
	end
	turns[clip] = list
	return list
end

local function orientationAt(clip: Clip, u: number): CFrame
	local keys = clip.keys
	local list = turnsOf(clip)
	local i = #keys - 1
	for k = 1, #keys - 1 do
		if u <= keys[k + 1].t then
			i = k
			break
		end
	end
	local h = keys[i + 1].t - keys[i].t
	local s = if h > 0 then math.clamp((u - keys[i].t) / h, 0, 1) else 1
	local turn = list[i]
	local middle = turn.exit:Lerp(turn.entry, s)
	return turn.from
		:Lerp(turn.exit, s)
		:Lerp(middle, s)
		:Lerp(middle:Lerp(turn.entry:Lerp(turn.to, s), s), s)
end

-- Spline interpolation through the keys (cubic Hermite with Catmull-Rom
-- tangents in time, the "auto" tangents of an animation editor): speed
-- carries through every key instead of stopping at it (2026-11-12, owner:
-- "less robotic"; per-segment easing came to rest at each key). How fast
-- the bat moves comes from how close the keys are. A one-shot starts and
-- ends at rest (zero tangents at its ends, which match the idle); a loop
-- wraps.
local function spline(clip: Clip, name: string, u: number): Vector3
	local keys = clip.keys
	local n = #keys
	local i = n - 1
	for k = 1, n - 1 do
		if u <= keys[k + 1].t then
			i = k
			break
		end
	end
	local a, b = keys[i], keys[i + 1]
	local h = b.t - a.t
	if h <= 0 then
		return channel(b, name)
	end
	local s = math.clamp((u - a.t) / h, 0, 1)
	local s2, s3 = s * s, s * s * s
	return channel(a, name) * (2 * s3 - 3 * s2 + 1)
		+ tangent(keys, n, name, i) * (h * (s3 - 2 * s2 + s))
		+ channel(b, name) * (-2 * s3 + 3 * s2)
		+ tangent(keys, n, name, i + 1) * (h * (s3 - s2))
end

-- Whether the left fist holds the handle at u (true while both keys around
-- u say so, or the nearer one does).
local function supportAt(clip: Clip, u: number): boolean
	local keys = clip.keys
	for k = 1, #keys - 1 do
		local a, b = keys[k], keys[k + 1]
		if u <= b.t then
			local mid = (a.t + b.t) / 2
			return (a.support == true and b.support == true)
				or (a.support == true and u < mid)
				or (b.support == true and u >= mid)
		end
	end
	return keys[#keys].support == true
end

-- The bat's least angle off the forearm at u (radians): each key's minAngle
-- (BAT_MIN_ANGLE where unset), eased between keys, so it never jumps.
local function minAngleAt(clip: Clip, u: number): number
	local keys = clip.keys
	local function at(k: Key): number
		return if k.minAngle then math.rad(k.minAngle) else BAT_MIN_ANGLE
	end
	for k = 1, #keys - 1 do
		local a, b = keys[k], keys[k + 1]
		if u <= b.t then
			local span = b.t - a.t
			local s = if span > 0 then math.clamp((u - a.t) / span, 0, 1) else 1
			s = s * s * (3 - 2 * s)
			return at(a) + (at(b) - at(a)) * s
		end
	end
	return at(keys[#keys])
end

-- The pose of a clip at u (0..1): the bat, the right fist, the left fist,
-- whether the left holds.
local function sample(clip: Clip, u: number): (CFrame, Vector3, Vector3, boolean)
	local fist = spline(clip, "fist", u)
	-- The fist IS the grip point while held: no sliding. The bat stays
	-- across the fist: never closer than BAT_MIN_ANGLE to the forearm's line,
	-- so the handle never runs along the arm (that read as "weird angles").
	local turn = orientationAt(clip, u)
	local dir = acrossArm(turn.LookVector, fist, minAngleAt(clip, u))
	local bat = batAt(fist, dir, turn.UpVector)
	local support = supportAt(clip, u)
	local left = if support
		then bat:PointToWorldSpace(Vector3.new(0, 0, -SUPPORT))
		else spline(clip, "left", u)
	return bat, fist, left, support
end

local tossEnds: { [Clip]: { CFrame } } = {}

-- One follow-through spring step (`f` Hz, damping `z`) over `step` seconds,
-- integrated in sub-steps of at most 1/240 s: one 60 fps step at 11 Hz
-- overshoots more every frame and the bat flew off (measured).
local function spring(
	x: Vector3,
	vel: Vector3,
	target: Vector3,
	f: number,
	z: number,
	step: number
): (Vector3, Vector3)
	local w = 2 * math.pi * f
	local n = math.max(1, math.ceil(step * 240))
	local h = step / n
	for _ = 1, n do
		vel += (target - x) * (w * w * h) - vel * (2 * z * w * h)
		x += vel * h
	end
	return x, vel
end

local function tossPose(clip: Clip, toss: Toss, u: number): CFrame?
	if u <= toss.from or u >= toss.to then
		return nil
	end
	-- Release and catch poses: the bat in the fist at each end (fixed per
	-- clip, so worked out once).
	local ends = tossEnds[clip]
	if not ends then
		ends = { (sample(clip, toss.from)), (sample(clip, toss.to)) }
		tossEnds[clip] = ends
	end
	local release, catch = ends[1], ends[2]
	local comLocal = Vector3.new(0, 0, -COM)
	local p0 = release:PointToWorldSpace(comLocal)
	local p1 = catch:PointToWorldSpace(comLocal)
	local s = (u - toss.from) / (toss.to - toss.from)
	-- A parabola through both ends with its top `peak` above the higher one.
	local base = p0:Lerp(p1, s)
	local height = toss.peak * 4 * s * (1 - s)
	local com = base + Vector3.new(0, height, 0)
	-- Spin end over end about the bat's own face axis (X), constant speed,
	-- from the release orientation to the catch one plus whole turns.
	local spin = CFrame.Angles(-2 * math.pi * toss.turns * s, 0, 0)
	local rot = release.Rotation:Lerp(catch.Rotation, s) * spin
	return CFrame.new(com) * rot * CFrame.new(-comLocal)
end

function Bat.step(
	motion: Motion,
	dt: number
): (CFrame, Vector3, Vector3, boolean, boolean, boolean, boolean)
	if motion.freeze > 0 and motion.freezeFor > 0 then
		-- A hit's drag: everything slows (the springs included) and eases back.
		local k = math.clamp(1 - motion.freeze / motion.freezeFor, 0, 1)
		local dip = if k < STOP_INTO then k / STOP_INTO else 1 - (k - STOP_INTO) / (1 - STOP_INTO)
		dip = dip * dip * (3 - 2 * dip)
		motion.freeze -= dt
		dt *= 1 - (1 - STOP_FLOOR) * dip
	end
	motion.time += dt * motion.speed
	local clip = motion.clip
	local u = motion.time / clip.length
	-- Studio review: Workspace DevBatScrub (0..1) holds the move at that point.
	if RunService:IsStudio() then
		local scrub = StateValues.get(Workspace, "DevBatScrub")
		if typeof(scrub) == "number" then
			u = math.clamp(scrub, 0, 1)
			motion.time = u * clip.length
		end
	end
	local done = false
	if clip.loop then
		u %= 1
	elseif u >= 1 then
		u = 1
		done = true
	end
	local bat, fist, left, support = sample(clip, u)
	-- The drift (DRIFT): on the keyed pose, so the springs carry it.
	drift += ((if clip.hit then 0 else 1) - drift) * (1 - math.exp(-DRIFT.fade * dt))
	local aim = bat.LookVector
	if drift > 1e-3 then
		local a = os.clock() * DRIFT.rate * 2 * math.pi
		aim = CFrame.Angles(
			math.rad(DRIFT.lean) * math.cos(a) * drift,
			math.rad(DRIFT.turn) * math.sin(a * 1.3 + 2) * drift,
			math.rad(DRIFT.roll) * math.sin(a) * drift
		):VectorToWorldSpace(aim)
		fist += Vector3.new(0, math.sin(a * 0.5) * DRIFT.lift * drift, 0)
	end
	-- Follow-through: the fist lags its key a touch and the barrel trails
	-- the hand (two springs, slightly under-damped), so a swing overshoots
	-- and settles instead of stopping dead. The bat stays rigid in the fist.
	local s = springs
	local step = math.min(dt, 1 / 30)
	-- (A NaN never compares equal to itself: start the springs over.)
	if s.fist ~= s.fist or s.dir ~= s.dir or s.fistV ~= s.fistV or s.dirV ~= s.dirV then
		s.ready = false
	end
	if not s.ready then
		s.fist, s.fistV, s.dir, s.dirV, s.ready = fist, Vector3.zero, aim, Vector3.zero, true
	end
	s.fist, s.fistV = spring(s.fist, s.fistV, fist, FOLLOW.fist, FOLLOW.damping, step)
	s.dir, s.dirV = spring(s.dir, s.dirV, aim, FOLLOW.dir, FOLLOW.damping, step)
	-- Keep the trailing direction a unit vector at most FOLLOW.maxLag behind
	-- the key: a swing that reverses the bat (the smash: up-back to
	-- forward-down) pulled a plain vector spring through zero length, and
	-- the bat jumped 1,272 studs for a frame (measured 2026-11-12).
	local target = aim
	if s.dir.Magnitude < 1e-3 then
		s.dir, s.dirV = target, Vector3.zero
	else
		s.dir = s.dir.Unit
		local behind = math.acos(math.clamp(s.dir:Dot(target), -1, 1))
		if behind > FOLLOW.maxLag then
			s.dir = target:Lerp(s.dir, FOLLOW.maxLag / behind).Unit
		end
	end
	fist = s.fist
	bat = batAt(fist, s.dir, bat.UpVector)
	if support then
		left = bat:PointToWorldSpace(Vector3.new(0, 0, -SUPPORT))
	end
	local held = true
	if clip.toss then
		local flying = tossPose(clip, clip.toss, u)
		if flying then
			bat = flying
			held = false
			-- The spring follows the flying bat so the catch is seamless.
			s.dir, s.dirV = flying.LookVector, Vector3.zero
		end
	end
	local trail = clip.trail ~= nil and u >= clip.trail[1] and u < clip.trail[2]
	return bat, fist, left, held, support, trail, done
end

return Bat
