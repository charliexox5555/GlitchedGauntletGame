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
