--!strict
-- The other lobby menus (Shop, Battle Pass, Locker, Settings, Range) as framed
-- placeholders: the same chrome as the Play menu (blur, scrim, header, close)
-- with a believable skeleton of what will live there and a clear "coming soon"
-- line. Locker uses the real gun renders; Settings has one working toggle.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Theme = require(ReplicatedStorage.Shared.Config.Theme)

local Fx = require(script.Parent.Parent.Util.Fx)
local Icons = require(script.Parent.Parent.Util.Icons)
local Layout = require(script.Parent.Parent.Util.Layout)
local Router = require(script.Parent.Parent.Util.Router)
local Sound = require(script.Parent.Parent.Util.Sound)
local Ui = require(script.Parent.Parent.SharedUi)

local Panels = {}

local C = Theme.COLORS
local player = Players.LocalPlayer

-- Desktop: 1920 x 1080 canvas. Phone: 800 x 420 (LihFolk: Responsive UI for
-- Phone Tablet Console and PC); placeholder panels collapse to one card there.
local PHONE = Layout.isPhone()
local CANVAS = Layout.pick(Vector2.new(1920, 1080), Vector2.new(800, 420))
local HEADER = Layout.pick(Vector2.new(120, 120), Vector2.new(24, 4))
local CLOSE = Layout.pick(Vector2.new(1800, 128), Vector2.new(780, 2))
local CLOSE_SIZE = Layout.pick(64, 60) -- 44+ px drawn on a 667 x 375 phone
local BODY = Layout.pick(Vector2.new(120, 260), Vector2.new(24, 70))
local BODY_SIZE = Layout.pick(Vector2.new(1680, 700), Vector2.new(752, 340))
-- Settings toggles: 44+ px drawn on a phone too.
local TOGGLE = Layout.pick(Vector2.new(84, 44), Vector2.new(100, 60))

type Panel = {
	gui: ScreenGui,
	backdrop: ScreenGui,
	focus: GuiObject?,
	scrim: Frame,
	content: CanvasGroup,
	header: Frame,
	body: Frame,
	isOpen: boolean,
}

-- A skeleton bar with a light sweeping through it on a loop.
local function skeleton(parent: Instance, props: { [string]: any }): Frame
	local bar = Ui.make("Frame", {
		BackgroundColor3 = C.white,
		BorderSizePixel = 0,
		ZIndex = 4,
	}, parent)
	for k, v in props do
		(bar :: any)[k] = v
	end
	local g = Ui.make("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, C.raised),
			ColorSequenceKeypoint.new(0.5, C.hover),
			ColorSequenceKeypoint.new(1, C.raised),
		}),
		Offset = Vector2.new(-1, 0),
	}, bar)
	TweenService:Create(
		g,
		TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1),
		{ Offset = Vector2.new(1, 0) }
	):Play()
	return bar
end

local function card(
	parent: Instance,
	x: number,
	y: number,
	w: number,
	h: number,
	line: Color3?
): ImageLabel
	return Ui.cut(parent, {
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
	}, { color = C.card, transparency = 0.04, line = line or C.lineSoft, corner = 18 })
end

local function soon(parent: Instance, text: string, y: number)
	-- An auto-layout row, so the tag and the line never touch at any text size.
	local row = Ui.make("Frame", {
		Position = UDim2.fromOffset(0, y),
		Size = UDim2.fromOffset(1600, 32),
		BackgroundTransparency = 1,
	}, parent)
	Ui.make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 16),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, row)
	local tag = Ui.tag(row, "COMING SOON", C.gold, { LayoutOrder = 1 }, true)
	Ui.text(row, text, "bodyM", {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 24),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.textSecondary,
		LayoutOrder = 2,
	})
	return tag
end

