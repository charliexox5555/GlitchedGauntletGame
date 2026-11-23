# Skin lines at launch

2026-11-21. The owner asked for a pass over every gun and knife skin line: what rarity each is now, whether to move any, and how many more lines each rarity needs for the first release. This is the inventory and Claude's proposal; **the owner's placement wins** (answers go in "Owner's call" below). Tiers live in `src/shared/Config/Skins.luau` (provisional since 2026-11-20); odds in [Skin Tiers and Cases](Skin%20Tiers%20and%20Cases.md).

Tier meaning (owner's brief): **Common** = reskin on the stock shape · **Rare** = a shape change · **Epic** = custom animation (inspects, moving parts) · **Legendary** = near-exclusive quality (animation + custom sound) that cases can give · **Exclusive** = Robux bundles only.

## In the game now (case pool, 18 slots: 17 guns + Knife)

| Tier | Line | Guns | Knife |
|---|---|---|---|
| Common | Prism, Redline | all 17 | Common knife |
| Common | PopCircuit | all 17 | the Bat (Epic: own rig, moves) |
| Common | Nitrous, Oilwake, Misprint, Faultline, Poolside | all 17 | none |
| Rare | Rootglass | all 17 | Leafblade (Epic, animated inspect) |
| Rare | Payload | 8 (Ares, Bulldog, Classic, Ghost, Odin, Operator, Stinger, Vandal) | none |
| Rare | Breakwater | 6 (Bucky, Judge, Odin, Shorty, Spectre, Vandal) | Rare |
| Rare | Sealwork | 5 (Guardian, Marshal, Sheriff, Shorty, Vandal) | Rare |
| Rare | Inkshift | 5 (Odin, Phantom, Shorty, Stinger, Vandal) | Rare |
| Rare | Giltfold | 5 (Classic, Ghost, Marshal, Stinger, Vandal) | the Fan (Epic, opens and shuts) |
| Rare | Moltframe | 3 (Ares, Spectre, Vandal) | Rare (note: "Legendary once the chamber flow ships") |
| Epic | Playback | 6 (Ares, Bulldog, Classic, Ghost, Phantom, Stinger) | Epic |
| Epic | Sundial | 6 (Ghost, Guardian, Marshal, Operator, Outlaw, Sheriff) | Epic |
| Epic | Slipframe | 5 (Classic, Guardian, Operator, Spectre, Vandal), installed in both Studio places | none |
| Legendary | none | | |
| Exclusive | Ruin-Blighted (bundle) | Vandal, Spectre, Ghost, Guardian, Operator + Ruined Reaver melee; installed in the match place only | |
| Exclusive | Tempest-Strike (bundle) | Vandal (hero, in production), Bucky started | |

**Counts including the Slipframe Studio build:** Common 8 lines (139 skins), Rare 7 (≈56), Epic 3 (≈19), Legendary 0. Knives by tier: Common 2, Rare 4, Epic 5, Legendary 0.

## Built in Blender, not in the game yet

| Line | What it is | Guns | Fits |
|---|---|---|---|
| Kilnlock | exotic: portable foundry, opening cage, heat core | Bulldog, Judge, Odin, Phantom, Sheriff, Shorty + Kiln Cleaver melee + Foundry Stamp | Legendary (or Epic) |
| Stacklight | exotic: electronics test bench, light window, shuttle | Ares, Classic, Operator, Outlaw, Phantom, Stinger + Keycap Tester / Patch Tool | Legendary (or Epic) |
| Spindrift | the first Kuronami-inspired pass | archived; Tempest-Strike replaced it | none |

## What stands out
1. **Epic and Legendary are thin.** With Slipframe included, three lines share the Apex Epic tier. The Legendary tier has no eligible line.
2. **The Season Pass line is also in cases.** The roadmap picks the pass line from Poolside or Rootglass, and both are in the case pool now. The pass line should leave the cases.
3. **The Knife case is thin at the bottom.** Two Common knives (each 25 % of a Knife case) are gone after a couple of openings.
4. **Common is full, Rare is partial.** Every Common line covers all 17 guns, while Rare lines cover 3-8. That's fine (shape work is expensive), but Moltframe at 3 guns is small for a line.

## Claude's proposal for launch (owner decides)

| Tier | Now | Launch target | How |
|---|---|---|---|
| Common | 8 | 7-8 | keep; move Poolside or Rootglass to the Season Pass; add **3 Common knife reskins** (e.g. Nitrous, Oilwake, Faultline) so the Knife case has 5 Commons |
| Rare | 7 | 8 | Kilnlock and Stacklight are the next reworks. Moltframe may move up when its chamber flow ships. |
| Epic | 2 | 4 | Playback, Sundial + **2 new animated lines** (6 guns + knife each) |
| Legendary | 0 | 2 | Kilnlock and Stacklight (built, custom melee and motion), each finished with its own sounds |
| Exclusive | 2 | 3 | Ruin-Blighted, Tempest-Strike, the Thanksgiving bundle line |
| Season Pass | 0 | 1 | Poolside or Rootglass (or a new theme) |

**Remaining in this proposal** are new Epic lines, the Thanksgiving line, 3 knife reskins, Tempest-Strike's roster, and finishing Kilnlock and Stacklight in Studio. Slipframe's visuals and models are in Studio. Custom sound follows.

## Owner's call (2026-11-21, planning only: nothing changed in the game yet)

| Tier | Launch lines | Work |
|---|---|---|
| Common | Prism, Redline, PopCircuit, Nitrous, Oilwake, Misprint, Faultline, Poolside (8) | none. No extra knife reskins ("one Common knife is fine"); Prism and Redline knives exist today |
| Rare | Payload, Breakwater, Sealwork, Inkshift, Giltfold (5) | Rootglass leaves for the Season Pass, Moltframe moves up. Slipframe (built in Blender) not placed yet |
| Epic | Playback, Sundial, Moltframe, + 1 new line (4) | improve Playback and Sundial (both in the game, 6 guns + knife each); Moltframe gets more guns and stronger effects; design 1 new Epic line |
| Legendary | 2 new lines (owner creates) | owner's designs, later |
| Exclusive | Ruin-Blighted, Tempest-Strike, Thanksgiving | as planned |
| Season Pass | Rootglass (Season 1) + 1 more pass line later | Rootglass comes out of the cases |

**Knives after the moves:** Common 2 (Prism, Redline), Rare 3 (Breakwater, Inkshift, Sealwork), Epic 5 (Giltfold Fan, Moltframe, Playback, PopCircuit Bat, Sundial), Legendary 0 until the new lines. Leafblade leaves with Rootglass.

**Slipframe, Kilnlock, Stacklight (owner, 2026-11-21, after the [built lineup sheets](../02%20Art/Skins/Slipframe/out/lineup_built.jpg)):** all three are "done kind of poorly ... sloppy and don't follow the build rules", so they get **rebuilt** to the build rules, and all three are **Rare** ("slight changes in the way they look, nothing crazy"). **Slipframe has the most potential to become Epic** later, so build it with that headroom. Their knives / melee (Slipframe Dagger, Kiln Cleaver, Patch Tool) and charms (Foundry Stamp, Keycap Tester) are **set aside** (charms aren't a system yet). Build plan: [Rare Line Rework Handoff](../02%20Art/Skins/Rare%20Line%20Rework%20Handoff.md).

**Owner update after the Guardian review.** Slipframe moved to Epic for the five animated guns and joins the Elite and Apex case pools in the Studio build. Kilnlock and Stacklight still follow the Rare rework brief. [Slipframe deployment](../02%20Art/Skins/Slipframe/Rework%20Ledger.md#studio-roster)

**Later owner direction (2026-11-21).** Slipframe is the candidate for the open Epic slot. Guardian r05fx is installed for Studio review with the first-person insert reveal, seam glint, shot pulse and magazine-seat light. The owner approves Guardian before the remaining Slipframe guns are built. The earlier Rare count includes Slipframe and would become seven on its move to Epic. Kilnlock and Stacklight remain planned as Rare. [Rework ledger](../02%20Art/Skins/Slipframe/Rework%20Ledger.md#guardian-r05fx-studio-review)

## Status (2026-11-22)
| Tier | Lines now | State |
|---|---|---|
| Common (8) | Prism, Redline, PopCircuit, Nitrous, Oilwake, Misprint, Faultline, Poolside | done |
| Rare (7) | Payload, Breakwater, Sealwork, Inkshift, Giltfold, Rootglass, Moltframe | in the game; Moltframe is leaving for Epic (Sheriff being added, in progress); Rootglass stays in cases while the Battle Pass is closed for the first update |
| Epic (3 → 4) | Playback, Sundial, **Slipframe** (5 guns rebuilt r02-r05, effects + audio, installed) | Moltframe joins when its additions land; Playback and Sundial improvements not started |
| Legendary | Slipframe **Arc** knife only | the owner's 2 Legendary lines not started |
| Exclusive | Ruin-Blighted (5 guns + Reaver), Tempest-Strike (6 items, final) | done; Thanksgiving bundle is not in the release shop layout |
| Season Pass | none | Battle Pass closed for the first update (`Release.BATTLE_PASS_OPEN = false`) |

Not started: Kilnlock and Stacklight Rare rework ([handoff](../02%20Art/Skins/Rare%20Line%20Rework%20Handoff.md)). Slipframe filled the planned "1 new Epic line", so Epic reaches its target of 4 once Moltframe moves.
