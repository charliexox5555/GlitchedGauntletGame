--!strict
-- Pathfinding runs off the think thread. Local steering checks the next
-- step for collisions, floor support and zone safety. Sustained loss of
-- waypoint progress invalidates the route.

local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BotsConfig = require(ReplicatedStorage.Shared.Config.Bots)
local Zone = require(script.Parent.Parent.Zone)
local MovementGuard = require(game:GetService("ServerScriptService").Server.Services.MovementGuard)
local BotTypes = require(script.Parent.Types)

type Bot = BotTypes.Bot
type Nav = BotTypes.Nav

local Nav = {}
local UP = Vector3.yAxis
local FLAT = Vector3.new(1, 0, 1)
local BODY = Vector3.new(3.4, 2.6, 3.4)
local SQRT_HALF = math.sqrt(0.5)

local AGENT = BotsConfig.AGENT
local path = PathfindingService:CreatePath({
	AgentRadius = AGENT.radius,
	AgentHeight = AGENT.height,
	AgentCanJump = AGENT.canJump,
	WaypointSpacing = AGENT.spacing,
	Costs = { Water = 20 },
})
-- One path compute at a time across all bots (ComputeAsync yields): the
-- shared Path object is reused, and a queue keeps the cost flat.
local busy: {}? = nil -- the compute holding the Path
local busyAt = 0
-- A compute that never comes back must not hold every bot's routing (2026-11-27 bot fixes).
local BUSY_TIMEOUT = 5
local activeMap: Model? = nil

function Nav.setMap(map: Model?)
	activeMap = map
end

function Nav.insideArena(point: Vector3): boolean
	local map = activeMap
	return not map or MovementGuard.contains(map, point)
end

function Nav.new(): Nav
	local params = RaycastParams.new()
	params.RespectCanCollide = true
	return {
		goal = nil,
		waypoints = {},
		index = 1,
		computedAt = -math.huge,
		computedFor = nil,
		computing = false,
		failedFor = nil,
		bestDist = math.huge,
		bestAt = 0,
		progressIndex = 0,
		lastSamplePos = Vector3.zero,
		lastSampleAt = 0,
		stuck = 0,
		revision = 0,
		params = params,
		shortcutAt = 0,
		steerAt = 0,
		steerFrom = Vector3.zero,
		steerDir = Vector3.zero,
		steerJump = false,
	}
end

function Nav.clear(nav: Nav)
	if not nav.goal then
		return
	end
	nav.goal = nil
	nav.revision += 1
	table.clear(nav.waypoints)
	nav.index = 1
	nav.computedFor = nil
	nav.failedFor = nil
	nav.computedAt = -math.huge
	nav.bestDist = math.huge
	nav.progressIndex = 0
	nav.stuck = 0
	nav.shortcutAt = 0
	nav.steerAt = 0
end

function Nav.updateFilter(bot: Bot)
	local root, model = bot.root, bot.model
	if root and model then
		local params = bot.nav.params
		params.FilterDescendantsInstances = { model }
		params.CollisionGroup = root.CollisionGroup
	end
end

function Nav.ground(bot: Bot, at: Vector3, down: number?): Vector3?
	local hit = workspace:Raycast(at + UP * 2, -UP * (down or 16), bot.nav.params)
	if not hit or hit.Normal.Y < 0.65 or not Nav.insideArena(hit.Position) then
		return nil
	end
	local map = activeMap
	return if not map or hit.Instance:IsDescendantOf(map) then hit.Position else nil
end

function Nav.clearLine(bot: Bot, from: Vector3, to: Vector3): boolean
	local delta = to - from
	return delta.Magnitude < 0.05 or workspace:Raycast(from, delta, bot.nav.params) == nil
end

