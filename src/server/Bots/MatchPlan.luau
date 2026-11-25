--!strict
-- Who this match server is for (vault/05 Production/Overnight 2026-11-04.md
-- → Lobby → Match). The Lobby teleports a party into a reserved server with
-- TeleportData on every player:
--   { v = 1, matchId = string, mode = "1v1" | "2v2" | "3v3",
--     teams = { { userId... }, { userId... } }, bots = boolean }
-- TeleportData travels through the client, so it is untrusted: every field
-- is validated, and it is only taken from a joining player it lists. The
-- first valid one wins; later joiners can't change it.
--
-- Studio has no teleport: the Workspace attribute "BotMatch" ("1v1",
-- "2v2", "3v3") makes a plan with the first player on team 1 and bots on.

local Context = require(script.Parent.Parent.Context) -- this match (MatchKit/Context)
local Players = Context.players
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local RunService = game:GetService("RunService")

local BotsConfig = require(ReplicatedStorage.Shared.Config.Bots)
local HealthLog = require(ReplicatedStorage.Shared.HealthLog)
local Net = Context.net

-- The client's "my match screens are up" signal (MapVoteController). The value is the match's id, never a plain
-- true: a pad duel player keeps their GauntletState across duels, and a plain flag left from the last duel counted
-- them as loaded before their new match client existed (measured 2026-11-22: the 2nd duel's vote opened 0.03 s
-- after the zone change). Only this match's token counts.
local READY = "MatchVoteReady"

export type Plan = {
	matchId: string,
	mode: string,
	size: number, -- players per team
	teams: { { number } },
	bots: boolean,
	studio: boolean,
	firstJoinAt: number, -- os.clock() the plan was read
}

local MatchPlan = {}

local MAX_ID = 64
local plan: Plan? = nil
-- When each player of this match was first seen here (os.clock()), for READY_TIMEOUT.
local seenAt: { [Player]: number } = {}

local function userIds(value: unknown, size: number, seen: { [number]: boolean }): { number }?
	if typeof(value) ~= "table" then
		return nil
	end
	local list: { number } = {}
	local count = 0
	for k, v in value :: { [unknown]: unknown } do
		count += 1
		if typeof(k) ~= "number" or typeof(v) ~= "number" then
			return nil
		end
		local id = v :: number
		if id ~= id or id <= 0 or id ~= math.floor(id) or id > 2 ^ 53 or seen[id] then
			return nil
		end
		seen[id] = true
		table.insert(list, id)
	end
	if count ~= #list or count > size then
		return nil
	end
	return list
end

-- The contract's shape, or nil for anything else.
function MatchPlan.validate(data: unknown): Plan?
	if typeof(data) ~= "table" then
		return nil
	end
	local d = data :: { [string]: unknown }
	if d.v ~= 1 then
		return nil
	end
	local matchId, mode, bots = d.matchId, d.mode, d.bots
	if typeof(matchId) ~= "string" or #matchId == 0 or #matchId > MAX_ID then
		return nil
	end
	if typeof(mode) ~= "string" or typeof(bots) ~= "boolean" then
		return nil
	end
	local size = BotsConfig.MODES[mode]
	if not size then
		return nil
	end
	local teams = d.teams
	if typeof(teams) ~= "table" then
		return nil
	end
	local t = teams :: { [unknown]: unknown }
	local seen: { [number]: boolean } = {}
	local one = userIds(t[1], size, seen)
	local two = userIds(t[2], size, seen)
	if not one or not two or #(teams :: { unknown }) ~= 2 then
		return nil
	end
	return {
		matchId = matchId,
		mode = mode,
		size = size,
		teams = { one, two },
		bots = bots,
		studio = false,
		firstJoinAt = os.clock(),
	}
end

local function listed(p: Plan, userId: number): boolean
	return table.find(p.teams[1], userId) ~= nil or table.find(p.teams[2], userId) ~= nil
end

