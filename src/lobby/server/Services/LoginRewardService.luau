--!strict
-- Daily login rewards (vault/01 Design/Shop Economy and Art v1.md; Config/Economy.LOGIN).
--   LoginClaim (client -> server): no arguments
--   LoginEvent (server -> that client): { kind = "claimed", step, coins?, tickets?, item? }
--                                     | { kind = "failed", text }
-- The day (server UTC), the step and the grant are all decided inside one PlayerDataService
-- write, which also marks the day claimed, so two claims can never both pay.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Lobby.Config)
local LobbyNet = require(ReplicatedStorage.Lobby.LobbyNet)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Inventory = require(ReplicatedStorage.Shared.Config.Inventory)
local LoginRewards = require(ReplicatedStorage.Shared.LoginRewards)
local RateLimit = require(ReplicatedStorage.Shared.Util.RateLimit)
local PlayerDataService = require(script.Parent.PlayerDataService)
local Telemetry = require(script.Parent.Parent.Telemetry)

local LoginRewardService = {}

local limiter = RateLimit.new(Config.RATE)
local loginEvent: RemoteEvent

local REASON_TEXT: { [string]: string } = {
	claimed = "Already claimed today. Come back tomorrow!",
	busy = "Still saving, try again",
	saving = "Couldn't save right now, try again",
	update = "Rejoin to claim your reward",
}

local function fail(player: Player, why: string)
	loginEvent:FireClient(
		player,
		{ kind = "failed", text = REASON_TEXT[why] or REASON_TEXT.saving }
	)
end

local function onClaim(player: Player)
	if not limiter:allow(player, "LoginClaim") then
		return
	end
	-- cheap refusal from the loaded copy; the real check is inside the write
	local known = PlayerDataService.get(player)
	if not known then
		fail(player, "saving")
		return
	end
	if not LoginRewards.nextStep(known.login, Economy.day(os.time())) then
		fail(player, "claimed")
		return
	end
	local claimedStep: number? = nil
	local ok, why = PlayerDataService.transact(player, PlayerDataService.newTxId(), function(data)
		claimedStep = nil
		local today = Economy.day(os.time())
		local step = LoginRewards.nextStep(data.login, today)
		if not step then
			return false, "claimed"
		end
		local reward = Economy.LOGIN[step]
		data.coins = math.min(data.coins + (reward.coins or 0), Inventory.MAX_COINS)
		data.tickets = math.min(data.tickets + (reward.tickets or 0), Economy.MAX_TICKETS)
		local itemId = reward.item
		local def = if itemId then Inventory.ITEMS[itemId] else nil
		if itemId and def then
			data.items[itemId] = math.min((data.items[itemId] or 0) + 1, def.maxStack)
		end
		data.login = { last = today, step = step }
		claimedStep = step
		return true
	end)
	local step = claimedStep
	if ok and step then
		Telemetry.event(player, "Login reward claimed", 1, tostring(step))
		local reward = Economy.LOGIN[step]
		loginEvent:FireClient(player, {
			kind = "claimed",
			step = step,
			coins = reward.coins,
			tickets = reward.tickets,
			item = reward.item,
		})
	elseif not ok then
		fail(player, why or "saving")
	end
end

function LoginRewardService.init() end

function LoginRewardService.start()
	loginEvent = LobbyNet.event("LoginEvent")
	LobbyNet.event("LoginClaim").OnServerEvent:Connect(onClaim)
	Players.PlayerRemoving:Connect(function(player)
		limiter:forget(player)
	end)
end

return LoginRewardService
