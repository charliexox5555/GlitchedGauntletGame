--!strict
-- Every RemoteEvent in one place. The server creates them (first require on
-- the server); clients wait for them. Payload shapes live in Types.luau.
--
-- Client -> server: Equip, Fire, Reload, PickWeapon (Studio / test mode), Aim (unreliable)
-- Server -> client: WeaponState, HitConfirm, Damaged, Killed, ShotFx (unreliable)
-- Mods (ModService): ModHold, ModUse, ModSteer, ModRecall (client -> server), ModFx (server -> clients),
-- ModReveal (server -> the caster's team only)
-- Dev test panel (DevModService; Studio, test mode or the owner): DevMod (client -> server)
-- Match (DraftService): DraftPick (client -> server), DraftOffer (server -> one client)
-- Spectating (SpectateService): Spectate (client -> server)
-- Final-kill replay (MatchService): Replay (server -> all clients)
-- Match end (MatchEndService): MatchSummary (server -> all clients), MatchChoice (client -> server)
-- Map vote (MapVoteService): MapVote (client -> server)
-- Device marks (DeviceService): Device (client -> server)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RELIABLE = {
	"Equip",
	"Fire",
	"Reload",
	"PickWeapon",
	"WeaponState",
	"HitConfirm",
	"Damaged",
	"Killed",
	"ModHold",
	"ModUse",
	"ModSteer",
	"ModRecall",
	"ModFx",
	"ModSim", -- Server Authority off: a client's own predicted Dash / Updraft events (client -> server)
	"ModSimFx", -- ... relayed to every other client (server -> clients): what to draw
	"ModReveal",
	"DevMod",
	"DraftPick",
	"DraftOffer",
	"Spectate",
	"Replay",
	"MatchSummary",
	"Scoreboard", -- StatsService: client asks (no args), server answers that client
	"CombatReport", -- StatsService: your damage vs your killer, on death
	"MatchChoice",
	"MapVote",
	"Device",
}
local UNRELIABLE = { "Aim", "ShotFx" }

-- Skin preview remote: the match place, in Studio or with Config/SkinPreview LIVE
-- (keep in step with shared/SkinPreview.allowed).
local SkinPreviewConfig = require(script.Parent.Config.SkinPreview)
if
	game.PlaceId == SkinPreviewConfig.PLACE_ID
	and (RunService:IsStudio() or SkinPreviewConfig.LIVE)
then
	table.insert(RELIABLE, SkinPreviewConfig.REMOTE)
end

local FOLDER_NAME = "Remotes"

local folder: Instance
if RunService:IsServer() then
	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing then
		existing:Destroy()
	end
	local f = Instance.new("Folder")
	f.Name = FOLDER_NAME
	for _, name in RELIABLE do
		local r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = f
	end
	for _, name in UNRELIABLE do
		local r = Instance.new("UnreliableRemoteEvent")
		r.Name = name
		r.Parent = f
	end
	f.Parent = ReplicatedStorage
	folder = f
else
	folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
end

local Net = {}

function Net.event(name: string): RemoteEvent
	local r = folder:WaitForChild(name)
	assert(r:IsA("RemoteEvent"), name .. " is not a RemoteEvent")
	return r
end

function Net.unreliable(name: string): UnreliableRemoteEvent
	local r = folder:WaitForChild(name)
	assert(r:IsA("UnreliableRemoteEvent"), name .. " is not an UnreliableRemoteEvent")
	return r
end

return Net
