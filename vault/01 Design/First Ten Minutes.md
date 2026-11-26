# First Ten Minutes (plan, 2026-11-26)

The owner's brief: plan the first ten minutes so new players get hooked and learn the game **by playing**: one new thing at a time, nobody talking at them, no menus they can't understand yet ("okay, I pick one of these 3 guns. What gun do I pick?"). This note is the plan. Nothing in it is built yet.

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
