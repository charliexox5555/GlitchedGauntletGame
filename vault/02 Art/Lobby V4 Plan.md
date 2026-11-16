# Lobby V4 Plan (2026-11-16)

**Status (2026-11-16):** approved and **built** (owner: "just build again", with the RIVALS look: [Lobby V4 Theme](Lobby%20V4%20Theme.md)). Results, numbers, scores and the swap steps: [Lobby V4 Build](Lobby%20V4%20Build.md). **The Range is not built** (owner: not yet); its door is sealed. What changed while building: walls 34 high, the Duels portal 26 wide (clears the corner piers), the Duels bays at y 82 / 112 / 142 and 12 deep (the queue on show at the mouth), the apse end at y 182, a lowered kiosk, the farthest pad about 10.5 s from spawn. The ChatGPT concept step (§7) was skipped at the owner's call. Brief: [2026-11-16 Lobby Build (RIVALS study)](../04%20Tech/Prompts/2026-11-16%20Lobby%20Build%20(RIVALS%20study).md). Study it rests on: [Maps and Lobby → What makes it work](../03%20Research/Rivals%20Reference/Maps%20and%20Lobby.md) (numbered points 1-23 below as **R1-R23**).

**Rules this plan follows:** [Style Bible §7](Style%20Bible.md), `gauntlet-build-style` (facets, carved ends, joints, one accent per room, rejected list §7), memory notes on lobby art direction, Sunwell taste, concept-first. LihFolk: *Lobby and Hub Design* (spawn faces the centrepiece and one station; first station under 15 s; social nodes off the main flow, never in corners), *Level Design Principles - Flow Sightlines and Landmarks* (landmark ≥ 3-5° of view; compression under 5 s, ceilings ≥ 3 character heights; test leak rays from max zoom), *Art Budgets - Triangles Draw Calls Memory* (instance count drives join time; a handful of shadowed lights on phones; small and Neon parts CastShadow off), *Readable Text and UI Scale* (titles ≥ 20 px on a phone), *Level of Detail and Model Streaming*.

## 1. What we take from RIVALS, and what we don't
| Take (logic and numbers) | Don't take |
|---|---|
| Spawn on one long axis that ends in Duels (R1) | Their round hub, logo dais, two-row pad aisle (V3 was rejected as "too close to RIVALS") |
| Doors on the axes, boards and stuff on the diagonals (R3) | Neon tube signs, holograms, purple/yellow lines |
| Compress-then-release doors, each one different (R5) | Their meshes, textures, signs, jokes |
| Short walks: everything ≤ 4.5 s, farthest pad ≤ 9.5 s (R6, ours shorter) | 15 s walks |
| Waiting players on a lit stage; a pier + lamp between pads (R8, R11) | Floating ring holograms |
| One sign per wing door, tilted at the spawn; every board lit (R12, R14) | Pictograms, thin letters |
| Heavy mesh reuse, never-flat ceilings, broken-up floors, camera blockers (R15-R18) | — |
| Range seen from the hub (R21) | — |

## 2. Layout (top-down; origin = spawn dais centre, +X = towards Duels; studs)
```
                         N
             ┌──────── SUPPLY ────────┐
             │ Shop counter  |  Season│   z 52 → 112
             │ bays (coral)  |  Pass  │
             └──────┐  door  ┌────────┘
                    │ 20×16  │
   ┌─RANGE YARD──┐ ╱──────────╲            ┌──────────── DUELS (gold) ─────────────╲
   │ lanes, mesa │╱ NW: seats  ╲ NE: board │ 3 bays: 1v1 1v1 1v1                    ╲
   │ + mast      ║   ┌──────┐   ║ portal   │                                        ╲ 2v2
   │  (lime)  ◄──║window│ ◆  │ ═══════════► │   ┌──────┐   (hall drops 3)  TROPHY ►  │
   │  gate  ◄────║ +gate│dais│   ║ 22×18   │   │island│                            ╱ 2v2
   └─────────────╲   └──────┘   ╱          │ 3 bays: 3v3 3v3 4v4                    ╱
                  ╲ SW: board  ╱ SE: board └────────────────────────────────────────╱
                   ╲──────────╱                 x 56 → 156
                    │ door   │
             ┌──────┘ 18×16  └────────┐
             │   LOCKER gallery       │   z -52 → -104
             │   (violet)             │
             └────────────────────────┘
                         S
```
Whole lobby about **330 × 220** (RIVALS ~340 × 290). Floor levels: hub 0, dais +2 (2 steps), Duels −3 (3 steps down past the portal), Supply 0, Locker +1, Range yard −2.

