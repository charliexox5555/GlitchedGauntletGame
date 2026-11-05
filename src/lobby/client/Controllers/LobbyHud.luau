--!strict
-- The lobby HUD, v2 (vault/01 Design/Lobby UI and Queue.md section 8; Figma
-- "Lobby v2 · HUD 1920x1080" and "· HUD phone 667x375").
-- * Top row IN Roblox's top-bar strip (a TopbarSafeInsets gui, so it sits
--   beside Roblox's buttons and moves with them): profile chip on the left,
--   wallet and settings on the right, 44 px like Roblox's own buttons. With no
--   top bar (console), the row drops to the core-UI safe area's top edge.
-- * Bottom dock: LOCKER · SHOP · PLAY · BATTLE PASS · RANGE, opening menus
--   through the Router. Desktop shows the "searching" pill above the dock;
--   phones under the top bar. Toasts sit above the dock, or at the top while a
--   menu is open. Nothing interactive lives where Roblox's chat (top left) or
--   player list (top right) draw (LihFolk: Safe Areas and Insets).
-- * Edge-to-edge shades in their own ScreenInsets.None gui.
-- Every colour and size comes from Util/Style; shapes from Util/Kit.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Fx = require(script.Parent.Parent.Util.Fx)
local Icons = require(script.Parent.Parent.Util.Icons)
local Kit = require(script.Parent.Parent.Util.Kit)
local Layout = require(script.Parent.Parent.Util.Layout)
local QueueState = require(script.Parent.Parent.Util.QueueState)
local Router = require(script.Parent.Parent.Util.Router)
local Sound = require(script.Parent.Parent.Util.Sound)
local Style = require(script.Parent.Parent.Util.Style)

local LobbyHud = {}

local C = Style.COLOR
local A = Style.ALPHA
local R = Style.RADIUS
local TB = Style.TOPBAR
local player = Players.LocalPlayer

local PHONE = Layout.isPhone()
local D = if PHONE then Style.DOCK.phone else Style.DOCK.desktop

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

local gui: ScreenGui -- dock, pill, toast (core-UI safe area)
local topGui: ScreenGui -- the row in Roblox's top bar
local topRow: Frame
local cluster: Frame -- bottom Fit cluster (dock + desktop pill)
local dock: Frame
local shadeTop: Frame
local shadeBottom: Frame

local play: {
	holder: Frame,
	face: TextButton,
	lip: Frame,
	glow: Kit.Glow,
	shade: UIGradient,
	stroke: UIStroke,
	title: TextLabel,
	sub: TextLabel,
	spinner: Frame,
	cancel: Frame?,
}
local pillHolder: Frame
local pill: TextButton
local pillTitle: TextLabel
local pillSub: TextLabel
local pillTimer: TextLabel
local pillCancel: TextButton
local toastHolder: Frame
local toastFrame: Frame
local toastText: TextLabel
local toastStrip: Frame

local timerConn: RBXScriptConnection? = nil
local lastSecond = -1
local dockShown = true
local toastToken = 0

local DOCK_W = 4 * D.tileW + D.playW + 4 * D.gap
local DOCK_SHOWN = UDim2.new(0.5, 0, 1, -D.bottom)
local DOCK_HIDDEN = UDim2.new(0.5, 0, 1, D.playH + 80)
local PILL_Y = D.bottom + D.playH + 20 -- desktop: above the dock
local TITLE_PLAY = Style.TEXT.play.size * (if PHONE then 0.62 else 1)

local function modeTitle(mode: string?): string
	return if mode then string.upper(mode) else ""
end

-- Tint every part of an icon (image or vector pieces).
local function tintIcon(icon: Frame, color: Color3, time: number)
	for _, d in icon:GetDescendants() do
		if d:IsA("ImageLabel") then
			Fx.tween(d, time, { ImageColor3 = color })
		elseif d:IsA("Frame") and d.BackgroundTransparency < 1 and d.Name ~= "Hole" then
			Fx.tween(d, time, { BackgroundColor3 = color })
		elseif d:IsA("UIStroke") then
			Fx.tween(d, time, { Color = color })
		end
	end
end

--------------------------------------------------------------------------------
-- Top row (Roblox top-bar strip)

