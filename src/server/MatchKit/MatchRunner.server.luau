--!strict
-- Runs one match (place merge 2026-11-21, vault/04 Tech/Place Merge Plan.md). This script is a template: MatchHost
-- clones it per match with the `MatchRunnerId` attribute set and parents the copy to ServerScriptService. The copy
-- builds the match's own kit (fresh copies of the match-flow services, the bots, MatchState, Zone and Context),
-- binds it to the match, then runs the usual init() / start() of every service. Destroying the copy (MatchHost,
-- when the match ends) stops every thread and connection it started.

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local runnerId = script:GetAttribute("MatchRunnerId")
if typeof(runnerId) ~= "string" then
	return -- the template itself
end

local Server = ServerScriptService:WaitForChild("Server")
local MatchHost = require(Server:WaitForChild("Services"):WaitForChild("MatchHost") :: ModuleScript)
local spec = MatchHost.takeSpec(runnerId)
if not spec then
	warn(`[MatchRunner] no spec for {runnerId}`)
	return
end

local Shared = ReplicatedStorage:WaitForChild("Shared")
local kitTemplates = Server:WaitForChild("MatchKit")

local kit = Instance.new("Folder")
kit.Name = "Kit"
kitTemplates:WaitForChild("Context"):Clone().Parent = kit
Shared:WaitForChild("MatchState"):Clone().Parent = kit
Shared:WaitForChild("Zone"):Clone().Parent = kit
local services = Instance.new("Folder")
services.Name = "Services"
services.Parent = kit
for _, name in MatchHost.KIT_SERVICES do
	local source = Server.Services:FindFirstChild(name)
	if source then
		source:Clone().Parent = services
	end
end
Server:WaitForChild("Bots"):Clone().Parent = kit
local testRange = Server:FindFirstChild("TestRange")
if testRange then
	testRange:Clone().Parent = kit
end
kit.Parent = script

local Context = require(kit:WaitForChild("Context") :: ModuleScript) :: any
Context.setup(spec.context)
local MatchState = require(kit:WaitForChild("MatchState") :: ModuleScript) :: any
MatchState.bind(spec.stateFolder)

-- A practice context (the range) runs only some services (MatchHost PRACTICE_SERVICES).
local only: { string }? = spec.only
local loaded: { [string]: any } = {}
for _, child in services:GetChildren() do
	if child:IsA("ModuleScript") and (only == nil or table.find(only, child.Name) ~= nil) then
		loaded[child.Name] = require(child) :: any
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
MatchHost.started(runnerId, Context, loaded.ModService and loaded.ModService.removePlayer)
print(
	`[MatchRunner] match {runnerId} running ({if spec.context.ownsServer
		then "whole server"
		elseif only then "practice"
		else "pad duel"})`
)
