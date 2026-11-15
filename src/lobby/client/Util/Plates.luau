--!strict
-- The lobby's plate look (owner, 2026-11-16, style board: "I like the slanted
-- look because that is the style we are going for... add the shine and the
-- nice look of the chunky block, mix them"; vault/02 Art/UI Shop.md → Style
-- board). A slanted plate is any GuiObject with CapL / CapR slant-cap
-- children (the builders' slant()). finish(plate) gives it:
--   * a SHINE: the top ~46% a lighter tint of its colour (flat, no gradient),
--   * a LIP: a darker band along the bottom, like a block sitting on a base,
-- both with slanted ends that follow its caps, under its words. They follow
-- the plate's colour and transparency, so code that recolours or fades a
-- plate (selected tabs, hidden caps) keeps working.
-- deepen(root) finishes every slanted plate under `root`, except those with
-- the attribute NoLip = true.

local Plates = {}

local DARK = Color3.fromHex("0B0E1F")
local WHITE = Color3.new(1, 1, 1)
local LIP = 5 -- px
local SHINE = 0.46 -- of the plate's height

type Band = { frame: Frame, caps: { ImageLabel }, tone: (Color3) -> Color3 }

-- A band across the plate (top or bottom) plus its two slanted ends: each
-- end is the cap's own image recoloured and clipped to the band's height.
local function band(
	body: GuiObject,
	capL: ImageLabel,
	capR: ImageLabel,
	name: string,
	top: boolean,
	h: number
): Band
	local f = Instance.new("Frame")
	f.Name = name
	f.AnchorPoint = Vector2.new(0, if top then 0 else 1)
	f.Position = UDim2.fromScale(0, if top then 0 else 1)
	f.Size = UDim2.new(1, 0, 0, h)
	f.BorderSizePixel = 0
	f.ZIndex = body.ZIndex
	f.Parent = body
	local caps: { ImageLabel } = {}
	for _, cap in { capL, capR } do
		local clip = Instance.new("Frame")
		clip.Name = name .. cap.Name
		clip.AnchorPoint = Vector2.new(cap.AnchorPoint.X, if top then 0 else 1)
		clip.Position =
			UDim2.new(cap.Position.X.Scale, cap.Position.X.Offset, if top then 0 else 1, 0)
		clip.Size = UDim2.fromOffset(cap.Size.X.Offset, h)
		clip.BackgroundTransparency = 1
		clip.ClipsDescendants = true
		clip.ZIndex = cap.ZIndex
		local img = cap:Clone()
		img:ClearAllChildren()
		img.Name = "Cap"
		img.AnchorPoint = Vector2.zero
		img.Position = if top then UDim2.new() else UDim2.new(0, 0, 1, -cap.Size.Y.Offset)
		img.ZIndex = cap.ZIndex
		img.Parent = clip
		clip.Parent = body
		table.insert(caps, img)
	end
	return {
		frame = f,
		caps = caps,
		tone = if top
			then function(c: Color3): Color3
				return c:Lerp(WHITE, 0.24)
			end
			else function(c: Color3): Color3
				return c:Lerp(DARK, 0.45)
			end,
	}
end

function Plates.finish(body: GuiObject)
	if body:FindFirstChild("Lip") then
		return
	end
	local capL = body:FindFirstChild("CapL")
	local capR = body:FindFirstChild("CapR")
	if not (capL and capL:IsA("ImageLabel") and capR and capR:IsA("ImageLabel")) then
		return
	end
	local h = capL.Size.Y.Offset
	-- layers (siblings draw by ZIndex, a subtree as one): the caps at the
	-- bottom, the shine and lip one above them, everything else (the words,
	-- rows, icons) above those
	local base = capL.ZIndex
	local others = {}
	for _, c in body:GetChildren() do
		if c:IsA("GuiObject") and c ~= capL and c ~= capR then
			table.insert(others, c)
		end
	end
	local bands = {
		band(body, capL, capR, "Shine", true, math.floor(h * SHINE + 0.5)),
		band(body, capL, capR, "Lip", false, LIP),
	}
	local function sync()
		for _, b in bands do
			local c = b.tone(body.BackgroundColor3)
			b.frame.BackgroundColor3 = c
			b.frame.BackgroundTransparency = body.BackgroundTransparency
			for i, img in b.caps do
				local src = if i == 1 then capL else capR
				img.ImageColor3 = c
				img.ImageTransparency = math.max(src.ImageTransparency, body.BackgroundTransparency)
			end
		end
	end
	for _, b in bands do
		b.frame.ZIndex = base + 1
		for _, img in b.caps do
			local clip = img.Parent :: GuiObject
			clip.ZIndex = base + 1
			img.ZIndex = base + 1
		end
	end
	for _, c in others do
		c.ZIndex = math.max(c.ZIndex, base + 2)
	end
	sync()
	-- white words on the plate get a soft dark stroke so they read like the
	-- board's shadowed words (a shadow label would upset list layouts)
	for _, d in body:GetDescendants() do
		if d:IsA("TextLabel") and d.TextColor3 == WHITE then
			d.TextStrokeColor3 = DARK
			d.TextStrokeTransparency = 0.55
		end
	end
	body:GetPropertyChangedSignal("BackgroundColor3"):Connect(sync)
	body:GetPropertyChangedSignal("BackgroundTransparency"):Connect(sync)
	capL:GetPropertyChangedSignal("ImageTransparency"):Connect(sync)
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
