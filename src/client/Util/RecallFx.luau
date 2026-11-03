--!strict
-- The Recall for everyone (vault/01 Design/Abilities/Recall.md → Look, What
-- enemies see and hear): the anchor's soft violet glow, ground halo and hum
-- (its finished model is dressed like any placed Mod object, ModFxController),
-- the violet shimmer on anyone winding up a teleport (read from their
-- RecallWindupUntil), the departure and arrival flashes and sounds, and for
-- us while winding up: the screen warping inward. Textures are the Recall's
-- Blender renders (Config/VfxTextures RECALL_*), tinted violet here.
-- Crash Recovery armed (glitch path, Util/UpgradeFx/Recall): our own anchor
-- glows magenta and sheds glitch static (setArmed).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.Mods)
local ModSounds = require(ReplicatedStorage.Shared.Config.ModSounds)
local VFX = require(ReplicatedStorage.Shared.Config.VfxTextures)

local ModAudio = require(script.Parent.ModAudio)
local ModVfx = require(script.Parent.ModVfx)

local RecallFx = {}

local S = ModSounds.Recall
local player = Players.LocalPlayer

local VIOLET = Color3.fromHex("9B6BFF")
local GLITCH = Config.COLORS.glitch
local HALO_SIZE = 3.5 -- studs across the ground halo under an anchor
local WARP_OUT = TweenInfo.new(0.25)

local function curve(points: { number }): NumberSequence
	local keys = {}
	for i = 1, #points, 2 do
		table.insert(keys, NumberSequenceKeypoint.new(points[i], points[i + 1]))
	end
	return NumberSequence.new(keys)
end

local function fxFolder(): Instance
	local f = Workspace:FindFirstChild("RecallFx")
	if f then
		return f
	end
	local made = Instance.new("Folder")
	made.Name = "RecallFx"
	made.Parent = Workspace
	return made
end

-- A one-shot pop at `at` (a flash, a burst of motes), violet unless `tint`.
local function pop(at: Vector3, size: number, life: number, tint: Color3?)
	local color = tint or VIOLET
	local part = Instance.new("Part")
	part.Name = "RecallPop"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.one * 0.2
	part.CFrame = CFrame.new(at)
	local flash = Instance.new("ParticleEmitter")
	flash.Texture = VFX.RECALL_FLASH
	flash.Color = ColorSequence.new(color)
	flash.LightEmission = 1
	flash.LightInfluence = 0
	flash.Lifetime = NumberRange.new(life)
	flash.Speed = NumberRange.new(0)
	flash.Rotation = NumberRange.new(0, 360)
	flash.Size = curve({ 0, size * 0.4, 0.3, size, 1, size * 1.2 })
	flash.Transparency = curve({ 0, 0, 0.5, 0.3, 1, 1 })
	flash.Rate = 0
	flash.Parent = part
	local motes = Instance.new("ParticleEmitter")
	motes.Texture = VFX.RECALL_MOTE
	motes.Color = ColorSequence.new(color)
	motes.LightEmission = 1
	motes.LightInfluence = 0
	motes.Lifetime = NumberRange.new(0.4, 0.8)
	motes.Speed = NumberRange.new(4, 10)
	motes.SpreadAngle = Vector2.new(180, 180)
	motes.Drag = 4
	motes.Size = curve({ 0, 0.35, 1, 0 })
	motes.Rate = 0
	motes.Parent = part
	part.Parent = fxFolder()
	flash:Emit(1)
	motes:Emit(18)
	task.delay(1, function()
		part:Destroy()
	end)
end

-- Anchors ---------------------------------------------------------------------------

type Anchor = {
	hum: ModAudio.Hum?,
	light: PointLight,
	halo: ModVfx.Handle,
	static: ParticleEmitter?, -- Crash Recovery armed (ours only)
	armed: boolean,
}
local anchors: { [BasePart]: Anchor } = {}
local armed = false -- our Crash Recovery (setArmed)

local function halo(part: BasePart, color: Color3): ModVfx.Handle
	local floor = part.Position - Vector3.new(0, part.Size.Y / 2 - 0.06, 0)
	return ModVfx.quad({
		texture = VFX.RECALL_RING,
		cframe = CFrame.new(floor),
		from = HALO_SIZE,
		color = color,
		life = 3600, -- until the anchor goes (stop)
		alpha0 = 0.35,
		alpha1 = 0.35,
		hold = true,
		spin = 0.6,
	})
