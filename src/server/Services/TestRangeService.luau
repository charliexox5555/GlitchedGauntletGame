--!strict
-- The test range, for testers in a published place (vault/04 Tech/
-- Architecture.md → Test range). Runs only while test mode is on
-- (shared/TestMode): builds the plain practice range (TestRange/RangeBuilder),
-- spawns every player there and runs the dummies (TestRange/Dummies). It has
-- no remotes: dummies are shot through the normal WeaponService validation.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TestMode = require(ReplicatedStorage.Shared.TestMode)
local TestRange = require(ReplicatedStorage.Shared.Config.TestRange)

local TestRangeFolder = script.Parent.Parent.TestRange
local Dummies = require(TestRangeFolder.Dummies)
local RangeBuilder = require(TestRangeFolder.RangeBuilder)

local TestRangeService = {}

local enabled = false
local behaviours: { [string]: boolean } = {}

function TestRangeService.init()
	enabled = TestMode.resolve()
	if not enabled then
		return
	end
	for _, b in TestRange.BEHAVIOURS do
		behaviours[b.id] = b.default
	end
end

function TestRangeService.start()
	if not enabled then
		return
	end
	local built = RangeBuilder.build()
	-- Everyone spawns in the range: other spawns are switched off.
	for _, d in workspace:GetDescendants() do
		if d:IsA("SpawnLocation") and d ~= built.spawn then
			d.Enabled = false
		end
	end

	local oldDummies = workspace:FindFirstChild("Dummies")
	if oldDummies then
		oldDummies:Destroy()
	end
	-- WeaponService's wall checks skip workspace.Dummies (bodies aren't walls).
	local dummies = Instance.new("Folder")
	dummies.Name = "Dummies"
	dummies.Parent = workspace
	Dummies.start(dummies, built.toWorld, function(id: string): boolean
		return behaviours[id] == true
	end)

	-- Anyone who spawned before the range existed respawns in it.
	for _, player in Players:GetPlayers() do
		if player.Character then
			player:LoadCharacter()
		end
	end
	print("[TestRange] test mode is ON: range built, dummies spawned")
end

return TestRangeService
