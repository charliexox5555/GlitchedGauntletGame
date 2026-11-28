--!strict
-- Frostbite Legendary Knife (Season 1 battle pass Tier 30 melee, first person).
--
-- Features:
--   - Rest: sculpted dual icy edge Beams hugging the blade fuller & tip, gentle
--     crackle cryo spark glints, ambient sub-zero mist, crossguard PointLight,
--     and 2.4 s breathing cold shimmer on FBCoreHeart, FBKnifeGlow & FBKnifePommel.
--   - Draw: 12-segment 3D Cryo Halo ring sweeps crossguard -> tip with sparkle burst.
--   - Inspect: staggered 3-stage crystal eruption along the blade (FBGrowRear -> Mid
--     -> Front) with frosted white-crystal color shift, trailing 3D halo sweep,
--     ice-chip bursts, and apex burst + Grow/Settle return events for FrostbiteAudio.
--   - Swing & Heavy: dual icy cryo Trails (outer frost vapor + bright white edge)
--     flaring along the blade arc, plus hit flare/sparks on contact.
--   - Kill: ice-white flash -> radial 3D halo shockwave + tumbling ice chips +
--     FBShard1..4 fracture/spin/fade via LocalHide -> smooth refreeze back to rest.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalHide = require(script.Parent.LocalHide)
local SettingsApply = require(ReplicatedStorage.Shared.SettingsApply)
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local UiMotion = require(ReplicatedStorage.Shared.UiMotion)
local VFX = require(ReplicatedStorage.Shared.Config.VfxTextures)

local FrostbiteKnife = {}

export type Event = "Grow" | "Settle"

type Moving = {
	part: MeshPart,
	motor: Motor6D,
	baseColor: Color3,
}

type GrowItem = Moving & {
	from: number,
	to: number,
	offset: Vector3,
	triggered: boolean,
}

type ShardItem = Moving & {
	burst: Vector3,
	spin: Vector3,
}

type Emissive = {
	part: MeshPart,
	baseColor: Color3,
}

type HaloRing = {
	points: { Attachment },
	beams: { Beam },
	cores: { Beam },
}

export type State = {
	model: Model,
	body: BasePart,
	handle: BasePart,
	scale: number,
	grow: { GrowItem },
	shards: { ShardItem },
	emissives: { Emissive },
	owned: { Instance },
	halo: HaloRing?,
	edgeBeams: { Beam },
	trails: { Trail },
	guardLight: PointLight?,
	tipSparks: ParticleEmitter?,
	tipBurst: ParticleEmitter?,
	mist: ParticleEmitter?,
	chips: ParticleEmitter?,
	clock: number,
	surge: number,
	flare: number,
	drawSwelled: boolean,
	haloMode: "None" | "Draw" | "Inspect" | "KillShed" | "KillRegrow",
	haloAge: number,
	haloDur: number,
	killPhase: "None" | "Flash" | "Shed" | "Regrow",
	killElapsed: number,
	settled: boolean,
}

local ICE_WHITE = Color3.fromHex("ECFDFF")
local CRYO_CYAN = Color3.fromHex("8CE8FF")
local GLACIER_BLUE = Color3.fromHex("3FB8F0")
local DEEP_ICE = Color3.fromHex("16538A")
local RING_PTS = 12

-- Blender anchors for Knife_Frostbite_v02 (x=tip, y=left, z=up)
local GUARD_BL = Vector3.new(0.325, 0, -0.005)
local BLADE_BASE_BL = Vector3.new(0.365, 0, -0.015)
local BLADE_MID_BL = Vector3.new(0.760, 0, -0.012)
local BLADE_SPINE_BL = Vector3.new(0.960, 0, 0.044)
local BLADE_EDGE_BL = Vector3.new(0.800, 0, -0.072)
local BLADE_TIP_BL = Vector3.new(1.268, 0, -0.002)

