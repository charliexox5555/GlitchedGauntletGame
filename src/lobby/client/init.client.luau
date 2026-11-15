--!strict
-- Lobby place client entry. Same two-phase bootstrap as the match client:
-- init() every controller in ./Controllers, then start() each in its own thread.

local Controllers = script:FindFirstChild("Controllers")

local loaded: { [string]: any } = {}
if Controllers then
	for _, child in Controllers:GetChildren() do
		if child:IsA("ModuleScript") then
			loaded[child.Name] = require(child) :: any
		end
	end
end

for _, controller in loaded do
	if typeof(controller.init) == "function" then
		controller.init()
	end
end

for _, controller in loaded do
	if typeof(controller.start) == "function" then
		task.spawn(controller.start)
	end
end

-- self-sizing text measured before its font loaded gets measured again
local TextFit = require(script.Util.TextFit)
local player = game:GetService("Players").LocalPlayer
TextFit.settle(player:WaitForChild("PlayerGui"))

print("[Lobby] client ready")
