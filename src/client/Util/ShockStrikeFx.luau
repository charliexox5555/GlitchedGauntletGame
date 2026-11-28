--!strict
-- Electric Shock's look (Mods/ElectricShock; vault/01 Design/Abilities/Electric Shock.md). The legendary power
-- (owner 2026-11-27: "a big lightning strike down, like a smite ... really cool sound effects"):
--   latch   the orb snaps a zap onto its target; a marked ring follows their feet and a thin beam of light comes
--           down from the sky onto them, tightening and flashing faster for `warning` s; the target hears it
--   strike  THE SMITE: a huge jagged bolt (Blender Bolt mesh, flickering through three shapes) cracks down from
--           90 studs onto them with two forks and crackling beams; a white flash (on screen for anyone close),
--           a big light, two shockwave rings racing out along the floor, a burst of sparks and dust, arcs crawling
--           over the target for a second and a scorch mark left behind; a layered crack, boom, rumble and sizzle
--   chain   arcs hopping from target to target (Chain Lightning)
--   storm   the glitched Storm Call's violet bolts around the smite, with magenta static
--   beacon  the landed orb sitting charged, crackling, with its reach drawn on the floor
--   fizzle  a small spark puff where the orb died
-- Meshes: ReplicatedStorage.Abilities.ShockVFX (Ring, Bolt; tools/blender/build_mod_shockvfx.py); textures
-- STIM_BOLT (beams), STIM_ARC_2x2 (crackle), SPARK, DUST_2x2. Everything client-side and short-lived.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Tex = require(ReplicatedStorage.Shared.Config.VfxTextures)
local ModSounds = require(ReplicatedStorage.Shared.Config.ModSounds)
local ModAudio = require(script.Parent.ModAudio)
local ModProps = require(script.Parent.ModProps)

local ShockStrikeFx = {}

local WHITE_BLUE = Color3.fromHex("DDF2FF")
local CORE = Color3.fromHex("8FD8FF")
local STORM = Color3.fromHex("B07CFF") -- Storm Call (glitched): violet lightning...
local GLITCH = Color3.fromHex("FF3BD4") -- ...with magenta static
local SCORCH = Color3.fromHex("23262C")
local SKY = 90 -- studs above the target the smite starts
local FLASH_RANGE = 60 -- studs: closer than this, your screen flashes white
local S = ModSounds.ElectricShock

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

local function kit(name: string): BasePart?
	local abilities = ReplicatedStorage:FindFirstChild("Abilities")
	local vfx = abilities and abilities:FindFirstChild("ShockVFX")
	local p = vfx and vfx:FindFirstChild(name, true)
	return if p and p:IsA("BasePart") then p else nil
end

local function bare(p: BasePart, color: Color3): BasePart
	p:ClearAllChildren()
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Parent = fxFolder()
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

-- A crackling beam between two points for `life` s, re-jittered every frame.
local function zap(from: Vector3, to: Vector3, color: Color3, width: number, life: number)
	local a, b = point(from, life), point(to, life)
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Parent, a1.Parent = a, b
	local beam = Instance.new("Beam")
	beam.Attachment0, beam.Attachment1 = a0, a1
	beam.Texture = Tex.STIM_BOLT
	beam.TextureMode = Enum.TextureMode.Stretch
	beam.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.45))
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Width0, beam.Width1 = width, width * 0.8
	beam.FaceCamera = true
	beam.Segments = 14
	beam.Parent = a
	animate(life, function(k)
		beam.CurveSize0 = math.random(-40, 40) / 10
		beam.CurveSize1 = math.random(-40, 40) / 10
		beam.Transparency = NumberSequence.new(math.clamp(k * k, 0, 1))
	end)
end

local function burst(at: Vector3, color: Color3, count: number, dust: boolean)
	local p = point(at, 2)
	local e = Instance.new("ParticleEmitter")
	e.Texture = Tex.SPARK
	e.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.35))
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 0),
	})
	e.Lifetime = NumberRange.new(0.3, 0.8)
	e.Speed = NumberRange.new(16, 40)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, -40, 0)
	e.Drag = 2.5
	e.Orientation = Enum.ParticleOrientation.VelocityParallel
	e.Rate = 0
	e.Parent = p
	e:Emit(count)
	local crackle = Instance.new("ParticleEmitter")
	crackle.Texture = Tex.STIM_ARC_2x2
	crackle.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
	crackle.FlipbookMode = Enum.ParticleFlipbookMode.Random
	crackle.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.5))
	crackle.LightEmission = 1
	crackle.LightInfluence = 0
	crackle.Size = NumberSequence.new(3.2)
	crackle.Lifetime = NumberRange.new(0.08, 0.18)
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
			NumberSequenceKeypoint.new(0, 2),
			NumberSequenceKeypoint.new(1, 6),
		})
		d.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		})
		d.Lifetime = NumberRange.new(0.8, 1.3)
		d.Speed = NumberRange.new(14, 22)
		d.SpreadAngle = Vector2.new(180, 8)
		d.EmissionDirection = Enum.NormalId.Top
		d.Drag = 3
		d.Rate = 0
		d.Parent = p
		d:Emit(16)
	end
