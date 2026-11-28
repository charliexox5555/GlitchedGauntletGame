--!strict
-- Frostbite Legendary world & first-person shot VFX:
--   - FrostbiteFx.splash: icy wall impact shatter (flipbook burst + shockwave ring +
--     flying diamond ice splinters + sub-zero mist + surface frost feather decal + cold light).
--   - FrostbiteFx.killBurst: dramatic world cryo shatter where a victim dies (nova ring +
--     big icy burst + 18-24 tumbling 3D ice shards + billowing frost vapor + glints + light).
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local UiMotion = require(Shared.UiMotion)
local VFX = require(Shared.Config.VfxTextures)

local FrostbiteFx = {}

local ICE_WHITE = Color3.fromHex("ECFDFF")
local CRYO_CYAN = Color3.fromHex("A6F2FF")
local GLACIER_BLUE = Color3.fromHex("3FB8F0")
local FROST_DECAL = Color3.fromHex("B8EEFF")
local DEEP_ICE = Color3.fromHex("16538A")

local function seq(points: { { number } }): NumberSequence
	local kps = {}
	for _, p in points do
		table.insert(kps, NumberSequenceKeypoint.new(p[1], p[2]))
	end
	return NumberSequence.new(kps)
end

local function emitter(parent: Instance, name: string, texture: string): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Texture = texture
	e.Enabled = false
	e.Rate = 0
	e.LightInfluence = 0
	e.LightEmission = 1
	e.LockedToPart = true
	e.Parent = parent
	return e
end

local SPLASH_CAP = 8
local liveSplashes = 0

