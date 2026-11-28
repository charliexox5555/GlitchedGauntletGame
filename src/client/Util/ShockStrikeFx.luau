--!strict
-- Electric Shock's look (Mods/ElectricShock; vault/01 Design/Abilities/Electric Shock.md). The LEGENDARY power.
-- Owner 2026-11-27: "a big lightning strike down from the sky ... it doesn't look legendary ... high level, high
-- animation, great looking ... light up the player". Built in three acts:
--   1 latch    the orb snaps a zap onto its target. A STORM gathers over them: dark faceted cloud puffs (the Smoke
--              kit's Puff meshes) swirl in 38 studs up, lit from inside by flickering lightning; a beam of light
--              comes down onto them and a marked ring follows their feet, tightening and flashing faster; the
--              world dims and cools for anyone near; the target hears it coming.
--   2 strike   THE SMITE: procedural forked lightning (midpoint-displaced jagged bolts built from glowing faceted
--              segments, a white-hot core inside a coloured glow) cracks from the cloud to the target, re-forking
--              three times in its first frames; a blinding grade pop and white flash, a light pillar, two
--              shockwave rings, glowing ground cracks, rock debris, sparks and dust, a scorch mark.
--   3 shock    the target is electrocuted for 1.4 s: their body flickers white and blue, arcs jump between their
--              limbs, sparks pour off them (and their own screen flickers).
-- Plus Chain Lightning hops, the glitched Storm Call's violet bolts, the charged beacon and the fizzle. Client-only
-- and short-lived; meshes from ReplicatedStorage.Abilities (ShockVFX Ring, SmokeVFX Puff1-3).

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Tex = require(ReplicatedStorage.Shared.Config.VfxTextures)
local ModSounds = require(ReplicatedStorage.Shared.Config.ModSounds)
local ModAudio = require(script.Parent.ModAudio)
local ModProps = require(script.Parent.ModProps)

local ShockStrikeFx = {}

local WHITE = Color3.new(1, 1, 1)
local WHITE_BLUE = Color3.fromHex("DDF2FF")
local CORE = Color3.fromHex("7FD0FF")
local STORM = Color3.fromHex("B07CFF") -- Storm Call (glitched): violet lightning...
local GLITCH = Color3.fromHex("FF3BD4") -- ...with magenta static
local CLOUD = Color3.fromHex("2A3040")
local SCORCH = Color3.fromHex("23262C")
local CLOUD_UP = 28 -- studs above the floor the storm cloud gathers (low enough to be in view at fighting range)
local NEAR = 90 -- studs: closer than this the world dims while it charges and pops on the strike
local FLASH_RANGE = 60 -- studs: closer than this your screen flashes white
local S: any = ModSounds.ElectricShock

local rng = Random.new()

local folder: Folder? = nil
local function fxFolder(): Folder
	local f = folder
	if f and f.Parent then
		return f
	end
	local made = Instance.new("Folder")
	made.Name = "ShockStrikeFx"
	made.Parent = Workspace
	folder = made
	return made
end

local function kit(model: string, name: string): BasePart?
	local abilities = ReplicatedStorage:FindFirstChild("Abilities")
	local vfx = abilities and abilities:FindFirstChild(model)
	local p = vfx and vfx:FindFirstChild(name, true)
	return if p and p:IsA("BasePart") then p else nil
end

local function bare(p: BasePart, color: Color3, material: Enum.Material?): BasePart
	p:ClearAllChildren()
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = material or Enum.Material.Neon
	p.Color = color
	p.Parent = fxFolder()
	return p
end

local function block(color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Block
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	bare(p, color, material)
	return p
end

local function point(at: Vector3, life: number): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.one * 0.2
	p.CFrame = CFrame.new(at)
	p.Parent = fxFolder()
	task.delay(life, function()
		p:Destroy()
	end)
	return p
end

-- Runs `fn(k)` every frame for `life` s (k 0..1), then `done`.
local function animate(life: number, fn: (k: number) -> (), done: (() -> ())?)
	local t0 = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local k = (os.clock() - t0) / life
		if k >= 1 then
			conn:Disconnect()
			if done then
				done()
			end
			return
		end
		fn(k)
	end)
end

-- Lightning -----------------------------------------------------------------------------------------------

-- A random direction square to `dir`.
local function across(dir: Vector3): Vector3
	local r = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1))
	local p = r - dir * r:Dot(dir)
	return if p.Magnitude > 1e-3 then p.Unit else Vector3.xAxis
