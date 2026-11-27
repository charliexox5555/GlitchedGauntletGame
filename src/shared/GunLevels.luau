--!strict
-- Gun levels (vault/01 Design/Gun Levels.md): the rules over Config/GunLevels. Pure functions, used on both
-- sides so the server enforces exactly what the client shows and plays:
--   * the save's `gunxp` = { [gunId] = total XP } (Shared/PlayerData; a save without it is all level 1),
--     published on the player as the StringValue GunLevels.REPLICA (JSON, server-written)
--   * level from total XP, the next milestone, the coin price of one level
--   * a match's XP per gun (ProgressionService, inside the save write)
--   * the stat steps: GunLevels.apply(config, level) is the gun's config at that level (WeaponService and
--     WeaponController build each slot from it)

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.GunLevels)
local LoadoutConfig = require(ReplicatedStorage.Shared.Config.Loadout)
local Types = require(ReplicatedStorage.Shared.Types)

type WeaponConfig = Types.WeaponConfig

export type GunXp = { [string]: number } -- gun id -> total XP
-- One gun's match, from the server's records (StatsService.gunStats).
export type GunMatch = { kills: number, rounds: number, roundsWon: number }
export type MatchGuns = { [string]: GunMatch }
-- What a match (or a coin level) did to one gun, for the end screen's level-up moment.
export type Gain = { id: string, xp: number, from: number, to: number, total: number }
export type Bonus = { Handling: number, Reload: number, Stability: number, Accuracy: number }

local GunLevels = {}

GunLevels.REPLICA = "GunXp"
GunLevels.MAX_LEVEL = Config.MAX_LEVEL
local MAX_ID = 24
local MAX_GUNS = 64 -- entries kept in a save (unknown ids from a newer catalog included)
local MAX_MATCH_GUNS = 8

-- A gun in the active set has a level; the knife and parked guns don't.
function GunLevels.levels(id: string): boolean
	return table.find(LoadoutConfig.PRIMARIES, id) ~= nil
		or table.find(LoadoutConfig.SECONDARIES, id) ~= nil
end

-- XP to go from `level` to the next (0 at the cap).
function GunLevels.need(level: number): number
	if level >= Config.MAX_LEVEL then
		return 0
	end
	return Config.CURVE.base + Config.CURVE.step * (math.max(level, 1) - 1)
end

-- Total XP at the start of `level`.
local starts: { number } = { 0 }
for level = 2, Config.MAX_LEVEL do
	starts[level] = starts[level - 1] + GunLevels.need(level - 1)
end
function GunLevels.startOf(level: number): number
	return starts[math.clamp(math.floor(level), 1, Config.MAX_LEVEL)]
end
GunLevels.MAX_XP = starts[Config.MAX_LEVEL]

-- (level, XP into it, XP the level needs) for a total.
function GunLevels.level(total: number): (number, number, number)
	local t = math.clamp(total, 0, GunLevels.MAX_XP)
	local level = 1
	while level < Config.MAX_LEVEL and t >= starts[level + 1] do
		level += 1
	end
	return level, t - starts[level], GunLevels.need(level)
end

-- The next milestone level above `level` (nil past the last).
function GunLevels.nextMilestone(level: number): number?
	local every = Config.MILESTONE_EVERY
	local at = (math.floor(level / every) + 1) * every
	return if at <= Config.MAX_LEVEL then at else nil
end