### Areas
| Area | Size (w × l × ceiling) | Door | From spawn (16 studs/s) |
|---|---|---|---|
| **Main area: the Concourse** | faceted octagon, 92 across; walls 26, rising to a stepped lantern 42 over the dais | 4 wing doors on the axes | — |
| **Duels** | 84 × 100 × 34, faceted 3-face end (apse) | portal 22 wide × 18 high × 10 deep, then 3 steps down | door 46 (2.9 s), first bay 80 (5 s), farthest bay ≈148 (9.3 s) |
| **Supply** (Shop + Season Pass) | 64 × 56 × 24 | 20 × 16 × 8 | door 46 (2.9 s), counter ~78 (4.9 s) |
| **Locker** | 56 × 48 × 22 | 18 × 16 × 8 | door 46 (2.9 s), terminal ~74 (4.6 s) |
| **Range** | window 36 × 14 in the hub's W face + gate; yard ~110 × 70 outside | gate 14 × 14 | window 46 (2.9 s), gate 50 (3.1 s) |

## 3. Each area's look
One accent per room (sign, small lamps, floor cues only). Structure everywhere: light grey walls `#B9BAB7`, slate wainscot, charcoal base and trim, gunmetal; faint textures (±4%), matte; white lamp light. Team orange / blue only on the pads.

### 3.1 Main area: the Concourse (build first)
- **Shape:** an octagon of faceted wall bays. Each face: battered slate wainscot (0.5 proud at the foot), a sloped belt ledge at 9, light grey upper wall with a modelled panel grid, a facet crown at 26 into a dark coffered ring ceiling. Piers with flared feet and heads at the 8 corners carry the ring beam and the lamps.
- **Landmark (pending Q1):** spawn on a **stepped octagonal dais** (22 across, 2 steps) under a **faceted lantern skylight** (stepped octagonal drum, 42 up) that drops a daylight pool on the dais: the hub's "sun well", our namesake, ours not theirs. A gold line ring round the dais; one gold lead runs out the E door into Duels.
- **First frame from spawn:** E portal centred, DUELS sign on top (solid letters, 24 wide, 22 up, tilted 12° down), the lit bays of Duels beyond, the **Gauntlet trophy** lit at the far end as the destination. NE and SE leaderboards at the edges of the frame.
- **Diagonals:** NE leaderboard (wins), SE leaderboard (streaks), SW season / news board, **NW social niche**: a lowered bench bay with a show plinth (a lit stand-on block, 1 step, for emotes and skins) and a featured-skin board behind it.
- **Doors:** each a different deep frame (compress-and-release): Duels a stepped portal with a lintel sign; Supply a counter-height shutter frame with a rolled-up faceted shutter (fully open, nothing half-hidden); Locker a gallery arch with a glass case either side; Range a wide window with a gate beside it.
- **Life:** 4 live SurfaceGui boards, the lantern's light shaft with faint dust (1 emitter), a slow 6-blade faceted fan in the lantern (`LobbySpin`).
- **Lights:** the lantern (sun = key), 8 pier spotlights pointing down (pools), 2 door pools per door. About 14.

### 3.2 Duels (second; layout pending Q3)
- **Horseshoe of bays:** 8 equal pads in **framed bays round the hall in mode order**, read clockwise from the door: north wall 1v1, 1v1, 1v1; apse 2v2, 2v2; south wall 3v3, 3v3, 4v4. Everyone waiting faces the middle, so they are on show to the whole hall.
- **Bay:** opening 26 wide × 18 high × 18 deep, lined as one piece; pad = floor flange → tray → light channel → deck → clamps → cable duct; two team plates (orange, blue) with one pip per player; footlights match the plate colour. Mode board over the opening (SurfaceGui: mode in big letters, "x / N queued", lit by a hood lamp). A pier with a vertical lamp between bays (R8).
- **Middle:** a low faceted **match-board island** (four-sided SurfaceGui kiosk, 10 high) ringed by a sitting kerb: the waiting spot that's not a pad.
- **End:** the apse's centre face holds the **Gauntlet trophy** on a plinth at 16-30 up, under a gold-lit coffer: the end of the spawn sightline. No vault door (rejected).
- **Ceiling:** dark coffers, one lamp per coffer; the hall is the dark, cool room, the bays are the bright stages.
- Accent: gold (it continues the hub's lead line). Hooks: 8 × `LobbyQueue` with `Mode` `1v1` / `2v2` / `3v3`; the 4v4 pad is tagged with `Mode` = `4v4` only after the mode exists (parked in Bugs & Ideas; until then it gets no tag or opens the menu with no preset).

### 3.3 Locker (third)
- Reuses the approved Sunwell **Locker gallery** idea: in-wall gun displays behind glass, a Vandal turning over a lit turntable, the `LobbyLocker` terminal at the end wall. New room shell to fit the octagon's S door. Accent violet `#8E6CFF` (matches the Locker UI's violet wash).

