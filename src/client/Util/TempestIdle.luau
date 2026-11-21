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
type Ring = { points: { Attachment }, beams: { Beam }, cores: { Beam } }
export type State = {
	frame: Frame,
	toBody: CFrame,
	ring: Ring,
	burst: ParticleEmitter,
	well: Attachment,
	reloadPrev: number, -- reload progress last frame (-1 = not reloading)
	timing: { outAt: number, inAt: number, seat: number }?,
	shotAge: number,
	shotSign: number,
	popAge: number, -- seconds since the new magazine seated
	boost: number, -- conduit flare (shots, seat), decays
	drain: number, -- conduits dimmed while the magazine is out
	pose: CFrame,
	wellRest: Vector3,
	drawPrev: number?,
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

-- A loop of water (Beams between moving attachments) for the draw and inspect rings.
local function makeRing(state: State, n: number, width: number): Ring
	local ring: Ring = { points = {}, beams = {}, cores = {} }
	for i = 1, n do
		local a = Instance.new("Attachment")
		a.Name = "TempestRing" .. i
		a.Parent = state.frame.body
		table.insert(ring.points, a)
	end
	for i = 1, n do
		local b = Instance.new("Beam")
		b.Name = "TempestRingWater"
		b.Attachment0, b.Attachment1 = ring.points[i], ring.points[i % n + 1]
		b.Texture = VFX.TEMPEST_WATER_RIBBON
		b.TextureMode = Enum.TextureMode.Wrap
		b.TextureLength = Style.RIBBON_TILE * scaleOf(width)
		b.TextureSpeed = Style.RIBBON_SPEED * 1.6
		-- pure water cyan: the white edge colour washed the short ring segments to grey-white
		b.Color = ColorSequence.new(Style.WATER)
		b.LightEmission = 0.45
		b.LightInfluence = 0
		b.Brightness = Style.RING_BRIGHTNESS
		b.FaceCamera = true
		b.Width0, b.Width1 = width, width
		b.Segments = 3
		b.Enabled = false
		b.Parent = ring.points[i]
		table.insert(ring.beams, b)
		-- solid water core so the ring reads as one clean loop, not loose streaks
		local core = b:Clone()
		core.Name = "TempestRingCore"
		core.Texture = ""
		core.LightEmission = 0.5
		core.Width0, core.Width1 = width * Style.CORE_WIDTH, width * Style.CORE_WIDTH
		core.Parent = ring.points[i]
		table.insert(ring.cores, core)
	end
	return ring
end

-- Place the ring: centre and the two in-plane axes in Handle space (Blender units via bl),
-- radius r (model studs), spun by `spin`, opacity alpha.
local function placeRing(
	state: State,
	centre: Vector3,
	u: Vector3,
	v: Vector3,
	r: number,
	spin: number,
	alpha: number
)
	local n = #state.ring.points
	local k = state.frame.scale
	for i, a in state.ring.points do
		local t = spin + (i / n) * 2 * math.pi
		local p = centre + u * (r * math.cos(t)) + v * (r * math.sin(t))
		a.Position = state.toBody:PointToWorldSpace(p * k)
	end
	local on = alpha > 0.02
	for _, b in state.ring.beams do
		b.Enabled = on
		if on then
			b.Transparency = NumberSequence.new(1 - alpha)
		end
	end
	for _, b in state.ring.cores do
		b.Enabled = on
		if on then
			b.Transparency = NumberSequence.new(1 - alpha * (1 - Style.CORE_BODY))
		end
	end
end

local function smooth(a: number, b: number, x: number): number
	local t = math.clamp((x - a) / (b - a), 0, 1)
	return t * t * (3 - 2 * t)
end

-- easeOutBack: passes 1 by ~10 % and settles (draw snap with a little overshoot)
local function outBack(t: number): number
	local c = 1.70158
	local u = t - 1
	return 1 + (c + 1) * u * u * u + c * u * u
end

local function droplets(parent: Attachment, scale: number): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = "TempestBurst"
	e.Texture = VFX.TEMPEST_DROPLETS_2x2
	e.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
	e.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	e.Color = ColorSequence.new(Style.WATER_EDGE, Style.WATER)
	e.LightEmission = 0.8
	e.LightInfluence = 0
	e.Brightness = 1.7
	e.Rate = 0
	e.Lifetime = NumberRange.new(0.26, 0.42)
	e.Speed = NumberRange.new(0.6 * scale, 1.4 * scale)
	e.Drag = 5
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.16 * scale),
		NumberSequenceKeypoint.new(1, 0.30 * scale),
	})
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(0.6, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Acceleration = Vector3.new(0, -5 * scale, 0)
	e.LockedToPart = true
	e.Enabled = false
	e.Parent = parent
	return e
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
	local state: State = {
		frame = frame,
		toBody = body.CFrame:ToObjectSpace(handle.CFrame),
		ring = { points = {}, beams = {}, cores = {} },
		burst = nil :: any,
		well = nil :: any,
		reloadPrev = -1,
		timing = nil,
		shotAge = math.huge,
		shotSign = 1,
		popAge = math.huge,
		boost = 0,
		drain = 0,
		pose = CFrame.identity,
		wellRest = Vector3.zero,
		drawPrev = nil,
		glows = {},
		ribbons = {},
		sparks = {},
		light = nil,
		clock = 0,
		weight = 0,
	}
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
	state.ring = makeRing(state, Style.RING_POINTS, w * 0.9)
	state.well = anchor(frame, "TempestWell", Style.WELL)
	state.wellRest = state.well.Position
	state.burst = droplets(state.well, scale)
	return state
end

-- One shot (first person): a small skin kick on top of the stock recoil and a conduit flare.
function TempestIdle.fire(state: State)
	state.shotAge = 0
	state.shotSign = -state.shotSign
	state.boost = math.max(state.boost, Style.BOOST_SHOT)
end

local function centre(parts: { BasePart }): Vector3?
	local sum, n = Vector3.zero, 0
	for _, p in parts do
		sum += p.Position
		n += 1
	end
	return if n > 0 then sum / n else nil
end

-- Called every frame of a reload clip with its progress t (0..1). `parts` are the mag's
-- parts; outAt / inAt the stock hide and show points, seat where the mag stops moving.
-- Returns true on the frame the old mag dissolves (the caller hides it, no drop copy).
function TempestIdle.reload(
	state: State,
	parts: { BasePart },
	t: number,
	outAt: number,
	inAt: number,
	seat: number
): boolean
	local prev = state.reloadPrev
	state.reloadPrev = t
	state.timing = { outAt = outAt, inAt = inAt, seat = seat }
	local dissolved = false
	if prev < outAt and t >= outAt then
		-- the old magazine bursts into water where it is
		local at = centre(parts)
		if at then
			state.well.WorldPosition = at
		end
		state.burst:Emit(if UiMotion.reduced() then 6 else 14)
		dissolved = true
	end
	if prev < inAt and t >= inAt then
		-- water forms the new magazine in the hand
		local at = centre(parts)
		if at then
			state.well.WorldPosition = at
		end
		state.burst:Emit(if UiMotion.reduced() then 4 else 9)
	end
	if prev < seat and t >= seat then
		state.well.Position = state.wellRest
		state.burst:Emit(8)
		state.popAge = 0
		state.boost = math.max(state.boost, Style.BOOST_SEAT)
	end
	return dissolved
end

function TempestIdle.endReload(state: State)
	state.reloadPrev = -1
	state.timing = nil
	state.well.Position = state.wellRest
end

-- The skin's motion layer in Handle space (multiply onto the gun's handle CFrame).
function TempestIdle.pose(state: State): CFrame
	return state.pose
