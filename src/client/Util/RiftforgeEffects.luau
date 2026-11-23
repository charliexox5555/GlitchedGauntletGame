--!strict
-- Riftforge Legendary live first-person reactor engine (v02 AAA Overhaul):
--
-- Drives all 7 articulated moving parts of Riftforge Phantom v02 + volumetric VFX:
--   1. CoreCrystal   : spinning 16-face dark-matter prism; LEVITATES +0.145 studs UP out of
--                      the open reactor bay during InspectRiftforge!
--   2. CoreRingA/B   : dual counter-rotating gyroscopic containment rings (steel + bronze)
--   3. CowlLeft/Right: sculpted receiver armor shrouds that flare outward (yaw + roll + pop)
--                      on fire/reload/inspect and SLAM shut with mechanical spring rebound!
--   4. VentTop/Bottom: sleek aerodynamic suppressor shrouds pitching open under heat/reload/inspect
--   5. Scrolling RiftforgePlasmaLayer surface textures across the crystal, rails & energy cell
--   6. Twin volumetric plasma Beam ribbons along both flanks (core -> handguard -> suppressor),
--      surging on shots, draining dark on MagOut, fading cleanly out in ADS
--   7. Dynamic crackling lightning Beam arcs bridging the flared cowls <-> levitating crystal
--   8. Per-shot travelling barrel plasma pulse ring (core -> muzzle)
--   9. Reload plasma discharge burst + converging plasma beads forming fresh cell + barrel surge wave
--  10. Inspect 360-roll plasma Trails off muzzle & buttstock + subtle idle living-machine flourish
--
-- All VFX Attachments are parented to Rig.Motors.Root.Part1 (the Root body joint) in Handle->Root
-- space so recoil, reload, and inspect move every ribbon, arc, ring, and trail cleanly with the gun!

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local SkinPreview = require(Shared.Config.SkinPreview)
local StateValues = require(Shared.StateValues)
local UiMotion = require(Shared.UiMotion)
local SettingsApply = require(Shared.SettingsApply)

local CFG = SkinPreview.RIFTFORGE

type WeldEntry = {
	weld: Weld,
	restC0: CFrame,
	fromPivot: CFrame,
	pivotInPart0: CFrame,
}

