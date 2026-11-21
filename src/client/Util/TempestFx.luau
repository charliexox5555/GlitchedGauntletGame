--!strict
-- Tempest-Strike shot effects (our own design, from the owner's concept sheet):
-- a sharp four-point shuriken flash at the muzzle (front star + a short side spear),
-- a burst of fine water mist out of the brake ports, a quick cyan light pop, and
-- at impacts a small glowing water splash with a static crackle. The tracer itself
-- is the stock TracerFx, tinted (EffectsController passes the colour).
-- First person rigs are built once per muzzle attachment and reused per shot.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local Shared = ReplicatedStorage.Shared
local Style = require(Shared.Config.SkinPreview).TEMPEST
local UiMotion = require(Shared.UiMotion)

type Rig = {
	front: ParticleEmitter,
	side: ParticleEmitter,
	mist: ParticleEmitter,
	ring: ParticleEmitter,
	jets: { ParticleEmitter },
	light: PointLight,
	lit: number,
}

local TempestFx = {}
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
	local rim = Style.WATER
	-- front: the shuriken star, facing the camera, spun a little per shot
	local front = emitter(muzzle, "TempestFlashFront", Style.FLASH_FRONT)
	if Style.FLASH_FRONT_FLIPBOOK then
		front.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
		front.FlipbookMode = Enum.ParticleFlipbookMode.Random
	end
	front.Color = ColorSequence.new(core, rim)
	front.Brightness = Style.FLASH_BRIGHTNESS
	front.Lifetime = NumberRange.new(Style.FLASH_TIME, Style.FLASH_TIME * 1.3)
	front.Speed = NumberRange.new(0)
	front.Rotation = NumberRange.new(-12, 12)
	front.Size = seq({ { 0, 0.30 * scale }, { 0.35, 0.42 * scale }, { 1, 0.10 * scale } })
	front.Transparency = seq({ { 0, 0 }, { 0.6, 0.15 }, { 1, 1 } })
	front.ZOffset = 0.06 * scale
	-- side: a short spear of light along the barrel (VelocityParallel along the bore)
	local side = emitter(muzzle, "TempestFlashSide", Style.FLASH_SIDE)
	side.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
	side.FlipbookMode = Enum.ParticleFlipbookMode.Random
	side.Color = ColorSequence.new(core, rim)
	side.Brightness = Style.FLASH_BRIGHTNESS * 0.9
	side.Lifetime = NumberRange.new(Style.FLASH_TIME)
	side.Speed = NumberRange.new(0.02)
	side.EmissionDirection = Enum.NormalId.Front
	side.Orientation = Enum.ParticleOrientation.VelocityParallel
	side.Size = seq({ { 0, 0.24 * scale }, { 0.4, 0.30 * scale }, { 1, 0.08 * scale } })
	side.Transparency = seq({ { 0, 0.05 }, { 0.7, 0.3 }, { 1, 1 } })
	-- mist: fine water droplets thrown sideways out of the ports
	local mist = emitter(muzzle, "TempestMist", Style.DROPLETS)
	if Style.DROPLETS_FLIPBOOK then
		mist.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
		mist.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	end
	mist.Color = ColorSequence.new(Style.WATER_EDGE, rim)
	mist.LightEmission = 0.6
	mist.Brightness = 1.1
	mist.Lifetime = NumberRange.new(0.16, 0.26)
	mist.Speed = NumberRange.new(1.6 * scale, 2.8 * scale)
	mist.Drag = 9
	mist.SpreadAngle = Vector2.new(70, 18)
	mist.EmissionDirection = Enum.NormalId.Front
	mist.Size = seq({ { 0, 0.05 * scale }, { 1, 0.11 * scale } })
	mist.Transparency = seq({ { 0, 0.2 }, { 0.5, 0.45 }, { 1, 1 } })
	mist.LockedToPart = false
	-- ring: a water ring bursting round the bore (the splash sheet, facing down the barrel)
	local ring = emitter(muzzle, "TempestMuzzleRing", Style.SPLASH)
	if Style.SPLASH_FLIPBOOK then
		ring.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
		ring.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	end
	ring.Color = ColorSequence.new(Style.WATER_EDGE, rim)
	ring.LightEmission = 0.8
	ring.Brightness = Style.FLASH_BRIGHTNESS * 0.8
	ring.Lifetime = NumberRange.new(Style.MUZZLE_RING_TIME)
	ring.Speed = NumberRange.new(Style.MUZZLE_RING_SPEED * scale)
	ring.EmissionDirection = Enum.NormalId.Front
	ring.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
	ring.Rotation = NumberRange.new(0, 360)
	ring.Size = seq({ { 0, 0.12 * scale }, { 1, Style.MUZZLE_RING_SIZE * scale } })
	ring.Transparency = seq({ { 0, 0.1 }, { 0.6, 0.35 }, { 1, 1 } })
	-- jets: short water spurts thrown sideways out of the brake ports
	local jets: { ParticleEmitter } = {}
	for _, dir in { Enum.NormalId.Left, Enum.NormalId.Right, Enum.NormalId.Top } do
		local jet = emitter(muzzle, "TempestPortJet", Style.FLASH_SIDE)
		jet.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
		jet.FlipbookMode = Enum.ParticleFlipbookMode.Random
		jet.Color = ColorSequence.new(Style.WATER_EDGE, rim)
		jet.Brightness = Style.FLASH_BRIGHTNESS * 0.75
		jet.LightEmission = 0.85
		jet.Lifetime = NumberRange.new(0.05, 0.07)
		jet.Speed = NumberRange.new(1.2 * scale, 1.8 * scale)
		jet.Drag = 12
		jet.EmissionDirection = dir
		jet.SpreadAngle = Vector2.new(12, 12)
		jet.Orientation = Enum.ParticleOrientation.VelocityParallel
		jet.Size = seq({ { 0, 0.12 * scale }, { 0.4, 0.2 * scale }, { 1, 0.05 * scale } })
		jet.Transparency = seq({ { 0, 0.05 }, { 0.7, 0.35 }, { 1, 1 } })
		table.insert(jets, jet)
	end
	local light = Instance.new("PointLight")
	light.Name = "TempestFlashLight"
	light.Color = rim
	light.Range = Style.FLASH_LIGHT_RANGE
	light.Brightness = 0
	light.Shadows = false
	light.Enabled = false
	light.Parent = muzzle
	local rig: Rig = {
		front = front,
		side = side,
		mist = mist,
		ring = ring,
		jets = jets,
		light = light,
		lit = -1,
	}
	rigs[muzzle] = rig
	return rig
end

-- One shot from our own Tempest-Strike gun (first person).
function TempestFx.flash(muzzle: Attachment, scale: number)
	local rig = rigs[muzzle] or build(muzzle, scale)
	rig.front:Emit(1)
	rig.side:Emit(1)
	if not UiMotion.reduced() then
		rig.mist:Emit(math.random(4, 6))
		rig.ring:Emit(1)
		for _, jet in rig.jets do
			jet:Emit(1)
		end
	end
	rig.light.Brightness = Style.FLASH_LIGHT
	rig.light.Enabled = true
	rig.lit = clock
end

-- A shot landing on the world: glowing droplets kicked off the surface and a short
-- static crackle mark.
function TempestFx.splash(position: Vector3, normal: Vector3)
	local part = Instance.new("Part")
	part.Name = "TempestSplash"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(0.05, 0.05, 0.05)
	part.CFrame = CFrame.lookAt(position + normal * 0.02, position + normal * 1.02)
	local at = Instance.new("Attachment")
	at.Parent = part
	local drops = emitter(at, "TempestSplashDrops", Style.DROPLETS)
	if Style.DROPLETS_FLIPBOOK then
		drops.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
		drops.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	end
	drops.LockedToPart = false
	drops.Color = ColorSequence.new(Style.WATER_EDGE, Style.WATER)
	drops.Brightness = 1.4
	drops.Lifetime = NumberRange.new(0.25, 0.4)
	drops.Speed = NumberRange.new(4, 8)
	drops.Drag = 6
	drops.Acceleration = Vector3.new(0, -14, 0)
	drops.SpreadAngle = Vector2.new(55, 55)
	drops.EmissionDirection = Enum.NormalId.Front
	drops.Size = seq({ { 0, 0.12 }, { 1, 0.05 } })
	drops.Transparency = seq({ { 0, 0 }, { 0.6, 0.2 }, { 1, 1 } })
	local ring = emitter(at, "TempestSplashRing", Style.SPLASH)
	if Style.SPLASH_FLIPBOOK then
		ring.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
		ring.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	end
	ring.LockedToPart = true
	ring.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp
	ring.Color = ColorSequence.new(Style.WATER_EDGE, Style.WATER)
	ring.Brightness = 1.3
	ring.Lifetime = NumberRange.new(0.18)
	ring.Speed = NumberRange.new(0)
	ring.Size = seq({ { 0, 0.25 }, { 1, 0.7 } })
	ring.Transparency = seq({ { 0, 0.1 }, { 1, 1 } })
	-- the strike: a small white-cyan star, two lightning arcs snapping off it, a light pop
	local core = emitter(at, "TempestStrikeCore", Style.FLASH_FRONT)
	core.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
	core.FlipbookMode = Enum.ParticleFlipbookMode.Random
	core.Color = ColorSequence.new(Style.FLASH_CORE, Style.WATER)
	core.Brightness = Style.FLASH_BRIGHTNESS
	core.Lifetime = NumberRange.new(0.06, 0.08)
	core.Speed = NumberRange.new(0)
	core.Rotation = NumberRange.new(0, 90)
	core.Size = seq({ { 0, 0.32 }, { 0.3, 0.62 }, { 1, 0.1 } })
	core.Transparency = seq({ { 0, 0 }, { 0.6, 0.2 }, { 1, 1 } })
	local arcs = emitter(at, "TempestStrikeArcs", Style.ARC)
	arcs.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
	arcs.FlipbookMode = Enum.ParticleFlipbookMode.Random
	arcs.Color = ColorSequence.new(Style.ARC_CORE, Style.WATER)
	arcs.Brightness = 1.6
	arcs.Lifetime = NumberRange.new(0.07, 0.12)
	arcs.Speed = NumberRange.new(0)
	arcs.Rotation = NumberRange.new(0, 360)
	arcs.Size = seq({ { 0, 0.55 }, { 1, 0.75 } })
	arcs.Transparency = seq({ { 0, 0 }, { 0.5, 0.15 }, { 1, 1 } })
	local light = Instance.new("PointLight")
	light.Color = Style.WATER
	light.Brightness = Style.IMPACT_LIGHT
	light.Range = 5
	light.Shadows = false
	light.Parent = at
	part.Parent = Workspace
	core:Emit(1)
	arcs:Emit(2)
	task.delay(0.07, function()
		light.Enabled = false
	end)
	drops:Emit(math.random(6, 9))
	ring:Emit(1)
	if Style.STATIC_MARK ~= "" then
		local mark = Instance.new("Decal")
		mark.Texture = Style.STATIC_MARK
		mark.Face = Enum.NormalId.Front
		mark.Color3 = Style.WATER
		mark.Transparency = 0.15
		local plate = Instance.new("Part")
		plate.Anchored = true
		plate.CanCollide = false
		plate.CanQuery = false
		plate.CanTouch = false
		plate.Transparency = 1
		plate.Size = Vector3.new(0.55, 0.55, 0.01)
		plate.CFrame = CFrame.lookAt(position + normal * 0.012, position + normal * 1.012)
			* CFrame.Angles(0, math.pi, math.random() * 2 * math.pi)
		mark.Parent = plate
		plate.Parent = Workspace
		task.delay(Style.STATIC_TIME, function()
			if plate.Parent then
				for i = 1, 6 do
					mark.Transparency = 0.15 + 0.85 * i / 6
					task.wait(0.04)
				end
				plate:Destroy()
			end
		end)
	end
	Debris:AddItem(part, 0.6)
end

-- Every frame (EffectsController): fades the flash lights.
function TempestFx.step(dt: number)
	clock += dt
	for _, rig in rigs do
		if rig.lit >= 0 then
			local k = (clock - rig.lit) / Style.FLASH_LIGHT_TIME
			if k >= 1 then
				rig.light.Enabled = false
				rig.lit = -1
			else
				rig.light.Brightness = Style.FLASH_LIGHT * (1 - k) * (1 - k)
			end
		end
	end
end

return TempestFx
