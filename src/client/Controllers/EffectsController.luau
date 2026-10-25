--!strict
-- Shot feedback in the Style B neon look (Gunplay.md §5): muzzle flash,
-- tracers, impact sparks, the Ray Trace beam, Loopback discs, the Null beam,
-- gun sounds, other players' shots, and the pixel-dissolve on death (no blood).

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Combat = require(ReplicatedStorage.Shared.Config.Combat)
local Net = require(ReplicatedStorage.Shared.Net)
local SoundAtlas = require(ReplicatedStorage.Shared.Config.SoundAtlas)
local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)
local Types = require(ReplicatedStorage.Shared.Types)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

local GunAnimator = require(script.Parent.Parent.Util.GunAnimator)

type WeaponConfig = Types.WeaponConfig

local EffectsController = {}

local SPARK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local PIXEL_TEXTURE = "rbxasset://textures/particles/SquareParticle.png"
local NEON = Color3.fromHex("00E5FF")
local WHITE = Color3.new(1, 1, 1)

-- Loopback discs start at the muzzle and blend onto the simulated path
-- (which starts at the camera, like the server's) over this many seconds.
local DISC_MERGE_TIME = 0.12
-- A beam with no update for this long switches off (other players' beams
-- arrive as ~10 Hz unreliable ticks).
local BEAM_TIMEOUT = 0.25

local folder: Folder? = nil

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

-- Sounds ---------------------------------------------------------------------

-- Makes a Sound for a Config/Sounds entry: a plain asset id, or "atlas:<Name>"
-- for a slice of the sound atlas (played with PlaybackRegion).
function EffectsController.makeSound(id: string): (Sound?, number)
	if id == "" then
		return nil, 0
	end
	local s = Instance.new("Sound")
	local length = 6
	if string.sub(id, 1, 6) == "atlas:" then
		local region = SoundAtlas[string.sub(id, 7)]
		if not region then
			s:Destroy()
			return nil, 0
		end
		s.SoundId = Sounds.ATLAS
		s.PlaybackRegionsEnabled = true
		s.PlaybackRegion = NumberRange.new(region.start, region.start + region.length)
		s.LoopRegion = s.PlaybackRegion
		length = region.length
	else
		s.SoundId = id
	end
	s.RollOffMaxDistance = 300
	s.RollOffMinDistance = 12
	return s, length
end

function EffectsController.playSound(id: string, parent: Instance?, volume: number?, pitch: number?)
	local s, length = EffectsController.makeSound(id)
	if not s then
		return
	end
	s.Volume = volume or 0.6
	s.PlaybackSpeed = pitch or 1
	s.Parent = parent or effectsFolder()
	s:Play()
	Debris:AddItem(s, length / (pitch or 1) + 0.5)
end

-- Plays a sound at a world position (for other players' shots and impacts).
function EffectsController.playSoundAt(
	id: string,
	position: Vector3,
	volume: number?,
	pitch: number?
)
	local holder = Instance.new("Attachment")
	holder.WorldPosition = position
	holder.Parent = Workspace.Terrain
	EffectsController.playSound(id, holder, volume, pitch)
	Debris:AddItem(holder, 6)
end

-- Visuals --------------------------------------------------------------------

function EffectsController.muzzleFlash(cf: CFrame, color: Color3, scale: number?)
	local s = scale or 1
	local flash = fxPart(Vector3.new(0.35, 0.35, 0.6) * s, cf * CFrame.new(0, 0, -0.25 * s), color)
	flash.Shape = Enum.PartType.Ball
	flash.Transparency = 0.15
	local core = fxPart(
		Vector3.new(0.12, 0.12, 0.9) * s,
		cf * CFrame.new(0, 0, -0.4 * s),
		Color3.new(1, 1, 1)
	)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = 4
	light.Range = 8
	light.Parent = flash
	Debris:AddItem(flash, 0.05)
	Debris:AddItem(core, 0.035)
end

function EffectsController.tracer(
	from: Vector3,
	to: Vector3,
	color: Color3,
	width: number?,
	life: number?
)
	local dist = (to - from).Magnitude
	if dist < 1 then
		return
	end
	local w = width or 0.07
	local t = life or 0.07
	local p = fxPart(Vector3.new(w, w, dist), CFrame.lookAt((from + to) / 2, to), color)
	p.Transparency = 0.1
	TweenService
		:Create(
			p,
			TweenInfo.new(t),
			{ Transparency = 1, Size = Vector3.new(w * 0.3, w * 0.3, dist) }
		)
		:Play()
	Debris:AddItem(p, t + 0.05)
end

-- Thick lingering beam (Ray Trace).
function EffectsController.beam(from: Vector3, to: Vector3, color: Color3)
	EffectsController.tracer(from, to, color, 0.35, 0.45)
	EffectsController.tracer(from, to, Color3.new(1, 1, 1), 0.1, 0.2)
end

function EffectsController.impact(position: Vector3, normal: Vector3, color: Color3?)
	local c = color or NEON
	local att = Instance.new("Attachment")
	att.WorldCFrame = CFrame.lookAt(position, position + normal)
	att.Parent = Workspace.Terrain
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = SPARK_TEXTURE
	sparks.Color = ColorSequence.new(c)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparks.Lifetime = NumberRange.new(0.12, 0.25)
	sparks.Speed = NumberRange.new(8, 16)
	sparks.SpreadAngle = Vector2.new(40, 40)
	sparks.EmissionDirection = Enum.NormalId.Front
	sparks.Drag = 6
	sparks.Enabled = false
	sparks.Parent = att
	sparks:Emit(8)
	-- A small glowing square where the shot landed.
	local mark = fxPart(
		Vector3.new(0.18, 0.18, 0.02),
		CFrame.lookAt(position + normal * 0.02, position + normal * 2),
		c
	)
	TweenService:Create(mark, TweenInfo.new(0.6), { Transparency = 1 }):Play()
	Debris:AddItem(mark, 0.65)
	Debris:AddItem(att, 0.5)
end

-- Enemies dissolve into neon pixels instead of ragdolling.
function EffectsController.dissolve(model: Model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			local att = Instance.new("Attachment")
			att.WorldPosition = d.Position
			att.Parent = Workspace.Terrain
			local pixels = Instance.new("ParticleEmitter")
			pixels.Texture = PIXEL_TEXTURE
			pixels.Color = ColorSequence.new(NEON, Color3.fromHex("56607C"))
			pixels.LightEmission = 0.8
			pixels.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.18),
				NumberSequenceKeypoint.new(1, 0.05),
			})
			pixels.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(1, 1),
			})
			pixels.Lifetime = NumberRange.new(0.5, 0.9)
			pixels.Speed = NumberRange.new(2, 6)
			pixels.SpreadAngle = Vector2.new(180, 180)
			pixels.Acceleration = Vector3.new(0, 6, 0)
			pixels.Enabled = false
			pixels.Parent = att
			pixels:Emit(math.clamp(math.floor(d.Size.Magnitude * 6), 4, 18))
			Debris:AddItem(att, 1.2)
			d.LocalTransparencyModifier = 1
		end
	end
