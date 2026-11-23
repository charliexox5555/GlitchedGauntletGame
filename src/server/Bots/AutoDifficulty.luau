--!strict
-- Picks the match's bot difficulty from its real players (Config/Bots.AUTO; vault/05 Production/Handoff -
-- Onboarding and Bots.md → Bots redesign). Pure: MatchService gathers the facts, BotService applies the name.
--   level   the real players' average level → Easy / Normal / Hard
--   mobile  most real players on phones or tablets → one step easier
--   streak  the real players on a win streak → one step harder
--   score   in this match, the real players' side ahead by scoreMargin → harder; behind → easier
--   mode    Beginner 2v2 → never above beginnerMax
-- Returns a Config/Bots.PROFILES name.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BotsConfig = require(ReplicatedStorage.Shared.Config.Bots)

export type Facts = {
	levels: { number }, -- each real player's level
	mobile: number, -- how many of them play on Mobile
	streaks: { number }, -- each real player's win streak
	mode: string?, -- the match plan's mode ("beginner", "2v2", ...)
	lead: number?, -- the real players' side's score minus the other side's, when they're all on one side
}

local AutoDifficulty = {}

local function average(list: { number }): number
	if #list == 0 then
		return 0
	end
	local sum = 0
	for _, n in list do
		sum += n
	end
	return sum / #list
end

function AutoDifficulty.pick(f: Facts): string
	local auto = BotsConfig.AUTO
	local steps = auto.steps
	if #f.levels == 0 then
		return steps[1] -- nobody real here (a test): the gentlest
	end
	local level = average(f.levels)
	local step = #steps
	for _, row in auto.levelSteps do
		if level < row.below then
			step = row.step
			break
		end
	end
	if f.mobile / #f.levels >= auto.mobileShare then
		step -= 1
	end
	if average(f.streaks) >= auto.streakUp then
		step += 1
	end
	local lead = f.lead
	if lead then
		if lead >= auto.scoreMargin then
			step += 1
		elseif lead <= -auto.scoreMargin then
			step -= 1
		end
	end
	local top = if f.mode == "beginner" then auto.beginnerMax else #steps
	return steps[math.clamp(step, 1, top)]
end

return AutoDifficulty
