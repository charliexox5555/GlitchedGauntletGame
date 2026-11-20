--!strict
-- The test mode switch. When it's on, the server runs the test range: every
-- player spawns there and gets the tester tools (loadout picker, ammo refill,
-- dummy controls, stats).
--
-- In Studio, the Workspace TestMode checkbox is read when Play starts.
-- The server publishes its decision so clients read the same answer.

local StateValues = require(game:GetService("ReplicatedStorage").Shared.StateValues)

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Dev = require(script.Parent.Config.Dev)

local FIELD = "TestMode"

local TestMode = {}

-- Server only: decides whether this server is a test range and publishes it.
function TestMode.resolve(): boolean
	assert(RunService:IsServer(), "TestMode.resolve is server-only")
	local on = false
	if RunService:IsStudio() then
		local value = Workspace:GetAttribute(FIELD)
		on = if typeof(value) == "boolean" then value else Dev.TEST_RANGE
	end
	StateValues.set(Workspace, FIELD, on)
	return on
end

-- Both sides. On the server this is only meaningful after resolve() (the
-- test range service calls it in init()).
function TestMode.isOn(): boolean
	return StateValues.get(Workspace, FIELD) == true
end

return TestMode
