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

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Animations = require(ReplicatedStorage.Shared.Config.Animations)
local VFX = require(ReplicatedStorage.Shared.Config.VfxTextures)

local Kit = require(script.Parent.ShotFxKit)

local ImpactFx = {}

local WHITE = Kit.WHITE
local FIRE = Kit.FIRE

local HOLE_POOL = 64
local HOLE_LIFE = 14 -- seconds, the last HOLE_FADE of it fading
local HOLE_FADE = 2
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
	local flash = emitter(att, VFX.GLOW, FIRE)
	Kit.fire(flash)
	flash.Lifetime = NumberRange.new(0.05)
	flash.Size = curve({ 0, 0.7, 1, 0.3 })
	flash.Transparency = curve({ 0, 0.15, 1, 1 })
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
)
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
function ImpactFx.slashMark(position: Vector3, normal: Vector3, along: Vector3, heavy: boolean?)
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
	placeHoleAt(position, n, mark.tint, look.size, look.stretch, angle, true)
end

-- Which family of surface a part is (knife wall sounds, impacts).
function ImpactFx.surfaceOf(hit: BasePart, material: Enum.Material?): Surface
	return SURFACES[material or hit.Material] or "Hard"
end

-- The blade landing on a body: a small white flash, one frame after contact
-- (LihFolk lihfolk-vfx: flash ~0.6x, 1-2 frames, ahead of the body).
function ImpactFx.knifeContact(position: Vector3)
	local set = getHitSet()
	set.att.WorldCFrame = CFrame.new(position)
	set.flash:Emit(1)
	set.sparks:Emit(2)
end

-- A shot landing at `position`. `hit` is the part it hit: characters get a
-- small puff (no blood); the world gets an impact for its surface and a
-- bullet hole. `size` scales the hole (pellets are smaller).
function ImpactFx.impact(
	position: Vector3,
	normal: Vector3,
	hit: Instance?,
	material: Enum.Material?,
	size: number?,
	noHole: boolean? -- the knife: its own gouge (slashMark), not a bullet hole
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

return ImpactFx
