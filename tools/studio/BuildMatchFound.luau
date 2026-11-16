--!strict
-- Builds the lobby's MATCH FOUND overlay (vault/02 Art/UI Play and Party Menus.md
-- → Match found) in the LOBBY place, Edit mode: StarterGui.LobbyMatchFound (off;
-- Controllers/MatchFoundController opens it). Re-running replaces it.
--
-- Owner 2026-11-15: "more simple... you don't need to show who's in the
-- match... just a little overlay", like RIVALS: the screen dims and blurs and
-- three white dots pulse in the middle until the teleport. No teams, no names,
-- no title. (A loading screen in the match place comes next.)

local SG = game:GetService("StarterGui")

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

local CENTRE = Vector2.new(0.5, 0.5)
local DOT = 70 -- a dot's size at rest; the pulsing one grows ~1.45x
local STEP = 104 -- centre to centre

local old = SG:FindFirstChild("LobbyMatchFound")
if old then
	old:Destroy()
end
local gui = make("ScreenGui", {
	Name = "LobbyMatchFound",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ScreenInsets = Enum.ScreenInsets.None,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 40, -- over the whole HUD
	Enabled = false,
})
make("Frame", {
	Name = "Scrim",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromHex("08080B"),
	BackgroundTransparency = 0.2,
	BorderSizePixel = 0,
	Active = true, -- swallows clicks while it's up
	ZIndex = 0,
}, gui)
local center = make("Frame", {
	Name = "Center",
	AnchorPoint = CENTRE,
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(3 * STEP, 160),
	BackgroundTransparency = 1,
	ZIndex = 1,
}, gui)
make("UIScale", { Name = "Fit" }, center)
local dots = make("Frame", {
	Name = "Dots",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	ZIndex = 1,
}, center)
-- each dot: a fixed holder with the circle centred in it, so it grows from
-- its centre without pushing its neighbours
for i = 1, 3 do
	local holder = make("Frame", {
		Name = "Dot" .. i,
		AnchorPoint = CENTRE,
		Position = UDim2.new(0.5, (i - 2) * STEP, 0.5, 0),
		Size = UDim2.fromOffset(STEP, STEP),
		BackgroundTransparency = 1,
		ZIndex = 1,
	}, dots)
	local circle = make("Frame", {
		Name = "Circle",
		AnchorPoint = CENTRE,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(DOT, DOT),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 2,
	}, holder)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, circle)
	make("UIScale", { Name = "Pop" }, circle)
end
-- Studio only: the teleport is skipped there, so say so quietly
make("TextLabel", {
	Name = "Studio",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 1, 10),
	Size = UDim2.fromOffset(600, 22),
	BackgroundTransparency = 1,
	Text = "STUDIO  ·  TELEPORT SKIPPED",
	FontFace = Font.new("rbxassetid://12187365977", Enum.FontWeight.Bold),
	TextSize = 15,
	TextColor3 = Color3.new(1, 1, 1),
	TextTransparency = 0.5,
	Visible = false,
	ZIndex = 3,
}, center)

gui.Parent = SG
print("[BuildMatchFound] StarterGui.LobbyMatchFound built")
