# Snowpeak Lodge

A medium snow map for 1v1 to 3v3: a two-storey timber ski lodge in the middle of a mountain saddle, a gondola station on each flank with its cable line climbing off the map into the peaks, a frozen pond, snow decks and pines, under a cold, clear morning sky. Our only snow map. See [Maps](00%20Maps.md) for the roster.

**Status (2026-11-03):** concept, checked layout, generated greybox, Blender kit (**uploaded, asset 130407667176648**), generated art pass and lighting are done and previewed offline; **not yet run in Studio** (run order in §5). Map id `Snowpeak` · world origin **(-1500, 200, -1500)** · modes 1v1–3v3 (`Config.Match` MAPS: minTeam 1, maxTeam 3).

---

## 1. One line
Fight through a warm timber lodge with a stone fireplace at its heart, or round it in the cold: past the gondola that waits in its station, across the frozen pond, under the cable lines that climb into the peaks.

### What it should feel like
- **Warm inside, cold outside.** The middle is the Lodge: close range, timber, firelight, a double-height lounge with lofts on both ends. The flanks are bright snow under a blue sky. Which one you're in is never in doubt.
- **A landmark on every screen.** The red gondola cabins and the two cable lines rising off the map tell you where the stations are; the Lodge chimney marks the middle.
- **Three heights, no more.** The snow (0), the lofts, balconies and station decks (10), and the roofs (20–30, Updraft only).
- **Fair.** 180° rotation. Each team has its own gondola station by its spawn and faces the other team's across the map.

### Not this
A Christmas-card theme park, candy colours, snow that blows out to white so players vanish against it, a blizzard that hides enemies, pine trees on the fighting floor that hide bodies, a maze of rooms inside the Lodge, invisible walls, slippery ice physics.

---

## 2. References
Other games' screenshots and the photos stay out of the public repo (`References/maps/snowpeak/third-party/` is git-ignored); the sources are linked here. No image has been downloaded into the repo yet: saving local copies is a user call.

