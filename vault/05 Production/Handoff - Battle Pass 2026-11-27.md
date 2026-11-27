# Handoff: from launch hardening to the battle pass (2026-11-27)

For the owner (and any session they start) picking up the battle pass after the launch hardening. What the game is now, what's ready, what's open, and where the pass fits.

## 1. Why this update exists
- The old game (Power Duels) got Home recommendations: **CTR over 4%**, but a **qualified play-through rate of 0.26-0.69%** and **average playtime under 5 minutes**. The thumbnails work; the first minutes didn't hold people. The owner: the structure and fantasy weren't landing, not only the loading.
- Earlier live funnels ([First Ten Minutes §11](../01%20Design/First%20Ten%20Minutes.md#11-first-live-readout-onboarding_v2-246-players-data-to-2026-11-26-0800), [Fantasy and Retention Plan](Fantasy%20and%20Retention%20Plan%202026-11-25.md)):
  - **71% of mid-match quits happen between rounds.** The pick screen alone is the top quit point.
  - Losing players leave about twice as often.
  - About 25% stop when match 1 ends.
  - D1 retention was 3.19% (2026-11-24 cohort).
- **Decision rule, kept from the 2026-11-26 checkpoint:**
  - D1 ≥ 8% and playtime ≥ 12 min: scale ads.
  - D1 5-8%: keep building reasons to come back.
  - D1 under 5% after this update: rethink the hook.

## 2. What the game is now (the loadout update)
- **Guns are owned.** Everyone starts with the Havoc (rifle) and the Classic (pistol). Round 1 of every match is sidearms only; the primary comes out from round 2. The shared weapon tiers are gone.
- **Gun prices are a grind (owner, 2026-11-27).**
  - The Prowler (400) is the onboarding gun, bought right after match 1 with the 500 starting coins.
  - The rest cost 1,000-6,000 (the Deadeye sniper is last); the whole set is 30,900, about 30-35 h of play.
  - Details: [Gun grind](../01%20Design/Shop%20Economy%20and%20Art%20v1.md#gun-grind-owner-2026-11-27).
- **Powers are a deck.** The starters are Dash, Updraft, Molly and Frost. More come from SURGE power packs: coins only, 1,500 each, never a duplicate, and pass powers never roll.
- **Every round is a draft:**
  - a new power on an empty slot;
  - an A/B upgrade for a power you hold;
  - sometimes a Glitched card that breaks a rule.
- **Gun levels (in progress):**
  - Guns level by playing with them, and optionally with coins.
  - Each level adds a small, capped stat step.
  - Milestone rewards every 5 levels; the rewards themselves are a later update.
  - Being built in its own session; see [Loadout and Power Deck](../01%20Design/Loadout%20and%20Power%20Deck.md#launch-plan-for-the-loadout-update-2026-11-27).
- **Skin cases** only give skins for guns you own. There is no free case or skin in onboarding.
- **Onboarding** (first match first to 4, one new thing per round, on a reserved server): [First Ten Minutes §13](../01%20Design/First%20Ten%20Minutes.md#13-onboarding-for-the-loadout-update-2026-11-27).
- **Hardening done today:** [Launch Hardening](Launch%20Hardening%202026-11-27.md).
  - Maps load every time: 20/21, then the last failure fixed.
  - 0 frozen bots in 49 rounds.
  - Phone and controller UI: no overlaps at 667x375 / 844x390, and the scoreboard/top bar clash is fixed.
  - Lobby UI load roughly halved.
  - Code audit of 516 files: no exploit, dupe or data loss.
  - Movement feel: running jumps are real jumps now.
  - A new-player funnel `Onboarding_v3` tracks 27 steps from loading to match 3. Guide: [Onboarding Funnel v3](../04%20Tech/Onboarding%20Funnel%20v3.md).
- **Gun levels: built (2026-11-27).** XP per gun from play, up to level 50. Small capped stat steps: handling, reload and stability −8% at most, accuracy −5%; damage and time to kill never change. Coin levels go up to 30 only. The Locker level card and the level-up moment on the end screen are built. Milestone rewards are empty for now (`Config/GunLevels.REWARDS`). See [Gun Levels](../01%20Design/Gun%20Levels.md).
- **Match pay:** 3 coins per round won and 1 per elimination. Finishing pays only when you took part, and +100 for the first win of the day. A bot match pays about 25 on average, a real one about 42.
- **Small adds:** a red dot on the Shop while today's login reward waits.

## 3. The battle pass: where it stands
Plan: [Battle Pass Build Plan](../04%20Tech/Battle%20Pass%20Build%20Plan.md) (9 phases). Contents: [Battle Pass Season 1 Contents](../01%20Design/Battle%20Pass%20Season%201%20Contents.md). Screen: [UI Battle Pass](../02%20Art/UI%20Battle%20Pass.md).

| Phase | State |
|---|---|
| 1 Season data + rewards | Done (27 Studio checks) |
| 2 Progress from matches | Done (live-round seconds + rounds won, same write as XP) |
| 3 Robux (Premium 689, +5 Levels 499) | Done (products `3736724862`, `3736724879`) |
| 4 Wire the screen | Done. Still open: phone layout, a CLAIM ALL button (server action exists), and the Shop's pass card sits half off the right edge in the launch layout. |
| 5 Titles | Not started |
| 6 Charms | Not started (every gun has `CharmPoint`, nothing hangs from it) |
| 7 Powers (Smoke free t10, Electric Shock premium t20) | Not started. The SURGE pack already skips both; set `free = false` on them in `Config/Mods` when built. |
| 8 Art (Arcade 8 guns, Frostbite 4, 8 charms) | Not started |
| 9 Season end + launch | Not started. `Release.BATTLE_PASS_OPEN = false`, `Season.STARTS_AT = 0` until launch. |

## 4. What today's changes mean for the pass (decide before building on)
1. **Pass coins look small next to the new gun prices.**
   - Premium pays 2,250 coins and free pays 1,000, against a 30,900 gun set; premium is about one Marksman.
   - Option: raise premium coins (for example to about 5,000), so the pass also speeds up the gun grind, a strong reason to buy it.
   - Owner call.
2. **Arcade / Frostbite skins for guns the player hasn't unlocked.**
   - Recommended: grant them anyway. The Locker shows the skin on the locked gun with "Unlock the Marksman to use it", which gives the grind a goal.
   - The alternative is to only show owned guns' skins. That breaks a fixed reward track.
3. **Gun levels and the pass** are two progress bars on the same matches. Keep them distinct:
   - The pass = time and rounds, cosmetics and powers.
   - Gun levels = that gun's use, small stats and milestone rewards.
   - A pass reward could be a gun XP boost later. Not now.
   - Gun level milestone rewards (`Config/GunLevels.REWARDS`, every 5 levels) are empty. They are the "rewards later" update: decide what they pay alongside the pass, so the two tracks don't hand out the same things.
4. **Pass powers stay out of packs.** Done (commit 62aeeefa).
5. **Electric Shock is slight pay-to-win on purpose** (owner, 2026-11-26). With coin levels now also buying small stats, watch what the community calls pay-to-win. Two strong levers at once is where that reputation starts.
6. **Pace:** a tier per 30 min of live rounds or 25 rounds won, bots at half, 6 weeks. That was decided before matches went first-to-4 for onboarding; normal matches are unchanged, so the pace holds.

## 5. Designer's notes: the next levers on retention (from the data, not built)
Ranked by what the funnels say, cheapest first:
1. **The gap between rounds** (71% of quits).
   - A **reroll for the round loser**: no extra power, just a new hand. This is the fair version of the comeback card (the owner said the extra card was unfair).
   - It gives the losing player something to do in the exact moment they leave.
2. **Match 1 to match 2:**
   - The Prowler unlock lands after match 1. Make the moment loud: the gun on screen and "EQUIP FOR NEXT MATCH".
   - Then NEXT MATCH as the main button.
3. **A reason to come back tomorrow:**
   - the login dot (done);
   - the Task Path (live);
   - the pass (this update);
   - a "first win of the day" coin bonus. It needs code: Economy pass → "Needs code" 2. Being added in this pass if it fits.
4. **Read `Onboarding_v3` after a full day of traffic** before changing the onboarding again. The two steps to watch:
   - **"Teleport arrived".** The old queue and teleport lost 16%, which is why matches 1-2 were in the hub before.
   - **Match 1's rounds 2-4.** If they leak, set match 1 to first to 3 (`Config/Onboarding SCRIPT[1].roundsToWin`).

## 6. Owner checklist before publishing
- [ ] **Save the place in Studio.** Many Studio-owned edits this pass:
  - the LobbyUI move to ServerStorage;
  - the KillFeed and Notify templates;
  - BuyCoins3;
  - weapon skins;
  - the Locker room.
- [ ] **Push `main`** when happy. Everything is committed and nothing is pushed.
- [ ] **Try on a real controller:** A to jump, B to slide, plus the lobby pages (the test tools can't press gamepad buttons).
- [ ] **Publish**, then read `Onboarding_v3`, `MatchLeft` and D1 over 2-3 days.

## 7. Release check (2026-11-27, Studio, after every session landed)
- **Code:** `stylua --check`, `selene` with 0 warnings, and `rojo build` all pass on main at 1e60fe53.
- **Fresh new player** (`FreshOnboarding`, idle player, Rookie bots, Telemetry log on):
  - Loading screen done at +4.1 s. Match 1 queued and reached at once; the fight was live at +10.7 s.
  - Four rounds, first to 4: an idle loss 0-4, so the bots fight.
  - `Onboarding_v3` steps 1-13 and 20 printed in order.
  - Back in the lobby: 506 coins (500 + 6; the onboarding exemption pays the finish to an idle new player). The **UNLOCK** badge was on the Locker.
  - The Locker opened on the Prowler (400). The new prices showed (Hornet 2,000 … Deadeye 6,000). The confirm said "You'll have 106 coins left", and UNLOCK took the coins to 106.
- **Bug found and fixed (1e60fe53):** TRY IN THE RANGE, then leaving the Range, brought the Locker's panels back over the lobby HUD with no room or camera.
  - Cause: the Locker closes and the Range trip starts at once. The armed-zone hide grabbed the Locker screen mid-close and turned it back on in the lobby.
  - Fix: a closed Locker keeps its screen off, the rule the other lobby pages already had.
  - Re-tested: TRY → Range → leave → clean lobby.
- **Shop login dot:** off when today is claimed. With the day faked unclaimed, the dot shows "1" on the Shop.
- **Gun levels** (own session, [Gun Levels](../01%20Design/Gun%20Levels.md)), Studio-tested:
  - XP from a bot match, the level-up moment, and the reload step measured in-game.
  - A coin level spammed 10× pays once. An old save loads.
- **Not checked here:**
  - **Phone size (667x375) of the new Locker level card.** Studio's Device Emulator needs desktop access, which needs you.
  - **A real controller.**
  - **The real teleport to a reserved server.** Studio can't teleport; the first live players will show it in `Onboarding_v3` step 5.
- **Minor, not ours as far as I can tell:**
  - Every join logs "rbxassetid://203785492 … Asset type does not match" three times. It isn't in our code, workspace, ReplicatedStorage or UI. It's probably an avatar item.
  - Also "Rubik.json failed to load: Temp read failed", a Studio font cache message.
- **Your RIVALS reference file was open in Play mode** in Studio during this pass. Its scripts are untrusted; stop it.