end

-- Loopback discs ---------------------------------------------------------------
-- The server flies the real disc and applies its damage; this is a client copy
-- that follows the same path (same start, Spherecast, bounces and lifetime).

type Disc = {
	part: BasePart,
	core: BasePart,
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

-- Disc orientation: flat like a frisbee (cylinder axis up), facing its flight.
local function discCFrame(position: Vector3, velocity: Vector3): CFrame
	local look = if velocity.Magnitude > 1e-3 then velocity.Unit else Vector3.zAxis
	local up = if math.abs(look.Y) > 0.99 then Vector3.zAxis else Vector3.yAxis
	return CFrame.lookAt(position, position + look, up) * CFrame.Angles(0, 0, math.pi / 2)
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
	local cf = discCFrame(visualFrom or start, dir)
	local part = fxPart(Vector3.new(0.12, r * 2, r * 2), cf, config.tracerColor)
	part.Shape = Enum.PartType.Cylinder
	part.Transparency = 0.15
	local core = fxPart(Vector3.new(0.16, r * 1.1, r * 1.1), cf, WHITE)
	core.Shape = Enum.PartType.Cylinder
	local light = Instance.new("PointLight")
	light.Color = config.tracerColor
	light.Brightness = 3
	light.Range = 10
	light.Parent = part
	-- Flat ribbon trail from the disc's two sides.
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, r * 0.7, 0)
	a0.Parent = part
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -r * 0.7, 0)
	a1.Parent = part
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(config.tracerColor)
	trail.LightEmission = 1
	trail.LightInfluence = 0
	trail.Lifetime = 0.18
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0.2),
	})
	trail.Parent = part

	table.insert(discs, {
		part = part,
		core = core,
		position = start,
		velocity = dir * stats.speed,
		offset = if visualFrom then visualFrom - start else Vector3.zero,
		age = 0,
		bounces = stats.bounces,
		stats = stats,
		params = params,
		color = config.tracerColor,
	})
end

local function endDisc(d: Disc)
	-- Hide the disc but let its trail fade out.
	d.part.Transparency = 1
	local light = d.part:FindFirstChildOfClass("PointLight")
	if light then
		light:Destroy()
	end
	d.core:Destroy()
	Debris:AddItem(d.part, 0.25)
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
					EffectsController.impact(result.Position, -d.velocity.Unit, d.color)
					alive = false
				elseif combatantOf(part) then
					d.params:AddToFilter(part) -- hats, held guns, bodies: fly through
					d.position += move
				else
					EffectsController.impact(result.Position, result.Normal, d.color)
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
			local cf = discCFrame(d.position + d.offset * blend, d.velocity)
			d.part.CFrame = cf
			d.core.CFrame = cf
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
	glow: Beam,
	core: Beam,
	sparks: ParticleEmitter,
	sound: Sound?,
	target: Vector3, -- where the end is heading (smoothed for other players)
	smooth: boolean,
	follow: Player?, -- other players: the start tracks their world gun's muzzle
	lastSeen: number,
}

