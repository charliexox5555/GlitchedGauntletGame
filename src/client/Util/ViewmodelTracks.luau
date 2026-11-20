--!strict
-- Keyframed viewmodel tracks (Config/Viewmodel TRACKS): the moves played on
-- top of the gun's hold pose (equip, draw, reload, inspect, melee swings).
-- Owns sampling a track, the set of tracks playing by slot (start, fade out,
-- step, the hit-stop freeze) and their combined offset for one gun. The set
-- itself belongs to ViewmodelController; every function here takes it.
-- Also the small rig math the controller shares (degree angles, mirroring
-- for the left gun of an akimbo pair).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Ease = require(ReplicatedStorage.Shared.Util.Ease)
local Types = require(ReplicatedStorage.Shared.Types)
local VM = require(ReplicatedStorage.Shared.Config.Viewmodel)

local ViewmodelMotion = require(script.Parent.ViewmodelMotion)

-- `rotScale`: how much of the track's rotation applies (0 = position only, when a
-- gun clip of the same move already turns the gun).
export type Playing = {
	track: VM.Track,
	time: number,
	length: number,
	weight: number,
	fading: boolean,
	rotScale: number,
	freeze: number, -- seconds left of a hit's drag (VM.HIT_DRAG): the track plays slower
	freezeFor: number, -- how long that drag is in all
	-- Where the slot's last move was when this one cut in (screen tracks): the
	-- offset blends from it over VM.TRACK_BLEND instead of snapping.
	blendFrom: CFrame?,
	-- A screen track's spring follower (VM.SCREEN_FOLLOW): where the knife is
	-- drawn, chasing the keyed pose. Handed on when a move cuts into another.
	follow: Follow?,
}

type Follow = {
	pos: Vector3,
	vel: Vector3, -- studs/s
	rot: CFrame,
	spin: Vector3, -- radians/s, in `rot`'s own frame
	at: number, -- the track time it was last stepped at
}

-- The tracks playing, by slot ("Equip", "Reload", "Inspect", "Swing").
export type Set = { [string]: Playing }

local ViewmodelTracks = {}

local DEG = math.pi / 180
local studio = RunService:IsStudio()

-- Rig math -----------------------------------------------------------------------

-- Degrees (X, Y, Z) to a rotation.
function ViewmodelTracks.angles(rot: Vector3): CFrame
	return CFrame.Angles(rot.X * DEG, rot.Y * DEG, rot.Z * DEG)
end

-- Reflects a camera-space offset across the screen's vertical axis (left gun).
function ViewmodelTracks.mirrorPos(v: Vector3): Vector3
	return Vector3.new(-v.X, v.Y, v.Z)
end

function ViewmodelTracks.mirrorRot(v: Vector3): Vector3
	return Vector3.new(v.X, -v.Y, -v.Z)
end

local angles = ViewmodelTracks.angles
local mirrorPos = ViewmodelTracks.mirrorPos
local mirrorRot = ViewmodelTracks.mirrorRot

local function aroundPivot(pivot: Vector3, cf: CFrame): CFrame
	return CFrame.new(pivot) * cf * CFrame.new(-pivot)
end

-- Playing --------------------------------------------------------------------------

-- `smooth` tracks in the gun's own axes (the gun draws, 2026-11-14): the same
-- spline as sampleSmooth below, on the offset and on the degree angles key by
-- key (their turns are small), with the velocity carried through each key.
-- The velocity at a key, per axis (Fritsch-Butland, the monotone "PCHIP"
-- cubic; LihFolk Timing Spacing and Frame Charts): a weighted harmonic mean of
-- the two segments' speeds, zero where they turn back. A move out of a held
-- pose starts from rest and accelerates; a fast move brakes into the next
-- hold; nothing drifts past a key (overshoot is keyed, not accidental).
local function pchip(a: number, b: number, c: number, da: number, db: number): number
	local sa, sb = (b - a) / da, (c - b) / db
	if sa * sb <= 0 then
		return 0
	end
	return 3 * (da + db) / ((2 * db + da) / sa + (db + 2 * da) / sb)
end

local function through(a: Vector3, b: Vector3, c: Vector3, da: number, db: number): Vector3
	return Vector3.new(
		pchip(a.X, b.X, c.X, da, db),
		pchip(a.Y, b.Y, c.Y, da, db),
		pchip(a.Z, b.Z, c.Z, da, db)
	)
end

