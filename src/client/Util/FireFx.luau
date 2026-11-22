--!strict
-- The fire element of the ability rework (vault/02 Art/Ability VFX Direction.md,
-- locked 2026-11-16 → Layer kits F1-F7, Per Mod → Molly / Fork Fire). One
-- module draws fire for every Mod that burns: the Molly patch, Fork Fire's
-- small patches and burning players. (Firewall's curtain and hand flame build
-- on the same tongues next.)
--
-- Shapes first: the silhouette is the kit's three tongue meshes
-- (Util/ReworkVfx, `Fire_TongueA/B/C`), standing up on a 0.12 s Snap, holding
-- one of four poses and changing a third of them 12 times a second (held
-- frames, not a smooth wobble), sinking into the floor over the last 0.3 s.
-- The tall dark tongues stand in the middle and mid / short ones on the rim
-- (60% of them, the danger line), so the patch rises to a peak like a fire;
-- every hook curls away from the middle as you see it (first greyscale pass,
-- 2026-11-16: tall hooks on the rim round a hollow middle read as claws). Particles are only the fire's debris: licks of the flame sheet
-- (slowed to ~12 fps), a few embers, a low dark-red pall, the ignite burst.
-- One warm light. The team-coloured ring on the floor says whose fire it is.
--
--   FireFx.ready()                     the kit is installed (else keep the old look)
--   FireFx.patch(at, radius, left, ringColor)   a fire patch for `left` seconds
--   FireFx.split(at)                   Fork Fire's split: the glitch accent + spikes
--   FireFx.setBurning(model, root, on, own)     the flames on a burning body
--   FireFx.step()                      per frame (MollyFx.step)
--
-- Timing runs on ReworkVfx.now(), so Studio's VfxTimeScale freezes it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local VFX = require(ReplicatedStorage.Shared.Config.VfxTextures)

local ReworkVfx = require(script.Parent.ReworkVfx)

local FireFx = {}

local player = Players.LocalPlayer
local rng = Random.new()

