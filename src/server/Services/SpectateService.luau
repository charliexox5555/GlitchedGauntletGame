--!strict
-- Spectating (vault/05 Production/Match Structure Revamp.md, phase B). The
-- spectator's client draws the view (SpectateController); the server only
-- streams the target's surroundings to them: `Spectate(target)` sets the
-- spectator's ReplicationFocus to the target's root (LihFolk "Instance
-- Streaming", "Arena Rounds with Teams and Spectating End to End"), nil
-- clears it. Allowed only for a player who is down or not spawned, and only
-- on a teammate, or on anyone during the round end (you watch your killer).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Match)
local Health = require(ReplicatedStorage.Shared.Health)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Net = require(ReplicatedStorage.Shared.Net)
local RateLimit = require(ReplicatedStorage.Shared.Util.RateLimit)
local Teams = require(ReplicatedStorage.Shared.Mods.Teams)

local BotService = require(script.Parent.BotService)

local SpectateService = {}

local limiter = RateLimit.new(Config.RATE)
local watching: { [Player]: Instance } = {} -- spectator → the target they focus on

local function clearFocus(player: Player)
	watching[player] = nil
	player.ReplicationFocus = nil
end

-- The fighter's body for a target the client named: a player in this game,
-- or one of our bots' models.
local function bodyOf(target: Instance): Model?
	if target:IsA("Player") then
		return if target.Parent == Players then target.Character else nil
	end
	if target:IsA("Model") then
		for _, key in BotService.keys() do
			if BotService.modelOf(key) == target then
				return target
			end
		end
	end
	return nil
end

local function onSpectate(player: Player, target: unknown)
	if not limiter:allow(player, "Spectate") then
		return
	end
	if target == nil then
		clearFocus(player)
		return
	end
	if typeof(target) ~= "Instance" or target == player then
		return
	end
	-- Only someone who can't play right now spectates.
	local own = player.Character
	if own and Health.isAlive(own:FindFirstChildOfClass("Humanoid")) then
		return
	end
	local body = bodyOf(target)
	local root = body and body:FindFirstChild("HumanoidRootPart")
	if not body or not root or not root:IsA("BasePart") then
		return
	end
	if not Health.isAlive(body:FindFirstChildOfClass("Humanoid")) then
		return
	end
	local mine = Teams.of(player)
	local theirs = Teams.of(target)
	if not (mine ~= nil and mine == theirs) and MatchState.phase() ~= "RoundEnd" then
		return
	end
	watching[player] = target
	player.ReplicationFocus = root
end

-- Out of the round end, focus on an enemy (your killer) ends; so does focus
-- on someone who left.
local function recheck()
	local roundEnd = MatchState.phase() == "RoundEnd"
	for spectator, target in watching do
		local mine = Teams.of(spectator)
		local ally = mine ~= nil and Teams.of(target) == mine
		local gone = target.Parent == nil or bodyOf(target) == nil
		if gone or (not ally and not roundEnd) then
			clearFocus(spectator)
		end
	end
end

function SpectateService.init()
	Net.event("Spectate").OnServerEvent:Connect(onSpectate)
end

function SpectateService.start()
	local function watch(player: Player)
		-- A new life plays from its own body again.
		player.CharacterAdded:Connect(function()
			clearFocus(player)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		limiter:forget(player)
		watching[player] = nil
		task.defer(recheck) -- anyone watching them
	end)
	MatchState.changed("Phase"):Connect(recheck)
end

return SpectateService
