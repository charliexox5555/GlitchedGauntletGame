--!strict
-- Sends a formed match to a reserved Match server (TeleportAsync with a
-- ReservedServerAccessCode) carrying the Lobby -> Match TeleportData contract
-- (vault/05 Production/Overnight 2026-11-04.md). Retries reserving and
-- teleporting with backoff, retries single players on TeleportInitFailed, and
-- hands every failure back to the caller. In Studio (no teleports) it logs and
-- reports the payload it would send instead.

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

local Launcher = {}

local pending: { [Player]: Pending } = {}

local function backoff(attempt: number): number
	local list = Config.retryBackoff
	return list[math.min(attempt, #list)]
end

local function reserve(): (string?, string?)
	local lastErr = "unknown"
	for attempt = 1, Config.reserveAttempts do
		local ok, result =
			pcall(TeleportService.ReserveServerAsync, TeleportService, Config.MATCH_PLACE_ID)
		if ok and typeof(result) == "string" then
			return result, nil
		end
		lastErr = tostring(result)
		warn(`[Queue] ReserveServerAsync failed ({attempt}/{Config.reserveAttempts}): {lastErr}`)
		if attempt < Config.reserveAttempts then
			task.wait(backoff(attempt))
		end
	end
	return nil, lastErr
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

-- The one retry path (a thrown TeleportAsync or a TeleportInitFailed): try this
-- player alone again after a backoff, until the attempts run out.
local function retry(player: Player, entry: Pending)
	if entry.attempts >= Config.teleportAttempts then
		fail(player, FAIL_TEXT)
		return
	end
	entry.attempts += 1
	entry.deadline = os.clock() + backoff(entry.attempts - 1) + Config.teleportTimeout
	task.delay(backoff(entry.attempts - 1), function()
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
			warn(`[Queue] TeleportAsync retry {entry.attempts} for {player.Name} failed: {err}`)
			retry(player, entry)
		end
	end)
end

-- Runs the whole launch for one match; yields until the teleport is sent.
function Launcher.launch(match: Match, hooks: Hooks)
	local code: string? = nil
	if not IS_STUDIO then
		code = reserve()
	end

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

	if not code then
		for _, p in present do
			hooks.failed(p, "Couldn't start a match server. You're back in the lobby; try again.")
		end
		return
	end

	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = code
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
		warn(`[Queue] TeleportAsync for match {match.id} failed: {err}`)
		for _, p in present do
			local entry = pending[p]
			if entry and entry.matchId == match.id then
				retry(p, entry)
			end
		end
	end
end

function Launcher.init()
	TeleportService.TeleportInitFailed:Connect(
		function(player: Player, result: Enum.TeleportResult, message: string)
			local entry = pending[player]
			if not entry or result == Enum.TeleportResult.IsTeleporting then
				return
			end
			warn(`[Queue] TeleportInitFailed for {player.Name} ({result.Name}): {message}`)
			retry(player, entry)
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
