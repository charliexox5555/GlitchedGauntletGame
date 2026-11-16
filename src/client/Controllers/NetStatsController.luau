--!strict
-- The server / FPS / ping readout, top right in the Roblox top bar row
-- (Shared/NetStats; vault/02 Art/UI Match Overhaul.md).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.NetStats)
local NetStats = require(ReplicatedStorage.Shared.NetStats)

local NetStatsController = {}

function NetStatsController.start()
	NetStats.mount(Config.RIGHT_INSET.match)
end

return NetStatsController
