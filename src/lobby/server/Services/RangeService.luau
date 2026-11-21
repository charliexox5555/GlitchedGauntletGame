--!strict
-- RangeService: the way into and out of the lobby's shooting range (owner 2026-11-21: "a smaller hologram ... where
-- you touch it and enter the range ... the actual range is built further away").
-- Parts tagged `RangeEntry` (the hologram in the hub's sim bay) send a player's character to one of the parts tagged
-- `RangeSpawn` (the range's spawn deck); parts tagged `RangeExit` (the exit hologram there) send it back to the part
-- tagged `RangeReturn` (in front of the hub hologram). Server only: no remotes, the server decides on touch.
-- Built by tools/studio/lobby_v5/BuildRangeV2.luau.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local RangeService = {}

local COOLDOWN = 1.5 -- seconds between two trips for one player
local SPREAD = 3 -- studs of random spread around a spawn point, so a crowd doesn't stack

local lastTrip: { [Player]: number } = {}
local connections: { [Instance]: RBXScriptConnection } = {}

local function pick(tag: string): BasePart?
	local list = {}
	for _, inst in CollectionService:GetTagged(tag) do
		if inst:IsA("BasePart") and inst:IsDescendantOf(workspace) then
			table.insert(list, inst)
		end
	end
	if #list == 0 then
		return nil
	end
	return list[math.random(1, #list)]
end

local function playerFromHit(hit: BasePart): (Player?, Model?)
	local model = hit:FindFirstAncestorOfClass("Model")
	while model and not model:FindFirstChildOfClass("Humanoid") do
		model = model:FindFirstAncestorOfClass("Model")
	end
	if not model then
		return nil, nil
	end
	local player = Players:GetPlayerFromCharacter(model)
	if not player then
		return nil, nil
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil, nil
	end
	return player, model
end

local function send(player: Player, character: Model, targetTag: string)
	local now = os.clock()
	if now - (lastTrip[player] or 0) < COOLDOWN then
		return
	end
	local target = pick(targetTag)
	if not target then
		return
	end
	lastTrip[player] = now
	local offset =
		Vector3.new((math.random() - 0.5) * 2 * SPREAD, 0, (math.random() - 0.5) * 2 * SPREAD)
	local look = target.CFrame.LookVector
	local pos = target.Position + offset
	task.spawn(function()
		pcall(function()
			player:RequestStreamAroundAsync(pos, 5)
		end)
		if character.Parent then
			character:PivotTo(CFrame.lookAt(pos, pos + Vector3.new(look.X, 0, look.Z)))
		end
	end)
end

local function hook(part: Instance, targetTag: string)
	if not part:IsA("BasePart") or connections[part] then
		return
	end
	connections[part] = part.Touched:Connect(function(hit: BasePart)
		local player, character = playerFromHit(hit)
		if player and character then
			send(player, character, targetTag)
		end
	end)
end

local function unhook(part: Instance)
	local c = connections[part]
	if c then
		c:Disconnect()
		connections[part] = nil
	end
end

function RangeService.start()
	for tag, target in { RangeEntry = "RangeSpawn", RangeExit = "RangeReturn" } do
		for _, part in CollectionService:GetTagged(tag) do
			hook(part, target)
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(function(part)
			hook(part, target)
		end)
		CollectionService:GetInstanceRemovedSignal(tag):Connect(unhook)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastTrip[player] = nil
	end)
end

return RangeService
