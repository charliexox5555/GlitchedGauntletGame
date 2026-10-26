--!strict
-- Blink (Mobility, Dash): a quick dash in your move direction (your facing
-- when still). Predicted: it runs inside the simulation (Simulation/
-- Abilities), on the server for everyone and on your client for yourself.
-- simCast writes the dash as character attributes; Abilities.stepDash moves
-- the root while it lasts.
--
-- Character attributes (simulation-written):
--   DashStart     time() the dash began (the client plays the lunge on change)
--   DashUntil     time() it ends
--   DashVelocity  horizontal velocity while it lasts
--   DashExit      horizontal speed kept when it ends

local Types = require(script.Parent.Types)
local Dash = require(script.Parent.Blocks.Dash)

local Blink = {}

local module: Types.ModModule = {}

module.simCast = function(ctx: Types.SimCtx): boolean
	local stats = ctx.stats
	local root = ctx.root
	local dir = Dash.direction(ctx.humanoid.MoveDirection, root.CFrame.LookVector)
	if not dir then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { ctx.character }
	local reach = Dash.reach(root.Position, dir, stats.distance, stats.radius, params)
	if reach < 1 then
		return false -- against a wall: no dash, no charge spent
	end
	local duration = stats.duration * reach / stats.distance
	local character = ctx.character
	character:SetAttribute("DashStart", ctx.now)
	character:SetAttribute("DashUntil", ctx.now + duration)
	character:SetAttribute("DashVelocity", dir * (stats.distance / stats.duration))
	character:SetAttribute("DashExit", stats.exitSpeed)
	return true
end

Blink.module = module

return Blink
