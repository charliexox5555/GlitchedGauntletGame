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
