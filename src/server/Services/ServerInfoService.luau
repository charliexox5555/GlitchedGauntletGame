--!strict
-- Publishes where this server is for the top bar readout (Shared/ServerRegion,
-- Shared/NetStats; vault/02 Art/UI Match Overhaul.md).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerRegion = require(ReplicatedStorage.Shared.ServerRegion)

local ServerInfoService = {}

function ServerInfoService.start()
	ServerRegion.start()
end

return ServerInfoService
