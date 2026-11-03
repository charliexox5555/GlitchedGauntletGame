--!strict
-- Crash Recovery's look (Recall glitch path, vault/01 Design/Abilities/
-- Recall.md → Upgrades): the RecallCrash event (Services/ModRecall.rescue).
--
-- For everyone: the saved player pops in on the anchor at once (RecallFx.
-- crashArrive), and where they "died" a frozen, stuttering ghost of their
-- body is left behind (blocky Neon copies of the body parts in their team
-- colour, a magenta copy jittering beside it like a bad frame). It shatters
-- into pixels that streak back to the anchor along a beam.
-- For the saved player: the screen crashes. Torn bands and a freeze, a
-- corrupted blue "fatal error" flash, then rewind static and scanlines
-- running up the screen while the view settles.
--
-- Built in code (no new assets): Neon parts, a Beam, ScreenGui frames, the
-- Recall textures (Config/VfxTextures RECALL_*) and the Recall sounds
-- re-pitched (Config/ModSounds Recall).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.Mods)
local ModSounds = require(ReplicatedStorage.Shared.Config.ModSounds)
local VFX = require(ReplicatedStorage.Shared.Config.VfxTextures)

local CameraController = require(script.Parent.Parent.Parent.Controllers.CameraController)
local ModAudio = require(script.Parent.Parent.ModAudio)
local ModVfx = require(script.Parent.Parent.ModVfx)
local RecallFx = require(script.Parent.Parent.RecallFx)
local TeamColor = require(script.Parent.Parent.TeamColor)

local RecallCrash = {}

local S = ModSounds.Recall
local player = Players.LocalPlayer

local GLITCH = Config.COLORS.glitch
local WHITE = Color3.new(1, 1, 1)
local BLUE = Color3.fromHex("1B2FD6") -- the corrupted "fatal error" screen
local CYAN = Config.COLORS.ally
local MONO = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold)

-- The ghost (seconds from the event).
local GHOST_TIME = 0.32 -- frozen and stuttering where they "died"
local BURST_TIME = 0.12 -- then its pixels fly apart
local PULL_TIME = 0.38 -- and get pulled back to the anchor
local PULL_SPREAD = 0.14 -- each pixel leaves up to this much later
local PIXELS_PER_PART = 5
local STREAK_LIFE = 0.5
local ARRIVE_LIFT = 2.5 -- studs above the anchor's floor the pixels fly to

-- Our screen (seconds from the event).
local TEAR_TIME = 0.18
local BLUE_FROM, BLUE_TO = 0.1, 0.34
local SCREEN_TIME = 1
local TEARS = 9
local NOISE = 42
local SCANS = 5
local FLICKER = 1 / 30 -- the frozen frame re-tears this often

local function folder(): Instance
	local f = Workspace:FindFirstChild("RecallCrashFx")
	if f then
		return f
	end
	local made = Instance.new("Folder")
	made.Name = "RecallCrashFx"
	made.Parent = Workspace
	return made
end

local function block(size: Vector3, color: Color3, transparency: number): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Size = size
	p.Color = color
	p.Transparency = transparency
	return p
end

local function ease(t: number): number
	return 1 - (1 - t) * (1 - t)
end

-- The ghost --------------------------------------------------------------------------

type Box = { size: Vector3, rel: CFrame }
type GhostPart = { box: Box, main: Part, split: Part }
type Ghost = {
	parts: { GhostPart },
	from: CFrame,
	to: Vector3,
	color: Color3,
	born: number,
	nextFlicker: number,
}
type Pixel = {
	part: Part,
	start: Vector3,
	out: Vector3,
	to: Vector3,
	size: number,
	leave: number, -- seconds after the burst it starts toward the anchor
	born: number,
}
type Streak = { holder: Part, beam: Beam, born: number }

local ghosts: { Ghost } = {}
local pixels: { Pixel } = {}
local streaks: { Streak } = {}

