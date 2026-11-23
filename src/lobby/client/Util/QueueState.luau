--!strict
-- The local player's queue state, read from the server-owned attributes
-- (Lobby/LobbyNet), plus the two requests a client may send. The server decides
-- everything; this only reads and asks.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateValues = require(ReplicatedStorage.Shared.StateValues)

local Config = require(ReplicatedStorage.Lobby.Config)
local LobbyNet = require(ReplicatedStorage.Lobby.LobbyNet)

local QueueState = {}

local player = Players.LocalPlayer
local listeners: { () -> () } = {}
local queued = false

local function num(v: any): number?
	if typeof(v) == "number" and v == v then
		return v
	end
	return nil
end

-- "idle" | "searching" | "found" | "teleporting"
function QueueState.status(): string
	local v = StateValues.get(player, "QueueStatus")
	return if typeof(v) == "string" then v else "idle"
end

function QueueState.mode(): string?
	local v = StateValues.get(player, "QueueMode")
	return if typeof(v) == "string" then v else nil
end

-- How a mode reads on screen: `short` for the bar's circle ("2V2"), else its title
-- ("BEGINNER 2V2"). Unknown ids are shown upper-cased.
function QueueState.label(mode: string?, short: boolean?): string
	local info = Config.MODE_BY_ID[mode or ""]
	if not info then
		return string.upper(mode or "")
	end
	if short then
		return `{info.teamSize}V{info.teamSize}`
	end
	return info.title
end

function QueueState.elapsed(): number
	local since = num(StateValues.get(player, "QueueSince"))
	return if since then math.max(0, workspace:GetServerTimeNow() - since) else 0
end

function QueueState.startsIn(): number
	local at = num(StateValues.get(player, "QueueStartsAt"))
	return if at then math.max(0, at - workspace:GetServerTimeNow()) else 0
end

function QueueState.count(mode: string): number
	return num(StateValues.get(LobbyNet.folder, LobbyNet.countAttribute(mode))) or 0
end

-- Seconds before bots fill the mode you're searching (Beginner 2v2 has its own).
function QueueState.botFillAfter(): number
	local info = Config.MODE_BY_ID[QueueState.mode() or ""]
	if info and info.fillAfter then
		local studio = game:GetService("RunService"):IsStudio()
		return if studio then info.fillAfterStudio or info.fillAfter else info.fillAfter
	end
	return num(StateValues.get(LobbyNet.folder, "BotFillAfter")) or Config.botFillAfter
end

-- Roblox party (server values from Matchmaking/Parties): solo players
-- lead themselves; in a party only the leader starts a search.
function QueueState.inParty(): boolean
	return typeof(StateValues.get(player, "PartyKey")) == "string"
end

function QueueState.isLeader(): boolean
	return StateValues.get(player, "PartyLeader") ~= false
end

function QueueState.join(mode: string)
	LobbyNet.event("QueueRequest"):FireServer("join", mode)
end

function QueueState.leave()
	LobbyNet.event("QueueRequest"):FireServer("leave")
end

-- Calls `cb` (deferred, once per batch of state changes) on any change.
function QueueState.onChanged(cb: () -> ())
	table.insert(listeners, cb)
end

local function fire()
	if queued then
		return
	end
	queued = true
	task.defer(function()
		queued = false
		for _, cb in listeners do
			task.spawn(cb)
		end
	end)
end

for _, name in
	{ "QueueStatus", "QueueMode", "QueueSince", "QueueStartsAt", "PartyKey", "PartyLeader" }
do
	StateValues.changed(player, name):Connect(fire)
end
StateValues.anyChanged(LobbyNet.folder):Connect(fire)

return QueueState
