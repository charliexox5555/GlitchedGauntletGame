# Foundry4 (Foundry remade)

**Status (2026-11-21): built v1, build checks at 0 / 0 / 0, in rotation** (shown as **FOUNDRY**, regular, 1v1-2v2). **Save the match place.** Map 3 of the [lineup round 2](Map%20Lineup%202026-11-21.md) run. The owner asked for this one to "really take inspiration from the museum" and to look and feel like RIVALS maps ("we're not really hitting those standards right now", "I don't really want too realistic in maps"). So it starts with a written RIVALS build study.

## RIVALS build study (2026-11-21, read-only)
Sources: the RIVALS file (`ServerStorage.Maps.Museum`, measured by script, never played or saved) and the match place copies (`ServerStorage.MapsRivals.Museum` / `Factory`, `Workspace.Docks`), captured in a temporary folder and removed. Captures (git-ignored): `vault/03 Research/Rivals Reference/third-party/maps/museum_hall_eye.jpg`, `museum_pillar_trim.jpg`, `museum_gallery_rail.jpg`, `docks_props_close.jpg`, `factory_aerial.jpg`. Background numbers: [Maps and Lobby](../../03%20Research/Rivals%20Reference/Maps%20and%20Lobby.md).

| Question | Museum | Docks / Station | What we take |
|---|---|---|---|
| Mesh vs Part | 1,206 Parts, 972 MeshParts, 4 unions; **125 unique meshes**, heavy reuse (BaseCurve_02b ×62, GrandRail ×45, ExhibitPiece ×54) | Docks 1,042 MeshParts of 98 meshes (Container ×161); Station 66 unique | Plain Part masses + a small MeshPart kit reused many times |
| How masses are built | walls, floors and ceilings are big Parts (117 over 40 studs) with tiling MaterialVariants (`StoneBlock_01a` ×665, `Concrete-02a` ×484) | floors are Parts; buildings and props are meshes | Ground, walls, decks, buildings = Parts |
| Meshes are | trims and joins: `GrandTrim_0Na/b/c` are **three stacked profiles** (cap, mid, base; 3.9 / 2.6 / 2.9 deep, each a different depth, touching exactly) wrapped round every pillar head and wall top; arch and ceiling shells; railings | chunky props with big flat chamfers: crates, drums (octagon ribs), barriers, cranes, containers | Our kit = props and hero pieces; trims as stepped Part stacks (different depths, never one plane) |
| Shape | chunky, clean silhouettes, big chamfers, stepped profiles, nothing noisy | same; round things are 8-16 flat facets | Big facets and chamfers that read at distance, flat shading |
| Materials / colour | one warm-grey family (b4afae, afa9a7, a29c9a …, ±10% value), the meshes wear **the same variants as the Parts** so joins don't show | Docks copy is flat SmoothPlastic: grey structure, flat strong accents (red / yellow cranes, orange cones) | Flat colours, soft variants without normal maps, grey structure, one accent (safety yellow) + the molten orange |
| Trim and edges | stacked trims at every junction (pillar heads, wall tops, floor edges), balustrades with chunky caps | buffer beams, ribs, rims | Plinth + trim + fascia on every wall, collars on columns, edge channels on decks |
| Props | Museum: benches, bins, exhibit cases, rope barriers, about one cluster per room; Docks: crates, drums, cones in small groups at cover spots | | Props in clusters at cover spots, each one a designed object |
| Lighting | per-map profile; the Museum has 56 lights (SurfaceLights 32, SpotLights 16) | | Warm fixture pools inside, cool night outside |
| Joins | trims touch exactly, each layer a different depth; nothing hovers | | Overlap 0.05 or step 0.05+, never one plane |

RIVALS **Factory** turned out to be a grid-textured block arena (grey + yellow), not a steel works: layout only, no look taken.

**RIVALS meshes used** (owner 2026-11-21: map meshes allowed, no logos, no scripts), in `ServerStorage.MapKit.Foundry4Rivals`, squared and pivoted at the bottom centre:

| Ours | RIVALS source (`Workspace.Docks`, match place) | Use |
|---|---|---|
| R_Barrel | `Barrel` | oil drums by the gas cage (recoloured red / blue) |
| R_PowerBox | `Power Box` (PowerUnit_01a, FireCase_01b) | on hall columns and the valve house |
| R_Roadblock | `Roadblocks/Roadblock` | the jersey barrier in each yard |
| R_Cone | `Traffic Cone` | by the pour pit and the barriers |
| R_WaterTank | `Water Tank` | on the pump-house roofs |

