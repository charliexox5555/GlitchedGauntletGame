--!strict
-- Skin preview requests (Config/SkinPreview): each player picks the skin line
-- for their own guns. The server keeps the choice in that player's attribute
-- (clients can't write it), so their camera guns and the world gun everyone
-- sees follow it. Cosmetic only: no inventory, loadout or purchase.
-- Also loads the skins equipped in the Lobby's Locker (Shared/Locker, one line
-- per gun, saved by the Lobby's LockerService) into a replicated folder;
-- Shared/SkinPreview.line uses them whenever the F7 preview is on Stock.
-- Only OWNED pairs are published (Shared/PlayerData skins, saved by the
-- Lobby); if the ownership read fails, every gun is Stock (fail closed).
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config.SkinPreview)
local Preview = require(Shared.SkinPreview)
local Net = require(Shared.Net)
local RateLimit = require(Shared.Util.RateLimit)
local Locker = require(Shared.Locker)
local PlayerData = require(Shared.PlayerData)

local SkinPreviewService = {}

local limiter = RateLimit.new({ [Config.REMOTE] = Config.RATE })

function SkinPreviewService.init() end

-- Read-only here (the Lobby writes): GetAsync with retry.
local function read(storeName: string, key: string): (boolean, any)
	local store = DataStoreService:GetDataStore(storeName)
	local delay = 1
	for attempt = 1, 3 do
		local ok, data = pcall(function()
			return store:GetAsync(key)
		end)
		if ok then
			return true, data
		end
		warn(`[SkinPreview] {storeName} load failed ({attempt}/3): {data}`)
		if attempt < 3 then
			task.wait(delay)
			delay *= 2
		end
	end
	return false, nil
end

-- The equipped skins, filtered to the ones the player owns, then published.
local function loadLocker(player: Player)
	if RunService:IsStudio() and workspace:GetAttribute("FreshOnboarding") == true then
		return
	end
	local key = Locker.key(player.UserId)
	local okLocker, locker = read(Locker.STORE, key)
	local okOwned, saved = read(PlayerData.STORE, PlayerData.key(player.UserId))
	if player.Parent ~= Players or player:FindFirstChild(Locker.REPLICA) ~= nil then
		return
	end
	local equipped = if okLocker then Locker.clean(locker) else {}
	local cleanSave = if okOwned then PlayerData.clean(saved, true) else nil
	local skins = if cleanSave then cleanSave.skins else {}
	local out: { [string]: string } = {}
	for gunId, line in equipped do
		if PlayerData.owns(skins, gunId, line) then
			out[gunId] = line
		end
	end
	Locker.publish(player, out)
	if not player:FindFirstChild(PlayerData.CHARMS) then
		local charms = if cleanSave then cleanSave.charms else { owned = {}, guns = {} }
		Locker.publish(player, charms :: any, PlayerData.CHARMS)
	end
end

function SkinPreviewService.start()
	if not Preview.allowed() then
		return
	end
	Preview.watch()
	local function setup(player: Player)
		if Preview.canUse(player) then
			StateValues.set(player, Config.ATTRIBUTE, "Stock")
		end
		task.spawn(loadLocker, player)
	end
	Players.PlayerAdded:Connect(setup)
	for _, player in Players:GetPlayers() do
		setup(player)
	end
	-- value: a line name from Config.LINES; anything else is dropped.
	Net.event(Config.REMOTE).OnServerEvent:Connect(function(player: Player, value: unknown)
		if typeof(value) ~= "string" or #value > 32 then
			return
		end
		if not Preview.canUse(player) or not limiter:allow(player, Config.REMOTE) then
			return
		end
		if Preview.valid(value) then -- one of Config.LINES
			StateValues.set(player, Config.ATTRIBUTE, value)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		limiter:forget(player)
	end)
end

return SkinPreviewService
