--!strict
-- The Heal Orb for everyone (vault/01 Design/Abilities/Heal Orb.md → Look):
-- a ribbon of light streaming from the caster to the ally (or a burst of
-- light around you on a self-heal), then on the healed player for the heal's
-- duration a rising green-teal glow, motes and a soft ring (everyone sees who
-- is being healed), and on the healed player's own screen a soft edge glow.
-- The healing is soft green-teal for every viewer (not a team colour).
-- Textures: the Heal Orb's Blender renders (Config/VfxTextures HEALORB_*).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local VFX = require(ReplicatedStorage.Shared.Config.VfxTextures)

local ModVfx = require(script.Parent.ModVfx)

local HealFx = {}

local player = Players.LocalPlayer

local HEAL = Color3.fromHex("5CFFC8")
local RIBBON_TIME = 0.55
local EDGE_IN = TweenInfo.new(0.25)
local EDGE_OUT = TweenInfo.new(0.5)

local function curve(points: { number }): NumberSequence
	local keys = {}
	for i = 1, #points, 2 do
		table.insert(keys, NumberSequenceKeypoint.new(points[i], points[i + 1]))
	end
	return NumberSequence.new(keys)
end

local function rootOf(model: Model?): BasePart?
	local r = model and model:FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r else nil
end

-- The glow on a healed body: motes and wisps rising (made once per root).
type Glow = { motes: ParticleEmitter, wisps: ParticleEmitter, untilT: number }
local glows: { [BasePart]: Glow } = {}

-- Our screen's edge glow while we're being healed (made once).
local edge: ImageLabel? = nil
local edgeUntil = -math.huge

local function glowOn(root: BasePart): Glow
	local g = glows[root]
	if g and g.motes.Parent == root then
		return g
	end
	local motes = Instance.new("ParticleEmitter")
	motes.Name = "HealMotes"
	motes.Texture = VFX.HEALORB_MOTE
	motes.Color = ColorSequence.new(HEAL)
	motes.Shape = Enum.ParticleEmitterShape.Box
	motes.Lifetime = NumberRange.new(0.8, 1.3)
	motes.Speed = NumberRange.new(2, 4)
	motes.EmissionDirection = Enum.NormalId.Top
	motes.SpreadAngle = Vector2.new(15, 15)
	motes.Size = curve({ 0, 0.25, 1, 0.08 })
	motes.Transparency = curve({ 0, 0.2, 1, 1 })
	motes.LightEmission = 1
	motes.LightInfluence = 0
	motes.Rate = 0
	motes.Parent = root
	local wisps = Instance.new("ParticleEmitter")
	wisps.Name = "HealWisps"
	wisps.Texture = VFX.HEALORB_WISP_2x2
	wisps.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
	wisps.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	wisps.Color = ColorSequence.new(HEAL)
	wisps.Shape = Enum.ParticleEmitterShape.Box
	wisps.Lifetime = NumberRange.new(0.9, 1.2)
	wisps.Speed = NumberRange.new(1.5, 3)
	wisps.EmissionDirection = Enum.NormalId.Top
	wisps.Size = curve({ 0, 0.8, 1, 1.4 })
	wisps.Transparency = curve({ 0, 1, 0.25, 0.4, 1, 1 })
	wisps.LightEmission = 0.8
	wisps.LightInfluence = 0
	wisps.Rotation = NumberRange.new(0, 360)
	wisps.Rate = 0
	wisps.Parent = root
	local made = { motes = motes, wisps = wisps, untilT = 0 }
	glows[root] = made
	return made
end

-- The ribbon of light from `from` to `to`, gone after RIBBON_TIME.
local function ribbon(from: BasePart, to: BasePart)
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.6, -0.8)
	a0.Parent = from
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, 0.3, 0)
	a1.Parent = to
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Texture = VFX.HEALORB_RIBBON
	beam.TextureMode = Enum.TextureMode.Stretch
	beam.TextureSpeed = 2.5
	beam.Color = ColorSequence.new(HEAL)
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.FaceCamera = true
	beam.Width0 = 0.7
	beam.Width1 = 0.5
	beam.Segments = 12
	beam.CurveSize0 = 2
	beam.CurveSize1 = -1
	beam.Transparency = NumberSequence.new(0.1)
	beam.Parent = a0
	local fade = TweenService:Create(beam, TweenInfo.new(RIBBON_TIME), { Width0 = 0, Width1 = 0 })
	fade:Play()
	task.delay(RIBBON_TIME, function()
		a0:Destroy()
		a1:Destroy()
	end)
