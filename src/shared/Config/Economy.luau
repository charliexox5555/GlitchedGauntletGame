--!strict
-- The launch economy (vault/01 Design/Shop Economy and Art v1.md, owner's picks 2026-11-22).
-- Two currencies:
--   Coins    earned (login rewards, match pay) and sold in coin packs; buy Common / Rare
--            daily skins and the streak save. Balance cap: Config/Inventory.MAX_COINS.
--   Tickets  EARN-ONLY, never sold for Robux and never inside anything bought with Robux
--            (that keeps cases outside Roblox's paid-random-items rules). Buy skin cases.
-- Shared/LoginRewards reads LOGIN; LobbyServer/LoginRewardService grants it.
local Economy = {}

Economy.DAY_SECONDS = 86400 -- days are UTC: day index = os.time() // DAY_SECONDS

-- Tickets
Economy.MAX_TICKETS = 100_000
Economy.STARTING_TICKETS = 0 -- no free case for match 1 any more (owner 2026-11-27)

-- Login rewards: a 7-day loop. Claim once per UTC day; the day after the last claim
-- gives the next step, a missed day starts again at step 1, after step 7 comes step 1.
-- `item` = a Config/Inventory item id (one of it). Never anything Robux can buy.
export type Reward = { coins: number?, tickets: number?, item: string? }
Economy.LOGIN = table.freeze({
	table.freeze({ coins = 250 }),
	table.freeze({ tickets = 1 }),
	table.freeze({ coins = 500 }),
	table.freeze({ tickets = 2 }),
	table.freeze({ coins = 750 }),
	table.freeze({ tickets = 3 }),
	table.freeze({ coins = 1000, item = "CaseStandard" }),
}) :: { Reward }

-- Free Rewards (the lobby's green hologram, owner 2026-11-28): a one-time gift for joining the game's Roblox
-- group, checked on the server (Services/GroupRewardService, PlayerData buys.group). "Like the game" is only
-- asked, never a condition: platforms prohibit rewarding ratings (LihFolk: Community Building).
-- `item` = a Config/Inventory item id (one of it).
Economy.GROUP_REWARD = table.freeze({ group = 11116787, coins = 500, item = "CaseStandard" })

-- What each skin case costs in Tickets (wired with the Shop purchases, step 2 of the plan).
Economy.CASE_TICKETS =
	table.freeze({ Standard = 1, Elite = 3, Apex = 6, Knife = 8 }) :: { [string]: number }

-- The SURGE power pack (vault/01 Design/Loadout and Power Deck.md -> Launch plan, owner 2026-11-27): COINS
-- ONLY, `coins` each (one or three at a time), no Robux product. A pack opened when every power is already
-- owned pays `coins` back.
Economy.POWER_PACK = table.freeze({ coins = 1500 })

-- Charm blind boxes (StrikeBox / OverdriveBox): COINS ONLY (`BUY x1` or `BUY x3`).
-- Prioritizes unowned charms until all 12 in that box are owned, then allows up to
-- 1 copy per active gun before converting overflow to coins.
Economy.CHARM_BOX = table.freeze({ coins = 850 })

-- Match pay in coins (ProgressionService, in the same write as the XP). Leaving pays
-- nothing; matches with no real player on the other side pay `botScale` of it. At most
-- `dailyCap` coins a UTC day from matches.
-- Economy pass 2026-11-27 (was 15 / 20 / 0.5 / 400): most of the pay is for the win, so idling through a lost
-- bot match pays little (6 coins), and the cap is about 4 hours of bot matches or 2.5 of real ones.
Economy.MATCH_COINS = table.freeze({ finish = 10, win = 40, botScale = 0.6, dailyCap = 600 })
-- On top of that (2026-11-27, Economy pass -> "Needs code" 1-3): coins per round won and per elimination, each
-- capped, so a close loss pays; `finish` only for a player who took part (an elimination or a round won; the
-- first `ONBOARDING` matches always pay it), so idling through bot matches earns nothing; and the day's first win
-- pays `firstWin` once a UTC day, outside the daily cap. Rounds, kills and the first win are scaled by `botScale`
-- like the rest.
Economy.MATCH_BONUS = table.freeze({
	perRound = 3,
	maxRounds = 5,
	perKill = 1,
	maxKills = 10,
	firstWin = 100,
	onboardingMatches = 2,
})

-- The daily shop: PER PLAYER, rolled by the server at the player's first visit of the
-- UTC day and saved (PlayerData `daily`), so nothing off their list can be bought.
-- One slot per entry: a tier, or "EpicOrLegendary" (a coin flip when both are free).
-- Skins the player doesn't own come first; a slot with none left shows an owned one.
-- Owner 2026-11-28 ("show more epic and legendary skins ... not too much"): 3 Common,
-- 2 Rare, 2 Epic, 1 Epic-or-Legendary (was 4 / 2 / 1 / 1). Keep 8 entries: the DAILY tab
-- has Item1..Item8.
Economy.DAILY_SLOTS = table.freeze({
	"Common",
	"Common",
	"Common",
	"Rare",
	"Rare",
	"Epic",
	"Epic",
	"EpicOrLegendary",
}) :: { string }
-- Owner 2026-11-28: most daily skins are for guns the player OWNS (the knife counts);
-- up to this many slots, at random, may show a gun they haven't unlocked yet as a tease
-- (shown GUN LOCKED, not buyable until the gun is unlocked). A slot falls back to the
-- other kind when its own has nothing left for that tier.
Economy.DAILY_TEASES = 2
-- Daily skins by tier: a coin price (Common, Rare) or Robux only (the rest).
Economy.DAILY_COINS = table.freeze({ Common = 1000, Rare = 2500 }) :: { [string]: number }
-- What a skin costs in Robux by tier (daily shop Epic and up; bundle items sold alone).
Economy.SKIN_ROBUX = table.freeze({
	Common = 199,
	Rare = 349,
	Epic = 449,
	Legendary = 649,
	Exclusive = 499,
}) :: { [string]: number }

-- What a Robux purchase that can't be granted pays back in coins, per Robux (a lost skin
-- intent, a skin or bundle already owned). About the coin packs' base rate.
Economy.ROBUX_TO_COINS = 10

function Economy.day(t: number): number
	return t // Economy.DAY_SECONDS
end

return table.freeze(Economy)
