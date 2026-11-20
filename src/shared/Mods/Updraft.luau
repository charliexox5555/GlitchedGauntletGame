--!strict
-- Updraft (Mobility, was Launch Pad; vault/01 Design/Abilities/Updraft.md):
-- an instant launch straight up for yourself, peaking `peak` studs above
-- where you used it. Keeps your horizontal momentum (running + Updraft = an
-- arc); in the air it resets your fall like a double jump. Then a normal
-- fall. Predicted: simCast runs inside the simulation (Simulation/
-- Abilities), on the server for everyone and on your client for yourself;
-- Updraft.step holds the rise while the Humanoid is still on the floor.
--
-- Upgrades (vault/01 Design/Abilities/Upgrade Paths.md → 2. Updraft): path A
-- raises `peak`, path B adds `charges` (numbers only). The glitch path
-- (`behaviour = "Slam"`, Crash Down): a fresh SECOND press of the Updraft
-- input while an Updraft is in the air slams you down at `slamSpeed`
-- (owner, 2026-11-15: was a Crouch press). The first press launches; from
-- then until you land, a press of that input is always Crash Down's
-- (module.simPress) and never another launch, so a held key, a repeat or a
-- second press can't spend a charge. A press in the first `slamArm` seconds
-- waits until then, so a launch can't slam where it stood. The dive keeps up
-- to `slamCarry` studs/s of horizontal speed (and the Humanoid's own air
-- steering inside that cap). The landing is a simulation write; the server's
-- hook (module.server) deals `slamDamage` to enemies within `slamRadius` in
-- sight of it (+ Hinder at G3).
--
-- Character attributes (simulation-written):
--   UpdraftAt     time() of the launch (clients play the effects on change)
--   UpdraftLaunch Vector3(up, gravity, gunDown): the launch's vertical speed
--                 (studs/s), the gravity it was launched under (a status
--                 lowers it), and the seconds from the launch the gun is down
--                 (no shots; both sides gate on it, Mods/Dash.stepGate). One
--                 attribute for three: a character's attributes share a
--                 1024-byte budget under Server Authority
--   Updrafting    true from the launch until you land (nil otherwise)
--   UpdraftSlam   "Queued": a second press waiting for `slamArm`; "Down":
--                 from the slam's start until its landing; nil otherwise
--   UpdraftSlamStart time() the slam started (clients: the dive effects)
--   UpdraftSlamAt / UpdraftSlamPos  time() and root position of the last
--                 slam landing (the server's hook deals the damage)

local StateValues = require(game:GetService("ReplicatedStorage").Shared.StateValues)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Health = require(script.Parent.Parent.Health)
local Config = require(script.Parent.Parent.Config.Mods)
local Movement = require(script.Parent.Parent.Config.Movement)
local Target = require(script.Parent.Blocks.Target)
local Teams = require(script.Parent.Teams)
local Types = require(script.Parent.Types)

local Updraft = {}

-- The Humanoid's ground state brakes a vertical kick for a few steps
-- (measured on the old Launch Pad: 99 → 55 studs/s in one): hold the launch's
-- own arc this long, until it's clear of the floor.
local RISE_HOLD = 0.2

-- The gravity this character falls under (a status like Hinder lowers it:
-- Simulation/Movement gives the rest back every step).
local function gravityOf(player: Player): number
	local mult = StateValues.get(player, "StatusGravityMult")
	return workspace.Gravity * (if typeof(mult) == "number" then mult else 1)
end

-- Launch speed for a peak `peak` studs up under `gravity`.
function Updraft.launchSpeed(peak: number, gravity: number?): number
	return math.sqrt(2 * (gravity or workspace.Gravity) * math.max(peak, 0))
end

local function number(inst: Instance, name: string, default: number): number
	local v = StateValues.get(inst, name)
	return if typeof(v) == "number" then v else default
end

local function set(inst: Instance, name: string, value: any)
	if StateValues.get(inst, name) ~= value then
		StateValues.set(inst, name, value)
	end
end

-- Updraft's stats at `level`, resolved like Mods.stats (Mods/init requires
-- this module, so it can't be required back).
local statsCache: { [string]: Types.Stats } = {}
local function statsAt(level: string): Types.Stats?
	local cached = statsCache[level]
	if cached then
		return cached
	end
	local def = Config.defs.Updraft
	local chain = Config.CHAIN[level]
	if not def or not chain then
		return nil
	end
	local out: Types.Stats = {}
	for _, step in chain do
		local values = def.levels[step]
		if values then
			for k, v in values do
				out[k] = v
			end
		end
	end
	table.freeze(out)
	statsCache[level] = out
	return out
end

local SLOT_ID: { string } = {}
local SLOT_LEVEL: { string } = {}
for slot = 1, Config.SLOTS do
	SLOT_ID[slot] = "Mod" .. slot .. "Id"
	SLOT_LEVEL[slot] = "Mod" .. slot .. "Level"
end

-- The stats of `player`'s Updraft when it's on the Slam path (nil: no
-- Updraft slotted, or another level), and the slot it is in. Reads the
-- loadout attributes, so it works inside the simulation and on any client.
function Updraft.slamStats(player: Player): (Types.Stats?, number?)
	for slot = 1, Config.SLOTS do
		if StateValues.get(player, SLOT_ID[slot]) == "Updraft" then
			local level = StateValues.get(player, SLOT_LEVEL[slot])
			local stats = if typeof(level) == "string" then statsAt(level) else nil
			if stats and stats.behaviour == "Slam" then
				return stats, slot
			end
			return nil, nil
		end
	end
	return nil, nil
end

-- The slam's state in one attribute (a character's attributes share a
-- 1024-byte budget under Server Authority): UpdraftSlam = "Queued" (pressed,
-- waiting for the arm time), "Down" (slamming), nil (none).
local function endSlam(character: Model)
	set(character, "UpdraftSlam", nil)