local GROW_SPECS = {
	{
		part = "SK_Root_FBGrowRear",
		from = 0.12,
		to = 0.34,
		offset = Vector3.new(-0.024, -0.022, 0),
	},
	{ part = "SK_Root_FBGrowMid", from = 0.32, to = 0.54, offset = Vector3.new(-0.028, -0.025, 0) },
	{
		part = "SK_Root_FBGrowFront",
		from = 0.50,
		to = 0.72,
		offset = Vector3.new(-0.026, -0.022, 0),
	},
}

local SHARD_SPECS = {
	{
		part = "SK_Root_FBShard1",
		burst = Vector3.new(-0.045, 0.065, 0.22),
		spin = Vector3.new(1.5, 2.3, -1.1),
	},
	{
		part = "SK_Root_FBShard2",
		burst = Vector3.new(-0.075, 0.070, 0.24),
		spin = Vector3.new(-1.6, 2.0, 1.3),
	},
	{
		part = "SK_Root_FBShard3",
		burst = Vector3.new(-0.045, 0.065, -0.22),
		spin = Vector3.new(-1.5, -2.3, 1.1),
	},
	{
		part = "SK_Root_FBShard4",
		burst = Vector3.new(-0.075, 0.070, -0.24),
		spin = Vector3.new(1.6, -2.0, -1.3),
	},
}

local function bl(v: Vector3): Vector3
	return Vector3.new(-v.Y, v.Z, -v.X)
end

local function rootBody(model: Model): BasePart?
	local rig = model:FindFirstChild("Rig")
	local motors = rig and rig:FindFirstChild("Motors")
	local root = motors and motors:FindFirstChild("Root")
	if root and root:IsA("Motor6D") and root.Part1 then
		return root.Part1
	end
	return model.PrimaryPart
end

local function toBodyPos(handle: BasePart, body: BasePart, scale: number, blPos: Vector3): Vector3
	local world = handle.CFrame:PointToWorldSpace(bl(blPos) * scale)
	return body.CFrame:PointToObjectSpace(world)
end

local function makeAnchor(
	owned: { Instance },
	handle: BasePart,
	body: BasePart,
	scale: number,
	name: string,
	blPos: Vector3
): Attachment
	local a = Instance.new("Attachment")
	a.Name = name
	a.Position = toBodyPos(handle, body, scale, blPos)
	a.Parent = body
	table.insert(owned, a)
	return a
end

local function moving(model: Model, name: string): Moving?
	local part = model:FindFirstChild(name)
	if not part or not part:IsA("MeshPart") then
		return nil
	end
	local weld = part:FindFirstChild("SkinCosmeticWeld")
	if not weld or not weld:IsA("Weld") or not weld.Part0 or weld.Part1 ~= part then
		return nil
	end
	local motor = Instance.new("Motor6D")
	motor.Name = "FrostbiteMotion"
	motor.Part0 = weld.Part0
	motor.Part1 = part
	motor.C0 = weld.C0
	motor.C1 = weld.C1
	weld:Destroy()
	motor.Parent = part
	return { part = part, motor = motor, baseColor = part.Color }
end

local function easeOutBack(t: number): number
	local c1 = 1.70158
	local c3 = c1 + 1
	local u = t - 1
	return 1 + c3 * u * u * u + c1 * u * u
end

local function easeOutCubic(t: number): number
	local u = 1 - t
	return 1 - u * u * u
end

