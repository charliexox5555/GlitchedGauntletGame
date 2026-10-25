--!strict
-- GlitchedGauntletGame server entry point. Two-phase bootstrap: init() every
-- service, then start() every service, so services can reference each other
-- during init without ordering problems.

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

print("[GlitchedGauntletGame] server started")