local function chip(parent: Instance, name: string, className: string, order: number): any
	local c = Kit.surface(parent, {
		Name = name,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, TB.height),
		LayoutOrder = order,
	}, { className = className, radius = R.pill, transparency = A.chip })
	Kit.make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, c)
	Kit.make("UIPadding", {
		PaddingLeft = UDim.new(0, 4),
		PaddingRight = UDim.new(0, 6),
	}, c)
	return c
end

local function group(name: string, right: boolean)
	local g = Kit.make("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(if right then 1 else 0, 0.5),
		Position = UDim2.fromScale(if right then 1 else 0, 0.5),
		Size = UDim2.new(0.5, 0, 0, TB.height),
		BackgroundTransparency = 1,
	}, topRow)
	Kit.make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = if right
			then Enum.HorizontalAlignment.Right
			else Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, TB.gap),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, g)
	return g
end

local function buildProfile(left: Frame)
	local card = chip(left, "Profile", "Frame", 1)
	local head = Kit.make("ImageLabel", {
		Name = "Headshot",
		Size = UDim2.fromOffset(TB.headshot, TB.headshot),
		BackgroundColor3 = C.surfaceHover,
		BorderSizePixel = 0,
		LayoutOrder = 1,
	}, card)
	Kit.corner(head, R.pill)
	Kit.stroke(head, C.white, 0.5)
	task.spawn(function()
		local ok, image = pcall(
			Players.GetUserThumbnailAsync,
			Players,
			player.UserId,
			Enum.ThumbnailType.HeadShot,
			Enum.ThumbnailSize.Size150x150
		)
		if ok then
			head.Image = image
		end
	end)
	if not PHONE then
		-- Name over a thin XP track (placeholders until progression exists).
		local col = Kit.make("Frame", {
			Name = "NameXp",
			Size = UDim2.fromOffset(124, 34),
			BackgroundTransparency = 1,
			LayoutOrder = 2,
		}, card)
		Kit.text(col, player.DisplayName, "name", {
			Name = "Name",
			Size = UDim2.fromOffset(124, 20),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		local _, fill = Kit.track(col, {
			Position = UDim2.fromOffset(0, 26),
			Size = UDim2.fromOffset(112, 4),
		})
		fill.Size = UDim2.fromScale(0.06, 1)
	end
	local level = Kit.make("Frame", {
		Name = "Level",
		Size = UDim2.fromOffset(54, 30),
		BackgroundColor3 = C.white,
		BorderSizePixel = 0,
		LayoutOrder = 3,
	}, card)
	Kit.corner(level, R.pill)
	Kit.make(
		"UIGradient",
		{ Rotation = 90, Color = ColorSequence.new(C.primaryTop, C.primaryBottom) },
		level
	)
	Kit.text(level, "LV 1", "labelS", { Size = UDim2.fromScale(1, 1), TextColor3 = C.onPrimary })
end

local function buildWallet(right: Frame)
	-- Currency (placeholder until the economy exists): coin, amount, "+" → Shop.
	local wallet = chip(right, "Wallet", "TextButton", 1)
	Icons.draw(wallet, "Coin", TB.coin + 4, C.primary, { LayoutOrder = 1 })
	Kit.text(wallet, "0", "name", {
		Name = "Amount",
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, TB.height),
		TextSize = 18,
		LayoutOrder = 2,
	})
	local plus = Kit.make("Frame", {
		Name = "Plus",
		Size = UDim2.fromOffset(TB.coin + 4, TB.coin + 4),
		BackgroundColor3 = C.primary,
		BorderSizePixel = 0,
		LayoutOrder = 3,
	}, wallet)
	Kit.corner(plus, R.pill)
	for _, r in { 0, 90 } do
		local bar = Kit.make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(14, 3),
			Rotation = r,
			BackgroundColor3 = C.onPrimary,
			BorderSizePixel = 0,
		}, plus)
		Kit.corner(bar, 2)
	end
	local stroke = Kit.strokeOf(wallet)
	Fx.button(wallet, function()
		Router.open("Shop")
	end, {
		onHover = function(on)
			Fx.tween(
				wallet,
				Fx.MOTION.hover,
				{ BackgroundColor3 = if on then C.surfaceHover else C.surface }
			)
			Fx.tween(
				stroke,
				Fx.MOTION.hover,
				{ Transparency = if on then A.strokeHover else A.stroke }
			)
		end,
	})

	local gearHolder = Kit.make("Frame", {
		Name = "Settings",
		Size = UDim2.fromOffset(TB.height, TB.height),
		BackgroundTransparency = 1,
		LayoutOrder = 2,
	}, right)
	local gear = Kit.surface(gearHolder, {
		Name = "Button",
		Size = UDim2.fromScale(1, 1),
	}, { className = "TextButton", radius = R.pill, transparency = A.chip })
	local gearStroke = Kit.strokeOf(gear)
	local icon = Icons.draw(gear, "Settings", 24, C.textSecondary, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
	})
	Fx.button(gear, function()
		Router.toggle("Settings")
	end, {
		onHover = function(on)
			Fx.tween(
				gear,
				Fx.MOTION.hover,
				{ BackgroundColor3 = if on then C.surfaceHover else C.surface }
			)
			Fx.tween(
				gearStroke,
				Fx.MOTION.hover,
				{ Transparency = if on then A.strokeHover else A.stroke }
			)
			tintIcon(icon, if on then C.text else C.textSecondary, Fx.MOTION.hover)
			Fx.tween(icon, 0.35, { Rotation = if on then 60 else 0 }, Enum.EasingStyle.Back)
		end,
	})