type EulerSmooth = { vel: { Vector3 }, spin: { Vector3 } }
local eulerCache: { [VM.Track]: EulerSmooth } = setmetatable({}, { __mode = "k" }) :: any

local function eulerSmoothOf(track: VM.Track): EulerSmooth
	local cached = eulerCache[track]
	if cached then
		return cached
	end
	local keys = track.keys
	local n = #keys
	local vel, spin = table.create(n, Vector3.zero), table.create(n, Vector3.zero)
	for i = 2, n - 1 do
		local da, db = keys[i].t - keys[i - 1].t, keys[i + 1].t - keys[i].t
		if da > 1e-6 and db > 1e-6 then
			vel[i] = through(keys[i - 1].pos, keys[i].pos, keys[i + 1].pos, da, db)
			spin[i] = through(keys[i - 1].rot, keys[i].rot, keys[i + 1].rot, da, db)
		end
	end
	local made = { vel = vel, spin = spin }
	eulerCache[track] = made
	return made
end

local function sample(track: VM.Track, t: number): (Vector3, Vector3)
	local keys = track.keys
	if track.smooth then
		local n = #keys
		if t <= keys[1].t then
			return keys[1].pos, keys[1].rot
		end
		if t >= keys[n].t then
			return keys[n].pos, keys[n].rot
		end
		local i = 1
		while i < n - 1 and t > keys[i + 1].t do
			i += 1
		end
		local a, b = keys[i], keys[i + 1]
		local span = b.t - a.t
		if span <= 1e-6 then
			return b.pos, b.rot
		end
		local s = eulerSmoothOf(track)
		local u = (t - a.t) / span
		local u2, u3 = u * u, u * u * u
		local h10, h01, h11 = u3 - 2 * u2 + u, -2 * u3 + 3 * u2, u3 - u2
		local h00 = 1 - h01
		local pos = a.pos * h00
			+ s.vel[i] * (span * h10)
			+ b.pos * h01
			+ s.vel[i + 1] * (span * h11)
		local rot = a.rot * h00
			+ s.spin[i] * (span * h10)
			+ b.rot * h01
			+ s.spin[i + 1] * (span * h11)
		return pos, rot
	end
	local prev = keys[1]
	if t <= prev.t then
		return prev.pos, prev.rot
	end
	for i = 2, #keys do
		local k = keys[i]
		if t <= k.t then
			local span = k.t - prev.t
			local a = if span > 0 then (t - prev.t) / span else 1
			a = TweenService:GetValue(
				a,
				k.style or Enum.EasingStyle.Sine,
				k.dir or Enum.EasingDirection.InOut
			)
			return prev.pos:Lerp(k.pos, a), prev.rot:Lerp(k.rot, a)
		end
		prev = k
	end
	return prev.pos, prev.rot
end

-- (Defined below, with the screen-track spline.)
local sampleKeys: (track: VM.Track, t: number) -> CFrame

-- Starts TRACKS[`trackName`] in `slot` (replacing what played there),
-- stretched to `duration` when given.
function ViewmodelTracks.play(
	playing: Set,
	slot: string,
	trackName: string,
	duration: number?,
	rotScale: number?
)
	local track = VM.TRACKS[trackName]
	if not track then
		return
	end
	-- A move cut in while another still plays in this slot (a slash straight
	-- after a heavy): start from where the old one is (2026-11-14, owner:
	-- "a hesitation"; research: inertialization, Gears of War GDC).
	local old = playing[slot]
	local blendFrom: CFrame? = nil
	local follow: Follow? = nil
	if old and old.track.screen and track.screen and not old.fading then
		blendFrom = sampleKeys(old.track, math.clamp(old.time / old.length, 0, 1))
		-- ...and keep the spring follower, with the speed it had.
		follow = old.follow
		if follow then
			follow.at = 0
		end
	end
	playing[slot] = {
		track = track,
		time = 0,
		length = if duration and duration > 0 then duration else track.length,
		weight = 1,
		fading = false,
		rotScale = rotScale or 1,
		freeze = 0,
		freezeFor = 0,
		blendFrom = blendFrom,
		follow = follow,
	}
end

-- Blends `slot` out over CANCEL_TIME (a cancelled reload or inspect).
function ViewmodelTracks.fade(playing: Set, slot: string)
	local p = playing[slot]
	if p then
		p.fading = true
	end
end

