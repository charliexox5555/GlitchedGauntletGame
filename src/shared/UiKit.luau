--!strict
-- UI v2 builders for the Lobby and the match (Figma "Lobby v2"): rounded surfaces with a 2 px light
-- edge and a top-lit gradient, stacked soft shadows, gold primary buttons with
-- a lip that sinks on press, circle icon buttons, tags and key chips. Every
-- value comes from Config/UiStyle. Shapes are UICorner + UIStroke (Border), never
-- scaled 9-slices, so edges stay crisp and equal at every Fit scale
-- (`UiKit.snapStrokes` keeps strokes on whole drawn pixels).

local Style = require(script.Parent.Config.UiStyle)

local Kit = {}

local C = Style.COLOR
local A = Style.ALPHA

function Kit.make(className: string, props: { [string]: any }, parent: Instance?): any
	local inst = Instance.new(className)
	for k, v in props do
		(inst :: any)[k] = v
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function apply(inst: Instance, props: { [string]: any }?)
	if props then
		for k, v in props do
			(inst :: any)[k] = v
		end
	end
end

-- A label in one of Style.TEXT's styles.
function Kit.text(
	parent: Instance,
	content: string,
	style: string,
	props: { [string]: any }?
): TextLabel
	local s = Style.TEXT[style]
	local label = Kit.make("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = s.font,
		TextSize = s.size,
		TextColor3 = C.text,
		Text = content,
		Size = UDim2.fromOffset(200, math.ceil(s.size * 1.25)),
	}, parent)
	apply(label, props)
	return label
end

-- The UIStroke / gradient a kit surface was built with (for hover tweens).
function Kit.strokeOf(obj: Instance): UIStroke
	local stroke = obj:FindFirstChildWhichIsA("UIStroke")
	assert(stroke, `Kit.strokeOf: {obj:GetFullName()} has no stroke`)
	return stroke
end

function Kit.shadeOf(obj: Instance): UIGradient
	local shade = obj:FindFirstChildWhichIsA("UIGradient")
	assert(shade, `Kit.shadeOf: {obj:GetFullName()} has no gradient`)
	return shade
end

-- A soft dark copy behind display text over art (a text shadow without blur).
function Kit.textShadow(label: TextLabel, drop: number?): TextLabel
	local shadow = label:Clone()
	for _, c in shadow:GetChildren() do
		c:Destroy()
	end
	shadow.Name = label.Name .. "Shadow"
	shadow.TextColor3 = C.shadow
	shadow.TextTransparency = 0.55
	shadow.Position = label.Position + UDim2.fromOffset(0, drop or 3)
	shadow.ZIndex = math.max(1, label.ZIndex - 1)
	shadow.Parent = label.Parent
	return shadow
end

function Kit.corner(parent: Instance, radius: number): UICorner
	-- Keep every kit stroke a whole number of DRAWN pixels at `scale` (UIScale
	-- scales UIStroke: a 2 px stroke at 0.83 would draw a soft 1.66 px). Strokes
	-- made here carry their design width in a "BaseThickness" attribute; nested
	-- UIScales between a stroke and `root` count, "PopScale" pops don't.
	function Kit.snapStrokes(root: Instance, scale: number)
		for _, d in root:GetDescendants() do
			if d:IsA("UIStroke") then
				local base = d:GetAttribute("BaseThickness")
				if typeof(base) == "number" then
					local s = scale
					local cur = d.Parent
					while cur and cur ~= root do
						for _, c in cur:GetChildren() do
							if c:IsA("UIScale") and c.Name ~= "PopScale" then
								s *= c.Scale
							end
						end
						cur = cur.Parent
					end
					s = math.max(s, 0.05)
					d.Thickness = math.max(1, math.floor(base * s + 0.5)) / s
				end
			end
		end
	end

	return Kit.make("UICorner", {
		Name = "Corner",
		CornerRadius = if radius >= Style.RADIUS.pill
			then UDim.new(0.5, 0)
			else UDim.new(0, radius),
	}, parent)
end

