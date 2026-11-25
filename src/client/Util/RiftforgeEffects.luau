--!strict
-- Riftforge Legendary live first-person reactor engine (v02 final pass):
--
-- Drives all 7 articulated moving parts of Riftforge Phantom v02 + motion-synced VFX:
--   1. CoreCrystal   : spinning 16-face dark-matter prism; hovers elevated on Draw &
--                      LEVITATES +0.145 studs UP out of the open bay on Inspect!
--   2. CoreRingA/B   : dual counter-rotating gyroscopic containment rings (steel + bronze)
--   3. CowlLeft/Right: sculpted receiver armor shrouds that flare outward (yaw + roll + pop)
--                      on fire/reload/inspect and SLAM shut with mechanical spring rebound!
--   4. VentTop/Bottom: sleek aerodynamic suppressor shrouds pitching open under heat/reload/inspect
--   5. 3D Plasma Halo Ring (12-segment Beam loop):
--        - Sweeps down the entire barrel (core -> muzzle) on Draw SLAM, Reload SLAM & Inspect lock
--        - Opens as a spinning Magwell Plasma Portal Ring while forging the new cell (MagOut..MagIn)
--        - Orbits around the center of the rifle during Empty Reload's 360 spin & Inspect's 360 roll!
--   6. Motion-synced violet plasma Trails off muzzle & stock on Draw snap-twist, Empty Reload
--      360 spin, and Inspect 360 roll
--   7. Scrolling RiftforgePlasmaLayer surface textures + 12 volumetric flank Beam ribbons
--      (dynamic width swell on fire/surge, draining dark on MagOut, fading cleanly out in ADS)
--   8. 3 dynamic crackling lightning Beam arcs bridging the open cowls <-> levitating crystal
--   9. Per-shot travelling barrel plasma pulse ring + muzzle crown spark pop on ring exit!
--
-- All VFX Attachments live on Rig.Motors.Root.Part1 in Handle->Root space so recoil, reload,
-- draw, and inspect move every ring, ribbon, arc, emitter, and trail seamlessly with the gun!

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local SkinPreview = require(Shared.Config.SkinPreview)
local StateValues = require(Shared.StateValues)
local UiMotion = require(Shared.UiMotion)
local SettingsApply = require(Shared.SettingsApply)

local CFG = SkinPreview.RIFTFORGE
local RING_PTS = 12

type RibbonSeg = { a: Vector3, b: Vector3, w0: number, w1: number }
type GunProfile = {
	core: Vector3,
	cowlL: Vector3,
	cowlR: Vector3,
	ventTop: Vector3,
	ventBot: Vector3,
	muzzle: Vector3,
	magWell: Vector3,
	mid: Vector3,
	stockTail: Vector3,
	pulseStart: Vector3,
	customReload: boolean,
	levitateMul: number,
	ribbons: { RibbonSeg },
	arcs: { { Vector3 } },
}

local PROFILES: { [string]: GunProfile } = {
	Phantom = {
		core = CFG.CORE_BL,
		cowlL = CFG.COWL_L_BL,
		cowlR = CFG.COWL_R_BL,
		ventTop = CFG.VENT_TOP_BL,
		ventBot = CFG.VENT_BOT_BL,
		muzzle = CFG.MUZZLE_BL,
		magWell = CFG.MAG_WELL_BL,
		mid = Vector3.new(0.82, 0.0, 0.28),
		stockTail = Vector3.new(-1.06, 0.0, 0.37),
		pulseStart = Vector3.new(0.68, 0.0, 0.345),
		customReload = true,
		levitateMul = 1.0,
		ribbons = {
			{
				a = Vector3.new(0.45, 0.084, 0.300),
				b = Vector3.new(1.12, 0.078, 0.314),
				w0 = 1.05,
				w1 = 0.88,
			},
			{
				a = Vector3.new(1.12, 0.078, 0.314),
				b = Vector3.new(1.76, 0.070, 0.346),
				w0 = 0.88,
				w1 = 0.74,
			},
			{
				a = Vector3.new(1.76, 0.070, 0.346),
				b = Vector3.new(2.38, 0.060, 0.352),
				w0 = 0.74,
				w1 = 0.44,
			},
		},
		arcs = {
			{ Vector3.new(0.30, 0.088, 0.342), Vector3.new(0.455, 0.0, 0.296) },
			{ Vector3.new(0.61, -0.088, 0.342), Vector3.new(0.455, 0.0, 0.296) },
			{ Vector3.new(0.32, 0.078, 0.220), Vector3.new(0.59, -0.078, 0.370) },
		},
	},
	Operator = {
		core = Vector3.new(0.64, 0.0, 0.345),
		cowlL = Vector3.new(0.63, 0.095, 0.345),
		cowlR = Vector3.new(0.63, -0.095, 0.345),
		ventTop = Vector3.new(2.68, 0.0, 0.445),
		ventBot = Vector3.new(2.68, 0.0, 0.325),
		muzzle = Vector3.new(3.52, 0.0, 0.385),
		magWell = Vector3.new(0.64, 0.0, 0.04),
		mid = Vector3.new(1.10, 0.0, 0.34),
		stockTail = Vector3.new(-1.26, 0.0, 0.36),
		pulseStart = Vector3.new(1.05, 0.0, 0.385),
		customReload = true,
		levitateMul = 0.45,
		ribbons = {
			{
				a = Vector3.new(1.16, 0.086, 0.332),
				b = Vector3.new(2.16, 0.084, 0.332),
				w0 = 1.05,
				w1 = 0.90,
			},
			{
				a = Vector3.new(2.22, 0.060, 0.385),
				b = Vector3.new(3.26, 0.056, 0.385),
				w0 = 0.90,
				w1 = 0.65,
			},
		},
		arcs = {
			{ Vector3.new(0.44, 0.090, 0.395), Vector3.new(0.64, 0.0, 0.345) },
			{ Vector3.new(0.84, -0.090, 0.395), Vector3.new(0.64, 0.0, 0.345) },
			{ Vector3.new(0.45, 0.085, 0.275), Vector3.new(0.83, -0.085, 0.410) },
		},
	},
	Sheriff = {
		core = Vector3.new(0.473, 0.0, 0.1898),
		cowlL = Vector3.new(1.04, 0.072, 0.172),
		cowlR = Vector3.new(1.04, -0.072, 0.172),
		ventTop = Vector3.new(1.06, 0.0, 0.366),
		ventBot = Vector3.new(1.06, 0.0, 0.100),
		muzzle = Vector3.new(1.50, 0.0, 0.278),
		magWell = Vector3.new(0.473, 0.0, 0.1898),
		mid = Vector3.new(0.66, 0.0, 0.22),
		stockTail = Vector3.new(-0.08, 0.0, 0.24),
		pulseStart = Vector3.new(0.76, 0.0, 0.278),
		customReload = false,
		levitateMul = 0.0,
		ribbons = {
			{
				a = Vector3.new(0.78, 0.068, 0.254),
				b = Vector3.new(1.37, 0.064, 0.256),
				w0 = 0.85,
				w1 = 0.55,
			},
		},
		arcs = {
			{ Vector3.new(0.34, 0.105, 0.240), Vector3.new(0.473, 0.0, 0.1898) },
			{ Vector3.new(0.60, -0.105, 0.240), Vector3.new(0.473, 0.0, 0.1898) },
		},
	},
	Spectre = {
		core = Vector3.new(0.305, 0.0, 0.338),
		cowlL = Vector3.new(0.305, 0.088, 0.338),
		cowlR = Vector3.new(0.305, -0.088, 0.338),
		ventTop = Vector3.new(1.50, 0.0, 0.440),
		ventBot = Vector3.new(1.50, 0.0, 0.265),
		muzzle = Vector3.new(1.90, 0.0, 0.353),
		magWell = Vector3.new(0.56, 0.0, 0.04),
		mid = Vector3.new(0.58, 0.0, 0.32),
		stockTail = Vector3.new(-1.00, 0.0, 0.35),
		pulseStart = Vector3.new(0.74, 0.0, 0.353),
		customReload = true,
		levitateMul = 0.90,
		ribbons = {
			{
				a = Vector3.new(0.74, 0.084, 0.350),
				b = Vector3.new(1.08, 0.080, 0.352),
				w0 = 0.95,
				w1 = 0.82,
			},
			{
				a = Vector3.new(1.24, 0.078, 0.353),
				b = Vector3.new(1.77, 0.072, 0.353),
				w0 = 0.82,
				w1 = 0.52,
			},
		},
		arcs = {
			{ Vector3.new(0.14, 0.088, 0.390), Vector3.new(0.305, 0.0, 0.338) },
			{ Vector3.new(0.46, -0.088, 0.390), Vector3.new(0.305, 0.0, 0.338) },
			{ Vector3.new(0.16, 0.082, 0.265), Vector3.new(0.45, -0.082, 0.395) },
		},
	},
	Shorty = {
		core = Vector3.new(0.280, 0.0, 0.252),
		cowlL = Vector3.new(0.280, 0.096, 0.252),
		cowlR = Vector3.new(0.280, -0.096, 0.252),
		ventTop = Vector3.new(0.94, 0.0, 0.324),
		ventBot = Vector3.new(0.92, 0.0, 0.024),
		muzzle = Vector3.new(1.45, 0.0, 0.260),
		magWell = Vector3.new(0.55, 0.0, 0.240),
		mid = Vector3.new(0.62, 0.0, 0.22),
		stockTail = Vector3.new(-0.08, 0.0, 0.25),
		pulseStart = Vector3.new(0.64, 0.0, 0.260),
		customReload = false,
		levitateMul = 0.72,
		ribbons = {
			{
				a = Vector3.new(0.68, 0.096, 0.260),
				b = Vector3.new(1.31, 0.092, 0.260),
				w0 = 0.90,
				w1 = 0.62,
			},
		},
		arcs = {
			{ Vector3.new(0.14, 0.092, 0.302), Vector3.new(0.280, 0.0, 0.252) },
			{ Vector3.new(0.40, -0.092, 0.302), Vector3.new(0.280, 0.0, 0.252) },
		},
	},
}

