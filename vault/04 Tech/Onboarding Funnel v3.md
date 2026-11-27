# Onboarding funnel v3 (2026-11-27)

**What it's for:** the old game's thumbnails got clicks (CTR over 4%), but players left inside 5 minutes (qualified play-through 0.26-0.69%). See [Launch Hardening](../05%20Production/Launch%20Hardening%202026-11-27.md) → "Why: the retention signal". **Onboarding_v3** shows the exact step where a first-time player leaves today's flow. The flow is in [First Ten Minutes](../01%20Design/First%20Ten%20Minutes.md) §13: first to 4, the player's own guns, no free case, and match 1 runs on a reserved server.

## Where to find each funnel
Creator Hub → your experience → **Analytics → Funnels** (the funnel analytics page). Each funnel is a tab. Data shows up the next day (custom analytics are aggregated daily, allow up to 24 h). Nothing is sent from Studio.

| Funnel | Kind | Use it for |
|---|---|---|
| **Onboarding_v3** | custom funnel, one session per player | **The one to read from this launch on.** 27 steps, below. |
| Onboarding_v2 | custom funnel | The 2026-11-26 flow. Kept so the two can be compared, but its "Free case opened" step no longer fires. |
| Onboarding | Roblox onboarding funnel | The oldest list (19 steps). Kept for comparison with the old game. |
| OnboardingCase | custom funnel | Dead: there's no onboarding case now. |
| Matchmaking / Match / MapFlow | recurring funnels | Every queue / match / map, not just new players. |

Custom events (Analytics → Custom events) to read next to it: `MatchLeft` (the round, the phase and the score when someone quit mid-match; `first:Mobile` = a first match on a phone), `MapLeftEarly`, `Save ready seconds`, `GunUnlocked`.

**Read it right:**
- **Set the date range to start after the update goes live.** Steps are new, and a range that spans the change shows a warning.
- **The cohort:** brand-new saves only, with fewer than 3 matches when the save loads. Funnels are cohorted by the day a player entered step 1.
- **Skipped steps count as passed.** A player who wins match 1 4-0 never plays R5-R7, and a player who goes straight to match 2 never opens the Locker. Roblox credits them with those steps once they log a later one. So a drop at a step means "**left at that point**", not "skipped it".
- Each step counts once per player, even if two servers send it.

## The steps, and what a drop at each one points to
"Drop at N" = players who reached the step before N and never got to N.

