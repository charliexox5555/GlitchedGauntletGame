--!strict
-- GlitchedGauntletGame server entry point. Two-phase bootstrap: init() every
-- service, then start() every service, so services can reference each other
-- during init without ordering problems.
--
-- One place, two roles (shared/ServerRole, vault/04 Tech/Place Merge Plan.md).
-- Only the shared, per-player services start here (health, characters,
-- weapons, movement ...). The match flow (MatchService, DraftService, the
-- Mods, bots ...) runs per match: MatchHost starts one whole-server match in a
-- Match server, and pad duels in a Lobby server, each in its own copy
-- (MatchKit/MatchRunner).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerRole = require(ReplicatedStorage.Shared.ServerRole)

local SHARED_SERVICES: { [string]: boolean } = {
	CharacterService = true,
	DeviceService = true,
	HealthService = true,
	HitboxHistory = true,
	InputContextService = true,
	LookStream = true,
	MatchHost = true,
	ModEntities = true,
	MovementService = true,
	SkinPreviewService = true,
	ServerInfoService = true,
	StatusService = true,
	WeaponService = true,
}

local role = ServerRole.get()
local Services = script:FindFirstChild("Services")

local loaded: { [string]: any } = {}
if Services then
	for _, child in Services:GetChildren() do
		if child:IsA("ModuleScript") and SHARED_SERVICES[child.Name] then
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
