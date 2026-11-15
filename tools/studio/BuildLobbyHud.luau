--!strict
-- Builds the lobby main HUD (vault/02 Art/UI Lobby HUD.md, mockup v5) in the
-- LOBBY place:
--   StarterGui.LobbyHudScreen              <- src/lobby/client/Util/LobbyHudView
--   ReplicatedStorage.UiTemplates.Lobby.PlayerRow
-- Studio owns them; this is their backup. Paste into the command bar (Edit
-- mode); refuses to run if they exist. Desktop only for now.
--
-- Four groups, each anchored to its screen edge with its own "Fit" UIScale
-- (the script sets it), so they hold the corners on any screen:
--   TopLeft   profile; daily tasks (hidden until a tasks system feeds it)
--   TopRight  the player list
--   Bottom    the bar (Locker, Shop, Pass, Range, Settings), PLAY, party, callout
--   Toast     short messages, top centre
-- Sharp slanted shapes (no pills): near-square corners, slant caps on tags and
-- slabs; the party portraits are circles.

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
local XB = Enum.FontWeight.ExtraBold
local NAVY, NAVY_HI = hex("1C2740"), hex("2B3A5A")
local ALLY, ALLY_CELL = hex("3FE0F2"), hex("0D5C7A")
local GOLD, MUTED, INK, WHITE = hex("FFC83D"), hex("8E98A8"), hex("141A26"), Color3.new(1, 1, 1)
local RED, PURPLE, TEAL = hex("FF4D5E"), hex("B58CFF"), hex("2BD9A8")
local SHADOW = "rbxassetid://121253415859134"
local CAP_R, CAP_L = "rbxassetid://130377997107460", "rbxassetid://75584308608588"
local ICON = {
	Shop = "rbxassetid://134974442051869",
	Locker = "rbxassetid://73637059723267",
	BattlePass = "rbxassetid://133121960419132",
	Range = "rbxassetid://82357119585599",
	Settings = "rbxassetid://85379480378289",
	Coin = "rbxassetid://122645025340088",
}
local CENTRE = Vector2.new(0.5, 0.5)

assert(not SG:FindFirstChild("LobbyHudScreen"), "StarterGui.LobbyHudScreen already exists")

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
		ZIndex = 4,
	}, p)
	for k, v in props or {} do
		(t :: any)[k] = v
	end
	return t
end

local function shadow(p: Instance, x: number, y: number, w: number, h: number, name: string?)
	make("ImageLabel", {
		Name = name or "Shadow",
		Position = UDim2.fromOffset(x - 30, y - 22),
		Size = UDim2.fromOffset(w + 60, h + 60),
		BackgroundTransparency = 1,
		Image = SHADOW,
		ImageColor3 = Color3.new(0, 0, 0),
		ImageTransparency = 0.45,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(48, 48, 80, 80),
		ZIndex = 0,
	}, p)
end

local function corner(p: Instance, r: number?)
	make("UICorner", { CornerRadius = UDim.new(0, r or 2) }, p)
end

