--!strict
-- The Flash's white-out on the blinded player's own screen (vault/01 Design/
-- Abilities/Flash.md → What a blinded player sees). Our stylised look, not a
-- photoreal glare: angled white plates close in from the edges in `CLOSE`
-- s (the centre plate last), hold while BlindedUntil runs, then break away
-- outward over `BREAK` s. Strength (0..1, how directly you looked) sets how
-- opaque the hold is. The game's sound is muffled while it lasts (an EQ on
-- the Combat master group, eased back as the plates go).
--
-- Driven by the character's BlindedUntil / BlindStrength / BlindedAt
-- attributes (written only by the server's StatusService.blind):
-- FlashFx.step() each frame from ModFxController.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local StatusEffects = require(ReplicatedStorage.Shared.Config.StatusEffects)

local ModAudio = require(script.Parent.ModAudio)

local FlashFx = {}

local CLOSE = 0.06 -- seconds the plates take to close in
local BREAK = 0.4 -- ... and to break away
local WHITE = Color3.fromHex("F7F9FF")

-- Each plate: where it rests (scale position of its centre), its size
-- (scale), its tilt (degrees), and the way it comes in / leaves.
type PlateSpec = { at: Vector2, size: Vector2, tilt: number, from: Vector2, order: number }
local PLATES: { PlateSpec } = {
	{
		at = Vector2.new(0.18, 0.2),
		size = Vector2.new(0.7, 0.62),
		tilt = -14,
		from = Vector2.new(-1, -1),
		order = 0,
	},
	{
		at = Vector2.new(0.84, 0.18),
		size = Vector2.new(0.66, 0.6),
		tilt = 11,
		from = Vector2.new(1, -1),
		order = 0,
	},
	{
		at = Vector2.new(0.12, 0.62),
		size = Vector2.new(0.6, 0.7),
		tilt = 8,
		from = Vector2.new(-1, 0.2),
		order = 0.1,
	},
	{
		at = Vector2.new(0.9, 0.66),
		size = Vector2.new(0.6, 0.72),
		tilt = -9,
		from = Vector2.new(1, 0.3),
		order = 0.1,
	},
	{
		at = Vector2.new(0.3, 0.9),
		size = Vector2.new(0.75, 0.5),
		tilt = 6,
		from = Vector2.new(-0.3, 1),
		order = 0.2,
	},
	{
		at = Vector2.new(0.74, 0.92),
		size = Vector2.new(0.7, 0.5),
		tilt = -12,
		from = Vector2.new(0.4, 1),
		order = 0.2,
	},
	{
		at = Vector2.new(0.5, 0.06),
		size = Vector2.new(0.6, 0.34),
		tilt = -3,
		from = Vector2.new(0, -1),
		order = 0.1,
	},
	{
		at = Vector2.new(0.52, 0.97),
		size = Vector2.new(0.6, 0.3),
		tilt = 3,
		from = Vector2.new(0, 1),
		order = 0.2,
	},
	-- The centre, last.
	{
		at = Vector2.new(0.5, 0.48),
		size = Vector2.new(0.62, 0.6),
		tilt = 4,
		from = Vector2.new(0, 0),
		order = 0.6,
	},
}

type Plate = { frame: Frame, spec: PlateSpec }

local gui: ScreenGui? = nil
-- The plates draw inside one CanvasGroup: its GroupTransparency is the hold's
-- see-through, so overlapping plates don't stack into patches.
local group: CanvasGroup? = nil
local plates: { Plate } = {}
local eq: EqualizerSoundEffect? = nil

-- The current blind (os.clock() times): nil when the screen is clear.
local shown: { closedAt: number, untilAt: number, strength: number }? = nil
local lastStart = -math.huge

local function build(): ScreenGui
	local existing = gui
	if existing and existing.Parent then
		return existing
	end
	local player = Players.LocalPlayer
	local made = Instance.new("ScreenGui")
	made.Name = "FlashBlind"
	made.IgnoreGuiInset = true
	made.ResetOnSpawn = false
	made.DisplayOrder = 60 -- over the HUD
	made.Enabled = false
	local canvas = Instance.new("CanvasGroup")
	canvas.Name = "Plates"
	canvas.Size = UDim2.fromScale(1, 1)
	canvas.BackgroundTransparency = 1
	canvas.Parent = made
	group = canvas
	table.clear(plates)
	for _, spec in PLATES do
		local frame = Instance.new("Frame")
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Size = UDim2.fromScale(spec.size.X, spec.size.Y)
		frame.Rotation = spec.tilt
		frame.BackgroundColor3 = WHITE
		frame.BorderSizePixel = 0
		frame.BackgroundTransparency = 1
		frame.Parent = canvas
		table.insert(plates, { frame = frame, spec = spec })
	end
	made.Parent = player:WaitForChild("PlayerGui")
	gui = made
	return made
end

local function equalizer(): EqualizerSoundEffect?
	local existing = eq
	if existing and existing.Parent then
		return existing
	end
	local master = SoundService:FindFirstChild("Combat")
	if not master or not master:IsA("SoundGroup") then
		return nil
	end
	local made = Instance.new("EqualizerSoundEffect")
	made.Name = "FlashMuffle"
	made.HighGain = 0
	made.MidGain = 0
	made.LowGain = 0
	made.Priority = 5
	made.Enabled = false
	made.Parent = master
	eq = made
	return made
end

local function quint(u: number): number
	return 1 - (1 - math.clamp(u, 0, 1)) ^ 5
end

-- Reads the server's attributes on our character: a new or extended blind
-- starts (or keeps) the plates.
local function poll()
	local character = Players.LocalPlayer.Character
	if not character then
		return
	end
	local cfg = StatusEffects.blinded
	local untilAt = character:GetAttribute(cfg.attribute)
	local startedAt = character:GetAttribute(cfg.startAttribute)
	local strength = character:GetAttribute(cfg.strengthAttribute)
	if typeof(untilAt) ~= "number" or typeof(startedAt) ~= "number" then
		return
	end
	local serverNow = Workspace:GetServerTimeNow()
	local left = untilAt - serverNow
	if left <= 0.05 then
		return
	end
	local s = if typeof(strength) == "number" then math.clamp(strength, 0, 1) else 1
	local clock = os.clock()
	local untilClock = clock + left
	local current = shown
	if startedAt ~= lastStart then
		lastStart = startedAt
		if current and clock < current.untilAt + BREAK then
			-- Already white: extend it (never shorter, never weaker).
			current.untilAt = math.max(current.untilAt, untilClock)
			current.strength = math.max(current.strength, s)
		else
			shown = { closedAt = clock + CLOSE, untilAt = untilClock, strength = s }
			ModAudio.play(ModAudio.SOUNDS.Flash.blinded)
		end
	end
end

function FlashFx.step()
	poll()
	local current = shown
	if not current then
		return
	end
	local screen = build()
	local clock = os.clock()
	local muffle = equalizer()
	-- Holding: the plates' opacity from the strength (a glance is see-through).
	local holdAlpha = 1 - (0.35 + 0.65 * current.strength)
	local over = clock >= current.untilAt + BREAK
	if over or not Players.LocalPlayer.Character then
		screen.Enabled = false
		shown = nil
		if muffle then
			muffle.Enabled = false
		end
		return
	end
	screen.Enabled = true
	local closing = current.closedAt - CLOSE
	local breaking = math.max(clock - current.untilAt, 0) / BREAK -- 0 until it breaks
	for _, p in plates do
		local spec = p.spec
		-- In: each plate on its own short delay (the centre last), all inside CLOSE.
		local delay = spec.order * CLOSE * 0.6
		local u = quint((clock - closing - delay) / math.max(CLOSE - delay, 0.01))
		local out = quint(breaking)
		local push = (1 - u) + out * 0.9
		local pos = spec.at + spec.from * push * 0.6
		p.frame.Position = UDim2.fromScale(pos.X, pos.Y)
		p.frame.Rotation = spec.tilt + out * spec.tilt * 0.8
		p.frame.BackgroundTransparency = if u <= 0 then 1 else math.max(1 - u, out)
	end
	local canvas = group
	if canvas then
		canvas.GroupTransparency = holdAlpha
	end
	if muffle then
		local m = (1 - quint(breaking)) * current.strength
		muffle.Enabled = m > 0.01
		muffle.HighGain = -30 * m
		muffle.MidGain = -14 * m
		muffle.LowGain = -4 * m
	end
end

return FlashFx