end

-- A jagged path from `a` to `b`: midpoint displacement, `depth` times (2^depth segments).
local function jag(a: Vector3, b: Vector3, depth: number, spread: number): { Vector3 }
	local pts = { a, b }
	for _ = 1, depth do
		local out = { pts[1] }
		for i = 1, #pts - 1 do
			local p, q = pts[i], pts[i + 1]
			local seg = q - p
			local len = seg.Magnitude
			local dir = if len > 1e-3 then seg / len else Vector3.yAxis
			table.insert(out, (p + q) / 2 + across(dir) * len * spread * rng:NextNumber(-1, 1))
			table.insert(out, q)
		end
		pts = out
	end
	return pts
end

-- One drawn bolt: per segment a white-hot core inside a coloured glow, both faceted blocks.
type Bolt = { cores: { Part }, glows: { Part }, core: number, glow: number }

local function newBolt(count: number, color: Color3, core: number, glow: number): Bolt
	local b: Bolt = { cores = {}, glows = {}, core = core, glow = glow }
	for _ = 1, count do
		table.insert(b.glows, block(color))
		table.insert(b.cores, block(WHITE))
	end
	for _, g in b.glows do
		g.Transparency = 0.45
	end
	return b
end

local function shape(b: Bolt, pts: { Vector3 }, thin: number)
	for i, core in b.cores do
		local p, q = pts[i], pts[i + 1]
		local glow = b.glows[i]
		if not (p and q) then
			core.Transparency, glow.Transparency = 1, 1
			continue
		end
		local len = (q - p).Magnitude + 0.15
		local frame = CFrame.lookAt((p + q) / 2, q)
		-- thinner toward the tip, like a real stroke
		local taper = 1 - 0.55 * (i / #b.cores)
		local w = math.max(b.core * taper * thin, 0.05)
		local gw = math.max(b.glow * taper * thin, 0.1)
		core.Size = Vector3.new(w, w, len)
		core.CFrame = frame * CFrame.Angles(0, 0, math.pi / 4)
		glow.Size = Vector3.new(gw, gw, len)
		glow.CFrame = frame * CFrame.Angles(0, 0, math.pi / 4)
	end
end

local function fadeBolt(b: Bolt, k: number)
	for i, core in b.cores do
		core.Transparency = math.clamp(k * 1.2, 0, 1)
		b.glows[i].Transparency = 0.45 + 0.55 * k
	end
end

local function dropBolt(b: Bolt)
	for i, core in b.cores do
		core:Destroy()
		b.glows[i]:Destroy()
	end
end

-- A full lightning strike from `top` to `floor`: a main bolt plus `forks` branches, re-forking `flickers` times
-- in its first frames, then fading over `life` s.
local function lightning(
	top: Vector3,
	floor: Vector3,
	color: Color3,
	core: number,
	glow: number,
	forks: number,
	life: number
)
	local depth = 5
	local main = newBolt(2 ^ depth, color, core, glow)
	local branches: { Bolt } = {}
	for _ = 1, forks do
		table.insert(branches, newBolt(8, color, core * 0.45, glow * 0.5))
	end
	local function reshape()
		local pts = jag(top, floor, depth, 0.16)
		shape(main, pts, 1)
		for _, br in branches do
			-- a branch leaves the main path in its upper two thirds and reaches down and out
			local from = pts[rng:NextInteger(4, math.floor(#pts * 0.66))]
			local drop = (floor - top).Magnitude * rng:NextNumber(0.15, 0.32)
			local out = across(Vector3.yAxis) * drop * rng:NextNumber(0.5, 1)
			shape(br, jag(from, from + out - Vector3.new(0, drop, 0), 3, 0.25), 1)
		end
	end
	reshape()
	local reforks = { 0.05, 0.1, 0.16 }
	local t0 = os.clock()
	animate(life, function(k)
		local t = os.clock() - t0
		if reforks[1] and t >= reforks[1] then
			table.remove(reforks, 1)
			reshape()
		end
		local fade = math.clamp((k - 0.3) / 0.7, 0, 1)
		fadeBolt(main, fade)
		for _, br in branches do
			fadeBolt(br, math.clamp(fade * 1.4, 0, 1))
		end
	end, function()
		dropBolt(main)
		for _, br in branches do
			dropBolt(br)
		end
	end)
end

-- A crackling beam between two points for `life` s, re-jittered every frame.
local function zap(from: Vector3, to: Vector3, color: Color3, width: number, life: number)
	local a, b = point(from, life), point(to, life)
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Parent, a1.Parent = a, b
	local beam = Instance.new("Beam")
	beam.Attachment0, beam.Attachment1 = a0, a1
	beam.Texture = Tex.STIM_BOLT
	beam.TextureMode = Enum.TextureMode.Stretch
	beam.Color = ColorSequence.new(color:Lerp(WHITE, 0.45))
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Width0, beam.Width1 = width, width * 0.8
	beam.FaceCamera = true
	beam.Segments = 14
	beam.Parent = a
	animate(life, function(k)
		beam.CurveSize0 = rng:NextNumber(-4, 4)
		beam.CurveSize1 = rng:NextNumber(-4, 4)
		beam.Transparency = NumberSequence.new(math.clamp(k * k, 0, 1))
	end)
end

local function burst(at: Vector3, color: Color3, count: number, dust: boolean)
	local p = point(at, 2)
	local e = Instance.new("ParticleEmitter")
	e.Texture = Tex.SPARK
	e.Color = ColorSequence.new(color:Lerp(WHITE, 0.35))
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Size =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 0) })
	e.Lifetime = NumberRange.new(0.3, 0.9)
	e.Speed = NumberRange.new(18, 46)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, -45, 0)
	e.Drag = 2.5
	e.Orientation = Enum.ParticleOrientation.VelocityParallel
	e.Rate = 0
	e.Parent = p
	e:Emit(count)
	local crackle = Instance.new("ParticleEmitter")
	crackle.Texture = Tex.STIM_ARC_2x2
	crackle.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
	crackle.FlipbookMode = Enum.ParticleFlipbookMode.Random
	crackle.Color = ColorSequence.new(color:Lerp(WHITE, 0.5))
	crackle.LightEmission = 1
	crackle.LightInfluence = 0
	crackle.Size = NumberSequence.new(3.6)
	crackle.Lifetime = NumberRange.new(0.08, 0.2)
	crackle.Rotation = NumberRange.new(0, 360)
	crackle.Speed = NumberRange.new(0)
	crackle.Rate = 0
	crackle.Parent = p
	crackle:Emit(math.max(4, count // 6))
	if dust then
		local d = Instance.new("ParticleEmitter")
		d.Texture = Tex.DUST_2x2
		d.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
		d.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
		d.Color = ColorSequence.new(Color3.fromHex("8B8F96"))
		d.LightInfluence = 0.6
		d.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 2.5),
			NumberSequenceKeypoint.new(1, 8),
		})
		d.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.3),
			NumberSequenceKeypoint.new(1, 1),
		})
		d.Lifetime = NumberRange.new(0.9, 1.5)
		d.Speed = NumberRange.new(16, 26)
		d.SpreadAngle = Vector2.new(180, 8)
		d.EmissionDirection = Enum.NormalId.Top
		d.Drag = 3
		d.Rate = 0
		d.Parent = p
		d:Emit(20)
	end
