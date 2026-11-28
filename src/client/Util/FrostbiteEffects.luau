--!strict
-- Frostbite Legendary skin line: first-person viewmodel reactor & cryo VFX.
--   - Rest: sculpted dual flank frost-vapor Beam ribbons (outer vapor + crisp white
--     core), cryo fracture lightning arcs around the receiver bay, cascading sub-zero
--     mist, diamond snow sparkles, cold breath shimmer across FBCoreHeart/seams/magGlow,
--     and dual PointLights (all suppressed smoothly during ADS to keep sights razor-clean).
--   - Draw: 3D Cryo Halo ring sweeps stock -> muzzle + cryo mist & sparkle burst.
--   - Reload: vents frost vapor from magwell while mag is out; MagIn seat slams a 3D halo
--     sweep + frost burst down the barrel.
--   - Inspect: staggered 3-stage crystal eruption (Rear -> Mid -> Front) with crystal
--     white-frost paint, trailing 3D cryo halo, shard bursts, crackle arcs, and settle chime.
--   - Fire: travelling barrel cryo pulse ring + muzzle crown shard spray + core/seam wave.
--   - Kill: ice-white flash -> dramatic radial halo shockwave + 22 tumbling ice chips +
--     FBShard1..4 detach/spin/fade via LocalHide -> sweeping refreeze back to rest.
-- Everything is parented inside Rig.Motors.Root.Part1 / the camera clone and cleaned up
-- by FrostbiteEffects.destroy on unequip.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalHide = require(script.Parent.LocalHide)
local Profiles = require(ReplicatedStorage.Shared.Config.Frostbite)
local UiMotion = require(ReplicatedStorage.Shared.UiMotion)
local VFX = require(ReplicatedStorage.Shared.Config.VfxTextures)

local FrostbiteEffects = {}

type Pulse = "Fire" | "Seat"
export type Event = "Grow" | "Settle"

type Moving = {
	part: MeshPart,
	motor: Motor6D,
	baseColor: Color3,
}

type GrowItem = Moving & {
	spec: Profiles.GrowStage,
	triggered: boolean,
}

type ShardItem = Moving & {
	spec: Profiles.ShardSpec,
}

type Emissive = {
	part: MeshPart,
	baseColor: Color3,
}

type Ribbon = {
	beam: Beam,
	core: Beam,
	w0: number,
	w1: number,
	speed: number,
}

type ArcBeam = {
	beam: Beam,
	a0: Attachment,
	a1: Attachment,
	base0: Vector3,
	base1: Vector3,
	until_: number,
}

type HaloRing = {
	points: { Attachment },
	beams: { Beam },
	cores: { Beam },
}

type PulseState = {
	attach: Attachment,
	ring: ParticleEmitter,
	startPos: Vector3,
	endPos: Vector3,
	age: number,
	active: boolean,
}

export type State = {
	profile: Profiles.Profile,
	scale: number,
	body: BasePart,
	handle: BasePart,
	grow: { GrowItem },
	shards: { ShardItem },
	heart: Emissive?,
	seams: { Emissive },
	magGlow: Emissive?,
	owned: { Instance },
	ribbons: { Ribbon },
	arcs: { ArcBeam },
	halo: HaloRing?,
	coreLight: PointLight?,
	foreLight: PointLight?,
	mistCore: ParticleEmitter?,
	mistFore: ParticleEmitter?,
	magMist: ParticleEmitter?,
	sparkles: ParticleEmitter?,
	chips: ParticleEmitter?,
	burst: ParticleEmitter?,
	muzzlePop: ParticleEmitter?,
	pulse: PulseState?,
	clock: number,
	fireLeft: number,
	seatLeft: number,
	heat: number,
	reloading: boolean,
	reloadSeated: boolean,
	nextArcAt: number,
	haloMode: "None" | "Draw" | "Seat" | "Inspect" | "KillShed" | "KillRegrow",
	haloAge: number,
	haloDur: number,
	drawSwelled: boolean,
	killPhase: "None" | "Flash" | "Shed" | "Regrow",
	killElapsed: number,
	settled: boolean,
}

local ICE_WHITE = Color3.fromHex("ECFDFF")
local CRYO_CYAN = Color3.fromHex("8CE8FF")
local GLACIER_BLUE = Color3.fromHex("3FB8F0")
local DEEP_ICE = Color3.fromHex("16538A")
local RING_PTS = 12

-- Blender (x=muzzle, y=left, z=up) -> Roblox Handle space (-y, z, -x)
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

local function seq(points: { { number } }): NumberSequence
	local kps = {}
	for _, p in points do
		table.insert(kps, NumberSequenceKeypoint.new(p[1], p[2]))
	end
	return NumberSequence.new(kps)
end

