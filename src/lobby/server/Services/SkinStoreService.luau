--!strict
-- Gun skins on demand, the server half (Shared/SkinStore; vault/05 Production/Handoff - Onboarding and Bots.md).
-- Runs in lobby and match servers. At start it publishes the skin manifest; each player gets an empty
-- PlayerGui.SkinDelivery folder (made on join, before any client script can snapshot PlayerGui).
--
-- SkinRequest (client -> server): ({ { line, gun } }) up to SkinStore.MAX_PER_REQUEST pairs. Each pair must
-- name a ready skin in the manifest; a skin already sent to that player is skipped. The copies go in the
-- player's own PlayerGui, which only that player's client receives. Rate-limited; bad requests are dropped
-- and counted, never kicked.
-- The server also sends each player's equipped skins on its own as soon as their Locker loads, so their
-- first gun wears its skin without a round trip.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LobbyNet = require(ReplicatedStorage.Lobby.LobbyNet)
local Locker = require(ReplicatedStorage.Shared.Locker)
local RateLimit = require(ReplicatedStorage.Shared.Util.RateLimit)
local PlayZone = require(ReplicatedStorage.Shared.PlayZone)
local ServerRole = require(ReplicatedStorage.Shared.ServerRole)
local SkinStore = require(ReplicatedStorage.Shared.SkinStore)

local SkinStoreService = {}

local limiter = RateLimit.new({ SkinRequest = { 4, 12 } })
local sent: { [Player]: { [string]: boolean } } = {}
local rejects: { [string]: number } = {}
local LOG_INTERVAL = 60

local function reject(reason: string)
	rejects[reason] = (rejects[reason] or 0) + 1
end

local function delivery(player: Player): Folder?
	local gui = player:FindFirstChildOfClass("PlayerGui")
	if not gui then
		return nil
	end
	local f = gui:FindFirstChild(SkinStore.DELIVERY)
	if f and f:IsA("Folder") then
		return f
	end
	local made = Instance.new("Folder")
	made.Name = SkinStore.DELIVERY
	made.Parent = gui
	return made
end

-- Copies one skin into the player's delivery folder (once).
local function send(player: Player, line: string, name: string): boolean
	local mine = sent[player]
	if not mine then
		return false
	end
	local k = line .. "/" .. name
	if mine[k] then
		return true
	end
	local model = SkinStore.model(line, name)
	local folder = delivery(player)
	if not model or not folder then
		return false
	end
	local lineFolder = folder:FindFirstChild(line)
	if not lineFolder then
		lineFolder = Instance.new("Folder")
		lineFolder.Name = line
		lineFolder.Parent = folder
	end
	mine[k] = true
	model:Clone().Parent = lineFolder
	return true
end

local function onRequest(player: Player, list: unknown)
	if not limiter:allow(player, "SkinRequest") then
		reject("rate")
		return
	end
	if typeof(list) ~= "table" then
		reject("badList")
		return
	end
	local n = 0
	for _, pair in list :: { unknown } do
		n += 1
		if n > SkinStore.MAX_PER_REQUEST then
			reject("tooMany")
			break
		end
		if typeof(pair) ~= "table" then
			reject("badPair")
			continue
		end
		local line, name = (pair :: any)[1], (pair :: any)[2]
		if
			typeof(line) ~= "string"
			or typeof(name) ~= "string"
			or #line > 32
			or #name > 32
			or not SkinStore.has(line, name)
		then
			reject("unknownSkin")
			continue
		end
		send(player, line, name)
	end
end

-- `owner`'s equipped skins (their Locker replica), sent to `to` without being asked.
local function sendEquipped(owner: Player, to: Player)
	for gun, line in Locker.equipped(owner) do
		if line ~= "Stock" then
			send(to, line, SkinStore.modelName(gun, line))
		end
	end
end

-- The players in `player`'s match (the whole server in the old Match role).
local function matchMates(player: Player): { Player }
	if ServerRole.isMatch() then
		return Players:GetPlayers()
	end
	local id = PlayZone.matchId(player)
	if PlayZone.get(player) ~= "Match" or not id then
		return { player }
	end
	local list: { Player } = {}
	for _, p in Players:GetPlayers() do
		if PlayZone.matchId(p) == id and PlayZone.get(p) == "Match" then
			table.insert(list, p)
		end
	end
	return list
end

-- Who gets a player's equipped skins: themselves, and in a match everyone in it (spectating shows the watched
-- player's gun in first person, so nobody's skin pops in mid-spectate).
local function audience(owner: Player): { Player }
	return matchMates(owner)
end

-- Joining a match (a hosted queued match, a pad duel): swap equipped skins with everyone in it.
local function onZone(player: Player)
	if PlayZone.get(player) ~= "Match" or not sent[player] then
		return
	end
	for _, other in matchMates(player) do
		if other ~= player and sent[other] then
			sendEquipped(other, player)
			sendEquipped(player, other)
		end
	end
end

local function onPlayerAdded(player: Player)
	sent[player] = {}
	delivery(player)
	Locker.observe(player, function()
		for _, to in audience(player) do
			sendEquipped(player, to)
		end
	end)
	for _, to in audience(player) do
		sendEquipped(player, to)
	end
	onZone(player)
end

-- A skin to these players right now (a case roll: it travels ahead of the result, so the reveal
-- never shows a stand-in).
function SkinStoreService.sendTo(players: { Player }, gun: string, line: string)
	if line == "Stock" then
		return
	end
	local name = SkinStore.modelName(gun, line)
	for _, p in players do
		send(p, line, name)
	end
end

function SkinStoreService.init()
	local count = SkinStore.publishManifest()
	print(`[SkinStore] {count} skins in the manifest`)
end

function SkinStoreService.start()
	LobbyNet.event(SkinStore.REMOTE).OnServerEvent:Connect(onRequest)
	Players.PlayerAdded:Connect(onPlayerAdded)
	PlayZone.changed:Connect(onZone)
	for _, p in Players:GetPlayers() do
		task.spawn(onPlayerAdded, p)
	end
	Players.PlayerRemoving:Connect(function(player)
		sent[player] = nil
		limiter:forget(player)
	end)
	while true do
		task.wait(LOG_INTERVAL)
		if next(rejects) then
			local parts = {}
			for reason, n in rejects do
				table.insert(parts, `{reason}={n}`)
			end
			warn(
				`[SkinStore] rejected SkinRequest in the last {LOG_INTERVAL} s: {table.concat(
					parts,
					", "
				)}`
			)
			table.clear(rejects)
		end
	end
end

return SkinStoreService
