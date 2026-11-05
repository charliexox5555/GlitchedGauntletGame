--!strict
-- Lobby remotes, in their own ReplicatedStorage folder ("LobbyRemotes") so they
-- never clash with Shared/Net's match "Remotes". The server creates them; clients wait.
--
-- QueueRequest (client -> server): ("join", mode) | ("leave")
-- QueueEvent (server -> one client): a one-shot moment (QueueEventPayload below)
--
-- Live state is on attributes the server owns:
--   Player:  QueueStatus ("idle" | "searching" | "found" | "teleporting"),
--            QueueMode, QueueSince / QueueStartsAt (workspace:GetServerTimeNow())
--   LobbyRemotes folder: Queued1v1 / Queued2v2 / Queued3v3 (players searching per mode;
--            world signs can read these too)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

export type QueueEventPayload = {
	kind: "found" | "failed" | "studio" | "info",
	mode: string?,
	teams: { { number } }?, -- userIds per team ("found")
	teamSize: number?,
	startsAt: number?, -- server time of the teleport ("found")
	text: string?, -- "failed" / "info" message
	payload: string?, -- "studio": the TeleportData JSON it would send
}

local FOLDER_NAME = "LobbyRemotes"
local EVENTS = { "QueueRequest", "QueueEvent" }

local folder: Instance
if RunService:IsServer() then
	-- Reuse a folder that already exists (a second require must never swap the
	-- live remotes out from under the running handlers).
	local f = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if not f then
		f = Instance.new("Folder")
		f.Name = FOLDER_NAME
		f.Parent = ReplicatedStorage
	end
	for _, name in EVENTS do
		if not f:FindFirstChild(name) then
			local r = Instance.new("RemoteEvent")
			r.Name = name
			r.Parent = f
		end
	end
	folder = f
else
	folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
end

local LobbyNet = {}

LobbyNet.folder = folder

function LobbyNet.event(name: string): RemoteEvent
	local r = folder:WaitForChild(name)
	assert(r:IsA("RemoteEvent"), name .. " is not a RemoteEvent")
	return r
end

function LobbyNet.countAttribute(mode: string): string
	return "Queued" .. mode
end

return LobbyNet
