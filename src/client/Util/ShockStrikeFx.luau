--!strict
-- Electric Shock's look (Mods/ElectricShock; vault/01 Design/Abilities/Electric Shock.md):
--   latch   the orb snaps a zap onto its target; a warning ring circles their feet (it follows them) and their
--           body flickers for `warning` s; the target hears a lock-on whine
--   strike  a jagged bolt cracks down from the sky onto them (Blender Bolt mesh + crackling beams), a white flash,
--           sparks, and the chain / splash hops
--   fizzle  a small spark puff where the orb died
-- Meshes: ReplicatedStorage.Abilities.ShockVFX (Ring, Bolt; tools/blender/build_mod_shockvfx.py); textures
-- STIM_BOLT (beams) and STIM_ARC_2x2 (crackle). Everything client-side and short-lived.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Tex = require(ReplicatedStorage.Shared.Config.VfxTextures)
local ModSounds = require(ReplicatedStorage.Shared.Config.ModSounds)
local ModAudio = require(script.Parent.ModAudio)

local ShockStrikeFx = {}

local WHITE_BLUE = Color3.fromHex("CFEBFF")
local SKY = 45 -- studs above the target the bolt starts
local S = ModSounds.ElectricShock

local folder: Folder? = nil
local function fxFolder(): Folder
	local f = folder
	if f and f.Parent then
		return f
	end
	local made = Instance.new("Folder")
	made.Name = "ShockStrikeFx"
	made.Parent = Workspace
	folder = made
	return made
end

local function kit(name: string): BasePart?
	local abilities = ReplicatedStorage:FindFirstChild("Abilities")
	local vfx = abilities and abilities:FindFirstChild("ShockVFX")
	local p = vfx and vfx:FindFirstChild(name, true)
	return if p and p:IsA("BasePart") then p else nil
end

local function point(at: Vector3, life: number): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.one * 0.2
	p.CFrame = CFrame.new(at)
	p.Parent = fxFolder()
	task.delay(life, function()
		p:Destroy()
	end)
	return p
end

-- A crackling beam between two points for `life` s, re-jittered every frame.
local function zap(from: Vector3, to: Vector3, color: Color3, width: number, life: number)
	local a, b = point(from, life), point(to, life)
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Parent, a1.Parent = a, b
	local beam = Instance.new("Beam")
	beam.Attachment0, beam.Attachment1 = a0, a1
	beam.Texture = Tex.STIM_BOLT
	beam.TextureMode = Enum.TextureMode.Stretch
	beam.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.4))
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Width0, beam.Width1 = width, width * 0.8
	beam.FaceCamera = true
	beam.Segments = 12
	beam.Parent = a
	local t0 = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local k = (os.clock() - t0) / life
		if k >= 1 or not beam.Parent then
			conn:Disconnect()
			return
		end
		beam.CurveSize0 = math.random(-30, 30) / 10
		beam.CurveSize1 = math.random(-30, 30) / 10
		beam.Transparency = NumberSequence.new(math.clamp(k * k, 0, 1))
	end)
end

local function sparks(at: Vector3, color: Color3, count: number)
	local p = point(at, 1.5)
	local e = Instance.new("ParticleEmitter")
	e.Texture = Tex.SPARK
	e.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.3))
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 0),
	})
	e.Lifetime = NumberRange.new(0.25, 0.6)
	e.Speed = NumberRange.new(10, 26)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, -30, 0)
	e.Drag = 3
	e.Orientation = Enum.ParticleOrientation.VelocityParallel
	e.Rate = 0
	e.Parent = p
	e:Emit(count)
	local crackle = Instance.new("ParticleEmitter")
	crackle.Texture = Tex.STIM_ARC_2x2
	crackle.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
	crackle.FlipbookMode = Enum.ParticleFlipbookMode.Random
	crackle.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.5))
	crackle.LightEmission = 1
	crackle.LightInfluence = 0
	crackle.Size = NumberSequence.new(2.2)
	crackle.Lifetime = NumberRange.new(0.08, 0.16)
	crackle.Rotation = NumberRange.new(0, 360)
	crackle.Speed = NumberRange.new(0)
	crackle.Rate = 0
	crackle.Parent = p
	crackle:Emit(6)
end

local function chest(model: Model): Vector3?
	local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	return if root and root:IsA("BasePart") then root.Position + Vector3.new(0, 0.6, 0) else nil
end

local function feet(model: Model): Vector3?
	local root = model:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root.Position - Vector3.new(0, 2.9, 0) else nil
end