local beams: { [any]: BeamFx } = {}

local function newBeam(color: Color3, soundId: string?, volume: number?, local_: boolean): BeamFx
	local a0 = Instance.new("Attachment")
	a0.Name = "BeamStart"
	a0.Parent = Workspace.Terrain
	local a1 = Instance.new("Attachment")
	a1.Name = "BeamEnd"
	a1.Parent = Workspace.Terrain
	local function beam(c: Color3, width: number, transparency: number): Beam
		local b = Instance.new("Beam")
		b.Attachment0 = a0
		b.Attachment1 = a1
		b.Color = ColorSequence.new(c)
		b.LightEmission = 1
		b.LightInfluence = 0
		b.FaceCamera = true
		b.Segments = 1
		b.Width0 = width
		b.Width1 = width
		b.Transparency = NumberSequence.new(transparency)
		b.Parent = a0
		return b
	end
	local glow = beam(color, 0.32, 0.25)
	local core = beam(WHITE, 0.08, 0)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = 3
	light.Range = 9
	light.Parent = a1
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = SPARK_TEXTURE
	sparks.Color = ColorSequence.new(color)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparks.Lifetime = NumberRange.new(0.1, 0.2)
	sparks.Speed = NumberRange.new(6, 12)
	sparks.SpreadAngle = Vector2.new(70, 70)
	sparks.Rate = 45
	sparks.Drag = 6
	sparks.Parent = a1
	local sound: Sound? = nil
	if soundId then
		local s = EffectsController.makeSound(soundId)
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
		glow = glow,
		core = core,
		sparks = sparks,
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
	b.a0:Destroy()
	-- Let the last sparks finish.
	b.sparks.Enabled = false
	local light = b.a1:FindFirstChildOfClass("PointLight")
	if light then
		light:Destroy()
	end
	Debris:AddItem(b.a1, 0.3)
end

-- Muzzle attachment of a character's world weapon (`left`: Dual Boot's left gun).
local function worldMuzzle(character: Model?, left: boolean?): Attachment?
	local weapon = character
		and character:FindFirstChild(if left then "WorldWeaponLeft" else "WorldWeapon")
	local muzzle = weapon and weapon:FindFirstChild("Muzzle", true)
	if muzzle and muzzle:IsA("Attachment") then
		return muzzle
	end
	return nil
end

local function stepBeams(dt: number)
	local now = os.clock()
	local t = 1 - math.exp(-30 * dt)
	for key, b in beams do
		if now - b.lastSeen > BEAM_TIMEOUT then
			EffectsController.stopBeam(key)
			continue
		end
		if b.follow then
			local muzzle = worldMuzzle(b.follow.Character)
			if muzzle then
				b.a0.WorldPosition = muzzle.WorldPosition
			end
		end
		if b.smooth then
			b.a1.WorldPosition = b.a1.WorldPosition:Lerp(b.target, t)
		end
		-- A little shimmer on the outer glow.
		local w = 0.3 + 0.05 * math.sin(now * 45)
		b.glow.Width0 = w * 0.7
		b.glow.Width1 = w
	end
end

-- Other players' shots ---------------------------------------------------------

-- Dual Boot: which side each shooter fires next (weak keys, players leave).
local nextLeft: { [Player]: boolean } = setmetatable({}, { __mode = "k" }) :: any

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

local function onShotFx(shooter: Player, weaponId: string, origin: Vector3, ends: { Vector3 })
	local config = Weapons.get(weaponId)
	if not config or typeof(origin) ~= "Vector3" or typeof(ends) ~= "table" then
		return
	end
	local character = shooter.Character

	-- Null: one continuous beam per shooter, kept alive by the ticks.
	if config.beam then
		local muzzle = worldMuzzle(character)
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
	local muzzle = worldMuzzle(character, left) or worldMuzzle(character)
	local from = if muzzle then muzzle.WorldPosition else origin
	if config.melee then
		EffectsController.playSoundAt(config.sounds.fire, from, 0.6)
		return
	end
	if muzzle then
		EffectsController.muzzleFlash(muzzle.WorldCFrame, config.tracerColor, 0.8)
	end
	EffectsController.playSoundAt(config.sounds.fire, from, (config.sounds.fireVolume or 0.7) * 0.9)
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
	end
end

local function onKilled(victim: Model?)
	if victim and victim.Parent then
		EffectsController.dissolve(victim)
	end
end

function EffectsController.start()
	effectsFolder()
	-- Load the atlas up front so the first shot isn't silent.
	task.spawn(function()
		local probe = Instance.new("Sound")
		probe.SoundId = Sounds.ATLAS
		game:GetService("ContentProvider"):PreloadAsync({ probe })
		probe:Destroy()
	end)
	Net.unreliable("ShotFx").OnClientEvent:Connect(onShotFx)
	Net.event("Killed").OnClientEvent:Connect(onKilled)
	RunService.RenderStepped:Connect(function(dt)
		for _, animator in worldAnimators do
			animator:update(dt)
		end
		stepDiscs(dt)
		stepBeams(dt)
	end)
end

return EffectsController
