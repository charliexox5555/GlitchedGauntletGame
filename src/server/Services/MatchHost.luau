--!strict
-- MatchHost: starts and ends matches (place merge 2026-11-21, vault/04 Tech/Place Merge Plan.md).
--  * Match server (shared/ServerRole): one whole-server match at start, as the match place always ran.
--  * Hosted (a reserved server for a queued match, Shared/ServerRole.isHosted; owner 2026-11-23): a Lobby server
--    whose queued match runs as an instance like a pad duel, from the TeleportData plan; players join it as they
--    arrive (bots take the seats nobody fills), and at the end they stay here in the lobby.
--  * Lobby server: pad duels (PadDuelService), several at once. Each gets an id, its own MatchState folder
--    (ReplicatedStorage.Matches[id]), its own world folder (Workspace.Matches[id]) and an isolated arena slot.
--    Its players move to the "Match" PlayZone with that MatchId (their match client
--    starts fresh); when it ends they go back to the lobby with their own avatars and the duel is torn down.
-- Each match runs in its own copy of MatchKit/MatchRunner (see there); KIT_SERVICES are the services it copies.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local MatchState = require(ReplicatedStorage.Shared.MatchState)
local MatchConfig = require(ReplicatedStorage.Shared.Config.Match)
local PlayZone = require(ReplicatedStorage.Shared.PlayZone)
local ServerRole = require(ReplicatedStorage.Shared.ServerRole)
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local HealthLog = require(ReplicatedStorage.Shared.HealthLog)
local Telemetry = require(game:GetService("ServerScriptService").LobbyServer.Telemetry)
local Teams = require(ReplicatedStorage.Shared.Mods.Teams)

local BotsConfig = require(ReplicatedStorage.Shared.Config.Bots)
local CharacterService = require(script.Parent.CharacterService)
local WeaponService = require(script.Parent.WeaponService)
local Spectated = require(script.Parent.Parent.Bots.Spectated)

local MatchHost = {}

-- The match-flow services every match runs its own copy of.
MatchHost.KIT_SERVICES = {
	"BotService",
	"DevModService",
	"DraftService",
	"MapService",
	"MapVoteService",
	"MatchEndService",
	"MatchService",
	"ModRecall",
	"ModService",
	"ModSim",
	"ModWalls",
	"SpectateService",
	"StatsService",
	"TestRangeService",
	"ZoneService",
}

-- The range's practice context (Lobby servers): the Mods and the F8 Mod dev
-- panel's backend, no match loop. Range players join it on the way in.
MatchHost.PRACTICE_ID = "range"
MatchHost.PRACTICE_SERVICES = { "DevModService", "ModRecall", "ModService", "ModSim", "ModWalls" }

-- Work a match asks for that must outlive its runner (teardown, the trip home, a requeue). A thread
-- the runner starts dies when teardown destroys the runner, so these run on MatchHost's own thread:
-- the BindableEvent is connected in init(), from the server's boot script, which is never destroyed.
local hostJobs: { () -> () } = {}
local hostSignal = Instance.new("BindableEvent")
local function onHostThread(fn: () -> ())
	table.insert(hostJobs, fn)
	hostSignal:Fire()
end

local EMPTY_GRACE = 8 -- seconds a pad duel may have none of its players before it's ended
local HOSTED_EMPTY_GRACE = 60 -- a hosted match waits this long for its first player (teleports take time)

-- Play Again from a hosted match: the Lobby's QueueService registers here (onRequeue).
local requeueHooks: { (Player, string) -> () } = {}
function MatchHost.onRequeue(fn: (Player, string) -> ())
	table.insert(requeueHooks, fn)
end

export type Plan = {
	matchId: string,
	mode: string,
	size: number,
	teams: { { number } },
	bots: boolean,
}

type Running = {
	id: string,
	runner: Script,
	stateFolder: Folder?,
	world: Instance?,
	slot: number,
	players: { Player },
	context: any?,
	cleanPlayer: ((Player) -> ())?,
	ownsServer: boolean,
	ending: boolean,
	emptySince: number?,
	practice: boolean?,
	hosted: boolean?,
	plan: Plan?,
}

local specs: { [string]: any } = {}
local running: { [string]: Running } = {}
local usedSlots: { [number]: boolean } = {}

