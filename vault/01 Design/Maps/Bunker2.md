# Bunker2: the Sunwell Bunker rebuilt to the standard (2026-11-06)

A new version of [Bunker](Bunker.md) built to the [Map Quality Standard](Map%20Quality%20Standard.md). The user's v3/v4 complaints ([Maps v3 Review](../../05%20Production/Playtests/2026-11-05%20Maps%20v3%20Review.md), [Maps v4 Review](../../05%20Production/Playtests/2026-11-05%20Maps%20v4%20Review.md)) were smooth plastic primitives, part-built text, blank signs, floating parts, wrong scale, misaligned arrows, mixed colours, too dark, and no character. Each of those is a check below.

- **Map id:** `Bunker2`, match place, origin **(-3000, 200, 1500)** (checked free 2026-11-06: the nearest maps are Dockyard2 at (-3000, 200, 0) and Bunker at (-1500, 200, 1500)).
- **ForceMap only.** It isn't in the `Config/Match` pool until the user approves it.
- **Old map untouched:** `Bunker` and its scripts stay as they are.
- **Scripts:**
  - layout: `tools/maps/bunker2_layout.py`
  - placements: `tools/maps/bunker2_art.py`
  - palette: `tools/maps/bunker2_style.py`
  - kit: `tools/blender/build_map_kit_bunker2.py`
  - textures: `tools/textures/make_bunker2_textures.py`
  - Studio: `tools/studio/maps/Bunker2/{Greybox, Art, Lighting}.luau`
- **Art:** `art-source/maps/Bunker2/` (concepts, kit .blend, exports, textures).
- **Shots:** `vault/02 Art/References/maps/bunker2/`.

**A call made without the user:** the standard asks for approved concepts before modelling. The concepts ([01 overview](../../../art-source/maps/Bunker2/concepts/01-overview.png), [02 hero](../../../art-source/maps/Bunker2/concepts/02-hero.png), [03 kit sheet](../../../art-source/maps/Bunker2/concepts/03-kit-sheet.png)) aren't approved yet, but the core chat's overnight brief said to go ahead and decide by the standard. They're used as quality references, not blueprints. If the user rejects their look, the palette and kit change, and the layout doesn't.

![Kit sheet concept](../../../art-source/maps/Bunker2/concepts/03-kit-sheet.png)

## Identity
**"A warm concrete shelter around one hot column of sunlight."** It's the Lobby's bunker family (board-formed concrete, brass, warm coves), but a working one: painted lower walls, steel doors, machines.

| | |
|---|---|
| Landmark | The **sun shaft** in the sunwell: the skylight at +64 with a steel truss, the beam on the sun plinth (8.5 tall with a gold pyramid cap) and the brass star compass. The shaft (64) is 2.5× the next-tallest space (the sunwell ceiling at 26). |
| Heights | Floor 0; plinth top 8.5 (Updraft only); ring and overlooks +12; ceilings 12 (rooms) and 26 (sunwell, galleries); skylight 64. That's 3 playable heights plus the shaft. |
| Zone colour | Sides read by **tone**, not team colour. The B end is a cobalt paint band (`3A5DB4`) and the A end an amber band (`D9A033`). The shared middle (sunwell, pump rooms) has no band, only olive paint and brass. Team cyan `00E5FF` and orange-red `FF5A36` stay in the UI. |
| Story groups | B and A each have a **Lockers** room (lockers, a bench, kit bags, a cleaning cart), a **Control** room (server racks, desk, monitors, a cable tray), a **Gallery** (generators behind brass rails, a jammed blast door with a hazard leaf) and a **Vestibule** (supply cage, hard-case stacks). The shared **Pump rooms** have a pump skid, a valve manifold and pipes into the ceiling. |
| Light | Bright, readable shade everywhere: warm cove strips under every header, cage lamps on the piers, and one warm column of sun. It's lighter than the Lobby, because "too dark" was a v4 complaint. |

## Layout (unchanged)
`bunker2_layout.py` is a copy of `bunker_layout.py` with a new id and origin, so every number in [Bunker → Layout](Bunker.md) holds. All checks pass:

| Check | Result |
|---|---|
| Spawn to spawn | 193 studs walked |
| First sight | 4.5 s walking |
| Spawn safety | 0% |
| Longest line | 82 studs |
| Distance to full cover | worst 8.7 studs |
| Overlaps / coplanar | 0 / 0 |

![layout](../../02%20Art/References/maps/bunker2/bunker2-layout.svg)

