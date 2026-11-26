--!strict
-- Match notifications (vault/02 Art/UI Notifications.md): one small toast
-- under the top bar instead of the old full-width banner. Round start (GET
-- READY with the round and gun tier, no big 3-2-1: the top bar's clock counts
-- it), FIGHT, MATCH POINT, SUDDEN DEATH, ROUND WON / LOST / DRAW, VICTORY /
-- DEFEAT, waiting and locked-in. The toast is built in Studio
-- (StarterGui.Notify, backup tools/studio/BuildNotify.luau); this only decides
-- what it says. A long band that fades out at both ends (no box, strip,
-- glow or pills; owner 2026-11-14). It shows what MatchState says; the server decides all of it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config.Match)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Teams = require(ReplicatedStorage.Shared.Mods.Teams)
local TestMode = require(ReplicatedStorage.Shared.TestMode)
local UiStyle = require(ReplicatedStorage.Shared.Config.UiStyle) -- FLAGS only (Roblox UI placement)

local UiSound = require(script.Parent.Parent.Util.UiSound)
local WaitGui = require(script.Parent.Parent.Util.WaitGui)

local MatchHudController = {}

local player = Players.LocalPlayer

local TICK = 0.1 -- seconds between refreshes
local FIGHT_MESSAGE_TIME = 1.2 -- seconds "FIGHT" stays up
local SUDDEN_DEATH_MESSAGE_TIME = 2.5 -- seconds "SUDDEN DEATH" stays up
local RESET_TRIES = 10

export type Tone = "neutral" | "ally" | "enemy" | "gold" | "danger"
local TONE: { [Tone]: Color3 } = {
	neutral = Color3.fromHex("F4F6F9"),
	ally = Color3.fromHex("3FE0F2"),
	enemy = Color3.fromHex("FF5A4E"),
	gold = Color3.fromHex("FFC83D"),
	danger = Color3.fromHex("FF4D5E"),
}
local WHITE = Color3.new(1, 1, 1)

-- The sound a notification makes as it comes in (by its title).
local SOUND: { [string]: string } = {
	["SUDDEN DEATH"] = "Banner",
	["GUNS UP"] = "Banner",
	["MATCH POINT"] = "Banner",
	FIGHT = "Fight",
	["ROUND WON"] = "RoundWon",
	["CLUTCH!"] = "RoundWon",
	["ACE!"] = "RoundWon",
	["FLAWLESS!"] = "RoundWon",
	["ROUND LOST"] = "RoundLost",
	DRAW = "Banner",
	-- VICTORY / DEFEAT: silent here. The ending song (MatchEnd) is started by
	-- the win cutscene (Util/WinCutscene), which runs on its clock.
}

type Ui = {
	gui: ScreenGui,
	fit: UIScale,
	band: CanvasGroup,
	title: TextLabel,
	titleShadow: TextLabel,
	sub: TextLabel,
	full: UDim2, -- the band's open size (Scale)
	shown: string,
	token: number,
}

local function tween(
	inst: Instance,
	time: number,
	goal: { [string]: any },
	style: Enum.EasingStyle?,
	dir: Enum.EasingDirection?
)
	TweenService:Create(
		inst,
		TweenInfo.new(time, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out),
		goal
	):Play()
end

local function myTeam(): number
	return Teams.of(player) or 1
end

-- An onboarding match deals later phases early (MatchState.phaseFor).
local function tierFor(round: number): Config.Phase
	return MatchState.phaseFor(round)
end

local function bind(): Ui
	local gui = WaitGui("Notify") :: ScreenGui
	local root = gui:WaitForChild("Root") :: Frame
	local band = root:WaitForChild("Band") :: CanvasGroup
	local ui: Ui = {
		gui = gui,
		fit = root:WaitForChild("Fit") :: UIScale,
		band = band,
		title = band:WaitForChild("Title") :: TextLabel,
		titleShadow = band:WaitForChild("Shadow") :: TextLabel,
		sub = band:WaitForChild("Sub") :: TextLabel,
		full = band.Size,
		shown = "",
		token = 0,
	}
	band.Visible = false
	band.GroupTransparency = 1

	-- The band is Scale (tools/studio/modules/UiToScale); each device's size
	-- and place come from Shared/UiLayout.
	return ui
end

-- Show (or update) the band; an empty title hides it.
local function show(ui: Ui, kicker: string, title: string, sub: string, tone: Tone)
	ui.sub.Text = if kicker ~= "" and sub ~= ""
		then kicker .. "  ·  " .. sub
		elseif kicker ~= "" then kicker
		else sub
	if title == ui.shown then
		return
	end
	local was = ui.shown
	ui.shown = title
	ui.token += 1
	local token = ui.token
	-- Open / close from the middle in Scale (the screen is Scale now).
	local full = ui.full
	local function across(k: number): UDim2
		return UDim2.new(full.X.Scale * k, full.X.Offset * k, full.Y.Scale, full.Y.Offset)
	end
	if title == "" then
		-- Out: the band closes toward its middle and fades.
		tween(
			ui.band,
			0.22,
			{ Size = across(0.6), GroupTransparency = 1 },
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.In
		)
		task.delay(0.24, function()
			if token == ui.token then
				ui.band.Visible = false
			end
		end)
		return
	end
	ui.title.Text = title
	ui.titleShadow.Text = title
	ui.title.TextColor3 = if tone == "neutral" then WHITE else TONE[tone]
	if was == "" then
		-- In: the band opens from its middle and fades in.
		ui.band.Visible = true
		ui.band.Size = across(0.4)
		ui.band.GroupTransparency = 1
		tween(ui.band, 0.32, { Size = full, GroupTransparency = 0 })
	else
		-- A new message in the open band: the words dip and come back.
		ui.band.GroupTransparency = 0.5
		tween(ui.band, 0.2, { GroupTransparency = 0 })
	end
	local sound = SOUND[title]
	if sound then
		UiSound.play(sound)
	end
