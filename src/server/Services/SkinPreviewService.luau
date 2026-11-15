--!strict
-- Skin preview requests (Config/SkinPreview): each player picks the skin line
-- for their own guns. The server keeps the choice in that player's attribute
-- (clients can't write it), so their camera guns and the world gun everyone
-- sees follow it. Cosmetic only: no inventory, loadout, purchase or saving.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config.SkinPreview)
local Preview = require(Shared.SkinPreview)
local Net = require(Shared.Net)
local RateLimit = require(Shared.Util.RateLimit)

local SkinPreviewService = {}

local limiter = RateLimit.new({ [Config.REMOTE] = Config.RATE })

function SkinPreviewService.init() end

function SkinPreviewService.start()
	if not Preview.allowed() then
		return
	end
	Preview.watch()
	local function setup(player: Player)
		if Preview.canUse(player) then
			player:SetAttribute(Config.ATTRIBUTE, "Stock")
		end
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
