--!strict
-- Server-authoritative queue per mode (vault/01 Design/Lobby UI and Queue.md).
-- A mode launches as soon as it fills; otherwise, once its oldest group has
-- waited Config.botFillAfter (Studio: botFillAfterStudio), everyone waiting
-- goes with bots in the empty slots. The client only asks to join or leave;
-- the queue publishes server-owned state values (see Lobby/LobbyNet).
--
-- Global (place merge 2026-11-21): groups are also written to the global
-- queue (Matchmaking/GlobalQueue), which matches them with groups from every
-- lobby server; a matched group teleports to the reserved server the match
-- shares. If MemoryStore can't be reached, matching stays inside this server.
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

local GlobalQueue = require(script.Parent.Parent.Matchmaking.GlobalQueue)
local Launcher = require(script.Parent.Parent.Matchmaking.Launcher)
local Matchmaker = require(script.Parent.Parent.Matchmaking.Matchmaker)
local Parties = require(script.Parent.Parent.Matchmaking.Parties)
local LockerService = require(script.Parent.LockerService)
local OnboardingConfig = require(ReplicatedStorage.Shared.Config.Onboarding)
local PlayerData = require(ReplicatedStorage.Shared.PlayerData)
local PlayZone = require(ReplicatedStorage.Shared.PlayZone)
local ServerRole = require(ReplicatedStorage.Shared.ServerRole)
local Telemetry = require(script.Parent.Parent.Telemetry)

type Status = "idle" | "searching" | "found" | "teleporting"
type State = { status: Status, mode: string?, matchId: string? }

local QueueService = {}

local IS_STUDIO = RunService:IsStudio()
local FILL_AFTER = if IS_STUDIO then Config.botFillAfterStudio else Config.botFillAfter

-- Seconds before bots fill a mode (Beginner 2v2 has its own, shorter wait).
local function fillFor(info: Config.ModeInfo): number
	local own = if IS_STUDIO then info.fillAfterStudio or info.fillAfter else info.fillAfter
	return own or FILL_AFTER
end

-- A mode with a level cap (Beginner 2v2): every member's save loaded and below it.
local function levelOk(members: { Player }, info: Config.ModeInfo): boolean
	local cap = info.maxLevel
	if not cap then
		return true
	end
	for _, m in members do
		local level = StateValues.get(m, "Level")
		if not PlayerData.ready(m) or typeof(level) ~= "number" or level >= cap then
			return false
		end
	end
	return true
end