-- Angled ends: parallel = both lean the same way; otherwise mirrored.
local function slant(body: GuiObject, color: Color3, h: number, capW: number, parallel: boolean?)
	make("ImageLabel", {
		Name = "CapL",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(0, 1, 0, 0),
		Size = UDim2.fromOffset(capW, h),
		BackgroundTransparency = 1,
		Image = if parallel then CAP_R else CAP_L,
		Rotation = if parallel then 180 else 0,
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

local function group(
	parent: Instance,
	name: string,
	anchor: Vector2,
	pos: UDim2,
	w: number,
	h: number
): Frame
	local g = make("Frame", {
		Name = name,
		AnchorPoint = anchor,
		Position = pos,
		Size = UDim2.fromOffset(w, h),
		BackgroundTransparency = 1,
	}, parent)
	make("UIScale", { Name = "Fit" }, g)
	return g
end

-- Templates -------------------------------------------------------------------
local templates = RS:FindFirstChild("UiTemplates") or make("Folder", { Name = "UiTemplates" }, RS)
local oldT = templates:FindFirstChild("Lobby")
if oldT then
	oldT:Destroy()
end
local folder = make("Folder", { Name = "Lobby" }, templates)
do -- PlayerRow: portrait, name, where they are, win streak and level tags
	local w, h = 340, 44
	local row = make("Frame", {
		Name = "PlayerRow",
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = NAVY,
		BorderSizePixel = 0,
	}, folder)
	corner(row)
	local cell = make("Frame", {
		Name = "Cell",
		Size = UDim2.fromOffset(h, h),
		BackgroundColor3 = ALLY_CELL,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, row)
	corner(cell)
	make(
		"ImageLabel",
		{ Name = "Headshot", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 3 },
		cell
	)
	text(
		row,
		"PlayerName",
		"PLAYER",
		14,
		WHITE,
		{ Position = UDim2.fromOffset(h + 12, 6), TextTruncate = Enum.TextTruncate.AtEnd }
	)
	text(row, "Where", "IN LOBBY", 10, ALLY, { Position = UDim2.fromOffset(h + 12, 25) })
	local lv = make("Frame", {
		Name = "Level",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -18, 0.5, 0),
		Size = UDim2.fromOffset(36, 28),
		BackgroundColor3 = GOLD,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, row)
	corner(lv)
	slant(lv, GOLD, 28, 10, true)
	text(lv, "Value", "1", 14, INK, { AnchorPoint = CENTRE, Position = UDim2.fromScale(0.5, 0.5) })
	-- win streak: the same tag in orange, left of the level
	local ORANGE = hex("FF7A3D")
	local st = make(
		"Frame",
		{
			Name = "Streak",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -72, 0.5, 0),
			Size = UDim2.fromOffset(36, 28),
			BackgroundColor3 = ORANGE,
			BorderSizePixel = 0,
			ZIndex = 2,
		},
		row
	)
	corner(st)
	slant(st, ORANGE, 28, 10, true)
	text(st, "Value", "0", 14, INK, { AnchorPoint = CENTRE, Position = UDim2.fromScale(0.5, 0.5) })
end

-- StarterGui.LobbyHudScreen ---------------------------------------------------
local gui = make("ScreenGui", {
	Name = "LobbyHudScreen",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ScreenInsets = Enum.ScreenInsets.None,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 25,
	Enabled = false, -- the script turns it on (desktop)
})

do -- TopLeft: profile, daily tasks
	local g = group(gui, "TopLeft", Vector2.new(0, 0), UDim2.fromScale(0, 0), 460, 620)
	local x, y, w, h = 40, 68, 300, 56
	shadow(g, x, y, w, h, "ProfileShadow")
	local p = make("Frame", {
		Name = "Profile",
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = NAVY,
		BorderSizePixel = 0,
	}, g)
	corner(p)
	local cell = make("Frame", {
		Name = "Cell",
		Size = UDim2.fromOffset(h, h),
		BackgroundColor3 = ALLY_CELL,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, p)
	corner(cell)
	make(
		"ImageLabel",
		{ Name = "Headshot", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 3 },
		cell
	)
	text(
		p,
		"PlayerName",
		"PLAYER",
		16,
		WHITE,
		{ Position = UDim2.fromOffset(h + 12, 11), TextTruncate = Enum.TextTruncate.AtEnd }
	)
	local bar = make("Frame", {
		Name = "Xp",
		Position = UDim2.fromOffset(h + 12, 36),
		Size = UDim2.fromOffset(150, 5),
		BackgroundTransparency = 1,
	}, p)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 2),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, bar)
	for i = 1, 10 do
		make("Frame", {
			Name = "Seg" .. i,
			LayoutOrder = i,
			Size = UDim2.fromOffset(13.2, 5),
			BackgroundColor3 = ALLY,
			BackgroundTransparency = 0.82,
			BorderSizePixel = 0,
		}, bar)
	end
	local lvW = 56
	make("ImageLabel", {
		Name = "CapL",
		Position = UDim2.fromOffset(w - lvW - 22, 0),
		Size = UDim2.fromOffset(24, h),
		BackgroundTransparency = 1,
		Image = CAP_L,
		ImageColor3 = GOLD,
		ZIndex = 2,
	}, p)
	local lv = make("Frame", {
		Name = "Level",
		Position = UDim2.fromOffset(w - lvW, 0),
		Size = UDim2.fromOffset(lvW, h),
		BackgroundColor3 = GOLD,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, p)
	corner(lv)
	text(lv, "Kicker", "LV", 10, INK, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(lvW / 2 - 2, 8),
		TextTransparency = 0.3,
	})
	text(
		lv,
		"Value",
		"1",
		24,
		INK,
		{ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(lvW / 2 - 2, 20) }
	)

	-- Daily tasks: rows are filled by the script once a tasks system exists.
	local t = make("Frame", {
		Name = "Tasks",
		Position = UDim2.fromOffset(40, 380),
		Size = UDim2.fromOffset(400, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = NAVY,
		BorderSizePixel = 0,
		Visible = false,
	}, g)
	corner(t)
	make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, t)
	make("UIPadding", { PaddingBottom = UDim.new(0, 12) }, t)
	local headRow = make("Frame", {
		Name = "Head",
		LayoutOrder = 0,
		Size = UDim2.fromOffset(400, 40),
		BackgroundTransparency = 1,
	}, t)
	local head = make("Frame", {
		Name = "Block",
		Size = UDim2.fromOffset(190, 40),
		BackgroundColor3 = GOLD,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, headRow)
	corner(head)
	make("ImageLabel", {
		Name = "Cap",
		Position = UDim2.fromOffset(186, 0),
		Size = UDim2.fromOffset(18, 40),
		BackgroundTransparency = 1,
		Image = CAP_R,
		ImageColor3 = GOLD,
		ZIndex = 2,
	}, headRow)
	text(
		head,
		"Label",
		"DAILY TASKS",
		16,
		INK,
		{ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, 0.5, 0) }
	)
	text(
		headRow,
		"Reset",
		"",
		11,
		MUTED,
		{ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0) }
	)
