--!strict
-- Fills a case's CONTENTS list like RIVALS' odds list (owner 2026-11-20): each SECTION
-- (gun skins, knife skins) with its chance; inside it, one row per skin line with the
-- line's hero picture (its Vandal) and combined odds, opening to that line's skins with
-- their own odds (every item in a section has the same chance); knives are one row
-- each. Pictures are rendered portraits (Shared/SkinArt) that spill over their tier-
-- coloured square; click a picture for a short card about the skin. Odds are before
-- owned skins drop out. Rows clone UiTemplates.Lobby.ShopOddsRow. Used by the Shop,
-- the Backpack and the Season Pass.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local ShopCatalog = require(ReplicatedStorage.Lobby.ShopCatalog)
local SkinArt = require(ReplicatedStorage.Shared.SkinArt)
local SkinCases = require(ReplicatedStorage.Shared.SkinCases)
local Skins = require(ReplicatedStorage.Shared.Config.Skins)
local Locker = require(ReplicatedStorage.Shared.Locker)

local OddsList = {}

local INDENT = 46 -- px a line's skins sit in from its row
local ARROW_W = 26
local MUTED = Color3.fromHex("9F9FA2")
local WHITE = Color3.new(1, 1, 1)

local KIND_TEXT: { [string]: string } = {
	reskin = "A NEW FINISH ON THE GUN'S OWN SHAPE.",
	shape = "RESHAPES THE GUN: NEW PARTS AND A NEW SILHOUETTE.",
	animated = "RESHAPED, WITH ITS OWN ANIMATIONS.",
}

local function child<T>(parent: Instance, name: string): T
	return (parent:WaitForChild(name) :: any) :: T
end

local function shiftX(obj: GuiObject, dx: number)
	obj.Position = obj.Position + UDim2.fromOffset(dx, 0)
end

local function gunWord(gun: string, line: string): string
	return if gun == "Knife" and line == "PopCircuit" then "BAT" else string.upper(gun)
end

-- the picture spills over its tier-coloured square, like RIVALS' tiles; with no
-- picture, the line's colour and its initial
local function picture(row: Frame, image: string?, line: string): GuiButton
	local cell = child(row, "Cell") :: Frame
	cell.ClipsDescendants = false
	if image then
		local pic = Instance.new("ImageLabel")
		pic.Name = "Pic"
		pic.BackgroundTransparency = 1
		pic.AnchorPoint = Vector2.new(0.5, 0.5)
		pic.Position = UDim2.fromScale(0.47, 0.47) -- centred, spilling a little up-left like RIVALS
		pic.Size = UDim2.fromScale(1.3, 1.3)
		pic.ScaleType = Enum.ScaleType.Fit
		pic.Image = image
		pic.ZIndex = cell.ZIndex + 2
		pic.Parent = cell
	else
		cell.BackgroundColor3 = Locker.COLORS[line] or cell.BackgroundColor3
		local letter = Instance.new("TextLabel")
		letter.Name = "Letter"
		letter.BackgroundTransparency = 1
		letter.Size = UDim2.fromScale(1, 1)
		letter.FontFace = (child(row, "Name") :: TextLabel).FontFace
		letter.TextSize = 26
		letter.TextColor3 = WHITE
		letter.Text = string.sub(string.upper(line), 1, 1)
		letter.ZIndex = cell.ZIndex + 1
		letter.Parent = cell
	end
	local hit = Instance.new("TextButton")
	hit.Name = "PicButton"
	hit.BackgroundTransparency = 1
	hit.Text = ""
	hit.Size = UDim2.fromScale(1.2, 1.2)
	hit.AnchorPoint = Vector2.new(0.5, 0.5)
	hit.Position = UDim2.fromScale(0.5, 0.5)
	hit.ZIndex = cell.ZIndex + 6
	hit.Parent = cell
	return hit
end

type Show = (
	anchor: GuiObject,
	image: string?,
	color: Color3,
	title: string,
	line1: string,
	line2: string
) -> ()

