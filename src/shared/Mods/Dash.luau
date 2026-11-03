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
-- Upgrade levels (vault/01 Design/Abilities/Dash.md → Upgrades), nil when
-- the level doesn't have them (each cast rewrites them, so a stale one from
-- another level can't linger):
--   DashDodgeUntil    B2/B3 Ghost: time() until which damage passes through
--                     you (the server's guard below; everyone sees the ghost)
--   DashCloakUntil    B3 Ghost, G3 Desync: time() until which you're nearly
--                     invisible (client-side per viewer, UpgradeFx/Dash)
--   DashDecoyFrom, DashDecoyYaw, DashDecoyVelocity, DashDecoyUntil
--                     G2/G3 Desync: where the decoy starts, its facing, the
--                     way it keeps running and when it glitches out
--   DashDecoyFires    G3: the decoy fires fake shots

local Types = require(script.Parent.Types)
local DashBlock = require(script.Parent.Blocks.Dash)

local Dash = {}

local module: Types.ModModule = {}

-- The simulation's fixed step (Simulation/Movement STEP). A dash lasts a
-- whole number of steps, so a fast one (A3: 160 studs/s, 2.7 studs a step)
-- ends exactly at the wall instead of overshooting into it.
local SIM_STEP = 1 / 60

-- G2/G3 Desync: the way the decoy keeps running: the way you were already
-- going (the press may have changed the input, not yet the velocity), or
-- your facing from a standstill, at a run.
local function decoyVelocity(stats: Types.Stats, root: BasePart): Vector3
	local flat = root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
	local speed = math.clamp(flat.Magnitude, stats.decoyMinSpeed, stats.decoyMaxSpeed)
	if flat.Magnitude > 2 then
		return flat.Unit * speed
	end
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	return if look.Magnitude > 0.01 then look.Unit * speed else Vector3.zero
end

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
	-- Whole steps at no more than the full speed, covering exactly `reach`.
	-- DashUntil sits half a step before the end of the last one, so the
	-- `now < DashUntil` check can't hold the velocity a step too long.
	local steps = math.max(math.ceil(stats.duration * reach / stats.distance / SIM_STEP - 1e-6), 1)
	local duration = steps * SIM_STEP
	local character = ctx.character
	local now = ctx.now

	-- The upgrade levels' attributes go first: clients key on DashStart.
	character:SetAttribute(
		"DashDodgeUntil",
		if stats.dodgeWindow then now + stats.dodgeWindow else nil
	)
	local cloakUntil: number? = nil
	if stats.cloakAfter then
		cloakUntil = now + duration + stats.cloakAfter
	elseif stats.decoyCloak then
		cloakUntil = now + stats.decoyTime
	end
	character:SetAttribute("DashCloakUntil", cloakUntil)
	local desync = stats.behaviour == "Desync"
	character:SetAttribute("DashDecoyFrom", if desync then root.Position else nil)
	character:SetAttribute(
		"DashDecoyYaw",
		if desync then math.atan2(-root.CFrame.LookVector.X, -root.CFrame.LookVector.Z) else nil
	)
	character:SetAttribute("DashDecoyVelocity", if desync then decoyVelocity(stats, root) else nil)
	character:SetAttribute("DashDecoyUntil", if desync then now + stats.decoyTime else nil)
	character:SetAttribute("DashDecoyFires", if desync and stats.decoyFires then true else nil)

	character:SetAttribute("DashStart", now)
	character:SetAttribute("DashUntil", now + duration - SIM_STEP / 2)
	character:SetAttribute("DashVelocity", dir * (reach / duration))
	character:SetAttribute("DashExit", stats.exitSpeed)
	character:SetAttribute("DashFireDelay", stats.fireDelay)
	character:SetAttribute("DashFocus", stats.focusWindow)
	return true
end

-- B2/B3 Ghost: while the dasher's dodge window is open on the server's own
-- simulation clock, every hit on them passes through (HitConfirm shows the
-- shooter "blocked"). Runs for every hit in the game: one attribute read.
module.server = function(api: Types.ServerApi)
	api.guard(
		function(victim: Model, _humanoid: Humanoid, amount: number, _attacker: Player?): number
			local untilT = victim:GetAttribute("DashDodgeUntil")
			if typeof(untilT) == "number" and time() < untilT then
				return 0
			end
			return amount
		end
	)
end

Dash.module = module

-- The gun gate around a dash, kept per character by WeaponController (our
-- own) and WeaponService (everyone, the truth), each on its own os.clock():
-- the gun is down until `readyAt` (the rest of the dash plus DashFireDelay),
-- then the first shot until `focusUntil` has no movement spread (Dash Focus).
-- Keyed on DashStart, so a chained dash pushes it on and a frame that
-- missed the Dashing flag can't skip it. An Updraft lowers the gun too
-- (UpdraftGunDown seconds from UpdraftAt), with no Focus after it.
export type GunGate = {
	lastStart: number, -- DashStart of the last dash seen
	lastUpdraft: number, -- UpdraftAt of the last Updraft seen
	readyAt: number,
	focusUntil: number,
	focusOpen: boolean,
}

function Dash.newGate(): GunGate
	return {
		lastStart = 0,
		lastUpdraft = 0,
		readyAt = -math.huge,
		focusUntil = -math.huge,
		focusOpen = false,
	}
end

-- A new life: forget the last one's dash (its character had its own DashStart).
function Dash.resetGate(gate: GunGate)
	gate.lastStart = 0
	gate.lastUpdraft = 0
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
	local updraft = character:GetAttribute("UpdraftAt")
	if typeof(updraft) == "number" and updraft > gate.lastUpdraft + 0.05 then
		gate.lastUpdraft = updraft
		local down = character:GetAttribute("UpdraftGunDown")
		local left = if typeof(down) == "number"
			then math.clamp(updraft + down - simNow, 0, 1)
			else 0
		gate.readyAt = math.max(gate.readyAt, now + left)
	end
end

return Dash