local function folder(parent: Instance, name: string): Folder
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local made = Instance.new("Folder")
	made.Name = name
	made.Parent = parent
	return made
end

local function freeSlot(): number
	local slot = 1
	while usedSlots[slot] do
		slot += 1
	end
	usedSlots[slot] = true
	return slot
end

-- Start over the origin, then fill square rings around it. The slots are
-- absolute so the map's position in Studio has no effect on a live duel.
local function arenaOrigin(slot: number): Vector3
	if slot == 1 then
		return Vector3.new(0, MatchConfig.ARENA_Y, 0)
	end
	local ring = math.ceil((math.sqrt(slot) - 1) / 2)
	local index = slot - (2 * ring - 1) ^ 2 - 1
	local side, step = math.floor(index / (2 * ring)), index % (2 * ring)
	local x, z
	if side == 0 then
		x, z = ring, step - ring
	elseif side == 1 then
		x, z = ring - step, ring
	elseif side == 2 then
		x, z = -ring, ring - step
	else
		x, z = step - ring, -ring
	end
	return Vector3.new(
		x * MatchConfig.ARENA_SPACING,
		MatchConfig.ARENA_Y,
		z * MatchConfig.ARENA_SPACING
	)
end

-- MatchRunner takes its match's spec once.
function MatchHost.takeSpec(id: string): any
	local spec = specs[id]
	specs[id] = nil
	return spec
end

-- Range players waiting for the practice context to start.
local practiceWaiting: { [Player]: boolean } = {}

function MatchHost.started(id: string, context: any, cleanPlayer: ((Player) -> ())?)
	local entry = running[id]
	if entry then
		entry.context = context
		entry.cleanPlayer = cleanPlayer
		-- a hosted match's players who arrived while its runner was starting
		if entry.hosted then
			for _, p in entry.players do
				if p.Parent == Players and not context.has(p) then
					context.addPlayer(p)
				end
			end
		end
	end
	if id == MatchHost.PRACTICE_ID then
		for player in practiceWaiting do
			if player.Parent == Players and PlayZone.get(player) == "Range" then
				context.addPlayer(player)
			end
		end
		table.clear(practiceWaiting)
	end
end

local function launchRunner(id: string): Script
	local template = ServerScriptService:WaitForChild("Server")
		:WaitForChild("MatchKit")
		:WaitForChild("MatchRunner")
	local runner = template:Clone() :: Script
	runner.Name = "Match_" .. id
	runner:SetAttribute("MatchRunnerId", id)
	runner.Parent = ServerScriptService
	return runner
end

-- One player back in the lobby: their own avatar at the lobby spawn, no guns.
local function sendHome(entry: Running, player: Player)
	if entry.cleanPlayer then
		entry.cleanPlayer(player)
	end
	if entry.context then
		entry.context.removePlayer(player)
	end
	StateValues.set(player, MatchState.COMBAT_LOCKED, nil)
	StateValues.set(player, Teams.ATTRIBUTE, nil)
	WeaponService.disarm(player)
	player.RespawnLocation = nil
	PlayZone.set(player, "Lobby")
	-- the load yields: it must not die with the runner when the match is torn down meanwhile
	onHostThread(function()
		CharacterService.spawn(player)
	end)
end

-- Sends a pad duel's players back to the lobby and removes the duel.
local function teardown(entry: Running)
	if entry.ending then
		return
	end
	entry.ending = true
	if entry.context then
		entry.context.alive = false
	end
	for _, player in entry.players do
		if player.Parent == Players and PlayZone.matchId(player) == entry.id then
			sendHome(entry, player)
		end
	end
	-- Stops every thread and connection the match started.
	entry.runner:Destroy()
	Spectated.forget(entry.id)
	-- Its bots and their stand-ins (shared folders, marked with the match id).
	for _, holder in
		{
			workspace:FindFirstChild("Dummies"),
			game:GetService("ServerStorage"):FindFirstChild("BotOwners"),
		}
	do
		if holder then
			for _, child in holder:GetChildren() do
				if child:GetAttribute("MatchId") == entry.id then
					child:Destroy()
				end
			end
		end
	end
	task.delay(1, function()
		if entry.world then
			entry.world:Destroy()
		end
		if entry.stateFolder then
			entry.stateFolder:Destroy()
		end
		usedSlots[entry.slot] = nil
	end)
	running[entry.id] = nil
	print(`[MatchHost] pad duel {entry.id} ended`)
