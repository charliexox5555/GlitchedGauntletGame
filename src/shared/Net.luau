--!strict
-- Every RemoteEvent in one place. The server creates them (first require on
-- the server); clients wait for them. Payload shapes live in Types.luau.
--
-- Client -> server: Equip, Fire, Reload, PickWeapon (Studio / test mode), Aim (unreliable)
-- Server -> client: WeaponState, HitConfirm, Damaged, Killed, ShotFx (unreliable)
-- Mods (ModService): ModHold, ModUse, ModSteer (client -> server), ModFx (server -> clients),
-- ModReveal (server -> the caster's team only)
-- Dev test panel (DevModService, Studio / owner only): DevMod (both ways)

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
	"ModFx",
	"ModReveal",
	"DevMod",
}
local UNRELIABLE = { "Aim", "ShotFx" }

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
