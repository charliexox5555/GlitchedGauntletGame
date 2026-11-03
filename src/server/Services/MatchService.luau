--!strict
-- The match (vault/01 Design/Match Flow.md): map, get ready, then rounds of
-- draft → countdown → fight → round end, first to 5. Runs on every server
-- that isn't in test mode. One loop in one thread, wrapped in a pcall so an
-- error can't leave the game stuck. Clients read the state from MatchState
-- attributes; they can't change anything here (picks go through DraftService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

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
local TestOpponent = require(script.Parent.TestOpponent)
local WeaponService = require(script.Parent.WeaponService)

local MatchService = {}

local POLL = 0.1 -- seconds between checks on a running clock
local RETRY_AFTER_ERROR = 3
local MAP_RETRY = 5
local SPAWN_TRIES = 2
local LATE_SPAWN_WAIT = 3 -- seconds a slow spawn gets past the countdown

local enabled = false
local matchesPlayed = 0
local activeOpponent: number? = nil -- the team the test opponent is playing for

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

-- The team the test opponent fills, if it's needed and allowed.
local function opponentTeam(): number?
	if not TestOpponent.isAllowed() then
		return nil
	end
	local one, two = #playersOn(1), #playersOn(2)
	if one > 0 and two == 0 then
		return 2
	elseif two > 0 and one == 0 then
		return 1
	end
	return nil
end

local function bothSidesFilled(): boolean
	local one, two = #playersOn(1), #playersOn(2)
	return (one > 0 and two > 0) or (opponentTeam() ~= nil)
end

-- Teams come from join order, so people leaving can tip them. Moves players
-- over until the sides differ by at most one.
local function balanceTeams()
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

-- Everyone with a seat in the draft: players, and the opponent when it plays.
local function seatKeys(): { any }
	local keys: { any } = {}
	for _, player in Players:GetPlayers() do
		table.insert(keys, player)
	end
	if activeOpponent then
		table.insert(keys, TestOpponent.KEY)
	end
	return keys
end

local function teamOfKey(key: any): number?
	if key == TestOpponent.KEY then
		return activeOpponent
	end
	return Teams.of(key)
end

-- Spawning ---------------------------------------------------------------------

local function isAlive(player: Player): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local function spawnPlayer(player: Player, spawn: SpawnLocation?)
	player.RespawnLocation = spawn
	for attempt = 1, SPAWN_TRIES do
		local ok, err = pcall(function()
			player:LoadCharacterAsync()
		end)
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

-- Everyone back at their end with full health.
local function spawnEveryone()
	spawnPlayers(function()
		return true
	end)
	TestOpponent.remove()
	activeOpponent = opponentTeam()
	if activeOpponent then
		local spot = MapService.spawns(activeOpponent)[1]
		if spot then
			TestOpponent.spawn(spot.CFrame, activeOpponent, MapService.toWorld)
		end
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
		if humanoid and humanoid.Health > 0 then
			alive += 1
			local shield = humanoid:GetAttribute(Combat.SHIELD_ATTRIBUTE)
			health += humanoid.Health + (if typeof(shield) == "number" then shield else 0)
		end
	end
	if activeOpponent == team and TestOpponent.isAlive() then
		alive += 1
		health += TestOpponent.health()
	end
	return alive, health
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
		if key ~= TestOpponent.KEY then
			local player = key :: Player
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
		local character = if key == TestOpponent.KEY
			then TestOpponent.model()
			else (key :: Player).Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid:SetAttribute(Combat.SHIELD_ATTRIBUTE, DraftService.seat(key).shield)
		end
	end
end

local function runDraft(round: number)
	local seconds = if round == 1 then Config.OPENING_DRAFT_TIME else Config.DRAFT_TIME
	local keys = seatKeys()
	local endsAt = workspace:GetServerTimeNow() + seconds
	DraftService.open(keys, round, endsAt, enemyKit)
	if table.find(keys, TestOpponent.KEY) then
		DraftService.autoPick(TestOpponent.KEY)
	end
	MatchState.set("WeaponPhase", DraftService.phaseFor(round).name)
	setPhase("Draft", seconds)
	runClock(seconds, function()
		return DraftService.allLocked(seatKeys())
	end)
	DraftService.close(seatKeys()) -- anyone who left in the meantime is out
	applyDraft(seatKeys())
	giveShields()
