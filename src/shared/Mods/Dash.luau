--!strict
-- Dash (Mobility, was Blink; vault/01 Design/Abilities/Dash.md): a quick
-- dash in your move direction (your facing when still). Predicted: it runs
-- inside the simulation (Simulation/Abilities), on the server for everyone
-- and on your client for yourself.
-- simCast writes the dash as character attributes; Abilities.stepDash moves
-- the root while it lasts.
--
-- Character attributes (simulation-written):
--   DashStart     time() the dash began (the client plays the lunge on change)
--   DashUntil     time() it ends
--   DashVelocity  horizontal velocity while it lasts
--   DashExit      horizontal speed kept when it ends
--   DashFireDelay seconds after it ends before the gun can fire (both sides
--                 gate shots on this; WeaponService checks it on its own)
--   DashFocus     Dash Focus window: the first shot this soon after the gun
--                 is back up has no movement or air spread

local Types = require(script.Parent.Types)
local DashBlock = require(script.Parent.Blocks.Dash)

local Dash = {}

local module: Types.ModModule = {}

module.simCast = function(ctx: Types.SimCtx): boolean
	local stats = ctx.stats
	local root = ctx.root
	local dir = DashBlock.direction(ctx.humanoid.MoveDirection, root.CFrame.LookVector)
	if not dir then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { ctx.character }
	local reach = DashBlock.reach(root.Position, dir, stats.distance, stats.radius, params)
	if reach < 1 then
		return false -- against a wall: no dash, no charge spent
	end
	local duration = stats.duration * reach / stats.distance
	local character = ctx.character
	character:SetAttribute("DashStart", ctx.now)
	character:SetAttribute("DashUntil", ctx.now + duration)
	character:SetAttribute("DashVelocity", dir * (stats.distance / stats.duration))
	character:SetAttribute("DashExit", stats.exitSpeed)
	character:SetAttribute("DashFireDelay", stats.fireDelay)
	character:SetAttribute("DashFocus", stats.focusWindow)
	return true
end

Dash.module = module

-- The gun gate around a dash, kept per character by WeaponController (our
-- own) and WeaponService (everyone, the truth), each on its own os.clock():
-- the gun is down until `readyAt` (the rest of the dash plus DashFireDelay),
-- then the first shot until `focusUntil` has no movement spread (Dash Focus).
-- Keyed on DashStart, so a chained dash pushes it on and a frame that
-- missed the Dashing flag can't skip it.
export type GunGate = {
	lastStart: number, -- DashStart of the last dash seen
	readyAt: number,
	focusUntil: number,
	focusOpen: boolean,
}

function Dash.newGate(): GunGate
	return { lastStart = 0, readyAt = -math.huge, focusUntil = -math.huge, focusOpen = false }
end

-- A new life: forget the last one's dash (its character had its own DashStart).
function Dash.resetGate(gate: GunGate)
	gate.lastStart = 0
	gate.readyAt = -math.huge
	gate.focusOpen = false
end

-- Call every frame. `now`: os.clock(); `simNow`: time() (the simulation's
-- clock, which DashUntil is on).
function Dash.stepGate(gate: GunGate, character: Model, now: number, simNow: number)
	local start = character:GetAttribute("DashStart")
	local fresh = false
	-- (A re-simulated start a few ms off isn't a new dash.)
	if typeof(start) == "number" and start > gate.lastStart + 0.05 then
		gate.lastStart = start
		gate.focusOpen = true
		fresh = true
	end
	if fresh or character:GetAttribute("Dashing") == true then
		local untilT = character:GetAttribute("DashUntil")
		local delay = character:GetAttribute("DashFireDelay")
		local window = character:GetAttribute("DashFocus")
		local left = if typeof(untilT) == "number" then math.clamp(untilT - simNow, 0, 1) else 0
		gate.readyAt =
			math.max(gate.readyAt, now + left + (if typeof(delay) == "number" then delay else 0))
		gate.focusUntil = gate.readyAt + (if typeof(window) == "number" then window else 0)
	end
end

return Dash
