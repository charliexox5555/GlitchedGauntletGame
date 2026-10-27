--!strict
-- Shot effects, realistic and simple (new direction, Art Direction → VFX):
-- muzzle flash (a fiery star burst down the barrel, a side flame, embers, a
-- warm light pop), smoke (a puff per shot, and wisps curling off a hot barrel
-- after a burst), brass ejected from `Eject`, tracers, and impacts that depend
-- on the surface: sparks off metal, dust and chips off concrete, splinters
-- off wood, dirt off ground, plus a bullet hole. Other players' shots get the
-- same effects (ShotFx) and their gun plays its Fire clip.
--
-- Textures come from tools/vfx/make_real_vfx.py (Config/VfxTextures).
-- Everything that fires often is pooled: tracers, shells and bullet holes are
-- recycled, and bursts use shared emitters that are moved and Emit()ed, so an
-- automatic gun creates no instances per shot.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local GunSounds = require(ReplicatedStorage.Shared.Config.GunSounds)
local Net = require(ReplicatedStorage.Shared.Net)
local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)
local Types = require(ReplicatedStorage.Shared.Types)
local VFX = require(ReplicatedStorage.Shared.Config.VfxTextures)
local ViewmodelConfig = require(ReplicatedStorage.Shared.Config.Viewmodel)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

local AudioController = require(script.Parent.AudioController)
local GunAnimator = require(script.Parent.Parent.Util.GunAnimator)

type WeaponConfig = Types.WeaponConfig

local EffectsController = {}

local player = Players.LocalPlayer

local WHITE = Color3.new(1, 1, 1)
local FIRE = Color3.fromHex("FFB45A") -- muzzle light and glow
local EMBER = Color3.fromHex("FFC070")
local SMOKE = Color3.fromHex("C9C7C2")
local PUFF = Color3.fromHex("EEEDEA") -- suppressed / muzzle-device puff: light, reads on grey floors
local BRASS = Color3.fromHex("8F7A47") -- reads as brass in direct sun
local SPARK_HOT = Color3.fromHex("FFF1C2")
local SPARK_COOL = Color3.fromHex("FF8A2A")

local TRACER_POOL = 40
local TRACER_SPEED = 1400 -- studs/s
local TRACER_MIN_TIME = 0.04 -- close shots still show for a few frames
local TRACER_MAX_TIME = 0.14
local TRACER_LENGTH = 9
local HOLE_POOL = 64
local HOLE_LIFE = 14 -- seconds, the last HOLE_FADE of it fading
local HOLE_FADE = 2
local SHELL_POOL = 32
local SHELL_LIFE = 1.6
local SHELL_GRAVITY = Vector3.new(0, -70, 0)
local LIGHT_TIME = 0.05
-- First-person flashes are this much smaller again than the viewmodel's scale
-- (the gun sits right in front of the camera).
local FP_FLASH = 0.75
local FLASH_AHEAD = 0.32 -- the flash rig sits this far (x flash size) in front of the Muzzle
-- Other players' shells and smoke only within this range of the camera.
local DETAIL_RANGE = 90
-- Barrel heat: +1 per shot, cools at HEAT_COOL per second; above HEAT_WISP
-- the barrel smokes for a moment after you stop firing.
local HEAT_COOL = 2.5
local HEAT_WISP = 4
local HEAT_MAX = 12

-- Surfaces, by how a bullet strike looks on them.
type Surface = "Metal" | "Wood" | "Soft" | "Glass" | "Hard"

local SURFACES: { [Enum.Material]: Surface } = {
	[Enum.Material.Metal] = "Metal",
	[Enum.Material.DiamondPlate] = "Metal",
	[Enum.Material.CorrodedMetal] = "Metal",
	[Enum.Material.Foil] = "Metal",
	[Enum.Material.Wood] = "Wood",
	[Enum.Material.WoodPlanks] = "Wood",
	[Enum.Material.Grass] = "Soft",
	[Enum.Material.LeafyGrass] = "Soft",
	[Enum.Material.Ground] = "Soft",
	[Enum.Material.Mud] = "Soft",
	[Enum.Material.Sand] = "Soft",
	[Enum.Material.Snow] = "Soft",
	[Enum.Material.Fabric] = "Soft",
	[Enum.Material.Glass] = "Glass",
	[Enum.Material.Ice] = "Glass",
	[Enum.Material.ForceField] = "Glass",
}

local folder: Folder? = nil

-- Effects time. Studio only: Workspace attribute VfxTimeScale slows it down
-- (0 freezes everything) for screenshots.
local fxClock = 0
local timeScale = 1

-- Fire animations on other players' third-person guns.
local worldAnimators: { [Model]: GunAnimator.GunAnimator } = {}

local function effectsFolder(): Folder
	if folder and folder.Parent then
		return folder
	end
	local f = Instance.new("Folder")
	f.Name = "Effects"
	f.Parent = Workspace
	folder = f
	return f
end

local function fxPart(size: Vector3, cf: CFrame, color: Color3): Part
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
	p.Parent = effectsFolder()
	return p
end

local function worldAttachment(name: string): Attachment
	local a = Instance.new("Attachment")
	a.Name = name
	a.Parent = Workspace.Terrain
	return a
end

-- NumberSequence from flat time/value pairs: curve({ 0, 1, 1, 0 }).
local function curve(points: { number }): NumberSequence
	local keys = {}
	for i = 1, #points, 2 do
		table.insert(keys, NumberSequenceKeypoint.new(points[i], points[i + 1]))
	end
	return NumberSequence.new(keys)
end

