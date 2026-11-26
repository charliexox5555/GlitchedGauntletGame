--!strict
-- Every point of damage and healing in a fight, for WeaponService (which
-- re-exports the public half: hurt, damage, damageBy, heal, the guard and
-- modifier hooks, onHit). Guns, Mods and bots all go through here: Mod
-- modifiers, Mod guards, shield first, then health, then the feedback
-- (hit confirm, damage direction, kill feed, hit listeners). Amounts always
-- come from server code, never from a client. A plain module: no init/start.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateValues = require(ReplicatedStorage.Shared.StateValues)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Combat = require(Shared.Config.Combat)
local Health = require(Shared.Health)
local MatchState = require(Shared.MatchState)
local PlayZone = require(Shared.PlayZone)
local Net = require(Shared.Net)
local Types = require(Shared.Types)
local Weapons = require(Shared.Config.Weapons)

local HealthService = require(script.Parent.Parent.HealthService)
local Spectated = require(script.Parent.Parent.Parent.Bots.Spectated)
local Targets = require(script.Parent.Targets)

type HitZone = Types.HitZone

-- Every hit from players and bots alike (StatsService): attacker is a Player
-- or a bot's model. Stats can return the assister IDs for the feed.
export type HitListener = (
	attacker: Instance,
	victim: Model,
	dealt: number,
	killed: boolean,
	headshot: boolean? -- the range bots' hit reactions (LobbyServer RangeService)
) -> { number }?
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

