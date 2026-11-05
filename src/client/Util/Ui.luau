--!strict
-- The UI v1 kit (vault/02 Art/UI Design.md): small builders shared by the draft,
-- match HUD and combat HUD, all reading Config/Theme. Layouts are Offset at the
-- 1920 x 1080 design size; `fit` gives a cluster one UIScale that follows its
-- ScreenGui's size (min of width / 1920 and height / 1080), scaled around its
-- AnchorPoint.

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Theme = require(ReplicatedStorage.Shared.Config.Theme)

local Ui = {}

local C = Theme.COLORS
local tweens: { [Instance]: Tween } = setmetatable({}, { __mode = "k" }) :: any

function Ui.make(className: string, props: { [string]: any }, parent: Instance?): any
	local inst = Instance.new(className)
	for k, v in props do
		(inst :: any)[k] = v
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

-- A label in one of Theme.TEXT's styles. Text never scales: sizes are design px.
function Ui.text(
	parent: Instance,
	content: string,
	style: string,
	props: { [string]: any }?
): TextLabel
	local s = Theme.TEXT[style]
	local label = Ui.make("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = s.font,
		TextSize = s.size,
		TextColor3 = C.text,
		Text = content,
		Size = UDim2.fromOffset(200, s.size * 1.2),
	}, parent)
	if props then
		for k, v in props do
			(label :: any)[k] = v
		end
	end
	return label
end

export type CutOptions = {
	corner: number?, -- design px of each cut (default 20)
	color: Color3?,
	transparency: number?,
	line: Color3?, -- an outline, if given
	lineTransparency: number?,
	className: string?, -- "ImageLabel" (default) or "ImageButton"
}

-- A card or button with cut top-left and bottom-right corners (9-slice), and
-- an optional outline drawn as a child named "Line".
function Ui.cut(parent: Instance, props: { [string]: any }, opts: CutOptions?): any
	local o: CutOptions = opts or {}
	local sliceScale = (o.corner or 20) / 32
	local fill = Ui.make(o.className or "ImageLabel", {
		BackgroundTransparency = 1,
		Image = Theme.IMAGE.cutFill,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Theme.IMAGE.cutSlice,
		SliceScale = sliceScale,
		ImageColor3 = o.color or C.card,
		ImageTransparency = o.transparency or 0,
	}, parent)
	if o.className == "ImageButton" then
		fill.AutoButtonColor = false
	end
	for k, v in props do
		(fill :: any)[k] = v
	end
	if o.line then
		Ui.make("ImageLabel", {
			Name = "Line",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = Theme.IMAGE.cutLine,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Theme.IMAGE.cutSlice,
			SliceScale = sliceScale,
			ImageColor3 = o.line,
			ImageTransparency = o.lineTransparency or 0,
			ZIndex = 3,
		}, fill)
	end
	return fill
end

-- A small caps tag (role, path, shield): tinted fill, outline, sized to its text.
function Ui.tag(
	parent: Instance,
	content: string,
	color: Color3,
	props: { [string]: any }?,
	solid: boolean?
): Frame
	local tag = Ui.make("Frame", {
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		BackgroundColor3 = color,
		BackgroundTransparency = if solid then 0 else 0.84,
	}, parent)
	Ui.make("UICorner", { CornerRadius = UDim.new(0, 3) }, tag)
	Ui.make("UIPadding", {
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
		PaddingTop = UDim.new(0, 5),
		PaddingBottom = UDim.new(0, 5),
	}, tag)
	if not solid then
		Ui.make(
			"UIStroke",
			{ Color = color, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
			tag
		)
	end
	Ui.text(tag, string.upper(content), "label", {
		Name = "Label",
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		TextColor3 = if solid then C.onAccent else color,
	})
	if props then
		for k, v in props do
			(tag :: any)[k] = v
		end
	end
	return tag
end

-- The key tab over a draft column: the key letter and 3 level pips (`level`
-- filled). 150 x 44, anchored at its top centre.
function Ui.keyTab(parent: Instance, key: string, level: number, position: UDim2): Frame
	local tab = Ui.make("ImageLabel", {
		Name = "KeyTab",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = position,
		Size = UDim2.fromOffset(150, 44),
		BackgroundTransparency = 1,
		Image = Theme.IMAGE.keyTabFill,
		ImageColor3 = C.raised,
		ZIndex = 5,
	}, parent)
	Ui.make("ImageLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = Theme.IMAGE.keyTabLine,
		ImageColor3 = C.lineStrong,
		ZIndex = 5,
	}, tab)
	Ui.text(tab, key, "key", {
		Size = UDim2.fromOffset(150, 24),
		Position = UDim2.fromOffset(0, 4),
		ZIndex = 6,
	})
	for i = 1, 3 do
		Ui.make("Frame", {
			Position = UDim2.fromOffset(27 + (i - 1) * 33, 30),
			Size = UDim2.fromOffset(30, 5),
			BorderSizePixel = 0,
			BackgroundColor3 = if i <= level then C.ally else C.lineStrong,
			ZIndex = 6,
		}, tab)
	end
	return tab
end

