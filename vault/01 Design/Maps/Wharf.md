# Wharf (regular map, 1v1-2v2)

A morning container wharf: a concrete pier with water on three sides and the container yard on the fourth, two staggered sheds that split it into three lanes, a harbour office with a roof deck in each team's corner, and a yellow quay crane standing off the east edge as the landmark. **Learned from RIVALS Docks** (flow, sizes, heights, sightlines; study only, nothing of theirs reused), built in our own art: mostly Parts on the 5-stud module, Blender only for the crane, the mountains and the port kit containers and bollards.

- Owner calls and the brief: [2026-11-20 Docks Map Build](../../04%20Tech/Prompts/2026-11-20%20Docks%20Map%20Build.md). Same session: the container fix on [Pier and Dockyard](Pier%20and%20Dockyard.md) and the rotation cut in [Maps](00%20Maps.md).
- Rules used: [Map Quality Standard](Map%20Quality%20Standard.md) §3, [Jump Audit](Jump%20Audit%202026-11-13.md) (ledge 7.5, gap 9 at sprint), `gauntlet-build-style` (no round curves, carved ends), [Style Bible](../../02%20Art/Style%20Bible.md), [Rivals Reference → Maps](../../03%20Research/Rivals%20Reference/Maps%20and%20Lobby.md), LihFolk `lihfolk-worldbuilding` (macro to micro, one hero, edges contain the space, lighting recipe table) and [Level Design Principles](../../LihFolk/33%20Level%20Design/Level%20Design%20Principles%20-%20Flow%20Sightlines%20and%20Landmarks.md).

## 1. RIVALS Docks, measured (2026-11-20, read-only, match place `Workspace.Docks`)
Measured with property reads and raycasts in edit mode (no play, no scripts touched). Origin = `Docks.Primary` (9000, 6000, 2000); the deck top is +9.5 above it, so heights below are **above the deck**.

| What | Docks |
|---|---|
| Whole model | 2,000 × 2,000 (water plane and islands); 3,262 instances, 1,277 Parts + 1,018 MeshParts in `Extra` |
| Play core | about **180 × 228** (x -96..85, z -127..101): a raised concrete pier block + an asphalt container yard on its west side |
| Spawns | 3 slots (one part each): (74, 94), (-82, -109), (19, -69). Slots 1-2 are **256** apart; the line between them is blocked after 104 by a container |
| Floor levels | deck **0** (95k sq studs) and a lower dock strip **-2.5** along the east water edge (92k incl. the yard); water **-9** (a flat SmoothPlastic Part, colour 48,98,173) |
| Lanes | **3**, about 30 wide each: yard lane (west, between the yard stacks and the west warehouse), mid lane (between the two warehouses, containers in it), quay lane (east, along the water and the east building) |
| Big blockers | 2 warehouses, **staggered** (W: 28 × 85, z -60..24; E: 32 × 70, z -92..-24), 35-46 tall, overlapping only 36 studs along the lanes, so the lanes connect round their ends; a south building 85 × 30 with a +15 deck; a north footbridge at +25 between the warehouses |
| Cover heights | crates mostly **4-5.5** (low), 8 when doubled, 13-20 in tall stacks; barrels 4; roadblocks 4.5; containers **10.5**, stacked to 20.5, rarely 31-41; outer fences 17 |
| Heights and climbs | steps +2/+4 (crates), container tops +10, decks **+15** (2 ladders), roofs **+25** (4 ladders), one +31 ladder; outside stairs to the +15 deck on the south building. **Ladders** (invisible TrussParts) are the main climb |
| Sightlines (eye height, 8-stud grid, 16 directions, inside the core) | longest **204**, mean 32, only **4%** of rays over 100 |
| Landmark | 2 cranes (red, yellow) 70-80 tall off the north end of the yard, outside the play space |
| Filler | 161 containers (most of them a backdrop wall in the yard), crates, pallets, barrels, cones, shelves, railings, buoys, lights, cleats |
| World | 5 low-poly island meshes 400-700 wide, 70-140 tall, 200-800 out (grey rock, green tops); a fake ship 700 out; the water Part 2,000 wide; outer barrier walls ~500 out, an instant-kill slab under the water |

**How it's built:** buildings are mostly **Parts** (128-314 per building, plus "Trim" parts and a few MeshParts for windows and details), floors are Parts with a fine Texture (1.25 studs a tile) on Sand violet / Sand green SmoothPlastic; containers, crates, barrels, cones, lights and cranes are a **MeshPart kit** (98 unique meshes, 1,018 MeshParts); collision is separate invisible `Hitbox` parts. Edges are raw blocks; colour does most of the work. Pipe railings run along every water edge.

