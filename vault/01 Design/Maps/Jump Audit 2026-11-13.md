# Jump Audit (2026-11-13)

Lane E of [Handoff - Grades to 9-10](../../05%20Production/Handoff%20-%20Grades%20to%209-10.md): the jump went from 5.6 studs (fall gravity x1.3) to 4.4 (x1.6) on 2026-11-11, and the maps were built for 5.6. This note lists every place on every map where that matters. **Owner's call (2026-11-13): keep the jump, fix the maps.** Fixes and the after-audit are in the last section.

## The real limits (measured in the engine)
A Roblox character gets onto a ledge once its root and torso (about 2 studs above the feet) clear the edge; the Humanoid then steps up. So the reach is well above the 4.4 jump height. Measured on my own character in a playtest (Vandal out, test parts built in the test range, gone when the test stopped):

| | Sprint (20.9 studs/s) | Aimed walk (11.6 studs/s) |
|---|---|---|
| Highest ledge you get onto | **7.5** (8.0 fails) | **7.25** (7.5 fails) |
| Widest gap, same height, jump at the edge | **9** (10 falls) | **6** (7 falls) |

The old 5.6 jump, worked out from the same physics (airtime 0.448 s against 0.379 s, the same step-up): **ledges up to about 8.9, gaps up to about 11.3** at sprint.

So what changed is narrow: **ledges between about 7.75 and 8.95 studs high**, and **gaps between about 9.9 and 11.3 studs**. Everything under 7.5 high or 9 wide still works.

## Method
- Each map in the match place (`Workspace.<Map>`, read only, Edit mode): rays straight down on a 1-stud grid over the greybox's extent, up to 8 layers deep, keeping every upward surface with 5 studs of headroom (barrier-tagged parts and non-colliding art skipped).
- From the map's 8 spawns, a flood fill: walk to the next column (rise up to 2.2, any drop), or jump along 8 directions to the first surface in reach, with the reach worked out from the measured arc (`reach = 20.9 x airtime-until-the-feet-drop-3.35-below-the-target + 0.8`, calibrated to the ledge and gap tests above).
- Run twice, once with the new jump and once with the old. **Lost** = surfaces only the old jump reached. **Tight** = a jump on a route the new jump still makes, with under 0.75 studs to spare (in the engine those are coin flips on take-off timing).
- The code lived in the Studio session (`shared.JumpAudit`); it isn't saved in the repo.

## Results
(Second pass. The first pass counted the floor under low walls and crates as standable, because a headroom ray cast up from inside a part sees nothing, so it walked under them instead of climbing on; that made 3-3.5 high crates and walls look lost. Headroom is now judged from the column's own stack, and a climb onto a higher surface next door is always tried. Checked on the parts it had wrong: Dockyard's quay and step crates, Whitebox's low walls and Old Town's planters stand on open floor with clear headroom and a 3-3.5 rise, and now come out reachable.)

| Map | In rotation | Lost with the new jump (surface, height above the map floor) | Tight jumps (worst margin) |
|---|---|---|---|
| Whitebox | yes | Tops of the 8-high cover blocks: corner cubes, side blocks, slabs, wall boxes (both sides); the window-frame lintels and posts at 12 (reached from those tops) | Mid wall to perch, 9.9 gap (0.26) |
| Big Whitebox | yes | Tops of the 8-high mid blocks, mid walls, side blocks, slabs and wall boxes; the Diamond's top at 14 | Corner cube to perch, 9.9 gap (0.26) |
| Rooftops | yes | Flues (10), Stair huts (9), Pit billboards (11), the Lift tower (8) | Block E coping to the East plank, 9.9 gap (0.07) |
| Bunker | yes | nothing | Generator to the Gallery stair, rise 3.7 over 8.5 (0.11); Generator to the West roof, rise 6.0 over 7.0 (0.43) |
| Dockyard | yes | The Mid post boxes and Stack steps (8; every other stack top is still reached by its crates, stairs and ramps); the 16-high Crane stack, Spawn baffles, West towers and Shed wall tops | none |
| Metro | yes | The hall vending machines (8) | Lower platform to the Kiosk, rise 6.5 over 7.0 (0.09) |
| Old Town | yes | The spawn shrines' tops (8); two arch tops (15) | Terraces to the arcade roofs, rise 2.4 over 9.0 (0.08); lane troughs to the gate lintels, rise 6.0 (0.36) |
| Greenhouse | yes | nothing | Gallery stair to the palm planter, 9.9 gap (0.07); fountain bowl, balustrade, fernery and plinth climbs of 6.0 over about 7 (0.36-0.43) |
| Snowpeak Lodge | yes | The trail-map signs (8) | Loft to hearth, snow piles to the garage roofs and station bases (rise 2 over 9, 0.23); snow piles to the woodpiles (9.9, 0.26) |
| Rooftops2 | ForceMap only | Flues, Stair huts, Pit billboards | Pit copings to the Pit stairs, rise 3.6-3.9 over 8.5 (0.04-0.12); East plank (0.07) |
| Dockyard2 | ForceMap only | The 16-high Baffle tops, West towers, Shed wall tops | none |
| Bunker2, Metro2, Greenhouse2, Snowpeak2, OldTown2 | ForceMap only | as their originals | as their originals (Greenhouse2 adds bridge rail / balustrade gaps, 0.12-0.18) |

