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
--   DashTune      Vector3(exit, fireDelay, focus): the horizontal speed kept
--                 when it ends; seconds after it ends before the gun can fire
--                 (both sides gate shots on this; WeaponService checks it on
--                 its own); the Dash Focus window (the first shot this soon
--                 after the gun is back up has no movement or air spread).
--                 One attribute for three: a character's attributes share a
--                 1024-byte budget under Server Authority
-- Upgrade levels (vault/01 Design/Abilities/Dash.md → Upgrades), nil when
-- the level doesn't have them (each cast rewrites them, so a stale one from
-- another level can't linger). Packed into three attributes: a character's
-- attributes share a 1024-byte budget under Server Authority (read them
-- with Dash.windows / Dash.decoy):
--   DashWindows   Vector3(dodge, cloak, decoy): time() until which
--                 B2/B3 Ghost lets damage pass through you (the server's
--                 guard below; everyone sees the ghost), B3 Ghost / G3
--                 Desync keeps you nearly invisible (client-side per viewer,
--                 UpgradeFx/Dash), and the G2/G3 decoy runs; 0 = none
--   DashDecoy     G2/G3 Desync: CFrame where the decoy starts, facing its yaw
--   DashDecoyRun  the way it keeps running (flat); Y = 1 when it fires
--                 fake shots (G3)

local StateValues = require(game:GetService("ReplicatedStorage").Shared.StateValues)

local Players = game:GetService("Players")

local Types = require(script.Parent.Types)
local DashBlock = require(script.Parent.Blocks.Dash)
local Validate = require(script.Parent.Parent.Util.Validate)

local Dash = {}

local module: Types.ModModule = {}

-- Server Authority off: the character and the time() until which each
-- player's Ghost dodge window is open, from the server's clock
-- (module.simReport). The DashWindows attribute carries it when the server
-- simulates the character itself. By player, strong (a weak table keyed by
-- an Instance can drop a live entry); cleared when the player leaves.
local serverDodge: { [Player]: { character: Model, untilT: number } } = {}

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
	local dodgeUntil = if stats.dodgeWindow then now + stats.dodgeWindow else 0
	local cloakUntil = 0
	if stats.cloakAfter then
		cloakUntil = now + duration + stats.cloakAfter
	elseif stats.decoyCloak then
		cloakUntil = now + stats.decoyTime
	end
	local desync = stats.behaviour == "Desync"
	local decoyUntil = if desync then now + stats.decoyTime else 0
	local any = dodgeUntil > 0 or cloakUntil > 0 or decoyUntil > 0
	StateValues.set(
		character,
		"DashWindows",
		if any then Vector3.new(dodgeUntil, cloakUntil, decoyUntil) else nil
	)
	local yaw = math.atan2(-root.CFrame.LookVector.X, -root.CFrame.LookVector.Z)
	StateValues.set(
		character,
		"DashDecoy",
		if desync then CFrame.new(root.Position) * CFrame.Angles(0, yaw, 0) else nil
	)
	local run = if desync then decoyVelocity(stats, root) else nil
	StateValues.set(
		character,
		"DashDecoyRun",
		if run then Vector3.new(run.X, if stats.decoyFires then 1 else 0, run.Z) else nil
	)

	StateValues.set(character, "DashStart", now)
	StateValues.set(character, "DashUntil", now + duration - SIM_STEP / 2)
	StateValues.set(character, "DashVelocity", dir * (reach / duration))
	StateValues.set(
		character,
		"DashTune",
		Vector3.new(stats.exitSpeed, stats.fireDelay, stats.focusWindow)
	)
	return true
end

-- B2/B3 Ghost: while the dasher's dodge window is open on the server's own
-- simulation clock, every hit on them passes through (HitConfirm shows the
-- shooter "blocked"). Runs for every hit in the game: one attribute read.
module.server = function(api: Types.ServerApi)
	api.guard(
		function(victim: Model, _humanoid: Humanoid, amount: number, _attacker: Player?): number
			local now = time()
			local dodgeUntil = Dash.windows(victim)
			if now < dodgeUntil then
				return 0
			end
			local owner = Players:GetPlayerFromCharacter(victim)
			local reported = owner and serverDodge[owner]
			if reported and reported.character == victim and now < reported.untilT then
				return 0
			end
			return amount
		end
	)
	Players.PlayerRemoving:Connect(function(player: Player)
		serverDodge[player] = nil
	end)
end

