--!strict
-- The full-screen Play menu, v2 (vault/01 Design/Lobby UI and Queue.md section
-- 8; Figma "Lobby v2 · Play menu 1920x1080"): three mode cards (1v1 / 2v2 /
-- 3v3) with full-bleed art, live "searching" counts, FIND MATCH, and while
-- queued a status panel with the elapsed timer, the bot-fill countdown and
-- CANCEL. Also the MATCH FOUND moment (teams, bots, countdown) and, in Studio,
-- the TeleportData the server would have sent. The server decides everything.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Lobby.Config)
local LobbyNet = require(ReplicatedStorage.Lobby.LobbyNet)

local Fx = require(script.Parent.Parent.Util.Fx)
local Kit = require(script.Parent.Parent.Util.Kit)
local Layout = require(script.Parent.Parent.Util.Layout)
local Menu = require(script.Parent.Parent.Util.Menu)
local QueueState = require(script.Parent.Parent.Util.QueueState)
local Router = require(script.Parent.Parent.Util.Router)
local Sound = require(script.Parent.Parent.Util.Sound)
local Style = require(script.Parent.Parent.Util.Style)
local LobbyHud = require(script.Parent.LobbyHud)

local QueueMenu = {}

local C = Style.COLOR
local A = Style.ALPHA
local player = Players.LocalPlayer

-- Card art: the un-cut ChatGPT art (assets/UI/lobby/mode_*.png, 840 x 940,
-- uploaded as decals 103850486455095 / 85740050789097 / 105604126054827),
-- rounded in engine by UICorner. Clear an id to fall back to the colour wash.
local MODE_ART: { [string]: string } = {
	["1v1"] = "rbxassetid://132175332386485",
	["2v2"] = "rbxassetid://88838344441665",
	["3v3"] = "rbxassetid://91043835690868",
}
local ART_SIZE = Vector2.new(840, 940)

-- Desktop: the Figma frame (1920 x 1080). Phone: its own arrangement on the
-- 800 x 420 canvas (LihFolk: Responsive UI for Phone Tablet Console and PC):
-- smaller cards without the blurb or key chips, and a shorter status line.
local PHONE = Layout.isPhone()
local CANVAS = Menu.canvas()
local L = if PHONE
	then {
		cardW = 240,
		cardH = 208,
		cardGap = 16,
		cardY = 76,
		radius = 18,
		artH = 208,
		modeSize = 60,
		titleY = 64,
		blurbY = 0,
		metaY = 0,
		divY = 136,
		countY = 148,
		botsY = 174,
		details = false,
		find = Vector2.new(400, 306),
		findSize = Vector2.new(340, 76),
		findText = 30,
		findRadius = 18,
		status = Vector2.new(400, 302),
		statusSize = Vector2.new(660, 86),
		statusTitle = Vector2.new(64, 10),
		statusTitleSize = 22,
		statusSub = Vector2.new(64, 42),
		timerX = -170,
		timerSize = 36,
		cancelSize = Vector2.new(136, 60),
	}
	else {
		cardW = 440,
		cardH = 520,
		cardGap = 32,
		cardY = 220,
		radius = Style.RADIUS.xl,
		artH = 300,
		modeSize = Style.TEXT.mode.size,
		titleY = 200,
		blurbY = 330,
		metaY = 382,
		divY = 418,
		countY = 434,
		botsY = 466,
		details = true,
		find = Vector2.new(960, 788),
		findSize = Vector2.new(520, 96),
		findText = Style.TEXT.action.size,
		findRadius = 20,
		status = Vector2.new(960, 780),
		statusSize = Vector2.new(880, 112),
		statusTitle = Vector2.new(86, 18),
		statusTitleSize = 30,
		statusSub = Vector2.new(86, 58),
		timerX = -196,
		timerSize = Style.TEXT.timer.size,
		cancelSize = Vector2.new(156, 64),
	}
local CARD_W, CARD_H, CARD_GAP, CARD_Y = L.cardW, L.cardH, L.cardGap, L.cardY