end

do -- TopRight: the player list
	local g = group(gui, "TopRight", Vector2.new(1, 0), UDim2.fromScale(1, 0), 380, 620)
	local w = 340
	local list = make("Frame", {
		Name = "PlayerList",
		Position = UDim2.fromOffset(0, 68),
		Size = UDim2.fromOffset(w, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, g)
	make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, list)
	local head = make("Frame", {
		Name = "Head",
		LayoutOrder = 0,
		Size = UDim2.fromOffset(w, 40),
		BackgroundColor3 = NAVY,
		BorderSizePixel = 0,
	}, list)
	corner(head)
	local block = make("Frame", {
		Name = "Block",
		Size = UDim2.fromOffset(130, 40),
		BackgroundColor3 = ALLY,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, head)
	corner(block)
	make("ImageLabel", {
		Name = "Cap",
		Position = UDim2.fromOffset(126, 0),
		Size = UDim2.fromOffset(18, 40),
		BackgroundTransparency = 1,
		Image = CAP_R,
		ImageColor3 = ALLY,
		ZIndex = 2,
	}, head)
	text(
		block,
		"Label",
		"PLAYERS",
		15,
		INK,
		{ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, 0.5, 0) }
	)
	text(
		head,
		"Count",
		"1 HERE",
		11,
		MUTED,
		{ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 156, 0.5, 0) }
	)
	-- column labels over the streak and level tags
	text(
		head,
		"ColStreak",
		"STREAK",
		9,
		MUTED,
		{ AnchorPoint = CENTRE, Position = UDim2.new(1, -90, 0.5, 0) }
	)
	text(
		head,
		"ColLevel",
		"LV",
		9,
		MUTED,
		{ AnchorPoint = CENTRE, Position = UDim2.new(1, -36, 0.5, 0) }
	)
	make("Frame", {
		Name = "Gap",
		LayoutOrder = 1,
		Size = UDim2.fromOffset(10, 2),
		BackgroundTransparency = 1,
	}, list)
	text(list, "More", "+0 MORE", 11, MUTED, { LayoutOrder = 999, Visible = false })
