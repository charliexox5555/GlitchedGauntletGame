--!strict
-- Lobby place server entry. Same two-phase bootstrap as the match server:
-- init() every service in ./Services, then start() each in its own thread.

local Services = script:FindFirstChild("Services")

local loaded: { [string]: any } = {}
if Services then
	for _, child in Services:GetChildren() do
		if child:IsA("ModuleScript") then
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

print("[Lobby] server ready")
