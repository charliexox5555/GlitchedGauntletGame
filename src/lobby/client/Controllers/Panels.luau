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
local Router = require(script.Parent.Parent.Util.Router)
local Sound = require(script.Parent.Parent.Util.Sound)
local Ui = require(script.Parent.Parent.SharedUi)

local Panels = {}

local C = Theme.COLORS
local player = Players.LocalPlayer

type Panel = {
	gui: ScreenGui,
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
	local tag = Ui.tag(parent, "COMING SOON", C.gold, {
		Position = UDim2.fromOffset(0, y),
	}, true)
	Ui.text(parent, text, "bodyM", {
		Position = UDim2.fromOffset(150, y + 1),
		Size = UDim2.fromOffset(1400, 24),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.textSecondary,
	})
	return tag
end

local function build(name: string, kicker: string, title: string): Panel
	local gui = Ui.make("ScreenGui", {
		Name = "Lobby" .. name,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
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
	}, gui)
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
		Size = UDim2.fromOffset(1920, 1080),
		BackgroundTransparency = 1,
	}, gui)
	Ui.fit(content)
	local header = Ui.make("Frame", {
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
	Ui.text(header, kicker, "label", {
		Position = UDim2.fromOffset(22, 4),
		Size = UDim2.fromOffset(600, 18),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.gold,
		TextSize = 15,
	})
	Ui.text(header, title, "displayL", {
		Position = UDim2.fromOffset(20, 26),
		Size = UDim2.fromOffset(800, 64),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local closeHolder = Ui.make("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromOffset(1800, 128),
		Size = UDim2.fromOffset(64, 64),
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
			Fx.tween(close, 0.12, { ImageColor3 = if on then C.hover else C.panel })
		end,
	})
	local body = Ui.make("Frame", {
		Position = UDim2.fromOffset(120, 260),
		Size = UDim2.fromOffset(1680, 700),
		BackgroundTransparency = 1,
	}, content)

	local panel: Panel = {
		gui = gui,
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
			scrim.BackgroundTransparency = 1
			Fx.tween(scrim, 0.25, { BackgroundTransparency = 0.38 })
			content.GroupTransparency = 1
			Fx.tween(content, 0.25, { GroupTransparency = 0 })
			header.Position = UDim2.fromOffset(84, 120)
			Fx.tween(header, 0.4, { Position = UDim2.fromOffset(120, 120) })
			body.Position = UDim2.fromOffset(120, 300)
			Fx.tween(body, 0.4, { Position = UDim2.fromOffset(120, 260) })
		end,
		close = function()
			if not panel.isOpen then
				return
			end
			panel.isOpen = false
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
			task.delay(0.2, function()
				if not panel.isOpen then
					gui.Enabled = false
				end
			end)
		end,
	})
	return panel
end

--------------------------------------------------------------------------------

local function buildShop()
	local p = build("Shop", "SHOP  ·  DAILY ITEMS", "SHOP")
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
		TextColor3 = C.textDim,
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
			TextColor3 = C.textDim,
			ZIndex = 4,
		})
		Ui.text(button, string.upper(entry.gun), "titleS", {
			Position = UDim2.fromOffset(22, 40),
			Size = UDim2.fromOffset(200, 26),
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
	local rows = {
		{ name = "UI SOUNDS", hint = "Clicks, whooshes and stingers in menus.", live = true },
		{ name = "CAMERA SENSITIVITY", hint = "Saved with your profile.", live = false },
		{ name = "FIELD OF VIEW", hint = "Match camera FOV.", live = false },
		{ name = "COLOUR-BLIND TEAM COLOURS", hint = "Swap ally and enemy colours.", live = false },
	}
	for i, row in rows do
		local c = card(p.body, 0, (i - 1) * 104, 1100, 88)
		Ui.text(c, row.name, "titleS", {
			Position = UDim2.fromOffset(28, 14),
			Size = UDim2.fromOffset(600, 26),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = if row.live then C.text else C.textDim,
			ZIndex = 4,
		})
		Ui.text(c, row.hint, "bodyS", {
			Position = UDim2.fromOffset(28, 46),
			Size = UDim2.fromOffset(600, 20),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = C.textDim,
			ZIndex = 4,
		})
		if row.live then
			local holder = Ui.make("Frame", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -28, 0.5, 0),
				Size = UDim2.fromOffset(84, 40),
				BackgroundTransparency = 1,
				ZIndex = 4,
			}, c)
			local toggle = Ui.make("TextButton", {
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = C.ready,
				AutoButtonColor = false,
				Text = "",
				ZIndex = 4,
			}, holder)
			Ui.make("UICorner", { CornerRadius = UDim.new(1, 0) }, toggle)
			local knob = Ui.make("Frame", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(1, -36, 0.5, 0),
				Size = UDim2.fromOffset(32, 32),
				BackgroundColor3 = C.white,
				BorderSizePixel = 0,
				ZIndex = 5,
			}, toggle)
			Ui.make("UICorner", { CornerRadius = UDim.new(1, 0) }, knob)
			local on = true
			Fx.button(toggle, function()
				on = not on
				local group = SoundService:FindFirstChild("Ui")
				if group and group:IsA("SoundGroup") then
					group.Volume = if on then 1 else 0
				end
				Fx.tween(toggle, 0.18, { BackgroundColor3 = if on then C.ready else C.lineStrong })
				Fx.tween(knob, 0.22, {
					Position = if on then UDim2.new(1, -36, 0.5, 0) else UDim2.new(0, 4, 0.5, 0),
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
	soon(
		p.body,
		"More options (keybinds, graphics, crosshair) come with saved player settings.",
		600
	)
end

local function buildRange()
	local p = build("Range", "PRACTICE", "SHOOTING RANGE")
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
