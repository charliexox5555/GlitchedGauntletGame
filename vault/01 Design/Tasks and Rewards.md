# Tasks and Rewards (the task Path)

**Status (2026-11-26):** owner picked every set and rule, and it is **built**: tracking, saving, rewards and the lobby panel (see [Build](#build-2026-11-26)). Not published. First brainstorm: 2026-11-25.

## Locked rules (owner 2026-11-26)
- **One-time Path, per account:** 6 sets in order (Recruit → Rookie → Contender → Duelist → Veteran → Champion), each **3 parts of 3 tasks** (Veteran part 3 has 4). Later updates add sets on the end. Daily tasks come later, as a separate track.
- **Starts back in the lobby after match 2** (`START_AFTER_MATCHES` = `Config/Match ONBOARDING_MATCHES`), when the lobby opens up. Recruit part 1 is the Range.
- **One part shows at a time** (the existing three-row `LobbyTasks` panel; HIDE SIDE TASKS already hides it).
- **Counts only while the part is showing.** `level` tasks check the current level.
- **Bots count everywhere** (quiet servers never block progress). Pad-duel wins against the same friend still need a farm cap.
- **Coins are the main reward.** Gun skins stay premium: a **Ticket only at the end of sets 2, 4 and 6** (3 in the whole Path).
- **Range tasks only in Recruit.**
- Every count is decided by the server (match results, range hits), never sent by the client.

## Rewards
| # | Set | Coins per task | Part bonus | Set reward |
|---|---|---|---|---|
| 1 | Recruit | 50 | 100 | 200 coins |
| 2 | Rookie | 75 | 150 | 1 Ticket |
| 3 | Contender | 100 | 200 | 400 coins |
| 4 | Duelist | 125 | 250 | 1 Ticket |
| 5 | Veteran | 150 | 300 | 600 coins |
| 6 | Champion | 200 | 400 | 1 Ticket + **Champion** title + 1,000 coins |

Whole Path: **12,850 coins, 3 Tickets, the title.** The coin set rewards on sets 1, 3 and 5 (200/400/600) are my fill-in for "other set ends pay a bigger coin bonus"; tune them freely.

## The tasks
**1 Recruit**
- P1: Visit the Range · Shatter 10 Range targets · Down 3 Range bots
- P2: Finish 2 matches · Draft 6 powers · Get 5 eliminations
- P3: Win 2 matches · Get 10 eliminations · Use powers 15 times

**2 Rookie**
- P1: Play a 1v1 · Play a 3v3 · Get 15 eliminations
- P2: Use 5 different powers · Get an elimination with every weapon tier in one match · Win 3 matches
- P3: Get 5 headshot eliminations · Win 5 matches · Get a double elimination

**3 Contender**
- P1: Win 5 matches · Get 30 eliminations · Take a power to level 2 in a match
- P2: Win 3 rounds without dying · Get 2 double eliminations · Win a match after picking a Glitched power
- P3: Win 2 matches in a row · Play on 6 different maps · Win 3 2v2s

**4 Duelist**
- P1: Win 5 1v1s · Get 60 eliminations · Win a match without losing a round
- P2: Win 3 matches in a row · Win on 8 different maps · Use every power at least once
- P3: Win a round as your team's last player alive · Get 10 eliminations with a Sidearm · Win 12 matches

**5 Veteran**
- P1: Win 15 matches · Get 25 headshot eliminations · Reach level 15
- P2: Win 5 1v1s · Win 5 2v2s · Win 5 3v3s
- P3 (4 tasks): Win 15 rounds without dying · Reach level 20 · Win 3 matches without losing a round · Get 30 headshot eliminations

**6 Champion**
- P1: Get 150 eliminations · Win 5 matches in a row · Win 20 matches
- P2: Eliminate the whole enemy team alone in a 3v3 round · Win 5 matches without losing a round · Win 10 1v1s
- P3: Win 30 matches · Get 300 eliminations · Reach level 30

## What the tracker counts
Task kinds in `Config/Tasks` (`Kind`): range visit, range targets shattered, range bots downed; match finished / won (by team size), flawless win, Glitched win, win streak (from when the task appears), round won / without dying / clutch / ace; eliminations (by weapon tier), headshot eliminations, double eliminations (2 within `MULTI_ELIM_WINDOW` = 4 s), every tier in one match; powers drafted / used / distinct / taken to level N; distinct maps played / won; player level.
- `teamSize`: the Lobby plan's size, else the bigger side; a pad duel counts as its size (1v1). No farm cap yet.
- Weapon tier names disagree between Home (Sidearm/Light/Heavy/Elite) and [Weapons](Weapons.md) (T4 Wildcard); task text only names tier 1 (Sidearm).

## Build (2026-11-26)
- **Data:** `Config/Tasks` (the list; `RANGE_FLUSH` 8 s, `MULTI_ELIM_WINDOW` 4 s), `shared/TaskPath` (state, clean/valid, `applyMatch` / `applyRange`, payouts), saved as `tasks` in `shared/PlayerData`, published as the `Tasks` StringValue. Never rename a shipped task id or lower a shipped target.
- **Matches:** `StatsService` counts (headshots, multi eliminations, tiers, round wins without dying / clutch / ace, picks, uses, power levels, Glitched pick); `MatchService` adds played / won / flawless / team size / map and passes it to `ProgressionService.report`, which moves the Path **in the same write as XP and match pay** (the match's txId makes a retry pay once). Only when the player had finished 2 matches before this one. All of it is pcall-guarded so it can never cost XP.
- **Range:** `Range/RangeEvents` (visit, target shattered, bot downed) → `TaskService` batches them and writes at once when one finishes a task (else after 8 s, on leave, on shutdown; busy writes retried 3 times).
- **Client:** `Controllers/TaskPanel` fills `LobbyTasks.TopLeft.Tasks` (set name, PART n / 3, three rows from the `Row` template, the part bonus line) and toasts each finished task / set / Ticket / title through the lobby toast. The panel and toast stay up in the Range (`ArmedHideController.RANGE_KEEP`).
- **Admin (owner only):** Utility tab → TASK PATH → SKIP PART (no rewards) / RESET PATH; RESET PROFILE also resets the Path.
- **Tested in Studio:** 23 logic checks in edit (every set, streak reset, distinct maps, level tasks, the Champion title, JSON round trip, junk saves, NaN); panel hidden at 1 match and shown at 2 (RECRUIT, PART 1 / 3); Range visit paid 50 coins, saved and toasted; panel up in the Range; a 1v1 bot match moved Recruit P2 to play 1/2, draft 5/6 with no errors; a match write without Path changes still saves XP and pay.
- **Not tested:** shattering targets and downing bots (the MCP can't fire the gun), eliminations / headshots / clutch / ace in a real fight, the toast's look, phones, a real live server.

## Still open
- Champion title: saved (`tasks.title`) but not shown anywhere yet (profile, player list, match top bar).
- Pad-duel farm cap.
- The coin set rewards for sets 1, 3 and 5 (200 / 400 / 600, my fill-in).
- Toasts for tasks finished in a match server are sent but the match client has no lobby toast; the panel shows the new progress back in the lobby.
