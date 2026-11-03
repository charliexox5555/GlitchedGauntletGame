# Old Town

A large outdoor map for 2v2 to 4v4 (playable 1v1): a sunlit stone plaza with a fountain in the middle, arcades down both sides, two-storey houses with balconies, narrow alleys behind them and a clock tower over the roofs. The most Valorant-looking map of the set. See [Maps](00%20Maps.md) for the roster.

**Status (2026-11-03):** concept, layout, greybox script, Blender kit, art and lighting scripts written; not yet run in Studio. The hub runs the scripts in the match place, screenshots and iterates (run order in **Build** below).

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
| Roof tiles | terracotta `#B4532F` | ClayRoofTiles |
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
| Visible triangles | ≤ 500k (facade modules ≤ 400 each, props ≤ 1.5k, heroes ≤ 6k) |
| Per mesh | ≤ 20k |
| Collision | the greybox Parts only (about 270); every mesh is CanCollide/CanQuery/CanTouch off, Box fidelity |
| Shadows | CastShadow only on wall-sized pieces (kit_bundle rule) |
| Textures | none of our own: Roblox materials (Plaster, Limestone, ClayRoofTiles, Cobblestone, Wood, Metal) |
| Lights | no dynamic lights (daytime) |

---

## 5. Build
Parts are the gameplay and collision; the Blender kit is the look ([Maps](00%20Maps.md) → How a map is built).

| Step | File |
|---|---|
| Layout + checks + SVG + greybox/art generation | `tools/maps/oldtown_layout.py` (`--write` rewrites `Greybox.luau` and `Art.luau`), art placement rules in `tools/maps/oldtown_art.py` |
| Greybox | `tools/studio/maps/OldTown/Greybox.luau` (generated) |
| Blender kit | `tools/blender/build_map_kit_oldtown.py` → `art-source/maps/OldTown/Kit_OldTown.blend`, contact sheets in `vault/02 Art/References/maps/oldtown/` |
| Art | `tools/studio/maps/OldTown/Art.luau` (generated) |
| Lighting | `tools/studio/maps/OldTown/Lighting.luau` |

Run order and what to check: see the end of this note once the kit is uploaded.