-- Server Authority off: the owner's client simulates the dash, so the server
-- hears of it here (Services/ModSim: the report already cost a charge on the
-- server's own count). The dodge window is the server's, from its own clock
-- and the level's stats. What the client sent only shapes what other players
-- see (the dash's line and length, the way the decoy runs), each value
-- checked and clamped to what this level can do.
module.simReport = function(api: Types.ServerApi, report: Types.SimReport): { [string]: any }?
	if report.kind ~= "Cast" then
		return nil
	end
	local stats = report.stats
	local data = report.data
	local root = report.root

	if stats.dodgeWindow then
		serverDodge[report.player] =
			{ character = report.character, untilT = report.now + stats.dodgeWindow }
	end
	-- The gun is down for the whole dash and its fire delay on the server's
	-- shot gate too, whatever the client does (a Ghost can't shoot from
	-- inside its dodge window by reporting a dash it never made).
	api.gunDown(report.player, stats.duration + stats.fireDelay, stats.focusWindow)

	-- (A one-step dash reports half a step: DashUntil sits half a step early.)
	local duration = Validate.number(data.dur, SIM_STEP / 2, stats.duration + SIM_STEP)
		or stats.duration
	local velocity = Validate.vector(data.vel)
	local flatVel = if velocity then Vector3.new(velocity.X, 0, velocity.Z) else Vector3.zero
	local top = stats.distance / stats.duration
	if flatVel.Magnitude > top then
		flatVel = flatVel.Unit * top
	end

	local desync = stats.behaviour == "Desync"
	local cloak = 0
	if stats.cloakAfter then
		cloak = duration + stats.cloakAfter
	elseif stats.decoyCloak then
		cloak = stats.decoyTime
	end
	local mirror: { [string]: any } = {
		dur = duration,
		vel = flatVel,
		tune = Vector3.new(stats.exitSpeed, stats.fireDelay, stats.focusWindow),
		-- Seconds from now (0 = none): dodge, cloak, decoy.
		windows = Vector3.new(stats.dodgeWindow or 0, cloak, if desync then stats.decoyTime else 0),
	}
	if desync then
		-- The decoy starts where the server sees the dasher, facing its yaw.
		local look = root.CFrame.LookVector
		mirror.decoy = CFrame.new(root.Position) * CFrame.Angles(0, math.atan2(-look.X, -look.Z), 0)
		local run = Validate.vector(data.run)
		local flatRun = if run then Vector3.new(run.X, 0, run.Z) else Vector3.zero
		if flatRun.Magnitude > 0.01 then
			flatRun = flatRun.Unit
				* math.clamp(flatRun.Magnitude, stats.decoyMinSpeed, stats.decoyMaxSpeed)
		end
		mirror.run = Vector3.new(flatRun.X, if stats.decoyFires then 1 else 0, flatRun.Z)
	end
	return mirror
end

Dash.module = module

-- The upgrade windows a dash opened (time(); 0 = none): dodge, cloak, decoy.
function Dash.windows(character: Instance): (number, number, number)
	local w = StateValues.get(character, "DashWindows")
	if typeof(w) ~= "Vector3" then
		return 0, 0, 0
	end
	return w.X, w.Y, w.Z
end

-- The Desync decoy of the last dash: where it starts, its yaw, the way it
-- runs (flat) and whether it fires fake shots. nil `from`: no decoy.
function Dash.decoy(character: Instance): (Vector3?, number, Vector3, boolean)
	local cf = StateValues.get(character, "DashDecoy")
	local run = StateValues.get(character, "DashDecoyRun")
	if typeof(cf) ~= "CFrame" or typeof(run) ~= "Vector3" then
		return nil, 0, Vector3.zero, false
	end
	local _, yaw, _ = cf:ToOrientation()
	return cf.Position, yaw, Vector3.new(run.X, 0, run.Z), run.Y > 0.5
end

-- The gun gate around a dash, kept per character by WeaponController (our
-- own) and WeaponService (everyone, the truth), each on its own os.clock():
-- the gun is down until `readyAt` (the rest of the dash plus DashFireDelay),
-- then the first shot until `focusUntil` has no movement spread (Dash Focus).
-- Keyed on DashStart, so a chained dash pushes it on and a frame that
-- missed the Dashing flag can't skip it. An Updraft lowers the gun too
-- (UpdraftLaunch's gun-down seconds from UpdraftAt), with no Focus after it.
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

-- Server Authority off (Services/ModSim): a reported dash or launch lowers
-- the gun for `down` seconds from `now` (os.clock()). `focus`: a dash's Focus
-- window once it's back up (nil: none, an Updraft).
function Dash.pushGate(gate: GunGate, now: number, down: number, focus: number?)
	gate.readyAt = math.max(gate.readyAt, now + down)
	if focus then
		gate.focusOpen = true
		gate.focusUntil = gate.readyAt + focus
	end
end

-- Call every frame. `now`: os.clock(); `simNow`: time() (the simulation's
-- clock, which DashUntil is on).
function Dash.stepGate(gate: GunGate, character: Model, now: number, simNow: number)
	local start = StateValues.get(character, "DashStart")
	local fresh = false
	-- (A re-simulated start a few ms off isn't a new dash.)
	if typeof(start) == "number" and start > gate.lastStart + 0.05 then
		gate.lastStart = start
		gate.focusOpen = true
		fresh = true
	end
	if fresh or StateValues.get(character, "Dashing") == true then
		local untilT = StateValues.get(character, "DashUntil")
		local tune = StateValues.get(character, "DashTune")
		local delay = if typeof(tune) == "Vector3" then tune.Y else nil
		local window = if typeof(tune) == "Vector3" then tune.Z else nil
		local left = if typeof(untilT) == "number" then math.clamp(untilT - simNow, 0, 1) else 0
		gate.readyAt =
			math.max(gate.readyAt, now + left + (if typeof(delay) == "number" then delay else 0))
		gate.focusUntil = gate.readyAt + (if typeof(window) == "number" then window else 0)
	end
	local updraft = StateValues.get(character, "UpdraftAt")
	if typeof(updraft) == "number" and updraft > gate.lastUpdraft + 0.05 then
		gate.lastUpdraft = updraft
		local launch = StateValues.get(character, "UpdraftLaunch")
		local down = if typeof(launch) == "Vector3" then launch.Z else nil
		local left = if typeof(down) == "number"
			then math.clamp(updraft + down - simNow, 0, 1)
			else 0
		gate.readyAt = math.max(gate.readyAt, now + left)
	end
end

return Dash