end

-- The dive's velocity: `slamSpeed` down, keeping at most `slamCarry` studs/s
-- of the horizontal speed it has (the Humanoid's air steering moves it inside
-- that cap, so the landing can be nudged, not flown).
local function diveVelocity(root: BasePart, slam: Types.Stats): Vector3
	local vel = root.AssemblyLinearVelocity
	local flat = Vector3.new(vel.X, 0, vel.Z)
	local carry: number = slam.slamCarry or 0
	local speed = flat.Magnitude
	if speed > carry then
		flat = if carry > 0 and speed > 1e-3 then flat.Unit * carry else Vector3.zero
	end
	return Vector3.new(flat.X, -slam.slamSpeed, flat.Z)
end

local function startSlam(character: Model, root: BasePart, slam: Types.Stats, now: number)
	set(character, "UpdraftSlam", "Down")
	set(character, "UpdraftSlamStart", now)
	-- No slide-jump air speed in the dive: walk-speed steering, capped by slamCarry.
	set(character, "SlideJumpSpeed", 0)
	root.AssemblyLinearVelocity = diveVelocity(root, slam)
end

-- Simulation, every step (before the cast): holds the rise, runs a slam, and
-- ends the Updraft on landing.
function Updraft.step(
	player: Player,
	character: Model,
	humanoid: Humanoid,
	root: BasePart,
	_context: Instance?,
	now: number
)
	if StateValues.get(character, "Updrafting") ~= true then
		return
	end
	local slam = Updraft.slamStats(player)
	local since = now - number(character, "UpdraftAt", 0)
	local airborne = humanoid.FloorMaterial == Enum.Material.Air

	if slam then
		if StateValues.get(character, "UpdraftSlam") == "Down" then
			if airborne then
				root.AssemblyLinearVelocity = diveVelocity(root, slam)
			else
				endSlam(character)
				set(character, "Updrafting", nil)
				StateValues.set(character, "UpdraftSlamPos", root.Position)
				StateValues.set(character, "UpdraftSlamAt", now)
			end
			return
		end
		-- A second press that came before the arm time (module.simPress).
		if
			StateValues.get(character, "UpdraftSlam") == "Queued"
			and since >= slam.slamArm
			and airborne
		then
			startSlam(character, root, slam, now)
			return
		end
	end

	if since < RISE_HOLD then
		local launch = StateValues.get(character, "UpdraftLaunch")
		local gravity = if typeof(launch) == "Vector3" then launch.Y else workspace.Gravity
		local up = (if typeof(launch) == "Vector3" then launch.X else 0) - gravity * since
		local vel = root.AssemblyLinearVelocity
		if vel.Y < up then
			root.AssemblyLinearVelocity = Vector3.new(vel.X, up, vel.Z)
		end
	elseif not airborne then
		endSlam(character) -- a press still waiting is dropped
		set(character, "Updrafting", nil) -- landed
	end
end