end

do -- Bottom: bar, PLAY, party, callout
	local W, H = 1000, 270
	local g = group(gui, "Bottom", Vector2.new(0.5, 1), UDim2.fromScale(0.5, 1), W, H)
	local barTop, barH = H - 96, 80
	local itemW = 140
	local items = {
		{ "Locker", "LOCKER", ALLY },
		{ "Shop", "SHOP", GOLD },
		{ "BattlePass", "PASS", PURPLE },
		{ "Range", "RANGE", TEAL },
		{ "Settings", "SETTINGS", WHITE },
	}
	local barW = #items * itemW + 40
	local bx = W / 2 - barW / 2
	shadow(g, bx, barTop, barW, barH, "BarShadow")
	local bar = make("Frame", {
		Name = "Bar",
		Position = UDim2.fromOffset(bx, barTop),
		Size = UDim2.fromOffset(barW, barH),
		BackgroundColor3 = NAVY,
		BorderSizePixel = 0,
	}, g)
	corner(bar)
	slant(bar, NAVY, barH, 34)
	for i, it in items do
		local cx = W / 2 + (i - (#items + 1) / 2) * itemW
		-- the hit area covers the icon and its name; the icon lifts on hover
		local b = make("TextButton", {
			Name = it[1],
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromOffset(cx, barTop - 40),
			Size = UDim2.fromOffset(itemW - 10, barH + 40),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			ZIndex = 5,
		}, g)
		make("ImageLabel", {
			Name = "Icon",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 0, 80),
			Size = UDim2.fromOffset(74, 74),
			BackgroundTransparency = 1,
			Image = ICON[it[1]],
			ImageColor3 = it[3],
			ZIndex = 6,
		}, b)
		text(
			b,
			"Label",
			it[2],
			14,
			WHITE,
			{ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 88), ZIndex = 6 }
		)
		local badge = make("Frame", {
			Name = "Badge",
			AnchorPoint = CENTRE,
			Position = UDim2.new(0.5, 32, 0, 14),
			Size = UDim2.fromOffset(28, 28),
			BackgroundColor3 = RED,
			BorderSizePixel = 0,
			ZIndex = 8,
			Visible = false,
		}, b)
		make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, badge)
		text(
			badge,
			"N",
			"1",
			14,
			WHITE,
			{ AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.fromScale(1, 1), ZIndex = 9 }
		)
	end
	-- PLAY: a fixed holder with a centred inner face (pops from its centre)
	local pw, ph = 320, 84
	local px, py = W / 2 - pw / 2, barTop - 44 - ph
	shadow(g, px + 20, py, pw - 40, ph, "PlayShadow")
	local play = make("TextButton", {
		Name = "Play",
		Position = UDim2.fromOffset(px, py),
		Size = UDim2.fromOffset(pw, ph),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 2,
	}, g)
	local face = make("Frame", {
		Name = "Face",
		AnchorPoint = CENTRE,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, play)
	make("UIScale", { Name = "Pop" }, face)
	local body = make("Frame", {
		Name = "Body",
		Position = UDim2.fromOffset(26, 0),
		Size = UDim2.new(1, -52, 1, 0),
		BackgroundColor3 = GOLD,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, face)
	slant(body, GOLD, ph, 28)
	text(
		face,
		"Title",
		"PLAY",
		44,
		INK,
		{ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(pw / 2, 6) }
	)
	text(face, "Sub", "1V1  ·  2V2  ·  3V3", 11, INK, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(pw / 2, 58),
		TextTransparency = 0.3,
	})
	-- party: you and an invite slot (circles with rings)
	for i = 1, 2 do
		local cx = px + pw + 16 + (i - 1) * 66 + 30
		local cy = py + ph / 2
		local ring = make(if i == 2 then "TextButton" else "Frame", {
			Name = if i == 1 then "PartyYou" else "Invite",
			AnchorPoint = CENTRE,
			Position = UDim2.fromOffset(cx, cy),
			Size = UDim2.fromOffset(60, 60),
			BackgroundColor3 = if i == 1 then ALLY else NAVY_HI,
			BorderSizePixel = 0,
			ZIndex = 2,
		}, g)
		if ring:IsA("TextButton") then
			ring.Text = ""
			ring.AutoButtonColor = false
		end
		make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, ring)
		local disc = make("Frame", {
			Name = "Disc",
			AnchorPoint = CENTRE,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(52, 52),
			BackgroundColor3 = NAVY,
			BorderSizePixel = 0,
			ZIndex = 3,
		}, ring)
		make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, disc)
		if i == 1 then
			local img = make("ImageLabel", {
				Name = "Headshot",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				ZIndex = 4,
			}, disc)
			make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, img)
		else
			text(
				disc,
				"Plus",
				"+",
				26,
				WHITE,
				{ AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.fromScale(1, 1) }
			)
		end
	end
	-- callout: a slanted red tag with a pointer (the script places it over an item)
	local cw, chh = 250, 40
	local callout = make("Frame", {
		Name = "Callout",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromOffset(200, barTop - 66),
		Size = UDim2.fromOffset(cw, chh),
		BackgroundColor3 = RED,
		BorderSizePixel = 0,
		ZIndex = 9,
		Visible = false,
	}, g)
	slant(callout, RED, chh, 14, true)
	text(
		callout,
		"Label",
		"NEW",
		14,
		WHITE,
		{ AnchorPoint = CENTRE, Position = UDim2.fromScale(0.5, 0.5), ZIndex = 10 }
	)
	make("Frame", {
		Name = "Pointer",
		AnchorPoint = CENTRE,
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.fromOffset(16, 16),
		Rotation = 45,
		BackgroundColor3 = RED,
		BorderSizePixel = 0,
		ZIndex = 8,
	}, callout)
