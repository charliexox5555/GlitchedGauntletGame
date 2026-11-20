--!strict
-- Server-authoritative queue per mode (vault/01 Design/Lobby UI and Queue.md).
-- A mode launches as soon as it fills; otherwise, once its oldest group has
-- waited Config.botFillAfter (Studio: botFillAfterStudio), everyone waiting
-- goes with bots in the empty slots. The client only asks to join or leave;
-- the queue publishes server-owned state values (see Lobby/LobbyNet).
--
-- Parties (Matchmaking/Parties): a Roblox party here queues as one group on
-- one team. Only its leader starts the queue (the whole party goes in that
-- mode); anyone in it can cancel for all. A party change while searching
-- re-forms the group (a friend who arrives joins the search) or, if it no
-- longer fits the mode, stops it with a message.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Lobby.Config)
local LobbyNet = require(ReplicatedStorage.Lobby.LobbyNet)
local RateLimit = require(ReplicatedStorage.Shared.Util.RateLimit)

local Launcher = require(script.Parent.Parent.Matchmaking.Launcher)
local Matchmaker = require(script.Parent.Parent.Matchmaking.Matchmaker)
local Parties = require(script.Parent.Parent.Matchmaking.Parties)
local LockerService = require(script.Parent.LockerService)

type Status = "idle" | "searching" | "found" | "teleporting"
type State = { status: Status, mode: string?, matchId: string? }

local QueueService = {}

local FILL_AFTER = if RunService:IsStudio() then Config.botFillAfterStudio else Config.botFillAfter

local states: { [Player]: State } = {}
local queues: { [string]: { Matchmaker.Entry } } = {}
for _, m in Config.MODES do
	queues[m.id] = {}
end

local limiter = RateLimit.new(Config.RATE)
local queueEvent: RemoteEvent

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function setState(player: Player, status: Status, mode: string?, matchId: string?)
	states[player] = { status = status, mode = mode, matchId = matchId }
	StateValues.set(player, "QueueStatus", status)
	StateValues.set(player, "QueueMode", mode)
	if status == "idle" then
		StateValues.set(player, "QueueSince", nil)
		StateValues.set(player, "QueueStartsAt", nil)
	end
end

local function updateCounts()
	for mode, queue in queues do
		StateValues.set(LobbyNet.folder, LobbyNet.countAttribute(mode), Matchmaker.count(queue))
	end
end

-- The queued group a player is in, and its mode.
local function entryOf(player: Player): (Matchmaker.Entry?, string?)
	for mode, queue in queues do
		for _, entry in queue do
			if table.find(entry.players, player) then
				return entry, mode
			end
		end
	end
	return nil, nil
end

local function removeEntry(entry: Matchmaker.Entry)
	for _, queue in queues do
		local i = table.find(queue, entry)
		if i then
			table.remove(queue, i)
			return
		end
	end
end

-- Takes the player's whole group out of its queue; returns that group.
local function removeFromQueue(player: Player): Matchmaker.Entry?
	local entry = entryOf(player)
	if entry then
		removeEntry(entry)
	end
	return entry
end

-- Queues stay oldest first (the bot-fill timer reads the first group).
local function insertEntry(mode: string, entry: Matchmaker.Entry)
	local queue = queues[mode]
	local at = #queue + 1
	for i, other in queue do
		if other.since > entry.since then
			at = i
			break
		end
	end
	table.insert(queue, at, entry)
end

local function send(player: Player, payload: LobbyNet.QueueEventPayload)
	if player.Parent == Players then
		queueEvent:FireClient(player, payload)
	end
end

local function backToLobby(player: Player, matchId: string, text: string?)
	local state = states[player]
	if not state or state.matchId ~= matchId then
		return
	end
	setState(player, "idle")
	if text then
		send(player, { kind = "failed", text = text })
	end
end

