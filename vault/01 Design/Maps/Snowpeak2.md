# Snowpeak2: Snowpeak Lodge rebuilt to the standard (2026-11-06)

A new version of [Snowpeak Lodge](Snowpeak%20Lodge.md) built to the [Map Quality Standard](Map%20Quality%20Standard.md), from the concepts the core chat delivered: [01 overview](../../../art-source/maps/Snowpeak2/concepts/01-overview.png), [02 hero](../../../art-source/maps/Snowpeak2/concepts/02-hero.png) and [03 kit sheet](../../../art-source/maps/Snowpeak2/concepts/03-kit-sheet.png). The user approves the finished map; the concepts are quality references.

- **Map id:** `Snowpeak2`, match place, origin **(-3000, 200, -1500)** (free: the nearest maps are Dockyard2 at (-3000, 200, 0) and Snowpeak at (-1500, 200, -1500)).
- **ForceMap only.** It isn't in the pool until the user approves it.
- **Old map untouched:** `Snowpeak` and `tools/studio/maps/Snowpeak/Art.luau` (the user's uncommitted edits) aren't modified.
- **Scripts:**
  - layout: `tools/maps/snowpeak2_layout.py`
  - palette: `tools/maps/snowpeak2_style.py`
  - signs: `tools/maps/snowpeak2_signs.py`
  - textures: `tools/textures/make_snowpeak2_textures.py`
  - kit and placements: `tools/blender/build_map_kit_snowpeak2.py`
  - Studio: `tools/studio/maps/Snowpeak2/{Greybox, Art, Lighting}.luau`
- **Shots:** `vault/02 Art/References/maps/snowpeak2/`.

![Hero concept](../../../art-source/maps/Snowpeak2/concepts/02-hero.png)

## Identity
**"A warm timber lodge in a cold, bright saddle."**

| | |
|---|---|
| Landmark | The lodge, with its stone chimney rising to 34, the tallest thing on the field (eaves 20, station decks 10). The gondola cables climbing off the map mark the stations. |
| Heights | Snow 0; lofts, balconies and station decks at 10; roofs 20–30 (Updraft only). |
| Zone tone | Warm inside (timber, amber windows, fire) against cold outside (blue-white snow, blue shade). End paint on the patrol huts and stations: B blue `3D63A8`, A gold `C9962E`. Team colours stay in the UI. |
| Hero accent | The red gondola cabins (`A8262E`), far from team orange-red. |
| Story groups | The lodge lounge (fire, sofa, bar, boot room); the gondola stations (cabin parked on the rail, bullwheel); the pond with its skate hut; the ski-patrol hut; woodsheds and log piles; the snowcat. |

## Layout (unchanged)
`snowpeak2_layout.py` is a copy of `snowpeak_layout.py` with new output paths. The plan, numbers and checks are in [Snowpeak Lodge → Layout](Snowpeak%20Lodge.md).

## Palette (single table; `tools/maps/snowpeak2_style.py`)
| Slot | Roles | Material / variant |
|---|---|---|
| Ground | Snow `EEF2F8`, shade `DCE4EE`; terrace stone `8E8578`; ice `B9D6E6` | Snow / `Snow2_Snow`; Cobblestone / `Snow2_Stone`; Ice |
| Walls | Timber `8A5E3C`, dark `5A3C28`, light `A8805A`; shutters `4A6650` | WoodPlanks / `Snow2_Timber` |
| Stone | Stone `9A9388`, dark `6E6962` | Cobblestone / `Snow2_Stone` |
| Roofs | Standing seam `4A535E` under snow | Plastic / `Snow2_Roof` (no sky mirror) |
| Decks and floors | Oak `9A7450` | WoodPlanks / `Snow2_Plank` |
| Rock | `7C838C`, dark `5E656E` | Rock / `Snow2_Rock` |
| Steel | `5E656D`, dark `3E444B` | Plastic (no Roblox Metal on paint) |
| Accent | Gondola red `A8262E`; brass `A8864A` | SmoothPlastic; Metal |
| Glow | Warm `B07A48`, fire `C0602C`, amber `B8862E` | Neon (dark values: Neon brightens hugely, as calibrated on Bunker2) |
| Icicles | `C9DDEA` | Ice |

## What changed against Snowpeak
- **Our own textures:** six variants at 512 (timber boards with seams and grain, coursed fieldstone, snow with drift and sparkle, standing-seam roof, granite, deck planks), tinted by role. They replace the built-in Roblox materials.
- **Warm windows:** amber Neon replaces near-white. In the old map the windows read as blown-out white squares.
- **Icicles** along the lodge eaves (as in the concept).
- **Signs:** the lodge, station and patrol names are now rendered-font decals, replacing SurfaceGui text. Rule: no GUI or part text.
- **Lighting:** a brighter, warmer morning than the old map; the v4 complaint was "too dark".

## Results
Installed in the match place, ForceMap only. **The place needs saving (Ctrl+S); the core chat saves it.**

**Kit and checks:**
- 30 pieces, 550 MeshParts, about 80k triangles for the whole map.
- Kit coplanar 0 (80k triangles); Studio `Audit.luau` 0 pairs; `FloatAudit` 0 floating groups (569 parts).
- Install fixes for 7 groups the old kit left floating:
  - stair rail posts now reach the stringers;
  - the porch lanterns have brackets to the porch walls;
  - the station lamps are set into the roof slab;
  - the bar foot rail stands on posts.

**Rounds and blind scores** (3 fresh reviewers each; median):

| Round | Changes | Scores | Median |
|---|---|---|---|
| r1 | First install: our textures, sign decals, icicles, amber windows (they read saturated yellow, then red). | 5.00 / 5.00 / 4.58 | **5.00** |
| r2 | Closed a see-through notch in the ridge over each spawn alcove: the "sky rectangle" every reviewer named, also in the old map. Desaturated warm window Neon (`8C7660`). Half-bright interior lights (the lounge blew out orange). | 4.58 / 4.58 / 5.00 | **4.58** |

**Consistent asks:**
- the gondola stations are plain grey boxes (the concept's are stone and steel with a bullwheel);
- the backdrop styles clash (faceted peaks next to noise-textured flat cliff faces);
- the snowcat, rocks and snow piles read as cubes;
- the snowfield is empty, with no paths or cover rhythm;
- flat noon light;
- the B spawn looks straight at the patrol hut's wall.

The thin cyan "spike" behind the lodge is a ridge crest of the backdrop seen edge-on. It isn't a stray part; there's no sliver in the mesh.
