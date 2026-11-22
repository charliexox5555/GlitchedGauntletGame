--!strict
-- GlitchedGauntletGame server entry point. Two-phase bootstrap: init() every
-- service, then start() every service, so services can reference each other
-- during init without ordering problems.
--
-- One place, two roles (shared/ServerRole, vault/04 Tech/Place Merge Plan.md):
--  * Match (a reserved match server, or the retired match place): every
--    service runs, as before.
--  * Lobby (a public server): only the per-player services run (health,
--    characters, weapons, movement ...), for the range and for players in a
--    pad duel. The match flow itself sleeps until pad duels run it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerRole = require(ReplicatedStorage.Shared.ServerRole)

-- The services that run in a Lobby server too: everything kept per player or
-- per character, nothing that runs the match flow.
local LOBBY_SERVICES: { [string]: boolean } = {
	CharacterService = true,
	DeviceService = true,
	HealthService = true,
	HitboxHistory = true,
	InputContextService = true,
	LookStream = true,
	ModEntities = true,
	MovementService = true,
	SkinPreviewService = true,
	StatusService = true,
	WeaponService = true,
}

local role = ServerRole.get()
local Services = script:FindFirstChild("Services")

local loaded: { [string]: any } = {}
if Services then
	for _, child in Services:GetChildren() do
		if child:IsA("ModuleScript") and (role == "Match" or LOBBY_SERVICES[child.Name]) then
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

print(`[GlitchedGauntletGame] server started ({role})`)