local function launch(info: Config.ModeInfo, pick: Matchmaker.Pick)
	local matchId = HttpService:GenerateGUID(false)
	local players: { Player } = {}
	for _, entry in pick.entries do
		removeEntry(entry)
		for _, p in entry.players do
			table.insert(players, p)
		end
	end
	updateCounts()

	-- save Locker equips now so the write lands before the teleport
	for _, p in players do
		LockerService.flush(p)
	end
	local startsAtServer = serverNow() + Config.matchFoundDelay
	local teams: { { number } } = {}
	for t, team in pick.teams do
		teams[t] = {}
		for _, p in team do
			table.insert(teams[t], p.UserId)
		end
	end
	for _, p in players do
		setState(p, "found", info.id, matchId)
		StateValues.set(p, "QueueStartsAt", startsAtServer)
		send(p, {
			kind = "found",
			mode = info.id,
			teams = teams,
			teamSize = info.teamSize,
			startsAt = startsAtServer,
		})
	end
	print(
		`[Queue] match {matchId} found: {info.id}, {#players} player(s), bots {#players < info.teamSize * 2}`
	)

	local match: Launcher.Match = {
		id = matchId,
		mode = info.id,
		teamSize = info.teamSize,
		players = players,
		teams = teams,
		startsAt = os.clock() + Config.matchFoundDelay,
	}
	local hooks: Launcher.Hooks = {
		stillIn = function(p: Player): boolean
			local s = states[p]
			return s ~= nil and s.matchId == matchId
		end,
		teleporting = function(p: Player)
			local s = states[p]
			if s and s.matchId == matchId then
				setState(p, "teleporting", info.id, matchId)
			end
		end,
		failed = function(p: Player, text: string)
			backToLobby(p, matchId, text)
		end,
		studio = function(p: Player, json: string)
			send(p, { kind = "studio", mode = info.id, payload = json })
			task.delay(Config.studioHold, backToLobby, p, matchId, nil)
		end,
	}

	-- A launch that errors or hangs (e.g. reserve retries) must never strand
	-- players on "found": they go back to the lobby with a message.
	task.delay(Config.matchFoundDelay + Config.foundTimeout, function()
		for _, p in players do
			local s = states[p]
			if s and s.matchId == matchId and s.status == "found" then
				backToLobby(
					p,
					matchId,
					"Couldn't start the match. You're back in the lobby; try again."
				)
			end
		end
	end)
	local ok, err = pcall(Launcher.launch, match, hooks)
	if not ok then
		warn(`[Queue] launch {matchId} errored: {err}`)
		for _, p in players do
			backToLobby(
				p,
				matchId,
				"Couldn't start the match. You're back in the lobby; try again."
			)
		end
	end
end

local function tick()
	local now = os.clock()
	for _, info in Config.MODES do
		local pick = Matchmaker.pick(queues[info.id], info.teamSize, now, FILL_AFTER)
		if pick then
			task.spawn(launch, info, pick)
		end
	end
end

-- Puts a group in a mode's queue (keeping `since` when it re-forms).
local function enqueue(members: { Player }, info: Config.ModeInfo, since: number)
	insertEntry(info.id, { players = members, since = since })
	local sinceServer = serverNow() - (os.clock() - since)
	for _, m in members do
		setState(m, "searching", info.id)
		StateValues.set(m, "QueueSince", sinceServer)
	end
end

-- Everyone in the group must be free to queue (idle, or searching: a new
-- PLAY moves them).
local function free(members: { Player }): boolean
	for _, m in members do
		local s = states[m]
		if not s or (s.status ~= "idle" and s.status ~= "searching") then
			return false
		end
	end
	return true
end

local function join(player: Player, info: Config.ModeInfo)
	local members = Parties.members(player)
	if members[1] ~= player then
		send(player, { kind = "info", text = "Your party leader starts the search" })
		return
	end
	if #members > info.teamSize then
		send(player, {
			kind = "failed",
			text = `Your party has {#members} players: pick {#members}V{#members}`,
		})
		return
	end
	local current, mode = entryOf(player)
	if current and mode == info.id and #current.players == #members then
		return
	end
	if not free(members) then
		return
	end
	for _, m in members do
		removeFromQueue(m) -- switching modes restarts the wait
	end
	enqueue(members, info, os.clock())
	for i, m in members do
		if i > 1 then
			send(m, {
				kind = "info",
				text = `{string.upper(player.DisplayName)} started a {string.upper(info.id)} search`,
			})
		end
	end
	updateCounts()
	tick()
end

-- Anyone in a queued party can cancel; it stops for the whole party.
local function leave(player: Player)
	local state = states[player]
	if not state or state.status ~= "searching" then
		return
	end
	local entry = removeFromQueue(player)
	for _, m in if entry then entry.players else { player } do
		if m.Parent == Players and states[m] then
			setState(m, "idle")
			if m ~= player then
				send(m, {
					kind = "info",
					text = `{string.upper(player.DisplayName)} stopped the search`,
				})
			end
		end
	end
	updateCounts()
end

-- A party changed (someone joined or left it, or this server): each queued
-- group holding one of these players re-forms around its leader's current
-- party in the same mode and keeps its wait, or stops if it no longer fits.
type Redo = { leader: Player, mode: string, since: number, was: { Player } }

