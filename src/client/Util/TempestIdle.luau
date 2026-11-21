--!strict
-- Tempest-Strike idle (first-person camera gun only): two laminar water ribbons
-- wrap the fore-end into the fluted sleeve, and sparse white-cyan arcs flick out of the handguard
-- vents. Everything eases down while aiming so the crescent stays clear.
-- Anchors are given in Blender coordinates (Roblox X, Y, Z = -Blender Y, Blender Z,
-- -Blender X) in the Handle's rest frame, scaled with the viewmodel, and parented to
-- the part the rig's Root motor drives: recoil, reload and inspect move that part,
-- not the Handle, so effects on the Handle were left behind (owner 2026-11-21).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local StateValues = require(Shared.StateValues)
local Style = require(Shared.Config.SkinPreview).TEMPEST
local VFX = require(Shared.Config.VfxTextures)
local UiMotion = require(Shared.UiMotion)

type Ribbon = { beam: Beam, speed: number, body: boolean }
type Glow = { part: BasePart, color: Color3 }
export type State = {
	glows: { Glow },
	ribbons: { Ribbon },
	sparks: { ParticleEmitter },
	light: PointLight?,
	clock: number,
	weight: number,
}

local TempestIdle = {}

local function bl(x: number, y: number, z: number): Vector3
	return Vector3.new(-y, z, -x)
end

type Frame = { handle: BasePart, body: BasePart, scale: number }

local function anchor(frame: Frame, name: string, p: Vector3): Attachment
	local a = Instance.new("Attachment")
	a.Name = name
	local world = frame.handle.CFrame:PointToWorldSpace(p * frame.scale)
	a.Position = frame.body.CFrame:PointToObjectSpace(world)
	a.Parent = frame.body
	return a
end

-- The part the stock rig's Root motor drives (everything visible is welded to it).
local function rootBody(model: Model): BasePart?
	local rig = model:FindFirstChild("Rig")
	local motors = rig and rig:FindFirstChild("Motors")
	local root = motors and motors:FindFirstChild("Root")
	if root and root:IsA("Motor6D") and root.Part1 then
		return root.Part1
	end
	return nil
end

local function scaleOf(width: number): number
	return width / Style.RIBBON_WIDTH
end

