--!strict
-- Plays the Blender clips (src/shared/WeaponAnimations: Fire, Reload and,
-- when a gun has them, ReloadEmpty, Draw and Inspect) on a weapon model's
-- Rig.Motors. Each clip stores, per bone and per frame, the
-- bone's local transform from rest, which is exactly Motor6D.Transform
-- because WeaponBuilder builds each joint in its bone's own axes.

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

local function resetMotors(self: GunAnimator)
	for _, m in self.motors do
		m.Transform = CFrame.identity
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

local function update(self: GunAnimator, dt: number)
	local clip = self.clip
	local clips = self.clips
	if not clip or not clips then
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
	local i = math.floor(f)
	local a = f - i
	local last = clip.frames - 1
	local i0 = math.min(i, last)
	local i1 = math.min(i + 1, last)
	for bone, data in clip.bones do
		local motor = self.motors[bone]
		if motor then
			local c0 = frameCFrame(data, i0, self.scale)
			motor.Transform = if a > 0 and i1 ~= i0
				then c0:Lerp(frameCFrame(data, i1, self.scale), a)
				else c0
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
				motors[m.Name] = m
			end
		end
	end
	return {
		model = model,
		scale = scale,
		motors = motors,
		clips = loadClips(weaponId),
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
	}
end

return GunAnimator
