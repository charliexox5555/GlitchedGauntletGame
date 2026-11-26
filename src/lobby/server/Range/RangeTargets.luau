--!strict
-- The range's air targets on the server (vault/01 Design/Range v5.md, numbers in Config/RangeTargets). Owner
-- 2026-11-26: "red circle targets [in the air] that you can shoot down. They break, like they shatter", then "the
-- target should always face the player ... completely client-sided ... separate per player".
--
-- Targets are per player: each player has their own set, broken and back on their own clock. The server never moves
-- the target models (no replication churn): each client draws them gliding along shared/RangeTargetMotion from the
-- server clock and turned to face its own camera. A target breaks only when the server's own rays for an accepted
-- shot (WeaponService.onRays: the spread it recomputed, not the client's claim) pass within RADIUS of its centre
-- (a ball, since every player sees it face-on) before anything solid, from a shooter in the Range zone. The shooter
-- alone is told (LobbyNet RangeTargetEvent: the target, where it was hit, where the shot came from, when it's back).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LobbyNet = require(ReplicatedStorage.Lobby.LobbyNet)
local PlayZone = require(ReplicatedStorage.Shared.PlayZone)
local RangeTargetMotion = require(ReplicatedStorage.Shared.RangeTargetMotion)
local RangeTargets = require(ReplicatedStorage.Shared.Config.RangeTargets)
local RangeEvents = require(script.Parent.RangeEvents)

local RangeTargetsServer = {}

type Target = { model: Model, home: CFrame }

local targets: { [Model]: Target } = {}
-- player -> target -> server time it comes back for them
local brokenUntil: { [Player]: { [Model]: number } } = {}

local function add(inst: Instance)
	if not inst:IsA("Model") or targets[inst] then
		return
	end
	-- the server's copies never block shots or players: the hit test is the ball below
	for _, d in inst:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
		end
	end
	inst.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local stored = inst:GetAttribute("Home")
	local home = if typeof(stored) == "CFrame" then stored else inst:GetPivot()
	inst:SetAttribute("Home", home)
	targets[inst] = { model = inst, home = home }
end

-- How far along the ray (origin + dir * t) it passes within `radius` of `centre`; nil if it misses.
local function rayBall(
	origin: Vector3,
	dir: Vector3,
	range: number,
	centre: Vector3,
	radius: number
): number?
	local t = (centre - origin):Dot(dir)
	if t < 0 or t > range then
		return nil
	end
	if (centre - (origin + dir * t)).Magnitude > radius then
		return nil
	end
	return t
end

-- An accepted shot's rays: each ray breaks the nearest of the shooter's standing targets it passes through, if
-- nothing solid comes first. Read-only on the shot.
local function onRays(
	player: Player,
	character: Model,
	origin: Vector3,
	dirs: { Vector3 },
	config: any
)
	if PlayZone.get(player) ~= "Range" or next(targets) == nil or config.melee then
		return
	end
	local range = if typeof(config.range) == "number" then config.range else 0
	if range <= 0 then
		return
	end
	local now = workspace:GetServerTimeNow()
	local mine = brokenUntil[player]
	if not mine then
		mine = {}
		brokenUntil[player] = mine
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	for _, dir in dirs do
		local bestT, best = math.huge, nil :: Target?
		for model, t in targets do
			if (mine[model] or 0) > now then
				continue
			end
			-- where it is now, or a moment ago (what the shooter saw a ping back)
			for _, back in { 0, RangeTargets.LAG_SLACK } do
				local centre = RangeTargetMotion.position(model, t.home, now - back)
				local along = rayBall(origin, dir, range, centre, RangeTargets.RADIUS)
				if along and along < bestT then
					bestT, best = along, t
				end
			end
		end
		if best and not workspace:Raycast(origin, dir * bestT, params) then
			local backAt = now + RangeTargets.RESPAWN
			mine[best.model] = backAt
			LobbyNet.event("RangeTargetEvent")
				:FireClient(player, best.model, origin + dir * bestT, origin, backAt)
			RangeEvents.fire(player, "target") -- the task Path (Services/TaskService)
		end
	end
end

-- `onRaysHook`: WeaponService.onRays (the match code, handed over by RangeService).
function RangeTargetsServer.start(onRaysHook: (any) -> ())
	for _, inst in CollectionService:GetTagged(RangeTargets.TAG) do
		add(inst)
	end
	CollectionService:GetInstanceAddedSignal(RangeTargets.TAG):Connect(add)
	CollectionService:GetInstanceRemovedSignal(RangeTargets.TAG):Connect(function(inst)
		if inst:IsA("Model") then
			targets[inst] = nil
		end
	end)
	onRaysHook(onRays)
	Players.PlayerRemoving:Connect(function(player)
		brokenUntil[player] = nil
	end)
end

return RangeTargetsServer