-- A whole-pixel border stroke. `BaseThickness` lets Layout re-snap it per scale.
function Kit.stroke(
	parent: Instance,
	color: Color3?,
	transparency: number?,
	thickness: number?
): UIStroke
	local t = thickness or Style.STROKE.base
	local stroke = Kit.make("UIStroke", {
		Name = "Stroke",
		Color = color or C.stroke,
		Transparency = if transparency ~= nil then transparency else A.stroke,
		Thickness = t,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	}, parent)
	stroke:SetAttribute("BaseThickness", t)
	return stroke
end

-- The top-lit gradient: multiplies the fill from white (top) to SHADE.bottom.
function Kit.shade(parent: Instance, bottom: Color3?): UIGradient
	-- Keep every kit stroke a whole number of DRAWN pixels at `scale` (UIScale
	-- scales UIStroke: a 2 px stroke at 0.83 would draw a soft 1.66 px). Strokes
	-- made here carry their design width in a "BaseThickness" attribute; nested
	-- UIScales between a stroke and `root` count, "PopScale" pops don't.
	function Kit.snapStrokes(root: Instance, scale: number)
		for _, d in root:GetDescendants() do
			if d:IsA("UIStroke") then
				local base = d:GetAttribute("BaseThickness")
				if typeof(base) == "number" then
					local s = scale
					local cur = d.Parent
					while cur and cur ~= root do
						for _, c in cur:GetChildren() do
							if c:IsA("UIScale") and c.Name ~= "PopScale" then
								s *= c.Scale
							end
						end
						cur = cur.Parent
					end
					s = math.max(s, 0.05)
					d.Thickness = math.max(1, math.floor(base * s + 0.5)) / s
				end
			end
		end
	end

	return Kit.make("UIGradient", {
		Name = "Shade",
		Rotation = 90,
		Color = ColorSequence.new(C.white, bottom or Style.SHADE.bottom),
	}, parent)
end

export type SurfaceOptions = {
	className: string?, -- "Frame" (default), "TextButton", "ImageButton", "CanvasGroup"
	color: Color3?,
	transparency: number?,
	radius: number?,
	stroke: (Color3 | boolean)?, -- false: no stroke
	strokeTransparency: number?,
	strokeThickness: number?,
	gradient: boolean?, -- default true
}

-- A rounded panel / tile / button face.
function Kit.surface(parent: Instance, props: { [string]: any }?, opts: SurfaceOptions?): any
	local o: SurfaceOptions = opts or {}
	local className = o.className or "Frame"
	local obj = Kit.make(className, {
		BackgroundColor3 = o.color or C.surface,
		BackgroundTransparency = if o.transparency ~= nil then o.transparency else A.surface,
		BorderSizePixel = 0,
	}, nil)
	if className == "TextButton" then
		obj.Text = ""
		obj.AutoButtonColor = false
	elseif className == "ImageButton" then
		obj.Image = ""
		obj.AutoButtonColor = false
	end
	Kit.corner(obj, o.radius or Style.RADIUS.lg)
	if o.stroke ~= false then
		local color = if typeof(o.stroke) == "Color3" then o.stroke else nil
		Kit.stroke(obj, color, o.strokeTransparency, o.strokeThickness)
	end
	if o.gradient ~= false then
		Kit.shade(obj)
	end
	apply(obj, props)
	obj.Parent = parent
	return obj
end

-- Stacked soft shadow BEHIND `obj` (a sibling, so it stays put when the object
-- lifts on hover: the gap reads as elevation). Call after obj has its final
-- Size / Position / AnchorPoint / parent.
function Kit.shadow(obj: GuiObject, radius: number, strength: number?): Frame?
	if not Style.FLAGS.shadows then
		return nil
	end
	local parent = obj.Parent
	if not parent then
		return nil
	end
	local k = strength or 1
	local holder = Kit.make("Frame", {
		Name = obj.Name .. "Shadow",
		AnchorPoint = obj.AnchorPoint,
		Position = obj.Position,
		Size = obj.Size,
		BackgroundTransparency = 1,
		ZIndex = math.max(0, obj.ZIndex - 1),
		Active = false,
	}, parent)
	for _, layer in Style.SHADOW.layers do
		local grow, drop, t = layer[1], layer[2], layer[3]
		local f = Kit.make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, drop),
			Size = UDim2.new(1, grow * 2, 1, grow * 2),
			BackgroundColor3 = C.shadow,
			BackgroundTransparency = 1 - (1 - t) * k,
			BorderSizePixel = 0,
			ZIndex = holder.ZIndex,
		}, holder)
		Kit.corner(f, if radius >= Style.RADIUS.pill then radius else radius + grow)
	end
	return holder
