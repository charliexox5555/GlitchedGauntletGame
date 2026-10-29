--!strict
-- Dash as other players see it (vault/01 Design/Abilities/Dash.md → What
-- others see): a team-tinted wind trail along the path, an air burst where it
-- starts (wisps blown back) and a soft puff where it ends. Layered from the
-- Dash textures (Config/VfxTextures DASH_*) with ParticleEmitters and a
-- Trail. ModFeelController spots the dash (DashStart / Dashing) and calls in.
--
-- Pooled: one Trail per character (on its root, made on its first dash and
-- gone with it), one emitter part per layer shared by everyone.

local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config.Mods)
local VFX = require(ReplicatedStorage.Shared.Config.VfxTextures)

local DashFx = {}

local WHITE = Color3.new(1, 1, 1)
-- Air reads as air: mostly white, with the team colour through it.
local TINT = 0.45

type Layers = {
	part: BasePart,
	burst: ParticleEmitter, -- the gust ring at the start
	wisps: ParticleEmitter, -- streaks blown back from the start
	puff: ParticleEmitter, -- the settle at the end
}

local layers: Layers? = nil
local trails: { [Model]: Trail } = setmetatable({}, { __mode = "k" }) :: any
-- os.clock() each trail turns off by itself (in case the end is never seen).
local trailsOff: { [Trail]: number } = setmetatable({}, { __mode = "k" }) :: any
local TRAIL_SLACK = 0.15

-- A usable flat direction (falls back to the root's facing).
local function flatDir(dir: Vector3, root: BasePart): Vector3
	local flat = dir * Vector3.new(1, 0, 1)
	if flat.Magnitude > 1e-3 then
		return flat.Unit
	end
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	return if look.Magnitude > 1e-3 then look.Unit else Vector3.new(0, 0, -1)
end

local function curve(points: { number }): NumberSequence
	local keys = {}
	for i = 1, #points, 2 do
		table.insert(keys, NumberSequenceKeypoint.new(points[i], points[i + 1]))
	end
	return NumberSequence.new(keys)
end

local function tint(color: Color3): Color3
	return WHITE:Lerp(color, TINT)
end

local function flipbookOnce(e: ParticleEmitter, fps: number)
	e.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
	e.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	e.FlipbookFramerate = NumberRange.new(fps)
end

local function emitter(parent: Instance, texture: string): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = texture
	e.Rate = 0
	e.Enabled = false
	e.LightInfluence = 0.2
	e.LockedToPart = false
	e.Parent = parent
	return e
end

local function build(): Layers
	local folder = Workspace:FindFirstChild("Effects") or Workspace
	local part = Instance.new("Part")
	part.Name = "DashFx"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.CFrame = CFrame.new(0, -10000, 0)
	part.Parent = folder

	-- The ring faces the way you dash (it drifts along it, perpendicular).
	local burst = emitter(part, VFX.DASH_AIR_BURST_2x2)
	flipbookOnce(burst, 18)
	burst.Lifetime = NumberRange.new(0.2, 0.24)
	burst.Speed = NumberRange.new(3)
	burst.EmissionDirection = Enum.NormalId.Front
	burst.SpreadAngle = Vector2.zero
	burst.Size = curve({ 0, 4, 1, 7 })
	burst.Transparency = curve({ 0, 0.1, 0.6, 0.45, 1, 1 })
	burst.LightEmission = 0.7
	burst.LightInfluence = 0
	burst.Rotation = NumberRange.new(0, 360)
	burst.Orientation = Enum.ParticleOrientation.VelocityPerpendicular

	local wisps = emitter(part, VFX.DASH_SCREEN_STREAK)
	wisps.Lifetime = NumberRange.new(0.2, 0.32)
	wisps.Speed = NumberRange.new(12, 22)
	wisps.Drag = 6
	wisps.EmissionDirection = Enum.NormalId.Back -- behind the dash
	wisps.SpreadAngle = Vector2.new(30, 30)
	wisps.Size = curve({ 0, 0.5, 1, 0.15 })
	wisps.Squash = curve({ 0, -1.5, 1, -1 }) -- long and thin along the flight
	wisps.Transparency = curve({ 0, 0.25, 1, 1 })
	wisps.LightEmission = 0.5
	wisps.Orientation = Enum.ParticleOrientation.VelocityParallel

	local puff = emitter(part, VFX.DASH_PUFF_2x2)
	flipbookOnce(puff, 10)
	puff.Lifetime = NumberRange.new(0.35, 0.45)
	puff.Speed = NumberRange.new(2, 5)
	puff.Drag = 4
	puff.Acceleration = Vector3.new(0, 1.5, 0)
	puff.EmissionDirection = Enum.NormalId.Front -- carried on the way you went
	puff.SpreadAngle = Vector2.new(50, 20)
	puff.Size = curve({ 0, 2.5, 1, 4.5 })
	puff.LightEmission = 0.15
	puff.LightInfluence = 0.4
	puff.Transparency = curve({ 0, 0.35, 0.5, 0.6, 1, 1 })
	puff.Rotation = NumberRange.new(0, 360)
	puff.RotSpeed = NumberRange.new(-40, 40)

	local l = { part = part, burst = burst, wisps = wisps, puff = puff }
	layers = l
	return l
end

local function getLayers(): Layers
	local l = layers
	if l and l.part.Parent then
		return l
	end
	return build()
end

-- The character's Trail (made once, on its root; StreamingEnabled can take
-- the root away, so a missing one is rebuilt).
local function trailOf(character: Model, root: BasePart): Trail
	local existing = trails[character]
	if existing and existing.Parent == root then
		return existing
	end
	local top = Instance.new("Attachment")
	top.Name = "DashTrailTop"
	top.Position = Vector3.new(0, 1.1, 0)
	top.Parent = root
	local bottom = Instance.new("Attachment")
	bottom.Name = "DashTrailBottom"
	bottom.Position = Vector3.new(0, -1.6, 0)
	bottom.Parent = root
	local trail = Instance.new("Trail")
	trail.Name = "DashTrail"
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Texture = VFX.DASH_WIND_TRAIL
	trail.TextureMode = Enum.TextureMode.Stretch
	trail.Lifetime = Config.DASH_FEEL.trailTime
	trail.MinLength = 0.05
	trail.LightEmission = 0.7
	trail.LightInfluence = 0
	trail.FaceCamera = true
	trail.Transparency = curve({ 0, 0.2, 0.4, 0.45, 1, 1 })
	trail.WidthScale = curve({ 0, 1, 1, 0.35 })
	trail.Enabled = false
	trail.Parent = root
	trails[character] = trail
	return trail
