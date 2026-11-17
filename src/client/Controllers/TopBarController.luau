--!strict
-- The match top bar, v2.2 (vault/02 Art/UI Top Bar Draft.md). The layout is
-- built in Studio: StarterGui.TopBar.Root → Shadow + Bar → AllyTeam / Centre /
-- EnemyTeam. A team = Body (Players, Score) + a Slant cap; Centre holds the
-- Timer (Clock → Icon, Time; Info). The player cell template is
-- ReplicatedStorage.UiTemplates.TopBar.Player (a CanvasGroup with a Headshot).
-- Colours live on the instances (Body colour + Shade gradient, Body's
-- "CellColor" attribute), so they can be tuned in Studio.
-- This script only fills it in: one cell per fighter (greyed out when dead),
-- the round score, the clock and the info line, from MatchState; the server
-- decides all of it.
-- Motion: the bar drops in, cells pop in, a death dips and greys, a point
-- bumps the team block, flashes it bright and pops the number, the last
-- seconds pulse the timer.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local Config = require(ReplicatedStorage.Shared.Config.Match)
local Health = require(ReplicatedStorage.Shared.Health)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Teams = require(ReplicatedStorage.Shared.Mods.Teams)
local TestMode = require(ReplicatedStorage.Shared.TestMode)

local PlayerTags = require(script.Parent.Parent.Util.PlayerTags)
local UiSound = require(script.Parent.Parent.Util.UiSound)
local UiMotion = require(game:GetService("ReplicatedStorage").Shared.UiMotion) -- the one motion module (lobby + match)
local WaitGui = require(script.Parent.Parent.Util.WaitGui)

local TopBarController = {}

local player = Players.LocalPlayer

local TICK = 0.1 -- seconds between refreshes
local DESIGN = Vector2.new(1920, 1080) -- the Studio layout is authored at this size
local URGENT_LIVE = 10 -- the clock turns red this many seconds from the end
local TICK_FROM: { [string]: number } = { Draft = 5, Countdown = 3, Live = 5 } -- the clock ticks (sound) from here
local BOT_HEADSHOT = "rbxassetid://119185654291939" -- helmet stand-in for bots and test players
local SHADOW_PAD = Vector2.new(56, 48) -- the soft shadow reaches this far past the bar
local VOTE_ORDER = 41 -- over the map vote screen (StarterGui.MapVote is 40)

local WHITE = Color3.new(1, 1, 1)
local DANGER = Color3.fromHex("FF4D5E")
local DEAD_TINT = Color3.fromRGB(120, 124, 132) -- greyed-out headshot
local DEAD_FADE = 0.35 -- headshot fade inside a dead cell
local CELL_DEAD = Color3.fromHex("3F3F42")
local CELL_FADE = 0.1

type Fighter = { key: Instance, userId: number?, humanoid: Humanoid? }
-- holder: a fixed-size item in the row; cell: centred inside it, so its pop
-- scales from the middle without moving the neighbours.
type Slot = { holder: Frame, cell: CanvasGroup, head: ImageLabel, pop: UIScale, alive: boolean? }
type Side = {
	block: Frame,
	blockPop: UIScale,
	body: Frame,
	slant: ImageLabel,
	players: Frame,
	value: TextLabel,
	valueShadow: TextLabel,
	pop: UIScale,
	color: Color3,
	cellColor: Color3,
	shown: number,
}

local tween = UiMotion.tween

local function clockText(seconds: number): string
	if MatchState.phase() == "Vote" and seconds < 10 then
		return string.format("%.1f", math.max(seconds, 0)) -- the vote: tenths, like RIVALS
	end
	local whole = math.max(math.ceil(seconds), 0)
	return string.format("%d:%02d", math.floor(whole / 60), whole % 60)
end

local function tierName(round: number): string
	local found = Config.PHASES[1]
	for _, p in Config.PHASES do
		if round >= p.fromRound then
			found = p
		end
	end
	return string.upper(found.name)
end

local function myTeam(): number
	return Teams.of(player) or 1
end