local function read(player: Player)
	if not seenAt[player] then
		seenAt[player] = os.clock()
		HealthLog.stage("match zone", player, Context.id)
	end
	if plan then
		return
	end
	-- A pad duel (MatchKit/Context) brings its own plan: the players on the pad, no bots.
	local given = Context.plan
	if given then
		plan = {
			matchId = given.matchId,
			mode = given.mode,
			size = given.size,
			teams = given.teams,
			bots = given.bots,
			studio = false,
			firstJoinAt = os.clock(),
		}
		return
	end
	if RunService:IsStudio() then
		local mode = StateValues.get(workspace, "BotMatch")
		local size = if typeof(mode) == "string" then BotsConfig.MODES[mode] else nil
		if size then
			plan = {
				matchId = "studio",
				mode = mode :: string,
				size = size,
				teams = { { player.UserId }, {} },
				bots = true,
				studio = true,
				firstJoinAt = os.clock(),
			}
			return
		end
	end
	local ok, joinData = pcall(function()
		return player:GetJoinData()
	end)
	if not ok or typeof(joinData) ~= "table" then
		return
	end
	local p = MatchPlan.validate((joinData :: any).TeleportData)
	if p and listed(p, player.UserId) then
		plan = p
	elseif (joinData :: any).TeleportData ~= nil then
		warn("[MatchPlan] ignored TeleportData from", player.UserId, "(invalid or not listed)")
	end
end

function MatchPlan.current(): Plan?
	return plan
end

-- The team the plan puts this player on (nil: not listed / no plan).
function MatchPlan.teamFor(player: Player): number?
	local p = plan
	if not p then
		return nil
	end
	for team = 1, 2 do
		if table.find(p.teams[team], player.UserId) then
			return team
		end
	end
	return nil
end

-- Whether this player's match client has said its screens are up, for this match.
function MatchPlan.isReady(player: Player): boolean
	return StateValues.get(player, READY) == Context.id
end

-- Wait for the vote UI on every connected seat. An absent seat expires after JOIN_GRACE (from the first arrival);
-- a seat that is here but never signals (a client that broke while loading) stops blocking after READY_TIMEOUT.
function MatchPlan.readiness(): (number, number, boolean)
	local p = plan
	if not p then
		return 0, 0, false
	end
	local studio = RunService:IsStudio()
	local grace = if studio then BotsConfig.JOIN_GRACE_STUDIO else BotsConfig.JOIN_GRACE
	local readyTimeout = if studio
		then BotsConfig.READY_TIMEOUT_STUDIO
		else BotsConfig.READY_TIMEOUT
	local now = os.clock()
	local ready, present, expected, waived = 0, 0, 0, 0
	for team = 1, 2 do
		for _, userId in p.teams[team] do
			expected += 1
			local player = Players:GetPlayerByUserId(userId)
			if player then
				present += 1
				if MatchPlan.isReady(player) then
					ready += 1
				elseif now - (seenAt[player] or now) >= readyTimeout then
					waived += 1
				end
			end
		end
	end
	local canStart = ready > 0
		and ready + waived == present
		and (present == expected or now - p.firstJoinAt >= grace)
	return ready, expected, canStart
end

function MatchPlan.allWaived(): boolean
	local p = plan
	if not p then
		return false
	end
	local studio = RunService:IsStudio()
	local readyTimeout = if studio
		then BotsConfig.READY_TIMEOUT_STUDIO
		else BotsConfig.READY_TIMEOUT
	local now = os.clock()
	local ready, present, waived = 0, 0, 0
	for team = 1, 2 do
		for _, userId in p.teams[team] do
			local player = Players:GetPlayerByUserId(userId)
			if player then
				present += 1
				if MatchPlan.isReady(player) then
					ready += 1
				elseif now - (seenAt[player] or now) >= readyTimeout then
					waived += 1
				end
			end
		end
	end
	return present > 0 and ready == 0 and waived == present
end

function MatchPlan.start()
	Net.event("MatchReady").OnServerEvent:Connect(function(player)
		if not MatchPlan.isReady(player) then
			StateValues.set(player, READY, Context.id)
			local since = seenAt[player]
			HealthLog.stage(
				"client ready",
				player,
				if since then string.format("%.1fs after the zone", os.clock() - since) else nil
			)
		end
	end)
	Players.PlayerAdded:Connect(read)
	Players.PlayerRemoving:Connect(function(player)
		seenAt[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		read(player)
	end
end

return MatchPlan
