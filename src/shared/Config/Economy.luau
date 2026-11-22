--!strict
-- The launch economy (vault/01 Design/Shop Economy and Art v1.md, owner's picks 2026-11-22).
-- Two currencies:
--   Coins    earned (login rewards, match pay) and sold in coin packs; buy Common / Rare
--            daily skins and the streak save. Balance cap: Config/Inventory.MAX_COINS.
--   Tickets  EARN-ONLY, never sold for Robux and never inside anything bought with Robux
--            (that keeps cases outside Roblox's paid-random-items rules). The only way
--            to buy cases.
-- Shared/LoginRewards reads LOGIN; LobbyServer/LoginRewardService grants it.
local Economy = {}

Economy.DAY_SECONDS = 86400 -- days are UTC: day index = os.time() // DAY_SECONDS

-- Tickets
Economy.MAX_TICKETS = 100_000
Economy.STARTING_TICKETS = 2 -- a new player can open two Standard cases straight away

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

-- What each case costs in Tickets (wired with the Shop purchases, step 2 of the plan).
Economy.CASE_TICKETS =
	table.freeze({ Standard = 1, Elite = 3, Apex = 6, Knife = 8 }) :: { [string]: number }

function Economy.day(t: number): number
	return t // Economy.DAY_SECONDS
end

return table.freeze(Economy)
