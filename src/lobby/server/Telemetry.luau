--!strict
-- Gameplay never waits on Roblox Analytics. Events are owned by the server.
local Analytics = game:GetService("AnalyticsService")
local Http = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local live = not game:GetService("RunService"):IsStudio()

local OnbConfig = require(ReplicatedStorage.Shared.Config.Onboarding)
local ServerRole = require(ReplicatedStorage.Shared.ServerRole)
local StateValues = require(ReplicatedStorage.Shared.StateValues)

local Telemetry = {}
local cohort: { [Player]: { [number]: boolean } } = {}
local caseCohort: { [Player]: { [number]: boolean } } = {}
local searches: { [Player]: { id: string, mode: string, at: number } } = {}
local steps = {
	"Save ready",
	"Match 1 launched",
	"M1 R1 draft",
	"M1 R1 live",
	"M1 R1 done",
	"M1 R2 live",
	"M1 R2 done",
	"M1 R3 live",
	"M1 R3 done",
	"M1 R4 live or won", -- a first match is first to 3 (2026-11-25): a match that ends sooner counts here too
	"M1 R4 done or won",
	"Match 1 saved",
	"Returned to hub",
	"Backpack opened",
	"Free case opened",
	"Skin equipped",
	"Match 2 queued",
	"Match 2 R1 live",
	"Match 2 saved",
}
-- Onboarding_v2 (2026-11-26, vault/01 Design/First Ten Minutes.md): the First Ten Minutes flow as its own funnel,
-- next to the old Onboarding one (kept so the two can be compared). One session per player (their UserId), the
-- same new-player cohort. Most steps ride on the old steps (V2_FROM_OLD); the rest are sent directly.
local FUNNEL_V2 = "Onboarding_v2"
local stepsV2 = {
	"Save ready",
	"Match 1 launched",
	"M1 R1 fight (no pick)",
	"M1 R1 done",
	"M1 R2 fight (2-card pick)",
	"M1 R3 fight (Glitched card)",
	"Match 1 saved",
	"Back in lobby",
	"Free case opened",
	"Match 2 R1 fight",
	"Match 2 saved",
	"Lobby after match 2",
	"Match 3 started",
}
Telemetry.V2 = table.freeze({ LOBBY_AFTER_MATCH_2 = 12, MATCH_3_STARTED = 13 })
local V2_FROM_OLD: { [number]: number } = {
	[1] = 1,
	[2] = 2,
	[4] = 3,
	[5] = 4,
	[6] = 5,
	[8] = 6,
	[12] = 7,
	[13] = 8,
	[15] = 9,
	[18] = 10,
	[19] = 11,
}
local cohortV2: { [Player]: { [number]: boolean } } = {}

-- Onboarding_v3 (2026-11-27, vault/04 Tech/Onboarding Funnel v3.md): today's flow (first match first to 4, the
-- player's own guns, no free case, onboarding matches on reserved servers), with steps for the loading screen,
-- the lobby, the queue and the teleport. One session per player (their UserId). The cohort: a brand-new save
-- (onb.analytics) with fewer than 3 matches saved when it loads.
-- Each step is sent once per player per server, forward only (never one below the furthest sent), and only at its
-- saved-match count, so a step that re-happens on the next server (Save ready on the reserved one) is never sent
-- out of place. Roblox counts a repeated step once and counts skipped steps as passed, so a 4-0 match 1 passes
-- R5-R7 and a player who goes straight to match 2 passes the Locker steps.
-- Steps sent before the save loads (the hosted arrival) wait for it and are dropped if not in the cohort.
local FUNNEL_V3 = "Onboarding_v3"
local V3_COHORT_BELOW = 3 -- matches saved at load
local M1_TO_WIN = OnbConfig.SCRIPT[1].roundsToWin
local M1_MAX_ROUNDS = M1_TO_WIN * 2 - 1
type StepV3 = { title: string, min: number, max: number, hub: boolean }
local stepsV3: { StepV3 } = {}
local function addV3(title: string, min: number, max: number, hub: boolean?): number
	table.insert(stepsV3, { title = title, min = min, max = max, hub = hub == true })
	return #stepsV3