local function build(name: string, kicker: string, title: string): Panel
	-- Two layers (LihFolk: Safe Areas and Insets): the dimmer bleeds to every
	-- edge, the panel content stays inside the core-UI safe area.
	local backdrop = Ui.make("ScreenGui", {
		Name = "Lobby" .. name .. "Backdrop",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ScreenInsets = Enum.ScreenInsets.None,
		SafeAreaCompatibility = Enum.SafeAreaCompatibility.None,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 19,
		Enabled = false,
	}, player:WaitForChild("PlayerGui"))
	local gui = Ui.make("ScreenGui", {
		Name = "Lobby" .. name,
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		SafeAreaCompatibility = Enum.SafeAreaCompatibility.None,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 20,
		Enabled = false,
	}, player:WaitForChild("PlayerGui"))
	local scrim = Ui.make("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.scrim,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		Modal = true,
		Selectable = false,
	}, backdrop)
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
	local content = Ui.make("CanvasGroup", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(CANVAS.X, CANVAS.Y),
		BackgroundTransparency = 1,
		SelectionGroup = true,
		SelectionBehaviorUp = Enum.SelectionBehavior.Stop,
		SelectionBehaviorDown = Enum.SelectionBehavior.Stop,
		SelectionBehaviorLeft = Enum.SelectionBehavior.Stop,
		SelectionBehaviorRight = Enum.SelectionBehavior.Stop,
	}, gui)
	Layout.fit(content, "menu")
	local header = Ui.make("Frame", {
		Position = UDim2.fromOffset(HEADER.X, HEADER.Y),
		Size = UDim2.fromOffset(900, 110),
		BackgroundTransparency = 1,
	}, content)
	Ui.make("Frame", {
		Position = UDim2.fromOffset(0, 6),
		Size = UDim2.fromOffset(4, Layout.pick(92, 54)),
		BackgroundColor3 = C.gold,
		BorderSizePixel = 0,
	}, header)
	Ui.text(header, kicker, "label", {
		Position = UDim2.fromOffset(22, 4),
		Size = UDim2.fromOffset(600, 24),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.gold,
		TextSize = 15,
	})
	Ui.text(header, title, "displayL", {
		Position = UDim2.fromOffset(20, Layout.pick(26, 22)),
		Size = UDim2.fromOffset(Layout.pick(800, 600), Layout.pick(64, 40)),
		TextSize = Layout.pick(56, 32),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	-- The same close button, same corner, same size on every menu (LihFolk: Menu Archetypes).
	local closeHolder = Ui.make("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromOffset(CLOSE.X, CLOSE.Y),
		Size = UDim2.fromOffset(CLOSE_SIZE, CLOSE_SIZE),
		BackgroundTransparency = 1,
	}, content)
	local close = Ui.cut(closeHolder, { Size = UDim2.fromScale(1, 1) }, {
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
		}, close)
	end
	Fx.button(close, function()
		Router.close()
	end, {
		silent = true,
		onHover = function(on)
			Fx.tween(close, Fx.MOTION.hover, { ImageColor3 = if on then C.hover else C.panel })
		end,
	})
	local body = Ui.make("Frame", {
		Position = UDim2.fromOffset(BODY.X, BODY.Y),
		Size = UDim2.fromOffset(BODY_SIZE.X, BODY_SIZE.Y),
		BackgroundTransparency = 1,
	}, content)

	local panel: Panel = {
		gui = gui,
		backdrop = backdrop,
		focus = close,
		scrim = scrim,
		content = content,
		header = header,
		body = body,
		isOpen = false,
	}
	Router.register(name, {
		open = function()
			if panel.isOpen then
				return
			end
			panel.isOpen = true
			gui.Enabled = true
			backdrop.Enabled = true
			scrim.BackgroundTransparency = 1
			Fx.tween(scrim, Fx.MOTION.dimIn, { BackgroundTransparency = 0.38 })
			content.GroupTransparency = 1
			Fx.tween(content, Fx.MOTION.enter, { GroupTransparency = 0 })
			header.Position = UDim2.fromOffset(HEADER.X - 36, HEADER.Y)
			Fx.tween(header, Fx.MOTION.enter, { Position = UDim2.fromOffset(HEADER.X, HEADER.Y) })
			body.Position = UDim2.fromOffset(BODY.X, BODY.Y + 32)
			Fx.tween(body, Fx.MOTION.enter, { Position = UDim2.fromOffset(BODY.X, BODY.Y) })
		end,
		close = function()
			if not panel.isOpen then
				return
			end
			panel.isOpen = false
			Fx.out(content, { GroupTransparency = 1 })
			Fx.tween(
				scrim,
				Fx.MOTION.dimOut,
				{ BackgroundTransparency = 1 },
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.In
			)
			task.delay(Fx.MOTION.exit + 0.02, function()
				if not panel.isOpen then
					gui.Enabled = false
					backdrop.Enabled = false
				end
			end)
		end,
		focus = function(): GuiObject?
			return panel.focus
		end,
	})
	return panel
end

-- Phone: a placeholder panel is one card (icon, what it will be, COMING SOON).
local function compact(p: Panel, icon: string, headline: string, text: string)
	local c = card(p.body, 0, 0, BODY_SIZE.X, 230, C.lineStrong)
	Icons.draw(c, icon, 72, C.textSecondary, {
		Position = UDim2.fromOffset(28, 28),
		ZIndex = 4,
	})
	Ui.text(c, headline, "displayM", {
		Position = UDim2.fromOffset(124, 30),
		Size = UDim2.fromOffset(600, 44),
		TextSize = 32,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 4,
	})
	Ui.text(c, text, "bodyM", {
		Position = UDim2.fromOffset(126, 82),
		Size = UDim2.fromOffset(590, 80),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		TextColor3 = C.textSecondary,
		ZIndex = 4,
	})
	Ui.tag(c, "COMING SOON", C.gold, {
		Position = UDim2.fromOffset(126, 178),
		ZIndex = 4,
	}, true)
end
--------------------------------------------------------------------------------

local function buildShop()
	local p = build("Shop", "SHOP  ·  DAILY ITEMS", "SHOP")
	if PHONE then
		compact(
			p,
			"Shop",
			"DAILY ITEMS",
			"Skins, wraps, charms, emotes and bundles arrive with the economy."
		)
		return
	end
	local featured = card(p.body, 0, 0, 620, 560, C.gold)
	Ui.tag(featured, "FEATURED", C.gold, { Position = UDim2.fromOffset(28, 28), ZIndex = 5 }, true)
	skeleton(featured, { Position = UDim2.fromOffset(28, 400), Size = UDim2.fromOffset(340, 30) })
	skeleton(featured, { Position = UDim2.fromOffset(28, 448), Size = UDim2.fromOffset(220, 18) })
	skeleton(featured, { Position = UDim2.fromOffset(470, 488), Size = UDim2.fromOffset(122, 44) })
	for i = 0, 5 do
		local col, row = i % 3, i // 3
		local c = card(p.body, 660 + col * 340, row * 284, 320, 268)
		skeleton(c, { Position = UDim2.fromOffset(22, 24), Size = UDim2.fromOffset(276, 140) })
		skeleton(c, { Position = UDim2.fromOffset(22, 184), Size = UDim2.fromOffset(180, 20) })
		skeleton(c, { Position = UDim2.fromOffset(22, 218), Size = UDim2.fromOffset(90, 26) })
	end
	soon(p.body, "Skins, wraps, charms, emotes and bundles arrive with the economy.", 600)
end

local function buildBattlePass()
	local p = build("BattlePass", "SEASON 1  ·  TIER 1", "BATTLE PASS")
	if PHONE then
		compact(
			p,
			"BattlePass",
			"SEASON 1",
			"Seasonal rewards for playing: skins, banners, emotes and currency."
		)
		return
	end
	Ui.text(p.body, "TIER 1", "titleCard", {
		Size = UDim2.fromOffset(200, 48),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local track = Ui.make("Frame", {
		Position = UDim2.fromOffset(170, 20),
		Size = UDim2.fromOffset(1100, 10),
		BackgroundColor3 = C.raised,
		BorderSizePixel = 0,
	}, p.body)
	Ui.make(
		"Frame",
		{ Size = UDim2.fromScale(0.03, 1), BackgroundColor3 = C.gold, BorderSizePixel = 0 },
		track
	)
	Ui.text(p.body, "0 / 1,000 XP", "label", {
		Position = UDim2.fromOffset(1290, 14),
		Size = UDim2.fromOffset(200, 20),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.textSecondary,
	})
	for _, rowDef in
		{
			{ y = 80, label = "PREMIUM", line = C.gold, h = 250 },
			{ y = 360, label = "FREE", line = C.lineSoft, h = 190 },
		}
	do
		Ui.text(p.body, rowDef.label, "label", {
			Position = UDim2.fromOffset(0, rowDef.y),
			Size = UDim2.fromOffset(120, 20),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = if rowDef.label == "PREMIUM" then C.gold else C.textSecondary,
		})
		for i = 0, 7 do
			local c = card(
				p.body,
				i * 210,
				rowDef.y + 28,
				190,
				rowDef.h,
				if i == 0 then C.text else rowDef.line
			)
			Ui.text(c, tostring(i + 1), "titleS", {
				Position = UDim2.fromOffset(16, 10),
				Size = UDim2.fromOffset(40, 26),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = if i == 0 then C.gold else C.textDim,
				ZIndex = 4,
			})
			skeleton(c, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.55),
				Size = UDim2.fromOffset(110, rowDef.h * 0.45),
			})
		end
	end
	soon(p.body, "Seasonal rewards for playing: skins, banners, emotes and currency.", 600)
end

local LOADOUT = {
	{ slot = "PRIMARY", gun = "Vandal" },
	{ slot = "SECONDARY", gun = "Classic" },
	{ slot = "MELEE", gun = "Knife" },
}

local function buildLocker()
	local p = build("Locker", "LOADOUT  ·  SKINS", "LOCKER")
	if PHONE then
		compact(
			p,
			"Locker",
			"YOUR LOADOUT",
			"Choose skins, wraps and charms here. Match loadouts are still drafted every round."
		)
		return
	end
	local preview = card(p.body, 520, 0, 1160, 560)
	local big = Ui.gun(preview, "Vandal", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.48),
		Size = UDim2.fromOffset(820, 360),
		ZIndex = 4,
	})
	local bigName = Ui.text(preview, "VANDAL", "displayM", {
		Position = UDim2.fromOffset(32, 24),
		Size = UDim2.fromOffset(400, 48),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 4,
	})
	Ui.text(preview, "DEFAULT SKIN", "label", {
		Position = UDim2.fromOffset(34, 72),
		Size = UDim2.fromOffset(400, 18),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.textSecondary,
		ZIndex = 4,
	})
	for i, entry in LOADOUT do
		local holder = Ui.make("Frame", {
			Position = UDim2.fromOffset(0, (i - 1) * 190),
			Size = UDim2.fromOffset(490, 170),
			BackgroundTransparency = 1,
		}, p.body)
		local button = Ui.cut(holder, { Size = UDim2.fromScale(1, 1) }, {
			className = "ImageButton",
			color = C.card,
			transparency = 0.04,
			line = C.lineSoft,
			corner = 18,
		})
		Ui.text(button, entry.slot, "label", {
			Position = UDim2.fromOffset(22, 18),
			Size = UDim2.fromOffset(200, 18),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = C.textSecondary,
			ZIndex = 4,
		})
		Ui.text(button, string.upper(entry.gun), "titleS", {
			Position = UDim2.fromOffset(22, 44),
			Size = UDim2.fromOffset(220, 36),
			TextSize = 32, -- the gun name outranks the slot label
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 4,
		})
		Ui.gun(button, entry.gun, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -20, 0.5, 10),
			Size = UDim2.fromOffset(280, 120),
			ZIndex = 4,
		})
		local shine = Fx.shine(button, C.white, 0.12)
		Fx.button(button, function()
			big.Image = Theme.GUN[entry.gun] or ""
			bigName.Text = string.upper(entry.gun)
			Fx.pop(big, 1.04)
		end, {
			lift = button,
			liftBy = 4,
			shine = shine,
			onHover = function(on)
				Fx.tween(button, 0.15, { ImageColor3 = if on then C.hover else C.card })
			end,
		})
	end
	soon(
		p.body,
		"Choose skins, wraps and charms here. Match loadouts are still drafted every round.",
		600
	)
