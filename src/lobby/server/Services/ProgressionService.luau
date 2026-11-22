--!strict
-- Levels, XP and the win streak (vault/01 Design/Progression.md). Runs in every role
-- (lobby: pad duels; match servers). Match flow calls it, there is no remote in:
--   ProgressionService.report(matchKey, userId, result)  one player's match (or leave)
-- Each report is one PlayerDataService write with the id "m:<matchKey>:<userId>", so a
-- repeated report (a leaver who came back, a retried match end) never counts twice.
-- The player (when still here) gets a ProgressEvent "gain" for the end screen and the
-- level-up pop; the new level and streak are published on them by PlayerData.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LobbyNet = require(ReplicatedStorage.Lobby.LobbyNet)
local PlayerData = require(ReplicatedStorage.Shared.PlayerData)
local Progress = require(ReplicatedStorage.Shared.Progress)
local PlayerDataService = require(script.Parent.PlayerDataService)

local ProgressionService = {}

-- A report that couldn't save (a DataStore outage, a long queue) tries again: the same
-- txId can't apply twice. Shutdown waits for pending reports (BindToClose below).
local RETRY_AFTER = { 5, 20, 60 }
local pending = 0

local progressEvent: RemoteEvent = LobbyNet.event("ProgressEvent")

-- Never yields the caller: the write runs on its own thread.
function ProgressionService.report(matchKey: string, userId: number, result: Progress.Result)
	if
		typeof(matchKey) ~= "string"
		or #matchKey == 0
		or typeof(userId) ~= "number"
		or userId <= 0
	then
		return
	end
	task.spawn(function()
		pending += 1
		local txId = string.sub(`m:{matchKey}:{userId}`, 1, 64)
		local gain: Progress.Gain? = nil
		local ok, why = false, nil :: string?
		for attempt = 0, #RETRY_AFTER do
			if attempt > 0 then
				task.wait(RETRY_AFTER[attempt])
			end
			ok, why = PlayerDataService.transactUserId(userId, txId, function(data: PlayerData.Data)
				gain = Progress.apply(data.prog, result, os.time())
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
			progressEvent:FireClient(player, {
				kind = "gain",
				xp = g.xp,
				levelFrom = g.levelFrom,
				levelTo = g.levelTo,
				streakFrom = g.streakFrom,
				streakTo = g.streakTo,
				lostOffer = g.lostOffer,
			})
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
