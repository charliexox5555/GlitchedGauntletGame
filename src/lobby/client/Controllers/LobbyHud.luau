--!strict
-- The lobby HUD (vault/01 Design/Lobby UI and Queue.md): a top bar (profile and
-- level on the left; currency and settings on the right), a bottom bar of
-- tiles (Locker, Shop, PLAY, Battle Pass, Range) that open menus through the
-- Router, the "searching" pill while you're queued with the menu closed, and
-- toasts. Desktop layout is the Figma 1920 x 1080 frame; phones (short side
-- under 520 px) get their own arrangement on an 800 x 420 canvas: compact
-- tiles that clear the thumbstick and jump zones, a slimmer profile, the pill
-- under the top bar, and the HUD hidden behind open menus (LihFolk: HUD Design,
-- Responsive UI for Phone Tablet Console and PC). Each cluster has one Fit
-- UIScale from Util/Layout, which also keeps drawn text at 12 px or more.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Theme = require(ReplicatedStorage.Shared.Config.Theme)

local Fx = require(script.Parent.Parent.Util.Fx)
local Icons = require(script.Parent.Parent.Util.Icons)
local Layout = require(script.Parent.Parent.Util.Layout)
local QueueState = require(script.Parent.Parent.Util.QueueState)
local Router = require(script.Parent.Parent.Util.Router)
local Sound = require(script.Parent.Parent.Util.Sound)
local Ui = require(script.Parent.Parent.SharedUi)

local LobbyHud = {}

local C = Theme.COLORS
local player = Players.LocalPlayer

type Tile = { id: string, label: string, short: string?, menu: string, icon: string? }

local TILES: { Tile } = {
	{ id = "Locker", label = "LOCKER", menu = "Locker", icon = "Locker" },
	{ id = "Shop", label = "SHOP", menu = "Shop", icon = "Shop" },
	{ id = "Play", label = "PLAY", menu = "Queue" },
	{
		id = "BattlePass",
		label = "BATTLE PASS",
		short = "PASS",
		menu = "BattlePass",
		icon = "BattlePass",
	},
	{ id = "Range", label = "RANGE", menu = "Range", icon = "Range" },
}

local gui: ScreenGui
local topLeft: Frame
local topRight: Frame
local bottom: Frame
local pill: ImageButton
local toastFrame: ImageLabel
local toastText: TextLabel
local toastStrip: Frame

local play: {
	button: ImageButton,
	glow: ImageLabel,
	title: TextLabel,
	sub: TextLabel,
	spinner: Frame,
	glowTween: Tween?,
}
local pillTitle: TextLabel
local pillSub: TextLabel
local pillTimer: TextLabel
local pillCancel: ImageButton
local pillSpinner: Frame

local timerConn: RBXScriptConnection? = nil
local bottomShade: Frame? = nil
local lastSecond = -1
local toastToken = 0

local BOTTOM_SHOWN = UDim2.new(0.5, 0, 1, -20)
local BOTTOM_HIDDEN = UDim2.new(0.5, 0, 1, 220)
local PHONE = Layout.isPhone()
-- Phone: the pill sits under the profile and wallet instead of between them.
local PILL_SHOWN = UDim2.new(0.5, 0, 0, 14)
local TILE_W, TILE_H = Layout.pick(168, 96), Layout.pick(104, 84)
local PLAY_W, PLAY_H = Layout.pick(320, 168), Layout.pick(124, 96)
local TITLE_PLAY = Layout.pick(56, 40)
local TITLE_SEARCH = Layout.pick(48, 26)
local TITLE_FOUND = Layout.pick(40, 22)
local PILL_HIDDEN = UDim2.new(0.5, 0, 0, -120)

local function modeTitle(mode: string?): string
	return if mode then string.upper(mode) else ""
end

--------------------------------------------------------------------------------
-- Top bar

