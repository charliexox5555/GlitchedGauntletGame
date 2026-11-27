# Launch hardening (2026-11-27)

The last pass before the battle pass work. Owner's brief (2026-11-27):
- Redo onboarding for the new loadout system. The first match can be longer than first to 3 ("could be 4 ... maybe even the full 5").
- Make movement and game functionality more satisfying.
- **Loading:** a regular player saw maps sometimes not load and many loading issues. Wants full optimisation, "everything loads well".
- **Full game deep dive:** check every script, refactor, fix issues and lag.
- **UI on every device:** on a phone, the settings and top bar buttons overlap the scoreboard at the top.
- **Bots:** about half are sometimes glitched (they don't turn, don't move well).
- **Check phone and controller.**
- **Onboarding matches leave the hub** (owner 2026-11-27): matches 1-2 teleport to a reserved server like every match (less lobby load); fast, clean teleport loading makes that fine.
- **Economy:** make it good. No compensation needed: nobody plays or has spent Robux yet.

## Why: the retention signal (owner, 2026-11-27)
The old game (Power Duels, before the draft and loadout update) got Home recommendations. Thumbnails: **CTR over 4%**. **Qualified play-through rate: 0.26%, 0.53% and 0.69%** on different thumbnails. **Average playtime under 5 minutes.** The thumbnails bring people in, but the first minutes don't hold them. Every workstream here is judged by what a brand-new player sees and feels in their first 2-3 minutes, phone first.
- The funnels to read in Creator Dashboard (Analytics → Funnels / Custom events) for where the old game lost people: `Onboarding_v2`, `Onboarding`, `Matchmaking`, `MapFlow`, and the `MatchLeft` / `MapLeftEarly` events (`src/lobby/server/Telemetry.luau`).
- Gaps in those funnels for the new flow:
  - **There is no step between "Save ready" and the first match.** So a bounce on the loading screen or in the first lobby minute can't be told apart from one later on.
  - **The step lists are out of date:**
    - Step 9 is "Free case opened", but onboarding no longer gives a free case.
    - The R4 step comment still says first to 3; the first match is now first to 4.

## Workstreams (parallel sessions, shared checkout on main)
| # | Session | Owns | Done when |
|---|---|---|---|
| 1 | loading-perf | `src/first`, map load/cleanup in reserved servers, preloading, streaming settings, server/client memory and frame time | Maps load every time in 20+ match starts (cold and warm), a measured before/after table (load time, memory, frame time on a phone-class client), the cause of each failure written down |
| 2 | bots | bot AI, movement, aim and turning (`src/server` bot modules) | 0 stuck or frozen bots across 10+ bot matches on every map, the cause found |
| 3 | onboarding | `Config/Onboarding`, `OnboardingController`, the onboarding parts of `DraftService` / `MatchService` / `ProgressionService` | A fresh profile plays through on the starter loadout (no guns handed out that they don't own, no free case). First match is first to 4. One new thing per round. Tested end to end |
| 4 | mobile-ui | layout of lobby and match UI on phone (667x375, 844x390), tablet and controller (TopBar, Scoreboard, Settings, HUD, Locker, Shop, pack opening, draft) | No overlaps at those sizes (captures), every screen usable with a gamepad, the scoreboard/top-bar overlap fixed |
| 5 | economy | `Config/Economy`, `Config/Loadout` PRICES, coin payouts, `Config/Products` coin packs, pass rewards (numbers only) | A table: coins per match and per hour against gun and pack prices, the first unlock in about 2-3 matches, a full gun set in a reasonable time. Numbers changed in config |
| 6 | code-audit | everything not owned above (report first) | `lihfolk:audit` over every Luau file, a ranked findings note, fixes in unowned files, findings in owned files passed to the owning session |

Next wave, after these report: movement and gunplay feel (satisfying movement), the audit's routed fixes, then a final phone + controller + bot-match check of the whole build.
Rules for every session: CLAUDE.md, the `gauntlet-vault` skill, exact-path commits on main, no push. Studio is shared: check `get_studio_state` before Play, keep runs short and stop them after.
