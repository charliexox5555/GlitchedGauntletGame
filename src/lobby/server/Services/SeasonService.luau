--!strict
-- Season pass claims (vault/04 Tech/Battle Pass Build Plan.md, phase 4).
--   SeasonRequest (client -> server):
--     ("claim", tier, track)  one reward: tier a whole number 1..Config/Season.TIERS,
--                             track "free" | "premium"
--     ("claimAll")            every reward reached and not yet taken
--   SeasonEvent (server -> that client): { kind = "claimed", rewards } | { kind = "failed", text }
-- The client only names WHICH reward. Whether it's reached, bought (premium) and not yet
-- taken is decided inside one PlayerDataService write (Lobby/SeasonRewards.claim), which
-- also pays and marks it, so a reward can never pay twice. Lobby only, while the pass is
-- open (Shared/SeasonPass.open). Premium and +5 LEVELS are Robux (Services/RobuxService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Lobby.Config)
local LobbyNet = require(ReplicatedStorage.Lobby.LobbyNet)
local SeasonCatalog = require(ReplicatedStorage.Lobby.SeasonCatalog)
local SeasonRewards = require(ReplicatedStorage.Lobby.SeasonRewards)
local Season = require(ReplicatedStorage.Shared.Config.Season)
local SeasonPass = require(ReplicatedStorage.Shared.SeasonPass)
local PlayZone = require(ReplicatedStorage.Shared.PlayZone)
local RateLimit = require(ReplicatedStorage.Shared.Util.RateLimit)
local PlayerDataService = require(script.Parent.PlayerDataService)
local Telemetry = require(script.Parent.Parent.Telemetry)

local SeasonService = {}

local limiter = RateLimit.new(Config.RATE)
local seasonEvent: RemoteEvent
local busy: { [Player]: boolean } = {}
local rejects: { [string]: number } = {}

local REASON_TEXT: { [string]: string } = {
	closed = "The battle pass isn't open right now",
	cannot = "That reward can't be claimed",
	nothing = "Nothing to claim yet",
	busy = "Still saving, try again",
	saving = "Couldn't save right now, try again",
}

local function reject(reason: string)
	rejects[reason] = (rejects[reason] or 0) + 1
end

local function fail(player: Player, why: string)
	if player.Parent then
		seasonEvent:FireClient(
			player,
			{ kind = "failed", text = REASON_TEXT[why] or REASON_TEXT.saving }
		)
	end
end

-- A whole tier number in range, or nil (rejects NaN, inf, fractions, other types).
local function tierArg(v: unknown): number?
	if typeof(v) ~= "number" or v ~= v or v ~= math.floor(v) or v < 1 or v > Season.TIERS then
		return nil
	end
	return v
end

local function trackArg(v: unknown): SeasonPass.Track?
	return if v == "free" then "free" elseif v == "premium" then "premium" else nil
end

local function onRequest(player: Player, what: unknown, a: unknown, b: unknown)
	if not limiter:allow(player, "SeasonRequest") then
		reject("rate")
		return
	end
	if PlayZone.get(player) ~= "Lobby" then
		reject("notLobby")
		return
	end
	if typeof(what) ~= "string" then
		reject("badAction")
		return
	end
	local tier: number?, track: SeasonPass.Track? = nil, nil
	if what == "claim" then
		tier, track = tierArg(a), trackArg(b)
		if not tier or not track then
			reject("badArgs")
			return
		end
	elseif what ~= "claimAll" then
		reject("badAction")
		return
	end
	if not SeasonPass.open(os.time(), RunService:IsStudio()) then
		fail(player, "closed")
		return
	end
	if busy[player] then
		fail(player, "busy")
		return
	end
	-- cheap refusal from the loaded copy; the real check is inside the write
	local known = PlayerDataService.get(player)
	if not known then
		fail(player, "saving")
		return
	end
	if tier and track then
		if
			#SeasonCatalog.rewards(tier, track) == 0
			or not SeasonPass.canClaim(known.season, tier, track)
		then
			fail(player, "cannot")
			return
		end
	end
	busy[player] = true
	local paid: { SeasonRewards.Claimed } = {}
	local ok, why = PlayerDataService.transact(player, PlayerDataService.newTxId(), function(data)
		paid = {}
		if tier and track then
			local c = SeasonRewards.claim(data, tier, track)
			if not c then
				return false, "cannot"
			end
			table.insert(paid, c)
		else
			paid = SeasonRewards.claimAll(data)
			if #paid == 0 then
				return false, "nothing"
			end
		end
		return true
	end)
	busy[player] = nil
	if not ok then
		fail(player, why or "saving")
		return
	end
	local rewards = {}
	for _, c in paid do
		Telemetry.event(player, "Season reward claimed", c.tier, c.track)
		for _, r in c.rewards do
			table.insert(rewards, { kind = r.kind, name = r.name, amount = r.amount })
		end
	end
	if player.Parent then
		seasonEvent:FireClient(player, { kind = "claimed", rewards = rewards })
	end
end

function SeasonService.init() end

function SeasonService.start()
	seasonEvent = LobbyNet.event("SeasonEvent")
	LobbyNet.event("SeasonRequest").OnServerEvent:Connect(onRequest)
	Players.PlayerRemoving:Connect(function(p)
		limiter:forget(p)
		busy[p] = nil
	end)
	while true do
		task.wait(Config.rejectLogInterval)
		if next(rejects) then
			local parts = {}
			for reason, count in rejects do
				table.insert(parts, `{reason}={count}`)
			end
			warn(`[Season] rejected SeasonRequest: {table.concat(parts, ", ")}`)
			table.clear(rejects)
		end
	end
end

return SeasonService
