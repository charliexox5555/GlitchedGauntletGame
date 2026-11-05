--!strict
-- The other lobby menus (Shop, Battle Pass, Locker, Settings, Range) as framed
-- placeholders: the same chrome as the Play menu (blur, scrim, header, close)
-- with a believable skeleton of what will live there and a clear "coming soon"
-- line. Locker uses the real gun renders; Settings has one working toggle.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Theme = require(ReplicatedStorage.Shared.Config.Theme) -- gun renders (Theme.GUN)

local Fx = require(script.Parent.Parent.Util.Fx)
local Icons = require(script.Parent.Parent.Util.Icons)
local Kit = require(script.Parent.Parent.Util.Kit)
local Layout = require(script.Parent.Parent.Util.Layout)
local Menu = require(script.Parent.Parent.Util.Menu)
local Router = require(script.Parent.Parent.Util.Router)
local Sound = require(script.Parent.Parent.Util.Sound)
local Style = require(script.Parent.Parent.Util.Style)
local Ui = require(script.Parent.Parent.SharedUi)

local Panels = {}

local C = Style.COLOR

-- Desktop: 1920 x 1080 canvas. Phone: 800 x 420 (LihFolk: Responsive UI for
-- Phone Tablet Console and PC); placeholder panels collapse to one card there.
local PHONE = Layout.isPhone()
local BODY = Layout.pick(Vector2.new(96, 228), Vector2.new(24, 76))
local BODY_SIZE = Layout.pick(Vector2.new(1728, 700), Vector2.new(752, 330))
-- Settings toggles: 44+ px drawn on a phone too.
local TOGGLE = Layout.pick(Vector2.new(84, 44), Vector2.new(100, 60))

type Panel = {
	chrome: Menu.Chrome,
	focus: GuiObject?,
	body: Frame,
	isOpen: boolean,
}

-- A skeleton bar with a light sweeping through it on a loop.
local function skeleton(parent: Instance, props: { [string]: any }): Frame
	local bar = Kit.make("Frame", {
		BackgroundColor3 = C.white,
		BorderSizePixel = 0,
		ZIndex = 4,
	}, parent)
	for k, v in props do
		(bar :: any)[k] = v
	end
	Kit.corner(bar, Style.RADIUS.xs)
	local g = Kit.make("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, C.surfaceDeep),
			ColorSequenceKeypoint.new(0.5, C.surfaceHover),
			ColorSequenceKeypoint.new(1, C.surfaceDeep),
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
): Frame
	local c = Kit.surface(parent, {
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		ZIndex = 2,
	}, {
		radius = Style.RADIUS.lg,
		transparency = 0.02,
		stroke = line or true,
		strokeTransparency = if line then 0.3 else nil,
	})
	Kit.shadow(c, Style.RADIUS.lg, 0.8)
	return c
end

local function soon(parent: Instance, text: string, y: number)
	-- An auto-layout row, so the tag and the line never touch at any text size.
	local row = Kit.make("Frame", {
		Position = UDim2.fromOffset(0, y),
		Size = UDim2.fromOffset(1600, 32),
		BackgroundTransparency = 1,
	}, parent)
	Kit.make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 16),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, row)
	local tag = Kit.tag(row, "COMING SOON", C.primary, { LayoutOrder = 1 }, true)
	Kit.text(row, text, "body", {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 24),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.textSecondary,
		LayoutOrder = 2,
	})
	return tag
end

