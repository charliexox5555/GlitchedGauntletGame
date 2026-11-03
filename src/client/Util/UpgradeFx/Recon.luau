--!strict
-- Recon's upgrade levels on the client (vault/01 Design/Abilities/Upgrade
-- Paths.md → 6. Recon). A Recharge and B More Pulses look like L1 (each pulse
-- is drawn by ModFxController, however many there are). G Ping Spike, the
-- glitched path, has its own look over the magenta glitch static
-- (TeamColor.GLITCH), its theme a corrupted network ping:
--   ReconStick   the dart arming: dead pixels crackle around it and a whine
--                rises until the spike (the window to shoot it down)
--   ReconPulse   one huge corrupted scan instead of the clean ring: a ring of
--                torn pixel slabs and a shimmer shell stuttering out to the
--                radius (dropped frames), outlined through walls for everyone
--                in range, glitch rings, a ground scan, a low sonar boom with
--                static; the screen tears as the wave passes you
--   Reveal       (the caster's team) revealed enemies get an outline that
--                tears between magenta and the enemy colour; at G3 the caster
--                sees "+20%" over them while the bonus lasts
--   Revealed     (the revealed player) magenta screen tears and a static
--                burst on top of the usual warning (ModFeelController)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Mods = require(Shared.Mods)
local Tex = require(Shared.Config.VfxTextures)

local CameraController = require(script.Parent.Parent.Parent.Controllers.CameraController)
local ModAudio = require(script.Parent.Parent.ModAudio)
local ModVfx = require(script.Parent.Parent.ModVfx)
local TeamColor = require(script.Parent.Parent.TeamColor)
local Types = require(script.Parent.Types)

local S = ModAudio.SOUNDS.Recon
local GLITCH = TeamColor.GLITCH
local WHITE = Color3.new(1, 1, 1)

local ARM_PIXELS = 12 -- dead pixels around the arming dart (at the spike)
local ARM_SPREAD = 1.6 -- studs around the dart
local WAVE_TIME = 0.9 -- the wave's sweep out to the radius
local WAVE_FADE = 0.45 -- then it breaks up
local WAVE_FPS = 14 -- it grows in steps (dropped frames), not smoothly
local WAVE_SLABS = 36 -- torn pixel slabs around the wave front
local TEAR_HZ = 12 -- how often outlines, tags and slabs re-roll their glitch
local PASS_TEAR = 0.25 -- screen tear (seconds) as the wave passes you
local REVEALED_TEAR = 0.45 -- the revealed player's screen tear
local TEAR_BARS = 9

local player = Players.LocalPlayer
local rng = Random.new()

local folder: Folder? = nil

local function fxFolder(): Folder
	local f = folder
	if f and f.Parent then
		return f
	end
	local made = Instance.new("Folder")
	made.Name = "ReconUpgradeFx"
	made.Parent = Workspace
	folder = made
	return made
end

local function isSpike(data: { [string]: any }): boolean
	local level = data.level
	if data.id ~= "Recon" or typeof(level) ~= "string" then
		return false
	end
	local stats = Mods.stats("Recon", level)
	return stats ~= nil and stats.behaviour == "Spike"
end

local function teamColor(data: { [string]: any }): Color3
	if data.caster == player then
		return TeamColor.ALLY
	end
	return TeamColor.forTeam(if typeof(data.team) == "number" then data.team else nil)
end

-- Glitch colour picks: mostly magenta, some team colour, a white frame now
-- and then.
local function glitchColor(team: Color3): Color3
	local r = rng:NextNumber()
	return if r < 0.55 then GLITCH elseif r < 0.9 then team else WHITE
end

-- Pixels (the arming crackle and the wave's slabs) --------------------------------

local pixelFree: { BasePart } = {}

local function takePixel(): BasePart
	local p = table.remove(pixelFree)
	if not p then
		local made = Instance.new("Part")
		made.Anchored = true
		made.CanCollide = false
		made.CanQuery = false
		made.CanTouch = false
		made.CastShadow = false
		made.Material = Enum.Material.Neon
		made.Size = Vector3.one * 0.2
		p = made
	end
	return p :: BasePart
end

local function freePixel(p: BasePart)
	p.Parent = nil
	table.insert(pixelFree, p)
end

-- The dart arming -----------------------------------------------------------------

type Arm = {
	at: Vector3,
	color: Color3,
	born: number,
	life: number,
	pixels: { BasePart },
	nextRoll: number,
}
local arms: { Arm } = {}

local function onStick(data: { [string]: any })
	local at = data.at
	if typeof(at) ~= "Vector3" then
		return
	end
	local delay = if typeof(data.delay) == "number" then math.clamp(data.delay, 0.1, 3) else 0.5
	ModAudio.play(S.spikeArm, at)
	local pixels = {}
	for _ = 1, ARM_PIXELS do
		local p = takePixel()
		p.Transparency = 1
		p.Parent = fxFolder()
		table.insert(pixels, p)
	end
	table.insert(arms, {
		at = at,
		color = teamColor(data),
		born = os.clock(),
		life = delay,
		pixels = pixels,
		nextRoll = 0,
	})
end

local function stepArms(now: number)
	for i = #arms, 1, -1 do
		local a = arms[i]
		local k = (now - a.born) / a.life
		if k >= 1 then
			for _, p in a.pixels do
				freePixel(p)
			end
			table.remove(arms, i)
			continue
		end
		if now < a.nextRoll then
			continue
		end
		a.nextRoll = now + 1 / TEAR_HZ * 0.6
		-- More of them, and further out, as the spike gets close.
		local shown = math.ceil(#a.pixels * (0.3 + 0.7 * k))
		for j, p in a.pixels do
			if j > shown then
				p.Transparency = 1
				continue
			end
			local reach = ARM_SPREAD * (0.4 + 0.6 * k)
			p.Size = Vector3.new(
				rng:NextNumber(0.08, 0.5),
				rng:NextNumber(0.06, 0.18),
				rng:NextNumber(0.08, 0.3)
			)
			p.CFrame = CFrame.new(
				a.at
					+ Vector3.new(
						rng:NextNumber(-reach, reach),
						rng:NextNumber(-reach, reach) * 0.6,
						rng:NextNumber(-reach, reach)
					)
			)
			p.Color = glitchColor(a.color)
			p.Transparency = rng:NextNumber(0, 0.35)
		end
	end
end

-- Screen tear (the wave passing you; being revealed) --------------------------------

local tearGui: ScreenGui? = nil
local tearTint: Frame? = nil
local tearBars: { Frame } = {}
local tearUntil = 0
local tearLength = 1
local tearStrength = 0
local tearNextRoll = 0

local function tearUi(): ScreenGui
	local existing = tearGui
	if existing and existing.Parent then
		return existing
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "ReconSpikeTear"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 20
	gui.Enabled = false
	local tint = Instance.new("Frame")
	tint.Size = UDim2.fromScale(1, 1)
	tint.BorderSizePixel = 0
	tint.BackgroundColor3 = GLITCH
	tint.BackgroundTransparency = 1
	tint.Parent = gui
	tearTint = tint
	table.clear(tearBars)
	for _ = 1, TEAR_BARS do
		local bar = Instance.new("Frame")
		bar.BorderSizePixel = 0
		bar.BackgroundTransparency = 1
		bar.Parent = gui
		table.insert(tearBars, bar)
	end
	gui.Parent = player:WaitForChild("PlayerGui")
	tearGui = gui
	return gui
end

local function screenTear(length: number, strength: number)
	local now = os.clock()
	-- A tear still running keeps the stronger of the two.
	tearStrength = math.max(if now < tearUntil then tearStrength else 0, strength)
	if now + length > tearUntil then
		tearUntil = now + length
		tearLength = length
	end
	tearUi().Enabled = true
	tearNextRoll = 0
end

local function stepTear(now: number)
	local gui = tearGui
	if not gui or not gui.Enabled then
		return
	end
	if now >= tearUntil then
		gui.Enabled = false
		tearStrength = 0
		return
	end
	local left = (tearUntil - now) / tearLength -- 1 → 0
	local tint = tearTint
	if tint then
		tint.BackgroundTransparency = 1 - 0.12 * tearStrength * left
	end
	if now < tearNextRoll then
		return
	end
	tearNextRoll = now + 1 / 20
	for _, bar in tearBars do
		if rng:NextNumber() > 0.75 * left then
			bar.BackgroundTransparency = 1
			continue
		end
		local h = rng:NextNumber(0.006, 0.05)
		bar.Size = UDim2.new(rng:NextNumber(0.3, 1.2), 0, h, 0)
		bar.Position = UDim2.fromScale(rng:NextNumber(-0.2, 0.6), rng:NextNumber(0, 1 - h))
		bar.BackgroundColor3 = if rng:NextNumber() < 0.7 then GLITCH else WHITE
		bar.BackgroundTransparency = 1 - rng:NextNumber(0.25, 0.6) * tearStrength
	end
end

-- The spike's wave -----------------------------------------------------------------

type Wave = {
	at: Vector3,
	radius: number,
	color: Color3,
	born: number,
	model: Model,
	shell: Part,
	slabs: { BasePart },
	angles: { number },
	highlight: Highlight,
	nextStep: number,
	passed: boolean,
}
local waves: { Wave } = {}

local function floorUnder(at: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { fxFolder() }
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(exclude, other.Character)
		end
	end
	for _, name in { "ModObjects", "ModFx", "ModVfx" } do
		local f = Workspace:FindFirstChild(name)
		if f then
			table.insert(exclude, f)
		end
	end
	params.FilterDescendantsInstances = exclude
	local down = Workspace:Raycast(at, Vector3.new(0, -8, 0), params)
	return if down then down.Position + Vector3.new(0, 0.05, 0) else at
end

local function onSpike(data: { [string]: any })
	local at, radius = data.at, data.radius
	if typeof(at) ~= "Vector3" or typeof(radius) ~= "number" then
		return
	end
	radius = math.clamp(radius, 1, 200)
	local color = teamColor(data)
	local d = radius * 2
	ModAudio.play(S.spike, at)
	ModAudio.play(S.spikeStatic, at)
	-- The dart flashes out in static.
	ModVfx.burst(at, GLITCH, 36, "Sparkle")
	ModVfx.burst(at, color, 16, "Glow")
	-- Flat glitch rings at three heights, spinning against each other, and
	-- the scan across the ground: the clean L1 look, corrupted.
	for i, dy in { -3, 0, 3 } do
		ModVfx.quad({
			texture = if i == 2 then Tex.RECON_SCAN_RING else Tex.MOD_RING_DASHED,
			cframe = CFrame.new(at + Vector3.new(0, dy, 0)),
			from = 2,
			to = d * (if i == 2 then 1 else 0.85),
			color = if i == 2 then GLITCH else color,
			life = WAVE_TIME + 0.2,
			alpha0 = 0,
			spin = if i == 1 then 3 else -3,
		})
	end
	ModVfx.quad({
		texture = Tex.MOD_SCAN,
		cframe = CFrame.new(floorUnder(at)),
		from = 2,
		to = d,
		color = GLITCH,
		life = WAVE_TIME,
		alpha0 = 0.1,
	})
	-- The wave: a shimmer shell (seen where nothing hides it) and a ring of
	-- slabs in one model with one highlight, so the front shows through
	-- walls without the shell's fill covering the screen.
	local model = Instance.new("Model")
	model.Name = "ReconSpikeWave"
	local shell = Instance.new("Part")
	shell.Shape = Enum.PartType.Ball
	shell.Anchored = true
	shell.CanCollide = false
	shell.CanQuery = false
	shell.CanTouch = false
	shell.CastShadow = false
	shell.Material = Enum.Material.ForceField
	shell.Color = GLITCH
	shell.Size = Vector3.one * 2
	shell.CFrame = CFrame.new(at)
	shell.Parent = fxFolder()
	local slabs = {}
	local angles = {}
	for i = 1, WAVE_SLABS do
		local p = takePixel()
		p.Transparency = 1
		p.Parent = model
		table.insert(slabs, p)
		table.insert(angles, (i - 1) / WAVE_SLABS * math.pi * 2)
	end
	local h = Instance.new("Highlight")
	h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	h.FillColor = GLITCH
	h.FillTransparency = 0.4
	h.OutlineColor = GLITCH
	h.OutlineTransparency = 0.2
	h.Adornee = model
	h.Parent = model
	model.Parent = fxFolder()
	table.insert(waves, {
		at = at,
		radius = radius,
		color = color,
		born = os.clock(),
		model = model,
		shell = shell,
		slabs = slabs,
		angles = angles,
		highlight = h,
		nextStep = 0,
		passed = false,
	})
	-- A thump for those it reaches.
	local cam = Workspace.CurrentCamera
	if cam then
		local away = (cam.CFrame.Position - at).Magnitude
		if away < radius then
			CameraController.shake(0.4 * (1 - away / radius))
		end
	end
end

local function stepWaves(now: number)
	local cam = Workspace.CurrentCamera
	for i = #waves, 1, -1 do
		local w = waves[i]
		local t = now - w.born
		if t >= WAVE_TIME + WAVE_FADE then
			for _, p in w.slabs do
				freePixel(p)
			end
			w.model:Destroy()
			w.shell:Destroy()
			table.remove(waves, i)
			continue
		end
		local grow = math.min(t / WAVE_TIME, 1)
		local r = w.radius * (1 - (1 - grow) ^ 2)
		-- The screen tears as the front passes you (through walls too).
		if not w.passed and cam then
			local away = (cam.CFrame.Position - w.at).Magnitude
			if away <= w.radius and r >= away then
				w.passed = true
				screenTear(PASS_TEAR, 0.6)
			end
		end
		if now < w.nextStep then
			continue
		end
		-- Dropped frames: it only moves WAVE_FPS times a second, jittered.
		w.nextStep = now + 1 / WAVE_FPS
		local fade = if t > WAVE_TIME then (t - WAVE_TIME) / WAVE_FADE else 0
		local jitter =
			Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.5, 0.5), rng:NextNumber(-1, 1))
		w.shell.Size = Vector3.one * math.max(r * 2, 2)
		w.shell.CFrame = CFrame.new(w.at + jitter)
		w.shell.Color = if rng:NextNumber() < 0.75 then GLITCH else w.color
		w.shell.Transparency = fade
		w.highlight.OutlineColor = if rng:NextNumber() < 0.7 then GLITCH else w.color
		w.highlight.OutlineTransparency = 0.2 + 0.8 * fade
		w.highlight.FillTransparency = 0.4 + 0.6 * fade
		for j, p in w.slabs do
			-- Dropouts: a slab skips frames, more of them as it breaks up.
			if rng:NextNumber() < 0.2 + 0.7 * fade or r < 3 then
				p.Transparency = 1
				continue
			end
			local a = w.angles[j] + rng:NextNumber(-0.05, 0.05)
			local out = math.max(r + rng:NextNumber(-1.5, 1.5), 1)
			local pos = w.at
				+ Vector3.new(math.cos(a) * out, rng:NextNumber(-3, 3), math.sin(a) * out)
			p.Size = Vector3.new(
				rng:NextNumber(0.2, 0.5),
				rng:NextNumber(1.5, 8),
				rng:NextNumber(1, 5) * math.clamp(r / w.radius, 0.3, 1)
			)
			-- Lying along the circle (its length is Z).
			p.CFrame = CFrame.lookAt(pos, pos + Vector3.new(-math.sin(a), 0, math.cos(a)))
			p.Color = glitchColor(w.color)
			p.Transparency = rng:NextNumber(0, 0.3) + 0.7 * fade
		end
	end
end

-- Revealed enemies: torn outlines (and the caster's "+20%") ----------------------

type Mark = {
	highlight: Highlight,
	tag: BillboardGui?,
	label: TextLabel?,
	text: string,
	untilT: number,
	nextRoll: number,
}
local marks: { [Model]: Mark } = {}

local function anchorOf(model: Model): BasePart?
	for _, name in { "Head", "HumanoidRootPart" } do
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			return part
		end
	end
	return nil
end

local function makeTag(model: Model, text: string): (BillboardGui?, TextLabel?)
	local at = anchorOf(model)
	if not at then
		return nil, nil
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "ReconSpikeBonus"
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Size = UDim2.fromOffset(84, 28)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
	gui.Adornee = at
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold)
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = GLITCH
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0.3
	label.Parent = gui
	gui.Parent = fxFolder()
	return gui, label
end

local function onReveal(data: { [string]: any })
	local targets, duration = data.targets, data.duration
	if typeof(targets) ~= "table" or typeof(duration) ~= "number" then
		return
	end
	local untilT = os.clock() + math.clamp(duration, 0, 10)
	-- "+20%" for the caster at G3, while the bonus lasts.
	local bonusText: string? = nil
	local stats = if typeof(data.level) == "string" then Mods.stats("Recon", data.level) else nil
	local bonus = stats and stats.bonusDamage
	if data.caster == player and typeof(bonus) == "number" and bonus > 0 then
		bonusText = string.format("+%d%%", math.round(bonus * 100))
	end
	-- pairs, not ipairs: a model that isn't streamed in arrives as a hole.
	for _, target in pairs(targets :: { [any]: any }) do
		if typeof(target) ~= "Instance" or not (target :: Instance):IsA("Model") then
			continue
		end
		local model = target :: Model
		local mark = marks[model]
		if not mark then
			local h = Instance.new("Highlight")
			h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			h.FillColor = TeamColor.ENEMY
			h.OutlineColor = GLITCH
			h.FillTransparency = 0.5
			h.OutlineTransparency = 0
			h.Adornee = model
			h.Parent = fxFolder()
			mark = { highlight = h, text = "", untilT = untilT, nextRoll = 0 }
			marks[model] = mark
		end
		local m = mark :: Mark
		m.untilT = math.max(m.untilT, untilT)
		if bonusText and not m.tag then
			m.text = bonusText
			m.tag, m.label = makeTag(model, bonusText)
		end
	end
end

local SCRAMBLE = { "#", "%", "0", "?", "/", "_", "2" }

local function scrambled(text: string): string
	local i = rng:NextInteger(1, #text)
	return text:sub(1, i - 1) .. SCRAMBLE[rng:NextInteger(1, #SCRAMBLE)] .. text:sub(i + 1)
end

local function dropMark(model: Model, mark: Mark)
	mark.highlight:Destroy()
	local tag = mark.tag
	if tag then
		tag:Destroy()
	end
	marks[model] = nil
end

local function stepMarks(now: number)
	for model, mark in marks do
		if now >= mark.untilT or not model.Parent then
			dropMark(model, mark)
			continue
		end
		if now < mark.nextRoll then
			continue
		end
		mark.nextRoll = now + 1 / TEAR_HZ
		-- The outline tears between magenta and the enemy colour; the fill
		-- drops out now and then (the outline never does: they stay tracked).
		local r = rng:NextNumber()
		local h = mark.highlight
		h.OutlineColor = if r < 0.6 then GLITCH elseif r < 0.9 then TeamColor.ENEMY else WHITE
		h.FillColor = if rng:NextNumber() < 0.8 then TeamColor.ENEMY else GLITCH
		h.FillTransparency = if rng:NextNumber() < 0.15 then 0.9 else rng:NextNumber(0.4, 0.65)
		local tag, label = mark.tag, mark.label
		if tag and label then
			tag.StudsOffsetWorldSpace =
				Vector3.new(rng:NextNumber(-0.12, 0.12), 2.6 + rng:NextNumber(-0.08, 0.08), 0)
			label.Text = if rng:NextNumber() < 0.15 then scrambled(mark.text) else mark.text
			label.TextColor3 = if rng:NextNumber() < 0.85 then GLITCH else WHITE
		end
	end
end

-- Handler --------------------------------------------------------------------------

local handler: Types.Handler = {}

handler.onFx = function(kind: string, data: { [string]: any }): boolean
	if kind == "Revealed" then
		-- You were caught by a Ping Spike: tears on top of the usual warning.
		if data.style == "Spike" then
			ModAudio.play(S.spikeRevealed)
			screenTear(REVEALED_TEAR, 1)
		end
		return false
	elseif kind == "Reveal" then
		if data.style ~= "Spike" then
			return false
		end
		onReveal(data)
		return true
	elseif not isSpike(data) then
		return false
	elseif kind == "ReconStick" then
		onStick(data)
		return false -- the stick sound plays as usual
	elseif kind == "ReconPulse" then
		onSpike(data)
		return true
	end
	return false
end

handler.step = function(_dt: number)
	if #arms == 0 and #waves == 0 and next(marks) == nil and not (tearGui and tearGui.Enabled) then
		return
	end
	local now = os.clock()
	stepArms(now)
	stepWaves(now)
	stepMarks(now)
	stepTear(now)
end

return handler
