--!strict
-- Studio only: F4 opens the game-wide sound audition board (Shared/SoundAudition).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundAudition = require(ReplicatedStorage.Shared.SoundAudition)

local SoundAuditionController = {}

function SoundAuditionController.start()
	-- One place since 2026-11-21: the lobby's board is the whole game's (the match tabs too).
	SoundAudition.start({ "SHARED", "HITS", "CUTSCENE" }) -- CASE rows all picked (owner 2026-11-20)
end

return SoundAuditionController
