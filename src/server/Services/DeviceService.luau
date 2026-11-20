--!strict
-- What each player plays on, for the device marks (Config/PlayerTags; vault/02
-- Art/UI Match Overhaul.md). The client reports it with the Device remote
-- (Controllers/DeviceController); the server checks it is one of the known
-- devices and sets the Player attribute "Device". It is a label only:
-- nothing in the game trusts it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateValues = require(ReplicatedStorage.Shared.StateValues)

local Net = require(ReplicatedStorage.Shared.Net)
local PlayerTags = require(ReplicatedStorage.Shared.Config.PlayerTags)
local RateLimit = require(ReplicatedStorage.Shared.Util.RateLimit)
local Validate = require(ReplicatedStorage.Shared.Util.Validate)

local DeviceService = {}

local limiter = RateLimit.new({ Device = PlayerTags.RATE })

local function onDevice(player: Player, value: unknown)
	if not limiter:allow(player, "Device") then
		return
	end
	local device = Validate.enum(value, PlayerTags.DEVICES :: any)
	if device then
		StateValues.set(player, "Device", device)
	end
end

function DeviceService.start()
	Net.event("Device").OnServerEvent:Connect(onDevice)
	Players.PlayerRemoving:Connect(function(player)
		limiter:forget(player)
	end)
end

return DeviceService
