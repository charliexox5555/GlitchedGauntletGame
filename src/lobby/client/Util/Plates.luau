--!strict
-- The lobby's plate look (owner, 2026-11-16, style board: "I like the slanted
-- look because that is the style we are going for... add the shine and the
-- nice look of the chunky block, mix them"; vault/02 Art/UI Shop.md → Plate
-- look). A slanted plate is any GuiObject with CapL / CapR slant-cap children
-- (the builders' slant()).
--
-- Pass 3 (owner: "the look and highlights and parts unalign with each other
-- when hovered"): a plate is drawn as ONE sliced image, not a body + two caps
-- + gradients. Pieces scaled by a hover pop round to the pixel separately and
-- show seams; one image can't. finish(plate):
--   * hides the body's own fill (a fully transparent UIGradient: code can
--     keep writing its colour and transparency, they still drive the plate),
--   * removes the caps,
--   * draws `Skin` (art-source/ui/plates/plate_base.png: the parallelogram,
--     greyscale, bright top → a little deeper → a darker lip) tinted with the
--     plate's colour, and `Gloss` (plate_gloss.png: the thin top line and a
--     soft sheen, white) with the same rect and slicing, so they always line
--     up. The slanted ends are the image's end columns (fixed width, scaled
--     by SliceScale), the middle stretches,
--   * outlines white words in a dark shade of the plate's colour.
-- deepen(root) finishes every slanted plate under `root`, except those with
-- the attribute NoLip = true.

local Plates = {}

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

local BASE = "rbxassetid://106196536481675"
local GLOSS = "rbxassetid://93037486307954"
local IMG_END = 32 -- px, each end column of the 128 x 96 images
local SLICE = Rect.new(IMG_END, 0, 128 - IMG_END, 96)
local REACH = 0.87 -- how far a slanted end reaches past the body, of the old cap's width
local LIFT = 0.1 -- the plate's colour lifted for the image's bright top
local OUTLINE = 0.62 -- white words' outline: the plate's colour toward black

local function layer(
	parent: Instance,
	name: string,
	image: string,
	ext: number,
	z: number
): ImageLabel
	local i = Instance.new("ImageLabel")
	i.Name = name
	i.BackgroundTransparency = 1
	i.Image = image
	i.ScaleType = Enum.ScaleType.Slice
	i.SliceCenter = SLICE
	i.SliceScale = ext / IMG_END
	i.Position = UDim2.fromOffset(-ext, 0)
	i.Size = UDim2.new(1, ext * 2, 1, 0)
	i.ZIndex = z
	i:SetAttribute("PivotOk", true)
	i.Parent = parent
	return i
end

function Plates.finish(body: GuiObject)
	if body:GetAttribute("Plated") == true then
		return
	end
	local capL = body:FindFirstChild("CapL")
	local capR = body:FindFirstChild("CapR")
	if not (capL and capL:IsA("ImageLabel") and capR and capR:IsA("ImageLabel")) then
		return
	end
	body:SetAttribute("Plated", true)
	local base = capL.ZIndex
	local ext = math.max(2, math.floor(capL.Size.X.Offset * REACH + 0.5))
	capL:Destroy()
	capR:Destroy()

	-- the words, rows and icons sit above the plate
	for _, c in body:GetChildren() do
		if c:IsA("GuiObject") then
			c.ZIndex = math.max(c.ZIndex, base + 2)
		end
	end

	-- the body's own fill is hidden; its properties still drive the plate
	for _, g in body:GetChildren() do
		if g:IsA("UIGradient") then
			g:Destroy()
		end
	end
	-- A plate that sized itself to its words (AutomaticSize X) would count
	-- its own art and grow every frame, so its width now follows its words
	-- here: the widest content child + padding, in unscaled pixels.
	if
		(body.AutomaticSize == Enum.AutomaticSize.X or body.AutomaticSize == Enum.AutomaticSize.XY)
		and body.Size.Y.Offset > 0
		and body.Size.Y.Scale == 0
	then
		body.AutomaticSize = if body.AutomaticSize == Enum.AutomaticSize.XY
			then Enum.AutomaticSize.Y
			else Enum.AutomaticSize.None
		local content: { GuiObject } = {}
		for _, c in body:GetChildren() do
			if c:IsA("GuiObject") then
				table.insert(content, c)
			end
		end
		local pad = body:FindFirstChildOfClass("UIPadding")
		local function fitWidth()
			local k = body.AbsoluteSize.Y / body.Size.Y.Offset
			if k <= 0 then
				return
			end
			local w = 0
			for _, c in content do
				if c.Visible then
					w = math.max(w, c.Position.X.Offset + c.AbsoluteSize.X / k)
				end
			end
			if pad then
				w += pad.PaddingLeft.Offset + pad.PaddingRight.Offset
			end
			w = math.ceil(w)
			if w > 0 and body.Size.X.Offset ~= w then
				body.Size = UDim2.new(0, w, body.Size.Y.Scale, body.Size.Y.Offset)
			end
		end
		for _, c in content do
			c:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitWidth)
			c:GetPropertyChangedSignal("Visible"):Connect(fitWidth)
		end
		body:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitWidth)
		fitWidth()
	end

	local hide = Instance.new("UIGradient")
	hide.Name = "HideFill"
	hide.Transparency = NumberSequence.new(1)
	hide.Parent = body

	-- a full-size holder (scale-sized, so a plate that sizes itself to its
	-- words doesn't count the slanted ends in its width)
	local back = Instance.new("Frame")
	back.Name = "PlateArt" -- not "Plate": some bodies are named Plate
	back.BackgroundTransparency = 1
	back.Size = UDim2.fromScale(1, 1)
	back.ZIndex = base
	back:SetAttribute("PivotOk", true)
	back.Parent = body
	local skin = layer(back, "Skin", BASE, ext, base)
	local gloss = layer(back, "Gloss", GLOSS, ext, base + 1)

	local words: { UIStroke } = {}
	for _, d in body:GetDescendants() do
		if d:IsA("TextLabel") and d.TextColor3 == WHITE then
			d.TextStrokeTransparency = 1
			local s = Instance.new("UIStroke")
			s.Name = "Outline"
			s.Thickness = 1.5
			s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
			s.LineJoinMode = Enum.LineJoinMode.Round
			s.Parent = d
			table.insert(words, s)
		end
	end

	local function paint()
		local c = body.BackgroundColor3
		skin.ImageColor3 = c:Lerp(WHITE, LIFT)
		local outline = c:Lerp(BLACK, OUTLINE)
		for _, s in words do
			s.Color = outline
		end
	end
	local function fade()
		local t = body.BackgroundTransparency
		skin.ImageTransparency = t
		gloss.ImageTransparency = t
	end
	paint()
	fade()
	body:GetPropertyChangedSignal("BackgroundColor3"):Connect(paint)
	body:GetPropertyChangedSignal("BackgroundTransparency"):Connect(fade)
end

function Plates.deepen(root: Instance)
	for _, d in root:GetDescendants() do
		if
			d:IsA("GuiObject")
			and d:GetAttribute("NoLip") ~= true
			and d:FindFirstChild("CapL")
			and d:FindFirstChild("CapR")
		then
			Plates.finish(d)
		end
	end
end

return Plates
