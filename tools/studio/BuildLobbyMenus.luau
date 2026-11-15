--!strict
-- Builds the lobby's Play menu, searching bar and Party menu (vault/02 Art/
-- UI Play and Party Menus.md) in the LOBBY place, Edit mode:
--   StarterGui.PlayMenu     mode tiles (off; Controllers/PlayMenuController)
--   StarterGui.LobbySearch  the searching bar, top centre (Bar hidden until queued)
--   StarterGui.PartyMenu    your party + everyone to invite (off; PartyMenuController)
--   UiTemplates.Lobby.PartyPlayerCard
-- Re-running replaces them. The look is the Locker's (BuildLocker.luau):
-- Builder Extended ExtraBold, dark navy see-through plates, cyan selection
-- with slant ends, white plates for the main action, a round close button.
-- No pills, outlines, glows, edge strips or icon tiles.

local SG = game:GetService("StarterGui")
local RS = game:GetService("ReplicatedStorage")

local function hex(h: string): Color3
	return Color3.fromHex(h)
end
local function make(class: string, props: { [string]: any }, parent: Instance?): any
	local i = Instance.new(class)
	for k, v in props do
		(i :: any)[k] = v
	end
	if parent then
		i.Parent = parent
	end
	return i
end

local BX = "rbxasset://fonts/families/BuilderExtended.json"
local XB, BOLD = Enum.FontWeight.ExtraBold, Enum.FontWeight.Bold
local CARD = hex("0B1236")
local CARD_T = 0.15 -- over a blurred world the plates need more body than the Locker's
local SCRIM = hex("06080C")
local ALLY, GREEN, RED = hex("3FE0F2"), hex("3FD68A"), hex("FF4D5E")
local MUTED, INK, WHITE = hex("AEB8D6"), hex("141A26"), Color3.new(1, 1, 1)
local CAP_R = "rbxassetid://130377997107460" -- slant cap (rotated 180 for the left end)
local CENTRE = Vector2.new(0.5, 0.5)
-- mode art (the ChatGPT art the old queue menu used; Controllers/QueueMenu MODE_ART)
local ART = {
	["1v1"] = "rbxassetid://132175332386485",
	["2v2"] = "rbxassetid://88838344441665",
	["3v3"] = "rbxassetid://91043835690868",
}

local function text(
	p: Instance,
	name: string,
	s: string,
	size: number,
	color: Color3,
	props: { [string]: any }?
): TextLabel
	local t = make("TextLabel", {
		Name = name,
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, size + 4),
		Text = s,
		FontFace = Font.new(BX, XB),
		TextSize = size,
		TextColor3 = color,
		ZIndex = 5,
	}, p)
	for k, v in props or {} do
		(t :: any)[k] = v
	end
	return t
end
local function corner(p: Instance, r: number?)
	make("UICorner", { CornerRadius = UDim.new(0, r or 8) }, p)
end
local function round(p: Instance)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, p)
end
local function slant(body: GuiObject, color: Color3, h: number, capW: number)
	make("ImageLabel", {
		Name = "CapL",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(0, 1, 0, 0),
		Size = UDim2.fromOffset(capW, h),
		BackgroundTransparency = 1,
		Image = CAP_R,
		Rotation = 180,
		ImageColor3 = color,
		ZIndex = body.ZIndex,
	}, body)
	make("ImageLabel", {
		Name = "CapR",
		Position = UDim2.new(1, -1, 0, 0),
		Size = UDim2.fromOffset(capW, h),
		BackgroundTransparency = 1,
		Image = CAP_R,
		ImageColor3 = color,
		ZIndex = body.ZIndex,
	}, body)
end
-- A slanted chip (SOON, IN QUEUE, LEADER): cyan body, ink label.
local function chip(p: Instance, name: string, label: string, props: { [string]: any }?): Frame
	local h = 30
	local c = make("Frame", {
		Name = name,
		Size = UDim2.fromOffset(0, h),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = ALLY,
		BorderSizePixel = 0,
		ZIndex = 6,
	}, p)
	make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, c)
	slant(c, ALLY, h, 11)
	text(c, "Label", label, 14, INK, { Size = UDim2.fromOffset(0, h), ZIndex = 7 })
	for k, v in props or {} do
		(c :: any)[k] = v
	end
	return c