## Palette (single table; `tools/maps/bunker2_style.py` holds the same roles)
| Slot | Roles and colours | Material / variant |
|---|---|---|
| Walls (upper, structure) | Board `A39C91`, BoardLight `B4ADA2` (sunwell, shaft, plinth), Ceiling `8E887F` | Concrete / `Bunk2_Board` |
| Lower walls (paint) | Olive `5F6B53`; LockerGreen `5C6A50` | Plastic / `Bunk2_Paint` |
| End bands (route tone) | B cobalt `3A5DB4`, A amber `D9A033`, middle none | Plastic / `Bunk2_Paint` |
| Floors | Room `77736C`, Sunwell `B3AB9E`, Deck `948E85`, Dais `C2B9AA` | Concrete / `Bunk2_Floor` |
| Steel | Steel `4D5258` (frames, beams, doors), SteelDark `3A3E43` (kick plates, skirts; lifted above luminance 0.06) | Plastic / `Bunk2_Steel` |
| Machines | Machine `767C80` (generators, pumps), Pipe `828A8F`, Case `5B6049` | Plastic / `Bunk2_Brushed` and `Bunk2_Paint` |
| Accent (the one warm metal) | Brass `C29B52` (rails, trims, compass), Gold `DDB45A` (plinth cap) | Plastic / `Bunk2_Brass` |
| Hazard | Hazard `E2B23E`, Ink `2C2E31` | SmoothPlastic |
| Glow | Cove `FFDDB0`, Lamp `FFD49A`, Screen `A6DCEB` (small), Status `FFB547` (tiny LEDs) | Neon |
| Sign art | Plates `30353A`, letters `E9E3D3` (rendered font decals) | decal |
| Team colours | none on the map | — |

No Roblox `Metal` anywhere (it mirrors the sky). Near-blacks sit at or above luminance 0.06.

## Kit (Blender, real bevelled meshes)
Bevels: concrete 0.3–0.45 on piers and pilasters, 0.12–0.2 on steel. Nothing is thinner than 0.2, and rail posts are ≥ 0.4. Board-form joints, tie holes, chips and plate seams live in the textures. The meshes carry the big forms: skirt, paint, band, header, pilasters, frames and bolts.

| Group | Pieces |
|---|---|
| Walls | `Wall12` / `Wall10` (dark steel kick, olive paint with a chamfered top edge, an end-colour band, board-formed field, a steel header with a warm cove), `Field14` (upper courses), `CornerPier12` / `CornerPier14` (concrete corner piers with chamfers and a steel cap), `Pier12` (a pilaster with an olive base, every 16 studs on long walls), `WallLamp` (a cage bulkhead on the piers) |
| Doors | `DoorFrame` (8 × 10: concrete jamb piers, a steel lintel with a cove, glow strips beside the opening, a sign plate with a rendered name on both faces), `BlastDoor` (a thick frame, a cross-braced leaf jammed open, hazard stripes at its foot, a hinge drum, bolts) |
| Sunwell | `SunDais` (stepped stone dais, an inlaid brass star compass with 16 points), `SunPlinth` (board-formed courses, chamfered corners, a gold pyramid cap with a brass collar), `ShaftPanel8`, `Skylight` (a steel truss: a perimeter ring, diagonal bracing and glazing bars, glass), `Beam8` and `Corbel` (concrete downstand beams on steel brackets) |
| Ring and stairs | `RingEdge8` (concrete fascia with a cove under the slab), `Rail8` (brass rail: 0.4 posts, a top rail and a mid-rail, on a concrete upstand), `GalleryStair` (concrete flight with steel nosings, brass handrails on both sides, a stringer) |
| Props | `Gen46` / `Gen66` (generator: radiator fin pack, control box, exhaust, skid, brass guard rail), `PumpUnit` (pump skid with a motor, volutes, valve wheels and pipe elbows into the ceiling), `Manifold`, `Lockers4` / `LockerIsland` (olive lockers with louvres, handles, a nameplate rail and a bench), `Rack4` (server racks with mesh doors and amber LEDs), `Console8` (control desk with screens, buttons and a monitor hood), `CaseStack` / `CaseRow` (hard cases with brass corners, latches and handles), `CableTray8`, `PipeRun8` |
| Fixtures | `LinearLight` (a steel housing with a diffuser), `CageLamp`, `HazardSill`, `SpawnPanel` (a big end letter on a plate, rendered) |

Budget: map ≤ 450k tris; repeated props ≤ 800; hero pieces 5–12k; visible MeshParts about 1.7–2.5k.

## Textures (6 variants at 512, colour plus normal, near-white, tinted by `Color`)
Made by script (`tools/textures/make_bunker2_textures.py`, numpy), from the concept's swatch row:

| Variant | What it carries | Studs per tile |
|---|---|---|
| `Bunk2_Board` | board-formed concrete: 0.5-stud board lines, panel joints every 4 × 2, tie holes, soft blotches | 8 |
| `Bunk2_Paint` | painted concrete: chipped edges, scuffs, roller texture | 8 |
| `Bunk2_Floor` | honed concrete: saw cuts every 8, speckle, faint scuffs | 16 |
| `Bunk2_Steel` | painted plate: seams, rivet rows, edge wear | 8 |
| `Bunk2_Brushed` | brushed steel streaks | 4 |
| `Bunk2_Brass` | brushed brass with faint wear | 4 |

**A call made without the user:** the standard asks for one 1024 trim sheet cut from an approved trim-sheet concept. There's no trim-sheet concept for Bunker2, so the six variants are made procedurally from the kit sheet's swatches. All of them are 512, so the budget stays under the 1024-sheet allowance.

