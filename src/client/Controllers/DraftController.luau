--!strict
-- The draft screen, UI v1 (vault/02 Art/UI Design.md, Figma "Draft" screens):
-- 3 gun cards on top, then one column per key (Q / E / T) like Gauntlet:
-- Glitched (vault/01 Design/Match Flow.md). An empty slot's column shows a new
-- ability for it; a filled slot's column shows that ability's upgrade cards
-- (Path A or B, stacked; compact when a glitch card makes three), or MAXED.
-- The server dealt these cards and checks every pick; this only shows them and
-- asks. The top bar (timer, score) is MatchHudController's, drawn above this.
-- Built at 1920 x 1080 and scaled by Util/Ui.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local MatchConfig = require(ReplicatedStorage.Shared.Config.Match)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local ModsConfig = require(ReplicatedStorage.Shared.Config.Mods)
local Mods = require(ReplicatedStorage.Shared.Mods)
local Net = require(ReplicatedStorage.Shared.Net)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)
local CoreUi = require(ReplicatedStorage.Shared.CoreUi)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

local CameraController = require(script.Parent.CameraController)
local Ui = require(script.Parent.Parent.Util.Ui)
local UiSound = require(script.Parent.Parent.Util.UiSound)

local DraftController = {}

local player = Players.LocalPlayer
local C = Theme.COLORS
local make = Ui.make

local KEYS = { "Q", "E", "T" }
local COL_W, COL_GAP, TOP = 380, 30, 446
local COL_H = 540
local LIFT = 6 -- design px a card rises on hover
local REVEAL_FROM = 48 -- design px below its place a card starts when the draft opens
local REVEAL_STEP = 0.05 -- seconds between cards (capped so the whole row takes 0.4 s)
local URGENT = 5 -- seconds left when the hint names your default pick
local GUN_KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three }
local SLOT_KEYS = { [Enum.KeyCode.Q] = 1, [Enum.KeyCode.E] = 2, [Enum.KeyCode.T] = 3 }
local GUN_W, GUN_GAP, GUN_Y = 300, 24, 190

-- Upgrade numbers worth showing on a card ("PEAK  14 → 21 STUDS"), in order.
local STATS: { { key: string, label: string, unit: string } } = {
	{ key = "charges", label = "CHARGES", unit = "" },
	{ key = "peak", label = "PEAK", unit = " STUDS" },
	{ key = "distance", label = "DISTANCE", unit = " STUDS" },
	{ key = "maxLength", label = "LENGTH", unit = " STUDS" },
	{ key = "range", label = "RANGE", unit = " STUDS" },
	{ key = "radius", label = "RADIUS", unit = " STUDS" },
	{ key = "pulses", label = "PULSES", unit = "" },
	{ key = "freeze", label = "FREEZE", unit = " S" },
	{ key = "duration", label = "DURATION", unit = " S" },
	{ key = "cooldown", label = "COOLDOWN", unit = " S" },
}

type Card = {
	button: ImageButton,
	line: UIStroke,
	glow: ImageLabel,
	id: string,
	rest: Color3,
	restLine: Color3,
	glowColor: Color3,
	slot: number, -- 0 for guns
	home: UDim2?, -- where it rests (set by hookCard)
	pick: (() -> ())?, -- click it (set by hookCard; the keyboard uses it too)
}

local backdrop: TextButton? = nil
local canvas: Frame? = nil
local lockButton: ImageButton? = nil
local lockLabel: TextLabel? = nil
local lockIcon: ImageLabel? = nil
local lockHint: TextLabel? = nil
local gunCards: { Card } = {}
local abilityCards: { Card } = {}
local offer: MatchState.DraftOffer? = nil
local selectedGun: string? = nil
local selectedAbility: string? = nil
local isOpen = false
local lockPulse: Tween? = nil
local locked = false
local revealToken = 0
local openToken = 0
local shownHint = ""

-- Opens with a quick fade of the backdrop; closes by fading it and sinking
-- the cards, then hides (the cards come in on their own, see `reveal`).
local function setOpen(value: boolean)
	if isOpen == value then
		return
	end
	isOpen = value
	openToken += 1
	local token = openToken
	CameraController.setCursorVisible(value)
	-- Roblox's chat steps aside while the draft fills the screen (it sits at
	-- the left middle in a match, over the first column on smaller screens).
	CoreUi.menuMode(value)
	local back = backdrop
	if not back then
		return
	end
	back.Modal = value -- frees the mouse in first person
	local content = canvas and canvas:FindFirstChild("Content") :: Frame?
	if value then
		back.Visible = true
		back.BackgroundTransparency = 1
		Ui.tween(back, Theme.MOTION.enter, { BackgroundTransparency = 0 })
		UiSound.play("Open")
	else
		UiSound.play("Close")
		Ui.tween(
			back,
			Theme.MOTION.exit,
			{ BackgroundTransparency = 1 },
			Enum.EasingStyle.Quint,
			Enum.EasingDirection.In
		)
		if content then
			Ui.tween(
				content,
				Theme.MOTION.exit,
				{ Position = UDim2.new(0.5, 0, 0.5, 40) },
				Enum.EasingStyle.Quint,
				Enum.EasingDirection.In
			)
		end
		task.delay(Theme.MOTION.exit + 0.02, function()
			if token == openToken then
				back.Visible = false
			end
		end)
	end
