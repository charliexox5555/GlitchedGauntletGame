--!strict
-- The Frost and its Hinder for everyone (vault/01 Design/Abilities/Frost.md
-- → Look, Screen): the burst (an icy mist explosion, a crystalline flash, ice
-- shards, frost spreading on the floor and fading after a few seconds), the
-- frost crystals and cold mist on anyone hindered (players and dummies, read
-- from their HinderedUntil), and for us while hindered: an icy screen-edge
-- vignette, a cold loop, and the thaw when it ends.
--
-- Stylized look (2026-11-03, Util/IceKit): faceted Blender crystals instead of
-- realistic mist. The burst is a crisp ring snapping out, a faceted frost
-- patch with glowing cracks, a crystal cluster bursting up at the centre and
-- a ring of crystal spikes, all sinking back into the floor; a hindered body
-- has a few crystals and a small frost patch at its feet that shatter off
-- when it ends. A puff of mist and a few sparkles are the only particles.
-- Until ReplicatedStorage.Abilities.IceVFX is installed it falls back to the
-- older look from the Frost's Blender renders (Config/VfxTextures FROST_*).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ModSounds = require(ReplicatedStorage.Shared.Config.ModSounds)
local Status = require(ReplicatedStorage.Shared.Mods.Status)
local VFX = require(ReplicatedStorage.Shared.Config.VfxTextures)

local IceKit = require(script.Parent.IceKit)
local ModAudio = require(script.Parent.ModAudio)
local ModVfx = require(script.Parent.ModVfx)

local FrostFx = {}

local S = ModSounds.Frost
local player = Players.LocalPlayer

local ICE = Color3.fromHex("BFE8FF")
local DEEP = Color3.fromHex("7FD4FF") -- every other crystal: a deeper blue
local CRACK = Color3.fromHex("E8F8FF") -- the ring and the cracks glow ice white
local GROUND_TIME = 3.5 -- the frost on the floor lingers, then fades
local rng = Random.new()
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

-- The stylized burst from the ice kit; false when it isn't installed.
local function kitBurst(at: Vector3, radius: number): boolean
	if not IceKit.ready() then
		return false
	end
	local floor = CFrame.new(at + Vector3.new(0, 0.02, 0)) * IceKit.yaw(rng)
	local flat = Vector3.new(radius, 1.5, radius)
	-- The frost patch and its cracks snap out under the ring.
	IceKit.spawn({
		name = "Floor",
		at = floor,
		scale = flat,
		color = ICE,
		alpha = 0.35,
		life = GROUND_TIME,
		from = 0.3,
		grow = 0.15,
		fade = 0.6,
	})
	IceKit.spawn({
		name = "Cracks_Energy",
		at = floor,
		scale = flat,
		color = CRACK,
		material = Enum.Material.Neon,
		alpha = 0.15,
		life = 1,
		from = 0.3,
		grow = 0.15,
		fade = 0.6,
	})
	IceKit.spawn({
		name = "Ring_Energy",
		at = floor * IceKit.yaw(rng),
		scale = flat,
		color = CRACK,
		material = Enum.Material.Neon,
		life = 0.45,
		from = 0.25,
		grow = 0.16,
		fade = 0.25,
	})
	-- A crystal cluster bursts up at the centre, spikes around it.
	local big = math.sqrt(radius / 10)
	IceKit.spawn({
		name = "Cluster",
		at = floor,
		scale = Vector3.one * 2.6 * big,
		color = ICE,
		alpha = 0.1,
		life = 1.2,
		from = 0.1,
		grow = 0.12,
		snap = true,
		fade = 0.35,
		sink = 2.8 * big,
	})
	local count = math.clamp(math.floor(radius * 0.7), 6, 12)
	for i = 1, count do
		local angle = (i + rng:NextNumber(-0.3, 0.3)) / count * math.pi * 2
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local dist = radius * rng:NextNumber(0.35, 0.7)
		local len = rng:NextNumber(1.6, 2.6) * big
		local base = at + out * dist
		IceKit.spawn({
			name = IceKit.pick(rng, IceKit.SHARDS),
			at = CFrame.lookAt(base, base + out)
				* CFrame.Angles(-math.rad(rng:NextNumber(20, 35)), rng:NextNumber(0, math.pi), 0),
			scale = Vector3.new(len * 1.2, len, len * 1.2),
			color = if i % 2 == 0 then DEEP else ICE,
			alpha = 0.1,
			delay = dist / radius * 0.08,
			life = 0.9,
			from = 0.05,
			grow = 0.1,
			snap = true,
			fade = 0.3,
			sink = len,
		})
	end
	ModVfx.shell({
		shape = Enum.PartType.Ball,
		cframe = CFrame.new(at + Vector3.new(0, 1, 0)),
		from = Vector3.one * 2,
		to = Vector3.one * radius * 0.6,
		color = ICE,
		life = 0.14,
		alpha0 = 0.3,
		material = Enum.Material.Neon,
	})
	ModVfx.burst(at + Vector3.new(0, 1, 0), ICE, 12, "Sparkle")
	return true
end