local function buildProfile()
	topLeft = Ui.make("Frame", {
		Name = "Profile",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromOffset(20, 14),
		Size = UDim2.fromOffset(Layout.pick(420, 240), 80),
		BackgroundTransparency = 1,
	}, gui)
	Layout.fit(topLeft, "hud")
	local card = Ui.cut(topLeft, { Size = UDim2.fromScale(1, 1) }, {
		color = C.panel,
		transparency = 0.12,
		line = C.lineSoft,
		corner = 14,
	})
	local frame = Ui.make("Frame", {
		Position = UDim2.fromOffset(9, 9),
		Size = UDim2.fromOffset(62, 62),
		BackgroundColor3 = C.raised,
		BorderSizePixel = 0,
		ZIndex = 4,
	}, card)
	Ui.make("UIStroke", { Color = C.lineStrong, Thickness = 1.5 }, frame)
	local headshot = Ui.make("ImageLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 5,
	}, frame)
	task.spawn(function()
		local ok, image = pcall(
			Players.GetUserThumbnailAsync,
			Players,
			player.UserId,
			Enum.ThumbnailType.HeadShot,
			Enum.ThumbnailSize.Size150x150
		)
		if ok then
			headshot.Image = image
		end
	end)
	Ui.text(card, player.DisplayName, "titleS", {
		Position = UDim2.fromOffset(86, 10),
		Size = UDim2.fromOffset(Layout.pick(310, 144), 28),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 4,
	})
	-- Level and XP: placeholders until progression exists.
	local level = Ui.make("Frame", {
		Position = UDim2.fromOffset(86, 44),
		Size = UDim2.fromOffset(44, 24),
		BackgroundColor3 = C.gold,
		BorderSizePixel = 0,
		ZIndex = 4,
	}, card)
	Ui.text(level, "LV 1", "label", {
		Size = UDim2.fromScale(1, 1),
		TextColor3 = C.onAccent,
		ZIndex = 5,
	})
	local bar = Ui.make("Frame", {
		Position = UDim2.fromOffset(140, 53),
		Size = UDim2.fromOffset(190, 6),
		Visible = not PHONE,
		BackgroundColor3 = C.raised,
		BorderSizePixel = 0,
		ZIndex = 4,
	}, card)
	Ui.make("Frame", {
		Size = UDim2.fromScale(0.04, 1),
		BackgroundColor3 = C.gold,
		BorderSizePixel = 0,
		ZIndex = 5,
	}, bar)
	Ui.text(card, "0 XP", "label", {
		Visible = not PHONE,
		Position = UDim2.fromOffset(340, 45),
		Size = UDim2.fromOffset(70, 20),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.textDim,
		ZIndex = 4,
	})
end

local function squareButton(parent: Instance, size: number, order: number): ImageButton
	local holder = Ui.make("Frame", {
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		LayoutOrder = order,
	}, parent)
	local button = Ui.cut(holder, { Size = UDim2.fromScale(1, 1) }, {
		className = "ImageButton",
		color = C.panel,
		transparency = 0.12,
		line = C.lineSoft,
		corner = 12,
	})
	return button
end

local function buildTopRight()
	topRight = Ui.make("Frame", {
		Name = "Wallet",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 14),
		Size = UDim2.fromOffset(320, 80),
		BackgroundTransparency = 1,
	}, gui)
	Layout.fit(topRight, "hud")
	Ui.make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, topRight)

	-- Currency chip (placeholder until the economy exists): coin, amount, "+".
	local chipHolder = Ui.make("Frame", {
		Size = UDim2.fromOffset(196, 60),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
	}, topRight)
	local chip = Ui.cut(chipHolder, { Size = UDim2.fromScale(1, 1) }, {
		className = "ImageButton",
		color = C.panel,
		transparency = 0.12,
		line = C.lineSoft,
		corner = 12,
	})
	Icons.draw(chip, "Coin", 30, C.gold, { Position = UDim2.fromOffset(14, 15), ZIndex = 4 })
	Ui.text(chip, "0", "titleS", {
		Position = UDim2.fromOffset(54, 0),
		Size = UDim2.fromOffset(80, 60),
		TextSize = 30,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 4,
	})
	local plus = Ui.make("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(32, 32),
		BackgroundColor3 = C.gold,
		BorderSizePixel = 0,
		ZIndex = 4,
	}, chip)
	Ui.text(plus, "+", "titleS", {
		Size = UDim2.fromScale(1, 1),
		TextSize = 28,
		TextColor3 = C.onAccent,
		ZIndex = 5,
	})
	local chipShine = Fx.shine(chip, C.gold, 0.2)
	Fx.button(chip, function()
		Router.open("Shop")
	end, {
		shine = chipShine,
		onHover = function(on)
			Fx.tween(chip, 0.15, { ImageColor3 = if on then C.hover else C.panel })
		end,
	})

	local gear = squareButton(topRight, 60, 2)
	local icon = Icons.draw(gear, "Settings", 28, C.textSecondary, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		ZIndex = 4,
	})
	Fx.button(gear, function()
		Router.toggle("Settings")
	end, {
		onHover = function(on)
			Fx.tween(gear, 0.15, { ImageColor3 = if on then C.hover else C.panel })
			Fx.tween(icon, 0.35, { Rotation = if on then 60 else 0 }, Enum.EasingStyle.Back)
		end,
	})
