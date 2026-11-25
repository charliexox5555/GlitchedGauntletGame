--!strict
-- Gameplay never waits on Roblox Analytics. Events are owned by the server.
local Analytics = game:GetService("AnalyticsService")
local Http = game:GetService("HttpService")
local Players = game:GetService("Players")
local live = not game:GetService("RunService"):IsStudio()

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
	"M1 R4 live",
	"M1 R4 done",
	"Match 1 saved",
	"Returned to hub",
	"Backpack opened",
	"Free case opened",
	"Skin equipped",
	"Match 2 queued",
	"Match 2 R1 live",
	"Match 2 saved",
}
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

function Telemetry.cohort(player: Player, enrolled: boolean)
	if live and enrolled and not cohort[player] then
		cohort[player] = {}
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
	caseCohort[player] = nil
	searches[player] = nil
end)

return Telemetry
