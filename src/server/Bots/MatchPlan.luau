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

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BotsConfig = require(ReplicatedStorage.Shared.Config.Bots)

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
	if plan then
		return
	end
	if RunService:IsStudio() then
		local mode = workspace:GetAttribute("BotMatch")
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

-- Every listed player is here, or the grace for them is over.
function MatchPlan.ready(): boolean
	local p = plan
	if not p then
		return false
	end
	local grace = if RunService:IsStudio()
		then BotsConfig.JOIN_GRACE_STUDIO
		else BotsConfig.JOIN_GRACE
	if os.clock() - p.firstJoinAt >= grace then
		return true
	end
	for team = 1, 2 do
		for _, userId in p.teams[team] do
			if not Players:GetPlayerByUserId(userId) then
				return false
			end
		end
	end
	return true
end

function MatchPlan.start()
	Players.PlayerAdded:Connect(read)
	for _, player in Players:GetPlayers() do
		read(player)
	end
end

return MatchPlan