-- The category the level-up INTO `level` gives (nil for level 1).
function GunLevels.category(level: number): string?
	if level < 2 or level > Config.MAX_LEVEL then
		return nil
	end
	return Config.CATEGORIES[(level - 2) % #Config.CATEGORIES + 1]
end

-- Steps of a category from level 2 to `level`.
local function stepsOf(category: string, level: number): number
	local n = 0
	for l = 2, math.min(level, Config.MAX_LEVEL) do
		if GunLevels.category(l) == category then
			n += 1
		end
	end
	return n
end
local stepsAtMax: { [string]: number } = {}
for _, c in Config.CATEGORIES do
	stepsAtMax[c] = stepsOf(c, Config.MAX_LEVEL)
end

-- Each category's fraction at `level` (0 at level 1, MAX_BONUS at the cap).
local bonusCache: { [number]: Bonus } = {}
function GunLevels.bonus(level: number): Bonus
	local l = math.clamp(math.floor(level), 1, Config.MAX_LEVEL)
	local cached = bonusCache[l]
	if cached then
		return cached
	end
	local out: any = {}
	for _, c in Config.CATEGORIES do
		local max = (Config.MAX_BONUS :: any)[c] :: number
		out[c] = if stepsAtMax[c] > 0 then max * stepsOf(c, l) / stepsAtMax[c] else 0
	end
	table.freeze(out)
	bonusCache[l] = out
	return out
end

-- One step's size in a category (the Locker's "+0.7% RELOAD").
function GunLevels.stepSize(category: string): number
	local max = (Config.MAX_BONUS :: any)[category]
	local steps = stepsAtMax[category]
	return if typeof(max) == "number" and steps and steps > 0 then max / steps else 0
end

-- The gun's config at `level`: times, kick and spread scaled down by the bonus; everything else (damage,
-- fire rate, magazine, range, move speed) as it is. Level 1 is the config itself. Frozen and cached.
local applied: { [WeaponConfig]: { [number]: WeaponConfig } } = setmetatable({}, { __mode = "k" }) :: any
function GunLevels.apply(config: WeaponConfig, level: number): WeaponConfig
	local l = math.clamp(math.floor(level), 1, Config.MAX_LEVEL)
	if l <= 1 or not GunLevels.levels(config.id) then
		return config
	end
	local byLevel = applied[config]
	if not byLevel then
		byLevel = {}
		applied[config] = byLevel
	end
	local hit = byLevel[l]
	if hit then
		return hit
	end
	local b = GunLevels.bonus(l)
	local handling, reload = 1 - b.Handling, 1 - b.Reload
	local stability, accuracy = 1 - b.Stability, 1 - b.Accuracy
	local c = table.clone(config) :: any
	c.equipTime = config.equipTime * handling
	if config.drawTime then
		c.drawTime = config.drawTime * handling
	end
	c.adsTime = config.adsTime * handling
	c.reloadTime = config.reloadTime * reload
	c.emptyReloadTime = config.emptyReloadTime * reload
	local shell = config.shellReload
	if shell then
		c.shellReload = table.freeze({
			start = shell.start * reload,
			insert = shell.insert * reload,
			finish = shell.finish * reload,
		})
	end
	local r = table.clone(config.recoil) :: any
	r.up *= stability
	r.upAfter *= stability
	r.side *= stability
	c.recoil = table.freeze(r)
	local s = table.clone(config.spread) :: any
	s.first *= accuracy
	s.protectedGrowth *= accuracy
	s.growth *= accuracy
	s.max *= accuracy
	c.spread = table.freeze(s)
	c.gunLevel = l
	local out = table.freeze(c) :: WeaponConfig
	byLevel[l] = out
	return out
end

local function whole(n: unknown, max: number): number?
	if typeof(n) ~= "number" or n ~= n or n == math.huge or n == -math.huge then
		return nil
	end
	return math.clamp(math.floor(n), 0, max)
end

-- A clean `gunxp` from anything (a save, a replica, nil). Unknown gun ids are kept (a newer catalog), at
-- most MAX_GUNS entries; totals whole and capped at MAX_XP.
function GunLevels.clean(raw: unknown): GunXp
	local out: GunXp = {}
	if typeof(raw) ~= "table" then
		return out
	end
	local count = 0
	for id, n in raw :: { [unknown]: unknown } do
		local total = whole(n, GunLevels.MAX_XP)
		if typeof(id) == "string" and #id > 0 and #id <= MAX_ID and total and total > 0 then
			if count >= MAX_GUNS then
				break
			end
			count += 1
			out[id] = total
		end
	end
	return out
end