**Edges and the world beyond (2-3 other RIVALS maps, `ServerStorage.MapsRivals`, one at a time in Workspace, put back):**
- **Docks:** islands all round in the water, the container yard continues past the play edge as a backdrop wall of stacked containers, the cranes stand outside play.
- **Bridge:** the play strip is a slice of a much longer road bridge that runs on into haze (lamp posts repeated), layered hazy mountain ridges in 2-3 depths, water and green land far below. The world continues past the play edge, so the edge reads as a choice, not a cliff.
- **Iceberg:** one 1,500-wide water Part with a soft texture, the map's edge broken into floes of falling size, a fake ship and flat ice shelves on the horizon.

Lessons we take: the world continues past the bounds (yard stacks, the crane, islands), 2-3 depth layers fading in the atmosphere haze, edge rails along water, one big water plane, a fake ship on the horizon.

## 2. Wharf layout (`python tools/maps/wharf_layout.py`)
Pier 130 × 185 (x ±65, z ±92.5), 180° rotational symmetry, **+Z = team A**. All sizes on the 5-stud module.

```
          z +92  ~~~~~~~~~~~~~~~~~~~ water ~~~~~~~~~~~~~~~~~~~~~~~
                 |OFFICE A +12 |st|           A A                 |
          yard   |_____________|ai|          spawns               |
          stacks |cont +10 |7|3|r|                                |   water
          (bound)          |      [==spawn ctr==]       |quay|    |
                 |                                       |ctr |    |
                 |  [yard  ]   ...       [mid cross+20 ]           |
                 |  [cont  ]  crates   [crate]   ___________  |box|   ~~
                 |  [      ]            stack   |          |dk|   |     QUAY
                 |                    crates    |  SHED B  |dk|        CRANE
                 |[reefer]                      |  (+14)   |crate    (landmark,
          z 0    |landing'  |  SHED A  | [mid] |__________|  |landing  off the pier)
                 |  -3      |  (+14)   | [ctr] ...rotated half ...
          z -92  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                x -65          -17.5    0     17.5    37.5      65
```
Plan image: `vault/02 Art/References/maps/wharf/wharf-layout.png` (+ SVG).

| Check (layout script) | **Wharf** | Docks / rule |
|---|---|---|
| Floor | 130 × 185 = 24,050 sq studs | Docks core ~180 × 228; duel rule 100×140 to 190×120 |
| Spawns | 4 a side at (−2.5..7.5, 75..80), gap **155** | duel 120-160 |
| Longest eye-height line | **158** (B's yard corner to A's yard, a 15° diagonal) | Docks 204; RIVALS Arena 144 on this script |
| Rays over 0.55 × gap | **9.5%** | Pier 8.2%, RIVALS Arena 18.3% |
| Lanes across the middle | 3 main (yard 28, mid 2 × 12 round the mid container, quay 26) | 3-5 |
| Cover | 25 full + 4 low, 26.9% footprint (28.5% eye-height blocked) | 25-35% |
| Pinch gaps < 6.5 | **0** | 0 |
| Heights | landing **-3** (low ground), floor 0, shed dock and crates **+3.5**, step crate +7, containers +10, office deck **+12** (parapet to +15); the dock crate stack is 12 (not a perch) | ≥3 heights |
| Office deck ways up | outside stair, or crate 3.5 → 7 → container 10 → deck 12 (rises 3.5 / 3.5 / 3 / 2) | 2 ways |
| Enemy-half floor that sees a spawn | 1.8% | Pier 0% |
| Sprint spawn → centre / → enemy spawn | 3.8 s / 7.8 s | Pier 3.3 / 7.3 |
| First sight, head-on rush | **3.4 s** | target 3-5 |

**Flow (like Docks):** three lanes split by two staggered sheds (each 20 × 60, walls 14, ridge 21) that overlap only 20 studs, so each outer lane opens into the mid lane round one shed end; the mid lane is cut by the mid container (two 12-wide sub-lanes) and a crosswise container with a second one stacked on its yard end (+20, a landmark-sized block in mid); the yard lane has a long container, a reefer and crates; the quay lane has the shed's +3.5 loading dock (walkable, shoot-over), a crate stack, a quay container and the sunken landing. Each team's harbour office sits in its yard corner behind its spawn; its +12 roof deck overlooks the yard lane.

