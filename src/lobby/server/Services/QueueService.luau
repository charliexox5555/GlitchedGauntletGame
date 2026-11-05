--!strict
-- Server-authoritative solo queue per mode (vault/01 Design/Lobby UI and Queue.md).
-- A mode launches as soon as it fills; otherwise, once its oldest player has
-- waited Config.botFillAfter (Studio: botFillAfterStudio), everyone waiting
-- goes with bots in the empty slots. The client only asks to join or leave;
-- every state lives in server-owned attributes (see Lobby/LobbyNet).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Lobby.Config)
local LobbyNet = require(ReplicatedStorage.Lobby.LobbyNet)
local RateLimit = require(ReplicatedStorage.Shared.Util.RateLimit)

local Launcher = require(script.Parent.Parent.Matchmaking.Launcher)
local Matchmaker = require(script.Parent.Parent.Matchmaking.Matchmaker)

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
	player:SetAttribute("QueueStatus", status)
	player:SetAttribute("QueueMode", mode)
	if status == "idle" then
		player:SetAttribute("QueueSince", nil)
		player:SetAttribute("QueueStartsAt", nil)
	end
end

local function updateCounts()
	for mode, queue in queues do
		LobbyNet.folder:SetAttribute(LobbyNet.countAttribute(mode), #queue)
	end
end

local function removeFromQueue(player: Player): boolean
	for _, queue in queues do
		for i, entry in queue do
			if entry.player == player then
				table.remove(queue, i)
				return true
			end
		end
	end
	return false
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

local function launch(info: Config.ModeInfo, entries: { Matchmaker.Entry })
	local matchId = HttpService:GenerateGUID(false)
	local players: { Player } = {}
	local ids: { number } = {}
	for _, entry in entries do
		removeFromQueue(entry.player)
		table.insert(players, entry.player)
		table.insert(ids, entry.player.UserId)
	end
	updateCounts()

	local startsAtServer = serverNow() + Config.matchFoundDelay
	local teams = Matchmaker.teams(ids)
	for _, p in players do
		setState(p, "found", info.id, matchId)
		p:SetAttribute("QueueStartsAt", startsAtServer)
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

	Launcher.launch({
		id = matchId,
		mode = info.id,
		teamSize = info.teamSize,
		players = players,
		startsAt = os.clock() + Config.matchFoundDelay,
	}, {
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
	})
end

local function tick()
	local now = os.clock()
	for _, info in Config.MODES do
		local group = Matchmaker.pick(queues[info.id], info.teamSize, now, FILL_AFTER)
		if group then
			task.spawn(launch, info, group)
		end
	end
end

local function join(player: Player, info: Config.ModeInfo)
	local state = states[player]
	if not state then
		return
	end
	if state.status == "searching" then
		if state.mode == info.id then
			return
		end
		removeFromQueue(player) -- switching modes restarts the wait
	elseif state.status ~= "idle" then
		return
	end
	table.insert(queues[info.id], { player = player, since = os.clock() })
	setState(player, "searching", info.id)
	player:SetAttribute("QueueSince", serverNow())
	updateCounts()
	tick()
end

local function leave(player: Player)
	local state = states[player]
	if not state or state.status ~= "searching" then
		return
	end
	removeFromQueue(player)
	setState(player, "idle")
	updateCounts()
end

local function onRequest(player: Player, action: unknown, mode: unknown)
	if not limiter:allow(player, "QueueRequest") then
		return
	end
	if typeof(action) ~= "string" then
		return
	end
	if action == "join" then
		if typeof(mode) ~= "string" or #mode > 8 then
			return
		end
		local info = Config.MODE_BY_ID[mode :: string]
		if info and info.enabled then
			join(player, info)
		end
	elseif action == "leave" then
		leave(player)
	end
end

local function onPlayerAdded(player: Player)
	setState(player, "idle")
end

function QueueService.init()
	queueEvent = LobbyNet.event("QueueEvent")
	LobbyNet.folder:SetAttribute("BotFillAfter", FILL_AFTER)
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
		if removeFromQueue(player) then
			updateCounts()
		end
		states[player] = nil
		limiter:forget(player)
	end)
	while true do
		task.wait(Config.tickInterval)
		tick()
	end
end

return QueueService