local function upFor(dir: Vector3): Vector3
	return if math.abs(dir.Unit.Y) > 0.99 then Vector3.zAxis else Vector3.yAxis
end

local function facing(position: Vector3, dir: Vector3): CFrame
	return CFrame.lookAt(position, position + dir, upFor(dir))
end

-- A burst-only emitter (Enabled = false; fire it with Emit). Lit by the scene
-- unless it's fire.
local function emitter(parent: Instance, texture: string, color: Color3): ParticleEmitter
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

local function fire(e: ParticleEmitter)
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Brightness = 1
end

-- 2x2 sheet; each particle keeps one random frame.
local function flipbook(e: ParticleEmitter)
	e.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
	e.FlipbookMode = Enum.ParticleFlipbookMode.Loop
	e.FlipbookFramerate = NumberRange.new(0)
	e.FlipbookStartRandom = true
end

local function sparkEmitter(parent: Instance, size: number): ParticleEmitter
	local e = emitter(parent, VFX.SPARK, SPARK_HOT)
	fire(e)
	e.Color = ColorSequence.new(SPARK_HOT, SPARK_COOL)
	e.Orientation = Enum.ParticleOrientation.VelocityParallel
	e.Rotation = NumberRange.new(0)
	e.Size = curve({ 0, size, 1, size * 0.3 })
	e.Squash = curve({ 0, 1.6, 1, 0.8 })
	e.EmissionDirection = Enum.NormalId.Front
	return e
end

-- Light pops -------------------------------------------------------------------
-- A light switched on for LIGHT_TIME and faded out (no tweens per shot).

local lightStart: { [PointLight]: number } = {}
local lightBase: { [PointLight]: number } = {}

local function popLight(light: PointLight, brightness: number)
	light.Brightness = brightness
	light.Enabled = true
	lightStart[light] = fxClock
	lightBase[light] = brightness
end

local function stepLights(now: number)
	for light, t0 in lightStart do
		local k = (now - t0) / LIGHT_TIME
		if k >= 1 or not light.Parent then
			light.Enabled = false
			lightStart[light] = nil
			lightBase[light] = nil
		else
			light.Brightness = lightBase[light] * (1 - k) * (1 - k)
		end
	end
end

-- Muzzle flash -------------------------------------------------------------------
-- Each muzzle gets a rig of emitters the first time it fires: the front burst
-- and side flame (locked to the gun), a hot core, embers, a smoke puff, a
-- barrel wisp and a light. Suppressed and muzzle-device guns (`puff`) get a
-- subtle grey puff instead of the flare, as in Valorant.

type MuzzleRig = {
	front: ParticleEmitter,
	side: ParticleEmitter?,
	core: ParticleEmitter?,
	embers: ParticleEmitter?,
	smoke: ParticleEmitter,
	wisp: ParticleEmitter,
	light: PointLight,
	brightness: number,
	smokeCount: number,
	heat: number,
	lastShot: number,
}

local rigs: { [Attachment]: MuzzleRig } = setmetatable({}, { __mode = "k" }) :: any

local function flashSize(config: WeaponConfig): number
	local class = config.class
	if class == "Shotgun" then
		return 1.3
	elseif class == "Sniper" then
		return 1.25
	elseif class == "MachineGun" then
		return 1.1
	elseif class == "Sidearm" or class == "SMG" then
		return 0.8
	end
	return 1
end

