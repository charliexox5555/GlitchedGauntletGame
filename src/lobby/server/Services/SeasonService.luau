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
--
-- Season end (Build Plan phase 9, 2026-11-27): once Config/Season.endsAt() has passed,
-- claims stop and every reward a player reached but didn't take is paid to them in one
-- write: when their save loads and once a minute while they're here (claims are marked,
-- so it pays once). In Studio the Workspace attribute SeasonEndNow = true forces the end.
-- Pay the leftovers before Season.ID changes: a new id starts every pass again.
-- Studio only: ServerStorage.SeasonTest:Invoke(userId, action, arg) sets up a test pass
-- ("tier", n | "premium", bool | "reset") and returns the season as JSON.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

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

local END_CHECK_SECONDS = 60 -- how often players here are checked for leftovers after the end

local REASON_TEXT: { [string]: string } = {
	ended = "The season is over: anything you reached was added for you",
	closed = "The battle pass isn't open right now",
	cannot = "That reward can't be claimed",
	nothing = "Nothing to claim yet",
	busy = "Still saving, try again",
	saving = "Couldn't save right now, try again",
}

-- Has the season ended? (Studio: Workspace SeasonEndNow = true forces it.)
local function ended(): boolean
	if RunService:IsStudio() and workspace:GetAttribute("SeasonEndNow") == true then
		return true
	end
	local ends = Season.endsAt()
	return ends ~= nil and os.time() >= ends
end

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

-- What a write paid, to the player (the pass screen lands reels and toasts from it).
local function send(player: Player, paid: { SeasonRewards.Claimed }, all: boolean, isEnd: boolean)
	local rewards = {}
	for _, c in paid do
		Telemetry.event(
			player,
			if isEnd then "Season leftover paid" else "Season reward claimed",
			c.tier,
			c.track
		)
		for _, r in c.rewards do
			table.insert(rewards, {
				kind = r.kind,
				name = r.name,
				amount = r.amount,
				gun = r.gun,
				line = r.line,
				tier = c.tier,
				track = c.track,
			})
		end
	end
	if player.Parent then
		seasonEvent:FireClient(player, {
			kind = "claimed",
			rewards = rewards,
			all = if all then true else nil,
			ended = if isEnd then true else nil,
		})
	end
end

-- Anything reached and not taken (a cheap look at the loaded copy).
local function hasLeftovers(data: any): boolean
	for tier = 1, data.season.tier do
		for _, track: SeasonPass.Track in { "free", "premium" } :: { SeasonPass.Track } do
			if
				#SeasonCatalog.rewards(tier, track) > 0
				and SeasonPass.canClaim(data.season, tier, track)
			then
				return true
			end
		end
	end
	return false
end

-- After the end: pay this player's leftovers in one write (claims are marked: pays once).
local function payLeftovers(player: Player)
	if busy[player] or not ended() or PlayZone.get(player) ~= "Lobby" then
		return
	end
	local known = PlayerDataService.get(player)
	if not known or not hasLeftovers(known) then
		return
	end
	busy[player] = true
	local paid: { SeasonRewards.Claimed } = {}
	local ok = PlayerDataService.transact(player, PlayerDataService.newTxId(), function(data)
		paid = SeasonRewards.claimAll(data)
		if #paid == 0 then
			return false, "nothing"
		end
		return true
	end)
	busy[player] = nil
	if ok and #paid > 0 then
		send(player, paid, true, true)
	end
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
	if ended() then
		fail(player, "ended")
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
	send(player, paid, tier == nil, false)
end

function SeasonService.init() end

function SeasonService.start()
	seasonEvent = LobbyNet.event("SeasonEvent")
	LobbyNet.event("SeasonRequest").OnServerEvent:Connect(onRequest)
	Players.PlayerRemoving:Connect(function(p)
		limiter:forget(p)
		busy[p] = nil
	end)
	-- the season-end payout: on load (and any change) and once a minute
	PlayerDataService.changed:Connect(function(p: Player)
		task.defer(payLeftovers, p)
	end)
	task.spawn(function()
		while true do
			task.wait(END_CHECK_SECONDS)
			if ended() then
				for _, p in Players:GetPlayers() do
					task.spawn(payLeftovers, p)
				end
			end
		end
	end)
	if RunService:IsStudio() then
		local hook = Instance.new("BindableFunction")
		hook.Name = "SeasonTest"
		hook.OnInvoke = function(userId: number, action: string, arg: any): string
			local p = Players:GetPlayerByUserId(userId)
			if not p then
				return "no player"
			end
			local ok, why = PlayerDataService.transact(
				p,
				PlayerDataService.newTxId(),
				function(data)
					if action == "tier" and typeof(arg) == "number" then
						data.season.tier = math.clamp(math.floor(arg), 0, Season.TIERS)
						data.season.secs, data.season.rounds = 0, 0
						-- claims stay only for tiers still reached (SeasonPass.valid)
						data.season = SeasonPass.clean(data.season)
					elseif action == "premium" then
						data.season.premium = arg == true
					elseif action == "reset" then
						data.season = SeasonPass.new()
					else
						return false, "bad action"
					end
					return true
				end
			)
			if not ok then
				return "failed: " .. tostring(why)
			end
			local data = PlayerDataService.get(p)
			return if data then HttpService:JSONEncode(data.season) else "no data"
		end
		hook.Parent = ServerStorage
	end
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
