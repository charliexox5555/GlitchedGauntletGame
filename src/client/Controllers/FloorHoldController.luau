--!strict
-- Floor hold (owner 2026-11-22: "the player would just be in a void and the game would start but just every
-- round ends right away in a draw"). A match map is sent to each client on its own schedule; a fighter spawned
-- before it arrived fell through the void, died below the map's kill depth, and the round started with that
-- side empty (MatchService counts it as a draw). Right after each spawn this checks for floor under the
-- character; while there is none it holds the root still (anchored on this client, which owns its movement)
-- and asks Roblox to stream that spot, then lets go as soon as floor appears, or after FLOOR_HOLD.max seconds.
-- Only the first moments after a spawn: a jump over a gap mid-round is never held.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Match)

local FloorHoldController = {}

local HOLD = Config.FLOOR_HOLD
local player = Players.LocalPlayer

local function hold(character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not (root and root:IsA("BasePart")) then
		return
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local function floor(): boolean
		return workspace:Raycast(root.Position, Vector3.new(0, -HOLD.probe, 0), params) ~= nil
	end
	if floor() then
		return
	end
	local anchoredHere = false
	if not root.Anchored then
		root.Anchored = true
		anchoredHere = true
	end
	task.spawn(function()
		pcall(function()
			player:RequestStreamAroundAsync(root.Position, HOLD.max)
		end)
	end)
	local started = os.clock()
	while character.Parent and root.Parent and not floor() and os.clock() - started < HOLD.max do
		task.wait(HOLD.check)
	end
	if anchoredHere and root.Parent then
		root.Anchored = false
	end
	if os.clock() - started >= HOLD.max then
		warn(string.format("[Health] C floor hold: no floor after %ds, let go", HOLD.max))
	end
end

function FloorHoldController.start()
	player.CharacterAdded:Connect(function(character)
		task.spawn(hold, character)
	end)
	if player.Character then
		task.spawn(hold, player.Character)
	end
end

return FloorHoldController
