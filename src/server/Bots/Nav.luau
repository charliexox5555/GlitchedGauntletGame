--!strict
-- Getting a bot somewhere (vault/01 Design/Bots.md → Brain → Move):
-- PathfindingService paths, recomputed sparingly (at most every
-- REPATH_EVERY, or when the goal moved REPATH_MOVE studs) off the think
-- thread, followed by steering (no waiting on MoveToFinished). Stuck
-- detection escalates: jump, then sidestep, then a fresh path.

local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BotsConfig = require(ReplicatedStorage.Shared.Config.Bots)
local BotTypes = require(script.Parent.Types)

type Bot = BotTypes.Bot
type Nav = BotTypes.Nav

local Nav = {}

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
local busy = false

function Nav.new(): Nav
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
	}
end

function Nav.clear(nav: Nav)
	nav.goal = nil
	table.clear(nav.waypoints)
	nav.index = 1
	nav.computedFor = nil
end

local function compute(bot: Bot, nav: Nav, from: Vector3, goal: Vector3, life: number)
	nav.computing = true
	while busy do
		task.wait()
		if bot.life ~= life then
			nav.computing = false
			return
		end
	end
	busy = true
	local ok = pcall(function()
		path:ComputeAsync(from, goal)
	end)
	local waypoints = if ok and path.Status == Enum.PathStatus.Success
		then path:GetWaypoints()
		else nil
	busy = false
	nav.computing = false
	if bot.life ~= life then
		return
	end
	nav.computedAt = os.clock()
	nav.computedFor = goal
	nav.failedFor = if waypoints then nil else goal
	nav.bestDist = math.huge
	table.clear(nav.waypoints)
	-- The waypoints are copied before the shared Path is used again
	-- (LihFolk Pathfinding Edge Cases: a shared Path must not be read later).
	if waypoints then
		for _, w in waypoints do
			table.insert(nav.waypoints, w)
		end
		nav.index = math.min(2, #nav.waypoints) -- the first is where it stands
	else
		-- No path (off the mesh, or the goal is inside something): head
		-- straight for it and let stuck handling sort it out.
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
	if not nav.computing and moved and due then
		task.spawn(compute, bot, nav, root.Position, goal, bot.life)
	end
end

-- The flat direction to walk this frame toward the goal (zero: arrived or
-- nothing to do), and whether to jump.
function Nav.steer(bot: Bot): (Vector3, boolean)
	local nav = bot.nav
	local root = bot.root
	local goal = nav.goal
	if not root or not goal then
		return Vector3.zero, false
	end
	local pos = root.Position
	local jump = false
	local aimAt = goal
	local w = nav.waypoints[nav.index]
	while w do
		local flat = (w.Position - pos) * Vector3.new(1, 0, 1)
		if flat.Magnitude > BotsConfig.WAYPOINT_REACHED then
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
		if w.Action == Enum.PathWaypointAction.Jump and (w.Position - pos).Magnitude < 4 then
			jump = true
		end
	end
	local flat = (aimAt - pos) * Vector3.new(1, 0, 1)
	if flat.Magnitude < 1 and not w then
		return Vector3.zero, false
	end
	-- A step up the path asks for a jump when the waypoint is clearly above.
	if w and w.Position.Y - pos.Y > 2.2 and flat.Magnitude < 5 then
		jump = true
	end
	return if flat.Magnitude > 1e-3 then flat.Unit else Vector3.zero, jump
end

-- Twice a second: did the bot move while it meant to? Returns the escalation
-- (0 fine, 1 jump, 2 sidestep, 3 repath).
function Nav.checkStuck(bot: Bot, wanted: boolean): number
	local nav = bot.nav
	local root = bot.root
	local now = os.clock()
	if not root or now - nav.lastSampleAt < BotsConfig.STUCK_CHECK then
		return 0
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
		return 0
	end
	nav.stuck += 1
	if nav.stuck == 3 and nav.waypoints[nav.index + 1] then
		nav.index += 1 -- skip the waypoint it can't reach
		nav.bestAt = now
		return 1
	end
	if nav.stuck >= 6 then
		nav.stuck = 0
		nav.computedAt = -math.huge
		nav.computedFor = nil
		return 3
	elseif nav.stuck >= 4 then
		return 2
	elseif nav.stuck >= 2 then
		return 1
	end
	return 0
end

return Nav
