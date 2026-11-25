--!strict
-- Studio only: F4 opens the game-wide sound audition board (Shared/SoundAudition).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundAudition = require(ReplicatedStorage.Shared.SoundAudition)

local SoundAuditionController = {}

function SoundAuditionController.start()
	-- the match also gets the win cutscene's accents
	SoundAudition.start({ "SHARED", "HITS", "CUTSCENE", "CASE" })
end

return SoundAuditionController
