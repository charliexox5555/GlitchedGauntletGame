--!strict
-- Fills a case's CONTENTS list, grouped like RIVALS (owner 2026-11-20: single-skin
-- odds alone read "oh my god, 0.5%"): one row per skin line with its combined odds
-- (Shared/SkinCases.groups), click it to open the line's skins underneath, each
-- with its own odds. Rows are UiTemplates.Lobby.ShopOddsRow clones: a tier-coloured
-- cell with the line's emblem or the skin's picture, the name in the tier colour,
-- the tier and what it's for, the %. Odds are before owned skins are re-rolled.
-- Used by the Shop, the Backpack and the Season Pass.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemIcons = require(ReplicatedStorage.Shared.ItemIcons)
local Locker = require(ReplicatedStorage.Shared.Locker)
local ShopCatalog = require(ReplicatedStorage.Lobby.ShopCatalog)
local SkinCases = require(ReplicatedStorage.Shared.SkinCases)
local Skins = require(ReplicatedStorage.Shared.Config.Skins)

local OddsList = {}

local INDENT = 46 -- px a line's skins sit in from its header
local ARROW_W = 26

local function child<T>(parent: Instance, name: string): T
	return (parent:WaitForChild(name) :: any) :: T
end

local function shiftX(obj: GuiObject, dx: number)
	obj.Position = obj.Position + UDim2.fromOffset(dx, 0)
end

-- the cell shows a picture on the tier colour; with no picture, the line's own
-- colour and its initial
local function picture(row: Frame, image: string?, tint: Color3?, line: string?)
	local cell = child(row, "Cell") :: Frame
	if not image or image == "" then
		if line and Locker.COLORS[line] then
			cell.BackgroundColor3 = Locker.COLORS[line]
		end
		local letter = Instance.new("TextLabel")
		letter.Name = "Letter"
		letter.BackgroundTransparency = 1
		letter.Size = UDim2.fromScale(1, 1)
		letter.FontFace = (child(row, "Name") :: TextLabel).FontFace
		letter.TextSize = 26
		letter.TextColor3 = Color3.new(1, 1, 1)
		letter.Text = string.sub(string.upper(line or "?"), 1, 1)
		letter.ZIndex = cell.ZIndex + 1
		letter.Parent = cell
		return
	end
	local pic = Instance.new("ImageLabel")
	pic.Name = "Pic"
	pic.BackgroundTransparency = 1
	pic.AnchorPoint = Vector2.new(0.5, 0.5)
	pic.Position = UDim2.fromScale(0.5, 0.5)
	pic.Size = UDim2.fromScale(0.86, 0.86)
	pic.ScaleType = Enum.ScaleType.Fit
	pic.Image = image or ""
	pic.ImageColor3 = tint or Color3.new(1, 1, 1)
	pic.ZIndex = cell.ZIndex + 1
	pic.Parent = cell
end

local function gunWord(gun: string, line: string): string
	return if gun == "Knife" and line == "PopCircuit" then "BAT" else string.upper(gun)
end

function OddsList.fill(list: ScrollingFrame, case: ShopCatalog.Case)
	for _, c in list:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	local layout = list:FindFirstChildWhichIsA("UIListLayout")
	if layout then
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Right -- indented skins hug the right
	end
	local template = ReplicatedStorage:WaitForChild("UiTemplates")
		:WaitForChild("Lobby")
		:WaitForChild("ShopOddsRow") :: Frame
	local order = 0
	for _, g in SkinCases.groups(case.id) do
		local tier = Skins.TIERS[g.tier]
		-- the line's row
		order += 1
		local head = template:Clone()
		head.Name = "Line_" .. g.line .. "_" .. g.tier
		head.LayoutOrder = order
		for _, n in { "Cell", "Name", "Sub" } do
			shiftX(child(head, n) :: GuiObject, ARROW_W)
		end
		local cell = child(head, "Cell") :: Frame
		cell.BackgroundColor3 = tier.color
		local emblem = if g.knives then nil else Locker.EMBLEMS[g.line]
		if emblem then
			picture(head, emblem, Color3.new(1, 1, 1))
		else
			local first = g.entries[1]
			local pic = if first then ItemIcons.get(first.gun, first.line) else nil
			picture(head, pic, nil, if g.knives then "Knife" else g.line)
		end
		local name = child(head, "Name") :: TextLabel
		name.Text = if g.knives then "KNIVES" else string.upper(g.line)
		name.TextColor3 = tier.color
		local n = #g.entries;
		(child(head, "Sub") :: TextLabel).Text = if g.knives
			then string.format("%s KNIFE SKIN, RANDOM LINE  ·  %d KNIVES", tier.name, n)
			elseif n == 1 then string.format(
				"%s SKIN FOR %s",
				tier.name,
				gunWord(g.entries[1].gun, g.line)
			)
			else string.format("%s SKIN FOR A RANDOM GUN  ·  %d GUNS", tier.name, n);
		(child(head, "Pct") :: TextLabel).Text = ShopCatalog.formatOdds(g.odds)
		local arrow = Instance.new("TextLabel")
		arrow.Name = "Arrow"
		arrow.BackgroundTransparency = 1
		arrow.AnchorPoint = Vector2.new(0, 0.5)
		arrow.Position = UDim2.new(0, 8, 0.5, 0)
		arrow.Size = UDim2.fromOffset(ARROW_W, 30)
		arrow.FontFace = name.FontFace
		arrow.TextSize = 18
		arrow.TextColor3 = Color3.fromHex("9F9FA2")
		arrow.Text = "▶"
		arrow.ZIndex = name.ZIndex
		arrow.Parent = head
		local toggle = Instance.new("TextButton")
		toggle.Name = "Toggle"
		toggle.BackgroundTransparency = 1
		toggle.Text = ""
		toggle.Size = UDim2.fromScale(1, 1)
		toggle.ZIndex = name.ZIndex + 2
		toggle.Parent = head
		head.Parent = list

		-- its skins, hidden until the line is opened
		local rows: { Frame } = {}
		for _, e in g.entries do
			order += 1
			local row = template:Clone()
			row.Name = "Skin_" .. e.gun .. "_" .. e.line
			row.LayoutOrder = order
			row.Size = row.Size - UDim2.fromOffset(INDENT, 0)
			row.Visible = false;
			(child(row, "Cell") :: Frame).BackgroundColor3 = tier.color
			picture(row, ItemIcons.get(e.gun, e.line) or Locker.EMBLEMS[e.line], nil, e.line)
			local rn = child(row, "Name") :: TextLabel
			rn.Text = SkinCases.name(e.gun, e.line)
			rn.TextColor3 = tier.color;
			(child(row, "Sub") :: TextLabel).Text =
				string.format("%s SKIN FOR %s", tier.name, gunWord(e.gun, e.line));
			(child(row, "Pct") :: TextLabel).Text = ShopCatalog.formatOdds(e.odds)
			row.Parent = list
			table.insert(rows, row)
		end
		local open = false
		toggle.Activated:Connect(function()
			open = not open
			arrow.Text = if open then "▼" else "▶"
			for _, r in rows do
				r.Visible = open
			end
		end)
	end
	list.CanvasPosition = Vector2.zero
end

return OddsList
