--!strict
-- Riftfang Legendary Knife (Riftforge melee slot, first person — XEROFANG-inspired).
--
-- Drives all 5 articulated moving parts + motion-synced VFX on the Riftfang dagger:
--   1. SK_Root_CoreCrystal : spinning faceted violet plasma crystal inside the crossguard eye
--   2. SK_Root_CoreRing    : counter-rotating machined-steel gimbal ring orbiting the crystal
--   3. SK_Root_Scale1/2/3  : three overlapping dorsal spine armor scales driven by staggered
--                            mechanical springs — rippling open (1 -> 2 -> 3) on Draw, Slash
--                            apex, Heavy coil charge, and Inspect, then SLAMMING shut!
--   4. Scrolling RiftforgePlasmaLayer surface textures along the blade fuller & spine core
--   5. Sleek razor-thin Plasma Edge Halo Beam + dynamic STIM_BOLT lightning arcs climbing
--      from crossguard -> Scale1 -> Scale2 -> Scale3 -> blade tip
--   6. 12-segment 3D Plasma Halo Ring racing guard -> tip on Draw lock & Inspect wave, and
--      orbiting the crossguard during the 360-deg pommel-ring finger-twirl!
--   7. Dual-layer violet plasma Slash Trails + crossguard PointLight + tip sparks + hit flare!

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local SkinPreview = require(Shared.Config.SkinPreview)
local StateValues = require(Shared.StateValues)
local SettingsApply = require(Shared.SettingsApply)
local UiMotion = require(Shared.UiMotion)

local CFG = SkinPreview.RIFTFORGE
local RING_PTS = 12

-- Exact Blender-space anchors matching tools/blender/model_riftforge_knife_v02.py
local GUARD_BL = Vector3.new(0.285, 0.0, 0.000)
local SCALE_PIVOTS_BL = {
	Vector3.new(0.455, 0.0, 0.088), -- Scale1 rear hinge
	Vector3.new(0.660, 0.0, 0.084), -- Scale2 mid hinge
	Vector3.new(0.875, 0.0, 0.072), -- Scale3 front hinge
}
local SCALE_HINGE_Y = { 0.022, 0.021, 0.019 } -- V-split lateral hinge offsets (L=+Y, R=-Y)
local BLADE_BASE_BL = Vector3.new(0.455, 0.0, -0.095)
local BLADE_MID_BL = Vector3.new(0.950, 0.0, -0.092)
local BLADE_TIP_BL = Vector3.new(1.392, 0.0, 0.009)
local SPINE_TIP_BL = Vector3.new(1.130, 0.0, 0.056)

type WeldEntry = {
	weld: Weld,
	pivotInPart0: CFrame,
	fromPivot: CFrame,
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
	-- Articulated weld groups
	crystals: { WeldEntry },
	rings: { WeldEntry },
	scales: { { WeldEntry } }, -- fallback unsplit Scale1..3 (v01)
	scalesL: { { WeldEntry } }, -- [1..3] left V-split dorsal scales (v02 Scale1L/2L/3L)
	scalesR: { { WeldEntry } }, -- [1..3] right V-split dorsal scales (v02 Scale1R/2R/3R)
	scalePos: { number },
	scaleVel: { number },
	glowParts: { BasePart },
	plasmaTextures: { Texture },
	-- Owned VFX
	owned: { Instance },
	halo: HaloRing?,
	edgeBeams: { Beam },
	bolts: { Beam },
	trails: { Trail },
	guardLight: PointLight?,
	tipSparks: ParticleEmitter?,
	tipBurst: ParticleEmitter?,
	-- Kinematics & timeline state
	clock: number,
	crystalAngle: number,
	ringAngle: number,
	crystalVel: number,
	ringVel: number,
	surge: number,
	flare: number,
	nextBoltAt: number,
	boltUntil: number,
	drawSlammed: boolean,
	inspectWaved: boolean,
	inspectSlammed: boolean,
	haloSweepAge: number,
	haloSweepDur: number,
	haloPopped: boolean,
}

