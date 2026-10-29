--!strict
-- Stim (Team buff, Zone; was Overclock; vault/01 Design/Abilities/Stim.md):
-- Brimstone's stim beacon. Instant: you drop a beacon at your feet (the
-- floor under you; refused with nothing under you). For `duration` seconds a
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

local GROUND_SEARCH = 12 -- studs below the feet a floor is looked for

-- The floor under `root` (nil: nothing close enough below).
function Stim.floorUnder(root: BasePart, params: RaycastParams): Vector3?
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -GROUND_SEARCH, 0), params)
	return if hit then hit.Position else nil
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
	local floor = Stim.floorUnder(root, ctx.worldParams())
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
	ctx.fx("StimDrop", {
		at = spot.Position,
		look = spot.LookVector,
		radius = stats.radius,
		duration = stats.duration,
		deploy = stats.deployTime,
		start = workspace:GetServerTimeNow(),
	})
	ctx.active(stats.duration)
	local ticks = math.floor(stats.duration / stats.tick + 0.5)
	for i = 0, ticks - 1 do
		ctx.schedule(stats.deployTime + i * stats.tick, function()
			pulse(ctx, zone)
		end)
	end
end

Stim.module = module

return Stim