end

-- A looping tween starter (the Lobby's Fx.loop, the match's own), so the kit
-- doesn't depend on either side's motion module.
export type Looper = (obj: Instance, time: number, props: { [string]: any }) -> any

export type Glow = {
	frame: Frame,
	layers: { Frame },
	setColor: (Color3) -> (),
	breathe: (loop: Looper) -> (),
}

-- A soft glow around a shape: stacked rounded layers that fade outward
-- (concentric: radius + grow). `breathe(loop)` starts the idle pulse with the
-- caller's loop helper (the Lobby's Fx.loop pauses while hidden and stops
-- under reduced motion).
function Kit.glow(parent: Instance, radius: number, color: Color3): Glow
	local frame = Kit.make("Frame", {
		Name = "Glow",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 1,
	}, parent)
	local layers: { Frame } = {}
	for _, layer in Style.GLOW.layers do
		local grow, t = layer[1], layer[2]
		local f = Kit.make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, grow * 2, 1, grow * 2),
			BackgroundColor3 = color,
			BackgroundTransparency = t,
			BorderSizePixel = 0,
			ZIndex = 1,
		}, frame)
		f:SetAttribute("BaseTransparency", t)
		Kit.corner(f, radius + grow)
		table.insert(layers, f)
	end
	local glow: Glow
	glow = {
		frame = frame,
		layers = layers,
		setColor = function(c: Color3)
			for _, f in layers do
				f.BackgroundColor3 = c
			end
		end,
		breathe = function(loop: Looper)
			for _, f in layers do
				local t = f:GetAttribute("BaseTransparency") :: number
				loop(
					f,
					Style.GLOW.period,
					{ BackgroundTransparency = 1 - (1 - t) * Style.GLOW.peak }
				)
			end
		end,
	}
	return glow
end

export type Primary = {
	holder: Frame,
	face: TextButton,
	lip: Frame,
	label: TextLabel,
	glow: Glow,
	press: (down: boolean) -> (),
}

