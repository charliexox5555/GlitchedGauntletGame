--!strict
-- Rebuilds the match top bar (v2.2 + centred pivots, 2026-11-14) in the match place
-- (vault/02 Art/UI Top Bar Draft.md). Regenerated from the saved place.
-- Studio owns StarterGui.TopBar and ReplicatedStorage.UiTemplates.TopBar.Player;
-- this is their backup in git. Paste into the Studio command bar (Edit mode).
-- It refuses to run if StarterGui.TopBar already exists, so hand edits are
-- never overwritten: rename or delete the old one first.
-- Behaviour: src/client/Controllers/TopBarController.luau.
-- Images: tools/ui/make_topbar_v22_images.py.
--
-- Root (centred, Fit) → Shadow + Bar → AllyTeam / Centre / EnemyTeam.
-- A team = Body (rounded, two-tone UIGradient; Players + Score) + Slant cap.
-- Pieces that pop scale from their centre: Score.Inner, Timer, each player's Cell.

local StarterGui = game:GetService("StarterGui")
local RS = game:GetService("ReplicatedStorage")

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

local BX = "rbxassetid://12187365977" -- Rubik (UI Match Overhaul: was Builder Extended)
local BOT_HEAD = "rbxassetid://119185654291939"
local CAP_RIGHT, CAP_LEFT = "rbxassetid://130377997107460", "rbxassetid://75584308608588"
local SHADOW = "rbxassetid://121253415859134"
local STOPWATCH = "rbxassetid://85745477188818"
local WHITE = Color3.new(1, 1, 1)
local INK = Color3.fromHex("08080B")
local CENTRE = Vector2.new(0.5, 0.5)
local FILL = UDim2.fromScale(1, 1)

local TEAMS = {
	ally = {
		top = Color3.fromHex("3FE0F2"),
		shade = Color3.new(0.41, 0.63, 0.76),
		cell = Color3.fromHex("0D5C7A"),
	},
	enemy = {
		top = Color3.fromHex("FF6B57"),
		shade = Color3.new(0.77, 0.4, 0.59),
		cell = Color3.fromHex("8A1C24"),
	},
}

assert(not StarterGui:FindFirstChild("TopBar"), "StarterGui.TopBar already exists")

-- Player cell template: a fixed holder in the row, the Cell centred in it ----
local templates = RS:FindFirstChild("UiTemplates") or make("Folder", { Name = "UiTemplates" }, RS)
local folder = templates:FindFirstChild("TopBar") or make("Folder", { Name = "TopBar" }, templates)
local old = folder:FindFirstChild("Player")
if old then
	old:Destroy()
end
local template = make(
	"Frame",
	{ Name = "Player", Size = UDim2.fromOffset(70, 66), BackgroundTransparency = 1 },
	folder
)
local cell = make("CanvasGroup", {
	Name = "Cell",
	AnchorPoint = CENTRE,
	Position = UDim2.fromScale(0.5, 0.5),
	Size = FILL,
	BackgroundColor3 = TEAMS.ally.cell,
	BackgroundTransparency = 0.1,
	BorderSizePixel = 0,
}, template)
make("UICorner", { CornerRadius = UDim.new(0, 6) }, cell)
make("UIGradient", {
	Name = "Shade",
	Rotation = 90,
	Color = ColorSequence.new(WHITE, Color3.fromRGB(170, 170, 170)),
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
make("UIScale", { Name = "Pop" }, cell)

-- Gui ----------------------------------------------------------------------
local gui = make("ScreenGui", {
	Name = "TopBar",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
	IgnoreGuiInset = true,
	DisplayOrder = 9,
})
local root = make("Frame", {
	Name = "Root",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.0185),
	Size = UDim2.fromOffset(0, 80),
	BackgroundTransparency = 1,
}, gui)
make("UIScale", { Name = "Fit" }, root)
make("ImageLabel", {
	Name = "Shadow",
	AnchorPoint = CENTRE,
	Position = UDim2.new(0.5, 0, 0, 46),
	Size = UDim2.fromOffset(746, 128), -- TopBarController sizes it to the bar
	BackgroundTransparency = 1,
	ZIndex = 0,
	Image = SHADOW,
	ImageColor3 = Color3.new(0, 0, 0),
	ImageTransparency = 0.45,
	ScaleType = Enum.ScaleType.Slice,
	SliceCenter = Rect.new(48, 48, 80, 80),
}, root)
local bar = make("Frame", {
	Name = "Bar",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0),
	Size = UDim2.fromOffset(0, 80),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundTransparency = 1,
}, root)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	Padding = UDim.new(0, 8),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, bar)

