--!strict
-- The predicted half of the Mod system (vault/04 Tech/Mod System.md → "The
-- core split"). Runs inside the movement simulation (Simulation/Movement
-- calls stepCharacter first in every step), on the server for every player
-- and on the client for its own character. Only simulation-safe reads and
-- writes, time() for time, and state in character attributes written only
-- here. No remote is involved: the server's run is the truth.
--
-- Reads (player attributes, written by ModService outside the simulation):
--   Mod<n>Id, Mod<n>Level   the loadout
--   ModUnlimitedCharges     test mode: casting spends nothing
--   ModResetSerial          bumped to refill every charge (ModService.refillCharges)
--   Mod<n>Serial            bumped by ModService.setSlot: that slot starts full
--   Mod<n>Carry, Mod<n>CarryAt   charges and next recharge the last life ended
--                           with (a new character starts with these, so dying
--                           doesn't refill)
-- Writes (character attributes):
--   Mod<n>In                last step's Mod<n> input (to detect presses)
--   Mod<n>Key               "id:level" the charges below belong to
--   Mod<n>Charges, Mod<n>RechargeAt   simulation Mods' charges (time() clock)
--   Mod<n>CastAt            time() of the last cast (the client's "just cast")
--   Mod<n>SerialSeen        last Mod<n>Serial applied
--   ModResetSeen            last ModResetSerial applied
--   Dashing + the Dash* attributes of Mods/Dash, RollbackAt / RollbackFrom
--   (Mods/Rollback), LaunchAt / LaunchVelocity / Launching (Mods/LaunchPad);
--   SlideJumpSpeed carries a
--   launch's forward speed through the air like a slide-jump (Movement)

local RunService = game:GetService("RunService")

local Charges = require(script.Parent.Parent.Mods.Charges)
local Config = require(script.Parent.Parent.Config.Mods)
local LaunchPad = require(script.Parent.Parent.Mods.LaunchPad)
local Mods = require(script.Parent.Parent.Mods)
local Rollback = require(script.Parent.Parent.Mods.Rollback)
local Teams = require(script.Parent.Parent.Mods.Teams)
local Types = require(script.Parent.Parent.Mods.Types)

local rollbackConnection: RBXScriptConnection? = nil

local AbilitiesSim = {}

-- Attribute names per slot, built once (the step runs 60 times a second for
-- every character).
type SlotNames = {
	input: string,
	inAttr: string,
	id: string,
	level: string,
	key: string,
	charges: string,
	rechargeAt: string,
	castAt: string,
	carry: string,
	carryAt: string,
	serial: string,
	serialSeen: string,
}
local NAMES: { SlotNames } = {}
for slot = 1, Config.SLOTS do
	local p = "Mod" .. slot
	NAMES[slot] = {
		input = p,
		inAttr = p .. "In",
		id = p .. "Id",
		level = p .. "Level",
		key = p .. "Key",
		charges = p .. "Charges",
		rechargeAt = p .. "RechargeAt",
		castAt = p .. "CastAt",
		carry = p .. "Carry",
		carryAt = p .. "CarryAt",
		serial = p .. "Serial",
		serialSeen = p .. "SerialSeen",
	}
end

local function set(model: Model, name: string, value: any)
	if model:GetAttribute(name) ~= value then
		model:SetAttribute(name, value)
	end
end

local function actionDown(context: Instance?, name: string): boolean
	local action = context and context:FindFirstChild(name)
	if action and action:IsA("InputAction") then
		return action:GetState() == true
	end
	return false
end

local function number(model: Instance, name: string, default: number): number
	local v = model:GetAttribute(name)
	return if typeof(v) == "number" then v else default
end

-- While a dash lasts, hold its horizontal velocity (keeping vertical speed);
-- when it ends, cap the speed carried out of it.
local function stepDash(character: Model, root: BasePart, now: number)
	local untilT = number(character, "DashUntil", 0)
	if now < untilT then
		local v = character:GetAttribute("DashVelocity")
		if typeof(v) == "Vector3" then
			root.AssemblyLinearVelocity = Vector3.new(v.X, root.AssemblyLinearVelocity.Y, v.Z)
		end
		set(character, "Dashing", true)
	elseif character:GetAttribute("Dashing") == true then
		local vel = root.AssemblyLinearVelocity
		local flat = vel * Vector3.new(1, 0, 1)
		local exit = number(character, "DashExit", 16)
		if flat.Magnitude > exit then
			flat = flat.Unit * exit
			root.AssemblyLinearVelocity = Vector3.new(flat.X, vel.Y, flat.Z)
		end
		set(character, "Dashing", false)
	end
end

-- Movement asks this for the walk speed while a dash runs, so the Humanoid
-- doesn't brake against it.
function AbilitiesSim.speedOverride(character: Model, now: number): number?
	if now < number(character, "DashUntil", 0) then
		local v = character:GetAttribute("DashVelocity")
		if typeof(v) == "Vector3" then
			return v.Magnitude
		end
	end
	return nil
end

function AbilitiesSim.stepCharacter(
	player: Player,
	character: Model,
	humanoid: Humanoid,
	root: BasePart,
	context: Instance?,
	now: number
)
	local unlimited = player:GetAttribute("ModUnlimitedCharges") == true
	local resetSerial = number(player, "ModResetSerial", 0)
	-- A new character hasn't seen a refill yet: it starts from the carry.
	local seen = character:GetAttribute("ModResetSeen")
	local reset = typeof(seen) == "number" and seen ~= resetSerial

	-- Your team's launch pads under your feet.
	local carry = LaunchPad.launch(character, humanoid, root, Teams.of(player), now)
	if carry then
		set(character, "SlideJumpSpeed", carry)
	end

	for slot, names in NAMES do
		local input = actionDown(context, names.input)
		local pressed = input and character:GetAttribute(names.inAttr) ~= true
		set(character, names.inAttr, input)

		local id = player:GetAttribute(names.id)
		local level = player:GetAttribute(names.level)
		if typeof(id) ~= "string" or typeof(level) ~= "string" then
			continue
		end
		local def = Mods.def(id)
		local module = Mods.module(id)
		local stats = Mods.stats(id, level)
		if not def or def.authority ~= "Simulation" or not module or not stats then
			continue
		end
		local cast = module.simCast
		if not cast then
			continue
		end

		if id == "Rollback" then
			Rollback.record(character, root, now)
		end

		local key = id .. ":" .. level
		local max: number = stats.charges
		local cooldown: number = stats.cooldown
		local charges = number(character, names.charges, max)
		local rechargeAt = number(character, names.rechargeAt, now)
		local storedKey = character:GetAttribute(names.key)
		local slotSerial = number(player, names.serial, 0)
		local slotSeen = character:GetAttribute(names.serialSeen)
		local refill = reset or (typeof(slotSeen) == "number" and slotSeen ~= slotSerial)
		if refill or storedKey ~= key then
			charges, rechargeAt = max, now
			-- A new life keeps what the last one had left this round.
			local carried = player:GetAttribute(names.carry)
			if not refill and storedKey == nil and typeof(carried) == "number" then
				charges = math.clamp(math.floor(carried), 0, max)
				local carriedAt = player:GetAttribute(names.carryAt)
				if typeof(carriedAt) == "number" then
					rechargeAt = carriedAt
				end
			end
		end
		charges, rechargeAt = Charges.settle(charges, rechargeAt, max, cooldown, now)

		if pressed and (charges >= 1 or unlimited) and humanoid.Health > 0 then
			local ctx: Types.SimCtx = {
				player = player,
				character = character,
				humanoid = humanoid,
				root = root,
				stats = stats,
				slot = slot,
				now = now,
			}
			if cast(ctx) then
				set(character, names.castAt, now)
				if not unlimited then
					charges, rechargeAt = Charges.spend(charges, rechargeAt, max, cooldown, now)
				end
			end
		end
		set(character, names.key, key)
		set(character, names.serialSeen, slotSerial)
		set(character, names.charges, charges)
		set(character, names.rechargeAt, rechargeAt)
	end
	set(character, "ModResetSeen", resetSerial)

	stepDash(character, root, now)
end

-- Call once per side (MovementSim.initialize does): a Server Authority
-- rollback drops the Luau state newer than the step it rewinds to.
function AbilitiesSim.initialize()
	if rollbackConnection then
		return
	end
	LaunchPad.watch()
	local ok, signal = pcall(function()
		return (RunService :: any).Rollback
	end)
	if ok and typeof(signal) == "RBXScriptSignal" then
		rollbackConnection = signal:Connect(function(t: number)
			if typeof(t) == "number" then
				Rollback.onRollback(t)
			end
		end)
	end
end

return AbilitiesSim
