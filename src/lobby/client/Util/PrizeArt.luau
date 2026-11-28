--!strict
-- The picture and words for a goodie bag prize (Lobby/GoodieBags via LobbyNet.CaseReward `coins` / `tickets` /
-- `item`): the reveal card (Util/BagOpening) and the Backpack's result panel use the same art.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Inventory = require(ReplicatedStorage.Shared.Config.Inventory)
local LobbyNet = require(ReplicatedStorage.Lobby.LobbyNet)
local ShopCatalog = require(ReplicatedStorage.Lobby.ShopCatalog)
local SkinArt = require(ReplicatedStorage.Shared.SkinArt)

local PrizeArt = {}

-- a bag prize that isn't a skin (coins, Tickets or a Backpack item): nothing to equip
function PrizeArt.isLoot(r: LobbyNet.CaseReward): boolean
	return r.coins ~= nil or r.tickets ~= nil or r.item ~= nil
end

function PrizeArt.image(r: LobbyNet.CaseReward): string?
	if r.coins then
		return ShopCatalog.ART.coinStack
	elseif r.tickets then
		return ShopCatalog.ART.ticket
	elseif r.item then
		local def = Inventory.ITEMS[r.item]
		local case = def and def.case and ShopCatalog.case(def.case)
		return (def and def.icon) or (case and case.art) or nil
	elseif r.gun ~= "" then
		return SkinArt.portrait(r.gun, r.line)
	end
	return nil
end

-- the small line over the prize's name
function PrizeArt.kicker(r: LobbyNet.CaseReward): string
	if r.coins then
		return "COINS"
	elseif r.tickets then
		return "TICKETS"
	elseif r.item then
		return "IN YOUR BACKPACK"
	end
	return "NEW SKIN"
end

return PrizeArt
