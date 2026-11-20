--!strict
-- The predicted Mods (Dash, Updraft) with Server Authority OFF (shared/
-- Authority, vault/04 Tech/Architecture.md → Authority mode). Each client
-- simulates its own character there, so the simulation attributes those Mods
-- write never reach the server or the other clients: a Crash Down landing
-- dealt no damage, a Ghost dash blocked nothing and nobody saw a decoy.
--
-- The owner's client reports each event on the ModSim remote (Controllers/
-- ModSimController): ModSim(slot, kind, data), kind "Cast" | "Slam" | "Land".
-- This module checks the report and hands it to the Mod's `simReport`
-- (Mods/Dash, Mods/Updraft), which does the server's part from the server's
-- own view of the character and returns what the other clients need to draw
-- it. That goes out on ModSimFx to everyone but the owner (who already sees
-- its own prediction), with times as seconds from now: each client writes
-- them onto that character in its own clock.
--
-- What is trusted: nothing that decides anything. The sender, the slot's Mod
-- and level, life, the round lock and the rate limit are checked here. A
-- "Cast" must be paid from the server's own charge count (the same refill,
-- recharge and per-round rules as Simulation/Abilities, so a client can't
-- cast more often than the Mod allows, whatever it claims). Positions and
-- windows come from the server; `data` only shapes cosmetics, clamped by the
-- Mod. With Server Authority on this module does nothing (the server
-- simulates every character itself).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateValues = require(ReplicatedStorage.Shared.StateValues)

local Shared = ReplicatedStorage.Shared
local Authority = require(Shared.Authority)
local Charges = require(Shared.Mods.Charges)
local Config = require(Shared.Config.Mods)
local Health = require(Shared.Health)
local MatchState = require(Shared.MatchState)
local Mods = require(Shared.Mods)
local ModTypes = require(Shared.Mods.Types)
local Net = require(Shared.Net)
local RateLimit = require(Shared.Util.RateLimit)
local Validate = require(Shared.Util.Validate)

local ModSim = {}

local KINDS: { [string]: boolean } = { Cast = true, Slam = true, Land = true }
-- Fields a report may carry (a bigger table is dropped unread).
local MAX_FIELDS = 6

