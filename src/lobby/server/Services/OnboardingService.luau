--!strict
-- New-player onboarding state (vault/05 Production/Handoff - Onboarding and Bots.md;
-- rules in Shared/Onboarding, numbers in Config/Onboarding). Runs in lobby and match
-- servers (the second favorite ask happens during match 2).
--
-- OnboardingRequest (client -> server):
--   ("favAsked", favorited: boolean)  the client showed the favorite prompt (and its result)
--   ("seen", bit: number)             the client showed a HUD unlock's NEW pop
-- Both only ever move the saved state forward (asks count up to the cap, bits only
-- set, favDone only turns on), so a lying client can at most skip its own prompts.
-- An ask is only counted when the rules say one was due (Shared/Onboarding.favAsk).
-- Rate-limited; refused before the save loads; rejects are counted, never kicked.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LobbyNet = require(ReplicatedStorage.Lobby.LobbyNet)
local Onboarding = require(ReplicatedStorage.Shared.Onboarding)
local OnbConfig = require(ReplicatedStorage.Shared.Config.Onboarding)
local PlayerData = require(ReplicatedStorage.Shared.PlayerData)
local RateLimit = require(ReplicatedStorage.Shared.Util.RateLimit)
local ServerRole = require(ReplicatedStorage.Shared.ServerRole)
local PlayerDataService = require(script.Parent.PlayerDataService)

local OnboardingService = {}

local limiter = RateLimit.new({ OnboardingRequest = OnbConfig.RATE })
local rejects: { [string]: number } = {}
local LOG_INTERVAL = 60

local function reject(reason: string)
	rejects[reason] = (rejects[reason] or 0) + 1
end

local function write(player: Player, what: string, change: PlayerDataService.Change)
	-- one write per request; a write already in flight queues (they're rare)
	local ok, why = PlayerDataService.transact(player, PlayerDataService.newTxId(), change, true)
	if not ok and why ~= "nothing" then
		warn(`[Onboarding] {what} for {player.UserId} not saved: {why}`)
	end
end

local function onFavAsked(player: Player, favorited: unknown)
	if typeof(favorited) ~= "boolean" then
		reject("badFav")
		return
	end
	local where = if ServerRole.isMatch() then "match" else "lobby"
	-- the cached save first: a request that can't change anything never costs a write
	local cached = PlayerDataService.get(player)
	if not cached or not Onboarding.favAsk(cached.onb, cached.prog.matches, where) then
		reject("favNotDue")
		return
	end
	write(player, "favAsked", function(data: PlayerData.Data)
		local o = data.onb
		if not Onboarding.favAsk(o, data.prog.matches, where) then
			return false, "nothing" -- no ask was due: nothing to count
		end
		o.fav = math.min(o.fav + 1, OnbConfig.FAV_MAX_ASKS)
		if favorited then
			o.favDone = true
		end
		return true
	end)
end

local function onSeen(player: Player, bit: unknown)
	if typeof(bit) ~= "number" or bit ~= bit or not Onboarding.isBit(bit) then
		reject("badBit")
		return
	end
	local b: number = bit
	local cached = PlayerDataService.get(player)
	if not cached or Onboarding.hasBit(cached.onb.seen, b) then
		reject("seenAlready")
		return
	end
	write(player, "seen", function(data: PlayerData.Data)
		local o = data.onb
		if Onboarding.hasBit(o.seen, b) then
			return false, "nothing"
		end
		o.seen = bit32.bor(o.seen, b)
		return true
	end)
end

local function onRequest(player: Player, action: unknown, arg: unknown)
	if not limiter:allow(player, "OnboardingRequest") then
		reject("rate")
		return
	end
	if typeof(action) ~= "string" then
		reject("badAction")
		return
	end
	if not PlayerData.ready(player) then
		reject("notLoaded")
		return
	end
	if action == "favAsked" then
		onFavAsked(player, arg)
	elseif action == "seen" then
		onSeen(player, arg)
	else
		reject("badAction")
	end
end

function OnboardingService.init() end

function OnboardingService.start()
	LobbyNet.event("OnboardingRequest").OnServerEvent:Connect(onRequest)
	Players.PlayerRemoving:Connect(function(player)
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
				`[Onboarding] rejected OnboardingRequest in the last {LOG_INTERVAL} s: {table.concat(
					parts,
					", "
				)}`
			)
			table.clear(rejects)
		end
	end
end

return OnboardingService
