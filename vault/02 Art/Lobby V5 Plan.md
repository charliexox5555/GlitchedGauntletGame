# Lobby V5 Plan (2026-11-20): new concept, Parts first

Status: **study and plan only. Nothing built.** Concept "The Deep" (our own underground bunker, seasonal customisation) chosen in principle; ChatGPT reference images next (§4).

Replaces the direction of [Lobby V4 Plan](Lobby%20V4%20Plan.md) / [Lobby V4 Theme](Lobby%20V4%20Theme.md). V4 stays in `Workspace.LobbyV4Staging` as the live fallback until V5 is approved.

## 1. What the owner wants changed (2026-11-20)
1. **Stop copying RIVALS.** Restart from a new concept that fits our game, above all the duels area.
2. **Too much Blender.** Almost every part was modelled in Blender, which makes the lobby hard to edit. The owner's own Studio builds (`Workspace.NewQueueArea`, `Workspace.PathNew`) look cleaner and more professional.
3. **Merged imports.** Wall runs, panels and trims came in as long merged meshes, so one panel can't be moved or deleted.
4. **Rounded "AI" look** still shows on wall panels and the duels area.
5. **No texture.** Use the MaterialService variants the owner added (the ones RIVALS uses).
6. **Overlaps and glitched parts** that the owner can't fix because of how the meshes were imported.

## 2. What the RIVALS lobby actually does (measured 2026-11-20, `Workspace.LobbyRivals`, read-only)
| | RIVALS lobby | Our V4 |
|---|---|---|
| BaseParts | 2,995 | 3,213 |
| Plain Parts / Wedges | 1,517 (1,300 blocks, 181 wedges, 6 corner wedges) | 1,297 |
| MeshParts | 1,467, from **491 unique meshes** (3x reuse) | 1,915, from **1,373 unique meshes** (1.4x reuse) |
| Parts with a MaterialVariant | **696** | 7 |
| MeshParts with a variant or SurfaceAppearance | **420** | 69 |
| Texture instances | 283 | ~0 |
| Main materials | Metal 749, Plastic 620, Neon 563, Concrete 559 | SmoothPlastic 2,304 |
| Top variants | Concrete-02a (621), Corrugated_02a (106), Pearlescent_01a/b (126), Concrete-01a (52), Wood01a (48), ConcretePanels-02a (32) | Pearlescent_01a (36) |

What that means:
- **Blender is used where Parts can't do the job**: the big angled hallway shells (`PadHallway_02b`, 108x90x36, with Corrugated_02a), door arches, bay doors, and **kit props** repeated many times (TV arms x96, spotlights x42, wall lights x42, pipes x34, crates, signs, support beams, vents). Each is small, named, and used again and again.
- **Everything flat or boxy is Parts**: floors, ledges, steps, pads, trims, panels. Edges are cut with WedgeParts, not rounded.
- **Texture comes from Roblox, not from Blender**: one concrete variant on 621 pieces, tinted per piece with `Color`. Meshes get the same variants (they're UV'd for it), so meshes and Parts match.
- **Textures add the detail**: stripes, hazard chevrons, grates and panel lines are `Texture` instances on Parts (most at 20 studs per tile; light overlays at Transparency 0.75-0.9).
- **A queue pad** (`Queue Pad #1`, 116 instances): 10 blocks + 8 wedges in Metal with Concrete-02a, 10 Plastic blocks, 9 Neon strips, 8 Textures, 15 neon MeshParts (ring icon), a SurfaceGui label. All loose parts in a Model, so any piece can be changed.

What our V4 does wrong (measured): `Duels/Wall_9` is one 162-stud `V_Wall` mesh with full-length `V_Trim` and `V_Low` meshes laid over it, all SmoothPlastic. That's why panels can't be moved, why textures can't be added, and where the overlaps come from.

The owner's own builds confirm the method: `NewQueueArea` is 24 Parts (Concrete-02a walls 24x10x1, Metal panels 11x9.5x1 with Textures, Neon strips, dark pad) and reads better than the Blender bays.

Captures (this session, Studio MCP): RIVALS duels hall, RIVALS pad close-up, RIVALS centre, NewQueueArea in V4.

## 3. The new build method (applies to every V5 piece)
1. **Studio first, Parts first.** Floors, walls, columns, ledges, steps, pads, trims, frames and panels are Parts / WedgeParts / CornerWedgeParts on a **1-stud grid with 4-stud wall bays** (walls 1 stud thick).
2. **One wall bay = one Model** (`WallBay_A_01`, ...): its panel, trim and lamp are separate Parts inside it. Any bay can be moved, swapped or deleted by hand. No piece longer than one bay.
3. **Texture through MaterialService.** Base variants: `Concrete-02a`, `ConcretePanels-02a`, `Concrete-01a`, `Corrugated_01a/02a`, `Wood01a`, `Wood03a/b`, `Diamond Plate`, `Metal`; colour by `Part.Color`. Detail through `Texture` instances (stripes, grates, panel lines). The final palette is picked from the variants already in MaterialService. No new uploads unless a gap shows.
4. **Blender only where Parts can't do it:** angled shells and arches, the hero landmark, and **kit props** (lamps, vents, crates, signs, rails, consoles). Rules for those:
   - One Model per prop and one MeshPart per material, under ~2k triangles. Never merge a run of walls or several props into one mesh.
   - Box-projected UVs at real scale so MaterialVariants work on them, then use the same variants as the Parts.
   - Built in the live Blender MCP session (port 9897 this time), hard-surface / box modelling, flat facets with one chamfer. **No sculpting for lobby pieces** (see §6).
   - Each prop is reused at least 3 times, or it isn't worth a mesh.
5. **Shape rules stay:** no round curves or spheres (angled plates), no blunt cut-offs (wedge-cut ends), no pill or round-bevel panels (`gauntlet-build-style`).
6. **Built by hand-style placement, not a regenerate script.** Pieces go into the place through the Studio MCP once and then belong to the place. No Build module that wipes and rebuilds the lobby, so the owner's edits are never overwritten. Each finished zone is saved as a backup `.rbxm` in `art-source/lobby/v5/`.
7. **Checks after every zone:** a Studio script lists overlapping coplanar faces (z-fighting), Parts inside Parts, and floating props (`rbx-map-kit-audit`, `rbx-prop-support-audit`), plus captures from player height.

## 4. Concept, round 3 (CURRENT, owner 2026-11-20)
The owner's answer to round 2:
- **No laser tag.** The underground bunker look is what works ("RIVALS is this underground bunker area, which looks good"), so we stay underground.
- **Customisable lobby.** Like RIVALS, it should change per update and season.
- **Professional with detail.** The lobby isn't the most important part of the game, but it should look good.
- **Images first.** ChatGPT prompts to get reference images.

### The concept: "The Deep", an underground facility built into a rock cavern
It's our own bunker, not RIVALS' corridor bunker. What makes it ours:

| | RIVALS lobby | Ours |
|---|---|---|
| Space | long horizontal corridors, closed metal ceilings | a big **natural rock cavern** with concrete structures built into it, so you see rock above and behind the walls |
| Landmark | queue hallway, centre display | a **central lift shaft**: you spawn as a huge freight lift arrives at the hub floor, with cables and counterweights rising into the dark |
| Duels area | hallway with pads down both sides | the **deployment deck**: lift cages on the edge of a drop, one per mode |
| Light | white bar lamps, violet / yellow neon floor lines | **warm work lights** (amber floodlights on rock, white lamps under canopies); colour only in the season accent and mode lights |
| Surfaces | dark metal panels, sci-fi | **concrete (Concrete-02a, ConcretePanels-02a), corrugated steel, hazard-painted steel, diamond-plate decks, grating, cable trays, pipes**, plus rock |
| Feel | sci-fi | grounded industrial: a working underground facility, clean and maintained |

**Walkthrough (one compact hub, every room under 15 s away):**
1. **Hub (spawn).** You arrive on the freight lift in the middle of a round concrete floor (octagonal, angled plates).
   - Rock walls rise around it, with concrete buildings set into them: the Shop counter, the Locker doors, the Range tunnel.
   - The duels deck sits straight ahead, a step down, so the first thing you see is where fights start.
   - Big wall screens on the rock show season art and the top players.
2. **Duels: the deployment deck.** A wide steel deck along the edge of a dark drop.
   - Each mode has its own **lift cage**, sized to the mode: 1v1 a narrow cage, 2v2 and 3v3 wider, 4v4 a big double cage.
   - Each cage floor is an inset pad with team-colour edge strips and hazard stripes (the RIVALS pad craft we keep). A mode sign and a screen with the queued names hang above it.
   - To queue, you step into the cage. When the match is found, the cage gate slides shut, the warning light spins and the cage drops into the dark (the teleport).
   - Cages differ in size, so the deck isn't a row of identical bays.
3. **Shop: the supply depot.** A counter set into a concrete building, with a roll-up shutter, crates behind a mesh fence, and a season display window next to it.
4. **Locker: the armoury.** Gun racks on pegboard behind mesh panels, and a work bench where your gun turns on a stand.
5. **Range** (later): a tunnel into the rock with target lanes. The door is built now, closed.

**Kept from RIVALS (structure and craft):** compact hub, concrete-variant shells, wedge-cut ledges, inset glowing pads, a sign over every entrance, detailed ceilings and canopies, reused prop clusters. **Not kept:** corridor layout, rows of identical bays, violet bunker palette, white bar lamps, word-plate signs.

**Blender is only for:** the freight lift and cage pieces (reused for every cage), rock walls (a few big faceted rock pieces, reused and rotated), floodlights, pipes and cable trays, crates. Everything else is Parts.

### Customisation per season and update
The lobby is split into a **permanent shell** and a **season layer**, so a new season changes how the lobby looks without rebuilding it.

1. **Shell** (`Workspace.Lobby.Shell`): floors, walls, rock, lifts, rooms. Never changes between seasons.
2. **Mount points in the shell.** Invisible anchor Parts tagged `SeasonMount` with a `Slot` attribute say where season pieces go:
   - `Banner` (hanging banners on the rock and over the duels deck)
   - `Centrepiece` (on the freight lift deck: a season statue, a crate pile, a vehicle)
   - `Screen` (the big wall screens: season art image ids)
   - `ShopWindow` (the season display next to the Shop)
   - `FloorDecal` (the hub floor emblem)
   - `Prop` (free spots for season clutter: snow piles, pumpkins, gift crates)
3. **Season packs** (`ServerStorage.SeasonPacks.<Season>`): one Model per slot name. The lobby server puts each one on its mount at start.
4. **Accent colour.** One `AccentColor` per pack recolours every part tagged `SeasonAccent`: mode lights, banner trims, screen frames, some lamp colours. One number changes the mood.
5. **Driven by `SeasonCatalog.SEASON`** (already in `src/lobby/shared/SeasonCatalog.luau`), so the lobby, the season pass and the shop change together.
6. **Smaller updates** (new gun, event, sale) only swap a Screen image or ShopWindow model.

This is code plus build work for the build phase: a small `LobbySeason` server module, tags and attributes; no remotes needed.

### ChatGPT image prompts
How to use them: paste the **style message** first, then one **shot** per message in the same chat, so all the images share a look. Ask for 16:9.