-- Server: a slam landed with the root at `center` (the server's own
-- simulation wrote it, or with Server Authority off the server's view of the
-- root when the owner's client reported it). Enemies within `slamRadius` of
-- the root, in sight of it, take `slamDamage` (no self or team damage),
-- Hindered at G3.
local function slamLanded(api: Types.ServerApi, player: Player, character: Model, center: Vector3)
	local _, level = api.slotOf(player, "Updraft")
	local stats = if level then statsAt(level) else nil
	if not stats or stats.behaviour ~= "Slam" then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not Health.isAlive(humanoid) or not root or not root:IsA("BasePart") then
		return
	end
	local params = api.worldParams()
	local hinder: number? = stats.slamHinder
	local hits = 0
	for _, model in Target.combatants() do
		if model == character or not Target.alive(model) or Teams.isAlly(player, model) then
			continue
		end
		local body = model:FindFirstChild("HumanoidRootPart")
		local point = if body and body:IsA("BasePart")
			then body.Position
			else Target.aimPoint(model)
		if
			point
			and (point - center).Magnitude <= stats.slamRadius
			and Target.visible(center, model, params)
		then
			api.damage(player, model, stats.slamDamage, point, "Updraft")
			if hinder then
				api.status(model, "Hinder", hinder)
			end
			hits += 1
		end
	end
	local feet = center - Vector3.new(0, humanoid.HipHeight + root.Size.Y * 0.5, 0)
	api.fx(player, "Updraft", "UpdraftSlam", {
		at = feet,
		radius = stats.slamRadius,
		hits = hits,
		hinder = hinder ~= nil,
	})
end

local module: Types.ModModule = {}

-- Server Authority off: follows the flights players report (defined with
-- module.simReport at the end of this file; started by module.server).
local followFlights: () -> ()

module.simCast = function(ctx: Types.SimCtx): boolean
	local root = ctx.root
	local character = ctx.character
	local gravity = gravityOf(ctx.player)
	local up = Updraft.launchSpeed(ctx.stats.peak, gravity)
	local vel = root.AssemblyLinearVelocity
	-- Straight up, from whatever you were doing (a fall is reset).
	root.AssemblyLinearVelocity = Vector3.new(vel.X, up, vel.Z)
	-- Carry the running speed through the air (Movement's air speed), like a
	-- slide-jump, up to maxCarry (a dash's 80 studs/s isn't running speed):
	-- the counter-play is a predictable arc.
	local flat = (vel * Vector3.new(1, 0, 1)).Magnitude
	local carry =
		math.clamp(flat, Movement.WALK_SPEED, math.max(ctx.stats.maxCarry, Movement.WALK_SPEED))
	StateValues.set(character, "SlideJumpSpeed", carry)
	StateValues.set(character, "UpdraftAt", ctx.now)
	StateValues.set(character, "UpdraftLaunch", Vector3.new(up, gravity, ctx.stats.gunDown))
	StateValues.set(character, "Updrafting", true)
	-- A launch always starts without a slam (a stale one from a lost landing).
	endSlam(character)
	return true
end

-- A fresh press of the Updraft input. While an Updraft with Crash Down is in
-- the air (Updrafting: from the launch until the landing) the press is the
-- slam's: it starts the dive, or waits for the arm time, and is never a
-- second launch, whether or not a charge is left. Outside that window (on
-- the ground, after a landing, without Crash Down) it returns false and the
-- press is an ordinary cast.
module.simPress = function(ctx: Types.SimCtx): boolean
	local character = ctx.character
	local slam = ctx.stats
	if slam.behaviour ~= "Slam" or StateValues.get(character, "Updrafting") ~= true then
		return false
	end
	if StateValues.get(character, "UpdraftSlam") == nil then
		local since = ctx.now - number(character, "UpdraftAt", 0)
		local airborne = ctx.humanoid.FloorMaterial == Enum.Material.Air
		if airborne and since >= slam.slamArm then
			startSlam(character, ctx.root, slam, ctx.now)
		else
			set(character, "UpdraftSlam", "Queued")
		end
	end
	return true
end

-- Watches every character's slam landings (the server's simulation writes
-- UpdraftSlamAt; a value seen on the first look is old). With Server
-- Authority off this only ever fires for characters the server simulates;
-- players' landings come in through module.simReport.
module.server = function(api: Types.ServerApi)
	local seen: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
	RunService.Heartbeat:Connect(function()
		for _, player in Players:GetPlayers() do
			local character = player.Character
			if not character then
				continue
			end
			local at = number(character, "UpdraftSlamAt", 0)
			local last = seen[character]
			seen[character] = at
			local center = StateValues.get(character, "UpdraftSlamPos")
			if last ~= nil and at > last and typeof(center) == "Vector3" then
				slamLanded(api, player, character, center)
			end
		end
	end)
	followFlights()
end

-- Server Authority off ----------------------------------------------------------
-- The owner's client simulates the Updraft, so the server follows a flight
-- from its reports (Services/ModSim: a "Cast" already cost a charge on the
-- server's own count). Nothing the client sends is used: every check and the
-- slam's centre come from the server's view of the character, sampled every
-- frame while the flight lasts (Config/Mods SIM_REPORT holds the limits).
type Flight = {
	character: Model,
	at: number, -- time() of the launch report
	from: Vector3, -- the root then
	peak: number, -- the highest the server has seen the root since
	slamAt: number?, -- time() of the dive report
}
-- By player (strong: a weak table keyed by an Instance can drop a live entry).
local flights: { [Player]: Flight } = {}

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Where the root stands once it's down: the server sees a client-owned
-- character a little late, so a root still up to `slamFloorReach` above the
-- floor counts as landed, on that floor. nil: no floor under it (no slam).
local function landedRoot(
	api: Types.ServerApi,
	humanoid: Humanoid,
	root: BasePart,
	reach: number
): Vector3?
	local stand = humanoid.HipHeight + root.Size.Y * 0.5
	local hit =
		workspace:Raycast(root.Position, Vector3.new(0, -(stand + reach), 0), api.worldParams())
	if not hit then
		return nil
	end
	return Vector3.new(root.Position.X, hit.Position.Y + stand, root.Position.Z)
end

-- Every frame: how high each flight has been, and no flight outlives its
-- player or its time.
followFlights = function()
	RunService.Heartbeat:Connect(function()
		local now = time()
		for player, flight in flights do
			local root = flight.character:FindFirstChild("HumanoidRootPart")
			if
				player.Character ~= flight.character
				or not root
				or not root:IsA("BasePart")
				or now - flight.at > Config.SIM_REPORT.flightLife
			then
				flights[player] = nil
			else
				flight.peak = math.max(flight.peak, root.Position.Y)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		flights[player] = nil
	end)
end

module.simReport = function(api: Types.ServerApi, report: Types.SimReport): { [string]: any }?
	local player = report.player
	local character = report.character
	local root = report.root
	local stats = report.stats
	local now = report.now
	local tune = Config.SIM_REPORT

	if report.kind == "Cast" then
		local y = root.Position.Y
		flights[player] = { character = character, at = now, from = root.Position, peak = y }
		-- The gun is down for the launch on the server's shot gate too.
		api.gunDown(player, stats.gunDown, nil)
		local gravity = gravityOf(player)
		return {
			launch = Vector3.new(Updraft.launchSpeed(stats.peak, gravity), gravity, stats.gunDown),
		}
	end

	local flight = flights[player]
	if not flight or flight.character ~= character then
		flights[player] = nil
		-- A landing still ends the flight other players are watching.
		return if report.kind == "Land" then { slam = false } else nil
	end
	flight.peak = math.max(flight.peak, root.Position.Y)
	local since = now - flight.at

	if report.kind == "Slam" then
		-- Armed (less a little jitter between the two clocks), once per
		-- flight, and only after the server saw the root actually go up.
		if
			stats.behaviour ~= "Slam"
			or flight.slamAt ~= nil
			or since < stats.slamArm - tune.armSlack
			or flight.peak - flight.from.Y < tune.slamMinRise
		then
			return nil
		end
		flight.slamAt = now
		return {}
	elseif report.kind == "Land" then
		flights[player] = nil
		local slamAt = flight.slamAt
		if not slamAt then
			return { slam = false }
		end
		-- The damage: a dive that took some time, landing within what the
		-- carried speed could cover since the launch and not far below it,
		-- on a floor, outside a round lock.
		local reach = math.min(tune.slamMaxTravel, stats.maxCarry * since + tune.slamTravelSlack)
		if
			not report.locked
			and now - slamAt >= tune.slamMinDive
			and flat(root.Position - flight.from).Magnitude <= reach
			and flight.from.Y - root.Position.Y <= tune.slamMaxDrop
		then
			local center = landedRoot(api, report.humanoid, root, tune.slamFloorReach)
			if center then
				slamLanded(api, player, character, center)
			end
		end
		return { slam = true }
	end
	return nil
end

Updraft.module = module

return Updraft