## 3. Build plan
- **Where:** match place `Workspace.Wharf`, pivot (6000, 200, 6000) = deck top at the pier centre (far from every other map, so its ocean and mountains overlap nothing).
- **Builder:** `tools/studio/maps/Wharf/Build.luau` (one script, edit mode, idempotent; layout rows from the layout script). Folders: `Collision` (invisible boxes from the layout, the play truth), `Structure` (deck, edges, sheds, office), `Props` (containers, crates, bollards, railings), `World` (ocean, yard stacks, crane, mountains, ship), `Spawns`, `Barriers` (empty: ghost hold), `Bounds` (invisible walls + ceiling), `Lighting`, `LightingFx`, `WinnerStage`.
- **Mostly Parts** on the 5-stud module with carved ends (WedgePart chamfers on every exposed end, battered plinths, capped beams). **Blender** (live MCP, port 9897) only for the quay crane, the mountains, and the port kit (containers + bollard, recoloured).
- **MaterialVariants** (our own, procedural, faint ±4%, 512): `Wharf_Concrete` (10-stud slabs with seams), `Wharf_Asphalt`, `Wharf_Plank`, `Wharf_Ribbed` (sheet metal ribs), `Wharf_Plate` (steel plate, welds). `tools/textures/make_wharf_textures.py`.
- **Accent:** ~~crane yellow only~~ replaced by palette v2 after the owner's note (see Build log 6). Team colours stay off the map.
- **World:** the ocean is one blue Part (4,000 across, non-colliding); faceted mountains in two depth layers; yard stacks past the west bound; a ship on the horizon.
- **Light:** morning (ClockTime 9), sun from the east behind the crane, cool shade, haze for depth; Pier is midday, Dockyard late afternoon.
- **Contract:** `ArenaSpawn_A/B` spawns, `Bounds` + ceiling, `KillDepth` 6 (the water kills), `Lighting` Configuration + `LightingFx`, a `WinnerStage` part, `Config/Match` MAPS entry (1-2), `ForceMap = Wharf`.

