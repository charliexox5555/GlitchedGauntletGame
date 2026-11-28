--!strict
-- Match stats (vault/05 Production/Match Structure Revamp.md, phase D): per
-- fighter (players and bots) eliminations, deaths, assists, damage dealt and
-- taken. Hits and kills come from WeaponService.onHit (both damage paths),
-- deaths from HealthService.onDowned (the zone and falls too). An assist is
-- damage on the victim in the ASSIST_WINDOW before the kill by anyone but the
-- killer (LihFolk "Kill Credit, Assists, Kill Feed and Death Recaps").
--
-- Also (vault/02 Art/UI Match Extras.md): the hold-Tab scoreboard asks for
-- the live lines with everyone's build (`Scoreboard`, rate-limited, no
-- arguments trusted), and a victim gets a combat report on death: the damage
-- they dealt to their killer and took from them this life (`CombatReport`).
--
-- And the task Path's match counts (vault/01 Design/Tasks and Rewards.md): headshot and multi eliminations,
-- eliminations by loadout slot, rounds won (without dying, as the last alive, an ace), powers drafted, used
-- and levelled. MatchService feeds the round ends (roundEnded), draft picks (notePick) and power uses
-- (noteUse) and reads one player's counts at the match end (taskStats).

local Context = require(script.Parent.Parent.Context) -- this match (MatchKit/Context)
local Globals =
	game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services")
local Players = Context.players
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateValues = require(ReplicatedStorage.Shared.StateValues)

local MatchConfig = require(ReplicatedStorage.Shared.Config.Match)
local ModsConfig = require(ReplicatedStorage.Shared.Config.Mods)
local Net = Context.net
local Pawns = require(ReplicatedStorage.Shared.Simulation.Pawns)
local RateLimit = require(ReplicatedStorage.Shared.Util.RateLimit)
local Teams = require(ReplicatedStorage.Shared.Mods.Teams)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local TasksConfig = require(ReplicatedStorage.Shared.Config.Tasks)

local HealthService = require(Globals.HealthService)
local WeaponService = require(Globals.WeaponService)

local StatsService = {}

export type Line = {
	id: string, -- "p<userId>" or "b<bot id>"
	name: string,
	userId: number?,
	botLevel: number?,
	portraitUserId: number?,
	team: number,
	eliminations: number,
	deaths: number,
	assists: number,
	dealt: number,
	taken: number,
	mvp: boolean?,
	kit: { string }?, -- "id:level" per filled Mod slot
	-- the gun this fighter got the most eliminations with (else the one in
	-- their hand at the end): the win cutscene puts it in their copy's hand
	weapon: string?,
}

type Entry = {
	id: string,
	name: string,
	userId: number?,
	botLevel: number?,
	portraitUserId: number?,
	team: number,
	eliminations: number,
	deaths: number,
	assists: number,
	dealt: number,
	taken: number,
	hurtBy: { [string]: number }, -- attacker id → last hit time
	gunKills: { [string]: number }, -- weapon id → eliminations with it
	-- gun levels (Shared/GunLevels, players only): rounds played / won with each gun in the loadout
	gunRounds: { [string]: number },
	gunRoundsWon: { [string]: number },
	lastGun: string?, -- the gun of their latest hit
	-- the task Path
	headshotElims: number,
	slotElims: { Primary: number, Secondary: number }, -- eliminations by the gun's loadout slot
	chain: number, -- eliminations in the current multi-elimination streak
	lastKillAt: number,
	doubles: number,
	triples: number,
	roundsWon: number,
	roundsNoDeath: number,
	clutches: number,
	aces: number,
	drafted: number,
	uses: number,
	powersUsed: { string },
	powerMax: { [string]: number }, -- power id → highest level reached (1..3)
	glitch: boolean, -- picked a Glitched power this match
}

type RoundKiller = { name: string, team: number, kills: number, userId: number? }

local entries: { [string]: Entry } = {}
-- Damage this life: attacker id → victim id → damage (the combat report).
local pair: { [string]: { [string]: number } } = {}
local roundKills: { [string]: RoundKiller } = {}
local roundDamageTaken: { [number]: number } = { [1] = 0, [2] = 0 }
local limiter = RateLimit.new(MatchConfig.RATE)

-- Who holds a fighter's Mod attributes: the Player, or a bot's owner stand-in.
local function holderOf(id: string): Instance?
	if string.sub(id, 1, 1) == "p" then
		local userId = tonumber(string.sub(id, 2))
		return if userId then Players:GetPlayerByUserId(userId) else nil
	end
	for _, pawn in Pawns.list() do
		if "b" .. tostring(StateValues.get(pawn.owner, "BotId")) == id then
			return pawn.owner
		end
	end
	return nil