end

-- Every frame. drawP / inspectP: progress 0..1 of the draw and inspect clips, or nil.
function TempestIdle.step(
	state: State,
	dt: number,
	visible: boolean,
	idle: boolean,
	ads: number,
	drawP: number?,
	inspectP: number?
)
	local reduced = UiMotion.reduced()
	local aim = math.clamp(ads, 0, 1)
	local target = if visible then (if idle then 1 else 0.6) else 0
	local s = math.min(dt, 0.1)
	state.weight = math.clamp(target, state.weight - s * 6, state.weight + s * 3)
	state.clock += s
	state.shotAge += s
	state.popAge += s
	state.boost = math.max(0, state.boost - s * Style.BOOST_DECAY)
	local on = visible and state.weight > 0.01
	-- reload: conduits drain while the magazine is gone, refill as the new one forms
	local timing = state.timing
	local drainGoal = 0
	if timing and state.reloadPrev >= 0 then
		local t = state.reloadPrev
		drainGoal = smooth(timing.outAt - 0.04, timing.outAt + 0.04, t)
			* (1 - smooth(timing.inAt - 0.10, timing.seat, t))
	end
	state.drain += (drainGoal - state.drain) * (1 - math.exp(-14 * s))
	local life = 1 - Style.RELOAD_DRAIN * state.drain
	-- ribbons: visible fade-in, thinned while aiming; reduced motion stops the scroll
	local opacity = state.weight * (1 - (1 - Style.ADS_RIBBON) * aim) * life
	for _, r in state.ribbons do
		r.beam.Enabled = on
		if on then
			r.beam.Brightness = (if r.body then 1.3 else Style.RIBBON_BRIGHTNESS)
					* (opacity + 0.35 * state.boost)
				+ 0.15 * math.sin(state.clock * 2.1)
			r.beam.TextureSpeed = if reduced then 0 else r.speed * (1 + 1.5 * state.boost)
		end
	end
	local inspecting = inspectP ~= nil
	local sparksOn = on and not reduced and aim < Style.ADS_SPARK_CUTOFF and state.drain < 0.5
	local rate = Style.SPARK_RATE * (if inspecting then Style.INSPECT_SPARKS else 1)
	for _, e in state.sparks do
		e.Rate = rate
		if e.Enabled ~= sparksOn then
			e.Enabled = sparksOn
			if not sparksOn then
				e:Clear()
			end
		end
	end
	-- the cyan conduits breathe; flare on shots and the seat; steady while aiming
	local breath = if reduced then 0.5 else 0.5 + 0.5 * math.sin(state.clock * Style.GLOW_RATE)
	local flare = math.clamp(breath * Style.GLOW_MIX * (1 - 0.6 * aim) + state.boost, 0, 1)
	for _, g in state.glows do
		local c = g.color:Lerp(Style.GLOW_PEAK, flare)
		g.part.Color = c:Lerp(Style.DRAINED, state.drain)
	end
	local light = state.light
	if light then
		light.Enabled = on
		if on then
			light.Brightness = Style.LIGHT_BRIGHTNESS
				* (opacity + 0.6 * state.boost)
				* (0.88 + 0.12 * math.sin(state.clock * 3.3))
		end
	end
	-- the water ring: runs down the barrel on draw, circles the fore-end on inspect,
	-- gathers at the magwell before the new magazine seats
	local ringAlpha, spin = 0, state.clock * Style.RING_SPIN
	if timing and state.reloadPrev >= 0 then
		local t = state.reloadPrev
		local k = smooth(timing.inAt - 0.16, timing.seat, t)
		ringAlpha = smooth(timing.inAt - 0.16, timing.inAt - 0.10, t)
			* (1 - smooth(timing.seat - 0.03, timing.seat, t))
		if ringAlpha > 0.02 then
			placeRing(
				state,
				Style.WELL,
				bl(1, 0, 0),
				bl(0, 1, 0),
				0.24 + (0.07 - 0.24) * k,
				spin * 1.6,
				ringAlpha
			)
		end
	elseif inspectP then
		-- the ring sweeps from the muzzle back over the receiver and returns
		ringAlpha = smooth(0.08, 0.18, inspectP) * (1 - smooth(0.82, 0.94, inspectP))
		if ringAlpha > 0.02 then
			local sweep = 0.5 - 0.5 * math.cos(smooth(0.08, 0.94, inspectP) * 2 * math.pi)
			local x = 2.35 + (0.45 - 2.35) * sweep
			local r = 0.15 + 0.11 * smooth(1.15, 0.85, x)
			placeRing(state, bl(x, 0, 0.30), bl(0, 1, 0), bl(0, 0, 1.1), r, spin, ringAlpha)
		end
	elseif drawP then
		local k = smooth(0, Style.DRAW_RING, drawP)
		ringAlpha = smooth(0, 0.08, drawP)
			* (1 - smooth(Style.DRAW_RING - 0.12, Style.DRAW_RING, drawP))
		if ringAlpha > 0.02 then
			local x = 2.55 + (1.0 - 2.55) * k
			local r = 0.10 + (0.17 - 0.10) * k
			placeRing(state, bl(x, 0, 0.30), bl(0, 1, 0), bl(0, 0, 1.15), r, spin, ringAlpha)
		end
		if (state.drawPrev or 0) < Style.DRAW_RING and drawP >= Style.DRAW_RING then
			state.boost = math.max(state.boost, Style.BOOST_SEAT) -- plates lock
		end
	end
	state.drawPrev = drawP
	if ringAlpha <= 0.02 or not on then
		for _, b in state.ring.beams do
			b.Enabled = false
		end
		for _, b in state.ring.cores do
			b.Enabled = false
		end
	end
	-- motion layer (animation oomph: snap in ~40 ms, overshoot, settle); none while hidden
	local k = state.frame.scale
	local pose = CFrame.identity
	if visible then
		-- shot: snap up and back, a quick roll that alternates per shot
		local a = state.shotAge
		if a < 1 then
			local env = if a < 0.04
				then a / 0.04
				else math.exp(-(a - 0.04) / Style.KICK_TIME * 4) * math.cos((a - 0.04) * 22)
			local damp = 1 - 0.65 * aim
			pose *= CFrame.new(0, 0, Style.KICK_BACK * k * env * damp) * CFrame.Angles(
				Style.KICK_PITCH * env * damp,
				0,
				Style.KICK_ROLL * env * state.shotSign * damp
			)
		end
		-- seat: the gun bumps up as the water magazine locks
		local p = state.popAge
		if p < 0.5 then
			local e = math.exp(-p * 9) * math.sin(p * 30)
			pose *= CFrame.new(0, Style.SEAT_POP * k * e, 0) * CFrame.Angles(-0.02 * e, 0, 0)
		end
		-- draw: rolls in from the side and snaps level with a little overshoot
		if drawP then
			local d = outBack(math.clamp(drawP / Style.DRAW_SNAP, 0, 1))
			pose *= CFrame.Angles(0, 0, Style.DRAW_ROLL * (1 - d))
		end
		-- inspect: the gun floats up and turns on the water
		if inspectP then
			local w = smooth(0.08, 0.25, inspectP) * (1 - smooth(0.80, 0.95, inspectP))
			pose *= CFrame.new(0, Style.INSPECT_LIFT * k * w, 0) * CFrame.Angles(
				0,
				0,
				Style.INSPECT_ROLL * w * math.sin(inspectP * math.pi * 3)
			)
		end
		-- idle: a faint hover
		if not reduced and idle then
			pose *= CFrame.new(0, Style.HOVER * k * math.sin(state.clock * 1.7) * (1 - aim), 0)
		end
	end
	state.pose = pose
end

return TempestIdle
