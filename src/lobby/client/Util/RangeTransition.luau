--!strict
-- The cut between the lobby and the range (owner 2026-11-26: "there should be a transition, meaning like the loading
-- screen between going through the places"). A full-screen card (dark, the range's teal accent, the place you're
-- going to in big type, a running bar) fades in the moment a trip starts (the hub gate, the range's LEAVE screen, the
-- lobby bar's RANGE button, the Leave button or key), holds while the server moves you and your new character
-- lands, then fades out. If the trip never happens (the server's cooldown said no), it lets go after a moment.
-- Client only; nothing here moves the player.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local LobbyNet = require(ReplicatedStorage.Lobby.LobbyNet)
local PlayZone = require(ReplicatedStorage.Shared.PlayZone)

local RangeTransition = {}

local player = Players.LocalPlayer
local TEAL = Color3.fromHex("2BD9A8")
local INK = Color3.fromRGB(13, 15, 19)
local RUBIK_H = Font.new("rbxassetid://12187365977", Enum.FontWeight.Heavy)
local RUBIK_B = Font.new("rbxassetid://12187365977", Enum.FontWeight.Bold)
local FADE_IN, FADE_OUT = 0.22, 0.4
local SETTLE = 0.8 -- s after the new character arrives before the card lifts (streaming, placement)
local MIN_HOLD = 1.2 -- s fully up at least, so it never flashes
local GIVE_UP = 2.5 -- s with no zone change: the trip didn't happen
local MAX_HOLD = 9 -- s: never hold longer than this

type Card = {
	gui: ScreenGui,
	cover: CanvasGroup,
	title: TextLabel,
	sub: TextLabel,
	fill: Frame,
}

local card: Card? = nil
local token = 0
local showing = false
local shownAt = 0

local function build(): Card
	local gui = Instance.new("ScreenGui")
	gui.Name = "RangeTransition"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = Enum.ScreenInsets.None
	gui.DisplayOrder = 95
	gui.Enabled = false
	gui:SetAttribute("KeepGui", true) -- survives the match client's cleanup between zones (client/init)
	local cover = Instance.new("CanvasGroup")
	cover.Name = "Cover"
	cover.Size = UDim2.fromScale(1, 1)
	cover.BackgroundColor3 = INK
	cover.BorderSizePixel = 0
	cover.GroupTransparency = 1
	cover.Active = true -- nothing under it takes input while it's up
	cover.Parent = gui
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 160, 170))
	grad.Parent = cover
	local mid = Instance.new("Frame")
	mid.Name = "Mid"
	mid.BackgroundTransparency = 1
	mid.AnchorPoint = Vector2.new(0.5, 0.5)
	mid.Position = UDim2.fromScale(0.5, 0.5)
	mid.Size = UDim2.fromScale(0.8, 0.3)
	mid.Parent = cover
	local bar = Instance.new("Frame")
	bar.Name = "Accent"
	bar.BackgroundColor3 = TEAL
	bar.BorderSizePixel = 0
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.fromScale(0.5, 0)
	bar.Size = UDim2.new(0.09, 0, 0.04, 0)
	bar.Parent = mid
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.AnchorPoint = Vector2.new(0.5, 0)
	title.Position = UDim2.fromScale(0.5, 0.14)
	title.Size = UDim2.fromScale(1, 0.46)
	title.FontFace = RUBIK_H
	title.TextScaled = true
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Text = ""
	title.Parent = mid
	local sub = Instance.new("TextLabel")
	sub.Name = "Sub"
	sub.BackgroundTransparency = 1
	sub.AnchorPoint = Vector2.new(0.5, 0)
	sub.Position = UDim2.fromScale(0.5, 0.64)
	sub.Size = UDim2.fromScale(1, 0.13)
	sub.FontFace = RUBIK_B
	sub.TextScaled = true
	sub.TextColor3 = TEAL
	sub.Text = ""
	sub.Parent = mid
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.BackgroundColor3 = Color3.fromRGB(40, 44, 52)
	track.BorderSizePixel = 0
	track.AnchorPoint = Vector2.new(0.5, 0)
	track.Position = UDim2.fromScale(0.5, 0.88)
	track.Size = UDim2.new(0.3, 0, 0.025, 0)
	track.ClipsDescendants = true
	track.Parent = mid
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = TEAL
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	fill.Parent = track
	gui.Parent = player:WaitForChild("PlayerGui")
	return { gui = gui, cover = cover, title = title, sub = sub, fill = fill }
end