end

-- Place the row from the live top-bar inset (LihFolk: Safe Areas and Insets:
-- never cache it). In Roblox's strip when there is one, else at the safe top.
local function layoutTopbar()
	local inset = GuiService.TopbarInset
	if inset.Height >= 30 then
		if topGui.ScreenInsets ~= Enum.ScreenInsets.TopbarSafeInsets then
			topGui.ScreenInsets = Enum.ScreenInsets.TopbarSafeInsets
		end
		topRow.AnchorPoint = Vector2.new(0, 0.5)
		topRow.Position = UDim2.new(0, TB.lead, 0.5, 0)
		topRow.Size = UDim2.new(1, -(TB.lead + TB.edge), 0, TB.height)
	else
		if topGui.ScreenInsets ~= Enum.ScreenInsets.CoreUISafeInsets then
			topGui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
		end
		topRow.AnchorPoint = Vector2.new(0, 0)
		topRow.Position = UDim2.fromOffset(TB.edge, TB.fallbackTop)
		topRow.Size = UDim2.new(1, -2 * TB.edge, 0, TB.height)
	end
	-- The top shade covers the strip plus a soft fade below it.
	shadeTop.Size = UDim2.new(1, 0, 0, math.max(inset.Max.Y, TB.fallbackTop + TB.height) + 90)
end

local function buildTopbar()
	topGui = Kit.make("ScreenGui", {
		Name = "LobbyTopBar",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ScreenInsets = Enum.ScreenInsets.TopbarSafeInsets,
		SafeAreaCompatibility = Enum.SafeAreaCompatibility.None,
		DisplayOrder = 25, -- above menus (20) so it stays; under MATCH FOUND (30)
	}, player:WaitForChild("PlayerGui"))
	topRow = Kit.make("Frame", { Name = "Row", BackgroundTransparency = 1 }, topGui)
	buildProfile(group("Left", false))
	buildWallet(group("Right", true))
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(layoutTopbar)
end

--------------------------------------------------------------------------------
-- Bottom dock