local states: { [Player]: State } = {}
-- In-server onboarding matches started this session (OnboardingConfig.INSTANT_MATCHES), so a save that
-- hasn't counted a match yet can't loop a player through them.
local instantUsed: { [Player]: number } = {}
local writingTickets: { [Matchmaker.Entry]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local autoRetried: { [Player]: number } = {}
local join: (player: Player, info: Config.ModeInfo) -> ()
local queues: { [string]: { Matchmaker.Entry } } = {}
for _, m in Config.MODES do
	queues[m.id] = {}
end

local matchHostRef: any = nil
local function getMatchHost(): any
	if matchHostRef then
		return matchHostRef
	end
	local server = game:GetService("ServerScriptService"):FindFirstChild("Server")
	local services = server and server:FindFirstChild("Services")
	local host = services and services:FindFirstChild("MatchHost")
	if host and host:IsA("ModuleScript") then
		matchHostRef = require(host)
	end
	return matchHostRef
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
	local global = if GlobalQueue.isOn() then GlobalQueue.counts() else nil
	for mode, queue in queues do
		-- Everyone searching in every server (at least this server's own).
		local n = Matchmaker.count(queue)
		if global then
			n = math.max(n, global[mode] or 0)
		end
		StateValues.set(LobbyNet.folder, LobbyNet.countAttribute(mode), n)
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
	local ticket = entry.ticket
	if ticket then
		entry.ticket = nil
		GlobalQueue.remove(ticket)
	end
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
		Telemetry.queueStop(player, "Queue launch failed")
		send(player, { kind = "failed", text = text })
	end
end

-- Starts the match-found beat and the teleport for this server's `players`.
-- `teams` lists every player in the match (other servers' too, for a global
-- match); `reservedServerId` / `bots` come from the global matchmaker.
local function startLaunch(
	info: Config.ModeInfo,
	players: { Player },
	teams: { { number } },
	matchId: string,
	reservedServerId: string?,
	bots: boolean?
)
	updateCounts()

	local startsAt = os.clock() + Config.matchFoundDelay
	local startsAtServer = serverNow() + Config.matchFoundDelay
	for _, p in players do
		setState(p, "found", info.id, matchId)
		Telemetry.queueStep(p, 2, "Match found")
		StateValues.set(p, "QueueStartsAt", startsAtServer)
		send(p, {
			kind = "found",
			mode = info.id,
			teams = teams,
			teamSize = info.teamSize,
			startsAt = startsAtServer,
		})
	end
	-- Reserve the queue state before a Locker save can yield.
	for _, p in players do
		LockerService.flush(p)
	end
	print(`[Queue] match {matchId} found: {info.id}, {#players} player(s) here, bots {bots}`)

	local match: Launcher.Match = {
		id = matchId,
		mode = info.id,
		teamSize = info.teamSize,
		players = players,
		teams = teams,
		startsAt = startsAt,
		reservedServerId = reservedServerId,
		bots = bots,
	}
	local function recoverTimeout(p: Player, text: string)
		if
			p.Parent == Players
			and PlayZone.get(p) == "Lobby"
			and Parties.leader(p) == p
			and (not autoRetried[p] or os.clock() - autoRetried[p] > 45)
		then
			autoRetried[p] = os.clock()
			backToLobby(p, matchId, nil)
			send(p, { kind = "info", text = "Match took too long to load — re-queueing..." })
			task.delay(1, function()
				if p.Parent == Players and PlayZone.get(p) == "Lobby" then
					join(p, info)
				end
			end)
		else
			backToLobby(p, matchId, text)
		end
	end

	local hooks: Launcher.Hooks = {
		stillIn = function(p: Player): boolean
			local s = states[p]
			return s ~= nil and s.matchId == matchId and PlayZone.get(p) == "Lobby"
		end,
		teleporting = function(p: Player)
			local s = states[p]
			if s and s.matchId == matchId then
				Telemetry.queueStep(p, 3, "Teleport requested")
				setState(p, "teleporting", info.id, matchId)
			end
		end,
		failed = function(p: Player, text: string)
			if string.find(text, "too long", 1, true) then
				recoverTimeout(p, text)
			else
				backToLobby(p, matchId, text)
			end
		end,
		studio = function(p: Player, json: string)
			send(p, { kind = "studio", mode = info.id, payload = json })
			task.delay(Config.studioHold, backToLobby, p, matchId, nil)
		end,
	}

	-- A launch that errors or hangs (e.g. reserve retries) must never strand
	-- players on "found": they go back to the lobby and re-queue cleanly.
	task.delay(Config.matchFoundDelay + Config.foundTimeout, function()
		for _, p in players do
			local s = states[p]
			if s and s.matchId == matchId and s.status == "found" then
				recoverTimeout(p, "Couldn't start the match. You're back in the lobby; try again.")
			end
		end
	end)
	local ok, err = pcall(function()
		-- Once found, new Mod changes are blocked. Let a choice already being
		-- saved commit before the destination server reads the player's data.
		for _, p in players do
			while hooks.stillIn(p) and LockerService.isSavingMods(p) do
				task.wait(0.1)
			end
		end
		Launcher.launch(match, hooks)
	end)
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

-- A match inside this server (the fallback when the global queue is off).
local function launch(info: Config.ModeInfo, pick: Matchmaker.Pick)
	local players: { Player } = {}
	for _, entry in pick.entries do
		removeEntry(entry)
		for _, p in entry.players do
			table.insert(players, p)
		end
	end
	local teams: { { number } } = {}
	for t, team in pick.teams do
		teams[t] = {}
		for _, p in team do
			table.insert(teams[t], p.UserId)
		end
	end
	startLaunch(
		info,
		players,
		teams,
		HttpService:GenerateGUID(false),
		nil,
		#players < info.teamSize * 2
	)
end

-- The global matchmaker matched one of our groups.
local function onGlobalMatch(ticket: string, match: GlobalQueue.MatchInfo)
	local info = Config.MODE_BY_ID[match.mode]
	local found: Matchmaker.Entry? = nil
	for _, queue in queues do
		for _, entry in queue do
			if entry.ticket == ticket then
				found = entry
				break
			end
		end
	end
	if not info or not found then
		return -- cancelled meanwhile: the match server gives the seat to a bot
	end
	removeEntry(found)
	local players: { Player } = {}
	for _, p in found.players do
		local s = states[p]
		if
			p.Parent == Players
			and PlayZone.get(p) == "Lobby"
			and s
			and s.status == "searching"
			and s.mode == match.mode
		then
			table.insert(players, p)
		end
	end
	if #players > 0 then
		startLaunch(info, players, match.teams, match.id, match.rsid, match.bots)
	end
end

local WRITE_BACKOFF = { 2, 4 }

-- Writes a queued group's global ticket (yields; the group may be gone by then).
local function writeTicket(mode: string, entry: Matchmaker.Entry)
	if not GlobalQueue.isOn() or writingTickets[entry] then
		return
	end
	writingTickets[entry] = true
	local users: { number } = {}
	for _, p in entry.players do
		table.insert(users, p.UserId)
	end
	for attempt = 1, 3 do
		local queue = queues[mode]
		if not queue or not table.find(queue, entry) or entry.ticket then
			break
		end
		local ticket = GlobalQueue.add(mode, users, os.clock() - entry.since)
		if ticket then
			local latestQueue = queues[mode]
			if latestQueue and table.find(latestQueue, entry) and not entry.ticket then
				entry.ticket = ticket
			else
				GlobalQueue.remove(ticket)
			end
			break
		end
		if attempt < 3 then
			task.wait(WRITE_BACKOFF[attempt])
		end
	end
	writingTickets[entry] = nil
end

local function tick()
	local now = os.clock()
	if GlobalQueue.isOn() then
		updateCounts() -- the global matchmaker does the matching
		for _, info in Config.MODES do
			local unticketed: { Matchmaker.Entry } = {}
			for _, entry in queues[info.id] do
				if entry.ticket == nil then
					if not writingTickets[entry] and now - entry.since >= 4 then
						task.spawn(writeTicket, info.id, entry)
					end
					if now - entry.since >= fillFor(info) + 5 then
						table.insert(unticketed, entry)
					end
				end
			end
			if #unticketed > 0 then
				local pick = Matchmaker.pick(unticketed, info.teamSize, now, fillFor(info))
				if pick then
					task.spawn(launch, info, pick)
				end
			end
		end
		return
	end
	for _, info in Config.MODES do
		local pick = Matchmaker.pick(queues[info.id], info.teamSize, now, fillFor(info))
		if pick then
			task.spawn(launch, info, pick)
		end
	end
end

-- Puts a group in a mode's queue (keeping `since` when it re-forms).
local function enqueue(members: { Player }, info: Config.ModeInfo, since: number)
	local entry: Matchmaker.Entry = { players = members, since = since }
	insertEntry(info.id, entry)
	task.spawn(writeTicket, info.id, entry)
	local sinceServer = serverNow() - (os.clock() - since)
	for _, m in members do
		setState(m, "searching", info.id)
		Telemetry.queueStart(m, info.id)
		local matches = StateValues.get(m, "Matches")
		local used = instantUsed[m] or 0
		if info.id == "beginner" and matches == 0 and used == 0 then
			Telemetry.onboarding(m, 2)
		elseif matches == 1 or (matches == 0 and used > 0) then
			Telemetry.onboarding(m, 17)
		end
		StateValues.set(m, "QueueSince", sinceServer)
	end
end

-- Everyone in the group must be free to queue (idle, or searching: a new
-- PLAY moves them).
local function free(members: { Player }): boolean
	for _, m in members do
		local s = states[m]
		if
			m.Parent ~= Players
			or PlayZone.get(m) ~= "Lobby"
			or not s
			or (s.status ~= "idle" and s.status ~= "searching")
		then
			return false
		end
	end
	return true
end

join = function(player: Player, info: Config.ModeInfo)
	-- only from the lobby (a player in a hosted match or a pad duel can't queue)
	if PlayZone.get(player) ~= "Lobby" then
		return
	end
	player:SetAttribute("OnbNextMatch", nil) -- a parked NEXT MATCH (onRequeue) is used up by any search
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
	if not levelOk(members, info) then
		send(player, {
			kind = "failed",
			text = `{info.title} is for players below level {info.maxLevel}`,
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
	local host = getMatchHost()
	-- A solo new player's first Beginner matches start at once in this server (OnboardingConfig.INSTANT_MATCHES):
	-- the saved count or this session's, whichever is further, so a slow save can't repeat one.
	local matches = StateValues.get(player, "Matches")
	local used = instantUsed[player] or 0
	local onboardingMatch = if typeof(matches) == "number" then math.max(matches, used) else nil
	if
		info.id == OnboardingConfig.BEGINNER_MODE
		and ServerRole.isLobby()
		and not ServerRole.isHosted()
		and #members == 1
		and onboardingMatch ~= nil
		and onboardingMatch < OnboardingConfig.INSTANT_MATCHES
		and host
	then
		instantUsed[player] = used + 1
		setState(player, "idle")
		Telemetry.queueStop(player, "Queue switched")
		updateCounts()
		Telemetry.onboarding(player, if onboardingMatch == 0 then 2 else 17)
		host.startDuel(info.id, info.teamSize, { { player }, {} }, true, true)
		return
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
			Telemetry.queueStop(m, "Queue cancelled")
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
		if info and #members <= info.teamSize and free(members) and levelOk(members, info) then
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
		autoRetried[player] = nil
		if typeof(mode) ~= "string" or #mode > 16 then
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
		autoRetried[player] = nil
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
	-- From a match server (a reserved server of this same place).
	if joinData.SourcePlaceId ~= game.PlaceId or joinData.SourceGameId ~= game.GameId then
		return
	end
	local data = (joinData :: any).TeleportData
	if typeof(data) ~= "table" or data.from ~= "match" then
		return
	end
	local mode = data.requeue
	if typeof(mode) ~= "string" or #mode > 16 then
		return
	end
	local info = Config.MODE_BY_ID[mode]
	if info and info.maxLevel then
		-- Beginner 2v2 grown out of (or a party member is): the normal mode of that size
		local t0 = os.clock()
		while not PlayerData.ready(player) and player.Parent == Players and os.clock() - t0 < 15 do
			task.wait(0.25)
		end
		if not levelOk(Parties.members(player), info) then
			info = Config.MODE_BY_ID[`{info.teamSize}v{info.teamSize}`]
		end
	end
	if info and info.enabled and Parties.leader(player) == player then
		if data.cancelled == true then
			send(
				player,
				{ kind = "info", text = "Previous match took too long to load — re-queueing!" }
			)
		end
		join(player, info)
	end
end

local function onPlayerAdded(player: Player)
	setState(player, "idle")
	task.defer(requeueFromMatch, player)
end

function QueueService.resetOnboarding(player: Player)
	instantUsed[player] = nil
	player:SetAttribute("OnbNextMatch", nil)
	local state = states[player]
	if state and state.status == "searching" then
		leave(player)
	end
end

function QueueService.init()
	queueEvent = LobbyNet.event("QueueEvent")
	StateValues.set(LobbyNet.folder, "BotFillAfter", FILL_AFTER)
	updateCounts()
	Launcher.init()
end

function QueueService.start()
	LobbyNet.event("QueueRequest").OnServerEvent:Connect(onRequest)
	PlayZone.changed:Connect(function(player: Player, zone: string)
		if zone ~= "Lobby" then
			leave(player)
		end
	end)
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
		instantUsed[player] = nil
		autoRetried[player] = nil
		limiter:forget(player)
	end)
	Parties.onChanged(onPartyChanged)
	Parties.start()
	-- Play Again from a hosted match (Server MatchHost): that mode's queue, from this server's lobby; Beginner
	-- grown out of falls back to the normal mode of that size.
	task.spawn(function()
		local server = game:GetService("ServerScriptService"):WaitForChild("Server", 10)
		local services = server and server:FindFirstChild("Services")
		local host = services and services:FindFirstChild("MatchHost")
		if not (host and host:IsA("ModuleScript")) then
			return
		end
		local mod = require(host) :: any
		matchHostRef = mod
		mod.onRequeue(function(player: Player, mode: string)
			local info = Config.MODE_BY_ID[mode]
			if info and info.maxLevel and not levelOk(Parties.members(player), info) then
				info = Config.MODE_BY_ID[`{info.teamSize}v{info.teamSize}`]
			end
			-- sendHome sets the zone first; give it a beat
			local t0 = os.clock()
			while
				PlayZone.get(player) ~= "Lobby"
				and player.Parent == Players
				and os.clock() - t0 < 5
			do
				task.wait(0.2)
			end
			-- NEXT MATCH after a new player's first match while the free case is still shut: park the request;
			-- the lobby opens the case by itself, then queues (Controllers/OnboardingController, vault/01
			-- Design/First Ten Minutes.md). The attribute only says "they asked"; the search goes through join.
			if
				info
				and StateValues.get(player, "OnbCaseGift") == true
				and StateValues.get(player, "OnbCaseOpened") ~= true
			then
				player:SetAttribute("OnbNextMatch", info.id)
				return
			end
			if info and info.enabled and Parties.leader(player) == player then
				join(player, info)
			end
		end)
	end)
	local rules = {}
	for _, m in Config.MODES do
		if m.enabled then
			table.insert(
				rules,
				{ id = m.id :: string, teamSize = m.teamSize, fillAfter = fillFor(m) }
			)
		end
	end
	GlobalQueue.onMatched(onGlobalMatch)
	task.spawn(GlobalQueue.start, rules, FILL_AFTER)
	game:BindToClose(GlobalQueue.releaseAll)
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
