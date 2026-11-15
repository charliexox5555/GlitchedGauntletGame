--!strict
-- Cells and cards get the plates' chunky look (owner, 2026-11-16: "the cells
-- and a lot of the UI still just looks bland, not fun ... that effect and
-- style that we like needs to be added to everything else"; vault/02 Art/UI
-- Shop.md → Plate look pass 4). One-piece art like Util/Plates, so nothing
-- comes apart on a hover pop:
--   * `Skin` (art-source/ui/plates/card_base.png): a rounded box, greyscale,
--     bright top → a little deeper → a darker 5 px lip, tinted with the
--     cell's colour, under everything in the cell;
--   * `Bevel` (card_over.png): a bright top edge line, a soft top sheen and a
--     dark lip, over the cell's art (under its hover brackets), so even cells
--     covered by art read as chunky blocks.
-- 9-sliced with the cell's own corner radius, so the edges keep their pixel
-- size on any cell. The cell's own fill is hidden (a transparent
-- UIGradient); its BackgroundColor3 / BackgroundTransparency still drive the
-- skin, so code that recolours or fades cells keeps working.
-- watch(gui, names): finish the named cells now and any added later (cloned
-- rows, cards, tiles). mark(template): clones of it are cells anywhere.

local Cards = {}

local WHITE = Color3.new(1, 1, 1)
local BASE = "rbxassetid://93845956518960"
local OVER = "rbxassetid://123951162018563"
local IMG_R = 16 -- px: the images' corner radius (64 x 64, slice 24..40)
local SLICE = Rect.new(24, 24, 40, 40)
local LIFT = 0.1

local function layer(
	cell: GuiObject,
	name: string,
	image: string,
	scale: number,
	z: number
): ImageLabel
	local i = Instance.new("ImageLabel")
	i.Name = name
	i.BackgroundTransparency = 1
	i.Image = image
	i.ScaleType = Enum.ScaleType.Slice
	i.SliceCenter = SLICE
	i.SliceScale = scale
	i.Size = UDim2.fromScale(1, 1)
	i.ZIndex = z
	i:SetAttribute("PivotOk", true)
	i.Parent = cell
	return i
end

function Cards.finish(cell: GuiObject)
	if cell:GetAttribute("Carded") == true or cell:GetAttribute("NoCard") == true then
		return
	end
	local corner = cell:FindFirstChildOfClass("UICorner")
	local r = if corner then corner.CornerRadius.Offset else 8
	if corner and corner.CornerRadius.Scale > 0 then
		return -- circles stay circles
	end
	-- the fill is hidden with a UIGradient, which would hide a cell's own
	-- words too: only boxes whose words are child labels (a label named
	-- like a cell, e.g. the Season Pass bar's "Next", is left alone)
	if
		cell:IsA("TextLabel")
		or cell:IsA("TextBox")
		or (cell:IsA("TextButton") and cell.Text ~= "")
	then
		return
	end
	cell:SetAttribute("Carded", true)

	-- layers: the skin under everything; the bevel just above the layers
	-- that cover the cell (art, shade, dim); the words, tags, ticks and the
	-- hover brackets above the bevel (owner: the bevel washed out CLAIM)
	local function covers(c: GuiObject): boolean
		if c.Name == "Select" then
			return false
		end
		local cw, ch = cell.AbsoluteSize.X, cell.AbsoluteSize.Y
		if cw > 1 and ch > 1 then
			return c.AbsoluteSize.X / cw >= 0.8 and c.AbsoluteSize.Y / ch >= 0.8
		end
		local s, cs = c.Size, cell.Size
		local w = s.X.Scale + (if cs.X.Offset > 0 then s.X.Offset / cs.X.Offset else 0)
		local h = s.Y.Scale + (if cs.Y.Offset > 0 then s.Y.Offset / cs.Y.Offset else 0)
		return w >= 0.8 and h >= 0.8
	end
	local lo, coverHi = math.huge, -math.huge
	local others: { GuiObject } = {}
	local othersLo = math.huge
	for _, c in cell:GetChildren() do
		if c:IsA("GuiObject") then
			lo = math.min(lo, c.ZIndex)
			if covers(c) then
				coverHi = math.max(coverHi, c.ZIndex)
			else
				table.insert(others, c)
				othersLo = math.min(othersLo, c.ZIndex)
			end
		end
	end
	if lo == math.huge then
		lo = cell.ZIndex
	end
	local hi = if coverHi > -math.huge then coverHi else lo
	if #others > 0 and othersLo <= hi + 1 then
		local shift = hi + 2 - othersLo
		for _, c in others do
			c.ZIndex += shift
		end
	end

	for _, g in cell:GetChildren() do
		if g:IsA("UIGradient") then
			g.Transparency = NumberSequence.new(1)
		end
	end
	if not cell:FindFirstChildOfClass("UIGradient") then
		local hide = Instance.new("UIGradient")
		hide.Name = "HideFill"
		hide.Transparency = NumberSequence.new(1)
		hide.Parent = cell
	end

	local scale = math.max(r, 2) / IMG_R
	local skin = layer(cell, "Skin", BASE, scale, lo - 1)
	local bevel = layer(cell, "Bevel", OVER, scale, hi + 1)

	local function paint()
		skin.ImageColor3 = cell.BackgroundColor3:Lerp(WHITE, LIFT)
	end
	local function fade()
		local t = cell.BackgroundTransparency
		skin.ImageTransparency = t
		-- the bevel shows on any visible cell, fading out with a hidden one
		bevel.ImageTransparency = math.clamp((t - 0.6) / 0.4, 0, 1)
	end
	paint()
	fade()
	cell:GetPropertyChangedSignal("BackgroundColor3"):Connect(paint)
	cell:GetPropertyChangedSignal("BackgroundTransparency"):Connect(fade)
end

local function matches(d: Instance, names: { [string]: boolean }): boolean
	return d:IsA("GuiObject") and (names[d.Name] == true or d:GetAttribute("Card") == true)
end

function Cards.watch(gui: Instance, list: { string })
	local names: { [string]: boolean } = {}
	for _, n in list do
		names[n] = true
	end
	for _, d in gui:GetDescendants() do
		if matches(d, names) then
			Cards.finish(d :: GuiObject)
		end
	end
	gui.DescendantAdded:Connect(function(d)
		if matches(d, names) then
			-- after the code that cloned it has set it up
			task.defer(function()
				if d.Parent then
					Cards.finish(d :: GuiObject)
				end
			end)
		end
	end)
end

function Cards.mark(template: Instance)
	template:SetAttribute("Card", true)
end

return Cards