end
-- A button that pops from its centre (Position is its centre).
local function button(
	p: Instance,
	name: string,
	label: string,
	centre: Vector2,
	size: Vector2,
	fill: Color3,
	ink: Color3,
	textSize: number
): TextButton
	local b = make("TextButton", {
		Name = name,
		AnchorPoint = CENTRE,
		Position = UDim2.fromOffset(centre.X, centre.Y),
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundColor3 = fill,
		BackgroundTransparency = if fill == CARD then CARD_T else 0,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 4,
	}, p)
	corner(b)
	make("UIScale", { Name = "Pop" }, b)
	text(b, "Label", label, textSize, ink, {
		AnchorPoint = CENTRE,
		Position = UDim2.fromScale(0.5, 0.5),
		ZIndex = 6,
	})
	return b
end
-- The round close button: a dark circle with a drawn X (two bars, not a
-- font glyph). Util/CloseButton animates it: on hover the circle fills white,
-- the X turns ink and turns a quarter.
-- The drawn X (two rounded bars) every close / cancel button uses.
local function drawX(p: Instance, size: number, thick: number, color: Color3)
	local glyph = make("Frame", {
		Name = "Glyph",
		AnchorPoint = CENTRE,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		ZIndex = 5,
	}, p)
	for _, r in { 45, -45 } do
		local bar = make("Frame", {
			Name = if r > 0 then "A" else "B",
			AnchorPoint = CENTRE,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(size, thick),
			Rotation = r,
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = 5,
		}, glyph)
		round(bar)
	end
end
local function closeButton(canvas: Instance)
	local close = make("TextButton", {
		Name = "Close",
		AnchorPoint = CENTRE,
		Position = UDim2.fromOffset(1830, 76),
		Size = UDim2.fromOffset(72, 72),
		BackgroundColor3 = CARD,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 3,
	}, canvas)
	round(close)
	make("UIScale", { Name = "Pop" }, close)
	drawX(close, 30, 5, WHITE)
end
local function screen(name: string, order: number, enabled: boolean): ScreenGui
	local old = SG:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	return make("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ScreenInsets = Enum.ScreenInsets.None,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = order,
		Enabled = enabled,
	})
end
-- A full-screen menu: a dark scrim over the blurred world and a 1920 x 1080
-- canvas that the controller fits to the screen.
local function menuCanvas(gui: ScreenGui): Frame
	make("Frame", {
		Name = "Scrim",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = SCRIM,
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		ZIndex = 0,
	}, gui)
	local canvas = make("Frame", {
		Name = "Canvas",
		AnchorPoint = CENTRE,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(1920, 1080),
		BackgroundTransparency = 1,
		ZIndex = 1,
	}, gui)
	make("UIScale", { Name = "Fit" }, canvas)
	return canvas
end
-- Slanted tabs (the Locker's): the selected one is a cyan body with slant ends.
local function tabs(p: Instance, name: string, list: { string }, pos: UDim2, anchor: Vector2): Frame
	local row = make("Frame", {
		Name = name,
		AnchorPoint = anchor,
		Position = pos,
		Size = UDim2.fromOffset(0, 64),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
	}, p)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 30),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, row)
	for i, t in list do
		local on = i == 1
		local tab = make("TextButton", {
			Name = t,
			LayoutOrder = i,
			Size = UDim2.fromOffset(0, 52),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = ALLY,
			BackgroundTransparency = if on then 0 else 1,
			BorderSizePixel = 0,
			Text = "",
			AutoButtonColor = false,
			ZIndex = 3,
		}, row)
		make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, tab)
		slant(tab, ALLY, 52, 17)
		for _, c in tab:GetChildren() do
			if c:IsA("ImageLabel") then
				c.ImageTransparency = if on then 0 else 1
			end
		end
		text(tab, "Label", t, 22, if on then INK else MUTED, { Size = UDim2.fromOffset(0, 52) })
	end
	return row
