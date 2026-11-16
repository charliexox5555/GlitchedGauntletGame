--!strict
-- The Roller as everyone sees it (vault/01 Design/Abilities/Roller.md → Look).
-- The server moves an invisible anchored part (Mods/Roller); this draws the
-- finished model (ReplicatedStorage.Abilities.Roller, Kind "placed", pivot at
-- the floor centre facing -Z) following that part smoothly: anchored CFrame
-- changes arrive at network rate, so the model eases toward the part and
-- leads it by its speed. Wheels (parts named Wheel*) turn with the distance
-- rolled. The eye (Eye_Energy) is dim while it seeks, lights up when it locks
-- on (LockedAt: a chirp) and blinks fast through the warning (WarnAt: the
-- beeps). A hum rides it while it rolls.
--
-- ModFxController routes placed parts with Kind "Roller" here (track) and
-- steps it every frame.

local Workspace = game:GetService("Workspace")

local ModAudio = require(script.Parent.ModAudio)
local ModProps = require(script.Parent.ModProps)
local ReworkVfx = require(script.Parent.ReworkVfx)

local S = ModAudio.SOUNDS

local RollerFx = {}

local FOLLOW = 22 -- 1/s: how fast the model closes on the part
local WHEEL_RADIUS = 0.42
local EYE_DIM = 0.55 -- the eye's transparency while seeking
local WARN_BLINK = 14 -- Hz

type Tracked = {
	part: BasePart,
	model: Model,
	eyes: { BasePart },
	wheels: { { part: BasePart, rest: CFrame } },
	light: PointLight?,
	pivot: CFrame, -- drawn
	last: Vector3, -- the part's position last frame (speed estimate)
	velocity: Vector3,
	roll: number, -- radians the wheels have turned
	hum: Sound?,
	lockedSeen: any,
	warnSeen: any,
	color: Color3,
}

local tracked: { [BasePart]: Tracked } = {}
local folder: Folder? = nil

local function fxFolder(): Folder
	local f = folder
	if f and f.Parent then
		return f
	end
	local made = Instance.new("Folder")
	made.Name = "Rollers"
	made.Parent = Workspace
	folder = made
	return made
end

-- A stand-in when the finished model isn't installed: a low faceted wedge
-- body with a slab eye (never a sphere).
local function standIn(color: Color3): Model
	local model = Instance.new("Model")
	model.Name = "Roller"
	local function block(
		name: string,
		size: Vector3,
		cf: CFrame,
		c: Color3,
		neon: boolean?,
		wedge: boolean?
	)
		local p: BasePart = if wedge then Instance.new("WedgePart") else Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf
		p.Color = c
		p.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Parent = model
		return p
	end
	local shell = Color3.fromHex("2A2D33")
	block("Body", Vector3.new(1.4, 0.7, 1.4), CFrame.new(0, 0.55, 0.1), shell)
	block(
		"Nose",
		Vector3.new(1.4, 0.7, 0.6),
		CFrame.new(0, 0.55, -0.9) * CFrame.Angles(0, math.pi, 0),
		shell,
		false,
		true
	)
	block(
		"Eye_Energy",
		Vector3.new(0.9, 0.16, 0.08),
		CFrame.new(0, 0.72, -0.62) * CFrame.Angles(math.rad(-35), 0, 0),
		color,
		true
	)
	for i, x in { -0.78, 0.78 } do
		block(
			"Wheel" .. i,
			Vector3.new(0.18, 0.84, 0.84),
			CFrame.new(x, 0.42, 0),
			Color3.fromHex("1B1D21")
		)
	end
	model.WorldPivot = CFrame.identity
	return model
end

local function modelFor(color: Color3): Model
	local finished = ModProps.finished("Roller", { "placed" })
	local model: Model
	if finished then
		model = finished:Clone()
		ModProps.tint(model, color)
	else
		model = standIn(color)
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	return model
end

local function floorPivot(part: BasePart): CFrame
	return part.CFrame * CFrame.new(0, -part.Size.Y / 2, 0)
end

