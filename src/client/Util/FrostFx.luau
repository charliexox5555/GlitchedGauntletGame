--!strict
-- The Frost and its Hinder for everyone (vault/01 Design/Abilities/Frost.md
-- → Look, Screen): the burst (an icy mist explosion, a crystalline flash, ice
-- shards, frost spreading on the floor and fading after a few seconds), the
-- frost crystals and cold mist on anyone hindered (players and dummies, read
-- from their HinderedUntil), and for us while hindered: an icy screen-edge
-- vignette, a cold loop, and the thaw when it ends. Textures are the Frost's
-- Blender renders (Config/VfxTextures FROST_*), tinted cold blue here.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ModSounds = require(ReplicatedStorage.Shared.Config.ModSounds)
local Status = require(ReplicatedStorage.Shared.Mods.Status)
local VFX = require(ReplicatedStorage.Shared.Config.VfxTextures)

local ModAudio = require(script.Parent.ModAudio)
local ModVfx = require(script.Parent.ModVfx)

local FrostFx = {}

local S = ModSounds.Frost
local player = Players.LocalPlayer

local ICE = Color3.fromHex("BFE8FF")
local GROUND_TIME = 3.5 -- the frost on the floor lingers, then fades
local VIGNETTE_IN = TweenInfo.new(0.2)
local VIGNETTE_OUT = TweenInfo.new(0.5)

local function curve(points: { number }): NumberSequence
	local keys = {}
	for i = 1, #points, 2 do
		table.insert(keys, NumberSequenceKeypoint.new(points[i], points[i + 1]))
	end
	return NumberSequence.new(keys)
end

-- The burst's emitters (one shared part, moved to each burst).
type Burst = {
	part: Part,
	mist: ParticleEmitter,
	flash: ParticleEmitter,
	shards: ParticleEmitter,
	light: PointLight,
}
local burstRig: Burst? = nil

local function emitter(parent: Instance, texture: string): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = texture
	e.Rate = 0
	e.LockedToPart = false
	e.LightInfluence = 0.3
	e.Color = ColorSequence.new(ICE)
	e.Parent = parent
	return e
end

local function rig(): Burst
	local r = burstRig
	if r and r.part.Parent then
		return r
	end
	local part = Instance.new("Part")
	part.Name = "FrostBurst"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.CFrame = CFrame.new(0, -10000, 0)
	part.Parent = Workspace:FindFirstChild("Effects") or Workspace

	local mist = emitter(part, VFX.FROST_MIST_2x2)
	mist.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
	mist.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	mist.Lifetime = NumberRange.new(1, 1.6)
	mist.Speed = NumberRange.new(10, 18)
	mist.Drag = 3
	mist.SpreadAngle = Vector2.new(180, 30)
	mist.EmissionDirection = Enum.NormalId.Top
	mist.Size = curve({ 0, 3, 1, 9 })
	mist.Transparency = curve({ 0, 0.2, 0.6, 0.55, 1, 1 })
	mist.Rotation = NumberRange.new(0, 360)
	mist.RotSpeed = NumberRange.new(-30, 30)
	mist.LightEmission = 0.15

	local flash = emitter(part, VFX.FROST_BURST_2x2)
	flash.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
	flash.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	flash.Lifetime = NumberRange.new(0.22)
	flash.Speed = NumberRange.new(0)
	flash.Size = curve({ 0, 10, 1, 18 })
	flash.Transparency = curve({ 0, 0, 0.7, 0.2, 1, 1 })
	flash.LightEmission = 1
	flash.Brightness = 2
	flash.LightInfluence = 0
	flash.Orientation = Enum.ParticleOrientation.FacingCamera

	local shards = emitter(part, VFX.FROST_SHARD)
	shards.Lifetime = NumberRange.new(0.4, 0.8)
	shards.Speed = NumberRange.new(14, 28)
	shards.Drag = 2
	shards.Acceleration = Vector3.new(0, -30, 0)
	shards.SpreadAngle = Vector2.new(180, 60)
	shards.EmissionDirection = Enum.NormalId.Top
	shards.Size = curve({ 0, 0.35, 1, 0.1 })
	shards.Transparency = curve({ 0, 0, 0.8, 0.2, 1, 1 })
	shards.LightEmission = 0.9
	shards.LightInfluence = 0
	shards.Rotation = NumberRange.new(0, 360)
	shards.RotSpeed = NumberRange.new(-200, 200)

	local light = Instance.new("PointLight")
	light.Color = ICE
	light.Brightness = 0
	light.Range = 24
	light.Shadows = false
	light.Parent = part

	local made = { part = part, mist = mist, flash = flash, shards = shards, light = light }
	burstRig = made
	return made
end

-- The canister burst at `at` (the floor).
function FrostFx.burst(at: Vector3, radius: number)
	local r = rig()
	r.part.CFrame = CFrame.new(at + Vector3.new(0, 0.5, 0))
	r.mist.Speed = NumberRange.new(radius * 1.1, radius * 1.9)
	r.mist:Emit(14)
	r.flash:Emit(1)
	r.shards:Emit(24)
	r.light.Brightness = 5
	TweenService:Create(r.light, TweenInfo.new(0.5), { Brightness = 0 }):Play()
	ModAudio.play(S.burst, at)
	ModAudio.play(S.burstCrackle, at)
	-- Frost spreading on the floor, then fading.
	ModVfx.quad({
		texture = VFX.FROST_GROUND,
		cframe = CFrame.new(at + Vector3.new(0, 0.05, 0)),
		from = radius * 0.6,
		to = radius * 2,
		color = Color3.new(1, 1, 1),
		life = GROUND_TIME,
		alpha0 = 0.05,
		hold = true,
	})