type Card = {
	info: Config.ModeInfo,
	holder: Frame,
	button: TextButton,
	stroke: UIStroke,
	ring: Frame,
	tag: Frame,
	tagLabel: TextLabel,
	count: TextLabel,
	dot: Frame,
	shine: (() -> ())?,
}

local chrome: Menu.Chrome
local cards: { Card } = {}
local selected: string = "1v1"
local isOpen = false

local findHolder: Frame
local findButton: TextButton
local findLabel: TextLabel
local status: Frame
local statusTitle: TextLabel
local statusSub: TextLabel
local statusTimer: TextLabel
local statusFill: Frame
local statusCancel: TextButton

local timerConn: RBXScriptConnection? = nil
local lastSecond = -1

-- Match found overlay.
local foundGui: ScreenGui
local foundBand: Frame
local foundInner: Frame
local foundTitle: TextLabel
local foundMode: TextLabel
local foundTeams: Frame
local foundCountdown: TextLabel
local foundStudio: TextLabel
local foundOpen = false
local foundToken = 0

--------------------------------------------------------------------------------
-- Cards

local function refreshCards()
	local queued = QueueState.mode()
	local searching = QueueState.status() ~= "idle"
	for _, card in cards do
		local id = card.info.id
		local tint = Style.MODE[id] or C.primary
		local isSel = id == selected
		local isQueued = searching and queued == id
		card.stroke.Color = if isSel then tint else C.stroke
		card.stroke.Transparency = if isSel then 0 else A.stroke
		card.ring.Visible = isSel
		Fx.tween(
			card.button,
			Fx.MOTION.hover,
			{ BackgroundColor3 = if isSel then C.surfaceSelected else C.surface }
		)
		card.tag.Visible = isSel or isQueued
		card.tagLabel.Text = if isQueued then "IN QUEUE" else "SELECTED"
		card.tag.BackgroundColor3 = if isQueued then C.primary else tint
		local n = QueueState.count(id)
		card.count.Text = `{n} SEARCHING`
		card.dot.BackgroundColor3 = if n > 0 then C.success else C.textMuted
	end
end

local function selectMode(id: string, quiet: boolean?)
	if not Config.MODE_BY_ID[id] then
		return
	end
	if selected ~= id and not quiet then
		Sound.play("Select")
	end
	selected = id
	for _, card in cards do
		if card.info.id == id and not quiet then
			Fx.pop(card.button, 1.03)
		end
	end
	refreshCards()
end

-- FIND MATCH is ignored while a request is in flight (until the server's
-- state attribute changes, or 1.5 s), so taps can't stack requests.
local pendingUntil = 0

local function findMatch()
	if os.clock() < pendingUntil then
		return
	end
	local s = QueueState.status()
	if s == "idle" or (s == "searching" and QueueState.mode() ~= selected) then
		pendingUntil = os.clock() + 1.5
		Sound.play("LockIn")
		findLabel.Text = "JOINING..."
		QueueState.join(selected)
	end
end

