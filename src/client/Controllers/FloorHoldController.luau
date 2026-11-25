--!strict
-- Floor hold (owner 2026-11-22: "the player would just be in a void and the game would start but just every
-- round ends right away in a draw"). A match map is sent to each client on its own schedule; a fighter spawned
-- before it arrived fell through the void, died below the map's kill depth, and the round started with that
-- side empty (MatchService counts it as a draw). Right after each spawn this checks for floor under the
-- character; while there is none it holds the root still (anchored on this client, which owns its movement)
-- and asks Roblox to stream that spot, then lets go as soon as floor appears, or after FLOOR_HOLD.max seconds.
-- Only the first moments after a spawn: a jump over a gap mid-round is never held.
-- Once the fighter is on this screen with floor under it (or the hold gave up), it tells the server (BodyReady),
-- which keeps the round's barrier up until every player's has (owner 2026-11-25: "camera in the void, spectate
-- the other bots for a second, and then finally load in"; Config/Match BODY_READY_WAIT).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Match)
local Net = require(ReplicatedStorage.Shared.Net)
local PlayZone = require(ReplicatedStorage.Shared.PlayZone)

local FloorHoldController = {}

local HOLD = Config.FLOOR_HOLD
local player = Players.LocalPlayer
local tokens: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any

-- This screen has `character` at `targetPos` (the ArenaSpawn it waited for; the server checks it's the current one).
local function ready(character: Model, targetPos: Vector3?)
	if player.Character == character and character.Parent and PlayZone.get(player) == "Match" then
		Net.event("BodyReady"):FireServer(character, targetPos)
	end
end

local function hold(character: Model, targetPos: Vector3?)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not (root and root:IsA("BasePart")) then
		return
	end
	local my = (tokens[character] or 0) + 1
	tokens[character] = my
	if targetPos and (root.Position - targetPos).Magnitude > 25 then
		local movedDeadline = os.clock() + 2
		while
			tokens[character] == my
			and character.Parent
			and root.Parent
			and (root.Position - targetPos).Magnitude > 25
			and os.clock() < movedDeadline
		do
			task.wait(0.05)
		end
	end
	if tokens[character] ~= my or not character.Parent or not root.Parent then
		return
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	params.FilterDescendantsInstances = { character }
	local function floor(): boolean
		return workspace:Raycast(root.Position, Vector3.new(0, -HOLD.probe, 0), params) ~= nil
	end
	if floor() then
		ready(character, targetPos)
		return
	end
	local anchoredHere = false
	if not root.Anchored then
		root.Anchored = true
		anchoredHere = true
	end
	root.AssemblyLinearVelocity = Vector3.zero
	task.spawn(function()
		pcall(function()
			player:RequestStreamAroundAsync(targetPos or root.Position, HOLD.max)
		end)
	end)
	local started = os.clock()
	while
		tokens[character] == my
		and character.Parent
		and root.Parent
		and not floor()
		and os.clock() - started < HOLD.max
	do
		task.wait(HOLD.check)
	end
	if tokens[character] == my and anchoredHere and root.Parent then
		root.AssemblyLinearVelocity = Vector3.zero
		root.Anchored = false
	end
	if tokens[character] == my and os.clock() - started >= HOLD.max then
		warn(string.format("[Health] C floor hold: no floor after %ds, let go", HOLD.max))
	end
	if tokens[character] == my then
		ready(character, targetPos)
	end
end

local function watchCharacter(character: Model)
	local initial = character:GetAttribute("ArenaSpawn")
	task.spawn(hold, character, if typeof(initial) == "Vector3" then initial else nil)
	character:GetAttributeChangedSignal("ArenaSpawn"):Connect(function()
		local pos = character:GetAttribute("ArenaSpawn")
		if typeof(pos) == "Vector3" then
			task.spawn(hold, character, pos)
		end
	end)
end

function FloorHoldController.start()
	player.CharacterAdded:Connect(watchCharacter)
	if player.Character then
		watchCharacter(player.Character)
	end
end

return FloorHoldController