end

-- The soft burst when an orb is pressed into your own chest.
local function burst(root: BasePart)
	local a = Instance.new("Attachment")
	a.Position = Vector3.new(0, 0.4, 0)
	a.Parent = root
	local e = Instance.new("ParticleEmitter")
	e.Texture = VFX.HEALORB_BURST_2x2
	e.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
	e.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	e.Color = ColorSequence.new(HEAL)
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Lifetime = NumberRange.new(0.5)
	e.Speed = NumberRange.new(0)
	e.Size = curve({ 0, 2.5, 1, 4 })
	e.Transparency = curve({ 0, 0.1, 1, 0.6 })
	e.Rotation = NumberRange.new(0, 360)
	e.Rate = 0
	e.Parent = a
	e:Emit(1)
	task.delay(0.6, function()
		a:Destroy()
	end)
end

-- Turns the glow on `target` off now (the heal was cut short: they died).
function HealFx.stop(target: Model)
	local root = rootOf(target)
	local g = root and glows[root]
	if g then
		g.untilT = 0
	end
	if target == player.Character then
		edgeUntil = 0
	end
end

-- Our screen while we're being healed.

local function screenEdge(): ImageLabel
	local e = edge
	if e and e.Parent then
		return e
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "HealScreen"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 2
	gui.Parent = player:WaitForChild("PlayerGui")
	local img = Instance.new("ImageLabel")
	img.Size = UDim2.fromScale(1, 1)
	img.BackgroundTransparency = 1
	img.Image = VFX.HEALORB_EDGE
	img.ImageColor3 = HEAL
	img.ImageTransparency = 1
	img.ScaleType = Enum.ScaleType.Stretch
	img.Parent = gui
	edge = img
	return img
end

-- A heal starts on `target` for `duration` s, sent by `caster` (nil or the
-- target itself: a self-heal).
function HealFx.start(target: Model, caster: Model?, duration: number)
	local root = rootOf(target)
	if not root then
		return
	end
	local fromRoot = rootOf(caster)
	if fromRoot and caster ~= target then
		ribbon(fromRoot, root)
	else
		burst(root)
		ModVfx.burst(root.Position, HEAL, 10, "Sparkle")
	end
	ModVfx.quad({
		texture = VFX.HEALORB_RING,
		cframe = CFrame.new(root.Position - Vector3.new(0, 2.9, 0)),
		from = 2,
		to = 7,
		color = HEAL,
		life = 0.8,
		alpha0 = 0.1,
	})
	local g = glowOn(root)
	g.untilT = os.clock() + duration
	g.motes.Rate = 18
	g.wisps.Rate = 6
	if target == player.Character then
		edgeUntil = os.clock() + duration
		TweenService:Create(screenEdge(), EDGE_IN, { ImageTransparency = 0.35 }):Play()
	end
end

-- Per frame (ModFxController.update).
function HealFx.step()
	local now = os.clock()
	for root, g in glows do
		if now >= g.untilT and g.motes.Rate > 0 then
			g.motes.Rate = 0
			g.wisps.Rate = 0
		end
		if not root.Parent then
			g.motes:Destroy()
			g.wisps:Destroy()
			glows[root] = nil
		end
	end
	local e = edge
	if e and now >= edgeUntil and e.ImageTransparency < 1 and e:GetAttribute("Fading") ~= true then
		e:SetAttribute("Fading", true)
		local t = TweenService:Create(e, EDGE_OUT, { ImageTransparency = 1 })
		t.Completed:Once(function()
			e:SetAttribute("Fading", nil)
		end)
		t:Play()
	end
end

return HealFx