end

-- Starts a pad duel in this lobby server. `teams`: the players on each side (real players only).
-- `bots`: fill empty seats with bots (only the Studio solo test does; pads are real players only).
-- Builds and starts one match instance in this Lobby server (a pad duel, or a hosted queued match).
local function launchInstance(
	plan: Plan,
	players: { Player },
	hosted: boolean,
	noRematch: boolean?
): Running
	local id = plan.matchId
	local mode = plan.mode
	local slot = freeSlot()
	local stateFolder = MatchState.createFolder(folder(ReplicatedStorage, MatchState.MATCHES), id)
	local world = folder(folder(workspace, "Matches"), id)
	local entry: Running = {
		id = id,
		runner = nil :: any,
		stateFolder = stateFolder,
		world = world,
		slot = slot,
		players = players,
		context = nil,
		ownsServer = false,
		ending = false,
		hosted = hosted,
		plan = plan,
	}
	running[id] = entry
	specs[id] = {
		stateFolder = stateFolder,
		context = {
			id = id,
			ownsServer = false,
			padDuel = true,
			mapOrigin = arenaOrigin(slot),
			world = world,
			plan = plan,
			players = players,
			finish = function(_finished: { Player })
				onHostThread(function()
					teardown(entry)
				end)
			end,
			sendHome = function(player: Player)
				if PlayZone.matchId(player) == id then
					sendHome(entry, player)
				end
			end,
			hosted = hosted,
			noRematch = noRematch == true,
			requeue = function(player: Player, requeueMode: string)
				onHostThread(function()
					for _, fn in requeueHooks do
						task.spawn(fn, player, requeueMode)
					end
				end)
			end,
		},
	}
	-- The players join the match before the runner starts, so it finds them and their clients bind to it.
	for _, p in players do
		PlayZone.set(p, "Match", id)
	end
	entry.runner = launchRunner(id)
	print(
		`[MatchHost] {if hosted then "hosted match" else "pad duel"} {id} ({mode}, {#players} players) in slot {slot}`
	)
	return entry
end

function MatchHost.startDuel(
	mode: string,
	teamSize: number,
	teams: { { Player } },
	bots: boolean?,
	noRematch: boolean?
): string?
	if not ServerRole.isLobby() or ServerRole.isHosted() then
		return nil -- a hosted server's duels area is caged
	end
	local id = string.sub(HttpService:GenerateGUID(false), 1, 8)
	local players: { Player } = {}
	local ids: { { number } } = { {}, {} }
	for t, team in teams do
		for _, p in team do
			table.insert(players, p)
			table.insert(ids[t], p.UserId)
		end
	end
	local plan: Plan =
		{ matchId = id, mode = mode, size = teamSize, teams = ids, bots = bots == true }
	launchInstance(plan, players, false, noRematch)
	return id
end

-- Hosted: the queued match's plan (the first arrival's TeleportData, or the Studio HostedTest switch).
local hostedEntry: Running? = nil

-- The Lobby's TeleportData contract (same checks as Bots/MatchPlan.validate, which only loads inside a match):
-- { v = 1, matchId, mode, teams = { { userId }, { userId } }, bots }. TeleportData travels through the client:
-- shape and sizes only, nothing here grants anything.
local MAX_ID = 64
local function userIds(value: unknown, size: number, seen: { [number]: boolean }): { number }?
	if typeof(value) ~= "table" then
		return nil
	end
	local list: { number } = {}
	local count = 0
	for k, v in value :: { [unknown]: unknown } do
		count += 1
		if typeof(k) ~= "number" or typeof(v) ~= "number" then
			return nil
		end
		local id = v :: number
		if id ~= id or id <= 0 or id ~= math.floor(id) or id > 2 ^ 53 or seen[id] then
			return nil
		end
		seen[id] = true
		table.insert(list, id)
	end
	if count ~= #list or count > size then
		return nil
	end
	return list
end

