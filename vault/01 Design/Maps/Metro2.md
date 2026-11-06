# Metro2 (new version of Metro)

Metro rebuilt to the [Map Quality Standard](Map%20Quality%20Standard.md). Lane F builds it, overnight on 2026-11-06. The layout, lanes and measured numbers come from [Metro](Metro.md) unchanged. The old map stays as it is: its files, its Studio model `Workspace.Metro` and its Config rows.

- **Map id** `Metro2`, **origin (3000, 200, 1500)**. That spot was checked free in the match place on 2026-11-06: Rooftops2 ends near z 450.
- **ForceMap only:** `workspace:SetAttribute("ForceMap", "Metro2")`. No `Config/Match` change until the user approves.
- **Status (02:00):** kit, textures, signs and art built; installed in the match place.
  - Studio z-fighting audit: **0 pairs** (1,937 visible parts).
  - FloatAudit: 42 groups fixed down to 2; the last fix is pending a re-audit.
  - Round 1 scoring is next.

## Calls made without the user (they're asleep; decided by the standard)
| Call | Why |
|---|---|
| **No board approval before modelling.** The core chat said to decide by the standard. | The board and concepts still go in this note for the user to judge in the morning. |
| **A end is sage green, not yellow.** B stays cobalt. | Standard §3 Palette: no second landmark colour. The landmark is the amber departure board, and Metro's yellow end competed with it. Both are far from team cyan and orange-red. |
| **The landmark is the departure gantry with its clock.** The trains are the secondary identity. | Indoors, the 1.5× height rule can't apply under a 28-stud ceiling. The gantry is the one unique silhouette in the middle, the brightest thing (amber), and both spawns see it from their terrace. |
| **Daylight through a skylight slot** over the trench, plus a lit coffered vault. Metro was ClockTime 0, Brightness 0. | User complaint "maps too dark". Standard §3 Lighting: bright and readable. A skylight is real metro architecture (Canary Wharf, Westminster) and gives a sun shaft and a warm-cool split. |
| **Textures are made procedurally** (tile, terrazzo, concrete, steel, ballast, train panel). They're not cut from a Codex trim sheet. | Codex's job is the concepts. Procedural textures keep the 6-variant budget and are near-white, so they tint. The call is noted, so a Codex trim sheet can replace them later. |
| **Signs are rendered text textures** on modelled plates: MERIDIAN, platform numbers, the departure rows, the clock face, the route map. | Standard §3 Text: real fonts on real plates. No SurfaceGui text, no part-built letters. |

## Identity brief
- **Sentence:** *Meridian Interchange on opening morning: a bright white-tiled hall under a coffered concrete vault, with a daylight slot over the tracks, two parked trains, and the big amber departure board and clock hanging over the middle.*
- **Story groups:**
  1. **Night works left behind:** a track-maintenance trolley on the open rail by the A end, with cones, a lifted cable-trough lid and a coiled hose (in the trench, by the wall, out of the lane).
  2. **The coffee kiosk opening up:** its shutter half raised, stacked cups, a crate of milk, two stools.
  3. **Lost property:** a suitcase and an umbrella left by a platform bench, with a "Mind the gap" floor mark nearby.
- **Not this:**
  - dark tunnels, rubble or floods (BF3 Métro);
  - neon cyberpunk;
  - grime, graffiti, water stains or flicker;
  - a maze of identical tunnels;
  - ad walls everywhere;
  - smooth plastic boxes;
  - real brands or logos;
  - team cyan or orange-red on the map;
  - a second yellow.

