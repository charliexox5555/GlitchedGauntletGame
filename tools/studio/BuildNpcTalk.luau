--!strict
-- Builds StarterGui.NpcTalk, the lobby NPC talk screen (owner 2026-11-16: "very similar to RIVALS ... they go into
-- this separate HUD"). Run in the Lobby place (Edit) from the command bar or Studio MCP; it replaces any old copy.
-- The owner edits the result in Studio; the controller (src/lobby/client/Controllers/NpcTalk.luau) fills it in.
-- After RIVALS' DialogPage, in our kit (vault/02 Art/Lobby V4 Build.md → Locker as a weapons room): the world
-- blurred behind a dark violet wash; the NPC's live 3D portrait at the bottom left, fading out at the waist; an
-- off-white slanted speech plate beside him with big ink words and a pointer at him, his name on a violet tab;
-- reply bubbles (slanted plates) stacked above its right end, GOODBYE in red.
-- Design canvas 1920 x 1080, centre-anchored (LobbyKit.page fits it to the screen).

local StarterGui = game:GetService("StarterGui")

local HEAVY = Font.new("rbxassetid://12187365977", Enum.FontWeight.Heavy)
local INK = Color3.fromHex("0F0F12")
local PAPER = Color3.fromHex("FFFDFE")
local VIOLET = Color3.fromHex("6539D7")
local CAP = "rbxassetid://75584308608588" -- the slant cap art the lobby builders use (Plates.finish replaces it)

local function new(class: string, props: { [string]: any }, parent: Instance?): any
	local i = Instance.new(class)
	for k, v in props do
		(i :: any)[k] = v
	end
	if parent then
		i.Parent = parent
	end
	return i
end

local function caps(body: GuiObject, w: number)
	for _, side in { "CapL", "CapR" } do
		new("ImageLabel", {
			Name = side,
			BackgroundTransparency = 1,
			Image = CAP,
			ImageColor3 = body.BackgroundColor3,
			Size = UDim2.new(0, w, 1, 0),
			Position = if side == "CapL" then UDim2.new(0, -w, 0, 0) else UDim2.new(1, 0, 0, 0),
			ZIndex = body.ZIndex,
		}, body)
	end
end

local old = StarterGui:FindFirstChild("NpcTalk")
if old then
	old:Destroy()
end

local gui = new("ScreenGui", {
	Name = "NpcTalk",
	Enabled = false,
	IgnoreGuiInset = true,
	ResetOnSpawn = false,
	DisplayOrder = 20,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})

local wash = new("Frame", {
	Name = "Wash",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BackgroundTransparency = 0.25,
	BorderSizePixel = 0,
}, gui)
new("UIGradient", {
	Rotation = 90,
	Color = ColorSequence.new(Color3.fromHex("0E0C16"), Color3.fromHex("231446")),
}, wash)

local canvas = new("Frame", {
	Name = "Canvas",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(1920, 1080),
	BackgroundTransparency = 1,
}, gui)
new("UIScale", { Name = "Fit" }, canvas)

-- the NPC's live portrait (the controller clones him in and plays his idle)
new("ViewportFrame", {
	Name = "Portrait",
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 110, 1, 40),
	Size = UDim2.fromOffset(780, 720),
	BackgroundTransparency = 1,
	Ambient = Color3.fromRGB(150, 140, 175),
	LightColor = Color3.fromRGB(255, 248, 240),
	LightDirection = Vector3.new(-0.6, -1, -0.8),
	ZIndex = 2,
}, canvas)
local pfade = new("Frame", {
	Name = "PortraitFade",
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, -400, 1, 0), -- the full width (and past it) so no side edges show
	Size = UDim2.fromOffset(2720, 300),
	BackgroundColor3 = Color3.fromHex("0E0C16"),
	BorderSizePixel = 0,
	ZIndex = 3,
}, canvas)
new("UIGradient", {
	Rotation = -90,
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(0.55, 0.6),
		NumberSequenceKeypoint.new(1, 1),
	}),
}, pfade)

local speech = new("Frame", {
	Name = "Speech",
	Position = UDim2.fromOffset(640, 700),
	Size = UDim2.fromOffset(860, 172),
	BackgroundColor3 = PAPER,
	BorderSizePixel = 0,
	ZIndex = 5,
}, canvas)
caps(speech, 30)
new("Frame", {
	Name = "Pointer", -- a turned square tucked under the plate's left end: the point toward him
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromOffset(622, 748),
	Size = UDim2.fromOffset(40, 40),
	Rotation = 45,
	BackgroundColor3 = PAPER,
	BorderSizePixel = 0,
	ZIndex = 4,
}, canvas)
new("TextLabel", {
	Name = "Message",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(44, 16),
	Size = UDim2.new(1, -88, 1, -32),
	FontFace = HEAVY,
	TextSize = 44,
	TextColor3 = INK,
	TextWrapped = true,
	LineHeight = 1.05,
	Text = "Back again? Every gun in here is wearing the skin you picked.",
	ZIndex = 7,
}, speech)
new("TextButton", {
	Name = "Skip", -- click the plate to finish the line at once
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	Text = "",
	ZIndex = 8,
}, speech)

local name = new("Frame", {
	Name = "Name",
	Position = UDim2.fromOffset(676, 648),
	Size = UDim2.fromOffset(230, 48),
	BackgroundColor3 = VIOLET,
	BorderSizePixel = 0,
	ZIndex = 6,
}, canvas)
caps(name, 18)
new("TextLabel", {
	Name = "Title",
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	FontFace = HEAVY,
	TextSize = 28,
	TextColor3 = Color3.new(1, 1, 1),
	Text = "ARMORER",
	ZIndex = 7,
}, name)

local replies = new("Frame", {
	Name = "Replies",
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.fromOffset(1530, 628),
	Size = UDim2.fromOffset(700, 300),
	BackgroundTransparency = 1,
}, canvas)
new("UIListLayout", {
	FillDirection = Enum.FillDirection.Vertical,
	HorizontalAlignment = Enum.HorizontalAlignment.Right,
	VerticalAlignment = Enum.VerticalAlignment.Bottom,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 14),
}, replies)

local reply = new("TextButton", {
	Name = "ReplyTemplate",
	Visible = false,
	AutoButtonColor = false,
	Size = UDim2.fromOffset(320, 56),
	BackgroundColor3 = VIOLET,
	BorderSizePixel = 0,
	Text = "",
	ZIndex = 5,
}, canvas)
caps(reply, 20)
new("TextLabel", {
	Name = "Label",
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	FontFace = HEAVY,
	TextSize = 30,
	TextColor3 = Color3.new(1, 1, 1),
	Text = "Open my Locker",
	ZIndex = 6,
}, reply)

gui.Parent = StarterGui
return "NpcTalk built"
