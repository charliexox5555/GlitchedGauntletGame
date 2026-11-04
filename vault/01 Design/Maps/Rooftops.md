# Rooftops

A small outdoor map for 1v1 and 2v2: a fight across the roofs of one city block at blue hour, just after sunset. Two team buildings face each other over a lower middle roof (the **Pit**) and two side towers, joined by bridges and steel stairs, with the street 72 studs below. See [Maps](00%20Maps.md) for the roster.

**Status (2026-11-03):** concept, checked layout, generated greybox, Blender kit (**uploaded, asset 112960022711405**), generated art pass and lighting are done and previewed offline in Blender. **Not yet run in Studio**: the hub runs it (§6). Map id `Rooftops`, world origin **(1500, 200, 1500)**, modes 1v1 and 2v2 (`Config.Match` MAPS: minTeam 1, maxTeam 2), `KillDepth` 24.

![Overview (offline preview)](../../02%20Art/References/maps/rooftops/rooftops-preview-overview.jpg)
![From the B spawn (offline preview)](../../02%20Art/References/maps/rooftops/rooftops-preview-from-b-spawn.jpg)
![In the Pit (offline preview)](../../02%20Art/References/maps/rooftops/rooftops-preview-pit.jpg)

Blender renders of the whole map exactly as `Art.luau` places it, under a blue-hour stand-in for the Roblox lighting (Roblox will be flatter and brighter in the shade).

---

## 1. One line
Hold the edge: two rooftops over a sunken middle roof, three ways across (a catwalk, the Pit, a plank), and a long drop for anyone who misjudges a gap.

### What it should feel like
- **Fast and vertical.** Three heights 8 apart: the Pit (−8), the roofs and bridges (0), and the hut, tank and AC tops you only reach with Updraft. Every gap is either clearly jumpable (8 wide) or clearly a bridge (16 wide).
- **A real place.** Water tanks on steel stands, rooftop AC units, stair penthouses, skylights, a billboard on each side tower, brick parapets with stone coping, lit windows down every facade.
- **Readable at blue hour.** A deep blue sky, warm lit windows and a few neon signs for mood, but bright, cool ambient light so a player against any wall reads at a glance.
- **Fair.** 180° rotational symmetry: each team owns the same set of places, turned round.

### Not this
A night map you can't see enemies in, neon everywhere (two sign colours, one per side), cyberpunk clutter, invisible walls, a parkour course you can't cross without abilities (every place is reachable on foot), props floating or piled for no reason.

---

## 2. References
Images of other games and other people's photos stay out of the repo (`References/maps/rooftops/third-party/` is git-ignored); the sources are linked.