-- Plain blocks for a body we can't see (not streamed in).
local SILHOUETTE: { Box } = {
	{ size = Vector3.new(2, 2, 1), rel = CFrame.new(0, 0, 0) },
	{ size = Vector3.new(1.2, 1.2, 1.2), rel = CFrame.new(0, 1.65, 0) },
	{ size = Vector3.new(0.9, 2, 0.9), rel = CFrame.new(-1.5, 0, 0) },
	{ size = Vector3.new(0.9, 2, 0.9), rel = CFrame.new(1.5, 0, 0) },
	{ size = Vector3.new(0.9, 2, 0.9), rel = CFrame.new(-0.5, -2, 0) },
	{ size = Vector3.new(0.9, 2, 0.9), rel = CFrame.new(0.5, -2, 0) },
}

-- The caster's body parts as boxes around the root (their pose now: the
-- body has already moved, but the pose relative to the root is the same).
local function bodyBoxes(caster: Player?): { Box }
	local character = caster and caster.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local boxes: { Box } = {}
	if character and root and root:IsA("BasePart") then
		for _, child in character:GetChildren() do
			if child:IsA("BasePart") and child ~= root and child.Transparency < 0.9 then
				table.insert(
					boxes,
					{ size = child.Size, rel = root.CFrame:ToObjectSpace(child.CFrame) }
				)
			end
		end
	end
	return if #boxes > 0 then boxes else SILHOUETTE
end

local function ghost(from: CFrame, to: Vector3, color: Color3, caster: Player?)
	local f = folder()
	local g: Ghost = {
		parts = {},
		from = from,
		to = to,
		color = color,
		born = os.clock(),
		nextFlicker = 0,
	}
	for _, box in bodyBoxes(caster) do
		local main = block(box.size, color, 0.3)
		main.CFrame = from * box.rel
		main.Parent = f
		local split = block(box.size * 1.02, GLITCH, 0.55)
		split.CFrame = from * box.rel
		split.Parent = f
		table.insert(g.parts, { box = box, main = main, split = split })
	end
	table.insert(ghosts, g)
end

-- A bad frame: parts slip sideways, flicker and drop out, the magenta copy
-- tears away from the body.
local function stutter(g: Ghost)
	local right = g.from.RightVector
	for _, gp in g.parts do
		local base = g.from * gp.box.rel
		local slip = if math.random() < 0.4 then (math.random() - 0.5) * 0.35 else 0
		gp.main.CFrame = base + right * slip
		gp.main.Transparency = if math.random() < 0.12 then 1 else 0.2 + math.random() * 0.35
		gp.split.CFrame = base + right * ((math.random() - 0.5) * 0.9)
		gp.split.Transparency = if math.random() < 0.3 then 1 else 0.4 + math.random() * 0.4
	end
end

local function streak(from: Vector3, to: Vector3, color: Color3)
	local holder = block(Vector3.one * 0.1, color, 1)
	holder.CFrame = CFrame.identity
	local a0 = Instance.new("Attachment")
	a0.Position = from
	a0.Parent = holder
	local a1 = Instance.new("Attachment")
	a1.Position = to
	a1.Parent = holder
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Color = ColorSequence.new(color, GLITCH)
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.FaceCamera = true
	beam.Segments = 1
	beam.Width0 = 1.4
	beam.Width1 = 0.5
	beam.Texture = VFX.RECALL_SHIMMER_2x2
	beam.TextureMode = Enum.TextureMode.Stretch
	beam.TextureSpeed = 4
	beam.Parent = holder
	holder.Parent = folder()
	table.insert(streaks, { holder = holder, beam = beam, born = os.clock() })
end