end

local function kitOf(id: string): { string }
	local holder = holderOf(id)
	local kit: { string } = {}
	if holder then
		for slot = 1, ModsConfig.SLOTS do
			local modId = StateValues.get(holder, "Mod" .. slot .. "Id")
			local level = StateValues.get(holder, "Mod" .. slot .. "Level")
			if typeof(modId) == "string" and modId ~= "" then
				table.insert(
					kit,
					modId .. ":" .. (if typeof(level) == "string" then level else "L1")
				)
			end
		end
	end
	return kit
end

-- A death ends that fighter's life: their damage both ways starts over.
local function forgetLife(id: string)
	pair[id] = nil
	for _, row in pair do
		row[id] = nil
	end
	local entry = entries[id]
	if entry then
		table.clear(entry.hurtBy)
	end
end

-- A fighter's id and name: a player (or their character) or a bot's model.
local function identify(x: Instance): (string?, string, number?)
	local owner: Player? = if x:IsA("Player")
		then x
		elseif x:IsA("Model") then Players:GetPlayerFromCharacter(x)
		else nil
	if owner then
		return "p" .. owner.UserId, owner.DisplayName, owner.UserId
	end
	if x:IsA("Model") and StateValues.get(x, "IsBot") == true then
		local serial = StateValues.get(x, "BotId") -- names get reused, ids don't
		return "b" .. tostring(serial or x.Name), x.Name, nil
	end
	return nil, "", nil
end