**Style message (paste first):**
> I'm making reference images for a Roblox game lobby. Keep this style for every image I ask for: a stylised but detailed 3D game environment, like a polished Roblox front-page game. It's an underground facility built into a natural rock cavern: grey concrete structures with visible board texture, corrugated steel, hazard-striped yellow-black painted steel, diamond-plate decks, steel grating, cable trays and pipes, plus faceted rock walls. Shapes are blocky and faceted: no round curves (curves are made from flat angled plates), with crisp chamfered edges and no soft or pillowy bevels. Lighting is warm amber floodlights on the rock and white lamps under canopies, with small coloured accent lights only. Clean and maintained, not ruined. No text, no logos, no characters. Eye-level camera, wide shot, 16:9.

**Shot 1: the hub.**
> The spawn hub: a big octagonal concrete floor in the middle of the cavern with a huge industrial freight lift platform at its centre, cables and counterweights rising into the dark above. Concrete buildings set into the rock walls around it: a shop counter with a roll-up shutter on the left, armoury doors on the right, and straight ahead a step down to a steel deck. Two large wall screens mounted on the rock.

**Shot 2: the duels deck.**
> The duels area: a wide steel deck along the edge of a dark drop in the cavern. Along the edge stand four industrial lift cages of different sizes (a narrow one, two medium ones, one big double cage). Each has a sliding mesh gate, a glowing inset floor pad with a coloured edge strip and hazard stripes, a warning beacon on top, and a hanging sign frame and small screen above it. Floodlights on the rock behind.

**Shot 3: shop and armoury.**
> Close view of two rooms set into the rock: a supply depot counter with a roll-up shutter, stacked crates behind a mesh fence and a lit display window, and next to it an armoury with gun racks on pegboard behind mesh panels and a work bench with a rifle on a turntable stand.

**Shot 4: the same hub dressed for a winter season.**
> The same spawn hub as shot 1, decorated for a winter season: snow piles on ledges, frost on the rock, hanging banners in icy blue and white on the rock walls, a big gift-crate stack on the freight lift, blue accent lights replacing the coloured lights, everything else unchanged.

**Optional shot 5: a second take on the hub, for contrast.**
> The spawn hub again, but as a bigger, taller cavern with a ring of catwalks climbing the lift shaft and more visible rock, darker, with stronger contrast between warm floodlights and shadow.

When the images come back: put them in `third-party/lobby-v5-concepts/`, which is git-ignored (or tell me where they are). I'll run the reference interview on them ([Model Style Interview](Model%20Style%20Interview.md)), then build the material test room in Parts.

### Earlier rounds (dropped)
- **Round 2** (laser-tag centre, indoor sports dome, warehouse hangout): the owner wants the underground bunker feel instead. Ideas kept: different-size queue rooms per mode, the "walk in to fight" moment.
- **Round 1** (Gauntlet tournament backstage, outdoor training compound, fight club): the game is no longer Gauntlet-themed, and the lobby must be indoors.

## Hub shell built (2026-11-20)
The owner approved the three ChatGPT concepts (`third-party/lobby-v5-concepts/`, git-ignored) and asked for the hub's main build, with little decoration.

**Concept review notes:**
- Kept: the freight-lift hub, the lift-cage duels deck, and the shop and armoury fronts.
- Changed: pipes in the concept bend round, ours bend at angles. Rock colour is one warm taupe in every room (the duels image used blue-grey rock).

**Where it is (Lobby place, Studio, NOT saved yet):**
- `Workspace.LobbyV5.Shell.Hub` at (0, 0, -1600), clear of V4 and the live spawn. 188 pieces, every one its own Part or MeshPart.
- Models: `Floor` (16 slabs), `LiftPlatform` (diamond-plate octagon 40 x 32 with a hazard border), `LiftTowers` (two steel towers with counterweights and cables, crossbeam at 55), `Rock` (40 rock MeshParts), `Shaft`, `Portal_Duels`, `DuelsStub` (temporary tunnel end), `Shop`, `Armoury`, `RangeDoor`, `Lights` (temporary invisible light sources), `Anchors.Spawn`.

**Layout:**
- Octagon cavern, rock backs at radius 50, walls 48 high, then an upper row leaning in 30 degrees up to a rock ceiling at about 62-76.
- A 48 x 48 lift shaft rises to y = 134.
- Lift centred on the shaft. The spawn faces north to the duels portal (36 x 20 opening with cut corners, one step down into the tunnel).
- Shop facade at x = -40 (west), armoury doors at x = 40 (east), range shutter at z = 42 (south, behind the spawn).

**Materials:**

| Surface | Variant | Colour |
|---|---|---|
| Floor | ConcretePanels-02a | 130,127,122 |
| Shop walls | Lobby_ConcreteBoard | 118,116,112 |
| Frames | Concrete-02a | 128,126,123 |
| Steel | Metal 2022 | |
| Lift deck | Diamond Plate 2022 | |
| Tunnel floor | Bunker_Grate | |
| Shutters | Corrugated_01a | |
| Rock | **Lobby_Rock** (Slate) | 132,116,102 |

Slate02c was tried on the rock and dropped: its cobble pattern fought the facets. The hazard stripes are our own texture (`art-source/lobby/v5/textures/Hazard.png`, image id 75158634706115; the Decal asset is 128601803791013).

**Rock kit (Blender, live MCP on port 9897, `tools/blender/lobby_v5/v5_rock.py`, `art-source/lobby/v5/LobbyV5.blend`):**
- `V5_RockWall_A/B/C` (24 x 48), `V5_RockLow_A` (24 x 16), `V5_RockCeil_A` (48 x 48).
- 23-92 triangles each, flat facets, box UVs; uploaded as Models (ids in `art-source/uploads.json`).
- Templates live in `ServerStorage.V5Kit`; every wall piece is a clone scaled with `Size`.
- **Gotcha:** after import the rock face points local **-Z** (Blender -Y), so pieces get a 180 degree turn. The first pass showed the flat backs.

**Build script:** `tools/studio/lobby_v5/BuildHub.luau` is a one-time placement record. It only rebuilds `Shell.Hub`; once the owner edits by hand, the place owns the parts.

**Checks:**
- 4,200 rays from 7 points inside the hub. One opening was found (under the shop: the floor stopped at x = -52) and fixed.
- Coplanar-face scan: the lift hazard strips shared deck edges; they now sit 0.02 inside.
- The armoury jambs were widened into the rock to close a light sliver.

**Self-review: 6.5 / 10 as a shell.**
- Works: the silhouette and mood match the concept (faceted rock, towers framing the lit portal); the lift and hazard border read at once.
- Missing (dressing pass):
  - Real light fixtures; the light sources are invisible for now.
  - Trims and cut-corner edges on the shop facade and canopy.
  - Pipes and cable trays on the rock, and wall screens on the NE / NW rock.
  - The shop display window, lift corner lamps, and shaft lights.
  - The floor is big and plain, and the shop facade still reads as a box.

**Owner to do:** look around the hub in Studio, then **save the Lobby place** (nothing here is saved yet). Rotate or move any piece freely.

## Hub round 2: owner feedback (2026-11-20)
**Owner asked for:**
1. Fix the glitched parts where the ceiling met the top of the walls.
2. Make the top a **skylight**: "you're at the bottom of a cave and the top opens up where the sky shines in".
3. Better lighting: it was too dark.
4. Fix the duels portal overlapping the rock.

