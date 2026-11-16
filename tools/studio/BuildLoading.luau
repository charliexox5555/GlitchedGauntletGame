--!strict
-- Builds the teleport / loading screen in the LOBBY place, Edit mode:
-- StarterGui.LobbyLoading (off). Re-running replaces it.
-- (vault/02 Art/UI Lobby Overhaul.md → Play / queue / party.)
--
-- MATCH FOUND (Controllers/MatchFoundController) fills in the mode and a tip,
-- then hands a copy to TeleportService:SetTeleportGui, so Roblox shows it
-- during the teleport; the match place's ReplicatedFirst script
-- (src/first/LoadingScreen.client.luau) keeps it up, pulses the dots and
-- fades it out once the match has loaded. No logo yet (owner, 2026-11-15:
-- "I don't have the game name, or logo yet"): the mode is the hero word.
-- Same look as MATCH FOUND: the violet wash, three white dots, Fredoka One.

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

local function hex(h: string): Color3
	return Color3.fromHex(h)
end

local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json")
local CENTRE = Vector2.new(0.5, 0.5)
local DOT = 34
local STEP = 54
local WHITE = Color3.new(1, 1, 1)

local old = SG:FindFirstChild("LobbyLoading")
if old then
	old:Destroy()
end
local gui = make("ScreenGui", {
	Name = "LobbyLoading",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ScreenInsets = Enum.ScreenInsets.None,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 50,
	Enabled = false,
})
local wash = make("Frame", {
	Name = "Wash",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = WHITE,
	BorderSizePixel = 0,
	Active = true,
	ZIndex = 0,
}, gui)
make("UIGradient", {
	Rotation = 35,
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, hex("3B1D63")),
		ColorSequenceKeypoint.new(0.55, hex("161A44")),
		ColorSequenceKeypoint.new(1, hex("0A1230")),
	}),
}, wash)

-- the queued mode's art (the Play menu tile's, set by MatchFoundController),
-- faint over the wash, darkening to the bottom where the tip sits
local art = make("ImageLabel", {
	Name = "Art",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	ScaleType = Enum.ScaleType.Crop,
	ImageTransparency = 0.78,
	ZIndex = 1,
}, gui)
make("UIGradient", {
	Rotation = 90,
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.6, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	}),
}, art)

local center = make("Frame", {
	Name = "Center",
	AnchorPoint = CENTRE,
	Position = UDim2.fromScale(0.5, 0.46),
	Size = UDim2.fromOffset(900, 300),
	BackgroundTransparency = 1,
	ZIndex = 2,
}, gui)
make("UIScale", { Name = "Fit" }, center)
make("UIAspectRatioConstraint", { AspectRatio = 3 }, center)
make("TextLabel", {
	Name = "Mode",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0),
	Size = UDim2.new(1, 0, 0, 110),
	BackgroundTransparency = 1,
	Text = "1V1",
	FontFace = FONT,
	TextSize = 104,
	TextColor3 = WHITE,
	ZIndex = 3,
}, center)
make("TextLabel", {
	Name = "Label",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 118),
	Size = UDim2.new(1, 0, 0, 34),
	BackgroundTransparency = 1,
	Text = "LOADING MATCH",
	FontFace = FONT,
	TextSize = 30,
	TextColor3 = hex("8FA0C8"),
	ZIndex = 3,
}, center)
local dots = make("Frame", {
	Name = "Dots",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 186),
	Size = UDim2.fromOffset(3 * STEP, STEP),
	BackgroundTransparency = 1,
	ZIndex = 3,
}, center)
-- fixed holders with centred circles, so a pulsing dot grows from its centre
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
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, holder)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, circle)
	make("UIScale", { Name = "Pop" }, circle)
end

-- a tip along the bottom, inside the safe area
make("TextLabel", {
	Name = "Tip",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -56),
	Size = UDim2.new(0.8, 0, 0, 30),
	BackgroundTransparency = 1,
	Text = "TIP  ·  DRAFT A NEW MOD EVERY ROUND",
	FontFace = FONT,
	TextSize = 22,
	TextColor3 = WHITE,
	TextTransparency = 0.25,
	ZIndex = 3,
}, gui)

gui.Parent = SG
print("[BuildLoading] StarterGui.LobbyLoading built")
