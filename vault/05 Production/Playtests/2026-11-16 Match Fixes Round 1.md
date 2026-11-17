# Match fixes, round 1 (2026-11-16)

The owner's first list before the last polish: seven match fixes. Items 1-6 are in code and checked in a Studio playtest of the match place (one client and a bot, then the test range for the damage numbers). Item 7 (the map vote screen revamp) is planned below and waits on the owner.

## 1. Matches restarting on a new map mid-match
- **Cause (from the code):** `MatchService.loop` ran the whole match in one `xpcall`. Any script error in any round (an earlier one was a Player attribute payload over 1,024 bytes, [2026-11-15 Match Damage and Reset](2026-11-15%20Match%20Damage%20and%20Reset.md)) ended the match. The loop then went straight to `pickMap` and the map vote, so the match looked like it restarted on a new map. Only that error path loads a new map mid-match.
- **Fix:** each round runs in its own `xpcall` (`playRound` in `runMatch`). After an error the round is logged with its traceback (`[MatchService] round N stopped on an error`), `recoverRound` stops the circle, bots and any open select, puts everyone behind the barrier, and **the same round is played again on the same map** (it is only replayed if its point wasn't scored yet). `Config/Match MAX_ROUND_ERRORS` (3) errors in a row end the match normally on the current score (end screen), never a silent restart.
- **Not reproduced:** a full idle 1v1 bot match (5 rounds, replay, end screen) ran clean, so the trigger behind the owner's restarts is still unknown. **Next time it happens, open Output (or F9 → Server in a live game) and send the `round N stopped on an error` line**: the traceback names the system that broke.

## 2. Map vote mouse, M key, early start
- **Mouse in the vote:** `CameraController.freeMouse(reason, on)`: the mouse is freed while any reason holds (each reason on its own, so one menu closing can't re-lock another's). It shows the cursor and a see-through Modal button (`PlayerGui.MouseFree`), which is what frees the mouse in first person. The map vote holds `"MapVote"` while it's up. The old `setCursorVisible` is now the shared `"Menu"` reason.
- **M key:** `Config/Input FreeMouse` (M on PC). Toggles the `"Key"` reason. Tested: frees the mouse in a live round, M again locks it.
- **Early start:** every select, round 1 included, skips to the 3-2-1 once everyone is locked in. Round 1 also waits until every player the Lobby match lists is on the server (`everyoneArrived`, from `MatchPlan`). Tested: locking in at 13 s left in round 1 went straight to the countdown.

## 3. Headshot effect too big from afar
- **Cause:** `Config/HitFx HEAD_FLASH.range` multiplied the effect's world size by distance (`dist / 18`, up to 2.4x). A far headshot was 2.4 times bigger *in the world*, so it read as huge and scaled oddly as distance changed.
- **RIVALS:** `Assets.Misc.HeadshotParticles.Attachment` is cloned onto the target's Head (`ClientHumanoidEntity._Setup`) and played on a head hit (`ClientEntity._HurtEffect` → `Utility:PlayParticles`). Seven emitters at **fixed world sizes**, no distance code: impact 1.28 → 0 (0.05 s, 3), big-middle 4x4 flipbook → 3.94 (0.5 s, 5), glow → 8.44 (0.4 s), dark → 3.94 (0.35 s), glow2 → 2.81 (0.5 s), shard → 0.19 and shard2 → 0.49 (4 and 7, 15-42 studs/s).
- **Fix:** the distance factor is gone (`HitFx.headFlash`); our sizes were already set in studs "at 18 studs", so it now keeps that world size everywhere, like RIVALS. A head kill is still 1.2x.

## 4. No quick melee in the pre-round
- **Cause:** quick melee (V) queued a swing straight onto the knife, and the knife's trigger path never checked the combat lock (the server refused it, but the client still swung).
- **Fix (`WeaponController`):** V does nothing while combat-locked, and the melee trigger drops any queued swing while locked (nothing saved up for GO).

## 5. Shooting and Mods in the round end, not in the pre-round
- **Fix (`MatchService`):** combat stays open through RoundEnd (5 s). `closeRound()` locks it and clears every Mod's leftovers after RoundEnd (or at once when the match is decided). The next round's select locks it as before.
- **No damage counts after the round:** `Weapon/Damage` deals nothing while the phase is RoundEnd (`apply` sends no hit confirm, so no BLOCKED tag; `hurt` returns 0 for Mod damage). The result and the stats stay as they were. **Owner's call:** if shots after the round should hurt (just for fun, no score), remove those two checks.
- Tested: in RoundEnd `CombatLocked` is false; in the next select it is true.

## 6. Damage numbers: distance and stacking
- **Cause:** our numbers were screen labels at a fixed pixel size, grouped by *hit point* (a new number when a hit landed over 8 studs from the last), and one fell away 0.28 s after the last hit, so a slower gun made a new number every shot.
- **RIVALS pattern** (the file's `Modules.DamageNumbers`, which says it is a port rebuilt from captures, not original code): one `DamageGui` BillboardGui per **target**, size `{15 studs, 250 px}` (shrinks with distance, less than the world does), on top of the head; a hit while it's alive adds to it and re-pops the **same** one.
- **Fix (`Util/HitFeedback`, `Config/HitFx NUMBER`):** one number per target (the server now sends `HitConfirm.victim`), sitting over their head and following them; a hit within `stackTime` (0.9 s) of the last on that target adds to it, even after it fell (it comes back with the running total); sized each frame like that billboard (`distance`: 15 studs + 250 px, 1.0 at 20 studs, 0.5..1.35). Tested on range dummies: 20 → 40 → 60 → 80 on one number at a 0.6 s cadence; two targets get one number each; a target at 131 studs draws at 0.5.

## 7. Map vote screen revamp (built 2026-11-16, owner approved the plan)
The owner: the screen doesn't fit the theme, no circle timer, no player cards like these, better animations, study RIVALS' UI and code.

**RIVALS' vote screen** (read-only: `UserInterface.DuelInterface.Voting`, `MapSlot`, `VoterSlot`, `Top.Timer`; code `ClientDuel.DuelInterface.Voting`, `.Timer`, `.Blur`, `Modules.ButtonEffect`). No springs: all TweenService.
- **Layout:** a 0.75-wide frame at the top centre over a full-screen Modal button. Six options or fewer: a centred grid of wide cards, 0.325 x 0.2 (about 455 x 208 px at 1080p, 2.2:1), 3 per row (2 x 2 for four). More than six: a scrolling list, 3 big featured cards and 4-per-row small ones.
- **Card:** picture fading out at the bottom, a foot bar (bottom 20 %, dark, patterned in the difficulty colour) with the name and "[40 %]", a corner tag. Voters are square team-coloured headshot tiles in a grid over the card. **Your pick:** the foot turns white, the name black.
- **Timer:** no timer of its own: the top-bar timer grows (0.25 s Quint Out), tenths under 10 s, red only at 0.
- **Motion:** open: each card scales 0.25 → 1, Quint Out, `sqrt(i)*0.1 + 0.1` s (stagger by length, not delay); blur to 24 over 0.4 s. Hover 1.025 (0.25 s Quint Out); press 0.875, release Back Out. **Votes redraw instantly** (no tween). Winner: other cards vanish, a copy of the winner flies to a centre box (0.75 s Quint Out), holds 1.25 s, shrinks away (0.75 s Quint In).

**Plan for ours (Soft Edge, owner to approve):**
1. **No circle timer:** a slanted bar under the "VOTE FOR A MAP" title plate that drains, with the seconds beside it (tenths under 5 s, one colour change at 3 s).
2. **No head cards:** each map is a wide soft plate (one cut corner, art fading under the foot). The foot is a **vote-share bar** that fills to its %, with the % in it; voters are small team-coloured chips on the foot (cut corner, no circles). Your pick is the one bright accent.
3. **Grid like RIVALS:** 3 per row, 2 x 2 for four, a featured row above six.
4. **Motion on our tokens** (Quint, no overshoot, no sounds): cards slide 12 px and fade in, 0.24 s, 0.04 s stagger; hover lifts 2 px and 1.025; tap 0.97 for 0.08 s; every vote change animates (bar fill 0.24 s, chips slide in 0.12 s), where RIVALS snaps; background blur about 24 over 0.4 s.
5. **Winner:** the other cards fade (0.14 s), the winner moves to the centre (0.5 s Quint Out), holds about 1.25 s, leaves (0.14 s).
Built as a real ScreenGui in Studio (`StarterGui.MapVote`, builder `tools/studio/BuildMapVote.luau`) for the owner to edit (memory `ui-design-in-studio`), then wired in `MapVoteController`. [UI Theme v4 Soft Edge](../../02%20Art/UI%20Theme%20v4%20Soft%20Edge.md).

**What was built (v2):**
- **Look:** the lobby's current look (Rubik Heavy / Bold, neutral charcoal, gold only on your pick) and its one-piece sliced art (the same card and slanted-plate images as lobby `Util/Cards` / `Util/Plates`). Title on a slanted plate; the clock is a slanted bar that drains, with the seconds at its end (tenths under 5 s, red from 3 s). Cards 470 x 210, 3 a row (2 x 2 for four). Each card: name, team sizes, a faint big initial (no map pictures yet: a `Picture` slot fades into the foot once maps have one), and a foot that is the vote share (fill + %) with square team-coloured voter chips. Template children `MapName` / `Teams` (not `Name` / `Size`: those clash with properties).
- **Motion:** world blur 24 over 0.4 s; header slides 12 px in; cards slide 12 px and fade in (0.24 s Quint Out, 0.04 s apart, each card a CanvasGroup); hover lifts 3 px and grows 1.025; your pick sits 6 px higher; shares ease (0.24 s), chips pop in and out (0.12 s); the winner moves from its cell to the middle and grows to 1.22 while the others fade (0.14 s); a Random win renames the Random card to the drawn map.
- **Playtest (Studio, one client + a bot):** cards in, mouse free, blur on; a vote on Bunker filled its foot gold to 100 % with your chip and lifted it; the all-in rule cut the clock to 1.1 s; Bunker moved to the centre at 1.22, the five others faded; the screen closed into the select with the blur off. Edit-mode capture checked the layout (one fix: the % on your gold pick stays white).
- The v1 screen and templates are kept in `ServerStorage.UiBackups` (`MapVote_v1`, `MapVoteTemplates_v1`). **The place needs saving** for the Studio-built screen to stick.
- **Next (parked):** map pictures for the cards once the maps are approved for `Config/Match` (a top-down capture per map, uploaded with `tools/opencloud/upload_asset.py`, set as `MAPS[i].image`).

## What to test
- [ ] A bot match and a two-player match all the way to the end screen. If the map changes mid-match, send the Output line.
- [ ] The map vote: the cursor shows and the cards can be clicked (Studio: clear `Workspace.ForceMap` first, or there's no vote).
- [ ] M frees and re-locks the mouse in a round; nothing else on M.
- [ ] Round 1 starts as soon as both of you lock in.
- [ ] V in the select or 3-2-1: nothing happens.
- [ ] After a round is won: shooting and Mods work, nobody takes damage; the next select locks you again.
- [ ] Headshots up close and far away: same size in the world.
- [ ] Damage numbers on one target with a slow gun (one climbing number), on two targets, and far away (smaller).

References: [Match Flow](../../01%20Design/Match%20Flow.md), [Body, Viewmodel, Guns and VFX](../../03%20Research/Rivals%20Reference/Body,%20Viewmodel,%20Guns%20and%20VFX.md) (headshot recipe), [UI and Client](../../03%20Research/Rivals%20Reference/UI%20and%20Client.md), LihFolk [Weekend Build - Arena Shooter with Server-Checked Hits](../../LihFolk/24%20Worked%20Builds/Weekend%20Build%20-%20Arena%20Shooter%20with%20Server-Checked%20Hits.md) (server-owned round state).
