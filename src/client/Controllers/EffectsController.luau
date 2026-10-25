--!strict
-- Shot feedback in the Style B neon look (Gunplay.md §5): muzzle flash, smoke,
-- shell casings, tracers, impacts (sparks, dust, bullet holes), the Ray Trace
-- charge and rail, Loopback discs, the Null beam, gun sounds, other players'
-- shots, the pixel-dissolve on death (no blood) and the kill flash.
--
-- Textures come from tools/vfx/make_vfx_textures.py (Config/VfxTextures).
-- Everything that fires often is pooled: tracers, shells and bullet holes are
-- recycled, and bursts use shared emitters that are moved and Emit()ed, so an
-- automatic gun creates no instances per shot.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Audio = require(ReplicatedStorage.Shared.Config.Audio)
local Combat = require(ReplicatedStorage.Shared.Config.Combat)
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

local NEON = Color3.fromHex("00E5FF")
local GOLD = Color3.fromHex("FFC83D")
local MAGENTA = Color3.fromHex("FF3DCB")
local WHITE = Color3.new(1, 1, 1)
local SMOKE = Color3.fromHex("A9B3C7")
local BRASS = Color3.fromHex("D9A441")

-- Loopback discs start at the muzzle and blend onto the simulated path
-- (which starts at the camera, like the server's) over this many seconds.
local DISC_MERGE_TIME = 0.12
-- A beam with no update for this long switches off (other players' beams
-- arrive as ~10 Hz unreliable ticks).
local BEAM_TIMEOUT = 0.25

local TRACER_POOL = 40
local TRACER_SPEED = 1100 -- studs/s, within the time range below
local TRACER_MIN_TIME = 0.05 -- close shots still show for a few frames
local TRACER_MAX_TIME = 0.16
local TRACER_LENGTH = 14
local HOLE_POOL = 48
local HOLE_LIFE = 4 -- seconds, the last HOLE_FADE of it fading
local HOLE_FADE = 1
local RIM_LIFE = 0.7
local SHELL_POOL = 32
local SHELL_LIFE = 1.1
local SHELL_GRAVITY = Vector3.new(0, -60, 0)
local LIGHT_TIME = 0.06
-- First-person flashes are this much smaller again than the viewmodel's scale
-- (the gun sits right in front of the camera).
local FP_FLASH = 0.8
-- Other players' shells and smoke only within this range of the camera.
local DETAIL_RANGE = 90

-- Guns that don't throw a casing when they fire (energy, revolver, break-action, melee).
local NO_SHELLS: { [string]: boolean } = {
	RayTrace = true,
	Null = true,
	Loopback = true,
	Root = true,
	Splinter = true,
	Handshake = true,
	Cutter = true,
}

local METAL: { [Enum.Material]: boolean } = {
	[Enum.Material.Metal] = true,
	[Enum.Material.DiamondPlate] = true,
	[Enum.Material.CorrodedMetal] = true,
	[Enum.Material.Foil] = true,
}
local NO_DUST: { [Enum.Material]: boolean } = {
	[Enum.Material.Metal] = true,
	[Enum.Material.DiamondPlate] = true,
	[Enum.Material.CorrodedMetal] = true,
	[Enum.Material.Foil] = true,
	[Enum.Material.Glass] = true,
	[Enum.Material.Neon] = true,
	[Enum.Material.ForceField] = true,
	[Enum.Material.Ice] = true,
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
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = size
	p.CFrame = cf
	p.Parent = effectsFolder()
	return p
end

-- An invisible anchored part to emit from (Box/Sphere shapes need a part).
local function emitterPart(name: string): Part
	local p = fxPart(Vector3.one, CFrame.identity, WHITE)
	p.Name = name
	p.Transparency = 1
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

-- A glowing, burst-only emitter (Enabled = false; fire it with Emit).
local function emitter(parent: Instance, texture: string, color: Color3): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = texture
	e.Color = ColorSequence.new(color)
	e.Enabled = false
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Speed = NumberRange.new(0)
	e.Rotation = NumberRange.new(0, 360)
	e.Lifetime = NumberRange.new(0.1)
	e.TimeScale = timeScale
	e.Parent = parent
	return e
end

-- 2x2 sheet; each particle keeps one random frame.
local function flipbook(e: ParticleEmitter)
	e.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
	e.FlipbookMode = Enum.ParticleFlipbookMode.Loop
	e.FlipbookFramerate = NumberRange.new(0)
	e.FlipbookStartRandom = true
end

local function sparkEmitter(parent: Instance, color: Color3, size: number): ParticleEmitter
	local e = emitter(parent, VFX.SPARK, color)
	e.Orientation = Enum.ParticleOrientation.VelocityParallel
	e.Rotation = NumberRange.new(0)
	e.Size = curve({ 0, size, 1, size * 0.4 })
	e.Squash = curve({ 0, 1.2, 1, 0.6 })
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
-- Each muzzle gets a rig of emitters the first time it fires: a front star and a
-- side flame (locked to the gun), a hot core, sparks, smoke and a light.

type MuzzleRig = {
	front: ParticleEmitter,
	side: ParticleEmitter?,
	core: ParticleEmitter,
	sparks: ParticleEmitter?,
	ring: ParticleEmitter?,
	smoke: ParticleEmitter,
	light: PointLight,
	brightness: number,
	smokeCount: number,
}

local rigs: { [Attachment]: MuzzleRig } = setmetatable({}, { __mode = "k" }) :: any

local function flashSize(config: WeaponConfig): number
	local class = config.class
	if class == "Shotgun" then
		return 1.3
	elseif class == "Sniper" then
		return 1.25
	elseif class == "MachineGun" then
		return 1.05
	elseif class == "Sidearm" or class == "SMG" then
		return 0.85
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
	local color = config.tracerColor
	local suppressed = config.suppressed == true
	local charge = config.fireMode == "Charge"
	local s = scale * flashSize(config) * (if suppressed then 0.45 else 1)

	local holder = Instance.new("Attachment")
	holder.Name = "FxMuzzle"
	holder.CFrame = muzzle.CFrame
	holder.Parent = parent

	local front = emitter(holder, VFX.MUZZLE_FRONT_2x2, color)
	flipbook(front)
	front.LockedToPart = true
	front.Lifetime = NumberRange.new(0.05)
	front.Size = curve({ 0, 1.1 * s, 1, 1.5 * s })
	front.Transparency = curve({ 0, 0, 0.6, 0.1, 1, 1 })

	local core = emitter(holder, VFX.GLOW, WHITE)
	core.LockedToPart = true
	core.Lifetime = NumberRange.new(0.045)
	core.Size = curve({ 0, 0.5 * s, 1, 0.25 * s })
	core.Color = ColorSequence.new(WHITE, color)

	local side: ParticleEmitter? = nil
	local sparks: ParticleEmitter? = nil
	-- Seen down the barrel the side flame degenerates into a sliver, so first
	-- person shows the front star only.
	if not suppressed and not charge and not firstPerson then
		-- The side flame's texture starts at its bottom edge, so it sits half
		-- its size ahead of the muzzle.
		local sideSize = 1.15 * s
		local ahead = Instance.new("Attachment")
		ahead.Name = "FxMuzzleSide"
		ahead.CFrame = muzzle.CFrame * CFrame.new(0, 0, -sideSize * 0.46)
		ahead.Parent = parent
		local e = emitter(ahead, VFX.MUZZLE_SIDE_2x2, color)
		flipbook(e)
		e.LockedToPart = true
		e.Orientation = Enum.ParticleOrientation.VelocityParallel
		e.EmissionDirection = Enum.NormalId.Front
		e.Speed = NumberRange.new(0.01)
		e.Rotation = NumberRange.new(0)
		e.Lifetime = NumberRange.new(0.05)
		e.Size = curve({ 0, sideSize * 0.85, 1, sideSize })
		e.Transparency = curve({ 0, 0, 0.6, 0.15, 1, 1 })
		side = e
	end
	if not suppressed and not charge then
		local sp = sparkEmitter(holder, WHITE:Lerp(color, 0.5), 0.22 * s)
		sp.Speed = NumberRange.new(30 * s, 55 * s)
		sp.SpreadAngle = Vector2.new(14, 14)
		sp.Lifetime = NumberRange.new(0.04, 0.09)
		sp.Drag = 6
		sparks = sp
	end

	local ring: ParticleEmitter? = nil
	if charge then
		local r = emitter(holder, VFX.RING, color)
		r.Lifetime = NumberRange.new(0.22)
		r.Size = curve({ 0, 0.4 * s, 1, 3.2 * s })
		r.Transparency = curve({ 0, 0, 1, 1 })
		r.Rotation = NumberRange.new(0)
		ring = r
	end

	local smoke = emitter(holder, VFX.SMOKE_2x2, SMOKE)
	flipbook(smoke)
	smoke.LightEmission = 0
	smoke.LightInfluence = 0.4
	smoke.Lifetime = NumberRange.new(0.5, 0.9)
	smoke.Speed = NumberRange.new(1.5 * s, 3.5 * s)
	smoke.SpreadAngle = Vector2.new(20, 20)
	smoke.EmissionDirection = Enum.NormalId.Front
	smoke.Acceleration = Vector3.new(0, 2 * s, 0)
	smoke.Drag = 2.5
	smoke.RotSpeed = NumberRange.new(-60, 60)
	smoke.Size = curve({ 0, 0.25 * s, 1, 1.3 * s })
	smoke.Transparency = curve({ 0, 1, 0.15, 0.78, 1, 1 })

	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = if suppressed then 5 else 8
	light.Shadows = false
	light.Enabled = false
	light.Parent = holder

	local rig: MuzzleRig = {
		front = front,
		side = side,
		core = core,
		sparks = sparks,
		ring = ring,
		smoke = smoke,
		light = light,
		-- Fast guns pop a dimmer light, or the room strobes.
		brightness = if suppressed then 0.8 elseif config.fireInterval < 0.1 then 1.4 else 2.5,
		smokeCount = if config.class == "Shotgun" or config.class == "Sniper" then 3 else 1,
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
	rig.core:Emit(1)
	if rig.side then
		rig.side:Emit(1)
	end
	if rig.sparks then
		rig.sparks:Emit(math.random(2, 4))
	end
	if rig.ring then
		rig.ring:Emit(1)
	end
	if smoke ~= false then
		rig.smoke:Emit(rig.smokeCount)
	end
	popLight(rig.light, rig.brightness)
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
		return Vector3.new(0.22, 0.075, 0.075)
	end
	return Vector3.new(0.14, 0.07, 0.07)
end

local function spawnShell(eject: Attachment, config: WeaponConfig, scale: number, inherit: Vector3)
	if #shells < SHELL_POOL then
		local p = fxPart(Vector3.one, CFrame.identity, BRASS)
		p.Name = "Shell"
		p.Shape = Enum.PartType.Cylinder
		p.Material = Enum.Material.Metal
		p.Reflectance = 0.15
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
	p.Color = if config.class == "Shotgun" then Color3.fromHex("C23A4E") else BRASS
	p.Transparency = 0
	shell.position = cf.Position
	shell.rotation = cf.Rotation * CFrame.Angles(0, math.pi / 2, 0) -- axis across the gun
	local out = cf.LookVector * (7 + math.random() * 4) + cf.UpVector * (4 + math.random() * 3)
	shell.velocity = (out - cf.RightVector * math.random() * 2) * math.sqrt(scale) + inherit
	shell.axis = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5).Unit
	shell.spin = 18 + math.random() * 16
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
				else
					v = (v - 2 * v:Dot(n) * n) * 0.35
					s.position = hit.Position + n * 0.03
					s.bounced = true
					s.spin *= 0.5
				end
			else
				s.position += move
			end
			s.velocity = v
			s.rotation = CFrame.fromAxisAngle(s.axis, s.spin * dt) * s.rotation
			p.CFrame = CFrame.new(s.position) * s.rotation
		end
		local fade = (s.age - (SHELL_LIFE - 0.25)) / 0.25
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
	if NO_SHELLS[config.id] or config.melee then
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

-- Our own shot from the viewmodel: flash and casing. `side` is Dual Boot's gun.
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

function EffectsController.localShot(config: WeaponConfig, side: string?)
	local scale = config.viewmodelScale or ViewmodelConfig.SCALE
	local muzzle = viewmodelPoint(side, "Muzzle")
	if muzzle then
		EffectsController.muzzleFlash(muzzle, config, true)
	end
	local eject = viewmodelPoint(side, "Eject")
	if eject then
		updateShellFilter()
		EffectsController.ejectShell(eject, config, scale, rootVelocity(player.Character))
	end
end

-- Tracers ------------------------------------------------------------------------
-- A bright streak that travels from the muzzle to the hit (pooled Beams).

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
	b.Width0 = width * 0.3
	b.Width1 = width
	b.Enabled = false
	b.Parent = a0
	return b
end

local function newTracer(): Tracer
	local a0 = worldAttachment("TracerTail")
	local a1 = worldAttachment("TracerHead")
	return {
		a0 = a0,
		a1 = a1,
		glow = tracerBeam(a0, a1, 0.28, NEON),
		core = tracerBeam(a0, a1, 0.08, WHITE),
		color = NEON,
		from = Vector3.zero,
		dir = Vector3.zAxis,
		dist = 0,
		speed = TRACER_SPEED,
		travelled = 0,
		length = TRACER_LENGTH,
		active = false,
	}
end

function EffectsController.tracer(from: Vector3, to: Vector3, color: Color3)
	local offset = to - from
	local dist = offset.Magnitude
	if dist < 2 then
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
	if t.color ~= color then
		t.color = color
		t.glow.Color = ColorSequence.new(color)
	end
	t.from = from
	t.dir = offset / dist
	t.dist = dist
	t.length = math.min(TRACER_LENGTH, dist * 0.6)
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
-- Shared emitters per colour, moved to each hit and Emit()ed. (Changing an
-- emitter's Color would recolour its live particles, hence one set per colour.)

type ImpactSet = {
	color: Color3,
	att: Attachment,
	flash: ParticleEmitter,
	sparks: ParticleEmitter,
	ring: ParticleEmitter,
	pixels: ParticleEmitter,
}

type DustSet = {
	color: Color3,
	att: Attachment,
	dust: ParticleEmitter,
	chips: ParticleEmitter,
}

local impactSets: { ImpactSet } = {}
local dustSets: { DustSet } = {}
local MAX_DUST_SETS = 16

local function impactSet(color: Color3): ImpactSet
	for _, set in impactSets do
		if set.color == color then
			return set
		end
	end
	local att = worldAttachment("ImpactFx")
	local flash = emitter(att, VFX.IMPACT_FLASH, WHITE:Lerp(color, 0.6))
	flash.Lifetime = NumberRange.new(0.07)
	flash.Size = curve({ 0, 1.3, 1, 0.5 })
	flash.Transparency = curve({ 0, 0, 1, 0.6 })
	flash.ZOffset = 0.5
	local sparks = sparkEmitter(att, WHITE:Lerp(color, 0.35), 0.32)
	sparks.Speed = NumberRange.new(14, 34)
	sparks.SpreadAngle = Vector2.new(55, 55)
	sparks.Lifetime = NumberRange.new(0.12, 0.3)
	sparks.Acceleration = Vector3.new(0, -45, 0)
	sparks.Drag = 3
	sparks.Color = ColorSequence.new(WHITE:Lerp(color, 0.3), color)
	local ring = emitter(att, VFX.RING, color)
	ring.Lifetime = NumberRange.new(0.16)
	ring.Size = curve({ 0, 0.3, 1, 2.4 })
	ring.Transparency = curve({ 0, 0, 1, 1 })
	ring.ZOffset = 0.4
	local pixels = emitter(att, VFX.PIXEL_2x2, color)
	flipbook(pixels)
	pixels.Rotation = NumberRange.new(0)
	pixels.Speed = NumberRange.new(5, 12)
	pixels.SpreadAngle = Vector2.new(70, 70)
	pixels.EmissionDirection = Enum.NormalId.Front
	pixels.Lifetime = NumberRange.new(0.2, 0.4)
	pixels.Drag = 5
	pixels.Size = curve({ 0, 0.2, 1, 0 })
	pixels.Color = ColorSequence.new(color, MAGENTA)
	local set: ImpactSet = {
		color = color,
		att = att,
		flash = flash,
		sparks = sparks,
		ring = ring,
		pixels = pixels,
	}
	table.insert(impactSets, set)
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
	local tint = c:Lerp(Color3.fromHex("C9CED8"), 0.35)
	local dust = emitter(att, VFX.DUST_2x2, tint)
	flipbook(dust)
	dust.LightEmission = 0
	dust.LightInfluence = 1
	dust.Lifetime = NumberRange.new(0.45, 0.8)
	dust.Speed = NumberRange.new(2, 6)
	dust.SpreadAngle = Vector2.new(35, 35)
	dust.EmissionDirection = Enum.NormalId.Front
	dust.Drag = 4
	dust.Acceleration = Vector3.new(0, 1.5, 0)
	dust.RotSpeed = NumberRange.new(-40, 40)
	dust.Size = curve({ 0, 0.4, 1, 1.6 })
	dust.Transparency = curve({ 0, 0.35, 1, 1 })
	local chips = emitter(att, VFX.DEBRIS_2x2, c:Lerp(Color3.new(0, 0, 0), 0.15))
	flipbook(chips)
	chips.LightEmission = 0
	chips.LightInfluence = 1
	chips.Lifetime = NumberRange.new(0.35, 0.6)
	chips.Speed = NumberRange.new(8, 18)
	chips.SpreadAngle = Vector2.new(50, 50)
	chips.EmissionDirection = Enum.NormalId.Front
	chips.Acceleration = Vector3.new(0, -60, 0)
	chips.RotSpeed = NumberRange.new(-400, 400)
	chips.Size = NumberSequence.new(0.14)
	local set: DustSet = { color = c, att = att, dust = dust, chips = chips }
	table.insert(dustSets, set)
	return set
end

-- Bullet holes: pooled parts with a SurfaceGui (dark hole + a glowing rim that
-- cools off first). The oldest is reused when the pool is full.

type Hole = {
	part: Part,
	hole: ImageLabel,
	rim: ImageLabel,
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
	gui.LightInfluence = 0
	gui.Brightness = 3.5
	gui.ZOffset = 1
	gui.Parent = p
	local function label(image: string): ImageLabel
		local l = Instance.new("ImageLabel")
		l.BackgroundTransparency = 1
		l.Size = UDim2.fromScale(1, 1)
		l.Image = image
		l.Parent = gui
		return l
	end
	return { part = p, hole = label(VFX.HOLE), rim = label(VFX.HOLE_RIM), age = 0, active = false }
end

local function placeHole(position: Vector3, normal: Vector3, color: Color3, size: number)
	if #holes < HOLE_POOL then
		table.insert(holes, newHole())
	end
	local h = holes[nextHole] or holes[1]
	nextHole = nextHole % HOLE_POOL + 1
	if not h.active then
		activeHoles += 1
	end
	h.part.Size = Vector3.new(size, size, 0.02)
	h.part.CFrame = facing(position + normal * 0.012, normal)
		* CFrame.Angles(0, 0, math.random() * math.pi * 2)
	h.hole.ImageTransparency = 0
	h.rim.ImageTransparency = 0
	h.rim.ImageColor3 = WHITE:Lerp(color, 0.5)
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
			h.hole.ImageTransparency = 1
			h.rim.ImageTransparency = 1
			continue
		end
		if h.age < RIM_LIFE + dt then
			h.rim.ImageTransparency = math.min(h.age / RIM_LIFE, 1)
		end
		local fade = (h.age - (HOLE_LIFE - HOLE_FADE)) / HOLE_FADE
		if fade > 0 then
			h.hole.ImageTransparency = fade
		end
	end
end

-- Same rule as the server: a hitbox is a body part directly under a model
-- with a Humanoid.
local function liveHitbox(part: Instance): boolean
	local model = part.Parent
	if not Combat.BODY_PARTS[part.Name] or not model or not model:IsA("Model") then
		return false
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
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

-- A shot landing at `position`. `hit` is the part it hit: characters get neon
-- sparks and pixels (no blood); the world gets sparks, dust in the surface's
-- colour, chips and a bullet hole. `size` scales the hole (pellets are smaller).
function EffectsController.impact(
	position: Vector3,
	normal: Vector3,
	color: Color3?,
	hit: Instance?,
	material: Enum.Material?,
	size: number?
)
	if normal.Magnitude < 1e-3 then
		normal = Vector3.yAxis
	end
	normal = normal.Unit
	local c = color or NEON
	local set = impactSet(c)
	set.att.WorldCFrame = facing(position + normal * 0.05, normal)
	set.flash:Emit(1)
	local character = hit and combatantOf(hit)
	if character or not hit or not hit:IsA("BasePart") then
		set.ring:Emit(1)
		set.sparks:Emit(7)
		set.pixels:Emit(5)
		return
	end
	local mat = material or hit.Material
	set.sparks:Emit(if METAL[mat] then 9 else 4)
	if METAL[mat] then
		local gold = impactSet(GOLD)
		gold.att.WorldCFrame = set.att.WorldCFrame
		gold.sparks:Emit(5)
	end
	if not NO_DUST[mat] then
		local surface = if hit:IsA("Terrain")
			then (hit :: Terrain):GetMaterialColor(mat)
			else hit.Color
		local dust = dustSet(surface)
		dust.att.WorldCFrame = set.att.WorldCFrame
		dust.dust:Emit(2)
		dust.chips:Emit(3)
	end
	if hit.Anchored and hit.Transparency < 0.9 then
		placeHole(position, normal, c, 0.75 * (size or 1))
	end
end

-- Ray Trace: charge and rail -------------------------------------------------------

type ChargeFx = {
	part: Part,
	glow: ParticleEmitter,
	rings: ParticleEmitter,
	motes: ParticleEmitter,
	light: PointLight,
	color: Color3,
	scale: number,
	level: number,
}

local chargeFx: ChargeFx? = nil

local function buildCharge(color: Color3, scale: number): ChargeFx
	local part = emitterPart("ChargeFx")
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.one * 1.4 * scale
	local center = Instance.new("Attachment")
	center.Parent = part
	local glow = emitter(center, VFX.GLOW, color)
	glow.LockedToPart = true
	glow.Rate = 40
	glow.Lifetime = NumberRange.new(0.12)
	glow.Size = NumberSequence.new(0.3 * scale)
	glow.Color = ColorSequence.new(WHITE, color)
	local rings = emitter(center, VFX.RING, color)
	rings.LockedToPart = true
	rings.Rotation = NumberRange.new(0)
	rings.Lifetime = NumberRange.new(0.25)
	rings.Size = curve({ 0, 1.2 * scale, 1, 0.1 * scale })
	rings.Transparency = curve({ 0, 1, 0.3, 0.2, 1, 0 })
	-- Motes drawn in from the surface of the ball.
	local motes = sparkEmitter(part, WHITE:Lerp(color, 0.4), 0.16 * scale)
	motes.LockedToPart = true
	motes.Shape = Enum.ParticleEmitterShape.Sphere
	motes.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	motes.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
	motes.Speed = NumberRange.new(4 * scale, 5 * scale)
	motes.Lifetime = NumberRange.new(0.13)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 5
	light.Shadows = false
	light.Parent = part
	return {
		part = part,
		glow = glow,
		rings = rings,
		motes = motes,
		light = light,
		color = color,
		scale = scale,
		level = -1,
	}
end

local function setChargeEnabled(fx: ChargeFx, on: boolean)
	fx.glow.Enabled = on
	fx.rings.Enabled = on
	fx.motes.Enabled = on
	fx.light.Enabled = on
end

-- Ray Trace charging at `cf` (the muzzle) with `alpha` 0..1; nil switches it off.
-- Call every frame while charging.
function EffectsController.charge(cf: CFrame?, alpha: number, color: Color3, scale: number?)
	local fx = chargeFx
	if not cf then
		if fx then
			setChargeEnabled(fx, false)
			fx.level = -1
		end
		return
	end
	local s = scale or 1
	if not fx or fx.color ~= color or fx.scale ~= s then
		if fx then
			fx.part:Destroy()
		end
		fx = buildCharge(color, s)
		chargeFx = fx
	end
	local f = fx :: ChargeFx
	f.part.CFrame = cf
	if f.level < 0 then
		setChargeEnabled(f, true)
	end
	-- Rebuild sequences only when the (stepped) level changes.
	local level = math.floor(math.clamp(alpha, 0, 1) * 8 + 0.5) / 8
	if level ~= f.level then
		f.level = level
		f.glow.Size = NumberSequence.new((0.4 + level * 1.4) * s)
		f.rings.Rate = 3 + level * 9
		f.motes.Rate = 10 + level * 50
		f.light.Brightness = 0.2 + level * 1.1
		if level >= 1 then
			f.rings.Color = ColorSequence.new(WHITE)
		else
			f.rings.Color = ColorSequence.new(color)
		end
	end
end

local railPart: Part? = nil
local railPixels: ParticleEmitter? = nil

local function railEmitter(): (Part, ParticleEmitter)
	if railPart and railPixels and railPart.Parent then
		return railPart, railPixels
	end
	local p = emitterPart("RailFx")
	local e = emitter(p, VFX.PIXEL_2x2, MAGENTA)
	flipbook(e)
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Rotation = NumberRange.new(0)
	e.Speed = NumberRange.new(0.3, 2)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Lifetime = NumberRange.new(0.5, 1.1)
	e.Drag = 1.5
	e.Acceleration = Vector3.new(0, 1.2, 0)
	e.Size = curve({ 0, 0.2, 1, 0 })
	e.Transparency = curve({ 0, 0, 0.7, 0.2, 1, 1 })
	railPart = p
	railPixels = e
	return p, e
end

type Rail = {
	a0: Attachment,
	a1: Attachment,
	beams: { Beam },
	widths: { number },
	lives: { number },
	age: number,
}

local rails: { Rail } = {}
local RAIL_LIFE = 0.6

-- Each strand thins out over its own life.
local function stepRails(dt: number)
	for i = #rails, 1, -1 do
		local r = rails[i]
		r.age += dt
		if r.age >= RAIL_LIFE then
			r.a0:Destroy()
			r.a1:Destroy()
			table.remove(rails, i)
			continue
		end
		for k, b in r.beams do
			local left = math.max(0, 1 - r.age / r.lives[k])
			local w = r.widths[k] * left * left
			b.Width0 = w * 0.2
			b.Width1 = w
		end
	end
end

-- Ray Trace's rail: a twisting energy beam that lingers and sheds pixels.
function EffectsController.beam(from: Vector3, to: Vector3, color: Color3)
	local offset = to - from
	local dist = offset.Magnitude
	if dist < 1 then
		return
	end
	local a0 = worldAttachment("RailStart")
	local a1 = worldAttachment("RailEnd")
	a0.WorldPosition = from
	a1.WorldPosition = to
	local function rail(
		texture: string?,
		width: number,
		c: Color3,
		speed: number,
		length: number
	): Beam
		local b = Instance.new("Beam")
		b.Attachment0 = a0
		b.Attachment1 = a1
		if texture then
			b.Texture = texture
			b.TextureMode = Enum.TextureMode.Static
			b.TextureLength = length
			b.TextureSpeed = speed
		end
		b.Color = ColorSequence.new(c)
		-- Textured strands only half additive, so the colour holds on a bright sky.
		b.LightEmission = if texture then 0.6 else 1
		b.LightInfluence = 0
		b.Brightness = 2
		b.FaceCamera = true
		b.Segments = 1
		-- Thin at the muzzle (right in front of the shooter's camera).
		b.Width0 = width * 0.2
		b.Width1 = width
		b.Parent = a0
		return b
	end
	table.insert(rails, {
		a0 = a0,
		a1 = a1,
		beams = {
			rail(VFX.BEAM_HELIX, 1.4, color, 1.2, 3),
			rail(VFX.BEAM_ENERGY, 2, color, -3, 6),
			rail(nil, 0.14, WHITE, 0, 1),
		},
		widths = { 1.4, 2, 0.14 },
		lives = { RAIL_LIFE, 0.3, 0.35 },
		age = 0,
	})
	local part, pixels = railEmitter()
	part.Size = Vector3.new(0.35, 0.35, dist)
	part.CFrame = CFrame.lookAt(from + offset / 2, to, upFor(offset))
	pixels:Emit(math.clamp(math.floor(dist * 0.7), 8, 120))
end

-- Loopback discs ---------------------------------------------------------------
-- The server flies the real disc and applies its damage; this is a client copy
-- that follows the same path (same start, Spherecast, bounces and lifetime).

type Disc = {
	part: BasePart,
	glow: ParticleEmitter,
	halo: ParticleEmitter,
	shed: ParticleEmitter,
	position: Vector3, -- simulated, matches the server's path
	velocity: Vector3,
	offset: Vector3, -- muzzle minus simulated start; fades out over DISC_MERGE_TIME
	age: number,
	bounces: number,
	stats: Types.ProjectileStats,
	params: RaycastParams,
	color: Color3,
}

local discs: { Disc } = {}

-- Disc orientation: flat like a frisbee (axis up), facing its flight, spinning.
local function discCFrame(position: Vector3, velocity: Vector3, spin: number): CFrame
	local look = if velocity.Magnitude > 1e-3 then velocity.Unit else Vector3.zAxis
	local up = if math.abs(look.Y) > 0.99 then Vector3.zAxis else Vector3.yAxis
	return CFrame.lookAt(position, position + look, up)
		* CFrame.Angles(0, 0, math.pi / 2)
		* CFrame.Angles(spin, 0, 0)
end

-- Spawns the visual disc for a shot from `origin` (the shooter's camera) in
-- `dir`. `visualFrom` is where it should appear to leave (the muzzle).
function EffectsController.disc(
	shooter: Model?,
	origin: Vector3,
	dir: Vector3,
	config: WeaponConfig,
	visualFrom: Vector3?
)
	local stats = config.projectile
	if not stats or dir.Magnitude < 1e-3 then
		return
	end
	dir = dir.Unit
	local start = origin + dir * 1.5
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { effectsFolder() }
	if shooter then
		table.insert(exclude, shooter)
	end
	local cam = Workspace.CurrentCamera
	if cam then
		table.insert(exclude, cam)
	end
	params.FilterDescendantsInstances = exclude

	local r = stats.radius
	local color = config.tracerColor
	-- Thin invisible block; both flat faces show the glowing disc texture.
	local part =
		fxPart(Vector3.new(0.05, r * 2.2, r * 2.2), discCFrame(visualFrom or start, dir, 0), color)
	part.Transparency = 1
	for _, face in { Enum.NormalId.Right, Enum.NormalId.Left } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		gui.CanvasSize = Vector2.new(128, 128)
		gui.LightInfluence = 0
		gui.Brightness = 3
		gui.Parent = part
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Size = UDim2.fromScale(1, 1)
		img.Image = VFX.DISC
		img.ImageColor3 = WHITE:Lerp(color, 0.75)
		img.Parent = gui
	end
	local center = Instance.new("Attachment")
	center.Parent = part
	local glow = emitter(center, VFX.GLOW, color)
	glow.LockedToPart = true
	glow.Rate = 30
	glow.Lifetime = NumberRange.new(0.1)
	glow.Size = NumberSequence.new(r * 3.2)
	glow.Transparency = NumberSequence.new(0.35)
	glow.LightEmission = 0.6
	glow.Enabled = true
	-- A camera-facing ring, so the disc still reads when seen edge-on.
	local halo = emitter(center, VFX.RING, color)
	halo.LockedToPart = true
	halo.Rotation = NumberRange.new(0)
	halo.Rate = 24
	halo.Lifetime = NumberRange.new(0.08)
	halo.Size = NumberSequence.new(r * 2.4)
	halo.LightEmission = 0.6
	halo.Enabled = true
	-- Glitch pixels shed behind it.
	local shed = emitter(center, VFX.PIXEL_2x2, color)
	flipbook(shed)
	shed.Rotation = NumberRange.new(0)
	shed.Rate = 40
	shed.Lifetime = NumberRange.new(0.2, 0.4)
	shed.Speed = NumberRange.new(0.5, 2)
	shed.SpreadAngle = Vector2.new(180, 180)
	shed.Size = curve({ 0, 0.16, 1, 0 })
	shed.Enabled = true
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = 2
	light.Range = 8
	light.Shadows = false
	light.Parent = part
	-- Ribbon trail from the disc's rim.
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, r * 0.8, 0)
	a0.Parent = part
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -r * 0.8, 0)
	a1.Parent = part
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Texture = VFX.BEAM_ENERGY
	trail.TextureMode = Enum.TextureMode.Wrap
	trail.TextureLength = 3
	trail.Color = ColorSequence.new(WHITE:Lerp(color, 0.6), color)
	trail.LightEmission = 1
	trail.LightInfluence = 0
	trail.Lifetime = 0.2
	trail.Transparency = curve({ 0, 0.1, 1, 1 })
	trail.WidthScale = curve({ 0, 1, 1, 0.3 })
	trail.FaceCamera = true
	trail.Parent = part

	table.insert(discs, {
		part = part,
		glow = glow,
		halo = halo,
		shed = shed,
		position = start,
		velocity = dir * stats.speed,
		offset = if visualFrom then visualFrom - start else Vector3.zero,
		age = 0,
		bounces = stats.bounces,
		stats = stats,
		params = params,
		color = color,
	})
end

local function endDisc(d: Disc)
	-- Hide the disc but let its trail and pixels fade out.
	for _, child in d.part:GetChildren() do
		if child:IsA("SurfaceGui") or child:IsA("PointLight") then
			child:Destroy()
		end
	end
	d.glow.Enabled = false
	d.halo.Enabled = false
	d.shed.Enabled = false
	local set = impactSet(d.color)
	set.att.WorldPosition = d.part.Position
	set.ring:Emit(1)
	set.pixels:Emit(8)
	Debris:AddItem(d.part, 0.45)
end

local function stepDiscs(dt: number)
	for i = #discs, 1, -1 do
		local d = discs[i]
		d.age += dt
		local alive = d.age < d.stats.lifetime
		if alive then
			local move = d.velocity * dt
			local result = Workspace:Spherecast(d.position, d.stats.radius, move, d.params)
			if not result then
				d.position += move
			else
				local part = result.Instance
				if liveHitbox(part) then
					EffectsController.impact(result.Position, -d.velocity.Unit, d.color, part)
					alive = false
				elseif combatantOf(part) then
					d.params:AddToFilter(part) -- hats, held guns, bodies: fly through
					d.position += move
				else
					EffectsController.impact(
						result.Position,
						result.Normal,
						d.color,
						part,
						result.Material
					)
					impactSet(d.color).ring:Emit(1)
					d.bounces -= 1
					if d.bounces < 0 then
						alive = false
					else
						local n = result.Normal
						d.velocity = d.velocity - 2 * d.velocity:Dot(n) * n
						d.position = result.Position + n * (d.stats.radius + 0.05)
					end
				end
			end
		end
		if alive then
			local blend = math.max(0, 1 - d.age / DISC_MERGE_TIME)
			d.part.CFrame = discCFrame(d.position + d.offset * blend, d.velocity, d.age * 25)
		else
			endDisc(d)
			table.remove(discs, i)
		end
	end
end

-- Continuous beams (Null) --------------------------------------------------------

type BeamFx = {
	a0: Attachment,
	a1: Attachment,
	beams: { Beam },
	emitters: { ParticleEmitter },
	sound: Sound?,
	target: Vector3, -- where the end is heading (smoothed for other players)
	smooth: boolean,
	follow: Player?, -- other players: the start tracks their world gun's muzzle
	lastSeen: number,
}

local beams: { [any]: BeamFx } = {}
local NULL_WIDTH = 1.3

local function newBeam(color: Color3, soundId: string?, volume: number?, local_: boolean): BeamFx
	local a0 = worldAttachment("BeamStart")
	local a1 = worldAttachment("BeamEnd")
	local list: { Beam } = {}
	local function beam(
		texture: string?,
		c: Color3,
		width: number,
		length: number,
		speed: number
	): Beam
		local b = Instance.new("Beam")
		b.Attachment0 = a0
		b.Attachment1 = a1
		if texture then
			b.Texture = texture
			b.TextureMode = Enum.TextureMode.Static
			b.TextureLength = length
			b.TextureSpeed = speed
		end
		b.Color = ColorSequence.new(c)
		b.LightEmission = if texture then 0.6 else 1
		b.LightInfluence = 0
		b.Brightness = 2
		b.FaceCamera = true
		b.Segments = 10
		b.Width0 = width * 0.2
		b.Width1 = width
		b.Parent = a0
		table.insert(list, b)
		return b
	end
	beam(VFX.BEAM_ENERGY, color, NULL_WIDTH, 3, 4)
	beam(VFX.BEAM_ENERGY, WHITE:Lerp(color, 0.5), 0.8, 5, -2.5)
	beam(nil, WHITE, 0.1, 1, 0)

	-- Muzzle glow.
	local start = emitter(a0, VFX.GLOW, color)
	start.LockedToPart = true
	start.Rate = 30
	start.Lifetime = NumberRange.new(0.08)
	start.Size = NumberSequence.new(if local_ then 0.25 else 0.9)
	start.Color = ColorSequence.new(WHITE:Lerp(color, 0.4), color)
	start.Enabled = true
	-- Where it lands: a flickering flare and sparks.
	local flare = emitter(a1, VFX.IMPACT_FLASH, WHITE:Lerp(color, 0.6))
	flare.LockedToPart = true
	flare.Rate = 25
	flare.Lifetime = NumberRange.new(0.06)
	flare.Size = curve({ 0, 1.6, 1, 0.8 })
	flare.ZOffset = 0.5
	flare.Enabled = true
	local sparks = sparkEmitter(a1, WHITE:Lerp(color, 0.4), 0.3)
	sparks.Rate = 45
	sparks.Speed = NumberRange.new(8, 22)
	sparks.SpreadAngle = Vector2.new(70, 70)
	sparks.Lifetime = NumberRange.new(0.1, 0.25)
	sparks.Acceleration = Vector3.new(0, -40, 0)
	sparks.Drag = 3
	sparks.Enabled = true
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = 1.5
	light.Range = 7
	light.Shadows = false
	light.Parent = a1

	local sound: Sound? = nil
	if soundId then
		local s = AudioController.makeSound(soundId, if local_ then "Gun" else "Enemy")
		if s then
			s.Looped = true
			s.Volume = volume or 0.5
			-- Our own beam plays flat on the camera; others' from their gun.
			local cam = Workspace.CurrentCamera
			s.Parent = if local_ and cam then cam else a0
			s:Play()
			sound = s
		end
	end
	return {
		a0 = a0,
		a1 = a1,
		beams = list,
		emitters = { start, flare, sparks },
		sound = sound,
		target = Vector3.zero,
		smooth = not local_,
		follow = nil,
		lastSeen = os.clock(),
	}
end

-- Shows (or moves) beam `key` from `from` to `to`. Call every frame while it's
-- on; it switches off by itself after BEAM_TIMEOUT without an update.
function EffectsController.setBeam(
	key: any,
	from: Vector3,
	to: Vector3,
	config: WeaponConfig,
	isLocal: boolean?
)
	local b = beams[key]
	if not b then
		b = newBeam(
			config.tracerColor,
			config.sounds.fire,
			config.sounds.fireVolume,
			isLocal == true
		)
		b.a1.WorldPosition = to
		beams[key] = b
	end
	b.a0.WorldPosition = from
	b.target = to
	if not b.smooth then
		b.a1.WorldPosition = to
	end
	b.lastSeen = os.clock()
end

function EffectsController.stopBeam(key: any)
	local b = beams[key]
	if not b then
		return
	end
	beams[key] = nil
	if b.sound then
		b.sound:Destroy()
	end
	for _, beam in b.beams do
		beam:Destroy()
	end
	-- Let the last sparks finish.
	for _, e in b.emitters do
		e.Enabled = false
	end
	local light = b.a1:FindFirstChildOfClass("PointLight")
	if light then
		light:Destroy()
	end
	Debris:AddItem(b.a0, 0.3)
	Debris:AddItem(b.a1, 0.3)
end

-- A named attachment on a character's world weapon (`left`: Dual Boot's left gun).
local function worldPoint(character: Model?, name: string, left: boolean?): Attachment?
	local weapon = character
		and character:FindFirstChild(if left then "WorldWeaponLeft" else "WorldWeapon")
	local point = weapon and weapon:FindFirstChild(name, true)
	if point and point:IsA("Attachment") then
		return point
	end
	return nil
end

local function stepBeams(dt: number, now: number)
	local t = 1 - math.exp(-30 * dt)
	for key, b in beams do
		if now - b.lastSeen > BEAM_TIMEOUT then
			EffectsController.stopBeam(key)
			continue
		end
		if b.follow then
			local muzzle = worldPoint(b.follow.Character, "Muzzle")
			if muzzle then
				b.a0.WorldPosition = muzzle.WorldPosition
			end
		end
		if b.smooth then
			b.a1.WorldPosition = b.a1.WorldPosition:Lerp(b.target, t)
		end
		-- Sparks spray back toward the gun.
		local back = b.a0.WorldPosition - b.a1.WorldPosition
		if back.Magnitude > 0.1 then
			b.a1.WorldCFrame = facing(b.a1.WorldPosition, back)
		end
		-- Crackle: the outer beams wobble and pulse.
		local glow = b.beams[1]
		local w = NULL_WIDTH * (1 + 0.15 * math.sin(now * 45))
		glow.Width0 = w * 0.2
		glow.Width1 = w
		glow.CurveSize0 = (math.random() - 0.5) * 0.5
		glow.CurveSize1 = (math.random() - 0.5) * 0.5
		local inner = b.beams[2]
		inner.CurveSize0 = (math.random() - 0.5) * 0.3
		inner.CurveSize1 = (math.random() - 0.5) * 0.3
	end
end

-- Death and kills -------------------------------------------------------------------

type Dissolve = {
	parts: { BasePart },
	highlight: Highlight,
	age: number,
}

local dissolving: { Dissolve } = {}
local dissolvePart: Part? = nil
local dissolvePixels: ParticleEmitter? = nil

local DISSOLVE_HOT = 0.08 -- white-hot hologram flash
local DISSOLVE_TIME = 0.4 -- flickered out by then

local function dissolveEmitter(): (Part, ParticleEmitter)
	if dissolvePart and dissolvePixels and dissolvePart.Parent then
		return dissolvePart, dissolvePixels
	end
	local p = emitterPart("DissolveFx")
	local e = emitter(p, VFX.PIXEL_2x2, NEON)
	flipbook(e)
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Rotation = NumberRange.new(0)
	e.Speed = NumberRange.new(1, 5)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Lifetime = NumberRange.new(0.5, 1.1)
	e.Drag = 2
	e.Acceleration = Vector3.new(0, 5, 0)
	e.Size = curve({ 0, 0.26, 0.6, 0.2, 1, 0 })
	e.Transparency = curve({ 0, 0, 0.7, 0.1, 1, 1 })
	e.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, WHITE),
		ColorSequenceKeypoint.new(0.15, NEON),
		ColorSequenceKeypoint.new(0.7, NEON),
		ColorSequenceKeypoint.new(1, MAGENTA),
	})
	dissolvePart = p
	dissolvePixels = e
	return p, e
