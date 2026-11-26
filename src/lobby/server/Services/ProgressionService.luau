--!strict
-- Levels, XP and the win streak (vault/01 Design/Progression.md). Runs in every role
-- (lobby: pad duels; match servers). Match flow calls it, there is no remote in:
--   ProgressionService.report(matchKey, userId, result)  one player's match (or leave)
-- Each report is one PlayerDataService write with the id "m:<matchKey>:<userId>", so a
-- repeated report (a leaver who came back, a retried match end) never counts twice.
-- The player (when still here) gets a ProgressEvent "gain" for the end screen and the
-- level-up pop; the new level and streak are published on them by PlayerData.
-- The same write pays match coins (Config/Economy.MATCH_COINS: finishing, a win bonus,
-- half with no real opponent, nothing for leaving, capped per UTC day in `earn`).
-- And the task Path (Shared/TaskPath, owner 2026-11-26): the match's task stats (MatchService, from
-- StatsService.taskStats) move the showing part in the same write, once the player had finished
-- Config/Tasks START_AFTER_MATCHES matches before this one; TaskService pays and toasts it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LobbyNet = require(ReplicatedStorage.Lobby.LobbyNet)
local PlayerData = require(ReplicatedStorage.Shared.PlayerData)
local Progress = require(ReplicatedStorage.Shared.Progress)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Inventory = require(ReplicatedStorage.Shared.Config.Inventory)
local Onboarding = require(ReplicatedStorage.Shared.Config.Onboarding)
local PlayerDataService = require(script.Parent.PlayerDataService)
local TaskPath = require(ReplicatedStorage.Shared.TaskPath)
local TaskService = require(script.Parent.TaskService)
local Telemetry = require(script.Parent.Parent.Telemetry)

local ProgressionService = {}

-- A report that couldn't save (a DataStore outage, a long queue) tries again: the same
-- txId can't apply twice. Shutdown waits for pending reports (BindToClose below).
local RETRY_AFTER = { 5, 20, 60 }
local pending = 0

local progressEvent: RemoteEvent = LobbyNet.event("ProgressEvent")

-- Coins for one match (before the daily cap).
local function matchCoins(result: Progress.Result): number
	if result.left then
		return 0
	end
	local pay = Economy.MATCH_COINS
	local n = pay.finish + (if result.won then pay.win else 0)
	if not result.counts then
		n *= pay.botScale
	end
	return math.floor(n)
end

-- Never yields the caller: the write runs on its own thread.
function ProgressionService.report(
	matchKey: string,
	userId: number,
	result: Progress.Result,
	mode: unknown,
	taskStats: unknown -- TaskPath.MatchStats (checked again here)
)
	if
		typeof(matchKey) ~= "string"
		or #matchKey == 0
		or typeof(userId) ~= "number"
		or userId <= 0
	then
		return
	end
	local stats = TaskPath.cleanMatch(taskStats)
	task.spawn(function()
		pending += 1
		local txId = string.sub(`m:{matchKey}:{userId}`, 1, 64)
		local gain: Progress.Gain? = nil
		local paid = 0
		local gainedCase = false
		local taskPay: TaskPath.Payout? = nil
		local ok, why = false, nil :: string?
		for attempt = 0, #RETRY_AFTER do
			if attempt > 0 then
				task.wait(RETRY_AFTER[attempt])
			end
			ok, why = PlayerDataService.transactUserId(userId, txId, function(data: PlayerData.Data)
				gainedCase = false
				taskPay = nil
				local now = os.time()
				local matchesBefore = data.prog.matches
				gain = Progress.apply(data.prog, result, now)
				if stats and TaskPath.open(matchesBefore) then
					local pay = TaskPath.applyMatch(data.tasks, stats, data.prog.level)
					TaskService.pay(data, pay)
					taskPay = pay
				end
				if not result.left and data.prog.matches == 1 and not data.onb.caseGift then
					data.onb.caseGift = true
					local caseId = Onboarding.FIRST_MATCH_CASE
					data.items[caseId] = (data.items[caseId] or 0) + 1
					gainedCase = true
				end
				local today = Economy.day(now)
				if data.earn.day ~= today then
					data.earn = { day = today, coins = 0 }
				end
				local room = math.max(Economy.MATCH_COINS.dailyCap - data.earn.coins, 0)
				paid = math.min(matchCoins(result), room, Inventory.MAX_COINS - data.coins)
				data.coins += paid
				data.earn.coins += paid
				return true
			end)
			if ok or (why ~= "saving" and why ~= "busy") then
				break
			end
		end
		pending -= 1
		if not ok then
			warn(`[Progression] match {matchKey} for {userId} not saved: {why}`)
			return
		end
		local player = game:GetService("Players"):GetPlayerByUserId(userId)
		local g = gain
		if player and g then
			local label = if type(mode) == "string" then mode else "Duel"
			if
				g.levelFrom < Onboarding.BEGINNER_MAX_LEVEL
				and g.levelTo >= Onboarding.BEGINNER_MAX_LEVEL
			then
				Telemetry.event(player, "Beginner graduated", 1)
			end
			if not result.left then
				Telemetry.funnel(player, "Match", matchKey, 12, "Match saved", label)
				local data = PlayerDataService.get(player)
				local matches = data and data.prog.matches
				if matches == 1 then
					Telemetry.onboarding(player, 12)
				elseif matches == 2 then
					Telemetry.onboarding(player, 19)
				end
				if gainedCase then
					Telemetry.caseOnboarding(player, 1, "Free case granted")
				end
			end
			progressEvent:FireClient(player, {
				kind = "gain",
				xp = g.xp,
				levelFrom = g.levelFrom,
				levelTo = g.levelTo,
				streakFrom = g.streakFrom,
				streakTo = g.streakTo,
				lostOffer = g.lostOffer,
				coins = paid,
			})
			TaskService.notify(player, taskPay)
		end
	end)
end

function ProgressionService.init() end
function ProgressionService.start()
	game:BindToClose(function()
		local t = os.clock()
		while pending > 0 and os.clock() - t < 25 do
			task.wait(0.2)
		end
	end)
end

return ProgressionService
