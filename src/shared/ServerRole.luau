--!strict
-- What this server is (vault/04 Tech/Place Merge Plan.md). The Lobby and the
-- match are one place now (the Lobby place, 71551303511506):
--  * "Lobby": a public server. Lobby world and UI, the range, pad duels.
--  * "Match": a reserved server of the same place holding one queued match
--    (PrivateServerId set, no owner). The retired match place
--    (133387545285290) also counts as "Match", so it keeps working as before.
-- Studio: set the Workspace attribute `ServerRole` to "Match" to test the
-- match role in the Lobby place (Studio only, so a value left in the saved
-- place can't change live servers).
-- The server decides once and publishes it as the ReplicatedStorage attribute
-- `ServerRole`; clients read that.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

export type Role = "Lobby" | "Match"

local ServerRole = {}

ServerRole.ATTRIBUTE = "ServerRole"
ServerRole.LOBBY_PLACE_ID = 71551303511506
ServerRole.LEGACY_MATCH_PLACE_ID = 133387545285290

local cached: Role? = nil

local function decide(): Role
	if RunService:IsStudio() then
		local forced = workspace:GetAttribute(ServerRole.ATTRIBUTE)
		if forced == "Match" or forced == "Lobby" then
			return forced
		end
	end
	if game.PlaceId == ServerRole.LEGACY_MATCH_PLACE_ID then
		return "Match"
	end
	if game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0 then
		return "Match"
	end
	-- The legacy match place in Studio has no PlaceId check issue; an unsaved
	-- file with match code only (no lobby) also plays as a match.
	if RunService:IsStudio() and game.PlaceId ~= ServerRole.LOBBY_PLACE_ID then
		local sss = game:GetService("ServerScriptService")
		if sss:FindFirstChild("Server") and not sss:FindFirstChild("LobbyServer") then
			return "Match"
		end
	end
	return "Lobby"
end

function ServerRole.get(): Role
	if cached then
		return cached
	end
	if RunService:IsServer() then
		cached = decide()
		ReplicatedStorage:SetAttribute(ServerRole.ATTRIBUTE, cached)
		return cached :: Role
	end
	local value = ReplicatedStorage:GetAttribute(ServerRole.ATTRIBUTE)
	while value == nil do
		ReplicatedStorage:GetAttributeChangedSignal(ServerRole.ATTRIBUTE):Wait()
		value = ReplicatedStorage:GetAttribute(ServerRole.ATTRIBUTE)
	end
	cached = if value == "Match" then "Match" else "Lobby"
	return cached :: Role
end

function ServerRole.isMatch(): boolean
	return ServerRole.get() == "Match"
end

function ServerRole.isLobby(): boolean
	return ServerRole.get() == "Lobby"
end

return ServerRole
