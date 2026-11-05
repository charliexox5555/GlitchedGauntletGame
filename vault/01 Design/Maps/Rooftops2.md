# Rooftops2 (redesign of Rooftops)

The 2026-11-05 redesign of [Rooftops](Rooftops.md) in the new environment style ([Lobby Style Guide](../../02%20Art/Lobby%20Style%20Guide.md), [Art Direction](../../02%20Art/Art%20Direction.md) → direction change 2026-11-04). Same idea: a city block, two team roofs over a sunken Pit with a water-tank tower, side towers on a gangway and a plank ramp, alleys to fall into, for 1v1 and 2v2. Built next to the old map, which stays untouched. **Not in the match rotation** until the user approves the swap; in Studio set the Workspace attribute `ForceMap = "Rooftops2"`. Template: [Dockyard2](Dockyard2.md).

**Map id** `Rooftops2`. **World origin (3000, 200, 0)** (free). Taken: Whitebox (0, 200, 0), Big Whitebox (0, 200, -1500), Dockyard (-1500, 200, 0), Metro (1500, 200, 0), Old Town (0, 200, 1500), Greenhouse (1500, 200, -1500), Rooftops (1500, 200, 1500), Bunker (-1500, 200, 1500), Snowpeak (-1500, 200, -1500), Dockyard2 (-3000, 200, 0). Pipeline and rules: [Maps](00%20Maps.md), [Game Plan](../../05%20Production/Game%20Plan.md) §5 (180° symmetry, three lanes, cover 3 / 7+, no dead ends, spawns out of sight, one long sightline ~70).

**Status (2026-11-05, lane G):** built in the match place (greybox, kit asset **78737454855986**, art and lighting).
- **Audit 0** (1,431 visible parts).
- Playable with `Workspace.ForceMap = "Rooftops2"`, and **not in the rotation** (no Config change at all).
- **Blind score 8.33 / 10, below the 8.5 bar** (8 fix rounds; the stop rule was reached). §9 has every round.
- The old Rooftops is untouched.
- ⚠ The match place must be **saved (Ctrl+S)** to keep it (the core chat saves).

![Rooftops2 B main lane](../../02%20Art/References/maps/rooftops2/r5-b-main-lane.jpg)
![Rooftops2 front row](../../02%20Art/References/maps/rooftops2/r5-a-front-row.jpg)

