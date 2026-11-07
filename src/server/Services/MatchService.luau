--!strict
-- The match (vault/01 Design/Match Flow.md, vault/05 Production/Match
-- Structure Revamp.md): rounds of select (draft, ending in a 3-2-1) → fight
-- → sudden death → round end, first to 5. Runs on every server
-- that isn't in test mode. One loop in one thread, wrapped in a pcall so an
-- error can't leave the game stuck. Clients read the state from MatchState
-- attributes; they can't change anything here (picks go through DraftService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BotsConfig = require(ReplicatedStorage.Shared.Config.Bots)
local Combat = require(ReplicatedStorage.Shared.Config.Combat)
local Config = require(ReplicatedStorage.Shared.Config.Match)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local ModsConfig = require(ReplicatedStorage.Shared.Config.Mods)
local Teams = require(ReplicatedStorage.Shared.Mods.Teams)
local TestMode = require(ReplicatedStorage.Shared.TestMode)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

local DraftService = require(script.Parent.DraftService)
local MapService = require(script.Parent.MapService)
local ModService = require(script.Parent.ModService)
local BotService = require(script.Parent.BotService)
local CharacterService = require(script.Parent.CharacterService)
local MatchPlan = require(script.Parent.Parent.Bots.MatchPlan)
local WeaponService = require(script.Parent.WeaponService)
local ZoneService = require(script.Parent.ZoneService)
local Health = require(ReplicatedStorage.Shared.Health)

local MatchService = {}

local POLL = 0.1 -- seconds between checks on a running clock
local RETRY_AFTER_ERROR = 3
local MAP_RETRY = 5
local SPAWN_TRIES = 2
local LATE_SPAWN_WAIT = 3 -- seconds a slow spawn gets past the countdown
local MAX_EMPTY_ROUNDS = 3 -- rounds in a row with a side nobody could spawn on: the match ends

local enabled = false
local matchesPlayed = 0

-- Seats (Match Structure Revamp → A2). A listed player who isn't here yet
-- has a bot stand-in that plays their seat until they arrive; a late player
-- takes it over at once during a select, else at the next round.
local standIns: { [number]: any } = {} -- userId → bot key
local pendingTakeovers: { [Player]: any } = {} -- player → the bot they replace
local inMatch = false
-- Sides that have had a real player this match: if one of them has none
-- left, the other side wins (a 1v1 leaver, or a whole team gone).
local humanSides = { false, false }

