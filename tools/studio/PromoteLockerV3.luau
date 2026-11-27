--!strict
-- Turns the Locker v3 mockup (tools/studio/BuildLockerV3.luau) into the real screen's templates for
-- src/lobby/client/Controllers/LockerV3Controller.luau (vault/01 Design/Loadout and Power Deck.md, step 2).
-- Run once in Edit mode after BuildLockerV3 (Studio command bar or MCP execute_luau). Re-running is safe.
--   * Left.Guns.List: RowVandal -> RowOwned, RowBulldog -> RowLocked (hidden templates); other mock rows go.
--   * Left.Powers.List.Grid: TileDash -> TileOwned, TileFirewall -> TileLocked; other mock tiles go.
--   * Bottom: a Skins strip (a Template tile inside, with Lock and Tier for skins not owned yet) and a Toast line.
--   * Confirm: the unlock confirmation (Shade, Box.Body: Title, Render, Price.Amount, Sub, Cancel, Ok).
--   * the LOCKER title moves from the top-left corner (under Roblox's buttons) to the left of the tabs.
--   * the mockup's Preview script and the showcase guns go; ReplicatedStorage.LockerV3Stage keeps the PowerCard.

local SG = game:GetService("StarterGui")
local RS = game:GetService("ReplicatedStorage")

local UiPlates = require(RS.Shared.Config.UiPlates)

-- a child by dotted path; errors (the run stops) when the mockup isn't the expected shape
local function need(parent: Instance, path: string): any
	local node: Instance = parent
	for name in string.gmatch(path, "[^%.]+") do
		local nextNode = node:FindFirstChild(name)
		assert(
			nextNode,
			"missing "
				.. name
				.. " under "
				.. node:GetFullName()
				.. " (run tools/studio/BuildLockerV3.luau first)"
		)
		node = nextNode
	end
	return node
end

local gui = need(SG, "LockerV3") :: ScreenGui
local HEAVY = Font.new("rbxassetid://12187365977", Enum.FontWeight.Heavy)
local PANEL = Color3.fromHex("07080B")
local CYAN = Color3.fromHex("3FE0F2")

local function rename(parent: Instance, from: string, to: string)
	local o = parent:FindFirstChild(from)
	if o then
		o.Name = to
	end
end

local preview = gui:FindFirstChild("Preview")
if preview then
	preview:Destroy()
end
local stage = RS:FindFirstChild("LockerV3Stage")
local showcase = stage and stage:FindFirstChild("Showcase")
if showcase then
	showcase:Destroy()
end

-- gun rows
local list = need(gui, "Left.Guns.List") :: Instance
rename(list, "RowVandal", "RowOwned")
rename(list, "RowBulldog", "RowLocked")
for _, r in list:GetChildren() do
	if r:IsA("GuiButton") and r.Name ~= "RowOwned" and r.Name ~= "RowLocked" then
		r:Destroy()
	end
end
for _, name in { "RowOwned", "RowLocked" } do
	local r = need(list, name) :: GuiButton
	r.Visible = false
	for _, a in
		{ "Gun", "GunName", "Role", "Blurb", "Owned", "Level", "Price", "Equipped", "SlotName" }
	do
		r:SetAttribute(a, nil)
	end
	local bg = need(r, "Bg") :: ImageLabel
	bg.ImageColor3, bg.ImageTransparency = PANEL, 0.3
	local sel = need(r, "Sel") :: GuiObject
	sel.Visible = false
end

-- power tiles
local grid = need(gui, "Left.Powers.List.Grid") :: Instance
rename(grid, "TileDash", "TileOwned")
rename(grid, "TileFirewall", "TileLocked")
for _, t in grid:GetChildren() do
	if t:IsA("GuiButton") and t.Name ~= "TileOwned" and t.Name ~= "TileLocked" then
		t:Destroy()
	end
end
for _, name in { "TileOwned", "TileLocked" } do
	local t = need(grid, name) :: GuiButton
	t.Visible = false
	for _, a in { "Power", "Owned", "InDeck", "Level" } do
		t:SetAttribute(a, nil)
	end
	local sel = need(t, "Sel") :: GuiObject
	sel.Visible = false
end

-- the skin strip and the toast (bottom, above the round buttons)
local bottom = need(gui, "Bottom") :: Frame
for _, n in { "Skins", "Toast" } do
	local o = bottom:FindFirstChild(n)
	if o then
		o:Destroy()
	end
end
local strip = Instance.new("ScrollingFrame")
strip.Name = "Skins"
strip.AnchorPoint = Vector2.new(0.5, 1)
strip.Position = UDim2.new(0.5, 0, 0, 34)
strip.Size = UDim2.fromOffset(1060, 128)
strip.BackgroundTransparency = 1
strip.BorderSizePixel = 0
strip.ScrollingDirection = Enum.ScrollingDirection.X
strip.AutomaticCanvasSize = Enum.AutomaticSize.X
strip.CanvasSize = UDim2.new()
strip.ScrollBarThickness = 4
strip.ScrollBarImageTransparency = 0.6
strip.Active = true
strip.Visible = false
local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
layout.Padding = UDim.new(0, 10)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = strip
local tpl = Instance.new("ImageButton")
tpl.Name = "Template"
tpl.BackgroundTransparency = 1
tpl.Image = ""
tpl.AutoButtonColor = false
tpl.Size = UDim2.fromOffset(190, 116)
tpl.Visible = false
local bg = Instance.new("ImageLabel")
bg.Name = "Bg"
bg.BackgroundTransparency = 1
bg.Image = UiPlates.cut1.image
bg.ScaleType = Enum.ScaleType.Slice
bg.SliceCenter = UiPlates.cut1.slice
bg.SliceScale = 0.6
bg.ImageColor3 = PANEL
bg.ImageTransparency = 0.25
bg.Size = UDim2.fromScale(1, 1)
bg.Parent = tpl
local art = Instance.new("ImageLabel")
art.Name = "Art"
art.BackgroundTransparency = 1
art.ScaleType = Enum.ScaleType.Fit
art.Position = UDim2.fromOffset(12, 22)
art.Size = UDim2.fromOffset(166, 58)
art.ZIndex = 2
art.Parent = tpl
local function text(name: string, t: string, size: number, color: Color3, pos: UDim2): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Text = t
	l.FontFace = HEAVY
	l.TextSize = size
	l.TextColor3 = color
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Position = pos
	l.Size = UDim2.fromOffset(170, size + 4)
	l.ZIndex = 3
	l.Parent = tpl
	return l
end
text("Name", "DEFAULT", 16, Color3.new(1, 1, 1), UDim2.fromOffset(12, 88))
text("On", "EQUIPPED", 12, CYAN, UDim2.fromOffset(12, 6))
tpl.Parent = strip
strip.Parent = bottom
local fit = bottom:FindFirstChild("Fit")
assert(fit, "Bottom.Fit")

local toast = Instance.new("TextLabel")
toast.Name = "Toast"
toast.BackgroundTransparency = 1
toast.AnchorPoint = Vector2.new(0.5, 1)
toast.Position = UDim2.new(0.5, 0, 0, -104)
toast.Size = UDim2.fromOffset(760, 30)
toast.FontFace = HEAVY
toast.TextSize = 22
toast.TextColor3 = Color3.new(1, 1, 1)
toast.TextTransparency = 1
toast.Text = ""
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.new(0, 0, 0)
stroke.Thickness = 2
stroke.Transparency = 0.5
stroke.Parent = toast
toast.Parent = bottom

-- the LOCKER title sits next to the tabs: Roblox's own buttons cover the top-left corner (owner 2026-11-26)
local title = gui:FindFirstChild("Left") and need(gui, "Left"):FindFirstChild("Title")
	or need(gui, "Top"):FindFirstChild("Title")
if title and title:IsA("TextLabel") then
	title.Parent = need(gui, "Top")
	title.AnchorPoint = Vector2.new(1, 0)
	title.Position = UDim2.fromOffset(112, 33)
	title.Size = UDim2.fromOffset(300, 52)
	title.TextXAlignment = Enum.TextXAlignment.Right
	title.TextSize = 42
end

-- the skin tile shows locked skins too (owner 2026-11-26: "show all available skins ... what they work towards")
local skinTpl = need(gui, "Bottom.Skins.Template") :: ImageButton
if not skinTpl:FindFirstChild("Lock") then
	local lock = Instance.new("ImageLabel")
	lock.Name = "Lock"
	lock.BackgroundTransparency = 1
	lock.Image = "rbxassetid://125270489944006" -- Theme.ICON.Lock
	lock.AnchorPoint = Vector2.new(1, 0)
	lock.Position = UDim2.new(1, -10, 0, 88)
	lock.Size = UDim2.fromOffset(18, 18)
	lock.ZIndex = 3
	lock.Visible = false
	lock.Parent = skinTpl
	local tier = text("Tier", "EPIC", 12, Color3.fromHex("B58CFF"), UDim2.fromOffset(12, 6))
	tier.AnchorPoint = Vector2.new(1, 0)
	tier.Position = UDim2.new(1, -10, 0, 6)
	tier.TextXAlignment = Enum.TextXAlignment.Right
	tier.Parent = skinTpl
end

-- the unlock confirmation (owner 2026-11-26: "buying with coins should open up a confirmation window")
local oldConfirm = gui:FindFirstChild("Confirm")
if oldConfirm then
	oldConfirm:Destroy()
end
local confirm = Instance.new("Frame")
confirm.Name = "Confirm"
confirm.BackgroundTransparency = 1
confirm.Size = UDim2.fromScale(1, 1)
confirm.ZIndex = 50
confirm.Visible = false
local shade = Instance.new("TextButton")
shade.Name = "Shade"
shade.Text = ""
shade.AutoButtonColor = false
shade.BackgroundColor3 = Color3.new(0, 0, 0)
shade.BackgroundTransparency = 0.45
shade.BorderSizePixel = 0
shade.Size = UDim2.fromScale(1, 1)
shade.ZIndex = 50
shade.Parent = confirm
local box = Instance.new("Frame")
box.Name = "Box"
box.BackgroundTransparency = 1
box.AnchorPoint = Vector2.new(0.5, 0.5)
box.Position = UDim2.fromScale(0.5, 0.5)
box.Size = UDim2.fromOffset(620, 360)
box.ZIndex = 51
box.Active = true
box.Parent = confirm
local boxFit = Instance.new("UIScale")
boxFit.Name = "Fit"
boxFit.Parent = box
local body = Instance.new("Frame")
body.Name = "Body"
body.BackgroundTransparency = 1
body.AnchorPoint = Vector2.new(0.5, 0.5)
body.Position = UDim2.fromScale(0.5, 0.5)
body.Size = UDim2.fromScale(1, 1)
body.ZIndex = 51
body.Parent = box
local pop = Instance.new("UIScale")
pop.Name = "Pop"
pop.Parent = body
local plate = Instance.new("ImageLabel")
plate.Name = "Bg"
plate.BackgroundTransparency = 1
plate.Image = UiPlates.cut1.image
plate.ScaleType = Enum.ScaleType.Slice
plate.SliceCenter = UiPlates.cut1.slice
plate.SliceScale = 0.8
plate.ImageColor3 = Color3.fromHex("0C0D11")
plate.ImageTransparency = 0.04
plate.Size = UDim2.fromScale(1, 1)
plate.ZIndex = 51
plate.Parent = body
local function boxText(
	name: string,
	t: string,
	size: number,
	font: Font,
	color: Color3,
	y: number
): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Text = t
	l.FontFace = font
	l.TextSize = size
	l.TextColor3 = color
	l.Position = UDim2.fromOffset(0, y)
	l.Size = UDim2.new(1, 0, 0, size + 6)
	l.ZIndex = 53
	l.Parent = body
	return l
end
boxText("Title", "UNLOCK PUMP?", 38, HEAVY, Color3.new(1, 1, 1), 26)
local render = Instance.new("ImageLabel")
render.Name = "Render"
render.BackgroundTransparency = 1
render.ScaleType = Enum.ScaleType.Fit
render.AnchorPoint = Vector2.new(0.5, 0)
render.Position = UDim2.new(0.5, 0, 0, 80)
render.Size = UDim2.fromOffset(320, 110)
render.ZIndex = 52
render.Parent = body
local priceRow = Instance.new("Frame")
priceRow.Name = "Price"
priceRow.BackgroundTransparency = 1
priceRow.AnchorPoint = Vector2.new(0.5, 0)
priceRow.Position = UDim2.new(0.5, 0, 0, 196)
priceRow.Size = UDim2.fromOffset(0, 40)
priceRow.AutomaticSize = Enum.AutomaticSize.X
priceRow.ZIndex = 52
priceRow.Parent = body
local rowLayout = Instance.new("UIListLayout")
rowLayout.FillDirection = Enum.FillDirection.Horizontal
rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
rowLayout.Padding = UDim.new(0, 10)
rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
rowLayout.Parent = priceRow
local coin = Instance.new("ImageLabel")
coin.Name = "Coin"
coin.BackgroundTransparency = 1
coin.Image = "rbxassetid://122645025340088"
coin.Size = UDim2.fromOffset(36, 36)
coin.LayoutOrder = 1
coin.ZIndex = 53
coin.Parent = priceRow
local amount = Instance.new("TextLabel")
amount.Name = "Amount"
amount.BackgroundTransparency = 1
amount.Text = "600"
amount.FontFace = HEAVY
amount.TextSize = 34
amount.TextColor3 = Color3.new(1, 1, 1)
amount.Size = UDim2.fromOffset(0, 40)
amount.AutomaticSize = Enum.AutomaticSize.X
amount.LayoutOrder = 2
amount.ZIndex = 53
amount.Parent = priceRow
boxText(
	"Sub",
	"You'll have 222 coins left",
	16,
	Font.new("rbxassetid://12187365977", Enum.FontWeight.Medium),
	Color3.fromHex("B4B9C4"),
	240
)
-- the buttons: copies of the screen's own chunky buttons (dark = cancel, gold = the one act-now thing)
local cancel = need(gui, "Right.Stack.GunOwned.Equip.Button"):Clone() :: GuiButton
cancel.Name = "Cancel"
cancel.Position = UDim2.fromOffset(40, 274)
cancel.Size = UDim2.fromOffset(250, 62)
cancel.ZIndex = 54
cancel.Parent = body
local ok = need(gui, "Right.Stack.GunLocked.Unlock.Buy.Button"):Clone() :: GuiButton
ok.Name = "Ok"
ok.Position = UDim2.fromOffset(330, 274)
ok.Size = UDim2.fromOffset(250, 62)
ok.ZIndex = 54
ok.Parent = body
for _, b in { cancel, ok } do
	for _, d in b:GetDescendants() do
		if d:IsA("GuiObject") then
			d.ZIndex = 55
		end
	end
end
local cancelLabel = cancel:FindFirstChild("Label")
if cancelLabel and cancelLabel:IsA("TextLabel") then
	cancelLabel.Text = "CANCEL"
end
local okLabel = ok:FindFirstChild("Label")
if okLabel and okLabel:IsA("TextLabel") then
	okLabel.Text = "UNLOCK"
end
confirm.Parent = gui

gui.Enabled = false
gui.ResetOnSpawn = false
return "LockerV3 promoted to templates"