local function buildCard(info: Config.ModeInfo, index: number)
	local tint = Style.MODE[info.id] or C.primary
	local x = (CANVAS.X - (3 * CARD_W + 2 * CARD_GAP)) / 2 + (index - 1) * (CARD_W + CARD_GAP)
	local holder = Kit.make("Frame", {
		Name = info.id,
		Position = UDim2.fromOffset(x, CARD_Y),
		Size = UDim2.fromOffset(CARD_W, CARD_H),
		BackgroundTransparency = 1,
	}, chrome.content)
	-- Selected: a soft outer ring in the mode colour (concentric: radius + 6).
	local ring = Kit.make("Frame", {
		Name = "Ring",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 12, 1, 12),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 1,
	}, holder)
	Kit.corner(ring, L.radius + 6)
	Kit.stroke(ring, tint, 0.55, 3)
	local button = Kit.surface(holder, {
		Name = "Button",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
	}, { className = "TextButton", radius = L.radius, transparency = 0.02 })
	Kit.shadow(button, L.radius)
	local stroke = Kit.strokeOf(button)

	-- Art, inset by the stroke so the light edge stays on top (nested radius).
	local art = MODE_ART[info.id]
	local artFrame = Kit.make("ImageLabel", {
		Name = "Art",
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.new(1, -4, 0, L.artH - 2),
		BackgroundColor3 = tint,
		BackgroundTransparency = if art then 1 else 0.55,
		Image = art or "",
		ScaleType = Enum.ScaleType.Stretch,
		ZIndex = 2,
	}, button)
	-- Show the top of the portrait art (the fighters), cropped to the card.
	local aspect = (CARD_W - 4) / (L.artH - 2)
	local rectH = math.min(ART_SIZE.X / aspect, ART_SIZE.Y)
	artFrame.ImageRectSize = Vector2.new(ART_SIZE.X, rectH)
	artFrame.ImageRectOffset = Vector2.new(0, if PHONE then 40 else 20)
	Kit.corner(artFrame, L.radius - 2)
	Kit.make("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(if PHONE then 0.35 else 0.55, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, artFrame)
	-- A faint wash of the mode colour from the top, and a dark floor under the
	-- title so it reads on any art.
	local wash = Kit.make("Frame", {
		Name = "Wash",
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.new(1, -4, 0, L.artH - 2),
		BackgroundColor3 = tint,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, button)
	Kit.corner(wash, L.radius - 2)
	Kit.make("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.82),
			NumberSequenceKeypoint.new(0.5, 1),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, wash)
	-- The floor runs past the art's bottom edge and fades out again, so there
	-- is no seam where the art ends.
	local floorTop = math.floor(L.artH * 0.4)
	local extra = math.max(0, math.min(64, CARD_H - L.artH - 2))
	local floorH = L.artH - floorTop + extra
	local edge = (L.artH - floorTop) / floorH
	local floor = Kit.make("Frame", {
		Name = "Floor",
		Position = UDim2.fromOffset(2, floorTop),
		Size = UDim2.new(1, -4, 0, floorH),
		BackgroundColor3 = C.surfaceDeep,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, button)
	Kit.make("UIGradient", {
		Rotation = 90,
		Transparency = if extra > 0
			then NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(edge, 0.45),
				NumberSequenceKeypoint.new(1, 1),
			})
			else NumberSequence.new(1, 0.2),
	}, floor)

	local title = Kit.text(button, info.title, "mode", {
		Name = "Title",
		Position = UDim2.fromOffset(if PHONE then 16 else 28, L.titleY),
		Size = UDim2.fromOffset(CARD_W - 40, math.ceil(L.modeSize * 1.1)),
		TextSize = L.modeSize,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 4,
	})
	Kit.textShadow(title, if PHONE then 2 else 4)

	local tag = Kit.tag(button, "SELECTED", tint, {
		Position = UDim2.fromOffset(if PHONE then 12 else 20, if PHONE then 12 else 20),
		Visible = false,
		ZIndex = 5,
	}, true)
	-- lihfolk-ignore: findfirstchild-chain (Kit.tag always makes its label)
	local tagLabel = tag:FindFirstChildWhichIsA("TextLabel") :: TextLabel
	for _, d in tag:GetDescendants() do
		if d:IsA("GuiObject") then
			d.ZIndex = 5
		end
	end
	if L.details and UserInputService.KeyboardEnabled then
		Kit.keyChip(button, tostring(index), {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -20, 0, 20),
			ZIndex = 5,
		})
	end

	local pad = if PHONE then 16 else 30
	if L.details then
		Kit.text(button, info.blurb, "body", {
			Name = "Blurb",
			Position = UDim2.fromOffset(pad, L.blurbY),
			Size = UDim2.fromOffset(CARD_W - 2 * pad, 46),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = true,
			TextColor3 = C.textSecondary,
			ZIndex = 4,
		})
		Kit.text(button, `FIRST TO 5  ·  {info.teamSize * 2} PLAYERS`, "labelS", {
			Name = "Meta",
			Position = UDim2.fromOffset(pad, L.metaY),
			Size = UDim2.fromOffset(CARD_W - 2 * pad, 20),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = C.textMuted,
			ZIndex = 4,
		})
	end
	Kit.divider(button, {
		Position = UDim2.fromOffset(pad, L.divY),
		Size = UDim2.fromOffset(CARD_W - 2 * pad, 2),
		ZIndex = 4,
	})
	local dot = Kit.make("Frame", {
		Name = "Dot",
		Position = UDim2.fromOffset(pad, L.countY + 6),
		Size = UDim2.fromOffset(10, 10),
		BackgroundColor3 = C.textMuted,
		BorderSizePixel = 0,
		ZIndex = 4,
	}, button)
	Kit.corner(dot, Style.RADIUS.pill)
	Fx.loop(dot, 0.9, { BackgroundTransparency = 0.6 })
	local count = Kit.text(button, "0 SEARCHING", "labelS", {
		Name = "Count",
		Position = UDim2.fromOffset(pad + 20, L.countY),
		Size = UDim2.fromOffset(CARD_W - 2 * pad - 20, 22),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 4,
	})
	Kit.text(
		button,
		if L.details
			then `BOTS FILL AFTER {Fx.clock(QueueState.botFillAfter())}`
			else `FIRST TO 5  ·  {info.teamSize * 2} PLAYERS`,
		"labelS",
		{
			Name = "Bots",
			Position = UDim2.fromOffset(pad, L.botsY),
			Size = UDim2.fromOffset(CARD_W - 2 * pad, 22),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = C.textMuted,
			ZIndex = 4,
		}
	)

	local card: Card = {
		info = info,
		holder = holder,
		button = button,
		stroke = stroke,
		ring = ring,
		tag = tag,
		tagLabel = tagLabel,
		count = count,
		dot = dot,
		shine = if Style.FLAGS.shine then Fx.shine(button, C.white, 0.08) else nil,
	}
	table.insert(cards, card)

	Fx.button(button, function()
		selectMode(info.id)
		if QueueState.status() == "searching" and QueueState.mode() ~= info.id then
			findMatch() -- switching mode while searching re-queues in the new mode
		end
	end, {
		lift = button,
		liftBy = 8,
		noScale = true, -- big cards lift instead of growing
		shine = card.shine,
		silent = false,
		enabled = function()
			return info.enabled
				and (QueueState.status() == "idle" or QueueState.status() == "searching")
		end,
		onHover = function(on)
			if info.id ~= selected then
				Fx.tween(
					button,
					Fx.MOTION.hover,
					{ BackgroundColor3 = if on then C.surfaceHover else C.surface }
				)
				Fx.tween(
					stroke,
					Fx.MOTION.hover,
					{ Transparency = if on then A.strokeHover else A.stroke }
				)
			end
		end,
	})