## What it means, and what I'd do (for the owner)
1. **Nothing a map is built around is lost.** Every route, perch, catwalk, ramp, stair and crate step still works: spawns reach the same floors, perches and stack tops as before, except the items above.
2. **What's lost is "climb the 8-high block from the floor".** 8 studs is exactly the measured fail (7.5 climbs, 8.0 doesn't). The old jump climbed any 8-high cover block, container, stall, shrine, vending machine or sign straight from the floor; the new one doesn't. Most of those tops were never meant as positions (Whitebox and Big Whitebox call them full cover; Dockyard's design says the stack tops are reached by "a ramp, a crate or an Updraft"; its 16-high tops are Updraft-only by design and the old jump reached them in two hops). **I'd keep it**: it closes off unplanned perches.
   - If any of them should stay climbable, either add a 3-3.5 step beside it (a crate, a low wall), or lower that block to 7.5.
   - Dockyard's Mid post boxes and Stack steps (8) are the only lost tops that sit where a route seems meant (the "Stack step" by its name): worth a look, and a step crate if so.
3. **Tight jumps** still work at a full sprint jumped from the edge but miss often; a coin flip feels bad. For each, decide: a shortcut players should use, then make it 1 stud easier (gap to 8.5 or less, climb to 6 or less); not meant, then make it clearly impossible (gap 11+, climb 8+). The worst: Rooftops' East plank and Pit stairs (margins 0.04-0.12), Metro's Kiosk (0.09), Old Town's arcade roofs (0.08), Bunker's Gallery stair (0.11), Greenhouse's palm planter (0.07).
4. **Aimed movement** clears gaps up to about 6 and ledges up to about 7.25. No map needs an aimed jump to reach anything.
5. **No change made.** Movement numbers untouched; maps untouched.

## Evidence
- Engine ledge test: 5.0-7.5 climbed at sprint (peak root rise 5.0-7.56), 8.0 and 8.5 not (peak rise 6.40 = 4.4 + 2); aimed 7.0 and 7.25 climbed, 7.5 not (rise 5.65).
- Engine gap test (two 3-high platforms): sprint 7, 8, 9 made, 10 and 11 fell; aimed 5 and 6 made, 7-11 fell.
- Reachable surface counts (new / old, 1-stud samples, second pass): Whitebox 11,381 / 12,127; Big Whitebox 25,258 / 26,753; Rooftops 13,466 / 13,750; Bunker 27,350 / 27,350; Dockyard 38,862 / 40,574; Metro 52,782 / 52,824; Old Town 62,041 / 62,337; Greenhouse 46,654 / 46,654; Snowpeak 31,358 / 31,394; Rooftops2 15,142 / 15,354; Dockyard2 40,518 / 41,094; Bunker2, Metro2, Greenhouse2, Snowpeak2, OldTown2 as their originals.
- Not verified: no flagged spot was jumped on the real map in a playtest; the physics behind every line is the engine-measured ledge and gap tests. A 1-stud grid can miss a route narrower than about 1.5 studs.

