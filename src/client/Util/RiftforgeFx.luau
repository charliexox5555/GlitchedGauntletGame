--!strict
-- Riftforge Legendary shot & impact VFX (first-person focused):
-- - 5-layer dark-matter plasma muzzle flash: octagonal star + side plasma spear +
--   perpendicular electric shockwave ring + sideways accelerator port jets + hot sparks + violet light pop.
-- - Custom plasma bullet impact splash on walls: lilac-violet core flash + crackling electric arcs +
--   expanding plasma shock ring + spark spray + fading violet static scorch mark + impact light pop.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage.Shared
local Style = require(Shared.Config.SkinPreview).RIFTFORGE
local VFX = require(Shared.Config.VfxTextures)
local UiMotion = require(Shared.UiMotion)

type Rig = {
	front: ParticleEmitter,
	side: ParticleEmitter,
	arc: ParticleEmitter,
	ring: ParticleEmitter,
	sparks: ParticleEmitter,
	smoke: ParticleEmitter,
	jets: { ParticleEmitter },
	light: PointLight,
	lit: number,
}

local RiftforgeFx = {}
local rigs: { [Attachment]: Rig } = setmetatable({}, { __mode = "k" }) :: any
local clock = 0

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

local function build(muzzle: Attachment, scale: number): Rig
	local core = Style.FLASH_CORE
	local mid = Style.PLASMA
	local deep = Style.PLASMA_DEEP
	local plasmaSeq = ColorSequence.new({
		ColorSequenceKeypoint.new(0, core),
		ColorSequenceKeypoint.new(0.42, mid),
		ColorSequenceKeypoint.new(1, deep),
	})

	-- 1. Crisp octagonal plasma star facing camera
	local front = emitter(muzzle, "RiftforgeFlashFront", Style.FLASH_FRONT)
	front.Color = plasmaSeq
	front.Brightness = Style.FLASH_BRIGHTNESS
	front.Lifetime = NumberRange.new(Style.FLASH_TIME, Style.FLASH_TIME * 1.28)
	front.Speed = NumberRange.new(0)
	front.Rotation = NumberRange.new(0, 90)
	front.Size = seq({ { 0, 0.34 * scale }, { 0.32, 0.48 * scale }, { 1, 0.10 * scale } })
	front.Transparency = seq({ { 0, 0 }, { 0.55, 0.12 }, { 1, 1 } })
	front.ZOffset = 0.08 * scale

	-- 2. Forward plasma lance spear down the bore
	local side = emitter(muzzle, "RiftforgeFlashSide", Style.FLASH_SIDE)
	side.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
	side.FlipbookMode = Enum.ParticleFlipbookMode.Random
	side.Color = plasmaSeq
	side.Brightness = Style.FLASH_BRIGHTNESS * 0.95
	side.Lifetime = NumberRange.new(Style.FLASH_TIME)
	side.Speed = NumberRange.new(0.02)
	side.EmissionDirection = Enum.NormalId.Front
	side.Orientation = Enum.ParticleOrientation.VelocityParallel
	side.Size = seq({ { 0, 0.26 * scale }, { 0.38, 0.36 * scale }, { 1, 0.08 * scale } })
	side.Transparency = seq({ { 0, 0.05 }, { 0.65, 0.28 }, { 1, 1 } })

	-- 3. Electric plasma crackle burst right at the muzzle crown
	local arc = emitter(muzzle, "RiftforgeMuzzleArc", Style.ARC_TEXTURE)
	arc.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
	arc.FlipbookMode = Enum.ParticleFlipbookMode.Random
	arc.Color = ColorSequence.new(core, mid)
	arc.Brightness = 2.0
	arc.Lifetime = NumberRange.new(0.06, 0.10)
	arc.Speed = NumberRange.new(0)
	arc.Rotation = NumberRange.new(0, 360)
	arc.Size = seq({ { 0, 0.24 * scale }, { 1, 0.42 * scale } })
	arc.Transparency = seq({ { 0, 0 }, { 0.5, 0.18 }, { 1, 1 } })
	arc.ZOffset = 0.10 * scale

	-- 4. Expanding perpendicular electric plasma shockwave ring around the bore!
	local ring = emitter(muzzle, "RiftforgeMuzzleRing", Style.PULSE_RING)
	ring.Color = ColorSequence.new(core, mid)
	ring.Brightness = Style.FLASH_BRIGHTNESS * 0.9
	ring.Lifetime = NumberRange.new(Style.MUZZLE_RING_TIME)
	ring.Speed = NumberRange.new(Style.MUZZLE_RING_SPEED * scale)
	ring.EmissionDirection = Enum.NormalId.Front
	ring.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
	ring.Rotation = NumberRange.new(0, 360)
	ring.Size = seq({ { 0, 0.12 * scale }, { 1, Style.MUZZLE_RING_SIZE * scale } })
	ring.Transparency = seq({ { 0, 0.08 }, { 0.55, 0.30 }, { 1, 1 } })

	-- 5. Hot violet plasma sparks flying out of the accelerator rails
	local sparks = emitter(muzzle, "RiftforgeMuzzleSparks", Style.SPARK_TEXTURE)
	sparks.Color = ColorSequence.new(core, mid)
	sparks.Brightness = 2.0
	sparks.Lifetime = NumberRange.new(0.10, 0.20)
	sparks.Speed = NumberRange.new(2.2 * scale, 4.4 * scale)
	sparks.Drag = 8
	sparks.SpreadAngle = Vector2.new(48, 32)
	sparks.EmissionDirection = Enum.NormalId.Front
	sparks.Orientation = Enum.ParticleOrientation.VelocityParallel
	sparks.Size = seq({ { 0, 0.045 * scale }, { 1, 0.012 * scale } })
	sparks.Transparency = seq({ { 0, 0 }, { 0.65, 0.25 }, { 1, 1 } })
	sparks.LockedToPart = false

	-- 5b. Subtle dark-violet plasma vapor wisp curling off the hot suppressor crown!
	local smoke = emitter(muzzle, "RiftforgeMuzzleVapor", VFX.SMOKE_2x2)
	smoke.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
	smoke.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	smoke.Color = ColorSequence.new(Style.MUZZLE_SMOKE, Style.PLASMA_DEEP)
	smoke.LightEmission = 0.35
	smoke.Brightness = 0.9
	smoke.Lifetime = NumberRange.new(0.28, 0.44)
	smoke.Speed = NumberRange.new(0.6 * scale, 1.3 * scale)
	smoke.Drag = 4.5
	smoke.Acceleration = Vector3.new(0, 1.8 * scale, 0)
	smoke.SpreadAngle = Vector2.new(28, 28)
	smoke.EmissionDirection = Enum.NormalId.Front
	smoke.Rotation = NumberRange.new(0, 360)
	smoke.Size = seq({ { 0, 0.10 * scale }, { 0.5, 0.24 * scale }, { 1, 0.36 * scale } })
	smoke.Transparency = seq({ { 0, 0.65 }, { 0.45, 0.78 }, { 1, 1 } })
	smoke.LockedToPart = false

	-- 6. Sideways accelerator port plasma jets (Left + Right)
	local jets: { ParticleEmitter } = {}
	for _, dir in { Enum.NormalId.Left, Enum.NormalId.Right } do
		local jet = emitter(muzzle, "RiftforgePortJet", Style.FLASH_SIDE)
		jet.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
		jet.FlipbookMode = Enum.ParticleFlipbookMode.Random
		jet.Color = plasmaSeq
		jet.Brightness = Style.FLASH_BRIGHTNESS * 0.78
		jet.Lifetime = NumberRange.new(0.045, 0.07)
		jet.Speed = NumberRange.new(1.4 * scale, 2.2 * scale)
		jet.Drag = 11
		jet.EmissionDirection = dir
		jet.SpreadAngle = Vector2.new(14, 14)
		jet.Orientation = Enum.ParticleOrientation.VelocityParallel
		jet.Size = seq({ { 0, 0.12 * scale }, { 0.4, 0.22 * scale }, { 1, 0.05 * scale } })
		jet.Transparency = seq({ { 0, 0.05 }, { 0.65, 0.35 }, { 1, 1 } })
		table.insert(jets, jet)
	end

	local light = Instance.new("PointLight")
	light.Name = "RiftforgeFlashLight"
	light.Color = mid
	light.Range = Style.FLASH_LIGHT_RANGE
	light.Brightness = 0
	light.Shadows = false
	light.Enabled = false
	light.Parent = muzzle

	local rig: Rig = {
		front = front,
		side = side,
		arc = arc,
		ring = ring,
		sparks = sparks,
		smoke = smoke,
		jets = jets,
		light = light,
		lit = -1,
	}
	rigs[muzzle] = rig
	return rig