-- Body-width clearance and floor support for local movement or a dash.
function Nav.canMove(bot: Bot, dir: Vector3, distance: number, jump: boolean?): boolean
	local root = bot.root
	if not root or dir.Magnitude < 0.05 then
		return false
	end
	local pos = root.Position
	local heading = dir.Unit
	if not Nav.insideArena(pos + heading * distance) then
		return false
	end
	local lift = if jump then 2.2 else 0
	if jump and not Nav.clearLine(bot, pos + UP * 1.3, pos + UP * 4.2) then
		return false
	end
	if
		workspace:Blockcast(CFrame.new(pos + UP * lift), BODY, heading * distance, bot.nav.params)
	then
		return false
	end
	if
		distance <= BotsConfig.STEER_LOOKAHEAD
		and bot.humanoid
		and bot.humanoid.FloorMaterial == Enum.Material.Air
	then
		return true
	end
	local floor = Nav.ground(bot, pos + heading * distance + UP * lift, 12)
	local hips = (bot.humanoid and bot.humanoid.HipHeight or 2) + root.Size.Y * 0.5
	return floor ~= nil
		and floor.Y >= pos.Y - hips - BotsConfig.MAX_STEP_DOWN
		and (jump == true or floor.Y <= pos.Y - hips + 2)
end

function Nav.zoneAllows(bot: Bot, endPos: Vector3, lead: number?): boolean
	local zone, root = bot.zone, bot.root
	if not zone or not root then
		return true
	end
	local now = workspace:GetServerTimeNow()
	local edge = Zone.outside(zone, root.Position, now)
	local nextEdge = Zone.outside(zone, endPos, now + (lead or 0))
	-- A bot already outside can take an inward step. A rotation can detour
	-- around cover while it still has ample room inside the current ring.
	return nextEdge <= -0.3 or nextEdge < edge - 0.05
end

-- The shared Path's waypoints for one compute (nil: no route), copied out before the Path is reused.
local function solve(from: Vector3, destination: Vector3): { PathWaypoint }?
	path:ComputeAsync(from, destination)
	if path.Status ~= Enum.PathStatus.Success then
		return nil
	end
	local waypoints = path:GetWaypoints()
	for _, waypoint in waypoints do
		if not Nav.insideArena(waypoint.Position) then
			return nil
		end
	end
	return waypoints
end

