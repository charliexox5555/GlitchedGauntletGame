--!strict
-- The match UI kit (vault/02 Art/UI Design.md; v2 look since 2026-11-05, see
-- vault/01 Design/Match HUD.md): small builders shared by the draft, match HUD
-- and combat HUD, reading Config/Theme (whose tokens resolve to Config/UiStyle)
-- and drawing with Shared/UiKit, the same rounded shapes as the Lobby. Layouts are Offset at the
-- 1920 x 1080 design size; `fit` gives a cluster one UIScale that follows its
-- ScreenGui's size (min of width / 1920 and height / 1080), scaled around its
-- AnchorPoint.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Theme = require(ReplicatedStorage.Shared.Config.Theme)
local UiKit = require(ReplicatedStorage.Shared.UiKit)
local UiStyle = require(ReplicatedStorage.Shared.Config.UiStyle)

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
	corner: number?, -- v1 cut size in design px (default 20); mapped to a radius
	radius: number?, -- or the corner radius directly
	color: Color3?,
	transparency: number?,
	line: Color3?, -- an outline (a UIStroke named "Line"), if given
	lineTransparency: number?,
	className: string?, -- "ImageLabel" (default) or "ImageButton"
}

-- v1 cut sizes (12-26) to v2 corner radii.
function Ui.radius(corner: number): number
	return math.clamp(math.floor(corner * 0.8 + 0.5), 8, UiStyle.RADIUS.xl)
end

-- A card or button: a rounded v2 surface (UICorner, top-lit gradient) with an
-- optional 2 px outline drawn as a UIStroke named "Line". Kept under its v1 name
-- so every builder switched look at once. Colour it with BackgroundColor3.
function Ui.cut(parent: Instance, props: { [string]: any }, opts: CutOptions?): any
	local o: CutOptions = opts or {}
	local fill = Ui.make(o.className or "ImageLabel", {
		BackgroundColor3 = o.color or C.card,
		BackgroundTransparency = o.transparency or 0,
		BorderSizePixel = 0,
		Image = "",
	})
	if o.className == "ImageButton" then
		fill.AutoButtonColor = false
	end
	UiKit.corner(fill, o.radius or Ui.radius(o.corner or 20))
	UiKit.shade(fill)
	if o.line then
		local stroke = UiKit.stroke(fill, o.line, o.lineTransparency or 0)
		stroke.Name = "Line"
	end
	for k, v in props do
		(fill :: any)[k] = v
	end
	fill.Parent = parent
	return fill
end

-- A small caps tag (role, path, shield): a pill, tinted fill and outline, sized
-- to its text.
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
		BorderSizePixel = 0,
	}, parent)
	UiKit.corner(tag, UiStyle.RADIUS.pill)
	Ui.make("UIPadding", {
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
		PaddingTop = UDim.new(0, 5),
		PaddingBottom = UDim.new(0, 5),
	}, tag)
	if not solid then
		UiKit.stroke(tag, color, 0.2)
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
-- filled). 150 x 44, anchored at its top centre; a rounded v2 tab.
function Ui.keyTab(parent: Instance, key: string, level: number, position: UDim2): Frame
	local tab = Ui.make("Frame", {
		Name = "KeyTab",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = position,
		Size = UDim2.fromOffset(150, 44),
		BackgroundColor3 = C.raised,
		BorderSizePixel = 0,
		ZIndex = 5,
	}, parent)
	UiKit.corner(tab, UiStyle.RADIUS.md)
	UiKit.shade(tab)
	UiKit.stroke(tab, C.white, UiStyle.ALPHA.stroke)
	Ui.text(tab, key, "key", {
		Size = UDim2.fromOffset(150, 24),
		Position = UDim2.fromOffset(0, 3),
		ZIndex = 6,
	})
	for i = 1, 3 do
		local pip = Ui.make("Frame", {
			Position = UDim2.fromOffset(30 + (i - 1) * 32, 30),
			Size = UDim2.fromOffset(26, 5),
			BorderSizePixel = 0,
			BackgroundColor3 = if i <= level then C.ally else C.lineStrong,
			ZIndex = 6,
		}, tab)
		UiKit.corner(pip, 3)
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
	local floor = math.ceil(Ui.MIN_TEXT_PX / math.max(scale, 0.05))
	for _, d in root:GetDescendants() do
		if d:IsA("TextLabel") or d:IsA("TextButton") then
			local base = d:GetAttribute("BaseTextSize")
			if typeof(base) ~= "number" then
				base = d.TextSize
				d:SetAttribute("BaseTextSize", base)
			end
			d.TextSize = math.max(base :: number, floor)
		end
	end
end

-- Re-apply the text floor and stroke snap after building new content inside
-- a fitted cluster (draft cards, kill-feed rows).
function Ui.refit(obj: GuiObject)
	local scale = obj:FindFirstChild("Fit")
	if scale and scale:IsA("UIScale") then
		floorText(obj, scale.Scale)
		UiKit.snapStrokes(obj, scale.Scale)
	end
end

-- Scale a design-size cluster with its ScreenGui (call it once the object is
-- parented under the ScreenGui). Also keeps drawn text at Ui.MIN_TEXT_PX or
-- more and strokes on whole drawn pixels.
function Ui.fit(obj: GuiObject): UIScale
	local gui = obj:FindFirstAncestorWhichIsA("LayerCollector")
	local scale = Ui.make("UIScale", { Name = "Fit", Scale = screenScale(gui) }, obj)
	Ui.refit(obj)
	task.defer(Ui.refit, obj)
	if gui then
		local conn = gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			scale.Scale = screenScale(gui)
			Ui.refit(obj)
		end)
		scale.Destroying:Connect(function()
			conn:Disconnect()
		end)
	end
	return scale
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
