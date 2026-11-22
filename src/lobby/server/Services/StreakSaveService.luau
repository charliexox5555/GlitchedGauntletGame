--!strict
-- The coin streak save (vault/01 Design/Progression.md). After a lost streak of 3 or more
-- the save holds an offer (Shared/Progress `prog.lost`) for 15 minutes; the lobby's
-- SAVE WINSTREAK button opens a popup that buys it back for coins.
--   StreakSave (client -> server): ("buy", shownPrice)
--   ProgressEvent (server -> that client): { kind = "saved" } | { kind = "failed", text }
-- The price, the timer and the coins are all checked inside one PlayerDataService write;
-- the client's price is only compared, so a price that went up is never charged.
-- The offer itself is on the player: StreakSaveValue / StreakSaveEnds / StreakSavePrice.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Lobby.Config)
local LobbyNet = require(ReplicatedStorage.Lobby.LobbyNet)
local PlayerData = require(ReplicatedStorage.Shared.PlayerData)
local Progress = require(ReplicatedStorage.Shared.Progress)
local RateLimit = require(ReplicatedStorage.Shared.Util.RateLimit)
local PlayerDataService = require(script.Parent.PlayerDataService)

local StreakSaveService = {}

local limiter = RateLimit.new(Config.RATE)
local progressEvent: RemoteEvent
local expiryTimers: { [Player]: thread } = {}

local REASON_TEXT: { [string]: string } = {
	coins = "Not enough coins",
	gone = "This streak can't be saved any more",
	price = "The price changed, try again",
	busy = "Still saving, try again",
	saving = "Couldn't save right now, try again",
	update = "Rejoin to save your streak",
}

local function fail(player: Player, why: string)
	progressEvent:FireClient(
		player,
		{ kind = "failed", text = REASON_TEXT[why] or REASON_TEXT.saving }
	)
end

-- Republish when the offer runs out, so the button goes back to Settings.
local function watchExpiry(player: Player)
	local old = expiryTimers[player]
	if old then
		task.cancel(old)
		expiryTimers[player] = nil
	end
	local data = PlayerDataService.get(player)
	local offer = if data then Progress.offer(data.prog, os.time()) else nil
	if not offer then
		return
	end
	expiryTimers[player] = task.delay(offer.expires - os.time() + 1, function()
		expiryTimers[player] = nil
		if player.Parent == Players then
			local now = PlayerDataService.get(player)
			PlayerData.publishProgress(player, if now then now.prog else nil)
		end
	end)
end

local function onRequest(player: Player, action: unknown, shownPrice: unknown)
	if not limiter:allow(player, "StreakSave") then
		return
	end
	if
		typeof(action) ~= "string"
		or action ~= "buy"
		or typeof(shownPrice) ~= "number"
		or shownPrice ~= shownPrice
		or shownPrice < 0
		or shownPrice > 1e7
	then
		return
	end
	-- Cheap refusals from the loaded copy; the real checks are inside the write.
	local known = PlayerDataService.get(player)
	if not known then
		fail(player, "saving")
		return
	end
	local now = os.time()
	local price = Progress.price(known.prog, now)
	if not price then
		fail(player, "gone")
		return
	end
	if price > shownPrice then
		fail(player, "price")
		return
	end
	if known.coins < price then
		fail(player, "coins")
		return
	end
	local ok, why = PlayerDataService.transact(player, PlayerDataService.newTxId(), function(data)
		local t = os.time()
		local cost = Progress.price(data.prog, t)
		if not cost then
			return false, "gone"
		end
		if cost > shownPrice then
			return false, "price"
		end
		if data.coins < cost then
			return false, "coins"
		end
		data.coins -= cost
		Progress.restore(data.prog, t)
		return true
	end)
	if ok then
		progressEvent:FireClient(player, { kind = "saved" })
	else
		fail(player, why or "saving")
	end
end

function StreakSaveService.init() end

function StreakSaveService.start()
	progressEvent = LobbyNet.event("ProgressEvent")
	LobbyNet.event("StreakSave").OnServerEvent:Connect(onRequest)
	PlayerDataService.changed:Connect(watchExpiry)
	Players.PlayerRemoving:Connect(function(player)
		limiter:forget(player)
		local t = expiryTimers[player]
		if t then
			task.cancel(t)
		end
		expiryTimers[player] = nil
	end)
end

return StreakSaveService