end

--------------------------------------------------------------------------------
-- Action area: FIND MATCH, or the searching status panel

local function buildAction()
	local p = Kit.primary(chrome.content, {
		Name = "Find",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(L.find.X, L.find.Y),
		Size = UDim2.fromOffset(L.findSize.X, L.findSize.Y),
	}, "FIND MATCH", "action", L.findRadius)
	findHolder = p.holder
	findButton = p.face
	findLabel = p.label
	findLabel.TextSize = L.findText
	p.glow.breathe()
	Fx.button(findButton, findMatch, {
		shine = if Style.FLAGS.shine then Fx.shine(findButton, C.white, 0.3) else nil,
		silent = true,
		onPress = p.press,
		onHover = function(on)
			if on then
				Sound.play("Hover")
				Fx.glitch(findLabel)
			end
		end,
	})

	status = Kit.surface(chrome.content, {
		Name = "Status",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(L.status.X, L.status.Y),
		Size = UDim2.fromOffset(L.statusSize.X, L.statusSize.Y),
		Visible = false,
	}, {
		radius = Style.RADIUS.xl,
		transparency = 0.02,
		stroke = C.primary,
		strokeTransparency = 0.45,
	})
	Fx.spinner(status, if PHONE then 28 else 36, C.primary, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, if PHONE then 20 else 30, 0.5, -3),
		ZIndex = 3,
	})
	statusTitle = Kit.text(status, "SEARCHING", "heading", {
		Position = UDim2.fromOffset(L.statusTitle.X, L.statusTitle.Y),
		Size = UDim2.fromOffset(380, L.statusTitleSize + 6),
		TextSize = L.statusTitleSize,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
	})
	statusSub = Kit.text(status, "", "bodyS", {
		Position = UDim2.fromOffset(L.statusSub.X, L.statusSub.Y),
		Size = UDim2.fromOffset(if PHONE then 300 else 420, 20),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.textSecondary,
		ZIndex = 3,
	})
	statusTimer = Kit.text(status, "0:00", "timer", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, L.timerX, 0.5, -3),
		Size = UDim2.fromOffset(170, L.timerSize + 8),
		TextSize = L.timerSize,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 3,
	})
	local _, fill = Kit.track(status, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.new(1, -60, 0, 4),
		ZIndex = 3,
	})
	statusFill = fill
	local cancelHolder = Kit.make("Frame", {
		Name = "CancelHolder",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -24, 0.5, -3),
		Size = UDim2.fromOffset(L.cancelSize.X, L.cancelSize.Y),
		BackgroundTransparency = 1,
		ZIndex = 3,
	}, status)
	statusCancel = Kit.surface(cancelHolder, {
		Name = "Cancel",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
	}, {
		className = "TextButton",
		color = C.surfaceHover,
		radius = Style.RADIUS.pill,
		strokeTransparency = 0.8,
	})
	Kit.text(statusCancel, "CANCEL", "label", { Size = UDim2.fromScale(1, 1), ZIndex = 4 })
	Fx.button(statusCancel, function()
		QueueState.leave()
	end, {
		onHover = function(on)
			Fx.tween(
				statusCancel,
				Fx.MOTION.hover,
				{ BackgroundColor3 = if on then C.danger else C.surfaceHover }
			)
		end,
	})