-- The gold call-to-action (PLAY, FIND MATCH): a lip in the darker gold, the
-- face above it with a gold gradient and a light edge, an outer glow ring.
-- `holder` takes the props (Size / Position / AnchorPoint / Name / LayoutOrder).
function Kit.primary(
	parent: Instance,
	props: { [string]: any },
	text: string,
	textStyle: string,
	radius: number
): Primary
	local lip = Style.LIP
	local holder = Kit.make("Frame", { BackgroundTransparency = 1 }, nil)
	apply(holder, props)
	holder.Parent = parent
	local glow = Kit.glow(holder, radius, C.primary)
	local base = Kit.make("Frame", {
		Name = "Lip",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.primaryLip,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, holder)
	Kit.corner(base, radius)
	Kit.shadow(base, radius, 0.9)
	local face = Kit.make("TextButton", {
		Name = "Face",
		Text = "",
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.new(1, 0, 1, -lip),
		BackgroundColor3 = C.white,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, holder)
	Kit.corner(face, radius)
	Kit.make("UIGradient", {
		Name = "Shade",
		Rotation = 90,
		Color = ColorSequence.new(C.primaryTop, C.primaryBottom),
	}, face)
	Kit.stroke(face, C.white, A.strokeOnPrimary)
	local label = Kit.text(face, text, textStyle, {
		Name = "Label",
		Size = UDim2.fromScale(1, 1),
		TextColor3 = C.onPrimary,
		ZIndex = 4,
	})
	-- Pressed: the face sinks into the lip (LihFolk UI Spec: lip − 2 px).
	local function press(down: boolean)
		face.Position = UDim2.new(0.5, 0, 0, if down then lip - 2 else 0)
	end
	return { holder = holder, face = face, lip = base, label = label, glow = glow, press = press }
end

-- A round icon button (close, settings): returns the button.
function Kit.circle(parent: Instance, props: { [string]: any }, size: number): TextButton
	local holder = Kit.make("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size, size),
	}, nil)
	apply(holder, props)
	holder.Parent = parent
	local button = Kit.surface(holder, {
		Name = "Button",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
	}, { className = "TextButton", radius = Style.RADIUS.pill, transparency = A.chip })
	Kit.shadow(button, Style.RADIUS.pill, 0.8)
	return button
end

-- The ✕ glyph drawn as two bars (crisp at any size).
function Kit.cross(parent: Instance, size: number, color: Color3?)
	for _, r in { 45, -45 } do
		local bar = Kit.make("Frame", {
			Name = "Cross",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(size, 3),
			Rotation = r,
			BackgroundColor3 = color or C.text,
			BorderSizePixel = 0,
			ZIndex = 4,
		}, parent)
		Kit.corner(bar, 2)
	end
end

-- A pill tag (IN QUEUE, COMING SOON): solid or tinted with an outline.
function Kit.tag(
	parent: Instance,
	content: string,
	color: Color3,
	props: { [string]: any }?,
	solid: boolean?
): Frame
	local tag = Kit.make("Frame", {
		Name = "Tag",
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		BackgroundColor3 = color,
		BackgroundTransparency = if solid then 0 else 0.84,
		BorderSizePixel = 0,
	}, parent)
	Kit.corner(tag, Style.RADIUS.pill)
	Kit.make("UIPadding", {
		PaddingLeft = UDim.new(0, 14),
		PaddingRight = UDim.new(0, 14),
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
	}, tag)
	if not solid then
		Kit.stroke(tag, color, 0.2)
	end
	Kit.text(tag, string.upper(content), "labelS", {
		Name = "Label",
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		TextColor3 = if solid then C.onPrimary else color,
	})
	apply(tag, props)
	return tag
end

-- A keyboard key chip ("1", "ENTER").
function Kit.keyChip(parent: Instance, content: string, props: { [string]: any }?): Frame
	local chip = Kit.make("Frame", {
		Name = "Key",
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 32),
		BackgroundColor3 = C.surfaceDeep,
		BackgroundTransparency = A.deep,
		BorderSizePixel = 0,
	}, parent)
	Kit.corner(chip, Style.RADIUS.sm)
	Kit.stroke(chip, C.stroke, 0.78)
	Kit.make("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, chip)
	Kit.text(chip, content, "labelS", {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
	})
	apply(chip, props)
	return chip
end

-- A thin rounded rule.
function Kit.divider(parent: Instance, props: { [string]: any }): Frame
	local d = Kit.make("Frame", {
		Name = "Divider",
		BackgroundColor3 = C.stroke,
		BackgroundTransparency = 0.9,
		BorderSizePixel = 0,
	}, parent)
	apply(d, props)
	return d
end

-- A round progress track with a fill; returns (track, fill).
function Kit.track(parent: Instance, props: { [string]: any }, color: Color3?): (Frame, Frame)
	local track = Kit.make("Frame", {
		Name = "Track",
		BackgroundColor3 = C.stroke,
		BackgroundTransparency = 0.84,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, parent)
	apply(track, props)
	Kit.corner(track, Style.RADIUS.pill)
	local fill = Kit.make("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = color or C.primary,
		BorderSizePixel = 0,
		ZIndex = track.ZIndex + 1,
	}, track)
	Kit.corner(fill, Style.RADIUS.pill)
	return track, fill
end

-- Keep every kit stroke a whole number of DRAWN pixels at `scale` (UIScale
-- scales UIStroke: a 2 px stroke at 0.83 would draw a soft 1.66 px). Strokes
-- made here carry their design width in a "BaseThickness" attribute; nested
-- UIScales between a stroke and `root` count, "PopScale" pops don't.
function Kit.snapStrokes(root: Instance, scale: number)
	for _, d in root:GetDescendants() do
		if d:IsA("UIStroke") then
			local base = d:GetAttribute("BaseThickness")
			if typeof(base) == "number" then
				local s = scale
				local cur = d.Parent
				while cur and cur ~= root do
					for _, c in cur:GetChildren() do
						if c:IsA("UIScale") and c.Name ~= "PopScale" then
							s *= c.Scale
						end
					end
					cur = cur.Parent
				end
				s = math.max(s, 0.05)
				d.Thickness = math.max(1, math.floor(base * s + 0.5)) / s
			end
		end
	end
end

return Kit
