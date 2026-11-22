--!strict
-- Lobby place server entry. Same two-phase bootstrap as the match server:
-- init() every service in ./Services, then start() each in its own thread.
-- In a Match server (a reserved match server of this place, shared/ServerRole)
-- only the player's saved data runs (wallet, settings, Locker skins); the
-- queue, shop, parties and range are lobby-only.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerRole = require(ReplicatedStorage.Shared.ServerRole)

local MATCH_SERVICES: { [string]: boolean } = {
	LockerService = true,
	PlayerDataService = true,
	ProgressionService = true,
	SettingsService = true,
}

local role = ServerRole.get()
local Services = script:FindFirstChild("Services")

local loaded: { [string]: any } = {}
if Services then
	for _, child in Services:GetChildren() do
		if child:IsA("ModuleScript") and (role == "Lobby" or MATCH_SERVICES[child.Name]) then
			loaded[child.Name] = require(child) :: any
		end
	end
end

for _, service in loaded do
	if typeof(service.init) == "function" then
		service.init()
	end
end

for _, service in loaded do
	if typeof(service.start) == "function" then
		task.spawn(service.start)
	end
end

print(`[Lobby] server ready ({role})`)