end

--------------------------------------------------------------------------------
-- Bottom bar

local function sideTile(tile: Tile, order: number)
	local holder = Ui.make("Frame", {
		Name = tile.id,
		Size = UDim2.fromOffset(TILE_W, TILE_H),
		BackgroundTransparency = 1,
		LayoutOrder = order,
	}, bottom)
	local button = Ui.cut(holder, { Size = UDim2.fromScale(1, 1) }, {
		className = "ImageButton",
		color = C.panel,
		transparency = 0.1,
		line = C.lineSoft,
		corner = 16,
	})
	local accent = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(0, 3),
		BackgroundColor3 = C.gold,
		BorderSizePixel = 0,
		ZIndex = 6,
	}, button)
	local icon = Icons.draw(button, tile.icon or tile.id, Layout.pick(38, 30), C.textSecondary, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(TILE_W / 2, Layout.pick(16, 12)),
		ZIndex = 4,
	})
	local label =
		Ui.text(button, if PHONE then tile.short or tile.label else tile.label, "titleS", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromOffset(TILE_W / 2, TILE_H - 40),
			Size = UDim2.fromOffset(TILE_W - 8, 26),
			TextColor3 = C.textSecondary,
			ZIndex = 4,
		})
	local shine = Fx.shine(button)
	local iconBase = icon.Position
	Fx.button(button, function()
		Router.toggle(tile.menu)
	end, {
		lift = button,
		shine = shine,
		onHover = function(on)
			Fx.tween(button, 0.15, { ImageColor3 = if on then C.hover else C.panel })
			Fx.tween(accent, 0.2, { Size = UDim2.new(if on then 0.55 else 0, 0, 0, 3) })
			Fx.tween(label, 0.15, { TextColor3 = if on then C.text else C.textSecondary })
			Fx.tween(icon, 0.25, {
				Position = if on then iconBase + UDim2.fromOffset(0, -2) else iconBase,
			}, Enum.EasingStyle.Back)
			for _, d in icon:GetDescendants() do
				if d:IsA("Frame") and d.BackgroundTransparency < 1 and d.Name ~= "Hole" then
					Fx.tween(d, 0.15, { BackgroundColor3 = if on then C.text else C.textSecondary })
				elseif d:IsA("ImageLabel") then
					Fx.tween(d, 0.15, { ImageColor3 = if on then C.text else C.textSecondary })
				elseif d:IsA("UIStroke") then
					Fx.tween(d, 0.15, { Color = if on then C.text else C.textSecondary })
				end
			end
		end,
	})
end

local function playTile(order: number)
	local holder = Ui.make("Frame", {
		Name = "Play",
		Size = UDim2.fromOffset(PLAY_W, PLAY_H),
		BackgroundTransparency = 1,
		LayoutOrder = order,
	}, bottom)
	local glow = Ui.cut(holder, {
		Name = "Glow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 16, 1, 16),
	}, { color = C.gold, transparency = 0.8, corner = 22 })
	local button = Ui.cut(holder, { Size = UDim2.fromScale(1, 1), ZIndex = 2 }, {
		className = "ImageButton",
		color = C.gold,
		corner = 22,
	})
	local title = Ui.text(button, "PLAY", "displayL", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, Layout.pick(14, 8)),
		Size = UDim2.fromOffset(PLAY_W - 20, Layout.pick(64, 48)),
		TextSize = TITLE_PLAY,
		TextColor3 = C.onAccent,
		ZIndex = 4,
	})
	local sub = Ui.text(button, "1V1  ·  2V2  ·  3V3", "label", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, Layout.pick(84, 60)),
		Size = UDim2.fromOffset(PLAY_W - 20, 20),
		TextSize = 15,
		TextColor3 = C.onAccent,
		ZIndex = 4,
	})
	local spinner = Fx.spinner(button, 30, C.gold, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 22, 0.5, 0),
		Visible = false,
		ZIndex = 4,
	})
	local shine = Fx.shine(button, C.white, 0.35)
	play = { button = button, glow = glow, title = title, sub = sub, spinner = spinner }
	play.glowTween =
		Fx.loop(glow, 1.3, { ImageTransparency = 0.55, Size = UDim2.new(1, 24, 1, 24) })
	Fx.button(button, function()
		Router.toggle("Queue")
	end, {
		lift = button,
		liftBy = 8,
		shine = shine,
		onHover = function(on)
			if on then
				Fx.glitch(title)
			end
		end,
	})