local function build(name: string, kicker: string, title: string): Panel
	local chrome = Menu.build("Lobby" .. name, kicker, title)
	local body = Kit.make("Frame", {
		Name = "Body",
		Position = UDim2.fromOffset(BODY.X, BODY.Y),
		Size = UDim2.fromOffset(BODY_SIZE.X, BODY_SIZE.Y),
		BackgroundTransparency = 1,
	}, chrome.content)
	local panel: Panel = {
		chrome = chrome,
		focus = chrome.close,
		body = body,
		isOpen = false,
	}
	Router.register(name, {
		open = function()
			if panel.isOpen then
				return
			end
			panel.isOpen = true
			Menu.show(chrome)
			body.Position = UDim2.fromOffset(BODY.X, BODY.Y + 32)
			Fx.tween(body, Fx.MOTION.enter, { Position = UDim2.fromOffset(BODY.X, BODY.Y) })
		end,
		close = function()
			if not panel.isOpen then
				return
			end
			panel.isOpen = false
			Menu.hide(chrome, function()
				return panel.isOpen
			end)
		end,
		focus = function(): GuiObject?
			return panel.focus
		end,
	})
	-- Built content is added after the Fit pass: re-run the text floor and
	-- stroke snap once everything exists.
	task.defer(function()
		local fit = chrome.content:FindFirstChild("Fit")
		if fit and fit:IsA("UIScale") then
			Layout.floorText(chrome.content, fit.Scale)
			Layout.snapStrokes(chrome.content, fit.Scale)
		end
	end)
	return panel
end