end
local ANY = math.huge
local V3_SAVE_READY = addV3("Save ready", 0, 0, true)
local V3_LOADING_CLOSED = addV3("Loading screen closed", 0, 0, true)
local V3_FIRST_MOVE = addV3("First move in lobby", 0, 0, true)
local V3_M1_QUEUED = addV3("Match 1 queued", 0, 0, true)
local V3_M1_ARRIVED = addV3("Match 1 server reached", 0, 0)
local V3_M1_ROUND_1 = #stepsV3 + 1
for round = 1, M1_MAX_ROUNDS do
	addV3(`M1 R{round} live`, 0, 0)
	addV3(`M1 R{round} done`, 0, 0)
end
local V3_M1_SAVED = addV3("Match 1 saved", 1, 1)
local V3_LOBBY_AFTER_M1 = addV3("Back in lobby", 1, 1)
local V3_LOCKER_SHOWN = addV3("Locker callout shown", 1, ANY)
local V3_LOCKER_OPENED = addV3("Locker opened from callout", 1, ANY)
local V3_FIRST_GUN = addV3("First gun unlocked", 1, ANY)
local V3_M2_STARTED = addV3("Match 2 started", 1, 1)
local V3_M2_SAVED = addV3("Match 2 saved", 2, 2)
local V3_M3_STARTED = addV3("Match 3 started", 2, 2)
Telemetry.V3 = table.freeze({
	SAVE_READY = V3_SAVE_READY,
	LOADING_CLOSED = V3_LOADING_CLOSED,
	FIRST_MOVE = V3_FIRST_MOVE,
	M1_QUEUED = V3_M1_QUEUED,
	M1_ARRIVED = V3_M1_ARRIVED,
	M1_SAVED = V3_M1_SAVED,
	LOBBY_AFTER_M1 = V3_LOBBY_AFTER_M1,
	LOCKER_SHOWN = V3_LOCKER_SHOWN,
	LOCKER_OPENED = V3_LOCKER_OPENED,
	FIRST_GUN = V3_FIRST_GUN,
	M2_STARTED = V3_M2_STARTED,
	M2_SAVED = V3_M2_SAVED,
	M3_STARTED = V3_M3_STARTED,
})
type V3State = { sent: { [number]: boolean }, furthest: number, loadMatches: number }
local cohortV3: { [Player]: V3State } = {}
local decidedV3: { [Player]: boolean } = {}
local pendingV3: { [Player]: { { step: number, label: string? } } } = {}
local PENDING_MAX = 8
-- Studio test switch: Workspace attribute TelemetryLog = true prints the Onboarding_v2 and v3 steps (nothing is
-- sent from Studio).
local function studioLog(): boolean
	return not live and workspace:GetAttribute("TelemetryLog") == true
end
local warnAfter = 0

local function emit(fn: () -> ())
	if live then
		task.defer(function()
			local ok, err = pcall(fn)
			if not ok and os.clock() >= warnAfter then
				warnAfter = os.clock() + 60
				warn("[Analytics] " .. tostring(err))
			end
		end)
	end
end

