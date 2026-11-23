--!strict
-- "To Hub" (owner 2026-11-23): in a hosted server (a queued match's reserved server, Shared/ServerRole.isHosted)
-- players stay in its lobby after the match; the To Hub button (left of PLAY, Util/LobbyHudView) sends one to a
-- full public server of this place instead.
--
-- HubRequest (client -> server): no arguments. Only in a hosted server, only from the lobby (not in a match,
-- not while searching: the search is cancelled first by the client). Rate-limited; a teleport that throws is
-- reported back on QueueEvent ("failed").

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local LobbyNet = require(ReplicatedStorage.Lobby.LobbyNet)
local PlayZone = require(ReplicatedStorage.Shared.PlayZone)
local RateLimit = require(ReplicatedStorage.Shared.Util.RateLimit)
local ServerRole = require(ReplicatedStorage.Shared.ServerRole)
local StateValues = require(ReplicatedStorage.Shared.StateValues)

local HubService = {}

local limiter = RateLimit.new({ HubRequest = { 0.2, 2 } })
local going: { [Player]: number } = {} -- os.clock() of a teleport in flight
local IN_FLIGHT = 20

local function fail(player: Player, text: string)
	LobbyNet.event("QueueEvent"):FireClient(player, { kind = "failed", text = text })
end

local function onRequest(player: Player)
	if not limiter:allow(player, "HubRequest") then
		return
	end
	if not ServerRole.isHosted() or PlayZone.get(player) ~= "Lobby" then
		return
	end
	local status = StateValues.get(player, "QueueStatus")
	if status ~= nil and status ~= "idle" then
		fail(player, "Cancel your search first")
		return
	end
	if going[player] and os.clock() - going[player] < IN_FLIGHT then
		return
	end
	going[player] = os.clock()
	if RunService:IsStudio() then
		print(`[Hub] STUDIO: would send {player.Name} to a public server`)
		going[player] = nil
		return
	end
	-- No reserved code and no server id: Roblox picks a public server of this place.
	local ok, err = pcall(TeleportService.TeleportAsync, TeleportService, game.PlaceId, { player })
	if not ok then
		going[player] = nil
		warn(`[Hub] teleport for {player.Name} threw: {err}`)
		fail(player, "Couldn't reach the hub, try again")
	end
end

function HubService.init() end

function HubService.start()
	LobbyNet.event("HubRequest").OnServerEvent:Connect(onRequest)
	TeleportService.TeleportInitFailed:Connect(function(player: Player, _result, message: string)
		if going[player] then
			going[player] = nil
			fail(player, "Couldn't reach the hub, try again")
			warn(`[Hub] teleport failed for {player.Name}: {message}`)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		going[player] = nil
		limiter:forget(player)
	end)
end

return HubService
