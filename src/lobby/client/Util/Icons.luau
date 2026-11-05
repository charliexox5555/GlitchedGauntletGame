--!strict
-- Vector placeholder icons for the lobby bars, drawn from Frames, UIStroke and
-- UICorner so nothing waits on image uploads. When a real icon is uploaded
-- (prompts in vault/01 Design/Lobby UI Image Prompts.md), put its asset id in
-- ASSETS and Icons.draw shows the image instead (white art, tinted).

local Icons = {}

Icons.ASSETS = {
	Shop = "",
	Locker = "",
	BattlePass = "",
	Range = "",
	Settings = "",
	Coin = "",
} :: { [string]: string }

local function box(parent: Instance, props: { [string]: any }): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	for k, v in props do
		(f :: any)[k] = v
	end
	f.Parent = parent
	return f
end

local function stroke(parent: Instance, color: Color3, thickness: number)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
end

local function round(parent: Instance, r: UDim)
	local c = Instance.new("UICorner")
	c.CornerRadius = r
	c.Parent = parent
end

local function at(x: number, y: number): UDim2
	return UDim2.fromScale(x, y)
end

local DRAW: { [string]: (Frame, Color3, number) -> () } = {}

-- A gear: a ring over six teeth.
DRAW.Settings = function(f, color, px)
	for i = 0, 2 do
		box(f, {
			Position = at(0.5, 0.5),
			Size = UDim2.fromScale(0.22, 0.92),
			BackgroundColor3 = color,
			Rotation = i * 60,
		})
	end
	local ring = box(f, {
		Position = at(0.5, 0.5),
		Size = UDim2.fromScale(0.68, 0.68),
		BackgroundColor3 = color,
	})
	round(ring, UDim.new(1, 0))
	local hole = box(f, {
		Name = "Hole",
		Position = at(0.5, 0.5),
		Size = UDim2.fromScale(0.3, 0.3),
		BackgroundColor3 = Color3.fromHex("11151C"),
		ZIndex = 2,
	})
	round(hole, UDim.new(1, 0))
	local _ = px
end

-- A coin: gold disc, darker rim, a diamond stamped in the middle.
DRAW.Coin = function(f, color, px)
	local disc = box(f, {
		Position = at(0.5, 0.5),
		Size = UDim2.fromScale(0.9, 0.9),
		BackgroundColor3 = color,
	})
	round(disc, UDim.new(1, 0))
	stroke(disc, Color3.fromHex("B88A12"), math.max(1, px * 0.07))
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromHex("D9A21C"))
	g.Parent = disc
	box(f, {
		Position = at(0.5, 0.5),
		Size = UDim2.fromScale(0.32, 0.32),
		BackgroundColor3 = Color3.fromHex("8A6408"),
		Rotation = 45,
		ZIndex = 2,
	})
end

-- A shopping bag: body plus a rounded handle.
DRAW.Shop = function(f, color, px)
	local handle = box(f, {
		Position = at(0.5, 0.3),
		Size = UDim2.fromScale(0.4, 0.42),
		BackgroundTransparency = 1,
	})
	round(handle, UDim.new(0.5, 0))
	stroke(handle, color, math.max(1.5, px * 0.08))
	local body = box(f, {
		Position = at(0.5, 0.66),
		Size = UDim2.fromScale(0.78, 0.6),
		BackgroundColor3 = color,
		ZIndex = 2,
	})
	round(body, UDim.new(0.12, 0))
end

-- A locker: tall door outline, centre seam, two handles.
DRAW.Locker = function(f, color, px)
	local door = box(f, {
		Position = at(0.5, 0.5),
		Size = UDim2.fromScale(0.68, 0.92),
		BackgroundTransparency = 1,
	})
	round(door, UDim.new(0.1, 0))
	stroke(door, color, math.max(1.5, px * 0.08))
	box(f, {
		Position = at(0.5, 0.5),
		Size = UDim2.new(0, math.max(1.5, px * 0.07), 0.8, 0),
		BackgroundColor3 = color,
	})
	for _, x in { 0.4, 0.6 } do
		box(
			f,
			{ Position = at(x, 0.5), Size = UDim2.fromScale(0.06, 0.2), BackgroundColor3 = color }
		)
	end
	for _, y in { 0.2, 0.28 } do
		box(
			f,
			{ Position = at(0.35, y), Size = UDim2.fromScale(0.16, 0.04), BackgroundColor3 = color }
		)
		box(
			f,
			{ Position = at(0.65, y), Size = UDim2.fromScale(0.16, 0.04), BackgroundColor3 = color }
		)
	end
end

-- Battle pass: two stacked chevrons (rank stripes).
DRAW.BattlePass = function(f, color, px)
	local w = math.max(2, px * 0.12)
	for _, y in { 0.38, 0.66 } do
		box(f, {
			Position = at(0.34, y),
			Size = UDim2.new(0.46, 0, 0, w),
			BackgroundColor3 = color,
			Rotation = 35,
		})
		box(f, {
			Position = at(0.66, y),
			Size = UDim2.new(0.46, 0, 0, w),
			BackgroundColor3 = color,
			Rotation = -35,
		})
	end
end

-- The range: a target reticle.
DRAW.Range = function(f, color, px)
	local ring = box(f, {
		Position = at(0.5, 0.5),
		Size = UDim2.fromScale(0.72, 0.72),
		BackgroundTransparency = 1,
	})
	round(ring, UDim.new(1, 0))
	stroke(ring, color, math.max(1.5, px * 0.08))
	local dot = box(
		f,
		{ Position = at(0.5, 0.5), Size = UDim2.fromScale(0.16, 0.16), BackgroundColor3 = color }
	)
	round(dot, UDim.new(1, 0))
	local t = math.max(1.5, px * 0.08)
	box(f, { Position = at(0.5, 0.06), Size = UDim2.new(0, t, 0.2, 0), BackgroundColor3 = color })
	box(f, { Position = at(0.5, 0.94), Size = UDim2.new(0, t, 0.2, 0), BackgroundColor3 = color })
	box(f, { Position = at(0.06, 0.5), Size = UDim2.new(0.2, 0, 0, t), BackgroundColor3 = color })
	box(f, { Position = at(0.94, 0.5), Size = UDim2.new(0.2, 0, 0, t), BackgroundColor3 = color })
end

-- Draws icon `name` into a new `px`-square frame. Returns the frame.
function Icons.draw(
	parent: Instance,
	name: string,
	px: number,
	color: Color3,
	props: { [string]: any }?
): Frame
	local f = Instance.new("Frame")
	f.Name = "Icon"
	f.BackgroundTransparency = 1
	f.Size = UDim2.fromOffset(px, px)
	for k, v in props or {} do
		(f :: any)[k] = v
	end
	local asset = Icons.ASSETS[name]
	if asset and asset ~= "" then
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Size = UDim2.fromScale(1, 1)
		img.Image = asset
		img.ImageColor3 = if name == "Coin" then Color3.new(1, 1, 1) else color
		img.ScaleType = Enum.ScaleType.Fit
		img.Parent = f
	elseif DRAW[name] then
		DRAW[name](f, color, px)
	end
	f.Parent = parent
	return f
end

return Icons