end

local function chest(model: Model): Vector3?
	local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	return if root and root:IsA("BasePart") then root.Position + Vector3.new(0, 0.6, 0) else nil
end

-- The floor under `at` (ignoring bodies and effects).
local function floorUnder(at: Vector3): Vector3
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
	local hit = Workspace:Raycast(at + Vector3.new(0, 1, 0), Vector3.new(0, -14, 0), params)
	return if hit then hit.Position else at - Vector3.new(0, 3, 0)
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
	local template = kit("Ring")
	local ring: BasePart
	if template then
		ring = bare(template:Clone(), color)
	else
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Cylinder
		ring = bare(p, color)
	end
	local base = if template then template.Size else Vector3.new(0.1, 2, 2)
	animate(life, function(k)
		local e = 1 - (1 - k) ^ 3
		local r = from + (to - from) * e
		if template then
			ring.Size = Vector3.new(base.X * r, (height or 0.6) * (1 - k * 0.6), base.Z * r)
			ring.CFrame = CFrame.new(floor + Vector3.new(0, 0.15, 0))
		else
			ring.Size = Vector3.new(0.1, r * 2, r * 2)
			ring.CFrame = CFrame.new(floor + Vector3.new(0, 0.15, 0))
				* CFrame.Angles(0, 0, math.pi / 2)
		end
		ring.Transparency = k
	end, function()
		ring:Destroy()
	end)
end

-- One lightning bolt from the sky onto `floor`: the kit Bolt flickering through three shapes, then fading.
local function bolt(top: Vector3, floor: Vector3, color: Color3, width: number, life: number)
	local template = kit("Bolt")
	if not template then
		zap(top, floor, color, width, life)
		return
	end
	local part = bare(template:Clone(), color)
	local length = (top - floor).Magnitude
	local axis = CFrame.lookAt((top + floor) / 2, floor) * CFrame.Angles(math.pi / 2, 0, 0)
	local frame = 0
	animate(life, function(k)
		frame += 1
		-- three shapes in the first frames (a real strike flickers), then it holds and fades
		local twist = if k < 0.35 then (frame % 3) * 2.1 else 0
		part.Size = Vector3.new(template.Size.X * width, length, template.Size.Z * width)
		part.CFrame = axis * CFrame.Angles(0, twist, 0)
		part.Transparency = if k < 0.35 then 0 else (k - 0.35) / 0.65
		part.Color = if k < 0.12 then Color3.new(1, 1, 1) else color
	end, function()
		part:Destroy()
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
	local strength = if mine then 0.75 else 0.5 * (1 - away / FLASH_RANGE)
	local screen = Instance.new("ScreenGui")
	screen.Name = "SmiteFlash"
	screen.IgnoreGuiInset = true
	screen.DisplayOrder = 6
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(1, 1)
	f.BorderSizePixel = 0
	f.BackgroundColor3 = Color3.new(1, 1, 1):Lerp(color, 0.15)
	f.BackgroundTransparency = 1 - strength
	f.Parent = screen
	screen.Parent = gui
	animate(0.3, function(k)
		f.BackgroundTransparency = 1 - strength * (1 - k)
	end, function()
		screen:Destroy()
	end)
end

-- The orb latched onto `target` at `at`; the smite comes in `warning` s.
function ShockStrikeFx.latch(target: Model, at: Vector3, warning: number, color: Color3)
	local body = chest(target)
	if body then
		zap(at, body, color, 0.5, 0.3)
	end
	burst(at, color, 14, false)
	ModAudio.play(S.latch, at)
	local me = Players.LocalPlayer.Character
	if me and target == me then
		ModAudio.play(S.warning) -- 2D: you're marked
	end
	local template = kit("Ring")
	local ring = if template then bare(template:Clone(), color) else nil
	local base = if template then template.Size else Vector3.one
	-- the sky beam: a thin column of light coming down onto them (the smite's aim)
	local skyA = point(Vector3.zero, warning + 0.1)
	local skyB = point(Vector3.zero, warning + 0.1)
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Parent, a1.Parent = skyA, skyB
	local beam = Instance.new("Beam")
	beam.Attachment0, beam.Attachment1 = a0, a1
	beam.Texture = Tex.STIM_BOLT
	beam.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.6))
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
		local floor = c - Vector3.new(0, 3.5, 0)
		local blink = math.sin(os.clock() * (10 + 40 * k)) > 0
		if ring then
			local r = 4 - 2 * k
			ring.Size = Vector3.new(base.X * r, 0.5, base.Z * r)
			ring.CFrame = CFrame.new(floor + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, k * 8, 0)
			ring.Transparency = if blink then 0 else 0.5
		end
		skyA.CFrame = CFrame.new(c + Vector3.new(0, SKY, 0))
		skyB.CFrame = CFrame.new(floor)
		beam.Width0, beam.Width1 = 0.2 + 1.2 * k, 0.2 + 1.2 * k
		beam.Transparency = NumberSequence.new(0.7 - 0.5 * k)
		highlight.FillTransparency = if blink then 0.5 else 0.85
		highlight.OutlineTransparency = if blink then 0 else 0.6
	end, function()
		if ring then
			ring:Destroy()
		end
		highlight:Destroy()
	end)
