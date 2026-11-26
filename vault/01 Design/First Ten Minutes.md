# First Ten Minutes (plan, 2026-11-26)

The owner's brief: plan the first ten minutes so new players get hooked and learn the game **by playing**: one new thing at a time, nobody talking at them, no menus they can't understand yet ("okay, I pick one of these 3 guns. What gun do I pick?"). This note is the plan; §8 says what was built (2026-11-26).

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