local function sideTile(tile: Tile, order: number)
	local holder = Kit.make("Frame", {
		Name = tile.id,
		Size = UDim2.fromOffset(D.tileW, D.tileH),
		BackgroundTransparency = 1,
		LayoutOrder = order,
	}, dock)
	local button = Kit.surface(holder, {
		Name = "Button",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
	}, { className = "TextButton", radius = D.radius })
	Kit.shadow(button, D.radius)
	local stroke = Kit.strokeOf(button)
	local icon = Icons.draw(button, tile.icon or tile.id, D.icon, C.textSecondary, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, if PHONE then 11 else 17),
		ZIndex = 3,
	})
	local label =
		Kit.text(button, if PHONE then tile.short or tile.label else tile.label, "label", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, if PHONE then -9 else -14),
			Size = UDim2.new(1, -8, 0, 20),
			TextColor3 = C.textSecondary,
			ZIndex = 3,
		})
	local accent = Kit.make("Frame", {
		Name = "Accent",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -4),
		Size = UDim2.fromOffset(0, 3),
		BackgroundColor3 = C.primary,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, button)
	Kit.corner(accent, 2)
	local shine = if Style.FLAGS.shine then Fx.shine(button, C.white, 0.1) else nil
	local iconBase = icon.Position
	Fx.button(button, function()
		Router.toggle(tile.menu)
	end, {
		lift = button,
		liftBy = 4,
		shine = shine,
		onHover = function(on)
			local t = Fx.MOTION.hover
			Fx.tween(button, t, { BackgroundColor3 = if on then C.surfaceHover else C.surface })
			Fx.tween(stroke, t, {
				Color = if on then C.primary else C.stroke,
				Transparency = if on then 0 else A.stroke,
			})
			Fx.tween(accent, Fx.MOTION.enter, { Size = UDim2.fromOffset(if on then 36 else 0, 3) })
			Fx.tween(label, t, { TextColor3 = if on then C.text else C.textSecondary })
			tintIcon(icon, if on then C.text else C.textSecondary, t)
			Fx.tween(icon, 0.25, {
				Position = if on then iconBase + UDim2.fromOffset(0, -2) else iconBase,
			}, Enum.EasingStyle.Back)
		end,
	})
end

local function setPlayLook(kind: "idle" | "searching" | "found")
	local idle = kind == "idle"
	local tint = if kind == "found" then C.success else C.primary
	play.shade.Color = if idle
		then ColorSequence.new(C.primaryTop, C.primaryBottom)
		else ColorSequence.new(C.surface, C.surface:Lerp(C.surfaceDeep, 0.6))
	play.lip.BackgroundColor3 = if idle then C.primaryLip else C.surfaceDeep
	play.stroke.Color = if idle then C.white else tint
	play.stroke.Transparency = if idle then A.strokeOnPrimary else 0.25
	play.glow.setColor(tint)
	play.spinner.Visible = not idle
	if play.cancel then
		play.cancel.Visible = kind == "searching"
	end
	play.title.TextColor3 = if idle then C.onPrimary else tint
	play.sub.TextColor3 = if idle then C.onPrimary else C.textSecondary
	play.sub.TextTransparency = if idle then 0.28 else 0
	local pad = if idle then 0 else (if PHONE then 14 else 22)
	play.title.Position = UDim2.new(0.5, pad, 0, if PHONE then 8 else 12)
	play.sub.Position = UDim2.new(0.5, pad, 1, if PHONE then -12 else -18)
end

local function playTile(order: number)
	local p = Kit.primary(dock, {
		Name = "Play",
		Size = UDim2.fromOffset(D.playW, D.playH),
		LayoutOrder = order,
	}, "PLAY", "play", D.playRadius)
	local title = p.label
	title.AnchorPoint = Vector2.new(0.5, 0)
	title.Size = UDim2.new(1, -24, 0, if PHONE then 40 else 62)
	title.TextSize = TITLE_PLAY
	local sub = Kit.text(p.face, "1V1  ·  2V2  ·  3V3", "labelS", {
		Name = "Sub",
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.new(1, -24, 0, 20),
		TextColor3 = C.onPrimary,
		ZIndex = 4,
	})
	local spinner = Fx.spinner(p.face, if PHONE then 24 else 30, C.primary, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, if PHONE then 12 else 20, 0.5, 0),
		Visible = false,
		ZIndex = 4,
	})
	play = {
		holder = p.holder,
		face = p.face,
		lip = p.lip,
		glow = p.glow,
		shade = Kit.shadeOf(p.face),
		stroke = Kit.strokeOf(p.face),
		title = title,
		sub = sub,
		spinner = spinner,
		cancel = nil,
	}
	-- Phones: no floating pill (Roblox's chat opens over the top of a phone
	-- screen); CANCEL is a badge on the PLAY tile while searching, 44+ px drawn.
	if PHONE then
		local badge = Kit.circle(p.holder, {
			Name = "CancelBadge",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -8, 0, 8),
			Visible = false,
			ZIndex = 6,
		}, Style.DOCK.phone.cancelBadge)
		badge.BackgroundColor3 = C.danger
		Kit.strokeOf(badge).Transparency = 0.5
		Kit.cross(badge, 20)
		Fx.button(badge, function()
			QueueState.leave()
		end)
		play.cancel = badge.Parent :: Frame
	end
	setPlayLook("idle")
	p.glow.breathe()
	Fx.button(p.face, function()
		Router.toggle("Queue")
	end, {
		shine = if Style.FLAGS.shine then Fx.shine(p.face, C.white, 0.3) else nil,
		onPress = p.press,
		onHover = function(on)
			if on then
				Fx.glitch(title)
			end
		end,
	})
