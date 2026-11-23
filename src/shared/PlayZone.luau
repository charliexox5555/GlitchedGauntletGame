--!strict
-- Where a player is playing (vault/04 Tech/Place Merge Plan.md):
--  * "Lobby": walking the lobby with their own avatar, no guns.
--  * "Range": in the lobby's shooting range with the match body and their
--    Locker loadout (no damage between players).
--  * "Match": in a match (the whole server in the Match role; a pad duel in
--    the Lobby role, with `MatchId` naming it).
-- The server owns it as the Player attributes `PlayZone` and `MatchId`;
-- clients only read them. In the Match role everyone is "Match".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ServerRole = require(ReplicatedStorage.Shared.ServerRole)

export type Zone = "Lobby" | "Range" | "Match"

local PlayZone = {}

PlayZone.ATTRIBUTE = "PlayZone"
PlayZone.MATCH_ID = "MatchId"

local changed = Instance.new("BindableEvent")
-- (player, zone, previous) on the server whenever set() changes a zone.
PlayZone.changed = changed.Event

local function read(player: Player): Zone
	local value = player:GetAttribute(PlayZone.ATTRIBUTE)
	if value == "Range" or value == "Match" or value == "Lobby" then
		return value
	end
	-- Not set yet: what this server starts everyone as.
	return if ServerRole.isMatch() then "Match" else "Lobby"
end

function PlayZone.get(player: Player): Zone
	return read(player)
end

-- Whether this player fights (has the match body and guns): Range or Match.
function PlayZone.isArmed(player: Player): boolean
	return read(player) ~= "Lobby"
end

function PlayZone.matchId(player: Player): string?
	local id = player:GetAttribute(PlayZone.MATCH_ID)
	return if typeof(id) == "string" then id else nil
end

-- The camera each zone plays with (the match place's StarterPlayer used to
-- set it for everyone: first person, no zoom). Server-set Player properties.
local function applyCamera(player: Player, zone: Zone)
	if zone == "Lobby" then
		player.CameraMode = Enum.CameraMode.Classic
		player.CameraMinZoomDistance = 0.5
		player.CameraMaxZoomDistance = 128
	else
		player.CameraMode = Enum.CameraMode.LockFirstPerson
		player.CameraMinZoomDistance = 0.5
		player.CameraMaxZoomDistance = 0.5
	end
end

-- Server only.
function PlayZone.set(player: Player, zone: Zone, matchId: string?)
	assert(RunService:IsServer(), "PlayZone.set is server only")
	local previous = read(player)
	applyCamera(player, zone)
	player:SetAttribute(PlayZone.MATCH_ID, if zone == "Match" then matchId else nil)
	player:SetAttribute(PlayZone.ATTRIBUTE, zone)
	if previous ~= zone then
		changed:Fire(player, zone, previous)
	end
end

-- Client: fires with the new zone whenever the local player's zone changes.
function PlayZone.onLocalChanged(fn: (Zone) -> ()): RBXScriptConnection
	local player = Players.LocalPlayer
	return player:GetAttributeChangedSignal(PlayZone.ATTRIBUTE):Connect(function()
		fn(read(player))
	end)
end

if RunService:IsServer() then
	local function stamp(player: Player)
		if player:GetAttribute(PlayZone.ATTRIBUTE) == nil then
			local zone = read(player)
			applyCamera(player, zone)
			player:SetAttribute(PlayZone.ATTRIBUTE, zone)
		end
	end
	Players.PlayerAdded:Connect(stamp)
	for _, p in Players:GetPlayers() do
		stamp(p)
	end
end

return PlayZone
