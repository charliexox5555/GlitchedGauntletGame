--!strict
-- Studio only: F4 opens the game-wide sound audition board (Shared/SoundAudition).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundAudition = require(ReplicatedStorage.Shared.SoundAudition)

local SoundAuditionController = {}

function SoundAuditionController.start()
	SoundAudition.start()
end

return SoundAuditionController