function ViewmodelTracks.step(playing: Set, dt: number)
	for slot, p in playing do
		local rate = 1
		if p.freeze > 0 and not p.fading then
			-- A hit drags the move (it slows and eases back; the time it eats
			-- is not caught up). It never holds a frame.
			rate = ViewmodelMotion.dragRate(p.freeze, p.freezeFor)
			p.freeze -= dt
		end
		p.time += dt * rate
		if p.fading then
			p.weight -= dt / VM.CANCEL_TIME
			if p.weight <= 0 then
				playing[slot] = nil
			end
		elseif p.time >= p.length then
			playing[slot] = nil
		end
	end
end

-- A gun's extra lift for one track slot (config.trackLift, e.g. a bullpup
-- raised so its reload shows), eased in and out over the track's ends.
local LIFT_EASE = 0.15
local function liftFor(weapon: Types.WeaponConfig?, slot: string, t: number): (Vector3, Vector3)
	local lifts = weapon and weapon.trackLift
	local lift = lifts and lifts[slot]
	-- Studio only: Workspace VmLift<slot> (Vector3) tunes it live.
	local live = if studio then StateValues.get(Workspace, "VmLift" .. slot) else nil
	if typeof(live) == "Vector3" then
		lift = { pos = live, rot = if lift then lift.rot else nil }
	end
	if not lift then
		return Vector3.zero, Vector3.zero
	end
	local e = Ease.smooth(math.clamp(math.min(t, 1 - t) / LIFT_EASE, 0, 1))
	return lift.pos * e, (lift.rot or Vector3.zero) * e
end

-- Track slots akimbo guns take turns on (ViewmodelController playTurns).
local TURN_SLOTS = { Equip = true, Reload = true, Inspect = true }

-- `smooth` tracks (2026-11-14, owner: "smoother... not a complete linear
-- animation"): a cubic Hermite spline through the keys with the velocity
-- carried through each one (LihFolk Timing Spacing and Frame Charts: chains
-- of per-key easing stop dead at every key, linear ones turn corners). The
-- velocity at a key is the time-weighted mean of the two segments' (zero at
-- the first and last key and at a hold, where two keys match), for the
-- position and for the turn (as rotation vectors). Per-key easing styles are
-- ignored: the keys' spacing in time is the timing.
type Smooth = {
	times: { number },
	cfs: { CFrame },
	vel: { Vector3 }, -- studs per unit t
	spin: { Vector3 }, -- radians per unit t, in the key's own frame
}
local smoothCache: { [VM.Track]: Smooth } = setmetatable({}, { __mode = "k" }) :: any

local function rotationVector(cf: CFrame): Vector3
	local axis, angle = cf:ToAxisAngle()
	if angle ~= angle or math.abs(angle) < 1e-6 then
		return Vector3.zero
	end
	return axis * angle
end

local function fromRotationVector(v: Vector3): CFrame
	local angle = v.Magnitude
	if angle < 1e-6 then
		return CFrame.identity
	end
	return CFrame.fromAxisAngle(v / angle, angle)
end

local function smoothOf(track: VM.Track): Smooth
	local cached = smoothCache[track]
	if cached then
		return cached
	end
	local keys = track.keys
	local n = #keys
	local times, cfs, vel, spin = table.create(n), table.create(n), table.create(n), table.create(n)
	for i, k in keys do
		times[i] = k.t
		cfs[i] = CFrame.new(k.pos) * ViewmodelTracks.angles(k.rot)
	end
	for i = 1, n do
		vel[i], spin[i] = Vector3.zero, Vector3.zero
		if i > 1 and i < n then
			local da, db = times[i] - times[i - 1], times[i + 1] - times[i]
			if da > 1e-6 and db > 1e-6 then
				vel[i] = through(cfs[i - 1].Position, cfs[i].Position, cfs[i + 1].Position, da, db)
				-- The turn as rotation vectors in the key's own frame: the turn in
				-- from the last key (negated: from here back) and out to the next.
				local back = -rotationVector(cfs[i - 1].Rotation:Inverse() * cfs[i].Rotation)
				local fwd = rotationVector(cfs[i].Rotation:Inverse() * cfs[i + 1].Rotation)
				spin[i] = through(back, Vector3.zero, fwd, da, db)
			end
		end
	end
	local made: Smooth = { times = times, cfs = cfs, vel = vel, spin = spin }
	smoothCache[track] = made
	return made
end

