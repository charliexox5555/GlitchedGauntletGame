--!strict
-- Tempest-Strike idle (first-person camera gun only): two laminar water ribbons
-- wrap the fore-end into the fluted sleeve, and sparse white-cyan arcs flick out of the handguard
-- vents. Everything eases down while aiming so the crescent stays clear.
-- Anchors are given in Blender coordinates (Roblox X, Y, Z = -Blender Y, Blender Z,
-- -Blender X) in the Handle's rest frame, scaled with the viewmodel, and parented to
-- the part the rig's Root motor drives: recoil, reload and inspect move that part,
-- not the Handle, so effects on the Handle were left behind (owner 2026-11-21).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local StateValues = require(Shared.StateValues)
local Style = require(Shared.Config.SkinPreview).TEMPEST
local VFX = require(Shared.Config.VfxTextures)
local UiMotion = require(Shared.UiMotion)
local TempestAudio = require(Shared.Config.TempestAudio)
local AudioController = require(script.Parent.Parent.Controllers.AudioController)

type Ribbon = { beam: Beam, speed: number, body: boolean }
type Glow = { part: BasePart, color: Color3 }
type Ring = { points: { Attachment }, beams: { Beam }, cores: { Beam } }
export type State = {
	frame: Frame,
	toBody: CFrame,
	ring: Ring,
	bursts: { [string]: ParticleEmitter }, -- droplet bursts, one attachment each (mag, well, centre)
	reloadPrev: number, -- reload progress last frame (-1 = not reloading)
	timing: { outAt: number, inAt: number, seat: number }?,
	shotAge: number,
	shotSign: number,
	popAge: number, -- seconds since the new magazine seated
	boost: number, -- conduit flare (shots, seat), decays
	drain: number, -- conduits dimmed while the magazine is out
	pose: CFrame,
	drawPrev: number?,
	inspectPrev: number?,
	cues: { [string]: () -> () },
	still: number, -- seconds standing idle (no aim, move, shot or action)
	nextFlourish: number,
	flourishAge: number,
	flourish: number, -- which idle flourish (1 wrist turn, 2 sight check)
	aimed: boolean,
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

-- A droplet burst at a Handle-space point (`at`, model studs) or a world point.
-- Each name keeps its own attachment, so a later burst never drags an earlier
-- one's live droplets (they are locked to their attachment).
local function burst(state: State, name: string, count: number, at: Vector3?, world: Vector3?)
	local e = state.bursts[name]
	if not e then
		local a = Instance.new("Attachment")
		a.Name = "TempestBurst" .. name
		a.Parent = state.frame.body
		e = droplets(a, state.frame.scale)
		state.bursts[name] = e
	end
	local a = e.Parent :: Attachment
	if world then
		a.WorldPosition = world
	elseif at then
		a.Position = state.toBody:PointToWorldSpace(at * state.frame.scale)
	end
	e:Emit(if UiMotion.reduced() then math.ceil(count * 0.4) else count)
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
		bursts = {},
		reloadPrev = -1,
		timing = nil,
		shotAge = math.huge,
		shotSign = 1,
		popAge = math.huge,
		boost = 0,
		drain = 0,
		pose = CFrame.identity,
		drawPrev = nil,
		inspectPrev = nil,
		cues = {},
		still = 0,
		nextFlourish = 0,
		flourishAge = math.huge,
		flourish = 1,
		aimed = false,
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
	return state
end

-- An action beat: its foley (Config/TempestAudio, over the stock handling sounds)
-- and any hook the caller set (state.cues[name] = fn).
function TempestIdle.cue(state: State, name: string)
	AudioController.playSound(TempestAudio.cues[name], "Foley")
	local f = state.cues[name]
	if f then
		f()
	end
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
		burst(state, "Out", 14, nil, centre(parts))
		dissolved = true
		TempestIdle.cue(state, "magOut")
	end
	if prev < inAt and t >= inAt then
		-- water forms the new magazine in the hand
		burst(state, "Form", 9, nil, centre(parts))
		TempestIdle.cue(state, "magForm")
	end
	if prev < seat and t >= seat then
		burst(state, "Well", 8, Style.WELL)
		state.popAge = 0
		state.boost = math.max(state.boost, Style.BOOST_SEAT)
		TempestIdle.cue(state, "magSeat")
	end
	return dissolved
end

function TempestIdle.endReload(state: State)
	state.reloadPrev = -1
	state.timing = nil
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
	-- idle flourishes: after standing still a while the gun turns in the hand
	-- (a wrist turn or a look down the sight) while the water surges
	state.flourishAge += s
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local moving = humanoid ~= nil and humanoid.MoveDirection.Magnitude > 0.1
	local calm = visible
		and idle
		and not reduced
		and aim < 0.05
		and not moving
		and drawP == nil
		and inspectP == nil
		and state.timing == nil
		and state.shotAge > 1.5
	if calm then
		state.still += s
		if state.nextFlourish <= 0 then
			state.nextFlourish = Style.FLOURISH_AFTER[1]
				+ math.random() * (Style.FLOURISH_AFTER[2] - Style.FLOURISH_AFTER[1])
		end
		if state.still >= state.nextFlourish and state.flourishAge > Style.FLOURISH_TIME then
			state.flourishAge = 0
			state.flourish = state.flourish % 2 + 1
			state.still = 0
			state.nextFlourish = 0
			TempestIdle.cue(state, "idleSurge")
		end
	else
		state.still = 0
		if state.flourishAge < Style.FLOURISH_TIME then
			-- cut short: let it ease out from where it is over the next 0.25 s
			state.flourishAge = math.max(state.flourishAge, Style.FLOURISH_TIME - 0.25)
		end
	end
	local fa = state.flourishAge
	local surge = if fa < Style.FLOURISH_TIME
		then smooth(0, 0.3, fa) * (1 - smooth(Style.FLOURISH_TIME - 0.5, Style.FLOURISH_TIME, fa))
		else 0
	state.boost = math.max(state.boost, 0.45 * surge)
	local on = visible and state.weight > 0.01
	-- into the sights: a faint water shimmer
	local aimed = if state.aimed then aim > 0.35 else aim > 0.6
	if aimed and not state.aimed and visible then
		TempestIdle.cue(state, "aimIn")
	end
	state.aimed = aimed
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
	local rate = Style.SPARK_RATE
		* (if inspecting then Style.INSPECT_SPARKS else 1)
		* (1 + 2 * surge)
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
		-- InspectTempest: the ring runs muzzle to receiver while the right side
		-- shows, then opens wide round the middle of the gun for the barrel roll
		-- (Config/Viewmodel toss 0.465-0.64) and spins against it; a splash on the catch
		local roll = smooth(Style.INSPECT_ROLL_IN - 0.04, Style.INSPECT_ROLL_IN, inspectP)
		ringAlpha = smooth(0.07, 0.15, inspectP) * (1 - smooth(0.70, 0.80, inspectP))
		if ringAlpha > 0.02 then
			local run = smooth(0.08, 0.40, inspectP)
			local x = 2.35 + (1.05 - 2.35) * run
			x += (Style.INSPECT_RING_X - x) * roll
			local r = 0.15 + 0.06 * run
			r += (Style.INSPECT_RING_R - r) * roll * (1 - 0.35 * smooth(0.64, 0.78, inspectP))
			local whirl = spin * (1 + 2.2 * roll)
			placeRing(state, bl(x, 0, 0.30), bl(0, 1, 0), bl(0, 0, 1.1), r, -whirl, ringAlpha)
		end
		local prev = state.inspectPrev or 0
		if inspectP < prev then
			prev = 0 -- pressed again: a fresh inspect from the top
		end
		if prev < Style.INSPECT_ROLL_IN and inspectP >= Style.INSPECT_ROLL_IN then
			state.boost = math.max(state.boost, Style.BOOST_SHOT)
			TempestIdle.cue(state, "inspectRoll")
		end
		if prev < Style.INSPECT_CATCH and inspectP >= Style.INSPECT_CATCH then
			burst(state, "Centre", 12, bl(Style.INSPECT_RING_X, 0, 0.30))
			state.boost = math.max(state.boost, Style.BOOST_SEAT)
			TempestIdle.cue(state, "inspectCatch")
		end
		if prev < 0.02 and inspectP >= 0.02 then
			TempestIdle.cue(state, "inspect")
		end
	elseif drawP then
		if state.drawPrev == nil then
			TempestIdle.cue(state, "draw")
		end
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
			burst(state, "Centre", 10, bl(1.2, 0, 0.32))
			TempestIdle.cue(state, "drawLock")
		end
	end
	state.drawPrev = drawP
	state.inspectPrev = inspectP
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
		-- idle: a faint hover
		if not reduced and idle then
			pose *= CFrame.new(0, Style.HOVER * k * math.sin(state.clock * 1.7) * (1 - aim), 0)
		end
		-- idle flourish: coil the other way, turn past the pose, settle back
		if surge > 0 then
			local coil = smooth(0, 0.12, fa) * (1 - smooth(0.12, 0.3, fa))
			local w = surge - 0.25 * coil
			if state.flourish == 1 then
				-- wrist turn: roll the plates toward the eye, muzzle a touch left
				pose *= CFrame.new(0, 0.012 * k * w, 0) * CFrame.Angles(
					math.rad(3) * w,
					math.rad(-5) * w,
					math.rad(14) * w
				)
			else
				-- sight check: lift the muzzle and tip it in to look along the top
				pose *= CFrame.new(0, 0.018 * k * w, 0) * CFrame.Angles(
					math.rad(8) * w,
					math.rad(4) * w,
					math.rad(-6) * w
				)
			end
		end
	end
	state.pose = pose
end

return TempestIdle