local function entryOf(x: Instance): Entry?
	local id, name, userId = identify(x)
	if not id then
		return nil
	end
	local e = entries[id]
	if not e then
		e = {
			id = id,
			name = name,
			userId = userId,
			botLevel = if not userId then StateValues.get(x, "Level") :: number? else nil,
			portraitUserId = if not userId
				then StateValues.get(x, "PortraitUserId") :: number?
				else nil,
			team = Teams.of(x) or 0,
			eliminations = 0,
			deaths = 0,
			assists = 0,
			dealt = 0,
			taken = 0,
			hurtBy = {},
			gunKills = {},
			gunRounds = {},
			gunRoundsWon = {},
			headshotElims = 0,
			slotElims = { Primary = 0, Secondary = 0 },
			chain = 0,
			lastKillAt = -math.huge,
			doubles = 0,
			triples = 0,
			roundsWon = 0,
			roundsNoDeath = 0,
			clutches = 0,
			aces = 0,
			drafted = 0,
			uses = 0,
			powersUsed = {},
			powerMax = {},
			glitch = false,
		}
		entries[id] = e
	end
	local team = Teams.of(x)
	if team then
		e.team = team -- a seat can change hands (a bot takes a leaver's place)
	end
	return e
end

-- The gun in a fighter's hand (WorldModel keeps the id on the Player, or
-- on a bot's model), nil for the knife or nothing.
local function heldGun(x: Instance): string?
	local owner: Player? = if x:IsA("Player")
		then x
		elseif x:IsA("Model") then Players:GetPlayerFromCharacter(x)
		else nil
	local id = StateValues.get(owner or x, "WeaponId")
	if typeof(id) ~= "string" then
		return nil
	end
	local config = Weapons.get(id)
	if not config or config.fireMode == "Melee" then
		return nil
	end
	return id
end

-- The gun with the most eliminations (ties: the latest one used), else the
-- gun of their latest hit.
local function topGun(e: Entry): string?
	local best = e.lastGun
	local count = if best then (e.gunKills[best] or 0) else 0
	for id, n in e.gunKills do
		if n > count then
			best, count = id, n
		end
	end
	return best
end

local function onHit(
	attacker: Instance,
	victim: Model,
	dealt: number,
	killed: boolean,
	headshot: boolean?
): { number }?
	local a = entryOf(attacker)
	local v = entryOf(victim)
	if not v then
		return nil
	end
	local now = os.clock()
	v.taken += dealt
	if dealt > 0 and (v.team == 1 or v.team == 2) then
		roundDamageTaken[v.team] = (roundDamageTaken[v.team] or 0) + dealt
	end
	-- Your own or your team's damage (Molly, Firewall) earns nothing.
	local enemy = a ~= nil and a ~= v and (a.team == 0 or a.team ~= v.team)
	if not a or not enemy then
		return nil
	end
	a.dealt += dealt
	if dealt > 0 then
		a.lastGun = heldGun(attacker) or a.lastGun
		v.hurtBy[a.id] = now
		local row = pair[a.id]
		if not row then
			row = {}
			pair[a.id] = row
		end
		row[v.id] = (row[v.id] or 0) + dealt
	end
	if killed then
		-- The victim's combat report: what they did to their killer, and took.
		local owner = Players:GetPlayerFromCharacter(victim)
		if owner then
			local dealtTo = (pair[v.id] or {})[a.id] or 0
			local takenFrom = (pair[a.id] or {})[v.id] or 0
			Net.event("CombatReport"):FireClient(owner, math.round(dealtTo), math.round(takenFrom))
		end
		a.eliminations += 1
		if a.userId then
			local killerPlayer = Players:GetPlayerByUserId(a.userId)
			if killerPlayer then
				StateValues.set(killerPlayer, "MatchKills", a.eliminations)
			end
		end
		local rk = roundKills[a.id]
		if not rk then
			rk = { name = a.name, team = a.team, kills = 0, userId = a.userId }
			roundKills[a.id] = rk
		end
		rk.kills += 1
		local gun = heldGun(attacker)
		if gun then
			a.gunKills[gun] = (a.gunKills[gun] or 0) + 1
			local config = Weapons.get(gun)
			local slot = config and config.slot
			if slot == "Primary" or slot == "Secondary" then
				a.slotElims[slot] += 1
			end
		end
		if headshot then
			a.headshotElims += 1
		end
		a.chain = if now - a.lastKillAt <= TasksConfig.MULTI_ELIM_WINDOW then a.chain + 1 else 1
		a.lastKillAt = now
		if a.chain == 2 then
			a.doubles += 1
		elseif a.chain == 3 then
			a.triples += 1
		end
		local assists: { number } = {}
		for id, at in v.hurtBy do
			local helper = entries[id]
			if helper and id ~= a.id and now - at <= MatchConfig.ASSIST_WINDOW then
				helper.assists += 1
				table.insert(assists, helper.userId or 0) -- bots count in the feed too
			end
		end
		forgetLife(v.id)
		return if #assists > 0 then assists else nil
	end
	return nil
end

-- A new match: everyone starts from zero.
function StatsService.reset()
	table.clear(entries)
	table.clear(pair)
	table.clear(roundKills)
	roundDamageTaken[1] = 0
	roundDamageTaken[2] = 0
	for _, p in Players:GetPlayers() do
		StateValues.set(p, "MatchKills", 0)
	end
end

-- A new round: everyone's life (and combat report) starts over.
function StatsService.newRound()
	table.clear(pair)
	table.clear(roundKills)
	roundDamageTaken[1] = 0
	roundDamageTaken[2] = 0
	for _, entry in entries do
		table.clear(entry.hurtBy)
		entry.chain = 0
		entry.lastKillAt = -math.huge
	end
end

-- A round's end (MatchService): `winner` 1 or 2, how many fighters each side started it with, the winning side's
-- fighters still alive (Players or bot models).
function StatsService.roundEnded(
	winner: number,
	winnerStart: number,
	loserStart: number,
	survivors: { Instance }
)
	for _, e in entries do
		-- gun levels: every player's guns this round (the loadout WeaponService handed out, not the client's word)
		local player = if e.userId then Players:GetPlayerByUserId(e.userId) else nil
		if player and (e.team == 1 or e.team == 2) then
			local loadout = WeaponService.getLoadout(player)
			for _, slot in { "Primary", "Secondary" } do
				local gun = loadout[slot :: any]
				if typeof(gun) == "string" then
					e.gunRounds[gun] = (e.gunRounds[gun] or 0) + 1
					if e.team == winner then
						e.gunRoundsWon[gun] = (e.gunRoundsWon[gun] or 0) + 1
					end
				end
			end
		end
		if e.team == winner then
			e.roundsWon += 1
			local rk = roundKills[e.id]
			if loserStart >= 2 and rk and rk.kills >= loserStart then
				e.aces += 1
			end
		end
	end
	for _, x in survivors do
		local e = entryOf(x)
		if e and e.team == winner then
			e.roundsNoDeath += 1
			if #survivors == 1 and winnerStart >= 2 then
				e.clutches += 1 -- the team's last player alive, and the round is theirs
			end
		end
	end
end

-- A draft pick that landed (DraftService.onPicked): a new power ("L1") or an upgrade ("A2", "G3", ...).
function StatsService.notePick(key: any, powerId: string, level: string)
	if typeof(key) ~= "Instance" or not key:IsA("Player") then
		return -- bots don't do tasks
	end
	local e = entryOf(key)
	if not e then
		return
	end
	e.drafted += 1
	local n = tonumber(string.sub(level, 2)) or 1
	e.powerMax[powerId] = math.max(e.powerMax[powerId] or 0, n)
	if string.sub(level, 1, 1) == "G" then
		e.glitch = true
	end
