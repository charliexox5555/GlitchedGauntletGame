--!strict
-- The knife's first-person swipe streak, split out of
-- Controllers/EffectsController (which forwards EffectsController.knifeSwipe
-- here). Owns the live swipes and their own RenderStepped connection, which
-- runs only while a swipe is showing.
--
-- 2026-11-05, lane F; LihFolk Slash VFX Recipes and VFX Timing with
-- Animation: the head sweeps in over the strike, the tail chases it, then it
-- erodes; white core + a dark steel body; no streak on the stab. `arc`: three
-- points in camera space (start, bend, end) of a quadratic curve, `delay`:
-- seconds until the head starts, `sweep`: seconds for the head to cross,
-- `strength` 0..1 (a hit is bolder).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local VFX = require(ReplicatedStorage.Shared.Config.VfxTextures)

local Kit = require(script.Parent.ShotFxKit)

local KnifeSwipeFx = {}

local WHITE = Kit.WHITE

type Swipe = {
	part: BasePart,
	beams: { Beam },
	a0: Attachment,
	a1: Attachment,
	arc: { Vector3 },
	t: number,
	delay: number,
	sweep: number,
	strength: number,
}
local swipes: { Swipe } = {}
local swipeConn: RBXScriptConnection? = nil
local SWIPE_LAG = 0.06 -- the tail chases the head by this long
local SWIPE_FADE = 0.12

local function bezier(p: { Vector3 }, u: number): Vector3
	local v = 1 - u
	return p[1] * (v * v) + p[2] * (2 * u * v) + p[3] * (u * u)
end

-- Aligns attachment `a` at `at` with its axis (X) along `dir`.
local function axisAlong(a: Attachment, at: Vector3, dir: Vector3)
	local d = if dir.Magnitude > 1e-4 then dir.Unit else Vector3.xAxis
	local up = if math.abs(d.Y) < 0.95 then Vector3.yAxis else Vector3.zAxis
	local back = d:Cross(up).Unit
	a.CFrame = CFrame.fromMatrix(at, d, back:Cross(d), back)
end

local function stepSwipes(dt: number)
	local cam = Workspace.CurrentCamera
	dt *= Kit.getTimeScale()
	for i = #swipes, 1, -1 do
		local w = swipes[i]
		w.t += dt
		local life = w.delay + w.sweep + SWIPE_LAG + SWIPE_FADE
		if w.t >= life or not cam then
			w.part:Destroy()
			table.remove(swipes, i)
			continue
		end
		if cam then
			w.part.CFrame = cam.CFrame
		end
		local run = w.t - w.delay
		if run <= 0 then
			for _, b in w.beams do
				b.Enabled = false
			end
			continue
		end
		local u1 = math.clamp(run / w.sweep, 0, 1)
		local u0 = math.clamp((run - SWIPE_LAG) / w.sweep, 0, 1)
		if u1 - u0 < 0.02 then
			u0 = math.max(u1 - 0.02, 0)
		end
		-- The sub-curve u0..u1 of the quadratic, as the Beam's cubic.
		local p = w.arc
		local p0, p3 = bezier(p, u0), bezier(p, u1)
		local q = p[1] * ((1 - u0) * (1 - u1))
			+ p[2] * ((1 - u0) * u1 + u0 * (1 - u1))
			+ p[3] * (u0 * u1)
		local c1, c2 = p0 + (q - p0) * (2 / 3), p3 + (q - p3) * (2 / 3)
		axisAlong(w.a0, p0, c1 - p0)
		axisAlong(w.a1, p3, p3 - c2)
		local fadeIn = math.clamp(run / 0.03, 0, 1)
		local fadeOut = 1 - math.clamp((run - w.sweep - SWIPE_LAG) / SWIPE_FADE, 0, 1)
		local alpha = fadeIn * fadeOut * w.strength
		for k, b in w.beams do
			b.Enabled = true
			b.CurveSize0 = (c1 - p0).Magnitude
			b.CurveSize1 = (p3 - c2).Magnitude
			local base = if k == 1 then 0.1 else 0.45
			local tr = 1 - (1 - base) * alpha
			b.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.55, math.min(1, tr + 0.25)),
				NumberSequenceKeypoint.new(1, tr),
			})
		end
	end
	if #swipes == 0 and swipeConn then
		swipeConn:Disconnect()
		swipeConn = nil
	end
end

function KnifeSwipeFx.swipe(arc: { Vector3 }, delay: number, sweep: number, strength: number)
	local cam = Workspace.CurrentCamera
	if not cam or #arc ~= 3 then
		return
	end
	local part = Instance.new("Part")
	part.Name = "KnifeSwipe"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.one * 0.1
	part.CFrame = cam.CFrame
	local a0 = Instance.new("Attachment")
	a0.Parent = part
	local a1 = Instance.new("Attachment")
	a1.Parent = part
	local beams = {}
	-- 1: the white core (narrow, glowing); 2: a dark steel body around it
	-- (LihFolk three tones: white rim, body, dark).
	for k, look in
		{
			{ width = 0.09, color = WHITE, emission = 1 },
			{ width = 0.3, color = Color3.fromHex("34404F"), emission = 0 }, -- dark steel: reads on bright floors
		}
	do
		local b = Instance.new("Beam")
		b.Attachment0 = a0
		b.Attachment1 = a1
		b.Texture = VFX.TRACER
		b.TextureMode = Enum.TextureMode.Stretch
		b.Width0 = look.width * 0.25 -- thin tail
		b.Width1 = look.width
		b.Color = ColorSequence.new(look.color)
		b.LightEmission = look.emission
		b.LightInfluence = 0
		b.FaceCamera = true
		b.Segments = 16
		b.Enabled = false
		b.ZOffset = k
		b.Parent = part
		table.insert(beams, b)
	end
	part.Parent = cam
	table.insert(swipes, {
		part = part,
		beams = beams,
		a0 = a0,
		a1 = a1,
		arc = arc,
		t = 0,
		delay = delay,
		sweep = math.max(sweep, 0.02),
		strength = math.clamp(strength, 0, 1),
	})
	if not swipeConn then
		swipeConn = RunService.RenderStepped:Connect(stepSwipes)
	end
end

return KnifeSwipeFx