## 4. Build log (2026-11-20, one session)
1. **Layout** (`tools/maps/wharf_layout.py`) iterated 6 times: longest line 187 → 158, rays over target 17.5% → 9.5%, pinches 12 → 0, first sight 1.8 s → 3.4 s (a crate stack hugging the mid lane's shed corner broke a 92-stud line along the shed face). Office runs to the pier end (no dead strip behind it); the mid stack is a 15-long box.
2. **Textures** (`tools/textures/make_wharf_textures.py`): 5 procedural 512 MaterialVariants, ±2-5% value, uploaded as decals (image ids in the builder): `Wharf_Concrete` (10-stud slab joints), `Wharf_Asphalt`, `Wharf_Plank`, `Wharf_Ribbed`, `Wharf_Plate`. Preview: `vault/02 Art/References/maps/wharf/wharf-variants-preview.png`.
3. **Blender kit** (live MCP, Blender 5.2 on port 9897; `tools/blender/maps_wharf/wharf_pieces.py`, `run_wharf.py`, `run_wharf_export.py`): QuayCrane 1,688 tris (portal on bogies, braces, box-girder boom with a tapered tip, A-frame + flat-bar stays, machinery house, trolley, cab, spreader), MountainA/B/C 440-816 tris (faceted islands whose shore dives under the water, no flat skirt to fight the sea), Ship 2,776 tris. Uploaded as asset 107834202851825, installed in `ServerStorage.MapKit.Wharf`. Renders: `kit-crane.png`, `kit-mountain-a/b.png`, `kit-ship.png`.
4. **Builder** `tools/studio/maps/Wharf/Build.luau` → `Workspace.Wharf` (1,746 parts incl. kit meshes): `Collision` (layout boxes, invisible, impact material), `Structure` (deck slabs with pits, fascia + fenders + piles on every water edge, two sheds with battered plinth, columns, eave ring, gable roof, ridge cap, roller doors, clerestory windows, loading dock with nosing, bumpers and steps; two harbour offices with plinth, belt course, parapet + copings, windows, door + hood, outside steel stair with landing), `Props` (port kit containers on collision boxes, crates built from Parts, bollards / wheel stops, pallets, railings, yard barrier blocks), `World` (ocean 3 × 3 tiles of 2048, outer berth with the crane and a ship alongside, yard stacks near row in kit containers and far rows in ribbed boxes, floodlight masts, mountains in two depth layers, a horizon ship), `Spawns`, `Bounds` (+60 ceiling), `Barriers` (empty), `WinnerStage`, `Lighting` + `LightingFx`.
5. **Owner notes mid-build (2026-11-20):** "colours are dull and boring", "the signs with text look unprofessional, we don't need them", "a good amount of overlapping and glitch parts". Done: **palette v2** (below), every text sign removed, overlaps fixed at the source until both audits read 0.
6. **Palette v2 (owner call, replaces the one-accent rule for this map):** warm light concrete `C2BDB2`, dark asphalt `4E525A`, sea `2A62AE`; containers in port colours (blue, green, red, orange, yellow, white, grey; body + darker frame); each half's buildings in their own paint so the sides read by colour: **A blue** (`4F82C4`, trim `27416B`), **B green** (`5AA368`, trim `2D5A37`), never the team cyan / orange-red; crane yellow `EBB531` on the crane, edge safety lines, barrier bands; greener hills. Grade: contrast 0.08, saturation 0.08 (0.14 read toy-like). Light: ClockTime 10.5, Brightness 3, Exposure 0.2, Atmosphere density 0.28 / haze 1.6.
7. **Fixes from the checks:** the dock crate stack was a 6.5 climb from the dock and a 5-stud hop from it reached the quay box top (an unplanned +10 perch chain): raised to 12 (8.5 above the dock). The ship's waterline sat flush with the sea (raised 1). The kerb between asphalt and concrete ran under a dock, a crate and a container (removed). Coping runs overlapped at parapet corners, fascia boards shared end faces with roofs, railing runs doubled their end posts, stacked crate battens met lid rims, far yard tiers floated 0.2 (all fixed in the builder).

## Checks (all run on the built map, 2026-11-20)
| Check | Result |
|---|---|
| Z-fighting (`tools/studio/maps/Audit.luau`) | **0 pairs** of 1,707 visible parts (first run 268) |
| Floating (`tools/studio/maps/FloatAudit.luau`; sea, mountains and ships excluded as water-borne) | **0 groups** of 1,665 parts (first run 56: far yard tiers, a pallet) |
| Reach + clearance (`tools/studio/maps/Wharf/Checks.luau`: 1-stud grid, 2 × 4.6 × 2 body box, walk rise ≤ 1.3, jump rise ≤ 7.0 within 2 cells, gaps ≤ 8 at rise ≤ 1) | every planned surface reached from A: floor, pits −3 and their steps, docks +3.5, step crates +7, office containers +10, office decks +12; **not** reached: shed roofs +14, mid stack +20, dock crate stacks +12, any other container top. Planned climbs rise 3.5 / 3.5 / 3 / 2 (under the 4.4 jump, no ledge trick). Parapet tops (+15, 3 over the deck) are standable: noted, minor |
| Spawn travel balance (same flood) | A → centre **94** studs / B → centre **94**; A → B spawn 160 / B → A 161; own office deck 62 / 61 |
| Playtest (Play, `ForceMap = Wharf`) | Wharf loads (vote skipped), spawns on A's markers, map lighting applies, draft → countdown → live. A server-side R15 walk tester: up the office stair to the deck in 1.7 s, across, down onto the container; pathfinding with **jumps off**: mid lane A→B 12.5 s, quay lane through the landing pit 15.8 s, yard lane through the loading pit 14.6 s, along the shed dock: all arrive, no stuck spot |
| Vote | played once after the rotation cut (before Wharf was added): a 2v2 vote offered Random, Arena, Pier, Big Arena, Dockyard and loaded the pick. Wharf is now in `Config/Match` MAPS (1-2), so it joins the 1v1/2v2 list; that vote wasn't re-run |

**Self-review against RIVALS Docks (same kind of views, `third-party/maps/` + this session's Docks captures):** layout clarity and lane reads match (three lanes, staggered big blockers, containers as cover, a crane landmark, islands round it); colour now reads as a real port like Docks. Weaker than Docks: fewer mid-size props (no barrels or cones: round shapes are off-limits, so crates, pallets, bollards, barrier blocks and masts carry it), simpler buildings (Docks' sheds have windows bands, X-trims and interiors), less vertical play (Docks has +15 decks and +25 roofs by ladder; Wharf stops at the +12 office decks). Not a score, a list for the next pass.

Captures (`vault/02 Art/References/maps/wharf/`): `wharf-overview.jpg`, `wharf-spawn-a.jpg`, `wharf-spawn-b.jpg`, `wharf-lane-mid.jpg`, `wharf-lane-yard.jpg`, `wharf-lane-quay.jpg`, `wharf-horizon-office-deck.jpg`.

## 5. What to test (owner)
1. Save the match place (the map, the kit and the MaterialVariants live in it).
2. `ForceMap = Wharf`, `TestMode = false`, Play; put both back after.
3. Run each lane: yard (asphalt, loading pit), mid (between the sheds), quay (shed dock, landing pit by the water). Check the first fight lands about 3-4 s after the hold.
4. Your office deck: the outside stair, and the crate → crate → container → deck route; the parapet as cover; the view down the yard lane.
5. Slide runs along the sheds; Updraft over the containers and onto the shed roofs (roofs are solid, +14 to +21).
6. Colour: does the blue (A) / green (B) split read, and are the containers lively without being toy-like?
7. Anything you still see overlapping or flickering: tell me the spot (both audits read 0, so it would be a mesh or a light issue).

## Open / next
- Map vote picture (`image` in `Config/Match`) not made yet: the card shows the plain band.
- MapLife (gulls, a drifting horizon ship, the crane's spreader sway) and Ambience emitters: only the Ambience beds are in.
- More mid-size props and one more height (a +15 walkway between the sheds, like Docks' footbridge) if the owner wants more verticality.