## Text and signs
- No letters are built from parts. Door plates carry the room name as a decal, rendered from a real font (Bahnschrift Bold Condensed, a DIN-style stencil look) into the palette, plus a small arrow pointing at the room.
- The spawn panels carry a big **A** or **B** with "SPAWN".
- Every plate sits on a bolted steel mount.

## Results
Per version and round, below.

## v1 results (2026-11-06 overnight)
Installed in the match place at (-3000, 200, 1500), ForceMap only. It isn't in the pool. **The place needs saving (Ctrl+S); the core chat saves it.**

**Kit and checks:**
- 35 pieces, 42.8k unique triangles, in-piece coplanar 0.
- Dressed map:
  - 717 placements, about 2.6k MeshParts, about 382k triangles (budget 450k);
  - dressed coplanar check 0 (43k face rectangles);
  - Studio `Audit.luau` 0 pairs;
  - `FloatAudit` 0 floating groups (2,682 parts).
- Layout checks all pass (unchanged from Bunker).

**Rounds and blind scores:**

| Round | Changes | Reviewer scores | Median |
|---|---|---|---|
| r1/r2 | First install. Palette re-valued for Roblox (textured Plastic renders about 1.4× brighter and warmer than its hex). Room PointLights at 0.75. Valve wheels as rims and spokes. Brass railing redesign. Floor guide lines. Spawn dressing. | 4.17 / 3.75 / 5.00 | **4.17** |
| r3 | Amber cove strips (Neon brightens hugely: `8A6446` renders amber). Lamp pools on every cage lamp (about 78 shadowless PointLights). Sunbeam plus a plinth spot. Hazard sills at every door. Calmer bands. Darker ambient. | 5.00 / 6.67 / 5.83 | **5.83** |
| r4 | One bevelled monolith plinth with a steel base and a band. Unlit cove trims instead of orange Neon. Metal brass rails. Plain ceiling. Darker floors. Per-room lower-wall paint (olive lockers, slate control, oxide-red pump rooms). Bigger cage lamps. | 5.00 / 4.58 / 6.25 | **5.00** |
| r5 | Clean enamel props (no lumpy paint texture). SmoothPlastic ceilings (Roblox Concrete read as brown smudges). Lower ambient. Lamp pools 0.8 / 14. Darker screens. | 5.00 / 6.25 / 6.25 | **6.25 (best)** |

**What the reviewers agreed on:**
- *Better:* the sunwell landmark, signs, floor lines, hazard thresholds, cohesion of concrete, olive and steel, and the lockers and pump room.
- *Still short:*
  - the plinth read as stacked boxes (fixed in r4);
  - the generator blocks the hero sightline from the SW corner;
  - no visible stair from the sunwell floor to the ring (that's the layout: the ring is reached from the overlooks);
  - flat orange or white strips (fixed in r4);
  - the spawn ceiling looks blotchy (r4 made it plain);
  - corridors look alike (r4 room paint);
  - pump motors are plain cylinders.

**Stopped after r5, a call made without the user.** The stop rule hadn't fired: r5 gained +1.25 over r4 and +0.42 over r3. I stopped anyway to give Snowpeak2 the rest of the night. Every reviewer's remaining asks are structural:
- **A visible way up to the ring from the sunwell floor.** That changes the layout, which was kept on purpose, so it's the user's call.
- **Prop rework in Blender:** detailed motor, generator and console meshes, and a sunburst plinth.
- **Bigger, contrasting lamp pools.** Edit captures understate local lights, as the Lobby showed.

During r4 the shared match Studio was reset twice by another lane. The core chat then gave lane A a clean window.

Best shots so far:

| Concept | Build |
|---|---|
| ![](../../../art-source/maps/Bunker2/concepts/02-hero.png) | ![](../../02%20Art/References/maps/bunker2/v1-r5-hero.jpg) |
| ![](../../../art-source/maps/Bunker2/concepts/01-overview.png) | ![](../../02%20Art/References/maps/bunker2/v1-r4-sunwell.jpg) |
| ![](../../../art-source/maps/Bunker2/concepts/03-kit-sheet.png) | ![](../../02%20Art/References/maps/bunker2/v1-r5-pump.jpg) |

Spawn A and its amber band: `v1-r4-spawn-a.jpg`. Corridor with pier lamps: `v1-r4-corridor.jpg`.

**Ready for approval?** No. The best round is **6.25 (r5)**, under the 8.5 bar. Navigation and scale reach 2 for some reviewers; composition, lighting and detail stay at 1. Biggest remaining gains:
1. a visible stair or ladder cue toward the ring from the sunwell floor (a decor cue, since the layout stays as it is);
2. motor and generator detail (fins, junction boxes, conduit);
3. moving the sunwell generator's hero-view block with a smaller console (a layout change, so it needs the user).

### For the user (layout; not built)
- **A visible stair from the sunwell floor to the ring.** Every reviewer asked for it. Today the ring is reached only from the gallery overlooks. Adding one changes sightlines and the ring's strength, so it needs `bunker2_layout.py` and its checks.
- **The sunwell generator** blocks the hero view of the plinth from one corner. Swapping it for lower cover is a layout change.