type WeldEntry = {
	weld: Weld,
	restC0: CFrame,
	fromPivot: CFrame,
	pivotInPart0: CFrame,
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

type SweepState = {
	attach: Attachment,
	rings: ParticleEmitter,
	startPos: Vector3,
	endPos: Vector3,
	age: number,
	duration: number,
	active: boolean,
}

export type State = {
	model: Model,
	weaponId: string,
	profile: GunProfile,
	body: BasePart,
	handle: BasePart,
	scale: number,
	-- Articulated weld groups
	crystals: { WeldEntry },
	ringA: { WeldEntry },
	ringB: { WeldEntry },
	cowlLeft: { WeldEntry },
	cowlRight: { WeldEntry },
	ventTop: { WeldEntry },
	ventBot: { WeldEntry },
	-- Glowing Neon parts & scrolling plasma textures
	glowParts: { BasePart },
	plasmaTextures: { Texture },
	-- Volumetric VFX owned by this camera gun (cleaned via pcall on destroy)
	owned: { Instance },
	ribbons: { Ribbon },
	arcs: { ArcBeam },
	halo: HaloRing?,
	coreLight: PointLight?,
	coreSparks: ParticleEmitter?,
	coreArcs: ParticleEmitter?,
	muzzlePop: ParticleEmitter?,
	magBurst: ParticleEmitter?,
	magFormer: ParticleEmitter?,
	pulse: PulseState?,
	sweep: SweepState?,
	trails: { Trail },
	-- Live kinematics & state
	clock: number,
	crystalAngle: number,
	ringAAngle: number,
	ringBAngle: number,
	crystalVel: number,
	ringAVel: number,
	ringBVel: number,
	heat: number,
	surge: number,
	drain: number,
	cowlPos: number,
	cowlVel: number,
	ventPos: number,
	ventVel: number,
	levitate: number,
	nextArcAt: number,
	still: number,
	nextFlourish: number,
	flourishAge: number,
	-- Active reload / inspect / draw progress tracking
	reloading: boolean,
	reloadBursted: boolean,
	reloadSeated: boolean,
	reloadSlammed: boolean,
	drawSlammed: boolean,
	inspectSlammed: boolean,
	haloSweepAge: number, -- >= 0 while 3D halo ring races core -> muzzle!
	haloSweepDur: number,
	haloPopped: boolean,
}

local RiftforgeEffects = {}

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

local function makeAnchor(state: State, name: string, blPos: Vector3): Attachment
	local a = Instance.new("Attachment")
	a.Name = name
	a.Position = toBodyPos(state.handle, state.body, state.scale, blPos)
	a.Parent = state.body
	table.insert(state.owned, a)
	return a
end

local function makeEntry(weld: Weld, pivotInPart0: Vector3): WeldEntry
	local pivotCf = CFrame.new(pivotInPart0)
	return {
		weld = weld,
		restC0 = weld.C0,
		pivotInPart0 = pivotCf,
		fromPivot = pivotCf:Inverse() * weld.C0,
	}
end

local function applyPivot(list: { WeldEntry }, delta: CFrame)
	for _, e in list do
		if e.weld.Parent then
			e.weld.C0 = e.pivotInPart0 * delta * e.fromPivot
		end
	end
end

local function stepSpring(
	pos: number,
	vel: number,
	target: number,
	freq: number,
	damp: number,
	dt: number
): (number, number)
	local force = (target - pos) * freq * freq
	local accel = force - 2 * damp * freq * vel
	local newVel = vel + accel * dt
	local newPos = pos + newVel * dt
	return newPos, newVel
end

-- Build a 12-segment 3D Plasma Halo Ring (Beam loop around moving attachments).
local function makeHalo(state: State, width: number): HaloRing
	local halo: HaloRing = { points = {}, beams = {}, cores = {} }
	for i = 1, RING_PTS do
		local a = Instance.new("Attachment")
		a.Name = "RiftforgeHaloPt_" .. i
		a.Parent = state.body
		table.insert(state.owned, a)
		table.insert(halo.points, a)
	end
	for i = 1, RING_PTS do
		local b = Instance.new("Beam")
		b.Name = "RiftforgeHaloBeam_" .. i
		b.Attachment0 = halo.points[i]
		b.Attachment1 = halo.points[i % RING_PTS + 1]
		b.Texture = CFG.RIBBON_TEXTURE
		b.TextureMode = Enum.TextureMode.Wrap
		b.TextureLength = 0.45 * state.scale
		b.TextureSpeed = 4.2
		b.Color = ColorSequence.new(CFG.PLASMA_EDGE, CFG.PLASMA)
		b.Transparency = NumberSequence.new(0.15)
		b.LightEmission = 1
		b.LightInfluence = 0
		b.Brightness = 2.4
		b.FaceCamera = true
		b.Width0 = width
		b.Width1 = width
		b.Segments = 3
		b.Enabled = false
		b.Parent = halo.points[i]
		table.insert(state.owned, b)
		table.insert(halo.beams, b)

		local c = b:Clone()
		c.Name = "RiftforgeHaloCore_" .. i
		c.Texture = ""
		c.Color = ColorSequence.new(CFG.PLASMA_EDGE)
		c.Width0 = width * 0.34
		c.Width1 = width * 0.34
		c.Transparency = NumberSequence.new(0.10)
		c.Parent = halo.points[i]
		table.insert(state.owned, c)
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
	local trans = math.clamp(1 - alpha * 0.92, 0.06, 1)
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
				c.Width0 = width * 0.34
				c.Width1 = width * 0.34
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

-- Custom track selector (mirrors TempestIdle.track for ViewmodelController!)
function RiftforgeEffects.track(
	state: State?,
	kind: "draw" | "reload" | "reloadEmpty" | "inspect"
): string?
	if not state then
		return nil
	end
	if kind == "draw" then
		return "DrawRiftforge"
	elseif kind == "reload" then
		return if state.profile.customReload then "ReloadRiftforge" else nil
	elseif kind == "reloadEmpty" then
		return if state.profile.customReload then "ReloadEmptyRiftforge" else nil
	elseif kind == "inspect" then
		return "InspectRiftforge"
	end
	return nil
end

local function triggerSweep(state: State, duration: number)
	if UiMotion.reduced() then
		return
	end
	state.haloSweepAge = 0
	state.haloSweepDur = duration
	state.haloPopped = false
	if state.sweep then
		state.sweep.active = true
		state.sweep.age = 0
		state.sweep.duration = duration
		state.sweep.rings.Enabled = true
	end
end

local function triggerPulse(state: State)
	if not state.pulse or UiMotion.reduced() then
		return
	end
	state.pulse.active = true
	state.pulse.age = 0
	state.pulse.attach.Position = state.pulse.startPos
	state.pulse.ring:Emit(1)
end

function RiftforgeEffects.new(model: Model, scale: number): State?
	if StateValues.get(model, "SkinLine") ~= CFG.LINE then
		return nil
	end
	local handle = model.PrimaryPart
	local body = rootBody(model)
	if not handle or not body then
		return nil
	end
	local weaponId = StateValues.get(model, "WeaponId")
	local id = if typeof(weaponId) == "string" then weaponId else "Phantom"
	local profile = PROFILES[id] or PROFILES.Phantom

	local state: State = {
		model = model,
		weaponId = id,
		profile = profile,
		body = body,
		handle = handle,
		scale = scale,
		crystals = {},
		ringA = {},
		ringB = {},
		cowlLeft = {},
		cowlRight = {},
		ventTop = {},
		ventBot = {},
		glowParts = {},
		plasmaTextures = {},
		owned = {},
		ribbons = {},
		arcs = {},
		halo = nil,
		coreLight = nil,
		coreSparks = nil,
		coreArcs = nil,
		muzzlePop = nil,
		magBurst = nil,
		magFormer = nil,
		pulse = nil,
		sweep = nil,
		trails = {},
		clock = 0,
		crystalAngle = 0,
		ringAAngle = 0,
		ringBAngle = 0,
		crystalVel = CFG.CRYSTAL_IDLE_SPIN,
		ringAVel = CFG.RING_A_IDLE_SPIN,
		ringBVel = CFG.RING_B_IDLE_SPIN,
		heat = 0,
		surge = 0.75,
		drain = 0,
		cowlPos = 0.85, -- opens wide during Draw snap-twist, then SLAMS shut!
		cowlVel = 0,
		ventPos = 0.75,
		ventVel = 0,
		levitate = 0,
		nextArcAt = 0.5,
		still = 0,
		nextFlourish = CFG.FLOURISH_AFTER[1]
			+ math.random() * (CFG.FLOURISH_AFTER[2] - CFG.FLOURISH_AFTER[1]),
		flourishAge = -1,
		reloading = false,
		reloadBursted = false,
		reloadSeated = false,
		reloadSlammed = false,
		drawSlammed = false,
		inspectSlammed = false,
		haloSweepAge = -1,
		haloSweepDur = 0.28,
		haloPopped = false,
	}

	for _, desc in model:GetDescendants() do
		if
			desc:IsA("Texture")
			and (
				CollectionService:HasTag(desc, "RiftforgePlasmaLayer")
				or desc:GetAttribute("RiftforgePlasmaLayer")
			)
		then
			table.insert(state.plasmaTextures, desc)
		elseif desc:IsA("BasePart") then
			local name = desc.Name
			if desc.Material == Enum.Material.Neon and not name:find("Sight") then
				table.insert(state.glowParts, desc)
			end
			local weld = desc:FindFirstChild("SkinCosmeticWeld")
			if weld and weld:IsA("Weld") and weld.Part0 then
				local p0 = weld.Part0
				if name:find("CoreCrystal") then
					table.insert(
						state.crystals,
						makeEntry(weld, toBodyPos(handle, p0, scale, profile.core))
					)
				elseif name:find("CoreRingA") then
					table.insert(
						state.ringA,
						makeEntry(weld, toBodyPos(handle, p0, scale, profile.core))
					)
				elseif name:find("CoreRingB") then
					table.insert(
						state.ringB,
						makeEntry(weld, toBodyPos(handle, p0, scale, profile.core))
					)
				elseif name:find("CowlLeft") then
					table.insert(
						state.cowlLeft,
						makeEntry(weld, toBodyPos(handle, p0, scale, profile.cowlL))
					)
				elseif name:find("CowlRight") then
					table.insert(
						state.cowlRight,
						makeEntry(weld, toBodyPos(handle, p0, scale, profile.cowlR))
					)
				elseif name:find("VentTop") then
					table.insert(
						state.ventTop,
						makeEntry(weld, toBodyPos(handle, p0, scale, profile.ventTop))
					)
				elseif name:find("VentBottom") then
					table.insert(
						state.ventBot,
						makeEntry(weld, toBodyPos(handle, p0, scale, profile.ventBot))
					)
				end
			end
		end
	end

	-- 1. Core reactor attachment: violet PointLight + sparks + crackle arcs
	local coreAtt = makeAnchor(state, "RiftforgeCoreAtt", profile.core)
	local light = Instance.new("PointLight")
	light.Name = "RiftforgeCoreLight"
	light.Color = CFG.LIGHT_COLOR
	light.Brightness = CFG.LIGHT_IDLE
	light.Range = CFG.LIGHT_RANGE * scale
	light.Shadows = false
	light.Parent = coreAtt
	state.coreLight = light
	table.insert(state.owned, light)

	if not UiMotion.reduced() then
		-- 3D Plasma Halo Ring (Draw sweep, Reload magwell portal, 360 spin halo, Cowl SLAM wave!)
		state.halo = makeHalo(state, 0.055 * scale)

		-- Muzzle crown plasma pop when a barrel halo wave exits the crown!
		local crownAtt = makeAnchor(state, "RiftforgeCrownAtt", profile.muzzle)
		local pop = Instance.new("ParticleEmitter")
		pop.Name = "RiftforgeCrownPop"
		pop.Texture = CFG.SPARK_TEXTURE
		pop.Color = ColorSequence.new(CFG.PLASMA_EDGE, CFG.PLASMA)
		pop.LightEmission = 1
		pop.LightInfluence = 0
		pop.Brightness = 2.4
		pop.Lifetime = NumberRange.new(0.14, 0.24)
		pop.Speed = NumberRange.new(1.2 * scale, 2.8 * scale)
		pop.Drag = 7
		pop.SpreadAngle = Vector2.new(55, 55)
		pop.EmissionDirection = Enum.NormalId.Front
		pop.Orientation = Enum.ParticleOrientation.VelocityParallel
		pop.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.055 * scale),
			NumberSequenceKeypoint.new(1, 0.01 * scale),
		})
		pop.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.6, 0.25),
			NumberSequenceKeypoint.new(1, 1),
		})
		pop.Rate = 0
		pop.Enabled = false
		pop.LockedToPart = true
		pop.Parent = crownAtt
		state.muzzlePop = pop
		table.insert(state.owned, pop)

		-- Core plasma spark motes
		local sparks = Instance.new("ParticleEmitter")
		sparks.Name = "RiftforgeCoreSparks"
		sparks.Texture = CFG.SPARK_TEXTURE
		sparks.Color = ColorSequence.new(CFG.PLASMA_EDGE, CFG.PLASMA)
		sparks.LightEmission = 1
		sparks.LightInfluence = 0
		sparks.Brightness = 2.1
		sparks.Lifetime = NumberRange.new(0.22, 0.42)
		sparks.Speed = NumberRange.new(0.25 * scale, 0.65 * scale)
		sparks.Drag = 4.5
		sparks.SpreadAngle = Vector2.new(180, 180)
		sparks.Orientation = Enum.ParticleOrientation.VelocityParallel
		sparks.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.016 * scale),
			NumberSequenceKeypoint.new(0.4, 0.048 * scale),
			NumberSequenceKeypoint.new(1, 0),
		})
		sparks.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.05),
			NumberSequenceKeypoint.new(0.65, 0.25),
			NumberSequenceKeypoint.new(1, 1),
		})
		sparks.Rate = SettingsApply.vfxCount(5)
		sparks.LockedToPart = true
		sparks.Parent = coreAtt
		state.coreSparks = sparks
		table.insert(state.owned, sparks)

		-- Core electric crackle flipbook
		local coreArcs = Instance.new("ParticleEmitter")
		coreArcs.Name = "RiftforgeCoreArcs"
		coreArcs.Texture = CFG.ARC_TEXTURE
		coreArcs.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
		coreArcs.FlipbookMode = Enum.ParticleFlipbookMode.Random
		coreArcs.Color = ColorSequence.new(CFG.PLASMA_EDGE, CFG.PLASMA)
		coreArcs.LightEmission = 1
		coreArcs.LightInfluence = 0
		coreArcs.Brightness = 2.0
		coreArcs.Lifetime = NumberRange.new(0.08, 0.14)
		coreArcs.Speed = NumberRange.new(0)
		coreArcs.Rotation = NumberRange.new(0, 360)
		coreArcs.Size = NumberSequence.new(0.18 * scale)
		coreArcs.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.05),
			NumberSequenceKeypoint.new(0.5, 0.22),
			NumberSequenceKeypoint.new(1, 1),
		})
		coreArcs.Rate = SettingsApply.vfxCount(3)
		coreArcs.LockedToPart = true
		coreArcs.ZOffset = 0.04 * scale
		coreArcs.Parent = coreAtt
		state.coreArcs = coreArcs
		table.insert(state.owned, coreArcs)

		-- 2. Twin volumetric scrolling plasma Beam ribbons on BOTH flanks (Core -> Handguard -> Suppressor!)
		local ribbonW = CFG.RIBBON_WIDTH * scale
		local ribColors = ColorSequence.new({
			ColorSequenceKeypoint.new(0, CFG.PLASMA_EDGE),
			ColorSequenceKeypoint.new(0.45, CFG.PLASMA),
			ColorSequenceKeypoint.new(1, CFG.PLASMA_DEEP),
		})
		for _, ysgn in { 1, -1 } do
			for i, seg in profile.ribbons do
				local aPt = Vector3.new(seg.a.X, ysgn * seg.a.Y, seg.a.Z)
				local bPt = Vector3.new(seg.b.X, ysgn * seg.b.Y, seg.b.Z)
				local a0 = makeAnchor(state, string.format("RF_Rib_%d_%d_0", ysgn, i), aPt)
				local a1 = makeAnchor(state, string.format("RF_Rib_%d_%d_1", ysgn, i), bPt)
				local w0 = ribbonW * seg.w0
				local w1 = ribbonW * seg.w1
				local beam = Instance.new("Beam")
				beam.Name = "RiftforgePlasmaRibbon"
				beam.Attachment0 = a0
				beam.Attachment1 = a1
				beam.Texture = CFG.RIBBON_TEXTURE
				beam.TextureMode = Enum.TextureMode.Wrap
				beam.TextureLength = CFG.RIBBON_TILE * scale
				beam.TextureSpeed = CFG.RIBBON_SPEED
				beam.Color = ribColors
				beam.Transparency = NumberSequence.new(0.28)
				beam.LightEmission = 1
				beam.LightInfluence = 0
				beam.Brightness = CFG.RIBBON_BRIGHTNESS
				beam.FaceCamera = true
				beam.Width0 = w0
				beam.Width1 = w1
				beam.Segments = 4
				beam.Parent = a0
				table.insert(state.owned, beam)

				local core = beam:Clone()
				core.Name = "RiftforgePlasmaCore"
				core.Texture = ""
				core.Width0 = w0 * 0.34
				core.Width1 = w1 * 0.34
				core.Color = ColorSequence.new(CFG.PLASMA_EDGE, CFG.PLASMA)
				core.Transparency = NumberSequence.new(0.38)
				core.Parent = a0
				table.insert(state.owned, core)

				table.insert(state.ribbons, {
					beam = beam,
					core = core,
					w0 = w0,
					w1 = w1,
					speed = CFG.RIBBON_SPEED,
				})
			end
		end

		-- 3. Dynamic jagged reactor lightning Beams (snap across open cowls & levitating crystal!)
		for i, pair in profile.arcs do
			local a0 = makeAnchor(state, "RF_Arc0_" .. i, pair[1])
			local a1 = makeAnchor(state, "RF_Arc1_" .. i, pair[2])
			local b = Instance.new("Beam")
			b.Name = "RiftforgeLightning_" .. i
			b.Attachment0 = a0
			b.Attachment1 = a1
			b.Texture = CFG.BOLT_TEXTURE
			b.TextureMode = Enum.TextureMode.Stretch
			b.Color = ColorSequence.new(CFG.PLASMA_EDGE, CFG.PLASMA)
			b.LightEmission = 1
			b.LightInfluence = 0
			b.Brightness = 2.8
			b.FaceCamera = true
			b.Width0 = 0.052 * scale
			b.Width1 = 0.052 * scale
			b.Segments = 3
			b.Enabled = false
			b.Parent = a0
			table.insert(state.owned, b)
			table.insert(state.arcs, {
				beam = b,
				a0 = a0,
				a1 = a1,
				base0 = a0.Position,
				base1 = a1.Position,
				until_ = 0,
			})
		end

		-- 4. Per-shot travelling barrel plasma pulse ring (core -> muzzle)
		local pStart = toBodyPos(handle, body, scale, profile.pulseStart)
		local pEnd = toBodyPos(handle, body, scale, profile.muzzle)
		local pAtt = Instance.new("Attachment")
		pAtt.Name = "RiftforgeBarrelPulse"
		pAtt.Position = pStart
		pAtt.Parent = body
		table.insert(state.owned, pAtt)

		local pRing = Instance.new("ParticleEmitter")
		pRing.Name = "RiftforgePulseRing"
		pRing.Texture = CFG.PULSE_RING
		pRing.Color = ColorSequence.new(CFG.PLASMA_EDGE, CFG.PLASMA)
		pRing.LightEmission = 1
		pRing.LightInfluence = 0
		pRing.Brightness = CFG.PULSE_BRIGHTNESS * 1.15
		pRing.Lifetime = NumberRange.new(CFG.PULSE_TIME)
		pRing.Speed = NumberRange.new(0.01)
		pRing.EmissionDirection = Enum.NormalId.Front
		pRing.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		pRing.Rotation = NumberRange.new(0, 360)
		pRing.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.26 * scale),
			NumberSequenceKeypoint.new(0.6, 0.32 * scale),
			NumberSequenceKeypoint.new(1, 0.18 * scale),
		})
		pRing.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.04),
			NumberSequenceKeypoint.new(0.65, 0.22),
			NumberSequenceKeypoint.new(1, 1),
		})
		pRing.Rate = 0
		pRing.Enabled = false
		pRing.LockedToPart = true
		pRing.Parent = pAtt
		table.insert(state.owned, pRing)
		state.pulse = {
			attach = pAtt,
			ring = pRing,
			startPos = pStart,
			endPos = pEnd,
			age = 0,
			active = false,
		}

		-- 5. Sweeping plasma rings along full barrel (Draw lock, Reload cowl SLAM, Inspect lock!)
		local sStart = toBodyPos(handle, body, scale, profile.core)
		local sEnd = toBodyPos(handle, body, scale, profile.muzzle)
		local sAtt = Instance.new("Attachment")
		sAtt.Name = "RiftforgeBarrelSweep"
		sAtt.Position = sStart
		sAtt.Parent = body
		table.insert(state.owned, sAtt)

		local sRings = Instance.new("ParticleEmitter")
		sRings.Name = "RiftforgeSweepRings"
		sRings.Texture = CFG.SWEEP_RING
		sRings.Color = ColorSequence.new(CFG.PLASMA_EDGE, CFG.PLASMA)
		sRings.LightEmission = 1
		sRings.LightInfluence = 0
		sRings.Brightness = 2.1
		sRings.Lifetime = NumberRange.new(CFG.SWEEP_LIFE)
		sRings.Speed = NumberRange.new(0.01)
		sRings.EmissionDirection = Enum.NormalId.Front
		sRings.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		sRings.Rotation = NumberRange.new(0, 360)
		sRings.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.18 * scale),
			NumberSequenceKeypoint.new(0.45, 0.38 * scale),
			NumberSequenceKeypoint.new(1, 0.24 * scale),
		})
		sRings.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.10),
			NumberSequenceKeypoint.new(0.5, 0.30),
			NumberSequenceKeypoint.new(1, 1),
		})
		sRings.Rate = SettingsApply.vfxCount(CFG.SWEEP_RATE)
		sRings.Enabled = false
		sRings.LockedToPart = true
		sRings.Parent = sAtt
		table.insert(state.owned, sRings)
		state.sweep = {
			attach = sAtt,
			rings = sRings,
			startPos = sStart,
			endPos = sEnd,
			age = 0,
			duration = 0.28,
			active = false,
		}

		-- 6. Reload MagWell discharge burst + converging plasma beads forming the fresh energy cell!
		local magAtt = makeAnchor(state, "RiftforgeMagWellAtt", profile.magWell)
		local magBurst = Instance.new("ParticleEmitter")
		magBurst.Name = "RiftforgeMagBurst"
		magBurst.Texture = CFG.ARC_TEXTURE
		magBurst.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
		magBurst.FlipbookMode = Enum.ParticleFlipbookMode.Random
		magBurst.Color = ColorSequence.new(CFG.PLASMA_EDGE, CFG.PLASMA)
		magBurst.LightEmission = 1
		magBurst.LightInfluence = 0
		magBurst.Brightness = 2.3
		magBurst.Lifetime = NumberRange.new(0.15, 0.26)
		magBurst.Speed = NumberRange.new(0.9 * scale, 2.5 * scale)
		magBurst.Drag = 6
		magBurst.SpreadAngle = Vector2.new(180, 180)
		magBurst.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.22 * scale),
			NumberSequenceKeypoint.new(1, 0.05 * scale),
		})
		magBurst.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.55, 0.22),
			NumberSequenceKeypoint.new(1, 1),
		})
		magBurst.Rate = 0
		magBurst.Enabled = false
		magBurst.LockedToPart = true
		magBurst.Parent = magAtt
		state.magBurst = magBurst
		table.insert(state.owned, magBurst)

		-- Converging violet plasma energy beads pulling inward to form the new cell
		local former = Instance.new("ParticleEmitter")
		former.Name = "RiftforgeMagFormer"
		former.Texture = CFG.SPARK_TEXTURE
		former.Color = ColorSequence.new(CFG.PLASMA_EDGE, CFG.PLASMA)
		former.LightEmission = 1
		former.LightInfluence = 0
		former.Brightness = 2.1
		former.Lifetime = NumberRange.new(0.24, 0.34)
		former.Speed = NumberRange.new(-1.45 * scale, -0.90 * scale)
		former.SpreadAngle = Vector2.new(180, 180)
		former.Shape = Enum.ParticleEmitterShape.Sphere
		former.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
		former.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		former.Orientation = Enum.ParticleOrientation.VelocityParallel
		former.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.022 * scale),
			NumberSequenceKeypoint.new(0.5, 0.064 * scale),
			NumberSequenceKeypoint.new(1, 0.010 * scale),
		})
		former.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.55),
			NumberSequenceKeypoint.new(0.35, 0.04),
			NumberSequenceKeypoint.new(1, 1),
		})
		former.Rate = SettingsApply.vfxCount(CFG.FORM_RATE)
		former.Enabled = false
		former.LockedToPart = true
		former.Parent = magAtt
		state.magFormer = former
		table.insert(state.owned, former)

		-- 7. Motion-synced plasma trails off muzzle & buttstock (Draw snap-twist, Empty Reload spin, Inspect roll!)
		local mz = profile.muzzle
		local st = profile.stockTail
		for idx, pair in
			{
				{ mz + Vector3.new(0, 0, 0.05), mz + Vector3.new(0, 0, -0.05) },
				{ st + Vector3.new(0, 0, 0.05), st + Vector3.new(0, 0, -0.05) },
			}
		do
			local t0 = makeAnchor(state, "RF_Trail0_" .. idx, pair[1])
			local t1 = makeAnchor(state, "RF_Trail1_" .. idx, pair[2])
			local tr = Instance.new("Trail")
			tr.Name = "RiftforgeRollTrail_" .. idx
			tr.Attachment0 = t0
			tr.Attachment1 = t1
			tr.Texture = CFG.RIBBON_TEXTURE
			tr.TextureMode = Enum.TextureMode.Stretch
			tr.Color = ColorSequence.new(CFG.PLASMA_EDGE, CFG.PLASMA)
			tr.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.10),
				NumberSequenceKeypoint.new(0.55, 0.40),
				NumberSequenceKeypoint.new(1, 1),
			})
			tr.LightEmission = 1
			tr.LightInfluence = 0
			tr.Brightness = 2.2
			tr.Lifetime = CFG.TRAIL_LIFE
			tr.MinLength = 0.035
			tr.FaceCamera = true
			tr.Enabled = false
			tr.Parent = t0
			table.insert(state.owned, tr)
			table.insert(state.trails, tr)
		end
	end

	return state
