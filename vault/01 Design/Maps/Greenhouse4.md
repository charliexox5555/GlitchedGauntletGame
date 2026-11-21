# Greenhouse4 (Greenhouse remade)

**Status (2026-11-21): built v1, build checks at 0 / 0 / 0, in rotation** (shown as **GREENHOUSE**, regular, 1v1-2v2). Map 2 of the [lineup round 2](Map%20Lineup%202026-11-21.md) run. The owner was away and waived per-map approval, so the concept round was self-reviewed (layout checks, Blender close-ups); the ChatGPT prompts are below for later. **Save the match place.**

| Overview | From the gallery (+10) | Spawn court |
|---|---|---|
| ![overview](../../02%20Art/References/maps/greenhouse4/build-overview.jpg) | ![gallery](../../02%20Art/References/maps/greenhouse4/build-gallery.jpg) | ![spawn](../../02%20Art/References/maps/greenhouse4/build-spawn.jpg) |

## What the old maps taught
- **Greenhouse3** was pulled 2026-11-20 with the overnight maps: curved shapes, plain ground, no world round it. **Greenhouse / Greenhouse2** stay as theme references only.
- **Kept:** glass and white iron, planting beds as cover, a pond in the middle.
- **New:** every curve is flat plates (hipped glass roof, octagonal lantern, octagonal pond), textured ground everywhere (lawn, gravel, quarry tiles, paving), and a walled garden with a park and a town round it.

## Reference board (self-reviewed, owner away)
- **RIVALS Studio / Museum** (read-only, [Maps and Lobby](../../03%20Research/Rivals%20Reference/Maps%20and%20Lobby.md)): one big readable hall in the middle with a raised gallery, a few doors in, outdoor lanes on the flanks. Taken: the layout idea and the plant meshes listed below. Not copied: no RIVALS scripts, nothing with a logo.
- **Victorian palm houses** (general knowledge): white-painted cast iron, glass on a stone dwarf wall, a hipped glass roof with a lantern, a lily pond, a brick boiler house with a tall chimney, a potting shed.

## Layout v1 (`python tools/maps/greenhouse4_layout.py`)
![layout](../../02%20Art/References/maps/greenhouse4/greenhouse4-layout.png)

140 × 196, 180° symmetric, team A at +Z.
- **The Palm House (middle, 88 × 72):**
  - the **lily pond** (octagon, 26 across, wade-in at -1.5) with an **island and a tall palm** (the landmark, under the lantern);
  - four raised **planting beds** and a **rockery** inside each grand door (it breaks the door-to-door line);
  - an **iron gallery at +10** along both side walls on cast-iron columns, with four iron stairs (each team has one to each gallery, at its own end);
  - doors: three in each end wall (a 12-wide grand door and two 7-wide side doors) and two in each side wall, under the galleries.
- **Each half:**
  - a paved apron with flower borders;
  - a gravel **parterre**: lawn panels with low box hedges (shoot over), flower beds, urns, two clipped topiary, a sundial bed;
  - the brick **potting house** (the spawn baffle) with team-colour awnings;
  - the paved **spawn court** with palms in Versailles tubs, benches and lamps.
- **Flanks** (180° turned between the halves):
  - the team's **Fern House** (a smaller glass hall, an indoor lane with a staging bench and fern beds);
  - an open walk with the **boiler house** (its chimney a landmark per side), a garden shed, a U-shaped yew alcove round a bench and a raised **rock garden (+4)** with steps and rails.

| Check | v1 |
|---|---|
| Spawn gap / longest line | 178 / 188 (1.06 of the gap, 0 rays over the target) |
| Pinches | **0** |
| Spawn sees spawn / enemy half sees a spawn | never / 0.0% |
| First sight | **3.2 s** |
| Sprint to the centre / enemy spawn | 3.8 s / 8.7 s |
| Heights | pond -1.5, ground 0, rock garden +4 (steps + climb), galleries +10 (2 stairs each); roofs, beds, hedges and huts out of reach (roof guards) |

## Build v1 (2026-11-21)
Built in the match place at **(6000, 200, 40000)** (`Workspace.Greenhouse4`) by `tools/studio/maps/Greenhouse4/Build.luau` (layout rows; the A half turned 180° for B). About 3,150 parts. Rojo wasn't connected, so the builder and the audit tools ran as ModuleScripts pasted into ServerStorage through the Studio MCP (`GH4_*`, removed afterwards); the committed file builds the same thing.

**Materials** (Parts with soft MaterialVariants, colour maps only, no normal maps):
- new: `G4_Lawn` (soft mowing stripes), `G4_Gravel`, `G4_Tile` (two-tone quarry tiles), made by `tools/textures/make_greenhouse4_textures.py`;
- reused colour maps: `G4_Brick`, `G4_Stone`, `G4_Paving`, `G4_Slate`, `G4_Plate`.