-- The orb latched onto `target` at `at`; the strike comes in `warning` s.
function ShockStrikeFx.latch(target: Model, at: Vector3, warning: number, color: Color3)
	local body = chest(target)
	if body then
		zap(at, body, color, 0.35, 0.25)
	end
	sparks(at, color, 10)
	ModAudio.play(S.latch, at)
	local me = Players.LocalPlayer.Character
	if me and target == me then
		ModAudio.play(S.warning) -- 2D: you're marked
	end
	-- the ring under their feet, following them, tightening and flashing faster
	local template = kit("Ring")
	local ring: BasePart
	if template then
		ring = template:Clone()
		ring:ClearAllChildren()
	else
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Cylinder
		ring = p
	end
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = color
	ring.Parent = fxFolder()
	local highlight = Instance.new("Highlight")
	highlight.FillColor = color
	highlight.OutlineTransparency = 1
	highlight.FillTransparency = 1
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Adornee = target
	highlight.Parent = fxFolder()
	local t0 = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local k = (os.clock() - t0) / math.max(warning, 0.05)
		local foot = feet(target)
		if k >= 1 or not foot or not ring.Parent then
			conn:Disconnect()
			ring:Destroy()
			highlight:Destroy()
			return
		end
		local r = 3.2 - 1.4 * k
		if template then
			ring.Size = Vector3.new(r * 2, 0.1, r * 2)
			ring.CFrame = CFrame.new(foot + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, k * 6, 0)
		else
			ring.Size = Vector3.new(0.08, r * 2, r * 2)
			ring.CFrame = CFrame.new(foot + Vector3.new(0, 0.1, 0))
				* CFrame.Angles(0, 0, math.pi / 2)
		end
		local blink = math.sin(os.clock() * (10 + 30 * k)) > 0
		ring.Transparency = if blink then 0.1 else 0.6
		highlight.FillTransparency = if blink then 0.65 else 0.9
	end)
end

-- The lightning lands on the target at `at`, hopping along `chain`, splashing `splash` points.
function ShockStrikeFx.strike(
	at: Vector3,
	color: Color3,
	chain: { Vector3 },
	splash: { Vector3 },
	splashRadius: number?
)
	local top = at + Vector3.new(math.random(-4, 4), SKY, math.random(-4, 4))
	-- the bolt mesh, stretched sky to target, for a few frames
	local template = kit("Bolt")
	if template then
		local bolt = template:Clone()
		bolt:ClearAllChildren()
		bolt.Anchored = true
		bolt.CanCollide = false
		bolt.CanQuery = false
		bolt.CanTouch = false
		bolt.CastShadow = false
		bolt.Material = Enum.Material.Neon
		bolt.Color = WHITE_BLUE
		local length = (top - at).Magnitude
		bolt.Size = Vector3.new(template.Size.X * 5, length, template.Size.Z * 5) -- ~1.3 studs wide at any length
		bolt.CFrame = CFrame.lookAt((top + at) / 2, at) * CFrame.Angles(math.pi / 2, 0, 0)
		bolt.Parent = fxFolder()
		task.delay(0.12, function()
			bolt.Transparency = 0.6
		end)
		task.delay(0.26, function()
			bolt:Destroy()
		end)
	end
	-- crackling beams along the same line, two forks
	zap(top, at, color, 1.1, 0.3)
	zap(top + Vector3.new(2, -10, 1), at, color, 0.5, 0.26)
	-- the flash
	local glow = point(at + Vector3.new(0, 1, 0), 0.35)
	local light = Instance.new("PointLight")
	light.Color = WHITE_BLUE
	light.Range = 26
	light.Brightness = 8
	light.Parent = glow
	task.delay(0.08, function()
		light.Brightness = 3
	end)
	sparks(at, color, 26)
	ModAudio.play(S.strike, at)
	ModAudio.play(S.thunder, at)
	ModAudio.play(S.zap, at)
	-- Chain hops: target to target
	local from = at
	for i, p in chain do
		task.delay(0.08 * i, function()
			zap(from, p, color, 0.6, 0.22)
			sparks(p, color, 14)
			ModAudio.play(S.zap, p)
			from = p
		end)
	end
	-- Overload splash: arcs out to each one caught
	for _, p in splash do
		zap(at, p, color, 0.45, 0.2)
		sparks(p, color, 8)
	end
	if splashRadius and splashRadius > 0 then
		sparks(at, color, 20)
	end
end

function ShockStrikeFx.fizzle(at: Vector3, color: Color3)
	sparks(at, color, 8)
	ModAudio.play(S.fizzle, at)
end

return ShockStrikeFx