end
-- A round headshot cell.
local function cell(p: Instance, pos: Vector2, d: number)
	local c = make("Frame", {
		Name = "Cell",
		Position = UDim2.fromOffset(pos.X, pos.Y),
		Size = UDim2.fromOffset(d, d),
		BackgroundColor3 = SCRIM,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		ZIndex = 4,
	}, p)
	round(c)
	local shot = make("ImageLabel", {
		Name = "Headshot",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = "",
		ZIndex = 5,
	}, c)
	round(shot)
end

--------------------------------------------------------------------------------------
-- PLAY MENU
--------------------------------------------------------------------------------------
do
	local gui = screen("PlayMenu", 30, false)
	local canvas = menuCanvas(gui)
	text(canvas, "Title", "PLAY", 68, WHITE, { Position = UDim2.fromOffset(264, 40) })
	text(canvas, "Hint", "CLICK A MODE TO QUEUE", 15, MUTED, {
		Position = UDim2.fromOffset(268, 118),
	})
	closeButton(canvas)

	local grid = make("Frame", {
		Name = "Modes",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, canvas)

	-- A tile: a button centred on its rect (pops from its centre) holding the
	-- art, a fade for the words, the mode name, and its chips.
	local function tile(
		id: string,
		x: number,
		y: number,
		w: number,
		h: number,
		opts: {
			art: string?,
			artTone: number?,
			title: string,
			titleSize: number,
			soon: boolean,
			order: number,
		}
	): TextButton
		local b = make("TextButton", {
			Name = id,
			LayoutOrder = opts.order,
			AnchorPoint = CENTRE,
			Position = UDim2.fromOffset(x + w / 2, y + h / 2),
			Size = UDim2.fromOffset(w, h),
			BackgroundColor3 = CARD,
			BackgroundTransparency = CARD_T,
			BorderSizePixel = 0,
			Text = "",
			AutoButtonColor = false,
			ZIndex = 2,
		}, grid)
		corner(b)
		make("UIScale", { Name = "Pop" }, b)
		b:SetAttribute("Live", not opts.soon)
		local tone = opts.artTone or 0.8
		local art = make("ImageLabel", {
			Name = "Art",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = opts.art or "",
			ImageColor3 = Color3.new(tone, tone, tone),
			ScaleType = Enum.ScaleType.Crop,
			Visible = opts.art ~= nil,
			ZIndex = 2,
		}, b)
		corner(art)
		local shade = make("Frame", {
			Name = "Shade",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = SCRIM,
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			ZIndex = 3,
		}, b)
		corner(shade)
		make("UIGradient", {
			Name = "Fade",
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.85),
				NumberSequenceKeypoint.new(0.55, 0.6),
				NumberSequenceKeypoint.new(1, 0.15),
			}),
		}, shade)
		text(b, "Mode", opts.title, opts.titleSize, WHITE, {
			AnchorPoint = CENTRE,
			Position = UDim2.fromScale(0.5, 0.5),
			TextTransparency = if opts.soon then 0.35 else 0,
		})
		if opts.soon then
			chip(b, "Soon", "SOON", { Position = UDim2.fromOffset(26, 16) })
		else
			local count = make("Frame", {
				Name = "Count",
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 18, 1, -14),
				Size = UDim2.fromOffset(0, 24),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
				ZIndex = 5,
			}, b)
			make("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}, count)
			local dot = make("Frame", {
				Name = "Dot",
				Size = UDim2.fromOffset(10, 10),
				BackgroundColor3 = GREEN,
				BorderSizePixel = 0,
				ZIndex = 6,
			}, count)
			round(dot)
			text(count, "Label", "0 SEARCHING", 15, WHITE, {
				LayoutOrder = 2,
				Size = UDim2.fromOffset(0, 24),
				FontFace = Font.new(BX, BOLD),
			})
			local key = make("Frame", {
				Name = "Key",
				Position = UDim2.fromOffset(16, 16),
				Size = UDim2.fromOffset(34, 34),
				BackgroundColor3 = SCRIM,
				BackgroundTransparency = 0.35,
				BorderSizePixel = 0,
				ZIndex = 5,
			}, b)
			corner(key, 6)
			text(key, "Label", tostring(opts.order), 16, WHITE, {
				AnchorPoint = CENTRE,
				Position = UDim2.fromScale(0.5, 0.5),
				ZIndex = 6,
			})
			chip(b, "InQueue", "IN QUEUE", {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -26, 0, 18),
				Visible = false,
			})
		end
		return b
	end

	-- Owner 2026-11-15: BEGINNER 2V2 (an easier 2v2, made later) takes the
	-- tall tile on the far left; Ranked comes back later. Right of it, the
	-- release modes, and under them the room for more.
	local X0, Y0, G = 264, 232, 14
	local TW, TH = 360, 330 + G + 300
	local beginner = tile("Beginner2v2", X0, Y0, TW, TH, {
		art = ART["2v2"],
		artTone = 0.5,
		title = "BEGINNER",
		titleSize = 46,
		soon = true,
		order = 0,
	})
	local bMode = beginner:WaitForChild("Mode") :: TextLabel
	bMode.Position = UDim2.fromScale(0.5, 0.42)
	bMode.TextTransparency = 0
	text(beginner, "Big", "2V2", 110, WHITE, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.42, 26),
	})
	text(beginner, "Sub", "EASIER LOBBIES WHILE YOU LEARN", 14, MUTED, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -28),
		FontFace = Font.new(BX, BOLD),
	})
	local RX = X0 + TW + G
	local RW = 264 + 1392 - RX
	local W1 = (RW - 2 * G) / 3
	for i, id in { "1v1", "2v2", "3v3" } do
		tile(id, RX + (i - 1) * (W1 + G), Y0, W1, 330, {
			art = ART[id],
			title = string.upper(id),
			titleSize = 92,
			soon = false,
			order = i,
		})
	end
	local W2 = (RW - G) / 2
	tile("4v4", RX, Y0 + 330 + G, W2, 300, {
		art = ART["3v3"],
		artTone = 0.38,
		title = "4V4",
		titleSize = 84,
		soon = true,
		order = 4,
	})
	tile("5v5", RX + W2 + G, Y0 + 330 + G, W2, 300, {
		art = ART["2v2"],
		artTone = 0.38,
		title = "5V5",
		titleSize = 84,
		soon = true,
		order = 5,
	})
	gui.Parent = SG