end

-- The dash starts at `root` going `dir` for `length` seconds: burst,
-- wisps, trail on.
function DashFx.start(character: Model, root: BasePart, dir: Vector3, length: number, color: Color3)
	dir = flatDir(dir, root)
	local l = getLayers()
	local c = ColorSequence.new(tint(color))
	local at = root.Position
	l.part.CFrame = CFrame.lookAt(at, at + dir)
	l.burst.Color = c
	l.wisps.Color = c
	l.burst:Emit(1)
	l.wisps:Emit(6)
	-- A smaller second ring a beat later, for depth.
	task.delay(0.05, function()
		if l.part.Parent then
			l.part.CFrame = CFrame.lookAt(at + dir * 0.6, at + dir * 1.6)
			l.burst:Emit(1)
		end
	end)
	local trail = trailOf(character, root)
	trail.Color = c
	trail.Enabled = true
	trailsOff[trail] = os.clock() + math.clamp(length, 0, 1) + TRAIL_SLACK
end

-- The dash ended at `root` (it was going `dir`): trail off, a settling puff.
function DashFx.finish(character: Model, root: BasePart, dir: Vector3, color: Color3)
	local trail = trails[character]
	if trail then
		trail.Enabled = false
		trailsOff[trail] = nil
	end
	dir = flatDir(dir, root)
	local l = getLayers()
	local at = root.Position - Vector3.new(0, 1.2, 0)
	l.part.CFrame = CFrame.lookAt(at, at + dir)
	l.puff.Color = ColorSequence.new(tint(color))
	l.puff:Emit(3)
end

-- Per frame: turns off trails whose dash should be over (a missed end).
function DashFx.step()
	local now = os.clock()
	for trail, offAt in trailsOff do
		if now >= offAt then
			trail.Enabled = false
			trailsOff[trail] = nil
		end
	end
end

return DashFx