**Glass walls:** one routine (`wall()`) for every glass run: a stone base course, dwarf wall and sill; glass bays between white iron mullions; transoms; an iron wall plate and gutter. Doors get iron jambs, a door head and a stone threshold; the grand doors a pediment with a keystone. Corner piers hide the corner joins. The glass collides and blocks shots (Transparency 0.6, so sightlines still read).

**Team colours:** A has coral flowers and red doors and awnings; B has violet flowers and plum doors and awnings.

**Kit (`tools/blender/maps_greenhouse4/`, 19 pieces, 37.7k tris, asset 111240674136657, `ServerStorage.MapKit.Greenhouse4`):**
- **Glass structure:** G4PalmRoof (hipped glass roof, rafters, purlins, hip ribs, lead curb), G4Lantern (octagonal drum, three-tier faceted dome, gilt finial), G4FernRoof (gabled glass roof with ridge cresting).
- **Ironwork:** G4Column (octagonal shaft, collar, capital, brackets), G4Rail4 + G4Post (lattice balustrade, rail top 3.29, jumpable), G4Stair10 (iron stair, 10 over 18), G4Gate (double gates between stone piers).
- **Water:** G4Pond (kerb, coping, lining, water, island), G4LilyPad, G4Lily.
- **Garden props:** G4Tub (Versailles planter), G4Bench, G4Urn, G4Sundial, G4LampPost, G4PotStack, G4Barrow, G4PottingBench.
- **Also used:** the sash window from the Rooftops4 kit (`R4Window`).

Close-ups: [kit sheet](../../02%20Art/References/maps/greenhouse4/kit-sheet.jpg). Every round form is flat plates (octagon columns and finials, a 12-facet urn, an octagonal dome); nothing round.

**Plants from the RIVALS maps** (owner 2026-11-21: map meshes allowed, no logos; copied into `ServerStorage.MapKit.Greenhouse4Rivals`, squared to the world axes, no scripts):

| Ours | RIVALS source |
|---|---|
| G4R_Palm | Studio map, `Palm Tree` (Base, Trunk, Leaf, Leaf_Bot) |
| G4R_Bush01a-e | Studio map, `Meshes/Bush_01a`-`e` |
| G4R_Topiary | BigMaps (Big Crossroads), `Meshes/PlanterHedge_06a` |
| G4R_Hedge01a / 02a / 03a / 04a / 05b | BigMaps, `Meshes/PlanterHedge_01a` … `_05b` |
| G4R_Pine | Legacy Docks, `Pine` (park, past the walls) |
| G4R_PineFar | Graveyard, `LOD Pine` (snow layer removed; far park) |

The box hedges, the yew alcove and the flower borders are LeafyGrass Parts (square-cut, a soft top course). No low-poly trees or bushes in play.

**The world:** a brick garden wall with piers and urns on the bounds line, closed iron gates in each back wall, a park with gravel avenues and pines, and a row of brick town houses with slate roofs. Late-morning light (authored data **421** map / **422** lighting): ClockTime 10.6, warm sun, soft green haze.

**Collision:** masses and glass collide. Beds, hedges, urns, tubs, topiary and every roof have invisible collision plus a roof guard (`MapBlockers`, shots pass), so nobody stands on a plant or a roof. Railings have hop-over strips only (owner 2026-11-21: railings jumpable). Stairs have wedge colliders.

## Chunk review (owner process, 2026-11-21)
After the owner's look at Rooftops4 ("go in chunks ... so we don't have to fix them later"), the build was reviewed area by area from close captures at player height (eye about 5), and each area was fixed before the next.

| Chunk | Close captures | Found and fixed |
|---|---|---|
| 1. Palm House | [stair](../../02%20Art/References/maps/greenhouse4/chunk1-stair.jpg), [under the gallery](../../02%20Art/References/maps/greenhouse4/chunk1-under-gallery.jpg), grand door, gallery | Door reveals, jambs, columns, joists, stair and pond kerb clean. The RIVALS bush meshes sat at ±45-135° inside their models (beds and rockery hedges ran the wrong way): squared to the world axes in the library. |
| 2. Parterre, potting house, spawn court | [parterre](../../02%20Art/References/maps/greenhouse4/chunk2-parterre.jpg), [border](../../02%20Art/References/maps/greenhouse4/chunk2-border.jpg) | Gravel read as a plain pale floor (warmer `C2AE8A` now, distinct from the paving). Flower borders read as red bricks: now one continuous green shrub bed with flowering clumps of varied width on top. Lamp lenses clipped to white: warm `B09270`. |
| 3. East flank | [yew alcove](../../02%20Art/References/maps/greenhouse4/chunk3-yew-alcove.jpg), [rock garden](../../02%20Art/References/maps/greenhouse4/chunk3-rock-garden.jpg) | The yew alcove was a bare dark cube: now a U of clipped yew round the bench. The rock garden's retaining wall was a bare block: a base course and a string course added. The boiler house's blank south face got a sash window. |
| 4. Fern House, west flank | [Fern House](../../02%20Art/References/maps/greenhouse4/chunk4-fern-house.jpg) | Clean (tile floor, beds, staging bench with pots, doors). |
| 5. Edges, background | [overview](../../02%20Art/References/maps/greenhouse4/build-overview.jpg) | Garden wall and gates clean. Park pines were too big and crowded the walls: scaled down (0.42-0.57). Background stays simple (owner: lower priority). |