function RollerFx.track(part: BasePart, color: Color3)
	if tracked[part] then
		return
	end
	local model = modelFor(color)
	local pivotNow = floorPivot(part)
	local eyes: { BasePart } = {}
	local wheels: { { part: BasePart, rest: CFrame } } = {}
	local inverse = model:GetPivot():Inverse()
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			if string.find(d.Name, "^Eye") then
				table.insert(eyes, d)
			elseif string.find(d.Name, "^Wheel") then
				table.insert(wheels, { part = d, rest = inverse * d.CFrame })
			end
		end
	end
	local eye = eyes[1]
	local light: PointLight? = nil
	if eye then
		local l = Instance.new("PointLight")
		l.Color = color
		l.Brightness = 1
		l.Range = 6
		l.Shadows = false
		l.Parent = eye
		light = l
	end
	model:PivotTo(pivotNow)
	model.Parent = fxFolder()
	part.LocalTransparencyModifier = 1
	local entry: Tracked = {
		part = part,
		model = model,
		eyes = eyes,
		wheels = wheels,
		light = light,
		pivot = pivotNow,
		last = part.Position,
		velocity = Vector3.zero,
		roll = 0,
		hum = nil,
		lockedSeen = part:GetAttribute("LockedAt"),
		warnSeen = part:GetAttribute("WarnAt"),
		color = color,
	}
	tracked[part] = entry
	-- Its own looping Sound (not ModAudio's pool): it goes with the model.
	local cue = S.Roller.roll
	local hum = Instance.new("Sound")
	hum.SoundId = cue.id
	hum.Looped = true
	hum.Volume = cue.volume
	hum.PlaybackSpeed = cue.pitch or 1
	hum.RollOffMode = Enum.RollOffMode.InverseTapered
	hum.RollOffMinDistance = 6
	hum.RollOffMaxDistance = cue.range or 35
	local loopEnd = cue.loopEnd
	if loopEnd then
		hum.PlaybackRegionsEnabled = true
		hum.LoopRegion = NumberRange.new(cue.start or 0, loopEnd)
	end
	hum.Parent = model.PrimaryPart or eye or model:FindFirstChildWhichIsA("BasePart")
	hum:Play()
	entry.hum = hum
	ModAudio.play(S.Roller.place, part.Position)
	part.AncestryChanged:Connect(function()
		if not part:IsDescendantOf(Workspace) then
			RollerFx.untrack(part)
		end
	end)
end

function RollerFx.untrack(part: BasePart)
	local entry = tracked[part]
	if not entry then
		return
	end
	tracked[part] = nil
	entry.model:Destroy() -- its hum too
end

function RollerFx.step(dt: number)
	local now = ReworkVfx.now()
	for part, t in tracked do
		if not part.Parent then
			RollerFx.untrack(part)
			continue
		end
		local target = floorPivot(part)
		-- The part's speed (smoothed): the model leads by a frame of it.
		local moved = part.Position - t.last
		t.last = part.Position
		if dt > 0 then
			t.velocity = t.velocity:Lerp(moved / dt, math.min(dt * 10, 1))
		end
		local lead = target + t.velocity * (1 / 30)
		local alpha = 1 - math.exp(-FOLLOW * dt)
		local before = t.pivot.Position
		t.pivot = t.pivot:Lerp(lead, alpha)
		t.model:PivotTo(t.pivot)
		-- Wheels: turned by the distance actually drawn.
		local drawn = (t.pivot.Position - before) * Vector3.new(1, 0, 1)
		local forward = t.pivot.LookVector
		t.roll += drawn:Dot(forward) / WHEEL_RADIUS
		for _, w in t.wheels do
			w.part.CFrame = t.pivot * w.rest * CFrame.Angles(0, t.roll, 0) -- the axle is the wheel's Y
		end
		-- The eye: dim seeking, lit locked, blinking through the warning.
		local locked = part:GetAttribute("LockedAt")
		local warn = part:GetAttribute("WarnAt")
		if locked ~= t.lockedSeen then
			t.lockedSeen = locked
			if locked ~= nil then
				ModAudio.play(S.Roller.lock, part.Position)
			end
		end
		if warn ~= t.warnSeen then
			t.warnSeen = warn
			if warn ~= nil then
				ModAudio.play(S.Roller.warn, part.Position)
			end
		end
		local alphaEye = EYE_DIM
		local bright = 1
		if warn ~= nil then
			local on = math.sin(now * WARN_BLINK * math.pi * 2) > 0
			alphaEye = if on then 0 else 0.7
			bright = if on then 6 else 0.5
		elseif locked ~= nil then
			alphaEye = 0
			bright = 3.5
		end
		for _, e in t.eyes do
			e.Transparency = alphaEye
		end
		local l = t.light
		if l then
			l.Brightness = bright
		end
	end
end

return RollerFx
