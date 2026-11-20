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
local DRIFT = { roll = 3.2, lean = 2, lift = 0.02, rate = 0.31, fade = 10 }
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
		trail = { 0.18, 0.42 },
		keys = {
			{ t = 0, fist = IDLE_FIST, dir = IDLE_DIR, face = FACE },
			{ t = 0.17, fist = v(1.3, -0.55, -1.6), dir = v(0.35, 1, -0.05), face = v(-1, 0, 0.3) },
			{
				t = 0.3,
				fist = v(0.35, -0.72, -2.05),
				dir = v(-1, 0.12, -0.35),
				face = v(0, 1, 0.2),
			},
			{
				t = 0.44,
				fist = v(-0.6, -1.25, -1.7),
				dir = v(-0.75, -0.45, 0.35),
				face = v(0.2, 1, 0),
			},
			-- Home a little past the idle (it came from the left), then back.
			{
				t = 0.82,
				fist = IDLE_FIST + v(0.06, 0.03, 0),
				dir = IDLE_DIR + v(0.07, 0, 0),
				face = FACE,
			},
			{ t = 1, fist = IDLE_FIST, dir = IDLE_DIR, face = FACE },
		},
	},
	-- Backhand: wound low across the body on the left, then a rising cut
	-- back through the crosshair to high right.
	SlashRight = {
		length = 0.5,
		hit = 0.3,
		trail = { 0.18, 0.42 },
		keys = {
			{ t = 0, fist = IDLE_FIST, dir = IDLE_DIR, face = FACE },
			{
				t = 0.17,
				fist = v(-0.35, -1.3, -1.65),
				dir = v(-0.9, -0.25, 0.15),
				face = v(0, 1, 0.3),
			},
			{ t = 0.3, fist = v(0.2, -0.75, -2.05), dir = v(1, 0.2, -0.35), face = v(0, 1, 0.2) },
			{ t = 0.44, fist = v(1.2, -0.6, -1.65), dir = v(0.55, 0.8, 0.2), face = v(-1, 0.2, 0) },
			-- Home a little past the idle (it came from up on the right), then back.
			{
				t = 0.82,
				fist = IDLE_FIST + v(-0.04, -0.06, 0),
				dir = IDLE_DIR + v(-0.06, 0, 0),
				face = FACE,
			},
			{ t = 1, fist = IDLE_FIST, dir = IDLE_DIR, face = FACE },
		},
	},
	-- Heavy: both hands on the handle, the bat raised high behind the head,
	-- a held beat, then straight down the centre line and through.
	Smash = {
		length = 0.9,
		hit = 0.44,
		trail = { 0.34, 0.52 },
		keys = {
			{ t = 0, fist = IDLE_FIST, dir = IDLE_DIR, face = FACE },
			{
				t = 0.14,
				fist = v(0.4, -0.45, -1.55),
				dir = v(0.05, 0.95, 0.3),
				face = v(1, 0, 0),
				left = v(0.3, -0.7, -1.5),
				support = true,
			},
			{
				t = 0.3,
				fist = v(0.38, -0.3, -1.5),
				dir = v(0.05, 0.9, 0.42),
				face = v(1, 0, 0),
				left = v(0.25, -0.55, -1.45),
				support = true,
			},
			{
				t = 0.44,
				fist = v(0.2, -1.0, -2.1),
				dir = v(-0.05, -0.1, -1),
				face = v(1, 0, 0),
				left = v(0.15, -1.15, -2.0),
				support = true,
			},
			{
				t = 0.56,
				fist = v(0.2, -1.45, -1.9),
				dir = v(-0.05, -0.85, -0.55),
				face = v(1, 0, 0),
				left = v(0.15, -1.6, -1.75),
				support = true,
			},
			-- Up out of the smash a little past the idle, then back.
			{
				t = 0.86,
				fist = IDLE_FIST + v(0.03, 0.07, 0),
				dir = IDLE_DIR + v(0.03, 0, -0.04),
				face = FACE,
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

-- `dir` turned (in the plane it makes with the forearm) until it is at least
-- BAT_MIN_ANGLE from the forearm's line (fist to shoulder, either way).
local BAT_MIN_ANGLE = math.rad(65)
local function acrossArm(dir: Vector3, fist: Vector3): Vector3
	local arm = Bat.RIGHT_SHOULDER - fist
	if arm.Magnitude < 1e-3 or dir.Magnitude < 1e-3 then
		return dir
	end
	local a, d = arm.Unit, dir.Unit
	local along = d:Dot(a)
	local limit = math.cos(BAT_MIN_ANGLE)
	if math.abs(along) <= limit then
		return d
	end
	local side = d - a * along
	if side.Magnitude < 1e-3 then
		side = a:Cross(Vector3.xAxis)
		if side.Magnitude < 1e-3 then
			side = a:Cross(Vector3.yAxis)
		end
	end
	local sign = if along > 0 then 1 else -1
	return (a * (sign * limit) + side.Unit * math.sin(BAT_MIN_ANGLE)).Unit
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

-- A key's Catmull-Rom tangent (in time); zero at the ends of the clip.
local function tangent(keys: { Key }, n: number, name: string, k: number): Vector3
	if k <= 1 or k >= n then
		return Vector3.zero
	end
	local dt = keys[k + 1].t - keys[k - 1].t
	return if dt > 0
		then (channel(keys[k + 1], name) - channel(keys[k - 1], name)) / dt
		else Vector3.zero
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

-- The pose of a clip at u (0..1): the bat, the right fist, the left fist,
-- whether the left holds.
local function sample(clip: Clip, u: number): (CFrame, Vector3, Vector3, boolean)
	local fist = spline(clip, "fist", u)
	-- The fist IS the grip point while held: no sliding. The bat stays
	-- across the fist: never closer than BAT_MIN_ANGLE to the forearm's line,
	-- so the handle never runs along the arm (that read as "weird angles").
	local dir = acrossArm(spline(clip, "dir", u), fist)
	local bat = batAt(fist, dir, spline(clip, "face", u))
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
			math.rad(DRIFT.lean) * math.sin(a * 0.7 + 1) * drift,
			0,
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
