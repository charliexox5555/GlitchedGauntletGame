# Lobby V4 Build (2026-11-16)

**Status:** the Concourse (main area), Duels, Locker and Shop are built in `Workspace.LobbyV4Staging` of the Lobby place, 1,500 studs west of V3. The Range is **not built** (owner: "it hasn't been built and won't be yet"); its doorway is a sealed door with the RANGE sign. **V3 stays live**; V4 is active in Studio only through `use("V4")`. Blind review median **6.6** after two rounds (target 8.5): see the table below. **Nothing is saved:** the owner saves the Lobby place.

Plan: [Lobby V4 Plan](Lobby%20V4%20Plan.md). Theme: [Lobby V4 Theme](Lobby%20V4%20Theme.md) (owner's switch to the RIVALS look and feel). Study: [Maps and Lobby → What makes it work](../03%20Research/Rivals%20Reference/Maps%20and%20Lobby.md). Rules followed: `gauntlet-build-style`, [Sunwell Build Rules Handoff](Sunwell%20Build%20Rules%20Handoff.md). LihFolk: *Lobby and Hub Design*, *Level Design Principles - Flow Sightlines and Landmarks*, *Art Budgets - Triangles Draw Calls Memory*.

## Captures
Studio (`References/lobby/v4/studio/`): `r2_01_spawn`, `r3_02_hub_oblique`, `r1_03_hub_reverse_range_door`, `r2_04_duels_enter`, `r2_05_duels_bays`, `r2_06_locker`, `r2_07_shop` (rN = the review round they come from). Blender review renders (`References/lobby/v4/build/`): `c01`-`c09` hub, `d01`-`d04` Duels, `l01`-`l02` Locker, `s01`-`s02` Shop.

## What was built
| Area | What | Hooks |
|---|---|---|
| **Concourse** | Faceted octagon, 92 across, walls 34: plinth, battered wainscot, light belt ledge, big cut-corner panels with a rail, stepped crown. 8 corner piers with white bar lamps and down-lights, 8 radial beams, coffer ring, a lantern drum with frosted clerestory panels, a skylight and a slow fan. Two-step dais with a gold ring and **GG**; lighter lanes with two gold lines and stencils to each door. Doors: DUELS stepped portal (26 wide), SHOP roll-shutter portal, LOCKER gallery arch with display cases, RANGE sealed door. Diagonals: two leaderboards, a news board with a crate stack, a social nook (two benches, a show stage, the featured board). | Spawn on the dais |
| **Duels** | Landing at hub level with three steps down and parapets (the overlook), the mouth continuing the hub portal's lining. 84 x 96 hall + a three-face apse. **8 equal bays in mode order** (left 1v1 x3, apse 2v2 x2, right 3v3 x2 and 4v4 by the door), each a stepped frame with a lined recess, a layered pad (flange, tray, team plates with light channels, A / B letters, one pip per player, clamps, cable duct), team footlights, a back-wall queue board, a big mode sign. Piers with bar lamps between bays, coffered ceiling with light panels, a screen kiosk island with a sitting kerb, **the gauntlet trophy** (a faceted gold fist, turning) under THE GAUNTLET sign at the end of the spawn sightline. | 7 `LobbyQueue` (1v1, 2v2, 3v3); the 4v4 bay is untagged until a `4v4` mode exists (Bugs & Ideas) |
| **Locker** | 52 x 48 x 28 room: six lit gun cabinets (SIDEARMS, RIFLES, SNIPERS, SMGS, SHOTGUNS, HEAVY: 12 real guns), the LOADOUT station (stage, board, sign, console), a hero Vandal turning over a violet plinth. | `LobbyLocker` on the console |
| **Shop** | 54 x 52 x 28 room: the SUPPLY counter with the featured board, the **SEASON PASS** wall (board, sign, podium, terminal), three skin cabinets (SKINS, BUNDLES, NEW), a crate group. | `LobbyShop` on the counter, `LobbyBattlePass` on the terminal |

**Numbers:** 2,942 instances in Studio (budget 3,200), about 83k triangles exported (Concourse 24k, Duels 29k, Locker 16k, Shop 14k), 118 lights (no shadows; bar lamps throw short pools), 19 SurfaceGui screens, 19 real guns, 746 colliders (hand boxes inside the visible solids; glass and cases use invisible keep-outs).

## Pipeline (live Blender MCP only)
- Blender: the owner's V4 instance. It listened on **port 9999**, not 9934 as first said. Code goes through `tools/blender/lobby_v4/send.py --port 9999 --pid <pid>`. File `art-source/lobby/LobbyV4.blend`.
- Builders: `tools/blender/lobby_v4/` (`v4_core` theme and kit: signs, bar lamps, boards, crates, wall runs, piers, rooms, cabinets; `v4_hub`, `v4_duels`, `v4_wings`, `v4_run`, `v4_export`), on top of `sw_core` / `lv3_core`.
- Run: `v4_run.build_all()`, `v4_run.audit()`, `v4_export.run()`, `v4_run.save()`. Then upload: `python tools/opencloud/upload_models.py --lobby --group 11116787 V4_Concourse V4_Duels V4_Locker V4_Shop` (always all four) and `python tools/studio/lobby_v4/upload_data.py --group 11116787` (asset `96690672063658`).
- Studio (Lobby place, Edit):
  1. `InsertService:LoadAsset(96690672063658)`;
  2. move `V4Data` to ServerStorage;
  3. `require(V4Data.Build:Clone())`, then `.rebuild()`, `.spawn(0, 0, 2)` and `.use("V4")`.
- Builder: `tools/studio/lobby_v4/Build_V4.luau`. Lighting for V4 (tuned in Studio):
  - Ambient 112,114,120; OutdoorAmbient 140,143,150; Brightness 2.8; exposure 0;
  - Bloom 0.55 / 18 / 1.4.

## Checks
- **Geometry audit** (`lv3_audit` on the V4 root): 0 floating, 0 leaks, 0 zero-face meshes. 17 coplanar pairs are left, all hidden: bottom faces resting on the floor slab, beam ends inside the crown, and same-material faces inside the trophy.
- **Fixed after the owner's notes:**
  - **"Too round corners":** bevel widths are down about 3×. Lamps, caps, boards and crates use small flat cuts. Wall panels use asymmetric cut corners instead of even chamfers.
  - **Overlaps** found by measuring:
    - the DUELS / RANGE frames, two signs, the crates and the benches crossed the corner piers;
    - bay frames touched their piers;
    - the Duels ceiling box doubled the apse slab;
    - the window sill was flush with its frame;
    - beam bottoms were flush with the lantern ring;
    - the landing plate was doubled;
    - the Range gate was too narrow for its rings and its geometry inverted;
    - the case colliders were opaque inside the glass;
    - a lime strip on the shooting line floated.
- **Prompt play-test** (Studio play, client): 10 prompts bind (Queue 1V1 ×3, 2V2 ×2, 3V3 ×2, Open Locker, Open Shop, Battle Pass), and the player spawns on the V4 dais. Output showed no V4 errors (an existing asset-type warning only).

## Blind review (three blind reviewers per round: art director, level designer, lighting artist; weighted rubric W1-W6 / 12)
| Round | Scores | Median | What changed after it |
|---|---|---|---|
| 1 | 6.8, 6.6, 6.2 | **6.6** | Floor lines painted (not neon), lamp light pools on every bar lamp, bays 12 deep with a fill light (the queue on show), tunnel fills, a frosted skylight (the sun blotch), a lowered kiosk (the trophy reads from the door), gun rails in the cases, the half-hidden cases by the Locker door, the unlabeled stage and the Range lane removed, the fist without studs, Shop pink instead of coral |
| 2 | 6.6, 6.2, 6.8 | **6.6** | Glitch fixes only (stop rule: the median held): the Shop door's round roll became an angled housing, the floating gold ring over the trophy removed, the room sign now SHOP (it said SUPPLY), a smaller Season Pass sign, the floor ring painted |

**Self-check against the rules:** no round shapes left that I know of; no floating parts (audit); no overlaps or flush faces left except hidden ones; one accent per room; team colours only on pads; every gameplay object has a hook and a prompt.

**Honest grade:** about **6.6 / 10** on the blind median, under the 8.5 target. The panels agree on what holds it back. That is the next round, with the owner:
1. **Lighting depth:** lamps that really pool (SurfaceLights on the bar lamps, a lower ambient), ceiling lamp cards with housings, and darker Locker / Shop walls (they read lighter than the hub).
2. **Dressing:** the walls between fixtures are bare. Add vents, plaques, kick plates, crate groups and wall breaks; dress the bay interiors (side lamps, back frames); give the Shop centre a featured plinth.
3. **The sign silhouette:** two reviewers called the `>> WORD <<` plate the closest thing to a RIVALS copy. Option: our own frame shape (one slanted end, our gold bar) while keeping the glow.

## Still weak
- Screens are placeholders: the queue, kiosk and featured boards use the old Sunwell layouts, and the live data comes from the lobby UI code later.
- The Shop centre is empty. A featured-skin plinth would carry it.
- Lighting reads flat (all three reviewers, both rounds), and the walls between fixtures are bare. See the blind review.
- The farthest pad is about 10.5 s from spawn (plan target 9.5 s; RIVALS is 15 s).

## Test list (owner)
1. Save the Lobby place. Sunwell and V4 are both unsaved.
2. Play in Studio: spawn on the dais and walk to each door. Check that the DUELS sign and the trophy sit on one line.
3. Duels:
   - stand in each bay;
   - check that the prompt says the right mode;
   - check the A / B plates and pips;
   - jump on the kerb and the landing parapets.
4. Locker: guns in every cabinet, LOADOUT prompt, the hero gun turning.
5. Shop: SUPPLY counter prompt, Season Pass terminal prompt.
6. Zoom the camera out everywhere and look for see-through walls.

## Parked questions
- A `4v4` queue mode for the 4v4 bay (Bugs & Ideas).
- The Range: what it is and where it goes (Bugs & Ideas). The sealed door is the placeholder.
- Real content for the boards (lobby UI lane).

## Swap steps (owner approves)
1. In Studio: `require(game.ServerStorage.V4Data.Build:Clone()).use("V4")`. This turns the V4 spawn on, the V3 and Sunwell spawns off, and applies the V4 lighting. Save the place.
2. Motion (the fan and the trophy turning, hero guns) uses `LobbySpin`, which the V3 `Workspace.Lobby.Ambience` client script drives. Keep that script, or move it out of `Workspace.Lobby`, before deleting V3.
3. Once V4 is approved for good: move `Workspace.Lobby` (V3) and `Workspace.SunwellStaging` to `ServerStorage.Archive`, then save and publish.

**Rollback:** `.use("V3")` puts the V3 spawn and lighting back.