end

local function buildSettings()
	local p = build("Settings", "OPTIONS", "SETTINGS")
	local rowW, rowH, rowGap =
		Layout.pick(1100, BODY_SIZE.X), Layout.pick(88, 70), Layout.pick(104, 78)
	local function setSound(on: boolean)
		local group = SoundService:FindFirstChild("Ui")
		if group and group:IsA("SoundGroup") then
			group.Volume = if on then 1 else 0
		end
	end
	type Row = { name: string, hint: string, value: (() -> boolean)?, set: ((boolean) -> ())? }
	local rows: { Row } = {
		{
			name = "UI SOUNDS",
			hint = "Clicks, whooshes and stingers in menus.",
			value = function()
				return true
			end,
			set = setSound,
		},
		{
			-- LihFolk: UI Motion Language and Timing (offer an in-game toggle;
			-- starts from the Roblox setting).
			name = "REDUCED MOTION",
			hint = "Fades instead of slides, pops, sweeps and spins.",
			value = Fx.reduced,
			set = function(on: boolean)
				Fx.setReduced(on)
			end,
		},
		{ name = "CAMERA SENSITIVITY", hint = "Saved with your profile." },
		{ name = "FIELD OF VIEW", hint = "Match camera FOV." },
	}
	for i, row in rows do
		local live = row.set ~= nil
		local c = card(p.body, 0, (i - 1) * rowGap, rowW, rowH)
		Ui.text(c, row.name, "titleS", {
			Position = UDim2.fromOffset(28, Layout.pick(14, 8)),
			Size = UDim2.fromOffset(600, 26),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = if live then C.text else C.textDim,
			ZIndex = 4,
		})
		Ui.text(c, row.hint, "bodyS", {
			Position = UDim2.fromOffset(28, Layout.pick(46, 38)),
			Size = UDim2.fromOffset(Layout.pick(600, 520), 20),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = C.textSecondary,
			ZIndex = 4,
		})
		local value, set = row.value, row.set
		if value and set then
			local holder = Ui.make("Frame", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -28, 0.5, 0),
				Size = UDim2.fromOffset(TOGGLE.X, TOGGLE.Y),
				BackgroundTransparency = 1,
				ZIndex = 4,
			}, c)
			local on = value()
			local toggle = Ui.make("TextButton", {
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = if on then C.ready else C.lineStrong,
				AutoButtonColor = false,
				Text = "",
				ZIndex = 4,
			}, holder)
			Ui.make("UICorner", { CornerRadius = UDim.new(1, 0) }, toggle)
			local knob = Ui.make("Frame", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = if on
					then UDim2.new(1, -(TOGGLE.Y - 5), 0.5, 0)
					else UDim2.new(0, 5, 0.5, 0),
				Size = UDim2.fromOffset(TOGGLE.Y - 10, TOGGLE.Y - 10),
				BackgroundColor3 = C.white,
				BorderSizePixel = 0,
				ZIndex = 5,
			}, toggle)
			Ui.make("UICorner", { CornerRadius = UDim.new(1, 0) }, knob)
			-- State is a word too, not only the colour (LihFolk: Accessibility).
			local stateLabel = Ui.text(c, if on then "ON" else "OFF", "label", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -(TOGGLE.X + 40), 0.5, 0),
				Size = UDim2.fromOffset(50, 20),
				TextXAlignment = Enum.TextXAlignment.Right,
				TextColor3 = C.textSecondary,
				ZIndex = 4,
			})
			if i == 1 then
				p.focus = toggle
			end
			Fx.button(toggle, function()
				on = not on
				set(on)
				stateLabel.Text = if on then "ON" else "OFF"
				Fx.tween(
					toggle,
					Fx.MOTION.enter,
					{ BackgroundColor3 = if on then C.ready else C.lineStrong }
				)
				Fx.tween(knob, Fx.MOTION.enter, {
					Position = if on
						then UDim2.new(1, -(TOGGLE.Y - 5), 0.5, 0)
						else UDim2.new(0, 5, 0.5, 0),
				}, Enum.EasingStyle.Back)
			end)
		else
			Ui.tag(c, "SOON", C.textDim, {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -28, 0.5, 0),
				ZIndex = 4,
			})
		end
	end
	if PHONE then
		return
	end
	soon(
		p.body,
		"More options (keybinds, graphics, crosshair) come with saved player settings.",
		600
	)