end

-- One match --------------------------------------------------------------------

-- A clean slate for everyone, for a new match.
local function resetKits()
	DraftService.reset()
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
	if #playersOn(1) > 0 then
		return 1
	elseif #playersOn(2) > 0 then
		return 2
	end
	return nil
end

local function runMatch()
	balanceTeams()
	setAllLocked(true)
	MatchState.set("Round", 0)
	MatchState.set("Score1", 0)
	MatchState.set("Score2", 0)
	MatchState.set("RoundWinner", nil)
	MatchState.set("MatchWinner", nil)
	MapService.setBarriers(true)
	resetKits()
	spawnEveryone()
	setPhase("Ready", Config.READY_TIME)
	task.wait(Config.READY_TIME)

	local scores = { 0, 0 }
	local round = 0
	local forfeitWinner: number? = nil
	while scores[1] < Config.ROUNDS_TO_WIN and scores[2] < Config.ROUNDS_TO_WIN do
		round += 1
		MatchState.set("Round", round)
		MatchState.set("RoundWinner", nil)
		setAllLocked(true)
		MapService.setBarriers(true)
		if round > 1 then
			spawnEveryone()
		end
		runDraft(round)

		spawnMissing()
		setPhase("Countdown", Config.COUNTDOWN_TIME)
		task.wait(Config.COUNTDOWN_TIME)
		if someoneOut() then
			runClock(LATE_SPAWN_WAIT, function()
				return not someoneOut()
			end)
		end

		-- A side with nobody alive at the start isn't a fight: no point, go again.
		local winner = 0
		if not someoneOut() then
			giveShields() -- anyone spawned late has one too
			-- Fight. Charges come back here, so nothing spent behind the barrier counts.
			for _, player in Players:GetPlayers() do
				ModService.refillCharges(player)
			end
			MapService.setBarriers(false)
			setAllLocked(false)
			TestOpponent.setFighting(true)
			setPhase("Live", Config.ROUND_TIME)
			runClock(Config.ROUND_TIME, someoneOut)

			TestOpponent.setFighting(false)
			setAllLocked(true)
			winner = roundWinner()
		end
		for _, player in Players:GetPlayers() do
			ModService.clearRound(player)
		end
		if winner ~= 0 then
			scores[winner] += 1
		end
		MatchState.set("Score1", scores[1])
		MatchState.set("Score2", scores[2])
		MatchState.set("RoundWinner", winner)
		setPhase("RoundEnd", Config.ROUND_END_TIME)
		task.wait(Config.ROUND_END_TIME)

		if not bothSidesFilled() then
			-- Everyone on one side left: whoever stayed wins the match.
			forfeitWinner = sideLeftStanding()
			if not forfeitWinner then
				return -- nobody is left at all
			end
			break
		end
	end

	MatchState.set("MatchWinner", forfeitWinner or (if scores[1] > scores[2] then 1 else 2))
	setPhase("MatchEnd", Config.MATCH_END_TIME)
	task.wait(Config.MATCH_END_TIME)
end

local function waitForPlayers()
	if bothSidesFilled() and matchesPlayed > 0 then
		return -- straight into the next match
	end
	setPhase("Waiting", 0)
	while not bothSidesFilled() do
		balanceTeams()
		task.wait(0.5)
	end
	-- In Studio, a moment for a second test client before the opponent steps in.
	if opponentTeam() then
		task.wait(Config.TEST_OPPONENT.joinGrace)
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
	local size = math.max(#playersOn(1), #playersOn(2), 1)
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
		TestOpponent.remove()
		activeOpponent = nil
		if not ok then
			warn("[MatchService] the match stopped on an error:", err)
			-- Back behind the barrier, whatever phase it stopped in.
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
	Players.PlayerAdded:Connect(function(player)
		-- Fighting needs a spawn at the next round; until then, no shots.
		setLocked(player, true)
	end)
	Players.PlayerRemoving:Connect(function(player)
		DraftService.forget(player)
	end)
	task.spawn(loop)
end

return MatchService
