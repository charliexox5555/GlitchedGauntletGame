# Launch hardening (2026-11-27)

The last pass before the battle pass work. Owner's brief (2026-11-27):
- Redo onboarding for the new loadout system. The first match can be longer than first to 3 ("could be 4 ... maybe even the full 5").
- Make movement and game functionality more satisfying.
- **Loading:** a regular player saw maps sometimes not load and many loading issues. Wants full optimisation, "everything loads well".
- **Full game deep dive:** check every script, refactor, fix issues and lag.
- **UI on every device:** on a phone, the settings and top bar buttons overlap the scoreboard at the top.
- **Bots:** about half are sometimes glitched (they don't turn, don't move well).
- **Check phone and controller.**
- **Economy:** make it good. No compensation needed: nobody plays or has spent Robux yet.

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
