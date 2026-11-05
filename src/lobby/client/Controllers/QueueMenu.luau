--!strict
-- The full-screen Play menu (vault/01 Design/Lobby UI and Queue.md): three mode
-- cards (1v1 / 2v2 / 3v3) with live "searching" counts, FIND MATCH, and while
-- queued a status panel with the elapsed timer, the bot-fill countdown and
-- CANCEL. Also the MATCH FOUND moment (teams, bots, countdown) and, in Studio,
-- the TeleportData the server would have sent. The server decides everything.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Lobby.Config)
local LobbyNet = require(ReplicatedStorage.Lobby.LobbyNet)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)

local Fx = require(script.Parent.Parent.Util.Fx)
local QueueState = require(script.Parent.Parent.Util.QueueState)
local Router = require(script.Parent.Parent.Util.Router)
local Sound = require(script.Parent.Parent.Util.Sound)
local Ui = require(script.Parent.Parent.SharedUi)
local LobbyHud = require(script.Parent.LobbyHud)

local QueueMenu = {}

local C = Theme.COLORS
local player = Players.LocalPlayer

local MODE_TINT: { [string]: Color3 } = {
	["1v1"] = C.enemy,
	["2v2"] = C.ally,
	["3v3"] = Theme.ROLE.Control,
}

local CARD_W, CARD_H, CARD_GAP, CARD_Y = 420, 470, 36, 250
local MONO = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Medium)

type Card = {
	info: Config.ModeInfo,
	holder: Frame,
	button: ImageButton,
	line: ImageLabel,
	accent: Frame,
	count: TextLabel,
	dot: Frame,
	queuedTag: Frame,
	shine: () -> (),
}

local gui: ScreenGui
local scrim: TextButton
local content: CanvasGroup
local header: Frame
local cards: { Card } = {}
local selected: string = "1v1"
local isOpen = false

local findHolder: Frame
local findButton: ImageButton
local findLabel: TextLabel
local status: ImageLabel
local statusTitle: TextLabel
local statusSub: TextLabel
local statusTimer: TextLabel
local statusFill: Frame
local statusCancel: ImageButton

local timerConn: RBXScriptConnection? = nil
local lastSecond = -1

-- Match found overlay.
local foundGui: ScreenGui
local foundBand: Frame
local foundTitle: TextLabel
local foundMode: TextLabel
local foundTeams: Frame
local foundCountdown: TextLabel
local foundStudio: TextLabel
local foundOpen = false
local foundToken = 0

--------------------------------------------------------------------------------
-- Pieces

local function person(parent: Instance, color: Color3, x: number, transparency: number?)
	local f = Ui.make("Frame", {
		Position = UDim2.fromOffset(x, 0),
		Size = UDim2.fromOffset(34, 46),
		BackgroundTransparency = 1,
		ZIndex = 4,
	}, parent)
	local head = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(18, 18),
		BackgroundColor3 = color,
		BackgroundTransparency = transparency or 0,
		BorderSizePixel = 0,
		ZIndex = 4,
	}, f)
	Ui.make("UICorner", { CornerRadius = UDim.new(1, 0) }, head)
	local body = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromOffset(32, 24),
		BackgroundColor3 = color,
		BackgroundTransparency = transparency or 0,
		BorderSizePixel = 0,
		ZIndex = 4,
	}, f)
	Ui.make("UICorner", { CornerRadius = UDim.new(0.45, 0) }, body)
end

local function teamsRow(parent: Instance, teamSize: number, y: number)
	local w = teamSize * 40
	local row = Ui.make("Frame", {
		Position = UDim2.fromOffset(32, y),
		Size = UDim2.fromOffset(CARD_W - 64, 46),
		BackgroundTransparency = 1,
		ZIndex = 4,
	}, parent)
	for i = 1, teamSize do
		person(row, C.ally, (i - 1) * 40)
	end
	Ui.text(row, "VS", "titleS", {
		Position = UDim2.fromOffset(w + 6, 0),
		Size = UDim2.fromOffset(40, 46),
		TextColor3 = C.textDim,
		ZIndex = 4,
	})
	for i = 1, teamSize do
		person(row, C.enemy, w + 52 + (i - 1) * 40)
	end
