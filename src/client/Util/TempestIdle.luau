--!strict
-- Tempest-Strike idle (first-person camera gun only): two laminar water ribbons
-- run down the fore-end into the fluted sleeve, a short ring of water circulates
-- around the stock hub, and sparse white-cyan arcs flick out of the handguard
-- vents. Everything eases down while aiming so the crescent stays clear.
-- Anchors are placed in the Handle's space from Blender coordinates
-- (Roblox X, Y, Z = -Blender Y, Blender Z, -Blender X), scaled with the viewmodel.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local StateValues = require(Shared.StateValues)
local Style = require(Shared.Config.SkinPreview).TEMPEST
local VFX = require(Shared.Config.VfxTextures)
local UiMotion = require(Shared.UiMotion)

type Ribbon = { beam: Beam, speed: number, body: boolean }
export type State = {
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

local function anchor(handle: BasePart, name: string, p: Vector3, scale: number): Attachment
	local a = Instance.new("Attachment")
	a.Name = name
	a.Position = p * scale
	a.Parent = handle
	return a
end

local function scaleOf(width: number): number
	return width / Style.RIBBON_WIDTH
end

local function ribbon(
	state: State,
	a0: Attachment,
	a1: Attachment,
	width: number,
	curve0: number,
	curve1: number,
	speed: number
)
	-- the water body: a continuous thin line
	local beam = Instance.new("Beam")
	beam.Name = "TempestWater"
	beam.Attachment0, beam.Attachment1 = a0, a1
	beam.Texture = ""
	beam.Color = ColorSequence.new(Style.WATER)
	beam.Transparency = NumberSequence.new(Style.RIBBON_BODY)
	beam.LightEmission = 0.85
	beam.LightInfluence = 0
	beam.Brightness = 1.3
	beam.FaceCamera = true
	beam.Width0, beam.Width1 = width, width
	beam.Segments = 4
	beam.CurveSize0, beam.CurveSize1 = curve0, curve1
	beam.Enabled = false
	beam.Parent = a0
	table.insert(state.ribbons, { beam = beam, speed = 0, body = true })
	-- the flow: bright streaks scrolling along it
	local flow = beam:Clone()
	flow.Name = "TempestFlow"
	flow.Texture = VFX.RECON_TRAIL
	flow.TextureMode = Enum.TextureMode.Wrap
	flow.TextureLength = Style.FLOW_TILE * scaleOf(width)
	flow.TextureSpeed = speed
	flow.Color = ColorSequence.new(Style.WATER_EDGE, Style.WATER)
	flow.Transparency = NumberSequence.new(0)
	flow.Width0, flow.Width1 = width * 0.8, width * 0.8
	flow.Parent = a0
	table.insert(state.ribbons, { beam = flow, speed = speed, body = false })
end

local function spark(state: State, at: Attachment, scale: number)
	local e = Instance.new("ParticleEmitter")
	e.Name = "TempestArc"
	e.Texture = VFX.SPARK
	e.Color = ColorSequence.new(Style.WATER_EDGE, Style.WATER)
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Brightness = 2
	e.Rate = Style.SPARK_RATE
	e.Lifetime = Style.SPARK_LIFE
	e.Speed = NumberRange.new(0.5 * scale, 1.1 * scale)
	e.Drag = 6
	e.SpreadAngle = Vector2.new(55, 55)
	e.EmissionDirection = Enum.NormalId.Top
	e.Orientation = Enum.ParticleOrientation.VelocityParallel
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, Style.SPARK_SIZE * scale),
		NumberSequenceKeypoint.new(1, Style.SPARK_SIZE * 0.25 * scale),
	})
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.6, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.LockedToPart = true
	e.ZOffset = 0.02 * scale
	e.Enabled = false
	e.Parent = at
	table.insert(state.sparks, e)
end

function TempestIdle.new(model: Model, scale: number): State?
	if StateValues.get(model, "SkinLine") ~= Style.LINE then
		return nil
	end
	local handle = model.PrimaryPart
	if not handle then
		return nil
	end
	local state: State = { ribbons = {}, sparks = {}, light = nil, clock = 0, weight = 0 }
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
					handle,
					"TempestHelix" .. i,
					bl(x, ry * math.cos(angle), zc + rz * math.sin(angle)),
					scale
				)
			)
		end
		for i = 1, N do
			ribbon(state, points[i], points[i + 1], w, 0, 0, Style.RIBBON_SPEED)
		end
	end
	-- arcs flick up off the top of the handguard
	for i, x in { 1.24, 1.58 } do
		local top = anchor(handle, "TempestArc" .. i, bl(x, 0, 0.418), scale)
		top.Axis = Vector3.new(0, 0, -1)
		top.SecondaryAxis = Vector3.new(0, 1, 0)
		spark(state, top, scale)
	end
	-- stock hub ring: six short spans around the top bar, scrolling one way = circulation
	local ring: { Attachment } = {}
	local n = 6
	for i = 0, n - 1 do
		local t = (i / n) * 2 * math.pi
		local p =
			bl(-0.985, math.cos(t) * Style.RING_RADIUS, 0.371 + math.sin(t) * Style.RING_RADIUS)
		table.insert(ring, anchor(handle, "TempestRing" .. i, p, scale))
	end
	for i = 1, n do
		ribbon(
			state,
			ring[i],
			ring[i % n + 1],
			w * 0.8,
			0.006 * scale,
			-0.006 * scale,
			Style.RING_SPEED
		)
	end
	local glow = anchor(handle, "TempestGlow", bl(1.30, 0, 0.30), scale)
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
			r.beam.Brightness = (if r.body then 1.3 else 1.7) * opacity
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
