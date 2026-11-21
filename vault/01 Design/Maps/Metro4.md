# Metro4 (Metro rebuilt the Wharf way, large map 2v2-3v3)

The owner's Metro, rebuilt after [Wharf](Wharf.md) landed ("that's kind of what I'm looking for"). Map id `Metro4`, shown as **METRO** in the vote. The old `Metro`, `Metro2` and `Metro3` models stay in the place untouched.

## Owner calls (2026-11-20)
| Call | Answer |
|---|---|
| Layout | **Re-study RIVALS Station** (measure it like Docks for Wharf) and lay Metro out again from its flow; keep only the theme |
| Size | **Large, 2v2-3v3** (joins Big Arena and Dockyard) |
| Setting | **Glass roof, open ends**: a big station hall with a glazed roof and open track ends where you see the city and sky outside. Bright, with a world beyond (the rejected maps had "no world around them") |
| Look | Wharf's way: mostly Parts on the 5-stud module, carved ends, our own **soft** MaterialVariants (Wharf v2 strength), lively colours (not grey + one accent), **no text signs**; Blender only for what Parts can't do (trains, horizon) |

Rules used: [Map Quality Standard](Map%20Quality%20Standard.md) §3, [Jump Audit](Jump%20Audit%202026-11-13.md), `gauntlet-build-style`, [Style Bible](../../02%20Art/Style%20Bible.md), Home → Locked decisions → Maps (2026-11-20), [Rivals Reference → Maps](../../03%20Research/Rivals%20Reference/Maps%20and%20Lobby.md) (Station row: 3 spawns 101-204 apart, 166 × 252, +1 / +14 / +15 levels, 5-6 lanes, wood and concrete). Pipeline and checks reuse Wharf's (`tools/maps/wharf_layout.py`, `tools/studio/maps/Wharf/Build.luau`, `Checks.luau`, the audits).

## 1. RIVALS Station, measured (2026-11-20, read-only, match place `ServerStorage.MapsRivals`)
Moved into Workspace one at a time, measured with property reads and raycasts in edit mode (no play, nothing copied), put back. Heights are above the yard floor (+6 over `Primary`).

| What | **Station** (regular) | **Big Station** (large: our size) |
|---|---|---|
| Idea | a freight station in the hills: two tracks of parked wagons on the west, a walled station yard east | **two walled yards with the tracks down the middle**: the parked trains are the divider |
| Spawns | 3 slots, 204 / 183 / 101 apart | 3 slots: (-26, 118), (-144, -89), (-85, -1); the two team slots sit in opposite yards, diagonal across the tracks (238) |
| Size | yard ~ 140 × 250 + the track strip | ~ 290 across the tracks × 250 along them (yards x -200..-110 and -55..+75; tracks x -101 and -69, 32 apart) |
| Levels | floor 0, platform blocks +4, wagons ~ +11.5 | floor **0**, track bed **-2.4**, wagon tops ~ +12, footbridge ~ **+15**, building eaves +29, roofs to +68 |
| Crossings | gaps between wagons | **gaps between wagons** at bed level, and a **diagonal footbridge** over both tracks, yard to yard |
| Blockers | 2 big station buildings, staggered | **two buildings per yard, staggered** (33 × 55 / 84 × 47 footprints), a round planter in each yard |
| Cover | crates, barrels, boards, containers | the same; wagons 11 × 14 × 48 with separate collision (`Car Collision`) |
| Sightlines (eye height, 8-grid, 16 dirs) | longest 186, mean 29, 2.7% over 100 | longest **213**, mean 34, **0.5% over 150** |
| World | forested hills all round, the tracks run out of the map both ways | the same: tracks leave through the trees at both ends, mountains and forest |
| Build | buildings mostly Parts with Window parts and a few MeshParts; trains and assets meshes | same; 4,576 instances in `Extra` |