end

local function nothingToPick(o: MatchState.DraftOffer): boolean
	return #o.abilities == 0 and #(o.upgrades or {}) == 0
end

local function canLock(): boolean
	local o = offer
	if not o then
		return false
	end
	return selectedGun ~= nil and (selectedAbility ~= nil or nothingToPick(o))
end

-- A card's text: the level's note, without its "Path name: " lead on an
-- upgrade card (the card's title already names the path).
local function cardNote(id: string, level: string): string
	local stats = Mods.stats(id, level)
	local note: string = if stats then stats.note or "" else ""
	local def = Mods.def(id)
	local pathName = if def then (def.paths :: any)[string.sub(level, 1, 1)] else nil
	if pathName and string.sub(note, 1, #pathName + 1) == pathName .. ":" then
		local rest = string.gsub(string.sub(note, #pathName + 2), "^%s+", "")
		return string.upper(string.sub(rest, 1, 1)) .. string.sub(rest, 2)
	end
	return note
end

local function levelNumber(level: string): number
	if level == "" then
		return 0
	end
	return tonumber(string.sub(level, 2, 2)) or 1
end

local function number(v: number): string
	return if v == math.floor(v) then tostring(v) else string.format("%.1f", v)
end

-- The first number that changes from `from` to `to` ("PEAK  14 → 21 STUDS").
local function statChange(id: string, from: string, to: string): string
	local a, b = Mods.stats(id, from), Mods.stats(id, to)
	if not a or not b then
		return ""
	end
	for _, s in STATS do
		local old, new = (a :: any)[s.key], (b :: any)[s.key]
		if typeof(new) == "number" and new ~= old then
			if s.key == "cooldown" and (typeof(old) ~= "number" or old == 0) then
				return string.format("RECHARGES EVERY %s S", number(new))
			end
			if typeof(old) == "number" then
				return string.format("%s  %s → %s%s", s.label, number(old), number(new), s.unit)
			end
		end
	end
	return ""
end

local function chargesText(id: string): string
	local stats = Mods.stats(id, "L1")
	if not stats then
		return ""
	end
	local charges = (stats :: any).charges or 1
	local cooldown = (stats :: any).cooldown or 0
	if cooldown > 0 then
		return string.format(
			"%d CHARGE%s  ·  %s S COOLDOWN",
			charges,
			if charges == 1 then "" else "S",
			number(cooldown)
		)
	end
	return string.format("%d PER ROUND", charges)
end

-- A card's short name for the hint ("Recon", "Stim · Quick Stims").
local function cardName(key: string): string
	local id, level = string.match(key, "^(%w+):(%w+)$")
	local def = Mods.def(id or key)
	if not def then
		return key
	end
	local pathName = if level then (def.paths :: any)[string.sub(level, 1, 1)] else nil
	return if pathName then def.name .. " · " .. pathName else def.name
end

local function hintText(): (string, Color3)
	local o = offer
	if not o then
		return "", C.textSecondary
	end
	if locked then
		return "Locked in. Waiting for the other players.", C.ready
	end
	if canLock() then
		return "Ready: press Enter or LOCK IN.", C.textSecondary
	end
	local left = MatchState.timeLeft()
	if left <= URGENT and left > 0 then
		-- What the server gives you if the clock runs out (DraftService.close).
		local gun = selectedGun or o.guns[1]
		local config = gun and Weapons.get(gun)
		local first = selectedAbility
			or o.abilities[1]
			or (o.upgrades and o.upgrades[1] and o.upgrades[1].key)
		local parts = { if config then config.displayName else gun or "" }
		if first then
			table.insert(parts, cardName(first))
		end
		return string.format(
			"%ds left. You'll get: %s",
			math.ceil(left),
			table.concat(parts, " + ")
		),
			C.gold
	end
	if not selectedGun then
		return "Pick a gun (1, 2, 3) and one card (Q, E, T).", C.textSecondary
	end
	if not nothingToPick(o) then
		return "Now pick one card: a new ability or an upgrade (Q, E, T).", C.textSecondary
	end
	return "", C.textSecondary
end

local function updateHint()
	local label = lockHint
	if not label then
		return
	end
	local text, color = hintText()
	if text ~= shownHint then
		shownHint = text
		label.Text = text
		label.TextColor3 = color
	end
end

local function setLockReady(ready: boolean)
	local button = lockButton
	if not button then
		return
	end
	local pulse = button:FindFirstChild("Pulse") :: UIScale?
	if ready and not lockPulse and pulse then
		-- A slow breathe while it's ready, so the eye finds it.
		local tween = TweenService:Create(
			pulse,
			TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Scale = 1.04 }
		)
		tween:Play()
		lockPulse = tween
	elseif not ready and lockPulse then
		lockPulse:Cancel()
		lockPulse = nil
		if pulse then
			pulse.Scale = 1
		end
	end
end

local function refreshSelection()
	for _, list in { gunCards, abilityCards } do
		for _, c in list do
			local on = c.id == selectedGun or c.id == selectedAbility
			c.line.Color = if on then C.white else c.restLine
			c.line.Transparency = 0
			c.glow.Visible = on and c.button.Visible
		end
	end
	local ready = canLock() and not locked
	if lockButton and lockLabel and lockIcon then
		lockButton.BackgroundColor3 = if locked then C.ready elseif ready then C.gold else C.raised
		lockLabel.TextColor3 = if ready or locked then C.onAccent else C.textDim
		lockLabel.Text = if locked then "LOCKED" else "LOCK IN"
		lockIcon.ImageColor3 = lockLabel.TextColor3
	end
	setLockReady(ready)
	updateHint()
end

-- A quick press pop through a UIScale.
local function popScale(scale: UIScale, peak: number)
	scale.Scale = 1
	Ui.tween(scale, 0.07, { Scale = peak }).Completed:Once(function(state)
		if state == Enum.PlaybackState.Completed then
			Ui.tween(scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
		end
	end)
end

-- A card shell: the cut shape, its outline and a selection glow behind it.
local function shell(
	parent: Instance,
	name: string,
	pos: UDim2,
	size: Vector2,
	corner: number,
	lineColor: Color3,
	glowColor: Color3?
): (ImageButton, UIStroke, ImageLabel)
	local glow = Ui.cut(parent, {
		Name = name .. "Glow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = pos + UDim2.fromOffset(size.X / 2, size.Y / 2),
		Size = UDim2.fromOffset(size.X + 16, size.Y + 16),
		Visible = false,
	}, { radius = Ui.radius(corner) + 8, color = glowColor or C.white, transparency = 0.86 })
	local button = Ui.cut(parent, {
		Name = name,
		-- Centre-anchored, so hover lifts and press pops grow from the middle.
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = pos + UDim2.fromOffset(size.X / 2, size.Y / 2),
		Size = UDim2.fromOffset(size.X, size.Y),
		ClipsDescendants = false,
	}, {
		corner = corner,
		color = C.card,
		transparency = 0.06,
		line = lineColor,
		className = "ImageButton",
	})
	local line = button:FindFirstChild("Line")
	assert(line and line:IsA("UIStroke"), "Ui.cut draws a Line when given a line colour")
	return button, line, glow
end

-- Hover lifts the card (and its glow) a little with a soft tick; a click or
-- its key pops it and picks it.
local function hookCard(card: Card, onPick: () -> ())
	local button, glow = card.button, card.glow
	local home, glowHome = button.Position, glow.Position
	card.home = home
	local pop = make("UIScale", { Name = "Pop" }, button)
	local up = UDim2.fromOffset(0, -LIFT)
	button.MouseEnter:Connect(function()
		if not isOpen then
			return
		end
		button.BackgroundColor3 = C.hover
		Ui.tween(button, Theme.MOTION.select, { Position = home + up })
		Ui.tween(glow, Theme.MOTION.select, { Position = glowHome + up })
		UiSound.play("Hover")
	end)
	button.MouseLeave:Connect(function()
		button.BackgroundColor3 = card.rest
		Ui.tween(button, Theme.MOTION.select, { Position = home })
		Ui.tween(glow, Theme.MOTION.select, { Position = glowHome })
	end)
	local function pick()
		if locked then
			return
		end
		onPick()
		refreshSelection()
		popScale(pop, 1.05)
		UiSound.play("Select")
	end
	card.pick = pick
	button.Activated:Connect(pick)
end

-- The cards rise into place one after another when the draft opens.
local function reveal(cards: { Card })
	revealToken += 1
	local token = revealToken
	local step = if #cards > 1 then math.min(REVEAL_STEP, 0.4 / (#cards - 1)) else 0
	for _, c in cards do
		c.button.Visible = false
		c.glow.Visible = false
	end
	for i, c in cards do
		task.delay((i - 1) * step + 0.05, function()
			local home = c.home
			if token ~= revealToken or not home then
				return
			end
			c.button.Position = home + UDim2.fromOffset(0, REVEAL_FROM)
			c.button.Visible = true
			Ui.tween(c.button, 0.32, { Position = home }, Enum.EasingStyle.Quint)
			UiSound.play("CardIn")
			refreshSelection()
		end)
	end
end

local function header(parent: Instance, label: string, y: number)
	Ui.text(parent, label, "displayM", {
		Position = UDim2.fromOffset(0, y),
		Size = UDim2.fromOffset(1920, 48),
	})
	for _, x in { 362, 1920 - 362 - 560 } do
		make("Frame", {
			Position = UDim2.fromOffset(x, y + 24),
			Size = UDim2.fromOffset(560, 2),
			BorderSizePixel = 0,
			BackgroundColor3 = C.lineStrong,
			BackgroundTransparency = 0.4,
		}, parent)
	end
end

local function gunCard(parent: Instance, id: string, index: number, phaseName: string): Card
	local config = Weapons.get(id)
	local x = (1920 - (GUN_W * 3 + GUN_GAP * 2)) / 2 + (index - 1) * (GUN_W + GUN_GAP)
	local button, line, glow =
		shell(parent, id, UDim2.fromOffset(x, GUN_Y), Vector2.new(GUN_W, 140), 12, C.lineSoft)
	Ui.gun(button, id, { Position = UDim2.fromOffset(40, 12), Size = UDim2.fromOffset(220, 78) })
	Ui.text(button, string.upper(if config then config.displayName else id), "titleS", {
		Position = UDim2.fromOffset(20, 98),
		Size = UDim2.fromOffset(150, 28),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local shield = MatchState.shieldFor(phaseName, id)
	local flat = false
	for _, phase in MatchConfig.PHASES do
		if phase.name == phaseName and phase.flatShield then
			flat = true
		end
	end
	if shield > 0 and not flat then
		Ui.tag(button, string.format("+%d shield", shield), C.ally, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromOffset(GUN_W - 16, 100),
		})
	end
	local card: Card = {
		button = button,
		line = line,
		glow = glow,
		id = id,
		rest = C.card,
		restLine = C.lineSoft,
		glowColor = C.white,
		slot = 0,
	}
	hookCard(card, function()
		selectedGun = id
		Net.event("DraftPick"):FireServer("Gun", id)
	end)
	return card
end

local function colX(slot: number): number
	return (1920 - (COL_W * 3 + COL_GAP * 2)) / 2 + (slot - 1) * (COL_W + COL_GAP)
end

-- A new ability for an empty slot: the full-height card.
local function abilityCard(parent: Instance, id: string, slot: number): Card
	local def = Mods.def(id)
	local role = if def then Theme.ROLE[def.role] or C.ally else C.ally
	local button, line, glow = shell(
		parent,
		id,
		UDim2.fromOffset(colX(slot), TOP),
		Vector2.new(COL_W, COL_H),
		20,
		C.lineSoft
	)
	-- Inset by the 2 px outline and rounded to the card's radius − 2 (nested
	-- rule), so the tint and art sit inside the card's edge.
	local inner = Ui.radius(20) - 2
	local tint = make("Frame", {
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.fromOffset(COL_W - 4, 298),
		BorderSizePixel = 0,
		BackgroundColor3 = role,
	}, button)
	make("UICorner", { CornerRadius = UDim.new(0, inner) }, tint)
	make("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new(1, 0.58),
	}, tint)
	local icon = if def then def.icon else ""
	local art = Theme.CARD_ART[id]
	if art then
		local artLabel = make("ImageLabel", {
			Name = "Art",
			Position = UDim2.fromOffset(2, 2),
			Size = UDim2.fromOffset(COL_W - 4, 298),
			BackgroundTransparency = 1,
			Image = art,
			-- The v1 art has the old cut corner baked in (40 px at 2x, top left):
			-- crop past it; UICorner rounds the rest.
			ImageRectOffset = Vector2.new(24, 24),
			ImageRectSize = Vector2.new(736, 576),
			ScaleType = Enum.ScaleType.Crop,
		}, button)
		make("UICorner", { CornerRadius = UDim.new(0, inner) }, artLabel)
	else
		make("ImageLabel", {
			Position = UDim2.fromOffset(150, 10),
			Size = UDim2.fromOffset(220, 220),
			BackgroundTransparency = 1,
			Image = icon,
			ImageTransparency = 0.93,
		}, button)
	end
	if art then
		-- The picture is the hero; the icon sits in a small badge in the corner.
		local badge = make("Frame", {
			Position = UDim2.fromOffset(22, 26),
			Size = UDim2.fromOffset(52, 52),
			BackgroundColor3 = C.panel,
			BackgroundTransparency = 0.25,
		}, button)
		make("UIStroke", { Color = role, Thickness = 1.5 }, badge)
		make("ImageLabel", {
			Position = UDim2.fromOffset(8, 8),
			Size = UDim2.fromOffset(36, 36),
			BackgroundTransparency = 1,
			Image = icon,
		}, badge)
	else
		make("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromOffset(COL_W / 2, 62),
			Size = UDim2.fromOffset(104, 104),
			BackgroundTransparency = 1,
			Image = icon,
		}, button)
	end
	Ui.text(button, string.upper(if def then def.name else id), "titleCard", {
		Position = UDim2.fromOffset(20, 186),
		Size = UDim2.fromOffset(COL_W - 40, 54),
	})
	if def then
		Ui.tag(button, def.role, role, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromOffset(COL_W / 2, 250),
		})
	end
	make("Frame", {
		Position = UDim2.fromOffset(28, 304),
		Size = UDim2.fromOffset(COL_W - 56, 2),
		BorderSizePixel = 0,
		BackgroundColor3 = C.lineSoft,
	}, button)
	Ui.text(button, cardNote(id, "L1") .. ".", "bodyM", {
		Position = UDim2.fromOffset(28, 326),
		Size = UDim2.fromOffset(COL_W - 56, 84),
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	if def then
		local paths = def.paths :: any
		Ui.text(button, "UPGRADES", "label", {
			Position = UDim2.fromOffset(28, 420),
			Size = UDim2.fromOffset(COL_W - 56, 16),
			TextColor3 = C.textDim,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		Ui.text(button, string.format("%s  ·  %s", paths.A or "", paths.B or ""), "bodyS", {
			Position = UDim2.fromOffset(28, 440),
			Size = UDim2.fromOffset(COL_W - 56, 20),
			TextColor3 = C.textSecondary,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
	end
	Ui.text(button, chargesText(id), "label", {
		Position = UDim2.fromOffset(28, COL_H - 44),
		Size = UDim2.fromOffset(230, 16),
		TextColor3 = C.textSecondary,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	Ui.text(button, "NEW  ·  LV 1", "label", {
		Position = UDim2.fromOffset(COL_W - 28 - 120, COL_H - 44),
		Size = UDim2.fromOffset(120, 16),
		TextColor3 = C.gold,
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	local card: Card = {
		button = button,
		line = line,
		glow = glow,
		id = id,
		rest = C.card,
		restLine = C.lineSoft,
		glowColor = C.white,
		slot = slot,
	}
	hookCard(card, function()
		selectedAbility = id
		Net.event("DraftPick"):FireServer("Ability", id)
	end)
	return card
end

-- One upgrade card in a filled slot's column. `compact` when three share it.
local function upgradeCard(
	parent: Instance,
	c: MatchState.UpgradeCard,
	from: string,
	y: number,
	compact: boolean
): Card
	local def = Mods.def(c.id)
	local path = string.sub(c.level, 1, 1)
	local glitch = path == "G"
	local accent = if glitch then C.glitch else C.gold
	local h = if compact then 160 else 256
	local button, line, glow = shell(
		parent,
		c.key,
		UDim2.fromOffset(colX(c.slot), y),
		Vector2.new(COL_W, h),
		if compact then 14 else 16,
		if glitch then C.glitch else C.lineSoft,
		if glitch then C.glitch else nil
	)
	if glitch then
		local tint = make("Frame", {
			Size = UDim2.fromOffset(COL_W, h),
			BorderSizePixel = 0,
			BackgroundColor3 = C.glitch,
		}, button)
		make("UIGradient", { Transparency = NumberSequence.new(0.76, 0.96) }, tint)
		for _, s in { { 250, 22, 90 }, { 300, 48, 50 }, { 220, h - 48, 120 }, { 320, h - 26, 40 } } do
			make("Frame", {
				Position = UDim2.fromOffset(s[1], s[2]),
				Size = UDim2.fromOffset(s[3], 3),
				BorderSizePixel = 0,
				BackgroundColor3 = C.glitch,
				BackgroundTransparency = 0.65,
			}, button)
		end
	end
	local pathName = if def then (def.paths :: any)[path] or c.level else c.level
	local badge = if glitch then "Glitched" else "Path " .. path
	local level = levelNumber(c.level)
	if compact then
		Ui.text(button, string.upper(pathName), "titleCard", {
			Position = UDim2.fromOffset(22, 14),
			Size = UDim2.fromOffset(240, 38),
			TextSize = 30,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		Ui.tag(
			button,
			badge,
			accent,
			{ AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromOffset(COL_W - 22, 22) },
			glitch
		)
		Ui.text(button, cardNote(c.id, c.level) .. ".", "bodyS", {
			Position = UDim2.fromOffset(22, 58),
			Size = UDim2.fromOffset(COL_W - 44, 52),
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
		})
		Ui.text(button, statChange(c.id, from, c.level), "titleS", {
			Position = UDim2.fromOffset(22, h - 40),
			Size = UDim2.fromOffset(COL_W - 44, 24),
			TextSize = 19,
			TextColor3 = accent,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
	else
		make("ImageLabel", {
			Position = UDim2.fromOffset(24, 20),
			Size = UDim2.fromOffset(40, 40),
			BackgroundTransparency = 1,
			Image = if glitch then Theme.ICON.Glitch elseif def then def.icon else "",
			ImageColor3 = if glitch then C.glitch else C.white,
		}, button)
		Ui.text(button, string.upper(if def then def.name else c.id), "titleS", {
			Position = UDim2.fromOffset(74, 28),
			Size = UDim2.fromOffset(180, 26),
			TextColor3 = C.textSecondary,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		Ui.tag(
			button,
			badge,
			accent,
			{ AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromOffset(COL_W - 24, 28) },
			glitch
		)
		Ui.text(button, string.upper(pathName), "titleCard", {
			Position = UDim2.fromOffset(24, 66),
			Size = UDim2.fromOffset(COL_W - 48, 50),
			TextSize = 40,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		for i = 1, 3 do
			make("Frame", {
				Position = UDim2.fromOffset(24 + (i - 1) * 46, 124),
				Size = UDim2.fromOffset(40, 6),
				BorderSizePixel = 0,
				BackgroundColor3 = if i <= level
					then (if glitch then C.glitch else C.ally)
					else C.lineStrong,
				BackgroundTransparency = if i == level then 0.45 else 0,
			}, button)
		end
		Ui.text(button, string.format("LV %d → %d", level - 1, level), "label", {
			Position = UDim2.fromOffset(170, 120),
			Size = UDim2.fromOffset(120, 16),
			TextColor3 = C.textSecondary,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		Ui.text(button, cardNote(c.id, c.level) .. ".", "bodyM", {
			Position = UDim2.fromOffset(24, 146),
			Size = UDim2.fromOffset(COL_W - 48, 56),
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
		})
		Ui.text(button, statChange(c.id, from, c.level), "titleS", {
			Position = UDim2.fromOffset(24, h - 46),
			Size = UDim2.fromOffset(COL_W - 48, 26),
			TextColor3 = accent,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
	end
	local card: Card = {
		button = button,
		line = line,
		glow = glow,
		id = c.key,
		rest = C.card,
		restLine = if glitch then C.glitch else C.lineSoft,
		glowColor = if glitch then C.glitch else C.white,
		slot = c.slot,
	}
	hookCard(card, function()
		selectedAbility = c.key
		Net.event("DraftPick"):FireServer("Ability", c.key)
	end)
	return card
end

-- A filled slot's column: its upgrade cards, or MAXED.
local function upgradeColumn(
	parent: Instance,
	slot: number,
	id: string,
	level: string,
	cards: { MatchState.UpgradeCard }
)
	if #cards == 0 then
		local def = Mods.def(id)
		local panel = Ui.cut(parent, {
			Name = "Maxed" .. slot,
			Position = UDim2.fromOffset(colX(slot), TOP),
			Size = UDim2.fromOffset(COL_W, COL_H),
		}, { color = C.panel, transparency = 0.3, line = C.lineSoft })
		make("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromOffset(COL_W / 2, 150),
			Size = UDim2.fromOffset(84, 84),
			BackgroundTransparency = 1,
			Image = if def then def.icon else "",
			ImageColor3 = C.textDim,
		}, panel)
		Ui.text(panel, "MAXED", "displayM", {
			Position = UDim2.fromOffset(0, 250),
			Size = UDim2.fromOffset(COL_W, 48),
			TextColor3 = C.textSecondary,
		})
		local path = string.sub(level, 1, 1)
		local pathName = if def then (def.paths :: any)[path] else nil
		Ui.text(
			panel,
			string.format("%s  ·  %s Lv 3", if def then def.name else id, pathName or ""),
			"bodyS",
			{
				Position = UDim2.fromOffset(0, 304),
				Size = UDim2.fromOffset(COL_W, 20),
				TextColor3 = C.textDim,
			}
		)
		return
	end
	local compact = #cards > 2
	local h = if compact then 160 else 256
	local gap = if compact then 30 else 28
	for i, c in cards do
		table.insert(
			abilityCards,
			upgradeCard(parent, c, level, TOP + (i - 1) * (h + gap), compact)
		)
	end
	if #cards == 2 then
		local y = TOP + h + gap / 2 - 8
		Ui.text(parent, "OR", "label", {
			Position = UDim2.fromOffset(colX(slot), y),
			Size = UDim2.fromOffset(COL_W, 16),
			TextColor3 = C.textSecondary,
		})
		for _, dx in { 130, 226 } do
			make("Frame", {
				Position = UDim2.fromOffset(colX(slot) + dx, y + 7),
				Size = UDim2.fromOffset(24, 2),
				BorderSizePixel = 0,
				BackgroundColor3 = C.lineStrong,
			}, parent)
		end
	end
end

-- The enemy's abilities (bottom right): icon tiles with level pips.
local function enemyKit(parent: Instance, entries: { string })
	local row = make("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromOffset(colX(3) + COL_W, 1004),
		Size = UDim2.fromOffset(300, 56),
		BackgroundTransparency = 1,
	}, parent)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
	}, row)
	Ui.text(row, if #entries > 0 then "ENEMY" else "ENEMY HAS NO ABILITIES YET", "label", {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 16),
		TextColor3 = C.enemy,
		LayoutOrder = 0,
	})
	for i, entry in entries do
		local id, level = string.match(entry, "^(%w+):(%w+)$")
		local def = id and Mods.def(id)
		if def and level then
			local tile = make("Frame", {
				Size = UDim2.fromOffset(44, 52),
				BackgroundColor3 = C.panel,
				BackgroundTransparency = 0.2,
				LayoutOrder = i,
			}, row)
			make("UIStroke", { Color = C.enemy, Thickness = 1.5, Transparency = 0.3 }, tile)
			make("ImageLabel", {
				Position = UDim2.fromOffset(8, 6),
				Size = UDim2.fromOffset(28, 28),
				BackgroundTransparency = 1,
				Image = def.icon,
			}, tile)
			for p = 1, 3 do
				make("Frame", {
					Position = UDim2.fromOffset(6 + (p - 1) * 11, 42),
					Size = UDim2.fromOffset(10, 4),
					BorderSizePixel = 0,
					BackgroundColor3 = if p <= levelNumber(level) then C.enemy else C.lineStrong,
				}, tile)
			end
		end
	end
end

local function lock()
	local button = lockButton
	if locked then
		return
	end
	if canLock() then
		locked = true
		Net.event("DraftPick"):FireServer("Lock")
		UiSound.play("LockIn")
		refreshSelection()
		local pulse = button and button:FindFirstChild("Pulse") :: UIScale?
		if pulse then
			popScale(pulse, 1.08)
		end
		return
	end
	-- Not ready: a "no" shake and the hint flashes.
	UiSound.play("Denied")
	if button then
		local home = UDim2.fromOffset(960, 1032)
		for i, dx in { -10, 8, -5, 0 } do
			task.delay((i - 1) * 0.04, function()
				button.Position = home + UDim2.fromOffset(dx, 0)
			end)
		end
	end
	local label = lockHint
	if label then
		label.TextColor3 = C.gold
		Ui.tween(label, 0.6, { TextColor3 = C.textSecondary })
	end
end

-- Keys: 1 / 2 / 3 pick a gun, Q / E / T a card in that column (pressing the
-- same key again steps through its cards), Enter locks in.
local function onKey(input: InputObject)
	if not isOpen or UserInputService:GetFocusedTextBox() then
		return
	end
	local key = input.KeyCode
	if key == Enum.KeyCode.Return or key == Enum.KeyCode.KeypadEnter then
		lock()
		return
	end
	for i, k in GUN_KEYS do
		local card = gunCards[i]
		if key == k and card and card.pick then
			card.pick()
			return
		end
	end
	local slot = SLOT_KEYS[key]
	if not slot then
		return
	end
	local column: { Card } = {}
	for _, c in abilityCards do
		if c.slot == slot then
			table.insert(column, c)
		end
	end
	if #column == 0 then
		UiSound.play("Denied")
		return
	end
	local at = 0
	for i, c in column do
		if c.id == selectedAbility then
			at = i
		end
	end
	local nextCard = column[at % #column + 1]
	if nextCard.pick then
		nextCard.pick()
	end
end

local function show(o: MatchState.DraftOffer)
	local p = canvas
	if not p then
		return
	end
	local old = p:FindFirstChild("Content")
	if old then
		old:Destroy() -- only the cards: the canvas keeps its UIScale
	end
	table.clear(gunCards)
	table.clear(abilityCards)
	offer = o
	selectedGun = o.gun
	selectedAbility = nil
	locked = false
	shownHint = ""
	if lockPulse then
		lockPulse:Cancel()
		lockPulse = nil
	end
	local content = make("Frame", {
		Name = "Content",
		AnchorPoint = Vector2.new(0.5, 0.5), -- the open pop grows from the middle
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, p)
	local scale = make("UIScale", { Scale = 0.97 }, content)

	header(content, "SELECT A GUN", 136)
	for i, id in o.guns do
		local card = gunCard(content, id, i, o.phase)
		Ui.text(card.button, tostring(i), "key", {
			Position = UDim2.fromOffset(14, 10),
			Size = UDim2.fromOffset(20, 18),
			TextColor3 = C.textDim,
		})
		table.insert(gunCards, card)
	end

	local upgrades = o.upgrades or {}
	header(
		content,
		if #o.abilities > 0 or #upgrades > 0 then "DRAFT AN ABILITY" else "YOUR ABILITIES",
		370
	)
	for slot = 1, ModsConfig.SLOTS do
		local owned = o.kit[slot] or ""
		local level = (o.levels or {})[slot] or ""
		if owned == "" then
			for _, id in o.abilities do
				local def = Mods.def(id)
				if def and def.slot == slot then
					table.insert(abilityCards, abilityCard(content, id, slot))
				end
			end
		else
			local cards: { MatchState.UpgradeCard } = {}
			for _, c in upgrades do
				if c.slot == slot then
					table.insert(cards, c)
				end
			end
			upgradeColumn(content, slot, owned, level, cards)
		end
		Ui.keyTab(
			content,
			KEYS[slot],
			levelNumber(level),
			UDim2.fromOffset(colX(slot) + COL_W / 2, TOP - 22)
		)
	end

	-- Bottom bar: the hint, LOCK IN, the enemy's kit.
	lockHint = Ui.text(content, "", "bodyS", {
		Position = UDim2.fromOffset(colX(1), 1012),
		Size = UDim2.fromOffset(410, 40),
		TextColor3 = C.textSecondary,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local button = Ui.cut(content, {
		Name = "LockIn",
		AnchorPoint = Vector2.new(0.5, 0.5), -- its pulse grows from the middle
		Position = UDim2.fromOffset(960, 1032),
		Size = UDim2.fromOffset(340, 64),
	}, { corner = 14, color = C.raised, className = "ImageButton" })
	lockIcon = make("ImageLabel", {
		Position = UDim2.fromOffset(98, 19),
		Size = UDim2.fromOffset(26, 26),
		BackgroundTransparency = 1,
		Image = Theme.ICON.Lock,
	}, button)
	lockLabel = Ui.text(button, "LOCK IN", "displayM", {
		Position = UDim2.fromOffset(134, 8),
		Size = UDim2.fromOffset(160, 48),
		TextSize = 36,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	make("UIScale", { Name = "Pulse" }, button)
	button.MouseEnter:Connect(function()
		if canLock() and not locked then
			UiSound.play("Hover")
		end
	end)
	button.Activated:Connect(lock)
	lockButton = button
	enemyKit(content, o.enemyKit)

	refreshSelection()
	setOpen(true)
	Ui.tween(scale, Theme.MOTION.enter, { Scale = 1 }, Enum.EasingStyle.Back)
	local order: { Card } = {}
	for _, c in gunCards do
		table.insert(order, c)
	end
	for _, c in abilityCards do
		table.insert(order, c)
	end
	reveal(order)
end

local function build()
	-- Core-UI safe area, like the top bar drawn above it (LihFolk: Safe Areas
	-- and Insets); the backdrop reaches up under Roblox's top bar anyway.
	local g = make("ScreenGui", {
		Name = "Draft",
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		SafeAreaCompatibility = Enum.SafeAreaCompatibility.None,
		DisplayOrder = 8,
	}, player:WaitForChild("PlayerGui"))
	local back = make("TextButton", {
		Name = "Backdrop",
		Position = UDim2.fromOffset(0, -160),
		Size = UDim2.new(1, 0, 1, 160),
		BackgroundColor3 = C.scrim,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Visible = false,
	}, g)
	make("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.14),
			NumberSequenceKeypoint.new(0.5, 0.26),
			NumberSequenceKeypoint.new(1, 0.08),
		}),
	}, back)
	backdrop = back
	local frame = make("Frame", {
		Name = "Canvas",
		AnchorPoint = Vector2.new(0.5, 0.5),
		-- Centred on the safe area, not on the backdrop (which reaches 160 px
		-- higher, under Roblox's top bar).
		Position = UDim2.new(0.5, 0, 0.5, 80),
		Size = UDim2.fromOffset(Theme.DESIGN.X, Theme.DESIGN.Y),
		BackgroundTransparency = 1,
	}, back)
	Ui.fit(frame)
	canvas = frame
end

-- The screen closes once you've locked in, or when the draft ends.
local function syncVisibility()
	if MatchState.phase() ~= "Draft" or player:GetAttribute("DraftLocked") == true then
		setOpen(false)
	end
end

function DraftController.isOpen(): boolean
	return isOpen
end

function DraftController.start()
	build()
	Net.event("DraftOffer").OnClientEvent:Connect(function(o: MatchState.DraftOffer)
		-- Queued while this client was starting up: that draft is already over.
		if o.endsAt > workspace:GetServerTimeNow() then
			show(o)
		end
	end)
	MatchState.changed("Phase"):Connect(syncVisibility)
	player:GetAttributeChangedSignal("DraftLocked"):Connect(syncVisibility)
	UiSound.preload()
	UserInputService.InputBegan:Connect(onKey)
	-- The hint counts down your default pick in the last seconds.
	task.spawn(function()
		while true do
			task.wait(0.25)
			if isOpen then
				updateHint()
			end
		end
	end)
	-- Started up mid-draft: ask for the cards.
	if MatchState.phase() == "Draft" then
		Net.event("DraftPick"):FireServer("Sync")
	end
end

return DraftController