local function setLocked(player: Player, locked: boolean)
	player:SetAttribute(MatchState.COMBAT_LOCKED, locked)
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
				player:SetAttribute(Teams.ATTRIBUTE, team)
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
		bigger[#bigger]:SetAttribute(Teams.ATTRIBUTE, target)
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

local function spawnPlayer(player: Player, spawn: SpawnLocation?)
	player.RespawnLocation = spawn
	for attempt = 1, SPAWN_TRIES do
		-- Spawned already wearing the standard match body (Match Avatar.md).
		local ok, err = pcall(CharacterService.loadCharacter, player)
		if ok or player.Parent ~= Players then
			return
		end
		warn("[MatchService] couldn't spawn", player.Name, "try", attempt, err)
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
local function spawnCentre(team: number): Vector3?
	local spawns = MapService.spawns(team)
	if #spawns == 0 then
		return nil
	end
	local sum = Vector3.zero
	for _, s in spawns do
		sum += s.Position
	end
	return sum / #spawns
end

-- Everyone back at their end with full health. Bots take the spawns after
-- their team's players, and head for the other end when they know nothing.
local function spawnEveryone()
	spawnPlayers(function()
		return true
	end)
	BotService.setRoamPoints(spawnCentre(2), spawnCentre(1))
	for team = 1, 2 do
		BotService.spawnTeam(team, MapService.spawns(team), #playersOn(team) + 1)
	end
end

-- Anyone on a team with no live character: a failed or slow spawn, or someone
-- who joined after the round's spawn.
local function spawnMissing()
	spawnPlayers(function(player: Player): boolean
		return not isAlive(player)
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
			local shield = humanoid:GetAttribute(Combat.SHIELD_ATTRIBUTE)
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
			BotService.applyDraft(key, matchLoadout(seat), seat.kit, seat.levels)
		elseif typeof(key) == "Instance" and key:IsA("Player") and key.Parent == Players then
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
			humanoid:SetAttribute(Combat.SHIELD_ATTRIBUTE, DraftService.seat(key).shield)
		end
	end
end

-- A side that has had real players this match and has none left: the other
-- side wins. 0 when both are gone, nil while the match goes on.
local function forfeitWinner(): number?
	if not inMatch then
		return nil
	end
	local goneOne = humanSides[1] and #playersOn(1) == 0
	local goneTwo = humanSides[2] and #playersOn(2) == 0
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

local function noteHumans()
	for team = 1, 2 do
		if #playersOn(team) > 0 then
			humanSides[team] = true
		end
	end
end

-- The select screen: SELECT time in all, the last COUNTDOWN of it the 3-2-1.
-- The top-bar clock counts to the fight. Round 1 runs its full time (people
-- are still arriving); later rounds skip to the 3-2-1 once all have locked in.
local function runDraft(round: number)
	local total = if round == 1 then Config.FIRST_SELECT_TIME else Config.SELECT_TIME
	local picking = math.max(total - Config.COUNTDOWN_TIME, 1)
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
	runClock(picking, function()
		return forfeited() or (round > 1 and DraftService.allLocked(seatKeys()))
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
		player:SetAttribute(Teams.ATTRIBUTE, team)
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
local function fillSlots()
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
		if player.Parent == Players and BotService.isBot(bot) then
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

local function onJoin(player: Player)
	if player.Parent ~= Players then
		return
	end
	local bot = standIns[player.UserId]
	local phase = MatchState.phase()
	local selecting = inMatch and (phase == "Draft" or phase == "Countdown")
	if bot and BotService.isBot(bot) then
		-- Their side from the start, even while the bot still plays the seat.
		local team = MatchPlan.teamFor(player) or BotService.teamOf(bot)
		if team then
			player:SetAttribute(Teams.ATTRIBUTE, team)
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
		player:SetAttribute(Teams.ATTRIBUTE, listedTeam)
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
	local wasPending = pendingTakeovers[player] ~= nil
	pendingTakeovers[player] = nil
	local team = Teams.of(player)
	local plan = MatchPlan.current()
	local size = if plan then plan.size elseif team then sideCount(team) else 1
	local kept = standIns[player.UserId]
	local standInPlays = kept ~= nil and BotService.isBot(kept)
	-- Nothing to replace: no match, a 1v1 (forfeit), their stand-in still has
	-- the seat (they never took it over), or the side is already full.
	if
		not inMatch
		or not team
		or size <= 1
		or wasPending
		or standInPlays
		or sideCount(team) - 1 >= size
	then
		DraftService.forget(player)
		return
	end
	local bot = BotService.add(team, 1)[1]
	standIns[player.UserId] = bot -- if they come back, they take the seat back
	DraftService.transfer(player, bot)
	local seat = DraftService.seat(bot)
	BotService.applyDraft(bot, matchLoadout(seat), seat.kit, seat.levels)
	if DraftService.isOpen() then
		BotService.draft(bot, seat :: any)
	end
	local phase = MatchState.phase()
	local spawns = MapService.spawns(team)
	if (phase == "Draft" or phase == "Countdown") and #spawns > 0 then
		local spot = spawns[(sideCount(team) - 2) % #spawns + 1] -- the leaver still counts here
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

local function runMatch()
	balanceTeams()
	inMatch = true
	humanSides = { false, false }
	noteHumans()
	setAllLocked(true)
	MatchState.set("Round", 0)
	MatchState.set("Score1", 0)
	MatchState.set("Score2", 0)
	MatchState.set("RoundWinner", nil)
	MatchState.set("MatchWinner", nil)
	MapService.setBarriers(true)
	resetKits()

	local scores = { 0, 0 }
	local round = 0
	local emptyRounds = 0
	local forfeitBy: number? = nil
	local function over(): boolean
		return someoneOut() or forfeited()
	end
	while scores[1] < Config.ROUNDS_TO_WIN and scores[2] < Config.ROUNDS_TO_WIN do
		round += 1
		MatchState.set("Round", round)
		MatchState.set("RoundWinner", nil)
		setAllLocked(true)
		MapService.setBarriers(true)
		applyTakeovers()
		spawnEveryone()
		runDraft(round)

		spawnMissing()
		if not forfeited() then
			setPhase("Countdown", Config.COUNTDOWN_TIME)
			runClock(Config.COUNTDOWN_TIME, forfeited)
		end
		if someoneOut() and not forfeited() then
			runClock(LATE_SPAWN_WAIT, function()
				return not someoneOut() or forfeited()
			end)
		end

		-- A side with nobody alive at the start isn't a fight: no point, go again.
		-- Rounds in a row like that (a side that can't spawn) end the match.
		local winner = 0
		if someoneOut() and not forfeited() then
			emptyRounds += 1
			if emptyRounds >= MAX_EMPTY_ROUNDS then
				local one, two = teamState(1), teamState(2)
				forfeitBy = if one > 0 and two == 0 then 1 elseif two > 0 and one == 0 then 2 else 0
				warn(
					"[MatchService] a side couldn't spawn for",
					emptyRounds,
					"rounds: the match ends"
				)
				break
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
			setPhase("Live", Config.ROUND_TIME)
			runClock(Config.ROUND_TIME, over)
			-- Sudden death: the circle closes until a side is out.
			if not over() and ZoneService.begin() then
				setPhase("SuddenDeath", Config.SUDDEN_DEATH.shrinkTime)
				runClock(Config.SUDDEN_DEATH.maxTime, over)
			end
			ZoneService.stop()

			BotService.setFighting(false)
			setAllLocked(true)
			winner = roundWinner()
		end
		for _, player in Players:GetPlayers() do
			ModService.clearRound(player)
		end
		forfeitBy = forfeitWinner()
		if forfeitBy then
			break
		end
		if winner ~= 0 then
			scores[winner] += 1
		end
		MatchState.set("Score1", scores[1])
		MatchState.set("Score2", scores[2])
		MatchState.set("RoundWinner", winner)
		setPhase("RoundEnd", Config.ROUND_END_TIME)
		runClock(Config.ROUND_END_TIME, forfeited)

		if #Players:GetPlayers() == 0 then
			return -- only bots are left
		end
		forfeitBy = forfeitWinner()
		if forfeitBy then
			break
		end
		if not bothSidesFilled() then
			-- Nobody at all on one side (no bots either): whoever stayed wins.
			forfeitBy = sideLeftStanding()
			if not forfeitBy then
				return -- nobody is left at all
			end
			break
		end
	end

	if forfeitBy == 0 then
		return -- everyone left
	end
	setAllLocked(true)
	MatchState.set("MatchWinner", forfeitBy or (if scores[1] > scores[2] then 1 else 2))
	setPhase("MatchEnd", Config.MATCH_END_TIME)
	task.wait(Config.MATCH_END_TIME)
end

local function waitForPlayers()
	if bothSidesFilled() and matchesPlayed > 0 then
		return -- straight into the next match
	end
	setPhase("Waiting", 0)
	local lonelySince: number? = nil
	while true do
		balanceTeams()
		local plan = MatchPlan.current()
		if plan and #Players:GetPlayers() > 0 then
			-- A Lobby (or Studio BotMatch) match starts with the first player:
			-- bots keep everyone else's seat, and the round 1 select is the wait.
			fillSlots()
			if bothSidesFilled() then
				return
			end
		elseif bothSidesFilled() and #Players:GetPlayers() > 0 then
			return
		elseif
			RunService:IsStudio()
			and BotsConfig.STUDIO_SOLO_BOT
			and #Players:GetPlayers() > 0
		then
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
		task.wait(0.5)
	end
end

-- The map for the next match: a random installed map from Config.MAPS that fits
-- the bigger team, not the last one when there's another (Studio: the
-- Workspace attribute ForceMap wins). nil keeps the current map.
local lastMap: string? = nil
local function pickMap(): string?
	local forced = workspace:GetAttribute("ForceMap")
	if RunService:IsStudio() and typeof(forced) == "string" and MapService.has(forced) then
		return forced
	end
	local size = math.max(sideCount(1), sideCount(2), 1)
	local fits: { string } = {}
	for _, entry in Config.MAPS do
		if size >= entry.minTeam and size <= entry.maxTeam and MapService.has(entry.id) then
			table.insert(fits, entry.id)
		end
	end
	if #fits > 1 and lastMap then
		local i = table.find(fits, lastMap)
		if i then
			table.remove(fits, i)
		end
	end
	if #fits == 0 then
		return nil
	end
	return fits[math.random(1, #fits)]
end

local function loop()
	while not MapService.load(Config.MAP) do
		task.wait(MAP_RETRY)
	end
	lastMap = Config.MAP
	while true do
		waitForPlayers()
		local nextMap = pickMap()
		if nextMap and nextMap ~= lastMap and MapService.load(nextMap) then
			lastMap = nextMap
		end
		matchesPlayed += 1
		local ok, err = pcall(runMatch)
		inMatch = false
		ZoneService.stop()
		BotService.setFighting(false)
		if #Players:GetPlayers() == 0 then
			BotService.clear()
			table.clear(standIns)
			table.clear(pendingTakeovers)
		end
		if not ok then
			warn("[MatchService] the match stopped on an error:", err)
			-- Back behind the barrier, whatever phase it stopped in.
			DraftService.reset()
			table.clear(pendingTakeovers)
			setPhase("Waiting", 0)
			setAllLocked(true)
			MapService.setBarriers(true)
			task.wait(RETRY_AFTER_ERROR)
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
	Players.PlayerAdded:Connect(function(player)
		-- Fighting needs a spawn; until then, no shots.
		setLocked(player, true)
		task.defer(onJoin, player) -- after MatchPlan and ModService have seen them
	end)
	Players.PlayerRemoving:Connect(onLeave)
	task.spawn(loop)
end

return MatchService