local function hide(mine: number)
	local c = card
	if not c or mine ~= token or not showing then
		return
	end
	local early = shownAt + MIN_HOLD - os.clock()
	if early > 0 then
		task.wait(early)
		if mine ~= token or not showing then
			return
		end
	end
	showing = false
	TweenService:Create(c.fill, TweenInfo.new(0.15), { Size = UDim2.fromScale(1, 1) }):Play()
	local t = TweenService:Create(
		c.cover,
		TweenInfo.new(FADE_OUT, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ GroupTransparency = 1 }
	)
	t:Play()
	t.Completed:Once(function()
		if mine == token and not showing then
			c.gui.Enabled = false
		end
	end)
end

-- Starts the card for a trip to `dest` ("Range" or "Lobby"). Safe to call twice (the gate and the server's
-- zone change both call it).
function RangeTransition.show(dest: string)
	local c = card or build()
	card = c
	if showing then
		return
	end
	showing = true
	shownAt = os.clock()
	token += 1
	local mine = token
	c.title.Text = if dest == "Range" then "SHOOTING RANGE" else "LOBBY"
	c.sub.Text = if dest == "Range" then "EVERY GUN  ·  TARGETS  ·  BOTS" else "BACK TO THE DEEP"
	c.fill.Size = UDim2.fromScale(0, 1)
	c.gui.Enabled = true
	TweenService:Create(
		c.cover,
		TweenInfo.new(FADE_IN, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ GroupTransparency = 0 }
	):Play()
	TweenService:Create(
		c.fill,
		TweenInfo.new(2.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{ Size = UDim2.fromScale(0.85, 1) }
	):Play()
	local startZone = PlayZone.get(player)
	-- the trip didn't happen: let go
	task.delay(GIVE_UP, function()
		if mine == token and showing and PlayZone.get(player) == startZone then
			hide(mine)
		end
	end)
	task.delay(MAX_HOLD, function()
		hide(mine)
	end)
end

-- Asks the server for the trip (the lobby bar's RANGE button, the Leave button and key) and covers it.
function RangeTransition.travel()
	local zone = PlayZone.get(player)
	if zone ~= "Lobby" and zone ~= "Range" then
		return
	end
	RangeTransition.show(if zone == "Lobby" then "Range" else "Lobby")
	LobbyNet.event("RangeTravel"):FireServer()
end

-- The zone changed between the lobby and the range: hold the card until the new character has landed.
local function onZone(zone: string)
	if zone ~= "Range" and zone ~= "Lobby" then
		return
	end
	if not showing then
		-- a trip we didn't see start (e.g. a server-side move): still cover the respawn
		RangeTransition.show(zone)
	end
	local mine = token
	local arrived: RBXScriptConnection? = nil
	arrived = player.CharacterAdded:Connect(function(character)
		if arrived then
			arrived:Disconnect()
		end
		character:WaitForChild("HumanoidRootPart", 5)
		task.wait(SETTLE)
		hide(mine)
	end)
	task.delay(MAX_HOLD, function()
		if arrived then
			arrived:Disconnect()
		end
	end)
end

local started = false
local lastZone: string? = nil
local lastTouch = 0

-- Walking into the hub gate (RangeEntry) or the range's LEAVE screen (RangeExit): the server makes the trip off its
-- own Touched; this only puts the card up at the same moment instead of a beat later.
local hooked: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local function hookGate(part: Instance, entering: boolean)
	if not part:IsA("BasePart") or hooked[part] then
		return
	end
	hooked[part] = true
	part.Touched:Connect(function(hit: BasePart)
		local character = player.Character
		if not character or not hit:IsDescendantOf(character) or showing then
			return
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			return
		end
		local now = os.clock()
		if now - lastTouch < 2 then
			return
		end
		local zone = PlayZone.get(player)
		if (entering and zone == "Lobby") or (not entering and zone == "Range") then
			lastTouch = now
			RangeTransition.show(if entering then "Range" else "Lobby")
		end
	end)
end

function RangeTransition.start()
	if started then
		return
	end
	started = true
	lastZone = PlayZone.get(player)
	PlayZone.onLocalChanged(function(zone)
		local was = lastZone
		lastZone = zone
		if (was == "Lobby" and zone == "Range") or (was == "Range" and zone == "Lobby") then
			onZone(zone)
		end
	end)
	for tag, entering in { RangeEntry = true, RangeExit = false } do
		for _, part in CollectionService:GetTagged(tag) do
			hookGate(part, entering)
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(function(part)
			hookGate(part, entering)
		end)
	end
end

return RangeTransition
