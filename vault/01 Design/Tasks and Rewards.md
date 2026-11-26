# Tasks and Rewards (brainstorm, 2026-11-25)

**Status:** brainstorm for the next update. Nothing is built and nothing is locked. Numbers are a first pass to tune.

## What already exists (the system builds on these)
- **Coins** (earned + sold) and **Tickets** (earn-only, the only way to buy cases: Standard 1, Elite 3, Apex 6, Knife 8). `src/shared/Config/Economy.luau`, [Shop Economy](Shop%20Economy%20and%20Art%20v1.md).
- Match pay: finish 15c, win 20c, bot-only half, **cap 400c/day**. Login loop pays 6 Tickets + 2,500c + a Standard case a week.
- Levels/XP are designed ([Progression](Progression.md)); `LEVEL_REWARDS` is empty.
- The lobby HUD already has a hidden **`LobbyTasks`** panel with **three task rows** (progress, count, coin reward), and the HIDE SIDE TASKS setting already hides it ([UI Lobby HUD](../02%20Art/UI%20Lobby%20HUD.md)).
- Player-facing word for Mods is now **powers**. The Range is closed at soft launch (`Release.RANGE_OPEN = false`).

## Proposed shape
- **The Path:** 6 sets, done in order. Each set has **3 parts**, each part has **3 tasks** (a part can have 2 or 4 when it suits). You see one part at a time, so the three-row panel fits as is.
- **Rewards:** each task pays coins; finishing a part pays a coin bonus; finishing a set pays **Tickets** (the existing currency, so a set ends with "go open a case"). The last set pays a **Knife Case**.
- **Daily tasks** stay a separate, later track (3 small coin tasks a day, reset daily).
- Task coins sit outside the 400c/day match cap.

| # | Set | Aimed at | Coins per task | Part bonus | Set reward |
|---|---|---|---|---|---|
| 1 | Recruit | first session | 50 | 100 | 1 Ticket |
| 2 | Rookie | first 2–3 days | 75 | 150 | 2 Tickets |
| 3 | Contender | first week | 100 | 200 | 2 Tickets |
| 4 | Duelist | week 2 | 125 | 250 | 3 Tickets |
| 5 | Veteran | week 3 | 150 | 300 | 4 Tickets |
| 6 | Champion | week 4+ | 200 | 400 | Knife Case + title |

Whole path: about 10,500 coins, 12 Tickets and a Knife Case.

## Task ideas per set
**1 Recruit** (bots count)
- Part 1: finish a match · draft 3 powers · get your first elimination
- Part 2: equip a skin in the Locker (the Starter Case gives one) · use powers 5 times · win a round
- Part 3: win a match · play a pad duel · hit 20 shots at the Range (swap for "play 3 matches" while the Range is closed)

**2 Rookie**
- Part 1: play a 2v2 · play a 3v3 · get 10 eliminations
- Part 2: use 5 different powers · win 3 matches · get an elimination with every weapon tier in one match
- Part 3: play a match with a party · play on 4 different maps · win 5 rounds

**3 Contender**
- Part 1: win 5 matches · get 25 eliminations · upgrade a power to level 2
- Part 2: get a double elimination · win a round without dying · revive a downed teammate
- Part 3: win with a Glitched card · open a case · win 2 matches in a row

**4 Duelist**
- Part 1: win 3 1v1s · get 50 eliminations · win a match without losing a round
- Part 2: reach a 3-win streak · win on 8 different maps · use every power once
- Part 3: win a round as your team's last player alive · get 10 eliminations with Sidearms · win 10 matches

**5 Veteran**
- Part 1: get 100 eliminations · upgrade a power to level 3 · win 15 matches
- Part 2: play every map · win 3 3v3s · get a triple elimination
- Part 3: win 10 rounds without dying · win 5 2v2s · reach level 15

**6 Champion**
- Part 1: get 250 eliminations · reach a 5-win streak · win 30 matches
- Part 2: eliminate the whole enemy team alone in a 3v3 round · win 5 flawless matches · win 10 1v1s
- Part 3: win 50 matches · get 500 eliminations · finish every other set (auto)

## Rules to decide later
- Bots: full credit in Recruit; after that, bot-only matches count half (like match pay) or not at all for win tasks.
- Farming: wins/eliminations from pad duels against the same friend could be capped per opponent per day.
- Every count is server-side (match results, kills), never sent by the client.
- Weapon tier names disagree between Home (Sidearm/Light/Heavy/Elite) and [Weapons](Weapons.md) (T4 Wildcard); task text must use whichever is current.

## Open questions for the owner
1. Six sets, or fewer/more?
2. One-time path, or does it reset with a season?
3. Do bot eliminations and wins count after Recruit?
4. Final reward: Knife Case, an exclusive skin, a title, or all three?
5. Daily tasks in the same update, or the Path first?