## Fixes (2026-11-13, owner: "Keep jump, fix maps")
### A sharper test first
"Tight" above counted any jump with under 0.75 to spare, including long run-ups to places you can simply walk up to and climb. The question that matters: **which surfaces can only be reached with a tight jump?** A third flood (every jump must keep 0.75 studs to spare, and climbs stop at 7.0) answers it: reachable now, but not comfortably.

| Map | Needs a tight jump | Lost | Designed to be reached? | Done |
|---|---|---|---|---|
| Whitebox, Big Whitebox | none | 8-high cover blocks (slabs, side blocks, wall boxes, corner cubes, mid blocks); frame lintels (12); Big Whitebox's Diamond (14) | No: full cover; the perches (7, ramp-only) are the designed height (Whitebox.md: "a single high ledge becomes the only spot anyone wants") | Left; intentionally out of reach |
| Rooftops | the Roof AC units (7.5), and the Penthouse and Lift-house roofs (10-11) beyond them | Flues, Stair huts, Pit billboards, Lift tower | No: cover and landmarks; the side towers (+8) are reached by the gangway and plank ramp | Left. The AC to Penthouse climb is a hard, undesigned way onto the spawn screen's roof (easier with the old jump): owner's call |
| Bunker | none | none | - | nothing to do |
| Dockyard | none | **Stack steps and Mid post boxes (8)**; the 16-high Crane stack, Spawn baffles, West towers; Shed wall tops | **Yes for the 8-high tops** ("the stack tops at 8: the high lane", reached by "a ramp, a crate or an Updraft"); the 16 tops are Updraft-only by design | **4 step crates added** (below); 16 tops left |
| Metro | none | Vending machines (8) | No: props | Left |
| Old Town | none | Gate shrines (8), two arch tops (15) | No: wall fountains and arches | Left |
| Greenhouse | the Statue plinth and Shelf racks (9), and from them the spawn Lodge's roof (14-15) | none | No: the Lodge is "out of every sightline" | Left. A hard, undesigned way onto the spawn roof (as before): owner's call |
| Snowpeak Lodge | none | Trail-map signs (8) | No: props | Left |
| `*2` maps | Rooftops2: the Roof AC (7.5); Greenhouse2: as Greenhouse | as their originals; Dockyard2 only the 16-high Updraft tops | as their originals | Left |

**No designed route needs a tight jump on any map**, so rule 1 asked for no change.

### Dockyard: step crates
- **What:** a 4 x 4 x 3.5 crate (the map's own `Crate` kit piece, the same as its existing step crate) against the face of each lost high-lane box that looks toward its own team's spawn: Stack step crate (-8, 14), Mid post crate (10, 34), and their mirrors (8, -14), (-10, -34). Floor to crate 3.5, crate to box top 8 (a 4.5 rise). Each sits at least 8 studs from the next piece (the layout script's gap check: none under 6).
- **How:** in the source, `tools/maps/dockyard_layout.py` (`STEPS`, listed after the mirrored half so every earlier piece keeps its index) and `tools/maps/dockyard_art.py` (a fixed turn, so the seeded random stays the same); regenerated `tools/studio/maps/Dockyard/Greybox.luau` and `Art.luau` (diff: the four greybox rows and four crate placements, nothing else); the layout SVG rewritten. In the place: the same four greybox parts (hidden collision, `Id` 92-95) and four crate models, added in Studio rather than re-running the whole build (each instance carries `JumpFix = 2026-11-13`). **Backup:** `ServerStorage.MapBackups.Dockyard_PreJumpFix_2026-11-13`.
- **After-audit:** the Stack steps and Mid post boxes are reachable again; still out of reach: the 16-high tops (Updraft-only, as designed) and the Shed wall tops.
- **Walked in a playtest** (sprint, jump onto the crate, jump onto the box): all four reach the box top; the Mid post one checked three times, standing on the top every time. Capture: the crate on its pallet flush against the container end, in the same kit as the yard's other crates.
- **The owner must save the match place** (the crates and the backup live in it).

### Before / after
| Map | Lost before / after | Needs a tight jump on a designed route |
|---|---|---|
| Dockyard | high-lane tops (Stack steps, Mid post boxes) + Updraft tops / **Updraft tops only** | none / none |
| every other map | unchanged (all lost items are cover, props or Updraft tops: left on purpose) | none / none |
