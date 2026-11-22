# Snowpeak4 (Snowpeak rebuilt, regular map 1v1-2v2)

Snowpeak rebuilt as the main snow map from [Snowpeak2](Snowpeak2.md)'s whole vibe. Map id `Snowpeak4`, shown as **SNOWPEAK** in the vote, in the rotation (1v1-2v2). The old `Snowpeak`, `Snowpeak2` and `Snowpeak3` models stay in the place untouched.

## Owner calls (2026-11-20)
| Call | Answer |
|---|---|
| Base | Snowpeak2 "as the main one": recreate the whole thing and its vibe (a timber ski lodge, the gondola station with red cabins, a frozen pond, the snowcat, pines, big mountains) |
| Middle | Snowpeak's middle was **"too congested"**: open it up |
| Snowcat | the old snowcat models "aren't good" → a new model. The first scripted one was rejected too ("scripted, just rounded parts"), so it was **modelled with the Blender skills** (blender-director → hard-surface / vehicle-artist) |
| Spawns | **no spawn nooks** (no indent with the blue wall): the ghost hold keeps players at the spawn |
| Mountains | good, no glitches (the Wharf exporter fixes: every face up, no loose vertices); far mountains may stay faceted |
| Greenery | not low-poly (owner, on Metro's planter): pines the RIVALS way |

## 1. RIVALS Village, measured (2026-11-20, read-only, match place `ServerStorage.MapsRivals`)
Property reads only, nothing moved or copied. 300 × 300; 2 spawns 185 apart (49, 79) / (-43, -81); the middle is an **open saddle round a raised feature** (two 110 × 168 terrain mounds and a bonfire at the centre); **two buildings per half pushed out to the sides** (66 × 60 and 55 × 50); pine groups on the flanks. Pines are a **foliage mesh in LeafyGrass** (dark green) with a **separate snow mesh in Snow** over it; planters and hedges are LeafyGrass meshes on Pavement / Concrete. What we take: the open middle with one feature, the buildings on the sides, the pine recipe.

## 2. Layout (`python tools/maps/snowpeak4_layout.py`)
Saddle 150 × 190 (x ±75, z ±95), 180° rotational symmetry, **+Z = team A**, 5 spawns a side in the open (z 85-91).

```
 z +95  ============ ridge slope behind the spawns (pines) ============
        woodshed   pines            A spawns            pines   sleds
        |          lodge stair    [ PATROL HUT ]                      crate stack (12)
 z +50  [ LODGE  ][deck +10]  ticket booth  ski rack   supply crates  stair[ STATION deck +10 ]
        |                 log pile      snowbank      steps 3.5/7          (cable out east)
 z +18          [warming hut]                  [snowcat]
 z   0  fence   ~~~~~~~~ frozen pond + rock outcrop (12) ~~~~~~~~        fence on the drop-off
        ... B's half, turned 180 degrees ...
```
Plan image: `vault/02 Art/References/maps/snowpeak4/snowpeak4-layout.png`.

| Check | Snowpeak4 | Rule / reference |
|---|---|---|
| Floor | 150 × 190 = 28,500 sq studs | Snowpeak 128 × 160; Village 300 × 300 |
| Spawn gap | 176 | regular 150-190 |
| Longest eye-height line | 208, 0% over 250 | |
| Lanes across the middle | 2 wide lanes either side of the pond rock (69 / 68 at z 0): an open middle | Snowpeak's lodge filled it |
| Pinch gaps < 6.5 | **0** | 0 |
| Spawn sees spawn | never; 8.5% of the enemy half sees a spawn point (spawns stand in the open by design) | |
| Sprint spawn → centre / enemy spawn | 3.8 s / 8.8 s | |
| First sight, head-on rush | **3.1 s** | 3-5 |
| Heights | floor 0, pond ice, low cover 3-3.5, station steps 3.5 / 7, decks **+10** (lodge deck by its stair, station deck by its stair or the steps), unclimbable: rock 12, crate stack 12, huts 9-10, lodge 20 | ≥ 3 heights |

## 3. Build
- **Kit** (`tools/blender/maps_snowpeak4/`: `snowpeak4_pieces.py`, `snowcat_model.py`, `run_snowpeak4.py` renders, `run_snowpeak4_export.py`; asset 94440665909114, `ServerStorage.MapKit.Snowpeak4`):
  - **Snowcat** (`snowcat_model.py`, ~12k tris), modelled the hard-surface way:
    - proportions first;
    - track loops with cleats and grousers, four road wheels with dished rims and bolts, a toothed sprocket and an idler;
    - a cab built as one mesh with the window faces inset into frames and the glass pushed back, a centre post and B-pillars, door seams, a stripe;
    - an engine housing with a chamfered top, louvre banks, a rear grille and an exhaust;
    - a light bar and beacon, mirrors, handrails and steps;
    - a front blade of angled moldboard plates with ribs, wings, push arms and rams;
    - a tiller with its comb;
    - angle-limited bevel modifiers, smooth shading with sharp edges over 35°, baked for export.

    Renders: `kit-snowcat.png`, `kit-snowcat-side.png`.
  - **PineA / PineB**: 9 / 7 drooping star tiers with ragged tips, a foliage mesh in LeafyGrass plus a snow mesh in Snow, box UVs.
  - **GondolaCabin**, **Bullwheel**.
  - **Outcrop / BoulderA / BoulderB**: noise-sculpted icospheres with bedding ledges, Slate with snow on the ledges. The first, jittered-cube version read as a low-poly blob and was replaced.
  - **MountainA/B/C**: snowy faceted heightfields.
- **Shared Props kit:** crates (CrateA, one style, square to the grid).
- **Builder** `tools/studio/maps/Snowpeak4/Build.luau` → `Workspace.Snowpeak4` at (6000, 200, 19000), 1,459 parts. All Parts use Snowpeak2's own textures (`Snow2_*`).
  - **Lodge:** stone base, timber walls, log corner posts, lit windows with shutters and sills, a gable roof on the true slope with snow, a ridge cap and fascia, a stone chimney, a porch.
  - **Lodge deck** (+10): on posts and joists, with a railing and a 32° stair.
  - **Gondola station:** a concrete base with a garage door, a plate deck with railings, a canopy on columns over the bullwheel, the parked cabin, cables out over the drop to a tower with cabins on the line, a 32° stair and stone steps.
  - **Smaller pieces:**
    - a warming hut;
    - the patrol hut (side-paint end boards, a shed roof, the patrol cross as an icon, no text);
    - a ticket booth and a woodshed against the fence;
    - a lumber stack, a snowbank, supply crates, a ski rack, sleds;
    - the pine clumps.
  - **World:** snow drifts against the walls, a fence on the drop-off along both long sides, a ridge slope with pines behind each spawn (no nook), a valley far below, a ring of mountains.
  - **Contract:** collision boxes plus the lodge's true gable collision and a player-only blocker over its roof; bounds with a ceiling at 45; spawns; WinnerStage; authored data 415 / 416 (KillDepth 20; ClockTime 10.2); LightingFx.

## Checks (2026-11-21)
| Check | Result |
|---|---|
| Z-fighting / floating | **0 / 0**. Before that, the first build had 120 pairs and gaps: window layers sharing faces, roof plane ends, rail corners, 0.05 gaps between stacked timber, fence posts above the slope, stair handrails crossing their posts (now seated in end posts), sleds stacked apart. The cables, the tower, the hanging cabins and the world are AllowFloat |
| Reach (`ReachCheck.luau`) | A and B alike: pond edge **80**, enemy spawn **184**, own lodge deck **47**, own station deck **66** |
| Reach fixes | The 14-run stairs were 35.5°, over the walk limit, so the decks were unreachable: both are now 16-run (32°), and the west pine clump and the woodshed moved to keep the stair foot clear. From the deck railing (13.2) you could jump onto the lodge's flat collision top at 20: it now has true gable collision plus a player-only blocker over the roof. You could also stand on the station's canopy column tops: the canopy beam and roof are now solid. **Still standable:** the deck railing tops (+3 over the decks) |
| Playtest | not run yet (owner test list below) |

Captures (`vault/02 Art/References/maps/snowpeak4/`): `snowpeak4-v1-overview / -middle / -lodge / -spawn.jpg`, kit renders `kit-*.png`.

## Character pass (2026-11-21)
After the owner's playtest ("needs more character"; "the skis are placeholder bricks"): a ski rack with modelled skis and poles, toboggans, lantern posts, a trail sign with run icons, benches on the lodge deck, a fire pit (v2 after the owner's note), icicles, string lights, trodden paths, chimney smoke and snowfall. Details and captures: [Map Playtest 2026-11-21](../../05%20Production/Playtests/2026-11-21%20Map%20Playtest.md) → Results. Layout: lamp posts and the trail sign are 1 × 1 pillars, the fire pit low cover (rows in `snowpeak4_layout.py`); still 0 pinches, first sight 3.1 s; audits 0 / 0 / 0 (slopes).

