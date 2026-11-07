# Old Town

A large outdoor map for 2v2 to 4v4 (playable 1v1): a sunlit stone plaza with a fountain in the middle, arcades down both sides, two-storey houses with balconies, narrow alleys behind them and a clock tower over the roofs. The most Valorant-looking map of the set. See [Maps](00%20Maps.md) for the roster.

**Status (2026-11-03):** built in Studio once by the hub; the user loved it but flagged z-fighting (the Studio audit found 1,780 pairs, 1,490 of them visible), unnatural windows and doorways, the cart's lumpy load, the bell tower's arches and the bare outer walls. **Fixed in the source** (see **7. No z-fighting** and **Fix round 1** below): the offline check of the assembled map now finds **0 visible coplanar pairs**; kit re-uploaded as new versions of the same assets. Waiting for the hub to rebuild and re-run the Studio audit.

![Old Town from the Cafe Terrace (offline preview)](../../02%20Art/References/maps/oldtown/preview-terrace.jpg)
![Overview (offline preview)](../../02%20Art/References/maps/oldtown/preview-overview.jpg)

**Map id** `OldTown` · **World origin** (0, 200, 1500) · **Modes** 2v2, 3v3, 4v4 (`Config.Match` MAPS: minTeam 2, maxTeam 4).

---

## 1. One line
A warm afternoon in an old town square: cream stone, terracotta roofs, a fountain to fight around, arcades to hide in, and a bell tower that tells you where you are.

### What it should feel like
- **Readable at a glance.** Three lanes you can name after one round: the **Alleys** (flanks, in shade), the **Plaza** (middle, in sun), and the **Arcades** between them. Shade vs sun tells you which lane you're in.
- **Two speeds.** Close rooms and alleys for shotguns and SMGs; one long line through the middle for the Operator rounds.
- **Somewhere you'd want to stand.** Cafe tables under the arcade, a market stall, washing over the alleys: a place, not a test chamber, but with nothing on the floor that hides a body or catches a bullet unfairly.
- **Fair.** 180° rotation: each team has the same streets, turned round. One accent colour per end (blue / green) so a turned map still reads.

### Not this
A copy of Ascent's layout or textures, sepia "medieval" grime, clutter that hides players (crates everywhere, foliage at head height), cartoon wonky houses, high-contrast stripes next to the team colours, invisible walls, rooftops as the main lane.

---

## 2. References
Other games' screenshots stay out of the public repo (`References/maps/oldtown/third-party/` is git-ignored); the sources are linked here.

