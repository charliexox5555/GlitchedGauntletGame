--!strict
-- Rebuilds the match top bar (v2.2) in the match place (vault/02 Art/UI Top Bar Draft.md).
-- Studio owns StarterGui.TopBar and ReplicatedStorage.UiTemplates.TopBar.Player;
-- this is their backup in git. Paste into the Studio command bar (Edit mode).
-- It refuses to run if StarterGui.TopBar already exists, so hand edits are
-- never overwritten: rename or delete the old one first. Behaviour lives in
-- src/client/Controllers/TopBarController.luau. Images: tools/ui/make_topbar_v22_images.py.
--
-- Root (centred, Fit UIScale) → Shadow (soft 9-slice) + Bar → AllyTeam / Centre / EnemyTeam.
-- A team = Body (rounded Frame, two-tone UIGradient; Players + Score) + Slant
-- (fixed-size cap image with the same UIGradient, overlapping the body by 8 px).
-- Colours to tweak live on the instances: Body.BackgroundColor3 (top colour),
-- the Shade gradients (bottom tint) and Body's "CellColor" attribute.

local StarterGui = game:GetService("StarterGui")
local RS = game:GetService("ReplicatedStorage")

local function hex(h: string): Color3
	return Color3.fromHex(h)
end
local function make(class: string, props: { [string]: any }, parent: Instance?): any
	local i = Instance.new(class)
	for k, v in props do
		(i :: any)[k] = v
	end
	if parent then
		i.Parent = parent
	end
	return i
end

local BUILDER_X = "rbxasset://fonts/families/BuilderExtended.json"
local BOT_HEAD = "rbxassetid://119185654291939"
local CAP_RIGHT, CAP_LEFT = "rbxassetid://130377997107460", "rbxassetid://75584308608588"
local SHADOW = "rbxassetid://121253415859134"
local STOPWATCH = "rbxassetid://85745477188818"

-- top colour + the bottom as a multiplier of it (UIGradient multiplies)
local TEAMS = {
	ally = { top = hex("3FE0F2"), shade = Color3.new(0.41, 0.63, 0.76), cell = hex("0D5C7A") },
	enemy = { top = hex("FF6B57"), shade = Color3.new(0.77, 0.40, 0.59), cell = hex("8A1C24") },
}

assert(not StarterGui:FindFirstChild("TopBar"), "StarterGui.TopBar already exists")

-- Player cell template -------------------------------------------------------
local templates = RS:FindFirstChild("UiTemplates") or make("Folder", { Name = "UiTemplates" }, RS)
local folder = templates:FindFirstChild("TopBar") or make("Folder", { Name = "TopBar" }, templates)
local old = folder:FindFirstChild("Player")
if old then
	old:Destroy()
end
local cell = make("CanvasGroup", {
	Name = "Player",
	Size = UDim2.fromOffset(70, 66),
	BackgroundColor3 = TEAMS.ally.cell,
	BackgroundTransparency = 0.1,
	BorderSizePixel = 0,
}, folder)
make("UICorner", { CornerRadius = UDim.new(0, 6) }, cell)
make("UIGradient", {
	Name = "Shade",
	Rotation = 90,
	Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 170)),
}, cell)
make("ImageLabel", {
	Name = "Headshot",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, 3),
	Size = UDim2.fromOffset(70, 70),
	BackgroundTransparency = 1,
	Image = BOT_HEAD,
	ScaleType = Enum.ScaleType.Fit,
}, cell)

-- Gui ----------------------------------------------------------------------
local gui = make("ScreenGui", {
	Name = "TopBar",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
	DisplayOrder = 9,
	IgnoreGuiInset = true,
})
local root = make("Frame", {
	Name = "Root",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.0185),
	Size = UDim2.fromOffset(0, 80), -- fixed: an auto-sized root grows with the shadow; the bar centres on it
	BackgroundTransparency = 1,
}, gui)
make("UIScale", { Name = "Fit" }, root)
make("ImageLabel", {
	Name = "Shadow",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0, 46),
	Size = UDim2.fromOffset(746, 128), -- TopBarController sizes it to the bar
	BackgroundTransparency = 1,
	Image = SHADOW,
	ImageColor3 = Color3.new(0, 0, 0),
	ImageTransparency = 0.45,
	ScaleType = Enum.ScaleType.Slice,
	SliceCenter = Rect.new(48, 48, 80, 80),
	ZIndex = 0,
}, root)
local bar = make("Frame", {
	Name = "Bar",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0),
	Size = UDim2.fromOffset(0, 80),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundTransparency = 1,
	ZIndex = 1,
}, root)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Top,
	Padding = UDim.new(0, 8),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, bar)

