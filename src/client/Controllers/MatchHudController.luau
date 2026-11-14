--!strict
-- The match's full-width banners (get ready, countdown, fight, round won /
-- lost, match end), UI v1 (vault/02 Art/UI Design.md). The top bar moved to the
-- Studio-built StarterGui.TopBar and TopBarController (2026-11-14). It only
-- shows what MatchState says; the server decides all of it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")

local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Teams = require(ReplicatedStorage.Shared.Mods.Teams)
local TestMode = require(ReplicatedStorage.Shared.TestMode)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)
local UiStyle = require(ReplicatedStorage.Shared.Config.UiStyle) -- FLAGS only (Roblox UI placement)

local Ui = require(script.Parent.Parent.Util.Ui)
local UiSound = require(script.Parent.Parent.Util.UiSound)

local MatchHudController = {}

local player = Players.LocalPlayer
local C = Theme.COLORS
local make = Ui.make

local TICK = 0.1 -- seconds between refreshes
local FIGHT_MESSAGE_TIME = 1 -- seconds "FIGHT" stays up
local SUDDEN_DEATH_MESSAGE_TIME = 2.5 -- seconds "SUDDEN DEATH" stays up
local RESET_TRIES = 10
local BAND_SIZE = UDim2.fromScale(1, 260 / 1080)

-- The sound a banner makes as it comes in (by its title).
local BANNER_SOUND: { [string]: string } = {
	["SUDDEN DEATH"] = "Banner",
	FIGHT = "Fight",
	["ROUND WON"] = "RoundWon",
	["ROUND LOST"] = "RoundLost",
	DRAW = "Banner",
	VICTORY = "Victory",
	DEFEAT = "RoundLost",
}

type Ui = {
	band: Frame,
	bandGradient: UIGradient,
	lines: { Frame },
	content: Frame,
	pop: UIScale,
	kicker: TextLabel,
	title: TextLabel,
	sub: TextLabel,
	shownTitle: string,
}

local function build(): Ui
	-- The banner is full-width art (nothing to press).
	local gui = make("ScreenGui", {
		Name = "MatchHud",
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		SafeAreaCompatibility = Enum.SafeAreaCompatibility.None,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 9, -- above the draft screen (8)
	}, player:WaitForChild("PlayerGui"))

	-- Banner: a full-width band in the result's colour, its words in a
	-- design-size frame in the middle.
	local band = make("Frame", {
		Name = "Banner",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.45),
		Size = BAND_SIZE,
		ClipsDescendants = true,
		BorderSizePixel = 0,
		BackgroundColor3 = C.white,
		Visible = false,
	}, gui)
	local bandGradient = make("UIGradient", {}, band)
	local lines = {}
	for i, y in { 0, 1 } do
		local line = make("Frame", {
			AnchorPoint = Vector2.new(0, y),
			Position = UDim2.fromScale(0, y),
			Size = UDim2.new(1, 0, 0, 3),
			BorderSizePixel = 0,
			BackgroundColor3 = C.white,
		}, band)
		make("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 0),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}, line)
		lines[i] = line
	end
	local content = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(1920, 260),
		BackgroundTransparency = 1,
	}, band)
	Ui.fit(content)
	local inner = make("Frame", {
		Name = "Pop",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, content)
	local pop = make("UIScale", {}, inner)
	local kicker = Ui.text(inner, "", "label", {
		Position = UDim2.fromOffset(0, 26),
		Size = UDim2.fromOffset(1920, 16),
		TextColor3 = C.textSecondary,
	})
	local title = Ui.text(inner, "", "displayXL", {
		Position = UDim2.fromOffset(0, 46),
		Size = UDim2.fromOffset(1920, 150),
	})
	local sub = Ui.text(inner, "", "displayM", {
		Position = UDim2.fromOffset(0, 196),
		Size = UDim2.fromOffset(1920, 44),
		TextSize = 34,
		RichText = true,
	})

	return {
		band = band,
		bandGradient = bandGradient,
		lines = lines,
		content = content,
		pop = pop,
		kicker = kicker,
		title = title,
		sub = sub,
		shownTitle = "",
	}
end

local function myTeam(): number
	return Teams.of(player) or 1
end

local liveSince = -math.huge
local suddenSince = -math.huge
local bandToken = 0

-- The band's look: a colour that fades out to both sides.
local function tintBand(ui: Ui, color: Color3)
	-- Neutral banners (countdown, GET READY, FIGHT) are just a dark band.
	local edge = if color == C.white then C.scrim else color
	ui.bandGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, edge),
		ColorSequenceKeypoint.new(0.5, C.scrim),
		ColorSequenceKeypoint.new(1, edge),
	})
	ui.bandGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.12),
		NumberSequenceKeypoint.new(1, 1),
	})
	for _, line in ui.lines do
		line.BackgroundColor3 = if color == C.white then C.lineStrong else color
	end
	ui.title.TextColor3 = if color == C.white then C.text else color