**Left for later:** the gaps in the wall between the range door and the other doors. The doors get their own pass "in a similar style to RIVALS" (study RIVALS' doors first; they stay as plain frames for now).

**Done:**
- **Ceiling and shaft removed.** The flat rock ceiling plates and the boxed lift shaft were where the leaning upper wall cut into the ceiling.
- **Open chimney instead.** The upper rock row now leans in 20 degrees (it was 30) and ends at radius 41. An open rock chimney (8 pieces, `V5_RockChimney_A/B`, jagged notched tops, leaning out 8 degrees, shallow so it clears the towers) rises to about y = 110. You see sky and sun from the lift.
- **Headframe.** The lift towers now rise to y = 120 through the opening with a headframe beam at 114, like a mine headframe. No tower piece touches the rock.
- **Duels portal:**
  - Opening is now 34 x 20, frame 8 deep, pillars out to x = 24.
  - The two rock panels beside it (`Wall_NW_2`, `Wall_NE_1`) stop 8 studs short of the corners.
  - New concrete **buttresses** (`Buttress_W/E`, 9 x 48 x 4.5) fill the corners, so the rock ends on concrete.
  - Ray check: 0 rock pokes into the opening (there were 34).
- **Lighting:**
  - Rock grazing lamps 2.5, warm fill point lights 0.6, floor darkened 20%.
  - **Place-wide Lighting changed:**

| Setting | Old | New |
|---|---|---|
| Ambient | 74,74,78 | 84,78,72 |
| OutdoorAmbient | 112,112,116 | 84,76,68 |
| Brightness | 3 | 2.4 |
| EnvironmentDiffuseScale | 0.55 | 0.3 |
| ClockTime | 12.3 | **14.6** |
| ColorShift_Top | 255,253,248 | 255,214,170 |

  - At noon the sun came straight down the opening and lit the whole floor white. At 14.6 a warm sunbeam falls on the east rock above the armoury, with the tower's shadow across it, and the floor stays in warm shade. The V4 lobby shares these settings.
- **Wall check:** 7,200 rays from 9 points. Every ray that escapes leaves upward through the skylight; none leave through a wall.

**Owner to do:** look from the lift (look up), then **save the Lobby place**.

## Hub dressing (2026-11-20)
Owner: "decorate the main hub and get things ready before we move on". Built by `tools/studio/lobby_v5/DressHub.luau` into `Hub.Dressing` (about 510 Parts, every fixture its own Model) and `Hub.SeasonMounts`. Rules from `gauntlet-build-style`: fixtures built the way they're made, no blunt ends, pipes enter the rock through a flange, a real light beside every lens, hazard yellow is the hub's one accent.

| Piece | What it is |
|---|---|
| **Wall lamps** (16) | Two per rock wall at y = 40, placed by raycast onto the real rock surface. Built in order: mount plate with bolts (sunk 0.85 into the rock), arm, housing, visor, bezel, warm lens set back. Each throws the warm grazing spot down its wall, replacing the invisible `Graze_*` lights. |
| **Pipes and cable trays** (NE, SE, SW, NW walls) | An 8-sided steel pipe, a charcoal pipe and a cable tray, each run just in front of the most protruding rock. Brackets every 8 studs reach the rock. Both ends turn 90 degrees into the rock (elbow collar and wall flange, or a closed tray end plate and conduit). NE and NW stop before the portal buttresses. New Blender kit pieces: `V5_Pipe8` and `V5_Flange8` (`tools/blender/lobby_v5/v5_pipe.py`). |
| **Signs** | DUELS (portal lintel), LOCKER (armoury lintel), RANGE (range lintel), SHOP (on feet on the canopy). Cut-corner charcoal plates, a SurfaceGui word in Fredoka One, a yellow accent bar tagged `SeasonAccent`. |
| **Season screens** | `Screen_N` (16 x 9) above the duels portal, the focal point from the spawn; `Screen_S` (14 x 7.9) above the range door. Charcoal case on a wall arm, SurfaceGui placeholder "SEASON 1 / THE DEEP". The NE / NW spots were hidden behind the lift towers. |
| **Shop front** | Canopy front leaning out at the top, a light bar under the canopy (replaces the invisible light), a hazard kick strip, a counter lip, and a lit display case with glass and a shelf (the `ShopWindow` season mount). |
| **Lift** | Four status lamps beside the east and west deck edges (lenses tagged `SeasonAccent`), two hanging downlights under the crossbeam (replace `Lift_W/E`), red beacons on the headframe, and a control console on the east plinth ("LIFT READY"). |
| **Floor** | Painted yellow walkway lines from the lift to each doorway, and four drain grates with frames. |
| **Props** | Three hard-case stacks on steel pallets (SE, SW, NW), with yellow latches and corner guards. |

**Season mounts** (`Hub.SeasonMounts`; the parts are tagged `SeasonMount` with a `Slot` attribute; the screens' Display parts are tagged too):
- `Banner_1/2` hang from the crossbeam.
- `Centrepiece` (10 x 10) sits behind the spawn at z = +30.
- `FloorDecal` (12 x 12) is in front of the portal.
- `ShopWindow` is inside the display case.
- `Prop_1-3` are spare floor spots.

The `LobbySeason` server module that fills them per season is **not written yet** (next code step, with `SeasonCatalog.SEASON`).

**Fixes during review:**
- Scaled text caps at 100 px, so signs and screens use a low pixel density.
- The SHOP sign was raised clear of the canopy front.
- The pipe runs used to cross the buttresses; they're rebuilt to stay in their walls.
- A walkway line and two drains were moved off the tower plinths.
- The tray lips were stepped 0.03 off the base edge.
- The coplanar scan's remaining hits are faces hidden against the floor or inside other parts.

**Capture gotcha:** a SurfaceGui facing away from `workspace.CurrentCamera` captures blank. Turn the camera to face it first.

**Self-review: 7.5 / 10.** The hub reads as a lived-in working facility: the signs, season screen and lit duels portal pull the eye, and the rock walls have structure.

Weak spots:
- The floor is still large and plain between the lines.
- The prop stacks are small at the cave edge.
- The display case reads as a lit box.
- The doors are plain until the RIVALS-style door pass.

**Owner to do:** look around, then **save the Lobby place**.

## Owner notes on the dressing (2026-11-20), parked for a later pass
- **Placeholders to redo:** the signs (the SHOP sign above all), the drains and the hard cases. Redo them when the props and cases are designed properly.
- **Colours are bland.** The palette needs more life later (the season accent and an owner colour pass).
- **Wrong font.** The game font is **Rubik** (Heavy / Bold, `rbxassetid://12187365977`, `Config/UiStyle.luau`), not Fredoka One. World signs and screens follow it.
- Builds must be well thought out. Next: the **duels deck structure first**, then the pads / cages.

## Duels hall structure (2026-11-20)
Owner: "build the structure of it, and then we'll go into the pads". Built by `tools/studio/lobby_v5/BuildDuels.luau` into `Workspace.LobbyV5.Shell.Duels` (about 600 Parts, 96 rock MeshParts). It replaced the hub's temporary `DuelsStub`. The concept image is `third-party/lobby-v5-concepts/02-duels-deck.png`.

**Layout** (hub-local coordinates, north = -Z; the deck is one step below the hub at y = -1):
- **Tunnel:** z -50 to -60 from the hub portal, with two ceiling light fixtures.
- **Bulkhead** (the hall's south wall, at z = -60, 30 high):
  - Pilasters every 16 studs, each with a sloped foot and head.
  - Each bay has a battered wainscot, a framed corrugated panel and a cap ledge.
  - The tunnel mouth has a frame with cut corners (matches the hub portal).
  - Every bay and pilaster is its own Model.
- **Deck:** 168 x 36 (x -84..84, z -60..-96).
  - 12 x 12 diamond-plate panels with 0.1 shadow gaps over a dark under-plate.
  - Grating panels on a pattern; the entry lane stays solid.
  - A hazard-striped edge kerb, plus an edge beam, girders and struts under it back to the ledge rock.
- **Chasm:** z -96..-150, floor at y -90. Rock all round: east / west walls, far wall, the ledge face under the deck, the floor and the ceiling (y ~56-70).
- **Skylight crack** over the chasm (x -36..36, z -118..-138). The chimney is short (26) so the afternoon sun reaches down.
- **Gantry:** 10 column lines (x = +/-13, 33, 49, 61, 73) with front and back columns at z -98 / -118, rising from the chasm floor to y 28.6. Runway beams front and back, cross beams with flanges, a deck-level tie, and X-bracing in the chasm.
- **9 cage bays** between the lines, mirrored from the centre in mode order:

| 1v1 | 1v1 | 2v2 | 3v3 | **4v4** | 3v3 | 2v2 | 1v1 | 1v1 |
|---|---|---|---|---|---|---|---|---|
| 10 | 10 | 14 | 18 | **24** | 18 | 14 | 10 | 10 |

  Bay sizes are in studs. Anchors are in `Duels.BayAnchors` (attribute `Mode`). The cages are the next step.
- **Rails:** `TEMP_EdgeRail` across the bays (remove when the cages go in), and permanent `EndRails`.
- **Lights:**
  - A downlight per bay under the front runway.
  - Lamps on every inner pilaster head.
  - Hub-style grazing lamps raycast onto the far wall (7) and side walls (4).
  - Uplights on the gantry onto the rock ceiling, warm fill over the deck, and a warm glow up the far wall from the chasm floor.

**Checks:**
- The first lighting pass was far too dark (the owner already called the hub too dark). It was fixed with the lamps, uplights and fill above.
- 12,000 rays from 10 open points (deck, gantry height, chasm floor): every escape goes up through the crack. Gaps at the chasm floor edges were fixed by sinking the bottom rock rows 10 studs and running the floor under the ledge.
- Coplanar faces: the beam ends and rail ends that sat flush with column and post faces are inset 0.1. The remaining hits are hidden (tops above eye level, bottoms resting on the deck).

**Next (pads pass):** the lift cages in each bay, sized per mode, with an inset floor pad, team edge strips, gates, a beacon, a mode sign and a queue screen. Then hook them to `LobbyQueue` (Step zones) and remove `TEMP_EdgeRail`.

## Duels cages (2026-11-20), SUPERSEDED by Queue bays v2 below
Owner: "Yes, build the cages". Built by `tools/studio/lobby_v5/BuildCages.luau` into `Duels.Cages`: 9 cages, about 1,000 Parts. `TEMP_EdgeRail` was removed.

**One cage per bay**, sized by the bay (`Duels.BayAnchors`, attribute `Mode`), built the way a lift car is made:
- **Base:** diamond-plate platform on an under-frame with joists, and a steel threshold.
- **Frame:** four corner posts with shoes, a top frame and a header with a gate track.
- **Walls:** barred side and back panels (rails, bars every 1.6, an X brace), with invisible colliders just inside.
- **Gates:** two sliding gate leaves parked open behind the front posts.
- **Hoist:** four cables from lugs up to sheave blocks seated under the gantry runways.

**What players see:**
- **Pad:** in two team halves.
  - A is orange (`200,96,30`), B is blue (`40,100,200`).
  - Each half has neon edge strips, a faint team letter, one pip per player and a soft team-coloured light.
- **Header sign:** the mode in Rubik Heavy, with one orange and one blue pip per player.
- **Beacon:** an amber beacon on top (tagged `CageBeacon` for the match-found effect later).
- **Queue screen:** on the back wall, "STEP IN TO QUEUE" (4v4 says "COMING SOON").

**Queueing:**
- Each live cage has an invisible `QueueZone` tagged `LobbyQueue` with `GauntletState` values `Mode = "s<mode>"` and `Trigger = "sStep"`. This is the V4 step-pad contract, read by `src/lobby/client/Controllers/WorldPrompts.luau`.
- There are 8 zones. 4v4 is not in `Config.MODES` yet, so its cage has no zone.
- The team halves are tagged `LobbyPadSquare` with `Team = n1 / n2`, so `LobbyPadFx` draws its rings and glow when someone stands on them.
- **Playtest (Studio, 2026-11-20):** standing in `Cage_08_1v1` set the player's `QueueStatus` to `searching / 1v1`; stepping out set it back to `idle`.
- The V4 step zones in `LobbyV4Staging` are still active as well.

**Review fixes:**
- The team letters were upside down.
- The X braces on the gate leaves read as sawhorses, so they're gone.
- Two hazard lines (cage threshold plus deck kerb) were too much yellow; the threshold is now plain steel.
- The header and top side beams were flush with the post faces; they're inset now. The remaining coplanar hits are bottoms resting on the platform.

**Watch:** the client log warned "no asset content representation" for the hazard texture (`75158634706115`) during play. It renders in edit, probably still processing. Recheck.

**Self-review: 7.5 / 10.** The row reads clearly (mode, size and team colours) and the queue works.

Still missing:
- **Motion:** gates sliding shut, the beacon spinning and the cage dropping when a match is found. That's the next code step: a `LobbyCageFx` client controller reading the player's `QueueStatus`.
- Header text is small from the far end of the deck.
- The colours are still the owner's "bland" note.

## Queue bays v2 and a wider hall (2026-11-20)
**Owner on the cages:**
- There were overlapping parts.
- The queue area colours weren't liked, and it felt like a horror game.
- Queue areas should be larger, like the 4v4 one: you walk in, stand on it, it highlights and goes up, and you walk off to leave. Expanding the duels area is fine.
- The 1v1 / 2v2 signs should be structured like RIVALS' (study, not copy).

**The overlaps found:** the side rock walls bulge up to 12 studs inward and cut through the end bulkhead bays and pilasters, the end rails, the last gantry columns and the end cages. All gone in v2. The only rock contacts left are deliberate: the end parapets and end pilasters run into the rock.

**RIVALS pad study** (`LobbyRivals` Queue Pad #3, read-only):
- Two team squares (~13 x 10) side by side, about 29 x 21 in total.
- Each square is a dark floor panel with thin team-colour neon edge strips in a concrete rim with a textured top.
- A small sign of a coloured title plate and a mode plate, on dark boards.
- When occupied, rings and a glow column rise.

**What we took:** the two-square pad and the lit sign over each pad, plus the occupied highlight (our LobbyPadFx already does it). **Not taken:** their look, colours or hallway layout.

**Hall v2** (`BuildDuels.luau`):
- 244 wide (x +/-122, was 168).
- 8 equal bays of 24 between gantry column lines every 26 (x -104..104).
- Back columns at z -124 (bays 26 deep).
- The bulkhead runs to +/-100, with floor-to-ceiling corner rock beyond it.
- Concrete end parapets on the deck edge run into the rock; the end rails are gone.
- Hub-style rock lamps, pilaster lamps and uplights are spread for the width.
- 801 pieces, 121 rock meshes.

**Bays** (`BuildQueueBays.luau`, replaces the deleted `BuildCages.luau`), in mode order mirrored from the tunnel:

| 3v3 | 2v2 | 1v1 | 1v1 | 1v1 | 1v1 | 2v2 | 3v3 |
|---|---|---|---|---|---|---|---|

4v4 can be added later as end bays. Each bay:
- **Platform:** an open light-concrete platform (24 x 26) out over the chasm, hung from the gantry by two back cables. Low steel rails on three sides with invisible colliders just inside.
- **Pad:** a raised dais (21 x 18, 0.6 high, sloped edges all round, light concrete rim). Two light-grey team squares, each with a thin neutral edge line and one team pip per player at the front.
  - The squares are tagged `LobbyPadSquare` (Team 1 / 2).
  - One `QueueZone` per bay is tagged `LobbyQueue` (Mode, Trigger Step). 8 zones in all.
- **Lightbox sign:** hung from the front runway on two hangers, tilted 25 degrees toward the deck. A cut-corner charcoal case with a white self-lit face (SurfaceGui, not Neon).
  - The mode is in big dark Rubik Heavy, with "STEP IN TO QUEUE" and one gold / cyan pip per player.
  - A SurfaceLight glows from the face, and a pad light under the case lights the dais.

**Colours:**
- Team A **gold** `FFB627` (the hub accent) and team B **cyan** `2EC8FF` (the game's ally colour), replacing orange / blue.
- `src/lobby/client/Controllers/LobbyPadFx.luau` TEAM changed too; Rojo is syncing it. It also recolours the V4 pads.
- Pads are neutral when empty and light up in the team colour when someone stands on them.

**Playtest (Studio):**
- Stepping into Bay_04 1v1, Bay_07 2v2 and Bay_01 3v3 set `QueueStatus` to searching for that mode; stepping out returned to idle.
- Standing on a square shows the gold rings with the rising glow, plus the "SEARCHING FOR PLAYERS 1V1" bar (capture `V5Bays_Occupied`).

**Review fixes:**
- The squares were overexposed (darkened, pad light 2).
- The front hoist cables cluttered the entry (removed).
- The rail post tops were flush with the top rail (posts raised 0.2).

**Still open:**
- Match-found motion (the platform lifting or dropping, the sign flashing), via a `LobbyCageFx`-style client controller.
- The owner's colour, sign and prop pass for the hub.
- The LobbySeason module.

## Match-found motion (2026-11-20)
Owner: "Add match-found motion". Code: `src/lobby/client/Util/MatchLift.luau` (new) and `src/lobby/client/Controllers/MatchFoundController.luau` (waits for the lift). Local to the matched player's client; no remotes, no server change.

**What happens** when your match is found while you stand on a V5 bay square:
1. **Sign:** the bay's lightbox sign flashes gold three times, holds gold and reads **MATCH FOUND**.
2. **Lift:** a lift plate rises out of your square, with team-colour edge strips (gold A / cyan B), a dark skirt and a team-coloured light.
   - **Motion:** coil down 0.3 (0.14 s), then a Quint-out rise of 7 studs over 1.45 s with a 0.35 overshoot, then a 0.35 s settle (the owner's animation-oomph rule: coil, snap, brake, overshoot, settle).
   - **Character:** the root is anchored and carried with the plate; the idle animation keeps playing.
3. **Light column:** a faint team-colour column climbs 16 studs above the plate.
4. **Overlay:** after 2.1 s the existing MATCH FOUND overlay (dim, blur, three dots) fades in. The server teleports at 3.5 s, as before.
5. **Off a bay:** if you queued from the menu or a V4 pad, nothing changes; the overlay opens at once.
6. **Cancel:** if the queue returns to idle (a failed teleport, Studio's skipped one), the plate is removed, the sign restored, and the character is put back on the pad (not dropped) and unanchored.

**Playtest (Studio, bot fill 5 s):**
- Found 5.5 s after stepping on Bay_05.
- The lift rose (capture `V5Lift_Rising`), then the overlay showed (`V5Lift_Overlay`, "STUDIO · TELEPORT SKIPPED").
- After the skip: lift model gone, root unanchored, sign back to STEP IN TO QUEUE.
- Second run (Bay_06 B): root y 3.2, peak 9.9, back to 2.5 after the cancel, with no drop.
- Format and lint clean (stylua, selene).

**Known limits:**
- Other players see the lift only on their own client (it's local). They may see the matched player stand still, or rise without the plate, depending on replication of the anchored root.
- In Studio, standing on the pad after a skipped teleport re-queues (existing step-pad behaviour).
- The column brightness and lift height are tunables at the top of `MatchLift.luau`.

## Pads v3: wells and the reticle (2026-11-20)
**Owner:**
- Disliked the "circular thing that spins around when you load up" (LobbyPadFx's two thin octagon rings, hovering and spinning at 2 rad/s).
- "The duel pads also have to be improved."
- 4v4 / 5v5 bays are not needed for now.

**RIVALS studied** (Queue Pad #3, capture `RivalsPadEmblem`):
- Each team square is a sunken dark well with striped inner slopes and a thick team-colour neon border.
- A bold flat emblem (thick broken arcs, flat MeshParts, Neon at 0.75 transparency) floats in the well, slowly turning, with a faint column going down into the well.

Taken: the dark well, the bold flat emblem and the border. Not taken: their arcs, stripes or colours.

**Pads** (`BuildQueueBays.luau` pad block, rebuilt in all 8 bays): the dais keeps its light concrete rim. Each team square is now a **sunken well**:
- A dark floor (`44,46,50`) just above the platform.
- Angled dark-steel slopes from the rim edge down to the floor.
- A thick **team border** on the rim around it (gold / cyan Neon, 0.3 wide).
- One pip per player on the rim in front.

The floor part keeps the name `Square_A / B` and the `LobbyPadSquare` tag (LobbyPadFx and MatchLift read them). The MatchLift plate now rises out of the well.

**LobbyPadFx v2** (`src/lobby/client/Controllers/LobbyPadFx.luau`, rewritten):
- Per well, a flat **reticle** floats 0.1 above the floor: four thick corner brackets with 45-degree bevelled tips, and a hollow diamond with a centre stud, all flat plates (no curves).
- **Idle:** still, light grey, 0.45 transparency. **No spinning.**
- **Occupied:** it locks on over 0.22 s with a Quint snap. The brackets pull in by 24%, the diamond turns 45 degrees to square, the plates take the team colour, and the glow curtain and light fade in as before.
- Sized from the well's short side, so the V4 pads get it too.
- Format and lint clean. Capture `V5Pads_Reticle`: idle reticles, plus a cyan lock-on with a player in it.

## Locker room plan (2026-11-20)
Owner: "let's move on to the locker area, creating the locker area" (building only, no season code). Concept: `third-party/lobby-v5-concepts/03-supply-depot-and-armoury.png`, right half: a cut-corner concrete arch, pegboard gun walls behind mesh panels, a central bench with a gun on a turntable, yellow floor marks.

**RIVALS weapons room, structure only** (`LobbyRivals.Hub.Extra.Weapons`, capture `RivalsWeaponsRoom`): a room off the hall with a gun wall at the back, tables of laid guns, the vendor NPC by the gun wall, crates, wall lamps, a recessed-light ceiling and a big floor emblem.

**Hooks in our code (reuse):**
- `LobbyGunDisplay` anchors show each player's own skins (`LobbyGunDisplays.luau`), with state values Gun, Mount, B / F (Blender axes) and Scale / Fill.
- The V4 locker used 9 Wall mounts (Bulldog, Guardian, Stinger, Ares, Ghost, Marshal, Bucky, Shorty, Outlaw at 1.9 / 5.9), 8 Lay mounts (Phantom, Operator, Spectre, Judge, Vandal, Odin, Classic, Sheriff at 2.3 / 6.6) and 1 Stand (Knife).
- A `LobbyLocker` part opens the Locker menu with a prompt (`WorldPrompts`).
- `LobbyNPC` Armorer (`LobbyV4Staging.NPCs.Armorer`).

**Layout** (hub-local, east of the hub):
- **Entrance:** the hub's armoury frame (x 40-46) opens; its doors, transom and back block go. A 8-long vestibule leads to the room.
- **Room:** x 55-103, z -22..22, y 0-18. Board-concrete walls, a dropped soffit with lit ceiling panels, a polished concrete floor with yellow marks.
- **Back wall:** a pegboard gun wall with the 9 Wall guns (3 x 3), framed by see-through mesh panels.
- **Side walls:** rows of steel lockers (number plates, vents, handles, a sloped top) with padded benches.
- **Tables:** four tables holding the 8 Lay guns.
- **Centre:** a workbench island (sloped sides, hazard panels) with a turntable and the Knife stand, and the `LobbyLocker` prompt; a yellow floor box around it.
- **Armorer:** NPC by the gun wall.

**New textures** (drawn, uploaded): pegboard, and a mesh grid with see-through holes.

## Locker room built (2026-11-20)
Built by `tools/studio/lobby_v5/BuildLocker.luau` into `Workspace.LobbyV5.Shell.Locker` (about 605 Parts). The hub's armoury frame is now open: doors, transom and back block removed. New textures (ours, uploaded):
- `Pegboard.png`: image `120794687026437`.
- `MeshGrid.png` (see-through holes): image `79156982233553`.

**Vestibule** (x 46-55): continues the frame's cut-corner profile, with a diamond-plate threshold and a ceiling light.

**Room** (x 55-103, z +/-22, 18 high):
- Board-concrete walls with a wainscot by the door.
- A dropped soffit round the ceiling with a warm lit cove, and four ceiling light panels.
- Polished concrete floor (`98,96,93`), with yellow walkway lines from the door and a yellow box round the bench.

**Gun wall** (east):
- A pegboard in a steel frame, tinted so it doesn't blow out, holding the **9 Wall guns** (Bulldog, Guardian, Stinger, Ares, Ghost, Marshal, Bucky, Shorty, Outlaw) on pairs of pegs.
- Mesh-fronted cages either side with shelves of cases.
- A LOCKER lightbox on the soffit, and three spotlights.

**Lockers:** 36 steel lockers in two rows on the side walls.
- Charcoal bodies with **muted olive doors** (the room's colour), vents, handles, sloped crowns and number plates (Rubik).
- Two padded benches per side.

**Tables:** four display tables (rubber mat, steel frame) with the **8 Lay guns** (Phantom, Operator, Spectre, Judge, Vandal, Odin, Classic, Sheriff).

**Workbench** (centre):
- Sloped hazard-striped sides, steel ends and top.
- An octagonal turntable (`V5_Flange8`) with the **Knife** standing and turning (Spin 30).
- `LockerZone` tagged `LobbyLocker` gives the "Open Locker" prompt.

**Armorer:** a copy of the V4 `LobbyNPC`, by the gun wall.

**Playtest (Studio):**
- 18 gun copies appeared in the room as the player's own skins.
- The bench prompt reads "Open Locker".

**Lighting note:** in Studio play the client runs at about 15 fps on automatic quality. At low quality Roblox drops most local lights, so lamp-lit rooms look darker and bluer than in edit. Phones will look like this too. If it matters, raise the interior Ambient or add self-lit surfaces; parked for the colour pass.

**Fixes in the same pass:**
- The duels bulkhead foot, head and wainscot slopes (34) and the queue-pad dais slopes (32) were built facing the wrong way (small overhangs instead of ramps). Turned in Studio and fixed in `BuildDuels` / `BuildQueueBays`; the pad slope now runs from y -0.46 at the rim to -0.94 at the platform.
- The coplanar scan of the Locker shows only hidden joints inside the mesh cages.

## Entrances and the shop (2026-11-20)

Owner: the locker "is kind of boring ... add on to it"; the entrances to Duels, Locker, Range and Shop "all need to look better", signs "more professional", "the shop sign is floating", the shop should be "an entrance similar to Rivals", not "one little area"; entrances "like Rivals and have different logos ... not as neon-y ... extravagant".

**RIVALS studied (read-only, one capture):** the MARKET entrance is a chunky light pier frame with a dark lit tunnel behind; the logo is a big badge on the frame face (word plus swoosh in a neon outline on a dark backing mesh, self-lit SurfaceGui images at Brightness 3 to 3.5); yellow accent bands and a floor stripe lead in. We took the structure (portal + badge + lead-in), not the look.

**Kit:** `tools/studio/lobby_v5/LobbyKit.luau`, installed in the place as the ModuleScript `ServerStorage.V5Kit.LobbyKit` (build scripts `require` a fresh clone; game code never touches it).
- `K.badge`: the area logo. Dark gunmetal plate with two cut corners (top-left, bottom-right), a soft accent rim behind it, and a self-lit SurfaceGui face (LightInfluence 0, Brightness 1.15). Face: the HUD icon in black on an accent tile, the word in Rubik Heavy Italic, and a `»` subtitle in Rubik Bold. The plate is sized to its text (TextService). It stands off its wall on brackets and has a small accent light.
- `K.gateway`: the entrance frame:
  - Concrete piers and header the full depth of the doorway, with a fascia over the rock gap.
  - Proud pilasters on plinths, each with a sloped cap and an inset panel.
  - A cornice with a sloped cap.
  - A soft accent light line in a dark channel beside each pilaster, and a lit reveal ring set back in the opening.
  - Cut top corners, a lintel beam with downlights, and a diamond-plate threshold.
  - The badge on stand-offs, washed by two small lamps under the cornice.
  - Neon is the accent at 42% darker, so it glows without shouting.
- Area colours and icons are the lobby HUD's tags:

  | Area | Colour | Icon |
  |---|---|---|
  | Locker | `3fe0f2` | locker |
  | Shop | `ffc83d` | bag |
  | Pass | `b58cff` | chevron shield |
  | Range | `2bd9a8` | target |
  | Duels | `ff6248` (new, red-orange) | the Play mark |

**Built** (`BuildGateways.luau`, 177 pieces):

| Gateway | Opening | Badge |
|---|---|---|
| Duels | 34 x 18 | DUELS » 1V1 · 2V2 · 3V3 |
| Locker | 14 x 13 | LOCKER » LOADOUT · SKINS |
| Range | 16 x 12, still shuttered | RANGE » COMING SOON |
| Shop | 14 x 12.5 | SHOP » ITEM SHOP · BATTLE PASS |

Also in this script:
- The old jambs, lintels, the shop counter facade, its canopy sign (the floating one) and the four flat signs are removed. The duels buttresses and the range back stay.
- The range shutter is now a ribbed roller door in guide rails.
- The hub's floor lane lines lead into each opening, 0.6 inside the edge. The Locker's carry on inside at the same spacing.

**Shop** (`BuildShop.luau`, 287 pieces, gold accent, `Workspace.LobbyV5.Shell.Shop`):
- **Storefront:** concrete wings either side of the gateway. Each has a lit display window: light backdrop, steel casing and sill, glass, a gold uplight, and a pedestal with a standing gun (Vandal / Phantom). The S window carries the `ShopWindow` SeasonMount.
- **Vestibule:** mirrors the locker's.
- **Room:** 44 x 48, height 18, charcoal board walls, a soffit with a warm cove, and 4 ceiling lights.
- **Featured podium:** chamfered tiers, a turntable with a turning Operator, a narrow spot, and a gold floor diamond. Gold lane lines lead to it from the door.
- **Gun wall:** 3 x 2 backlit bays with hoods, downlights and tag plates, showing each player's own skins.
- **Battle Pass bay:** a framed purple panel with a BATTLE PASS badge, three plinths with cases and a purple glow, and the `LobbyBattlePass` prompt.
- **Counter:** a leaning front, a steel top, a gold lip, and a terminal screen with the shop icon. The `LobbyShop` prompt is in front.
- **Back wall:** a steel slat wall over gold-lit slots, carrying a MARKET » OPEN NOW badge, with stock shelves of cases either side.
- **The Broker** (from `LobbyV4Staging`), scaled 1.5 and placed clear of the badge. His V4 "vest" was a loose 5.7-stud box that read as a purple block; it and his sash are now fitted to the torso.

**Locker polish** (`PolishLocker.luau`, cyan accent):
- The yellow floor lines turned cyan; the workbench keeps its hazard stripes.
- A painted floor emblem at the entry: the locker icon in a cut-corner outline.
- A cyan belt line on the N and S walls, with painted labels "BAY A · 01–18" and "BAY B · 19–36" over the lockers.
- Three steel I-beams and two octagonal air ducts, with flanges, clamps and vents.
- Kit bags and a helmet on the benches, and box stacks in the corners. The locker tops are sloped crowns, so nothing sits on them.
- The gun wall's lightbox is replaced by the LOCKER badge on the soffit face.

**Checks:**
- **Captures:** all four gateways from the hub, the shop front and room, the locker before and after, a wide hub shot, and play-mode shots of the shop and locker.
- **Exact overlap audit (GetPartsInPart) of every new part.** What remains is deliberate seats:
  - each badge's rim behind its plate;
  - thresholds and the shutter in the floor;
  - window sills into the wing sides;
  - the BP rim into its wall;
  - the bag straps on the bench pads;
  - the duct clamps into the beam flanges.
  - The diagonal duels buttresses still run through the new piers, as they did through the old pillars.
- **Fixed during the checks:**
  - gear sunk in the locker crowns;
  - the Broker into the badge and the counter;
  - a range rail into the cut;
  - lane lines that ran into plinths.
- **Playtest:** prompts live (Open Shop / Market, Battle Pass / Season 1, Open Locker, Talk to the Armorer). Wall and stand guns show the player's skins. No new console errors.
- White outfits blew out under the ceiling spots, so the locker and shop ceiling spots went from 2.3 / 2.2 to 1.7, fill from 0.8 to 1.0, and the podium spot from 2.6 to 1.5.

**Open:**
- The Broker has no Talk line (no `Talk` attribute in V4).
- The Range is still shut.
- The colour and prop pass is still to come.
- The place is **not saved**.

## Character pass plan (2026-11-20)

Owner, after the entrances pass: the badges "look too generic ... don't fit the theme ... not much character"; liked the V4 signs more (not to copy); the locker floor logo goes; entrances "still need a little improving" ("Rivals ... cool entrances"); the Range entrance "very similar to Rivals": a big bay door opening, then a hologram mini of the range, and a themed landmark at the back (a placeholder for now; the range itself is not built); "intricate designs ... support beams and all those aspects ... that really brings it together".

**What gives RIVALS and V4 their character (studied):**
- RIVALS: neon-outline words with arrows or icons that break the sign's outline, tilted down at the spawn; small slanted label tags ("UGC SHOP", "SEASON 3 / FAME"); stencilled wall text ("HOLOBAY 01"); caution plates; crates with logos; yellow accent bands; chunky capsule lamps; heavy ribbed frames.
- RIVALS range: two giant dark bay-door leaves parked open, a cyan holo grid curtain over a miniature simulated range, neon SHOOTING RANGE letters with a target for the O, a floor stencil ("LARGE SCALE SIMULATION") and warning plates by the door.
- V4 (our own): a sculpted sign in layers (dark plate, steel trim, glowing outline, white letters) shaped like an arrow, with a 3D emblem (crossed swords) breaking out of its left end.

**Plan:**
1. **Sign kit v2 (K.sign):** a hanging sign in layers built from Parts, tilted down at the hub:
   - a slanted plate with a steel frame and an accent inlay line;
   - a faceted medallion with a 3D emblem per area breaking out of the left end:
     - Duels: clashing chevrons
     - Locker: padlock
     - Shop: bag
     - Range: crosshair
     - Pass: star chevron
   - extruded letters: stacked Rubik Heavy Italic layers;
   - a slanted sub-tag;
   - hangers, bolts and its own lamps.
   It replaces every badge (gateways, MARKET, BATTLE PASS, LOCKER). The locker floor emblem is removed.
2. **Entrances v2:** steel added to each gateway: a header I-beam with knee braces, column caps and bolts, hazard kick plates, a gate ID stencil, a caution plate, a status lamp, conduit to a junction box, and floor chevrons into the door.
3. **Range bay entrance:** a 22 x 15 bay door frame with two ribbed leaves parked open on a top rail, beacons, caution plates and a sim bay behind it (about 46 x 30), containing:
   - a holo projector plinth with a translucent neon miniature range (lanes, targets, cover, towers) and projection beams;
   - a holo grid screen with neon RANGE letters;
   - a lattice landmark frame at the back as a season mount (placeholder);
   - a floor stencil.
4. **Structure:** steel columns at the hub's octagon corners up to a ring beam, with knee braces, base plates and cable trays, set clear of the doors, lamps and pipes.
5. Captures, overlap audit, playtest, then this note.

## Character pass built (2026-11-20)

**Signs v2** (`tools/studio/lobby_v5/LobbySigns.luau` → module `ServerStorage.V5Kit.LobbySigns`; placed by `BuildSigns.luau`). Each sign is a hanging, layered Part sign, tilted down at the viewer:
- a slanted dark plate in a steel frame, with accent inlay lines top and bottom;
- a faceted octagon medallion that breaks out of the left end: a steel back, an accent ring, a dark face and a 3D emblem in the area colour;
- extruded letters: three dark layers behind a bright Rubik Heavy Italic face with a thin ink stroke;
- a slanted accent sub-tag under the right end;
- hanger rods, clamps and bolts.

Rubik isn't installed locally, so the letters are stacked SurfaceGui layers, not meshes; they keep the game font exactly.

| Sign | Emblem | Where |
|---|---|---|
| Duels | `versus` (two chevrons facing, a spark) | gateway |
| Locker | `padlock` | gateway, and hung over the gun wall |
| Shop | `bag` | gateway; MARKET hangs over the counter |
| Battle Pass | `rank` (stacked chevrons and a gem) | on its panel |
| Range | `crosshair` | stands on the bay girder |

The old badges and wash lamps are gone, and so is the locker floor emblem.

**Entrance steel** (`S.gatewaySteel`) on Duels, Locker and Shop:
- two I-beam outriggers on bearing pads over the cornice, with knee braces, carrying the sign;
- steel capitals with bolts on the pilasters;
- hazard kick plates in the jambs;
- a gate ID plate (D-01, L-02, S-03) and a caution or notice plate: "FIGHTERS ONLY", "GEAR UP BEFORE DUELS", "NO REFUNDS";
- a green status lamp, and a conduit with a junction box (Locker only: Duels has buttresses there, Shop's piers are too narrow);
- three floor chevrons into each door.

The Duels season screen went up 5 to clear the outriggers.

**Range bay** (`BuildRangeBay.luau`, `Hub.RangeBay`, 333 pieces). It replaces the shuttered gateway; the range itself is not built.
- **Frame:** a 24 x 16 opening with steel-clad piers, rivets and hazard bands; a stiffened girder; two amber beacons; corner gussets; a fascia and coping; R-04, warning and caution plates.
- **Doors:** two ribbed leaves on a track, parked open with hazard edges, trolleys and a floor guide channel. The passage between them is 12 wide.
- **RANGE sign:** stands on posts on the girder. The south screen went up 6.
- **Sim bay:** 24 x 30 x 18, with steel H-columns and knee braces, I-beams across, ceiling lights and a "SIMULATION BAY 04" floor stencil. It contains:
  - a walk-through holo grid curtain just inside the doors, reading "LIVE FIRE » COMING SOON";
  - a faceted projector plinth throwing a translucent miniature range: grid platform, 3 lanes, a firing line, targets, cover and towers, with projection beams;
  - on the back wall, a steel truss landmark with standalone letters "THE DEEP", lit by two uplights. It is a `SeasonMount` (Slot `RangeLandmark`) for the season's landmark (RIVALS' Rivalwood idea, ours as a placeholder).

**Hub steel** (`BuildHubSteel.luau`, `Hub.Steel`):
- Four steel H-columns in the rock corners beside the Locker and the Range.
  - They are placed by raycasts 1.15 in front of the nearest rock or pipe run (the runs pass behind them).
  - Each has a bolted base plate, a hazard sleeve, collars and tie-backs to the rock at heights clear of pipes.
  - Three end in caps that carry the cable trays; one runs up into the rock.
- A box lighting truss between the lift towers at y 27-29.4, with four hanging spot lamps.
- Two first tries failed and were fixed:
  - Header beams over the door sides were buried (the upper rock leans in to about 34 from the centre at y 33), so they were dropped.
  - Columns at R 51 were inside the jagged rock corners (41 to 50 from the centre), so they are placed by raycast instead.
  - The Shop corners were skipped: columns there block the display windows.

**Checks:**
- **Captures:** Duels front and side, Locker, Range bay (two angles), the hub's SE corner, and the shop's interior signs.
- **Exact overlap audit** of every new part (rock excluded). Fixed:
  - the locker sign's medallion into an I-beam (it hangs lower now);
  - MARKET into the soffit band (moved 0.6 forward);
  - the Duels conduit into its buttress (removed);
  - range rivets under the door plates (removed);
  - the columns through the pipe runs and trays.
  - What remains is deliberate seats: mount plates bolted into ceilings, plate edges set into panels, capitals over the pilaster tops, chevrons on the floor.
- **Playtest:** walked from the hub into the range bay through the curtain; 4 prompts live; no new console errors.

**Open:**
- The queue bay lightbox signs in the Duels hall are still the old style (MatchLift flashes them, so a restyle must keep their Sign / Face / SurfaceGui contract).
- The hologram is static (no spinner code).
- The place is **not saved**.

## Final touches and pause (2026-11-20)

Owner: "a lot of the support pins aren't connecting to anything ... the other support beams are just not fully connected"; "a little bit of overlap in the walls and the entrances, such as the shop entrance"; redo the bay signs. Then **stop work on the lobby** until more of the game's functionality is built (the range will add to the bay later).

**Supports now connect:**
- The lift truss spans to the towers' yokes (x ±20.2). Its end plates bear on the yokes and span post to post, bolted; it used to end 2.8 short.
- The three column caps reach 3 studs back under the cable trays they carry, on knee braces. They stood 1.5 in front of the trays.
- The RANGE sign stands 2.85 forward on posts that follow its 10° tilt from foot plates on the girder up its back, with two clamps each. The vertical posts only touched its top edge.

**Rock overlaps** (a raycast scan from the hub at 0.5 spacing across each entrance face, looking for rock in front of the frame):
- **Duels:** the side rock walls stood in front of the outer 2 studs. Every frame piece past |x| 21.3 is trimmed back to it and the plates moved in.
- **Shop:** the corner rock cut across the outer 4 studs of both wings, half of the south window. The wings now end at |x| 17.2 with the windows moved in (4 wide, pedestal guns at fill 3.4).
- Locker and Range were clean. All four now scan clear.

**Queue bay signs v2** (`BuildBaySigns.luau`):
- Each of the 8 bays has a hanging v2 sign: the mode word, and a medallion with two clashing chevrons in the team colours (gold against cyan).
- A STEP IN TO QUEUE status strip, a pad light under it, and rods to the gantry runway beam (Runway_F) they always hung from.
- Util/MatchLift's contract is kept: `Sign`, then `Face`, then the SurfaceGui's first Frame, holding a right-aligned label. Playtested: standing on a 1v1 square, MATCH FOUND flashed the strip gold at 5.5 s.

**State at the pause:**
- Everything is built in the Lobby place, but the place is **not saved**.
- The hologram is static.
- The range itself, a talk line for the Broker, and the colour/prop pass wait for later.

## Shop V2: the market hall (plan, 2026-11-21)

Owner: "we're starting to lose some professionality ... make sure you're good on quality"; the shop "doesn't really look good"; "I want the same idea that Rivals has ... that big hallway splitting off into other two sections ... look good ... fun ... leads to more stuff just to explore". Picks: the wings are **Item Shop (left) + Season Pass (right)**; the hall is lined with **display bays both sides**; **redo the entrance**; **build it all, review at the end**. The lobby pause is lifted for the shop only.

**RIVALS Market, measured read-only (`Workspace.Lobby.Hub.Extra.Market`, rays from the corridor axis):** a 30-wide door, then a 32-wide, 27-high corridor about 60 long with one stage bay on each side (UGC SHOP, SEASON 3: stage lighting truss, a backdrop, a display, a slanted label tag on the pier, a KEEP CLEAR stencil). It then steps down 3 into a room that fans out to about 128 wide round a central block, and the walk splits left and right into passages ("WEST GATE", "CARGO ELEVATOR" floor stencils). What makes it work: compress then release, the destination visible down the axis, life only in the bays, and labels on everything. We take the structure and numbers, in our own look (The Deep: concrete, steel, warm white light, one accent per room).

**Layout** (shop frame F: origin on the hub floor at the old gate face, world x -40; x = right as seen from the hub; z toward the hub):

| Piece | Size | Notes |
|---|---|---|
| Portal | opening 20 x 15, piers 4.5, 12 deep, cornice 20.5 | The `K.gateway` family (Duels, Locker), bigger; the SHOP sign on outriggers; the hall's lit axis and the central feature are visible from the hub. Kept under the hub's rock above (Above_W, bottom y 18). |
| Hall | 30 wide, 22 high, z -13 to -61 | Compress, then release. A dark aisle between the hub's gold lines (x ±6.4) carried on; pilasters with bar lamps; steel beams on capitals; a raised coffer down the middle. |
| Display bays | 4, each 16 wide, 9 deep, 14 high, stage 1.2 up | FEATURED (gun on a turntable) and NEW IN (three guns) on the left; SEASON 1 (pass screen and reward cases) and CASES (the real crate models, every tier) on the right. Each has a lighting truss with spots, a backdrop screen (SurfaceGui), a slanted label tag and a bay number. |
| Junction | 48 wide, 26 high, z -61 to -95 | The walls flare at 45 degrees out of the hall. At the back sits the central feature: a DAILY SHOP screen over a tiered plinth with the featured gun turning (the `ShopWindow` season mount). The two back corners are cut at 45 degrees and hold the passages. |
| Passages | 12 x 14, 14 long, at 45 degrees | Compress again, each under its hanging sign: ITEM SHOP (bag, gold) and SEASON PASS (rank, purple). |
| Item Shop wing | 32 x 30, 18 high | The Broker behind the counter (`LobbyShop`, now also a Talk line that opens the Shop), the MARKET sign over the slat wall, the gun wall (`LobbyGunDisplay`), crate shelves, and a closed STOCKROOM shutter (a future door). |
| Season Pass wing | 32 x 30, 18 high, purple accent | A pass screen with a tier track, a stepped reward stage with the cases (`LobbyBattlePass`), season banners, and a closed NEXT SEASON shutter (a future door). |

Walk from the spawn: portal about 40, junction about 120, wing counters about 165 (about 10 s; RIVALS' market is about 137).

**Quality bar for this pass** (from `gauntlet-build-style`, the owner's notes in memory, and the RIVALS study):
- Every fixture is built the way it would be made: housing, lens set back, guard, a real light beside it; trusses bolted to the bay heads; beams bearing on capitals.
- No plain boxes for displays; the props are real models (guns, crate meshes, the Broker).
- Every joint gets a transition: pilasters hide the 45-degree corners; plinths sit under walls; shadow gaps.
- One accent per room: the hall and Item Shop gold, the Season Pass purple.
- Check sightlines from the hub and from the junction; run an overlap audit and a rock check; play-walk it.
- Hooks are kept: `LobbyShop`, `LobbyBattlePass`, `LobbyGunDisplay`, `LobbyNPC` (Broker), and `SeasonMount` slots `ShopWindow`, `SeasonShowcase` and `PassHero`.

Scripts: `BuildShopHall.luau` (the shell: portal, hall, bays, junction, passages, wings, structure, light) and `BuildShopFit.luau` (displays, the feature, the wings' fit-out, signs, plates, stencils).

## Overnight pass: shop, locker, signs v3, glitches, decor, range (2026-11-21)

Owner before bed: finish the shop ("make it look really good, all the sections, grade yourself"), then the locker ("needs sections for the guns ... the stands need to look better ... dull"), all the signs ("they just don't fit our vibe ... make something new", the 1v1/2v2/3v3 ones too), "your overlapping glitch parts check", the hub decor ("look at all the rivals decorations and build your own ... sleek ... nothing crazy") and the Duels section, then start the range ("arena bricks ... bots different sets away ... trash cans ... to change their loadout ... we're literally just building it"). All built in the Lobby place and **saved** (versions 860 to 868, then a final save).

Captures (`Lobby V5/2026-11-21/`): ![shop front](Lobby%20V5/2026-11-21/01_shop_front.jpg) ![hall](Lobby%20V5/2026-11-21/02_shop_hall.jpg) ![junction](Lobby%20V5/2026-11-21/03_shop_junction.jpg) ![item shop](Lobby%20V5/2026-11-21/04_item_shop.jpg) ![season pass](Lobby%20V5/2026-11-21/05_season_pass.jpg) ![locker](Lobby%20V5/2026-11-21/06_locker_armory.jpg) ![console](Lobby%20V5/2026-11-21/07_locker_console.jpg) ![range](Lobby%20V5/2026-11-21/08_range_hall.jpg) ![duels](Lobby%20V5/2026-11-21/09_duels_deck.jpg)

Edit-mode captures don't show the guns (the client lays each player's skins in play) or the gun stands; the green dots and purple lines in some shots are Studio's attachment and bone overlays, not parts.

**Shop V2, built as planned above** (`BuildShopHall`, `BuildShopFit`, `BuildShopWings`):
- **Portal:** a 20 x 15 gateway, 12 deep, with return walls out to the rock (no more gaps). The SHOP sign stands on the cornice.
- **Hall:** 30 x 22 with a raised coffer, pilasters with bar lamps carrying I-beams, a dark aisle between the hub's gold lines, and four stage bays. Each bay has drape walls, a stage with a gold step light, a lighting truss with three cans, a backdrop screen, and its own sign (01 FEATURED, 02 SEASON 1, 03 NEW IN, 04 CASES):
  - FEATURED: a Vandal on a turntable.
  - SEASON 1: Elite, Apex and Knife crates on plinths (`SeasonShowcase` mount).
  - NEW IN: Phantom, Spectre and Sheriff on stands.
  - CASES: every crate tier on risers. These are the real crate models in their tier looks.
- **Junction:** 26 high, with 45-degree corners, corner pilasters, two beams, the DAILY SHOP screen under a lit hood, a tiered plinth with the Operator turning (`ShopWindow` mount), a gold floor ring the lines run into, ITEMS / PASS wayfinding boards, and hanging ITEM SHOP and SEASON PASS signs over the two passages.
- **Item Shop wing:**
  - the Broker at the counter, with a Talk line that opens the Shop (`NpcTalk.broker`);
  - the terminal, the slat wall with the MARKET sign, and crate shelves;
  - two lit gun cabinets (Vandal, Phantom; Operator, Spectre), and a knife-case vitrine table under a pendant from the beam;
  - a BUNDLES board, and a STOCKROOM shutter (a future door).
- **Season Pass wing:**
  - the SEASON 1 screen with a 7-tier track under a lit hood (`PassHero` mount);
  - a three-step stage with purple step lights and the reward cases;
  - S1 banners, a floor emblem, and a NEXT SEASON shutter (a future door).
- **Prompts:** `LobbyShop` and `LobbyBattlePass` sit in front of the counter and the stage.

**Signs v3** (`LobbyWay.luau` → `ServerStorage.V5Kit.LobbyWay`): facility wayfinding instead of neon. Each sign is:
- a dark steel cabinet with one cut corner on a steel rim;
- a raised accent tile with the area's HUD icon (or a code: a bay number, "!");
- the word in flat white Rubik Heavy, a ruled sub-label in the accent, and a small zone code;
- lit by two gooseneck lamps, on wall stand-offs, hanging rods or posts.

Every label shrinks to fit instead of overflowing (`UITextSizeConstraint`). Replaced:
- DUELS, LOCKER and SHOP over the gateways;
- RANGE on the bay girder;
- the 8 queue bays: the mode as the word, "DUELS · n PLAYERS", and a status strip that keeps MatchLift's MATCH FOUND contract (`Sign` → `Face` → first Frame → right-aligned label).

**Locker armory** (`BuildLockerArmory`): every gun sits in a section for its class (`Config/Weapons`):
- **Back wall:** three glass-fronted cabinets between steel columns: SNIPERS (Operator, Outlaw, Marshal), RIFLES (Vandal, Phantom, Guardian, Bulldog) and HEAVY (Odin, Ares). Each row has its own hood light and tag.
- **Centre:** the old flat tables became sloped display consoles: a plinth, a felt top between gunmetal cheeks, a front lip, a canopy lamp and the class sign on the fascia. They hold SIDEARMS (Classic, Ghost, Sheriff, Shorty), SMGS (Stinger, Spectre) and SHOTGUNS (Bucky, Judge).
- **MELEE:** an octagon vitrine with the knife turning.
- **Fixed:** the two west wainscot slopes (they stuck 6 studs through the wall into the vestibule). The Armorer moved 1.6 forward (his tail was in a cabinet).

**Glitch pass** (`FixGlitches.luau`): three scans (cross-area GetPartsInPart, a coplanar-face scan, per-area audits). Fixed:
- the buried Duels tunnel step;
- flickering faces: bar-lamp caps, bay opening edges, the portal wainscot ends, hall ceiling ends, I-beam web ends, console hood lips, the range bay wainscot;
- bay jambs widened over the drape edges;
- sign bolts moved off the accent tile.

What remains are deliberate seats (pilasters into walls, sign mounts, floor paint).

**Hub decor** (`BuildHubDecor`), after a read-only study of RIVALS' hub decor (TVs on arms, standing displays, capsule lamps, stanchions, crates, vents, intercoms, floor arrows; life where players stop):
- four info kiosks, one beside each gateway, turned to the spawn: a stepped plinth, a slim steel tower, a portrait screen, the area tile, a crown hood lamp and a conduit;
- two benches behind the spawn.

All clear of the lines, drains, columns, season mounts and rock (the Duels kiosk was moved out of a leaning rock wall; the Shop and Locker kiosks off their gate piers).

**Duels decor** (`BuildDuelsDecor`):
- bollard lamps in every gap between the queue bays along the chasm edge (RIVALS' lamp between pads, ours);
- four how-to-play boards on the bulkhead: THE DRAFT, WEAPON TIERS, HEADSHOTS 1.5x, QUEUE UP;
- two benches.

**Range: the test hall** (`BuildRange`), from the owner's `Workspace.ShootingRangeRivals` (read-only). It extends `Hub.RangeBay` (the sim bay's back wall now opens into it; the hologram stays; the curtain says NOW OPEN):
- **Hall:** 120 x 155 x 40, arena bricks (our two greys and our grid tile, the arena recipe), 18 downlights.
- **Firing line:** a firing line and distance lines every 25 studs.
- **Bots:** nine training bots (R15, yellow torso, anchored, tagged `RangeBot` with Distance / Lane) on pads with distance plates. Three lanes: 20 / 60 / 110, 35 / 80 / 130 and 45 / 95 / 120 studs.
- **Cover and towers:** six cover blocks and two towers on 5 x 15 x 5 posts with truss ladders.
- **Loadout bins:** six bins, our take on RIVALS' trash cans (a faceted steel bin, a lid, a cyan band and the locker icon), tagged `RangeLoadout` for the loadout GUI later.
- **Landmark:** THE DEEP moved to the far wall at 1.8x (the owner's "Hollywood thing at the back").

No code yet: bots don't react and the bins don't open anything.

**Self-grade** (honest; the owner's bar runs higher):
- Shop: **8**. Structure, wayfinding and the split are strong; the bays depend on the guns showing in play.
- Season and Item wings: **8**.
- Locker armory: **7.5**. It needs a play check with the guns in.
- Signs v3: **7.5**. Clean and consistent, but a new look the owner hasn't seen.
- Hub decor: **7**. Restrained on purpose.
- Duels decor: **7**.
- Range: **7.5**. It matches the reference's vibe; the bots are plain R15 rigs.

**To check in play:**
- the guns on every stand, cabinet and console;
- Talk to the Broker → Shop;
- the Open Shop / Battle Pass prompts;
- a queue-bay MATCH FOUND flash with the new strip;
- walking the range (ladders, towers, bins);
- the Armorer's white outfit still blows out under the lights (an old issue).

## Hub 9/10 pass (2026-11-21, afternoon)

**Owner's review of the overnight pass:**
- Target: hub quality 9–10/10.
- Hub decor was not good. The kiosks and misplaced benches go. Wanted instead: real decorations built in Blender — cases (not the gun cases), boxes, barrels — that the owner will then move around.
- Shop: glitching parts; display lighting; the Item Shop was cluttered (cases in the middle); needs more character. The second wing should be closed, "under construction or something cool".
- Locker: cluttered, needs room and detail like RIVALS. Its gun stands didn't show much, and there were floating and unaligned parts. The part-built kitbags looked unprofessional. Remove the benches.
- Too many signs and labels.
- Duels: a little more character, nothing over the top.
- Range: like RIVALS — a small hologram you touch to enter, no dummies visible from the hub. The real range is built far away, much bigger, open, with levels, for many players.

**Built (place saved, version 880):**
- **Decor props** (`tools/blender/lobby_v5/v5_props.py`, asset 90719517602535, `ServerStorage.V5Kit.Props`, placed with `BuildProps.luau`):
  - The set: WeaponCrate, FlatCase, CargoBox, Drum, Pallet, AmmoCan, CableSpool, ToolChest, PowerBox.
  - Colour schemes: Charcoal, Olive, Hazard, Slate.
  - v1 was rejected during the pass: "rounded low poly shapes that do not connect well" (only the drum passed). v2 is crisp: small bevels, details cut in with booleans or bands that wrap, attachments seated in pockets. Rule saved in memory `props-crisp-connected`. Sheet: `Lobby V5/2026-11-21/19 Props v2 sheet.jpg`.
- **Hub:** the kiosks, benches and part-built stacks are gone. Four prop clusters sit in the rock corners (`Hub.Dressing.Props.Cluster_*`), for the owner to move. Captures: `10`, `11`.
- **Shop:**
  - Flicker fix (`FlickerFix.luau`): 112 coplanar pairs down to 4 hidden ones.
  - Item Shop decluttered: no case table, pendant, crate shelves, racking or bundles board. It now has a story: a delivery pallet by the stockroom shutter, drums and a case behind the counter, a tool chest, a counter mat, and one case for sale on the counter (`12`).
  - Display bays: lighter drape, a warm ceiling wash in every bay, stronger and tighter spots with shadows, light plinth tops, and cases 1.35× bigger (`14`).
  - **Season Pass wing closed** (`BuildSeasonClosed.luau`): a sealed blast door with a hazard band, a red lock lamp and a spinning amber beacon. In front: a "COMING SOON · SEASON PASS · AREA UNDER CONSTRUCTION" board on posts, and building materials (`13`). The wing's battle-pass prompt is now unreachable; the menu button still opens it.
- **Locker rebuilt** (`BuildLockerV2.luau`):
  - Cleared: the workbench (the LockerZone was kept), consoles, the melee vitrine, the corner cages, the kitbags and helmets, and the benches.
  - **One weapon wall** across the back: long guns on top (SNIPERS | RIFLES | HEAVY), short guns and the knife below (SMGS | SHOTGUNS | SIDEARMS | MELEE). Guns hang big on a lit pegboard, a lens strip runs over each tier, and small class labels sit on the bands.
  - An octagonal hero plinth in the middle turns your rifle.
  - Supply props in the back corners; the Armorer is moved to the south corner. In play the guns read clearly (`15`).
- **Fewer labels:** gone are the caution/notice/gate-ID plates (gateways and range frame), the bay number signs, both junction wayboards, the hanging wing signs and the shutter signs. Kept: the area signs, queue-bay signs, screens, the Duels how-to boards and MARKET.
- **Floating fixes:**
  - the Duels deck's front panel row hung 0.1 over the under-plate;
  - the lift counterweight blocks had 0.1 gaps between them;
  - both shutter handles floated.
  - Flicker fix also run on the Hub (112→4), Duels (94→0), Locker and Range.
- **Duels:** small prop sets only — crates with ammo cans at x ±92, a power cabinet and drum at ±28, and drums at both deck ends.
- **Range** (`BuildRangeV2.luau`, `src/lobby/server/Services/RangeService.luau`):
  - **Hub side:** the sim bay is closed again and the grid curtain is gone. The spinning hologram range on the projector is the way in (`RangeEntry`), with a "STEP IN » LIVE FIRE" caption (`16`).
  - **The range** is a sunlit "simulation yard" at world (0, 0, 2600), 270 × 250, in arena bricks with 30-high walls:
    - a spawn deck with an exit hologram (`RangeExit`), 4 spawn points (`RangeSpawn`) and the 6 loadout bins;
    - three firing lanes with 25-stud bands, floor distance numbers, booths and the 9 bots;
    - an open arena: four 10-high bastions with ramps and ladders, a two-level plateau, catwalks on posts joining everything, 17 cover blocks, two tall walls, and 5 jump pads (`RangeJumpPad`, no code yet);
    - THE DEEP on the north wall (`17`, `18`).
  - **Teleports tested in play** both ways (entry → deck, exit → in front of the hub hologram).
  - Rojo was not connected, so RangeService was added in Studio with the same source; reconnect Rojo to sync the file.

**Self-grade** (honest; my grades have run 2–3 high before, so the owner's review decides):

| Area | Grade | Note |
|---|---|---|
| Props | 8 | |
| Hub decor | 8 | Clusters are a first layout. |
| Shop | 8.5 | |
| Locker | 8.5 | |
| Duels | 8 | |
| Range | 8 | Plain arena bricks; it could use colour zones and more height variety. |

**To check / next:**
- walk the range with several players (ladders, catwalk edges, jump pads need code);
- reconnect Rojo so `RangeService.luau` syncs;
- the Range HUD panel still says it "opens in the next lobby phase";
- the Season Pass prompt is now unreachable in the world;
- move the prop clusters as you like (`Hub.Dressing.Props`).

## Range v3 (2026-11-21)

**Owner's review:** "the shooting range is pretty boring. it needs more like structure ... not over the top ... the signs you have for markers are pretty bad. I want jump pads to be made in blender to look nice ... study the rivals shooting range so you actually understand the build".

**Study:** [Maps and Lobby → Shooting range study](../03%20Research/Rivals%20Reference/Maps%20and%20Lobby.md#shooting-range-study-2026-11-21-workspaceshootingrangerivals-in-our-lobby-place-read-only). What the RIVALS range does:
- structure comes from height and massing (50-high thick walls with doorways and windows, walkable roofs, bridges crossing overhead);
- one material with a grid;
- colour only on the lane floor and the gameplay objects;
- distance as big text on the lane walls;
- a modelled glowing jump pad.

**Built** (`BuildRangeV3.luau`, place saved v883). Our layout, sized "not over the top". The yard's walls are now 45 high. Structures:
- **Hangar** (hollow, 25 high): two doors, windows, a roof with parapets, a ladder.
- **Long hall:** two 25-high walls with doorways and windows, beams across the top, walkable wall tops.
- **Tower:** 40 high.
- **Lookout:** 25 high, with parkour posts at 5 / 10 / 15 / 20 up its face.
- **Bunker:** 15 high, with a ramp.
- **Bridges at 25:** hangar roof → long hall, long hall → lookout, both on piers.
- **Ground cover:** three U-walls and ten blocks.

**Lane:**
- A walled 55 × 210 corridor (walls 45 high).
- Floor bands every 25 in our area colours: orange, yellow, teal, cyan, purple, slate, charcoal, grey.
- **The distance numbers are on both lane walls** (25 … 200, white Rubik Heavy with a dark stroke, a band-coloured bar, "STUDS").
- The bots stand on the 25-stud lines; their old post signs are gone.

**Jump pads:**
- Modelled in Blender (`tools/blender/lobby_v5/v5_jumppad.py`, asset 103017656207012, `V5Kit.JumpPad`; render `23`). Our own design: a clipped-square base, a notched rim, a recessed deck, a teal glow ring around a dark bezel and glowing core, four launch chevrons, and steel corner clamps.
- Four of them, one onto each roof. `LobbyJumpPads` launches you.
- **Tested in play: all four land on their roof.** In the air the humanoid caps sideways speed, so the pads sit about 7 from the wall and launch high.

Audits: no overlaps, no floating parts, no flicker. Captures `20`–`23`.

**Next / to check:**
- walk it with several players;
- tightropes / ziplines between the tower and the hangar (RIVALS has them; they need code);
- loadout bin GUI;
- Rojo reconnect (`RangeService`, `LobbyJumpPads` were added in Studio with the same source).

## 5. Phases
1. **Concept images (now).** Owner runs the §4 ChatGPT prompts; then the reference interview on the results. References in §7. Then the reference interview from [Model Style Interview](Model%20Style%20Interview.md) on 4-6 picked images.
2. **Concept images.** ChatGPT prompts for the concourse and duels area (memory: concept first, owner approves before building).
3. **Material and kit sheet in Studio** (shell pieces plus one `SeasonMount` of each slot). A small test room built in Parts: the chosen variants, 3 wall bays, a floor, a trim, one gate, one pad. Owner signs off the look before any layout.
4. **Grey blockout of the layout** in Parts (spawn, duels, shop, locker, range door), walk-time checks, captures.
5. **Dress zone by zone** (duels first), Blender props only where §3.4 allows, audit after each zone.
6. **Swap in** for V4 when the owner approves; V4 stays as rollback.

## 6. Tools installed this session
- **blender-skills** (arjun988, MIT, commit in `~/.claude/skill-library/blender-skills/COMMIT.txt`). Safety check: 547 markdown files, no scripts that run, no hooks; its `.mcp.json` (a second Blender MCP on port 9876) was **not** installed. 28 skills that fit our work are in `~/.claude/skills/` (blender-director, blender-modeler, hard-surface, prop-artist, environment-artist, set-dressing, scene-assembly, procedural-modeling, geometry-nodes, lowpoly-style, stylized-style, genre-shooter, materials, texture-workflow, uv-workflow, export-pipeline, collision-proxy, asset-optimization, lod-pipeline, retopology, sculpting, references, qa-review, lighting, lookdev, animation, rigging, vfx-fx). The other 66 (anime, horror packs, Unity/Unreal export and so on) are in `~/.claude/skill-library/blender-skills/` to copy in when needed.
- **Sculpting vs scripting.** The pack's own sculpting skill says not to sculpt hard-surface panels, modular kit pieces, low-poly assets or background props. Our faceted style is hard-surface, so lobby pieces and guns are **box-modelled** (edit-mode modelling through the MCP, one chamfer). Sculpting fits organic forms only: characters, creatures, cloth, damage on hero skins. The rule we use: **always load the Blender skills (blender-director first, then the specialist) before Blender work; sculpt only organic forms.**
- **roblox-map-builder** (the zip). **Proprietary licence: no sharing or redistribution.** This repo is public, so it is installed only in `~/.claude/skills/roblox-map-builder/` and is **not** copied into the vault or git. Safety check: 115 Python, 55 Lua, 14 shell files; no network, no shell calls, no HttpService or `loadstring`; the only `eval` calls run the user's own command-line expressions in its preview tools. Its main pipeline (headless Blender builds the whole map, one GLB per prop, a generated setup module) is the approach we're moving away from, and our rule is live Blender MCP only. Useful parts for V5: `references/layout_patterns.md` and `map_archetypes.md` (layout types), `quality_checklist.md` and `bug_gallery.md` (floating / clipping checks), the "Stud / Parts mode" section (wedge-chamfer tops, framed panels, "no bare blocks", no text built from Parts, one signature edge detail repeated on every ledge).

## 7. References (web search 2026-11-20; "opened" = page read, the rest from search results)
**Walkout and venue ideas (round-1 concept A, dropped; the walkout-door idea lives on in the airlocks)**
- [THE FINALS wiki: Arenas](https://www.thefinals.wiki/wiki/Arenas) (opened): every space is a venue in one show. Take the framing, not the TV-glitz look.
- [SVG: Inside OGN Super Arena](https://www.sportsvideo.org/2019/06/13/inside-ogn-super-arena-the-first-esports-venue-in-north-america-designed-specifically-for-battle-royale/) (opened): an LED walkout tunnel, and each player's station shows their name and stats. Take: a board over each gate showing who is queued.
- [Populous: Etihad Tunnel Club](https://populous.com/project/etihad-stadium-expansion/): a glass wall looking onto the players' tunnel. Take: the lobby watches players walk out.
- [Gladiators (2024 UK)](https://www.wikipedia.org/wiki/Gladiators_(2024_British_TV_series)): a bright arena inside a dark surround, red and blue sides.
- [Snøhetta: Ullevaal Stadion](https://old.snohetta.com/projects/600-ullevaal-stadion): colour-coded industrial floor coating in the tunnel, used for wayfinding.
- [Core77: NBA locker room design](https://www.core77.com/posts/138228/A-Look-at-NBA-Locker-Room-Design) and [AHMM: NBA Performance Center](https://www.ahmm.co.uk/projects/americas/nba-professional-performance-center/): locker ring around one centre point; shop, locker and briefing as separate rooms.
- [THE FINALS wiki: Sponsors](https://www.thefinals.wiki/wiki/Sponsors): fictional sponsors give rooms an identity (shop / locker branding).

**Shooting facilities (useful for the laser-tag arena and range)**
- [Kill house](https://en.wikipedia.org/wiki/Kill_house), [Military Times: Shoot house](https://militarytimes.com/native/range-systems/2018/05/09/shoot-house-intel): observation catwalks over rooms, moving walls.
- [Officer.com: Indoor range design](https://www.officer.com/training-careers/shooting-ranges-equipment/article/21226716/indoor-range-design-considerations): plywood-faced steel baffles, rubber, a range-master booth.
- [Dexerto: Apex Firing Range overhaul](https://dexerto.com/apex-legends/apex-legends-firing-range-gets-massive-overhaul-in-season-17-with-new-map-1v1-pit-movement-practice-2128703) (opened): a dedicated 1v1 Duel Pit next to the range lanes.
- [Rainbow Six: Hereford Base rework](https://rainbowsix.fandom.com/wiki/Hereford_Base_(Rework)), [Valorant: The Range](https://valorant-lore.fandom.com/wiki/The_Range): believable training bases with a story.

**Other hubs**
- [Deadlock wiki: Sandbox](https://deadlock.wiki/Sandbox) (portal from the hub to practice), [Halo Infinite Academy](https://support.halowaypoint.com/hc/en-us/articles/30152458997652-Halo-Infinite-Academy) (drill scores saved), [Murderers vs Sheriffs](https://pixeltwelve.com/games/murderers-vs-sheriffs) (1v1 to 4v4 modes like ours).
- [BuiltByBit: Low Poly FPS Lobby](https://builtbybit.com/resources/low-poly-fps-lobby.109214/): the stock Roblox shooter-lobby layout (central spawn, range, case opening, four queue boards). **Avoid this layout.**
- [DevForum: lobby for Hyperlust](https://devforum.roblox.com/t/new-game-lobby-for-hyperlust/664112): feedback was "busy, no theme". Give players one main feature to gather around.

**Roblox build craft**
- [Roblox docs: Beyond the Dark, building architecture](https://create.roblox.com/docs/resources/beyond-the-dark/building-architecture) (opened): a modular grid and shared trim sheets.
- [Roblox docs: Materials](https://create.roblox.com/docs/parts/materials), [MaterialVariant release](https://devforum.roblox.com/t/ugc-material-variants-upgraded-built-in-materials-release/1886517), [Open Materials Showcase](https://devforum.roblox.com/t/open-materials-showcase-share-your-custom-materials/1852276).
- [Roblox docs: Assemble modular environments](https://create.roblox.com/docs/tutorials/use-case-tutorials/modeling/assemble-modular-environments): consistent pivots and snap settings.
- [DevForum: Parts or MeshParts?](https://devforum.roblox.com/t/should-i-use-roblox-parts-or-meshparts/3753133), [MeshPart performance](https://devforum.roblox.com/t/meshpart-usage-performance-optimizations/1319217): Parts for simple shapes, meshes for repeated detail, unions cost the most.

**Duels-area layouts that aren't a hallway of pads**
1. **Contender gates (A):** short lit tunnels off the hub, one per mode, with a queued-names board above each. The doors open when the match starts, and a window lets the lobby watch.
2. **Arena pit with gates (A/B):** a sunken pit in the hub with four gates around it and a board over each. Standing in a gate bay queues you.
3. **Grid stage (A):** a raised floor of lit cells. Bigger modes take bigger blocks of cells, which light up as they fill.
4. **Facing booths (A/C):** booths face each other across a stage, each with a nameplate screen.
5. **Lift cells under a catwalk (B):** queue cells on lifts that drop away when the match starts, watched from an observation deck.

## 8. Sources used
- Studio MCP, Lobby place: `Workspace.LobbyRivals` (read-only), `Workspace.LobbyV4Staging`, `Workspace.NewQueueArea`, `Workspace.PathNew`, `MaterialService`.
- [Lobby V4 Build](Lobby%20V4%20Build.md), [Lobby V4 Theme](Lobby%20V4%20Theme.md), [Lobby](../01%20Design/Lobby.md), [Rivals Reference](../03%20Research/Rivals%20Reference/00%20Rivals%20Reference.md).
- Skills: `gauntlet-build-style`, `rivals-reference`, `lihfolk-worldbuilding`, the blender-skills pack (sculpting, hard-surface), roblox-map-builder references.
- LihFolk (plugin vault): *Parts Unions and MeshParts* (Parts for structure, MeshParts for repeated or detailed props, Unions only for 1-3 cut-outs); *Materials MaterialVariants and SurfaceAppearance* and *MaterialService and Custom Materials* (renaming a variant breaks every part on it; `Texture` with StudsPerTileU/V for trims); *Modular Environment Kits* (write grid, wall height, thickness and door size first; one pivot rule; z-fighting fix = delete the hidden face or offset 0.01-0.05; no bevels on contact edges); *Lobby and Hub Design* (first station under 15 s, exit under 20 s, spawn faces the centrepiece, blockout playtested on PC and phone before art); *Modeling in Blender for Roblox* (one mesh per piece or colour, bottom-centre pivots, clone instead of re-import).