end

local function closeButton(parent: Instance): ImageButton
	local holder = Ui.make("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromOffset(1800, 128),
		Size = UDim2.fromOffset(64, 64),
		BackgroundTransparency = 1,
	}, parent)
	local button = Ui.cut(holder, { Size = UDim2.fromScale(1, 1) }, {
		className = "ImageButton",
		color = C.panel,
		transparency = 0.1,
		line = C.lineStrong,
		corner = 12,
	})
	for _, r in { 45, -45 } do
		Ui.make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(28, 3),
			Rotation = r,
			BackgroundColor3 = C.text,
			BorderSizePixel = 0,
			ZIndex = 4,
		}, button)
	end
	Fx.button(button, function()
		Router.close()
	end, {
		silent = true,
		onHover = function(on)
			Fx.tween(button, 0.12, { ImageColor3 = if on then C.hover else C.panel })
		end,
	})
	return button
end

--------------------------------------------------------------------------------
-- Cards

local function refreshCards()
	local queued = QueueState.mode()
	local searching = QueueState.status() ~= "idle"
	for _, card in cards do
		local id = card.info.id
		local isSel = id == selected
		local isQueued = searching and queued == id
		card.line.ImageColor3 = if isSel then C.text else C.lineSoft
		card.line.ImageTransparency = if isSel then 0 else 0.2
		Fx.tween(card.accent, 0.2, { Size = UDim2.new(if isSel then 1 else 0, 0, 0, 4) })
		Fx.tween(card.button, 0.15, { ImageColor3 = if isSel then C.raised else C.card })
		card.queuedTag.Visible = isQueued
		local n = QueueState.count(id)
		card.count.Text = `{n} SEARCHING`
		card.dot.BackgroundColor3 = if n > 0 then C.ready else C.textDim
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

local function findMatch()
	local s = QueueState.status()
	if s == "idle" or (s == "searching" and QueueState.mode() ~= selected) then
		Sound.play("LockIn")
		QueueState.join(selected)
	end
end

