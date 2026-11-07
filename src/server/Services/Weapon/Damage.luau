--!strict
-- Every point of damage and healing in a fight, for WeaponService (which
-- re-exports the public half: hurt, damage, damageBy, heal, the guard and
-- modifier hooks, onHit). Guns, Mods and bots all go through here: Mod
-- modifiers, Mod guards, shield first, then health, then the feedback
-- (hit confirm, damage direction, kill feed, hit listeners). Amounts always
-- come from server code, never from a client. A plain module: no init/start.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Combat = require(Shared.Config.Combat)
local Health = require(Shared.Health)
local Net = require(Shared.Net)
local Types = require(Shared.Types)

local HealthService = require(script.Parent.Parent.HealthService)
local Targets = require(script.Parent.Targets)

type HitZone = Types.HitZone

-- Every hit from players and bots alike (StatsService): attacker is a Player
-- or a bot's model. Listeners only observe: nothing they do feeds back.
export type HitListener = (attacker: Instance, victim: Model, dealt: number, killed: boolean) -> ()
-- Damage rules from Mods (ModService's ServerApi): modifiers change
-- player-on-player damage, guards see every hit and may block it.
export type DamageGuard = (
	victim: Model,
	humanoid: Humanoid,
	amount: number,
	attacker: Player?
) -> number
export type DamageModifier = (
	attacker: Player,
	victim: Model,
	amount: number,
	sourceId: string
) -> number

local Damage = {}

local hitListeners: { HitListener } = {}
local damageGuards: { DamageGuard } = {}
local damageModifiers: { DamageModifier } = {}

local function tellHit(attacker: Instance, victim: Model, dealt: number, killed: boolean)
	for _, fn in hitListeners do
		task.spawn(fn, attacker, victim, dealt, killed)
	end
end

-- Every hit by a player or a bot (match stats).
function Damage.onHit(fn: HitListener)
	table.insert(hitListeners, fn)
end

-- A Mod's damage guard: sees every hit on a combatant and returns the amount
-- to deal (0 blocks it: a Barrier, a Ghost dash, Crash Recovery).
function Damage.addDamageGuard(fn: DamageGuard)
	table.insert(damageGuards, fn)
end

-- A Mod's damage modifier: player-on-player damage (guns and Mods) before
-- the guards (Ping Spike's bonus on revealed enemies).
function Damage.addDamageModifier(fn: DamageModifier)
	table.insert(damageModifiers, fn)
end

-- All damage goes through here: the guards, then shield first, then health.
-- Returns what it took (0 when a guard blocked it). `attacker`: the player
-- behind it, if any.
function Damage.hurt(humanoid: Humanoid, amount: number, attacker: Player?): number
	if amount ~= amount or amount <= 0 or amount == math.huge then
		return 0
	end
	local victim = humanoid.Parent
	if victim and victim:IsA("Model") then
		for _, guard in damageGuards do
			local ok, result = pcall(guard, victim, humanoid, amount, attacker)
			if not ok then
				warn("[WeaponService] damage guard failed:", result)
			elseif typeof(result) == "number" and result == result then
				amount = math.max(result, 0)
			end
			if amount <= 0 then
				return 0
			end
		end
	end
	local shield = humanoid:GetAttribute(Combat.SHIELD_ATTRIBUTE)
	local fromShield = if typeof(shield) == "number" then math.min(shield, amount) else 0
	if fromShield > 0 then
		humanoid:SetAttribute(Combat.SHIELD_ATTRIBUTE, (shield :: number) - fromShield)
	end
	local taken = if amount > fromShield
		then HealthService.damage(humanoid, amount - fromShield)
		else 0
	return fromShield + taken
end

-- A player's damage on a combatant: the Mod modifiers, then hurt, then the
-- feedback. `sourceId`: the gun's id, or a Mod's id for Mod damage.
function Damage.apply(
	attacker: Player,
	victimModel: Model,
	amount: number,
	zone: HitZone,
	sourceId: string,
	at: Vector3
)
	local humanoid = Targets.liveHumanoid(victimModel)
	if not humanoid then
		return
	end
	for _, modify in damageModifiers do
		local ok, result = pcall(modify, attacker, victimModel, amount, sourceId)
		if not ok then
			warn("[WeaponService] damage modifier failed:", result)
		elseif typeof(result) == "number" and result == result then
			amount = math.max(result, 0)
		end
	end
	local dealt = Damage.hurt(humanoid, amount, attacker)
	local killed = Health.isDowned(humanoid)
	local blocked = dealt <= 0 and amount > 0
	humanoid:SetAttribute("LastAttacker", attacker.UserId)
	local victimPlayer = Players:GetPlayerFromCharacter(victimModel)
	if victimPlayer and dealt > 0 then
		victimPlayer:SetAttribute("HitAt", workspace:GetServerTimeNow()) -- the flinch others see
	end

	Net.event("HitConfirm"):FireClient(attacker, {
		damage = math.round(dealt),
		zone = zone,
		killed = killed,
		position = at,
		blocked = blocked or nil, -- a guard took it (Barrier, Ghost dash)
	})

	local victim = Players:GetPlayerFromCharacter(victimModel)
	local attackerRoot = attacker.Character
		and attacker.Character:FindFirstChild("HumanoidRootPart")
	if victim and attackerRoot and attackerRoot:IsA("BasePart") then
		Net.event("Damaged"):FireClient(victim, attackerRoot.Position, math.round(dealt))
	end
	tellHit(attacker, victimModel, dealt, killed)
	if killed then
		Net.event("Killed"):FireAllClients(victimModel, attacker, sourceId, zone == "Head")
	end
end

-- Damage from a Mod (ModService), through the same path as gun damage: kill
-- feed, hit confirm, damage direction, LastAttacker, listeners. The amount is
-- computed by the server's Mod code, never by a client.
function Damage.damage(
	attacker: Player,
	victim: Model,
	amount: number,
	sourceId: string,
	at: Vector3
)
	if amount ~= amount or amount <= 0 then
		return
	end
	Damage.apply(attacker, victim, amount, "Body", sourceId, at)
end

-- AI bots (vault/01 Design/Bots.md, Services/BotService): damage from a
-- bot's gun or Mod. The same path as a player's (guards, shield, health,
-- the victim's damage direction, kill feed) minus what needs a Player
-- attacker (damage modifiers, hit confirm). The server computed `amount`.
-- Returns what it took.
function Damage.damageBy(
	attacker: Model,
	victimModel: Model,
	amount: number,
	zone: HitZone,
	sourceId: string,
	_at: Vector3
): number
	local humanoid = Targets.liveHumanoid(victimModel)
	if not humanoid or amount ~= amount or amount <= 0 or amount == math.huge then
		return 0
	end
	local dealt = Damage.hurt(humanoid, amount, nil)
	local killed = Health.isDowned(humanoid)
	local victim = Players:GetPlayerFromCharacter(victimModel)
	if victim and dealt > 0 then
		victim:SetAttribute("HitAt", workspace:GetServerTimeNow())
		local root = attacker:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			Net.event("Damaged"):FireClient(victim, root.Position, math.round(dealt))
		end
	end
	tellHit(attacker, victimModel, dealt, killed)
	if killed then
		Net.event("Killed"):FireAllClients(victimModel, attacker, sourceId, zone == "Head")
	end
	return dealt
end

-- Heals a combatant (no natural regen: heals only come from Mods). Returns
-- the health actually added.
function Damage.heal(target: Model, amount: number): number
	local humanoid = Targets.liveHumanoid(target)
	if not humanoid or amount ~= amount or amount <= 0 then
		return 0
	end
	return HealthService.heal(humanoid, amount)
end

return Damage
