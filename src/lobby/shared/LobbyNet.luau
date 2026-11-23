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
-- LockerModRequest: (modId, equipped) -> client (saved), with state in LockerMods
-- ShopRequest (client -> server): ("buyCase", caseId) | ("openCase", itemId, count?, requestId?) |
--   ("buyDaily", slot) | ("devCoins") |
--   ("devSkins") (Services/ShopService)
-- ShopEvent (server -> one client): ShopEventPayload below
-- SettingsRequest (client -> server): ("save", values) (Services/SettingsService;
--   the saved values come back in the player's "Settings" StringValue)
-- StreakSave (client -> server): ("buy", price) (Services/StreakSaveService; price = the one
--   the popup showed, so a price change never charges more than was shown)
-- ProgressEvent (server -> one client): ProgressEventPayload below (Services/ProgressionService,
--   StreakSaveService)
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

export type CaseReward = { gun: string, line: string, tier: string, name: string }

export type ShopEventPayload = {
	openRequest: number?, -- Backpack case-opening response, including failures
	results: { CaseReward }?, -- one entry per skin granted, in opening order
	ticketsBack: number?,
	kind: "bought" | "opened" | "refunded" | "coins" | "skin" | "robux" | "free" | "failed", -- "skin": a daily shop skin; "robux": a Robux purchase granted; "free": the free daily skin
	item: string?, -- "bought" / "opened": the Config/Inventory item id
	count: number?, -- bought/opened case count, or Tickets returned when refunded
	gun: string?, -- "opened" / "skin": the skin's gun (Config/Weapons id)
	line: string?, -- "opened": the skin line
	tier: string?, -- "opened": Config/Skins tier id
	text: string?, -- the item's name, or a short message
	product: number?, -- "robux": the Config/Products id granted (the YOU GOT popup)
}

export type ProgressEventPayload = {
	kind: "gain" | "saved" | "failed",
	xp: number?, -- "gain": XP this match gave
	levelFrom: number?,
	levelTo: number?,
	streakFrom: number?,
	streakTo: number?,
	lostOffer: number?, -- "gain": a lost streak now on offer
	coins: number?, -- "gain": match coins paid (Config/Economy.MATCH_COINS)
	text: string?, -- "failed": why
}

-- RobuxRequest (client -> server): ("pack", n) | ("bundle", id) | ("item", id, i) | ("daily", slot)
--   | ("starter") | ("case", caseId, 1|3) (Services/RobuxService; answers on ShopEvent)
-- LoginClaim (client -> server): no arguments (Services/LoginRewardService)
-- SkinRequest (client -> server): ({ { line, gun } }) gun skins delivered on demand (Services/SkinStoreService)
-- OnboardingRequest (client -> server): ("favAsked", favorited) | ("seen", bit)
--   (Services/OnboardingService; new-player favorite asks and HUD NEW pops)
-- LoginEvent (server -> one client): LoginEventPayload
export type LoginEventPayload = {
	kind: "claimed" | "failed",
	step: number?, -- "claimed": the step (1..7) just claimed
	coins: number?, -- "claimed": what it gave
	tickets: number?,
	item: string?, -- a Config/Inventory item id
	text: string?, -- "failed": why
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

export type AdminEventPayload = {
	ok: boolean,
	action: string,
	targetUserId: number,
	text: string,
}

local FOLDER_NAME = "LobbyRemotes"
local EVENTS = {
	"QueueRequest",
	"QueueEvent",
	"PartyRequest",
	"PartyEvent",
	"LockerRequest",
	"LockerModRequest",
	"ShopRequest",
	"ShopEvent",
	"CaseShow",
	"SettingsRequest",
	"StreakSave",
	"ProgressEvent",
	"LoginClaim",
	"LoginEvent",
	"RobuxRequest",
	"OnboardingRequest",
	"AdminRequest",
	"AdminEvent",
	"SkinRequest",
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
