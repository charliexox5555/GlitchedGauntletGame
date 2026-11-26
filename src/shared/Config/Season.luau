--!strict
-- The season pass rules (vault/01 Design/Battle Pass Season 1 Contents.md, owner 2026-11-26).
-- The rewards per tier live in Lobby/SeasonCatalog; the saved state and the tier maths
-- in Shared/SeasonPass. Data only.

local Season = {}

-- A new id starts everyone's pass again (Shared/SeasonPass.clean). Pay the old season's
-- unclaimed rewards before changing it (vault/04 Tech/Battle Pass Build Plan.md, phase 9).
Season.ID = 1
Season.NAME = "SEASON 1"
Season.TIERS = 30
Season.LENGTH_DAYS = 42 -- 6 weeks
-- os.time() (UTC) the season opens. 0 = not scheduled yet: it never ends (set at launch).
Season.STARTS_AT = 0

-- One tier every TIER_SECONDS in live rounds OR every TIER_ROUNDS rounds won, whichever
-- fills first. The meter that fills keeps its overflow; the other starts again at 0.
Season.TIER_SECONDS = 30 * 60
Season.TIER_ROUNDS = 25
Season.FIRST_WIN_ROUNDS = 5 -- the first win of each UTC day adds this many rounds
Season.BOT_SCALE = 0.5 -- no real player on the other side: time and rounds count half
-- The most one match can add (a match server can't report more than this).
Season.MAX_MATCH_SECONDS = 60 * 60
Season.MAX_MATCH_ROUNDS = 20

Season.PREMIUM_ROBUX = 689
Season.SKIP_ROBUX = 499
Season.SKIP_TIERS = 5
-- Given the moment premium is bought (Lobby/SeasonRewards.setPremium).
Season.PREMIUM_TITLE = "SEASON 1"

-- Powers the pass unlocks for the draft (phase 7 reads this in Shared/ModLoadout).
-- A power listed here is draftable once its tier's reward on that track is claimed.
Season.POWER_UNLOCKS = table.freeze({
	Smoke = table.freeze({ tier = 10, track = "free" }),
	ElectricShock = table.freeze({ tier = 20, track = "premium" }),
}) :: { [string]: { tier: number, track: "free" | "premium" } }

-- os.time() the season ends (nil while not scheduled).
function Season.endsAt(): number?
	if Season.STARTS_AT <= 0 then
		return nil
	end
	return Season.STARTS_AT + Season.LENGTH_DAYS * 86400
end

return table.freeze(Season)
