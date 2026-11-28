--!strict
-- Builds StarterPlayerScripts.UI.Templates.Lobby.NameTag (the lobby name tag BillboardGui) in Studio, Edit mode.
-- Run with the Studio MCP (execute_luau). The old template goes to ServerStorage.UiBackups.NameTag_<n>.
-- Design: vault/02 Art/UI Name Tags.md. The owner edits the result in Studio; the controller
-- (LobbyClient/Controllers/NameTagController) only fills text and visibility, so layout tweaks are safe.

local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local RUBIK = "rbxasset://fonts/families/Rubik.json"
local BADGE = "rbxassetid://134852137458210" -- art-source/ui/nametag/level_badge.png
local FLAME = "rbxassetid://73282136637340" -- art-source/ui/streak/streak_icon.png
local GOLD = Color3.fromHex("FFC83D")
local INK = Color3.fromHex("F4F6F9")
local MUTED = Color3.fromHex("C3CAD4")
local STREAK = Color3.fromHex("FF8A3D")
local BADGE_TINT = Color3.fromHex("F4F6F9") -- light faceted hex, dark number
local BADGE_INK = Color3.fromHex("10141B")

local function new<T>(class: string, props: { [string]: any }, parent: Instance?): T
	local i = Instance.new(class)
	for k, v in props do
		(i :: any)[k] = v
	end
	i.Parent = parent
	return (i :: any) :: T
end

-- a label with a soft drop shadow (a dark copy 2 px down, under it): readable over a bright lobby, no outline
local function label(
	name: string,
	parent: Instance,
	order: number,
	size: UDim2,
	weight: Enum.FontWeight,
	textSize: number,
	color: Color3,
	text: string
): TextLabel
	local l: TextLabel = new("TextLabel", {
		Name = name,
		LayoutOrder = order,
		Size = size,
		BackgroundTransparency = 1,
		FontFace = Font.new(RUBIK, weight),
		TextSize = textSize,
		TextColor3 = color,
		Text = text,
		ZIndex = 3,
	}, parent)
	new("TextLabel", {
		Name = "Shadow",
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromOffset(0, 2),
		BackgroundTransparency = 1,
		FontFace = l.FontFace,
		TextSize = textSize,
		TextColor3 = Color3.new(0, 0, 0),
		TextTransparency = 0.3,
		Text = text,
		ZIndex = 1,
	}, l)
	return l
end

local lobby = StarterPlayer.StarterPlayerScripts
	:WaitForChild("UI")
	:WaitForChild("Templates")
	:WaitForChild("Lobby")
local old = lobby:FindFirstChild("NameTag")
if old then
	local backups = ServerStorage:FindFirstChild("UiBackups")
		or new("Folder", { Name = "UiBackups" }, ServerStorage)
	local n = 1
	while backups:FindFirstChild("NameTag_" .. n) do
		n += 1
	end
	old.Name = "NameTag_" .. n
	old.Parent = backups
end

local gui: BillboardGui = new("BillboardGui", {
	Name = "NameTag",
	Size = UDim2.fromOffset(520, 140),
	StudsOffsetWorldSpace = Vector3.new(0, 2.9, 0), -- only for a body with no Head (from the HumanoidRootPart)
	SizeOffset = Vector2.new(0, 0.5), -- the bottom edge sits on that point at any distance
	MaxDistance = 50,
	LightInfluence = 0,
	AlwaysOnTop = true,
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Global,
	ClipsDescendants = false,
})
gui:SetAttribute("RefDistance", 14) -- studs where the tag is drawn at 1:1
gui:SetAttribute("MinScale", 0.55)
gui:SetAttribute("MaxScale", 1.6)
gui:SetAttribute("Falloff", 0.7) -- < 1: shrinks slower than the world, so far tags stay readable
gui:SetAttribute("PhoneBoost", 1.5) -- phones/tablets: size x screen height / 1080 x this (max 1)
gui:SetAttribute("TabletBoost", 1.2)
gui:SetAttribute("HeadGap", 0.5) -- the controller pins the tag this far over the top of the Head
gui:SetAttribute("DetailScale", 0.8) -- the @username hides below this size

local root: Frame = new("Frame", {
	Name = "Root",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.fromScale(0.5, 1),
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
}, gui)
new("UIScale", { Name = "Scale" }, root) -- scales about Root's bottom-centre anchor
new("UIListLayout", {
	FillDirection = Enum.FillDirection.Vertical,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Bottom,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, -4), -- tight stack, like one block of type
}, root)

label("Title", root, 1, UDim2.new(1, 0, 0, 22), Enum.FontWeight.Heavy, 20, GOLD, "SEASON 1")

local row: Frame = new("Frame", {
	Name = "Row",
	LayoutOrder = 2,
	Size = UDim2.new(1, 0, 0, 50),
	BackgroundTransparency = 1,
}, root)
new("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 6),
}, row)

local badge: ImageLabel = new("ImageLabel", {
	Name = "Level",
	LayoutOrder = 1,
	Size = UDim2.fromOffset(50, 44),
	BackgroundTransparency = 1,
	Image = BADGE,
	ImageColor3 = BADGE_TINT,
	ScaleType = Enum.ScaleType.Fit,
	ZIndex = 2,
}, row)
new("TextLabel", {
	Name = "Value",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	FontFace = Font.new(RUBIK, Enum.FontWeight.Heavy),
	TextSize = 22,
	TextColor3 = BADGE_INK,
	Text = "12",
	ZIndex = 3,
}, badge)

local name = label(
	"PlayerName",
	row,
	2,
	UDim2.fromOffset(0, 50),
	Enum.FontWeight.Heavy,
	44,
	INK,
	"PlayerName"
)
name.AutomaticSize = Enum.AutomaticSize.X

local streak: Frame = new("Frame", {
	Name = "Streak",
	LayoutOrder = 3,
	Size = UDim2.fromOffset(0, 50),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundTransparency = 1,
}, row)
new("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 1),
}, streak)
new("ImageLabel", {
	Name = "Icon",
	LayoutOrder = 1,
	Size = UDim2.fromOffset(34, 34),
	BackgroundTransparency = 1,
	Image = FLAME,
	ScaleType = Enum.ScaleType.Fit,
	ZIndex = 3,
}, streak)
local streakValue =
	label("Value", streak, 2, UDim2.fromOffset(0, 50), Enum.FontWeight.Heavy, 30, STREAK, "3")
streakValue.AutomaticSize = Enum.AutomaticSize.X

label("Username", root, 3, UDim2.new(1, 0, 0, 20), Enum.FontWeight.Bold, 17, MUTED, "@username")

gui.Parent = lobby
return "NameTag built"
