--!strict
-- Server-side envelopes and large displacement checks. Physics ownership stays with the client.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(RS.Shared.Config.MovementGuard)
local Match = require(RS.Shared.Config.Match)
local Health = require(RS.Shared.Health)
local PlayZone = require(RS.Shared.PlayZone)
local StateValues = require(RS.Shared.StateValues)
local TestMode = require(RS.Shared.TestMode)

type Plane = { origin: Vector3, normal: Vector3 }
type Bounds = { planes: { Plane }, ceiling: number, killY: number }
type Visit = {
	character: Model,
	map: Model,
	last: CFrame,
	checkedAt: number,
	recallSerial: number?,
	recallUntil: number,
}
local maps: { [Model]: Bounds } = setmetatable({}, { __mode = "k" }) :: any
local visits: { [Player]: Visit } = {}
local warnings: { [string]: number } = {}
local MovementGuard = {}

function MovementGuard.register(map: Model)
	local centre = map:GetPivot().Position
	local bounds = map:FindFirstChild("Bounds", true)
	local planes: { Plane } = {}
	local ceiling = math.huge
	if bounds then
		for _, d in bounds:GetDescendants() do
			if not d:IsA("BasePart") then
				continue
			end
			local size = d.Size
			local axis = if size.X <= size.Z then d.CFrame.RightVector else d.CFrame.LookVector
			if size.Y < math.min(size.X, size.Z) then
				ceiling = math.min(ceiling, d.Position.Y + size.Y / 2)
			elseif math.abs(axis.Y) < 0.2 then
				local inward = if (centre - d.Position):Dot(axis) >= 0 then axis else -axis
				table.insert(planes, { origin = d.Position, normal = inward })
			end
		end
	end
	local depth = StateValues.get(map, "KillDepth")
	maps[map] = {
		planes = planes,
		ceiling = ceiling,
		killY = centre.Y - (if type(depth) == "number" then depth else Match.KILL_DEPTH),
	}
end

function MovementGuard.bind(player: Player, map: Model, spawn: CFrame)
	local character = player.Character
	if character then
		local recallSerial = StateValues.get(player, "RecallSerial")
		visits[player] = {
			character = character,
			map = map,
			last = spawn,
			checkedAt = os.clock(),
			recallSerial = if type(recallSerial) == "number" then recallSerial else nil,
			recallUntil = 0,
		}
	end
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function inArena(bounds: Bounds, pos: Vector3): boolean
	if pos.Y > bounds.ceiling + Config.BOUND_MARGIN then
		return false
	end
	for _, plane in bounds.planes do
		if (pos - plane.origin):Dot(plane.normal) < -Config.BOUND_MARGIN then
			return false
		end
	end
	return true
end

function MovementGuard.contains(map: Model, position: Vector3): boolean
	local bounds = maps[map]
	return bounds ~= nil and position.Y >= bounds.killY and inArena(bounds, position)
end

local function validate(player: Player, visit: Visit, position: Vector3, now: number): boolean
	local bounds = maps[visit.map]
	if not visit.map.Parent or not bounds or not inArena(bounds, position) then
		return false
	end
	-- A new server-issued Recall serial can explain one large jump to its exact landing area.
	local serial = StateValues.get(player, "RecallSerial")
	if typeof(serial) == "number" and serial ~= visit.recallSerial then
		visit.recallSerial = serial
		visit.recallUntil = now + Config.RECALL_WINDOW
	end
	local delta = position - visit.last.Position
	local elapsed = math.min(now - visit.checkedAt, Config.MAX_SAMPLE_GAP)
	local flat = Vector2.new(delta.X, delta.Z).Magnitude
	if
		flat <= Config.BURST_ALLOWANCE + Config.MAX_HORIZONTAL_SPEED * elapsed
		and delta.Y <= Config.BURST_ALLOWANCE + Config.MAX_UPWARD_SPEED * elapsed
	then
		return true
	end
	local recall = StateValues.get(player, "RecallTo")
	if now <= visit.recallUntil and typeof(recall) == "Vector3" then
		if (position - recall).Magnitude <= Config.RECALL_LANDING_RADIUS then
			visit.recallUntil = 0
			visit.last += position - visit.last.Position
			return true
		end
	end
	return false
end

function MovementGuard.canFight(player: Player): boolean
	local zone = PlayZone.get(player)
	if zone ~= "Match" then
		return zone == "Range" or TestMode.isOn()
	end
	local visit = visits[player]
	local root = rootOf(player)
	local bounds = visit and maps[visit.map]
	return visit ~= nil
		and visit.character == player.Character
		and root ~= nil
		and bounds ~= nil
		and root.Position.Y >= bounds.killY
		and validate(player, visit, root.Position, os.clock())
end

local function correct(root: BasePart, target: CFrame, reason: string)
	root.CFrame = target
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	warnings[reason] = (warnings[reason] or 0) + 1
end

local function sample(player: Player, now: number)
	local zone = PlayZone.get(player)
	if zone ~= "Match" then
		visits[player] = nil
	end
	local root = rootOf(player)
	local character = player.Character
	if
		not root
		or not character
		or not Health.isAlive(character:FindFirstChildOfClass("Humanoid"))
	then
		return
	end
	if zone == "Match" then
		local visit = visits[player]
		if not visit or visit.character ~= character then
			return
		end
		if validate(player, visit, root.Position, now) then
			visit.last = root.CFrame
		else
			correct(root, visit.last, "arena")
		end
		visit.checkedAt = now
	elseif zone == "Lobby" and not TestMode.isOn() then
		local p = root.Position
		local lo, hi = Config.LOBBY_MIN, Config.LOBBY_MAX
		if p.X < lo.X or p.X > hi.X or p.Y > hi.Y or p.Z < lo.Z or p.Z > hi.Z then
			local lobby = workspace:FindFirstChild("LobbyV5")
			local spawn = lobby and lobby:FindFirstChild("LobbyV5Spawn")
			if spawn and spawn:IsA("SpawnLocation") then
				correct(root, spawn.CFrame + Vector3.new(0, 4, 0), "lobby")
			end
		end
	end
end

function MovementGuard.start()
	Players.PlayerRemoving:Connect(function(player)
		visits[player] = nil
	end)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < Config.SAMPLE_INTERVAL then
			return
		end
		elapsed = 0
		debug.profilebegin("MovementGuard")
		local now = os.clock()
		for _, player in Players:GetPlayers() do
			sample(player, now)
		end
		debug.profileend()
	end)
	while true do
		task.wait(60)
		for reason, count in warnings do
			warn(`[MovementGuard] {reason} corrections in the last minute: {count}`)
		end
		table.clear(warnings)
	end
end

return MovementGuard