## Polish pass (2026-11-21, owner feedback)
Owner: "it's good ... a really good looking map", but some parts don't line up (the doorstep), the bench's iron arms don't line up, some bushes sit over gaps, and the bush texture is "a little bit too realistic". Fixed:
- **Foliage:** the RIVALS bushes use a stylised foliage MaterialVariant (`PineFoliage_01a`) that our place didn't have, so they fell back to Roblox's realistic LeafyGrass leaf litter. Its maps are now our `G4_Foliage` (LeafyGrass base); every plant mesh, LeafyGrass hedge, yew and flower bed uses it: soft, calm green, like RIVALS. ([foliage](../../02%20Art/References/maps/greenhouse4/polish-foliage.jpg))
- **Doorsteps:** each house door's step is as wide as its stone surround, and the leaf and surround stand on it, proud of the base course (the base course used to cross the bottom of the door). The Palm House thresholds run jamb to jamb, as deep as the base course. ([door](../../02%20Art/References/maps/greenhouse4/polish-door-step.jpg), [threshold](../../02%20Art/References/maps/greenhouse4/polish-threshold.jpg))
- **Bench:** rebuilt from Parts (one design everywhere): square cast-iron end frames (the front leg runs into the arm post, a wide armrest, the back post), a centre rail, wood slats that end inside the frames. The kit `G4Bench` is no longer used. The rock-garden bench now stands on the terrace (+4). ([bench](../../02%20Art/References/maps/greenhouse4/polish-bench.jpg))
- **Bushes over gaps:** the island planting sits inside the island kerb ([island](../../02%20Art/References/maps/greenhouse4/polish-island.jpg)); the topiary plinths are as wide as the topiary; the rock-garden shrubs moved off the rail line.
- Audits after the pass: **0 / 0 / 0**.

## Checks (owner 2026-11-21: build checks only)
| Check | Result |
|---|---|
| Z-fight (`Audit.luau`) | **0** (first build 167: base course / dwarf wall / sill ends meeting at the door reveals, rail runs overlapping at posts, wall plinths, lily pads, gable and pediment wedge pairs, a few skin edges; all fixed at the source) |
| Floating (`FloatAudit.luau`) | **0** |
| Coincident slopes (`SlopeAudit.luau`) | **0** (202 slopes / rotated parts) |
| After the chunk fixes | re-run: **0 / 0 / 0** |
| Note | 15-17 RIVALS meshes can't be read as EditableMesh, so the audits test them as boxes |

## ChatGPT concept prompts (for the owner later)
1. *Overview:* "Stylised but grounded Roblox shooter map, three-quarter aerial view, late morning. A Victorian walled garden with a large white cast-iron and glass palm house in the middle: a hipped glass roof with an octagonal glass lantern, glass walls on a honey-stone dwarf wall, white iron mullions. Inside, a terracotta quarry-tile floor, an octagonal lily pond with a palm on its island, raised stone planting beds, an iron gallery along both sides. Outside, gravel parterres with lawn panels, low clipped box hedges, coral flower beds, stone urns and topiary; a red-brick potting shed with a striped awning; a smaller fern house; a brick boiler house with a tall chimney; a raised rock garden with white railings. Red-brick garden walls with piers, a park with pines and a row of brick town houses beyond. Blocky, crisp, faceted shapes, no round curves, RIVALS / Valorant readability."
2. *Player view inside:* "First-person view inside a Victorian glass palm house: terracotta checker tiles, a lily pond with lily pads and pink lilies, a tall palm under an octagonal glass lantern, raised stone beds with clipped shrubs, white cast-iron columns carrying an iron gallery with lattice railings, an iron stair up to it, sunlight through the glass roof. Crisp stylised Roblox look."
3. *From the gallery:* "View from a white iron gallery 10 studs up across a glass palm house: palms, the lily pond, clipped shrubs in stone beds, the far gallery and stairs, the garden and red-brick walls outside through the glass."

## Waiting on the owner
- Play it: the gallery fights, the pond, the grand doors, the Fern House lane, the rock garden.
- **Save the match place** (it holds the map, both kit folders and the new MaterialVariants).
- Rojo wasn't connected: the Studio copies of `Config/Match`, `Config/Ambience` and `AssetData/MatchMaps` were edited to match the repo.
