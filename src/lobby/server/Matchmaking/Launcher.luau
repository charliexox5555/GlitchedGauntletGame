--!strict
-- Sends a formed match to its own reserved Match server and carries the
-- Lobby -> Match TeleportData contract (vault/05 Production/Overnight
-- 2026-11-04.md). In Studio (no teleports) it logs and reports the payload.
--
-- LihFolk (41 Multiplayer Services: Teleporting and Multi-Place Games;
-- Reserved and Private Servers in Practice; TeleportService - Engine Reference
-- Card; Error Handling and Retries):
--  * ReserveServerAsync is deprecated: each match gets one
--    TeleportOptions.ReservedServerId (a GUID kept server-side); the first
--    teleport creates the server, so there is no reserve step to fail.
--  * Only TeleportResult Failure (after ~2 s) and Flooded (after ~10 s) are
--    retried, per player, with the options TeleportInitFailed hands back
--    (same reserved server). GameFull / GameEnded / GameNotFound /
--    Unauthorized end with a message. IsTeleporting means it's already going.
--  * A thrown TeleportAsync (nothing in flight) retries with 1, 2, 4, 8 s backoff.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Config = require(ReplicatedStorage.Lobby.Config)

export type Match = {
	id: string,
	mode: string,
	teamSize: number,
	players: { Player },
	teams: { { number } }, -- split once when found, so the MATCH FOUND screen stays true
	startsAt: number, -- os.clock() of the teleport
}

export type Hooks = {
	stillIn: (Player) -> boolean, -- still in this match (didn't leave the server)
	teleporting: (Player) -> (),
	failed: (Player, string) -> (),
	studio: (Player, string) -> (), -- the TeleportData JSON it would have sent
}

export type TeleportData = {
	v: number,
	matchId: string,
	mode: string,
	teams: { { number } },
	bots: boolean,
}

type Pending = {
	matchId: string,
	options: TeleportOptions,
	attempts: number,
	deadline: number, -- os.clock(); restarted on every attempt
	hooks: Hooks,
}

local IS_STUDIO = RunService:IsStudio()
local FAIL_TEXT = "Couldn't reach the match server. You're back in the lobby; try again."

-- Results worth retrying, and how long to wait first (seconds).
local RETRY_AFTER: { [Enum.TeleportResult]: number } = {
	[Enum.TeleportResult.Failure] = 2,
	[Enum.TeleportResult.Flooded] = 10,
}

-- Results that end the attempt, with what the player is told.
local FINAL_TEXT: { [Enum.TeleportResult]: string } = {
	[Enum.TeleportResult.GameFull] = "That match filled up. You're back in the lobby; queue again.",
	[Enum.TeleportResult.GameEnded] = "That match already ended. You're back in the lobby.",
	[Enum.TeleportResult.GameNotFound] = "That match server is gone. You're back in the lobby.",
	[Enum.TeleportResult.Unauthorized] = "You can't join that match. You're back in the lobby.",
}

local Launcher = {}

local pending: { [Player]: Pending } = {}

local function backoff(attempt: number): number
	local list = Config.retryBackoff
	return list[math.min(attempt, #list)]
end

-- The match's teams with anyone who left removed; bots fill what's missing.
function Launcher.buildData(match: Match, present: { Player }): TeleportData
	local here: { [number]: boolean } = {}
	for _, p in present do
		here[p.UserId] = true
	end
	local teams: { { number } } = {}
	for t, team in match.teams do
		local kept: { number } = {}
		for _, id in team do
			if here[id] then
				table.insert(kept, id)
			end
		end
		teams[t] = kept
	end
	return {
		v = Config.TEAMDATA_VERSION,
		matchId = match.id,
		mode = match.mode,
		teams = teams,
		bots = #present < match.teamSize * 2,
	}
end

local function fail(player: Player, text: string)
	local entry = pending[player]
	pending[player] = nil
	if entry then
		entry.hooks.failed(player, text)
	end
end

-- The one retry path: try this player alone again after `wait` seconds, with
-- `options` (the same reserved server), until the attempts run out.
local function retry(player: Player, entry: Pending, wait: number, options: TeleportOptions?)
	if entry.attempts >= Config.teleportAttempts then
		fail(player, FAIL_TEXT)
		return
	end
	entry.attempts += 1
	if options then
		entry.options = options
	end
	entry.deadline = os.clock() + wait + Config.teleportTimeout
	task.delay(wait, function()
		if pending[player] ~= entry or player.Parent ~= Players then
			return
		end
		local ok, err = pcall(
			TeleportService.TeleportAsync,
			TeleportService,
			Config.MATCH_PLACE_ID,
			{ player },
			entry.options
		)
		if not ok then
			warn(`[Queue] TeleportAsync retry {entry.attempts} for {player.Name} threw: {err}`)
			retry(player, entry, backoff(entry.attempts), nil)
		end
	end)
end

-- Runs the whole launch for one match; yields until the teleport is sent.
function Launcher.launch(match: Match, hooks: Hooks)
	local remaining = match.startsAt - os.clock()
	if remaining > 0 then
		task.wait(remaining)
	end

	local present: { Player } = {}
	for _, p in match.players do
		if p.Parent == Players and hooks.stillIn(p) then
			table.insert(present, p)
		end
	end
	if #present == 0 then
		return
	end

	local data = Launcher.buildData(match, present)
	local json = HttpService:JSONEncode(data)

	if IS_STUDIO then
		print(
			`[Queue] STUDIO: would teleport {#present} player(s) to place {Config.MATCH_PLACE_ID} with TeleportData {json}`
		)
		for _, p in present do
			hooks.studio(p, json)
		end
		return
	end

	local options = Instance.new("TeleportOptions")
	options.ReservedServerId = HttpService:GenerateGUID(false) -- one private server per match
	options:SetTeleportData(data)

	for _, p in present do
		pending[p] = {
			matchId = match.id,
			options = options,
			attempts = 1,
			deadline = os.clock() + Config.teleportTimeout,
			hooks = hooks,
		}
		hooks.teleporting(p)
	end
	print(`[Queue] teleporting {#present} player(s), match {match.id}: {json}`)

	local ok, err = pcall(
		TeleportService.TeleportAsync,
		TeleportService,
		Config.MATCH_PLACE_ID,
		present,
		options
	)
	if not ok then
		-- Nothing is in flight after a throw, so each player retries on their own.
		warn(`[Queue] TeleportAsync for match {match.id} threw: {err}`)
		for _, p in present do
			local entry = pending[p]
			if entry and entry.matchId == match.id then
				retry(p, entry, backoff(1), nil)
			end
		end
	end
end

function Launcher.init()
	TeleportService.TeleportInitFailed:Connect(
		function(
			player: Player,
			result: Enum.TeleportResult,
			message: string,
			_placeId: number,
			options: TeleportOptions?
		)
			local entry = pending[player]
			if not entry or result == Enum.TeleportResult.IsTeleporting then
				return
			end
			warn(`[Queue] TeleportInitFailed for {player.Name} ({result.Name}): {message}`)
			local wait = RETRY_AFTER[result]
			if wait then
				retry(player, entry, wait, options)
			else
				fail(player, FINAL_TEXT[result] or FAIL_TEXT)
			end
		end
	)
	Players.PlayerRemoving:Connect(function(player)
		pending[player] = nil
	end)
	-- Watchdog: anyone still here past their attempt's deadline goes back to the lobby.
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.clock()
			for player, entry in pending do
				if now > entry.deadline and player.Parent == Players then
					fail(player, "The match took too long to load. You're back in the lobby.")
				end
			end
		end
	end)
end

return Launcher