local function makeHalo(owned: { Instance }, body: BasePart, scale: number): HaloRing
	local halo: HaloRing = { points = {}, beams = {}, cores = {} }
	for i = 1, RING_PTS do
		local a = Instance.new("Attachment")
		a.Name = "FrostbiteKnifeHaloPt_" .. i
		a.Parent = body
		table.insert(owned, a)
		table.insert(halo.points, a)
	end
	local w = 0.036 * scale
	for i = 1, RING_PTS do
		local b = Instance.new("Beam")
		b.Name = "FrostbiteKnifeHaloBeam_" .. i
		b.Attachment0 = halo.points[i]
		b.Attachment1 = halo.points[i % RING_PTS + 1]
		b.Texture = VFX.FROST_VAPOR
		b.TextureMode = Enum.TextureMode.Wrap
		b.TextureLength = 0.34 * scale
		b.TextureSpeed = 3.8
		b.Color = ColorSequence.new(ICE_WHITE, GLACIER_BLUE)
		b.Transparency = NumberSequence.new(0.18)
		b.LightEmission = 1
		b.LightInfluence = 0
		b.Brightness = 2.1
		b.FaceCamera = true
		b.Width0 = w
		b.Width1 = w
		b.Segments = 3
		b.Enabled = false
		b.Parent = halo.points[i]
		table.insert(owned, b)
		table.insert(halo.beams, b)

		local c = b:Clone()
		c.Name = "FrostbiteKnifeHaloCore_" .. i
		c.Texture = ""
		c.Color = ColorSequence.new(ICE_WHITE)
		c.Width0 = w * 0.32
		c.Width1 = w * 0.32
		c.Transparency = NumberSequence.new(0.10)
		c.Parent = halo.points[i]
		table.insert(owned, c)
		table.insert(halo.cores, c)
	end
	return halo
end

local function poseHalo(
	halo: HaloRing,
	center: Vector3,
	axisU: Vector3,
	axisV: Vector3,
	radius: number,
	spin: number,
	alpha: number,
	width: number
)
	local on = alpha > 0.03
	local trans = math.clamp(1 - alpha * 0.90, 0.08, 1)
	for i = 1, RING_PTS do
		local ang = spin + (i - 1) * (2 * math.pi / RING_PTS)
		halo.points[i].Position = center + (axisU * math.cos(ang) + axisV * math.sin(ang)) * radius
	end
	for i = 1, RING_PTS do
		local b = halo.beams[i]
		local c = halo.cores[i]
		if b.Parent then
			b.Enabled = on
			c.Enabled = on
			if on then
				b.Transparency = NumberSequence.new(trans)
				c.Transparency = NumberSequence.new(math.min(1, trans + 0.08))
				b.Width0 = width
				b.Width1 = width
				c.Width0 = width * 0.32
				c.Width1 = width * 0.32
			end
		end
	end
end

local function hideHalo(halo: HaloRing?)
	if not halo then
		return
	end
	for i = 1, RING_PTS do
		if halo.beams[i].Parent then
			halo.beams[i].Enabled = false
			halo.cores[i].Enabled = false
		end
	end
end