local function buildCard(info: Config.ModeInfo, index: number)
	local x = (1920 - (3 * CARD_W + 2 * CARD_GAP)) / 2 + (index - 1) * (CARD_W + CARD_GAP)
	local holder = Ui.make("Frame", {
		Name = info.id,
		Position = UDim2.fromOffset(x, CARD_Y),
		Size = UDim2.fromOffset(CARD_W, CARD_H),
		BackgroundTransparency = 1,
	}, content)
	local button = Ui.cut(holder, { Size = UDim2.fromScale(1, 1) }, {
		className = "ImageButton",
		color = C.card,
		transparency = 0.04,
		line = C.lineSoft,
		corner = 26,
	})
	local tint = MODE_TINT[info.id] or C.gold
	-- A wash of the mode's colour from the top (stand-in for card art).
	local wash = Ui.cut(button, { Size = UDim2.fromScale(1, 1), ZIndex = 2 }, {
		color = tint,
		transparency = 0.0,
		corner = 26,
	})
	Ui.make("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.72),
			NumberSequenceKeypoint.new(0.55, 0.97),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, wash)
	-- Diagonal hairlines: a quiet texture in the wash.
	for i = 0, 5 do
		Ui.make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(300 + i * 26, 60),
			Size = UDim2.fromOffset(2, 260),
			Rotation = 30,
			BackgroundColor3 = tint,
			BackgroundTransparency = 0.82 + i * 0.025,
			BorderSizePixel = 0,
			ZIndex = 2,
		}, button)
	end

	Ui.text(button, info.title, "displayXL", {
		Position = UDim2.fromOffset(30, 22),
		Size = UDim2.fromOffset(360, 140),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 4,
	})
	local key = Ui.make("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromOffset(CARD_W - 26, 30),
		Size = UDim2.fromOffset(32, 32),
		BackgroundColor3 = C.panel,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		ZIndex = 4,
	}, button)
	Ui.make("UIStroke", { Color = C.lineStrong, Thickness = 1.5 }, key)
	Ui.text(key, tostring(index), "key", { Size = UDim2.fromScale(1, 1), ZIndex = 5 })

	teamsRow(button, info.teamSize, 178)
	Ui.text(button, info.blurb, "bodyM", {
		Position = UDim2.fromOffset(32, 248),
		Size = UDim2.fromOffset(CARD_W - 64, 48),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		TextColor3 = C.textSecondary,
		ZIndex = 4,
	})
	Ui.text(button, `FIRST TO 5  ·  {info.teamSize * 2} PLAYERS`, "label", {
		Position = UDim2.fromOffset(32, 316),
		Size = UDim2.fromOffset(CARD_W - 64, 18),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.textDim,
		ZIndex = 4,
	})
	Ui.make("Frame", {
		Position = UDim2.fromOffset(32, 362),
		Size = UDim2.fromOffset(CARD_W - 64, 1),
		BackgroundColor3 = C.lineSoft,
		BorderSizePixel = 0,
		ZIndex = 4,
	}, button)
	local dot = Ui.make("Frame", {
		Position = UDim2.fromOffset(32, 392),
		Size = UDim2.fromOffset(10, 10),
		BackgroundColor3 = C.textDim,
		BorderSizePixel = 0,
		ZIndex = 4,
	}, button)
	Ui.make("UICorner", { CornerRadius = UDim.new(1, 0) }, dot)
	Fx.loop(dot, 0.9, { BackgroundTransparency = 0.6 })
	local count = Ui.text(button, "0 SEARCHING", "label", {
		Position = UDim2.fromOffset(52, 386),
		Size = UDim2.fromOffset(180, 22),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 14,
		ZIndex = 4,
	})
	Ui.text(button, `BOTS AFTER {Fx.clock(QueueState.botFillAfter())}`, "label", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromOffset(CARD_W - 32, 386),
		Size = UDim2.fromOffset(180, 22),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = C.textDim,
		ZIndex = 4,
	})
	local queuedTag = Ui.tag(button, "IN QUEUE", C.gold, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromOffset(CARD_W - 70, 32),
		Visible = false,
		ZIndex = 5,
	}, true)
	local accent = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromOffset(0, 4),
		BackgroundColor3 = C.gold,
		BorderSizePixel = 0,
		ZIndex = 6,
	}, button)
	local card: Card = {
		info = info,
		holder = holder,
		button = button,
		-- lihfolk-ignore: findfirstchild-chain (Ui.cut always makes "Line" when `line` is passed)
		line = button:FindFirstChild("Line") :: ImageLabel,
		accent = accent,
		count = count,
		dot = dot,
		queuedTag = queuedTag,
		shine = Fx.shine(button, C.white, 0.12),
	}
	table.insert(cards, card)

	Fx.button(button, function()
		selectMode(info.id)
		if QueueState.status() == "searching" and QueueState.mode() ~= info.id then
			findMatch() -- switching mode while searching re-queues in the new mode
		end
	end, {
		lift = button,
		liftBy = 10,
		shine = card.shine,
		silent = false,
		enabled = function()
			return info.enabled
				and (QueueState.status() == "idle" or QueueState.status() == "searching")
		end,
		onHover = function(on)
			if info.id ~= selected then
				Fx.tween(button, 0.15, { ImageColor3 = if on then C.hover else C.card })
			end
		end,
	})
end

--------------------------------------------------------------------------------
-- Action area: FIND MATCH, or the searching status panel

