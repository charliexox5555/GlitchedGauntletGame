--!strict
-- Rebuilds the match notifications (vault/02 Art/UI Notifications.md) in the
-- match place. One long, smooth band under the top bar: dark in the middle,
-- fading out at both ends (no box, no edge strip, no glow, no pills; owner
-- 2026-11-14), the title in the tone colour and one small line under it.
-- Studio owns StarterGui.Notify; this is its backup in git. Paste into the
-- Studio command bar (Edit mode). It refuses to run if StarterGui.Notify exists.
-- Behaviour: src/client/Controllers/MatchHudController.luau.

local StarterGui = game:GetService("StarterGui")

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

local BX = "rbxassetid://12187365977" -- Rubik (UI Match Overhaul: was Builder Extended)
local WIDTH, HEIGHT = 980, 68

assert(not StarterGui:FindFirstChild("Notify"), "StarterGui.Notify already exists")

local gui = make("ScreenGui", {
	Name = "Notify",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
	IgnoreGuiInset = true,
	DisplayOrder = 10, -- above the top bar (9) and the draft (8)
})
local root = make("Frame", {
	Name = "Root",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.107), -- just under the top bar
	Size = UDim2.fromOffset(WIDTH, HEIGHT),
	BackgroundTransparency = 1,
}, gui)
make("UIScale", { Name = "Fit" }, root)
-- The band opens from its middle (the script animates Size.X) and fades.
local band = make("CanvasGroup", {
	Name = "Band",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0),
	Size = UDim2.fromOffset(WIDTH, HEIGHT),
	BackgroundColor3 = hex("09090C"),
	BackgroundTransparency = 0,
	BorderSizePixel = 0,
}, root)
make("UIGradient", {
	Name = "Fade",
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.22, 0.3),
		NumberSequenceKeypoint.new(0.78, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	}),
}, band)
for _, part in { "Shadow", "Title" } do
	make("TextLabel", {
		Name = part,
		Position = UDim2.fromOffset(0, if part == "Shadow" then 9 else 6),
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundTransparency = 1,
		Text = "MATCH POINT",
		FontFace = Font.new(BX, Enum.FontWeight.ExtraBold),
		TextSize = 30,
		TextColor3 = if part == "Shadow" then hex("000000") else hex("FFC83D"),
		TextTransparency = if part == "Shadow" then 0.55 else 0,
		ZIndex = if part == "Shadow" then 1 else 2,
	}, band)
end
make("TextLabel", {
	Name = "Sub",
	Position = UDim2.fromOffset(0, 43),
	Size = UDim2.new(1, 0, 0, 18),
	BackgroundTransparency = 1,
	RichText = true,
	Text = "ROUND 9  ·  You need one more round",
	FontFace = Font.new(BX, Enum.FontWeight.Bold),
	TextSize = 14,
	TextColor3 = hex("E6EAF0"),
	ZIndex = 2,
}, band)

gui.Parent = StarterGui
print("Notify built")