function FrostbiteKnife.new(model: Model, scale: number): State?
	if StateValues.get(model, "SkinLine") ~= "Frostbite" then
		return nil
	end
	if StateValues.get(model, "WeaponId") ~= "Knife" then
		return nil
	end
	local handle = model.PrimaryPart
	local body = rootBody(model)
	if not handle or not body then
		return nil
	end

	local grow: { GrowItem } = {}
	for _, spec in GROW_SPECS do
		local m = moving(model, spec.part)
		if m then
			table.insert(grow, {
				part = m.part,
				motor = m.motor,
				baseColor = m.baseColor,
				from = spec.from,
				to = spec.to,
				offset = spec.offset,
				triggered = false,
			})
		end
	end

	local shards: { ShardItem } = {}
	for _, spec in SHARD_SPECS do
		local m = moving(model, spec.part)
		if m then
			table.insert(shards, {
				part = m.part,
				motor = m.motor,
				baseColor = m.baseColor,
				burst = spec.burst,
				spin = spec.spin,
			})
		end
	end

	local emissives: { Emissive } = {}
	for _, name in { "SK_Root_FBCoreHeart", "SK_Root_FBKnifeGlow", "SK_Root_FBKnifePommel" } do
		local part = model:FindFirstChild(name)
		if part and part:IsA("MeshPart") then
			table.insert(emissives, { part = part, baseColor = part.Color })
		end
	end

	local owned: { Instance } = {}
	local guardAt = makeAnchor(owned, handle, body, scale, "FrostbiteKnifeGuard", GUARD_BL)
	local light = Instance.new("PointLight")
	light.Name = "FrostbiteKnifeLight"
	light.Color = CRYO_CYAN
	light.Brightness = 0.48
	light.Range = 2.0 * scale
	light.Shadows = false
	light.Parent = guardAt
	table.insert(owned, light)

	local edgeBeams: { Beam } = {}
	local trails: { Trail } = {}
	local halo: HaloRing? = nil
	local tipSparks: ParticleEmitter? = nil
	local tipBurst: ParticleEmitter? = nil
	local mist: ParticleEmitter? = nil
	local chips: ParticleEmitter? = nil

	if not UiMotion.reduced() then
		halo = makeHalo(owned, body, scale)

		local e0 = makeAnchor(owned, handle, body, scale, "FBK_EdgeBase", BLADE_BASE_BL)
		local e1 = makeAnchor(owned, handle, body, scale, "FBK_EdgeMid", BLADE_EDGE_BL)
		local e2 = makeAnchor(owned, handle, body, scale, "FBK_EdgeTip", BLADE_TIP_BL)
		for idx, pair in { { e0, e1 }, { e1, e2 } } do
			local b = Instance.new("Beam")
			b.Name = "FrostbiteKnifeEdge_" .. idx
			b.Attachment0 = pair[1]
			b.Attachment1 = pair[2]
			b.Texture = VFX.FROST_VAPOR
			b.TextureMode = Enum.TextureMode.Wrap
			b.TextureLength = 0.45 * scale
			b.TextureSpeed = 2.8
			b.Color = ColorSequence.new(ICE_WHITE, GLACIER_BLUE)
			b.Transparency = NumberSequence.new(0.38)
			b.LightEmission = 1
			b.LightInfluence = 0
			b.Brightness = 1.9
			b.FaceCamera = true
			b.Width0 = (if idx == 1 then 0.030 else 0.026) * scale
			b.Width1 = (if idx == 1 then 0.026 else 0.010) * scale
			b.Segments = 4
			b.Parent = pair[1]
			table.insert(owned, b)
			table.insert(edgeBeams, b)
		end

		-- Dual swing cryo trails: outer vapor + inner frost edge
		local tBase = makeAnchor(owned, handle, body, scale, "FBK_TrailBase", BLADE_BASE_BL)
		local tTip = makeAnchor(owned, handle, body, scale, "FBK_TrailTip", BLADE_TIP_BL)
		local tSpine = makeAnchor(owned, handle, body, scale, "FBK_TrailSpine", BLADE_SPINE_BL)

		local outerTrail = Instance.new("Trail")
		outerTrail.Name = "FrostbiteKnifeBodyTrail"
		outerTrail.Attachment0 = tBase
		outerTrail.Attachment1 = tTip
		outerTrail.Texture = VFX.FROST_VAPOR
		outerTrail.TextureMode = Enum.TextureMode.Stretch
		outerTrail.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, ICE_WHITE),
			ColorSequenceKeypoint.new(0.45, CRYO_CYAN),
			ColorSequenceKeypoint.new(1, DEEP_ICE),
		})
		outerTrail.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.14),
			NumberSequenceKeypoint.new(0.6, 0.48),
			NumberSequenceKeypoint.new(1, 1),
		})
		outerTrail.LightEmission = 1
		outerTrail.LightInfluence = 0
		outerTrail.Brightness = 2.0
		outerTrail.Lifetime = 0.16
		outerTrail.MinLength = 0.025
		outerTrail.Enabled = false
		outerTrail.Parent = tTip
		table.insert(owned, outerTrail)
		table.insert(trails, outerTrail)

		local innerTrail = Instance.new("Trail")
		innerTrail.Name = "FrostbiteKnifeEdgeTrail"
		innerTrail.Attachment0 = tSpine
		innerTrail.Attachment1 = tTip
		innerTrail.Texture = VFX.TEMPEST_GLOW_BAND
		innerTrail.TextureMode = Enum.TextureMode.Stretch
		innerTrail.Color = ColorSequence.new(ICE_WHITE, CRYO_CYAN)
		innerTrail.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.05),
			NumberSequenceKeypoint.new(0.5, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		})
		innerTrail.LightEmission = 1
		innerTrail.LightInfluence = 0
		innerTrail.Brightness = 2.4
		innerTrail.Lifetime = 0.13
		innerTrail.MinLength = 0.02
		innerTrail.Enabled = false
		innerTrail.Parent = tTip
		table.insert(owned, innerTrail)
		table.insert(trails, innerTrail)

		local midAt = makeAnchor(owned, handle, body, scale, "FBK_BladeMid", BLADE_MID_BL)
		local sp = Instance.new("ParticleEmitter")
		sp.Name = "FrostbiteKnifeSparkles"
		sp.Texture = VFX.MOD_SPARKLE
		sp.Color = ColorSequence.new(ICE_WHITE, CRYO_CYAN)
		sp.LightEmission = 1
		sp.LightInfluence = 0
		sp.Brightness = 1.9
		sp.Lifetime = NumberRange.new(0.22, 0.42)
		sp.Speed = NumberRange.new(0.14 * scale, 0.38 * scale)
		sp.Drag = 3
		sp.SpreadAngle = Vector2.new(180, 180)
		sp.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.012 * scale),
			NumberSequenceKeypoint.new(0.45, 0.028 * scale),
			NumberSequenceKeypoint.new(1, 0),
		})
		sp.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.10),
			NumberSequenceKeypoint.new(0.7, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		})
		sp.Rate = SettingsApply.vfxCount(4)
		sp.LockedToPart = true
		sp.Parent = tTip
		tipSparks = sp
		table.insert(owned, sp)

		local bu = Instance.new("ParticleEmitter")
		bu.Name = "FrostbiteKnifeBurst"
		bu.Texture = VFX.FROST_BURST_2x2
		bu.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
		bu.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
		bu.Color = ColorSequence.new(ICE_WHITE, CRYO_CYAN)
		bu.LightEmission = 1
		bu.LightInfluence = 0
		bu.Brightness = 2.2
		bu.Lifetime = NumberRange.new(0.12, 0.20)
		bu.Speed = NumberRange.new(0.35 * scale, 1.15 * scale)
		bu.Drag = 6
		bu.SpreadAngle = Vector2.new(180, 180)
		bu.Size = NumberSequence.new(0.22 * scale)
		bu.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.05),
			NumberSequenceKeypoint.new(0.55, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		})
		bu.Rate = 0
		bu.Enabled = false
		bu.LockedToPart = true
		bu.Parent = tTip
		tipBurst = bu
		table.insert(owned, bu)

		local ms = Instance.new("ParticleEmitter")
		ms.Name = "FrostbiteKnifeMist"
		ms.Texture = VFX.FROST_MIST_2x2
		ms.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
		ms.FlipbookMode = Enum.ParticleFlipbookMode.Loop
		ms.Color = ColorSequence.new(CRYO_CYAN, GLACIER_BLUE)
		ms.LightEmission = 0.65
		ms.LightInfluence = 0.2
		ms.Lifetime = NumberRange.new(0.45, 0.75)
		ms.Speed = NumberRange.new(0.06 * scale, 0.16 * scale)
		ms.Acceleration = Vector3.new(0, -0.22 * scale, 0)
		ms.SpreadAngle = Vector2.new(180, 180)
		ms.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.07 * scale),
			NumberSequenceKeypoint.new(0.5, 0.14 * scale),
			NumberSequenceKeypoint.new(1, 0.18 * scale),
		})
		ms.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.90),
			NumberSequenceKeypoint.new(0.3, 0.72),
			NumberSequenceKeypoint.new(1, 1),
		})
		ms.Rate = SettingsApply.vfxCount(5)
		ms.LockedToPart = true
		ms.Parent = midAt
		mist = ms
		table.insert(owned, ms)

		local ch = Instance.new("ParticleEmitter")
		ch.Name = "FrostbiteKnifeChips"
		ch.Texture = VFX.T_CHIP
		ch.Color = ColorSequence.new(ICE_WHITE, GLACIER_BLUE)
		ch.LightEmission = 0.9
		ch.LightInfluence = 0
		ch.Lifetime = NumberRange.new(0.24, 0.42)
		ch.Speed = NumberRange.new(0.5 * scale, 1.5 * scale)
		ch.Drag = 4
		ch.SpreadAngle = Vector2.new(180, 180)
		ch.RotSpeed = NumberRange.new(-360, 360)
		ch.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.025 * scale),
			NumberSequenceKeypoint.new(0.6, 0.020 * scale),
			NumberSequenceKeypoint.new(1, 0),
		})
		ch.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.7, 0.25),
			NumberSequenceKeypoint.new(1, 1),
		})
		ch.Rate = 0
		ch.Enabled = false
		ch.LockedToPart = true
		ch.Parent = midAt
		chips = ch
		table.insert(owned, ch)
	end

	return {
		model = model,
		body = body,
		handle = handle,
		scale = scale,
		grow = grow,
		shards = shards,
		emissives = emissives,
		owned = owned,
		halo = halo,
		edgeBeams = edgeBeams,
		trails = trails,
		guardLight = light,
		tipSparks = tipSparks,
		tipBurst = tipBurst,
		mist = mist,
		chips = chips,
		clock = 0,
		surge = 0.6,
		flare = 0,
		drawSwelled = false,
		haloMode = "None",
		haloAge = 0,
		haloDur = 0.34,
		killPhase = "None",
		killElapsed = 0,
		settled = false,
	}