**What we take (flow, not looks):** the trains as the middle divider with ground crossings in the wagon gaps; an elevated footbridge as the one high crossing; two staggered blockers in each half; a centre feature (planter) in each half near the spawn; tracks that run out of the play space at both ends so the world continues. Same family as Docks (staggered blockers + a lane along a "wall" of containers/wagons).

## 2. Layout (`python tools/maps/metro4_layout.py`)
Hall 230 × 210 (x ±115 along the tracks, z ±105 across), 180° rotational symmetry, **+Z = team A**, 5 spawns a side.

```
 z +105  |========== hall wall (glazed above 12) ===========|   city outside
         |  [TICKET HALL A +10 deck]st     [kiosk]   . .        A spawns
         |  steps                         planter  [SHOPS A]
         |      gates   crate    crates  stair===+14 landing
 z +25   |  col    col    col  bench  | col  vending col  col     (platform, 0)
 z +16   |==[ car A1 ]=[ car A2 ]==== |bridge====[work wagon]==   track A
 z   0   |  ~~~~~~~~~~ track bed -2.5, open lane ~~~~~~|~~~~~~~~   (footbridge +14 over)
 z -16   |==[work wagon']====| [ car B2 ]=[ car B1 ]=========    track B
         |  ...B's half, turned 180 degrees...
 z -105  |==================================================|
        x -115 (open end: tracks run out into the city)        x +115 (open end)
```
Plan image: `vault/02 Art/References/maps/metro4/metro4-layout.png` (+ SVG).

| Check | **Metro4** | Big Station / rule |
|---|---|---|
| Floor | 230 × 210 = 48,300 sq studs | Big Station ~290 × 250; Dockyard 200 × 230 |
| Spawns | 5 a side round (0, ±97), gap **193** | big 180-200 |
| Longest eye-height line | **243**, 0.0% of rays over 250 | Big Station 213, 0.5% over 150 |
| Lanes across the tracks | the bed lane (12 wide, -2.5) runs the whole length; across each track: the 7-stud gap between cars, the open track beside each train (72 and 33 wide), the end gaps (8) | 3-5 crossings |
| Cover | 35 full + 16 low, 14.8% footprint | open big maps 12-20% |
| Pinch gaps < 6.5 | **0** | 0 |
| Heights | track bed **-2.5** (low ground), floor 0, crates / gates / benches 3-3.5, step crate +7, trains / blocks +10, ticket hall roof deck **+10** (stair + crate steps), footbridge **+14** (stairs both ends) | ≥3 heights |
| Enemy-half floor that sees a spawn | 0.4% | 0 |
| Sprint spawn → centre / → enemy spawn | 4.0 s / 9.3 s | Dockyard 4.3 / 10.0 |
| First sight, head-on rush | **3.8 s** | target 3-5 |