-- The ghost comes apart: pixels burst out of every part, then fly home.
local function shatter(g: Ghost)
	local now = os.clock()
	local home = g.to + Vector3.new(0, ARRIVE_LIFT, 0)
	local f = folder()
	for _, gp in g.parts do
		local cf = g.from * gp.box.rel
		for _ = 1, PIXELS_PER_PART do
			local half = gp.box.size / 2
			local at = cf
				* Vector3.new(
					(math.random() * 2 - 1) * half.X,
					(math.random() * 2 - 1) * half.Y,
					(math.random() * 2 - 1) * half.Z
				)
			local size = 0.25 + math.random() * 0.25
			local roll = math.random()
			local color = if roll < 0.45 then g.color elseif roll < 0.85 then GLITCH else WHITE
			local p = block(Vector3.one * size, color, 0)
			p.CFrame = CFrame.new(at)
			p.Parent = f
			local outward = (at - g.from.Position) + Vector3.new(0, 0.5, 0)
			table.insert(pixels, {
				part = p,
				start = at,
				out = (if outward.Magnitude > 1e-3 then outward.Unit else Vector3.yAxis)
					* (1.2 + math.random() * 1.8),
				to = home
					+ Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5),
				size = size,
				leave = math.random() * PULL_SPREAD,
				born = now,
			})
		end
		gp.main:Destroy()
		gp.split:Destroy()
	end
	table.clear(g.parts)
	ModAudio.play(S.destroyedBreak, g.from.Position, 1.4)
	ModVfx.burst(g.from.Position, GLITCH, 18, "Sparkle")
	streak(g.from.Position, home, g.color)
end

local function stepWorld()
	local now = os.clock()
	for i = #ghosts, 1, -1 do
		local g = ghosts[i]
		if now - g.born >= GHOST_TIME then
			shatter(g)
			table.remove(ghosts, i)
		elseif now >= g.nextFlicker then
			g.nextFlicker = now + FLICKER
			stutter(g)
		end
	end
	for i = #pixels, 1, -1 do
		local px = pixels[i]
		local t = now - px.born
		local pull = (t - BURST_TIME - px.leave) / PULL_TIME
		if pull >= 1 then
			px.part:Destroy()
			table.remove(pixels, i)
			continue
		end
		local burst = px.start + px.out * ease(math.min(t / BURST_TIME, 1))
		local k = math.max(pull, 0)
		-- Slow to leave, fast to land (pulled in), shrinking as it goes.
		px.part.CFrame = CFrame.new(burst:Lerp(px.to, k * k))
		px.part.Size = Vector3.one * px.size * (1 - 0.7 * k)
		px.part.Transparency = if math.random() < 0.08 then 1 else 0.6 * k
	end
	for i = #streaks, 1, -1 do
		local s = streaks[i]
		local k = (now - s.born) / STREAK_LIFE
		if k >= 1 then
			s.holder:Destroy()
			table.remove(streaks, i)
		else
			local alpha = 0.15 + 0.85 * k
			s.beam.Transparency = NumberSequence.new(alpha)
			s.beam.Width0 = 1.4 * (1 - k)
		end
	end
end

-- Our screen -------------------------------------------------------------------------

type Screen = {
	gui: ScreenGui,
	dim: Frame,
	tears: { Frame },
	blue: Frame,
	lines: { TextLabel },
	noise: { Frame },
	scans: { Frame },
	rewind: TextLabel,
	warp: ImageLabel,
}
local screen: Screen? = nil
local crashAt = -math.huge
local nextTear = 0

local ERROR_LINES = {
	":(",
	"FATAL EXCEPTION 0x0000DEAD",
	"PLAYER STOPPED RESPONDING",
	"RESTORING LAST CHECKPOINT...",
}
local JUNK = { "#", "%", "&", "@", "$", "!", "?", "/", "\\", "|", "<", ">", "0", "1", "_" }

local function frame(parent: Instance, color: Color3, z: number): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = color
	f.BackgroundTransparency = 1
	f.ZIndex = z
	f.Parent = parent
	return f
end

local function label(parent: Instance, size: number, z: number): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.FontFace = MONO
	l.TextSize = size
	l.TextColor3 = WHITE
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextTransparency = 1
	l.ZIndex = z
	l.Parent = parent
	return l
end