## References (third-party, never committed)
`vault/02 Art/References/maps/metro2/third-party/` holds the reference board, git-ignored like the others. Sources:
- [Canary Wharf Jubilee line station](https://en.wikipedia.org/wiki/Canary_Wharf_tube_station): a huge clean concrete hall with daylight.
- [Washington Metro coffered vaults](https://docomomo-us.org/news/the-vaulted-architecture-of-the-metro-that-almost-wasn-t): the coffer rhythm.
- [Toronto TTC tile signage](https://transittoronto.ca/subway/5009.shtml): the station name in tile, the end-colour trim.
- Valorant and RIVALS for readable colour per zone.
- The modelling reference is the [Metro kit](Metro.md) (28 pieces), which the user liked. Metro2 keeps its sizes and doubles its detail.

LihFolk notes this plan uses:
- [Level Design Principles - Flow Sightlines and Landmarks](../../LihFolk/33%20Level%20Design/Level%20Design%20Principles%20-%20Flow%20Sightlines%20and%20Landmarks.md)
- [World Composition and Set Dressing - Designed, Not Scattered](../../LihFolk/06%20World%20Building%20and%20Art/World%20Composition%20and%20Set%20Dressing%20-%20Designed%2C%20Not%20Scattered.md)
- [Zone and Biome Art Direction](../../LihFolk/06%20World%20Building%20and%20Art/Zone%20and%20Biome%20Art%20Direction.md)
- [Colour Scripts and Value Structure for Untextured Art](../../LihFolk/54%20Untextured%20Stylised%20Modelling/Colour%20Scripts%20and%20Value%20Structure%20for%20Untextured%20Art.md)
- [Hard-Surface Modeling](../../LihFolk/14%203D%20Modeling/Hard-Surface%20Modeling.md)
- [Bevels Chamfers and Edge Highlights Without Textures](../../LihFolk/55%20Modelling%20Nuance%20and%20Readability/Bevels%20Chamfers%20and%20Edge%20Highlights%20Without%20Textures.md)
- [Modelling to the Roblox Camera and Player Scale](../../LihFolk/55%20Modelling%20Nuance%20and%20Readability/Modelling%20to%20the%20Roblox%20Camera%20and%20Player%20Scale.md)
- [Stylized Lighting Recipes](../../LihFolk/07%20Lighting%20VFX%20and%20Audio/Stylized%20Lighting%20Recipes.md)
- [Art Budgets - Triangles Draw Calls Memory](../../LihFolk/06%20World%20Building%20and%20Art/Art%20Budgets%20-%20Triangles%20Draw%20Calls%20Memory.md)

## Layout (kept)
From [Metro §3](Metro.md#3-layout) through `tools/maps/metro2_layout.py`, which re-runs `metro_layout.py`'s checks and writes `tools/studio/maps/Metro2/Greybox.luau` at the new origin. The collision boxes are the same.

**Heights:**

| Level | Height |
|---|---|
| Trench | −4 |
| Platforms, corridors | 0 |
| Train roofs | +10 |
| Terraces | +14 |
| Ceiling | 28 |

**Standard §2 checks:**
- 180° symmetry.
- Three lanes: west platform, trench, east platform.
- Spawns never see each other.
- First contact at 7.4 s walking.
- Terrace perch share: 35% of the enemy half.

## Palette (single table; `tools/maps/metro2_style.py` carries the same roles)
| Slot | Role | Colour | Surface |
|---|---|---|---|
| Walls | Tile (field) | `E9E6DE` warm white | `Metro2_Tile` |
| Walls | Vault (upper walls, ceiling, coffers) | `BDB8AE` warm concrete | `Metro2_Concrete` |
| Stone and trim | Granite (plinths, copings, column bases) | `8C8780` | `Metro2_Terrazzo` |
| Stone and trim | Trim (cornices, frames on tile) | `D9D4CA` | SmoothPlastic |
| Floors | Terrazzo (platforms, concourse) | `CFC9BD` | `Metro2_Terrazzo` |
| Floors | Ballast (trench) | `77726B` | `Metro2_Ballast` |
| Floors | Sleeper | `85796B` | SmoothPlastic |
| Floors | Tactile strip | `B89A5E` muted ochre (not the landmark amber) | SmoothPlastic |
| Steel | Charcoal (gantry, rails, frames, handrail posts) | `434851` | SmoothPlastic |
| Steel | Stainless (columns' shoes, kiosk, gates) | `B7BBC1` | `Metro2_Steel` |
| Steel | Rail head | `A9ACB0` | SmoothPlastic |
| Machines | Train body | `D4D7DB` | `Metro2_Panel` |
| Machines | Train dark (glass frames, skirts, bogies) | `4A4F57` | SmoothPlastic |
| Machines | Oak (kiosk counter, benches) | `A77C55` | SmoothPlastic |
| Accents | End B, cobalt (bands, train stripe, portal trim) | `2F5FBF` | SmoothPlastic |
| Accents | End A, sage green | `3C8C6C` | SmoothPlastic |
| Accents | Mid (bands on the middle bays) | `5B6270` | SmoothPlastic |
| Glow | Coffer light | `E8EEF4` | Neon |
| Glow | Board amber, the landmark's colour only | `FFB547` | Neon |
| Glow | Kiosk warm | `FFD9A8` | Neon |
| Glass | Glass | `9FB4C2`, transparency 0.55 | Glass |
| Sign-art tint | Sign art | `EDE9E0` | decal |

**Value plan:**
- The trench is the darkest band (luminance about 0.17).
- Platforms are mid.
- Tile walls are light.
- The vault is mid-light, with glowing coffers.
- Players (the 5-stud dummy, about 0.35) stand out against the white tile and the dark trench.

## Lighting
- **Base:** the golden-hour recipe (LihFolk Stylized Lighting Recipes §3.3), lifted for indoors:
  - ClockTime 13.5, sun high through the skylight;
  - Brightness 2.6;
  - Ambient about (150,152,160), OutdoorAmbient about (168,172,184), with Ambient ≤ OutdoorAmbient;
  - ExposureCompensation 0.25;
  - Bloom threshold 1.1;
  - haze off (it's indoors).
- **Practical light:** Neon coffer panels, pendant tubes and the board glow. PointLights don't show in edit captures.
- **Checks:** the greyscale test and the no-shadow test (§3 Lighting).

## Kit (`tools/blender/build_map_kit_metro2.py` → `art-source/maps/Metro2/Kit_Metro2.blend`, group `Station2`)
Same piece names and origins as the Metro kit, so the Art script's placements carry over. Each piece is rebuilt at the §3 finish:
- bevels: steel 0.12–0.2, stone 0.3–0.45;
- 0.05+ insets;
- undersides dressed;
- nothing thinner than 0.2.

| Piece | Metro had | Metro2 adds |
|---|---|---|
| `WallBay8` / `WallEnd4` / `WallDoor8` | flat tile bands | A granite plinth with a chamfered cap, a tile field (tile texture, 0.06 proud), a dado tile band in the end colour with a steel bead, a cornice with a cove light lip, pilasters with steel shoes and caps every 8, and a framed lightbox or route map on alternate bays |
| `Coffer10` / `Coffer14` | 30-tri trays | Deep coffers with chamfered ribs, a recessed glowing panel in a steel frame, and a beam soffit below |
| `Skylight` (new) | none | A glazed slot over the trench: steel mullions, a chamfered concrete upstand, and glass |
| `Column` | a box | A tile-clad column with radiused corners, a stainless shoe, a band in the end colour, a capital and a bracket for a hanging sign |
| `PlatformEdge8` | a block | Granite coping with an overhang lip, a tactile strip with modelled domes in rows, a white line, and the platform face with a dark recess and a refuge under it |
| `TrackBay8` | rails | Concrete sleepers with fastening clips, rails with a head profile, a cable trough with a lid, and a ballast bed (texture) |
| `Train` | a body with stripes | A curved roof profile, a window band with frames, doors with frames and grab bars, a skirt with equipment boxes, two bogies with wheels and springs, an end cab with a windscreen, headlights and a destination screen (text texture), and a gangway bellows with ribs |
| `Gantry` | a board | A steel truss gantry with hangers, the departure board (rendered rows: times, destinations, platforms), the round station clock (rendered face, steel bezel) and platform signs |
| `EndWall` | a portal | A segmental tunnel portal with lining rings, the MERIDIAN name panel (rendered, on a bolted frame), signals on brackets, buffer stops and the terrace parapet with a glass balustrade |
| `EscalatorBank` / `HallStairs` / `CorridorStair` | slabs | Balustrades with glass panels and handrails, step nosings, and stringers in charcoal (the route language: dark against light tile) |
| `Kiosk`, `Vending`, `Bench`, `FareGateRow`, `TicketOffice` | boxes | Modelled to scale: a counter with a shutter, products and a menu board; machine fronts as rendered textures; a slatted oak bench on steel legs; gates with glass paddles and readers |
| Story props (new) | none | `MaintTrolley`, `Cone`, `CableLid`, `HoseCoil`, `Suitcase`, `Umbrella`, `MilkCrate`, `CupStack`, `Stool`, `Bin`, `Extinguisher`, `CCTV`, `Speaker`, `HelpPoint` |

**Budgets:**
- Map ≤ 450k visible triangles.
- Repeated props ≤ 800 tris.
- The train ≤ 12k.
- Textures: 6 MaterialVariants at 512 (`Metro2_Tile`, `Metro2_Terrazzo`, `Metro2_Concrete`, `Metro2_Steel`, `Metro2_Ballast`, `Metro2_Panel`), plus sign art at 1024 or less.

## Codex prop list (Metro2)
Lane F models the whole kit itself. Codex is asked only for sign art: no props, because its budget is small.

| # | Asset | Size | Notes |
|---|---|---|---|
| M1 | 4 poster artworks for platform lightboxes (fictional brands: a coffee, a museum show, a city-break rail pass, a phone network) | 1024 × 1536 PNG, portrait | No real logos. At most 3 words each. Calm colours that sit in the palette (warm whites, cobalt, sage, one warm accent). Path: `art-source/maps/Metro2/textures/posters/`. |

## Build and run order
1. **Layout:** `python tools/maps/metro2_layout.py --luau`. It re-runs Metro's checks and writes `tools/studio/maps/Metro2/Greybox.luau`.
2. **Style:** `python tools/maps/metro2_style.py --luau`. It writes the STYLE block into `Art.luau` and the LIGHT block into `Lighting.luau`.
3. **Textures and signs:** `python tools/textures/make_metro2_textures.py --preview`.
   - Writes 6 variants plus sign art to `art-source/maps/Metro2/textures/`.
   - Upload each image with `tools/opencloud/upload_asset.py --type Decal`.
   - Resolve the Image ids in Studio (`InsertService:LoadAsset(decal).Decal.Texture`).
   - Ids go in `metro2_style.py` VARIANTS and in `Art.luau`'s IMAGES block.
4. **Kit:** `blender --background --factory-startup --python tools/blender/build_map_kit_metro2.py -- [--no-render]`.
   - Writes `art-source/maps/Metro2/Kit_Metro2.blend` and the contact sheet `vault/02 Art/References/maps/metro2/kit-contact.jpg`.
   - Export: `export_lobby_kit.py -- --maps Metro2 Station2`.
5. **Offline z-fighting:** `python tools/studio/maps/zfight_check.py Metro2 Station2`. Target: 0 in both the polygon and bounds passes.
6. **Upload:** `python tools/opencloud/upload_models.py --maps Metro2 --group 11116787 Station2`. Asset **120182985827917**.
7. **Studio (match place, holding the lock):**
   - `kit_bundle.py Metro2 Station2`, then `bundle.py Metro2 Greybox Art Lighting`.
   - Swap the PlaceId assert for a content check in the temporary bundles: `MapKit.luau` and `kit_bundle.py` still assert the Lobby's id.
   - Big bundles are staged as ModuleScripts in a temporary `assets/_MapStage/` folder, which Rojo syncs to `ReplicatedStorage.Assets._MapStage`, and run with `loadstring(Source)`. The folder is deleted afterwards and never committed.
8. **Audits:** `Audit.luau("Metro2")`, then `FloatAudit.luau("Metro2")`.
9. **Evidence:** the `Metro2` entry in `tools/maps/evidence_cameras.json`, with `PreviewLighting.luau("Metro2", "apply")` set in the same call as the capture.

## Kit as built (42 pieces, 38.3k triangles)
- **Pieces:**
  - Walls: `WallBay8`, `WallBayPoster8`, `WallBayMap8`, `WallBayPlain8`, `WallEnd4`, `WallDoor8`, `NameSign`.
  - Ceiling and hanging: `Coffer10`, `Coffer14`, `Skylight14`, `PendantLight`, `PendantLightLow`, `PlatformSign`.
  - Platforms and track: `Column`, `PlatformEdge8` / `Plain`, `TrackBay8`, `TrackBox`, `Train`.
  - Stairs: `EscalatorBank`, `HallStairs`, `CorridorStair`.
  - Landmark and ends: `Gantry`, `EndWall`.
  - Furniture: `Kiosk`, `Vending`, `Bench`, `FareGateRow`, `TicketOffice`, `Portal10`, `DoorFrame8`.
  - Service corridor: `PipeRun8`, `CorridorLight`, `PumpDoor`.
  - Props and story groups: `Bin`, `CCTV`, `HelpPoint`, `Cone`, `NightWorks`, `LostProperty`, `Delivery`, `Stool`.
- **Largest pieces:** Train 6.5k, Gantry 4.6k, EscalatorBank 3.9k.
- **Textures:** 6 MaterialVariants at 512 (`Metro2_Tile`, `Floor`, `Concrete`, `Steel`, `Ballast`, `Granite`).
- **Sign art:** 23 rendered-font sign images, plus Codex's 4 posters on the lightboxes.

![Kit contact sheet](../../02%20Art/References/maps/metro2/kit-contact.jpg)

### Fixes found in Studio (before round 1)
- **The pendants and platform signs floated.** Their rods stopped at 27.98, under the coffers. Each rod now ends in a ceiling plate that meets the coffer top or the concourse slab.
- **Other floating groups:**
  - the pipe runs (0.45 off their brackets): saddles added;
  - the escalator-mouth sign plate: hangers added;
  - the ticket-office counter: brackets added;
  - the kiosk shutter: now meets the posts.
- **Clock:** the square art showed on the round face. The dial art is now transparent outside the circle.
- **Colours:**
  - The cab glass read as a black hole; it's lifted to `56606C`.
  - The fare-gate and help-point lights rendered close to team cyan; they're warm white now.
  - The train floor was very dark; it's granite now.
- **Concourse coffers tried and dropped:** the visible greybox ceiling at 28 would cover their recesses.

## Rounds
Filled in per round: what changed, audits, shots, scores and the next list.

## Codex jobs

- **M1 (2026-11-06):** Saved four original 1024 x 1536 portrait posters: [coffee](../../../art-source/maps/Metro2/textures/posters/01_Coffee.png), [museum show](../../../art-source/maps/Metro2/textures/posters/02_MuseumShow.png), [rail pass](../../../art-source/maps/Metro2/textures/posters/03_RailPass.png), [phone network](../../../art-source/maps/Metro2/textures/posters/04_PhoneNetwork.png); Meridian palette, two-word headlines, no real logos, visually checked; built-in image_gen prompts embedded in PNG metadata (in-game distance test pending).