**Flow (Big Station's, our layout):** the tracks are the divider. Each team's train is parked on its own track and the two trains are staggered, so the ground crossings make an S: past the end of your own train, through the 7-stud gap between its cars, and across the bed under the footbridge. The footbridge (+14, stairs into both concourses) is the one high crossing and overlooks both platforms. Each concourse has a ticket hall (roof deck +10 overlooking the platform: outside stair, or crate 3.5 → 7 → 10) staggered against a shop block on the other side, with gates, benches, vending pairs, crates and a planter as mid cover; a kiosk screens each spawn.

## 3. Build log
1. **v1 (2026-11-20):** layout script (6 passes), 3 new soft MaterialVariants (`tools/textures/make_metro4_textures.py`: Metro_Tile, Metro_Brick, Metro_Facade), builder `tools/studio/maps/Metro4/Build.luau` → `Workspace.Metro4` at (6000, 200, 12500), 1,535 parts. Audits fixed to **0 z-fighting / 0 floating** (from 133 / 6: truss chords sharing side planes, door seams, caps, mullions in pilasters, portal faces, trains whose bogies crossed the rails without touching (wheel blocks added), a stair handrail with no posts). Reach check (new shared `tools/studio/maps/ReachCheck.luau`, true-geometry body box, jump paths ray-tested): both teams 94 studs to the bed centre, 194 to the enemy spawn, 103 / 104 to the footbridge, 69 to their own hall deck. Found and closed: hop over the 3.5 bridge parapet onto the train roofs (glazed bridge sides to +21 + a roof; the glass stops players, not bullets), crate stacks climbable from the ticket gates (raised to 12).
2. **Owner notes on v1 (2026-11-20, mid-build):** "not really looking good": some colours **too bright**, **too cartoony**; "we're not going realistic, but a lot isn't following our build rules"; it should look nicer; the **background buildings look dull and not professional** ("a lot of the buildings in the RIVALS maps look professional"). → v2: calmer palette (less saturation, no pure primaries, grade saturation 0), every piece to `gauntlet-build-style` (carved ends, transitions at every joint, nothing a plain box), city buildings rebuilt as designed facades (base storey, framed windows, pilasters, cornices, roof parapets and plant) after studying how RIVALS' buildings are made.

3. **v2 (2026-11-20, for those notes):** palette muted (warm grey tile, cream stone, muted brick, warm charcoal steel, ochre footbridge, off-white trains with muted A-blue / B-green stripes and doors, muted suitcases and vending, grade saturation -0.05, exposure 0.05). Build rules applied: ticket hall with a stone base, cream stone quoins, framed windows on every face that shows (jambs, head, sill), a framed door and a stepped stone cornice; shops with stone pilasters, a dark fascia, mullioned and transomed shopfronts, awnings under the fascia and a stepped cornice; the kiosk on a plinth with chamfered canopy edges; slatted benches on steel end frames. City rebuilt after a close look at a RIVALS station building (muted colour + layered trim: frames, sills, bands, eaves): each near building has a stone base storey with shop glass, a string course, a framed-window facade (new `Metro_Facade2`, 8 studs a storey), corner pilasters, a stepped cornice, a parapet with a coping ring round a dark roof and roof plant; a taller simpler row behind; towers in the haze. 2,712 parts. Audits **0 z-fighting / 0 floating** again.

4. **Owner notes on v2 (2026-11-20):** many parts still look **unprofessional**, "not really using all the building skills"; **floating parts**, e.g. **the columns under the footbridge** (their tops stopped at 11.5 between the girders, nothing seated them); things are **not organised, even or lined up**. The **cars' wheel section (bogies) and front (cab)** should be made in Blender; the rest of the car can stay Parts. → v3: every support seated with a cap / crosshead (rbx-prop-support-audit), a line-up pass on the 5-stud grid (columns, bays, benches, gates, kiosks on shared axes and even spacing), the map-builder quality checklist on close-ups of every piece, Blender bogies and cab fronts.

5. **v3 (2026-11-20, for those notes):** method from the map-builder quality checklist (supports carry the next member, joints are joints, close-up per prop) and `rbx-prop-support-audit`.
   - **Footbridge supports:** the girders are now plate girders (web, bottom flange, stiffeners every 6) that sit on a **crosshead** at each column; each column has a foot, a cap and two **knee braces** under the crosshead (the platform column and the landing column). Stair treads got closed risers.
   - **Line-ups:** the end trusses moved from x +-115 to +-114 so they stand exactly over the end columns (the columns were 1 stud off their truss); crates are square to the grid (no random tilts); crates in a 10-long box are two 5-stud units 0.06 apart.
   - **Blender kit** (`tools/blender/maps_metro4/metro4_pieces.py`, `run_metro4.py` renders, `run_metro4_export.py`): Metro4 kit (asset 135586549857344): **Bogie** (side frames with a dropped centre, axle boxes, 12-sided wheels with flanges standing on the rails, axles, brake blocks, bolster carrying the floor, motor box), **CabFront** (raked faceted nose meeting the Parts body at a joint plane, framed windscreen with a display band, centre post and wiper, headlights, paint band, anti-climber, skirt, coupler; nose gets its own collision), **TicketGate** + **GatePaddles**. Shared **Props** kit (asset 79842869151783): **CrateA / CrateB** in heights 3.5 / 4.25 / 5 / 6 (skids, V-grooved boards, lid recessed in the frame, posts, rails; A has diagonal braces, B a middle rail and steel corner brackets), **Vending** (stocked window, button panel, lit header, flap), **LuggageCart**, and for Wharf **Pallet** and **Barrier**. Parts named `*Paint*` take each half's colour. Renders: `kit-*.png` in `vault/02 Art/References/maps/metro4/`.
   - **Cars:** the Parts body stops 2 short of a driving end and the cab continues it; a sill and underframe boxes between the bogies replace the old full-length black skirt, so the bogies show.
   - **Kiosk** rebuilt in Parts: stone corner posts and string course, framed serving hatch with a shutter box, mullions and a counter on brackets, framed lower panels, side windows, a framed back door with a light and kick plate, a louvred vent.
   - **Planter (owner, mid-build: "this greenery does not look good", low-poly):** the faceted hedge and conifer were removed from the kit. RIVALS (read-only check of its maps in the match place) plants its planters with hedge meshes in **LeafyGrass** on a **Pavement** base with a **Concrete** cap; ours now does the same with Parts (clipped hedge with a chamfered top course). Far mountains can stay faceted.
   - Audits **0 z-fighting / 0 floating** (from 9 / 0 after the first v3 build: touching crate units, the cab's paint band and anti-climber sharing the joint plane). Reach unchanged: bed centre 94, enemy spawn 195, footbridge 105, own hall deck 69; train roofs, kiosk and crate stacks still unreachable. 2,913 parts.
   - Captures: `metro4-v2-bridge-before.jpg`, `metro4-v3-bridge / -kiosk / -gates / -planter.jpg`.

## Checks (v2, 2026-11-20)
| Check | Result |
|---|---|
| Layout script | longest line 243 (big target 250, 0.0% over), pinches 0, spawns hidden (0.4% of the enemy half sees a spawn), sprint 4.0 s to the centre / 9.3 s to the enemy spawn, first sight 3.8 s |
| Z-fighting / floating | **0 / 0** (mountains and the land plane excluded as ground) |
| Reach (`tools/studio/maps/ReachCheck.luau`) | both teams: bed centre **94** studs, enemy spawn **194**, footbridge **105**, own ticket hall deck **69**. Not reachable: train roofs, crate stacks (12), shed / shop roofs, column caps |
| Playtest (Play, `ForceMap = Metro4`, server R15 walk tester) | A spawn → footbridge → B concourse 12.9 s; up the ticket hall stair onto the deck 6.8 s; through the gap between cars into B's half 8.8 s. **One pathfinding leg stalled** at B's kiosk corner (the path hugged the corner 0.7 off its face); straight walks past it all pass, so it's the pathfinder, not geometry: watch bots there |

Captures (`vault/02 Art/References/maps/metro4/`): v1 `metro4-v1-overview / -platform / -bed.jpg`; v2 `metro4-v2-overview / -platform / -ticket-hall / -shops.jpg`.

## 4. What to test (owner)
1. Save the match place (the map and its MaterialVariants live in it).
2. `ForceMap = Metro4`, `TestMode = false`, Play (2v2 bots); put both back after.
3. The S of crossings: past the end of your train, through the gap between cars, under the footbridge; the footbridge (glass sides block jumping out, bullets go through).
4. Your ticket hall deck (outside stair, or crates): the view over the platform.
5. Look and feel: is the colour calm enough now, and do the buildings outside read as professional? Anything still "cartoony", say where.
6. Bots near the kiosks (the one pathfinding stall above).
