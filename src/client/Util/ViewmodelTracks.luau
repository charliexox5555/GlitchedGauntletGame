--!strict
-- Keyframed viewmodel tracks (Config/Viewmodel TRACKS): the moves played on
-- top of the gun's hold pose (equip, draw, reload, inspect, melee swings).
-- Owns sampling a track, the set of tracks playing by slot (start, fade out,
-- step, the hit-stop freeze) and their combined offset for one gun. The set
-- itself belongs to ViewmodelController; every function here takes it.
-- Also the small rig math the controller shares (degree angles, mirroring
-- for the left gun of an akimbo pair).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Ease = require(ReplicatedStorage.Shared.Util.Ease)
local Types = require(ReplicatedStorage.Shared.Types)
local VM = require(ReplicatedStorage.Shared.Config.Viewmodel)

-- `rotScale`: how much of the track's rotation applies (0 = position only, when a
-- gun clip of the same move already turns the gun).
export type Playing = {
	track: VM.Track,
	time: number,
	length: number,
	weight: number,
	fading: boolean,
	rotScale: number,
	freeze: number, -- seconds left of a hit-stop: the track holds its frame
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

local function sample(track: VM.Track, t: number): (Vector3, Vector3)
	local keys = track.keys
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
	playing[slot] = {
		track = track,
		time = 0,
		length = if duration and duration > 0 then duration else track.length,
		weight = 1,
		fading = false,
		rotScale = rotScale or 1,
		freeze = 0,
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
		if p.freeze > 0 and not p.fading then
			-- Hit-stop: hold this frame (the time it eats is not caught up).
			p.freeze -= dt
			continue
		end
		p.time += dt
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
	local live = if studio then Workspace:GetAttribute("VmLift" .. slot) else nil
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

-- A `screen` track's offset at `t`: each key as a CFrame, eased between them
-- with CFrame:Lerp, so the turn takes the shortest way (a slerp).
local function sampleKeys(track: VM.Track, t: number): CFrame
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