-- The canister burst at `at` (the floor).
function FrostFx.burst(at: Vector3, radius: number)
	local r = rig()
	r.part.CFrame = CFrame.new(at + Vector3.new(0, 0.5, 0))
	r.mist.Speed = NumberRange.new(radius * 1.1, radius * 1.9)
	r.light.Brightness = 5
	TweenService:Create(r.light, TweenInfo.new(0.5), { Brightness = 0 }):Play()
	ModAudio.play(S.burst, at)
	ModAudio.play(S.burstCrackle, at)
	if kitBurst(at, radius) then
		r.mist:Emit(4) -- just a soft puff under the crystals
		return
	end
	r.mist:Emit(14)
	r.flash:Emit(1)
	r.shards:Emit(24)
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

-- Frost on anyone hindered: crystals and cold mist on the body (with the kit:
-- crystals and a frost patch at the feet, and much less mist).
type Ice = { part: BasePart, rel: CFrame, scale: Vector3 }
type Body = {
	crystals: ParticleEmitter,
	mist: ParticleEmitter,
	root: BasePart,
	ice: { Ice }?,
	iceBorn: number,
	seen: number, -- the last step that checked it
}
local bodies: { [Model]: Body } = setmetatable({}, { __mode = "k" }) :: any

local FEET_ICE = 3 -- crystals at a hindered body's feet
local ICE_GROW = 0.15

-- From the root down to the floor under the body.
local function feetOf(model: Instance, root: BasePart): CFrame
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local hip = if humanoid then humanoid.HipHeight else 2
	return root.CFrame * CFrame.new(0, -(hip + root.Size.Y / 2), 0)
end

-- Takes the feet ice off (`shatter`: it breaks off in a few chips).
local function freeIce(b: Body, shatter: boolean)
	local ice = b.ice
	if not ice then
		return
	end
	b.ice = nil
	for _, piece in ice do
		IceKit.release(piece.part)
	end
	local model = b.root.Parent
	if not shatter or not model then
		return
	end
	local at = feetOf(model, b.root).Position + Vector3.new(0, 0.6, 0)
	for i = 1, 3 do
		local dir = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1))
		IceKit.spawn({
			name = IceKit.FRAGMENTS[i],
			at = CFrame.new(at) * IceKit.yaw(rng),
			scale = Vector3.one * rng:NextNumber(0.35, 0.55),
			color = ICE,
			alpha = 0.1,
			life = 0.5,
			fade = 0.2,
			velocity = dir * 8 + Vector3.new(0, rng:NextNumber(8, 14), 0),
			spin = Vector3.new(rng:NextNumber(-9, 9), rng:NextNumber(-9, 9), 0),
		})
	end
end

-- Crystals and a frost patch at the feet (false: the kit isn't installed).
local function holdIce(b: Body, model: Model): boolean
	local ice = b.ice
	if not ice then
		if not IceKit.ready() then
			return false
		end
		local patch = IceKit.acquire("Floor")
		if not patch then
			return false
		end
		patch.Color = ICE
		patch.Material = Enum.Material.SmoothPlastic
		patch.Transparency = 0.4
		local made: { Ice } = {
			{
				part = patch,
				rel = CFrame.new(0, 0.03, 0) * IceKit.yaw(rng),
				scale = Vector3.new(1.7, 1.5, 1.7),
			},
		}
		for i = 1, FEET_ICE do
			local p = IceKit.acquire(IceKit.SHARDS[i])
			if p then
				local angle = (i + rng:NextNumber(-0.25, 0.25)) / FEET_ICE * math.pi * 2
				local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
				local len = rng:NextNumber(0.9, 1.4)
				p.Color = if i == 2 then DEEP else ICE
				p.Material = Enum.Material.SmoothPlastic
				p.Transparency = 0.1
				table.insert(made, {
					part = p,
					rel = CFrame.lookAt(out * 0.8, out * 2)
						* CFrame.Angles(-math.rad(rng:NextNumber(25, 40)), 0, 0),
					scale = Vector3.new(len * 1.2, len, len * 1.2),
				})
			end
		end
		ice = made
		b.ice = made
		b.iceBorn = os.clock()
	end
	local feet = feetOf(model, b.root)
	local x = math.clamp((os.clock() - b.iceBorn) / ICE_GROW, 0, 1)
	local grow = 0.1 + 0.9 * (1 - (1 - x) * (1 - x))
	for _, piece in ice do
		IceKit.place(piece.part, feet * piece.rel, piece.scale * grow)
	end
	return true
end

local function bodyOf(model: Model, root: BasePart): Body
	local b = bodies[model]
	if b and b.root == root and b.crystals.Parent then
		return b
	end
	if b then
		freeIce(b, false) -- a new character: the old feet ice goes
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
	local made = { crystals = crystals, mist = mist, root = root, ice = nil, iceBorn = 0, seen = 0 }
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

local stepCount = 0

-- Per frame (ModFxController.update). Also animates the ice kit's timed
-- pieces for every ice effect (Util/IceKit).
function FrostFx.step()
	IceKit.step()
	stepCount += 1
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
		body.seen = stepCount
		local kit = on and holdIce(body, model)
		if not on then
			freeIce(body, true)
		end
		body.crystals.Rate = if on and not kit then 16 else 0
		body.mist.Rate = if not on then 0 elseif kit then 2 else 5
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
	-- A body gone from the world (a dummy removed, a player left) drops its ice.
	for _, b in bodies do
		if b.ice and b.seen ~= stepCount then
			freeIce(b, false)
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