local function makeEmitter(parent: Instance, name: string, texture: string): ParticleEmitter
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

local function emissive(model: Model, name: string?): Emissive?
	local part = if name then model:FindFirstChild(name) else nil
	if not part or not part:IsA("MeshPart") then
		return nil
	end
	return { part = part, baseColor = part.Color }
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
		a.Name = "FrostbiteHaloPt_" .. i
		a.Parent = body
		table.insert(owned, a)
		table.insert(halo.points, a)
	end
	local w = 0.046 * scale
	for i = 1, RING_PTS do
		local b = Instance.new("Beam")
		b.Name = "FrostbiteHaloBeam_" .. i
		b.Attachment0 = halo.points[i]
		b.Attachment1 = halo.points[i % RING_PTS + 1]
		b.Texture = VFX.FROST_VAPOR
		b.TextureMode = Enum.TextureMode.Wrap
		b.TextureLength = 0.42 * scale
		b.TextureSpeed = 3.6
		b.Color = ColorSequence.new(ICE_WHITE, GLACIER_BLUE)
		b.Transparency = NumberSequence.new(0.18)
		b.LightEmission = 1
		b.LightInfluence = 0
		b.Brightness = 2.0
		b.FaceCamera = true
		b.Width0 = w
		b.Width1 = w
		b.Segments = 3
		b.Enabled = false
		b.Parent = halo.points[i]
		table.insert(owned, b)
		table.insert(halo.beams, b)

		local c = b:Clone()
		c.Name = "FrostbiteHaloCore_" .. i
		c.Texture = ""
		c.Color = ColorSequence.new(ICE_WHITE)
		c.Width0 = w * 0.32
		c.Width1 = w * 0.32
		c.Transparency = NumberSequence.new(0.12)
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