local function buildAction()
	findHolder = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(960, 790),
		Size = UDim2.fromOffset(480, 96),
		BackgroundTransparency = 1,
	}, content)
	local glow = Ui.cut(findHolder, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 14, 1, 14),
	}, { color = C.gold, transparency = 0.8, corner = 22 })
	Fx.loop(glow, 1.3, { ImageTransparency = 0.55, Size = UDim2.new(1, 22, 1, 22) })
	findButton = Ui.cut(findHolder, { Size = UDim2.fromScale(1, 1), ZIndex = 2 }, {
		className = "ImageButton",
		color = C.gold,
		corner = 22,
	})
	findLabel = Ui.text(findButton, "FIND MATCH", "displayM", {
		Size = UDim2.fromScale(1, 1),
		TextColor3 = C.onAccent,
		ZIndex = 4,
	})
	local shine = Fx.shine(findButton, C.white, 0.35)
	Fx.button(findButton, findMatch, {
		lift = findButton,
		shine = shine,
		silent = true,
		onHover = function(on)
			if on then
				Sound.play("Hover")
				Fx.glitch(findLabel)
			end
		end,
	})

	status = Ui.cut(content, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(960, 784),
		Size = UDim2.fromOffset(820, 108),
		Visible = false,
	}, {
		color = C.panel,
		transparency = 0.04,
		line = C.gold,
		lineTransparency = 0.35,
		corner = 20,
	})
	Fx.spinner(status, 40, C.gold, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 28, 0.5, -4),
		ZIndex = 4,
	})
	statusTitle = Ui.text(status, "SEARCHING", "titleCard", {
		Position = UDim2.fromOffset(88, 14),
		Size = UDim2.fromOffset(380, 48),
		TextSize = 36,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 4,
	})
	statusSub = Ui.text(status, "", "bodyS", {
		Position = UDim2.fromOffset(90, 60),
		Size = UDim2.fromOffset(380, 20),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.textSecondary,
		ZIndex = 4,
	})
	statusTimer = Ui.text(status, "0:00", "numberHud", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -200, 0.5, -4),
		Size = UDim2.fromOffset(170, 80),
		TextSize = 60,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 4,
	})
	local track = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 24, 1, -12),
		Size = UDim2.new(1, -48, 0, 4),
		BackgroundColor3 = C.raised,
		BorderSizePixel = 0,
		ZIndex = 4,
	}, status)
	statusFill = Ui.make("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = C.gold,
		BorderSizePixel = 0,
		ZIndex = 5,
	}, track)
	local cancelHolder = Ui.make("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -24, 0.5, -4),
		Size = UDim2.fromOffset(150, 58),
		BackgroundTransparency = 1,
		ZIndex = 4,
	}, status)
	statusCancel = Ui.cut(cancelHolder, { Size = UDim2.fromScale(1, 1), ZIndex = 4 }, {
		className = "ImageButton",
		color = C.raised,
		line = C.lineStrong,
		corner = 12,
	})
	Ui.text(statusCancel, "CANCEL", "titleS", { Size = UDim2.fromScale(1, 1), ZIndex = 5 })
	Fx.button(statusCancel, function()
		QueueState.leave()
	end, {
		onHover = function(on)
			Fx.tween(statusCancel, 0.12, { ImageColor3 = if on then C.enemy else C.raised })
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
	statusSub.Text = if left > 0
		then `Looking for players  ·  bots fill empty slots in {Fx.clock(left + 0.999)}`
		else "Starting with bots..."
end

local function refreshAction()
	local s = QueueState.status()
	local mode = QueueState.mode()
	local idle = s == "idle"
	local switching = s == "searching" and mode ~= selected
	findHolder.Visible = idle or switching
	status.Visible = not idle and not switching
	findLabel.Text = if switching then `SWITCH TO {string.upper(selected)}` else "FIND MATCH"
	if s == "searching" then
		statusTitle.Text = `SEARCHING  ·  {string.upper(mode or "")}`
		statusTitle.TextColor3 = C.text
		statusCancel.Parent.Visible = true
		statusTimer.Position = UDim2.new(1, -200, 0.5, -4)
	elseif s == "found" or s == "teleporting" then
		statusTitle.Text = "MATCH FOUND"
		statusTitle.TextColor3 = C.ready
		statusSub.Text = if s == "teleporting" then "Teleporting..." else "Get ready"
		statusCancel.Parent.Visible = false
		statusTimer.Position = UDim2.new(1, -30, 0.5, -4)
		statusTimer.Text = ""
		statusFill.Size = UDim2.fromScale(1, 1)
	end
	if switching then
		findHolder.Position = UDim2.fromOffset(960, 790)
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
	gui.Enabled = true
	scrim.BackgroundTransparency = 1
	Fx.tween(scrim, 0.25, { BackgroundTransparency = 0.38 })
	content.GroupTransparency = 1
	Fx.tween(content, 0.25, { GroupTransparency = 0 })
	header.Position = UDim2.fromOffset(84, 120)
	Fx.tween(header, 0.4, { Position = UDim2.fromOffset(120, 120) })
	for i, card in cards do
		card.button.Position = UDim2.fromOffset(0, 48)
		task.delay((i - 1) * 0.05, function()
			Fx.tween(card.button, 0.36, { Position = UDim2.fromOffset(0, 0) })
			Sound.play("CardIn")
		end)
	end
	if not timerConn then
		timerConn = RunService.Heartbeat:Connect(updateTimer)
	end
end

local function animateOut()
	if not isOpen then
		return
	end
	isOpen = false
	for _, card in cards do
		Fx.tween(
			card.button,
			0.15,
			{ Position = UDim2.fromOffset(0, 24) },
			Enum.EasingStyle.Quint,
			Enum.EasingDirection.In
		)
	end
	Fx.tween(
		content,
		0.15,
		{ GroupTransparency = 1 },
		Enum.EasingStyle.Quint,
		Enum.EasingDirection.In
	)
	Fx.tween(
		scrim,
		0.18,
		{ BackgroundTransparency = 1 },
		Enum.EasingStyle.Quint,
		Enum.EasingDirection.In
	)
	if timerConn then
		timerConn:Disconnect()
		timerConn = nil
	end
	task.delay(0.2, function()
		if not isOpen then
			gui.Enabled = false
		end
	end)
end

local function buildMenu()
	gui = Ui.make("ScreenGui", {
		Name = "LobbyQueue",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 20,
		Enabled = false,
	}, player:WaitForChild("PlayerGui"))
	scrim = Ui.make("TextButton", {
		Name = "Scrim",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.scrim,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		Modal = true,
		Selectable = false,
	}, gui)
	-- Vignette: dark bands fading in from the top and bottom edges.
	for _, top in { true, false } do
		local band = Ui.make("Frame", {
			AnchorPoint = Vector2.new(0, if top then 0 else 1),
			Position = UDim2.fromScale(0, if top then 0 else 1),
			Size = UDim2.fromScale(1, 0.3),
			BackgroundColor3 = C.scrim,
			BorderSizePixel = 0,
		}, scrim)
		Ui.make("UIGradient", {
			Rotation = if top then 90 else -90,
			Transparency = NumberSequence.new(0.15, 1),
		}, band)
	end
	content = Ui.make("CanvasGroup", {
		Name = "Content",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(1920, 1080),
		BackgroundTransparency = 1,
	}, gui)
	Ui.fit(content)

	header = Ui.make("Frame", {
		Position = UDim2.fromOffset(120, 120),
		Size = UDim2.fromOffset(900, 110),
		BackgroundTransparency = 1,
	}, content)
	Ui.make("Frame", {
		Position = UDim2.fromOffset(0, 6),
		Size = UDim2.fromOffset(4, 92),
		BackgroundColor3 = C.gold,
		BorderSizePixel = 0,
	}, header)
	Ui.text(header, "PLAY  ·  CASUAL DUELS", "label", {
		Position = UDim2.fromOffset(22, 4),
		Size = UDim2.fromOffset(600, 18),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.gold,
		TextSize = 15,
	})
	Ui.text(header, "CHOOSE YOUR FIGHT", "displayL", {
		Position = UDim2.fromOffset(20, 26),
		Size = UDim2.fromOffset(800, 64),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	closeButton(content)

	for i, info in Config.MODES do
		buildCard(info, i)
	end
	buildAction()

	Ui.text(
		content,
		"1 / 2 / 3  choose      ENTER  find match      BACKSPACE  back      Keep moving while you search: close this menu any time.",
		"label",
		{
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromOffset(960, 924),
			Size = UDim2.fromOffset(1400, 20),
			TextColor3 = C.textDim,
		}
	)
end

--------------------------------------------------------------------------------
-- MATCH FOUND

local function slot(parent: Instance, userId: number?, color: Color3, order: number)
	local f = Ui.make("Frame", {
		Size = UDim2.fromOffset(120, 160),
		BackgroundTransparency = 1,
		LayoutOrder = order,
	}, parent)
	local card = Ui.cut(f, { Size = UDim2.fromOffset(120, 120) }, {
		color = if userId then C.raised else C.panel,
		line = color,
		lineTransparency = if userId then 0 else 0.6,
		corner = 14,
	})
	local name = "BOT"
	if userId then
		local p = Players:GetPlayerByUserId(userId)
		name = if p then p.DisplayName else "Player"
		local img = Ui.make("ImageLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 2,
		}, card)
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
		Ui.text(
			card,
			"BOT",
			"displayM",
			{ Size = UDim2.fromScale(1, 1), TextColor3 = C.textDim, ZIndex = 4 }
		)
	end
	Ui.text(f, name, "bodyM", {
		Position = UDim2.fromOffset(0, 128),
		Size = UDim2.fromOffset(120, 24),
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextColor3 = if userId == player.UserId then C.gold else C.text,
	})
	local s = Fx.scale(f)
	s.Scale = 0.6
	task.delay(0.25 + order * 0.06, function()
		Fx.tween(s, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
		Sound.play("CardIn")
	end)
end

local function buildFound()
	foundGui = Ui.make("ScreenGui", {
		Name = "LobbyMatchFound",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 30,
		Enabled = false,
	}, player:WaitForChild("PlayerGui"))
	foundBand = Ui.make("Frame", {
		Name = "Band",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundColor3 = C.scrim,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, foundGui)
	for _, y in { 0, 1 } do
		Ui.make("Frame", {
			AnchorPoint = Vector2.new(0, y),
			Position = UDim2.fromScale(0, y),
			Size = UDim2.new(1, 0, 0, 3),
			BackgroundColor3 = C.gold,
			BorderSizePixel = 0,
			ZIndex = 3,
		}, foundBand)
	end
	local inner = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(1920, 520),
		BackgroundTransparency = 1,
	}, foundBand)
	Ui.fit(inner)
	foundTitle = Ui.text(inner, "MATCH FOUND", "displayXL", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(960, 18),
		Size = UDim2.fromOffset(1200, 140),
		TextColor3 = C.gold,
		ZIndex = 4,
	})
	foundMode = Ui.text(inner, "", "titleS", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(960, 154),
		Size = UDim2.fromOffset(800, 28),
		TextColor3 = C.textSecondary,
		ZIndex = 4,
	})
	foundTeams = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(960, 200),
		Size = UDim2.fromOffset(1400, 170),
		BackgroundTransparency = 1,
		ZIndex = 4,
	}, inner)
	Ui.make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Top,
		Padding = UDim.new(0, 18),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, foundTeams)
	foundCountdown = Ui.text(inner, "", "titleS", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(960, 392),
		Size = UDim2.fromOffset(800, 30),
		TextSize = 26,
		ZIndex = 4,
	})
	foundStudio = Ui.text(inner, "", "bodyS", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(960, 430),
		Size = UDim2.fromOffset(1500, 70),
		FontFace = MONO,
		TextSize = 15,
		TextWrapped = true,
		TextColor3 = C.ally,
		Visible = false,
		ZIndex = 4,
	})
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
			local vs = Ui.make("Frame", {
				Size = UDim2.fromOffset(110, 120),
				BackgroundTransparency = 1,
				LayoutOrder = order,
			}, foundTeams)
			Ui.text(
				vs,
				"VS",
				"displayL",
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
	Fx.tween(foundBand, 0.26, { Size = UDim2.new(1, 0, 0, 540) })
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
		while foundToken == token and foundOpen do
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
			foundCountdown.TextColor3 = C.ally
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
	Router.register("Queue", { open = animateIn, close = animateOut })
end

function QueueMenu.start()
	LobbyNet.event("QueueEvent").OnClientEvent:Connect(onQueueEvent)
	QueueState.onChanged(function()
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
