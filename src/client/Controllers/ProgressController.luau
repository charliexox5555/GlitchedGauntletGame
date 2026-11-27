--!strict
-- XP, level and streak on the match end screen (vault/01 Design/Progression.md). Studio-built
-- MatchEndScreen.Canvas.Right.Progress (top of the right column): LV, +XP, a bar that fills
-- (and wraps on a level up, with a LEVEL UP pop), the XP numbers and the streak line.
-- Fed by the server's ProgressEvent "gain" (lobby Services/ProgressionService), which lands a
-- moment after the match ends; the bar plays once the end screen is up.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Progression = require(ReplicatedStorage.Shared.Config.Progression)
local StateValues = require(ReplicatedStorage.Shared.StateValues)

local ProgressController = {}

local player = Players.LocalPlayer
local token = 0

local QUINT_OUT = TweenInfo.new(0.7, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local POP = TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

local function num(v: any, default: number): number
	return if typeof(v) == "number" and v == v then v else default
end

local function find(): (ScreenGui?, Frame?)
	local gui = player:FindFirstChild("PlayerGui")
	local screen = gui and gui:FindFirstChild("MatchEndScreen")
	local canvas = screen and screen:FindFirstChild("Canvas")
	local right = canvas and canvas:FindFirstChild("Right")
	local panel = right and right:FindFirstChild("Progress")
	if screen and screen:IsA("ScreenGui") and panel and panel:IsA("Frame") then
		return screen, panel
	end
	return nil, nil
end

local function label(panel: Frame, name: string): TextLabel?
	local l = panel:FindFirstChild(name)
	return if l and l:IsA("TextLabel") then l else nil
end

local function play(g: { [string]: any })
	token += 1
	local my = token
	local screen, panel = find()
	if not screen or not panel then
		return
	end
	local track = panel:FindFirstChild("Track")
	local fill = track and track:FindFirstChild("Fill")
	if not (fill and fill:IsA("Frame")) then
		return
	end
	local xp = num(g.xp, 0)
	local levelFrom, levelTo = num(g.levelFrom, 1), num(g.levelTo, 1)
	-- where the bar ends: the published XP into the new level (falls back to a full bar)
	local xpNow = num(StateValues.get(player, "Xp"), 0)
	local needNow = Progression.xpToNext(levelTo)
	local startXp = if levelTo == levelFrom then math.max(xpNow - xp, 0) else 0
	local startShare = startXp / needNow

	local levelLabel, gain, xpLabel, streakLabel, up =
		label(panel, "Level"),
		label(panel, "Gain"),
		label(panel, "Xp"),
		label(panel, "Streak"),
		label(panel, "LevelUp")
	if levelLabel then
		levelLabel.Text = "LV " .. levelFrom
	end
	if gain then
		local coins = num(g.coins, 0) -- match pay (Config/Economy.MATCH_COINS + MATCH_BONUS)
		local firstWin = num(g.firstWin, 0) -- the day's first-win bonus, already inside `coins`
		gain.Text = "+"
			.. xp
			.. " XP"
			.. (if coins > 0 then `  ·  +{coins} COINS` else "")
			.. (if firstWin > 0 then "  ·  FIRST WIN" else "")
	end
	if xpLabel then
		xpLabel.Text = string.format("%d / %d XP", xpNow, needNow)
	end
	if streakLabel then
		local from, to = num(g.streakFrom, 0), num(g.streakTo, 0)
		local lost = num(g.lostOffer, 0)
		streakLabel.Text = if lost > 0
			then string.format("STREAK %d LOST · SAVE IT IN THE LOBBY", lost)
			elseif to > from then "WIN STREAK " .. to
			elseif to == 0 and from > 0 then "STREAK ENDED"
			elseif to > 0 then "WIN STREAK " .. to
			else ""
	end
	if up then
		up.Visible = false
	end
	panel.Visible = true

	task.spawn(function()
		-- wait for the end screen to be up (the cutscene plays first)
		local t = os.clock()
		while not screen.Enabled and os.clock() - t < 30 do
			task.wait(0.2)
		end
		if my ~= token or not screen.Enabled then
			return
		end
		task.wait(0.6)
		if levelTo > levelFrom then
			fill.Size =
				UDim2.fromScale(math.clamp(startXp / Progression.xpToNext(levelFrom), 0, 1), 1)
			local tw = TweenService:Create(fill, QUINT_OUT, { Size = UDim2.fromScale(1, 1) })
			tw:Play()
			tw.Completed:Wait()
			if my ~= token then
				return
			end
			if levelLabel then
				levelLabel.Text = "LV " .. levelTo
			end
			if up then
				local pop = up:FindFirstChild("Pop")
				up.Visible = true
				if pop and pop:IsA("UIScale") then
					pop.Scale = 0.4
					TweenService:Create(pop, POP, { Scale = 1 }):Play()
				end
			end
			fill.Size = UDim2.fromScale(0, 1)
		else
			fill.Size = UDim2.fromScale(math.clamp(startShare, 0, 1), 1)
		end
		TweenService
			:Create(
				fill,
				QUINT_OUT,
				{ Size = UDim2.fromScale(math.clamp(xpNow / needNow, 0, 1), 1) }
			)
			:Play()
	end)
end

function ProgressController.start()
	local lobby = ReplicatedStorage:WaitForChild("Lobby", 30)
	if not lobby then
		return
	end
	local LobbyNet = require(lobby:WaitForChild("LobbyNet") :: ModuleScript) :: any
	LobbyNet.event("ProgressEvent").OnClientEvent:Connect(function(payload: any)
		if typeof(payload) == "table" and payload.kind == "gain" then
			play(payload)
		end
	end)
	-- a new match: the panel waits for its next gain
	local MatchState = require(ReplicatedStorage.Shared.MatchState) :: any
	MatchState.changed("Results"):Connect(function()
		if MatchState.get("Results") == nil then
			token += 1
			local _, panel = find()
			if panel then
				panel.Visible = false
			end
		end
	end)
end

return ProgressController
