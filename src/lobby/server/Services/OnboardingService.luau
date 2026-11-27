--!strict
-- New-player onboarding state (vault/05 Production/Handoff - Onboarding and Bots.md;
-- rules in Shared/Onboarding, numbers in Config/Onboarding). Runs in lobby and match
-- servers (the second favorite ask happens during match 2).
--
-- OnboardingRequest (client -> server):
--   ("favAsked", favorited: boolean)  the client showed the favorite prompt (and its result)
--   ("seen", bit: number)             the client showed a HUD unlock's NEW pop (or the first-unlock callout)
--   ("step", key: string)             an Onboarding_v3 funnel step only the client sees: "loaded" (the loading
--                                     screen closed), "moved" (first move in the lobby, after "loaded") or
--                                     "callout" (the first-unlock callout is up; only when the save says it's due)
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
local PlayZone = require(ReplicatedStorage.Shared.PlayZone)
local PlayerDataService = require(script.Parent.PlayerDataService)
local Telemetry = require(script.Parent.Parent.Telemetry)

local OnboardingService = {}

local limiter = RateLimit.new({ OnboardingRequest = OnbConfig.RATE })
local rejects: { [string]: number } = {}
local backpackLogged: { [Player]: boolean } = {}
local LOG_INTERVAL = 60

local function reject(reason: string)
	rejects[reason] = (rejects[reason] or 0) + 1
end

local function write(player: Player, what: string, change: PlayerDataService.Change): boolean
	-- one write per request; a write already in flight queues (they're rare)
	local ok, why = PlayerDataService.transact(player, PlayerDataService.newTxId(), change, true)
	if not ok and why ~= "nothing" then
		warn(`[Onboarding] {what} for {player.UserId} not saved: {why}`)
	end
	return ok
end

local function onFavAsked(player: Player, favorited: unknown)
	if typeof(favorited) ~= "boolean" then
		reject("badFav")
		return
	end
	local where = if PlayZone.get(player) == "Match" then "match" else "lobby"
	-- the cached save first: a request that can't change anything never costs a write
	local cached = PlayerDataService.get(player)
	if not cached or not Onboarding.favAsk(cached.onb, cached.prog.matches, where) then
		reject("favNotDue")
		return
	end
	local saved = write(player, "favAsked", function(data: PlayerData.Data)
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
	if saved then
		Telemetry.event(player, "Onboarding favorite prompt", 1, where)
		if favorited then
			Telemetry.event(player, "Onboarding favorite accepted", 1, where)
		end
	end
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
	local saved = write(player, "seen", function(data: PlayerData.Data)
		local o = data.onb
		if not Onboarding.bitAllowed(b, data.prog.matches) or Onboarding.hasBit(o.seen, b) then
			return false, "nothing"
		end
		o.seen = bit32.bor(o.seen, b)
		return true
	end)
	if saved then
		Telemetry.event(player, "Onboarding unlock viewed", 1, tostring(b))
		if b == OnbConfig.FIRST_UNLOCK.bit then
			Telemetry.onboardingV3(player, Telemetry.V3.LOCKER_OPENED)
		end
	end
end

-- Client-only funnel steps: the key picks the step, nothing else is read. Telemetry sends each once, forward only,
-- in the new-player cohort before match 1 and in a public lobby only, so a lying client can at most mark its own
-- funnel early; "moved" also needs "loaded" first.
local CLIENT_STEPS: { [string]: number } = {
	loaded = Telemetry.V3.LOADING_CLOSED,
	moved = Telemetry.V3.FIRST_MOVE,
	callout = Telemetry.V3.LOCKER_SHOWN,
}

local function onStep(player: Player, key: unknown)
	if typeof(key) ~= "string" or #key > 8 then
		reject("badStep")
		return
	end
	local step = CLIENT_STEPS[key]
	if not step then
		reject("badStep")
		return
	end
	if
		step == Telemetry.V3.FIRST_MOVE
		and not Telemetry.onboardingV3Sent(player, Telemetry.V3.LOADING_CLOSED)
	then
		reject("stepOrder")
		return
	end
	if step == Telemetry.V3.LOCKER_SHOWN then
		local cached = PlayerDataService.get(player)
		if
			not cached
			or Onboarding.firstUnlock(
					cached.prog.matches,
					cached.onb.seen,
					cached.guns.owned,
					cached.coins
				)
				== nil
		then
			reject("calloutNotDue")
			return
		end
	end
	Telemetry.onboardingV3(player, step)
end

local function onBackpackOpened(player: Player)
	if backpackLogged[player] then
		return
	end
	local cached = PlayerDataService.get(player)
	if not cached or not cached.onb.caseGift or cached.onb.caseOpened then
		reject("backpackNotDue")
		return
	end
	backpackLogged[player] = true
	Telemetry.onboarding(player, 14)
	Telemetry.caseOnboarding(player, 2, "Backpack opened")
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
	elseif action == "backpackOpened" then
		onBackpackOpened(player)
	elseif action == "step" then
		onStep(player, arg)
	else
		reject("badAction")
	end
end

function OnboardingService.reset(player: Player)
	backpackLogged[player] = nil
end

function OnboardingService.init() end

function OnboardingService.start()
	LobbyNet.event("OnboardingRequest").OnServerEvent:Connect(onRequest)
	local function checkHub(player: Player)
		local data = PlayerDataService.get(player)
		if data and data.prog.matches >= 1 and PlayZone.get(player) == "Lobby" then
			Telemetry.onboarding(player, 13)
			Telemetry.onboardingV3(player, Telemetry.V3.LOBBY_AFTER_M1, nil, data.prog.matches)
			if data.prog.matches >= 2 then
				Telemetry.onboardingV2(player, Telemetry.V2.LOBBY_AFTER_MATCH_2)
			end
		end
	end
	PlayerDataService.changed:Connect(checkHub)
	PlayZone.changed:Connect(checkHub)
	for _, player in Players:GetPlayers() do
		checkHub(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		limiter:forget(player)
		backpackLogged[player] = nil
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
