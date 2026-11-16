--!strict
-- Skin preview requests (Config/SkinPreview): each player picks the skin line
-- for their own guns. The server keeps the choice in that player's attribute
-- (clients can't write it), so their camera guns and the world gun everyone
-- sees follow it. Cosmetic only: no inventory, loadout or purchase.
-- Also loads the skins equipped in the Lobby's Locker (Shared/Locker, one line
-- per gun, saved by the Lobby's LockerService) into a replicated folder;
-- Shared/SkinPreview.line uses them whenever the F7 preview is on Stock.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config.SkinPreview)
local Preview = require(Shared.SkinPreview)
local Net = require(Shared.Net)
local RateLimit = require(Shared.Util.RateLimit)
local Locker = require(Shared.Locker)

local SkinPreviewService = {}

local limiter = RateLimit.new({ [Config.REMOTE] = Config.RATE })

function SkinPreviewService.init() end

-- Read-only here (the Lobby writes): GetAsync with retry, then the attributes.
local function loadLocker(player: Player)
	local store = DataStoreService:GetDataStore(Locker.STORE)
	local delay = 1
	for attempt = 1, 3 do
		local ok, data = pcall(function()
			return store:GetAsync(Locker.key(player.UserId))
		end)
		if ok then
			if player.Parent == Players then
				-- Keep equipped skins off the Player's combat attribute budget.
				local folder = Instance.new("Folder")
				folder.Name = Preview.LOCKER_FOLDER
				for gunId, line in Locker.clean(data) do
					folder:SetAttribute(gunId, line)
				end
				folder.Parent = player
			end
			return
		end
		warn(`[SkinPreview] Locker load failed ({attempt}/3): {data}`)
		task.wait(delay)
		delay *= 2
	end
end

function SkinPreviewService.start()
	if not Preview.allowed() then
		return
	end
	Preview.watch()
	local function setup(player: Player)
		if Preview.canUse(player) then
			player:SetAttribute(Config.ATTRIBUTE, "Stock")
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
			player:SetAttribute(Config.ATTRIBUTE, value)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		limiter:forget(player)
	end)
end

return SkinPreviewService