end

local function buildDock()
	cluster = Kit.make("Frame", {
		Name = "Bottom",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromOffset(math.max(DOCK_W, D.pillW) + 48, PILL_Y + D.pillH + 24),
		BackgroundTransparency = 1,
	}, gui)
	Layout.fit(cluster, "hud")
	dock = Kit.make("Frame", {
		Name = "Bar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = DOCK_SHOWN,
		Size = UDim2.fromOffset(DOCK_W, D.playH + 12),
		BackgroundTransparency = 1,
	}, cluster)
	Kit.make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		Padding = UDim.new(0, D.gap),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, dock)
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

local PILL_HIDDEN_DESKTOP = UDim2.new(0.5, 0, 1, -PILL_Y + 40)
local PILL_SHOWN_DESKTOP = UDim2.new(0.5, 0, 1, -PILL_Y)
local PILL_HIDDEN_PHONE = UDim2.new(0.5, 0, 0, -90)
local PILL_SHOWN_PHONE = UDim2.new(0.5, 0, 0, 8)

local function buildPill()
	if PHONE then
		pillHolder = Kit.make("Frame", {
			Name = "Searching",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = PILL_HIDDEN_PHONE,
			Size = UDim2.fromOffset(D.pillW, D.pillH),
			BackgroundTransparency = 1,
			Visible = false,
		}, gui)
		Layout.fit(pillHolder, "hud")
	else
		pillHolder = Kit.make("Frame", {
			Name = "Searching",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = PILL_HIDDEN_DESKTOP,
			Size = UDim2.fromOffset(D.pillW, D.pillH),
			BackgroundTransparency = 1,
			Visible = false,
		}, cluster)
	end
	pill = Kit.surface(pillHolder, {
		Name = "Pill",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
	}, {
		className = "TextButton",
		radius = R.pill,
		stroke = C.primary,
		strokeTransparency = 0.45,
	})
	Kit.shadow(pill, R.pill)
	Fx.spinner(pill, 24, C.primary, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 18, 0.5, 0),
		ZIndex = 3,
	})
	pillTitle = Kit.text(pill, "SEARCHING", "label", {
		Position = UDim2.fromOffset(54, 11),
		Size = UDim2.fromOffset(230, 22),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
	})
	pillSub = Kit.text(pill, "", "bodyS", {
		Position = UDim2.fromOffset(54, 34),
		Size = UDim2.fromOffset(230, 20),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.textSecondary,
		ZIndex = 3,
	})
	pillTimer = Kit.text(pill, "0:00", "number", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -160, 0.5, 0),
		Size = UDim2.fromOffset(90, 34),
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 3,
	})
	local cancelHolder = Kit.make("Frame", {
		Name = "CancelHolder",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -6, 0.5, 0),
		Size = UDim2.fromOffset(140, D.pillH - 6), -- 58: 44+ px drawn at the 0.76 HUD floor
		BackgroundTransparency = 1,
		ZIndex = 3,
	}, pill)
	pillCancel = Kit.surface(cancelHolder, {
		Name = "Cancel",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
	}, {
		className = "TextButton",
		color = C.surfaceHover,
		radius = R.pill,
		strokeTransparency = 0.8,
	})
	Kit.text(pillCancel, "CANCEL", "labelS", { Size = UDim2.fromScale(1, 1), ZIndex = 4 })
	Fx.button(pillCancel, function()
		QueueState.leave()
	end, {
		onHover = function(on)
			Fx.tween(
				pillCancel,
				Fx.MOTION.hover,
				{ BackgroundColor3 = if on then C.danger else C.surfaceHover }
			)
		end,
	})
	Fx.button(pill, function()
		Router.open("Queue")
	end, { noScale = true })
