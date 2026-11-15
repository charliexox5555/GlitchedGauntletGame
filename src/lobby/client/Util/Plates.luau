--!strict
-- The lobby's plate look (owner, 2026-11-16, style board: "I like the slanted
-- look because that is the style we are going for... add the shine and the
-- nice look of the chunky block, mix them"; vault/02 Art/UI Shop.md → Plate
-- look). A slanted plate is any GuiObject with CapL / CapR slant-cap children
-- (the builders' slant()). finish(plate) gives it RIVALS-style depth:
--   * one smooth top-to-bottom gradient (bright top, a little deeper below),
--   * a darker lip along the bottom, like a block sitting on a base,
--   * a thin bright line across the top, inset from the slanted ends,
--   * white words get a dark outline in the plate's own hue.
-- Pass 2 (owner: "a weird fold on the sides"): the depth is a UIGradient on
-- the body AND on each cap, so the slanted ends match the body exactly (the
-- first pass laid clipped bands over the caps; a rotated cap can't be
-- clipped, which made the fold). The plate's colour stays the truth: code
-- that recolours or tweens a plate (selected tabs, setPlate) keeps working,
-- the plate just lifts that colour a touch for its bright top.
-- deepen(root) finishes every slanted plate under `root`, except those with
-- the attribute NoLip = true.

local Plates = {}

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local LIP = 5 -- px
local LIFT = 0.12 -- how much the plate's colour is lifted for its bright top
local MID = 0.93 -- gradient at the middle (multiplier)
local FOOT = 0.84 -- just above the lip
local LIP_TONE = 0.6 -- the lip
local LINE_INSET = 6 -- px from each end of the body
local LINE_ALPHA = 0.55 -- the top line's transparency on top of the plate's

local function grey(v: number): Color3
	return Color3.new(v, v, v)
end

local function close(a: Color3, b: Color3): boolean
	return math.abs(a.R - b.R) + math.abs(a.G - b.G) + math.abs(a.B - b.B) < 0.004
end

local function depth(h: number): ColorSequence
	local lip = math.clamp(LIP / math.max(h, 1), 0.05, 0.3)
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, grey(1)),
		ColorSequenceKeypoint.new(0.5, grey(MID)),
		ColorSequenceKeypoint.new(1 - lip - 0.002, grey(FOOT)),
		ColorSequenceKeypoint.new(1 - lip, grey(LIP_TONE)),
		ColorSequenceKeypoint.new(1, grey(LIP_TONE)),
	})
end

local function gradient(parent: GuiObject, h: number, rotation: number)
	local g = Instance.new("UIGradient")
	g.Name = "Depth"
	g.Rotation = rotation
	g.Color = depth(h)
	g.Parent = parent
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
	local h = capL.Size.Y.Offset
	-- top-to-bottom on screen: 90 for an unrotated frame; a cap turned 180
	-- needs its gradient turned the other way to stay top-to-bottom
	gradient(body, h, 90)
	gradient(capL, h, if math.abs(capL.Rotation % 360 - 180) < 1 then 270 else 90)
	gradient(capR, h, if math.abs(capR.Rotation % 360 - 180) < 1 then 270 else 90)

	-- layers (siblings draw by ZIndex, a subtree as one): the caps, then the
	-- top line, then everything else (the words, rows, icons)
	local base = capL.ZIndex
	for _, c in body:GetChildren() do
		if c:IsA("GuiObject") and c ~= capL and c ~= capR then
			c.ZIndex = math.max(c.ZIndex, base + 2)
		end
	end
	-- A plate that sizes itself to its words (AutomaticSize X) counted its
	-- right cap in that size, so the body ran ~a cap's width past the slant:
	-- the "weird fold" (owner, 2026-11-16). Caps inside a full-size "Ends"
	-- frame (scale-sized, so not counted) fix it; code that shows / hides
	-- caps by looping the plate's children no longer finds them, so the
	-- caps follow the body's fade below.
	local moved = body.AutomaticSize == Enum.AutomaticSize.X
		or body.AutomaticSize == Enum.AutomaticSize.XY
	if moved then
		local ends = Instance.new("Frame")
		ends.Name = "Ends"
		ends.BackgroundTransparency = 1
		ends.Size = UDim2.fromScale(1, 1)
		ends.ZIndex = base
		ends.Parent = body
		capL.Parent = ends
		capR.Parent = ends
	end
	local line = Instance.new("Frame")
	line.Name = "TopLine"
	line.BorderSizePixel = 0
	line.Position = UDim2.fromOffset(LINE_INSET, 2)
	line.Size = UDim2.new(1, -LINE_INSET * 2, 0, 2)
	line.ZIndex = base + 1
	line.Parent = body

	local words: { TextLabel } = {}
	for _, d in body:GetDescendants() do
		if d:IsA("TextLabel") and d.TextColor3 == WHITE then
			d.TextStrokeTransparency = 1
			local s = Instance.new("UIStroke")
			s.Name = "Outline"
			s.Thickness = 1.5
			s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
			s.LineJoinMode = Enum.LineJoinMode.Round
			s.Parent = d
			table.insert(words, d)
		end
	end

	-- the plate's own colour, lifted for the bright top; caps follow it
	local lifted: Color3? = nil
	local source = body.BackgroundColor3
	local function paint()
		local c = source:Lerp(WHITE, LIFT)
		lifted = c
		body.BackgroundColor3 = c
		capL.ImageColor3 = c
		capR.ImageColor3 = c
		line.BackgroundColor3 = source:Lerp(WHITE, 0.55)
		local outline = source:Lerp(BLACK, 0.62)
		for _, w in words do
			local s = w:FindFirstChild("Outline")
			if s and s:IsA("UIStroke") then
				s.Color = outline
			end
		end
	end
	local function fade()
		line.BackgroundTransparency = 1 - (1 - body.BackgroundTransparency) * (1 - LINE_ALPHA)
		if moved then
			capL.ImageTransparency = body.BackgroundTransparency
			capR.ImageTransparency = body.BackgroundTransparency
		end
	end
	-- outside code writes the plain colour (or a tween step of it): take it
	-- as the new source; ignore our own lifted writes
	local function onColour(c: Color3)
		if lifted and close(c, lifted) then
			return
		end
		source = c
		paint()
	end
	paint()
	fade()
	body:GetPropertyChangedSignal("BackgroundColor3"):Connect(function()
		onColour(body.BackgroundColor3)
	end)
	for _, cap in { capL, capR } do
		cap:GetPropertyChangedSignal("ImageColor3"):Connect(function()
			if lifted and not close(cap.ImageColor3, lifted) then
				cap.ImageColor3 = lifted
			end
		end)
	end
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