local function teamBlock(
	name: string,
	order: number,
	team: { top: Color3, shade: Color3, cell: Color3 },
	isAlly: boolean
)
	local shade = ColorSequence.new(WHITE, team.shade)
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
		HorizontalAlignment = align,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, body)
	local players = make("Frame", {
		Name = "Players",
		LayoutOrder = if isAlly then 1 else 2,
		Size = UDim2.fromOffset(0, 80),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
	}, body)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = align,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, players)
	-- Edit-mode preview cells (the controller removes them in play)
	for i = 1, 2 do
		local p = template:Clone()
		p.Name = "Preview" .. i
		p:SetAttribute("Preview", true)
		p.LayoutOrder = if isAlly then -i else i
		local pc = p:FindFirstChild("Cell")
		if pc and pc:IsA("CanvasGroup") then
			pc.BackgroundColor3 = team.cell
		end
		p.Parent = players
	end
	local score = make("Frame", {
		Name = "Score",
		LayoutOrder = if isAlly then 2 else 1,
		Size = UDim2.fromOffset(62, 80),
		BackgroundTransparency = 1,
	}, body)
	local inner = make("Frame", {
		Name = "Inner",
		AnchorPoint = CENTRE,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = FILL,
		BackgroundTransparency = 1,
	}, score)
	for _, part in { "Shadow", "Value" } do
		make("TextLabel", {
			Name = part,
			Position = UDim2.fromOffset(0, if part == "Shadow" then 3 else 0),
			Size = FILL,
			BackgroundTransparency = 1,
			ZIndex = if part == "Shadow" then 1 else 2,
			Text = "0",
			FontFace = Font.new(BX, Enum.FontWeight.ExtraBold),
			TextSize = 50,
			TextColor3 = if part == "Shadow" then INK else WHITE,
			TextTransparency = if part == "Shadow" then 0.6 else 0,
		}, inner)
	end
	make("UIScale", { Name = "Pop" }, inner)
	local slant = make("ImageLabel", {
		Name = "Slant",
		LayoutOrder = if isAlly then 2 else 1,
		Size = UDim2.fromOffset(28, 80),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Image = if isAlly then CAP_RIGHT else CAP_LEFT,
		ImageColor3 = team.top,
	}, block)
	make("UIGradient", { Name = "Shade", Rotation = 90, Color = shade }, slant)
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
	AnchorPoint = CENTRE,
	Position = UDim2.fromScale(0.5, 0.5),
	Size = FILL,
	BackgroundColor3 = Color3.fromHex("1F1F22"),
	BorderSizePixel = 0,
}, centre)
make("UICorner", { CornerRadius = UDim.new(0, 6) }, timer)
make("UIGradient", {
	Name = "Shade",
	Rotation = 90,
	Color = ColorSequence.new(WHITE, Color3.fromRGB(140, 140, 140)),
}, timer)
make("UIStroke", {
	Name = "Edge",
	ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	Color = Color3.fromHex("FF4D5E"),
	Thickness = 2,
	Transparency = 1,
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
	FontFace = Font.new(BX, Enum.FontWeight.ExtraBold),
	TextSize = 34,
	TextColor3 = WHITE,
}, clock)
make("TextLabel", {
	Name = "Info",
	Position = UDim2.fromOffset(0, 52),
	Size = UDim2.new(1, 0, 0, 18),
	BackgroundTransparency = 1,
	RichText = true,
	Text = "ROUND 6 · HEAVY",
	FontFace = Font.new(BX, Enum.FontWeight.Bold),
	TextSize = 13,
	TextColor3 = Color3.fromHex("A3A3A6"),
}, timer)

teamBlock("EnemyTeam", 3, TEAMS.enemy, false)
gui.Parent = StarterGui
print("TopBar built")