end

local function buildBottom()
	bottom = Ui.make("Frame", {
		Name = "Bar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = BOTTOM_SHOWN,
		Size = UDim2.fromOffset(1220, 140),
		BackgroundTransparency = 1,
	}, gui)
	Layout.fit(bottom, "hud")
	Ui.make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		Padding = UDim.new(0, Layout.pick(14, 8)),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, bottom)
	for i, tile in TILES do
		if tile.id == "Play" then
			playTile(i)
		else
			sideTile(tile, i)
		end
	end
end

--------------------------------------------------------------------------------
-- Searching pill and toasts

local function buildPill()
	local holder = Ui.make("Frame", {
		Name = "Searching",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = PILL_HIDDEN,
		Size = UDim2.fromOffset(560, 76),
		BackgroundTransparency = 1,
		Visible = false,
	}, gui)
	Layout.fit(holder, "hud")
	pill = Ui.cut(holder, { Name = "Pill", Size = UDim2.fromScale(1, 1) }, {
		className = "ImageButton",
		color = C.panel,
		transparency = 0.06,
		line = C.gold,
		lineTransparency = 0.4,
		corner = 16,
	})
	pillSpinner = Fx.spinner(pill, 32, C.gold, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 20, 0.5, 0),
		ZIndex = 4,
	})
	pillTitle = Ui.text(pill, "SEARCHING", "titleS", {
		Position = UDim2.fromOffset(66, 12),
		Size = UDim2.fromOffset(260, 26),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 4,
	})
	pillSub = Ui.text(pill, "", "bodyS", {
		Position = UDim2.fromOffset(66, 42),
		Size = UDim2.fromOffset(260, 20),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.textSecondary,
		ZIndex = 4,
	})
	pillTimer = Ui.text(pill, "0:00", "timer", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -140, 0.5, 0),
		Size = UDim2.fromOffset(110, 50),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextSize = 38,
		ZIndex = 4,
	})
	local cancelHolder = Ui.make("Frame", {
		Name = "CancelHolder",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(112, 60), -- 44+ px drawn at the 0.76 floor
		BackgroundTransparency = 1,
		ZIndex = 4,
	}, pill)
	pillCancel = Ui.cut(
		cancelHolder,
		{ Name = "Cancel", Size = UDim2.fromScale(1, 1), ZIndex = 4 },
		{
			className = "ImageButton",
			color = C.raised,
			line = C.lineStrong,
			corner = 10,
		}
	)
	Ui.text(
		pillCancel,
		"CANCEL",
		"label",
		{ Size = UDim2.fromScale(1, 1), TextSize = 14, ZIndex = 5 }
	)
	Fx.button(pillCancel, function()
		QueueState.leave()
	end, {
		onHover = function(on)
			Fx.tween(pillCancel, 0.12, { ImageColor3 = if on then C.enemy else C.raised })
		end,
	})
	Fx.button(pill, function()
		Router.open("Queue")
	end, { silent = false })
end

