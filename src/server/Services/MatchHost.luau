--!strict
-- MatchHost: starts and ends matches (place merge 2026-11-21, vault/04 Tech/Place Merge Plan.md).
--  * Match server (shared/ServerRole): one whole-server match at start, as the match place always ran.
--  * Lobby server: pad duels (PadDuelService), several at once. Each gets an id, its own MatchState folder
--    (ReplicatedStorage.Matches[id]), its own world folder (Workspace.Matches[id]) and a map slot far from the lobby
--    and from the other duels. Its players move to the "Match" PlayZone with that MatchId (their match client
--    starts fresh); when it ends they go back to the lobby with their own avatars and the duel is torn down.
-- Each match runs in its own copy of MatchKit/MatchRunner (see there); KIT_SERVICES are the services it copies.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local MatchState = require(ReplicatedStorage.Shared.MatchState)
local PlayZone = require(ReplicatedStorage.Shared.PlayZone)
local ServerRole = require(ReplicatedStorage.Shared.ServerRole)

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

local SLOT_SPACING = 20000 -- studs along X between pad duel maps (maps are up to ~6,200 across)
local EMPTY_GRACE = 8 -- seconds a pad duel may have none of its players before it's ended

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
	ownsServer: boolean,
	ending: boolean,
	emptySince: number?,
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

-- MatchRunner takes its match's spec once.
function MatchHost.takeSpec(id: string): any
	local spec = specs[id]
	specs[id] = nil
	return spec
end

function MatchHost.started(id: string, context: any)
	local entry = running[id]
	if entry then
		entry.context = context
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
local function sendHome(player: Player)
	PlayZone.set(player, "Lobby")
	WeaponService.disarm(player)
	player.RespawnLocation = nil
	task.spawn(function()
		pcall(function()
			player:LoadCharacter()
		end)
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
			sendHome(player)
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
	end)
	usedSlots[entry.slot] = nil
	running[entry.id] = nil
	print(`[MatchHost] pad duel {entry.id} ended`)
end

-- Starts a pad duel in this lobby server. `teams`: the players on each side (real players only).
-- `bots`: fill empty seats with bots (only the Studio solo test does; pads are real players only).
function MatchHost.startDuel(
	mode: string,
	teamSize: number,
	teams: { { Player } },
	bots: boolean?
): string?
	if not ServerRole.isLobby() then
		return nil
	end
	local id = string.sub(HttpService:GenerateGUID(false), 1, 8)
	local slot = freeSlot()
	local players: { Player } = {}
	local ids: { { number } } = { {}, {} }
	for t, team in teams do
		for _, p in team do
			table.insert(players, p)
			table.insert(ids[t], p.UserId)
		end
	end
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
	}
	running[id] = entry
	local plan: Plan =
		{ matchId = id, mode = mode, size = teamSize, teams = ids, bots = bots == true }
	specs[id] = {
		stateFolder = stateFolder,
		context = {
			id = id,
			ownsServer = false,
			padDuel = true,
			offset = Vector3.new(SLOT_SPACING * slot, 0, 0),
			world = world,
			plan = plan,
			players = players,
			finish = function(_finished: { Player })
				task.defer(teardown, entry)
			end,
			sendHome = function(player: Player)
				if PlayZone.matchId(player) == id then
					if entry.context then
						entry.context.removePlayer(player)
					end
					sendHome(player)
				end
			end,
		},
	}
	-- The players join the match before the runner starts, so it finds them and their clients bind to it.
	for _, p in players do
		PlayZone.set(p, "Match", id)
	end
	entry.runner = launchRunner(id)
	print(`[MatchHost] pad duel {id} ({mode}, {#players} players) in slot {slot}`)
	return id
end

-- Ends a pad duel now (everyone gone, or an admin).
function MatchHost.endDuel(id: string)
	local entry = running[id]
	if entry and not entry.ownsServer then
		teardown(entry)
	end
end

function MatchHost.isRunning(id: string): boolean
	return running[id] ~= nil
end

function MatchHost.init()
	folder(ReplicatedStorage, MatchState.MATCHES)
end

function MatchHost.start()
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
				offset = Vector3.zero,
				world = workspace,
				plan = nil,
				players = {},
				finish = nil,
			},
		}
		running[id].runner = launchRunner(id)
		return
	end
	-- Pad duels whose players have all gone end themselves.
	while true do
		task.wait(1)
		local now = os.clock()
		for _, entry in running do
			if entry.ownsServer or entry.ending then
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
			elseif now - entry.emptySince > EMPTY_GRACE then
				teardown(entry)
			end
		end
	end
end

return MatchHost
