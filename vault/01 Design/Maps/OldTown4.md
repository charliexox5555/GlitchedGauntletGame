# OldTown4 (Old Town remade): concept round

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

## Owner decisions needed
1. **Direction:** A (Canale) or B (Collina), or a mix (for example the hill with a bridge).
2. **Size:** large 2v2-3v3 (planned) or regular 1v1-2v2.
3. **Concept images:** run the prompts above (or have me adjust them first), then approve one image per view before the build.