-- Colours (F1, F2, F4, F6). Neon draws a step brighter than its colour (the
-- spec's FF6A1F showed yellow, FFD98A white), so the meshes use darker values
-- that land on the spec's look (the spec allows this: "darken its colour
-- value until it does not bloom"); particles keep the spec colours.
local BACK = Color3.fromHex("C2260A") -- tongue A, the tall back flames
local BODY = Color3.fromHex("FF6A1F") -- tongue B
local FRONT = Color3.fromHex("FFD98A") -- tongue C, short and light, in front
local MESH_BACK = Color3.fromHex("8A1606")
local MESH_BODY = Color3.fromHex("C8430E")
local MESH_FRONT = Color3.fromHex("D49A3A")
local PALL = Color3.fromHex("8A1A08")
local LIGHT = Color3.fromHex("FF5A1A")
local GLITCH = Color3.fromHex("FF3DCB")
local LICK_COLOR = ColorSequence.new({
	ColorSequenceKeypoint.new(0, FRONT),
	ColorSequenceKeypoint.new(0.5, BODY),
	ColorSequenceKeypoint.new(1, BACK),
})
local EMBER_COLOR = ColorSequence.new(FRONT, BODY)

-- F1 tongues.
local MOLLY_RADIUS = 9 -- L1: the counts below are Molly's
local MOLLY_TONGUES = 14 -- 4 A, 6 B, 4 C
local MIN_TONGUES, MAX_TONGUES = 5, 30
local RIM_SHARE = 0.6
local HEIGHT: { [string]: { number } } = {
	Fire_TongueA = { 5, 7 },
	Fire_TongueB = { 3.5, 5 },
	Fire_TongueC = { 2, 3 },
}
local COLOR: { [string]: Color3 } =
	{ Fire_TongueA = MESH_BACK, Fire_TongueB = MESH_BODY, Fire_TongueC = MESH_FRONT }
local WIDTH = 0.65 -- tongue width per stud of height (its kit width is ~0.8-0.95 at height 1)
local RISE = 0.12 -- Snap
local SINK = 0.3
local POSE_HZ = 12
local POSE_Y = { 0.85, 1, 1.1, 0.95 }
local POSE_YAW = math.rad(12)
local POSE_LEAN = math.rad(8)
local CHANGE_SHARE = 1 / 3
local TONGUE_ALPHA = 0.02
local RING_ALPHA = 0.2
local RING_LIFT = 0.08
local RING_POP = 0.12

-- Particles: rates at full detail (Distance tiers halve them, then drop them).
local LICK_RATE = 20
local EMBER_RATE = 20
local PALL_RATE = 5
local LIGHT_RANGE = 27
local LIGHT_BRIGHTNESS = 1.5 -- PROPOSED (spec 3): 3 washed the grey floor pink out to 27 studs
local NEAR, FAR = 60, 120

-- F7.
local BODY_LICK_RATE = 8
local BODY_EMBER_RATE = 5
local CORNER_FPS = 12
local CORNER_SIZE = 0.26 -- of the screen height
local CORNER_ALPHA = 0.25

type Tongue = {
	part: BasePart,
	name: ReworkVfx.Name,
	spot: Vector3, -- offset from the patch centre
	height: number,
	delay: number, -- its Snap starts this much after the ignite
	pose: number,
	yaw: number,
	lean: number,
}

export type Patch = {
	at: Vector3,
	radius: number,
	born: number,
	endAt: number,
	tongues: { Tongue },
	ring: BasePart?,
	ringColor: Color3,
	anchor: Part, -- holds the emitters and the light (and the caller's hum)
	licks: ParticleEmitter,
	embers: ParticleEmitter,
	pall: ParticleEmitter,
	light: PointLight,
	nextPose: number,
	tier: number, -- 0 full, 1 halved, 2 meshes and footprint only
	done: boolean,
}

local patches: { Patch } = {}
local folder: Folder? = nil
local appliedScale = -1

local function fxFolder(): Folder
	local f = folder
	if f and f.Parent then
		return f
	end
	local made = Instance.new("Folder")
	made.Name = "FireFx"
	made.Parent = Workspace
	folder = made
	return made
end

function FireFx.ready(): boolean
	return ReworkVfx.ready()
end

-- Fire particles subtract light from what is behind them (LightEmission -1,
-- the RIVALS recipe: solid, saturated, under the Bloom threshold).
local function fireLook(e: ParticleEmitter, brightness: number)
	e.LightInfluence = 0
	e.Brightness = brightness
	local ok = pcall(function()
		e.LightEmission = -1
	end)
	if not ok then
		e.LightEmission = 0
	end
end

local function emitter(parent: Instance, texture: string): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = texture
	e.Rate = 0
	e.LockedToPart = false
	e.ZOffset = 0
	e.Parent = parent
	return e
end

-- `from` + (`to` - `from`) * curve, as a NumberSequence.
local function ranged(curve: ReworkVfx.Curve, from: number, to: number): NumberSequence
	local s = ReworkVfx.sequence(curve, 1)
	local keys = {}
	for _, k in s.Keypoints do
		table.insert(keys, NumberSequenceKeypoint.new(k.Time, from + (to - from) * k.Value))
	end
	return NumberSequence.new(keys)
end

local function flameSheet(e: ParticleEmitter)
	e.Texture = VFX.FLAME_SHEET_4x4
	e.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
	e.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
end

-- Base TimeScale of each emitter, scaled by the Studio review clock.
local baseScale: { [ParticleEmitter]: number } = setmetatable({}, { __mode = "k" }) :: any

local function setScale(e: ParticleEmitter, s: number)
	baseScale[e] = s
	e.TimeScale = s * ReworkVfx.timeScale()
end

local function buildAnchor(
	at: Vector3,
	radius: number
): (Part, ParticleEmitter, ParticleEmitter, ParticleEmitter, PointLight)
	local p = Instance.new("Part")
	p.Name = "FirePatch"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = Vector3.new(radius * 1.7, 0.2, radius * 1.7)
	p.CFrame = CFrame.new(at + Vector3.new(0, 0.1, 0))

	-- F2 licks: the rolling top edge between the tongues.
	local licks = emitter(p, VFX.FLAME_SHEET_4x4)
	flameSheet(licks)
	licks.Lifetime = NumberRange.new(0.5, 0.7)
	licks.Size = ReworkVfx.sequence("Grow", 5)
	licks.Transparency = ReworkVfx.sequence("Cut")
	licks.Color = LICK_COLOR
	licks.Acceleration = Vector3.new(0, 40, 0)
	licks.Drag = 3
	licks.Speed = NumberRange.new(0)
	licks.Rotation = NumberRange.new(-8, 8)
	licks.Orientation = Enum.ParticleOrientation.FacingCamera
	-- PROPOSED (spec LightEmission -1 / Brightness 5): -1 drew the licks a
	-- muddy olive over a lit floor; 0 / 1.2 keeps them flat fire colours.
	licks.LightInfluence = 0
	licks.LightEmission = 0
	licks.Brightness = 1.2
	setScale(licks, 0.5)

	-- F3 embers: rising sparks.
	local embers = emitter(p, VFX.T_CHIP)
	embers.Lifetime = NumberRange.new(0.2, 0.4)
	embers.Size = ReworkVfx.sequence("Bell", 1)
	embers.Speed = NumberRange.new(70, 130)
	embers.SpreadAngle = Vector2.new(40, 40)
	embers.EmissionDirection = Enum.NormalId.Top
	embers.Acceleration = Vector3.new(0, 200, 0)
	embers.Drag = 15
	embers.Color = EMBER_COLOR
	embers.Rotation = NumberRange.new(0, 360)
	fireLook(embers, 7)
	setScale(embers, 0.3)

	-- F4 pall: grounds the fire, dark red and low.
	local pall = emitter(p, VFX.T_PUFF)
	pall.Lifetime = NumberRange.new(0.3)
	pall.Size = ranged("Fade", radius * 0.55, radius * 0.9)
	pall.Transparency = ReworkVfx.sequence("Haze")
	pall.Color = ColorSequence.new(PALL)
	pall.Speed = NumberRange.new(1, 3)
	pall.EmissionDirection = Enum.NormalId.Top
	pall.Rotation = NumberRange.new(0, 360)
	pall.LightInfluence = 0
	pall.LightEmission = 0
	pall.Brightness = 0.4
	setScale(pall, 0.25)

	-- F6: the one warm light.
	local light = Instance.new("PointLight")
	light.Color = LIGHT
	light.Range = math.min(LIGHT_RANGE, radius * 2) -- PROPOSED (spec 27 at every size): less floor wash
	light.Brightness = 0
	light.Shadows = false
	light.Parent = p

	p.Parent = fxFolder()
	return p, licks, embers, pall, light
end

-- F5: the snap on landing (spikes and blooms, embers 0.075 s later).
local function ignite(anchor: Part, radius: number)
	local a = Instance.new("Attachment")
	a.Position = Vector3.new(0, 0.3, 0)
	a.Parent = anchor
	local k = math.clamp(radius / MOLLY_RADIUS, 0.55, 1.3)

	local spikes = emitter(a, VFX.T_STREAK)
	spikes.Orientation = Enum.ParticleOrientation.VelocityParallel
	spikes.Lifetime = NumberRange.new(0.05, 0.13)
	spikes.Size = ReworkVfx.sequence("Spike", 9 * k)
	spikes.Speed = NumberRange.new(170, 250)
	spikes.Drag = 12
	spikes.SpreadAngle = Vector2.new(70, 70)
	spikes.EmissionDirection = Enum.NormalId.Top
	spikes.Color = ColorSequence.new(FRONT)
	fireLook(spikes, 7)
	setScale(spikes, 1)

	local blooms = emitter(a, VFX.FLAME_SHEET_4x4)
	flameSheet(blooms)
	blooms.Lifetime = NumberRange.new(0.15, 0.3) -- 0.3-0.6 on screen at TimeScale 0.5
	blooms.Size = ranged("Pop", 5.5 * k, 11 * k)
	blooms.Transparency = ReworkVfx.sequence("Cut")
	blooms.Speed = NumberRange.new(40, 100)
	blooms.Drag = 14 -- at 6 they flew ~16 studs up and hung over the patch
	blooms.SpreadAngle = Vector2.new(80, 80)
	blooms.EmissionDirection = Enum.NormalId.Top
	blooms.Color = LICK_COLOR
	blooms.Rotation = NumberRange.new(-10, 10)
	-- PROPOSED (spec -1 / 5): as the licks, -1 left a dark smudge in the middle.
	blooms.LightInfluence = 0
	blooms.LightEmission = 0
	blooms.Brightness = 1.2
	setScale(blooms, 0.5)

	local sparks = emitter(a, VFX.T_CHIP)
	sparks.Lifetime = NumberRange.new(0.3, 0.6)
	sparks.Size = ReworkVfx.sequence("Bell", 1)
	sparks.Speed = NumberRange.new(40, 90)
	sparks.SpreadAngle = Vector2.new(70, 70)
	sparks.EmissionDirection = Enum.NormalId.Top
	sparks.Acceleration = Vector3.new(0, -30, 0)
	sparks.Drag = 3
	sparks.Color = EMBER_COLOR
	sparks.Rotation = NumberRange.new(0, 360)
	fireLook(sparks, 7)
	setScale(sparks, 1)

	spikes:Emit(6)
	blooms:Emit(8)
	task.delay(0.075 / math.max(ReworkVfx.timeScale(), 0.05), function()
		if sparks.Parent then
			sparks:Emit(10)
		end
	end)
	task.delay(2, function()
		a:Destroy()
	end)
end

local function newPose(t: Tongue)
	local p = rng:NextInteger(1, #POSE_Y - 1)
	t.pose = if p >= t.pose then p + 1 else p
	t.yaw = rng:NextNumber(-POSE_YAW, POSE_YAW)
	t.lean = rng:NextNumber(-POSE_LEAN, POSE_LEAN)
end

-- The tongues of a patch: 60% on the rim (B and C, the burning edge), the
-- rest inside (the tall A, some B), all scaled gently with the radius.
local function tongues(radius: number): { Tongue }
	local area = (radius / MOLLY_RADIUS) ^ 2
	local count = math.clamp(math.floor(MOLLY_TONGUES * area + 0.5), MIN_TONGUES, MAX_TONGUES)
	local sizeK = math.clamp((radius / MOLLY_RADIUS) ^ 0.5, 0.6, 1.25)
	local rim = math.max(math.floor(count * RIM_SHARE + 0.5), 3)
	local inner = count - rim
	local out: { Tongue } = {}
	local function add(name: ReworkVfx.Name, spot: Vector3, delay: number)
		local part = ReworkVfx.take(name)
		if not part then
			return
		end
		part.Color = COLOR[name]
		part.Material = Enum.Material.Neon
		part.Transparency = TONGUE_ALPHA
		local h = HEIGHT[name]
		local t: Tongue = {
			part = part,
			name = name,
			spot = spot,
			height = rng:NextNumber(h[1], h[2]) * sizeK,
			delay = delay,
			pose = rng:NextInteger(1, #POSE_Y),
			yaw = 0,
			lean = 0,
		}
		newPose(t)
		table.insert(out, t)
	end
	local turn = rng:NextNumber(0, math.pi * 2)
	for i = 1, rim do
		local a = turn + (i - 0.5) / rim * math.pi * 2 + rng:NextNumber(-0.15, 0.15)
		local r = radius * rng:NextNumber(0.8, 0.92)
		local name: ReworkVfx.Name = if i % 2 == 1 then "Fire_TongueB" else "Fire_TongueC"
		add(name, Vector3.new(math.cos(a) * r, 0, math.sin(a) * r), rng:NextNumber(0, 0.04))
	end
	local golden = math.pi * (3 - math.sqrt(5))
	for n = 1, inner do
		local r = radius * 0.55 * math.sqrt((n - 0.5) / inner)
		local a = turn + n * golden
		local name: ReworkVfx.Name = if n % 3 == 0 then "Fire_TongueB" else "Fire_TongueA"
		add(name, Vector3.new(math.cos(a) * r, 0, math.sin(a) * r), rng:NextNumber(0, 0.04))
	end
	return out
end

-- A fire patch at `at` (the floor) of `radius`, burning for `left` seconds.
function FireFx.patch(at: Vector3, radius: number, left: number, ringColor: Color3?): Patch?
	if not ReworkVfx.ready() then
		return nil
	end
	local now = ReworkVfx.now()
	local anchor, licks, embers, pall, light = buildAnchor(at, radius)
	local ring = ReworkVfx.take("FX_Ring")
	local color = ringColor or Color3.new(1, 1, 1)
	if ring then
		ring.Color = color
		ring.Material = Enum.Material.Neon
		ring.Transparency = RING_ALPHA
	end
	local p: Patch = {
		at = at,
		radius = radius,
		born = now,
		endAt = now + left,
		tongues = tongues(radius),
		ring = ring,
		ringColor = color,
		anchor = anchor,
		licks = licks,
		embers = embers,
		pall = pall,
		light = light,
		nextPose = now + 1 / POSE_HZ,
		tier = -1,
		done = false,
	}
	ignite(anchor, radius)
	table.insert(patches, p)
	return p
end

-- Ends a patch early (it sinks over SINK).
function FireFx.stop(p: Patch)
	local now = ReworkVfx.now()
	if p.endAt > now + SINK then
		p.endAt = now + SINK
	end
end

local function release(p: Patch)
	p.done = true
	for _, t in p.tongues do
		ReworkVfx.give(t.name, t.part)
	end
	table.clear(p.tongues)
	local ring = p.ring
	if ring then
		ReworkVfx.give("FX_Ring", ring)
		p.ring = nil
	end
	p.licks.Enabled = false
	p.embers.Enabled = false
	p.pall.Enabled = false
	p.light.Enabled = false
	-- The last particles finish before the part goes.
	local anchor = p.anchor
	task.delay(1.5, function()
		anchor:Destroy()
	end)
end

local function setTier(p: Patch, tier: number)
	if tier == p.tier then
		return
	end
	p.tier = tier
	local area = math.clamp((p.radius / MOLLY_RADIUS) ^ 2, 0.3, 2.4)
	local k = if tier == 0 then 1 elseif tier == 1 then 0.5 else 0
	p.licks.Rate = LICK_RATE * area * k
	p.embers.Rate = if tier == 0 then EMBER_RATE * area else 0
	p.pall.Rate = PALL_RATE * math.sqrt(area) * k
	p.light.Enabled = tier < 2
end

local function stepPatch(p: Patch, now: number, eye: Vector3?)
	local age = now - p.born
	local left = p.endAt - now
	if left <= 0 then
		release(p)
		return
	end
	local away = if eye then (eye - p.at).Magnitude else 0
	setTier(p, if away < NEAR then 0 elseif away < FAR then 1 else 2)
	-- The sink: rates and the light fall with the tongues.
	local sink = math.clamp(left / SINK, 0, 1)
	if sink < 1 then
		p.licks.Rate = 0
		p.embers.Rate = 0
		p.pall.Rate = 0
	end
	p.light.Brightness = LIGHT_BRIGHTNESS * sink

	-- Held poses: a third of the tongues change on each 12 Hz step.
	if now >= p.nextPose then
		p.nextPose = now + 1 / POSE_HZ
		for _, t in p.tongues do
			if rng:NextNumber() < CHANGE_SHARE then
				newPose(t)
			end
		end
	end

	local ring = p.ring
	if ring then
		local r = 2 * p.radius * ReworkVfx.curve("Pop", age / RING_POP)
		ring.Transparency = RING_ALPHA + (1 - RING_ALPHA) * (1 - sink)
		ReworkVfx.place(
			ring,
			"FX_Ring",
			CFrame.new(p.at + Vector3.new(0, RING_LIFT, 0)),
			Vector3.new(r, 1, r)
		)
	end
	for _, t in p.tongues do
		local rise = ReworkVfx.snap(age - t.delay, RISE)
		if age < t.delay then
			rise = 0
		end
		local h = t.height * POSE_Y[t.pose] * rise * sink
		local pos = p.at + t.spot
		-- The flat side (kit X) toward the viewer, then the pose's yaw and lean;
		-- turned round when that makes its hook curl away from the middle.
		local yaw = t.yaw
		if eye then
			local d = eye - pos
			local face = math.atan2(-d.Z, d.X)
			-- The hook curls toward the kit's +Z: flip it when +Z points inward.
			local side = CFrame.Angles(0, face, 0):VectorToWorldSpace(Vector3.zAxis)
			local outward = side:Dot(t.spot) >= 0
			yaw += face + (if outward then 0 else math.pi)
		end
		local w = t.height * WIDTH
		ReworkVfx.place(
			t.part,
			t.name,
			CFrame.new(pos) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(t.lean, 0, 0),
			Vector3.new(w, math.max(h, 0.01), w)
		)
	end
end

-- Fork Fire's split: the glitch accent (two frames of the bomblet burst
-- doubled 0.3 studs off with a magenta edge) and four ignite spikes.
function FireFx.split(at: Vector3)
	if not ReworkVfx.ready() then
		return
	end
	local a = Instance.new("Attachment")
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.CFrame = CFrame.new(at + Vector3.new(0, 0.3, 0))
	a.Parent = holder
	holder.Parent = fxFolder()
	local spikes = emitter(a, VFX.T_STREAK)
	spikes.Orientation = Enum.ParticleOrientation.VelocityParallel
	spikes.Lifetime = NumberRange.new(0.05, 0.13)
	spikes.Size = ReworkVfx.sequence("Spike", 6)
	spikes.Speed = NumberRange.new(170, 250)
	spikes.Drag = 12
	spikes.SpreadAngle = Vector2.new(80, 80)
	spikes.EmissionDirection = Enum.NormalId.Top
	spikes.Color = ColorSequence.new(FRONT)
	fireLook(spikes, 7)
	setScale(spikes, 1)
	spikes:Emit(4)
	-- The accent: the split's shape (a C tongue fan) twice, the copy offset
	-- 0.3 studs with the glitch edge colour, for two frames at 12 Hz.
	local pieces: { { name: ReworkVfx.Name, part: BasePart } } = {}
	local side = Vector3.new(0.3, 0, 0)
	for i = 0, 2 do
		local yaw = i * math.pi * 2 / 3
		for copy = 0, 1 do
			local part = ReworkVfx.take("Fire_TongueC")
			if part then
				part.Material = Enum.Material.Neon
				part.Color = if copy == 0 then MESH_FRONT else GLITCH
				part.Transparency = if copy == 0 then 0.02 else 0.3
				ReworkVfx.place(
					part,
					"Fire_TongueC",
					CFrame.new(at + side * copy)
						* CFrame.Angles(0, yaw, 0)
						* CFrame.Angles(0.5, 0, 0),
					Vector3.new(1.6, 2.2, 1.6)
				)
				table.insert(pieces, { name = "Fire_TongueC", part = part })
			end
		end
	end
	ReworkVfx.flush()
	task.delay((2 / 12) / math.max(ReworkVfx.timeScale(), 0.05), function()
		for _, piece in pieces do
			ReworkVfx.give(piece.name, piece.part)
		end
	end)
	task.delay(1, function()
		holder:Destroy()
	end)
end

-- F7: burning bodies -----------------------------------------------------------------

type Burn = { licks: ParticleEmitter, embers: ParticleEmitter, root: BasePart }
local burns: { [Model]: Burn } = setmetatable({}, { __mode = "k" }) :: any

local function burnOf(model: Model, root: BasePart): Burn
	local b = burns[model]
	if b and b.licks.Parent == root then
		return b
	end
	local licks = root:FindFirstChild("FireLicks")
	local embers = root:FindFirstChild("FireEmbers")
	if not (licks and licks:IsA("ParticleEmitter")) then
		local e = emitter(root, VFX.FLAME_SHEET_4x4)
		e.Name = "FireLicks"
		flameSheet(e)
		e.Shape = Enum.ParticleEmitterShape.Box
		e.Lifetime = NumberRange.new(0.2, 0.4)
		e.Size = NumberSequence.new(2.2)
		e.Transparency = ReworkVfx.sequence("Cut")
		e.Color = LICK_COLOR
		e.Speed = NumberRange.new(0)
		e.Acceleration = Vector3.new(0, 12, 0)
		e.LockedToPart = true
		fireLook(e, 5)
		setScale(e, 0.3)
		licks = e
	end
	if not (embers and embers:IsA("ParticleEmitter")) then
		local e = emitter(root, VFX.T_CHIP)
		e.Name = "FireEmbers"
		e.Shape = Enum.ParticleEmitterShape.Box
		e.Lifetime = NumberRange.new(0.2, 0.4)
		e.Size = NumberSequence.new(0.6)
		e.Transparency = ReworkVfx.sequence("Fade")
		e.Color = EMBER_COLOR
		e.Speed = NumberRange.new(4, 8)
		e.EmissionDirection = Enum.NormalId.Top
		e.Rotation = NumberRange.new(0, 360)
		e.LockedToPart = true
		fireLook(e, 7)
		setScale(e, 0.3)
		embers = e
	end
	local made: Burn =
		{ licks = licks :: ParticleEmitter, embers = embers :: ParticleEmitter, root = root }
	burns[model] = made
	return made
end

-- The victim's view: two flame-sheet frames in the bottom screen corners.
local corners: { ImageLabel } = {}
local cornerGui: ScreenGui? = nil
local ownBurning = false
local cornerFrame = 0
local nextCorner = 0

local function cornerLabels(): { ImageLabel }
	local gui = cornerGui
	if gui and gui.Parent then
		return corners
	end
	table.clear(corners)
	local made = Instance.new("ScreenGui")
	made.Name = "FireCorners"
	made.IgnoreGuiInset = true
	made.ScreenInsets = Enum.ScreenInsets.None -- full-bleed, under the notch too
	made.SafeAreaCompatibility = Enum.SafeAreaCompatibility.None
	made.ClipToDeviceSafeArea = false
	made.ResetOnSpawn = false
	made.DisplayOrder = 5
	made.Enabled = false
	for i, x in { 0, 1 } do
		local img = Instance.new("ImageLabel")
		img.Name = if i == 1 then "Left" else "Right"
		img.BackgroundTransparency = 1
		img.Image = VFX.FLAME_SHEET_4x4
		img.ImageRectSize = Vector2.new(256, 256)
		img.ImageColor3 = BODY
		img.ImageTransparency = CORNER_ALPHA
		img.AnchorPoint = Vector2.new(x, 1)
		img.Position = UDim2.fromScale(x, 1)
		img.Size = UDim2.fromScale(CORNER_SIZE, CORNER_SIZE)
		local ratio = Instance.new("UIAspectRatioConstraint")
		ratio.AspectRatio = 1
		ratio.DominantAxis = Enum.DominantAxis.Height
		ratio.Parent = img
		img.Parent = made
		table.insert(corners, img)
	end
	made.Parent = player:WaitForChild("PlayerGui")
	cornerGui = made
	return corners
end

-- `model` is burning (`on`) or not; `own`: it is the local player's body,
-- which shows no flames on itself, only the screen corners.
function FireFx.setBurning(model: Model, root: BasePart, on: boolean, own: boolean)
	if own then
		ownBurning = on
		local b = burns[model]
		if b then
			b.licks.Rate = 0
			b.embers.Rate = 0
		end
		return
	end
	if not on and not burns[model] then
		return
	end
	local b = burnOf(model, root)
	b.licks.Rate = if on then BODY_LICK_RATE else 0
	b.embers.Rate = if on then BODY_EMBER_RATE else 0
end

-- Whether setBurning still has flames (or the corners) up for `model`.
function FireFx.tracked(model: Model, own: boolean): boolean
	if own then
		return ownBurning
	end
	local b = burns[model]
	return b ~= nil and (b.licks.Rate > 0 or b.embers.Rate > 0)
end

local function stepCorners(now: number)
	local gui = cornerGui
	if not ownBurning then
		if gui then
			gui.Enabled = false
		end
		return
	end
	local labels = cornerLabels()
	local g = cornerGui :: ScreenGui
	g.Enabled = true
	if now < nextCorner then
		return
	end
	nextCorner = now + 1 / CORNER_FPS
	cornerFrame = (cornerFrame + 1) % 16
	local offset = Vector2.new((cornerFrame % 4) * 256, math.floor(cornerFrame / 4) * 256)
	for _, img in labels do
		img.ImageRectOffset = offset
	end
end

-- Per frame -------------------------------------------------------------------------

function FireFx.step()
	local now = ReworkVfx.now()
	local s = ReworkVfx.timeScale()
	if s ~= appliedScale then
		appliedScale = s
		for e, base in baseScale do
			if e.Parent then
				e.TimeScale = base * s
			end
		end
	end
	local camera = Workspace.CurrentCamera
	local eye = if camera then camera.CFrame.Position else nil
	for i = #patches, 1, -1 do
		local p = patches[i]
		stepPatch(p, now, eye)
		if p.done then
			table.remove(patches, i)
		end
	end
	ReworkVfx.flush()
	stepCorners(now)
end

return FireFx
