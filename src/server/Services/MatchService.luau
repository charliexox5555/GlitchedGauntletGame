--!strict
-- The match (vault/01 Design/Match Flow.md, vault/05 Production/Match
-- Structure Revamp.md): rounds of select (draft, ending in a 3-2-1) → fight
-- → sudden death → round end, first to 5. Runs on every server
-- that isn't in test mode. One loop in one thread, wrapped in a pcall so an
-- error can't leave the game stuck. Clients read the state from MatchState
-- attributes; they can't change anything here (picks go through DraftService).

local Context = require(script.Parent.Parent.Context) -- this match (MatchKit/Context)
local Globals =
	game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services")
local Players = Context.players
-- The real service, for "is this player still in the server" (Players above is this match's stand-in, MatchKit/Context).
local PlayersService = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local RunService = game:GetService("RunService")

local BotsConfig = require(ReplicatedStorage.Shared.Config.Bots)
local Combat = require(ReplicatedStorage.Shared.Config.Combat)
local Config = require(ReplicatedStorage.Shared.Config.Match)
local OnbConfig = require(ReplicatedStorage.Shared.Config.Onboarding)
local MatchState = require(script.Parent.Parent.MatchState)
local ModsConfig = require(ReplicatedStorage.Shared.Config.Mods)
local Teams = require(ReplicatedStorage.Shared.Mods.Teams)
local TestMode = require(ReplicatedStorage.Shared.TestMode)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

local DraftService = require(script.Parent.DraftService)
local MapService = require(script.Parent.MapService)
local MapVoteService = require(script.Parent.MapVoteService)
local ModService = require(script.Parent.ModService)
local BotService = require(script.Parent.BotService)
local CharacterService = require(Globals.CharacterService)
local MatchPlan = require(script.Parent.Parent.Bots.MatchPlan)
local AutoDifficulty = require(script.Parent.Parent.Bots.AutoDifficulty)
local WeaponService = require(Globals.WeaponService)
local MovementGuard = require(Globals.MovementGuard)
local HealthService = require(Globals.HealthService)
local Net = Context.net
local ZoneService = require(script.Parent.ZoneService)
local StatsService = require(script.Parent.StatsService)
local MatchEndService = require(script.Parent.MatchEndService)
local Health = require(ReplicatedStorage.Shared.Health)
local RateLimit = require(ReplicatedStorage.Shared.Util.RateLimit)
local HealthLog = require(ReplicatedStorage.Shared.HealthLog)
local HttpService = game:GetService("HttpService")
-- Levels and streaks (LobbyServer, one copy per server; vault/01 Design/Progression.md)
local ProgressionService = require(
	game:GetService("ServerScriptService")
		:WaitForChild("LobbyServer")
		:WaitForChild("Services")
		:WaitForChild("ProgressionService") :: ModuleScript
) :: any
local Telemetry = require(game:GetService("ServerScriptService").LobbyServer.Telemetry)

local MatchService = {}

local POLL = 0.1 -- seconds between checks on a running clock
local RETRY_AFTER_ERROR = 3
local MAP_RETRY = 5
local SPAWN_TRIES = 4
local SPAWN_BACKOFF = { 0.5, 1, 2 }
local STREAM_WAIT = 6 -- seconds a spawn may wait for its area to stream to the player
local spawning: { [Player]: boolean } = {}
local firstMatch = false -- this match is a new player's first (isFirstMatch, set in runMatch)
local onboardingMatch = false -- every real player is under Config.ONBOARDING_MATCHES (set in runMatch)
-- The body each player's own client last said is on its screen with floor under it (BodyReady).
local bodyReady: { [Player]: Model } = {}
local limiter = RateLimit.new(Config.RATE)

local enabled = false
local matchesPlayed = 0

-- Seats (Match Structure Revamp → A2). A listed player who isn't here yet
-- has a bot stand-in that plays their seat until they arrive; a late player
-- takes it over at once during a select, else at the next round.
local standIns: { [number]: any } = {} -- userId → bot key
local pendingTakeovers: { [Player]: any } = {} -- player → the bot they replace
local inMatch = false
-- Sides that have had a real player this match: if one of them has no
-- fighters left (humans OR bot backfill) past FORFEIT_GRACE, the other wins.
local FORFEIT_GRACE = 0.5
local humanSides = { false, false }
local sideEmptySince: { [number]: number? } = { nil, nil }
local currentMapName = "Unknown"
local currentRound = 0
local lastMap: string? = nil
-- The voted map, loaded once round 1's select is open (see playRound): the select screen reaches a slow phone
-- before the map's download does, instead of the phone sitting on the vote screen while it arrives (owner
-- 2026-11-26: "stuck on the vote map screen", phones).
local pendingMap: string? = nil
local mapLogged: { [number]: boolean } = {}
local roundStartCounts = { 0, 0 }
local clutchState: { [number]: { vs: number, actor: string }? } = { nil, nil }
local matchMode: () -> string

local function mapLabel(id: string?): string
	if not id or id == "" then
		return "Unknown"
	end
	for _, entry in Config.MAPS do
		if entry.id == id then
			return entry.name or entry.id
		end
	end
	return id
end