local function build(): Screen
	local made = screen
	if made and made.gui.Parent then
		return made
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "RecallCrashScreen"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6 -- over the HUD
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local dim = frame(gui, Color3.new(0, 0, 0), 1)
	dim.Size = UDim2.fromScale(1, 1)
	local blue = frame(gui, BLUE, 3)
	blue.Size = UDim2.fromScale(1, 1)
	local lines: { TextLabel } = {}
	for i = 1, #ERROR_LINES do
		local l = label(blue, if i == 1 then 96 else 26, 4)
		l.Position = UDim2.new(0.12, 0, 0.2, if i == 1 then 0 else 90 + i * 40)
		l.Size = UDim2.new(0.8, 0, 0, if i == 1 then 100 else 34)
		lines[i] = l
	end
	local tears: { Frame } = {}
	for i = 1, TEARS do
		tears[i] = frame(gui, GLITCH, 2)
	end
	local noise: { Frame } = {}
	for i = 1, NOISE do
		noise[i] = frame(gui, WHITE, 5)
	end
	local scans: { Frame } = {}
	for i = 1, SCANS do
		local s = frame(gui, WHITE, 5)
		s.Size = UDim2.new(1, 0, 0, 3)
		scans[i] = s
	end
	local warp = Instance.new("ImageLabel")
	warp.Name = "Warp"
	warp.AnchorPoint = Vector2.new(0.5, 0.5)
	warp.Position = UDim2.fromScale(0.5, 0.5)
	warp.Size = UDim2.fromScale(1.2, 1.2)
	warp.BackgroundTransparency = 1
	warp.Image = VFX.RECALL_WARP
	warp.ImageColor3 = GLITCH
	warp.ImageTransparency = 1
	warp.ZIndex = 2
	warp.Parent = gui
	local rewind = label(gui, 30, 6)
	rewind.Position = UDim2.new(0, 48, 0, 40)
	rewind.Size = UDim2.fromOffset(320, 40)
	rewind.Text = "◀◀ REWIND"
	local stroke = Instance.new("UIStroke")
	stroke.Color = GLITCH
	stroke.Thickness = 2
	stroke.Parent = rewind
	made = {
		gui = gui,
		dim = dim,
		tears = tears,
		blue = blue,
		lines = lines,
		noise = noise,
		scans = scans,
		rewind = rewind,
		warp = warp,
	}
	screen = made
	return made
end