local function buildRig(
	muzzle: Attachment,
	config: WeaponConfig,
	scale: number,
	firstPerson: boolean
): MuzzleRig?
	local parent = muzzle.Parent
	if not parent or not parent:IsA("BasePart") then
		return nil
	end
	local suppressed = config.suppressed == true
	local puff = suppressed or config.muzzleDevice == true
	local s = scale * flashSize(config) * (if suppressed then 0.6 else 1)

	-- The flash is a billboard: centred on the opening, the barrel (or a
	-- suppressor) hides its back half from first person and it seems to
	-- burst inside the muzzle. Start it just ahead of the opening instead.
	-- ZOffset (studs, toward the camera) must stay under that lead, or it
	-- pulls the quad back behind the muzzle face: a fixed 0.2 put a small
	-- suppressed flash inside the Phantom's can.
	local holder = Instance.new("Attachment")
	holder.Name = "FxMuzzle"
	holder.CFrame = muzzle.CFrame * CFrame.new(0, 0, -FLASH_AHEAD * s)
	holder.Parent = parent

	local front: ParticleEmitter
	local core: ParticleEmitter? = nil
	if puff then
		-- A quick grey puff out of the can or brake, no flame.
		front = emitter(holder, VFX.SMOKE_2x2, PUFF)
		flipbook(front)
		front.LockedToPart = true
		front.EmissionDirection = Enum.NormalId.Front
		front.Speed = NumberRange.new(2 * s, 4 * s)
		front.Drag = 6
		front.Lifetime = NumberRange.new(0.14, 0.22)
		front.Size = curve({ 0, 0.5 * s, 1, 1.5 * s })
		front.Transparency = curve({ 0, 0.3, 0.4, 0.6, 1, 1 })
		front.Rotation = NumberRange.new(0, 360)
		front.ZOffset = 0.1 * s
	else
		-- Down the barrel: a star burst, two frames long.
		front = emitter(holder, VFX.FLASH_FRONT_2x2, WHITE)
		fire(front)
		flipbook(front)
		front.LockedToPart = true
		front.Lifetime = NumberRange.new(0.035, 0.05)
		front.Size = curve({ 0, 0.5 * s, 1, 0.72 * s })
		front.Transparency = curve({ 0, 0.05, 0.5, 0.25, 1, 1 })
		front.ZOffset = 0.15 * s

		local c = emitter(holder, VFX.GLOW, FIRE)
		fire(c)
		c.LockedToPart = true
		c.Lifetime = NumberRange.new(0.04)
		c.Size = curve({ 0, 0.35 * s, 1, 0.2 * s })
		c.Transparency = curve({ 0, 0.5, 1, 1 })
		core = c
	end

	-- From the side: a ragged tongue of flame out of the muzzle. Seen nearly
	-- down the barrel in first person it shrinks to a short flick, so it's
	-- smaller there.
	local side: ParticleEmitter? = nil
	local embers: ParticleEmitter? = nil
	if not puff then
		local sideSize = (if firstPerson then 0.8 else 1.15) * s
		-- The side flame's texture starts at its bottom edge, so it sits half
		-- its size ahead of the muzzle.
		local ahead = Instance.new("Attachment")
		ahead.Name = "FxMuzzleSide"
		ahead.CFrame = muzzle.CFrame * CFrame.new(0, 0, -sideSize * 0.47)
		ahead.Parent = parent
		local e = emitter(ahead, VFX.FLASH_SIDE_2x2, WHITE)
		fire(e)
		flipbook(e)
		e.LockedToPart = true
		e.Orientation = Enum.ParticleOrientation.VelocityParallel
		e.EmissionDirection = Enum.NormalId.Front
		e.Speed = NumberRange.new(0.01)
		e.Rotation = NumberRange.new(0)
		e.Lifetime = NumberRange.new(0.035, 0.05)
		e.Size = curve({ 0, sideSize * 0.8, 1, sideSize })
		e.Transparency = curve({ 0, 0, 0.5, 0.2, 1, 1 })
		side = e

		local em = sparkEmitter(holder, 0.07 * s)
		em.Color = ColorSequence.new(EMBER, SPARK_COOL)
		em.Speed = NumberRange.new(35 * s, 60 * s)
		em.SpreadAngle = Vector2.new(9, 9)
		em.Lifetime = NumberRange.new(0.04, 0.1)
		em.Drag = 5
		embers = em
	end

	-- One grey puff per shot, drifting forward and up.
	local smoke = emitter(holder, VFX.SMOKE_2x2, SMOKE)
	flipbook(smoke)
	smoke.Lifetime = NumberRange.new(0.6, 1.1)
	smoke.Speed = NumberRange.new(2 * s, 5 * s)
	smoke.SpreadAngle = Vector2.new(18, 18)
	smoke.EmissionDirection = Enum.NormalId.Front
	smoke.Acceleration = Vector3.new(0, 1.6 * s, 0)
	smoke.Drag = 3
	smoke.RotSpeed = NumberRange.new(-50, 50)
	smoke.Size = curve({ 0, 0.18 * s, 1, 1.1 * s })
	smoke.Transparency = curve({ 0, 1, 0.1, 0.82, 1, 1 })

	-- Thin wisps curling off a hot barrel: continuous, rate set each frame.
	local wisp = emitter(holder, VFX.SMOKE_2x2, SMOKE)
	flipbook(wisp)
	wisp.Rate = 0
	wisp.Enabled = true
	wisp.Lifetime = NumberRange.new(0.9, 1.5)
	wisp.Speed = NumberRange.new(0.3 * s, 0.8 * s)
	wisp.SpreadAngle = Vector2.new(25, 25)
	wisp.EmissionDirection = Enum.NormalId.Top
	wisp.Acceleration = Vector3.new(0.4 * s, 2.2 * s, 0)
	wisp.Drag = 1.5
	wisp.RotSpeed = NumberRange.new(-30, 30)
	wisp.Size = curve({ 0, 0.06 * s, 1, 0.55 * s })
	wisp.Squash = curve({ 0, -0.6, 1, -0.2 }) -- taller than wide
	wisp.Transparency = curve({ 0, 1, 0.2, 0.86, 1, 1 })

	local light = Instance.new("PointLight")
	light.Color = FIRE
	light.Range = if puff then 4 else 10
	light.Shadows = false
	light.Enabled = false
	light.Parent = holder

	local rig: MuzzleRig = {
		front = front,
		side = side,
		core = core,
		embers = embers,
		smoke = smoke,
		wisp = wisp,
		light = light,
		-- Fast guns pop a dimmer light, or the room strobes.
		brightness = if puff
			then (if suppressed then 0 else 0.5)
			elseif config.fireInterval < 0.1 then 1.6
			else 2.4,
		smokeCount = if config.class == "Shotgun" or config.class == "Sniper" then 3 else 1,
		heat = 0,
		lastShot = -math.huge,
	}
	rigs[muzzle] = rig
	muzzle.Destroying:Once(function()
		rigs[muzzle] = nil
	end)
	return rig
end

-- Flash at a gun's Muzzle attachment. `firstPerson`: our viewmodel (scaled to
-- the viewmodel). `smoke`: false skips the smoke (far away).
function EffectsController.muzzleFlash(
	muzzle: Attachment,
	config: WeaponConfig,
	firstPerson: boolean,
	smoke: boolean?
)
	local scale = if firstPerson
		then (config.viewmodelScale or ViewmodelConfig.SCALE) * FP_FLASH
		else 1
	local rig = rigs[muzzle] or buildRig(muzzle, config, scale, firstPerson)
	if not rig then
		return
	end
	rig.front:Emit(1)
	if rig.core then
		rig.core:Emit(1)
	end
	if rig.side then
		rig.side:Emit(1)
	end
	if rig.embers and math.random() < 0.6 then
		rig.embers:Emit(math.random(1, 3))
	end
	if smoke ~= false then
		rig.smoke:Emit(rig.smokeCount)
		rig.heat = math.min(rig.heat + 1, HEAT_MAX)
	end
	rig.lastShot = fxClock
	popLight(rig.light, rig.brightness)
