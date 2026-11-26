--!strict
-- Bullet and knife impacts, split out of Controllers/EffectsController (which
-- forwards impact, slashMark, surfaceOf and knifeContact here and calls step()
-- every frame). Owns the surface table, the shared impact emitters (a flash and
-- sparks, plus dust and chips in sets per surface colour) and the bullet-hole
-- pool, which also holds the knife's gouges.
--
-- Impact emitters are moved to each hit and Emit()ed. Tinted ones (dust,
-- chips) come in sets per surface colour: changing an emitter's Color would
-- recolour its live particles.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Animations = require(ReplicatedStorage.Shared.Config.Animations)
local VFX = require(ReplicatedStorage.Shared.Config.VfxTextures)
local HitFxConfig = require(ReplicatedStorage.Shared.Config.HitFx)
local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)
local SettingsApply = require(ReplicatedStorage.Shared.SettingsApply) -- Optimized VFX

local Kit = require(script.Parent.ShotFxKit)
local AudioController = require(script.Parent.Parent.Controllers.AudioController)

local ImpactFx = {}

local WHITE = Kit.WHITE

local HOLE_POOL = 64
local HOLE_LIFE = 14 -- seconds, the last HOLE_FADE of it fading
local HOLE_FADE = 2
local SCORCH_MIST_LIFE = 1.5
local SCORCH_MIST_EMIT = 0.88
local MAX_DUST_SETS = 16

local emitter = Kit.emitter
local flipbook = Kit.flipbook
local curve = Kit.curve
local facing = Kit.facing

-- Surfaces, by how a bullet strike looks on them.
export type Surface = "Metal" | "Wood" | "Soft" | "Glass" | "Hard"

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

-- Shared emitters -----------------------------------------------------------------

type HitSet = {
	att: Attachment,
	flash: ParticleEmitter,
	sparks: ParticleEmitter,
	metalSparks: ParticleEmitter,
	spectralFlash: ParticleEmitter,
	spectralChips: ParticleEmitter,
}

type DustSet = {
	color: Color3,
	att: Attachment,
	dust: ParticleEmitter,
	chips: ParticleEmitter,
}

local hitSet: HitSet? = nil
local dustSets: { DustSet } = {}

local function getHitSet(): HitSet
	if hitSet then
		return hitSet
	end
	local att = Kit.worldAttachment("ImpactFx")
	-- The strike: a hot core with spark spikes (stylised sheet, colours baked;
	-- 2026-11-10, was a plain soft glow), one random frame, two frames long.
	local flash = emitter(att, VFX.IMPACT_2x2, WHITE)
	Kit.fire(flash)
	flipbook(flash)
	flash.Brightness = 1.6
	flash.Lifetime = NumberRange.new(0.06, 0.085)
	flash.Size = curve({ 0, 0.9, 0.3, 1.6, 1, 1.9 })
	flash.Transparency = curve({ 0, 0, 0.5, 0.2, 1, 1 })
	flash.ZOffset = 0.4
	-- A couple of quick sparks off stone.
	local sparks = Kit.sparkEmitter(att, 0.07)
	sparks.Speed = NumberRange.new(14, 30)
	sparks.SpreadAngle = Vector2.new(50, 50)
	sparks.Lifetime = NumberRange.new(0.05, 0.14)
	sparks.Acceleration = Vector3.new(0, -50, 0)
	sparks.Drag = 4
	-- Off metal: a shower that arcs down.
	local metal = Kit.sparkEmitter(att, 0.09)
	metal.Speed = NumberRange.new(18, 42)
	metal.SpreadAngle = Vector2.new(60, 60)
	metal.Lifetime = NumberRange.new(0.12, 0.35)
	metal.Acceleration = Vector3.new(0, -70, 0)
	metal.Drag = 2.5
	local spectralFlash = emitter(att, VFX.RECON_GLOW, Color3.fromRGB(95, 230, 194))
	Kit.fire(spectralFlash)
	spectralFlash.Name = "ShadowMistImpactFlash"
	spectralFlash.Lifetime = NumberRange.new(0.11, 0.16)
	spectralFlash.Size = curve({ 0, 0.18, 0.38, 0.63, 1, 0.91 })
	spectralFlash.Transparency = curve({ 0, 0.20, 0.42, 0.66, 1, 1 })
	local spectralChips = Kit.sparkEmitter(att, 0.065)
	spectralChips.Name = "ShadowMistImpactChips"
	spectralChips.Texture = VFX.FROST_SHARD
	spectralChips.Color =
		ColorSequence.new(Color3.fromRGB(143, 247, 214), Color3.fromRGB(33, 92, 86))
	spectralChips.Speed = NumberRange.new(4, 8)
	spectralChips.SpreadAngle = Vector2.new(53, 53)
	spectralChips.Lifetime = NumberRange.new(0.14, 0.29)
	spectralChips.Drag = 3
	local set: HitSet = {
		att = att,
		flash = flash,
		sparks = sparks,
		metalSparks = metal,
		spectralFlash = spectralFlash,
		spectralChips = spectralChips,
	}
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
	local att = Kit.worldAttachment("DustFx")
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

