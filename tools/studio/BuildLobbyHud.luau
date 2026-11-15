--!strict
-- Builds the lobby main HUD (vault/02 Art/UI Lobby HUD.md, mockup v5) in the
-- LOBBY place:
--   StarterGui.LobbyTasks, LobbyPlayerList, LobbyBar, LobbyToast, LobbyTopbar (the profile card
--   top left was removed, owner 2026-11-14)
--                                          <- src/lobby/client/Util/LobbyHudView
--   ReplicatedStorage.UiTemplates.Lobby.PlayerRow, PartySlot (the + opens the Party
--   menu, tools/studio/BuildLobbyMenus.luau)
-- Studio owns them; this is their backup. Paste into the command bar (Edit
-- mode); refuses to run if they exist. Desktop only for now.
--
-- Five ScreenGuis, each holding one group anchored to its screen edge with its own "Fit" UIScale
-- (the script sets it), so they hold the corners on any screen:
--   TopLeft   profile; daily tasks (hidden until a tasks system feeds it)
--   TopRight  the player list
--   Bottom    the bar (Locker, Shop, Pass, Range, Settings), PLAY, the party row
--             (you, your Roblox party, +) and its card, callout
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
	-- full-colour flat-faceted icons v2 (ChatGPT, art-source/ui/lobby-icons/*_v2.png,
	-- cropped to one 400 px square)
	Shop = "rbxassetid://75746609493674",
	Locker = "rbxassetid://94062620763078",
	BattlePass = "rbxassetid://124123984170556",
	Range = "rbxassetid://79251886607751",
	Settings = "rbxassetid://139738672487062",
	Coin = "rbxassetid://122645025340088",
}
local CENTRE = Vector2.new(0.5, 0.5)

for _, n in { "LobbyTasks", "LobbyPlayerList", "LobbyBar", "LobbyToast", "LobbyTopbar" } do
	assert(not SG:FindFirstChild(n), "StarterGui." .. n .. " already exists")
end

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

-- A party slot: a fixed 60x72 holder with a centred ring (its "Pop" UIScale
-- pops it from the centre), the disc with a headshot (or the +), and a small
-- gold LEAD tag under the leader.
local function partySlot(
	parent: Instance,
	name: string,
	ringColor: Color3,
	plus: boolean?
): GuiObject
	local holder = make(if plus then "TextButton" else "Frame", {
		Name = name,
		Size = UDim2.fromOffset(60, 72),
		BackgroundTransparency = 1,
		ZIndex = 2,
	}, parent)
	if holder:IsA("TextButton") then
		holder.Text = ""
		holder.AutoButtonColor = false
	end
	local ring = make("Frame", {
		Name = "Ring",
		AnchorPoint = CENTRE,
		Position = UDim2.fromOffset(30, 32),
		Size = UDim2.fromOffset(60, 60),
		BackgroundColor3 = ringColor,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, holder)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, ring)
	make("UIScale", { Name = "Pop" }, ring)
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
	if plus then
		text(
			disc,
			"Plus",
			"+",
			26,
			WHITE,
			{ AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.fromScale(1, 1) }
		)
	else
		local img = make("ImageLabel", {
			Name = "Headshot",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 4,
		}, disc)
		make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, img)
		local lead = make("Frame", {
			Name = "Lead",
			AnchorPoint = CENTRE,
			Position = UDim2.new(0.5, 0, 1, 2),
			Size = UDim2.fromOffset(34, 14),
			BackgroundColor3 = GOLD,
			BorderSizePixel = 0,
			ZIndex = 6,
			Visible = false,
		}, ring)
		slant(lead, GOLD, 14, 6, true)
		text(
			lead,
			"Label",
			"LEAD",
			9,
			INK,
			{ AnchorPoint = CENTRE, Position = UDim2.fromScale(0.5, 0.5), ZIndex = 7 }
		)
	end
	return holder
end

-- Bar item look (owner picked concept A + C's hover, bar_concepts_v2.png):
-- the name sits on a slanted tag in the item's colour, always on; on hover
-- the script shows a big colour plate behind the icon with a » (it pops from
-- its bottom-centre via its "Pop" UIScale).
local function decorateItem(b: GuiObject, color: Color3, w: number)
	local label = b:FindFirstChild("Label") :: TextLabel
	local tag = make("Frame", {
		Name = "Tag",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 84),
		Size = UDim2.fromOffset(w - 44, 28),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = 6,
	}, b)
	slant(tag, color, 28, 10, true)
	label.Parent = tag
	label.AnchorPoint = CENTRE
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.TextColor3 = INK
	label.ZIndex = 7
	local plate = make("Frame", {
		Name = "Plate",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.fromOffset(w - 36, 118),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = 3,
		Visible = false,
	}, b)
	slant(plate, color, 118, 18, true)
	make("UIScale", { Name = "Pop" }, plate)
	text(plate, "Chevrons", "»", 30, WHITE, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 6, 0, 0),
		ZIndex = 4,
	})
end

-- A small gold slanted INVITE button (player rows, the party card's list).
local function inviteButton(parent: Instance, z: number): TextButton
	local b = make("TextButton", {
		Name = "Invite",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.5, 0),
		Size = UDim2.fromOffset(64, 26),
		BackgroundColor3 = GOLD,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		ZIndex = z,
	}, parent)
	slant(b, GOLD, 26, 8, true)
	text(
		b,
		"Label",
		"INVITE",
		11,
		INK,
		{ AnchorPoint = CENTRE, Position = UDim2.fromScale(0.5, 0.5), ZIndex = z + 1 }
	)
	return b
end

local function invitePopup(g: Instance)
	local w, h = 440, 100
	local pop = make("Frame", {
		Name = "Invite",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(350, 206),
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = NAVY,
		BorderSizePixel = 0,
		ZIndex = 20,
		Visible = false,
	}, g)
	corner(pop)
	make("UIScale", { Name = "Pop" }, pop)
	local cell = make("Frame", {
		Name = "Cell",
		Position = UDim2.fromOffset(14, 14),
		Size = UDim2.fromOffset(72, 72),
		BackgroundColor3 = ALLY,
		BorderSizePixel = 0,
		ZIndex = 21,
	}, pop)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, cell)
	local disc = make("Frame", {
		Name = "Disc",
		AnchorPoint = CENTRE,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(64, 64),
		BackgroundColor3 = NAVY_HI,
		BorderSizePixel = 0,
		ZIndex = 22,
	}, cell)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, disc)
	local shot = make("ImageLabel", {
		Name = "Headshot",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 23,
	}, disc)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, shot)
	text(
		pop,
		"Kicker",
		"PARTY INVITE",
		10,
		ALLY,
		{ Position = UDim2.fromOffset(102, 14), ZIndex = 22 }
	)
	text(pop, "PlayerName", "PLAYER", 18, WHITE, {
		Position = UDim2.fromOffset(102, 28),
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 22,
	})
	text(pop, "Timer", "30", 12, MUTED, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 14),
		ZIndex = 22,
	})
	local accept = make("TextButton", {
		Name = "Accept",
		Position = UDim2.fromOffset(112, 60),
		Size = UDim2.fromOffset(130, 28),
		BackgroundColor3 = GOLD,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 22,
	}, pop)
	slant(accept, GOLD, 28, 9, true)
	text(
		accept,
		"Label",
		"ACCEPT",
		12,
		INK,
		{ AnchorPoint = CENTRE, Position = UDim2.fromScale(0.5, 0.5), ZIndex = 23 }
	)
	local decline = make("TextButton", {
		Name = "Decline",
		Position = UDim2.fromOffset(266, 60),
		Size = UDim2.fromOffset(130, 28),
		BackgroundColor3 = NAVY_HI,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 22,
	}, pop)
	slant(decline, NAVY_HI, 28, 9, true)
	text(
		decline,
		"Label",
		"DECLINE",
		12,
		WHITE,
		{ AnchorPoint = CENTRE, Position = UDim2.fromScale(0.5, 0.5), ZIndex = 23 }
	)
end

-- Topbar buttons (owner: "a top bar button above the leaderboard for both
-- settings and opening/closing leaderboard", like TopbarPlus): our own two
-- buttons in Roblox's top bar row, sized and coloured like Roblox's own
-- (44 px dark circles in the 58 px row), right-aligned above the player list.
-- ScreenInsets = TopbarSafeInsets gives exactly the free part of that row, so
-- no script places them. The leaderboard icon is drawn (three list rows).
local SETTINGS_GEAR = "rbxassetid://85379480378289" -- flat white gear
local function topbarButton(parent: Instance, name: string, order: number): TextButton
	local b = make("TextButton", {
		Name = name,
		LayoutOrder = order,
		Size = UDim2.fromOffset(44, 44),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
	}, parent)
	local face = make("Frame", {
		Name = "Face",
		AnchorPoint = CENTRE,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
	}, b)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, face)
	make("UIScale", { Name = "Pop" }, face)
	return b
end

local function topbar(gui: ScreenGui)
	gui.ScreenInsets = Enum.ScreenInsets.TopbarSafeInsets
	local bar = make("Frame", {
		Name = "Bar",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -40, 0.5, 0), -- lines up with the player list
		Size = UDim2.fromOffset(0, 44),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
	}, gui)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, bar)
	local settings = topbarButton(bar, "Settings", 1)
	make("ImageLabel", {
		Name = "Icon",
		AnchorPoint = CENTRE,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(26, 26),
		BackgroundTransparency = 1,
		Image = SETTINGS_GEAR,
		ImageColor3 = WHITE,
		ScaleType = Enum.ScaleType.Fit,
	}, settings:FindFirstChild("Face"))
	local board = topbarButton(bar, "Leaderboard", 2)
	local icon = make("Frame", {
		Name = "Icon",
		AnchorPoint = CENTRE,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(22, 18),
		BackgroundTransparency = 1,
	}, board:FindFirstChild("Face"))
	for i = 0, 2 do
		make("Frame", {
			Name = "Dot" .. i,
			Position = UDim2.fromOffset(0, i * 7),
			Size = UDim2.fromOffset(4, 4),
			BackgroundColor3 = WHITE,
			BorderSizePixel = 0,
		}, icon)
		make("Frame", {
			Name = "Line" .. i,
			Position = UDim2.fromOffset(7, i * 7),
			Size = UDim2.fromOffset(15, 4),
			BackgroundColor3 = WHITE,
			BorderSizePixel = 0,
		}, icon)
	end
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
	local st = make("Frame", {
		Name = "Streak",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -72, 0.5, 0),
		Size = UDim2.fromOffset(36, 28),
		BackgroundColor3 = ORANGE,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, row)
	corner(st)
	slant(st, ORANGE, 28, 10, true)
	text(st, "Value", "0", 14, INK, { AnchorPoint = CENTRE, Position = UDim2.fromScale(0.5, 0.5) })
	-- hovering someone else's row shows INVITE over the tags (the script)
	inviteButton(row, 8).Visible = false
end

partySlot(folder, "PartySlot", ALLY) -- a friend in your Roblox party

-- One ScreenGui per part (like the match's TopBar / BottomHud / Notify), all
-- in StarterGui so they can be edited in Explorer. Enabled = shown in Studio;
-- the script turns them off on phones (and the tasks / toast until needed).
local made: { ScreenGui } = {}
local function screen(name: string, enabled: boolean): ScreenGui
	local g = make("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ScreenInsets = Enum.ScreenInsets.None,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 25,
		Enabled = enabled,
	})
	table.insert(made, g)
	return g
end

do -- TopLeft: daily tasks (hidden until a tasks system feeds it)
	-- Daily tasks: rows are filled by the script once a tasks system exists.
	local t = make(
		"Frame",
		{
			Name = "Tasks",
			Position = UDim2.fromOffset(40, 380),
			Size = UDim2.fromOffset(400, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = NAVY,
			BorderSizePixel = 0,
			Visible = false,
		},
		group(
			screen("LobbyTasks", false),
			"TopLeft",
			Vector2.new(0, 0),
			UDim2.fromScale(0, 0),
			460,
			620
		)
	)
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
	local g = group(
		screen("LobbyPlayerList", true),
		"TopRight",
		Vector2.new(1, 0),
		UDim2.fromScale(1, 0),
		380,
		620
	)
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
	local g = group(
		screen("LobbyBar", true),
		"Bottom",
		Vector2.new(0.5, 1),
		UDim2.fromScale(0.5, 1),
		W,
		H
	)
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
	slant(bar, NAVY, barH, 34, true)
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
			ScaleType = Enum.ScaleType.Fit, -- the colour is in the art
			ZIndex = 6,
		}, b)
		make("UIScale", { Name = "Pop" }, b:FindFirstChild("Icon"))
		text(
			b,
			"Label",
			it[2],
			14,
			WHITE,
			{ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 88), ZIndex = 6 }
		)
		decorateItem(b, it[3], itemW)
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
	-- party: you, your Roblox party here, and the + (a row that grows; the
	-- script clones UiTemplates.Lobby.PartySlot for each friend)
	local party = make("Frame", {
		Name = "Party",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromOffset(px + pw + 14, py + ph / 2 + 6),
		Size = UDim2.fromOffset(0, 72),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		ZIndex = 2,
	}, g)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, party)
	local you = partySlot(party, "You", ALLY)
	you.LayoutOrder = 1
	local inviteSlot = partySlot(party, "Invite", NAVY_HI, true)
	inviteSlot.LayoutOrder = 99
	-- the party card opens from the +
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
	local g = group(
		screen("LobbyToast", true),
		"Toast",
		Vector2.new(0.5, 0),
		UDim2.fromScale(0.5, 0),
		700,
		200
	)
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
	make("UIScale", { Name = "Pop" }, plate)
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
	invitePopup(g)
end

topbar(screen("LobbyTopbar", true))

for _, g in made do
	g.Parent = SG
end
print("Lobby HUD ScreenGuis built")