end

local function updateTimer()
	local s = QueueState.status()
	if s ~= "searching" then
		return
	end
	local elapsed = QueueState.elapsed()
	local fill = QueueState.botFillAfter()
	statusFill.Size = UDim2.fromScale(math.clamp(elapsed / math.max(fill, 0.1), 0, 1), 1)
	local second = math.floor(elapsed)
	if second == lastSecond then
		return
	end
	lastSecond = second
	statusTimer.Text = Fx.clock(elapsed)
	local left = fill - elapsed
	local short = `Bots fill in {Fx.clock(left + 0.999)}`
	statusSub.Text = if left <= 0
		then "Starting with bots..."
		elseif PHONE then short
		else `Looking for players  ·  bots fill empty slots in {Fx.clock(left + 0.999)}`
	-- The text floor can make the long line too wide on small screens.
	if not statusSub.TextFits then
		statusSub.Text = if left <= 0 then "Starting with bots..." else short
	end
end

local function refreshAction()
	local s = QueueState.status()
	local mode = QueueState.mode()
	local idle = s == "idle"
	local switching = s == "searching" and mode ~= selected
	findHolder.Visible = idle or switching
	status.Visible = not idle and not switching
	findLabel.Text = if os.clock() < pendingUntil
		then "JOINING..."
		elseif switching then `SWITCH TO {string.upper(selected)}`
		else "FIND MATCH"
	if s == "searching" then
		statusTitle.Text = `SEARCHING  ·  {string.upper(mode or "")}`
		statusTitle.TextColor3 = C.text
		statusCancel.Parent.Visible = true
		statusTimer.Position = UDim2.new(1, L.timerX, 0.5, -4)
	elseif s == "found" or s == "teleporting" then
		statusTitle.Text = "MATCH FOUND"
		statusTitle.TextColor3 = C.success
		statusSub.Text = if s == "teleporting" then "Teleporting..." else "Get ready"
		statusCancel.Parent.Visible = false
		statusTimer.Position = UDim2.new(1, -30, 0.5, -4)
		statusTimer.Text = ""
		statusFill.Size = UDim2.fromScale(1, 1)
	end
	lastSecond = -1
	updateTimer()
end

--------------------------------------------------------------------------------
-- Open / close

