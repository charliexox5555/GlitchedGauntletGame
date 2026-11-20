# Lobby V4 Build (2026-11-16)

**2026-11-17 update.** V4 was the enabled spawn in the open Lobby place. V3 and Sunwell spawns were disabled. The owner chose V4 for release after cleanup, with Lobby and Match staying separate for now. Published activation remains unverified. See the [Developer Handoff](../04%20Tech/Developer%20Handoff.md).

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

**Numbers (after the detail and life rounds):** 3,817 instances in Studio (budget raised to 4,000; RIVALS' hub is about 5,700), about 195k triangles (budget 240k), 151 lights with no shadows (each lamp, sign and pad throws its own light; RIVALS uses about 130), 38 SurfaceGui screens, 23 real guns, about 950 colliders (hand boxes inside the visible solids; glass and cases use invisible keep-outs). **Phone check still to do** in a real phone test (MicroProfiler).

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

## Detail and life rounds (owner 2026-11-16: "more character, less simple shapes and pill looks; connection parts; vents, warning signs, lights and accents pull RIVALS together")
| Round | Added or changed |
|---|---|
| Character | Bar lamps rebuilt as caged faceted lamps (bolted plate, trapezoid housing, lens behind steel bars, angled caps, conduit up into a junction box, a down-light pool). Pier collars at the belt line and steel gussets under every beam root. Conduit runs with saddle clamps and flanges into the piers. Boards on bolted ears with a power feed into a wall junction box. Tunnel ribs with light strips inside every doorway. Gold hazard thresholds at every bay mouth. Housed ceiling lamps with grilles (no floating light cards). Our own sign silhouette: a leaning plate, a gold slash pair and a gold tab. |
| The little things | Wall vents (faceted louvre frames, angled slats, bolts) in mixed sizes. Printed safety plaques in our words (WARNING / CAUTION / NOTICE: "WHEN LAMPS FLASH, MATCH STARTS", "STAND ON PAD TO QUEUE", "RANGE CLOSED, OPENS SOON"). Alarm beacons in cages. A hung octagonal truss ring with eight yoke-mounted stage spots on the dais, kept under the lantern ring so it never crosses a door sign. |
| Life | Four showcase stands with real guns turning round the dais (our answer to RIVALS' hologram stands). An arcade cabinet ("TARGET RUN"). Hard-case and crate groups. A Shop feature plinth. Hero guns on turntables (they read as floating before). |
| Light | Env diffuse for form gradients, ambient under outdoor (LihFolk), a neutral grade (the sky's blue was tinting the rooms), team-coloured light off every pad, signs that throw their room's accent, lighter bay linings, lighter ceilings so the coffers read, bloom 0.6/24/1.4, light distance haze. |

**Checks each round:** the geometry audit (0 floating, 0 leaks; the visible pairs left are clamp and plate backs against wall planes), a scripted sightline check from the spawn, the hub corners, the Duels landing and middle and the room doors to every sign and board (no blockers), a route check along every lane (clear), and close-up captures. Two "white outline" sightings in captures were Studio's mouse-hover highlight (rays hit only the wall there). The bay boards are partly hidden by the near door jamb at oblique angles, which is perspective, not a glitch.

**Compared with RIVALS** (three blind reviewers rate both lobbies on the same rubric):
| Round | V4 weighted | RIVALS weighted | V4 as % of RIVALS |
|---|---|---|---|
| After the character pass | 6.9, 7.3, 6.7 | 7.6, 7.9, 8.1 | 91%, 92%, 83% |
| After the life pass (showcases, arcade, props, team light, lower ambient) | 6.8, 7.3, 7.1 | 7.8, 7.3, 7.3 | 88%, 99%, 97% |
| After round 5 (dais collar, drop stand, grates, hero spots, tighter accents) | 6.6, 7.3, 6.9 | 7.8, 7.7, 7.8 | 85%, 94%, 88% (median **88%**) |

What all three still say holds V4 under RIVALS: **life that moves or rewards a look** (RIVALS' spinning hologram pickups and sparkles; ours turn slowly and are dim), **light pools and hero light shapes** (beam cones from the spots), **prop storytelling** (rooms read as the same shell recoloured), the **sealed Range door** in a prime spot, and **placeholder boards** filling wall space. Fixed after the last panel: solid floor words (the stencil breaks read as glitches), white STAND HERE text (gold broke the violet and pink rooms), the Locker room sign now says LOCKER (it said LOADOUT, a mismatch with the hub).

**Next round (proposed):** Beam light cones from the truss spots onto the dais and showcases, sparkle emitters and a slow bob on the showcase guns, a SurfaceLight on every wall tube, a dressed vault hall end in Duels, one prop story per room (Locker: a gunsmith bench; Shop: a crate being unpacked), live board content from the lobby UI lane, and a phone performance test.

## Owner round, night of 2026-11-16 (pads, neon, consoles, signs, Locker)
The owner's notes:
- tablet-looking terminals that overlap;
- too much neon;
- overlapping text on the STAND HERE pads and the plaques;
- too many caution signs (none needed in the pads);
- boring queue pads: "more like the RIVALS queue area, with bigger pads and room to queue, and big screens that show the players";
- the Locker needs shelves and decor;
- every sign is the same: each should have its own character, without copying.

| Note | Done |
|---|---|
| Queue pads | **Open stage pads** in front of a shallow recess, like RIVALS' open pads beside the walkway but our build. Each pad: 19 x 12 deck on a stepped base with a steel rim and a hazard-striped front step; two team plates (one thin lit outline, painted team band, A/B letter, one chevron slot marker per player); a VS pylon between them; two waist-high lamp bollards. Bays respaced (78 / 106 / 134) so the bigger pads clear the piers and the apse pads. |
| Big screens | Each recess holds a **14 x 10 player screen** (new `lineup` layout): mode and "0 / N QUEUED" across the top, TEAM A and TEAM B columns, one card per player slot (avatar box, name line), "STAND ON THE PAD TO QUEUE". Static until the lobby UI code fills it. |
| Neon | Painted accent twins (`V_Violet`, `V_Pink`, `V_Lime`, `V_TeamA`, `V_TeamB`) replace glow on cases, showcases, stages, plinths, consoles and the drop stand. Glow stays on signs, lamps, pad outlines and the GG. |
| Consoles | Rebuilt as **terminal kiosks**: faceted column, a vertical screen in a bezel (SurfaceGui), a visor, a key shelf, one painted band. No slanted neon slab. |
| Text overlap | STAND HERE removed. Plaques print with text scaled to fit, the rule sits under the header, one line each. |
| Caution signs | The plaque in every pad removed. The hub keeps one notice by the Locker and one warning by the Range. Duels keeps one warning. |
| Signs | **Each sign has its own plate shape and icon**, breaking its outline on a dark backing: DUELS a blade-shaped badge with crossed steel blades (gold guards); SHOP a price tag with a sparkle; LOCKER a leaning plate with a reticle; RANGE an arrow with a bullseye and dart; THE GAUNTLET a ribbon with a crown; SEASON PASS a ribbon with a star. |
| Locker | Two **gun tables** (faceted top, dark mat, A-frame legs, a lower shelf with ammo boxes, three guns on stands each) and two **posters** by the door ("KNOW YOUR LOADOUT", "EVERY GUN HAS A STORY"). The loadout board now shows. |

**Checks:** geometry audit 0 floating, 0 leaks; 0 missing meshes; 29 real guns placed; play-test: all 10 prompts bind, spawn on the dais. 4,052 instances. **The exporter now writes FBX and JSON through temp files with retries**, after Windows file locks broke two exports. Captures: `References/lobby/v4/studio/`.

## Owner round 3 (2026-11-16): step pads, NPCs, Shop stages, bundles and effects, lighting, flat surfaces
The owner's asks: no "E to open" in the Locker, step on a pad and it opens; an NPC that looks good; a Shop like RIVALS' Market instead of a boring room; the hub stands should show effects and bundles, not only guns; visual effects; parts of the lobby too dark; the "blocky" textures.

| Ask | Done |
|---|---|
| Step pads | `src/lobby/client/Controllers/WorldPrompts.luau`: a tagged part with `Trigger = "Step"` gets no prompt; walking onto it opens its menu once (re-arms on leaving; a 10 Hz client check; client UI only, no remote). Locker pad (in front of the loadout board), Shop pad (in front of the counter), Season Pass pad (in front of its stage). The queue pads keep their prompts. Play-tested: stepping on the Locker pad opened the Locker. |
| NPCs | Real R15 rigs built by `Build_V4.npcs()` from `LobbyNPCSpot` anchors: an ARMORER in the Locker beside the pad, a SHOPKEEPER at the counter end, in uniform colours with a vest, strap and cap, a name tag in Fredoka One, the root anchored. `src/lobby/client/Controllers/LobbyNpcs.luau` plays a looping idle on anything tagged `LobbyNPC` (both playing in the test). |
| Shop | RIVALS' Market logic in our build: two **show stages** set into the long walls (`v4_core.holobay`: stepped frame, lined recess, raised stage with a lit lip, slash backdrop, an inner truss with three spot cans and light cones, a tab sign). FEATURED: the bundle gun turning on a pedestal, hard cases, a price card ("PHANTOM BUNDLE, 1,200 COINS"). SEASON PASS: a gold crest with "1" on a stepped podium. The old wall cases, the board and the console are gone. |
| Hub stands | `bundle_stand` (a gift box with straps and a bow, a gold star medal floating and turning above it, sparkles, a light cone) and `effect_stand` (a cluster of faceted gold shards with rising embers, a light cone). One gun showcase stays, with sparkles; the supply drop gets sparkles. |
| Effects | `Build_V4.fx()` from `LobbyFX` anchors: sparkle, embers and dust ParticleEmitters and soft Beam light cones, built-in Roblox textures only. 20 effects. |
| Lighting | Ambient 74 / outdoor 112 (from 62 / 100), room ceiling pools 1.5 (from 1.1). A point fill was tried and washed the walls flat, so it was removed. |
| Textures | The SW_* painted MaterialVariants are off every V4 material (flat SmoothPlastic). The two floor plate tones are closer. |

**Checks:** 0 floating, 0 leaks; 0 missing meshes; 2 NPCs; 20 effects; 23 guns; the play-test opened the Locker from its pad; the only prompts left are the 7 queue pads; no new Output errors. About 4,400 instances.

## Structure pass (2026-11-16)
The owner: "it still needs improvements on the structure of the whole thing". Reviewers had called the Duels hall a flat box and the rooms the same shell.

| Where | Done |
|---|---|
| Duels | A **raised nave vault** over the middle of the hall: the ceiling slab opens 32 wide along the nave, with clerestory walls of frosted panels on steel mullions, angled plates up to a flat top 10 higher (faceted, no curves), gable ends, section ribs on steel shoes every 12, housed lamps along the top. The side aisles keep their lamps. |
| Locker, Shop | The same vault along each room (7 higher), lamps either side of it: the rooms stop reading as boxes. |
| Hub | **Upper galleries** on the four diagonal walls: steel decks with grate fields and a trim edge, knee braces down to wall shoes, posts and two pipe rails, a lit strip and down-lights under the deck washing the boards below. Layered depth like RIVALS' hub ring, decorative (no access). |

`v4_core.slab_with_hole`, `nave_vault`, `gallery`. **Checks:** 0 floating, 0 leaks, the seams between vault and slab stepped proud (no flush faces); 0 missing; all 27 screens have content (black screens in a capture taken straight after a rebuild are the SurfaceGui capture delay). About 4,650 instances, 204k triangles (budget 240k).

## Hub section pass (owner 2026-11-16, section by section, starting with the hub)
| Note | Done |
|---|---|
| Overlaps (bar lamp 5 into gallery 3, vent 4 into the bench, others) | A new **clash audit** (`tools/blender/lobby_v4/v4_clash.py`): triangles of one piece cutting through another. Fixed: galleries now stop short of the piers (every bar lamp's feed was hitting them), braces and shoes sit on the wall panels, the SE vent moved off the bench, the truss ring moved outside the lantern ring, the fan's rod through the skylight is gone, the Shop shutter channels are gone, signs clear the new cornices, plaques clear the lit slots. What is left are intended seats (piers into walls, collars round piers, rods into the roof). |
| TVs should pop out like RIVALS' | `v4_core.tv`: a wall plate, two faceted arms, a thick case 3.2 out from the wall and tilted down at the room, a bezel, a glow strip, a light bar. Screens now follow the tilt (`sw_core.screen` records the normal's z; `Build_V4.screens` uses it). |
| Hologram stands like RIVALS' | `v4_core.holo_stand`: a stepped emitter with a glowing lens, a translucent ring on the floor, a soft projection cone widening upward, the item as a glowing silhouette with an offset ghost copy, turning, sparkles. Placeholders: gift, badge, rifle, supply case. |
| Paths | `v4_core.path_lane`: an inlaid dark lane with steel edge rails, a lit slot in each rail, lit chevrons near the door, the word at the start; a lit ring round the dais where they begin. |
| Sunroof | The lantern rebuilt: clerestory drum with sills, eight sloped faceted roof plates with ribs, an upper drum with a frosted band, a frosted oculus, a hung light ring on rods (white underside, violet edge), a soft light shaft. The fan is gone. |
| Grand entrances | `v4_core.gatehouse`: a deep frame block standing out between the piers round each door: columns with chamfered fronts and a lit slot, a plinth, a head with a cornice and a lit soffit with downlights, glowing jamb strips, hazard thresholds beside the lane; the sign stands on the cornice. The Duels door is 23 x 20 now (was 26 x 22) to make room, and the Duels mouth follows. |
| Arcade | Removed. |
| Props (cases, crates) | Kept as placeholders for now (owner: later). Not copied from RIVALS: their file is untrusted and the rule is study, don't copy. |
| Colour theme | **Studio palette applied** (owner's codes): deep violet `#401C99`, violet `#6539D7`, lilac `#C5B7D9`, pale lilac `#E5DDEF`, off-white `#FFFDFE` (confirmed by the owner). Violet replaces gold as the lobby's glow (hub, Duels, Locker: signs, GG, collar, bay signs); lilac on paths, rails and holograms (as Neon `#9F8FC0`, since lighter Neon clips to white); pale lilac replaces gold on the screens. Kept: hazard stripes yellow/black (safety), the gold trophy, Shop pink and Range lime as room accents. `v4_core.THEME`. |

**Checks:** 0 floating, 0 leaks; clash audit clean for fixtures; 0 missing meshes; about 4,630 instances.

## Shop as a Market hallway, separate meshes, railings (owner 2026-11-16)
| Note | Done |
|---|---|
| Gallery railings not on the deck | Railing posts and rails now stand on the deck, inside its cut corners, each post on a base plate. |
| Every structure its own mesh | Walls, floors, ceilings, conduits, paths, hazard strips and ceiling lamps are their own pieces (`v4_core.grouped`), the gallery splits into Deck / Braces / Railing, the hub and Duels floors, ceilings and the Duels landing too. 178 → 308 pieces; each piece is a Model in Studio, and inside a piece each material is its own MeshPart. |
| Shop redesign (like RIVALS' Market) | The Shop is now a **hallway** 88 long x 26 wide x 30 high with a vault: two big show stages face each other (FEATURED south, SEASON PASS north, 30 wide x 16 deep), each with a **walk-in floor mark** (`v4_core.step_mark`: inlaid field, lit corner brackets in the stage colour, three pairs of footprints, a hazard strip with STEP IN) that opens its menu, no pad. The far end: the **BROKER**, a big R15 NPC (about 9.8 studs, scale 1.8) on a stepped plinth, a TV and the SHOP sign behind him. Pop-out TVs and vents by the entrance, piers with bar lamps, a lit path down the middle. Play-tested: FEATURED opened the Shop, SEASON PASS the Battle Pass. |
| Props from RIVALS | Copying between two Studio windows is not possible from here (each place is its own DataModel to the tools, no clipboard). The owner can paste them into `Workspace.LobbyV4Staging.PropsPlaceholder`; they are RIVALS' meshes, so placeholders only, replaced before publishing. |

**Checks:** 0 floating, 0 leaks; the Shop clash list is down to intended seats (piers into walls, frame legs into the floor, lamp housings into the ceiling); 0 missing; about 5,050 instances (the split adds Models).

## RIVALS props, a wider Market, lit stages (owner 2026-11-16)
Studied against the owner's paste of the RIVALS lobby (`Workspace.LobbyRivals`, read only, 0 scripts). Their Market hall is about as wide as ours now; what sells it is that both bays are **lit, full stages** (bright backdrop, curtains, glowing grid figures, spot cans) and one colour band runs down both walls. Their Ski Crate lies flat, like our cases.

| Note | Done |
|---|---|
| "Create a folder called Rivals Props and paste them into the world" | The owner's `Workspace.RivalsProps` (14 RIVALS props) moves to `ServerStorage.RivalsPropTemplates` the first time `Build_V4.props()` runs. Every crate and case spot in the builders is now a **`LobbyPropSpot` anchor** (`v4_core.prop_m`: `Kind` = template name, `Yaw`), and Studio drops a copy there, bottom on the floor, scripts and prompts stripped, in `LobbyV4Staging["Rivals Props"]`. 17 props: the hub stack (two weapon crates, a wooden crate across them, a barrel, an explosive barrel), the Duels and Locker case stacks, the two stage cases, four by the Broker. The Ski Crate stands on end in the owner's folder, so `PROP_LAY` lays it flat (shortest side up). **Placeholders: RIVALS' meshes, replaced before publishing.** Map in `v4_core.PROP_KIND`. |
| Hallway too narrow | 26 → **40 wide** (88 long, 30 high), stages 18 deep, the floor marks 24 x 8 with heel and ball footprints. |
| Shop "a bit rough" | Both stages are lit stages now: FEATURED has **folded coral curtains** (zigzag flat plates, no curves) on a steel rail, SEASON PASS a **lilac backdrop**; each has **two hologram figures** (`v4_core.holo_figure`: block bodies in a violet ForceField, so they shimmer like a grid, no bloom) on lit discs; stage light 2.4 → 3.2, the accent fill doubled. A **painted violet band** runs down both long walls between the piers. Hologram stands (gift, badge) by the entrance. |
| Separate pieces | The bay spot cans (`stage_spot`) and door collars (`mouth`) were merged into one loose mesh per material; now each is its own piece. |

**Checks:** 0 floating, 0 leaks, visible pairs 64 → 52; the Shop clash list is only the stage frames and the door collar seated into the wall at the opening edges; props checked against every collider (none intersect) and sit on the floor; play-tested: FEATURED opened the Shop and SEASON PASS the Battle Pass.

## The Market turns a corner (owner 2026-11-16: "Add the corner")
The far end wall of the hall is now a **wide arch** (24 high, about 24 clear) into **the Broker's room**, which runs north behind the hall: 32 wide x 84 long x 30 high (`LX0..LX1` = X1 + 8 .. X1 + 40, Y -24..60). Through the arch you see the room's back wall: the FEATURED TV under a **MARKET** ribbon sign. The lit path runs through the arch and **turns left** at an L corner piece (`PathCorner`: rails round the outside only, so no line crosses the path) up to the **BROKER**, who now stands at the far north end on his plinth (facing the way in), with his own TV and a BROKER badge sign behind him. Props in the room's corners (5 more, 22 in all), the violet band carried on, two extra ceiling lamps at the room's ends. Both sides of the arch are stepped collars (`mouth`), their linings meeting inside the 8-deep passage.

**Checks:** 0 floating, 0 leaks; clash list only the usual seats (conduit clamps, bands into the wainscot, stage frames and collars at opening edges). Play-tested: a character walks from the hall through the arch to the Broker; the Broker plays his idle. The extra SHOP sign over the arch was dropped (it ran into the end wall's cornice); the MARKET sign reads through the arch instead. Shop: 106 pieces, about 55k triangles.

## The Broker's exchange (owner 2026-11-16: "Add a feature")
The Broker's room is now an exchange: **four lit glass gun cabinets** down its long walls (`v4_core.niche`, the Locker's cabinet: DEALS with Vandal and Sheriff, RARE with Operator and Judge, NEW with Phantom and Spectre, VAULT with Odin and Bucky; real guns, own lights, violet accent strips), and a **bundle stand** (coral gift box, turning medal) and an **effect stand** (violet crystal shards, embers) flanking the end of the path in front of the Broker. The Broker's TV reads DAILY DEALS (the sign and his name tag already say BROKER). The violet wall band was taken out of this room: between the cabinets it was only stubs. Checks: 0 floating, 0 leaks, no new clashes; 30 guns placed, 0 missing; Shop 113 pieces, about 62k triangles.

Rebuilt and captured in Studio after the place restarted (`LobbyRivals` and the prop templates survived the restart).

## Still weak
- Screens are placeholders: the queue, kiosk and featured boards use the old Sunwell layouts, and the live data comes from the lobby UI code later.
- The props are RIVALS' meshes (placeholders). Our own crates, cases and barrels are still to model.
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

## Locker as a weapons room (owner 2026-11-16: "more oomph, like RIVALS' weapons area")
**Studied** (RIVALS lobby pasted in our place, read only; RIVALS file for the UI, read only): their weapons room is round, a red target ring on the floor, about 8 low display tables in a ring (`LooseWeaponDisplay` spots where the client lays your equipped guns), crates stacked round the walls, hanging tube lights, a pegboard gun wall, and an NPC (Nosniy) with a custom "Interact" prompt (16 studs). Talking opens `DialogPage`: a big portrait, a white speech bubble along the bottom, reply buttons stacked above it that appear 0.1 s apart (close = red); a reply's action key opens a page.

**Plan (owner picks: octagon ring, 8 guns one per class, Armorer with 3 replies):**
- Room: an octagon (rectangle + four diagonal walls) about 64 across, 32 high, door from the hub on the east. A faceted emblem ring inlaid in the floor (violet paints, crosshair ticks), a centre plinth with your knife turning over it.
- 8 display tables in a ring (Classic, Sheriff, Spectre, Judge, Vandal, Phantom, Operator, Odin), each a `LobbyGunDisplay` anchor (Gun, Mount, barrel and face directions, Scale): the client lays **your equipped skin** of that gun on it (`Shared/Locker.skinModel`, `Skin_<gun>` attributes), and swaps it when you equip.
- West wall: a pegboard gun wall with 9 more guns (also your skins), the LOCKER sign over it, the ARMORER (bigger) in front.
- Crates round the walls (RIVALS prop placeholders), two hanging tube lamps, vents and posters on the walls.
- No Locker pad: talk to the Armorer. Prompt "Talk" (12 studs) → `NpcTalk` page (Router, no blur): the camera eases onto him, a dark plate along the bottom with his name tab and typed-out words, slanted reply plates stacked at the right: OPEN MY LOCKER (opens the Locker), WHAT'S NEW? (one more line), GOODBYE. Dialog lines in `lobby/shared/NpcTalk`. Client only (opening a menu changes nothing on the server).

**Built (2026-11-16):**
- **Room** (`v4_wings.Locker`, `v4_core.oct_corner_walls` / `floor_emblem` / `display_table` / `gun_wall` / `hang_lamp` / `gun_display`; `room(inset=)` keeps the straight walls' trims inside the octagon): octagon 64 across, 32 high; emblem rings and crosshair ticks inlaid; knife plinth in the middle; 8 tables at radius 21 with name plates facing in (a **J** glyph was added to `sw_core` for JUDGE); pegboard (L-shaped hooks) with 9 guns under the LOCKER sign; the ARMORER at scale 1.6 on a step; 11 prop spots; two hanging tubes; vents and posters. 41 pieces, 33k triangles. Audit 0 floating, 0 leaks, visible pairs 71 → 60.
- **Your skins on display** (`client/Controllers/LobbyGunDisplays`): 18 `LobbyGunDisplay` spots (Gun, Mount Lay / Wall / Stand, barrel and face directions, Scale cap, Fill length, Spin). The client lays a copy of `Locker.skinModel(gun, Skin_<gun>)` (else the stock gun) there, oriented from the model's own shape and Muzzle (skin models point their barrels along X, stock guns along -Z), and swaps it when `Skin_<gun>` changes. Checked in play: all 18 placed with the test account's skins, lying on the tables and hanging on the board, the knife turning.
- **Talking** (`client/Controllers/NpcTalk`, `lobby/shared/NpcTalk`, `StarterGui.NpcTalk` from `tools/studio/BuildNpcTalk.luau`). Owner, mid-build: "resemble RIVALS more ... they go into this separate HUD", so it is its own screen: the world blurred behind a dark violet wash (a LobbyKit page), his **live 3D portrait** (a clone playing his idle in a ViewportFrame) bottom left fading out at the waist, an off-white slanted **speech plate** with big ink words typed out and a pointer at him, his name on a violet tab, **reply plates** stacked above its right end (violet; Goodbye red), keys 1-4 pick, Backspace / B close (the Router; Esc is Roblox's menu). The prompt is our own card (Style Custom): an off-white slanted plate with a dark key tile, ARMORER, "Talk". Checked in play with real keys: E opens, 2 goes to the next line, "Show me" opens the Locker, Backspace closes and the card comes back.
- The Locker step pad is gone; the bottom bar's LOCKER button still opens the Locker directly.
- The prompt card shows above the Armorer (owner checked in play, 2026-11-16; Studio's capture tool does not draw client-made billboards, so it is missing from the captures). Not checked yet: the talk screen's phone layout.

## Duels V5: RIVALS-style pads, sections, big TVs (owner 2026-11-16)
**Studied** (`LobbyRivals` paste, read only; RIVALS file `QueuePadVisuals`, read only): each pad is two 8 × 8 team squares sunk into a deck with a hazard divider, a white ring logo under a dark tinted floor, team outlines; two rings float over each square and turn opposite ways, light grey at 75 % see-through; **when a team has players its rings take the team colour and a glow rises**. Two dark 10 × 14 boards behind each pad, the mode tag above, a pier with a bar lamp between pads, a dark aisle with coloured edge lines and grates.

**Built (`v4_duels.pad`, `client/Controllers/LobbyPadFx`):**
- Hall 88 wide, straight to y 222 (was 158), the apse to 244. **Eight big pads** along the side walls, near to far: left 1v1, 1v1, 2v2, 2v2; right 3v3, 3v3, 4v4, 5v5 (4v4 / 5v5 have no queue yet). A **pier with a bar lamp between every pad**: one section each, a ceiling lamp over each.
- **Pad:** a deck 25 × 14.5 with a steel rim and a front step and hazard edge; two sunken **11 × 11 team wells** (A orange, B blue) under tinted see-through plates (`G_PadA` / `G_PadB`, SmoothPlastic 0.45: Roblox Glass glared and blurred the emblem), a lit octagon emblem on each well floor, a lit team outline, a hazard divider, a light post at each front corner.
- **Two tall TVs per pad** (10 × 14, portrait, one per team) with frames, hoods and a team glow bar, **blank** (dark glass `G_Screen`) until the pad UI is coded; each has a `LobbyPadBoard` anchor (Pad, Team, Mode, normal NX / NY) for it. The mode sign over them.
- **Highlight** (client, everyone sees it): per well two faceted rings (eight bars) hover and turn opposite ways, faint grey; when any player stands in the well they turn the team colour and spin faster, a **glow curtain** (four Beams up the well's edges) and a team light fade in (0.25 s). Anchors `LobbyPadSquare` (Pad, Team, Mode).
- **Queue (owner: "just have it queue the player auto"):** each live pad's `LobbyQueue` anchor is a step zone. Stepping onto a pad **starts a search for its mode**, stepping off **cancels it** (`WorldPrompts.stepQueue` → `QueueState.join / leave`, the Play menu's own `QueueRequest`; the server's QueueService still checks the rate, the mode, the party leader and the party size). Only a search the pad started is cancelled by stepping off; a party member who isn't the leader never cancels the party's search. Played: on pad 3 → searching 2v2, off → idle. The owner plans to merge lobby and match into one place later (like RIVALS); this pad logic carries over.
- Aisle: a dark lane with a violet line and a lilac line, grates either side, the island mid hall, the trophy at the end; crates and vents on the apse faces. A **5** glyph added to the stencil font.

**Checks:** 0 floating, 0 leaks, visible pairs 66 (TV backs seated into the wall trims); played: 16 wells built, standing on 1v1's A well turned its rings orange with the glow and opened the Queue menu for 1v1.

### Duels round 2 (owner 2026-11-16: "glitched pads ... area is kind of boring ... don't need the centre piece ... paths and arrows more like RIVALS, animated and fun")
- **Pad glass fixed:** the see-through plastic plates caught jagged shadow steps and hid the emblem. They are now see-through **Neon** (`G_PadA` / `G_PadB`, 0.78): Neon takes no shadows, glows softly, and the lit emblem shows through.
- **Island removed.** The aisle runs straight from the landing to the trophy plinth.
- **A four-sided screen cube** hangs over the middle of the hall (`v4_duels.jumbotron`: faceted dark body, a blank screen per face with `LobbyHallBoard` anchors for the UI later, trim caps, a violet light ring under it, four hangers into the vault between two vault lamps).
- **Animated paths** (`client/Controllers/LobbyPathFx`, anchors `LobbyPathRun` / `LobbyLineRun` from `v4_duels.path_run / line_run`): **chevrons up the aisle** light in a wave running toward the trophy (lilac, 42 studs a second); **a chevron run from the aisle to every pad** (violet, 26 a second); **a light pulse runs along each aisle edge line**. Studied first: RIVALS' floor textures are static (a metal pattern and stripes) and its Beams are the screens' scanlines, so the motion is our own.
- **Checks:** 0 floating, 0 leaks, visible pairs 71; the cube's hangers clear the vault lamps; played: 9 chevron runs and 2 line pulses built, the aisle wave travels (lit chevrons move on within half a second), the pad glass reads without shadow steps.
