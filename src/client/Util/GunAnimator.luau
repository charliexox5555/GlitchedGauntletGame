--!strict
-- Plays the Blender clips (src/shared/WeaponAnimations: Fire, Reload and,
-- when a gun has them, ReloadEmpty, Draw and Inspect) on a weapon model's
-- Rig.Motors. Each clip stores, per bone and per frame, the
-- bone's local transform from rest, which is exactly Motor6D.Transform
-- because WeaponBuilder builds each joint in its bone's own axes.
--
-- Between the 24 fps keys each channel follows a monotone cubic (PCHIP,
-- Fritsch-Butland, the spline Util/ViewmodelTracks uses): straight CFrame
-- lerps put a corner in every part's speed every 42 ms at 60+ fps (2026-11-20
-- animation pass). Turning points and the clip's ends stay at rest, so holds
-- stay still and nothing swings past a key.
--
-- Rest: a bone whose Fire clip starts away from the built pose (the Marshal's
-- hammer, cocked) rests there between clips, so a clip neither starts nor ends
-- on a one-frame snap back to the built pose.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

type Clip = { frames: number, bones: { [string]: { number } } }
type ClipSet = {
	fps: number,
	Fire: Clip?,
	Reload: Clip?,
	ReloadEmpty: Clip?, -- empty mag: the reload ends by racking the action
	Draw: Clip?, -- first draw of a life: raise and rack
	Inspect: Clip?,
	ReloadStart: Clip?, -- shell-by-shell reloads: into the loading pose,
	ReloadInsert: Clip?, -- one shell (looped per shell),
	ReloadEnd: Clip?, -- back to the hold
	DryFire: Clip?, -- trigger on an empty gun
}