end

-- A power use the server accepted (ModService.onUsed).
function StatsService.noteUse(player: Player, powerId: string)
	local e = entryOf(player)
	if not e then
		return
	end
	e.uses += 1
	if not table.find(e.powersUsed, powerId) and #e.powersUsed < 32 then
		table.insert(e.powersUsed, powerId)
	end
end

-- One player's counts for the task Path (MatchService adds played / won / flawless / mode / map).
function StatsService.taskStats(userId: number): { [string]: any }
	local e = entries["p" .. userId]
	if not e then
		return {}
	end
	local levels = { 0, 0, 0 }
	for _, n in e.powerMax do
		for l = 1, math.min(n, 3) do
			levels[l] += 1
		end
	end
	return {
		elims = e.eliminations,
		headshotElims = e.headshotElims,
		doubles = e.doubles,
		triples = e.triples,
		slotElims = table.clone(e.slotElims),
		roundsWon = e.roundsWon,
		roundsNoDeath = e.roundsNoDeath,
		clutches = e.clutches,
		aces = e.aces,
		drafted = e.drafted,
		uses = e.uses,
		powersUsed = table.clone(e.powersUsed),
		powerLevels = levels,
		glitch = e.glitch,
	}
end

-- One player's guns this match for gun levels (Shared/GunLevels.MatchGuns; ProgressionService checks it
-- again): eliminations from the server's hit records, rounds from the loadouts it handed out.
function StatsService.gunStats(
	userId: number
): { [string]: { kills: number, rounds: number, roundsWon: number } }
	local e = entries["p" .. userId]
	local out = {}
	if not e then
		return out
	end
	for gun, n in e.gunRounds do
		out[gun] =
			{ kills = e.gunKills[gun] or 0, rounds = n, roundsWon = e.gunRoundsWon[gun] or 0 }
	end
	for gun, n in e.gunKills do
		if not out[gun] then
			out[gun] = { kills = n, rounds = 0, roundsWon = 0 }
		end
	end
	return out
end

-- Makes sure everyone in the match has a line, even with nothing on it.
function StatsService.note(x: Instance)
	entryOf(x)
end

function StatsService.roundTopKiller(team: number): (string?, number, number?)
	local bestName: string? = nil
	local bestKills = 0
	local bestUserId: number? = nil
	for _, rk in roundKills do
		if rk.team == team and rk.kills > bestKills then
			bestKills = rk.kills
			bestName = rk.name
			bestUserId = rk.userId
		end
	end
	return bestName, bestKills, bestUserId
end

function StatsService.roundDamageTaken(team: number): number
	return roundDamageTaken[team] or 0
end

-- Every line, with the MVP marked (most eliminations, then damage dealt).
function StatsService.summary(): { Line }
	local out: { Line } = {}
	local best: Line? = nil
	for _, e in entries do
		local line: Line = {
			id = e.id,
			name = e.name,
			userId = e.userId,
			botLevel = e.botLevel,
			portraitUserId = e.portraitUserId,
			team = e.team,
			eliminations = e.eliminations,
			deaths = e.deaths,
			assists = e.assists,
			dealt = math.round(e.dealt),
			taken = math.round(e.taken),
			kit = kitOf(e.id),
			weapon = topGun(e),
		}
		table.insert(out, line)
		if
			not best
			or line.eliminations > best.eliminations
			or (line.eliminations == best.eliminations and line.dealt > best.dealt)
		then
			best = line
		end
	end
	if best and (best.eliminations > 0 or best.dealt > 0) then
		best.mvp = true
	end
	table.sort(out, function(x, y)
		if x.team ~= y.team then
			return x.team < y.team
		end
		return x.eliminations > y.eliminations
	end)
	return out
end

function StatsService.start()
	-- Shared services hear every fighter in the server: only this match's count (MatchKit/Context).
	WeaponService.onHit(Context.filtered(2, onHit))
	HealthService.onDowned(Context.filtered(1, function(humanoid: Humanoid)
		local body = humanoid.Parent
		local e = body and entryOf(body)
		if e then
			e.deaths += 1
			-- The zone and falls too. Deferred: the killing hit's listener (and
			-- its combat report) runs after this, and needs the life's damage.
			task.defer(forgetLife, e.id)
		end
	end))
	-- The hold-Tab scoreboard: the live lines, for the asker only.
	Net.event("Scoreboard").OnServerEvent:Connect(function(player: Player)
		if limiter:allow(player, "Scoreboard") then
			Net.event("Scoreboard"):FireClient(player, StatsService.summary())
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		limiter:forget(player)
	end)
end

return StatsService