end

do -- Toast: top centre, a navy plate led by a slanted colour block
	local g = group(gui, "Toast", Vector2.new(0.5, 0), UDim2.fromScale(0.5, 0), 700, 200)
	local plate = make("Frame", {
		Name = "Plate",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(350, 140),
		Size = UDim2.fromOffset(0, 52),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = NAVY,
		BorderSizePixel = 0,
		Visible = false,
	}, g)
	corner(plate)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 14),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, plate)
	make("UIPadding", { PaddingRight = UDim.new(0, 20) }, plate)
	local kind = make("Frame", {
		Name = "Kind",
		LayoutOrder = 1,
		Size = UDim2.fromOffset(16, 52),
		BackgroundColor3 = ALLY,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, plate)
	make("ImageLabel", {
		Name = "Cap",
		Position = UDim2.new(1, -1, 0, 0),
		Size = UDim2.fromOffset(20, 52),
		BackgroundTransparency = 1,
		Image = CAP_R,
		ImageColor3 = ALLY,
		ZIndex = 2,
	}, kind)
	make(
		"Frame",
		{ Name = "Gap", LayoutOrder = 2, Size = UDim2.fromOffset(8, 2), BackgroundTransparency = 1 },
		plate
	)
	text(plate, "Label", "MESSAGE", 15, WHITE, { LayoutOrder = 3 })
end

gui.Parent = SG
print("LobbyHudScreen built")