-- The spectate feed (vault/05 Production/Spectate Replay Fix Plan.md, C):
-- what a spectator sees of the fighter they watch, sent only to the players
-- watching them (Bots/Spectated), reliable:
--   ("Hit", attacker, hit)        the watched fighter hit someone (the same
--                                 fields as your own HitConfirm)
--   ("Hurt", victim, from, dealt) the watched fighter was hit (from = the
--                                 attacker's position, for the damage arcs)
-- A fighter is the Player, or the bot's model (what the clients know).
-- Also a short ring of every fighter's recent hits on the server's clock: the
-- final-kill replay replays the killer's hit markers from it (`hitsOf`).
export type RecentHit = {
	t: number,
	victim: Model,
	damage: number,
	zone: HitZone,
	killed: boolean,
	position: Vector3,
	source: string?,
	from: Vector3?, -- where the attacker stood (the victim's damage arcs in the replay)
}
local HIT_KEEP = 64
local recentHits: { [Instance]: { RecentHit } } = setmetatable({}, { __mode = "k" }) :: any

local function feed(target: Instance, ...: any)
	local watchers = Spectated.watchersOf(target)
	if #watchers == 0 then
		return
	end
	local remote = Net.event("SpectateFeed")
	for _, spectator in watchers do
		if spectator.Parent == Players then
			remote:FireClient(spectator, ...)
		end
	end
end

-- After any hit (a player's or a bot's, a gun's or a Mod's): the ring, the
-- attacker's spectators (their hit marker) and the victim's (their hurt).
local function shareHit(
	attacker: Instance,
	victimModel: Model,
	dealt: number,
	killed: boolean,
	blocked: boolean,
	zone: HitZone,
	at: Vector3,
	source: string?,
	from: Vector3?
)
	local damage = math.round(dealt)
	if not blocked then
		local list = recentHits[attacker]
		if not list then
			list = {}
			recentHits[attacker] = list
		end
		table.insert(list, {
			t = workspace:GetServerTimeNow(),
			victim = victimModel,
			damage = damage,
			zone = zone,
			killed = killed,
			position = at,
			source = source,
			from = from,
		})
		if #list > HIT_KEEP then
			table.remove(list, 1)
		end
	end
	feed(attacker, "Hit", attacker, {
		damage = damage,
		zone = zone,
		killed = killed,
		position = at,
		blocked = blocked or nil,
		source = source,
		victim = victimModel,
	})
	if dealt > 0 and from then
		local victimHolder: Instance = Players:GetPlayerFromCharacter(victimModel) or victimModel
		feed(victimHolder, "Hurt", victimHolder, from, damage)
	end
end

-- `attacker`'s hits between `from` and `to` (server time), oldest first: the
-- final-kill replay's hit markers.
function Damage.hitsOf(attacker: Instance, from: number, to: number): { RecentHit }
	local out: { RecentHit } = {}
	for _, hit in recentHits[attacker] or {} do
		if hit.t >= from and hit.t <= to then
			table.insert(out, hit)
		end
	end
	return out
end

-- Every hit taken by `victim` between `from` and `to` (server time), oldest
-- first, whoever dealt it: a victim's-eye replay shows them.
function Damage.hitsOn(victim: Model, from: number, to: number): { RecentHit }
	local out: { RecentHit } = {}
	for _, list in recentHits do
		for _, hit in list do
			if hit.victim == victim and hit.t >= from and hit.t <= to then
				table.insert(out, hit)
			end
		end
	end
	table.sort(out, function(a: RecentHit, b: RecentHit): boolean
		return a.t < b.t
	end)
	return out
end

local hitListeners: { HitListener } = {}
local damageGuards: { DamageGuard } = {}
local damageModifiers: { DamageModifier } = {}

local function tellHit(
	attacker: Instance,
	victim: Model,
	dealt: number,
	killed: boolean,
	sourceId: string,
	headshot: boolean
)
	local assists: { number }? = nil
	for _, fn in hitListeners do
		local ok, credit = pcall(fn, attacker, victim, dealt, killed, headshot)
		if not ok then
			warn("[WeaponService] hit listener failed:", credit)
		elseif credit then
			assists = credit
		end
	end
	if killed then
		for _, other in Players:GetPlayers() do
			if PlayZone.get(other) ~= "Lobby" and PlayZone.inSameScope(other, victim) then
				Net.event("Killed"):FireClient(other, victim, attacker, sourceId, headshot, assists)
			end
		end
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
	-- After the round is decided (RoundEnd) everyone can still shoot and cast,
	-- but nothing hurts: the result and the stats stay as they were. (The
	-- victim's own match: a lobby server can run several, MatchState.)
	local victimOwner: Instance? = if victim
		then (Players:GetPlayerFromCharacter(victim) or victim)
		else nil
	if MatchState.phase(victimOwner) == "RoundEnd" then
		return 0
	end
	-- Players only take damage in a match, and only from their own match
	-- (PlayZone): nobody gets hurt in the lobby or the range, and two pad
	-- duels in one lobby server never touch each other.
	local victimPlayer = if victim then Players:GetPlayerFromCharacter(victim) else nil
	if victimPlayer then
		if PlayZone.get(victimPlayer) ~= "Match" then
			return 0
		end
		if attacker and PlayZone.matchId(attacker) ~= PlayZone.matchId(victimPlayer) then
			return 0
		end
	end
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
	local shield = StateValues.get(humanoid, Combat.SHIELD_ATTRIBUTE)
	local fromShield = if typeof(shield) == "number" then math.min(shield, amount) else 0
	if fromShield > 0 then
		StateValues.set(humanoid, Combat.SHIELD_ATTRIBUTE, (shield :: number) - fromShield)
	end
	local taken = if amount > fromShield
		then HealthService.damage(humanoid, amount - fromShield)
		else 0
	return fromShield + taken
end

-- A player's damage on a combatant: the Mod modifiers, then hurt, then the
-- feedback. `sourceId`: the gun's id, or a Mod's id for Mod damage.
-- `modSource`: the Mod's id when a Mod dealt it; the attacker's client gets it
-- in the hit confirm and shows the ability feedback (marker, no numbers).
function Damage.apply(
	attacker: Player,
	victimModel: Model,
	amount: number,
	zone: HitZone,
	sourceId: string,
	at: Vector3,
	modSource: string?
)
	local humanoid = Targets.liveHumanoid(victimModel)
	local owner: Instance = Players:GetPlayerFromCharacter(victimModel) or victimModel
	if not humanoid or MatchState.phase(owner) == "RoundEnd" then
		return -- after the round: shots land, nothing counts (no confirm, no BLOCKED)
	end
	-- A player outside a match (the range; owner 2026-11-26): no damage (hurt below), and no feedback either: no
	-- hit confirm for the shooter, no hurt screen / direction arc / flinch for them.
	if owner:IsA("Player") and PlayZone.get(owner) ~= "Match" then
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
	StateValues.set(humanoid, "LastAttacker", attacker.UserId)
	local victimPlayer = Players:GetPlayerFromCharacter(victimModel)
	if victimPlayer and dealt > 0 then
		StateValues.set(victimPlayer, "HitAt", workspace:GetServerTimeNow()) -- the flinch others see
	end

	Net.event("HitConfirm"):FireClient(attacker, {
		damage = math.round(dealt),
		zone = zone,
		killed = killed,
		position = at,
		blocked = blocked or nil, -- a guard took it (Barrier, Ghost dash)
		source = modSource,
		victim = victimModel, -- the damage number's target (one per target)
	})

	local victim = Players:GetPlayerFromCharacter(victimModel)
	local attackerRoot = attacker.Character
		and attacker.Character:FindFirstChild("HumanoidRootPart")
	if victim and attackerRoot and attackerRoot:IsA("BasePart") then
		Net.event("Damaged"):FireClient(victim, attackerRoot.Position, math.round(dealt))
	end
	shareHit(
		attacker,
		victimModel,
		dealt,
		killed,
		blocked,
		zone,
		at,
		modSource,
		if attackerRoot and attackerRoot:IsA("BasePart") then attackerRoot.Position else nil
	)
	tellHit(attacker, victimModel, dealt, killed, sourceId, zone == "Head")
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
	Damage.apply(attacker, victim, amount, "Body", sourceId, at, sourceId)
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
	at: Vector3
): number
	local humanoid = Targets.liveHumanoid(victimModel)
	if not humanoid or amount ~= amount or amount <= 0 or amount == math.huge then
		return 0
	end
	local dealt = Damage.hurt(humanoid, amount, nil)
	local killed = Health.isDowned(humanoid)
	local victim = Players:GetPlayerFromCharacter(victimModel)
	local root = attacker:FindFirstChild("HumanoidRootPart")
	local from = if root and root:IsA("BasePart") then root.Position else nil
	if victim and dealt > 0 then
		StateValues.set(victim, "HitAt", workspace:GetServerTimeNow())
		if from then
			Net.event("Damaged"):FireClient(victim, from, math.round(dealt))
		end
	end
	-- A Mod's damage names the Mod (its hit marker rules); a gun's doesn't.
	local modSource = if Weapons.get(sourceId) then nil else sourceId
	shareHit(attacker, victimModel, dealt, killed, dealt <= 0, zone, at, modSource, from)
	tellHit(attacker, victimModel, dealt, killed, sourceId, zone == "Head")
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