Not taken: crates (their `CrateBadges` carry a logo), the tall roadblock, pallet and strip light (they sat tilted in their models).

## Layout v1 (`python tools/maps/foundry4_layout.py`)
![layout](../../02%20Art/References/maps/foundry4/foundry4-layout.png)

150 × 192, **mirror symmetry across the midline** (z → -z) instead of the usual 180° turn, so the furnace (west) and the ladle (east) can sit on the midline and belong to both teams. Team A at +Z.
- **The melt shop** (x -48..48, z -32..32): a portal-frame hall with clad walls, three 12-wide doors a side, a roof with a lit monitor.
  - the **blast furnace** (the landmark, 57 tall) closes the west end of the midline, half inside its cast house;
  - the **molten runner** (8 wide) runs from the tap hole east along z = 0 into the pour pit (x 44..50); two steel plate bridges cross it; the **skimmer gate** straddles it;
  - **catwalks at +12** along both long walls (a stair at each end), joined across the runner by the walkway hung under the **overhead crane** (the high crossing);
  - cover on the cast floor: the mudgun, a slab pile, the ingot cart on its spur, a coil stack.
- **The ladle on its car** stands on the ladle track beside the pour pit (east flank lane past it).
- **Each yard:** the hot blast stove + valve house (west), a skip, two coil stacks, two slab piles, the spare ladle on its stand (east), the shunting loco on a spur (team colour), the pump house (spawn baffle, team door), gas cylinders, drums, a jersey barrier, the spawn yard.
- **The works round the bounds:** a mill shed behind each spawn (clad, lit high windows, closed roller doors, chimneys), a mill along the east edge, a concrete yard wall on the west with more stoves and a stack beyond.

**The kill zone:** the runner's and the pit's glowing surfaces don't collide; anyone who drops in falls past the map's **KillDepth 6** (authored data 423) and is downed. The edges are walkable (a 0.6 refractory kerb, yellow edge lines); railings stay low and jumpable.

| Check | v1 |
|---|---|
| Spawn gap / longest line | 174 / 211 (1.22 of the gap, 0 rays over target) |
| Pinches | 0 (the furnace against the bounds is closed off by the cast house) |
| Spawn sees spawn / enemy half sees a spawn | never / 1.4% |
| First sight | 3.6 s |
| Sprint to the centre / enemy spawn | 3.5 s / 8.9 s |
| Heights | runner (kill), ground 0, catwalks + crane walkway +12 (4 stairs); roofs, loco, ladles, ingot cart out of reach (roof guards) |

## Kit (`tools/blender/maps_foundry4/`, asset 133709238746938, `ServerStorage.MapKit.Foundry4`)
14 pieces, ~60k tris, built in its own file `art-source/maps/Foundry4/Kit_Foundry4.blend`: F4Furnace, F4Stove, F4Ladle, F4LadleCar, F4Crane, F4Stair12, F4Rail4, F4Post, F4Coil, F4IngotCart, F4Loco, F4OxyTanks (cylinders only), F4Chimney, F4SlabPile2, F4SlabPile6, F4RollerDoor. (F4ScrapBin, the F4Clad panel and F4Mudgun were dropped in the owner passes below.) Round forms are 8-12 flat facets with flat shading; chamfers are flat 1-segment cuts.

**Owner feedback on the first kit look (2026-11-21):** the ladle, the ladle car and the loco read as "curved boxes" whose parts "don't align well, they don't flush well". Cause: smooth shading across the 12 facets made them read round, the ladle's bands were straight rings on a tapered body, and the loco's louvres, rails and the car's blocks were stuck on. Rebuilt the same day:
- every kit piece is flat-shaded (each facet a plane);
- the ladle's bands and lip are revolved from one profile that follows the taper; the trunnion pads lie on their facets; the pins sit in saddles between cheeks on the car's trestles; the foot stands in a seat ring;
- the loco's hood is built in segments: full section at the door frames, a recessed section on the doors, louvres inside the recess; rails run exactly stanchion to stanchion; the cab glass is set back behind its posts; the buffer beams are striped beams below the deck line; axle boxes are one cut-cornered cap on each hub.

