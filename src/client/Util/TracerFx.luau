--!strict
-- Tracers, split out of Controllers/EffectsController (which forwards
-- EffectsController.tracer here and calls step() every frame). Owns the tracer
-- pool. One tracer is three Beams between world attachments:
--   core   a white-hot streak with a bright head (the round itself),
--   glow   a wider, softer streak in the gun's tracer colour around it,
--   trail  (other players' shots) the line the round drew from the muzzle to
--          wherever its head has got to. It hangs for a moment after the
--          round arrives, then dissolves from the gun end outward and spreads
--          (a spray draws its pattern in the air; a sniper round leaves a
--          vapour trail).
-- Two looks (Config/Juice TRACER has the why and the measurements):
--   your own shot   a DART: its head is on the hit point from the first
--                   frame (at most T.dart.reach ahead), its tail starts at the
--                   muzzle and runs into the hit at a steady speed (RIVALS,
--                   2026-11-16), and it is drawn a fixed width on screen
--                   whatever the range.
--   everyone else's a streak that flies from their muzzle, with the trail.
-- Each gun class has its own round (`style`, `class`, `gun`).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Juice = require(ReplicatedStorage.Shared.Config.Juice)
local Types = require(ReplicatedStorage.Shared.Types)
local VFX = require(ReplicatedStorage.Shared.Config.VfxTextures)

local Kit = require(script.Parent.ShotFxKit)

type WeaponConfig = Types.WeaponConfig

local TracerFx = {}

local T = Juice.TRACER
local WHITE = Kit.WHITE
local FIRE = Kit.FIRE

type Style = {
	dartWidth: number,
	dartTaper: number,
	dartStart: number,
	dartTime: number,
	speed: number,
	length: number,
	core: number,
	glow: number,
	glowFade: number,
	trailWidth: number,
	trail: number,
	trailFade: number,
	trailGrow: number,
}

-- A gun's round: the base style, its class's changes, then the gun's own.
local styles: { [string]: Style } = {}
local SPECTRAL: Style = {
	dartWidth = 0,
	dartTaper = 0,
	dartStart = 0,
	dartTime = 0,
	speed = 1080,
	length = 5.4,
	core = 0.095,
	glow = 0.20,
	glowFade = 0.57,
	trailWidth = 0.23,
	trail = 0.56,
	trailFade = 0.31,
	trailGrow = 0.95,
}

local function styleOf(config: WeaponConfig): Style
	local style = styles[config.id]
	if not style then
		local merged: { [string]: number } = table.clone(T.style :: any)
		for key, value in T.class[config.class] or {} do
			merged[key] = value
		end
		for key, value in T.gun[config.id] or {} do
			merged[key] = value
		end
		style = merged :: any
		styles[config.id] = style :: Style
	end
	return style :: Style
end

type Tracer = {
	a0: Attachment, -- streak tail
	a1: Attachment, -- streak head
	w0: Attachment, -- trail start (the muzzle)
	glow: Beam,
	core: Beam,
	trail: Beam,
	color: Color3,
	style: Style,
	from: Vector3,
	dir: Vector3,
	dist: number,
	speed: number,
	travelled: number,
	length: number,
	trailBase: number, -- the trail's transparency while the round flies (1 = none)
	trailAge: number, -- seconds since the round arrived
	dart: boolean, -- your own shot: the head is on the hit, the tail runs into it
	tail: number, -- dart: studs from `from` to its tail
	fresh: boolean, -- dart: not drawn yet (its first frame shows it from the muzzle)
	flying: boolean,
	active: boolean,
}

local tracers: { Tracer } = {}
local nextTracer = 1
local activeTracers = 0

local function beam(a0: Attachment, a1: Attachment, texture: string, color: Color3): Beam
	local b = Instance.new("Beam")
	b.Attachment0 = a0
	b.Attachment1 = a1
	b.Texture = texture
	b.TextureMode = Enum.TextureMode.Stretch
	b.TextureLength = 1
	b.Color = ColorSequence.new(color)
	b.LightEmission = 1
	b.LightInfluence = 0
	b.FaceCamera = true
	b.Segments = 1
	b.Enabled = false
	b.Parent = a0
	return b
end

local function newTracer(): Tracer
	local a0 = Kit.worldAttachment("TracerTail")
	local a1 = Kit.worldAttachment("TracerHead")
	local w0 = Kit.worldAttachment("TracerWake")
	local glow = beam(a0, a1, VFX.TRACER, FIRE)
	local core = beam(a0, a1, VFX.TRACER, WHITE)
	core.Brightness = T.coreBrightness
	local trail = beam(w0, a1, VFX.TRACER_WAKE, FIRE:Lerp(WHITE, T.wakeWhiten))
	trail.LightEmission = 0.6
	return {
		a0 = a0,
		a1 = a1,
		w0 = w0,
		glow = glow,
		core = core,
		trail = trail,
		color = FIRE,
		style = T.style :: any,
		from = Vector3.zero,
		dir = Vector3.zAxis,
		dist = 0,
		speed = T.style.speed,
		travelled = 0,
		length = T.style.length,
		trailBase = 1,
		trailAge = 0,
		dart = false,
		fresh = false,
		tail = 0,
		flying = false,
		active = false,
	}
end

-- The trail `k` (0..1) of the way through dissolving: gone at the gun end
-- first (u = 0), the far end last, the whole line thinning out as it goes.
local DISSOLVE_BAND = 0.35 -- the share of the line that is part-faded at once
local function dissolve(base: number, k: number): NumberSequence
	local front = k * (1 + DISSOLVE_BAND)
	local overall = k * k
	local keys = table.create(5)
	for i = 0, 4 do
		local u = i / 4
		local gone = math.clamp((front - u) / DISSOLVE_BAND, 0, 1)
		local shown = (1 - base) * (1 - gone) * (1 - overall)
		keys[i + 1] = NumberSequenceKeypoint.new(u, 1 - shown)
	end
	return NumberSequence.new(keys)
end

-- A dart's widths this frame: `px` wide on screen (at 1080p) at each end,
-- however far away that end is.
local function dartWidths(t: Tracer, cam: Camera)
	local style = t.style
	-- Studs per px, per stud of depth.
	local perPixel = math.tan(math.rad(cam.FieldOfView) / 2) / 540
	local eye = cam.CFrame
	local tailDepth = math.max(-eye:PointToObjectSpace(t.a0.WorldPosition).Z, 0.5)
	local headDepth = math.max(-eye:PointToObjectSpace(t.a1.WorldPosition).Z, 0.5)
	local head = style.dartWidth * perPixel * headDepth
	local tail = style.dartWidth * style.dartTaper * perPixel * tailDepth
	t.core.Width0 = tail
	t.core.Width1 = head
	t.glow.Width0 = tail * T.dartGlow
	t.glow.Width1 = head * T.dartGlow
end

-- The dart's head, studs from `from`: on the hit, or (RIVALS) at most
-- T.dart.reach ahead of the tail.
local function dartHead(t: Tracer): number
	if T.dart.speed > 0 then
		return math.min(t.dist, t.tail + T.dart.reach)
	end
	return t.dist
end

-- `own`: our own shot, drawn as the dart (see the top of the file). A
-- suppressed gun's is fainter, and enemies see no tracer from it at all.
function TracerFx.tracer(
	from: Vector3,
	to: Vector3,
	config: WeaponConfig,
	own: boolean?,
	colorOverride: Color3?
)
	local offset = to - from
	local dist = offset.Magnitude
	if dist < T.minDistance then
		return
	end
	local dir = offset / dist
	if #tracers < T.pool then
		table.insert(tracers, newTracer())
	end
	local t = tracers[nextTracer] or tracers[1]
	nextTracer = nextTracer % T.pool + 1
	if not t.active then
		activeTracers += 1
	end
	-- A tint is supplied only for the owner of the equipped skin. The
	-- suppressed model gets its own round without revealing the shot to others.
	local spectral = own == true and colorOverride ~= nil
	local style = if spectral then SPECTRAL else styleOf(config)
	t.style = style
	-- A gun that flashes has its class's colour (T.color); a suppressed one
	-- keeps the pale round.
	local suppressed = config.suppressed == true
	local tint = if spectral
		then colorOverride
		elseif suppressed then nil
		else T.color.gun[config.id] or T.color.class[config.class]
	local color = tint or config.tracerColor
	if t.color ~= color or spectral then
		t.color = color
		t.glow.Color = ColorSequence.new(color)
		t.core.Color = ColorSequence.new(if tint then WHITE:Lerp(color, T.color.core) else WHITE)
		t.trail.Color = if spectral
			then ColorSequence.new(Color3.fromRGB(43, 104, 96), color:Lerp(WHITE, 0.12))
			else ColorSequence.new(
				color:Lerp(WHITE, if tint then T.color.trail else T.wakeWhiten)
			)
	end
	t.from = from
	t.dir = dir
	t.dist = dist
	t.travelled = 0
	t.trailAge = 0
	t.active = true
	t.flying = true
	t.dart = own == true and not spectral
	t.fresh = t.dart
	t.glow.Enabled = true
	t.core.Enabled = true
	if t.dart then
		-- The dart: tail from the muzzle (RIVALS, T.dart) or a little ahead of
		-- it (the eased dart), head on the hit or at most T.dart.reach ahead.
		t.tail = math.min(if T.dart.speed > 0 then T.dart.start else style.dartStart, dist * 0.5)
		t.trailBase = 1
		t.trail.Enabled = false
		local fade = if suppressed then T.suppressedFade else 0
		t.core.Transparency = NumberSequence.new(fade)
		t.core.Brightness = T.dartBrightness
		t.glow.Transparency = NumberSequence.new(1 - (1 - T.dartGlowFade) * (1 - fade))
		t.a0.WorldPosition = from + dir * t.tail
		t.a1.WorldPosition = from + dir * dartHead(t)
		local cam = Workspace.CurrentCamera
		if cam then
			dartWidths(t, cam)
		end
		return
	end
	local taper = if spectral then 0.18 else T.tailTaper
	t.core.Width0 = style.core * taper
	t.core.Width1 = style.core
	t.glow.Width0 = style.glow * taper
	t.glow.Width1 = style.glow
	t.core.Transparency = NumberSequence.new(0)
	t.core.Brightness = T.coreBrightness
	t.glow.Transparency = NumberSequence.new(style.glowFade)
	-- Suppressed rounds leave no trail.
	t.trailBase = if suppressed then 1 else style.trail
	t.trail.Texture = if spectral then VFX.FROST_VAPOR else VFX.TRACER_WAKE
	t.trail.TextureSpeed = if spectral then 0.8 else 0
	t.trail.Width0 = style.trailWidth * 0.5
	t.trail.Width1 = style.trailWidth
	t.length = math.min(style.length, dist * 0.6)
	-- The whole streak, tail included, has to leave within the time range.
	local time = math.clamp(dist / style.speed, T.minTime, T.maxTime)
	t.speed = (dist + t.length) / time
	t.a0.WorldPosition = from
	t.a1.WorldPosition = from + t.dir * 0.1
	t.w0.WorldPosition = from
	t.trail.Enabled = t.trailBase < 1
	if t.trailBase < 1 then
		t.trail.Transparency = NumberSequence.new(t.trailBase)
	end
	if spectral then
		if suppressed then
			t.core.Width0 *= 0.56
			t.core.Width1 *= 0.56
			t.glow.Width0 *= 0.66
			t.glow.Width1 *= 0.66
		end
	end
end

-- Every frame, with `dt` already scaled by the effects time scale.
function TracerFx.step(dt: number)
	if activeTracers == 0 then
		return
	end
	local cam = Workspace.CurrentCamera
	for _, t in tracers do
		if not t.active then
			continue
		end
		if t.dart then
			-- The tail runs into the hit: at a steady speed (RIVALS), or
			-- faster the further out it gets (the eased dart: on screen it
			-- shrinks at an even pace); then the dart is gone.
			if t.fresh then
				-- Its first frame shows it whole, from the muzzle (at 15 fps a
				-- round covers 50 studs a frame and was never seen there).
				t.fresh = false
			elseif T.dart.speed > 0 then
				t.tail += T.dart.speed * dt
			else
				t.tail *= math.exp(dt / t.style.dartTime)
			end
			if t.tail >= t.dist - 0.2 or not cam then
				t.active = false
				t.flying = false
				activeTracers -= 1
				t.glow.Enabled = false
				t.core.Enabled = false
			else
				t.a0.WorldPosition = t.from + t.dir * t.tail
				t.a1.WorldPosition = t.from + t.dir * dartHead(t)
				dartWidths(t, cam)
			end
			continue
		end
		if t.flying then
			t.travelled += t.speed * dt
			local head = math.min(t.travelled, t.dist)
			local tail = math.max(0, t.travelled - t.length)
			if tail >= t.dist then
				-- Arrived: the streak goes, the trail hangs and dissolves.
				t.flying = false
				t.glow.Enabled = false
				t.core.Enabled = false
				t.a1.WorldPosition = t.from + t.dir * t.dist
			else
				t.a0.WorldPosition = t.from + t.dir * tail
				t.a1.WorldPosition = t.from + t.dir * math.max(head, tail + 0.1)
			end
		else
			t.trailAge += dt
		end
		if not t.flying then
			local style = t.style
			local k = if t.trailBase < 1 then t.trailAge / style.trailFade else 1
			if k >= 1 then
				t.active = false
				activeTracers -= 1
				t.trail.Enabled = false
			else
				t.trail.Transparency = dissolve(t.trailBase, k)
				local width = style.trailWidth * (1 + style.trailGrow * k)
				t.trail.Width0 = width * 0.5
				t.trail.Width1 = width
			end
		end
	end
end

return TracerFx