local RiftfangKnife = {}

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

local function makeHalo(state: State, width: number): HaloRing
	local halo: HaloRing = { points = {}, beams = {}, cores = {} }
	for i = 1, RING_PTS do
		local a = Instance.new("Attachment")
		a.Name = "RiftfangHaloPt_" .. i
		a.Parent = state.body
		table.insert(state.owned, a)
		table.insert(halo.points, a)
	end
	for i = 1, RING_PTS do
		local b = Instance.new("Beam")
		b.Name = "RiftfangHaloBeam_" .. i
		b.Attachment0 = halo.points[i]
		b.Attachment1 = halo.points[i % RING_PTS + 1]
		b.Texture = CFG.RIBBON_TEXTURE
		b.TextureMode = Enum.TextureMode.Wrap
		b.TextureLength = 0.36 * state.scale
		b.TextureSpeed = 4.6
		b.Color = ColorSequence.new(CFG.PLASMA_EDGE, CFG.PLASMA)
		b.Transparency = NumberSequence.new(0.14)
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
		c.Name = "RiftfangHaloCore_" .. i
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

function RiftfangKnife.new(model: Model, scale: number): State?
	if StateValues.get(model, "SkinLine") ~= CFG.LINE then
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

	local state: State = {
		model = model,
		body = body,
		handle = handle,
		scale = scale,
		crystals = {},
		rings = {},
		scales = { {}, {}, {} },
		scalesL = { {}, {}, {} },
		scalesR = { {}, {}, {} },
		scalePos = { 0.95, 0.95, 0.95 }, -- V-flared open on Draw, ripple-slam shut!
		scaleVel = { 0, 0, 0 },
		glowParts = {},
		plasmaTextures = {},
		owned = {},
		halo = nil,
		edgeBeams = {},
		bolts = {},
		trails = {},
		guardLight = nil,
		tipSparks = nil,
		tipBurst = nil,
		clock = 0,
		crystalAngle = 0,
		ringAngle = 0,
		crystalVel = 2.2,
		ringVel = -1.8,
		surge = 0.8,
		flare = 0,
		nextBoltAt = 0.4,
		boltUntil = 0,
		drawSlammed = false,
		inspectWaved = false,
		inspectSlammed = false,
		haloSweepAge = -1,
		haloSweepDur = 0.24,
		haloPopped = false,
	}

	local guardPivot = toBodyPos(handle, body, scale, GUARD_BL)
	local scalePivots = {
		toBodyPos(handle, body, scale, SCALE_PIVOTS_BL[1]),
		toBodyPos(handle, body, scale, SCALE_PIVOTS_BL[2]),
		toBodyPos(handle, body, scale, SCALE_PIVOTS_BL[3]),
	}
	local scalePivotsL = {
		toBodyPos(handle, body, scale, SCALE_PIVOTS_BL[1] + Vector3.new(0, SCALE_HINGE_Y[1], 0)),
		toBodyPos(handle, body, scale, SCALE_PIVOTS_BL[2] + Vector3.new(0, SCALE_HINGE_Y[2], 0)),
		toBodyPos(handle, body, scale, SCALE_PIVOTS_BL[3] + Vector3.new(0, SCALE_HINGE_Y[3], 0)),
	}
	local scalePivotsR = {
		toBodyPos(handle, body, scale, SCALE_PIVOTS_BL[1] - Vector3.new(0, SCALE_HINGE_Y[1], 0)),
		toBodyPos(handle, body, scale, SCALE_PIVOTS_BL[2] - Vector3.new(0, SCALE_HINGE_Y[2], 0)),
		toBodyPos(handle, body, scale, SCALE_PIVOTS_BL[3] - Vector3.new(0, SCALE_HINGE_Y[3], 0)),
	}

	for _, desc in model:GetDescendants() do
		if desc:IsA("Texture") and desc:GetAttribute("RiftforgePlasmaLayer") then
			table.insert(state.plasmaTextures, desc)
		elseif desc:IsA("BasePart") then
			local name = desc.Name
			if desc.Material == Enum.Material.Neon then
				table.insert(state.glowParts, desc)
			end
			local weld = desc:FindFirstChild("SkinCosmeticWeld")
			if weld and weld:IsA("Weld") and weld.Part0 == body then
				if name:find("CoreCrystal") then
					table.insert(state.crystals, makeEntry(weld, guardPivot))
				elseif name:find("CoreRing") then
					table.insert(state.rings, makeEntry(weld, guardPivot))
				else
					for idx = 1, 3 do
						local tag = "Scale" .. idx
						if name:find(tag .. "L") then
							table.insert(state.scalesL[idx], makeEntry(weld, scalePivotsL[idx]))
							break
						elseif name:find(tag .. "R") then
							table.insert(state.scalesR[idx], makeEntry(weld, scalePivotsR[idx]))
							break
						elseif name:find(tag) then
							table.insert(state.scales[idx], makeEntry(weld, scalePivots[idx]))
							break
						end
					end
				end
			end
		end
	end

	-- Crossguard plasma light
	local guardAtt = makeAnchor(state, "RiftfangGuardAtt", GUARD_BL)
	local light = Instance.new("PointLight")
	light.Name = "RiftfangGuardLight"
	light.Color = CFG.LIGHT_COLOR
	light.Brightness = 0.55
	light.Range = 2.2 * scale
	light.Shadows = false
	light.Parent = guardAtt
	state.guardLight = light
	table.insert(state.owned, light)

	if not UiMotion.reduced() then
		-- 1. 3D Plasma Halo Ring
		state.halo = makeHalo(state, 0.045 * scale)

		-- 2. Sleek narrow Plasma Edge Sheath hugging the blade cutting edge (never blocks geometry!)
		local e0 = makeAnchor(state, "RFK_Edge0", BLADE_BASE_BL)
		local e1 = makeAnchor(state, "RFK_Edge1", BLADE_MID_BL)
		local e2 = makeAnchor(state, "RFK_Edge2", BLADE_TIP_BL)
		for idx, pair in { { e0, e1 }, { e1, e2 } } do
			local b = Instance.new("Beam")
			b.Name = "RiftfangEdgeGlow_" .. idx
			b.Attachment0 = pair[1]
			b.Attachment1 = pair[2]
			b.Texture = CFG.RIBBON_TEXTURE
			b.TextureMode = Enum.TextureMode.Wrap
			b.TextureLength = 0.55 * scale
			b.TextureSpeed = 3.2
			b.Color = ColorSequence.new(CFG.PLASMA_EDGE, CFG.PLASMA)
			b.Transparency = NumberSequence.new(0.42)
			b.LightEmission = 1
			b.LightInfluence = 0
			b.Brightness = 1.9
			b.FaceCamera = true
			b.Width0 = (if idx == 1 then 0.036 else 0.032) * scale
			b.Width1 = (if idx == 1 then 0.032 else 0.012) * scale
			b.Segments = 4
			b.Parent = pair[1]
			table.insert(state.owned, b)
			table.insert(state.edgeBeams, b)
		end

		-- 3. Spine Lightning Bolts (STIM_BOLT crackling Guard -> Scales -> Tip!)
		local s0 = makeAnchor(state, "RFK_Spine0", GUARD_BL + Vector3.new(0.06, 0, 0.08))
		local s1 = makeAnchor(state, "RFK_Spine1", Vector3.new(0.76, 0, 0.135))
		local s2 = makeAnchor(state, "RFK_Spine2", BLADE_TIP_BL)
		for idx, pair in { { s0, s1 }, { s1, s2 } } do
			local bolt = Instance.new("Beam")
			bolt.Name = "RiftfangSpineBolt_" .. idx
			bolt.Attachment0 = pair[1]
			bolt.Attachment1 = pair[2]
			bolt.Texture = CFG.BOLT_TEXTURE
			bolt.TextureMode = Enum.TextureMode.Stretch
			bolt.Color = ColorSequence.new(CFG.PLASMA_EDGE, CFG.PLASMA)
			bolt.LightEmission = 1
			bolt.LightInfluence = 0
			bolt.Brightness = 2.8
			bolt.FaceCamera = true
			bolt.Width0 = 0.042 * scale
			bolt.Width1 = 0.030 * scale
			bolt.Segments = 3
			bolt.Enabled = false
			bolt.Parent = pair[1]
			table.insert(state.owned, bolt)
			table.insert(state.bolts, bolt)
		end

		-- 4. Dual-layer Blade Slash Trails (deep plasma ribbon + razor lilac-white edge!)
		local tBase = makeAnchor(state, "RFK_TrailBase", BLADE_BASE_BL)
		local tTip = makeAnchor(state, "RFK_TrailTip", BLADE_TIP_BL)
		local bodyTrail = Instance.new("Trail")
		bodyTrail.Name = "RiftfangBodyTrail"
		bodyTrail.Attachment0 = tBase
		bodyTrail.Attachment1 = tTip
		bodyTrail.Texture = CFG.RIBBON_TEXTURE
		bodyTrail.TextureMode = Enum.TextureMode.Stretch
		bodyTrail.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, CFG.PLASMA_EDGE),
			ColorSequenceKeypoint.new(0.4, CFG.PLASMA),
			ColorSequenceKeypoint.new(1, CFG.PLASMA_DEEP),
		})
		bodyTrail.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.12),
			NumberSequenceKeypoint.new(0.55, 0.45),
			NumberSequenceKeypoint.new(1, 1),
		})
		bodyTrail.LightEmission = 1
		bodyTrail.LightInfluence = 0
		bodyTrail.Brightness = 2.2
		bodyTrail.Lifetime = 0.16
		bodyTrail.MinLength = 0.025
		bodyTrail.Enabled = false
		bodyTrail.Parent = tTip
		table.insert(state.owned, bodyTrail)
		table.insert(state.trails, bodyTrail)

		local tSpineTip = makeAnchor(state, "RFK_TrailEdgeInner", SPINE_TIP_BL)
		local edgeTrail = Instance.new("Trail")
		edgeTrail.Name = "RiftfangEdgeTrail"
		edgeTrail.Attachment0 = tSpineTip
		edgeTrail.Attachment1 = tTip
		edgeTrail.Texture = CFG.BOLT_TEXTURE
		edgeTrail.TextureMode = Enum.TextureMode.Stretch
		edgeTrail.Color = ColorSequence.new(CFG.PLASMA_EDGE, CFG.PLASMA)
		edgeTrail.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.04),
			NumberSequenceKeypoint.new(0.5, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		})
		edgeTrail.LightEmission = 1
		edgeTrail.LightInfluence = 0
		edgeTrail.Brightness = 2.6
		edgeTrail.Lifetime = 0.13
		edgeTrail.MinLength = 0.02
		edgeTrail.Enabled = false
		edgeTrail.Parent = tTip
		table.insert(state.owned, edgeTrail)
		table.insert(state.trails, edgeTrail)

		-- 5. Tip ambient plasma sparks + impact/wave burst!
		local sparks = Instance.new("ParticleEmitter")
		sparks.Name = "RiftfangTipSparks"
		sparks.Texture = CFG.SPARK_TEXTURE
		sparks.Color = ColorSequence.new(CFG.PLASMA_EDGE, CFG.PLASMA)
		sparks.LightEmission = 1
		sparks.LightInfluence = 0
		sparks.Brightness = 2.0
		sparks.Lifetime = NumberRange.new(0.18, 0.34)
		sparks.Speed = NumberRange.new(0.20 * scale, 0.52 * scale)
		sparks.Drag = 4
		sparks.SpreadAngle = Vector2.new(180, 180)
		sparks.Orientation = Enum.ParticleOrientation.VelocityParallel
		sparks.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.014 * scale),
			NumberSequenceKeypoint.new(0.4, 0.040 * scale),
			NumberSequenceKeypoint.new(1, 0),
		})
		sparks.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.05),
			NumberSequenceKeypoint.new(0.65, 0.25),
			NumberSequenceKeypoint.new(1, 1),
		})
		sparks.Rate = SettingsApply.vfxCount(3)
		sparks.LockedToPart = true
		sparks.Parent = tTip
		state.tipSparks = sparks
		table.insert(state.owned, sparks)

		local burst = Instance.new("ParticleEmitter")
		burst.Name = "RiftfangTipBurst"
		burst.Texture = CFG.ARC_TEXTURE
		burst.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
		burst.FlipbookMode = Enum.ParticleFlipbookMode.Random
		burst.Color = ColorSequence.new(CFG.PLASMA_EDGE, CFG.PLASMA)
		burst.LightEmission = 1
		burst.LightInfluence = 0
		burst.Brightness = 2.4
		burst.Lifetime = NumberRange.new(0.08, 0.14)
		burst.Speed = NumberRange.new(0.4 * scale, 1.4 * scale)
		burst.Drag = 6
		burst.SpreadAngle = Vector2.new(180, 180)
		burst.Size = NumberSequence.new(0.20 * scale)
		burst.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.55, 0.22),
			NumberSequenceKeypoint.new(1, 1),
		})
		burst.Rate = 0
		burst.Enabled = false
		burst.LockedToPart = true
		burst.Parent = tTip
		state.tipBurst = burst
		table.insert(state.owned, burst)
	end

	return state