end

-- Hot barrels smoke for a moment once the shooting stops.
local function stepWisps(dt: number)
	for _, rig in rigs do
		if rig.heat > 0 then
			rig.heat = math.max(0, rig.heat - HEAT_COOL * dt)
			local resting = fxClock - rig.lastShot > 0.12
			local amount = math.clamp((rig.heat - HEAT_WISP) / (HEAT_MAX - HEAT_WISP), 0, 1)
			rig.wisp.Rate = if resting then 4 + 18 * amount else 0
			if rig.heat <= HEAT_WISP * 0.5 then
				rig.wisp.Rate = 0
			end
		end
	end
end

-- Shell casings --------------------------------------------------------------------
-- Pooled anchored parts flown by hand (no physics), with one bounce.

type Shell = {
	part: Part,
	position: Vector3,
	velocity: Vector3,
	rotation: CFrame,
	axis: Vector3,
	spin: number,
	age: number,
	bounced: boolean,
	resting: boolean,
	active: boolean,
}

local shells: { Shell } = {}
local nextShell = 1
local activeShells = 0
local shellParams = RaycastParams.new()
shellParams.FilterType = Enum.RaycastFilterType.Exclude
local shellFilterCharacter: Model? = nil
local shellFilterReady = false

-- Shells land on the world, not on our own character.
local function updateShellFilter()
	local character = player.Character
	if character ~= shellFilterCharacter or not shellFilterReady then
		shellFilterReady = true
		shellFilterCharacter = character
		shellParams.FilterDescendantsInstances = if character
			then { effectsFolder(), character }
			else { effectsFolder() }
	end
end

local function shellSize(config: WeaponConfig): Vector3
	local class = config.class
	if class == "Shotgun" then
		return Vector3.new(0.3, 0.16, 0.16)
	elseif class == "Sniper" then
		return Vector3.new(0.3, 0.09, 0.09)
	elseif class == "Rifle" or class == "MachineGun" then
		return Vector3.new(0.16, 0.05, 0.05)
	end
	return Vector3.new(0.13, 0.06, 0.06)
end

local function spawnShell(eject: Attachment, config: WeaponConfig, scale: number, inherit: Vector3)
	if #shells < SHELL_POOL then
		local p = fxPart(Vector3.one, CFrame.identity, BRASS)
		p.Name = "Shell"
		p.Shape = Enum.PartType.Cylinder
		p.Material = Enum.Material.Metal
		p.Reflectance = 0.05
		table.insert(shells, {
			part = p,
			position = Vector3.zero,
			velocity = Vector3.zero,
			rotation = CFrame.identity,
			axis = Vector3.xAxis,
			spin = 0,
			age = 0,
			bounced = false,
			resting = false,
			active = false,
		})
	end
	local shell = shells[nextShell] or shells[1]
	nextShell = nextShell % SHELL_POOL + 1
	if not shell.active then
		activeShells += 1
	end
	local cf = eject.WorldCFrame
	local p = shell.part
	p.Size = shellSize(config) * scale
	p.Color = if config.class == "Shotgun" then Color3.fromHex("A8333F") else BRASS
	p.Transparency = 0
	shell.position = cf.Position
	shell.rotation = cf.Rotation * CFrame.Angles(0, math.pi / 2, 0) -- axis across the gun
	-- Out to the side and up, a little forward, with some scatter.
	local out = cf.LookVector * (8 + math.random() * 4) + cf.UpVector * (5 + math.random() * 3)
	shell.velocity = (out - cf.RightVector * (math.random() - 0.3) * 2) * math.sqrt(scale) + inherit
	shell.axis = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5).Unit
	shell.spin = 20 + math.random() * 18
	shell.age = 0
	shell.bounced = false
	shell.resting = false
	shell.active = true
	p.CFrame = CFrame.new(shell.position) * shell.rotation
end

local function stepShells(dt: number)
	if activeShells == 0 then
		return
	end
	for _, s in shells do
		if not s.active then
			continue
		end
		s.age += dt
		local p = s.part
		if s.age >= SHELL_LIFE then
			s.active = false
			activeShells -= 1
			p.Transparency = 1
			continue
		end
		if not s.resting then
			local v = s.velocity + SHELL_GRAVITY * dt
			local move = v * dt
			local hit = Workspace:Raycast(s.position, move, shellParams)
			if hit then
				local n = hit.Normal
				if s.bounced or v.Magnitude < 6 then
					s.resting = true
					s.position = hit.Position + n * (p.Size.Y / 2)
					-- Lie flat on the ground.
					s.rotation = CFrame.fromMatrix(Vector3.zero, s.rotation.RightVector, n)
						* CFrame.Angles(0, 0, math.pi / 2)
				else
					v = (v - 2 * v:Dot(n) * n) * 0.32
					s.position = hit.Position + n * 0.03
					s.bounced = true
					s.spin *= 0.5
				end
			else
				s.position += move
			end
			s.velocity = v
			if not s.resting then
				s.rotation = CFrame.fromAxisAngle(s.axis, s.spin * dt) * s.rotation
			end
			p.CFrame = CFrame.new(s.position) * s.rotation
		end
		local fade = (s.age - (SHELL_LIFE - 0.3)) / 0.3
		if fade > 0 then
			p.Transparency = fade
		end
	end
