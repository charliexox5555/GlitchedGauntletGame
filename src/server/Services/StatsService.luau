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

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchConfig = require(ReplicatedStorage.Shared.Config.Match)
local ModsConfig = require(ReplicatedStorage.Shared.Config.Mods)
local Net = require(ReplicatedStorage.Shared.Net)
local Pawns = require(ReplicatedStorage.Shared.Simulation.Pawns)
local RateLimit = require(ReplicatedStorage.Shared.Util.RateLimit)
local Teams = require(ReplicatedStorage.Shared.Mods.Teams)

local HealthService = require(script.Parent.HealthService)
local WeaponService = require(script.Parent.WeaponService)

local StatsService = {}

export type Line = {
	id: string, -- "p<userId>" or "b<bot name>"
	name: string,
	userId: number?,
	team: number,
	eliminations: number,
	deaths: number,
	assists: number,
	dealt: number,
	taken: number,
	mvp: boolean?,
	kit: { string }?, -- "id:level" per filled Mod slot
}

type Entry = {
	id: string,
	name: string,
	userId: number?,
	team: number,
	eliminations: number,
	deaths: number,
	assists: number,
	dealt: number,
	taken: number,
	hurtBy: { [string]: number }, -- attacker id → last hit time
}

local entries: { [string]: Entry } = {}
-- Damage this life: attacker id → victim id → damage (the combat report).
local pair: { [string]: { [string]: number } } = {}
local limiter = RateLimit.new(MatchConfig.RATE)

-- Who holds a fighter's Mod attributes: the Player, or a bot's owner stand-in.
local function holderOf(id: string): Instance?
	if string.sub(id, 1, 1) == "p" then
		local userId = tonumber(string.sub(id, 2))
		return if userId then Players:GetPlayerByUserId(userId) else nil
	end
	for _, pawn in Pawns.list() do
		if "b" .. tostring(pawn.owner:GetAttribute("BotId")) == id then
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
			local modId = holder:GetAttribute("Mod" .. slot .. "Id")
			local level = holder:GetAttribute("Mod" .. slot .. "Level")
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
	if x:IsA("Model") and x:GetAttribute("IsBot") == true then
		local serial = x:GetAttribute("BotId") -- names get reused, ids don't
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
			team = Teams.of(x) or 0,
			eliminations = 0,
			deaths = 0,
			assists = 0,
			dealt = 0,
			taken = 0,
			hurtBy = {},
		}
		entries[id] = e
	end
	local team = Teams.of(x)
	if team then
		e.team = team -- a seat can change hands (a bot takes a leaver's place)
	end
	return e
end

local function onHit(attacker: Instance, victim: Model, dealt: number, killed: boolean)
	local a = entryOf(attacker)
	local v = entryOf(victim)
	if not v then
		return
	end
	local now = os.clock()
	v.taken += dealt
	-- Your own or your team's damage (Molly, Firewall) earns nothing.
	local enemy = a ~= nil and a ~= v and (a.team == 0 or a.team ~= v.team)
	if not a or not enemy then
		return
	end
	a.dealt += dealt
	if dealt > 0 then
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
		forgetLife(v.id)
		a.eliminations += 1
		for id, at in v.hurtBy do
			local helper = entries[id]
			if helper and id ~= a.id and now - at <= MatchConfig.ASSIST_WINDOW then
				helper.assists += 1
			end
		end
		table.clear(v.hurtBy)
	end
end

-- A new match: everyone starts from zero.
function StatsService.reset()
	table.clear(entries)
	table.clear(pair)
end

-- A new round: everyone's life (and combat report) starts over.
function StatsService.newRound()
	table.clear(pair)
end

-- Makes sure everyone in the match has a line, even with nothing on it.
function StatsService.note(x: Instance)
	entryOf(x)
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
			team = e.team,
			eliminations = e.eliminations,
			deaths = e.deaths,
			assists = e.assists,
			dealt = math.round(e.dealt),
			taken = math.round(e.taken),
			kit = kitOf(e.id),
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
	WeaponService.onHit(onHit)
	HealthService.onDowned(function(humanoid: Humanoid)
		local body = humanoid.Parent
		local e = body and entryOf(body)
		if e then
			e.deaths += 1
			-- The zone and falls too. Deferred: the killing hit's listener (and
			-- its combat report) runs after this, and needs the life's damage.
			task.defer(forgetLife, e.id)
		end
	end)
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