end

function FrostbiteKnife.hit(state: State)
	state.flare = 1.0
	state.surge = 1.0
	if not UiMotion.reduced() then
		if state.tipBurst then
			state.tipBurst:Emit(SettingsApply.vfxCount(3))
		end
		if state.chips then
			state.chips:Emit(SettingsApply.vfxCount(10))
		end
		if state.tipSparks then
			state.tipSparks:Emit(SettingsApply.vfxCount(8))
		end
	end
end

function FrostbiteKnife.onKill(state: State)
	state.killPhase = "Flash"
	state.killElapsed = 0
	state.haloMode = "KillShed"
	state.haloAge = 0
	state.haloDur = 0.36
	state.surge = 1.0
	state.flare = 1.0
	if not UiMotion.reduced() then
		if state.chips then
			state.chips:Emit(SettingsApply.vfxCount(20))
		end
		if state.tipBurst then
			state.tipBurst:Emit(SettingsApply.vfxCount(4))
		end
		if state.tipSparks then
			state.tipSparks:Emit(SettingsApply.vfxCount(12))
		end
	end
end

function FrostbiteKnife.step(
	state: State,
	dt: number,
	visible: boolean,
	drawProgress: number?,
	inspectProgress: number?,
	swingProgress: number?,
	swingHit: number?,
	heavy: boolean?
): (Event?, number?)
	state.clock += dt
	local t = state.clock
	local reduced = UiMotion.reduced()
	state.surge = math.max(0, state.surge - 2.8 * dt)
	state.flare = math.max(0, state.flare - 4.8 * dt)

	local scale = state.scale
	local event: Event? = nil
	local eventStage: number? = nil

	-- 1. Draw halo sweep
	if visible and drawProgress ~= nil then
		if not state.drawSwelled and drawProgress >= 0.08 then
			state.drawSwelled = true
			state.haloMode = "Draw"
			state.haloAge = 0
			state.haloDur = 0.36
			state.surge = 1.0
			if state.tipSparks and not reduced then
				state.tipSparks:Emit(SettingsApply.vfxCount(8))
			end
		end
	else
		state.drawSwelled = false
	end

	-- 2. Swing / Heavy lunge trails + surge
	local trailOn = false
	if visible and swingProgress ~= nil then
		local hAt = swingHit or 0.28
		local padFront = if heavy then 0.14 else 0.10
		local padBack = if heavy then 0.24 else 0.18
		if swingProgress >= hAt - padFront and swingProgress <= hAt + padBack then
			trailOn = true
			state.surge = math.max(state.surge, if heavy then 0.95 else 0.65)
		end
	end

	-- 3. Inspect staggered 3-stage crystal growth
	local inspectGlow = 0
	if visible and inspectProgress ~= nil then
		local allLocked = true
		for i, item in state.grow do
			local amount = 0
			if inspectProgress >= item.from and inspectProgress < 0.84 then
				if not item.triggered then
					item.triggered = true
					event, eventStage = "Grow", i
					if state.haloMode == "None" then
						state.haloMode = "Inspect"
						state.haloAge = 0
						state.haloDur = 0.38
					end
					if not reduced then
						if state.chips then
							state.chips:Emit(SettingsApply.vfxCount(6))
						end
						if state.tipSparks then
							state.tipSparks:Emit(SettingsApply.vfxCount(6))
						end
					end
				end
				local u = math.clamp((inspectProgress - item.from) / (item.to - item.from), 0, 1)
				amount = easeOutBack(u)
				if u < 1 then
					allLocked = false
				end
			elseif inspectProgress >= 0.84 then
				local rt = math.clamp((inspectProgress - 0.84) / 0.14, 0, 1)
				amount = 1 - easeOutCubic(rt)
				allLocked = false
			else
				allLocked = false
			end
			item.motor.Transform = CFrame.new(item.offset * (amount * scale))
			item.part.Color = item.baseColor:Lerp(ICE_WHITE, math.clamp(amount * 0.55, 0, 0.55))
			inspectGlow = math.max(inspectGlow, math.clamp(amount, 0, 1))
		end
		if allLocked and not state.settled then
			state.settled = true
			event = "Settle"
			if not reduced then
				if state.tipBurst then
					state.tipBurst:Emit(SettingsApply.vfxCount(2))
				end
				if state.tipSparks then
					state.tipSparks:Emit(SettingsApply.vfxCount(10))
				end
			end
		end
	else
		state.settled = false
		for _, item in state.grow do
			item.triggered = false
			item.motor.Transform = CFrame.identity
			item.part.Color = item.baseColor
		end
	end

	-- 4. Kill shatter + refreeze on FBShard1..4
	local killFlash = 0
	local killLift = 0
	if state.killPhase ~= "None" then
		state.killElapsed += dt
		if state.killPhase == "Flash" then
			local u = math.clamp(state.killElapsed / 0.07, 0, 1)
			killFlash = 1
			killLift = u
			for _, shard in state.shards do
				shard.motor.Transform = CFrame.new(shard.burst * (0.14 * u * scale))
				if visible then
					LocalHide.set(shard.part, 0)
				end
			end
			if state.killElapsed >= 0.07 then
				state.killPhase = "Shed"
				state.killElapsed = 0
			end
		elseif state.killPhase == "Shed" then
			local u = math.clamp(state.killElapsed / 0.42, 0, 1)
			local e = easeOutCubic(u)
			killFlash = 1 - u
			killLift = 1 - u * 0.65
			for _, shard in state.shards do
				shard.motor.Transform = CFrame.new(shard.burst * ((0.14 + 0.86 * e) * scale))
					* CFrame.Angles(shard.spin.X * e, shard.spin.Y * e, shard.spin.Z * e)
				if visible then
					LocalHide.set(shard.part, math.clamp(e, 0, 1))
				end
			end
			if state.killElapsed >= 0.42 then
				state.killPhase = "Regrow"
				state.killElapsed = 0
				state.haloMode = "KillRegrow"
				state.haloAge = 0
				state.haloDur = 0.55
			end
		else
			local u = math.clamp(state.killElapsed / 0.90, 0, 1)
			local e = easeOutCubic(u)
			killLift = 0.35 * (1 - e)
			for _, shard in state.shards do
				local sink = shard.burst.Unit * (-0.028 * (1 - e) * scale)
				shard.motor.Transform = CFrame.new(sink)
				if visible then
					LocalHide.set(shard.part, if e < 0.14 then 1 else 0)
				end
			end
			if state.killElapsed >= 0.90 then
				state.killPhase = "None"
				state.killElapsed = 0
				for _, shard in state.shards do
					shard.motor.Transform = CFrame.identity
					if visible then
						LocalHide.set(shard.part, 0)
					end
				end
			end
		end
	end

	if killLift > 0 and not (visible and inspectProgress) then
		for _, item in state.grow do
			item.motor.Transform = CFrame.new(item.offset * (0.30 * killLift * scale))
			item.part.Color = item.baseColor:Lerp(ICE_WHITE, 0.65 * killLift)
		end
	end

	-- 5. Emissive heart/fuller/pommel shimmer + Light + Edge beams
	local shimmer = 0.5 + 0.5 * math.sin(t * (math.pi * 2 / 2.4))
	local energy =
		math.clamp(state.surge * 0.65 + state.flare + inspectGlow * 0.55 + killFlash, 0, 1)
	for _, em in state.emissives do
		if em.part.Parent then
			em.part.Color = em.baseColor
				:Lerp(GLACIER_BLUE, 0.32 * (1 - shimmer))
				:Lerp(ICE_WHITE, math.clamp(shimmer * 0.35 + energy * 0.65, 0, 1))
		end
	end
	if state.guardLight and state.guardLight.Parent then
		state.guardLight.Enabled = visible
		state.guardLight.Brightness = 0.42 + 0.16 * shimmer + 0.95 * energy
		state.guardLight.Color = CRYO_CYAN:Lerp(ICE_WHITE, energy * 0.65)
	end
	for _, eb in state.edgeBeams do
		if eb.Parent then
			eb.Enabled = visible and not reduced
			if eb.Enabled then
				eb.Brightness = 1.6 + energy * 1.3
				eb.Transparency = NumberSequence.new(math.clamp(0.45 - energy * 0.30, 0.10, 0.85))
			end
		end
	end

	-- 6. 3D Cryo Halo ring sweeps (Draw, Inspect, Kill shockwave & refreeze)
	if state.halo and visible and not reduced and state.haloMode ~= "None" then
		state.haloAge += dt
		local u = state.haloAge / math.max(state.haloDur, 0.05)
		if u >= 1 then
			state.haloMode = "None"
			hideHalo(state.halo)
		else
			local guardP = toBodyPos(state.handle, state.body, scale, GUARD_BL)
			local tipP = toBodyPos(state.handle, state.body, scale, BLADE_TIP_BL)
			local upDir = (toBodyPos(
				state.handle,
				state.body,
				scale,
				GUARD_BL + Vector3.new(0, 0, 0.2)
			) - guardP).Unit
			local leftAxis = (toBodyPos(
				state.handle,
				state.body,
				scale,
				GUARD_BL + Vector3.new(0, 0.2, 0)
			) - guardP).Unit
			local pos = if state.haloMode == "KillShed"
				then guardP:Lerp(tipP, 0.35)
				elseif state.haloMode == "KillRegrow" then tipP:Lerp(guardP, u)
				else guardP:Lerp(tipP, u)
			local rad = if state.haloMode == "KillShed"
				then (0.10 + 0.42 * easeOutCubic(u)) * scale
				else (0.14 - 0.08 * u) * scale
			local alpha = math.sin(u * math.pi)
			poseHalo(state.halo, pos, leftAxis, upDir, rad, t * 7.5, alpha, 0.036 * scale)
		end
	else
		hideHalo(state.halo)
	end

	-- 7. Ambient emitters & Swing Trails
	if state.mist and state.mist.Parent then
		state.mist.Enabled = visible and not reduced
	end
	if state.tipSparks and state.tipSparks.Parent then
		state.tipSparks.Enabled = visible and not reduced
	end
	for _, tr in state.trails do
		if tr.Parent then
			tr.Enabled = visible and trailOn and not reduced
		end
	end

	return event, eventStage
end

function FrostbiteKnife.destroy(state: State)
	for _, inst in state.owned do
		pcall(function()
			if inst.Parent then
				inst:Destroy()
			end
		end)
	end
	table.clear(state.owned)
	table.clear(state.edgeBeams)
	table.clear(state.trails)
	state.halo = nil
	state.guardLight = nil
	state.tipSparks = nil
	state.tipBurst = nil
	state.mist = nil
	state.chips = nil
end

return FrostbiteKnife
