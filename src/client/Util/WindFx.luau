--!strict
-- The wind Mods as other players see them, team-tinted, layered from the
-- wind textures (Config/VfxTextures DASH_*) with ParticleEmitters and Trails.
-- ModFeelController spots the casts (simulation attributes) and calls in.
--   Dash (vault/01 Design/Abilities/Dash.md → What others see): a wind trail
--   along the path, a gust ring where it starts (wisps blown back) and a
--   soft puff where it ends.
--   Updraft (Updraft.md → What others see): a gust ring and dust at your
--   feet where you launched, and a short trail under you while rising.
--
-- Pooled: one Trail of each kind per character (on its root, made on first
-- use and gone with it), one emitter part per layer shared by everyone.

local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config.Mods)
local VFX = require(ReplicatedStorage.Shared.Config.VfxTextures)

local WindFx = {}

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

-- Trail kinds: where its two attachments sit on the root.
type TrailSpec = {
	name: string,
	a: Vector3,
	b: Vector3,
	lifetime: number,
	faceCamera: boolean,
}
local TRAILS: { [string]: TrailSpec } = {
	-- Head to shins: a ribbon along the dash.
	Dash = {
		name = "DashTrail",
		a = Vector3.new(0, 1.1, 0),
		b = Vector3.new(0, -1.6, 0),
		lifetime = Config.DASH_FEEL.trailTime,
		faceCamera = true,
	},
	-- Across the feet: a sheet left under you as you rise.
	Updraft = {
		name = "UpdraftTrail",
		a = Vector3.new(-1.1, -2.6, 0),
		b = Vector3.new(1.1, -2.6, 0),
		lifetime = Config.UPDRAFT_FEEL.trailTime,
		faceCamera = false,
	},
}
local trails: { [string]: { [Model]: Trail } } = {
	Dash = setmetatable({}, { __mode = "k" }) :: any,
	Updraft = setmetatable({}, { __mode = "k" }) :: any,
}
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
	part.Name = "WindFx"
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

-- The character's Trail of `kind` (made once, on its root; StreamingEnabled
-- can take the root away, so a missing one is rebuilt).
local function trailOf(kind: string, character: Model, root: BasePart): Trail
	local spec = TRAILS[kind]
	local list = trails[kind]
	local existing = list[character]
	if existing and existing.Parent == root then
		return existing
	end
	local a = Instance.new("Attachment")
	a.Name = spec.name .. "A"
	a.Position = spec.a
	a.Parent = root
	local b = Instance.new("Attachment")
	b.Name = spec.name .. "B"
	b.Position = spec.b
	b.Parent = root
	local trail = Instance.new("Trail")
	trail.Name = spec.name
	trail.Attachment0 = a
	trail.Attachment1 = b
	trail.Texture = VFX.DASH_WIND_TRAIL
	trail.TextureMode = Enum.TextureMode.Stretch
	trail.Lifetime = spec.lifetime
	trail.MinLength = 0.05
	trail.LightEmission = 0.7
	trail.LightInfluence = 0
	trail.FaceCamera = spec.faceCamera
	trail.Transparency = curve({ 0, 0.2, 0.4, 0.45, 1, 1 })
	trail.WidthScale = curve({ 0, 1, 1, 0.35 })
	trail.Enabled = false
	trail.Parent = root
	list[character] = trail
	return trail
end

-- Turns a trail on for `seconds` (it turns off by itself after that).
local function trailFor(
	kind: string,
	character: Model,
	root: BasePart,
	color: ColorSequence,
	seconds: number
)
	local trail = trailOf(kind, character, root)
	trail.Color = color
	trail.Enabled = true
	trailsOff[trail] = os.clock() + math.clamp(seconds, 0, 1)
end

-- The dash starts at `root` going `dir` for `length` seconds: burst,
-- wisps, trail on.
function WindFx.dashStart(
	character: Model,
	root: BasePart,
	dir: Vector3,
	length: number,
	color: Color3
)
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
	trailFor("Dash", character, root, c, length + TRAIL_SLACK)
end

-- The dash ended at `root` (it was going `dir`): trail off, a settling puff.
function WindFx.dashEnd(character: Model, root: BasePart, dir: Vector3, color: Color3)
	local trail = trails.Dash[character]
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

-- An Updraft launched from `root` (rising for `rise` seconds): a gust ring
-- flat on the ground and dust at the feet, and a trail under you.
function WindFx.updraft(character: Model, root: BasePart, rise: number, color: Color3)
	local l = getLayers()
	local c = ColorSequence.new(tint(color))
	local feet = root.Position - Vector3.new(0, 2.8, 0)
	l.part.CFrame = CFrame.lookAt(feet, feet + Vector3.yAxis, Vector3.zAxis)
	l.burst.Color = c
	l.burst:Emit(1)
	l.puff.Color = c
	l.puff:Emit(3)
	task.delay(0.05, function()
		if l.part.Parent then
			l.part.CFrame =
				CFrame.lookAt(feet + Vector3.yAxis * 0.6, feet + Vector3.yAxis * 1.6, Vector3.zAxis)
			l.burst:Emit(1)
		end
	end)
	trailFor("Updraft", character, root, c, math.min(rise, Config.UPDRAFT_FEEL.trailTime))
end

-- Per frame: turns off trails whose cast should be over (a missed end).
function WindFx.step()
	local now = os.clock()
	for trail, offAt in trailsOff do
		if now >= offAt then
			trail.Enabled = false
			trailsOff[trail] = nil
		end
	end
end

return WindFx
