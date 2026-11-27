--!strict
-- The end of a match (vault/05 Production/Match Structure Revamp.md, phase
-- D): the server publishes a results snapshot, then a MatchEnd phase where
-- each player picks (`MatchChoice`):
--   Rematch   a vote; once every real player from the match still here has
--             voted, a new match starts on this server
--   PlayAgain back to the Lobby, straight into the same mode's queue
--   Leave     back to the Lobby
-- At the end of the clock everyone left goes to the Lobby. Teleports run
-- from the server with retries (LihFolk "Teleporting and Multi-Place Games",
-- like the Lobby's Matchmaking/Launcher): only Flooded / Failure results are
-- retried, and a player whose teleport keeps failing stays on the list, so
-- MatchService resends them while it waits for the server to empty.

local Context = require(script.Parent.Parent.Context) -- this match (MatchKit/Context)
local Players = Context.players
-- The real service, for "is this player still in the server" (Players above is this match's stand-in, MatchKit/Context).
local PlayersService = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Config = require(ReplicatedStorage.Shared.Config.Match)
local MatchState = require(script.Parent.Parent.MatchState)
local Net = Context.net
local RateLimit = require(ReplicatedStorage.Shared.Util.RateLimit)

local StatsService = require(script.Parent.StatsService)
local Telemetry = require(game:GetService("ServerScriptService").LobbyServer.Telemetry)

local MatchEndService = {}

local E = Config.MATCH_END
local IS_STUDIO = RunService:IsStudio()
local CHOICES = { Rematch = true, PlayAgain = true, Leave = true }
local rng = Random.new()

-- What the Lobby reads (Lobby QueueService.requeueFromMatch).
export type LobbyReturn = { v: number, from: string, requeue: string?, cancelled: boolean? }

local limiter = RateLimit.new(Config.RATE)
local open = false
local mode: string? = nil
local choices: { [Player]: string } = {}
local voters: { [Player]: boolean } = {} -- the real players when the match ended
local present: { [Player]: boolean } = {} -- them and anyone who joined during the screen
local outbound: { [Player]: LobbyReturn } = {} -- on their way to the Lobby (until they leave)
local attempts: { [Player]: number } = {}
local sentAt: { [Player]: number } = {} -- os.clock() of each player's last teleport try
local IN_FLIGHT = 20 -- seconds a teleport may take before a resend
local rematchBroken = false
local botSeats = 0
local botVoteAt: { number } = {}
local botVotesShownAt = 0

local function lobbyReturn(choice: string): LobbyReturn
	return { v = 1, from = "match", requeue = if choice == "PlayAgain" then mode else nil }
end

local function optionsFor(data: LobbyReturn): TeleportOptions
	local options = Instance.new("TeleportOptions")
	options:SetTeleportData(data)
	return options
end

-- One try for `players` (a throw retries each on their own, with backoff).
local function teleport(players: { Player }, data: LobbyReturn)
	-- A pad duel or a hosted queued match (MatchKit/Context): back to the lobby here, no teleport; Play Again
	-- queues them again from here.
	if Context.padDuel then
		for _, p in players do
			if p.Parent == PlayersService and Context.sendHome then
				Context.sendHome(p)
				local requeue = Context.requeue
				if data.requeue and requeue then
					task.spawn(requeue, p, data.requeue)
				end
			end
		end
		return
	end
	local list: { Player } = {}
	for _, p in players do
		if p.Parent == PlayersService then
			outbound[p] = data
			attempts[p] = (attempts[p] or 0) + 1
			sentAt[p] = os.clock()
			table.insert(list, p)
		end
	end
	if #list == 0 then
		return
	end
	if IS_STUDIO then
		for _, p in list do
			print(
				`[MatchEnd] STUDIO: would teleport {p.Name} to the Lobby ({data.requeue or "no"} requeue)`
			)
		end
		return
	end
	local ok, err = pcall(
		TeleportService.TeleportAsync,
		TeleportService,
		game.PlaceId, -- the lobby: this same place (one place since 2026-11-21)
		list,
		optionsFor(data)
	)
	if not ok then
		if string.find(tostring(err), "already in progress", 1, true) then
			return -- the earlier teleport is still on its way: nothing to retry
		end
		warn(`[MatchEnd] teleport for {#list} player(s) threw: {err}`)
		for _, p in list do
			local tries = attempts[p] or 1
			if tries < E.teleportAttempts then
				task.delay(E.retryBackoff[tries] or 4, function()
					if outbound[p] and p.Parent == PlayersService then
						teleport({ p }, outbound[p])
					end
				end)
			end
		end
	end
end

local function countVotes(): (number, number)
	local votes, needed = 0, 0
	for player in voters do
		if player.Parent == PlayersService then
			needed += 1
			if choices[player] == "Rematch" then
				votes += 1
			end
		end
	end
	return votes, needed
end

local function publish()
	local votes, needed = countVotes()
	local now = os.clock()
	for _, at in botVoteAt do
		if now >= at then
			votes += 1
		end
	end
	MatchState.set("RematchVotes", votes)
	MatchState.set("RematchNeeded", needed + botSeats)
	MatchState.set("RematchOpen", open and not rematchBroken and needed > 0)
end

local function onChoice(player: Player, choice: unknown)
	if not limiter:allow(player, "MatchChoice") then
		return
	end
	if typeof(choice) ~= "string" or not CHOICES[choice] then
		return
	end
	-- After the screen: someone whose teleport failed can still ask again.
	if not open then
		local data = outbound[player]
		if data and (choice == "Leave" or choice == "PlayAgain") then
			attempts[player] = 0
			teleport({ player }, data)
		end
		return
	end
	if not present[player] then
		return
	end
	local current = choices[player]
	if current == "PlayAgain" or current == "Leave" or current == choice then
		return -- already on the way out, or already picked this choice
	end
	if choice == "Rematch" and (rematchBroken or not voters[player]) then
		return
	end
	choices[player] = choice
	Telemetry.event(player, "MatchEndChoice", 1, choice)
	if choice ~= "Rematch" then
		if voters[player] then
			rematchBroken = true -- they won't be in it
		end
		teleport({ player }, lobbyReturn(choice))
	end
	publish()
end

-- Runs the MatchEnd phase. Returns true for a rematch on this server. `gift`: a new player's first match (the
-- results screen shows NEXT MATCH / LOBBY, no rematch: Util/MatchEndScreen). The name is from the old free case.
function MatchEndService.run(winner: number, matchMode: string?, gift: boolean?): boolean
	table.clear(choices)
	table.clear(voters)
	table.clear(present)
	table.clear(outbound)
	table.clear(attempts)
	table.clear(sentAt)
	rematchBroken = Context.noRematch == true
	mode = matchMode
	for _, player in Players:GetPlayers() do
		voters[player] = true
		present[player] = true
	end
	botSeats = #MatchState.botSeats()
	table.clear(botVoteAt)
	local now = os.clock()
	botVotesShownAt = now
	if not rematchBroken then
		for _ = 1, botSeats do
			if rng:NextNumber() < E.botRematchChance then
				local at = now + rng:NextNumber(E.botRematchDelay[1], E.botRematchDelay[2])
				table.insert(botVoteAt, at)
				botVotesShownAt = math.max(botVotesShownAt, at + 0.4)
			end
		end
	end
	MatchState.set("Results", {
		winner = winner,
		lines = StatsService.summary(),
		score1 = MatchState.get("Score1") or 0,
		score2 = MatchState.get("Score2") or 0,
		rounds = MatchState.getList("RoundHistory"),
		gift = gift == true,
	})
	-- No rematch (a new player's in-server onboarding matches): a shorter screen, straight back to the lobby.
	local screenTime = if rematchBroken then E.timeNoRematch else E.time
	MatchState.set("EndsAt", workspace:GetServerTimeNow() + screenTime)
	open = true
	publish()
	MatchState.set("Phase", "MatchEnd")

	local rematch = false
	local ok, err = pcall(function()
		local deadline = os.clock() + screenTime
		while os.clock() < deadline do
			-- Someone from the match left: no rematch with the same players.
			for player in voters do
				if player.Parent ~= PlayersService then
					rematchBroken = true
				end
			end
			local votes, needed = countVotes()
			if
				not rematchBroken
				and needed > 0
				and votes == needed
				and os.clock() >= botVotesShownAt
			then
				rematch = true
				return
			end
			if needed == 0 and next(present) == nil then
				return -- everyone's gone
			end
			publish()
			task.wait(0.1)
		end
	end)
	if not ok then
		warn("[MatchEnd] the match-end screen stopped on an error:", err)
	end
	open = false
	MatchState.set("RematchOpen", false)
	if rematch then
		return true
	end
	-- Time's up: everyone who hasn't picked goes back to the Lobby, together.
	local rest: { Player } = {}
	for player in present do
		if
			player.Parent == PlayersService
			and choices[player] ~= "PlayAgain"
			and choices[player] ~= "Leave"
		then
			if not choices[player] then
				Telemetry.event(player, "MatchEndChoice", 1, "Timeout")
			end
			table.insert(rest, player)
		end
	end
	teleport(rest, lobbyReturn("Leave"))
	if Context.padDuel and Context.finish then
		Context.finish(rest)
	end
	return false
end

-- Sends every player still here back to the lobby (MatchService, when a match stops on an error).
function MatchEndService.sendEveryoneHome()
	teleport(Players:GetPlayers(), lobbyReturn("Leave"))
end

-- Cancels a match that took too long to load, returning everyone to Lobby & requeueing them.
function MatchEndService.cancelAndRequeue(matchMode: string?)
	mode = matchMode
	local players = Players:GetPlayers()
	local data: LobbyReturn = { v = 1, from = "match", requeue = matchMode, cancelled = true }
	teleport(players, data)
	if Context.padDuel and Context.finish then
		Context.finish(players)
	end
end

-- Resends everyone still waiting on a failed teleport (MatchService calls it
-- while it waits for the server to empty).
function MatchEndService.resendStranded()
	for player, data in outbound do
		-- a teleport sent in the last IN_FLIGHT seconds may still be going through: leave it
		if player.Parent == PlayersService and os.clock() - (sentAt[player] or 0) >= IN_FLIGHT then
			attempts[player] = 0
			teleport({ player }, data)
		end
	end
end

function MatchEndService.init()
	Net.event("MatchChoice").OnServerEvent:Connect(onChoice) -- always connected: `open` gates it
	TeleportService.TeleportInitFailed:Connect(
		function(
			player: Player,
			result: Enum.TeleportResult,
			message: string,
			_placeId: number,
			options: TeleportOptions?
		)
			local data = outbound[player]
			if not data or player.Parent ~= PlayersService then
				return
			end
			warn(`[MatchEnd] teleport failed for {player.Name} ({result.Name}): {message}`)
			if result ~= Enum.TeleportResult.Flooded and result ~= Enum.TeleportResult.Failure then
				return -- IsTeleporting, Unauthorized...: retrying won't help
			end
			local tries = attempts[player] or 1
			if tries >= E.teleportAttempts then
				return -- stays on the list; resendStranded tries again later
			end
			task.delay(if result == Enum.TeleportResult.Flooded then 10 else 2, function()
				if outbound[player] and player.Parent == PlayersService then
					attempts[player] = (attempts[player] or 0) + 1
					local ok, err = pcall(
						TeleportService.TeleportAsync,
						TeleportService,
						game.PlaceId, -- the lobby: this same place (one place since 2026-11-21)
						{ player },
						options or optionsFor(data)
					)
					if not ok then
						warn(`[MatchEnd] teleport retry for {player.Name} threw: {err}`)
					end
				end
			end)
		end
	)
end

function MatchEndService.start()
	Players.PlayerAdded:Connect(function(player)
		if open then
			present[player] = true -- joined during the screen: sent to the Lobby at the end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		limiter:forget(player)
		choices[player] = nil
		attempts[player] = nil
		outbound[player] = nil
		sentAt[player] = nil
		present[player] = nil
	end)
end

return MatchEndService
