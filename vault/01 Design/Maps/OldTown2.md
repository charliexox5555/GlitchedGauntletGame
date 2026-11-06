# OldTown2 (new version of Old Town)

Old Town rebuilt to the [Map Quality Standard](Map%20Quality%20Standard.md) by lane F on the night of 2026-11-06. It keeps [Old Town](Old%20Town.md)'s layout, lanes and measured numbers. The old map stays untouched: its files, its Studio model `Workspace.OldTown`, and its Config rows.

- **Map id:** `OldTown2`.
- **Origin:** (3000, 200, -1500). Checked free in the match place on 2026-11-06; Rooftops2 ends near z -420.
- **How to view it:** ForceMap only (`workspace:SetAttribute("ForceMap", "OldTown2")`). There's no `Config/Match` change until the user approves.
- **Status (05:30): stopped at 6.3 by the stop rule (rounds 6.3 → 6.3 → 6.3). It is a draft below the 8.5 bar.** Audits are 0/0. See "Stopped at 6.3" at the end.

## Calls made without the user (asleep; decided by the standard)
| Call | Why |
|---|---|
| Model before the board is approved | Core chat's instruction. The concepts and the board stay here for the morning. |
| Keep Blue (B) / Green (A) as the side accents, on shutters, awnings, banners and doors | The concept uses them, and they're far from team cyan / orange-red. The landmark is the brick clock tower: terracotta and brick, no blue or green. |
| Procedural textures (`tools/textures/make_oldtown2_textures.py`) | No Codex trim sheet tonight. They follow the concept's swatches, are near-white and tintable, and fit the 6-variant budget. |
| Fork the Old Town kit (61 pieces), then raise it | The layout and every opening match already, and the old map passed 0 z-fighting. The gap to the bar is surface quality, colour, light and the heroes, so that's where the work goes. |

## Identity brief
- **Sentence:** *A warm late afternoon on the Piazza of Sant'Orsola: cream, ochre and rose stucco over stone arcades, terracotta roofs, the fountain splashing in the middle and the brick clock tower over the east roofs.*
- **Story groups:**
  1. **Market packing up:** a striped stall, half-loaded crates on a hand cart, a fallen crate by the stall.
  2. **The cafe terrace:** bistro tables, umbrellas and potted lavender above the east arcade.
  3. **Laundry day in the alleys:** washing lines between the houses, a basket under them.
- **Not this:**
  - sepia medieval grime;
  - clutter that hides players;
  - smooth plastic boxes;
  - part-built letters;
  - cartoon wonky houses;
  - team colours;
  - real brands.