end

-- Glitch static flickering off the anchor (magenta fragments).
local function staticOn(part: BasePart): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = "RecallCrashStatic"
	e.Texture = VFX.RECALL_SHIMMER_2x2
	e.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
	e.FlipbookMode = Enum.ParticleFlipbookMode.Random
	e.Color = ColorSequence.new(GLITCH)
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Shape = Enum.ParticleEmitterShape.Box
	e.Lifetime = NumberRange.new(0.08, 0.2)
	e.Speed = NumberRange.new(0)
	e.Rotation = NumberRange.new(0, 360)
	e.Size = curve({ 0, 0.5, 1, 0.3 })
	e.Transparency = curve({ 0, 0.2, 1, 0.8 })
	e.Rate = 14
	e.Parent = part
	return e
end

local function isMine(part: BasePart): boolean
	return part:GetAttribute("OwnerId") == player.UserId
end

local function setUp(part: BasePart)
	local glitched = armed and isMine(part)
	local color = if glitched then GLITCH else VIOLET
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 8
	light.Brightness = 1.2
	light.Shadows = false
	light.Parent = part
	anchors[part] = {
		hum = ModAudio.hum(S.idle, part),
		light = light,
		halo = halo(part, color),
		static = if glitched then staticOn(part) else nil,
		armed = glitched,
	}
end

local function tearDown(part: BasePart)
	local a = anchors[part]
	if not a then
		return
	end
	anchors[part] = nil
	ModAudio.stopHum(a.hum)
	ModVfx.stop(a.halo)
	a.light:Destroy()
	if a.static then
		a.static:Destroy()
	end
end

-- Our anchor's look follows our Crash Recovery: magenta and static while
-- it's armed, violet again once it's spent (the hum carries on).
local function restyle(part: BasePart, a: Anchor)
	local glitched = armed and isMine(part)
	if glitched == a.armed then
		return
	end
	a.armed = glitched
	local color = if glitched then GLITCH else VIOLET
	a.light.Color = color
	ModVfx.stop(a.halo)
	a.halo = halo(part, color)
	if a.static then
		a.static:Destroy()
		a.static = nil
	end
	if glitched then
		a.static = staticOn(part)
	end
end

function RecallFx.setArmed(on: boolean)
	if on == armed then
		return
	end
	armed = on
	for part, a in anchors do
		restyle(part, a)
	end
end

local function stepAnchors()
	for part in anchors do
		if not part:IsDescendantOf(Workspace) then
			tearDown(part)
		end
	end
	local objects = Workspace:FindFirstChild("ModObjects")
	if not objects then
		return
	end
	for _, child in objects:GetChildren() do
		if
			child:IsA("BasePart")
			and child:GetAttribute("Kind") == "Recall"
			and not anchors[child]
		then
			setUp(child)
		end
	end
end

-- The wind-up --------------------------------------------------------------------------

-- The shimmer on anyone winding up (made once per root).
local shimmers: { [BasePart]: ParticleEmitter } = {}

local function shimmerOn(root: BasePart): ParticleEmitter
	local e = shimmers[root]
	if e and e.Parent == root then
		return e
	end
	local made = Instance.new("ParticleEmitter")
	made.Name = "RecallShimmer"
	made.Texture = VFX.RECALL_SHIMMER_2x2
	made.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
	made.FlipbookMode = Enum.ParticleFlipbookMode.Random
	made.Color = ColorSequence.new(VIOLET)
	made.LightEmission = 1
	made.LightInfluence = 0
	made.Shape = Enum.ParticleEmitterShape.Box
	made.Lifetime = NumberRange.new(0.25, 0.45)
	made.Speed = NumberRange.new(0.5, 2)
	made.EmissionDirection = Enum.NormalId.Top
	made.Rotation = NumberRange.new(0, 360)
	made.Size = curve({ 0, 0.4, 0.5, 0.9, 1, 0.2 })
	made.Transparency = curve({ 0, 0.4, 0.3, 0, 1, 1 })
	made.LockedToPart = true
	made.Rate = 0
	made.Parent = root
	shimmers[root] = made
	return made
end

-- Our screen while winding up: streaks pulling in toward the centre.
local warp: ImageLabel? = nil
local warping = false
local windupLength = 0.6 -- ours, from the RecallWindup event