end

-- Enemies flash into a neon hologram, flicker and break into pixels.
function EffectsController.dissolve(model: Model)
	local parts: { BasePart } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 and d.Name ~= "HumanoidRootPart" then
			table.insert(parts, d)
		end
	end
	local highlight = Instance.new("Highlight")
	highlight.Adornee = model
	highlight.FillColor = WHITE
	highlight.OutlineColor = NEON
	highlight.FillTransparency = 0
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = effectsFolder()
	local emitPart, pixels = dissolveEmitter()
	for _, d in parts do
		emitPart.Size = d.Size
		emitPart.CFrame = d.CFrame
		pixels:Emit(math.clamp(math.floor(d.Size.Magnitude * 7), 3, 16))
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		local set = impactSet(NEON)
		set.att.WorldPosition = root.Position
		set.ring:Emit(2)
		set.flash:Emit(1)
	end
	table.insert(dissolving, { parts = parts, highlight = highlight, age = 0 })
end

local function stepDissolves(dt: number)
	for i = #dissolving, 1, -1 do
		local d = dissolving[i]
		d.age += dt
		local done = d.age >= DISSOLVE_TIME
		if d.age < DISSOLVE_HOT then
			d.highlight.FillColor = WHITE:Lerp(NEON, d.age / DISSOLVE_HOT)
		else
			local k = (d.age - DISSOLVE_HOT) / (DISSOLVE_TIME - DISSOLVE_HOT)
			d.highlight.FillColor = NEON
			d.highlight.FillTransparency = 0.2 + k * 0.8
			-- Glitch flicker: visible less and less often.
			local visible = not done and math.random() > k
			for _, part in d.parts do
				part.LocalTransparencyModifier = if visible then 0 else 1
			end
		end
		if done then
			d.highlight:Destroy()
			table.remove(dissolving, i)
		end
	end
