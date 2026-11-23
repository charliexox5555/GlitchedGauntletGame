--!strict
-- Studio build (Edit mode, Studio MCP or command bar): the lobby bar's "TO HUB" button (owner 2026-11-23), left
-- of PLAY, made from PLAY itself (same slanted plate, font and Pop) in the red the bar already uses. Hidden by
-- default; Util/LobbyHudView shows it only in a hosted server. Idempotent. Save the place afterwards.

local StarterPlayer = game:GetService("StarterPlayer")

local RED = Color3.fromHex("FF4D5E")
local GOLD = Color3.fromHex("FFC83D")
local WHITE = Color3.new(1, 1, 1)
local W, H = 210, 70 -- PLAY is 320 x 84
local GAP = 14 -- px between TO HUB and PLAY

local function near(a: Color3, b: Color3): boolean
	return math.abs(a.R - b.R) + math.abs(a.G - b.G) + math.abs(a.B - b.B) < 0.12
end

local ui = StarterPlayer.StarterPlayerScripts:FindFirstChild("UI")
local lobby = ui and ui:FindFirstChild("Lobby")
local bar = lobby and lobby:FindFirstChild("LobbyBar")
local bottom = bar and bar:FindFirstChild("Bottom")
local playFound = bottom and bottom:FindFirstChild("Play")
assert(bottom and playFound and playFound:IsA("GuiObject"), "LobbyBar.Bottom.Play missing")
local play = playFound :: GuiObject

local old = bottom:FindFirstChild("ToHub")
if old then
	old:Destroy()
end
local hub = play:Clone()
hub.Name = "ToHub"
hub.Visible = false
hub.Size = UDim2.fromOffset(W, H)
hub.Position = UDim2.fromOffset(
	play.Position.X.Offset - GAP - W,
	play.Position.Y.Offset + (play.Size.Y.Offset - H) / 2
)
for _, d in hub:GetDescendants() do
	if d:IsA("Frame") and near(d.BackgroundColor3, GOLD) then
		d.BackgroundColor3 = RED
	elseif d:IsA("ImageLabel") and near(d.ImageColor3, GOLD) then
		d.ImageColor3 = RED
	elseif d:IsA("TextLabel") then
		if d.Name == "Title" then
			d.Text = "TO HUB"
			d.TextSize = 30
			d.TextColor3 = WHITE
			d.Position = UDim2.fromOffset(W / 2, 8)
		elseif d.Name == "Sub" then
			d.Text = "PUBLIC SERVER"
			d.TextColor3 = WHITE
			d.Position = UDim2.fromOffset(W / 2, 46)
		end
	end
end
hub.Parent = bottom
return `ToHub at {hub.Position}, PLAY at {play.Position}`