| # | Step | Sent by | A drop here means |
|---|---|---|---|
| 1 | Save ready | PlayerDataService (save loaded) | Left before their save even loaded: the join itself, or a very slow DataStore. Compare with `Save ready seconds`. |
| 2 | Loading screen closed | `src/first` LoadingScreen (via remote) | **Left on the loading screen.** Loading is too long or looks stuck. Check `[Health] C loading screen` times and phones first. |
| 3 | First move in lobby | lobby OnboardingController (via remote) | Left in the ~1.2 s between the screen closing and the auto-queue, without touching anything. Should be close to 0. Step 4's field says whether they had moved (`moved` / `still`). |
| 4 | Match 1 queued | QueueService | The auto-queue didn't fire, or they left right as it did. A big drop = auto-queue bug. |
| 5 | Match 1 server reached | MatchHost (hosted arrival; `studio` in Studio) | **Lost in the teleport.** Teleport failures, or a second loading screen that's too long. The loading-perf workstream's area. |
| 6 | M1 R1 live | MatchService | Arrived but the first round never went live: map load, the draft, the 3-2-1, or a match that never started. |
| 7 | M1 R1 done | MatchService | **Quit during the first gunfight.** Sidearm round too hard or too long, controls (phones), or "I don't get it". Read with `MatchLeft` (phase, score, device). |
| 8 | M1 R2 live | MatchService | Left between rounds 1 and 2, at **the first draft** (Dash or Updraft). The pick screen confuses or bores them. |
| 9 | M1 R2 done | MatchService | Quit mid round 2: first power plus the Havoc. |
| 10 | M1 R3 live | MatchService | Left at the second pick (Frost or Molly). |
| 11 | M1 R3 done | MatchService | Quit mid round 3: the throws. |
| 12 | M1 R4 live | MatchService | Left at the Glitched card screen. |
| 13 | M1 R4 done | MatchService | Quit mid round 4. A 4-0 match ends here. |
| 14-19 | M1 R5-R7 live / done | MatchService | Only longer matches play these. Rounds past 4 drag: think about it if there are many drops here. |
| 20 | Match 1 saved | ProgressionService | Left on the match end screen before the save landed (or the save failed). |
| 21 | Back in lobby | OnboardingService | Left on the end screen instead of coming back (NEXT MATCH skips this; it's credited). |
| 22 | Locker callout shown | lobby OnboardingController (via remote, checked against the save) | Back in the lobby but left before the UNLOCK badge showed. Also: no badge (not enough coins), so check the economy. |
| 23 | Locker opened from callout | OnboardingService (seen bit) | **Saw the UNLOCK badge and didn't tap it.** The badge doesn't read, or they didn't care. |
| 24 | First gun unlocked | LockerService (field = gun) | Opened the Locker and didn't buy. Price, or the confirm step. |
| 25 | Match 2 started | MatchService (round 1 live) | **Left in the lobby after match 1.** The most important "do they want more" number. |
| 26 | Match 2 saved | ProgressionService | Quit during match 2: the real draft (three cards, then upgrade columns). |
| 27 | Match 3 started | MatchService (field = mode) | Left after match 2: the lobby opening up (Shop, Range, Party), the favorite ask, or the first normal queue wait. |

## How it's built (for the next session)
- `src/lobby/server/Telemetry.luau`:
  - `Telemetry.onboardingV3(player, step, label?, matches?)`, `onboardingV3Round(player, round, done)`, `Telemetry.V3` step ids.
  - Each step is sent once per player per server and forward only. It's only sent at its saved-match count (steps 1-19 before match 1 is saved, and so on). Steps 1-4 are only sent in a public lobby, so the reserved server never re-sends them.
  - Steps sent before the save loads (the hosted arrival) wait for it.
  - The round steps come from `Config/Onboarding SCRIPT[1].roundsToWin`, up to `2 × N − 1` rounds. **If match 1 becomes first to 5, the step numbers after the rounds move, so rename the funnel to `Onboarding_v4`.**
- **Client steps** go through the existing `OnboardingRequest` remote, action `("step", key)`. The key is `loaded`, `moved` or `callout`.
  - It's rate-limited (OnbConfig.RATE) and refused before the save loads.
  - Only those three keys are accepted. `moved` needs `loaded` first. `callout` needs the save to say the callout is due.
  - It never writes the save. A lying client can at most mark its own funnel early.
- Limits: 10 funnels per experience (we use 6), 100 steps per funnel, and 3 custom fields from small fixed sets (mode, gun id, `moved` / `still`, `teleport` / `studio`).

## Studio check (2026-11-27)
Workspace `TelemetryLog = true` + `FreshOnboarding = true`, two runs:
- **Run 1, fresh save through match 2:**
  - Steps 1, 2, 4 (`still`) and 5 (`studio`) printed. The auto-queue came before any input, so step 3 was correctly not printed.
  - Steps 6-15: match 1 went to five rounds (one round won by the bot teammate).
  - Steps 20-26: the UNLOCK badge showed (22). The seen bit and a Spectre unlock were sent through the real remotes (`OnboardingRequest` "seen" 8, `LockerGunRequest` "unlock"), giving 23 and 24. Then PLAY gave 25-26.
  - Each step printed once, in order, with no script errors.
- **Run 2:** moved right after the loading screen closed. Steps 1, 2, 3, 4 (`moved`), 5 and 6 printed in order.
- **Not seen:**
  - **Step 27:** match 3 goes through the real queue, and Studio can't teleport. It will first show live.
  - Steps 16-19 (rounds 6-7).
  - The real reserved-server arrival.
  - Phones.