end

local killFlash: ImageLabel? = nil

-- A short neon flash round the screen edge when we get a kill (gold: headshot).
function EffectsController.killFlash(headshot: boolean)
	local label = killFlash
	if not label or not label.Parent then
		local gui = Instance.new("ScreenGui")
		gui.Name = "KillFlash"
		gui.IgnoreGuiInset = true
		gui.ResetOnSpawn = false
		gui.DisplayOrder = -1
		gui.Parent = player:WaitForChild("PlayerGui")
		local l = Instance.new("ImageLabel")
		l.BackgroundTransparency = 1
		l.Size = UDim2.fromScale(1, 1)
		l.Image = VFX.VIGNETTE
		l.ImageTransparency = 1
		l.Parent = gui
		killFlash = l
		label = l
	end
	local l = label :: ImageLabel
	l.ImageColor3 = if headshot then GOLD else NEON
	l.ImageTransparency = 0.6
	TweenService:Create(l, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		ImageTransparency = 1,
	}):Play()
end

-- Other players' shots ---------------------------------------------------------

-- Dual Boot: which side each shooter fires next (weak keys, players leave).
local nextLeft: { [Player]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local remoteParams = RaycastParams.new()
remoteParams.FilterType = Enum.RaycastFilterType.Exclude

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
			config.tracerColor,
			result.Instance,
			result.Material,
			if config.pellets > 1 then 0.65 else 1
		)
	end