local function validatePlan(data: unknown): Plan?
	if typeof(data) ~= "table" then
		return nil
	end
	local d = data :: { [string]: unknown }
	local matchId, mode, bots = d.matchId, d.mode, d.bots
	if d.v ~= 1 or typeof(matchId) ~= "string" or #matchId == 0 or #matchId > MAX_ID then
		return nil
	end
	if typeof(mode) ~= "string" or typeof(bots) ~= "boolean" then
		return nil
	end
	local size = BotsConfig.MODES[mode]
	local teams = d.teams
	if not size or typeof(teams) ~= "table" or #(teams :: { unknown }) ~= 2 then
		return nil
	end
	local seen: { [number]: boolean } = {}
	local one = userIds((teams :: any)[1], size, seen)
	local two = userIds((teams :: any)[2], size, seen)
	if not one or not two then
		return nil
	end
	return { matchId = matchId, mode = mode, size = size, teams = { one, two }, bots = bots }
end

local function planFor(player: Player): Plan?
	local test = workspace:GetAttribute(ServerRole.HOSTED_TEST)
	if game:GetService("RunService"):IsStudio() and typeof(test) == "string" then
		local size = BotsConfig.MODES[test]
		if size then
			return {
				matchId = "hosted-studio",
				mode = test,
				size = size,
				teams = { { player.UserId }, {} },
				bots = true,
			}
		end
	end
	local ok, joinData = pcall(function()
		return player:GetJoinData()
	end)
	if not ok or typeof(joinData) ~= "table" then
		return nil
	end
	if joinData.SourceGameId ~= game.GameId or joinData.SourcePlaceId ~= game.PlaceId then
		return nil
	end
	return validatePlan((joinData :: any).TeleportData)
end

local function listed(plan: Plan, userId: number): boolean
	return table.find(plan.teams[1], userId) ~= nil or table.find(plan.teams[2], userId) ~= nil
end

-- A player arriving in a hosted server: the first one with a plan starts the match; a listed player joins it
-- (late arrivals take their seat back from a bot); anyone else just walks the lobby.
local function hostedArrival(player: Player)
	local entry = hostedEntry
	if not entry then
		local plan = planFor(player)
		if not plan or not listed(plan, player.UserId) then
			-- Walks this reserved server's lobby instead of playing: say so, it reads as "the map never loaded".
			HealthLog.problem(
				"hosted arrival without a plan",
				player,
				if plan then "not listed" else "no TeleportData"
			)
			return
		end
		-- Listed players who got here first without a plan of their own (a lost TeleportData) play too.
		local players = { player }
		for _, other in Players:GetPlayers() do
			if
				other ~= player
				and listed(plan, other.UserId)
				and PlayZone.get(other) == "Lobby"
			then
				table.insert(players, other)
			end
		end
		-- Onboarding_v3 "Match 1 server reached" (Telemetry holds it until the save loads, and only counts it
		-- before match 1)
		for _, p in players do
			Telemetry.onboardingV3(p, Telemetry.V3.M1_ARRIVED, "teleport")
		end
		hostedEntry = launchInstance(plan, players, true)
		return
	end
	if entry.ending or not entry.plan or not listed(entry.plan, player.UserId) then
		HealthLog.problem(
			"hosted arrival not seated",
			player,
			if entry.ending then "match already ending" else "not listed"
		)
		return
	end
	if table.find(entry.players, player) then
		return
	end
	table.insert(entry.players, player)
	Telemetry.onboardingV3(player, Telemetry.V3.M1_ARRIVED, "teleport")
	PlayZone.set(player, "Match", entry.id)
	if entry.context then
		entry.context.addPlayer(player)
	end
end

local function startPractice()
	local id = MatchHost.PRACTICE_ID
	local stateFolder = MatchState.createFolder(folder(ReplicatedStorage, MatchState.MATCHES), id)
	local world = folder(folder(workspace, "Matches"), id)
	local entry: Running = {
		id = id,
		runner = nil :: any,
		stateFolder = stateFolder,
		world = world,
		slot = 0,
		players = {},
		context = nil,
		ownsServer = false,
		ending = false,
		practice = true,
	}
	running[id] = entry
	specs[id] = {
		stateFolder = stateFolder,
		only = MatchHost.PRACTICE_SERVICES,
		context = {
			id = id,
			ownsServer = false,
			padDuel = false,
			mapOrigin = Vector3.zero,
			world = world,
			plan = nil,
			players = {},
			finish = nil,
		},
	}
	-- In and out of the range: in and out of the practice context.
	PlayZone.changed:Connect(function(player: Player)
		local context = entry.context
		if PlayZone.get(player) == "Range" then
			if context then
				context.addPlayer(player)
			else
				practiceWaiting[player] = true
			end
		else
			practiceWaiting[player] = nil
			if context then
				if context.owns(player) and entry.cleanPlayer then
					entry.cleanPlayer(player)
				end
				context.removePlayer(player)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		practiceWaiting[player] = nil
	end)
	entry.runner = launchRunner(id)