-- After a change: every total whole and in range, not too many entries.
function GunLevels.valid(t: GunXp): boolean
	local count = 0
	for id, n in t do
		count += 1
		if
			typeof(id) ~= "string"
			or #id > MAX_ID
			or typeof(n) ~= "number"
			or n ~= math.floor(n)
			or n < 0
			or n > GunLevels.MAX_XP
		then
			return false
		end
	end
	return count <= MAX_GUNS
end

-- A match's per-gun records, checked again (the match server builds them; the save path never trusts a
-- shape it didn't check). Only guns in the active set; counts whole and capped.
function GunLevels.cleanMatch(raw: unknown): MatchGuns?
	if typeof(raw) ~= "table" then
		return nil
	end
	local out: MatchGuns = {}
	local count = 0
	for id, rec in raw :: { [unknown]: unknown } do
		if
			typeof(id) ~= "string"
			or #id > MAX_ID
			or not GunLevels.levels(id)
			or typeof(rec) ~= "table"
		then
			continue
		end
		local r = rec :: { [string]: unknown }
		local kills = whole(r.kills, 1000)
		local rounds = whole(r.rounds, 1000)
		local won = whole(r.roundsWon, 1000)
		if kills and rounds and won and count < MAX_MATCH_GUNS then
			count += 1
			out[id] = { kills = kills, rounds = rounds, roundsWon = math.min(won, rounds) }
		end
	end
	return if count > 0 then out else nil
end

-- One gun's XP for a match.
function GunLevels.matchXp(rec: GunMatch, wonMatch: boolean, botsOnly: boolean): number
	local x = Config.XP
	local rounds = math.min(rec.rounds, x.roundMax)
	local n = math.min(rec.kills, x.killMax) * x.kill
		+ rounds * x.round
		+ math.min(rec.roundsWon, rounds) * x.roundWon
		+ (if wonMatch and rec.rounds > 0 then x.matchWon else 0)
	if botsOnly then
		n *= x.botsOnlyScale
	end
	return math.floor(n)
end

-- Adds a match's XP to `gunxp` (in place, inside the save write). Returns each gun's gain, sorted by gun id.
function GunLevels.applyMatch(
	gunxp: GunXp,
	guns: MatchGuns,
	wonMatch: boolean,
	botsOnly: boolean
): { Gain }
	local gains: { Gain } = {}
	for id, rec in guns do
		local xp = GunLevels.matchXp(rec, wonMatch, botsOnly)
		if xp <= 0 then
			continue
		end
		local before = gunxp[id] or 0
		local after = math.min(before + xp, GunLevels.MAX_XP)
		if after == before then
			continue
		end
		gunxp[id] = after
		table.insert(gains, {
			id = id,
			xp = after - before,
			from = (GunLevels.level(before)),
			to = (GunLevels.level(after)),
			total = after,
		})
	end
	table.sort(gains, function(a, b)
		return a.id < b.id
	end)
	return gains
end

-- Coins for the next level of a gun at `total` XP, nil when coins can't buy it (at or past COIN.maxLevel).
function GunLevels.coinPrice(total: number): number?
	local level, into, need = GunLevels.level(total)
	if level >= Config.COIN.maxLevel or need <= 0 then
		return nil
	end
	local step = Config.COIN.roundTo
	return math.ceil((need - into) * Config.COIN.perXp / step) * step
end

-- The total after buying one level from `total`.
function GunLevels.boughtTotal(total: number): number
	local level = GunLevels.level(total)
	return GunLevels.startOf(level + 1)
end

-- The published `gunxp` (empty until the save loads). Server-written, read by both sides.
function GunLevels.read(player: Player): GunXp
	local value = player:FindFirstChild(GunLevels.REPLICA)
	if value and value:IsA("StringValue") and value.Value ~= "" then
		local ok, decoded = pcall(HttpService.JSONDecode, HttpService, value.Value)
		if ok then
			return GunLevels.clean(decoded)
		end
	end
	return {}
end

function GunLevels.levelOf(player: Player, id: string): number
	return (GunLevels.level(GunLevels.read(player)[id] or 0))
end

return GunLevels
