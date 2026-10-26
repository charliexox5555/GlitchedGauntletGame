--!strict
-- The test mode switch. When it's on, the server runs the test range: every
-- player spawns there and gets the tester tools (loadout picker, ammo refill,
-- dummy controls, stats).
--
-- The switch is the Workspace attribute "TestMode" (a checkbox in Studio:
-- Workspace → Properties → Attributes), saved with the place, so it can be
-- flipped before publishing without touching code. When the attribute is
-- missing, Studio playtests fall back to Config/Dev TEST_RANGE and live
-- servers stay off. At start the server writes the value it decided on back
-- to the attribute, so clients read the same answer.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Dev = require(script.Parent.Config.Dev)

local ATTRIBUTE = "TestMode"

local TestMode = {}

TestMode.ATTRIBUTE = ATTRIBUTE

-- Server only: decides whether this server is a test range and publishes it.
function TestMode.resolve(): boolean
	assert(RunService:IsServer(), "TestMode.resolve is server-only")
	local value = Workspace:GetAttribute(ATTRIBUTE)
	local on = if typeof(value) == "boolean"
		then value
		else RunService:IsStudio() and Dev.TEST_RANGE
	Workspace:SetAttribute(ATTRIBUTE, on)
	return on
end

-- Both sides. On the server this is only meaningful after resolve() (the
-- test range service calls it in init()).
function TestMode.isOn(): boolean
	return Workspace:GetAttribute(ATTRIBUTE) == true
end

return TestMode