-- Bullet holes -------------------------------------------------------------------
-- Pooled parts with a SurfaceGui decal, lit by the scene. The oldest is reused
-- when the pool is full.

type Hole = {
	part: Part,
	image: ImageLabel,
	age: number,
	active: boolean,
	smoke: ParticleEmitter?,
}

local holes: { Hole } = {}
local nextHole = 1
local activeHoles = 0

local function newHole(): Hole
	local p = Kit.fxPart(Vector3.new(0.4, 0.4, 0.02), CFrame.identity, WHITE)
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
local function placeHoleAt(
	position: Vector3,
	normal: Vector3,
	tint: Color3,
	size: number,
	stretch: Vector2?,
	angle: number?,
	exact: boolean?
): Hole
	if #holes < HOLE_POOL then
		table.insert(holes, newHole())
	end
	local h = holes[nextHole] or holes[1]
	nextHole = nextHole % HOLE_POOL + 1
	if not h.active then
		activeHoles += 1
	end
	local s = if exact then size else size * (0.85 + math.random() * 0.3)
	local k = stretch or Vector2.one
	h.part.Size = Vector3.new(s * k.X, s * k.Y, 0.02)
	h.part.CFrame = facing(position + normal * 0.012, normal)
		* CFrame.Angles(0, 0, angle or math.random() * math.pi * 2)
	h.image.ImageColor3 = tint
	h.image.ImageTransparency = 0
	h.age = 0
	h.active = true
	h.part.Name = "BulletHole"
	if h.smoke then
		h.smoke.Enabled = false
		h.smoke:Clear()
	end
	return h
end

local function scorch(
	position: Vector3,
	normal: Vector3,
	size: number,
	stretch: Vector2?,
	angle: number?
)
	local h = placeHoleAt(
		position,
		normal,
		Color3.fromRGB(46, 64, 61),
		size,
		stretch or Vector2.new(1.21, 0.91),
		angle
	)
	h.part.Name = "ShadowMistScorch"
	local smoke = h.smoke
	if not smoke then
		local socket = Instance.new("Attachment")
		socket.Position = Vector3.new(0, 0, -0.045)
		socket.Parent = h.part
		smoke = emitter(socket, VFX.FROST_MIST_2x2, Color3.fromRGB(74, 184, 160))
		smoke.Name = "ShadowMistScorchVapor"
		flipbook(smoke)
		smoke.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
		smoke.LightInfluence = 0.16
		smoke.LightEmission = 0.06
		smoke.EmissionDirection = Enum.NormalId.Front
		smoke.SpreadAngle = Vector2.new(18, 18)
		smoke.Speed = NumberRange.new(0.11, 0.25)
		smoke.Drag = 2.3
		smoke.Acceleration = Vector3.new(0, 1.5, 0)
		smoke.Rate = 9
		smoke.Lifetime = NumberRange.new(0.44, 0.62)
		smoke.Size = curve({ 0, 0.085, 0.44, 0.23, 1, 0.34 })
		smoke.Transparency = curve({ 0, 1, 0.21, 0.43, 0.63, 0.74, 1, 1 })
		h.smoke = smoke
	end
	smoke.Enabled = true
	smoke:Emit(SettingsApply.vfxCount(3))