end

-- THE SMITE on the target at `at` (their chest), with Chain Lightning hops and splash points.
function ShockStrikeFx.strike(
	at: Vector3,
	color: Color3,
	chain: { Vector3 },
	splash: { Vector3 },
	target: Model?,
	stormy: boolean
)
	local floor = floorUnder(at)
	local tint = if stormy then STORM else color:Lerp(CORE, 0.5)
	local top = floor + Vector3.new(math.random(-6, 6), SKY, math.random(-6, 6))
	bolt(top, floor, tint, 9, 0.45)
	bolt(
		top:Lerp(floor, 0.45) + Vector3.new(5, 0, -3),
		floor + Vector3.new(2.5, 0, 1.5),
		tint,
		4,
		0.3
	)
	bolt(
		top:Lerp(floor, 0.6) + Vector3.new(-4, 0, 4),
		floor + Vector3.new(-2, 0, -2),
		tint,
		3,
		0.25
	)
	zap(top, floor, tint, 2.4, 0.4)
	zap(top + Vector3.new(3, -20, 2), floor, tint, 1.2, 0.3)
	-- light and flash
	local glow = point(floor + Vector3.new(0, 3, 0), 0.7)
	local light = Instance.new("PointLight")
	light.Color = WHITE_BLUE
	light.Range = 45
	light.Brightness = 14
	light.Shadows = true
	light.Parent = glow
	animate(0.6, function(k)
		light.Brightness = 14 * (1 - k) ^ 2
	end)
	local me = Players.LocalPlayer.Character
	screenFlash(floor, me ~= nil and target == me, tint)
	-- the ground: two shockwaves, sparks, dust, and a scorch left behind
	shockwave(floor, tint, 1, 14, 0.45, 0.8)
	task.delay(0.07, function()
		shockwave(floor, WHITE_BLUE, 1, 8, 0.35, 0.4)
	end)
	burst(floor + Vector3.new(0, 0.5, 0), tint, 60, true)
	local scorchTemplate = kit("Ring")
	if scorchTemplate then
		local scorch = bare(scorchTemplate:Clone(), SCORCH)
		scorch.Material = Enum.Material.SmoothPlastic
		local base = scorchTemplate.Size
		scorch.Size = Vector3.new(base.X * 2.2, 0.05, base.Z * 2.2)
		scorch.CFrame = CFrame.new(floor + Vector3.new(0, 0.04, 0))
		animate(3.5, function(k)
			scorch.Transparency = 0.2 + 0.8 * k
		end, function()
			scorch:Destroy()
		end)
	end
	-- arcs crawling over the target for a second
	if target then
		for i = 0, 9 do
			task.delay(i * 0.1, function()
				local c = chest(target)
				if c then
					local r = Vector3.new(
						math.random(-15, 15),
						math.random(-25, 15),
						math.random(-15, 15)
					) / 10
					zap(c + r, c - r, tint, 0.35, 0.12)
				end
			end)
		end
	end
	ModAudio.play(S.strike, floor)
	ModAudio.play(S.boom, floor)
	ModAudio.play(S.rumble, floor)
	ModAudio.play(S.sizzle, floor)
	-- Chain Lightning: arcs hopping target to target
	local from = at
	for i, p in chain do
		task.delay(0.1 * i, function()
			zap(from, p, tint, 1.4, 0.3)
			zap(from, p, WHITE_BLUE, 0.6, 0.2)
			burst(p, tint, 24, false)
			ModAudio.play(S.zap, p)
			from = p
		end)
	end
	-- the splash: arcs out to each one caught
	for _, p in splash do
		zap(at, p, tint, 0.8, 0.25)
		burst(p, tint, 12, false)
	end
end

-- Storm Call: one glitched violet bolt at `floor` (radius = its reach).
function ShockStrikeFx.stormBolt(floor: Vector3, radius: number)
	local top = floor + Vector3.new(math.random(-4, 4), SKY * 0.8, math.random(-4, 4))
	bolt(top, floor, STORM, 5, 0.3)
	zap(top, floor, GLITCH, 1, 0.25)
	shockwave(floor, STORM, 0.5, radius * 1.4, 0.35, 0.5)
	burst(floor + Vector3.new(0, 0.4, 0), GLITCH, 30, true)
	local glow = point(floor + Vector3.new(0, 2, 0), 0.4)
	local light = Instance.new("PointLight")
	light.Color = STORM
	light.Range = 26
	light.Brightness = 8
	light.Parent = glow
	ModAudio.play(S.stormBolt, floor)
	ModAudio.play(S.sizzle, floor)
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
	local zone = kit("Ring")
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
		if math.random() < 0.18 then
			local r = Vector3.new(math.random(-10, 10), math.random(0, 12), math.random(-10, 10))
				/ 10
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
	burst(at, color, 10, false)
	ModAudio.play(S.fizzle, at)
end

return ShockStrikeFx
