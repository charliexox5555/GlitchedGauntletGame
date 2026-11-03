# Playtest: 2026-11-03, ability upgrades overnight

**Build / commit:** ability upgrades (all 9 abilities' L2/L3 paths) + the slot draft, merged on `main`
**Testers (device):** Claude only, one player in Studio on PC, real keyboard/mouse input through the Studio MCP plus server commands. Match mode on the Whitebox vs the test opponent, and test mode (the range) with dev dummies
**What this checks:** that every level works and nothing errors. It doesn't check balance or feel: that's the morning test below.

## How it was built
- **Hub session** (the overnight chat): shared groundwork first (fixed slots, every L2/L3 number in `Config/Mods`, damage guards and modifiers in `WeaponService`, the `Frozen` stun and `StimStrong` statuses, a server hook and a client effects module per ability), then the slot draft with upgrade cards, the HUD level label and the dev panel.
- **9 ability sessions** in parallel, one per ability, each in its own worktree: built the levels, researched names and card text, wrote an "Upgrades (L2/L3)" section in its ability note. All 9 branches merged into `main` without conflicts.

## Results
| Test | Result |
|---|---|
| Draft: new abilities only for empty slots, each card shows its key (Q/E/T) | ✅ |
| Draft: round 3 with Q left only offers Q abilities (2 cards: Q has only 2) | ✅ as designed |
| Draft: once slots are full, one column per slot with path A / path B | ✅ |
| Draft: a glitch card appears by chance (pity rose to ~14% by the 2nd upgrade draft) | ✅ Heal Orb G2 showed up |
| Draft: picking an upgrade applies it (Firewall L1 → B2 → B3 over two drafts; level 3 shows only the next card, maxed shows MAXED) | ✅ |
| HUD: ability slots show the level ("DASH 3", "FROST G3") | ✅ |
| Heal Orb **Barrier**: cast on yourself, hex edge + BARRIER pips | ✅ |
| Barrier blocks an enemy hit (test opponent: 2 → 1, no damage) | ✅ |
| Barrier ignores your own damage (your own Molly burns through without using it) | ✅ as built (see Bugs & Ideas: confirm) |
| Stim **Heal Zone**: 7.5 HP/s inside (30 → 45 in 2 s), Heal Orb look + glitch | ✅ |
| Firewall **Frost Wall**: ice wall built along the floor, pieces marked Frost | ✅ (the Hinder on contact wasn't hit in this test) |
| Updraft **Crash Down** G3: crouch mid-air slams, 45 damage + Hinder on the enemy dummy | ✅ 100 → 55 |
| Frost **Freeze Frame** G3: you and the enemy dummy frozen solid, ice blocks, PAUSE screen, FROZEN countdown | ✅ |
| Recon **Ping Spike**: reveals every enemy dummy through walls with the glitched outline | ✅ |
| Molly **Fork Fire** G3: splits into several small fires around the target | ✅ |
| Dash **Desync** G3: a copy of you keeps going and turns to fire at the nearest enemy | ✅ |
| Dash **Ghost** B2: a hit 0.15 s into the dash is dodged, the next one lands | ✅ 100 → 100 → 50 |
| Recall **Crash Recovery** G3: a lethal hit near the anchor → back on the anchor at 40 HP, anchor gone, "CRASH RECOVERED" | ✅ |
| Script errors in Output during all of the above | ✅ none (one unrelated asset warning: `rbxassetid://203785492`, not in `src`) |

## Not tested yet (for the morning)
- **Two players** (Team Test): Ghost's cloak and the Desync decoy as the *enemy* sees them, the Barrier bubble on someone else, Frozen on another player, Ping Spike's +20% damage (G3) in a real fight.
- The number-only levels one by one (they're config values the sessions checked by reading the code): Long Dash distances, High Rise heights, recharge timers on the HUD, Bigger Fire / Big Burst sizes, Long Heal amounts, Quick Stims / Strong Stim.
- Feel: are glitch cards too rare at 8%? (`Config/Dev ALWAYS_GLITCH_CARDS = true` makes every level-1 column show its glitch card in Studio.)
- Each ability session's own checklist is in its ability note, "Upgrades (L2/L3)" section.

## Changes during the test
- The dev panel's **Hurt me (−50)** now goes through the real damage path (the guards, then shield, then health) so Barrier / Ghost / Crash Recovery can be tested alone. It can kill now.