end

-- First-person Riftforge muzzle flash.
function RiftforgeFx.flash(muzzle: Attachment, scale: number)
	local rig = rigs[muzzle] or build(muzzle, scale)
	rig.front:Emit(1)
	rig.side:Emit(1)
	rig.arc:Emit(1)
	if not UiMotion.reduced() then
		rig.ring:Emit(1)
		rig.sparks:Emit(math.random(5, 8))
		rig.smoke:Emit(1)
		for _, jet in rig.jets do
			jet:Emit(1)
		end
	end
	rig.light.Brightness = Style.FLASH_LIGHT
	rig.light.Enabled = true
	rig.lit = clock
end

-- First-person Riftforge plasma impact on world surfaces.
function RiftforgeFx.splash(position: Vector3, normal: Vector3)
	local part = Instance.new("Part")
	part.Name = "RiftforgeSplash"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(0.05, 0.05, 0.05)
	part.CFrame = CFrame.lookAt(position + normal * 0.02, position + normal * 1.02)

	local at = Instance.new("Attachment")
	at.Parent = part

	-- Hot violet plasma impact burst
	local core = emitter(at, "RiftforgeImpactCore", Style.IMPACT_FLASH)
	core.Color = ColorSequence.new(Style.FLASH_CORE, Style.PLASMA)
	core.Brightness = 2.2
	core.Lifetime = NumberRange.new(0.07, 0.11)
	core.Speed = NumberRange.new(0)
	core.Rotation = NumberRange.new(0, 360)
	core.Size = seq({ { 0, 0.34 }, { 0.35, 0.68 }, { 1, 0.14 } })
	core.Transparency = seq({ { 0, 0 }, { 0.55, 0.18 }, { 1, 1 } })

	-- Crackling dark-matter lightning arcs
	local arcs = emitter(at, "RiftforgeImpactArcs", Style.ARC_TEXTURE)
	arcs.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
	arcs.FlipbookMode = Enum.ParticleFlipbookMode.Random
	arcs.Color = ColorSequence.new(Style.FLASH_CORE, Style.PLASMA)
	arcs.Brightness = 1.9
	arcs.Lifetime = NumberRange.new(0.08, 0.14)
	arcs.Speed = NumberRange.new(0)
	arcs.Rotation = NumberRange.new(0, 360)
	arcs.Size = seq({ { 0, 0.55 }, { 1, 0.92 } })
	arcs.Transparency = seq({ { 0, 0 }, { 0.5, 0.15 }, { 1, 1 } })

	-- Expanding surface plasma shockwave ring
	local ring = emitter(at, "RiftforgeImpactRing", Style.PULSE_RING)
	ring.Color = ColorSequence.new(Style.PLASMA_EDGE, Style.PLASMA)
	ring.Brightness = 1.6
	ring.Lifetime = NumberRange.new(0.18)
	ring.Speed = NumberRange.new(0.05)
	ring.EmissionDirection = Enum.NormalId.Front
	ring.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
	ring.Rotation = NumberRange.new(0, 360)
	ring.Size = seq({ { 0, 0.22 }, { 1, 0.85 } })
	ring.Transparency = seq({ { 0, 0.08 }, { 0.6, 0.35 }, { 1, 1 } })

	-- Hot violet plasma sparks flying off the surface
	local sparks = emitter(at, "RiftforgeImpactSparks", Style.SPARK_TEXTURE)
	sparks.LockedToPart = false
	sparks.Color = ColorSequence.new(Style.FLASH_CORE, Style.PLASMA)
	sparks.Brightness = 1.9
	sparks.Lifetime = NumberRange.new(0.18, 0.34)
	sparks.Speed = NumberRange.new(5.5, 11.5)
	sparks.Drag = 6.5
	sparks.Acceleration = Vector3.new(0, -14, 0)
	sparks.SpreadAngle = Vector2.new(62, 62)
	sparks.EmissionDirection = Enum.NormalId.Front
	sparks.Orientation = Enum.ParticleOrientation.VelocityParallel
	sparks.Size = seq({ { 0, 0.085 }, { 1, 0.02 } })
	sparks.Transparency = seq({ { 0, 0 }, { 0.65, 0.22 }, { 1, 1 } })

	local light = Instance.new("PointLight")
	light.Color = Style.PLASMA
	light.Brightness = Style.IMPACT_LIGHT
	light.Range = 5.5
	light.Shadows = false
	light.Parent = at

	part.Parent = Workspace
	core:Emit(1)
	arcs:Emit(2)
	ring:Emit(1)
	if not UiMotion.reduced() then
		sparks:Emit(math.random(7, 11))
	end
	task.delay(0.08, function()
		if light.Parent then
			light.Enabled = false
		end
	end)

	-- Glowing violet plasma static ring scorch decal fading out smoothly
	if Style.STATIC_MARK ~= "" then
		local mark = Instance.new("Decal")
		mark.Texture = Style.STATIC_MARK
		mark.Face = Enum.NormalId.Front
		mark.Color3 = Style.PLASMA
		mark.Transparency = 0.12
		local plate = Instance.new("Part")
		plate.Name = "RiftforgeImpactMark"
		plate.Anchored = true
		plate.CanCollide = false
		plate.CanQuery = false
		plate.CanTouch = false
		plate.Transparency = 1
		plate.Size = Vector3.new(0.62, 0.62, 0.01)
		plate.CFrame = CFrame.lookAt(position + normal * 0.014, position + normal * 1.014)
			* CFrame.Angles(0, math.pi, math.random() * 2 * math.pi)
		mark.Parent = plate
		plate.Parent = Workspace
		task.delay(Style.STATIC_TIME, function()
			if plate.Parent then
				for i = 1, 6 do
					mark.Transparency = 0.12 + 0.88 * i / 6
					task.wait(0.04)
				end
				plate:Destroy()
			end
		end)
	end

	Debris:AddItem(part, 0.65)
end

-- Per-frame light decay (called by EffectsController).
function RiftforgeFx.step(dt: number)
	clock += dt
	for _, rig in rigs do
		if rig.lit >= 0 then
			local k = (clock - rig.lit) / Style.FLASH_LIGHT_TIME
			if k >= 1 then
				if rig.light.Parent then
					rig.light.Enabled = false
				end
				rig.lit = -1
			elseif rig.light.Parent then
				rig.light.Brightness = Style.FLASH_LIGHT * (1 - k) * (1 - k)
			end
		end
	end
end

return RiftforgeFx