function FrostbiteEffects.new(model: Model, scale: number, gunId: string): State?
	local profile = Profiles[gunId]
	if not profile then
		return nil
	end
	local handle = model.PrimaryPart
	local body = rootBody(model)
	if not handle or not body then
		return nil
	end

	local grow: { GrowItem } = {}
	for _, spec in profile.growStages do
		local m = moving(model, spec.part)
		if m then
			table.insert(grow, {
				part = m.part,
				motor = m.motor,
				baseColor = m.baseColor,
				spec = spec,
				triggered = false,
			})
		end
	end
	local shards: { ShardItem } = {}
	for _, spec in profile.shards do
		local m = moving(model, spec.part)
		if m then
			table.insert(shards, {
				part = m.part,
				motor = m.motor,
				baseColor = m.baseColor,
				spec = spec,
			})
		end
	end
	if #grow == 0 and #shards == 0 then
		return nil
	end

	local heart = emissive(model, profile.heart)
	local seams: { Emissive } = {}
	for _, name in profile.seams do
		local e = emissive(model, name)
		if e then
			table.insert(seams, e)
		end
	end
	local magGlow = emissive(model, profile.magGlow)

	local owned: { Instance } = {}
	local coreAt = makeAnchor(owned, handle, body, scale, "FrostbiteCoreAnchor", profile.core)
	local foreAt = makeAnchor(owned, handle, body, scale, "FrostbiteForeAnchor", profile.fore)
	local muzzleAt = makeAnchor(owned, handle, body, scale, "FrostbiteMuzzleAnchor", profile.muzzle)
	local magAt = makeAnchor(owned, handle, body, scale, "FrostbiteMagAnchor", profile.magWell)

	-- Volumetric flank cryo ribbons (Left & Right, scrolling vapor + white-ice core)
	local ribbons: { Ribbon } = {}
	for _, side in { 1, -1 } do
		for i, seg in profile.ribbons do
			local a0 = makeAnchor(
				owned,
				handle,
				body,
				scale,
				string.format("FrostbiteRibA_%d_%d", side, i),
				Vector3.new(seg.a.X, seg.a.Y * side, seg.a.Z)
			)
			local a1 = makeAnchor(
				owned,
				handle,
				body,
				scale,
				string.format("FrostbiteRibB_%d_%d", side, i),
				Vector3.new(seg.b.X, seg.b.Y * side, seg.b.Z)
			)
			local b = Instance.new("Beam")
			b.Name = string.format("FrostbiteRibbon_%d_%d", side, i)
			b.Attachment0 = a0
			b.Attachment1 = a1
			b.Texture = VFX.FROST_VAPOR
			b.TextureMode = Enum.TextureMode.Wrap
			b.TextureLength = 0.55 * scale
			b.TextureSpeed = 1.35
			b.Color = ColorSequence.new(ICE_WHITE, GLACIER_BLUE)
			b.Transparency = NumberSequence.new(0.42)
			b.LightEmission = 1
			b.LightInfluence = 0
			b.Brightness = 1.75
			b.FaceCamera = true
			b.Width0 = seg.w0 * scale
			b.Width1 = seg.w1 * scale
			b.Parent = a0
			table.insert(owned, b)

			local c = b:Clone()
			c.Name = string.format("FrostbiteRibbonCore_%d_%d", side, i)
			c.Texture = VFX.TEMPEST_GLOW_BAND
			c.TextureSpeed = 2.0
			c.Color = ColorSequence.new(ICE_WHITE, CRYO_CYAN)
			c.Brightness = 2.0
			c.Transparency = NumberSequence.new(0.50)
			c.Width0 = seg.w0 * 0.34 * scale
			c.Width1 = seg.w1 * 0.34 * scale
			c.Parent = a0
			table.insert(owned, c)

			table.insert(ribbons, {
				beam = b,
				core = c,
				w0 = seg.w0 * scale,
				w1 = seg.w1 * scale,
				speed = 1.35 + i * 0.25,
			})
		end
	end

	-- Cryo fracture lightning arcs
	local arcs: { ArcBeam } = {}
	for i, span in profile.arcs do
		local a0 = makeAnchor(owned, handle, body, scale, "FrostbiteArcA_" .. i, span[1])
		local a1 = makeAnchor(owned, handle, body, scale, "FrostbiteArcB_" .. i, span[2])
		local b = Instance.new("Beam")
		b.Name = "FrostbiteArc_" .. i
		b.Attachment0 = a0
		b.Attachment1 = a1
		b.Texture = VFX.STIM_BOLT
		b.TextureMode = Enum.TextureMode.Stretch
		b.Color = ColorSequence.new(ICE_WHITE, CRYO_CYAN)
		b.Transparency = NumberSequence.new(0.15)
		b.LightEmission = 1
		b.LightInfluence = 0
		b.Brightness = 2.1
		b.FaceCamera = true
		b.Width0 = 0.042 * scale
		b.Width1 = 0.028 * scale
		b.Segments = 6
		b.Enabled = false
		b.Parent = a0
		table.insert(owned, b)
		table.insert(arcs, {
			beam = b,
			a0 = a0,
			a1 = a1,
			base0 = a0.Position,
			base1 = a1.Position,
			until_ = 0,
		})
	end

	local halo = makeHalo(owned, body, scale)

	-- Dual PointLights (receiver core + fore-end bay)
	local coreLight = Instance.new("PointLight")
	coreLight.Name = "FrostbiteCoreLight"
	coreLight.Range = 2.6 * scale
	coreLight.Color = CRYO_CYAN
	coreLight.Brightness = 0.65
	coreLight.Shadows = false
	coreLight.Parent = coreAt
	table.insert(owned, coreLight)

	local foreLight = Instance.new("PointLight")
	foreLight.Name = "FrostbiteForeLight"
	foreLight.Range = 2.0 * scale
	foreLight.Color = GLACIER_BLUE
	foreLight.Brightness = 0.45
	foreLight.Shadows = false
	foreLight.Parent = foreAt
	table.insert(owned, foreLight)

	-- Sub-zero vapor mist (cascades gently downward at core & fore-end)
	local mistCore = makeEmitter(coreAt, "FrostbiteMistCore", VFX.FROST_MIST_2x2)
	mistCore.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
	mistCore.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	mistCore.Color = ColorSequence.new(CRYO_CYAN, DEEP_ICE)
	mistCore.LightEmission = 0.45
	mistCore.Brightness = 1.25
	mistCore.Size = seq({ { 0, 0.09 * scale }, { 0.45, 0.22 * scale }, { 1, 0.34 * scale } })
	mistCore.Transparency = seq({ { 0, 1 }, { 0.25, 0.56 }, { 0.7, 0.78 }, { 1, 1 } })
	mistCore.Lifetime = NumberRange.new(0.55, 0.90)
	mistCore.Rate = 5.5
	mistCore.Speed = NumberRange.new(0.14 * scale, 0.32 * scale)
	mistCore.SpreadAngle = Vector2.new(45, 45)
	mistCore.Acceleration = Vector3.new(0, -0.55 * scale, 0)
	mistCore.Rotation = NumberRange.new(0, 360)
	mistCore.RotSpeed = NumberRange.new(-40, 40)
	table.insert(owned, mistCore)

	local mistFore = makeEmitter(foreAt, "FrostbiteMistFore", VFX.FROST_MIST_2x2)
	mistFore.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
	mistFore.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	mistFore.Color = ColorSequence.new(ICE_WHITE, GLACIER_BLUE)
	mistFore.LightEmission = 0.40
	mistFore.Brightness = 1.15
	mistFore.Size = seq({ { 0, 0.07 * scale }, { 0.45, 0.18 * scale }, { 1, 0.28 * scale } })
	mistFore.Transparency = seq({ { 0, 1 }, { 0.25, 0.62 }, { 1, 1 } })
	mistFore.Lifetime = NumberRange.new(0.45, 0.80)
	mistFore.Rate = 4.0
	mistFore.Speed = NumberRange.new(0.12 * scale, 0.28 * scale)
	mistFore.SpreadAngle = Vector2.new(40, 40)
	mistFore.Acceleration = Vector3.new(0, -0.50 * scale, 0)
	mistFore.Rotation = NumberRange.new(0, 360)
	table.insert(owned, mistFore)

	-- Magwell frost vapor vent while magazine is out during reload
	local magMist = makeEmitter(magAt, "FrostbiteMagMist", VFX.FROST_MIST_2x2)
	magMist.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
	magMist.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	magMist.Color = ColorSequence.new(ICE_WHITE, GLACIER_BLUE)
	magMist.LightEmission = 0.55
	magMist.Brightness = 1.35
	magMist.Size = seq({ { 0, 0.08 * scale }, { 0.5, 0.20 * scale }, { 1, 0.30 * scale } })
	magMist.Transparency = seq({ { 0, 0.72 }, { 0.4, 0.50 }, { 1, 1 } })
	magMist.Lifetime = NumberRange.new(0.32, 0.55)
	magMist.Speed = NumberRange.new(0.25 * scale, 0.65 * scale)
	magMist.SpreadAngle = Vector2.new(60, 60)
	magMist.Acceleration = Vector3.new(0, -0.8 * scale, 0)
	magMist.Rotation = NumberRange.new(0, 360)
	table.insert(owned, magMist)

	-- Crisp 4-point diamond snow sparkles (replaces generic dots)
	local sparkles = makeEmitter(coreAt, "FrostbiteSparkles", VFX.MOD_SPARKLE)
	sparkles.Color = ColorSequence.new(ICE_WHITE, CRYO_CYAN)
	sparkles.Brightness = 1.9
	sparkles.Size = seq({ { 0, 0.012 * scale }, { 0.45, 0.048 * scale }, { 1, 0 } })
	sparkles.Transparency = seq({ { 0, 1 }, { 0.22, 0.16 }, { 1, 1 } })
	sparkles.Lifetime = NumberRange.new(0.45, 0.85)
	sparkles.Rate = 6.5
	sparkles.Speed = NumberRange.new(0.15 * scale, 0.42 * scale)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.RotSpeed = NumberRange.new(-90, 90)
	sparkles.Acceleration = Vector3.new(0, -0.35 * scale, 0)
	table.insert(owned, sparkles)

	-- Faceted ice chip burst emitter (inspect stages & kill explosion)
	local chips = makeEmitter(coreAt, "FrostbiteShards", VFX.T_CHIP)
	chips.Color = ColorSequence.new(ICE_WHITE, GLACIER_BLUE)
	chips.LightEmission = 0.7
	chips.LightInfluence = 0.25
	chips.Brightness = 1.8
	chips.Size = seq({ { 0, 0.082 * scale }, { 0.6, 0.056 * scale }, { 1, 0 } })
	chips.Transparency = seq({ { 0, 0.04 }, { 0.7, 0.26 }, { 1, 1 } })
	chips.Lifetime = NumberRange.new(0.32, 0.56)
	chips.Speed = NumberRange.new(1.1 * scale, 2.6 * scale)
	chips.SpreadAngle = Vector2.new(85, 85)
	chips.Rotation = NumberRange.new(-180, 180)
	chips.RotSpeed = NumberRange.new(-360, 360)
	chips.Acceleration = Vector3.new(0, -4.4 * scale, 0)
	table.insert(owned, chips)

	-- Icy shatter flash burst (kill flash, inspect apex, mag seat)
	local burst = makeEmitter(coreAt, "FrostbiteBurst", VFX.FROST_BURST_2x2)
	burst.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
	burst.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	burst.Color = ColorSequence.new(ICE_WHITE, GLACIER_BLUE)
	burst.Brightness = 1.95
	burst.Lifetime = NumberRange.new(0.14, 0.22)
	burst.Speed = NumberRange.new(0)
	burst.Rotation = NumberRange.new(0, 360)
	burst.Size = seq({ { 0, 0.14 * scale }, { 0.4, 0.42 * scale }, { 1, 0.08 * scale } })
	burst.Transparency = seq({ { 0, 0.04 }, { 0.55, 0.24 }, { 1, 1 } })
	table.insert(owned, burst)

	-- Muzzle crown shard pop when travelling pulse exits
	local muzzlePop = makeEmitter(muzzleAt, "FrostbiteMuzzlePop", VFX.FROST_SHARD)
	muzzlePop.Color = ColorSequence.new(ICE_WHITE, GLACIER_BLUE)
	muzzlePop.Brightness = 1.9
	muzzlePop.Lifetime = NumberRange.new(0.08, 0.15)
	muzzlePop.Speed = NumberRange.new(1.2 * scale, 2.4 * scale)
	muzzlePop.SpreadAngle = Vector2.new(42, 42)
	muzzlePop.Orientation = Enum.ParticleOrientation.VelocityParallel
	muzzlePop.Size = seq({ { 0, 0.068 * scale }, { 1, 0.015 * scale } })
	muzzlePop.Transparency = seq({ { 0, 0.05 }, { 1, 1 } })
	table.insert(owned, muzzlePop)

	-- Travelling barrel cryo pulse ring (core -> muzzle per shot)
	local pulseAt = makeAnchor(owned, handle, body, scale, "FrostbitePulseAnchor", profile.core)
	local pulseRing = makeEmitter(pulseAt, "FrostbitePulseRing", VFX.T_RING)
	pulseRing.Color = ColorSequence.new(ICE_WHITE, GLACIER_BLUE)
	pulseRing.Brightness = 1.85
	pulseRing.Lifetime = NumberRange.new(profile.pulseTime)
	pulseRing.Speed = NumberRange.new(0.01)
	pulseRing.Rotation = NumberRange.new(0, 360)
	pulseRing.Size = seq({ { 0, 0.11 * scale }, { 0.5, 0.20 * scale }, { 1, 0.07 * scale } })
	pulseRing.Transparency = seq({ { 0, 0.12 }, { 0.65, 0.36 }, { 1, 1 } })
	table.insert(owned, pulseRing)

	local pulse: PulseState = {
		attach = pulseAt,
		ring = pulseRing,
		startPos = toBodyPos(handle, body, scale, profile.core),
		endPos = toBodyPos(handle, body, scale, profile.muzzle),
		age = 0,
		active = false,
	}

	return {
		profile = profile,
		scale = scale,
		body = body,
		handle = handle,
		grow = grow,
		shards = shards,
		heart = heart,
		seams = seams,
		magGlow = magGlow,
		owned = owned,
		ribbons = ribbons,
		arcs = arcs,
		halo = halo,
		coreLight = coreLight,
		foreLight = foreLight,
		mistCore = mistCore,
		mistFore = mistFore,
		magMist = magMist,
		sparkles = sparkles,
		chips = chips,
		burst = burst,
		muzzlePop = muzzlePop,
		pulse = pulse,
		clock = 0,
		fireLeft = 0,
		seatLeft = 0,
		heat = 0,
		reloading = false,
		reloadSeated = false,
		nextArcAt = 0.4,
		haloMode = "None",
		haloAge = 0,
		haloDur = 0.35,
		drawSwelled = false,
		killPhase = "None",
		killElapsed = 0,
		settled = false,
	}