local function teamBlock(
	name: string,
	order: number,
	team: { top: Color3, shade: Color3, cell: Color3 },
	isAlly: boolean
)
	local shade = ColorSequence.new(Color3.new(1, 1, 1), team.shade)
	local block = make("Frame", {
		Name = name,
		LayoutOrder = order,
		Size = UDim2.fromOffset(0, 80),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
	}, bar)
	make("UIScale", { Name = "Pop" }, block)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Top,
		Padding = UDim.new(0, -8), -- the cap overlaps the body's inner rounded corners
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, block)
	local body = make("Frame", {
		Name = "Body",
		LayoutOrder = if isAlly then 1 else 2,
		Size = UDim2.fromOffset(0, 80),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = team.top,
		BorderSizePixel = 0,
	}, block)
	body:SetAttribute("CellColor", team.cell)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, body)
	make("UIGradient", { Name = "Shade", Rotation = 90, Color = shade }, body)
	make("UIPadding", {
		PaddingLeft = UDim.new(0, if isAlly then 7 else 12),
		PaddingRight = UDim.new(0, if isAlly then 12 else 7),
	}, body)
	local align = if isAlly then Enum.HorizontalAlignment.Right else Enum.HorizontalAlignment.Left
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		HorizontalAlignment = align,
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, body)
	local slant = make("ImageLabel", {
		Name = "Slant",
		LayoutOrder = if isAlly then 2 else 1,
		Size = UDim2.fromOffset(28, 80),
		BackgroundTransparency = 1,
		Image = if isAlly then CAP_RIGHT else CAP_LEFT,
		ImageColor3 = team.top,
		ZIndex = 2,
	}, block)
	make("UIGradient", { Name = "Shade", Rotation = 90, Color = shade }, slant)
	local players = make("Frame", {
		Name = "Players",
		LayoutOrder = if isAlly then 1 else 2,
		Size = UDim2.fromOffset(0, 80),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
	}, body)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		HorizontalAlignment = align,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, players)
	local score = make("Frame", {
		Name = "Score",
		LayoutOrder = if isAlly then 2 else 1,
		Size = UDim2.fromOffset(62, 80),
		BackgroundTransparency = 1,
	}, body)
	make("UIScale", { Name = "Pop" }, score)
	make("TextLabel", {
		Name = "Shadow",
		Position = UDim2.fromOffset(0, 3),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "0",
		FontFace = Font.new(BUILDER_X, Enum.FontWeight.ExtraBold),
		TextSize = 50,
		TextColor3 = hex("06080C"),
		TextTransparency = 0.6,
		ZIndex = 1,
	}, score)
	make("TextLabel", {
		Name = "Value",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "0",
		FontFace = Font.new(BUILDER_X, Enum.FontWeight.ExtraBold),
		TextSize = 50,
		TextColor3 = Color3.new(1, 1, 1),
		ZIndex = 2,
	}, score)
	-- Edit-mode preview cells (the controller removes them in play)
	for i = 1, 2 do
		local p = cell:Clone()
		p.Name = "Preview" .. i
		p:SetAttribute("Preview", true)
		p.BackgroundColor3 = team.cell
		p.LayoutOrder = if isAlly then -i else i
		p.Parent = players
	end
end

teamBlock("AllyTeam", 1, TEAMS.ally, true)

local centre = make("Frame", {
	Name = "Centre",
	LayoutOrder = 2,
	Size = UDim2.fromOffset(172, 80),
	BackgroundTransparency = 1,
}, bar)
local timer = make("Frame", {
	Name = "Timer",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = hex("1A202A"),
	BorderSizePixel = 0,
}, centre)
make("UICorner", { CornerRadius = UDim.new(0, 6) }, timer)
make("UIGradient", {
	Name = "Shade",
	Rotation = 90,
	Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(140, 140, 140)),
}, timer)
make("UIStroke", {
	Name = "Edge",
	ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	Color = hex("FF4D5E"),
	Transparency = 1,
	Thickness = 2,
}, timer)
make("UIScale", { Name = "Pop" }, timer)
local clock = make("Frame", {
	Name = "Clock",
	Position = UDim2.fromOffset(0, 6),
	Size = UDim2.new(1, 0, 0, 46),
	BackgroundTransparency = 1,
}, timer)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	Padding = UDim.new(0, 8),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, clock)
make("ImageLabel", {
	Name = "Icon",
	LayoutOrder = 1,
	Size = UDim2.fromOffset(22, 22),
	BackgroundTransparency = 1,
	Image = STOPWATCH,
}, clock)
make("TextLabel", {
	Name = "Time",
	LayoutOrder = 2,
	Size = UDim2.fromOffset(0, 46),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundTransparency = 1,
	Text = "1:24",
	FontFace = Font.new(BUILDER_X, Enum.FontWeight.ExtraBold),
	TextSize = 34,
	TextColor3 = Color3.new(1, 1, 1),
}, clock)
make("TextLabel", {
	Name = "Info",
	Position = UDim2.fromOffset(0, 52),
	Size = UDim2.new(1, 0, 0, 18),
	BackgroundTransparency = 1,
	RichText = true,
	Text = "ROUND 6 · HEAVY",
	FontFace = Font.new(BUILDER_X, Enum.FontWeight.Bold),
	TextSize = 13,
	TextColor3 = hex("9AA4B2"),
}, timer)

teamBlock("EnemyTeam", 3, TEAMS.enemy, false)
gui.Parent = StarterGui
print("TopBar v2.2 built")
