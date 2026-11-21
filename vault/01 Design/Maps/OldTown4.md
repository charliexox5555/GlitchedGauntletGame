# OldTown4 (Old Town remade)

**Status (2026-11-21): built v1 and in rotation** (shown as **OLD TOWN**, 2v2-3v3). The owner picked Collina; the build is below in [Build v1](#build-v1-2026-11-21). **Save the match place.** The concept round that led here follows the build section.

The owner's next map after the 2026-11-21 playtest round: **"a new Old Town, similar type but remade with our ideas, based on OldTown2"**. Concept first (owner, 2026-11-21): this note, two layout directions and the concept-image prompts; nothing is built until the owner picks. Map id `OldTown4`, shown as **OLD TOWN**. The old `OldTown`, `OldTown2` and `OldTown3` stay in the place untouched.

## What we keep from OldTown2, what changes
| Keep (the vibe) | Change (our ideas, and what held OldTown2 at 6.3) |
|---|---|
| A warm Italian old town: cream / ochre / rose stucco, terracotta roofs, stone arcades | **Not a closed box.** OldTown2 is a court walled in by tall flat perimeter blocks; the new town **continues past the bounds** (roofs, streets, a campanile, cypress hills, the sea or a valley beyond), like Wharf and Metro |
| A fountain to fight round, market stalls, a cafe terrace | **RIVALS-clean lanes, not a maze of small rooms.** Few, clear lanes; big readable blocks; height you can name |
| The clock tower as the landmark | **Designed facades** (stone base storey, framed windows with shutters, string courses, cornices, balconies, varied heights and roof lines), never a repeated window grid |
| Golden hour (OldTown2's concept) | **Real props**, no placeholder bricks: a modelled fountain, stalls with goods, a well, cafe sets, carts, planters ([No placeholder bricks](../../05%20Production/Playtests/2026-11-21%20Map%20Playtest.md)) |
| Blue / green side paint on shutters and awnings | **More levels**: a +7 middle feature and +12 terraces (owner on Arena: "more levels, high ground") |

Rules: [Map Quality Standard](Map%20Quality%20Standard.md), the Wharf / Metro4 / Snowpeak4 way (Parts on the 5-stud module with soft MaterialVariants, Blender for heroes and props, audits 0 / 0 / slopes 0, ReachCheck), no text signs, no low-poly greenery, no placeholder bricks, no spawn nooks (ghost hold).

## Assets
- **Parts** on the 5-stud module with our soft MaterialVariants (stucco, stone, terracotta, cobbles), the Metro city's facade methods.
- **Blender** (modelled with the skills, like the snowcat): the fountain, the clock tower's top, the covered bridge or loggia, stalls and goods, a well, cafe sets, carts.
- **From the RIVALS maps** (owner 2026-11-21: allowed, nothing with a logo, no scripts; each one listed in this note when used), candidates found read-only in `ServerStorage.MapsRivals`:
  - Museum's stone arch kit (`MiniGrandArch_01-04`, `MiniGrandArchTrim_03`, `GoulfArch_01`): the arcades;
  - Studio's `Awning_01` and `Bush_01` (LeafyGrass bushes);
  - Station's `PlanterHedge_05/07` and `Doors_03/04`;
  - Studio's `Railing_01`;
  - `NewCrate_01/02`.
  - **Skipped:** `CrateBadges_*`, which may carry badges or logos.

## Size and team size
Large, **2v2-3v3** (it joins Big Arena, Dockyard and Metro): 200 × 220, spawn gap 200, 5 spawns a side. It can be cut down to a regular map if the owner prefers.

## Two layout directions (blockouts; `python tools/maps/oldtown4_layout.py`)
Both are first blockouts to choose a direction, not final layouts. The chosen one gets the full iteration (cover density, second ways up, sightline polish).

### A. Canale (a canal town)
![Canale](../../02%20Art/References/maps/oldtown4/oldtown4-canal-layout.png)

A canal crosses the middle (walkable, 3 below the quays), the way Metro's track bed does. The landmark is a **covered stone bridge** at the centre (+7 deck, arches you walk under in the canal), with two flat side bridges at the flanks.

Each half has:
- a piazza with a fountain;
- an arcade house with a **+12 roof terrace**;
- a cafe and market stalls;
- a loggia kiosk that breaks the spawn line;
- a gatehouse screening the spawn;
- quay houses on the canal.

Beyond the bounds, the canal runs on between houses to the lagoon.

| Check | Canale |
|---|---|
| Spawn gap | 200 |
| Longest line | 242 (0% over 250) |
| Pinches | 0 |
| First sight | 2.6 s (target 3-5: a little quick; more mid cover in the iteration) |
| Spawn to centre / enemy spawn | 4.4 s / 10.0 s |
| Heights | canal -3, floor 0, low cover 3-3.5, bridge **+7**, terrace **+12** (one stair so far; a second way in the iteration) |
| Feel | three crossings over one divider (bridge, under the bridge, side bridges): an S like Metro |

### B. Collina (a hill town)
![Collina](../../02%20Art/References/maps/oldtown4/oldtown4-hill-layout.png)

The middle is a **raised piazza (+7) round the clock tower**, climbed by a stepped street and a ramp from each half. Each half has:
- a lower street with a fountain;
- a loggia house with a **+12 terrace**;
- a long house;
- alleys on the flanks that run under arches.

Beyond the bounds, roofs step down the hill to cypress slopes and a valley.

| Check | Collina |
|---|---|
| Spawn gap | 200 |
| Longest line | 224 (0% over 250) |
| Pinches | 0 |
| First sight | **3.8 s** |
| Spawn to centre / enemy spawn | 3.9 s / 10.2 s |
| Heights | floor 0, low cover 3.5, the hill piazza **+7** (4 climbs), terrace **+12** (one stair so far), the tower 40 |
| Feel | king-of-the-hill middle with flanking alleys under arches; the tower is visible from everywhere |

**My pick: B (Collina).** Its numbers are already in range, it gives the "more levels" you asked for on Arena, and the tower in the middle is the strongest landmark. A gives the more distinctive silhouette (the bridge and the canal), but it needs more mid cover.

## Concept images (paste into ChatGPT)
Our concept-image workflow: ChatGPT makes the concept images from these prompts, and nothing is built until you approve one. Save the results to `art-source/maps/OldTown4/concepts/` (that folder is never committed if an image uses third-party references).

**Style lines for every prompt:**
- stylised but not cartoony, clean readable shapes like a competitive Roblox shooter (RIVALS-clean);
- warm golden-hour light;
- cream, ochre and rose stucco with stone dressings and terracotta roofs;
- blue and green shutters;
- no text, no logos, no people.

1. **Collina, overview:** "A bird's-eye concept of a compact Italian hill town designed as a competitive shooter map. In the middle, a raised stone piazza (one storey up) surrounds a tall brick clock tower; two stepped streets and two ramps climb to it from the lower streets on both sides. Each side has a fountain square, a two-storey loggia house with a roof terrace and outside stair, a long house, and narrow alleys on the flanks that pass under stone arches. The town continues beyond the playable area: roofs stepping down the hill, cypress trees, a valley in warm haze. Cream, ochre and rose stucco, stone corners and cornices, terracotta roofs, blue and green shutters. Golden hour, long soft shadows. Stylised, clean, readable shapes, not cartoony. No text, no logos, no people."
2. **Collina, player view:** "Eye-level view from a lower street looking up a wide stepped street to a raised piazza with a brick clock tower above it. A fountain in the foreground, market stall with crates of fruit, a loggia with arches and a terrace railing on the left, shutters and balconies, terracotta roofs, cypress hills beyond. Golden hour. Stylised but not cartoony, clean shapes for a competitive shooter. No text, logos or people."
3. **Canale, overview:** "A bird's-eye concept of an Italian canal town designed as a competitive shooter map. A canal crosses the middle; at its centre a covered stone bridge with arches (you can walk on it and under it), two smaller flat bridges at the sides. Each side has a piazza with a fountain, an arcade house with a roof terrace, a cafe with tables and umbrellas, market stalls, quay houses with boats tied up. The canal continues beyond the map between houses toward a lagoon. Cream, ochre and rose stucco, stone, terracotta roofs, blue and green shutters. Golden hour. Stylised, clean, readable, not cartoony. No text, logos or people."
4. **Props sheet (either option):** "A clean prop sheet for a stylised Italian old town shooter map: a stone fountain with a basin and a carved column, a market stall with a striped awning and crates of fruit, a stone well with a small roof and crank, a cafe table set with chairs and a parasol, a wooden hand cart, terracotta planters with clipped shrubs, a wall lantern, a wooden door with iron studs, shuttered windows with stone frames. Consistent warm palette, golden-hour lighting, white background. No text or logos."

### Concept PNGs (2026-11-21)

| View | Concept |
|---|---|
| Collina overview | [collina-overview.png](../../../art-source/maps/OldTown4/concepts/collina-overview.png) |
| Collina player view | [collina-player-view.png](../../../art-source/maps/OldTown4/concepts/collina-player-view.png) |
| Canale overview | [canale-overview.png](../../../art-source/maps/OldTown4/concepts/canale-overview.png) |
| Shared prop kit | [old-town-props-sheet.png](../../../art-source/maps/OldTown4/concepts/old-town-props-sheet.png) |

Original generated concepts. The Collina views share the tower, loggia, fountain and market palette. Use the Collina v2 layout below for exact route positions and elevations, which vary between the renders. The Canale image shows all three bridges across the main canal. The props sheet groups the nine requested prop types. Ready for the owner's art review.

## Owner pick (2026-11-21)
**Collina (the hill town).** Canale is parked. Next: the Collina layout iterated to the standard (below), then concept images (prompts above) approved before any build.

## Collina layout v2 (2026-11-21, after the pick)
Same plan image, iterated: `vault/02 Art/References/maps/oldtown4/oldtown4-hill-layout.png`.

**Up on the hill (+7):**
- planters, a bench and an edge parapet round the tower (low cover);
- a small pavilion (full cover), so standing up there isn't a free kill.

**The lower streets:**
- a well;
- a kiosk at the ramp foot;
- a wall shrine on the west flank;
- a garden wall by the long house;
- a hand cart.

**The +12 loggia terrace** now has two ways up: the stair, or stone steps (3.5 → 7 → 12).

| Check | Collina v2 |
|---|---|
| Spawn gap / longest line | 200 / 224 (0% over 250) |
| Pinches | **0** |
| Spawn sees spawn / enemy half sees a spawn | never / 0.0% |
| First sight | **3.8 s** |
| Sprint to centre / enemy spawn | 4.0 s / 10.2 s |
| Heights | 0, low 3-3.5, steps 3.5 / 7, hill piazza **+7** (2 climbs a side + jump from 3.5 cover), cover on top to +10.5 / +17, loggia terrace **+12** (stair + steps), houses 14-16, the tower 40 |
| Cover | 20 full + 16 low (more detail dressing comes in the build: doorsteps, planters, benches, lamps, washing lines out of the lanes) |

**Concept prompts, updated for v2:** the Collina prompts above stand; add to prompt 1:
- "a small arched pavilion and stone planters on the raised piazza";
- "stone steps up the side of the loggia";
- "a well and a kiosk in the lower streets".

## Owner decisions (resolved 2026-11-21)
1. **Direction:** Collina (Canale parked).
2. **Size:** large 2v2-3v3.
3. **Concept images:** in (above). Owner: "pretty realistic looking, but it's all right. Let's go ahead and build it. Don't have to build to the T the images ... use good judgment."

## Build v1 (2026-11-21)
Built in the match place at **(6000, 200, 26000)** (`Workspace.OldTown4`) by `tools/studio/maps/OldTown4/Build.luau` (run: copy to `src/shared/_DevBuild/`, `require(<clone>)()`). Parts carry OldTown2's own MaterialVariants (`OT2_Stucco / Ashlar / Paving / Cobble / Terracotta / Plank`). The props and details come from a new Blender kit, `tools/blender/maps_oldtown4/` (`oldtown4_pieces.py`, `run_oldtown4.py` renders, `run_oldtown4_export.py`), uploaded as asset 100833762894900 and installed as `ServerStorage.MapKit.OldTown4`. 6,708 parts.

| Overview | From the lower street | Hill piazza |
|---|---|---|
| ![overview](../../02%20Art/References/maps/oldtown4/build-overview.jpg) | ![street](../../02%20Art/References/maps/oldtown4/build-street.jpg) | ![piazza](../../02%20Art/References/maps/oldtown4/build-piazza.jpg) |
| **House bridge over the east alley** | **Spawn terrace view** | |
| ![bridge](../../02%20Art/References/maps/oldtown4/build-bridge.jpg) | ![vista](../../02%20Art/References/maps/oldtown4/build-spawn-vista.jpg) | |

**What's built.** Layout v2 rows, with the A half turned 180° for B.

**The middle:**
- the +7 hill piazza: ashlar retaining walls with pilasters, a stone coping, paving bands, a wall fountain on the flank;
- a brick **clock tower** (40) on an ashlar plinth, with stone quoins, string courses, slit windows, four kit clock faces and the kit belfry (bell, tiled pyramid roof).

**Each half:**
- **Climbs:**
  - a 14-step stone **stepped street** between ashlar cheek walls with potted newels;
  - a cobbled **ramp** with stone cordonata edges.
- **On the hill:** a planter with a clipped LeafyGrass hedge, a high-backed stone bench, the edge balustrade, the kit pavilion.
- **Lower street:**
  - the kit fountain on a bordered paving square;
  - the market stall (side-coloured stripes);
  - the well, a hand cart with a crate;
  - a kiosk shop;
  - a votive shrine (a painted niche with lit candles).
- **Loggia house:**
  - a five-bay kit arcade portico with a timbered ceiling;
  - a +12 roof terrace with kit balustrades, a pergola with a vine, cafe sets, a roof hut;
  - a stone stair with a landing on the east side;
  - stone steps up the west side (3.5 → 7 → 12);
  - a cafe front on the north street.
- **Long house:** three storeys, shops with striped awnings, a balcony, a garden wall and a garden.
- **House bridges over both flank alleys:** an ashlar pier, stone lintels, a timber ceiling, a lantern.
- **Town gate:** brick with merlons, a voussoir arch, closed doors, lanterns. It stays a baffle in front of the spawn.
- **Corner houses** round the spawn terrace, which ends in a balustrade over the drop.
- **Washing lines** across both alleys.

**Facades** come from one `house()` routine:
- a rusticated ground storey or base course, a string course, a two-step cornice;
- long/short stone quoins on the dressed corners;
- kit windows with side-coloured shutters (A green, B blue), kit doors with doorsteps, shop fronts with awnings, lanterns, balconies;
- terracotta gable roofs with ridge rolls and chimneys.

**The world past the bounds:** row houses face the flank alleys (dressed fronts). The town stands on an ashlar plinth above a valley: a lower town of simple houses 26 below the spawn terraces, fields, kit cypress lines, and a ring of faceted kit hills (allowed for far shapes). Golden hour (authored data 417 / 418) with a warm haze (`LightingFx`).

**Judgment calls against the concepts / layout v2:**
- **Loggia stair:** its landing sits at z 31-35.5, so you arrive on the terrace facing the middle. The stair moved 1.5 toward the spawn.
- **House bridges:** each got a 2.5 x 10 pier on the alley's inner side to carry it.
- **Town gate:** kept closed (a blind gate) so it stays a baffle.
- **Loggia stair's outer wall:** ashlar, 2.3 above the steps. A tall pink wall read as a blank wedge from the piazza.
- **Roof hut:** 8.4 tall, so its roof is out of jump reach.
- **Cypress:** used only past the bounds (the kit cypress is lumpy up close; no low-poly greenery in play). Hedges are LeafyGrass Parts.

**Kit (22 pieces, 46.7k tris):**
- Fountain, Well, MarketStall, Cart, CafeSet, PlanterBox, PotBush;
- WallLantern, WindowUnit, DoorUnit, ArcadeBay, Balustrade5, BalPost;
- BelfryTop, ClockFace, Pavilion;
- CypressA/B, Bush, HillA/B/C.

Close-ups: `vault/02 Art/References/maps/oldtown4/kit-*.png`. The float audit found the belfry, pavilion and well roofs resting on nothing. Fixed in the kit: a hidden roof core under the tile courses, king posts and gable rafters on the well, and a bell beam carried into the piers.

**From the RIVALS maps:** nothing used. The own kit covered every need; the candidates above stay available.

| Check | Result |
|---|---|
| Z-fight (`Audit.luau`) | **0** (from 1,104 on the first build: cornice rings and gable ends sharing planes, stacked bands, neighbours at equal heights) |
| Floating (`FloatAudit.luau`) | **0** |
| Coincident slopes (`SlopeAudit.luau`) | **0** |
| Reach (`ReachCheck.luau`) | spawn → own hill piazza 91 studs (4.3 s), own terrace 88 (4.2 s), enemy terrace 181, enemy spawn 214 (10.2 s), A and B alike. Nothing above the terrace landing walls (+15) is reachable. |
| Roofs out of play | The first check found a route: loggia stair → terrace balustrade → roof hut → house bridges → every roof. Fixed with: rail guards (invisible, shots pass) over the terrace balustrades, the roof hut raised, a blocker over the kiosk roof and one on the fountain's top. |
| Playtest | `LockMap = OldTown4`: loads in a 2v2 with bots, lighting applied, no errors |
| Layout numbers | as layout v2 (0 pinches, first sight 3.8 s, longest line 224) |

**Waiting on the owner:**
- play it, especially the loggia terrace and the hill fights;
- **save the match place.**

Studio's own Lighting properties (ClockTime etc.) were changed for preview captures. Every map applies its own lighting on load, so match play doesn't use them.
