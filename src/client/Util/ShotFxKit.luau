--!strict
-- Shared pieces of the shot effects (Controllers/EffectsController and the
-- Util/MuzzleFx, ShellFx, TracerFx, ImpactFx and KnifeSwipeFx modules it is
-- split into): the Workspace.Effects folder, the shared colours, the effects
-- time scale, and the builders for fx parts, world attachments and burst-only
-- particle emitters. Requires none of the other shot fx modules.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local VFX = require(ReplicatedStorage.Shared.Config.VfxTextures)

local ShotFxKit = {}

ShotFxKit.WHITE = Color3.new(1, 1, 1)
ShotFxKit.FIRE = Color3.fromHex("FFB45A") -- muzzle light and glow
ShotFxKit.SPARK_HOT = Color3.fromHex("FFF1C2")
ShotFxKit.SPARK_COOL = Color3.fromHex("FF8A2A")

local folder: Folder? = nil

-- Effects time. Studio only: Workspace attribute VfxTimeScale slows it down
-- (0 freezes everything) for screenshots (EffectsController sets it).
local timeScale = 1

function ShotFxKit.getTimeScale(): number
	return timeScale
end

function ShotFxKit.setTimeScale(value: number)
	timeScale = value
end

function ShotFxKit.effectsFolder(): Folder
	if folder and folder.Parent then
		return folder
	end
	local f = Instance.new("Folder")
	f.Name = "Effects"
	f.Parent = Workspace
	folder = f
	return f
end

function ShotFxKit.fxPart(size: Vector3, cf: CFrame, color: Color3): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.Color = color
	p.Size = size
	p.CFrame = cf
	p.Parent = ShotFxKit.effectsFolder()
	return p
end

function ShotFxKit.worldAttachment(name: string): Attachment
	local a = Instance.new("Attachment")
	a.Name = name
	a.Parent = Workspace.Terrain
	return a
end

-- NumberSequence from flat time/value pairs: curve({ 0, 1, 1, 0 }).
function ShotFxKit.curve(points: { number }): NumberSequence
	local keys = {}
	for i = 1, #points, 2 do
		table.insert(keys, NumberSequenceKeypoint.new(points[i], points[i + 1]))
	end
	return NumberSequence.new(keys)
end

local function upFor(dir: Vector3): Vector3
	return if math.abs(dir.Unit.Y) > 0.99 then Vector3.zAxis else Vector3.yAxis
end

function ShotFxKit.facing(position: Vector3, dir: Vector3): CFrame
	return CFrame.lookAt(position, position + dir, upFor(dir))
end

-- A burst-only emitter (Enabled = false; fire it with Emit). Lit by the scene
-- unless it's fire.
function ShotFxKit.emitter(parent: Instance, texture: string, color: Color3): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = texture
	e.Color = ColorSequence.new(color)
	e.Enabled = false
	e.LightEmission = 0
	e.LightInfluence = 1
	e.Speed = NumberRange.new(0)
	e.Rotation = NumberRange.new(0, 360)
	e.Lifetime = NumberRange.new(0.1)
	e.TimeScale = timeScale
	e.Parent = parent
	return e
end

function ShotFxKit.fire(e: ParticleEmitter)
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Brightness = 1
end

-- 2x2 sheet; each particle keeps one random frame.
function ShotFxKit.flipbook(e: ParticleEmitter)
	e.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
	e.FlipbookMode = Enum.ParticleFlipbookMode.Loop
	e.FlipbookFramerate = NumberRange.new(0)
	e.FlipbookStartRandom = true
end

function ShotFxKit.sparkEmitter(parent: Instance, size: number): ParticleEmitter
	local e = ShotFxKit.emitter(parent, VFX.SPARK, ShotFxKit.SPARK_HOT)
	ShotFxKit.fire(e)
	e.Color = ColorSequence.new(ShotFxKit.SPARK_HOT, ShotFxKit.SPARK_COOL)
	e.Orientation = Enum.ParticleOrientation.VelocityParallel
	e.Rotation = NumberRange.new(0)
	e.Size = ShotFxKit.curve({ 0, size, 1, size * 0.3 })
	e.Squash = ShotFxKit.curve({ 0, 1.6, 1, 0.8 })
	e.EmissionDirection = Enum.NormalId.Front
	return e
end

return ShotFxKit