function FrostbiteFx.splash(position: Vector3, normal: Vector3)
	if liveSplashes >= SPLASH_CAP then
		return
	end
	liveSplashes += 1
	task.delay(0.75, function()
		liveSplashes -= 1
	end)

	local part = Instance.new("Part")
	part.Name = "FrostbiteSplash"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(0.05, 0.05, 0.05)
	part.CFrame = CFrame.lookAt(position + normal * 0.02, position + normal * 1.02)

	local at = Instance.new("Attachment")
	at.Parent = part

	local core = emitter(at, "FrostbiteImpactBurst", VFX.FROST_BURST_2x2)
	core.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
	core.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	core.Color = ColorSequence.new(ICE_WHITE, GLACIER_BLUE)
	core.Brightness = 2.0
	core.Lifetime = NumberRange.new(0.08, 0.13)
	core.Speed = NumberRange.new(0)
	core.Rotation = NumberRange.new(0, 360)
	core.Size = seq({ { 0, 0.34 }, { 0.35, 0.72 }, { 1, 0.14 } })
	core.Transparency = seq({ { 0, 0 }, { 0.52, 0.18 }, { 1, 1 } })

	local ring = emitter(at, "FrostbiteImpactRing", VFX.T_RING)
	ring.Color = ColorSequence.new(CRYO_CYAN, GLACIER_BLUE)
	ring.Brightness = 1.65
	ring.Lifetime = NumberRange.new(0.18)
	ring.Speed = NumberRange.new(0.05)
	ring.EmissionDirection = Enum.NormalId.Front
	ring.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
	ring.Rotation = NumberRange.new(0, 360)
	ring.Size = seq({ { 0, 0.20 }, { 1, 0.88 } })
	ring.Transparency = seq({ { 0, 0.08 }, { 0.58, 0.32 }, { 1, 1 } })

	local chips = emitter(at, "FrostbiteImpactChips", VFX.T_CHIP)
	chips.LockedToPart = false
	chips.Color = ColorSequence.new(ICE_WHITE, GLACIER_BLUE)
	chips.LightEmission = 0.65
	chips.LightInfluence = 0.25
	chips.Brightness = 1.65
	chips.Lifetime = NumberRange.new(0.20, 0.38)
	chips.Speed = NumberRange.new(5, 11)
	chips.Drag = 6
	chips.Acceleration = Vector3.new(0, -14, 0)
	chips.SpreadAngle = Vector2.new(64, 64)
	chips.EmissionDirection = Enum.NormalId.Front
	chips.Rotation = NumberRange.new(-180, 180)
	chips.RotSpeed = NumberRange.new(-320, 320)
	chips.Size = seq({ { 0, 0.085 }, { 0.55, 0.055 }, { 1, 0 } })
	chips.Transparency = seq({ { 0, 0 }, { 0.65, 0.24 }, { 1, 1 } })

	local shards = emitter(at, "FrostbiteImpactShards", VFX.FROST_SHARD)
	shards.LockedToPart = false
	shards.Color = ColorSequence.new(ICE_WHITE, CRYO_CYAN)
	shards.Brightness = 1.85
	shards.Lifetime = NumberRange.new(0.14, 0.28)
	shards.Speed = NumberRange.new(6.5, 13)
	shards.Drag = 7
	shards.Acceleration = Vector3.new(0, -10, 0)
	shards.SpreadAngle = Vector2.new(54, 54)
	shards.EmissionDirection = Enum.NormalId.Front
	shards.Orientation = Enum.ParticleOrientation.VelocityParallel
	shards.Size = seq({ { 0, 0.07 }, { 1, 0.015 } })
	shards.Transparency = seq({ { 0, 0 }, { 0.6, 0.25 }, { 1, 1 } })

	local mist = emitter(at, "FrostbiteImpactMist", VFX.FROST_MIST_2x2)
	mist.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
	mist.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	mist.LockedToPart = false
	mist.Color = ColorSequence.new(CRYO_CYAN, DEEP_ICE)
	mist.LightEmission = 0.38
	mist.Brightness = 1.15
	mist.Lifetime = NumberRange.new(0.30, 0.48)
	mist.Speed = NumberRange.new(0.9, 2.0)
	mist.Drag = 4
	mist.Acceleration = Vector3.new(0, -0.75, 0)
	mist.SpreadAngle = Vector2.new(36, 36)
	mist.EmissionDirection = Enum.NormalId.Front
	mist.Rotation = NumberRange.new(0, 360)
	mist.Size = seq({ { 0, 0.16 }, { 0.5, 0.38 }, { 1, 0.56 } })
	mist.Transparency = seq({ { 0, 0.52 }, { 0.45, 0.72 }, { 1, 1 } })

	local light = Instance.new("PointLight")
	light.Name = "FrostbiteImpactLight"
	light.Color = GLACIER_BLUE
	light.Brightness = 1.45
	light.Range = 5.5
	light.Shadows = false
	light.Parent = at

	part.Parent = Workspace
	core:Emit(1)
	ring:Emit(1)
	mist:Emit(1)
	if not UiMotion.reduced() then
		chips:Emit(math.random(4, 6))
		shards:Emit(math.random(3, 5))
	end
	task.delay(0.08, function()
		if light.Parent then
			light.Enabled = false
		end
	end)

	local plate = Instance.new("Part")
	plate.Name = "FrostbiteImpactMark"
	plate.Anchored = true
	plate.CanCollide = false
	plate.CanQuery = false
	plate.CanTouch = false
	plate.Transparency = 1
	plate.Size = Vector3.new(0.68, 0.68, 0.01)
	plate.CFrame = CFrame.lookAt(position + normal * 0.014, position + normal * 1.014)
		* CFrame.Angles(0, math.pi, math.random() * 2 * math.pi)
	local mark = Instance.new("Decal")
	mark.Texture = VFX.FROST_GROUND
	mark.Face = Enum.NormalId.Front
	mark.Color3 = FROST_DECAL
	mark.Transparency = 0.14
	mark.Parent = plate
	plate.Parent = Workspace
	task.delay(0.85, function()
		if plate.Parent then
			for i = 1, 6 do
				mark.Transparency = 0.14 + 0.86 * i / 6
				task.wait(0.04)
			end
			plate:Destroy()
		end
	end)

	Debris:AddItem(part, 0.75)
end

local KILL_CAP = 4
local liveKills = 0

