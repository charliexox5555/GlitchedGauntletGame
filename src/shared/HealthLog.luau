--!strict
-- The stage health log (vault/05 Production/Handoff - Stability, Loading and Preload.md, Phase 1).
-- One line per loading stage, on the server and on the client, in Studio and live:
--   [Health] S joined Name +0.0s
--   [Health] S vote Name? +12.4s 2/2 ready
-- S = server, C = client. The seconds count from that player's join on the server (from this client's start on a
-- client; from the server's start for lines about no one player). Live, server lines are in the F9 console's
-- Server tab, so a report ("stuck on the vote", "skins missing") can be traced to the stage that stalled.
-- Plain prints, no remotes, no storage. LihFolk: Debugging Live Servers (JobId and place version on the first line).

local RunService = game:GetService("RunService")

local HealthLog = {}

local SIDE = if RunService:IsServer() then "S" else "C"
local started = os.clock()
local joinedAt: { [Player]: number } = setmetatable({}, { __mode = "k" }) :: any

-- The join line (the server calls it on PlayerAdded).
function HealthLog.joined(player: Player)
	HealthLog.stage("joined", player)
end

local function since(player: Player?): number
	if not player then
		return started
	end
	-- A player's clock starts at their first line (the client's own player: this client's start).
	local at = joinedAt[player]
	if not at then
		at = if RunService:IsServer() then os.clock() else started
		joinedAt[player] = at
	end
	return at
end

-- One stage line. `detail` is a short note (a count, a map id, a reason).
function HealthLog.stage(stage: string, player: Player?, detail: string?)
	local from = since(player)
	print(
		string.format(
			"[Health] %s %s %s+%.1fs%s",
			SIDE,
			stage,
			if player then player.Name .. " " else "",
			os.clock() - from,
			if detail then " " .. detail else ""
		)
	)
end

-- A stage that went wrong: the same line as a warning, so it stands out in Output.
function HealthLog.problem(stage: string, player: Player?, detail: string?)
	local from = since(player)
	warn(
		string.format(
			"[Health] %s %s %s+%.1fs%s",
			SIDE,
			stage,
			if player then player.Name .. " " else "",
			os.clock() - from,
			if detail then " " .. detail else ""
		)
	)
end

print(
	string.format(
		"[Health] %s start job %s place %d v%d",
		SIDE,
		if game.JobId == "" then "studio" else string.sub(game.JobId, 1, 8),
		game.PlaceId,
		game.PlaceVersion
	)
)

return HealthLog