local function buildToast()
	local holder = Ui.make("Frame", {
		Name = "Toast",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 104),
		Size = UDim2.fromOffset(620, 60),
		BackgroundTransparency = 1,
	}, gui)
	Layout.fit(holder, "hud")
	toastFrame = Ui.cut(holder, { Size = UDim2.fromScale(1, 1), Visible = false }, {
		color = C.panel,
		transparency = 0.05,
		line = C.lineStrong,
		corner = 12,
	})
	toastStrip = Ui.make("Frame", {
		Size = UDim2.new(0, 6, 1, -16),
		Position = UDim2.fromOffset(12, 8),
		BackgroundColor3 = C.enemy,
		BorderSizePixel = 0,
		ZIndex = 4,
	}, toastFrame)
	toastText = Ui.text(toastFrame, "", "bodyM", {
		Position = UDim2.fromOffset(32, 0),
		Size = UDim2.new(1, -48, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		ZIndex = 4,
	})
end

-- A short message under the top bar. kind: "error" (red strip) or "info".
function LobbyHud.toast(text: string, kind: string?)
	toastToken += 1
	local token = toastToken
	toastText.Text = text
	toastStrip.BackgroundColor3 = if kind == "error" then C.enemy else C.ally
	toastFrame.Visible = true
	toastFrame.Position = UDim2.fromOffset(0, -16)
	toastFrame.ImageTransparency = 1
	toastText.TextTransparency = 1
	Fx.tween(toastFrame, 0.25, { Position = UDim2.fromOffset(0, 0), ImageTransparency = 0.05 })
	Fx.tween(toastText, 0.25, { TextTransparency = 0 })
	Sound.play(if kind == "error" then "Denied" else "Banner")
	task.delay(5, function()
		if toastToken ~= token then
			return
		end
		Fx.tween(
			toastFrame,
			0.18,
			{ Position = UDim2.fromOffset(0, -16), ImageTransparency = 1 },
			Enum.EasingStyle.Quint,
			Enum.EasingDirection.In
		)
		Fx.tween(toastText, 0.18, { TextTransparency = 1 })
		task.wait(0.2)
		if toastToken == token then
			toastFrame.Visible = false
		end
	end)
end

--------------------------------------------------------------------------------
-- State

local function updateTimers()
	local status = QueueState.status()
	if status == "searching" then
		local elapsed = QueueState.elapsed()
		local second = math.floor(elapsed)
		if second == lastSecond then
			return
		end
		lastSecond = second
		local left = QueueState.botFillAfter() - elapsed
		pillTimer.Text = Fx.clock(elapsed)
		pillSub.Text = if left > 0
			then `Bots fill in {Fx.clock(left + 0.999)}`
			else "Starting with bots..."
		play.sub.Text = `{modeTitle(QueueState.mode())}  ·  {Fx.clock(elapsed)}`
	elseif status == "found" then
		local left = math.ceil(QueueState.startsIn())
		pillTimer.Text = if left > 0 then tostring(left) else ""
	end
end

local function refresh()
	local status = QueueState.status()
	local mode = QueueState.mode()
	local queueOpen = Router.current() == "Queue"
	lastSecond = -1

	-- Play tile.
	if status == "idle" then
		play.title.Text = "PLAY"
		play.title.TextColor3 = C.onAccent
		play.title.Position = UDim2.new(0.5, 0, 0, Layout.pick(14, 8))
		play.sub.Text = Layout.pick("1V1  ·  2V2  ·  3V3", "1V1 · 2V2 · 3V3")
		play.sub.TextColor3 = C.onAccent
		play.button.ImageColor3 = C.gold
		play.spinner.Visible = false
		play.glow.ImageColor3 = C.gold
	else
		local found = status ~= "searching"
		play.title.Text = if found then "MATCH FOUND" else "SEARCHING"
		play.title.TextColor3 = if found then C.ready else C.gold
		play.title.Position = UDim2.new(0.5, Layout.pick(18, 14), 0, Layout.pick(14, 12))
		play.title.TextSize = if found then TITLE_FOUND else TITLE_SEARCH
		play.sub.TextColor3 = C.textSecondary
		play.sub.Text = modeTitle(mode)
		play.button.ImageColor3 = C.panel
		play.spinner.Visible = true
		play.glow.ImageColor3 = if found then C.ready else C.gold
	end
	if status == "idle" then
		play.title.TextSize = TITLE_PLAY
	end

	-- Pill.
	local showPill = status ~= "idle" and not queueOpen
	local holder = pill.Parent :: Frame
	if showPill and not holder.Visible then
		holder.Visible = true
		holder.Position = PILL_HIDDEN
		-- Phone: under the profile card (its drawn height), not between the clusters.
		local shown = if PHONE
			then UDim2.new(
				0.5,
				0,
				0,
				topLeft.AbsolutePosition.Y - gui.AbsolutePosition.Y + topLeft.AbsoluteSize.Y + 8
			)
			else PILL_SHOWN
		Fx.tween(holder, Fx.MOTION.enter, { Position = shown })
	elseif not showPill and holder.Visible then
		Fx.out(holder, { Position = PILL_HIDDEN })
		task.delay(Fx.MOTION.exit + 0.02, function()
			if Router.current() == "Queue" or QueueState.status() == "idle" then
				holder.Visible = false
			end
		end)
	end
	local found = status == "found" or status == "teleporting"
	pillTitle.Text = if found
		then `MATCH FOUND  ·  {modeTitle(mode)}`
		else `SEARCHING  ·  {modeTitle(mode)}`
	pillTitle.TextColor3 = if found then C.ready else C.text
	if status == "teleporting" then
		pillSub.Text = "Teleporting..."
	elseif status == "found" then
		pillSub.Text = "Get ready"
	end
	pillCancel.Parent.Visible = status == "searching"
	pillTimer.Position = UDim2.new(1, if status == "searching" then -140 else -24, 0.5, 0)
	local _ = pillSpinner

	-- Live timer only while queued.
	if status ~= "idle" and not timerConn then
		timerConn = RunService.Heartbeat:Connect(updateTimers)
	elseif status == "idle" and timerConn then
		timerConn:Disconnect()
		timerConn = nil
	end
	updateTimers()
end

local function onMenuChanged(name: string?)
	local open = name ~= nil
	if bottomShade then
		bottomShade.Visible = not open
	end
	if open then
		Fx.out(bottom, { Position = BOTTOM_HIDDEN })
	else
		Fx.tween(bottom, Fx.MOTION.enter, { Position = BOTTOM_SHOWN })
	end
	-- Phones: the whole HUD steps aside for an open menu (LihFolk: HUD Design).
	if PHONE then
		topLeft.Visible = not open
		topRight.Visible = not open
	end
	refresh()
end

-- Entrance: the bars slide in, the tiles rise one after another.
local function intro()
	topLeft.Position = UDim2.fromOffset(20, -110)
	topRight.Position = UDim2.new(1, -20, 0, -110)
	Fx.tween(topLeft, Fx.MOTION.reveal, { Position = UDim2.fromOffset(20, 14) })
	Fx.tween(topRight, Fx.MOTION.reveal, { Position = UDim2.new(1, -20, 0, 14) })
	for i, tile in TILES do
		local holder = bottom:FindFirstChild(tile.id)
		local button = holder and holder:FindFirstChildWhichIsA("ImageButton")
		if button then
			local base = Fx.base(button)
			button.Position = base + UDim2.fromOffset(0, 160)
			task.delay(0.1 + i * Fx.MOTION.stagger, function()
				Fx.tween(button, Fx.MOTION.reveal, { Position = base }, Enum.EasingStyle.Back)
			end)
		end
	end
end

function LobbyHud.init()
	gui = Ui.make("ScreenGui", {
		Name = "LobbyHud",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		DisplayOrder = 25, -- above menus (20) so the top bar stays; under Match Found (30)
	}, player:WaitForChild("PlayerGui"))
	-- Soft shade behind the bars so they read over a bright lobby.
	for _, top in { true, false } do
		local shade = Ui.make("Frame", {
			Name = if top then "ShadeTop" else "ShadeBottom",
			AnchorPoint = Vector2.new(0, if top then 0 else 1),
			Position = UDim2.fromScale(0, if top then 0 else 1),
			Size = UDim2.fromScale(1, if top then 0.14 else 0.24),
			BackgroundColor3 = C.scrim,
			BorderSizePixel = 0,
			ZIndex = 0,
		}, gui)
		Ui.make("UIGradient", {
			Rotation = if top then 90 else -90,
			Transparency = NumberSequence.new(if top then 0.6 else 0.45, 1),
		}, shade)
		if not top then
			bottomShade = shade
		end
	end
	buildProfile()
	buildTopRight()
	buildBottom()
	buildPill()
	buildToast()
end

function LobbyHud.start()
	Sound.preload()
	QueueState.onChanged(refresh)
	Router.onChanged(onMenuChanged)
	refresh()
	intro()
end

return LobbyHud
