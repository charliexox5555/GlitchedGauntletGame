--!strict
-- Free Rewards (vault/02 Art/Lobby Holograms.md; Config/Economy.GROUP_REWARD): a one-time gift for joining the
-- game's Roblox group, opened from the green lobby hologram (Controllers/FreeRewardsController).
--   GroupRewardClaim (client -> server): no arguments
--   GroupRewardEvent (server -> that client): { kind = "claimed", coins, item } | { kind = "notMember" }
--                                           | { kind = "failed", text }
-- Membership is asked of Roblox here, never taken from the client. IsInGroupAsync can answer from a per-session
-- cache, so a "no" is checked again with GetGroupsAsync (a fresh lookup) for a player who joined mid-session.
-- The grant and buys.group = true happen inside one PlayerDataService write, so two claims can never both pay.
-- "Like the game" is only asked in the popup, never checked or rewarded (platforms prohibit rewarding ratings).

local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Lobby.Config)
local LobbyNet = require(ReplicatedStorage.Lobby.LobbyNet)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Inventory = require(ReplicatedStorage.Shared.Config.Inventory)
local RateLimit = require(ReplicatedStorage.Shared.Util.RateLimit)
local PlayerDataService = require(script.Parent.PlayerDataService)
local Telemetry = require(script.Parent.Parent.Telemetry)

local GroupRewardService = {}

local REWARD = Economy.GROUP_REWARD
local limiter = RateLimit.new(Config.RATE)
local rewardEvent: RemoteEvent
local busy: { [Player]: boolean } = {}

local REASON_TEXT: { [string]: string } = {
	claimed = "You already claimed this gift",
	busy = "Still saving, try again",
	saving = "Couldn't save right now, try again",
	update = "Rejoin to claim your gift",
	roblox = "Roblox didn't answer, try again in a moment",
}

local function fail(player: Player, why: string)
	rewardEvent:FireClient(
		player,
		{ kind = "failed", text = REASON_TEXT[why] or REASON_TEXT.saving }
	)
end

-- true / false, or nil when Roblox didn't answer
local function isMember(player: Player): boolean?
	local ok, member = pcall(function()
		return player:IsInGroupAsync(REWARD.group)
	end)
	if ok and member == true then
		return true
	end
	local fresh, groups = pcall(function()
		return GroupService:GetGroupsAsync(player.UserId)
	end)
	if fresh and typeof(groups) == "table" then
		for _, g in groups do
			if typeof(g) == "table" and g.Id == REWARD.group then
				return true
			end
		end
		return false
	end
	return if ok then false else nil
end

local function onClaim(player: Player)
	if not limiter:allow(player, "GroupRewardClaim") or busy[player] then
		return
	end
	-- cheap refusal from the loaded copy; the real check is inside the write
	local known = PlayerDataService.get(player)
	if not known then
		fail(player, "saving")
		return
	end
	if known.buys.group then
		fail(player, "claimed")
		return
	end
	busy[player] = true
	local member = isMember(player)
	if member == nil then
		busy[player] = nil
		fail(player, "roblox")
		return
	elseif not member then
		busy[player] = nil
		rewardEvent:FireClient(player, { kind = "notMember" })
		return
	end
	local ok, why = PlayerDataService.transact(player, PlayerDataService.newTxId(), function(data)
		if data.buys.group then
			return false, "claimed"
		end
		data.coins = math.min(data.coins + REWARD.coins, Inventory.MAX_COINS)
		local def = Inventory.ITEMS[REWARD.item]
		if def then
			data.items[REWARD.item] = math.min((data.items[REWARD.item] or 0) + 1, def.maxStack)
		end
		data.buys.group = true
		return true
	end)
	busy[player] = nil
	if not player.Parent then
		return
	end
	if ok then
		Telemetry.event(player, "Group reward claimed", 1)
		rewardEvent:FireClient(
			player,
			{ kind = "claimed", coins = REWARD.coins, item = REWARD.item }
		)
	else
		fail(player, why or "saving")
	end
end

function GroupRewardService.init() end

function GroupRewardService.start()
	rewardEvent = LobbyNet.event("GroupRewardEvent")
	LobbyNet.event("GroupRewardClaim").OnServerEvent:Connect(onClaim)
	Players.PlayerRemoving:Connect(function(player)
		limiter:forget(player)
		busy[player] = nil
	end)
end

return GroupRewardService