end

function RiftfangKnife.hit(state: State)
	state.flare = 1.0
	state.surge = 1.0
	state.crystalVel += 18.0
	state.ringVel -= 15.0
	state.boltUntil = state.clock + 0.16
	for i = 1, 3 do
		state.scaleVel[i] += 12.0
	end
	if state.tipBurst and not UiMotion.reduced() then
		state.tipBurst:Emit(SettingsApply.vfxCount(5))
	end
	if state.tipSparks and not UiMotion.reduced() then
		state.tipSparks:Emit(SettingsApply.vfxCount(8))
	end
end

local function triggerSweep(state: State, duration: number)
	if UiMotion.reduced() then
		return
	end
	state.haloSweepAge = 0
	state.haloSweepDur = duration
	state.haloPopped = false
end

function RiftfangKnife.step(
	state: State,
	dt: number,
	visible: boolean,
	drawProgress: number?,
	inspectProgress: number?,
	swingProgress: number?,
	swingHit: number?,
	heavy: boolean?
)
	state.clock += dt
	local t = state.clock
	local reduced = UiMotion.reduced()

	local drag = math.exp(-3.6 * dt)
	state.crystalVel = 2.2 + (state.crystalVel - 2.2) * drag
	state.ringVel = -1.8 + (state.ringVel - -1.8) * drag
	state.surge = math.max(0, state.surge - 3.2 * dt)
	state.flare = math.max(0, state.flare - 5.5 * dt)

	local scaleTargets = { 0.0, 0.0, 0.0 }
	local trailOn = false
	local haloOrbit = false

	-- 1. DRAW: Palm-flip plasma trails (0.00..0.44), scales ripple open then SLAM shut at 0.46!
	if drawProgress ~= nil then
		if drawProgress < 0.46 then
			trailOn = true
			for i = 1, 3 do
				-- Staggered closing wave as draw approaches lock!
				local shutAt = 0.34 + (i - 1) * 0.055
				scaleTargets[i] = if drawProgress < shutAt then 0.85 else 0.0
			end
		elseif not state.drawSlammed then
			state.drawSlammed = true
			state.surge = 1.0
			state.crystalVel += 14.0
			state.ringVel -= 12.0
			state.boltUntil = t + 0.14
			triggerSweep(state, 0.22)
		end
	else
		state.drawSlammed = false
	end

	-- 2. SLASH / HEAVY LUNGE: Predatory scale flare + razor plasma trails!
	if swingProgress ~= nil then
		local hAt = swingHit or 0.28
		if heavy then
			-- Heavy coil: staggered wave flare 1 -> 2 -> 3 charging with lightning before lunge!
			if swingProgress < hAt + 0.04 then
				for i = 1, 3 do
					local openAt = 0.05 + (i - 1) * 0.07
					if swingProgress >= openAt then
						scaleTargets[i] = 1.15
					end
				end
				state.surge = math.max(state.surge, 0.85)
				state.boltUntil = math.max(state.boltUntil, t + 0.06)
			end
			if swingProgress >= hAt - 0.12 and swingProgress <= hAt + 0.24 then
				trailOn = true
			end
		else
			-- Light slash: quick predatory scale pop around strike apex!
			if swingProgress >= hAt - 0.10 and swingProgress <= hAt + 0.18 then
				trailOn = true
				for i = 1, 3 do
					scaleTargets[i] = 0.72
				end
				state.surge = math.max(state.surge, 0.55)
			end
		end
	end

	-- 3. INSPECT (3.4s natural wrist-roll showcase):
	--    Staggered 1->2->3 V-split scale ripple open -> wrist-roll guard->tip plasma wave sweep ->
	--    upright crystal halo showcase -> crisp 0.78 staggered V-scale SLAM lock & double tip spark pop!
	if inspectProgress ~= nil then
		if inspectProgress >= 0.06 and inspectProgress < 0.78 then
			for i = 1, 3 do
				local openAt = 0.07 + (i - 1) * 0.055
				if inspectProgress >= openAt then
					-- Pronounced living harmonic wave rippling down the 3 V-split armor plates!
					scaleTargets[i] = 1.02 + 0.18 * math.sin(t * 8.0 - i * 1.15)
				end
			end
			state.crystalVel = math.max(state.crystalVel, 18.0)
			state.ringVel = math.min(state.ringVel, -15.5)
			state.surge = math.max(state.surge, 0.65)
		elseif inspectProgress >= 0.78 and not state.inspectSlammed then
			state.inspectSlammed = true
			state.surge = 1.0
			state.flare = 0.85
			state.crystalVel += 16.0
			state.ringVel -= 14.0
			state.boltUntil = t + 0.22
			for i = 1, 3 do
				state.scaleVel[i] = -22.0
			end
			if state.tipBurst and not reduced then
				state.tipBurst:Emit(SettingsApply.vfxCount(6))
			end
			if state.tipSparks and not reduced then
				state.tipSparks:Emit(SettingsApply.vfxCount(8))
			end
		end
		if inspectProgress >= 0.40 and inspectProgress <= 0.54 then
			trailOn = true
		end
		if inspectProgress >= 0.41 and not state.inspectWaved then
			state.inspectWaved = true
			state.surge = 1.0
			state.crystalVel += 10.0
			state.ringVel -= 9.0
			state.boltUntil = math.max(state.boltUntil, t + 0.24)
			triggerSweep(state, 0.26)
		end
		if inspectProgress >= 0.54 and inspectProgress <= 0.76 then
			haloOrbit = true
		end
	else
		state.inspectWaved = false
		state.inspectSlammed = false
	end

	-- Idle subtle living-machine micro-breathe on scales
	if drawProgress == nil and inspectProgress == nil and swingProgress == nil then
		for i = 1, 3 do
			local wave = math.max(0, math.sin(t * 2.1 - i * 0.65) - 0.65) * 0.35
			scaleTargets[i] = math.max(scaleTargets[i], wave)
		end
	end

	-- Step springs & gyros
	local dtClamped = math.min(dt, 0.05)
	state.crystalAngle += state.crystalVel * dt
	state.ringAngle += state.ringVel * dt
	for i = 1, 3 do
		state.scalePos[i], state.scaleVel[i] =
			stepSpring(state.scalePos[i], state.scaleVel[i], scaleTargets[i], 20.0, 0.46, dtClamped)
		state.scalePos[i] = math.clamp(state.scalePos[i], -0.06, 1.35)
	end

	-- Basis vectors in Root body space
	local guardP = toBodyPos(state.handle, state.body, state.scale, GUARD_BL)
	local upDir = (toBodyPos(
		state.handle,
		state.body,
		state.scale,
		GUARD_BL + Vector3.new(0, 0, 0.2)
	) - guardP).Unit
	local fwdDir = (toBodyPos(
		state.handle,
		state.body,
		state.scale,
		GUARD_BL + Vector3.new(0.2, 0, 0)
	) - guardP).Unit
	local leftAxis = (toBodyPos(
		state.handle,
		state.body,
		state.scale,
		GUARD_BL + Vector3.new(0, 0.2, 0)
	) - guardP).Unit

	-- 1. Crossguard CoreCrystal + counter-rotating CoreRing
	local crysDelta = CFrame.fromAxisAngle(upDir, state.crystalAngle)
		* CFrame.fromAxisAngle(fwdDir, state.crystalAngle * 0.6)
	applyPivot(state.crystals, crysDelta)

	local ringDelta = CFrame.fromAxisAngle(fwdDir, state.ringAngle * 0.8)
		* CFrame.fromAxisAngle(leftAxis, state.ringAngle * 0.55)
	applyPivot(state.rings, ringDelta)

	-- 2. Three articulated dorsal spine scales:
	--    v02 paired L/R scales flare OUTWARD in a concept-faithful V-split (±28 deg roll + splay + lift + pitch!)
	--    exposing the blazing violet plasma core channel between them! (Falls back cleanly to v01 unsplit scales.)
	for i = 1, 3 do
		local open = math.max(0, state.scalePos[i])
		local lift = open * 0.024 * state.scale
		local splay = open * 0.022 * state.scale
		local roll = open * math.rad(28)
		local pitch = open * math.rad(16)
		if #state.scalesL[i] > 0 or #state.scalesR[i] > 0 then
			local deltaL = CFrame.new(upDir * lift + leftAxis * splay)
				* CFrame.fromAxisAngle(fwdDir, -roll)
				* CFrame.fromAxisAngle(leftAxis, -pitch)
			local deltaR = CFrame.new(upDir * lift - leftAxis * splay)
				* CFrame.fromAxisAngle(fwdDir, roll)
				* CFrame.fromAxisAngle(leftAxis, -pitch)
			applyPivot(state.scalesL[i], deltaL)
			applyPivot(state.scalesR[i], deltaR)
		end
		if #state.scales[i] > 0 then
			local delta = CFrame.new(upDir * (open * 0.026 * state.scale))
				* CFrame.fromAxisAngle(leftAxis, -(open * math.rad(20)))
			applyPivot(state.scales[i], delta)
		end
	end

	-- 3. Scroll RiftforgePlasmaLayer surface textures along the blade!
	local scrollBoost = 1 + state.surge * 3.0 + state.flare * 4.0
	for _, tex in state.plasmaTextures do
		if tex.Parent then
			tex.OffsetStudsU = (tex.OffsetStudsU + 0.36 * scrollBoost * dt) % 10
			tex.OffsetStudsV = (tex.OffsetStudsV + 0.16 * scrollBoost * dt) % 10
		end
	end

	-- 4. Glow parts, PointLight & Edge Sheath
	local energy = math.clamp(state.surge * 0.75 + state.flare, 0, 1)
	local pulseWave = 0.5 + 0.5 * math.sin(t * 4.5)
	local col = CFG.CORE_IDLE_COLOR:Lerp(CFG.CORE_HOT_COLOR, energy * 0.85 + pulseWave * 0.14)
	for _, p in state.glowParts do
		if p.Parent then
			p.Color = col
		end
	end
	if state.guardLight and state.guardLight.Parent then
		state.guardLight.Enabled = visible
		state.guardLight.Brightness = 0.45 + 0.18 * pulseWave + 1.15 * energy
		state.guardLight.Color = CFG.LIGHT_COLOR:Lerp(CFG.LIGHT_HOT_COLOR, energy * 0.75)
	end
	for _, eb in state.edgeBeams do
		if eb.Parent then
			eb.Enabled = visible and not reduced
			if eb.Enabled then
				eb.Brightness = 1.7 + energy * 1.4
				eb.Transparency = NumberSequence.new(math.clamp(0.48 - energy * 0.32, 0.10, 0.85))
			end
		end
	end

	-- 5. Dynamic Spine Lightning Bolts (crackle periodically at idle, flare on heavy/inspect/hit!)
	if #state.bolts > 0 and not reduced then
		if t >= state.nextBoltAt then
			state.nextBoltAt = t
				+ (if energy > 0.3 then 0.12 + math.random() * 0.18 else 0.55 + math.random() * 1.1)
			state.boltUntil = math.max(state.boltUntil, t + 0.08 + math.random() * 0.06)
		end
		local on = visible and t < state.boltUntil
		for _, bolt in state.bolts do
			if bolt.Parent then
				bolt.Enabled = on
				if on then
					bolt.CurveSize0 = (math.random() - 0.5) * 0.06 * state.scale
					bolt.CurveSize1 = (math.random() - 0.5) * 0.06 * state.scale
				end
			end
		end
	end

	-- 6. 3D Plasma Halo Ring (Draw/Inspect guard->tip wave OR 360 twirl crossguard orbit!)
	if state.halo and visible and not reduced then
		local haloActive = false
		if state.haloSweepAge >= 0 then
			state.haloSweepAge += dt
			local u = state.haloSweepAge / state.haloSweepDur
			if u >= 1 then
				state.haloSweepAge = -1
				if not state.haloPopped and state.tipBurst then
					state.haloPopped = true
					state.tipBurst:Emit(SettingsApply.vfxCount(4))
				end
			else
				haloActive = true
				local tipP = toBodyPos(state.handle, state.body, state.scale, BLADE_TIP_BL)
				local pos = guardP:Lerp(tipP, u)
				local rad = (0.14 - 0.07 * u) * state.scale
				poseHalo(
					state.halo,
					pos,
					leftAxis,
					upDir,
					rad,
					t * 10.0,
					math.sin(u * math.pi),
					0.044 * state.scale
				)
			end
		end
		if not haloActive and haloOrbit then
			haloActive = true
			poseHalo(
				state.halo,
				guardP,
				leftAxis,
				upDir,
				0.20 * state.scale,
				t * 12.0,
				0.88,
				0.042 * state.scale
			)
		end
		if not haloActive then
			hideHalo(state.halo)
		end
	else
		hideHalo(state.halo)
	end

	-- 7. Slash & flip Trails
	for _, tr in state.trails do
		if tr.Parent then
			tr.Enabled = visible and trailOn and not reduced
		end
	end
end

function RiftfangKnife.destroy(state: State)
	for _, inst in state.owned do
		pcall(function()
			if inst.Parent then
				inst:Destroy()
			end
		end)
	end
	table.clear(state.owned)
	table.clear(state.edgeBeams)
	table.clear(state.bolts)
	table.clear(state.trails)
	state.halo = nil
	state.guardLight = nil
	state.tipSparks = nil
	state.tipBurst = nil
end

return RiftfangKnife
