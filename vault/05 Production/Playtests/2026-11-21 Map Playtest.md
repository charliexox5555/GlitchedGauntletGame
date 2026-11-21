# Map playtest (owner, 2026-11-21)

The owner played Wharf, Snowpeak4, Metro4, Arena and Big Arena after the 2026-11-20/21 map builds.

| Map | Owner | Plan |
|---|---|---|
| [Wharf](../../01%20Design/Maps/Wharf.md) | "Solid", just audit for glitching and floating parts | re-run the overlap and floating audits on the built map, plus a close-up capture sweep for what the audits can't see (mesh-on-part overlaps, gaps) |
| [Snowpeak4](../../01%20Design/Maps/Snowpeak4.md) | Good; needs **more character**; check glitching and misaligned parts. **The skis are placeholder bricks** ("we don't have to model skis, but placeholder bricks ruin the map") | replace every placeholder-brick prop with a real one (ski rack with modelled skis and poles, sleds); a character pass (story groups, lamps, signage icons, lived-in details); audits + alignment sweep |
| [Metro4](../../01%20Design/Maps/Metro4.md) | Same as the others; the big one is the **footbridge stair railing**: it isn't attached (the handrail stops in the air beside the parapet) | rail ends land in newel posts at the top and bottom, the top newel ties into the parapet; audit sweep |
| [Arena](../../01%20Design/Maps/Arena.md) | Good, but needs **more levels** (high ground) | add planned high ground in the plain RIVALS-parts style (5-stud module, two greys, grid), layout checks for sightlines and jumps |
| Big Arena | Same as Arena | same |

**Rule from this round:** no placeholder-brick props anywhere (a coloured box standing in for an object). If a thing is shown, it is built as the thing (it can stay simple, but it has its real parts and shape).

Next after this round: a new **Old Town** remade with our own ideas, based on OldTown2.

Screenshots: `vault/02 Art/References/maps/metro4/playtest-2026-11-21-railing.png`, `vault/02 Art/References/maps/snowpeak4/playtest-2026-11-21-skis.png`.

## Results (2026-11-21)
- **Audits on every played map, plus a new check.** The box-face audit (`Audit.luau`) only compares faces that lie on box planes, so a new **`tools/studio/maps/SlopeAudit.luau`** probes every WedgePart slope and every face of a rotated Part for a coincident surface (rays from 0.4 outside, everything else made queryable for the run; proven on a test pair before use).
  - **Wharf, Metro4, Snowpeak4, Arena:** 0 z-fighting, 0 floating, 0 coincident slopes.
  - **Big Arena:** had **21 real overlaps the old check missed** (the 12-sided walls at the mitres, the walls on the floor, the pylon in the plinth). Fixed with the audit's fix mode (the lesser face pulled back 0.04): now 0 / 0 / 0.
  - Play loads the Workspace models directly (no stale copies in `ServerStorage.Maps`).
  - Removed `Workspace.ScaleDummies` (7 R15 scale dummies left from the Arena build that also showed in play).
- **Metro4 (v5):** both stair handrails now run newel to newel.
  - The footbridge stair's top newel stands against the bridge parapet's end and the deck edge.
  - The hall stair's top newel stands on the top tread.
  - The bottom newels stand on the floor, and the posts reach the rail.

  Audits 0 / 0. `metro4-v5-railing.jpg`.
- **Snowpeak4 (character pass):** new Blender props in the Snowpeak4 kit (`tools/blender/maps_snowpeak4/snowpeak4_props.py`, modelled with the snowcat's hard-surface helpers):
  - a **ski rack**: a timber trestle rack with a notched bar and four pairs of modelled skis (curled tips, toe and heel bindings on the top sheet, a stripe) resting on the bar, tails on the snow, plus poles with grips and baskets;
  - **toboggans**, stacked crosswise;
  - **lantern posts** (lit cores);
  - a **trail sign** with the ski-run icons (green circle, blue square, black diamond; no text);
  - **benches** with snow, on the lodge deck;
  - a **fire pit**, v2 after your note on v1: half-buried field stones packed in a ring with snow on top, an ash bed sunk into the snow, six bark logs in a teepee standing on the ash and crossing at the top, cut ends, charred logs, embers, a real fire particle effect, smoke and a warm light.

  Placed in the map: lamp posts on three routes per half, the trail sign by the spawn, the fire pit west of the lodge porch. Dressing:
  - icicles under the lodge and warming hut eaves;
  - warm string lights along the lodge deck rail and over the porch;
  - trodden-snow paths from the spawn to the lodge and the station;
  - chimney and stovepipe smoke;
  - light snowfall.

  Layout re-checked: 0 pinches, first sight 3.1 s. Audits 0 / 0 / 0. Your note on the skis floating in v1 is fixed: they lean onto the bar, they don't stand in front of it. Captures: `snowpeak4-v2-skirack.jpg`, `snowpeak4-v2-lodge-front.jpg`, `kit-skirack / -sled / -lamppost / -trailsign / -bench / -firepit.png`.
- **Arena + Big Arena (v3, more levels):** new +7 platforms, each with a 3-high parapet on the enemy side and a +3.5 step on your own side, all on the 5-stud grid. Arena's side block became one per team. Big Arena's left and right blocks became two more per team, on top of its +7 deck and +14 tower. Built by `tools/studio/maps/Arena/HighGround.luau` as clones of the maps' own parts (same two greys, the grid texture lines up). Layout checks: 0 pinches, spawns hidden; first sight is unchanged (Arena 2.6 s, Big Arena 4.8 s). A raised +5 centre stage was tried and dropped: it sat in the 4-6 dead band and pinched the angled slab. `arena-v3-side-platform.jpg`.
