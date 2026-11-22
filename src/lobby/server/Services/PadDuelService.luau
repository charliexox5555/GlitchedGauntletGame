--!strict
-- Duel pads (place merge 2026-11-21, vault/04 Tech/Place Merge Plan.md): "the duel pads in the main lobby now
-- create the duel in that server". Each LobbyV5 queue bay has one pad (its `LobbyQueue`-tagged QueueZone) split
-- in two halves (Square_A / Square_B): the halves are the two teams. When both halves hold teamSize real players
-- from this server (no bots, owner's pick) the pad counts down (Config.PAD.countdown) and MatchHost starts the duel
-- right here, far from the lobby; several pads can run duels at once. Someone stepping off stops the count.
-- The mode comes from the pad's `Mode` attribute or its bay's name (Bay_05_1v1).
-- Server only: no remotes. Clients draw the pad's state from the pad model's attributes (PadDuelController):
--   PadMode, PadNeed (players per side), PadA / PadB (on each half), PadStartsAt (server time, 0 = not counting).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Lobby.Config)
local Health = require(ReplicatedStorage.Shared.Health)
local PlayZone = require(ReplicatedStorage.Shared.PlayZone)
local StateValues = require(ReplicatedStorage.Shared.StateValues)

local PadDuelService = {}

local TAG = "LobbyQueue"
local ROOT = "LobbyV5" -- only the real lobby's pads (the older lobbies stay in the place, unused)

type Pad = {
	zone: BasePart,
	model: Instance,
	mode: string,
	teamSize: number,
	squareA: BasePart?,
	squareB: BasePart?,
	countFrom: number?, -- os.clock() the count started
	sides: { { Player } },
}

local pads: { [BasePart]: Pad } = {}
local MatchHost: any = nil

local function modeOf(zone: BasePart): string?
	local attr = zone:GetAttribute("Mode")
	if typeof(attr) == "string" then
		return attr
	end
	local node: Instance? = zone
	while node and node ~= workspace do
		local m = string.match(node.Name, "_(%dv%d)$")
		if m then
			return m
		end
		node = node.Parent
	end
	return nil
end

local function addPad(zone: Instance)
	if not zone:IsA("BasePart") or pads[zone] or not zone:IsDescendantOf(workspace) then
		return
	end
	local root = workspace:FindFirstChild(ROOT)
	if not root or not zone:IsDescendantOf(root) then
		return
	end
	local mode = modeOf(zone)
	local info = mode and Config.MODE_BY_ID[mode]
	if not info then
		return
	end
	local model = zone.Parent or zone
	local a = model:FindFirstChild("Square_A")
	local b = model:FindFirstChild("Square_B")
	pads[zone] = {
		zone = zone,
		model = model,
		mode = info.id,
		teamSize = info.teamSize,
		squareA = if a and a:IsA("BasePart") then a else nil,
		squareB = if b and b:IsA("BasePart") then b else nil,
		countFrom = nil,
		sides = { {}, {} },
	}
	model:SetAttribute("PadMode", info.id)
	model:SetAttribute("PadNeed", info.teamSize)
	model:SetAttribute("PadA", 0)
	model:SetAttribute("PadB", 0)
	model:SetAttribute("PadStartsAt", 0)
end

-- Who can be counted: in the lobby (not the range, not a duel), up and about, not searching the global queue.
local function eligible(player: Player): BasePart?
	if PlayZone.get(player) ~= "Lobby" then
		return nil
	end
	local status = StateValues.get(player, "QueueStatus")
	if status ~= nil and status ~= "idle" then
		return nil
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") or humanoid.Health <= 0 then
		return nil
	end
	if Health.isDowned(humanoid) then
		return nil
	end
	return root
end

-- Which half of the pad a position is on (1 = A, 2 = B), or nil when off the pad.
local function sideOf(pad: Pad, position: Vector3): number?
	local zone = pad.zone
	local loc = zone.CFrame:PointToObjectSpace(position)
	local half = zone.Size / 2
	if math.abs(loc.X) > half.X or math.abs(loc.Z) > half.Z then
		return nil
	end
	if loc.Y < -half.Y or loc.Y > half.Y + Config.PAD.height then
		return nil
	end
	local a, b = pad.squareA, pad.squareB
	if a and b then
		return if (position - a.Position).Magnitude <= (position - b.Position).Magnitude
			then 1
			else 2
	end
	return if loc.X < 0 then 1 else 2
end

local function publish(pad: Pad, startsAt: number)
	pad.model:SetAttribute("PadA", #pad.sides[1])
	pad.model:SetAttribute("PadB", #pad.sides[2])
	pad.model:SetAttribute("PadStartsAt", startsAt)
end

local function step()
	-- Everyone counted once, on the first pad they stand on.
	local roots: { [Player]: BasePart } = {}
	for _, player in Players:GetPlayers() do
		local root = eligible(player)
		if root then
			roots[player] = root
		end
	end
	local taken: { [Player]: boolean } = {}
	local now = os.clock()
	for _, pad in pads do
		if not pad.zone:IsDescendantOf(workspace) then
			continue
		end
		local sides: { { Player } } = { {}, {} }
		for player, root in roots do
			if not taken[player] then
				local side = sideOf(pad, root.Position)
				if side then
					taken[player] = true
					table.insert(sides[side], player)
				end
			end
		end
		pad.sides = sides
		-- Studio test switch: Workspace attribute PadDuelSolo = true starts a duel
		-- from side A alone, with bots on side B (Studio playtests are one player).
		local solo = RunService:IsStudio() and workspace:GetAttribute("PadDuelSolo") == true
		local full = #sides[1] == pad.teamSize
			and (#sides[2] == pad.teamSize or (solo and #sides[2] == 0))
		if not full then
			pad.countFrom = nil
			publish(pad, 0)
		elseif not pad.countFrom then
			pad.countFrom = now
			publish(pad, workspace:GetServerTimeNow() + Config.PAD.countdown)
		elseif now - pad.countFrom >= Config.PAD.countdown then
			pad.countFrom = nil
			publish(pad, 0)
			local teams = { table.clone(sides[1]), table.clone(sides[2]) }
			local ok, err =
				pcall(MatchHost.startDuel, pad.mode, pad.teamSize, teams, #teams[2] == 0)
			if not ok then
				warn(`[PadDuel] couldn't start a {pad.mode} duel: {err}`)
			end
		else
			publish(pad, pad.model:GetAttribute("PadStartsAt") :: number)
		end
	end
end

function PadDuelService.start()
	local server = ServerScriptService:WaitForChild("Server", 10)
	local services = server and server:FindFirstChild("Services")
	local host = services and services:FindFirstChild("MatchHost")
	if not host or not host:IsA("ModuleScript") then
		warn("[PadDuel] no MatchHost in this place: duel pads are off")
		return
	end
	MatchHost = require(host) :: any
	for _, zone in CollectionService:GetTagged(TAG) do
		addPad(zone)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(addPad)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(zone)
		if zone:IsA("BasePart") then
			pads[zone] = nil
		end
	end)
	while true do
		task.wait(Config.PAD.tick)
		step()
	end
end

return PadDuelService