local function sampleSmooth(track: VM.Track, t: number): CFrame
	local s = smoothOf(track)
	local times, n = s.times, #s.times
	if t <= times[1] then
		return s.cfs[1]
	end
	if t >= times[n] then
		return s.cfs[n]
	end
	local i = 1
	while i < n - 1 and t > times[i + 1] do
		i += 1
	end
	local span = times[i + 1] - times[i]
	if span <= 1e-6 then
		return s.cfs[i + 1]
	end
	local u = (t - times[i]) / span
	local u2, u3 = u * u, u * u * u
	local h10, h01, h11 = u3 - 2 * u2 + u, -2 * u3 + 3 * u2, u3 - u2
	local h00 = 1 - h01
	local a, b = s.cfs[i], s.cfs[i + 1]
	local pos = a.Position * h00
		+ s.vel[i] * (span * h10)
		+ b.Position * h01
		+ s.vel[i + 1] * (span * h11)
	local turn = rotationVector(a.Rotation:Inverse() * b.Rotation)
	local r = s.spin[i] * (span * h10) + turn * h01 + s.spin[i + 1] * (span * h11)
	return CFrame.new(pos) * a.Rotation * fromRotationVector(r)
end

-- The knife thrown out of the fist and caught (Config/Viewmodel Track `toss`,
-- 2026-11-14, owner: "it throws the knife up, catches it, spins it"): the
-- toss keys (the knife's own handle space, turns in degrees about `tossPivot`)
-- of the first playing track that has them. The arms stay on the fist.
local tossTracks: { [VM.Track]: VM.Track } = setmetatable({}, { __mode = "k" }) :: any

function ViewmodelTracks.toss(playing: Set): CFrame?
	for _, p in playing do
		local track = p.track
		local keys = track.toss
		if keys and not p.fading then
			local t = math.clamp(p.time / p.length, 0, 1)
			local tossTrack = tossTracks[track]
			if not tossTrack then
				tossTrack =
					{ length = track.length, pivot = "Grip", keys = keys, smooth = true } :: VM.Track
				tossTracks[track] = tossTrack
			end
			local pos, rot = sample(tossTrack, t)
			if pos.Magnitude < 1e-4 and rot.Magnitude < 1e-3 then
				return nil
			end
			local pivot = CFrame.new(track.tossPivot or Vector3.zero)
			return CFrame.new(pos) * pivot * ViewmodelTracks.angles(rot) * pivot:Inverse()
		end
	end
	return nil
end

-- A `screen` track's offset at `t`: each key as a CFrame, eased between them
-- with CFrame:Lerp, so the turn takes the shortest way (a slerp).
function sampleKeys(track: VM.Track, t: number): CFrame
	if track.smooth then
		return sampleSmooth(track, t)
	end
	local keys = track.keys
	local prev = keys[1]
	local function at(k: VM.Key): CFrame
		return CFrame.new(k.pos) * angles(k.rot)
	end
	if t <= prev.t then
		return at(prev)
	end
	for i = 2, #keys do
		local k = keys[i]
		if t <= k.t then
			local span = k.t - prev.t
			local a = if span > 0 then (t - prev.t) / span else 1
			a = TweenService:GetValue(
				a,
				k.style or Enum.EasingStyle.Sine,
				k.dir or Enum.EasingDirection.InOut
			)
			return at(prev):Lerp(at(k), a)
		end
		prev = k
	end
	return at(prev)
end

-- A screen track's pose through its spring follower (VM.SCREEN_FOLLOW):
-- `target` is the keyed pose this frame, `weight` how much of the follower
-- shows (0 = the keys exactly). Stepped once per frame, by how far the
-- track's own time moved (so a hit-stop or a frozen review holds it too).
local TAU = 2 * math.pi
local FOLLOW = VM.SCREEN_FOLLOW

local function followed(p: Playing, target: CFrame, weight: number): CFrame
	local f = p.follow
	if not f then
		local new: Follow = {
			pos = target.Position,
			vel = Vector3.zero,
			rot = target.Rotation,
			spin = Vector3.zero,
			at = p.time,
		}
		f = new
		p.follow = new
	elseif f.at ~= p.time then
		local dt = math.clamp(p.time - f.at, 0, 0.1)
		f.at = p.time
		-- Position: an exact step of the spring toward the target, per axis.
		local omega = FOLLOW.frequency * TAU
		local d = f.pos - target.Position
		local x, vx = ViewmodelMotion.bounce(d.X, f.vel.X, omega, FOLLOW.damping, dt)
		local y, vy = ViewmodelMotion.bounce(d.Y, f.vel.Y, omega, FOLLOW.damping, dt)
		local z, vz = ViewmodelMotion.bounce(d.Z, f.vel.Z, omega, FOLLOW.damping, dt)
		f.pos = target.Position + Vector3.new(x, y, z)
		f.vel = Vector3.new(vx, vy, vz)
		-- Turn: the same spring on the rotation between the two, in small
		-- steps (it is not linear, and a slow frame must not blow it up).
		local turn = FOLLOW.turnFrequency * TAU
		local steps = math.max(math.ceil(dt * turn / 0.35), 1)
		local h = dt / steps
		for _ = 1, steps do
			local off = rotationVector(f.rot:Inverse() * target.Rotation)
			f.spin += (off * (turn * turn) - f.spin * (2 * FOLLOW.turnDamping * turn)) * h
			f.rot *= fromRotationVector(f.spin * h)
		end
	end
	if weight <= 0 then
		return target
	end
	local drawn = CFrame.new(f.pos) * f.rot
	return if weight >= 1 then drawn else target:Lerp(drawn, weight)
end

-- The combined track offset for one gun, around its pivots (`centerRel`: the
-- gun's middle relative to its grip, the "Center" pivot). `weapon`: the held
-- gun's config (its trackLift). `akimbo`: two guns are held, `mirror` is the
-- left one. `screen`: only the tracks keyed on screen (Config/Viewmodel
-- `screen`, the knife's attacks), which holdPose applies in camera axes
-- around the grip so they read the same whatever the gun's tilt; otherwise
-- only the others, applied in the gun's own axes.
function ViewmodelTracks.offset(
	playing: Set,
	weapon: Types.WeaponConfig?,
	centerRel: Vector3,
	akimbo: boolean,
	mirror: boolean,
	screen: boolean
): CFrame
	local cf = CFrame.identity
	-- Akimbo guns take turns (playTurns): the right gun's half, then the left's.
	local turn = if akimbo then (if mirror then 1 else 0) else nil
	for slot, p in playing do
		if (p.track.screen == true) ~= screen then
			continue
		end
		if screen then
			local t = math.clamp(p.time / p.length, 0, 1)
			-- The blade's turn trails the hand's travel by SCREEN_LAG (the
			-- wrist follows through: overlapping action, not one rigid piece).
			-- It builds up after contact, so the blade is exactly on the
			-- impact point at `hit`.
			local hit = p.track.hit
			local ramp = if hit then math.clamp((t - hit) * p.length / 0.08, 0, 1) else 1
			local lag = VM.SCREEN_LAG * ramp / math.max(p.length, 1e-3)
			local travel = sampleKeys(p.track, t)
			local wrist = sampleKeys(p.track, math.max(t - lag, 0))
			local full = CFrame.new(travel.Position) * wrist.Rotation
			local from = p.blendFrom
			if from then
				local k = p.time / VM.TRACK_BLEND
				if k >= 1 then
					p.blendFrom = nil
				else
					full = from:Lerp(full, Ease.smooth(k))
				end
			end
			-- Through the spring: after contact on an attack, the whole way on
			-- the others; let go over the end, so the track lands on the hold.
			full = followed(
				p,
				full,
				(if hit then math.clamp((t - hit) * p.length / FOLLOW.after, 0, 1) else 1)
					* math.clamp((1 - t) / FOLLOW.out, 0, 1)
			)
			if mirror then
				local pos, rx, ry, rz = full.Position, full:ToEulerAnglesXYZ()
				full = CFrame.new(mirrorPos(pos)) * CFrame.Angles(rx, -ry, -rz)
			end
			cf *= if p.weight >= 1 then full else CFrame.new():Lerp(full, Ease.smooth(p.weight))
			continue
		end
		local t = math.clamp(p.time / p.length, 0, 1)
		if turn and TURN_SLOTS[slot] then
			t = math.clamp(t * 2 - turn, 0, 1)
		end
		local pos, rot = sample(p.track, t)
		local liftPos, liftRot = liftFor(weapon, slot, t)
		rot *= p.rotScale
		pos += liftPos
		rot += liftRot
		if mirror then
			pos, rot = mirrorPos(pos), mirrorRot(rot)
		end
		local pivot = if p.track.pivot == "Center" then centerRel else Vector3.zero
		local full = aroundPivot(pivot, CFrame.new(pos) * angles(rot))
		-- A fading (cancelled) track blends out along the shortest rotation, so
		-- a knife mid-flip doesn't spin back a full turn.
		cf *= if p.weight >= 1 then full else CFrame.new():Lerp(full, Ease.smooth(p.weight))
	end
	return cf
end

return ViewmodelTracks