end

--------------------------------------------------------------------------------------
-- SEARCHING BAR
--------------------------------------------------------------------------------------
do
	local gui = screen("LobbySearch", 20, true)
	local W, H = 700, 96
	local holder = make("Frame", {
		Name = "Top",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 72),
		Size = UDim2.fromOffset(W, H),
		BackgroundTransparency = 1,
	}, gui)
	make("UIScale", { Name = "Fit" }, holder)
	local bar = make("Frame", {
		Name = "Bar",
		AnchorPoint = CENTRE,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = CARD,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Visible = false,
	}, holder)
	corner(bar)
	make("UIScale", { Name = "Pop" }, bar)
	-- the mode in a circle, with a turning ring while it searches
	local m = make("Frame", {
		Name = "Mode",
		Position = UDim2.fromOffset(16, 14),
		Size = UDim2.fromOffset(68, 68),
		BackgroundColor3 = SCRIM,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, bar)
	round(m)
	local ring = make("Frame", {
		Name = "Ring",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 3,
	}, m)
	round(ring)
	local stroke = make("UIStroke", {
		Name = "Stroke",
		Thickness = 4,
		Color = ALLY,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		BorderStrokePosition = Enum.BorderStrokePosition.Inner,
	}, ring)
	make("UIGradient", {
		Name = "Spin",
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(0.501, 0.85),
			NumberSequenceKeypoint.new(1, 0.85),
		}),
	}, stroke)
	text(
		m,
		"Label",
		"2V2",
		20,
		WHITE,
		{ AnchorPoint = CENTRE, Position = UDim2.fromScale(0.5, 0.5) }
	)
	text(bar, "Title", "SEARCHING FOR PLAYERS", 24, WHITE, { Position = UDim2.fromOffset(104, 16) })
	text(bar, "Sub", "2V2  ·  BOTS FILL IN 0:30", 15, ALLY, {
		Position = UDim2.fromOffset(104, 54),
		FontFace = Font.new(BX, BOLD),
	})
	text(bar, "Timer", "0:00", 38, WHITE, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -118, 0.5, 0),
	})
	local cancel = button(
		bar,
		"Cancel",
		"",
		Vector2.new(W - 16 - 42, H / 2),
		Vector2.new(84, 64),
		RED,
		WHITE,
		28
	)
	cancel.ZIndex = 4
	cancel:WaitForChild("Label"):Destroy()
	drawX(cancel, 26, 5, WHITE)
	gui.Parent = SG
