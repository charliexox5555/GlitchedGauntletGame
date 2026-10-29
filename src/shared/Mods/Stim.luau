--!strict
-- Stim (Team buff, Zone; was Overclock; vault/01 Design/Abilities/Stim.md):
-- Brimstone's stim beacon. Instant: you toss the beacon underhand and it
-- lands `tossDistance` studs ahead of you (Stim.landing: short of a wall, on
-- the floor there; refused with no floor). It leaves the hand `tossRelease`
-- s after the press, flies `tossTime` s, and the zone switches on
-- `deployTime` s after it lands. For `duration` seconds a
-- `radius`-stud zone around it stims you and your teammates standing in it
-- (Config/StatusEffects "Stimmed": faster fire, movement, swaps and
-- reloads), refreshed every `tick` so it lasts `linger` seconds after
-- leaving. Enemies are never affected. The beacon can't be destroyed: the
-- zone's ticks are owner timers, clients draw the beacon and zone from the
-- "StimDrop" fx.

local Target = require(script.Parent.Blocks.Target)
local Teams = require(script.Parent.Teams)
local Types = require(script.Parent.Types)
local Zone = require(script.Parent.Blocks.Zone)

local Stim = {}

local GROUND_SEARCH = 12 -- studs below the root a floor is looked for
local WALL_GAP = 1 -- studs a toss lands short of a wall in the way

-- Where a toss from `root` along the flat `look` lands: `stats.tossDistance`
-- ahead at waist height (short of a wall), on the floor below that; else on
-- the floor under you. nil: no floor either way.
function Stim.landing(
	root: BasePart,
	look: Vector3,
	stats: Types.Stats,
	params: RaycastParams
): Vector3?
	local flat = Vector3.new(look.X, 0, look.Z)
	flat = if flat.Magnitude > 1e-3 then flat.Unit else root.CFrame.LookVector
	local from = root.Position
	local reach: number = stats.tossDistance
	local wall = workspace:Raycast(from, flat * reach, params)
	if wall then
		reach = math.max(wall.Distance - WALL_GAP, 0)
	end
	local ahead = from + flat * reach
	local hit = workspace:Raycast(ahead, Vector3.new(0, -GROUND_SEARCH, 0), params)
	if hit then
		return hit.Position
	end
	local under = workspace:Raycast(from, Vector3.new(0, -GROUND_SEARCH, 0), params)
	return if under then under.Position else nil
end

-- One tick: everyone friendly inside gets (or keeps) the stim.
local function pulse(ctx: Types.ServerCtx, zone: Zone.Zone)
	local caster = ctx.player
	for _, model in Target.combatants() do
		if not Target.alive(model) then
			continue
		end
		if model ~= caster.Character and not Teams.isAlly(caster, model) then
			continue -- never enemies
		end
		local root = model:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and Zone.contains(zone, root.Position) then
			ctx.status(model, "Stimmed", ctx.stats.linger)
		end
	end
end

local module: Types.ModModule = {}

module.validate = function(ctx: Types.ServerCtx, req: Types.Request): (boolean, string?)
	local root = ctx.character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false, "no root"
	end
	local floor = Stim.landing(root, req.direction, ctx.stats, ctx.worldParams())
	if not floor then
		return false, "No ground"
	end
	-- Facing the way you look (flat), on the floor.
	local look = Vector3.new(req.direction.X, 0, req.direction.Z)
	look = if look.Magnitude > 1e-3 then look.Unit else Vector3.new(0, 0, -1)
	req.placement = CFrame.lookAt(floor, floor + look)
	return true
end

module.apply = function(ctx: Types.ServerCtx, req: Types.Request)
	local stats = ctx.stats
	local spot = req.placement :: CFrame
	local zone: Zone.Zone = { center = spot.Position, radius = stats.radius, height = stats.height }
	-- Where it leaves the hand (third person: in front, about waist high).
	local root = ctx.character:FindFirstChild("HumanoidRootPart")
	local from = if root and root:IsA("BasePart")
		then root.Position + spot.LookVector + Vector3.new(0, 0.6, 0)
		else spot.Position
	-- The zone starts once it's thrown, has flown and snapped open.
	local deploy = stats.tossRelease + stats.tossTime + stats.deployTime
	ctx.fx("StimDrop", {
		at = spot.Position,
		look = spot.LookVector,
		from = from,
		release = stats.tossRelease,
		toss = stats.tossTime,
		radius = stats.radius,
		duration = stats.duration,
		deploy = deploy,
		start = workspace:GetServerTimeNow(),
	})
	ctx.active(deploy + stats.duration)
	local ticks = math.floor(stats.duration / stats.tick + 0.5)
	for i = 0, ticks - 1 do
		ctx.schedule(deploy + i * stats.tick, function()
			pulse(ctx, zone)
		end)
	end
end

Stim.module = module

return Stim