-- The server's own count of each slot's charges (Simulation/Abilities keeps
-- the client's). Kept per player, not per character: a new life keeps what
-- the last one had left this round, as there.
type Shadow = { key: string, charges: number, rechargeAt: number, reset: number, serial: number }
local shadows: { [Player]: { [number]: Shadow } } = {}

local function number(inst: Instance, name: string): number
	local v = StateValues.get(inst, name)
	return if typeof(v) == "number" then v else 0
end

-- Pays one charge of `slot` from the server's count. False: none left.
local function spend(
	player: Player,
	slot: number,
	key: string,
	stats: ModTypes.Stats,
	now: number
): boolean
	if StateValues.get(player, "ModUnlimitedCharges") == true then
		return true
	end
	local max: number = stats.charges
	local cooldown: number = stats.cooldown
	local reset = number(player, "ModResetSerial")
	local serial = number(player, "Mod" .. slot .. "Serial")
	local bySlot = shadows[player]
	if not bySlot then
		bySlot = {}
		shadows[player] = bySlot
	end
	local shadow = bySlot[slot]
	-- Another Mod or level in the slot, a round refill, a re-slot: full again.
	if not shadow or shadow.key ~= key or shadow.reset ~= reset or shadow.serial ~= serial then
		shadow = { key = key, charges = max, rechargeAt = now, reset = reset, serial = serial }
		bySlot[slot] = shadow
	end
	local had = shadow.charges
	local dueAt = shadow.rechargeAt
	local charges, rechargeAt =
		Charges.settle(had, dueAt, max, cooldown, now + Config.SIM_REPORT.grace)
	if charges < 1 then
		shadow.charges, shadow.rechargeAt = charges, rechargeAt
		return false
	end
	-- A charge the grace let through early is spent when it was really due,
	-- so the slack can't add up cast after cast.
	local spentAt = if charges > had then math.max(now, dueAt) else now
	shadow.charges, shadow.rechargeAt = Charges.spend(charges, rechargeAt, max, cooldown, spentAt)
	return true
end

-- The charges the server counts in `slot` for the Mod and level `key`, for a
-- life that just ended (ModService carries them into the next one, so the
-- new character's simulation starts where the server is). nil: nothing
-- counted for this loadout since the last refill, so the slot is full.
function ModSim.left(player: Player, slot: number, key: string): number?
	local bySlot = shadows[player]
	local shadow = bySlot and bySlot[slot]
	if
		not shadow
		or shadow.key ~= key
		or shadow.reset ~= number(player, "ModResetSerial")
		or shadow.serial ~= number(player, "Mod" .. slot .. "Serial")
	then
		return nil
	end
	return shadow.charges
end

local function fieldCount(t: { [any]: any }): number
	local n = 0
	for _ in t do
		n += 1
		if n > MAX_FIELDS then
			break
		end
	end
	return n
end

local function onReport(
	api: ModTypes.ServerApi,
	limiter: RateLimit.Limiter,
	player: Player,
	slotArg: unknown,
	kindArg: unknown,
	dataArg: unknown
)
	if not limiter:allow(player, "ModSim") then
		return
	end
	local slot = Validate.integer(slotArg, 1, Config.SLOTS)
	local kind = Validate.enum(kindArg, KINDS)
	if not slot or not kind then
		return
	end
	local data: { [string]: unknown } = {}
	if typeof(dataArg) == "table" then
		if fieldCount(dataArg :: any) > MAX_FIELDS then
			return
		end
		data = dataArg :: any
	elseif dataArg ~= nil then
		return
	end

	local id = StateValues.get(player, "Mod" .. slot .. "Id")
	local level = StateValues.get(player, "Mod" .. slot .. "Level")
	if typeof(id) ~= "string" or typeof(level) ~= "string" then
		return
	end
	local def = Mods.def(id)
	local module = Mods.module(id)
	local stats = Mods.stats(id, level)
	local report = module and module.simReport
	if not def or def.authority ~= "Simulation" or not report or not stats then
		return
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if
		not character
		or not humanoid
		or not Health.isAlive(humanoid)
		or not root
		or not root:IsA("BasePart")
	then
		return
	end

	local now = time()
	local locked = StateValues.get(player, MatchState.COMBAT_LOCKED) == true
	if kind ~= "Land" then
		-- No casts and no dives behind the barrier, between rounds or while
		-- frozen (as Simulation/Abilities and ModService refuse them). A
		-- landing still goes through, to end the flight (`locked`: no damage).
		if locked or StateValues.get(player, "StatusStunned") == true then
			return
		end
		if kind == "Cast" and not spend(player, slot, id .. ":" .. level, stats, now) then
			return
		end
	end

	local ok, mirror = pcall(
		report,
		api,
		{
			player = player,
			character = character,
			humanoid = humanoid,
			root = root,
			stats = stats,
			level = level,
			kind = kind,
			data = data,
			now = now,
			locked = locked,
		} :: ModTypes.SimReport
	)
	if not ok then
		warn("[ModSim] report failed:", mirror)
		return
	end
	if typeof(mirror) ~= "table" then
		return
	end
	local event = Net.event("ModSimFx")
	for _, other in Players:GetPlayers() do
		if other ~= player then
			event:FireClient(other, player, id, kind, mirror)
		end
	end
end

-- Called once by ModService.start with its Mod hooks' api and its limiter
-- (Config/Mods RATE.ModSim).
function ModSim.bind(api: ModTypes.ServerApi, limiter: RateLimit.Limiter)
	if Authority.server() then
		return
	end
	Net.event("ModSim").OnServerEvent
		:Connect(function(player: Player, slotArg: unknown, kindArg: unknown, dataArg: unknown)
			-- Shape first; onReport then checks the range, the kind, the rate,
			-- the loadout and the charge.
			if
				typeof(slotArg) ~= "number"
				or typeof(kindArg) ~= "string"
				or (dataArg ~= nil and typeof(dataArg) ~= "table")
			then
				return
			end
			onReport(api, limiter, player, slotArg, kindArg, dataArg)
		end)
	Players.PlayerRemoving:Connect(function(player: Player)
		shadows[player] = nil
	end)
end

return ModSim