-- a short card about one skin or line (RIVALS: "Given to a random weapon!"), in our
-- look: a dark plate that pops out next to the clicked picture with a pointer, the
-- picture spilling over its tier tile, the name, what it is. Clicking anywhere else
-- closes it.
local function infoCard(panel: GuiObject, font: Font): Show
	for _, n in { "SkinInfo", "SkinInfoShade" } do
		local old = panel:FindFirstChild(n)
		if old then
			old:Destroy()
		end
	end
	local W, H = 640, 196
	-- the click-away catcher over the whole panel
	local shade = Instance.new("TextButton")
	shade.Name = "SkinInfoShade"
	shade.AutoButtonColor = false
	shade.Text = ""
	shade.BackgroundTransparency = 1
	shade.Size = UDim2.fromScale(1, 1)
	shade.ZIndex = 58
	shade.Visible = false
	shade.Parent = panel
	local card = Instance.new("TextButton")
	card.Name = "SkinInfo"
	card.AutoButtonColor = false
	card.Text = ""
	card.Size = UDim2.fromOffset(W, H)
	card.BackgroundColor3 = Color3.fromHex("1B1B1F")
	card.BorderSizePixel = 0
	card.ZIndex = 60
	card.Visible = false
	local pop = Instance.new("UIScale")
	pop.Parent = card
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = card
	local pointer = Instance.new("Frame")
	pointer.Name = "Pointer"
	pointer.AnchorPoint = Vector2.new(0.5, 0.5)
	pointer.Size = UDim2.fromOffset(22, 22)
	pointer.Rotation = 45
	pointer.BackgroundColor3 = card.BackgroundColor3
	pointer.BorderSizePixel = 0
	pointer.ZIndex = 59
	pointer.Parent = card
	local tile = Instance.new("Frame")
	tile.Name = "Tile"
	tile.Position = UDim2.fromOffset(24, 22)
	tile.Size = UDim2.fromOffset(152, 152)
	tile.BorderSizePixel = 0
	tile.ZIndex = 61
	tile.Parent = card
	local tc = Instance.new("UICorner")
	tc.CornerRadius = UDim.new(0, 8)
	tc.Parent = tile
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(110, 110, 120))
	grad.Parent = tile
	local pic = Instance.new("ImageLabel")
	pic.Name = "Pic"
	pic.BackgroundTransparency = 1
	pic.AnchorPoint = Vector2.new(0.5, 0.5)
	pic.Position = UDim2.fromScale(0.47, 0.47)
	pic.Size = UDim2.fromScale(1.25, 1.25)
	pic.ScaleType = Enum.ScaleType.Fit
	pic.ZIndex = 63
	pic.Parent = tile
	local function label(name: string, y: number, size: number, color: Color3): TextLabel
		local l = Instance.new("TextLabel")
		l.Name = name
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromOffset(200, y)
		l.Size = UDim2.new(1, -222, 0, size + 6)
		l.FontFace = font
		l.TextSize = size
		l.TextColor3 = color
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.TextWrapped = true
		l.ZIndex = 62
		l.Parent = card
		return l
	end
	local title = label("Title", 34, 38, WHITE)
	local l1 = label("Line1", 90, 21, WHITE)
	local l2 = label("Line2", 126, 17, MUTED)
	card.Parent = panel
	local function hide()
		card.Visible = false
		shade.Visible = false
	end
	shade.Activated:Connect(hide)
	card.Activated:Connect(hide)
	return function(
		anchor: GuiObject,
		image: string?,
		color: Color3,
		t: string,
		a: string,
		b: string
	)
		tile.BackgroundColor3 = color
		pic.Image = image or ""
		title.Text = t
		title.TextColor3 = color
		l1.Text = a
		l2.Text = b
		-- next to the clicked picture, in the panel's own (unscaled) units
		local k = if panel.Size.X.Offset > 0 then panel.AbsoluteSize.X / panel.Size.X.Offset else 1
		local rel = (anchor.AbsolutePosition - panel.AbsolutePosition) / k
		local size = anchor.AbsoluteSize / k
		local ph = panel.AbsoluteSize.Y / k
		local x = math.clamp(rel.X - 40, 16, math.max(16, panel.AbsoluteSize.X / k - W - 16))
		local below = rel.Y + size.Y + 16 + H < ph
		local y = if below then rel.Y + size.Y + 16 else rel.Y - 16 - H
		card.Position = UDim2.fromOffset(x, y)
		pointer.Position = UDim2.fromOffset(rel.X + size.X / 2 - x, if below then 0 else H)
		shade.Visible = true
		card.Visible = true
		-- pops out from the picture
		pop.Scale = 0.82
		card.AnchorPoint = Vector2.zero
		TweenService:Create(
			pop,
			TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = 1 }
		):Play()
	end
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
	local font = (child(template, "Name") :: TextLabel).FontFace
	local parent = list.Parent
	local showInfo = infoCard(if parent and parent:IsA("GuiObject") then parent else list, font)
	local order = 0

	local function row(): Frame
		order += 1
		local r = template:Clone()
		r.LayoutOrder = order
		return r
	end

	for _, sec in SkinCases.sections(case.id) do
		-- the section: its name and chance
		local head = row()
		head.Name = "Section_" .. sec.id
		head.BackgroundTransparency = 1;
		(child(head, "Cell") :: Frame).Visible = false
		local hn = child(head, "Name") :: TextLabel
		hn.Text = sec.name
		hn.TextColor3 = WHITE
		hn.TextSize = 26
		shiftX(hn, -66)
		local hs = child(head, "Sub") :: TextLabel
		hs.Text = if sec.id == "Knives"
			then "A TIER IS ROLLED FIRST, THEN A KNIFE IN IT"
			else "A TIER IS ROLLED FIRST, THEN A SKIN LINE IN IT"
		shiftX(hs, -66);
		(child(head, "Pct") :: TextLabel).Text = ShopCatalog.formatOdds(sec.odds)
		head.Parent = list

		for _, tb in sec.tiers do
			-- the tier: its name in its colour, its chance, how many lines share it
			local tierDef = Skins.TIERS[tb.tier]
			local th = row()
			th.Name = "Tier_" .. tb.tier .. "_" .. sec.id
			th.BackgroundTransparency = 1;
			(child(th, "Cell") :: Frame).Visible = false
			local tn = child(th, "Name") :: TextLabel
			tn.Text = tierDef.name
			tn.TextColor3 = tierDef.color
			tn.TextSize = 22
			shiftX(tn, -66)
			local ts = child(th, "Sub") :: TextLabel
			local noun = if sec.id == "Knives"
				then (if #tb.groups == 1 then "KNIFE" else "KNIVES")
				else (if #tb.groups == 1 then "SKIN LINE" else "SKIN LINES")
			ts.Text = string.format("%d %s  ·  EACH THE SAME CHANCE", #tb.groups, noun)
			shiftX(ts, -66)
			local tp = child(th, "Pct") :: TextLabel
			tp.Text = ShopCatalog.formatOdds(tb.odds)
			tp.TextColor3 = tierDef.color
			th.Parent = list

			for _, g in tb.groups do
				local tier = Skins.TIERS[g.tier]
				local def = Skins.LINES[g.line]
				local kind = KIND_TEXT[if def then def.kind else "reskin"] or ""
				local single = #g.entries == 1
				local first = g.entries[1]
				local guns: { string } = {}
				for _, e in g.entries do
					table.insert(guns, e.gun)
				end
				local r = row()
				r.Name = "Line_" .. g.line .. "_" .. g.tier .. "_" .. sec.id
				if not single then
					for _, n in { "Cell", "Name", "Sub" } do
						shiftX(child(r, n) :: GuiObject, ARROW_W)
					end
				end
				local cell = child(r, "Cell") :: Frame
				cell.BackgroundColor3 = tier.color
				local image = if single
					then SkinArt.portrait(first.gun, first.line)
					else SkinArt.line(g.line, guns)
				local hit = picture(r, image, g.line)
				local name = child(r, "Name") :: TextLabel
				name.Text = if single
					then SkinCases.name(first.gun, first.line)
					else string.upper(g.line)
				name.TextColor3 = tier.color;
				(child(r, "Sub") :: TextLabel).Text = if single
					then string.format("%s SKIN FOR %s", tier.name, gunWord(first.gun, first.line))
					else string.format(
						"%s SKIN FOR A RANDOM GUN  ·  %d GUNS",
						tier.name,
						#g.entries
					);
				(child(r, "Pct") :: TextLabel).Text = ShopCatalog.formatOdds(g.odds)
				hit.Activated:Connect(function()
					if single then
						showInfo(
							cell,
							image,
							tier.color,
							SkinCases.name(first.gun, first.line),
							string.format(
								"%s SKIN  ·  GIVEN TO THE %s",
								tier.name,
								gunWord(first.gun, first.line)
							),
							kind
						)
					else
						showInfo(
							cell,
							image,
							tier.color,
							string.upper(g.line),
							string.format(
								"%s SKIN  ·  GIVEN TO A RANDOM GUN (%d)",
								tier.name,
								#g.entries
							),
							kind
						)
					end
				end)
				r.Parent = list
				if single then
					continue
				end

				-- the line's skins, hidden until it's opened
				local arrow = Instance.new("TextLabel")
				arrow.Name = "Arrow"
				arrow.BackgroundTransparency = 1
				arrow.AnchorPoint = Vector2.new(0, 0.5)
				arrow.Position = UDim2.new(0, 8, 0.5, 0)
				arrow.Size = UDim2.fromOffset(ARROW_W, 30)
				arrow.FontFace = name.FontFace
				arrow.TextSize = 18
				arrow.TextColor3 = MUTED
				arrow.Text = "▶"
				arrow.ZIndex = name.ZIndex
				arrow.Parent = r
				local toggle = Instance.new("TextButton")
				toggle.Name = "Toggle"
				toggle.BackgroundTransparency = 1
				toggle.Text = ""
				toggle.Size = UDim2.fromScale(1, 1)
				-- under the picture cell (siblings layer by ZIndex), so a click on the
				-- picture opens its card and a click anywhere else on the row opens the line
				toggle.ZIndex = cell.ZIndex - 1
				toggle.Parent = r
				local rows: { Frame } = {}
				for _, e in g.entries do
					local c = row()
					c.Name = "Skin_" .. e.gun .. "_" .. e.line
					c.Size = c.Size - UDim2.fromOffset(INDENT, 0)
					c.Visible = false;
					(child(c, "Cell") :: Frame).BackgroundColor3 = tier.color
					local pic = SkinArt.portrait(e.gun, e.line)
					local chit = picture(c, pic, e.line)
					local cn = child(c, "Name") :: TextLabel
					cn.Text = SkinCases.name(e.gun, e.line)
					cn.TextColor3 = tier.color;
					(child(c, "Sub") :: TextLabel).Text =
						string.format("%s SKIN FOR %s", tier.name, gunWord(e.gun, e.line));
					(child(c, "Pct") :: TextLabel).Text = ShopCatalog.formatOdds(e.odds)
					chit.Activated:Connect(function()
						showInfo(
							child(c, "Cell") :: GuiObject,
							pic,
							tier.color,
							SkinCases.name(e.gun, e.line),
							string.format(
								"%s SKIN  ·  GIVEN TO THE %s",
								tier.name,
								gunWord(e.gun, e.line)
							),
							kind
						)
					end)
					c.Parent = list
					table.insert(rows, c)
				end
				local open = false
				toggle.Activated:Connect(function()
					open = not open
					arrow.Text = if open then "▼" else "▶"
					for _, c in rows do
						c.Visible = open
					end
				end)
			end
		end
	end
	list.CanvasPosition = Vector2.zero
end

return OddsList
