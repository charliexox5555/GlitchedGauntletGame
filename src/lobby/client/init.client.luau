--!strict
-- Lobby place client entry. Same two-phase bootstrap as the match client:
-- init() every controller in ./Controllers, then start() each in its own thread.

-- In a Match server (shared/ServerRole) the lobby UI doesn't run at all: the
-- match client (StarterPlayerScripts.Client) has the screen.
local ServerRole =
	require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("ServerRole"))
if ServerRole.isMatch() then
	-- StarterGui still copies the lobby's screens to everyone: keep them off.
	local StarterGui = game:GetService("StarterGui")
	local playerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
	local function off(gui: Instance)
		if gui:IsA("ScreenGui") and StarterGui:FindFirstChild(gui.Name) then
			gui.Enabled = false
		end
	end
	for _, gui in playerGui:GetChildren() do
		off(gui)
	end
	playerGui.ChildAdded:Connect(off)
	return
end

-- the chunky cell look on every screen + re-measured self-sizing text
-- (first, so templates are marked before any controller clones them)
local LobbyLook = require(script.Util.LobbyLook)
local player = game:GetService("Players").LocalPlayer
LobbyLook.apply(player:WaitForChild("PlayerGui"))

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

print("[Lobby] client ready")