| Reference | Take |
|---|---|
| [Timberline Lodge, Mt Hood](https://www.frommers.com/destinations/mount-hood/hotels/timberline-lodge) and its [NRHP nomination](https://npgallery.nps.gov/NRHP/GetAsset/NHLS/73001572_text) | The model for the Lodge: a stone ground storey, timber above, huge exposed beams and a massive stone fireplace in the middle of a tall lounge. Steep snow roofs |
| [Copperhill Mountain Lodge, Åre](https://www.archdaily.com/245939/copperhill-mountain-lodge-aix-arkitekter-ab/) | The fireplace in the centre of a tall timber volume: our double-height lounge, lofts looking down on it |
| [Chalet Béranger, French Alps](https://www.dezeen.com/2012/02/03/chalet-beranger-by-noe-duchaufour-lawrance/amp/) | A chunky stone fireplace under sloping eaves; the fir-and-stone palette |
| [Giggijoch cable car, Sölden](https://bergbahnen.soelden.com/en/projects-investments/highlights/giggijoch-cable-car) | A station with a solid core that reads from far away as a landmark |
| [Merano 2000 station](https://www.suedtirol.info/en/en/experiences-and-events/plp-experiences/experiences-south-tyrol/pdp-experience.smgpoiarchapp73.mountain-station-of-the-merano-2000-cable-car-.falzeben-falzeben) | The lift machinery in one big box: our bullwheel housing on the station deck |
| [Valley station](https://en.wikipedia.org/wiki/Valley_station) and [Gondola lift](https://en.wikipedia.org/wiki/Gondola_lift) | Gondola stations are horizontal; cabins detach and park in a garage under the station (our garage passage); the cable loops round a bullwheel, up and down tracks side by side |
| [Seceda lift, Val Gardena (Commons)](https://commons.wikimedia.org/wiki/File:Lift_Seceda_Gherd%C3%ABina.jpg) | A cable line climbing past pylons above the treeline into rock peaks: the off-map lines |
| [Gondola station in the snow, First (Pakutaso)](https://www.pakutaso.com/en/20171243335post-14325.html) | Snow loading on station roofs, red cabins against white and blue |
| [Peak 2 Peak Gondola](https://en.wikipedia.org/wiki/Peak_2_Peak_Gondola) | A long span across a valley: the lines leave the saddle and cross to the far peaks |
| [Snowcat](https://en.wikipedia.org/wiki/Snowcat) | The groomer parked mid-flank: a believable 8-tall piece of full cover |
| [Valorant: Icebox](https://www.thespike.gg/valorant/maps/icebox) and [Red Bull's Icebox guide](https://www.redbull.com/ie-en/icebox-map-tips-guide-valorant) | A snow map with three lanes and lots of verticality; players found its tight interiors and many levels hard, which is why we stop at three heights and keep the Lodge to one big room per storey |
| [Overwatch: Ecopoint Antarctica](https://liquipedia.net/overwatch/Ecopoint:_Antarctica) | A small snow arena built for 1v1–3v3: a warm interior in a cold exterior, short routes |
| [Overwatch: Nepal](https://liquipedia.net/overwatch/Nepal) | Sunny snow on mountain buildings, a blue sky and peaks as the backdrop, snow kept off the readable surfaces |
| [DevForum: best winter lighting](https://devforum.roblox.com/t/whats-the-best-winter-lighting/1801093) and [snow effects thread](https://devforum.roblox.com/t/experimenting-with-snow-effects-for-open-world-survival/1185023) | Blue-white sky, light atmosphere; the common critique is "the sun is too bright for winter", so exposure comes down and the ambient goes blue |

### What the LihFolk notes add
- **Frost preset** (Stylized Lighting Recipes): ClockTime 11, Ambient (120,135,160), OutdoorAmbient (160,175,200), Brightness 2.5, ColorShift_Top (220,235,255); Atmosphere Density 0.35, Colour (210,225,245), Decay (150,170,210), Glare 0.3, Haze 1; Bloom threshold 1.4; grade saturation down. Snow that clips to white means the exposure is too high: check a greyscale shot.
- **Blue shadows:** warm ColorShift_Top, cool Ambient, sun 30–50° up; lit faces 1.5–2.5× the shadow faces.
- **Neon lights nothing**: the warm window glow is Neon plus a few real lights at the focal points (8–12 visible, shadowless on phones).
- **Cover heights:** under 2 is a kerb, 2.5–3.5 low cover, avoid 4–6, 7+ full cover. At least 30 studs clear over the fighting floor.
- **Low-poly pines:** a 5–8 sided trunk with a root flare, stacked canopy tiers, dark green low; canopies never collide, so no pine stands on the fighting floor.
- **Snowfall:** if any, light and client-side (rate 60–150, size 0.15–0.3), never dense enough to hide a player. Not in the first pass.
- **Composition** (World Composition): one hero per view (the Lodge chimney, the gondola), leading lines (the cables, the fence line) pointing at it; saturation on the hero and interactables, never on the ground.

---

## 3. Layout (plan)
Checked by `tools/maps/snowpeak_layout.py`, which writes the SVG and the greybox data. **Symmetry:** 180° rotation (team A at -Z, team B at +Z). **Shape:** a 128 × 160 saddle, a spawn alcove cut into the rock at each end, a fence on a drop-off along both long sides.

| Place | Job |
|---|---|
| **Lodge** (middle) | Two storeys, 36 × 44. The **Lounge** is double height round a stone **Fireplace** (with the chimney, the middle's landmark); a **Loft** at each end at height 10 looks down into it; a **Bar** under each loft. Main door toward each spawn, two doors in each long wall, upstairs doors onto the balcony |
| **Balcony** | Wraps round the Lodge at height 10, 5 deep, low rail. Your **outside stair** climbs to it from your spawn side |
| **Station** (your flank) | The gondola station: a concrete base with a **Garage** passage through it, the **Deck** at 10 with the parked cabin and the bullwheel housing, a stair from your side. The cable leaves over the edge and climbs off the map |
| **Pond** (your other flank) | The open lane: a frozen pond with a snowy rock **Island**, the skating **Hut** at the spawn end |
| **Snowcat** | A parked groomer in the middle of each flank: cover between the Pond and the enemy Station |
| **Patrol** | The ski-patrol hut in front of each spawn: no line from the middle reaches the spawn |
| **Edges** | Rock cliffs behind the spawns (out of reach), a timber fence on the drop-off along both sides (fall = death at the map's kill height) |

![Snowpeak Lodge layout](../../02%20Art/References/maps/snowpeak/snowpeak-layout.svg)

Interior: the B half of the Lodge from the main door: the **entry porch** (side walls) → the **entry hall** under the loft, between the **back bar** (west, the bar room with the counter and the west door) and the **boot wall** (east, the boot room with the east door) → the **lounge**: the fireplace in the middle with a stair up to each loft beside it (B's on the east side of the fire, A's on the west). Doors are only in the under-loft rooms, so seen through the porch the main door never lines up with a side door.

### Measured (from the script, 3D voxel checks at 0.5 studs)
| Check | Result | Target |
|---|---|---|
| Gaps under 6 between pieces (ground and height 10) | none (the 2.5 bartender aisle and the hop-over sofa are exempt on purpose) | none |
| Spawn sees enemy spawn | never | never |
| Enemy-half floor / high spots (lofts, balconies, decks, roofs) that see a spawn | 0% / 0 of 1,142 | ~0 |
| Spawn to spawn | 176 straight, 207 walked (9.4 s sprint) | 150–190 straight |
| Both teams meet (sprint / walk) | 4.7 s / 6.5 s | contact ~10 s with fighting on the way |
| **First sight** | **3.2 s sprint, 4.3 s walk**, 74 studs (west porch corner ↔ the far side of the west flank); within 70 studs 3.3 / 4.5 s | 5–8 s |
| Rays over 100 / over 70 studs | 4.2% / 15.1% | Dockyard 0.6% / 6.5% |
| Distance to full cover | average 5.3, worst 17.5 (the open snow by the drop-off) | worst under ~15 |
| What the high spots see | station deck 28%, island top 37%, Lodge ridge 21%, station roof 28%, balcony 11–14%, loft 2% | — |
| Highest reach | 34 (chimney top) + 7.2 + 28 = 69.2 | under the 72 cliffs |
| **Coplanar faces** (greybox) | **0** in 158 pieces | 0 |

**What it bends:** first sight lands under the 5 s target at a sprint (like Dockyard 3.8 and Old Town 4.5), on a 74-stud diagonal past the Lodge's west porch; walking it is 4.3 s. More cover there would close the porch, which is the flank-to-middle rotation. The flanks are more open than Dockyard's container yard (15% of rays over 70): the pond lane is meant to be the long lane, one per side. Walk it first.

---

## 4. Look
| Part | Colour | Note |
|---|---|---|
| Snow | `#E9EEF5` (Snow) | Never pure white; under the cool ambient it reads blue in shade |
| Ice | `#A9CBDD` (Glacier) | Darker than the snow, so the pond reads as its own lane |
| Lodge timber | stained larch `#6E4B33`, beams `#5A3B27` | The warm block on every screen |
| Stone | granite `#8C8883`, darker joints | The plinth and the fireplace |
| Roofs | slate-dark metal `#3B434D` with snow on it | |
| Station | concrete `#A9ABAE`, steel `#5E656D` | |
| **Gondola red** | `#A8262E` | The hero accent: cabins, station trim. Darker and bluer than the team orange-red (`#FF5A36`), which stays for players |
| Warm light | `#FFC98A` | Lodge windows (Neon), lamps |
| End paint | B end `#2E6FB0` blue, A end `#D9A520` gold | Patrol huts and the station signs, so a turned map still reads |

**Lighting mood:** a clear cold morning. Sun about 37° up, raking along the X axis (GeographicLatitude 0, ClockTime ~8.5) so neither team looks into it; cool blue ambient so shadows go blue; exposure pulled down so the snow keeps detail; warm light only from the Lodge (windows, fire, lamps) and the station lamps.

### Built with
| Use | For |
|---|---|
| **Roblox Parts** (greybox) | Everything you walk on or shoot. Hidden where the art covers them, never deleted. Each part carries `Kind`, `Piece` and `Half` attributes |
| **Blender kit** (`art-source/maps/Snowpeak/Kit_Snowpeak.blend`) | The look: Lodge, interior, station, gondola cabins, cable lines and pylons, pond rim, hut, snowcat, fence, rocks, cliffs, pines, mountains |

---

### The kit (as built)
![Kit contact sheet](../../02%20Art/References/maps/snowpeak/kit-contact.jpg)
![Overview (offline preview)](../../02%20Art/References/maps/snowpeak/snowpeak-preview-overview.jpg)
![From the B spawn](../../02%20Art/References/maps/snowpeak/snowpeak-preview-from-b-spawn.jpg)
![The lounge](../../02%20Art/References/maps/snowpeak/snowpeak-preview-lounge.jpg)
![The B station from the balcony](../../02%20Art/References/maps/snowpeak/snowpeak-preview-station.jpg)

`tools/blender/build_map_kit_snowpeak.py` → `art-source/maps/Snowpeak/Kit_Snowpeak.blend`, group `Kit`, **asset 130407667176648**: 30 pieces, 193 parts, 41k unique triangles. Pieces that stand where there is collision are built on the layout's own boxes (the script imports `snowpeak_layout.py`), so what you see is what you stand on and shoot. The same script writes the PLACEMENTS block of `Art.luau`, so the offline preview and Studio place the same pieces.

| Piece | What |
|---|---|
| `Lodge` | Timber walls on the greybox walls, stone plinth, floor band, frames, green shutters (open beside the upper windows, closed on the blank ground bays), glass, the balcony (deck, chalet balustrade, brackets), porch walls, boxed roof overhang with snow, gable sign boards, lanterns |
| `LodgeInside` (×2) | Loft floor and beams, loft rail, back bar with bottles and mirror, boot lockers, bar counter, stools, sofa, rug, iron chandelier |
| `Fireplace` | The stone hearth with a firebox on both faces (fire glow), mantels, the chimney to 34 with a cap |
| `LodgeStair`, `DeckStair`, `StationStair` | 6 × 16 stairs rising 10 (closed sides like the WedgePart) |
| `Station` (×2), `Cabin` | Concrete base with the L garage, deck, bullwheel housing and wheel, overhead rail the parked cabin hangs from, roof with snow, end-paint bands, sign boards |
| `Line` (×2) | Two cables from the bullwheel up the ridge to a summit station, 4 pylons, hanging cabins |
| `PatrolHut`, `SkateHut`, `Kiosk`, `Woodshed`, `Woodpile`, `Firewood` | Timber huts filling their boxes (gable roofs with snow, lit windows), log stacks |
| `SnowPile8/18`, `Island`, `Boulder6/8` | Ploughed snow blocks with blade-cut sides; faceted rocks with snow caps |
| `Snowcat`, `TrailMap`, `SkiRack`, `FirePit`, `LampPost` | Props (lamp posts are thin decor, no collision) |
| `Parapet8` | The edge wall: stone, timber cap, snow |
| `PondRim` | Snow lip round the ice with rounded inner corners (hides the ice rectangle) |
| `Cliffs`, `Range`, `PineGrove` | Rock faces behind the spawns (recessed behind the collision face), the mountains (a centrally symmetric heightfield: drop-offs, end ridges, far peaks), 46 pine groves on the slopes |

**Z-fighting:** the kit script assembles the whole map exactly as `Art.luau` places it, adds the greybox Parts that stay visible (snow, terrace, Lodge floor, ice) and tests every triangle pair: same-facing, within 0.02 studs of one plane, overlapping by more than 0.0025 sq studs, not buried in a visible Part → **0 pairs over 81k triangles** (`art-source/maps/Snowpeak/coplanar.json`). Rules it enforces: attached layers (plinth, band, frames, shutters, paint) each sit at their own depth, frames reach 0.05 into their openings, trims stand ≥ 0.05 proud.

### Budget (mobile)
547 MeshParts, about **81k triangles for the whole map** (largest mesh 8.5k: the cliff rock), 10 lights, all shadowless. No textures beyond Roblox materials. The art is CanCollide/CanQuery/CanTouch off; kit_bundle turns shadows off below 8 studs.

### Quality score (maker's draft, LihFolk world rubric)
| Criterion | W | Points | Evidence |
|---|---|---|---|
| W1 Composition and focal point | 3 | 2 | The Lodge gable and chimney face each spawn; cables climb the ridge behind |
| W2 Navigation readability | 3 | 2 | Lodge / station / pond lanes, a station on each flank, end paint |
| W3 Style cohesion | 2 | 2 | One timber-stone-snow family; the station is the one modern piece (concrete and red) |
| W4 Lighting and mood | 2 | 1 | Tuned offline only; needs the Studio greyscale check |
| W5 Detail density | 1 | 1 | The flank snow fields are plain between the cover pieces |
| W6 Scale | 1 | 2 | Doors 8, storeys 10, cabins 6 × 8 against a 5.4 avatar |

**8.8 / 10, draft:** scored by the maker from offline renders. The hard gates (floating props, budget in Studio) and the 3-reviewer pass need the Studio screenshots. Next fixes: W4 in Studio (exposure / ambient), then W5 (snow drifts, footpaths and benches on the flanks, all decor-sized).

## 5. Build and run order
Built 2026-11-03 by a parallel map session (no Studio, no Blender MCP): the hub runs it in the match place, edit mode.
1. Layout (done; rerun after any change): `python tools/maps/snowpeak_layout.py --luau` prints the checks, writes the SVG and the greybox data.
2. Greybox: `python tools/studio/maps/bundle.py Snowpeak Greybox -o snowpeak_greybox.luau`, run it. Expect `Snowpeak greybox: 159 parts, 4 + 4 spawns, 2 barriers` (the gable roof is two wedges).
3. Kit (already uploaded): `blender --background --factory-startup --python tools/blender/build_map_kit_snowpeak.py -- [--no-render]` (also rewrites the Art.luau placements), export `blender --background --factory-startup art-source/maps/Snowpeak/Kit_Snowpeak.blend --python tools/blender/export_lobby_kit.py -- --maps Snowpeak Kit`, upload `python tools/opencloud/upload_models.py --maps Snowpeak --group 11116787 Kit` (updates asset 130407667176648).
4. Install the kit: `python tools/studio/maps/kit_bundle.py Snowpeak Kit -o snowpeak_kit.luau`, run it (`ServerStorage.MapKit.Snowpeak`, 30 pieces).
5. Art + lighting: `python tools/studio/maps/bundle.py Snowpeak Art Lighting -o snowpeak_art.luau`, run it. The report should say `all kit pieces found`.
6. Audit: `loadstring(Audit.luau)("Snowpeak")` → target 0 z-fighting pairs.
7. Check: walk it, screenshots, the mobile budget; save the place and back up `art-source/maps/Snowpeak/Snowpeak.rbxm`.

**What to check in the first screenshots**
- **Kit axes:** the Lodge walls sit exactly on the hidden greybox walls (doors line up with the openings, the balcony deck is the walking surface), both `LodgeInside` copies line up (A turned 180), the stairs climb the right way (Lodge stairs up toward each loft, the deck stair up to the end balcony, the station stair up to the deck), the parked cabin's arm meets the overhead rail.
- **Sun:** `Lighting:GetSunDirection()` mostly ±X. Snow not clipped in a greyscale shot; a player readable against snow in shade and against the Lodge timber. Tune `ExposureCompensation` / `OutdoorAmbient` first.
- **The edges:** the parapet stops a Dash; going over it falls to the kill height (40 below). The cliff rock sits behind the collision face (no rock poking into the alcoves).
- **Signs:** the Lodge, station and patrol names face outward (SurfaceGui Front).
- **The cable lines** leave the bullwheel over the parapet and climb the ridge; no cabin clips the summit station.
- **Budget:** MeshParts (the report prints it), 10 lights.

## Concepts (Codex)
- [01-overview.png](../../../art-source/maps/Snowpeak2/concepts/01-overview.png) - Whole-arena aerial with lodge, stations and ponds.
- [02-hero.png](../../../art-source/maps/Snowpeak2/concepts/02-hero.png) - Blue spawn view toward the lodge and chimney.
- [03-kit-sheet.png](../../../art-source/maps/Snowpeak2/concepts/03-kit-sheet.png) - Structure pieces, props and material swatches.
