--!strict
-- The second favorite ask, during a new player's second match, if they declined the
-- first one in the lobby (vault/05 Production/Handoff - Onboarding and Bots.md; rule
-- Shared/Onboarding.favAsk "match", prompt Shared/FavoritePrompt). It waits for the
-- first round break (RoundEnd) so it never covers a fight, and asks at most once a match.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FavoritePrompt = require(ReplicatedStorage.Shared.FavoritePrompt)
local MatchState = require(ReplicatedStorage.Shared.MatchState)

local FavoriteAskController = {}

local ROUND_BREAK = "RoundEnd"
local DELAY = 1.2 -- seconds into the break (the round's result lands first)
local asked = false

function FavoriteAskController.init() end

function FavoriteAskController.start()
	-- runs while this player is in a match (a hosted queued match since 2026-11-23, or a pad duel)
	MatchState.changed("Phase"):Connect(function()
		if asked or MatchState.get("Phase") ~= ROUND_BREAK then
			return
		end
		asked = true
		task.delay(DELAY, function()
			if MatchState.get("Phase") == ROUND_BREAK then
				FavoritePrompt.maybeAsk("match")
			end
		end)
	end)
end

return FavoriteAskController
