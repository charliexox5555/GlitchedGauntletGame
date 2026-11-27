--!strict
-- Turns the Locker v3 mockup (tools/studio/BuildLockerV3.luau) into the real screen's templates for
-- src/lobby/client/Controllers/LockerV3Controller.luau (vault/01 Design/Loadout and Power Deck.md, step 2).
-- Run once in Edit mode after BuildLockerV3 (Studio command bar or MCP execute_luau). Re-running is safe.
--   * Left.Guns.List: RowVandal -> RowOwned, RowBulldog -> RowLocked (hidden templates); other mock rows go.
--   * Left.Powers.List.Grid: TileDash -> TileOwned, TileFirewall -> TileLocked; other mock tiles go.
--   * Bottom: a Skins strip (a Template tile inside) and a Toast line.
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
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
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

gui.Enabled = false
gui.ResetOnSpawn = false
return "LockerV3 promoted to templates"
