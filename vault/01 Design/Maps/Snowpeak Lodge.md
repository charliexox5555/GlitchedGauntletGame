# Snowpeak Lodge

A medium snow map for 1v1 to 3v3: a two-storey timber ski lodge in the middle of a mountain saddle, a gondola station on each flank with its cable line climbing off the map into the peaks, a frozen pond, snow decks and pines, under a cold, clear morning sky. Our only snow map. See [Maps](00%20Maps.md) for the roster.

**Status (2026-11-03):** concept. Map id `Snowpeak` · world origin **(-1500, 200, -1500)** · modes 1v1–3v3 (`Config.Match` MAPS: minTeam 1, maxTeam 3).

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

Measured numbers go here once the script passes.

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

## 5. Build and run order
Filled in when the kit is uploaded.
