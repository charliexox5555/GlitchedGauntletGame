--!strict
-- Lobby remotes, in their own ReplicatedStorage folder ("LobbyRemotes") so they
-- never clash with Shared/Net's match "Remotes". The server creates them; clients wait.
--
-- QueueRequest (client -> server): ("join", mode) | ("leave")
-- QueueEvent (server -> one client): a one-shot moment (QueueEventPayload below)
-- PartyRequest (client -> server): ("invite", userId) | ("accept", userId) |
--   ("decline", userId) | ("leave")
-- PartyEvent (server -> one client): PartyEventPayload below
-- LockerRequest (client -> server): ("equip", gunId, line) (Services/LockerService)
-- ShopRequest (client -> server): ("buyCase", caseId) | ("openCase", itemId) | ("devCoins") |
--   ("devSkins") (Services/ShopService)
-- ShopEvent (server -> one client): ShopEventPayload below
-- SettingsRequest (client -> server): ("save", values) (Services/SettingsService;
--   the saved values come back in the player's "Settings" StringValue)
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

export type PartyEventPayload = {
	kind: "invite" | "info",
	from: number?, -- "invite": the inviter's userId
	expiresIn: number?, -- "invite": seconds it stays open
	text: string?, -- "info": a short message
}

export type ShopEventPayload = {
	kind: "bought" | "opened" | "refunded" | "coins" | "failed",
	item: string?, -- "bought" / "opened": the Config/Inventory item id
	count: number?, -- "bought": how many; "refunded": the coins given back
	gun: string?, -- "opened": the skin's gun (Config/Weapons id)
	line: string?, -- "opened": the skin line
	tier: string?, -- "opened": Config/Skins tier id
	text: string?, -- the item's name, or a short message
}

-- CaseShow (server -> each OTHER player): someone opened a case; play it at them
export type CaseShowPayload = {
	userId: number, -- the opener
	crate: number, -- Config/Inventory tier of the case (the crate's colours)
	gun: string,
	line: string,
	tier: string, -- Config/Skins tier id
	text: string, -- the skin's name
}

local FOLDER_NAME = "LobbyRemotes"
local EVENTS = {
	"QueueRequest",
	"QueueEvent",
	"PartyRequest",
	"PartyEvent",
	"LockerRequest",
	"ShopRequest",
	"ShopEvent",
	"CaseShow",
	"SettingsRequest",
}

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