type Ribbon = {
	beam: Beam,
	core: Beam,
	baseWidth: number,
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
	-- Volumetric VFX owned by this camera gun (cleaned via pcall on detach)
	owned: { Instance },
	ribbons: { Ribbon },
	arcs: { ArcBeam },
	coreLight: PointLight?,
	coreSparks: ParticleEmitter?,
	coreArcs: ParticleEmitter?,
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
	cowlPos: number, -- 0 = closed, 1 = wide open
	cowlVel: number,
	ventPos: number,
	ventVel: number,
	levitate: number, -- 0 = seated in bay, 1 = levitating above bay on inspect
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
		return "ReloadRiftforge"
	elseif kind == "reloadEmpty" then
		return "ReloadEmptyRiftforge"
	elseif kind == "inspect" then
		return "InspectRiftforge"
	end
	return nil
end

local function triggerSweep(state: State, duration: number)
	if not state.sweep or UiMotion.reduced() then
		return
	end
	state.sweep.active = true
	state.sweep.age = 0
	state.sweep.duration = duration
	state.sweep.rings.Enabled = true
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

	local state: State = {
		model = model,
		weaponId = id,
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
		coreLight = nil,
		coreSparks = nil,
		coreArcs = nil,
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
		surge = 0.6,
		drain = 0,
		cowlPos = 0.45, -- start slightly open on draw, slam shut cleanly!
		cowlVel = 0,
		ventPos = 0.35,
		ventVel = 0,
		levitate = 0,
		nextArcAt = 0.6,
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
	}

	-- Compute exact pivots in Root body space (works regardless of Root bone offset!)
	local corePivot = toBodyPos(handle, body, scale, CFG.CORE_BL)
	local cowlLPivot = toBodyPos(handle, body, scale, CFG.COWL_L_BL)
	local cowlRPivot = toBodyPos(handle, body, scale, CFG.COWL_R_BL)
	local ventTopPivot = toBodyPos(handle, body, scale, CFG.VENT_TOP_BL)
	local ventBotPivot = toBodyPos(handle, body, scale, CFG.VENT_BOT_BL)

	for _, desc in model:GetDescendants() do
		if desc:IsA("Texture") and desc:GetAttribute("RiftforgePlasmaLayer") then
			table.insert(state.plasmaTextures, desc)
		elseif desc:IsA("BasePart") then
			local name = desc.Name
			if desc.Material == Enum.Material.Neon and not name:find("Sight") then
				table.insert(state.glowParts, desc)
			end
			local weld = desc:FindFirstChild("SkinCosmeticWeld")
			if weld and weld:IsA("Weld") and weld.Part0 == body then
				if name:find("CoreCrystal") then
					table.insert(state.crystals, makeEntry(weld, corePivot))
				elseif name:find("CoreRingA") then
					table.insert(state.ringA, makeEntry(weld, corePivot))
				elseif name:find("CoreRingB") then
					table.insert(state.ringB, makeEntry(weld, corePivot))
				elseif name:find("CowlLeft") then
					table.insert(state.cowlLeft, makeEntry(weld, cowlLPivot))
				elseif name:find("CowlRight") then
					table.insert(state.cowlRight, makeEntry(weld, cowlRPivot))
				elseif name:find("VentTop") then
					table.insert(state.ventTop, makeEntry(weld, ventTopPivot))
				elseif name:find("VentBottom") then
					table.insert(state.ventBot, makeEntry(weld, ventBotPivot))
				end
			end
		end
	end

	-- 1. Core reactor attachment: soft violet PointLight + sparks + crackle arcs
	local coreAtt = makeAnchor(state, "RiftforgeCoreAtt", CFG.CORE_BL)
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
		-- Core plasma spark motes
		local sparks = Instance.new("ParticleEmitter")
		sparks.Name = "RiftforgeCoreSparks"
		sparks.Texture = CFG.SPARK_TEXTURE
		sparks.Color = ColorSequence.new(CFG.PLASMA_EDGE, CFG.PLASMA)
		sparks.LightEmission = 1
		sparks.LightInfluence = 0
		sparks.Brightness = 1.9
		sparks.Lifetime = NumberRange.new(0.22, 0.42)
		sparks.Speed = NumberRange.new(0.22 * scale, 0.58 * scale)
		sparks.Drag = 4.5
		sparks.SpreadAngle = Vector2.new(180, 180)
		sparks.Orientation = Enum.ParticleOrientation.VelocityParallel
		sparks.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.014 * scale),
			NumberSequenceKeypoint.new(0.4, 0.044 * scale),
			NumberSequenceKeypoint.new(1, 0),
		})
		sparks.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.05),
			NumberSequenceKeypoint.new(0.65, 0.25),
			NumberSequenceKeypoint.new(1, 1),
		})
		sparks.Rate = SettingsApply.vfxCount(4)
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
		coreArcs.Brightness = 1.85
		coreArcs.Lifetime = NumberRange.new(0.08, 0.14)
		coreArcs.Speed = NumberRange.new(0)
		coreArcs.Rotation = NumberRange.new(0, 360)
		coreArcs.Size = NumberSequence.new(0.16 * scale)
		coreArcs.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.05),
			NumberSequenceKeypoint.new(0.5, 0.25),
			NumberSequenceKeypoint.new(1, 1),
		})
		coreArcs.Rate = SettingsApply.vfxCount(2)
		coreArcs.LockedToPart = true
		coreArcs.ZOffset = 0.04 * scale
		coreArcs.Parent = coreAtt
		state.coreArcs = coreArcs
		table.insert(state.owned, coreArcs)

		-- 2. Twin volumetric scrolling plasma Beam ribbons on BOTH flanks (Core -> Handguard -> Suppressor!)
		local ribbonW = CFG.RIBBON_WIDTH * scale
		for _, ysgn in { 1, -1 } do
			local segs = {
				{
					Vector3.new(0.45, ysgn * 0.082, 0.300),
					Vector3.new(1.12, ysgn * 0.076, 0.314),
					1.0,
					0.85,
				},
				{
					Vector3.new(1.12, ysgn * 0.076, 0.314),
					Vector3.new(1.76, ysgn * 0.068, 0.346),
					0.85,
					0.72,
				},
				{
					Vector3.new(1.76, ysgn * 0.068, 0.346),
					Vector3.new(2.38, ysgn * 0.058, 0.352),
					0.72,
					0.42,
				},
			}
			for i, seg in segs do
				local a0 = makeAnchor(state, string.format("RF_Rib_%d_%d_0", ysgn, i), seg[1])
				local a1 = makeAnchor(state, string.format("RF_Rib_%d_%d_1", ysgn, i), seg[2])
				local beam = Instance.new("Beam")
				beam.Name = "RiftforgePlasmaRibbon"
				beam.Attachment0 = a0
				beam.Attachment1 = a1
				beam.Texture = CFG.RIBBON_TEXTURE
				beam.TextureMode = Enum.TextureMode.Wrap
				beam.TextureLength = CFG.RIBBON_TILE * scale
				beam.TextureSpeed = CFG.RIBBON_SPEED
				beam.Color = ColorSequence.new(CFG.PLASMA_EDGE, CFG.PLASMA)
				beam.Transparency = NumberSequence.new(0.32)
				beam.LightEmission = 1
				beam.LightInfluence = 0
				beam.Brightness = CFG.RIBBON_BRIGHTNESS
				beam.FaceCamera = true
				beam.Width0 = ribbonW * seg[3]
				beam.Width1 = ribbonW * seg[4]
				beam.Segments = 4
				beam.Parent = a0
				table.insert(state.owned, beam)

				local core = beam:Clone()
				core.Name = "RiftforgePlasmaCore"
				core.Texture = ""
				core.Width0 = beam.Width0 * 0.32
				core.Width1 = beam.Width1 * 0.32
				core.Color = ColorSequence.new(CFG.PLASMA)
				core.Transparency = NumberSequence.new(0.45)
				core.Parent = a0
				table.insert(state.owned, core)

				table.insert(state.ribbons, {
					beam = beam,
					core = core,
					baseWidth = ribbonW * 0.5 * (seg[3] + seg[4]),
					speed = CFG.RIBBON_SPEED,
				})
			end
		end

		-- 3. Three dynamic jagged reactor lightning Beams (snap across open cowls & levitating crystal!)
		local arcDefs = {
			{ Vector3.new(0.30, 0.085, 0.340), Vector3.new(0.455, 0.0, 0.296) },
			{ Vector3.new(0.61, -0.085, 0.340), Vector3.new(0.455, 0.0, 0.296) },
			{ Vector3.new(0.32, 0.075, 0.220), Vector3.new(0.59, -0.075, 0.370) },
		}
		for i, pair in arcDefs do
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
			b.Brightness = 2.6
			b.FaceCamera = true
			b.Width0 = 0.045 * scale
			b.Width1 = 0.045 * scale
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
		local pStart = toBodyPos(handle, body, scale, Vector3.new(0.68, 0, 0.345))
		local pEnd = toBodyPos(handle, body, scale, CFG.MUZZLE_BL)
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
		pRing.Brightness = CFG.PULSE_BRIGHTNESS
		pRing.Lifetime = NumberRange.new(CFG.PULSE_TIME)
		pRing.Speed = NumberRange.new(0.01)
		pRing.EmissionDirection = Enum.NormalId.Front
		pRing.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		pRing.Rotation = NumberRange.new(0, 360)
		pRing.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.24 * scale),
			NumberSequenceKeypoint.new(0.6, 0.28 * scale),
			NumberSequenceKeypoint.new(1, 0.16 * scale),
		})
		pRing.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.05),
			NumberSequenceKeypoint.new(0.65, 0.25),
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

		-- 5. Sweeping plasma wave along full barrel (Draw lock, Reload cowl SLAM, Inspect lock!)
		local sStart = toBodyPos(handle, body, scale, CFG.CORE_BL)
		local sEnd = toBodyPos(handle, body, scale, CFG.MUZZLE_BL)
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
		sRings.Brightness = 1.9
		sRings.Lifetime = NumberRange.new(CFG.SWEEP_LIFE)
		sRings.Speed = NumberRange.new(0.01)
		sRings.EmissionDirection = Enum.NormalId.Front
		sRings.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		sRings.Rotation = NumberRange.new(0, 360)
		sRings.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.16 * scale),
			NumberSequenceKeypoint.new(0.45, 0.34 * scale),
			NumberSequenceKeypoint.new(1, 0.22 * scale),
		})
		sRings.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.15),
			NumberSequenceKeypoint.new(0.5, 0.35),
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
		local magAtt = makeAnchor(state, "RiftforgeMagWellAtt", CFG.MAG_WELL_BL)
		local magBurst = Instance.new("ParticleEmitter")
		magBurst.Name = "RiftforgeMagBurst"
		magBurst.Texture = CFG.ARC_TEXTURE
		magBurst.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
		magBurst.FlipbookMode = Enum.ParticleFlipbookMode.Random
		magBurst.Color = ColorSequence.new(CFG.PLASMA_EDGE, CFG.PLASMA)
		magBurst.LightEmission = 1
		magBurst.LightInfluence = 0
		magBurst.Brightness = 2.1
		magBurst.Lifetime = NumberRange.new(0.14, 0.24)
		magBurst.Speed = NumberRange.new(0.8 * scale, 2.2 * scale)
		magBurst.Drag = 6
		magBurst.SpreadAngle = Vector2.new(180, 180)
		magBurst.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.18 * scale),
			NumberSequenceKeypoint.new(1, 0.04 * scale),
		})
		magBurst.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.55, 0.25),
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
		former.Brightness = 1.9
		former.Lifetime = NumberRange.new(0.24, 0.34)
		former.Speed = NumberRange.new(-1.35 * scale, -0.85 * scale)
		former.SpreadAngle = Vector2.new(180, 180)
		former.Shape = Enum.ParticleEmitterShape.Sphere
		former.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
		former.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		former.Orientation = Enum.ParticleOrientation.VelocityParallel
		former.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.018 * scale),
			NumberSequenceKeypoint.new(0.5, 0.055 * scale),
			NumberSequenceKeypoint.new(1, 0.008 * scale),
		})
		former.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.65),
			NumberSequenceKeypoint.new(0.35, 0.05),
			NumberSequenceKeypoint.new(1, 1),
		})
		former.Rate = SettingsApply.vfxCount(CFG.FORM_RATE)
		former.Enabled = false
		former.LockedToPart = true
		former.Parent = magAtt
		state.magFormer = former
		table.insert(state.owned, former)

		-- 7. Inspect 360-roll plasma trails off muzzle & buttstock
		for idx, pair in
			{
				{ Vector3.new(2.48, 0.0, 0.39), Vector3.new(2.48, 0.0, 0.31) },
				{ Vector3.new(-1.06, 0.0, 0.41), Vector3.new(-1.06, 0.0, 0.33) },
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
				NumberSequenceKeypoint.new(0, 0.15),
				NumberSequenceKeypoint.new(0.55, 0.45),
				NumberSequenceKeypoint.new(1, 1),
			})
			tr.LightEmission = 1
			tr.LightInfluence = 0
			tr.Brightness = 1.9
			tr.Lifetime = CFG.TRAIL_LIFE
			tr.MinLength = 0.04
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
	-- Snappy mechanical cowl recoil flare impulse!
	state.cowlVel += 4.2
	state.ventVel += 3.8
	-- Travelling plasma pulse ring down the barrel on every shot!
	triggerPulse(state)
	if state.coreSparks and not UiMotion.reduced() then
		state.coreSparks:Emit(SettingsApply.vfxCount(5))
	end
	if state.coreArcs and not UiMotion.reduced() then
		state.coreArcs:Emit(SettingsApply.vfxCount(2))
	end
	-- Snap a lightning arc across the bay on shots!
	if #state.arcs > 0 and not UiMotion.reduced() then
		local a = state.arcs[math.random(1, #state.arcs)]
		a.until_ = state.clock + 0.075
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
		state.surge = 0.85
		state.drawSlammed = false
		state.cowlPos = 0.65
		state.ventPos = 0.55
		state.crystalVel = 9.0
		state.ringAVel = -8.0
		state.ringBVel = 11.0
	elseif kind == "Inspect" then
		state.surge = 0.9
		state.inspectSlammed = false
		state.crystalVel = CFG.CRYSTAL_INSPECT_SPIN
		state.ringAVel = -9.5
		state.ringBVel = 13.5
		if state.coreSparks and not UiMotion.reduced() then
			state.coreSparks:Emit(SettingsApply.vfxCount(7))
		end
	elseif kind == "Seat" then
		state.surge = 1.0
		state.drain = 0
		state.crystalVel = 13.0
		state.ringAVel = -10.0
		state.ringBVel = 14.0
		if state.magBurst and not UiMotion.reduced() then
			state.magBurst:Emit(SettingsApply.vfxCount(8))
		end
		if state.coreSparks and not UiMotion.reduced() then
			state.coreSparks:Emit(SettingsApply.vfxCount(8))
		end
	elseif kind == "CowlSlam" then
		state.surge = 1.0
		state.cowlVel = -16.0 -- violent SLAM shut!
		state.ventVel = -14.0
		triggerSweep(state, 0.24)
		if state.coreArcs and not UiMotion.reduced() then
			state.coreArcs:Emit(SettingsApply.vfxCount(3))
		end
	end
end

-- Reload plasma energy-cell choreography (mirrors TempestIdle.reload):
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
		state.cowlVel += 11.0 -- blow armor cowls wide open!
		state.ventVel += 10.0
		if state.magBurst and not UiMotion.reduced() then
			state.magBurst:Emit(SettingsApply.vfxCount(9))
		end
		if state.coreArcs and not UiMotion.reduced() then
			state.coreArcs:Emit(SettingsApply.vfxCount(2))
		end
	end
	local forming = t >= outAt + 0.04 and t < inAt
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
	adsAlpha: number
)
	state.clock += dt
	local t = state.clock
	local reduced = UiMotion.reduced()

	-- Decay angular velocities, heat, surge, drain
	local drag = math.exp(-CFG.SPIN_DRAG * dt)
	state.crystalVel = CFG.CRYSTAL_IDLE_SPIN + (state.crystalVel - CFG.CRYSTAL_IDLE_SPIN) * drag
	state.ringAVel = CFG.RING_A_IDLE_SPIN + (state.ringAVel - CFG.RING_A_IDLE_SPIN) * drag
	state.ringBVel = CFG.RING_B_IDLE_SPIN + (state.ringBVel - CFG.RING_B_IDLE_SPIN) * drag
	state.heat = math.max(0, state.heat - CFG.HEAT_COOL * dt)
	state.surge = math.max(0, state.surge - CFG.SURGE_DECAY * dt)
	if not state.reloading then
		state.drain = math.max(0, state.drain - 4.5 * dt)
	end

	-- Determine mechanical targets across Draw, Reload, Inspect, and Idle Flourish!
	local cowlTarget = state.heat * 0.62
	local ventTarget = state.heat * 0.68
	local levTarget = 0
	local trailOn = false

	-- Draw beat: cowls stay cracked open on pull, then SLAM shut at 0.42 with barrel wave!
	if drawProgress ~= nil then
		state.still = 0
		if drawProgress < 0.41 then
			cowlTarget = 0.65
			ventTarget = 0.55
		elseif not state.drawSlammed then
			state.drawSlammed = true
			RiftforgeEffects.pulse(state, "CowlSlam")
		end
	else
		state.drawSlammed = false
	end

	-- Reload beat: cowls & vents split wide open from 0.12 -> 0.74, then SLAM shut!
	if reloadProgress ~= nil then
		state.still = 0
		if reloadProgress > 0.12 and reloadProgress < 0.74 then
			cowlTarget = 1.0
			ventTarget = 1.0
			state.crystalVel = math.max(state.crystalVel, 8.5)
			state.ringAVel = math.min(state.ringAVel, -7.5)
			state.ringBVel = math.max(state.ringBVel, 11.0)
		end
	end

	-- Inspect beat: cowls split wide, CoreCrystal LEVITATES UP out of the open bay,
	-- plasma trails light up during the 360 roll (0.45..0.63), crystal seats & cowls SLAM at 0.81!
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
			trailOn = true
		end
	else
		state.inspectSlammed = false
	end

	-- Living-machine subtle idle flourish when standing still!
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
			state.crystalVel += 7.5
			state.ringAVel -= 6.5
			state.ringBVel += 9.5
			state.surge = math.max(state.surge, 0.55)
			if #state.arcs > 0 and not reduced then
				state.arcs[math.random(1, #state.arcs)].until_ = t + 0.14
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
			cowlTarget = math.max(cowlTarget, bell * 0.45)
			ventTarget = math.max(ventTarget, bell * 0.35)
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
	state.levitate += (levTarget - state.levitate) * (1 - math.exp(-7.5 * dtClamped))

	-- Integrate gyros
	state.crystalAngle += state.crystalVel * dt
	state.ringAAngle += state.ringAVel * dt
	state.ringBAngle += state.ringBVel * dt

	-- Exact basis vectors in Root body space (works whether Root is Blender-axis or Roblox-axis!)
	local coreP = toBodyPos(state.handle, state.body, state.scale, CFG.CORE_BL)
	local upDir = (toBodyPos(
		state.handle,
		state.body,
		state.scale,
		CFG.CORE_BL + Vector3.new(0, 0, 0.2)
	) - coreP).Unit
	local fwdDir = (toBodyPos(
		state.handle,
		state.body,
		state.scale,
		CFG.CORE_BL + Vector3.new(0.2, 0, 0)
	) - coreP).Unit
	local leftAxis = (toBodyPos(
		state.handle,
		state.body,
		state.scale,
		CFG.CORE_BL + Vector3.new(0, 0.2, 0)
	) - coreP).Unit

	-- 1. CoreCrystal: spin + hover bob + dramatic upward levitation during Inspect!
	local bobY = math.sin(t * CFG.CRYSTAL_BOB_FREQ) * CFG.CRYSTAL_BOB_AMP * state.scale
	local levY = state.levitate * CFG.CRYSTAL_LEVITATE * state.scale
	local crystalDelta = CFrame.new(upDir * (bobY + levY))
		* CFrame.fromAxisAngle(upDir, state.crystalAngle)
		* CFrame.fromAxisAngle(fwdDir, state.crystalAngle * 0.55)
		* CFrame.fromAxisAngle(leftAxis, math.sin(t * 1.9) * 0.14)
	applyPivot(state.crystals, crystalDelta)

	-- 2. Dual Counter-Rotating Gyroscopic Containment Rings (follow half of levitation!)
	local ringLift = levY * 0.55
	local ringADelta = CFrame.new(upDir * ringLift)
		* CFrame.fromAxisAngle(fwdDir, state.ringAAngle * 0.72)
		* CFrame.fromAxisAngle(upDir, state.ringAAngle * 0.45)
		* CFrame.fromAxisAngle(leftAxis, state.ringAAngle * 0.65)
	local ringBDelta = CFrame.new(upDir * (ringLift * 1.15))
		* CFrame.fromAxisAngle(leftAxis, state.ringBAngle * 0.78)
		* CFrame.fromAxisAngle(upDir, -state.ringBAngle * 0.55)
		* CFrame.fromAxisAngle(fwdDir, state.ringBAngle * 0.46)
	applyPivot(state.ringA, ringADelta)
	applyPivot(state.ringB, ringBDelta)

	-- 3. Articulated Armor Cowls (outward pop + yaw + roll flare!)
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

	-- 4. Suppressor Accelerator Shrouds (VentTop / VentBottom) pitch open around their hinge!
	local ventOpen = math.max(0, state.ventPos)
	local vAng = (CFG.VENT_ANGLE_HEAT + (CFG.VENT_ANGLE_OPEN - CFG.VENT_ANGLE_HEAT) * ventOpen)
		* ventOpen
	if #state.ventTop > 0 or #state.ventBot > 0 then
		applyPivot(state.ventTop, CFrame.fromAxisAngle(leftAxis, -vAng))
		applyPivot(state.ventBot, CFrame.fromAxisAngle(leftAxis, vAng))
	end

	-- 5. Scroll RiftforgePlasmaLayer surface textures smoothly (faster when heated/surging!)
	local scrollBoost = 1 + state.heat * 2.2 + state.surge * 3.0 + state.levitate * 2.0
	for _, tex in state.plasmaTextures do
		if tex.Parent then
			tex.OffsetStudsU = (tex.OffsetStudsU + CFG.TILE_SCROLL_U * scrollBoost * dt) % 10
			tex.OffsetStudsV = (tex.OffsetStudsV + CFG.TILE_SCROLL_V * scrollBoost * dt) % 10
		end
	end

	-- 6. Animate Neon glow parts, PointLight & Volumetric Plasma Ribbons (ADS fade keeps sight clear!)
	local adsFade = 1 - adsAlpha * (1 - CFG.ADS_LIGHT_SCALE)
	local energy = math.clamp(state.heat * 0.55 + state.surge * 0.8 + state.levitate * 0.45, 0, 1)
	local pulseWave = 0.5 + 0.5 * math.sin(t * 4.2)
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
		state.coreLight.Color = CFG.LIGHT_COLOR:Lerp(CFG.LIGHT_HOT_COLOR, energy * 0.72)
	end

	-- Volumetric plasma ribbons along flanks
	local ribVis = math.clamp((1 - adsAlpha * 0.92) * (1 - state.drain * 0.75), 0, 1)
	local ribTrans = math.clamp(1 - ribVis * (0.62 + energy * 0.32), 0.08, 1)
	local ribBright = CFG.RIBBON_BRIGHTNESS * (1 + energy * 0.9)
	local ribSpeed = CFG.RIBBON_SPEED * (1 + state.heat * 1.4 + state.surge * 1.8)
	for _, r in state.ribbons do
		if r.beam.Parent then
			r.beam.Enabled = ribVis > 0.05 and not reduced
			r.core.Enabled = r.beam.Enabled
			if r.beam.Enabled then
				r.beam.Transparency = NumberSequence.new(ribTrans)
				r.core.Transparency = NumberSequence.new(math.min(1, ribTrans + 0.15))
				r.beam.Brightness = ribBright
				r.beam.TextureSpeed = ribSpeed
			end
		end
	end

	-- 7. Dynamic crackling reactor lightning arcs (jump up to levitating crystal on inspect!)
	if #state.arcs > 0 and not reduced then
		if t >= state.nextArcAt then
			local gap = if state.levitate > 0.25 or state.heat > 0.35
				then 0.08 + math.random() * 0.14
				else 0.45 + math.random() * 0.95
			state.nextArcAt = t + gap
			local pick = state.arcs[math.random(1, #state.arcs)]
			pick.until_ = t + 0.07 + math.random() * 0.06
		end
		for _, a in state.arcs do
			local on = t < a.until_ and adsAlpha < 0.65 and state.drain < 0.8
			if a.beam.Parent then
				a.beam.Enabled = on
				if on then
					a.a1.Position = a.base1 + upDir * levY
					a.beam.CurveSize0 = (math.random() - 0.5) * 0.08 * state.scale
					a.beam.CurveSize1 = (math.random() - 0.5) * 0.08 * state.scale
				end
			end
		end
	end

	-- 8. Step per-shot travelling barrel pulse ring
	if state.pulse and state.pulse.active then
		state.pulse.age += dt
		local u = state.pulse.age / CFG.PULSE_TIME
		if u >= 1 then
			state.pulse.active = false
		else
			state.pulse.attach.Position = state.pulse.startPos:Lerp(state.pulse.endPos, u)
		end
	end

	-- 9. Step sweeping barrel plasma wave (Draw / CowlSlam / Inspect)
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

	-- 10. Toggle 360-roll plasma trails cleanly
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
	state.coreLight = nil
	state.coreSparks = nil
	state.coreArcs = nil
	state.magBurst = nil
	state.magFormer = nil
	state.pulse = nil
	state.sweep = nil
end

return RiftforgeEffects
