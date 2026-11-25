--!strict
-- Other players' case openings (vault/01 Design/Case Opening.md): the server's
-- CaseShow (Services/ShopService) plays the in-world opening at that player,
-- quieter and with their name on the card (Util/CaseOpening). Your own opening is
-- started by the Backpack. Skipped when the opener is far away or has no character.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LobbyNet = require(ReplicatedStorage.Lobby.LobbyNet)
local Inventory = require(ReplicatedStorage.Shared.Config.Inventory)
local OpeningConfig = require(ReplicatedStorage.Shared.Config.CaseOpening)
local CaseOpening = require(script.Parent.Parent.Util.CaseOpening)

local CaseShowController = {}

function CaseShowController.start()
	local me = Players.LocalPlayer
	LobbyNet.event("CaseShow").OnClientEvent:Connect(function(p: LobbyNet.CaseShowPayload)
		if typeof(p) ~= "table" or typeof(p.userId) ~= "number" or p.userId == me.UserId then
			return
		end
		if
			(p.count ~= 1 and p.count ~= Inventory.BATCH_OPEN_COUNT)
			or typeof(p.results) ~= "table"
			or #p.results == 0
		then
			return
		end
		local owner = Players:GetPlayerByUserId(p.userId)
		local theirs = owner and owner.Character
		local mine = me.Character
		local a = theirs and theirs:FindFirstChild("HumanoidRootPart")
		local b = mine and mine:FindFirstChild("HumanoidRootPart")
		if not (owner and a and a:IsA("BasePart")) then
			return
		end
		if
			b
			and b:IsA("BasePart")
			and (a.Position - b.Position).Magnitude > OpeningConfig.VIEW_DISTANCE
		then
			return
		end
		local crateTier = if typeof(p.crate) == "number" then p.crate else 1
		local h = CaseOpening.start(owner, crateTier, false, p.count)
		if h then
			h:reveal(p.results)
		end
	end)
end

return CaseShowController