## References (third-party, never committed)
Sources, linked as in [Old Town §2](Old%20Town.md#2-references):
- Valorant: Ascent;
- CS2: Inferno;
- the Plaza Mayor in Salamanca;
- Piazza del Campo and the Torre del Mangia in Siena;
- Venice's sotoporteghi.

The concepts are in `art-source/maps/OldTown2/concepts/` (01-overview, 02-hero, 03-kit-sheet).

LihFolk notes:
- [Level Design Principles](../../LihFolk/33%20Level%20Design/Level%20Design%20Principles%20-%20Flow%20Sightlines%20and%20Landmarks.md)
- [World Composition and Set Dressing](../../LihFolk/06%20World%20Building%20and%20Art/World%20Composition%20and%20Set%20Dressing%20-%20Designed%2C%20Not%20Scattered.md)
- [Zone and Biome Art Direction](../../LihFolk/06%20World%20Building%20and%20Art/Zone%20and%20Biome%20Art%20Direction.md)
- [Colour Scripts and Value Structure](../../LihFolk/54%20Untextured%20Stylised%20Modelling/Colour%20Scripts%20and%20Value%20Structure%20for%20Untextured%20Art.md)
- [Stylized Lighting Recipes](../../LihFolk/07%20Lighting%20VFX%20and%20Audio/Stylized%20Lighting%20Recipes.md) (golden hour §3.3)
- [Textures Decals and Texture Memory](../../LihFolk/06%20World%20Building%20and%20Art/Textures%20Decals%20and%20Texture%20Memory.md)

## Layout (kept)
`tools/maps/oldtown2_layout.py --write` re-runs every Old Town check on the same numbers and writes `tools/studio/maps/OldTown2/Greybox.luau` and `Art.luau` at the new origin.

**Heights:** ground 0, terraces 12, roofs 24–31 (not a lane), perimeter 52. The checks are unchanged:
- spawns never see each other;
- first sight comes at 4.5 s sprinting, 6.1 s walking;
- one 130-stud line per side.

## Palette (single table; `tools/maps/oldtown2_style.py`)
| Slot | Role | Colour | Surface |
|---|---|---|---|
| Walls | Stucco tones: cream / ochre / rose | `E8D6B0` / `DDB57C` / `D9A08A` | `OT2_Stucco` |
| Stone and trim | Stone (arches, cornices, quoins) | `D8C6A0` | `OT2_Ashlar` |
| Stone and trim | Plinth (bases, steps) | `BFA884` | `OT2_Ashlar` |
| Roofs | Terracotta | `B5603A` | `OT2_Terracotta` |
| Roofs | Brick (the tower) | `A65A3E` | Brick |
| Floors | Plaza and forecourt paving | `D9C7A4` | `OT2_Paving` |
| Floors | Streets and alleys | `9C8E7C` | `OT2_Cobble` |
| Timber | Wood dark / light | `6B4A2E` / `9A7550` | Wood / `OT2_Plank` |
| Iron | Ironwork | `3A3633` | SmoothPlastic, not Metal |
| Greenery | Cypress / foliage / lavender | `4E6B35` / `6B8A3F` / `8C7BB8` | |
| Water | Water | `5FA8B8` at 0.35 | Glass |
| Accents | B side blue | `2F6BB3` | shutters, awnings, banners |
| Accents | A side green | `4E8A3E` | shutters, awnings, banners |
| Glow | Lanterns | `FFD39A` | Neon |

## Lighting
The golden-hour recipe, lifted:
- sun low in the west at about 35°, so shadows run across the map toward the tower;
- Brightness 3;
- Ambient ≤ OutdoorAmbient, warm key, neutral-cool shade;
- light warm haze;
- bloom threshold 1.2 so the cream walls don't blow out.

Check with the greyscale and no-shadow tests.

## Kit
`tools/blender/build_map_kit_oldtown2.py`, forked from the Old Town kit: 61 pieces in two groups, `Structure` and `Props`.
- **Materials:** carry MaterialVariants by role (`VARIANT_OF`).
- **Hero upgrades:** done in rounds, worst first, from the reviews.

## Build and run order
Filled in as built.

## Rounds
Filled in per round.

### Round 1 (04:43)
- **Installed:** the forked kit, procedural variants, the style pass (palette remap, no Metal), lifted lighting, plain stucco, muted roofs at a smaller tile, calmer side accents.
- **Audits:** 0 z-fighting pairs (7,610 parts). Two floating groups, the well buckets; a rope now links each bucket to the windlass.
- **Blind score: 6.3** (6.3, 6.3, 6.3). Medians: W1 2, W2 1, W3 1, W4 1, W5 1, W6 1.

Low points:
- The spawn faces a blank cloister wall.
- The perimeter blocks read procedural: repeated window grids, uniform height.
- Stall boards and hedges use mixed realistic textures; the fruit reads as blocks; the cart wheel is a flat disc.
- Flat midday light with no warm practicals.

### Round 2 (05:05)
- **Props:** round fruit, spoked cart wheels.
- **Wall lanterns:** lit (warm Neon).
- **Spawn wall:** two lanterns and two banners on each cloister front wall.
- **Light:** lower sun (16.6), more haze and a warmer grade.
- **Materials:** Roblox Wood swapped for the plank variant; fabric and grass made SmoothPlastic.
- **Audits:** 0 / 0 (7,632 parts).
- **Blind score: 6.3** (6.3, 6.3, 6.3). Same medians as round 1, gain 0.

Low points:
- The heavier haze read as a sepia wash.
- The SmoothPlastic cloth and foliage read as flat slabs.
- Otherwise the same structural asks:
  - break up the perimeter blocks (heights, roof breaks, balconies, vines);
  - open the spawn view;
  - modelled cloth;
  - show the +12 terraces.

### Round 3 (staged 05:13)
- Haze back down (Density 0.22, Haze 0.9), more contrast.
- Fabric and foliage materials restored.
- **Audits:** 0 / 0 (7,632 parts).
- **Blind score: 6.3** (6.3, 6.7, 6.3). Medians: W1 2, W2 1, W3 1, W4 1, W5 1, W6 1.

### OldTown2 stopped at 6.3 (the stop rule)
| Round | 1 | 2 | 3 |
|---|---|---|---|
| Score | 6.3 | 6.3 | 6.3 |

Rounds 2 and 3 each gained 0 on the best score, so the map stops. **It is a draft below 8.5, not ready for approval.** The audits stayed at 0 / 0 every round, and the user can see it with `ForceMap = "OldTown2"`.

What holds it back (all reviewers, every round), and what would move it:
1. **W1 and W3, the perimeter blocks.** They're very tall flat stucco slabs with a repeated window grid, which reads as procedural from the overview. They also rise nearly to the tower, so the tower isn't 1.5× taller.
   - The fix: lower and vary the perimeter (heights, roof breaks, chimneys, balconies, setbacks).
   - That means editing the Old Town layout's perimeter buildings: the art and not the collision, but a large rebuild.
2. **W3, the props.**
   - The finish is mixed: flat stall boxes, smooth fruit, black café chairs, and Roblox's photo-real foliage on the hedges.
   - The fix: a stylised foliage card and modelled stall goods. Codex could make the props.
3. **W4, lighting.** Flat midday. Reviewers want the concept's golden hour: a lower warm sun and warm practicals in the arcades.
   - Round 2's lower sun with heavy haze read as a sepia wash; round 3 rolled the haze back.
   - The next try: a low sun (ClockTime about 17.2) with light haze and PointLights at the lanterns, judged in play mode.
4. **W1 and W2, the spawn view.** The cloister faces a solid wall; the layout puts the exits at the corners on purpose.
   - Opening a gate arch in the front wall would change spawn sightlines, so it's a layout call for the user.
5. **The forecourt "blank sign on an L-bracket"** is the well's windlass and bucket seen side-on. Reviewers read it as a primitive sign; a modelled well (roof, crank, rope) would fix it.

**Best shots:**
- [plaza](../../02%20Art/References/maps/oldtown2/v1-r3-plaza.jpg)
- [tower](../../02%20Art/References/maps/oldtown2/v1-r3-tower.jpg)
- [overview](../../02%20Art/References/maps/oldtown2/v1-r2-overview.jpg)
- [side-by-side](../../02%20Art/References/maps/oldtown2/v1-r3-side-by-side.jpg)

**Approval read: not ready.** It is clearly warmer and more finished than Old Town: textured stone and stucco, an octagonal fountain, a balustraded gate, lit lanterns, and 0 / 0 audits. The perimeter and prop finish keep it at 6.3.
