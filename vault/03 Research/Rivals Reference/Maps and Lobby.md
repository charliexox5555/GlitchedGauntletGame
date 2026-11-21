# RIVALS reference: maps and lobby

Part of [Rivals Reference](00%20Rivals%20Reference.md). Measured read-only on 2026-11-15 in both sources (RIVALS file `ServerStorage.Maps` + `Workspace.Lobby`; match place `Workspace["Rivals Map Examples"]`). Cover is counted per part (kit pieces inflate it); sightline = longest free eye-height run on a 2-stud grid (estimate, not raycast). Our own rules win: [Maps hub](../../01%20Design/Maps/00%20Maps.md), [Jump Audit](../../01%20Design/Maps/Jump%20Audit%202026-11-13.md) (ledges 7.5, gaps 9). Screenshots: `third-party/maps/`, `third-party/lobby/` (local only).

## Map file convention
| Child | Holds |
|---|---|
| `Spawns` | a folder per slot (`1`, `2`, `3`); each part 4×5×1, invisible, no collide. Duel maps: one part per slot; big maps 4-5 per slot, 6-36 apart |
| `SpawnsArcade` | 55-133 extra spawns (arcade modes, some maps only) |
| `Barriers` | five tiers: `Invisible` (walls + ceiling hugging play, Arena's ceiling ~140 up) → `OOB` (warning volumes) with an `OOBSafe` hole = the playable box → `InstakillOOB` slab under the map (`WarnDelay`/`KillDelay` attributes = 0) → `OuterBottom` + `Outer` walls 270-1000 out. Splash adds `KillBrick`s over water |
| `Winners` | victory-pose anchor (`Primary` + flat `Reference`) |
| `Primary` / `Spectate` | map origin at floor; spectator camera part 40-60 up in a corner |
| `Entities` | destructibles (explosive barrels, breakable windows) |
| `Extra` | all art and collision, split into **category folders** (Docks: Containers, Cranes, Crates, Fences, Floor, Lights, Pallets…) |

**Lighting is not in the map:** per-map client profiles (`Assets.LightingProfiles.<Map>`: an Atmosphere + Sky; some have MatchPoint / SuddenDeath / Day / Dusk / Night variants). Global Lighting stays Brightness 3, Ambient 0.47 grey, ClockTime 12.

## Per-map numbers
| Map | Spawns / gap | Play area | Parts / Mesh / Union | Cover low/chest/full | Longest sight | Lanes | Look |
|---|---|---|---|---|---|---|---|
| **Arena** | 2 / 121 | 100×140 | 68 / 0 / 1 | 4 / 0 / 22 | 49 | 2-3 | grey SmoothPlastic + one grid texture (5-stud tile, 0.75 transparent) ×143 |
| **Big Arena** | 3 / 80-160 | ~200 round | 83 parts | 0 / 30 / 39 | – | – | same kit as Arena |
| **Docks** | 3 / 108-256 | ~290×330 | 1453 / 1042 / 5 | 60 / 166 / 459 | 164 | 5-7 | MeshPart kit (98 unique meshes, Container ×161), grey + coloured containers |
| **Construction** | 2 / 125 | ~125×150 core | 409 / 118 / 1 | 60 / 20 / 22 | 75 | 2-4 | Parts + 521 Textures (brick walls = 3 Parts with 4 Textures each), +22 deck |
| **Big Crossroads** | 3×4 / 246-300 | ~650×610 | 2307 Parts only | 57 / 33 / 75 | 650 | 3-5 | stud-style specialty map, +0 to +31 plateaus |
| **Splash** | 2 / 195 | 264×264 | 41 / 171 / 2 | 0 / 0 / 40 | 133 | 2-4 | Rubber tile kit (Square, Rectangle, Corner, Ramp, Arch) in primaries |
| **Big Splash** | 3 / 220-381 | 420×420 | 145 / 280 / 1 | 0 / 0 / 82 | 420 | 1-3 | same |
| Battleground | 2 / 206 | 317×356 | 974 / 393 / 9 | 37/40/110 | 178 | 7 | concrete, brick |
| Backrooms / Big | 2 / 159 · 3 / 124-180 | 120×133 · 170×171 | 102/273 · 244/410 | 112/0/44 · 162/0/61 | 67 · 172 | 3-4 | yellow-olive |
| Bridge | 2 / 152 | 171×168 | 322 / 374 / 5 | 16/38/14 | 73 | 3-5 | concrete, orange accent |
| Village | 2 / 185 | 300×300 | 192 / 424 | 0/2/76 | 150 | 2 | snow |
| Gate | 2 / 161 | 190×115 | 125 / 0 / 23 | 2/0/19 | 96 | 2-4 | 763 Textures, claustrophobic |
| Chess | 2 / 269 | 148×333 | 148 / 67 | 0/0/25 | 167 | 1-2 | black/white wood |
| Westown | 3 / 185-352 | 124×377 | 1139 / 490 | 38/94/196 | 175 | 2-6 | wood |
| Iceberg | 3 / 160-234 | 420×420 | 109 / 221 | 18/31/20 | 210 | 5-10 | ice, snow |
| Dimension | 2 / 165 | 124×188 | 683 / 303 | 87/37/159 | 122 | 2-3 | portals |
| Factory | 3 / 107-121 | 235×230 | 258 / 17 / 8 | 0/0/97 | 236 | 3-4 | grey + amber |
| Playground | 2 / 120 | 151×150 | 293 / 552 | 34/18/29 | 152 | 1-2 | saturated |
| Sandbox | 2 / 183 | 200×200 | 100 / 64 | 0/2/17 | 188 | 2-3 | sand, wood |
| Station / Big | 3 / 101-204 · 107-239 | 166×252 · 243×291 | 1132/955 · 2078/1628 | 113/108/274 · 65/204/490 | 254 · 168 | 5-6 · 4-9 | wood, concrete |
| Museum | 3×3 / 20-40 | 169×290 | 1206 / 972 (56 lights) | 218/39/128 | 236 | 3-4 | marble, brick |
| Studio | 3 / 145-149 | 212×180 | 1364 / 331 | 73/30/137 | 120 | 4-5 | concrete |
| Graveyard / Big | 2 / 196 · 3 / 172-196 | 252×160 | 628/788 · 745/876 | 10/5/31 · 26/6/38 | 244 | 1-4 | wood, ground |
| Onyx / Big | 3×2 · 3×5 / ~200-224 | ~530 · 550×488 | tiny | almost none | 534-550 | 1-4 | lava arena |

Height levels: ~85-90% of the area is floor; Arena +3 / +15 / +20, Docks +2/+4 steps, +15 decks, +27 gantries; Construction +22; Splash +9/+10; Station +1 / +14 / +15.

## Construction (how they're built)
- **Arena:** pure Parts: wall slabs 140×30×5, one floor plate, 7 tiny cover Models of 2-5 parts (20×15×5 walls, 20×20×15 and 20×20×20 blocks), one grid texture over grey.
- **Docks:** a **MeshPart kit with heavy reuse** (1042 MeshParts, 98 unique meshes); a Container is 9.4×10.2×27.5 with a separate `Hitbox` Part; floors are Parts with Textures.
- **Construction:** **Parts + Textures**: repeated small Models (Brick Wall ×23, Beam ×36), `Extra` sorted by material.
- **Splash:** a 41-mesh tile kit in Rubber.
- **Edges are raw blocks**; detail comes from textures / SurfaceAppearance and colour, wedges only for roofs and ramps. Collision is always separate invisible parts. (Our own rule is stricter: carved ends, no blunt cutoffs: `gauntlet-build-style`.)

- **Museum (build study 2026-11-21, [Foundry4](../../01%20Design/Maps/Foundry4.md#rivals-build-study-2026-11-21-read-only)):** big Part masses wearing tiling variants (`StoneBlock_01a` ×665, `Concrete-02a` ×484); 972 MeshParts of only 125 meshes, mostly trims and joins: `GrandTrim_0Na/b/c` stacks three profiles of different depth (3.9 / 2.6 / 2.9) that touch exactly, round every pillar head and wall top; the meshes wear the same variants as the Parts, so joins don't show; one warm-grey colour family (±10% value).

## Rules worth adopting (with numbers)
1. **Size by team size.** 1v1-2v2 ~100×140 to 190×120, spawns 120-160 apart. Mid 200-300 across, spawns 180-200. 4v4 250-420 across, spawns 220-380.
2. **Close the box:** invisible wall box (+ ceiling) or OOB with an OOBSafe hole, a zero-delay kill slab below, far outer walls.
3. **Cover blocks ~25-35% of the eye-height area** on duel maps (Arena 34%); open maps 12-20%. About **one piece per 400-600 sq studs**; full cover dominates (Arena 22 full : 4 low).
4. **Longest sightline ≈ half the spawn gap** on small maps (Arena 49 vs 121; Construction 75 vs 125); big maps allow 130-250 on one or two marked lines only.
5. **3-5 open lanes (≥6 wide) across the midline** on small maps, 5-7 on big ones; under 2 = corridor fight.
6. **Mostly flat:** steps +3 to +5 (inside our 7.5 jump), platforms +9/+10, one or two decks +15 to +25.
7. **Spawns are small markers**, not rooms; the spawn-to-spawn line is partly blocked (Arena ~10%, Docks ~30%).
8. **Grey structure, one accent on cover and landmarks** (red containers, orange, blue); saturated maps make the silhouette the whole look.
9. **Budget:** duel map ~250 instances, mid 700-1,300, dense 2,900-3,300 only with heavy mesh reuse and category folders.
10. **Lighting per map in a profile**, with match-point / sudden-death variants.

## Map studies
### Arena / Big Arena (2026-11-16, for [our Arena](../../01%20Design/Maps/Arena.md))
- **Layout (Arena, 36 visible parts):** floor 100 × 5 × 140, walls 140/90 × 30 × 5, spawns at z ±60 (gap 121). Cover: 4 window arches (two 5 × 12 × 5 posts, a 10 × 5 × 5 lintel, a 20 × 3 × 5 base; two turned 150°), 2 wall + block pairs (20 × 15 × 5 + 20 × 15 × 15), a 4-pillar canopy in the middle (5 × 15 × 5 pillars, 20 × 5 × 20 roof at +20), 4 slabs 20 × 20 × 5 and 2 blocks 15 × 20 × 10.
- **Look:** two colours only: structure and arches Sand violet metallic (151,153,163), slabs and blocks Silver flip/flop (132,134,143), SmoothPlastic; one overlay Texture on every face (5-stud tile, black, 0.75 transparent): thin seams with a plus cross at each joint. Sizes are multiples of 5, so the grid lines continue from part to part. No trims, no extra parts.
- **Measured with our layout script** (`tools/maps/arena_layout.py rivals`, calibration only): longest eye-height line **144** (a wall-hugging diagonal; the "49" above was a different estimate), 18.3% of rays longer than 0.55 × the spawn gap, 3 lanes across the middle, 15% cover footprint, 2.2 pieces per 1000 sq studs, spawns unseen from the enemy half, first sight on a head-on rush 1.8 s.
- **Big Arena:** round court ~200 across, same kit, 3 spawns a side (80-160 apart), 30 chest / 39 full cover (aerial in `third-party/maps/`).
- **For us:** take the module (5-stud sizes, 10-high cover, 30-high walls), the two-tone + grid overlay and the restraint; our own layout, spawn hold and landmark. Edit-mode captures of the RIVALS file come out white when its window isn't drawing; use the saved shots.

### Docks (2026-11-16, for [Pier and Dockyard](../../01%20Design/Maps/Pier%20and%20Dockyard.md))
- **Kit:** containers 9-10 wide × 10 tall × 27 or 34 long (608 parts from 4 meshes), stacked two high in places; flat colours grey (163,162,165, most common), blue (80,105,158), green (55,121,44), red (189,73,73), purple (184,98,255), orange (255,177,67). Crates (13 meshes), barrels, pallets, cones, railings, bollard cleats, lights, shelves, roadblocks, 16 building meshes, 2 gantry cranes (107 long × 70 tall, orange and red) off the far end.
- **Layout:** deck top about +9.5, water lower; core play area about 180 × 216; 3 spawn groups (108-256 apart); big warehouses 69 × 41 × 82 make the edges; two-storey buildings with interiors in the middle.
- **Mix:** MeshParts for the shaped things (containers, crates, buildings, cranes), plain Parts for floors and simple walls; category folders under `Extra`.
- **For us:** the 10 × 10 × 30 container as the module, stacks of two, crates as steps, one crane as the landmark, flat colours with one accent (red); our own layouts and meshes.
- **Measured again 2026-11-20 (match place `Workspace.Docks`, raycasts, for [Wharf](../../01%20Design/Maps/Wharf.md)):** core 180 × 228; 3 spawn slots, slots 1-2 256 apart, the line blocked after 104; floors deck 0 and a lower dock −2.5, water −9; 3 lanes ~30 wide split by **two staggered warehouses** (28 × 85 and 32 × 70, overlapping 36 studs); cover: crates 4-5.5, doubled 8, containers 10.5 (stacks 20.5); climbs by **ladders** (TrussParts) to +15 decks and +25 roofs, outside stairs to one +15 deck; eye-height sightlines longest 204, mean 32, 4% over 100. Buildings are mostly Parts (128-314 each) with a few MeshParts; floors Parts with a 1.25-stud texture. World: 5 low-poly islands 400-700 wide 200-800 out, a fake ship, a 2,000 water Part. Other maps for edges: **Bridge** (the play strip is a slice of a road bridge that runs on into haze, layered ridges) and **Iceberg** (one 1,500 water Part, the edge broken into floes, a ship and ice shelves on the horizon): the world continues past the bounds.

## Lobby (RIVALS file `Workspace.Lobby.Hub`)
- **Plan:** a compact **cross** about 340×290: a round centre hub (spawn on a ringed logo dais, holograms around it) with short wings: **Duels** hall, **Market** (holo-bays: UGC shop, season pass), **Weapons** room (display tables), **Hallway**, and the **outdoor shooting range** facing a landmark hill. Separate `WaitingRoom` and `ShootingRange` rooms elsewhere. See `lobby/04_topdown_plan.jpg`.
- **Walks from spawn** (16 studs/s): range 68 studs (~4 s), first pad ~102 (~6 s), farthest pad ~232 (~15 s), weapons ~100, market ~137.
- **Look:** dark charcoal metal, white bar lamps, **purple + yellow floor lines** that lead to each wing, neon signs per wing, caution signs and crates as dressing; 1,445 MeshParts, 96 SurfaceGuis, 36 SpotLights, 27 SurfaceLights, 68 Beams, 86 emitters; holograms and TVs carry the "life". Camera-blocker planes stop the camera clipping walls.
- **Queue pads** (10, two rows 48 apart, pads 27-39 apart; 1v1 ×2, 2v2 ×2, 3v3 ×2, 4v4, 5v5, 1v1v1, 2v2v2). Each ~116 instances, 21×34×29:
  - mode from attributes `QueueName`, `PlayersPerTeam`, `NumTeams`;
  - a neon title plate + player-count plate (SurfaceGuis), two dark board plates with a Beam shimmer;
  - per team a floating, rotating ring hologram (7 neon MeshParts on AlignPosition / AlignOrientation / AngularVelocity) and an invisible trigger volume (gold `#a38733` / purple `#7349a2`);
  - floor: metal plate + translucent plate, 9-high side panels, team-colour neon trim strips, a base slab. See `lobby/03_queue_pads_close.jpg`, `09_duels_end_1v1_2v2.jpg`.

**For us:** our lobby direction is our own (light tactical, gold accents, no neon/glitch: Home → Locked decisions → Art). Take the **plan** (compact cross, short walks, Duels hall with pads both sides and mode signs over the lanes), the **pad logic** (mode attributes, count board, team triggers) and **walk times**. Don't take the neon-heavy look.

## What makes it work (lobby study, 2026-11-16)
Read from the RIVALS file (`Workspace.Lobby.Hub`, read-only: property reads and raycasts from the spawn at `(109, -681, 1184)`, no play, no scripts) plus the saved shots `lobby/01, 02, 04, 05, 08, 09`. Numbers in studs; walk = 16 studs/s. Used for the [Lobby V4 Plan](../../02%20Art/Lobby%20V4%20Plan.md). **Study, don't copy:** the "for us" lines are our versions, in our look.

**The file's own split:** `Hub.Important` (2,599 instances: the gameplay bits: Center, Duels pads, Displays, Range sign) and `Hub.Extra` (3,079: shell and dressing per wing, plus 12 `CameraBlocker` planes and blocks loose at the top). Whole hub about 5,700 instances, 1,445 MeshParts.

### 1. Spawn view and flow
1. **One axis, one promise.** The spawn stands on the centre dais facing east down a 256-stud line: dais → Duels doorway (40 away) → the whole Duels aisle → the far door. The first frame is the DUELS sign (22 wide, 32 up, tilted at the spawn) with two white lamps under it and the pad hall behind. What you came to do is the first and deepest thing you see.
   *For us:* the spawn faces the Duels mouth on one long axis; the Duels sign tops the first frame, and the far end of Duels has a lit end wall so the line has a destination.
2. **The ring round the dais is the floor-line hub.** Two accent lines (purple + yellow) ring the logo dais and peel off into each doorway; the Duels aisle carries both, one per side, to the far end. Lines do the wayfinding; the walls stay grey.
   *For us:* one gold line ring round our landmark and one gold lead into Duels (the main action). Other wings start their own accent at their threshold (one accent per room).
3. **Everything else sits on the diagonals.** The four doorways are on the axes (E Duels, W Range, N Market, S Weapons). Between them, at radius 25-30: 6 hologram stands (rewards, ranked, bundles; 3 more empty bases), 4 wall TVs (8-16 wide, 12-20 tall, bottoms 3-12 up: Duels, Likes, Leaderboard, Starter bundle) and an arcade cabinet. Doors stay clear; the "stuff" is in the corners.
   *For us:* keep the axes clear; boards and the social niche go on the diagonal faces.
4. **Bunching:** players stop at the dais (spawn), the reward stands beside it, the pad squares and the range window: all within 40 of the spawn except the pads. Nothing to sit on: standing on things is the social act.
   *For us:* one place to stand on (a stepped dais) and one to sit (a niche), both off the walking lines.

### 2. Layout (rays at eye height)
| Area | Doorway (w × h) | Room (w × h) | Length | From spawn |
|---|---|---|---|---|
| Hub (round) | 4 axis doors | ~85 across, ceiling 37 | — | 0 |
| Duels (E) | 27-30 × 30 | 64-67 × 33, then 47 in the back half; floor steps down 4-6 | ~200 | sign 40, first pad ~100 (6 s), last ~230 (15 s) |
| Weapons (S) | 26 × **17** | 65-88 × 33-37 | ~60 | ~100 |
| Market (N) | 26-31 × **20**, then a 31 × 27 corridor 70 long | opens to 77-118 wide | ~100 | ~137 |
| Range (W) | 25 | 70-110 × 38, then a window onto the outdoor range | ~50 + yard | window ~70 (4 s) |

5. **Compress, then release, on every wing.** Weapons and Market doors are 17-20 high under a 37 ceiling, then open into 33-37 rooms; Duels goes 30 → 33 → 47 and drops 4-6 in floor height. The squeeze makes each room feel bigger than it is.
   *For us:* each wing door is a low, deep frame (16-20 high, 6-10 deep) into a taller room, and each frame is different (the owner likes different entries).
6. **Short walks, one long hall.** Everything but Duels is under 140 (9 s). Only Duels is long, and that is the walk you take every match.
   *For us:* farthest pad ≤ 150 (9.5 s), everything else ≤ 70 (4.5 s): shorter than theirs.
7. **The plan is a compact cross** (~340 × 290) with the range yard spilling outside. Five rooms.

### 3. Duels area
8. **Rhythm:** 10 pads in two rows facing a central aisle, rows 48 apart (about 19 clear between pad edges), pads 27-39 apart along the hall (x 208, 242, 281, 308, 340). A **pier with a vertical bar lamp stands between every pair of pads** (lamps at x 192, 225, 258, 309, 355, 18 up): pier, pad, pier, pad.
9. **Pad build:** a 21 × 29 footprint; two **team squares** side by side along the aisle (8 × 8 floor plates with a ring logo, gold / purple team outlines), sunk so the deck is 1-2 above the hall floor; a floating, spinning ring hologram over each square (7 neon parts on AlignOrientation / AngularVelocity: 88 movers in Duels); an invisible 10 × 13 × 13 trigger per team.
10. **How the mode reads:** not from the pads (they all look alike). A small white mode tag (9 × 2, about 23 up, tilted down at the aisle) hangs over each pad with the count board behind. From the door you read the *rhythm*, then the tags as you walk. Mode order from the door: 1v1, 1v1, 2v2, 2v2, 3v3, 3v3, 4v4 / 5v5, then 1v1v1 / 2v2v2 at the end.
11. **Waiting players are on show:** they stand on raised, lit squares right beside the aisle everyone walks down, against two dark boards per pad (10 × 14, 4-18 up), so the avatar is the brightest thing there. The queue is a stage.
   *For us:* keep "waiting = on show" and "piers carry the lamps". Drop the straight two-row aisle: the owner rejected that as too close to RIVALS in V3. Our pads go in mode order round our own room shape, each in a framed bay with its own mode board, lit like a stage.

### 4. Signs and boards
12. **Wing signs:** one big tilted sign per wing door (Duels 22 wide at 32 up; Weapons 20-26 at 27-28 up; Range 36 wide at 19 up over the window; UGC 34 at 13 up). Each is a neon outline word with an icon or arrows, **over the door, tilted down at the spawn**. One per door, never two.
13. **Small signs carry the jokes:** floor stencils (KEEP CLEAR, 35 long), department plates (MANAGEMENT, LABORATORY, WEST GATE), warning plaques (WARNING, BUNKER ACCESS). 96 SurfaceGuis in the lobby, most of them flavour.
14. **Every board has a light on it:** TVs and display walls get a SpotLight or SurfaceLight beside them (Displays: 9 warm spots for 17 boards).
   *For us:* one solid-letter sign per wing door (neon tubes and pictograms were rejected), plus a few department plates and floor stencils in our own words, each board lit by a real fixture.

### 5. Structure language
15. **Big chunky shell meshes, reused:** Duels has 217 MeshParts from **37 unique meshes**; Hallway 223 from 78; the hub 283 from 149 (the hub is where the unique pieces go).
16. **Ceilings are never flat:** a dark coffered vault over Duels, a ring of ceiling detail over the hub, a big lit end feature (red ring) at the far end of Duels.
17. **Floors are broken up:** the dark aisle, the lit pad squares, grated strips beside the aisle, the accent lines: four floor types in one hall.
18. **Camera blockers:** 12 large invisible planes and blocks (8-84 long) over door heads and outside thin walls, so the third-person camera can't clip through or see out.
   *For us:* one bay mesh for every pad bay, one pier, one lamp; a coffer or soffit on every ceiling; opaque invisible camera blockers over thin walls and door heads (our V3 "see-through when zoomed out" bug).

### 6. Life
19. **Counts:** hub 57 particle emitters (mostly the 6 hologram stands), 12 beams, 6 SurfaceGuis (4 TVs), 11 lights; Duels 88 movers (the ring holograms), 23 beams, 20 SurfaceGuis; Market 23 SurfaceGuis, 8 beams; Weapons 1 mover. Life sits where players stop (spawn ring, pads, shop bays), never in corridors.
   *For us:* mesh holograms are rejected. Our life is SurfaceGui boards with real content (live queue counts, leaderboard, featured skins), a few `LobbySpin` movers (a slow fan, turntables), soft dust in light shafts and the range seen through glass.

### 7. Lighting
20. Lighting service: Ambient `#797979`, OutdoorAmbient `#C6C6C1`, Brightness 3, noon, exposure -0.15. **Interiors run on few lights:** hub 11, Duels 19 (12 SurfaceLight bar lamps of range 60 + 4 red spots on the end feature), Weapons 10, Market 8, Displays 9. White to warm white (`#FFF3E6`, `#FFE4AE`); colour only on the end feature (red) and in the range (purple and amber spots).
   *For us:* the same as our rule: white lamp light, few lights, pools at doors and pads, one coloured feature per room.

### 8. Fun
21. **The range is 4 s from spawn and visible from it** (a big window with SHOOTING RANGE over it). Shooting is the first toy.
22. **Show-off spots:** the dais, the lit pad squares, the Weapons room's gun tables. Your skin is seen most while you wait on a pad.
23. **Things to do while waiting:** walk to the range, read the boards, the arcade cabinet, slide down the long aisle.
   *For us:* a range window in the hub, a stage to stand on, a slide run (the Duels walk), live boards.

## Shooting range study (2026-11-21, `Workspace.ShootingRangeRivals` in our Lobby place, read-only)
For [our range](../../02%20Art/Lobby%20V5%20Plan.md#range-v3-2026-11-21). Captures kept out of git (third-party).
- **Size and levels.** About 250 × 250 open-roof yard plus a 55 × 180 lane. Ground at +0; a **rooftop level at +50**: 10-wide, 2.5-thick walkways with 2.5 × 5 × 20 parapets run between building tops. Spawn and exit portals are in the middle at ground level.
- **Massing is the structure.** Thick (5) walls 50 high and solid 20 × 50 × 20 / 25 × 50 × 25 blocks make "buildings" and corridors. Walls have doorways and windows cut through, U-shaped walls, and pointed-gable arches under the walkways. Tall pillars (10 × 80-100 × 10) carry the tightropes high above. You always see structure overhead (bridges cross over the ground routes), and that's what reads as "a place", not a floor with boxes.
- **Parkour steps.** Clusters of 5 × 5 posts at 5 / 10 / 15 / 25 high climb to the walls. TrussPart ladders (2 × 51) run up building sides. Jump pads on the ground launch you to the roofs.
- **One material.** Plastic `#9799A3` with a grid texture whose 5-stud crossings show as "+" marks, everywhere. Only the lane floor, jump pads (neon blue), loadout bins (red) and the green/magenta "green screen" room are coloured.
- **The lane.** A walled corridor 55 wide, walls 55 high, 180 long. The floor is bands 25 deep in strong colours: red, orange, yellow, green, blue, purple, black. **Distance markers are text on both lane walls** at every 25: an invisible part with a SurfaceGui, "100" in white Rubik Heavy over a small italic "studs away", with a dark UIStroke, about 5 high, at eye height. No floor plates.
- **Jump pad** (3 MeshParts + a 11 × 3 × 11 trigger):
  - a square base plate 10.7 wide with clipped corners;
  - four raised corner blocks;
  - a dark deck;
  - a neon centre octagon and four neon bracket arcs pointing inward, separated by dark triangles.
  - It reads from far away because it's the only glowing thing on the floor.
- **Loadout bins:** red metal trash cans (3 × 3.5) with a lid that opens (Open/Close animations) and a ProximityPrompt.
- **For us:**
  - Build height and overhead structure, not just more floor clutter.
  - Keep one material with our grid.
  - Put colour on the lane floor and on the gameplay objects only.
  - Distance numbers big on the lane walls.
  - Jump pads modelled, glowing, readable at range.
  - Make our own layout and our own pad design (study, don't copy).
