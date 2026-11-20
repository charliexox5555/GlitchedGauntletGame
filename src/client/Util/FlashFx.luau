--!strict
-- The Flash (vault/01 Design/Abilities/Flash.md → What a blinded player sees,
-- v3 2026-11-17 from the owner's Valorant screenshot; Config/Mods FLASH_FEEL).
--
-- Your own screen, when you're blinded: the whole screen covered in a deep
-- cool wash (fully, at full strength: you can't see through it), light rays
-- fanning out from the spot the flash popped (pale and cool outside, warm
-- gold at the core, turning slowly), so you can tell where it came from. The
-- spot is fixed where it went off on your screen (it doesn't move as you turn);
-- if that was off screen the burst comes in from that edge. It pulses softly. A glance (the edge of your view) is the same, weaker and short.
-- It ramps in fast, holds, then clears: the rays shrink into the spot and
-- the wash fades. The game's sound is muffled and a low thump plays.
--
-- Everyone else's flashed players: a small burst of the same rays over the
-- face while they're blinded (you can see who you flashed), fading out as
-- their blind runs out.
--
-- Driven by the characters' BlindedUntil / BlindStrength / BlindedAt /
-- BlindFrom attributes (written only by the server's StatusService.blind):
-- FlashFx.step() each frame from ModFxController.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local ModsConfig = require(ReplicatedStorage.Shared.Config.Mods)
local StatusEffects = require(ReplicatedStorage.Shared.Config.StatusEffects)
local Tex = require(ReplicatedStorage.Shared.Config.VfxTextures)

local ModAudio = require(script.Parent.ModAudio)

local FlashFx = {}

local FEEL = ModsConfig.FLASH_FEEL
local CFG = StatusEffects.blinded

local gui: ScreenGui? = nil
local fill: Frame? = nil
local beams: ImageLabel? = nil
local streaks: ImageLabel? = nil
local halo: ImageLabel? = nil
local core: ImageLabel? = nil
local eq: EqualizerSoundEffect? = nil

-- The current blind (os.clock() times): nil when the screen is clear. `spot`
-- is where the burst sits on the screen, fixed when the blind starts (the
-- owner: it shouldn't move as you move around).
type Shown = { start: number, untilAt: number, strength: number, spot: Vector2 }
local shown: Shown? = nil
local lastStart = -math.huge

-- Head bursts on other flashed characters.
type Head = { gui: BillboardGui, image: ImageLabel, glow: ImageLabel }
local heads: { [Model]: Head } = {}

local function image(
	parent: Instance,
	name: string,
	texture: string,
	color: Color3,
	z: number
): ImageLabel
	local i = Instance.new("ImageLabel")
	i.Name = name
	i.AnchorPoint = Vector2.new(0.5, 0.5)
	i.BackgroundTransparency = 1
	i.Image = texture
	i.ImageColor3 = color
	i.ImageTransparency = 1
	i.SizeConstraint = Enum.SizeConstraint.RelativeYY
	i.ZIndex = z
	i.Parent = parent
	return i
end

local function build(): ScreenGui
	local existing = gui
	if existing and existing.Parent then
		return existing
	end
	local made = Instance.new("ScreenGui")
	made.Name = "FlashBlind"
	made.IgnoreGuiInset = true
	made.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	made.ResetOnSpawn = false
	made.DisplayOrder = 60 -- over the HUD
	made.Enabled = false
	local f = Instance.new("Frame")
	f.Name = "Fill"
	f.Size = UDim2.fromScale(1, 1)
	f.BorderSizePixel = 0
	f.BackgroundColor3 = FEEL.fill
	f.BackgroundTransparency = 1
	f.ZIndex = 1
	f.Parent = made
	fill = f
	-- Layers, back to front: the wash, wide soft beams, fine streaks, the
	-- halo, the hot core.
	beams = image(made, "Beams", Tex.FLASH_BEAMS, FEEL.beams, 2)
	streaks = image(made, "Streaks", Tex.FLASH_STREAKS, FEEL.streaks, 3)
	halo = image(made, "Halo", Tex.FLASH_HALO, FEEL.streaks, 4)
	core = image(made, "Core", Tex.MOD_GLOW, FEEL.core, 5)
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

-- Where the flash was on the screen when it went off (shares of the view,
-- 0..1 on screen). Off screen or behind: pushed out past the edge on its
-- side, so the burst comes in from there.
local function spotOf(from: Vector3?): Vector2
	local cam = Workspace.CurrentCamera
	if not from or not cam then
		return Vector2.new(0.5, 0.5)
	end
	local view = cam.ViewportSize
	local p = cam:WorldToViewportPoint(from)
	if p.Z > 0 then
		return Vector2.new(math.clamp(p.X / view.X, -0.2, 1.2), math.clamp(p.Y / view.Y, -0.2, 1.2))
	end
	local rel = cam.CFrame:PointToObjectSpace(from)
	local d = Vector2.new(rel.X, -rel.Y)
	if d.Magnitude < 1e-3 then
		return Vector2.new(0.5, 1.2)
	end
	return Vector2.new(0.5, 0.5) + d.Unit * 0.75
end

-- Reads the server's attributes on our character: a new or extended blind
-- starts (or keeps) it.
local function poll()
	local character = Players.LocalPlayer.Character
	if not character then
		return
	end
	local untilAt = StateValues.get(character, CFG.attribute)
	local startedAt = StateValues.get(character, CFG.startAttribute)
	if typeof(untilAt) ~= "number" or typeof(startedAt) ~= "number" or startedAt == lastStart then
		return
	end
	local left = untilAt - Workspace:GetServerTimeNow()
	if left <= 0.05 then
		return
	end
	lastStart = startedAt
	local strength = StateValues.get(character, CFG.strengthAttribute)
	local from = StateValues.get(character, CFG.fromAttribute)
	local s = if typeof(strength) == "number" then math.clamp(strength, 0, 1) else 1
	local clock = os.clock()
	local current = shown
	if current and clock < current.untilAt then
		-- Already blind: extend it (never shorter, never weaker); the burst
		-- stays where it is.
		current.untilAt = math.max(current.untilAt, clock + left)
		current.strength = math.max(current.strength, s)
	else
		shown = {
			start = clock,
			untilAt = clock + left,
			strength = s,
			spot = spotOf(if typeof(from) == "Vector3" then from else nil),
		}
		ModAudio.play(ModAudio.SOUNDS.Flash.blinded)
		ModAudio.play(ModAudio.SOUNDS.Flash.blindedShimmer)
	end
end

local function place(i: ImageLabel?, spot: Vector2, size: number, rot: number, alpha: number)
	if not i then
		return
	end
	i.Position = UDim2.fromScale(spot.X, spot.Y)
	i.Size = UDim2.fromScale(size, size)
	i.Rotation = rot
	i.ImageTransparency = 1 - math.clamp(alpha, 0, 1)
end

local function stepScreen(clock: number)
	local current = shown
	if not current then
		return
	end
	local screen = build()
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
	local t = clock - current.start
	local total = current.untilAt - current.start
	local fade = math.max(total * FEEL.fadeShare, FEEL.minFade)
	local fadeAt = current.untilAt - fade
	local into = quint(t / FEEL.rampIn)
	local clearing = math.clamp((clock - fadeAt) / fade, 0, 1) -- 0 held, 1 clear
	local s = current.strength
	local amount = into * (1 - quint(clearing)) * (0.35 + 0.65 * s)
	local f = fill
	if f then
		-- A full flash covers the screen completely; a glance only partly.
		local cover = if s >= 0.8 then 1 else s
		f.BackgroundTransparency = 1 - into * (1 - quint(clearing)) * cover
	end
	-- The burst: fixed where it went off, a soft pulse (the core breathes,
	-- the beams shimmer, the halo swells), the layers turning against each
	-- other; it pops in a little big and settles, and shrinks away as it clears.
	local P = FEEL.pulse
	local beat = math.sin(t * P.rate * 2 * math.pi)
	local shimmer = math.sin(t * P.rate * 1.7 * 2 * math.pi + 1.3)
	local settle = 1 + 0.18 * math.exp(-t / 0.12)
	local shrink = (1 - 0.7 * quint(clearing)) * settle
	local spot = current.spot
	place(beams, spot, FEEL.beamsSize * shrink, t * FEEL.spin, amount * (0.85 + P.beams * shimmer))
	place(
		streaks,
		spot,
		FEEL.streaksSize * shrink * (1 + P.streaks * beat),
		-t * FEEL.spin * 1.8,
		amount
	)
	place(halo, spot, FEEL.haloSize * shrink * (1 + P.halo * beat), 0, amount * 0.9)
	place(core, spot, FEEL.coreSize * shrink * (1 + P.core * beat), 0, amount)
	if muffle then
		local m = (1 - quint(clearing)) * s * FEEL.muffle
		muffle.Enabled = m > 0.01
		muffle.HighGain = -30 * m
		muffle.MidGain = -14 * m
		muffle.LowGain = -4 * m
	end
end

-- The burst over a flashed character's face (for everyone but them).
local function headFor(model: Model, headPart: BasePart): Head
	local existing = heads[model]
	if existing and existing.gui.Parent then
		return existing
	end
	local bb = Instance.new("BillboardGui")
	bb.Name = "FlashedBurst"
	bb.Adornee = headPart
	bb.Size = UDim2.fromScale(FEEL.headSize, FEEL.headSize)
	-- In front of the face, toward whoever is looking (camera space), so the
	-- head never hides it.
	bb.StudsOffset = Vector3.new(0, 0.1, 1.4)
	bb.LightInfluence = 0
	bb.AlwaysOnTop = false
	bb.MaxDistance = 250
	local rays = Instance.new("ImageLabel")
	rays.AnchorPoint = Vector2.new(0.5, 0.5)
	rays.Position = UDim2.fromScale(0.5, 0.5)
	rays.Size = UDim2.fromScale(1, 1)
	rays.BackgroundTransparency = 1
	rays.Image = Tex.FLASH_STREAKS
	rays.ImageColor3 = FEEL.headColor
	rays.Parent = bb
	local glow = Instance.new("ImageLabel")
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.Size = UDim2.fromScale(0.45, 0.45)
	glow.BackgroundTransparency = 1
	glow.Image = Tex.MOD_GLOW
	glow.ImageColor3 = Color3.new(1, 1, 1)
	glow.Parent = bb
	bb.Parent = headPart
	local h: Head = { gui = bb, image = rays, glow = glow }
	heads[model] = h
	return h
end

local function dropHead(model: Model)
	local h = heads[model]
	if h then
		heads[model] = nil
		h.gui:Destroy()
	end
end

local function considerHead(model: Model, serverNow: number, clock: number)
	local untilAt = StateValues.get(model, CFG.attribute)
	local startedAt = StateValues.get(model, CFG.startAttribute)
	local headPart = model:FindFirstChild("Head")
	if
		typeof(untilAt) ~= "number"
		or typeof(startedAt) ~= "number"
		or untilAt <= serverNow
		or not headPart
		or not headPart:IsA("BasePart")
	then
		dropHead(model)
		return
	end
	local h = headFor(model, headPart)
	local total = math.max(untilAt - startedAt, 0.1)
	local left = untilAt - serverNow
	local fadeOut = math.clamp(left / math.min(total * 0.4, 0.35), 0, 1)
	local fadeIn = math.clamp((serverNow - startedAt) / 0.06, 0, 1)
	local a = fadeIn * fadeOut
	local pulse = 0.94 + 0.06 * math.sin(clock * 2 * math.pi * FEEL.pulse.rate)
	h.gui.Size = UDim2.fromScale(FEEL.headSize * pulse, FEEL.headSize * pulse)
	h.image.Rotation = clock * 30
	h.image.ImageTransparency = 1 - a
	h.glow.ImageTransparency = 1 - a
end

local function stepHeads(clock: number)
	local serverNow = Workspace:GetServerTimeNow()
	local me = Players.LocalPlayer.Character
	local seen: { [Model]: boolean } = {}
	for _, p in Players:GetPlayers() do
		local c = p.Character
		if c and c ~= me then
			seen[c] = true
			considerHead(c, serverNow, clock)
		end
	end
	local dummies = Workspace:FindFirstChild("Dummies")
	if dummies then
		for _, m in dummies:GetChildren() do
			if m:IsA("Model") then
				seen[m] = true
				considerHead(m, serverNow, clock)
			end
		end
	end
	for model in heads do
		if not seen[model] then
			dropHead(model)
		end
	end
end

function FlashFx.step()
	poll()
	local clock = os.clock()
	stepScreen(clock)
	stepHeads(clock)
end

return FlashFx