-- Everyone on a team, in a stable order: you first, then players by UserId,
-- then bots (Workspace.Dummies models with a TeamId) by name.
local function roster(team: number): { Fighter }
	local list: { Fighter } = {}
	local people: { Player } = {}
	for _, p in Players:GetPlayers() do
		if Teams.of(p) == team then
			table.insert(people, p)
		end
	end
	table.sort(people, function(a, b)
		if a == player then
			return true
		elseif b == player then
			return false
		end
		return a.UserId < b.UserId
	end)
	for _, p in people do
		local humanoid = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
		table.insert(list, { key = p, userId = p.UserId, humanoid = humanoid })
	end
	local dummies = workspace:FindFirstChild("Dummies")
	if dummies then
		local bots: { Model } = {}
		for _, model in dummies:GetChildren() do
			if model:IsA("Model") and model:GetAttribute("TeamId") == team then
				table.insert(bots, model)
			end
		end
		table.sort(bots, function(a, b)
			return a.Name < b.Name
		end)
		for _, model in bots do
			table.insert(
				list,
				{ key = model, userId = nil, humanoid = model:FindFirstChildOfClass("Humanoid") }
			)
		end
	end
	return list
end

local function headshot(userId: number?): string
	if userId and userId > 0 then
		return string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", userId)
	end
	return BOT_HEADSHOT
end

-- The bar's screen. The map vote shows the bar before anyone spawns (and
-- StarterGui only copies on a spawn), so take our own copy now and drop the
-- one Roblox adds at the first spawn (like MapVoteController).
local function ownCopy(): ScreenGui
	local playerGui = player:WaitForChild("PlayerGui")
	local source = StarterGui:FindFirstChild("TopBar")
	if not (source and source:IsA("ScreenGui")) then
		return WaitGui("TopBar") :: ScreenGui
	end
	local mine = playerGui:FindFirstChild("TopBar") :: ScreenGui?
	if not mine then
		local copy = source:Clone()
		copy.ResetOnSpawn = false
		copy.Parent = playerGui
		mine = copy
	end
	local kept = mine :: ScreenGui
	playerGui.ChildAdded:Connect(function(c)
		if c ~= kept and c.Name == "TopBar" and c:IsA("ScreenGui") then
			task.defer(c.Destroy, c)
		end
	end)
	return kept
end