### 3.4 Supply: Shop + Season Pass (fourth)
- One room, two bays: the **Shop counter** (left, `LobbyShop`) with featured-item boards, the **Season Pass wall** (right, `LobbyBattlePass`) with a big tier board. Accent coral `#FF6B4A`. Real guns on pale backs in the bays (Sunwell's idea, kept).

### 3.5 Range (fifth; pending Q4)
- A **window** in the hub's W face onto the real range yard (lanes, targets, a faceted mesa with a mast as its landmark) and a **gate** beside it (`LobbyRangeEntrance`; the existing teleport takes you in). What you see through the glass is where you go. Accent lime `#B4E04A`.

## 4. Reuse
| Keep | Rebuild |
|---|---|
| The palette, faint textures (`tools/textures/make_sunwell_textures.py`), lighting rules | The hub shell (new octagon) |
| Blender helpers `tools/blender/sunwell_p1/sw_core.py` (`wall_seg`, `cham_rect`, `cut_rect`, `taper_y`, `ring_prism`, `u_frame`, `add_text`), `sw_doors.py` (`sconce`, `display`), `S.grp` standalone pieces | Duels (new room shape, new bay) |
| Pad construction (flange, tray, deck, clamps, pips) and the board case kit | Supply room, Range window and yard |
| The Locker gallery idea and its display cases | Signs (new letters per wing) |
| The pipeline: Blender MCP → `sw_export.run()` → Open Cloud → Build module; collision rules | — |
| V3 (live, rollback) and Sunwell (fallback) stay as they are until the swap | — |

New Blender module `tools/blender/lobby_v4/` (imports the Sunwell helpers), blend `art-source/lobby/LobbyV4.blend`, exports `art-source/lobby/Exports/V4_<Area>.fbx`, Studio staging `Workspace.LobbyV4Staging` 1,500 studs west of V3 (checked clear first).

## 5. Budgets (this must run on phones)
| Area | Instances | Triangles | Lights (shadowed) | SurfaceGuis | Emitters | Unique meshes |
|---|---|---|---|---|---|---|
| Concourse | 900 | 70k | 14 (2) | 6 | 1 | 40 |
| Duels | 1,000 | 70k | 18 (2) | 10 | 1 | 30 |
| Locker | 350 | 30k | 8 (1) | 2 | 0 | 15 |
| Supply | 450 | 35k | 8 (1) | 6 | 0 | 20 |
| Range window + yard | 500 | 35k | 8 (0) | 4 | 1 | 15 |
| **Total** | **≤ 3,200** | **≤ 240k** | **≤ 56 (≤ 6)** | **≤ 28** | **≤ 3** | **≤ 120** |
RIVALS' hub is about 5,700 instances. Colliders and camera blockers count in these numbers. Identical pieces share one mesh (bays, piers, lamps, coffers, wall bays). Neon and small parts CastShadow off. Category folders per area: `Shell`, `Trim`, `Fixtures`, `Boards`, `Props`, `Colliders`, `Lights`, `Hooks`.

## 6. Phase order
1. **Concourse:** blockout + walk test → captures (spawn eye, high oblique) → full build → geometry checks → score (blind median ≥ 8.5, own 9) → fix.
2. **Duels**, same steps, plus every pad prompt checked in a play-test.
3. **Locker**, 4. **Supply**, 5. **Range window + yard**.
6. Whole-lobby pass: camera blockers from max zoom, streaming check, audit, `Lobby V4 Build.md` with the test list and the swap / rollback steps.

**Before phase 3 starts: save the Lobby place** (Sunwell is built but not saved).

## 7. Concept images (ChatGPT): paste this
Save the images to `vault/02 Art/References/lobby/v4/concepts/` with the names given. Main area and Duels first.

> I'm designing the lobby for my Roblox competitive shooter (third-person social hub, players are blocky R15 Roblox avatars about 5.5 studs tall). Everything must be original: no logos, signs, art or layouts from RIVALS, Valorant or any other game.
>
> **Style for every image:** stylised Roblox game environment, a clean modern tactical facility, chunky and readable like a top Roblox shooter, with the detail level of a Valorant map. Forms are **faceted**: no round curves or spheres (any curve is built from flat angled plates), no blunt square ends (every end is chamfered, tapered or carved), soft flat chamfers, never bevelled "pillow" boxes. Walls are **light grey `#B9BAB7`** with a **slate battered wainscot**, **charcoal** base and trim, **gunmetal** fixtures; matte surfaces with very faint painted variation, no photoreal textures. **White lamp light** from real fixtures (hooded spotlights, wall lamps with cages) making soft pools; cool shade between. Colour is used sparingly: **gold `#FFC83D` only on signs, small lamps and floor lines**. Signs are solid chunky letters on a backing plate (no neon tubes, no icons). Screens are flat bright UI panels in dark cases. **Avoid:** blue-teal steel, neon everywhere, glitch effects, brass, wood, amber light, sepia, pipes, hand wheels, holograms, rounded "AI" shapes, clutter.
>
> **1. `main_hero.png` (16:9):** the view from the spawn at eye height in the main hall: an **octagonal hall about 90 studs across**, walls 26 high with a dark coffered ring ceiling, and in the centre above you a **stepped faceted octagonal skylight lantern** dropping a pool of daylight onto a 2-step octagonal dais you stand on, with a gold line ringing it. Straight ahead, a deep stepped **portal** (22 wide, 18 high) with a big solid-letter **DUELS** sign above it; through it a long darker hall with lit bays and, far at the end, a **chunky faceted gauntlet-fist trophy** lit gold on a plinth. Front-left and front-right on the angled walls: two large leaderboard screens in dark cases. A few R15 avatars for scale.
>
> **2. `main_overhead.png` (16:9):** the same hall from a high three-quarter angle: the octagon with four doorways on the main axes (Duels ahead, a Shop doorway with a fully rolled-up faceted shutter, a Locker arch with glass cases either side, and a wide window onto an outdoor shooting range), boards and a bench niche with a small show stage on the four angled walls, piers at the corners carrying the lamps.
>
> **3. `duels_hero.png` (16:9):** the Duels hall seen from just inside its portal: **84 wide, 100 long, 34 high**, three steps down into it, a **faceted three-sided far end** with the gold-lit gauntlet trophy high in the middle. Round the walls, **eight identical framed bays** (26 wide, 18 high, 18 deep) each holding a queue pad: a layered pad (floor flange, tray, light channel, deck, clamps) with two team plates, **orange** and **blue**, small pips for players; a lit screen above each bay showing the mode (1V1, 2V2, 3V3, 4V4). Piers with vertical lamps between the bays. In the middle of the floor a low faceted four-sided screen kiosk with a sitting kerb. Dark coffered ceiling; the bays are the brightest, warmest things. Avatars waiting on two pads, others walking.
>
> **4. `duels_bay.png` (4:3):** a close-up of one bay and its pad at an angle: the bay's lined frame (one piece, chamfered), the layered pad build, the team plates with player pips, footlights matching the plate colours, the mode screen in its case with a hooded lamp over it, a cable duct running into the wall through a flange.
>
> If you can't save files, show them here and I'll download them.

## 8. Decisions (interview, one round, owner 2026-11-16)
| Question | Owner's answer |
|---|---|
| Q1 Landmark | **Lantern + Duels trophy**: spawn on a stepped octagonal dais under a faceted skylight lantern; the gauntlet trophy high at the far end of Duels |
| Q2 Hub shape | **Faceted octagon**, 92 across, doors on the axes, boards and the seating niche on the diagonals |
| Q3 Duels | **Horseshoe of bays**: 8 equal pads in mode order, match-board island in the middle |
| Q4 Range | **Window + yard by the hub**, gate beside it (existing teleport) |

Defaults the owner can still change at approval: Season Pass shares the Supply room as its own bay; wing accents gold (hub, Duels), violet (Locker), coral (Supply), lime (Range); 8 pads: 1v1 ×3, 2v2 ×2, 3v3 ×2, 4v4 ×1.

**How to build (owner, 2026-11-16):** map and lobby assets are modelled **only in the live Blender MCP instance on port 9934** (never background Blender), assembled in Roblox Studio, **in sections with a review after each**.

## 9. Parked
- A `4v4` queue mode for the 4v4 pad (code; goes to Bugs & Ideas, not this job).