end

-- Still flying at the end of its path: a little puff, nothing else.
function FrostFx.fizzle(at: Vector3)
	local r = rig()
	r.part.CFrame = CFrame.new(at)
	r.mist.Speed = NumberRange.new(3, 6)
	r.mist:Emit(3)
end

-- Frost on anyone hindered: crystals and cold mist on the body.
type Body = { crystals: ParticleEmitter, mist: ParticleEmitter, root: BasePart }
local bodies: { [Model]: Body } = setmetatable({}, { __mode = "k" }) :: any

local function bodyOf(model: Model, root: BasePart): Body
	local b = bodies[model]
	if b and b.root == root and b.crystals.Parent then
		return b
	end
	local existing = root:FindFirstChild("FrostCrystals")
	local crystals: ParticleEmitter
	local mist: ParticleEmitter
	if existing and existing:IsA("ParticleEmitter") then
		crystals = existing
		local m = root:FindFirstChild("FrostMist")
		mist = if m and m:IsA("ParticleEmitter") then m else emitter(root, VFX.FROST_MIST_2x2)
	else
		crystals = emitter(root, VFX.FROST_CRYSTALS)
		crystals.Name = "FrostCrystals"
		crystals.Shape = Enum.ParticleEmitterShape.Box
		crystals.Lifetime = NumberRange.new(0.5, 0.9)
		crystals.Speed = NumberRange.new(0)
		crystals.Size = curve({ 0, 0.6, 0.5, 1, 1, 0.6 })
		crystals.Transparency = curve({ 0, 1, 0.2, 0.15, 0.8, 0.25, 1, 1 })
		crystals.LightEmission = 0.5
		crystals.Rotation = NumberRange.new(0, 360)
		crystals.LockedToPart = true
		mist = emitter(root, VFX.FROST_MIST_2x2)
		mist.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
		mist.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
		mist.Shape = Enum.ParticleEmitterShape.Box
		mist.Lifetime = NumberRange.new(0.9, 1.3)
		mist.Speed = NumberRange.new(0.5, 1.5)
		mist.Acceleration = Vector3.new(0, -1, 0) -- cold air sinks
		mist.Size = curve({ 0, 0.8, 1, 1.6 })
		mist.Transparency = curve({ 0, 1, 0.3, 0.6, 1, 1 })
	end
	mist.Name = "FrostMist"
	local made = { crystals = crystals, mist = mist, root = root }
	bodies[model] = made
	return made
end

-- Our screen while hindered.
local vignette: ImageLabel? = nil
local hinderedNow = false
local coldHum: ModAudio.Hum? = nil

local function screen(): ImageLabel
	local v = vignette
	if v and v.Parent then
		return v
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "FrostScreen"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 2
	gui.Parent = player:WaitForChild("PlayerGui")
	local img = Instance.new("ImageLabel")
	img.Name = "Vignette"
	img.Size = UDim2.fromScale(1, 1)
	img.BackgroundTransparency = 1
	img.Image = VFX.FROST_VIGNETTE
	img.ImageColor3 = ICE
	img.ImageTransparency = 1
	img.ScaleType = Enum.ScaleType.Stretch
	img.Parent = gui
	vignette = img
	return img
end

local function setHindered(on: boolean)
	TweenService:Create(screen(), if on then VIGNETTE_IN else VIGNETTE_OUT, {
		ImageTransparency = if on then 0.15 else 1,
	}):Play()
	if on then
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		ModAudio.stopHum(coldHum)
		coldHum = ModAudio.hum(S.hinderedLoop, root)
	else
		ModAudio.stopHum(coldHum)
		coldHum = nil
		ModAudio.play(S.recover)
	end
end

-- Per frame (ModFxController.update).
function FrostFx.step()
	local serverNow = Workspace:GetServerTimeNow()
	local function check(model: Instance)
		if not model:IsA("Model") then
			return
		end
		local on = Status.active(model, "Hinder", serverNow)
		local b = bodies[model]
		if not on and not b then
			return
		end
		local root = model:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			return
		end
		local body = bodyOf(model, root)
		body.crystals.Rate = if on then 16 else 0
		body.mist.Rate = if on then 5 else 0
	end
	for _, other in Players:GetPlayers() do
		local character = other.Character
		if character then
			check(character)
		end
	end
	local dummies = Workspace:FindFirstChild("Dummies")
	if dummies then
		for _, d in dummies:GetChildren() do
			check(d)
		end
	end
	local mine = Status.active(player.Character, "Hinder", serverNow)
	if mine ~= hinderedNow then
		hinderedNow = mine
		setHindered(mine)
	end
end

-- Seconds of Hinder we have left (0 = none), for the HUD.
function FrostFx.hinderedLeft(): number
	return math.max(Status.until_(player.Character, "Hinder") - Workspace:GetServerTimeNow(), 0)
end

return FrostFx