end

-- Every frame, with `dt` already scaled by the effects time scale: ages and
-- fades the bullet holes and gouges.
function ImpactFx.step(dt: number)
	if activeHoles == 0 then
		return
	end
	for _, h in holes do
		if not h.active then
			continue
		end
		local previous = h.age
		h.age += dt
		local smoke = h.smoke
		if smoke and h.part.Name == "ShadowMistScorch" then
			if previous < SCORCH_MIST_EMIT and h.age >= SCORCH_MIST_EMIT then
				smoke.Enabled = false
			end
			if previous < SCORCH_MIST_LIFE and h.age >= SCORCH_MIST_LIFE then
				smoke:Clear()
			end
		end
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

-- Impacts --------------------------------------------------------------------------

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

-- The range's air targets turn, glide and shatter: a bullet hole (a loose pooled part) would be left hanging in
-- the air where the target was (owner 2026-11-26), so they get the spark and sound only.
local RANGE_TARGET_TAG = "RangeTarget" -- Config/RangeTargets.TAG
local function onRangeTarget(hit: Instance): boolean
	local model = hit:FindFirstAncestorOfClass("Model")
	while model do
		if CollectionService:HasTag(model, RANGE_TARGET_TAG) then
			return true
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return false
end

local function surfaceColor(hit: BasePart, material: Enum.Material): Color3
	if hit:IsA("Terrain") then
		return (hit :: Terrain):GetMaterialColor(material)
	end
	return hit.Color
end