-- The last fighter to go down on each side, and when (server time): the
-- final-kill replay.
type Down = { body: Model, at: number }
local lastDown: { [number]: Down } = {}
-- Who took each body down (a Player or a bot's model): the replay's killer.
local lastKiller: { [Model]: Instance } = setmetatable({}, { __mode = "k" }) :: any

local function setLocked(player: Player, locked: boolean)
	StateValues.set(player, MatchState.COMBAT_LOCKED, locked)
end

local function setAllLocked(locked: boolean)
	for _, player in Players:GetPlayers() do
		setLocked(player, locked)
	end
end

local function setPhase(phase: MatchState.Phase, seconds: number)
	MatchState.set("EndsAt", workspace:GetServerTimeNow() + seconds)
	MatchState.set("Phase", phase)
end

-- Waits out the clock, or until `done` says so.
local function runClock(seconds: number, done: (() -> boolean)?)
	local deadline = os.clock() + seconds
	while os.clock() < deadline do
		if done and done() then
			return
		end
		task.wait(POLL)
	end
end

-- Players ----------------------------------------------------------------------

local function playersOn(team: number): { Player }
	local list: { Player } = {}
	for _, player in Players:GetPlayers() do
		if Teams.of(player) == team then
			table.insert(list, player)
		end
	end
	return list
end

-- Fighters on a team: players and AI bots (BotService).
local function sideCount(team: number): number
	return #playersOn(team) + BotService.count(team)
end

local function bothSidesFilled(): boolean
	return sideCount(1) > 0 and sideCount(2) > 0
end

-- Teams come from join order, so people leaving can tip them. Moves players
-- over until the sides differ by at most one. A Lobby match (MatchPlan) puts
-- everyone it lists on their listed team instead.
local function balanceTeams()
	if MatchPlan.current() then
		for _, player in Players:GetPlayers() do
			local team = MatchPlan.teamFor(player)
			if team and Teams.of(player) ~= team then
				StateValues.set(player, Teams.ATTRIBUTE, team)
			end
		end
		return
	end
	while true do
		local one, two = playersOn(1), playersOn(2)
		local bigger, target = one, 2
		if #two > #one then
			bigger, target = two, 1
		end
		if math.abs(#one - #two) < 2 then
			return
		end
		StateValues.set(bigger[#bigger], Teams.ATTRIBUTE, target)
	end
end

-- Everyone with a seat in the draft: players and bots.
local function seatKeys(): { any }
	local keys: { any } = {}
	for _, player in Players:GetPlayers() do
		table.insert(keys, player)
	end
	for _, key in BotService.keys() do
		table.insert(keys, key)
	end
	return keys
end

local function teamOfKey(key: any): number?
	if BotService.isBot(key) then
		return BotService.teamOf(key)
	end
	return Teams.of(key)
end

-- Spawning ---------------------------------------------------------------------

local function isAlive(player: Player): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return Health.isAlive(humanoid)
end

local function onArena(player: Player): boolean
	if not isAlive(player) then
		return false
	end
	local character = player.Character
	if not character or character:GetAttribute("MatchId") ~= Context.id then
		return false
	end
	local map = MapService.map()
	if map then
		local root = character:FindFirstChild("HumanoidRootPart")
		if
			not (root and root:IsA("BasePart"))
			or math.abs(root.Position.Y - map:GetPivot().Position.Y) >= 400
		then
			return false
		end
	end
	return true
end

local function anyoneMissing(): boolean
	for team = 1, 2 do
		for _, player in playersOn(team) do
			if not onArena(player) then
				return true
			end
		end
	end
	return false
end

-- On the arena on the server AND on the player's own screen (BodyReady): what a round waits for before the
-- fight, so nobody starts as a camera in the void watching bots (owner 2026-11-25).
local function inView(player: Player): boolean
	return onArena(player) and bodyReady[player] == player.Character
end

local function anyoneOutOfView(): boolean
	for team = 1, 2 do
		for _, player in playersOn(team) do
			if not inView(player) then
				return true
			end
		end
	end
	return false
end

local function finiteVector(v: Vector3): boolean
	for _, n in { v.X, v.Y, v.Z } do
		if n ~= n or n == math.huge or n == -math.huge then
			return false
		end
	end
	return true
end

-- Client (Controllers/FloorHoldController): `body` is on its screen with floor under it, at `at` (the
-- ArenaSpawn it waited for). Only the current character counts, and only at the spot the server put it.
local function onBodyReady(player: Player, body: unknown, at: unknown)
	if not limiter:allow(player, "BodyReady") then
		return
	end
	if typeof(body) ~= "Instance" or body ~= player.Character or not body:IsA("Model") then
		return
	end
	local spawnAt = body:GetAttribute("ArenaSpawn")
	if typeof(spawnAt) == "Vector3" then
		if typeof(at) ~= "Vector3" or not finiteVector(at) or (at - spawnAt).Magnitude > 1 then
			return -- a check from before the server moved it to the arena
		end
	end
	if bodyReady[player] ~= body then
		bodyReady[player] = body
		HealthLog.stage("client has its body", player, Context.id)
	end
end

local function spawnPlayer(player: Player, spawn: SpawnLocation?)
	if spawning[player] or player.Parent ~= PlayersService then
		return
	end
	spawning[player] = true
	local okRun, runErr = pcall(function()
		player.RespawnLocation = if Context.ownsServer then spawn else nil
		local map = MapService.map()
		if not Context.ownsServer and map then
			pcall(map.AddPersistentPlayer, map, player)
		end
		if spawn then
			-- The spot streams in first, so nobody hangs in the air (Streaming
			-- PauseOutsideLoadedArea) while a big map arrives.
			pcall(player.RequestStreamAroundAsync, player, spawn.Position, STREAM_WAIT)
		end
		for attempt = 1, SPAWN_TRIES do
			if player.Parent ~= PlayersService then
				return
			end
			-- Spawned already wearing the standard match body (Match Avatar.md).
			local ok, errOrModel =
				pcall(CharacterService.loadCharacter, player, attempt == SPAWN_TRIES)
			local character: Model? = if ok
					and typeof(errOrModel) == "Instance"
					and errOrModel:IsA("Model")
				then errOrModel
				else player.Character
			if ok and character and character.Parent then
				local root = character:FindFirstChild("HumanoidRootPart")
					or character:WaitForChild("HumanoidRootPart", 5)
				local humanoid = character:FindFirstChildOfClass("Humanoid")
					or character:WaitForChild("Humanoid", 2)
				map = MapService.map()
				if spawn then
					local target = spawn.CFrame + Vector3.new(0, spawn.Size.Y / 2 + 3, 0)
					if
						not Context.ownsServer
						or (
							root
							and root:IsA("BasePart")
							and (root.Position - target.Position).Magnitude > 25
						)
					then
						character:PivotTo(target)
						if root and root:IsA("BasePart") then
							root.AssemblyLinearVelocity = Vector3.zero
							root.AssemblyAngularVelocity = Vector3.zero
						end
					end
					character:SetAttribute("MatchId", Context.id)
					character:SetAttribute("ArenaSpawn", target.Position)
					if map then
						MovementGuard.bind(player, map, target)
					end
				else
					character:SetAttribute("MatchId", Context.id)
				end
				if Health.isAlive(humanoid) then
					if inMatch and humanoid and humanoid:IsA("Humanoid") then
						StateValues.set(
							humanoid,
							Combat.SHIELD_ATTRIBUTE,
							DraftService.seat(player).shield
						)
						if not DraftService.isOpen() then
							WeaponService.giveLoadout(player)
						end
					end
					return
				end
				HealthLog.problem("match spawn missing parts", player, `try {attempt}`)
			else
				HealthLog.problem("match spawn failed", player, `try {attempt}: {errOrModel}`)
				warn("[MatchService] couldn't spawn", player.Name, "try", attempt, errOrModel)
			end
			if player.Parent ~= PlayersService then
				return
			end
			if attempt < SPAWN_TRIES then
				task.wait(SPAWN_BACKOFF[attempt] or 1)
			end
		end
	end)
	spawning[player] = nil
	if not okRun then
		warn("[MatchService] spawnPlayer error for", player.Name, runErr)
	end
end

-- Spawns the players `which` picks, each on their own spot at their team's end.
local function spawnPlayers(which: (player: Player) -> boolean)
	for team = 1, 2 do
		local spawns = MapService.spawns(team)
		for i, player in playersOn(team) do
			if which(player) then
				task.spawn(spawnPlayer, player, spawns[(i - 1) % math.max(#spawns, 1) + 1])
			end
		end
	end
end

-- The middle of a team's spawns.
-- Everyone back at their end with full health. Bots take the spawns after
-- their team's players, and head for the other end when they know nothing.
local function spawnEveryone()
	spawnPlayers(function()
		return true
	end)
	BotService.setRoamPoints(MapService.map(), MapService.spawnCentre(2), MapService.spawnCentre(1))
	for team = 1, 2 do
		BotService.spawnTeam(team, MapService.spawns(team), #playersOn(team) + 1)
	end
end

-- Anyone on a team with no live arena character: a failed or slow spawn, or someone
-- who joined after the round's spawn.
local function spawnMissing()
	spawnPlayers(function(player: Player): boolean
		return not onArena(player) and not spawning[player]
	end)
end

-- Round results ----------------------------------------------------------------

local function teamState(team: number): (number, number)
	local alive, health = 0, 0
	for _, player in playersOn(team) do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and Health.isAlive(humanoid) then
			alive += 1
			local shield = StateValues.get(humanoid, Combat.SHIELD_ATTRIBUTE)
			health += Health.get(humanoid) + (if typeof(shield) == "number" then shield else 0)
		end
	end
	local botsAlive, botsHealth = BotService.teamState(team)
	return alive + botsAlive, health + botsHealth
end

local function someoneOut(): boolean
	local one = teamState(1)
	local two = teamState(2)
	return one == 0 or two == 0
end

-- 1 or 2, or 0 when nobody takes the round (both dead, or equal health).
local function roundWinner(): number
	local aliveOne, healthOne = teamState(1)
	local aliveTwo, healthTwo = teamState(2)
	if aliveOne == 0 and aliveTwo == 0 then
		return 0
	elseif aliveTwo == 0 then
		return 1
	elseif aliveOne == 0 then
		return 2
	end
	if healthOne > healthTwo then
		return 1
	elseif healthTwo > healthOne then
		return 2
	end
	return 0
end

-- The fighters still alive on `team` (Players and bot models): the task Path's round counts.
local function survivors(team: number): { Instance }
	local out: { Instance } = {}
	for _, player in playersOn(team) do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and Health.isAlive(humanoid) then
			table.insert(out, player)
		end
	end
	for _, key in BotService.keys() do
		if BotService.teamOf(key) == team then
			local model = BotService.modelOf(key)
			local humanoid = model and model:FindFirstChildOfClass("Humanoid")
			if model and humanoid and Health.isAlive(humanoid) then
				table.insert(out, model)
			end
		end
	end
	return out
end

-- Name and HP+shield of the single surviving fighter on `team` (nil if 0 or 2+ alive).
local function soleSurvivor(team: number): (string?, number)
	local name: string? = nil
	local hp = 0
	local count = 0
	for _, player in playersOn(team) do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and Health.isAlive(humanoid) then
			count += 1
			name = player.DisplayName
			local shield = StateValues.get(humanoid, Combat.SHIELD_ATTRIBUTE)
			hp = Health.get(humanoid) + (if typeof(shield) == "number" then shield else 0)
		end
	end
	for _, key in BotService.keys() do
		if BotService.teamOf(key) == team then
			local model = BotService.modelOf(key)
			local humanoid = model and model:FindFirstChildOfClass("Humanoid")
			if model and humanoid and Health.isAlive(humanoid) then
				count += 1
				name = model.Name
				local shield = StateValues.get(humanoid, Combat.SHIELD_ATTRIBUTE)
				hp = Health.get(humanoid) + (if typeof(shield) == "number" then shield else 0)
			end
		end
	end
	if count == 1 then
		return name, hp
	end
	return nil, 0
end

local function computeRoundCallout(winner: number, eliminated: boolean): MatchState.RoundCallout?
	if winner == 0 or not eliminated then
		return nil
	end
	local loser = 3 - winner
	local aliveW, hpW = teamState(winner)
	local startW, startL = roundStartCounts[winner], roundStartCounts[loser]
	local c = clutchState[winner]
	if c and aliveW == 1 then
		return {
			tag = "CLUTCH",
			detail = string.format("1v%d", c.vs),
			actor = c.actor,
			team = winner,
		}
	end
	if startL >= 2 then
		local topName, topKills = StatsService.roundTopKiller(winner)
		if topName and topKills >= startL then
			return {
				tag = "ACE",
				detail = string.format("%d ELIMS", topKills),
				actor = topName,
				team = winner,
			}
		end
	end
	if startW >= 2 and aliveW >= startW then
		return { tag = "FLAWLESS", detail = "ZERO DEATHS", team = winner }
	elseif startW == 1 and aliveW == 1 and StatsService.roundDamageTaken(winner) == 0 then
		return { tag = "FLAWLESS", detail = "UNTOUCHED", team = winner }
	end
	if aliveW == 1 and hpW > 0 and hpW <= 15 then
		local hero = soleSurvivor(winner)
		return {
			tag = "CLOSE CALL",
			detail = string.format("%d HP LEFT", math.max(1, math.round(hpW))),
			actor = hero,
			team = winner,
		}
	end
	return nil
end

-- The draft --------------------------------------------------------------------

-- "id:level" for each ability on the other team.
local function enemyKit(key: any): { string }
	local kit: { string } = {}
	local mine = teamOfKey(key)
	for _, other in seatKeys() do
		if teamOfKey(other) ~= mine then
			for _, entry in DraftService.kitOf(other) do
				table.insert(kit, entry)
			end
		end
	end
	return kit
end

local function matchLoadout(seat: DraftService.Seat): { [any]: string }
	return {
		Primary = seat.primary,
		Secondary = seat.sidearm or Weapons.DEFAULT_LOADOUT.Secondary,
		Melee = Weapons.DEFAULT_LOADOUT.Melee,
	}
end

-- Hands out what the draft decided: guns in hand and abilities in their slots.
local function applyDraft(keys: { any })
	for _, key in keys do
		if BotService.isBot(key) then
			local seat = DraftService.seat(key)
			BotService.applyDraft(key, matchLoadout(seat), seat.kit, seat.levels, true)
		elseif typeof(key) == "Instance" and key:IsA("Player") and key.Parent == PlayersService then
			local player = key
			local seat = DraftService.seat(player)
			WeaponService.setMatchLoadout(player, matchLoadout(seat))
			if isAlive(player) then
				WeaponService.giveLoadout(player)
			end
			for slot = 1, ModsConfig.SLOTS do
				local id = seat.kit[slot]
				local level = seat.levels[slot]
				ModService.setSlot(
					player,
					slot,
					if id ~= "" then id else nil,
					if level ~= "" then level else Config.ABILITY_LEVEL
				)
			end
		end
	end
end

-- Everyone's shield for the round, from the gun they chose or the phase.
local function giveShields()
	for _, key in seatKeys() do
		if BotService.isBot(key) then
			BotService.giveShield(key, DraftService.seat(key).shield)
			continue
		end
		if not (typeof(key) == "Instance" and key:IsA("Player")) then
			continue
		end
		local character = key.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			StateValues.set(humanoid, Combat.SHIELD_ATTRIBUTE, DraftService.seat(key).shield)
		end
	end
end

-- A side that has had real players this match and now has no fighters
-- left (neither humans nor bot backfill) past FORFEIT_GRACE: the other
-- side wins. 0 when everyone left or both are gone, nil while it goes on.
local function forfeitWinner(): number?
	if not inMatch then
		return nil
	end
	if #Players:GetPlayers() == 0 then
		return 0
	end
	for t = 1, 2 do
		if humanSides[t] and sideCount(t) == 0 then
			sideEmptySince[t] = sideEmptySince[t] or os.clock()
		else
			sideEmptySince[t] = nil
		end
	end
	local now = os.clock()
	local goneOne = sideEmptySince[1] ~= nil
		and (now - (sideEmptySince[1] :: number)) >= FORFEIT_GRACE
	local goneTwo = sideEmptySince[2] ~= nil
		and (now - (sideEmptySince[2] :: number)) >= FORFEIT_GRACE
	if goneOne and goneTwo then
		return 0
	elseif goneOne then
		return 2
	elseif goneTwo then
		return 1
	end
	return nil
end

local function forfeited(): boolean
	return forfeitWinner() ~= nil
end

-- Progression: everyone who played a part of this match, and who has been
-- reported (a leaver at once, the rest at the end).
local matchKey = ""
local participants: { [number]: number } = {} -- userId -> team
local reported: { [number]: boolean } = {}

local function noteHumans()
	for team = 1, 2 do
		if #playersOn(team) > 0 then
			humanSides[team] = true
		end
		for _, player in playersOn(team) do
			participants[player.UserId] = team
		end
	end
end

local function opponentsOf(team: number): { number }
	local list: { number } = {}
	for userId, t in participants do
		if t ~= team then
			table.insert(list, userId)
		end
	end
	return list
end

local function killsOf(userId: number): number
	for _, line in StatsService.summary() do
		if line.userId == userId then
			return line.eliminations
		end
	end
	return 0
end

-- Players per team (the Lobby plan's, else the bigger side): the task Path's 1v1 / 2v2 / 3v3.
local function teamSize(): number
	local plan = MatchPlan.current()
	if plan then
		return plan.size
	end
	return math.max(sideCount(1), sideCount(2), 1)
end

-- One player's match into their save (once per match; later calls do nothing).
-- `theirScore`: the other side's rounds (a won match with 0 is flawless).
local function reportProgress(
	userId: number,
	team: number,
	won: boolean,
	left: boolean,
	roundsWon: number,
	theirScore: number?
)
	if reported[userId] or matchKey == "" then
		return
	end
	reported[userId] = true
	local opponents = opponentsOf(team)
	-- the task Path (Shared/TaskPath MatchStats; ProgressionService checks it again). Guarded: a fault here must
	-- never cost the player their XP and match pay.
	local statsOk, taskStats = pcall(function(): { [string]: any }
		local t = StatsService.taskStats(userId)
		local wonIt = won and not left
		t.played = not left
		t.won = wonIt
		t.flawless = wonIt and theirScore == 0
		t.glitchWin = wonIt and t.glitch == true
		t.glitch = nil
		t.teamSize = teamSize()
		t.map = lastMap or ""
		return t
	end)
	if not statsOk then
		warn("[MatchService] task stats failed:", taskStats)
		taskStats = nil
	end
	local ok, err = pcall(ProgressionService.report, matchKey, userId, {
		won = won and not left,
		left = left,
		-- Studio test switch: Workspace attribute ProgressBotsCount = true lets bot matches move the streak
		counts = #opponents > 0
			or (
				game:GetService("RunService"):IsStudio()
				and workspace:GetAttribute("ProgressBotsCount") == true
			),
		roundsWon = roundsWon,
		kills = killsOf(userId),
		opponents = opponents,
	}, MatchState.get("Mode"), taskStats)
	if not ok then
		warn("[MatchService] progression report failed:", err)
	end
end

-- The select screen: SELECT time in all, the last COUNTDOWN of it the 3-2-1.
-- The top-bar clock counts to the fight. Any round skips to the 3-2-1 once
-- everyone has locked in.
-- Loads a map, never throwing: a map that fails to load keeps the one already loaded.
local function loadMap(id: string): boolean
	local ok, loaded = pcall(MapService.load, id)
	if not ok then
		HealthLog.problem("map load failed", nil, `{Context.id} {id}: {loaded}`)
		return false
	end
	if loaded then
		HealthLog.stage("map loaded", nil, `{Context.id} {id}`)
	end
	return loaded == true
end

-- Opens round `round`'s select (offers, bot picks, Phase "Draft") and returns its picking time.
local function openDraft(round: number): number
	local total = if round == 1
		then Config.FIRST_SELECT_TIME
		else Config.SELECT_TIME_BY_MODE[matchMode()] or Config.SELECT_TIME
	local picking = math.max(total - Config.COUNTDOWN_TIME, 1)
	-- A new player's scripted round with no pick screen (Config/Onboarding SCRIPT): just time to spawn.
	local step = DraftService.scriptStep(round)
	if step and step.select == "none" then
		picking = OnbConfig.HIDDEN_SELECT_TIME
		total = picking + Config.COUNTDOWN_TIME
	end
	local keys = seatKeys()
	local now = workspace:GetServerTimeNow()
	DraftService.open(keys, round, now + picking, enemyKit)
	-- Bots pick from the same offers (Bots/BotDraft).
	for _, key in keys do
		if BotService.isBot(key) then
			BotService.draft(key, DraftService.seat(key) :: any)
		end
	end
	MatchState.set("WeaponPhase", DraftService.phaseFor(round).name)
	MatchState.set("EndsAt", now + total)
	MatchState.set("Phase", "Draft")
	return picking
end

-- Waits out the open select (or until everyone has locked in), then closes it and hands out the picks.
local function finishDraft(picking: number)
	runClock(picking, function()
		-- Everyone locked in skips to the 3-2-1, unless someone's fighter isn't on their screen yet: the
		-- select's own time is free waiting for them.
		return forfeited() or (DraftService.allLocked(seatKeys()) and not anyoneOutOfView())
	end)
	DraftService.close(seatKeys())
	applyDraft(seatKeys())
	giveShields()
end

-- Joining and leaving -----------------------------------------------------------

-- A player takes the seat their bot stand-in kept for them.
local function takeOver(player: Player, bot: any)
	local team = MatchPlan.teamFor(player) or BotService.teamOf(bot)
	if team then
		StateValues.set(player, Teams.ATTRIBUTE, team)
	end
	standIns[player.UserId] = nil
	pendingTakeovers[player] = nil
	DraftService.transfer(bot, player)
	BotService.remove(bot)
	noteHumans()
	applyDraft({ player })
end

-- Lobby matches: every listed player who isn't here gets a bot stand-in, and
-- the rest of each side fills with bots.
-- Beginner 2v2 red enemies (Controllers/BeginnerHighlightController): who each fighter has hit this match,
-- published as "RedHits" (comma-joined "p<UserId>" / "b<BotId>") on the Player or the bot's seat, so a
-- spectator sees the watched teammate's red enemies, not their own.
local redHits: { [Instance]: { [string]: boolean } } = {}

local function fighterKey(body: Model): string?
	local owner = Players:GetPlayerFromCharacter(body)
	if owner then
		return "p" .. owner.UserId
	end
	local botId = StateValues.get(body, "BotId")
	return if botId ~= nil then "b" .. tostring(botId) else nil
end

-- Where a fighter's RedHits live: the Player, or the bot's seat (it outlives the bot's body).
local function redHolder(attacker: Instance): Instance?
	if attacker:IsA("Player") then
		return attacker
	end
	local botId = StateValues.get(attacker, "BotId")
	if botId == nil then
		return nil
	end
	for _, seat in MatchState.botSeats() do
		if StateValues.get(seat, "BotId") == botId then
			return seat
		end
	end
	return nil
end

local function noteRedHit(attacker: Instance, victim: Model, dealt: number)
	if dealt <= 0 or MatchState.get("Mode") ~= "beginner" then
		return
	end
	local holder = redHolder(attacker)
	local key = fighterKey(victim)
	if not holder or not key then
		return
	end
	local set = redHits[holder]
	if not set then
		set = {}
		redHits[holder] = set
	end
	if set[key] then
		return
	end
	set[key] = true
	local list = {}
	for k in set do
		table.insert(list, k)
	end
	StateValues.set(holder, "RedHits", table.concat(list, ","))
end

local function clearRedHits()
	for holder in redHits do
		if holder.Parent then
			StateValues.set(holder, "RedHits", nil)
		end
	end
	table.clear(redHits)
end

-- Rounds a side needs to win the match. Studio test switch: Workspace attribute QuickMatch = true ends a match
-- after one round (owner 2026-11-23: a quick way to test the match end).
local function roundsToWin(): number
	if RunService:IsStudio() and workspace:GetAttribute("QuickMatch") == true then
		return 1
	end
	if firstMatch or onboardingMatch then
		return Config.FIRST_MATCH_ROUNDS_TO_WIN
	end
	return Config.ROUNDS_TO_WIN_BY_MODE[matchMode()] or Config.ROUNDS_TO_WIN
end

-- A Beginner match where every real player here has fewer than `below` matches saved (1: a new player's very
-- first match; Config.ONBOARDING_MATCHES: an onboarding match). Read once at the match's start (runMatch) so a
-- late joiner can't change the match.
local function allPlayersBelow(below: number): boolean
	if matchMode() ~= "beginner" then
		return false
	end
	local any = false
	for _, player in Players:GetPlayers() do
		local matches = StateValues.get(player, "Matches")
		if typeof(matches) ~= "number" or matches >= below then
			return false
		end
		any = true
	end
	return any
end

local function isFirstMatch(): boolean
	return allPlayersBelow(1)
end

-- The bots' dynamic difficulty from this match's real players (Bots/AutoDifficulty): at the
-- fill and at each round, with the score once the match is running.
local function updateBotDifficulty(scores: { number }?)
	local levels, streaks, mobile = {}, {}, 0
	local teamsSeen: { [number]: boolean } = {}
	for _, player in Players:GetPlayers() do
		local team = Teams.of(player)
		if team == 1 or team == 2 then
			teamsSeen[team] = true
			local level = StateValues.get(player, "Level")
			local streak = StateValues.get(player, "WinStreak")
			table.insert(levels, if typeof(level) == "number" then level else 1)
			table.insert(streaks, if typeof(streak) == "number" then streak else 0)
			if StateValues.get(player, "Device") == "Mobile" then
				mobile += 1
			end
		end
	end
	local lead: number? = nil
	if scores and teamsSeen[1] ~= teamsSeen[2] then
		local mine = if teamsSeen[1] then 1 else 2
		lead = scores[mine] - scores[3 - mine]
	end
	local plan = MatchPlan.current()
	local name = AutoDifficulty.pick({
		levels = levels,
		mobile = mobile,
		streaks = streaks,
		mode = if plan then plan.mode else nil,
		lead = lead,
		onboarding = onboardingMatch or allPlayersBelow(Config.ONBOARDING_MATCHES),
	})
	BotService.setAuto(name)
end

local function fillSlots()
	updateBotDifficulty(nil)
	local plan = MatchPlan.current()
	if not plan then
		return
	end
	for team = 1, 2 do
		for _, userId in plan.teams[team] do
			local kept = standIns[userId]
			if not Players:GetPlayerByUserId(userId) and not (kept and BotService.isBot(kept)) then
				standIns[userId] = BotService.add(team, 1)[1]
			end
		end
		local missing = plan.size - sideCount(team)
		if missing > 0 then
			BotService.add(team, missing)
		end
	end
end

-- Late players whose stand-in kept their seat during the last fight.
local function applyTakeovers()
	for player, bot in pendingTakeovers do
		if player.Parent == PlayersService and BotService.isBot(bot) then
			takeOver(player, bot)
		end
	end
	table.clear(pendingTakeovers)
end

local function spawnOne(player: Player)
	spawnPlayers(function(p: Player): boolean
		return p == player
	end)
end

local function logMapStart(player: Player)
	if mapLogged[player.UserId] then
		return
	end
	mapLogged[player.UserId] = true
	local mode = matchMode()
	Telemetry.mapPlayed(player, currentMapName, mode)
	Telemetry.mapFunnel(player, matchKey, 1, "Map loaded", currentMapName, mode)
end

local function onJoin(player: Player)
	if player.Parent ~= PlayersService then
		return
	end
	if inMatch then
		logMapStart(player)
	end
	local bot = standIns[player.UserId]
	local phase = MatchState.phase()
	local selecting = inMatch and (phase == "Draft" or phase == "Countdown")
	if bot and BotService.isBot(bot) then
		-- Their side from the start, even while the bot still plays the seat.
		local team = MatchPlan.teamFor(player) or BotService.teamOf(bot)
		if team then
			StateValues.set(player, Teams.ATTRIBUTE, team)
		end
		if selecting then
			takeOver(player, bot)
			spawnOne(player)
		else
			-- Mid-fight: the bot plays on; the seat is theirs from the next round.
			pendingTakeovers[player] = bot
		end
		return
	end
	local listedTeam = MatchPlan.teamFor(player)
	if listedTeam then
		StateValues.set(player, Teams.ATTRIBUTE, listedTeam)
	end
	if selecting then
		-- No seat kept: dealt in (a Studio test client, or a free join).
		DraftService.join(player)
		noteHumans()
		spawnOne(player)
	end
end

-- Team modes: a bot takes a leaver's seat (and plays from now in a select,
-- else from the next round). A 1v1 leaver forfeits (forfeitWinner).
local function onLeave(player: Player)
	spawning[player] = nil
	bodyReady[player] = nil
	limiter:forget(player)
	-- Leaving a match before its end is a loss (Progression.md).
	local leftTeam = participants[player.UserId]
	if inMatch and leftTeam and not reported[player.UserId] then
		local score = MatchState.get(if leftTeam == 1 then "Score1" else "Score2")
		reportProgress(
			player.UserId,
			leftTeam,
			false,
			true,
			if typeof(score) == "number" then score else 0
		)
		Telemetry.mapLeftEarly(player, currentMapName, matchMode(), currentRound)
		-- Where in the match they left (owner 2026-11-25, onboarding funnel): the phase, their score, the last
		-- round's result, and whether this was their first match.
		local theirs = MatchState.get(if leftTeam == 1 then "Score2" else "Score1")
		local lastWinner = MatchState.get("RoundWinner")
		Telemetry.matchLeft(
			player,
			currentRound,
			tostring(MatchState.phase() or "?"),
			string.format(
				"%d-%d %s",
				if typeof(score) == "number" then score else 0,
				if typeof(theirs) == "number" then theirs else 0,
				if lastWinner == leftTeam
					then "W"
					elseif typeof(lastWinner) == "number" and lastWinner ~= 0 then "L"
					else "-"
			),
			-- "kind:device" (owner 2026-11-25): only three custom fields, and the funnel needs the phone split
			string.format(
				"%s:%s",
				if firstMatch then "first" elseif onboardingMatch then "onboarding" else matchMode(),
				tostring(StateValues.get(player, "Device") or "?")
			)
		)
	end
	local wasPending = pendingTakeovers[player] ~= nil
	pendingTakeovers[player] = nil
	local team = Teams.of(player)
	local plan = MatchPlan.current()
	local size = if plan then plan.size elseif team then sideCount(team) else 1
	local kept = standIns[player.UserId]
	local standInPlays = kept ~= nil and BotService.isBot(kept)
	local stillCounted = table.find(Players:GetPlayers(), player) ~= nil
	local remaining = if team then sideCount(team) - (if stillCounted then 1 else 0) else 0
	-- Nothing to replace: no match, a 1v1 (forfeit), their stand-in still has
	-- the seat (they never took it over), or the side is already full.
	if not inMatch or not team or size <= 1 or wasPending or standInPlays or remaining >= size then
		DraftService.forget(player)
		return
	end
	local bot = BotService.add(team, 1)[1]
	standIns[player.UserId] = bot -- if they come back, they take the seat back
	DraftService.transfer(player, bot)
	local seat = DraftService.seat(bot)
	BotService.applyDraft(bot, matchLoadout(seat), seat.kit, seat.levels, true)
	if DraftService.isOpen() then
		BotService.draft(bot, seat :: any)
	end
	local phase = MatchState.phase()
	local spawns = MapService.spawns(team)
	if (phase == "Draft" or phase == "Countdown") and #spawns > 0 then
		local spot = spawns[math.max(0, remaining) % #spawns + 1]
		BotService.spawnOne(bot, spot.CFrame)
	end
end

-- One match --------------------------------------------------------------------

-- A clean slate for everyone, for a new match.
local function resetKits()
	DraftService.reset()
	for _, key in BotService.keys() do
		local seat = DraftService.seat(key)
		BotService.applyDraft(key, matchLoadout(seat), { "", "", "" }, { "", "", "" })
	end
	for _, player in Players:GetPlayers() do
		WeaponService.setMatchLoadout(player, matchLoadout(DraftService.seat(player)))
		for slot = 1, ModsConfig.SLOTS do
			ModService.setSlot(player, slot, nil, Config.ABILITY_LEVEL)
		end
	end
end

-- Which side is left if everyone on the other one has gone (nil: both are
-- still here, or nobody is).
local function sideLeftStanding(): number?
	if bothSidesFilled() then
		return nil
	end
	if sideCount(1) > 0 then
		return 1
	elseif sideCount(2) > 0 then
		return 2
	end
	return nil
end

-- Plays the final kill on every client (Controllers/ReplayController): the
-- losing side's last fighter, if the round ended because that side was
-- eliminated just now (no replay for a timeout or a health compare).

-- The mode for Play Again ("1v1", "2v2", "3v3"): the Lobby plan's, else the
-- bigger side's size.
matchMode = function(): string
	local plan = MatchPlan.current()
	if plan then
		return plan.mode
	end
	local size = math.max(sideCount(1), sideCount(2), 1)
	return `{size}v{size}`
end

local function reportStage(
	step: number,
	title: string,
	firstBeginner: number?,
	secondMatch: number?,
	thirdMatch: boolean? -- Onboarding_v2 "Match 3 started" (round 1 live)
)
	local mode = matchMode()
	for _, player in Players:GetPlayers() do
		Telemetry.funnel(player, "Match", matchKey, step, title, mode)
		local matches = StateValues.get(player, "Matches")
		if firstBeginner and mode == "beginner" and matches == 0 then
			Telemetry.onboarding(player, firstBeginner)
		elseif secondMatch and matches == 1 then
			Telemetry.onboarding(player, secondMatch)
		elseif thirdMatch and matches == 2 then
			Telemetry.onboardingV2(player, Telemetry.V2.MATCH_3_STARTED, mode)
		end
	end
end

-- Everyone in the match gets a stats line, even with nothing on it.
local function noteFighters()
	for _, player in Players:GetPlayers() do
		StatsService.note(player)
	end
	for _, key in BotService.keys() do
		local model = BotService.modelOf(key)
		if model then
			StatsService.note(model)
		end
	end
end

-- The round is over for good: combat locks and every Mod's leftovers (walls,
-- fire, Recall anchors) go. Runs after RoundEnd, or straight away when the
-- match ends (a replay or the end screen comes next).
local function closeRound()
	setAllLocked(true)
	BotService.setFighting(false)
	for _, player in Players:GetPlayers() do
		ModService.clearRound(player)
	end
end

-- After a round stopped on an error: no fight, no circle, no open select;
-- everyone back behind the barrier, ready to play the round again.
local function recoverRound()
	local ok, err = pcall(function()
		ZoneService.stop()
		BotService.setFighting(false)
		if DraftService.isOpen() then
			DraftService.close(seatKeys())
		end
		closeRound()
		MapService.setBarriers(true)
	end)
	if not ok then
		warn("[MatchService] couldn't tidy up after the round error:", err)
	end
end

type RoundOutcome = "next" | "stop" | "abandon"

-- Runs one match. Returns true when the players voted a rematch.
local roundHistory: { string } = {} -- the match end screen's round chips (MatchState list "RoundHistory")

local function runMatch(): boolean
	balanceTeams()
	if MatchPlan.current() then
		fillSlots()
	end
	firstMatch = isFirstMatch()
	onboardingMatch = allPlayersBelow(Config.ONBOARDING_MATCHES)
	-- before round 1's draft deals: onboarding matches deal the better guns early (MatchState.phaseFor)
	MatchState.set("PhaseBoost", onboardingMatch)
	-- which of a new player's first matches this is (Config/Onboarding SCRIPT: DraftService deals from it)
	MatchState.set(
		"OnboardingMatch",
		if firstMatch then 1 elseif onboardingMatch then math.min(2, #OnbConfig.SCRIPT) else 0
	)
	inMatch = true
	StatsService.reset()
	humanSides = { false, false }
	sideEmptySince[1] = nil
	sideEmptySince[2] = nil
	table.clear(mapLogged)
	currentMapName = mapLabel(pendingMap or lastMap)
	currentRound = 0
	-- clients read the mode (Beginner 2v2's red enemies: Controllers/BeginnerHighlightController)
	MatchState.set("Mode", matchMode())
	MatchState.set("RoundsToWin", roundsToWin())
	clearRedHits()
	table.clear(participants)
	table.clear(reported)
	noteHumans()
	for _, player in Players:GetPlayers() do
		logMapStart(player)
	end
	setAllLocked(true)
	MatchState.set("Round", 0)
	MatchState.set("Score1", 0)
	MatchState.set("Score2", 0)
	MatchState.set("RoundWinner", nil)
	MatchState.set("RoundCallout", nil)
	MatchState.set("MatchWinner", nil)
	MatchState.set("Results", nil)
	roundStartCounts[1], roundStartCounts[2] = 0, 0
	clutchState[1], clutchState[2] = nil, nil
	roundHistory = {}
	MatchState.setList("RoundHistory", roundHistory) -- "winner:WeaponPhase" per round
	MapService.setBarriers(true)
	resetKits()
	table.clear(lastDown)

	local scores = { 0, 0 }
	local round = 0
	local emptyRounds = 0
	local forfeitBy: number? = nil
	local function over(): boolean
		return someoneOut() or forfeited()
	end
	-- One round, from the select to RoundEnd: "next", "stop" (the match is
	-- decided) or "abandon" (nobody left to play).
	local scored = false -- this round's point is already on the board
	local draftReported = false
	local doneCount = 0
	local liveReported: { [number]: boolean } = {}
	local doneReported: { [number]: boolean } = {}
	local function playRound(): RoundOutcome
		round += 1
		currentRound = round
		scored = false
		roundStartCounts[1], roundStartCounts[2] = 0, 0
		clutchState[1], clutchState[2] = nil, nil
		MatchState.set("Round", round)
		MatchState.set("RoundWinner", nil)
		MatchState.set("RoundCallout", nil)
		StatsService.newRound()
		clearRedHits() -- Beginner red enemies light up again every round (owner 2026-11-23)
		updateBotDifficulty(scores)
		setAllLocked(true)
		MapService.resetGlass()
		MapService.setBarriers(true)
		applyTakeovers()
		-- The select opens first; a voted map still to load attaches right after it (pendingMap), so its
		-- download runs behind the select screen. Everyone spawns once it's in.
		local picking = openDraft(round)
		local nextMap = pendingMap
		if nextMap then
			pendingMap = nil
			if loadMap(nextMap) then
				lastMap = nextMap
				MapService.resetGlass()
				MapService.setBarriers(true)
			end
		end
		spawnEveryone()
		if not draftReported then
			draftReported = true
			reportStage(3, "R1 draft opened", 3)
		end
		finishDraft(picking)
		noteFighters()

		spawnMissing()
		if not forfeited() then
			setPhase("Countdown", Config.COUNTDOWN_TIME)
			runClock(Config.COUNTDOWN_TIME, forfeited)
		end
		if (someoneOut() or anyoneMissing()) and not forfeited() then
			-- someone died or didn't reach the arena yet (slow load / streaming): back in
			spawnMissing()
			runClock(Config.LATE_SPAWN_WAIT, function()
				if anyoneMissing() then
					spawnMissing()
				end
				return (not someoneOut() and not anyoneMissing()) or forfeited()
			end)
		end
		if anyoneOutOfView() and not forfeited() then
			-- The server has them but their own screen doesn't show their fighter yet (a slow device, a big map
			-- still arriving): the barrier stays up a little longer.
			runClock(Config.BODY_READY_WAIT, function()
				if anyoneMissing() then
					spawnMissing()
				end
				return not anyoneOutOfView() or forfeited()
			end)
			for team = 1, 2 do
				for _, player in playersOn(team) do
					if not inView(player) then
						HealthLog.problem(
							"fight started before the client showed its fighter",
							player,
							`{Context.id} round {round}`
						)
					end
				end
			end
		end

		-- A side with nobody alive at the start isn't a fight: no point, go again.
		-- Rounds in a row like that (a side that can't spawn) end the match.
		local winner = 0
		local eliminated = false
		if someoneOut() and not forfeited() then
			emptyRounds += 1
			if emptyRounds >= Config.MAX_EMPTY_ROUNDS then
				local one, two = teamState(1), teamState(2)
				forfeitBy = if one > 0 and two == 0 then 1 elseif two > 0 and one == 0 then 2 else 0
				warn(
					"[MatchService] a side couldn't spawn for",
					emptyRounds,
					"rounds: the match ends"
				)
				return "stop"
			end
		else
			emptyRounds = 0
		end
		if not over() then
			giveShields() -- anyone spawned late has one too
			-- Fight. Charges come back here, so nothing spent behind the barrier counts.
			for _, player in Players:GetPlayers() do
				ModService.refillCharges(player)
			end
			BotService.refillCharges()
			MapService.setBarriers(false)
			setAllLocked(false)
			BotService.setFighting(true)
			roundStartCounts = { teamState(1), teamState(2) }
			setPhase("Live", Config.ROUND_TIME)
			local fightRound = doneCount + 1
			if fightRound <= 4 and not liveReported[fightRound] then
				liveReported[fightRound] = true
				local step = 2 + fightRound * 2
				reportStage(
					step,
					`R{fightRound} live`,
					step,
					if fightRound == 1 then 18 else nil,
					fightRound == 1
				)
			end
			HealthLog.stage(
				"round start",
				nil,
				string.format(
					"%s round %d, alive %d v %d",
					Context.id,
					round,
					teamState(1),
					teamState(2)
				)
			)
			runClock(Config.ROUND_TIME, over)
			-- Sudden death: the circle closes until a side is out.
			if not over() and ZoneService.begin() then
				setPhase("SuddenDeath", Config.SUDDEN_DEATH.shrinkTime)
				runClock(Config.SUDDEN_DEATH.maxTime, over)
			end
			ZoneService.stop()

			BotService.setFighting(false)
			-- Combat stays open through RoundEnd (players can shoot and cast for
			-- fun; Weapon/Damage deals nothing in that phase). closeRound locks it.
			eliminated = someoneOut()
			winner = roundWinner()
			if fightRound <= 4 and not doneReported[fightRound] then
				doneReported[fightRound] = true
				doneCount = fightRound
				local step = 3 + fightRound * 2
				reportStage(step, `R{fightRound} completed`, step)
				if fightRound == 1 then
					for _, player in Players:GetPlayers() do
						Telemetry.mapFunnel(
							player,
							matchKey,
							2,
							"First round completed",
							currentMapName,
							matchMode()
						)
					end
				end
			end
		end
		forfeitBy = forfeitWinner()
		if forfeitBy then
			closeRound()
			return "stop"
		end
		if winner ~= 0 then
			scores[winner] += 1
			local ok, err = pcall(function()
				StatsService.roundEnded(
					winner,
					roundStartCounts[winner],
					roundStartCounts[3 - winner],
					survivors(winner),
					DraftService.phaseFor(round).tier
				)
			end)
			if not ok then
				warn("[MatchService] task round stats failed:", err) -- the task Path only: the round goes on
			end
		end
		scored = true
		MatchState.set("Score1", scores[1])
		MatchState.set("Score2", scores[2])
		MatchState.set("RoundWinner", winner)
		MatchState.set("RoundCallout", computeRoundCallout(winner, eliminated))
		-- The match end screen's round chips (display only).
		local phaseName = MatchState.get("WeaponPhase")
		table.insert(
			roundHistory,
			string.format("%d:%s", winner, if typeof(phaseName) == "string" then phaseName else "")
		)
		MatchState.setList("RoundHistory", roundHistory)
		if winner ~= 0 and scores[winner] >= roundsToWin() then
			-- No final-kill replay (owner 2026-11-25): a short beat on the last kill (the loser's fall plays
			-- out, the winner can move about), then straight into the win cutscene (MatchEndService).
			setPhase("RoundEnd", Config.MATCH_END_PAUSE)
			BotService.setFighting(false, true)
			runClock(Config.MATCH_END_PAUSE)
			closeRound()
			return "stop"
		end
		local roundEnd = Config.ROUND_END_TIME_BY_MODE[matchMode()] or Config.ROUND_END_TIME
		setPhase("RoundEnd", roundEnd)
		BotService.setFighting(false, true)
		runClock(roundEnd, forfeited)
		closeRound()

		if #Players:GetPlayers() == 0 then
			return "abandon" -- only bots are left
		end
		forfeitBy = forfeitWinner()
		if forfeitBy then
			return "stop"
		end
		if not bothSidesFilled() then
			-- Nobody at all on one side (no bots either): whoever stayed wins.
			forfeitBy = sideLeftStanding()
			if not forfeitBy then
				return "abandon" -- nobody is left at all
			end
			return "stop"
		end
		return "next"
	end

	-- An error in one round must not throw the match away (it used to: the loop
	-- caught it and started a new match on a new map, mid-match). The round is
	-- logged, everyone goes back behind the barrier and it is played again on
	-- the same map. Too many in a row: the match ends on the current score.
	local roundErrors = 0
	while scores[1] < roundsToWin() and scores[2] < roundsToWin() do
		local ok, outcome = xpcall(playRound, debug.traceback)
		if ok then
			roundErrors = 0
			if outcome == "stop" then
				break
			elseif outcome == "abandon" then
				return false
			end
		else
			roundErrors += 1
			warn(
				string.format(
					"[MatchService] round %d stopped on an error (%d in a row), playing on:",
					round,
					roundErrors
				),
				outcome
			)
			recoverRound()
			if not scored then
				round -= 1 -- the same round again
			end
			if roundErrors >= Config.MAX_ROUND_ERRORS then
				forfeitBy = forfeitWinner()
				break
			end
			task.wait(RETRY_AFTER_ERROR)
		end
	end

	if forfeitBy == 0 then
		return false -- everyone left
	end
	setAllLocked(true)
	ZoneService.stop()
	BotService.setFighting(false)
	local matchWinner = forfeitBy or (if scores[1] > scores[2] then 1 else 2)
	MatchState.set("MatchWinner", matchWinner)
	if firstMatch then
		-- A first match is first to 3, so it can end before round 4: its funnel steps 10-11 ("M1 R4 ... or won")
		-- fire for everyone still here (Telemetry.onboarding sends each step once).
		for _, player in Players:GetPlayers() do
			Telemetry.onboarding(player, 10)
			Telemetry.onboarding(player, 11)
		end
	end
	for userId, team in participants do
		local player = Players:GetPlayerByUserId(userId)
		local here = player ~= nil and Teams.of(player) == team
		reportProgress(userId, team, team == matchWinner, not here, scores[team], scores[3 - team])
		if here and player then
			Telemetry.mapCompleted(player, currentMapName, matchMode(), round)
			Telemetry.mapFunnel(player, matchKey, 3, "Match completed", currentMapName, matchMode())
		end
	end
	-- a new player's first match: everyone who finishes it gets the free Starter Case (ProgressionService)
	return MatchEndService.run(matchWinner, matchMode(), firstMatch)
end

local function cancelSlowLoad(reason: string)
	HealthLog.problem("match load cancelled", nil, `{Context.id}: {reason}`)
	MatchState.set("Phase", "Cancelled")
	local mode = matchMode()
	local requeueMode: string? = if Context.ownsServer
			or Context.hosted
			or mode == "beginner"
		then mode
		else nil
	MatchEndService.cancelAndRequeue(requeueMode)
	if Context.ownsServer and not RunService:IsStudio() then
		local until_ = os.clock() + Config.MATCH_END.emptyWait
		while #Players:GetPlayers() > 0 and os.clock() < until_ do
			task.wait(5)
			MatchEndService.resendStranded()
		end
	end
end

local function waitForPlayers(): boolean
	if bothSidesFilled() and matchesPlayed > 0 and #Players:GetPlayers() > 0 then
		MatchState.set("Mode", matchMode())
		MatchState.set("RoundsToWin", roundsToWin())
		return true -- straight into the next match
	end
	setPhase("Waiting", 0)
	HealthLog.stage("waiting", nil, Context.id)
	local lonelySince: number? = nil
	local waitStart: number? = nil
	local lastCount = ""
	local lastGoal = 0
	while true do
		balanceTeams()
		local plan = MatchPlan.current()
		local goal = roundsToWin()
		if goal ~= lastGoal then
			lastGoal = goal
			MatchState.set("Mode", matchMode())
			MatchState.set("RoundsToWin", goal)
		end
		local hereCount = #Players:GetPlayers()
		if hereCount > 0 then
			waitStart = waitStart or os.clock()
		else
			waitStart = nil
		end
		if plan and hereCount > 0 then
			local ready, expected, canStart = MatchPlan.readiness()
			MatchState.set("ReadyPlayers", ready)
			MatchState.set("ExpectedPlayers", expected)
			local count = string.format("%d/%d ready, %d here", ready, expected, hereCount)
			if count ~= lastCount then
				lastCount = count
				HealthLog.stage("waiting", nil, `{Context.id} {count}`)
			end
			if canStart then
				fillSlots()
				if bothSidesFilled() then
					HealthLog.stage("players in", nil, `{Context.id} {count}`)
					return true
				end
			end
		elseif bothSidesFilled() and hereCount > 0 then
			return true
		elseif RunService:IsStudio() and BotsConfig.STUDIO_SOLO_BOT and hereCount > 0 then
			-- Studio, one side only: after a moment for a second test client,
			-- one bot takes the other side.
			local since = lonelySince or os.clock()
			lonelySince = since
			if os.clock() - since >= BotsConfig.JOIN_GRACE_STUDIO then
				local empty = if #playersOn(1) == 0 then 1 else 2
				if sideCount(empty) == 0 then
					BotService.add(empty, 1)
				end
			end
		else
			lonelySince = nil
		end
		if not RunService:IsStudio() and waitStart then
			if plan and MatchPlan.allWaived() then
				cancelSlowLoad("all present clients timed out waiting for MatchReady")
				return false
			end
			if os.clock() - waitStart >= Config.LOAD_CANCEL_TIMEOUT then
				cancelSlowLoad(
					string.format(
						"exceeded %.0fs load wait (%s)",
						Config.LOAD_CANCEL_TIMEOUT,
						if plan then "plan" else "no plan"
					)
				)
				return false
			end
		end
		task.wait(0.2)
	end
end

-- The map for the next match (vault/02 Art/UI Match Overhaul.md): the
-- players vote among every installed map in Config.MAPS that fits the bigger
-- team (MapVoteService). One map that fits, or nobody here: no vote. In Studio
-- the Workspace attribute ForceMap wins. nil keeps the current map.
--
-- LockMap (Studio only, 2026-11-21): the easy test switch. Type a map into the Workspace attribute `LockMap`
-- (a map id like "Snowpeak4" or its vote name like "Snowpeak", any case) and every match plays that map with
-- no vote; clear it to vote again. Studio only, so a value left in the saved place can't pin live servers.
local lockWarned: string? = nil
local function lockedMap(): string?
	if not RunService:IsStudio() then
		return nil
	end
	local raw = workspace:GetAttribute("LockMap")
	if typeof(raw) ~= "string" then
		return nil
	end
	local want = string.lower((string.gsub(raw, "^%s*(.-)%s*$", "%1")))
	if want == "" then
		return nil
	end
	local found: string? = nil
	for _, entry in Config.MAPS do
		if string.lower(entry.id) == want or (entry.name and string.lower(entry.name) == want) then
			found = entry.id
			break
		end
	end
	if not found and MapService.has(raw) then
		found = raw -- an installed map outside the rotation (an old one, a work in progress)
	end
	if found and MapService.has(found) then
		return found
	end
	if lockWarned ~= raw then
		lockWarned = raw
		warn(
			string.format(
				"[MatchService] LockMap %q matches no installed map; voting as usual",
				raw
			)
		)
	end
	return nil
end

local function pickMap(): string?
	local locked = lockedMap()
	if locked then
		print(string.format("[MatchService] LockMap: %s (map vote skipped)", locked))
		return locked
	end
	local forced = StateValues.get(workspace, "ForceMap")
	if RunService:IsStudio() and typeof(forced) == "string" and MapService.has(forced) then
		return forced
	end
	if matchMode() == "beginner" and MapService.has(Config.MAP) then
		return Config.MAP
	end
	local size = math.max(sideCount(1), sideCount(2), 1)
	local fits: { string } = {}
	for _, entry in Config.MAPS do
		if size >= entry.minTeam and size <= entry.maxTeam and MapService.has(entry.id) then
			table.insert(fits, entry.id)
		end
	end
	if #fits == 0 then
		return nil
	elseif #fits == 1 or #Players:GetPlayers() == 0 then
		return fits[math.random(1, #fits)]
	end
	HealthLog.stage("vote open", nil, `{Context.id} {#fits} maps`)
	return MapVoteService.run(fits, size, MatchState.botSeats(), matchMode())
end

-- A match that stopped on an error never leaves its players frozen on the vote or the draft (before
-- 2026-11-22 the loop just returned, with the Phase still "Vote"): a pad duel sends them back to the lobby here,
-- a match server teleports them to the lobby (MatchEndService retries a failed teleport).
local function abandonMatch(reason: string)
	HealthLog.problem("match error", nil, `{Context.id}: {reason}`)
	if Context.padDuel and Context.finish then
		Context.finish(Players:GetPlayers())
	else
		MatchEndService.sendEveryoneHome()
	end
end

local function loop()
	local mapStart = os.clock()
	while not loadMap(Config.MAP) do
		if
			not RunService:IsStudio()
			and os.clock() - mapStart >= Config.MAP_LOAD_TIMEOUT
			and #Players:GetPlayers() > 0
		then
			cancelSlowLoad("initial map failed to load")
			return
		end
		task.wait(MAP_RETRY)
	end
	lastMap = Config.MAP
	while true do
		if not waitForPlayers() then
			return
		end
		matchKey = HttpService:GenerateGUID(false)
		reportStage(1, "Match server ready")
		local picked, nextMap = xpcall(pickMap, debug.traceback)
		if not picked then
			-- The vote broke: play the map that's loaded rather than hang on the vote screen.
			HealthLog.problem("map vote failed", nil, `{Context.id}: {nextMap}`)
			nextMap = nil
		else
			HealthLog.stage("vote done", nil, `{Context.id} {nextMap or lastMap or "?"}`)
		end
		-- Loaded once round 1's select is open (pendingMap), not here.
		pendingMap = if nextMap and nextMap ~= lastMap then nextMap else nil
		reportStage(2, "Map selected")
		matchesPlayed += 1
		local ok, result = xpcall(runMatch, debug.traceback)
		inMatch = false
		firstMatch = false
		onboardingMatch = false
		pendingMap = nil -- a match that stopped before round 1 keeps the map it has
		ZoneService.stop()
		BotService.setFighting(false)
		if #Players:GetPlayers() == 0 then
			BotService.clear()
			table.clear(standIns)
			table.clear(pendingTakeovers)
		end
		if not ok then
			warn("[MatchService] the match stopped on an error:", result)
			DraftService.reset()
			table.clear(pendingTakeovers)
			setAllLocked(true)
			MapService.setBarriers(true)
			abandonMatch(tostring(result))
			if Context.ownsServer and not RunService:IsStudio() then
				-- Wait for the teleports out, resending any that failed.
				local until_ = os.clock() + Config.MATCH_END.emptyWait
				while #Players:GetPlayers() > 0 and os.clock() < until_ do
					task.wait(5)
					MatchEndService.resendStranded()
				end
			end
			return
		end
		if result ~= true then
			-- Keep the results visible while any remaining clients return to the Lobby.
			if RunService:IsStudio() then
				return
			end
			local until_ = os.clock() + Config.MATCH_END.emptyWait
			local nextResend = os.clock() + 5
			while #Players:GetPlayers() > 0 and os.clock() < until_ do
				task.wait(1)
				if os.clock() >= nextResend then
					nextResend = os.clock() + 5
					MatchEndService.resendStranded() -- a teleport that failed tries again
				end
			end
			BotService.clear()
			table.clear(standIns)
			table.clear(pendingTakeovers)
			return
		end
	end
end

function MatchService.init()
	enabled = not TestMode.resolve()
	if enabled then
		-- The match decides when people spawn: one life per round.
		Players.CharacterAutoLoads = false
	end
end

function MatchService.start()
	if not enabled then
		return
	end
	setAllLocked(true)
	MatchPlan.start()
	Net.event("BodyReady").OnServerEvent:Connect(onBodyReady)
	-- the task Path's draft and power counts (StatsService)
	DraftService.onPicked(StatsService.notePick)
	ModService.onUsed(StatsService.noteUse)
	-- Shared services hear every fighter in the server: only this match's count (MatchKit/Context).
	WeaponService.onHit(
		Context.filtered(
			2,
			function(attacker: Instance, victim: Model, dealt: number, killed: boolean)
				if killed then
					lastKiller[victim] = attacker
				end
				noteRedHit(attacker, victim, dealt)
				return nil
			end
		)
	)
	HealthService.onDowned(Context.filtered(1, function(humanoid: Humanoid)
		local body = humanoid.Parent
		local team = body and body:IsA("Model") and Teams.of(body)
		if body and body:IsA("Model") and team then
			lastDown[team] = { body = body, at = workspace:GetServerTimeNow() }
			if inMatch then
				local phase = MatchState.phase()
				if phase == "Live" or phase == "SuddenDeath" then
					local alive1 = teamState(1)
					local alive2 = teamState(2)
					if alive1 == 1 and alive2 >= 2 then
						local prev = clutchState[1]
						local hero = soleSurvivor(1) or (if prev then prev.actor else "SOLO")
						clutchState[1] = {
							vs = math.max(if prev then prev.vs else 0, alive2),
							actor = hero,
						}
					end
					if alive2 == 1 and alive1 >= 2 then
						local prev = clutchState[2]
						local hero = soleSurvivor(2) or (if prev then prev.actor else "SOLO")
						clutchState[2] = {
							vs = math.max(if prev then prev.vs else 0, alive1),
							actor = hero,
						}
					end
				end
			end
		end
	end))
	local function joined(player: Player)
		-- Fighting needs a spawn; until then, no shots.
		setLocked(player, true)
		task.defer(onJoin, player) -- after MatchPlan and ModService have seen them
	end
	Players.PlayerAdded:Connect(joined)
	-- A pad duel's players are here before it starts (MatchKit/Context).
	if not Context.ownsServer then
		for _, player in Players:GetPlayers() do
			joined(player)
		end
	end
	Players.PlayerRemoving:Connect(onLeave)
	task.spawn(loop)
end

return MatchService
