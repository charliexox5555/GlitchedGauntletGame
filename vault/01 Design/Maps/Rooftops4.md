# Rooftops4 (Rooftops remade)

**Status (2026-11-21): built v1, checks at 0, in rotation** (shown as **ROOFTOPS**, regular, 1v1-2v2). **Blind grade 8.33/10, under the 8.5 bar** (blocker: navigation read; see [Grade](#grade-lihfolkquality-score-world-rubric-3-blind-reviewers-per-round-medians)). Map 1 of the [lineup round 2](Map%20Lineup%202026-11-21.md) run. The owner was away and waived per-map approval, so the concept round was self-reviewed (layout checks, a reference board, Blender close-ups); the ChatGPT prompts are below for later. **Save the match place.**

| Overview | Spawn roof | Main path to the catwalk |
|---|---|---|
| ![overview](../../02%20Art/References/maps/rooftops4/build-overview.jpg) | ![spawn](../../02%20Art/References/maps/rooftops4/build-spawn.jpg) | ![main path](../../02%20Art/References/maps/rooftops4/build-mainpath.jpg) |
| **The games court (-6)** | **From the +8 billboard deck** | **Plank bridge over the alley** |
| ![court](../../02%20Art/References/maps/rooftops4/build-court-from-deck.jpg) | ![deck](../../02%20Art/References/maps/rooftops4/build-billboard-deck.jpg) | ![plank](../../02%20Art/References/maps/rooftops4/build-plank-bridge.jpg) |

## What the old maps taught (owner verdicts)
- **Rooftops2** was "the weakest map, with no levels and no character": big flat roof floors, a dark pit, AC stacks blocking routes, blocky signs, props off scale, floating bits ([Rooftops2](Rooftops2.md)). **Rooftops** (the first) met at 1.7 s, far too soon ([Rooftops](Rooftops.md) §3).
- **Rooftops3** was pulled 2026-11-20 with the overnight maps: curved shapes, plain ground, no world round it.
- **Kept:** blue hour, a city block over alleys you can fall into, the water tank as the landmark, three ways across, 180° symmetry.

## Reference board (self-reviewed, owner away)
- **RIVALS Construction** (read-only, the RIVALS file in Studio; measured [Maps and Lobby](../../03%20Research/Rivals%20Reference/Maps%20and%20Lobby.md) L18-46): ~125 × 150 core, 2-4 lanes, longest sight 75, a +22 deck. What we took: one big readable landmark (their crane and hung container → our water tank on its stand), a few strong lanes, and a high deck per side. Nothing copied: no RIVALS meshes or scripts used.
- **Old Rooftops preview** (`02 Art/References/maps/rooftops/rooftops-preview-overview.jpg`): the brick, lit windows and night city were right; its roofs were flat and empty.
- **Rooftops2 evidence shots** (`02 Art/References/maps/rooftops2/r*`): what not to do (plaster cubes, navy glass, slab walls).

## Layout v1 (`python tools/maps/rooftops4_layout.py`)
![layout](../../02%20Art/References/maps/rooftops4/rooftops4-layout.png)

Three buildings in a row, split by two **alleys** (10 wide, the fall), 140 × 192, 180° symmetric, team A at +Z.
- **Team roof (0):** a **front row** of roof structures along its alley (lift machine room, stair hut, tar-paper shed, plant room, chimney breast, vent stack) open only at the three crossings. It cuts the long roof-to-roof lines. Behind it: the **fire-escape deck (+8, stair + a cabinet step)**, the **spawn penthouse** (the baffle, the team's neon icon on its roof), a skylight, AC units, a cooling tower.
- **Crossings:** a **plank bridge** (amber lamps), a **steel catwalk** (white lamps), a **fire-escape bridge** (painted red, red lamps). Each route has its own colour.
- **Middle building:** the **sunken games court (-6)** round the brick pump house that carries the **water tank** (the landmark, ~47 tall). Drop in anywhere (6 < 7.5 climbs back out) or take the steps. The wings: a **billboard deck (+8: stair + landing, a cabinet step)** at one end and a **skylight roof (+3.5) with a glass lantern** at the other, staggered by the turn.

| Check | v1 |
|---|---|
| Spawn gap / longest line | 176 / 154 (0.88 of the gap; the lines over 140 run inside one team's half) |
| Pinches | **0** |
| Spawn sees spawn / enemy half sees a spawn | never / 0.0% |
| First sight | **3.7 s** |
| Sprint to the court / enemy spawn | 4.8 s / 9.6 s (reach check on the build: court 3.7 s, enemy spawn 9.2 s) |
| Heights | court -6, roofs 0, skylight roofs +3.5, steps / cabinets +3.5, decks **+8** (2 ways up each), crates on the decks to +11.5; huts 10-12 and the tank out of reach |
| Cover | 33 full + 6 low in the plan, plus crates, AC units, planters in the build |

## Build v1 (2026-11-21)
Built in the match place at **(6000, 200, 33000)** (`Workspace.Rooftops4`) by `tools/studio/maps/Rooftops4/Build.luau` (rows from the layout; the A half turned 180° for B). 4,827 parts (about 1,000 kit mesh parts), about 48 lights. Rojo wasn't connected to the match place, so the builder and the audit tools ran as ModuleScripts pasted into ServerStorage through the Studio MCP (removed afterwards); the committed file builds the same thing (checked line by line).

**Materials:** Parts with new soft MaterialVariants, colour maps only, no normal maps (OldTown4 final-check rule): `R4_Brick`, `R4_Tar`, `R4_Render`, `R4_Concrete`, `R4_Asphalt`, `R4_Plate`, `R4_Stone`. Roofs are tar skins 0.04 over brick masses, with stone copings, cornices, string courses and base courses.

**Team colours:** A red brick, amber neon, red/yellow billboard, star icon; B buff brick, pink neon, purple/pink billboard, bolt icon. The middle building is dark brick with sand render huts.

**Dressing:**
- **Roofs:** paver walkways with yellow edge lines to every crossing, a membrane seam grid, tar patches, conduit runs.
- **Spawn penthouse:** planters with clipped hedges, string lights from the penthouse to masts on the back parapet, the team's neon icon back to back on a steel frame.
- **Facades:** washing lines across the alleys, fire escapes and sash windows (lit warm or dark glass) on every alley face.
- **Court:** painted rust-red with white lines (straight only), a hoop on each wing wall, drains, puddles.
- **Middle huts:** each side's wall bands (A red / yellow, B purple / pink); team-colour lamps at the foot of each way up; warm lamps at the court steps.
- **Decks:** crates.

**The world:** a street 60 below with sidewalks and lamps, 12 neighbouring buildings at varied heights with lit windows, water tanks, AC units and two-colour neon billboards, and 14 lit city towers. Blue hour: ClockTime 18.35, cool ambient, warm practical lights, purple-blue haze (authored data **419** map / **420** lighting).

**Kit (`tools/blender/maps_rooftops4/`, 22 pieces, 44.9k tris, asset 76377338677614, `ServerStorage.MapKit.Rooftops4`):**
- **Rooftop gear:** R4Tank (12-sided stave tank, steel hoops, faceted roof, braced stand, railed platform, ladders), R4AC, R4Condenser, R4Skylight, R4Lantern, R4Vent, R4Gooseneck, R4Dish.
- **Signs:** R4Billboard (lattice legs, catwalk, floodlights), R4NeonStar / Bolt / Cup (icon signs, no text).
- **Circulation:** R4Stair8, R4Catwalk8 / 6, R4Plank6.
- **Facades:** R4Window, R4Door, R4FireEsc.
- **City:** R4TowerA / B / C.

Close-ups: [kit sheet](../../02%20Art/References/maps/rooftops4/kit-sheet.jpg), [tank](../../02%20Art/References/maps/rooftops4/kit-r4tank.jpg), [billboard](../../02%20Art/References/maps/rooftops4/kit-r4billboard.jpg). Every curve is flat plates (12-sided tank, octagon pipes, octagonal hoop rim); nothing round.

**New: map blockers that let shots through.** Invisible "rail guards" with `CanCollide` on still block raycasts (`CanQuery` can't be off while `CanCollide` is on), so the old "shots pass" guards stopped bullets. Fix: a **`MapBlockers` collision group** (collides with `Bodies` only, not with Default), set up by `CharacterService` at runtime (`Config/Collision.MAP_BLOCKERS`) and by the builder in edit mode. Weapon raycasts run in Default and pass; players are stopped. OldTown4's guards still use the old way (follow-up in Bugs & Ideas).

**Judgment calls:**
- The court's hoops sit on the wing walls (z ±12) to stay clear of the fan housings.
- The court lines are straight only.
- The penthouse plant went from an AC to two condensers to clear the sign frame.
- Each guard stands 9 tall over its floor (parapet guards 14 over the coping): a thin invisible guard top is itself standable, and the reach check found two such chains.

## Checks
| Check | Result |
|---|---|
| Z-fight (`Audit.luau`) | **0** (first build 148: kit window pane/frame planes, rail corners, trim overlaps; then 28 walkway-line and 18 hoop-rim pairs, all fixed at the source) |
| Floating (`FloatAudit.luau`) | **0** (first build 4: city tower window panes 0.065 off the body when scaled; fixed in the kit) |
| Coincident slopes (`SlopeAudit.luau`) | **0** (64 rotated / sloped parts) |
| Reach (`ReachCheck.luau`, run as the `Bodies` group so blockers count) | Every planned level reached from both spawns; **nothing above the +8 decks** except the crate tops on them. Fixed on the way: parapet copings lifting a jump onto the vent stack; guard tops as stepping stones. Spawn → own fire-escape deck 2.8 s, own billboard deck 4.2 s, court 3.7 s, enemy spawn 9.2 s (A and B alike) |
| KillDepth | 20 (`GGAsset_MatchMaps_419`): a fall into an alley downs the player at y −20, about 0.45 s |
| Playtest | `LockMap = Rooftops4`, TestMode off: a 2v2 with bots loaded on the map, lighting applied, bots used the decks, court and every bridge; rounds played; an alley fall downed the player. LockMap (Big Arena) and TestMode (on) restored after. **Bots are exempt from the fall kill** (MapService only checks players): a bot that falls stays in the street; logged in Bugs & Ideas |

## Grade (`lihfolk:quality-score`, world rubric, 3 blind reviewers per round, medians)
| Round | What changed before it | W1 comp (3) | W2 nav (3) | W3 cohesion (2) | W4 light (2) | W5 density (1) | W6 scale (1) | Score |
|---|---|---|---|---|---|---|---|---|
| 0 | first build | 1 | 1 | 2 | 2 | 1 | 2 | **7.1** |
| 1 | lighter roof membrane, paver walkways to each crossing, colour-coded crossing lamps, team neon on the penthouse roof, steel-plate decks, warmer render, ribbed shed | 2 | 1 | 2 | 2 | 1 | 2 | **8.3** |
| 2 | yellow walkway edge lines, court rim line, crates on the decks, court drains and puddles | 1-2 | 1 | 2 | 2 | 1 | 2 | 7.1-8.3 |
| 3 | painted games court with hoops, brighter door-lamp pools, sand-render plant rooms | 2 | 1 | 2 | 2 | 1 | 2 | **8.3** |
| 4 | team-colour wall bands on the middle huts, coloured lamps at each way up | 2 | 1 | 2 | 2 | 1 | 2 | **8.3** |
| 5 | lighter roofs and pavers, more outdoor ambient | 2 | 1 | 1 | 2 | 1 | 2 | 7.5 |

Hard gates: pass (0 overlaps, 0 floating, reach clean, spawn safe, anchored, ~4,830 parts / ~45k kit tris / ~48 lights). **Result: 8.33 / 10 (best stable median), below the 8.5 bar.** I stopped after five rounds; the skill's limit is three. The scores bounce 7.1-8.3 with about one point of reviewer noise, the same plateau Rooftops2 hit (7.9-8.3 over rounds 5-8). **Blocking criterion: W2 navigation** (1/2 in every round). From screenshots, the reviewers read the team roofs' front row and the middle huts as "many similar boxes" and the levels as hard to follow. That front row is the layout's sightline control (longest line 216 → 154), so making it more open would trade away the layout checks. Second: W5 (flat roof planes). Reviewers took W3 down to 1 in round 5 for a saturated court and a stale dark capture; the court colour was toned down afterwards. **Needs the owner:** play it and say whether the routes read in motion. If not, a bigger landmark on each crossing is the next lever (a lit sign gantry over each bridge head).

## ChatGPT concept prompts (for the owner later)
1. *Overview:* "Stylised but grounded Roblox shooter map, three-quarter aerial view at blue hour. A city block of three brick buildings split by two narrow alleys with a long drop to a lit street. Team roofs with a row of rooftop structures (brick lift room, sand-plaster stair hut, green corrugated shed, chimney breast with three clay flues, galvanised vent stack), crossed by a wooden plank bridge, a steel catwalk and a red fire-escape bridge. The middle building has a sunken rust-red rooftop games court with white lines round a squat brick pump house carrying a big wooden water tank on a braced steel stand (the landmark). One wing has a raised steel-plate deck with a billboard and a neon star icon; the other a low roof with a glass roof lantern. Warm lit windows, string lights, neon icon signs (no text), lit city towers and neighbouring roofs with water tanks all round. Blocky, crisp, faceted shapes, no round curves, RIVALS / Valorant readability."
2. *Player view from the spawn:* "First-person view from a brick rooftop at blue hour: a paver walkway with yellow edge lines leads between a brick penthouse with planters and string lights and a row of AC units to a lit steel catwalk over an alley; the big wooden water tank on its steel stand rises behind; a glowing neon star sign on the penthouse roof. Crisp blocky Roblox style, warm practical lights against a deep blue sky."
3. *The games court:* "View from a raised steel deck down into a sunken rust-red rooftop games court with white lines, a wall-mounted hoop, steps, a brick pump house with doors and wall lamps, the steel lattice of a water tower above, neon cup and bolt icon signs, blue hour."

## Waiting on the owner
- Play it: the court fights, the +8 decks, the three crossings, the fall.
- **Save the match place** (it holds the map, the kit and the `MapBlockers` collision group).
- Rojo wasn't connected during the build: the Studio copies of `Config/Match`, `Config/Ambience` and `AssetData/MatchMaps` were edited to match the repo; `CharacterService` / `Config/Collision` sync on the next Rojo connect.