function TopBarController.start()
	local gui = ownCopy()
	local baseOrder = gui.DisplayOrder
	local root = gui:WaitForChild("Root") :: Frame
	local fit = root:WaitForChild("Fit") :: UIScale
	local shadow = root:WaitForChild("Shadow") :: ImageLabel
	local bar = root:WaitForChild("Bar") :: Frame
	local timer = (bar:WaitForChild("Centre") :: Frame):WaitForChild("Timer") :: Frame
	local clock = timer:WaitForChild("Clock") :: Frame
	local timeLabel = clock:WaitForChild("Time") :: TextLabel
	local icon = clock:WaitForChild("Icon") :: ImageLabel
	local infoLabel = timer:WaitForChild("Info") :: TextLabel
	local timerEdge = timer:WaitForChild("Edge") :: UIStroke
	local timerPop = timer:WaitForChild("Pop") :: UIScale
	local template = ReplicatedStorage:WaitForChild("UiTemplates")
		:WaitForChild("TopBar")
		:WaitForChild("Player") :: Frame

	local function side(name: string): Side
		local block = bar:WaitForChild(name) :: Frame
		local body = block:WaitForChild("Body") :: Frame
		-- The number and its shadow sit in a centred Inner frame (its pop scales
		-- from the middle; the Score item keeps its size in the row).
		local score = (body:WaitForChild("Score") :: Frame):WaitForChild("Inner") :: Frame
		local players = body:WaitForChild("Players") :: Frame
		-- The Studio preview cells only show the layout in Edit mode.
		for _, child in players:GetChildren() do
			if child:GetAttribute("Preview") then
				child:Destroy()
			end
		end
		local cellColor = body:GetAttribute("CellColor")
		return {
			block = block,
			blockPop = block:WaitForChild("Pop") :: UIScale,
			body = body,
			slant = block:WaitForChild("Slant") :: ImageLabel,
			players = players,
			value = score:WaitForChild("Value") :: TextLabel,
			valueShadow = score:WaitForChild("Shadow") :: TextLabel,
			pop = score:WaitForChild("Pop") :: UIScale,
			color = body.BackgroundColor3,
			cellColor = if typeof(cellColor) == "Color3" then cellColor else Color3.new(0, 0, 0),
			shown = -1,
		}
	end
	local sides: { [string]: Side } = { ally = side("AllyTeam"), enemy = side("EnemyTeam") }

	-- One UIScale keeps the 1920 x 1080 layout proportional on other screens.
	local function refit()
		local size = gui.AbsoluteSize
		if size.X > 0 and size.Y > 0 then
			fit.Scale = math.clamp(math.min(size.X / DESIGN.X, size.Y / DESIGN.Y), 0.6, 1.5)
		end
	end
	refit()
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)

	-- The soft shadow follows the bar's width (the bar grows with the team sizes).
	local function fitShadow()
		local width = bar.AbsoluteSize.X / math.max(fit.Scale, 0.01)
		shadow.Size = UDim2.fromOffset(width + SHADOW_PAD.X, bar.Size.Y.Offset + SHADOW_PAD.Y)
	end
	bar:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitShadow)
	fitShadow()

	local slots: { [string]: { [Instance]: Slot } } = { ally = {}, enemy = {} }

	local function newSlot(key: string, f: Fighter): Slot
		local holder = template:Clone()
		local cell = holder:WaitForChild("Cell") :: CanvasGroup
		cell.BackgroundColor3 = sides[key].cellColor
		local head = cell:WaitForChild("Headshot") :: ImageLabel
		head.Image = headshot(f.userId)
		local pop = cell:WaitForChild("Pop") :: UIScale
		pop.Scale = 0.5
		-- level on the tile's foot, device in its corner (vault/02 Art/UI Match
		-- Overhaul.md); bots get a BOT chip
		local who = if f.key:IsA("Player") then f.key :: Player else nil
		local z = cell.ZIndex + 5
		local lv = PlayerTags.level(holder, who, 11, z)
		lv.AnchorPoint = Vector2.new(0.5, 0.5)
		lv.Position = UDim2.new(0.5, 0, 1, -1)
		local dev = PlayerTags.device(holder, who, 14, z)
		dev.AnchorPoint = Vector2.new(1, 0)
		dev.Position = UDim2.new(1, -4, 0, 4)
		holder.Parent = sides[key].players
		tween(pop, 0.36, { Scale = 1 })
		return { holder = holder, cell = cell, head = head, pop = pop, alive = nil }
	end

	local function setAlive(key: string, slot: Slot, alive: boolean)
		if slot.alive == alive then
			return
		end
		local first = slot.alive == nil
		slot.alive = alive
		local time = if first then 0 else 0.3
		-- Greyed out: the cell turns slate and the headshot fades grey into it.
		tween(slot.cell, time, {
			BackgroundColor3 = if alive then sides[key].cellColor else CELL_DEAD,
			BackgroundTransparency = if alive then CELL_FADE else 0,
		})
		tween(slot.head, time, {
			ImageColor3 = if alive then WHITE else DEAD_TINT,
			ImageTransparency = if alive then 0 else DEAD_FADE,
		})
		if not first then
			-- A dip on a death, a lift on a respawn.
			slot.pop.Scale = if alive then 1.15 else 0.85
			tween(slot.pop, 0.32, { Scale = 1 })
		end
	end

	local function syncSide(key: string, team: number)
		local seen: { [Instance]: boolean } = {}
		for i, f in roster(team) do
			seen[f.key] = true
			local slot = slots[key][f.key]
			if not slot then
				slot = newSlot(key, f)
				slots[key][f.key] = slot
			end
			-- Player 1 sits next to the score, closest to the timer.
			slot.holder.LayoutOrder = if key == "ally" then -i else i
			local h = f.humanoid
			-- Before anyone spawns (the map vote) nobody is greyed out.
			local waiting = MatchState.phase() == "Vote"
			setAlive(key, slot, waiting or (h ~= nil and h.Parent ~= nil and Health.isAlive(h)))
		end
		for k, slot in slots[key] do
			if not seen[k] then
				slot.holder:Destroy()
				slots[key][k] = nil
			end
		end
	end

	local function setScore(s: Side, value: number)
		local text = tostring(value)
		s.value.Text = text
		s.valueShadow.Text = text
		if s.shown >= 0 and value > s.shown then
			-- A point: the block bumps and flashes bright, the number pops.
			UiSound.play("Score")
			s.pop.Scale = 1.35
			tween(s.pop, 0.42, { Scale = 1 })
			local flash = s.color:Lerp(WHITE, 0.55)
			s.body.BackgroundColor3 = flash
			s.slant.ImageColor3 = flash
			tween(s.body, 0.5, { BackgroundColor3 = s.color })
			tween(s.slant, 0.5, { ImageColor3 = s.color })
		end
		s.shown = value
	end

	local lastSecond = -1
	local lastTick = -1
	local function refresh()
		local phase = MatchState.phase()
		root.Visible = phase ~= nil and phase ~= "Waiting" and not TestMode.isOn()
		-- Over the map vote's screen (it covers every other HUD).
		gui.DisplayOrder = if phase == "Vote" then VOTE_ORDER else baseOrder
		if not root.Visible then
			return
		end
		local mine = myTeam()
		local theirs = if mine == 1 then 2 else 1
		syncSide("ally", mine)
		syncSide("enemy", theirs)

		local scoreOne = MatchState.get("Score1") or 0
		local scoreTwo = MatchState.get("Score2") or 0
		local myScore = if mine == 1 then scoreOne else scoreTwo
		local theirScore = if mine == 1 then scoreTwo else scoreOne
		setScore(sides.ally, myScore)
		setScore(sides.enemy, theirScore)

		local left = MatchState.timeLeft()
		local second = math.ceil(left)
		timeLabel.Text = clockText(left)
		local urgent = phase == "SuddenDeath"
			or phase == "Countdown"
			or (phase == "Live" and second <= URGENT_LIVE)
			or (phase == "Draft" and second <= 5)
			or (phase == "Vote" and second <= 3)
		timeLabel.TextColor3 = if urgent then DANGER else WHITE
		icon.ImageColor3 = if urgent then DANGER else WHITE
		timerEdge.Transparency = if urgent then 0.2 else 1
		if urgent and second ~= lastSecond and second >= 1 and second <= URGENT_LIVE then
			timerPop.Scale = 1.08
			tween(timerPop, 0.3, { Scale = 1 })
		end
		lastSecond = second
		-- The last seconds tick (moved here from MatchHudController's old bar).
		local from = TICK_FROM[phase or ""]
		if from and second >= 1 and second <= from and second ~= lastTick then
			lastTick = second
			UiSound.play(if second == 1 then "TickFinal" else "Tick")
		elseif not from or second > from then
			lastTick = -1
		end

		local round = MatchState.get("Round") or 0
		local matchPoint = math.max(myScore, theirScore) == Config.ROUNDS_TO_WIN - 1
		local info
		if phase == "Vote" then
			info = "VOTE FOR A MAP"
		elseif phase == "SuddenDeath" then
			info = string.format(
				'ROUND %d · <font color="#%s">SUDDEN DEATH</font>',
				round,
				DANGER:ToHex()
			)
		elseif round <= 0 then
			info = string.format("FIRST TO %d", Config.ROUNDS_TO_WIN)
		elseif phase == "Draft" then
			info = string.format("DRAFT · %s GUNS", tierName(round))
		elseif matchPoint then
			info = string.format('ROUND %d · <font color="#FFC83D">MATCH POINT</font>', round)
		else
			info = string.format("ROUND %d · %s", round, tierName(round))
		end
		infoLabel.Text = info
	end

	-- Drop into place when a match starts showing the bar.
	local home = root.Position
	root:GetPropertyChangedSignal("Visible"):Connect(function()
		if root.Visible then
			root.Position = home - UDim2.fromOffset(0, 40)
			tween(root, 0.42, { Position = home })
		end
	end)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < TICK then
			return
		end
		acc = 0
		refresh()
	end)
	refresh()
end

return TopBarController