local function animateIn(arg: any?)
	if typeof(arg) == "string" and Config.MODE_BY_ID[arg] then
		selectMode(arg, true)
	elseif QueueState.mode() then
		selectMode(QueueState.mode() :: string, true)
	end
	refreshCards()
	refreshAction()
	if isOpen then
		return
	end
	isOpen = true
	Menu.show(chrome)
	-- Cards rise in one after another (vault UI Design -> Motion: 48 px, 0.32 s
	-- Quint, staggered, total under 0.4 s). Input works from the first frame.
	for i, card in cards do
		local base = Fx.base(card.button)
		card.button.Position = base + UDim2.fromOffset(0, 48)
		task.delay((i - 1) * Fx.MOTION.stagger, function()
			if isOpen then
				Fx.tween(card.button, 0.32, { Position = base })
				Sound.play("CardIn")
			end
		end)
	end
	if not timerConn then
		timerConn = RunService.Heartbeat:Connect(function()
			updateTimer()
			-- A request the server ignored: give FIND MATCH back.
			if pendingUntil > 0 and os.clock() >= pendingUntil then
				pendingUntil = 0
				refreshAction()
			end
		end)
	end
end

local function animateOut()
	if not isOpen then
		return
	end
	isOpen = false
	for _, card in cards do
		Fx.out(card.button, { Position = Fx.base(card.button) + UDim2.fromOffset(0, 24) })
	end
	if timerConn then
		timerConn:Disconnect()
		timerConn = nil
	end
	Menu.hide(chrome, function()
		return isOpen
	end)
end

local function buildMenu()
	chrome = Menu.build("LobbyQueue", "PLAY  ·  CASUAL DUELS", "CHOOSE YOUR FIGHT")
	for i, info in Config.MODES do
		buildCard(info, i)
	end
	buildAction()

	-- Keyboard hints as key chips (desktop with a keyboard only).
	if not PHONE and UserInputService.KeyboardEnabled then
		local hints = Kit.make("Frame", {
			Name = "Hints",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromOffset(960, 930),
			Size = UDim2.fromOffset(1400, 32),
			BackgroundTransparency = 1,
		}, chrome.content)
		Kit.make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, hints)
		local order = 0
		for _, h in
			{
				{ "1  2  3", "choose" },
				{ "ENTER", "find match" },
				{ "BACKSPACE", "back" },
				{ "", "Close any time: you stay in the queue." },
			}
		do
			if h[1] ~= "" then
				order += 1
				Kit.keyChip(hints, h[1], { LayoutOrder = order })
			end
			order += 1
			Kit.text(hints, h[2], "bodyS", {
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, 32),
				TextColor3 = C.textSecondary,
				LayoutOrder = order,
			})
			order += 1
			Kit.make("Frame", {
				Size = UDim2.fromOffset(18, 2),
				BackgroundTransparency = 1,
				LayoutOrder = order,
			}, hints)
		end
	end
end

--------------------------------------------------------------------------------
-- MATCH FOUND