end

--------------------------------------------------------------------------------------
-- PARTY MENU
--------------------------------------------------------------------------------------
do
	local gui = screen("PartyMenu", 30, false)
	local canvas = menuCanvas(gui)
	text(canvas, "Title", "PARTY", 68, WHITE, { Position = UDim2.fromOffset(264, 40) })
	closeButton(canvas)

	-- left: your party
	local LX, LW = 264, 392
	local left = make("Frame", {
		Name = "Left",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, canvas)
	text(left, "Head", "YOUR PARTY", 28, WHITE, { Position = UDim2.fromOffset(LX, 160) })
	text(left, "Count", "1 / 3", 22, ALLY, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromOffset(LX + LW, 164),
	})
	local slots = make("Frame", {
		Name = "Slots",
		Position = UDim2.fromOffset(LX, 232),
		Size = UDim2.fromOffset(LW, 3 * 104 + 2 * 12),
		BackgroundTransparency = 1,
	}, left)
	make(
		"UIListLayout",
		{ Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder },
		slots
	)
	for i = 1, 3 do
		local s = make("Frame", {
			Name = "Slot" .. i,
			LayoutOrder = i,
			Size = UDim2.fromOffset(LW, 104),
			BackgroundColor3 = CARD,
			BackgroundTransparency = if i == 1 then CARD_T else 0.55,
			BorderSizePixel = 0,
			ZIndex = 2,
		}, slots)
		corner(s)
		make("UIScale", { Name = "Pop" }, s)
		cell(s, Vector2.new(14, 14), 76)
		text(s, "PlayerName", if i == 1 then "YOU" else "", 24, WHITE, {
			AutomaticSize = Enum.AutomaticSize.None,
			Position = UDim2.fromOffset(106, 22),
			Size = UDim2.fromOffset(LW - 106 - 110, 28),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		text(s, "Sub", "", 15, MUTED, {
			AutomaticSize = Enum.AutomaticSize.None,
			Position = UDim2.fromOffset(106, 56),
			Size = UDim2.fromOffset(LW - 106 - 20, 20),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			FontFace = Font.new(BX, BOLD),
		})
		chip(s, "Lead", "LEADER", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -22, 0, 16),
			Visible = false,
		})
		text(s, "Empty", "EMPTY SLOT", 18, MUTED, {
			AnchorPoint = CENTRE,
			Position = UDim2.fromScale(0.5, 0.5),
			TextTransparency = 0.3,
			Visible = i ~= 1,
		})
		local c = s:WaitForChild("Cell") :: Frame
		c.Visible = i == 1
	end
	local y = 232 + 3 * 104 + 2 * 12 + 26
	button(
		left,
		"InviteFriends",
		"INVITE FRIENDS",
		Vector2.new(LX + LW / 2, y + 34),
		Vector2.new(LW, 68),
		WHITE,
		INK,
		22
	)
	button(
		left,
		"Leave",
		"LEAVE PARTY",
		Vector2.new(LX + LW / 2, y + 68 + 12 + 30),
		Vector2.new(LW, 60),
		CARD,
		RED,
		20
	)
	text(
		left,
		"Help",
		"Your party queues together, on one team. Friends in your Roblox party join it on their own.",
		15,
		MUTED,
		{
			AutomaticSize = Enum.AutomaticSize.None,
			Position = UDim2.fromOffset(LX, y + 68 + 12 + 60 + 22),
			Size = UDim2.fromOffset(LW, 80),
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			FontFace = Font.new(BX, BOLD),
			LineHeight = 1.15,
		}
	)

	-- right: search, filters, everyone you can invite
	local RX, RW = 688, 968
	local search = make("Frame", {
		Name = "Search",
		Position = UDim2.fromOffset(RX, 154),
		Size = UDim2.fromOffset(470, 60),
		BackgroundColor3 = CARD,
		BackgroundTransparency = CARD_T,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, canvas)
	corner(search)
	make("TextBox", {
		Name = "Box",
		Position = UDim2.fromOffset(22, 0),
		Size = UDim2.new(1, -44, 1, 0),
		BackgroundTransparency = 1,
		Text = "",
		PlaceholderText = "SEARCH PLAYERS",
		PlaceholderColor3 = MUTED,
		TextColor3 = WHITE,
		FontFace = Font.new(BX, BOLD),
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		ZIndex = 4,
	}, search)
	tabs(
		canvas,
		"Filters",
		{ "ALL", "FRIENDS", "LOBBY" },
		UDim2.fromOffset(RX + RW - 8, 158),
		Vector2.new(1, 0)
	)
	local list = make("ScrollingFrame", {
		Name = "Grid",
		Position = UDim2.fromOffset(RX, 232),
		Size = UDim2.fromOffset(RW + 18, 800),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 0, -- no visible bar (owner, 2026-11-16)
		ScrollBarImageColor3 = WHITE,
		ScrollBarImageTransparency = 1, -- Thickness 0 still drew a hairline
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 2,
	}, canvas)
	make("UIGridLayout", {
		CellSize = UDim2.fromOffset(314, 132),
		CellPadding = UDim2.fromOffset(13, 13),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, list)
	text(canvas, "Empty", "NO ONE TO INVITE YET", 22, MUTED, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(RX + RW / 2, 330),
		Visible = false,
	})
	gui.Parent = SG
end

--------------------------------------------------------------------------------------
-- TEMPLATE: a player card in the Party menu
--------------------------------------------------------------------------------------
do
	local templates = RS:FindFirstChild("UiTemplates")
		or make("Folder", { Name = "UiTemplates" }, RS)
	local lobby = templates:FindFirstChild("Lobby") or make("Folder", { Name = "Lobby" }, templates)
	local old = lobby:FindFirstChild("PartyPlayerCard")
	if old then
		old:Destroy()
	end
	local card = make("Frame", {
		Name = "PartyPlayerCard",
		Size = UDim2.fromOffset(314, 132),
		BackgroundColor3 = CARD,
		BackgroundTransparency = CARD_T,
		BorderSizePixel = 0,
		ZIndex = 2,
	})
	corner(card)
	cell(card, Vector2.new(14, 24), 84)
	local function line(
		name: string,
		s: string,
		size: number,
		color: Color3,
		y: number,
		bold: boolean
	)
		text(card, name, s, size, color, {
			AutomaticSize = Enum.AutomaticSize.None,
			Position = UDim2.fromOffset(112, y),
			Size = UDim2.fromOffset(188, size + 4),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			FontFace = Font.new(BX, if bold then XB else BOLD),
		})
	end
	line("PlayerName", "PLAYER", 21, WHITE, 16, true)
	line("Sub", "@username", 13, MUTED, 42, false)
	line("Where", "IN LOBBY", 13, ALLY, 62, false)
	button(
		card,
		"Invite",
		"INVITE",
		Vector2.new(112 + 94, 86 + 17),
		Vector2.new(188, 34),
		WHITE,
		INK,
		16
	)
	text(card, "State", "IN YOUR PARTY", 14, GREEN, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromOffset(112, 103),
		Visible = false,
	})
	card.Parent = lobby
end

print("[BuildLobbyMenus] PlayMenu, LobbySearch, PartyMenu and PartyPlayerCard built")