## What to test (owner)
1. Save the match place (the map, the kit and the Snow2 MaterialVariants live in it).
2. `ForceMap = Snowpeak4`, `TestMode = false`, Play (1v1 / 2v2 bots); put both back after.
3. Does the middle read open enough now (pond + rock, the snowcats and warming huts off to the sides)?
4. The snowcat up close, the pines and the rock: still anything that reads low-poly?
5. Your lodge deck (stair) and station deck (stair or steps 3.5 → 7): the views over the middle.
6. Spawn: you stand in the open behind the patrol hut (no nook); is the first fight about 3 s after the hold?

## RIVALS texture pass (2026-11-21)
The owner asked for RIVALS' textures on the built maps (they are in `MaterialService.ExtraTextures`; which ones RIVALS' maps use and how they render: [Foundry4](Foundry4.md#owner-fixes-2026-11-21-second-look)). Every surface look moved onto a RIVALS map variant; the part Material follows the variant's base. The builder applies it as a `RIVALS_REMAP` table ("Material|Variant" as built → RIVALS material and variant) right before the map is parented, so a rebuild matches the place. Glass, Neon, flat SmoothPlastic paint and LeafyGrass foliage stay as they were (no realistic foliage textures).

| Surface | RIVALS variant (base) | Was |
|---|---|---|
| Snow (parts and kit) | Snow_01a (Snow), as RIVALS Village | Snow2_Snow, plain |
| Ice | Ice_01b (Ice), as RIVALS Village | plain Ice |
| Log / timber walls | WoodPlank01a_Big (WoodPlanks), as RIVALS Village | Snow2_Timber |
| Planks, kit wood | WoodPlank01a, Wood01a | Snow2_Plank, plain |
| Concrete, plate | Concrete-01a, Diamond Plate 2022 | Wharf_Concrete, Wharf_Plate |

Rock, stone (cobble), roof and paint stay.

**Captures** (player height, the map's own lighting): [rivals-tex-village.jpg](../../02%20Art/References/maps/snowpeak4/rivals-tex-village.jpg)

**Checks** (run once after the pass): z-fight / floating / slopes **0 / 0 / 0**.

**Grade: 8.5 / 10.** Closest to RIVALS of all: the same snow, ice and log variants as RIVALS Village. Held back by the plain stone base walls (Snow2_Stone kept).