local function fields(f1: string?, f2: string?, f3: string?): { [string]: string }?
	local out: { [string]: string } = {}
	local any = false
	if f1 ~= nil and f1 ~= "" then
		out[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = f1
		any = true
	end
	if f2 ~= nil and f2 ~= "" then
		out[Enum.AnalyticsCustomFieldKeys.CustomField02.Name] = f2
		any = true
	end
	if f3 ~= nil and f3 ~= "" then
		out[Enum.AnalyticsCustomFieldKeys.CustomField03.Name] = f3
		any = true
	end
	return if any then out else nil
end

function Telemetry.event(player: Player, name: string, value: number, label: string?)
	emit(function()
		Analytics:LogCustomEvent(player, name, value, if label then fields(label) else nil)
	end)
end

local function sendV3(
	player: Player,
	state: V3State,
	step: number,
	label: string?,
	matches: number?
)
	local def = stepsV3[step]
	if not def or state.sent[step] or step <= state.furthest then
		return
	end
	-- matches only go up: the published count, the count at load, or the caller's fresher one
	local published = StateValues.get(player, "Matches")
	local m = math.max(
		state.loadMatches,
		if typeof(published) == "number" then published else 0,
		matches or 0
	)
	if m < def.min or m > def.max or (def.hub and ServerRole.isHosted()) then
		return
	end
	state.sent[step] = true
	state.furthest = step
	if studioLog() then
		print(
			`[Telemetry] {FUNNEL_V3} {step}. {def.title}{if label then " (" .. label .. ")" else ""}`
		)
	end
	local id = tostring(player.UserId)
	local title = def.title
	emit(function()
		Analytics:LogFunnelStepEvent(player, FUNNEL_V3, id, step, title, fields(label))
	end)
end

-- `matches`: the player's saved matches played (for Onboarding_v3: prog.matches at load).
function Telemetry.cohort(player: Player, enrolled: boolean, matches: number?)
	if live and enrolled and not cohort[player] then
		cohort[player] = {}
		cohortV2[player] = {}
	elseif studioLog() and enrolled and not cohortV2[player] then
		cohortV2[player] = {}
	end
	if decidedV3[player] or player.Parent ~= Players then
		return
	end
	decidedV3[player] = true
	local waiting = pendingV3[player]
	pendingV3[player] = nil
	local m = matches or 0
	if enrolled and m < V3_COHORT_BELOW and (live or studioLog()) then
		local state: V3State = { sent = {}, furthest = 0, loadMatches = m }
		cohortV3[player] = state
		for _, p in waiting or {} do
			sendV3(player, state, p.step, p.label)
		end
	end
end

-- One Onboarding_v3 step (Telemetry.V3). `label`: custom field 1 (a small fixed set only). `matches`: the saved
-- matches played when the caller knows a fresher count than the published one (just after a match saved).
function Telemetry.onboardingV3(player: Player, step: number, label: string?, matches: number?)
	local state = cohortV3[player]
	if state then
		sendV3(player, state, step, label, matches)
	elseif not decidedV3[player] and player.Parent == Players then
		local waiting = pendingV3[player]
		if not waiting then
			waiting = {}
			pendingV3[player] = waiting
		end
		if #waiting < PENDING_MAX then
			table.insert(waiting, { step = step, label = label })
		end
	end
end

-- Match 1's rounds (Onboarding_v3 "M1 R<n> live" / "done"); rounds past the longest first-to-N match are ignored.
function Telemetry.onboardingV3Round(player: Player, round: number, done: boolean)
	if round >= 1 and round <= M1_MAX_ROUNDS then
		Telemetry.onboardingV3(player, V3_M1_ROUND_1 + (round - 1) * 2 + (if done then 1 else 0))
	end
end

-- This Onboarding_v3 step was sent to this player on this server.
function Telemetry.onboardingV3Sent(player: Player, step: number): boolean
	local state = cohortV3[player]
	return state ~= nil and state.sent[step] == true
end

-- One Onboarding_v2 step (each once per player; only the new-player cohort). `label`: custom field 1.
function Telemetry.onboardingV2(player: Player, step: number, label: string?)
	local sent = cohortV2[player]
	local title = stepsV2[step]
	if sent and title and not sent[step] then
		sent[step] = true
		if studioLog() then
			print(
				`[Telemetry] {FUNNEL_V2} {step}. {title}{if label then " (" .. label .. ")" else ""}`
			)
		end
		local id = tostring(player.UserId)
		emit(function()
			Analytics:LogFunnelStepEvent(player, FUNNEL_V2, id, step, title, fields(label))
		end)
	end
end

function Telemetry.onboarding(player: Player, step: number)
	local sent = cohort[player]
	if sent and not sent[step] then
		sent[step] = true
		emit(function()
			Analytics:LogOnboardingFunnelStepEvent(player, step, steps[step])
		end)
	end
	local v2 = V2_FROM_OLD[step]
	if v2 then
		-- the free case: did they ask for the next match on match 1's end screen, or go to the lobby?
		local label = if step == 15
			then (if player:GetAttribute("OnbNextMatch") ~= nil then "next match" else "lobby")
			else nil
		Telemetry.onboardingV2(player, v2, label)
	end
end

function Telemetry.caseOnboarding(player: Player, step: number, title: string)
	if not live then
		return
	end
	local sent = caseCohort[player]
	if not sent then
		sent = {}
		caseCohort[player] = sent
	end
	if not sent[step] then
		sent[step] = true
		local id = tostring(player.UserId)
		emit(function()
			Analytics:LogFunnelStepEvent(player, "OnboardingCase", id, step, title)
		end)
	end
end

function Telemetry.funnel(
	player: Player,
	name: string,
	id: string,
	step: number,
	title: string,
	label: string
)
	emit(function()
		Analytics:LogFunnelStepEvent(player, name, id, step, title, fields(label))
	end)
end

function Telemetry.queueStart(player: Player, mode: string)
	if live then
		local search = { id = Http:GenerateGUID(false), mode = mode, at = os.clock() }
		searches[player] = search
		Telemetry.funnel(player, "Matchmaking", search.id, 1, "Search started", mode)
	end
end

function Telemetry.queueStep(player: Player, step: number, title: string)
	local search = searches[player]
	if search then
		Telemetry.funnel(player, "Matchmaking", search.id, step, title, search.mode)
		if step == 2 then
			Telemetry.event(player, "Queue wait seconds", os.clock() - search.at, search.mode)
		end
	end
end

function Telemetry.queueStop(player: Player, reason: string)
	local search = searches[player]
	if search then
		searches[player] = nil
		Telemetry.event(player, reason, os.clock() - search.at, search.mode)
	end
end

function Telemetry.mapVoted(player: Player, mapName: string, mode: string)
	emit(function()
		Analytics:LogCustomEvent(player, "MapVoted", 1, fields(mapName, mode))
	end)
end

function Telemetry.mapPlayed(player: Player, mapName: string, mode: string)
	emit(function()
		Analytics:LogCustomEvent(player, "MapPlayed", 1, fields(mapName, mode))
	end)
end

function Telemetry.mapCompleted(player: Player, mapName: string, mode: string, rounds: number)
	emit(function()
		Analytics:LogCustomEvent(player, "MapCompleted", rounds, fields(mapName, mode))
	end)
end

function Telemetry.mapLeftEarly(player: Player, mapName: string, mode: string, round: number)
	emit(function()
		Analytics:LogCustomEvent(player, "MapLeftEarly", round, fields(mapName, mode))
	end)
end

-- A player left mid-match (MatchService.onLeave): value = the round, fields = the phase they left in
-- ("Draft", "Countdown", "Live", "RoundEnd", ...), their score "mine-theirs W/L/-" (the last round's result), and
-- "first" / "onboarding" / the mode, then ":" and the device ("first:Mobile"). Shows which gap loses players.
function Telemetry.matchLeft(
	player: Player,
	round: number,
	phase: string,
	score: string,
	kind: string
)
	emit(function()
		Analytics:LogCustomEvent(player, "MatchLeft", round, fields(phase, score, kind))
	end)
end

function Telemetry.mapFunnel(
	player: Player,
	matchKey: string,
	step: number,
	title: string,
	mapName: string,
	mode: string
)
	emit(function()
		Analytics:LogFunnelStepEvent(
			player,
			"MapFlow",
			matchKey,
			step,
			title,
			fields(mapName, mode)
		)
	end)
end

Players.PlayerRemoving:Connect(function(player)
	cohort[player] = nil
	cohortV2[player] = nil
	cohortV3[player] = nil
	decidedV3[player] = nil
	pendingV3[player] = nil
	caseCohort[player] = nil
	searches[player] = nil
end)

return Telemetry