function FrostbiteFx.killBurst(position: Vector3)
	if liveKills >= KILL_CAP then
		return
	end
	liveKills += 1
	task.delay(1.2, function()
		liveKills -= 1
	end)

	local part = Instance.new("Part")
	part.Name = "FrostbiteKillBurst"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(0.08, 0.08, 0.08)
	part.CFrame = CFrame.new(position)

	local at = Instance.new("Attachment")
	at.Parent = part

	local core = emitter(at, "FrostbiteKillCore", VFX.FROST_BURST_2x2)
	core.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
	core.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	core.Color = ColorSequence.new(ICE_WHITE, GLACIER_BLUE)
	core.Brightness = 2.2
	core.Lifetime = NumberRange.new(0.14, 0.22)
	core.Speed = NumberRange.new(0)
	core.Rotation = NumberRange.new(0, 360)
	core.Size = seq({ { 0, 0.65 }, { 0.32, 1.85 }, { 1, 0.35 } })
	core.Transparency = seq({ { 0, 0 }, { 0.55, 0.18 }, { 1, 1 } })

	local ring = emitter(at, "FrostbiteKillNova", VFX.T_RING)
	ring.Color = ColorSequence.new(ICE_WHITE, GLACIER_BLUE)
	ring.Brightness = 1.8
	ring.Lifetime = NumberRange.new(0.28)
	ring.Speed = NumberRange.new(0.02)
	ring.EmissionDirection = Enum.NormalId.Top
	ring.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
	ring.Rotation = NumberRange.new(0, 360)
	ring.Size = seq({ { 0, 0.35 }, { 1, 2.4 } })
	ring.Transparency = seq({ { 0, 0.05 }, { 0.6, 0.32 }, { 1, 1 } })

	local chips = emitter(at, "FrostbiteKillChips", VFX.T_CHIP)
	chips.LockedToPart = false
	chips.Color = ColorSequence.new(ICE_WHITE, GLACIER_BLUE)
	chips.LightEmission = 0.72
	chips.LightInfluence = 0.25
	chips.Brightness = 1.9
	chips.Lifetime = NumberRange.new(0.32, 0.62)
	chips.Speed = NumberRange.new(7, 16)
	chips.Drag = 4.2
	chips.Acceleration = Vector3.new(0, -16, 0)
	chips.SpreadAngle = Vector2.new(180, 180)
	chips.Rotation = NumberRange.new(-180, 180)
	chips.RotSpeed = NumberRange.new(-360, 360)
	chips.Size = seq({ { 0, 0.22 }, { 0.6, 0.15 }, { 1, 0.02 } })
	chips.Transparency = seq({ { 0, 0 }, { 0.7, 0.22 }, { 1, 1 } })

	local shards = emitter(at, "FrostbiteKillShards", VFX.FROST_SHARD)
	shards.LockedToPart = false
	shards.Color = ColorSequence.new(ICE_WHITE, CRYO_CYAN)
	shards.Brightness = 2.0
	shards.Lifetime = NumberRange.new(0.24, 0.48)
	shards.Speed = NumberRange.new(8, 16)
	shards.Drag = 5
	shards.Acceleration = Vector3.new(0, -14, 0)
	shards.SpreadAngle = Vector2.new(180, 180)
	shards.Orientation = Enum.ParticleOrientation.VelocityParallel
	shards.Size = seq({ { 0, 0.14 }, { 1, 0.03 } })
	shards.Transparency = seq({ { 0, 0 }, { 0.65, 0.24 }, { 1, 1 } })

	local mist = emitter(at, "FrostbiteKillMist", VFX.FROST_MIST_2x2)
	mist.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
	mist.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	mist.LockedToPart = false
	mist.Color = ColorSequence.new(CRYO_CYAN, DEEP_ICE)
	mist.LightEmission = 0.42
	mist.Brightness = 1.25
	mist.Lifetime = NumberRange.new(0.45, 0.75)
	mist.Speed = NumberRange.new(1.5, 3.8)
	mist.Drag = 3.2
	mist.Acceleration = Vector3.new(0, -1.2, 0)
	mist.SpreadAngle = Vector2.new(180, 180)
	mist.Rotation = NumberRange.new(0, 360)
	mist.Size = seq({ { 0, 0.45 }, { 0.5, 1.15 }, { 1, 1.65 } })
	mist.Transparency = seq({ { 0, 0.42 }, { 0.5, 0.68 }, { 1, 1 } })

	local sparkles = emitter(at, "FrostbiteKillSparkles", VFX.MOD_SPARKLE)
	sparkles.LockedToPart = false
	sparkles.Color = ColorSequence.new(ICE_WHITE, CRYO_CYAN)
	sparkles.Brightness = 2.0
	sparkles.Lifetime = NumberRange.new(0.35, 0.65)
	sparkles.Speed = NumberRange.new(3.5, 8.5)
	sparkles.Drag = 5
	sparkles.Acceleration = Vector3.new(0, -2.5, 0)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.RotSpeed = NumberRange.new(-140, 140)
	sparkles.Size = seq({ { 0, 0.18 }, { 0.45, 0.24 }, { 1, 0 } })
	sparkles.Transparency = seq({ { 0, 0.05 }, { 0.6, 0.25 }, { 1, 1 } })

	local light = Instance.new("PointLight")
	light.Name = "FrostbiteKillLight"
	light.Color = CRYO_CYAN
	light.Brightness = 2.4
	light.Range = 11
	light.Shadows = false
	light.Parent = at

	part.Parent = Workspace
	core:Emit(2)
	ring:Emit(1)
	mist:Emit(if UiMotion.reduced() then 2 else 5)
	if not UiMotion.reduced() then
		chips:Emit(12)
		shards:Emit(10)
		sparkles:Emit(12)
	end

	task.spawn(function()
		for i = 1, 6 do
			task.wait(0.036)
			if light.Parent then
				light.Brightness = 2.4 * (1 - i / 6) ^ 2
			end
		end
		if light.Parent then
			light.Enabled = false
		end
	end)

	Debris:AddItem(part, 1.2)
end

return FrostbiteFx