local function corrupt(text: string, share: number): string
	local out: { string } = {}
	for i = 1, #text do
		local c = string.sub(text, i, i)
		out[i] = if c ~= " " and math.random() < share then JUNK[math.random(#JUNK)] else c
	end
	return table.concat(out)
end

-- Torn bands: slices of the frozen frame slipped sideways in glitch colours.
local function tear(sc: Screen, strength: number)
	for i, t in sc.tears do
		local on = math.random() < strength
		t.BackgroundTransparency = if on then 0.35 + math.random() * 0.4 else 1
		t.BackgroundColor3 = if i % 3 == 0 then CYAN elseif i % 3 == 1 then GLITCH else WHITE
		t.Position = UDim2.new(0, (math.random() - 0.5) * 120, math.random(), 0)
		t.Size = UDim2.new(0.4 + math.random() * 0.8, 0, 0.01 + math.random() * 0.06, 0)
	end
end

-- Dead pixels scattered over the screen (`density` 0..1 of them lit).
local function scatter(sc: Screen, density: number)
	for i, n in sc.noise do
		local on = math.random() < density
		n.BackgroundTransparency = if on then 0.1 + math.random() * 0.5 else 1
		n.BackgroundColor3 = if i % 4 == 0 then GLITCH elseif i % 4 == 1 then CYAN else WHITE
		local px = 6 + math.random(0, 3) * 6
		n.Size = UDim2.fromOffset(px, px)
		n.Position = UDim2.fromScale(math.random(), math.random())
	end
end

local function hideScreen(sc: Screen)
	sc.gui.Enabled = false
end

local function stepScreen()
	local sc = screen
	if not sc or not sc.gui.Enabled then
		return
	end
	local now = os.clock()
	local t = now - crashAt
	if t >= SCREEN_TIME then
		hideScreen(sc)
		return
	end
	local flicker = now >= nextTear
	if flicker then
		nextTear = now + FLICKER
	end
	-- The freeze: dark, torn, re-torn every few frames.
	local frozen = t < TEAR_TIME
	sc.dim.BackgroundTransparency = if frozen
		then 0.45
		else 0.45 + 0.55 * math.clamp((t - TEAR_TIME) / 0.5, 0, 1)
	if flicker then
		tear(sc, if frozen then 0.85 else math.max(0.5 - t, 0))
		scatter(sc, if frozen then 0.5 else math.max(0.6 - t * 0.6, 0))
	end
	-- The fatal-error flash, flickering and corrupting.
	local blueOn = t >= BLUE_FROM and t < BLUE_TO
	local blueAlpha = 1
	if t >= BLUE_TO then
		blueAlpha = 0.08 + 0.92 * math.clamp((t - BLUE_TO) / 0.12, 0, 1)
	elseif blueOn then
		blueAlpha = if flicker and math.random() < 0.25 then 0.5 else 0.08
	end
	sc.blue.BackgroundTransparency = blueAlpha
	for i, l in sc.lines do
		l.TextTransparency = blueAlpha
		if flicker and blueAlpha < 1 then
			l.Text = corrupt(ERROR_LINES[i], if blueOn then 0.12 else 0.4)
		end
	end
	-- The rewind: static and scanlines running up as the view settles.
	local rewinding = t >= BLUE_FROM
	local r = if rewinding then (t - BLUE_FROM) / (SCREEN_TIME - BLUE_FROM) else 0
	for i, s in sc.scans do
		local y = 1 - ((t * 2.6 + i / SCANS) % 1)
		s.Position = UDim2.fromScale(0, y)
		s.BackgroundColor3 = if i % 2 == 0 then GLITCH else WHITE
		s.BackgroundTransparency = if rewinding then 0.35 + 0.65 * r else 1
	end
	sc.warp.ImageTransparency = if rewinding then 0.35 + 0.65 * r else 0.6
	local blink = math.floor(t * 8) % 2 == 0
	sc.rewind.TextTransparency = if rewinding and blink then 0.6 * r else 1
	local rewindStroke = sc.rewind:FindFirstChildOfClass("UIStroke")
	if rewindStroke then
		rewindStroke.Transparency = sc.rewind.TextTransparency
	end
end

local function crashScreen()
	local sc = build()
	crashAt = os.clock()
	nextTear = 0
	sc.gui.Enabled = true
	ModAudio.play(S.outOfRange, nil, 0.8) -- a burst of static
	ModAudio.play(S.destroyed, nil, 0.7) -- the electrical crunch of the crash
	CameraController.shake(0.6)
	CameraController.rollKick(5, 0.35)
	stepScreen()
end

-- Events --------------------------------------------------------------------------------

function RecallCrash.play(data: { [string]: any })
	local from, at = data.from, data.at
	if typeof(from) ~= "CFrame" or typeof(at) ~= "Vector3" then
		return
	end
	local caster = if typeof(data.caster) == "Instance" and data.caster:IsA("Player")
		then data.caster
		else nil
	local color = if caster == player
		then TeamColor.ALLY
		else TeamColor.forTeam(if typeof(data.team) == "number" then data.team else nil)
	ModAudio.play(S.destroyed, from.Position, 0.85)
	ghost(from, at, color, caster)
	RecallFx.crashArrive(at, color)
	if caster == player then
		crashScreen()
	end
end

-- The anchor breaking under a rescue (ObjectGone "Crashed"): magenta shards.
function RecallCrash.anchorGone(at: Vector3)
	ModAudio.play(S.destroyedBreak, at, 1.15)
	ModVfx.burst(at, GLITCH, 22, "Sparkle")
end

function RecallCrash.step()
	stepWorld()
	stepScreen()
end

return RecallCrash