| Reference | Take |
|---|---|
| [Call of Duty Mobile: Highrise map snapshot](https://blog.activision.com/call-of-duty/2020-07/Call-of-Duty-Mobile-Map-Snapshot-Highrise) (images `codm-highrise-*.jpg`) | The closest shooter precedent: two office buildings as spawns, a lower level between them that "fights from above and below", tanks and AC units as cover, low parapets round the roof edge, a raised helipad as the risky high spot. We copy the sunken middle seen from both roofs |
| [CS2: Vertigo](https://counterstrikewiki.com/Vertigo) and its callouts ([csdb.gg](https://csdb.gg/maps/vertigo/)) | A skyscraper fight on two exposed floors where you can fall off the map; the stairways are the chokepoints between floors. Our two Pit stairs play the same role |
| [Valorant: the creation of Split](https://playvalorant.com/en-us/news/dev/the-creation-of-split) | Off-site high positions that matter, and a middle split so it isn't one tangle of routes. Our Pit is one middle with two stairs, the side lanes are bridges |
| [Mirror's Edge: The City](https://mirrorsedge.fandom.com/wiki/The_City) | Rooftops as a readable playground: clean shapes, colour saved for a job |
| Rooftop water towers: [SoHo](https://commons.wikimedia.org/wiki/File:Rooftop_water_towers_in_SoHo,_Manhattan.jpg), [57th Street](https://commons.wikimedia.org/wiki/File:Rooftop_water_towers_on_New_York_apartment_buildings.jpg), [46th Street 1984](https://commons.wikimedia.org/wiki/File:Water_Towers_On_New_York_City%27s_46th_Street_-_June_1984.jpg); [Wikipedia: Rooftop water tower](https://en.wikipedia.org/wiki/Rooftop_water_tower) | The silhouette of the map: a wooden tank with steel hoops and a conical cap on a braced steel stand with a ladder. Brick parapets with a stone coping and a regular window rhythm on every storey |
| [Rooftop HVAC unit](https://commons.wikimedia.org/wiki/File:Helicopter_delivering_a_rooftop_HVAC_unit_-05-_(9721468738).jpg) | The packaged AC unit: a long grey box with louvred sides and fans on top, on a steel curb. It is our full cover |
| [Hong Kong rooftops](https://commons.wikimedia.org/wiki/File:Hong_Kong_rooftop_vc.jpg) | A dense block of roofs at different heights with alleys between them: what a "light well" between buildings looks like from above |
| [Flat-roof skylight](https://commons.wikimedia.org/wiki/File:Roofing_services_roof_skylight.jpg) | Low glass skylights on the membrane: half cover that reads as glass |
| [Shinjuku at blue hour](https://commons.wikimedia.org/wiki/File:Buildings_with_colorful_neon_street_signs_at_blue_hour,_Shinjuku,_Tokyo.jpg) | Rooftop billboards on steel frames with a row of floodlight arms over them, against a deep blue sky. The sky colour target and the billboard model |
| [Taipei skyline at blue hour](https://commons.wikimedia.org/wiki/File:Taipei_Skyline_at_blue_hour_20260623.jpg), [Manhattan at dusk](https://commons.wikimedia.org/wiki/File:Empire_State_Building_at_dusk_from_the_Bryant_Park_Hotel_(1629369476).jpg) | Blue hour: the sky still bright blue near the horizon, buildings dark against it, warm windows lit on maybe one in four; the tall tower as the landmark |
| [Vertical neon hotel sign](https://commons.wikimedia.org/wiki/File:Boulevard_Hotel_(Neon_sign),_Miami_Beach.jpg) | The landmark sign: tall vertical letters in a frame on a building's corner |
| Our own Dockyard and Old Town previews | The style to match: Roblox materials on clean low-poly kit pieces, value steps doing the work, colour where it means something |

### What the LihFolk notes add
- **Composition** ([World Composition and Set Dressing](../../LihFolk/06%20World%20Building%20and%20Art/World%20Composition%20and%20Set%20Dressing%20-%20Designed,%20Not%20Scattered.md)): one hero landmark at least 1.5 × taller than anything else, visible from both spawns; 2–4 primary forms framing it (here the two water tanks and the billboards); story groups in odd numbers; made things square to the walls.
- **Palette:** a cool blue base, one warm accent (the windows), and one sign colour per side so it means "west" or "east".
- **Readable night** preset ([Stylized Lighting Recipes](../../LihFolk/07%20Lighting%20VFX%20and%20Audio/Stylized%20Lighting%20Recipes.md)): Ambient ≤ OutdoorAmbient, tinted never black, Brightness doesn't lift shadows (ambient does), phones under quality 4 have no shadows so values must carry the look. Real lights only at focal points, shadowless; Neon for everything else.
- **Edges:** a real edge first (parapet, ledge); the kill height is a server check, not a Touched part ([Kill Planes, Map Boundaries](../../LihFolk/33%20Level%20Design/Kill%20Planes,%20Map%20Boundaries%20and%20Out-of-Bounds%20Recovery.md)). Gaps are clearly passable or clearly not.

---

## 3. Layout
![Rooftops layout](../../02%20Art/References/maps/rooftops/rooftops-layout.svg)

Generated and checked by `tools/maps/rooftops_layout.py` (`--write` regenerates the greybox and the art placements from the same data). Team A at −Z, team B at +Z, **180° rotation**. Map space: origin on the team roofs' surface at the map centre; the street is at −72.

| Place | Size (studs) | Height | Job |
|---|---|---|---|
| **Team roof** (A / B) | 96 × 48 | 0 | A 3 × 3 of cover between 6-wide lanes. Front row: a stair hut, two AC units, skylights. Middle: an AC unit, the **Penthouse** (40 wide, the spawn screen, team letter on it), the lift house. Back: the **spawn court** between the cooling tower and the tank house (water tank on top); 4 spawns; a full-width barrier at z ±56 |
| **Pit** (centre) | 40 × 32 | −8 | The middle roof. The **lift tower** (to +8) with the **water tank** on it: the centrepiece and the main line breaker. An AC unit and a condenser per half. A steel **stair** per team climbs along the parapet to a short footbridge onto that team's roof. A floodlit **billboard** at each end (its advert faces the team it overlooks) cuts the roof-to-roof lines at eye height; you walk under it |
| **Side towers** (west, east) | 20 × 16 | +8 | The high ground of the side lanes. A stair hut with the **neon roof sign** over it (DINER: pink west, amber east). A **gangway** (rails) climbs to it from one team roof, a **plank ramp** (no rails) from the other |
| **Flues** | 8 × 6 | to +10 | Brick shafts on the team blocks' alley walls, one in each alley mouth, so no line runs down an alley from roof to roof |
| **Alleys** | 8 (Pit ↔ roofs, Pit ↔ towers), 16 (towers ↔ roofs) | street −72 | The fall. 8 is a sprint jump (11.9) or a Dash; 16 is a bridge or a long Dash |
| **Edges** | | | Brick parapets (3 tall, stone coping, piers every 8) on the outer edges and round the Pit; a 1-high concrete ledge along the alleys (you can step off); flush stone sills where bridges land |

### Heights
Three walkable layers 8 apart: Pit −8, team roofs 0, towers +8. Updraft-only tops: AC units and the lift tower +8, stair huts +9, flues and lift houses +10, Penthouses +11, the tank +22. AC units are 7.5 tall (not jumpable at 7.2). **Kill height** y −24 (`KillDepth` 24 on the map): 16 under the Pit, 48 above the street; a fall from a roof ends in 0.49 s.

### Measured (from the scripts)
| Check | Result | Target |
|---|---|---|
| **Z-fighting, box faces** (greybox stage / with the street Parts) | **0 / 0** (`rooftops_layout.py`) | 0 |
| **Z-fighting, real triangles** (every kit piece / the assembled map: kit meshes + visible greybox Parts + street Parts) | **0 / 0** (`build_map_kit_rooftops.py`) | 0 |
| Props clipping anything / slits (0.6–6 between props, 0.6–4 to an edge) | 0 / 0 | 0 |
| Spawn sees enemy spawn | never | never |
| Floor or Updraft tops south of the B roof that see a B spawn point | 0% / 0% | ~0 |
| Spawn to spawn | 120–130 straight, 160 walked (7.3 s sprint) | 110–150 |
| Spawn to the Pit | 3.0 s sprint | |
| Both teams sprinting meet after | 3.6 s (4.9 s walking) | |
| **First sight** | **1.7 s sprinting, 2.4 s walking** (front edge to front edge across the Pit) | 5–8 s on a big map |
| Standing sightlines over 70 / over 100 | 8.5% / 0.9% of visible pairs; longest 128 (one diagonal per side across the Pit) | Whitebox: 6.4% over 70 |
| Distance to full cover | average 6.9, furthest 20 (on the gangways) | worst under ~15 except a lane |
| Places you can't walk to (without abilities) | 0 | 0 |

Checks at standing eye height on a 1-stud grid, heights in 3D. They don't replace walking it.

**What it bends:** first sight at 1.7 s is early because the map is small (the teams meet at 3.6 s); it is a front-edge look across the Pit, never into a spawn. The longest lines (~120) are one diagonal per side from a front corner across the Pit into the far roof; they end at the spawn-court exits, which the barrier covers until it drops.

### Abilities on this size
| Ability | Fit |
|---|---|
| **Dash** (12–24) | Crosses any 8 alley; 16+ crosses a tower gap without the bridge. Ledges don't stop a Dash: dashing along an alley edge is the fall risk |
| **Updraft** (14–28) | Pit → roof and roof → tower (8) from anywhere; onto the huts, the Penthouse (+11) and the flues. The tank (+22) only from a roof at full strength |
| **Firewall** (40 × 10) | Seals the Pit end to end, or a team's whole front row |
| **Molly / Frost** | The stairs, the footbridges and the gangway tops are the chokepoints |
| **Recall** (40) | An anchor on your footbridge reaches back to your front row; one in the Pit is a strong retake |

---

## 4. Look
| Part | Colour / material | Note |
|---|---|---|
| Team A building | warm red-brown brick `#8E4E3C` | facade walls, Penthouse, huts and flues on that roof |
| Team B building | cool slate-blue painted brick `#5F6F82` | the same pieces, tinted |
| Towers / Pit | sandstone `#A99173` / `#9C8A72` | |
| Trim | pale stone `#C9C1B0` (Limestone): sills, lintels, cornice, quoins, coping | |
| Roofs | asphalt membrane `#4B4E56`; the Pit gravel `#6E6A63` | darker than every piece of cover, so cover reads |
| Windows | dark glass `#1D2633`; about one in four lit warm `#E8B072` (Neon) | three lit patterns on the 8-wide columns |
| Signs | DINER neon pink `#FF4FA3` west, amber `#FFB238` east; the HOTEL sign tower pink | team colours (cyan `#00E5FF`, orange-red `#FF5A36`) stay free |
| Steel | stair, gangway and footbridge rails and nosings safety yellow, frames dark steel | every walkable route reads by its yellow rail |

- **Landmarks:** the water tank on the lift tower in the middle (seen from the whole map), the neon roof signs on the towers, the **sign tower** (240 tall, vertical HOTEL sign facing the map) to the west and a radio mast with red lights to the north-east. The ring of neighbouring blocks stays at or under the roofs so the sky stays open.
- **Lighting** (`Lighting.luau`): blue hour, ClockTime 18.45, GeographicLatitude 0 (the sun just under the western horizon; any low light rakes across the map along X), Brightness 1.4, cool high ambient (Ambient 112,120,152; OutdoorAmbient 150,160,200), ExposureCompensation 0.35, blue Atmosphere (density 0.3, haze 1.2), bloom threshold 1.2 (windows and signs glow, players don't). 6 shadowless lights: the two billboard floods, the two sign spills, a pool under the tank.

### Budget (mobile)
| Item | Value |
|---|---|
| Kit | 32 pieces, 126 MeshParts in the upload, 28k triangles; largest mesh 4,020 (the sign tower's lit windows) |
| Placed | 234 placements → **828 MeshParts**, **177k triangles for the whole map** (under 500k visible, well under 2,000 MeshParts) |
| Parts | 408 greybox Parts (brick edges, roofs and sills stay visible; 97 hidden under the kit) + 13 street Parts |
| Collision | greybox Parts only; every mesh CanCollide/CanQuery/CanTouch off, Box fidelity; CastShadow only on wall-sized pieces |
| Textures | none of our own: Roblox materials (Brick, Limestone, Asphalt, Pebble, Concrete, Metal, DiamondPlate, WoodPlanks, Glass, Neon) |

### Quality score (LihFolk world rubric, from the offline previews)
W1 composition 2 (the tank tower is the focal point in every view, the signs and billboards frame it, the sign tower breaks the skyline), W2 navigation 2 (yellow-railed stairs and gangways show every route), W3 style 2 (one kit, one palette), W4 lighting 1 (only previewed offline), W5 detail 1 (the roof membranes are plain, few story groups), W6 scale 2 (doors 3.2 × 7, steps 0.5, rails 3.5): **8.75 / 10**. Lowest: lighting (confirm readability in Studio) and detail (add roof clutter in groups if the screenshots look bare).

---

## 5. Build
| Step | File |
|---|---|
| Layout, checks, SVG, generation | `tools/maps/rooftops_layout.py [--write]`; placement rules `tools/maps/rooftops_art.py` |
| Greybox (generated layout block) | `tools/studio/maps/Rooftops/Greybox.luau` |
| Blender kit, previews, mesh z-fighting check | `tools/blender/build_map_kit_rooftops.py` → `art-source/maps/Rooftops/Kit_Rooftops.blend`, `References/maps/rooftops/kit-contact.jpg`, `rooftops-preview-*.jpg` |
| Export + upload | group **Kit**, asset **112960022711405**, `art-source/maps/Rooftops/Exports/` |
| Art (generated placement block), lighting | `tools/studio/maps/Rooftops/Art.luau`, `Lighting.luau` |

![Kit contact sheet](../../02%20Art/References/maps/rooftops/kit-contact.jpg)

**Kit pieces:** facade columns `Facade8A/B/C` (8 wide, 72 tall: a window on every 12-stud storey with stone sill, lintel and mullion, pilasters, frieze and cornice; three lit patterns) and `Facade4`; `Plinth8/4` (the towers' street storey); `Quoin` (corner stones and the cornice's corner block); `Flue`; `Stair16`, `Gangway16`, `PlankRamp16`, `Catwalk8`; `ACUnit`, `Condenser`, `Skylight`, `Penthouse`, `LetterA/B`, `StairHut`, `LiftHouse`, `LiftTower`, `TankHouse`, `CoolingTower`, `WaterTank`, `Billboard`, `RoofSign`; `StreetLamp`, `CityA/B/C`, `SignTower`, `RadioMast`. Origins are listed at the top of the build script.

---

## 6. Build and run (for the hub)
In the **match place**, edit mode (Command Bar or the Studio MCP). Everything is re-runnable.
1. Kit: `python tools/studio/maps/kit_bundle.py Rooftops Kit -o rooftops_kit.luau`, run it (`ServerStorage.MapKit.Rooftops`, 32 pieces).
2. Map: `python tools/studio/maps/bundle.py Rooftops Greybox Art Lighting -o rooftops.luau`, run it. Expect `Rooftops greybox: 408 parts, 4 + 4 spawns, 2 barriers, KillDepth 24`, `Rooftops art: 234 of 234 kit pieces placed, 13 art Parts, 97 greybox parts hidden; all kit pieces found`, then the lighting line. (The greybox alone: `bundle.py Rooftops Greybox`.)
3. Audit: `Audit.luau` with `"Rooftops"`: expect **0** (the offline triangle check is 0).
4. Play: `Workspace.ForceMap = "Rooftops"`, a 2-player test (MapService applies the lighting). For edit-mode lighting screenshots set `PREVIEW = true` in `Lighting.luau` for that run only and don't save the place with it.
5. Save the place and back up `art-source/maps/Rooftops/Rooftops.rbxm`.

### What to check in screenshots
- **Facades:** columns flush on every building face (windows on the storey rhythm, cornice under the parapet, quoins on every corner), none behind the flues, the towers' stone plinth at the street; nothing see-through where a body is hidden.
- **Kit axes:** stairs climb from the Pit to the footbridge; gangway and plank ramp rise from the team roof to the tower; the Penthouse doors face the spawn court and the letter faces the middle; each billboard advert faces the roof it overlooks; the roof sign reads the right way on both faces; tank-house doors face the roof, not the parapet.
- **Tints:** A's walls red brick, B's slate blue, towers and Pit sandstone; west sign pink, east amber; the sign tower's windows warm (only its HOTEL letters pink).
- **Readability:** a player against B's slate brick and against a dark roof, first person; raise OutdoorAmbient if they're lost. Greyscale and no-shadow (quality 1–3) views. Where the low light comes from at ClockTime 18.45 (`GetSunDirection` / moon): if it's too dark, ClockTime 18.1 brings the last sun back.
- **Edges and falls:** stepping off a ledge into an alley dies at y −24 (about half a second, well above the street); parapets and rails stop a walk; a Dash across an 8 alley works.
- **Budget:** about 828 MeshParts and 177k triangles; 6 lights.