The same standard then went over the **ingot cart** (three plain black boxes before: now square moulds with a foot flange, a top rim, lifting lugs and the glowing ingot set into the rim, on a car of the ladle car's family) and the **mudgun** (a flared pedestal, slew ring, a boom with cut ends, the barrel hung from a clevis, a ram, a counterweight). The gas cylinders' shoulders now step 0.04 out from the body (they shared a plane).

Close-ups: [kit sheet](../../02%20Art/References/maps/foundry4/kit-sheet.jpg), [ladle, car and loco](../../02%20Art/References/maps/foundry4/close-sheet.jpg), [ingot cart and mudgun](../../02%20Art/References/maps/foundry4/close-cart-mudgun.jpg).

## Build v1 (2026-11-21)
`tools/studio/maps/Foundry4/Build.luau` at **(6000, 200, 47000)** (`Workspace.Foundry4`), authored data **423** (map: KillDepth 6, layout version) / **424** (lighting). About 1,780 parts. Rojo was connected, so the builder, the kit installer and the audit tools ran as temporary ModuleScripts synced from `src/server/FD4Dev/` (required from a clone, removed afterwards; none of it is committed).

| Overview | Furnace and tap | Cast floor |
|---|---|---|
| ![overview](../../02%20Art/References/maps/foundry4/build-overview.jpg) | ![furnace](../../02%20Art/References/maps/foundry4/chunk1-furnace.jpg) | ![floor](../../02%20Art/References/maps/foundry4/chunk2-cast-floor.jpg) |

**Materials:** Parts with soft variants already in the place, colour maps only (`R4_Concrete` floors, `R4_Asphalt` yards, `R4_Plate` decks and bridges, `R4_Brick` refractory, `R4_Render` plinths and walls); kit and steel are flat SmoothPlastic. Structure is blue-grey and charcoal; the one structural accent is safety yellow (rails, crane, collars, lintels), plus the molten orange. Team colours: A red-orange (loco, pump-house door, spawn band), B blue.

**Built the RIVALS way:** plain Part masses; every wall has a plinth, a trim and an eave fascia stepped at different depths (the Museum's stacked trims); the corrugated walls are one `F4Clad` panel reused about 300 times in a checkerboard of depths (0 / 0.05) so neighbours never share a plane; columns get a base plate and a yellow collar; decks an edge channel.

**Light:** night (ClockTime 0.5), cool ambient (92, 94, 108) and outdoor ambient (118, 126, 152), exposure 0.6; warm pools from one pendant design in the hall (spot, range 26, 0.55) and one mast-lamp design in the yards (spot, 30, 0.8); low orange point lights along the runner, at the pit and over the ladle. Neon lenses, windows and molten use dark hexes (`8C6E4C`, `4A3A2A`, `9A3410` / `B85416`) because brighter Neon clips to yellow-white; the kit's own glows and lenses are recoloured to these after the build.

**Collision:** masses, walls, decks, bridges and cover collide; kit props get invisible boxes; stairs are tilted plates (you can walk under them); roofs, the loco, the ladles, the ingot cart and the skimmer beam have roof guards (`MapBlockers`, shots pass). Railings stay low (rail top 3.2) with no guards.

## Chunk review (owner process, 2026-11-21)
| Chunk | Close captures | Found and fixed |
|---|---|---|
| 1. Furnace, runner, bridges, skimmer, ladle | [furnace](../../02%20Art/References/maps/foundry4/chunk1-furnace.jpg), [runner](../../02%20Art/References/maps/foundry4/chunk1-runner.jpg), [ladle](../../02%20Art/References/maps/foundry4/chunk1-ladle.jpg) | The molten surface sat 3 down and could not be seen from eye height: raised to -1 (still a fall-through kill). Neon molten clipped yellow: darker hexes. The skimmer's brick slab read as a wall: now a thin steel plate on a frame, legs with collars. The east mill's orange window band glowed far too strong: dark warm hex. The night was too dark and blue to read: ambient and exposure up. |
| 2. Melt shop, catwalks, crane walkway, doors | [catwalk](../../02%20Art/References/maps/foundry4/chunk2-catwalk.jpg), [cast floor](../../02%20Art/References/maps/foundry4/chunk2-cast-floor.jpg) | The pendant spots and runner glows blew the hall out to orange: brightness and range about halved. Lamp lenses still clipped white: darker lens. |
| 3. Yard | [west yard](../../02%20Art/References/maps/foundry4/chunk3-west-yard.jpg), [pump house](../../02%20Art/References/maps/foundry4/chunk3-pump-house.jpg) | Dark gaps beside the pump-house door and at its corners (the cladding stopped short): wider door frame, a header plate, L-shaped steel corner pilasters. The valve house was a plain box: a steel top band and a louvred vent; the power box moved off the vent. |
| 4. Edges, works | [overview](../../02%20Art/References/maps/foundry4/build-overview.jpg) | The world's ground sat 0.1 under the buildings (they floated): all ground tops at 0. The east mill is one building now (it was three that met in shared planes). |

## Checks (owner 2026-11-21: build checks only)
| Check | Result |
|---|---|
| Z-fight (`Audit.luau`) | **0** (first run 75: bottom faces of wall piers, mill columns and plinths at y 0, the stand rails' ends, rail posts where the catwalk meets the walkway, the cast-house cladding under its roof, the east mill's three parts, kerb and lining ends, the gas cylinders' shoulders, two drum lids at one height; all fixed at the source) |
| Floating (`FloatAudit.luau`) | **0** (first run 560: the outer ground 0.1 low; then pendant rods crossing the trusses without a vertex inside, the mill windows and pump lamps 0.2 off their walls) |
| Coincident slopes (`SlopeAudit.luau`) | **0** (13 rotated parts) |
| Note | 5-10 meshes cannot be read as EditableMesh (RIVALS props, some kit parts), so the audits test them as boxes |

## ChatGPT concept prompts (for the owner later)
1. *Overview:* "Stylised Roblox shooter map in the style of RIVALS, three-quarter aerial view at night. A steel works: a long blue-grey steel melt shop with corrugated walls and big doors, a tall dark blast furnace at one end with yellow platform rails, pipes and a bustle ring, a glowing orange molten-iron channel running down the middle of the hall into a pour pit, a ladle on a yellow rail car beside it, catwalks with yellow railings and an overhead yellow crane. Outside: hot blast stoves with domed tops, coil stacks, slab piles, a red shunting locomotive, a small pump house, gas cylinders in a cage. Chimneys with red and white bands, mill sheds with warm high windows. Chunky clean shapes, flat colours, warm lamp light against a cool night."
2. *Player view:* "First-person view on a steel works cast floor at night: a glowing orange channel of molten metal with a low brick kerb and yellow edge lines, a steel plate bridge with yellow rails, a yellow overhead crane with a hanging walkway above, an ingot-mould car, coil stacks, warm pendant lamps under a dark roof. Stylised Roblox RIVALS look, clean and readable."

## Owner fixes (2026-11-21, second look)
The owner: some props (the bins, the slab piles, the gas cage) "don't line up well" and look unprofessional, there is still flicker and overlap in play, and RIVALS' textures (now in `MaterialService.ExtraTextures`) should be used well.

**RIVALS variants.** What RIVALS' own maps use (counted on `ServerStorage.MapsRivals` and `Workspace["Rivals Map Examples"]`): Concrete-02a ×1,364, Concrete-01a ×814, Wood01a ×6,574, RubberSmooth, PineFoliage_01a, Slate02c, Corrugated_01a ×105 (corrugated metal on plain Parts), CinderBlock_01a, Paver_01b, ConcretePanels-02a; the Museum adds StoneBlock_01a and Marble_01a. They render in our place from inside the `ExtraTextures` subfolders (test parts captured), so nothing was moved. Foundry4 now uses:

| Surface | Variant (base) |
|---|---|
| Yards | ConcretePanels-02a (Concrete) |
| Cast floor | Concrete-02a (Concrete) |
| Ground strips, plinths, walls, cage plinth, kit concrete | Concrete-01a (Concrete) |
| Runner kerbs and lining | CinderBlock_01a (Brick) |
| Decks, bridges, thresholds, kit grating | Diamond Plate 2022 (DiamondPlate) |
| Steel (columns, beams, slabs, rails, skips) and the kit's steel, pipe and rust parts | Metal 2022 (Metal) |
| Hall, cast house, pump house, mill and back-shed walls, roofs | Corrugated_01a (Metal) |
| Bearers / sleepers | Wood01a / Wood03a (Wood) |

Paint (yellow, team colours) and the molten / lamp Neon stay flat.

**Flicker.** The corrugated walls were ~300 mesh panels in a checkerboard 0.05 apart, which shimmers at distance. They are now plain Parts with Corrugated_01a, like RIVALS: one sheet per run of equal height, neighbours overlapping 0.02 and stepping 0.04. Floor paint lines and door thresholds sit 0.06-0.07 above the floor instead of 0.04-0.05.

**Props rebuilt as designed Parts (one design each):**
- **Skip:** a 9.6 × 4.8 steel bin on two skids, an enclosing top rim, four evenly spaced ribs a side that stop under the rim, lifting lugs, a level fill of two scrap plates inside the rim (no random bars).
- **Slab pile:** identical 8 × 0.9 × 3.6 slabs stacked exactly on identical bearers (0.2 proud each side), each layer seated 0.02 into the one below.
- **Gas cage:** a concrete plinth, four posts, three rail levels on all four sides, every rail running between the posts' inner faces; the kit now holds only the three cylinders (foot ring, body, stepped shoulder, dome, neck, valve, guard ring).
- **Ladle stand:** beams stepped in from the legs, cross rails the ladle's foot actually stands on, steel feet.

Checks after the fixes (run once): **z-fight 0, floating 0, slopes 0**. About 1,560 parts (300 fewer meshes).

## Owner final pass (2026-11-21, third look)
The owner: "the Foundry looks pretty good", but the slab piles still look unprofessional, props are placed "without any actual use", the mudgun uses building skills they don't like, the mill door is unprofessional; "the barriers are that kind of style that looks good"; look at the RIVALS Museum and build that well (low triangle counts are fine, but not at the cost of looks).
- **Purpose pass:** every prop now does a job. Cover: slab piles, coil stacks, the skip, the ingot cart, the drums, the jersey barrier, the gas cage, the loco, the ladles. Working parts of the works: the furnace, stoves, runner, skimmer, crane, ladle car and track. Removed: the mudgun (kit piece and collision), the cones and the power boxes.
- **Slab piles** are now kit pieces built like the RIVALS barriers: concrete footings with cut tops, a steel cradle beam on each (flanges and web), identical slabs 8 × 0.9 × 3.6 with flat chamfers stacked exactly, timber spacers on the cradle lines, and the slabs' end faces spray-painted as part of the slab. `F4SlabPile2` (3.22, low cover) and `F4SlabPile6` (8.02). [Close-up](../../02%20Art/References/maps/foundry4/close-slabs-door.jpg)
- **Roller doors** (the mill door and the back sheds' doors) are one kit piece, `F4RollerDoor`: chamfered steel jambs with guide channels, a coil housing with a cut lower front, a slatted curtain with cut-in grooves, a rubber bottom rail, a control box with a status lamp. The doors sit on the cladding grid (12-wide openings, the jambs cover the edges) and the plinths stop at the jambs.
- Checks after the pass (run once): **z-fight 0, floating 0, slopes 0**; about 1,480 parts.

## Grade (self, honest): 7/10
Good: a clear landmark and a readable middle (the furnace, the glowing runner, the yellow crane); RIVALS textures on every surface; a consistent chunky kit; clean joins (audits 0/0/0); warm against cool light that reads at night.
What still holds it back:
- **Kit hero pieces are simpler than the Museum's.** The furnace and the stoves read well at range but are plainer up close than RIVALS' trims and arches (no stepped trim stacks on the furnace platforms, plain pipe elbows).
- **Some Part-built props are still basic:** the pump house and the valve house are clean boxes with trims; the skip and the gas cage are tidy but plain next to the kit pieces.
- **The yards are flat and open** past the hall walls; the only height is the catwalks inside. A yard-side deck or a pipe bridge would help the flanks.
- **Night readability:** the corrugated and concrete textures show less at night than in RIVALS' daylit Museum.
- Not playtested (owner: build checks only).

## Waiting on the owner
- Play it: the runner (falling in kills), the bridges, the crane walkway, the catwalk stairs, the yards and the east lane past the ladle.
- **Save the match place** (it holds `Workspace.Foundry4`, `ServerStorage.MapKit.Foundry4` and `MapKit.Foundry4Rivals`).
- Say whether the reworked ladle, car and loco now meet the standard.