local function warpLabel(): ImageLabel
	local w = warp
	if w and w.Parent then
		return w
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "RecallScreen"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 2
	gui.Parent = player:WaitForChild("PlayerGui")
	local img = Instance.new("ImageLabel")
	img.Name = "Warp"
	img.AnchorPoint = Vector2.new(0.5, 0.5)
	img.Position = UDim2.fromScale(0.5, 0.5)
	img.Size = UDim2.fromScale(1.4, 1.4)
	img.BackgroundTransparency = 1
	img.Image = VFX.RECALL_WARP
	img.ImageColor3 = VIOLET
	img.ImageTransparency = 1
	img.ScaleType = Enum.ScaleType.Stretch
	img.Parent = gui
	warp = img
	return img
end

local function stepShimmers(serverNow: number)
	for root, e in shimmers do
		if not root.Parent then
			e:Destroy()
			shimmers[root] = nil
		end
	end
	for _, other in Players:GetPlayers() do
		local character = other.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not character or not root or not root:IsA("BasePart") then
			continue
		end
		local untilT = character:GetAttribute("RecallWindupUntil")
		local on = typeof(untilT) == "number" and serverNow < untilT
		if on or shimmers[root] then
			shimmerOn(root).Rate = if on then 45 else 0
		end
		if other == player then
			local img = warpLabel()
			if on then
				-- The streaks close in as it charges (0 → 1 over the wind-up).
				local left = (untilT :: number) - serverNow
				local k = 1 - math.clamp(left / windupLength, 0, 1)
				warping = true
				img.ImageTransparency = 0.75 - 0.6 * k
				img.Size = UDim2.fromScale(1.4 - 0.4 * k, 1.4 - 0.4 * k)
			elseif warping then
				warping = false
				TweenService:Create(img, WARP_OUT, { ImageTransparency = 1 }):Play()
			end
		end
	end
end

-- Server events ------------------------------------------------------------------------

function RecallFx.placed(data: { [string]: any })
	if typeof(data.at) == "Vector3" then
		ModAudio.play(S.place, data.at)
	end
end

function RecallFx.pickedUp(data: { [string]: any })
	if typeof(data.at) == "Vector3" then
		ModAudio.play(S.pickUp, data.at)
	end
end

function RecallFx.windup(data: { [string]: any })
	if typeof(data.at) == "Vector3" then
		ModAudio.play(S.windUp, data.at)
	end
	if data.caster == player and typeof(data.duration) == "number" and data.duration > 0 then
		windupLength = data.duration
	end
end

-- The teleport: a pop where they left, a flash and a ring where they land.
function RecallFx.arrive(data: { [string]: any })
	local from, at = data.from, data.at
	if typeof(from) ~= "Vector3" or typeof(at) ~= "Vector3" then
		return
	end
	ModAudio.play(S.depart, from)
	pop(from, 5, 0.3)
	ModAudio.play(S.arrive, at)
	pop(at + Vector3.new(0, 2.5, 0), 7, 0.35)
	ModVfx.quad({
		texture = VFX.RECALL_RING,
		cframe = CFrame.new(at + Vector3.new(0, 0.08, 0)),
		from = 2,
		to = 10,
		color = VIOLET,
		life = 0.45,
		alpha0 = 0,
	})
end

-- Crash Recovery's arrival on the anchor (Util/UpgradeFx/RecallCrash): the
-- arrival flash and ring in `color` (the saved player's team colour), with a
-- magenta glitch ring inside it.
function RecallFx.crashArrive(at: Vector3, color: Color3)
	ModAudio.play(S.arrive, at, 0.8)
	pop(at + Vector3.new(0, 2.5, 0), 8, 0.4, color)
	ModVfx.quad({
		texture = VFX.RECALL_RING,
		cframe = CFrame.new(at + Vector3.new(0, 0.08, 0)),
		from = 2,
		to = 12,
		color = color,
		life = 0.5,
		alpha0 = 0,
	})
	ModVfx.quad({
		texture = VFX.RECALL_RING,
		cframe = CFrame.new(at + Vector3.new(0, 0.1, 0)),
		from = 1,
		to = 7,
		color = GLITCH,
		life = 0.3,
		alpha0 = 0,
		pulse = 0.6,
	})
end

-- Per frame (ModFxController.update).
function RecallFx.step()
	stepAnchors()
	stepShimmers(Workspace:GetServerTimeNow())
end

return RecallFx
