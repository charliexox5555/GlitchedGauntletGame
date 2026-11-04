# Rooftops

A small outdoor map for 1v1 and 2v2: a fight across the roofs of one city block at blue hour, just after sunset. Two team buildings face each other over a lower middle roof (the **Pit**) and two side towers, joined by bridges and steel stairs, with the street 72 studs below. See [Maps](00%20Maps.md) for the roster.

**Status (2026-11-03):** concept. Map id `Rooftops`, world origin **(1500, 200, 1500)**, modes 1v1 and 2v2 (`Config.Match` MAPS already lists it: minTeam 1, maxTeam 2).

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

## 3. Layout (concept)
Team A at −Z, team B at +Z, 180° rotation. Map space: origin on the team roofs' surface at the map centre.

| Place | Size (studs) | Height | Job |
|---|---|---|---|
| **Team roof** (A / B) | 96 × 48 | 0 | The spawn building. Spawn behind the **Penthouse** (the stair house, full cover), AC units and a water tank as cover, skylights as half cover |
| **Pit** (centre) | 40 × 32 | −8 | The middle roof, 8 below. A lift room in the centre (full cover), AC units and condensers. A steel **stair** at each end climbs to a short footbridge onto a team roof |
| **Side towers** (west, east) | 20 × 16 | 0 | Small roofs between the team roofs, each with a stair hut and a billboard. A **catwalk** (rails) joins a tower to one team roof and a **plank** (no rails) to the other |
| **Alleys** | 8 wide (Pit ↔ roofs, Pit ↔ towers), 16 (towers ↔ roofs) | street at −72 | The fall. 8 is a sprint jump, 16 is a bridge or a Dash |
| **Edges** | parapet 3 on the outer edges and round the Pit; a 1-high ledge along the alleys | | Half cover on the outside; along the alleys you can step off |

**Heights:** −8 (Pit), 0 (roofs, bridges, towers), and Updraft-only tops (lift room +4, huts +9, penthouses +11, tank tops). Kill height: **KillDepth 24** (y −24 in map space), 16 below the Pit, 48 above the street, so a fall ends in under half a second.

---

## 4. Look (concept)
- **Time:** blue hour, about 20 minutes after sunset. Sky deep blue overhead, paler at the horizon, no sun shadows; cool, bright ambient so players stay readable; warm windows lit on about a quarter of the facades; a vertical neon sign on a skyscraper to the west and a lit radio mast to the east as landmarks.
- **Buildings:** team A's building warm red-brown brick, team B's cool grey-blue painted brick, the Pit and towers sandstone. Brick parapets with pale stone coping; dark membrane roofs.
- **Side colours:** the west billboard and sign glow pink, the east ones amber, so "pink bridge" and "amber bridge" are callouts. Team colours (cyan `#00E5FF`, orange-red `#FF5A36`) stay reserved for players and abilities.

## 5. Build plan
1. Concept (this note).
2. Layout and checks: `tools/maps/rooftops_layout.py` → `References/maps/rooftops/rooftops-layout.svg`, with a coplanar (z-fighting) check on every placed box.
3. Greybox: `tools/studio/maps/Rooftops/Greybox.luau` (generated layout block).
4. Blender kit: `tools/blender/build_map_kit_rooftops.py` → `art-source/maps/Rooftops/Kit_Rooftops.blend`, contact sheet, assembled previews and a mesh-level coplanar check; export and upload.
5. Art and lighting: `Art.luau`, `Lighting.luau`.