end

-- Matches running in this lobby server now (pad duels; not the range, not one that is ending). watchLoad logs
-- it when the server runs slow.
function MatchHost.activeDuels(): number
	local n = 0
	for _, r in running do
		if not r.practice and not r.ending and not r.ownsServer then
			n += 1
		end
	end
	return n
end

-- Live load check (2026-11-26): with matches running, a server whose frame rate drops logs it with the match
-- count, so the cap is tuned from real servers (Studio can't measure this: server and client share one PC).
local SLOW_FPS = 45
local LOAD_WINDOW = 30 -- seconds per check
local function watchLoad()
	local frames, since = 0, os.clock()
	RunService.Heartbeat:Connect(function()
		frames += 1
	end)
	while true do
		task.wait(LOAD_WINDOW)
		local now = os.clock()
		local fps = frames / math.max(now - since, 0.001)
		frames, since = 0, now
		local duels = MatchHost.activeDuels()
		if duels > 0 and fps < SLOW_FPS then
			HealthLog.problem(
				"server slow",
				nil,
				string.format("%d matches, %d players, %.0f fps", duels, #Players:GetPlayers(), fps)
			)
		end
	end
end

function MatchHost.init()
	hostSignal.Event:Connect(function()
		while #hostJobs > 0 do
			task.spawn(table.remove(hostJobs, 1) :: () -> ())
		end
	end)
	folder(ReplicatedStorage, MatchState.MATCHES)
	-- Hide all staged release templates in both roles. The live arena is a
	-- clone, so no edit-position map can overlap it or cast shadows onto it.
	local templates = folder(ServerStorage, "Maps")
	for _, entry in MatchConfig.MAPS do
		local model = workspace:FindFirstChild(entry.id)
		if model and model:IsA("Model") then
			if templates:FindFirstChild(entry.id) then
				model:Destroy()
			else
				model.Parent = templates
			end
		end
	end
end

function MatchHost.start()
	if ServerRole.isLobby() and not ServerRole.isHosted() then
		task.spawn(watchLoad)
	end
	if ServerRole.isMatch() then
		-- The whole server is one match (a reserved match server, or the retired match place).
		local id = "server"
		local legacy = MatchState.createFolder(ReplicatedStorage, MatchState.FOLDER)
		running[id] = {
			id = id,
			runner = nil :: any,
			stateFolder = nil,
			world = nil,
			slot = 0,
			players = {},
			context = nil,
			ownsServer = true,
			ending = false,
		}
		specs[id] = {
			stateFolder = legacy,
			context = {
				id = id,
				ownsServer = true,
				padDuel = false,
				mapOrigin = arenaOrigin(1),
				world = workspace,
				plan = nil,
				players = {},
				finish = nil,
			},
		}
		running[id].runner = launchRunner(id)
		return
	end
	startPractice()
	if ServerRole.isHosted() then
		Players.PlayerAdded:Connect(hostedArrival)
		for _, p in Players:GetPlayers() do
			task.spawn(hostedArrival, p)
		end
	end
	-- Pad duels whose players have all gone end themselves.
	while true do
		task.wait(1)
		local now = os.clock()
		for _, entry in running do
			if entry.ownsServer or entry.ending or entry.practice then
				continue
			end
			local anyone = false
			for _, p in entry.players do
				if p.Parent == Players and PlayZone.matchId(p) == entry.id then
					anyone = true
					break
				end
			end
			if anyone then
				entry.emptySince = nil
			elseif not entry.emptySince then
				entry.emptySince = now
			elseif
				now - entry.emptySince > (if entry.hosted then HOSTED_EMPTY_GRACE else EMPTY_GRACE)
			then
				teardown(entry)
			end
		end
	end
end

return MatchHost
