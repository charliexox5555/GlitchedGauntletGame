--!strict
-- What this server is (vault/04 Tech/Place Merge Plan.md). The Lobby and the
-- match are one place now (the Lobby place, 71551303511506):
--  * "Lobby": a public server. Lobby world and UI, the range, pad duels.
--  * "Match": one whole-server match (the old reserved-server role). Since 2026-11-23 only the Studio
--    test uses it: reserved servers are Lobby servers that host their queued match (isHosted below).
-- Studio: set the Workspace attribute `ServerRole` to "Match" to test the
-- whole-server match role in the Lobby place (Studio only, so a value left in the saved
-- place can't change live servers).
-- The server decides once and publishes it as the ReplicatedStorage attribute
-- `ServerRole`; clients read that.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

export type Role = "Lobby" | "Match"

local ServerRole = {}

ServerRole.ATTRIBUTE = "ServerRole"
ServerRole.LOBBY_PLACE_ID = 71551303511506
ServerRole.LEGACY_MATCH_PLACE_ID = 133387545285290 -- retired 2026-11-21 (archived); Config/SkinPreview still lists it

-- Hosted (owner 2026-11-23: "the big point of the merge is that it actually will send you to the lobby in that
-- match server"): a reserved server made for a queued match is a Lobby server that hosts that match as an instance
-- (Services/MatchHost, like a pad duel). After the match its players stay here in the lobby (duels area caged,
-- queue from the menu, "To Hub" for a public server). Studio: Workspace attribute `HostedTest` = a mode ("2v2")
-- runs a hosted match for the first player with bots. Clients read the ReplicatedStorage attribute.
ServerRole.HOSTED_ATTRIBUTE = "HostedServer"
ServerRole.HOSTED_TEST = "HostedTest"

local cached: Role? = nil

local function decide(): Role
	if RunService:IsStudio() then
		local forced = workspace:GetAttribute(ServerRole.ATTRIBUTE)
		if forced == "Match" or forced == "Lobby" then
			return forced
		end
	end
	-- a reserved server (a queued match) is a Lobby server hosting that match (isHosted)
	return "Lobby"
end

local hostedCached: boolean? = nil

-- This server was reserved for a queued match (a Lobby server hosting it; see above).
function ServerRole.isHosted(): boolean
	if hostedCached ~= nil then
		return hostedCached
	end
	if RunService:IsServer() then
		local reserved = game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
		local studio = RunService:IsStudio()
			and typeof(workspace:GetAttribute(ServerRole.HOSTED_TEST)) == "string"
		hostedCached = (reserved or studio) and ServerRole.get() == "Lobby"
		ReplicatedStorage:SetAttribute(ServerRole.HOSTED_ATTRIBUTE, hostedCached)
		return hostedCached :: boolean
	end
	local value = ReplicatedStorage:GetAttribute(ServerRole.HOSTED_ATTRIBUTE)
	while value == nil do
		ReplicatedStorage:GetAttributeChangedSignal(ServerRole.HOSTED_ATTRIBUTE):Wait()
		value = ReplicatedStorage:GetAttribute(ServerRole.HOSTED_ATTRIBUTE)
	end
	hostedCached = value == true
	return hostedCached :: boolean
end

function ServerRole.get(): Role
	if cached then
		return cached
	end
	if RunService:IsServer() then
		cached = decide()
		ReplicatedStorage:SetAttribute(ServerRole.ATTRIBUTE, cached)
		task.defer(ServerRole.isHosted) -- publish the hosted flag too
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
