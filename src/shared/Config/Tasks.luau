--!strict
-- The task Path (vault/01 Design/Tasks and Rewards.md, owner's picks 2026-11-26). Data only: nothing reads this yet.
--   * One-time, per account: 6 sets in order, each 3 parts, each part 3 tasks (Veteran part 3 has 4).
--   * It opens back in the lobby after the onboarding matches (Config/Match ONBOARDING_MATCHES = 2).
--   * One part shows at a time (the lobby's three-row LobbyTasks panel). A task only counts while its part is
--     showing; `level` tasks check the player's current level instead.
--   * Bots count everywhere (owner 2026-11-26). Coins are the main reward; a Ticket only at the end of
--     sets 2, 4 and 6 (skins stay premium).
--   * Every count is decided by the server from match results and range hits, never sent by the client.
-- `text` is shown with string.format(text, target).
local Match = require(script.Parent.Match)

local POWER_COUNT = 12 -- the powers in the game (Config/Mods); "use every power" asks for this many

-- What a task counts. Filters on the task narrow it (`teamSize`, `tier`, `level`).
export type Kind =
	"rangeVisit" -- walk into the Range (target 1)
	| "rangeTargets" -- shatter Range air targets
	| "rangeBots" -- down Range training bots
	| "matchPlay" -- finish a match (leaving doesn't count); `teamSize` = only that mode
	| "matchWin" -- win a match; `teamSize` = only that mode
	| "matchFlawless" -- win a match without losing a round
	| "glitchWin" -- win a match in which you picked a Glitched power
	| "winStreak" -- win this many matches in a row (counted from when the task appears)
	| "roundWin" -- win a round
	| "roundNoDeath" -- win a round without dying
	| "roundClutch" -- win a round as your team's last player alive
	| "roundAce" -- eliminate the whole enemy team alone in one round; `teamSize` = only that mode
	| "elims" -- eliminations; `tier` = only with that weapon tier
	| "headshotElims" -- eliminations by a headshot
	| "multiElim" -- `level` eliminations within MULTI_ELIM_WINDOW, counted per streak
	| "tierSweep" -- an elimination with every weapon tier in one match
	| "powerDraft" -- powers drafted
	| "powerUse" -- power uses
	| "powerDistinct" -- different powers used (all of them = POWER_COUNT)
	| "powerLevel" -- powers taken to `level` in a match
	| "mapDistinct" -- different maps played on
	| "mapWinDistinct" -- different maps won on
	| "level" -- reach this player level (checks the current level)

export type Task = {
	id: string, -- unique across the Path, saved with the player's progress: never rename one that shipped
	kind: Kind,
	target: number,
	text: string,
	teamSize: number?, -- 1, 2 or 3: only matches of that size
	tier: number?, -- weapon tier (1 = Sidearm)
	level: number?, -- powerLevel: the level; multiElim: eliminations in the streak
}
export type Part = { tasks: { Task } }
export type SetReward = { coins: number?, tickets: number?, title: string? }
export type TaskSet = {
	id: string,
	name: string,
	coins: number, -- per task
	partBonus: number, -- coins for finishing each part
	reward: SetReward, -- for finishing the set (on top of its last part's bonus)
	parts: { Part },
}

local function t(
	id: string,
	kind: Kind,
	target: number,
	text: string,
	extra: { [string]: any }?
): Task
	local task = { id = id, kind = kind, target = target, text = text } :: any
	if extra then
		for k, v in extra do
			task[k] = v
		end
	end
	return table.freeze(task) :: Task
end

local function part(...: Task): Part
	return table.freeze({ tasks = table.freeze({ ... }) })
end

local SETS: { TaskSet } = {
	{
		id = "Recruit",
		name = "RECRUIT",
		coins = 50,
		partBonus = 100,
		reward = { coins = 200 },
		parts = {
			part(
				t("rec1_rangeVisit", "rangeVisit", 1, "Visit the Range"),
				t("rec1_rangeTargets", "rangeTargets", 10, "Shatter %d air targets at the Range"),
				t("rec1_rangeBots", "rangeBots", 3, "Down %d training bots at the Range")
			),
			part(
				t("rec2_play", "matchPlay", 2, "Finish %d matches"),
				t("rec2_draft", "powerDraft", 6, "Draft %d powers"),
				t("rec2_elims", "elims", 5, "Get %d eliminations")
			),
			part(
				t("rec3_wins", "matchWin", 2, "Win %d matches"),
				t("rec3_elims", "elims", 10, "Get %d eliminations"),
				t("rec3_powerUse", "powerUse", 15, "Use powers %d times")
			),
		},
	},
	{
		id = "Rookie",
		name = "ROOKIE",
		coins = 75,
		partBonus = 150,
		reward = { tickets = 1 },
		parts = {
			part(
				t("roo1_play1v1", "matchPlay", 1, "Play a 1v1", { teamSize = 1 }),
				t("roo1_play3v3", "matchPlay", 1, "Play a 3v3", { teamSize = 3 }),
				t("roo1_elims", "elims", 15, "Get %d eliminations")
			),
			part(
				t("roo2_powers", "powerDistinct", 5, "Use %d different powers"),
				t(
					"roo2_tierSweep",
					"tierSweep",
					1,
					"Get an elimination with every weapon tier in one match"
				),
				t("roo2_wins", "matchWin", 3, "Win %d matches")
			),
			part(
				t("roo3_headshots", "headshotElims", 5, "Get %d headshot eliminations"),
				t("roo3_wins", "matchWin", 5, "Win %d matches"),
				t("roo3_double", "multiElim", 1, "Get a double elimination", { level = 2 })
			),
		},
	},
	{
		id = "Contender",
		name = "CONTENDER",
		coins = 100,
		partBonus = 200,
		reward = { coins = 400 },
		parts = {
			part(
				t("con1_wins", "matchWin", 5, "Win %d matches"),
				t("con1_elims", "elims", 30, "Get %d eliminations"),
				t(
					"con1_powerL2",
					"powerLevel",
					1,
					"Take a power to level 2 in a match",
					{ level = 2 }
				)
			),
			part(
				t("con2_noDeath", "roundNoDeath", 3, "Win %d rounds without dying"),
				t("con2_double", "multiElim", 2, "Get %d double eliminations", { level = 2 }),
				t("con2_glitchWin", "glitchWin", 1, "Win a match after picking a Glitched power")
			),
			part(
				t("con3_streak", "winStreak", 2, "Win %d matches in a row"),
				t("con3_maps", "mapDistinct", 6, "Play on %d different maps"),
				t("con3_wins2v2", "matchWin", 3, "Win %d 2v2s", { teamSize = 2 })
			),
		},
	},
	{
		id = "Duelist",
		name = "DUELIST",
		coins = 125,
		partBonus = 250,
		reward = { tickets = 1 },
		parts = {
			part(
				t("due1_wins1v1", "matchWin", 5, "Win %d 1v1s", { teamSize = 1 }),
				t("due1_elims", "elims", 60, "Get %d eliminations"),
				t("due1_flawless", "matchFlawless", 1, "Win a match without losing a round")
			),
			part(
				t("due2_streak", "winStreak", 3, "Win %d matches in a row"),
				t("due2_mapWins", "mapWinDistinct", 8, "Win on %d different maps"),
				t("due2_allPowers", "powerDistinct", POWER_COUNT, "Use every power at least once")
			),
			part(
				t("due3_clutch", "roundClutch", 1, "Win a round as your team's last player alive"),
				t("due3_sidearm", "elims", 10, "Get %d eliminations with a Sidearm", { tier = 1 }),
				t("due3_wins", "matchWin", 12, "Win %d matches")
			),
		},
	},
	{
		id = "Veteran",
		name = "VETERAN",
		coins = 150,
		partBonus = 300,
		reward = { coins = 600 },
		parts = {
			part(
				t("vet1_wins", "matchWin", 15, "Win %d matches"),
				t("vet1_headshots", "headshotElims", 25, "Get %d headshot eliminations"),
				t("vet1_level15", "level", 15, "Reach level %d")
			),
			part(
				t("vet2_wins1v1", "matchWin", 5, "Win %d 1v1s", { teamSize = 1 }),
				t("vet2_wins2v2", "matchWin", 5, "Win %d 2v2s", { teamSize = 2 }),
				t("vet2_wins3v3", "matchWin", 5, "Win %d 3v3s", { teamSize = 3 })
			),
			part( -- four tasks (owner 2026-11-26)
				t("vet3_noDeath", "roundNoDeath", 15, "Win %d rounds without dying"),
				t("vet3_level20", "level", 20, "Reach level %d"),
				t("vet3_flawless", "matchFlawless", 3, "Win %d matches without losing a round"),
				t("vet3_headshots", "headshotElims", 30, "Get %d headshot eliminations")
			),
		},
	},
	{
		id = "Champion",
		name = "CHAMPION",
		coins = 200,
		partBonus = 400,
		reward = { tickets = 1, coins = 1000, title = "Champion" },
		parts = {
			part(
				t("cha1_elims", "elims", 150, "Get %d eliminations"),
				t("cha1_streak", "winStreak", 5, "Win %d matches in a row"),
				t("cha1_wins", "matchWin", 20, "Win %d matches")
			),
			part(
				t(
					"cha2_ace",
					"roundAce",
					1,
					"Eliminate the whole enemy team alone in a 3v3 round",
					{ teamSize = 3 }
				),
				t("cha2_flawless", "matchFlawless", 5, "Win %d matches without losing a round"),
				t("cha2_wins1v1", "matchWin", 10, "Win %d 1v1s", { teamSize = 1 })
			),
			part(
				t("cha3_wins", "matchWin", 30, "Win %d matches"),
				t("cha3_elims", "elims", 300, "Get %d eliminations"),
				t("cha3_level30", "level", 30, "Reach level %d")
			),
		},
	},
}

for _, set in SETS do
	table.freeze(set.reward)
	table.freeze(set.parts)
	table.freeze(set)
end

return table.freeze({
	-- The Path opens once a player has finished this many matches (back in the lobby after match 2).
	START_AFTER_MATCHES = Match.ONBOARDING_MATCHES,
	MULTI_ELIM_WINDOW = 4, -- s between eliminations for a double / triple
	POWER_COUNT = POWER_COUNT,
	SETS = table.freeze(SETS),
})