end

function FrostbiteEffects.pulse(state: State, kind: Pulse)
	if kind == "Fire" then
		state.fireLeft = state.profile.fireTime
		state.heat = math.min(1, state.heat + 0.38)
		if state.pulse and not UiMotion.reduced() then
			state.pulse.active = true
			state.pulse.age = 0
			state.pulse.attach.Position = state.pulse.startPos
			state.pulse.ring:Emit(1)
		end
		if state.muzzlePop and not UiMotion.reduced() then
			state.muzzlePop:Emit(3)
		end
	else
		state.seatLeft = state.profile.seatTime
		state.reloadSeated = true
		state.haloMode = "Seat"
		state.haloAge = 0
		state.haloDur = state.profile.haloSeatDur
		if state.burst and not UiMotion.reduced() then
			state.burst:Emit(1)
		end
		if state.sparkles and not UiMotion.reduced() then
			state.sparkles:Emit(8)
		end
	end
end

function FrostbiteEffects.onKill(state: State)
	state.killPhase = "Flash"
	state.killElapsed = 0
	state.haloMode = "KillShed"
	state.haloAge = 0
	state.haloDur = state.profile.killFlashTime + state.profile.killShedTime
	if not UiMotion.reduced() then
		if state.burst then
			state.burst:Emit(2)
		end
		if state.chips then
			state.chips:Emit(22)
		end
		if state.sparkles then
			state.sparkles:Emit(14)
		end
		if state.muzzlePop then
			state.muzzlePop:Emit(6)
		end
	end