end

local liveSince = -math.huge
local suddenSince = -math.huge
-- A short fight-time alert (MatchHudController.alert), e.g. OUTSIDE THE ZONE.
local alertTitle, alertSub, alertTone, alertUntil = "", "", "danger" :: Tone, -math.huge

local function refresh(ui: Ui)
	local phase = MatchState.phase()
	local mine = myTeam()
	local scoreOne = MatchState.get("Score1") or 0
	local scoreTwo = MatchState.get("Score2") or 0
	local round = MatchState.get("Round") or 0
	local now = os.clock()
	local myScore = if mine == 1 then scoreOne else scoreTwo
	local theirScore = if mine == 1 then scoreTwo else scoreOne
	local scoreLine = string.format(
		'<font color="#%s">%d</font>  —  <font color="#%s">%d</font>',
		TONE.ally:ToHex(),
		myScore,
		TONE.enemy:ToHex(),
		theirScore
	)
	local tier = tierFor(round)
	local roundTag = string.format("ROUND %d · %s", round, string.upper(tier.name))
	local roundsGoal = MatchState.roundsToWin()
	local need = roundsGoal - 1
	local matchPoint = myScore == need or theirScore == need

	local kicker, title, sub, tone = "", "", "", "neutral" :: Tone
	if phase == "Vote" then
		-- the map vote screen (MapVoteController) has the middle: no banner
		title = ""
	elseif phase == "Waiting" then
		title, sub = "WAITING FOR OPPONENT", string.format("First to %d", roundsGoal)
	elseif phase == "Draft" then
		-- The draft screen covers the middle until you've locked in.
		if StateValues.get(player, "DraftLocked") == true then
			kicker, title, sub, tone = roundTag, "LOCKED IN", "Waiting for the others", "ally"
		end
	elseif phase == "Countdown" then
		kicker = string.format("ROUND %d", round)
		if matchPoint then
			title, tone = "MATCH POINT", "gold"
			sub = if myScore == need and theirScore == need
				then "Next round wins it"
				elseif myScore == need then "You need one more round"
				else "They need one more round"
		elseif round > 1 and tierFor(round - 1).name ~= tier.name then
			-- The tier went up: the 3-2-1 hands out the bigger guns (vault/01 Design/First Ten Minutes.md).
			title, tone = "GUNS UP", "gold"
			sub = string.format("%s guns", tier.name)
		else
			title = "GET READY"
			sub = string.format("%s guns", tier.name)
		end
	elseif phase == "Live" then
		if now - liveSince < FIGHT_MESSAGE_TIME then
			kicker, title = roundTag, "FIGHT"
		end
	elseif phase == "SuddenDeath" then
		if now - suddenSince < SUDDEN_DEATH_MESSAGE_TIME then
			kicker, title, sub, tone = roundTag, "SUDDEN DEATH", "Get inside the circle", "danger"
		end
	elseif phase == "RoundEnd" then
		local winner = MatchState.get("RoundWinner") or 0
		local callout = MatchState.get("RoundCallout") :: MatchState.RoundCallout?
		kicker = string.format("ROUND %d", round)
		if winner == 0 then
			title, sub = "DRAW", "No point for either side"
		elseif winner == mine then
			if callout and callout.team == winner then
				local who = if callout.actor then string.upper(callout.actor) .. "  ·  " else ""
				if callout.tag == "CLUTCH" then
					title, tone = "CLUTCH!", "gold"
					kicker = "ROUND WON · " .. string.upper(callout.detail or "")
					sub = who .. scoreLine
				elseif callout.tag == "ACE" then
					title, tone = "ACE!", "gold"
					kicker = "ROUND WON"
					sub = who .. scoreLine
				elseif callout.tag == "FLAWLESS" then
					title, tone = "FLAWLESS!", "ally"
					kicker = "ROUND WON"
						.. (if callout.detail then " · " .. callout.detail else "")
					sub = scoreLine
				elseif callout.tag == "CLOSE CALL" then
					title, tone = "ROUND WON", "ally"
					kicker = "CLOSE CALL · " .. (callout.detail or "")
					sub = scoreLine
				else
					title, sub, tone = "ROUND WON", scoreLine, "ally"
				end
			else
				title, sub, tone = "ROUND WON", scoreLine, "ally"
			end
		else
			if callout and callout.team == winner then
				kicker = string.format("ROUND %d · %s", round, callout.tag)
			end
			title, sub, tone = "ROUND LOST", scoreLine, "enemy"
		end
	elseif phase == "MatchEnd" then
		local won = MatchState.get("MatchWinner") == mine
		kicker, title, sub = "MATCH OVER", if won then "VICTORY" else "DEFEAT", scoreLine
		tone = if won then "gold" else "enemy"
	end
	-- An alert fills the band in a fight when nothing else is showing.
	if title == "" and now < alertUntil and (phase == "Live" or phase == "SuddenDeath") then
		kicker, title, sub, tone = roundTag, alertTitle, alertSub, alertTone
	end
	show(ui, kicker, title, sub, tone)
end

-- Shows a short alert in the notification band for `seconds` (called again
-- to keep it up). Tones: "neutral" | "ally" | "enemy" | "gold" | "danger".
function MatchHudController.alert(title: string, sub: string, tone: string, seconds: number)
	alertTitle, alertSub = title, sub
	alertTone = (if TONE[tone] then tone else "danger") :: any
	alertUntil = os.clock() + seconds
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
	local ui = bind()
	while true do
		refresh(ui)
		task.wait(TICK)
	end
end

return MatchHudController