end

local function onShotFx(shooter: Player, weaponId: string, origin: Vector3, ends: { Vector3 })
	local config = Weapons.get(weaponId)
	if not config or typeof(origin) ~= "Vector3" or typeof(ends) ~= "table" then
		return
	end
	local character = shooter.Character

	-- Null: one continuous beam per shooter, kept alive by the ticks.
	if config.beam then
		local muzzle = worldPoint(character, "Muzzle")
		local e = ends[1]
		if typeof(e) == "Vector3" then
			EffectsController.setBeam(
				shooter,
				if muzzle then muzzle.WorldPosition else origin,
				e,
				config
			)
			local b = beams[shooter]
			if b then
				b.follow = shooter
			end
		end
		return
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
	local muzzle = worldPoint(character, "Muzzle", left) or worldPoint(character, "Muzzle")
	local from = if muzzle then muzzle.WorldPosition else origin
	if config.melee then
		AudioController.play(
			config.sounds.fire,
			{ group = "Enemy", at = from, volume = Audio.ENEMY_SHOT_VOLUME }
		)
		return
	end
	local cam = Workspace.CurrentCamera
	local near = cam ~= nil and (cam.CFrame.Position - from).Magnitude < DETAIL_RANGE
	if muzzle then
		EffectsController.muzzleFlash(muzzle, config, false, near)
	end
	if near then
		local eject = worldPoint(character, "Eject", left)
		if eject then
			updateShellFilter()
			EffectsController.ejectShell(eject, config, 1, rootVelocity(character))
		end
	end
	AudioController.play(config.sounds.fire, {
		group = "Enemy",
		at = from,
		far = true,
		volume = Audio.ENEMY_SHOT_VOLUME * (config.sounds.fireVolume or 1),
		pitch = config.sounds.firePitch,
	})
	if config.projectile then
		local e = ends[1]
		if typeof(e) == "Vector3" then
			EffectsController.disc(character, origin, e - origin, config, from)
		end
		return
	end
	for _, e in ends do
		if typeof(e) ~= "Vector3" then
			continue
		end
		if config.fireMode == "Charge" then
			EffectsController.beam(from, e, config.tracerColor)
		elseif not config.suppressed then
			EffectsController.tracer(from, e, config.tracerColor)
		end
		remoteImpact(character, origin, e, config)
	end
end

local function onKilled(victim: Model?, killer: Player?, _weaponId: string?, headshot: boolean?)
	if victim and victim.Parent then
		EffectsController.dissolve(victim)
	end
	if killer == player and victim ~= player.Character then
		EffectsController.killFlash(headshot == true)
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
		game:GetService("ContentProvider"):PreloadAsync(preload)
		probe:Destroy()
	end)
	Net.unreliable("ShotFx").OnClientEvent:Connect(onShotFx)
	Net.event("Killed").OnClientEvent:Connect(onKilled)
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
		local now = os.clock()
		for _, animator in worldAnimators do
			animator:update(dt)
		end
		stepDiscs(dt)
		stepBeams(dt, now)
		stepRails(dt)
		stepTracers(dt)
		stepShells(dt)
		stepHoles(dt)
		stepLights(fxClock)
		stepDissolves(dt)
	end)
end

return EffectsController
