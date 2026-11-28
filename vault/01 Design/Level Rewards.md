# Level rewards (player levels and gun milestones)

Owner 2026-11-28: "We should honestly add level rewards if we can, and also gun level rewards. Just give coins, rarely tickets and maybe charm case, etc. Just simple things."

Fills the two empty slots left for later: `Config/Progression.LEVEL_REWARDS` ([Progression](Progression.md) A.6) and `Config/GunLevels.REWARDS` ([Gun Levels](Gun%20Levels.md), "Reward at LV N"). Claude's proposal, 2026-11-28; **the owner approves the table**, numbers are config only.

## The table

### Player level-up (every level, no cap on levels)
- **Coins every level: 20 + 5 × level, at most 150** (level 2: 30, level 10: 70, level 20: 120, level 26 on: 150).
- **On top, one extra:** every **50** levels an **Overdrive Box**, else every **10** levels a **Strike Box**, else every **5** levels **1 Ticket**.

| Level | Reward | Running total from level 2 | Rough time (Progression curve) |
|---|---|---|---|
| 2 | 30 coins | 30 | match 2 |
| 5 | 45 coins + 1 Ticket | 150 coins, 1 Ticket | ~1 h |
| 10 | 70 coins + Strike Box | 450 coins, 1 Ticket, 1 box | ~3 h |
| 15 | 95 coins + 1 Ticket | 875 coins, 2 Tickets, 1 box | ~14 h vs bots |
| 20 | 120 coins + Strike Box | 1,425 coins, 2 Tickets, 2 boxes | |
| 30 | 150 coins + Strike Box | 2,850 coins, 3 Tickets, 3 boxes | ~46 h vs bots |
| 50 | 150 coins + Overdrive Box | 5,850 coins, 5 Tickets, 4 + 1 boxes | ~450 matches |

### Gun milestones (per gun, levels 5 to 50)
| LV | 5 | 10 | 15 | 20 | 25 | 30 | 35 | 40 | 45 | 50 |
|---|---|---|---|---|---|---|---|---|---|---|
| Coins | 50 | 100 | 150 | 200 | 250 | 300 | 350 | 400 | 450 | 500 |
| Extra | | | 1 Ticket | | **Strike Box** | | 1 Ticket | | 1 Ticket | **Overdrive Box** |

A maxed gun has paid 2,750 coins, 3 Tickets and 2 boxes over ~56 h of bot play with it.

### Why these numbers
- **Against the gun grind (30,900 coins for the set):** by about 12 h a player has ~900 coins from levels plus a few hundred from their two guns' first milestones (5 at 0.7 h, 10 at 2.5 h): about 4-5% of the set. Levels never pay for the guns; they top up match pay (~145 coins an hour late game).
- **Tickets stay rare:** about 1 per 10 player levels and 3 per maxed gun, next to 6 a week from login. Still earn-only.
- **Charm boxes** (850 coins in the Shop) are the "big" level moments: every 10 player levels, gun LV 25 and 50.
- **Coin levels:** a gun milestone reached by buying a level with coins pays **its coins only**; its Ticket or box comes from play. Tickets are never inside anything coins (and so Robux) can buy ([Shop Economy](Shop%20Economy%20and%20Art%20v1.md), Config/Economy), and the boxes are paid random items. Buying LV 1 → 30 costs ~28,700 coins and pays back 1,050. Rewards are earned, not bought, so no PolicyService gate.

## Build (2026-11-28)
- **Rules:** `src/shared/LevelRewards.luau`: `player(level)`, `gun(level)`, `grant(data, paid, "player" | "gun", from, to, coinsOnly?)` (pays each level in (from, to] in place, capped at MAX_COINS / MAX_TICKETS / the item's maxStack, at most 50 levels a write), `label(coins, tickets, items)`.
- **Paid inside the write that made the level:** `ProgressionService.report` (the match write, txId `m:<match>:<user>`) after `Progress.apply` and `GunLevels.applyMatch`; `LockerService` coin level (`coinsOnly`). Levels only go up, so a level crossed in one write is never crossed again: **no new save field, no VERSION bump**, and a repeated report is stopped by its txId.
- **Wire:** `ProgressEvent` "gain" gains `levelReward = { coins, tickets, items, levels }` and `gunRewards = { [gunId] = same }`. `LockerGunRequest` reply gains a 5th value, the milestone the coin level paid.
- **Screen:** a gold `Reward` line (Studio-built, hidden) in `MatchEndScreen.Canvas.Right.Progress` (y 94) and `GunProgress` (y 50); `ProgressController` fills it ("LV 10 REWARD  +70 COINS · STRIKE BOX"), pops it in after LEVEL UP / the stat step and grows the card by the line (100 → 122, 58 → 78) only while it shows. The gun row prefers a gun that paid a milestone. Locker card: "LV 25: 250 COINS · STRIKE BOX" instead of "Reward at LV 25"; the coin level toast adds "+250 COINS".
- **Telemetry:** `Level reward coins` / `Level reward tickets` / `Level reward item` (value = amount; label `Player` / `Gun`, items `Player CaseStrikeBox`), `Telemetry.levelReward`.

## Tests (Studio, 2026-11-28)
- **Rules:** lint clean (`stylua --check src`, `selene src` 0 errors, the 3 warnings are another session's Locker work), Rojo build clean. No type checker run outside Studio.
- **Match write pays once:** test save seeded 1 XP short of player LV 10 and the Classic 1 XP short of LV 25; `ServerRole = Match`, `BotMatch = 1v1`, `QuickMatch`. One lost round: **LV 10, Classic LV 25, coins 30,393 → 30,713 (+70 +250; a lost bot round with no kill pays 0 match coins), Strike Boxes 3 → 5**, one new `m:` tx in the save.
- **End screen:** `LV 10 · LEVEL UP` with the gold line `LV 10 REWARD  +70 COINS · STRIKE BOX` (card 100 → 122), the gun row `CLASSIC LV 25 · +0.4% ACCURACY` with `LV 25 REWARD  +250 COINS · STRIKE BOX` (58 → 78). Capture in the session transcript.
- **Rejoin:** a new Play showed LV 10, 30,713 coins and the Classic at 6,721 XP.
- **Repeat:** `ProgressionService.report` sent again from the MCP with the same match key and a much bigger result: the save didn't change (the txId). The positive control (a new key) wasn't run: Play stopped under it (other sessions share Studio).
- **Coin level:** Vandal LV 3 → 4 (20 coins) → 5 (330 coins): 30,713 → 30,413 = −350 + 50, Tickets unchanged; the reply carried `{ coins = 50, levels = { 5 } }`. The Locker card then read `LV 10: 100 COINS`.
- Test save restored from the backup afterwards (30,393 coins, LV 3, Classic 25,970, 3 Strike Boxes).
- **Not done:** the phone size (667x375) of the two Reward lines; the Locker toast and card seen on screen (read from the labels only).
- **Owner:** save the place (two `Reward` TextLabels in `UI.Match.MatchEndScreen.Canvas.Right.Progress` / `GunProgress`).