end

-- Pump and bolt guns throw the casing when they cycle, a moment after the shot.
function EffectsController.ejectShell(
	eject: Attachment,
	config: WeaponConfig,
	scale: number,
	inherit: Vector3?
)
	if config.melee then
		return
	end
	if config.fireMode == "Pump" or config.fireMode == "Bolt" then
		task.delay(0.3, function()
			if eject.Parent then
				spawnShell(eject, config, scale, inherit or Vector3.zero)
			end
		end)
	else
		spawnShell(eject, config, scale, inherit or Vector3.zero)
	end
end

-- Our own shot from the viewmodel: flash and casing. `side` is the left gun
-- of an akimbo pair.
local viewmodelPoints: { [Instance]: { [string]: Attachment } } = setmetatable({}, { __mode = "k" }) :: any

local function viewmodelPoint(side: string?, name: string): Attachment?
	local cam = Workspace.CurrentCamera
	local model = cam
		and cam:FindFirstChild(if side == "Left" then "ViewmodelLeft" else "Viewmodel")
	if not model then
		return nil
	end
	local points = viewmodelPoints[model]
	if not points then
		points = {}
		viewmodelPoints[model] = points
	end
	local a = points[name]
	if not a or not a.Parent then
		local found = model:FindFirstChild(name, true)
		if not found or not found:IsA("Attachment") then
			return nil
		end
		a = found
		points[name] = found
	end
	return a
end

local function rootVelocity(character: Model?): Vector3
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root.AssemblyLinearVelocity else Vector3.zero
end

