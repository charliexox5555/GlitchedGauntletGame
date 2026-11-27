# First Ten Minutes (plan, 2026-11-26)

The owner's brief: plan the first ten minutes so new players get hooked and learn the game **by playing**: one new thing at a time, nobody talking at them, no menus they can't understand yet ("okay, I pick one of these 3 guns. What gun do I pick?"). This note is the plan; §8 says what was built (2026-11-26). **The match flow of §3-§5 and §8 is replaced by [§13, onboarding for the loadout update](#13-onboarding-for-the-loadout-update-2026-11-27)** (2026-11-27: owned guns, round 1 sidearms, no tiers, no free case). The rules (§1), the learn-by-playing call (§2) and the readouts stay.

Inputs:
- The live funnel ([readout 2026-11-26](../05%20Production/Fantasy%20and%20Retention%20Plan%202026-11-25.md#8-readout-2026-11-26-61-players-last-hour-ad-traffic)).
- The owner's run through RIVALS' onboarding.
- The current flow ([Handoff - Onboarding and Bots](../05%20Production/Handoff%20-%20Onboarding%20and%20Bots.md), `Config/Onboarding`, `Config/Match`).
- LihFolk: *First-Time User Experience and Onboarding*, *Onboarding and FTUE - Tutorials That Keep Players*, *Tutorial Step Design Patterns - Teach by Doing*, *Onboarding Accessibility and Cross-Device Prompts*, *Skippable Tutorials and Replayable Tips*.

## 1. Rules

1. **Fight first.** Control within 10 s of the arena, first shot within 20 s, first kill or reward inside 60 s (LihFolk FTUE rules of thumb). Roblox now counts leaving within 60 s and within 61-180 s against the game.
2. **One new thing per step.** Each round or screen adds exactly one idea, and the player uses it straight away.
3. **Teach with the game, not with words.**
   - No narrator, no text boxes, no "Next" slides.
   - Allowed: a pulsing button with its real key on it, a one- or two-word game banner ("GUNS UP"), a highlight, a sound.
   - Keys come from the bindings and change with the device (`Config/Input`, `UserInputService.PreferredInput`).
4. **Every choice has a safe default.** Something is always preselected, so doing nothing is fine.
5. **First time only.** A hint shows until the player has done the thing once, then never again (saved). Hints never stack: at most one on screen, none in the middle of a firefight.
6. **The game opens up as a reward.** Menus appear when they mean something. Soft gates, not a cage: Settings and the Locker always work.
7. **Friends are never forced.** A player who joins a friend or arrives in a party is never auto-started.

## 2. Tutorial room or learn-by-playing? (Claude's call: learn-by-playing)

**No separate tutorial and no dummy room.** Reasons:
- RIVALS, the game our players compare us to, has none.
- A forced tutorial is exactly the 60-180 s bounce Roblox penalises.
- The owner doesn't want anyone talking to players.
- The Range (being built now) is the **optional** practice place: reachable from the lobby once it unlocks, never forced. The bots in a new player's first two matches are the tutorial: Rookie bots, red enemies, Arena only.

## 3. What a new player sees, minute by minute

> **[REPLACED 2026-11-27 by §13.]** Handed-out guns, GUNS UP tiers and the free case no longer exist. Kept as history.

Today a new player reaches the fight like this: loading → auto-start → **round 1's pick screen** (3 guns and 3 powers, up to 22 s, ends early on lock-in) → 3-2-1 → fight. Beginner already skips the map vote (Arena only). The changes below are marked **NEW**; everything else is already built.

### 0:00-0:20 Arrive
- Loading screen (2.2 s minimum hold), then straight into a match in this server (`INSTANT_MATCHES`). That's 97% of players today.
- **NEW: the friend rule.** If the player joined by following a friend, arrived in a party, or has a friend in this server, there's no auto-start. They land in the lobby with the PLAY bubble and Party lit. The PLAY shortcut stays (straight into Beginner).

### 0:20 Match 1, round 1: shoot (no menus)
- **NEW: no pick screen in round 1 of match 1.** The player spawns behind the barrier, already holding a good Light gun and with **Dash** in E. Only the 3-2-1, then the barrier drops.
- **Learned:** move, shoot, red enemies are the targets, your teammate fights with you.
- **Why Dash:** it is the one power that is a single tap (`activation = Instant`) and makes you *feel* fast at once. Molly and Frost are held throws, too much for second one.
- **NEW hint:** the Dash circle pulses with its key (E, or the touch button) once the barrier drops, until the first use. If they never press it, it stops after the round. No words.
- **NEW hint:** standing still for 6 s in a live round pulses the move keys or the stick. This is the only basic-controls hint; Roblox players know WASD and click.
- Rookie bots, red enemies and mobile auto-shoot are as today.

### ~1:10 Between rounds 1 and 2: the first pick (one decision)
- **NEW: two big cards, powers only.** "Pick a new power" is said by the screen layout, not text: two cards side by side, one gold-lit as the default. No gun row: the gun is handed out (below).
- The pair is curated, not rolled:
  - **Updraft** (Q, a single tap that throws you up).
  - **Frost** (T, a held throw, the first held power, with its existing held hint "LMB Throw").
- 9 s timer (Beginner's `SELECT_TIME`). Picking skips straight to the 3-2-1.
- **NEW: GUNS UP.** At the 3-2-1, the new tier's gun drops into their hands with a short "GUNS UP · HEAVY" banner in the one banner slot and a sound. **Learned:** the guns get bigger every round, with no gun choice needed.
- The new power's circle pulses with its key until first use (same hint as Dash).

### ~2:20 Between rounds 2 and 3: the Glitched card
- **NEW: one card, the wow.** Their Dash turns Glitched (the Desync path, `G`): a glitch-styled card, preselected, with its own reveal sound. One click or just wait.
- **Learned:** powers *level up*, and Glitched cards break the rules. This is the hook the name promises ("stack them until you're unstoppable").
- Today the Glitched card is guaranteed from round 2 (`GLITCH.onboardingRound = 2`). **Move it to 3** so round 2 teaches a new power and round 3 teaches the upgrade.

### Round 4-5 if the match goes long
- Normal power columns (new power or A/B upgrade). Guns are still handed out.

### ~4:30 Match 1 ends: the reward lands where they are
- Win cutscene and results as today, then:
  1. The XP bar fills, then LEVEL UP (`ProgressController`, built).
  2. **NEW: the free Epic case opens right on the results screen** (the in-world opening runs in this lobby server, so `CaseOpening` is there). The skin is **equipped automatically** and shown in their hands. Today this is the 6-player leak: the hub, the Backpack, the case, then equip.
  3. **NEW: NEXT MATCH starts by itself in 5 s** (the second instant match) with a small LOBBY button. The friend rule applies: a player with a friend here gets a plain choice instead of a countdown.
- **Learned:** playing earns things, and the next match is one moment away.

### ~5:00 Match 2: you choose your power
- **NEW: round 1 has a pick screen, powers only:** the real draft row, one new power per slot (Q / E / T), three cards, a 9 s timer.
- From round 2: the real columns, new powers or **A/B upgrades** of the ones they have.
- **Learned:** the draft itself, with no gun row yet.
- Guns are still handed out with GUNS UP.
- First to 3, like today (C1).

### ~9:00 Back in the lobby: the game opens up
- **NEW: the unlocks move to after match 2** (`UNLOCKS at = 2`, today 1). One NEW pop at a time, gold on the next thing to do:
  - **PLAY**: still straight into Beginner 2v2 (`PLAY_SHORTCUT_BELOW 2 → 3`).
  - **Locker**: their new skin is there.
  - **Shop**, **Party**.
  - **Range**: when it ships.
- **NEW: the first task appears now**, one line, not a panel of six. The owner is right that a new player doesn't care about tasks before they like the game.
- **NEW: the favorite prompt fires after the first match win** (RIVALS: first win or 5 duels), not on a fixed match count. It stays a plain ask, never rewarded.

### Match 3 and on: the full game
- **NEW: the gun row joins the pick screen in match 3.** Cards carry a role word ("CLOSE", "LONG", "ALL-ROUND") so the choice reads at a glance.
- The map vote appears when they leave Beginner (level 5, `BEGINNER_MAX_LEVEL`).

## 4. The order things are introduced

| # | When | New thing | How they learn it |
|---|---|---|---|
| 1 | M1 R1 | Move, shoot, red enemies | Spawned with a gun facing red targets |
| 2 | M1 R1 | A power (Dash) | Its circle pulses with its key |
| 3 | M1 pick 1 | Picking a power | Two big cards, one preselected |
| 4 | M1 R2 | Guns get bigger every round | GUNS UP banner, new gun in hand |
| 5 | M1 R2 | A held power | The existing held hint |
| 6 | M1 pick 2 | Upgrades and Glitched cards | One Glitched card on their Dash |
| 7 | M1 end | Rewards, skins | Case opens on the results screen, auto-equipped |
| 8 | M2 R1 | The full power draft | Real three-slot row, no guns |
| 9 | M2 R2+ | A/B upgrade paths | Real columns |
| 10 | Lobby after M2 | Locker, Shop, Party, Range, first task | One NEW pop at a time |
| 11 | M3 | Picking guns | Gun row with role words |
| 12 | Level 5 | Map vote, all modes | Beginner hides |

Sudden death needs no hint: the closing ring, the tint and the warning tick already say it. If players die outside it often in match 1, add a one-time "GET IN" banner.

## 5. What to build (in this order, each tested in Studio with `FreshOnboarding`)

1. **One onboarding script in config.** `Config/Onboarding.SCRIPT`, by onboarding match and round:
   - `select`: none, powers, or full.
   - `offer`: curated pair, glitch, or the normal deal.
   - `startKit`.
   - `ONBOARDING_GUNS` by phase.

   All the numbers live here, nothing hard-coded.
2. **Server.**
   - `MatchService`: round 1 of onboarding match 1 skips the select and gives the start kit before the 3-2-1.
   - `DraftService`: script-driven offers (curated pair, glitch-only, powers-only) and handed-out guns.
   - Picks are still checked on the server.
3. **Pick screen** (`DraftController` / `Util/DraftScreen`):
   - Hide the gun row when no gun is offered.
   - A two-card and one-card layout.
   - Gold on the default.
4. **First-time hints** (new client `FirstHintsController`):
   - Covers the power pulse, the idle move-key pulse and reload.
   - Saved as bits in a new `onb.hints` field (the current `seen` holds only 3 bits).
   - Device-aware keys; one at a time; never during damage taken in the last 2 s.
5. **GUNS UP moment:** a banner, a sound and the gun in hand at the 3-2-1 of a tier change.
6. **Results screen:**
   - The case reveal and auto-equip.
   - The NEXT MATCH countdown into the second instant match.
   - The LOBBY button.
   - The friend rule.
7. **Lobby:** unlocks at 2, the shortcut below 3, the first task after match 2, the favorite prompt after the first win.
8. **Telemetry:** the funnel steps follow the new flow:
   - "M1 R1 live" comes straight after launch.
   - "Free case opened" and "Match 2 R1 live" move onto the match server.
   - A `FirstHint` event (which hint, seconds to first use).

Security: the only new client input is the pick, and it goes through the existing `DraftService` checks. The case grant and auto-equip stay server-side (`ProgressionService`, `LockerService`).

## 6. How we'll know it worked (a full day of ad traffic, not one hour)

| Step | Now (2026-11-26) | Target |
|---|---|---|
| Arena → first shot | ~10-25 s (round 1 pick screen) | ≤ 10 s |
| M1 R1 live → done | 93% | ≥ 93% (hold) |
| Gaps between rounds, M1 (players lost) | 10 of 59 (17%) | ≤ 8% |
| Match 1 saved → Match 2 R1 live | 58% | ≥ 85% |
| Match 2 completion | 68% | ≥ 85% |
| New-user 5-minute retention | 26.5% | ≥ 45% |

Read `MatchLeft` (phase, last round W/L, device) alongside. If gap quits are mostly right after a lost round, the next step is the loser's extra card (C2).

## 7. Owner decisions

1. Starter power: **Dash** (recommended) or another single-tap power (Updraft, Stim).
2. The first pick's pair: **Updraft + Frost** (recommended).
3. Handed-out guns by tier. Suggested: Light **Prowler** (SMG, forgiving at Arena range), Heavy **Havoc**, Elite **Mauler**.
4. Free case on the results screen with auto-equip (recommended), or keep it in the lobby.
5. Next match auto-start in 5 s after match 1 (recommended), or a big NEXT MATCH button with no countdown.
6. The Range: show it after match 2 as optional practice, or keep it hidden until match 3.

## 8. Built (2026-11-26)

> **[REPLACED 2026-11-27 by §13]** for the match script, the guns and the case. The bug fixes below still hold.

The owner approved the plan and Claude's picks ("I like this … whatever you think is best for the second match"), with two changes: **no friend rule** (everyone goes straight in) and **no auto-start into match 2**.

**What a new player gets now**
1. **Match 1, round 1:** no pick screen. They spawn with the Prowler and Dash, and the fight starts about 4 s after the match opens. In Studio the client showed the pick screen for under a second; the 3-2-1 comes straight after.
2. **Round 2:** two big power cards side by side (Updraft or Frost), with no gun row and LOCK IN under them. The 3-2-1 shows **GUNS UP · Heavy guns** in gold, with the Havoc in hand.
3. **Round 3:** one centred Glitched card (Desync on their Dash), preselected.
4. **First-use nudge** (onboarding matches only): a new power's key turns gold and the cell pops with a shine every 1.6 s until first use. On touch, the button breathes.
5. **Match 1 end:** the gold button is **NEXT MATCH**, the other **LOBBY**. The results stay up about 10 s after the cutscene (`timeNoRematch` 13 → 18).
6. **Back in the lobby either way:** the free case opens by itself (no Backpack clicks) and the skin is equipped. The reveal says "NEW SKIN · EQUIPPED" and has one gold button: **NEXT MATCH** if they pressed it (the server parks that request until the case is open), else NICE.
7. **Match 2:** a power-only pick (three slots), handed-out guns, first to 3.
8. **After match 2:** Locker, Shop, Backpack and Party unlock together (they were after match 1), with one NEW badge on the icon. PLAY stays straight-to-Beginner until match 3.

**Changed from the plan**
- **The free case opens in the lobby, not on the results screen.** The results screen is the arena's victory scene, and the in-world crate lives in the lobby. Opening it the moment they arrive, with no clicks and auto-equip, removes the same steps (the 6 lost at the OPEN click and the 2 at EQUIP).
- **Dropped:**
  - The idle move-key hint: Rookie bots come to you, and RIVALS doesn't have one either.
  - The first task after match 2: tasks aren't built yet.
  - The favorite prompt after the first win: it stays at the lobby after match 2.
  - The `FirstHint` telemetry event: funnel step names are unchanged, so dashboards keep working.

**Bugs found while testing** (both pre-existing, and both could explain part of the "back in the hub" drop):
- **`DuelLoading` could stay on after a match.** With it stuck, the lobby's onboarding never ran (the free case didn't open). `DuelLoadingController` now clears the flag when no cover is on screen.
- **A lobby menu closing as a match started came back on in the lobby with the Router closed.** This left a dead Backpack after match 2. `ArmedHideController` restores every lobby screen that was on, so `LobbyKit.page` now keeps a closed page off.
- **Also fixed:** the NEW tag sat over PLAY. Short callouts are now a badge on the icon's corner.

**Verified in Studio** (fresh ephemeral save, Rookie bots, player idle):
- Rounds 1–3 of match 1 as above.
- The end screen, and NEXT MATCH → lobby → the case opened in 2.5 s → reveal → NEXT MATCH → match 2 started at once (`OnboardingMatch = 2`, power-only pick).
- The LOBBY / timeout path opens the case too.
- After match 2 the lobby is clean, with the menus unlocked.
- No script errors in the console.
- Not verified:
  - A real phone (the touch-button nudge).
  - A player who wins rounds: only losses were played, so round 4–5 and the win path weren't seen.
  - Live analytics.

**How the owner tests it:** F8 admin panel → UTILITIES & RESET → **START FULL ONBOARDING**. The 1-ROUND MATCH switch skips the scripted rounds, so leave it off to see rounds 1–3. Or set Studio `Workspace.FreshOnboarding = true` before Play for a throwaway save.

## 9. Owner playtest notes (2026-11-26)

The owner played it: "I think it's good", with these changes.
- **Free case:** a normal-feeling case for a gun they'll hold in match 2, not a guaranteed Epic ("a higher percent chance of having a better skin, not a higher percent chance of legendary"). `Config/Skins CASES.Starter` now only holds Prowler and Havoc skins: both are handed out in every match 2, because rounds 1–3 are Light then Heavy. The tiers are Common 40, Rare 42, Epic 16, Legendary 2, against the Standard Case's 85/15. Measured in Studio: 29 skins, tier totals as set, and the one Legendary is the Riftforge Prowler. `Case.guns` is the new filter in `SkinCases.pool`.
- **Mobile:** checked in Studio with ForceLayout phone and ForceTouchUI:
  - The round 2 two-card pick, the end screen (NEXT MATCH / LOBBY IN 10) and the reveal all read well.
  - The touch nudge was only a slow scale breath, too easy to miss. The new power's touch button now also gets a **gold ring** until first use ("gold = act now", UI Theme v4 rings).
- **Keybinds and controller** (owner: a rebind didn't change the on-screen key; a controller was told "Q"; the pick screen had no controller buttons):
  - Power key chips (`ModController.keyLabel`) now read the player's live binds (`InputGlyphs.keysFor`) and the same device rule as every other chip (`InputGlyphs.mode`). They are cached until the binds or the device change. Before, they read the defaults and overwrote the chip every frame.
  - The held-power hint and Updraft's Crash Down prompt use the same keys.
  - New `InputGlyphs.padName`: controller button words that match the pad's own icons (Square / L1 on PlayStation, X / LB on Xbox).
  - Pick screen on a controller: LB/RB step through the power cards, the D-pad left/right through the guns, A picks the selected card and X locks in. The hint line says so with the pad's own button names.
  - Verified in Studio with `ForceInput = gamepad`:
    - The R1 chip shows.
    - A server-side rebind to Y switched the chip at once.
    - The pick hint reads "L1 / R1: change power · Square: LOCK IN".
  - Not verified: bumper input on a real pad (MCP can't press pad buttons). The Settings screen itself wasn't changed.
  - No "not set up for controller" text exists in the game; that message is probably Roblox's own.
- **Pad duel camera stuck** (tester, live), two causes found and fixed:
  1. **The Locker's Scriptable camera survived a duel start.** The Locker raises the camera while it's open, and nothing closed it when the match began. `ArmedHideController` now closes any open lobby menu when the player enters a match, and the client host starts every match on the normal follow camera. Reproduced in Studio (Locker open → Scriptable) and fixed (Custom, on the player, 0.3 s after the zone change).
  2. **A character load that never returns blocked every arena spawn** ("LoadCharacter already in progress" × 2 in Studio after returning from a match), leaving the player on the lobby body over the pad. `CharacterService.loadCharacter` now lets a new spawn take over:
     - 2 s after the hung load's body arrives, or
     - after `Avatar.LOAD_STALE` (15 s) with no body.

     It logs "character load hung" (HealthLog) so the live logs show how often. Verified twice in Studio: the takeover logged, then a normal spawn and round 1. Root cause of the hang not found (the lobby respawn after a match); worst case a duel started right after returning waits up to 15 s instead of failing.

## 10. Onboarding_v2 funnel (2026-11-26)
A new custom funnel, **Onboarding_v2**, follows this flow step by step. It uses `AnalyticsService:LogFunnelStepEvent` with one session per player (their UserId) and the same new-player cohort as the old funnel. The old **Onboarding** funnel keeps running unchanged, so the two can be compared. Find it in Creator Hub → Analytics → Funnels.

| # | Step | Fires |
|---|---|---|
| 1 | Save ready | data loaded |
| 2 | Match 1 launched | instant match 1 starts |
| 3 | M1 R1 fight (no pick) | round 1 live |
| 4 | M1 R1 done | round 1 ends |
| 5 | M1 R2 fight (2-card pick) | round 2 live |
| 6 | M1 R3 fight (Glitched card) | round 3 live |
| 7 | Match 1 saved | |
| 8 | Back in lobby | |
| 9 | Free case opened | field 1: "next match" (pressed NEXT MATCH) or "lobby" |
| 10 | Match 2 R1 fight | |
| 11 | Match 2 saved | |
| 12 | Lobby after match 2 | the lobby opens up |
| 13 | Match 3 started | round 1 live of the first queued match; field 1 = mode |

Code: `lobby/server/Telemetry.luau`:
- `onboardingV2` sends a step.
- `V2_FROM_OLD` maps the old steps, so most v2 steps fire where the old ones already do.
- Step 12 fires from `OnboardingService`, step 13 from `MatchService.reportStage`.

Studio check: Workspace attribute `TelemetryLog = true` prints each step to the Output, because nothing is sent from Studio. Verified 2026-11-26 on a full run (fresh save, NEXT MATCH, match 2): steps 1–12 printed in order, the case step with "(next match)". Step 13 needs a queued match (teleport), so it will first be seen live.

## 11. First live readout (Onboarding_v2, 246 players, data to 2026-11-26 08:00)

Like for like, against the old funnel's hour (61 players, before this flow):

| Measure | Before | Onboarding_v2 |
|---|---|---|
| M1 R1 fight → done | 93% | **98%** |
| Match 1 launched → saved | 73% | 73% |
| Match 1 saved → Match 2 fight | 58% | **76%** |
| Match 2 fight → saved | 68% | **86%** (target 85% met) |
| Joined → Match 2 saved | 28% | **46%** |

The 28% headline is to **match 3**, a step the old funnel didn't have. It isn't the same number as the old 28%.

Where players are lost now:
1. **Lobby after match 2 → match 3: 31%** (101 → 70).
   - Match 3 is the first queued match: PLAY, then the global queue, then a teleport to a reserved server.
   - About 10 minutes in, some players stop for the day.
   - Proposed fix: match 3 is instant on this server too (`INSTANT_MATCHES` 2 → 3; matches 1–2 went to instant on 2026-11-25 because the queue lost 16%). Optionally a goal in the lobby (the tasks system isn't built).
2. **Match 1 after round 1: 20%** (232 → 174): 4.7% before round 2, 9.5% before round 3, 13% before the save.
   - Needs `MatchLeft` (phase, last-round W/L, device) to tell "losing", "phones" and "too long" apart.
   - Likely fixes: easier match 1 bots, the loser's extra card (C2), or match 1 first to 2.
3. **Match 1 saved → back in lobby: 10%.** The win cutscene and results are the natural stopping point.

Ad traffic is low-intent: anyone shown an ad, not players searching for shooters. Home recommendations are earned by these same signals (first-play bounce, playtime, return days), so keep fixing the leaks while waiting for Home traffic. Judge on D1 retention and average play time over 2–3 days, not one funnel snapshot.

**Owner decision (2026-11-26): no instant match 3.** After match 2, the player chooses. The lobby highlights PLAY and hands them the first tasks; players also wander into the Range at this point. Tasks are being built in a separate session for the Saturday update. Their first task should point at PLAY (for example "Play 1 match", with a visible reward), so the 31% drop at match 3 gets a reason to queue. Next target: the match 1 leak after round 1, once `MatchLeft` says why.

**Match funnel (all matches, 2026-11-26 09:00: day 763, hour 91).** The same pattern as every readout since the first: players leave in the **gaps between rounds** (round end → pick → 3-2-1), not in the fights.

| Window | Lost during a fight | Lost between rounds |
|---|---|---|
| Day | 2.2–3.4% per round | 6.3% (R1→R2), 9.1% (R2→R3), 5.3% (R3→R4) |
| Hour | 1.1–3.9% per round | 7.8%, 6.1%, 8.1% |

- About two thirds of mid-match quits are in the gap.
- Caveat: a match that ends 3-0 never logs "R4 live", so part of the R3→R4 drop is matches that simply ended (Match funnel steps 10–11 aren't filled on an early win, unlike the onboarding funnel's).
- The gap is 15–19 s with no fighting: round end 2.5–4 s, the pick 9–12 s, then the 3-2-1.
- Proposed: the loser's comeback card (C2), and a shorter gap.

**MatchLeft readout (owner's CSV exports, 2026-11-25 and 26, 464 mid-match quits; 26th = 331, the new flow).**
- **Phase (26th):**
  - Draft (pick screen) 129 (39%), Live 97 (29%), Countdown 56 (17%), RoundEnd 49 (15%).
  - **71% of quits are in the gap between rounds; the pick screen alone is the top quit point.**
- **Score (both days).** W/L is only set during RoundEnd, so this compares the score itself:
  - Behind: 210 (45%). Level: 155 (33%), of which 0-0 is 92 (left before any round was decided: loading, round 1). Ahead: 98 (21%).
  - Of quits once a round had been decided: behind 56%, level 17%, ahead 26%. **Players who are losing leave about twice as often.**
- **Device (26th):**
  - Mobile 267 (81%), Console 32, PC 31.
  - This needs the share of all players on mobile (Analytics → Acquisition → Platform) before it means anything. Ad traffic is mostly phones.
  - By kind: first match 167, onboarding (match 2) 76, Beginner queue 61, other modes 27.
- **Owner on the comeback card:** "kind of makes it unfair". A fair version is a **reroll for the round loser**: no extra power, just a new set of cards.
- **Server load (owner's worry):** `MatchHost` has no cap on in-server matches. Each instant onboarding match is 1 player + 3 bots + its own Arena copy, so up to ~25 at once in a full lobby.
  - Proposed: a measured cap (`MAX_INSTANT_MATCHES`), with new players over the cap going through the normal queue and teleport.
  - Also proposed: pair two new players who start at the same moment into one instant match (fewer bots, real opponents).

## 12. Shorter gaps, the big 3-2-1 and the server cap (2026-11-26)
The owner approved: "less waiting times … pick your gun, goes 3, 2, 1 … maybe just a countdown more like on the screen".

**Gaps** (`Config/Match`):

| Setting | Before | Now |
|---|---|---|
| Round end | 4 s | 2.5 s |
| Round end, Beginner | 2.5 s | 2 s |
| Select (including the 3-2-1) | 12 s | 9 s |
| Select, Beginner | 9 s | 8 s |
| Round 1 select | 22 s | 16 s |

Measured in Studio (Beginner): round end 2.1 s, then 5 s of picking, then the 3-2-1, about 10 s from kill to fight (was 11.5 s; normal modes about 16 → 11.5 s).

**Big 3-2-1** (`client/Controllers/CountdownController`):
- A white Rubik Heavy number in the middle during the Countdown phase, about 17% of the screen height, with a soft dark drop copy. No outline, no glow.
- Each number pops in from the centre and fades.
- Roblox caps TextScaled at 100 px, so it is TextSize 100 plus a UIScale from the screen height.
- Round 1 of match 1 shows it under the loading cover.

**Server load** (`Config/Onboarding`, `QueueService`, `MatchHost`):
- `MAX_LOBBY_MATCHES = 8` matches per lobby server (pad duels included). A new player over the cap goes through the normal Beginner queue to their own server.
- `PAIR_WHEN_BUSY = 3`: with 3 or more matches running, a new player waits up to `PAIR_WAIT` 2.5 s for another new player at the same onboarding match, and the two play one match on opposite teams. A quiet server starts at once.
- `MatchHost.watchLoad` logs `server slow` (HealthLog: matches, players, fps) when a lobby with matches running drops under 45 fps over 30 s. Tune the cap from those lines. Studio can't measure server load.
- Not tested in Studio: the cap and the pairing need several real players. Both are code-reviewed only.

## 13. Onboarding for the loadout update (2026-11-27)
Owner (2026-11-27): "redo onboarding ... with the new system, change it up a little bit, make it different"; "we don't need to be 3 rounds. It could be 4 rounds. Honestly, we could maybe even go up to the full 5. Like Rivals has it." Earlier: no free skin case in onboarding (done, commit c4e4f1b9).

What changed under it: guns are owned (a new player has the **Classic** and the **Havoc**), round 1 of every match is sidearms only, the shared weapon tiers are gone, powers come from your own deck (starters **Dash, Updraft, Molly, Frost**). The old script handed out Sheriff / Prowler / Havoc / Mauler, which new players don't own. Now the onboarding plays the **real loadout and the real rules**, and only the draft is scripted.

**Length: both onboarding matches are first to 4** (Claude's pick from "4, maybe 5"). Four rounds is the shortest match 1 can be, so the four steps below always fit, even in a 4-0 win. **To make match 1 first to 5, set `Config/Onboarding SCRIPT[1].roundsToWin = 5`** (match 2: `SCRIPT[2]`). First to 3 (`FIRST_MATCH_ROUNDS_TO_WIN`) is gone.

### Where the matches run: a reserved server, not the hub (owner 2026-11-27)
The owner: "we're removing onboarding matches being in the hub because it's just going to cause lag and things we don't need, overusage of matches in the server ... if we fix loading, this shouldn't be an issue."
- **Lobby join → loading screen → auto-queue (1.2 s) → MATCH FOUND → teleport to a reserved match server.** A solo new player's first `LAUNCH_AT_ONCE` (2) Beginner matches skip the queue wait and launch at once with bots. Like every queued match, the reserved server runs the match and keeps them in its lobby afterwards.
- **The script still applies there.** The match server reads the saved `Matches` (MatchService `OnboardingMatch`).
- **The lobby callouts run in that server's lobby too**, because the same lobby scripts run there: NEXT MATCH / PLAY into match 2, then the unlocks and the UNLOCK callout.
- **Removed from the hub:** the in-server instant match, the `MAX_LOBBY_MATCHES` cap and the busy-server pairing (`PAIR_WHEN_BUSY`, `PAIR_WAIT`). Pad duels still run in the hub.
- **Studio has no teleports**, so there (only) the onboarding match runs in the Studio server as a stand-in. This keeps `FreshOnboarding` and START FULL ONBOARDING testable.
- Teleport and map-load speed belong to workstream 1 (loading-perf).

### Match 1: one new thing per round
| Round | Before it | The one new thing | In hand |
|---|---|---|---|
| 1 | No pick screen: 1.5 s to spawn, then the 3-2-1 ("GET READY · Sidearms only") | Move, shoot, red enemies. Round 1 is a pistol round, as in every match. No power yet | Classic |
| 2 | **The first draft:** two big cards, **Dash** or **Updraft** (single taps), one gold and preselected | **A power, chosen in the draft.** Its key pulses until the first use. The Havoc comes out by the game's own rule, with the existing "GUNS UP · Full loadout" banner | Classic + Havoc |
| 3 | Two big cards: **Frost** or **Molly** (held throws) | **Powers stack:** a second power on the next key, and the held-throw hint | Classic + Havoc |
| 4 | One centred **Glitched** card on their first power, preselected | **Upgrades:** powers level up, and Glitched cards break the rules | Classic + Havoc |
| 5+ | The normal deal (a third power, or A/B upgrades) | — | Classic + Havoc |

How it differs from the old flow:
- No power in round 1, so the first fight is the plain gunfight every real match opens with.
- The first power is a choice, not a gift.
- Both throws come in round 3.
- The Glitched card moves to round 4.

### Match 2: the real draft
- **Round 1 has the real pick screen:** one new power per slot (three cards from their deck), during the sidearm round. **New:** a choice of three.
- **Round 2 on: the real columns.** These are A/B upgrades for powers they hold, or a new power on an empty slot. **New:** upgrade paths.
- There is no scripted Glitched card any more (they saw one in match 1). The normal chance applies.
- **Their own saved loadout.** A gun they unlocked after match 1 is in their hands from round 2 of match 2.
- The pick screen stays in focus mode as before (no empty columns).

### Back in the lobby: the first unlock
This replaces the old free case and its OPEN / EQUIP callouts.
- **When it shows:** back in the lobby after match 1 or later, with only the starter guns owned and coins ≥ the cheapest locked gun.
- **What it does:** the Locker icon pulses and carries an **UNLOCK** badge on its corner. Clicking it opens the Locker on the cheapest gun they can afford, with its UNLOCK button in view, so the purchase is one more click (the real confirm).
- **First time only:** it is seen once (bit 8 of `onb.seen`) and never shows again. It also never shows once they own any non-starter gun.
- It goes before the NEW badges, one callout at a time.
- **The Range comes first after match 2.** The Range bar button is now one of the after-match-2 unlocks, and its NEW badge comes before Backpack / Shop / Party. It clears when they go there. The reason: the Task Path's first part (Recruit 1, in the Range) pays about 500 coins. That, plus about 60 from matches 1-2, is what makes the first 400-coin gun affordable before match 3 (economy pass, 2026-11-27). With the economy pass a fresh save starts with 500 coins, so in practice UNLOCK already shows after match 1 (tested), and the Range NEW comes next after match 2.
- **When it lands depends on the coin numbers.** Workstream 5 targets the first unlock in 2-3 matches. With the old pay (about 17 coins for a bot match against a 400-coin gun), it wouldn't show for weeks.

### Removed
- `HANDED_GUNS` and the script's `handGuns`.
- The onboarding weapon-phase boost (`ONBOARDING_PHASE_ROUNDS`, MatchState `PhaseBoost`).
- `FIRST_MATCH_ROUNDS_TO_WIN`, replaced by the per-match `roundsToWin` in the script.
- `GLITCH.onboardingRound`, since round 4's script step does that job now.

### Unchanged
- Rookie bots, red enemies, the Arena only and the first-use power nudge.
- NEXT MATCH / LOBBY after match 1.
- The lobby menus unlock after match 2.
- PLAY stays straight-to-Beginner until match 3.
- Bots keep random loadouts from the active set, so a new player sees the guns they can unlock.

### Admin testing
- **RESET SAVE TO DEFAULT** (`resetProfile`) makes a brand-new save: starter guns and starting coins. This is the full new-player path, including the first-unlock moment once they can afford a gun.
- **START FULL ONBOARDING** (`startOnboarding`) replays matches 1-2 with the save's own guns, deck and coins. The unlock moment shows only if they still own just the starters.
- Studio: `Workspace.FreshOnboarding = true` before Play gives a throwaway fresh save.

### Tested in Studio (2026-11-27)
Fresh ephemeral save (`FreshOnboarding`), Rookie bots, the player idle, two runs.
- **Run 1, match 1 in full** (lost 0-4, so four rounds):
  - **R1:** no pick screen; the fight was live 12 s after Play. Classic only, no power, red enemies, "ROUND 1 · SIDEARM".
  - **R2:** the Havoc and the Classic, Dash on Q with the gold first-use key, "ROUND 2 · LOADOUT", 50 shield.
  - **R3:** Frost on E next to Dash. The two-card screen closed before the capture.
  - **R4:** one centred **DESYNC · DASH · GLITCHED** card, preselected, LOCK IN.
  - MatchState showed `OnboardingMatch` 1 and `RoundsToWin` 4.
  - Back in the lobby there was no item and no case callout. Coins were 506 (500 starting + 6 for the loss). **UNLOCK A GUN** showed on the Locker, and clicking it opened the Locker on the **Prowler** (400) with "Unlock now" in view.
- **Fixed after run 1:**
  - The long tag sat over PLAY and stacked with the "Join the queue" bubble. Bar-item callouts are now always a badge on the icon's corner (text "UNLOCK").
  - The bubble now waits while the unlock callout is up, so there is one hint at a time.
- **Run 2** (`QuickMatch`, one round a match, rounds already checked):
  - Lobby after match 1: one UNLOCK badge on the Locker, clear of PLAY, no bubble.
  - PLAY went straight into match 2 (`OnboardingMatch` 2). R1 showed the real draft: Frost / Updraft / Molly from the deck, "DRAFT · SIDEARMS ONLY", Classic.
  - Lobby after match 2: Shop, Backpack, Range and Party unlocked; the Recruit panel ("Visit the Range"); UNLOCK still on the Locker; the Locker opened on the Prowler again.
- No script errors in either run.
- **Not seen:**
  - The Range NEW badge taking over after the Locker is opened (the run ended inside the Locker).
  - The real reserved-server teleport: Studio can't teleport, so it hosts the match in-server.
  - A won round, and phones.