-- A knife strike on the world: a long thin gouge (the bullet-hole decal
-- stretched) centred exactly on `position`, its long side laid along `along`
-- (the blade's path in world space; flattened onto the surface here), a short
-- wide tear for a heavy stab. Pooled with the bullet holes. Numbers:
-- Config/Animations KNIFE_MARK.
function ImpactFx.slashMark(
	position: Vector3,
	normal: Vector3,
	along: Vector3,
	heavy: boolean?,
	spectral: boolean?
)
	if normal.Magnitude < 1e-3 then
		return
	end
	local n = normal.Unit
	-- The decal's frame from facing(): its back (+Z) faces into the surface.
	local frame = facing(position, n)
	local flat = along - n * along:Dot(n)
	local angle = if flat.Magnitude > 1e-3
		then math.atan2(frame.UpVector:Dot(flat), frame.RightVector:Dot(flat))
		else 0
	local mark = Animations.KNIFE_MARK
	local look = if heavy then mark.heavy else mark.light
	if spectral then
		scorch(
			position,
			n,
			look.size,
			if heavy then Vector2.new(3.2, 0.49) else look.stretch,
			angle
		)
		return
	end
	placeHoleAt(position, n, mark.tint, look.size, look.stretch, angle, true)
end

-- Which family of surface a part is (knife wall sounds, impacts).
function ImpactFx.surfaceOf(hit: BasePart, material: Enum.Material?): Surface
	return SURFACES[material or hit.Material] or "Hard"
end

-- The blade landing on a body: a small white flash, one frame after contact
-- (LihFolk lihfolk-vfx: flash ~0.6x, 1-2 frames, ahead of the body).
function ImpactFx.knifeContact(position: Vector3, spectral: boolean?)
	local set = getHitSet()
	set.att.WorldCFrame = CFrame.new(position)
	set.flash:Emit(1)
	set.sparks:Emit(SettingsApply.vfxCount(2))
	if spectral then
		local mist = dustSet(Color3.fromRGB(121, 233, 194))
		mist.att.WorldCFrame = set.att.WorldCFrame
		mist.dust:Emit(SettingsApply.vfxCount(4))
	end
end

local lastImpactSound = -math.huge

-- A shot landing at `position`. `hit` is the part it hit: characters get a
-- small puff (no blood); the world gets an impact for its surface, its sound
-- and a bullet hole. `size` scales the hole (pellets are smaller).
function ImpactFx.impact(
	position: Vector3,
	normal: Vector3,
	hit: Instance?,
	material: Enum.Material?,
	size: number?,
	noHole: boolean?, -- the knife: its own gouge (slashMark), not a bullet hole
	spectral: boolean?,
	ownStrike: boolean? -- a skin draws its own strike (Tempest-Strike: water + static): no orange flash or sparks
)
	local function placeHole(at: Vector3, n: Vector3, color: Color3, holeSize: number)
		if not noHole then
			placeHoleAt(at, n, color, holeSize)
		end
	end
	if normal.Magnitude < 1e-3 then
		normal = Vector3.yAxis
	end
	normal = normal.Unit
	local cf = facing(position + normal * 0.05, normal)
	if not hit or not hit:IsA("BasePart") then
		return
	end
	if not noHole and onRangeTarget(hit) then
		noHole = true
	end
	if combatantOf(hit) then
		local color = if spectral
			then Color3.fromRGB(74, 184, 160)
			else hit.Color:Lerp(Color3.fromHex("8A8A8A"), 0.5)
		local puff = dustSet(color)
		puff.att.WorldCFrame = cf
		puff.dust:Emit(SettingsApply.vfxCount(if spectral then 4 else 1))
		return
	end
	local mat = material or hit.Material
	local kind: Surface = SURFACES[mat] or "Hard"
	-- The surface's bullet-impact sound (audio lane: Config/Sounds IMPACTS),
	-- throttled so a shotgun's pellets don't stack. Not for the knife (its
	-- own wall sounds) and not on bodies (hit sounds handle those, above).
	local sound = HitFxConfig.IMPACT_SOUND
	local now = os.clock()
	if not noHole and now - lastImpactSound >= sound.minGap then
		lastImpactSound = now
		AudioController.play(Sounds.IMPACTS[kind], {
			group = "Enemy",
			at = position,
			range = sound.range,
			volume = sound.volume,
		})
	end
	if
		spectral
		and not noHole
		and math.abs(normal.Y) < 0.74
		and kind ~= "Glass"
		and kind ~= "Soft"
	then
		local set = getHitSet()
		set.att.WorldCFrame = cf
		set.spectralFlash:Emit(1)
		set.spectralChips:Emit(SettingsApply.vfxCount(4))
		scorch(position, normal, 0.45 * (size or 1))
		return
	end
	local color = surfaceColor(hit, mat)
	local set = getHitSet()
	set.att.WorldCFrame = cf
	local dust = dustSet(color)
	dust.att.WorldCFrame = cf
	local holeSize = 0.36 * (size or 1)
	local hot = not ownStrike
	if kind == "Metal" then
		if hot then
			set.flash:Emit(1)
			set.metalSparks:Emit(SettingsApply.vfxCount(math.random(6, 10)))
		end
		dust.dust:Emit(SettingsApply.vfxCount(1))
		placeHole(position, normal, Color3.fromHex("8E9399"), holeSize * 0.8)
	elseif kind == "Wood" then
		dust.dust:Emit(SettingsApply.vfxCount(1))
		dust.chips:Emit(SettingsApply.vfxCount(math.random(4, 6))) -- splinters
		placeHole(position, normal, Color3.fromHex("6E5A44"), holeSize)
	elseif kind == "Soft" then
		dust.dust:Emit(SettingsApply.vfxCount(3))
		dust.chips:Emit(SettingsApply.vfxCount(math.random(2, 4))) -- clods
	elseif kind == "Glass" then
		if hot then
			set.flash:Emit(1)
		end
		dust.chips:Emit(SettingsApply.vfxCount(math.random(4, 7)))
		placeHole(position, normal, Color3.fromHex("C8CDD2"), holeSize * 0.9)
	else
		if hot then
			set.flash:Emit(1)
			set.sparks:Emit(SettingsApply.vfxCount(math.random(1, 3)))
		end
		dust.dust:Emit(SettingsApply.vfxCount(2))
		dust.chips:Emit(SettingsApply.vfxCount(math.random(3, 5)))
		placeHole(position, normal, WHITE, holeSize)
	end
end

return ImpactFx
