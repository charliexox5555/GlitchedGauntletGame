--!strict
-- Lobby place server entry. Same two-phase bootstrap as the match server:
-- init() every service in ./Services, then start() each in its own thread.
-- In a Match server (a reserved match server of this place, shared/ServerRole)
-- only the player's saved data runs (wallet, settings, Locker skins); the
-- queue, shop, parties and range are lobby-only.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerRole = require(ReplicatedStorage.Shared.ServerRole)

local MATCH_SERVICES: { [string]: boolean } = {
	AdminService = true,
	LockerService = true,
	OnboardingService = true, -- the second favorite ask is during match 2
	PlayerDataService = true,
	ProgressionService = true,
	SettingsService = true,
}

local role = ServerRole.get()
local Services = script:FindFirstChild("Services")

-- Boot timing (owner 2026-11-22: "stuck on LOADING YOUR DATA"): a player who joins a fresh
-- server waits for this whole boot before their save even starts loading, so any require or
-- init slower than SLOW_STEP is named in the F9 Server log.
local SLOW_STEP = 0.2
local bootStart = os.clock()
local slow: { string } = {}
-- Each require / init runs protected: one broken service is logged and skipped, and the rest
-- (PlayerDataService above all) still start.
local function timed(label: string, fn: () -> ())
	local t = os.clock()
	local ok, err = pcall(fn)
	if not ok then
		warn(`[Health] S boot: {label} failed: {err}`)
	end
	local took = os.clock() - t
	if took >= SLOW_STEP then
		table.insert(slow, string.format("%s %.2fs", label, took))
	end
end

local loaded: { [string]: any } = {}
if Services then
	for _, child in Services:GetChildren() do
		if child:IsA("ModuleScript") and (role == "Lobby" or MATCH_SERVICES[child.Name]) then
			timed("require " .. child.Name, function()
				loaded[child.Name] = require(child) :: any
			end)
		end
	end
end

for name, service in loaded do
	if typeof(service.init) == "function" then
		timed("init " .. name, service.init)
	end
end

for _, service in loaded do
	if typeof(service.start) == "function" then
		task.spawn(service.start)
	end
end

print(
	string.format(
		"[Health] S lobby boot %.2fs%s",
		os.clock() - bootStart,
		if #slow > 0 then " (slow: " .. table.concat(slow, ", ") .. ")" else ""
	)
)
print(`[Lobby] server ready ({role})`)