end

function RiftforgeEffects.fire(state: State)
	state.crystalVel = math.min(state.crystalVel + CFG.CRYSTAL_FIRE_SPIN, 24)
	state.ringAVel = math.max(state.ringAVel + CFG.RING_A_FIRE_SPIN, -18)
	state.ringBVel = math.min(state.ringBVel + CFG.RING_B_FIRE_SPIN, 22)
	state.heat = math.min(1, state.heat + CFG.HEAT_PER_SHOT)
	state.surge = 1.0
	state.still = 0
	state.cowlVel += 4.5
	state.ventVel += 4.0
	triggerPulse(state)
	if state.coreSparks and not UiMotion.reduced() then
		state.coreSparks:Emit(SettingsApply.vfxCount(6))
	end
	if state.coreArcs and not UiMotion.reduced() then
		state.coreArcs:Emit(SettingsApply.vfxCount(2))
	end
	if #state.arcs > 0 and not UiMotion.reduced() then
		local a = state.arcs[math.random(1, #state.arcs)]
		a.until_ = state.clock + 0.085
	end
end

function RiftforgeEffects.pulse(
	state: State,
	kind: "Fire" | "Draw" | "Inspect" | "Seat" | "CowlSlam"
)
	if kind == "Fire" then
		RiftforgeEffects.fire(state)
		return
	end
	state.still = 0
	if kind == "Draw" then
		state.surge = 0.95
		state.drawSlammed = false
		state.cowlPos = 0.90
		state.ventPos = 0.80
		state.crystalVel = 12.0
		state.ringAVel = -10.5
		state.ringBVel = 14.0
		if state.coreArcs and not UiMotion.reduced() then
			state.coreArcs:Emit(SettingsApply.vfxCount(3))
		end
	elseif kind == "Inspect" then
		state.surge = 0.95
		state.inspectSlammed = false
		state.crystalVel = CFG.CRYSTAL_INSPECT_SPIN
		state.ringAVel = -10.0
		state.ringBVel = 14.0
		if state.coreSparks and not UiMotion.reduced() then
			state.coreSparks:Emit(SettingsApply.vfxCount(8))
		end
	elseif kind == "Seat" then
		state.surge = 1.0
		state.drain = 0
		state.crystalVel = 14.5
		state.ringAVel = -11.5
		state.ringBVel = 15.5
		if state.magBurst and not UiMotion.reduced() then
			state.magBurst:Emit(SettingsApply.vfxCount(10))
		end
		if state.coreSparks and not UiMotion.reduced() then
			state.coreSparks:Emit(SettingsApply.vfxCount(9))
		end
	elseif kind == "CowlSlam" then
		state.surge = 1.0
		state.cowlVel = -17.5 -- violent SLAM shut!
		state.ventVel = -15.0
		triggerSweep(state, 0.25)
		if state.coreArcs and not UiMotion.reduced() then
			state.coreArcs:Emit(SettingsApply.vfxCount(4))
		end
		for _, a in state.arcs do
			a.until_ = state.clock + 0.11
		end
	end
end

-- Reload plasma energy-cell choreography:
-- Returns true while the old mag should stay hidden (discharged into plasma -> forming new cell!).
function RiftforgeEffects.reload(
	state: State,
	t: number,
	outAt: number,
	inAt: number,
	rackAt: number
): boolean
	state.reloading = true
	state.still = 0
	if t >= outAt and not state.reloadBursted then
		state.reloadBursted = true
		state.drain = 1.0
		state.cowlVel += 12.5 -- blow armor cowls wide open!
		state.ventVel += 11.0
		if state.magBurst and not UiMotion.reduced() then
			state.magBurst:Emit(SettingsApply.vfxCount(11))
		end
		if state.coreArcs and not UiMotion.reduced() then
			state.coreArcs:Emit(SettingsApply.vfxCount(3))
		end
	end
	local forming = t >= outAt + 0.03 and t < inAt
	if state.magFormer then
		state.magFormer.Enabled = forming and not UiMotion.reduced()
	end
	if t >= inAt and not state.reloadSeated then
		state.reloadSeated = true
		RiftforgeEffects.pulse(state, "Seat")
	end
	if t >= rackAt and not state.reloadSlammed then
		state.reloadSlammed = true
		RiftforgeEffects.pulse(state, "CowlSlam")
	end
	return t >= outAt and t < inAt
end

function RiftforgeEffects.endReload(state: State)
	state.reloading = false
	state.reloadBursted = false
	state.reloadSeated = false
	state.reloadSlammed = false
	state.drain = 0
	if state.magFormer then
		state.magFormer.Enabled = false
	end
end

function RiftforgeEffects.step(
	state: State,
	dt: number,
	drawProgress: number?,
	reloadProgress: number?,
	inspectProgress: number?,
	adsAlpha: number,
	reloadEmpty: boolean?
)
	state.clock += dt
	local t = state.clock
	local reduced = UiMotion.reduced()

	local drag = math.exp(-CFG.SPIN_DRAG * dt)
	state.crystalVel = CFG.CRYSTAL_IDLE_SPIN + (state.crystalVel - CFG.CRYSTAL_IDLE_SPIN) * drag
	state.ringAVel = CFG.RING_A_IDLE_SPIN + (state.ringAVel - CFG.RING_A_IDLE_SPIN) * drag
	state.ringBVel = CFG.RING_B_IDLE_SPIN + (state.ringBVel - CFG.RING_B_IDLE_SPIN) * drag
	state.heat = math.max(0, state.heat - CFG.HEAT_COOL * dt)
	state.surge = math.max(0, state.surge - CFG.SURGE_DECAY * dt)
	if not state.reloading then
		state.drain = math.max(0, state.drain - 4.5 * dt)
	end

	local cowlTarget = state.heat * 0.62
	local ventTarget = state.heat * 0.68
	local levTarget = 0
	local trailOn = false

	-- 1. DRAW SNAP-TWIST CHOREOGRAPHY:
	--    0.00..0.34: violet plasma trails streak off muzzle & stock during 135-deg snap-twist!
	--    0.08..0.41: cowls stay wide open & CoreCrystal hovers elevated (+0.45) flashing the core!
	--    0.42: VIOLENT COWL SLAM launching 3D Plasma Halo Ring down the full barrel!
	if drawProgress ~= nil then
		state.still = 0
		if drawProgress < 0.34 then
			trailOn = true
		end
		if drawProgress < 0.41 then
			cowlTarget = 0.92
			ventTarget = 0.80
			levTarget = 0.42
		elseif not state.drawSlammed then
			state.drawSlammed = true
			RiftforgeEffects.pulse(state, "CowlSlam")
		end
	else
		state.drawSlammed = false
	end

	-- 2. RELOAD / RELOAD-EMPTY CHOREOGRAPHY:
	--    0.12..0.74: cowls & vents split wide open
	--    Empty reload 0.52..0.74: blazing plasma trails + spinning 3D halo ring around rifle!
	local reloadForming = false
	local reloadSpinning = false
	if reloadProgress ~= nil then
		state.still = 0
		if reloadProgress > 0.12 and reloadProgress < 0.74 then
			cowlTarget = 1.0
			ventTarget = 1.0
			state.crystalVel = math.max(state.crystalVel, 10.5)
			state.ringAVel = math.min(state.ringAVel, -9.0)
			state.ringBVel = math.max(state.ringBVel, 13.0)
		end
		if reloadProgress >= 0.17 and reloadProgress < 0.46 then
			reloadForming = true
		end
		if reloadEmpty and reloadProgress >= 0.52 and reloadProgress <= 0.75 then
			reloadSpinning = true
			trailOn = true
		end
	end

	-- 3. INSPECT CHOREOGRAPHY:
	--    0.14..0.80: cowls wide, CoreCrystal LEVITATES +0.145 UP out of chassis!
	--    0.44..0.64: 360-deg magnetic roll with plasma trails & orbiting 3D plasma halo ring!
	local inspectSpinning = false
	if inspectProgress ~= nil then
		state.still = 0
		if inspectProgress > 0.14 and inspectProgress < 0.80 then
			cowlTarget = 1.0
			ventTarget = 0.95
			state.crystalVel = math.max(state.crystalVel, CFG.CRYSTAL_INSPECT_SPIN)
			state.ringAVel = math.min(state.ringAVel, -10.5)
			state.ringBVel = math.max(state.ringBVel, 15.0)
			if inspectProgress > 0.20 and inspectProgress < 0.74 then
				levTarget = 1.0
			end
		elseif inspectProgress >= 0.80 and not state.inspectSlammed then
			state.inspectSlammed = true
			RiftforgeEffects.pulse(state, "CowlSlam")
		end
		if inspectProgress >= 0.44 and inspectProgress <= 0.64 then
			inspectSpinning = true
			trailOn = true
		end
	else
		state.inspectSlammed = false
	end

	-- 4. Living-machine subtle idle flourish when standing still!
	if
		drawProgress == nil
		and reloadProgress == nil
		and inspectProgress == nil
		and adsAlpha < 0.15
		and state.heat < 0.05
	then
		state.still += dt
		if state.still >= state.nextFlourish and state.flourishAge < 0 then
			state.flourishAge = 0
			state.crystalVel += 8.0
			state.ringAVel -= 7.0
			state.ringBVel += 10.0
			state.surge = math.max(state.surge, 0.6)
			if #state.arcs > 0 and not reduced then
				state.arcs[math.random(1, #state.arcs)].until_ = t + 0.15
			end
		end
	else
		state.still = 0
	end
	if state.flourishAge >= 0 then
		state.flourishAge += dt
		local f = state.flourishAge / CFG.FLOURISH_TIME
		if f >= 1 then
			state.flourishAge = -1
			state.still = 0
			state.nextFlourish = CFG.FLOURISH_AFTER[1]
				+ math.random() * (CFG.FLOURISH_AFTER[2] - CFG.FLOURISH_AFTER[1])
		else
			local bell = math.sin(f * math.pi)
			cowlTarget = math.max(cowlTarget, bell * 0.48)
			ventTarget = math.max(ventTarget, bell * 0.38)
		end
	end

	-- Step crisp mechanical springs & levitation
	local dtClamped = math.min(dt, 0.05)
	state.cowlPos, state.cowlVel = stepSpring(
		state.cowlPos,
		state.cowlVel,
		cowlTarget,
		CFG.COWL_SPRING_FREQ,
		CFG.COWL_SPRING_DAMP,
		dtClamped
	)
	state.ventPos, state.ventVel = stepSpring(
		state.ventPos,
		state.ventVel,
		ventTarget,
		CFG.COWL_SPRING_FREQ * 0.9,
		CFG.COWL_SPRING_DAMP,
		dtClamped
	)
	state.cowlPos = math.clamp(state.cowlPos, -0.05, 1.25)
	state.ventPos = math.clamp(state.ventPos, -0.05, 1.25)
	state.levitate += (levTarget - state.levitate) * (1 - math.exp(-8.5 * dtClamped))

	state.crystalAngle += state.crystalVel * dt
	state.ringAAngle += state.ringAVel * dt
	state.ringBAngle += state.ringBVel * dt

	-- Exact basis vectors in Root body space
	local prof = state.profile
	local coreP = toBodyPos(state.handle, state.body, state.scale, prof.core)
	local upDir = (toBodyPos(
		state.handle,
		state.body,
		state.scale,
		prof.core + Vector3.new(0, 0, 0.2)
	) - coreP).Unit
	local fwdDir = (toBodyPos(
		state.handle,
		state.body,
		state.scale,
		prof.core + Vector3.new(0.2, 0, 0)
	) - coreP).Unit
	local leftAxis = (toBodyPos(
		state.handle,
		state.body,
		state.scale,
		prof.core + Vector3.new(0, 0.2, 0)
	) - coreP).Unit

	-- 1. CoreCrystal
	local bobY = math.sin(t * CFG.CRYSTAL_BOB_FREQ)
		* CFG.CRYSTAL_BOB_AMP
		* state.scale
		* math.max(0.25, prof.levitateMul)
	local levY = state.levitate * CFG.CRYSTAL_LEVITATE * prof.levitateMul * state.scale
	local crystalDelta = if state.weaponId == "Sheriff"
		then CFrame.fromAxisAngle(fwdDir, state.crystalAngle)
		else CFrame.new(upDir * (bobY + levY)) * CFrame.fromAxisAngle(
			upDir,
			state.crystalAngle
		) * CFrame.fromAxisAngle(fwdDir, state.crystalAngle * 0.55) * CFrame.fromAxisAngle(
			leftAxis,
			math.sin(t * 1.9) * 0.14
		)
	applyPivot(state.crystals, crystalDelta)

	-- 2. Dual Counter-Rotating Gyroscopic Containment Rings
	local ringLift = levY * 0.55
	local ringADelta = if state.weaponId == "Sheriff"
		then CFrame.fromAxisAngle(fwdDir, state.ringAAngle * 0.85)
		else CFrame.new(upDir * ringLift) * CFrame.fromAxisAngle(
			fwdDir,
			state.ringAAngle * 0.72
		) * CFrame.fromAxisAngle(upDir, state.ringAAngle * 0.45) * CFrame.fromAxisAngle(
			leftAxis,
			state.ringAAngle * 0.65
		)
	local ringBDelta = if state.weaponId == "Sheriff"
		then CFrame.fromAxisAngle(fwdDir, state.ringBAngle * 0.85)
		else CFrame.new(upDir * (ringLift * 1.15)) * CFrame.fromAxisAngle(
			leftAxis,
			state.ringBAngle * 0.78
		) * CFrame.fromAxisAngle(upDir, -state.ringBAngle * 0.55) * CFrame.fromAxisAngle(
			fwdDir,
			state.ringBAngle * 0.46
		)
	applyPivot(state.ringA, ringADelta)
	applyPivot(state.ringB, ringBDelta)

	-- 3. Articulated Armor Cowls
	local openAmt = math.max(0, state.cowlPos)
	local pop = (
		CFG.COWL_OUT_HEAT * math.min(1, openAmt)
		+ (CFG.COWL_OUT_OPEN - CFG.COWL_OUT_HEAT) * math.max(0, openAmt - 0.5) * 2
	) * state.scale
	local yaw = (CFG.COWL_YAW_HEAT + (CFG.COWL_YAW_OPEN - CFG.COWL_YAW_HEAT) * openAmt) * openAmt
	local roll = (CFG.COWL_ROLL_HEAT + (CFG.COWL_ROLL_OPEN - CFG.COWL_ROLL_HEAT) * openAmt)
		* openAmt
	if #state.cowlLeft > 0 then
		local deltaL = CFrame.new(leftAxis * pop)
			* CFrame.fromAxisAngle(upDir, -yaw)
			* CFrame.fromAxisAngle(fwdDir, -roll)
		applyPivot(state.cowlLeft, deltaL)
		local deltaR = CFrame.new(-leftAxis * pop)
			* CFrame.fromAxisAngle(upDir, yaw)
			* CFrame.fromAxisAngle(fwdDir, roll)
		applyPivot(state.cowlRight, deltaR)
	end

	-- 4. Suppressor Accelerator Shrouds
	local ventOpen = math.max(0, state.ventPos)
	local vAng = (CFG.VENT_ANGLE_HEAT + (CFG.VENT_ANGLE_OPEN - CFG.VENT_ANGLE_HEAT) * ventOpen)
		* ventOpen
	if #state.ventTop > 0 or #state.ventBot > 0 then
		applyPivot(state.ventTop, CFrame.fromAxisAngle(leftAxis, -vAng))
		applyPivot(state.ventBot, CFrame.fromAxisAngle(leftAxis, vAng))
	end

	-- 5. Scroll RiftforgePlasmaLayer surface textures smoothly
	local scrollBoost = 1 + state.heat * 2.4 + state.surge * 3.4 + state.levitate * 2.2
	for _, tex in state.plasmaTextures do
		if tex.Parent then
			tex.OffsetStudsU = (tex.OffsetStudsU + CFG.TILE_SCROLL_U * scrollBoost * dt) % 10
			tex.OffsetStudsV = (tex.OffsetStudsV + CFG.TILE_SCROLL_V * scrollBoost * dt) % 10
		end
	end

	-- 6. Neon glow, PointLight & Dynamic Volumetric Plasma Ribbons
	local adsFade = 1 - adsAlpha * (1 - CFG.ADS_LIGHT_SCALE)
	local energy = math.clamp(state.heat * 0.55 + state.surge * 0.85 + state.levitate * 0.45, 0, 1)
	local pulseWave = 0.5 + 0.5 * math.sin(t * 4.4)
	local glowColor = CFG.CORE_IDLE_COLOR:Lerp(CFG.CORE_HOT_COLOR, energy * 0.85 + pulseWave * 0.14)
	if state.drain > 0.01 then
		glowColor = glowColor:Lerp(CFG.PLASMA_DRAINED, state.drain * 0.8)
	end
	for _, p in state.glowParts do
		if p.Parent then
			p.Color = glowColor
		end
	end

	if state.coreLight and state.coreLight.Parent then
		local drainMul = 1 - state.drain * 0.7
		state.coreLight.Brightness = (
			CFG.LIGHT_IDLE
			+ CFG.LIGHT_PULSE * pulseWave
			+ CFG.LIGHT_SURGE * energy
		)
			* adsFade
			* drainMul
		state.coreLight.Color = CFG.LIGHT_COLOR:Lerp(CFG.LIGHT_HOT_COLOR, energy * 0.75)
	end

	-- Volumetric flank plasma ribbons with dynamic fire/surge width swell!
	local ribVis = math.clamp((1 - adsAlpha * 0.92) * (1 - state.drain * 0.75), 0, 1)
	local ribTrans = math.clamp(1 - ribVis * (0.68 + energy * 0.30), 0.06, 1)
	local ribBright = CFG.RIBBON_BRIGHTNESS * (1 + energy * 1.1)
	local ribSpeed = CFG.RIBBON_SPEED * (1 + state.heat * 1.6 + state.surge * 2.2)
	local ribSwell = 1 + energy * 0.55
	for _, r in state.ribbons do
		if r.beam.Parent then
			r.beam.Enabled = ribVis > 0.05 and not reduced
			r.core.Enabled = r.beam.Enabled
			if r.beam.Enabled then
				r.beam.Transparency = NumberSequence.new(ribTrans)
				r.core.Transparency = NumberSequence.new(math.min(1, ribTrans + 0.14))
				r.beam.Brightness = ribBright
				r.beam.TextureSpeed = ribSpeed
				r.beam.Width0 = r.w0 * ribSwell
				r.beam.Width1 = r.w1 * ribSwell
				r.core.Width0 = r.w0 * 0.34 * ribSwell
				r.core.Width1 = r.w1 * 0.34 * ribSwell
			end
		end
	end

	-- 7. Dynamic 3D Plasma Halo Ring (Draw/Reload/Inspect motion-synced showcase!)
	if state.halo and not reduced and adsAlpha < 0.65 then
		local haloActive = false
		-- Priority A: Barrel shockwave halo racing Core -> Muzzle on Draw/Reload/Inspect SLAM!
		if state.haloSweepAge >= 0 then
			state.haloSweepAge += dt
			local u = state.haloSweepAge / state.haloSweepDur
			if u >= 1 then
				state.haloSweepAge = -1
				if not state.haloPopped and state.muzzlePop then
					state.haloPopped = true
					state.muzzlePop:Emit(SettingsApply.vfxCount(7))
				end
			else
				haloActive = true
				local muzzleP = toBodyPos(state.handle, state.body, state.scale, prof.muzzle)
				local pos = coreP:Lerp(muzzleP, u)
				local rad = (0.175 - 0.065 * u) * state.scale
				local alpha = math.sin(u * math.pi)
				poseHalo(state.halo, pos, leftAxis, upDir, rad, t * 9.0, alpha, 0.062 * state.scale)
			end
		end
		-- Priority B: Orbiting plasma halo around center of gun during Empty Reload 360 spin or Inspect roll!
		if not haloActive and (reloadSpinning or inspectSpinning) then
			haloActive = true
			local midP = toBodyPos(state.handle, state.body, state.scale, prof.mid)
			poseHalo(
				state.halo,
				midP,
				leftAxis,
				upDir,
				0.28 * state.scale,
				t * 11.0,
				0.92,
				0.058 * state.scale
			)
		end
		-- Priority C: Glowing Magwell Plasma Portal Ring while forging the fresh energy cell!
		if not haloActive and reloadForming then
			haloActive = true
			local magP = toBodyPos(state.handle, state.body, state.scale, prof.magWell)
			local u = math.clamp(((reloadProgress or 0.3) - 0.17) / 0.29, 0, 1)
			local rad = (0.21 - 0.09 * u) * state.scale -- contracts smoothly as cell condenses!
			poseHalo(state.halo, magP, fwdDir, leftAxis, rad, t * 8.5, 0.85, 0.052 * state.scale)
		end
		if not haloActive then
			hideHalo(state.halo)
		end
	else
		hideHalo(state.halo)
	end

	-- 8. Dynamic crackling reactor lightning arcs
	if #state.arcs > 0 and not reduced then
		if t >= state.nextArcAt then
			local excited = state.levitate > 0.2
				or state.heat > 0.3
				or reloadSpinning
				or reloadForming
			local gap = if excited then 0.07 + math.random() * 0.12 else 0.42 + math.random() * 0.90
			state.nextArcAt = t + gap
			local pick = state.arcs[math.random(1, #state.arcs)]
			pick.until_ = t + 0.075 + math.random() * 0.06
		end
		for _, a in state.arcs do
			local on = t < a.until_ and adsAlpha < 0.65 and state.drain < 0.8
			if a.beam.Parent then
				a.beam.Enabled = on
				if on then
					a.a1.Position = a.base1 + upDir * levY
					a.beam.CurveSize0 = (math.random() - 0.5) * 0.09 * state.scale
					a.beam.CurveSize1 = (math.random() - 0.5) * 0.09 * state.scale
				end
			end
		end
	end

	-- 9. Step per-shot travelling barrel pulse ring
	if state.pulse and state.pulse.active then
		state.pulse.age += dt
		local u = state.pulse.age / CFG.PULSE_TIME
		if u >= 1 then
			state.pulse.active = false
		else
			state.pulse.attach.Position = state.pulse.startPos:Lerp(state.pulse.endPos, u)
		end
	end

	-- 10. Step sweeping barrel plasma wave
	if state.sweep and state.sweep.active then
		state.sweep.age += dt
		local u = state.sweep.age / state.sweep.duration
		if u >= 1 then
			state.sweep.active = false
			state.sweep.rings.Enabled = false
		else
			state.sweep.attach.Position = state.sweep.startPos:Lerp(state.sweep.endPos, u)
		end
	end

	-- 11. Toggle motion-synced plasma trails cleanly
	for _, tr in state.trails do
		if tr.Parent then
			tr.Enabled = trailOn and not reduced
		end
	end
end

function RiftforgeEffects.destroy(state: State)
	for _, inst in state.owned do
		pcall(function()
			if inst.Parent then
				inst:Destroy()
			end
		end)
	end
	table.clear(state.owned)
	table.clear(state.ribbons)
	table.clear(state.arcs)
	table.clear(state.trails)
	state.halo = nil
	state.coreLight = nil
	state.coreSparks = nil
	state.coreArcs = nil
	state.muzzlePop = nil
	state.magBurst = nil
	state.magFormer = nil
	state.pulse = nil
	state.sweep = nil
end

return RiftforgeEffects