end

local function chest(model: Model): Vector3?
	local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	return if root and root:IsA("BasePart") then root.Position + Vector3.new(0, 0.6, 0) else nil
end

local function floorParams(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local skip: { Instance } = { fxFolder() }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(skip, p.Character)
		end
	end
	local dummies = Workspace:FindFirstChild("Dummies")
	if dummies then
		table.insert(skip, dummies)
	end
	params.FilterDescendantsInstances = skip
	return params
end

-- The floor under `at` (ignoring bodies and effects), and its colour for the debris.
local function floorUnder(at: Vector3): (Vector3, Color3)
	local hit = Workspace:Raycast(at + Vector3.new(0, 1, 0), Vector3.new(0, -14, 0), floorParams())
	if hit then
		local inst = hit.Instance
		return hit.Position, if inst:IsA("BasePart") then inst.Color else Color3.fromHex("8B8F96")
	end
	return at - Vector3.new(0, 3, 0), Color3.fromHex("8B8F96")
end

-- A flat ring on the floor (the kit's Ring) racing from `from` to `to` studs radius over `life` s.
local function shockwave(
	floor: Vector3,
	color: Color3,
	from: number,
	to: number,
	life: number,
	height: number?
)
	local template = kit("ShockVFX", "Ring")
	if not template then
		return
	end
	local ring = bare(template:Clone(), color)
	local base = template.Size
	animate(life, function(k)
		local e = 1 - (1 - k) ^ 3
		local r = from + (to - from) * e
		ring.Size = Vector3.new(base.X * r, (height or 0.6) * (1 - k * 0.6), base.Z * r)
		ring.CFrame = CFrame.new(floor + Vector3.new(0, 0.15, 0))
		ring.Transparency = k
	end, function()
		ring:Destroy()
	end)
end

-- The world dims and cools around a charging smite, then pops white on the strike (only for viewers near it).
local function grade(at: Vector3, charge: number)
	local cam = Workspace.CurrentCamera
	if not cam or (cam.CFrame.Position - at).Magnitude > NEAR then
		return
	end
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "SmiteGrade"
	cc.Parent = Lighting
	animate(charge, function(k)
		cc.Brightness = -0.12 * k
		cc.Saturation = -0.25 * k
		cc.TintColor = WHITE:Lerp(Color3.fromHex("C9DBFF"), k)
	end, function()
		-- the strike: a blinding pop, then back to normal
		animate(0.55, function(k)
			local pop = (1 - k) ^ 2
			cc.Brightness = 0.45 * pop
			cc.Contrast = 0.25 * pop
			cc.Saturation = -0.25 * (1 - k)
			cc.TintColor = WHITE
		end, function()
			cc:Destroy()
		end)
	end)
end

-- A white flash on your screen when you're close to a smite (stronger when it's you).
local function screenFlash(at: Vector3, mine: boolean, color: Color3)
	local cam = Workspace.CurrentCamera
	local gui = Players.LocalPlayer:FindFirstChild("PlayerGui")
	if not cam or not gui then
		return
	end
	local away = (cam.CFrame.Position - at).Magnitude
	if away > FLASH_RANGE and not mine then
		return
	end
	local strength = if mine then 0.8 else 0.55 * (1 - away / FLASH_RANGE)
	local screen = Instance.new("ScreenGui")
	screen.Name = "SmiteFlash"
	screen.IgnoreGuiInset = true
	screen.DisplayOrder = 6
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(1, 1)
	f.BorderSizePixel = 0
	f.BackgroundColor3 = WHITE:Lerp(color, 0.15)
	f.BackgroundTransparency = 1 - strength
	f.Parent = screen
	screen.Parent = gui
	animate(0.35, function(k)
		f.BackgroundTransparency = 1 - strength * (1 - k) ^ 2
	end, function()
		screen:Destroy()
	end)
end

-- The storm --------------------------------------------------------------------------------------------------

type Storm = { puffs: { BasePart }, light: PointLight, anchor: Part, alive: boolean }
local storms: { [Model]: Storm } = {}

-- Dark faceted cloud puffs swirling in over `floor`, lit from inside, for `life` s (the strike ends it).
local function gather(target: Model, floor: Vector3, life: number, color: Color3): Storm
	local centre = floor + Vector3.new(0, CLOUD_UP, 0)
	local anchor = point(centre, life + 2)
	local light = Instance.new("PointLight")
	light.Color = color:Lerp(WHITE, 0.4)
	light.Range = 40
	light.Brightness = 0
	light.Parent = anchor
	local storm: Storm = { puffs = {}, light = light, anchor = anchor, alive = true }
	local homes: { { a: number, r: number, y: number, s: number, base: Vector3 } } = {}
	for i = 1, 12 do
		local template = kit("SmokeVFX", "Puff" .. tostring((i - 1) % 3 + 1))
		if not template then
			break
		end
		local p = bare(template:Clone(), CLOUD, Enum.Material.SmoothPlastic)
		p.Transparency = 1
		table.insert(storm.puffs, p)
		table.insert(homes, {
			a = (i / 12) * math.pi * 2 + rng:NextNumber(-0.2, 0.2),
			r = rng:NextNumber(3, 9),
			y = rng:NextNumber(-1.5, 1.5),
			s = rng:NextNumber(6, 10),
			base = template.Size,
		})
	end
	storms[target] = storm
	local t0 = os.clock()
	animate(life + 1.2, function(_k)
		local t = os.clock() - t0
		local build = math.clamp(t / life, 0, 1)
		local gone = if storm.alive then 0 else math.clamp((t - life) / 1.2, 0, 1)
		for i, p in storm.puffs do
			local h = homes[i]
			local a = h.a + t * (0.8 + 0.6 * build)
			local r = h.r * (1.6 - 0.6 * build)
			p.Size = h.base * h.s * (0.4 + 0.6 * build) * (1 - 0.5 * gone)
			p.CFrame = CFrame.new(centre + Vector3.new(math.cos(a) * r, h.y, math.sin(a) * r))
				* CFrame.Angles(0, a, 0)
			p.Transparency = math.max(1 - build * 1.6, 0) + gone
		end
		-- lightning flickering inside the cloud, more often as it builds
		local flicker = rng:NextNumber() < 0.08 + 0.3 * build
		light.Brightness = if storm.alive and flicker then 6 + 8 * build else light.Brightness * 0.8
		if storm.alive and flicker and #storm.puffs > 1 and rng:NextNumber() < 0.35 then
			local a = storm.puffs[rng:NextInteger(1, #storm.puffs)].Position
			local b = storm.puffs[rng:NextInteger(1, #storm.puffs)].Position
			zap(a, b, color, 0.6, 0.08)
		end
	end, function()
		for _, p in storm.puffs do
			p:Destroy()
		end
		if storms[target] == storm then
			storms[target] = nil
		end
	end)
	return storm
end

-- The target being electrocuted for `life` s: body flicker, arcs between limbs, sparks pouring off.
local function electrocute(target: Model, color: Color3, life: number)
	local highlight = Instance.new("Highlight")
	highlight.FillColor = WHITE
	highlight.OutlineColor = color:Lerp(WHITE, 0.3)
	highlight.FillTransparency = 0
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Adornee = target
	highlight.Parent = fxFolder()
	local limbs: { BasePart } = {}
	for _, d in target:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 and d.Name ~= "HumanoidRootPart" then
			table.insert(limbs, d)
		end
	end
	local root = target:FindFirstChild("HumanoidRootPart")
	local spark: ParticleEmitter? = nil
	if root and root:IsA("BasePart") then
		local e = Instance.new("ParticleEmitter")
		e.Texture = Tex.SPARK
		e.Color = ColorSequence.new(color:Lerp(WHITE, 0.4))
		e.LightEmission = 1
		e.LightInfluence = 0
		e.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.25),
			NumberSequenceKeypoint.new(1, 0),
		})
		e.Lifetime = NumberRange.new(0.2, 0.5)
		e.Speed = NumberRange.new(8, 18)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Acceleration = Vector3.new(0, -30, 0)
		e.Orientation = Enum.ParticleOrientation.VelocityParallel
		e.Rate = 60
		e.Parent = root
		spark = e
	end
	local mine = Players.LocalPlayer.Character == target
	local veil: Frame? = nil
	if mine then
		local gui = Players.LocalPlayer:FindFirstChild("PlayerGui")
		if gui then
			local screen = Instance.new("ScreenGui")
			screen.Name = "ShockVeil"
			screen.IgnoreGuiInset = true
			screen.DisplayOrder = 6
			local f = Instance.new("Frame")
			f.Size = UDim2.fromScale(1, 1)
			f.BorderSizePixel = 0
			f.BackgroundColor3 = color
			f.BackgroundTransparency = 1
			f.Parent = screen
			screen.Parent = gui
			veil = f
		end
	end
	local nextArc = 0
	local t0 = os.clock()
	animate(life, function(k)
		local t = os.clock() - t0
		local on = math.sin(t * 70) > 0
		highlight.FillColor = if on then WHITE else color
		highlight.FillTransparency = 0.15 + 0.7 * k + (if on then 0 else 0.15)
		highlight.OutlineTransparency = k
		if t >= nextArc and #limbs > 1 then
			nextArc = t + 0.05
			for _ = 1, 2 do
				local a = limbs[rng:NextInteger(1, #limbs)].Position
				local b = limbs[rng:NextInteger(1, #limbs)].Position
				if (a - b).Magnitude > 0.5 then
					zap(a, b, color, 0.28, 0.07)
				end
			end
		end
		if veil then
			veil.BackgroundTransparency = if on then 0.75 + 0.25 * k else 0.9 + 0.1 * k
		end
	end, function()
		highlight:Destroy()
		if spark then
			spark:Destroy()
		end
		if veil then
			(veil.Parent :: Instance):Destroy()
		end
	end)
end

-- Acts ---------------------------------------------------------------------------------------------------

-- 1. The orb latched onto `target` at `at`; the smite comes in `warning` s.
function ShockStrikeFx.latch(target: Model, at: Vector3, warning: number, color: Color3)
	local body = chest(target)
	if body then
		zap(at, body, color, 0.6, 0.35)
		zap(at, body, WHITE_BLUE, 0.25, 0.25)
	end
	burst(at, color, 18, false)
	ModAudio.play(S.latch, at)
	ModAudio.play(S.charge, at)
	local me = Players.LocalPlayer.Character
	if me and target == me then
		ModAudio.play(S.warning) -- 2D: you're marked
	end
	local floor = if body then floorUnder(body) else at
	gather(target, floor, warning, color)
	grade(floor, warning)
	local template = kit("ShockVFX", "Ring")
	local ring = if template then bare(template:Clone(), color) else nil
	local base = if template then template.Size else Vector3.one
	-- the beam of light coming down onto them from the cloud
	local skyA = point(Vector3.zero, warning + 0.1)
	local skyB = point(Vector3.zero, warning + 0.1)
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Parent, a1.Parent = skyA, skyB
	local beam = Instance.new("Beam")
	beam.Attachment0, beam.Attachment1 = a0, a1
	beam.Texture = Tex.STIM_BOLT
	beam.Color = ColorSequence.new(color:Lerp(WHITE, 0.6))
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.FaceCamera = true
	beam.Parent = skyA
	local highlight = Instance.new("Highlight")
	highlight.FillColor = color
	highlight.OutlineColor = WHITE_BLUE
	highlight.FillTransparency = 1
	highlight.OutlineTransparency = 1
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Adornee = target
	highlight.Parent = fxFolder()
	animate(math.max(warning, 0.05), function(k)
		local c = chest(target)
		if not c then
			return
		end
		local feet = c - Vector3.new(0, 3.5, 0)
		local blink = math.sin(os.clock() * (10 + 40 * k)) > 0
		if ring then
			local r = 4 - 2 * k
			ring.Size = Vector3.new(base.X * r, 0.5, base.Z * r)
			ring.CFrame = CFrame.new(feet + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, k * 8, 0)
			ring.Transparency = if blink then 0 else 0.5
		end
		skyA.CFrame = CFrame.new(c + Vector3.new(0, CLOUD_UP, 0))
		skyB.CFrame = CFrame.new(feet)
		beam.Width0, beam.Width1 = 0.2 + 1.4 * k, 0.2 + 1.4 * k
		beam.Transparency = NumberSequence.new(0.75 - 0.55 * k)
		highlight.FillTransparency = if blink then 0.45 else 0.85
		highlight.OutlineTransparency = if blink then 0 else 0.6
	end, function()
		if ring then
			ring:Destroy()
		end
		highlight:Destroy()
	end)
end

-- 2 + 3. THE SMITE on the target at `at` (their chest), with Chain Lightning hops and splash points.
function ShockStrikeFx.strike(
	at: Vector3,
	color: Color3,
	chain: { Vector3 },
	splash: { Vector3 },
	target: Model?,
	stormy: boolean
)
	local floor, ground = floorUnder(at)
	local tint = if stormy then STORM else color:Lerp(CORE, 0.5)
	local storm = if target then storms[target] else nil
	if storm then
		storm.alive = false -- it breaks up after the strike
	end
	local top = floor + Vector3.new(rng:NextNumber(-3, 3), CLOUD_UP, rng:NextNumber(-3, 3))
	lightning(top, floor, tint, 0.9, 2.8, 4, 0.6)
	task.delay(0.07, function()
		lightning(top + Vector3.new(2, 0, -2), floor, tint, 0.45, 1.6, 2, 0.35)
	end)
	-- the light pillar
	local pillar = block(tint:Lerp(WHITE, 0.5))
	animate(0.5, function(k)
		local w = 4.5 * (1 - k) ^ 2 + 0.1
		pillar.Size = Vector3.new(w, CLOUD_UP, w)
		pillar.CFrame = CFrame.new(floor + Vector3.new(0, CLOUD_UP / 2, 0))
			* CFrame.Angles(0, math.pi / 4, 0)
		pillar.Transparency = 0.2 + 0.8 * k
	end, function()
		pillar:Destroy()
	end)
	-- light, grade pop, flash
	local glow = point(floor + Vector3.new(0, 3, 0), 0.8)
	local light = Instance.new("PointLight")
	light.Color = WHITE_BLUE
	light.Range = 55
	light.Brightness = 18
	light.Shadows = true
	light.Parent = glow
	animate(0.7, function(k)
		light.Brightness = 18 * (1 - k) ^ 2
	end)
	local me = Players.LocalPlayer.Character
	screenFlash(floor, me ~= nil and target == me, tint)
	-- the ground: shockwaves, cracks, debris, sparks, dust and a scorch
	shockwave(floor, tint, 1, 16, 0.5, 0.9)
	task.delay(0.08, function()
		shockwave(floor, WHITE_BLUE, 1, 9, 0.4, 0.4)
	end)
	burst(floor + Vector3.new(0, 0.5, 0), tint, 80, true)
	for i = 1, 8 do
		local a = (i / 8) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local len = rng:NextNumber(4, 9)
		local crack = block(tint)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		crack.Size = Vector3.new(0.25, 0.06, len)
		crack.CFrame = CFrame.lookAt(
			floor + dir * len / 2 + Vector3.new(0, 0.05, 0),
			floor + dir * len + Vector3.new(0, 0.05, 0)
		)
		animate(1.6, function(k)
			crack.Transparency = k ^ 0.7
		end, function()
			crack:Destroy()
		end)
	end
	for _ = 1, 10 do
		local chunk = block(ground:Lerp(SCORCH, 0.35), Enum.Material.SmoothPlastic)
		chunk.Size = Vector3.new(
			rng:NextNumber(0.3, 0.8),
			rng:NextNumber(0.25, 0.6),
			rng:NextNumber(0.3, 0.8)
		)
		local v = across(Vector3.yAxis) * rng:NextNumber(10, 22)
			+ Vector3.new(0, rng:NextNumber(14, 26), 0)
		local spin =
			Vector3.new(rng:NextNumber(-12, 12), rng:NextNumber(-12, 12), rng:NextNumber(-12, 12))
		local start = floor + Vector3.new(0, 0.4, 0)
		animate(0.9, function(k)
			local t = k * 0.9
			local p = start + v * t + Vector3.new(0, -45 * t * t, 0)
			chunk.CFrame = CFrame.new(p) * CFrame.Angles(spin.X * t, spin.Y * t, spin.Z * t)
			chunk.Transparency = math.clamp((k - 0.6) / 0.4, 0, 1)
		end, function()
			chunk:Destroy()
		end)
	end
	local scorchTemplate = kit("ShockVFX", "Ring")
	if scorchTemplate then
		local scorch = bare(scorchTemplate:Clone(), SCORCH, Enum.Material.SmoothPlastic)
		local base = scorchTemplate.Size
		scorch.Size = Vector3.new(base.X * 2.6, 0.05, base.Z * 2.6)
		scorch.CFrame = CFrame.new(floor + Vector3.new(0, 0.04, 0))
		animate(4, function(k)
			scorch.Transparency = 0.15 + 0.85 * k
		end, function()
			scorch:Destroy()
		end)
	end
	if target then
		electrocute(target, tint, 1.4)
	end
	ModAudio.play(S.strike, floor) -- one designed file: crack, sub boom, sizzle, rolling thunder
	-- Chain Lightning: arcs hopping target to target
	local from = at
	for i, p in chain do
		task.delay(0.12 * i, function()
			lightning(from, p, tint, 0.35, 1.1, 1, 0.3)
			burst(p, tint, 30, false)
			ModAudio.play(S.zap, p)
			from = p
		end)
	end
	-- the splash: arcs out to each one caught
	for _, p in splash do
		lightning(at, p, tint, 0.25, 0.8, 0, 0.25)
		burst(p, tint, 14, false)
	end
end

-- Storm Call: one glitched violet bolt at `floor` (radius = its reach).
function ShockStrikeFx.stormBolt(floor: Vector3, radius: number)
	local top = floor + Vector3.new(rng:NextNumber(-4, 4), CLOUD_UP, rng:NextNumber(-4, 4))
	lightning(top, floor, STORM, 0.6, 2, 2, 0.4)
	zap(top, floor, GLITCH, 1, 0.25)
	shockwave(floor, STORM, 0.5, radius * 1.5, 0.4, 0.5)
	burst(floor + Vector3.new(0, 0.4, 0), GLITCH, 40, true)
	local glow = point(floor + Vector3.new(0, 2, 0), 0.5)
	local light = Instance.new("PointLight")
	light.Color = STORM
	light.Range = 30
	light.Brightness = 10
	light.Parent = glow
	ModAudio.play(S.stormBolt, floor)
end

local beacons: { [number]: Model } = {}

-- The landed orb, charged, for `life` s (it latches anyone who comes within `radius`).
function ShockStrikeFx.beacon(
	start: number,
	at: Vector3,
	life: number,
	radius: number,
	color: Color3
)
	local template = ModProps.get("ElectricShock", color)
	if not template then
		return
	end
	local orb = template:Clone()
	orb.Parent = fxFolder()
	beacons[start] = orb
	local zone = kit("ShockVFX", "Ring")
	local ring = if zone then bare(zone:Clone(), color) else nil
	local base = if zone then zone.Size else Vector3.one
	local hum =
		ModAudio.hum(S.beacon, orb.PrimaryPart or orb:FindFirstChildWhichIsA("BasePart", true))
	local t0 = os.clock()
	animate(life + 0.2, function(_k)
		if not orb.Parent then
			return
		end
		local t = os.clock() - t0
		orb:PivotTo(
			CFrame.new(at + Vector3.new(0, 0.45 + math.sin(t * 6) * 0.08, 0))
				* CFrame.Angles(0, t * 4, 0)
		)
		if ring then
			ring.Size = Vector3.new(base.X * radius, 0.15, base.Z * radius)
			ring.CFrame = CFrame.new(at + Vector3.new(0, 0.08, 0))
			ring.Transparency = 0.55 + 0.35 * math.abs(math.sin(t * 5))
		end
		if rng:NextNumber() < 0.2 then
			local r =
				Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0, 1.2), rng:NextNumber(-1, 1))
			zap(at + Vector3.new(0, 0.45, 0), at + r, color, 0.3, 0.1)
		end
	end, function()
		ModAudio.stopHum(hum)
		if ring then
			ring:Destroy()
		end
		if beacons[start] == orb then
			beacons[start] = nil
		end
		orb:Destroy()
	end)
end

-- The throw that started at `start` is done (it latched or fizzled): its landed orb goes.
function ShockStrikeFx.endBeacon(start: unknown)
	if typeof(start) ~= "number" then
		return
	end
	local orb = beacons[start]
	if orb then
		beacons[start] = nil
		orb:Destroy()
	end
end

function ShockStrikeFx.fizzle(at: Vector3, color: Color3)
	burst(at, color, 12, false)
	ModAudio.play(S.fizzle, at)
end

return ShockStrikeFx