-- Phone: a placeholder panel is one card (icon, what it will be, COMING SOON).
local function compact(p: Panel, icon: string, headline: string, text: string)
	local c = card(p.body, 0, 0, BODY_SIZE.X, 230)
	Icons.draw(c, icon, 72, C.textSecondary, {
		Position = UDim2.fromOffset(28, 28),
		ZIndex = 4,
	})
	Kit.text(c, headline, "title", {
		Position = UDim2.fromOffset(124, 30),
		Size = UDim2.fromOffset(600, 44),
		TextSize = 32,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 4,
	})
	Kit.text(c, text, "body", {
		Position = UDim2.fromOffset(126, 82),
		Size = UDim2.fromOffset(590, 80),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		TextColor3 = C.textSecondary,
		ZIndex = 4,
	})
	Kit.tag(c, "COMING SOON", C.primary, {
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
	local featured = card(p.body, 0, 0, 620, 560, C.primary)
	Kit.tag(
		featured,
		"FEATURED",
		C.primary,
		{ Position = UDim2.fromOffset(28, 28), ZIndex = 5 },
		true
	)
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
	Kit.text(p.body, "TIER 1", "heading", {
		Size = UDim2.fromOffset(200, 48),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local track = Kit.make("Frame", {
		Position = UDim2.fromOffset(170, 20),
		Size = UDim2.fromOffset(1100, 10),
		BackgroundColor3 = C.surfaceDeep,
		BorderSizePixel = 0,
	}, p.body)
	Kit.make(
		"Frame",
		{ Size = UDim2.fromScale(0.03, 1), BackgroundColor3 = C.primary, BorderSizePixel = 0 },
		track
	)
	Kit.text(p.body, "0 / 1,000 XP", "label", {
		Position = UDim2.fromOffset(1290, 14),
		Size = UDim2.fromOffset(200, 20),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.textSecondary,
	})
	for _, rowDef in
		{
			{ y = 80, label = "PREMIUM", line = C.primary :: Color3?, h = 250 },
			{ y = 360, label = "FREE", line = nil :: Color3?, h = 190 },
		}
	do
		Kit.text(p.body, rowDef.label, "label", {
			Position = UDim2.fromOffset(0, rowDef.y),
			Size = UDim2.fromOffset(120, 20),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = if rowDef.label == "PREMIUM" then C.primary else C.textSecondary,
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
			Kit.text(c, tostring(i + 1), "heading", {
				Position = UDim2.fromOffset(16, 10),
				Size = UDim2.fromOffset(40, 26),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = if i == 0 then C.primary else C.textMuted,
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
	local bigName = Kit.text(preview, "VANDAL", "title", {
		Position = UDim2.fromOffset(32, 24),
		Size = UDim2.fromOffset(400, 48),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 4,
	})
	Kit.text(preview, "DEFAULT SKIN", "label", {
		Position = UDim2.fromOffset(34, 72),
		Size = UDim2.fromOffset(400, 18),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.textSecondary,
		ZIndex = 4,
	})
	for i, entry in LOADOUT do
		local holder = Kit.make("Frame", {
			Position = UDim2.fromOffset(0, (i - 1) * 190),
			Size = UDim2.fromOffset(490, 170),
			BackgroundTransparency = 1,
		}, p.body)
		local button = Kit.surface(holder, { Size = UDim2.fromScale(1, 1), ZIndex = 2 }, {
			className = "TextButton",
			radius = Style.RADIUS.lg,
			transparency = 0.02,
		})
		Kit.shadow(button, Style.RADIUS.lg, 0.8)
		Kit.text(button, entry.slot, "label", {
			Position = UDim2.fromOffset(22, 18),
			Size = UDim2.fromOffset(200, 18),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = C.textSecondary,
			ZIndex = 4,
		})
		Kit.text(button, string.upper(entry.gun), "heading", {
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
		local shine = if Style.FLAGS.shine then Fx.shine(button, C.white, 0.08) else nil
		Fx.button(button, function()
			big.Image = Theme.GUN[entry.gun] or ""
			bigName.Text = string.upper(entry.gun)
			Fx.pop(big, 1.04)
		end, {
			lift = button,
			liftBy = 4,
			shine = shine,
			onHover = function(on)
				Fx.tween(
					button,
					Fx.MOTION.hover,
					{ BackgroundColor3 = if on then C.surfaceHover else C.surface }
				)
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
		Kit.text(c, row.name, "heading", {
			Position = UDim2.fromOffset(28, Layout.pick(14, 8)),
			Size = UDim2.fromOffset(600, 26),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = if live then C.text else C.textMuted,
			ZIndex = 4,
		})
		Kit.text(c, row.hint, "bodyS", {
			Position = UDim2.fromOffset(28, Layout.pick(46, 38)),
			Size = UDim2.fromOffset(Layout.pick(600, 520), 20),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = C.textSecondary,
			ZIndex = 4,
		})
		local value, set = row.value, row.set
		if value and set then
			local holder = Kit.make("Frame", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -28, 0.5, 0),
				Size = UDim2.fromOffset(TOGGLE.X, TOGGLE.Y),
				BackgroundTransparency = 1,
				ZIndex = 4,
			}, c)
			local on = value()
			local toggle = Kit.make("TextButton", {
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = if on then C.success else C.surfaceHover,
				AutoButtonColor = false,
				Text = "",
				ZIndex = 4,
			}, holder)
			Kit.make("UICorner", { CornerRadius = UDim.new(1, 0) }, toggle)
			local knob = Kit.make("Frame", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = if on
					then UDim2.new(1, -(TOGGLE.Y - 5), 0.5, 0)
					else UDim2.new(0, 5, 0.5, 0),
				Size = UDim2.fromOffset(TOGGLE.Y - 10, TOGGLE.Y - 10),
				BackgroundColor3 = C.white,
				BorderSizePixel = 0,
				ZIndex = 5,
			}, toggle)
			Kit.make("UICorner", { CornerRadius = UDim.new(1, 0) }, knob)
			-- State is a word too, not only the colour (LihFolk: Accessibility).
			local stateLabel = Kit.text(c, if on then "ON" else "OFF", "label", {
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
					{ BackgroundColor3 = if on then C.success else C.surfaceHover }
				)
				Fx.tween(knob, Fx.MOTION.enter, {
					Position = if on
						then UDim2.new(1, -(TOGGLE.Y - 5), 0.5, 0)
						else UDim2.new(0, 5, 0.5, 0),
				}, Enum.EasingStyle.Back)
			end)
		else
			Kit.tag(c, "SOON", C.textMuted, {
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
	local c = card(p.body, 0, 0, 1100, 420)
	Icons.draw(c, "Range", 120, C.textSecondary, {
		Position = UDim2.fromOffset(60, 60),
		ZIndex = 4,
	})
	Kit.text(c, "EVERY GUN. EVERY MOD.", "title", {
		Position = UDim2.fromOffset(230, 70),
		Size = UDim2.fromOffset(800, 50),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 4,
	})
	Kit.text(
		c,
		"Firing lanes, moving dummies that shoot back, a movement course and an ability test area. Walk down the ramp behind spawn, or press RANGE.",
		"body",
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
