--!strict
-- Tracers, split out of Controllers/EffectsController (which forwards
-- EffectsController.tracer here and calls step() every frame). Owns the tracer
-- pool: a thin hot streak of two Beams (glow and core) between two world
-- attachments that travels from the muzzle to the hit.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local VFX = require(ReplicatedStorage.Shared.Config.VfxTextures)

local Kit = require(script.Parent.ShotFxKit)

type WeaponConfig = Types.WeaponConfig

local TracerFx = {}

local WHITE = Kit.WHITE
local FIRE = Kit.FIRE

local TRACER_POOL = 40
local TRACER_SPEED = 1400 -- studs/s
local TRACER_MIN_TIME = 0.04 -- close shots still show for a few frames
local TRACER_MAX_TIME = 0.14
local TRACER_LENGTH = 9

type Tracer = {
	a0: Attachment,
	a1: Attachment,
	glow: Beam,
	core: Beam,
	color: Color3,
	from: Vector3,
	dir: Vector3,
	dist: number,
	speed: number,
	travelled: number,
	length: number,
	active: boolean,
}

local tracers: { Tracer } = {}
local nextTracer = 1
local activeTracers = 0

local function tracerBeam(a0: Attachment, a1: Attachment, width: number, color: Color3): Beam
	local b = Instance.new("Beam")
	b.Attachment0 = a0
	b.Attachment1 = a1
	b.Texture = VFX.TRACER
	b.TextureMode = Enum.TextureMode.Stretch
	b.TextureLength = 1
	b.Color = ColorSequence.new(color)
	b.LightEmission = 1
	b.LightInfluence = 0
	b.FaceCamera = true
	b.Segments = 1
	b.Width0 = width * 0.25
	b.Width1 = width
	b.Enabled = false
	b.Parent = a0
	return b
end

local function newTracer(): Tracer
	local a0 = Kit.worldAttachment("TracerTail")
	local a1 = Kit.worldAttachment("TracerHead")
	local glow = tracerBeam(a0, a1, 0.14, FIRE)
	glow.Transparency = NumberSequence.new(0.55)
	return {
		a0 = a0,
		a1 = a1,
		glow = glow,
		core = tracerBeam(a0, a1, 0.045, WHITE),
		color = FIRE,
		from = Vector3.zero,
		dir = Vector3.zAxis,
		dist = 0,
		speed = TRACER_SPEED,
		travelled = 0,
		length = TRACER_LENGTH,
		active = false,
	}
end

-- `own`: our own shot (a little fainter: it runs straight away from the eye;
-- fainter still from a suppressed gun, which shows enemies no tracer at all).
function TracerFx.tracer(from: Vector3, to: Vector3, config: WeaponConfig, own: boolean?)
	local offset = to - from
	local dist = offset.Magnitude
	if dist < 4 then
		return
	end
	if #tracers < TRACER_POOL then
		table.insert(tracers, newTracer())
	end
	local t = tracers[nextTracer] or tracers[1]
	nextTracer = nextTracer % TRACER_POOL + 1
	if not t.active then
		activeTracers += 1
	end
	local color = config.tracerColor
	if t.color ~= color then
		t.color = color
		t.glow.Color = ColorSequence.new(color)
	end
	local faint = own and config.suppressed == true
	t.core.Transparency = NumberSequence.new(if faint then 0.7 elseif own then 0.35 else 0)
	t.glow.Transparency = NumberSequence.new(if faint then 0.85 else 0.55)
	t.from = from
	t.dir = offset / dist
	t.dist = dist
	t.length = math.min(TRACER_LENGTH, dist * 0.5)
	-- The whole streak, tail included, has to leave within the time range.
	local time = math.clamp(dist / TRACER_SPEED, TRACER_MIN_TIME, TRACER_MAX_TIME)
	t.speed = (dist + t.length) / time
	t.travelled = 0
	t.active = true
	t.a0.WorldPosition = from
	t.a1.WorldPosition = from + t.dir * 0.1
	t.glow.Enabled = true
	t.core.Enabled = true
end

-- Every frame, with `dt` already scaled by the effects time scale.
function TracerFx.step(dt: number)
	if activeTracers == 0 then
		return
	end
	for _, t in tracers do
		if not t.active then
			continue
		end
		t.travelled += t.speed * dt
		local head = math.min(t.travelled, t.dist)
		local tail = math.max(0, t.travelled - t.length)
		if tail >= t.dist then
			t.active = false
			activeTracers -= 1
			t.glow.Enabled = false
			t.core.Enabled = false
			continue
		end
		t.a0.WorldPosition = t.from + t.dir * tail
		t.a1.WorldPosition = t.from + t.dir * math.max(head, tail + 0.1)
	end
end

return TracerFx
