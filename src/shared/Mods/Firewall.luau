--!strict
-- Firewall (Defense, Placeable): held, LMB deploys an 8x6 wall in front of
-- you, across your aim. It's a queryable, collidable part in
-- workspace.ModObjects, so it blocks bullets both ways through WeaponService's
-- normal wall check, and shots that hit it take its HP (150) down. 6 s life.
-- The placement must not overlap anyone (no trapping people in a wall).

local Placeable = require(script.Parent.Blocks.Placeable)
local Types = require(script.Parent.Types)

local Firewall = {}

function Firewall.size(stats: Types.Stats): Vector3
	return Vector3.new(stats.width, stats.height, stats.thickness)
end

function Firewall.find(
	head: Vector3,
	aim: Vector3,
	stats: Types.Stats,
	params: RaycastParams
): Placeable.Spot
	return Placeable.find(
		head,
		aim,
		stats.placeRange,
		Firewall.size(stats),
		params,
		Placeable.overlap(true)
	)
end

local module: Types.ModModule = {}

module.validate = function(ctx: Types.ServerCtx, req: Types.Request): (boolean, string?)
	local spot = Firewall.find(ctx.head.Position, req.direction, ctx.stats, ctx.worldParams())
	if not spot.valid then
		return false, spot.reason
	end
	req.placement = spot.cframe
	return true
end

module.apply = function(ctx: Types.ServerCtx, req: Types.Request)
	local stats = ctx.stats
	local wall = Instance.new("Part")
	wall.Name = "Firewall"
	wall.Size = Firewall.size(stats)
	local placement = req.placement
	if not placement then
		return
	end
	wall.CFrame = placement
	wall.Material = Enum.Material.ForceField
	wall.Color = Color3.fromHex("2A2D33") -- clients recolour by team
	wall.Transparency = 0.1
	wall.CanCollide = true
	wall.CanQuery = true -- blocks shots (WeaponService wall checks)
	wall.CanTouch = false
	ctx.place("Firewall", wall, stats.life, stats.hp, stats.charges)
	ctx.fx("Placed", { kind = "Firewall", at = wall.Position })
	ctx.active(stats.life)
end

Firewall.module = module

return Firewall
