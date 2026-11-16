--!strict
-- The map vote before round 1 (vault/02 Art/UI Match Overhaul.md; the
-- structure follows RIVALS' duels, our own code). MatchService calls
-- MapVoteService.run(pool) between matches; it returns the map to load.
--
--   * The options are the pool (maps that fit the team size), with Random
--     first when there's more than one map.
--   * A player votes with the MapVote remote (an option name). The vote is a
--     server-set Player attribute "MapVote", so every client can draw who
--     voted for what; changing your mind just moves it. Bots don't vote.
--   * Every vote is a ticket and one ticket is drawn; no votes, or the Random
--     ticket, gives any map in the pool. Once every player has voted the clock
--     cuts to Config/Match VOTE.allInSeconds.
--   * State for the screens (MatchState): Phase "Vote" with EndsAt,
--     "VoteOptions" (option names, comma-separated), "VoteTeamSize" (players
--     per side, for the screen's match line), "VoteChosen" ("" while voting,
--     then the picked map for VOTE.chosenSeconds).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Match)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Net = require(ReplicatedStorage.Shared.Net)
local RateLimit = require(ReplicatedStorage.Shared.Util.RateLimit)

local MapVoteService = {}

local VOTE = Config.VOTE
local ATTRIBUTE = "MapVote"
local POLL = 0.1

local limiter = RateLimit.new(Config.RATE)
local open = false
local options: { string } = {}
local random = Random.new()

local function setClock(seconds: number)
	MatchState.set("EndsAt", workspace:GetServerTimeNow() + seconds)
end

local function clearVotes()
	for _, player in Players:GetPlayers() do
		player:SetAttribute(ATTRIBUTE, nil)
	end
end

local function allVoted(): boolean
	local players = Players:GetPlayers()
	if #players == 0 then
		return false
	end
	for _, player in players do
		if player:GetAttribute(ATTRIBUTE) == nil then
			return false
		end
	end
	return true
end

local function draw(pool: { string }): string
	local tickets: { string } = {}
	for _, player in Players:GetPlayers() do
		local vote = player:GetAttribute(ATTRIBUTE)
		if typeof(vote) == "string" and table.find(options, vote) then
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
	player:SetAttribute(ATTRIBUTE, name)
end

-- Runs the vote over `pool` (map ids, at least one) for teams of `teamSize`
-- and returns the pick. Yields for the vote and the chosen-map beat.
function MapVoteService.run(pool: { string }, teamSize: number): string
	assert(#pool > 0, "MapVoteService.run: empty pool")
	options = table.clone(pool)
	if #pool > 1 then
		table.insert(options, 1, VOTE.random)
	end
	clearVotes()
	MatchState.set("VoteOptions", table.concat(options, ","))
	MatchState.set("VoteChosen", "")
	MatchState.set("VoteTeamSize", teamSize)
	setClock(VOTE.seconds)
	MatchState.set("Phase", "Vote")
	open = true

	local deadline = os.clock() + VOTE.seconds
	local shortened = false
	while os.clock() < deadline do
		if not shortened and allVoted() then
			shortened = true
			if deadline - os.clock() > VOTE.allInSeconds then
				deadline = os.clock() + VOTE.allInSeconds
				setClock(VOTE.allInSeconds)
			end
		end
		task.wait(POLL)
	end
	open = false

	local chosen = draw(pool)
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