end

local function buildRange()
	local p = build("Range", "PRACTICE", "SHOOTING RANGE")
	if PHONE then
		compact(
			p,
			"Range",
			"EVERY GUN. EVERY MOD.",
			"Lanes, dummies that shoot back, a movement course and an ability area. Opens in the next lobby phase."
		)
		return
	end
	local c = card(p.body, 0, 0, 1100, 420, C.lineStrong)
	Icons.draw(c, "Range", 120, C.textSecondary, {
		Position = UDim2.fromOffset(60, 60),
		ZIndex = 4,
	})
	Ui.text(c, "EVERY GUN. EVERY MOD.", "displayM", {
		Position = UDim2.fromOffset(230, 70),
		Size = UDim2.fromOffset(800, 50),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 4,
	})
	Ui.text(
		c,
		"Firing lanes, moving dummies that shoot back, a movement course and an ability test area. Walk down the ramp behind spawn, or press RANGE.",
		"bodyM",
		{
			Position = UDim2.fromOffset(232, 136),
			Size = UDim2.fromOffset(800, 80),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = true,
			TextColor3 = C.textSecondary,
			ZIndex = 4,
		}
	)
	soon(
		p.body,
		"The Range wing opens in the next lobby phase. You'll be able to queue from inside it.",
		460
	)
end

function Panels.init()
	buildShop()
	buildBattlePass()
	buildLocker()
	buildSettings()
	buildRange()
	local _ = Sound
end

return Panels
