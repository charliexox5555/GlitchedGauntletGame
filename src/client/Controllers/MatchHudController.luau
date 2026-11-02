--!strict
-- The match's on-screen state (rough, PC first; final design comes later): the
-- score and clock at the top, and big messages for each phase. It only shows
-- what MatchState says; the server decides all of it. Layout is in Scale.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Config = require(ReplicatedStorage.Shared.Config.Match)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local ModsConfig = require(ReplicatedStorage.Shared.Config.Mods)
local Teams = require(ReplicatedStorage.Shared.Mods.Teams)
local TestMode = require(ReplicatedStorage.Shared.TestMode)

local MatchHudController = {}

local player = Players.LocalPlayer

local WHITE = Color3.new(1, 1, 1)
local BACK = Color3.fromHex("16181B")
local BOLD = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
local MEDIUM = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Medium)

local TICK = 0.1 -- seconds between refreshes
local FIGHT_MESSAGE_TIME = 1 -- seconds "FIGHT" stays up
local RESET_TRIES = 10

type Ui = {
	bar: Frame,
	myScore: TextLabel,
	enemyScore: TextLabel,
	clock: TextLabel,
	round: TextLabel,
	banner: TextLabel,
	sub: TextLabel,
}

local function make(className: string, props: { [string]: any }, parent: Instance?): any
	local inst = Instance.new(className)
	for k, v in props do
		(inst :: any)[k] = v
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function text(parent: Instance, props: { [string]: any }): TextLabel
	local label = make("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = BOLD,
		TextColor3 = WHITE,
		TextScaled = true,
		Text = "",
	}, parent)
	for k, v in props do
		(label :: any)[k] = v
	end
	return label
end

local function build(): Ui
	local gui = make("ScreenGui", {
		Name = "MatchHud",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 5,
	}, player:WaitForChild("PlayerGui"))

	local bar = make("Frame", {
		Name = "ScoreBar",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.015),
		Size = UDim2.fromScale(0.26, 0.085),
		BackgroundColor3 = BACK,
		BackgroundTransparency = 0.25,
		Visible = false,
	}, gui)
	make("UIAspectRatioConstraint", { AspectRatio = 4.6 }, bar)
	make("UICorner", { CornerRadius = UDim.new(0.15, 0) }, bar)

	local myScore = text(bar, {
		Position = UDim2.fromScale(0.03, 0.12),
		Size = UDim2.fromScale(0.22, 0.76),
		TextColor3 = ModsConfig.COLORS.ally,
	})
	local enemyScore = text(bar, {
		Position = UDim2.fromScale(0.75, 0.12),
		Size = UDim2.fromScale(0.22, 0.76),
		TextColor3 = ModsConfig.COLORS.enemy,
	})
	local clock = text(bar, {
		Position = UDim2.fromScale(0.3, 0.06),
		Size = UDim2.fromScale(0.4, 0.58),
	})
	local round = text(bar, {
		Position = UDim2.fromScale(0.3, 0.64),
		Size = UDim2.fromScale(0.4, 0.28),
		FontFace = MEDIUM,
	})

	local banner = text(gui, {
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromScale(0.7, 0.11),
		TextStrokeTransparency = 0.5,
	})
	local sub = text(gui, {
		Name = "Sub",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.36),
		Size = UDim2.fromScale(0.6, 0.04),
		FontFace = MEDIUM,
		TextStrokeTransparency = 0.5,
	})
	return {
		bar = bar,
		myScore = myScore,
		enemyScore = enemyScore,
		clock = clock,
		round = round,
		banner = banner,
		sub = sub,
	}
end

local function myTeam(): number
	return Teams.of(player) or 1
end

local function clockText(seconds: number): string
	local whole = math.ceil(seconds)
	return string.format("%d:%02d", math.floor(whole / 60), whole % 60)
end

local liveSince = -math.huge

local function refresh(ui: Ui)
	local phase = MatchState.phase()
	ui.bar.Visible = phase ~= nil and phase ~= "Waiting"
	if not phase then
		ui.banner.Text = ""
		ui.sub.Text = ""
		return
	end

	local mine = myTeam()
	local scoreOne = MatchState.get("Score1") or 0
	local scoreTwo = MatchState.get("Score2") or 0
	ui.myScore.Text = tostring(if mine == 1 then scoreOne else scoreTwo)
	ui.enemyScore.Text = tostring(if mine == 1 then scoreTwo else scoreOne)
	local left = MatchState.timeLeft()
	ui.clock.Text = clockText(left)
	local round = MatchState.get("Round") or 0
	ui.round.Text = if round > 0
		then string.format("ROUND %d · FIRST TO %d", round, Config.ROUNDS_TO_WIN)
		else string.format("FIRST TO %d", Config.ROUNDS_TO_WIN)

	local banner, sub = "", ""
	if phase == "Waiting" then
		banner, sub = "WAITING FOR OPPONENT", ""
	elseif phase == "Ready" then
		banner, sub = "GET READY", string.format("Match starts in %d", math.ceil(left))
	elseif phase == "Draft" then
		-- The draft screen covers this until you've locked in.
		if player:GetAttribute("DraftLocked") == true then
			banner, sub = "LOCKED IN", "Waiting for the other players"
		end
	elseif phase == "Countdown" then
		banner, sub = tostring(math.max(math.ceil(left), 1)), "The barrier drops soon"
	elseif phase == "Live" then
		if os.clock() - liveSince < FIGHT_MESSAGE_TIME then
			banner = "FIGHT"
		end
	elseif phase == "RoundEnd" then
		local winner = MatchState.get("RoundWinner") or 0
		banner = if winner == 0 then "DRAW" elseif winner == mine then "ROUND WON" else "ROUND LOST"
		sub = if winner == 0 then "No point for either side" else ""
	elseif phase == "MatchEnd" then
		banner = if MatchState.get("MatchWinner") == mine then "YOU WIN" else "YOU LOSE"
		sub = "A new match starts soon"
	end
	ui.banner.Text = banner
	ui.sub.Text = sub
end

-- One life per round, so no Reset Character in a match. SetCore isn't ready
-- right at startup, so it takes a few tries.
local function disableReset()
	for _ = 1, RESET_TRIES do
		local ok = pcall(function()
			StarterGui:SetCore("ResetButtonCallback", false)
		end)
		if ok then
			return
		end
		task.wait(1)
	end
end

function MatchHudController.start()
	local ui = build()
	if not TestMode.isOn() then
		task.spawn(disableReset)
	end
	MatchState.changed("Phase"):Connect(function()
		if MatchState.phase() == "Live" then
			liveSince = os.clock()
		end
	end)
	while true do
		refresh(ui)
		task.wait(TICK)
	end
end

return MatchHudController
