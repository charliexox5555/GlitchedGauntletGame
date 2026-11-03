--!strict
-- The Molly's fire for everyone (vault/01 Design/Abilities/Molly.md → Look):
-- the burst (a canister pop and a whoomp of flame out to the radius), the
-- steady patch, the end (flames die down and sizzle out over ~0.5 s; the
-- scorch fades a few seconds later), and the small flames on whoever is
-- burning (the server's BurningUntil attribute). Fire is fire-coloured for
-- everyone: it's the same danger to both teams.
--
-- The stylized patch (Util/FireKit, the Blender FireVFX meshes; Brimstone's /
-- Phoenix's incendiary): a glowing disc on the floor, a bright ring on the
-- edge (the safe line), two rings of flame tongues standing on the edge
-- (orange outside, yellow inside, turning opposite ways and flickering), and
-- flame tongues dancing over the patch, turned to face you, flickering,
-- leaning and swapping shapes. The burst: the rings shoot up tall and small
-- and spread out to the radius as they settle, ember shards fly out. The
-- end: everything sinks into the floor. A few embers, a flickering warm
-- light and the scorch mark stay as they were; no smoke.
--
-- Until the hub has installed ReplicatedStorage.Abilities.FireVFX the patch
-- keeps the old particle look: low flames across it, a brighter burning
-- edge, a little smoke, embers (textures Config/VfxTextures MOLLY_*, rendered
-- in Blender by tools/vfx/make_molly_vfx.py). Fire rigs are pooled; burning
-- flames are one emitter per character, made on first burn.
--
-- Any size (Molly.md → Upgrades): the flames' density, the embers, the
-- whoomp, the light and the pitch of the burst and the loop follow `radius`
-- (Bigger Fire's 12 / 14 studs read bigger and deeper, Fork Fire's 5-stud
-- fires smaller and higher), the time follows `duration`.
--
-- Glitch fire (Fork Fire, `glitch`): the same fire, corrupted. Its flames
-- keep flipping between fire and hot magenta (COLORS.glitch), magenta crackle
-- arcs and embers, neon "dead pixels" and screen-tear slivers blinking in
-- and out over the patch, a light that jumps between levels instead of
-- flickering smoothly, a pitched-up loop with stuttering digital crackles,
-- and it dissolves into magenta static when it goes out. The mesh flames
-- move at a choppy frame rate (GLITCH_FPS) and now and then a ring of them
-- skips sideways.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.Mods)
local ModSounds = require(ReplicatedStorage.Shared.Config.ModSounds)
local VFX = require(ReplicatedStorage.Shared.Config.VfxTextures)

local FireKit = require(script.Parent.FireKit)
local ModAudio = require(script.Parent.ModAudio)
local ModVfx = require(script.Parent.ModVfx)

local MollyFx = {}

local S = ModSounds.Molly
local player = Players.LocalPlayer

local FLAME_POINTS = 26 -- flame emitters spread over the patch
local EDGE_POINTS = 28 -- around the rim
local SMOKE_POINTS = 5
local FADE_TIME = 0.5 -- flames die down over this at the end
local SCORCH_LINGER = 3 -- seconds the scorch stays after the fire
local LIGHT_COLOR = Color3.fromRGB(255, 150, 70)
local FIRE_TINT = Color3.fromRGB(255, 255, 255) -- the flame textures carry their own colour
local BASE_RADIUS = 9 -- L1's patch: the rates below are tuned for it
local EMBER_COLOR = ColorSequence.new(Color3.fromRGB(255, 214, 120), Color3.fromRGB(200, 50, 20))
local SMOKE_COLOR = ColorSequence.new(Color3.fromHex("3A3A3C"))

-- Glitch fire.
local GLITCH = Config.COLORS.glitch
local GLITCH_VIOLET = Color3.fromRGB(120, 50, 255)
-- The flame sheet is orange: a pink-violet tint turns it hot pink.
local GLITCH_FLAME = ColorSequence.new(Color3.fromRGB(255, 120, 255), Color3.fromRGB(200, 90, 255))
local GLITCH_EMBER = ColorSequence.new(Color3.fromRGB(255, 200, 245), GLITCH)
local GLITCH_SMOKE = ColorSequence.new(Color3.fromRGB(60, 28, 64))
local GLITCH_SCORCH = Color3.fromRGB(255, 160, 235)
local PIXEL_COLORS = { GLITCH, GLITCH, Color3.new(1, 1, 1), GLITCH_VIOLET, LIGHT_COLOR }
local FLIP_GAP = 0.09 -- seconds between colour flips of the flames
local FLIP_SHARE = 0.35 -- share of the flames flipped each time
local LIGHT_STEP = 0.07 -- the light holds each level at least this long
local CRACKLE_MIN, CRACKLE_MAX = 0.35, 0.9 -- seconds between crackles
local CRACKLE_PITCHES = { 1, 1.5, 2 } -- stepped, so it sounds digital

-- The mesh fire (FireKit). Sizes are for L1's 9-stud patch and follow the
-- radius gently (a 5-stud Fork Fire still reads, a 14-stud one isn't a forest).
local MESH_FLAMES_PER_STUD = 0.9 -- flame tongues over the patch per stud of radius
local MESH_FLAMES_MIN, MESH_FLAMES_MAX = 4, 13
local FLAME_LOW, FLAME_HIGH = 1.7, 2.5 -- their heights (studs) at L1's radius
local FLAME_WIDTH = 2.0 -- tongue width scale (the variants are ~0.45 wide)
local CROWN_HEIGHT = 2.6 -- the rim flames at L1's radius
local CROWN_SPIN_A, CROWN_SPIN_B = 0.5, -0.7 -- radians/s: outer and inner ring
local POOL_ALPHA = 0.15
local BURST_TIME = 0.3 -- the whoomp: the rings spread out to the radius
local BURST_TALL = 1.6 -- they start this much taller
local MESH_EMBER_RATE = 5 -- embers are an accent only
local SPARKS = 6 -- ember shards flying out of the burst
local SPARK_LIFE = 0.5
local SPARK_SIZE = 0.4
local ANIM_GAP = 1 / 30 -- the flames move at most this often
local ANIM_RANGE = 220 -- fires farther than this from the camera hold still
local GLITCH_FPS = 12 -- glitch fire's flames move at this choppy rate
local SKIP_CHANCE = 0.06 -- per glitch frame: a ring of flames skips sideways
local GLITCH_PINK = Color3.fromRGB(255, 170, 240)
local GLITCH_POOL = Color3.fromRGB(150, 24, 130)

local rng = Random.new()

type MeshFire = {
	pool: BasePart,
	ring: BasePart,
	crownA: BasePart,
	crownB: BasePart,
	flames: { FireKit.Flame },
	spots: { Vector3 }, -- each flame's offset at full spread
	heights: { number },
	seed: number,
	sizeK: number, -- flame size for this radius / L1's
	skipA: Vector3, -- glitch: a ring drawn off-centre for a frame
	skipB: Vector3,
}

-- An ember shard flying out of a burst.
type Spark = { part: BasePart, from: Vector3, vel: Vector3, born: number }

type Rig = {
	part: Part,
	particles: boolean, -- built with the particle flames (no FireKit)
	flames: { ParticleEmitter },
	edge: { ParticleEmitter },
	smoke: { ParticleEmitter },
	embers: ParticleEmitter,
	burst: ParticleEmitter,
	arcs: ParticleEmitter, -- glitch fire only
	light: PointLight,
	attachments: { Attachment },
}

-- A blinking neon block over a glitch fire (a dead pixel, or a wide sliver:
-- a screen tear).
type Pixel = { part: Part, shown: boolean, untilT: number }

type Fire = {
	rig: Rig,
	at: Vector3,
	radius: number,
	startAt: number, -- os.clock()
	endAt: number,
	hum: ModAudio.Hum?,
	sizzled: boolean,
	scorch: any,
	area: number, -- the patch's area / L1's (flame and ember rates)
	rim: number, -- its rim / L1's (edge and smoke rates)
	glitch: boolean,
	pixels: { Pixel },
	nextFlip: number,
	nextLight: number,
	lightLevel: number,
	nextCrackle: number,
	mesh: MeshFire?,
	nextGlitchFrame: number,
}

local fires: { Fire } = {}
local sparks: { Spark } = {}
local lastAnim = 0
local freeRigs: { Rig } = {}
local freePixels: { Part } = {}
local folder: Folder? = nil

local function curve(points: { number }): NumberSequence
	local keys = {}
	for i = 1, #points, 2 do
		table.insert(keys, NumberSequenceKeypoint.new(points[i], points[i + 1]))
	end
	return NumberSequence.new(keys)
end

local function fxFolder(): Folder
	local f = folder
	if f and f.Parent then
		return f
	end
	local made = Instance.new("Folder")
	made.Name = "MollyFx"
	made.Parent = Workspace
	folder = made
	table.clear(freeRigs)
	table.clear(freePixels)
	return made
end

local function emitter(parent: Instance, texture: string): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = texture
	e.Rate = 0
	e.Enabled = true
	e.LightInfluence = 0
	e.LockedToPart = false
	e.Color = ColorSequence.new(FIRE_TINT)
	e.Parent = parent
	return e
end

-- A low flame: the looping 16-frame sheet, each particle starting on its
-- own frame. The sprite's base is its bottom edge, so emitters sit about half
-- a flame's height above the floor (see layout).
local function flameEmitter(parent: Instance, tall: number): ParticleEmitter
	local e = emitter(parent, VFX.MOLLY_FLAME_4x4)
	e.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
	e.FlipbookMode = Enum.ParticleFlipbookMode.Loop
	e.FlipbookFramerate = NumberRange.new(20, 24)
	e.FlipbookStartRandom = true
	e.Lifetime = NumberRange.new(0.6, 0.9)
	e.Speed = NumberRange.new(0.2, 0.6)
	e.EmissionDirection = Enum.NormalId.Top
	e.SpreadAngle = Vector2.new(6, 6)
	e.Size = curve({ 0, 0.8 * tall, 0.3, 1.4 * tall, 1, 1.2 * tall })
	e.Transparency = curve({ 0, 0.7, 0.15, 0.1, 0.75, 0.3, 1, 1 })
	e.LightEmission = 0.6
	e.Brightness = 1.3
	e.Orientation = Enum.ParticleOrientation.FacingCamera
	e.Rotation = NumberRange.new(-6, 6)
	return e
end

local FLAME_TALL = 1.6 -- patch flames (studs, roughly knee-high at their peak)
local EDGE_TALL = 2 -- the burning edge: a little taller so the line reads
-- Emitters sit this share of a flame's size up: the sprite's base is its
-- bottom edge, and at its biggest (1.4x) half of it would sink into the floor.
local FLOOR_LIFT = 0.72

-- `particles`: with the particle flames, edge and smoke (the look without
-- FireKit); a mesh fire's rig only has the embers, burst, arcs and light.
local function build(particles: boolean): Rig
	local part = Instance.new("Part")
	part.Name = "MollyFire"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(1, 0.2, 1)
	part.CFrame = CFrame.new(0, -10000, 0)
	part.Parent = fxFolder()

	local attachments: { Attachment } = {}
	local function attach(): Attachment
		local a = Instance.new("Attachment")
		a.Parent = part
		table.insert(attachments, a)
		return a
	end
	local flames, edge, smoke = {}, {}, {}
	for _ = 1, if particles then FLAME_POINTS else 0 do
		table.insert(flames, flameEmitter(attach(), FLAME_TALL))
	end
	for _ = 1, if particles then EDGE_POINTS else 0 do
		table.insert(edge, flameEmitter(attach(), EDGE_TALL))
	end
	for _ = 1, if particles then SMOKE_POINTS else 0 do
		local e = emitter(attach(), VFX.MOLLY_SMOKE_2x2)
		e.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
		e.FlipbookMode = Enum.ParticleFlipbookMode.OneShot -- billows, then thins
		e.Color = SMOKE_COLOR
		e.Lifetime = NumberRange.new(1.8, 2.6)
		e.Speed = NumberRange.new(2, 3.5)
		e.Acceleration = Vector3.new(0, 1.2, 0)
		e.Drag = 0.6
		e.EmissionDirection = Enum.NormalId.Top
		e.SpreadAngle = Vector2.new(20, 20)
		e.Size = curve({ 0, 1.6, 1, 4.5 })
		e.Transparency = curve({ 0, 1, 0.2, 0.72, 1, 1 })
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-20, 20)
		e.LightInfluence = 0.6
		table.insert(smoke, e)
	end
	local center = attach()
	-- On the part itself: its size (the patch) sets the emitter's shape.
	local embers = emitter(part, VFX.MOLLY_EMBER)
	embers.Shape = Enum.ParticleEmitterShape.Cylinder
	embers.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	embers.Lifetime = NumberRange.new(1, 1.8)
	embers.Speed = NumberRange.new(3, 6)
	embers.Acceleration = Vector3.new(0, 1.5, 0)
	embers.EmissionDirection = Enum.NormalId.Top
	embers.SpreadAngle = Vector2.new(25, 25)
	embers.Size = curve({ 0, 0.14, 1, 0.05 })
	embers.Color = EMBER_COLOR
	embers.Transparency = curve({ 0, 0, 0.8, 0.3, 1, 1 })
	embers.LightEmission = 1
	embers.Brightness = 2
	-- The whoomp: a side-view sheet (base at the bottom) as wide as the patch,
	-- played once; a second, smaller one a beat later (ignite).
	local burst = emitter(center, VFX.MOLLY_BURST_2x2)
	burst.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
	burst.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	burst.Lifetime = NumberRange.new(0.4)
	burst.Speed = NumberRange.new(0)
	burst.Size = NumberSequence.new(18)
	burst.Transparency = curve({ 0, 0, 0.8, 0.2, 1, 1 })
	burst.LightEmission = 0.6
	burst.Brightness = 1.4
	burst.Orientation = Enum.ParticleOrientation.FacingCamera
	-- Glitch fire's crackle arcs: blink-short magenta sparks over the patch.
	local arcs = emitter(part, VFX.STIM_ARC_2x2)
	arcs.Shape = Enum.ParticleEmitterShape.Cylinder
	arcs.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	arcs.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
	arcs.FlipbookMode = Enum.ParticleFlipbookMode.Random
	arcs.Lifetime = NumberRange.new(0.06, 0.14)
	arcs.Speed = NumberRange.new(0)
	arcs.Size = NumberSequence.new(1.6)
	arcs.Rotation = NumberRange.new(0, 360)
	arcs.Color = ColorSequence.new(GLITCH)
	arcs.LightEmission = 1
	arcs.Brightness = 2
	local light = Instance.new("PointLight")
	light.Color = LIGHT_COLOR
	light.Shadows = false
	light.Brightness = 0
	light.Parent = center
	return {
		part = part,
		particles = particles,
		flames = flames,
		edge = edge,
		smoke = smoke,
		embers = embers,
		burst = burst,
		arcs = arcs,
		light = light,
		attachments = attachments,
	}
end

local function takeRig(particles: boolean): Rig
	fxFolder()
	for i = #freeRigs, 1, -1 do
		local rig = freeRigs[i]
		if not rig.part.Parent then
			table.remove(freeRigs, i)
		elseif rig.particles == particles then
			table.remove(freeRigs, i)
			return rig
		end
	end
	return build(particles)
end

-- Lays the rig out for a patch of `radius` at `at`: flames spread evenly over
-- the disc (golden angle), the edge points on the rim, smoke inside.
local function layout(rig: Rig, at: Vector3, radius: number)
	rig.part.CFrame = CFrame.new(at)
	-- The ember cylinder spans the patch.
	rig.part.Size = Vector3.new(radius * 2, 0.2, radius * 2)
	if not rig.particles then
		return
	end
	local golden = math.pi * (3 - math.sqrt(5))
	for n = 1, FLAME_POINTS do
		local r = radius * 0.92 * math.sqrt((n - 0.5) / FLAME_POINTS)
		local a = n * golden
		rig.attachments[n].Position =
			Vector3.new(math.cos(a) * r, FLAME_TALL * FLOOR_LIFT, math.sin(a) * r)
	end
	local i = FLAME_POINTS
	for n = 1, EDGE_POINTS do
		local a = (n / EDGE_POINTS) * math.pi * 2
		rig.attachments[i + n].Position =
			Vector3.new(math.cos(a) * radius, EDGE_TALL * FLOOR_LIFT, math.sin(a) * radius)
	end
	i += EDGE_POINTS
	for n = 1, SMOKE_POINTS do
		local a = n * 2.4
		local r = radius * 0.5 * ((n % 3) / 3 + 0.2)
		rig.attachments[i + n].Position = Vector3.new(math.cos(a) * r, 0.5, math.sin(a) * r)
	end
end

-- Emission at `k` (1 = full) for a fire of this size.
local function setRates(f: Fire, k: number)
	local rig = f.rig
	for _, e in rig.flames do
		e.Rate = 5 * k * f.area
	end
	for _, e in rig.edge do
		e.Rate = 7 * k * f.rim
	end
	for _, e in rig.smoke do
		e.Rate = 1.2 * k * f.rim
	end
	rig.embers.Rate = (if f.mesh then MESH_EMBER_RATE else 14) * k * f.area
	rig.arcs.Rate = if f.glitch then 10 * k * f.area else 0
end

-- A pooled rig is recoloured on every use (fire or glitch fire).
local function paint(rig: Rig, glitch: boolean)
	local flame = if glitch then GLITCH_FLAME else ColorSequence.new(FIRE_TINT)
	for _, e in rig.flames do
		e.Color = flame
	end
	for _, e in rig.edge do
		e.Color = flame
	end
	for _, e in rig.smoke do
		e.Color = if glitch then GLITCH_SMOKE else SMOKE_COLOR
	end
	rig.embers.Color = if glitch then GLITCH_EMBER else EMBER_COLOR
	rig.burst.Color = flame
	rig.light.Color = if glitch then GLITCH else LIGHT_COLOR
end

-- How the fire sounds for its size: deeper when bigger, higher when smaller.
local function pitchFor(radius: number): number
	return math.clamp((BASE_RADIUS / radius) ^ 0.35, 0.8, 1.35)
end

-- The mesh fire (FireKit) ----------------------------------------------------------

-- Every third flame over the patch is the bright yellow, the rest orange.
local function flameColor(i: number, glitch: boolean): Color3
	if glitch then
		return if i % 2 == 0 then GLITCH_PINK else GLITCH
	end
	return if i % 3 == 0 then FireKit.CORE else FireKit.BODY
end

local function paintMesh(m: MeshFire, glitch: boolean)
	m.pool.Color = if glitch then GLITCH_POOL else FireKit.POOL
	m.ring.Color = if glitch then GLITCH else FireKit.CORE
	m.crownA.Color = if glitch then GLITCH else FireKit.BODY
	m.crownB.Color = if glitch then GLITCH_PINK else FireKit.CORE
	for i, f in m.flames do
		FireKit.paint(f, flameColor(i, glitch))
	end
end

-- A mesh fire of `radius` (nil when the kit isn't installed): the flames
-- spread evenly over the inner 72% of the patch (golden angle).
local function meshFire(radius: number, glitch: boolean, now: number): MeshFire?
	if not FireKit.available() then
		return nil
	end
	local pool = FireKit.take("Pool")
	local ring = FireKit.take("Ring")
	local crownA = FireKit.take("CrownA")
	local crownB = FireKit.take("CrownB")
	if not pool or not ring or not crownA or not crownB then
		return nil
	end
	pool.Transparency = POOL_ALPHA
	local sizeK = (radius / BASE_RADIUS) ^ 0.3
	local count = math.clamp(
		math.floor(radius * MESH_FLAMES_PER_STUD + 0.5),
		MESH_FLAMES_MIN,
		MESH_FLAMES_MAX
	)
	local flames: { FireKit.Flame } = {}
	local spots: { Vector3 } = {}
	local heights: { number } = {}
	local golden = math.pi * (3 - math.sqrt(5))
	local turn = rng:NextNumber(0, math.pi * 2)
	for n = 1, count do
		local f = FireKit.flame(flameColor(n, glitch), now)
		if not f then
			break
		end
		local r = radius * 0.72 * math.sqrt((n - 0.5) / count)
		local a = turn + n * golden
		table.insert(flames, f)
		table.insert(spots, Vector3.new(math.cos(a) * r, 0, math.sin(a) * r))
		table.insert(heights, rng:NextNumber(FLAME_LOW, FLAME_HIGH) * sizeK)
	end
	local m: MeshFire = {
		pool = pool,
		ring = ring,
		crownA = crownA,
		crownB = crownB,
		flames = flames,
		spots = spots,
		heights = heights,
		seed = rng:NextNumber(0, 1000),
		sizeK = sizeK,
		skipA = Vector3.zero,
		skipB = Vector3.zero,
	}
	paintMesh(m, glitch)
	return m
end

local function dropMesh(m: MeshFire)
	FireKit.give("Pool", m.pool)
	FireKit.give("Ring", m.ring)
	FireKit.give("CrownA", m.crownA)
	FireKit.give("CrownB", m.crownB)
	for _, f in m.flames do
		FireKit.drop(f)
	end
	table.clear(m.flames)
end

-- The whoomp's progress: 0 at the burst, easing out to 1 at BURST_TIME.
local function burstEase(since: number): number
	local x = math.clamp(since / BURST_TIME, 0, 1)
	return 1 - (1 - x) ^ 3
end

-- Places a mesh fire: `t` is its animation time, `k` the fade (1 = full,
-- 0 = sunk), `b` the burst (0 = just burst, 1 = settled); flames over the
-- patch turn to face `eye`.
local function placeMesh(
	f: Fire,
	m: MeshFire,
	now: number,
	t: number,
	k: number,
	b: number,
	eye: Vector3?
)
	local spread = f.radius * (0.35 + 0.65 * b) * (0.85 + 0.15 * k)
	local tall = (1 + BURST_TALL * (1 - b)) * k
	local base = CFrame.new(f.at)
	local flat = Vector3.new(spread, 1, spread)
	FireKit.place(m.pool, "Pool", base * CFrame.new(0, 0.05, 0), flat)
	FireKit.place(m.ring, "Ring", base * CFrame.new(0, 0.07, 0), flat)
	local crown = CROWN_HEIGHT * m.sizeK * tall
	local ha = FireKit.flicker(m.seed, t, 0.6)
	local hb = FireKit.flicker(m.seed + 50, t, 0.6)
	FireKit.place(
		m.crownA,
		"CrownA",
		base * CFrame.new(m.skipA) * CFrame.Angles(0, m.seed + t * CROWN_SPIN_A, 0),
		Vector3.new(spread, math.max(crown * (0.8 + 0.2 * ha), 0.02), spread)
	)
	FireKit.place(
		m.crownB,
		"CrownB",
		base * CFrame.new(m.skipB) * CFrame.Angles(0, m.seed + t * CROWN_SPIN_B, 0),
		Vector3.new(spread, math.max(crown * (0.8 + 0.2 * hb), 0.02), spread)
	)
	local share = spread / f.radius
	for i, fl in m.flames do
		FireKit.swap(fl, now)
		local h, lean = FireKit.flicker(fl.seed, t, 1)
		local pos = f.at + m.spots[i] * share
		-- Face the camera: the tongue's flat side (model X) toward it.
		local yaw = fl.turn
		if eye then
			local d = eye - pos
			yaw += math.atan2(-d.Z, d.X)
		end
		local height = m.heights[i] * h * k * (0.4 + 0.6 * b)
		local w = FLAME_WIDTH * m.sizeK / math.sqrt(h)
		FireKit.place(
			fl.part,
			fl.name,
			CFrame.new(pos) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(lean, 0, 0),
			Vector3.new(w * 0.9, math.max(height, 0.02), w)
		)
	end
end

-- Ember shards flying out of a burst (FireKit's Spark).
local SPARK_GRAVITY = Vector3.new(0, -30, 0)

local function burstSparks(at: Vector3, radius: number, color: Color3, now: number)
	for n = 1, SPARKS do
		local part = FireKit.take("Spark")
		if not part then
			return
		end
		part.Color = color
		local a = (n / SPARKS) * math.pi * 2 + rng:NextNumber(-0.4, 0.4)
		local out = rng:NextNumber(0.9, 1.5) * radius
		table.insert(sparks, {
			part = part,
			from = at + Vector3.new(0, 0.5, 0),
			vel = Vector3.new(math.cos(a) * out, rng:NextNumber(9, 14), math.sin(a) * out),
			born = now,
		})
	end
end

local function stepSparks(now: number)
	for i = #sparks, 1, -1 do
		local s = sparks[i]
		local t = now - s.born
		if t >= SPARK_LIFE then
			table.remove(sparks, i)
			FireKit.give("Spark", s.part)
			continue
		end
		local vel = s.vel + SPARK_GRAVITY * t
		local pos = s.from + s.vel * t + SPARK_GRAVITY * (0.5 * t * t)
		local size = math.max(SPARK_SIZE * (1 - t / SPARK_LIFE), 0.02)
		FireKit.place(
			s.part,
			"Spark",
			CFrame.lookAt(pos, pos + vel) * CFrame.Angles(-math.pi / 2, 0, 0),
			Vector3.new(size, size, size)
		)
	end
end

-- Glitch fire's blinking blocks ---------------------------------------------------

local function takePixel(): Part
	local p = table.remove(freePixels)
	if p and p.Parent then
		return p
	end
	local made = Instance.new("Part")
	made.Name = "GlitchPixel"
	made.Anchored = true
	made.CanCollide = false
	made.CanQuery = false
	made.CanTouch = false
	made.CastShadow = false
	made.Material = Enum.Material.Neon
	made.Transparency = 1
	made.CFrame = CFrame.new(0, -10000, 0)
	made.Parent = fxFolder()
	return made
end

local function hidePixel(px: Pixel, now: number, k: number)
	px.shown = false
	px.part.Transparency = 1
	-- Fewer of them as the fire dies down.
	px.untilT = now + rng:NextNumber(0.02, 0.3) / math.max(k, 0.15)
end

local function showPixel(px: Pixel, f: Fire, now: number)
	local r = f.radius * 0.95 * math.sqrt(rng:NextNumber())
	local a = rng:NextNumber(0, math.pi * 2)
	local offset = Vector3.new(math.cos(a) * r, rng:NextNumber(0.15, 2.8), math.sin(a) * r)
	local part = px.part
	if rng:NextNumber() < 0.2 then
		-- A tear: a thin sliver across the fire.
		local long = rng:NextNumber(1.5, f.radius * 1.2)
		part.Size = Vector3.new(long, 0.08, rng:NextNumber(0.15, 0.4))
		part.CFrame = CFrame.new(f.at + offset * Vector3.new(0.5, 1, 0.5))
			* CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
	else
		local s = rng:NextNumber(0.2, 0.55)
		part.Size = Vector3.new(s, s, s)
		part.CFrame = CFrame.new(f.at + offset)
	end
	part.Color = PIXEL_COLORS[rng:NextInteger(1, #PIXEL_COLORS)]
	part.Transparency = rng:NextNumber(0, 0.25)
	px.shown = true
	px.untilT = now + rng:NextNumber(0.04, 0.12)
end

local function releasePixels(f: Fire)
	for _, px in f.pixels do
		px.part.Transparency = 1
		px.part.CFrame = CFrame.new(0, -10000, 0)
		table.insert(freePixels, px.part)
	end
	table.clear(f.pixels)
end

-- One frame of a glitch fire: the flames flip colour, the blocks blink, the
-- light jumps between levels, a crackle now and then.
local function stepGlitch(f: Fire, now: number, k: number)
	local rig = f.rig
	if now >= f.nextFlip then
		f.nextFlip = now + FLIP_GAP
		local fire = ColorSequence.new(FIRE_TINT)
		for _, list in { rig.flames, rig.edge } do
			for _, e in list do
				if rng:NextNumber() < FLIP_SHARE then
					e.Color = if rng:NextNumber() < 0.6 then GLITCH_FLAME else fire
				end
			end
		end
		local m = f.mesh
		if m then
			local function flip(part: BasePart, glitch: Color3, normal: Color3)
				if rng:NextNumber() < FLIP_SHARE then
					part.Color = if rng:NextNumber() < 0.6 then glitch else normal
				end
			end
			flip(m.crownA, GLITCH, FireKit.BODY)
			flip(m.crownB, GLITCH_PINK, FireKit.CORE)
			flip(m.ring, GLITCH, FireKit.CORE)
			for i, fl in m.flames do
				if rng:NextNumber() < FLIP_SHARE then
					FireKit.paint(fl, flameColor(i, rng:NextNumber() < 0.6))
				end
			end
		end
	end
	for _, px in f.pixels do
		if now >= px.untilT then
			if px.shown or rng:NextNumber() > k then
				hidePixel(px, now, k)
			else
				showPixel(px, f, now)
			end
		end
	end
	if now >= f.nextLight then
		f.nextLight = now + LIGHT_STEP * rng:NextInteger(1, 3)
		f.lightLevel = if rng:NextNumber() < 0.15 then 0.3 else rng:NextNumber(1.6, 3.4)
	end
	local spike = math.max(0, 1 - (now - f.startAt) / 0.35) * 4
	rig.light.Brightness = f.lightLevel * k + spike
	if now >= f.nextCrackle and k >= 1 then
		f.nextCrackle = now + rng:NextNumber(CRACKLE_MIN, CRACKLE_MAX)
		ModAudio.play(S.glitchCrackle, f.at, CRACKLE_PITCHES[rng:NextInteger(1, #CRACKLE_PITCHES)])
	end
end

-- The canister bursts at `at` (the floor): a fire of `radius` until
-- `duration` after server time `start`; `glitch`: Fork Fire's glitch fire.
function MollyFx.ignite(
	at: Vector3,
	radius: number,
	duration: number,
	start: number,
	glitch: boolean?
)
	local left = duration - (Workspace:GetServerTimeNow() - start)
	if left <= 0 then
		return
	end
	local isGlitch = glitch == true
	local now = os.clock()
	local mesh = meshFire(radius, isGlitch, now)
	local rig = takeRig(mesh == nil)
	layout(rig, at + Vector3.new(0, 0.1, 0), radius)
	paint(rig, isGlitch)
	rig.light.Range = radius * 1.8
	if mesh then
		-- The whoomp is the mesh rings spreading out (placeMesh); shards fly.
		burstSparks(at, radius, if isGlitch then GLITCH else FireKit.CORE, now)
	else
		-- The whoomp: the sheet as wide as the patch (its base on the floor), a
		-- smaller one a beat later.
		local burstAttachment = rig.burst.Parent :: Attachment
		burstAttachment.Position = Vector3.new(0, radius * 0.5, 0)
		rig.burst.Size = NumberSequence.new(radius * 2)
		rig.burst:Emit(1)
		task.delay(0.06, function()
			rig.burst.Size = NumberSequence.new(radius * 1.4)
			rig.burst:Emit(1)
		end)
	end
	-- And a light spike.
	rig.light.Brightness = 6
	local pitch = pitchFor(radius)
	ModAudio.play(S.burst, at, pitch)
	if isGlitch then
		ModAudio.play(S.glitchCrackle, at, 1.5)
		ModVfx.burst(at + Vector3.new(0, 1, 0), GLITCH, 10, "Sparkle")
	end
	local scorch = ModVfx.quad({
		texture = VFX.MOLLY_SCORCH,
		cframe = CFrame.new(at + Vector3.new(0, 0.05, 0)),
		from = radius * 2.6, -- the char fills the middle 60%
		color = if isGlitch then GLITCH_SCORCH else Color3.new(1, 1, 1),
		life = left + SCORCH_LINGER,
		alpha0 = 0.05,
		hold = true,
	})
	local hum = ModAudio.hum(if isGlitch then S.glitchLoop else S.fireLoop, rig.part)
	if hum then
		hum.sound.PlaybackSpeed *= pitch
	end
	local pixels: { Pixel } = {}
	if isGlitch then
		for _ = 1, math.clamp(math.floor(radius * 1.6 + 0.5), 6, 20) do
			table.insert(pixels, { part = takePixel(), shown = false, untilT = now })
		end
	end
	local f: Fire = {
		rig = rig,
		at = at,
		radius = radius,
		startAt = now,
		endAt = now + left,
		hum = hum,
		sizzled = false,
		scorch = scorch,
		area = math.clamp((radius / BASE_RADIUS) ^ 2, 0.3, 2.4),
		rim = math.clamp(radius / BASE_RADIUS, 0.55, 1.6),
		glitch = isGlitch,
		pixels = pixels,
		nextFlip = now,
		nextLight = now,
		lightLevel = 2.2,
		nextCrackle = now + rng:NextNumber(CRACKLE_MIN, CRACKLE_MAX),
		mesh = mesh,
		nextGlitchFrame = now,
	}
	setRates(f, 1)
	if mesh then
		local camera = Workspace.CurrentCamera
		placeMesh(f, mesh, now, now, 1, 0, if camera then camera.CFrame.Position else nil)
	end
	table.insert(fires, f)
end

-- A canister that never found a floor: a small pop, nothing burns (`glitch`:
-- a Fork Fire bomblet: a pop of magenta static).
function MollyFx.fizzle(at: Vector3, glitch: boolean?)
	if glitch then
		ModAudio.play(S.glitchCrackle, at, 2)
		ModVfx.burst(at, GLITCH, 8, "Sparkle")
		return
	end
	ModAudio.play(S.sizzleOut, at)
end

-- Small flames on everyone burning (the server's BurningUntil), and the
-- sizzle for us.
type Burn = { emitter: ParticleEmitter, root: BasePart }
local burns: { [Model]: Burn } = setmetatable({}, { __mode = "k" }) :: any
local burnSoundAt = -math.huge
local BURN_SOUND_GAP = 0.3

local function burnOf(model: Model, root: BasePart): Burn
	local b = burns[model]
	if b and b.emitter.Parent and b.root == root then
		return b
	end
	-- One per root, even if this table lost its entry.
	local existing = root:FindFirstChild("MollyBurn")
	if existing and existing:IsA("ParticleEmitter") then
		local found = { emitter = existing, root = root }
		burns[model] = found
		return found
	end
	-- On the root: its box (the torso) is where the flames come from.
	local e = flameEmitter(root, 1)
	e.Name = "MollyBurn"
	e.Shape = Enum.ParticleEmitterShape.Box
	e.Rate = 0
	local made = { emitter = e, root = root }
	burns[model] = made
	return made
end

local function stepBurning(serverNow: number)
	local function check(model: Instance)
		if not model:IsA("Model") then
			return
		end
		local untilT = model:GetAttribute("BurningUntil")
		local burning = typeof(untilT) == "number" and serverNow < untilT
		local b = burns[model]
		if not burning and not b then
			return
		end
		local root = model:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			return
		end
		local burn = burnOf(model, root)
		burn.emitter.Rate = if burning then 14 else 0
		if burning and model == player.Character then
			local now = os.clock()
			if now - burnSoundAt >= BURN_SOUND_GAP then
				burnSoundAt = now
				ModAudio.play(S.burning)
			end
		end
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
end

-- One frame of a mesh fire: the burst, the flames' dance (at most every
-- ANIM_GAP, or GLITCH_FPS for glitch fire; still when far away), the sinking
-- end; back to the pools once it's out.
local function stepMesh(
	f: Fire,
	m: MeshFire,
	now: number,
	left: number,
	k: number,
	animate: boolean,
	eye: Vector3?
)
	if left <= 0 then
		f.mesh = nil
		dropMesh(m)
		return
	end
	local since = now - f.startAt
	local moving = since < BURST_TIME or k < 1
	local near = not eye or (eye - f.at).Magnitude < ANIM_RANGE
	local t = now
	if f.glitch then
		-- Choppy: a new pose GLITCH_FPS times a second, a ring now and then
		-- drawn off-centre for one of them.
		if now < f.nextGlitchFrame or not near then
			return
		end
		f.nextGlitchFrame = now + 1 / GLITCH_FPS
		local function skip(): Vector3
			if rng:NextNumber() >= SKIP_CHANCE then
				return Vector3.zero
			end
			local a = rng:NextNumber(0, math.pi * 2)
			return Vector3.new(math.cos(a), 0, math.sin(a)) * rng:NextNumber(0.4, 1)
		end
		m.skipA = skip()
		m.skipB = skip()
	elseif not moving and not (animate and near) then
		return
	end
	placeMesh(f, m, now, t, k, burstEase(since), eye)
end

-- Per frame (ModFxController.update).
function MollyFx.step()
	local now = os.clock()
	local animate = now - lastAnim >= ANIM_GAP
	if animate then
		lastAnim = now
	end
	local camera = Workspace.CurrentCamera
	local eye = if camera then camera.CFrame.Position else nil
	for i = #fires, 1, -1 do
		local f = fires[i]
		local rig = f.rig
		local left = f.endAt - now
		if left <= -1 then
			-- Out, and the last particles are gone: back to the pool (the
			-- loop stopped even if a long frame skipped the fade).
			ModAudio.stopHum(f.hum)
			f.hum = nil
			table.remove(fires, i)
			releasePixels(f)
			local m = f.mesh
			if m then
				f.mesh = nil
				dropMesh(m)
			end
			rig.light.Brightness = 0
			rig.part.CFrame = CFrame.new(0, -10000, 0)
			table.insert(freeRigs, rig)
			continue
		end
		if left <= FADE_TIME and not f.sizzled then
			f.sizzled = true
			ModAudio.stopHum(f.hum)
			f.hum = nil
			ModAudio.play(S.sizzleOut, f.at, pitchFor(f.radius))
			if f.glitch then
				-- It goes out as static.
				ModAudio.play(S.glitchCrackle, f.at, 1)
				local count = math.floor(f.radius * 2)
				ModVfx.burst(f.at + Vector3.new(0, 1, 0), GLITCH, count, "Sparkle")
			end
		end
		local k = math.clamp(left / FADE_TIME, 0, 1)
		setRates(f, k)
		local m = f.mesh
		if m then
			stepMesh(f, m, now, left, k, animate, eye)
		end
		if f.glitch then
			stepGlitch(f, now, k)
			continue
		end
		-- Flicker: a warm light that never sits still; the burst's spike decays.
		local since = now - f.startAt
		local base = 2.2
			+ 0.6 * math.noise(now * 7.3, f.at.X)
			+ 0.4 * math.noise(now * 13.1, f.at.Z)
		local spike = math.max(0, 1 - since / 0.35) * 4
		rig.light.Brightness = math.max(0, base * k + spike)
	end
	stepSparks(now)
	FireKit.flush()
	stepBurning(Workspace:GetServerTimeNow())
end

return MollyFx