-- A gun picture (Theme.GUN), fitted into its box.
function Ui.gun(parent: Instance, id: string, props: { [string]: any }): ImageLabel
	local image = Ui.make("ImageLabel", {
		BackgroundTransparency = 1,
		Image = Theme.GUN[id] or "",
		ScaleType = Enum.ScaleType.Fit,
	}, parent)
	for k, v in props do
		(image :: any)[k] = v
	end
	return image
end

local function screenScale(gui: LayerCollector?): number
	local size: Vector2 = Theme.DESIGN
	if gui and gui:IsA("ScreenGui") and gui.AbsoluteSize.X > 0 then
		size = gui.AbsoluteSize
	else
		local camera = workspace.CurrentCamera
		if camera then
			size = camera.ViewportSize
		end
	end
	return math.min(size.X / Theme.DESIGN.X, size.Y / Theme.DESIGN.Y)
end

-- Drawn text floor for the match UI (LihFolk: Accessibility, 12 px minimum;
-- 13 here for small labels over a busy 3D scene). The authored size is kept
-- in a "BaseTextSize" attribute so a larger screen can lower it again.
Ui.MIN_TEXT_PX = 13

local function floorText(root: Instance, scale: number)
	-- Before the gui has a real size (first frames) the scale is meaningless.
	if scale < 0.2 then
		return
	end
	local floor = math.ceil(Ui.MIN_TEXT_PX / scale)
	for _, d in root:GetDescendants() do
		if d:IsA("TextLabel") or d:IsA("TextButton") then
			local base = d:GetAttribute("BaseTextSize")
			if typeof(base) ~= "number" then
				base = d.TextSize
				d:SetAttribute("BaseTextSize", base)
			end
			local size = math.max(base :: number, floor)
			d.TextSize = size
			-- A raised size gets a box tall enough for it (top edge kept); the
			-- authored height comes back when the size does.
			local autoY = d.AutomaticSize == Enum.AutomaticSize.Y
				or d.AutomaticSize == Enum.AutomaticSize.XY
			if not autoY and d.Size.Y.Scale == 0 then
				local baseH = d:GetAttribute("BaseHeight")
				if typeof(baseH) ~= "number" then
					baseH = d.Size.Y.Offset
					d:SetAttribute("BaseHeight", baseH)
				end
				local want = math.max(
					baseH :: number,
					if size > (base :: number) then math.ceil(size * 1.2) else 0
				)
				if d.Size.Y.Offset ~= want then
					d.Size = UDim2.new(d.Size.X.Scale, d.Size.X.Offset, 0, want)
				end
			end
		end
	end
end

-- Re-apply the text floor after building new content inside a fitted cluster
-- (draft cards, kill-feed rows).
function Ui.refit(obj: GuiObject)
	local scale = obj:FindFirstChild("Fit")
	if scale and scale:IsA("UIScale") then
		floorText(obj, scale.Scale)
	end
end

-- Scale a design-size cluster with its ScreenGui (call it once the object is
-- parented under the ScreenGui). Also keeps drawn text at Ui.MIN_TEXT_PX or
-- more.
function Ui.fit(obj: GuiObject): UIScale
	local gui = obj:FindFirstAncestorWhichIsA("LayerCollector")
	local scale = Ui.make("UIScale", { Name = "Fit", Scale = screenScale(gui) }, obj)
	Ui.refit(obj)
	task.defer(Ui.refit, obj)
	if gui then
		local conn = gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			-- A phone arrangement (Controllers/PhoneHudController) sets its own scale.
			if scale:GetAttribute("Override") == nil then
				scale.Scale = screenScale(gui)
			end
			Ui.refit(obj)
		end)
		scale.Destroying:Connect(function()
			conn:Disconnect()
		end)
	end
	return scale
end

-- Reduced motion (GuiService.ReducedMotionEnabled; LihFolk: UI Motion Language
-- and Timing, Accessibility): movement jumps to its end value, while fades and
-- colour still ease.
local MOVEMENT = { Position = true, Size = true, Rotation = true, Scale = true }

local function reducedMotion(): boolean
	local ok, on = pcall(function()
		return (GuiService :: any).ReducedMotionEnabled
	end)
	return ok and on == true
end

-- Give a fitted cluster a fixed scale (phone arrangements), or nil to go back
-- to following its ScreenGui.
function Ui.override(obj: GuiObject, value: number?)
	local scale = obj:FindFirstChild("Fit")
	if not (scale and scale:IsA("UIScale")) then
		return
	end
	scale:SetAttribute("Override", value)
	if value then
		scale.Scale = value
	else
		scale.Scale = screenScale(obj:FindFirstAncestorWhichIsA("LayerCollector"))
	end
	Ui.refit(obj)
end

-- Tween, replacing any tween still running on that object.
function Ui.tween(
	obj: Instance,
	time: number,
	props: { [string]: any },
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?
): Tween
	local old = tweens[obj]
	if old then
		old:Cancel()
	end
	if reducedMotion() then
		local rest: { [string]: any } = {}
		for k, v in props do
			if MOVEMENT[k] then
				(obj :: any)[k] = v
			else
				rest[k] = v
			end
		end
		props = rest
	end
	local tween = TweenService:Create(
		obj,
		TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
		props
	)
	tweens[obj] = tween
	tween:Play()
	return tween
end

return Ui