end

local function refresh(ui: Ui)
	local phase = MatchState.phase()
	local mine = myTeam()
	local scoreOne = MatchState.get("Score1") or 0
	local scoreTwo = MatchState.get("Score2") or 0
	local left = MatchState.timeLeft()
	local round = MatchState.get("Round") or 0
	local now = os.clock()

	local kicker, title, sub, color = "", "", "", C.white
	local myScore = if mine == 1 then scoreOne else scoreTwo
	local theirScore = if mine == 1 then scoreTwo else scoreOne
	local scoreLine = string.format(
		'<font color="#%s">%d</font>   —   <font color="#%s">%d</font>',
		C.ally:ToHex(),
		myScore,
		C.enemy:ToHex(),
		theirScore
	)
	if phase == "Waiting" then
		title = "WAITING FOR OPPONENT"
	elseif phase == "Draft" then
		-- The draft screen covers the middle until you've locked in.
		if player:GetAttribute("DraftLocked") == true then
			kicker, title, sub =
				string.format("ROUND %d", round), "LOCKED IN", "Waiting for the other players"
			color = C.ready
		end
	elseif phase == "Countdown" then
		kicker, title = string.format("ROUND %d", round), tostring(math.max(math.ceil(left), 1))
	elseif phase == "Live" then
		if now - liveSince < FIGHT_MESSAGE_TIME then
			kicker, title = string.format("ROUND %d", round), "FIGHT"
		end
	elseif phase == "SuddenDeath" then
		if now - suddenSince < SUDDEN_DEATH_MESSAGE_TIME then
			kicker, title, sub, color =
				string.format("ROUND %d", round), "SUDDEN DEATH", "Get inside the circle", C.enemy
		end
	elseif phase == "RoundEnd" then
		local winner = MatchState.get("RoundWinner") or 0
		kicker = string.format("ROUND %d", round)
		if winner == 0 then
			title, sub = "DRAW", "No point for either side"
		elseif winner == mine then
			title, sub, color = "ROUND WON", scoreLine, C.ally
		else
			title, sub, color = "ROUND LOST", scoreLine, C.enemy
		end
	elseif phase == "MatchEnd" then
		local won = MatchState.get("MatchWinner") == mine
		kicker, title, sub, color =
			"MATCH OVER",
			if won then "VICTORY" else "DEFEAT",
			scoreLine,
			if won then C.ally else C.enemy
	end

	ui.kicker.Text = kicker
	ui.sub.Text = sub
	if title ~= ui.shownTitle then
		local was = ui.shownTitle
		ui.shownTitle = title
		bandToken += 1
		local token = bandToken
		if title == "" then
			-- Out: the band folds shut, then hides.
			Ui.tween(
				ui.band,
				Theme.MOTION.exit,
				{ Size = UDim2.fromScale(1, 0) },
				Enum.EasingStyle.Quint,
				Enum.EasingDirection.In
			)
			task.delay(Theme.MOTION.exit, function()
				if token == bandToken then
					ui.band.Visible = false
				end
			end)
			return
		end
		ui.title.Text = title
		tintBand(ui, color)
		if was == "" then
			-- In: the band opens from its middle line.
			ui.band.Size = UDim2.fromScale(1, 0)
			ui.band.Visible = true
			Ui.tween(ui.band, 0.22, { Size = BAND_SIZE }, Enum.EasingStyle.Quint)
		end
		ui.pop.Scale = 1.15
		Ui.tween(ui.pop, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
		local sound = BANNER_SOUND[title]
		if sound then
			UiSound.play(sound)
		end
	end
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

-- Roblox's own UI in a match (Config/UiStyle FLAGS): the player list steps
-- aside for the top bar and kill feed, and the chat window moves to the left
-- middle, so nothing of ours sits under either (LihFolk: Safe Areas and Insets).
local function arrangeCoreUi()
	local flags = UiStyle.FLAGS
	if flags.matchHidePlayerList then
		for _ = 1, RESET_TRIES do
			local ok =
				pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.PlayerList, false)
			if ok then
				break
			end
			task.wait(1)
		end
	end
	local window = TextChatService:FindFirstChildOfClass("ChatWindowConfiguration")
	if window then
		pcall(function()
			(window :: any).VerticalAlignment = (Enum.VerticalAlignment :: any)[flags.matchChatVertical]
		end)
	end
end

function MatchHudController.start()
	local ui = build()
	task.spawn(arrangeCoreUi)
	if not TestMode.isOn() then
		task.spawn(disableReset)
	end
	MatchState.changed("Phase"):Connect(function()
		local phase = MatchState.phase()
		if phase == "Live" then
			liveSince = os.clock()
		elseif phase == "SuddenDeath" then
			suddenSince = os.clock()
		end
	end)
	while true do
		refresh(ui)
		task.wait(TICK)
	end
end

return MatchHudController