**Why Rooftops next** (lane G's call, 2026-11-05): after Dockyard it's the map players will meet most in the core mode. It's one of the five 1v1 maps, with Whitebox, Bunker, Dockyard and Snowpeak, and RIVALS is a duel game first. It's the other dark map: blue hour, real brick, a 240-tall sign tower. That is exactly the "too tactical and realistic" look the user wants gone. Of the others, Bunker was already built in the Lobby's kit language, and Whitebox is deliberately abstract. Snowpeak has uncommitted edits by the user, so it waits for them. The large 2v2–4v4 maps (Metro, Old Town, Greenhouse) come after the duel pool.


---

## Lessons from Dockyard2 (applied from the start, so later maps start higher)
Dockyard2's blind score went 5.4 → 5.4 → 6.7 → 8.75 ([Dockyard2](Dockyard2.md) → Scoring). What moved it, as rules for every redesigned map:
1. **The spawn view must show the landmark and the way out.** A blank wall in front of the spawn cost composition and navigation the most. Make the spawn screen low enough on one side to see the landmark (check spawn safety in the layout script), and put a **framed sign** on it that names the base and the routes each way ("DOCK A ◄ GREEN  RED ►"; here "ROOF A/B ◄ EAST  WEST ►").
2. **Paint the routes.** Lane or side words on the floor where routes leave the base and where they cross the middle, named by where they *land* after the 180° turn (Dockyard2's first try mirrored them into the wrong lanes). Chevrons from the spawn round the screen.
3. **Give the middle a ground-level landmark** with a name plate (Dockyard2's white reefers with "CRANE"). Here it's the cobalt water tank on the lift tower, plus the billboards.
4. **Never put painted surfaces on Roblox Metal.** It mirrors the sky, so blue paint goes royal blue. Use clean SmoothPlastic paint, with the geometry (ribs, rails, frames) carrying the detail. Keep the Lobby's textures for big calm surfaces only (plaster, roof tiles), and check in Studio, not just Blender.
5. **Warm practical light that shows in captures:** Neon glow strips on lamps and interiors. PointLights don't render in edit-mode MCP captures, which the reviewers judge from.
6. **Warm sun against neutral-cool shade, haze for depth, lower grade contrast.** A blue ambient crushes blue paint in shade, and "tuned, not striking" was the last thing holding the score down.
7. **Dress every face the overview sees** (end-wall backs, far quays). Reviewers mark down raw slabs even outside the play space.

## 1. What's wrong with the old Rooftops
From its note, its renders and a rerun of `tools/maps/rooftops_layout.py` (the SVG was restored afterwards, nothing in the repo changed).

| Problem | Evidence | Fix in Rooftops2 |
|---|---|---|
| **Too dark, too realistic.** Blue hour (ClockTime 18.45), real brick, a lit-window rhythm, a 240-tall HOTEL sign tower. The note scores its own lighting 1/2 and detail 1/2 and admits cover only reads because the roofs are darker. | [Rooftops](Rooftops.md) §4 look and quality score; [overview](../../02%20Art/References/maps/rooftops/rooftops-preview-overview.jpg) | Golden afternoon, stylized plaster and tile, lighting does the contrast (§4) |
| **First sight at 1.7 s sprinting, 2.4 s walking**; the teams meet at 3.6 s. A front-edge look across a 40-stud Pit; spawn to the Pit is only 3.0 s. | script: first sight, routes | Change 1. Target first sight >= 3.0 s, meet >= 4.5 s |
| **Long diagonals.** 8.5% of visible pairs over 70 studs (Whitebox: 6.4%), 0.9% over 100, longest **128** ((-44,40) to (34,-62)). Game Plan §5 allows one ~70 line. | script: sightlines | Change 2. Target <= 100 and over-70 <= 6.4% |
| **Open gangways.** Furthest distance to full cover is **20** at (-44,12); average 6.9. | script: cover spread | Change 3. Target worst <= 15 |
| **The Pit is the slow route.** Spawn to spawn: 160 direct, 162 via the east tower, 164 via the west tower, **173 via the Pit** (7.9 s vs 7.3 s sprinting, +0.6 s). The centre should be the fast road. | script: routes | Change 4. Target all three within 0.5 s |
| **High-perch pile-up, unmeasured.** Ten Updraft-only tops (roof AC +8, tank house +8, lift tower +8, cooling tower +8, stair hut +9, lift house +10, flue +10, penthouse +11, tower hut +17, tank +22) and the script prints no perch share. | script: heights | Change 5: add the perch-share check (Dockyard2 has one), cap the best perch ~45% |
| **A hard fall.** Kill height y -24: 0.49 s from a roof, so a missed jump costs the life with no warning. | script: heights | Change 6: keep the fall (it is the map's idea) but make drop edges read |
| **Heavy kit for a small map.** 32 pieces, 828 MeshParts, 177k triangles; 72-tall facade columns with a window every 12 studs; 408 greybox Parts. | [Rooftops](Rooftops.md) §4 budget | Chunkier facades, fewer and bigger windows. Target <= 600 MeshParts, <= 120k triangles |

What the old map gets right and Rooftops2 keeps: 180° symmetry, three walkable layers 8 apart (Pit -8, roofs 0, towers +8), three ways across (catwalk, Pit, plank), the water tank tower as the hero landmark, flues that break alley lines, 0 unreachable cells, spawn safety (spawn sees spawn: never; 0% / 0% perches), z-fighting audit at 0.

## 2. References
Images of other games and other people's photos stay out of the repo (links only). Fetched on 2026-11-05; fandom and strategywiki block bots (403), marked "bot-blocked" where used (it came up in search).

| Reference | What to take |
|---|---|
| [Valorant Sunset (esports.net)](https://www.esports.net/news/valorant/sunset-map/) | A sunlit Los Angeles map with a wide mid and narrow close-quarters paths: warm, saturated light on pale walls. Our mood target, not our layout |
| [Valorant Ascent (Beebom)](https://beebom.com/valorant-ascent-map-guide), [Ascent (esports.net)](https://www.esports.net/wiki/guides/valorant-ascent-map/) | A bright stylized town of rooftops and a courtyard: three lanes, a wide centre, long lines closed by doors. Named places ("Wine", "Tree", "Heaven") are the callout model |
| [Valorant Bind (Beebom)](https://beebom.com/valorant-bind-map-guide) | Warm sandy plaster, colour-blocked trims, simple shapes: a stylized map that stays readable without fine detail |
| [RIVALS maps list (Bloxodes)](https://bloxodes.com/wiki/rivals/maps) | RIVALS has **no rooftop map** (39 maps, none a city roof): our opening. Closest: **Construction** (crane high ground, gaps, fall risks), **Station** (two buildings, breakable windows), **Dimension** (small platforms over a fall), and "Big" twins of small maps. See [Case Study - Rivals](../../LihFolk/32%20Case%20Studies%20of%20Top%20Roblox%20Games/Case%20Study%20-%20Rivals.md) |
| [Overwatch 2 map design (Blizzard)](https://news.blizzard.com/en-us/article/23785339/uniting-gameplay-and-style-behind-overwatch-2-s-complex-map-design) | Art guides the player: bold shape and colour per side, readable silhouettes, light used for direction |
| Splatoon *Moray Towers* ([StrategyWiki](https://strategywiki.org/wiki/Splatoon/Moray_Towers), bot-blocked) | Tall towers joined by ramps, ledges over long drops, a low centre between: our Pit-and-tower idea in a bright, toy-clean style |
| [Rooftop water tower (Wikipedia)](https://en.wikipedia.org/wiki/Rooftop_water_tower), [SoHo](https://commons.wikimedia.org/wiki/File:Rooftop_water_towers_in_SoHo,_Manhattan.jpg), [160 5th Ave](https://commons.wikimedia.org/wiki/File:Rooftop_water_tower,_160_5th_Ave,_Manhattan.jpg), [46th St, 1984](https://commons.wikimedia.org/wiki/File:Water_Towers_On_New_York_City%27s_46th_Street_-_June_1984.jpg), [Commons: NYC water towers](https://commons.wikimedia.org/wiki/Category:Water_towers_in_New_York_City) | The hero shape: a barrel tank with hoops and a cone cap on a braced steel stand with a ladder. We simplify it to a chunky cobalt tank (§4) |
| [Commons: roof terraces](https://commons.wikimedia.org/wiki/Category:Roof_terraces), [rooftop gardens](https://commons.wikimedia.org/wiki/Category:Rooftop_gardens), [fire escapes](https://commons.wikimedia.org/wiki/Category:Fire_escapes) | Sunny roofs with pergolas, planters and awnings, and the stair-and-landing silhouette: the friendly set dressing |
| [Lobby Style Guide](../../02%20Art/Lobby%20Style%20Guide.md) and its renders ([spawn](../../02%20Art/References/lobby/rebuild-20261104/01-spawn.jpg), [kit sheet](../../02%20Art/References/lobby/rebuild-20261104/bunker2-sheet-a.jpg)) | The kit language: stepped plinths and collars, picture-frame openings, bevel hierarchy, layering, clean SmoothPlastic trims, calm textures on big surfaces |
| [Dockyard2](Dockyard2.md) | The sibling redesign. Rooftops2 must not look like it (sunny harbour, sand deck, yellow crane) |
| Counter-example: the old [Rooftops Pit preview](../../02%20Art/References/maps/rooftops/rooftops-preview-pit.jpg) | Blue hour, dark brick, grey membrane: what not to repeat |

### What the LihFolk notes add (cited)
- **Layout** (`33 Level Design`): *Combat Arena and Encounter Layout* (cover 2.5-3.5 or 7+, never 4-6; routes within ~1 s), *Level Design Principles - Flow Sightlines and Landmarks* (one landmark 1.5x taller than the rest, in the first frame after spawning: the tank tower), *Spawn Points Safe Zones and Respawn Flow*, *Kill Planes, Map Boundaries and Out-of-Bounds Recovery* (a server depth check, not a Touched part).
- **Composition** (`06 World Building and Art`): *World Composition and Set Dressing - Designed, Not Scattered* (hero landmark, 2-4 primary forms, odd-numbered story groups), *Environment Art Styles*, *Art Budgets - Triangles Draw Calls Memory*, *Collision and Physics Geometry*.
- **Modelling** (`54 Untextured Stylised Modelling`, `55 Modelling Nuance and Readability`): *Bevels Chamfers and Edge Highlights Without Textures* (1-6% of the form), *Shape Language and Silhouette Testing*, *Proportion Exaggeration and Gameplay Distance*, *Spending Triangles Where the Camera Looks*.
- **Materials and colour** (`44 Materials and Surfaces`, `06`): *Stylised vs Realistic Material Pipelines*, *Materials MaterialVariants and SurfaceAppearance*, *Colour Scripts and Value Structure for Untextured Art* (3-5 value bands, 60/30/10, one accent, greyscale check).
- **Light** (`07 Lighting VFX and Audio`): *Stylized Lighting Recipes* ("Bright cartoon" base), *Lighting Mood and Time of Day*, *Atmosphere Sky Clouds and Post-Processing*, *Light Sources and Shadows* (local lights shadowless).
- **Craft** (`60 High-Craft Game Teardowns`): *What Craft Looks Like on Roblox*, *Teardown - Phantom Forces* (simple geometry, strong silhouettes).
- Skills to load for phases 3 to 7: `lihfolk-worldbuilding`, `roblox-blender-modeling`, `roblox-asset-import`, `lihfolk:quality-score`.

## 3. Layout changes to test
The plan lives as data in `tools/maps/rooftops2_layout.py` (a copy of `rooftops_layout.py` plus a perch-share check). Same 180° rotation, team A at -Z, B at +Z. Every change is a hypothesis: keep it only if the script confirms it.

| Check | Rooftops now | Target for Rooftops2 |
|---|---|---|
| Spawn sees spawn; enemy floor / Updraft tops seeing a spawn | never; 0% / 0% | same |
| First sight, sprint / walk | 1.7 s / 2.4 s | >= 3.0 s / 4.0 s |
| Both teams sprinting meet | 3.6 s (4.9 s walking) | >= 4.5 s |
| Sightlines over 70 / over 100 / longest | 8.5% / 0.9% / 128 | <= 6.4% / <= 0.5% / <= 100 |
| Distance to full cover: average / furthest | 6.9 / 20.0 | <= 6.5 / <= 15 |
| Spawn to spawn: direct / via a tower / via the Pit | 160 / 162-164 / 173 | 170-185, all within 0.5 s sprinting |
| Best perch (share of the floor it sees) | not measured | <= 45% |
| Gaps: Pit-roof 8, Pit-tower 8, tower-roof 16 | crossable (jump 8.7 walk / 11.9 sprint, Dash 12-24) | keep; no gap 4-7 |
| Places you can't walk to | 0 | 0 |

1. **Deeper roofs, Pit screens.** Team roofs 96 x 48 → 96 x 56 (the extra 8 goes to the spawn court; map bound Z 84 → 92) and a full-cover (7+) planter wall or awning screen on each Pit lip, offset from the stairs. Spawn to spawn ~176; the first look runs down a lane instead of across the Pit.
2. **Break the 128 diagonals.** They run from a front corner across the Pit into the far roof. Move one front-row AC unit per roof onto that diagonal and widen the flue into a short wall. Re-run the sightlines.
3. **Cover at the gangway foot.** A pergola post line or a stair-hut spur on each gangway, and a 7-high planter at (-44,12) and its twin.
4. **Pit stairs 4 studs nearer the middle** so the Pit stops being the slow route; the footbridges keep their length.
5. **Perch share.** Add the check; lower the huts and flues that see most of a roof, or add a parapet at their lip. The tank (+22) stays the one risky landmark seat.
6. **Readable fall.** No gameplay change: bright coping on every drop edge and a shaded, hazy alley below (street Parts in a darker teal), so a missed jump reads as "down there".

Callouts: **A roof / B roof**, **Pit**, **Tank** (lift tower), **West / East tower**, **Gangway**, **Plank**, **Penthouse**, **Alley**.

### Measured result (layout v2, 2026-11-05)
![Rooftops2 layout](../../02%20Art/References/maps/rooftops2/rooftops2-layout.svg)

| Check | Rooftops | **Rooftops2** | Target |
|---|---|---|---|
| Z-fighting (box faces), clipping, slits | 0 / 0 / 0 | **0 / 0 / 0** | 0 |
| Spawn sees spawn; floor / Updraft tops that see a spawn | never; 0% / 0% | **never; 0% / 0%** | same |
| First sight, sprint / walk | 1.7 / 2.4 s | **1.9 / 2.6 s** | ≥ 3.0 / 4.0 (missed) |
| Both teams sprinting meet | 3.6 s | **3.9 s** | ≥ 4.5 (missed) |
| Over 70 / over 100 / longest | 8.5% / 0.9% / 128 | **8.6% / 0.8% / 132** | ≤ 6.4% / 0.5% / 100 (missed) |
| Distance to full cover: average / furthest | 6.9 / 20.0 | **7.2 / 20.2** (on the gangway, a lane) | ≤ 15 (missed) |
| Spawn to spawn: direct / via a tower / via the Pit | 160 / 162–164 / 173 | **173 / 175–177 / 183** | within 0.5 s (Pit +0.4 s, was +0.6) |

What was built, and what each change measured:
1. **Team roofs 96 × 56** (the middle and back rows move back 6–8; spawns at z ±68–73, barrier at ±64). Spawn to spawn is +13. The meet moves +0.3 s and first sight +0.2 s.
2. **Billboards 22 wide** (were 18), reaching x +1, 4 short of the stair. They cut the diagonals that slipped past their inner end, including the old first-sight line.
3. **Pit stairs 6 nearer the middle** (x 5–13, against the lift tower), and the Pit condenser removed because it left slits. The Pit route goes from +0.6 s to +0.4 s.
4. **A planter screen** (6 × 3, full cover) against the west parapet of each roof's front row. It cuts the west-lane diagonal and brings the longest line from 136 back to 132.

**Honest read:** the plan's sight targets aren't met. On a 1v1 map this small (teams meet at 3.9 s), the front edges see each other across the Pit by design, as with "Hold the edge". The remaining long lines are side-lane diagonals that each end in cover. Changes that kept the numbers flat or worse were dropped rather than kept for show. The next step, if the user wants it, is front-row screens on the Pit lips, which trade the Pit look-down for safety.

## 4. Look (style frame)
**Identity: sunny terracotta rooftops at golden afternoon.** A warm city of cream plaster, terracotta tile and white trims with **one cobalt accent**: the water tank and the awnings. The Lobby is dark warm concrete with teal-slate structure and one accent per wing; Dockyard2 is a sunny harbour with a sand deck and a signal-yellow crane. Rooftops2 is warmer and rosier than both (coral, terracotta, sage) with a blue spike, so no two maps read alike. Team cyan, orange-red and glitch magenta stay off the map.

| Role | Colour | Material (variant) | Note |
|---|---|---|---|
| Roof deck (ground band, V ~50%) | terracotta flat tile `#B8704F` | Slate or Brick, `Roof2_Tile` (calm, 8-stud tiles) | the Pit deck is cooler `#A8896E` |
| Team A building | warm coral plaster `#D98C66` | Concrete, `Roof2_Plaster` | facades, penthouse, huts |
| Team B building | pale sage plaster `#A9BBA0` | same | same pieces, tinted: distinct from A in colour and in greyscale |
| Towers and Pit walls | cream limestone `#D9C9A8` | same | |
| Trim (cornice, sills, coping, frames) | white `#F2EEE4` | SmoothPlastic | at least 0.05 proud |
| Structure (stairs, rails, stand, shutters) | charcoal `#3A3F47` | SmoothPlastic / Metal | route language: white rail tops and stair nosings |
| **Accent** | cobalt `#2E6BE0` | SmoothPlastic | tank, awnings, tower roof signs; <= 10% of any view |
| Glass | pale sky `#BFD8E8`, 0.3 transparency | Glass | big and few; warm panes `#F4D9A8` on one in six |
| Signs | Montserrat Black letters on a white plate, cobalt outline tube | Neon (outline only) | glitch ghosting only as a rare flicker, <= 5% of any view |

- **Landmark:** the cobalt **water tank on the lift tower**, seen from both spawns and 1.5x taller than anything else on the roofs. No 240-tall sign tower; the skyline is a ring of low plaster blocks and tile roofs at or under roof height, with a steeple or two far off.
- **Kit language** (Lobby Style Guide): bevels primary 0.45 (2 segments), secondary 0.14, tertiary 0.05. Parapets with a stepped coping and bullnose lip; 8-wide facade modules with picture-frame windows, a shutter pair and a deep cornice; the tank on a stepped plinth with a notched leg stand, collar and cap; AC units with five broad proud louvre ribs; stairs with chamfered steel stringers; awnings and pergolas as the friendly dressing.
- **Light:** golden afternoon, ClockTime ~16.3, latitude 0 (the sun is ~35° up and rakes along X, so neither team looks into it). Warm sun, cool sky ambient, Atmosphere density ~0.3 with a peach haze, bloom threshold >= 1.4. Long shadows fall into the alleys and give the falls a dark floor. Base: the "Bright cartoon" recipe. Local lights only at the tank and signs, shadowless.
- Greyscale and no-shadow views (phones below quality 4) are checked before moving on.

## 5. Kit pieces (Lobby kit language; 1 unit = 1 stud, origin bottom centre, front -Y)
About 30 pieces, <= 120k triangles placed, <= 600 MeshParts, none over 2048 studs.

| Group | Pieces |
|---|---|
| Facade | `Facade8A/B/C` (plaster, fewer bigger picture-frame windows, cornice, shutters), `Facade4`, `Plinth8/4`, `Quoin` |
| Edges | `Parapet8` (stepped coping, pier), `Ledge8`, `Sill` |
| Routes | `Stair16`, `Gangway16` (pergola rails), `PlankRamp16`, `Catwalk8` |
| Roof furniture | `ACUnit` (louvre ribs), `Condenser`, `Skylight`, `Planter`, `Pergola`, `Awning`, `Flue` |
| Hero shapes | `WaterTank` (cobalt), `LiftTower`, `TankHouse`, `CoolingTower`, `Penthouse` + `LetterA/B`, `StairHut`, `LiftHouse` |
| Signs, dressing | `RoofSign`, `Banner` (replaces the billboard), `StreetLamp`, `CityA/B/C` (low backdrop blocks), `Chimney`, `Steeple` |

## 6. Restyle parameters (cheap to change)
All in **`tools/maps/rooftops2_style.py`** (as `dockyard2_style.py`): `PALETTE` (role colours, materials, MaterialVariants), `TEAM_TINT`, `VARIANTS`, `LIGHTING` / `FX` / `LAMP`, `BEVEL` / `SEGMENTS`. Colour, texture and light changes: `python tools/maps/rooftops2_style.py --luau`, then re-run the Art + Lighting bundle in Studio (no Blender, no upload). Bevel or shape changes: Blender rebuild → export → upload → kit install.

## 7. Plan (phases)
1. Plan with references (this note).
2. Layout check script and SVG (`tools/maps/rooftops2_layout.py`): the §3 table, change by change.
3. Greybox in Studio (`tools/studio/maps/Rooftops2/Greybox.luau`, origin (3000, 200, 0)). Walk it in play mode, then critique.
4. Style frame, then the Blender kit (`tools/blender/build_map_kit_rooftops2.py` on the Lobby kit helpers) with a contact sheet. Coplanar audit at 0, export, upload (group 11116787), install.
5. Art pass (`Art.luau`), lighting (`Lighting.luau`), set dressing in odd-numbered groups.
6. `tools/studio/maps/Audit.luau "Rooftops2"` reports 0.
7. Screenshots from each spawn, the Pit, a tower and an overview; mobile budget; a 2-player play test with `ForceMap`.
8. Blind scoring (`lihfolk:quality-score`, world rubric, min 8.5), fix rounds, then ask the user about the swap. Vault upkeep: Home status, Asset Tracker row, a note in `05 Production/Playtests/`.

## Built (phases 3 to 7)
- **Greybox** (`tools/studio/maps/Rooftops2/Greybox.luau`, generated by `tools/maps/rooftops2_layout.py --write`): 436 parts, 4 + 4 spawns, 2 barriers, `KillDepth` 24. Walked in play mode with `ForceMap`: [overview](../../02%20Art/References/maps/rooftops2/greybox-overview.jpg), [from the A spawn](../../02%20Art/References/maps/rooftops2/greybox-play-a-spawn.jpg), [A front row](../../02%20Art/References/maps/rooftops2/greybox-play-a-front.jpg).
- **Kit** (`tools/blender/build_map_kit_rooftops2.py`, on the Dockyard2 and Lobby helpers): 39 pieces, about 32k triangles. **Coplanar audit 0.** [Contact sheet A](../../02%20Art/References/maps/rooftops2/kit-contact-a.jpg), [B](../../02%20Art/References/maps/rooftops2/kit-contact-b.jpg). Piece names and origins are the old Rooftops kit's, so the checked placements dropped straight in.
  - **Facades:** an 8-wide plaster column with storey bands, picture-frame windows, sills and a deep cornice. Variant B has two windows per storey, variant C has cobalt awnings.
  - **Roof furniture:** huts with a plinth, corner pilasters, a framed door and a cornice. AC units as two stacked louvred machines. A cobalt water tank with white hoops and cap.
  - **The Penthouse:** pilasters, downpipes, vents, a door awning with wall lamps, and end windows.
  - **Routes:** stairs and gangways with yellow rails and nosings, wooden catwalks, a plank ramp.
  - **Wayfinding:** "SUNSET SODA" billboards (two-sided), "SKY DINER" roof signs, "ROOF A/B" spawn signs (◄ side ►), TANK plates on the lift tower, painted PIT / WEST / EAST / ROOF A / ROOF B words, chevrons.
- **Art pass:** 264 placements and 25 art Parts (street, sidewalks, yellow lane lines). The visible greybox edges (parapets, coping, ledges, roofs) are restyled by their `Look` attribute.
- **Studio audit (`Audit.luau`): 0.** It found 121 pairs on the first install: facade columns at the building corners and plinths shared their end planes. They were fixed at the source by dropping hidden end caps and back faces (`open_box`), and the kit audit can't see these cross-piece pairs, so always run the Studio audit.
- **Sun:** latitude 23.5 at ClockTime 17.1 gives `GetSunDirection` (-0.97, 0.23, 0.00): low across the map, so neither team looks into it.

## 9. Scoring (`lihfolk:quality-score`, world rubric, 3 blind reviewers per round, medians)
| Round | W1 (3) | W2 (3) | W3 (2) | W4 (2) | W5 (1) | W6 (1) | Score | Gain | What changed before it |
|---|---|---|---|---|---|---|---|---|---|
| 0 | 2 | 1 | 1 | 1 | 1 | 2 | 6.67 | | first install |
| 1 | 2 | 1 | 2 | 1 | 1 | 1 | 7.08 (reviewers 7.08 / 7.5 / 7.9) | +0.4 | plaster on SmoothPlastic (the concrete variant read as brick), golden hour 17.1, varied city tints, yellow rails on every route, ROOF A/B words in the Pit |
| 2 | 2 | 1 | 2 | 1 | 1 | 2 | 7.5 | +0.4 | hut and Penthouse detail, two-tier AC units, cooler shade, darker towers |
| 3 | 2 | 2 | 1 | 1 | 1 | 1 | 7.5 | 0 | yellow lane lines down each main lane, spawn-court planters, deeper ambient |
| 4 | 2 | 1 | 2 | 2 | 1 | 1 | 7.92 | +0.42 | exposure -0.15, darker cream, cool street, no moon, wood decks, spawn chevrons, clipped Pit word fixed |
| 5 | 2 | 2 | 2 | 1 | 1 | 1 | 8.33 | +0.42 | route lines round the Penthouse, bigger chevrons, TANK plates, Penthouse awning and lamps, warm doors and AC paint |
| 6 | 2 | 1 | 2 | 2 | 1 | 1 | 7.92 (8.33 / 7.92 / 7.08) | -0.42 | Penthouse end windows, lift-tower vents and band, softer bands, awning and billboards (`AccentSoft`, `Poster`), cobalt chevrons, more sun contrast |
| 7 | 2 | 2 | 2 | 1 | 1 | 1 | 8.33 (8.33 / 7.08 / 8.33) | +0.42 | bigger chevrons, four per court exit, WEST/EAST words past the Penthouse |
| **8** | **2** | **2** | **1** | **2** | **1** | **1** | **8.33** (8.33 / 7.92 / 8.33) | 0 | wainscot, cap and warm cove glow on the Penthouse long faces, cream chevrons, deeper shade and grade contrast, EAST/WEST words moved past the lift house |

**Final: 8.33 / 10, below the 8.5 bar.** The stop rule was reached: rounds 6 (-0.42) and 8 (0) each gained less than 0.3. Rounds 5 to 8 sit at 7.9 to 8.3, and single reviewers swing a criterion by about ±1.

What the reviewers still mark down, all three in round 8:
- **W5:** big plain wall slabs at the spawn-court exit (the 6-wide gap between the Penthouse and the lift house).
- **W6:** oversized-looking windows, AC units and the TANK plate, with no avatar in frame.
- **W3:** flat navy window glass and dark door voids. These two are role colours in `rooftops2_style.py` (`Window`, `Door`), so they're a one-line restyle the user can judge in play.

The next fix, if wanted, is to lighten `Window` and `Door` and dress the lift-house and Penthouse ends at the court exit.


The reviewers repeat the same small set of issues: blank walls (Penthouse ends, lift-tower faces), chevron contrast, billboards competing with the tank, and eye-level light "tuned, not striking". Fix round 6 targets all four.

## What the user should check tonight
1. Save the match place (Ctrl+S): fix rounds 7 and 8 were installed after the 13:59 save. Then set `ForceMap = "Rooftops2"` and play.
2. **The look:** golden-afternoon terracotta roofs, apricot/sage plaster, a cobalt tank. Too warm? Too busy? Every colour and the light are in `tools/maps/rooftops2_style.py`.
3. **Routes:** spawn → chevrons round the Penthouse → yellow lane lines → the PIT footbridge. Do the stairs and gangways read?
4. **Feel:** first sight is still early (1.9 s). Do the deeper roofs and the planters help, or do the front rows need screens?
5. Decide whether Rooftops2 replaces Rooftops in the 1v1/2v2 rotation.

## 8. Open questions for the user
- Is rosy terracotta with cobalt right, or should it be cooler (sage and white)?
- Should the 8-wide alleys keep the instant fall, or get a short rescue ledge for 1v1?
- Roofs 56 deep make the map a little longer. Fine for 1v1 and 2v2?

## Concept pass 2026-11-05
Status: **in progress.** Brief: [Evening Review](../../05%20Production/Playtests/2026-11-05%20Evening%20Review.md).

The user's verdict: Rooftops2 is the weakest map, with no levels and no character. Target: Valorant-level detail with RIVALS clarity. The user approves the concepts before any modelling.

Skills and notes used: the same as the [Dockyard2 concept pass](Dockyard2.md#concept-pass-2026-11-05), namely `gauntlet-vault`, `lihfolk-worldbuilding` and `roblox-blender-modeling`, plus the LihFolk notes on kits, trim sheets, texture memory, budgets and arena layout.

### What's wrong now (evidence)
Screenshots:
- [overview](../../02%20Art/References/maps/rooftops2/r8-overview.jpg)
- [B court exit](../../02%20Art/References/maps/rooftops2/r8-b-court-exit.jpg)
- [Pit](../../02%20Art/References/maps/rooftops2/r8-pit.jpg)
- [A spawn court](../../02%20Art/References/maps/rooftops2/r8-a-spawn-court.jpg)

1. **No levels.** Both team roofs are one flat deck. The Pit is a single step down. Nothing can be climbed: no penthouse roof, no fire escape, no water-tank platform, no bridge over the alley. The billboard is a wall, not a perch.
2. **Cubes for buildings.** The huts, the Penthouse and the lift tower are boxes with a cap. None of them have a pitched roof, parapet profile, chimney stack, cornice depth, overhang or antenna clutter. The skyline towers behind are plain slabs with stripes for windows.
3. **Blank walls.** At eye height, the court exit is two big flat plaster slabs with flat navy windows and no reveals, sills, shutters, frames or interior. The doors are dark rectangles.
4. **Flat materials.**
   - The tile roof is a clean orange grid.
   - The plaster has no cracks, stains, patches or exposed brick.
   - There are no tar seams, gravel, flashing, drainpipes or roof hatches.
5. **No identity.** It could be any city. It has no street life below, no laundry lines, satellite dishes or rooftop garden, and no neighbourhood sign. The "Sunset Soda" billboard is the only story.
6. **Weak landmark.** The cobalt water tanks are small and repeated, so none of them own the skyline.
7. **What works:**
   - the warm golden light;
   - the team tones (apricot and sage);
   - the painted lane words;
   - the 180° layout and its measured timings.

   Keep all four.

### Reference board (local only, never committed: third-party images)
21 images in `vault/02 Art/References/maps/rooftops/third-party/`. What to take from each is listed in that folder's `SOURCES.md`.
- **Games (11):**
  - Valorant Split ×2: height stacking, trim bands, worn plaster and metal.
  - Valorant Ascent ×2: old-town identity, tiled roofs, colour zoning.
  - Valorant Sunset ×2: sun-baked palette, signage and trim.
  - CS2 Vertigo ×2: roof edges, steel and plank silhouettes, drops, parapets.
  - Overwatch Rialto: Mediterranean roofs and chimneys.
  - Overwatch Dorado: balconies, awnings, zoning.
  - RIVALS Station: clarity and zone colour.
- **Real (10):**
  - Lisbon rooftops ×3: roof planes at many heights, chimneys and antennas.
  - NYC water towers ×3: the tank silhouette (conical roof, hoops, stilted frame).
  - Fire escapes ×3: landings, stairs, railings, peeling paint.
  - A Marseille roofscape: clutter, lean-to roofs.
- **Gaps:** no Krunker, and only one RIVALS image (no rooftop map exists there).

### LihFolk rules applied (what changes, and the note it comes from)
The folders read are the same as for [Dockyard2](Dockyard2.md#lihfolk-rules-applied-what-changes-and-the-note-it-comes-from), and its rules 6–15 apply here unchanged:
- bevels by material; shape hierarchy; panel lines; modelled undersides; prop exaggeration;
- triangle budget; one 1024 trim sheet plus ≤ 6 variants at 512; TintMask tinting;
- wear baked, not decals; opaque grating.

The Rooftops-specific rules:
1. **The water-tank platform is not a lone power seat** (*Combat Arena and Encounter Layout* §6).
   - It needs two contested ways up (a ladder from each side) and a low parapet of 2.5–3.5 studs.
   - Before building, run the perch-share check. Rooftops already has ten tops only Updraft can reach; cap the share at ≤ 40%.
   - The platform must not see into either spawn court (*Spawn Points Safe Zones and Respawn Flow* §3).
2. **Jump is 5.6 studs** ([Gunplay](../Gunplay.md)). Penthouse roofs (+10) and billboard catwalks (+8) are reached only by stairs or ladders, never by a jump off AC units or planters.
   - Every rise is ≤ 4 studs per hop.
   - Rule 3 below keeps the props that could serve as steps in the decor band.
3. **Cover is low (2.5–3.5) or full (7+).** AC units, planters and chimney stacks in the 4–6 band become non-colliding decor or are resized (*Combat Arena and Encounter Layout* §2).
4. **One global landmark.** The timber water tank on a steel tower with the neon sign frame is the single landmark:
   - unique as a black silhouette;
   - at least 1.5× taller than anything else;
   - in the first frame after spawning;
   - not hiding a route exit.

   The many small cobalt tanks go. The old "Sunset Soda" billboard must stay dimmer than the landmark sign (*Level Design Principles - Flow Sightlines and Landmarks* §4; *World Composition and Set Dressing* §2).
5. **Neon is the single hot spot.**
   - It covers about one sixth of the sign frame's area, and nothing else glows as bright (*Stylized Lighting Recipes*).
   - Bloom threshold goes to about 1.1 so the neon actually blooms. It stays above the walls' brightness.
6. **Lighting: Golden hour** (*Stylized Lighting Recipes* §3.3), with the arena rule from §3.2 that the environment stays desaturated while team tones and the landmark carry the saturation.
   - About 17 h; top shift (255,190,120); bottom shift (60,40,80).
   - Peach haze (255,200,160) at density about 0.35, glare 0.4. No SunRays.
   - Low key and warm dominant, so it's the opposite of Dockyard2's high-key cool (*Colour Scripts and Value Structure for Untextured Art*: neighbouring maps differ in at least two of hue, key and saturation).
   - Greyscale and no-shadow tests, because colour has to come from the shifts when phones drop shadows.
7. **Detail goes where the camera looks** (*Teardown - Phantom Forces*; *Environment Art Styles*).
   - Facades at eye height get reveals, sills, shutters and drainpipes.
   - The skyline towers stay simple silhouettes, faded by haze toward the sky's value.
8. **Same process as Dockyard2:** silhouettes, then the overview, then the hero images, critiqued in a fixed order.

### Identity brief
- **Identity sentence:** "The sun-baked rooftops of an old harbour quarter at golden hour, where two neighbours' roofs face off across a sunken courtyard under a giant water tank." The district name is ours.
- **Story groups (2–3):**
  - a rooftop party left half-set: string lights, folding chairs, a cooler;
  - a laundry line with one sheet blown onto the parapet;
  - a pigeon loft with an open hatch.
- **Not this:**
  - plaster cubes with caps;
  - flat navy windows;
  - neon everywhere;
  - a copy of Venice, Lisbon or any real square;
  - thin antennas crossing sightlines;
  - noisy decals on floors.

### Direction (keep the layout: two team roofs, the Pit between them, east and west routes)
- **Height levels (new, 180° symmetric):**
  - **Penthouse roof (+10):** reached by an outside fire-escape stair. It overlooks the team's own roof only, so it can't spawn-peek.
  - **Water-tank platform (+12):** a ladder from each side and a low parapet. Perch share ≤ 40%.
  - **Bridges:** plank and steel bridges over the alley gaps. Beside each bridge, a drop to a fire-escape landing (-6) gives a flank route with a ladder back up.
  - **Billboard catwalk (+8):** behind each billboard, looking into the Pit through the gap between the panels.
- **Landmark:** one big timber water tank on a steel lattice tower in a neon sign frame (the sign is blank in the concepts; our own lettering comes later).
- **Colour:**
  - A roof: apricot plaster and terracotta tiles.
  - B roof: sage plaster and slate tiles.
  - The Pit: cream with cobalt trims.
  - The neon is the one spike.
- **Materials:** in one 1024 trim sheet plus ≤ 6 variants at 512:
  - plaster, with low-frequency cracks and stains;
  - exposed-brick corner patches;
  - terracotta and slate tiles;
  - tar-and-gravel roofing with flashing;
  - painted shutter wood;
  - fire-escape steel (opaque grating);
  - stone cornice;
  - plank.

### Prompts (ChatGPT image generation, revised after the LihFolk read)
Attach the current Rooftops2 [overview](../../02%20Art/References/maps/rooftops2/r8-overview.jpg), one Lobby screenshot, and 2–3 of the third-party references.

The shared style block is the same as Dockyard2's (chunky proportions, trims 2–4× real thickness, wear on edges only, value bands, no text, no thin wires, original). Only the palette and light lines change:
> Palette: apricot plaster #E3AA84, sage plaster #A9C2B0, cream plaster #D4B98F, terracotta tile #B5735A, slate tile #6E7B86, charcoal steel #3A3F47, cobalt trim #2F62C8, warm neon #FFB14A (landmark sign only).
> Light: golden late afternoon, low warm sun from the side, peach haze, cool violet shade; the landmark sign is the brightest point.

0. **Silhouette round:**
   > 12 black silhouettes on white of rooftop water-tank-on-tower landmarks with a sign frame, each unique when blacked out, chunky, side view.
1. **Overview** (generate first; it becomes the reference for 2–4):
   > High three-quarter aerial view of a compact arena shooter map across the rooftops of two old city blocks, 180-degree rotational symmetry.
   > - Each end: a team roof with a walled spawn court and a penthouse with a fire-escape stair to its roof (one roof apricot plaster with terracotta tiles, one sage with slate).
   > - Middle: a sunken rooftop courtyard (the Pit) under a giant timber water tank on a steel lattice tower with a blank neon sign frame and a ladder platform.
   > - Flanks: plank-and-steel bridges cross the alley gaps, with fire-escape landings below.
   > - Two back-to-back billboards with catwalks stand between the roofs.
   > - The streets far below. Golden hour.
2. **Hero, the Pit:**
   > Wide game camera, about 100° horizontal FOV, player eye height, standing in the sunken courtyard looking up at the water tank and tower (from image 1). Ladders up both sides, cream plaster walls with green shutters and drainpipes, a stair up to the terracotta roof ahead, tar-and-gravel floor.
3. **Hero, spawn A:**
   > Same camera, looking out of the apricot spawn court across the terracotta roof: chimney stacks, skylights, a fire-escape stair climbing to the penthouse roof on the right, a laundry line, the landmark mid-distance.
4. **Hero, spawn B:**
   > The rotated twin: the sage roof with slate tiles, a plank-and-steel bridge over an alley gap with the street far below, a rooftop party corner, the landmark ahead.
5. **Kit sheet:**
   > Orthographic front, side and top views plus one three-quarter view, a 5-ft mannequin for scale, on a 4-unit grid:
   > - window bay facade module with shutters and sill;
   > - corner pier with quoins;
   > - cornice and parapet with coping;
   > - penthouse block;
   > - fire-escape stair and landing;
   > - plank bridge and steel bridge;
   > - water tank on lattice tower;
   > - billboard with catwalk;
   > - AC unit on brackets;
   > - chimney stack;
   > - skylight and roof hatch;
   > - planter box.
6. **Trim sheet:**
   > Game trim sheet texture, 1:1, horizontal tiling strips:
   > - plaster panel;
   > - exposed brick;
   > - terracotta tile row;
   > - slate tile row;
   > - tar-and-gravel;
   > - shutter slats;
   > - stone cornice profile;
   > - metal flashing;
   > - fire-escape grating (opaque);
   > - plank;
   > - a blank sign plate row;
   > - a flat palette strip.
   >
   > All tintable near-white except the palette strip; wear on edges only; low noise.

### Modelling plan (after the concepts are approved)
- **Blender, real detail** (scripted kit, derived dimensions, seed per piece, A1–A18 gates, coplanar 0):
  - the water tank and tower (hero, 5–12k);
  - facade modules with real reveals, shutters and sills (these replace the flat navy windows and blank slabs);
  - corner piers and cornices;
  - the penthouse with roof and parapet;
  - fire escapes and bridges with stringers underneath;
  - billboard catwalks;
  - AC, chimney, skylight and hatch;
  - laundry lines and cables (`lihfolk_curves`).
- **Textures and budget:**
  - One 1024 trim sheet (colour + normal) with baked edge wear, cavity and AO. Up to 6 MaterialVariants at 512 for plaster, tile, gravel and plank.
  - Repeated props at 100–800 tris; the map ≤ 450k visible tris.
  - Measured in Studio before the art pass is called done.
- **Order:** layout re-check (perch share, jump 5.6, spawn-court sightlines), greybox heights, kit, trim sheet, art, blind score.

### Birds (map life)
The current pigeons are boxy. **Recommendation: remove them until there's a modelled replacement.** Use the same rules as Dockyard2's gulls:
- a rounded body, tapered wings, tail fan and neck collar;
- 300–500 tris;
- flaps in bursts with glides, on spline paths;
- client-only, capped and culled.

They perch on parapets and the pigeon loft away from routes, and take off only when a player comes near, never across a duel sightline. This is lane F's area; it's a recommendation only.