end

local function buildToast()
	toastHolder = Kit.make("Frame", {
		Name = "Toast",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -200),
		Size = UDim2.fromOffset(620, 60),
		BackgroundTransparency = 1,
	}, gui)
	Layout.fit(toastHolder, "hud")
	toastFrame = Kit.surface(toastHolder, {
		Name = "Card",
		Size = UDim2.fromScale(1, 1),
		Visible = false,
	}, { radius = R.md, transparency = 0.02 })
	toastStrip = Kit.make("Frame", {
		Name = "Strip",
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.new(0, 4, 1, -24),
		BackgroundColor3 = C.danger,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, toastFrame)
	Kit.corner(toastStrip, 2)
	toastText = Kit.text(toastFrame, "", "body", {
		Position = UDim2.fromOffset(30, 0),
		Size = UDim2.new(1, -46, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		ZIndex = 3,
	})
end

-- Above the dock (and the pill), or at the top while a menu is open (chat and
-- the player list are hidden then).
local function placeToast()
	if Router.current() ~= nil then
		toastHolder.AnchorPoint = Vector2.new(0.5, 0)
		toastHolder.Position = UDim2.new(0.5, 0, 0, 12)
		return
	end
	local top = dock.AbsolutePosition.Y
	if pillHolder.Visible and not PHONE then
		top = math.min(top, pillHolder.AbsolutePosition.Y)
	end
	local fromBottom = gui.AbsolutePosition.Y + gui.AbsoluteSize.Y - top + 12
	toastHolder.AnchorPoint = Vector2.new(0.5, 1)
	toastHolder.Position = UDim2.new(0.5, 0, 1, -math.floor(fromBottom))
end

-- A short message. kind: "error" (red strip) or "info".
function LobbyHud.toast(text: string, kind: string?)
	toastToken += 1
	local token = toastToken
	placeToast()
	toastText.Text = text
	toastStrip.BackgroundColor3 = if kind == "error" then C.danger else C.info
	toastFrame.Visible = true
	toastFrame.Position = UDim2.fromOffset(0, 12)
	toastFrame.BackgroundTransparency = 1
	toastText.TextTransparency = 1
	Fx.tween(
		toastFrame,
		Fx.MOTION.enter,
		{ Position = UDim2.fromOffset(0, 0), BackgroundTransparency = 0.02 }
	)
	Fx.tween(toastText, Fx.MOTION.enter, { TextTransparency = 0 })
	Sound.play(if kind == "error" then "Denied" else "Banner")
	task.delay(5, function()
		if toastToken ~= token then
			return
		end
		Fx.out(toastFrame, { Position = UDim2.fromOffset(0, 12), BackgroundTransparency = 1 })
		Fx.out(toastText, { TextTransparency = 1 })
		task.wait(Fx.MOTION.exit + 0.02)
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

	-- PLAY tile.
	if status == "idle" then
		setPlayLook("idle")
		play.title.Text = "PLAY"
		play.title.TextSize = TITLE_PLAY
		play.sub.Text = "1V1  ·  2V2  ·  3V3"
	else
		local found = status ~= "searching"
		setPlayLook(if found then "found" else "searching")
		play.title.Text = if found then "MATCH FOUND" else "SEARCHING"
		play.title.TextSize = math.floor(TITLE_PLAY * (if found then 0.66 else 0.8))
		play.sub.Text = modeTitle(mode)
	end

	-- The dock steps aside while MATCH FOUND owns the screen.
	local dockAway = status == "found" or status == "teleporting" or Router.current() ~= nil
	if dockAway and dockShown then
		dockShown = false
		Fx.out(dock, { Position = DOCK_HIDDEN })
	elseif not dockAway and not dockShown then
		dockShown = true
		Fx.tween(dock, Fx.MOTION.enter, { Position = DOCK_SHOWN })
	end
	shadeBottom.Visible = not dockAway

	-- Pill: searching only (MATCH FOUND has its own full-width band).
	local showPill = status == "searching" and not queueOpen and not PHONE
	local shown = if PHONE then PILL_SHOWN_PHONE else PILL_SHOWN_DESKTOP
	local hidden = if PHONE then PILL_HIDDEN_PHONE else PILL_HIDDEN_DESKTOP
	if showPill and not pillHolder.Visible then
		pillHolder.Visible = true
		pillHolder.Position = hidden
		Fx.tween(pillHolder, Fx.MOTION.enter, { Position = shown })
	elseif not showPill and pillHolder.Visible then
		Fx.out(pillHolder, { Position = hidden })
		task.delay(Fx.MOTION.exit + 0.02, function()
			if Router.current() == "Queue" or QueueState.status() ~= "searching" then
				pillHolder.Visible = false
			end
		end)
	end
	pillTitle.Text = `SEARCHING  ·  {modeTitle(mode)}`
	pillCancel.Parent.Visible = status == "searching"

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
	local _ = name
	refresh() -- places the dock (away while a menu or MATCH FOUND is up)
end

-- Entrance: the top row drops in, the tiles rise one after another.
local function intro()
	local rowBase = topRow.Position
	topRow.Position = rowBase + UDim2.fromOffset(0, -70)
	Fx.tween(topRow, Fx.MOTION.reveal, { Position = rowBase })
	for i, tile in TILES do
		local holder = dock:FindFirstChild(tile.id)
		local target: GuiObject? = nil
		if holder then
			target = if tile.id == "Play"
				then holder :: Frame
				else holder:FindFirstChildWhichIsA("GuiButton")
		end
		if target and tile.id ~= "Play" then
			local base = Fx.base(target)
			target.Position = base + UDim2.fromOffset(0, 160)
			task.delay(0.1 + i * Fx.MOTION.stagger, function()
				Fx.tween(target, Fx.MOTION.reveal, { Position = base }, Enum.EasingStyle.Back)
			end)
		elseif target then
			local s = Fx.scale(play.face)
			s.Scale = 0.85
			task.delay(0.1 + i * Fx.MOTION.stagger, function()
				Fx.tween(s, Fx.MOTION.reveal, { Scale = 1 }, Enum.EasingStyle.Back)
			end)
		end
	end
end

function LobbyHud.init()
	local playerGui = player:WaitForChild("PlayerGui")
	-- Edge-to-edge shades (art only, nothing to press) so the bars read over a
	-- bright lobby; the top one runs under Roblox's strip, no hard edge.
	local shadeGui = Kit.make("ScreenGui", {
		Name = "LobbyHudShade",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ScreenInsets = Enum.ScreenInsets.None,
		SafeAreaCompatibility = Enum.SafeAreaCompatibility.None,
		DisplayOrder = 1,
	}, playerGui)
	shadeTop = Kit.make("Frame", {
		Name = "ShadeTop",
		Size = UDim2.new(1, 0, 0, 150),
		BackgroundColor3 = C.scrim,
		BorderSizePixel = 0,
		Active = false,
	}, shadeGui)
	Kit.make("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0.5, 1) }, shadeTop)
	shadeBottom = Kit.make("Frame", {
		Name = "ShadeBottom",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, if PHONE then 0.36 else 0.26),
		BackgroundColor3 = C.scrim,
		BorderSizePixel = 0,
		Active = false,
	}, shadeGui)
	Kit.make(
		"UIGradient",
		{ Rotation = -90, Transparency = NumberSequence.new(0.42, 1) },
		shadeBottom
	)

	gui = Kit.make("ScreenGui", {
		Name = "LobbyHud",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		SafeAreaCompatibility = Enum.SafeAreaCompatibility.None,
		DisplayOrder = 25,
	}, playerGui)
	buildTopbar()
	buildDock()
	buildPill()
	buildToast()
	layoutTopbar()
end

function LobbyHud.start()
	Sound.preload()
	QueueState.onChanged(refresh)
	Router.onChanged(onMenuChanged)
	refresh()
	intro()
end

return LobbyHud
