--!strict
-- The map vote before round 1 (vault/02 Art/UI Match Overhaul.md; the
-- structure follows RIVALS' duels, our own code). MatchService calls
-- MapVoteService.run(pool) between matches; it returns the map to load.
--
--   * The options are the pool (maps that fit the team size), with Random
--     first when there's more than one map.
--   * A player votes with the MapVote remote (an option name). The vote is a
--     server-set Player attribute "MapVote", so every client can draw who
--     voted for what. Bot seats cast one vote for a random eligible map.
--   * Every vote is a ticket and one ticket is drawn; no votes, or the Random
--     ticket, gives any map in the pool. Once every player has voted the clock
--     cuts to Config/Match VOTE.allInSeconds.
--   * State for the screens (MatchState): Phase "Vote" with EndsAt,
--     "VoteOptions" (option names, comma-separated), "VoteTeamSize" (players
--     per side, for the screen's match line), "VoteChosen" ("" while voting,
--     then the picked map for VOTE.chosenSeconds).

local Context = require(script.Parent.Parent.Context) -- this match (MatchKit/Context)
local Players = Context.players
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateValues = require(ReplicatedStorage.Shared.StateValues)

local Config = require(ReplicatedStorage.Shared.Config.Match)
local MatchState = require(script.Parent.Parent.MatchState)
local Net = Context.net
local RateLimit = require(ReplicatedStorage.Shared.Util.RateLimit)
local Telemetry = require(game:GetService("ServerScriptService").LobbyServer.Telemetry)

local MapVoteService = {}

local VOTE = Config.VOTE
local ATTRIBUTE = "MapVote"
local POLL = 0.1

local function mapLabel(id: string): string
	if id == VOTE.random then
		return VOTE.random
	end
	for _, entry in Config.MAPS do
		if entry.id == id then
			return entry.name or entry.id
		end
	end
	return id
end

local limiter = RateLimit.new(Config.RATE)
local open = false
local options: { string } = {}
local random = Random.new()

local function setClock(seconds: number)
	MatchState.set("EndsAt", workspace:GetServerTimeNow() + seconds)
end

local function clearVotes()
	for _, player in Players:GetPlayers() do
		StateValues.set(player, ATTRIBUTE, nil)
	end
end

local function allVoted(botSeats: { Configuration }): boolean
	local players = Players:GetPlayers()
	if #players == 0 then
		return false
	end
	for _, player in players do
		if StateValues.get(player, ATTRIBUTE) == nil then
			return false
		end
	end
	for _, seat in botSeats do
		if seat.Parent and StateValues.get(seat, ATTRIBUTE) == nil then
			return false
		end
	end
	return true
end

local function draw(pool: { string }, botSeats: { Configuration }): string
	local tickets: { string } = {}
	for _, player in Players:GetPlayers() do
		local vote = StateValues.get(player, ATTRIBUTE)
		if typeof(vote) == "string" and table.find(options, vote) then
			table.insert(tickets, vote)
		end
	end
	for _, seat in botSeats do
		local vote = StateValues.get(seat, ATTRIBUTE)
		if seat.Parent and typeof(vote) == "string" and table.find(pool, vote) then
			table.insert(tickets, vote)
		end
	end
	local ticket = if #tickets > 0 then tickets[random:NextInteger(1, #tickets)] else VOTE.random
	if ticket == VOTE.random or not table.find(pool, ticket) then
		return pool[random:NextInteger(1, #pool)]
	end
	return ticket
end

local function onVote(player: Player, name: unknown)
	if not limiter:allow(player, "MapVote") then
		return
	end
	if not open or typeof(name) ~= "string" or #name > 40 or not table.find(options, name) then
		return
	end
	StateValues.set(player, ATTRIBUTE, name)
end

-- Runs the vote over `pool` (map ids, at least one) for teams of `teamSize`
-- and returns the pick. Yields for the vote and the chosen-map beat.
function MapVoteService.run(
	pool: { string },
	teamSize: number,
	botSeats: { Configuration },
	mode: string?
): string
	assert(#pool > 0, "MapVoteService.run: empty pool")
	options = table.clone(pool)
	if #pool > 1 then
		table.insert(options, 1, VOTE.random)
	end
	clearVotes()
	local started = os.clock()
	local botTimes: { [Configuration]: number } = {}
	for _, seat in botSeats do
		StateValues.set(seat, ATTRIBUTE, nil)
		botTimes[seat] = started + random:NextNumber(VOTE.botDelay[1], VOTE.botDelay[2])
	end
	MatchState.setList("VoteOptions", options)
	MatchState.set("VoteChosen", "")
	MatchState.set("VoteTeamSize", teamSize)
	setClock(VOTE.seconds)
	MatchState.set("Phase", "Vote")
	open = true

	local deadline = started + VOTE.seconds
	local minClose = started + (if #botSeats > 0 then VOTE.withBotsMinSeconds else 0)
	local shortened = false
	while os.clock() < deadline do
		local now = os.clock()
		for seat, at in botTimes do
			if now >= at then
				botTimes[seat] = nil
				if seat.Parent then
					StateValues.set(seat, ATTRIBUTE, pool[random:NextInteger(1, #pool)])
				end
			end
		end
		if not shortened and allVoted(botSeats) then
			shortened = true
			local closeAt = math.max(now + VOTE.allInSeconds, minClose)
			if deadline > closeAt then
				deadline = closeAt
				setClock(closeAt - now)
			end
		end
		task.wait(POLL)
	end
	open = false
	local modeName = mode or `{teamSize}v{teamSize}`
	for _, player in Players:GetPlayers() do
		local vote = StateValues.get(player, ATTRIBUTE)
		if typeof(vote) == "string" and table.find(options, vote) then
			Telemetry.mapVoted(player, mapLabel(vote), modeName)
		end
	end

	local chosen = draw(pool, botSeats)
	setClock(VOTE.chosenSeconds)
	MatchState.set("VoteChosen", chosen)
	task.wait(VOTE.chosenSeconds)
	return chosen
end

function MapVoteService.start()
	Net.event("MapVote").OnServerEvent:Connect(onVote)
	Players.PlayerRemoving:Connect(function(player)
		limiter:forget(player)
	end)
end

return MapVoteService
