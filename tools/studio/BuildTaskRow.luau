--!strict
-- The task Path panel's row template (vault/01 Design/Tasks and Rewards.md), after the approved lobby HUD
-- mockup's DAILY TASKS block (vault/02 Art/UI Lobby HUD.md): the task's words and its count on the first line,
-- the coin reward on the right, a progress bar under it. Builds
-- StarterPlayer.StarterPlayerScripts.UI.Lobby.LobbyTasks.TopLeft.Tasks.Row (Visible = false); the client
-- (LobbyClient Controllers/TaskPanel) clones it per task. Run in Studio's command bar or the MCP; replaces an
-- older Row. Studio owns the result: edit it there, then copy the change back here.

local panel =
	game:GetService("StarterPlayer").StarterPlayerScripts.UI.Lobby.LobbyTasks.TopLeft.Tasks

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

local BX = "rbxassetid://12187365977" -- Rubik
local NAVY_HI = hex("39393C")
local ALLY, GOLD, WHITE, MUTED = hex("3FE0F2"), hex("FFC83D"), Color3.new(1, 1, 1), hex("97979A")
local COIN = "rbxassetid://122645025340088"

local old = panel:FindFirstChild("Row")
if old then
	old:Destroy()
end

local row = make("Frame", {
	Name = "Row",
	LayoutOrder = 10,
	Size = UDim2.fromOffset(400, 50),
	BackgroundTransparency = 1,
	Visible = false,
}, panel)
make("TextLabel", {
	Name = "Words",
	Position = UDim2.fromOffset(14, 8),
	Size = UDim2.fromOffset(250, 18),
	BackgroundTransparency = 1,
	Text = "SHATTER 10 AIR TARGETS AT THE RANGE",
	FontFace = Font.new(BX, Enum.FontWeight.Heavy),
	TextSize = 14,
	TextColor3 = WHITE,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
}, row)
make("TextLabel", {
	Name = "Count",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromOffset(318, 8),
	Size = UDim2.fromOffset(50, 18),
	BackgroundTransparency = 1,
	Text = "4 / 10",
	FontFace = Font.new(BX, Enum.FontWeight.Bold),
	TextSize = 13,
	TextColor3 = ALLY,
	TextXAlignment = Enum.TextXAlignment.Right,
}, row)
local bar = make("Frame", {
	Name = "Bar",
	Position = UDim2.fromOffset(14, 32),
	Size = UDim2.fromOffset(304, 6),
	BackgroundColor3 = NAVY_HI,
	BorderSizePixel = 0,
}, row)
make("Frame", {
	Name = "Fill",
	Size = UDim2.fromScale(0.4, 1),
	BackgroundColor3 = ALLY,
	BorderSizePixel = 0,
}, bar)
make("ImageLabel", {
	Name = "Coin",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.fromOffset(332, 25),
	Size = UDim2.fromOffset(22, 22),
	BackgroundTransparency = 1,
	Image = COIN,
}, row)
make("TextLabel", {
	Name = "Reward",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.fromOffset(358, 25),
	Size = UDim2.fromOffset(40, 18),
	BackgroundTransparency = 1,
	Text = "50",
	FontFace = Font.new(BX, Enum.FontWeight.Heavy),
	TextSize = 14,
	TextColor3 = GOLD,
	TextXAlignment = Enum.TextXAlignment.Left,
}, row)
-- the part bonus line under the rows: "FINISH ALL 3: +100"
local foot = panel:FindFirstChild("Bonus")
if foot then
	foot:Destroy()
end
make("TextLabel", {
	Name = "Bonus",
	LayoutOrder = 100,
	Size = UDim2.fromOffset(400, 18),
	BackgroundTransparency = 1,
	Text = "FINISH ALL 3  +100",
	FontFace = Font.new(BX, Enum.FontWeight.Bold),
	TextSize = 11,
	TextColor3 = MUTED,
	TextXAlignment = Enum.TextXAlignment.Left,
	Visible = false,
}, panel)
make("UIPadding", { PaddingLeft = UDim.new(0, 14) }, panel:FindFirstChild("Bonus"))
print("[BuildTaskRow] built", row:GetFullName())