export type GunAnimator = {
	model: Model,
	scale: number,
	motors: { [string]: Motor6D },
	rest: { [string]: CFrame }, -- bones that rest away from the built pose
	clips: ClipSet?,
	clip: Clip?,
	clipName: string?,
	time: number,
	speed: number,
	length: number,
	dirty: boolean,
	-- `holdEnd`: keep the clip's last frame when it ends (no clip playing) until
	-- the next play or stop, for clips another one follows (a shell loop).
	play: (self: GunAnimator, name: string, duration: number?, holdEnd: boolean?) -> (),
	holdEnd: boolean,
	holding: string?, -- the clip whose end frame is held
	stop: (self: GunAnimator) -> (),
	isPlaying: (self: GunAnimator, name: string?) -> boolean,
	holdStart: (self: GunAnimator, name: string) -> (),
	has: (self: GunAnimator, name: string) -> boolean,
	progress: (self: GunAnimator) -> number,
	activity: (self: GunAnimator, name: string, bone: string) -> (number?, number?),
	update: (self: GunAnimator, dt: number) -> (),
	-- A roll on one bone on top of whatever clip plays (a revolver's cylinder
	-- rolled by the palm as the inspect starts): `degrees` about `axis` (the
	-- bone's own), fast at first and easing to a stop over `seconds`.
	spin: (self: GunAnimator, bone: string, degrees: number, seconds: number, axis: Vector3) -> (),
	spinBone: string?,
	spinTime: number,
	spinLength: number,
	spinAngle: number, -- radians
	spinAxis: Vector3,
}

local GunAnimator = {}

local animationsFolder = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WeaponAnimations")
local cache: { [string]: ClipSet } = {}

local function loadClips(id: string): ClipSet?
	if cache[id] then
		return cache[id]
	end
	local module = animationsFolder:FindFirstChild(id)
	if not module or not module:IsA("ModuleScript") then
		return nil
	end
	local clips = (require(module) :: any) :: ClipSet
	cache[id] = clips
	return clips
end

local function frameCFrame(data: { number }, frame: number, scale: number): CFrame
	local i = frame * 7
	return CFrame.new(
		data[i + 1] * scale,
		data[i + 2] * scale,
		data[i + 3] * scale,
		data[i + 5],
		data[i + 6],
		data[i + 7],
		data[i + 4]
	)
end

-- The velocity at the middle key (Fritsch-Butland PCHIP, keys one frame
-- apart): zero where the channel turns back or holds.
local function pchip(a: number, b: number, c: number): number
	local sa, sb = b - a, c - b
	if sa * sb <= 0 then
		return 0
	end
	return 2 * sa * sb / (sa + sb)
end

-- Clip pose of `data` at frame `f` (fractional) on a monotone cubic through
-- the keys either side. `last` is the clip's last frame index.
local function sampleCFrame(data: { number }, f: number, last: number, scale: number): CFrame
	local i0 = math.clamp(math.floor(f), 0, last)
	local i1 = math.min(i0 + 1, last)
	local t = f - i0
	if i1 == i0 or t <= 0 then
		return frameCFrame(data, i0, scale)
	end
	local im = math.max(i0 - 1, 0)
	local i2 = math.min(i1 + 1, last)
	local bm, b0, b1, b2 = im * 7, i0 * 7, i1 * 7, i2 * 7
	-- Quaternions on the same side as the key we leave (q and -q are one turn).
	local function sign(base: number): number
		local d = data[base + 4] * data[b0 + 4]
			+ data[base + 5] * data[b0 + 5]
			+ data[base + 6] * data[b0 + 6]
			+ data[base + 7] * data[b0 + 7]
		return if d < 0 then -1 else 1
	end
	local sm, s1, s2 = sign(bm), sign(b1), sign(b2)
	local t2, t3 = t * t, t * t * t
	local h00, h10, h01, h11 = 2 * t3 - 3 * t2 + 1, t3 - 2 * t2 + t, -2 * t3 + 3 * t2, t3 - t2
	local out = table.create(7, 0)
	for k = 1, 7 do
		local quat = k >= 4
		local pm = data[bm + k] * (if quat then sm else 1)
		local p0 = data[b0 + k]
		local p1 = data[b1 + k] * (if quat then s1 else 1)
		local p2 = data[b2 + k] * (if quat then s2 else 1)
		-- The clip's ends start and stop at rest.
		local m0 = if i0 == 0 then 0 else pchip(pm, p0, p1)
		local m1 = if i1 == last then 0 else pchip(p0, p1, p2)
		out[k] = h00 * p0 + h10 * m0 + h01 * p1 + h11 * m1
	end
	local qw, qx, qy, qz = out[4], out[5], out[6], out[7]
	local n = math.sqrt(qw * qw + qx * qx + qy * qy + qz * qz)
	if n < 1e-6 then
		return frameCFrame(data, i0, scale)
	end
	return CFrame.new(
		out[1] * scale,
		out[2] * scale,
		out[3] * scale,
		qx / n,
		qy / n,
		qz / n,
		qw / n
	)
end

local function resetMotors(self: GunAnimator)
	for name, m in self.motors do
		m.Transform = self.rest[name] or CFrame.identity
	end
	self.dirty = false
end

local function play(self: GunAnimator, name: string, duration: number?, holdEnd: boolean?)
	local clips = self.clips
	local clip = clips and (clips :: any)[name] :: Clip?
	if not clips or not clip then
		return
	end
	self.clip = clip
	self.clipName = name
	self.holdEnd = holdEnd == true
	self.holding = nil
	self.time = 0
	self.length = math.max(clip.frames - 1, 1) / clips.fps
	self.speed = if duration and duration > 0 then self.length / duration else 1
end

local function stop(self: GunAnimator)
	self.clip = nil
	self.clipName = nil
	self.holding = nil
	if self.dirty then
		resetMotors(self)
	end
end

local function isPlaying(self: GunAnimator, name: string?): boolean
	return self.clip ~= nil and (name == nil or self.clipName == name)
end

-- Holds the first frame of clip `name` (no clip playing) until the next
-- play or stop: a pistol's slide locked back after its last round.
local function holdStart(self: GunAnimator, name: string)
	local clips = self.clips
	local clip = clips and (clips :: any)[name] :: Clip?
	if not clip then
		return
	end
	self.clip = nil
	self.clipName = nil
	self.holding = nil
	resetMotors(self)
	for bone, data in clip.bones do
		local motor = self.motors[bone]
		if motor then
			motor.Transform = frameCFrame(data, 0, self.scale)
		end
	end
	self.dirty = true
end

local function has(self: GunAnimator, name: string): boolean
	local clips = self.clips
	return clips ~= nil and (clips :: any)[name] ~= nil
end

-- How far through the playing clip we are, 0..1.
local function progress(self: GunAnimator): number
	return if self.clip then math.clamp(self.time / self.length, 0, 1) else 0
end

-- When (0..1 through the clip) a bone first and last leaves its rest pose,
-- so hands can reach for a part just before it moves. nil if it never moves.
local activityCache: { [Clip]: { [string]: { number } | false } } = {}

local function activity(self: GunAnimator, name: string, bone: string): (number?, number?)
	local clips = self.clips
	local clip = clips and (clips :: any)[name] :: Clip?
	if not clip then
		return nil
	end
	local perClip = activityCache[clip]
	if not perClip then
		perClip = {}
		activityCache[clip] = perClip
	end
	local cached = perClip[bone]
	if cached == nil then
		cached = false
		local data = clip.bones[bone]
		if data then
			local first, last = -1, -1
			for f = 0, clip.frames - 1 do
				local i = f * 7
				local moved = math.abs(data[i + 1]) + math.abs(data[i + 2]) + math.abs(data[i + 3])
						> 0.01
					or math.abs(data[i + 4]) < 0.9995
				if moved then
					if first < 0 then
						first = f
					end
					last = f
				end
			end
			if first >= 0 then
				local span = math.max(clip.frames - 1, 1)
				cached = { first / span, last / span }
			end
		end
		perClip[bone] = cached
	end
	if cached then
		return cached[1], cached[2]
	end
	return nil
end

-- The bone spin's motor and its turn this frame (nil when none).
local function stepSpin(self: GunAnimator, dt: number): (Motor6D?, CFrame)
	local bone = self.spinBone
	local motor = bone and self.motors[bone]
	if not motor then
		return nil, CFrame.identity
	end
	self.spinTime += dt
	local u = math.clamp(self.spinTime / math.max(self.spinLength, 1e-3), 0, 1)
	if u >= 1 then
		self.spinBone = nil -- whole turns: it lands where it started
		return motor, CFrame.identity
	end
	local eased = 1 - (1 - u) ^ 3 -- rolled hard, slowing to a stop
	return motor, CFrame.fromAxisAngle(self.spinAxis, self.spinAngle * eased)
end

local function spin(
	self: GunAnimator,
	bone: string,
	degrees: number,
	seconds: number,
	axis: Vector3
)
	self.spinBone = bone
	self.spinTime = 0
	self.spinLength = seconds
	self.spinAngle = math.rad(degrees)
	self.spinAxis = axis.Unit
end

local function update(self: GunAnimator, dt: number)
	local spinMotor, spinCf = stepSpin(self, dt)
	local clip = self.clip
	local clips = self.clips
	if not clip or not clips then
		if spinMotor then
			spinMotor.Transform = spinCf
			self.dirty = true
		end
		return
	end
	self.time += dt * self.speed
	if self.time >= self.length then
		if self.holdEnd then
			-- Pose the last frame and keep it (the next clip starts from it).
			local last = clip.frames - 1
			for bone, data in clip.bones do
				local motor = self.motors[bone]
				if motor then
					motor.Transform = frameCFrame(data, last, self.scale)
				end
			end
			self.holding = self.clipName
			self.clip = nil
			self.clipName = nil
			self.dirty = true
			return
		end
		stop(self)
		return
	end
	local f = self.time * clips.fps
	local last = clip.frames - 1
	for bone, data in clip.bones do
		local motor = self.motors[bone]
		if motor then
			motor.Transform = sampleCFrame(data, f, last, self.scale)
			if motor == spinMotor then
				motor.Transform *= spinCf
			end
		end
	end
	self.dirty = true
end

function GunAnimator.new(model: Model, weaponId: string, scale: number): GunAnimator
	local motors: { [string]: Motor6D } = {}
	local rig = model:FindFirstChild("Rig")
	local folder = rig and rig:FindFirstChild("Motors")
	if folder then
		for _, m in folder:GetChildren() do
			if m:IsA("Motor6D") then
				if m.Name == "Charm" then
					-- CharmRig owns live charm physics; baked Charm tracks must not rotate CharmPoint.
					m.Transform = CFrame.identity
				else
					motors[m.Name] = m
				end
			end
		end
	end
	local clips = loadClips(weaponId)
	local rest: { [string]: CFrame } = {}
	local fire = clips and clips.Fire
	if fire then
		for bone, data in fire.bones do
			local cf = frameCFrame(data, 0, scale)
			local motor = motors[bone]
			if motor and (cf.Position.Magnitude > 1e-3 or math.abs(data[4]) < 0.9995) then
				rest[bone] = cf
				motor.Transform = cf
			end
		end
	end
	return {
		model = model,
		scale = scale,
		motors = motors,
		rest = rest,
		clips = clips,
		clip = nil,
		clipName = nil,
		holdEnd = false,
		holding = nil,
		time = 0,
		speed = 1,
		length = 0,
		dirty = false,
		play = play,
		stop = stop,
		isPlaying = isPlaying,
		holdStart = holdStart,
		has = has,
		progress = progress,
		activity = activity,
		update = update,
		spin = spin,
		spinBone = nil,
		spinTime = 0,
		spinLength = 0,
		spinAngle = 0,
		spinAxis = Vector3.xAxis,
	}
end

return GunAnimator