| Reference | Take |
|---|---|
| [Valorant: Ascent](https://valorant.fandom.com/wiki/Ascent) | The open middle with a landmark in it, a "market" side room, catwalk-style high ground over one side, offset doors so mid never shows you the enemy spawn |
| [Counter-Strike: Inferno](https://counterstrike.fandom.com/wiki/Inferno) | The best "old town" shooter: cream stucco and terracotta, narrow alleys, balconies, washing lines; shade lanes vs sun lanes |
| [Plaza Mayor, Salamanca](https://en.wikipedia.org/wiki/Plaza_Mayor,_Salamanca) | A square enclosed by one continuous ring of houses over a ground-floor arcade: the arcade rhythm (pier, arch, pier) and the warm sandstone |
| [Piazza del Campo, Siena](https://en.wikipedia.org/wiki/Piazza_del_Campo) and [Torre del Mangia](https://en.wikipedia.org/wiki/Torre_del_Mangia) | Brick and stone piazza, paving bands that radiate from the fountain, a tall thin tower that you see from every street |
| [Venice sotoportego](https://en.wikipedia.org/wiki/Sotoportego) | Arches over lane mouths; the lane is a window from the alley into the square |
| [RIVALS: Big Arena](https://robloxrivals.fandom.com/wiki/Big_Arena) | Large maps take over from 3v3; simple, readable blocks matter more than detail |

---

## 3. Layout
![Old Town layout](../../02%20Art/References/maps/oldtown/oldtown-layout.svg)

Generated and checked by `tools/maps/oldtown_layout.py` (the same data writes the greybox). Change a number there, rerun it, and it prints the checks again. Green end is at the top of the plan.

**Shape:** a playable 160 × 272 rectangle inside a ring of four-storey houses. Spawns are 236–256 studs apart. **Symmetry:** 180° rotation (only the Blue half is listed in the script).

From the Blue end to the middle:

| Place | Size (studs) | Job |
|---|---|---|
| **Blue Cloister** (spawn) | 40 × 28 walled garden | Out of every sightline. Two 8-wide gates at the front corners (barriers), never straight ahead |
| **Blue Lane** | 12 wide, wall to wall | The cross street in front of the spawn: left to the west alley and the Market Court, ahead to the Forecourt, right to the Granary and the east alley. Porches and a cart alternate north / south / north so no line runs its length |
| **Gate shrines** | 6 × 7, 8 tall | A wall fountain each side of the Forecourt mouth: they screen the cloister gates from the middle |
| **Forecourt** | 24 × 52 | The mid approach: a well, a cart, a planter. Side exits to Bakery Lane (east) and the Market Court (west) |
| **Blue Gate** | a 10-wide arch, west of centre | The only way from the Forecourt into the Plaza. Offset, so the two gates never see each other past the fountain. A kiosk 8 studs in front: step left or right into the square |
| **Plaza** | 68 × 72, fountain in the middle | The middle lane. Fountain basin Ø22 (3 tall, low cover you can stand on), pedestal Ø12 (full cover), column to 22. Market stalls, a kiosk, cypress planters, cafe tables |
| **Arcades** | 10 deep, 3 arches per half | Down both long sides: piers as full cover, arches to shoot through. The arcade halves are split by the solid **Pavilion** at the centre line, so no corridor runs end to end |
| **Cafe + Cafe Terrace** (east, Blue side) | house 24 × 32; terrace 10 × 32 at height 12 | The high layer: the roof of the east arcade, behind a 3-tall balustrade. Up the Cafe's stair (inside), out through an upstairs door. Faces the Green terrace diagonally across the plaza. Two ways off: the stair, or drop 12 |
| **Bakery** (east) | hall 24 × 20 | Joins Bakery Lane, the east arcade's end and the Cafe (inner door) |
| **Granary, Bakery Lane** (east) | lane 8 wide | Forecourt ↔ east alley |
| **Market Court** (west) | 24 × 24 open court | Three ways in (Blue Lane, the west alley, the Forecourt); crates and barrels. The **Tavern** joins it to the west arcade's end |
| **Chemist, Lane, Bookshop** (west) | lane 8 wide | The Lane is a window from the west alley into the plaza; the Bookshop room joins the Lane and the arcade |
| **Alleys** | 12 wide, both flanks | Shade lanes. House corners (inner side) and buttresses (outer side) alternate about every 30 studs, so a straight line never passes more than two of them |

**Every room has two exits or more:** Bakery 3, Cafe 4 (with the stair), Tavern 2, Bookshop 2, Market Court 3, Cloister 2, Terrace 2 (door + drop).

### Heights (three layers, 12 apart)
| Layer | Height | What |
|---|---|---|
| Ground | 0 | Everything |
| High | 12 | The two Cafe Terraces (one per team, on opposite sides), reached by stairs or Updraft from the plaza (7.2 jump + 14 clears the 15 rail) |
| Roofs | 24–31 | Terracotta roofs over the two-storey houses: Updraft-only from a terrace, exposed from everywhere. Not a lane |

Perimeter houses are 52 tall. The highest floor you reach on foot (the terrace rail, 15) + 7.2 jump + 28 of Updraft = 50.2, so nobody leaves the map with two Updrafts or High Rise (Second Wind B3's third Updraft could; same as Whitebox, a kill volume would fix it).

### Measured (from the script)
| Check | Result | Target |
|---|---|---|
| Spawn sees enemy spawn | Never | Never |
| Enemy-held floor that sees a spawn point | 0% | 0 |
| Spawn → plaza edge (through Blue Gate) | 4.3 s sprint, 6.0 s walk | |
| Spawn → fountain | 5.5 s sprint, 7.6 s walk | |
| Spawn → own Cafe Terrace | 7.4 s sprint | High ground costs time |
| Spawn → alley mid / arcade mid | 6.1–7.0 / 5.6–5.9 s sprint | Flanks a bit slower than mid |
| **Time to first sight** | **4.5 s sprint, 6.1 s walk** (gate to gate past the kiosk) | 5–8 s |
| Earliest meeting point | 6.0 s sprint, 8.2 s walk | Contact ~10 s at walking pace |
| Spawn to enemy spawn | 12.0 s sprint | |
| Longest ground sightline | **130 studs**: Blue Gate's corner across the plaza, through Green Gate into the Green Forecourt (one per side, broken by the kiosk and the cart) | One long line per side |
| Other long lines | Lane mouth ↔ far arcade, 120–125 | |
| Sight rays over 100 studs | 0.5% of 79k sampled | Few |
| Plaza cover spread | average 4.4, furthest 10.3 studs to full cover | Worst under ~15 |
| Passages under 6 wide on any route | none | none |

These are checks at standing eye height on a 1-stud grid, with the terraces and stairs in 3D. They don't replace walking it.

**What it bends:** first sight at a sprint (4.5 s) sits just under the 5 s target; at walking pace it is 6.1 s. Pushing it later means a longer map (already 256 spawn to spawn) or more plaza cover; walk it first. The middle line is 130, longer than the Game Plan's ~70, on purpose: a large map needs one real line for the Operator / Outlaw rounds, and each team gets exactly one.

### Abilities on this size
| Ability | Fit |
|---|---|
| **Updraft** | Plaza → terrace (12) works from anywhere along the balustrade; terrace → roofs is the risky escape |
| **Dash** (12–24) | Crosses a lane mouth or an arch bay out of sight |
| **Firewall** (40 × 10) | Seals a 24-wide street (Forecourt) or half the plaza; doesn't seal the whole square |
| **Molly / Frost** | Rooms and the 8-wide lanes are the denial spots; the 10-wide gate arch is the classic molly |
| **Recall** (40) | An anchor in the Forecourt reaches the plaza edge; one on the terrace is a strong retake |
| **Recon** (40) | A dart over the fountain sees most of the plaza but not into the arcades' back rooms |

---

## 4. Look
### Palette
| Part | Colour | Roblox material |
|---|---|---|
| Stucco walls (three tones per house) | cream `#E9DCC0`, ochre `#E0BE8A`, rose `#DDAA8F` | Plaster |
| Stone trim (plinths, arches, cornices, quoins) | `#D3C3A0` | Limestone |
| Roof tiles | terracotta `#AD5230` | ClayRoofTiles |
| Clock tower shaft | brick `#9E5A40`, stone quoins | Brick |
| Window glass | slate `#3B4652` | SmoothPlastic |
| Plaza and forecourt paving | `#D8C9AA` with darker bands `#B9A584` | Limestone, Cobblestone bands |
| Streets and alleys | `#9C8D7A` | Cobblestone |
| Doors, shutters frame, tables | walnut `#6B4A2E` | Wood |
| Ironwork (lamps, balconies, railings) | `#2B2A28` | Metal |
| Greenery | cypress `#4E6B35`, shrubs `#6B8A3F` | Grass / LeafyGrass |
| Water | `#5FA8B8`, 0.35 transparent | Glass |
| **Blue end** (Team A side) | `#2F6BB3` | Shutters, awnings, stall canopies, banners, doors |
| **Green end** (Team B side) | `#4E8A3E` | The same pieces on the other half |

The team colours (cyan `#00E5FF`, orange-red `#FF5A36`) stay reserved for players and abilities, so the side accents avoid them. Blue and green stay apart for colour-blind players (blue keeps its blue; green reads as olive-yellow).

**Callouts** (short, for comms): Cloister, Lane, Shrine, Forecourt, Gate, Kiosk, Fountain, Stall, Cafe, Terrace, Bakery, Granary, Court, Tavern, Lane (west), Bookshop, Chemist, Pavilion, Alley, Tower side (east).

### Lighting mood
Warm afternoon, sun low in the west (about 40° up) so shadows run across the map, not toward a spawn: sunlit plaza, shaded alleys, warm bounce under the arcades. Bright enough to read on phones without shadows (quality < 4): the lanes still separate by colour (light paving vs dark cobbles, cream vs terracotta). A light warm haze for depth, gentle bloom with a high threshold so cream walls don't blow out.

### Landmarks
- **The fountain** in the middle: the plaza's focal point from every gate and arcade.
- **The clock tower** (104 tall) outside the east perimeter, centred on z = 0: seen over the roofs from the plaza, forecourts and lanes. It isn't rotated, so it also tells you which side is east.
- **The city gates**: each end's gate wears its colour (banners, shutters).

### Budget (mobile)
| Item | Target |
|---|---|
| Triangles | **339k for the whole map** (3,025 kit pieces), so well under 500k visible; facade modules 12–442, props ≤ 852, heroes ≤ 4.7k |
| Per mesh | ≤ 20k (largest: the tower's stone, 2,976) |
| Collision | the greybox Parts only (271 + paving); every mesh is CanCollide/CanQuery/CanTouch off, Box fidelity |
| Instances | about 7,500 MeshParts (one per piece material; the closed outer walls added ~1,600) + 130 plain decor parts: watch this on a phone |
| Shadows | CastShadow only on wall-sized pieces (kit_bundle rule) |
| Textures | none of our own: Roblox materials (Plaster, Limestone, ClayRoofTiles, Cobblestone, Wood, Metal) |
| Lights | no dynamic lights (daytime) |

---

## 5. Build
Parts are the gameplay and collision; the Blender kit is the look ([Maps](00%20Maps.md) → How a map is built). One source of truth: `tools/maps/oldtown_layout.py` holds the plan as 3D boxes, wedges and buildings (an outer box minus rooms and doors); `--write` regenerates both `Greybox.luau` and `Art.luau` from it, so the art always lines up with the collision.

| Step | File |
|---|---|
| Layout, checks, SVG, generation | `tools/maps/oldtown_layout.py [--write]`; art placement rules in `tools/maps/oldtown_art.py` |
| Greybox (generated) | `tools/studio/maps/OldTown/Greybox.luau` |
| Blender kit | `tools/blender/build_map_kit_oldtown.py` → `art-source/maps/OldTown/Kit_OldTown.blend`, contact sheets `oldtown-kit-sheet.jpg`, `-vignette.jpg`, `-heroes.jpg` |
| Export + upload | two groups: **Structure** (asset `96772424739648`) and **Props** (asset `92082436481108`), in `art-source/maps/OldTown/Exports/` |
| Art (generated) | `tools/studio/maps/OldTown/Art.luau` |
| Lighting | `tools/studio/maps/OldTown/Lighting.luau` |
| Offline preview | `tools/blender/preview_map_oldtown.py` → `References/maps/oldtown/preview-*.jpg` (the assembled map as Studio will build it, without the tints) |

![Kit contact sheet](../../02%20Art/References/maps/oldtown/oldtown-kit-sheet.jpg)
![Kit vignette](../../02%20Art/References/maps/oldtown/oldtown-kit-vignette.jpg)
![Kit heroes](../../02%20Art/References/maps/oldtown/oldtown-kit-heroes.jpg)

### The kit (61 pieces)
- **Facade modules** (8 / 4 / 2 wide, 12 per storey, 2 thick like the greybox walls): ground `F_GroundDoor` (an open 6 × 9 arched doorway), `F_GroundShop` (shop window and striped awning), `F_GroundWindow` (barred), `F_GroundClosed` (wooden doors), plain; upper `F_UpperWindow` (shutters), `F_UpperBalcony` (iron balcony), `F_UpperDoor` (the terrace door), plain. The origin is on the floor at the centre of the wall's front face, facing +X.
- **Trims:** `Cornice*` (the inner houses' eaves), `Parapet*` (flat roofs), `Attic*` (the perimeter's 48–52 band), `OuterBand*` (the perimeter's outer side up to a shed roof's high edge), `Quoin12` (slim corner stones between plinth and string course).
- **Roofs:** `Roof12_*` and `Roof16_*` slopes (30°, raised tile rolls), `RidgeCap8/4` (one per ridge, so the two slopes never overlap), `Gable24` and `Gable32` ends with an oculus.
- **Arcade:** `ArcadeBay` (pier, arch, keystone), `Balustrade8`, `ArcadeRoof8` (the west arcade's lean-to), `Arch8` / `Arch8D4` (lane-mouth and cloister-gate arches, 1.85 / 3.85 deep, just inside their lintels), `Stair12` (one solid stepped mass).
- **Heroes:** `CityGate` (the Blue and Green Gates: rusticated base, offset arch, banners, crenellations, bell gable), `Pavilion`, `Fountain`, `ClockTower` (brick shaft, four clocks at ten to four, an open belfry: a round-arched brick wall per side under the cornice with a stone ring and sill, a brick ceiling, a bronze bell with a clapper hung from a timber yoke on iron straps; a tiled spire, 108 tall).
- **Props:** `MarketStall`, `Kiosk`, `Cart` (a hand cart loaded with stacked crates, tailboards and a prop leg), `PlanterLow`, `CypressPlanter`, `CafeSet`, `Well`, `Shrine`, `Crates`, `Barrels`, `StairPorch`, `WallLantern`, `Banner`, `LaundryLine`, `PlazaRing`, `PavingBand16`, `Bench`, `CeilingBeam`. Every cover block in the layout gets the prop that fills it.
- **Colour rules in Studio** (Art.luau): each piece's stucco is tinted to its house's tone (cream, ochre or rose), and the side accent `#2F6BB3` turns green `#4E8A3E` on the Green half.

---

## 6. Build and run (for the hub)
In the **match place**, edit mode, from the Command Bar or the Studio MCP. Everything is re-runnable.
1. `python tools/studio/maps/kit_bundle.py OldTown Structure -o kit1.luau`, then run it (it installs `ServerStorage.MapKit.OldTown`; it replaces the group's old pieces, so re-run it after every upload).
2. `python tools/studio/maps/kit_bundle.py OldTown Props -o kit2.luau`, then run it.
3. `python tools/studio/maps/bundle.py OldTown Greybox Art Lighting -o oldtown.luau`, then run it. It builds `Workspace.OldTown` at (0, 200, 1500) and returns one report line per body: greybox parts, art pieces placed (expect "all kit pieces found"), lighting.
   The greybox alone, before the kit: `python tools/studio/maps/bundle.py OldTown Greybox -o oldtown-greybox.luau`.
4. If CollisionFidelity Box didn't stick on the kit meshes, use the Lobby's `KitFidelity.luau` approach (the meshes neither collide nor take queries either way).
5. Play it: set the Workspace attribute `ForceMap = "OldTown"` and run a 2-player test (MapService applies the map's lighting when it loads). For edit-mode lighting screenshots, set `PREVIEW = true` at the top of `Lighting.luau` for that run only, and don't save the place with it.
6. Save the place and back up `art-source/maps/OldTown.rbxm`.

### What to check in screenshots
- **Spawn** (each cloister, from a spawn pad toward the gates): the two gates read as the only exits, the barriers fill them, and there's no view of the plaza or the other team.
- **Forecourt to Blue Gate** (eye height): the paving band leads to the arch, the kiosk sits in front of it, and the clock tower shows over the roofs.
- **Plaza from each gate and from each terrace**: the fountain is the focal point, the stalls and kiosks read as cover, and the Green half's shutters, awnings, banners and gate shield are **green** (the tint ran).
- **Arcades:** the arches line up with the greybox piers (no pier through an arch), the balustrade sits on the slab edge, the banners hang on the piers, and the west arcade's tiled roof sits on its wedge.
- **Cafe stair:** the steps cover the wedge, and the landing and terrace door line up. The interiors (Bakery, Cafe, Tavern, Bookshop) have plaster walls, plank floors and beams, with no see-through gaps at the doors.
- **Alleys:** the alternating jogs, the laundry overhead, the perimeter windows; the tower base sits flush in the east perimeter with no facade modules through it.
- **Roofs from the terrace:** the slopes sit on the roof wedges, gable ends close the open ends, flat roofs show their tops and parapets. Check which way the ClayRoofTiles texture runs on the slopes.
- **Overview:** nothing floating, and no holes where hidden greybox shows through (a missing module shows as a see-through wall).
- **Lighting:** shadows run across the map toward the tower (east), not toward a spawn; cream walls don't blow out; the alleys are shaded but readable; a phone at quality 1–3 (no shadows) still separates paving, cobbles, walls and roofs.
- **Budget:** `budgetReport` on `Workspace.OldTown` (about 5,900 MeshParts and 351k triangles) and frame time on a phone.

### Known risks
- First sight at a sprint is 4.5 s (the target is 5–8; it is 6.1 s walking). Walk it before changing anything.
- Second Wind B3 (three Updrafts) can top the 52-stud perimeter; it's the same open question as Whitebox, and a kill volume above the roofs would close it.
- The perimeter's outside faces show the backs of windows; nobody can see them from the playable map.
- The interiors have no lights (daytime ambient only); check they aren't too dark.

---

## 7. No z-fighting
Two visible surfaces in one plane flicker. The rules the kit and the placement follow (vault/01 Design/Maps/00 Maps.md):
- **A layer on a surface sits on it** (trim, sill, band, coping, cloth, iron): its back face touches the surface, so both faces are buried and nothing flickers; it stands proud by at least 0.05. A part that must pass into a solid reaches 0.05 into it, never flush with one of its faces. A wall's top is buried in its coping, not level with it.
- **Recessed windows are two layers:** the front layer has the opening, the back layer is solid, and the glass stands 0.05 proud of it and 0.05 into the reveals. From behind, a window is plain wall (no dark rectangles on the outer sides).
- **Modules butt edge to edge:** the kit drops the wall body's end faces (the neighbour or, at a corner, the other facade covers the plane) and pulls trim ends in by 0.03 (eave trims by 0.07), so neighbours meet at a hairline joint instead of a shared plane. Faces resting on the ground or on the storey below are dropped.
- **Roofs:** slopes have no end or ridge faces; one `RidgeCap` per ridge covers the line where they meet; gable bands stop 0.05 inside the corners.
- **Corners:** everything on a W/E facade (modules, eave trims, W/E eave roofs) sits 0.06 lower than on S/N facades, so corner trims and perpendicular fascias never share a plane.
- **Attachments:** windows never sit under an arch, a porch, a shrine or crates against a wall (those spans get plain modules); modules never straddle a corner where another house (or the clock tower) stands against the facade (the rhythm breaks at its edges); awnings and balconies stay off corners and breaks.
- **Linings and plain parts** (Art.luau): room linings butt at corners and stop under the ceiling; flat roof tops are inset 0.1 and below every coping; beams stop inside the linings; the visible arcade slabs start behind the arcade wall; the ground slab reaches past the outer walls.

**Checks (both fail the build):**
- `build_map_kit_oldtown.py` checks every piece on its own with `tools/blender/zfight_check.py` before saving the .blend (so before any export): same plane (< 0.02 apart, parallel), overlapping (> 0.01 studs²), both facing the same way and not pressed against an opposite face = z-fighting.
- `blender --background --factory-startup art-source/maps/OldTown/Kit_OldTown.blend --python tools/blender/preview_map_oldtown.py -- --check` assembles the map exactly as Art.luau places it (every MeshPart, the visible greybox, Art's plain parts) and runs the same test; it writes `art-source/maps/OldTown/zfight-offline.json` and exits 1 on any visible pair. Last run: 338,764 triangles, 7,613 surfaces, **0 visible pairs** (1,144 buried and 52,631 touching pairs are faces pressed together, invisible, and the Studio audit skips them too).

### Fix round 2 (2026-11-03): the triangle-level Studio audit's 183 pairs
The offline check now matches `tools/studio/maps/Audit.luau`: it includes the barriers, and only a visible block Part can bury a face between two parts (never a MeshPart). Fixes: paving floors, the terrace slab and the west arcade ceiling stop 0.1 short of the facades; barriers reach 0.1 into the gate walls and stay 0.05 off the facades; interior floors sit inside the linings; balcony slabs, consoles, parapet bands, the arcade roof's band, porch stones, laundry hooks and the lean-to roof's back end sink into the wall behind them; shrine spout, cypress trunks, gate rustication / glass and pavilion pilasters, glass and pediment moved off shared planes. Offline: 0 visible pairs (kit pieces and assembled map).

### Fix round 1 (2026-11-03, from the user's playtest and the Studio audit)
| Flagged | Fix |
|---|---|
| 1,780 z-fighting pairs (`Attic` stone/stucco 178, `Cornice` + roof tiles 84, roof + roof 82, facade modules where they meet, parapets, arcade bays, shop awnings, arches against windows, props on the ground) | The rules above, in the kit and in the placement; checked offline to 0 |
| Wall-top cap with pink stucco flickering through (a jut's attic) | Wall tops buried 0.35 under their copings; flat roof tops inset and lowered |
| Bell tower: white arch soffits broke through the brick arches (the arch crowned above the cornice), odd bell and clapper | Belfry rebuilt: arched brick walls crowned at 81.2 under the cornice, stone rings and sills, brick ceiling, new bell profile, clapper, yoke on straps |
| Cart with lumpy rocks piled high | A load of six stacked crates in the bed (still full cover), tailboards, prop leg |
| Outer back walls: dark rectangles at random, a roof eave alone | Two-layer walls (no window backs); every outer face of the perimeter gets plain walls, the attic band and, under a shed roof's high edge, an outer band |
| Windows and doors not natural | A regular rhythm per face: openings stack storey over storey; plaza faces alternate shop / window, streets window / shop, alleys window / plain, a closed door in the middle of odd runs; balconies on the first floor on alternate bays (every third on the four-storey houses); no windows cut by arches, porches or neighbouring houses |
| Doorways vs their greybox openings | Door modules match the 6 × 9 voids (jambs at ±3, crown at 9); inner doors get plaster linings and soffits; the terrace door's threshold steps 0.14 over the terrace floor |


## Concepts (Codex)
- [01-overview.png](../../../art-source/maps/OldTown2/concepts/01-overview.png) - Whole-arena aerial with plaza, arcades, alleys and tower.
- [02-hero.png](../../../art-source/maps/OldTown2/concepts/02-hero.png) - Blue gate approach toward the fountain and cafe terrace.
- [03-kit-sheet.png](../../../art-source/maps/OldTown2/concepts/03-kit-sheet.png) - Structure pieces, landmarks, props and material swatches.
