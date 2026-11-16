--!strict
-- The Flash on the blinded player's own screen (vault/01 Design/Abilities/
-- Flash.md → What a blinded player sees). Valorant's recipe in our colours
-- (Config/Mods FLASH_FEEL): it ramps in fast to a warm near-white (a hair
-- under full), holds, then clears from the edges inward. A glow sits on the
-- spot where it popped (projected every frame, so it stays on the flash as
-- you turn) and shrinks into it, turning the Flash's gold as the fill fades.
-- The game's sound is muffled while it lasts (an EQ on the Combat master
-- group) and a low thump plays.
--
-- Driven by the character's BlindedUntil / BlindStrength / BlindedAt /
-- BlindFrom attributes (written only by the server's StatusService.blind):
-- FlashFx.step() each frame from ModFxController.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local ModsConfig = require(ReplicatedStorage.Shared.Config.Mods)
local StatusEffects = require(ReplicatedStorage.Shared.Config.StatusEffects)
local Tex = require(ReplicatedStorage.Shared.Config.VfxTextures)

local ModAudio = require(script.Parent.ModAudio)

local FlashFx = {}

local FEEL = ModsConfig.FLASH_FEEL

local gui: ScreenGui? = nil
local fill: Frame? = nil
local core: ImageLabel? = nil
local eq: EqualizerSoundEffect? = nil

-- The current blind (os.clock() times): nil when the screen is clear.
type Shown = { start: number, untilAt: number, strength: number, from: Vector3? }
local shown: Shown? = nil
local lastStart = -math.huge

local function build(): ScreenGui
	local existing = gui
	if existing and existing.Parent then
		return existing
	end
	local made = Instance.new("ScreenGui")
	made.Name = "FlashBlind"
	made.IgnoreGuiInset = true
	made.ResetOnSpawn = false
	made.DisplayOrder = 60 -- over the HUD
	made.Enabled = false
	local f = Instance.new("Frame")
	f.Name = "Fill"
	f.Size = UDim2.fromScale(1, 1)
	f.BorderSizePixel = 0
	f.BackgroundColor3 = FEEL.peak
	f.BackgroundTransparency = 1
	f.Parent = made
	fill = f
	local c = Instance.new("ImageLabel")
	c.Name = "Core"
	c.AnchorPoint = Vector2.new(0.5, 0.5)
	c.BackgroundTransparency = 1
	c.Image = Tex.MOD_GLOW
	c.ImageColor3 = FEEL.peak
	c.ImageTransparency = 1
	c.SizeConstraint = Enum.SizeConstraint.RelativeYY
	c.Parent = made
	core = c
	made.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
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
-- starts (or keeps) it.
local function poll()
	local character = Players.LocalPlayer.Character
	if not character then
		return
	end
	local cfg = StatusEffects.blinded
	local untilAt = character:GetAttribute(cfg.attribute)
	local startedAt = character:GetAttribute(cfg.startAttribute)
	if typeof(untilAt) ~= "number" or typeof(startedAt) ~= "number" or startedAt == lastStart then
		return
	end
	local left = untilAt - Workspace:GetServerTimeNow()
	if left <= 0.05 then
		return
	end
	lastStart = startedAt
	local strength = character:GetAttribute(cfg.strengthAttribute)
	local from = character:GetAttribute(cfg.fromAttribute)
	local s = if typeof(strength) == "number" then math.clamp(strength, 0, 1) else 1
	local clock = os.clock()
	local current = shown
	if current and clock < current.untilAt then
		-- Already blind: extend it (never shorter, never weaker).
		current.untilAt = math.max(current.untilAt, clock + left)
		current.strength = math.max(current.strength, s)
		if typeof(from) == "Vector3" then
			current.from = from
		end
	else
		shown = {
			start = clock,
			untilAt = clock + left,
			strength = s,
			from = if typeof(from) == "Vector3" then from else nil,
		}
		ModAudio.play(ModAudio.SOUNDS.Flash.blinded)
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
	if clock >= current.untilAt or not Players.LocalPlayer.Character then
		screen.Enabled = false
		shown = nil
		if muffle then
			muffle.Enabled = false
		end
		return
	end
	screen.Enabled = true
	local total = current.untilAt - current.start
	local fade = math.max(total * FEEL.fadeShare, FEEL.minFade)
	local fadeAt = current.untilAt - fade
	local into = quint((clock - current.start) / FEEL.rampIn)
	local clearing = math.clamp((clock - fadeAt) / fade, 0, 1) -- 0 held, 1 clear
	-- The fill: full at the peak (by strength), clearing first and fastest.
	local peakAlpha = FEEL.peakAlpha + (1 - FEEL.peakAlpha) * (1 - current.strength) * 0.7
	local fillAlpha = 1 - (1 - peakAlpha) * into * (1 - quint(clearing * 1.6))
	local tint = FEEL.peak:Lerp(FEEL.tint, math.clamp(clearing * 1.4, 0, 1))
	local f = fill
	if f then
		f.BackgroundTransparency = fillAlpha
		f.BackgroundColor3 = tint
	end
	-- The core: on the flash's spot (or the middle), shrinking into it.
	local c = core
	if c then
		local cam = Workspace.CurrentCamera
		local spot = Vector2.new(0.5, 0.5)
		local from = current.from
		if cam and from then
			local p = cam:WorldToViewportPoint(from)
			local view = cam.ViewportSize
			if p.Z > 0 then
				spot = Vector2.new(
					math.clamp(p.X / view.X, -0.1, 1.1),
					math.clamp(p.Y / view.Y, -0.1, 1.1)
				)
			else
				-- Behind the camera (a glance): pinned to the nearest edge.
				spot = Vector2.new(if p.X / view.X < 0.5 then 1.05 else -0.05, 0.5)
			end
		end
		local size = FEEL.coreSize + (FEEL.coreEnd - FEEL.coreSize) * quint(clearing)
		c.Position = UDim2.fromScale(spot.X, spot.Y)
		c.Size = UDim2.fromScale(size, size)
		c.ImageColor3 = tint
		c.ImageTransparency = 1
			- into * (1 - clearing * clearing) * (0.35 + 0.65 * current.strength)
	end
	if muffle then
		local m = (1 - quint(clearing)) * current.strength * FEEL.muffle
		muffle.Enabled = m > 0.01
		muffle.HighGain = -30 * m
		muffle.MidGain = -14 * m
		muffle.LowGain = -4 * m
	end
end

return FlashFx