local function onPartyChanged(players: { Player })
	local redo: { Redo } = {}
	for _, p in players do
		local entry, mode = entryOf(p)
		if entry and mode then
			removeEntry(entry)
			for _, m in entry.players do
				if m.Parent == Players and states[m] then
					setState(m, "idle")
				end
			end
			table.insert(
				redo,
				{ leader = entry.players[1], mode = mode, since = entry.since, was = entry.players }
			)
		end
	end
	for _, r in redo do
		local info = Config.MODE_BY_ID[r.mode]
		-- the old leader left: the next one still here takes the group on
		local anchor: Player? = nil
		for _, m in r.was do
			if Parties.isHere(m) and states[m] then
				anchor = m
				break
			end
		end
		if not anchor or entryOf(anchor) then
			continue
		end
		local members = Parties.members(anchor)
		if info and #members <= info.teamSize and free(members) then
			enqueue(members, info, r.since)
			for _, m in members do
				if not table.find(r.was, m) then
					send(m, {
						kind = "info",
						text = `You joined your party's {string.upper(info.id)} search`,
					})
				end
			end
		else
			for _, m in r.was do
				if m.Parent == Players and states[m] and not entryOf(m) then
					send(m, { kind = "failed", text = "Your party changed, so the search stopped" })
				end
			end
		end
	end
	if #redo > 0 then
		updateCounts()
		tick()
	end
end

-- Rejected requests are dropped and counted, never kicked; a summary is
-- logged once per interval (LihFolk: Rate Limiting and Abuse Prevention;
-- False Positives Lag and Fair Enforcement).
local rejects: { [string]: number } = {}

local function reject(reason: string)
	rejects[reason] = (rejects[reason] or 0) + 1
end

local function onRequest(player: Player, action: unknown, mode: unknown)
	if not limiter:allow(player, "QueueRequest") then
		reject("rate")
		return
	end
	if typeof(action) ~= "string" then
		reject("badAction")
		return
	end
	if action == "join" then
		if typeof(mode) ~= "string" or #mode > 8 then
			reject("badMode")
			return
		end
		local info = Config.MODE_BY_ID[mode :: string]
		if info and info.enabled then
			join(player, info)
		else
			reject("unknownMode")
		end
	elseif action == "leave" then
		leave(player)
	else
		reject("badAction")
	end
end

-- Play Again from the match-end screen (Services/MatchEndService in the match
-- place): TeleportData `{ v = 1, from = "match", requeue = mode }` puts the
-- player straight back in that mode's queue. TeleportData travels through
-- the client, so it's only a request to do what the PLAY button does anyway.
local function requeueFromMatch(player: Player)
	local ok, joinData = pcall(function()
		return player:GetJoinData()
	end)
	if not ok or typeof(joinData) ~= "table" then
		return
	end
	if (joinData :: any).SourcePlaceId ~= Config.MATCH_PLACE_ID then
		return
	end
	local data = (joinData :: any).TeleportData
	if typeof(data) ~= "table" or data.from ~= "match" then
		return
	end
	local mode = data.requeue
	if typeof(mode) ~= "string" or #mode > 8 then
		return
	end
	local info = Config.MODE_BY_ID[mode]
	if info and info.enabled and Parties.leader(player) == player then
		join(player, info)
	end
end

local function onPlayerAdded(player: Player)
	setState(player, "idle")
	task.defer(requeueFromMatch, player)
end

function QueueService.init()
	queueEvent = LobbyNet.event("QueueEvent")
	StateValues.set(LobbyNet.folder, "BotFillAfter", FILL_AFTER)
	updateCounts()
	Launcher.init()
end

function QueueService.start()
	LobbyNet.event("QueueRequest").OnServerEvent:Connect(onRequest)
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, p in Players:GetPlayers() do
		onPlayerAdded(p)
	end
	Players.PlayerRemoving:Connect(function(player)
		-- a queued party's rest is re-formed by Parties.onChanged
		local entry = entryOf(player)
		if entry and #entry.players == 1 then
			removeEntry(entry)
			updateCounts()
		end
		states[player] = nil
		limiter:forget(player)
	end)
	Parties.onChanged(onPartyChanged)
	Parties.start()
	task.spawn(function()
		while true do
			task.wait(Config.rejectLogInterval)
			if next(rejects) then
				local parts = {}
				for reason, n in rejects do
					table.insert(parts, `{reason}={n}`)
				end
				warn(
					`[Queue] rejected QueueRequest in the last {Config.rejectLogInterval} s: {table.concat(
						parts,
						", "
					)}`
				)
				table.clear(rejects)
			end
		end
	end)
	while true do
		task.wait(Config.tickInterval)
		tick()
	end
end

return QueueService
