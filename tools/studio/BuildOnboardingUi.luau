--!strict
-- Studio build (run once in Edit mode, via the Studio MCP or the command bar): the
-- onboarding UI pieces on the lobby bar (vault/05 Production/Handoff - Onboarding and
-- Bots.md → Phase 2). Idempotent: re-running replaces what it made.
--  * LobbyBar.Bottom.PlayBubble: "Join the queue to start playing!" over PLAY, a light
--    slanted plate with a pointer, made from the bar's own Callout (same shape and
--    font) recoloured: white plate, ink words (RIVALS' bubble, our plate). Hidden;
--    Util/LobbyHudView shows it, pops it in (its UIScale "Pop") and bobs it.
--  * LobbyBar.Bottom.Callout gets a UIScale "Pop" so the NEW pop scales in from its
--    centre.
-- The screens live in StarterPlayer.StarterPlayerScripts.UI.Lobby (Shared/UiRoot);
-- the old StarterGui spot is checked too. Save the place afterwards.

local StarterPlayer = game:GetService("StarterPlayer")
local StarterGui = game:GetService("StarterGui")

local WHITE = Color3.fromHex("F4F4F2")
local INK = Color3.fromHex("1A1A1D")
local RED = Color3.fromHex("FF4D5E")
local W, H = 430, 46 -- the bubble's plate (design px)
local GAP = 16 -- px between the bubble's pointer tip and PLAY's top

local function find(): Instance?
	local ui = StarterPlayer.StarterPlayerScripts:FindFirstChild("UI")
	local lobby = ui and ui:FindFirstChild("Lobby")
	local bar = (lobby and lobby:FindFirstChild("LobbyBar"))
		or StarterGui:FindFirstChild("LobbyBar")
	return bar
end

local function near(a: Color3, b: Color3): boolean
	return math.abs(a.R - b.R) + math.abs(a.G - b.G) + math.abs(a.B - b.B) < 0.06
end

local bar = find()
assert(bar, "LobbyBar not found (StarterPlayerScripts.UI.Lobby or StarterGui)")
local bottom = bar:FindFirstChild("Bottom")
assert(bottom, "LobbyBar.Bottom missing")
local calloutFound = bottom:FindFirstChild("Callout")
local playFound = bottom:FindFirstChild("Play")
assert(
	calloutFound and calloutFound:IsA("Frame") and playFound and playFound:IsA("GuiObject"),
	"Bottom.Callout / Bottom.Play missing"
)
local callout = calloutFound :: Frame
local play = playFound :: GuiObject

if not callout:FindFirstChild("Pop") then
	local pop = Instance.new("UIScale")
	pop.Name = "Pop"
	pop.Parent = callout
end

local old = bottom:FindFirstChild("PlayBubble")
if old then
	old:Destroy()
end
local bubble = callout:Clone()
bubble.Name = "PlayBubble"
bubble.Visible = false
bubble.AnchorPoint = Vector2.new(0.5, 1)
bubble.Size = UDim2.fromOffset(W, H)
bubble.Position =
	UDim2.fromOffset(play.Position.X.Offset + play.Size.X.Offset / 2, play.Position.Y.Offset - GAP)
bubble.ZIndex = 12
for _, d in bubble:GetDescendants() do
	if d:IsA("GuiObject") then
		d.ZIndex = math.max(d.ZIndex, 12) + (if d:IsA("TextLabel") then 2 else 0)
	end
	if d:IsA("Frame") and near(d.BackgroundColor3, RED) then
		d.BackgroundColor3 = WHITE
	elseif d:IsA("ImageLabel") and near(d.ImageColor3, RED) then
		d.ImageColor3 = WHITE
	elseif d:IsA("TextLabel") then
		d.TextColor3 = INK
		d.Text = "Join the queue to start playing!"
		d.TextSize = 18
		d.Size = UDim2.new(1, -24, 1, 0)
		d.AutomaticSize = Enum.AutomaticSize.None
		d.TextScaled = false
	end
end
if near(bubble.BackgroundColor3, RED) then
	bubble.BackgroundColor3 = WHITE
end
-- the pointer hangs from the plate's bottom middle, under the words
local pointer = bubble:FindFirstChild("Pointer")
if pointer and pointer:IsA("GuiObject") then
	pointer.ZIndex = bubble.ZIndex - 1
end
bubble.Parent = bottom
return `PlayBubble at {bubble.Position} over Play {play.Position}; Callout Pop ok`