end

function FrostbiteEffects.step(
	state: State,
	dt: number,
	inspect: number?,
	draw: number?,
	reload: number?,
	visible: boolean,
	adsAlpha: number
): (Event?, number?)
	local profile = state.profile
	local scale = state.scale
	state.clock += dt
	state.fireLeft = math.max(0, state.fireLeft - dt)
	state.seatLeft = math.max(0, state.seatLeft - dt)
	state.heat = math.max(0, state.heat - dt * 1.45)

	if not visible or not reload or reload < 0.14 then
		state.reloadSeated = false
	end
	local draining = visible and reload ~= nil and not state.reloadSeated
	state.reloading = draining

	local showFx = visible and adsAlpha < 0.25
	local adsFade = 1 - math.clamp(adsAlpha / 0.28, 0, 1)

	-- Draw sweep trigger
	if visible and draw then
		if not state.drawSwelled and draw >= 0.08 then
			state.drawSwelled = true
			state.haloMode = "Draw"
			state.haloAge = 0
			state.haloDur = profile.haloDrawDur
			if showFx and state.sparkles and not UiMotion.reduced() then
				state.sparkles:Emit(8)
			end
		end
	else
		state.drawSwelled = false
	end

	local event: Event? = nil
	local eventStage: number? = nil

	-- 1. Inspect: staggered 3-stage crystal eruption Rear -> Mid -> Front + frosted paint
	local inspectGlow = 0
	local inspectWaveX = 0
	if visible and inspect then
		local allLocked = true
		for i, item in state.grow do
			local spec = item.spec
			local amount = 0
			if inspect >= spec.from and inspect < profile.retractFrom then
				if not item.triggered then
					item.triggered = true
					event, eventStage = "Grow", i
					if showFx and not UiMotion.reduced() then
						if state.chips then
							state.chips:Emit(7)
						end
						if state.sparkles then
							state.sparkles:Emit(6)
						end
					end
				end
				local t = math.clamp((inspect - spec.from) / (spec.to - spec.from), 0, 1)
				amount = easeOutBack(t)
				if t < 1 then
					allLocked = false
				end
			elseif inspect >= profile.retractFrom then
				local rt = math.clamp(
					(inspect - profile.retractFrom) / (profile.retractTo - profile.retractFrom),
					0,
					1
				)
				amount = 1 - easeOutCubic(rt)
				allLocked = false
			else
				allLocked = false
			end
			item.motor.Transform = CFrame.new(spec.offset * (amount * scale))
			item.part.Color = item.baseColor:Lerp(ICE_WHITE, math.clamp(amount * 0.55, 0, 0.55))
			inspectGlow = math.max(inspectGlow, math.clamp(amount, 0, 1))
		end
		inspectWaveX = math.clamp((inspect - 0.12) / 0.62, 0, 1)
		if allLocked and not state.settled then
			state.settled = true
			event = "Settle"
			if showFx and not UiMotion.reduced() then
				if state.burst then
					state.burst:Emit(1)
				end
				if state.sparkles then
					state.sparkles:Emit(10)
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

	-- 2. Kill: flash -> crack/shed outward -> regrow/refreeze
	local killFlash = 0
	local killLift = 0
	if state.killPhase ~= "None" then
		state.killElapsed += dt
		if state.killPhase == "Flash" then
			local t = math.clamp(state.killElapsed / profile.killFlashTime, 0, 1)
			killFlash = 1
			killLift = t
			for _, shard in state.shards do
				shard.motor.Transform = CFrame.new(shard.spec.burst * (0.14 * t * scale))
				if visible then
					LocalHide.set(shard.part, 0)
				end
			end
			if state.killElapsed >= profile.killFlashTime then
				state.killPhase = "Shed"
				state.killElapsed = 0
			end
		elseif state.killPhase == "Shed" then
			local t = math.clamp(state.killElapsed / profile.killShedTime, 0, 1)
			local e = easeOutCubic(t)
			killFlash = 1 - t
			killLift = 1 - t * 0.65
			for _, shard in state.shards do
				local sp = shard.spec
				shard.motor.Transform = CFrame.new(sp.burst * ((0.14 + 0.86 * e) * scale))
					* CFrame.Angles(sp.spin.X * e, sp.spin.Y * e, sp.spin.Z * e)
				if visible then
					LocalHide.set(shard.part, math.clamp(e, 0, 1))
				end
			end
			if state.killElapsed >= profile.killShedTime then
				state.killPhase = "Regrow"
				state.killElapsed = 0
				state.haloMode = "KillRegrow"
				state.haloAge = 0
				state.haloDur = profile.killRegrowTime * 0.65
			end
		else
			local t = math.clamp(state.killElapsed / profile.killRegrowTime, 0, 1)
			local e = easeOutCubic(t)
			killLift = 0.35 * (1 - e)
			for _, shard in state.shards do
				local sink = shard.spec.burst.Unit * (-0.036 * (1 - e) * scale)
				shard.motor.Transform = CFrame.new(sink)
				if visible then
					LocalHide.set(shard.part, if e < 0.14 then 1 else 0)
				end
			end
			if state.killElapsed >= profile.killRegrowTime then
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

	-- Sympathetic crystal crest shudder during kill flash/shed when not inspecting
	if killLift > 0 and not (visible and inspect) then
		for _, item in state.grow do
			item.motor.Transform = CFrame.new(item.spec.offset * (0.28 * killLift * scale))
			item.part.Color = item.baseColor:Lerp(ICE_WHITE, 0.65 * killLift)
		end
	end

	-- 3. Travelling barrel cryo pulse ring
	if state.pulse and state.pulse.active then
		state.pulse.age += dt
		local t = math.clamp(state.pulse.age / profile.pulseTime, 0, 1)
		state.pulse.attach.Position = state.pulse.startPos:Lerp(state.pulse.endPos, t)
		if t >= 1 then
			state.pulse.active = false
		end
	end

	-- 4. Emissive heart / seams / magazine breathing & sequential wave
	local shimmer = 0.5 + 0.5 * math.sin(state.clock * (math.pi * 2 / profile.shimmerPeriod))
	local fireBoost = if state.fireLeft > 0 then state.fireLeft / profile.fireTime else 0
	local seatBoost = if state.seatLeft > 0 then state.seatLeft / profile.seatTime else 0
	local drainDim = if draining then 0.25 else 1
	local mixAmt = math.clamp(
		shimmer * 0.40 + inspectGlow * 0.50 + fireBoost * 0.72 + seatBoost * 0.68 + killFlash,
		0,
		1
	) * drainDim

	if state.heart then
		local base = state.heart.baseColor
		state.heart.part.Color = if draining
			then base:Lerp(DEEP_ICE, 0.7)
			else base:Lerp(GLACIER_BLUE, 0.35 * (1 - shimmer)):Lerp(ICE_WHITE, mixAmt * 0.85)
	end
	for i, seam in state.seams do
		local wave = if fireBoost > 0
			then math.clamp(
				1 - math.abs((1 - fireBoost) - (i - 1) / math.max(#state.seams, 1)) * 2.5,
				0,
				1
			)
			else 0
		local m = math.clamp(mixAmt + wave * 0.45, 0, 1)
		seam.part.Color = if draining
			then seam.baseColor:Lerp(DEEP_ICE, 0.72)
			else seam.baseColor
				:Lerp(GLACIER_BLUE, 0.42 * (1 - shimmer))
				:Lerp(ICE_WHITE, m * 0.78)
	end
	if state.magGlow then
		local magMix = math.clamp(shimmer * 0.35 + seatBoost * 0.90 + killFlash * 0.75, 0, 1)
			* drainDim
		state.magGlow.part.Color = state.magGlow.baseColor:Lerp(ICE_WHITE, magMix * 0.82)
	end

	-- 5. Volumetric flank frost ribbons (smooth fade in ADS, drain during reload)
	local ribAlpha = math.clamp(
		(0.55 + 0.15 * shimmer + 0.30 * (fireBoost + inspectGlow + seatBoost + killFlash))
			* drainDim
			* adsFade,
		0,
		1
	)
	local ribWidthMul = 0.85 + 0.35 * math.max(fireBoost, inspectGlow, killFlash)
	local ribOn = visible and ribAlpha > 0.04 and not UiMotion.reduced()
	for _, r in state.ribbons do
		if r.beam.Parent then
			r.beam.Enabled = ribOn
			r.core.Enabled = ribOn
			if ribOn then
				local t = math.clamp(1 - ribAlpha * 0.62, 0.18, 0.96)
				r.beam.Transparency = NumberSequence.new(t)
				r.core.Transparency = NumberSequence.new(math.clamp(t + 0.06, 0.22, 0.98))
				r.beam.Width0 = r.w0 * ribWidthMul
				r.beam.Width1 = r.w1 * ribWidthMul
				r.core.Width0 = r.w0 * 0.34 * ribWidthMul
				r.core.Width1 = r.w1 * 0.34 * ribWidthMul
				r.beam.TextureSpeed = r.speed * (1 + fireBoost * 1.4 + inspectGlow * 0.8)
			end
		end
	end

	-- 6. 3D Cryo Halo Ring (Draw sweep, MagIn seat slam, Inspect bloom wave, Kill shockwave & refreeze)
	if state.halo then
		local haloActive = showFx and not UiMotion.reduced()
		if
			haloActive and state.killPhase == "Flash" or (haloActive and state.killPhase == "Shed")
		then
			local dur = profile.killFlashTime + profile.killShedTime
			local t = math.clamp(
				(state.killElapsed + if state.killPhase == "Shed" then profile.killFlashTime else 0)
					/ dur,
				0,
				1
			)
			local e = easeOutCubic(t)
			local center = toBodyPos(state.handle, state.body, scale, profile.core)
			local axisU = state.body.CFrame:VectorToObjectSpace(state.handle.CFrame.UpVector)
			local axisV = state.body.CFrame:VectorToObjectSpace(state.handle.CFrame.RightVector)
			poseHalo(
				state.halo,
				center,
				axisU,
				axisV,
				(0.14 + 0.36 * e) * scale,
				state.clock * 8,
				(1 - e * 0.85),
				(0.068 - 0.030 * e) * scale
			)
		elseif haloActive and state.haloMode ~= "None" then
			state.haloAge += dt
			local t = math.clamp(state.haloAge / state.haloDur, 0, 1)
			local startPt = if state.haloMode == "Draw" then profile.stock else profile.core
			local endPt = profile.muzzle
			local pt = startPt:Lerp(endPt, easeOutCubic(t))
			local center = toBodyPos(state.handle, state.body, scale, pt)
			local axisU = state.body.CFrame:VectorToObjectSpace(state.handle.CFrame.UpVector)
			local axisV = state.body.CFrame:VectorToObjectSpace(state.handle.CFrame.RightVector)
			poseHalo(
				state.halo,
				center,
				axisU,
				axisV,
				0.135 * scale,
				state.clock * 6,
				math.sin(t * math.pi),
				0.048 * scale
			)
			if t >= 1 then
				state.haloMode = "None"
				hideHalo(state.halo)
			end
		elseif haloActive and inspect and inspect >= 0.12 and inspect < 0.82 then
			local pt = Vector3.new(0.20, 0, 0.28):Lerp(Vector3.new(1.75, 0, 0.34), inspectWaveX)
			local center = toBodyPos(state.handle, state.body, scale, pt)
			local axisU = state.body.CFrame:VectorToObjectSpace(state.handle.CFrame.UpVector)
			local axisV = state.body.CFrame:VectorToObjectSpace(state.handle.CFrame.RightVector)
			poseHalo(
				state.halo,
				center,
				axisU,
				axisV,
				(0.14 + 0.04 * math.sin(state.clock * 9)) * scale,
				state.clock * 5,
				0.72 * math.sin(math.clamp((inspect - 0.12) / 0.70, 0, 1) * math.pi),
				0.044 * scale
			)
		else
			hideHalo(state.halo)
		end
	end

	-- 7. Cryo fracture lightning arcs
	if showFx and not UiMotion.reduced() then
		local energetic = inspectGlow > 0.15 or killFlash > 0.1 or fireBoost > 0.1
		if state.clock >= state.nextArcAt then
			state.nextArcAt = state.clock
				+ if energetic then 0.08 + math.random() * 0.12 else 0.45 + math.random() * 0.75
			local arc = state.arcs[math.random(1, #state.arcs)]
			if arc then
				local j = 0.018 * scale
				arc.a0.Position = arc.base0
					+ Vector3.new(
						(math.random() - 0.5) * j,
						(math.random() - 0.5) * j,
						(math.random() - 0.5) * j
					)
				arc.a1.Position = arc.base1
					+ Vector3.new(
						(math.random() - 0.5) * j,
						(math.random() - 0.5) * j,
						(math.random() - 0.5) * j
					)
				arc.until_ = state.clock + (if energetic then 0.09 else 0.065)
			end
		end
		for _, arc in state.arcs do
			if arc.beam.Parent then
				arc.beam.Enabled = state.clock < arc.until_
			end
		end
	else
		for _, arc in state.arcs do
			if arc.beam.Parent then
				arc.beam.Enabled = false
			end
		end
	end

	-- 8. Lights & particle emitters (strictly off in ADS)
	local boost = math.max(fireBoost, inspectGlow, seatBoost, killFlash)
	if state.coreLight then
		state.coreLight.Enabled = showFx and not draining
		state.coreLight.Brightness = 0.45 + mixAmt * 1.15
	end
	if state.foreLight then
		state.foreLight.Enabled = showFx and not draining
		state.foreLight.Brightness = 0.25 + boost * 0.85
	end
	if state.mistCore then
		state.mistCore.Enabled = showFx
		state.mistCore.Rate = if draining then 2 else 5.5 + boost * 9
	end
	if state.mistFore then
		state.mistFore.Enabled = showFx
		state.mistFore.Rate = if draining then 1 else 4.0 + boost * 7
	end
	if state.magMist then
		state.magMist.Enabled = showFx and draining
		state.magMist.Rate = if draining then 18 else 0
	end
	if state.sparkles then
		state.sparkles.Enabled = showFx and not UiMotion.reduced()
		state.sparkles.Rate = 6.5 + boost * 12
	end

	return event, eventStage
end

function FrostbiteEffects.destroy(state: State)
	for _, inst in state.owned do
		pcall(inst.Destroy, inst)
	end
	table.clear(state.owned)
end

return FrostbiteEffects