local function slot(parent: Instance, userId: number?, color: Color3, order: number)
	local f = Kit.make("Frame", {
		Size = UDim2.fromOffset(120, 160),
		BackgroundTransparency = 1,
		LayoutOrder = order,
	}, parent)
	local card = Kit.surface(f, {
		Name = "Card",
		Size = UDim2.fromOffset(120, 120),
		ZIndex = 2,
	}, {
		color = if userId then C.surfaceHover else C.surface,
		radius = Style.RADIUS.lg,
		stroke = color,
		strokeTransparency = if userId then 0 else 0.55,
		strokeThickness = Style.STROKE.selected,
	})
	Kit.shadow(card, Style.RADIUS.lg)
	local name = "BOT"
	if userId then
		local p = Players:GetPlayerByUserId(userId)
		name = if p then p.DisplayName else "Player"
		local img = Kit.make("ImageLabel", {
			Position = UDim2.fromOffset(3, 3),
			Size = UDim2.new(1, -6, 1, -6),
			BackgroundTransparency = 1,
			ZIndex = 3,
		}, card)
		Kit.corner(img, Style.RADIUS.lg - 3)
		task.spawn(function()
			local ok, image = pcall(
				Players.GetUserThumbnailAsync,
				Players,
				userId,
				Enum.ThumbnailType.HeadShot,
				Enum.ThumbnailSize.Size150x150
			)
			if ok then
				img.Image = image
			end
		end)
	else
		Kit.text(card, "BOT", "heading", {
			Size = UDim2.fromScale(1, 1),
			TextSize = 30,
			TextColor3 = C.textSecondary,
			ZIndex = 3,
		})
	end
	Kit.text(f, name, "name", {
		Position = UDim2.fromOffset(0, 130),
		Size = UDim2.fromOffset(120, 24),
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextColor3 = if userId == player.UserId then C.primary else C.text,
	})
	local s = Fx.scale(f)
	s.Scale = 0.6
	task.delay(0.25 + order * 0.06, function()
		Fx.tween(s, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
		Sound.play("CardIn")
	end)
end

local function buildFound()
	foundGui = Kit.make("ScreenGui", {
		Name = "LobbyMatchFound",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ScreenInsets = Enum.ScreenInsets.None, -- edge art only, nothing to press
		SafeAreaCompatibility = Enum.SafeAreaCompatibility.None,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 30,
		Enabled = false,
	}, player:WaitForChild("PlayerGui"))
	foundBand = Kit.make("Frame", {
		Name = "Band",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundColor3 = C.scrim,
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, foundGui)
	Kit.make("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, C.surface),
			ColorSequenceKeypoint.new(0.5, C.scrim),
			ColorSequenceKeypoint.new(1, C.surface),
		}),
	}, foundBand)
	for _, y in { 0, 1 } do
		Kit.make("Frame", {
			AnchorPoint = Vector2.new(0, y),
			Position = UDim2.fromScale(0, y),
			Size = UDim2.new(1, 0, 0, 3),
			BackgroundColor3 = C.primary,
			BorderSizePixel = 0,
			ZIndex = 3,
		}, foundBand)
	end
	local inner = Kit.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(1920, 520),
		BackgroundTransparency = 1,
	}, foundBand)
	foundInner = inner
	foundTitle = Kit.text(inner, "MATCH FOUND", "hero", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(960, 18),
		Size = UDim2.fromOffset(1200, 136),
		TextColor3 = C.primary,
		ZIndex = 4,
	})
	foundMode = Kit.text(inner, "", "label", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(960, 154),
		Size = UDim2.fromOffset(800, 26),
		TextSize = 20,
		TextColor3 = C.textSecondary,
		ZIndex = 4,
	})
	foundTeams = Kit.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(960, 200),
		Size = UDim2.fromOffset(1400, 170),
		BackgroundTransparency = 1,
		ZIndex = 4,
	}, inner)
	Kit.make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Top,
		Padding = UDim.new(0, 18),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, foundTeams)
	foundCountdown = Kit.text(inner, "", "heading", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(960, 392),
		Size = UDim2.fromOffset(900, 30),
		TextSize = 26,
		ZIndex = 4,
	})
	foundStudio = Kit.text(inner, "", "bodyS", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(960, 430),
		Size = UDim2.fromOffset(1500, 70),
		TextWrapped = true,
		TextColor3 = C.textSecondary,
		Visible = false,
		ZIndex = 4,
	})
	Layout.fit(inner, "found")
end

local function closeFound()
	if not foundOpen then
		return
	end
	foundOpen = false
	foundToken += 1
	local token = foundToken
	Fx.tween(
		foundBand,
		0.22,
		{ Size = UDim2.new(1, 0, 0, 0) },
		Enum.EasingStyle.Quint,
		Enum.EasingDirection.In
	)
	task.delay(0.25, function()
		if foundToken == token then
			foundGui.Enabled = false
		end
	end)
end