-- `muzzleName`: which muzzle fired (a double barrel's "MuzzleLower").
function EffectsController.localShot(config: WeaponConfig, side: string?, muzzleName: string?)
	local scale = config.viewmodelScale or ViewmodelConfig.SCALE
	local muzzle = viewmodelPoint(side, muzzleName or "Muzzle")
	if muzzle then
		EffectsController.muzzleFlash(muzzle, config, true)
	end
	local eject = if config.shellsOnFire ~= false then viewmodelPoint(side, "Eject") else nil
	if eject then
		updateShellFilter()
		EffectsController.ejectShell(eject, config, scale, rootVelocity(player.Character))
	end
end

-- Tracers ------------------------------------------------------------------------
-- A thin hot streak that travels from the muzzle to the hit (pooled Beams).

type Tracer = {
	a0: Attachment,
	a1: Attachment,
	glow: Beam,
	core: Beam,
	color: Color3,
	from: Vector3,
	dir: Vector3,
	dist: number,
	speed: number,
	travelled: number,
	length: number,
	active: boolean,
}

local tracers: { Tracer } = {}
local nextTracer = 1
local activeTracers = 0

local function tracerBeam(a0: Attachment, a1: Attachment, width: number, color: Color3): Beam
	local b = Instance.new("Beam")
	b.Attachment0 = a0
	b.Attachment1 = a1
	b.Texture = VFX.TRACER
	b.TextureMode = Enum.TextureMode.Stretch
	b.TextureLength = 1
	b.Color = ColorSequence.new(color)
	b.LightEmission = 1
	b.LightInfluence = 0
	b.FaceCamera = true
	b.Segments = 1
	b.Width0 = width * 0.25
	b.Width1 = width
	b.Enabled = false
	b.Parent = a0
	return b
end

local function newTracer(): Tracer
	local a0 = worldAttachment("TracerTail")
	local a1 = worldAttachment("TracerHead")
	local glow = tracerBeam(a0, a1, 0.14, FIRE)
	glow.Transparency = NumberSequence.new(0.55)
	return {
		a0 = a0,
		a1 = a1,
		glow = glow,
		core = tracerBeam(a0, a1, 0.045, WHITE),
		color = FIRE,
		from = Vector3.zero,
		dir = Vector3.zAxis,
		dist = 0,
		speed = TRACER_SPEED,
		travelled = 0,
		length = TRACER_LENGTH,
		active = false,
	}
end

-- `own`: our own shot (a little fainter: it runs straight away from the eye;
-- fainter still from a suppressed gun, which shows enemies no tracer at all).
function EffectsController.tracer(from: Vector3, to: Vector3, config: WeaponConfig, own: boolean?)
	local offset = to - from
	local dist = offset.Magnitude
	if dist < 4 then
		return
	end
	if #tracers < TRACER_POOL then
		table.insert(tracers, newTracer())
	end
	local t = tracers[nextTracer] or tracers[1]
	nextTracer = nextTracer % TRACER_POOL + 1
	if not t.active then
		activeTracers += 1
	end
	local color = config.tracerColor
	if t.color ~= color then
		t.color = color
		t.glow.Color = ColorSequence.new(color)
	end
	local faint = own and config.suppressed == true
	t.core.Transparency = NumberSequence.new(if faint then 0.7 elseif own then 0.35 else 0)
	t.glow.Transparency = NumberSequence.new(if faint then 0.85 else 0.55)
	t.from = from
	t.dir = offset / dist
	t.dist = dist
	t.length = math.min(TRACER_LENGTH, dist * 0.5)
	-- The whole streak, tail included, has to leave within the time range.
	local time = math.clamp(dist / TRACER_SPEED, TRACER_MIN_TIME, TRACER_MAX_TIME)
	t.speed = (dist + t.length) / time
	t.travelled = 0
	t.active = true
	t.a0.WorldPosition = from
	t.a1.WorldPosition = from + t.dir * 0.1
	t.glow.Enabled = true
	t.core.Enabled = true
end

local function stepTracers(dt: number)
	if activeTracers == 0 then
		return
	end
	for _, t in tracers do
		if not t.active then
			continue
		end
		t.travelled += t.speed * dt
		local head = math.min(t.travelled, t.dist)
		local tail = math.max(0, t.travelled - t.length)
		if tail >= t.dist then
			t.active = false
			activeTracers -= 1
			t.glow.Enabled = false
			t.core.Enabled = false
			continue
		end
		t.a0.WorldPosition = t.from + t.dir * tail
		t.a1.WorldPosition = t.from + t.dir * math.max(head, tail + 0.1)
	end
end

-- Impacts ------------------------------------------------------------------------
-- Shared emitters moved to each hit and Emit()ed. Tinted ones (dust, chips)
-- come in sets per surface colour: changing an emitter's Color would recolour
-- its live particles.

type HitSet = {
	att: Attachment,
	flash: ParticleEmitter,
	sparks: ParticleEmitter,
	metalSparks: ParticleEmitter,
}

type DustSet = {
	color: Color3,
	att: Attachment,
	dust: ParticleEmitter,
	chips: ParticleEmitter,
}

local hitSet: HitSet? = nil
local dustSets: { DustSet } = {}
local MAX_DUST_SETS = 16

local function getHitSet(): HitSet
	if hitSet then
		return hitSet
	end
	local att = worldAttachment("ImpactFx")
	local flash = emitter(att, VFX.GLOW, FIRE)
	fire(flash)
	flash.Lifetime = NumberRange.new(0.05)
	flash.Size = curve({ 0, 0.7, 1, 0.3 })
	flash.Transparency = curve({ 0, 0.15, 1, 1 })
	flash.ZOffset = 0.4
	-- A couple of quick sparks off stone.
	local sparks = sparkEmitter(att, 0.07)
	sparks.Speed = NumberRange.new(14, 30)
	sparks.SpreadAngle = Vector2.new(50, 50)
	sparks.Lifetime = NumberRange.new(0.05, 0.14)
	sparks.Acceleration = Vector3.new(0, -50, 0)
	sparks.Drag = 4
	-- Off metal: a shower that arcs down.
	local metal = sparkEmitter(att, 0.09)
	metal.Speed = NumberRange.new(18, 42)
	metal.SpreadAngle = Vector2.new(60, 60)
	metal.Lifetime = NumberRange.new(0.12, 0.35)
	metal.Acceleration = Vector3.new(0, -70, 0)
	metal.Drag = 2.5
	local set: HitSet = { att = att, flash = flash, sparks = sparks, metalSparks = metal }
	hitSet = set
	return set
end

local function dustSet(surface: Color3): DustSet
	-- Snap the colour so a map's few surface colours share sets.
	local c = Color3.new(
		math.floor(surface.R * 6 + 0.5) / 6,
		math.floor(surface.G * 6 + 0.5) / 6,
		math.floor(surface.B * 6 + 0.5) / 6
	)
	for _, set in dustSets do
		if set.color == c then
			return set
		end
	end
	if #dustSets >= MAX_DUST_SETS then
		return dustSets[1]
	end
	local att = worldAttachment("DustFx")
	-- Dust reads lighter than the surface it comes off.
	local dust = emitter(att, VFX.DUST_2x2, c:Lerp(Color3.fromHex("D8D4CC"), 0.45))
	flipbook(dust)
	dust.Lifetime = NumberRange.new(0.5, 1.0)
	dust.Speed = NumberRange.new(3, 8)
	dust.SpreadAngle = Vector2.new(30, 30)
	dust.EmissionDirection = Enum.NormalId.Front
	dust.Drag = 5
	dust.Acceleration = Vector3.new(0, 1.2, 0)
	dust.RotSpeed = NumberRange.new(-40, 40)
	dust.Size = curve({ 0, 0.3, 1, 1.5 })
	dust.Transparency = curve({ 0, 0.3, 0.4, 0.6, 1, 1 })
	local chips = emitter(att, VFX.CHIPS_2x2, c:Lerp(Color3.new(0, 0, 0), 0.2))
	flipbook(chips)
	chips.Lifetime = NumberRange.new(0.4, 0.7)
	chips.Speed = NumberRange.new(10, 22)
	chips.SpreadAngle = Vector2.new(45, 45)
	chips.EmissionDirection = Enum.NormalId.Front
	chips.Acceleration = Vector3.new(0, -70, 0)
	chips.RotSpeed = NumberRange.new(-500, 500)
	chips.Size = curve({ 0, 0.11, 1, 0.08 })
	local set: DustSet = { color = c, att = att, dust = dust, chips = chips }
	table.insert(dustSets, set)
	return set
end

-- Bullet holes: pooled parts with a SurfaceGui decal, lit by the scene. The
-- oldest is reused when the pool is full.

type Hole = {
	part: Part,
	image: ImageLabel,
	age: number,
	active: boolean,
}

local holes: { Hole } = {}
local nextHole = 1
local activeHoles = 0

local function newHole(): Hole
	local p = fxPart(Vector3.new(0.4, 0.4, 0.02), CFrame.identity, WHITE)
	p.Name = "BulletHole"
	p.Transparency = 1
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(64, 64)
	gui.LightInfluence = 1
	gui.ZOffset = 1
	gui.Parent = p
	local image = Instance.new("ImageLabel")
	image.BackgroundTransparency = 1
	image.Size = UDim2.fromScale(1, 1)
	image.Image = VFX.HOLE
	image.Parent = gui
	return { part = p, image = image, age = 0, active = false }
end

-- `stretch` (width, height multipliers) and `angle` (radians around the
-- normal, else random) make a knife's gouge out of the same decal.
local function placeHole(
	position: Vector3,
	normal: Vector3,
	tint: Color3,
	size: number,
	stretch: Vector2?,
	angle: number?
)
	if #holes < HOLE_POOL then
		table.insert(holes, newHole())
	end
	local h = holes[nextHole] or holes[1]
	nextHole = nextHole % HOLE_POOL + 1
	if not h.active then
		activeHoles += 1
	end
	local s = size * (0.85 + math.random() * 0.3)
	local k = stretch or Vector2.one
	h.part.Size = Vector3.new(s * k.X, s * k.Y, 0.02)
	h.part.CFrame = facing(position + normal * 0.012, normal)
		* CFrame.Angles(0, 0, angle or math.random() * math.pi * 2)
	h.image.ImageColor3 = tint
	h.image.ImageTransparency = 0
	h.age = 0
	h.active = true
end

local function stepHoles(dt: number)
	if activeHoles == 0 then
		return
	end
	for _, h in holes do
		if not h.active then
			continue
		end
		h.age += dt
		if h.age >= HOLE_LIFE then
			h.active = false
			activeHoles -= 1
			h.image.ImageTransparency = 1
			continue
		end
		local fade = (h.age - (HOLE_LIFE - HOLE_FADE)) / HOLE_FADE
		if fade > 0 then
			h.image.ImageTransparency = fade
		end
	end
end

local function combatantOf(part: Instance): Model?
	local node: Instance? = part.Parent
	while node and node ~= Workspace do
		if node:IsA("Model") and node:FindFirstChildOfClass("Humanoid") then
			return node
		end
		node = node.Parent
	end
	return nil
end

local function surfaceColor(hit: BasePart, material: Enum.Material): Color3
	if hit:IsA("Terrain") then
		return (hit :: Terrain):GetMaterialColor(material)
	end
	return hit.Color
end

-- A knife strike on the world: a long thin gouge (the bullet-hole decal
-- stretched) across the surface at `angle` (radians around the normal), longer
-- for a heavy stab's tear. Pooled with the bullet holes.
function EffectsController.slashMark(
	position: Vector3,
	normal: Vector3,
	angle: number,
	heavy: boolean?
)
	if heavy then
		placeHole(position, normal, Color3.fromHex("5A5550"), 0.5, Vector2.new(1.1, 0.5), angle)
	else
		placeHole(position, normal, Color3.fromHex("5A5550"), 0.36, Vector2.new(3.2, 0.22), angle)
	end
end

-- A shot landing at `position`. `hit` is the part it hit: characters get a
-- small puff (no blood); the world gets an impact for its surface and a
-- bullet hole. `size` scales the hole (pellets are smaller).
function EffectsController.impact(
	position: Vector3,
	normal: Vector3,
	hit: Instance?,
	material: Enum.Material?,
	size: number?
)
	if normal.Magnitude < 1e-3 then
		normal = Vector3.yAxis
	end
	normal = normal.Unit
	local cf = facing(position + normal * 0.05, normal)
	if not hit or not hit:IsA("BasePart") then
		return
	end
	if combatantOf(hit) then
		local puff = dustSet(hit.Color:Lerp(Color3.fromHex("8A8A8A"), 0.5))
		puff.att.WorldCFrame = cf
		puff.dust:Emit(1)
		return
	end
	local mat = material or hit.Material
	local kind: Surface = SURFACES[mat] or "Hard"
	local color = surfaceColor(hit, mat)
	local set = getHitSet()
	set.att.WorldCFrame = cf
	local dust = dustSet(color)
	dust.att.WorldCFrame = cf
	local holeSize = 0.36 * (size or 1)
	if kind == "Metal" then
		set.flash:Emit(1)
		set.metalSparks:Emit(math.random(6, 10))
		dust.dust:Emit(1)
		placeHole(position, normal, Color3.fromHex("8E9399"), holeSize * 0.8)
	elseif kind == "Wood" then
		dust.dust:Emit(1)
		dust.chips:Emit(math.random(4, 6)) -- splinters
		placeHole(position, normal, Color3.fromHex("6E5A44"), holeSize)
	elseif kind == "Soft" then
		dust.dust:Emit(3)
		dust.chips:Emit(math.random(2, 4)) -- clods
	elseif kind == "Glass" then
		set.flash:Emit(1)
		dust.chips:Emit(math.random(4, 7))
		placeHole(position, normal, Color3.fromHex("C8CDD2"), holeSize * 0.9)
	else
		set.flash:Emit(1)
		set.sparks:Emit(math.random(1, 3))
		dust.dust:Emit(2)
		dust.chips:Emit(math.random(3, 5))
		placeHole(position, normal, WHITE, holeSize)
	end
end

-- Other players' shots ---------------------------------------------------------

-- Akimbo guns: which side each shooter fires next (weak keys, players leave).
local nextLeft: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local nextMuzzle: { [Instance]: number } = setmetatable({}, { __mode = "k" }) :: any
local remoteParams = RaycastParams.new()
remoteParams.FilterType = Enum.RaycastFilterType.Exclude

-- A named attachment on a character's world weapon (`left`: the left gun).
local function worldPoint(character: Model?, name: string, left: boolean?): Attachment?
	local weapon = character
		and character:FindFirstChild(if left then "WorldWeaponLeft" else "WorldWeapon")
	if not weapon then
		return nil
	end
	local a = weapon:FindFirstChild(name, true)
	return if a and a:IsA("Attachment") then a else nil
end

local function animateWorldWeapon(character: Model?, modelName: string, clipId: string)
	local weapon = character and character:FindFirstChild(modelName)
	if not weapon or not weapon:IsA("Model") then
		return
	end
	local animator = worldAnimators[weapon]
	if not animator then
		animator = GunAnimator.new(weapon, clipId, 1)
		worldAnimators[weapon] = animator
		weapon.Destroying:Once(function()
			worldAnimators[weapon] = nil
		end)
	end
	animator:play("Fire")
end

-- Where a remote shot from `origin` toward `finish` landed (for its impact).
local function remoteImpact(
	character: Model?,
	origin: Vector3,
	finish: Vector3,
	config: WeaponConfig
)
	local offset = finish - origin
	local dist = offset.Magnitude
	if dist < 0.5 or dist > config.range + 1 then
		return
	end
	local exclude: { Instance } = { effectsFolder() }
	if character then
		table.insert(exclude, character)
	end
	remoteParams.FilterDescendantsInstances = exclude
	local result = Workspace:Raycast(origin, offset * ((dist + 0.5) / dist), remoteParams)
	if result then
		EffectsController.impact(
			result.Position,
			result.Normal,
			result.Instance,
			result.Material,
			if config.pellets > 1 then 0.65 else 1
		)
	end
end

-- `shooter` is another player, or a test range dummy model (its harmless
-- tracers use the same effects).
local function onShotFx(shooter: Instance, weaponId: string, origin: Vector3, ends: { Vector3 })
	if
		typeof(weaponId) ~= "string"
		or typeof(shooter) ~= "Instance"
		or typeof(origin) ~= "Vector3"
		or typeof(ends) ~= "table"
	then
		return
	end
	local config = Weapons.get(weaponId)
	if not config then
		return
	end
	local character: Model? = nil
	if shooter:IsA("Player") then
		character = shooter.Character
	elseif shooter:IsA("Model") then
		character = shooter
	end

	local left = false
	local models = config.models
	if models and models.left then
		left = nextLeft[shooter] == true
		nextLeft[shooter] = not left
	end
	if left and models and models.left then
		animateWorldWeapon(character, "WorldWeaponLeft", models.left)
	else
		animateWorldWeapon(character, "WorldWeapon", if models then models.right else weaponId)
	end
	-- Guns with several muzzles fire them in turn (we don't know their
	-- ammo, so just alternate per shooter).
	local muzzleName = "Muzzle"
	local muzzles = config.muzzles
	if muzzles and #muzzles > 1 then
		local n = (nextMuzzle[shooter] or 0) % #muzzles + 1
		nextMuzzle[shooter] = n
		muzzleName = muzzles[n]
	end
	local muzzle = worldPoint(character, muzzleName, left) or worldPoint(character, "Muzzle")
	local from = if muzzle then muzzle.WorldPosition else origin
	local sounds = GunSounds.get(weaponId)
	if config.melee then
		AudioController.playSound(sounds.fireFar, "Enemy", from)
		return
	end
	local cam = Workspace.CurrentCamera
	local near = cam ~= nil and (cam.CFrame.Position - from).Magnitude < DETAIL_RANGE
	if muzzle then
		EffectsController.muzzleFlash(muzzle, config, false, near)
	end
	if near and config.shellsOnFire ~= false then
		local eject = worldPoint(character, "Eject", left)
		if eject then
			updateShellFilter()
			EffectsController.ejectShell(eject, config, 1, rootVelocity(character))
		end
	end
	AudioController.playSound(sounds.fireFar, "Enemy", from)
	local maxPellets =
		math.max(config.pellets, if config.altFire then config.altFire.pellets else 0)
	for i, e in ends do
		if typeof(e) ~= "Vector3" or i > maxPellets then
			continue
		end
		if not config.suppressed then
			EffectsController.tracer(from, e, config)
		end
		remoteImpact(character, origin, e, config)
	end
end

function EffectsController.start()
	effectsFolder()
	-- Load the atlas and textures up front so the first shot isn't missing them.
	task.spawn(function()
		local probe = Instance.new("Sound")
		probe.SoundId = Sounds.ATLAS
		local preload: { Instance | string } = { probe }
		for _, id in VFX do
			table.insert(preload, id)
		end
		for _, id in GunSounds.allIds() do
			if string.sub(id, 1, 6) ~= "atlas:" then
				local s = Instance.new("Sound")
				s.SoundId = id
				table.insert(preload, s)
			end
		end
		game:GetService("ContentProvider"):PreloadAsync(preload)
		probe:Destroy()
	end)
	Net.unreliable("ShotFx").OnClientEvent:Connect(onShotFx)
	if RunService:IsStudio() then
		Workspace:GetAttributeChangedSignal("VfxTimeScale"):Connect(function()
			local value = Workspace:GetAttribute("VfxTimeScale")
			timeScale = if typeof(value) == "number" then math.clamp(value, 0, 1) else 1
			for _, root in { effectsFolder(), Workspace.Terrain, Workspace.CurrentCamera } do
				for _, d in root:GetDescendants() do
					if d:IsA("ParticleEmitter") then
						d.TimeScale = timeScale
					end
				end
			end
		end)
	end
	RunService.RenderStepped:Connect(function(frameDt)
		local dt = frameDt * timeScale
		fxClock += dt
		for _, animator in worldAnimators do
			animator:update(dt)
		end
		stepTracers(dt)
		stepShells(dt)
		stepHoles(dt)
		stepWisps(dt)
		stepLights(fxClock)
	end)
end

return EffectsController
