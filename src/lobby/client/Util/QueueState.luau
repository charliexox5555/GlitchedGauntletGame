--!strict
-- The local player's queue state, read from the server-owned attributes
-- (Lobby/LobbyNet), plus the two requests a client may send. The server decides
-- everything; this only reads and asks.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
	local v = player:GetAttribute("QueueStatus")
	return if typeof(v) == "string" then v else "idle"
end

function QueueState.mode(): string?
	local v = player:GetAttribute("QueueMode")
	return if typeof(v) == "string" then v else nil
end

function QueueState.elapsed(): number
	local since = num(player:GetAttribute("QueueSince"))
	return if since then math.max(0, workspace:GetServerTimeNow() - since) else 0
end

function QueueState.startsIn(): number
	local at = num(player:GetAttribute("QueueStartsAt"))
	return if at then math.max(0, at - workspace:GetServerTimeNow()) else 0
end

function QueueState.count(mode: string): number
	return num(LobbyNet.folder:GetAttribute(LobbyNet.countAttribute(mode))) or 0
end

function QueueState.botFillAfter(): number
	return num(LobbyNet.folder:GetAttribute("BotFillAfter")) or Config.botFillAfter
end

function QueueState.join(mode: string)
	LobbyNet.event("QueueRequest"):FireServer("join", mode)
end

function QueueState.leave()
	LobbyNet.event("QueueRequest"):FireServer("leave")
end

-- Calls `cb` (deferred, once per batch of attribute changes) on any change.
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

for _, name in { "QueueStatus", "QueueMode", "QueueSince", "QueueStartsAt" } do
	player:GetAttributeChangedSignal(name):Connect(fire)
end
LobbyNet.folder.AttributeChanged:Connect(fire)

return QueueState