local function showFound(payload: LobbyNet.QueueEventPayload)
	local teams = payload.teams
	local teamSize = payload.teamSize
	if typeof(teams) ~= "table" or typeof(teamSize) ~= "number" then
		return
	end
	Router.close()
	foundToken += 1
	local token = foundToken
	foundOpen = true
	for _, child in foundTeams:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	local order = 0
	for t = 1, 2 do
		local team = teams[t] or {}
		local color = if t == 1 then C.ally else C.enemy
		for i = 1, teamSize do
			order += 1
			local id = team[i]
			slot(foundTeams, if typeof(id) == "number" then id else nil, color, order)
		end
		if t == 1 then
			order += 1
			local vs = Kit.make("Frame", {
				Size = UDim2.fromOffset(110, 120),
				BackgroundTransparency = 1,
				LayoutOrder = order,
			}, foundTeams)
			Kit.text(
				vs,
				"VS",
				"title",
				{ Size = UDim2.fromScale(1, 1), TextColor3 = C.textSecondary }
			)
		end
	end
	local bots = 0
	for t = 1, 2 do
		bots += teamSize - #(teams[t] or {})
	end
	foundMode.Text = `{string.upper(payload.mode or "")}  ·  CASUAL`
		.. (if bots > 0 then `  ·  {bots} BOT{if bots == 1 then "" else "S"}` else "")
	foundStudio.Visible = false
	foundCountdown.TextColor3 = C.text

	foundGui.Enabled = true
	foundBand.Size = UDim2.new(1, 0, 0, 0)
	-- The band opens to its content's drawn height (it scales per screen).
	local bandHeight = foundInner.AbsoluteSize.Y + 24
	if foundGui.AbsoluteSize.Y > 0 then
		bandHeight = math.min(bandHeight, foundGui.AbsoluteSize.Y)
	end
	Fx.tween(foundBand, Fx.MOTION.enter, { Size = UDim2.new(1, 0, 0, bandHeight) })
	local s = Fx.scale(foundTitle)
	s.Scale = 1.35
	Fx.tween(s, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
	Sound.play("LockIn")
	Sound.play("Banner")
	task.delay(0.12, function()
		Fx.glitch(foundTitle)
	end)

	-- Countdown to the teleport.
	task.spawn(function()
		local last = -1
		while foundToken == token and foundOpen and not foundStudio.Visible do
			local st = QueueState.status()
			if st == "teleporting" then
				foundCountdown.Text = "TELEPORTING..."
			elseif st == "found" then
				local left = math.ceil(QueueState.startsIn())
				foundCountdown.Text = if left > 0 then `TELEPORTING IN {left}` else "CONNECTING..."
				if left ~= last and left > 0 then
					last = left
					Sound.play(if left == 1 then "TickFinal" else "Tick")
					Fx.pop(foundCountdown, 1.15)
				end
			end
			task.wait(0.1)
		end
	end)
end

local function onQueueEvent(payload: any)
	if typeof(payload) ~= "table" then
		return
	end
	local kind = payload.kind
	if kind == "found" then
		showFound(payload)
	elseif kind == "studio" then
		if foundOpen and typeof(payload.payload) == "string" then
			foundCountdown.Text =
				"STUDIO: TELEPORT SKIPPED. THIS IS THE TELEPORTDATA IT WOULD SEND:"
			foundCountdown.TextColor3 = C.textSecondary
			foundStudio.Text = payload.payload
			foundStudio.Visible = true
		end
	elseif kind == "failed" and typeof(payload.text) == "string" then
		closeFound()
		LobbyHud.toast(payload.text, "error")
	elseif kind == "info" and typeof(payload.text) == "string" then
		LobbyHud.toast(payload.text, "info")
	end
end

--------------------------------------------------------------------------------

function QueueMenu.init()
	buildMenu()
	buildFound()
	Router.register("Queue", {
		open = animateIn,
		close = animateOut,
		focus = function(): GuiObject?
			if findHolder.Visible then
				return findButton
			end
			for _, card in cards do
				if card.info.id == selected then
					return card.button
				end
			end
			return nil
		end,
	})
end

function QueueMenu.start()
	Router.setBlocked(function()
		return foundOpen
	end)
	LobbyNet.event("QueueEvent").OnClientEvent:Connect(onQueueEvent)
	QueueState.onChanged(function()
		pendingUntil = 0
		if QueueState.status() == "idle" then
			closeFound()
		end
		if isOpen then
			refreshCards()
			refreshAction()
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not isOpen then
			return
		end
		local key = input.KeyCode
		if key == Enum.KeyCode.One then
			selectMode("1v1")
		elseif key == Enum.KeyCode.Two then
			selectMode("2v2")
		elseif key == Enum.KeyCode.Three then
			selectMode("3v3")
		elseif key == Enum.KeyCode.Return or key == Enum.KeyCode.KeypadEnter then
			findMatch()
		else
			return
		end
		refreshAction()
	end)
end

return QueueMenu
