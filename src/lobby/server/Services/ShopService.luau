--!strict
-- Buying from the Shop (vault/01 Design/Inventory and Crates.md). Now: cases
-- for coins, which go into the player's inventory unopened. Robux purchases
-- (developer products, ProcessReceipt) come next; opening cases is not built.
--
-- ShopRequest (client -> server):
--   ("buyCase", caseId)  pay the case's coin price, +1 of its inventory item
--   ("devCoins")         Studio only: + Inventory.STUDIO_GRANT coins
-- ShopEvent (server -> that client): ShopEventPayload in LobbyNet.
--
-- The client sends only what it wants; the price, the item and the balance
-- check all come from the server's own tables and the stored save, inside one
-- atomic write (PlayerDataService.transact). Type-checked and rate-limited.
-- Cases are paid random items (coins can be bought with Robux), so players
-- where PolicyService restricts them can't buy (failed check = restricted).

local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Lobby.Config)
local Inventory = require(ReplicatedStorage.Shared.Config.Inventory)
local LobbyNet = require(ReplicatedStorage.Lobby.LobbyNet)
local RateLimit = require(ReplicatedStorage.Shared.Util.RateLimit)
local ShopCatalog = require(ReplicatedStorage.Lobby.ShopCatalog)
local PlayerDataService = require(script.Parent.PlayerDataService)

local ShopService = {}

local limiter = RateLimit.new(Config.RATE)
local rejects: { [string]: number } = {}
local restricted: { [Player]: boolean } = {}
local shopEvent: RemoteEvent

local REASON_TEXT: { [string]: string } = {
	coins = "Not enough coins",
	full = "Your Backpack can't hold more of those",
	busy = "Still finishing your last purchase",
	saving = "Couldn't reach your save, try again",
	update = "The game updated, rejoin to keep buying",
	invalid = "Purchase failed",
	slow = "Slow down a little",
}

local function reject(reason: string)
	rejects[reason] = (rejects[reason] or 0) + 1
end

local function send(player: Player, payload: LobbyNet.ShopEventPayload)
	if player.Parent then
		shopEvent:FireClient(player, payload)
	end
end

-- Fail closed: a check that errors counts as restricted, and isn't cached so
-- the next try asks again.
local function casesRestricted(player: Player): boolean
	local known = restricted[player]
	if known ~= nil then
		return known
	end
	local ok, info = pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, player)
	if not ok or typeof(info) ~= "table" then
		return true
	end
	local value = (info :: any).ArePaidRandomItemsRestricted
	local isRestricted = value ~= false
	if player.Parent then
		restricted[player] = isRestricted
	end
	return isRestricted
end

local function buyCase(player: Player, caseId: string)
	local case = ShopCatalog.case(caseId)
	local itemId = Inventory.BY_CASE[caseId]
	local def = if itemId then Inventory.ITEMS[itemId] else nil
	if not case or not def or def.retired or case.coins <= 0 then
		reject("badCase")
		return
	end
	if casesRestricted(player) then
		send(player, { kind = "failed", text = "Cases aren't available where you are" })
		return
	end
	local price = case.coins
	-- Cheap refusals from the loaded copy, so a click that can't succeed costs
	-- no DataStore request. The real check is inside the write.
	local known = PlayerDataService.get(player)
	if known and known.coins < price then
		send(player, { kind = "failed", text = REASON_TEXT.coins })
		return
	end
	if known and (known.items[def.id] or 0) >= def.maxStack then
		send(player, { kind = "failed", text = REASON_TEXT.full })
		return
	end
	if not limiter:allow(player, "ShopWrite") then
		send(player, { kind = "failed", text = REASON_TEXT.slow })
		return
	end
	local ok, why = PlayerDataService.transact(player, PlayerDataService.newTxId(), function(data)
		if data.coins < price then
			return false, "coins"
		end
		local held = data.items[def.id] or 0
		if held >= def.maxStack then
			return false, "full"
		end
		data.coins -= price
		data.items[def.id] = held + 1
		return true
	end)
	if ok then
		send(player, { kind = "bought", item = def.id, count = 1, text = def.name })
	else
		send(player, { kind = "failed", text = REASON_TEXT[why or ""] or "Purchase failed" })
	end
end

local function devCoins(player: Player)
	if not RunService:IsStudio() then
		reject("devOutsideStudio")
		return
	end
	if not limiter:allow(player, "ShopWrite") then
		send(player, { kind = "failed", text = REASON_TEXT.slow })
		return
	end
	local grant = Inventory.STUDIO_GRANT
	local ok, why = PlayerDataService.transact(player, PlayerDataService.newTxId(), function(data)
		data.coins = math.min(data.coins + grant, Inventory.MAX_COINS)
		return true
	end)
	send(
		player,
		if ok
			then { kind = "coins", text = `+{grant} coins (Studio)` }
			else {
				kind = "failed",
				text = REASON_TEXT[why or ""] or "Couldn't add coins",
			}
	)
end

local function onRequest(player: Player, action: unknown, arg: unknown)
	if not limiter:allow(player, "ShopRequest") then
		reject("rate")
		return
	end
	if typeof(action) ~= "string" then
		reject("badAction")
		return
	end
	if action == "buyCase" then
		if typeof(arg) ~= "string" or #arg > 24 then
			reject("badArgs")
			return
		end
		buyCase(player, arg :: string)
	elseif action == "devCoins" then
		devCoins(player)
	else
		reject("badAction")
	end
end

function ShopService.init() end

function ShopService.start()
	shopEvent = LobbyNet.event("ShopEvent")
	LobbyNet.event("ShopRequest").OnServerEvent:Connect(onRequest)
	Players.PlayerRemoving:Connect(function(p)
		limiter:forget(p)
		restricted[p] = nil
	end)
	while true do
		task.wait(Config.rejectLogInterval)
		if next(rejects) then
			local parts = {}
			for reason, n in rejects do
				table.insert(parts, `{reason}={n}`)
			end
			warn(
				`[Shop] rejected ShopRequest in the last {Config.rejectLogInterval} s: {table.concat(
					parts,
					", "
				)}`
			)
			table.clear(rejects)
		end
	end
end

return ShopService