local function ribbon(
	state: State,
	a0: Attachment,
	a1: Attachment,
	width: number,
	speed: number,
	taper0: number,
	taper1: number
)
	local beam = Instance.new("Beam")
	beam.Name = "TempestWater"
	beam.Attachment0, beam.Attachment1 = a0, a1
	beam.Texture = VFX.TEMPEST_WATER_RIBBON
	beam.TextureMode = Enum.TextureMode.Wrap
	beam.TextureLength = Style.RIBBON_TILE * scaleOf(width)
	beam.TextureSpeed = speed
	beam.Color = ColorSequence.new(Style.WATER_EDGE, Style.WATER)
	beam.Transparency = NumberSequence.new(Style.RIBBON_BODY)
	beam.LightEmission = 0.9
	beam.LightInfluence = 0
	beam.Brightness = 1.4
	beam.FaceCamera = true
	beam.Width0, beam.Width1 = width * taper0, width * taper1
	beam.Segments = 4
	beam.Enabled = false
	beam.Parent = a0
	table.insert(state.ribbons, { beam = beam, speed = speed, body = false })
	-- the solid water core under the textured flow (keeps the line readable when the
	-- texture's thin streaks go sub-pixel)
	local core = beam:Clone()
	core.Name = "TempestWaterCore"
	core.Texture = ""
	core.Width0, core.Width1 = beam.Width0 * Style.CORE_WIDTH, beam.Width1 * Style.CORE_WIDTH
	core.Transparency = NumberSequence.new(Style.CORE_BODY)
	core.Color = ColorSequence.new(Style.WATER)
	core.Parent = a0
	table.insert(state.ribbons, { beam = core, speed = 0, body = true })
end

local function spark(state: State, at: Attachment, scale: number)
	local e = Instance.new("ParticleEmitter")
	e.Name = "TempestArc"
	e.Texture = VFX.TEMPEST_ARC_2x2
	e.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
	e.FlipbookMode = Enum.ParticleFlipbookMode.Random
	e.Color = ColorSequence.new(Style.ARC_CORE, Style.WATER)
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Brightness = 1.6
	e.Rate = Style.SPARK_RATE
	e.Lifetime = Style.SPARK_LIFE
	e.Speed = NumberRange.new(0)
	e.Rotation = NumberRange.new(-25, 25)
	e.Size = NumberSequence.new(Style.SPARK_SIZE * scale)
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.5, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.LockedToPart = true
	e.ZOffset = 0.03 * scale
	e.Enabled = false
	e.Parent = at
	table.insert(state.sparks, e)
end

function TempestIdle.new(model: Model, scale: number): State?
	if StateValues.get(model, "SkinLine") ~= Style.LINE then
		return nil
	end
	local handle = model.PrimaryPart
	local body = rootBody(model)
	if not handle or not body then
		return nil
	end
	local frame: Frame = { handle = handle, body = body, scale = scale }
	local state: State =
		{ glows = {}, ribbons = {}, sparks = {}, light = nil, clock = 0, weight = 0 }
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Material == Enum.Material.Neon then
			table.insert(state.glows, { part = d, color = d.Color })
		end
	end
	local w = Style.RIBBON_WIDTH * scale
	-- fore-end: two helices (half a turn apart) wrap the handguard and the fluted sleeve,
	-- passing over the top where the first-person camera looks
	local N = Style.HELIX_POINTS
	for _, start in { 0, math.pi } do
		local points: { Attachment } = {}
		for i = 0, N do
			local t = i / N
			local angle = start + t * 2 * math.pi * Style.HELIX_TURNS
			local ry = Style.HELIX_LIFT + 0.114 + (0.068 - 0.114) * t
			local rz = Style.HELIX_LIFT + 0.152 + (0.094 - 0.152) * t
			local zc = 0.300 + (0.314 - 0.300) * t
			local x = 1.08 + (2.02 - 1.08) * t
			table.insert(
				points,
				anchor(
					frame,
					"TempestHelix" .. i,
					bl(x, ry * math.cos(angle), zc + rz * math.sin(angle))
				)
			)
		end
		for i = 1, N do
			-- thin in at both ends of the helix, full width along the middle
			local t0, t1 = (i - 1) / N, i / N
			local taper = function(t: number): number
				return math.clamp(math.min(t, 1 - t) / 0.18, 0.25, 1)
			end
			ribbon(state, points[i], points[i + 1], w, Style.RIBBON_SPEED, taper(t0), taper(t1))
		end
	end
	-- arcs flick up off the top of the handguard
	for i, p in { bl(0.55, 0.098, 0.378), bl(1.30, 0, 0.418), bl(1.55, 0.084, 0.240) } do
		spark(state, anchor(frame, "TempestArc" .. i, p), scale)
	end
	local glow = anchor(frame, "TempestGlow", bl(1.20, 0.05, 0.36))
	local light = Instance.new("PointLight")
	light.Color = Style.WATER
	light.Brightness = 0
	light.Range = Style.LIGHT_RANGE * scale
	light.Shadows = false
	light.Parent = glow
	state.light = light
	return state
end

function TempestIdle.step(state: State, dt: number, visible: boolean, idle: boolean, ads: number)
	local reduced = UiMotion.reduced()
	local aim = math.clamp(ads, 0, 1)
	local target = if visible then (if idle then 1 else 0.6) else 0
	local s = math.min(dt, 0.1)
	state.weight = math.clamp(target, state.weight - s * 6, state.weight + s * 3)
	state.clock += s
	local on = visible and state.weight > 0.01
	-- ribbons: visible fade-in, thinned while aiming; reduced motion stops the scroll
	local opacity = state.weight * (1 - (1 - Style.ADS_RIBBON) * aim)
	for _, r in state.ribbons do
		r.beam.Enabled = on
		if on then
			r.beam.Brightness = (if r.body then 1.3 else Style.RIBBON_BRIGHTNESS) * opacity
				+ 0.15 * math.sin(state.clock * 2.1)
			r.beam.TextureSpeed = if reduced then 0 else r.speed
		end
	end
	local sparksOn = on and not reduced and aim < Style.ADS_SPARK_CUTOFF
	for _, e in state.sparks do
		if e.Enabled ~= sparksOn then
			e.Enabled = sparksOn
			if not sparksOn then
				e:Clear()
			end
		end
	end
	-- the cyan conduits breathe; a little brighter at hip, steady while aiming
	local breath = if reduced then 0.5 else 0.5 + 0.5 * math.sin(state.clock * Style.GLOW_RATE)
	for _, g in state.glows do
		g.part.Color = g.color:Lerp(Style.GLOW_PEAK, breath * Style.GLOW_MIX * (1 - 0.6 * aim))
	end
	local light = state.light
	if light then
		light.Enabled = on
		if on then
			light.Brightness = Style.LIGHT_BRIGHTNESS
				* opacity
				* (0.88 + 0.12 * math.sin(state.clock * 3.3))
		end
	end
end

return TempestIdle
