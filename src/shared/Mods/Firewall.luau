--!strict
-- Firewall (Control, Wall; vault/01 Design/Abilities/Firewall.md): Phoenix's
-- Blaze. Held ("HeldSteer"): your free hand ignites. Hold LMB and a wall of
-- fire builds forward from your feet along the ground, curving as you turn
-- (the server turns it toward its own copy of your camera, at most
-- `turnRate` degrees a second; ModSteer streams the look as a fallback and
-- ends it early on release). RMB builds it dead straight. Up to `maxLength`
-- long, `height` tall; it blocks vision only (shots and players pass through
-- it), goes through walls and follows the floor. It burns `dps` while you're
-- in it: enemies full, your team Config/Mods FRIENDLY_FIRE, you not at all.
-- It lasts `duration` after it finishes building.
--
-- The server side is Services/ModWalls (segments in workspace.ModWalls,
-- damage ticks); clients dress the segments (Util/WallFx).

local Types = require(script.Parent.Types)

local Firewall = {}

-- A point is in a wall segment `part` (thickness × height × length, centred)
-- with `margin` studs of body width around it.
function Firewall.inside(part: BasePart, point: Vector3, margin: number): boolean
	local rel = part.CFrame:PointToObjectSpace(point)
	local half = part.Size / 2
	return math.abs(rel.X) <= half.X + margin
		and math.abs(rel.Z) <= half.Z + 0.25
		and rel.Y >= -half.Y - 1.5
		and rel.Y <= half.Y
end

local module: Types.ModModule = {}

module.validate = function(_ctx: Types.ServerCtx, req: Types.Request): (boolean, string?)
	if req.mode ~= "Primary" and req.mode ~= "Alt" then
		return false, "bad mode"
	end
	local flat = req.direction * Vector3.new(1, 0, 1)
	if flat.Magnitude < 0.05 then
		return false, "look along the ground"
	end
	return true
end

module.apply = function(ctx: Types.ServerCtx, req: Types.Request)
	local flat = (ctx.cameraLook * Vector3.new(1, 0, 1))
	if flat.Magnitude < 0.05 then
		flat = req.direction * Vector3.new(1, 0, 1)
	end
	ctx.wall({ heading = flat.Unit, straight = req.mode == "Alt" })
	ctx.fx("FirewallCast", { at = ctx.head.Position })
end

Firewall.module = module

return Firewall