local function compute(bot: Bot, nav: Nav, goal: Vector3, life: number, revision: number)
	while busy and os.clock() - busyAt < BUSY_TIMEOUT do
		task.wait()
		if bot.life ~= life or nav.revision ~= revision then
			nav.computing = false
			return
		end
	end
	local root = bot.root
	if not root or bot.life ~= life or nav.revision ~= revision then
		nav.computing = false
		return
	end
	local from = root.Position
	local destination = Nav.ground(bot, goal)
	local waypoints: { PathWaypoint }? = nil
	if destination then
		local token = {}
		busy, busyAt = token, os.clock()
		local ok, result = pcall(solve, from, destination)
		if busy == token then
			busy = nil
		end
		waypoints = if ok then result else nil
	end
	nav.computing = false
	if bot.life ~= life or nav.revision ~= revision then
		return
	end
	if
		not nav.goal
		or (nav.goal - goal).Magnitude > math.max(9, (goal - from).Magnitude * 0.35)
	then
		return
	end
	nav.computedAt = os.clock()
	nav.computedFor = goal
	nav.failedFor = if waypoints then nil else goal
	nav.bestDist = math.huge
	nav.bestAt = nav.computedAt
	nav.shortcutAt = 0
	nav.steerAt = 0
	table.clear(nav.waypoints)
	-- The waypoints are copied before the shared Path is used again
	-- (LihFolk Pathfinding Edge Cases: a shared Path must not be read later).
	if waypoints then
		for _, w in waypoints do
			table.insert(nav.waypoints, w)
		end
		nav.index = math.min(2, #nav.waypoints) -- the first is where it stands
	else
		-- Local steering admits a direct step only if the body and floor fit.
		nav.index = 1
	end
end

-- Sets where the bot is going (recomputes when needed).
function Nav.setGoal(bot: Bot, goal: Vector3)
	local nav = bot.nav
	local root = bot.root
	if not root then
		return
	end
	nav.goal = goal
	local now = os.clock()
	-- Recompute when the goal moved a share of the way left (LihFolk Pathfinding).
	local left = (goal - root.Position).Magnitude
	local moved = nav.computedFor == nil
		or (nav.computedFor - goal).Magnitude
			> math.max(BotsConfig.REPATH_MOVE, left * BotsConfig.REPATH_SHARE)
	local due = now - nav.computedAt > BotsConfig.REPATH_EVERY
	if
		not nav.computing
		and due
		and (moved or (nav.failedFor ~= nil and now - nav.computedAt > 1.8))
	then
		nav.computing = true
		task.spawn(compute, bot, nav, goal, bot.life, nav.revision)
	end
end

-- Round off close corners only when the body fits and the ground carries it.
local function shortcut(bot: Bot, pos: Vector3, now: number)
	local nav = bot.nav
	local current = nav.waypoints[nav.index]
	if
		now < nav.shortcutAt
		or not current
		or current.Action ~= Enum.PathWaypointAction.Walk
		or current.Label ~= ""
		or not bot.humanoid
		or bot.humanoid.FloorMaterial == Enum.Material.Air
	then
		return
	end
	nav.shortcutAt = now + 0.15
	for i = nav.index + 1, math.min(nav.index + 2, #nav.waypoints) do
		local next = nav.waypoints[i]
		if next.Action ~= Enum.PathWaypointAction.Walk or next.Label ~= "" then
			break
		end
		local step = (next.Position - pos) * FLAT
		local distance = step.Magnitude
		if distance < 1 or distance > 10 or not Nav.zoneAllows(bot, next.Position) then
			break
		end
		if not (Nav.canMove(bot, step, distance) and Nav.canMove(bot, step, distance * 0.5)) then
			break
		end
		nav.index = i
	end
end

-- The flat direction to walk this frame toward the goal (zero: arrived or
-- nothing to do), and whether to jump.
function Nav.steer(bot: Bot, now: number): (Vector3, boolean)
	local nav = bot.nav
	local root = bot.root
	local goal = nav.goal
	if not root or not goal then
		return Vector3.zero, false
	end
	local pos = root.Position
	shortcut(bot, pos, now)
	local jump = false
	local aimAt = goal
	local w = nav.waypoints[nav.index]
	while w do
		local flat = (w.Position - pos) * FLAT
		local from = nav.waypoints[nav.index - 1]
		local passed = false
		if from and w.Action ~= Enum.PathWaypointAction.Jump then
			local segment = (w.Position - from.Position) * FLAT
			if segment.Magnitude > 0.1 then
				local forward = segment.Unit
				local ahead = -flat:Dot(forward)
				local cross = -flat - forward * ahead
				passed = ahead >= 0 and cross.Magnitude < BotsConfig.WAYPOINT_REACHED
			end
		end
		if
			(not passed and flat.Magnitude > BotsConfig.WAYPOINT_REACHED)
			or w.Position.Y - pos.Y > 1.5
		then
			break
		end
		nav.index += 1
		w = nav.waypoints[nav.index]
		if w and w.Action == Enum.PathWaypointAction.Jump then
			jump = true
		end
	end
	if w then
		aimAt = w.Position
		if w.Action == Enum.PathWaypointAction.Jump and (w.Position - pos).Magnitude < 6 then
			jump = true
		end
	elseif
		#nav.waypoints > 0
		and nav.computedFor
		and ((nav.computedFor - goal) * FLAT).Magnitude <= BotsConfig.WAYPOINT_REACHED
	then
		return Vector3.zero, false
	end
	local flat = (aimAt - pos) * Vector3.new(1, 0, 1)
	if flat.Magnitude < 1.4 then
		return Vector3.zero, w ~= nil and (jump or w.Position.Y - pos.Y > 1.5)
	end
	-- A step up the path asks for a jump when the waypoint is clearly above.
	if w and w.Position.Y - pos.Y > 2.2 and flat.Magnitude < 5 then
		jump = true
	end
	return if flat.Magnitude > 1e-3 then flat.Unit else Vector3.zero, jump
end

-- Every bot samples its next step at most at the configured steer cadence.
-- Keep the chosen side briefly to avoid ping-pong at an angled wall.
function Nav.avoid(bot: Bot, dir: Vector3, jump: boolean, now: number): (Vector3, boolean)
	local root, nav = bot.root, bot.nav
	if not root then
		return Vector3.zero, false
	end
	if dir.Magnitude < 0.05 then
		return Vector3.zero,
			jump and Nav.clearLine(bot, root.Position + UP * 1.3, root.Position + UP * 4.2)
	end
	local heading = dir.Unit
	if now < nav.steerAt and heading:Dot(nav.steerFrom) > 0.94 then
		return nav.steerDir * math.min(dir.Magnitude, 1), nav.steerJump
	end
	local old = nav.steerDir
	nav.steerAt = now + BotsConfig.STEER_EVERY
	nav.steerFrom = heading
	nav.steerDir, nav.steerJump = Vector3.zero, false
	local ahead = BotsConfig.STEER_LOOKAHEAD
	local waypoint = nav.waypoints[nav.index]
	local goal = if waypoint then waypoint.Position else nav.goal
	if goal then
		local delta = goal - root.Position
		ahead = math.clamp(Vector3.new(delta.X, 0, delta.Z).Magnitude, if jump then 2 else 1, ahead)
	end
	local function legal(step: Vector3, hop: boolean): boolean
		return Nav.zoneAllows(bot, root.Position + step * ahead)
			and Nav.canMove(bot, step, ahead, hop)
	end
	-- A valid route can briefly lead farther out to get around a wall if a
	-- bot is already outside. Inside, the boundary always wins.
	local zone = bot.zone
	local needsDetour = bot.goal == "Rotate"
		and zone ~= nil
		and nav.waypoints[nav.index] ~= nil
		and Zone.outside(zone, root.Position, workspace:GetServerTimeNow()) > 0
	if legal(heading, jump) or (needsDetour and Nav.canMove(bot, heading, ahead, jump)) then
		nav.steerDir, nav.steerJump = heading, jump
	else
		local side = Vector3.new(-heading.Z, 0, heading.X)
		if side:Dot(old) < 0 then
			side = -side
		end
		local alternatives = if nav.goal
			then { (heading + side) * SQRT_HALF, (heading - side) * SQRT_HALF }
			else { (heading + side) * SQRT_HALF, (heading - side) * SQRT_HALF, side, -side }
		for _, step in alternatives do
			if legal(step, false) then
				nav.steerDir = step
				break
			end
		end
	end
	return nav.steerDir * math.min(dir.Magnitude, 1), nav.steerJump
end

-- Twice a second: report sustained loss of progress so the brain can replan.
function Nav.checkStuck(bot: Bot, wanted: boolean): boolean
	local nav = bot.nav
	local root = bot.root
	local now = os.clock()
	if not root or now - nav.lastSampleAt < BotsConfig.STUCK_CHECK then
		return false
	end
	local moved = (root.Position - nav.lastSamplePos).Magnitude
	nav.lastSamplePos = root.Position
	nav.lastSampleAt = now
	-- Progress, not just speed: circling or sliding along a wall moves the
	-- bot without getting it closer (LihFolk Pathfinding Edge Cases).
	local w = nav.waypoints[nav.index]
	local aim = if w then w.Position else nav.goal
	local noProgress = false
	if aim then
		local d = ((aim - root.Position) * Vector3.new(1, 0, 1)).Magnitude
		if nav.progressIndex ~= nav.index or d < nav.bestDist - 1 then
			nav.progressIndex = nav.index
			nav.bestDist = d
			nav.bestAt = now
		end
		noProgress = now - nav.bestAt > BotsConfig.PROGRESS_WINDOW
	end
	if not wanted or (moved >= BotsConfig.STUCK_DISTANCE and not noProgress) then
		nav.stuck = 0
		return false
	end
	nav.stuck += 1
	if nav.stuck >= 2 then
		nav.stuck = 0
		nav.failedFor = nav.goal
		nav.computedAt = -math.huge
		nav.computedFor = nil
		nav.steerAt = 0
		nav.revision += 1
		table.clear(nav.waypoints)
		nav.index = 1
		return true
	end
	return false
end

return Nav
